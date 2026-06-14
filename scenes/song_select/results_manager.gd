# scenes/song_select/results_manager.gd
class_name ResultsManager
extends Node

const GradeDisplay = preload("res://logic/utils/grade_display.gd")

var achievement_system = null
var replay_achievement_sent_for_song: Dictionary = {}
var results_service: ResultsHistoryService = preload("res://logic/results_history_service.gd").new()

func _mode_label(mode_raw: String) -> String:
	var mode = mode_raw.to_lower()
	match mode:
		"minimal":
			return "Минимал"
		"basic":
			return "Базовый"
		"enhanced":
			return "Усложненный"
		"natural":
			return "Натуральный"
		"custom":
			return "Пользовательский"
		_:
			return mode_raw

func set_achievement_system(ach_sys):
	achievement_system = ach_sys

func _instrument_label(instrument_raw: String) -> String:
	var key := instrument_raw.strip_edges().to_lower()
	match key:
		"drums", "перкуссия":
			return "Перкуссия"
		"fullmix", "микс":
			return "Микс"
		"standard", "стандарт":
			return "Стандарт"
		"":
			return "—"
		_:
			return instrument_raw

func _format_result_line(result: Dictionary) -> String:
	var original_datetime_str = str(result.get("date", "N/A"))
	var formatted_date_str = "N/A"
	if original_datetime_str != "N/A":
		formatted_date_str = TimeUtils.format_iso_to_ddmmyyyy_hhmmss(original_datetime_str)
	var instrument_label := _instrument_label(str(result.get("instrument", "")))
	var mode_raw := str(result.get("mode", "")).strip_edges()
	var mode_text := _mode_label(mode_raw) if mode_raw != "" else "—"
	return "%s - %d очков (%.0f%%) [%s · %s] - %s" % [
		formatted_date_str,
		result.get("score", 0),
		result.get("accuracy", 0.0),
		instrument_label,
		mode_text,
		result.get("grade", "N/A")
	]

func show_results_for_song(song_data: Dictionary, results_list: ItemList):
	results_list.clear()

	var results = results_service.load_results_for_song(song_data.get("path", ""))
	if not results is Array:
		results = []

	if results.size() > 0:
		var best_candidates: Array = results.duplicate()
		best_candidates.sort_custom(TimeUtils.sort_results_by_score)
		var top_result: Dictionary = best_candidates[0]
		var header_idx = results_list.add_item("Лучший результат")
		results_list.set_item_custom_bg_color(header_idx, Color(0.25, 0.25, 0.15, 1.0))
		results_list.set_item_selectable(header_idx, false)
		var item_idx_top = results_list.add_item(_format_result_line(top_result))
		results_list.set_item_custom_fg_color(item_idx_top, GradeDisplay.color_from_saved_result(top_result))

		results.sort_custom(TimeUtils.sort_results_newest_first)
		var history_header_idx = results_list.add_item("История попыток (сначала новые)")
		results_list.set_item_custom_bg_color(history_header_idx, Color(0.2, 0.2, 0.2, 1.0))
		results_list.set_item_selectable(history_header_idx, false)

		for result in results:
			var item_index = results_list.add_item(_format_result_line(result))
			results_list.set_item_custom_fg_color(item_index, GradeDisplay.color_from_saved_result(result))
	else:
		results_list.add_item("Нет результатов для этой песни")

func load_results_for_song(song_path: String) -> Array:
	return results_service.load_results_for_song(song_path)

func save_result_for_song(song_path: String, instrument_type: String, score: int, accuracy: float, grade: String = "N/A", grade_color: Color = Color.WHITE, result_datetime: String = "", mode: String = "", ss_repeat: bool = false):
	results_service.save_result_for_song(song_path, instrument_type, score, accuracy, grade, grade_color, result_datetime, mode, ss_repeat)

	var song_key = song_path
	var current_results = results_service.load_results_for_song(song_path)
	if current_results.size() >= 2 and not replay_achievement_sent_for_song.has(song_key):
		replay_achievement_sent_for_song[song_key] = true
		if achievement_system:
			achievement_system.on_song_replayed(song_path)
		else:
			printerr("ResultsManager.gd: achievement_system не установлен, невозможно проверить ачивку.")


func get_top_result_for_song(song_path: String) -> Dictionary:
	return results_service.get_top_result_for_song(song_path)


func clear_results_for_song(song_path: String) -> bool:
	var ok = results_service.clear_results_for_song(song_path)
	if ok:
		var song_key = song_path
		if replay_achievement_sent_for_song.has(song_key):
			replay_achievement_sent_for_song.erase(song_key)
	return ok
