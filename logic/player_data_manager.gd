# logic/player_data_manager.gd
class_name PlayerDataManager 
extends RefCounted

const PLAYER_DATA_PATH = "user://player_data.json" 
const BEST_GRADES_PATH = "user://best_grades.json" 
const TRACK_STATS_PATH = "user://track_stats.json"

const DEFAULT_ACTIVE_ITEMS = {
	"Kick": "kick_default",
	"Snare": "snare_default",
	"Backgrounds": "background_default",
	"Covers": "covers_default",
	"LaneHighlight": "lane_highlight_default",
	"Misc": null 
}

var data: Dictionary = {
	"currency": 0,
	"unlocked_item_ids": PackedStringArray(),  
	"active_items": DEFAULT_ACTIVE_ITEMS.duplicate(true), 
	"unlocked_achievement_ids": PackedInt32Array(),  
	"spent_currency": 0,
	"total_earned_currency": 0,
	"last_login_date": "",
	"login_streak": 0,
	"levels_completed": 0,
	"drum_levels_completed": 0,      
	"total_drum_perfect_hits": 0,   
	"total_notes_hit": 0,
	"total_notes_missed": 0,
	"max_combo_ever": 0,             
	"max_drum_combo_ever": 0,       
	"total_drum_hits": 0,           
	"total_drum_misses": 0,
	"total_play_time": "00:00", 
	"total_score_ever": 0,           
	"total_drum_score_ever": 0,     
	"grades": {
		"SS": 0,
		"S": 0,
		"A": 0,
		"B": 0,
		"C": 0,
		"D": 0,
		"F": 0
	},
	"total_xp": 0,
	"current_level": 1,
	"xp_for_next_level": 100,
	"favorite_track": "",
	"favorite_track_play_count": 0
}

signal total_play_time_changed(new_time_formatted: String)
signal level_changed(new_level: int, new_xp: int, xp_for_next_level: int)  

var _total_play_time_seconds: int = 0

var achievement_manager = null
var game_engine_reference = null
var delayed_achievements: Array[Dictionary] = []

var track_stats_manager = null

func _init():
	_load()
	_total_play_time_seconds = _play_time_string_to_seconds(data.get("total_play_time", "00:00"))

	var track_counts = data.get("track_completion_counts", {})
	var max_count = 0
	var max_track = ""
	for track_path in track_counts:
		var count = track_counts[track_path]
		if count > max_count:
			max_count = count
			max_track = track_path
	data["favorite_track"] = max_track
	data["favorite_track_play_count"] = max_count

	var default_items = [
		"kick_default",
		"snare_default", 
		"covers_default",
		"lane_highlight_default"
	]
	var items_changed = false
	for item_id in default_items:
		if not data["unlocked_item_ids"].has(item_id):   
			data["unlocked_item_ids"].append(item_id)
			items_changed = true
	if items_changed:
		_save() 

