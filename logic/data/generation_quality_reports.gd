# logic/data/generation_quality_reports.gd
extends RefCounted
class_name GenerationQualityReports

const ROOT_DIR := "user://generation_quality_reports"
const LEGACY_FILE_PATH := "user://generation_quality_reports.json"
const FILE_VERSION := 3

const ISSUE_MISSING_NOTES := "MISSING_NOTES"
const ISSUE_TOO_MANY_NOTES := "TOO_MANY_NOTES"
const ISSUE_WRONG_TIMING := "WRONG_TIMING"
const ISSUE_BROKEN_PATTERN := "BROKEN_PATTERN"
const ISSUE_WRONG_DENSITY := "WRONG_DENSITY"
const ISSUE_OTHER := "OTHER"

const ISSUE_ORDER: Array[String] = [
	ISSUE_MISSING_NOTES,
	ISSUE_TOO_MANY_NOTES,
	ISSUE_WRONG_TIMING,
	ISSUE_BROKEN_PATTERN,
	ISSUE_WRONG_DENSITY,
	ISSUE_OTHER,
]

const ISSUE_LOCALE_KEYS := {
	ISSUE_MISSING_NOTES: "GENQA_ISSUE_MISSING_NOTES",
	ISSUE_TOO_MANY_NOTES: "GENQA_ISSUE_TOO_MANY",
	ISSUE_WRONG_TIMING: "GENQA_ISSUE_WRONG_TIMING",
	ISSUE_BROKEN_PATTERN: "GENQA_ISSUE_BROKEN_PATTERN",
	ISSUE_WRONG_DENSITY: "GENQA_ISSUE_WRONG_DENSITY",
	ISSUE_OTHER: "GENQA_ISSUE_OTHER",
}

const SESSION_META_KEYS: Array[String] = [
	"song_hash",
	"song",
	"song_path",
	"artist",
	"preset",
	"instrument",
	"lanes",
	"bpm",
	"genre",
	"detector",
	"generator_version",
	"chart_file",
	"chart_difficulty",
	"chart_density_nps",
]

const DEFAULT_DETECTOR := "adtof_fast"
const DENSITY_WINDOW_MEASURES := 1

static var _legacy_migrated := false


static func compute_measure_beat(time_sec: float, bpm: float, beats_per_measure: int = 4) -> Dictionary:
	if bpm <= 0.0 or time_sec < 0.0:
		return {"measure": 0, "beat": 0.0}
	var beat_dur := 60.0 / bpm
	var meas_dur := beat_dur * float(beats_per_measure)
	var measure := int(floor(time_sec / meas_dur)) + 1
	var beat := fmod(time_sec, meas_dur) / beat_dur
	return {"measure": measure, "beat": snappedf(beat, 0.01)}


static func measure_start_time(measure: int, bpm: float, beats_per_measure: int = 4) -> float:
	if measure <= 0 or bpm <= 0.0:
		return 0.0
	var beat_dur := 60.0 / bpm
	return float(measure - 1) * beat_dur * float(beats_per_measure)


static func song_hash(song_path: String) -> String:
	return NotesUtils.chart_id_from_song_path(song_path)


static func session_filename(instrument: String, preset: String, lanes: int) -> String:
	return "%s_%s_lanes%d.json" % [
		instrument.strip_edges().to_lower(),
		preset.strip_edges().to_lower(),
		lanes,
	]


static func session_file_path(song_path: String, instrument: String, preset: String, lanes: int) -> String:
	var chart_id := song_hash(song_path)
	return "%s/%s/%s" % [ROOT_DIR, chart_id, session_filename(instrument, preset, lanes)]


