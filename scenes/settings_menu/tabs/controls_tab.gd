# scenes/settings_menu/tabs/controls_tab.gd
extends Control

signal settings_changed # Для уведомления SettingsMenu о необходимости сохранить настройки

var _remap_active: bool = false
var _remap_target_button: Button = null
var _remap_target_lane: int = -1
var _remap_old_text: String = ""

var settings_manager: SettingsManager = null # Передаётся из SettingsMenu
var game_screen = null # Передаётся из SettingsMenu




func _ready():
	print("ControlsTab.gd: _ready вызван.")


func setup_ui_and_manager(manager: SettingsManager, screen = null):
	settings_manager = manager
	game_screen = screen
	_setup_ui()


func _setup_ui():
	if not settings_manager:
		printerr("ControlsTab.gd: settings_manager не установлен, невозможно настроить UI.")
		return

	print("ControlsTab.gd: _setup_ui вызван.")

	var keys_container = $ContentVBox/KeysContainer # Используем путь из вашей сцены
	if not keys_container:
		printerr("ControlsTab.gd: Не найден KeysContainer по пути $ContentVBox/KeysContainer!")
		return

	for child in keys_container.get_children():
		child.queue_free()

	var current_keys_text = []
	if settings_manager.has_method("get_controls_key_texts"):
		current_keys_text = settings_manager.get_controls_key_texts()
		print("ControlsTab.gd: Клавиши загружены через get_controls_key_texts.")
	else:
		print("ControlsTab.gd: Метод get_controls_key_texts не найден, используем get_key_text_for_lane.")
		for i in range(4): # Предполагаем 4 линии
			var key_text = settings_manager.get_key_text_for_lane(i)
			current_keys_text.append(key_text)

	for i in range(current_keys_text.size()):
		var lane_index = i
		var key_text = current_keys_text[i]

		var row_hbox = _create_row_container()
		row_hbox.name = "Lane%dRow" % (lane_index + 1)

		var line_label = _create_line_label(lane_index + 1)

		var key_button = _create_key_button(key_text, lane_index)

		var label_margin_container = _wrap_label_in_margin(line_label)
		row_hbox.add_child(label_margin_container)
		row_hbox.add_child(key_button)

		keys_container.add_child(row_hbox)

	print("ControlsTab.gd: UI управления создано.")

	print("ControlsTab.gd: DEBUG: После _setup_ui, количество дочерних элементов в KeysContainer: ", keys_container.get_child_count())
	for i in range(keys_container.get_child_count()):
		var child = keys_container.get_child(i)
		print("ControlsTab.gd: DEBUG: Дочерний элемент ", i, ": ", child.name, " (", child.get_class(), ")")
		if child is HBoxContainer:
			print("ControlsTab.gd: DEBUG:   - HBoxContainer создан, имя: ", child.name)
			if child.get_child_count() >= 3: # Проверим Label и Button
				var label_container = child.get_child(0)
				if label_container and label_container.get_child_count() > 0:
					var label = label_container.get_child(0)
					print("ControlsTab.gd: DEBUG:   - Label: ", label.text)
				var button = child.get_child(2) # Button на индексе 2
				if button and button is Button:
					print("ControlsTab.gd: DEBUG:   - Button: ", button.text)


func _create_row_container() -> HBoxContainer:
	var row_hbox = HBoxContainer.new()
	row_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_hbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(1.0, 1.0, 1.0, 0.05)
	bg_style.set("corner_radius_top_left", 10.0)
	bg_style.set("corner_radius_top_right", 10.0)
	bg_style.set("corner_radius_bottom_left", 10.0)
	bg_style.set("corner_radius_bottom_right", 10.0)
	row_hbox.add_theme_stylebox_override("panel", bg_style)

	row_hbox.add_theme_constant_override("separation", 20)
	row_hbox.add_theme_constant_override("margin_left", 10)
	row_hbox.add_theme_constant_override("margin_right", 10)
	row_hbox.add_theme_constant_override("margin_top", 5)
	row_hbox.add_theme_constant_override("margin_bottom", 5)

	return row_hbox


func _create_line_label(lane_number: int) -> Label:
	var line_label = Label.new()
	line_label.text = "Линия %d" % lane_number
	line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	line_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line_label.add_theme_color_override("font_color", Color.WHITE)
	line_label.add_theme_font_size_override("font_size", 22)
	line_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return line_label


