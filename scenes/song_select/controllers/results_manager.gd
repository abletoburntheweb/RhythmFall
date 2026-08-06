# scenes/song_select/controllers/results_manager.gd
class_name ResultsManager
extends Node

const GradeDisplay = preload("res://logic/ui/grade_display.gd")
const _SS = preload("res://logic/domain/library/song_select_strings.gd")
const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const _GenPresetUi = preload("res://logic/ui/generation_preset_ui.gd")

var achievement_system = null
var replay_achievement_sent_for_song: Dictionary = {}
var results_service: ResultsHistoryService


func _init() -> void:
	results_service = ResultsHistoryService.new()


func _mode_label(mode_raw: String) -> String:
	var label := _SS.format_chart_mode_label(mode_raw)
	return label if label != "" else "—"


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


func instrument_id_from_raw(instrument_raw: String) -> String:
	var key := instrument_raw.strip_edges().to_lower()
	match key:
		"drums", "перкуссия":
			return "drums"
		"bass", "бас":
			return "bass"
		"fullmix", "микс":
			return "fullmix"
		"guitar", "гитара":
			return "guitar"
		"keys", "vocals":
			return key
		"standard", "стандарт":
			# Legacy label before instrument split — no dedicated icon.
			return ""
		"":
			return ""
		_:
			if key in _GenPresetUi.INSTRUMENT_ICONS:
				return key
			return ""


func _instrument_label(instrument_raw: String) -> String:
	var id := instrument_id_from_raw(instrument_raw)
	if id != "":
		return _GenPresetUi.localized_instrument(id)
	if instrument_raw.strip_edges() == "":
		return "—"
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
	if original_datetime_str != "N/A" and original_datetime_str.strip_edges() != "":
		formatted_date_str = TimeUtils.format_session_datetime_localized(original_datetime_str)
		if formatted_date_str == "":
			formatted_date_str = TimeUtils.format_iso_to_ddmmyyyy_hhmmss(original_datetime_str)
	var instrument_label := _instrument_label(str(result.get("instrument", "")))
	var mode_raw := str(result.get("mode", "")).strip_edges()
	var settings_label := instrument_label
	if mode_raw != "":
		settings_label = "%s, %s" % [instrument_label, _mode_label(mode_raw)]
	var mods_abbr := _modifiers_abbr(result)
	if mods_abbr != "":
		settings_label = "%s · %s" % [settings_label, mods_abbr]
	var max_combo := int(result.get("max_combo", 0))
	if max_combo > 0:
		return _SS._translate("SONG_RESULTS_LINE_COMBO") % [
			formatted_date_str,
			int(result.get("score", 0)),
			float(result.get("accuracy", 0.0)),
			max_combo,
			settings_label,
			str(result.get("grade", "N/A")),
		]
	return _SS._translate("SONG_RESULTS_LINE") % [
		formatted_date_str,
		int(result.get("score", 0)),
		float(result.get("accuracy", 0.0)),
		settings_label,
		str(result.get("grade", "N/A")),
	]


func _instrument_icon_for_result(result: Dictionary) -> Texture2D:
	var inst_id := instrument_id_from_raw(str(result.get("instrument", "")))
	if inst_id == "":
		return null
	var icon_file := str(_GenPresetUi.INSTRUMENT_ICONS.get(inst_id, ""))
	if icon_file == "":
		return null
	var tint: Color = _GenPresetUi.INSTRUMENT_ICON_COLORS.get(inst_id, Color(0.38, 0.78, 0.74, 1.0))
	return UiIconHelper.load_tinted_icon(icon_file, tint, 64)


func top_modifier_ids(results: Array, limit: int = 3) -> Array:
	var counts: Dictionary = {}
	for item in results:
		if not item is Dictionary:
			continue
		var raw: Variant = item.get("modifiers", [])
		if not raw is Array:
			continue
		for mod_id in _RunModifiers.sanitize(raw):
			var key := str(mod_id)
			counts[key] = int(counts.get(key, 0)) + 1
	if counts.is_empty():
		return []
	var pairs: Array = []
	for key in counts.keys():
		pairs.append({"id": key, "n": int(counts[key])})
	pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["n"]) == int(b["n"]):
			return str(a["id"]) < str(b["id"])
		return int(a["n"]) > int(b["n"])
	)
	var out: Array = []
	for i in range(mini(limit, pairs.size())):
		out.append(str(pairs[i]["id"]))
	return out


func _favorite_instrument_id(results: Array) -> String:
	var counts: Dictionary = {}
	for item in results:
		if not item is Dictionary:
			continue
		var id := instrument_id_from_raw(str(item.get("instrument", "")))
		if id == "":
			continue
		counts[id] = int(counts.get(id, 0)) + 1
	if counts.is_empty():
		return ""
	var best_id := ""
	var best_n := -1
	for id in counts.keys():
		var n := int(counts[id])
		if n > best_n:
			best_n = n
			best_id = str(id)
	return best_id


func _favorite_mode_raw(results: Array) -> String:
	var counts: Dictionary = {}
	for item in results:
		if not item is Dictionary:
			continue
		var mode := str(item.get("mode", "")).strip_edges()
		if mode == "":
			continue
		counts[mode] = int(counts.get(mode, 0)) + 1
	if counts.is_empty():
		return ""
	var best_mode := ""
	var best_n := -1
	for mode in counts.keys():
		var n := int(counts[mode])
		if n > best_n:
			best_n = n
			best_mode = str(mode)
	return best_mode


func _average_accuracy(results: Array) -> float:
	var sum := 0.0
	var n := 0
	for item in results:
		if not item is Dictionary:
			continue
		if not item.has("accuracy"):
			continue
		sum += float(item.get("accuracy", 0.0))
		n += 1
	if n <= 0:
		return -1.0
	return sum / float(n)