static func build_context(
	song_path: String,
	song_time: float,
	bpm: float,
	instrument: String,
	preset: String,
	lanes: int,
	run_modifiers: Array,
	song_title: String = "",
	song_artist: String = ""
) -> Dictionary:
	var path := song_path.strip_edges()
	var meta := {}
	if path != "" and SongLibrary:
		meta = SongLibrary.get_metadata_for_song(path)
	var mb := compute_measure_beat(song_time, bpm)
	var chart_stats := {}
	var chart_difficulty := 0
	if path != "":
		chart_stats = ChartDifficultyAnalyzer.ensure_persisted(path, instrument, preset, lanes)
		if float(chart_stats.get("avg_nps", 0.0)) <= 0.0:
			var fresh := ChartDifficultyAnalyzer.analyze_notes_file(path, instrument, preset, lanes)
			if not fresh.is_empty():
				chart_stats = fresh
		chart_difficulty = int(chart_stats.get("stars", 0))
	var chart_rel := ""
	if path != "":
		chart_rel = NotesUtils.preferred_chart_path(path, instrument, preset, lanes)
	var genre := str(meta.get("primary_genre", meta.get("genre", "unknown"))).strip_edges()
	if genre == "":
		genre = "unknown"
	var song_label := path.get_file().get_basename() if path != "" else ""
	if song_title.strip_edges() != "":
		song_label = song_title.strip_edges()
	var ctx := {
		"id": "%d_%d" % [Time.get_unix_time_from_system(), randi() % 100000],
		"created_at": Time.get_datetime_string_from_system(true),
		"song_hash": song_hash(path),
		"song": song_label,
		"song_path": path,
		"artist": str(meta.get("artist", song_artist)).strip_edges(),
		"preset": preset,
		"instrument": instrument,
		"lanes": lanes,
		"bpm": snappedf(bpm, 0.01),
		"time": snappedf(maxf(0.0, song_time), 3),
		"measure": int(mb.get("measure", 0)),
		"beat": float(mb.get("beat", 0.0)),
		"chart_difficulty": chart_difficulty,
		"chart_density_nps": snappedf(float(chart_stats.get("avg_nps", 0.0)), 2),
		"genre": genre,
		"detector": DEFAULT_DETECTOR,
		"generator_version": "client_%s_build%d" % [AppVersion.get_version(), AppVersion.get_build()],
		"chart_file": chart_rel,
		"run_modifiers": run_modifiers.duplicate() if run_modifiers is Array else [],
	}
	ctx["density"] = compute_density_snapshot(path, instrument, preset, lanes, int(mb.get("measure", 0)), bpm)
	return ctx


static func compute_density_snapshot(
	song_path: String,
	instrument: String,
	preset: String,
	lanes: int,
	center_measure: int,
	bpm: float,
	window_measures: int = DENSITY_WINDOW_MEASURES
) -> Dictionary:
	var empty := {
		"center_measure": center_measure,
		"notes_this_measure": 0,
		"notes_prev_measure": 0,
		"notes_next_measure": 0,
		"window_measures": window_measures,
		"avg_notes_per_measure": 0.0,
	}
	var path := song_path.strip_edges()
	if path == "" or center_measure <= 0 or bpm <= 0.0:
		return empty
	var notes: Array = NotesUtils.load_notes_array(path, instrument, preset, lanes)
	if notes.is_empty():
		return empty
	var counts: Dictionary = {}
	for item in notes:
		if not item is Dictionary:
			continue
		var t := float(item.get("time", -1.0))
		if t < 0.0:
			continue
		var m := int(compute_measure_beat(t, bpm).get("measure", 0))
		if m <= 0:
			continue
		counts[m] = int(counts.get(m, 0)) + 1
	var lo := maxi(1, center_measure - window_measures)
	var hi := center_measure + window_measures
	var total := 0
	var span := 0
	for m in range(lo, hi + 1):
		var c := int(counts.get(m, 0))
		total += c
		span += 1
	return {
		"center_measure": center_measure,
		"notes_this_measure": int(counts.get(center_measure, 0)),
		"notes_prev_measure": int(counts.get(center_measure - 1, 0)),
		"notes_next_measure": int(counts.get(center_measure + 1, 0)),
		"window_measures": window_measures,
		"avg_notes_per_measure": snappedf(float(total) / float(maxi(1, span)), 2),
	}


