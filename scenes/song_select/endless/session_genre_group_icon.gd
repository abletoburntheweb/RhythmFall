# scenes/song_select/endless/session_genre_group_icon.gd
extends Button
class_name SessionGenreGroupIcon

signal group_toggled(group_id: String, pressed: bool)

const _GenreGroupIcons = preload("res://logic/domain/library/genre_group_icons.gd")
const _ProfileGenrePortrait = preload("res://logic/domain/profile/profile_genre_portrait.gd")

const FRAME_SIZE := 36
const ICON_SIZE := 19

var group_id: String = ""
var _icon_frame: PanelContainer = null
var _empty_style: StyleBoxEmpty


func setup(p_group_id: String) -> void:
	group_id = p_group_id
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


func set_group_selected(on: bool) -> void:
	set_block_signals(true)
	button_pressed = on
	_sync_style()
	set_block_signals(false)


func _build_icon() -> void:
	for child in get_children():
		child.queue_free()
	_icon_frame = null
	var tint := _GenreGroupIcons.tint_for_group(group_id)
	_icon_frame = _GenreGroupIcons.make_icon_frame_for_group(group_id, tint, FRAME_SIZE, ICON_SIZE, false)
	_icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon_frame.offset_left = 0.0
	_icon_frame.offset_top = 0.0
	_icon_frame.offset_right = 0.0
	_icon_frame.offset_bottom = 0.0
	_icon_frame.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_icon_frame.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_icon_frame)
	pivot_offset = custom_minimum_size * 0.5
	for state in ["normal", "hover", "focus", "pressed", "disabled"]:
		add_theme_stylebox_override(state, _empty_button_style())


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size * 0.5


func _empty_button_style() -> StyleBoxEmpty:
	if _empty_style == null:
		_empty_style = StyleBoxEmpty.new()
	return _empty_style


func _refresh_tooltip() -> void:
	tooltip_text = tr(_ProfileGenrePortrait.group_locale_key(group_id))


func refresh_locale() -> void:
	_refresh_tooltip()


func _on_toggled(on: bool) -> void:
	_sync_style()
	group_toggled.emit(group_id, on)


func _sync_style() -> void:
	if _icon_frame:
		var tint := _GenreGroupIcons.tint_for_group(group_id)
		UiIconHelper.set_frame_tint(_icon_frame, tint, button_pressed)
	if button_pressed:
		modulate = Color(1.0, 1.0, 1.0, 1.0)
		scale = Vector2(1.06, 1.06)
		tooltip_text = "%s\n%s" % [
			tr(_ProfileGenrePortrait.group_locale_key(group_id)),
			tr("SESSION_SETUP_GENRE_GROUP_SELECTED_TIP"),
		]
	else:
		modulate = Color(0.78, 0.82, 0.9, 0.88)
		scale = Vector2.ONE
		_refresh_tooltip()
