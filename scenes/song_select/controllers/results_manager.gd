# scenes/song_select/results_manager.gd
class_name ResultsManager
extends Node

const GradeDisplay = preload("res://logic/ui/grade_display.gd")
const _SS = preload("res://logic/domain/library/song_select_strings.gd")
const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const _GoalDiff = preload("res://logic/domain/generation/generation_goal_difficulty.gd")

var achievement_system = null
var replay_achievement_sent_for_song: Dictionary = {}
var results_service: ResultsHistoryService


func _init() -> void:
	results_service = ResultsHistoryService.new()

func _format_goal_diff_label(pair: Dictionary) -> String:
	var goal := str(pair.get("goal", _GoalDiff.DEFAULT_GOAL))
	var difficulty := str(pair.get("difficulty", _GoalDiff.DEFAULT_DIFFICULTY))
	var goal_label := _SS._translate("GEN_GOAL_%s" % goal.to_upper())
	if _GoalDiff.sanitize_goal(goal) == "original":
		return goal_label
	var diff_label := _SS._translate(_GoalDiff.difficulty_label_key(goal, difficulty))
	return "%s · %s" % [goal_label, diff_label]


func _mode_label(mode_raw: String) -> String:
	var mode := mode_raw.strip_edges().to_lower()
	if mode == "":
		return "—"
	# New chart stems: arcade_dense → Arcade · Hard / Аркада · Сложная
	if _GoalDiff.is_chart_stem(mode):
		return _format_goal_diff_label(_GoalDiff.pair_from_stem(mode))
	# Single-token intents saved before full stems (original / groove / sparse / arcade)
	if mode in ["original", "groove", "sparse", "arcade"]:
		return _format_goal_diff_label(_GoalDiff.from_intent(mode))
	# Legacy modes (minimal / basic / …) already have GEN_MODE_* strings
	var mode_key := "GEN_MODE_%s" % mode.to_upper()
	var label := _SS._translate(mode_key)
	if label == mode_key:
		return mode_raw
	return label

func set_achievement_system(ach_sys):
	achievement_system = ach_sys


func _get_achievement_system():
	if achievement_system:
		return achievement_system
	var tree := Engine.get_main_loop()
	if tree is SceneTree:
		for child in tree.root.get_children():
			if child.has_method("get_achievement_system"):
				var ach = child.get_achievement_system()
				if ach:
					achievement_system = ach
					return ach
	return null

func _instrument_label(instrument_raw: String) -> String:
	var key := instrument_raw.strip_edges().to_lower()
	match key:
		"drums", "перкуссия":
			return _SS._translate("GEN_INST_DRUMS")
		"bass", "бас":
			return _SS._translate("GEN_INST_BASS")
		"fullmix", "микс":
			return _SS._translate("GEN_INST_MIX")
		"standard", "стандарт":
			return _SS._translate("GEN_INST_STANDARD")
		"":
			return "—"
		_:
			return instrument_raw

func _modifiers_abbr(result: Dictionary) -> String:
	var raw: Variant = result.get("modifiers", [])
	if not raw is Array:
		return ""
	var mods_array: Array = raw
	if mods_array.is_empty():
		return ""
	return _RunModifiers.format_abbr_list(mods_array, _translate_mod_abbr)


func _translate_mod_abbr(key: String) -> String:
	return _SS._translate(key)


func _format_result_line(result: Dictionary) -> String:
	var original_datetime_str = str(result.get("date", "N/A"))
	var formatted_date_str = "N/A"
	if original_datetime_str != "N/A":
		formatted_date_str = TimeUtils.format_iso_to_ddmmyyyy_hhmmss(original_datetime_str)
	var instrument_label := _instrument_label(str(result.get("instrument", "")))
	var mode_raw := str(result.get("mode", "")).strip_edges()
	var settings_label := instrument_label
	if mode_raw != "":
		settings_label = "%s, %s" % [instrument_label, _mode_label(mode_raw)]
	var mods_abbr := _modifiers_abbr(result)
	if mods_abbr != "":
		settings_label = "%s · %s" % [settings_label, mods_abbr]
	return _SS._translate("SONG_RESULTS_LINE") % [
		formatted_date_str,
		int(result.get("score", 0)),
		float(result.get("accuracy", 0.0)),
		settings_label,
		str(result.get("grade", "N/A")),
	]

