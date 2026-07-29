# logic/domain/rhythm/density_focus_schedule.gd
extends RefCounted
class_name DensityFocusSchedule

const _DynamicLanesSchedule = preload("res://logic/domain/rhythm/dynamic_lanes_schedule.gd")

const BLEND_SEC_MIN := 0.5
const BLEND_SEC_MAX := 2.0
const BLEND_FRAC := 0.2


static func kind_intensity(kind: String) -> float:
	match String(kind).strip_edges():
		"quiet", "sparse":
			return 0.0
		"dense", "loud_quiet":
			return 1.0
		_:
			return 0.35


static func build_from_dna(dna: Dictionary, song_duration: float) -> Array:
	var raw := _DynamicLanesSchedule.build_structure_segments_from_dna(dna)
	if not raw.is_empty():
		return _coalesce_by_kind(raw)
	if song_duration > 0.01:
		return _coalesce_by_kind(_fallback_progressive_schedule(song_duration))
	return [{"start_s": 0.0, "end_s": 999999.0, "kind": "steady", "intensity": 0.35}]


static func enrich_with_chart_notes(schedule: Array, notes: Array) -> Array:
	if schedule.is_empty():
		return schedule
	var out: Array = []
	var nps_values: Array = []
	for seg in schedule:
		if not seg is Dictionary:
			continue
		var entry: Dictionary = (seg as Dictionary).duplicate()
		var start_s := float(entry.get("start_s", 0.0))
		var end_s := maxf(float(entry.get("end_s", start_s)), start_s)
		var duration := maxf(end_s - start_s, 0.01)
		var count := 0
		for note in notes:
			if not note is Dictionary:
				continue
			var t := float(note.get("time", -1.0))
			if t >= start_s and t < end_s:
				count += 1
		var nps := float(count) / duration
		entry["notes_per_sec"] = nps
		nps_values.append(nps)
		out.append(entry)
	if out.is_empty():
		return out
	nps_values.sort()
	var median_nps := float(nps_values[nps_values.size() / 2])
	for entry in out:
		var kind := String(entry.get("kind", "steady"))
		var base := kind_intensity(kind)
		var chart_boost := 0.0
		if median_nps > 0.01:
			var ratio := float(entry.get("notes_per_sec", 0.0)) / median_nps
			chart_boost = clampf((ratio - 1.0) * 0.25, 0.0, 0.25)
		entry["intensity"] = clampf(base + chart_boost, 0.0, 1.0)
	return out


static func _fallback_progressive_schedule(duration: float) -> Array:
	return [
		{"start_s": 0.0, "end_s": duration * 0.25, "kind": "quiet", "intensity": 0.0},
		{"start_s": duration * 0.25, "end_s": duration * 0.50, "kind": "steady", "intensity": 0.35},
		{"start_s": duration * 0.50, "end_s": duration * 0.75, "kind": "steady", "intensity": 0.35},
		{"start_s": duration * 0.75, "end_s": duration, "kind": "dense", "intensity": 1.0},
	]


static func _coalesce_by_kind(schedule: Array) -> Array:
	if schedule.is_empty():
		return schedule
	var sorted: Array = schedule.duplicate(true)
	sorted.sort_custom(func(a, b): return float(a.get("start_s", 0.0)) < float(b.get("start_s", 0.0)))
	var merged: Array = []
	for seg in sorted:
		if not seg is Dictionary:
			continue
		var entry: Dictionary = (seg as Dictionary).duplicate()
		var kind := String(entry.get("kind", "steady"))
		entry["intensity"] = kind_intensity(kind)
		if merged.is_empty():
			merged.append(entry)
			continue
		var last: Dictionary = merged[-1]
		if String(last.get("kind", "steady")) == kind:
			last["end_s"] = maxf(float(last.get("end_s", 0.0)), float(entry.get("end_s", 0.0)))
		else:
			merged.append(entry)
	return merged


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


static func _blend_sec(seg: Dictionary) -> float:
	var start_s := float(seg.get("start_s", 0.0))
	var end_s := maxf(float(seg.get("end_s", start_s)), start_s)
	var duration := end_s - start_s
	return clampf(duration * BLEND_FRAC, BLEND_SEC_MIN, BLEND_SEC_MAX)


static func _smoothstep_alpha(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


static func intensity_at(schedule: Array, song_time: float) -> float:
	if schedule.is_empty():
		return 0.0
	var idx := segment_index_at(schedule, song_time)
	var seg: Dictionary = schedule[idx]
	var start_s := float(seg.get("start_s", 0.0))
	var end_s := maxf(float(seg.get("end_s", start_s)), start_s)
	var curr := float(seg.get("intensity", kind_intensity(String(seg.get("kind", "steady")))))
	var blend := _blend_sec(seg)
	var intensity := curr
	if idx > 0:
		var prev: Dictionary = schedule[idx - 1]
		var prev_i := float(prev.get("intensity", 0.0))
		var t_in := song_time - start_s
		if t_in < blend:
			var alpha := _smoothstep_alpha(t_in / blend)
			intensity = lerpf(prev_i, curr, alpha)
	if idx < schedule.size() - 1:
		var next: Dictionary = schedule[idx + 1]
		var next_i := float(next.get("intensity", 0.0))
		var t_to_end := end_s - song_time
		if t_to_end < blend:
			var alpha := _smoothstep_alpha(1.0 - t_to_end / blend)
			intensity = lerpf(intensity, next_i, alpha)
	return clampf(intensity, 0.0, 1.0)
