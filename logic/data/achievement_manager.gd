# logic/data/achievement_manager.gd
class_name AchievementManager
extends RefCounted

const ACHIEVEMENTS_JSON_PATH := "res://data/achievements_data.json"
const SHOP_JSON_PATH := "res://data/shop_data.json"
const DEFAULT_ACHIEVEMENT_ICON_PATH := "res://assets/achievements/default.png"
const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const ResultsHistoryService = preload("res://logic/data/results_history_service.gd")
const GenreSearch = preload("res://logic/domain/library/genre_search.gd")
const ProfileGenrePortrait = preload("res://logic/domain/profile/profile_genre_portrait.gd")


var player_data_mgr = null 
var notification_mgr = null

var achievements: Array[Dictionary] = []
var genre_group_map: Dictionary = {}
var new_mastery_achievements: Array[Dictionary] = []
var _ach_by_id: Dictionary = {}
var _suppress_unlock_notifications := false

func _init(json_path: String = ACHIEVEMENTS_JSON_PATH):
	load_achievements(json_path)
	_load_genre_group_map()

func set_suppress_unlock_notifications(suppress: bool) -> void:
	_suppress_unlock_notifications = suppress


static func is_deprecated(achievement: Dictionary) -> bool:
	return bool(achievement.get("deprecated", false))


static func is_active(achievement: Dictionary) -> bool:
	return not is_deprecated(achievement)


## Catalog: only active achievements (deprecated are fully retired).
static func is_visible_in_catalog(achievement: Dictionary) -> bool:
	return is_active(achievement)


func restore_unlock_state_from_player_data() -> void:
	if not player_data_mgr:
		return
	var ids: Variant = player_data_mgr.data.get("unlocked_achievement_ids", PackedInt32Array())
	if not (ids is PackedInt32Array or ids is Array):
		return
	var changed := false
	for raw_id in ids:
		var ach_id := int(raw_id)
		var a = get_achievement_by_id(ach_id)
		if a == null or is_deprecated(a):
			continue
		if not a.get("unlocked", false):
			a.unlocked = true
			a.current = max(int(a.get("current", 0)), int(a.get("total", 1)))
			changed = true
		# Restored unlocks often have no date — leave empty so UI shows «Ранее», not «Дата неизвестна».
		var raw_date = a.get("unlock_date", null)
		if raw_date == null or str(raw_date).strip_edges() == "" or str(raw_date).to_lower() == "<null>":
			a.unlock_date = ""
			changed = true
	if changed:
		save_achievements()


## Hard retire: clear unlocks for deprecated ids in achievements JSON + player_data.
func purge_deprecated_unlocks() -> void:
	var dep_ids: Dictionary = {}
	var ach_changed := false
	for i in range(achievements.size()):
		var a: Dictionary = achievements[i]
		if not is_deprecated(a):
			continue
		var ach_id := int(a.get("id", -1))
		if ach_id >= 0:
			dep_ids[ach_id] = true
		var need := bool(a.get("unlocked", false)) or int(a.get("current", 0)) != 0
		var raw_date = a.get("unlock_date", null)
		if raw_date != null and str(raw_date).strip_edges() != "" and str(raw_date).to_lower() != "<null>":
			need = true
		if need:
			a.unlocked = false
			a.current = 0
			a.unlock_date = null
			achievements[i] = a
			ach_changed = true
	var pdm_changed := false
	if player_data_mgr and player_data_mgr.data is Dictionary and not dep_ids.is_empty():
		var ids: Variant = player_data_mgr.data.get("unlocked_achievement_ids", PackedInt32Array())
		if ids is PackedInt32Array or ids is Array:
			var kept := PackedInt32Array()
			for raw_id in ids:
				var ach_id := int(raw_id)
				if not dep_ids.has(ach_id):
					kept.append(ach_id)
			if kept.size() != ids.size():
				player_data_mgr.data["unlocked_achievement_ids"] = kept
				pdm_changed = true
	if ach_changed:
		save_achievements()
	if pdm_changed and player_data_mgr.has_method("_save"):
		player_data_mgr._save()
	if ach_changed:
		_rebuild_index()


