# logic/domain/rhythm/energy_balance_schedule.gd
extends RefCounted
class_name EnergyBalanceSchedule

const _EnergyPulseSchedule = preload("res://logic/domain/rhythm/energy_pulse_schedule.gd")

const BLEND_SEC_MIN := 0.5
const BLEND_SEC_MAX := 2.0
const BLEND_FRAC := 0.2


static func build_from_dna(dna: Dictionary, song_duration: float) -> Array:
	return _EnergyPulseSchedule.build_from_dna(dna, song_duration)


static func timing_pct_for_kind(kind: String, calm_pct: float, intense_pct: float) -> float:
	match String(kind).strip_edges():
		"quiet", "sparse":
			return calm_pct
		"dense", "loud_quiet":
			return intense_pct
		_:
			return 100.0


static func _mult_for_segment(seg: Dictionary, calm_pct: float, intense_pct: float) -> float:
	var kind := String(seg.get("kind", "steady"))
	return timing_pct_for_kind(kind, calm_pct, intense_pct) / 100.0


static func _blend_sec(seg: Dictionary) -> float:
	var start_s := float(seg.get("start_s", 0.0))
	var end_s := maxf(float(seg.get("end_s", start_s)), start_s)
	return clampf((end_s - start_s) * BLEND_FRAC, BLEND_SEC_MIN, BLEND_SEC_MAX)


static func _smoothstep_alpha(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


static func timing_multiplier_at(
	schedule: Array,
	song_time: float,
	calm_pct: float,
	intense_pct: float
) -> float:
	if schedule.is_empty():
		return 1.0
	var idx := _EnergyPulseSchedule.segment_index_at(schedule, song_time)
	var seg: Dictionary = schedule[idx]
	var start_s := float(seg.get("start_s", 0.0))
	var end_s := maxf(float(seg.get("end_s", start_s)), start_s)
	var curr := _mult_for_segment(seg, calm_pct, intense_pct)
	var blend := _blend_sec(seg)
	var mult := curr
	if idx > 0:
		var prev: Dictionary = schedule[idx - 1]
		var prev_mult := _mult_for_segment(prev, calm_pct, intense_pct)
		var t_in := song_time - start_s
		if t_in < blend:
			var alpha := _smoothstep_alpha(t_in / blend)
			mult = lerpf(prev_mult, curr, alpha)
	if idx < schedule.size() - 1:
		var next: Dictionary = schedule[idx + 1]
		var next_mult := _mult_for_segment(next, calm_pct, intense_pct)
		var t_to_end := end_s - song_time
		if t_to_end < blend:
			var alpha := _smoothstep_alpha(1.0 - t_to_end / blend)
			mult = lerpf(mult, next_mult, alpha)
	return mult
