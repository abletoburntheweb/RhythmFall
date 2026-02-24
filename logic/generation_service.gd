extends Node
class_name GenerationService

signal bpm_started(song_path: String, display_name: String)
signal bpm_completed(song_path: String, bpm_value: int, display_name: String)
signal bpm_error(song_path: String, message: String, display_name: String)
signal bpm_progress(song_path: String, stage_index: int, total: int, status: String)

signal notes_started(song_path: String, display_name: String)
signal notes_completed(song_path: String, instrument: String, display_name: String)
signal notes_error(song_path: String, message: String, display_name: String)
signal notes_progress(song_path: String, stage_index: int, total: int, status: String)

var _api: GenerationApiClient = null
var _game_engine: Node = null

var _active_bpm_task: Dictionary = {}
var _active_notes_task: Dictionary = {}
var _last_bpm_task: Dictionary = {}
var _last_notes_task: Dictionary = {}
var _bpm_queue: Array[String] = []
var _notes_queue: Array[Dictionary] = []
var _bpm_delay_timer: Timer = null
var _notes_delay_timer: Timer = null

var _BPM_STAGES := [
	"Подключение к серверу...",
	"Соединение установлено",
	"Открытие файла",
	"Формирование запроса",
	"Отправка данных",
	"Получение ответа",
	"Обработка ответа"
]
var _NOTES_STAGES := [
	"Подключение к серверу...",
	"Соединение установлено",
	"Идентификация трека...",
	"Определение жанров...",
	"Разделение на стемы...",
	"Детекция ударных...",
	"Назначение линий...",
	"Сохранение нот...",
	"Формирование ответа..."
]

func _stage_index_for(status: String, stages: Array) -> int:
	for i in range(stages.size()):
		if status.begins_with(stages[i]):
			return i + 1
	return 0

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
	var artist = meta.get("artist", "Неизвестен")
	var title = meta.get("title", "Н/Д")
	return "%s - %s" % [artist, title]

func start_bpm_analysis(song_path: String):
	if _active_bpm_task.has("path"):
		_bpm_queue.append(song_path)
		return
	_active_bpm_task = {"path": song_path, "display": _get_display_name(song_path)}
	_last_bpm_task = _active_bpm_task.duplicate(true)
	_api.analyze_bpm(song_path)

func start_notes_generation(song_path: String, instrument: String, bpm: float, lanes: int, tolerance: float, auto_identify: bool, artist: String, title: String, mode: String):
	if _active_notes_task.has("path"):
		_notes_queue.append({
			"path": song_path,
			"instrument": instrument,
			"bpm": bpm,
			"lanes": lanes,
			"tolerance": tolerance,
			"auto_identify": auto_identify,
			"artist": artist,
			"title": title,
			"mode": mode
		})
		return
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
		"mode": mode
	}
	_last_notes_task = _active_notes_task.duplicate(true)
	_api.generate_notes(song_path, instrument, bpm, lanes, tolerance, auto_identify, artist, title, mode)

func get_genres_for_manual_entry(artist: String, title: String):
	_api.detect_genres(artist, title)

func cancel_bpm():
	if _api:
		_api.request_cancel_bpm()

func cancel_notes():
	if _api:
		_api.request_cancel_notes()

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
		start_notes_generation(t.path, t.instrument, t.bpm, t.lanes, t.tolerance, t.auto_identify, t.artist, t.title, t.mode)

func _on_bpm_started():
	if _active_bpm_task.has("path"):
		var path = _active_bpm_task.path
		var disp = _active_bpm_task.display
		bpm_started.emit(path, disp)
		if SettingsManager.get_setting("show_generation_notifications", true) and _game_engine and _game_engine.has_method("notifications_add_or_update"):
			var total := 1 + _bpm_queue.size()
			_game_engine.notifications_add_or_update("bpm", "Вычисление BPM для %s (1/%d)%s" % [disp, total, _suffix_from_settings()], true, "cancel_bpm")

func _on_bpm_completed(bpm_value: int):
	if not _active_bpm_task.has("path"):
		return
	var path = _active_bpm_task.path
	var disp = _active_bpm_task.display
	SongLibrary.update_metadata(path, {"bpm": str(bpm_value)})
	bpm_completed.emit(path, bpm_value, disp)
	if SettingsManager.get_setting("show_generation_notifications", true) and _game_engine and _game_engine.has_method("notifications_complete"):
		_game_engine.notifications_complete("bpm", "BPM вычислен: %d для %s%s" % [bpm_value, disp, _suffix_from_settings()])
	if MusicManager and MusicManager.has_method("play_analysis_success"):
		MusicManager.play_analysis_success()
	_active_bpm_task.clear()
	if _bpm_queue.size() > 0:
		_start_next_bpm_delayed()

