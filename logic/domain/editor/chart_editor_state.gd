# logic/domain/editor/chart_editor_state.gd
extends RefCounted
class_name ChartEditorState

const RfcCodec = preload("res://logic/domain/editor/rfc_corrections_codec.gd")

# Single source of truth for editor. Plain data + helpers, no Node.

var song_path: String = ""
var chart_id: String = ""
var instrument: String = "drums"
var chart_stem: String = "arcade_medium"
var base_stem: String = "arcade_medium"
var version: int = 0 # 0 = Generated, >0 = Corrected vN
var is_corrected: bool = false
var is_canonical: bool = true
var canonical_stem: String = "arcade_medium"

var bpm: float = 120.0
var duration_s: float = 0.0
var lanes: int = 5

var chart_path: String = "" # Specific .rf path when opened via picker (preserved version)
var document: ChartDocument = null
var grid: ChartGrid = null
var corrections: ChartEditorCorrections = null
# New .rfc versioning (Stage B) — authoritative for corrected versions
var rfc_payload: Dictionary = {}
var source_notes_cache: Array = []
var source_hash_cache: String = ""
var parent_version_cache: int = 0
var parent_hash_cache: String = ""

var song_time: float = 0.0
var px_per_sec: float = 360.0 # Logical travel scale (kept constant for editor, 360 = 100%)
var view_scale: float = 1.0 # Viewport zoom (0.5..2.0) — visual only, does not affect logical geometry (spec 10)
var snap_enabled: bool = true
var snap_division: int = 16

var selected_keys: Dictionary = {} # Set[String]=true, key = EditorNoteUtils.note_key
var primary_key: String = ""

var is_dirty: bool = false
var is_playing: bool = false

# Clipboard for copy/paste (in-memory).
var clipboard: Array = []
var clipboard_min_time: float = 0.0

const PerfTrace = preload("res://logic/utils/perf_trace.gd")