func show_results_for_song(song_data: Dictionary, results_view: SongResultsView):
	if results_view == null:
		return

	var song_path := str(song_data.get("path", ""))
	var results = results_service.load_results_for_song(song_path)
	if not results is Array:
		results = []

	var first_played := results_service.ensure_first_played_migrated(song_path)
	var play_count := 0
	if TrackStatsManager:
		play_count = TrackStatsManager.get_completion_count(song_path)
	if play_count <= 0:
		play_count = results.size()

	if results.is_empty():
		results_view.show_empty()
		return

	var best_candidates: Array = results.duplicate()
	best_candidates.sort_custom(TimeUtils.sort_results_by_score)
	var top_result: Dictionary = best_candidates[0]

	var history: Array = results.duplicate()
	history.sort_custom(TimeUtils.sort_results_newest_first)

	var best_rr := 0
	if ProfileMilestonesManager:
		best_rr = ProfileMilestonesManager.get_best_rr_for_song(song_path)
	if best_rr <= 0:
		best_rr = int(top_result.get("run_rr", 0))
	if int(top_result.get("run_rr", 0)) <= 0 and best_rr > 0:
		top_result = top_result.duplicate()
		top_result["run_rr"] = best_rr

	var fc_count := 0
	var ss_count := 0
	for item in results:
		if not item is Dictionary:
			continue
		if bool(item.get("full_combo", false)):
			fc_count += 1
		if str(item.get("grade", "")).to_upper() == "SS":
			ss_count += 1
	if TrackStatsManager:
		ss_count = maxi(ss_count, TrackStatsManager.get_ss_count(song_path))

	var medals := results_service.load_medals_for_song(song_path)
	var play_seconds := 0
	if TrackStatsManager:
		play_seconds = TrackStatsManager.get_total_play_seconds(song_path)
	# Fallback: sum duration_sec from surviving result rows (partial, but real).
	if play_seconds <= 0:
		for item in results:
			if item is Dictionary:
				play_seconds += maxi(0, int(item.get("duration_sec", 0)))

	var last_played := ""
	if not history.is_empty() and history[0] is Dictionary:
		last_played = str(history[0].get("date", ""))
	var fav_inst_id := _favorite_instrument_id(results)
	var fav_inst_label := ""
	if fav_inst_id != "":
		fav_inst_label = _GenPresetUi.localized_instrument(fav_inst_id)

	var avg_accuracy := _average_accuracy(results)
	var fav_mode_raw := _favorite_mode_raw(results)
	var fav_style_label := ""
	if fav_mode_raw != "":
		fav_style_label = _SS.format_chart_mode_label(fav_mode_raw)

	var passport_data := {
		"song_path": song_path,
		"song_title": str(song_data.get("title", "")).strip_edges(),
		"song_artist": str(song_data.get("artist", "")).strip_edges(),
		"first_played": first_played,
		"play_count": play_count,
		"play_seconds": play_seconds,
		"best_rr": best_rr,
		"avg_accuracy": avg_accuracy,
		"fc_count": fc_count,
		"ss_count": ss_count,
		"medals_earned": medals.size(),
		"medals_total": 8,
		"medals_unlocked": medals,
		"top_mods": top_modifier_ids(results, 3),
		"last_played": last_played,
		"favorite_instrument": fav_inst_label,
		"favorite_instrument_id": fav_inst_id,
		"favorite_style": fav_style_label,
		"favorite_mode": fav_mode_raw,
	}

	var footer := ""
	if play_count > history.size():
		footer = _SS._translate("SONG_MUSEUM_SHOWN_OF") % [history.size(), play_count]
	else:
		footer = _SS._translate("SONG_MUSEUM_SHOWN_ALL") % history.size()

	results_view.show_filled(
		passport_data,
		top_result,
		history,
		func(row: SongResultRow, result: Dictionary, is_best_card: bool) -> void:
			_bind_result_row(row, result, is_best_card),
		footer
	)


func _bind_result_row(
	row: SongResultRow,
	result: Dictionary,
	_is_best_card: bool
) -> void:
	var inst_raw := str(result.get("instrument", ""))
	var inst_id := instrument_id_from_raw(inst_raw)
	var mode_raw := str(result.get("mode", "")).strip_edges()
	row.apply_result(
		result,
		inst_id,
		_instrument_label(inst_raw),
		_mode_label(mode_raw) if mode_raw != "" else ""
	)


func load_results_for_song(song_path: String) -> Array:
	return results_service.load_results_for_song(song_path)


func load_medals_for_song(song_path: String) -> Array[String]:
	return results_service.load_medals_for_song(song_path)


func load_unseen_medals_for_song(song_path: String) -> Array[String]:
	return results_service.load_unseen_medals_for_song(song_path)


func mark_medals_seen_for_song(song_path: String) -> void:
	results_service.mark_medals_seen_for_song(song_path)


func save_result_for_song(song_path: String, instrument_type: String, score: int, accuracy: float, grade: String = "N/A", grade_color: Color = Color.WHITE, result_datetime: String = "", mode: String = "", ss_repeat: bool = false, medals_earned_this_run: Array = [], run_modifiers: Array = [], full_combo: bool = false, max_combo: int = 0, chart_rating: int = 0, title: String = "", artist: String = "", lanes: int = 4, run_rr: int = 0, duration_sec: int = 0) -> Array:
	var earned_run := results_service.save_result_for_song(
		song_path, instrument_type, score, accuracy, grade, grade_color, result_datetime, mode,
		ss_repeat, medals_earned_this_run, run_modifiers, full_combo, max_combo, chart_rating,
		title, artist, lanes, run_rr, duration_sec
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
