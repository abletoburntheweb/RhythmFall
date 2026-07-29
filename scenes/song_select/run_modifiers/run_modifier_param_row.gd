# scenes/song_select/run_modifiers/run_modifier_param_row.gd
extends PanelContainer

signal value_changed(param_id: String, value: Variant)

@export var param_id: String = ""

@onready var _title_label: Label = $RowMargin/RowHBox/TitleLabel
@onready var _slider: HSlider = $RowMargin/RowHBox/Slider
@onready var _value_label: Label = $RowMargin/RowHBox/ValueLabel
@onready var _delta_label: Label = $RowMargin/RowHBox/DeltaLabel

var _default_value: float = 0.0


func setup(
	p_param_id: String,
	title_text: String,
	min_value: float,
	max_value: float,
	step: float,
	default_value: float,
	value_suffix: String = ""
) -> void:
	param_id = p_param_id
	_default_value = default_value
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
	_set_value_suffix(value_suffix)
	_refresh_value_label()


func set_value(value: float, emit: bool = false) -> void:
	if _slider:
		_slider.set_value_no_signal(value)
	_refresh_value_label()
	if emit:
		value_changed.emit(param_id, value)


func get_value() -> float:
	return _slider.value if _slider else 0.0


func get_default_value() -> float:
	return _default_value


func reset_to_default(emit: bool = true) -> void:
	set_value(_default_value, emit)


func set_delta_text(text: String) -> void:
	if _delta_label:
		_delta_label.text = text


func set_title(text: String) -> void:
	if _title_label:
		_title_label.text = text


var _value_suffix: String = "%"


func _set_value_suffix(suffix: String) -> void:
	_value_suffix = suffix if suffix != "" else "%"


func _on_slider_changed(value: float) -> void:
	_refresh_value_label()
	value_changed.emit(param_id, value)


func _on_slider_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.double_click:
		if event.button_index == MOUSE_BUTTON_LEFT:
			reset_to_default(true)
			accept_event()


func _refresh_value_label() -> void:
	if _value_label == null or _slider == null:
		return
	if _value_suffix == "%":
		_value_label.text = "%d%%" % int(round(_slider.value))
	elif _value_suffix.strip_edges() in ["s", "с"]:
		var step := float(_slider.step)
		var decimals := 0 if step >= 1.0 else (1 if step >= 0.1 else 2)
		if decimals <= 0:
			_value_label.text = "%d %s" % [int(round(_slider.value)), tr("UNIT_SEC")]
		else:
			_value_label.text = ("%0." + str(decimals) + "f %s") % [_slider.value, tr("UNIT_SEC")]
	else:
		_value_label.text = "%s%s" % [str(int(_slider.value)), _value_suffix]
