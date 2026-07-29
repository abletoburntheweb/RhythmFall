# scenes/song_select/run_modifiers/run_modifier_card_border.gd
extends Panel

@export var dash_color: Color = Color(0.98, 0.32, 0.28, 0.95)
@export var line_width: float = 2.0
@export var dash_length: float = 5.0
@export var dash_gap: float = 3.0
@export var corner_inset: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed() -> void:
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var rect := Rect2(
		Vector2(corner_inset, corner_inset),
		size - Vector2(corner_inset * 2.0, corner_inset * 2.0)
	)
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	var tl := rect.position
	var tr := rect.position + Vector2(rect.size.x, 0.0)
	var br := rect.position + rect.size
	var bl := rect.position + Vector2(0.0, rect.size.y)
	_draw_dashed_segment(tl, tr)
	_draw_dashed_segment(tr, br)
	_draw_dashed_segment(br, bl)
	_draw_dashed_segment(bl, tl)


func _draw_dashed_segment(from: Vector2, to: Vector2) -> void:
	var delta := to - from
	var length := delta.length()
	if length <= 0.001:
		return
	var dir := delta / length
	var pos := 0.0
	var draw_dash := true
	while pos < length:
		var seg_len := dash_length if draw_dash else dash_gap
		var next_pos := minf(pos + seg_len, length)
		if draw_dash:
			draw_line(from + dir * pos, from + dir * next_pos, dash_color, line_width, true)
		pos = next_pos
		draw_dash = not draw_dash
