# logic/domain/midi/midi_pattern_store.gd
extends RefCounted
class_name MidiPatternStore

# MVP storage for drum patterns: user://Patterns/  (separate from chart .rf)
# No global index, scan on demand. No UI, no FORMAT_VERSION bump here.

const STORE_DIR := "user://Patterns"
const PATTERN_EXT := ".json"
const MIDI_DIAG := true

static func get_store_dir() -> String:
	return STORE_DIR

static func ensure_store_dir() -> bool:
	var abs_dir := DirectoryUtils.to_absolute(STORE_DIR)
	if abs_dir == "":
		return false
	return DirectoryUtils.ensure_dir(abs_dir)

static func _sanitize_id(name: String) -> String:
	var base := name.strip_edges()
	if base == "":
		base = "pattern"
	base = base.get_file().get_basename()
	base = base.replace("/", "_").replace("\\", "_").replace(":", "_").replace("*", "_").replace("?", "_").replace("\"", "_").replace("<", "_").replace(">", "_").replace("|", "_")
	base = base.to_lower().replace(" ", "_")
	if base == "":
		base = "pattern"
	return base

static func _pattern_path_for_id(id: String) -> String:
	var sid := _sanitize_id(id)
	return "%s/%s%s" % [STORE_DIR, sid, PATTERN_EXT]

static func list_patterns() -> Array:
	ensure_store_dir()
	var out: Array = []
	var abs_dir := DirectoryUtils.to_absolute(STORE_DIR)
	if abs_dir == "" or not DirAccess.dir_exists_absolute(abs_dir):
		return out
	var da := DirAccess.open(abs_dir)
	if da == null:
		return out
	da.list_dir_begin()
	var fname := da.get_next()
	while fname != "":
		if not da.current_is_dir() and fname.to_lower().ends_with(PATTERN_EXT):
			var full := "%s/%s" % [STORE_DIR, fname]
			var pat := load_pattern_from_path(full)
			if pat != null:
				out.append(pat)
		fname = da.get_next()
	da.list_dir_end()
	out.sort_custom(func(a, b): return String(a.name).to_lower() < String(b.name).to_lower())
	return out

static func load_pattern_from_path(path: String) -> MidiPattern:
	var data := JsonUtils.read_json_dict(path)
	if data.is_empty():
		return null
	return MidiPattern.from_dict(data)

static func load_pattern(id: String) -> MidiPattern:
	var path := _pattern_path_for_id(id)
	return load_pattern_from_path(path)

static func save_pattern(pattern: MidiPattern) -> String:
	if pattern == null:
		return "pattern null"
	ensure_store_dir()
	if pattern.id == "":
		pattern.id = _sanitize_id(pattern.name)
	var path := _pattern_path_for_id(pattern.id)
	# Ensure unique if file exists and is different pattern (avoid overwrite different hash)
	var abs_path := DirectoryUtils.to_absolute(path)
	if FileAccess.file_exists(abs_path):
		var existing := JsonUtils.read_json_dict(path)
		if not existing.is_empty():
			var existing_hash := String(existing.get("source_hash", ""))
			if existing_hash != "" and existing_hash != pattern.source_hash and String(existing.get("id","")) == pattern.id:
				# Same id but different source -> make unique
				pattern.id = "%s_%s" % [pattern.id, pattern.source_hash.substr(0, 6)]
				path = _pattern_path_for_id(pattern.id)
	var dict := pattern.to_dict()
	var ok := JsonUtils.write_json(path, dict, true, true)
	if not ok:
		return "cannot write %s" % path
	return ""

static func delete_pattern(id: String) -> String:
	var path := _pattern_path_for_id(id)
	var abs_path := DirectoryUtils.to_absolute(path)
	if abs_path == "" or not FileAccess.file_exists(abs_path):
		return "not found"
	var da := DirAccess.open(DirectoryUtils.to_absolute(STORE_DIR))
	if da == null:
		return "cannot open store dir"
	if da.remove(abs_path.get_file()) != OK:
		# Fallback via DirAccess.remove_absolute
		if DirAccess.remove_absolute(abs_path) != OK:
			return "cannot delete"
	return ""

