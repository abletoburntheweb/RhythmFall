# logic/settings_manager.gd
extends Node

const SETTINGS_PATH = "user://settings.json"
const MAX_LANES = 5
var default_settings = {
	"music_volume": 30.0,
	"menu_music_volume": 30.0,
	"effects_volume": 30.0,
	"hit_sounds_volume": 30.0,
	"metronome_volume": 30.0, 
	"preview_volume": 30.0,
	"timing_offset_ms": 0,
	"fps_mode": 0, 
	"fullscreen": false,
	"enable_debug_menu": false,
	"enable_genre_detection": true,
	"user_songs_path": "",
	"lane_highlight_enabled": true,
	"controls_keymap": {
		"lane_0_key": KEY_A,
		"lane_1_key": KEY_S,
		"lane_2_key": KEY_D,
		"lane_3_key": KEY_F,
		"lane_4_key": KEY_G
	},
	"last_generation_instrument": "drums",
	"last_generation_mode": "basic",
	"last_generation_lanes": 4,
	"use_stems_in_generation": true,
	"scroll_speed": 6.0
}

var settings: Dictionary = default_settings.duplicate(true)


func _init():
	_load_settings()


func _load_settings():
	var json_result: Dictionary = JsonUtils.read_json_dict(SETTINGS_PATH)
	if not json_result.is_empty():
		var loaded_settings = _merge_defaults_with_loaded(default_settings, json_result)
		var controls_loaded = loaded_settings.get("controls_keymap", {})
		var controls_updated = false
		for i in range(MAX_LANES):
			var lane_key = "lane_%d_key" % i
			if not controls_loaded.has(lane_key):
				controls_loaded[lane_key] = default_settings["controls_keymap"][lane_key]
				controls_updated = true
			else:
				var value = controls_loaded.get(lane_key)
				if value is float:
					controls_loaded[lane_key] = int(value)
					controls_updated = true
				elif value is String:
					var scancode = KeyInputUtils.string_to_scancode(value)
					if scancode != 0:
						controls_loaded[lane_key] = scancode
					else:
						controls_loaded[lane_key] = default_settings["controls_keymap"][lane_key]
					controls_updated = true

		if controls_updated:
			pass
		if loaded_settings.has("show_manual_track_input_on_generation"):
			loaded_settings.erase("show_manual_track_input_on_generation")
		settings = loaded_settings

		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.get("fullscreen", default_settings["fullscreen"]) else DisplayServer.WINDOW_MODE_WINDOWED)
		if not settings.get("fullscreen", default_settings["fullscreen"]):
			DisplayServer.window_set_size(Vector2i(1920, 1080))
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, true)
			var screen_size = DisplayServer.screen_get_size()
			var window_size = Vector2i(1920, 1080)
			DisplayServer.window_set_position((screen_size - window_size) / 2)
	else:
		_save_settings() 


func _save_settings():
	JsonUtils.write_json(SETTINGS_PATH, settings, true, true)


func _merge_defaults_with_loaded(defaults: Dictionary, loaded: Dictionary) -> Dictionary:
	var merged = defaults.duplicate(true)
	for key in loaded:
		if defaults.has(key):
			if defaults[key] is Dictionary and loaded[key] is Dictionary:
				merged[key] = _merge_defaults_with_loaded(defaults[key], loaded[key])
			else:
				merged[key] = loaded[key]
		else:
			merged[key] = loaded[key]
	return merged


func get_setting(setting_name: String, default_value=null):
	return settings.get(setting_name, default_value)

func set_setting(setting_name: String, value):
	settings[setting_name] = value

func save_settings():
	_save_settings()

func reset_settings():
	var prev_fullscreen = settings.get("fullscreen", false)
	settings = default_settings.duplicate(true)
	settings["fullscreen"] = prev_fullscreen
	_save_settings()

func get_music_volume() -> float:
	return float(settings.get("music_volume", default_settings["music_volume"]))

func get_menu_music_volume() -> float:
	return float(settings.get("menu_music_volume", default_settings["menu_music_volume"]))

func get_effects_volume() -> float:
	return float(settings.get("effects_volume", default_settings["effects_volume"])) 

func get_hit_sounds_volume() -> float:
	return float(settings.get("hit_sounds_volume", default_settings["hit_sounds_volume"])) 

func get_metronome_volume() -> float: 
	return float(settings.get("metronome_volume", default_settings["metronome_volume"]))

func get_preview_volume() -> float:
	return float(settings.get("preview_volume", default_settings["preview_volume"]))

func set_music_volume(volume: float): 
	settings["music_volume"] = clampf(volume, 0.0, 100.0) 

func set_menu_music_volume(volume: float):
	settings["menu_music_volume"] = clampf(volume, 0.0, 100.0)

func set_effects_volume(volume: float): 
	settings["effects_volume"] = clampf(volume, 0.0, 100.0) 

func set_hit_sounds_volume(volume: float):
	settings["hit_sounds_volume"] = clampf(volume, 0.0, 100.0)

func set_metronome_volume(volume: float):
	settings["metronome_volume"] = clampf(volume, 0.0, 100.0) 

func set_preview_volume(volume: float):
	settings["preview_volume"] = clampf(volume, 0.0, 100.0) 

func get_scroll_speed() -> float:
	return float(settings.get("scroll_speed", default_settings["scroll_speed"]))