func _on_bpm_error(message: String):
	if not _active_bpm_task.has("path"):
		return
	var disp = _active_bpm_task.display
	var path = _active_bpm_task.path
	bpm_error.emit(path, message, disp)
	if SettingsManager.get_setting("show_generation_notifications", true) and _game_engine and _game_engine.has_method("notifications_error"):
		var show_msg = "Ошибка вычисления BPM: %s" % message
		_game_engine.notifications_error("bpm", show_msg, "retry_bpm", "cancel_bpm")
	if MusicManager and MusicManager.has_method("play_analysis_error"):
		MusicManager.play_analysis_error()
	_active_bpm_task.clear()
	if _bpm_queue.size() > 0:
		_start_next_bpm_delayed()

func _on_bpm_status(status: String):
	if _active_bpm_task.has("path"):
		var disp = _active_bpm_task.display
		var total := 1 + _bpm_queue.size()
		var k := _stage_index_for(status, _BPM_STAGES)
		if SettingsManager.get_setting("show_generation_notifications", true) and _game_engine and _game_engine.has_method("notifications_add_or_update"):
			var stage_info := ("(%d/%d)" % [k, _BPM_STAGES.size()]) if k > 0 else ""
			_game_engine.notifications_add_or_update("bpm", "%s (1/%d) %s: %s%s" % [disp, total, stage_info, status, _suffix_from_settings()], true, "cancel_bpm")
		bpm_progress.emit(_active_bpm_task.path, k, _BPM_STAGES.size(), status)

func _on_notes_started():
	if _active_notes_task.has("path"):
		var disp = _active_notes_task.display
		notes_started.emit(_active_notes_task.path, disp)
		if SettingsManager.get_setting("show_generation_notifications", true) and _game_engine and _game_engine.has_method("notifications_add_or_update"):
			var total := 1 + _notes_queue.size()
			var instr_code = "П" if String(_active_notes_task.get("instrument","drums")).to_lower() == "drums" else String(_active_notes_task.get("instrument","")).substr(0, 1).to_upper()
			var mode_code = "Б" if String(_active_notes_task.get("mode","basic")).to_lower() == "basic" else "У"
			var lanes_val = int(_active_notes_task.get("lanes", 4))
			var suffix = " (%s %s %d)" % [instr_code, mode_code, lanes_val]
			_game_engine.notifications_add_or_update("notes", "Генерация нот для %s (1/%d)%s" % [disp, total, suffix], true, "cancel_notes")

func _on_notes_completed(notes_data: Array, bpm_value: float, instrument_type: String):
	if not _active_notes_task.has("path"):
		return
	var path = _active_notes_task.path
	var disp = _active_notes_task.display
	var gen_mode = _active_notes_task.mode
	var lanes_val = _active_notes_task.lanes
	var base_name = path.get_file().get_basename()
	var notes_filename = "%s_drums_%s_lanes%d.json" % [base_name, gen_mode.to_lower(), lanes_val]
	var notes_dir = "user://notes/%s" % base_name
	var dir = DirAccess.open("user://notes")
	if not dir:
		DirAccess.make_dir_absolute("user://notes")
		dir = DirAccess.open("user://notes")
	if dir:
		if not dir.dir_exists(notes_dir):
			dir.make_dir(notes_dir)
	var notes_path = "%s/%s" % [notes_dir, notes_filename]
	var fa = FileAccess.open(notes_path, FileAccess.WRITE)
	if fa:
		fa.store_string(JSON.stringify(notes_data))
		fa.close()
	notes_completed.emit(path, instrument_type, disp)
	if SettingsManager.get_setting("show_generation_notifications", true) and _game_engine and _game_engine.has_method("notifications_complete"):
		var instr_code = "П" if instrument_type.to_lower() == "drums" else instrument_type.substr(0, 1).to_upper()
		var mode_code = "Б" if gen_mode.to_lower() == "basic" else "У"
		_game_engine.notifications_complete("notes", "%s: Генерация завершена: %s %s %d" % [disp, instr_code, mode_code, int(lanes_val)])
	if MusicManager and MusicManager.has_method("play_analysis_success"):
		MusicManager.play_analysis_success()
	_active_notes_task.clear()
	if _notes_queue.size() > 0:
		_start_next_notes_delayed()

func _on_notes_error(message: String):
	if not _active_notes_task.has("path"):
		return
	var disp = _active_notes_task.display
	notes_error.emit(_active_notes_task.path, message, disp)
	if SettingsManager.get_setting("show_generation_notifications", true) and _game_engine and _game_engine.has_method("notifications_error"):
		var instr_code = "П" if String(_active_notes_task.get("instrument","drums")).to_lower() == "drums" else String(_active_notes_task.get("instrument","")).substr(0, 1).to_upper()
		var mode_code = "Б" if String(_active_notes_task.get("mode","basic")).to_lower() == "basic" else "У"
		var lanes_val = int(_active_notes_task.get("lanes", 4))
		var suffix = " (%s %s %d)" % [instr_code, mode_code, lanes_val]
		var show_msg = "%s: Ошибка %s%s" % [disp, message, suffix]
		_game_engine.notifications_error("notes", show_msg, "retry_notes", "cancel_notes")
	if MusicManager and MusicManager.has_method("play_analysis_error"):
		MusicManager.play_analysis_error()
	_active_notes_task.clear()
	if _notes_queue.size() > 0:
		_start_next_notes_delayed()

