# res://scenes/profile/chart_point.gd
extends Control

signal point_hovered(position: Vector2, tooltip_text: String)
signal point_unhovered

@export var point_color: Color = Color.RED
@export var point_radius: float = 6.0
@export var border_width: float = 1.5
@export var border_color: Color = Color.BLACK

var custom_tooltip_text: String = ""
var is_hovered: bool = false
var mouse_inside: bool = false

func _ready():
	var diameter = (point_radius + border_width) * 2
	size = Vector2(diameter, diameter)
	pivot_offset = Vector2.ZERO
	mouse_filter = Control.MOUSE_FILTER_STOP

func _draw():
	if border_width > 0:
		draw_circle(size / 2, point_radius + border_width, border_color)
	draw_circle(size / 2, point_radius, point_color)
	
	if is_hovered:
		var inner_radius = point_radius
		var outer_radius = point_radius + 3.0
		for i in range(1, 4):
			var radius = point_radius + float(i)
			draw_circle(size / 2, radius, Color.YELLOW.lerp(point_color, 0.5)) 

func _gui_input(event):
	if event is InputEventMouseMotion:
		var local_mouse_pos = event.position
		var distance = local_mouse_pos.distance_to(size / 2)
		var is_inside_new = distance <= point_radius + border_width
		
		if is_inside_new != mouse_inside:
			mouse_inside = is_inside_new
			if mouse_inside:
				if not is_hovered:
					is_hovered = true
					emit_signal("point_hovered", global_position + size / 2, custom_tooltip_text)
			else:
				if is_hovered:
					is_hovered = false
					emit_signal("point_unhovered")

func set_custom_tooltip_text(text: String):
	custom_tooltip_text = text

func _property_changed_notify():
	queue_redraw()
