# scenes/song_select/endless/session_preset_ready_chip.gd
extends Button
class_name SessionPresetReadyChip

signal option_toggled(slot_id: String, pressed: bool)

const FRAME_SIZE := 36
const ICON_SIZE := 18
const MIN_WIDTH := 96
const MAX_LABEL_CHARS := 14

var toggle_id: String = ""
var _icon_frame: PanelContainer = null
var _name_label: Label = null
var _base_tint: Color = Color(0.55, 0.78, 0.98, 1.0)
var _empty_style: StyleBoxEmpty


func setup(slot_id: String, icon_file: String, tint: Color, display_name: String, tooltip: String = "") -> void:
	toggle_id = slot_id
	_base_tint = tint
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	flat = true
	clip_contents = false
	custom_minimum_size = Vector2(MIN_WIDTH, FRAME_SIZE)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text = ""
	tooltip_text = tooltip
	_build_content(icon_file, display_name)
	if not toggled.is_connected(_on_toggled):
		toggled.connect(_on_toggled)
	_sync_style()


func set_selected(on: bool) -> void:
	set_block_signals(true)
	button_pressed = on
	_sync_style()
	set_block_signals(false)


func set_display_name(display_name: String) -> void:
	if _name_label:
		_name_label.text = _truncate(display_name)


func set_tooltip_text_value(text: String) -> void:
	tooltip_text = text


func _build_content(icon_file: String, display_name: String) -> void:
	for child in get_children():
		child.queue_free()
	_icon_frame = null
	_name_label = null
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 4.0
	row.offset_top = 0.0
	row.offset_right = -4.0
	row.offset_bottom = 0.0
	add_child(row)
	if icon_file.strip_edges() != "":
		_icon_frame = UiIconHelper.make_icon_frame(icon_file, FRAME_SIZE, ICON_SIZE, _base_tint)
		_icon_frame.custom_minimum_size = Vector2(FRAME_SIZE, FRAME_SIZE)
		_icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(_icon_frame)
	_name_label = Label.new()
	_name_label.text = _truncate(display_name)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 13)
	_name_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))
	row.add_child(_name_label)
	for state in ["normal", "hover", "focus", "pressed", "disabled"]:
		add_theme_stylebox_override(state, _empty_button_style())


func _truncate(text: String) -> String:
	var s := text.strip_edges()
	if s.length() <= MAX_LABEL_CHARS:
		return s
	return s.substr(0, MAX_LABEL_CHARS - 1) + "…"


func _empty_button_style() -> StyleBoxEmpty:
	if _empty_style == null:
		_empty_style = StyleBoxEmpty.new()
	return _empty_style


func _on_toggled(on: bool) -> void:
	_sync_style()
	option_toggled.emit(toggle_id, on)


func _sync_style() -> void:
	if _icon_frame:
		var paint_tint := _base_tint
		if not button_pressed:
			paint_tint = _base_tint.lerp(UiIconHelper.MUTED, 0.58)
		UiIconHelper.set_frame_tint(_icon_frame, paint_tint, button_pressed)
	if _name_label:
		var col := Color(0.92, 0.96, 1.0, 1.0) if button_pressed else Color(0.62, 0.68, 0.78, 0.95)
		_name_label.add_theme_color_override("font_color", col)
	if button_pressed:
		modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		modulate = Color(0.72, 0.76, 0.84, 0.82)
