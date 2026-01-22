# logic/player.gd
extends Node

signal note_hit(lane: int)
signal lane_pressed_changed

var lanes_state: Array[bool] = []
var keymap: Dictionary = {}
var _key_to_lane: Dictionary = {}
var num_active_lanes: int = 5 

const MAX_LANES = 5  

func _init(settings: Dictionary = {}, num_lanes: int = MAX_LANES):
	keymap = load_keymap_from_settings(settings)
	_key_to_lane = {}
	for key in keymap:
		_key_to_lane[keymap[key]] = key
	
	set_num_lanes(num_lanes)

func load_keymap_from_settings(settings: Dictionary) -> Dictionary:
	var default_keymap = {
		KEY_A: 0,
		KEY_S: 1,
		KEY_D: 2,
		KEY_F: 3,
		KEY_G: 4, 
	}
	
	if settings and "controls_keymap" in settings:
		var settings_keymap = settings["controls_keymap"]
		if settings_keymap:
			var loaded_keymap = {}
			for lane_str in settings_keymap:
				var lane = int(lane_str.replace("lane_", "").replace("_key", ""))
				var key_int = int(settings_keymap[lane_str]) 
				loaded_keymap[key_int] = lane
			
			var valid = true
			for lane in loaded_keymap.values():
				if lane < 0 or lane >= MAX_LANES:
					valid = false
					break
			
			if valid and _has_unique_values(loaded_keymap):
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
	set_num_lanes(num_active_lanes)
	lane_pressed_changed.emit()

func set_num_lanes(new_num_lanes: int):
	num_active_lanes = clamp(new_num_lanes, 3, MAX_LANES)
	lanes_state.resize(num_active_lanes)
	for i in range(num_active_lanes):
		lanes_state[i] = false
	lane_pressed_changed.emit()

func handle_key_press(keycode: int):
	if keycode in keymap:
		var lane = keymap[keycode]
		if lane >= num_active_lanes:
			return
		if not lanes_state[lane]:
			lanes_state[lane] = true
			note_hit.emit(lane)
			lane_pressed_changed.emit()

func handle_key_release(keycode: int):
	if keycode in keymap:
		var lane = keymap[keycode]
		if lane >= num_active_lanes:
			return
		if lanes_state[lane]:
			lanes_state[lane] = false
			lane_pressed_changed.emit()
			print("Player: Key released for lane %d" % lane)

func reset():
	for i in range(lanes_state.size()):
		lanes_state[i] = false
	lane_pressed_changed.emit()
