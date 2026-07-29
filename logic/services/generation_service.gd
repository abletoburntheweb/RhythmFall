# logic/services/generation_service.gd
extends Node
class_name GenerationService

const _RhythmDnaServerFetch = preload("res://server/rhythm_dna_server_fetch.gd")
const _GenerationIntents = preload("res://logic/domain/generation/generation_intents.gd")
const _GoalDiff = preload("res://logic/domain/generation/generation_goal_difficulty.gd")

signal bpm_started(song_path: String, display_name: String)
signal bpm_completed(song_path: String, bpm_value: int, display_name: String)
signal bpm_error(song_path: String, message: String, display_name: String)
signal bpm_progress(song_path: String, stage_index: int, total: int, status: String)

signal notes_started(song_path: String, display_name: String)
signal notes_completed(song_path: String, instrument: String, display_name: String)
signal notes_error(song_path: String, message: String, display_name: String)
signal notes_progress(song_path: String, stage_index: int, total: int, status: String)

signal queue_changed(snapshot: Dictionary)

var _api: GenerationApiClient = null
var _game_engine: Node = null

var _active_bpm_task: Dictionary = {}
var _active_notes_task: Dictionary = {}
var _last_bpm_task: Dictionary = {}
var _last_notes_task: Dictionary = {}
var _bpm_queue: Array[String] = []
var _notes_queue: Array[Dictionary] = []
var _backend_retry_timer: Timer = null
var _bpm_request_sent := false
var _notes_request_sent := false
var _queue_emit_pending := false
var _active_bpm_progress: Dictionary = {}
var _active_notes_progress: Dictionary = {}
var _queue_history: Array = []
const QUEUE_HISTORY_MAX := 10
const BACKEND_RETRY_SEC := 0.5
const DURATION_SAMPLES_MAX := 30
const DEFAULT_TASK_DURATION_SEC := 90.0

var _offline_paused := false
var _offline_pause_message := ""
var _offline_banner_dismissed := false
var _duration_samples: Array[float] = []
var _active_task_started_unix: int = 0

var _BPM_STAGES := [
	"GEN_API_CONNECTING",
	"GEN_API_CONNECTED",
	"GEN_API_OPENING_FILE",
	"GEN_API_BUILDING_REQUEST",
	"GEN_API_SENDING_DATA",
	"GEN_API_RECEIVING_RESPONSE",
	"GEN_API_PROCESSING_RESPONSE",
]
var _NOTES_STAGES := [
	"GEN_API_CONNECTING",
	"GEN_API_CONNECTED",
	"GEN_API_TRACK_IDENTIFY",
	"GEN_API_DETECTING_GENRES",
	"GEN_API_SPLITTING_STEMS",
	"GEN_API_DRUM_DETECTION",
	"GEN_API_SAVING_NOTES",
	"GEN_API_BUILDING_RESPONSE",
	"GEN_API_RECEIVING_RESPONSE",
	"GEN_API_PROCESSING_RESPONSE",
]

func _localized_stage_text(stage_key: String) -> String:
	return tr(String(stage_key).strip_edges())


func _stage_index_for(status: String, stages: Array) -> int:
	var s := String(status).strip_edges()
	var stage_key := _notes_stage_key_for_status(s)
	if stage_key != "":
		for i in range(stages.size()):
			if str(stages[i]) == stage_key:
				return i + 1
	for i in range(stages.size()):
		var localized := _localized_stage_text(str(stages[i]))
		if s == localized:
			return i + 1
		var core := localized.trim_suffix("...").strip_edges()
		if core != "" and s.findn(core) != -1:
			return i + 1
	return 0


func _notes_stage_key_for_status(status: String) -> String:
	var s := String(status).strip_edges()
	if s == "":
		return ""
	if GenerationApiClient.SERVER_STATUS_ALIASES.has(s):
		var key := str(GenerationApiClient.SERVER_STATUS_ALIASES[s])
		# Bass shares the drums detection slot (6/10) and the save slot (7/10).
		if key == "GEN_API_BASS_LINE_ANALYSIS":
			return "GEN_API_DRUM_DETECTION"
		if key == "GEN_API_BASS_CHART_BUILD":
			return "GEN_API_SAVING_NOTES"
		return key
	if s.begins_with("GEN_"):
		if s == "GEN_API_BASS_LINE_ANALYSIS":
			return "GEN_API_DRUM_DETECTION"
		if s == "GEN_API_BASS_CHART_BUILD":
			return "GEN_API_SAVING_NOTES"
		return s
	return ""


func _stage_count_label(stage_index: int, total_stages: int) -> String:
	if stage_index <= 0:
		return ""
	return "(%d/%d) " % [stage_index, total_stages]


func _operation_icon_kind(task_type: String, stage_text: String, stage_key: String = "") -> String:
	var probe := String(stage_key if stage_key != "" else stage_text).strip_edges().to_upper()
	if probe.contains("UPLOAD") or probe.contains("SENDING"):
		return "upload"
	if probe.contains("CONNECT"):
		return "network"
	if probe.contains("OPENING") or probe.contains("READING"):
		return "scan"
	if probe.contains("WAIT") or probe.contains("QUEUE"):
		return "queue"
	return "bpm" if task_type == "bpm" else "music"


func _queue_summary_suffix() -> String:
	var parts: Array[String] = []
	if _bpm_queue.size() > 0:
		parts.append(tr("GEN_QUEUE_BPM") % _bpm_queue.size())
	if _notes_queue.size() > 0:
		parts.append(tr("GEN_QUEUE_NOTES") % _notes_queue.size())
	if parts.is_empty():
		return ""
	return " · %s" % " · ".join(parts)


func _push_pipeline_waiting_status(task_type: String) -> void:
	if not _gen_status_enabled():
		return
	var task: Dictionary = _active_bpm_task if task_type == "bpm" else _active_notes_task
	if task.is_empty():
		return
	var disp := String(task.get("display", ""))
	var cancel_method := "cancel_bpm" if task_type == "bpm" else "cancel_notes"
	var wait_key := "GEN_WAIT_NOTES_BUSY" if is_notes_pipeline_busy() else "GEN_WAIT_BPM_BUSY"
	var wait_text := tr(wait_key)
	var subtitle := wait_text + _queue_summary_suffix()
	var title: String = disp if _GenStatusMode.is_compact() else "%s — %s" % [disp, wait_text]
	_push_gen_operation(task_type, title, subtitle, 0, 1, cancel_method, "queue")


const _GenStatusMode = preload("res://logic/domain/library/generation_status_mode.gd")


func _gen_status_enabled() -> bool:
	return _GenStatusMode.is_enabled()


func _status_dock() -> StatusDock:
	if _game_engine and _game_engine.has_method("get_status_dock"):
		return _game_engine.get_status_dock() as StatusDock
	return null


func _service_callable(method: String) -> Callable:
	return func(): call(method)


func _push_gen_operation(
	op_id: String,
	title: String,
	subtitle: String,
	stage_index: int,
	stage_total: int,
	cancel_method: String,
	icon_kind: String = "music"
) -> void:
	var dock := _status_dock()
	if dock == null:
		return
	if not _gen_status_enabled():
		# Mode switched to Off while a job is running — drop the sticky panel.
		dock.clear_operation(op_id)
		return
	var progress := 0.0
	if stage_total > 0 and stage_index > 0:
		progress = float(stage_index) / float(stage_total)
	dock.show_operation({
		"id": op_id,
		"title": title,
		"subtitle": subtitle,
		"progress": progress,
		"compact": _GenStatusMode.is_compact(),
		"cancel": _service_callable(cancel_method),
		"icon_kind": icon_kind,
	})


