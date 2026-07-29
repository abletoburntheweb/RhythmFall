# scenes/song_select/rhythm_dna_decision_donut.gd
extends Control
class_name RhythmDnaDecisionDonut

const TAU_F := PI * 2.0

var _removed: int = 0
var _added: int = 0
var _corrected: int = 0
var _saved: int = 0
var _total: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(132, 132)


func configure(gene: Dictionary) -> void:
	_removed = maxi(0, int(gene.get("removed", 0)))
	_added = maxi(0, int(gene.get("added", 0)))
	_corrected = maxi(0, int(gene.get("corrected", 0)))
	_saved = maxi(0, int(gene.get("saved", 0)))
	_total = maxi(1, int(gene.get("total", 0)))
	if _removed + _added + _corrected + _saved <= 0:
		_saved = 1
		_total = 1
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var outer_r: float = minf(size.x, size.y) * 0.46
	var inner_r: float = outer_r * 0.58
	if outer_r <= 4.0:
		return
	var start := -PI * 0.5
	var slices: Array = [
		[_removed, Color(0.91, 0.45, 0.38, 0.95)],
		[_added, Color(0.38, 0.78, 0.74, 0.95)],
		[_saved, Color(0.45, 0.68, 0.95, 0.95)],
	]
	for slice in slices:
		var weight: int = int(slice[0])
		if weight <= 0:
			continue
		var sweep: float = TAU_F * float(weight) / float(_total)
		_draw_ring_slice(center, inner_r, outer_r, start, start + sweep, slice[1] as Color)
		start += sweep
	draw_circle(center, inner_r - 1.0, Color(0.06, 0.07, 0.11, 1.0))
	var font := ThemeDB.fallback_font
	var total_text := str(_total)
	var total_size := 24
	var total_width := font.get_string_size(total_text, HORIZONTAL_ALIGNMENT_CENTER, -1, total_size).x
	draw_string(
		font,
		center - Vector2(total_width * 0.5, -total_size * 0.35),
		total_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		total_size,
		Color(0.9, 0.93, 0.98, 1.0)
	)
	var caption := TranslationServer.translate("DNA_DONUT_DECISIONS")
	var cap_size := 11
	var cap_width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_CENTER, -1, cap_size).x
	draw_string(
		font,
		center - Vector2(cap_width * 0.5, total_size * 0.45),
		caption,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		cap_size,
		Color(0.62, 0.68, 0.76, 0.92)
	)


func _draw_ring_slice(
	center: Vector2,
	inner_r: float,
	outer_r: float,
	start_rad: float,
	end_rad: float,
	color: Color
) -> void:
	if end_rad <= start_rad:
		return
	var steps: int = maxi(8, int((end_rad - start_rad) * 28.0))
	var points := PackedVector2Array()
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var angle: float = lerpf(start_rad, end_rad, t)
		points.append(center + Vector2(cos(angle), sin(angle)) * outer_r)
	for i in range(steps, -1, -1):
		var t: float = float(i) / float(steps)
		var angle: float = lerpf(start_rad, end_rad, t)
		points.append(center + Vector2(cos(angle), sin(angle)) * inner_r)
	if points.size() >= 3:
		draw_colored_polygon(points, color)
