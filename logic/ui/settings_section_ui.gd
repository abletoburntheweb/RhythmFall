# logic/utils/settings_section_ui.gd
extends RefCounted
class_name SettingsSectionUi

const MUTED_TEXT := Color(0.58, 0.66, 0.78, 0.92)
const TITLE_TEXT := Color(0.88, 0.92, 0.96, 1.0)


static func nest_section_header(header: Label, panel: PanelContainer, icon_file: String, icon_tint: Color) -> void:
	if header == null or panel == null:
		return
	if header.get_meta("settings_nested_header", false):
		return
	var margin := panel.get_child(0) as MarginContainer
	if margin == null:
		return
	var parent := header.get_parent()
	if parent:
		parent.remove_child(header)
	margin.add_child(header)
	margin.move_child(header, 0)
	header.add_theme_font_size_override("font_size", 22)
	if icon_file.strip_edges() != "":
		UiIconHelper.add_icon_before_label(header, icon_file, false, icon_tint)
	header.set_meta("settings_nested_header", true)


static func make_inner_card(panel_variation: StringName = &"SectionPanelTeal") -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.theme_type_variation = panel_variation
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)
	card.set_meta("inner_margin", margin)
	return card


static func enhance_volume_row(
	row: HBoxContainer,
	icon_file: String,
	icon_tint: Color,
	name_label: Label,
	slider: HSlider
) -> Label:
	if row == null or row.get_meta("settings_volume_row_enhanced", false):
		return row.get_node_or_null("PercentLabel") as Label if row else null

	var pct := Label.new()
	pct.name = &"PercentLabel"
	pct.custom_minimum_size = Vector2(52, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pct.add_theme_font_size_override("font_size", 17)
	pct.add_theme_color_override("font_color", icon_tint.lightened(0.15))

	var frame := UiIconHelper.make_icon_frame(icon_file, 32, 16, icon_tint)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	name_label.custom_minimum_size.x = 148.0
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_label.add_theme_font_size_override("font_size", 17)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(120, 28)

	row.add_theme_constant_override("separation", 10)
	row.add_child(frame)
	row.move_child(frame, 0)
	row.add_child(pct)
	row.set_meta("settings_volume_row_enhanced", true)
	return pct


static func make_setting_block(title: String, description: String, control: Control) -> VBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 6)
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 17)
	title_lbl.add_theme_color_override("font_color", TITLE_TEXT)
	block.add_child(title_lbl)

	if description.strip_edges() != "":
		var desc_lbl := Label.new()
		desc_lbl.text = description
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 14)
		desc_lbl.add_theme_color_override("font_color", MUTED_TEXT)
		block.add_child(desc_lbl)

	if control:
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		block.add_child(control)
	return block


static func apply_settings_checkbox(checkbox: CheckBox, font_size: int = 22, compact: bool = false) -> void:
	if checkbox == null:
		return
	checkbox.theme_type_variation = &"SettingsCheckBoxCompact" if compact else &"SettingsCheckBox"
	checkbox.add_theme_font_size_override("font_size", font_size)
	checkbox.add_theme_constant_override("h_separation", 10 if compact else 12)
	if not compact:
		checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Force stable frame overrides so on/off never lose the border even when a
	# Control embeds a stale app_theme.tres (theme_type_variation alone is not enough).
	_apply_stable_check_frame(checkbox, compact)


static func _apply_stable_check_frame(checkbox: CheckBox, compact: bool) -> void:
	var border := Color(1, 1, 1, 0.22)
	var focus_border := Color(0.42, 0.57, 0.82, 1.0)
	var pad_h := 8.0 if compact else 12.0
	var pad_v := 4.0 if compact else 10.0
	var normal := AppTheme._make_button_box(Color(1, 1, 1, 0.04), border, true, 1)
	normal.shadow_size = 0
	normal.content_margin_left = pad_h
	normal.content_margin_right = pad_h
	normal.content_margin_top = pad_v
	normal.content_margin_bottom = pad_v
	normal.set_corner_radius_all(10)
	var hover := normal.duplicate()
	hover.bg_color = Color(1, 1, 1, 0.08)
	hover.border_color = border.lightened(0.08)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(1, 1, 1, 0.1)
	pressed.border_color = border
	var hover_pressed := pressed.duplicate()
	hover_pressed.bg_color = hover.bg_color
	hover_pressed.border_color = hover.border_color
	var disabled := normal.duplicate()
	disabled.bg_color = Color(1, 1, 1, 0.02)
	disabled.border_color = border.darkened(0.25)
	var focus := normal.duplicate()
	focus.border_color = focus_border
	focus.set_border_width_all(1)
	checkbox.add_theme_stylebox_override("normal", normal)
	checkbox.add_theme_stylebox_override("hover", hover)
	checkbox.add_theme_stylebox_override("pressed", pressed)
	checkbox.add_theme_stylebox_override("hover_pressed", hover_pressed)
	checkbox.add_theme_stylebox_override("disabled", disabled)
	checkbox.add_theme_stylebox_override("focus", focus)


