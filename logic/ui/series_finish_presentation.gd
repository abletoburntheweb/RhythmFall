# logic/ui/series_finish_presentation.gd
extends RefCounted
class_name SeriesFinishPresentation

## Victory-like poster cards + mode accent (Endless purple / Marathon copper).

const _PlayModeIds = preload("res://logic/domain/session/play_mode_ids.gd")


static func apply(root: Control, mode_id: String) -> void:
	if root == null:
		return
	var accent: Color = _PlayModeIds.accent_for(mode_id)
	var first: bool = not bool(root.get_meta(&"series_finish_styled", false))
	_ensure_background(root, accent)
	_style_panels(root, accent)
	_style_title(root, accent)
	_style_buttons(root, accent)
	if first:
		root.set_meta(&"series_finish_styled", true)
		_play_intro(root)


static func make_accent_card(accent: Color, border_alpha: float = 0.42) -> StyleBoxFlat:
	var card := StyleBoxFlat.new()
	card.bg_color = Color(0.108, 0.118, 0.158, 0.96)
	card.border_color = Color(accent.r, accent.g, accent.b, border_alpha)
	card.set_border_width_all(1)
	card.set_corner_radius_all(14)
	card.corner_detail = 12
	card.set_content_margin_all(12)
	card.shadow_color = Color(0, 0, 0, 0.28)
	card.shadow_size = 6
	card.shadow_offset = Vector2(0, 2)
	return card


static func make_poster_frame(accent: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.108, 0.118, 0.158, 0.96)
	box.border_color = Color(accent.r, accent.g, accent.b, 0.55)
	box.set_border_width_all(1)
	box.set_corner_radius_all(14)
	box.set_content_margin_all(6)
	box.shadow_color = Color(accent.r, accent.g, accent.b, 0.18)
	box.shadow_size = 10
	return box


## Value colors matched to library victory_screen tiles.
const STAT_VALUE_COLORS := {
	"ScoreTile": Color(0.584314, 0.717647, 0.921569, 1.0),
	"ComboTile": Color(0.584314, 0.717647, 0.921569, 1.0),
	"MaxComboTile": Color(0.647059, 0.556863, 0.858824, 1.0),
	"AccuracyTile": Color(0.34902, 0.819608, 0.745098, 1.0),
	"PerfectTile": Color(0.95, 0.82, 0.42, 1.0),
	"GoodTile": Color(0.45, 0.82, 0.92, 1.0),
	"MissTile": Color(0.882353, 0.415686, 0.466667, 1.0),
}

const STAT_ICONS := {
	"ScoreTile": "hash.svg",
	"ComboTile": "zap.svg",
	"MaxComboTile": "sparkles.svg",
	"AccuracyTile": "crosshair.svg",
	"PerfectTile": "star.svg",
	"GoodTile": "circle-check.svg",
	"MissTile": "ban.svg",
}


static func style_stat_tile(panel: PanelContainer, accent: Color) -> void:
	if panel == null:
		return
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.08, 0.11, 0.72)
	box.border_color = Color(1, 1, 1, 0.05)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", box)
	var value_color: Color = STAT_VALUE_COLORS.get(panel.name, accent.lerp(Color(0.85, 0.9, 1.0), 0.35))
	var caption_color := Color(value_color.r, value_color.g, value_color.b, 0.72)
	for child in panel.find_children("*", "Label", true, false):
		var lbl := child as Label
		if lbl == null:
			continue
		if lbl.name == "Cap" or lbl.name == "CaptionLabel":
			lbl.add_theme_color_override("font_color", caption_color)
		elif lbl.name.ends_with("Value"):
			lbl.add_theme_color_override("font_color", value_color)


