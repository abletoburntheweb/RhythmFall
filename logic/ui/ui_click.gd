# logic/ui/ui_click.gd
## Утилита для привязки кликов (ЛКМ) к Control через сигнал gui_input,
## чтобы не дублировать в каждом скрипте проверку
## `if event is InputEventMouseButton and event.pressed and ...`.
class_name UiClick
extends RefCounted


## Подписывает control на клик ЛКМ (нажатие). callback вызывается без аргументов.
## guard (опц.): Callable() -> bool — клик сработает только если вернёт true.
## handled (по умолч. true): событие помечается обработанным — не всплывает к
## родительским контролам и не протекает сквозь модалки на слои ниже.
static func connect_clicked(control: Control, callback: Callable, guard: Callable = Callable(), handled: bool = true) -> void:
	var handler := Callable(_on_gui_input).bind(control, callback, guard, handled)
	if not control.gui_input.is_connected(handler):
		control.gui_input.connect(handler)


## Глушит клики на control (для поповеров/панелей поверх модалок, чтобы клик
## по ним не закрывал родительское окно).
static func consume_clicks(control: Control) -> void:
	var handler := Callable(_consume).bind(control)
	if not control.gui_input.is_connected(handler):
		control.gui_input.connect(handler)


static func _on_gui_input(event: InputEvent, control: Control, callback: Callable, guard: Callable, handled: bool) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if guard.is_valid() and not guard.call():
		return
	if handled:
		control.get_viewport().set_input_as_handled()
	callback.call()


static func _consume(event: InputEvent, control: Control) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed:
		control.get_viewport().set_input_as_handled()
