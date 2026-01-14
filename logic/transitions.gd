# logic/transitions.gd
var game_engine = null
var parent = null

var session_history_manager = null

var main_menu_instance = null

func _init(p_game_engine):
	game_engine = p_game_engine
	parent = p_game_engine
	if game_engine and game_engine.has_method("get_session_history_manager"):
		session_history_manager = game_engine.get_session_history_manager()
		print("Transitions.gd: SessionHistoryManager получен из GameEngine: ", session_history_manager)
	else:
		printerr("Transitions.gd: GameEngine не имеет метода get_session_history_manager!")
		session_history_manager = null 

func set_main_menu_instance(instance):
	main_menu_instance = instance

func _instantiate_if_exists(scene_path):
	var scene_resource = load(scene_path)
	if scene_resource and scene_resource is PackedScene:
		return scene_resource.instantiate()
	else:
		printerr("Transitions: Сцена не найдена: ", scene_path)
		return null

func hide_level_ui():
	if game_engine and game_engine.has_method("get_level_layer"):
		var level_layer = game_engine.get_level_layer()
		if level_layer:
			level_layer.visible = false

func show_level_ui():
	if game_engine and game_engine.has_method("get_level_layer"):
		var level_layer = game_engine.get_level_layer()
		if level_layer:
			level_layer.visible = true

func transition_open_game(start_level=null, selected_song=null, instrument="standard", results_mgr = null, generation_mode: String = "basic"):
	hide_level_ui() 
	
	if main_menu_instance and main_menu_instance.is_game_open:
		transition_close_game()
		return

	var new_game_screen = _instantiate_if_exists("res://scenes/game_screen/game_screen.tscn")
	if new_game_screen:
		if new_game_screen.has_method("_set_instrument"):
			new_game_screen._set_instrument(instrument)

		if new_game_screen.has_method("_set_start_level"):
			new_game_screen._set_start_level(start_level)
		if new_game_screen.has_method("_set_selected_song"):
			new_game_screen._set_selected_song(selected_song)

		if new_game_screen.has_method("set_results_manager") and results_mgr:
			new_game_screen.set_results_manager(results_mgr)
			print("Transitions.gd: ResultsManager передан в GameScreen.")
		elif results_mgr:
			printerr("Transitions.gd: GameScreen не имеет метода set_results_manager, но ResultsManager передан.")

		if new_game_screen.has_method("_set_generation_mode"):
			new_game_screen._set_generation_mode(generation_mode)
			print("Transitions.gd: Режим генерации передан в GameScreen: ", generation_mode)

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
		if new_screen.has_method("set_transitions"):
			new_screen.set_transitions(self) 
		else:
			printerr("Transitions.gd: Новый экземпляр SongSelect не имеет метода set_transitions!")

		if game_engine.current_screen:
			game_engine.current_screen.queue_free()
		game_engine.add_child(new_screen)
		game_engine.current_screen = new_screen
	else:
		print("Transitions: song_select.tscn не найден, переход отменён.")

func transition_close_song_select():
	if game_engine.current_screen:
		game_engine.current_screen.queue_free()
		game_engine.current_screen = null 
	else:
		print("Transitions.gd: Текущий экран уже null, ничего не удаляем.")

	transition_open_main_menu()

func transition_open_main_menu():
	show_level_ui()  
	if main_menu_instance and is_instance_valid(main_menu_instance):
		if main_menu_instance.is_inside_tree():
			print("Transitions.gd: main_menu_instance уже внутри дерева сцен, не добавляем заново.")
		else:
			if game_engine.current_screen and game_engine.current_screen != main_menu_instance:
				game_engine.current_screen.queue_free()
				game_engine.current_screen = null 
			game_engine.add_child(main_menu_instance)
			game_engine.current_screen = main_menu_instance
		if game_engine.has_method("get_music_manager"):
			var music_manager = game_engine.get_music_manager()
			if music_manager and music_manager.has_method("play_menu_music"):
				music_manager.play_menu_music()
			else:
				print("Transitions.gd: У MusicManager нет метода play_menu_music. Реализуйте его в MusicManager.")
		else:
			print("Transitions.gd: У GameEngine нет метода get_music_manager!")

	else:
		var new_main_menu_instance = _instantiate_if_exists("res://scenes/main_menu/main_menu.tscn")
		if new_main_menu_instance:
			if new_main_menu_instance.has_method("set_transitions"):
				new_main_menu_instance.set_transitions(self)
			else:
				printerr("Transitions.gd: Новый экземпляр MainMenu не имеет метода set_transitions!")
			
			main_menu_instance = new_main_menu_instance
			
			if game_engine.current_screen:
				game_engine.current_screen.queue_free()
				game_engine.current_screen = null
			
			game_engine.add_child(main_menu_instance)
			game_engine.current_screen = main_menu_instance
			if game_engine.has_method("get_music_manager"):
				var music_manager = game_engine.get_music_manager()
				if music_manager and music_manager.has_method("play_menu_music"):
					music_manager.play_menu_music()
				else:
					print("Transitions.gd: У MusicManager нет метода play_menu_music. Реализуйте его в MusicManager.")
			else:
				print("Transitions.gd: У GameEngine нет метода get_music_manager!")

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

