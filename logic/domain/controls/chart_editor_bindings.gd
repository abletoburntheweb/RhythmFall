# logic/domain/controls/chart_editor_bindings.gd
extends RefCounted
class_name ChartEditorBindings

# Logical actions for Chart Editor
const ACTIONS := [
	"undo",
	"redo",
	"save",
	"select_all",
	"copy",
	"paste",
	"duplicate",
	"delete",
	"clear_selection",
	"play_pause",
	"song_start",
	"song_end",
	"prev_beat",
	"next_beat",
	"prev_measure",
	"next_measure",
	"quantize",
	"toggle_audio_source",
	"tool_pencil",
	"tool_select",
	"cut",
]

# Human readable sections for UI
const SECTIONS := {
	"editing": ["undo", "redo", "save", "select_all", "copy", "paste", "duplicate", "delete", "clear_selection", "cut"],
	"playback": ["play_pause", "toggle_audio_source"],
	"navigation": ["song_start", "song_end", "prev_beat", "next_beat", "prev_measure", "next_measure"],
	"chart": ["quantize"],
	"tools": ["tool_select", "tool_pencil"],
}

const SECTION_LABELS := {
	"editing": "Редактирование",
	"playback": "Воспроизведение",
	"navigation": "Навигация",
	"chart": "Чарт",
	"tools": "Инструменты",
}

const ACTION_LABELS := {
	"undo": "Undo",
	"redo": "Redo",
	"save": "Save",
	"select_all": "Select All",
	"copy": "Copy",
	"paste": "Paste",
	"duplicate": "Duplicate",
	"delete": "Delete",
	"clear_selection": "Clear Selection",
	"play_pause": "Play / Pause",
	"song_start": "Song Start",
	"song_end": "Song End",
	"prev_beat": "Previous Beat",
	"next_beat": "Next Beat",
	"prev_measure": "Previous Measure",
	"next_measure": "Next Measure",
	"quantize": "Quantize",
	"toggle_audio_source": "Toggle Audio Source",
	"tool_pencil": "Pencil",
	"tool_select": "Select",
	"cut": "Cut",
}

# Default keymap per spec — structured combos
const DEFAULT_KEYMAP := {
	"undo": [{"key": KEY_Z, "ctrl": true, "shift": false, "alt": false}],
	"redo": [
		{"key": KEY_Y, "ctrl": true, "shift": false, "alt": false},
		{"key": KEY_Z, "ctrl": true, "shift": true, "alt": false}
	],
	"save": [{"key": KEY_S, "ctrl": true, "shift": false, "alt": false}],
	"select_all": [{"key": KEY_A, "ctrl": true, "shift": false, "alt": false}],
	"copy": [{"key": KEY_C, "ctrl": true, "shift": false, "alt": false}],
	"paste": [{"key": KEY_V, "ctrl": true, "shift": false, "alt": false}],
	"duplicate": [{"key": KEY_D, "ctrl": true, "shift": false, "alt": false}],
	"delete": [
		{"key": KEY_DELETE, "ctrl": false, "shift": false, "alt": false},
		{"key": KEY_BACKSPACE, "ctrl": false, "shift": false, "alt": false}
	],
	"clear_selection": [{"key": KEY_ESCAPE, "ctrl": false, "shift": false, "alt": false}],
	"play_pause": [{"key": KEY_SPACE, "ctrl": false, "shift": false, "alt": false}],
	"song_start": [{"key": KEY_HOME, "ctrl": false, "shift": false, "alt": false}],
	"song_end": [{"key": KEY_END, "ctrl": false, "shift": false, "alt": false}],
	"prev_beat": [{"key": KEY_LEFT, "ctrl": false, "shift": false, "alt": false}],
	"next_beat": [{"key": KEY_RIGHT, "ctrl": false, "shift": false, "alt": false}],
	"prev_measure": [{"key": KEY_LEFT, "ctrl": false, "shift": true, "alt": false}],
	"next_measure": [{"key": KEY_RIGHT, "ctrl": false, "shift": true, "alt": false}],
	"quantize": [{"key": KEY_Q, "ctrl": false, "shift": false, "alt": false}],
	"toggle_audio_source": [{"key": KEY_T, "ctrl": false, "shift": false, "alt": false}],
	"tool_pencil": [{"key": KEY_P, "ctrl": false, "shift": false, "alt": false}],
	"tool_select": [{"key": KEY_E, "ctrl": false, "shift": false, "alt": false}],
	"cut": [{"key": KEY_X, "ctrl": true, "shift": false, "alt": false}],
}

static func make_binding(key: int, ctrl: bool = false, shift: bool = false, alt: bool = false) -> Dictionary:
	return {"key": key, "ctrl": ctrl, "shift": shift, "alt": alt}

static func binding_equals(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("key", 0)) == int(b.get("key", 0)) \
		and bool(a.get("ctrl", false)) == bool(b.get("ctrl", false)) \
		and bool(a.get("shift", false)) == bool(b.get("shift", false)) \
		and bool(a.get("alt", false)) == bool(b.get("alt", false))

static func event_to_binding(event: InputEventKey) -> Dictionary:
	var sc := int(event.keycode)
	if sc == 0:
		sc = int(event.physical_keycode)
	return {"key": sc, "ctrl": event.ctrl_pressed, "shift": event.shift_pressed, "alt": event.alt_pressed}

