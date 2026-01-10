# logic/game_engine.gd
extends Control

var transitions = null
var main_menu_instance = null
var intro_instance = null
var current_screen = null

var settings_manager: SettingsManager = null
var player_data_manager: PlayerDataManager = null
var music_manager: MusicManager = null
var achievement_manager: AchievementManager = null
var achievement_system: AchievementSystem = null
var achievement_queue_manager: AchievementQueueManager = null

var song_metadata_manager: SongMetadataManager = null

var session_history_manager: SessionHistoryManager = null

var track_stats_manager: TrackStatsManager = null

var _session_start_time_ticks: int = 0
var _play_time_timer: SceneTreeTimer = null
const PLAY_TIME_UPDATE_INTERVAL: float = 10.0 

@onready var fps_label: Label = $FPSLayer/FPSLabel

func _ready():
	initialize_logic()
	initialize_screens()
	show_intro()
	_session_start_time_ticks = Time.get_ticks_msec() 
	_start_play_time_timer()
	
	_initialize_display_settings()

func _initialize_display_settings():
	if settings_manager:
		fps_label.visible = settings_manager.get_show_fps()
	
	if settings_manager:
		if settings_manager.get_fullscreen():
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			if not settings_manager.get_fullscreen():
				DisplayServer.window_set_size(Vector2i(1920, 1080))
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, true)
				var screen_size = DisplayServer.screen_get_size()
				var window_size = Vector2i(1920, 1080)
				DisplayServer.window_set_position((screen_size - window_size) / 2)

func _process(delta):
	if fps_label.visible:
		if Engine.get_process_frames() % 30 == 0: 
			fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

func update_display_settings():
	if settings_manager:
		if settings_manager.get_fullscreen():
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(Vector2i(1920, 1080))
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, true)
			var screen_size = DisplayServer.screen_get_size()
			var window_size = Vector2i(1920, 1080)
			DisplayServer.window_set_position((screen_size - window_size) / 2)
		
		fps_label.visible = settings_manager.get_show_fps()

func _start_play_time_timer():
	print("GameEngine.gd (DEBUG): _start_play_time_timer вызван. Интервал: ", PLAY_TIME_UPDATE_INTERVAL)
	if _play_time_timer:
		if _play_time_timer.time_left > 0:
			_play_time_timer.timeout.disconnect(_on_play_time_update_timeout) 
		print("GameEngine.gd (DEBUG): Старый таймер отключен.")

	_play_time_timer = get_tree().create_timer(PLAY_TIME_UPDATE_INTERVAL)
	if _play_time_timer:
		var connect_result = _play_time_timer.timeout.connect(_on_play_time_update_timeout)
		print("GameEngine.gd (DEBUG): Результат подключения таймера: ", connect_result)
		if connect_result != 0:
			printerr("GameEngine.gd (DEBUG): Ошибка подключения таймера! Код: ", connect_result)

func _on_play_time_update_timeout():
	if player_data_manager:
		var elapsed_ms = Time.get_ticks_msec() - _session_start_time_ticks
		var elapsed_seconds = int(elapsed_ms / 1000.0)
		print("GameEngine.gd (DEBUG): Прошло секунд с последнего таймера: %d (таймер сработал)" % elapsed_seconds)
		player_data_manager.add_play_time_seconds(elapsed_seconds)
		_session_start_time_ticks = Time.get_ticks_msec()
		_start_play_time_timer()

func _exit_tree():
	_finalize_session_time()
	if _play_time_timer and _play_time_timer.is_connected("timeout", _on_play_time_update_timeout):
		_play_time_timer.timeout.disconnect(_on_play_time_update_timeout)

func _finalize_session_time():
	if player_data_manager:
		var elapsed_ms = Time.get_ticks_msec() - _session_start_time_ticks
		var elapsed_seconds = int(elapsed_ms / 1000.0)
		player_data_manager.add_play_time_seconds(elapsed_seconds)
		print("GameEngine.gd: Сессия завершена, добавлено времени: %d сек (%s)" % [elapsed_seconds, _play_time_seconds_to_string(elapsed_seconds)])
		_session_start_time_ticks = 0

func _play_time_seconds_to_string(total_seconds: int) -> String:
	var hours = total_seconds / 3600
	var minutes = (total_seconds % 3600) / 60
	return str(hours).pad_zeros(2) + ":" + str(minutes).pad_zeros(2)

func initialize_logic():
	player_data_manager = PlayerDataManager.new()

	track_stats_manager = TrackStatsManager.new(player_data_manager) 

	player_data_manager.set_track_stats_manager(track_stats_manager)
	
	settings_manager = SettingsManager.new()
	
	song_metadata_manager = SongMetadataManager.new()
	if not song_metadata_manager:
		printerr("GameEngine.gd: Не удалось инстанцировать SongMetadataManager!")

	music_manager = MusicManager.new() 
	if music_manager:
		music_manager.set_player_data_manager(player_data_manager)
		add_child(music_manager)
		if settings_manager:
			music_manager.update_volumes_from_settings(settings_manager)
		else:
			printerr("GameEngine.gd: SettingsManager не установлен при инициализации MusicManager!")
	else:
		printerr("GameEngine.gd: Не удалось инстанцировать MusicManager!")

	achievement_manager = AchievementManager.new()
	
	achievement_system = AchievementSystem.new(achievement_manager, player_data_manager, music_manager, track_stats_manager)
	achievement_manager.notification_mgr = self
	
	achievement_queue_manager = preload("res://logic/achievement_queue_manager.gd").new()
	add_child(achievement_queue_manager)
	
	player_data_manager.set_game_engine_reference(self)

	session_history_manager = SessionHistoryManager.new() 
	print("GameEngine.gd: SessionHistoryManager инициализирован.")

	transitions = preload("res://logic/transitions.gd").new(self)

	call_deferred("_handle_player_login")