func _push_gen_message(
	op_id: String,
	text: String,
	kind: String,
	duration_sec: float,
	retry_method: String = "",
	cancel_method: String = "",
	sound: String = ""
) -> void:
	var dock := _status_dock()
	if dock == null:
		return
	if not _gen_status_enabled():
		dock.clear_operation(op_id)
		return
	var payload := {
		"id": op_id,
		"text": text,
		"kind": kind,
		"duration_sec": duration_sec,
	}
	if sound != "":
		payload["sound"] = sound
	if retry_method != "":
		payload["retry"] = _service_callable(retry_method)
	if cancel_method != "":
		payload["cancel"] = _service_callable(cancel_method)
	dock.show_operation_message(payload)


func _play_analysis_success_sound() -> void:
	if MusicManager and MusicManager.has_method("play_analysis_success"):
		MusicManager.play_analysis_success()


func _notify_task_success(task_kind: String, toast_text: String, batch_continues: bool) -> void:
	_play_analysis_success_sound()
	if not _gen_status_enabled():
		return
	var toast_sec := maxf(1.0, _get_queue_toast_seconds())
	if batch_continues:
		_show_batch_completion_toast(task_kind, toast_text, toast_sec)
	else:
		_push_gen_message(task_kind, toast_text, "success", toast_sec, "", "", "analysis_success")


func _show_batch_completion_toast(op_id: String, text: String, duration_sec: float) -> void:
	var dock := _status_dock()
	if dock == null:
		return
	dock.show_transient("%s_batch_done" % op_id, text, "success", duration_sec, false)


func _notify_os_background_done() -> void:
	var loop := Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return
	var win: Node = (loop as SceneTree).root.get_node_or_null("/root/AppWindowManager")
	if win and win.has_method("notify_background_task_done"):
		win.notify_background_task_done()

func _init(game_engine_ref: Node = null):
	_game_engine = game_engine_ref
	_api = preload("res://server/generation_api_client.gd").new()
	add_child(_api)
	_api.bpm_started.connect(_on_bpm_started)
	_api.bpm_completed.connect(_on_bpm_completed)
	_api.bpm_error.connect(_on_bpm_error)
	_api.notes_started.connect(_on_notes_started)
	_api.notes_completed.connect(_on_notes_completed)
	_api.notes_error.connect(_on_notes_error)
	_api.bpm_status.connect(_on_bpm_status)
	_api.notes_status.connect(_on_notes_status)
	_api.genres_status.connect(_on_genres_status)
	_api.genres_completed.connect(_on_genres_completed)


func _get_display_name(song_path: String) -> String:
	var meta = SongLibrary.get_metadata_for_song(song_path)
	var artist = String(meta.get("artist", "Неизвестен")).strip_edges()
	var title = String(meta.get("title", "Н/Д")).strip_edges()
	if title == "" or title == "Н/Д" or title.to_lower() == "без названия":
		var stem = song_path.get_file().get_basename()
		if " - " in stem:
			var parts = stem.split(" - ", false, 1)
			if parts.size() == 2:
				var a = parts[0].strip_edges()
				var t = parts[1].strip_edges()
				if a != "": artist = a
				if t != "": title = t
		elif " — " in stem:
			var parts2 = stem.split(" — ", false, 1)
			if parts2.size() == 2:
				var a2 = parts2[0].strip_edges()
				var t2 = parts2[1].strip_edges()
				if a2 != "": artist = a2
				if t2 != "": title = t2
		elif " – " in stem:
			var parts3 = stem.split(" – ", false, 1)
			if parts3.size() == 2:
				var a3 = parts3[0].strip_edges()
				var t3 = parts3[1].strip_edges()
				if a3 != "": artist = a3
				if t3 != "": title = t3
		if title == "" or title == "Н/Д" or title.to_lower() == "без названия":
			title = song_path.get_file().get_basename()
	return "%s - %s" % [artist, title]

func _ensure_generation_backend() -> Dictionary:
	if GenerationProcessManager == null:
		return {"ok": true}
	return GenerationProcessManager.ensure_running()

func _backend_error_message(result: Dictionary) -> String:
	var key := str(result.get("error_key", "GEN_WORKER_START_FAILED"))
	var base := tr(key)
	var detail := str(result.get("detail", "")).strip_edges()
	if detail == "":
		return base
	return "%s (%s)" % [base, detail]


func _show_backend_starting_status(task_type: String, display_name: String) -> void:
	if not _gen_status_enabled():
		return
	var cancel_method := "cancel_notes" if task_type == "notes" else "cancel_bpm"
	var title: String = display_name if _GenStatusMode.is_compact() else "%s — %s" % [display_name, tr("GEN_WORKER_STARTING")]
	var subtitle := tr("GEN_STATUS_NETWORK_WAIT") + _queue_summary_suffix()
	_push_gen_operation(task_type, title, subtitle, 0, 1, cancel_method, "network")


func _schedule_backend_retry() -> void:
	if _backend_retry_timer == null:
		_backend_retry_timer = Timer.new()
		_backend_retry_timer.one_shot = true
		_backend_retry_timer.timeout.connect(_on_backend_retry_timeout)
		add_child(_backend_retry_timer)
	if _backend_retry_timer.is_stopped():
		_backend_retry_timer.wait_time = BACKEND_RETRY_SEC
		_backend_retry_timer.start()


func _clear_backend_retry_if_idle() -> void:
	if _backend_retry_timer == null:
		return
	if (_active_bpm_task.is_empty() or _bpm_request_sent) and (_active_notes_task.is_empty() or _notes_request_sent):
		_backend_retry_timer.stop()


func _clear_offline_pause() -> void:
	_offline_paused = false
	_offline_pause_message = ""
	_offline_banner_dismissed = false


func _offline_status_op_id() -> String:
	if _active_bpm_task.has("path") and not _bpm_request_sent:
		return "bpm"
	if _active_notes_task.has("path") and not _notes_request_sent:
		return "notes"
	return "bpm"


func _show_offline_banner(task_type: String) -> void:
	if not _gen_status_enabled() or _offline_pause_message.strip_edges() == "":
		return
	var text := tr("GEN_QUEUE_OFFLINE_BANNER") % _offline_pause_message
	_push_gen_message(
		task_type,
		text,
		"error",
		0.0,
		"retry_offline_pipeline",
		"dismiss_offline_banner"
	)


func dismiss_offline_banner() -> void:
	_offline_banner_dismissed = true
	var dock := _status_dock()
	if dock:
		dock.clear_operation(_offline_status_op_id())


func _enter_offline_pause(task_type: String, backend: Dictionary) -> void:
	var task: Dictionary = _active_bpm_task if task_type == "bpm" else _active_notes_task
	if task.is_empty():
		return
	var backend_msg := _backend_error_message(backend)
	var first_pause := not _offline_paused
	_offline_paused = true
	_offline_pause_message = backend_msg
	_schedule_backend_retry()
	if first_pause and not _offline_banner_dismissed:
		_show_offline_banner(task_type)
	_emit_queue_changed()


func _resume_offline_pipeline_attempt() -> void:
	if _active_bpm_task.has("path") and not _bpm_request_sent:
		_try_start_active_bpm()
	elif _active_notes_task.has("path") and not _notes_request_sent:
		_try_start_active_notes()
	elif _offline_paused:
		_schedule_backend_retry()


func retry_offline_pipeline() -> void:
	_offline_banner_dismissed = false
	_resume_offline_pipeline_attempt()
	if _offline_paused and _gen_status_enabled():
		_show_offline_banner(_offline_status_op_id())
	_emit_queue_changed()


func _mark_active_task_started() -> void:
	_active_task_started_unix = int(Time.get_unix_time_from_system())


