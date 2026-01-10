# logic/settings_manager.gd
class_name SettingsManager
extends RefCounted

const SETTINGS_PATH = "user://settings.json"

var default_settings = {
	"music_volume": 50.0,
	"effects_volume": 50.0,
	"hit_sounds_volume": 70.0,
	"metronome_volume": 30.0, 
	"preview_volume": 70.0,
	"fps_mode": 0, 
	"fullscreen": false,
	"enable_debug_menu": false,
	"controls_keymap": {
		"lane_0_key": KEY_A,
		"lane_1_key": KEY_S,
		"lane_2_key": KEY_D,
		"lane_3_key": KEY_F,
	}
}

var settings: Dictionary = default_settings.duplicate(true)

static var _scancode_to_string_map: Dictionary = {
	KEY_A: "A", KEY_B: "B", KEY_C: "C", KEY_D: "D", KEY_E: "E", KEY_F: "F",
	KEY_G: "G", KEY_H: "H", KEY_I: "I", KEY_J: "J", KEY_K: "K", KEY_L: "L",
	KEY_M: "M", KEY_N: "N", KEY_O: "O", KEY_P: "P", KEY_Q: "Q", KEY_R: "R",
	KEY_S: "S", KEY_T: "T", KEY_U: "U", KEY_V: "V", KEY_W: "W", KEY_X: "X",
	KEY_Y: "Y", KEY_Z: "Z",
	KEY_0: "0", KEY_1: "1", KEY_2: "2", KEY_3: "3", KEY_4: "4", KEY_5: "5",
	KEY_6: "6", KEY_7: "7", KEY_8: "8", KEY_9: "9",
	KEY_SPACE: "Space",
	KEY_ENTER: "Enter",
	KEY_ESCAPE: "Escape",
	KEY_BACKSPACE: "Backspace",
	KEY_TAB: "Tab",
	KEY_SHIFT: "Shift",
	KEY_CTRL: "Ctrl",
	KEY_ALT: "Alt",
	KEY_UP: "Up",
	KEY_DOWN: "Down",
	KEY_LEFT: "Left",
	KEY_RIGHT: "Right",
	KEY_F1: "F1", KEY_F2: "F2", KEY_F3: "F3", KEY_F4: "F4", KEY_F5: "F5", KEY_F6: "F6",
	KEY_F7: "F7", KEY_F8: "F8", KEY_F9: "F9", KEY_F10: "F10", KEY_F11: "F11", KEY_F12: "F12",
}


func _init():
	_load_settings()


func _load_settings():
	var file_access = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file_access:
		var json_text = file_access.get_as_text()
		file_access.close()
		var json_result = JSON.parse_string(json_text)
		if json_result is Dictionary:
			var loaded_settings = _merge_defaults_with_loaded(default_settings, json_result)
			var controls_loaded = loaded_settings.get("controls_keymap", {})
			var controls_updated = false
			for i in range(4):
				var lane_key = "lane_%d_key" % i
				var value = controls_loaded.get(lane_key)
				if value is float:  
					controls_loaded[lane_key] = int(value)
					controls_updated = true
				elif value is String:  
					var scancode = _string_to_scancode(value)
					if scancode != 0:
						controls_loaded[lane_key] = scancode
						controls_updated = true
					else:
						controls_loaded[lane_key] = default_settings["controls_keymap"][lane_key]
						controls_updated = true
			if controls_updated:
				print("SettingsManager: Обновлен формат клавиш управления из float/строк в int при загрузке.")
			settings = loaded_settings
			print("SettingsManager: Настройки загружены из ", SETTINGS_PATH)
			print("SettingsManager: Загруженные настройки: ", settings)

			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.get("fullscreen", default_settings["fullscreen"]) else DisplayServer.WINDOW_MODE_WINDOWED)
			if not settings.get("fullscreen", default_settings["fullscreen"]):
				DisplayServer.window_set_size(Vector2i(1920, 1080))
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, true)
				var screen_size = DisplayServer.screen_get_size()
				var window_size = Vector2i(1920, 1080)
				DisplayServer.window_set_position((screen_size - window_size) / 2)
		else:
			print("SettingsManager: Ошибка парсинга JSON или данные не являются словарём в ", SETTINGS_PATH)
			_save_settings()
	else:
		print("SettingsManager: Файл settings.json не найден, создаем новый: ", SETTINGS_PATH)
		_save_settings() 


func _save_settings():
	var file_access = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file_access:
		var json_text = JSON.stringify(settings, "\t")
		file_access.store_string(json_text)
		file_access.close()
		print("SettingsManager: Настройки сохранены в ", SETTINGS_PATH)
	else:
		print("SettingsManager: Ошибка при открытии файла для записи: ", SETTINGS_PATH)


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
	settings = default_settings.duplicate(true)
	_save_settings()
	print("SettingsManager: Настройки сброшены к значениям по умолчанию.")

func get_music_volume() -> float:
	return float(settings.get("music_volume", default_settings["music_volume"]))

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

func set_effects_volume(volume: float): 
	settings["effects_volume"] = clampf(volume, 0.0, 100.0) 

func set_hit_sounds_volume(volume: float):
	settings["hit_sounds_volume"] = clampf(volume, 0.0, 100.0)

func set_metronome_volume(volume: float):
	settings["metronome_volume"] = clampf(volume, 0.0, 100.0) 

func set_preview_volume(volume: float):
	settings["preview_volume"] = clampf(volume, 0.0, 100.0) 

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
	print("SettingsManager: set_fullscreen вызван с enabled = ", enabled)
	_save_settings()
	if enabled:
		print("SettingsManager: Значение полноэкранного режима установлено в true.")
	else:
		print("SettingsManager: Значение полноэкранного режима установлено в false.")


