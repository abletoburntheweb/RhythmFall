# logic/session_history_manager.gd
class_name SessionHistoryManager
extends RefCounted 

const SESSION_HISTORY_PATH = "user://session_history.json"
const MAX_SESSIONS = 20 

var history: Array[Dictionary] = []

func _init():
	_load()

func _load():
	var file_access = FileAccess.open(SESSION_HISTORY_PATH, FileAccess.READ)
	if file_access:
		var json_text = file_access.get_as_text()
		file_access.close()
		var json_result = JSON.parse_string(json_text)
		if json_result is Array:
			var valid_history: Array[Dictionary] = [] 
			for item in json_result:
				if item is Dictionary and item.has("accuracy") and item.has("date"):
					valid_history.append(item)
			history = valid_history
			print("SessionHistoryManager: Загружено %d записей из %s" % [history.size(), SESSION_HISTORY_PATH])
		else:
			print("SessionHistoryManager: Файл %s повреждён или не содержит массив. Создаём пустой." % SESSION_HISTORY_PATH)
			history = []
	else:
		print("SessionHistoryManager: Файл %s не найден. Создаём пустой." % SESSION_HISTORY_PATH)
		history = []

func _save():
	var file_access = FileAccess.open(SESSION_HISTORY_PATH, FileAccess.WRITE)
	if file_access:
		var json_text = JSON.stringify(history, "\t")
		file_access.store_string(json_text)
		file_access.close()
		print("SessionHistoryManager: История сессий сохранена в %s (%d записей)" % [SESSION_HISTORY_PATH, history.size()])
	else:
		printerr("SessionHistoryManager: Ошибка при сохранении в %s" % SESSION_HISTORY_PATH)

func add_session_result(accuracy: float, date_str: String, grade: String, grade_color: Color, instrument: String, score: int):
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
		"score": score
	}
	
	history.push_front(new_result)
	
	if history.size() > MAX_SESSIONS:
		history.resize(MAX_SESSIONS)
	
	_save()

func get_history() -> Array[Dictionary]:
	return history.duplicate(true)

func get_history_for_instrument(target_instrument: String) -> Array[Dictionary]:
	var filtered_history = []
	for session in history:
		if session.get("instrument", "") == target_instrument:
			filtered_history.append(session)
	return filtered_history.duplicate(true)
