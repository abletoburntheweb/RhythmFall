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
	print("GameEngine.gd: _ready вызван.")
	print("GameEngine запущен")
	initialize_logic()
	initialize_screens()
	show_intro()

func initialize_logic():
	player_data_manager = PlayerDataManager.new()
	settings_manager = SettingsManager.new()
	
	song_metadata_manager = SongMetadataManager.new()
	if song_metadata_manager:
		print("GameEngine.gd: SongMetadataManager инстанцирован.")
	else:
		printerr("GameEngine.gd: Не удалось инстанцировать SongMetadataManager!")

	music_manager = MusicManager.new() 
	if music_manager:
		music_manager.set_player_data_manager(player_data_manager)
		add_child(music_manager)
		print("GameEngine.gd: MusicManager инстанцирован, настроен и добавлен как дочерний.")
		if settings_manager:
			music_manager.update_volumes_from_settings(settings_manager)
			print("GameEngine.gd: Обновлены громкости MusicManager из SettingsManager при инициализации (после добавления в сцену).")
		else:
			printerr("GameEngine.gd: SettingsManager не установлен при инициализации MusicManager!")
	else:
		printerr("GameEngine.gd: Не удалось инстанцировать MusicManager!")

	transitions = preload("res://logic/transitions.gd").new(self)

func initialize_screens():
	print("GameEngine.gd: initialize_screens вызван")
	main_menu_instance = preload("res://scenes/main_menu/main_menu.tscn").instantiate()
	print("GameEngine.gd: main_menu_instance инстанцирован: ", main_menu_instance)
	if main_menu_instance:
		print("GameEngine.gd: main_menu_instance не null, вызываем set_transitions")
		if main_menu_instance.has_method("set_transitions"):
			if transitions:
				main_menu_instance.set_transitions(transitions)
				print("GameEngine.gd: Экземпляр Transitions передан в MainMenu.")
			else:
				printerr("GameEngine.gd: Экземпляр Transitions равен null!")

func show_intro():
	print("GameEngine.gd: show_intro вызван")
	if intro_instance:
		_switch_to_screen(intro_instance)
		show_main_menu()
	else:
		print("GameEngine.gd: Intro отсутствует, переходим к главному меню.")
		show_main_menu() 

func show_main_menu():
	print("GameEngine.gd: show_main_menu вызван. current_screen перед вызовом Transitions: ", current_screen)
	if transitions:
		transitions.open_main_menu()
		print("GameEngine.gd: transitions.open_main_menu() завершён. current_screen после: ", current_screen)
	else:
		print("GameEngine.gd: ОШИБКА! transitions не установлен!")

func get_song_metadata_manager() -> SongMetadataManager:
	return song_metadata_manager

func _switch_to_screen(new_screen_instance):
	print("GameEngine.gd: _switch_to_screen вызван для ", new_screen_instance, ". current_screen до: ", current_screen)
	if current_screen and current_screen != new_screen_instance:
		print("GameEngine.gd: Удаляем предыдущий экран: ", current_screen)
		current_screen.queue_free()
		current_screen = null
	if new_screen_instance:
		print("GameEngine.gd: Добавляем новый экран как дочерний: ", new_screen_instance)
		add_child(new_screen_instance)
		current_screen = new_screen_instance
		print("GameEngine.gd: current_screen обновлён на: ", current_screen)

func request_quit():
	print("GameEngine.gd: request_quit вызван. Пытаемся закрыть игру.")
	get_tree().quit()

func prepare_screen_exit(screen_to_exit: Node) -> bool:
	if current_screen != screen_to_exit:
		printerr("GameEngine.gd: prepare_screen_exit - переданный узел не является current_screen.")
		return false

	print("GameEngine.gd: Подготовка к выходу из экрана: ", screen_to_exit)

	if screen_to_exit.has_method("cleanup_before_exit"):
		screen_to_exit.cleanup_before_exit()
		print("GameEngine.gd: Вызван cleanup_before_exit на ", screen_to_exit)

	if player_data_manager:
		player_data_manager._save()
		print("GameEngine.gd: Данные игрока сохранены перед выходом из экрана.")
	if settings_manager:
		settings_manager.save_settings()
		print("GameEngine.gd: Настройки сохранены перед выходом из экрана.")


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
