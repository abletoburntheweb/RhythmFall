# logic/utils/accuracy_timeline.gd
extends RefCounted
class_name AccuracyTimeline


static func build_chart_points(
	samples: Array,
	duration_sec: float,
	width: float,
	height: float,
	final_accuracy: float,
	padding: float = 10.0
) -> PackedVector2Array:
	if width <= padding * 2.0 or height <= padding * 2.0:
		return PackedVector2Array()

	var duration := maxf(duration_sec, 0.001)
	var plot_w := width - padding * 2.0
	var plot_h := height - padding * 2.0

	var normalized: Array[Dictionary] = []
	normalized.append({"t": 0.0, "acc": 100.0})

	for raw in samples:
		if not raw is Dictionary:
			continue
		var t := maxf(0.0, float(raw.get("t", 0.0)))
		var acc := clampf(float(raw.get("acc", 0.0)), 0.0, 100.0)
		normalized.append({"t": t, "acc": acc})

	if normalized.size() == 1 and final_accuracy > 0.0:
		normalized.append({"t": duration * 0.5, "acc": final_accuracy})

	var last_t := float(normalized[normalized.size() - 1].get("t", 0.0))
	var end_acc := clampf(final_accuracy, 0.0, 100.0)
	if last_t < duration or normalized.size() == 1:
		normalized.append({"t": duration, "acc": end_acc})
	else:
		normalized[normalized.size() - 1]["acc"] = end_acc
		normalized[normalized.size() - 1]["t"] = maxf(last_t, duration)

	var dense: Array[Dictionary] = []
	for i in normalized.size():
		var cur: Dictionary = normalized[i]
		if dense.is_empty():
			dense.append(cur)
			continue
		var prev: Dictionary = dense[dense.size() - 1]
		var t0 := float(prev.get("t", 0.0))
		var a0 := float(prev.get("acc", 0.0))
		var t1 := float(cur.get("t", 0.0))
		var a1 := float(cur.get("acc", 0.0))
		if t1 <= t0:
			continue
		var steps := 4
		for step in range(1, steps + 1):
			var u := float(step) / float(steps)
			dense.append({
				"t": lerpf(t0, t1, u),
				"acc": lerpf(a0, a1, u),
			})

	var points := PackedVector2Array()
	for entry in dense:
		var t := float(entry.get("t", 0.0))
		var acc := float(entry.get("acc", 0.0))
		var x := padding + (t / duration) * plot_w
		var y := padding + plot_h - (acc / 100.0) * plot_h
		points.append(Vector2(x, y))
	return points


static func points_up_to_progress(full: PackedVector2Array, progress: float) -> PackedVector2Array:
	if full.is_empty():
		return PackedVector2Array()
	var p := clampf(progress, 0.0, 1.0)
	if p <= 0.0:
		return PackedVector2Array([full[0]])
	if p >= 1.0:
		return full.duplicate()

	var max_idx := full.size() - 1
	var f := p * float(max_idx)
	var idx := int(floor(f))
	var frac := f - float(idx)
	var out := PackedVector2Array()
	for i in range(idx + 1):
		out.append(full[i])
	if frac > 0.001 and idx < max_idx:
		out.append(full[idx].lerp(full[idx + 1], frac))
	return out
