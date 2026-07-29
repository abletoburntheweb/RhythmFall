# logic/domain/rhythm/dna_virtual_effects.gd
extends RefCounted
class_name DnaVirtualEffects

const _DynamicLanesSchedule = preload("res://logic/domain/rhythm/dynamic_lanes_schedule.gd")

const BLEND_SEC_MIN := 0.5
const BLEND_SEC_MAX := 2.0
const BLEND_FRAC := 0.2

const MOD_PHRASE_SHIFT := "phrase_shift"
const MOD_GROOVE_LOCK := "groove_lock"
const MOD_ADAPTIVE := "adaptive"


static func empty_virtual() -> Dictionary:
	return {
		"reverse_scroll": false,
		"hidden_band_px": 0.0,
		"scroll_mult": 1.0,
		"timing_pct": 100.0,
		"playback_mult": 1.0,
	}


static func build_schedule(
	mod_id: String,
	dna: Dictionary,
	song_duration: float,
	notes: Array,
	params: Dictionary = {}
) -> Array:
	var raw := _DynamicLanesSchedule.build_structure_segments_from_dna(dna)
	if raw.is_empty() and song_duration > 0.01:
		raw = _fallback_segments(song_duration)
	if raw.is_empty():
		return []
	var schedule := _coalesce_segments(raw)
	match mod_id:
		MOD_PHRASE_SHIFT:
			return _build_phrase_shift(schedule, params)
		MOD_GROOVE_LOCK:
			return _build_groove_lock(schedule, dna, params)
		MOD_ADAPTIVE:
			return _build_adaptive(schedule, dna, notes, params)
		_:
			return schedule


static func virtual_at(schedule: Array, song_time: float) -> Dictionary:
	if schedule.is_empty():
		return empty_virtual()
	var idx := segment_index_at(schedule, song_time)
	var seg: Dictionary = schedule[idx]
	var start_s := float(seg.get("start_s", 0.0))
	var end_s := maxf(float(seg.get("end_s", start_s)), start_s)
	var curr: Dictionary = (
		seg.get("virtual", empty_virtual()) as Dictionary
	).duplicate()
	var blend := _blend_sec(seg)
	var out := curr.duplicate()
	if idx > 0:
		var prev: Dictionary = (schedule[idx - 1].get("virtual", empty_virtual()) as Dictionary).duplicate()
		var t_in := song_time - start_s
		if t_in < blend:
			var alpha := _smoothstep_alpha(t_in / blend)
			out = _lerp_virtual(prev, curr, alpha)
	if idx < schedule.size() - 1:
		var next: Dictionary = (schedule[idx + 1].get("virtual", empty_virtual()) as Dictionary).duplicate()
		var t_to_end := end_s - song_time
		if t_to_end < blend:
			var alpha := _smoothstep_alpha(1.0 - t_to_end / blend)
			out = _lerp_virtual(out, next, alpha)
	out["reverse_scroll"] = bool(curr.get("reverse_scroll", false))
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


static func _build_phrase_shift(schedule: Array, params: Dictionary) -> Array:
	var heat_pct := float(params.get("phrase_shift_heat_scroll_pct", 125.0))
	var hidden_band := float(params.get("phrase_shift_hidden_band_px", 180.0))
	var out: Array = []
	for i in range(schedule.size()):
		if not schedule[i] is Dictionary:
			continue
		var seg: Dictionary = (schedule[i] as Dictionary).duplicate()
		var kind := String(seg.get("kind", "steady"))
		var role := String(seg.get("role", ""))
		var is_finale := role in ["peak", "chorus", "outro"] if role != "" else i == schedule.size() - 1
		var v := empty_virtual()
		match kind:
			"dense":
				if is_finale:
					v["scroll_mult"] = heat_pct / 100.0
				else:
					v["reverse_scroll"] = true
			"loud_quiet":
				v["hidden_band_px"] = hidden_band
			_:
				pass
		seg["virtual"] = v
		out.append(seg)
	return out


static func _build_groove_lock(schedule: Array, dna: Dictionary, params: Dictionary) -> Array:
	var groove := _track_groove_level(dna)
	var groove_f := _level_float(groove)
	if groove_f < 0.35:
		groove_f = 0.35
	var scroll_pct := float(params.get("groove_lock_scroll_pct", 115.0))
	var timing_pct := float(params.get("groove_lock_timing_pct", 85.0))
	var band_px := float(params.get("groove_lock_band_px", 160.0))
	var out: Array = []
	for seg in schedule:
		if not seg is Dictionary:
			continue
		var entry: Dictionary = (seg as Dictionary).duplicate()
		var kind := String(entry.get("kind", "steady"))
		var v := empty_virtual()
		if kind in ["quiet", "sparse"]:
			entry["virtual"] = v
			out.append(entry)
			continue
		var intensity := groove_f
		if kind == "dense":
			intensity = clampf(intensity + 0.25, 0.0, 1.0)
		elif kind == "steady":
			intensity *= 0.75
		if intensity >= 0.45:
			v["scroll_mult"] = lerpf(1.0, scroll_pct / 100.0, intensity)
			v["timing_pct"] = lerpf(100.0, timing_pct, intensity)
			v["hidden_band_px"] = lerpf(0.0, band_px, intensity)
		entry["virtual"] = v
		out.append(entry)
	return out