static func append_report(issue: String, comment: String, context: Dictionary, extras: Dictionary = {}) -> Dictionary:
	_migrate_legacy_if_needed()
	var entry := context.duplicate(true)
	entry["issue"] = issue
	entry["comment"] = comment.strip_edges()
	entry["marked_time"] = float(entry.get("time", 0.0))
	entry["marked_measure"] = int(entry.get("measure", 0))
	entry["marked_beat"] = float(entry.get("beat", 0.0))
	_apply_extras(entry, extras, float(entry.get("bpm", 0.0)))
	var issue_row := _issue_from_full_entry(entry)
	var session := _load_session_file(
		str(entry.get("song_path", "")),
		str(entry.get("instrument", "")),
		str(entry.get("preset", "")),
		int(entry.get("lanes", 0))
	)
	_merge_session_meta(session, entry)
	session["issues"].append(issue_row)
	session["updated_at"] = Time.get_datetime_string_from_system(true)
	_save_session_file(session)
	return _flatten_issue(session, issue_row)


static func close_open_range(
	song_path: String,
	preset: String,
	instrument: String,
	lanes: int,
	end_time: float,
	bpm: float
) -> Dictionary:
	_migrate_legacy_if_needed()
	var path := song_path.strip_edges()
	var session := _load_session_file(path, instrument, preset, lanes)
	var issues: Array = session.get("issues", [])
	for i in range(issues.size() - 1, -1, -1):
		var row: Variant = issues[i]
		if not row is Dictionary:
			continue
		if _report_has_range_end(row):
			continue
		var mb := compute_measure_beat(end_time, bpm)
		row["range_end_time"] = snappedf(maxf(0.0, end_time), 3)
		row["range_end_measure"] = int(mb.get("measure", 0))
		row["range_end_beat"] = float(mb.get("beat", 0.0))
		issues[i] = row
		session["issues"] = issues
		session["updated_at"] = Time.get_datetime_string_from_system(true)
		_save_session_file(session)
		return _flatten_issue(session, row)
	return {}


static func load_reports() -> Array:
	_migrate_legacy_if_needed()
	var flat: Array = []
	for session in load_sessions():
		var issues: Array = session.get("issues", [])
		for issue in issues:
			if issue is Dictionary:
				flat.append(_flatten_issue(session, issue))
	return flat


static func load_sessions() -> Array:
	_migrate_legacy_if_needed()
	var sessions: Array = []
	var root_abs := ProjectSettings.globalize_path(ROOT_DIR)
	if not DirAccess.dir_exists_absolute(root_abs):
		return sessions
	_collect_session_files(root_abs, sessions)
	return sessions


static func report_count() -> int:
	return load_reports().size()


static func export_path_absolute() -> String:
	return ProjectSettings.globalize_path(ROOT_DIR)


static func _collect_session_files(dir_abs: String, out_sessions: Array) -> void:
	var dir := DirAccess.open(dir_abs)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name != "." and name != "..":
			var full := "%s/%s" % [dir_abs, name]
			if dir.current_is_dir():
				_collect_session_files(full, out_sessions)
			elif name.ends_with(".json") and name != "generation_quality_reports.json":
				var rel := _abs_to_user_path(full)
				if rel != "":
					var session := _read_json_file(rel)
					if not session.is_empty():
						out_sessions.append(session)
		name = dir.get_next()
	dir.list_dir_end()


static func _abs_to_user_path(abs_path: String) -> String:
	var norm := abs_path.replace("\\", "/")
	var data_dir := OS.get_user_data_dir().replace("\\", "/")
	if norm.begins_with(data_dir):
		return "user://%s" % norm.substr(data_dir.length()).trim_prefix("/")
	return ""


static func _issue_from_full_entry(entry: Dictionary) -> Dictionary:
	var issue := {}
	for k in entry.keys():
		if k in SESSION_META_KEYS:
			continue
		issue[k] = entry[k]
	return issue


static func _merge_session_meta(session: Dictionary, entry: Dictionary) -> void:
	session["version"] = FILE_VERSION
	for k in SESSION_META_KEYS:
		if entry.has(k):
			session[k] = entry[k]
	if not session.has("issues") or not session.get("issues") is Array:
		session["issues"] = []


static func _flatten_issue(session: Dictionary, issue: Dictionary) -> Dictionary:
	var row := {}
	for k in SESSION_META_KEYS:
		if session.has(k):
			row[k] = session[k]
	for k in issue.keys():
		row[k] = issue[k]
	return row


