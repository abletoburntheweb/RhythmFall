# logic/transitions.gd
var game_engine = null
var parent = null

var main_menu_instance = null
# var game_screen_instance = null
# var song_select_instance = null
# var achievements_instance = null
# var shop_instance = null
# var settings_instance = null

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
	if main_menu_instance:
		print("Transitions.gd: main_menu_instance не null, добавляем как дочерний к game_engine")
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
		print("Transitions.gd: ОШИБКА! main_menu_instance равен null в transition_open_main_menu!")

func transition_open_achievements():


	var new_screen = _instantiate_if_exists("res://scenes/achievements/AchievementsScreen.tscn")
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


	var new_screen = _instantiate_if_exists("res://shop/ShopScreen.tscn")
	if new_screen:


		if game_engine.current_screen:
			game_engine.current_screen.queue_free()
		game_engine.add_child(new_screen)
		game_engine.current_screen = new_screen
	else:
		print("Transitions: ShopScreen.tscn не найден, переход отменён.")

func transition_close_shop():
	game_engine.current_screen = null 

	transition_open_main_menu()


func transition_open_settings(_from_pause=false):

	var new_screen = _instantiate_if_exists("res://settings/SettingsMenu.tscn")
	if new_screen:

		if game_engine.current_screen:
			game_engine.current_screen.queue_free()
		game_engine.add_child(new_screen)
		game_engine.current_screen = new_screen
	else:
		print("Transitions: SettingsMenu.tscn не найден, переход отменён.")

func transition_close_settings(_from_pause=false):
	game_engine.current_screen = null


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
