# scenes/main_menu/main_menu.gd
extends Control

var transitions = null
var music_manager = null

var is_game_open = false

var button_configs = {
	"PlayButton": _on_play_pressed,
	"SongSelectButton": _on_song_select_pressed,
	"AchievementsButton": _on_achievements_pressed,
	"ShopButton": _on_shop_pressed,
	"ProfileButton": _on_profile_pressed,
	"SettingsButton": _on_settings_pressed,
	"ExitButton": _on_exit_pressed,
}

func _ready():
	print("MainMenu.gd: _ready вызван")

	var game_engine = get_parent()
	if game_engine and game_engine.has_method("get_music_manager"):
		music_manager = game_engine.get_music_manager()
		if music_manager:
			print("MainMenu.gd: MusicManager получен через GameEngine.get_music_manager().")
			music_manager.play_menu_music()
		else:
			printerr("MainMenu.gd: MusicManager не найден через GameEngine.get_music_manager()!")
	else:
		printerr("MainMenu.gd: Не удалось получить GameEngine или метод get_music_manager()!")
		
	var all_buttons_connected = true
	for button_name in button_configs:
		var button = get_node_or_null(button_name)
		if button:
			button.pressed.connect(button_configs[button_name])
			print("MainMenu.gd: Подключён %s" % button_name)
		else:
			push_error("MainMenu.gd: ОШИБКА! Узел $%s не найден!" % button_name)
			all_buttons_connected = false

	if all_buttons_connected:
		print("MainMenu загружен")

func set_transitions(transitions_instance):
	transitions = transitions_instance

func _play_select_sound():
	if music_manager:
		music_manager.play_select_sound()

func _stop_music():
	if music_manager:
		music_manager.stop_music()

func _play_menu_music():
	if music_manager:
		music_manager.play_menu_music()

func _on_play_pressed():
	_stop_music()
	if transitions:
		transitions.open_game()

func _on_song_select_pressed():
	_stop_music()
	if transitions:
		transitions.open_song_select()

func _on_achievements_pressed():
	_play_select_sound()
	if transitions:
		transitions.open_achievements()

func _on_shop_pressed():
	_play_select_sound()
	if transitions:
		transitions.open_shop()

func _on_profile_pressed(): 
	_play_select_sound()
	if transitions:
		transitions.open_profile()

func _on_settings_pressed():
	_play_select_sound()
	if transitions:
		transitions.open_settings()

func _on_exit_pressed():
	_stop_music()
	if transitions:
		transitions.exit_game()

func exit_to_main_menu():
	_play_menu_music()
	if transitions:
		transitions.exit_to_main_menu()
