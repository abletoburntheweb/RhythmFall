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
				var loaded_achievements: Array[Dictionary] = []
				for item in json_parse_result.achievements:
					if item is Dictionary:
						loaded_achievements.append(item)
					else:
						printerr("[AchievementManager] Найден элемент не типа Dictionary в списке достижений: ", item)
				achievements = loaded_achievements
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

func save_achievements(json_path: String = ACHIEVEMENTS_JSON_PATH):
	var file = FileAccess.open(json_path, FileAccess.WRITE)
	if file:
		var json_to_save = {"achievements": achievements}
		var json_string = JSON.stringify(json_to_save, "\t")
		file.store_string(json_string)
		file.close()
	else:
		printerr("[AchievementManager] Не удалось сохранить файл ", json_path)

func get_achievement_progress(achievement_id: int) -> Vector2i: 
	for a in achievements:
		if a.id == achievement_id:
			return Vector2i(a.get("current", 0), a.get("total", 1))
	return Vector2i(0, 1)

func update_progress(achievement_id: int, value: int):
	for a in achievements:
		if a.id == achievement_id:
			a.current = min(value, a.get("total", 1))
			if a.current >= a.get("total", 1):
				unlock_achievement_by_id(achievement_id)
			save_achievements()
			return

func unlock_achievement_by_id(achievement_id: int):
	for a in achievements:
		if a.id == achievement_id and not a.get("unlocked", false):
			_perform_unlock(a)
			break 

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
	for a in achievements:
		if a.id == 6 and not a.get("unlocked", false):
			_perform_unlock(a) 
			break

func check_purchase_count(total_purchases: int):
	for achievement in achievements:
		var ach_id = int(achievement.get("id", 0))
		if ach_id in [7, 8, 9, 10]:
			var required_count = int(achievement.get("total", 0))
			achievement.current = total_purchases
			if total_purchases >= required_count and not achievement.get("unlocked", false):
				_perform_unlock(achievement)
	save_achievements()

func check_currency_achievements(player_data_mgr_override = null):
	var pdm = player_data_mgr_override if player_data_mgr_override != null else player_data_mgr
	var total_earned = 0
	if pdm:
		total_earned = pdm.data.get("total_earned_currency", 0)
	else:
		printerr("[AchievementManager] check_currency_achievements: pdm is null!") 
		return
	for achievement in achievements:
		var ach_id = int(achievement.get("id", 0))
		if ach_id in [11, 12, 13]:
			var required_amount = int(achievement.get("total", 0))
			achievement.current = total_earned
			if total_earned >= required_amount and not achievement.get("unlocked", false):
				_perform_unlock(achievement)
	save_achievements()

func check_spent_currency_achievement(total_spent: int):
	for achievement in achievements:
		var ach_id = int(achievement.get("id", 0))
		if ach_id in [14, 15, 16]:
			var required_amount = int(achievement.get("total", 0))
			achievement.current = total_spent
			if total_spent >= required_amount and not achievement.get("unlocked", false):
				_perform_unlock(achievement)
	save_achievements()

func check_style_hunter_achievement(player_data_mgr_override = null):
	var pdm = player_data_mgr_override if player_data_mgr_override != null else player_data_mgr
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

	for achievement in achievements:
		if achievement.id == 17 and not achievement.get("unlocked", false):
			if achievement.total != total_categories:
				achievement.total = total_categories
			achievement.current = categories_with_items

			if categories_with_items == total_categories and total_categories > 0:
				_perform_unlock(achievement)
			break

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

	var login_achievements = {19: 1, 20: 7, 21: 30, 22: 365}
	var progress_updated_but_not_unlocked = false

	for ach_id in login_achievements:
		var required_days = login_achievements[ach_id]
		for achievement in achievements:
			if achievement.id == ach_id:
				var old_current = achievement.current
				achievement.current = login_streak 

				if login_streak >= required_days and not achievement.get("unlocked", false):
					_perform_unlock(achievement)

				elif old_current != login_streak and not achievement.get("unlocked", false):
					progress_updated_but_not_unlocked = true
				break

	if progress_updated_but_not_unlocked:
		save_achievements()

