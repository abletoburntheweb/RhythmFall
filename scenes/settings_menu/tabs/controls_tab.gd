# scenes/settings_menu/tabs/controls_tab.gd
extends Control

signal settings_changed

var _remap_active: bool = false
var _remap_target_button: Button = null
var _remap_target_lane: int = -1
var _remap_old_scancode: int = 0

var game_screen = null

@onready var reset_button: Button = $ContentVBox/ResetControlsButton

func _ready():
	if reset_button and not reset_button.has_meta("initialized"):
		reset_button.pressed.connect(_on_reset_controls_pressed)
		reset_button.set_meta("initialized", true)

func setup_ui_and_manager(screen = null):
	game_screen = screen
	_setup_ui()

func _setup_ui():
	
	var keys_container = $ContentVBox/KeysContainer
	if not keys_container:
		printerr("ControlsTab.gd: Не найден KeysContainer!")
		return

	var num_lanes = SettingsManager.MAX_LANES if SettingsManager.has_method("MAX_LANES") else 5
	for i in range(num_lanes):
		var row_name = "Lane%dRow" % (i + 1)
		var row_hbox = keys_container.get_node_or_null(row_name)
		if not row_hbox and i < keys_container.get_child_count():
			row_hbox = keys_container.get_child(i)
		if row_hbox and row_hbox is HBoxContainer:
			var label_container = null
			if row_hbox.get_child_count() > 0:
				label_container = row_hbox.get_child(0)
			var label_node = null
			if label_container and label_container is MarginContainer and label_container.get_child_count() > 0:
				label_node = label_container.get_child(0)
			elif label_container and label_container is Label:
				label_node = label_container
			if label_node and label_node is Label:
				label_node.text = "Линия %d" % (i + 1)
			var button_node = null
			if row_hbox.get_child_count() > 1:
				button_node = row_hbox.get_child(1)
			if button_node and button_node is Button:
				button_node.text = SettingsManager.get_key_text_for_lane(i)
				button_node.set_meta("lane_index", i)
				if not button_node.has_meta("initialized"):
					button_node.pressed.connect(_on_key_button_pressed.bind(button_node))
					button_node.set_meta("initialized", true)

	

func _on_key_button_pressed(button: Button):
	if _remap_active and _remap_target_button:
		_remap_target_button.text = SettingsManager.get_key_text_for_lane(_remap_target_lane)

	_remap_target_button = button
	_remap_target_lane = button.get_meta("lane_index")
	_remap_old_scancode = SettingsManager.get_key_scancode_for_lane(_remap_target_lane) 
	
	button.text = "..."  
	_remap_active = true
	
func _is_service_key(scancode: int) -> bool:
	return scancode == KEY_SHIFT \
		or scancode == KEY_ALT \
		or scancode == KEY_CTRL \
		or scancode == KEY_META \
		or scancode == KEY_CAPSLOCK \
		or scancode == KEY_NUMLOCK \
		or scancode == KEY_SCROLLLOCK

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
			get_viewport().set_input_as_handled()
			return
		
		if _is_service_key(new_scancode):
			printerr("ControlsTab.gd: Назначение на служебную клавишу запрещено.")
			_remap_target_button.text = SettingsManager.get_key_text_for_lane(_remap_target_lane)
			_remap_active = false
			_remap_target_button = null
			_remap_target_lane = -1
			_remap_old_scancode = 0
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
			
		else:
			SettingsManager.set_key_scancode_for_lane(_remap_target_lane, new_scancode)
			_remap_target_button.text = SettingsManager.get_key_text_for_lane(_remap_target_lane)
			

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

func _on_reset_controls_pressed():
	for i in range(5):
		var defaults = [KEY_A, KEY_S, KEY_D, KEY_F, KEY_G]
		SettingsManager.set_key_scancode_for_lane(i, defaults[i])
	emit_signal("settings_changed")
	_update_player_keymap()
	refresh_ui()

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

func refresh_ui():
	_setup_ui()