func transition_open_profile():

	
	var new_screen = _instantiate_if_exists("res://scenes/profile/profile_screen.tscn")
	if new_screen:
		if new_screen.has_method("setup_managers"):
			var trans = self
			var music_mgr = null
			var player_data_mgr = null

			if game_engine.has_method("get_music_manager"):
				music_mgr = game_engine.get_music_manager()
			if game_engine.has_method("get_player_data_manager"):
				player_data_mgr = game_engine.get_player_data_manager()

			new_screen.setup_managers(trans, music_mgr, player_data_mgr)
		else:
			printerr("Transitions.gd: Экземпляр ProfileScreen не имеет метода setup_managers!")

		if game_engine.current_screen:
			game_engine.current_screen.queue_free()
		game_engine.add_child(new_screen)
		game_engine.current_screen = new_screen
	else:
		print("Transitions: ProfileScreen.tscn не найден, переход отменён.")

func transition_close_profile():
	game_engine.current_screen = null 
	transition_open_main_menu()

func transition_open_shop():
	
	var new_screen = _instantiate_if_exists("res://scenes/shop/shop_screen.tscn")
	if new_screen:
		if game_engine.current_screen:
			game_engine.current_screen.queue_free()
		game_engine.add_child(new_screen)
		game_engine.current_screen = new_screen
		if game_engine.has_method("get_music_manager"):
			var music_manager = game_engine.get_music_manager()
			if music_manager and music_manager.has_method("pause_menu_music"):
				music_manager.pause_menu_music()
			elif music_manager and music_manager.has_method("stop"):
				print("Transitions.gd: У MusicManager нет метода pause_menu_music. Реализуйте его в MusicManager.")
			else:
				print("Transitions.gd: У MusicManager нет подходящего метода для остановки музыки меню.")
		else:
			print("Transitions.gd: У GameEngine нет метода get_music_manager!")

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
	if game_engine.current_screen:
		game_engine.current_screen.queue_free()
		game_engine.current_screen = null
	transition_open_main_menu()

func transition_open_settings(_from_pause=false):
	var new_screen = _instantiate_if_exists("res://scenes/settings_menu/settings_menu.tscn")
	if not new_screen:
		print("Transitions: SettingsMenu.tscn не найден, переход отменён.")
		return

	if game_engine and game_engine.has_method("get_settings_manager") and game_engine.has_method("get_music_manager"):
		var settings_mgr = game_engine.get_settings_manager()
		var music_mgr = game_engine.get_music_manager()
		if settings_mgr and music_mgr and new_screen.has_method("set_managers"):
			var game_scr = null
			if _from_pause and game_engine.current_screen:
				game_scr = game_engine.current_screen
			new_screen.set_managers(settings_mgr, music_mgr, game_scr, self)
		else:
			printerr("Transitions.gd: Не удалось передать менеджеры в SettingsMenu.")

	if _from_pause:
		if game_engine.current_screen:
			game_engine.current_screen.add_child(new_screen)
		else:
			printerr("Transitions.gd: Нет активного экрана для паузы!")
	else:
		game_engine.add_child(new_screen)

func transition_close_settings(_from_pause=false):
	if _from_pause:
		if game_engine.current_screen:
			for child in game_engine.current_screen.get_children():
				if child is Control and child.has_method("cleanup_before_exit"):
					child.cleanup_before_exit()
					child.queue_free()
					break
	else:
		for child in game_engine.get_children():
			if child is Control and child.has_method("cleanup_before_exit"):
				child.cleanup_before_exit()
				child.queue_free()
				break