func _load():
	var file_access = FileAccess.open(PLAYER_DATA_PATH, FileAccess.READ)
	if file_access:
		var json_text = file_access.get_as_text()
		file_access.close()
		var json_result = JSON.parse_string(json_text)
		if json_result is Dictionary:
			var loaded_currency = int(json_result.get("currency", 0))
			var loaded_unlocked_item_ids = json_result.get("unlocked_item_ids", PackedStringArray())
			if loaded_unlocked_item_ids is Array:
				loaded_unlocked_item_ids = PackedStringArray(loaded_unlocked_item_ids)
			var loaded_active_items = json_result.get("active_items", {})
			var loaded_last_login = json_result.get("last_login_date", "")
			var loaded_login_streak = int(json_result.get("login_streak", 0))
			var loaded_unlocked_achievement_ids = json_result.get("unlocked_achievement_ids", PackedInt32Array())
			if loaded_unlocked_achievement_ids is Array:
				loaded_unlocked_achievement_ids = PackedInt32Array(loaded_unlocked_achievement_ids)
			var loaded_spent_currency = int(json_result.get("spent_currency", 0))
			var loaded_total_earned_currency = int(json_result.get("total_earned_currency", 0))
			var loaded_levels_completed = int(json_result.get("levels_completed", 0))
			var loaded_drum_levels_completed = int(json_result.get("drum_levels_completed", 0))
			var loaded_total_drum_perfect_hits = int(json_result.get("total_drum_perfect_hits", 0))
			var loaded_total_notes_hit = int(json_result.get("total_notes_hit", 0)) 
			var loaded_total_notes_missed = int(json_result.get("total_notes_missed", 0))
			var loaded_max_combo_ever = int(json_result.get("max_combo_ever", 0))
			var loaded_max_drum_combo_ever = int(json_result.get("max_drum_combo_ever", 0))
			var loaded_total_drum_hits = int(json_result.get("total_drum_hits", 0))
			var loaded_total_drum_misses = int(json_result.get("total_drum_misses", 0))
			var loaded_total_play_time = json_result.get("total_play_time", "00:00") 
			var loaded_total_score_ever = int(json_result.get("total_score_ever", 0))
			var loaded_total_drum_score_ever = int(json_result.get("total_drum_score_ever", 0))
			var loaded_total_xp = int(json_result.get("total_xp", 0))
			var loaded_current_level = int(json_result.get("current_level", 1))
			var loaded_xp_for_next_level = int(json_result.get("xp_for_next_level", 100))

			var loaded_favorite_track = json_result.get("favorite_track", "")
			var loaded_favorite_track_play_count = int(json_result.get("favorite_track_play_count", 0))

			var loaded_grades = json_result.get("grades", {
				"SS": 0,
				"S": 0,
				"A": 0,
				"B": 0,
				"C": 0,
				"D": 0,
				"F": 0
			})

			print("PlayerDataManager.gd: Загружено currency: ", loaded_currency)
			print("PlayerDataManager.gd: Загружено unlocked_item_ids: ", loaded_unlocked_item_ids)
			print("PlayerDataManager.gd: Загружено active_items: ", loaded_active_items)
			
			data["currency"] = loaded_currency
			data["unlocked_item_ids"] = loaded_unlocked_item_ids 
			data["unlocked_achievement_ids"] = loaded_unlocked_achievement_ids 
			data["spent_currency"] = loaded_spent_currency
			data["total_earned_currency"] = loaded_total_earned_currency
			data["levels_completed"] = loaded_levels_completed
			data["drum_levels_completed"] = loaded_drum_levels_completed
			data["total_drum_perfect_hits"] = loaded_total_drum_perfect_hits
			data["total_notes_hit"] = loaded_total_notes_hit
			data["total_notes_missed"] = loaded_total_notes_missed
			data["max_combo_ever"] = loaded_max_combo_ever
			data["max_drum_combo_ever"] = loaded_max_drum_combo_ever
			data["total_drum_hits"] = loaded_total_drum_hits
			data["total_drum_misses"] = loaded_total_drum_misses
			data["total_play_time"] = loaded_total_play_time 
			data["total_score_ever"] = loaded_total_score_ever
			data["total_drum_score_ever"] = loaded_total_drum_score_ever
			data["grades"] = loaded_grades
			data["total_xp"] = loaded_total_xp
			data["current_level"] = loaded_current_level
			data["xp_for_next_level"] = loaded_xp_for_next_level

			data["favorite_track"] = loaded_favorite_track
			data["favorite_track_play_count"] = loaded_favorite_track_play_count

			data["last_login_date"] = loaded_last_login
			data["login_streak"] = loaded_login_streak 
			
			var loaded_active_items_dict = loaded_active_items.duplicate(true)
			for category in DEFAULT_ACTIVE_ITEMS:
				var loaded_value = loaded_active_items_dict.get(category, DEFAULT_ACTIVE_ITEMS[category])
				if loaded_value == null:
					loaded_value = DEFAULT_ACTIVE_ITEMS[category] 
				data["active_items"][category] = loaded_value
			for category in loaded_active_items_dict:
				if not DEFAULT_ACTIVE_ITEMS.has(category):
					data["active_items"][category] = loaded_active_items_dict[category]
			print("PlayerDataManager.gd: Данные игрока загружены из ", PLAYER_DATA_PATH)
		else:
			print("PlayerDataManager.gd: Ошибка парсинга JSON или данные не являются словарём в ", PLAYER_DATA_PATH)
			_save() 
	else:
		print("PlayerDataManager.gd: Файл player_data.json не найден, создаем новый: ", PLAYER_DATA_PATH)
		_save() 

	_load_best_grades()

