# server/generation_api_client.gd
extends Node
class_name GenerationApiClient

const _RhythmDnaServerFetch = preload("res://server/rhythm_dna_server_fetch.gd")
const _GoalDiff = preload("res://logic/domain/generation/generation_goal_difficulty.gd")
const PerfTrace = preload("res://logic/utils/perf_trace.gd")
const _CONNECT_TIMEOUT_MS := 20000

const SERVER_STATUS_ALIASES: Dictionary = {
	"Идентификация трека...": "GEN_API_TRACK_IDENTIFY",
	"Определение жанров...": "GEN_API_DETECTING_GENRES",
	"Разделение на стемы...": "GEN_API_SPLITTING_STEMS",
	"Детекция ударных...": "GEN_API_DRUM_DETECTION",
	"Анализ басовой линии...": "GEN_API_BASS_LINE_ANALYSIS",
	"Сборка бас-чарта...": "GEN_API_BASS_CHART_BUILD",
	"Сохранение нот...": "GEN_API_SAVING_NOTES",
	"Анализ структуры (SongFormer, CPU)...": "GEN_API_SPLITTING_STEMS",
	"Формирование ответа...": "GEN_API_BUILDING_RESPONSE",
}


func _api_host() -> String:
	if SettingsManager:
		if bool(SettingsManager.get_setting("generation_server_use_lan_host", false)):
			var lan := str(SettingsManager.get_setting("generation_server_lan_host", "")).strip_edges()
			return lan if not lan.is_empty() else "127.0.0.1"
		return "127.0.0.1"
	var h := str(ProjectSettings.get_setting("rhythmfall/generation_api/host", "127.0.0.1")).strip_edges()
	return h if not h.is_empty() else "127.0.0.1"


func _api_port() -> int:
	if SettingsManager:
		var p = SettingsManager.get_setting("generation_server_port", null)
		if p != null:
			return clampi(int(p), 1, 65535)
	return clampi(int(ProjectSettings.get_setting("rhythmfall/generation_api/port", 5000)), 1, 65535)

signal bpm_started
signal bpm_completed(bpm_value: int)
signal bpm_error(error_message: String)

signal genres_started
signal genres_completed(artist: String, title: String, genres: Array)
signal genres_error(error_message: String)

signal notes_started
signal notes_completed(notes_data: Array, bpm_value: float, instrument_type: String, notes_variants: Dictionary, rhythm_dna: Dictionary)
signal notes_error(error_message: String)
signal bpm_status(status: String)
signal genres_status(status: String)
signal notes_status(status: String)

signal genre_analysis_started
signal genre_analysis_status(status_key: String, detail: String)
signal genre_analysis_completed(song_path: String, predictions: Array)
signal genre_analysis_error(error_message: String)

var _bpm_thread: Thread = null
var _genres_thread: Thread = null
var _genre_analysis_thread: Thread = null
var _notes_thread: Thread = null

var _bpm_req: Dictionary = {}
var _genres_req: Dictionary = {}
var _genre_analysis_req: Dictionary = {}
var _notes_req: Dictionary = {}

var _bpm_res: Dictionary = {}
var _genres_res: Dictionary = {}
var _genre_analysis_res: Dictionary = {}
var _notes_res: Dictionary = {}
var _notes_last_stem_model: String = ""
var _bpm_status_queue: Array = []
var _genres_status_queue: Array = []
var _genre_analysis_status_queue: Array = []
var _notes_status_queue: Array = []

var _bpm_done: bool = false
var _genres_done: bool = false
var _genre_analysis_done: bool = false
var _notes_done: bool = false

var _cancel_bpm: bool = false
var _cancel_notes: bool = false
var _bpm_task_id: String = ""
var _notes_active_task_id: String = ""
var _next_chart_intent: String = ""
var _next_goal: String = ""
var _next_difficulty: String = ""
var _next_chart_stem: String = ""
var _bpm_poll_timer: Timer = null
var _notes_poll_timer: Timer = null
var _genres_poll_timer: Timer = null
var _genre_analysis_poll_timer: Timer = null

func analyze_bpm(song_path: String):
	if _bpm_thread:
		return
	_bpm_task_id = str(Time.get_ticks_msec()) + "_" + str(randi())
	_bpm_req = {"song_path": song_path, "task_id": _bpm_task_id}
	_bpm_res = {}
	_bpm_done = false
	_cancel_bpm = false
	_bpm_status_queue.clear()
	emit_signal("bpm_started")
	_bpm_thread = Thread.new()
	var err = _bpm_thread.start(func(): _bpm_worker(_bpm_req.duplicate()))
	if err != OK:
		_bpm_thread = null
		emit_signal("bpm_error", "Ошибка запуска потока")
		return
	_bpm_poll_timer = _replace_poll_timer(_bpm_poll_timer, _check_bpm)

func analyze_genre_predictions(song_path: String):
	if _genre_analysis_thread:
		return
	_genre_analysis_req = {"song_path": song_path}
	_genre_analysis_res = {}
	_genre_analysis_done = false
	_genre_analysis_status_queue.clear()
	emit_signal("genre_analysis_started")
	_genre_analysis_thread = Thread.new()
	var err = _genre_analysis_thread.start(func(): _genre_analysis_worker(_genre_analysis_req.duplicate()))
	if err != OK:
		_genre_analysis_thread = null
		emit_signal("genre_analysis_error", "Ошибка запуска потока")
		return
	_genre_analysis_poll_timer = _replace_poll_timer(_genre_analysis_poll_timer, _check_genre_analysis)

func detect_genres(artist: String, title: String):
	if _genres_thread:
		return
	_genres_req = {"artist": artist, "title": title}
	_genres_res = {}
	_genres_done = false
	_genres_status_queue.clear()
	emit_signal("genres_started")
	_genres_thread = Thread.new()
	var err = _genres_thread.start(func(): _genres_worker(_genres_req.duplicate()))
	if err != OK:
		_genres_thread = null
		emit_signal("genres_error", "Ошибка запуска потока")
		return
	_genres_poll_timer = _replace_poll_timer(_genres_poll_timer, _check_genres)

func set_chart_intent_for_next_request(intent: String) -> void:
	_next_chart_intent = str(intent).strip_edges()


func set_goal_difficulty_for_next_request(goal: String, difficulty: String) -> void:
	_next_goal = str(goal).strip_edges().to_lower()
	_next_difficulty = str(difficulty).strip_edges().to_lower()


func set_chart_stem_for_next_request(stem: String) -> void:
	_next_chart_stem = str(stem).strip_edges().to_lower()


func generate_notes_for_task(task: Dictionary) -> void:
	print(
		"[GenAPI] generate_notes_for_task goal=%s difficulty=%s stem=%s"
		% [str(task.get("goal", "")), str(task.get("difficulty", "")), str(task.get("chart_stem", ""))]
	)
	var lanes := int(task.get("lanes", 4))
	if int(task.get("preset_slot", 0)) > 0 or str(task.get("chart_tag", "")).strip_edges() != "":
		lanes = NotesUtils.CANONICAL_MAX_LANES
	generate_notes(
		str(task.get("path", "")),
		str(task.get("instrument", task.get("instrument_type", "drums"))),
		float(task.get("bpm", 120.0)),
		lanes,
		float(task.get("tolerance", task.get("sync_tolerance", 0.2))),
		bool(task.get("auto_identify", true)),
		str(task.get("artist", "")),
		str(task.get("title", "")),
		str(task.get("mode", task.get("generation_mode", "basic"))),
		str(task.get("goal", "")),
		str(task.get("difficulty", "")),
		str(task.get("chart_stem", "")),
		str(task.get("chart_intent", "")),
	)


