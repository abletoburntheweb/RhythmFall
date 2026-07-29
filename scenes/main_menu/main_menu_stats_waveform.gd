extends Control

const _BAR_COLOR := Color(0.35, 0.82, 0.72, 0.32)
const _BAR_COUNT := 28


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var bar_gap := 3.0
	var bar_w := maxf(2.0, (size.x - bar_gap * float(_BAR_COUNT - 1)) / float(_BAR_COUNT))
	for i in range(_BAR_COUNT):
		var phase := float(i) * 0.55
		var wave := absf(sin(phase)) * 0.55 + absf(cos(phase * 0.47)) * 0.35
		var bar_h := size.y * (0.18 + wave * 0.72)
		var x := float(i) * (bar_w + bar_gap)
		draw_rect(Rect2(x, size.y - bar_h, bar_w, bar_h), _BAR_COLOR)