static func import_mid(source_mid_path: String) -> Dictionary:
	# Returns {pattern: MidiPattern, error: String, warning: String}
	var abs_src := DirectoryUtils.to_absolute(source_mid_path)
	if abs_src == "" or not FileAccess.file_exists(abs_src):
		if MIDI_DIAG:
			print("[RF_DIAG] STORE IMPORT FAILED stage=abs_path reason=file_not_found path=%s abs=%s exists=%s" % [source_mid_path, abs_src, str(abs_src != "" and FileAccess.file_exists(abs_src))])
		return {"pattern": null, "error": "file not found: %s" % source_mid_path, "warning": ""}
	var parsed := MidiParser.parse_file(source_mid_path)
	var err := String(parsed.get("error", ""))
	if err != "":
		if MIDI_DIAG:
			print("[RF_DIAG] STORE IMPORT FAILED stage=parse error='%s' path=%s" % [err, source_mid_path])
		return {"pattern": null, "error": err, "warning": ""}
	var notes: Array = parsed.get("notes", [])
	if notes.is_empty():
		if MIDI_DIAG:
			print("[RF_DIAG] STORE IMPORT FAILED stage=no_notes path=%s" % source_mid_path)
		return {"pattern": null, "error": "", "warning": "MIDI contains no notes"}
	var detect := MidiDrumDetector.detect(parsed)
	var is_drum: bool = bool(detect.get("is_drum", false))
	var reason: String = String(detect.get("reason", ""))
	var confidence: String = String(detect.get("confidence", "low"))
	if MIDI_DIAG:
		print("[RF_DIAG] DETECT RESULT is_drum=%s reason='%s' confidence=%s drum_notes=%d total=%d" % [str(is_drum), reason, confidence, (detect.get("drum_notes", []) as Array).size(), notes.size()])
	# MVP: remove hard drum-track gate — any valid MIDI with notes is allowed
	var drum_notes: Array
	if is_drum:
		drum_notes = detect.get("drum_notes", notes)
	else:
		if MIDI_DIAG:
			print("[RF_DIAG] DETECT NOT DRUM but MVP permissive — using all notes is_drum=false reason='%s'" % reason)
		drum_notes = notes
	if drum_notes.is_empty():
		if MIDI_DIAG:
			print("[RF_DIAG] STORE IMPORT FAILED stage=detect_empty reason='%s'" % reason)
		return {"pattern": null, "error": "", "warning": "No drum notes after filter: %s" % reason}
	# Build pattern from drum_notes only (merge)
	var filtered_parsed := parsed.duplicate(true)
	filtered_parsed["notes"] = drum_notes
	# Recalculate duration/leading for filtered set
	var sec_per_tick: float = 0.0
	var ppq: int = int(parsed.get("ppq", 480))
	var tempo_us: int = int(parsed.get("tempo_us", 0))
	if tempo_us == 0:
		tempo_us = int(60000000.0 / float(parsed.get("bpm", 120.0)))
	sec_per_tick = (float(tempo_us) / 1000000.0) / float(ppq if ppq>0 else 480)
	var max_end: float = 0.0
	var min_start: float = 1e9
	for n in drum_notes:
		var st: float = float(n.get("relTime", n.get("start_sec", 0.0)))
		var dur: float = float(n.get("duration", 0.0))
		min_start = minf(min_start, st)
		max_end = maxf(max_end, st + dur)
	if min_start >= 1e9:
		min_start = 0.0
	var duration_sec: float = max_end
	var leading_offset: float = min_start
	filtered_parsed["durationSec"] = duration_sec
	filtered_parsed["leadingOffset"] = leading_offset
	var src_hash := MidiPattern.file_hash_for_path(source_mid_path)
	var pattern := MidiPattern.from_parser_result(filtered_parsed, source_mid_path, src_hash)
	# Ensure drum mapping present check — MVP permissive fallback for KICK MIDI
	var pitches := MidiGmMapper.pitches_in_notes(drum_notes)
	var mapping := MidiGmMapper.default_map_for_pitches(pitches)
	if MIDI_DIAG:
		print("[RF_DIAG] MAP RESULT pitches=%s mapping_size=%d" % [str(pitches), mapping.size()])
	if mapping.is_empty():
		# MVP fallback: any pitch → kick, explicitly for browser KICK MIDI with non-GM pitches (60,112)
		# Global MidiGmMapper remains strict; fallback is local to import pipeline only
		if MIDI_DIAG:
			print("[RF_DIAG] MAP EMPTY — MVP fallback any pitch → kick for pitches=%s" % str(pitches))
		mapping.clear()
		for p in pitches:
			mapping[int(p)] = "kick"
		if MIDI_DIAG:
			print("[RF_DIAG] MAP FALLBACK applied mapping_size=%d" % mapping.size())
		# If still empty (no pitches at all, shouldn't happen as notes not empty), fail
		if mapping.is_empty():
			if MIDI_DIAG:
				print("[RF_DIAG] STORE IMPORT FAILED stage=mapping_empty pitches=%s" % str(pitches))
			return {"pattern": null, "error": "", "warning": "No mappable drum pitches (pitches %s)" % str(pitches)}
	# Save
	var save_err := save_pattern(pattern)
	if MIDI_DIAG:
		print("[RF_DIAG] STORE SAVE pattern_id=%s err='%s'" % [pattern.id, save_err])
	if save_err != "":
		if MIDI_DIAG:
			print("[RF_DIAG] STORE IMPORT FAILED stage=save err='%s'" % save_err)
		return {"pattern": null, "error": save_err, "warning": ""}
	if MIDI_DIAG:
		print("[RF_DIAG] STORE IMPORT SUCCESS pattern_id=%s notes=%d" % [pattern.id, pattern.note_count()])
	return {"pattern": pattern, "error": "", "warning": ""}

static func get_pattern_ids() -> Array[String]:
	var pats := list_patterns()
	var out: Array[String] = []
	for p in pats:
		if p is MidiPattern:
			out.append(String((p as MidiPattern).id))
	return out
