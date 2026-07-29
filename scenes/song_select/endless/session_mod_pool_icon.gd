# scenes/song_select/endless/session_mod_pool_icon.gd
extends Button
class_name SessionModPoolIcon

signal pool_toggled(modifier_id: String, pressed: bool)

const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")

const FRAME_SIZE := 36
const ICON_SIZE := 19

var modifier_id: String = ""
var _icon_frame: PanelContainer = null
var _empty_style: StyleBoxEmpty


func setup(mod_id: String) -> void:
	modifier_id = mod_id
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	flat = true
	clip_contents = false
	custom_minimum_size = Vector2(FRAME_SIZE, FRAME_SIZE)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text = ""
	_build_icon()
	_refresh_tooltip()
	if not toggled.is_connected(_on_toggled):
		toggled.connect(_on_toggled)
	_sync_style()


func set_pool_selected(on: bool) -> void:
	set_block_signals(true)
	button_pressed = on
	_sync_style()
	set_block_signals(false)


func _build_icon() -> void:
	for child in get_children():
		child.queue_free()
	_icon_frame = null
	var icon_file := _RunModifiers.icon_file(modifier_id)
	if icon_file.strip_edges() == "":
		return
	var tint := _RunModifiers.category_tint(modifier_id, false)
	_icon_frame = UiIconHelper.make_icon_frame(icon_file, FRAME_SIZE, ICON_SIZE, tint)
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


func _refresh_tooltip() -> void:
	var title := tr(_RunModifiers.title_i18n_key(modifier_id))
	var desc := _RunModifiers.format_modifier_description(modifier_id, {}).strip_edges()
	if desc != "":
		tooltip_text = "%s\n%s" % [title, desc]
	else:
		tooltip_text = title


func refresh_locale() -> void:
	_refresh_tooltip()


func _on_toggled(on: bool) -> void:
	_sync_style()
	pool_toggled.emit(modifier_id, on)


func _sync_style() -> void:
	if _icon_frame:
		var tint := _RunModifiers.category_tint(modifier_id, button_pressed)
		UiIconHelper.set_frame_tint(_icon_frame, tint, button_pressed)
	if button_pressed:
		modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		modulate = Color(0.78, 0.82, 0.9, 0.88)
