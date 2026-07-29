# logic/domain/rhythm/energy_pulse_schedule.gd
extends RefCounted
class_name EnergyPulseSchedule

const _DynamicLanesSchedule = preload("res://logic/domain/rhythm/dynamic_lanes_schedule.gd")

const BLEND_SEC_MIN := 0.5
const BLEND_SEC_MAX := 2.0
const BLEND_FRAC := 0.2


static func playback_pct_for_kind(kind: String, min_pct: float, max_pct: float) -> float:
	match String(kind).strip_edges():
		"quiet", "sparse":
			return min_pct
		"dense", "loud_quiet":
			return max_pct
		_:
			return 100.0


static func _segment_energy(seg: Dictionary) -> float:
	var mix := float(seg.get("mix_energy", -1.0))
	var drum := float(seg.get("drum_energy", -1.0))
	if mix >= 0.0 or drum >= 0.0:
		if mix < 0.0:
			mix = 0.0
		if drum < 0.0:
			drum = 0.0
		return clampf(mix * 0.6 + drum * 0.4, 0.0, 1.0)
	return _kind_energy_proxy(String(seg.get("kind", "steady")))


static func _kind_energy_proxy(kind: String) -> float:
	match String(kind).strip_edges():
		"quiet":
			return 0.15
		"sparse":
			return 0.28
		"steady":
			return 0.5
		"loud_quiet":
			return 0.72
		"dense":
			return 0.88
		_:
			return 0.5


static func build_from_dna(dna: Dictionary, song_duration: float) -> Array:
	var raw := _DynamicLanesSchedule.build_structure_segments_from_dna(dna)
	if not raw.is_empty():
		return _coalesce_by_kind(raw)
	if song_duration > 0.01:
		return _coalesce_by_kind(_fallback_progressive_schedule(song_duration))
	return [{"start_s": 0.0, "end_s": 999999.0, "kind": "steady"}]


static func _fallback_progressive_schedule(duration: float) -> Array:
	return [
		{"start_s": 0.0, "end_s": duration * 0.25, "kind": "quiet"},
		{"start_s": duration * 0.25, "end_s": duration * 0.50, "kind": "steady"},
		{"start_s": duration * 0.50, "end_s": duration * 0.75, "kind": "steady"},
		{"start_s": duration * 0.75, "end_s": duration, "kind": "dense"},
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
		if merged.is_empty():
			merged.append(entry)
			continue
		var last: Dictionary = merged[-1]
		if String(last.get("kind", "steady")) == String(entry.get("kind", "steady")):
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


static func _mult_for_segment(seg: Dictionary, min_pct: float, max_pct: float) -> float:
	var kind := String(seg.get("kind", "steady"))
	var base_mult := playback_pct_for_kind(kind, min_pct, max_pct) / 100.0
	var intensity := float(seg.get("intensity", -1.0))
	if intensity < 0.0:
		return base_mult
	var energy := _segment_energy(seg)
	var drive := clampf(energy * intensity, 0.0, 1.0)
	return lerpf(1.0, base_mult, drive)


static func _blend_sec(seg: Dictionary) -> float:
	var start_s := float(seg.get("start_s", 0.0))
	var end_s := maxf(float(seg.get("end_s", start_s)), start_s)
	var duration := end_s - start_s
	return clampf(duration * BLEND_FRAC, BLEND_SEC_MIN, BLEND_SEC_MAX)


static func _smoothstep_alpha(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


static func playback_multiplier_at(
	schedule: Array,
	song_time: float,
	min_pct: float,
	max_pct: float
) -> float:
	if schedule.is_empty():
		return 1.0
	var idx := segment_index_at(schedule, song_time)
	var seg: Dictionary = schedule[idx]
	var start_s := float(seg.get("start_s", 0.0))
	var end_s := maxf(float(seg.get("end_s", start_s)), start_s)
	var curr_mult := _mult_for_segment(seg, min_pct, max_pct)
	var blend := _blend_sec(seg)
	var mult := curr_mult
	if idx > 0:
		var prev: Dictionary = schedule[idx - 1]
		var prev_mult := _mult_for_segment(prev, min_pct, max_pct)
		var t_in := song_time - start_s
		if t_in < blend:
			var alpha := _smoothstep_alpha(t_in / blend)
			mult = lerpf(prev_mult, curr_mult, alpha)
	if idx < schedule.size() - 1:
		var next: Dictionary = schedule[idx + 1]
		var next_mult := _mult_for_segment(next, min_pct, max_pct)
		var t_to_end := end_s - song_time
		if t_to_end < blend:
			var alpha := _smoothstep_alpha(1.0 - t_to_end / blend)
			mult = lerpf(mult, next_mult, alpha)
	return mult