func _save():
	var active_items_clean = {}
	for category in DEFAULT_ACTIVE_ITEMS:
		var current_value = data["active_items"].get(category)
		active_items_clean[category] = current_value
	if data["active_items"].has("Misc") and not active_items_clean.has("Misc"):
		active_items_clean["Misc"] = data["active_items"]["Misc"]
	data["active_items"] = active_items_clean

	var data_to_save = data.duplicate(true)
	data_to_save.erase("total_perfect_hits")
	data_to_save.erase("best_grades_per_track")

	var file_access = FileAccess.open(PLAYER_DATA_PATH, FileAccess.WRITE)
	if file_access:
		var json_text = JSON.stringify(data_to_save, "\t") 
		file_access.store_string(json_text)
		file_access.close()
		print("PlayerDataManager.gd: Данные игрока сохранены в ", PLAYER_DATA_PATH)
	else:
		print("PlayerDataManager.gd: Ошибка при открытии файла для записи: ", PLAYER_DATA_PATH)

func _load_best_grades():
	var file_access = FileAccess.open(BEST_GRADES_PATH, FileAccess.READ)
	if file_access:
		var json_text = file_access.get_as_text()
		file_access.close()
		var json_result = JSON.parse_string(json_text)
		if json_result is Dictionary:
			data["best_grades_per_track"] = json_result
			print("PlayerDataManager.gd: Загружены лучшие оценки из ", BEST_GRADES_PATH)
		else:
			print("PlayerDataManager.gd: best_grades.json повреждён или не является словарём")
			data["best_grades_per_track"] = {}
	else:
		print("PlayerDataManager.gd: best_grades.json не найден, создаём пустой")
		data["best_grades_per_track"] = {}

func _save_best_grades():
	var file_access = FileAccess.open(BEST_GRADES_PATH, FileAccess.WRITE)
	if file_access:
		var json_text = JSON.stringify(data["best_grades_per_track"], "\t")
		file_access.store_string(json_text)
		file_access.close()
		print("PlayerDataManager.gd: Лучшие оценки сохранены в ", BEST_GRADES_PATH)
	else:
		print("PlayerDataManager.gd: Ошибка при открытии best_grades.json для записи")

func get_currency() -> int:
	return int(data.get("currency", 0))

func set_track_stats_manager(tsm):
	track_stats_manager = tsm
	if track_stats_manager:
		data["favorite_track"] = track_stats_manager.get_favorite_track()
		data["favorite_track_play_count"] = track_stats_manager.get_favorite_track_count()

func on_track_completed(track_path: String):
	if track_stats_manager:
		track_stats_manager.on_track_completed(track_path)
		data["favorite_track"] = track_stats_manager.get_favorite_track()
		data["favorite_track_play_count"] = track_stats_manager.get_favorite_track_count()

func set_game_engine_reference(engine):
	game_engine_reference = engine
	if game_engine_reference:
		var achievement_system = game_engine_reference.get_achievement_system() if game_engine_reference.has_method("get_achievement_system") else null
		if achievement_system and achievement_system.has_method("on_playtime_changed"):
			self.total_play_time_changed.connect(achievement_system.on_playtime_changed)
		else:
			printerr("[PlayerDataManager] Не удалось подключить сигнал total_play_time_changed к AchievementSystem!")
	
