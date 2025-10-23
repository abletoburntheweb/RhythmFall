# scenes/main_menu/main_menu.gd
extends Control

var transitions = null


var is_game_open = false

func _ready():
	print("MainMenu.gd: _ready вызван")

	var game_engine = get_parent()
	if game_engine and game_engine.has_method("get_music_manager"):
		var music_manager = game_engine.get_music_manager()
		if music_manager:
			print("MainMenu.gd: MusicManager получен через GameEngine.get_music_manager().")
			music_manager.play_menu_music() 
		else:
			printerr("MainMenu.gd: MusicManager не найден через GameEngine.get_music_manager()!")
	else:
		printerr("MainMenu.gd: Не удалось получить GameEngine или метод get_music_manager()!")

	var play_btn = $PlayButton
	if play_btn:
		play_btn.pressed.connect(_on_play_pressed)
		print("MainMenu.gd: Подключён PlayButton")
	else:
		push_error("MainMenu.gd: ОШИБКА! Узел $PlayButton не найден!")

	var song_select_btn = $SongSelectButton
	if song_select_btn:
		song_select_btn.pressed.connect(_on_song_select_pressed)
		print("MainMenu.gd: Подключён SongSelectButton")
	else:
		push_error("MainMenu.gd: ОШИБКА! Узел $SongSelectButton не найден!")

	var achievements_btn = $AchievementsButton
	if achievements_btn:
		achievements_btn.pressed.connect(_on_achievements_pressed)
		print("MainMenu.gd: Подключён AchievementsButton")
	else:
		push_error("MainMenu.gd: ОШИБКА! Узел $AchievementsButton не найден!")

	var shop_btn = $ShopButton
	if shop_btn:
		shop_btn.pressed.connect(_on_shop_pressed)
		print("MainMenu.gd: Подключён ShopButton")
	else:
		push_error("MainMenu.gd: ОШИБКА! Узел $ShopButton не найден!")

	var settings_btn = $SettingsButton
	if settings_btn:
		settings_btn.pressed.connect(_on_settings_pressed)
		print("MainMenu.gd: Подключён SettingsButton")
	else:
		push_error("MainMenu.gd: ОШИБКА! Узел $SettingsButton не найден!")

	var exit_btn = $ExitButton
	if exit_btn:
		exit_btn.pressed.connect(_on_exit_pressed)
		print("MainMenu.gd: Подключён ExitButton")
	else:
		push_error("MainMenu.gd: ОШИБКА! Узел $ExitButton не найден!")

	if play_btn and song_select_btn and achievements_btn and shop_btn and settings_btn and exit_btn:
		print("MainMenu загружен")

func set_transitions(transitions_instance):
	transitions = transitions_instance
	print("MainMenu.gd: Transitions инстанс получен")

func _on_play_pressed():
	print("Кнопка ИГРАТЬ нажата")
	var game_engine = get_parent()
	if game_engine and game_engine.has_method("get_music_manager"):
		var music_manager = game_engine.get_music_manager()
		if music_manager:
			music_manager.stop_music()
	if transitions:
		transitions.open_game()

func _on_song_select_pressed():
	print("Кнопка ВЫБОР ПЕСНИ нажата")
	var game_engine = get_parent()
	if game_engine and game_engine.has_method("get_music_manager"):
		var music_manager = game_engine.get_music_manager()
		if music_manager:
			music_manager.stop_music()
	if transitions:
		transitions.open_song_select()

func _on_achievements_pressed():
	print("Кнопка ДОСТИЖЕНИЯ нажата")
	var game_engine = get_parent()
	if game_engine and game_engine.has_method("get_music_manager"):
		var music_manager = game_engine.get_music_manager()
		if music_manager:
			music_manager.play_select_sound()
	if transitions:
		transitions.open_achievements()

func _on_shop_pressed():
	print("Кнопка МАГАЗИН нажата")
	var game_engine = get_parent() 
	if game_engine and game_engine.has_method("get_music_manager"):
		var music_manager = game_engine.get_music_manager()
		if music_manager:
			music_manager.play_select_sound()
	if transitions:
		transitions.open_shop()

func _on_settings_pressed():
	print("Кнопка НАСТРОЙКИ нажата")
	var game_engine = get_parent() 
	if game_engine and game_engine.has_method("get_music_manager"):
		var music_manager = game_engine.get_music_manager()
		if music_manager:
			music_manager.play_select_sound()
	if transitions:
		transitions.open_settings()

func _on_exit_pressed():
	print("MainMenu.gd: Кнопка ВЫХОД нажата") 
	var game_engine = get_parent() 
	if game_engine and game_engine.has_method("get_music_manager"):
		var music_manager = game_engine.get_music_manager()
		if music_manager:
			music_manager.stop_music()
	if transitions:
		print("MainMenu.gd: Вызываю transitions.exit_game()")
		transitions.exit_game()
	else:
		print("MainMenu.gd: ОШИБКА! Переменная transitions не установлена!")

func exit_to_main_menu():
	var game_engine = get_parent()
	if game_engine and game_engine.has_method("get_music_manager"):
		var music_manager = game_engine.get_music_manager()
		if music_manager:
			music_manager.play_menu_music()
	if transitions:
		transitions.exit_to_main_menu()