func _create_key_button(key_text: String, lane_index: int) -> Button:
	var key_button = Button.new()
	key_button.text = key_text
	key_button.size = Vector2(160, 55) # Фиксированный размер
	key_button.flat = true # Без стандартного фона
	key_button.set_meta("lane_index", lane_index)

	key_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	key_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var button_style_normal = _create_button_style()
	button_style_normal.bg_color = Color(1.0, 1.0, 1.0, 0.1)
	button_style_normal.border_color = Color(1.0, 1.0, 1.0, 0.25)

	var button_style_hover = button_style_normal.duplicate()
	button_style_hover.bg_color = Color(1.0, 1.0, 1.0, 0.2)
	button_style_hover.border_color = Color.WHITE

	var button_style_pressed = button_style_normal.duplicate()
	button_style_pressed.bg_color = Color(1.0, 1.0, 1.0, 0.35)

	key_button.add_theme_stylebox_override("normal", button_style_normal)
	key_button.add_theme_stylebox_override("hover", button_style_hover)
	key_button.add_theme_stylebox_override("pressed", button_style_pressed)

	key_button.add_theme_color_override("font_color", Color.WHITE)
	key_button.add_theme_color_override("font_color_pressed", Color.BLACK) # Цвет текста при нажатии
	key_button.add_theme_font_size_override("font_size", 22)

	key_button.pressed.connect(_on_key_button_pressed.bind(key_button))

	return key_button


func _create_button_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.set("border_width_left", 2)
	style.set("border_width_right", 2)
	style.set("border_width_top", 2)
	style.set("border_width_bottom", 2)
	style.set("corner_radius_top_left", 10.0)
	style.set("corner_radius_top_right", 10.0)
	style.set("corner_radius_bottom_left", 10.0)
	style.set("corner_radius_bottom_right", 10.0)
	style.set("content_margin_left", 10)
	style.set("content_margin_right", 10)
	style.set("content_margin_top", 10)
	style.set("content_margin_bottom", 10)
	return style


func _wrap_label_in_margin(label: Label) -> MarginContainer:
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 10)
	margin_container.add_theme_constant_override("margin_right", 10)
	margin_container.add_theme_constant_override("margin_top", 5)
	margin_container.add_theme_constant_override("margin_bottom", 5)
	margin_container.add_child(label)
	return margin_container


func _on_key_button_pressed(button: Button):
	if _remap_active and _remap_target_button:
		var lane_key = "lane_%d_key" % _remap_target_lane
		var old_text = settings_manager.get_controls_keymap().get(lane_key, "X")
		_remap_target_button.text = old_text

	_remap_target_button = button
	_remap_target_lane = button.get_meta("lane_index")
	_remap_old_text = button.text
	_remap_active = true
	button.text = "..."
	print("ControlsTab.gd: Ожидание нажатия новой клавиши для линии %d..." % (_remap_target_lane + 1))


func _input(event):
	if _remap_active and event is InputEventKey and event.pressed:
		var new_key_text = char(event.key_label)
		if new_key_text.length() == 1 and new_key_text.is_valid_identifier():
			print("ControlsTab.gd: Нажата новая клавиша: %s (Label: %d)" % [new_key_text, event.key_label])

			var keys_container = $ContentVBox/KeysContainer
			if not keys_container:
				printerr("ControlsTab.gd: Не найден KeysContainer при обработке ввода!")
				return

			var duplicate_button: Button = null
			var duplicate_lane: int = -1
			for child in keys_container.get_children():
				if child is HBoxContainer:
					var btn = child.get_child(2) # Кнопка на индексе 2
					if btn is Button and btn != _remap_target_button and btn.text == new_key_text:
						duplicate_button = btn
						duplicate_lane = btn.get_meta("lane_index")
						break

			if duplicate_button:
				var old_key_text = _remap_old_text
				duplicate_button.text = old_key_text
				_remap_target_button.text = new_key_text
				settings_manager.set_key_text_for_lane(duplicate_lane, old_key_text)
				settings_manager.set_key_text_for_lane(_remap_target_lane, new_key_text)
				print("ControlsTab.gd: Клавиши поменяны местами: '%s' <-> '%s'" % [old_key_text, new_key_text])
			else:
				_remap_target_button.text = new_key_text
				settings_manager.set_key_text_for_lane(_remap_target_lane, new_key_text)

			emit_signal("settings_changed")
			if game_screen and game_screen.player:
				_update_player_keymap()

			_remap_active = false
			_remap_target_button = null
			_remap_target_lane = -1
			_remap_old_text = ""
		else:
			print("ControlsTab.gd: Игнорируем нажатие: не буквенный символ или специальная клавиша (Label: %d)" % event.key_label)


func _update_player_keymap():
	if not game_screen or not game_screen.player or not settings_manager:
		return

	var updated_keymap = {}
	for i in range(4):
		var scan_code = settings_manager.get_key_scancode_for_lane(i)
		if scan_code != 0:
			updated_keymap[scan_code] = i
	game_screen.player.set_keymap(updated_keymap)
	print("ControlsTab.gd: Keymap Player обновлён: ", updated_keymap)


func _unhandled_key_input(event):
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		if _remap_active:
			print("ControlsTab.gd: Переназначение отменено по Escape.")
			var restored_text = settings_manager.get_key_text_for_lane(_remap_target_lane) if settings_manager else "X"
			if _remap_target_button:
				_remap_target_button.text = restored_text
			_remap_active = false
			_remap_target_button = null
			_remap_target_lane = -1
			_remap_old_text = ""


func refresh_ui():
	_setup_ui()