func generate_notes(
	song_path: String,
	instrument_type: String,
	bpm: float,
	lanes: int,
	sync_tolerance: float,
	auto_identify: bool,
	manual_artist: String,
	manual_title: String,
	generation_mode: String,
	job_goal: String = "",
	job_difficulty: String = "",
	chart_stem: String = "",
	chart_intent_override: String = "",
):
	if _notes_thread:
		return
	_notes_active_task_id = str(Time.get_ticks_msec()) + "_" + str(randi())
	var chart_intent := str(chart_intent_override).strip_edges()
	if chart_intent == "":
		chart_intent = _next_chart_intent
	_next_chart_intent = ""
	var goal := str(job_goal).strip_edges().to_lower()
	if goal == "":
		goal = _next_goal
	var difficulty := str(job_difficulty).strip_edges().to_lower()
	if difficulty == "":
		difficulty = _next_difficulty
	chart_stem = str(chart_stem).strip_edges().to_lower()
	if chart_stem == "":
		chart_stem = _next_chart_stem
	_next_goal = ""
	_next_difficulty = ""
	_next_chart_stem = ""
	if chart_stem == "" and goal != "" and difficulty != "":
		chart_stem = _GoalDiff.chart_stem(goal, difficulty)
	if goal == "" or difficulty == "":
		if chart_stem != "":
			var stem_pair := _GoalDiff.pair_from_stem(chart_stem)
			if goal == "":
				goal = str(stem_pair.get("goal", _GoalDiff.DEFAULT_GOAL)).strip_edges().to_lower()
			if difficulty == "":
				difficulty = str(stem_pair.get("difficulty", _GoalDiff.DEFAULT_DIFFICULTY)).strip_edges().to_lower()
	if chart_intent == "" and goal != "" and difficulty != "":
		chart_intent = _GoalDiff.intent_for(goal, difficulty)
	push_warning(
		"GenAPI request goal=%s difficulty=%s stem=%s intent=%s mode=%s"
		% [goal, difficulty, chart_stem, chart_intent, generation_mode]
	)
	print(
		"[GenAPI] request goal=%s difficulty=%s stem=%s intent=%s mode=%s"
		% [goal, difficulty, chart_stem, chart_intent, generation_mode]
	)
	_notes_req = {
		"song_path": song_path,
		"instrument_type": instrument_type,
		"bpm": bpm,
		"lanes": lanes,
		"sync_tolerance": sync_tolerance,
		"auto_identify": auto_identify,
		"manual_artist": manual_artist,
		"manual_title": manual_title,
		"generation_mode": generation_mode,
		"chart_intent": chart_intent,
		"goal": goal,
		"difficulty": difficulty,
		"chart_stem": chart_stem,
		"task_id": _notes_active_task_id
	}
	_notes_res = {}
	_notes_done = false
	_cancel_notes = false
	_notes_status_queue.clear()
	emit_signal("notes_started")
	_notes_thread = Thread.new()
	var err = _notes_thread.start(func(): _notes_worker(_notes_req.duplicate()))
	if err != OK:
		_notes_thread = null
		emit_signal("notes_error", "Ошибка запуска потока")
		return
	_notes_poll_timer = _replace_poll_timer(_notes_poll_timer, _check_notes)

func is_bpm_cancelled() -> bool:
	return _cancel_bpm

func is_bpm_busy() -> bool:
	return _bpm_thread != null

func is_notes_busy() -> bool:
	return _notes_thread != null

func request_cancel_bpm():
	_cancel_bpm = true
	print("DEBUG_BPM_CLIENT: request_cancel_bpm _bpm_task_id=%s" % _bpm_task_id)
	var task_id := _bpm_task_id
	if task_id != "":
		var cancel_thread := Thread.new()
		cancel_thread.start(func(): _send_cancel_task_request(task_id))

func request_cancel_notes():
	_cancel_notes = true
	var task_id := _notes_active_task_id
	if task_id != "":
		var cancel_thread := Thread.new()
		cancel_thread.start(func(): _send_cancel_task_request(task_id))


func _poll_until_http_connected(http_client: HTTPClient, cancel_getter: Callable) -> bool:
	var start_ms := Time.get_ticks_msec()
	while http_client.get_status() in [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]:
		http_client.poll()
		OS.delay_msec(10)
		if Time.get_ticks_msec() - start_ms > _CONNECT_TIMEOUT_MS:
			return false
		if cancel_getter.is_valid() and cancel_getter.call():
			return false
	return http_client.get_status() == HTTPClient.STATUS_CONNECTED


func _read_http_response_body(http_client: HTTPClient, cancel_getter: Callable = Callable()) -> PackedByteArray:
	var response_body := PackedByteArray()
	while http_client.get_status() == HTTPClient.STATUS_BODY:
		if cancel_getter.is_valid() and cancel_getter.call():
			return PackedByteArray()
		http_client.poll()
		var chunk = http_client.read_response_body_chunk()
		if chunk.size() > 0:
			response_body.append_array(chunk)
		else:
			OS.delay_msec(10)
	return response_body


func _uses_remote_generation_server() -> bool:
	return SettingsManager and bool(SettingsManager.get_setting("generation_server_use_lan_host", false))


func _http_get_json(path: String, cancel_getter: Callable) -> Dictionary:
	var out := {"ok": false, "code": 0, "json": null}
	var http_client = HTTPClient.new()
	if http_client.connect_to_host(_api_host(), _api_port()) != OK:
		return out
	if not _poll_until_http_connected(http_client, cancel_getter):
		http_client.close()
		return out
	http_client.request_raw(HTTPClient.METHOD_GET, path, PackedStringArray(), PackedByteArray())
	while http_client.get_status() == HTTPClient.STATUS_REQUESTING:
		http_client.poll()
		OS.delay_msec(10)
		if cancel_getter.is_valid() and cancel_getter.call():
			http_client.close()
			return out
	out.code = http_client.get_response_code()
	var response_body = _read_http_response_body(http_client)
	http_client.close()
	var response_json = JSON.parse_string(response_body.get_string_from_utf8())
	if response_json != null:
		out.json = response_json
		out.ok = true
	return out


func _extract_rhythm_dna(payload: Variant) -> Dictionary:
	if payload is Dictionary:
		return payload
	if payload is String:
		var text := String(payload).strip_edges()
		if text.is_empty():
			return {}
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary:
			return parsed
	return {}


func _fetch_rhythm_dna_for_task(task_id: String, _cancel_getter: Callable = Callable()) -> Dictionary:
	return _RhythmDnaServerFetch.fetch_by_task_id(task_id)


func _server_track_stem(song_path: String) -> String:
	return _RhythmDnaServerFetch.track_stem_from_song_path(song_path)


func _fetch_rhythm_dna_sidecar_for_song(
	song_path: String,
	mode: String,
	instrument: String = "drums",
	_cancel_getter: Callable = Callable()
) -> Dictionary:
	return _RhythmDnaServerFetch.fetch_sidecar(song_path, mode, instrument)


func fetch_rhythm_dna_for_song(
	song_path: String,
	mode: String,
	instrument: String = "drums",
	task_id: String = ""
) -> Dictionary:
	return _RhythmDnaServerFetch.fetch_for_song(song_path, mode, instrument, task_id)


func get_last_notes_task_id() -> String:
	return str(_notes_res.get("task_id", ""))


func get_last_notes_stem_model() -> String:
	if _notes_last_stem_model != "":
		return _notes_last_stem_model
	return str(_notes_res.get("stem_model", ""))