func add_delayed_achievement(achievement_data: Dictionary):
	delayed_achievements.append(achievement_data)

func get_and_clear_delayed_achievements() -> Array[Dictionary]:
	var achievements = delayed_achievements.duplicate()
	delayed_achievements.clear()
	
	return achievements

func add_currency(amount: int):
	var old_currency = int(data.get("currency", 0))
	var new_currency = old_currency + amount
	data["currency"] = max(0, new_currency) 

	if amount < 0:
		var spent_amount = abs(amount)
		data["spent_currency"] = int(data.get("spent_currency", 0)) + spent_amount
		_trigger_currency_achievement_check()
	elif amount > 0:
		data["total_earned_currency"] = int(data.get("total_earned_currency", 0)) + amount
		_trigger_currency_achievement_check()

	_save()

func _trigger_currency_achievement_check():
	if game_engine_reference:
		var achievement_system = game_engine_reference.get_achievement_system() if game_engine_reference.has_method("get_achievement_system") else null
		if achievement_system:
			achievement_system.on_currency_changed()

func add_perfect_hits(count: int):
	var current_hits = int(data.get("total_notes_hit", 0))
	var new_total = current_hits + count
	data["total_notes_hit"] = new_total
	_save()
	print("[PlayerDataManager] Совершенных попаданий добавлено: %d. Общий счёт: %d" % [count, new_total])
	_trigger_perfect_hit_achievement_check()

func _trigger_perfect_hit_achievement_check():
	if game_engine_reference:
		var achievement_system = game_engine_reference.get_achievement_system() if game_engine_reference.has_method("get_achievement_system") else null
		if achievement_system:
			achievement_system.on_perfect_hit_made()

func xp_for_level(level: int) -> int:
	return int(100 * pow(1.5, level - 1))

func _calculate_xp_for_next_level():
	data["xp_for_next_level"] = xp_for_level(data["current_level"] + 1)

func add_xp(amount: int):
	data["total_xp"] += amount
	print("PlayerDataManager: Добавлено XP: %d, всего: %d" % [amount, data["total_xp"]])
	check_level_up()

func check_level_up():
	while data["total_xp"] >= data["xp_for_next_level"]:
		data["current_level"] += 1
		print("PlayerDataManager: Уровень повышен! Новый уровень: %d" % data["current_level"])
		_calculate_xp_for_next_level()
		emit_signal("level_changed", data["current_level"], data["total_xp"], data["xp_for_next_level"])
		_save() 

func get_xp_progress() -> float:
	if data["xp_for_next_level"] == 0:
		return 0.0
	return float(data["total_xp"]) / float(data["xp_for_next_level"])

func get_xp_progress_text() -> String:
	return "%d / %d" % [data["total_xp"], data["xp_for_next_level"]]

func get_total_xp() -> int:
	return data["total_xp"]

func get_current_level() -> int:
	return data["current_level"]

func get_xp_for_next_level() -> int:
	return data["xp_for_next_level"]

func get_items() -> PackedStringArray:
	return data.get("unlocked_item_ids", PackedStringArray()).duplicate()  

func unlock_item(item_name: String):
	if not data["unlocked_item_ids"].has(item_name):
		data["unlocked_item_ids"].append(item_name)  
		_trigger_purchase_achievement_check()
		_save()

func _trigger_purchase_achievement_check():
	if game_engine_reference:
		var achievement_system = game_engine_reference.get_achievement_system() if game_engine_reference.has_method("get_achievement_system") else null
		if achievement_system:
			achievement_system.on_purchase_made()

func is_item_unlocked(item_name: String) -> bool:
	return data["unlocked_item_ids"].has(item_name) 

