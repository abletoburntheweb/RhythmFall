# logic/domain/midi/midi_drum_detector.gd
extends RefCounted
class_name MidiDrumDetector

# Conservative drum-only detection for MVP. Merges all detected drum tracks, ignores melodic.

const GM_DRUM_PITCHES: Array[int] = [
	35, 36, 37, 38, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 55, 57, 59
]
const GM_DRUM_CORE: Array[int] = [36, 38, 42, 45, 49, 51]

static func is_pitch_drum(pitch: int) -> bool:
	return int(pitch) in GM_DRUM_PITCHES

static func _track_name_is_drum(name: String) -> bool:
	var n := name.strip_edges().to_lower()
	if n == "":
		return false
	return n.contains("drum") or n.contains("kit") or n.contains("perc") or n.contains("beat") or n.contains("kick") or n.contains("snare") or n.contains("hat") or n.contains("tom") or n.contains("cymbal")

static func _is_channel_drum(channel_set: Dictionary) -> bool:
	return channel_set.has(9)

static func evaluate_track(notes: Array, channel_set: Dictionary, track_name: String) -> Dictionary:
	var total := notes.size()
	if total == 0:
		return {"is_drum": false, "score": 0, "reason": "empty", "drum_ratio": 0.0}
	var drum_count := 0
	for n in notes:
		if n is Dictionary and is_pitch_drum(int(n.get("pitch", -1))):
			drum_count += 1
	var ratio := float(drum_count) / float(total) if total > 0 else 0.0
	var score := 0
	var reasons: Array[String] = []
	if _is_channel_drum(channel_set):
		score += 2
		reasons.append("ch10")
	if _track_name_is_drum(track_name):
		score += 1
		reasons.append("name:%s" % track_name)
	if ratio >= 0.6:
		score += 1
		reasons.append("pitch %.0f%% drum" % (ratio * 100.0))
	elif ratio >= 0.4:
		reasons.append("pitch %.0f%% mixed" % (ratio * 100.0))
	var is_drum := false
	var confidence := "low"
	if score >= 2 and ratio >= 0.6:
		is_drum = true
		confidence = "high"
	elif score >= 2 and ratio >= 0.4:
		is_drum = false
		confidence = "ambiguous"
	elif ratio >= 0.7:
		is_drum = true
		confidence = "medium"
	if is_drum:
		reasons.append("is_drum")
	else:
		reasons.append("not_drum")
	return {"is_drum": is_drum, "score": score, "ratio": ratio, "reason": ", ".join(reasons), "confidence": confidence, "drum_count": drum_count, "total": total}

static func detect(parsed: Dictionary) -> Dictionary:
	var all_notes: Array = parsed.get("notes", [])
	if all_notes.is_empty():
		return {"is_drum": false, "reason": "no notes", "confidence": "high", "drum_tracks": [], "drum_notes": [], "melodic_notes": []}
	var tracks_meta: Array = parsed.get("tracksMeta", [])
	# Group notes by track
	var by_track: Dictionary = {}
	for n in all_notes:
		if not n is Dictionary:
			continue
		var t := int(n.get("track", 0))
		if not by_track.has(t):
			by_track[t] = []
		(by_track[t] as Array).append(n)
	var drum_tracks: Array[int] = []
	var drum_notes: Array = []
	var melodic_notes: Array = []
	var reasons: Array[String] = []
	for tid in by_track.keys():
		var t_notes: Array = by_track[tid]
		var meta := {}
		for tm in tracks_meta:
			if tm is Dictionary and int(tm.get("track", -1)) == int(tid):
				meta = tm
				break
		# Also try index-based meta
		if meta.is_empty() and int(tid) < tracks_meta.size():
			var cand: Variant = tracks_meta[tid]
			if cand is Dictionary:
				meta = cand
		var ch_set: Dictionary = meta.get("channel_set", {}) as Dictionary
		var tname: String = String(meta.get("name", ""))
		var eval_res := evaluate_track(t_notes, ch_set, tname)
		if bool(eval_res.get("is_drum", false)):
			drum_tracks.append(int(tid))
			for nn in t_notes:
				drum_notes.append(nn)
			reasons.append("track %d drum (%s)" % [int(tid), String(eval_res.get("reason", ""))])
		else:
			for nn in t_notes:
				melodic_notes.append(nn)
			reasons.append("track %d melodic (%s)" % [int(tid), String(eval_res.get("reason", ""))])
	drum_tracks.sort()
	# Conservative: if no drum tracks, try global fallback (all notes as one virtual track)
	if drum_tracks.is_empty():
		# Global ratio check
		var total := all_notes.size()
		var drum_cnt := 0
		for n in all_notes:
			if is_pitch_drum(int(n.get("pitch", -1))):
				drum_cnt += 1
		var ratio := float(drum_cnt) / float(total) if total > 0 else 0.0
		var has_ch10 := false
		for tm in tracks_meta:
			if tm is Dictionary and _is_channel_drum(tm.get("channel_set", {}) as Dictionary):
				has_ch10 = true
				break
		if ratio >= 0.6 and has_ch10:
			# Treat as drum despite track split
			drum_tracks = by_track.keys()
			drum_tracks.sort()
			drum_notes = all_notes.duplicate(true)
			melodic_notes.clear()
			return {"is_drum": true, "drum_tracks": drum_tracks, "drum_notes": drum_notes, "melodic_notes": melodic_notes, "reason": "global %.0f%% drum ch10 -> merge all" % (ratio*100.0), "confidence": "medium"}
		return {"is_drum": false, "drum_tracks": [], "drum_notes": [], "melodic_notes": melodic_notes, "reason": "no drum track: " + ", ".join(reasons), "confidence": "high"}
	# Merge all detected drum tracks (strategy C) — not largest only
	drum_notes.sort_custom(func(a, b): return float(a.get("relTime", a.get("start_sec", 0.0))) < float(b.get("relTime", b.get("start_sec", 0.0))))
	# Deduplicate exact same pitch+time+channel (rare)
	var seen: Dictionary = {}
	var deduped: Array = []
	for n in drum_notes:
		var k := "%d|%.5f|%d" % [int(n.get("pitch", 0)), float(n.get("relTime", 0.0)), int(n.get("channel", 0))]
		if not seen.has(k):
			seen[k] = true
			deduped.append(n)
	var is_drum_final := not deduped.is_empty()
	var conf := "high" if drum_tracks.size() == 1 else "medium"
	var reason_str := "merge %d drum tracks: " % drum_tracks.size() + ", ".join(reasons) if drum_tracks.size() > 1 else ", ".join(reasons)
	return {"is_drum": is_drum_final, "drum_tracks": drum_tracks, "drum_notes": deduped, "melodic_notes": melodic_notes, "reason": reason_str, "confidence": conf}