func _record_active_task_duration() -> void:
	if _active_task_started_unix <= 0:
		return
	var elapsed := float(int(Time.get_unix_time_from_system()) - _active_task_started_unix)
	_active_task_started_unix = 0
	if elapsed < 1.0:
		return
	_duration_samples.append(elapsed)
	while _duration_samples.size() > DURATION_SAMPLES_MAX:
		_duration_samples.pop_front()


func _average_task_duration_sec() -> float:
	if _duration_samples.is_empty():
		return DEFAULT_TASK_DURATION_SEC
	var total := 0.0
	for sample in _duration_samples:
		total += float(sample)
	return total / float(_duration_samples.size())


func _estimate_remaining_sec() -> int:
	var pending := _bpm_queue.size() + _notes_queue.size()
	var active_count := int(_active_bpm_task.has("path")) + int(_active_notes_task.has("path"))
	if pending <= 0 and active_count <= 0:
		return 0
	var avg := _average_task_duration_sec()
	var active_remaining := avg
	if _active_task_started_unix > 0:
		var elapsed := float(int(Time.get_unix_time_from_system()) - _active_task_started_unix)
		active_remaining = maxf(5.0, avg - elapsed)
	elif active_count <= 0:
		active_remaining = 0.0
	return int(round(active_remaining + avg * float(pending)))


func clear_all_queue_work(cancel_active: bool = true) -> void:
	_bpm_queue.clear()
	_notes_queue.clear()
	_clear_offline_pause()
	if cancel_active:
		if _active_bpm_task.has("path"):
			cancel_bpm()
		elif _active_notes_task.has("path"):
			cancel_notes()
	else:
		_emit_queue_changed()


func _try_start_active_bpm() -> void:
	if not _active_bpm_task.has("path") or _bpm_request_sent:
		return
	if is_notes_pipeline_busy():
		_push_pipeline_waiting_status("bpm")
		_schedule_backend_retry()
		return
	var backend := _ensure_generation_backend()
	if backend.get("ok", false):
		_clear_offline_pause()
		_bpm_request_sent = true
		_mark_active_task_started()
		_api.analyze_bpm(_active_bpm_task.path)
		_clear_backend_retry_if_idle()
		return
	if backend.get("pending", false):
		_show_backend_starting_status("bpm", _active_bpm_task.get("display", _get_display_name(_active_bpm_task.path)))
		_schedule_backend_retry()
		return
	_enter_offline_pause("bpm", backend)


func _try_start_active_notes() -> void:
	if not _active_notes_task.has("path") or _notes_request_sent:
		return
	if is_bpm_pipeline_busy():
		_push_pipeline_waiting_status("notes")
		_schedule_backend_retry()
		return
	var backend := _ensure_generation_backend()
	if backend.get("ok", false):
		_clear_offline_pause()
		_notes_request_sent = true
		_mark_active_task_started()
		print(
			"[GenQueue] start goal=%s difficulty=%s stem=%s path=%s"
			% [
				str(_active_notes_task.get("goal", "")),
				str(_active_notes_task.get("difficulty", "")),
				str(_active_notes_task.get("chart_stem", "")),
				str(_active_notes_task.get("path", "")).get_file(),
			]
		)
		_api.generate_notes_for_task(_active_notes_task)
		_clear_backend_retry_if_idle()
		return
	if backend.get("pending", false):
		_show_backend_starting_status("notes", _active_notes_task.get("display", _get_display_name(_active_notes_task.path)))
		_schedule_backend_retry()
		return
	_enter_offline_pause("notes", backend)


func _on_backend_retry_timeout() -> void:
	if _offline_paused:
		_resume_offline_pipeline_attempt()
		return
	if _active_bpm_task.has("path") and not _bpm_request_sent:
		_try_start_active_bpm()
	if _active_notes_task.has("path") and not _notes_request_sent:
		_try_start_active_notes()

func is_notes_pipeline_busy() -> bool:
	return _active_notes_task.has("path") or not _notes_queue.is_empty()


func is_bpm_pipeline_busy() -> bool:
	return _active_bpm_task.has("path") or not _bpm_queue.is_empty()


func is_generation_backend_busy() -> bool:
	return is_notes_pipeline_busy() or is_bpm_pipeline_busy()


func start_bpm_analysis(song_path: String) -> int:
	var existing_pos := get_bpm_queue_position(song_path)
	if existing_pos > 0:
		return 0
	if _active_bpm_task.has("path") or is_notes_pipeline_busy():
		_bpm_queue.append(song_path)
		_emit_queue_changed()
		return get_bpm_queue_position(song_path)
	_active_bpm_task = {"path": song_path, "display": _get_display_name(song_path)}
	_last_bpm_task = _active_bpm_task.duplicate(true)
	_bpm_request_sent = false
	_active_bpm_progress.clear()
	_try_start_active_bpm()
	_emit_queue_changed()
	return 1

func start_notes_generation(
	song_path: String,
	instrument: String,
	bpm: float,
	lanes: int,
	tolerance: float,
	auto_identify: bool,
	artist: String,
	title: String,
	mode: String,
	chart_tag: String = "",
	chart_intent: String = "",
	goal: String = "",
	difficulty: String = ""
) -> int:
	var intent := str(chart_intent).strip_edges()
	if intent == "":
		intent = _GenerationIntents.resolve_chart_stem(mode)
	var goal_v := str(goal).strip_edges().to_lower()
	var difficulty_v := str(difficulty).strip_edges().to_lower()
	if goal_v == "" or difficulty_v == "":
		var pair := _GoalDiff.from_intent(intent)
		if goal_v == "":
			goal_v = str(pair.get("goal", _GoalDiff.DEFAULT_GOAL))
		if difficulty_v == "":
			difficulty_v = str(pair.get("difficulty", _GoalDiff.DEFAULT_DIFFICULTY))
	var api_mode := mode
	if _GenerationIntents.is_chart_intent(mode):
		api_mode = _GenerationIntents.intent_to_legacy_mode(mode)
	elif intent != "":
		api_mode = _GenerationIntents.intent_to_legacy_mode(intent)
	var chart_stem := _GoalDiff.chart_stem(goal_v, difficulty_v)
	print(
		"[GenQueue] enqueue goal=%s difficulty=%s stem=%s file=%s"
		% [goal_v, difficulty_v, chart_stem, song_path.get_file()]
	)
	if get_notes_queue_position(song_path, instrument, chart_stem, lanes) > 0:
		return 0
	var queued := {
		"path": song_path,
		"instrument": instrument,
		"bpm": bpm,
		"lanes": lanes,
		"tolerance": tolerance,
		"auto_identify": auto_identify,
		"artist": artist,
		"title": title,
		"mode": api_mode,
		"chart_intent": intent,
		"chart_stem": chart_stem,
		"chart_tag": chart_tag,
		"goal": goal_v,
		"difficulty": difficulty_v,
	}
	if is_bpm_pipeline_busy():
		_notes_queue.append(queued)
		_emit_queue_changed()
		return get_notes_queue_position(song_path, instrument, chart_stem, lanes)
	if _active_notes_task.has("path"):
		_notes_queue.append(queued)
		_emit_queue_changed()
		return get_notes_queue_position(song_path, instrument, chart_stem, lanes)
	_active_notes_task = {
		"path": song_path,
		"display": _get_display_name(song_path),
		"instrument": instrument,
		"bpm": bpm,
		"lanes": lanes,
		"tolerance": tolerance,
		"auto_identify": auto_identify,
		"artist": artist,
		"title": title,
		"mode": api_mode,
		"chart_intent": intent,
		"chart_stem": chart_stem,
		"chart_tag": chart_tag,
		"goal": goal_v,
		"difficulty": difficulty_v,
	}
	_last_notes_task = _active_notes_task.duplicate(true)
	_notes_request_sent = false
	_active_notes_progress.clear()
	_try_start_active_notes()
	_emit_queue_changed()
	return 1

