# scenes/settings_menu/tabs/controls_tab.gd
extends Control

signal settings_changed

var _remap_active: bool = false
var _remap_target_button: Button = null
var _remap_target_lane: int = -1
var _remap_old_scancode: int = 0

var game_screen = null
@onready var keys_container: VBoxContainer = $ContentVBox/KeysContainer
@onready var lane_buttons := [
	$ContentVBox/KeysContainer/Lane1Row/KeyButton,
	$ContentVBox/KeysContainer/Lane2Row/KeyButton,
	$ContentVBox/KeysContainer/Lane3Row/KeyButton,
	$ContentVBox/KeysContainer/Lane4Row/KeyButton,
	$ContentVBox/KeysContainer/Lane5Row/KeyButton
]
 

func setup_ui_and_manager(screen = null):
	game_screen = screen
	_setup_ui()

func _setup_ui():
	var num_lanes = SettingsManager.MAX_LANES if SettingsManager.has_method("MAX_LANES") else 5
	for i in range(num_lanes):
		if i < lane_buttons.size() and lane_buttons[i]:
			lane_buttons[i].text = SettingsManager.get_key_text_for_lane(i)

	

func _on_key_button_pressed(lane_index: int):
	if _remap_active and _remap_target_button:
		_remap_target_button.text = SettingsManager.get_key_text_for_lane(_remap_target_lane)
	_remap_target_lane = lane_index
	_remap_target_button = lane_buttons[lane_index] if lane_index >= 0 and lane_index < lane_buttons.size() else null
	_remap_old_scancode = SettingsManager.get_key_scancode_for_lane(_remap_target_lane) 
	
	if _remap_target_button:
		_remap_target_button.text = "..."
	_remap_active = true
	
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
		
		if event.alt_pressed and event.ctrl_pressed:
			get_viewport().set_input_as_handled()
			return
		
		if SettingsManager.is_service_key(new_scancode):
			get_viewport().set_input_as_handled()
			return

		var duplicate_button: Button = null
		var duplicate_lane: int = -1
		for i in range(lane_buttons.size()):
			var btn: Button = lane_buttons[i]
			if btn and btn != _remap_target_button:
				var btn_scancode = SettingsManager.get_key_scancode_for_lane(i)
				if btn_scancode == new_scancode:
					duplicate_button = btn
					duplicate_lane = i
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
