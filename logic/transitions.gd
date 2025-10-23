# logic/transitions.gd
var game_engine = null
var parent = null

var main_menu_instance = null

func _init(p_game_engine):
	game_engine = p_game_engine
	parent = p_game_engine

func set_main_menu_instance(instance):
	main_menu_instance = instance
	print("Transitions: Установлен инстанс MainMenu")

func _instantiate_if_exists(scene_path):
	var scene_resource = load(scene_path)
	if scene_resource and scene_resource is PackedScene:
		return scene_resource.instantiate()
	else:
		printerr("Transitions: Сцена не найдена: ", scene_path)
		return null

func transition_open_game(start_level=null, selected_song=null, instrument="standard"):
	if main_menu_instance and main_menu_instance.is_game_open:
		transition_close_game()
		return


	var new_game_screen = _instantiate_if_exists("res://scenes/game_screen/GameScreen.tscn")
	if new_game_screen:
		if new_game_screen.has_method("_set_start_level"):
			new_game_screen._set_start_level(start_level)
		if new_game_screen.has_method("_set_selected_song"):
			new_game_screen._set_selected_song(selected_song)
		if new_game_screen.has_method("_set_instrument"):
			new_game_screen._set_instrument(instrument)
		if new_game_screen.has_method("start_game"):
			new_game_screen.start_game()


		if game_engine.current_screen:
			game_engine.current_screen.queue_free()
		game_engine.add_child(new_game_screen)
		game_engine.current_screen = new_game_screen

		if main_menu_instance:
			main_menu_instance.is_game_open = true

	else:
		print("Transitions: GameScreen.tscn не найден, переход отменён.")

func transition_close_game():
	if not main_menu_instance or not main_menu_instance.is_game_open:
		return



	game_engine.current_screen = null 

	transition_open_main_menu()

	if main_menu_instance:
		main_menu_instance.is_game_open = false

func transition_open_song_select():


	var new_screen = _instantiate_if_exists("res://scenes/song_select/song_select.tscn")
	if new_screen:

		if game_engine.current_screen:
			game_engine.current_screen.queue_free()
		game_engine.add_child(new_screen)
		game_engine.current_screen = new_screen

	else:
		print("Transitions: song_select.tscn не найден, переход отменён.")

func transition_close_song_select():
	game_engine.current_screen = null 


	transition_open_main_menu()

func transition_open_main_menu():
	print("Transitions.gd: transition_open_main_menu вызван")
	print("Transitions.gd: main_menu_instance в Transitions: ", main_menu_instance)
	
	if main_menu_instance and is_instance_valid(main_menu_instance):
		print("Transitions.gd: main_menu_instance действителен, добавляем как дочерний к game_engine")
		print("Transitions.gd: game_engine.current_screen ДО проверки и удаления: ", game_engine.current_screen)
		if game_engine.current_screen and game_engine.current_screen != main_menu_instance:
			print("Transitions.gd: Удаляем текущий экран: ", game_engine.current_screen)
			game_engine.current_screen.queue_free()
			game_engine.current_screen = null 
		print("Transitions.gd: Вызываем game_engine.add_child(main_menu_instance)")
		game_engine.add_child(main_menu_instance)
		print("Transitions.gd: Установлен game_engine.current_screen = main_menu_instance")
		game_engine.current_screen = main_menu_instance
		print("Transitions.gd: game_engine.current_screen ПОСЛЕ обновления: ", game_engine.current_screen)
	else:
		print("Transitions.gd: main_menu_instance недействителен или null. Создаём новый экземпляр MainMenu.")
		var new_main_menu_instance = _instantiate_if_exists("res://scenes/main_menu/main_menu.tscn")
		if new_main_menu_instance:
			if new_main_menu_instance.has_method("set_transitions"):
				new_main_menu_instance.set_transitions(self)
				print("Transitions.gd: set_transitions вызван для нового MainMenu.")
			else:
				printerr("Transitions.gd: Новый экземпляр MainMenu не имеет метода set_transitions!")
			
			main_menu_instance = new_main_menu_instance
			print("Transitions.gd: main_menu_instance обновлён на новый экземпляр.")
			
			if game_engine.current_screen:
				game_engine.current_screen.queue_free()
				game_engine.current_screen = null
			
			game_engine.add_child(main_menu_instance)
			game_engine.current_screen = main_menu_instance
			print("Transitions.gd: Новый MainMenu добавлен и установлен как current_screen.")
		else:
			printerr("Transitions.gd: ОШИБКА! Не удалось создать новый экземпляр MainMenu!")

