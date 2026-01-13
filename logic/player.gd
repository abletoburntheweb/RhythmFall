# logic/player.gd
extends Node

signal note_hit(lane: int)
signal lane_pressed_changed

var lanes_state: Array[bool] = [false, false, false, false]
var keymap: Dictionary = {}

var _key_to_lane: Dictionary = {}

func _init(settings: Dictionary = {}):
	keymap = load_keymap_from_settings(settings)
	_key_to_lane = {}
	for key in keymap:
		_key_to_lane[keymap[key]] = key

func load_keymap_from_settings(settings: Dictionary) -> Dictionary:
	var default_keymap = {
		KEY_A: 0,
		KEY_S: 1,
		KEY_D: 2,
		KEY_F: 3,
	}
	
	if settings and "controls_keymap" in settings:
		var settings_keymap = settings["controls_keymap"]
		if settings_keymap:
			var loaded_keymap = {}
			for lane_str in settings_keymap:
				var lane = int(lane_str.replace("lane_", "").replace("_key", ""))
				var key_int = int(settings_keymap[lane_str]) 
				loaded_keymap[key_int] = lane
			
			if loaded_keymap.size() == 4 and _has_unique_values(loaded_keymap):
				print("[Player] Загружен маппинг клавиш: %s" % loaded_keymap)
				return loaded_keymap
			else:
				print("[Player] Невалидный маппинг клавиш в настройках: %s. Используем стандартный." % settings_keymap)
				return default_keymap
	
	print("[Player] Маппинг клавиш не найден в настройках. Используем стандартный.")
	return default_keymap

func _has_unique_values(keymap: Dictionary) -> bool:
	var values = []
	for key in keymap:
		var value = keymap[key]
		if value in values:
			return false
		values.append(value)
	return true

func set_keymap(new_keymap: Dictionary):
	keymap = new_keymap
	_key_to_lane = {}
	for key in keymap:
		_key_to_lane[keymap[key]] = key
	lanes_state = [false, false, false, false]

func handle_key_press(keycode: int):
	if keycode in keymap:
		var lane = keymap[keycode]
		if 0 <= lane and lane < lanes_state.size() and not lanes_state[lane]:
			lanes_state[lane] = true
			note_hit.emit(lane)
			lane_pressed_changed.emit()

func handle_key_release(keycode: int):
	if keycode in keymap:
		var lane = keymap[keycode]
		if 0 <= lane and lane < lanes_state.size():
			lanes_state[lane] = false
			lane_pressed_changed.emit()
			print("Player: Key released for lane %d" % lane)

func reset():
	lanes_state = [false, false, false, false]
	lane_pressed_changed.emit()