func transition_open_victory_screen(score: int, combo: int, max_combo: int, accuracy: float, song_info: Dictionary = {}, results_mgr = null, missed_notes: int = 0, perfect_hits: int = 0, hit_notes: int = 0):
	hide_level_ui()
	var new_screen = _instantiate_if_exists("res://scenes/victory_screen/victory_screen.tscn")
	if new_screen:
		if new_screen.has_method("set_victory_data"):
			new_screen.set_victory_data(score, combo, max_combo, accuracy, song_info, 1.0, 0, missed_notes, perfect_hits, hit_notes)
		
		if new_screen.has_method("set_results_manager") and results_mgr:
			new_screen.set_results_manager(results_mgr)
			print("Transitions.gd: ResultsManager передан в VictoryScreen.")
		elif results_mgr:
			printerr("Transitions.gd: VictoryScreen не имеет метода set_results_manager, но ResultsManager передан.")
		
		if new_screen.has_method("set_session_history_manager"):
			if session_history_manager: 
				new_screen.set_session_history_manager(session_history_manager)
			else:
				printerr("Transitions.gd: session_history_manager в Transitions равен null!")
		else:
			printerr("Transitions.gd: VictoryScreen не имеет метода set_session_history_manager.")
		
		new_screen.song_select_requested.connect(transition_open_song_select)
		new_screen.replay_requested.connect(_on_replay_requested.bind(song_info))
		
		if game_engine.current_screen:
			game_engine.current_screen.queue_free()
		game_engine.add_child(new_screen)
		game_engine.current_screen = new_screen
	else:
		print("Transitions: victory_screen.tscn не найден, переход отменён.")

func _on_replay_requested(song_info: Dictionary):
	transition_open_game(null, song_info, "standard")

func open_victory_screen(score: int, combo: int, max_combo: int, accuracy: float, song_info: Dictionary = {}, results_mgr = null, missed_notes: int = 0, perfect_hits: int = 0, hit_notes: int = 0):
	transition_open_victory_screen(score, combo, max_combo, accuracy, song_info, results_mgr, missed_notes, perfect_hits, hit_notes)

func transition_exit_to_main_menu():
	transition_open_main_menu() 

func transition_exit_game():
	if game_engine.has_method("request_quit"):
		game_engine.request_quit()
	else:
		print("Transitions.gd: ОШИБКА! GameEngine не имеет метода request_quit!")

func open_game_with_instrument(
	song_path_or_instrument: String = "",
	instrument_if_path_provided: String = "standard",
	results_mgr = null,
	generation_mode: String = "basic"
):
	var current_screen = game_engine.current_screen
	var selected_song_data = {}
	var instrument = instrument_if_path_provided
	var results_manager = results_mgr
	
	var is_instrument_call = (song_path_or_instrument == "standard" or song_path_or_instrument == "drums") and instrument_if_path_provided == "standard"
	
	if is_instrument_call:
		instrument = song_path_or_instrument
		if current_screen and current_screen.has_method("get_current_selected_song"):
			selected_song_data = current_screen.get_current_selected_song()
			var song_path = selected_song_data.get("path", "")
			print("Transitions.gd: Получен путь к песне из текущего экрана: %s" % song_path)
			if current_screen.has_method("get_results_manager"):
				results_manager = current_screen.get_results_manager()
		else:
			print("Transitions.gd: Не удалось получить выбранную песню из текущего экрана, запуск игры с инструментом: ", instrument)
			selected_song_data = {}
			return 
	
	else:
		var song_path = song_path_or_instrument
		if song_path.is_empty() and current_screen and current_screen.has_method("get_current_selected_song"):
			selected_song_data = current_screen.get_current_selected_song()
			song_path = selected_song_data.get("path", "")
			print("Transitions.gd: Получен путь к песне из текущего экрана: %s" % song_path)
		else:
			selected_song_data = {"path": song_path}
			print("Transitions.gd: Используем переданный путь к песне: %s" % song_path)

		if song_path.is_empty():
			printerr("Transitions.gd: Невозможно открыть игру - путь к песне пуст!")
			return

	open_game_with_song(selected_song_data, instrument, results_manager, generation_mode) 

func open_game(start_level=null):
	transition_open_game(start_level)

func close_game():
	transition_close_game()

func open_song_select():
	transition_open_song_select()

func close_song_select():
	transition_close_song_select()

func open_game_with_song(selected_song, instrument="standard", results_mgr = null, generation_mode: String = "basic"): 
	transition_open_game(null, selected_song, instrument, results_mgr, generation_mode) 

func resume_game():
	pass
func exit_to_main_menu():
	transition_exit_to_main_menu()

func open_achievements():
	transition_open_achievements()

func close_achievements():
	transition_close_achievements()

func open_profile():
	transition_open_profile()

func close_profile():
	transition_close_profile()

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
	transition_exit_game()