func set_active_item(category: String, item_id: String):
	if data["active_items"].has(category):
		data["active_items"][category] = item_id
		_save()

func get_active_item(category: String) -> String:
	var active_item_id = data["active_items"].get(category)
	if active_item_id == null:
		var default_item = DEFAULT_ACTIVE_ITEMS.get(category, "")
		print("PlayerDataManager.gd: get_active_item: Активный предмет для категории '", category, "' равен null, возвращаем дефолтное значение: '", default_item, "'")
		return default_item if default_item != null else ""
	return active_item_id 

func get_all_unlocked_items() -> PackedStringArray:
	return data.get("unlocked_item_ids", PackedStringArray()).duplicate() 

func get_active_items() -> Dictionary:
	var active_items_copy = {}
	for category in data["active_items"]:
		var value = data["active_items"][category]
		if value is String or value == null:
			active_items_copy[category] = value
		else:
			print("PlayerDataManager.gd: get_active_items: Найдено некорректное значение для категории '", category, "': ", value, " (тип: ", typeof(value), ")")
	return active_items_copy

func get_save_data() -> Dictionary:
	var save_dict = data.duplicate(true)
	return save_dict

func load_save_data(save_dict: Dictionary):
	if save_dict.has("currency"):
		data["currency"] = int(save_dict["currency"])
	if save_dict.has("unlocked_item_ids"):
		if save_dict["unlocked_item_ids"] is Array:
			data["unlocked_item_ids"] = PackedStringArray(save_dict["unlocked_item_ids"]) 
		else:
			print("PlayerDataManager.gd: load_save_data: Поле 'unlocked_item_ids' не является массивом, пропускаем.")
	if save_dict.has("active_items"):
		if save_dict["active_items"] is Dictionary:
			data["active_items"].clear()
			data["active_items"].merge(DEFAULT_ACTIVE_ITEMS.duplicate(true)) 
			data["active_items"].merge(save_dict["active_items"]) 
			for category in DEFAULT_ACTIVE_ITEMS:
				var loaded_value = data["active_items"].get(category, DEFAULT_ACTIVE_ITEMS[category])
				if loaded_value == null:
					loaded_value = DEFAULT_ACTIVE_ITEMS[category]
				data["active_items"][category] = loaded_value
		else:
			print("PlayerDataManager.gd: load_save_data: Поле 'active_items' не является словарём, пропускаем.")
	if save_dict.has("unlocked_achievement_ids"): 
		if save_dict["unlocked_achievement_ids"] is Array:
			data["unlocked_achievement_ids"] = PackedInt32Array(save_dict["unlocked_achievement_ids"]) 
		else:
			print("PlayerDataManager.gd: load_save_data: Поле 'unlocked_achievement_ids' не является массивом, пропускаем.")
	if save_dict.has("spent_currency"):
		data["spent_currency"] = int(save_dict["spent_currency"])
	if save_dict.has("total_earned_currency"):
		data["total_earned_currency"] = int(save_dict["total_earned_currency"])
	if save_dict.has("drum_levels_completed"):
		data["drum_levels_completed"] = int(save_dict["drum_levels_completed"])
	if save_dict.has("total_drum_perfect_hits"):
		data["total_drum_perfect_hits"] = int(save_dict["total_drum_perfect_hits"])
	if save_dict.has("total_notes_hit"):
		data["total_notes_hit"] = int(save_dict["total_notes_hit"])
	if save_dict.has("total_notes_missed"):
		data["total_notes_missed"] = int(save_dict["total_notes_missed"])
	if save_dict.has("max_combo_ever"):
		data["max_combo_ever"] = int(save_dict["max_combo_ever"])
	if save_dict.has("max_drum_combo_ever"):
		data["max_drum_combo_ever"] = int(save_dict["max_drum_combo_ever"])
	if save_dict.has("total_drum_hits"):
		data["total_drum_hits"] = int(save_dict["total_drum_hits"])
	if save_dict.has("total_drum_misses"):
		data["total_drum_misses"] = int(save_dict["total_drum_misses"])
	if save_dict.has("last_login_date"):
		data["last_login_date"] = save_dict["last_login_date"]
	if save_dict.has("login_streak"):
		data["login_streak"] = int(save_dict["login_streak"])
	if save_dict.has("levels_completed"):
		data["levels_completed"] = int(save_dict["levels_completed"])
	if save_dict.has("total_play_time"): 
		data["total_play_time"] = str(save_dict["total_play_time"])
		_total_play_time_seconds = _play_time_string_to_seconds(data["total_play_time"])
	if save_dict.has("total_score_ever"):
		data["total_score_ever"] = int(save_dict["total_score_ever"])
	if save_dict.has("total_drum_score_ever"):
		data["total_drum_score_ever"] = int(save_dict["total_drum_score_ever"])
	
	if save_dict.has("total_xp"):
		data["total_xp"] = int(save_dict["total_xp"])
	if save_dict.has("current_level"):
		data["current_level"] = int(save_dict["current_level"])
	if save_dict.has("xp_for_next_level"):
		data["xp_for_next_level"] = int(save_dict["xp_for_next_level"])

	if save_dict.has("favorite_track"):
		data["favorite_track"] = save_dict["favorite_track"]
	if save_dict.has("favorite_track_play_count"):
		data["favorite_track_play_count"] = int(save_dict["favorite_track_play_count"])

	if save_dict.has("grades"):
		var loaded_grades = save_dict["grades"]
		if loaded_grades is Dictionary:
			data["grades"] = loaded_grades
		else:
			print("PlayerDataManager.gd: load_save_data: Поле 'grades' не является словарём, пропускаем.")
	_save()

