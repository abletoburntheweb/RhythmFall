class_name ChartCurveUtils
extends RefCounted


static func catmull_rom(points: PackedVector2Array, segments_per_span: int = 6) -> PackedVector2Array:
	if points.size() < 2:
		return points
	var out: PackedVector2Array = PackedVector2Array()
	var step_count := maxi(segments_per_span, 1)
	for i in range(points.size() - 1):
		var p0 := points[maxi(i - 1, 0)]
		var p1 := points[i]
		var p2 := points[i + 1]
		var p3 := points[mini(i + 2, points.size() - 1)]
		for step in range(step_count + 1):
			if i > 0 and step == 0:
				continue
			var t := float(step) / float(step_count)
			out.append(_catmull_rom_point(p0, p1, p2, p3, t))
	return out


static func fill_polygon_under_curve(curve: PackedVector2Array, baseline_y: float, left_x: float, right_x: float) -> PackedVector2Array:
	if curve.is_empty():
		return PackedVector2Array()
	var polygon := PackedVector2Array()
	polygon.append(Vector2(left_x, baseline_y))
	for point in curve:
		polygon.append(point)
	polygon.append(Vector2(right_x, baseline_y))
	return polygon


static func _catmull_rom_point(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * (
		(2.0 * p1)
		+ (-p0 + p2) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)
