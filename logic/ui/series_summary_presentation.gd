# logic/ui/series_summary_presentation.gd
extends RefCounted
class_name SeriesSummaryPresentation

const _PlayModeIds = preload("res://logic/domain/session/play_mode_ids.gd")
const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")


static func apply(root: Control, mode_id: String) -> void:
	if root == null:
		return
	var accent: Color = _PlayModeIds.accent_for(mode_id)
	_ensure_background(root, accent)
	_style_stats_frame(root, accent)
	_style_title(root, accent)
	_add_hero_icon(root, mode_id, accent)
	_style_buttons(root, accent)
	_play_intro(root)


static func _ensure_background(root: Control, accent: Color) -> void:
	if root.get_node_or_null("SummaryBackground") != null:
		return
	var bg := ColorRect.new()
	bg.name = "SummaryBackground"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.color = Color(0.03, 0.04, 0.07, 1.0)
	root.add_child(bg)
	root.move_child(bg, 0)

	var wash := ColorRect.new()
	wash.name = "SummaryAccentWash"
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wash_col := accent.lerp(Color(0.08, 0.1, 0.16, 1.0), 0.55)
	wash_col.a = 0.22
	wash.color = wash_col
	root.add_child(wash)
	root.move_child(wash, 1)


static func _style_stats_frame(root: Control, accent: Color) -> void:
	var stats := root.find_child("StatsFrame", true, false) as PanelContainer
	if stats == null:
		return
	var box := StyleBoxFlat.new()
	box.bg_color = accent.darkened(0.62)
	box.bg_color.a = 0.42
	box.border_color = accent.lerp(Color.WHITE, 0.18)
	box.set_border_width_all(1)
	box.set_corner_radius_all(16)
	box.content_margin_left = 24
	box.content_margin_right = 24
	box.content_margin_top = 20
	box.content_margin_bottom = 20
	box.shadow_color = accent
	box.shadow_size = 10
	box.shadow_offset = Vector2(2, 4)
	stats.add_theme_stylebox_override("panel", box)


static func _style_title(root: Control, accent: Color) -> void:
	var title := root.find_child("TitleLabel", true, false) as Label
	if title:
		title.add_theme_color_override("font_color", accent.lightened(0.12))
		title.add_theme_font_size_override("font_size", 38)
	var subtitle := root.find_child("SubtitleLabel", true, false) as Label
	if subtitle:
		subtitle.add_theme_color_override("font_color", accent.lerp(Color.WHITE, 0.45))


static func _add_hero_icon(root: Control, mode_id: String, accent: Color) -> void:
	var main_vbox := root.get_node_or_null("MainMargin/MainVBox") as VBoxContainer
	if main_vbox == null:
		return
	var existing := main_vbox.get_node_or_null("HeroIconRow")
	if existing:
		existing.queue_free()
	var hero := HBoxContainer.new()
	hero.name = "HeroIconRow"
	hero.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_theme_constant_override("separation", 12)
	var icon_wrap := PanelContainer.new()
	var icon_box := StyleBoxFlat.new()
	icon_box.bg_color = Color(0.06, 0.08, 0.12, 0.92)
	icon_box.border_color = accent.lerp(Color.WHITE, 0.15)
	icon_box.set_border_width_all(2)
	icon_box.set_corner_radius_all(999)
	icon_box.content_margin_left = 10
	icon_box.content_margin_right = 10
	icon_box.content_margin_top = 10
	icon_box.content_margin_bottom = 10
	icon_wrap.add_theme_stylebox_override("panel", icon_box)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _UiIconHelper.load_tinted_icon(_PlayModeIds.icon_for(mode_id), accent.lightened(0.15), 20)
	icon_wrap.add_child(icon)
	hero.add_child(icon_wrap)
	main_vbox.add_child(hero)
	main_vbox.move_child(hero, 0)


static func _style_buttons(root: Control, accent: Color) -> void:
	for button_name in ["PlayModesButton", "PlayAgainButton", "CatalogButton"]:
		var btn := root.find_child(button_name, true, false) as Button
		if btn == null:
			continue
		btn.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 1.0))
		var normal := StyleBoxFlat.new()
		normal.bg_color = accent.darkened(0.55)
		normal.bg_color.a = 0.85
		normal.border_color = accent.lerp(Color.WHITE, 0.12)
		normal.set_border_width_all(1)
		normal.set_corner_radius_all(12)
		normal.content_margin_top = 10
		normal.content_margin_bottom = 10
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = accent.darkened(0.42)
		hover.bg_color.a = 0.95
		btn.add_theme_stylebox_override("normal", normal)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", hover)
		btn.add_theme_stylebox_override("focus", hover)


static func _play_intro(root: Control) -> void:
	var main_margin := root.get_node_or_null("MainMargin") as Control
	if main_margin == null:
		return
	main_margin.modulate = Color(1, 1, 1, 0)
	main_margin.position.y = 18
	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(main_margin, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(main_margin, "position:y", 0.0, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