func reset_progress():
	var current_currency = int(data.get("currency", 0))
	var current_active_items = data.get("active_items", DEFAULT_ACTIVE_ITEMS.duplicate(true)).duplicate(true)

	data["unlocked_item_ids"] = PackedStringArray() 
	data["unlocked_achievement_ids"] = PackedInt32Array() 
	data["spent_currency"] = 0
	data["total_earned_currency"] = 0
	data["drum_levels_completed"] = 0
	data["total_drum_perfect_hits"] = 0
	data["total_notes_hit"] = 0
	data["total_notes_missed"] = 0
	data["max_combo_ever"] = 0
	data["max_drum_combo_ever"] = 0
	data["total_drum_hits"] = 0
	data["total_drum_misses"] = 0
	data["total_score_ever"] = 0
	data["total_drum_score_ever"] = 0
	data["total_play_time"] = "00:00" 
	data["grades"] = {
		"SS": 0,
		"S": 0,
		"A": 0,
		"B": 0,
		"C": 0,
		"D": 0,
		"F": 0
	}

	data["favorite_track"] = ""
	data["favorite_track_play_count"] = 0

	data["total_xp"] = 0
	data["current_level"] = 1
	data["xp_for_next_level"] = 100

	_total_play_time_seconds = 0

	data["last_login_date"] = ""
	data["login_streak"] = 0 
	data["levels_completed"] = 0

	data["currency"] = current_currency 
	data["active_items"] = current_active_items

	_save()
	data["best_grades_per_track"] = {}
	_save_best_grades()
	print("[PlayerDataManager] Прогресс сброшен.")