func _stem_download_temp_path(identifier: String, kind: String, format: String = "wav") -> String:
	var id := String(identifier).strip_edges().to_lower()
	if id == "":
		id = "unknown"
	var safe_id := ""
	for c in id:
		if String(c) in ["0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f"]:
			safe_id += String(c)
	if safe_id == "":
		safe_id = "unknown"
	var k := String(kind).strip_edges().to_lower()
	if k not in ["drums", "bass"]:
		k = "drums"
	var fmt := String(format).strip_edges().to_lower()
	if fmt not in ["wav", "mp3"]:
		fmt = "wav"
	# Temporary location — NOT persistent user://stems/ (Phase 3).
	# Reuses existing DirectoryUtils helper; no new setting/dir-choice.
	return "user://cache/stem_downloads/%s_%s.%s" % [safe_id, k, fmt]


func _http_get_binary_to_file(query_path: String, out_file_path: String, cancel_getter: Callable = Callable()) -> Dictionary:
	var out := {"ok": false, "code": 0, "path": "", "error": ""}
	var http_client := HTTPClient.new()
	if http_client.connect_to_host(_api_host(), _api_port()) != OK:
		out.error = "connect_failed"
		return out
	if not _poll_until_http_connected(http_client, cancel_getter):
		http_client.close()
		out.error = "connect_timeout"
		return out
	http_client.request_raw(HTTPClient.METHOD_GET, query_path, PackedStringArray(), PackedByteArray())
	while http_client.get_status() == HTTPClient.STATUS_REQUESTING:
		http_client.poll()
		OS.delay_msec(10)
		if cancel_getter.is_valid() and cancel_getter.call():
			http_client.close()
			out.error = "cancelled"
			return out
	var code := http_client.get_response_code()
	out.code = code
	if code != 200:
		var err_body := _read_http_response_body(http_client, cancel_getter)
		var err_text := err_body.get_string_from_utf8()
		var err_json = JSON.parse_string(err_text)
		if err_json is Dictionary and err_json.has("error"):
			out.error = str(err_json["error"])
		elif err_text.strip_edges() != "":
			out.error = err_text.strip_edges().substr(0, 200)
		else:
			out.error = "http_%d" % code
		http_client.close()
		return out
	# 200 — stream WAV chunks directly to file, not holding whole file in RAM.
	DirectoryUtils.ensure_dir_for_file(out_file_path)
	var abs_out := DirectoryUtils.to_absolute(out_file_path)
	# Remove stale file if exists
	if FileAccess.file_exists(abs_out):
		DirAccess.remove_absolute(abs_out)
	var file := FileAccess.open(out_file_path, FileAccess.WRITE)
	if file == null:
		# Fallback via absolute path
		file = FileAccess.open(abs_out, FileAccess.WRITE)
	if file == null:
		http_client.close()
		out.error = "file_open_failed"
		return out
	while http_client.get_status() == HTTPClient.STATUS_BODY:
		if cancel_getter.is_valid() and cancel_getter.call():
			file.close()
			http_client.close()
			# Remove partial file
			var abs_tmp := DirectoryUtils.to_absolute(out_file_path)
			if abs_tmp != "" and FileAccess.file_exists(abs_tmp):
				DirAccess.remove_absolute(abs_tmp)
			out.error = "cancelled"
			return out
		http_client.poll()
		var chunk := http_client.read_response_body_chunk()
		if chunk.size() > 0:
			file.store_buffer(chunk)
		else:
			OS.delay_msec(10)
	file.close()
	http_client.close()
	# Validate file size (>1KB) like ChartStemManager.validate_stem
	var abs_check := DirectoryUtils.to_absolute(out_file_path)
	var sz := 0
	if abs_check != "" and FileAccess.file_exists(abs_check):
		var f2 := FileAccess.open(abs_check, FileAccess.READ)
		if f2:
			sz = int(f2.get_length())
			f2.close()
	if sz < 1024:
		if abs_check != "" and FileAccess.file_exists(abs_check):
			DirAccess.remove_absolute(abs_check)
		out.error = "too_small"
		return out
	out.ok = true
	out.path = out_file_path
	return out


func download_stem_file(content_hash: String, kind: String, chart_id: String = "", format: String = "wav") -> Dictionary:
	# Minimal binary download for already generated stem — does NOT trigger generation.
	# Uses existing HTTPClient + LAN host settings via _api_host/_api_port.
	var k := String(kind).strip_edges().to_lower()
	if k not in ["drums", "bass"]:
		return {"ok": false, "code": 400, "path": "", "error": "invalid kind"}
	var fmt := String(format).strip_edges().to_lower()
	if fmt not in ["wav", "mp3"]:
		fmt = "wav"
	var ch := String(content_hash).strip_edges().to_lower()
	var cid := String(chart_id).strip_edges().to_lower()
	if ch == "" and cid == "":
		return {"ok": false, "code": 400, "path": "", "error": "content_hash or chart_id required"}
	var query := "/stem_file?kind=" + k + "&format=" + fmt
	if ch != "":
		query += "&content_hash=" + ch
	if cid != "":
		query += "&chart_id=" + cid
	var identifier := ch if ch != "" else cid
	var out_path := _stem_download_temp_path(identifier, k, fmt)
	return _http_get_binary_to_file(query, out_path, Callable())


func download_stem_for_song(song_path: String, kind: String = "drums", format: String = "wav") -> Dictionary:
	# Convenience: compute Phase 1 content_hash via NotesUtils, fallback to chart_id.
	# Does not generate stem — only downloads if already exists on server (404 otherwise).
	var k := String(kind).strip_edges().to_lower()
	if k not in ["drums", "bass"]:
		k = "drums"
	var fmt := String(format).strip_edges().to_lower()
	if fmt not in ["wav", "mp3"]:
		fmt = "wav"
	var content_hash := ""
	if song_path != "" and FileAccess.file_exists(song_path):
		# Prefer content identity (Phase 1), stable on rename.
		if NotesUtils:
			content_hash = String(NotesUtils.audio_content_hash(song_path)).strip_edges().to_lower()
	var chart_id := ""
	if NotesUtils:
		chart_id = String(NotesUtils.chart_id_from_song_path(song_path)).strip_edges().to_lower()
	return download_stem_file(content_hash, k, chart_id, fmt)


func fetch_storage_usage() -> Dictionary:
	return _http_get_json("/storage_usage", Callable())


func reclaim_temp_uploads() -> Dictionary:
	var payload := JSON.stringify({"temp_uploads_root_artifacts": true}).to_utf8_buffer()
	var headers := PackedStringArray(["Content-Type: application/json"])
	var http_client := HTTPClient.new()
	if http_client.connect_to_host(_api_host(), _api_port()) != OK:
		return {"ok": false, "code": 0}
	if not _poll_until_http_connected(http_client, Callable()):
		http_client.close()
		return {"ok": false, "code": 0}
	http_client.request_raw(HTTPClient.METHOD_POST, "/storage_reclaim", headers, payload)
	while http_client.get_status() == HTTPClient.STATUS_REQUESTING:
		http_client.poll()
		OS.delay_msec(50)
	var code := http_client.get_response_code()
	var body := _read_http_response_body(http_client)
	http_client.close()
	var js = JSON.parse_string(body.get_string_from_utf8())
	if js is Dictionary:
		return {"ok": code == 200, "code": code, "json": js}
	return {"ok": code == 200, "code": code, "json": {}}


