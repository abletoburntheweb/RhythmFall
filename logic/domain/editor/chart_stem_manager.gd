# logic/domain/editor/chart_stem_manager.gd
extends RefCounted
class_name ChartStemManager

const PerfTrace = preload("res://logic/utils/perf_trace.gd")

# Client-side drum stem lookup. P0: lookup-only, fetch is async via GenerationService (optional).
# Server stems are at server temp_uploads/{id}/splitter — not on client. Client may have user://stems/{id}_drums.wav if previously fetched.

static func persistent_stem_path_for(song_path: String, kind: String = "drums") -> String:
	var _t := PerfTrace.begin("perf.detail.chart_editor.stem_persistent")
	if String(song_path).strip_edges() == "":
		PerfTrace.end("perf.detail.chart_editor.stem_persistent", _t)
		return ""
	var k := kind.strip_edges().to_lower()
	if k not in ["drums", "bass"]:
		PerfTrace.end("perf.detail.chart_editor.stem_persistent", _t)
		return ""
	# Chart_id is organizational/path identity, same as notes/charts
	var chart_id := ""
	if NotesUtils:
		chart_id = String(NotesUtils.chart_id_from_song_path(song_path)).strip_edges().to_lower()
	if chart_id == "" or chart_id.length() != 16:
		PerfTrace.end("perf.detail.chart_editor.stem_persistent", _t)
		return ""
	var base_dir := ""
	if SettingsManager and SettingsManager.has_method("get_stem_storage_path"):
		base_dir = String(SettingsManager.get_stem_storage_path())
	else:
		base_dir = String(SettingsManager.get_setting("stem_storage_path", "")) if SettingsManager else ""
	if base_dir.strip_edges() == "":
		base_dir = "user://stems"
	while base_dir.ends_with("/"):
		base_dir = base_dir.substr(0, base_dir.length() - 1)
	# New structure: <stem_storage>/<chart_id>/<kind>_<model>.mp3 (only mp3 as final)
	var chart_dir := "%s/%s" % [base_dir, chart_id]
	var abs_chart_dir := DirectoryUtils.to_absolute(chart_dir)
	if abs_chart_dir == "" or not DirAccess.dir_exists_absolute(abs_chart_dir):
		PerfTrace.end("perf.detail.chart_editor.stem_persistent", _t)
		return ""
	var prefix := "%s_" % k
	var candidates: Array[String] = []
	var by_model: Dictionary = {}
	var d := DirAccess.open(abs_chart_dir)
	if d == null:
		PerfTrace.end("perf.detail.chart_editor.stem_persistent", _t)
		return ""
	d.list_dir_begin()
	var fname := d.get_next()
	while fname != "":
		if not d.current_is_dir() and fname.begins_with(prefix) and fname.ends_with(".mp3"):
			var rel := "%s/%s" % [chart_dir, fname]
			var info := validate_stem(rel)
			if bool(info.get("valid", false)):
				candidates.append(rel)
				# Model = part between prefix and extension
				var model_part := fname.substr(prefix.length(), fname.length() - prefix.length() - 4)
				if not by_model.has(model_part):
					by_model[model_part] = []
				(by_model[model_part] as Array).append(rel)
		fname = d.get_next()
	d.list_dir_end()
	if candidates.is_empty():
		PerfTrace.end("perf.detail.chart_editor.stem_persistent", _t)
		return ""
	if by_model.size() == 1:
		# One model — return its mp3
		var sole_model: String = (by_model.keys()[0] as String)
		var files: Array = by_model[sole_model] as Array
		PerfTrace.end("perf.detail.chart_editor.stem_persistent", _t)
		return String(files[0]) if files.size() > 0 else ""
	if by_model.size() > 1:
		print("[ChartStemManager] persistent ambiguous for chart_id=%s kind=%s found %d models %d files, fallback" % [chart_id, k, by_model.size(), candidates.size()])
	PerfTrace.end("perf.detail.chart_editor.stem_persistent", _t)
	return ""


static func stem_path_for(song_path: String, kind: String = "drums") -> String:
	var _t := PerfTrace.begin("perf.detail.chart_editor.stem_resolve")
	var cid := NotesUtils.chart_id_from_song_path(song_path)
	var k := kind.strip_edges().to_lower()
	if k == "":
		k = "drums"
	# Client-stored stems (if any). We check two roots: user://stems and user://notes/{id}/splitter
	var candidates: Array[String] = [
		"user://stems/%s_%s.wav" % [cid, k],
		"%s/splitter/%s_%s.wav" % [NotesUtils.chart_dir(cid), cid, k],
	]
	for rel in candidates:
		var abs_path := DirectoryUtils.to_absolute(rel)
		if abs_path != "" and FileAccess.file_exists(abs_path):
			PerfTrace.end("perf.detail.chart_editor.stem_resolve", _t)
			return rel
	PerfTrace.end("perf.detail.chart_editor.stem_resolve", _t)
	return ""

