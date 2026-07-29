# scenes/victory_screen/victory_accuracy_chart.gd
extends Control

const _Timeline = preload("res://scenes/victory_screen/lib/accuracy_timeline.gd")

const PLOT_PADDING := 10.0
const COLOR_BG := Color(0.045, 0.058, 0.092, 0.96)
const COLOR_GRID := Color(1.0, 1.0, 1.0, 0.055)
const COLOR_GRID_MAJOR := Color(1.0, 1.0, 1.0, 0.09)
const COLOR_FILL_TOP := Color(0.35, 0.84, 0.74, 0.24)
const COLOR_FILL_BOTTOM := Color(0.35, 0.84, 0.74, 0.02)
const COLOR_LINE_GOOD := Color(0.42, 0.9, 0.78, 1.0)
const COLOR_LINE_DIP := Color(0.94, 0.44, 0.5, 1.0)
const COLOR_GLOW := Color(0.35, 0.86, 0.76, 0.35)
const DIP_THRESHOLD_PX := 1.25

var _full_points: PackedVector2Array = PackedVector2Array()
var _draw_progress: float = 0.0
var _anim_tween: Tween = null
var _has_data: bool = false
var _color_bg := COLOR_BG
var _color_fill_top := COLOR_FILL_TOP
var _color_fill_bottom := COLOR_FILL_BOTTOM
var _color_line_good := COLOR_LINE_GOOD
var _color_line_dip := COLOR_LINE_DIP
var _color_glow := COLOR_GLOW


func _ready() -> void:
	custom_minimum_size = Vector2(0, 118)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_on_resized)
	visible = false


func set_accent(accent: Color) -> void:
	## Recolor line/fill to match mode accent (victory cyan by default).
	_color_line_good = accent.lightened(0.12)
	_color_glow = Color(accent.r, accent.g, accent.b, 0.38)
	_color_fill_top = Color(accent.r, accent.g, accent.b, 0.26)
	_color_fill_bottom = Color(accent.r, accent.g, accent.b, 0.02)
	_color_line_dip = Color(0.94, 0.44, 0.5, 1.0)
	queue_redraw()


func setup(samples: Array, duration_sec: float, final_accuracy: float) -> void:
	_has_data = samples.size() > 0 or final_accuracy > 0.0
	if not _has_data:
		_full_points = PackedVector2Array()
		_draw_progress = 0.0
		visible = false
		queue_redraw()
		return

	visible = true
	_rebuild_points(samples, duration_sec, final_accuracy)
	_draw_progress = 0.0
	queue_redraw()


func play_reveal(duration_sec: float = 1.65) -> void:
	if not _has_data or _full_points.size() < 2:
		return
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_draw_progress = 0.0
	queue_redraw()
	_anim_tween = create_tween()
	_anim_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_method(_set_draw_progress, 0.0, 1.0, duration_sec)


func _set_draw_progress(value: float) -> void:
	_draw_progress = value
	queue_redraw()


func _rebuild_points(samples: Array, duration_sec: float, final_accuracy: float) -> void:
	var sz := size
	if sz.x <= 1.0 or sz.y <= 1.0:
		sz = custom_minimum_size
	_full_points = _Timeline.build_chart_points(
		samples,
		duration_sec,
		sz.x,
		sz.y,
		final_accuracy,
		PLOT_PADDING
	)
	queue_redraw()


func _visible_points() -> PackedVector2Array:
	return _Timeline.points_up_to_progress(_full_points, _draw_progress)


func _plot_rect() -> Rect2:
	return Rect2(
		PLOT_PADDING,
		PLOT_PADDING,
		maxf(1.0, size.x - PLOT_PADDING * 2.0),
		maxf(1.0, size.y - PLOT_PADDING * 2.0)
	)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _color_bg, true)
	if not _has_data:
		return
	var plot := _plot_rect()
	_draw_grid(plot)
	var pts := _visible_points()
	if pts.size() < 2:
		return
	_draw_fill(plot, pts)
	_draw_line_segments(pts)
	_draw_head_marker(pts)


func _draw_grid(plot: Rect2) -> void:
	var bottom := plot.position.y + plot.size.y
	for i in range(1, 4):
		var x := plot.position.x + plot.size.x * float(i) / 4.0
		draw_line(Vector2(x, plot.position.y), Vector2(x, bottom), COLOR_GRID, 1.0, true)
	for acc_pct: float in [0.5, 0.75, 1.0]:
		var y: float = bottom - plot.size.y * acc_pct
		var col := COLOR_GRID_MAJOR if acc_pct >= 0.99 else COLOR_GRID
		draw_line(Vector2(plot.position.x, y), Vector2(plot.position.x + plot.size.x, y), col, 1.0, true)


func _draw_fill(plot: Rect2, pts: PackedVector2Array) -> void:
	var bottom := plot.position.y + plot.size.y
	var fill := PackedVector2Array()
	var colors := PackedColorArray()
	for p in pts:
		fill.append(p)
		var t := 1.0 - clampf((p.y - plot.position.y) / plot.size.y, 0.0, 1.0)
		colors.append(_color_fill_top.lerp(_color_fill_bottom, 1.0 - t))
	fill.append(Vector2(pts[pts.size() - 1].x, bottom))
	colors.append(_color_fill_bottom)
	fill.append(Vector2(pts[0].x, bottom))
	colors.append(_color_fill_bottom)
	draw_polygon(fill, colors)


func _draw_line_segments(pts: PackedVector2Array) -> void:
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var dipping := b.y > a.y + DIP_THRESHOLD_PX
		var col := _color_line_dip if dipping else _color_line_good
		draw_line(a, b, _color_glow, 5.0, true)
		draw_line(a, b, col, 2.25, true)


func _draw_head_marker(pts: PackedVector2Array) -> void:
	var head := pts[pts.size() - 1]
	draw_circle(head, 5.5, Color(_color_glow.r, _color_glow.g, _color_glow.b, 0.45))
	draw_circle(head, 2.5, _color_line_good)


func _on_resized() -> void:
	if not _has_data:
		return
	call_deferred("_rebuild_from_cached")


var _cached_samples: Array = []
var _cached_duration: float = 0.0
var _cached_final_acc: float = 0.0


func setup_and_cache(samples: Array, duration_sec: float, final_accuracy: float) -> void:
	_cached_samples = samples.duplicate(true)
	_cached_duration = duration_sec
	_cached_final_acc = final_accuracy
	setup(samples, duration_sec, final_accuracy)


func _rebuild_from_cached() -> void:
	if _cached_samples.is_empty() and _cached_final_acc <= 0.0:
		return
	_rebuild_points(_cached_samples, _cached_duration, _cached_final_acc)