func _resolve_rhythm_dna_for_result(
	result: Dictionary,
	task_id: String,
	song_path: String,
	mode: String,
	instrument: String,
	cancel_getter: Callable
) -> Dictionary:
	if not result is Dictionary:
		return {}
	var rhythm_dna := _extract_rhythm_dna(result.get("rhythm_dna", null))
	if not rhythm_dna.is_empty() and not NotesUtils.is_minimal_rhythm_dna(rhythm_dna):
		push_warning("RhythmDNA: present in POST/task_result JSON")
		return rhythm_dna
	rhythm_dna = _RhythmDnaServerFetch.fetch_for_song(song_path, mode, instrument, task_id)
	if not rhythm_dna.is_empty():
		result["rhythm_dna"] = rhythm_dna
		return rhythm_dna
	if task_id.strip_edges() != "":
		push_warning("RhythmFall: Rhythm DNA missing after API + sidecar fetch (task_id=%s, track=%s)" % [
			task_id,
			_server_track_stem(song_path),
		])
	return {}


func _notes_payload_from_json(response_json: Variant, song_path: String, bpm: float, lanes: int, instrument_type: String) -> Dictionary:
	if not response_json is Dictionary:
		return {"error": "Некорректный ответ сервера"}
	if str(response_json.get("status", "")) == "processing":
		return {"pending": true}
	if response_json.has("status") and str(response_json["status"]) == "cancelled_by_user":
		return {"error": "Отменено пользователем"}
	if response_json.has("status") and str(response_json["status"]) == "requires_manual_input":
		return {"result": {"manual_identification_required": true, "song_path": song_path}}
	if response_json.has("status") and str(response_json["status"]) == "error":
		return {"error": str(response_json.get("error", "Ошибка сервера"))}
	if response_json.has("error") and not response_json.has("notes") and not response_json.has("notes_variants"):
		return {"error": str(response_json["error"])}
	if response_json.has("notes") or response_json.has("notes_variants"):
		var result_dict := {}
		if response_json.has("notes"):
			result_dict["notes"] = response_json["notes"]
		if response_json.has("notes_variants"):
			result_dict["notes_variants"] = response_json["notes_variants"]
		result_dict["bpm"] = response_json.get("bpm", bpm)
		result_dict["lanes"] = response_json.get("lanes", lanes)
		result_dict["instrument_type"] = response_json.get("instrument_type", instrument_type)
		result_dict["track_info"] = response_json.get("track_info", {})
		if response_json.has("task_id"):
			result_dict["task_id"] = str(response_json.get("task_id", ""))
		# Phase 3D.2: actually used stem model (not config), empty if old server
		if response_json.has("stem_model"):
			result_dict["stem_model"] = str(response_json.get("stem_model", ""))
		elif response_json.has("stem") and response_json["stem"] is Dictionary and (response_json["stem"] as Dictionary).has("model"):
			result_dict["stem_model"] = str((response_json["stem"] as Dictionary).get("model", ""))
		else:
			result_dict["stem_model"] = ""
		var rhythm_dna := _extract_rhythm_dna(response_json.get("rhythm_dna", null))
		if not rhythm_dna.is_empty():
			result_dict["rhythm_dna"] = rhythm_dna
		return {"result": result_dict}
	return {"error": "Ответ не содержит нот"}


func _try_notes_task_result(task_id: String, song_path: String, bpm: float, lanes: int, instrument_type: String, cancel_getter: Callable) -> Dictionary:
	var http_resp = _http_get_json("/task_result?task_id=" + task_id, cancel_getter)
	if not http_resp.ok or http_resp.json == null:
		return {}
	var code := int(http_resp.code)
	if code == 404 or code == 202:
		return {}
	return _notes_payload_from_json(http_resp.json, song_path, bpm, lanes, instrument_type)


func _send_cancel_task_request(task_id: String) -> void:
	if task_id == "":
		return
	var http_client = HTTPClient.new()
	if http_client.connect_to_host(_api_host(), _api_port()) != OK:
		return
	if not _poll_until_http_connected(http_client, Callable()):
		http_client.close()
		return
	http_client.request_raw(
		HTTPClient.METHOD_GET,
		"/cancel_task?task_id=" + task_id,
		PackedStringArray(),
		PackedByteArray()
	)
	while http_client.get_status() == HTTPClient.STATUS_REQUESTING:
		http_client.poll()
		OS.delay_msec(10)
	http_client.close()


func _fetch_notes_task_result(task_id: String, song_path: String, bpm: float, lanes: int, instrument_type: String, cancel_getter: Callable) -> Dictionary:
	_notes_status_queue.append("GEN_API_FETCHING_RESULT")
	var start_ms := Time.get_ticks_msec()
	var timeout_ms := 600000
	var last_heartbeat := start_ms
	while Time.get_ticks_msec() - start_ms < timeout_ms:
		if cancel_getter.is_valid() and cancel_getter.call():
			_send_cancel_task_request(task_id)
			return {"error": "Отменено пользователем"}
		var parsed = _try_notes_task_result(task_id, song_path, bpm, lanes, instrument_type, cancel_getter)
		if parsed.has("result") or parsed.has("error"):
			return parsed
		# Keep dock honest while server is still on Basic Pitch / stem passes (202).
		if Time.get_ticks_msec() - last_heartbeat >= 8000:
			_notes_status_queue.append("GEN_API_FETCHING_RESULT")
			last_heartbeat = Time.get_ticks_msec()
		OS.delay_msec(500)
	return {"error": "Таймаут ожидания результата с сервера"}


func _start_timer(cb: Callable):
	# Legacy entry — prefer typed poll timers below.
	_start_poll_timer_generic(cb)


func _start_poll_timer_generic(cb: Callable) -> Timer:
	var t := Timer.new()
	t.wait_time = 0.1
	t.timeout.connect(cb)
	add_child(t)
	t.start()
	return t


func _replace_poll_timer(existing: Timer, cb: Callable) -> Timer:
	if existing != null and is_instance_valid(existing):
		existing.stop()
		existing.queue_free()
	return _start_poll_timer_generic(cb)


func _stop_poll_timer(existing: Timer) -> void:
	if existing != null and is_instance_valid(existing):
		existing.stop()
		existing.queue_free()

func _localize_text(raw: String) -> String:
	var s := String(raw).strip_edges()
	if s == "":
		return s
	if s.begins_with("GEN_"):
		return tr(s)
	if SERVER_STATUS_ALIASES.has(s):
		return tr(str(SERVER_STATUS_ALIASES[s]))
	return s


func _emit_genre_analysis_status(status_key: String, detail: String = "") -> void:
	emit_signal("genre_analysis_status", status_key, detail)


func _post_genre_analysis_status(status_key: String, detail: String = "") -> void:
	call_deferred("_emit_genre_analysis_status", status_key, detail)


func _check_bpm():
	if _bpm_status_queue.size() > 0:
		for s in _bpm_status_queue:
			emit_signal("bpm_status", _localize_text(s))
		_bpm_status_queue.clear()
	if _bpm_done:
		_stop_poll_timer(_bpm_poll_timer)
		_bpm_poll_timer = null
		_bpm_done = false
		if _bpm_thread:
			_bpm_thread.wait_to_finish()
			_bpm_thread = null
		# Cancellation must never be reported as a successful BPM.
		# Root cause fix: worker can set a successful bpm after Cancel was
		# requested (race between body read and final assignment). Force the
		# result to a cancellation error so we never emit bpm_completed after Cancel.
		if _cancel_bpm:
			_bpm_res = {"error": "Операция отменена"}
		if _bpm_res.has("error"):
			emit_signal("bpm_error", _bpm_res.error)
		elif _bpm_res.has("bpm"):
			emit_signal("bpm_completed", int(_bpm_res.bpm))
		else:
			emit_signal("bpm_error", "Неизвестная ошибка")

