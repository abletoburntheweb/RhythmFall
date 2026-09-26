# logic/domain/editor/rf_temp_codec.gd
extends RefCounted
class_name RfTempCodec

# .rf.temp recovery snapshot codec — Stage C
# Stores full current document state for crash recovery, next to specific .rf

const RfcCorrectionsCodec = preload("res://logic/domain/editor/rfc_corrections_codec.gd")

const TEMP_VERSION := 1

static func temp_path_for_rf(rf_path: String) -> String:
	var p := String(rf_path).strip_edges()
	if p == "":
		return ""
	return p + ".temp"

static func temp_path_for_versioned(song_path: String, instrument: String, base_stem: String, version: int) -> String:
	var rf_path := RfcCorrectionsCodec.versioned_path_for(song_path, instrument, base_stem, version, "rf")
	return temp_path_for_rf(rf_path)

static func _hash_notes(arr: Array) -> String:
	return RfcCorrectionsCodec._hash_notes(arr)

static func _now_iso() -> String:
	return Time.get_datetime_string_from_system(true)

static func build_payload(
	song_path: String,
	instrument: String,
	base_stem: String,
	version: int,
	notes: Array,
	bpm: float,
	lanes: int,
	source_notes: Array,
	source_path: String,
	source_hash: String,
	parent_version: int = 0,
	parent_hash: String = ""
) -> Dictionary:
	var cid := NotesUtils.chart_id_from_song_path(song_path)
	var cur_hash := _hash_notes(notes)
	var src_hash := source_hash
	if src_hash == "":
		src_hash = _hash_notes(source_notes)
	var cur_name := RfcCorrectionsCodec.version_name(version) if version > 0 else ""
	var parent_name := RfcCorrectionsCodec.version_name(parent_version) if parent_version > 0 else ""
	var payload := {
		"version": TEMP_VERSION,
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
			"notes_count": notes.size(),
		},
		"lanes": lanes,
		"bpm": bpm,
		"notes": notes.duplicate(true),
		"recovery": {
			"saved_at": _now_iso(),
			"reason": "autosave",
		},
		"integrity": {
			"hash": cur_hash,
			"notes_count": notes.size(),
		},
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

static func write_file(temp_path: String, payload: Dictionary) -> bool:
	var abs_path := DirectoryUtils.to_absolute(temp_path)
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
	# Validate
	var check := FileAccess.open(tmp_path, FileAccess.READ)
	if check == null:
		return false
	var check_text := check.get_as_text()
	check.close()
	var parsed := deserialize(check_text)
	if parsed.is_empty():
		DirAccess.remove_absolute(tmp_path)
		return false
	var err := validate_payload(parsed)
	if err != "":
		DirAccess.remove_absolute(tmp_path)
		return false
	# Atomic replace
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

static func read_file(temp_path: String) -> Dictionary:
	var abs_path := DirectoryUtils.to_absolute(temp_path)
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
	if int(payload.get("version", 0)) != TEMP_VERSION:
		return "unsupported version"
	if String(payload.get("chart_id", "")) == "":
		return "missing chart_id"
	var notes: Array = payload.get("notes", []) as Array
	if notes.is_empty() and int(payload.get("current", {}).get("notes_count", 0)) > 0:
		return "missing notes but count >0"
	var src: Dictionary = payload.get("source", {}) as Dictionary
	if src.is_empty() or String(src.get("hash", "")) == "":
		return "missing source hash"
	var integ: Dictionary = payload.get("integrity", {}) as Dictionary
	var expected_hash: String = String(integ.get("hash", ""))
	var actual_hash: String = _hash_notes(notes)
	if expected_hash != "" and expected_hash != actual_hash:
		return "integrity hash mismatch"
	var notes_count: int = int(payload.get("current", {}).get("notes_count", notes.size()))
	if notes_count != notes.size():
		return "notes_count mismatch"
	return ""

static func delete_temp(temp_path: String) -> bool:
	var abs_path := DirectoryUtils.to_absolute(temp_path)
	if abs_path == "" or not FileAccess.file_exists(abs_path):
		return true
	return DirAccess.remove_absolute(abs_path) == OK

static func temp_exists_for_versioned(song_path: String, instrument: String, base_stem: String, version: int) -> bool:
	var tp := temp_path_for_versioned(song_path, instrument, base_stem, version)
	return FileAccess.file_exists(DirectoryUtils.to_absolute(tp))
