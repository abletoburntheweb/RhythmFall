# ui/overlays/app_overlay_base.gd
class_name AppOverlayBase
extends Control

const Z_INDEX := 120

@onready var _backdrop: ColorRect = %Backdrop

var _dismissed := false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _backdrop:
		_backdrop.gui_input.connect(_on_backdrop_gui_input)


func present() -> void:
	_dismissed = false
	_ensure_fullscreen()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = maxi(z_index, Z_INDEX)
	move_to_front()
	set_process_input(true)


func dismiss() -> void:
	if _dismissed:
		return
	_dismissed = true
	set_process_input(false)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func try_dismiss() -> bool:
	if _dismissed:
		return false
	dismiss()
	return true


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _is_escape_event(event):
		_on_escape_pressed()
		get_viewport().set_input_as_handled()
		return
	if _is_confirm_event(event):
		_on_confirm_key_pressed()
		get_viewport().set_input_as_handled()


func _is_confirm_event(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_accept"):
		return true
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return key_event.pressed and not key_event.echo and key_event.keycode == KEY_SPACE
	return false


func _on_confirm_key_pressed() -> void:
	pass


static func _is_escape_event(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel"):
		return true
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE
	return false


func _on_escape_pressed() -> void:
	_on_backdrop_pressed()


func _ensure_fullscreen() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_backdrop_pressed()


func _on_backdrop_pressed() -> void:
	pass
