# logic/ui/preset_active_header.gd
extends RefCounted
class_name PresetActiveHeader

const ACTIVE_ICON_FILE := "disc-3.svg"
const ACTIVE_ICON_COLOR := Color(0.45, 0.78, 0.98, 1.0)
const DIRTY_MARK_COLOR := Color(0.95, 0.78, 0.38, 1.0)
const ICON_DISPLAY_SIZE := 20


static func attach(
	parent: Control,
	insert_index: int = -1,
	centered: bool = false,
	replace_label: Label = null
) -> HBoxContainer:
	if parent == null:
		return null
	var row := parent.get_node_or_null("ActivePresetRow") as HBoxContainer
	if row != null:
		return row
	if replace_label != null:
		insert_index = replace_label.get_index()
		replace_label.queue_free()
	row = HBoxContainer.new()
	row.name = &"ActivePresetRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	if centered:
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var icon := UiIconHelper.make_texture_rect(
		UiIconHelper.load_tinted_icon(
			ACTIVE_ICON_FILE,
			ACTIVE_ICON_COLOR,
			UiIconHelper.raster_size_for_display(ICON_DISPLAY_SIZE),
		),
		ICON_DISPLAY_SIZE,
	)
	icon.name = &"ActiveIcon"
	row.add_child(icon)
	var prefix := Label.new()
	prefix.name = &"PrefixLabel"
	prefix.add_theme_font_size_override("font_size", 14)
	prefix.add_theme_color_override("font_color", Color(0.55, 0.64, 0.76, 0.92))
	row.add_child(prefix)
	var name_label := Label.new()
	name_label.name = &"NameLabel"
	name_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.78, 0.88, 0.98, 1.0))
	row.add_child(name_label)
	var dirty := Label.new()
	dirty.name = &"DirtyMark"
	dirty.text = "*"
	dirty.add_theme_font_size_override("font_size", 17)
	dirty.add_theme_color_override("font_color", DIRTY_MARK_COLOR)
	dirty.visible = false
	row.add_child(dirty)
	parent.add_child(row)
	if insert_index >= 0:
		parent.move_child(row, insert_index)
	row.visible = false
	return row


static func update(row: HBoxContainer, slot: int, preset_name: String, is_dirty: bool) -> void:
	if row == null:
		return
	if slot <= 0:
		row.visible = false
		return
	row.visible = true
	var prefix := row.get_node_or_null("PrefixLabel") as Label
	var name_label := row.get_node_or_null("NameLabel") as Label
	var dirty := row.get_node_or_null("DirtyMark") as Label
	if prefix:
		prefix.text = TranslationServer.translate("MOD_PRESET_ACTIVE_PREFIX")
	if name_label:
		name_label.text = preset_name
	if dirty:
		dirty.visible = is_dirty
		dirty.tooltip_text = (
			TranslationServer.translate("MOD_PRESET_DIRTY_TIP") if is_dirty else ""
		)
