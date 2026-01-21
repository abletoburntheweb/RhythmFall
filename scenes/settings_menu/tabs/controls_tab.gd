# scenes/settings_menu/tabs/controls_tab.gd
extends Control

signal settings_changed

var _remap_active: bool = false
var _remap_target_button: Button = null
var _remap_target_lane: int = -1
var _remap_old_scancode: int = 0

var game_screen = null

func _ready():
	print("ControlsTab.gd: _ready вызван.")

func setup_ui_and_manager(screen = null):
	game_screen = screen
	_setup_ui()

func _setup_ui():
	print("ControlsTab.gd: _setup_ui вызван.")

	var keys_container = $ContentVBox/KeysContainer
	if not keys_container:
		printerr("ControlsTab.gd: Не найден KeysContainer!")
		return

	for child in keys_container.get_children():
		child.queue_free()

	var num_lanes = SettingsManager.MAX_LANES if SettingsManager.has_method("MAX_LANES") else 5

	for i in range(num_lanes):
		var key_text = SettingsManager.get_key_text_for_lane(i)

		var row_hbox = _create_row_container()
		row_hbox.name = "Lane%dRow" % (i + 1)

		var line_label = _create_line_label(i + 1)
		var key_button = _create_key_button(key_text, i)

		var label_margin_container = _wrap_label_in_margin(line_label)
		row_hbox.add_child(label_margin_container)
		row_hbox.add_child(key_button)

		keys_container.add_child(row_hbox)

	print("ControlsTab.gd: UI управления создано для %d линий." % num_lanes)

	print("ControlsTab.gd: DEBUG: После _setup_ui, количество дочерних элементов в KeysContainer: ", keys_container.get_child_count())
	for i in range(keys_container.get_child_count()):
		var child = keys_container.get_child(i)
		print("ControlsTab.gd: DEBUG: Дочерний элемент ", i, ": ", child.name, " (", child.get_class(), ")")
		if child is HBoxContainer:
			print("ControlsTab.gd: DEBUG:   - HBoxContainer создан, имя: ", child.name)
			if child.get_child_count() >= 2:
				var label_container = child.get_child(0)
				if label_container and label_container.get_child_count() > 0:
					var label = label_container.get_child(0)
					print("ControlsTab.gd: DEBUG:   - Label: ", label.text)
				var button = child.get_child(1)
				if button and button is Button:
					print("ControlsTab.gd: DEBUG:   - Button: ", button.text, " (lane_index: ", button.get_meta("lane_index"), ")")

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
	key_button.size = Vector2(160, 55)
	key_button.flat = true
	key_button.set_meta("lane_index", lane_index)

	key_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
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
	key_button.add_theme_color_override("font_color_pressed", Color.BLACK) 
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
		_remap_target_button.text = SettingsManager.get_key_text_for_lane(_remap_target_lane)

	_remap_target_button = button
	_remap_target_lane = button.get_meta("lane_index")
	_remap_old_scancode = SettingsManager.get_key_scancode_for_lane(_remap_target_lane) 
	
	button.text = "..."  
	_remap_active = true

	print("ControlsTab.gd: Ожидание нажатия новой клавиши для линии %d (scancode %d)..." % [_remap_target_lane + 1, _remap_old_scancode])

func _input(event):
	if _remap_active and event is InputEventKey and event.pressed:
		var new_scancode = event.keycode
		var new_key_text = _get_key_string_from_scancode_for_display(new_scancode)

		if new_scancode == KEY_ESCAPE:
			_remap_target_button.text = SettingsManager.get_key_text_for_lane(_remap_target_lane)
			_remap_active = false
			_remap_target_button = null
			_remap_target_lane = -1
			_remap_old_scancode = 0
			print("ControlsTab.gd: Переназначение отменено по Escape.")
			get_viewport().set_input_as_handled()
			return

		var keys_container = $ContentVBox/KeysContainer
		if not keys_container:
			printerr("ControlsTab.gd: Не найден KeysContainer при обработке ввода!")
			_remap_active = false
			_remap_target_button = null
			_remap_target_lane = -1
			_remap_old_scancode = 0
			get_viewport().set_input_as_handled()
			return

		var duplicate_button: Button = null
		var duplicate_lane: int = -1
		for child in keys_container.get_children():
			if child is HBoxContainer:
				var btn = child.get_child(1)
				if btn is Button and btn != _remap_target_button:
					var btn_lane = btn.get_meta("lane_index")
					var btn_scancode = SettingsManager.get_key_scancode_for_lane(btn_lane)
					if btn_scancode == new_scancode:
						duplicate_button = btn
						duplicate_lane = btn_lane
						break 

		if duplicate_button:
			SettingsManager.set_key_scancode_for_lane(duplicate_lane, _remap_old_scancode)
			SettingsManager.set_key_scancode_for_lane(_remap_target_lane, new_scancode)

			duplicate_button.text = SettingsManager.get_key_text_for_lane(duplicate_lane)
			_remap_target_button.text = SettingsManager.get_key_text_for_lane(_remap_target_lane)

			print("ControlsTab.gd: Клавиши поменяны местами: '%s' (Lane %d) <-> '%s' (Lane %d)" % [
				_get_key_string_from_scancode_for_display(_remap_old_scancode), duplicate_lane + 1,
				_get_key_string_from_scancode_for_display(new_scancode), _remap_target_lane + 1
			])
		else:
			SettingsManager.set_key_scancode_for_lane(_remap_target_lane, new_scancode)
			_remap_target_button.text = SettingsManager.get_key_text_for_lane(_remap_target_lane)

			print("ControlsTab.gd: Назначена новая клавиша '%s' для линии %d (scancode %d)" % [new_key_text, _remap_target_lane + 1, new_scancode])

		emit_signal("settings_changed")
		if game_screen and game_screen.player:
			_update_player_keymap()

		_remap_active = false
		_remap_target_button = null
		_remap_target_lane = -1
		_remap_old_scancode = 0

		get_viewport().set_input_as_handled()

func _get_key_string_from_scancode_for_display(scancode: int) -> String:
	return SettingsManager._get_key_string_from_scancode(scancode)

func _update_player_keymap():
	if not game_screen or not game_screen.player:
		return

	var updated_keymap = {}
	var num_lanes = SettingsManager.MAX_LANES if SettingsManager.has_method("MAX_LANES") else 5
	for i in range(num_lanes):
		var scan_code = SettingsManager.get_key_scancode_for_lane(i)
		if scan_code != 0 and scan_code != KEY_X:
			updated_keymap[scan_code] = i
	game_screen.player.set_keymap(updated_keymap)
	print("ControlsTab.gd: Keymap Player обновлён: ", updated_keymap)

func refresh_ui():
	_setup_ui()
