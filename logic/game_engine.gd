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

var song_metadata_manager: SongMetadataManager = null

func _ready():
	initialize_logic()
	initialize_screens()
	show_intro()

func initialize_logic():
	player_data_manager = PlayerDataManager.new()
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
	
	achievement_system = AchievementSystem.new(achievement_manager, player_data_manager, music_manager)
	achievement_manager.notification_mgr = self
	
	player_data_manager.set_game_engine_reference(self)
	
	transitions = preload("res://logic/transitions.gd").new(self)

	_handle_player_login()

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
		show_main_menu()
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
	print("Achievement data: ", achievement)
	var popup = preload("res://scenes/achievements/achievement_pop_up.tscn").instantiate()
	
	popup.set_achievement_data(achievement)

	add_child(popup)

	popup.show_popup()
	
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