func _check_genre_analysis():
	if _genre_analysis_status_queue.size() > 0:
		for s in _genre_analysis_status_queue:
			var parts := str(s).split("|", false, 1)
			var key := parts[0]
			var detail := parts[1] if parts.size() > 1 else ""
			emit_signal("genre_analysis_status", key, detail)
		_genre_analysis_status_queue.clear()
	if _genre_analysis_done:
		_stop_poll_timer(_genre_analysis_poll_timer)
		_genre_analysis_poll_timer = null
		_genre_analysis_done = false
		if _genre_analysis_thread:
			_genre_analysis_thread.wait_to_finish()
			_genre_analysis_thread = null
		var song_path := str(_genre_analysis_req.get("song_path", ""))
		if _genre_analysis_res.has("error"):
			emit_signal("genre_analysis_error", _genre_analysis_res.error)
		elif _genre_analysis_res.has("predictions"):
			emit_signal("genre_analysis_completed", song_path, _genre_analysis_res.predictions)
		else:
			emit_signal("genre_analysis_error", "Неизвестная ошибка")

func _check_genres():
	if _genres_status_queue.size() > 0:
		for s in _genres_status_queue:
			emit_signal("genres_status", _localize_text(s))
		_genres_status_queue.clear()
	if _genres_done:
		_stop_poll_timer(_genres_poll_timer)
		_genres_poll_timer = null
		_genres_done = false
		if _genres_thread:
			_genres_thread.wait_to_finish()
			_genres_thread = null
		if _genres_res.has("error"):
			emit_signal("genres_error", _genres_res.error)
		elif _genres_res.has("genres"):
			emit_signal("genres_completed", _genres_res.artist, _genres_res.title, _genres_res.genres)
		else:
			emit_signal("genres_error", "Неизвестная ошибка")

func _check_notes():
	if _notes_status_queue.size() > 0:
		emit_signal("notes_status", _localize_text(_notes_status_queue.pop_front()))
		return
	if _notes_done:
		_stop_poll_timer(_notes_poll_timer)
		_notes_poll_timer = null
		_notes_done = false
		if _notes_thread:
			_notes_thread.wait_to_finish()
			_notes_thread = null
		_notes_active_task_id = ""
		if _notes_res.has("error"):
			_notes_last_stem_model = ""
			emit_signal("notes_error", _notes_res.error)
		elif _notes_res.has("manual_identification_required"):
			_notes_last_stem_model = ""
			_notes_status_queue.append("GEN_API_MANUAL_ID_REQUIRED")
			var req = _notes_req
			if has_method("generate_notes_for_task"):
				generate_notes_for_task(req)
			else:
				set_goal_difficulty_for_next_request(
					str(req.get("goal", "")),
					str(req.get("difficulty", ""))
				)
				set_chart_stem_for_next_request(str(req.get("chart_stem", "")))
				set_chart_intent_for_next_request(str(req.get("chart_intent", "")))
				generate_notes(
					req.song_path,
					req.instrument_type,
					req.bpm,
					req.lanes,
					req.sync_tolerance,
					false,
					"Unknown",
					"Unknown",
					req.generation_mode,
				)
		elif _notes_res.has("notes") or _notes_res.has("notes_variants"):
			_notes_last_stem_model = str(_notes_res.get("stem_model", ""))
			var task_id := str(_notes_res.get("task_id", _notes_active_task_id))
			var song_path := str(_notes_req.get("song_path", ""))
			var gen_mode := str(_notes_req.get("generation_mode", "basic"))
			var instrument := str(_notes_req.get("instrument_type", "drums"))
			var rhythm_dna := _resolve_rhythm_dna_for_result(
				_notes_res, task_id, song_path, gen_mode, instrument, Callable()
			)
			if _notes_res.has("notes_variants"):
				var variants = _notes_res.notes_variants
				var requested_lanes = int(_notes_req.get("lanes", 4))
				var key = str(requested_lanes)
				var arr = variants.get(key, null)
				if arr == null:
					for fallback_k in [key, "4", "3", "5"]:
						if variants.has(fallback_k):
							arr = variants[fallback_k]
							break
					if arr == null and variants.size() > 0:
						var first_k = variants.keys()[0]
						arr = variants[first_k]
				if arr is Array:
					emit_signal("notes_completed", arr, float(_notes_res.bpm), _notes_res.instrument_type, variants, rhythm_dna)
			else:
				emit_signal("notes_completed", _notes_res.notes, float(_notes_res.bpm), _notes_res.instrument_type, {}, rhythm_dna)
			if _notes_res.has("track_info"):
				var ti = _notes_res.track_info
				var source = str(ti.get("genres_source", "")).strip_edges().to_lower()
				var artist = str(ti.get("artist", "Unknown"))
				var title = str(ti.get("title", "Unknown"))
				var genres = ti.get("genres", [])
				var path = _notes_req.get("song_path", "")
				var allow_update = false
				if path != "":
					var meta = SongLibrary.get_metadata_for_song(path)
					var local_pg = str(meta.get("primary_genre", "")).strip_edges().to_lower()
					allow_update = (source == "server") or (local_pg == "" or local_pg == "unknown")
				else:
					allow_update = (source == "server")
				if allow_update and genres is Array:
					emit_signal("genres_completed", artist, title, genres)
				if path != "":
					var preds = ti.get("genre_predictions", [])
					if preds is Array and preds.size() > 0:
						SongLibrary.update_metadata(path, {"genre_predictions": preds})
						_notify_genre_analysis_achievement()
		else:
			_notes_last_stem_model = ""
			emit_signal("notes_error", "Неизвестная ошибка")


