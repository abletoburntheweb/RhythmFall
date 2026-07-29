class_name SongSelectUiStyles
extends RefCounted

static func screen_background_color() -> Color:
	return Color(0.035, 0.045, 0.09, 1.0)


static func overlay_background_color() -> Color:
	return Color(0.02, 0.03, 0.06, 0.78)


static func title_color() -> Color:
	return Color(0.78, 0.86, 0.98, 1.0)


static func subtitle_color() -> Color:
	return Color(0.62, 0.7, 0.82, 0.92)


static func metadata_color() -> Color:
	return Color(0.72, 0.8, 0.92, 0.95)


static func accent_metadata_color() -> Color:
	return Color(0.55, 0.78, 0.98, 1.0)


static func card_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1089, 0.1188, 0.1584, 0.98)
	style.border_color = Color(1, 1, 1, 0.14)
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.shadow_color = Color(0, 0, 0, 0.32)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	style.content_margin_left = 16.0
	style.content_margin_top = 14.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 14.0
	return style


static func row_panel_style(selected: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.2, 0.95) if selected else Color(0.08, 0.09, 0.13, 0.72)
	style.border_color = Color(0.62, 0.48, 0.95, 0.55) if selected else Color(1, 1, 1, 0.06)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 14
	style.content_margin_bottom = 10
	return style


static func top_bar_panel_style() -> StyleBoxFlat:
	var style := card_panel_style()
	style.bg_color = Color(0.09, 0.1, 0.14, 0.92)
	style.set_corner_radius_all(12)
	style.shadow_size = 4
	style.content_margin_left = 12.0
	style.content_margin_top = 10.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 10.0
	return style


static func medal_slot_locked_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.16, 0.22, 0.95)
	style.border_color = Color(1, 1, 1, 0.14)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style


static func medal_slot_earned_style() -> StyleBoxFlat:
	var gold := Color("#F2B35A")
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.97, 0.88, 0.1)
	style.border_color = gold
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(gold.r, gold.g, gold.b, 0.28)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	return style


static func make_setup_btn_box(bg: Color, border: Color, border_w: int = 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_w)
	box.set_corner_radius_all(10)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	return box


static func apply_option_button_style(btn: Button, selected: bool, accent: Color) -> void:
	if btn == null:
		return
	btn.set_meta("ui_keep_style_overrides", true)
	var neutral_bg := Color(0.16, 0.17, 0.23, 0.92)
	var neutral_border := Color(1, 1, 1, 0.2)
	var selected_bg := Color(0.2, 0.19, 0.28, 0.96)
	var selected_border := Color(accent.r, accent.g, accent.b, 0.55)
	var neutral_box := make_setup_btn_box(neutral_bg, neutral_border)
	var neutral_hover := make_setup_btn_box(neutral_bg.lightened(0.06), Color(1, 1, 1, 0.28))
	var selected_box := make_setup_btn_box(selected_bg, selected_border, 2)
	var selected_hover := make_setup_btn_box(selected_bg.lightened(0.05), selected_border.lightened(0.08), 2)
	var resting := selected_box if selected else neutral_box
	var resting_hover := selected_hover if selected else neutral_hover
	btn.add_theme_stylebox_override("normal", resting)
	btn.add_theme_stylebox_override("hover", resting_hover)
	btn.add_theme_stylebox_override("focus", resting_hover)
	btn.add_theme_stylebox_override("pressed", selected_box if selected else neutral_hover)
	btn.add_theme_stylebox_override("hover_pressed", selected_hover)
	var font_idle := Color(0.82, 0.86, 0.94, 1.0)
	var font_sel := Color(0.94, 0.95, 1.0, 1.0)
	btn.add_theme_color_override("font_color", font_sel if selected else font_idle)
	btn.add_theme_color_override("font_hover_color", font_sel)
	btn.add_theme_color_override("font_pressed_color", font_sel)
	btn.add_theme_color_override("font_hover_pressed_color", font_sel)


