# Guitar Hero / Rock Band style controller presets and device detection.
extends RefCounted
class_name GuitarHeroBindings

const MAX_LANES := 5

# XInput fret order: green, red, yellow, blue, orange.
const DEFAULT_LANE_BUTTONS := [0, 1, 3, 2, 9]
const DEFAULT_STRUM_UP := 11
const DEFAULT_STRUM_DOWN := 12
const DEFAULT_PAUSE_BUTTON := 6
const DEFAULT_SKIP_BUTTON := 4

const DETECT_NAME_TOKENS := [
	"guitar",
	"hero",
	"rock band",
	"xplorer",
	"wiitar",
	"clone hero",
	"gh live",
	"mustang",
	"strat",
	"les paul",
	"xinput",
	"gamepad",
	"controller",
]

# JoyButton indices (Godot 4 XInput layout).
const BUTTON_LABELS := {
	0: "A",
	1: "B",
	2: "X",
	3: "Y",
	4: "Select",
	5: "Guide",
	6: "Start",
	7: "L3",
	8: "R3",
	9: "LB",
	10: "RB",
	11: "D-Pad Up",
	12: "D-Pad Down",
	13: "D-Pad Left",
	14: "D-Pad Right",
}

const LANE_COLOR_KEYS := [
	"CONTROLS_GH_COLOR_GREEN",
	"CONTROLS_GH_COLOR_RED",
	"CONTROLS_GH_COLOR_YELLOW",
	"CONTROLS_GH_COLOR_BLUE",
	"CONTROLS_GH_COLOR_ORANGE",
]

const LANE_COLORS := [
	Color(0.22, 0.92, 0.38, 1.0),
	Color(0.95, 0.22, 0.22, 1.0),
	Color(0.98, 0.88, 0.18, 1.0),
	Color(0.32, 0.58, 1.0, 1.0),
	Color(1.0, 0.55, 0.12, 1.0),
]


static func sanitize_lane_buttons(raw: Variant) -> Array[int]:
	var out: Array[int] = []
	out.assign(DEFAULT_LANE_BUTTONS)
	if raw is Array:
		for lane in range(mini(raw.size(), MAX_LANES)):
			out[lane] = int(raw[lane])
	return out


static func sanitize_button(raw: Variant, fallback: int) -> int:
	if raw is int:
		return raw
	if raw is float:
		return int(raw)
	return fallback


static func detect_guitar_device_id() -> int:
	for device_id in Input.get_connected_joypads():
		if is_likely_guitar_device(device_id):
			return device_id
	return -1


static func resolve_auto_device_id() -> int:
	var connected := Input.get_connected_joypads()
	var by_name := detect_guitar_device_id()
	if by_name >= 0:
		return by_name
	if connected.size() == 1:
		return int(connected[0])
	if connected.size() > 1:
		return int(connected[0])
	return -1


static func is_likely_guitar_device(device_id: int) -> bool:
	if device_id < 0:
		return false
	return is_guitar_name(Input.get_joy_name(device_id))


static func is_guitar_name(device_name: String) -> bool:
	var lower := device_name.to_lower()
	for token in DETECT_NAME_TOKENS:
		if token in lower:
			return true
	return false


static func button_display_name(button_index: int) -> String:
	if BUTTON_LABELS.has(button_index):
		return str(BUTTON_LABELS[button_index])
	return "Btn %d" % button_index


static func lane_color_key(lane: int) -> String:
	if lane < 0 or lane >= LANE_COLOR_KEYS.size():
		return ""
	return LANE_COLOR_KEYS[lane]


static func lane_color(lane: int) -> Color:
	if lane < 0 or lane >= LANE_COLORS.size():
		return Color.WHITE
	return LANE_COLORS[lane]


static func fret_color_keys() -> PackedStringArray:
	return PackedStringArray(LANE_COLOR_KEYS)


static func lane_row_label(lane: int) -> String:
	if lane < 0 or lane >= LANE_COLOR_KEYS.size():
		return ""
	var color_name := TranslationServer.translate(lane_color_key(lane))
	var lane_name := TranslationServer.translate("CONTROLS_LANE") % (lane + 1)
	return "%s (%s)" % [color_name, lane_name]


static func lane_binding_label(lane: int, button_index: int) -> String:
	return "%s (%s)" % [lane_row_label(lane), button_display_name(button_index)]


static func lane_button_label(lane: int, button_index: int) -> String:
	var color_name := TranslationServer.translate(lane_color_key(lane))
	return "%s (%s)" % [color_name, button_display_name(button_index)]
