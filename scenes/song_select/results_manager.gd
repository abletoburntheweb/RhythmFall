class_name ResultsManager
extends Node

var player_data_manager = null

func set_player_data_manager(player_data_mgr):
	player_data_manager = player_data_mgr

func show_results_for_song(song_data: Dictionary, results_list: ItemList):
	print("ResultsManager.gd: Показ результатов для песни: %s" % song_data.get("title", "Неизвестная"))
	
	results_list.clear()
	
	var results = load_results_for_song(song_data.get("path", ""))
	
	if results is Array:
		results.sort_custom(func(a, b): return a.get("score", 0) > b.get("score", 0))
	
	for result in results:
		var original_datetime_str = result.get("result_datetime", "N/A")
		var formatted_date_str = "N/A"
		if original_datetime_str != "N/A":
			if original_datetime_str.length() >= 19 and original_datetime_str[4] == '-' and original_datetime_str[7] == '-' and original_datetime_str[10] == ' ' and original_datetime_str[13] == ':' and original_datetime_str[16] == ':':
				var year = original_datetime_str.substr(0, 4)
				var month = original_datetime_str.substr(5, 2)
				var day = original_datetime_str.substr(8, 2)
				var time_part = original_datetime_str.substr(11, 8) 
				formatted_date_str = "%s.%s.%s %s" % [day, month, year, time_part]
			else:
				formatted_date_str = original_datetime_str

		var display_text = "%s - %d очков (%.0f%%) [%s] - %s" % [
			formatted_date_str,            
			result.get("score", 0),       
			result.get("accuracy", 0.0),   
			result.get("instrument", "unknown"), 
			result.get("grade", "N/A")    
		]

		var item_index = results_list.get_item_count() 
		results_list.add_item(display_text)

		var saved_color_data = result.get("grade_color", null)
		if saved_color_data and saved_color_data is Dictionary and saved_color_data.has("r"):
			var saved_grade_color = Color(
				saved_color_data.get("r", 1.0),
				saved_color_data.get("g", 1.0),
				saved_color_data.get("b", 1.0),
				saved_color_data.get("a", 1.0)
			)
			results_list.set_item_custom_fg_color(item_index, saved_grade_color)
			print("ResultsManager.gd: Установлен цвет %s для элемента '%s' (индекс %d)" % [saved_grade_color, display_text, item_index])
		else:
			results_list.set_item_custom_fg_color(item_index, Color.WHITE)
			print("ResultsManager.gd: Цвет не найден, установлен белый для элемента '%s' (индекс %d)" % [display_text, item_index])
	
	if results.size() == 0:
		results_list.add_item("Нет результатов для этой песни")

func load_results_for_song(song_path: String) -> Array:
	var results = []
	
	if song_path.is_empty():
		print("ResultsManager.gd: Пустой путь к песне, невозможно загрузить результаты")
		return []
	
	var song_file_name = song_path.get_file().get_basename()
	var results_file_path = "user://results/%s_results.json" % song_file_name
	
	print("ResultsManager.gd: Пытаемся загрузить результаты из: ", results_file_path)
	
	if FileAccess.file_exists(results_file_path):
		var file = FileAccess.open(results_file_path, FileAccess.READ)
		if file:
			var json_str = file.get_as_text()
			var json_result = JSON.parse_string(json_str)
			
			if json_result and json_result is Array:
				results = json_result
				print("ResultsManager.gd: Загружено %d результатов из файла: %s" % [results.size(), results_file_path])
			else:
				print("ResultsManager.gd: Файл результатов поврежден или пуст: ", results_file_path)
				results = []
		else:
			print("ResultsManager.gd: Не удалось открыть файл результатов для чтения: ", results_file_path)
			results = []
	else:
		print("ResultsManager.gd: Файл результатов не найден, будет создан при первом сохранении: ", results_file_path)
		results = []
	
	return results

func save_result_for_song(song_path: String, instrument_type: String, score: int, accuracy: float, grade: String = "N/A", grade_color: Color = Color.WHITE, result_datetime: String = ""):
	if song_path.is_empty():
		printerr("ResultsManager.gd: Пустой путь к песне, невозможно сохранить результат")
		return
	
	var dir = DirAccess.open("user://")
	if not dir:
		printerr("ResultsManager.gd: Не удалось открыть директорию user://")
		return
	
	if not dir.dir_exists("results"):
		var err = dir.make_dir("results")
		if err == OK:
			print("ResultsManager.gd: Создана директория results")
		else:
			printerr("ResultsManager.gd: Не удалось создать директорию results")
			return
	
	var results = load_results_for_song(song_path)
	
	var new_result = {
		"score": score,
		"accuracy": accuracy,
		"instrument": instrument_type,
		"date": result_datetime if result_datetime != "" else Time.get_datetime_string_from_system(true, true),
		"grade": grade,
		"grade_color": { "r": grade_color.r, "g": grade_color.g, "b": grade_color.b, "a": grade_color.a },
		"result_datetime": result_datetime
	}
	results.append(new_result)
	
	results.sort_custom(func(a, b): return a.get("score", 0) > b.get("score", 0))
	if results.size() > 10:
		results.resize(10)
	
	var song_file_name = song_path.get_file().get_basename()
	var results_file_path = "user://results/%s_results.json" % song_file_name
	
	print("ResultsManager.gd: Сохраняем результат в файл: ", results_file_path)
	
	var file = FileAccess.open(results_file_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(results)
		file.store_string(json_string)
		file.close()
		print("ResultsManager.gd: Результат успешно сохранен для песни %s: %d очков, %.2f%%, инструмент: %s, оценка: %s, дата: %s" % [song_path, score, accuracy, instrument_type, grade, result_datetime])
		print("ResultsManager.gd: JSON содержимое: %s" % json_string)
	else:
		printerr("ResultsManager.gd: Не удалось создать/открыть файл для записи: ", results_file_path)
		var file_create = FileAccess.open(results_file_path, FileAccess.WRITE)
		if file_create:
			file_create.store_string("[]")
			file_create.close()
			print("ResultsManager.gd: Файл результатов создан с пустым массивом: ", results_file_path)
			save_result_for_song(song_path, instrument_type, score, accuracy, grade, grade_color, result_datetime)
		else:
			printerr("ResultsManager.gd: Критическая ошибка - невозможно создать файл: ", results_file_path)

func get_top_result_for_song(song_path: String) -> Dictionary:
	var results = load_results_for_song(song_path)
	if results.size() > 0:
		results.sort_custom(func(a, b): return a.get("score", 0) > b.get("score", 0))
		return results[0]
	return {}