func get_enable_debug_menu() -> bool:
	return settings.get("enable_debug_menu", default_settings["enable_debug_menu"])

func set_enable_debug_menu(enabled: bool):
	settings["enable_debug_menu"] = enabled

func get_controls_keymap() -> Dictionary:
	var current_keymap = settings.get("controls_keymap", default_settings["controls_keymap"].duplicate(true))
	var display_keymap = {}
	for i in range(4):
		var lane_key = "lane_%d_key" % i
		var scancode = current_keymap.get(lane_key, default_settings["controls_keymap"][lane_key])
		if scancode is int:
			display_keymap[lane_key] = _get_key_string_from_scancode(scancode)
		else:
			printerr("SettingsManager: get_controls_keymap: Найдено нецелочисленное значение для ", lane_key, ": ", scancode, " (тип: ", typeof(scancode), "). Используем дефолт.")
			display_keymap[lane_key] = _get_key_string_from_scancode(default_settings["controls_keymap"][lane_key])
	return display_keymap

func get_controls_keymap_scancode() -> Dictionary:
	return settings.get("controls_keymap", default_settings["controls_keymap"].duplicate(true)).duplicate(true)

func set_controls_keymap_scancode(new_keymap_scancode: Dictionary):
	settings["controls_keymap"] = new_keymap_scancode.duplicate(true)
	print("SettingsManager: Установлен keymap (scancode): ", new_keymap_scancode)

func get_key_text_for_lane(lane_index: int) -> String:
	var keymap = settings.get("controls_keymap", default_settings["controls_keymap"].duplicate(true))
	var lane_key = "lane_%d_key" % lane_index
	var scancode = keymap.get(lane_key, default_settings["controls_keymap"][lane_key])
	if scancode is int:
		return _get_key_string_from_scancode(scancode)
	else:
		printerr("SettingsManager: get_key_text_for_lane: Найдено нецелочисленное значение для lane ", lane_index, ": ", scancode, " (тип: ", typeof(scancode), "). Используем дефолт.")
		var default_scancodes = [KEY_A, KEY_S, KEY_D, KEY_F]
		if lane_index >= 0 and lane_index < default_scancodes.size():
			return _get_key_string_from_scancode(default_scancodes[lane_index])
		else:
			return _get_key_string_from_scancode(KEY_X)

func set_key_scancode_for_lane(lane_index: int, new_scancode: int):
	var lane_key = "lane_%d_key" % lane_index
	settings["controls_keymap"][lane_key] = new_scancode
	print("SettingsManager: Установлен scancode '", new_scancode, "' (", _get_key_string_from_scancode(new_scancode), ") для линии ", lane_index)

func get_key_scancode_for_lane(lane_index: int) -> int:
	var keymap = settings.get("controls_keymap", default_settings["controls_keymap"].duplicate(true))
	var lane_key = "lane_%d_key" % lane_index
	var scancode = keymap.get(lane_key, default_settings["controls_keymap"][lane_key])
	if scancode is int:
		return scancode
	else:
		printerr("SettingsManager: get_key_scancode_for_lane: Найдено нецелочисленное значение для lane ", lane_index, ": ", scancode, " (тип: ", typeof(scancode), "). Используем дефолт.")
		var default_scancodes = [KEY_A, KEY_S, KEY_D, KEY_F]
		if lane_index >= 0 and lane_index < default_scancodes.size():
			return default_scancodes[lane_index]
		else:
			return KEY_X

func _string_to_scancode(key_string: String) -> int:
	var key_to_scancode_map = {
		"A": KEY_A, "B": KEY_B, "C": KEY_C, "D": KEY_D, "E": KEY_E, "F": KEY_F,
		"G": KEY_G, "H": KEY_H, "I": KEY_I, "J": KEY_J, "K": KEY_K, "L": KEY_L,
		"M": KEY_M, "N": KEY_N, "O": KEY_O, "P": KEY_P, "Q": KEY_Q, "R": KEY_R,
		"S": KEY_S, "T": KEY_T, "U": KEY_U, "V": KEY_V, "W": KEY_W, "X": KEY_X,
		"Y": KEY_Y, "Z": KEY_Z,
		"0": KEY_0, "1": KEY_1, "2": KEY_2, "3": KEY_3, "4": KEY_4, "5": KEY_5,
		"6": KEY_6, "7": KEY_7, "8": KEY_8, "9": KEY_9,
	}
	return key_to_scancode_map.get(key_string.to_upper(), 0)

func _get_key_string_from_scancode(scancode: int) -> String:
	var key_string = _scancode_to_string_map.get(scancode, "Unknown")
	if key_string == "Unknown":
		printerr("SettingsManager: _get_key_string_from_scancode: Неизвестный scancode ", scancode)
		return "Key" + str(scancode)
	return key_string
func reset_all_settings():
	var current_controls = settings.get("controls_keymap", {}).duplicate(true)
	
	settings = default_settings.duplicate(true)
	
	if not current_controls.is_empty():
		settings["controls_keymap"] = current_controls
	
	_apply_reset_settings()
	_save_settings()
	print("SettingsManager: Все настройки сброшены к значениям по умолчанию")

func _apply_reset_settings():
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.get("fullscreen", false) else DisplayServer.WINDOW_MODE_WINDOWED)
	
	if not settings.get("fullscreen", false):
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, true)
		var screen_size = DisplayServer.screen_get_size()
		var window_size = Vector2i(1920, 1080)
		DisplayServer.window_set_position((screen_size - window_size) / 2)
	
	print("SettingsManager: Сброшенные настройки применены к системе")
