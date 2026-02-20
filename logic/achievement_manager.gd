# logic/achievement_manager.gd
class_name AchievementManager
extends RefCounted

const ACHIEVEMENTS_JSON_PATH := "res://data/achievements_data.json"
const SHOP_JSON_PATH := "res://data/shop_data.json"
const DEFAULT_ACHIEVEMENT_ICON_PATH := "res://assets/achievements/default.png"

const MONTHS_RU_SHORT = [
	"Янв", "Фев", "Мар", "Апр", "Мая", "Июн",
	"Июл", "Авг", "Сен", "Окт", "Ноя", "Дек"
]

var player_data_mgr = null 
var notification_mgr = null

var achievements: Array[Dictionary] = []
var genre_group_map: Dictionary = {}
var new_mastery_achievements: Array[Dictionary] = []
var _ach_by_id: Dictionary = {}

func _init(json_path: String = ACHIEVEMENTS_JSON_PATH):
	load_achievements(json_path)
	_load_genre_group_map()

func load_achievements(json_path: String = ACHIEVEMENTS_JSON_PATH):
	if not FileAccess.file_exists(json_path):
		achievements = []
		return

	var file = FileAccess.open(json_path, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()

		var json_parse_result = JSON.parse_string(json_text)
		if json_parse_result and json_parse_result.has("achievements"):
			if json_parse_result.achievements is Array:
				var loaded: Array[Dictionary] = []
				var seen_ids: Dictionary = {}
				for item in json_parse_result.achievements:
					if item is Dictionary:
						var ach_id = int(item.get("id", -1))
						var category = str(item.get("category", ""))
						var title = str(item.get("title", ""))
						var total_val = item.get("total", 0)
						if ach_id < 0 or category == "" or title == "":
							continue
						if seen_ids.has(ach_id):
							continue
						seen_ids[ach_id] = true
						if typeof(total_val) == TYPE_NIL:
							item.total = 1
						elif typeof(total_val) == TYPE_FLOAT or typeof(total_val) == TYPE_INT:
							item.total = max(1, int(total_val))
						else:
							item.total = 1
						var cur_val = item.get("current", 0)
						if typeof(cur_val) == TYPE_NIL:
							item.current = 0
						else:
							item.current = int(cur_val)
						item.unlocked = bool(item.get("unlocked", false))
						if not item.has("unlock_date"):
							item.unlock_date = null
						loaded.append(item)
					else:
						printerr("[AchievementManager] Найден элемент не типа Dictionary в списке достижений: ", item)
				achievements = loaded
				new_mastery_achievements.clear()
			else:
				printerr("[AchievementManager] Поле 'achievements' в JSON не является массивом.")
				achievements = []
		else:
			printerr("[AchievementManager] Ошибка парсинга JSON или отсутствие ключа 'achievements'.")
			achievements = []
	else:
		printerr("[AchievementManager] Не удалось открыть файл ", json_path)
		achievements = []
	_rebuild_index()

func save_achievements(json_path: String = ACHIEVEMENTS_JSON_PATH):
	var file = FileAccess.open(json_path, FileAccess.WRITE)
	if file:
		var json_to_save = {"achievements": achievements}
		var json_string = JSON.stringify(json_to_save, "\t")
		file.store_string(json_string)
		file.close()
	else:
		printerr("[AchievementManager] Не удалось сохранить файл ", json_path)

func _rebuild_index():
	_ach_by_id.clear()
	for a in achievements:
		_ach_by_id[int(a.get("id", -1))] = a

func get_achievement_by_id(achievement_id: int) -> Dictionary:
	return _ach_by_id.get(achievement_id, null)

func get_total_for(achievement_id: int) -> int:
	var a = get_achievement_by_id(achievement_id)
	if a == null:
		return 0
	return int(a.get("total", 0))

func _get_pdm(pdm_override = null):
	return pdm_override if pdm_override != null else player_data_mgr

func _update_ids(ids: Array, current: int):
	for ach_id in ids:
		var a = get_achievement_by_id(ach_id)
		if a != null:
			a.current = current
			if current >= int(a.get("total", 1)) and not a.get("unlocked", false):
				_perform_unlock(a)

func get_achievement_progress(achievement_id: int) -> Vector2i: 
	var a = get_achievement_by_id(achievement_id)
	if a != null:
		return Vector2i(int(a.get("current", 0)), int(a.get("total", 1)))
	return Vector2i(0, 1)

func update_progress(achievement_id: int, value: int):
	var a = get_achievement_by_id(achievement_id)
	if a != null:
		a.current = min(value, a.get("total", 1))
		if a.current >= a.get("total", 1):
			unlock_achievement_by_id(achievement_id)
		save_achievements()

func unlock_achievement_by_id(achievement_id: int):
	var a = get_achievement_by_id(achievement_id)
	if a != null and not a.get("unlocked", false):
		_perform_unlock(a)

func unlock_achievement(achievement_dict: Dictionary):
	if not achievement_dict.get("unlocked", false):
		_perform_unlock(achievement_dict)

func _perform_unlock(achievement: Dictionary):
	var was_unlocked = achievement.get("unlocked", false)
	if was_unlocked:
		return

	achievement.unlocked = true
	achievement.current = achievement.get("total", 1)

	var date = Time.get_date_dict_from_system()
	var time = Time.get_time_dict_from_system()

	var day = date.day
	var month = MONTHS_RU_SHORT[date.month - 1]
	var year = date.year
	var time_str = "%02d:%02d" % [time.hour, time.minute] 
	achievement.unlock_date = "%d %s %d, %s" % [day, month, year, time_str]

	save_achievements()

	if player_data_mgr:
		player_data_mgr.unlock_achievement(achievement.id)

	MusicManager.play_achievement_sound()  

	var category = achievement.get("category", "")
	if category == "mastery":
		if not new_mastery_achievements.has(achievement):
			new_mastery_achievements.append(achievement)
	elif notification_mgr: 
		notification_mgr.show_achievement_popup(achievement)
	else:
		printerr("Нет notification_mgr для показа ачивки: ", achievement.title)


func show_all_delayed_mastery_achievements():
	for achievement in new_mastery_achievements:
		if notification_mgr:
			notification_mgr.show_achievement_popup(achievement)
		else:
			printerr("notification_mgr не установлен для показа: ", achievement.title)

func clear_new_mastery_achievements():
	new_mastery_achievements.clear()

func reset_achievements():
	for a in achievements:
		a.unlocked = false
		a.current = 0
		a.unlock_date = null
	new_mastery_achievements.clear()
	save_achievements()

	if player_data_mgr:
		player_data_mgr.data["unlocked_achievement_ids"] = PackedInt32Array() 
		player_data_mgr._save() 

	print("[AchievementManager] Все достижения сброшены.")

func check_first_purchase():
	unlock_achievement_by_id(6)

func check_purchase_count(total_purchases: int):
	_update_ids([7, 8, 9, 10], total_purchases)
	save_achievements()

func check_currency_achievements(player_data_mgr_override = null):
	var pdm = _get_pdm(player_data_mgr_override)
	var total_earned = 0
	if pdm:
		total_earned = pdm.data.get("total_earned_currency", 0)
	else:
		printerr("[AchievementManager] check_currency_achievements: pdm is null!") 
		return
	_update_ids([11, 12, 13], total_earned)
	save_achievements()

func check_spent_currency_achievement(total_spent: int):
	_update_ids([14, 15, 16], total_spent)
	save_achievements()

func check_style_hunter_achievement(player_data_mgr_override = null):
	var pdm = _get_pdm(player_data_mgr_override)
	var categories: Dictionary = {}

	if pdm:
		var unlocked_items = pdm.get_items()

		var shop_file = FileAccess.open(SHOP_JSON_PATH, FileAccess.READ)
		if shop_file:
			var shop_json_text = shop_file.get_as_text()
			shop_file.close()

			var shop_json_parse_result = JSON.parse_string(shop_json_text)
			if shop_json_parse_result and shop_json_parse_result.has("items"):
				for item in shop_json_parse_result.items:
					var item_id = item.get("item_id", "")
					var price = int(item.get("price", 0))
					var category_ru = item.get("category", "")
					var category_internal = _map_category_ru_to_internal(category_ru)
					if category_internal == "":
						category_internal = category_ru.strip_edges()

					if not categories.has(category_internal):
						categories[category_internal] = []

					if price > 0 and unlocked_items.has(item_id):
						categories[category_internal].append(item_id)
			else:
				printerr("[AchievementManager] Ошибка парсинга shop_data.json или отсутствие ключа 'items'.")
		else:
			printerr("[AchievementManager] Не удалось открыть файл ", SHOP_JSON_PATH)

	var categories_with_items = 0
	for key in categories.keys():
		var items: Array = categories[key]
		if items.size() > 0:
			categories_with_items += 1
	var total_categories = categories.size()

	var a = get_achievement_by_id(17)
	if a != null and not a.get("unlocked", false):
		a.total = total_categories
		a.current = categories_with_items
		if categories_with_items == total_categories and total_categories > 0:
			_perform_unlock(a)

	save_achievements()

func _map_category_ru_to_internal(category_ru: String) -> String:
	match category_ru:
		"Кик": return "Kick"
		"Фоны": return "Backgrounds"
		"Обложки": return "Covers"
		"Подсветка линий": return "LaneHighlight"
		"Ноты": return "Notes"
		"Прочее": return "Misc"
		_:
			var fallback = category_ru.strip_edges()
			if fallback == "":
				printerr("Неизвестная категория из shop_data.json: ", category_ru)
			return fallback

func check_daily_login_achievements(player_data_mgr_override = null):
	var pdm = player_data_mgr_override if player_data_mgr_override != null else player_data_mgr
	if not pdm:
		printerr("[AchievementManager] Ошибка: player_data_mgr не передан в check_daily_login_achievements.")
		return

	var login_streak = pdm.get_login_streak()

	var login_ids = [19, 20, 21, 22]
	var progress_updated_but_not_unlocked = false

	for ach_id in login_ids:
		var achievement = get_achievement_by_id(ach_id)
		if achievement != null:
			var required_days = int(achievement.get("total", 1))
			var old_current = int(achievement.get("current", 0))
			achievement.current = login_streak
			if login_streak >= required_days and not achievement.get("unlocked", false):
				_perform_unlock(achievement)
			elif old_current != login_streak and not achievement.get("unlocked", false):
				progress_updated_but_not_unlocked = true

	if progress_updated_but_not_unlocked:
		save_achievements()

func check_event_achievements():
	var date = Time.get_date_dict_from_system()
	var day = date.day
	var month = date.month 

	if day == 30 and month == 9: 
		var a = get_achievement_by_id(47)
		if a != null and not a.get("unlocked", false):
			a.current = 1
			_perform_unlock(a)

	if (month == 1 and day >= 1 and day <= 10): 
		var b = get_achievement_by_id(48)
		if b != null and not b.get("unlocked", false):
			b.current = 1
			_perform_unlock(b)

	save_achievements()

func check_collection_completed_achievement(player_data_mgr_override = null):
	var pdm = _get_pdm(player_data_mgr_override)
	var shop_file = FileAccess.open(SHOP_JSON_PATH, FileAccess.READ)
	if not shop_file:
		printerr("[AchievementManager] Не удалось открыть файл ", SHOP_JSON_PATH)
		return

	var shop_json_text = shop_file.get_as_text()
	shop_file.close()

	var shop_json_parse_result = JSON.parse_string(shop_json_text)
	if not (shop_json_parse_result and shop_json_parse_result.has("items")):
		printerr("[AchievementManager] Ошибка парсинга shop_data.json или отсутствие ключа 'items'.")
		return

	var purchasable_items = []
	for item in shop_json_parse_result.items:
		if item.get("price", 0) > 0: 
			purchasable_items.append(item)

	var total_purchasable_items = purchasable_items.size() 
	var shop_item_ids = []
	var unlocked_item_ids = []
	var unlocked_purchasable_count = 0

	if pdm:
		unlocked_item_ids = pdm.get_items()  

		for item in purchasable_items: 
			shop_item_ids.append(item.get("item_id", ""))

	var missing_items_count = 0
	for shop_id in shop_item_ids:
		if not unlocked_item_ids.has(shop_id): 
			missing_items_count += 1
		else:
			unlocked_purchasable_count += 1

	var a = get_achievement_by_id(18)
	if a != null and not a.get("unlocked", false):
		a.total = total_purchasable_items
		a.current = unlocked_purchasable_count
		if missing_items_count == 0:
			_perform_unlock(a)
	
	save_achievements()

func check_first_level_achievement():
	unlock_achievement_by_id(24)

func check_perfect_accuracy_achievement(accuracy: float):
	if accuracy >= 100.0:
		unlock_achievement_by_id(25)

func check_levels_completed_achievement(total_levels_completed: int):
	var ids = [26, 27, 62, 63, 64]
	for ach_id in ids:
		var achievement = get_achievement_by_id(ach_id)
		if achievement != null:
			var required_count = int(achievement.get("total", 1))
			achievement.current = total_levels_completed
			if total_levels_completed >= required_count and not achievement.get("unlocked", false):
				_perform_unlock(achievement)
	save_achievements() 
	
func check_unique_levels_completed_achievements(player_data_mgr_override = null):
	var pdm = _get_pdm(player_data_mgr_override)
	if not pdm:
		return
	var unique_completed = pdm.get_unique_levels_completed()
	var ids = [59, 60, 61]
	var progress_updated = false
	for ach_id in ids:
		var achievement = get_achievement_by_id(ach_id)
		if achievement != null:
			var required = int(achievement.get("total", 1))
			var old = int(achievement.get("current", 0))
			achievement.current = unique_completed
			if unique_completed >= required and not achievement.get("unlocked", false):
				_perform_unlock(achievement)
			elif old != unique_completed and not achievement.get("unlocked", false):
				progress_updated = true
	if progress_updated:
		save_achievements()
	
func check_accuracy_95_achievements(player_data_mgr_override = null):
	var pdm = _get_pdm(player_data_mgr_override)
	if not pdm:
		return
	var grades: Dictionary = pdm.data.get("grades", {})
	var s_count = int(grades.get("S", 0))
	var ss_count = int(grades.get("SS", 0))
	var total_95 = s_count + ss_count
	for achievement in achievements:
		if achievement.id == 66:
			achievement.current = total_95
			if total_95 >= int(achievement.get("total", 15)) and not achievement.get("unlocked", false):
				_perform_unlock(achievement)
			break
	save_achievements()
	
func check_absolute_precision_achievements(player_data_mgr_override = null):
	var pdm = _get_pdm(player_data_mgr_override)
	if not pdm:
		return
	var ss_count = int(pdm.data.get("grades", {}).get("SS", 0))
	var achievement = get_achievement_by_id(65)
	if achievement != null:
		achievement.current = ss_count
		if ss_count >= int(achievement.get("total", 10)) and not achievement.get("unlocked", false):
			_perform_unlock(achievement)
	save_achievements()  	
	
func check_note_researcher_achievement():
	for achievement in achievements:
		if achievement.id == 23 and not achievement.get("unlocked", false):
			_perform_unlock(achievement)
			break 				
			
func reset_all_achievements_and_player_data(player_data_mgr_override = null):
	var pdm = player_data_mgr_override if player_data_mgr_override != null else player_data_mgr
	if not pdm:
		printerr("[AchievementManager] reset_all_achievements_and_player_ player_data_mgr не передан!")
		return

	reset_achievements()

	var current_currency = pdm.get_currency()

	pdm.data["unlocked_item_ids"] = PackedStringArray()

	pdm.data["active_items"] = pdm.DEFAULT_ACTIVE_ITEMS.duplicate(true)

	pdm.data["login_streak"] = 0
	pdm.data["last_login_date"] = ""
	
	pdm.data["currency"] = current_currency
	pdm.data["spent_currency"] = 0
	pdm.data["total_earned_currency"] = 0
	pdm.data["levels_completed"] = 0

	pdm.data["drum_levels_completed"] = 0
	pdm.data["drum_perfect_hits_in_level"] = 0
	pdm.data["total_drum_perfect_hits"] = 0

	pdm._save()
	

func check_rhythm_master_achievement(total_notes_hit: int):
	var a = get_achievement_by_id(28)
	if a != null and not a.get("unlocked", false):
		a.current = total_notes_hit
		if total_notes_hit >= 1000:
			_perform_unlock(a)

func check_drum_level_achievements(player_data_mgr_override = null, accuracy: float = 0.0, total_drum_levels: int = 0):
	var pdm = _get_pdm(player_data_mgr_override)
	if not pdm:
		printerr("[AchievementManager] check_drum_level_achievements: player_data_mgr не передан.")
		return

	if total_drum_levels >= 1: 
		for achievement in achievements:
			if achievement.id == 29 and not achievement.get("unlocked", false):
				_perform_unlock(achievement)
				break

	if accuracy >= 100.0:
		for achievement in achievements:
			if achievement.id == 30 and not achievement.get("unlocked", false):
				_perform_unlock(achievement)
				break

	var ids = [31, 67, 68, 69]
	for ach_id in ids:
		var achievement = get_achievement_by_id(ach_id)
		if achievement != null:
			var required = int(achievement.get("total", 1))
			achievement.current = total_drum_levels
			if total_drum_levels >= required and not achievement.get("unlocked", false):
				_perform_unlock(achievement)

	check_drum_storm_achievement(pdm)

func check_drum_storm_achievement(player_data_mgr_override = null):
	var pdm = player_data_mgr_override if player_data_mgr_override != null else player_data_mgr
	if not pdm:
		printerr("[AchievementManager] check_drum_storm_achievement: player_data_mgr не передан.")
		return
	for achievement in achievements:
		if achievement.id == 32 and not achievement.get("unlocked", false):
			var max_drum_combo = pdm.data.get("max_drum_combo_ever", 0)
			achievement.current = max_drum_combo
			if max_drum_combo >= 100: 
				_perform_unlock(achievement)
			break

func check_replay_level_achievement(track_completion_counts: Dictionary):
	var a = get_achievement_by_id(33)
	if not a or a.get("unlocked", false):
		return

	var replay_found = false
	for track_path in track_completion_counts:
		var count = track_completion_counts[track_path]
		if count > 1.0: 
			replay_found = true
			break 

	if replay_found:
		a.current = 1.0
		_perform_unlock(a)
		save_achievements() 

func check_playtime_achievements(player_data_mgr_override = null):
	var pdm = _get_pdm(player_data_mgr_override)
	if not pdm:
		return

	var total_play_time_formatted = pdm.data.get("total_play_time", "00:00")

	var time_parts = total_play_time_formatted.split(":")
	var total_play_time_seconds = 0

	if time_parts.size() == 2: 
		var hours = int(time_parts[0])
		var minutes = int(time_parts[1])
		total_play_time_seconds = (hours * 3600) + (minutes * 60)
	else:
		printerr("[AchievementManager] Неизвестный формат времени: ", total_play_time_formatted)
		return

	var total_play_time_hours = total_play_time_seconds / 3600.0
	var total_play_time_hours_rounded = roundf(total_play_time_hours * 100.0) / 100.0

	for achievement in achievements:
		if achievement.get("category", "") == "playtime":
			var achievement_id = achievement.id
			var required_hours = achievement.get("total", 0.0)

			achievement.current = total_play_time_hours_rounded

			if not achievement.get("unlocked", false):
				if total_play_time_hours_rounded >= required_hours:
					_perform_unlock(achievement)
				
func get_formatted_achievement_progress(achievement_id: int) -> Dictionary:
	for a in achievements:
		if a.id == achievement_id:
			var current_val = a.get("current", 0.0)
			var total_val = a.get("total", 1.0)
			var current_str = "%0.2f" % [current_val]
			var total_str = "%0.2f" % [total_val]
			return {"current": current_str, "total": total_str, "unlocked": a.get("unlocked", false)}

	return {"current": "0.00", "total": "1.00", "unlocked": false}

func check_score_achievements(player_data_mgr_override = null):
	var pdm = _get_pdm(player_data_mgr_override)
	if not pdm:
		return

	var total_score = pdm.get_total_score()
	var ids = [39, 40, 41, 42]
	for ach_id in ids:
		var achievement = get_achievement_by_id(ach_id)
		if achievement != null:
			var required_score = int(achievement.get("total", 0))
			achievement.current = total_score
			if total_score >= required_score and not achievement.get("unlocked", false):
				_perform_unlock(achievement)

	save_achievements()

func check_ss_achievements(player_data_mgr_override = null):
	var pdm = _get_pdm(player_data_mgr_override)
	if not pdm:
		return
	var ss_count = pdm.data.get("grades", {}).get("SS", 0)
	var ids = [43, 44, 45, 46]
	for ach_id in ids:
		var achievement = get_achievement_by_id(ach_id)
		if achievement != null:
			var required_ss = int(achievement.get("total", 0))
			achievement.current = ss_count
			if ss_count >= required_ss and not achievement.get("unlocked", false):
				_perform_unlock(achievement)
	save_achievements()

func check_daily_quests_completed_achievements(player_data_mgr_override = null):
	var pdm = _get_pdm(player_data_mgr_override)
	if not pdm:
		return
	var total_completed = pdm.get_daily_quests_completed_total()
	var ids = [1, 2, 3, 4, 5]
	var progress_updated = false
	for ach_id in ids:
		var achievement = get_achievement_by_id(ach_id)
		if achievement != null:
			var required = int(achievement.get("total", 0))
			var old = int(achievement.get("current", 0))
			achievement.current = total_completed
			if total_completed >= required and not achievement.get("unlocked", false):
				_perform_unlock(achievement)
			elif old != total_completed and not achievement.get("unlocked", false):
				progress_updated = true
	if progress_updated:
		save_achievements()

func check_level_achievements(player_level: int):
	_update_ids([49, 50, 51, 52, 53], player_level)

	save_achievements()
	
func _load_genre_group_map():
	var path = "res://data/genre_groups.json"
	if not FileAccess.file_exists(path):
		printerr("[AchievementManager] Файл genre_groups.json не найден!")
		return

	var file = FileAccess.open(path, FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		printerr("[AchievementManager] Ошибка: genre_groups.json должен содержать объект (Dictionary)")
		return

	genre_group_map.clear()
	for group_name in parsed:
		var genres = parsed[group_name]
		if genres is Array:
			for g in genres:
				if g is String:
					genre_group_map[g.to_lower()] = group_name
				else:
					printerr("[AchievementManager] Некорректный жанр в группе %s: %s" % [group_name, g])
		else:
			printerr("[AchievementManager] Группа %s должна содержать массив жанров" % group_name)

	
func _map_canonical_genre_to_group(canonical_genre: String) -> String:
	if canonical_genre == "":
		return ""
	return genre_group_map.get(canonical_genre.to_lower(), "")
	
func check_genre_achievements(track_stats_mgr = null):
	var tsm = track_stats_mgr if track_stats_mgr != null else TrackStatsManager
	if not tsm:
		printerr("[AchievementManager] TrackStatsManager недоступен")
		return

	var raw_counts = tsm.genre_play_counts  

	var group_counts = {
		"electronic": 0,
		"guitar_rock": 0,
		"rap": 0,
		"indie_alt": 0,
		"experimental": 0,
		"pop": 0,
		"classical_orchestral": 0,
		"jazz_soul": 0,
		"folk_world": 0,
		"industrial_noise": 0
	}

	for canonical_genre in raw_counts:
		var count = raw_counts[canonical_genre]
		var group = _map_canonical_genre_to_group(canonical_genre)
		if group != "" and group_counts.has(group):
			group_counts[group] += count

	var genre_achievements = {
		54: "electronic",
		55: "guitar_rock",
		56: "rap",
		57: "indie_alt",
		58: "experimental",
		70: "pop",
		71: "classical_orchestral",
		72: "jazz_soul",
		73: "folk_world",
		74: "industrial_noise"
	}

	for ach_id in genre_achievements:
		var group = genre_achievements[ach_id]
		var required = int(get_total_for(ach_id))
		var current = int(group_counts[group])

		var achievement = get_achievement_by_id(ach_id)
		if achievement != null:
			achievement.current = current
			if current >= required and not achievement.get("unlocked", false):
				_perform_unlock(achievement)

	save_achievements()
