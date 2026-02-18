extends HBoxContainer
class_name NotificationUI

@onready var label: Label = $NotificationLabel
@onready var cancel_btn: BaseButton = $CancelButton
@onready var retry_btn: BaseButton = $RetryButton

var _clear_token: int = 0
var on_cancel: Callable = Callable()
var on_retry: Callable = Callable()

func _ready():
	if cancel_btn and not cancel_btn.is_connected("pressed", _on_cancel_pressed):
		cancel_btn.pressed.connect(_on_cancel_pressed)
	if retry_btn and not retry_btn.is_connected("pressed", _on_retry_pressed):
		retry_btn.pressed.connect(_on_retry_pressed)
	_clear_immediate()

func show_progress(text: String, cancel_callable: Callable):
	label.text = text
	label.visible = true
	on_retry = Callable()
	retry_btn.visible = false
	on_cancel = cancel_callable
	cancel_btn.visible = cancel_callable.is_valid()
	_clear_token = Time.get_ticks_msec()

func show_error(text: String, retry_callable: Callable, cancel_callable: Callable):
	label.text = text
	label.visible = true
	on_retry = retry_callable
	on_cancel = cancel_callable
	var is_cancel_text = _is_cancel_text(text)
	cancel_btn.visible = cancel_callable.is_valid() and not is_cancel_text
	retry_btn.visible = retry_callable.is_valid()
	var token = Time.get_ticks_msec()
	_clear_token = token
	await get_tree().create_timer(5.0).timeout
	if _clear_token == token:
		_clear_immediate()

func show_complete(text: String):
	label.text = text
	label.visible = true
	cancel_btn.visible = false
	retry_btn.visible = false
	var token = Time.get_ticks_msec()
	_clear_token = token
	await get_tree().create_timer(5.0).timeout
	if _clear_token == token:
		_clear_immediate()

func clear_immediately():
	_clear_immediate()

func _clear_immediate():
	if label:
		label.text = ""
		label.visible = false
	if cancel_btn:
		cancel_btn.visible = false
	if retry_btn:
		retry_btn.visible = false
	on_cancel = Callable()
	on_retry = Callable()

func _on_cancel_pressed():
	if on_cancel.is_valid():
		on_cancel.call()
	cancel_btn.visible = false

func _on_retry_pressed():
	if on_retry.is_valid():
		on_retry.call()
	retry_btn.visible = false

func _is_cancel_text(text: String) -> bool:
	var lower = text.to_lower()
	return lower.find("отмен") != -1 or lower.find("cancel") != -1
