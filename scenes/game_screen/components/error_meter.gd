# scenes/game_screen/components/error_meter.gd
extends Control
class_name ErrorMeter

const KIND_PERFECT := "perfect"
const KIND_GOOD := "good"
const KIND_MISS := "miss"

const DEFAULT_CAPACITY := 20
const BAR_HEIGHT := 14.0

@export var capacity: int = DEFAULT_CAPACITY
@export var max_display_ms: float = 150.0
@export var tick_width: float = 2.0
@export var tick_height_perfect: float = 10.0
@export var tick_height_good: float = 8.0
@export var miss_marker_size: float = 3.0
@export var color_perfect: Color = Color(1.0, 0.92, 0.45, 0.95)
@export var color_good: Color = Color(0.45, 0.82, 0.98, 0.92)
@export var color_miss: Color = Color(0.92, 0.38, 0.42, 0.95)
@export var color_axis: Color = Color(0.82, 0.88, 0.96, 0.55)
@export var color_bg: Color = Color(0.05, 0.07, 0.11, 0.88)
@export var color_perfect_zone: Color = Color(0.45, 0.72, 0.96, 0.14)

var _entries: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	custom_minimum_size = Vector2(120, 20)
	resized.connect(queue_redraw)


func clear() -> void:
	_entries.clear()
	queue_redraw()


func set_max_display_ms(ms: float) -> void:
	max_display_ms = maxf(20.0, ms)
	queue_redraw()


func push_entry(kind: String, signed_ms: float = 0.0) -> void:
	if capacity <= 0:
		return
	if _entries.size() >= capacity:
		_entries.pop_front()
	_entries.append({
		"kind": kind,
		"signed_ms": signed_ms,
	})
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 8.0 or h < 4.0:
		return

	var bar_h := minf(BAR_HEIGHT, h - 2.0)
	var bar_top := (h - bar_h) * 0.5
	var bar_rect := Rect2(0.0, bar_top, w, bar_h)
	var center_x := w * 0.5
	var half_span := maxf(4.0, center_x - 6.0)
	var clamp_ms := maxf(1.0, max_display_ms)
	var radius := minf(6.0, bar_h * 0.5)

	var bg := StyleBoxFlat.new()
	bg.bg_color = color_bg
	bg.set_corner_radius_all(int(radius))
	bg.corner_detail = 8
	bg.draw(get_canvas_item(), bar_rect)

	var perfect_ms := clamp_ms * 0.33
	var perfect_half_px := (perfect_ms / clamp_ms) * half_span
	var zone := StyleBoxFlat.new()
	zone.bg_color = color_perfect_zone
	zone.set_corner_radius_all(maxi(2, int(radius) - 1))
	zone.corner_detail = 8
	zone.draw(
		get_canvas_item(),
		Rect2(center_x - perfect_half_px, bar_top, perfect_half_px * 2.0, bar_h)
	)

	draw_line(
		Vector2(center_x, bar_top + 1.0),
		Vector2(center_x, bar_top + bar_h - 1.0),
		color_axis,
		1.0
	)

	for entry in _entries:
		var kind: String = str(entry.get("kind", KIND_MISS))
		var signed_ms: float = float(entry.get("signed_ms", 0.0))
		var norm := clampf(signed_ms / clamp_ms, -1.0, 1.0)
		var x := center_x + norm * half_span

		if kind == KIND_MISS:
			# Keep markers inside the rounded bar so they don't spill past playfield clip.
			var y := bar_top + bar_h - 1.0
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(x - miss_marker_size, y - miss_marker_size - 1.0),
					Vector2(x + miss_marker_size, y - miss_marker_size - 1.0),
					Vector2(x, y),
				]),
				color_miss
			)
			continue

		var tick_h := tick_height_good
		var col := color_good
		if kind == KIND_PERFECT:
			tick_h = tick_height_perfect
			col = color_perfect

		var y0 := bar_top + (bar_h - tick_h) * 0.5
		draw_line(Vector2(x, y0), Vector2(x, y0 + tick_h), col, tick_width)
