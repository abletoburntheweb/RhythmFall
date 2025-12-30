# res://scenes/profile/chart_point.gd
extends Control

@export var point_color: Color = Color.RED
@export var point_radius: float = 6.0
@export var border_width: float = 1.5
@export var border_color: Color = Color.BLACK

func _ready():
	var diameter = (point_radius + border_width) * 2
	size = Vector2(diameter, diameter)
	pivot_offset = Vector2.ZERO

func _draw():
	if border_width > 0:
		draw_circle(size / 2, point_radius + border_width, border_color)
	draw_circle(size / 2, point_radius, point_color)

func _property_changed_notify():
	queue_redraw()