static func binding_to_string(binding: Dictionary) -> String:
	var parts: Array[String] = []
	if bool(binding.get("ctrl", false)):
		parts.append("Ctrl")
	if bool(binding.get("shift", false)):
		parts.append("Shift")
	if bool(binding.get("alt", false)):
		parts.append("Alt")
	var key := int(binding.get("key", 0))
	var key_str := KeyInputUtils.get_key_string_from_scancode(key)
	if key_str == "":
		key_str = OS.get_keycode_string(key)
		if key_str == "":
			key_str = "Key%d" % key
	# For single keys like Space, keep as is
	parts.append(key_str)
	return "+".join(parts)

static func sanitize_binding(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var key := int(raw.get("key", 0))
	if key == 0:
		return {}
	var ctrl := bool(raw.get("ctrl", false))
	var shift := bool(raw.get("shift", false))
	var alt := bool(raw.get("alt", false))
	# Filter out pure modifier keys as primary key
	if key == KEY_CTRL or key == KEY_SHIFT or key == KEY_ALT or key == KEY_META:
		return {}
	return {"key": key, "ctrl": ctrl, "shift": shift, "alt": alt}

static func sanitize_keymap(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if raw is Dictionary:
		for action in ACTIONS:
			var arr = raw.get(action, null)
			if arr is Array:
				var cleaned: Array = []
				for b in arr:
					var s := sanitize_binding(b)
					if not s.is_empty():
						# Dedupe within action
						var dup := false
						for existing in cleaned:
							if binding_equals(existing, s):
								dup = true
								break
						if not dup:
							cleaned.append(s)
				if not cleaned.is_empty():
					out[action] = cleaned
				else:
					out[action] = _duplicate_defaults(action)
			else:
				out[action] = _duplicate_defaults(action)
		# Also handle legacy single binding stored as dict not array
		for action in raw.keys():
			if not out.has(action) and raw[action] is Dictionary:
				var s := sanitize_binding(raw[action])
				if not s.is_empty():
					out[action] = [s]
	else:
		for action in ACTIONS:
			out[action] = _duplicate_defaults(action)
	# Ensure all actions present
	for action in ACTIONS:
		if not out.has(action):
			out[action] = _duplicate_defaults(action)
	return out

static func _duplicate_defaults(action: String) -> Array:
	var arr = DEFAULT_KEYMAP.get(action, [])
	var out: Array = []
	for b in arr:
		out.append(b.duplicate(true))
	return out

static func get_default_keymap() -> Dictionary:
	return sanitize_keymap(DEFAULT_KEYMAP)

static func matches_event(binding: Dictionary, event: InputEventKey) -> bool:
	if event.keycode == 0 and event.physical_keycode == 0:
		return false
	var ev_binding := event_to_binding(event)
	# For event, keycode may be e.g., KEY_Z with ctrl, but we need exact match
	return binding_equals(binding, ev_binding)

static func find_binding(keymap: Dictionary, event: InputEventKey) -> String:
	# Returns action id if event matches any binding in keymap
	for action in keymap.keys():
		var arr = keymap[action]
		if arr is Array:
			for binding in arr:
				if binding is Dictionary and matches_event(binding, event):
					return String(action)
	return ""

static func get_bindings_for_action(keymap: Dictionary, action: String) -> Array:
	var arr = keymap.get(action, [])
	if arr is Array:
		return arr.duplicate(true)
	return []

static func set_binding_for_action(keymap: Dictionary, action: String, index: int, new_binding: Dictionary) -> Dictionary:
	var out := keymap.duplicate(true)
	var arr = out.get(action, [])
	if not arr is Array:
		arr = []
	# Ensure array size
	while arr.size() <= index:
		arr.append({})
	if new_binding.is_empty():
		# Remove this index
		arr.remove_at(index)
	else:
		arr[index] = new_binding.duplicate(true)
	out[action] = arr
	return out

static func add_binding_for_action(keymap: Dictionary, action: String, new_binding: Dictionary) -> Dictionary:
	var out := keymap.duplicate(true)
	var arr = out.get(action, [])
	if not arr is Array:
		arr = []
	arr.append(new_binding.duplicate(true))
	out[action] = arr
	return out

static func remove_binding_for_action(keymap: Dictionary, action: String, index: int) -> Dictionary:
	var out := keymap.duplicate(true)
	var arr = out.get(action, [])
	if arr is Array and index >= 0 and index < arr.size():
		arr.remove_at(index)
		out[action] = arr
	return out

static func find_duplicate(keymap: Dictionary, new_binding: Dictionary, exclude_action: String = "", exclude_index: int = -1) -> Dictionary:
	# Returns {"action": ..., "index": ...} if duplicate found
	for action in keymap.keys():
		var arr = keymap[action]
		if not arr is Array:
			continue
		for i in range(arr.size()):
			if action == exclude_action and i == exclude_index:
				continue
			var b = arr[i]
			if b is Dictionary and binding_equals(b, new_binding):
				return {"action": action, "index": i}
	return {}

static func swap_bindings(keymap: Dictionary, action_a: String, index_a: int, action_b: String, index_b: int) -> Dictionary:
	var out := keymap.duplicate(true)
	var arr_a = out.get(action_a, [])
	var arr_b = out.get(action_b, [])
	if not arr_a is Array or not arr_b is Array:
		return out
	if index_a < 0 or index_a >= arr_a.size() or index_b < 0 or index_b >= arr_b.size():
		return out
	var tmp = arr_a[index_a].duplicate(true)
	arr_a[index_a] = arr_b[index_b].duplicate(true)
	arr_b[index_b] = tmp
	out[action_a] = arr_a
	out[action_b] = arr_b
	return out
