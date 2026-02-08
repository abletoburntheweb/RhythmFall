extends Object
class_name GameTheme

static func build_theme() -> Theme:
	var theme := Theme.new()
	var blue := Color(0.42, 0.57, 0.82, 1.0)
	var text := Color(0.96, 0.97, 1.0, 1.0)
	var subtle := Color(0.85, 0.88, 0.95, 1.0)

	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.12, 0.13, 0.17, 1.0)
	pb_bg.corner_radius_top_left = 8
	pb_bg.corner_radius_top_right = 8
	pb_bg.corner_radius_bottom_right = 8
	pb_bg.corner_radius_bottom_left = 8
	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = blue
	pb_fill.corner_radius_top_left = 8
	pb_fill.corner_radius_top_right = 8
	pb_fill.corner_radius_bottom_right = 8
	pb_fill.corner_radius_bottom_left = 8
	theme.set_stylebox("background", "ProgressBar", pb_bg)
	theme.set_stylebox("fill", "ProgressBar", pb_fill)
	theme.set_color("font_color", "ProgressBar", text)

	theme.set_color("font_color", "Label", subtle)

	theme.set_type_variation("StatLabel", "Label")
	theme.set_color("font_color", "StatLabel", subtle)

	theme.set_type_variation("ScoreLabel", "Label")
	theme.set_color("font_color", "ScoreLabel", text)

	theme.set_type_variation("ComboLabel", "Label")
	theme.set_color("font_color", "ComboLabel", blue.lightened(0.1))

	theme.set_type_variation("JudgementLabel", "Label")
	theme.set_color("font_color", "JudgementLabel", Color(0.95, 0.95, 0.98, 1.0))
	theme.set_color("font_outline_color", "JudgementLabel", Color(0, 0, 0, 0.6))
	theme.set_constant("outline_size", "JudgementLabel", 1)

	theme.set_type_variation("CountdownLabel", "Label")
	theme.set_color("font_color", "CountdownLabel", Color(1, 1, 1, 1.0))
	theme.set_color("font_outline_color", "CountdownLabel", Color(0, 0, 0, 0.7))
	theme.set_constant("outline_size", "CountdownLabel", 2)
	
	theme.set_type_variation("GameNote", "Panel")
	var note_panel := StyleBoxFlat.new()
	note_panel.bg_color = Color(0.18, 0.2, 0.26, 1.0)
	note_panel.corner_radius_top_left = 8
	note_panel.corner_radius_top_right = 8
	note_panel.corner_radius_bottom_right = 8
	note_panel.corner_radius_bottom_left = 8
	note_panel.shadow_color = Color(0, 0, 0, 0.25)
	note_panel.shadow_size = 6
	note_panel.shadow_offset = Vector2(0, 2)
	theme.set_stylebox("panel", "GameNote", note_panel)
	
	theme.set_type_variation("GameHoldNote", "Panel")
	var hold_panel := note_panel.duplicate()
	hold_panel.bg_color = Color(0.16, 0.18, 0.24, 1.0)
	theme.set_stylebox("panel", "GameHoldNote", hold_panel)
	
	theme.set_type_variation("HitZone", "Panel")
	var hit_panel := StyleBoxFlat.new()
	hit_panel.bg_color = Color(0.95, 0.8, 0.85, 1.0)
	hit_panel.corner_radius_top_left = 4
	hit_panel.corner_radius_top_right = 4
	hit_panel.corner_radius_bottom_right = 4
	hit_panel.corner_radius_bottom_left = 4
	theme.set_stylebox("panel", "HitZone", hit_panel)

	return theme
