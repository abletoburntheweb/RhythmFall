class_name LoadingOverlay
extends Control

const DEBOUNCE_SEC := 0.18
const SPINNER_CHARS := "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
const SPIN_INTERVAL_SEC := 0.08
const _CARD_BORDER_ACCENT := Color(0.42, 0.57, 0.82, 1.0)
const _UiMotionEffects = preload("res://logic/ui/ui_motion_effects.gd")

@onready var _root: Control = $Root
@onready var _card: PanelContainer = $Root/Center/Card
@onready var _spinner_label: Label = $Root/Center/Card/Margin/VBox/SpinnerLabel
@onready var _message_label: Label = $Root/Center/Card/Margin/VBox/MessageLabel

var _ref_count := 0
var _debounce_token := 0
var _spin_index := 0
var _spin_accum := 0.0
var _custom_message := ""


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	add_to_group("locale_refresh")
	apply_locale()


func apply_locale() -> void:
	if _custom_message == "":
		_set_message(tr("UI_LOADING_WAIT"))


func _process(delta: float) -> void:
	if not visible:
		return
	_spin_accum += delta
	if _spin_accum < SPIN_INTERVAL_SEC:
		return
	_spin_accum = 0.0
	_spin_index = (_spin_index + 1) % SPINNER_CHARS.length()
	if _spinner_label:
		_spinner_label.text = SPINNER_CHARS[_spin_index]


func show_loading(message: String = "", immediate: bool = false) -> void:
	var was_idle := _ref_count == 0
	_ref_count += 1
	if was_idle:
		_set_input_block(true)
	if message.strip_edges() != "":
		_custom_message = message
		_set_message(message)
	else:
		_custom_message = ""
		_set_message(tr("UI_LOADING_WAIT"))
	if _ref_count == 1:
		if immediate:
			_debounce_token += 1
			_show_now()
		else:
			_begin_show_debounce()


func hide_loading() -> void:
	_ref_count = maxi(_ref_count - 1, 0)
	if _ref_count == 0:
		_debounce_token += 1
		_hide_now()


func reset_loading() -> void:
	_ref_count = 0
	_debounce_token += 1
	_set_input_block(false)
	_hide_now()


func is_active() -> bool:
	return _ref_count > 0


func _set_input_block(enabled: bool) -> void:
	set_process_unhandled_input(enabled)
	set_process_shortcut_input(enabled)


func _unhandled_input(event: InputEvent) -> void:
	if _ref_count <= 0:
		return
	accept_event()
	var viewport := get_viewport()
	if viewport:
		viewport.set_input_as_handled()


func _shortcut_input(event: InputEvent) -> void:
	if _ref_count <= 0:
		return
	accept_event()
	var viewport := get_viewport()
	if viewport:
		viewport.set_input_as_handled()


func _set_message(text: String) -> void:
	if _message_label:
		_message_label.text = text


func _begin_show_debounce() -> void:
	_debounce_token += 1
	var token := _debounce_token
	await get_tree().create_timer(DEBOUNCE_SEC).timeout
	if token != _debounce_token or _ref_count <= 0:
		return
	_show_now()


func _show_now() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _root:
		_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_spin_index = 0
	_spin_accum = 0.0
	if _spinner_label:
		_spinner_label.text = SPINNER_CHARS[0]
	set_process(true)
	if _card:
		_UiMotionEffects.pulse_panel_border(_card, _CARD_BORDER_ACCENT, 0.45, 0.95, 0.75)


func _hide_now() -> void:
	if _card:
		_UiMotionEffects.stop_panel_border_pulse(_card)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	if _ref_count <= 0:
		_set_input_block(false)
	_custom_message = ""
