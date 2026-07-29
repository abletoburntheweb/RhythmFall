# scenes/victory_screen/victory_reward_bar.gd
extends Control

var fill_ratio: float = 0.0
var accent: Color = Color(0.95, 0.7, 0.35, 1.0)

const TRACK_COLOR := Color(1.0, 1.0, 1.0, 0.08)
const BAR_HEIGHT := 10.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, BAR_HEIGHT)
	if not resized.is_connected(queue_redraw):
		resized.connect(queue_redraw)


func set_fill(ratio: float, bar_accent: Color) -> void:
	fill_ratio = clampf(ratio, 0.0, 1.0)
	accent = bar_accent
	queue_redraw()


func _draw() -> void:
	var w := size.x
	if w <= 1.0:
		return
	var h := BAR_HEIGHT
	var y := (size.y - h) * 0.5
	draw_rect(Rect2(0.0, y, w, h), TRACK_COLOR, true)
	var fill_w := w * fill_ratio
	if fill_w <= 0.5:
		return
	var fill_col := Color(accent.r, accent.g, accent.b, 0.92)
	draw_rect(Rect2(0.0, y, fill_w, h), fill_col, true)
	var tip_w := minf(3.0, fill_w)
	draw_rect(Rect2(fill_w - tip_w, y - 1.0, tip_w, h + 2.0), accent.lightened(0.2), true)
