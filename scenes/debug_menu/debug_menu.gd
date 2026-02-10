# scenes/debug_menu/debug_menu.gd
class_name DebugMenu
extends Control

var fps_label: Label = null
var score_label: Label = null
var combo_label: Label = null
var max_combo_label: Label = null
var combo_multiplier_label: Label = null
var bpm_label: Label = null
var accuracy_label: Label = null  
var notes_total_label: Label = null
var notes_current_label: Label = null
var song_time_label: Label = null
var auto_play_check_box: CheckButton = null
var plus_1000_button: Button = null
var minus_1000_button: Button = null
var plus_10_combo_button: Button = null
var accuracy_edit: LineEdit = null 
var win_button: Button = null
 
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
	plus_10_combo_button = get_node_or_null("Plus10ComboButton") as Button 
	accuracy_edit = get_node_or_null("AccuracyEdit") as LineEdit
	accuracy_label = get_node_or_null("AccuracyLabel") as Label   
	
	var missing_nodes = []
	for property_name in ["fps_label", "score_label", "combo_label", "max_combo_label", "combo_multiplier_label", "bpm_label", "notes_total_label", "notes_current_label", "song_time_label", "auto_play_check_box", "plus_1000_button", "minus_1000_button", "win_button", "plus_10_combo_button", "accuracy_edit", "accuracy_label"]:
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
	if plus_10_combo_button:
		plus_10_combo_button.pressed.connect(_on_plus_10_combo_button_pressed)
	if auto_play_check_box:
		auto_play_check_box.toggled.connect(_on_auto_play_check_box_toggled)
	if accuracy_edit:
		accuracy_edit.placeholder_text = "0-100"
		accuracy_edit.text_submitted.connect(_on_accuracy_text_submitted)
	if accuracy_label:
		accuracy_label.text = "Точность:"

	hide()

func _input(event):
	if not visible:
		return

	if accuracy_edit and accuracy_edit.has_focus():
		return
	
	if event is InputEventKey and event.pressed:
		var viewport = get_viewport()
		var handled = false
		
		match event.keycode:
			KEY_1:
				_on_plus_1000_button_pressed()
				handled = true
			KEY_2:
				_on_minus_1000_button_pressed()
				handled = true
			KEY_3:
				_on_plus_10_combo_button_pressed()
				handled = true
			KEY_4:
				if auto_play_check_box:
					auto_play_check_box.button_pressed = not auto_play_check_box.button_pressed
					_on_auto_play_check_box_toggled(auto_play_check_box.button_pressed)
				handled = true
			KEY_5:
				if accuracy_edit:
					accuracy_edit.grab_focus()
					print("DebugMenu: Ввод точности - введите значение 0-100 и нажмите Enter")
				handled = true
			KEY_6:
				_on_win_button_pressed()
				handled = true
		
		if handled and viewport:
			viewport.set_input_as_handled()

func toggle_visibility():
	visible = not visible
	if visible:
		grab_focus()

func update_debug_info(game_screen):
	if fps_label:
		fps_label.text = "FPS %d" % Engine.get_frames_per_second()

	if game_screen and game_screen.score_manager:
		if score_label:
			score_label.text = "Счёт: %d" % game_screen.score_manager.get_score()
		if combo_label:
			combo_label.text = "Комбо: %d" % game_screen.score_manager.get_combo()
		if max_combo_label:
			max_combo_label.text = "Макс. комбо: %d" % game_screen.score_manager.get_max_combo()
		if combo_multiplier_label:
			combo_multiplier_label.text = "Множитель комбо: x%.1f" % game_screen.score_manager.get_combo_multiplier()
		if accuracy_label:
			accuracy_label.text = "Точность: %.1f%%" % game_screen.score_manager.get_accuracy()

	if game_screen and game_screen.note_manager:
		if notes_current_label:
			notes_current_label.text = "Активные ноты: %d" % game_screen.note_manager.get_notes().size()
		if notes_total_label:
			notes_total_label.text = "Всего нот: %d" % game_screen.note_manager.get_spawn_queue_size()

	if game_screen and bpm_label:
		bpm_label.text = "BPM: %.1f" % game_screen.bpm

	if game_screen and song_time_label:
		song_time_label.text = "Время песни: %.1fс" % game_screen.game_time

func _on_accuracy_text_submitted(new_text: String):
	if new_text.is_valid_float():
		var accuracy_value = new_text.to_float()
		accuracy_value = clampf(accuracy_value, 0.0, 100.0)
		
		var game_screen = get_parent()
		if game_screen and game_screen.score_manager:
			var total_notes = game_screen.score_manager.total_notes
			if total_notes <= 0 and game_screen.note_manager:
				total_notes = game_screen.note_manager.get_spawn_queue_size()
			if total_notes <= 0:
				total_notes = 1
			var missed_notes = int(round(total_notes * (100.0 - accuracy_value) / 100.0))
			missed_notes = clamp(missed_notes, 0, total_notes)
			var hit_notes = total_notes - missed_notes
			game_screen.score_manager.total_notes = total_notes
			game_screen.score_manager.missed_notes = missed_notes
			game_screen.score_manager.hit_notes = hit_notes
			game_screen.score_manager.update_accuracy()
			if game_screen.has_method("update_ui"):
				game_screen.update_ui()
			
			accuracy_edit.text = ""
			accuracy_edit.release_focus()
		else:
			printerr("DebugMenu: Не удалось получить доступ к score_manager")
	else:
		print("DebugMenu: Введено некорректное значение точности: ", new_text)
		accuracy_edit.text = ""

