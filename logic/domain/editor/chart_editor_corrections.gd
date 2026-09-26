# logic/domain/editor/chart_editor_corrections.gd
extends RefCounted
class_name ChartEditorCorrections

# Sidecar for human corrections. Never mutates generation pipeline.
# Files: user://notes/{chart_id}/drums_{stem}.corrections.json  and  drums_{stem}.source.rf
# Immutable source handling per design уточнение: do NOT declare current .rf as immutable source unless we can prove it.
# Provenance: "verified" (source.rf exists or corrections.source_notes exists) vs "inferred" (snapshot of current .rf on first edit).

const CORRECTIONS_VERSION := 1

var chart_id: String = ""
var song_path: String = ""
var chart_stem: String = "arcade_medium"
var instrument: String = "drums"
var lanes: int = 5
var bpm: float = 120.0
var source_notes: Array = [] # immutable snapshot
var source_provenance: String = "" # "verified" | "inferred" | "missing"
var source_hash: String = ""
var actions: Array = [] # Array[Dictionary] {id, op, at, target, from, to, delta_ms, snap, context}
var _next_action_id: int = 1

static func corrections_path_for(song_path: String, chart_stem: String) -> String:
	var cid := NotesUtils.chart_id_from_song_path(song_path)
	var stem := chart_stem.strip_edges().to_lower()
	if stem == "":
		stem = "arcade_medium"
	# Canonical: user://notes/{id}/drums_{stem}.corrections.json  (instrument drums P0)
	return "%s/drums_%s.corrections.json" % [NotesUtils.chart_dir(cid), stem]

static func source_path_for(song_path: String, chart_stem: String) -> String:
	var cid := NotesUtils.chart_id_from_song_path(song_path)
	var stem := chart_stem.strip_edges().to_lower()
	if stem == "":
		stem = "arcade_medium"
	return "%s/drums_%s.source.rf" % [NotesUtils.chart_dir(cid), stem]

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

func _init(p_song_path: String = "", p_chart_stem: String = "arcade_medium") -> void:
	song_path = p_song_path
	chart_stem = p_chart_stem.strip_edges().to_lower()
	if chart_stem == "":
		chart_stem = "arcade_medium"
	chart_id = NotesUtils.chart_id_from_song_path(song_path) if song_path != "" else ""

func load() -> String:
	var rel := corrections_path_for(song_path, chart_stem)
	var abs_path := DirectoryUtils.to_absolute(rel)
	if abs_path == "" or not FileAccess.file_exists(abs_path):
		# No corrections yet — not an error.
		actions = []
		source_notes = []
		source_provenance = "missing"
		source_hash = ""
		return ""
	var f := FileAccess.open(abs_path, FileAccess.READ)
	if f == null:
		return "cannot open corrections: %s" % abs_path
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not parsed is Dictionary:
		return "corrections: invalid json"
	var d: Dictionary = parsed
	if int(d.get("version", 0)) != CORRECTIONS_VERSION:
		# Allow future, but warn. For P0 strict.
		pass
	chart_id = String(d.get("chart_id", chart_id))
	song_path = String(d.get("song_path", song_path))
	chart_stem = String(d.get("chart_stem", chart_stem)).to_lower()
	instrument = String(d.get("instrument", instrument))
	lanes = int(d.get("lanes", lanes))
	bpm = float(d.get("bpm", bpm))
	source_notes = d.get("source_notes", []) if d.get("source_notes", []) is Array else []
	source_provenance = String(d.get("source_provenance", "missing"))
	source_hash = String(d.get("source_hash", ""))
	actions = d.get("actions", []) if d.get("actions", []) is Array else []
	_next_action_id = int(d.get("next_action_id", actions.size() + 1))
	if source_hash == "" and not source_notes.is_empty():
		source_hash = _hash_notes(source_notes)
	return ""

