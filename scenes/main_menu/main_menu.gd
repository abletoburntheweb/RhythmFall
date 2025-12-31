extends Control

var transitions = null
var music_manager = null

var is_game_open = false

@onready var level_label: Label = $XPContainer/LevelLabel
@onready var xp_progress_bar: ProgressBar = $XPContainer/XPProgressBar
@onready var xp_amount_label: Label = $XPContainer/XPAmountLabel

var player_data_manager: PlayerDataManager = null

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

	if not level_label:
		print("❌ LevelLabel не найден!")
	if not xp_progress_bar:
		print("❌ XPProgressBar не найден!")
	if not xp_amount_label:
		print("❌ XPAmountLabel не найден!")

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

	if game_engine and game_engine.has_method("get_player_data_manager"):
		player_data_manager = game_engine.get_player_data_manager()
		if player_data_manager:
			print("✅ PlayerDataManager получен из GameEngine")
			if player_data_manager.has_signal("level_changed"):
				player_data_manager.level_changed.connect(_on_level_changed)
			_update_xp_ui()
		else:
			printerr("MainMenu: Не удалось получить PlayerDataManager")
	else:
		printerr("MainMenu: Не удалось получить GameEngine или метод get_player_data_manager()")

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

func _on_level_changed(new_level: int, new_xp: int, xp_for_next_level: int):
	print("🔧 Уровень обновлён через сигнал: %d, XP: %d, до следующего: %d" % [new_level, new_xp, xp_for_next_level])
	level_label.text = "Уровень %d" % new_level
	xp_progress_bar.max_value = xp_for_next_level
	xp_progress_bar.value = new_xp
	xp_amount_label.text = "%d / %d" % [new_xp, xp_for_next_level]

func _update_xp_ui():
	print("🔧 _update_xp_ui вызван")
	if player_data_manager:
		var level = player_data_manager.get_current_level()
		var total_xp = player_data_manager.get_total_xp()
		var xp_for_next = player_data_manager.get_xp_for_next_level()
		var progress_text = player_data_manager.get_xp_progress_text()

		print("🔧 Уровень: %d, XP: %d, XP до следующего: %d, Прогресс: %s" % [level, total_xp, xp_for_next, progress_text])

		level_label.text = "Уровень %d" % level
		xp_progress_bar.max_value = xp_for_next
		xp_progress_bar.value = total_xp
		xp_amount_label.text = progress_text

		print("✅ UI обновлён: ", level_label.text, ", ", xp_amount_label.text)
	else:
		print("❌ PlayerDataManager не установлен")

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