func _on_plus_1000_button_pressed():
	var game_screen = get_parent()
	if game_screen and game_screen.score_manager:
		var current_combo = game_screen.score_manager.combo
		var multiplier = min(4.0, 1.0 + float(int(current_combo / 10)))
		var actual_points = int(1000 * multiplier)
		
		game_screen.score_manager.score += actual_points
		print("DebugMenu: Добавлено %d очков (с множителем x%.1f). Новый счёт: %d" % [actual_points, multiplier, game_screen.score_manager.get_score()])
		if game_screen.has_method("update_ui"):
			game_screen.update_ui()
	else:
		if not game_screen:
			printerr("DebugMenu: get_parent() вернул null!")
		elif not game_screen.score_manager:
			printerr("DebugMenu: score_manager родителя равен null! (Возможно, GameScreen ещё не инициализировал его или произошла ошибка.)")
		else:
			printerr("DebugMenu: Неизвестная ошибка при доступе к score_manager.")

func _on_minus_1000_button_pressed():
	var game_screen = get_parent()
	if game_screen and game_screen.score_manager:
		game_screen.score_manager.score = max(0, game_screen.score_manager.score - 1000) 
		print("DebugMenu: Вычтено 1000 очков. Новый счёт: %d" % game_screen.score_manager.get_score())
		if game_screen.has_method("update_ui"):
			game_screen.update_ui()
	else:
		if not game_screen:
			printerr("DebugMenu: get_parent() вернул null!")
		elif not game_screen.score_manager:
			printerr("DebugMenu: score_manager родителя равен null! (Возможно, GameScreen ещё не инициализировал его или произошла ошибка.)")
		else:
			printerr("DebugMenu: Неизвестная ошибка при доступе к score_manager.")

func _on_plus_10_combo_button_pressed():
	var game_screen = get_parent()
	if game_screen and game_screen.score_manager:
		var current_combo = game_screen.score_manager.combo
		var new_combo = current_combo + 10

		game_screen.score_manager.combo = new_combo
		if new_combo > game_screen.score_manager.max_combo:
			game_screen.score_manager.max_combo = new_combo
		
		game_screen.score_manager.combo_multiplier = min(4, 1 + (int(new_combo / 10)))
			
		print("DebugMenu: Добавлено 10 к комбо. Новое комбо: %d, Макс. комбо: %d, Множитель: x%.1f" % [game_screen.score_manager.combo, game_screen.score_manager.max_combo, game_screen.score_manager.combo_multiplier])
		if game_screen.has_method("update_ui"):
			game_screen.update_ui()
	else:
		if not game_screen:
			printerr("DebugMenu: get_parent() вернул null!")
		elif not game_screen.score_manager:
			printerr("DebugMenu: score_manager родителя равен null! (Возможно, GameScreen ещё не инициализировал его или произошла ошибка.)")
		else:
			printerr("DebugMenu: Неизвестная ошибка при доступе к score_manager.")

func _on_win_button_pressed():
	var game_screen = get_parent()
	if not game_screen or not game_screen.score_manager or not game_screen.note_manager:
		printerr("DebugMenu: Не удалось получить доступ к GameScreen или его компонентам.")
		return
	
	var target_accuracy = game_screen.score_manager.get_accuracy()
	var override_with_input = false
	if accuracy_edit and accuracy_edit.text.is_valid_float():
		target_accuracy = clampf(accuracy_edit.text.to_float(), 0.0, 100.0)
		override_with_input = true

	var total_notes = game_screen.score_manager.total_notes
	if total_notes <= 0:
		total_notes = game_screen.note_manager.get_spawn_queue_size()
	if total_notes <= 0:
		total_notes = 1
	
	if override_with_input:
		var missed_notes = int(round(total_notes * (100.0 - target_accuracy) / 100.0))
		missed_notes = clamp(missed_notes, 0, total_notes)
		var hit_notes = total_notes - missed_notes
		game_screen.score_manager.total_notes = total_notes
		game_screen.score_manager.missed_notes = missed_notes
		game_screen.score_manager.hit_notes = hit_notes
		game_screen.score_manager.update_accuracy()

	var hits_for_combo = game_screen.score_manager.get_hit_notes_count()
	if target_accuracy >= 100.0 and hits_for_combo > 0:
		game_screen.score_manager.combo = hits_for_combo

	var base_score_per_hit = 100
	var multiplier = 1.0
	if target_accuracy >= 100.0:
		multiplier = min(4.0, 1.0 + (total_notes / 10.0)) 
	elif target_accuracy >= 95.0:
		multiplier = 2.0
	elif target_accuracy >= 90.0:
		multiplier = 1.5
	
	var current_score = game_screen.score_manager.get_score()
	var recompute = override_with_input or current_score <= 0
	if recompute:
		var hits_for_score = max(1, game_screen.score_manager.get_hit_notes_count())
		game_screen.score_manager.score = int(hits_for_score * base_score_per_hit * multiplier)

	if game_screen.has_method("update_ui"):
		game_screen.update_ui()

	game_screen.note_manager.clear_notes()

	if game_screen.has_method("end_game"):
		game_screen.end_game()
		print("DebugMenu: Игра завершена с точностью %.1f%% (%d/%d нот)" % [game_screen.score_manager.get_accuracy(), game_screen.score_manager.get_hit_notes_count(), game_screen.score_manager.total_notes])
	else:
		printerr("DebugMenu: Метод end_game не найден у GameScreen")

func _on_auto_play_check_box_toggled(button_pressed: bool):
	print("DebugMenu: Автопрохождение ", "ВКЛ" if button_pressed else "ВЫКЛ")

func is_auto_play_enabled() -> bool:
	if auto_play_check_box:
		return auto_play_check_box.button_pressed
	else:
		return false
