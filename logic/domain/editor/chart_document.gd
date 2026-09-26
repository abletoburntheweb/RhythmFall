# logic/domain/editor/chart_document.gd
extends RefCounted
class_name ChartDocument

# In-memory chart being edited. Notes are Array[Dictionary] with {time,lane,drum,type}.
# Does NOT own file I/O — that is ChartEditorCorrections.

var song_path: String = ""
var chart_id: String = ""
var instrument: String = "drums"
var chart_stem: String = "arcade_medium"
var lanes: int = 5
var bpm: float = 120.0
var duration_s: float = 0.0
var notes: Array = [] # sorted by time
var header_artist: String = ""
var header_title: String = ""

func _init(p_song_path: String = "", p_chart_stem: String = "arcade_medium", p_lanes: int = 5) -> void:
	song_path = p_song_path
	chart_stem = p_chart_stem.strip_edges().to_lower()
	if chart_stem == "":
		chart_stem = "arcade_medium"
	lanes = clampi(p_lanes, 3, 5)
	instrument = "drums"
	if song_path != "":
		chart_id = NotesUtils.chart_id_from_song_path(song_path)

func load_from_disk() -> String:
	# Returns error string or "" on success. Populates notes/bpm/duration.
	if song_path == "":
		return "song_path empty"
	# Stage B: handle versioned stems (e.g. arcade_medium_v1 or "Fix chorus snare v2") directly
	var RfcVerCodec = preload("res://logic/domain/editor/rfc_corrections_codec.gd")
	if RfcVerCodec.is_versioned_stem(chart_stem):
		var base_v := RfcVerCodec.base_stem_from_versioned(chart_stem)
		var ver_v := RfcVerCodec.version_from_stem(chart_stem)
		var vpath := RfcVerCodec.versioned_path_for(song_path, instrument, base_v, ver_v, "rf")
		var abs_v := DirectoryUtils.to_absolute(vpath)
		if FileAccess.file_exists(abs_v):
			var RfcChartCodec = preload("res://logic/domain/charts/rfc_chart_codec.gd")
			var arr_v := RfcChartCodec.read_file(vpath)
			notes = EditorNoteUtils.sort_by_time(EditorNoteUtils.clone_notes(arr_v))
			var header_lanes_v := RfcChartCodec.read_header_lanes(vpath, lanes)
			lanes = clampi(header_lanes_v, 3, 5)
			if SongLibrary:
				var meta_v := SongLibrary.get_metadata_for_song(song_path)
				bpm = _parse_bpm(meta_v.get("bpm", 0))
				duration_s = _parse_duration(meta_v.get("duration", "00:00"))
			if bpm <= 0.0:
				bpm = 120.0
			return ""
	var resolved := NotesUtils.resolve_existing_path(song_path, instrument, chart_stem, lanes)
	if resolved == "":
		resolved = NotesUtils.resolve_unified_mode_path(song_path, instrument, chart_stem)
	if resolved == "":
		return "chart not found: %s %s" % [instrument, chart_stem]
	var arr := NotesUtils.load_notes_array(song_path, instrument, chart_stem, lanes)
	notes = EditorNoteUtils.sort_by_time(EditorNoteUtils.clone_notes(arr))
	var header_lanes := NotesUtils.read_chart_lanes(resolved, lanes)
	lanes = clampi(header_lanes, 3, 5)
	# BPM/duration from SongLibrary.
	if SongLibrary:
		var meta := SongLibrary.get_metadata_for_song(song_path)
		bpm = _parse_bpm(meta.get("bpm", 0))
		duration_s = _parse_duration(meta.get("duration", "00:00"))
	if bpm <= 0.0:
		bpm = 120.0
	# Also try to enrich duration from audio length if available via FilePathUtils? Keep metadata for P0.
	return ""

func clone_notes() -> Array:
	return EditorNoteUtils.clone_notes(notes)

func set_notes(new_notes: Array) -> void:
	notes = EditorNoteUtils.sort_by_time(EditorNoteUtils.clone_notes(new_notes))

func note_count() -> int:
	return notes.size()

func add_note(time: float, lane: int, drum: String) -> Dictionary:
	var n := EditorNoteUtils.make_note(time, lane, drum, lanes)
	notes.append(n)
	notes = EditorNoteUtils.sort_by_time(notes)
	return n

func remove_notes_by_keys(keys: Dictionary) -> int:
	# keys is Set via Dictionary[key]=true where key = note_key
	var removed := 0
	var kept: Array = []
	for n in notes:
		var k := EditorNoteUtils.note_key(n as Dictionary)
		if keys.has(k):
			removed += 1
		else:
			kept.append(n)
	notes = kept
	return removed

func find_note_index_by_key(key: String) -> int:
	for i in range(notes.size()):
		var k := EditorNoteUtils.note_key(notes[i] as Dictionary)
		if k == key:
			return i
	return -1

static func _parse_duration(v) -> float:
	var s := str(v).strip_edges()
	if s == "" or s == "Н/Д" or s == "00:00":
		return 0.0
	if ":" in s:
		var parts := s.split(":")
		if parts.size() >= 2:
			var m := int(parts[0]) if String(parts[0]).is_valid_int() else 0
			var sec := int(parts[1]) if String(parts[1]).is_valid_int() else 0
			return float(m * 60 + sec)
	if s.is_valid_float():
		return float(s)
	return 0.0

static func _parse_bpm(v) -> float:
	var s := str(v).strip_edges()
	if s.is_valid_float():
		return maxf(1.0, float(s))
	if v is int or v is float:
		return maxf(1.0, float(v))
	return 0.0