func transition_open_achievements():


	var new_screen = _instantiate_if_exists("res://scenes/achievements/achievements_screen.tscn")
	if new_screen:

		if game_engine.current_screen:
			game_engine.current_screen.queue_free()
		game_engine.add_child(new_screen)
		game_engine.current_screen = new_screen
	else:
		print("Transitions: AchievementsScreen.tscn не найден, переход отменён.")

func transition_close_achievements():
	game_engine.current_screen = null 


	transition_open_main_menu()

func transition_open_shop():
	print("Transitions.gd: transition_open_shop вызван")
	var new_screen = _instantiate_if_exists("res://scenes/shop/shop_screen.tscn")
	if new_screen:
		print("Transitions.gd: ShopScreen успешно инстанцирован: ", new_screen)  
		if game_engine.current_screen:
			print("Transitions.gd: Удаляем текущий экран перед добавлением магазина: ", game_engine.current_screen) 
			game_engine.current_screen.queue_free()
		game_engine.add_child(new_screen)
		game_engine.current_screen = new_screen
		print("Transitions.gd: ShopScreen добавлен и установлен как current_screen") 
	else:
		print("Transitions.gd: ОШИБКА! ShopScreen.tscn не найден или не удалось инстанцировать.") 
		var scene_resource = load("res://scenes/shop/shop_screen.tscn")
		if not scene_resource:
			print("Transitions.gd: load() вернул null для пути shop_screen.tscn")
		elif not (scene_resource is PackedScene):
			print("Transitions.gd: Загруженный ресурс не является PackedScene: ", scene_resource)
		else:
			print("Transitions.gd: PackedScene загружен, но instantiate() вернул null. Проверьте сцену и скрипт ShopScreen на ошибки!")

func transition_close_shop():
	game_engine.current_screen = null 

	transition_open_main_menu()


func transition_open_settings(_from_pause=false):
	var new_screen = _instantiate_if_exists("res://scenes/settings_menu/settings_menu.tscn")
	if new_screen:
		if game_engine and game_engine.has_method("get_settings_manager") and game_engine.has_method("get_music_manager"):
			var settings_mgr = game_engine.get_settings_manager()
			var music_mgr = game_engine.get_music_manager()
			var game_scr = null
			if settings_mgr and music_mgr:
				if new_screen.has_method("set_managers"):
					new_screen.set_managers(settings_mgr, music_mgr, game_scr, self) 
					print("Transitions.gd: Менеджеры переданы в SettingsMenu.")
				else:
					printerr("Transitions.gd: SettingsMenu instance не имеет метода set_managers!")
			else:
				printerr("Transitions.gd: Не удалось получить settings_manager или music_manager из game_engine!")
		else:
			printerr("Transitions.gd: game_engine не имеет методов get_settings_manager или get_music_manager!")

		if game_engine.current_screen:
			game_engine.current_screen.queue_free()
		game_engine.add_child(new_screen)
		game_engine.current_screen = new_screen
	else:
		print("Transitions: SettingsMenu.tscn не найден, переход отменён.")

func transition_close_settings(_from_pause=false):
	print("Transitions.gd: transition_close_settings called. _from_pause=", _from_pause)
	
	if game_engine.current_screen:
		print("Transitions.gd: Удаляем текущий экран (настройки) перед переходом: ", game_engine.current_screen)
		game_engine.current_screen.queue_free()
		game_engine.current_screen = null
	else:
		print("Transitions.gd: Текущий экран уже null.")
	
	transition_open_main_menu()

func transition_exit_to_main_menu():


	transition_open_main_menu()


func transition_exit_game():
	print("Transitions.gd: transition_exit_game вызван")
	if game_engine.has_method("request_quit"):
		print("Transitions.gd: Вызываю game_engine.request_quit()")
		game_engine.request_quit()
	else:
		print("Transitions.gd: ОШИБКА! GameEngine не имеет метода request_quit!")

func open_game(start_level=null):
	transition_open_game(start_level)

func close_game():
	transition_close_game()

func open_song_select():
	transition_open_song_select()

func close_song_select():
	transition_close_song_select()

func open_game_with_song(selected_song, instrument="standard"):
	transition_open_game(null, selected_song, instrument)

func resume_game():
	pass
func exit_to_main_menu():
	transition_exit_to_main_menu()

func open_achievements():
	transition_open_achievements()

func close_achievements():
	transition_close_achievements()

func open_shop():
	transition_open_shop()

func close_shop():
	transition_close_shop()

func open_settings(from_pause=false):
	transition_open_settings(from_pause)

func close_settings(from_pause=false):
	transition_close_settings(from_pause)

func open_main_menu():
	transition_open_main_menu()

func exit_game():
	print("Transitions.gd: exit_game (обёртка) вызван")
	transition_exit_game()