func get_genres_for_manual_entry(artist: String, title: String):
	var backend := _ensure_generation_backend()
	if not backend.get("ok", false):
		return
	_api.detect_genres(artist, title)

func cancel_bpm():
	if _api:
		_api.request_cancel_bpm()
	var cancelled_path := ""
	var cancelled_disp := ""
	if _active_bpm_task.has("path"):
		cancelled_path = _active_bpm_task.path
		cancelled_disp = _active_bpm_task.display
		var cancelled_key := _song_path_key(_active_bpm_task.path)
		var remaining: Array[String] = []
		for queued_path in _bpm_queue:
			if _song_path_key(queued_path) != cancelled_key:
				remaining.append(queued_path)
		_bpm_queue = remaining
		if _game_engine and _game_engine.has_method("get_achievement_system"):
			var ach = _game_engine.get_achievement_system()
			if ach and ach.has_method("on_analysis_canceled"):
				ach.on_analysis_canceled()
	if _gen_status_enabled():
		_push_gen_message("bpm", tr("GEN_NOTIF_BPM_CANCELLED"), "success", 3.0, "", "cancel_bpm")
	if cancelled_path != "":
		_push_queue_history("bpm", cancelled_disp, tr("GEN_QUEUE_ROW_BPM"), "cancelled")
		_active_bpm_task.clear()
		_bpm_request_sent = false
		_record_active_task_duration()
		bpm_error.emit(cancelled_path, tr("GEN_NOTIF_BPM_CANCELLED"), cancelled_disp)
	_clear_offline_pause()
	_clear_backend_retry_if_idle()
	_active_bpm_progress.clear()
	_emit_queue_changed()

func cancel_notes():
	if _api:
		_api.request_cancel_notes()
	var cancelled_path := ""
	var cancelled_disp := ""
	if _active_notes_task.has("path"):
		cancelled_path = _active_notes_task.path
		cancelled_disp = _active_notes_task.display
		var cancelled_key := _song_path_key(_active_notes_task.path)
		var remaining: Array[Dictionary] = []
		for item in _notes_queue:
			if _song_path_key(item.get("path", "")) != cancelled_key:
				remaining.append(item)
		_notes_queue = remaining
		if _game_engine and _game_engine.has_method("get_achievement_system"):
			var ach = _game_engine.get_achievement_system()
			if ach and ach.has_method("on_analysis_canceled"):
				ach.on_analysis_canceled()
	if _gen_status_enabled():
		_push_gen_message("notes", tr("GEN_NOTIF_NOTES_CANCELLED"), "success", 3.0, "", "cancel_notes")
	if cancelled_path != "":
		var history_job := _active_notes_task.duplicate(true)
		_push_queue_history("notes", cancelled_disp, _notes_settings_line(history_job), "cancelled")
		_active_notes_task.clear()
		_notes_request_sent = false
		_record_active_task_duration()
		notes_error.emit(cancelled_path, tr("GEN_NOTIF_NOTES_CANCELLED"), cancelled_disp)
	_clear_offline_pause()
	_clear_backend_retry_if_idle()
	_active_notes_progress.clear()
	_emit_queue_changed()

func retry_bpm():
	var t = _active_bpm_task
	if t.is_empty():
		t = _last_bpm_task
	if t.has("path"):
		start_bpm_analysis(t.path)

func retry_notes():
	var t = _active_notes_task
	if t.is_empty():
		t = _last_notes_task
	if t.has("path"):
		start_notes_generation(
			t.path,
			t.instrument,
			t.bpm,
			t.lanes,
			t.tolerance,
			t.auto_identify,
			t.artist,
			t.title,
			t.mode,
			str(t.get("chart_tag", "")),
			str(t.get("chart_intent", "")),
			str(t.get("goal", "")),
			str(t.get("difficulty", "")),
		)

func _on_bpm_started():
	if _active_bpm_task.has("path"):
		var path = _active_bpm_task.path
		var disp = _active_bpm_task.display
		bpm_started.emit(path, disp)
		if _gen_status_enabled():
			var total := 1 + _bpm_queue.size()
			var title: String = disp if _GenStatusMode.is_compact() else tr("GEN_NOTIF_BPM_FOR") % [disp, total]
			_push_gen_operation("bpm", title, "", 0, _BPM_STAGES.size(), "cancel_bpm", "bpm")

func _on_bpm_completed(bpm_value: int):
	if not _active_bpm_task.has("path"):
		return
	var path = _active_bpm_task.path
	var disp = _active_bpm_task.display
	_push_queue_history("bpm", disp, tr("GEN_QUEUE_ROW_BPM"), "done")
	SongLibrary.update_metadata(path, {"bpm": str(bpm_value), "bpm_from_server": true})
	_record_active_task_duration()
	_active_bpm_task.clear()
	_bpm_request_sent = false
	bpm_completed.emit(path, bpm_value, disp)
	if _game_engine and _game_engine.has_method("get_achievement_system"):
		var ach = _game_engine.get_achievement_system()
		if ach and ach.has_method("on_bpm_computed"):
			ach.on_bpm_computed()
	var batch_continues := _bpm_queue.size() > 0 or _notes_queue.size() > 0
	_notify_task_success("bpm", tr("GEN_NOTIF_BPM_DONE") % [bpm_value, disp], batch_continues)
	if _bpm_queue.size() > 0:
		_start_next_bpm_from_queue()
	elif _notes_queue.size() > 0 and not _active_notes_task.has("path"):
		_start_next_notes_from_queue()
	_clear_backend_retry_if_idle()
	_active_bpm_progress.clear()
	_emit_queue_changed()

func _on_bpm_error(message: String):
	if not _active_bpm_task.has("path"):
		if _bpm_queue.size() > 0:
			_start_next_bpm_from_queue()
		return
	var disp = _active_bpm_task.display
	var path = _active_bpm_task.path
	var cancelled := SongSelectStrings.is_cancel_message(message)
	if cancelled:
		_push_queue_history("bpm", disp, tr("GEN_QUEUE_ROW_BPM"), "cancelled")
	else:
		_push_queue_history("bpm", disp, tr("GEN_QUEUE_ROW_BPM"), "error")
	_record_active_task_duration()
	_active_bpm_task.clear()
	_bpm_request_sent = false
	bpm_error.emit(path, message, disp)
	if not cancelled and _gen_status_enabled():
		var show_msg = tr("GEN_NOTIF_BPM_ERROR") % message
		_push_gen_message("bpm", show_msg, "error", 0.0, "retry_bpm", "cancel_bpm")
	if _bpm_queue.size() > 0:
		_start_next_bpm_from_queue()
	elif _notes_queue.size() > 0 and not _active_notes_task.has("path"):
		_start_next_notes_from_queue()
	_clear_backend_retry_if_idle()
	_active_bpm_progress.clear()
	_emit_queue_changed()

func _on_bpm_status(status: String) -> void:
	if _active_bpm_task.has("path"):
		var disp = _active_bpm_task.display
		var total := 1 + _bpm_queue.size()
		var k := _stage_index_for(status, _BPM_STAGES)
		var stage_key := str(_BPM_STAGES[k - 1]) if k > 0 and k <= _BPM_STAGES.size() else ""
		if _gen_status_enabled():
			var title: String = disp if _GenStatusMode.is_compact() else "%s (1/%d)" % [disp, total]
			var subtitle := status
			if _GenStatusMode.is_full():
				subtitle = "%s%s" % [_stage_count_label(k, _BPM_STAGES.size()), status]
			var icon_kind := _operation_icon_kind("bpm", status, stage_key)
			_push_gen_operation("bpm", title, subtitle, k, _BPM_STAGES.size(), "cancel_bpm", icon_kind)
		bpm_progress.emit(_active_bpm_task.path, k, _BPM_STAGES.size(), status)
		_store_bpm_progress(k, status, stage_key)

