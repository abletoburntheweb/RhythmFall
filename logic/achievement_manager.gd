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
var music_mgr = null
var notification_mgr = null

var achievements: Array[Dictionary] = []

func _init(json_path: String = ACHIEVEMENTS_JSON_PATH):
	load_achievements(json_path)

func load_achievements(json_path: String = ACHIEVEMENTS_JSON_PATH):
	if not FileAccess.file_exists(json_path):
		print("[AchievementManager] Файл %s не найден. Загружен пустой список." % json_path)
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
	print("[AchievementManager] Достижение с id=%d не найдено" % achievement_id)
	return Vector2i(0, 1)

func update_progress(achievement_id: int, value: int):
	for a in achievements:
		if a.id == achievement_id:
			a.current = min(value, a.get("total", 1))
			if a.current >= a.get("total", 1):
				unlock_achievement_by_id(achievement_id)
			save_achievements()
			return
	print("[AchievementManager] Достижение с id=%d не найдено" % achievement_id)

func unlock_achievement_by_id(achievement_id: int):
	for a in achievements:
		if a.id == achievement_id and not a.get("unlocked", false):
			_perform_unlock(a)
			break 

func unlock_achievement(achievement_dict: Dictionary):
	if not achievement_dict.get("unlocked", false):
		_perform_unlock(achievement_dict)

func _perform_unlock(achievement: Dictionary):
	if achievement.get("unlocked", false):
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

	print("🏆 Достижение открыто: %s" % achievement.title)

	save_achievements()

	if player_data_mgr:
		player_data_mgr.unlock_achievement(achievement.id)

	if music_mgr:
		music_mgr.play_achievement_sound()

	var category = achievement.get("category", "")
	if notification_mgr and category != "gameplay":
		print("Unlocking achievement: ", achievement)
		notification_mgr.show_achievement_popup(achievement)
	else:
		print("🎮 Геймплейная ачивка отложена: ", achievement.title)
func show_all_delayed_gameplay_achievements():
	print("🎯 Показываем все отложенные геймплейные ачивки...")

	for achievement in achievements:
		if achievement.get("unlocked", false) and achievement.get("category", "") == "gameplay":
			print("🏆 Показываем геймплейную ачивку: ", achievement.title)
			if notification_mgr:
				notification_mgr.show_achievement_popup(achievement)
				
func reset_achievements():
	for a in achievements:
		a.unlocked = false
		a.current = 0
		a.unlock_date = null
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
	var purchase_achievements = {7: 3, 8: 5, 9: 10, 10: 15}

	for ach_id in purchase_achievements:
		var required_count = purchase_achievements[ach_id]
		for achievement in achievements:
			if achievement.id == ach_id:
				achievement.current = total_purchases
				if total_purchases >= required_count and not achievement.get("unlocked", false):
					_perform_unlock(achievement)
				break

func check_currency_achievements(player_data_mgr_override = null):
	var pdm = player_data_mgr_override if player_data_mgr_override != null else player_data_mgr
	var total_earned = 0
	if pdm:
		total_earned = pdm.data.get("total_earned_currency", 0)
		print("[AchievementManager] check_currency_achievements: total_earned = ", total_earned) 
	else:
		print("[AchievementManager] check_currency_achievements: pdm is null!") 
		return

	var currency_achievements = {11: 500, 12: 1000, 13: 2500} 

	for ach_id in currency_achievements:
		var required_amount = currency_achievements[ach_id]
		print("[AchievementManager] Проверяем ачивку ", ach_id, ", требуется: ", required_amount, ", есть: ", total_earned) 
		for achievement in achievements:
			if achievement.id == ach_id:
				print("[AchievementManager] Нашли ачивку ", ach_id, ", текущий прогресс: ", achievement.current)
				achievement.current = total_earned
				print("[AchievementManager] Установлен прогресс ачивки ", ach_id, " в ", total_earned) 
				if total_earned >= required_amount and not achievement.get("unlocked", false):
					print("[AchievementManager] Разблокируем ачивку ", ach_id, "!") 
					_perform_unlock(achievement)
				break

	save_achievements()

func check_spent_currency_achievement(total_spent: int):
	var spent_achievements = {14: 500, 15: 1000, 16: 2500}

	for ach_id in spent_achievements:
		var required_amount = spent_achievements[ach_id]
		for achievement in achievements:
			if achievement.id == ach_id:
				achievement.current = total_spent
				if total_spent >= required_amount and not achievement.get("unlocked", false):
					_perform_unlock(achievement)
				break 

func check_style_hunter_achievement(player_data_mgr_override = null):
	var pdm = player_data_mgr_override if player_data_mgr_override != null else player_data_mgr
	var categories = {
		"Kick": [],
		"Snare": [],
		"Backgrounds": [],
		"Covers": [],
		"Misc": []
	}

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
					var category_ru = item.get("category", "")
					var category = _map_category_ru_to_internal(category_ru)

					if unlocked_items.has(item_id) and category: 
						if categories.has(category):
							categories[category].append(item_id)
			else:
				printerr("[AchievementManager] Ошибка парсинга shop_data.json или отсутствие ключа 'items'.")
		else:
			printerr("[AchievementManager] Не удалось открыть файл ", SHOP_JSON_PATH)

	var categories_with_items = 0
	for items in categories.values():
		if items.size() > 0:
			categories_with_items += 1
	var total_categories = categories.size()

	for achievement in achievements:
		if achievement.id == 17 and not achievement.get("unlocked", false):
			if achievement.total != total_categories: 
				achievement.total = total_categories
			achievement.current = categories_with_items

			if categories_with_items == total_categories:
				_perform_unlock(achievement)
			break 

	save_achievements()

