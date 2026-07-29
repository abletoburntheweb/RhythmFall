# scenes/song_select/endless/session_instrument_icon.gd
extends Button
class_name SessionInstrumentIcon

## Fired when the circular pool icon is toggled (Endless instrument pool).
signal pool_toggled(instrument_id: String, pressed: bool)
## Legacy single-select (playlist filters): emitted when turned on.
signal instrument_selected(instrument_id: String)

const _GenPresetUi = preload("res://logic/ui/generation_preset_ui.gd")
const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")

# Match SessionModPoolIcon geometry so instruments sit in the same visual language.
const FRAME_SIZE := 36
const ICON_SIZE := 19

var instrument_id: String = ""
var _icon_frame: PanelContainer = null
var _empty_style: StyleBoxEmpty
var _locked: bool = false


func setup(inst_id: String, locked: bool = false) -> void:
	instrument_id = inst_id
	_locked = locked
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL if not locked else Control.FOCUS_NONE
	flat = true
	clip_contents = false
	custom_minimum_size = Vector2(FRAME_SIZE, FRAME_SIZE)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text = ""
	disabled = locked
	_build_icon()
	_refresh_tooltip()
	if not toggled.is_connected(_on_toggled):
		toggled.connect(_on_toggled)
	_sync_style()


func set_instrument_selected(on: bool) -> void:
	set_pool_selected(on)


func set_pool_selected(on: bool) -> void:
	set_block_signals(true)
	button_pressed = on
	_sync_style()
	set_block_signals(false)


func _build_icon() -> void:
	for child in get_children():
		child.queue_free()
	_icon_frame = null
	var icon_file := str(_GenPresetUi.INSTRUMENT_ICONS.get(instrument_id, "drum.svg"))
	var tint: Color = _GenPresetUi.INSTRUMENT_ICON_COLORS.get(
		instrument_id,
		Color(0.38, 0.78, 0.74, 1.0)
	)
	if _locked:
		tint = tint.lerp(Color(0.45, 0.5, 0.58), 0.45)
	_icon_frame = _UiIconHelper.make_icon_frame(icon_file, FRAME_SIZE, ICON_SIZE, tint)
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


func _instrument_title() -> String:
	var title_key := "GEN_INST_DRUMS" if instrument_id == "drums" else "GEN_INST_BASS"
	return tr(title_key)


func _refresh_tooltip() -> void:
	var title := _instrument_title()
	if _locked:
		tooltip_text = "%s — %s" % [tr("GEN_SOON"), title]
		return
	var desc_key := "GEN_INST_DRUMS_DESC" if instrument_id == "drums" else "GEN_INST_BASS_DESC"
	tooltip_text = "%s\n%s" % [title, tr(desc_key)]


func refresh_locale() -> void:
	_refresh_tooltip()


func _on_toggled(on: bool) -> void:
	if _locked:
		set_pool_selected(false)
		return
	_sync_style()
	pool_toggled.emit(instrument_id, on)
	if on:
		instrument_selected.emit(instrument_id)


func _sync_style() -> void:
	if _icon_frame:
		var tint: Color = _GenPresetUi.INSTRUMENT_ICON_COLORS.get(
			instrument_id,
			Color(0.38, 0.78, 0.74, 1.0)
		)
		if _locked:
			tint = tint.lerp(Color(0.45, 0.5, 0.58), 0.45)
		_UiIconHelper.set_frame_tint(_icon_frame, tint, button_pressed and not _locked)
	if _locked:
		modulate = Color(0.55, 0.58, 0.64, 0.55)
	elif button_pressed:
		modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		modulate = Color(0.78, 0.82, 0.9, 0.88)