func _on_notes_started():
	if _active_notes_task.has("path"):
		var disp = _active_notes_task.display
		notes_started.emit(_active_notes_task.path, disp)
		if _gen_status_enabled():
			var total := 1 + _notes_queue.size()
			var instr_s = String(_active_notes_task.get("instrument", "drums"))
			var lookup_key := _GenerationIntents.chart_lookup_key_from_job(_active_notes_task)
			var lanes_val = int(_active_notes_task.get("lanes", 4))
			var suffix = _notes_notification_suffix(
				instr_s,
				lookup_key,
				lanes_val,
				str(_active_notes_task.get("goal", "")),
				str(_active_notes_task.get("difficulty", "")),
			)
			var title: String = disp if _GenStatusMode.is_compact() else tr("GEN_NOTIF_NOTES_FOR") % [disp, total, suffix]
			var subtitle := suffix.strip_edges() if _GenStatusMode.is_compact() else ""
			_push_gen_operation("notes", title, subtitle, 0, _NOTES_STAGES.size(), "cancel_notes", "music")
		_emit_queue_changed()

func _persist_rhythm_dna_for_chart(
	chart_dst: String,
	song_path: String,
	instrument: String,
	mode: String,
	lanes: int,
	note_count: int,
	bpm: float,
	rhythm_dna: Dictionary
) -> bool:
	var payload := rhythm_dna.duplicate(true) if rhythm_dna is Dictionary else {}
	if payload.is_empty() or NotesUtils.is_minimal_rhythm_dna(payload):
		return false
	var meta: Dictionary = payload.get("meta", {}) if payload.get("meta", {}) is Dictionary else {}
	if meta.has("incomplete"):
		meta.erase("incomplete")
		meta.erase("reason")
		if meta.is_empty():
			payload.erase("meta")
		else:
			payload["meta"] = meta
	var warnings: Array = payload.get("warnings", []) if payload.get("warnings", []) is Array else []
	var cleaned: Array = []
	for item in warnings:
		if item is Dictionary:
			var key := String(item.get("key", ""))
			if key in ["DNA_WARN_CLIENT_FALLBACK", "DNA_WARN_LEGACY_CHART"]:
				continue
		cleaned.append(item)
	payload["warnings"] = cleaned
	if payload.is_empty():
		return false
	if not NotesUtils.save_rhythm_dna_at_chart(chart_dst, payload):
		push_warning("Rhythm DNA save failed: %s -> %s" % [
			chart_dst,
			NotesUtils.rhythm_dna_path_for_chart(chart_dst),
		])
		return false
	return true


func _on_notes_completed(
	notes_data: Array,
	bpm_value: float,
	instrument_type: String,
	notes_variants: Dictionary,
	rhythm_dna: Dictionary = {}
):
	var t = _active_notes_task
	if t.is_empty():
		t = _last_notes_task
	if not t.has("path"):
		return
	var path = t.path
	var disp = t.display
	var gen_mode = t.mode
	var save_stem := _task_chart_stem(t)
	var lanes_val = int(t.get("lanes", 4))
	var save_instrument = instrument_type if instrument_type != "" else String(t.get("instrument", "drums"))
	var variant_tag := NotesUtils.resolve_generation_save_chart_tag(t)
	DirectoryUtils.ensure_dir(NotesUtils.get_notes_root())
	var saved_any_variant := false
	var rhythm_dna_saved := false
	var duration_sec := ChartDifficultyAnalyzer.parse_duration_seconds(SongLibrary.get_metadata_for_song(path).get("duration", "00:00"))
	var stats_for_mode: Dictionary = {}
	var meta_for_bpm := SongLibrary.get_metadata_for_song(path)
	var track_bpm := NotesUtils._parse_bpm_from_metadata(meta_for_bpm)
	if track_bpm <= 0.0:
		track_bpm = bpm_value
	var task_id := ""
	if _api and _api.has_method("get_last_notes_task_id"):
		task_id = str(_api.get_last_notes_task_id())
	if rhythm_dna.is_empty() or NotesUtils.is_minimal_rhythm_dna(rhythm_dna):
		push_warning("RhythmDNA: generation response empty — fetching from server (task_id=%s)" % task_id)
		var fetched: Dictionary = _RhythmDnaServerFetch.fetch_for_song(
			path, save_stem, save_instrument, task_id
		)
		if not fetched.is_empty():
			rhythm_dna = fetched
	elif not rhythm_dna.is_empty():
		var pl: Dictionary = rhythm_dna.get("pipeline", {}) if rhythm_dna.get("pipeline", {}) is Dictionary else {}
		push_warning("RhythmDNA: received in generation response (source=%s)" % str(pl.get("source", 0)))
	var chart_lanes := NotesUtils.CANONICAL_MAX_LANES
	if notes_data is Array and not notes_data.is_empty():
		var save_notes: Array = notes_data
		if NotesUtils.save_mode_chart_array(path, save_instrument, save_stem, chart_lanes, save_notes, variant_tag):
			saved_any_variant = true
			if variant_tag == "":
				stats_for_mode = ChartDifficultyAnalyzer.analyze(
					save_notes, duration_sec, ChartDifficultyAnalyzer.CANONICAL_STATS_LANES, bpm_value, save_instrument
				)
				if not stats_for_mode.is_empty():
					SongLibrary.set_chart_difficulty_variant(path, save_instrument, save_stem, stats_for_mode)
	elif notes_variants is Dictionary and notes_variants.size() > 0:
		# Legacy server: pick the largest lane variant once and save unified.
		var best_key := ""
		var best_lanes := 0
		for lane_key in notes_variants.keys():
			var variant_lanes := int(str(lane_key))
			if variant_lanes > best_lanes:
				best_lanes = variant_lanes
				best_key = str(lane_key)
		if best_key != "":
			var legacy_notes = notes_variants.get(best_key, null)
			if legacy_notes is Array and NotesUtils.save_mode_chart_array(
				path, save_instrument, save_stem, maxi(best_lanes, chart_lanes), legacy_notes, variant_tag
			):
				saved_any_variant = true
	if saved_any_variant:
		var dna_chart := NotesUtils.preferred_mode_chart_path(path, save_instrument, save_stem, variant_tag)
		var dna_note_count := notes_data.size() if notes_data is Array else 0
		rhythm_dna_saved = _persist_rhythm_dna_for_chart(
			dna_chart,
			path,
			save_instrument,
			save_stem,
			chart_lanes,
			dna_note_count,
			track_bpm,
			rhythm_dna
		)
	if saved_any_variant and not rhythm_dna_saved:
		push_warning("RhythmDNA: not saved — server report missing for %s" % save_stem)
	elif saved_any_variant and rhythm_dna_saved:
		var pipeline: Dictionary = rhythm_dna.get("pipeline", {}) if rhythm_dna is Dictionary else {}
		push_warning("RhythmDNA: saved FULL -> %s (source=%s, notes=%s)" % [
			NotesUtils.rhythm_dna_path_for_mode(path, save_instrument, save_stem, variant_tag),
			str(pipeline.get("source", 0)),
			str(pipeline.get("final_notes", 0)),
		])
	if saved_any_variant:
		var note_count := notes_data.size() if notes_data is Array else 0
		var pipeline: Dictionary = rhythm_dna.get("pipeline", {}) if rhythm_dna is Dictionary else {}
		var server_final := int(pipeline.get("final_notes", note_count))
		push_warning(
			"GenDone: %s | saved=%d server_final=%d stem=%s goal=%s diff=%s -> %s"
			% [
				disp,
				note_count,
				server_final,
				save_stem,
				str(t.get("goal", "")),
				str(t.get("difficulty", "")),
				NotesUtils.preferred_mode_chart_path(path, save_instrument, save_stem, variant_tag),
			]
		)
		print(
			"[GenDone] %s | saved=%d server_final=%d stem=%s goal=%s diff=%s"
			% [
				disp,
				note_count,
				server_final,
				save_stem,
				str(t.get("goal", "")),
				str(t.get("difficulty", "")),
			]
		)
	if saved_any_variant and PlayerDataManager:
		PlayerDataManager.record_last_chart_generation(path, save_instrument, save_stem, lanes_val)
	notes_completed.emit(path, save_instrument, disp)
	if _game_engine and _game_engine.has_method("get_achievement_system"):
		var ach = _game_engine.get_achievement_system()
		if ach and ach.has_method("on_notes_generated"):
			ach.on_notes_generated()
	var done_suffix := _notes_notification_suffix(
		save_instrument,
		save_stem,
		lanes_val,
		str(t.get("goal", "")),
		str(t.get("difficulty", "")),
	)
	var batch_continues := _notes_queue.size() > 0 or _bpm_queue.size() > 0
	_notify_task_success(
		"notes",
		tr("GEN_NOTIF_NOTES_DONE") % [disp, done_suffix],
		batch_continues
	)
	if not batch_continues:
		_notify_os_background_done()
	if _song_has_genres(path):
		_skip_auto_identify_for_queued_notes(path)
	_push_queue_history("notes", disp, _notes_settings_line(t), "done")
	_record_active_task_duration()
	_active_notes_task.clear()
	_notes_request_sent = false
	if _notes_queue.size() > 0:
		_start_next_notes_from_queue()
	elif _bpm_queue.size() > 0 and not _active_bpm_task.has("path"):
		_start_next_bpm_from_queue()
	_clear_backend_retry_if_idle()
	_active_notes_progress.clear()
	_emit_queue_changed()