func _map_category_ru_to_internal(category_ru: String) -> String:
	match category_ru:
		"Кик": return "Kick"
		"Снейр": return "Snare"
		"Фоны": return "Backgrounds"
		"Обложки": return "Covers"
		"Прочее": return "Misc"
		_:
			printerr("Неизвестная категория из shop_data.json: ", category_ru)
			return ""

func check_daily_login_achievements(player_data_mgr_override = null):
	var pdm = player_data_mgr_override if player_data_mgr_override != null else player_data_mgr
	if not pdm:
		print("[AchievementManager] Ошибка: player_data_mgr не передан в check_daily_login_achievements.")
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
	var total_unlocked_items = 0
	var shop_item_ids = []
	var unlocked_item_ids = []

	if pdm:
		unlocked_item_ids = pdm.get_items()  
		total_unlocked_items = unlocked_item_ids.size()

		for item in purchasable_items:
			shop_item_ids.append(item.get("item_id", ""))

	var missing_items_count = 0
	for shop_id in shop_item_ids:
		if not unlocked_item_ids.has(shop_id): 
			missing_items_count += 1

	for achievement in achievements:
		if achievement.id == 18 and not achievement.get("unlocked", false):
			achievement.total = total_purchasable_items
			achievement.current = total_unlocked_items

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
	print("[AchievementManager] Проверка уровней: total_levels_completed = ", total_levels_completed)
	var level_achievements = {26: 5, 27: 20}

	for ach_id in level_achievements:
		var required_count = level_achievements[ach_id]
		print("[AchievementManager] Проверяем ачивку ", ach_id, ", требуется: ", required_count, ", есть: ", total_levels_completed)
		for achievement in achievements:
			if achievement.id == ach_id:
				print("[AchievementManager] Нашли ачивку ", ach_id, ", текущий прогресс: ", achievement.current)
				achievement.current = total_levels_completed
				print("[AchievementManager] Установлен прогресс ачивки ", ach_id, " в ", total_levels_completed)
				if total_levels_completed >= required_count and not achievement.get("unlocked", false):
					print("[AchievementManager] Разблокируем ачивку ", ach_id, "!")
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

	pdm.data["total_perfect_hits"] = 0
	pdm.data["drum_levels_completed"] = 0
	pdm.data["drum_perfect_hits_in_level"] = 0
	pdm.data["current_snare_streak"] = 0
	pdm.data["total_drum_perfect_hits"] = 0

	pdm._save()

	print("[AchievementManager] Прогресс достижений и данных игрока (кроме валюты) сброшен.")

func check_rhythm_master_achievement(total_perfect_hits: int):
	var rhythm_master_id = 28
	for achievement in achievements:
		if achievement.id == rhythm_master_id and not achievement.get("unlocked", false):
			achievement.current = total_perfect_hits 
			if total_perfect_hits >= 1000:
				_perform_unlock(achievement)
			break 
			
func check_drum_level_achievements(player_data_mgr_override = null, accuracy: float = 0.0, total_drum_levels: int = 0):
	var pdm = player_data_mgr_override if player_data_mgr_override != null else player_data_mgr
	if not pdm:
		print("[AchievementManager] check_drum_level_achievements: player_data_mgr не передан.")
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

	for achievement in achievements:
		if achievement.id == 31 and not achievement.get("unlocked", false):
			achievement.current = total_drum_levels
			if total_drum_levels >= 10:
				_perform_unlock(achievement)
			break

func check_drum_storm_achievement(player_data_mgr_override = null, current_drum_streak: int = 0):
	var pdm = player_data_mgr_override if player_data_mgr_override != null else player_data_mgr
	if not pdm:
		print("[AchievementManager] check_drum_storm_achievement: player_data_mgr не передан.")
		return

	for achievement in achievements:
		if achievement.id == 32 and not achievement.get("unlocked", false):
			achievement.current = current_drum_streak
			if current_drum_streak >= 10:
				_perform_unlock(achievement)
			break

func check_replay_level_achievement(song_path: String):
	var achievement_id = 33
	var achievement_to_check = null
	for a in achievements:
		if a.id == achievement_id:
			achievement_to_check = a
			break
	
	if not achievement_to_check:
		print("[AchievementManager] Ачивка с id=%d не найдена для проверки 'Музыкальная память'." % achievement_id)
		return
	
	if achievement_to_check.get("unlocked", false):
		return 
	
	unlock_achievement_by_id(achievement_id)
	print("AchievementManager: Ачивка 'Музыкальная память' разблокирована для песни %s." % song_path)
