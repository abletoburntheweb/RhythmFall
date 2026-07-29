# logic/results_history_service.gd
class_name ResultsHistoryService
extends RefCounted

const _TrackMedals = preload("res://logic/domain/library/track_medals.gd")
const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")

const SESSION_HISTORY_PATH = "user://session_history.json"
const MAX_SESSIONS = 20
const RESULTS_KEY := "results"
const MEDALS_KEY := "medals_unlocked"
const MEDALS_SEEN_KEY := "medals_seen"

var _history_cache: Array[Dictionary] = []
var _history_cache_valid := false


static func resolve_backend(results_mgr) -> ResultsHistoryService:
	if results_mgr == null:
		return null
	if results_mgr is ResultsHistoryService:
		return results_mgr
	const ResultsManager = preload("res://scenes/song_select/controllers/results_manager.gd")
	if results_mgr is ResultsManager:
		return results_mgr.results_service
	return null


func load_results_for_song(song_path: String) -> Array:
	return _load_song_file(song_path).get(RESULTS_KEY, [])


func load_medals_for_song(song_path: String) -> Array[String]:
	if song_path.is_empty():
		return []
	return _TrackMedals.sanitize_unlocked(_load_song_file(song_path).get(MEDALS_KEY, []))


func load_medals_seen_for_song(song_path: String) -> Array[String]:
	if song_path.is_empty():
		return []
	return _TrackMedals.sanitize_unlocked(_load_song_file(song_path).get(MEDALS_SEEN_KEY, []))


func load_unseen_medals_for_song(song_path: String) -> Array[String]:
	if song_path.is_empty():
		return []
	var file_data := _load_song_file(song_path)
	var unlocked := _TrackMedals.sanitize_unlocked(file_data.get(MEDALS_KEY, []))
	var seen := _TrackMedals.sanitize_unlocked(file_data.get(MEDALS_SEEN_KEY, []))
	var unseen: Array[String] = []
	for medal_id in unlocked:
		if not seen.has(medal_id):
			unseen.append(medal_id)
	return unseen


func mark_medals_seen_for_song(song_path: String) -> void:
	if song_path.is_empty():
		return
	var file_data := _load_song_file(song_path)
	file_data[MEDALS_SEEN_KEY] = _TrackMedals.sanitize_unlocked(file_data.get(MEDALS_KEY, []))
	_save_song_file(song_path, file_data)


func save_result_for_song(
	song_path: String,
	instrument_type: String,
	score: int,
	accuracy: float,
	grade: String = "N/A",
	grade_color: Color = Color.WHITE,
	result_datetime: String = "",
	mode: String = "",
	ss_repeat: bool = false,
	medals_earned_this_run: Array = [],
	run_modifiers: Array = [],
	full_combo: bool = false,
	max_combo: int = 0,
	chart_rating: int = 0,
	title: String = "",
	artist: String = "",
	lanes: int = 4
) -> Array:
	if song_path.is_empty():
		return []
	var file_data := _load_song_file(song_path)
	var results: Array = file_data.get(RESULTS_KEY, [])
	var new_result := {
		"score": score,
		"accuracy": accuracy,
		"instrument": instrument_type,
		"date": result_datetime if result_datetime != "" else TimeUtils.now_local_datetime_string(),
		"grade": grade,
		"grade_color": { "r": grade_color.r, "g": grade_color.g, "b": grade_color.b, "a": grade_color.a },
	}
	if grade == "SS":
		new_result["ss_repeat"] = ss_repeat
	if mode != "":
		new_result["mode"] = mode
	var mods := _RunModifiers.sanitize(run_modifiers)
	if mods.size() > 0:
		new_result["modifiers"] = mods
	if full_combo:
		new_result["full_combo"] = true
	if max_combo > 0:
		new_result["max_combo"] = max_combo
	if chart_rating > 0:
		new_result["chart_rating"] = chart_rating
	if title != "":
		new_result["title"] = title
	if artist != "":
		new_result["artist"] = artist
	if lanes > 0:
		new_result["lanes"] = lanes
	results.append(new_result)
	results.sort_custom(TimeUtils.sort_results_newest_first)
	if results.size() > 20:
		results.resize(20)
	var prev_unlocked := _TrackMedals.sanitize_unlocked(file_data.get(MEDALS_KEY, []))
	var unlocked := _TrackMedals.compute_unlocked(results)
	var earned_run: Array[String] = []
	for medal_id in unlocked:
		if not prev_unlocked.has(medal_id):
			earned_run.append(medal_id)
	if earned_run.size() > 0:
		new_result["medals_new"] = earned_run
	file_data[RESULTS_KEY] = results
	file_data[MEDALS_KEY] = unlocked
	_save_song_file(song_path, file_data)
	return earned_run

func clear_results_for_song(song_path: String) -> bool:
	if song_path.is_empty():
		return false
	var song_file_name = song_path.get_file().get_basename()
	var results_file_path = "user://results/%s_results.json" % song_file_name
	var dir_access_instance = DirAccess.open("user://")
	if dir_access_instance and dir_access_instance.dir_exists("results") and FileAccess.file_exists(results_file_path):
		return dir_access_instance.remove(results_file_path) == OK
	return true

func get_top_result_for_song(song_path: String) -> Dictionary:
	var results = load_results_for_song(song_path)
	if results.size() == 0:
		return {}
	results.sort_custom(TimeUtils.sort_results_by_score)
	return results[0]