func _on_notes_error(message: String):
	if not _active_notes_task.has("path"):
		if _notes_queue.size() > 0:
			_start_next_notes_from_queue()
		return
	var disp = _active_notes_task.display
	var path = _active_notes_task.path
	var cancelled := SongSelectStrings.is_cancel_message(message)
	var history_settings := _notes_settings_line(_active_notes_task)
	notes_error.emit(path, message, disp)
	if cancelled:
		_push_queue_history("notes", disp, history_settings, "cancelled")
		_record_active_task_duration()
		_active_notes_task.clear()
		_notes_request_sent = false
		if _notes_queue.size() > 0:
			_start_next_notes_from_queue()
		elif _bpm_queue.size() > 0 and not _active_bpm_task.has("path"):
			_start_next_bpm_from_queue()
		_clear_backend_retry_if_idle()
		_active_notes_progress.clear()
		_emit_queue_changed()
		return
	_push_queue_history("notes", disp, history_settings, "error")
	_record_active_task_duration()
	if _gen_status_enabled():
		var ei = String(_active_notes_task.get("instrument", "drums"))
		var lookup_key := _GenerationIntents.chart_lookup_key_from_job(_active_notes_task)
		var lanes_val = int(_active_notes_task.get("lanes", 4))
		var suffix = _notes_notification_suffix(
			ei,
			lookup_key,
			lanes_val,
			str(_active_notes_task.get("goal", "")),
			str(_active_notes_task.get("difficulty", "")),
		)
		var show_msg = tr("GEN_NOTIF_NOTES_ERROR") % [disp, message, suffix]
		_push_gen_message("notes", show_msg, "error", 0.0, "retry_notes", "cancel_notes")
	_active_notes_task.clear()
	_notes_request_sent = false
	if _notes_queue.size() > 0:
		_start_next_notes_from_queue()
	elif _bpm_queue.size() > 0 and not _active_bpm_task.has("path"):
		_start_next_bpm_from_queue()
	_clear_backend_retry_if_idle()
	_active_notes_progress.clear()
	_emit_queue_changed()

func _on_notes_status(status: String) -> void:
	if _active_notes_task.has("path"):
		var disp = _active_notes_task.display
		var total := 1 + _notes_queue.size()
		var k := _stage_index_for(status, _NOTES_STAGES)
		var stage_key := str(_NOTES_STAGES[k - 1]) if k > 0 and k <= _NOTES_STAGES.size() else ""
		if _gen_status_enabled():
			var instr_s = String(_active_notes_task.get("instrument", "drums"))
			var lookup_key := _GenerationIntents.chart_lookup_key_from_job(_active_notes_task)
			var lanes_val = int(_active_notes_task.get("lanes", 4))
			var suffix = _notes_notification_suffix(
				instr_s,
				lookup_key,
				lanes_val,
				str(_active_notes_task.get("goal", "")),
				str(_active_notes_task.get("difficulty", "")),
			)
			var title: String = disp if _GenStatusMode.is_compact() else "%s (1/%d)" % [disp, total]
			var subtitle := status
			if _GenStatusMode.is_full():
				subtitle = "%s%s%s" % [_stage_count_label(k, _NOTES_STAGES.size()), status, suffix]
			elif suffix.strip_edges() != "":
				subtitle = "%s %s" % [status, suffix.strip_edges()]
			var icon_kind := _operation_icon_kind("notes", status, stage_key)
			_push_gen_operation("notes", title, subtitle, k, _NOTES_STAGES.size(), "cancel_notes", icon_kind)
		notes_progress.emit(_active_notes_task.path, k, _NOTES_STAGES.size(), status)
		_store_notes_progress(k, status, stage_key)

func _on_genres_status(status: String):
	pass

func _on_genres_completed(artist: String, title: String, genres: Array):
	var path = ""
	if _active_notes_task.has("path"):
		path = _active_notes_task.path
	elif _last_notes_task.has("path"):
		path = _last_notes_task.path
	if path != "":
		if genres.size() > 0:
			var primary = str(genres[0])
			print("[Genres] Update for %s: %s (primary: %s)" % [path, ", ".join(genres), primary])
			SongLibrary.update_metadata(path, {"genres": genres, "primary_genre": primary, "genre_from_server": true})
			_skip_auto_identify_for_queued_notes(path)
		else:
			print("[Genres] Empty genres received; keeping existing metadata for %s" % path)

func get_active_bpm_task() -> Dictionary:
	return _active_bpm_task.duplicate(true)

func get_active_notes_task() -> Dictionary:
	return _active_notes_task.duplicate(true)

func get_last_notes_task() -> Dictionary:
	return _last_notes_task.duplicate(true)

func get_bpm_queue_position(song_path: String) -> int:
	var key := _song_path_key(song_path)
	if key == "":
		return 0
	if _active_bpm_task.has("path") and _song_path_key(_active_bpm_task.path) == key:
		return 1
	for i in range(_bpm_queue.size()):
		if _song_path_key(_bpm_queue[i]) == key:
			return i + 2
	return 0

func get_notes_queue_position(song_path: String, instrument: String, mode: String, lanes: int) -> int:
	var key := _song_path_key(song_path)
	if key == "":
		return 0
	if _active_notes_task.has("path"):
		if _notes_job_matches_query(_active_notes_task, key, instrument, mode, lanes):
			return 1
	for i in range(_notes_queue.size()):
		var item: Dictionary = _notes_queue[i]
		if _notes_job_matches_query(item, key, instrument, mode, lanes):
			return i + 2
	return 0

func notes_job_matches(
	song_path: String,
	instrument: String,
	mode_or_intent: String,
	lanes: int,
	item: Dictionary
) -> bool:
	return _notes_job_matches_query(item, _song_path_key(song_path), instrument, mode_or_intent, lanes)