func set_scroll_speed(value: float):
	settings["scroll_speed"] = clampf(value, 1.0, 20.0)
	_save_settings()

func get_timing_offset_ms() -> int:
	return int(settings.get("timing_offset_ms", default_settings["timing_offset_ms"]))

func set_timing_offset_ms(value: int):
	settings["timing_offset_ms"] = clamp(value, -500, 500)
	_save_settings()

func get_fps_mode() -> int:
	return settings.get("fps_mode", default_settings["fps_mode"])

func set_fps_mode(mode: int):
	settings["fps_mode"] = mode
	_save_settings() 

func get_show_fps() -> bool:
	return settings.get("fps_mode", default_settings["fps_mode"]) != 0

func set_show_fps(enabled: bool):
	settings["fps_mode"] = 1 if enabled else 0
	_save_settings() 

func get_fullscreen() -> bool:
	return settings.get("fullscreen", default_settings["fullscreen"])

func set_fullscreen(enabled: bool):
	settings["fullscreen"] = enabled
	_save_settings()

func get_lane_highlight_enabled() -> bool:
	return bool(settings.get("lane_highlight_enabled", default_settings["lane_highlight_enabled"]))

func set_lane_highlight_enabled(enabled: bool):
	settings["lane_highlight_enabled"] = enabled
	_save_settings()


func get_enable_debug_menu() -> bool:
	return settings.get("enable_debug_menu", default_settings["enable_debug_menu"])

func set_enable_debug_menu(enabled: bool):
	settings["enable_debug_menu"] = enabled

func get_controls_keymap() -> Dictionary:
	var current_keymap = settings.get("controls_keymap", default_settings["controls_keymap"].duplicate(true))
	var display_keymap = {}
	for i in range(MAX_LANES):  
		var lane_key = "lane_%d_key" % i
		var scancode = current_keymap.get(lane_key, default_settings["controls_keymap"][lane_key])
		if scancode is int:
			display_keymap[lane_key] = _get_key_string_from_scancode(scancode)
		else:
			printerr("SettingsManager: get_controls_keymap: Некорректное значение для ", lane_key)
			display_keymap[lane_key] = _get_key_string_from_scancode(default_settings["controls_keymap"][lane_key])
	return display_keymap

func get_controls_keymap_scancode() -> Dictionary:
	return settings.get("controls_keymap", default_settings["controls_keymap"].duplicate(true)).duplicate(true)

func set_controls_keymap_scancode(new_keymap_scancode: Dictionary):
	settings["controls_keymap"] = new_keymap_scancode.duplicate(true)

func get_key_text_for_lane(lane_index: int) -> String:
	if lane_index < 0 or lane_index >= MAX_LANES:
		return "X"
	var keymap = settings.get("controls_keymap", default_settings["controls_keymap"].duplicate(true))
	var lane_key = "lane_%d_key" % lane_index
	var scancode = keymap.get(lane_key, default_settings["controls_keymap"][lane_key])
	if scancode is int:
		return KeyInputUtils.get_key_string_from_scancode(scancode)
	else:
		var default_scancodes = [KEY_A, KEY_S, KEY_D, KEY_F, KEY_G]
		if lane_index < default_scancodes.size():
			return KeyInputUtils.get_key_string_from_scancode(default_scancodes[lane_index])
		else:
			return KeyInputUtils.get_key_string_from_scancode(KEY_X)

func set_key_scancode_for_lane(lane_index: int, new_scancode: int):
	var lane_key = "lane_%d_key" % lane_index
	settings["controls_keymap"][lane_key] = new_scancode

func get_key_scancode_for_lane(lane_index: int) -> int:
	if lane_index < 0 or lane_index >= MAX_LANES:
		return KEY_X
	var keymap = settings.get("controls_keymap", default_settings["controls_keymap"].duplicate(true))
	var lane_key = "lane_%d_key" % lane_index
	var scancode = keymap.get(lane_key, default_settings["controls_keymap"][lane_key])
	if scancode is int:
		return scancode
	else:
		var default_scancodes = [KEY_A, KEY_S, KEY_D, KEY_F, KEY_G]
		if lane_index < default_scancodes.size():
			return default_scancodes[lane_index]
		else:
			return KEY_X

func _string_to_scancode(key_string: String) -> int:
	return KeyInputUtils.string_to_scancode(key_string)

func _get_key_string_from_scancode(scancode: int) -> String:
	return KeyInputUtils.get_key_string_from_scancode(scancode)
 
static func is_service_key(scancode: int) -> bool:
	return KeyInputUtils.is_service_key(scancode)
func reset_all_settings():
	var current_controls = settings.get("controls_keymap", {}).duplicate(true)
	var prev_fullscreen = settings.get("fullscreen", false)
	
	settings = default_settings.duplicate(true)
	
	if not current_controls.is_empty():
		settings["controls_keymap"] = current_controls
	settings["fullscreen"] = prev_fullscreen
	
	_apply_reset_settings()
	_save_settings()

func _apply_reset_settings():
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.get("fullscreen", false) else DisplayServer.WINDOW_MODE_WINDOWED)
	
	if not settings.get("fullscreen", false):
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, true)
		var screen_size = DisplayServer.screen_get_size()
		var window_size = Vector2i(1920, 1080)
		DisplayServer.window_set_position((screen_size - window_size) / 2)
	
	pass
