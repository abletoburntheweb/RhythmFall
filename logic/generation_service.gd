extends Node
class_name GenerationService

signal bpm_started(song_path: String, display_name: String)
signal bpm_completed(song_path: String, bpm_value: int, display_name: String)
signal bpm_error(song_path: String, message: String, display_name: String)

signal notes_started(song_path: String, display_name: String)
signal notes_completed(song_path: String, instrument: String, display_name: String)
signal notes_error(song_path: String, message: String, display_name: String)

var _api: GenerationApiClient = null
var _game_engine: Node = null

var _active_bpm_task: Dictionary = {}
var _active_notes_task: Dictionary = {}
var _last_bpm_task: Dictionary = {}
var _last_notes_task: Dictionary = {}

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

func _get_display_name(song_path: String) -> String:
	var meta = SongLibrary.get_metadata_for_song(song_path)
	var artist = meta.get("artist", "Неизвестен")
	var title = meta.get("title", "Н/Д")
	return "%s - %s" % [artist, title]

func start_bpm_analysis(song_path: String):
	if _active_bpm_task.has("path"):
		return
	_active_bpm_task = {"path": song_path, "display": _get_display_name(song_path)}
	_last_bpm_task = _active_bpm_task.duplicate(true)
	_api.analyze_bpm(song_path)

func start_notes_generation(song_path: String, instrument: String, bpm: float, lanes: int, tolerance: float, auto_identify: bool, artist: String, title: String, mode: String):
	if _active_notes_task.has("path"):
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
			_game_engine.notifications_add_or_update("bpm", "Вычисление BPM для %s" % disp, true, "cancel_bpm")

func _on_bpm_completed(bpm_value: int):
	if not _active_bpm_task.has("path"):
		return
	var path = _active_bpm_task.path
	var disp = _active_bpm_task.display
	SongLibrary.update_metadata(path, {"bpm": str(bpm_value)})
	bpm_completed.emit(path, bpm_value, disp)
	if SettingsManager.get_setting("show_generation_notifications", true) and _game_engine and _game_engine.has_method("notifications_complete"):
		_game_engine.notifications_complete("bpm", "BPM вычислен: %d для %s" % [bpm_value, disp])
	if MusicManager and MusicManager.has_method("play_analysis_success"):
		MusicManager.play_analysis_success()
	_active_bpm_task.clear()

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

func _on_notes_started():
	if _active_notes_task.has("path"):
		var disp = _active_notes_task.display
		notes_started.emit(_active_notes_task.path, disp)
		if SettingsManager.get_setting("show_generation_notifications", true) and _game_engine and _game_engine.has_method("notifications_add_or_update"):
			_game_engine.notifications_add_or_update("notes", "Генерация нот для %s" % disp, true, "cancel_notes")

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
		_game_engine.notifications_complete("notes", "Ноты сгенерированы для %s" % disp)
	if MusicManager and MusicManager.has_method("play_analysis_success"):
		MusicManager.play_analysis_success()
	_active_notes_task.clear()

func _on_notes_error(message: String):
	if not _active_notes_task.has("path"):
		return
	var disp = _active_notes_task.display
	notes_error.emit(_active_notes_task.path, message, disp)
	if SettingsManager.get_setting("show_generation_notifications", true) and _game_engine and _game_engine.has_method("notifications_error"):
		var show_msg = message
		if show_msg.find("подключиться") != -1:
			show_msg = "Ошибка генерации: нет подключения к серверу"
		_game_engine.notifications_error("notes", show_msg, "retry_notes", "cancel_notes")
	if MusicManager and MusicManager.has_method("play_analysis_error"):
		MusicManager.play_analysis_error()
	_active_notes_task.clear()

func get_active_bpm_task() -> Dictionary:
	return _active_bpm_task.duplicate(true)

func get_active_notes_task() -> Dictionary:
	return _active_notes_task.duplicate(true)
