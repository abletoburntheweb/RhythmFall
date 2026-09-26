# logic/domain/editor/rfc_corrections_codec.gd
extends RefCounted
class_name RfcCorrectionsCodec

# .rfc correction/versioning codec — Stage A
# Stores correction history + semantic diff + version identity, separate from .rf
# Format is JSON, versioned, atomic write via .tmp

const RFC_VERSION := 1
const TIME_EPSILON := 0.0001

# Version naming: corrected files are `drums_{stem}_v{version}.rf` + `.rfc`
# Generated has no version suffix, version 0 is implicit.
# For custom base names containing space, use " vN" to preserve style ("Fix chorus snare v2.rf");
# otherwise use "_vN" ("arcade_medium_v1.rf").
# Both forms are parsed on load.

static func version_name(version: int) -> String:
	if version <= 0:
		return ""
	return "v%d" % version

static func parse_version(name: String) -> int:
	var s := name.strip_edges().to_lower()
	if s.begins_with("v"):
		var num := s.substr(1)
		if num.is_valid_int():
			return int(num)
	return 0

static func parse_base_and_version(stem: String) -> Dictionary:
	# stem is chart_stem without instrument prefix, e.g. "arcade_medium_v1" or "Fix chorus snare v2"
	var s := stem.strip_edges()
	# Try underscore form "_vN" at end
	var re_underscore := RegEx.new()
	re_underscore.compile("^(.*)_v(\\d+)$")
	var m := re_underscore.search(s.to_lower())
	if m:
		var base := s.substr(0, m.get_start(2) - 2).strip_edges() # remove "_vN"
		var ver := int(m.get_string(2))
		return {"base": base, "version": ver}
	# Try space form " vN" at end
	var re_space := RegEx.new()
	re_space.compile("^(.*)\\s+v(\\d+)$")
	var m2 := re_space.search(s)
	if m2:
		var base2 := m2.get_string(1).strip_edges()
		var ver2 := int(m2.get_string(2))
		return {"base": base2, "version": ver2}
	return {"base": s, "version": 0}

static func versioned_stem(base_stem: String, version: int) -> String:
	var stem := base_stem.strip_edges()
	if version <= 0:
		return stem.to_lower()
	# Preserve space style if base contains space
	if " " in stem:
		return "%s %s" % [stem, version_name(version)]
	return "%s_%s" % [stem.to_lower(), version_name(version)]

static func versioned_filename(instrument: String, base_stem: String, version: int, ext: String = "rf") -> String:
	var stem := versioned_stem(base_stem, version)
	return "%s_%s.%s" % [instrument.to_lower(), stem, ext]

static func versioned_path_for(song_path: String, instrument: String, base_stem: String, version: int, ext: String = "rf") -> String:
	var cid := NotesUtils.chart_id_from_song_path(song_path)
	var filename := versioned_filename(instrument, base_stem, version, ext)
	return "%s/%s" % [NotesUtils.chart_dir(cid), filename]

static func rfc_path_for_versioned(song_path: String, instrument: String, base_stem: String, version: int) -> String:
	return versioned_path_for(song_path, instrument, base_stem, version, "rfc")

static func is_versioned_stem(stem: String) -> bool:
	return int(parse_base_and_version(stem).get("version", 0)) > 0

static func base_stem_from_versioned(stem: String) -> String:
	return String(parse_base_and_version(stem).get("base", stem))

static func version_from_stem(stem: String) -> int:
	return int(parse_base_and_version(stem).get("version", 0))

# Scan existing versioned files for a base stem to find next free version
static func list_existing_versions(song_path: String, instrument: String, base_stem: String) -> Array[int]:
	var cid := NotesUtils.chart_id_from_song_path(song_path)
	var dir := NotesUtils.chart_dir(cid)
	var abs_dir := DirectoryUtils.to_absolute(dir)
	if abs_dir == "" or not DirAccess.dir_exists_absolute(abs_dir):
		return []
	var base_lower := base_stem.strip_edges().to_lower()
	var inst_lower := instrument.strip_edges().to_lower()
	var versions: Array[int] = []
	var da := DirAccess.open(abs_dir)
	if da == null:
		return versions
	da.list_dir_begin()
	var fname := da.get_next()
	while fname != "":
		if not da.current_is_dir():
			# Check suffix .rf or .rfc (and not .rf.temp etc)
			if fname.ends_with(".rf") or fname.ends_with(".rfc"):
				var stem_full := fname
				# Strip extension
				if stem_full.ends_with(".rfc"):
					stem_full = stem_full.substr(0, stem_full.length() - 4)
				elif stem_full.ends_with(".rf"):
					stem_full = stem_full.substr(0, stem_full.length() - 3)
				# Expect instrument_ prefix
				var prefix := inst_lower + "_"
				if stem_full.to_lower().begins_with(prefix):
					var stem_part := stem_full.substr(prefix.length())
					var parsed := parse_base_and_version(stem_part)
					var b := String(parsed.get("base", "")).to_lower()
					var v := int(parsed.get("version", 0))
					if b == base_lower and v > 0:
						if not versions.has(v):
							versions.append(v)
				# Also handle flat dir? Already in chart_dir, no
		fname = da.get_next()
	da.list_dir_end()
	versions.sort()
	return versions