func _task_chart_stem(job: Dictionary) -> String:
	var stored := str(job.get("chart_stem", "")).strip_edges().to_lower()
	if stored != "":
		return stored
	var goal_v := str(job.get("goal", "")).strip_edges().to_lower()
	var difficulty_v := str(job.get("difficulty", "")).strip_edges().to_lower()
	if goal_v != "" and difficulty_v != "":
		return _GoalDiff.chart_stem(goal_v, difficulty_v)
	var intent := str(job.get("chart_intent", "")).strip_edges().to_lower()
	if intent != "":
		if _GoalDiff.is_chart_stem(intent):
			return intent
		return _GoalDiff.stem_from_intent_legacy(intent)
	return NotesUtils.resolve_mode_stem_key(str(job.get("mode", "")))


func _notes_job_matches_query(item: Dictionary, song_key: String, instrument: String, mode_or_intent: String, lanes: int) -> bool:
	if not item.has("path") or _song_path_key(item.get("path", "")) != song_key:
		return false
	if String(item.get("instrument", "")) != instrument:
		return false
	if int(item.get("lanes", 0)) != lanes:
		return false
	var query_stem := NotesUtils.resolve_mode_stem_key(mode_or_intent)
	return _task_chart_stem(item) == query_stem


func get_notes_queue_position_for_song(song_path: String) -> int:
	var key := _song_path_key(song_path)
	if key == "":
		return 0
	if _active_notes_task.has("path") and _song_path_key(_active_notes_task.get("path", "")) == key:
		return 1
	for i in range(_notes_queue.size()):
		if _song_path_key(_notes_queue[i].get("path", "")) == key:
			return i + 2
	return 0


func _song_path_key(path: String) -> String:
	return String(path).replace("\\", "/").strip_edges()


func is_song_metadata_edit_locked(song_path: String) -> bool:
	var key := _song_path_key(song_path)
	if key == "":
		return false
	if _active_bpm_task.has("path") and _song_path_key(_active_bpm_task.path) == key:
		return true
	for queued_path in _bpm_queue:
		if _song_path_key(queued_path) == key:
			return true
	if _active_notes_task.has("path") and _song_path_key(_active_notes_task.path) == key:
		return true
	for queued_task in _notes_queue:
		if _song_path_key(queued_task.get("path", "")) == key:
			return true
	return false

func _get_queue_toast_seconds() -> float:
	return float(SettingsManager.get_setting("generation_queue_delay_seconds", 5.0))


func _start_next_bpm_from_queue() -> void:
	if _offline_paused:
		return
	if _bpm_queue.is_empty():
		return
	var next_path = _bpm_queue[0]
	_bpm_queue.remove_at(0)
	start_bpm_analysis(next_path)
	_emit_queue_changed()


func _start_next_notes_from_queue() -> void:
	if _offline_paused:
		return
	if _notes_queue.is_empty():
		return
	if is_bpm_pipeline_busy():
		return
	var next = _notes_queue[0]
	_notes_queue.remove_at(0)
	var song_path := str(next.get("path", ""))
	var auto_identify := bool(next.get("auto_identify", true))
	if auto_identify and _song_has_genres(song_path):
		auto_identify = false
	start_notes_generation(
		song_path,
		next.get("instrument", "drums"),
		float(next.get("bpm", 120.0)),
		int(next.get("lanes", 4)),
		float(next.get("tolerance", 0.2)),
		auto_identify,
		next.get("artist", ""),
		next.get("title", ""),
		next.get("mode", "basic"),
		str(next.get("chart_tag", "")),
		str(next.get("chart_intent", "")),
		str(next.get("goal", "")),
		str(next.get("difficulty", "")),
	)
	_emit_queue_changed()


func _song_has_genres(song_path: String) -> bool:
	var metadata := SongLibrary.get_metadata_for_song(song_path)
	if metadata.has("genres"):
		if typeof(metadata["genres"]) == TYPE_ARRAY:
			if metadata["genres"].size() > 0:
				return true
		elif str(metadata["genres"]).strip_edges() != "":
			return true
	if metadata.has("primary_genre"):
		var pg := str(metadata["primary_genre"]).strip_edges().to_lower()
		if pg != "" and pg != "unknown":
			return true
	return false


func _skip_auto_identify_for_queued_notes(song_path: String) -> void:
	var key := _song_path_key(song_path)
	if key == "":
		return
	for i in range(_notes_queue.size()):
		var item: Dictionary = _notes_queue[i]
		if _song_path_key(str(item.get("path", ""))) == key:
			item["auto_identify"] = false
			_notes_queue[i] = item

func _instr_code(instrument: String) -> String:
	match instrument.to_lower():
		"drums":
			return tr("SONG_GEN_ABBR_DRUMS")
		"bass":
			return tr("SONG_GEN_ABBR_BASS")
		"fullmix":
			return tr("SONG_GEN_ABBR_FULLMIX")
		_:
			return instrument.substr(0, 1).to_upper()


func _notes_notification_suffix(
	instr: String,
	lookup_key: String,
	lanes_val: int,
	goal: String = "",
	difficulty: String = "",
) -> String:
	var goal_v := str(goal).strip_edges().to_lower()
	var difficulty_v := str(difficulty).strip_edges().to_lower()
	if goal_v == "" or difficulty_v == "":
		var pair := _GoalDiff.from_intent(lookup_key)
		if goal_v == "":
			goal_v = str(pair.get("goal", _GoalDiff.DEFAULT_GOAL))
		if difficulty_v == "":
			difficulty_v = str(pair.get("difficulty", _GoalDiff.DEFAULT_DIFFICULTY))
	return " (%s)" % SongSelectStrings.format_gen_settings_label(instr, lanes_val, goal_v, difficulty_v)


func _emit_queue_changed() -> void:
	if _queue_emit_pending:
		return
	_queue_emit_pending = true
	call_deferred("_flush_queue_changed")


func _flush_queue_changed() -> void:
	_queue_emit_pending = false
	queue_changed.emit(get_queue_snapshot())


func _store_bpm_progress(stage_index: int, stage_label: String, stage_key: String) -> void:
	var total := _BPM_STAGES.size()
	_active_bpm_progress = {
		"stage_index": stage_index,
		"stage_total": total,
		"stage_label": stage_label,
		"stage_key": stage_key,
		"progress01": clampf(float(stage_index) / float(maxi(total, 1)), 0.0, 1.0),
	}
	_emit_queue_changed()


func _store_notes_progress(stage_index: int, stage_label: String, stage_key: String) -> void:
	var total := _NOTES_STAGES.size()
	_active_notes_progress = {
		"stage_index": stage_index,
		"stage_total": total,
		"stage_label": stage_label,
		"stage_key": stage_key,
		"progress01": clampf(float(stage_index) / float(maxi(total, 1)), 0.0, 1.0),
	}
	_emit_queue_changed()


func _bpm_job_id(song_path: String) -> String:
	return "bpm:%s" % _song_path_key(song_path)


func _notes_job_id(job: Dictionary) -> String:
	return "notes:%s|%s|%s|%s|%s" % [
		_song_path_key(str(job.get("path", ""))),
		str(job.get("instrument", "")),
		_task_chart_stem(job),
		str(int(job.get("lanes", 0))),
		str(job.get("chart_tag", "")),
	]


func _notes_job_display(job: Dictionary) -> String:
	var path := str(job.get("path", ""))
	if job.has("display"):
		return str(job.get("display", ""))
	return _get_display_name(path)


func _pending_notes_blocked_by() -> String:
	if is_bpm_pipeline_busy():
		return "bpm"
	if _active_notes_task.has("path"):
		return "notes"
	return ""


func _serialize_bpm_item(path: String, position: int, state: String, queue_index: int = -1) -> Dictionary:
	var row := {
		"id": _bpm_job_id(path),
		"kind": "bpm",
		"state": state,
		"position": position,
		"path": path,
		"display": _get_display_name(path),
		"settings_line": tr("GEN_QUEUE_ROW_BPM"),
		"blocked_by": "",
	}
	if state == "pending" and queue_index >= 0:
		row["can_promote"] = queue_index > 0
		row["can_demote"] = queue_index < _bpm_queue.size() - 1
	return row