func setup(p_song_path: String, p_chart_stem: String, p_lanes: int = 5, p_chart_path: String = "") -> String:
	var _t_setup := PerfTrace.begin("perf.detail.chart_editor.setup_state")
	var _t_path := PerfTrace.begin("perf.detail.chart_editor.setup_path")
	song_path = p_song_path
	# If specific chart_path provided (from picker), preserve it and derive stem/version from it
	if p_chart_path.strip_edges() != "" and FileAccess.file_exists(DirectoryUtils.to_absolute(p_chart_path.strip_edges().replace("\\", "/"))):
		chart_path = p_chart_path.strip_edges().replace("\\", "/")
		# Derive stem from file name for version tracking (keep _vN)
		var fname := chart_path.get_file()
		var base_name := fname.get_basename() # without .rf
		if base_name.to_lower().begins_with("drums_"):
			var extracted := base_name.substr(6) # after drums_
			if extracted != "":
				p_chart_stem = extracted
	else:
		chart_path = ""
	chart_stem = p_chart_stem.strip_edges().to_lower()
	if chart_stem == "":
		chart_stem = "arcade_medium"
	canonical_stem = "arcade_medium"
	# Parse version from stem for corrected handling (Stage B)
	var parsed = RfcCodec.parse_base_and_version(chart_stem)
	base_stem = String(parsed.get("base", chart_stem)).to_lower()
	version = int(parsed.get("version", 0))
	is_corrected = version > 0
	is_canonical = (base_stem == canonical_stem)
	var _t_cid := PerfTrace.begin("perf.detail.chart_editor.chart_id")
	chart_id = NotesUtils.chart_id_from_song_path(song_path)
	PerfTrace.end("perf.detail.chart_editor.chart_id", _t_cid)
	lanes = clampi(p_lanes, 3, 5)
	instrument = "drums"
	PerfTrace.end("perf.detail.chart_editor.setup_path", _t_path)
	# If specific chart_path was provided, try to load directly from it
	if chart_path != "" and FileAccess.file_exists(DirectoryUtils.to_absolute(chart_path)):
		var direct_notes: Array = []
		var RfcChartCodecDirect = preload("res://logic/domain/charts/rfc_chart_codec.gd")
		var _t_rfc := PerfTrace.begin("perf.detail.chart_editor.rfc_read")
		direct_notes = RfcChartCodecDirect.read_file(chart_path)
		PerfTrace.end("perf.detail.chart_editor.rfc_read", _t_rfc)
		if direct_notes.is_empty():
			# Fallback: try NotesUtils for non-versioned direct path
			var _t_n1 := PerfTrace.begin("perf.detail.chart_editor.notes_load")
			direct_notes = NotesUtils.load_notes_array(song_path, "drums", chart_stem, lanes)
			PerfTrace.end("perf.detail.chart_editor.notes_load", _t_n1)
		var _t_doc_new := PerfTrace.begin("perf.detail.chart_editor.doc_new")
		document = ChartDocument.new(song_path, chart_stem, lanes)
		PerfTrace.end("perf.detail.chart_editor.doc_new", _t_doc_new)
		if not direct_notes.is_empty():
			var _t_sort := PerfTrace.begin("perf.detail.chart_editor.notes_sort")
			document.notes = EditorNoteUtils.sort_by_time(EditorNoteUtils.clone_notes(direct_notes))
			PerfTrace.end("perf.detail.chart_editor.notes_sort", _t_sort)
		else:
			var _t_doc_load := PerfTrace.begin("perf.detail.chart_editor.doc_load")
			var err2 := document.load_from_disk()
			PerfTrace.end("perf.detail.chart_editor.doc_load", _t_doc_load)
			if err2 != "":
				PerfTrace.end("perf.detail.chart_editor.setup_state", _t_setup)
				return err2
	else:
		var _t_doc_new2 := PerfTrace.begin("perf.detail.chart_editor.doc_new")
		document = ChartDocument.new(song_path, chart_stem, lanes)
		PerfTrace.end("perf.detail.chart_editor.doc_new", _t_doc_new2)
		var _t_doc_load2 := PerfTrace.begin("perf.detail.chart_editor.doc_load")
		var err2 := document.load_from_disk()
		PerfTrace.end("perf.detail.chart_editor.doc_load", _t_doc_load2)
		if err2 != "":
			PerfTrace.end("perf.detail.chart_editor.setup_state", _t_setup)
			return err2
	var _t_doc_load3 := PerfTrace.begin("perf.detail.chart_editor.doc_load")
	var err := document.load_from_disk()
	PerfTrace.end("perf.detail.chart_editor.doc_load", _t_doc_load3)
	if err != "":
		PerfTrace.end("perf.detail.chart_editor.setup_state", _t_setup)
		return err
	# BPM/duration from document (already loaded via SongLibrary). Allow override from DNA later.
	bpm = document.bpm if document.bpm > 0.0 else 120.0
	duration_s = document.duration_s if document.duration_s > 0.0 else 0.0
	# Try to get real duration from SongLibrary metadata
	var _t_meta := PerfTrace.begin("perf.detail.chart_editor.metadata")
	if duration_s <= 0.0 and SongLibrary:
		var meta2 = SongLibrary.get_metadata_for_song(song_path)
		var dur_str = str(meta2.get("duration", ""))
		if dur_str != "" and dur_str != "00:00" and dur_str != "Н/Д":
			if ":" in dur_str:
				var parts = dur_str.split(":")
				if parts.size() >= 2:
					var m = int(parts[0]) if String(parts[0]).is_valid_int() else 0
					var s = int(parts[1]) if String(parts[1]).is_valid_int() else 0
					duration_s = float(m * 60 + s)
	PerfTrace.end("perf.detail.chart_editor.metadata", _t_meta)
	# Fallback to audio length
	var _t_audiolen := PerfTrace.begin("perf.detail.chart_editor.audio_len")
	if duration_s <= 0.0:
		var stream = FilePathUtils.load_audio_stream_for_path(song_path) if FilePathUtils else null
		if stream and stream.has_method("get_length"):
			var alen = float(stream.get_length())
			if alen > 0.0:
				duration_s = alen
	PerfTrace.end("perf.detail.chart_editor.audio_len", _t_audiolen)
	# Fallback to last note +2
	if duration_s <= 0.0 and document.notes.size() > 0:
		var last_n = document.notes[document.notes.size()-1]
		duration_s = float(last_n.get("time", 0.0)) + 2.0
	if duration_s <= 0.0:
		duration_s = 60.0
	# Try enrich bpm/duration from RhythmDNA if available.
	var _t_dna := PerfTrace.begin("perf.detail.chart_editor.rhythm_dna")
	var dna := NotesUtils.load_rhythm_dna(song_path, instrument, chart_stem, lanes)
	PerfTrace.end("perf.detail.chart_editor.rhythm_dna", _t_dna)
	if not dna.is_empty():
		var track: Dictionary = dna.get("track", {})
		var dna_bpm := float(track.get("bpm", 0.0))
		if dna_bpm > 0.0:
			bpm = dna_bpm
	# Grid: try beats from DNA if present (structure_sections store not needed for P0).
	var beats_arr: Array[float] = []
	if dna.has("beats") and dna["beats"] is Array:
		for v in dna["beats"]:
			beats_arr.append(float(v))
	var _t_grid := PerfTrace.begin("perf.detail.chart_editor.grid")
	grid = ChartGrid.new(bpm, duration_s, beats_arr)
	PerfTrace.end("perf.detail.chart_editor.grid", _t_grid)
	var _t_corr_new := PerfTrace.begin("perf.detail.chart_editor.corrections_new")
	corrections = ChartEditorCorrections.new(song_path, chart_stem)
	corrections.lanes = lanes
	corrections.bpm = bpm
	PerfTrace.end("perf.detail.chart_editor.corrections_new", _t_corr_new)
	var _t_corr_load := PerfTrace.begin("perf.detail.chart_editor.corrections_load")
	var c_err := corrections.load()
	PerfTrace.end("perf.detail.chart_editor.corrections_load", _t_corr_load)
	if c_err != "":
		pass
	var _t_corr_snap := PerfTrace.begin("perf.detail.chart_editor.corrections_snapshot")
	corrections.ensure_source_snapshot(document.notes)
	PerfTrace.end("perf.detail.chart_editor.corrections_snapshot", _t_corr_snap)
	# Stage B: try load new .rfc for corrected versions
	rfc_payload = {}
	source_notes_cache = []
	source_hash_cache = ""
	parent_version_cache = 0
	parent_hash_cache = ""
	var _t_rfc_stage := PerfTrace.begin("perf.detail.chart_editor.rfc_stage")
	if is_corrected:
		var rfc_path = RfcCodec.rfc_path_for_versioned(song_path, instrument, base_stem, version)
		var _t_rfc_read2 := PerfTrace.begin("perf.detail.chart_editor.rfc_read")
		var payload = RfcCodec.read_file(rfc_path)
		PerfTrace.end("perf.detail.chart_editor.rfc_read", _t_rfc_read2)
		if not payload.is_empty():
			rfc_payload = payload
			var src: Dictionary = payload.get("source", {}) as Dictionary
			source_hash_cache = String(src.get("hash", ""))
			parent_version_cache = int(payload.get("parent_version", 0))
			parent_hash_cache = String(payload.get("parent_hash", ""))
			# Also populate old corrections actions for compatibility (so future saves inherit history)
			var rfc_actions = payload.get("actions", [])
			if rfc_actions is Array and not rfc_actions.is_empty():
				corrections.actions = (rfc_actions as Array).duplicate(true)
				corrections._next_action_id = int(payload.get("next_action_id", rfc_actions.size() + 1)) if payload.has("next_action_id") else rfc_actions.size() + 1
			# Source notes: try generated base
			var _t_gen1 := PerfTrace.begin("perf.detail.chart_editor.notes_load")
			var gen_notes = NotesUtils.load_notes_array(song_path, instrument, base_stem, lanes)
			PerfTrace.end("perf.detail.chart_editor.notes_load", _t_gen1)
			if not gen_notes.is_empty():
				source_notes_cache = gen_notes
				if source_hash_cache == "":
					source_hash_cache = RfcCodec._hash_notes(source_notes_cache)
			if source_notes_cache.is_empty():
				var gen_path = RfcCodec.versioned_path_for(song_path, instrument, base_stem, 0, "rf")
				var _t_gen2 := PerfTrace.begin("perf.detail.chart_editor.notes_load")
				var gen_arr = NotesUtils.load_notes_array(song_path, instrument, base_stem, lanes)
				PerfTrace.end("perf.detail.chart_editor.notes_load", _t_gen2)
				if not gen_arr.is_empty():
					source_notes_cache = gen_arr
					if source_hash_cache == "":
						source_hash_cache = RfcCodec._hash_notes(source_notes_cache)
		else:
			# No .rfc yet for this corrected version (legacy or new without .rfc) — treat source as generated and keep any existing corrections actions
			var _t_gen3 := PerfTrace.begin("perf.detail.chart_editor.notes_load")
			var gen_arr2 = NotesUtils.load_notes_array(song_path, instrument, base_stem, lanes)
			PerfTrace.end("perf.detail.chart_editor.notes_load", _t_gen3)
			if not gen_arr2.is_empty():
				source_notes_cache = gen_arr2
				source_hash_cache = RfcCodec._hash_notes(source_notes_cache)
			# If we have old corrections with actions, keep them; otherwise empty
	else:
		# Generated: source is itself
		var _t_clone := PerfTrace.begin("perf.detail.chart_editor.notes_clone")
		source_notes_cache = EditorNoteUtils.clone_notes(document.notes)
		PerfTrace.end("perf.detail.chart_editor.notes_clone", _t_clone)
		var _t_hash := PerfTrace.begin("perf.detail.chart_editor.hash")
		source_hash_cache = RfcCodec._hash_notes(source_notes_cache)
		PerfTrace.end("perf.detail.chart_editor.hash", _t_hash)
	PerfTrace.end("perf.detail.chart_editor.rfc_stage", _t_rfc_stage)
	# Selection empty initially.
	selected_keys.clear()
	primary_key = ""
	clipboard.clear()
	is_dirty = false
	PerfTrace.end("perf.detail.chart_editor.setup_state", _t_setup)
	return ""

func note_count() -> int:
	return document.note_count() if document else 0

func has_selection() -> bool:
	return not selected_keys.is_empty()

func selected_notes() -> Array:
	if document == null or document.notes.is_empty():
		return []
	var out: Array = []
	for n in document.notes:
		var k := EditorNoteUtils.note_key(n as Dictionary)
		if selected_keys.has(k):
			out.append(n)
	return out

func select_only(keys: Array) -> void:
	selected_keys.clear()
	for k in keys:
		selected_keys[String(k)] = true
	primary_key = String(keys[0]) if not keys.is_empty() else ""

func toggle_selection(keys: Array) -> void:
	for k in keys:
		var sk := String(k)
		if selected_keys.has(sk):
			selected_keys.erase(sk)
			if primary_key == sk:
				primary_key = ""
		else:
			selected_keys[sk] = true
			primary_key = sk

func clear_selection() -> void:
	selected_keys.clear()
	primary_key = ""

func mark_dirty() -> void:
	is_dirty = true

func mark_clean() -> void:
	is_dirty = false
