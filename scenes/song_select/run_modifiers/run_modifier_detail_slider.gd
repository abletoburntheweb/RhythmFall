# scenes/song_select/run_modifiers/run_modifier_detail_slider.gd
extends VBoxContainer

signal value_changed(param_id: String, value: Variant)

const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")

@export var param_id: String = ""

@onready var _title_label: Label = $TitleLabel
@onready var _value_row: HBoxContainer = $ValueRow
@onready var _value_label: Label = $ValueRow/ValueLabel
@onready var _slider: HSlider = $ValueRow/Slider
@onready var _range_row: HBoxContainer = $RangeRow
@onready var _min_label: Label = $RangeRow/MinLabel
@onready var _max_label: Label = $RangeRow/MaxLabel
@onready var _windows_caption: Label = $WindowsCaption

var _default_value: float = 0.0
var _value_suffix: String = "%"
var _display_multiplier: float = 1.0
var _timing_modifier_id: String = ""
var _hits_suffix: bool = false


func setup(
	p_param_id: String,
	title_text: String,
	min_value: float,
	max_value: float,
	step: float,
	default_value: float,
	value_suffix: String = "%",
	display_multiplier: float = 1.0,
	timing_modifier_id: String = "",
	hits_suffix: bool = false
) -> void:
	param_id = p_param_id
	_default_value = default_value
	_value_suffix = value_suffix
	_display_multiplier = display_multiplier
	_timing_modifier_id = timing_modifier_id
	_hits_suffix = hits_suffix
	if _title_label:
		_title_label.text = title_text
	if _slider:
		_slider.min_value = min_value
		_slider.max_value = max_value
		_slider.step = step
		_slider.value = default_value
		if not _slider.value_changed.is_connected(_on_slider_changed):
			_slider.value_changed.connect(_on_slider_changed)
		if not _slider.gui_input.is_connected(_on_slider_gui_input):
			_slider.gui_input.connect(_on_slider_gui_input)
	_refresh_bounds()
	_refresh_value_label()
	_refresh_windows_caption()


func set_value(value: float, emit: bool = false) -> void:
	if _slider:
		_slider.set_value_no_signal(value)
	_refresh_bounds()
	_refresh_value_label()
	_refresh_windows_caption()
	if emit:
		value_changed.emit(param_id, value)


func get_value() -> float:
	return _slider.value if _slider else 0.0


func get_default_value() -> float:
	return _default_value


func set_hint_tooltip(hint: String) -> void:
	if _title_label:
		_title_label.tooltip_text = hint
	if _slider:
		_slider.tooltip_text = hint
	if _value_label:
		_value_label.tooltip_text = hint


func reset_to_default(emit: bool = true) -> void:
	set_value(_default_value, emit)


func _refresh_bounds() -> void:
	if _slider == null:
		return
	if _min_label:
		_min_label.text = _format_bound(_slider.min_value)
	if _max_label:
		_max_label.text = _format_bound(_slider.max_value)


func _uses_speed_mult_display() -> bool:
	return (
		is_equal_approx(_display_multiplier, 0.01)
		and _timing_modifier_id == ""
		and _value_suffix == "%"
	)


func _is_seconds_suffix() -> bool:
	return _value_suffix.strip_edges() in ["s", "с"]


func _is_ms_suffix() -> bool:
	return _value_suffix.strip_edges() in ["ms", "мс"]


func _seconds_display_decimals() -> int:
	if _slider == null:
		return 0
	var step := float(_slider.step)
	if step >= 1.0:
		return 0
	if step >= 0.1:
		return 1
	return 2


func _format_seconds(v: float) -> String:
	var decimals := _seconds_display_decimals()
	if decimals <= 0:
		return "%d %s" % [int(round(v)), tr("UNIT_SEC")]
	return ("%0." + str(decimals) + "f %s") % [v, tr("UNIT_SEC")]


func _format_bound(v: float) -> String:
	if _timing_modifier_id != "":
		# The slider is a single strictness multiplier that scales both the
		# Perfect and Good windows together; show it as a percentage and put the
		# resulting millisecond windows on the caption below.
		return "%d%%" % int(round(v))
	if _uses_speed_mult_display():
		return _RunModifiers.format_speed_mult_pct(v)
	if _is_seconds_suffix():
		return _format_seconds(v)
	if is_equal_approx(_display_multiplier, 1.0):
		if _hits_suffix:
			return "%d %s" % [int(round(v)), tr("UNIT_HITS")]
		if _is_ms_suffix():
			return "%d %s" % [int(round(v)), tr("UNIT_MS")]
		return "%d%s" % [int(round(v)), _value_suffix]
	return "%.2fx" % (v * _display_multiplier)


func _refresh_value_label() -> void:
	if _value_label == null or _slider == null:
		return
	var v := _slider.value
	if _timing_modifier_id != "":
		_value_label.text = "%d%%" % int(round(v))
		return
	if _uses_speed_mult_display():
		_value_label.text = _RunModifiers.format_speed_mult_pct(v)
		return
	if is_equal_approx(_display_multiplier, 1.0):
		if _value_suffix == "%":
			_value_label.text = "%d%%" % int(round(v))
		elif _is_ms_suffix():
			_value_label.text = "%d %s" % [int(round(v)), tr("UNIT_MS")]
		elif _is_seconds_suffix():
			_value_label.text = _format_seconds(v)
		elif _value_suffix == " px":
			_value_label.text = "%d px" % int(round(v))
		elif _hits_suffix:
			_value_label.text = "%d %s" % [int(round(v)), tr("UNIT_HITS")]
		else:
			_value_label.text = "%d" % int(round(v))
	else:
		_value_label.text = "%.2fx" % (v * _display_multiplier)


func _refresh_windows_caption() -> void:
	if _windows_caption == null:
		return
	if _timing_modifier_id == "" or _slider == null:
		_windows_caption.visible = false
		return
	_windows_caption.visible = true
	_windows_caption.text = _RunModifiers.format_timing_windows_label(
		_timing_modifier_id, _slider.value
	)


func _on_slider_changed(value: float) -> void:
	_refresh_value_label()
	_refresh_windows_caption()
	value_changed.emit(param_id, value)


func _on_slider_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.double_click:
		reset_to_default(true)
		accept_event()