static func next_free_version(song_path: String, instrument: String, base_stem: String) -> int:
	var existing := list_existing_versions(song_path, instrument, base_stem)
	if existing.is_empty():
		return 1
	return existing.max() + 1

static func latest_version(song_path: String, instrument: String, base_stem: String) -> int:
	var existing := list_existing_versions(song_path, instrument, base_stem)
	if existing.is_empty():
		return 0
	return existing.max()

static func _hash_notes(arr: Array) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for n in arr:
		if not n is Dictionary:
			continue
		var line := "%0.4f|%d|%s\n" % [float(n.get("time", 0.0)), int(n.get("lane", 0)), String(n.get("drum", "kick")).to_lower()]
		ctx.update(line.to_utf8_buffer())
	return ctx.finish().hex_encode().substr(0, 16)

static func _now_iso() -> String:
	return Time.get_datetime_string_from_system(true)

static func _sanitize_notes(arr: Array) -> Array:
	var out: Array = []
	for n in arr:
		if n is Dictionary:
			out.append((n as Dictionary).duplicate(true))
	return EditorNoteUtils.sort_by_time(out)

# Semantic diff: Generated -> Corrected
# Returns {added: Array, deleted: Array, moved: Array[{from,to}], reclassed: Array[{from,to}]}
static func compute_diff(generated: Array, corrected: Array) -> Dictionary:
	var gen := _sanitize_notes(generated)
	var cor := _sanitize_notes(corrected)
	# Exact match via note_key (time+lane+drum with 0.0001)
	var gen_by_key: Dictionary = {}
	var cor_by_key: Dictionary = {}
	for n in gen:
		var k := EditorNoteUtils.note_key(n as Dictionary)
		gen_by_key[k] = n
	for n in cor:
		var k := EditorNoteUtils.note_key(n as Dictionary)
		cor_by_key[k] = n
	var gen_unmatched: Array = []
	var cor_unmatched: Array = []
	for k in gen_by_key.keys():
		if not cor_by_key.has(k):
			gen_unmatched.append(gen_by_key[k])
	for k in cor_by_key.keys():
		if not gen_by_key.has(k):
			cor_unmatched.append(cor_by_key[k])
	# Now try to classify MOVE and RECLASS among unmatched
	var moved: Array = []
	var reclassed: Array = []
	var added: Array = []
	var deleted: Array = []
	# For MOVE: same drum, different time/lane
	# For RECLASS: same time+lane, different drum
	# Use greedy matching
	var cor_used: Dictionary = {}
	var gen_used: Dictionary = {}
	# First pass: RECLASS (same time+lane, different drum) — more specific than MOVE
	for g in gen_unmatched:
		var g_time := float(g.get("time", 0.0))
		var g_lane := int(g.get("lane", 0))
		var g_drum := String(g.get("drum", "kick")).to_lower()
		var g_key_time_lane := "%0.4f|%d" % [g_time, g_lane]
		var found := false
		for c in cor_unmatched:
			var c_key := EditorNoteUtils.note_key(c as Dictionary)
			if cor_used.has(c_key):
				continue
			var c_time := float(c.get("time", 0.0))
			var c_lane := int(c.get("lane", 0))
			var c_drum := String(c.get("drum", "kick")).to_lower()
			var c_key_time_lane := "%0.4f|%d" % [c_time, c_lane]
			if g_key_time_lane == c_key_time_lane and g_drum != c_drum:
				reclassed.append({"from": (g as Dictionary).duplicate(true), "to": (c as Dictionary).duplicate(true)})
				cor_used[c_key] = true
				gen_used[EditorNoteUtils.note_key(g as Dictionary)] = true
				found = true
				break
	# Second pass: MOVE (same drum, time or lane changed)
	for g in gen_unmatched:
		var gk := EditorNoteUtils.note_key(g as Dictionary)
		if gen_used.has(gk):
			continue
		var g_drum := String(g.get("drum", "kick")).to_lower()
		var best_c = null
		var best_key = ""
		for c in cor_unmatched:
			var ck := EditorNoteUtils.note_key(c as Dictionary)
			if cor_used.has(ck):
				continue
			var c_drum := String(c.get("drum", "kick")).to_lower()
			if c_drum != g_drum:
				continue
			# Same drum, check if time/lane differs
			var g_time := float(g.get("time", 0.0))
			var g_lane := int(g.get("lane", 0))
			var c_time := float(c.get("time", 0.0))
			var c_lane := int(c.get("lane", 0))
			if absf(g_time - c_time) > TIME_EPSILON or g_lane != c_lane:
				best_c = c
				best_key = ck
				break
		if best_c != null:
			moved.append({"from": (g as Dictionary).duplicate(true), "to": (best_c as Dictionary).duplicate(true)})
			cor_used[best_key] = true
			gen_used[gk] = true
	# Remaining gen -> deleted, cor -> added
	for g in gen_unmatched:
		var gk := EditorNoteUtils.note_key(g as Dictionary)
		if not gen_used.has(gk):
			deleted.append((g as Dictionary).duplicate(true))
	for c in cor_unmatched:
		var ck := EditorNoteUtils.note_key(c as Dictionary)
		if not cor_used.has(ck):
			added.append((c as Dictionary).duplicate(true))
	return {"added": added, "deleted": deleted, "moved": moved, "reclassed": reclassed}

