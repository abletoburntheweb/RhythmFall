# logic/utils/profile_milestones_rebuild.gd
class_name ProfileMilestonesRebuild
extends RefCounted

const _ChartDifficulty = preload("res://logic/domain/charts/chart_difficulty_analyzer.gd")
const _RhythmRating = preload("res://logic/domain/rhythm/rhythm_rating.gd")

const RESULTS_DIR := "user://results"
const RESULTS_SUFFIX := "_results.json"


static func rebuild_into(manager: Node) -> void:
	if manager == null or not manager.has_method("on_run_completed"):
		return
	if not DirAccess.dir_exists_absolute(RESULTS_DIR):
		return

	var song_path_map := _build_song_path_map()
	var dir := DirAccess.open(RESULTS_DIR)
	if dir == null:
		return

	var runs: Array[Dictionary] = []
	for file_name in dir.get_files():
		if not file_name.ends_with(RESULTS_SUFFIX):
			continue
		var basename := file_name.trim_suffix(RESULTS_SUFFIX)
		var song_path := str(song_path_map.get(basename, ""))
		if song_path == "":
			song_path = _guess_song_path_from_basename(basename)
		if song_path == "":
			continue
		var raw: Variant = JsonUtils.read_json("%s/%s" % [RESULTS_DIR, file_name])
		var results: Array = []
		if raw is Dictionary:
			results = raw.get("results", [])
		elif raw is Array:
			results = raw
		if not results is Array:
			continue
		for result in results:
			if not result is Dictionary:
				continue
			var run := _result_to_run(song_path, result)
			if not run.is_empty():
				runs.append(run)

	runs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return TimeUtils.result_datetime_sort_key(str(a.get("date", ""))) < TimeUtils.result_datetime_sort_key(str(b.get("date", "")))
	)

	for run in runs:
		manager.on_run_completed(run, true)


static func _build_song_path_map() -> Dictionary:
	var out: Dictionary = {}
	if TrackStatsManager:
		for path in TrackStatsManager.track_completion_counts:
			var normalized := str(path).replace("\\", "/").trim_suffix("/")
			var basename := normalized.get_file().get_basename()
			if basename != "":
				out[basename] = normalized
	if SongLibrary and SongLibrary.has_method("get_songs_list"):
		for song_data in SongLibrary.get_songs_list():
			if not song_data is Dictionary:
				continue
			var normalized := str(song_data.get("path", "")).replace("\\", "/").trim_suffix("/")
			var basename := normalized.get_file().get_basename()
			if basename != "" and not out.has(basename):
				out[basename] = normalized
	return out


static func _guess_song_path_from_basename(basename: String) -> String:
	if basename == "":
		return ""
	var songs_root: String = str(SettingsManager.get_setting("songs_folder", "user://Songs")) if SettingsManager else "user://Songs"
	var candidate := "%s/%s.mp3" % [str(songs_root).trim_suffix("/"), basename]
	if FileAccess.file_exists(ProjectSettings.globalize_path(candidate)):
		return candidate.replace("\\", "/")
	candidate = "%s/%s.wav" % [str(songs_root).trim_suffix("/"), basename]
	if FileAccess.file_exists(ProjectSettings.globalize_path(candidate)):
		return candidate.replace("\\", "/")
	return ""


static func _result_to_run(song_path: String, result: Dictionary) -> Dictionary:
	var modifiers: Array = result.get("modifiers", [])
	if not modifiers is Array:
		modifiers = []

	var instrument := str(result.get("instrument", "standard"))
	var mode := str(result.get("mode", "basic"))
	var lanes := int(result.get("lanes", 4))
	var accuracy := float(result.get("accuracy", 0.0))
	var grade := str(result.get("grade", ""))
	var chart_rating := int(result.get("chart_rating", 0))
	if chart_rating <= 0:
		chart_rating = _RhythmRating.resolve_chart_rating(song_path, instrument, mode, lanes)

	var full_combo := bool(result.get("full_combo", false))
	var max_combo := int(result.get("max_combo", 0))

	var title := str(result.get("title", ""))
	var artist := str(result.get("artist", ""))
	var duration_sec := float(result.get("duration_sec", 0.0))
	var bpm := float(result.get("bpm", 0.0))
	var primary_genre := str(result.get("primary_genre", ""))

	var md: Dictionary = {}
	if SongLibrary:
		md = SongLibrary.get_metadata_for_song(song_path)
	if md is Dictionary:
		if title == "":
			title = str(md.get("title", ""))
		if artist == "":
			artist = str(md.get("artist", ""))
		if duration_sec <= 0.0:
			duration_sec = _parse_duration_sec(str(md.get("duration", "")))
		if bpm <= 0.0:
			bpm = _ChartDifficulty.parse_bpm(md.get("bpm", 0))
		if primary_genre == "":
			primary_genre = str(md.get("primary_genre", ""))

	var medals_new: Array = []
	if result.get("medals_new") is Array:
		medals_new = result["medals_new"]

	return {
		"song_path": song_path,
		"instrument": instrument,
		"mode": mode,
		"lanes": lanes,
		"modifiers": modifiers,
		"accuracy": accuracy,
		"grade": grade,
		"chart_rating": chart_rating,
		"full_combo": full_combo,
		"max_combo": max_combo,
		"score": int(result.get("score", 0)),
		"title": title,
		"artist": artist,
		"date": str(result.get("date", "")),
		"duration_sec": duration_sec,
		"bpm": bpm,
		"primary_genre": primary_genre,
		"medals_new": medals_new,
	}


static func _parse_duration_sec(duration_text: String) -> float:
	var s := duration_text.strip_edges()
	if s == "" or s == "Н/Д" or s.to_lower() == "n/a":
		return 0.0
	if s.contains(":"):
		var parts := s.split(":")
		if parts.size() == 2:
			return float(parts[0].to_int() * 60 + parts[1].to_int())
		if parts.size() == 3:
			return float(parts[0].to_int() * 3600 + parts[1].to_int() * 60 + parts[2].to_int())
	return s.to_float()
