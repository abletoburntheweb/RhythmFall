# logic/player_data_manager.gd
class_name PlayerDataManager 
extends RefCounted

const PLAYER_DATA_PATH = "user://player_data.json" 
const DEFAULT_ACTIVE_ITEMS = {
	"Kick": "kick_default",
	"Snare": "snare_default",
	"Backgrounds": "background_default",
	"Covers": "covers_default",
	"Misc": null 
}

var data: Dictionary = {
	"currency": 0,
	"items": {},
	"active_items": DEFAULT_ACTIVE_ITEMS.duplicate(true), 
	"achievements": {},
	"spent_currency": 0,
	"total_earned_currency": 0,
	"last_login_date": "",
	"login_streak": 0
}

var achievement_manager = null

func _init():
	_load()

	var default_items = [
		"kick_default",
		"snare_default",
		"covers_default",
	]
	var items_changed = false
	for item_id in default_items:
		if not data["items"].has(item_id): 
			data["items"][item_id] = true  
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
			var loaded_currency = json_result.get("currency", 0)
			var loaded_items = json_result.get("items", {})
			var loaded_active_items = json_result.get("active_items", {})
			var loaded_last_login = json_result.get("last_login_date", "")
			var loaded_login_streak = json_result.get("login_streak", 0)
			var loaded_achievements = json_result.get("achievements", {})
			var loaded_spent_currency = json_result.get("spent_currency", 0)
			var loaded_total_earned_currency = json_result.get("total_earned_currency", 0)
			
			print("PlayerDataManager.gd: Загружено currency: ", loaded_currency)
			print("PlayerDataManager.gd: Загружено items: ", loaded_items)
			print("PlayerDataManager.gd: Загружено active_items: ", loaded_active_items)
			
			data["currency"] = loaded_currency
			data["items"] = loaded_items.duplicate(true) 
			data["achievements"] = loaded_achievements.duplicate(true) 
			data["spent_currency"] = loaded_spent_currency
			data["total_earned_currency"] = loaded_total_earned_currency

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
		
func _save():
	var active_items_clean = {}
	for category in DEFAULT_ACTIVE_ITEMS:
		var current_value = data["active_items"].get(category)
		active_items_clean[category] = current_value
	if data["active_items"].has("Misc") and not active_items_clean.has("Misc"):
		active_items_clean["Misc"] = data["active_items"]["Misc"]
	data["active_items"] = active_items_clean

	var file_access = FileAccess.open(PLAYER_DATA_PATH, FileAccess.WRITE)
	if file_access:
		var json_text = JSON.stringify(data, "\t") 
		file_access.store_string(json_text)
		file_access.close()
		print("PlayerDataManager.gd: Данные игрока сохранены в ", PLAYER_DATA_PATH)
	else:
		print("PlayerDataManager.gd: Ошибка при открытии файла для записи: ", PLAYER_DATA_PATH)

func get_currency() -> int:
	return data.get("currency", 0)

func add_currency(amount: int):
	var old_currency = data.get("currency", 0)
	var new_currency = old_currency + amount
	data["currency"] = max(0, new_currency) 

	if amount < 0:
		var spent_amount = abs(amount)
		data["spent_currency"] = data.get("spent_currency", 0) + spent_amount
		if achievement_manager:
			achievement_manager.check_spent_currency_achievement(data["spent_currency"])
	elif amount > 0:
		data["total_earned_currency"] = data.get("total_earned_currency", 0) + amount
		if achievement_manager:
			achievement_manager.check_currency_achievements(self) 

	_save()

func get_items() -> Dictionary:
	return data.get("items", {}).duplicate(true) 

func unlock_item(item_name: String):
	var old_count = data["items"].size()
	data["items"][item_name] = true
	var new_count = data["items"].size()

	if achievement_manager:
		if old_count == 0 and new_count == 1:
			achievement_manager.check_first_purchase()
		
		achievement_manager.check_purchase_count(new_count)
		
		achievement_manager.check_style_hunter_achievement(self) 
	
		achievement_manager.check_collection_completed_achievement(self) 

	_save()

func is_item_unlocked(item_name: String) -> bool:
	return data["items"].get(item_name, false)

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
	var unlocked = PackedStringArray()
	for item_id in data.get("items", {}):
		if data["items"][item_id]:
			if item_id is String:
				unlocked.append(item_id)
			else:
				print("PlayerDataManager.gd: get_all_unlocked_items: Найден нестроковый ключ в items: ", item_id, " (тип: ", typeof(item_id), ")")
	return unlocked

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
		data["currency"] = save_dict["currency"]
	if save_dict.has("items"):
		if save_dict["items"] is Dictionary:
			data["items"] = save_dict["items"].duplicate(true)
		else:
			print("PlayerDataManager.gd: load_save_data: Поле 'items' не является словарём, пропускаем.")
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
	if save_dict.has("achievements"):
		data["achievements"] = save_dict["achievements"].duplicate(true)
	if save_dict.has("spent_currency"):
		data["spent_currency"] = save_dict["spent_currency"]
	if save_dict.has("total_earned_currency"):
		data["total_earned_currency"] = save_dict["total_earned_currency"]
	if save_dict.has("last_login_date"):
		data["last_login_date"] = save_dict["last_login_date"]
	if save_dict.has("login_streak"):
		data["login_streak"] = save_dict["login_streak"]
	_save()

func reset_progress():
	var current_currency = data.get("currency", 0)
	var current_active_items = data.get("active_items", DEFAULT_ACTIVE_ITEMS.duplicate(true)).duplicate(true)

	data["items"] = {}
	data["achievements"] = {}
	data["spent_currency"] = 0
	data["total_earned_currency"] = 0
	data["last_login_date"] = ""
	data["login_streak"] = 0 

	data["currency"] = current_currency 
	data["active_items"] = current_active_items

	_save()
	print("[PlayerDataManager] Прогресс сброшен.")

func get_login_streak() -> int:
	return data.get("login_streak", 0)

func set_login_streak(streak: int) -> void:
	data["login_streak"] = streak
	data["last_login_date"] = Time.get_date_string_from_system()
	_save()
	if achievement_manager:
		achievement_manager.check_daily_login_achievements(self) 

func increment_login_streak() -> void:
	data["login_streak"] = data.get("login_streak", 0) + 1
	data["last_login_date"] = Time.get_date_string_from_system() 
	_save()
	if achievement_manager:
		achievement_manager.check_daily_login_achievements(self) 

func reset_login_streak() -> void:
	data["login_streak"] = 0
	data["last_login_date"] = Time.get_date_string_from_system()
	_save()

func unlock_achievement(achievement_id: int) -> void:
	data["achievements"][str(achievement_id)] = true
	_save()
	print("[PlayerDataManager] Достижение с ID %d разблокировано для игрока." % achievement_id)

func is_achievement_unlocked(achievement_id: int) -> bool:
	return data["achievements"].get(str(achievement_id), false)
