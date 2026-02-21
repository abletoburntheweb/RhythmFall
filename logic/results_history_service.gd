# logic/results_history_service.gd
class_name ResultsHistoryService
extends RefCounted

const SESSION_HISTORY_PATH = "user://session_history.json"
const MAX_SESSIONS = 20

func load_results_for_song(song_path: String) -> Array:
	var results: Array = []
	if song_path.is_empty():
		return results
	var song_file_name = song_path.get_file().get_basename()
	var results_file_path = "user://results/%s_results.json" % song_file_name
	if FileAccess.file_exists(results_file_path):
		var file = FileAccess.open(results_file_path, FileAccess.READ)
		if file:
			var json_str = file.get_as_text()
			var json_result = JSON.parse_string(json_str)
			if json_result and json_result is Array:
				results = json_result
			file.close()
	return results

func save_result_for_song(song_path: String, instrument_type: String, score: int, accuracy: float, grade: String = "N/A", grade_color: Color = Color.WHITE, result_datetime: String = ""):
	if song_path.is_empty():
		return
	var dir = DirAccess.open("user://")
	if not dir:
		return
	if not dir.dir_exists("results"):
		var mk = dir.make_dir("results")
		if mk != OK:
			return
	var results = load_results_for_song(song_path)
	var new_result = {
		"score": score,
		"accuracy": accuracy,
		"instrument": instrument_type,
		"date": result_datetime if result_datetime != "" else Time.get_datetime_string_from_system(true, true),
		"grade": grade,
		"grade_color": { "r": grade_color.r, "g": grade_color.g, "b": grade_color.b, "a": grade_color.a },
	}
	results.append(new_result)
	results.sort_custom(func(a, b):
		if a.get("score", 0) != b.get("score", 0):
			return a.get("score", 0) > b.get("score", 0)
		else:
			return a.get("accuracy", 0.0) > b.get("accuracy", 0.0)
	)
	if results.size() > 20:
		results.resize(20)
	var song_file_name = song_path.get_file().get_basename()
	var results_file_path = "user://results/%s_results.json" % song_file_name
	var file = FileAccess.open(results_file_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(results, "\t")
		file.store_string(json_string)
		file.close()

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
	results.sort_custom(func(a, b):
		if a.get("score", 0) != b.get("score", 0):
			return a.get("score", 0) > b.get("score", 0)
		else:
			return a.get("accuracy", 0.0) > b.get("accuracy", 0.0)
	)
	return results[0]

func add_session_result(accuracy: float, date_str: String, grade: String, grade_color: Color, instrument: String, score: int, artist: String = "N/A", title: String = "N/A"):
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
	var history = _load_history()
	history.push_front(new_result)
	if history.size() > MAX_SESSIONS:
		history.resize(MAX_SESSIONS)
	_save_history(history)

func get_history() -> Array[Dictionary]:
	return _load_history()

func get_history_for_instrument(target_instrument: String) -> Array[Dictionary]:
	var filtered_history: Array[Dictionary] = []
	for session in _load_history():
		if session.get("instrument", "") == target_instrument:
			filtered_history.append(session)
	return filtered_history

func clear_history():
	_save_history([])

func _load_history() -> Array[Dictionary]:
	var history: Array[Dictionary] = []
	var file_access = FileAccess.open(SESSION_HISTORY_PATH, FileAccess.READ)
	if file_access:
		var json_text = file_access.get_as_text()
		file_access.close()
		var json_result = JSON.parse_string(json_text)
		if json_result is Array:
			for item in json_result:
				if item is Dictionary and item.has("accuracy") and item.has("date"):
					history.append(item)
	return history

func _save_history(history: Array[Dictionary]):
	var file_access = FileAccess.open(SESSION_HISTORY_PATH, FileAccess.WRITE)
	if file_access:
		var json_text = JSON.stringify(history, "\t")
		file_access.store_string(json_text)
		file_access.close()