func _bpm_worker(data_dict: Dictionary):
	var local_result = {}
	var local_error = ""
	var song_path = data_dict.get("song_path", "")
	if song_path == "":
		_bpm_res = {"error": "Пустой путь"}
		_bpm_done = true
		return
	_bpm_status_queue.append("GEN_API_CONNECTING")
	var http_client = HTTPClient.new()
	var err = http_client.connect_to_host(_api_host(), _api_port())
	if err != OK:
		local_error = "Не удалось подключиться: " + str(err)
	else:
		if not _poll_until_http_connected(http_client, func(): return _cancel_bpm):
			if _cancel_bpm:
				_bpm_res = {"error": "Операция отменена"}
			else:
				_bpm_res = {"error": "Таймаут подключения к серверу (%s:%d)" % [_api_host(), _api_port()]}
			http_client.close()
			_bpm_done = true
			return
		_bpm_status_queue.append("GEN_API_CONNECTED")
		if http_client.get_status() != HTTPClient.STATUS_CONNECTED:
			local_error = "Нет подключения. Статус: " + str(http_client.get_status())
		else:
			_bpm_status_queue.append("GEN_API_OPENING_FILE")
			var file_access = FileAccess.open(song_path, FileAccess.READ)
			if not file_access:
				local_error = "Не удалось открыть файл: " + song_path
			else:
				var file_data = file_access.get_buffer(file_access.get_length())
				file_access.close()
				_bpm_status_queue.append("GEN_API_BUILDING_REQUEST")
				var boundary = "bpm_boundary_" + str(Time.get_ticks_msec())
				var body = PackedByteArray()
				var header = ("--%s\r\n" + "Content-Disposition: form-data; name=\"audio_file\"; filename=\"%s\"\r\n" + "Content-Type: application/octet-stream\r\n\r\n") % [boundary, song_path.get_file()]
				body.append_array(header.to_utf8_buffer())
				body.append_array(file_data)
				body.append_array(("\r\n--%s--\r\n" % boundary).to_utf8_buffer())
				var headers = PackedStringArray(["Content-Type: multipart/form-data; boundary=" + boundary, "X-Task-Id: " + str(data_dict.get("task_id", _bpm_task_id))])
				_bpm_status_queue.append("GEN_API_SENDING_DATA")
				http_client.request_raw(HTTPClient.METHOD_POST, "/analyze_bpm", headers, body)
				http_client.poll()
				while http_client.get_status() == HTTPClient.STATUS_REQUESTING:
					http_client.poll()
					OS.delay_msec(100)
					if _cancel_bpm:
						_bpm_res = {"error": "Операция отменена"}
						http_client.close()
						_bpm_done = true
						return
				if _cancel_bpm:
					_bpm_res = {"error": "Операция отменена"}
					http_client.close()
					_bpm_done = true
					return
				_bpm_status_queue.append("GEN_API_RECEIVING_RESPONSE")
				var response_code = http_client.get_response_code()
				if _cancel_bpm:
					_bpm_res = {"error": "Операция отменена"}
					http_client.close()
					_bpm_done = true
					return
				var response_body = _read_http_response_body(http_client, func(): return _cancel_bpm)
				if _cancel_bpm or response_body.is_empty() and _cancel_bpm:
					_bpm_res = {"error": "Операция отменена"}
					http_client.close()
					_bpm_done = true
					return
				_bpm_status_queue.append("GEN_API_PROCESSING_RESPONSE")
				# Final cancellation check — the worker could have been cancelled
				# after the body was already read but before JSON parsing.
				# Without this check the cancelled job could still be reported
				# as a successful BPM (the previous root cause).
				if _cancel_bpm:
					_bpm_res = {"error": "Операция отменена"}
					http_client.close()
					_bpm_done = true
					return
				var response_text = response_body.get_string_from_utf8()
				var response_json = JSON.parse_string(response_text)
				if response_code == 200 and response_json and response_json.has("bpm"):
					local_result = {"bpm": response_json["bpm"]}
				else:
					local_error = "Ошибка: " + str(response_code)
	http_client.close()
	# Ensure cancellation is never swallowed by a late success.
	if _cancel_bpm:
		_bpm_res = {"error": "Операция отменена"}
	else:
		_bpm_res = local_result if local_error == "" else {"error": local_error}
	_bpm_done = true

func _genre_analysis_worker(data_dict: Dictionary):
	var local_result = {}
	var local_error = ""
	var song_path = data_dict.get("song_path", "")
	if song_path == "":
		_genre_analysis_res = {"error": "Пустой путь"}
		_genre_analysis_done = true
		return
	_post_genre_analysis_status("GEN_API_CONNECTING")
	var http_client = HTTPClient.new()
	var err = http_client.connect_to_host(_api_host(), _api_port())
	if err != OK:
		local_error = "Не удалось подключиться: " + str(err)
	else:
		if not _poll_until_http_connected(http_client, Callable()):
			local_error = "Таймаут подключения к серверу (%s:%d)" % [_api_host(), _api_port()]
			http_client.close()
			_genre_analysis_res = {"error": local_error}
			_genre_analysis_done = true
			return
		_post_genre_analysis_status("GEN_API_CONNECTED")
		if http_client.get_status() != HTTPClient.STATUS_CONNECTED:
			local_error = "Нет подключения. Статус: " + str(http_client.get_status())
		else:
			_post_genre_analysis_status("reading_file")
			var file_access = FileAccess.open(song_path, FileAccess.READ)
			if not file_access:
				local_error = "Не удалось открыть файл: " + song_path
			else:
				var file_data = file_access.get_buffer(file_access.get_length())
				file_access.close()
				var size_mb := float(file_data.size()) / (1024.0 * 1024.0)
				_post_genre_analysis_status("uploading", str(size_mb))
				var boundary = "genre_boundary_" + str(Time.get_ticks_msec())
				var body = PackedByteArray()
				var header = ("--%s\r\n" + "Content-Disposition: form-data; name=\"audio_file\"; filename=\"%s\"\r\n" + "Content-Type: application/octet-stream\r\n\r\n") % [boundary, song_path.get_file()]
				body.append_array(header.to_utf8_buffer())
				body.append_array(file_data)
				body.append_array(("\r\n--%s--\r\n" % boundary).to_utf8_buffer())
				var headers = PackedStringArray(["Content-Type: multipart/form-data; boundary=" + boundary])
				http_client.request_raw(HTTPClient.METHOD_POST, "/detect_genres_audio", headers, body)
				http_client.poll()
				while http_client.get_status() == HTTPClient.STATUS_REQUESTING:
					http_client.poll()
					OS.delay_msec(100)
				_post_genre_analysis_status("analyzing")
				var response_code = http_client.get_response_code()
				var response_body = _read_http_response_body(http_client)
				var response_json = JSON.parse_string(response_body.get_string_from_utf8())
				if response_code == 200 and response_json and response_json.has("predictions"):
					local_result = {"predictions": response_json["predictions"]}
				else:
					var err_msg := "Ошибка: " + str(response_code)
					if response_json is Dictionary and response_json.has("error"):
						err_msg = str(response_json["error"])
					local_error = err_msg
	http_client.close()
	_genre_analysis_res = local_result if local_error == "" else {"error": local_error}
	_genre_analysis_done = true

func _genres_worker(data_dict: Dictionary):
	var local_result = {}
	var local_error = ""
	var artist = data_dict.get("artist", "").strip_edges()
	var title = data_dict.get("title", "").strip_edges()
	if artist == "" or title == "":
		_genres_res = {"error": "Пустые поля"}
		_genres_done = true
		return
	_genres_status_queue.append("GEN_API_CONNECTING")
	var http_client = HTTPClient.new()
	var err = http_client.connect_to_host(_api_host(), _api_port())
	if err != OK:
		local_error = "Не удалось подключиться: " + str(err)
	else:
		if not _poll_until_http_connected(http_client, Callable()):
			local_error = "Таймаут подключения к серверу (%s:%d)" % [_api_host(), _api_port()]
			http_client.close()
			_genres_res = {"error": local_error}
			_genres_done = true
			return
		_genres_status_queue.append("GEN_API_CONNECTED")
		if http_client.get_status() != HTTPClient.STATUS_CONNECTED:
			local_error = "Нет подключения. Статус: " + str(http_client.get_status())
		else:
			_genres_status_queue.append("GEN_API_SENDING_REQUEST")
			var payload = JSON.stringify({"artist": artist, "title": title}).to_utf8_buffer()
			var headers = PackedStringArray(["Content-Type: application/json", "Content-Length: " + str(payload.size())])
			http_client.request_raw(HTTPClient.METHOD_POST, "/get_genres_manual", headers, payload)
			http_client.poll()
			while http_client.get_status() == HTTPClient.STATUS_REQUESTING:
				http_client.poll()
				OS.delay_msec(100)
			_genres_status_queue.append("GEN_API_RECEIVING_RESPONSE")
			var response_code = http_client.get_response_code()
			var response_body = _read_http_response_body(http_client)
			_genres_status_queue.append("GEN_API_PROCESSING_RESPONSE")
			var response_text = response_body.get_string_from_utf8()
			var response_json = JSON.parse_string(response_text)
			if response_code == 200 and response_json and response_json.has("genres"):
				local_result = {"genres": response_json["genres"], "artist": response_json.get("artist", artist), "title": response_json.get("title", title)}
			else:
				local_error = "Ошибка: " + str(response_code)
	http_client.close()
	_genres_res = local_result if local_error == "" else {"error": local_error}
	_genres_done = true