static func make_section_hint_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", MUTED_TEXT)
	return lbl


static func make_help_link_button(text: String) -> LinkButton:
	var btn := LinkButton.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color(0.55, 0.78, 0.98, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.72, 0.88, 1.0, 1.0))
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return btn


static func make_help_icon_button(tooltip: String = "") -> Button:
	# Mint chip — readable on blue UI without amber “warning” vibe.
	const HELP_TINT := Color(0.48, 0.90, 0.76, 1.0)
	const ICON_PX := 22
	var btn := Button.new()
	btn.text = ""
	btn.focus_mode = Control.FOCUS_NONE
	btn.flat = true
	btn.custom_minimum_size = Vector2(36, 36)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.tooltip_text = tooltip
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.12, 0.12, 0.94)
	normal.border_color = Color(0.48, 0.90, 0.76, 0.50)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(18)
	normal.content_margin_left = 6
	normal.content_margin_top = 6
	normal.content_margin_right = 6
	normal.content_margin_bottom = 6
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.10, 0.18, 0.16, 0.96)
	hover.border_color = Color(0.62, 0.96, 0.84, 0.85)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.06, 0.10, 0.10, 0.96)
	for state in ["normal", "hover", "pressed", "focus"]:
		var box: StyleBoxFlat = normal
		if state == "hover":
			box = hover
		elif state == "pressed":
			box = pressed
		btn.add_theme_stylebox_override(state, box)
	UiIconHelper.configure_button_icon(btn, "circle-question-mark.svg", HELP_TINT, ICON_PX)
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.add_theme_constant_override("h_separation", 0)
	btn.add_theme_constant_override("icon_max_width", ICON_PX)
	return btn


## Puts a compact (?) immediately after `label` (wraps into an HBox once).
static func attach_help_icon_beside_label(
	label: Label,
	tooltip: String,
	on_pressed: Callable,
	center_row: bool = false
) -> Button:
	if label == null:
		return null
	# Godot treats get_meta(..., null) as "no default" and errors if key is missing.
	if label.has_meta("help_icon_btn"):
		var existing: Variant = label.get_meta("help_icon_btn")
		if existing is Button and is_instance_valid(existing):
			(existing as Button).tooltip_text = tooltip
			return existing as Button
	var btn := make_help_icon_button(tooltip)
	if on_pressed.is_valid():
		btn.pressed.connect(on_pressed)
	var parent := label.get_parent()
	if parent == null:
		return btn
	if parent is HBoxContainer:
		parent.add_child(btn)
		parent.move_child(btn, label.get_index() + 1)
		label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		label.set_meta("help_icon_btn", btn)
		return btn
	var row := HBoxContainer.new()
	row.name = "%sHelpRow" % label.name
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = (
		Control.SIZE_SHRINK_CENTER if center_row else Control.SIZE_SHRINK_BEGIN
	)
	if center_row:
		row.alignment = BoxContainer.ALIGNMENT_CENTER
	var idx := label.get_index()
	parent.add_child(row)
	parent.move_child(row, idx)
	parent.remove_child(label)
	row.add_child(label)
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(btn)
	label.set_meta("help_icon_btn", btn)
	return btn


static func make_info_hint(text: String, accent: Color = Color(0.42, 0.57, 0.82, 1.0)) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := StyleBoxFlat.new()
	box.bg_color = Color(accent.r, accent.g, accent.b, 0.1)
	box.border_color = Color(accent.r, accent.g, accent.b, 0.28)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.content_margin_left = 12
	box.content_margin_top = 10
	box.content_margin_right = 12
	box.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var frame := UiIconHelper.make_icon_frame("info.svg", 30, 16, accent)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(frame)
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.62, 0.7, 0.82, 0.95))
	row.add_child(lbl)
	return panel


static func make_stat_card(
	title_text: String,
	hint_text: String,
	panel_variation: StringName,
	accent: Color
) -> Dictionary:
	var card := make_inner_card(panel_variation)
	card.size_flags_stretch_ratio = 1.0
	var margin: MarginContainer = card.get_meta("inner_margin")
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", MUTED_TEXT)
	vbox.add_child(title)

	var value := Label.new()
	value.text = "—"
	value.add_theme_font_size_override("font_size", 30)
	value.add_theme_color_override("font_color", accent.lightened(0.12))
	vbox.add_child(value)

	var hint: Label = null
	if hint_text.strip_edges() != "":
		hint = Label.new()
		hint.text = hint_text
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_font_size_override("font_size", 13)
		hint.add_theme_color_override("font_color", MUTED_TEXT)
		vbox.add_child(hint)

	return {"card": card, "value_label": value, "hint_label": hint}
