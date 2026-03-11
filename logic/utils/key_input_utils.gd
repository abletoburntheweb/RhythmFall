# logic/utils/key_input_utils.gd
extends RefCounted
class_name KeyInputUtils

static var _scancode_to_string: Dictionary = {
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

static var _string_to_scancode: Dictionary = {}

static func get_key_string_from_scancode(scancode: int) -> String:
	var s = _scancode_to_string.get(scancode, "")
	if s == "":
		return "Key" + str(scancode)
	return s

static func string_to_scancode(key_string: String) -> int:
	if _string_to_scancode.is_empty():
		for k in _scancode_to_string.keys():
			_string_to_scancode[_scancode_to_string[k]] = k
	return int(_string_to_scancode.get(key_string.to_upper(), 0))

static func is_service_key(scancode: int) -> bool:
	return scancode == KEY_SHIFT \
		or scancode == KEY_ALT \
		or scancode == KEY_CTRL \
		or scancode == KEY_META \
		or scancode == KEY_CAPSLOCK \
		or scancode == KEY_NUMLOCK \
		or scancode == KEY_SCROLLLOCK \
		or scancode == KEY_TAB \
		or scancode == KEY_QUOTELEFT \
		or scancode == KEY_ENTER \
		or scancode == KEY_BACKSPACE \
		or scancode == KEY_F1 \
		or scancode == KEY_F2 \
		or scancode == KEY_F3 \
		or scancode == KEY_F4 \
		or scancode == KEY_F5 \
		or scancode == KEY_F6 \
		or scancode == KEY_F7 \
		or scancode == KEY_F8 \
		or scancode == KEY_F9 \
		or scancode == KEY_F10 \
		or scancode == KEY_F11 \
		or scancode == KEY_F12
