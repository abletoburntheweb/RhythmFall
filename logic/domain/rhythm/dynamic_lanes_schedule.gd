# logic/utils/dynamic_lanes_schedule.gd
extends RefCounted
class_name DynamicLanesSchedule

const NotesUtils = preload("res://logic/domain/rhythm/notes_utils.gd")

const MIN_LANES := 3
const MAX_LANES := 5
const MIN_SEGMENT_SEC := 8.0
const MIN_STRUCTURE_MEASURES := 4


static func lanes_for_kind(kind: String) -> int:
	match String(kind).strip_edges():
		"quiet", "sparse":
			return 3
		"dense", "loud_quiet":
			return 5
		_:
			return 4


static func has_usable_dna(
	song_path: String,
	instrument: String,
	mode: String,
	lanes: int
) -> bool:
	if song_path.strip_edges() == "":
		return false
	return NotesUtils.has_full_rhythm_dna(song_path, instrument, mode, lanes)


static func build_from_dna(dna: Dictionary, song_duration: float) -> Array:
	var timeline: Array = dna.get("structure_timeline", []) if dna.get("structure_timeline", []) is Array else []
	if not timeline.is_empty():
		var out: Array = []
		for seg in timeline:
			if not seg is Dictionary:
				continue
			var kind := String(seg.get("kind", "steady"))
			out.append({
				"start_s": float(seg.get("start_s", 0.0)),
				"end_s": maxf(float(seg.get("end_s", 0.0)), float(seg.get("start_s", 0.0))),
				"lanes": lanes_for_kind(kind),
				"kind": kind,
			})
		if not out.is_empty():
			return _coalesce_schedule(out)
	if song_duration > 0.01:
		return _coalesce_schedule(_fallback_progressive_schedule(song_duration))
	return [{"start_s": 0.0, "end_s": 999999.0, "lanes": 4, "kind": "steady"}]


static func _merge_same_lanes(schedule: Array) -> Array:
	if schedule.is_empty():
		return schedule
	var merged: Array = []
	for seg in schedule:
		if not seg is Dictionary:
			continue
		var entry: Dictionary = (seg as Dictionary).duplicate()
		if merged.is_empty():
			merged.append(entry)
			continue
		var last: Dictionary = merged[-1]
		if int(last.get("lanes", 4)) == int(entry.get("lanes", 4)):
			last["end_s"] = maxf(float(last.get("end_s", 0.0)), float(entry.get("end_s", 0.0)))
		else:
			merged.append(entry)
	return merged


static func _insert_lane_step_bridges(schedule: Array) -> Array:
	if schedule.size() < 2:
		return schedule
	var out: Array = []
	for seg in schedule:
		if not seg is Dictionary:
			continue
		var entry: Dictionary = (seg as Dictionary).duplicate()
		if out.is_empty():
			out.append(entry)
			continue
		var last: Dictionary = out[-1]
		var last_lanes := int(last.get("lanes", 4))
		var target_lanes := int(entry.get("lanes", 4))
		var delta := target_lanes - last_lanes
		if absi(delta) <= 1:
			out.append(entry)
			continue
		var bridge_lanes := last_lanes + clampi(delta, -1, 1)
		var boundary := float(last.get("end_s", 0.0))
		var next_start := float(entry.get("start_s", boundary))
		if next_start > boundary + 0.001:
			var mid := boundary + (next_start - boundary) * 0.5
			out.append({
				"start_s": boundary,
				"end_s": mid,
				"lanes": bridge_lanes,
				"kind": "transition",
			})
			entry["start_s"] = mid
			entry["lanes"] = bridge_lanes if absi(target_lanes - bridge_lanes) > 1 else target_lanes
		else:
			entry["lanes"] = bridge_lanes
		out.append(entry)
	return _merge_same_lanes(out)


static func _coalesce_schedule(schedule: Array) -> Array:
	if schedule.is_empty():
		return schedule
	var sorted: Array = schedule.duplicate(true)
	sorted.sort_custom(func(a, b): return float(a.get("start_s", 0.0)) < float(b.get("start_s", 0.0)))
	var merged := _merge_same_lanes(sorted)
	return _insert_lane_step_bridges(merged)


static func _fallback_progressive_schedule(duration: float) -> Array:
	return [
		{"start_s": 0.0, "end_s": duration * 0.25, "lanes": 3, "kind": "quiet"},
		{"start_s": duration * 0.25, "end_s": duration * 0.50, "lanes": 4, "kind": "steady"},
		{"start_s": duration * 0.50, "end_s": duration * 0.75, "lanes": 4, "kind": "steady"},
		{"start_s": duration * 0.75, "end_s": duration, "lanes": 5, "kind": "dense"},
	]


static func lanes_at(schedule: Array, song_time: float) -> int:
	for seg in schedule:
		if not seg is Dictionary:
			continue
		var start_s := float(seg.get("start_s", 0.0))
		var end_s := maxf(float(seg.get("end_s", start_s)), start_s)
		if song_time >= start_s and song_time < end_s:
			return clampi(int(seg.get("lanes", 4)), MIN_LANES, MAX_LANES)
	if not schedule.is_empty() and schedule[-1] is Dictionary:
		return clampi(int((schedule[-1] as Dictionary).get("lanes", 4)), MIN_LANES, MAX_LANES)
	return 4


