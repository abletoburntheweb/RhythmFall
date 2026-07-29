# scenes/victory_screen/victory_lane_stats.gd
# Компактный «эквалайзер» точности по линиям для экрана победы: по столбику на
# каждую отображаемую линию, высота = доля попаданий, цвет — по качеству, а самая
# слабая линия дополнительно подсвечивается, чтобы игрок сразу увидел «провис».
extends Control

const COLOR_HIGH := Color(0.42, 0.9, 0.78, 1.0)
const COLOR_MID := Color(0.55, 0.78, 0.98, 1.0)
const COLOR_WARN := Color(0.95, 0.82, 0.42, 1.0)
const COLOR_LOW := Color(0.94, 0.44, 0.5, 1.0)
const COLOR_TRACK := Color(1.0, 1.0, 1.0, 0.06)
const COLOR_LABEL := Color(0.62, 0.7, 0.82, 0.9)
const COLOR_VALUE := Color(0.9, 0.94, 0.98, 1.0)

const PAD_X := 8.0
const PAD_Y := 4.0
const TOP_TEXT_H := 15.0
const BOTTOM_TEXT_H := 15.0
const BAR_WIDTH_RATIO := 0.44
const BAR_WIDTH_MAX := 46.0
const WEAK_LANE_THRESHOLD := 90.0

var _stats: Array = []
var _weak_lane: int = -1


func _ready() -> void:
	custom_minimum_size = Vector2(0, 74)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not resized.is_connected(queue_redraw):
		resized.connect(queue_redraw)
	visible = false


func setup(lane_stats: Array) -> void:
	_stats = []
	for raw in lane_stats:
		if raw is Dictionary:
			_stats.append(raw)
	_weak_lane = -1
	var worst := 200.0
	for i in _stats.size():
		var total := int(_stats[i].get("total", 0))
		var acc := float(_stats[i].get("acc", 100.0))
		if total > 0 and acc < worst:
			worst = acc
			_weak_lane = i
	# Слабую линию подсвечиваем, только если она реально просела.
	if worst >= WEAK_LANE_THRESHOLD:
		_weak_lane = -1
	# Показываем при 2+ линиях чарта (даже если на части линий не было нот).
	visible = _stats.size() >= 2
	queue_redraw()


func has_data() -> bool:
	return _stats.size() >= 2


func _bar_color(acc: float) -> Color:
	if acc >= 95.0:
		return COLOR_HIGH
	if acc >= 85.0:
		return COLOR_MID
	if acc >= 70.0:
		return COLOR_WARN
	return COLOR_LOW


func _draw() -> void:
	if _stats.size() < 2:
		return
	var font := get_theme_default_font()
	var value_fs := 13
	var label_fs := 11
	var sz := size
	var top := PAD_Y + TOP_TEXT_H
	var bottom := sz.y - PAD_Y - BOTTOM_TEXT_H
	var plot_h := maxf(8.0, bottom - top)
	var n := _stats.size()
	var col_w := (sz.x - PAD_X * 2.0) / float(n)
	for i in n:
		var d: Dictionary = _stats[i]
		var total_notes := int(d.get("total", 0))
		var acc := clampf(float(d.get("acc", 100.0)), 0.0, 100.0)
		var lane_no := int(d.get("lane", i)) + 1
		var cx := PAD_X + col_w * (float(i) + 0.5)
		var bw := minf(col_w * BAR_WIDTH_RATIO, BAR_WIDTH_MAX)
		var x0 := cx - bw * 0.5
		draw_rect(Rect2(x0, top, bw, plot_h), COLOR_TRACK, true)
		var fill_h := plot_h * (acc / 100.0) if total_notes > 0 else 0.0
		var fill_y := top + plot_h - fill_h
		var col := _bar_color(acc) if total_notes > 0 else COLOR_LABEL
		if i == _weak_lane:
			draw_rect(
				Rect2(x0 - 3.0, fill_y - 3.0, bw + 6.0, fill_h + 6.0),
				Color(col.r, col.g, col.b, 0.2),
				true
			)
		draw_rect(Rect2(x0, fill_y, bw, fill_h), col, true)
		if font == null:
			continue
		var value_str := "—" if total_notes <= 0 else "%d%%" % int(round(acc))
		var value_w := font.get_string_size(
			value_str, HORIZONTAL_ALIGNMENT_LEFT, -1, value_fs
		).x
		draw_string(
			font,
			Vector2(cx - value_w * 0.5, top - 4.0),
			value_str,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			value_fs,
			col if i == _weak_lane else COLOR_VALUE
		)
		var lane_str := "L%d" % lane_no
		var lane_w := font.get_string_size(
			lane_str, HORIZONTAL_ALIGNMENT_LEFT, -1, label_fs
		).x
		var lane_col := COLOR_LOW if i == _weak_lane else COLOR_LABEL
		draw_string(
			font,
			Vector2(cx - lane_w * 0.5, sz.y - PAD_Y - 2.0),
			lane_str,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			label_fs,
			lane_col
		)
