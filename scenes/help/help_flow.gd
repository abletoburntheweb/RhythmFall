# scenes/help/help_flow.gd
class_name HelpFlow
extends PanelContainer

const _HelpTypography = preload("res://scenes/help/lib/help_typography.gd")

const _ARROW := "→"
const _SPLIT_ARROW := "↔"
const _CARD_W := 148.0
const _ICON_FRAME := 44.0
const _ICON_SIZE := 24.0

var _layout_height := 100.0


func setup_linear(steps: Array, palette: Dictionary) -> void:
	_layout_height = 132.0
	_clear_body()
	if steps.is_empty():
		return
	_apply_shell_style()
	var root := _content_root()
	var row := _shrink_h(HBoxContainer.new())
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	root.add_child(row)
	for i in range(steps.size()):
		var step: Dictionary = steps[i]
		if not (step is Dictionary):
			continue
		row.add_child(_make_step_card(step, palette))
		if i < steps.size() - 1:
			row.add_child(_make_arrow(_ARROW))
	_lock_layout(0.0)


func setup_split(left: Dictionary, right: Dictionary, palette: Dictionary) -> void:
	_layout_height = 132.0
	_clear_body()
	if left.is_empty() or right.is_empty():
		return
	_apply_shell_style()
	var root := _content_root()
	var row := _shrink_h(HBoxContainer.new())
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	root.add_child(row)
	row.add_child(_make_info_card(left, palette))
	row.add_child(_make_arrow(_SPLIT_ARROW))
	row.add_child(_make_info_card(right, palette))
	_lock_layout(0.0)


func setup_branch(hub: Dictionary, arms: Array, palette: Dictionary) -> void:
	_layout_height = 92.0 + 36.0 + float(mini(arms.size(), 6)) * 4.0
	if arms.size() >= 3:
		_layout_height = 300.0
	elif arms.size() == 2:
		_layout_height = 268.0
	_clear_body()
	if hub.is_empty() or arms.is_empty():
		return
	_apply_shell_style()
	var root := _content_root()
	var vbox := _shrink_v(VBoxContainer.new())
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	root.add_child(vbox)
	var hub_row := _shrink_h(HBoxContainer.new())
	hub_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hub_row.add_child(_make_info_card(hub, palette, _CARD_W + 20.0))
	vbox.add_child(hub_row)
	var arrow_row := _shrink_h(HBoxContainer.new())
	arrow_row.alignment = BoxContainer.ALIGNMENT_CENTER
	arrow_row.add_theme_constant_override("separation", 16)
	vbox.add_child(arrow_row)
	for _i in arms.size():
		arrow_row.add_child(_make_arrow("↓"))
	var arms_row := _shrink_h(HBoxContainer.new())
	arms_row.alignment = BoxContainer.ALIGNMENT_CENTER
	arms_row.add_theme_constant_override("separation", 8)
	vbox.add_child(arms_row)
	for arm in arms:
		if arm is Dictionary:
			arms_row.add_child(_make_info_card(arm, palette))
	_lock_layout(0.0)


func finalize_layout(width: float) -> void:
	var h := _layout_height
	if get_child_count() > 0 and is_inside_tree():
		var margin := get_child(0) as Control
		if margin:
			h = maxf(margin.get_minimum_size().y + 22.0, _layout_height)
	_lock_bounds(h)


func _lock_layout(width: float) -> void:
	_lock_bounds(_layout_height)


func _lock_bounds(height: float) -> void:
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	size_flags_stretch_ratio = 0.0
	clip_contents = true
	custom_minimum_size = Vector2(0.0, maxf(height, 1.0))
	update_minimum_size()


func _shrink_h(node: HBoxContainer) -> HBoxContainer:
	node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	node.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return node


func _shrink_v(node: VBoxContainer) -> VBoxContainer:
	node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	node.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return node


func _content_root() -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	margin.add_child(center)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	return box