static func _ensure_background(root: Control, accent: Color) -> void:
	# Keep screen transparent so GameEngine AmbientBackground (wash circles + dots) shows through,
	# matching victory_screen's Color(0,0,0,0) background.
	var wash_col := accent.lerp(Color(0.08, 0.1, 0.16, 1.0), 0.55)
	wash_col.a = 0.10
	var existing_bg := root.get_node_or_null("SummaryBackground") as ColorRect
	if existing_bg:
		existing_bg.color = Color(0, 0, 0, 0)
	var existing_wash := root.get_node_or_null("SummaryAccentWash") as ColorRect
	if existing_wash:
		existing_wash.color = wash_col
	if existing_bg != null:
		return
	var bg := ColorRect.new()
	bg.name = "SummaryBackground"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.color = Color(0, 0, 0, 0)
	root.add_child(bg)
	root.move_child(bg, 0)

	var wash := ColorRect.new()
	wash.name = "SummaryAccentWash"
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash.color = wash_col
	root.add_child(wash)
	root.move_child(wash, 1)


static func _style_panels(root: Control, accent: Color) -> void:
	var chart_accent := accent.lerp(Color(0.45, 0.68, 0.95), 0.35)
	var specs: Array = [
		["RewardsPanel", accent, 0.42],
		["ChartPanel", chart_accent, 0.38],
		["StatsPanel", Color(1, 1, 1, 0.14), 0.14],
		["LaneStatsPanel", Color(1, 1, 1, 0.14), 0.14],
		["RouteBadgesPanel", accent, 0.4],
		["HeroFrame", accent, 0.55],
		["TopStat0", accent, 0.28],
		["TopStat1", accent, 0.28],
	]
	for spec in specs:
		var panel := root.find_child(String(spec[0]), true, false) as PanelContainer
		if panel == null:
			continue
		var name := String(spec[0])
		if name == "HeroFrame":
			panel.add_theme_stylebox_override("panel", make_poster_frame(accent))
		elif name.begins_with("TopStat"):
			panel.add_theme_stylebox_override("panel", make_accent_card(accent, float(spec[2])))
		else:
			panel.add_theme_stylebox_override("panel", make_accent_card(spec[1] as Color, float(spec[2])))
	for name in [
		"ScoreTile",
		"ComboTile",
		"MaxComboTile",
		"AccuracyTile",
		"PerfectTile",
		"GoodTile",
		"MissTile",
	]:
		var tile := root.find_child(name, true, false) as PanelContainer
		style_stat_tile(tile, accent)


static func _style_title(root: Control, accent: Color) -> void:
	var title := root.find_child("TitleLabel", true, false) as Label
	if title:
		title.add_theme_color_override("font_color", accent.lightened(0.08))
		title.add_theme_font_size_override("font_size", 36)
	var subtitle := root.find_child("SubtitleLabel", true, false) as Label
	if subtitle:
		subtitle.add_theme_color_override("font_color", Color(0.72, 0.78, 0.88, 0.95))


static func _style_buttons(root: Control, accent: Color) -> void:
	for button_name in ["BackButton", "PlayAgainButton", "SecondaryButton"]:
		var btn := root.find_child(button_name, true, false) as Button
		if btn == null:
			continue
		_apply_button_style(btn, accent, button_name == "PlayAgainButton")


static func _apply_button_style(btn: Button, accent: Color, primary: bool) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		if primary:
			box.bg_color = Color(0.08, 0.1, 0.14, 0.95)
			if state == "hover":
				box.bg_color = Color(0.1, 0.12, 0.17, 0.98)
			box.border_color = accent.lerp(Color.WHITE, 0.12 if state == "hover" else 0.0)
			box.set_border_width_all(2)
		else:
			box.bg_color = Color(0.08, 0.1, 0.14, 0.9)
			box.border_color = Color(accent.r, accent.g, accent.b, 0.45)
			box.set_border_width_all(1)
		box.set_corner_radius_all(12)
		box.content_margin_left = 16
		box.content_margin_right = 16
		box.content_margin_top = 10
		box.content_margin_bottom = 10
		btn.add_theme_stylebox_override(state, box)
	btn.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0, 1.0))


static func _play_intro(root: Control) -> void:
	var margin := root.get_node_or_null("MainMargin") as Control
	if margin == null:
		return
	margin.modulate.a = 0.0
	margin.position.y = 18.0
	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(margin, "modulate:a", 1.0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(margin, "position:y", 0.0, 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