func _notes_worker(data_dict: Dictionary):
	var _perf_network := PerfTrace.begin("perf.detail.generation.network.wait")
	var local_result = {}
	var local_error = ""
	var song_path = data_dict.get("song_path", "")
	if song_path == "":
		PerfTrace.end("perf.detail.generation.network.wait", _perf_network)
		_notes_res = {"error": "Пустой путь"}
		_notes_done = true
		return
	_notes_status_queue.append("GEN_API_CONNECTING")
	var instrument_type = data_dict.get("instrument_type", "drums")
	var bpm = data_dict.get("bpm", 120.0)
	var lanes = data_dict.get("lanes", 4)
	var sync_tolerance = data_dict.get("sync_tolerance", 0.2)
	var auto_identify := bool(data_dict.get("auto_identify", true))
	var manual_artist = data_dict.get("manual_artist", "")
	var manual_title = data_dict.get("manual_title", "")
	var generation_mode = data_dict.get("generation_mode", "basic")
	var chart_intent_req := str(data_dict.get("chart_intent", "")).strip_edges()
	var http_client = HTTPClient.new()
	var err = http_client.connect_to_host(_api_host(), _api_port())
	if err != OK:
		local_error = "Не удалось подключиться: " + str(err)
	else:
		if not _poll_until_http_connected(http_client, func(): return _cancel_notes):
			PerfTrace.end("perf.detail.generation.network.wait", _perf_network)
			if _cancel_notes:
				_notes_res = {"error": "Отменено пользователем"}
			else:
				_notes_res = {"error": "Таймаут подключения к серверу (%s:%d)" % [_api_host(), _api_port()]}
			http_client.close()
			_notes_done = true
			return
		_notes_status_queue.append("GEN_API_CONNECTED")
	# SongFormer structure analysis — part of existing SPLITTING_STEMS stage, indeterminate (no %)
	if SettingsManager and bool(SettingsManager.get_setting("songformer_enabled", false)):
		_notes_status_queue.append("Анализ структуры (SongFormer, CPU)...")
		if http_client.get_status() != HTTPClient.STATUS_CONNECTED:
			local_error = "Нет подключения. Статус: " + str(http_client.get_status())
		else:
			var file_access = FileAccess.open(song_path, FileAccess.READ)
			if not file_access:
				_notes_res = {"error": "Не удалось открыть файл"}
				http_client.close()
				_notes_done = true
				return
			var audio_data = file_access.get_buffer(file_access.get_length())
			file_access.close()
			var boundary = "notes_boundary_" + str(randi())
			var task_id = str(data_dict.get("task_id", ""))
			if task_id == "":
				task_id = str(Time.get_ticks_msec()) + "_" + str(randi())
				_notes_active_task_id = task_id
			var body = PackedByteArray()
			var client_meta = SongLibrary.get_metadata_for_song(song_path)
			var client_genres_arr: Array = []
			var genres_val = client_meta.get("genres", "")
			if typeof(genres_val) == TYPE_ARRAY:
				for g in genres_val:
					var s = str(g).strip_edges()
					if s != "":
						client_genres_arr.append(s)
			else:
				var client_genres_str = str(genres_val)
				if client_genres_str.strip_edges() != "":
					for part in client_genres_str.split(","):
						var s = str(part).strip_edges()
						if s != "":
							client_genres_arr.append(s)
			var client_primary_genre = str(client_meta.get("primary_genre", ""))
			if client_primary_genre.strip_edges() == "" and client_genres_arr.size() > 0:
				client_primary_genre = str(client_genres_arr[0])
			var needs_genre_detection := auto_identify and client_genres_arr.is_empty()
			if needs_genre_detection:
				client_genres_arr = []
				client_primary_genre = ""
			else:
				auto_identify = false
			var preset_id = generation_mode
			var chart_intent := chart_intent_req
			var goal_meta := str(data_dict.get("goal", "")).strip_edges().to_lower()
			var difficulty_meta := str(data_dict.get("difficulty", "")).strip_edges().to_lower()
			var chart_stem_meta := str(data_dict.get("chart_stem", "")).strip_edges().to_lower()
			var has_job_style := goal_meta != "" or difficulty_meta != "" or chart_stem_meta != ""
			if goal_meta == "" and difficulty_meta == "" and chart_stem_meta != "":
				var stem_pair := _GoalDiff.pair_from_stem(chart_stem_meta)
				goal_meta = str(stem_pair.get("goal", _GoalDiff.DEFAULT_GOAL)).strip_edges().to_lower()
				difficulty_meta = str(stem_pair.get("difficulty", _GoalDiff.DEFAULT_DIFFICULTY)).strip_edges().to_lower()
			if not has_job_style:
				if goal_meta == "":
					goal_meta = str(SettingsManager.get_setting("generation_goal", "original")).strip_edges().to_lower()
				if difficulty_meta == "":
					difficulty_meta = str(SettingsManager.get_setting("generation_difficulty", "medium")).strip_edges().to_lower()
			elif goal_meta == "" or difficulty_meta == "":
				push_error(
					"GenAPI: incomplete job style metadata goal=%s difficulty=%s stem=%s — check queue task"
					% [goal_meta, difficulty_meta, chart_stem_meta]
				)
			if chart_stem_meta == "" and goal_meta != "" and difficulty_meta != "":
				chart_stem_meta = _GoalDiff.chart_stem(goal_meta, difficulty_meta)
			push_warning(
				"GenAPI metadata goal=%s difficulty=%s stem=%s intent=%s"
				% [goal_meta, difficulty_meta, chart_stem_meta, chart_intent_req]
			)
			print(
				"[GenAPI] metadata goal=%s difficulty=%s stem=%s intent=%s task=%s"
				% [goal_meta, difficulty_meta, chart_stem_meta, chart_intent_req, task_id]
			)
			if chart_intent == "":
				chart_intent = str(SettingsManager.get_setting("last_generation_intent", "")).strip_edges()
			if chart_intent == "" and goal_meta != "" and difficulty_meta != "":
				chart_intent = _GoalDiff.intent_for(goal_meta, difficulty_meta)
			if chart_intent == "":
				chart_intent = "original"
			var metadata := {
				"original_filename": song_path.get_file(),
				"song_path": song_path.replace("\\", "/"),
				"chart_id": NotesUtils.chart_id_from_song_path(song_path),
				"bpm": bpm,
				"lanes": lanes,
				"instrument_type": instrument_type,
				"sync_tolerance": sync_tolerance,
				"generation_mode": generation_mode,
				"chart_intent": chart_intent,
				"goal": goal_meta,
				"difficulty": difficulty_meta,
				"generation_goal": goal_meta,
				"generation_difficulty": difficulty_meta,
				"chart_stem": chart_stem_meta,
				"preset_id": preset_id,
				"auto_identify_track": auto_identify,
				"manual_artist": manual_artist,
				"manual_title": manual_title,
				"progress_delay_seconds": 0.0,
				"use_stems": false if instrument_type == "fullmix" else bool(SettingsManager.get_setting("use_stems_in_generation", true)),
				"genres": client_genres_arr,
				"primary_genre": client_primary_genre,
				"include_hi_hats": bool(SettingsManager.get_setting("generation_include_hi_hats", true)),
				"stem_keep_all": bool(SettingsManager.get_setting("generation_stem_keep_all", true)),
				"stem_retention_mode": str(SettingsManager.get_setting("generation_stem_retention_mode", "after_job")),
				"stem_keep_count": 10,
				"stem_ttl_seconds": 900,
				"songformer_enabled": bool(SettingsManager.get_setting("songformer_enabled", false)),
				"songformer_backend": str(SettingsManager.get_setting("songformer_backend", "auto")),
			}
			# Goal×difficulty pairs carry density/fill/groove on the server preset.
			# Client sliders apply only in custom mode or legacy intent requests.
			var use_goal_diff_preset := (
				_GoalDiff.is_goal(goal_meta) and _GoalDiff.is_difficulty(difficulty_meta)
			)
			if generation_mode == "custom" or (not use_goal_diff_preset and chart_intent != ""):
				metadata["fill"] = int(SettingsManager.get_setting("generation_fill", 30))
				metadata["groove"] = int(SettingsManager.get_setting("generation_groove", 50))
				metadata["density"] = int(SettingsManager.get_setting("generation_density", 50))
				metadata["grid_snap_strength"] = int(SettingsManager.get_setting("generation_grid_snap_strength", 80))
				metadata["accent_strong_beats"] = bool(SettingsManager.get_setting("generation_accent_strong_beats", true))
				metadata["genre_template_strength"] = int(SettingsManager.get_setting("generation_genre_template_strength", 60))
				metadata["critic_strength"] = int(SettingsManager.get_setting("generation_critic_strength", 50))
				metadata["groove_completion"] = bool(SettingsManager.get_setting("generation_groove_completion", true))
				metadata["raw_adtof"] = bool(SettingsManager.get_setting("generation_raw_adtof", false))
			var metadata_json = JSON.stringify(metadata)
			var metadata_part = "--" + boundary + "\r\n" + "Content-Disposition: form-data; name=\"metadata\"\r\n" + "Content-Type: application/json\r\n\r\n" + metadata_json + "\r\n"
			body.append_array(metadata_part.to_utf8_buffer())
			var file_part_header = "--" + boundary + "\r\n" + "Content-Disposition: form-data; name=\"audio_file\"; filename=\"upload.mp3\"\r\n" + "Content-Type: audio/mpeg\r\n\r\n"
			body.append_array(file_part_header.to_utf8_buffer())
			body.append_array(audio_data)
			var closing_boundary = "\r\n--" + boundary + "--\r\n"
			body.append_array(closing_boundary.to_utf8_buffer())
			var headers = PackedStringArray(["Content-Type: multipart/form-data; boundary=" + boundary, "X-Task-Id: " + task_id])
			var gen_endpoint := "/generate_bass" if instrument_type == "bass" else "/generate_drums"
			err = http_client.request_raw(HTTPClient.METHOD_POST, gen_endpoint, headers, body)
			if err != OK:
				local_error = "Ошибка отправки: " + str(err)
			else:
				http_client.poll()
				var use_remote := _uses_remote_generation_server()
				var last_poll := Time.get_ticks_msec() - 1000
				var last_result_poll := Time.get_ticks_msec() - 2000
				var last_count := 0
				var task_result_done := false
				while http_client.get_status() == HTTPClient.STATUS_REQUESTING:
					http_client.poll()
					OS.delay_msec(100)
					if Time.get_ticks_msec() - last_poll >= 800:
						var poll_client = HTTPClient.new()
						var perr = poll_client.connect_to_host(_api_host(), _api_port())
						if perr == OK and _poll_until_http_connected(poll_client, Callable()):
							if poll_client.get_status() == HTTPClient.STATUS_CONNECTED:
								var q: String = "/task_status?task_id=" + task_id
								poll_client.request_raw(HTTPClient.METHOD_GET, q, PackedStringArray(), PackedByteArray())
								while poll_client.get_status() == HTTPClient.STATUS_REQUESTING:
									poll_client.poll()
									OS.delay_msec(50)
								var response_body = _read_http_response_body(poll_client)
								var txt = response_body.get_string_from_utf8()
								var js = JSON.parse_string(txt)
								if js and js.has("statuses"):
									var statuses = js["statuses"]
									if statuses is Array:
										for i in range(last_count, statuses.size()):
											_notes_status_queue.append(str(statuses[i]))
										last_count = statuses.size()
						poll_client.close()
						last_poll = Time.get_ticks_msec()
					if use_remote and Time.get_ticks_msec() - last_result_poll >= 1500:
						last_result_poll = Time.get_ticks_msec()
						var remote_parsed = _try_notes_task_result(
							task_id, song_path, bpm, lanes, instrument_type, func(): return _cancel_notes
						)
						if remote_parsed.has("result"):
							local_result = remote_parsed.result
							task_result_done = true
							break
						if remote_parsed.has("error"):
							local_error = remote_parsed.error
							task_result_done = true
							break
					if _cancel_notes:
						PerfTrace.end("perf.detail.generation.network.wait", _perf_network)
						_send_cancel_task_request(task_id)
						_notes_res = {"error": "Отменено пользователем"}
						http_client.close()
						_notes_done = true
						return
				if not task_result_done:
					if use_remote:
						_notes_status_queue.append("GEN_API_FETCHING_RESULT")
						var fetched = _fetch_notes_task_result(
							task_id, song_path, bpm, lanes, instrument_type, func(): return _cancel_notes
						)
						if fetched.has("result"):
							local_result = fetched.result
						elif fetched.has("error"):
							local_error = fetched.error
					else:
						_notes_status_queue.append("GEN_API_RECEIVING_RESPONSE")
						var response_code = http_client.get_response_code()
						var response_body = _read_http_response_body(http_client)
						_notes_status_queue.append("GEN_API_PROCESSING_RESPONSE")
						var response_json = JSON.parse_string(response_body.get_string_from_utf8())
						if response_code == 200 and response_json != null:
							var parsed = _notes_payload_from_json(
								response_json, song_path, bpm, lanes, instrument_type
							)
							if parsed.has("result"):
								local_result = parsed.result
							elif parsed.has("error"):
								local_error = parsed.error
						elif response_code == 499:
							local_error = "Отменено пользователем"
						elif response_code == 200:
							local_error = "Ответ сервера обрезан или повреждён (%d байт)" % response_body.size()
						else:
							local_error = "Ошибка: " + str(response_code)
						if local_error != "" or local_result.is_empty():
							var fetched = _fetch_notes_task_result(
								task_id, song_path, bpm, lanes, instrument_type, func(): return _cancel_notes
							)
							if fetched.has("result"):
								local_result = fetched.result
								local_error = ""
							elif fetched.has("error") and local_error == "":
								local_error = fetched.error
				http_client.close()
			if local_error == "" and local_result is Dictionary:
				local_result["task_id"] = task_id
	PerfTrace.end("perf.detail.generation.network.wait", _perf_network)
	_notes_res = local_result if local_error == "" else {"error": local_error}
	# Server perf: if response contained perf block, log it via PerfTrace
	if _notes_res is Dictionary and _notes_res.has("perf") and _notes_res["perf"] is Dictionary:
		var _perf_srv: Dictionary = _notes_res["perf"]
		for k in _perf_srv.keys():
			PerfTrace.record("perf.detail.generation.server." + str(k), int(_perf_srv[k] * 1000))
		# Also print server perf for debug console when DETAIL enabled
		if PerfTrace.is_enabled(PerfTrace.Level.DETAIL):
			print("[PERF][SERVER] " + str(_perf_srv))
	_notes_done = true


func _notify_genre_analysis_achievement() -> void:
	var tree := Engine.get_main_loop()
	if tree == null or not (tree is SceneTree):
		return
	var ge := (tree as SceneTree).root.get_node_or_null("GameEngine")
	if ge == null:
		ge = (tree as SceneTree).root.find_child("GameEngine", true, false)
	if ge and ge.has_method("get_achievement_system"):
		var ach = ge.get_achievement_system()
		if ach and ach.has_method("on_genre_analyzed"):
			ach.on_genre_analyzed()