func _clear_body() -> void:
	custom_minimum_size = Vector2.ZERO
	update_minimum_size()
	for child in get_children():
		remove_child(child)
		child.queue_free()


func _apply_shell_style() -> void:
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(12)
	box.content_margin_left = 4.0
	box.content_margin_right = 4.0
	box.content_margin_top = 4.0
	box.content_margin_bottom = 4.0
	box.bg_color = Color(0.08, 0.09, 0.13, 0.72)
	box.set_border_width_all(1)
	box.border_color = Color(1, 1, 1, 0.08)
	add_theme_stylebox_override("panel", box)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	clip_contents = true


func _make_arrow(symbol: String) -> Label:
	var arrow := Label.new()
	arrow.text = symbol
	_HelpTypography.apply_label(arrow, _HelpTypography.SIZE_BODY, _HelpTypography.COLOR_FAINT)
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.custom_minimum_size = Vector2(18, 0)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return arrow


func _make_step_card(step: Dictionary, palette: Dictionary) -> PanelContainer:
	var accent := _resolve_palette_color(str(step.get("color", "primary")), palette)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(_CARD_W, 0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_apply_card_style(card, accent, 1)
	var vbox := VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)
	vbox.add_child(_make_icon_frame(str(step.get("icon", "circle-question-mark.svg")), accent))
	var label := Label.new()
	label.text = str(step.get("label", ""))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_HelpTypography.apply_label(label, _HelpTypography.SIZE_BODY)
	label.custom_minimum_size = Vector2(_CARD_W - 12.0, 0)
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vbox.add_child(label)
	return card


func _make_info_card(side: Dictionary, palette: Dictionary, card_w: float = _CARD_W) -> PanelContainer:
	var accent := _resolve_palette_color(str(side.get("color", "primary")), palette)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(card_w, 0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_apply_card_style(card, accent, 2)
	var vbox := VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)
	vbox.add_child(_make_icon_frame(str(side.get("icon", "server.svg")), accent))
	var title := Label.new()
	title.text = str(side.get("title", ""))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_HelpTypography.apply_label(title, _HelpTypography.SIZE_BODY, accent.lightened(0.06))
	title.custom_minimum_size = Vector2(card_w - 12.0, 0)
	title.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vbox.add_child(title)
	var subtitle := str(side.get("subtitle", "")).strip_edges()
	if subtitle != "":
		var subtitle_label := Label.new()
		subtitle_label.text = subtitle
		subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_HelpTypography.apply_label(subtitle_label, _HelpTypography.SIZE_BODY, _HelpTypography.COLOR_MUTED)
		subtitle_label.custom_minimum_size = Vector2(card_w - 12.0, 0)
		subtitle_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		vbox.add_child(subtitle_label)
	return card


func _apply_card_style(card: PanelContainer, accent: Color, border_w: int) -> void:
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(10)
	box.bg_color = Color(accent.r, accent.g, accent.b, 0.12)
	box.set_border_width_all(border_w)
	box.border_color = Color(accent.r, accent.g, accent.b, 0.42)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	card.add_theme_stylebox_override("panel", box)


func _make_icon_frame(icon_file: String, accent: Color) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(_ICON_FRAME, _ICON_FRAME)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(int(_ICON_FRAME * 0.5))
	box.bg_color = Color(accent.r, accent.g, accent.b, 0.16)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	frame.add_theme_stylebox_override("panel", box)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(_ICON_SIZE, _ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = UiIconHelper.load_tinted_icon(icon_file, accent)
	if icon.texture == null and icon_file != "sun.svg":
		# Missing asset in a partial copy — keep the card usable.
		icon.texture = UiIconHelper.load_tinted_icon("sun.svg", accent)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(icon)
	return frame


func _resolve_palette_color(color_key: String, palette: Dictionary) -> Color:
	var key := color_key.strip_edges()
	if key.begins_with("#"):
		key = key.substr(1)
	if palette.has(key):
		return Color("#" + str(palette[key]))
	return Color(0.42, 0.57, 0.82, 1.0)
