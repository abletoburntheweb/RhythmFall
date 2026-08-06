# logic/domain/profile/genre_portrait_rows_ui.gd
extends RefCounted
class_name GenrePortraitRowsUi

const _GenreGroupIcons = preload("res://logic/domain/library/genre_group_icons.gd")

const GRID_COLUMNS := 4
const ICON_SIZE := 32
const ICON_INNER := 17
const ROW_MIN_HEIGHT := 40
const BAR_HEIGHT := 14
const LABEL_WIDTH := 124
const VALUE_WIDTH := 44
const LABEL_FONT_SIZE := 14
const VALUE_FONT_SIZE := 13
const BAR_SLOT_MIN_WIDTH := 80
const H_SEP := 10
const V_SEP := 6

const NAME_COLOR := Color(0.784314, 0.823529, 0.901961, 1)
const VALUE_COLOR := Color(0.654902, 0.654902, 0.678431, 1)


static func create_grid() -> GridContainer:
	var grid := GridContainer.new()
	configure_grid(grid)
	return grid


static func configure_grid(grid: GridContainer) -> void:
	grid.columns = GRID_COLUMNS
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", H_SEP)
	grid.add_theme_constant_override("v_separation", V_SEP)


static func icon_cell_for_group(group_id: String, tint: Color) -> CenterContainer:
	var icon_cell := CenterContainer.new()
	icon_cell.custom_minimum_size = Vector2(ICON_SIZE, ROW_MIN_HEIGHT)
	icon_cell.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	icon_cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_cell.add_child(
		_GenreGroupIcons.make_icon_frame_for_group(group_id, tint, ICON_SIZE, ICON_INNER)
	)
	return icon_cell


static func icon_cell_for_genre(genre_id: String, tint: Color) -> CenterContainer:
	var icon_cell := CenterContainer.new()
	icon_cell.custom_minimum_size = Vector2(ICON_SIZE, ROW_MIN_HEIGHT)
	icon_cell.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	icon_cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_cell.add_child(
		_GenreGroupIcons.make_icon_frame_for_genre(genre_id, tint, ICON_SIZE, ICON_INNER)
	)
	return icon_cell


static func add_grid_row(
	grid: GridContainer,
	icon_cell: Control,
	label_text: String,
	bar_value: float,
	bar_max: float,
	value_text: String,
	tint: Color,
	label_font_size: int = LABEL_FONT_SIZE,
	value_font_size: int = VALUE_FONT_SIZE
) -> void:
	grid.add_child(icon_cell)
	grid.add_child(_make_name_label(label_text, label_font_size))
	grid.add_child(_make_bar_slot(bar_value, bar_max, tint))
	grid.add_child(_make_value_label(value_text, value_font_size))


static func build_row_hbox(
	icon_cell: Control,
	label_text: String,
	bar_value: float,
	bar_max: float,
	value_text: String,
	tint: Color,
	label_font_size: int = LABEL_FONT_SIZE,
	value_font_size: int = VALUE_FONT_SIZE
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size.y = ROW_MIN_HEIGHT
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", H_SEP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon_cell)
	row.add_child(_make_name_label(label_text, label_font_size))
	row.add_child(_make_bar_slot(bar_value, bar_max, tint))
	row.add_child(_make_value_label(value_text, value_font_size))
	return row


static func style_bar(bar: ProgressBar, tint: Color) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.09, 0.1, 0.14, 0.95)
	track.set_corner_radius_all(BAR_HEIGHT * 0.5)
	track.set_content_margin_all(0)
	var fill := StyleBoxFlat.new()
	fill.bg_color = tint.lightened(0.05)
	fill.set_corner_radius_all(BAR_HEIGHT * 0.5)
	fill.set_content_margin_all(0)
	fill.expand_margin_top = 0
	fill.expand_margin_bottom = 0
	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", fill)


static func _make_name_label(text: String, font_size: int) -> Label:
	var name_label := Label.new()
	name_label.text = text
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", font_size)
	name_label.add_theme_color_override("font_color", NAME_COLOR)
	name_label.custom_minimum_size = Vector2(LABEL_WIDTH, ROW_MIN_HEIGHT)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return name_label


static func _make_value_label(text: String, font_size: int) -> Label:
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(VALUE_WIDTH, ROW_MIN_HEIGHT)
	value_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.text = text
	value_label.add_theme_font_size_override("font_size", font_size)
	value_label.add_theme_color_override("font_color", VALUE_COLOR)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return value_label


static func _make_bar_slot(bar_value: float, bar_max: float, tint: Color) -> MarginContainer:
	if bar_max <= 0.0:
		bar_max = 1.0
	var bar_slot := MarginContainer.new()
	bar_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	bar_slot.custom_minimum_size = Vector2(BAR_SLOT_MIN_WIDTH, ROW_MIN_HEIGHT)
	bar_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_vpad := int((ROW_MIN_HEIGHT - BAR_HEIGHT) * 0.5)
	bar_slot.add_theme_constant_override("margin_top", bar_vpad)
	bar_slot.add_theme_constant_override("margin_bottom", bar_vpad)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = bar_max
	bar.value = bar_value
	bar.step = 0.01 if bar_max <= 100.0 else 1.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	style_bar(bar, tint)
	bar_slot.add_child(bar)
	return bar_slot