func _serialize_notes_item(
	job: Dictionary,
	position: int,
	state: String,
	blocked_by: String,
	queue_index: int = -1
) -> Dictionary:
	var intent := str(job.get("chart_intent", "")).strip_edges()
	if intent == "":
		intent = _GenerationIntents.resolve_chart_stem(str(job.get("mode", "")))
	var row := {
		"id": _notes_job_id(job),
		"kind": "notes",
		"state": state,
		"position": position,
		"path": str(job.get("path", "")),
		"display": _notes_job_display(job),
		"instrument": str(job.get("instrument", "")),
		"chart_intent": intent,
		"lanes": int(job.get("lanes", 0)),
		"settings_line": _notes_settings_line(job),
		"blocked_by": blocked_by,
	}
	if state == "pending" and queue_index >= 0:
		row["can_promote"] = queue_index > 0
		row["can_demote"] = queue_index < _notes_queue.size() - 1
	return row


func _notes_settings_line(job: Dictionary) -> String:
	var intent := str(job.get("chart_intent", "")).strip_edges()
	if intent == "":
		intent = _GenerationIntents.resolve_chart_stem(str(job.get("mode", "")))
	var goal_v := str(job.get("goal", "")).strip_edges().to_lower()
	var difficulty_v := str(job.get("difficulty", "")).strip_edges().to_lower()
	if goal_v == "" or difficulty_v == "":
		var pair := _GoalDiff.from_intent(intent)
		if goal_v == "":
			goal_v = str(pair.get("goal", _GoalDiff.DEFAULT_GOAL))
		if difficulty_v == "":
			difficulty_v = str(pair.get("difficulty", _GoalDiff.DEFAULT_DIFFICULTY))
	var goal_label := tr("GEN_GOAL_%s" % goal_v.to_upper())
	# Original is a single documentary chart — no Easy/Med/Hard / «Как в оригинале» suffix.
	var style_label := goal_label
	if _GoalDiff.sanitize_goal(goal_v) != "original":
		var diff_label := tr(_GoalDiff.difficulty_label_key(goal_v, difficulty_v))
		style_label = "%s · %s" % [goal_label, diff_label]
	var instrument := str(job.get("instrument", "drums")).strip_edges().to_lower()
	if instrument == "" or instrument == "standard":
		instrument = "drums"
	var inst_key := "GEN_INST_%s" % instrument.to_upper()
	var inst_label := tr(inst_key)
	if inst_label == inst_key:
		inst_label = instrument.capitalize()
	return tr("GEN_QUEUE_ROW_SETTINGS_FMT") % [inst_label, style_label]


func get_queue_snapshot() -> Dictionary:
	var items: Array = []
	var waiting_count := 0

	if _active_bpm_task.has("path"):
		var row := _serialize_bpm_item(str(_active_bpm_task.path), 1, "active")
		row["progress"] = _active_bpm_progress.duplicate(true)
		items.append(row)

	for i in range(_bpm_queue.size()):
		waiting_count += 1
		items.append(_serialize_bpm_item(_bpm_queue[i], i + 2, "pending", i))

	if _active_notes_task.has("path"):
		var active_notes := _serialize_notes_item(_active_notes_task, 1, "active", "")
		active_notes["progress"] = _active_notes_progress.duplicate(true)
		items.append(active_notes)

	var pending_block := _pending_notes_blocked_by()
	for i in range(_notes_queue.size()):
		waiting_count += 1
		items.append(_serialize_notes_item(_notes_queue[i], i + 2, "pending", pending_block, i))

	var pipeline_state := "idle"
	if _offline_paused:
		pipeline_state = "paused_offline"
	elif is_generation_backend_busy():
		pipeline_state = "running"

	return {
		"items": items,
		"counts": {
			"bpm_pending": _bpm_queue.size(),
			"notes_pending": _notes_queue.size(),
			"waiting": waiting_count,
			"active": int(_active_bpm_task.has("path")) + int(_active_notes_task.has("path")),
		},
		"history": _queue_history.duplicate(true),
		"delay_active": false,
		"delay_sec_remaining": 0.0,
		"delay_sec_default": _get_queue_toast_seconds(),
		"pipeline_busy": is_generation_backend_busy(),
		"pipeline_state": pipeline_state,
		"offline_paused": _offline_paused,
		"offline_message": _offline_pause_message,
		"eta_sec_remaining": _estimate_remaining_sec(),
	}


func promote_queue_item(item_id: String) -> bool:
	if item_id == "":
		return false
	if _active_bpm_task.has("path") and _bpm_job_id(str(_active_bpm_task.path)) == item_id:
		return false
	if _active_notes_task.has("path") and _notes_job_id(_active_notes_task) == item_id:
		return false
	for i in range(_bpm_queue.size()):
		if _bpm_job_id(_bpm_queue[i]) == item_id:
			if i == 0:
				return true
			var path := _bpm_queue[i]
			_bpm_queue.remove_at(i)
			_bpm_queue.insert(0, path)
			_emit_queue_changed()
			return true
	for i in range(_notes_queue.size()):
		if _notes_job_id(_notes_queue[i]) == item_id:
			if i == 0:
				return true
			var job: Dictionary = _notes_queue[i]
			_notes_queue.remove_at(i)
			_notes_queue.insert(0, job)
			_emit_queue_changed()
			return true
	return false


func demote_queue_item(item_id: String) -> bool:
	if item_id == "":
		return false
	if _active_bpm_task.has("path") and _bpm_job_id(str(_active_bpm_task.path)) == item_id:
		return false
	if _active_notes_task.has("path") and _notes_job_id(_active_notes_task) == item_id:
		return false
	for i in range(_bpm_queue.size() - 1):
		if _bpm_job_id(_bpm_queue[i]) == item_id:
			var path := _bpm_queue[i]
			_bpm_queue.remove_at(i)
			_bpm_queue.insert(i + 1, path)
			_emit_queue_changed()
			return true
	for i in range(_notes_queue.size() - 1):
		if _notes_job_id(_notes_queue[i]) == item_id:
			var job: Dictionary = _notes_queue[i]
			_notes_queue.remove_at(i)
			_notes_queue.insert(i + 1, job)
			_emit_queue_changed()
			return true
	return false


func _push_queue_history(kind: String, display: String, settings_line: String, status: String) -> void:
	_queue_history.insert(0, {
		"kind": kind,
		"display": display,
		"settings_line": settings_line,
		"status": status,
		"finished_at_unix": int(Time.get_unix_time_from_system()),
	})
	while _queue_history.size() > QUEUE_HISTORY_MAX:
		_queue_history.pop_back()


func cancel_queue_item(item_id: String) -> bool:
	if item_id == "":
		return false
	if _active_bpm_task.has("path") and _bpm_job_id(str(_active_bpm_task.path)) == item_id:
		cancel_bpm()
		return true
	if _active_notes_task.has("path") and _notes_job_id(_active_notes_task) == item_id:
		cancel_notes()
		return true
	for i in range(_bpm_queue.size()):
		if _bpm_job_id(_bpm_queue[i]) == item_id:
			_bpm_queue.remove_at(i)
			_emit_queue_changed()
			return true
	for i in range(_notes_queue.size()):
		if _notes_job_id(_notes_queue[i]) == item_id:
			_notes_queue.remove_at(i)
			_emit_queue_changed()
			return true
	return false


func has_queue_work() -> bool:
	return is_generation_backend_busy() or _offline_paused


func is_offline_paused() -> bool:
	return _offline_paused