static func _empty_session(song_path: String, instrument: String, preset: String, lanes: int) -> Dictionary:
	var path := song_path.strip_edges()
	return {
		"version": FILE_VERSION,
		"song_hash": song_hash(path),
		"song": "",
		"song_path": path,
		"artist": "",
		"preset": preset,
		"instrument": instrument,
		"lanes": lanes,
		"bpm": 0.0,
		"genre": "unknown",
		"detector": DEFAULT_DETECTOR,
		"generator_version": "",
		"chart_file": "",
		"chart_difficulty": 0,
		"chart_density_nps": 0.0,
		"updated_at": "",
		"issues": [],
	}


static func _load_session_file(song_path: String, instrument: String, preset: String, lanes: int) -> Dictionary:
	var rel := session_file_path(song_path, instrument, preset, lanes)
	if FileAccess.file_exists(rel):
		var parsed := _read_json_file(rel)
		if not parsed.is_empty():
			if not parsed.get("issues") is Array:
				parsed["issues"] = []
			return parsed
	return _empty_session(song_path, instrument, preset, lanes)


static func _save_session_file(session: Dictionary) -> void:
	var song_path := str(session.get("song_path", "")).strip_edges()
	var instrument := str(session.get("instrument", ""))
	var preset := str(session.get("preset", ""))
	var lanes := int(session.get("lanes", 0))
	var rel := session_file_path(song_path, instrument, preset, lanes)
	var folder_rel := rel.get_base_dir()
	_ensure_dir(folder_rel)
	var f := FileAccess.open(rel, FileAccess.WRITE)
	if f == null:
		push_error("GenerationQualityReports: cannot write %s" % rel)
		return
	f.store_string(JSON.stringify(session, "\t"))


static func _read_json_file(rel_path: String) -> Dictionary:
	if not FileAccess.file_exists(rel_path):
		return {}
	var f := FileAccess.open(rel_path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}


static func _ensure_dir(rel_path: String) -> void:
	var abs := ProjectSettings.globalize_path(rel_path)
	if not DirAccess.dir_exists_absolute(abs):
		DirAccess.make_dir_recursive_absolute(abs)


static func _migrate_legacy_if_needed() -> void:
	if _legacy_migrated:
		return
	_legacy_migrated = true
	if not FileAccess.file_exists(LEGACY_FILE_PATH):
		return
	var legacy := _read_json_file(LEGACY_FILE_PATH)
	var reports: Array = legacy.get("reports", [])
	for row in reports:
		if not row is Dictionary:
			continue
		var full: Dictionary = row
		if not full.has("song_hash"):
			full["song_hash"] = song_hash(str(full.get("song_path", "")))
		var issue_row := _issue_from_full_entry(full)
		var session := _load_session_file(
			str(full.get("song_path", "")),
			str(full.get("instrument", "")),
			str(full.get("preset", "")),
			int(full.get("lanes", 0))
		)
		_merge_session_meta(session, full)
		session["issues"].append(issue_row)
		session["updated_at"] = str(full.get("created_at", Time.get_datetime_string_from_system(true)))
		_save_session_file(session)
	var legacy_abs := ProjectSettings.globalize_path(LEGACY_FILE_PATH)
	if FileAccess.file_exists(LEGACY_FILE_PATH):
		DirAccess.rename_absolute(legacy_abs, legacy_abs + ".migrated")


static func _apply_extras(entry: Dictionary, extras: Dictionary, bpm: float) -> void:
	if extras.is_empty():
		return
	if extras.get("range_end", "") == "eof":
		entry["range_end"] = "eof"
	if extras.has("reaction_lag") and str(extras.get("reaction_lag", "")).strip_edges() != "":
		entry["reaction_lag"] = str(extras.get("reaction_lag", "")).strip_edges()
	var issue_measure := int(extras.get("issue_measure", 0))
	if issue_measure > 0 and bpm > 0.0:
		entry["issue_measure"] = issue_measure
		entry["issue_time"] = snappedf(measure_start_time(issue_measure, bpm), 3)
		entry["issue_beat"] = 0.0


static func _report_has_range_end(row: Dictionary) -> bool:
	if str(row.get("range_end", "")) == "eof":
		return true
	if row.has("range_end_time") and float(row.get("range_end_time", -1.0)) >= 0.0:
		return true
	if int(row.get("range_end_measure", 0)) > 0:
		return true
	return false
