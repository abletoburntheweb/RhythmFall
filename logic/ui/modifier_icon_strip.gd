# logic/utils/modifier_icon_strip.gd
extends RefCounted
class_name ModifierIconStrip

const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")

const _DETAIL_ICON_SIZE := 18
const _DETAIL_FRAME_SIZE := 34
const _SLOT_CHIP_ICON_SIZE := 18
const _ROW_CHIP_ICON_SIZE := 16
const _HUD_CHIP_ICON_SIZE := 16
const _HUD_CHIP_FRAME_PAD := 6
const MAX_SLOT_LIST_ICONS := 10
const MAX_ROW_LIST_ICONS := 5
const MAX_HUD_ICONS := 24


static func fill(
	container: BoxContainer,
	modifiers: Array,
	icon_size: int = 20,
	frame_size: int = 28
) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
	for raw_id in _RunModifiers.sanitize(modifiers):
		var mod_id := str(raw_id)
		var icon_file := _RunModifiers.icon_file(mod_id)
		if icon_file.strip_edges() == "":
			continue
		var tint := _RunModifiers.category_tint(mod_id, true)
		var frame := UiIconHelper.make_icon_frame(icon_file, frame_size, icon_size, tint)
		frame.tooltip_text = _RunModifiers.format_tooltip(mod_id)
		container.add_child(frame)


static func fill_row_chips(
	container: BoxContainer,
	modifiers: Array,
	_params: Dictionary = {},
	max_icons: int = MAX_ROW_LIST_ICONS,
	show_tooltips: bool = true,
) -> void:
	fill_slot_chips(
		container,
		modifiers,
		_params,
		max_icons,
		show_tooltips,
		_ROW_CHIP_ICON_SIZE,
		8,
		6,
	)


static func fill_slot_chips(
	container: BoxContainer,
	modifiers: Array,
	_params: Dictionary = {},
	max_icons: int = MAX_SLOT_LIST_ICONS,
	show_tooltips: bool = true,
	icon_size: int = _SLOT_CHIP_ICON_SIZE,
	frame_pad: int = 10,
	separation: int = 8,
) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
	var mods := _RunModifiers.sanitize(modifiers)
	if mods.is_empty():
		return
	container.add_theme_constant_override("separation", separation)
	var shown := 0
	for raw_id in mods:
		if shown >= max_icons:
			break
		var mod_id := str(raw_id)
		var icon_file := _RunModifiers.icon_file(mod_id)
		if icon_file.strip_edges() == "":
			continue
		var tint := _RunModifiers.category_tint(mod_id, true)
		container.add_child(
			_make_mod_chip(mod_id, icon_file, tint, icon_size, show_tooltips, frame_pad)
		)
		shown += 1
	var remaining := mods.size() - shown
	if remaining > 0:
		container.add_child(_make_overflow_chip(remaining))


static func fill_hud_flow(
	container: FlowContainer,
	modifiers: Array,
	max_icons: int = MAX_HUD_ICONS,
	show_tooltips: bool = true,
) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
	var mods := _RunModifiers.sanitize(modifiers)
	if mods.is_empty():
		container.visible = false
		return
	container.visible = true
	container.add_theme_constant_override("h_separation", 6)
	container.add_theme_constant_override("v_separation", 4)
	var shown := 0
	for raw_id in mods:
		if shown >= max_icons:
			break
		var mod_id := str(raw_id)
		var icon_file := _RunModifiers.icon_file(mod_id)
		if icon_file.strip_edges() == "":
			continue
		var tint := _RunModifiers.category_tint(mod_id, true)
		container.add_child(
			_make_mod_chip(
				mod_id,
				icon_file,
				tint,
				_HUD_CHIP_ICON_SIZE,
				show_tooltips,
				_HUD_CHIP_FRAME_PAD,
			)
		)
		shown += 1
	var remaining := mods.size() - shown
	if remaining > 0:
		container.add_child(_make_overflow_chip(remaining))


static func make_mod_chip(mod_id: String, icon_size: int = _SLOT_CHIP_ICON_SIZE, show_tooltip: bool = true) -> Control:
	var icon_file := _RunModifiers.icon_file(mod_id)
	if icon_file.strip_edges() == "":
		return Control.new()
	var tint := _RunModifiers.category_tint(mod_id, true)
	return _make_mod_chip(mod_id, icon_file, tint, icon_size, show_tooltip, 10)


static func fill_mod_rows(container: VBoxContainer, modifiers: Array, empty_text: String = "") -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
	var mods := _RunModifiers.sanitize(modifiers)
	if mods.is_empty():
		if empty_text.strip_edges() != "":
			var empty := Label.new()
			empty.text = empty_text
			empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			empty.add_theme_font_size_override("font_size", 13)
			empty.add_theme_color_override("font_color", Color(0.5, 0.58, 0.68, 0.88))
			container.add_child(empty)
		return
	for raw_id in mods:
		container.add_child(_make_mod_row(str(raw_id)))


static func _make_mod_chip(
	mod_id: String,
	icon_file: String,
	tint: Color,
	icon_size: int,
	show_tooltip: bool,
	frame_pad: int = 10,
) -> Control:
	# Return the framed icon directly — nesting it under a bare Control skips
	# container layout and squeezes the circle into a non-square rect.
	var frame_size := icon_size + frame_pad
	var frame := UiIconHelper.make_icon_frame(icon_file, frame_size, icon_size, tint)
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	if show_tooltip:
		frame.tooltip_text = _RunModifiers.format_tooltip(mod_id)
	return frame


static func _make_flat_icon(icon_file: String, tint: Color, size: int) -> TextureRect:
	return UiIconHelper.make_texture_rect(
		UiIconHelper.load_tinted_icon(icon_file, tint, UiIconHelper.raster_size_for_display(size)),
		size,
	)


static func _make_overflow_chip(extra: int) -> Label:
	var lbl := Label.new()
	lbl.text = "+%d" % extra
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.64, 0.76, 0.88))
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


static func _make_mod_row(modifier_id: String) -> PanelContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 38)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.12, 0.17, 0.95)
	box.border_color = Color(1, 1, 1, 0.08)
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_left = 8
	box.content_margin_top = 6
	box.content_margin_right = 8
	box.content_margin_bottom = 6
	row.add_theme_stylebox_override("panel", box)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hbox)

	var icon_file := _RunModifiers.icon_file(modifier_id)
	var tint := _RunModifiers.category_tint(modifier_id, true)
	if icon_file.strip_edges() != "":
		hbox.add_child(
			UiIconHelper.make_icon_frame(icon_file, _DETAIL_FRAME_SIZE, _DETAIL_ICON_SIZE, tint)
		)

	var title := Label.new()
	title.text = TranslationServer.translate(_RunModifiers.title_i18n_key(modifier_id))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.86, 0.92, 0.98, 0.98))
	hbox.add_child(title)
	return row
