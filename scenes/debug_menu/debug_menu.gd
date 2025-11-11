# scenes/debug_menu/debug_menu.gd
class_name DebugMenu
extends Control

var fps_label: Label = null
var score_label: Label = null
var combo_label: Label = null
var max_combo_label: Label = null
var combo_multiplier_label: Label = null
var bpm_label: Label = null
var notes_total_label: Label = null
var notes_current_label: Label = null
var song_time_label: Label = null
var auto_play_check_box: CheckButton = null
var plus_1000_button: Button = null
var minus_1000_button: Button = null
var win_button: Button = null

var is_auto_playing: bool = false

func _ready():
	fps_label = get_node_or_null("FPSLabel") as Label
	score_label = get_node_or_null("ScoreLabel") as Label
	combo_label = get_node_or_null("ComboLabel") as Label
	max_combo_label = get_node_or_null("MaxComboLabel") as Label
	combo_multiplier_label = get_node_or_null("ComboMultiplierLabel") as Label
	bpm_label = get_node_or_null("BPMLabel") as Label
	notes_total_label = get_node_or_null("NotesTotalLabel") as Label
	notes_current_label = get_node_or_null("NotesCurrentLabel") as Label
	song_time_label = get_node_or_null("SongTimeLabel") as Label
	auto_play_check_box = get_node_or_null("AutoPlayCheckBox") as CheckButton
	plus_1000_button = get_node_or_null("Plus1000Button") as Button
	minus_1000_button = get_node_or_null("Minus1000Button") as Button
	win_button = get_node_or_null("WinButton") as Button
	
	var missing_nodes = []
	for property_name in ["fps_label", "score_label", "combo_label", "max_combo_label", "combo_multiplier_label", "bpm_label", "notes_total_label", "notes_current_label", "song_time_label", "auto_play_check_box", "plus_1000_button", "minus_1000_button", "win_button"]:
		if not get(property_name):
			missing_nodes.append(property_name)
	
	if missing_nodes:
		printerr("DebugMenu.gd: Не найдены узлы: ", missing_nodes)

	if plus_1000_button:
		plus_1000_button.pressed.connect(_on_plus_1000_button_pressed)
	if minus_1000_button:
		minus_1000_button.pressed.connect(_on_minus_1000_button_pressed)
	if win_button:
		win_button.pressed.connect(_on_win_button_pressed)
	if auto_play_check_box:
		auto_play_check_box.toggled.connect(_on_auto_play_check_box_toggled)

	hide()

func toggle_visibility():
	visible = not visible
	if visible:
		grab_focus()

func update_debug_info(game_screen):
	if fps_label:
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

	if game_screen and game_screen.score_manager:
		if score_label:
			score_label.text = "Счёт: %d" % game_screen.score_manager.get_score()
		if combo_label:
			combo_label.text = "Комбо: %d" % game_screen.score_manager.get_combo()
		if max_combo_label:
			max_combo_label.text = "Макс. комбо: %d" % game_screen.score_manager.get_max_combo()
		if combo_multiplier_label:
			combo_multiplier_label.text = "Множитель комбо: x%.1f" % game_screen.score_manager.get_combo_multiplier()

	if game_screen and game_screen.note_manager:
		if notes_current_label:
			notes_current_label.text = "Активные ноты: %d" % game_screen.note_manager.get_notes().size()
		if notes_total_label:
			notes_total_label.text = "Всего нот: %d" % game_screen.note_manager.get_spawn_queue_size()

	if game_screen and bpm_label:
		bpm_label.text = "BPM: %.1f" % game_screen.bpm

	if game_screen and song_time_label:
		song_time_label.text = "Время песни: %.1fс" % game_screen.game_time

func _on_plus_1000_button_pressed():
	if get_parent() and get_parent().has_method("score_manager"):
		var parent_score_manager = get_parent().score_manager
		if parent_score_manager:
			parent_score_manager.score += 1000
			print("DebugMenu: Добавлено 1000 очков.")

func _on_minus_1000_button_pressed():
	if get_parent() and get_parent().has_method("score_manager"):
		var parent_score_manager = get_parent().score_manager
		if parent_score_manager:
			parent_score_manager.score = max(0, parent_score_manager.score - 1000)
			print("DebugMenu: Вычтено 1000 очков.")

func _on_win_button_pressed():
	if get_parent() and get_parent().has_method("end_game"):
		get_parent().end_game()
		print("DebugMenu: Игра завершена через DebugMenu.")

func _on_auto_play_check_box_toggled(button_pressed: bool):
	is_auto_playing = button_pressed
	print("DebugMenu: Автопрохождение ", "ВКЛ" if is_auto_playing else "ВЫКЛ")

func is_auto_play_enabled() -> bool:
	return is_auto_playing
