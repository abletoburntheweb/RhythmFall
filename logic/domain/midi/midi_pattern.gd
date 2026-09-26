# logic/domain/midi/midi_pattern.gd
extends RefCounted
class_name MidiPattern

# Drum pattern asset — one .mid = one pattern. Preserves leading offset, vel/dur when present.
# No artificial vel/dur for legacy notes.

const PATTERN_VERSION := 1

var id: String = "" # hash or sanitized name
var name: String = ""
var source_path: String = ""
var source_hash: String = ""
var ppq: int = 480
var bpm: float = 120.0
var time_sig: String = "4/4"
var duration_sec: float = 0.0
var leading_offset: float = 0.0
var notes_rel: Array = [] # Array[Dictionary{relTime:float, pitch:int, vel:int, duration:float, channel:int, track:int}]
var tracks_meta: Array = [] # for diagnostics
var import_warnings: Array = [] # optional

static func from_parser_result(parsed: Dictionary, source_path: String, source_hash: String = "") -> MidiPattern:
	var pat := MidiPattern.new()
	pat.source_path = source_path
	pat.source_hash = source_hash
	pat.ppq = int(parsed.get("ppq", 480))
	pat.bpm = float(parsed.get("bpm", 120.0))
	pat.time_sig = String(parsed.get("timeSig", "4/4"))
	pat.duration_sec = float(parsed.get("durationSec", 0.0))
	pat.leading_offset = float(parsed.get("leadingOffset", 0.0))
	pat.tracks_meta = (parsed.get("tracksMeta", []) as Array).duplicate(true)
	var raw_notes: Array = parsed.get("notes", [])
	var out: Array = []
	for n in raw_notes:
		if not n is Dictionary:
			continue
		var d := n as Dictionary
		var entry := {}
		entry["relTime"] = float(d.get("relTime", d.get("start_sec", 0.0)))
		entry["pitch"] = int(d.get("pitch", 60))
		if d.has("vel"):
			entry["vel"] = int(d.get("vel"))
		if d.has("duration"):
			var dur := float(d.get("duration", 0.0))
			if dur > 0.0:
				entry["duration"] = dur
		if d.has("channel"):
			entry["channel"] = int(d.get("channel"))
		if d.has("track"):
			entry["track"] = int(d.get("track"))
		out.append(entry)
	out.sort_custom(func(a, b): return float(a.get("relTime", 0.0)) < float(b.get("relTime", 0.0)))
	pat.notes_rel = out
	pat.name = source_path.get_file().get_basename() if source_path != "" else "Pattern"
	if pat.name == "":
		pat.name = "Pattern"
	pat.id = pat.name.to_lower().replace(" ", "_")
	if pat.id == "":
		pat.id = "pattern_%s" % pat.source_hash.substr(0, 8) if pat.source_hash != "" else "pattern"
	return pat

func note_count() -> int:
	return notes_rel.size()

func to_dict() -> Dictionary:
	return {
		"version": PATTERN_VERSION,
		"id": id,
		"name": name,
		"source_path": source_path,
		"source_hash": source_hash,
		"ppq": ppq,
		"bpm": bpm,
		"timeSig": time_sig,
		"durationSec": duration_sec,
		"leadingOffset": leading_offset,
		"notesRel": notes_rel.duplicate(true),
		"tracksMeta": tracks_meta.duplicate(true),
	}

static func from_dict(d: Dictionary) -> MidiPattern:
	var pat := MidiPattern.new()
	pat.id = String(d.get("id", ""))
	pat.name = String(d.get("name", "Pattern"))
	pat.source_path = String(d.get("source_path", ""))
	pat.source_hash = String(d.get("source_hash", ""))
	pat.ppq = int(d.get("ppq", 480))
	pat.bpm = float(d.get("bpm", 120.0))
	pat.time_sig = String(d.get("timeSig", "4/4"))
	pat.duration_sec = float(d.get("durationSec", 0.0))
	pat.leading_offset = float(d.get("leadingOffset", 0.0))
	pat.notes_rel = (d.get("notesRel", []) as Array).duplicate(true)
	pat.tracks_meta = (d.get("tracksMeta", []) as Array).duplicate(true)
	return pat

static func file_hash_for_path(path: String) -> String:
	var abs_path := DirectoryUtils.to_absolute(path)
	if abs_path == "" or not FileAccess.file_exists(abs_path):
		return ""
	var fa := FileAccess.open(abs_path, FileAccess.READ)
	if fa == null:
		return ""
	var data := fa.get_buffer(fa.get_length())
	fa.close()
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(data)
	return ctx.finish().hex_encode().substr(0, 16)
