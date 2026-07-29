# logic/utils/duo_mode.gd
extends RefCounted
class_name DuoMode

const STYLE_WARM_COOL := "warm_cool"
const STYLE_TINT := "tint"
const STYLE_OUTLINE := "outline"
const STYLE_NONE := "none"

const VALID_STYLES: Array[String] = [
	STYLE_WARM_COOL,
	STYLE_TINT,
	STYLE_OUTLINE,
	STYLE_NONE,
]

const WARM_TINT := Color(1.0, 0.94, 0.88)
const COOL_TINT := Color(0.86, 0.93, 1.0)
const WARM_BLEND := 0.12
const COOL_BLEND := 0.12
const TINT_BRIGHTNESS := 1.1
const TINT_COOL_BLEND := 0.15
const OUTLINE_INSET_PX := 2.0


static func split_index(chart_lanes: int) -> int:
	return int(ceil(float(chart_lanes) / 2.0))


static func p1_lane_count(chart_lanes: int) -> int:
	return split_index(chart_lanes)


static func p2_lane_count(chart_lanes: int) -> int:
	return maxi(chart_lanes - split_index(chart_lanes), 1)


static func sanitize_style(raw: String) -> String:
	var v := raw.strip_edges().to_lower()
	if v in VALID_STYLES:
		return v
	return STYLE_WARM_COOL


static func current_style() -> String:
	if SettingsManager and SettingsManager.has_method("get_duo_partner_note_style"):
		return SettingsManager.get_duo_partner_note_style()
	return STYLE_WARM_COOL


static func should_draw_partner_outline() -> bool:
	return current_style() == STYLE_OUTLINE


static func apply_note_color(color: Color, is_partner: bool) -> Color:
	match current_style():
		STYLE_NONE:
			return color
		STYLE_WARM_COOL:
			if is_partner:
				return _blend_tint(color, COOL_TINT, COOL_BLEND)
			return _blend_tint(color, WARM_TINT, WARM_BLEND)
		STYLE_TINT:
			if is_partner:
				return _tint_cool_bright(color)
			return color
		STYLE_OUTLINE:
			return color
		_:
			return color


static func partner_outline_color(note_color: Color) -> Color:
	return Color(0.45, 0.78, 0.98, clampf(note_color.a * 0.85, 0.35, 0.95))


static func _blend_tint(rgb: Color, tint: Color, blend: float) -> Color:
	return Color(rgb.r, rgb.g, rgb.b, rgb.a).lerp(tint, blend)


static func _tint_cool_bright(rgb: Color) -> Color:
	var bright := Color(
		clampf(rgb.r * TINT_BRIGHTNESS, 0.0, 1.0),
		clampf(rgb.g * TINT_BRIGHTNESS, 0.0, 1.0),
		clampf(rgb.b * TINT_BRIGHTNESS, 0.0, 1.0),
		rgb.a
	)
	return bright.lerp(COOL_TINT, TINT_COOL_BLEND)


static func queue_for_player(full_queue: Array, player_idx: int, chart_lanes: int) -> Array:
	var split_at := split_index(chart_lanes)
	var out: Array = []
	for item in full_queue:
		if not item is Dictionary:
			continue
		var chart_lane := int(item.get("lane", 0))
		if player_idx == 0:
			if chart_lane >= split_at:
				continue
			var copy: Dictionary = (item as Dictionary).duplicate()
			copy["lane"] = chart_lane
			out.append(copy)
		else:
			if chart_lane < split_at:
				continue
			var copy: Dictionary = (item as Dictionary).duplicate()
			copy["lane"] = chart_lane - split_at
			out.append(copy)
	out.sort_custom(func(a, b) -> bool:
		return float(a.get("time", 0.0)) < float(b.get("time", 0.0))
	)
	return out
