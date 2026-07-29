# scenes/song_select/endless/session_toggle_icon.gd
extends Button
class_name SessionToggleIcon

signal option_toggled(toggle_id: String, pressed: bool)

const FRAME_SIZE := 36
const ICON_SIZE := 19

var toggle_id: String = ""
var _icon_frame: PanelContainer = null
var _base_tint: Color = Color.WHITE
var _empty_style: StyleBoxEmpty


func setup(id: String, icon_file: String, tint: Color, tooltip: String = "") -> void:
	toggle_id = id
	_base_tint = tint
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	flat = true
	clip_contents = false
	custom_minimum_size = Vector2(FRAME_SIZE, FRAME_SIZE)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text = ""
	tooltip_text = tooltip
	_build_icon(icon_file)
	if not toggled.is_connected(_on_toggled):
		toggled.connect(_on_toggled)
	_sync_style()


func set_selected(on: bool) -> void:
	set_block_signals(true)
	button_pressed = on
	_sync_style()
	set_block_signals(false)


func set_tooltip_text_value(text: String) -> void:
	tooltip_text = text


func _build_icon(icon_file: String) -> void:
	for child in get_children():
		child.queue_free()
	_icon_frame = null
	if icon_file.strip_edges() == "":
		return
	_icon_frame = UiIconHelper.make_icon_frame(icon_file, FRAME_SIZE, ICON_SIZE, _base_tint)
	_icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon_frame.offset_left = 0.0
	_icon_frame.offset_top = 0.0
	_icon_frame.offset_right = 0.0
	_icon_frame.offset_bottom = 0.0
	_icon_frame.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_icon_frame.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_icon_frame)
	for state in ["normal", "hover", "focus", "pressed", "disabled"]:
		add_theme_stylebox_override(state, _empty_button_style())


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
			# Desaturate off-state like Endless mod-pool — clearer than soft modulate alone.
			paint_tint = _base_tint.lerp(UiIconHelper.MUTED, 0.58)
		UiIconHelper.set_frame_tint(_icon_frame, paint_tint, button_pressed)
	if button_pressed:
		modulate = Color(1.0, 1.0, 1.0, 1.0)
		scale = Vector2(1.06, 1.06)
	else:
		modulate = Color(0.72, 0.76, 0.84, 0.82)
		scale = Vector2.ONE
