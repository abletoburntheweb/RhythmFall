extends Object
class_name AppTheme

static func _make_button_box(bg: Color, border_col: Color, draw_center := true, border_w := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.draw_center = draw_center
	sb.border_color = border_col
	sb.border_width_top = border_w
	sb.border_width_right = border_w
	sb.border_width_bottom = border_w
	sb.border_width_left = border_w
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_right = 10
	sb.corner_radius_bottom_left = 10
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 2)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

static func build_theme() -> Theme:
	var theme := Theme.new()
	var blue := Color(0.42, 0.57, 0.82, 1.0)
	var blue_hover := blue.lightened(0.1)
	var blue_pressed := blue.darkened(0.1)
	var outline := Color(1, 1, 1, 0.85)
	var text := Color(1, 1, 1, 1)
	var transparent := Color(0, 0, 0, 0)

	var btn_outline_normal := _make_button_box(transparent, outline, false, 2)
	var btn_outline_hover := _make_button_box(transparent, outline.lightened(0.2), false, 2)
	var btn_outline_pressed := _make_button_box(transparent, outline.darkened(0.2), true, 2)
	var btn_outline_disabled := _make_button_box(transparent, outline.darkened(0.5), false, 2)
	var btn_outline_focus := _make_button_box(transparent, outline, false, 3)

	theme.set_stylebox("normal", "Button", btn_outline_normal)
	theme.set_stylebox("hover", "Button", btn_outline_hover)
	theme.set_stylebox("pressed", "Button", btn_outline_pressed)
	theme.set_stylebox("disabled", "Button", btn_outline_disabled)
	theme.set_stylebox("focus", "Button", btn_outline_focus)
	theme.set_color("font_color", "Button", text)
	theme.set_color("font_hover_color", "Button", text)
	theme.set_color("font_pressed_color", "Button", text)
	theme.set_color("font_disabled_color", "Button", text.darkened(0.5))

	theme.set_type_variation("Primary", "Button")
	var btn_primary_normal := _make_button_box(blue, Color(0, 0, 0, 0), true, 0)
	var btn_primary_hover := _make_button_box(blue.lightened(0.1), Color(0, 0, 0, 0), true, 0)
	var btn_primary_pressed := _make_button_box(blue.darkened(0.1), Color(0, 0, 0, 0), true, 0)
	var btn_primary_disabled := _make_button_box(blue.darkened(0.25), Color(0, 0, 0, 0), true, 0)
	var btn_primary_focus := _make_button_box(blue, outline, true, 2)
	theme.set_stylebox("normal", "Primary", btn_primary_normal)
	theme.set_stylebox("hover", "Primary", btn_primary_hover)
	theme.set_stylebox("pressed", "Primary", btn_primary_pressed)
	theme.set_stylebox("disabled", "Primary", btn_primary_disabled)
	theme.set_stylebox("focus", "Primary", btn_primary_focus)
	theme.set_color("font_color", "Primary", text)
	theme.set_color("font_hover_color", "Primary", text)
	theme.set_color("font_pressed_color", "Primary", text)
	theme.set_color("font_disabled_color", "Primary", text.darkened(0.5))

	theme.set_type_variation("Secondary", "Button")
	var gray := Color(0.27, 0.32, 0.40, 1.0)
	var btn_secondary_normal := _make_button_box(gray, Color(0, 0, 0, 0), true, 0)
	var btn_secondary_hover := _make_button_box(gray.lightened(0.06), Color(0, 0, 0, 0), true, 0)
	var btn_secondary_pressed := _make_button_box(gray.darkened(0.08), Color(0, 0, 0, 0), true, 0)
	var btn_secondary_disabled := _make_button_box(gray.darkened(0.25), Color(0, 0, 0, 0), true, 0)
	var btn_secondary_focus := _make_button_box(gray, outline, true, 2)
	theme.set_stylebox("normal", "Secondary", btn_secondary_normal)
	theme.set_stylebox("hover", "Secondary", btn_secondary_hover)
	theme.set_stylebox("pressed", "Secondary", btn_secondary_pressed)
	theme.set_stylebox("disabled", "Secondary", btn_secondary_disabled)
	theme.set_stylebox("focus", "Secondary", btn_secondary_focus)
	theme.set_color("font_color", "Secondary", text)
	theme.set_color("font_hover_color", "Secondary", text)
	theme.set_color("font_pressed_color", "Secondary", text)
	theme.set_color("font_disabled_color", "Secondary", text.darkened(0.5))

	theme.set_type_variation("Danger", "Button")
	var red := Color(0.85, 0.30, 0.34, 1.0)
	var btn_danger_normal := _make_button_box(red, Color(0, 0, 0, 0), true, 0)
	var btn_danger_hover := _make_button_box(red.lightened(0.06), Color(0, 0, 0, 0), true, 0)
	var btn_danger_pressed := _make_button_box(red.darkened(0.08), Color(0, 0, 0, 0), true, 0)
	var btn_danger_disabled := _make_button_box(red.darkened(0.25), Color(0, 0, 0, 0), true, 0)
	var btn_danger_focus := _make_button_box(red, outline, true, 2)
	theme.set_stylebox("normal", "Danger", btn_danger_normal)
	theme.set_stylebox("hover", "Danger", btn_danger_hover)
	theme.set_stylebox("pressed", "Danger", btn_danger_pressed)
	theme.set_stylebox("disabled", "Danger", btn_danger_disabled)
	theme.set_stylebox("focus", "Danger", btn_danger_focus)
	theme.set_color("font_color", "Danger", text)
	theme.set_color("font_hover_color", "Danger", text)
	theme.set_color("font_pressed_color", "Danger", text)
	theme.set_color("font_disabled_color", "Danger", text.darkened(0.5))

	var slider_box := StyleBoxFlat.new()
	slider_box.bg_color = Color(0.18, 0.2, 0.26, 1.0)
	slider_box.corner_radius_top_left = 6
	slider_box.corner_radius_top_right = 6
	slider_box.corner_radius_bottom_right = 6
	slider_box.corner_radius_bottom_left = 6
	slider_box.content_margin_top = 6
	slider_box.content_margin_bottom = 6

	var grabber_area := StyleBoxFlat.new()
	grabber_area.bg_color = Color(0, 0, 0, 0.0)
	grabber_area.content_margin_top = 6
	grabber_area.content_margin_bottom = 6

	theme.set_stylebox("slider", "HSlider", slider_box)
	theme.set_stylebox("grabber_area", "HSlider", grabber_area)

	var le_normal := StyleBoxFlat.new()
	le_normal.bg_color = Color(0.12, 0.13, 0.17, 1.0)
	le_normal.border_color = Color(1, 1, 1, 0.18)
	le_normal.border_width_left = 1
	le_normal.border_width_right = 1
	le_normal.border_width_top = 1
	le_normal.border_width_bottom = 1
	le_normal.corner_radius_top_left = 10
	le_normal.corner_radius_top_right = 10
	le_normal.corner_radius_bottom_right = 10
	le_normal.corner_radius_bottom_left = 10
	le_normal.content_margin_left = 12
	le_normal.content_margin_right = 12
	le_normal.content_margin_top = 8
	le_normal.content_margin_bottom = 8

	var le_focus := le_normal.duplicate()
	le_focus.border_color = blue
	le_focus.border_width_left = 2
	le_focus.border_width_right = 2
	le_focus.border_width_top = 2
	le_focus.border_width_bottom = 2

	theme.set_stylebox("normal", "LineEdit", le_normal)
	theme.set_stylebox("focus", "LineEdit", le_focus)
	theme.set_color("font_color", "LineEdit", Color(0.92, 0.92, 0.94, 1.0))
	theme.set_color("font_placeholder_color", "LineEdit", Color(0.65, 0.68, 0.75, 1.0))
	theme.set_color("caret_color", "LineEdit", Color(0.95, 0.95, 0.95, 1.0))
	theme.set_color("clear_button_color", "LineEdit", Color(0.8, 0.85, 0.95, 1.0))
	theme.set_color("clear_button_color_pressed", "LineEdit", Color(1, 1, 1, 1.0))

	theme.set_type_variation("SearchField", "LineEdit")
	var sf_normal := le_normal.duplicate()
	sf_normal.bg_color = Color(0.14, 0.16, 0.22, 1.0)
	var sf_focus := le_focus.duplicate()
	theme.set_stylebox("normal", "SearchField", sf_normal)
	theme.set_stylebox("focus", "SearchField", sf_focus)
	theme.set_color("font_color", "SearchField", Color(0.95, 0.95, 0.98, 1.0))
	theme.set_color("font_placeholder_color", "SearchField", Color(0.7, 0.74, 0.8, 1.0))
	theme.set_color("caret_color", "SearchField", Color(1, 1, 1, 1.0))
	
	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.12, 0.13, 0.17, 1.0)
	pb_bg.corner_radius_top_left = 8
	pb_bg.corner_radius_top_right = 8
	pb_bg.corner_radius_bottom_right = 8
	pb_bg.corner_radius_bottom_left = 8
	pb_bg.content_margin_top = 6
	pb_bg.content_margin_bottom = 6
	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = blue
	pb_fill.corner_radius_top_left = 8
	pb_fill.corner_radius_top_right = 8
	pb_fill.corner_radius_bottom_right = 8
	pb_fill.corner_radius_bottom_left = 8
	theme.set_stylebox("background", "ProgressBar", pb_bg)
	theme.set_stylebox("fill", "ProgressBar", pb_fill)
	theme.set_color("font_color", "ProgressBar", Color.WHITE)
	theme.set_color("font_outline_color", "ProgressBar", Color(0, 0, 0, 0.8))
	theme.set_constant("outline_size", "ProgressBar", 0)

	theme.set_type_variation("LevelLabel", "Label")
	theme.set_color("font_color", "LevelLabel", Color(0.85, 0.9, 1.0, 1.0))
	theme.set_type_variation("XPAmountLabel", "Label")
	theme.set_color("font_color", "XPAmountLabel", Color(0.9, 0.95, 1.0, 1.0))

	theme.add_type("ChartPoint")
	theme.set_color("point_color", "ChartPoint", Color(0.6, 0.8, 1.0, 1.0))
	theme.set_color("border_color", "ChartPoint", Color(0, 0, 0, 1.0))
	theme.set_constant("point_radius", "ChartPoint", 6)
	theme.set_constant("border_width", "ChartPoint", 2)

	var card_base := StyleBoxFlat.new()
	card_base.bg_color = Color(0.11, 0.12, 0.16, 1.0)
	card_base.border_color = Color(1, 1, 1, 0.22)
	card_base.border_width_left = 1
	card_base.border_width_right = 1
	card_base.border_width_top = 1
	card_base.border_width_bottom = 1
	card_base.corner_radius_top_left = 12
	card_base.corner_radius_top_right = 12
	card_base.corner_radius_bottom_right = 12
	card_base.corner_radius_bottom_left = 12
	card_base.shadow_color = Color(0, 0, 0, 0.35)
	card_base.shadow_size = 8
	card_base.shadow_offset = Vector2(0, 3)

	theme.set_stylebox("panel", "PanelContainer", card_base)

	theme.set_type_variation("CardDefault", "PanelContainer")
	var card_default := card_base.duplicate()
	theme.set_stylebox("panel", "CardDefault", card_default)

	theme.set_type_variation("CardActive", "PanelContainer")
	var card_active := card_base.duplicate()
	card_active.border_color = blue
	card_active.border_width_left = 2
	card_active.border_width_right = 2
	card_active.border_width_top = 2
	card_active.border_width_bottom = 2
	theme.set_stylebox("panel", "CardActive", card_active)

	theme.set_type_variation("CardLocked", "PanelContainer")
	var card_locked := card_base.duplicate()
	card_locked.bg_color = card_base.bg_color.darkened(0.15)
	card_locked.border_color = Color(1, 1, 1, 0.12)
	theme.set_stylebox("panel", "CardLocked", card_locked)

	var opt_normal := _make_button_box(transparent, outline, true, 1)
	opt_normal.content_margin_left = 12
	opt_normal.content_margin_right = 12
	opt_normal.content_margin_top = 8
	opt_normal.content_margin_bottom = 8
	var opt_hover := opt_normal.duplicate()
	opt_hover.border_color = outline.lightened(0.2)
	var opt_pressed := _make_button_box(transparent, outline.darkened(0.2), true, 1)
	var opt_disabled := _make_button_box(transparent, outline.darkened(0.5), true, 1)
	var opt_focus := opt_normal.duplicate()
	opt_focus.border_width_left = 2
	opt_focus.border_width_right = 2
	opt_focus.border_width_top = 2
	opt_focus.border_width_bottom = 2
	theme.set_stylebox("normal", "OptionButton", opt_normal)
	theme.set_stylebox("hover", "OptionButton", opt_hover)
	theme.set_stylebox("pressed", "OptionButton", opt_pressed)
	theme.set_stylebox("disabled", "OptionButton", opt_disabled)
	theme.set_stylebox("focus", "OptionButton", opt_focus)
	theme.set_color("font_color", "OptionButton", text)
	theme.set_color("font_hover_color", "OptionButton", text)
	theme.set_color("font_pressed_color", "OptionButton", text)
	theme.set_color("font_disabled_color", "OptionButton", text.darkened(0.5))


	var v_track := StyleBoxFlat.new()
	v_track.bg_color = Color(0.12, 0.13, 0.17, 1.0)
	v_track.corner_radius_top_left = 8
	v_track.corner_radius_top_right = 8
	v_track.corner_radius_bottom_right = 8
	v_track.corner_radius_bottom_left = 8
	v_track.content_margin_left = 12
	v_track.content_margin_right = 12
	var v_grabber := StyleBoxFlat.new()
	v_grabber.bg_color = Color(0.30, 0.34, 0.44, 1.0)
	v_grabber.corner_radius_top_left = 8
	v_grabber.corner_radius_top_right = 8
	v_grabber.corner_radius_bottom_right = 8
	v_grabber.corner_radius_bottom_left = 8
	var v_grabber_high := v_grabber.duplicate()
	v_grabber_high.bg_color = v_grabber.bg_color.lightened(0.12)
	var v_grabber_pressed := v_grabber.duplicate()
	v_grabber_pressed.bg_color = v_grabber.bg_color.darkened(0.12)
	theme.set_stylebox("scroll", "VScrollBar", v_track)
	theme.set_stylebox("scroll_focus", "VScrollBar", v_track)
	theme.set_stylebox("grabber", "VScrollBar", v_grabber)
	theme.set_stylebox("grabber_highlight", "VScrollBar", v_grabber_high)
	theme.set_stylebox("grabber_pressed", "VScrollBar", v_grabber_pressed)

	var h_track := StyleBoxFlat.new()
	h_track.bg_color = Color(0.12, 0.13, 0.17, 1.0)
	h_track.corner_radius_top_left = 8
	h_track.corner_radius_top_right = 8
	h_track.corner_radius_bottom_right = 8
	h_track.corner_radius_bottom_left = 8
	h_track.content_margin_top = 12
	h_track.content_margin_bottom = 12
	var h_grabber := StyleBoxFlat.new()
	h_grabber.bg_color = Color(0.30, 0.34, 0.44, 1.0)
	h_grabber.corner_radius_top_left = 8
	h_grabber.corner_radius_top_right = 8
	h_grabber.corner_radius_bottom_right = 8
	h_grabber.corner_radius_bottom_left = 8
	var h_grabber_high := h_grabber.duplicate()
	h_grabber_high.bg_color = h_grabber.bg_color.lightened(0.12)
	var h_grabber_pressed := h_grabber.duplicate()
	h_grabber_pressed.bg_color = h_grabber.bg_color.darkened(0.12)
	theme.set_stylebox("scroll", "HScrollBar", h_track)
	theme.set_stylebox("scroll_focus", "HScrollBar", h_track)
	theme.set_stylebox("grabber", "HScrollBar", h_grabber)
	theme.set_stylebox("grabber_highlight", "HScrollBar", h_grabber_high)
	theme.set_stylebox("grabber_pressed", "HScrollBar", h_grabber_pressed)

	var pm_panel := StyleBoxFlat.new()
	pm_panel.bg_color = Color(0.10, 0.11, 0.15, 1.0)
	pm_panel.corner_radius_top_left = 10
	pm_panel.corner_radius_top_right = 10
	pm_panel.corner_radius_bottom_right = 10
	pm_panel.corner_radius_bottom_left = 10
	pm_panel.border_color = Color(1, 1, 1, 0.18)
	pm_panel.border_width_left = 1
	pm_panel.border_width_right = 1
	pm_panel.border_width_top = 1
	pm_panel.border_width_bottom = 1
	var pm_hover := StyleBoxFlat.new()
	pm_hover.bg_color = Color(0.18, 0.20, 0.26, 1.0)
	pm_hover.corner_radius_top_left = 6
	pm_hover.corner_radius_top_right = 6
	pm_hover.corner_radius_bottom_right = 6
	pm_hover.corner_radius_bottom_left = 6
	var pm_sep := StyleBoxFlat.new()
	pm_sep.bg_color = Color(1, 1, 1, 0.12)
	pm_sep.content_margin_top = 1
	pm_sep.content_margin_bottom = 1
	theme.set_stylebox("panel", "PopupMenu", pm_panel)
	theme.set_stylebox("hover", "PopupMenu", pm_hover)
	theme.set_stylebox("separator", "PopupMenu", pm_sep)
	theme.set_color("font_color", "PopupMenu", Color(0.92, 0.94, 0.98, 1.0))
	theme.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	theme.set_color("font_disabled_color", "PopupMenu", Color(0.7, 0.72, 0.78, 1.0))
	theme.set_color("font_accelerator_color", "PopupMenu", Color(0.7, 0.74, 0.8, 0.9))

	var il_panel := StyleBoxFlat.new()
	il_panel.bg_color = Color(0.10, 0.11, 0.15, 1.0)
	il_panel.corner_radius_top_left = 10
	il_panel.corner_radius_top_right = 10
	il_panel.corner_radius_bottom_right = 10
	il_panel.corner_radius_bottom_left = 10
	il_panel.border_color = Color(1, 1, 1, 0.14)
	il_panel.border_width_left = 1
	il_panel.border_width_right = 1
	il_panel.border_width_top = 1
	il_panel.border_width_bottom = 1
	var il_hovered := il_panel.duplicate()
	il_hovered.bg_color = il_panel.bg_color.lightened(0.04)
	var il_selected := il_panel.duplicate()
	il_selected.bg_color = Color(0.18, 0.20, 0.26, 1.0)
	il_selected.border_color = blue
	il_selected.border_width_left = 2
	il_selected.border_width_right = 2
	il_selected.border_width_top = 2
	il_selected.border_width_bottom = 2
	var il_selected_focus := il_selected.duplicate()
	var il_cursor := StyleBoxFlat.new()
	il_cursor.bg_color = Color(1, 1, 1, 0.08)
	il_cursor.corner_radius_top_left = 6
	il_cursor.corner_radius_top_right = 6
	il_cursor.corner_radius_bottom_right = 6
	il_cursor.corner_radius_bottom_left = 6
	theme.set_stylebox("panel", "ItemList", il_panel)
	theme.set_stylebox("hovered", "ItemList", il_hovered)
	theme.set_stylebox("selected", "ItemList", il_selected)
	theme.set_stylebox("selected_focus", "ItemList", il_selected_focus)
	theme.set_stylebox("cursor", "ItemList", il_cursor)
	theme.set_stylebox("cursor_unfocused", "ItemList", il_cursor)
	theme.set_color("font_color", "ItemList", Color(0.92, 0.94, 0.98, 1.0))
	theme.set_color("font_hovered_color", "ItemList", Color.WHITE)
	theme.set_color("font_selected_color", "ItemList", Color.WHITE)
	theme.set_color("font_hovered_selected_color", "ItemList", Color.WHITE)

	var cb_normal := _make_button_box(transparent, Color(0, 0, 0, 0), true, 0)
	cb_normal.content_margin_left = 8
	cb_normal.content_margin_right = 8
	cb_normal.content_margin_top = 4
	cb_normal.content_margin_bottom = 4
	var cb_hover := cb_normal.duplicate()
	cb_hover.bg_color = Color(1, 1, 1, 0.06)
	var cb_pressed := cb_normal.duplicate()
	cb_pressed.bg_color = Color(1, 1, 1, 0.1)
	var cb_disabled := cb_normal.duplicate()
	cb_disabled.bg_color = Color(1, 1, 1, 0.02)
	var cb_focus := cb_normal.duplicate()
	cb_focus.border_color = blue
	cb_focus.border_width_left = 2
	cb_focus.border_width_right = 2
	cb_focus.border_width_top = 2
	cb_focus.border_width_bottom = 2
	theme.set_stylebox("normal", "CheckBox", cb_normal)
	theme.set_stylebox("hover", "CheckBox", cb_hover)
	theme.set_stylebox("pressed", "CheckBox", cb_pressed)
	theme.set_stylebox("disabled", "CheckBox", cb_disabled)
	theme.set_stylebox("focus", "CheckBox", cb_focus)
	theme.set_color("font_color", "CheckBox", text)
	theme.set_color("font_hover_color", "CheckBox", text)
	theme.set_color("font_pressed_color", "CheckBox", text)
	theme.set_color("font_disabled_color", "CheckBox", text.darkened(0.5))
	theme.set_color("checkbox_checked_color", "CheckBox", blue)
	theme.set_color("checkbox_unchecked_color", "CheckBox", Color(0.75, 0.80, 0.90, 1.0))

	return theme
