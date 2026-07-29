# ui/overlays/app_overlay_styles.gd
class_name AppOverlayStyles
extends RefCounted

const APP_THEME := preload("res://ui/theme/app_theme.tres")


static func notice_panel() -> StyleBoxFlat:
	var panel := _base_panel()
	panel.border_width_left = 1
	panel.border_width_top = 1
	panel.border_width_right = 1
	panel.border_width_bottom = 1
	panel.border_color = Color(1, 1, 1, 0.14)
	return panel


static func tutorial_panel() -> StyleBoxFlat:
	var panel := _base_panel()
	panel.border_width_left = 1
	panel.border_width_top = 1
	panel.border_width_right = 1
	panel.border_width_bottom = 1
	panel.border_color = Color(1, 1, 1, 0.16)
	return panel


static func tutorial_highlight_panel() -> StyleBoxFlat:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.38, 0.82, 0.62, 0.05)
	panel.border_width_left = 2
	panel.border_width_top = 2
	panel.border_width_right = 2
	panel.border_width_bottom = 2
	panel.border_color = Color(0.38, 0.78, 0.66, 0.72)
	panel.corner_radius_top_left = 10
	panel.corner_radius_top_right = 10
	panel.corner_radius_bottom_right = 10
	panel.corner_radius_bottom_left = 10
	panel.shadow_color = Color(0.28, 0.62, 0.56, 0.16)
	panel.shadow_size = 4
	return panel


static func tutorial_accent_color() -> Color:
	return _accent_color("success")


static func confirm_panel(_variant: String = "warning") -> StyleBoxFlat:
	var panel := _base_panel()
	panel.border_width_left = 1
	panel.border_width_top = 1
	panel.border_width_right = 1
	panel.border_width_bottom = 1
	panel.border_color = Color(1, 1, 1, 0.16)
	return panel


static func accent_color(variant: String = "warning") -> Color:
	return _accent_color(variant)


static func title_color(variant: String = "warning") -> Color:
	return _accent_color(variant).lerp(_palette().text, 0.25)


static func _base_panel() -> StyleBoxFlat:
	var panel := StyleBoxFlat.new()
	panel.content_margin_left = 28.0
	panel.content_margin_top = 22.0
	panel.content_margin_right = 28.0
	panel.content_margin_bottom = 20.0
	panel.bg_color = Color(0.1089, 0.1188, 0.1584, 0.98)
	panel.corner_radius_top_left = 16
	panel.corner_radius_top_right = 16
	panel.corner_radius_bottom_right = 16
	panel.corner_radius_bottom_left = 16
	panel.shadow_size = 10
	panel.shadow_offset = Vector2(0, 4)
	panel.shadow_color = Color(0, 0, 0, 0.36)
	return panel


static func _palette() -> Dictionary:
	var theme: Theme = APP_THEME
	return {
		"text": theme.get_color("font_color", "Label") if theme else Color(0.9, 0.94, 1),
		"border": Color(1, 1, 1, 0.14),
		"primary": theme.get_color("primary", "Palette") if theme else Color(0.42, 0.57, 0.82),
		"danger": theme.get_color("danger", "Palette") if theme else Color(0.92, 0.35, 0.35),
		"warning": theme.get_color("accent_orange", "Palette") if theme else Color(0.95, 0.55, 0.35),
		"info": theme.get_color("accent_sky", "Palette") if theme else Color(0.38, 0.72, 0.95),
		"success": theme.get_color("accent_mint", "Palette") if theme else Color(0.38, 0.82, 0.62),
	}


static func _accent_color(variant: String) -> Color:
	var p := _palette()
	match variant:
		"danger":
			return p.danger
		"info":
			return p.info
		"success":
			return p.success
		"primary":
			return p.primary
		"subtle":
			return p.border
		_:
			return p.warning