static func apply_check_row_style(btn: BaseButton) -> void:
	## Stable frame for CheckBox / CheckButton rows. On/off is the switch only —
	## do not reuse option-button "selected" accent borders.
	if btn == null:
		return
	btn.set_meta("ui_keep_style_overrides", true)
	var neutral_bg := Color(0.16, 0.17, 0.23, 0.92)
	var neutral_border := Color(1, 1, 1, 0.2)
	var box := make_setup_btn_box(neutral_bg, neutral_border, 1)
	var hover := make_setup_btn_box(neutral_bg.lightened(0.06), Color(1, 1, 1, 0.28), 1)
	var checked := make_setup_btn_box(neutral_bg.lightened(0.03), neutral_border, 1)
	var checked_hover := make_setup_btn_box(neutral_bg.lightened(0.06), Color(1, 1, 1, 0.28), 1)
	btn.add_theme_stylebox_override("normal", box)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("pressed", checked)
	btn.add_theme_stylebox_override("hover_pressed", checked_hover)
	var font := Color(0.88, 0.91, 0.97, 1.0)
	btn.add_theme_color_override("font_color", font)
	btn.add_theme_color_override("font_hover_color", font)
	btn.add_theme_color_override("font_pressed_color", font)
	btn.add_theme_color_override("font_hover_pressed_color", font)
	btn.add_theme_color_override("font_disabled_color", font.darkened(0.45))


static func style_setup_button(btn: Button, min_height: int = 40, font_size: int = 16) -> void:
	if btn == null:
		return
	btn.custom_minimum_size = Vector2(0, min_height)
	btn.add_theme_font_size_override("font_size", font_size)


static func apply_play_button_style(btn: Button, accent: Color) -> void:
	if btn == null:
		return
	var transparent := Color(0, 0, 0, 0)
	var normal := AppTheme._make_button_box(transparent, accent, false, 2)
	var hover_bg := Color(accent.r, accent.g, accent.b, 0.14).lerp(Color(0.1, 0.12, 0.17, 1.0), 0.58)
	var hover := AppTheme._make_button_box(hover_bg, accent.lightened(0.15), true, 2)
	var pressed_bg := Color(accent.r, accent.g, accent.b, 0.1).lerp(Color(0.06, 0.08, 0.12, 1.0), 0.72)
	var pressed := AppTheme._make_button_box(pressed_bg, accent.darkened(0.12), true, 2)
	var disabled := AppTheme._make_button_box(transparent, accent.darkened(0.5), false, 2)
	var focus := AppTheme._make_button_box(transparent, accent, false, 3)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_stylebox_override("focus", focus)
	var text := Color(0.96, 0.98, 1.0, 1.0)
	btn.add_theme_color_override("font_color", text)
	btn.add_theme_color_override("font_hover_color", text)
	btn.add_theme_color_override("font_pressed_color", text)
	btn.add_theme_color_override("font_disabled_color", text.darkened(0.5))


static func make_row_cover_thumbnail(size_px: int = 56) -> Dictionary:
	var outer := PanelContainer.new()
	outer.custom_minimum_size = Vector2(size_px, size_px)
	outer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.06, 0.09, 1.0)
	box.set_corner_radius_all(8)
	box.set_border_width_all(1)
	box.border_color = Color(1, 1, 1, 0.08)
	box.content_margin_left = 2
	box.content_margin_right = 2
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	outer.add_theme_stylebox_override("panel", box)
	var aspect := AspectRatioContainer.new()
	aspect.ratio = 1.0
	aspect.stretch_mode = AspectRatioContainer.STRETCH_COVER
	aspect.custom_minimum_size = Vector2(size_px - 4, size_px - 4)
	aspect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aspect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(aspect)
	var cover := TextureRect.new()
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cover.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cover.size_flags_vertical = Control.SIZE_EXPAND_FILL
	aspect.add_child(cover)
	UiRoundedClip.apply_cover(outer, cover, 8.0)
	return {"frame": outer, "cover": cover}


static func apply_row_cover_texture(cover: TextureRect, song_path: String, display_px: int) -> void:
	if cover == null:
		return
	var loader := preload("res://scenes/song_select/rhythm_dna/lib/rhythm_dna_cover_loader.gd")
	var path := str(song_path).strip_edges()
	if path == "":
		return
	cover.texture = loader.load_cover_for_display(path, display_px)
