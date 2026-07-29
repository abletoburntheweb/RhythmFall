# scenes/profile/chart_point.gd
class_name ChartPoint
extends Control

@export var point_color: Color = Color.RED
@export var point_radius: float = 6.0
@export var border_width: float = 1.5
@export var border_color: Color = Color.BLACK

var grade_label: String = ""
var is_hovered: bool = false

const HIT_PADDING := 8.0


func _ready() -> void:
	_update_layout_size()
	pivot_offset = Vector2.ZERO
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)


func _draw() -> void:
	var center := _draw_center()
	if border_width > 0:
		draw_circle(center, point_radius + border_width, border_color)
	draw_circle(center, point_radius, point_color)

	if grade_label != "":
		var font := ThemeDB.fallback_font
		var font_size := 9
		var text_size := font.get_string_size(grade_label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(
			font,
			Vector2(center.x - text_size.x * 0.5, size.y - 2.0),
			grade_label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			point_color
		)

	if is_hovered:
		draw_circle(center, point_radius + 2.0, Color(1.0, 1.0, 1.0, 0.22))


func _draw_center() -> Vector2:
	return Vector2(size.x * 0.5, point_radius + border_width + HIT_PADDING * 0.5)


func get_point_center() -> Vector2:
	return _draw_center()


func set_point_tooltip(text: String) -> void:
	tooltip_text = text


func set_grade_label(text: String) -> void:
	grade_label = text.strip_edges()
	_update_layout_size()
	queue_redraw()


func _update_layout_size() -> void:
	var diameter := (point_radius + border_width) * 2.0 + HIT_PADDING
	var extra_height := 12.0 if grade_label != "" else 0.0
	size = Vector2(diameter, diameter + extra_height)


func _on_mouse_entered() -> void:
	var parent := get_parent()
	if parent:
		for sibling in parent.get_children():
			if sibling != self and sibling is ChartPoint:
				(sibling as ChartPoint).clear_hover()
	if not is_hovered:
		is_hovered = true
		queue_redraw()


func clear_hover() -> void:
	if is_hovered:
		is_hovered = false
		queue_redraw()


func _on_mouse_exited() -> void:
	if is_hovered:
		is_hovered = false
		queue_redraw()
