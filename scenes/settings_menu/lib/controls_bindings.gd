# logic/utils/controls_bindings.gd
extends RefCounted
class_name ControlsBindings

const LAYOUT_PRIMARY := "primary"
const LAYOUT_ALT := "alt"
const LAYOUT_BOTH := "both"

const DEFAULT_KEYMAP_PRIMARY := {
	"lane_0_key": KEY_A,
	"lane_1_key": KEY_S,
	"lane_2_key": KEY_D,
	"lane_3_key": KEY_F,
	"lane_4_key": KEY_G,
}

const DEFAULT_KEYMAP_ALT := {
	"lane_0_key": KEY_J,
	"lane_1_key": KEY_K,
	"lane_2_key": KEY_L,
	"lane_3_key": KEY_SEMICOLON,
	"lane_4_key": KEY_APOSTROPHE,
}


static func sanitize_layout_mode(raw: Variant) -> String:
	var mode := str(raw).strip_edges()
	if mode == LAYOUT_ALT or mode == LAYOUT_BOTH:
		return mode
	return LAYOUT_PRIMARY


static func sanitize_lane_keymap(raw: Variant, fallback: Dictionary) -> Dictionary:
	var out := fallback.duplicate(true)
	if raw is Dictionary:
		for i in range(5):
			var lane_key := "lane_%d_key" % i
			if raw.has(lane_key):
				out[lane_key] = int(raw[lane_key])
	return out


static func build_lane_keymap(keymap: Dictionary) -> Dictionary:
	var out := {}
	for i in range(5):
		var sc := int(keymap.get("lane_%d_key" % i, 0))
		if sc != 0 and sc != KEY_X:
			out[sc] = i
	return out


static func merge_lane_keymaps(primary: Dictionary, alt: Dictionary) -> Dictionary:
	var out := primary.duplicate(true)
	for key in alt:
		out[key] = alt[key]
	return out


static func dedupe_scancodes(values: Array) -> Array[int]:
	var out: Array[int] = []
	for v in values:
		var sc := int(v)
		if sc != 0 and sc != KEY_X and not out.has(sc):
			out.append(sc)
	return out
