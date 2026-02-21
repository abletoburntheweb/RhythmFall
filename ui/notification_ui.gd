extends HBoxContainer
class_name NotificationUI

@onready var label: Label = $NotificationLabel
@onready var cancel_btn: BaseButton = $CancelButton
@onready var retry_btn: BaseButton = $RetryButton
@onready var clear_timer: Timer = $ClearTimer

var _clear_token: int = 0
var _pending_token: int = 0
var on_cancel: Callable = Callable()
var on_retry: Callable = Callable()
@export var duration_clear_ms: int = 5000
@export var cancel_hide_keywords: Array[String] = ["отмен", "cancel"]

func _ready():
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
	_schedule_clear()

func show_complete(text: String):
	label.text = text
	label.visible = true
	cancel_btn.visible = false
	retry_btn.visible = false
	_schedule_clear()

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
	for kw in cancel_hide_keywords:
		if lower.find(kw.to_lower()) != -1:
			return true
	return false

func _schedule_clear():
	var token = Time.get_ticks_msec()
	_clear_token = token
	_pending_token = token
	var seconds = float(duration_clear_ms) / 1000.0
	if clear_timer:
		if not clear_timer.is_stopped():
			clear_timer.stop()
		clear_timer.one_shot = true
		clear_timer.wait_time = seconds
		clear_timer.start()
	else:
		await get_tree().create_timer(seconds).timeout
		if _clear_token == token:
			_clear_immediate()

func _on_clear_timeout():
	if _clear_token == _pending_token:
		_clear_immediate()