static func server_stem_path_for(song_path: String, kind: String = "drums") -> String:
	var _t := PerfTrace.begin("perf.detail.chart_editor.stem_server")
	var cid := NotesUtils.chart_id_from_song_path(song_path)
	var k := kind.strip_edges().to_lower()
	if k == "":
		k = "drums"
	var song_name := song_path.get_file().get_basename().strip_edges()
	# Debug logging for stem discovery (spec 8) — not per frame
	var do_log := true
	if do_log:
		print("[ChartStemManager] server_stem_path_for song_name='%s' hash='%s' kind='%s' song_path='%s'" % [song_name, cid, k, song_path])
	var candidates: Array[String] = []
	# Primary: server temp_uploads with hash or song name, as used by RhythmFallServer
	# The actual file for astrid - glaive is at .../temp_uploads/astrid - glaive/splitter/astrid - glaive_drums.wav
	if song_name != "":
		# Direct song name (with spaces) — the real server layout
		candidates.append("res://RhythmFallServer/temp_uploads/%s/splitter/%s_%s.wav" % [song_name, song_name, k])
		candidates.append("res://RhythmFallServer/temp_uploads/%s/%s_%s.wav" % [song_name, song_name, k])
		candidates.append("res://RhythmFallServer/temp_uploads/%s_%s/%s_%s.wav" % [song_name, k, song_name, k])
		var safe_name := song_name.replace(" ", "_")
		if safe_name != song_name:
			candidates.append("res://RhythmFallServer/temp_uploads/%s/splitter/%s_%s.wav" % [safe_name, safe_name, k])
	if cid != "":
		candidates.append("res://RhythmFallServer/temp_uploads/%s/splitter/%s_%s.wav" % [cid, cid, k])
		candidates.append("res://RhythmFallServer/temp_uploads/%s/%s_%s.wav" % [cid, cid, k])
		candidates.append("res://RhythmFallServer/temp_uploads/%s_%s/%s_%s.wav" % [cid, k, cid, k])
		candidates.append("res://RhythmFallServer/temp_uploads/%s_%s" % [cid, k])
	# Also check absolute production path when running from copy (res:// maps to copy, but file is in production)
	var prod_base := "D:/Games/godotprojects/RhythmFall/RhythmFallServer/temp_uploads"
	for rel in candidates.duplicate():
		if rel.begins_with("res://RhythmFallServer/temp_uploads/"):
			var suffix: String = rel.substr("res://RhythmFallServer/temp_uploads/".length())
			candidates.append(prod_base + "/" + suffix)
	# Check each candidate
	for rel in candidates:
		var abs_path := DirectoryUtils.to_absolute(rel) if rel.begins_with("res://") or rel.begins_with("user://") else rel
		if rel.begins_with("D:/"):
			abs_path = rel
		var exists := abs_path != "" and FileAccess.file_exists(abs_path)
		if exists:
			var info_log := validate_stem(rel)
			print("[ChartStemManager] FOUND candidate='%s' abs='%s' exists=%s load=%s duration=%.2f valid=%s reason='%s'" % [rel, abs_path, str(exists), str(info_log.get("stream", null) != null), float(info_log.get("duration", 0.0)), str(bool(info_log.get("valid", false))), str(info_log.get("reason", ""))])
			PerfTrace.end("perf.detail.chart_editor.stem_server", _t)
			return rel if rel.begins_with("res://") or rel.begins_with("user://") else rel
		else:
			# Log miss at debug level (only for key paths to avoid spam, but show all for astrid)
			if song_name == "astrid - glaive" or cid == "67dc7a1c98bd43e8" or rel.contains("astrid"):
				print("[ChartStemManager] miss candidate='%s' abs='%s' exists=%s" % [rel, abs_path, str(exists)])
		if abs_path != "" and DirAccess.dir_exists_absolute(abs_path):
			var d := DirAccess.open(abs_path)
			if d:
				d.list_dir_begin()
				var fname := d.get_next()
				while fname != "":
					if not d.current_is_dir() and (fname.to_lower().ends_with(".wav") or fname.to_lower().ends_with(".mp3") or fname.to_lower().ends_with(".ogg")):
						print("[ChartStemManager] FOUND via dir scan candidate='%s' file='%s'" % [rel, fname])
						PerfTrace.end("perf.detail.chart_editor.stem_server", _t)
						return rel + "/" + fname if not rel.ends_with("/") else rel + fname
					fname = d.get_next()
				d.list_dir_end()
	var fallback_candidate := "D:/Games/godotprojects/RhythmFall/RhythmFallServer/temp_uploads/%s/splitter/%s_%s.wav" % [song_name, song_name, k] if song_name != "" else ""
	if fallback_candidate != "":
		var abs_fb := fallback_candidate
		var exists_fb := FileAccess.file_exists(abs_fb)
		var info_fb: Dictionary = validate_stem(fallback_candidate) if exists_fb else {"valid": false, "reason": "file not found", "duration": 0.0, "stream": null}
		print("[ChartStemManager] final fallback candidate='%s' abs='%s' exists=%s duration=%.2f valid=%s" % [fallback_candidate, abs_fb, str(exists_fb), float(info_fb.get("duration", 0.0)), str(bool(info_fb.get("valid", false)))])
	print("[ChartStemManager] NO stem found for song_name='%s' hash='%s'" % [song_name, cid])
	PerfTrace.end("perf.detail.chart_editor.stem_server", _t)
	return ""

