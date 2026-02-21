# scenes/song_select/results_manager.gd
class_name ResultsManager
extends Node

var achievement_system = null
var replay_achievement_sent_for_song: Dictionary = {}
var results_service: ResultsHistoryService = preload("res://logic/results_history_service.gd").new()

func set_achievement_system(ach_sys):
	achievement_system = ach_sys

func show_results_for_song(song_data: Dictionary, results_list: ItemList):
	
	results_list.clear()
	
	var results = results_service.load_results_for_song(song_data.get("path", ""))
	
	if results is Array:
		results.sort_custom(func(a, b): 
			if a.get("accuracy", 0.0) != b.get("accuracy", 0.0):
				return a.get("accuracy", 0.0) > b.get("accuracy", 0.0) 
			else:
				return a.get("score", 0) > b.get("score", 0) 
		)

	if results.size() > 0:
		var top_result = results[0]
		var header_idx = results_list.add_item("Лучший результат")
		results_list.set_item_custom_bg_color(header_idx, Color(0.25, 0.25, 0.15, 1.0))
		results_list.set_item_selectable(header_idx, false)
		var original_datetime_str_top = str(top_result.get("date", "N/A"))
		var formatted_date_str_top = "N/A"
		if original_datetime_str_top != "N/A":
			formatted_date_str_top = _format_iso_to_ddmmyyyy_hhmmss(original_datetime_str_top)
		var display_text_top = "%s - %d очков (%.0f%%) [%s] - %s" % [
			formatted_date_str_top,
			top_result.get("score", 0),
			top_result.get("accuracy", 0.0),
			top_result.get("instrument", "unknown"),
			top_result.get("grade", "N/A")
		]
		var item_idx_top = results_list.add_item(display_text_top)
		var saved_color_data_top = top_result.get("grade_color", null)
		var grade_top = str(top_result.get("grade", "N/A"))
		if grade_top == "SS":
			results_list.set_item_custom_fg_color(item_idx_top, Color("#F2B35A"))
		elif saved_color_data_top and saved_color_data_top is Dictionary and saved_color_data_top.has("r"):
			var saved_grade_color_top = Color(
				saved_color_data_top.get("r", 1.0),
				saved_color_data_top.get("g", 1.0),
				saved_color_data_top.get("b", 1.0),
				saved_color_data_top.get("a", 1.0)
			)
			results_list.set_item_custom_fg_color(item_idx_top, saved_grade_color_top)
		else:
			results_list.set_item_custom_fg_color(item_idx_top, Color.WHITE)

	var grouped_results = {}
	for result in results:
		var grade = result.get("grade", "N/A")
		var instrument = result.get("instrument", "unknown")
		var group_key = grade + " (" + instrument + ")"

		if not grouped_results.has(group_key):
			grouped_results[group_key] = {
				"grade": grade,
				"instrument": instrument,
				"results": []
			}
		grouped_results[group_key].results.append(result)

	var grade_order = {"SS": 0, "S": 1, "A": 2, "B": 3, "C": 4, "D": 5, "F": 6, "N/A": 7}
	var sorted_group_keys = grouped_results.keys()
	sorted_group_keys.sort_custom(func(a, b):
		var grade_a = a.split(" (")[0]
		var grade_b = a.split(" (")[0]
		var instr_a = a.split(" (")[1].split(")")[0] 
		var instr_b = b.split(" (")[1].split(")")[0]

		if grade_order.get(grade_a, 99) != grade_order.get(grade_b, 99):
			return grade_order.get(grade_a, 99) < grade_order.get(grade_b, 99)
		else:
			return instr_a < instr_b 
	)

	for group_key in sorted_group_keys:
		var group_info = grouped_results[group_key]
		var header_text = "%d %s" % [group_info.results.size(), group_key]
		var header_item_index = results_list.add_item(header_text)
		results_list.set_item_custom_bg_color(header_item_index, Color(0.2, 0.2, 0.2, 1.0)) 
		results_list.set_item_selectable(header_item_index, false) 

		for result in group_info.results:
			var original_datetime_str = result.get("date", "N/A")
			var formatted_date_str = "N/A"
			if original_datetime_str != "N/A":
				formatted_date_str = _format_iso_to_ddmmyyyy_hhmmss(original_datetime_str)

			var display_text = "%s - %d очков (%.0f%%) [%s] - %s" % [
				formatted_date_str,            
				result.get("score", 0),       
				result.get("accuracy", 0.0),   
				result.get("instrument", "unknown"), 
				result.get("grade", "N/A")    
			]

			var item_index = results_list.add_item(display_text)

			var saved_color_data = result.get("grade_color", null)
			var grade_item = str(result.get("grade", "N/A"))
			if grade_item == "SS":
				results_list.set_item_custom_fg_color(item_index, Color("#F2B35A"))
			elif saved_color_data and saved_color_data is Dictionary and saved_color_data.has("r"):
				var saved_grade_color = Color(
					saved_color_data.get("r", 1.0),
					saved_color_data.get("g", 1.0),
					saved_color_data.get("b", 1.0),
					saved_color_data.get("a", 1.0)
				)
				results_list.set_item_custom_fg_color(item_index, saved_grade_color)
			else:
				results_list.set_item_custom_fg_color(item_index, Color.WHITE)
	
	if results.size() == 0:
		results_list.add_item("Нет результатов для этой песни")

func load_results_for_song(song_path: String) -> Array:
	return results_service.load_results_for_song(song_path)

func save_result_for_song(song_path: String, instrument_type: String, score: int, accuracy: float, grade: String = "N/A", grade_color: Color = Color.WHITE, result_datetime: String = ""):
	results_service.save_result_for_song(song_path, instrument_type, score, accuracy, grade, grade_color, result_datetime)
	
	var song_key = song_path 
	var current_results = results_service.load_results_for_song(song_path)
	if current_results.size() >= 2 and not replay_achievement_sent_for_song.has(song_key):
		replay_achievement_sent_for_song[song_key] = true 
		if achievement_system:
			achievement_system.on_song_replayed(song_path) 
		else:
			printerr("ResultsManager.gd: achievement_system не установлен, невозможно проверить ачивку.")
	else:
		pass


func get_top_result_for_song(song_path: String) -> Dictionary:
	return results_service.get_top_result_for_song(song_path)

func _format_iso_to_ddmmyyyy_hhmmss(date_str: String) -> String:
	if date_str.length() >= 19 and date_str[4] == '-' and date_str[7] == '-' and date_str[10] == ' ' and date_str[13] == ':' and date_str[16] == ':':
		var year_v = date_str.substr(0, 4)
		var month_v = date_str.substr(5, 2)
		var day_v = date_str.substr(8, 2)
		var time_part_v = date_str.substr(11, 8)
		return "%s.%s.%s %s" % [day_v, month_v, year_v, time_part_v]
	return date_str

func clear_results_for_song(song_path: String) -> bool: 
	var ok = results_service.clear_results_for_song(song_path)
	if ok:
		var song_key = song_path
		if replay_achievement_sent_for_song.has(song_key):
			replay_achievement_sent_for_song.erase(song_key)
	return ok