func check_event_achievements():
	var date = Time.get_date_dict_from_system()
	var day = date.day
	var month = date.month 

	if day == 30 and month == 9: 
		for achievement in achievements:
			if achievement.id == 47 and not achievement.get("unlocked", false): 
				achievement.current = 1
				_perform_unlock(achievement)
				break

	if (month == 1 and day >= 1 and day <= 10): 
		for achievement in achievements:
			if achievement.id == 48 and not achievement.get("unlocked", false):
				achievement.current = 1
				_perform_unlock(achievement)
				break

	save_achievements()

func check_collection_completed_achievement(player_data_mgr_override = null):
	var pdm = player_data_mgr_override if player_data_mgr_override != null else player_data_mgr
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

	for achievement in achievements:
		if achievement.id == 18 and not achievement.get("unlocked", false):
			achievement.total = total_purchasable_items
			achievement.current = unlocked_purchasable_count

			if missing_items_count == 0:
				_perform_unlock(achievement)
			break
	
	save_achievements()

func check_first_level_achievement():
	for achievement in achievements:
		if achievement.id == 24 and not achievement.get("unlocked", false):
			_perform_unlock(achievement)
			break

func check_perfect_accuracy_achievement(accuracy: float):
	if accuracy >= 100.0:
		for achievement in achievements:
			if achievement.id == 25 and not achievement.get("unlocked", false):
				_perform_unlock(achievement)
				break

func check_levels_completed_achievement(total_levels_completed: int):
	var level_achievements = {26: 5, 27: 20, 62: 50, 63: 100, 64: 200}

	for ach_id in level_achievements:
		var required_count = level_achievements[ach_id]
		for achievement in achievements:
			if achievement.id == ach_id:
				achievement.current = total_levels_completed
				if total_levels_completed >= required_count and not achievement.get("unlocked", false):
					_perform_unlock(achievement)
				break
	save_achievements() 
	
func check_unique_levels_completed_achievements(player_data_mgr_override = null):
	var pdm = player_data_mgr_override if player_data_mgr_override != null else player_data_mgr
	if not pdm:
		return
	var unique_completed = pdm.get_unique_levels_completed()
	var unique_map = {59: 10, 60: 25, 61: 50}
	var progress_updated = false
	for ach_id in unique_map:
		var required = unique_map[ach_id]
		for achievement in achievements:
			if achievement.id == ach_id:
				var old = int(achievement.get("current", 0))
				achievement.current = unique_completed
				if unique_completed >= required and not achievement.get("unlocked", false):
					_perform_unlock(achievement)
				elif old != unique_completed and not achievement.get("unlocked", false):
					progress_updated = true
				break
	if progress_updated:
		save_achievements()
	
func check_accuracy_95_achievements(player_data_mgr_override = null):
	var pdm = player_data_mgr_override if player_data_mgr_override != null else player_data_mgr
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
	var pdm = player_data_mgr_override if player_data_mgr_override != null else player_data_mgr
	if not pdm:
		return
	var ss_count = int(pdm.data.get("grades", {}).get("SS", 0))
	for achievement in achievements:
		if achievement.id == 65:
			achievement.current = ss_count
			if ss_count >= int(achievement.get("total", 10)) and not achievement.get("unlocked", false):
				_perform_unlock(achievement)
			break
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
	var rhythm_master_id = 28
	for achievement in achievements:
		if achievement.id == rhythm_master_id and not achievement.get("unlocked", false):
			achievement.current = total_notes_hit 
			if total_notes_hit >= 1000:  
				_perform_unlock(achievement)
			break 

