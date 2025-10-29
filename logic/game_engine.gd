# logic/game_engine.gd
extends Control

var transitions = null
var main_menu_instance = null
var intro_instance = null
var current_screen = null

var settings_manager: SettingsManager = null
var player_data_manager: PlayerDataManager = null
var music_manager: MusicManager = null

var song_metadata_manager: SongMetadataManager = null

func _ready():
	initialize_logic()
	initialize_screens()
	show_intro()

func initialize_logic():
	player_data_manager = PlayerDataManager.new()
	settings_manager = SettingsManager.new()
	
	song_metadata_manager = SongMetadataManager.new()
	if song_metadata_manager:
		pass
	else:
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

	transitions = preload("res://logic/transitions.gd").new(self)

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
