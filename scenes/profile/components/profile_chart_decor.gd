extends Control

const PLOT_LEFT := 44.0
const PLOT_RIGHT := 12.0
const PLOT_TOP := 22.0
const PLOT_BOTTOM := 8.0

var metric: String = "accuracy"
var y_min: float = 0.0
var y_max: float = 100.0
var y_tick_labels: PackedStringArray = PackedStringArray(["50%", "75%", "90%", "100%"])
var y_tick_values: PackedFloat32Array = PackedFloat32Array([50.0, 75.0, 90.0, 100.0])

const _ACCURACY_ZONES: Array = [
	[95.0, 100.0, Color(0.95, 0.78, 0.35, 0.08)],
	[90.0, 95.0, Color(0.42, 0.57, 0.82, 0.06)],
	[80.0, 90.0, Color(0.35, 0.82, 0.75, 0.05)],
	[75.0, 80.0, Color(0.65, 0.52, 0.82, 0.04)],
]


func get_plot_rect() -> Rect2:
	return Rect2(
		PLOT_LEFT,
		PLOT_TOP,
		maxf(0.0, size.x - PLOT_LEFT - PLOT_RIGHT),
		maxf(0.0, size.y - PLOT_TOP - PLOT_BOTTOM)
	)


func value_to_y(value: float) -> float:
	var plot := get_plot_rect()
	if plot.size.y <= 0.0:
		return plot.position.y
	var span := y_max - y_min
	var t := 0.0 if span <= 0.0 else clampf((value - y_min) / span, 0.0, 1.0)
	return plot.position.y + plot.size.y * (1.0 - t)


func session_index_to_x(index: int, session_count: int) -> float:
	var plot := get_plot_rect()
	if session_count <= 1:
		return plot.position.x + plot.size.x * 0.5
	return plot.position.x + index * (plot.size.x / float(session_count - 1))


func configure(p_metric: String, p_y_min: float, p_y_max: float, tick_values: PackedFloat32Array, tick_labels: PackedStringArray) -> void:
	metric = p_metric
	y_min = p_y_min
	y_max = p_y_max
	y_tick_values = tick_values
	y_tick_labels = tick_labels
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var plot := get_plot_rect()
	if plot.size.x <= 0.0 or plot.size.y <= 0.0:
		return

	if metric == "accuracy":
		for zone in _ACCURACY_ZONES:
			_draw_value_zone(plot, float(zone[0]), float(zone[1]), zone[2] as Color)

	var font := ThemeDB.fallback_font
	var font_size := 10
	for i in range(y_tick_values.size()):
		var tick_value := y_tick_values[i]
		var y := value_to_y(tick_value)
		draw_line(
			Vector2(plot.position.x, y),
			Vector2(plot.position.x + plot.size.x, y),
			Color(1.0, 1.0, 1.0, 0.11),
			1.0
		)
		var label := y_tick_labels[i] if i < y_tick_labels.size() else str(tick_value)
		var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(
			font,
			Vector2(plot.position.x - label_size.x - 6.0, y + label_size.y * 0.32),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color(0.72, 0.76, 0.84, 0.9)
		)


func _draw_value_zone(plot: Rect2, low: float, high: float, color: Color) -> void:
	var y_top := value_to_y(high)
	var y_bottom := value_to_y(low)
	draw_rect(Rect2(plot.position.x, y_top, plot.size.x, y_bottom - y_top), color)