func check_drum_level_achievements(player_data_mgr_override = null, accuracy: float = 0.0, total_drum_levels: int = 0):
	var pdm = player_data_mgr_override if player_data_mgr_override != null else player_data_mgr
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

	var drum_levels_map = {31: 10, 67: 25, 68: 50, 69: 100}
	for ach_id in drum_levels_map:
		for achievement in achievements:
			if achievement.id == ach_id:
				achievement.current = total_drum_levels
				if total_drum_levels >= drum_levels_map[ach_id] and not achievement.get("unlocked", false):
					_perform_unlock(achievement)
				break

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
	var achievement_id = 33
	var achievement_to_check = null
	for a in achievements:
		if a.id == achievement_id:
			achievement_to_check = a
			break
	
	if not achievement_to_check or achievement_to_check.get("unlocked", false):
		return

	var replay_found = false
	for track_path in track_completion_counts:
		var count = track_completion_counts[track_path]
		if count > 1.0: 
			replay_found = true
			break 

	if replay_found:
		achievement_to_check.current = 1.0
		_perform_unlock(achievement_to_check)
		save_achievements() 

func check_playtime_achievements(player_data_mgr_override = null):
	var pdm = player_data_mgr_override if player_data_mgr_override != null else player_data_mgr
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
	var pdm = player_data_mgr_override if player_data_mgr_override != null else player_data_mgr
	if not pdm:
		return

	var total_score = pdm.get_total_score()
	var score_achievements = {39: 20000, 40: 75000, 41: 250000, 42: 750000}

	for ach_id in score_achievements:
		var required_score = score_achievements[ach_id]
		for achievement in achievements:
			if achievement.id == ach_id:
				achievement.current = total_score
				if total_score >= required_score and not achievement.get("unlocked", false):
					_perform_unlock(achievement)
				break

	save_achievements()

func check_ss_achievements(player_data_mgr_override = null):
	var pdm = player_data_mgr_override if player_data_mgr_override != null else player_data_mgr
	if not pdm:
		return
	var ss_count = pdm.data.get("grades", {}).get("SS", 0)
	var ss_achievements = {43: 5, 44: 10, 45: 25, 46: 50}
	for ach_id in ss_achievements:
		var required_ss = ss_achievements[ach_id]
		for achievement in achievements:
			if achievement.id == ach_id:
				achievement.current = ss_count
				if ss_count >= required_ss and not achievement.get("unlocked", false):
					_perform_unlock(achievement)
				break
	save_achievements()

func check_daily_quests_completed_achievements(player_data_mgr_override = null):
	var pdm = player_data_mgr_override if player_data_mgr_override != null else player_data_mgr
	if not pdm:
		return
	var total_completed = pdm.get_daily_quests_completed_total()
	var daily_map = {1: 5, 2: 20, 3: 50, 4: 100, 5: 250}
	var progress_updated = false
	for ach_id in daily_map:
		var required = daily_map[ach_id]
		for achievement in achievements:
			if achievement.id == ach_id:
				var old = int(achievement.get("current", 0))
				achievement.current = total_completed
				if total_completed >= required and not achievement.get("unlocked", false):
					_perform_unlock(achievement)
				elif old != total_completed and not achievement.get("unlocked", false):
					progress_updated = true
				break
	if progress_updated:
		save_achievements()

func check_level_achievements(player_level: int):
	var level_achievements = {49: 10, 50: 16, 51: 25, 52: 50, 53: 100}

	for ach_id in level_achievements:
		var required_level = level_achievements[ach_id]
		for achievement in achievements:
			if achievement.id == ach_id:
				achievement.current = player_level
				if player_level >= required_level and not achievement.get("unlocked", false):
					_perform_unlock(achievement)
				break

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
		54: ["electronic", 3],
		55: ["guitar_rock", 3],
		56: ["rap", 3],
		57: ["indie_alt", 3],
		58: ["experimental", 3],
		70: ["pop", 3],
		71: ["classical_orchestral", 3],
		72: ["jazz_soul", 3],
		73: ["folk_world", 3],
		74: ["industrial_noise", 3]
	}

	for ach_id in genre_achievements:
		var group = genre_achievements[ach_id][0]
		var required = genre_achievements[ach_id][1]
		var current = group_counts[group]

		for achievement in achievements:
			if achievement.id == ach_id:
				achievement.current = current
				if current >= required and not achievement.unlocked:
					_perform_unlock(achievement)
				break

	save_achievements()
