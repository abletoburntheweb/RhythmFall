# logic/domain/rhythm/groove_addiction_schedule.gd
extends RefCounted
class_name GrooveAddictionSchedule

const _DynamicLanesSchedule = preload("res://logic/domain/rhythm/dynamic_lanes_schedule.gd")


static func build_from_dna(dna: Dictionary, song_duration: float) -> Array:
	var raw := _DynamicLanesSchedule.build_structure_segments_from_dna(dna)
	if raw.is_empty() and song_duration > 0.01:
		raw = _fallback_segments(song_duration)
	if raw.is_empty():
		return []
	var groove_f := _groove_float(dna)
	var schedule := _coalesce_segments(raw)
	var out: Array = []
	for seg in schedule:
		if not seg is Dictionary:
			continue
		var entry: Dictionary = (seg as Dictionary).duplicate()
		entry["is_groove"] = _segment_is_groove(entry, groove_f)
		out.append(entry)
	return out


static func segment_index_at(schedule: Array, song_time: float) -> int:
	if schedule.is_empty():
		return 0
	for i in range(schedule.size()):
		var seg = schedule[i]
		if not seg is Dictionary:
			continue
		var start_s := float(seg.get("start_s", 0.0))
		var end_s := maxf(float(seg.get("end_s", start_s)), start_s)
		if song_time >= start_s and song_time < end_s:
			return i
	return schedule.size() - 1


static func is_groove_segment(schedule: Array, song_time: float) -> bool:
	if schedule.is_empty():
		return false
	var seg: Dictionary = schedule[segment_index_at(schedule, song_time)]
	return bool(seg.get("is_groove", false))


static func tier_multipliers(
	tier: int,
	max_tier: int,
	scroll_pct: float,
	timing_pct: float
) -> Dictionary:
	var max_t := maxi(max_tier, 1)
	var t := clampf(float(tier) / float(max_t), 0.0, 1.0)
	return {
		"scroll_mult": lerpf(1.0, scroll_pct / 100.0, t),
		"timing_mult": lerpf(1.0, timing_pct / 100.0, t),
	}


static func _segment_is_groove(seg: Dictionary, groove_f: float) -> bool:
	if groove_f < 0.35:
		groove_f = 0.35
	var kind := String(seg.get("kind", "steady"))
	if kind in ["quiet", "sparse"]:
		return false
	var intensity := groove_f
	if kind == "dense":
		intensity = clampf(intensity + 0.25, 0.0, 1.0)
	elif kind == "steady":
		intensity *= 0.75
	return intensity >= 0.45


static func _groove_float(dna: Dictionary) -> float:
	var genes: Dictionary = dna.get("genes", {}) if dna.get("genes", {}) is Dictionary else {}
	var rhythm: Dictionary = genes.get("rhythm", {}) if genes.get("rhythm", {}) is Dictionary else {}
	var level := String(rhythm.get("groove_stability", "medium"))
	match String(level).strip_edges():
		"high":
			return 1.0
		"low":
			return 0.25
		_:
			return 0.55


static func _fallback_segments(duration: float) -> Array:
	return [
		{"start_s": 0.0, "end_s": duration * 0.25, "kind": "quiet"},
		{"start_s": duration * 0.25, "end_s": duration * 0.50, "kind": "steady"},
		{"start_s": duration * 0.50, "end_s": duration * 0.75, "kind": "steady"},
		{"start_s": duration * 0.75, "end_s": duration, "kind": "dense"},
	]


static func _coalesce_segments(raw: Array) -> Array:
	if raw.is_empty():
		return raw
	var sorted: Array = raw.duplicate(true)
	sorted.sort_custom(func(a, b): return float(a.get("start_s", 0.0)) < float(b.get("start_s", 0.0)))
	var merged: Array = []
	for seg in sorted:
		if not seg is Dictionary:
			continue
		var entry: Dictionary = (seg as Dictionary).duplicate()
		if merged.is_empty():
			merged.append(entry)
			continue
		var last: Dictionary = merged[-1]
		if String(last.get("kind", "steady")) == String(entry.get("kind", "steady")):
			last["end_s"] = maxf(float(last.get("end_s", 0.0)), float(entry.get("end_s", 0.0)))
		else:
			merged.append(entry)
	return merged