func reset_profile_statistics():
	var current_currency = int(data.get("currency", 0))
	var current_unlocked_items = data.get("unlocked_item_ids", PackedStringArray()).duplicate()
	var current_active_items = data.get("active_items", DEFAULT_ACTIVE_ITEMS.duplicate(true)).duplicate(true)
	var current_unlocked_achievements = data.get("unlocked_achievement_ids", PackedInt32Array()).duplicate()
	var current_login_streak = int(data.get("login_streak", 0))
	var current_last_login_date = data.get("last_login_date", "")

	data["levels_completed"] = 0
	data["drum_levels_completed"] = 0
	data["total_drum_perfect_hits"] = 0
	data["total_notes_hit"] = 0
	data["total_notes_missed"] = 0
	data["max_combo_ever"] = 0
	data["max_drum_combo_ever"] = 0
	data["total_drum_hits"] = 0
	data["total_drum_misses"] = 0
	data["total_score_ever"] = 0
	data["total_drum_score_ever"] = 0
	data["spent_currency"] = 0
	data["total_earned_currency"] = 0
	data["total_play_time"] = "00:00" 
	data["grades"] = {
		"SS": 0,
		"S": 0,
		"A": 0,
		"B": 0,
		"C": 0,
		"D": 0,
		"F": 0
	}

	data["favorite_track"] = ""
	data["favorite_track_play_count"] = 0

	data["total_xp"] = 0
	data["current_level"] = 1
	data["xp_for_next_level"] = 100

	_total_play_time_seconds = 0

	data["currency"] = current_currency
	data["unlocked_item_ids"] = current_unlocked_items
	data["active_items"] = current_active_items
	data["unlocked_achievement_ids"] = current_unlocked_achievements
	data["login_streak"] = current_login_streak
	data["last_login_date"] = current_last_login_date

	if track_stats_manager:
		track_stats_manager.reset_stats()

	_save()
	data["best_grades_per_track"] = {}
	_save_best_grades()
	print("[PlayerDataManager] Статистика профиля (включая валюту, время, но не предметы/ачивки/данные аккаунта) сброшена.")

func get_login_streak() -> int:
	return int(data.get("login_streak", 0))

func set_login_streak(streak: int) -> void:
	data["login_streak"] = int(streak)
	data["last_login_date"] = Time.get_date_string_from_system()
	_save()
	_trigger_login_achievement_check()

func increment_login_streak() -> void:
	data["login_streak"] = int(data.get("login_streak", 0)) + 1
	data["last_login_date"] = Time.get_date_string_from_system() 
	_save()
	_trigger_login_achievement_check()

func reset_login_streak() -> void:
	data["login_streak"] = 0
	data["last_login_date"] = Time.get_date_string_from_system()
	_save()
	_trigger_login_achievement_check()  

func _trigger_login_achievement_check():
	if game_engine_reference:
		var achievement_system = game_engine_reference.get_achievement_system() if game_engine_reference.has_method("get_achievement_system") else null
		if achievement_system:
			achievement_system.on_daily_login()

func unlock_achievement(achievement_id: int) -> void:
	if not data["unlocked_achievement_ids"].has(achievement_id):  
		data["unlocked_achievement_ids"].append(achievement_id) 
		_save()
		print("[PlayerDataManager] Достижение с ID %d разблокировано для игрока." % achievement_id)

func is_achievement_unlocked(achievement_id: int) -> bool:
	return data["unlocked_achievement_ids"].has(achievement_id)

func add_completed_level():
	var current_count = int(data.get("levels_completed", 0))
	var new_count = current_count + 1
	data["levels_completed"] = new_count
	_save()
	print("[PlayerDataManager] Уровень завершён. Текущий levels_completed: ", new_count)

func _trigger_level_achievement_check():
	if game_engine_reference:
		var achievement_system = game_engine_reference.get_achievement_system() if game_engine_reference.has_method("get_achievement_system") else null
		if achievement_system:
			var final_accuracy = 100.0
			achievement_system.on_level_completed(final_accuracy)

func get_levels_completed() -> int:
	return int(data.get("levels_completed", 0))

func add_drum_level_completed():
	var current_count = int(data.get("drum_levels_completed", 0))
	var new_count = current_count + 1
	data["drum_levels_completed"] = new_count
	_save()
	print("[PlayerDataManager] Уровень на барабанах завершён. Текущий drum_levels_completed: ", new_count)

func get_drum_levels_completed() -> int:
	return int(data.get("drum_levels_completed", 0))