func load_achievements(json_path: String = ACHIEVEMENTS_JSON_PATH):
	var _perf_ach_total_start := PerfTrace.begin("perf.load.achievements.total")
	var user_path = "user://achievements_data.json"
	var open_path = user_path if FileAccess.file_exists(user_path) else json_path
	if not FileAccess.file_exists(open_path):
		achievements = []
		PerfTrace.end("perf.load.achievements.total", _perf_ach_total_start)
		return

	var file = FileAccess.open(open_path, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()

		var json_parse_result = JSON.parse_string(json_text)
		if json_parse_result is Dictionary:
			CatalogDataSync._cache_set(open_path, json_parse_result)
		if json_parse_result and json_parse_result.has("achievements"):
			if json_parse_result.achievements is Array:
				var loaded: Array[Dictionary] = []
				var seen_ids: Dictionary = {}
				var changed := false
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
						item.id = ach_id
						if item.has("image"):
							item.erase("image")
							changed = true
						if typeof(total_val) == TYPE_NIL:
							item.total = 1
						elif typeof(total_val) == TYPE_FLOAT or typeof(total_val) == TYPE_INT:
							item.total = max(1, int(total_val))
						else:
							item.total = 1
						var cur_val = item.get("current", 0)
						if typeof(cur_val) == TYPE_NIL:
							item.current = 0
						elif category == "playtime":
							item.current = float(cur_val)
						else:
							item.current = int(cur_val)
						item.unlocked = bool(item.get("unlocked", false))
						if not item.has("unlock_date"):
							item.unlock_date = null
						loaded.append(item)
					else:
						printerr("[AchievementManager] Найден элемент не типа Dictionary в списке достижений: ", item)
				achievements = loaded
				if changed:
					save_achievements(user_path)
				new_mastery_achievements.clear()
				_apply_achievement_migrations()
				_merge_missing_seed_achievements()
				_sync_deprecated_flags_from_seed()
			else:
				printerr("[AchievementManager] Поле 'achievements' в JSON не является массивом.")
				achievements = []
		else:
			printerr("[AchievementManager] Ошибка парсинга JSON или отсутствие ключа 'achievements'.")
			achievements = []
	else:
		printerr("[AchievementManager] Не удалось открыть файл ", open_path)
		achievements = []
	_rebuild_index()
	PerfTrace.end("perf.load.achievements.total", _perf_ach_total_start)

func _apply_achievement_migrations():
	var updates = {
		39: 300000,
		42: 2400000,
		11: 5000,
		13: 50000,
		14: 2000,
		16: 15000,
		# Drums/bass content replace (v1.3): totals for new conditions.
		31: 50,
		68: 1000,
		69: 1,
		168: 1,
		171: 50,
		172: 50,
		# RR mastery soften — sum of chart bests, not lifetime grind.
		124: 1500,
		126: 15000,
		128: 50000,
	}
	var preserve_progress_ids := {
		124: true,
		126: true,
		128: true,
	}
	for i in range(achievements.size()):
		var a: Dictionary = achievements[i]
		var id_val = int(a.get("id", -1))
		if updates.has(id_val):
			var new_total = int(updates[id_val])
			var old_total = int(a.get("total", 1))
			if new_total != old_total:
				a.total = new_total
				if bool(a.get("unlocked", false)):
					a.current = new_total
				elif preserve_progress_ids.has(id_val):
					a.current = mini(int(a.get("current", 0)), new_total)
				else:
					a.current = 0
				achievements[i] = a
	_sync_replaced_achievement_copy_from_seed()


func _sync_replaced_achievement_copy_from_seed() -> void:
	if not FileAccess.file_exists(ACHIEVEMENTS_JSON_PATH):
		return
	var seed_file = FileAccess.open(ACHIEVEMENTS_JSON_PATH, FileAccess.READ)
	if seed_file == null:
		return
	var parsed = JSON.parse_string(seed_file.get_as_text())
	seed_file.close()
	if not parsed is Dictionary or not parsed.get("achievements") is Array:
		return
	var replace_ids := {
		31: true, 68: true, 69: true, 168: true, 171: true, 172: true, 173: true, 174: true
	}
	var seed_by_id: Dictionary = {}
	for item in parsed.achievements:
		if item is Dictionary:
			seed_by_id[int(item.get("id", -1))] = item
	var changed := false
	for i in range(achievements.size()):
		var a: Dictionary = achievements[i]
		var id_val := int(a.get("id", -1))
		if not replace_ids.has(id_val) or not seed_by_id.has(id_val):
			continue
		var seed: Dictionary = seed_by_id[id_val]
		var new_title := str(seed.get("title", ""))
		var new_desc := str(seed.get("description", ""))
		var new_total: int = maxi(1, int(seed.get("total", 1)))
		if str(a.get("title", "")) != new_title or str(a.get("description", "")) != new_desc or int(a.get("total", 1)) != new_total:
			a.title = new_title
			a.description = new_desc
			a.total = new_total
			achievements[i] = a
			changed = true
	if changed:
		save_achievements("user://achievements_data.json")

func _merge_missing_seed_achievements() -> void:
	if not FileAccess.file_exists(ACHIEVEMENTS_JSON_PATH):
		return
	var seed_file = FileAccess.open(ACHIEVEMENTS_JSON_PATH, FileAccess.READ)
	if seed_file == null:
		return
	var parsed = JSON.parse_string(seed_file.get_as_text())
	seed_file.close()
	if not parsed is Dictionary or not parsed.get("achievements") is Array:
		return
	var existing: Dictionary = {}
	for a in achievements:
		existing[int(a.get("id", -1))] = true
	var added := false
	for item in parsed.achievements:
		if not item is Dictionary:
			continue
		var ach_id := int(item.get("id", -1))
		if ach_id < 0 or existing.has(ach_id):
			continue
		var copy: Dictionary = item.duplicate(true)
		copy.id = ach_id
		if copy.has("image"):
			copy.erase("image")
		copy.total = max(1, int(copy.get("total", 1)))
		copy.current = int(copy.get("current", 0))
		copy.unlocked = bool(copy.get("unlocked", false))
		if not copy.has("unlock_date"):
			copy.unlock_date = null
		achievements.append(copy)
		existing[ach_id] = true
		added = true
	if added:
		save_achievements("user://achievements_data.json")


func _sync_deprecated_flags_from_seed() -> void:
	if not FileAccess.file_exists(ACHIEVEMENTS_JSON_PATH):
		return
	var seed_file = FileAccess.open(ACHIEVEMENTS_JSON_PATH, FileAccess.READ)
	if seed_file == null:
		return
	var parsed = JSON.parse_string(seed_file.get_as_text())
	seed_file.close()
	if not parsed is Dictionary or not parsed.get("achievements") is Array:
		return
	var seed_dep: Dictionary = {}
	for item in parsed.achievements:
		if item is Dictionary:
			seed_dep[int(item.get("id", -1))] = bool(item.get("deprecated", false))
	var changed := false
	for i in range(achievements.size()):
		var a: Dictionary = achievements[i]
		var id_val := int(a.get("id", -1))
		if not seed_dep.has(id_val):
			continue
		var want := bool(seed_dep[id_val])
		var has := a.has("deprecated")
		var cur := bool(a.get("deprecated", false))
		if want:
			if not has or not cur:
				a["deprecated"] = true
				achievements[i] = a
				changed = true
		elif has:
			a.erase("deprecated")
			achievements[i] = a
			changed = true
	if changed:
		save_achievements("user://achievements_data.json")
		_rebuild_index()


func save_achievements(json_path: String = ACHIEVEMENTS_JSON_PATH):
	var user_path = "user://achievements_data.json"
	var save_path = user_path
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		var json_to_save = {"achievements": achievements}
		var json_string = JSON.stringify(json_to_save, "\t")
		file.store_string(json_string)
		file.close()
	else:
		printerr("[AchievementManager] Не удалось сохранить файл ", save_path)

func _rebuild_index():
	_ach_by_id.clear()
	for a in achievements:
		_ach_by_id[int(a.get("id", -1))] = a

func get_achievement_by_id(achievement_id: int):
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
		if a == null or is_deprecated(a):
			continue
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
	if a == null or is_deprecated(a):
		return
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
	# Deprecated achievements are fully retired — never grant.
	if is_deprecated(achievement):
		return

	achievement.unlocked = true
	achievement.current = achievement.get("total", 1)

	var date = Time.get_date_dict_from_system()
	var time = Time.get_time_dict_from_system()
	var TimeUtils = preload("res://logic/platform/time_utils.gd")
	var date_text = TimeUtils.format_date_parts_ru(int(date.get("day", 1)), int(date.get("month", 1)), int(date.get("year", 2000)))
	var time_str = "%02d:%02d" % [int(time.get("hour", 0)), int(time.get("minute", 0))]
	achievement.unlock_date = "%s, %s" % [date_text, time_str]

	save_achievements()

	if player_data_mgr:
		player_data_mgr.unlock_achievement(int(achievement.get("id", -1)))


	var category = achievement.get("category", "")
	if category == "mastery":
		if not new_mastery_achievements.has(achievement):
			new_mastery_achievements.append(achievement)
	elif notification_mgr and not _suppress_unlock_notifications:
		notification_mgr.show_achievement_popup(achievement)
	elif not notification_mgr and not _suppress_unlock_notifications:
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

func _load_shop_json() -> Dictionary:
	var _st_total_inner := Time.get_ticks_usec()
	var user_path = "user://shop_data.json"
	var path = user_path if FileAccess.file_exists(user_path) else SHOP_JSON_PATH
	if not FileAccess.file_exists(path):
		var alt = "res://logic/shop_data.json"
		path = alt if FileAccess.file_exists(alt) else path
	if not FileAccess.file_exists(path):
		var exe_dir = OS.get_executable_path().get_base_dir()
		var ext = exe_dir.path_join("data/shop_data.json").replace("\\", "/")
		if FileAccess.file_exists(ext):
			path = ext
	var shop_file = FileAccess.open(path, FileAccess.READ)
	if not shop_file:
		return {}
	var shop_json_text = shop_file.get_as_text()
	shop_file.close()
	var parsed = JSON.parse_string(shop_json_text)
	var _total_ms := (Time.get_ticks_usec() - _st_total_inner) / 1000.0
	var ge: Node = Engine.get_main_loop().root.get_node_or_null("GameEngine") if Engine.get_main_loop() and Engine.get_main_loop().root else null
	if ge and "_startup_trace" in ge:
		var cnt: int = int(ge._startup_trace.get("load_shop_json_calls", 0)) + 1
		ge._startup_trace["load_shop_json_calls"] = cnt
		ge._startup_trace["load_shop_json_last_ms"] = _total_ms
		var acc: float = float(ge._startup_trace.get("load_shop_json_total_ms", 0.0)) + _total_ms
		ge._startup_trace["load_shop_json_total_ms"] = acc
		ge._startup_trace["load_shop_json_at_ms"] = (Time.get_ticks_usec() - ge._startup_t0_usec) / 1000.0 if ge._startup_t0_usec != 0 else 0.0
	if parsed is Dictionary and parsed.has("items"):
		return parsed
	return {}

func check_first_purchase():
	unlock_achievement_by_id(6)

func check_purchase_count(total_purchases: int):
	_update_ids([7, 10], total_purchases)
	save_achievements()

func check_currency_achievements(player_data_mgr_override = null):
	var pdm = _get_pdm(player_data_mgr_override)
	var total_earned = 0
	if pdm:
		total_earned = pdm.data.get("total_earned_currency", 0)
	else:
		printerr("[AchievementManager] check_currency_achievements: pdm is null!") 
		return
	_update_ids([11, 13], total_earned)
	save_achievements()

func check_spent_currency_achievement(total_spent: int):
	_update_ids([14, 16], total_spent)
	save_achievements()

func check_style_hunter_achievement(player_data_mgr_override = null, save: bool = true):
	var _st_total := Time.get_ticks_usec()
	var _trace: Dictionary = {}
	var _st_step: int
	var pdm = _get_pdm(player_data_mgr_override)
	var categories: Dictionary = {}
	var purchasable_categories: Dictionary = {}

	if pdm:
		_st_step = Time.get_ticks_usec()
		var unlocked_items = pdm.get_items()
		_trace["get_items_ms"] = (Time.get_ticks_usec() - _st_step) / 1000.0
		_st_step = Time.get_ticks_usec()
		var shop_json_parse_result = _load_shop_json()
		_trace["load_shop_ms"] = (Time.get_ticks_usec() - _st_step) / 1000.0
		if shop_json_parse_result and shop_json_parse_result.has("items"):
			_st_step = Time.get_ticks_usec()
			for item in shop_json_parse_result.items:
					var item_id = item.get("item_id", "")
					var price = int(item.get("price", 0))
					var category_ru = item.get("category", "")
					var category_internal = _map_category_ru_to_internal(category_ru)
					if category_internal == "":
						category_internal = category_ru.strip_edges()

					if not categories.has(category_internal):
						categories[category_internal] = []

					if price > 0:
						purchasable_categories[category_internal] = true
						if unlocked_items.has(item_id):
							categories[category_internal].append(item_id)
			_trace["loop_items_ms"] = (Time.get_ticks_usec() - _st_step) / 1000.0
		else:
			printerr("[AchievementManager] Ошибка парсинга shop_data.json или отсутствие ключа 'items'.")
			_trace["loop_items_ms"] = 0.0
	else:
		_trace["get_items_ms"] = 0.0
		_trace["load_shop_ms"] = 0.0
		_trace["loop_items_ms"] = 0.0

	_st_step = Time.get_ticks_usec()
	var categories_with_items = 0
	for key in categories.keys():
		var items: Array = categories[key]
		if items.size() > 0:
			categories_with_items += 1
	_trace["loop_categories_ms"] = (Time.get_ticks_usec() - _st_step) / 1000.0
	_st_step = Time.get_ticks_usec()
	var total_categories = purchasable_categories.size()
	_trace["total_categories_ms"] = (Time.get_ticks_usec() - _st_step) / 1000.0

	_st_step = Time.get_ticks_usec()
	var a = get_achievement_by_id(17)
	_trace["get_achievement_ms"] = (Time.get_ticks_usec() - _st_step) / 1000.0
	_st_step = Time.get_ticks_usec()
	if a != null and not a.get("unlocked", false):
		a.total = total_categories
		a.current = categories_with_items
		if categories_with_items == total_categories and total_categories > 0:
			_perform_unlock(a)
	_trace["unlock_check_ms"] = (Time.get_ticks_usec() - _st_step) / 1000.0
	_st_step = Time.get_ticks_usec()
	if save:
		save_achievements()
	_trace["save_ms"] = (Time.get_ticks_usec() - _st_step) / 1000.0 if save else 0.0
	_trace["total_ms"] = (Time.get_ticks_usec() - _st_total) / 1000.0
	print("[STYLE HUNTER TRACE]")
	for k in ["total_ms", "get_items_ms", "load_shop_ms", "loop_items_ms", "loop_categories_ms", "total_categories_ms", "get_achievement_ms", "unlock_check_ms", "save_ms"]:
		if _trace.has(k):
			print("  %-28s %.2f ms" % [k + ":", float(_trace[k])])
	var ge: Node = Engine.get_main_loop().root.get_node_or_null("GameEngine") if Engine.get_main_loop() and Engine.get_main_loop().root else null
	if ge and "_startup_trace" in ge:
		for kk in _trace.keys():
			ge._startup_trace["style_hunter_" + kk] = _trace[kk]

func _map_category_ru_to_internal(category_ru: String) -> String:
	match category_ru:
		"Кик": return "Kick"
		"Фоны": return "Backgrounds"
		"Подсветка линий": return "LaneHighlight"
		"Ноты": return "Notes"
		"Частицы хита": return "HitParticles"
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

	# Keep: game birthday + winter holidays. Other seasonal events retired.
	if day == 30 and month == 9:
		var a = get_achievement_by_id(47)
		if a != null and not a.get("unlocked", false):
			a.current = 1
			_perform_unlock(a)

	if month == 1 and day >= 1 and day <= 10:
		var b = get_achievement_by_id(48)
		if b != null and not b.get("unlocked", false):
			b.current = 1
			_perform_unlock(b)

	save_achievements()

## --- Calendar-event read-only diagnostics ----------------------------------
## Additive API for the `event.status` debug command. Pure queries only:
## no unlock, no save, no PlayerData writes, no state changes.
## NOTE: windows intentionally mirror check_event_achievements() above;
## do NOT refactor that function here.
const EVENT_GAME_BIRTHDAY_ID := 47
const EVENT_WINTER_JAM_ID := 48


static func get_event_date() -> Dictionary:
	return Time.get_date_dict_from_system()


static func get_calendar_event_ids() -> PackedInt32Array:
	return PackedInt32Array([EVENT_GAME_BIRTHDAY_ID, EVENT_WINTER_JAM_ID])


static func get_event_window(event_id: int, date: Dictionary) -> Dictionary:
	match event_id:
		EVENT_GAME_BIRTHDAY_ID:
			return {
				"start": "09-30",
				"end": "09-30",
				"active": int(date.get("month", 0)) == 9 and int(date.get("day", 0)) == 30,
			}
		EVENT_WINTER_JAM_ID:
			var month := int(date.get("month", 0))
			var day := int(date.get("day", 0))
			return {
				"start": "01-01",
				"end": "01-10",
				"active": month == 1 and day >= 1 and day <= 10,
			}
		_:
			return {
				"start": "",
				"end": "",
				"active": false,
			}

func check_collection_completed_achievement(player_data_mgr_override = null, save: bool = true):
	var _st_total := Time.get_ticks_usec()
	var _trace: Dictionary = {}
	var _st_step: int
	_st_step = Time.get_ticks_usec()
	var pdm = _get_pdm(player_data_mgr_override)
	_trace["get_pdm_ms"] = (Time.get_ticks_usec() - _st_step) / 1000.0
	_st_step = Time.get_ticks_usec()
	var shop_json_parse_result = _load_shop_json()
	_trace["load_shop_ms"] = (Time.get_ticks_usec() - _st_step) / 1000.0
	if not (shop_json_parse_result and shop_json_parse_result.has("items")):
		printerr("[AchievementManager] Ошибка парсинга shop_data.json или отсутствие ключа 'items'.")
		_trace["total_ms"] = (Time.get_ticks_usec() - _st_total) / 1000.0
		print("[COLLECTION TRACE] early exit")
		return

	_st_step = Time.get_ticks_usec()
	var purchasable_items = []
	for item in shop_json_parse_result.items:
		if item.get("price", 0) > 0: 
			purchasable_items.append(item)
	_trace["loop_purchasable_ms"] = (Time.get_ticks_usec() - _st_step) / 1000.0

	_st_step = Time.get_ticks_usec()
	var total_purchasable_items = purchasable_items.size() 
	_trace["total_purchasable_ms"] = (Time.get_ticks_usec() - _st_step) / 1000.0
	_st_step = Time.get_ticks_usec()
	var shop_item_ids = []
	var unlocked_item_ids = []
	var unlocked_purchasable_count = 0
	_trace["init_arrays_ms"] = (Time.get_ticks_usec() - _st_step) / 1000.0

	_st_step = Time.get_ticks_usec()
	if pdm:
		unlocked_item_ids = pdm.get_items()  
	_trace["get_items_ms"] = (Time.get_ticks_usec() - _st_step) / 1000.0

	_st_step = Time.get_ticks_usec()
	if pdm:
		for item in purchasable_items: 
			shop_item_ids.append(item.get("item_id", ""))
	_trace["loop_shop_ids_ms"] = (Time.get_ticks_usec() - _st_step) / 1000.0

	_st_step = Time.get_ticks_usec()
	var missing_items_count = 0
	for shop_id in shop_item_ids:
		if not unlocked_item_ids.has(shop_id): 
			missing_items_count += 1
		else:
			unlocked_purchasable_count += 1
	_trace["loop_missing_ms"] = (Time.get_ticks_usec() - _st_step) / 1000.0

	_st_step = Time.get_ticks_usec()
	var a = get_achievement_by_id(18)
	_trace["get_achievement_ms"] = (Time.get_ticks_usec() - _st_step) / 1000.0
	_st_step = Time.get_ticks_usec()
	if a != null and not a.get("unlocked", false):
		a.total = total_purchasable_items
		a.current = unlocked_purchasable_count
		if missing_items_count == 0:
			_perform_unlock(a)
	_trace["unlock_check_ms"] = (Time.get_ticks_usec() - _st_step) / 1000.0
	
	_st_step = Time.get_ticks_usec()
	if save:
		save_achievements()
	_trace["save_ms"] = (Time.get_ticks_usec() - _st_step) / 1000.0 if save else 0.0
	_trace["total_ms"] = (Time.get_ticks_usec() - _st_total) / 1000.0
	print("[COLLECTION TRACE]")
	for k in ["total_ms", "get_pdm_ms", "load_shop_ms", "loop_purchasable_ms", "total_purchasable_ms", "init_arrays_ms", "get_items_ms", "loop_shop_ids_ms", "loop_missing_ms", "get_achievement_ms", "unlock_check_ms", "save_ms"]:
		if _trace.has(k):
			print("  %-28s %.2f ms" % [k + ":", float(_trace[k])])
	var ge: Node = Engine.get_main_loop().root.get_node_or_null("GameEngine") if Engine.get_main_loop() and Engine.get_main_loop().root else null
	if ge and "_startup_trace" in ge:
		for kk in _trace.keys():
			ge._startup_trace["collection_" + kk] = _trace[kk]

func check_first_level_achievement():
	unlock_achievement_by_id(24)

func check_perfect_accuracy_achievement(accuracy: float):
	if accuracy >= 100.0:
		unlock_achievement_by_id(25)

func check_levels_completed_achievement(total_levels_completed: int):
	var ids = [26, 62, 64]
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
	var ids = [59, 61]
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
	
func check_accuracy_95_achievements(_player_data_mgr_override = null):
	# Retired: mastery id 66 (15× ≥95%).
	return


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
			
func check_first_bpm_achievement():
	for achievement in achievements:
		if achievement.id == 75 and not achievement.get("unlocked", false):
			_perform_unlock(achievement)
			break


func check_first_genre_analysis_achievement():
	for achievement in achievements:
		if achievement.id == 129 and not achievement.get("unlocked", false):
			_perform_unlock(achievement)
			break


func check_first_rhythm_dna_achievement() -> void:
	for achievement in achievements:
		if achievement.id == 141 and not achievement.get("unlocked", false):
			_perform_unlock(achievement)
			break


func check_genre_analysis_achievements(player_data_mgr_override = null):
	var pdm = _get_pdm(player_data_mgr_override)
	if not pdm or not pdm.has_method("get_generation_stats"):
		return
	var stats: Dictionary = pdm.get_generation_stats()
	_apply_modifier_counter(130, int(stats.get("genre_analyses", 0)))
	_apply_modifier_counter(131, int(stats.get("genre_from_server_pick", 0)))
	_apply_modifier_counter(132, int(stats.get("metadata_saves", 0)))
	save_achievements()
			
func check_cancel_analysis_achievement():
	for achievement in achievements:
		if achievement.id == 76 and not achievement.get("unlocked", false):
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
	pdm.data["bass_levels_completed"] = 0
	pdm.data["drum_perfect_hits_in_level"] = 0
	pdm.data["total_drum_perfect_hits"] = 0
	pdm.data["total_bass_perfect_hits"] = 0
	pdm.data["drum_dense_clears"] = 0
	pdm.data["max_drum_score_single_run"] = 0
	pdm.data["bass_ghost_hits_total"] = 0
	pdm.data["bass_multilane_hits_total"] = 0
	pdm.data["bass_perfect_holds_total"] = 0
	pdm.data["bass_clean_hold_clears"] = 0

	pdm._save()
	

func check_rhythm_master_achievement(total_notes_hit: int):
	var a = get_achievement_by_id(28)
	if a != null and not a.get("unlocked", false):
		a.current = total_notes_hit
		if total_notes_hit >= 1000:
			_perform_unlock(a)
		else:
			save_achievements()

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

	# Volume milestone: 25 levels only (id 67).
	var level_ach = get_achievement_by_id(67)
	if level_ach != null:
		var required = int(level_ach.get("total", 25))
		level_ach.current = total_drum_levels
		if total_drum_levels >= required and not level_ach.get("unlocked", false):
			_perform_unlock(level_ach)

	_progress_threshold_unlock(31, int(pdm.data.get("max_drum_combo_ever", 0)))
	_progress_threshold_unlock(32, int(pdm.data.get("max_drum_combo_ever", 0)))
	_progress_threshold_unlock(68, int(pdm.data.get("total_drum_perfect_hits", 0)))
	_progress_threshold_unlock(69, int(pdm.data.get("drum_dense_clears", 0)))
	_progress_threshold_unlock(173, int(pdm.data.get("max_drum_score_single_run", 0)))

func check_drum_storm_achievement(player_data_mgr_override = null):
	var pdm = player_data_mgr_override if player_data_mgr_override != null else player_data_mgr
	if not pdm:
		printerr("[AchievementManager] check_drum_storm_achievement: player_data_mgr не передан.")
		return
	_progress_threshold_unlock(31, int(pdm.data.get("max_drum_combo_ever", 0)))
	_progress_threshold_unlock(32, int(pdm.data.get("max_drum_combo_ever", 0)))

func check_bass_level_achievements(player_data_mgr_override = null, accuracy: float = 0.0, total_bass_levels: int = 0, is_bass_mode: bool = false):
	var pdm = _get_pdm(player_data_mgr_override)
	if not pdm:
		printerr("[AchievementManager] check_bass_level_achievements: player_data_mgr не передан.")
		return

	if is_bass_mode and total_bass_levels >= 1:
		for achievement in achievements:
			if achievement.id == 166 and not achievement.get("unlocked", false):
				_perform_unlock(achievement)
				break

	if is_bass_mode and accuracy >= 100.0:
		for achievement in achievements:
			if achievement.id == 167 and not achievement.get("unlocked", false):
				_perform_unlock(achievement)
				break

	var level_ach = get_achievement_by_id(170)
	if level_ach != null:
		var required = int(level_ach.get("total", 25))
		level_ach.current = total_bass_levels
		if total_bass_levels >= required and not level_ach.get("unlocked", false):
			_perform_unlock(level_ach)

	_progress_threshold_unlock(168, int(pdm.data.get("bass_clean_hold_clears", 0)))
	_progress_threshold_unlock(169, int(pdm.data.get("max_bass_combo_ever", 0)))
	_progress_threshold_unlock(171, int(pdm.data.get("bass_ghost_hits_total", 0)))
	_progress_threshold_unlock(172, int(pdm.data.get("bass_multilane_hits_total", 0)))
	_progress_threshold_unlock(174, int(pdm.data.get("bass_perfect_holds_total", 0)))

func check_bass_storm_achievement(player_data_mgr_override = null):
	var pdm = player_data_mgr_override if player_data_mgr_override != null else player_data_mgr
	if not pdm:
		printerr("[AchievementManager] check_bass_storm_achievement: player_data_mgr не передан.")
		return
	_progress_threshold_unlock(169, int(pdm.data.get("max_bass_combo_ever", 0)))


func _progress_threshold_unlock(ach_id: int, value: int) -> void:
	var achievement = get_achievement_by_id(ach_id)
	if achievement == null:
		return
	var required = int(achievement.get("total", 1))
	achievement.current = value
	if value >= required and not achievement.get("unlocked", false):
		_perform_unlock(achievement)

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

func _parse_play_time_to_seconds(time_formatted: String) -> int:
	var time_parts = time_formatted.split(":")
	if time_parts.size() == 2:
		return int(time_parts[0]) * 3600 + int(time_parts[1]) * 60
	if time_parts.size() == 3:
		return int(time_parts[0]) * 3600 + int(time_parts[1]) * 60 + int(time_parts[2])
	printerr("[AchievementManager] Неизвестный формат времени: ", time_formatted)
	return 0

func check_playtime_achievements(player_data_mgr_override = null):
	var pdm = _get_pdm(player_data_mgr_override)
	if not pdm:
		return

	var total_play_time_seconds = 0
	if pdm.has_method("get_total_play_time_seconds"):
		total_play_time_seconds = int(pdm.get_total_play_time_seconds())
	else:
		total_play_time_seconds = _parse_play_time_to_seconds(str(pdm.data.get("total_play_time", "00:00")))

	var total_play_time_hours = total_play_time_seconds / 3600.0
	var total_play_time_hours_rounded = roundf(total_play_time_hours * 100.0) / 100.0

	for achievement in achievements:
		if achievement.get("category", "") == "playtime":
			var required_hours = float(achievement.get("total", 0.0))
			achievement.current = total_play_time_hours_rounded
			if not achievement.get("unlocked", false):
				if total_play_time_hours_rounded >= required_hours:
					_perform_unlock(achievement)

	save_achievements()

func is_achievement_unlocked(achievement_id: int) -> bool:
	var a = get_achievement_by_id(achievement_id)
	return a != null and a.get("unlocked", false)

func _is_achievement_requirement_met(achievement: Dictionary) -> bool:
	if achievement.get("unlocked", false):
		return true
	var cur = float(achievement.get("current", 0.0))
	var tot = float(achievement.get("total", 1.0))
	return tot > 0.0 and cur >= tot

func sync_unlocked_achievements_to_player_data(silent: bool = false) -> void:
	if not player_data_mgr:
		return
	var prev_suppress := _suppress_unlock_notifications
	if silent:
		_suppress_unlock_notifications = true
	for achievement in achievements:
		var ach_id = int(achievement.get("id", -1))
		if ach_id < 0 or is_deprecated(achievement):
			continue
		if achievement.get("unlocked", false):
			player_data_mgr.unlock_achievement(ach_id)
		elif _is_achievement_requirement_met(achievement):
			unlock_achievement_by_id(ach_id)
	if silent:
		_suppress_unlock_notifications = prev_suppress
		new_mastery_achievements.clear()

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
	var ids = [39, 42]
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
	var ids = [43, 45]
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
	var ids = [1, 2, 3, 4]
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
	var user_path = "user://genre_groups.json"
	var path = user_path if FileAccess.file_exists(user_path) else "res://data/genre_groups.json"
	if not FileAccess.file_exists(path):
		printerr("[AchievementManager] Файл genre_groups.json не найден!")
		return

	var file = FileAccess.open(path, FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(json_text)
	if parsed is Dictionary:
		CatalogDataSync._cache_set(path, parsed)
	if not (parsed is Dictionary):
		printerr("[AchievementManager] Ошибка: genre_groups.json должен содержать объект (Dictionary)")
		return

	genre_group_map.clear()
	for group_name in parsed:
		var genres = parsed[group_name]
		if not (genres is Array):
			printerr("[AchievementManager] Группа %s должна содержать массив жанров" % group_name)
			continue
		for g in genres:
			if g is String:
				genre_group_map[g.to_lower()] = group_name
			else:
				printerr("[AchievementManager] Некорректный жанр в группе %s: %s" % [group_name, g])

	GenreSearch.enrich_group_map(genre_group_map)

func _map_canonical_genre_to_group(canonical_genre: String) -> String:
	if canonical_genre == "":
		return ""
	return genre_group_map.get(GenreSearch.normalize_canonical(canonical_genre), "")
	
const GENRE_PLAY_ACHIEVEMENT_GROUPS := {
	54: "edm",
	55: "rock",
	56: "rap",
	57: "indie_alt",
	58: "electronic",
	70: "pop",
	71: "classical_orchestral",
	72: "jazz",
	73: "world",
	74: "bass_music",
	77: "metal",
	78: "reggae_dub",
	79: "soul_funk",
	80: "folk_country",
	81: "latin",
}


func check_genre_achievements(track_stats_mgr = null):
	var tsm = track_stats_mgr if track_stats_mgr != null else TrackStatsManager
	if not tsm:
		printerr("[AchievementManager] TrackStatsManager недоступен")
		return

	var raw_counts = tsm.genre_play_counts

	var group_counts: Dictionary = {}
	for group_id in ProfileGenrePortrait.all_group_ids():
		group_counts[group_id] = 0

	for canonical_genre in raw_counts:
		var count = raw_counts[canonical_genre]
		var group = _map_canonical_genre_to_group(canonical_genre)
		if group != "" and group_counts.has(group):
			group_counts[group] += count

	for ach_id in GENRE_PLAY_ACHIEVEMENT_GROUPS:
		var group: String = GENRE_PLAY_ACHIEVEMENT_GROUPS[ach_id]
		var required = int(get_total_for(ach_id))
		var current = int(group_counts.get(group, 0))

		var achievement = get_achievement_by_id(ach_id)
		if achievement != null:
			achievement.current = current
			if current >= required and not achievement.get("unlocked", false):
				_perform_unlock(achievement)

	save_achievements()


func check_genre_mastery_achievements(track_stats_mgr = null) -> void:
	var tsm = track_stats_mgr if track_stats_mgr != null else TrackStatsManager
	if not tsm:
		return
	var best_level := ProfileGenreMastery.best_level_in_groups(tsm.genre_play_counts)
	var mastery_achievements := {
		118: 5,
		120: 10,
		122: 15,
		123: 20,
	}
	for ach_id in mastery_achievements:
		var required := int(mastery_achievements[ach_id])
		var achievement = get_achievement_by_id(ach_id)
		if achievement != null:
			achievement.current = best_level
			if best_level >= required and not achievement.get("unlocked", false):
				_perform_unlock(achievement)
	save_achievements()


func check_genre_collector_achievements(track_stats_mgr = null) -> void:
	var tsm = track_stats_mgr if track_stats_mgr != null else TrackStatsManager
	if not tsm:
		return
	var counts: Dictionary = tsm.genre_play_counts
	var total_discovered := ProfileGenreMastery.total_discovered(counts)
	var best_in_group := ProfileGenreMastery.best_group_discovered_count(counts)
	var full_groups := ProfileGenreMastery.groups_with_full_discovery(counts)
	var completed_small := ProfileGenreMastery.has_completed_small_group(counts)

	var global_targets := {
		134: 15,
		135: 30,
	}
	for ach_id in global_targets:
		var required := int(global_targets[ach_id])
		var achievement = get_achievement_by_id(ach_id)
		if achievement != null:
			achievement.current = total_discovered
			if total_discovered >= required and not achievement.get("unlocked", false):
				_perform_unlock(achievement)

	var group_five = get_achievement_by_id(138)
	if group_five != null:
		group_five.current = best_in_group
		if best_in_group >= int(group_five.get("total", 5)) and not group_five.get("unlocked", false):
			_perform_unlock(group_five)

	var small_group = get_achievement_by_id(139)
	if small_group != null:
		small_group.current = 1 if completed_small else 0
		if completed_small and not small_group.get("unlocked", false):
			_perform_unlock(small_group)

	var full_group = get_achievement_by_id(140)
	if full_group != null:
		full_group.current = full_groups
		if full_groups >= int(full_group.get("total", 1)) and not full_group.get("unlocked", false):
			_perform_unlock(full_group)

	save_achievements()


func check_rr_mastery_achievements() -> void:
	if not ProfileMilestonesManager:
		return
	var total_rr := ProfileMilestonesManager.get_total_rr_earned()
	var rr_achievements := {
		124: 1500,
		126: 15000,
		128: 50000,
	}
	for ach_id in rr_achievements:
		var required := int(rr_achievements[ach_id])
		var achievement = get_achievement_by_id(ach_id)
		if achievement != null:
			achievement.current = total_rr
			if total_rr >= required and not achievement.get("unlocked", false):
				_perform_unlock(achievement)
	save_achievements()


func check_modifier_achievements(player_data_mgr_override = null):
	var pdm = _get_pdm(player_data_mgr_override)
	if not pdm:
		return
	if not pdm.has_method("get_modifier_stats"):
		return
	var stats: Dictionary = pdm.get_modifier_stats()
	var any_clears := int(stats.get("clears_any", 0))
	var three_plus := int(stats.get("clears_3plus", 0))
	var hardcore := int(stats.get("clears_hardcore_triple", 0))

	_apply_modifier_counter(82, any_clears)
	_apply_modifier_counter(89, three_plus)
	_apply_modifier_counter(90, hardcore)
	_apply_modifier_counter(91, any_clears)
	_apply_modifier_counter(92, any_clears)
	_apply_modifier_counter(151, int(stats.get("clears_5plus", 0)))
	_apply_modifier_counter(175, int(stats.get("clears_cat_speed", 0)))
	_apply_modifier_counter(176, int(stats.get("clears_cat_visibility", 0)))
	_apply_modifier_counter(177, int(stats.get("clears_cat_timing", 0)))
	_apply_modifier_counter(178, int(stats.get("clears_cat_lanes", 0)))
	_apply_modifier_counter(179, int(stats.get("clears_cat_special", 0)))
	_apply_modifier_counter(180, int(stats.get("clears_cat_dna", 0)))
	save_achievements()


func check_generation_achievements(player_data_mgr_override = null):
	var pdm = _get_pdm(player_data_mgr_override)
	if not pdm or not pdm.has_method("get_generation_stats"):
		return
	var stats: Dictionary = pdm.get_generation_stats()
	_apply_modifier_counter(96, int(stats.get("notes_generated", 0)))
	_apply_modifier_counter(97, int(stats.get("bpm_computed", 0)))
	check_genre_analysis_achievements(pdm)
	save_achievements()


func check_medal_achievements():
	var stats: Dictionary = ResultsHistoryService.new().get_global_medal_stats()
	var total := int(stats.get("total_medal_count", 0))
	var full_sets := int(stats.get("tracks_with_full_set", 0))
	var ss_tracks := int(stats.get("tracks_with_ss_medal", 0))
	var hard_mode_tracks := int(stats.get("tracks_with_hard_mode_medal", 0))
	_apply_modifier_counter(102, total)
	_apply_modifier_counter(103, total)
	_apply_modifier_counter(105, total)
	_apply_modifier_counter(106, full_sets)
	_apply_modifier_counter(107, ss_tracks)
	_apply_modifier_counter(108, hard_mode_tracks)
	_apply_modifier_counter(115, full_sets)
	save_achievements()


func check_chart_difficulty_achievements(player_data_mgr_override = null):
	var pdm = _get_pdm(player_data_mgr_override)
	if not pdm or not pdm.has_method("get_chart_difficulty_stats"):
		return
	var stats: Dictionary = pdm.get_chart_difficulty_stats()
	var max_cleared := int(stats.get("max_cleared", 0))
	var clears_8_plus := int(stats.get("clears_8_plus", 0))
	_apply_modifier_counter(109, 1 if max_cleared >= 5 else 0)
	_apply_modifier_counter(112, 1 if max_cleared >= 10 else 0)
	_apply_modifier_counter(114, clears_8_plus)
	save_achievements()


func _apply_modifier_counter(ach_id: int, current: int):
	var achievement = get_achievement_by_id(ach_id)
	if achievement == null or is_deprecated(achievement):
		return
	achievement.current = current
	if current >= int(achievement.get("total", 1)) and not achievement.get("unlocked", false):
		_perform_unlock(achievement)


func check_endless_mode_unlocked() -> void:
	unlock_achievement_by_id(152)


func check_marathon_mode_unlocked() -> void:
	unlock_achievement_by_id(159)


func resync_marathon_achievements() -> void:
	const PlayModeIds = preload("res://logic/domain/session/play_mode_ids.gd")
	const MarathonSeason = preload("res://logic/domain/session/marathon_season.gd")
	const MarathonDailyRoute = preload("res://logic/domain/session/marathon_daily_route.gd")
	if player_data_mgr == null:
		return
	if player_data_mgr.has_method("is_play_mode_unlocked"):
		if player_data_mgr.is_play_mode_unlocked(PlayModeIds.ENDLESS):
			check_endless_mode_unlocked()
		if player_data_mgr.is_play_mode_unlocked(PlayModeIds.MARATHON):
			check_marathon_mode_unlocked()
	if player_data_mgr.has_method("get_marathon_courses_completed_count"):
		_apply_modifier_counter(161, player_data_mgr.get_marathon_courses_completed_count())
		if player_data_mgr.get_marathon_courses_completed_count() > 0:
			unlock_achievement_by_id(160)
	var completions: Variant = player_data_mgr.data.get("marathon_completions", {})
	if not completions is Dictionary:
		return
	for route_id in completions.keys():
		var entry: Variant = completions[route_id]
		if entry is not Dictionary or float((entry as Dictionary).get("best_ratio", 0.0)) < 0.999:
			continue
		var rid := str(route_id)
		if MarathonDailyRoute.is_daily_route(rid):
			unlock_achievement_by_id(162)
		var aid := MarathonSeason.archetype_id_from_route_id(rid)
		match aid:
			"boss_rush":
				unlock_achievement_by_id(163)
			"weekly":
				unlock_achievement_by_id(164)
			"ultimate":
				unlock_achievement_by_id(165)


func check_marathon_run_achievements(summary: Dictionary, player_data_mgr_override = null) -> void:
	const MarathonSeason = preload("res://logic/domain/session/marathon_season.gd")
	const MarathonDailyRoute = preload("res://logic/domain/session/marathon_daily_route.gd")
	var pdm = player_data_mgr_override if player_data_mgr_override != null else player_data_mgr
	if pdm == null or summary is not Dictionary:
		return
	if str(summary.get("reason", "")) != "victory":
		return
	unlock_achievement_by_id(160)
	if pdm.has_method("get_marathon_courses_completed_count"):
		_apply_modifier_counter(161, pdm.get_marathon_courses_completed_count())
	var route_id := str(summary.get("route_id", "")).strip_edges()
	if MarathonDailyRoute.is_daily_route(route_id):
		unlock_achievement_by_id(162)
	var aid := MarathonSeason.archetype_id_from_route_id(route_id)
	match aid:
		"boss_rush":
			unlock_achievement_by_id(163)
		"journey", "weekly":
			unlock_achievement_by_id(164)
		"ultimate":
			unlock_achievement_by_id(165)


func check_endless_run_achievements(summary: Dictionary, player_data_mgr_override = null) -> void:
	var pdm = player_data_mgr_override if player_data_mgr_override != null else player_data_mgr
	if pdm == null or summary is not Dictionary:
		return
	var streak := maxi(0, int(summary.get("streak", 0)))
	if streak >= 1:
		unlock_achievement_by_id(153)
	var best_streak := streak
	if pdm.has_method("get_endless_best_streak"):
		best_streak = maxi(streak, pdm.get_endless_best_streak())
	for ach_id in [154, 155]:
		var achievement = get_achievement_by_id(ach_id)
		if achievement == null:
			continue
		var old := int(achievement.get("current", 0))
		achievement.current = maxi(old, streak)
		if streak >= int(achievement.get("total", 1)) and not achievement.get("unlocked", false):
			_perform_unlock(achievement)
		elif old != achievement.current and not achievement.get("unlocked", false):
			save_achievements()
	for streak_ach_id in [156, 157]:
		var streak_ach = get_achievement_by_id(streak_ach_id)
		if streak_ach == null:
			continue
		var prev := int(streak_ach.get("current", 0))
		streak_ach.current = maxi(prev, best_streak)
		if best_streak >= int(streak_ach.get("total", 1)) and not streak_ach.get("unlocked", false):
			_perform_unlock(streak_ach)
		elif prev != streak_ach.current and not streak_ach.get("unlocked", false):
			save_achievements()
	if bool(summary.get("flawless_series", false)) and streak >= 3:
		unlock_achievement_by_id(158)