static func _build_adaptive(schedule: Array, dna: Dictionary, notes: Array, params: Dictionary) -> Array:
	var groove_f := _level_float(_track_groove_level(dna))
	var heat_pct := float(params.get("adaptive_heat_scroll_pct", 125.0))
	var hidden_band := float(params.get("adaptive_hidden_band_px", 150.0))
	var speed_pct := float(params.get("adaptive_speed_pct", 120.0))
	var enriched := _enrich_notes_per_sec(schedule, notes, schedule)
	var nps_values: Array = []
	for seg in enriched:
		if seg is Dictionary:
			nps_values.append(float(seg.get("notes_per_sec", 0.0)))
	nps_values.sort()
	var median_nps := float(nps_values[nps_values.size() / 2]) if not nps_values.is_empty() else 1.0
	var out: Array = []
	for seg in enriched:
		if not seg is Dictionary:
			continue
		var entry: Dictionary = (seg as Dictionary).duplicate()
		var kind := String(entry.get("kind", "steady"))
		var energy := _kind_energy(kind)
		var nps := float(entry.get("notes_per_sec", 0.0))
		var density := float(entry.get("density", -1.0))
		if density < 0.0:
			density = clampf(nps / maxf(median_nps, 0.01), 0.0, 1.5) / 1.5
		var v := empty_virtual()
		if energy < 0.18 and density < 0.22:
			entry["virtual"] = v
			out.append(entry)
			continue
		var heat_score := groove_f * density
		var hidden_score := density * 0.95
		var speed_score := energy * 0.9
		var best := "none"
		var best_score := 0.0
		for pick in [
			{"id": "heat", "score": heat_score},
			{"id": "hidden", "score": hidden_score},
			{"id": "speed", "score": speed_score},
		]:
			if float(pick.get("score", 0.0)) > best_score:
				best_score = float(pick.get("score", 0.0))
				best = String(pick.get("id", "none"))
		if best_score >= 0.32:
			match best:
				"heat":
					v["scroll_mult"] = lerpf(1.0, heat_pct / 100.0, clampf(best_score, 0.0, 1.0))
				"hidden":
					v["hidden_band_px"] = lerpf(0.0, hidden_band, clampf(best_score, 0.0, 1.0))
				"speed":
					v["playback_mult"] = lerpf(1.0, speed_pct / 100.0, clampf(best_score, 0.0, 1.0))
		entry["virtual"] = v
		out.append(entry)
	return out


static func _enrich_notes_per_sec(schedule: Array, notes: Array, base: Array) -> Array:
	var out: Array = []
	for seg in base:
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
		entry["notes_per_sec"] = float(count) / duration
		out.append(entry)
	return out


static func _track_groove_level(dna: Dictionary) -> String:
	var genes: Dictionary = dna.get("genes", {}) if dna.get("genes", {}) is Dictionary else {}
	var rhythm: Dictionary = genes.get("rhythm", {}) if genes.get("rhythm", {}) is Dictionary else {}
	return String(rhythm.get("groove_stability", "medium"))


static func _level_float(level: String) -> float:
	match String(level).strip_edges():
		"high":
			return 1.0
		"low":
			return 0.25
		_:
			return 0.55


static func _kind_energy(kind: String) -> float:
	match String(kind).strip_edges():
		"quiet":
			return 0.0
		"sparse":
			return 0.15
		"steady":
			return 0.45
		"loud_quiet":
			return 0.65
		"dense":
			return 1.0
		_:
			return 0.45


static func _blend_sec(seg: Dictionary) -> float:
	var start_s := float(seg.get("start_s", 0.0))
	var end_s := maxf(float(seg.get("end_s", start_s)), start_s)
	return clampf((end_s - start_s) * BLEND_FRAC, BLEND_SEC_MIN, BLEND_SEC_MAX)


static func _smoothstep_alpha(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


static func _lerp_virtual(a: Dictionary, b: Dictionary, alpha: float) -> Dictionary:
	var t := clampf(alpha, 0.0, 1.0)
	return {
		"reverse_scroll": bool(b.get("reverse_scroll", false)) if t >= 0.5 else bool(
			a.get("reverse_scroll", false)
		),
		"hidden_band_px": lerpf(float(a.get("hidden_band_px", 0.0)), float(b.get("hidden_band_px", 0.0)), t),
		"scroll_mult": lerpf(float(a.get("scroll_mult", 1.0)), float(b.get("scroll_mult", 1.0)), t),
		"timing_pct": lerpf(float(a.get("timing_pct", 100.0)), float(b.get("timing_pct", 100.0)), t),
		"playback_mult": lerpf(float(a.get("playback_mult", 1.0)), float(b.get("playback_mult", 1.0)), t),
	}