func show_results_for_song(song_data: Dictionary, results_list: ItemList):
	results_list.clear()
	results_list.icon_mode = ItemList.ICON_MODE_TOP

	var results = results_service.load_results_for_song(song_data.get("path", ""))
	if not results is Array:
		results = []

	if results.size() > 0:
		var best_candidates: Array = results.duplicate()
		best_candidates.sort_custom(TimeUtils.sort_results_by_score)
		var top_result: Dictionary = best_candidates[0]
		var header_idx = results_list.add_item(_SS._translate("SONG_RESULTS_BEST"))
		results_list.set_item_custom_bg_color(header_idx, Color(0.25, 0.25, 0.15, 1.0))
		results_list.set_item_selectable(header_idx, false)
		var item_idx_top = results_list.add_item(_format_result_line(top_result))
		results_list.set_item_custom_fg_color(item_idx_top, GradeDisplay.color_from_saved_result(top_result))

		results.sort_custom(TimeUtils.sort_results_newest_first)
		var history_header_idx = results_list.add_item(_SS._translate("SONG_RESULTS_HISTORY"))
		results_list.set_item_custom_bg_color(history_header_idx, Color(0.2, 0.2, 0.2, 1.0))
		results_list.set_item_selectable(history_header_idx, false)

		for result in results:
			var item_index = results_list.add_item(_format_result_line(result))
			results_list.set_item_custom_fg_color(item_index, GradeDisplay.color_from_saved_result(result))
	else:
		results_list.add_item(_SS._translate("SONG_RESULTS_NONE"))

func load_results_for_song(song_path: String) -> Array:
	return results_service.load_results_for_song(song_path)


func load_medals_for_song(song_path: String) -> Array[String]:
	return results_service.load_medals_for_song(song_path)


func load_unseen_medals_for_song(song_path: String) -> Array[String]:
	return results_service.load_unseen_medals_for_song(song_path)


func mark_medals_seen_for_song(song_path: String) -> void:
	results_service.mark_medals_seen_for_song(song_path)

func save_result_for_song(song_path: String, instrument_type: String, score: int, accuracy: float, grade: String = "N/A", grade_color: Color = Color.WHITE, result_datetime: String = "", mode: String = "", ss_repeat: bool = false, medals_earned_this_run: Array = [], run_modifiers: Array = [], full_combo: bool = false, max_combo: int = 0, chart_rating: int = 0, title: String = "", artist: String = "", lanes: int = 4) -> Array:
	var earned_run := results_service.save_result_for_song(
		song_path, instrument_type, score, accuracy, grade, grade_color, result_datetime, mode,
		ss_repeat, medals_earned_this_run, run_modifiers, full_combo, max_combo, chart_rating,
		title, artist, lanes
	)
	var song_key = song_path
	var current_results = results_service.load_results_for_song(song_path)
	if current_results.size() >= 2 and not replay_achievement_sent_for_song.has(song_key):
		replay_achievement_sent_for_song[song_key] = true
		var ach_sys = _get_achievement_system()
		if ach_sys:
			ach_sys.on_song_replayed(song_path)
	return earned_run


func get_top_result_for_song(song_path: String) -> Dictionary:
	return results_service.get_top_result_for_song(song_path)


func clear_results_for_song(song_path: String) -> bool:
	var ok = results_service.clear_results_for_song(song_path)
	if ok:
		var song_key = song_path
		if replay_achievement_sent_for_song.has(song_key):
			replay_achievement_sent_for_song.erase(song_key)
	return ok