func _date_dict_to_string(date_dict: Dictionary) -> String:
	if date_dict.has("year") and date_dict.has("month") and date_dict.has("day"):
		return "%04d-%02d-%02d" % [date_dict.year, date_dict.month, date_dict.day]
	return ""

func _string_to_date_dict(date_str: String) -> Dictionary:
	var parts = date_str.split("-")
	if parts.size() == 3:
		return {
			"year": parts[0].to_int(),
			"month": parts[1].to_int(),
			"day": parts[2].to_int()
		}
	return {}

func _is_yesterday(date_dict: Dictionary, today_str: String) -> bool:
	var today_parts = today_str.split("-")
	if today_parts.size() != 3:
		return false
	var today_year = today_parts[0].to_int()
	var today_month = today_parts[1].to_int()
	var today_day = today_parts[2].to_int()
	
	if date_dict.year == today_year and date_dict.month == today_month and date_dict.day == (today_day - 1):
		return true
	return false

func _handle_player_login():
	var today_dict = Time.get_date_dict_from_system()
	var today_str = _date_dict_to_string(today_dict) 
	
	var last_login_str = player_data_manager.data.get("last_login_date", "")

	var last_login_dict = {} 
	if last_login_str != "":
		last_login_dict = _string_to_date_dict(last_login_str) 
	
	var login_streak = player_data_manager.data.get("login_streak", 0)
	var new_streak = 1

	if not last_login_dict.is_empty():
		if last_login_str == today_str:
			print("[GameEngine] Игрок уже заходил сегодня.")
			new_streak = login_streak 
		elif _is_yesterday(last_login_dict, today_str):
			new_streak = login_streak + 1
			print("[GameEngine] Вход подряд. Streak: ", new_streak)
		else:
			new_streak = 1
			print("[GameEngine] Разрыв серии входов. Новый streak: ", new_streak)
	else:
		new_streak = 1
		print("[GameEngine] Первый вход или нет данных о входах. Streak: ", new_streak)

	player_data_manager.set_login_streak(new_streak)
	
	if achievement_system:
		achievement_system.on_daily_login()
	
func initialize_screens():
	intro_instance = preload("res://scenes/intro/intro_screen.tscn").instantiate()
	if intro_instance:
		if intro_instance.has_method("set_game_engine_reference"):
			intro_instance.set_game_engine_reference(self)

	main_menu_instance = preload("res://scenes/main_menu/main_menu.tscn").instantiate()
	if main_menu_instance:
		if main_menu_instance.has_method("set_transitions"):
			if transitions:
				main_menu_instance.set_transitions(transitions)
			else:
				printerr("GameEngine.gd: Экземпляр Transitions равен null!")

func show_intro():
	if intro_instance:
		_switch_to_screen(intro_instance)
	else:
		show_main_menu() 

func show_main_menu():
	if transitions:
		transitions.open_main_menu()
	else:
		print("GameEngine.gd: ОШИБКА! transitions не установлен!")

func get_song_metadata_manager() -> SongMetadataManager:
	return song_metadata_manager

func _switch_to_screen(new_screen_instance):
	if current_screen and current_screen != new_screen_instance:
		current_screen.queue_free()
		current_screen = null
	if new_screen_instance:
		add_child(new_screen_instance)
		current_screen = new_screen_instance

func request_quit():
	_finalize_session_time()
	if player_data_manager:
		player_data_manager._save()
	if settings_manager:
		settings_manager.save_settings()
	get_tree().quit()

func prepare_screen_exit(screen_to_exit: Node) -> bool:
	if current_screen != screen_to_exit:
		printerr("GameEngine.gd: prepare_screen_exit - переданный узел не является current_screen.")
		return false

	if screen_to_exit.has_method("cleanup_before_exit"):
		screen_to_exit.cleanup_before_exit()

	if player_data_manager:
		player_data_manager._save()
	if settings_manager:
		settings_manager.save_settings()

	return true

func show_achievement_popup(achievement: Dictionary):
	print("GameEngine: Запрос на показ ачивки: ", achievement.get("title", "Unknown"))
	if achievement_queue_manager and achievement_queue_manager.is_inside_tree():
		achievement_queue_manager.add_achievement_to_queue(achievement)
	else:
		print("GameEngine: AchievementQueueManager не готов, откладываем показ ачивки")
		if not achievement_queue_manager.has_method("_delayed_achievements"):
			achievement_queue_manager._delayed_achievements = []
		achievement_queue_manager._delayed_achievements.append(achievement)
	
func get_main_menu_instance():
	return main_menu_instance

func get_transitions():
	return transitions

func get_settings_manager() -> SettingsManager:
	return settings_manager

func get_player_data_manager() -> PlayerDataManager:
	return player_data_manager

func get_music_manager() -> MusicManager:
	return music_manager

func get_achievement_manager() -> AchievementManager:
	return achievement_manager

func get_achievement_system() -> AchievementSystem:
	return achievement_system

func get_achievement_queue_manager() -> AchievementQueueManager:
	return achievement_queue_manager

func get_session_history_manager() -> SessionHistoryManager:
	return session_history_manager

func get_track_stats_manager() -> TrackStatsManager:
	return track_stats_manager