func add_session_result(accuracy: float, date_str: String, grade: String, grade_color: Color, instrument: String, score: int, artist: String = "N/A", title: String = "N/A", ss_repeat: bool = false, run_rr: int = -1, song_path: String = ""):
	var new_result = {
		"accuracy": accuracy,
		"date": date_str,
		"grade": grade,
		"grade_color": {
			"r": grade_color.r,
			"g": grade_color.g,
			"b": grade_color.b,
			"a": grade_color.a
		},
		"instrument": instrument,
		"score": score,
		"artist": artist,
		"title": title
	}
	if song_path.strip_edges() != "":
		new_result["song_path"] = song_path.replace("\\", "/").trim_suffix("/")
	if run_rr >= 0:
		new_result["run_rr"] = run_rr
	if grade == "SS":
		new_result["ss_repeat"] = ss_repeat
	var history = _load_history()
	history.push_front(new_result)
	if history.size() > MAX_SESSIONS:
		history.resize(MAX_SESSIONS)
	_save_history(history)

func get_history() -> Array[Dictionary]:
	if not _history_cache_valid:
		_history_cache = _load_history()
		_history_cache_valid = true
	return _history_cache

func get_history_for_instrument(target_instrument: String) -> Array[Dictionary]:
	var filtered_history: Array[Dictionary] = []
	for session in _load_history():
		if session.get("instrument", "") == target_instrument:
			filtered_history.append(session)
	return filtered_history

func clear_history():
	_save_history([])


func invalidate_history_cache() -> void:
	_history_cache_valid = false


func get_global_medal_stats() -> Dictionary:
	var total_medal_count := 0
	var tracks_with_full_set := 0
	var tracks_with_ss_medal := 0
	var tracks_with_hard_mode_medal := 0
	var counts_by_id: Dictionary = {}
	for medal_id in _TrackMedals.ALL_IDS:
		counts_by_id[medal_id] = 0
	if not DirAccess.dir_exists_absolute("user://results"):
		return {
			"total_medal_count": 0,
			"tracks_with_full_set": 0,
			"tracks_with_ss_medal": 0,
			"tracks_with_hard_mode_medal": 0,
			"counts_by_id": counts_by_id,
		}
	var dir := DirAccess.open("user://results")
	if dir == null:
		return {
			"total_medal_count": 0,
			"tracks_with_full_set": 0,
			"tracks_with_ss_medal": 0,
			"tracks_with_hard_mode_medal": 0,
			"counts_by_id": counts_by_id,
		}
	for file_name in dir.get_files():
		if not file_name.ends_with("_results.json"):
			continue
		var raw: Variant = JsonUtils.read_json("user://results/" + file_name)
		var unlocked: Array[String] = []
		if raw is Dictionary:
			var results: Array = raw.get(RESULTS_KEY, [])
			if results is Array:
				unlocked = _TrackMedals.compute_unlocked(results)
			else:
				unlocked = _TrackMedals.sanitize_unlocked(raw.get(MEDALS_KEY, []))
		total_medal_count += unlocked.size()
		for medal_id in unlocked:
			if counts_by_id.has(medal_id):
				counts_by_id[medal_id] = int(counts_by_id[medal_id]) + 1
		if unlocked.size() >= _TrackMedals.COUNT:
			tracks_with_full_set += 1
		if unlocked.has(_TrackMedals.ID_GRADE_SS):
			tracks_with_ss_medal += 1
		if unlocked.has(_TrackMedals.ID_HARD_MODE_CLEAR):
			tracks_with_hard_mode_medal += 1
	return {
		"total_medal_count": total_medal_count,
		"tracks_with_full_set": tracks_with_full_set,
		"tracks_with_ss_medal": tracks_with_ss_medal,
		"tracks_with_hard_mode_medal": tracks_with_hard_mode_medal,
		"counts_by_id": counts_by_id,
	}


func _results_file_path(song_path: String) -> String:
	var song_file_name = song_path.get_file().get_basename()
	return "user://results/%s_results.json" % song_file_name


func _load_song_file(song_path: String) -> Dictionary:
	var empty := {
		RESULTS_KEY: [],
		MEDALS_KEY: [],
		MEDALS_SEEN_KEY: [],
	}
	if song_path.is_empty():
		return empty
	var results_file_path := _results_file_path(song_path)
	var raw: Variant = JsonUtils.read_json(results_file_path)
	if raw is Array:
		return {
			RESULTS_KEY: raw,
			MEDALS_KEY: [],
			MEDALS_SEEN_KEY: [],
		}
	if raw is Dictionary:
		var results: Array = raw.get(RESULTS_KEY, [])
		if not results is Array:
			results = []
		var unlocked := _TrackMedals.compute_unlocked(results)
		var seen_raw: Variant = raw.get(MEDALS_SEEN_KEY, null)
		var seen: Array[String] = []
		if seen_raw is Array:
			seen = _TrackMedals.sanitize_unlocked(seen_raw)
		else:
			seen = unlocked.duplicate()
		for medal_id in seen.duplicate():
			if not unlocked.has(medal_id):
				seen.erase(medal_id)
		return {
			RESULTS_KEY: results,
			MEDALS_KEY: unlocked,
			MEDALS_SEEN_KEY: seen,
		}
	return empty


func _save_song_file(song_path: String, file_data: Dictionary) -> void:
	var results_file_path := _results_file_path(song_path)
	JsonUtils.write_json(results_file_path, file_data, true, true)


func _load_history() -> Array[Dictionary]:
	var history: Array[Dictionary] = []
	var arr: Array = JsonUtils.read_json_array(SESSION_HISTORY_PATH)
	for item in arr:
		if item is Dictionary and item.has("accuracy") and item.has("date"):
			history.append(item)
	return history

func _save_history(history: Array[Dictionary]):
	_history_cache = history
	_history_cache_valid = true
	JsonUtils.write_json(SESSION_HISTORY_PATH, history, true, true)