func add_total_drum_perfect_hit():
	var current_total = int(data.get("total_drum_perfect_hits", 0))
	var new_total = current_total + 1
	data["total_drum_perfect_hits"] = new_total
	_save()

func add_hit_notes(count: int):
	var current_hits = int(data.get("total_notes_hit", 0))
	data["total_notes_hit"] = current_hits + count
	_save() 

func add_missed_notes(count: int):
	var current_misses = int(data.get("total_notes_missed", 0))
	data["total_notes_missed"] = current_misses + count
	_save() 

func get_total_notes_hit() -> int:
	return int(data.get("total_notes_hit", 0))

func get_total_notes_missed() -> int:
	return int(data.get("total_notes_missed", 0))

func get_total_notes_played() -> int: 
	return get_total_notes_hit() + get_total_notes_missed()

func add_score_to_total(score: int, is_drum_mode: bool = false):
	var current_total = int(data.get("total_score_ever", 0))
	var new_total = current_total + score
	data["total_score_ever"] = new_total
	print("[PlayerDataManager] Добавлено очков к общему счёту: %d. Общий счёт: %d" % [score, new_total])
	
	if is_drum_mode:
		var current_drum_total = int(data.get("total_drum_score_ever", 0))
		var new_drum_total = current_drum_total + score
		data["total_drum_score_ever"] = new_drum_total
		print("[PlayerDataManager] Добавлено очков к барабанному счёту: %d. Общий барабанный счёт: %d" % [score, new_drum_total])
	
	_save()

func get_total_score() -> int:
	return int(data.get("total_score_ever", 0))

func get_total_drum_score() -> int:
	return int(data.get("total_drum_score_ever", 0))

func _play_time_string_to_seconds(time_str: String) -> int:
	var parts = time_str.split(":")
	if parts.size() == 2:
		var hours = parts[0].to_int()
		var minutes = parts[1].to_int()
		return (hours * 3600) + (minutes * 60)
	return 0

func _play_time_seconds_to_string(total_seconds: int) -> String:
	var hours = total_seconds / 3600
	var minutes = (total_seconds % 3600) / 60
	return str(hours).pad_zeros(2) + ":" + str(minutes).pad_zeros(2)

func add_play_time_seconds(seconds_to_add: int):
	_total_play_time_seconds += seconds_to_add
	var new_time_string = _play_time_seconds_to_string(_total_play_time_seconds)
	print("PlayerDataManager.gd (DEBUG add_play_time): Добавляем: ", seconds_to_add, ", Новое общее время (сек): ", _total_play_time_seconds, ", Новое время (строка): ", new_time_string)
	data["total_play_time"] = new_time_string
	emit_signal("total_play_time_changed", new_time_string)
	_save()

func get_total_play_time_formatted() -> String:
	return data.get("total_play_time", "00:00")

func get_total_play_time_seconds() -> int:
	return _total_play_time_seconds

func update_best_grade_for_track(song_path: String, new_grade: String):
	if song_path.is_empty():
		return

	var grade_order = {"SS": 0, "S": 1, "A": 2, "B": 3, "C": 4, "D": 5, "F": 6}
	var current_best_grade = data["best_grades_per_track"].get(song_path, "")
	var new_grade_order = grade_order.get(new_grade, 99)
	var current_best_order = grade_order.get(current_best_grade, 99)

	if new_grade_order < current_best_order:
		if current_best_grade != "":
			var current_count = data["grades"].get(current_best_grade, 0)
			data["grades"][current_best_grade] = max(0, current_count - 1)

		var new_count = data["grades"].get(new_grade, 0)
		data["grades"][new_grade] = new_count + 1

		data["best_grades_per_track"][song_path] = new_grade

		_save()  
		_save_best_grades()  
		print("PlayerDataManager: Обновлена лучшая оценка для '%s': %s" % [song_path, new_grade])