static func resolve_chart_lanes(
	song_path: String,
	instrument: String,
	mode: String,
	preferred: int
) -> int:
	var unified := NotesUtils.resolve_unified_mode_path(song_path, instrument, mode)
	if unified != "":
		return NotesUtils.read_chart_lanes(unified, NotesUtils.CANONICAL_MAX_LANES)
	for lane_count in [NotesUtils.CANONICAL_MAX_LANES, 4, MIN_LANES]:
		if lane_count > preferred and lane_count != NotesUtils.CANONICAL_MAX_LANES:
			continue
		if NotesUtils.notes_exist(song_path, instrument, mode, lane_count):
			var path := NotesUtils.resolve_existing_path(song_path, instrument, mode, lane_count)
			if path != "":
				return NotesUtils.read_chart_lanes(path, lane_count)
	return clampi(preferred, MIN_LANES, NotesUtils.CANONICAL_MAX_LANES)


static func build_structure_segments_from_dna(dna: Dictionary) -> Array:
	var timeline: Array = (
		dna.get("structure_timeline", [])
		if dna.get("structure_timeline", []) is Array
		else []
	)
	if timeline.is_empty():
		return []
	var out: Array = []
	for seg in timeline:
		if not seg is Dictionary:
			continue
		var start_s := float(seg.get("start_s", 0.0))
		var end_s := maxf(float(seg.get("end_s", start_s)), start_s)
		var entry := {
			"start_s": start_s,
			"end_s": end_s,
			"kind": String(seg.get("kind", "steady")),
		}
		for key in ["role", "density", "drum_energy", "mix_energy", "intensity", "confidence", "boundary_source"]:
			if (seg as Dictionary).has(key):
				entry[key] = (seg as Dictionary).get(key)
		out.append(entry)
	if out.is_empty():
		return out
	out.sort_custom(func(a, b): return float(a.get("start_s", 0.0)) < float(b.get("start_s", 0.0)))
	return _coalesce_structure_segments(out, dna)


static func _measure_duration_from_dna(dna: Dictionary) -> float:
	var bpm := float(dna.get("bpm", 0.0))
	if bpm <= 0.0:
		var meta: Variant = dna.get("meta", {})
		if meta is Dictionary:
			bpm = float((meta as Dictionary).get("bpm", 0.0))
	if bpm <= 0.0:
		bpm = 120.0
	return (60.0 / bpm) * 4.0


static func _coalesce_structure_segments(segments: Array, dna: Dictionary) -> Array:
	if segments.is_empty():
		return segments
	var min_sec := _measure_duration_from_dna(dna) * float(MIN_STRUCTURE_MEASURES)
	if min_sec <= 0.0:
		return segments
	var coalesced: Array = []
	for seg in segments:
		if not seg is Dictionary:
			continue
		var start_s := float(seg.get("start_s", 0.0))
		var end_s := maxf(float(seg.get("end_s", start_s)), start_s)
		var kind := String(seg.get("kind", "steady"))
		if coalesced.is_empty():
			coalesced.append(_copy_structure_segment(seg, start_s, end_s, kind))
			continue
		var last: Dictionary = coalesced[-1]
		var group_start := float(last.get("start_s", 0.0))
		if start_s - group_start < min_sec:
			last["end_s"] = maxf(float(last.get("end_s", 0.0)), end_s)
			_merge_structure_segment_fields(last, seg)
		else:
			coalesced.append(_copy_structure_segment(seg, start_s, end_s, kind))
	return coalesced


static func _copy_structure_segment(seg: Dictionary, start_s: float, end_s: float, kind: String) -> Dictionary:
	var entry := {
		"start_s": start_s,
		"end_s": end_s,
		"kind": kind,
	}
	for key in ["role", "density", "drum_energy", "mix_energy", "intensity", "confidence", "boundary_source"]:
		if seg.has(key):
			entry[key] = seg.get(key)
	return entry


static func _merge_structure_segment_fields(target: Dictionary, source: Dictionary) -> void:
	if source.has("density"):
		target["density"] = maxf(float(target.get("density", 0.0)), float(source.get("density", 0.0)))
	if source.has("intensity"):
		target["intensity"] = maxf(float(target.get("intensity", 0.0)), float(source.get("intensity", 0.0)))
	for key in ["drum_energy", "mix_energy", "confidence"]:
		if source.has(key) and not target.has(key):
			target[key] = source.get(key)
	var src_role := String(source.get("role", ""))
	var dst_role := String(target.get("role", ""))
	if src_role == "peak" or src_role == "chorus" or (src_role == "outro" and dst_role not in ["peak", "chorus"]):
		target["role"] = src_role


static func build_random_remap_schedule(dna: Dictionary, min_sec: float = MIN_SEGMENT_SEC) -> Array:
	var raw := build_structure_segments_from_dna(dna)
	if raw.is_empty():
		return []
	var coalesced: Array = []
	for seg in raw:
		if not seg is Dictionary:
			continue
		var start_s := float(seg.get("start_s", 0.0))
		var end_s := maxf(float(seg.get("end_s", start_s)), start_s)
		var kind := String(seg.get("kind", "steady"))
		if coalesced.is_empty():
			coalesced.append({
				"start_s": start_s,
				"end_s": end_s,
				"kind": kind,
			})
			continue
		var last: Dictionary = coalesced[-1]
		var group_start := float(last.get("start_s", 0.0))
		if start_s - group_start < min_sec:
			last["end_s"] = maxf(float(last.get("end_s", 0.0)), end_s)
		else:
			coalesced.append({
				"start_s": start_s,
				"end_s": end_s,
				"kind": kind,
			})
	return coalesced


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
