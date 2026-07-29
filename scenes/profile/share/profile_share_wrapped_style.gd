# scenes/profile/share/profile_share_wrapped_style.gd
class_name ProfileShareWrappedStyle
extends RefCounted

const CARD_GRADIENTS := {
	"overview": {
		"bg": Color(0.05, 0.03, 0.1, 1.0),
		"glow_a": Color(0.72, 0.32, 0.95, 0.38),
		"glow_b": Color(0.95, 0.35, 0.65, 0.22),
	},
	"statistics": {
		"bg": Color(0.03, 0.06, 0.12, 1.0),
		"glow_a": Color(0.28, 0.58, 0.98, 0.38),
		"glow_b": Color(0.15, 0.82, 0.95, 0.2),
	},
	"music": {
		"bg": Color(0.03, 0.08, 0.06, 1.0),
		"glow_a": Color(0.22, 0.88, 0.52, 0.36),
		"glow_b": Color(0.48, 0.98, 0.65, 0.18),
	},
	"records": {
		"bg": Color(0.09, 0.06, 0.03, 1.0),
		"glow_a": Color(0.98, 0.78, 0.32, 0.38),
		"glow_b": Color(0.95, 0.52, 0.18, 0.2),
	},
}

const VALUE_COLORS := {
	"rr": Color(0.98, 0.78, 0.38, 1.0),
	"accuracy": Color(0.42, 0.88, 0.78, 1.0),
	"combo": Color(0.98, 0.72, 0.35, 1.0),
	"score": Color(0.82, 0.86, 0.96, 1.0),
	"miss": Color(0.92, 0.48, 0.48, 1.0),
	"medal": Color(0.96, 0.82, 0.42, 1.0),
}


static func card_index_label(index: int) -> String:
	return "%02d" % (index + 1)


static func glass_style(accent: Color, scale: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(accent.r, accent.g, accent.b, 0.12)
	box.border_color = Color(accent.r, accent.g, accent.b, 0.42)
	box.set_border_width_all(maxi(2, int(round(2.0 * scale))))
	var radius := maxi(10, int(round(18.0 * scale)))
	box.set_corner_radius_all(radius)
	var pad := maxf(8.0, 16.0 * scale)
	box.content_margin_left = pad
	box.content_margin_right = pad
	box.content_margin_top = pad * 0.9
	box.content_margin_bottom = pad * 0.9
	box.shadow_color = Color(accent.r, accent.g, accent.b, 0.18)
	box.shadow_size = maxi(0, int(round(8.0 * scale)))
	return box


static func hero_chip_style(accent: Color, scale: float) -> StyleBoxFlat:
	var box := glass_style(accent, scale)
	box.bg_color = Color(accent.r, accent.g, accent.b, 0.2)
	box.border_color = Color(accent.r, accent.g, accent.b, 0.62)
	box.shadow_size = maxi(0, int(round(14.0 * scale)))
	box.shadow_color = Color(accent.r, accent.g, accent.b, 0.28)
	return box


static func milestone_style(accent: Color, unlocked: bool, scale: float) -> StyleBoxFlat:
	var box := glass_style(accent, scale)
	if unlocked:
		box.bg_color = Color(accent.r, accent.g, accent.b, 0.28)
		box.border_color = Color(accent.r, accent.g, accent.b, 0.85)
	else:
		box.bg_color = Color(1, 1, 1, 0.04)
		box.border_color = Color(1, 1, 1, 0.1)
	return box
