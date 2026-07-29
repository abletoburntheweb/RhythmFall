# logic/domain/generation/generation_bulk_queue.gd
class_name GenerationBulkQueue
extends RefCounted

const _GenerationIntents = preload("res://logic/domain/generation/generation_intents.gd")
const _GoalDiff = preload("res://logic/domain/generation/generation_goal_difficulty.gd")


static func song_needs_bpm(song: Dictionary, song_path: String) -> bool:
	var bpm := String(song.get("bpm", "")).strip_edges()
	if bpm == "" or bpm == "Н/Д" or bpm == "-1":
		var meta := SongLibrary.get_metadata_for_song(song_path)
		bpm = String(meta.get("bpm", "")).strip_edges()
	return bpm == "" or bpm == "Н/Д" or bpm == "-1"


static func collect_bpm_paths(force_all: bool) -> Array[String]:
	var paths: Array[String] = []
	for song in SongLibrary.get_songs_list():
		if not song is Dictionary:
			continue
		var path := String(song.get("path", "")).strip_edges()
		if path == "":
			continue
		if force_all or song_needs_bpm(song, path):
			paths.append(path)
	return paths


static func collect_notes_jobs_for_song(
	song_path: String,
	instrument: String,
	generation_mode: String,
	lanes: int,
	_scope_legacy: int,
	force_all: bool,
	custom_chart_tag: String = ""
) -> Array:
	var jobs: Array = []
	var tag := custom_chart_tag if generation_mode == "custom" else ""
	var axes := _GoalDiff.resolve_ready_axes({}, "", "", instrument)
	var stems := _GoalDiff.stems_for_ready_axes(axes.get("goals", []), axes.get("diffs", []))
	var instruments: Array = axes.get("instruments", [instrument])
	for inst_raw in instruments:
		var inst := str(inst_raw)
		for stem_id in stems:
			if force_all or not NotesUtils.notes_exist(song_path, inst, stem_id, lanes, tag):
				var pair := _GoalDiff.pair_from_stem(stem_id)
				var goal_v := str(pair.get("goal", _GoalDiff.DEFAULT_GOAL))
				var diff_v := str(pair.get("difficulty", _GoalDiff.DEFAULT_DIFFICULTY))
				jobs.append({
					"mode": generation_mode,
					"chart_intent": _GoalDiff.intent_for(goal_v, diff_v),
					"chart_stem": stem_id,
					"goal": goal_v,
					"difficulty": diff_v,
					"lanes": lanes,
					"chart_tag": tag,
					"instrument": inst,
				})
	return jobs


static func resolve_song_bpm(song: Dictionary, song_path: String) -> float:
	var song_bpm = song.get("bpm", -1)
	if str(song_bpm) == "-1" or song_bpm == "Н/Д":
		var meta_bpm = SongLibrary.get_metadata_for_song(song_path).get("bpm", "Н/Д")
		if str(meta_bpm) == "-1" or str(meta_bpm) == "Н/Д":
			return -1.0
		song_bpm = str(meta_bpm)
	return float(song_bpm)


static func resolve_auto_identify(song_path: String) -> Dictionary:
	var metadata := SongLibrary.get_metadata_for_song(song_path)
	var has_genres := false
	if metadata.has("genres"):
		if typeof(metadata["genres"]) == TYPE_ARRAY:
			has_genres = metadata["genres"].size() > 0
		else:
			has_genres = str(metadata["genres"]).strip_edges() != ""
	if not has_genres and metadata.has("primary_genre"):
		var pg := str(metadata["primary_genre"]).strip_edges().to_lower()
		has_genres = pg != "" and pg != "unknown"
	var enable_genre_detection := bool(SettingsManager.get_setting("enable_genre_detection", true))
	if has_genres or not enable_genre_detection:
		return {"auto_identify": false, "artist": "Unknown" if not has_genres else "", "title": "Unknown" if not has_genres else ""}
	return {"auto_identify": true, "artist": "", "title": ""}


static func enqueue_bpm_for_library(service: GenerationService, force_all: bool) -> Dictionary:
	var result := {"queued": 0, "skipped": 0, "total": 0}
	if service == null:
		return result
	var paths := collect_bpm_paths(force_all)
	result["total"] = paths.size()
	for path in paths:
		var pos := service.start_bpm_analysis(path)
		if pos == 0:
			result["skipped"] += 1
		elif pos >= 1:
			result["queued"] += 1
	return result


static func enqueue_notes_for_library(
	service: GenerationService,
	instrument: String,
	generation_mode: String,
	lanes: int,
	scope: int,
	force_all: bool,
	custom_chart_tag: String = ""
) -> Dictionary:
	var result := {"queued": 0, "skipped": 0, "skipped_no_bpm": 0, "total_jobs": 0}
	if service == null:
		return result
	for song in SongLibrary.get_songs_list():
		if not song is Dictionary:
			continue
		var song_path := String(song.get("path", "")).strip_edges()
		if song_path == "":
			continue
		var bpm_f := resolve_song_bpm(song, song_path)
		if bpm_f <= 0.0:
			result["skipped_no_bpm"] += 1
			continue
		var id_info := resolve_auto_identify(song_path)
		var jobs := collect_notes_jobs_for_song(
			song_path, instrument, generation_mode, lanes, scope, force_all, custom_chart_tag
		)
		for job in jobs:
			result["total_jobs"] += 1
			var mode: String = str(job.get("mode", generation_mode))
			var job_lanes: int = int(job.get("lanes", lanes))
			var job_instrument := str(job.get("instrument", instrument))
			var chart_tag := str(job.get("chart_tag", ""))
			var chart_intent := str(job.get("chart_intent", "")).strip_edges()
			if chart_intent == "":
				chart_intent = _GenerationIntents.resolve_chart_stem(mode)
			var api_mode := mode
			if _GenerationIntents.is_chart_intent(mode):
				api_mode = _GenerationIntents.intent_to_legacy_mode(mode)
			elif chart_intent != "":
				api_mode = _GenerationIntents.intent_to_legacy_mode(chart_intent)
			var pos := service.start_notes_generation(
				song_path,
				job_instrument,
				bpm_f,
				job_lanes,
				0.2,
				bool(id_info.get("auto_identify", true)),
				str(id_info.get("artist", "")),
				str(id_info.get("title", "")),
				api_mode,
				chart_tag,
				chart_intent,
				str(job.get("goal", "")),
				str(job.get("difficulty", "")),
			)
			if pos == 0:
				result["skipped"] += 1
			elif pos >= 1:
				result["queued"] += 1
	return result