static func server_stem_candidates(song_path: String, kind: String = "drums") -> Array[String]:
	var cid := NotesUtils.chart_id_from_song_path(song_path)
	var k := kind.strip_edges().to_lower()
	if k == "":
		k = "drums"
	var out: Array[String] = []
	if cid != "":
		out.append("res://RhythmFallServer/temp_uploads/%s_%s" % [cid, k])
	if song_path.get_file().get_basename().strip_edges() != "":
		out.append("res://RhythmFallServer/temp_uploads/%s_%s" % [song_path.get_file().get_basename().strip_edges().replace(" ", "_"), k])
	return out

static var _diag_calls: int = 0
static var _diag_usec_total: int = 0
static var _diag_usec_max: int = 0

static func _diag_reset() -> void:
	_diag_calls = 0
	_diag_usec_total = 0
	_diag_usec_max = 0

static func _diag_snapshot() -> Dictionary:
	return {"calls": _diag_calls, "total": _diag_usec_total, "max": _diag_usec_max}

static func validate_stem(path: String) -> Dictionary:
	# IMPLEMENTATION 2: cheap validation for optional stem — no audio decode.
	# Returns {valid: bool, reason: String, duration: float, stream: AudioStream}
	var _diag_t := Time.get_ticks_usec()
	_diag_calls += 1
	var rel := String(path).strip_edges()
	if rel == "":
		var _dt0 := Time.get_ticks_usec() - _diag_t
		_diag_usec_total += _dt0
		_diag_usec_max = maxi(_diag_usec_max, _dt0)
		return {"valid": false, "reason": "empty path", "duration": 0.0, "stream": null}
	var abs_path := DirectoryUtils.to_absolute(rel)
	var exists := abs_path != "" and FileAccess.file_exists(abs_path)
	if abs_path == "" or not exists:
		if rel.contains("astrid") or rel.contains("67dc7a1c98bd43e8"):
			print("[ChartStemManager] validate miss rel='%s' abs='%s' exists=%s" % [rel, abs_path, str(exists)])
		var _dt1 := Time.get_ticks_usec() - _diag_t
		_diag_usec_total += _dt1
		_diag_usec_max = maxi(_diag_usec_max, _dt1)
		return {"valid": false, "reason": "file not found", "duration": 0.0, "stream": null}
	# Cheap checks: extension and file size (>1KB), no decode
	var ext := abs_path.get_extension().to_lower()
	if ext not in ["wav", "mp3", "ogg"]:
		var _dt2 := Time.get_ticks_usec() - _diag_t
		_diag_usec_total += _dt2
		_diag_usec_max = maxi(_diag_usec_max, _dt2)
		return {"valid": false, "reason": "unsupported extension", "duration": 0.0, "stream": null}
	var f := FileAccess.open(abs_path, FileAccess.READ)
	var fsize := 0
	if f:
		fsize = int(f.get_length())
		f.close()
	if fsize < 1024:
		var _dt3 := Time.get_ticks_usec() - _diag_t
		_diag_usec_total += _dt3
		_diag_usec_max = maxi(_diag_usec_max, _dt3)
		return {"valid": false, "reason": "too small", "duration": 0.0, "stream": null}
	if rel.contains("astrid") or rel.contains("drums") or abs_path.contains("astrid"):
		print("[ChartStemManager] validate OK (cheap) rel='%s' abs='%s' size=%d" % [rel, abs_path, fsize])
	var _dt4 := Time.get_ticks_usec() - _diag_t
	_diag_usec_total += _dt4
	_diag_usec_max = maxi(_diag_usec_max, _dt4)
	return {"valid": true, "reason": "", "duration": 0.0, "stream": null}

static func has_stem(song_path: String, kind: String = "drums") -> bool:
	var _t := PerfTrace.begin("perf.detail.chart_editor.has_stem")
	if persistent_stem_path_for(song_path, kind) != "":
		PerfTrace.end("perf.detail.chart_editor.has_stem", _t)
		return true
	if server_stem_path_for(song_path, kind) != "":
		PerfTrace.end("perf.detail.chart_editor.has_stem", _t)
		return true
	if stem_path_for(song_path, kind) != "":
		PerfTrace.end("perf.detail.chart_editor.has_stem", _t)
		return true
	PerfTrace.end("perf.detail.chart_editor.has_stem", _t)
	return false

static func stem_status(song_path: String) -> Dictionary:
	# For UI badge.
	var has := has_stem(song_path, "drums")
	return {
		"has_stem": has,
		"path": stem_path_for(song_path, "drums") if has else "",
		"hint": "Drum stem available" if has else "Drum stem not found — mix preview only",
	}