func _on_notes_status(status: String):
	if _active_notes_task.has("path"):
		var disp = _active_notes_task.display
		var total := 1 + _notes_queue.size()
		var k := _stage_index_for(status, _NOTES_STAGES)
		if SettingsManager.get_setting("show_generation_notifications", true) and _game_engine and _game_engine.has_method("notifications_add_or_update"):
			var stage_info := ("(%d/%d)" % [k, _NOTES_STAGES.size()]) if k > 0 else ""
			var instr_code = "П" if String(_active_notes_task.get("instrument","drums")).to_lower() == "drums" else String(_active_notes_task.get("instrument","")).substr(0, 1).to_upper()
			var mode_code = "Б" if String(_active_notes_task.get("mode","basic")).to_lower() == "basic" else "У"
			var lanes_val = int(_active_notes_task.get("lanes", 4))
			var suffix = " (%s %s %d)" % [instr_code, mode_code, lanes_val]
			_game_engine.notifications_add_or_update("notes", "%s (1/%d) %s: %s%s" % [disp, total, stage_info, status, suffix], true, "cancel_notes")
		notes_progress.emit(_active_notes_task.path, k, _NOTES_STAGES.size(), status)

func _on_genres_status(status: String):
	pass

func _on_genres_completed(artist: String, title: String, genres: Array):
	var path = ""
	if _active_notes_task.has("path"):
		path = _active_notes_task.path
	elif _last_notes_task.has("path"):
		path = _last_notes_task.path
	if path != "":
		var primary = str(genres[0]) if genres.size() > 0 else "unknown"
		print("[Genres] Update for %s: %s (primary: %s)" % [path, ", ".join(genres), primary])
		SongLibrary.update_metadata(path, {"genres": genres, "primary_genre": primary})

func get_active_bpm_task() -> Dictionary:
	return _active_bpm_task.duplicate(true)

func get_active_notes_task() -> Dictionary:
	return _active_notes_task.duplicate(true)

func _get_queue_delay_seconds() -> float:
	return float(SettingsManager.get_setting("generation_queue_delay_seconds", 5.0))

func get_bpm_queue_position(song_path: String) -> int:
	if _active_bpm_task.has("path") and _active_bpm_task.path == song_path:
		return 1
	for i in range(_bpm_queue.size()):
		if _bpm_queue[i] == song_path:
			return i + 2
	return 0

func get_notes_queue_position(song_path: String) -> int:
	if _active_notes_task.has("path") and _active_notes_task.path == song_path:
		return 1
	for i in range(_notes_queue.size()):
		var item = _notes_queue[i]
		if item.has("path") and item.path == song_path:
			return i + 2
	return 0

func _suffix_from_settings() -> String:
	var instrument = String(SettingsManager.get_setting("last_generation_instrument", "drums"))
	var mode = String(SettingsManager.get_setting("last_generation_mode", "basic"))
	var lanes = int(SettingsManager.get_setting("last_generation_lanes", 4))
	var instr_code = "П" if instrument.to_lower() == "drums" else instrument.substr(0, 1).to_upper()
	var mode_code = "Б" if mode.to_lower() == "basic" else "У"
	return " (%s %s %d)" % [instr_code, mode_code, lanes]

func _start_next_bpm_delayed():
	if _bpm_delay_timer == null:
		_bpm_delay_timer = Timer.new()
		_bpm_delay_timer.one_shot = true
		_bpm_delay_timer.timeout.connect(_on_bpm_delay_timeout)
		add_child(_bpm_delay_timer)
	_bpm_delay_timer.wait_time = _get_queue_delay_seconds()
	_bpm_delay_timer.start()

func _on_bpm_delay_timeout():
	if _bpm_queue.size() == 0:
		return
	var next_path = _bpm_queue[0]
	_bpm_queue.remove_at(0)
	start_bpm_analysis(next_path)

func _start_next_notes_delayed():
	if _notes_delay_timer == null:
		_notes_delay_timer = Timer.new()
		_notes_delay_timer.one_shot = true
		_notes_delay_timer.timeout.connect(_on_notes_delay_timeout)
		add_child(_notes_delay_timer)
	_notes_delay_timer.wait_time = _get_queue_delay_seconds()
	_notes_delay_timer.start()

func _on_notes_delay_timeout():
	if _notes_queue.size() == 0:
		return
	var next = _notes_queue[0]
	_notes_queue.remove_at(0)
	start_notes_generation(
		next.get("path", ""),
		next.get("instrument", "drums"),
		float(next.get("bpm", 120.0)),
		int(next.get("lanes", 4)),
		float(next.get("tolerance", 0.2)),
		bool(next.get("auto_identify", true)),
		next.get("artist", ""),
		next.get("title", ""),
		next.get("mode", "basic")
	)
