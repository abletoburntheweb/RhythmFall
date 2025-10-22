#logic/settings_manager.gd
class_name SettingsManager
extends RefCounted

const SETTINGS_PATH = "user://settings.json"

var default_settings = {
	"music_volume": 50,
	"effects_volume": 50,
	"hit_sounds_volume": 70,
	"metronome_volume": 30,
	"preview_volume": 70,
	"show_fps": false,
	"fullscreen": false,
	"enable_debug_menu": false,
	"controls_keymap": {
		"lane_0_key": "A",
		"lane_1_key": "S",
		"lane_2_key": "D",
		"lane_3_key": "F",
	}
}

var settings: Dictionary = default_settings.duplicate(true)


func _init():
	_load_settings()


func _load_settings():
	var file_access = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file_access:
		var json_text = file_access.get_as_text()
		file_access.close()
		var json_result = JSON.parse_string(json_text)
		if json_result is Dictionary:
			settings = _merge_defaults_with_loaded(default_settings, json_result)
			print("SettingsManager: Настройки загружены из ", SETTINGS_PATH)
			print("SettingsManager: Загруженные настройки: ", settings)
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

func get_music_volume() -> int:
	return settings.get("music_volume", default_settings["music_volume"])

func set_music_volume(volume: int):
	settings["music_volume"] = clampi(volume, 0, 100)

func get_effects_volume() -> int:
	return settings.get("effects_volume", default_settings["effects_volume"])

func set_effects_volume(volume: int):
	settings["effects_volume"] = clampi(volume, 0, 100)

func get_hit_sounds_volume() -> int:
	return settings.get("hit_sounds_volume", default_settings["hit_sounds_volume"])

func set_hit_sounds_volume(volume: int):
	settings["hit_sounds_volume"] = clampi(volume, 0, 100)

func get_metronome_volume() -> int:
	return settings.get("metronome_volume", default_settings["metronome_volume"])

func set_metronome_volume(volume: int):
	settings["metronome_volume"] = clampi(volume, 0, 100)

func get_preview_volume() -> int:
	return settings.get("preview_volume", default_settings["preview_volume"])

func set_preview_volume(volume: int):
	settings["preview_volume"] = clampi(volume, 0, 100)

func get_show_fps() -> bool:
	return settings.get("show_fps", default_settings["show_fps"])

func set_show_fps(enabled: bool):
	settings["show_fps"] = enabled

func get_fullscreen() -> bool:
	return settings.get("fullscreen", default_settings["fullscreen"])

func set_fullscreen(enabled: bool):
	settings["fullscreen"] = enabled

func get_enable_debug_menu() -> bool:
	return settings.get("enable_debug_menu", default_settings["enable_debug_menu"])

func set_enable_debug_menu(enabled: bool):
	settings["enable_debug_menu"] = enabled

func get_controls_keymap() -> Dictionary:
	return settings.get("controls_keymap", default_settings["controls_keymap"].duplicate(true))

func set_controls_keymap(new_keymap: Dictionary):
	settings["controls_keymap"] = new_keymap

func get_key_text_for_lane(lane_index: int) -> String:
	var keymap = settings.get("controls_keymap", default_settings["controls_keymap"].duplicate(true))
	var lane_key = "lane_%d_key" % lane_index
	var key_text = keymap.get(lane_key, default_settings["controls_keymap"][lane_key])
	if key_text is String:
		return key_text
	else:
		printerr("SettingsManager: get_key_text_for_lane: Найдено нестроковое значение для lane ", lane_index, ": ", key_text, " (тип: ", typeof(key_text), "). Используем дефолт.")
		var default_keys = ["A", "S", "D", "F"]
		if lane_index >= 0 and lane_index < default_keys.size():
			return default_keys[lane_index]
		else:
			return "X" 
	return key_text

func set_key_text_for_lane(lane_index: int, new_key_text: String): # Принимает текст
	var lane_key = "lane_%d_key" % lane_index
	settings["controls_keymap"][lane_key] = new_key_text
	print("SettingsManager: Установлена клавиша '", new_key_text, "' для линии ", lane_index)



func get_key_scancode_for_lane(lane_index: int) -> int:
	var text_key = get_key_text_for_lane(lane_index)
	var key_to_scancode_map = {
		"A": KEY_A, "B": KEY_B, "C": KEY_C, "D": KEY_D, "E": KEY_E, "F": KEY_F,
		"G": KEY_G, "H": KEY_H, "I": KEY_I, "J": KEY_J, "K": KEY_K, "L": KEY_L,
		"M": KEY_M, "N": KEY_N, "O": KEY_O, "P": KEY_P, "Q": KEY_Q, "R": KEY_R,
		"S": KEY_S, "T": KEY_T, "U": KEY_U, "V": KEY_V, "W": KEY_W, "X": KEY_X,
		"Y": KEY_Y, "Z": KEY_Z,
		"0": KEY_0, "1": KEY_1, "2": KEY_2, "3": KEY_3, "4": KEY_4, "5": KEY_5,
		"6": KEY_6, "7": KEY_7, "8": KEY_8, "9": KEY_9,
	}
	var scancode = key_to_scancode_map.get(text_key.to_upper(), 0)
	print("SettingsManager: Текст '", text_key, "' преобразован в скан-код ", scancode)
	return scancode