func save(bpm_p: float = 0.0, lanes_p: int = 0) -> String:
	if bpm_p > 0.0:
		bpm = bpm_p
	if lanes_p > 0:
		lanes = lanes_p
	var rel := corrections_path_for(song_path, chart_stem)
	DirectoryUtils.ensure_dir_for_file(rel)
	var payload := {
		"version": CORRECTIONS_VERSION,
		"chart_id": chart_id,
		"song_path": song_path,
		"chart_stem": chart_stem,
		"instrument": instrument,
		"lanes": lanes,
		"bpm": bpm,
		"source_hash": source_hash,
		"source_provenance": source_provenance,
		"source_notes": source_notes,
		"actions": actions,
		"next_action_id": _next_action_id,
		"updated_at": _now_iso(),
	}
	var abs_path := DirectoryUtils.to_absolute(rel)
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		return "cannot write corrections: %s" % abs_path
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	return ""

func ensure_source_snapshot(current_notes: Array) -> String:
	# Called on Open and before first Save. Establishes immutable source WITHOUT silently claiming current .rf is generated.
	# Returns provenance used.
	var source_rel := source_path_for(song_path, chart_stem)
	var source_abs := DirectoryUtils.to_absolute(source_rel)
	var has_source_file := source_abs != "" and FileAccess.file_exists(source_abs)
	var has_corrections := actions.size() > 0 or not source_notes.is_empty()

	if has_source_file:
		# Verified: source.rf exists — load it as ground truth (authoritative).
		var src_arr := _load_notes_from_path(source_rel)
		if not src_arr.is_empty():
			source_notes = EditorNoteUtils.clone_notes(src_arr)
			source_hash = _hash_notes(source_notes)
			source_provenance = "verified"
			return source_provenance
		# If we can't read source file, fall through to inferred.

	if has_corrections and not source_notes.is_empty():
		# Already have source snapshot in corrections — verified via prior run.
		source_provenance = "verified" if source_provenance == "verified" else "inferred"
		source_hash = _hash_notes(source_notes) if source_hash == "" else source_hash
		return source_provenance

	# No source file and no prior corrections. We cannot prove current .rf is pure generator output.
	# For P0 we snapshot current notes as "inferred" source — but we MUST NOT overwrite later if proven source appears.
	# Caller should call this again on Save to create source.rf file once (first edit).
	source_notes = EditorNoteUtils.clone_notes(current_notes)
	source_hash = _hash_notes(source_notes)
	source_provenance = "inferred"
	return source_provenance

func ensure_source_file_created() -> String:
	# Persist source_notes to .source.rf ONCE, only if file doesn't exist and we have a snapshot.
	var rel := source_path_for(song_path, chart_stem)
	var abs_path := DirectoryUtils.to_absolute(rel)
	if abs_path == "" or FileAccess.file_exists(abs_path):
		return ""
	if source_notes.is_empty():
		return "no source snapshot to write"
	DirectoryUtils.ensure_dir_for_file(rel)
	# Use RfcChartCodec via NotesUtils helper: write directly via RfcChartCodec to avoid variant tag confusion.
	var ok := _write_notes_to_path(rel, source_notes, lanes)
	if not ok:
		return "failed to write source.rf"
	return ""

func record_action(op: String, payload: Dictionary) -> Dictionary:
	var entry := {
		"id": "a%d" % _next_action_id,
		"op": op,
		"at": _now_iso(),
	}
	_next_action_id += 1
	for k in payload.keys():
		entry[k] = payload[k]
	actions.append(entry)
	return entry

func clear() -> void:
	actions.clear()
	_next_action_id = 1

static func _load_notes_from_path(rel: String) -> Array:
	var abs_path := DirectoryUtils.to_absolute(rel)
	if abs_path == "" or not FileAccess.file_exists(abs_path):
		return []
	var Rfc := preload("res://logic/domain/charts/rfc_chart_codec.gd")
	return Rfc.read_file(abs_path)

static func _write_notes_to_path(rel: String, notes: Array, lanes_p: int) -> bool:
	var Rfc := preload("res://logic/domain/charts/rfc_chart_codec.gd")
	var abs_path := DirectoryUtils.to_absolute(rel)
	# Rfc.write_file expects game path (user://...), not abs; pass rel.
	# We need artist/title for header — leave empty for source snapshot.
	return Rfc.write_file(rel, notes, "drums", "arcade_medium", lanes_p, "", "")