static func is_diff_empty(diff: Dictionary) -> bool:
	return int(diff.get("added", []).size()) == 0 and int(diff.get("deleted", []).size()) == 0 and int(diff.get("moved", []).size()) == 0 and int(diff.get("reclassed", []).size()) == 0

static func build_payload(
	song_path: String,
	instrument: String,
	base_stem: String,
	version: int,
	source_notes: Array,
	corrected_notes: Array,
	actions: Array,
	parent_version: int = 0,
	parent_hash: String = "",
	bpm: float = 0.0,
	lanes: int = 0,
	source_path: String = ""
) -> Dictionary:
	var cid := NotesUtils.chart_id_from_song_path(song_path)
	var src_hash := _hash_notes(source_notes)
	var cur_hash := _hash_notes(corrected_notes)
	var parent_name := version_name(parent_version) if parent_version > 0 else ""
	var cur_name := version_name(version) if version > 0 else ""
	var diff := compute_diff(source_notes, corrected_notes)
	var payload := {
		"version": RFC_VERSION,
		"chart_id": cid,
		"song_path": song_path,
		"instrument": instrument.to_lower(),
		"base_stem": base_stem.to_lower(),
		"current_version": version,
		"current_version_name": cur_name,
		"current_hash": cur_hash,
		"parent_version": parent_version,
		"parent_version_name": parent_name,
		"parent_hash": parent_hash,
		"source": {
			"path": source_path,
			"hash": src_hash,
			"notes_count": source_notes.size(),
		},
		"current": {
			"hash": cur_hash,
			"notes_count": corrected_notes.size(),
		},
		"lanes": lanes,
		"bpm": bpm,
		"actions": actions.duplicate(true),
		"diff": diff,
		"updated_at": _now_iso(),
	}
	return payload

static func serialize(payload: Dictionary) -> String:
	return JSON.stringify(payload, "\t")

static func deserialize(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}

static func write_file(path: String, payload: Dictionary) -> bool:
	var abs_path := DirectoryUtils.to_absolute(path)
	if abs_path == "":
		return false
	if not DirectoryUtils.ensure_dir_for_file(abs_path):
		return false
	var tmp_path := abs_path + ".tmp"
	var text := serialize(payload)
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	# Validate JSON
	var check := FileAccess.open(tmp_path, FileAccess.READ)
	if check == null:
		return false
	var check_text := check.get_as_text()
	check.close()
	if deserialize(check_text).is_empty():
		DirAccess.remove_absolute(tmp_path)
		return false
	if FileAccess.file_exists(abs_path):
		var bak := abs_path + ".bak"
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		if DirAccess.rename_absolute(abs_path, bak) != OK:
			DirAccess.remove_absolute(tmp_path)
			return false
	if DirAccess.rename_absolute(tmp_path, abs_path) == OK:
		var bak2 := abs_path + ".bak"
		if FileAccess.file_exists(bak2):
			DirAccess.remove_absolute(bak2)
		return true
	# Fallback copy
	var rf := FileAccess.open(tmp_path, FileAccess.READ)
	if rf == null:
		return false
	var data := rf.get_buffer(rf.get_length())
	rf.close()
	var wf := FileAccess.open(abs_path, FileAccess.WRITE)
	if wf == null:
		return false
	wf.store_buffer(data)
	wf.close()
	DirAccess.remove_absolute(tmp_path)
	return true

static func read_file(path: String) -> Dictionary:
	var abs_path := DirectoryUtils.to_absolute(path)
	if abs_path == "" or not FileAccess.file_exists(abs_path):
		return {}
	var f := FileAccess.open(abs_path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	return deserialize(text)

static func validate_payload(payload: Dictionary) -> String:
	if payload.is_empty():
		return "empty payload"
	if int(payload.get("version", 0)) != RFC_VERSION:
		return "unsupported version"
	if String(payload.get("chart_id", "")) == "":
		return "missing chart_id"
	var src: Dictionary = payload.get("source", {}) as Dictionary
	if src.is_empty() or String(src.get("hash", "")) == "":
		return "missing source hash"
	return ""
