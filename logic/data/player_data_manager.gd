# logic/player_data_manager.gd
extends Node

const RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const PlayModeIds = preload("res://logic/domain/session/play_mode_ids.gd")

const DEFAULT_MODIFIER_STATS := {
	"clears_any": 0,
	"clears_hidden": 0,
	"clears_sudden": 0,
	"clears_sudden_death": 0,
	"clears_no_miss_forgiveness": 0,
	"clears_strict_timing": 0,
	"clears_2plus": 0,
	"clears_3plus": 0,
	"clears_4plus": 0,
	"clears_5plus": 0,
	"clears_hardcore_triple": 0,
	"clears_memory_mode": 0,
	"clears_dynamic_lanes": 0,
	"clears_lane_remap": 0,
	"clears_combo_escalation": 0,
	"clears_metronome_only": 0,
	"clears_reverse_scroll": 0,
	"clears_time_warp": 0,
	"clears_pick_mode": 0,
}

const DEFAULT_GENERATION_STATS := {
	"notes_generated": 0,
	"bpm_computed": 0,
	"analysis_cancelled": 0,
	"genre_analyses": 0,
	"genre_from_server_pick": 0,
	"metadata_saves": 0,
}
const DEFAULT_CHART_DIFFICULTY_STATS := {
	"clears_count": 0,
	"rating_sum": 0,
	"max_cleared": 0,
	"clears_6_plus": 0,
	"clears_8_plus": 0,
}

signal active_item_changed(category: String, item_id: String)

const PLAYER_DATA_PATH = "user://player_data.json" 
const TRACK_STATS_PATH = "user://track_stats.json"
const MAX_LEVEL := 100
const INT64_MAX := 9223372036854775807
const CURRENCY_CAP := 9999999999

const DEFAULT_ACTIVE_ITEMS = {
	"Kick": "kick_default",
	"Backgrounds": "background_default",
	"LaneHighlight": "lanes_highlight_default",
	"Notes": "notes_default",
	"HitParticles": "particles_default",
}

const DEFAULT_UNLOCKED_ITEMS = [
	"kick_default",
	"lanes_highlight_default",
	"notes_default",
	"particles_default",
]

const LEGACY_COVER_ITEM_IDS := [
	"covers_default",
	"covers_geometric",
	"covers_flowing_lines",
	"covers_music_note",
	"covers_ink_splash",
	"covers_vinyl",
	"covers_spiderweb",
	"covers_explosion",
	"covers_shards",
	"covers_cross",
	"covers_brush",
	"covers_falling_blocks",
	"pixel_amp",
	"covers_shatter",
	"covers_marble_flow",
]

var data: Dictionary = {
	"currency": 0,
	"unlocked_item_ids": PackedStringArray(),  
	"active_items": DEFAULT_ACTIVE_ITEMS.duplicate(true), 
	"unlocked_achievement_ids": PackedInt32Array(),  
	"spent_currency": 0,
	"total_earned_currency": 0,
	"last_login_date": "",
	"login_streak": 0,
	"best_login_streak": 0,
	"levels_completed": 0,
	"drum_levels_completed": 0,      
	"total_drum_perfect_hits": 0,   
	"total_perfect_hits": 0,
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
	"favorite_track_play_count": 0,
	"favorite_song_paths": PackedStringArray(),
	"favorite_genre": "unknown",
	"daily_quests": {
		"date": "",
		"quests": []
	},
	"daily_quests_completed_total": 0,
	"last_daily_quest_completion": {},
	"last_chart_generation": {},
	"profile_created_date": "",
	"seen_shop_reward_item_ids": PackedStringArray(),
	"shop_reward_notifications_initialized": false,
	"spent_medals": 0,
	"modifier_stats": DEFAULT_MODIFIER_STATS.duplicate(true),
	"generation_stats": DEFAULT_GENERATION_STATS.duplicate(true),
	"chart_difficulty_stats": DEFAULT_CHART_DIFFICULTY_STATS.duplicate(true),
	"unlocked_play_modes": PackedStringArray([PlayModeIds.LIBRARY]),
	"endless_best_streak": 0,
	"endless_session_last": {},
	"endless_stats": {
		"total_runs": 0,
		"total_tracks_cleared": 0,
		"total_notes_hit": 0,
		"best_series_rr": 0,
		"best_avg_accuracy": 0.0,
		"last_run": {},
		"history": [],
	},
	"marathon_completions": {},
}

signal total_play_time_changed(new_time_formatted: String)
signal level_changed(new_level: int, new_xp: int, xp_for_next_level: int)  
signal daily_quests_updated()
signal calendar_day_changed(new_date: String)
signal profile_statistics_reset()
signal shop_new_rewards_changed()
signal favorite_songs_changed()

var _total_play_time_seconds: int = 0

var achievement_manager = null
var game_engine_reference = null
var delayed_achievements: Array[Dictionary] = []
var daily_quests_mgr = null
var _save_pending: bool = false
var _save_timer = null
const SAVE_DEBOUNCE_SECONDS: float = 1.0
const MIN_MIDNIGHT_TIMER_SECONDS: float = 1.0
var _playtime_minutes_buffer_seconds: int = 0
var _tracked_calendar_date: String = ""
var _midnight_rollover_timer: Timer = null


func _ready():
	_load()
	call_deferred("_maybe_rebuild_chart_difficulty_stats_from_results")
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

	daily_quests_mgr = preload("res://logic/data/daily_quests_manager.gd").new()
	daily_quests_mgr.set_player_data_manager(self)
	daily_quests_mgr.daily_quests_updated.connect(func():
		emit_signal("daily_quests_updated")
		emit_signal("shop_new_rewards_changed")
	)

	var default_items = DEFAULT_UNLOCKED_ITEMS
	var items_changed = false
	for item_id in default_items:
		if not data["unlocked_item_ids"].has(item_id):   
			data["unlocked_item_ids"].append(item_id)
			items_changed = true
	if items_changed:
		_save() 
	ensure_shop_reward_notifications_migrated()
	_ensure_play_modes_data()
	_setup_calendar_day_watcher()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		sync_calendar_day_if_needed()

func _setup_calendar_day_watcher() -> void:
	_tracked_calendar_date = Time.get_date_string_from_system()
	sync_calendar_day_if_needed()
	_schedule_midnight_rollover()

func _schedule_midnight_rollover() -> void:
	if _midnight_rollover_timer == null:
		_midnight_rollover_timer = Timer.new()
		_midnight_rollover_timer.one_shot = true
		_midnight_rollover_timer.timeout.connect(_on_midnight_rollover_timer)
		add_child(_midnight_rollover_timer)
	_midnight_rollover_timer.wait_time = _seconds_until_next_local_midnight()
	_midnight_rollover_timer.start()

func _seconds_until_next_local_midnight() -> float:
	var now_dict := Time.get_datetime_dict_from_system()
	var today_start := Time.get_unix_time_from_datetime_dict({
		"year": now_dict.year,
		"month": now_dict.month,
		"day": now_dict.day,
		"hour": 0,
		"minute": 0,
		"second": 0,
	})
	var elapsed_today := Time.get_unix_time_from_system() - today_start
	return maxf(MIN_MIDNIGHT_TIMER_SECONDS, 86400.0 - float(elapsed_today))

func _on_midnight_rollover_timer() -> void:
	sync_calendar_day_if_needed()
	_schedule_midnight_rollover()

func sync_calendar_day_if_needed() -> void:
	var today := Time.get_date_string_from_system()
	var quests_date := str(data.get("daily_quests", {}).get("date", ""))
	if today != _tracked_calendar_date:
		apply_calendar_day_rollover(today)
		return
	if quests_date != today:
		ensure_daily_quests_for_today()

func apply_calendar_day_rollover(new_date: String = "") -> void:
	if new_date == "":
		new_date = Time.get_date_string_from_system()
	_tracked_calendar_date = new_date
	ensure_daily_quests_for_today()
	apply_daily_login_for_today()
	emit_signal("calendar_day_changed", new_date)

func apply_daily_login_for_today() -> void:
	var today_str := Time.get_date_string_from_system()
	var last_login_str := str(data.get("last_login_date", ""))
	if last_login_str == today_str:
		return
	var login_streak := int(data.get("login_streak", 0))
	var new_streak := 1
	if last_login_str != "":
		var last_login_dict := _parse_date_string(last_login_str)
		if not last_login_dict.is_empty() and _is_yesterday_date(last_login_dict, today_str):
			new_streak = login_streak + 1
	set_login_streak(new_streak)

func _parse_date_string(date_str: String) -> Dictionary:
	var parts := date_str.split("-")
	if parts.size() != 3:
		return {}
	return {
		"year": parts[0].to_int(),
		"month": parts[1].to_int(),
		"day": parts[2].to_int(),
	}

func _is_yesterday_date(date_dict: Dictionary, today_str: String) -> bool:
	var today_parts := today_str.split("-")
	if today_parts.size() != 3:
		return false
	var today_year := today_parts[0].to_int()
	var today_month := today_parts[1].to_int()
	var today_day := today_parts[2].to_int()
	return date_dict.get("year", -1) == today_year \
		and date_dict.get("month", -1) == today_month \
		and date_dict.get("day", -1) == (today_day - 1)

func ensure_shop_reward_notifications_migrated(shop_items: Array = []) -> void:
	if data.get("shop_reward_notifications_initialized", false):
		return
	if shop_items.is_empty():
		shop_items = ShopRewardNotifications.load_shop_items()
	for item in shop_items:
		if not (item is Dictionary):
			continue
		if not ShopRewardNotifications.is_reward_available(item):
			continue
		var item_id := str(item.get("item_id", ""))
		if item_id != "" and not data["seen_shop_reward_item_ids"].has(item_id):
			data["seen_shop_reward_item_ids"].append(item_id)
	data["shop_reward_notifications_initialized"] = true
	_save()

func get_unseen_shop_reward_ids(shop_items: Array = []) -> PackedStringArray:
	ensure_shop_reward_notifications_migrated(shop_items)
	if shop_items.is_empty():
		shop_items = ShopRewardNotifications.load_shop_items()
	var unseen := PackedStringArray()
	for item in shop_items:
		if not (item is Dictionary):
			continue
		if not ShopRewardNotifications.is_reward_available(item):
			continue
		var item_id := str(item.get("item_id", ""))
		if item_id == "":
			continue
		if not data["seen_shop_reward_item_ids"].has(item_id):
			unseen.append(item_id)
	return unseen

func get_unseen_shop_reward_count(shop_items: Array = []) -> int:
	return get_unseen_shop_reward_ids(shop_items).size()

func get_unseen_shop_reward_count_for_category(category: String, shop_items: Array = []) -> int:
	category = category.strip_edges()
	if category == "" or category == "Все":
		return get_unseen_shop_reward_count(shop_items)
	if shop_items.is_empty():
		shop_items = ShopRewardNotifications.load_shop_items()
	var unseen_ids := get_unseen_shop_reward_ids(shop_items)
	var count := 0
	for item in shop_items:
		if not (item is Dictionary):
			continue
		var item_id := str(item.get("item_id", ""))
		if item_id == "" or not unseen_ids.has(item_id):
			continue
		if str(item.get("category", "")) == category:
			count += 1
	return count

func is_shop_reward_unseen(item_id: String, shop_items: Array = []) -> bool:
	item_id = item_id.strip_edges()
	if item_id == "":
		return false
	return get_unseen_shop_reward_ids(shop_items).has(item_id)

func _normalize_song_path(path: String) -> String:
	return String(path).replace("\\", "/").strip_edges()


func _normalize_favorite_song_paths(paths: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	var seen: Dictionary = {}
	for raw in paths:
		var path := _normalize_song_path(String(raw))
		if path == "" or seen.has(path):
			continue
		seen[path] = true
		out.append(path)
	return out


func _ensure_favorite_song_paths() -> void:
	if not data.has("favorite_song_paths") or not (data["favorite_song_paths"] is PackedStringArray):
		data["favorite_song_paths"] = PackedStringArray()


func is_song_favorite(path: String) -> bool:
	path = _normalize_song_path(path)
	if path == "":
		return false
	_ensure_favorite_song_paths()
	return data["favorite_song_paths"].has(path)


func toggle_song_favorite(path: String) -> bool:
	path = _normalize_song_path(path)
	if path == "":
		return false
	_ensure_favorite_song_paths()
	var paths: PackedStringArray = data["favorite_song_paths"]
	var idx := paths.find(path)
	var now_favorite := false
	if idx >= 0:
		paths.remove_at(idx)
	else:
		paths.append(path)
		now_favorite = true
	data["favorite_song_paths"] = _normalize_favorite_song_paths(paths)
	_save()
	emit_signal("favorite_songs_changed")
	return now_favorite


func remove_favorite_song(path: String) -> void:
	path = _normalize_song_path(path)
	if path == "":
		return
	_ensure_favorite_song_paths()
	var paths: PackedStringArray = data["favorite_song_paths"]
	var idx := paths.find(path)
	if idx < 0:
		return
	paths.remove_at(idx)
	data["favorite_song_paths"] = paths
	_save()
	emit_signal("favorite_songs_changed")


func mark_shop_reward_seen(item_id: String) -> void:
	item_id = item_id.strip_edges()
	if item_id == "":
		return
	ensure_shop_reward_notifications_migrated()
	if data["seen_shop_reward_item_ids"].has(item_id):
		return
	data["seen_shop_reward_item_ids"].append(item_id)
	_save()
	emit_signal("shop_new_rewards_changed")

func _load():
	var json_result: Dictionary = JsonUtils.read_json_dict(PLAYER_DATA_PATH)
	if json_result is Dictionary and not json_result.is_empty():
		var loaded_currency = int(json_result.get("currency", 0))
		var loaded_unlocked_item_ids = _to_packed_string_array(json_result.get("unlocked_item_ids", PackedStringArray()))
		var loaded_active_items = json_result.get("active_items", {})
		var loaded_last_login = json_result.get("last_login_date", "")
		var loaded_login_streak = int(json_result.get("login_streak", 0))
		var loaded_best_login_streak = int(json_result.get("best_login_streak", loaded_login_streak))
		var loaded_unlocked_achievement_ids = _to_packed_int_array(json_result.get("unlocked_achievement_ids", PackedInt32Array()))
		var loaded_spent_currency = int(json_result.get("spent_currency", 0))
		var loaded_total_earned_currency = int(json_result.get("total_earned_currency", 0))
		var loaded_levels_completed = int(json_result.get("levels_completed", 0))
		var loaded_drum_levels_completed = int(json_result.get("drum_levels_completed", 0))
		var loaded_total_drum_perfect_hits = int(json_result.get("total_drum_perfect_hits", 0))
		var loaded_total_perfect_hits = int(json_result.get("total_perfect_hits", 0))
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
		var loaded_favorite_song_paths = _to_packed_string_array(json_result.get("favorite_song_paths", PackedStringArray()))
		var loaded_favorite_genre = json_result.get("favorite_genre", "unknown")
		var loaded_grades = json_result.get("grades", {
			"SS": 0,
			"S": 0,
			"A": 0,
			"B": 0,
			"C": 0,
			"D": 0,
			"F": 0
		})
		var loaded_daily_quests = json_result.get("daily_quests", {"date": "", "quests": []})
		var loaded_daily_quests_completed_total = int(json_result.get("daily_quests_completed_total", 0))
		var loaded_last_daily_quest_completion = json_result.get("last_daily_quest_completion", {})
		var loaded_last_chart_generation = json_result.get("last_chart_generation", {})
		var loaded_seen_shop_reward_item_ids = _to_packed_string_array(json_result.get("seen_shop_reward_item_ids", PackedStringArray()))
		var loaded_shop_reward_notifications_initialized = bool(json_result.get("shop_reward_notifications_initialized", false))
		
		
		data["currency"] = clamp(loaded_currency, 0, CURRENCY_CAP)
		data["unlocked_item_ids"] = loaded_unlocked_item_ids 
		data["unlocked_achievement_ids"] = loaded_unlocked_achievement_ids 
		data["spent_currency"] = max(0, loaded_spent_currency)
		data["total_earned_currency"] = max(0, loaded_total_earned_currency)
		data["levels_completed"] = loaded_levels_completed
		data["drum_levels_completed"] = loaded_drum_levels_completed
		data["total_drum_perfect_hits"] = loaded_total_drum_perfect_hits
		data["total_perfect_hits"] = loaded_total_perfect_hits
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
		data["total_xp"] = max(0, loaded_total_xp)
		data["current_level"] = loaded_current_level
		data["xp_for_next_level"] = max(1, loaded_xp_for_next_level)

		data["favorite_track"] = loaded_favorite_track
		data["favorite_track_play_count"] = loaded_favorite_track_play_count
		data["favorite_song_paths"] = _normalize_favorite_song_paths(loaded_favorite_song_paths)
		data["favorite_genre"] = loaded_favorite_genre
		data["daily_quests"] = loaded_daily_quests
		data["daily_quests_completed_total"] = loaded_daily_quests_completed_total
		if loaded_last_daily_quest_completion is Dictionary:
			data["last_daily_quest_completion"] = loaded_last_daily_quest_completion.duplicate(true)
		else:
			data["last_daily_quest_completion"] = {}
		if loaded_last_chart_generation is Dictionary:
			data["last_chart_generation"] = loaded_last_chart_generation.duplicate(true)
		else:
			data["last_chart_generation"] = {}
		data["seen_shop_reward_item_ids"] = loaded_seen_shop_reward_item_ids
		data["shop_reward_notifications_initialized"] = loaded_shop_reward_notifications_initialized
		_ensure_modifier_stats()
		if json_result.get("modifier_stats") is Dictionary:
			for key in DEFAULT_MODIFIER_STATS:
				data["modifier_stats"][key] = int(json_result["modifier_stats"].get(key, DEFAULT_MODIFIER_STATS[key]))
		_ensure_generation_stats()
		if json_result.get("generation_stats") is Dictionary:
			for key in DEFAULT_GENERATION_STATS:
				data["generation_stats"][key] = int(json_result["generation_stats"].get(key, DEFAULT_GENERATION_STATS[key]))
		_ensure_chart_difficulty_stats()
		if json_result.get("chart_difficulty_stats") is Dictionary:
			for key in DEFAULT_CHART_DIFFICULTY_STATS:
				data["chart_difficulty_stats"][key] = int(json_result["chart_difficulty_stats"].get(key, DEFAULT_CHART_DIFFICULTY_STATS[key]))
		_ensure_play_modes_data()
		if json_result.get("unlocked_play_modes") != null:
			data["unlocked_play_modes"] = _to_packed_string_array(json_result.get("unlocked_play_modes", PackedStringArray()))
		data["endless_best_streak"] = maxi(0, int(json_result.get("endless_best_streak", data.get("endless_best_streak", 0))))
		if json_result.get("endless_session_last") is Dictionary:
			data["endless_session_last"] = json_result["endless_session_last"].duplicate(true)
		if json_result.get("endless_stats") is Dictionary:
			data["endless_stats"] = json_result["endless_stats"].duplicate(true)
		if json_result.get("marathon_completions") is Dictionary:
			data["marathon_completions"] = json_result["marathon_completions"].duplicate(true)
		
		data["last_login_date"] = loaded_last_login
		data["login_streak"] = loaded_login_streak
		data["best_login_streak"] = maxi(loaded_best_login_streak, loaded_login_streak)
		
		var loaded_profile_created_date = str(json_result.get("profile_created_date", ""))
		if loaded_profile_created_date == "":
			if loaded_last_login != "":
				data["profile_created_date"] = loaded_last_login
			else:
				data["profile_created_date"] = Time.get_date_string_from_system()
			_save()
		else:
			data["profile_created_date"] = loaded_profile_created_date
		
		var loaded_active_items_dict = loaded_active_items.duplicate(true)
		for category in DEFAULT_ACTIVE_ITEMS:
			var loaded_value = loaded_active_items_dict.get(category, DEFAULT_ACTIVE_ITEMS[category])
			if loaded_value == null:
				loaded_value = DEFAULT_ACTIVE_ITEMS[category]
			data["active_items"][category] = loaded_value
		for category in loaded_active_items_dict:
			if category == "Covers":
				continue
			if not DEFAULT_ACTIVE_ITEMS.has(category):
				data["active_items"][category] = loaded_active_items_dict[category]
		
		_purge_legacy_cover_shop_data()
		
		if data["current_level"] > MAX_LEVEL:
			data["current_level"] = MAX_LEVEL
		_calculate_xp_for_next_level()
		data["total_xp"] = min(data["total_xp"], data["xp_for_next_level"])
	else:
		printerr("PlayerDataManager.gd: player_data.json не найден или пуст — инициализация по умолчанию: ", PLAYER_DATA_PATH)
		data["profile_created_date"] = Time.get_date_string_from_system()
		_save() 

	if TrackStatsManager and TrackStatsManager.has_method("get_best_grades_map"):
		data["best_grades_per_track"] = TrackStatsManager.get_best_grades_map()

func _save():
	_schedule_save()

func flush_save():
	_write_to_disk()

func _schedule_save():
	if _save_pending:
		return
	_save_pending = true
	if is_inside_tree():
		_save_timer = get_tree().create_timer(SAVE_DEBOUNCE_SECONDS)
		if _save_timer:
			_save_timer.timeout.connect(_on_save_timer_timeout)
	else:
		_write_to_disk()

func _on_save_timer_timeout():
	_write_to_disk()

func _is_legacy_cover_item_id(item_id: String) -> bool:
	var normalized := str(item_id).strip_edges()
	if normalized == "":
		return false
	if normalized in LEGACY_COVER_ITEM_IDS:
		return true
	return normalized.begins_with("covers_")


func _purge_legacy_cover_shop_data() -> void:
	data["active_items"].erase("Covers")
	var filtered_unlocked := PackedStringArray()
	for item_id in data.get("unlocked_item_ids", PackedStringArray()):
		if _is_legacy_cover_item_id(str(item_id)):
			continue
		filtered_unlocked.append(str(item_id))
	data["unlocked_item_ids"] = filtered_unlocked


func _write_to_disk():
	_save_pending = false
	_purge_legacy_cover_shop_data()
	var active_items_clean = {}
	for category in DEFAULT_ACTIVE_ITEMS:
		var current_value = data["active_items"].get(category)
		active_items_clean[category] = current_value
	data["active_items"] = active_items_clean

	var data_to_save = data.duplicate(true)
	data_to_save.erase("best_grades_per_track")

	JsonUtils.write_json(PLAYER_DATA_PATH, data_to_save, true, true)

func _save_best_grades():
	if TrackStatsManager and TrackStatsManager.has_method("get_best_grades_map"):
		data["best_grades_per_track"] = TrackStatsManager.get_best_grades_map()

func get_currency() -> int:
	return int(data.get("currency", 0))

func set_game_engine_reference(engine):
	game_engine_reference = engine
func add_delayed_achievement(achievement_data: Dictionary):
	delayed_achievements.append(achievement_data)

func get_and_clear_delayed_achievements() -> Array[Dictionary]:
	var achievements = delayed_achievements.duplicate()
	delayed_achievements.clear()
	
	return achievements

func add_currency(amount: int):
	var old_currency = int(data.get("currency", 0))
	var new_currency = _saturating_add_nonneg(old_currency, amount, CURRENCY_CAP)
	data["currency"] = new_currency 

	if amount < 0:
		var spent_amount = abs(amount)
		var old_spent = int(data.get("spent_currency", 0))
		data["spent_currency"] = _saturating_add_nonneg(old_spent, spent_amount, INT64_MAX)
		_trigger_currency_achievement_check()
	elif amount > 0:
		var old_earned = int(data.get("total_earned_currency", 0))
		data["total_earned_currency"] = _saturating_add_nonneg(old_earned, amount, INT64_MAX)
		_trigger_currency_achievement_check()

	_save()

func _trigger_currency_achievement_check():
	pass

func add_perfect_hits(count: int):
	if count <= 0:
		return
	var current_perfect = int(data.get("total_perfect_hits", 0))
	var new_total = current_perfect + count
	data["total_perfect_hits"] = new_total
	_save()
	_trigger_perfect_hit_achievement_check()
	increment_daily_progress("perfect_hits", count, {})

func _trigger_perfect_hit_achievement_check():
	pass

func xp_for_level(level: int) -> int:
	if level <= 1:
		return 100
	var capped_level = min(level, MAX_LEVEL)
	return int(100 * pow(1.10, capped_level - 1))

func _calculate_xp_for_next_level():
	if data["current_level"] >= MAX_LEVEL:
		data["xp_for_next_level"] = xp_for_level(MAX_LEVEL)
	else:
		data["xp_for_next_level"] = xp_for_level(data["current_level"] + 1)

func add_xp(amount: int):
	if amount <= 0:
		return
	var summed = _saturating_add_nonneg(int(data.get("total_xp", 0)), amount, INT64_MAX)
	data["total_xp"] = summed
	if data["current_level"] >= MAX_LEVEL:
		data["total_xp"] = min(data["total_xp"], data["xp_for_next_level"])
		emit_signal("level_changed", data["current_level"], data["total_xp"], data["xp_for_next_level"])
		_save()
		return
	var leveled_up = check_level_up()
	if not leveled_up:
		emit_signal("level_changed", data["current_level"], data["total_xp"], data["xp_for_next_level"])
		_save()

func check_level_up() -> bool:
	if data["current_level"] >= MAX_LEVEL:
		data["total_xp"] = min(data["total_xp"], data["xp_for_next_level"])
		return false
	var leveled: bool = false
	while data["total_xp"] >= data["xp_for_next_level"] and data["current_level"] < MAX_LEVEL:
		var required = data["xp_for_next_level"]
		var remainder = data["total_xp"] - required
		data["current_level"] += 1
		var new_level = data["current_level"]
		data["total_xp"] = int(remainder * 0.2)
		_calculate_xp_for_next_level()
		leveled = true
		
		emit_signal("level_changed", new_level, data["total_xp"], data["xp_for_next_level"])
		emit_signal("shop_new_rewards_changed")
		increment_daily_progress("profile_level_up", 1, {})
		_save()
	if data["current_level"] >= MAX_LEVEL and data["total_xp"] > data["xp_for_next_level"]:
		data["total_xp"] = data["xp_for_next_level"]
	return leveled

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


func get_xp_remaining_to_next_level() -> int:
	if get_current_level() >= MAX_LEVEL:
		return 0
	return maxi(0, get_xp_for_next_level() - get_total_xp())


func get_days_in_rhythmfall() -> int:
	var created := str(data.get("profile_created_date", "")).strip_edges()
	if created.length() < 10:
		return 1
	var created_ts := TimeUtils.unix_from_local_iso_datetime("%s 12:00:00" % created.substr(0, 10))
	var today_ts := TimeUtils.unix_from_local_iso_datetime(
		"%s 12:00:00" % Time.get_date_string_from_system()
	)
	if created_ts <= 0 or today_ts <= 0:
		return 1
	return maxi(1, int((today_ts - created_ts) / 86400) + 1)


func get_items() -> PackedStringArray:
	return data.get("unlocked_item_ids", PackedStringArray()).duplicate()  

func unlock_item(item_name: String):
	if not data["unlocked_item_ids"].has(item_name):
		data["unlocked_item_ids"].append(item_name)  
		_trigger_purchase_achievement_check()
		_save()

func _trigger_purchase_achievement_check():
	pass

func _to_packed_string_array(value):
	if value is PackedStringArray:
		return value
	if value is Array:
		return PackedStringArray(value)
	return PackedStringArray()

func _to_packed_int_array(value):
	if value is PackedInt32Array:
		return value
	if value is Array:
		return PackedInt32Array(value)
	return PackedInt32Array()

func _saturating_add_nonneg(base: int, delta: int, cap: int) -> int:
	var b = max(0, base)
	if delta > 0:
		var room = cap - b
		if delta > room:
			return cap
		return b + delta
	elif delta < 0:
		var take = -delta
		if take > b:
			return 0
		return b - take
	else:
		return b

func is_item_unlocked(item_name: String) -> bool:
	return data["unlocked_item_ids"].has(item_name)


func _ensure_play_modes_data() -> void:
	if not data.has("unlocked_play_modes"):
		data["unlocked_play_modes"] = PackedStringArray([PlayModeIds.LIBRARY])
	var modes: PackedStringArray = _to_packed_string_array(data.get("unlocked_play_modes", PackedStringArray()))
	if not modes.has(PlayModeIds.LIBRARY):
		modes.append(PlayModeIds.LIBRARY)
	data["unlocked_play_modes"] = modes
	if not data.has("endless_best_streak"):
		data["endless_best_streak"] = 0
	if not data.has("endless_session_last") or not data["endless_session_last"] is Dictionary:
		data["endless_session_last"] = {}
	_ensure_endless_stats()
	if not data.has("marathon_completions") or not data["marathon_completions"] is Dictionary:
		data["marathon_completions"] = {}


func _ensure_endless_stats() -> void:
	if not data.has("endless_stats") or not data["endless_stats"] is Dictionary:
		data["endless_stats"] = {
			"total_runs": 0,
			"total_tracks_cleared": 0,
			"total_notes_hit": 0,
			"best_series_rr": 0,
			"best_avg_accuracy": 0.0,
			"last_run": {},
			"history": [],
		}
		return
	var stats: Dictionary = data["endless_stats"]
	if not stats.has("history") or not stats["history"] is Array:
		stats["history"] = []
	if not stats.has("last_run") or not stats["last_run"] is Dictionary:
		stats["last_run"] = {}
	data["endless_stats"] = stats


func get_endless_stats() -> Dictionary:
	_ensure_play_modes_data()
	var raw: Variant = data.get("endless_stats", {})
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


func record_endless_run(summary: Dictionary) -> Dictionary:
	_ensure_play_modes_data()
	var stats: Dictionary = data["endless_stats"]
	var streak := maxi(0, int(summary.get("streak", 0)))
	var series_rr := maxi(0, int(summary.get("series_rr", 0)))
	var avg_acc := maxf(0.0, float(summary.get("average_accuracy", 0.0)))
	var notes_hit := maxi(0, int(summary.get("total_hit_notes", 0)))
	var now_iso := Time.get_datetime_string_from_system(true)

	stats["total_runs"] = maxi(0, int(stats.get("total_runs", 0))) + 1
	stats["total_tracks_cleared"] = maxi(0, int(stats.get("total_tracks_cleared", 0))) + streak
	stats["total_notes_hit"] = maxi(0, int(stats.get("total_notes_hit", 0))) + notes_hit

	var best_rr_updated := false
	var best_acc_updated := false
	if series_rr > int(stats.get("best_series_rr", 0)):
		stats["best_series_rr"] = series_rr
		best_rr_updated = true
	if streak > 0 and avg_acc > float(stats.get("best_avg_accuracy", 0.0)) + 0.0001:
		stats["best_avg_accuracy"] = avg_acc
		best_acc_updated = true

	var last_run := {
		"date": now_iso,
		"reason": str(summary.get("reason", "")),
		"streak": streak,
		"series_rr": series_rr,
		"average_accuracy": avg_acc,
		"total_hit_notes": notes_hit,
		"earned_xp": int(summary.get("earned_xp", 0)),
		"earned_currency": int(summary.get("earned_currency", 0)),
		"config": summary.get("config", {}),
	}
	stats["last_run"] = last_run

	var history: Array = stats.get("history", [])
	if not history is Array:
		history = []
	history.insert(0, last_run.duplicate(true))
	while history.size() > 10:
		history.pop_back()
	stats["history"] = history
	data["endless_stats"] = stats
	_save()

	return {
		"best_series_rr_updated": best_rr_updated,
		"best_avg_accuracy_updated": best_acc_updated,
	}


func is_play_mode_unlocked(mode_id: String) -> bool:
	_ensure_play_modes_data()
	if mode_id == PlayModeIds.LIBRARY:
		return true
	return data["unlocked_play_modes"].has(mode_id)


func unlock_play_mode(mode_id: String) -> void:
	_ensure_play_modes_data()
	if mode_id == PlayModeIds.LIBRARY or is_play_mode_unlocked(mode_id):
		return
	data["unlocked_play_modes"].append(mode_id)
	_save()
	if mode_id == PlayModeIds.ENDLESS and achievement_manager != null:
		if achievement_manager.has_method("check_endless_mode_unlocked"):
			achievement_manager.check_endless_mode_unlocked()


func meets_play_mode_unlock_requirements(mode_id: String) -> bool:
	if is_play_mode_unlocked(mode_id):
		return false
	var req: Dictionary = PlayModeIds.unlock_requirements_for(mode_id)
	if req.is_empty():
		return false
	return (
		get_current_level() >= int(req.get("min_level", 999))
		and get_total_medals_earned() >= int(req.get("min_medals", 999))
		and get_currency() >= int(req.get("diamond_cost", 0))
	)


func can_unlock_play_mode_free(mode_id: String) -> bool:
	return meets_play_mode_unlock_requirements(mode_id)


func try_unlock_play_mode_with_diamonds(mode_id: String) -> bool:
	if is_play_mode_unlocked(mode_id):
		return true
	if not meets_play_mode_unlock_requirements(mode_id):
		return false
	var req: Dictionary = PlayModeIds.unlock_requirements_for(mode_id)
	if req.is_empty():
		return false
	var cost: int = maxi(0, int(req.get("diamond_cost", 0)))
	if cost > 0:
		add_currency(-cost)
	unlock_play_mode(mode_id)
	return true


func get_endless_best_streak() -> int:
	_ensure_play_modes_data()
	return maxi(0, int(data.get("endless_best_streak", 0)))


func update_endless_best_streak(streak: int) -> bool:
	_ensure_play_modes_data()
	var normalized := maxi(0, streak)
	var best := get_endless_best_streak()
	if normalized <= best:
		return false
	data["endless_best_streak"] = normalized
	_save()
	return true


func grant_endless_run_rewards(xp: int, currency: int) -> void:
	if xp > 0:
		add_xp(xp)
	if currency > 0:
		add_currency(currency)
	flush_save()


func get_endless_session_last() -> Dictionary:
	_ensure_play_modes_data()
	var raw: Variant = data.get("endless_session_last", {})
	return raw if raw is Dictionary else {}


func save_endless_session_last(config: Dictionary) -> void:
	_ensure_play_modes_data()
	const EndlessSessionConfig = preload("res://logic/domain/session/endless_session_config.gd")
	data["endless_session_last"] = EndlessSessionConfig.sanitize(config)
	_save()


func get_marathon_courses_total_count() -> int:
	# Placeholder until marathon_routes.json catalog is wired in.
	return 0


func get_marathon_courses_completed_count() -> int:
	_ensure_play_modes_data()
	var completions: Variant = data.get("marathon_completions", {})
	if not completions is Dictionary:
		return 0
	var count := 0
	for course_id in completions.keys():
		var entry: Variant = completions[course_id]
		if entry is Dictionary and float(entry.get("best_ratio", 0.0)) >= 0.999:
			count += 1
	return count


func get_spent_medals() -> int:
	return maxi(0, int(data.get("spent_medals", 0)))


func get_total_medals_earned() -> int:
	var stats: Dictionary = ResultsHistoryService.new().get_global_medal_stats()
	return int(stats.get("total_medal_count", 0))


func get_available_medals() -> int:
	return get_total_medals_earned()


func spend_medals(amount: int) -> bool:
	var cost := maxi(0, amount)
	if get_available_medals() < cost:
		return false
	data["spent_medals"] = get_spent_medals() + cost
	_save()
	return true


func set_active_item(category: String, item_id: String):
	if data["active_items"].has(category):
		var old_item_id = data["active_items"][category]
		data["active_items"][category] = item_id
		_save()
		emit_signal("active_item_changed", category, item_id)

func get_active_item(category: String) -> String:
	var active_item_id = data["active_items"].get(category)
	if active_item_id == null:
		var default_item = DEFAULT_ACTIVE_ITEMS.get(category, "")
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
	return active_items_copy

func get_save_data() -> Dictionary:
	var save_dict = data.duplicate(true)
	return save_dict

func load_save_data(save_dict: Dictionary):
	if save_dict.has("currency"):
		data["currency"] = int(save_dict["currency"])
	if save_dict.has("unlocked_item_ids"):
		data["unlocked_item_ids"] = _to_packed_string_array(save_dict["unlocked_item_ids"])
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
			printerr("PlayerDataManager.gd: load_save_data: Поле 'active_items' не является словарём, пропускаем.")
	if save_dict.has("unlocked_achievement_ids"): 
		data["unlocked_achievement_ids"] = _to_packed_int_array(save_dict["unlocked_achievement_ids"])
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
	if save_dict.has("best_login_streak"):
		data["best_login_streak"] = int(save_dict["best_login_streak"])
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
	if save_dict.has("unlocked_play_modes"):
		data["unlocked_play_modes"] = _to_packed_string_array(save_dict["unlocked_play_modes"])
	if save_dict.has("endless_best_streak"):
		data["endless_best_streak"] = maxi(0, int(save_dict["endless_best_streak"]))
	if save_dict.has("endless_session_last") and save_dict["endless_session_last"] is Dictionary:
		data["endless_session_last"] = save_dict["endless_session_last"].duplicate(true)
	if save_dict.has("endless_stats") and save_dict["endless_stats"] is Dictionary:
		data["endless_stats"] = save_dict["endless_stats"].duplicate(true)
	if save_dict.has("marathon_completions") and save_dict["marathon_completions"] is Dictionary:
		data["marathon_completions"] = save_dict["marathon_completions"].duplicate(true)
	_ensure_play_modes_data()
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
	data["best_login_streak"] = 0
	data["levels_completed"] = 0
	data["daily_quests_completed_total"] = 0
	data["modifier_stats"] = DEFAULT_MODIFIER_STATS.duplicate(true)
	data["generation_stats"] = DEFAULT_GENERATION_STATS.duplicate(true)
	data["chart_difficulty_stats"] = DEFAULT_CHART_DIFFICULTY_STATS.duplicate(true)

	data["currency"] = current_currency 
	data["active_items"] = current_active_items

	_save()
	data["best_grades_per_track"] = {}
	_save_best_grades()
	

func reset_profile_statistics():
	var default_items = DEFAULT_UNLOCKED_ITEMS

	data["levels_completed"] = 0
	data["drum_levels_completed"] = 0
	data["total_drum_perfect_hits"] = 0
	data["total_perfect_hits"] = 0
	data["total_notes_hit"] = 0
	data["total_notes_missed"] = 0
	data["max_combo_ever"] = 0
	data["max_drum_combo_ever"] = 0
	data["total_drum_hits"] = 0
	data["total_drum_misses"] = 0
	data["total_score_ever"] = 0
	data["total_drum_score_ever"] = 0
	data["currency"] = 0
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
	data["favorite_genre"] = "unknown"
	data["daily_quests_completed_total"] = 0
	data["daily_quests"] = {"date": "", "quests": []}
	data["modifier_stats"] = DEFAULT_MODIFIER_STATS.duplicate(true)
	data["generation_stats"] = DEFAULT_GENERATION_STATS.duplicate(true)
	data["chart_difficulty_stats"] = DEFAULT_CHART_DIFFICULTY_STATS.duplicate(true)
	data["profile_created_date"] = Time.get_date_string_from_system()
	
	data["total_xp"] = 0
	data["current_level"] = 1
	data["xp_for_next_level"] = 100

	_total_play_time_seconds = 0

	data["unlocked_item_ids"] = PackedStringArray(default_items)
	data["active_items"] = DEFAULT_ACTIVE_ITEMS.duplicate(true)
	data["unlocked_achievement_ids"] = PackedInt32Array()
	
	_save()
	for category in DEFAULT_ACTIVE_ITEMS:
		var def_id = DEFAULT_ACTIVE_ITEMS[category]
		if def_id != null and def_id is String and def_id != "":
			set_active_item(category, def_id)
	data["best_grades_per_track"] = {}
	_save_best_grades()
	if achievement_manager and achievement_manager.has_method("reset_achievements"):
		achievement_manager.reset_achievements()
	var svc = null
	if game_engine_reference and game_engine_reference.has_method("get_results_history_service"):
		svc = game_engine_reference.get_results_history_service()
	elif game_engine_reference and game_engine_reference.has_method("get_session_history_manager"):
		svc = game_engine_reference.get_session_history_manager()
	if svc and svc.has_method("clear_history"):
		svc.clear_history()
	if game_engine_reference and game_engine_reference.has_method("on_currency_changed"):
		game_engine_reference.on_currency_changed()
	emit_signal("level_changed", data["current_level"], data["total_xp"], data["xp_for_next_level"])
	emit_signal("total_play_time_changed", data.get("total_play_time", "00:00"))
	emit_signal("profile_statistics_reset")

func get_login_streak() -> int:
	return int(data.get("login_streak", 0))

func get_best_login_streak() -> int:
	return maxi(int(data.get("best_login_streak", 0)), get_login_streak())

func _touch_best_login_streak() -> void:
	var cur := get_login_streak()
	data["best_login_streak"] = maxi(int(data.get("best_login_streak", 0)), cur)

func set_login_streak(streak: int) -> void:
	data["login_streak"] = int(streak)
	data["last_login_date"] = Time.get_date_string_from_system()
	_touch_best_login_streak()
	_save()
	_trigger_login_achievement_check()

func increment_login_streak() -> void:
	data["login_streak"] = int(data.get("login_streak", 0)) + 1
	data["last_login_date"] = Time.get_date_string_from_system()
	_touch_best_login_streak()
	_save()
	_trigger_login_achievement_check()

func reset_login_streak() -> void:
	data["login_streak"] = 0
	data["best_login_streak"] = 0
	data["last_login_date"] = ""
	_save()

func _trigger_login_achievement_check():
	pass

func unlock_achievement(achievement_id: int) -> void:
	if not data["unlocked_achievement_ids"].has(achievement_id):  
		data["unlocked_achievement_ids"].append(achievement_id) 
		_save()
		emit_signal("shop_new_rewards_changed")

func is_achievement_unlocked(achievement_id: int) -> bool:
	if data["unlocked_achievement_ids"].has(achievement_id):
		return true
	if achievement_manager:
		var a = achievement_manager.get_achievement_by_id(achievement_id)
		if a == null:
			return false
		if a.get("unlocked", false):
			unlock_achievement(achievement_id)
			return true
		var cur = float(a.get("current", 0.0))
		var tot = float(a.get("total", 1.0))
		if tot > 0.0 and cur >= tot:
			achievement_manager.unlock_achievement_by_id(achievement_id)
			return data["unlocked_achievement_ids"].has(achievement_id)
	return false

func add_completed_level():
	var current_count = int(data.get("levels_completed", 0))
	var new_count = current_count + 1
	data["levels_completed"] = new_count
	_save()
	

func _trigger_level_achievement_check():
	pass

func get_levels_completed() -> int:
	return int(data.get("levels_completed", 0))
	
func get_unique_levels_completed() -> int:
	return data.get("best_grades_per_track", {}).size()
	
func add_drum_level_completed():
	var current_count = int(data.get("drum_levels_completed", 0))
	var new_count = current_count + 1
	data["drum_levels_completed"] = new_count
	_save()
	

func get_drum_levels_completed() -> int:
	return int(data.get("drum_levels_completed", 0))

func get_chart_difficulty_stats() -> Dictionary:
	_ensure_chart_difficulty_stats()
	var stats: Variant = data.get("chart_difficulty_stats", {})
	if stats is Dictionary:
		return stats.duplicate(true)
	return DEFAULT_CHART_DIFFICULTY_STATS.duplicate(true)

func record_chart_difficulty_clear(rating: int) -> void:
	_ensure_chart_difficulty_stats()
	var value := clampi(rating, 0, ChartDifficultyAnalyzer.MAX_RATING)
	if value <= 0:
		return
	var stats: Dictionary = data["chart_difficulty_stats"]
	stats["clears_count"] = int(stats.get("clears_count", 0)) + 1
	stats["rating_sum"] = int(stats.get("rating_sum", 0)) + value
	stats["max_cleared"] = maxi(int(stats.get("max_cleared", 0)), value)
	if value >= 6:
		stats["clears_6_plus"] = int(stats.get("clears_6_plus", 0)) + 1
	if value >= 8:
		stats["clears_8_plus"] = int(stats.get("clears_8_plus", 0)) + 1
	data["chart_difficulty_stats"] = stats
	_save()

func get_average_chart_difficulty_cleared() -> float:
	var stats := get_chart_difficulty_stats()
	var count := int(stats.get("clears_count", 0))
	if count <= 0:
		return 0.0
	return float(int(stats.get("rating_sum", 0))) / float(count)


func _maybe_rebuild_chart_difficulty_stats_from_results() -> void:
	_ensure_chart_difficulty_stats()
	if int(data["chart_difficulty_stats"].get("clears_count", 0)) > 0:
		return
	if not DirAccess.dir_exists_absolute("user://results"):
		return
	var song_paths_by_basename: Dictionary = {}
	if SongLibrary and SongLibrary.has_method("get_songs_list"):
		for song in SongLibrary.get_songs_list():
			if song is Dictionary:
				var song_path := str(song.get("path", ""))
				if song_path != "":
					song_paths_by_basename[song_path.get_file().get_basename()] = song_path
	var dir := DirAccess.open("user://results")
	if dir == null:
		return
	var rebuilt: Dictionary = DEFAULT_CHART_DIFFICULTY_STATS.duplicate(true)
	for file_name in dir.get_files():
		if not file_name.ends_with("_results.json"):
			continue
		var basename := file_name.trim_suffix("_results.json")
		var song_path := str(song_paths_by_basename.get(basename, ""))
		if song_path == "":
			continue
		var raw: Variant = JsonUtils.read_json("user://results/" + file_name)
		if not raw is Dictionary:
			continue
		var results: Array = raw.get("results", [])
		for result in results:
			if not result is Dictionary:
				continue
			var instrument := _chart_instrument_from_result(str(result.get("instrument", "")))
			var mode := str(result.get("mode", "basic"))
			if mode == "":
				mode = "basic"
			var rating := ChartDifficultyAnalyzer.get_run_rating(song_path, instrument, mode, 4)
			if rating <= 0:
				continue
			rebuilt["clears_count"] = int(rebuilt.get("clears_count", 0)) + 1
			rebuilt["rating_sum"] = int(rebuilt.get("rating_sum", 0)) + rating
			rebuilt["max_cleared"] = maxi(int(rebuilt.get("max_cleared", 0)), rating)
			if rating >= 6:
				rebuilt["clears_6_plus"] = int(rebuilt.get("clears_6_plus", 0)) + 1
			if rating >= 8:
				rebuilt["clears_8_plus"] = int(rebuilt.get("clears_8_plus", 0)) + 1
	if int(rebuilt.get("clears_count", 0)) <= 0:
		return
	data["chart_difficulty_stats"] = rebuilt
	_save()


func _chart_instrument_from_result(result_instrument: String) -> String:
	if result_instrument == "Перкуссия":
		return "drums"
	if result_instrument == "":
		return "standard"
	return result_instrument

func add_total_drum_perfect_hit():
	add_total_drum_perfect_hits(1)


func add_total_drum_perfect_hits(count: int):
	if count <= 0:
		return
	var current_total = int(data.get("total_drum_perfect_hits", 0))
	data["total_drum_perfect_hits"] = current_total + count
	_save()
	increment_daily_progress("drum_perfect_hits", count, {})

func add_hit_notes(count: int):
	if count <= 0:
		return
	var current_hits = int(data.get("total_notes_hit", 0))
	data["total_notes_hit"] = current_hits + count
	_save() 

func add_missed_notes(count: int):
	if count <= 0:
		return
	var current_misses = int(data.get("total_notes_missed", 0))
	data["total_notes_missed"] = current_misses + count
	_save() 

func get_total_notes_hit() -> int:
	return int(data.get("total_notes_hit", 0))

func get_total_perfect_hits() -> int:
	return int(data.get("total_perfect_hits", 0))

func get_total_notes_missed() -> int:
	return int(data.get("total_notes_missed", 0))

func get_total_notes_played() -> int: 
	return get_total_notes_hit() + get_total_notes_missed()

func add_score_to_total(score: int, is_drum_mode: bool = false):
	if score <= 0:
		return
	var current_total = int(data.get("total_score_ever", 0))
	var new_total = current_total + score
	data["total_score_ever"] = new_total
	
	if is_drum_mode:
		var current_drum_total = int(data.get("total_drum_score_ever", 0))
		var new_drum_total = current_drum_total + score
		data["total_drum_score_ever"] = new_drum_total
	
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
	if seconds_to_add <= 0:
		return
	_total_play_time_seconds += seconds_to_add
	var new_time_string = _play_time_seconds_to_string(_total_play_time_seconds)
	data["total_play_time"] = new_time_string
	emit_signal("total_play_time_changed", new_time_string)
	_playtime_minutes_buffer_seconds += seconds_to_add
	if _playtime_minutes_buffer_seconds >= 60:
		var add_minutes = int(_playtime_minutes_buffer_seconds / 60)
		_playtime_minutes_buffer_seconds = _playtime_minutes_buffer_seconds % 60
		if add_minutes > 0:
			increment_daily_progress("playtime_minutes", add_minutes, {})
			_save()

func get_total_play_time_formatted() -> String:
	return data.get("total_play_time", "00:00")

func get_total_play_time_seconds() -> int:
	return _total_play_time_seconds

func ensure_daily_quests_for_today():
	if daily_quests_mgr:
		daily_quests_mgr.ensure_daily_quests_for_today()
		# Forensic fix 2026-09-12: recover from corrupted state where date==today but quests==[] (see C:\Users\kolbi\AppData\Roaming\RhythmFall_1.2.0_restore\player_data.json).
		# Original 1.2.0 only checked date != today, so empty quests with matching date persisted forever and UI stayed hidden.
		var dq = data.get("daily_quests", {})
		var qs = dq.get("quests", [])
		if dq.get("date", "") != Time.get_date_string_from_system() or not qs is Array or qs.size() != 3:
			# Already handled date!=today via mgr, but handle empty/corrupted quests with matching date.
			if qs is Array and qs.size() == 3:
				return
			daily_quests_mgr._generate_daily_quests_for_date(Time.get_date_string_from_system())
			_save()
			emit_signal("daily_quests_updated")

func _generate_daily_quests_for_date(date_str: String):
	if daily_quests_mgr:
		daily_quests_mgr._generate_daily_quests_for_date(date_str)

func get_daily_quests() -> Array:
	if daily_quests_mgr:
		return daily_quests_mgr.get_daily_quests()
	return []


func _ensure_modifier_stats() -> void:
	if not data.get("modifier_stats") is Dictionary:
		data["modifier_stats"] = DEFAULT_MODIFIER_STATS.duplicate(true)
		return
	for key in DEFAULT_MODIFIER_STATS:
		if not data["modifier_stats"].has(key):
			data["modifier_stats"][key] = DEFAULT_MODIFIER_STATS[key]


func get_modifier_stats() -> Dictionary:
	_ensure_modifier_stats()
	return data["modifier_stats"].duplicate(true)


func record_modifier_victory(run_modifiers: Array) -> void:
	var mods := RunModifiers.sanitize(run_modifiers)
	if RunModifiers.has_modifier(mods, RunModifiers.ID_AUTOPLAY):
		return
	var challenge_count := 0
	for mod_id in mods:
		if mod_id != RunModifiers.ID_AUTOPLAY:
			challenge_count += 1
	if challenge_count <= 0:
		return

	_ensure_modifier_stats()
	var stats: Dictionary = data["modifier_stats"]
	stats["clears_any"] = int(stats.get("clears_any", 0)) + 1
	if RunModifiers.has_modifier(mods, RunModifiers.ID_HIDDEN):
		stats["clears_hidden"] = int(stats.get("clears_hidden", 0)) + 1
	if RunModifiers.has_modifier(mods, RunModifiers.ID_SUDDEN):
		stats["clears_sudden"] = int(stats.get("clears_sudden", 0)) + 1
	if RunModifiers.has_modifier(mods, RunModifiers.ID_SUDDEN_DEATH):
		stats["clears_sudden_death"] = int(stats.get("clears_sudden_death", 0)) + 1
	if RunModifiers.has_modifier(mods, RunModifiers.ID_NO_MISS_FORGIVENESS):
		stats["clears_no_miss_forgiveness"] = int(stats.get("clears_no_miss_forgiveness", 0)) + 1
	if RunModifiers.has_modifier(mods, RunModifiers.ID_STRICT_TIMING):
		stats["clears_strict_timing"] = int(stats.get("clears_strict_timing", 0)) + 1
	if challenge_count >= 2:
		stats["clears_2plus"] = int(stats.get("clears_2plus", 0)) + 1
	if challenge_count >= 3:
		stats["clears_3plus"] = int(stats.get("clears_3plus", 0)) + 1
	if challenge_count >= 4:
		stats["clears_4plus"] = int(stats.get("clears_4plus", 0)) + 1
	if challenge_count >= 5:
		stats["clears_5plus"] = int(stats.get("clears_5plus", 0)) + 1
	if RunModifiers.has_modifier(mods, RunModifiers.ID_MEMORY_MODE):
		stats["clears_memory_mode"] = int(stats.get("clears_memory_mode", 0)) + 1
	if RunModifiers.has_modifier(mods, RunModifiers.ID_DYNAMIC_LANES):
		stats["clears_dynamic_lanes"] = int(stats.get("clears_dynamic_lanes", 0)) + 1
	if (
		RunModifiers.has_modifier(mods, RunModifiers.ID_MIRROR_MODE)
		or RunModifiers.has_modifier(mods, RunModifiers.ID_SHUFFLE_MODE)
		or RunModifiers.has_modifier(mods, RunModifiers.ID_RANDOM_MODE)
	):
		stats["clears_lane_remap"] = int(stats.get("clears_lane_remap", 0)) + 1
	if RunModifiers.has_modifier(mods, RunModifiers.ID_COMBO_ESCALATION):
		stats["clears_combo_escalation"] = int(stats.get("clears_combo_escalation", 0)) + 1
	if RunModifiers.has_modifier(mods, RunModifiers.ID_METRONOME_ONLY):
		stats["clears_metronome_only"] = int(stats.get("clears_metronome_only", 0)) + 1
	if RunModifiers.has_modifier(mods, RunModifiers.ID_REVERSE_SCROLL):
		stats["clears_reverse_scroll"] = int(stats.get("clears_reverse_scroll", 0)) + 1
	if RunModifiers.has_modifier(mods, RunModifiers.ID_TIME_WARP):
		stats["clears_time_warp"] = int(stats.get("clears_time_warp", 0)) + 1
	if RunModifiers.has_modifier(mods, RunModifiers.ID_PICK_MODE):
		stats["clears_pick_mode"] = int(stats.get("clears_pick_mode", 0)) + 1
	if (
		RunModifiers.has_modifier(mods, RunModifiers.ID_STRICT_TIMING)
		and RunModifiers.has_modifier(mods, RunModifiers.ID_NO_MISS_FORGIVENESS)
		and RunModifiers.has_modifier(mods, RunModifiers.ID_SUDDEN_DEATH)
	):
		stats["clears_hardcore_triple"] = int(stats.get("clears_hardcore_triple", 0)) + 1
	data["modifier_stats"] = stats

	var dq_context := {
		"hidden": RunModifiers.has_modifier(mods, RunModifiers.ID_HIDDEN),
		"sudden_death": RunModifiers.has_modifier(mods, RunModifiers.ID_SUDDEN_DEATH),
		"challenge_count": challenge_count,
	}
	increment_daily_progress("modifier_clear", 1, dq_context)
	if dq_context["hidden"]:
		increment_daily_progress("modifier_clear_hidden", 1, dq_context)
	if dq_context["sudden_death"]:
		increment_daily_progress("modifier_clear_sd", 1, dq_context)
	if challenge_count >= 2:
		increment_daily_progress("modifier_clear_2plus", 1, dq_context)
	_save()


func _ensure_generation_stats() -> void:
	if not data.get("generation_stats") is Dictionary:
		data["generation_stats"] = DEFAULT_GENERATION_STATS.duplicate(true)
		return
	for key in DEFAULT_GENERATION_STATS:
		if not data["generation_stats"].has(key):
			data["generation_stats"][key] = DEFAULT_GENERATION_STATS[key]


func _ensure_chart_difficulty_stats() -> void:
	if not data.get("chart_difficulty_stats") is Dictionary:
		data["chart_difficulty_stats"] = DEFAULT_CHART_DIFFICULTY_STATS.duplicate(true)
		return
	for key in DEFAULT_CHART_DIFFICULTY_STATS:
		if not data["chart_difficulty_stats"].has(key):
			data["chart_difficulty_stats"][key] = DEFAULT_CHART_DIFFICULTY_STATS[key]


func get_generation_stats() -> Dictionary:
	_ensure_generation_stats()
	return data["generation_stats"].duplicate(true)


func record_notes_generated() -> void:
	_ensure_generation_stats()
	var stats: Dictionary = data["generation_stats"]
	stats["notes_generated"] = int(stats.get("notes_generated", 0)) + 1
	data["generation_stats"] = stats
	_save()


func record_last_chart_generation(
	song_path: String,
	instrument: String,
	mode: String,
	lanes: int,
	title: String = "",
	artist: String = ""
) -> void:
	song_path = song_path.strip_edges()
	if song_path == "":
		return
	var display := SongLibrary.get_display_metadata_for_song(song_path) if SongLibrary else {}
	var title_text := title.strip_edges()
	var artist_text := artist.strip_edges()
	if title_text == "":
		title_text = str(display.get("title", "")).strip_edges()
	if artist_text == "":
		artist_text = str(display.get("artist", "")).strip_edges()
	data["last_chart_generation"] = {
		"song_path": song_path,
		"title": title_text,
		"artist": artist_text,
		"instrument": instrument.strip_edges(),
		"mode": mode.strip_edges(),
		"lanes": maxi(lanes, 1),
		"completed_at": TimeUtils.now_local_datetime_string(),
	}
	_save()


func record_bpm_computed() -> void:
	_ensure_generation_stats()
	var stats: Dictionary = data["generation_stats"]
	stats["bpm_computed"] = int(stats.get("bpm_computed", 0)) + 1
	data["generation_stats"] = stats
	_save()


func record_analysis_cancelled() -> void:
	_ensure_generation_stats()
	var stats: Dictionary = data["generation_stats"]
	stats["analysis_cancelled"] = int(stats.get("analysis_cancelled", 0)) + 1
	data["generation_stats"] = stats
	_save()


func record_genre_analyzed() -> void:
	_ensure_generation_stats()
	var stats: Dictionary = data["generation_stats"]
	stats["genre_analyses"] = int(stats.get("genre_analyses", 0)) + 1
	data["generation_stats"] = stats
	_save()


func record_genre_from_server_pick() -> void:
	_ensure_generation_stats()
	var stats: Dictionary = data["generation_stats"]
	stats["genre_from_server_pick"] = int(stats.get("genre_from_server_pick", 0)) + 1
	data["generation_stats"] = stats
	_save()


func record_metadata_saved() -> void:
	_ensure_generation_stats()
	var stats: Dictionary = data["generation_stats"]
	stats["metadata_saves"] = int(stats.get("metadata_saves", 0)) + 1
	data["generation_stats"] = stats
	_save()


func increment_daily_progress(event_name: String, value: int, context: Dictionary = {}):
	if daily_quests_mgr:
		daily_quests_mgr.increment_daily_progress(event_name, value, context)

func _add_daily_quest_reward(amount: int):
	if daily_quests_mgr:
		daily_quests_mgr._add_daily_quest_reward(amount)

func get_daily_quests_completed_total() -> int:
	if daily_quests_mgr:
		return daily_quests_mgr.get_daily_quests_completed_total()
	return 0

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

		if TrackStatsManager and TrackStatsManager.has_method("set_best_grade_for_track"):
			TrackStatsManager.set_best_grade_for_track(song_path, new_grade)
		_save()

func add_bass_clean_hold_clear() -> void:
	data["bass_clean_hold_clears"] = int(data.get("bass_clean_hold_clears", 0)) + 1
	_save()



func add_bass_ghost_hits(count: int) -> void:
	if count <= 0:
		return
	data["bass_ghost_hits_total"] = int(data.get("bass_ghost_hits_total", 0)) + count
	_save()



func add_bass_level_completed():
	var current_count = int(data.get("bass_levels_completed", 0))
	var new_count = current_count + 1
	data["bass_levels_completed"] = new_count
	_save()


func add_bass_multilane_hits(count: int) -> void:
	if count <= 0:
		return
	data["bass_multilane_hits_total"] = int(data.get("bass_multilane_hits_total", 0)) + count
	_save()



func add_bass_perfect_holds(count: int) -> void:
	if count <= 0:
		return
	data["bass_perfect_holds_total"] = int(data.get("bass_perfect_holds_total", 0)) + count
	_save()



func add_drum_dense_clear() -> void:
	data["drum_dense_clears"] = int(data.get("drum_dense_clears", 0)) + 1
	_save()



func delete_playlist(playlist_id: String) -> bool:
	_ensure_play_modes_data()
	var pid := str(playlist_id).strip_edges()
	if pid == "":
		return false
	var playlists: Array = []
	var removed := false
	for raw in get_user_playlists():
		if raw is not Dictionary:
			continue
		var existing := raw as Dictionary
		if str(existing.get("id", "")).strip_edges() == pid:
			removed = true
			continue
		playlists.append(existing.duplicate(true))
	if not removed:
		return false
	data["user_playlists"] = playlists
	_save()
	return true



func get_bass_levels_completed() -> int:
	return int(data.get("bass_levels_completed", 0))


func get_marathon_session_last(route_id: String) -> Dictionary:
	_ensure_play_modes_data()
	const MarathonRouteCatalog = preload("res://logic/domain/session/marathon_route_catalog.gd")
	var rid := str(route_id).strip_edges()
	if rid == "":
		return {}
	var all: Variant = data.get("marathon_session_last", {})
	if not all is Dictionary:
		return {}
	var raw: Variant = all.get(rid, {})
	if raw is Dictionary and not (raw as Dictionary).is_empty():
		return (raw as Dictionary).duplicate(true)
	# Legacy key: genre group id from old saves.
	var group_id := MarathonRouteCatalog.genre_group_for_route(rid)
	if group_id != "":
		raw = all.get(group_id, {})
		if raw is Dictionary:
			return (raw as Dictionary).duplicate(true)
	return {}



func get_user_playlists() -> Array:
	_ensure_play_modes_data()
	var raw: Variant = data.get("user_playlists", [])
	if not raw is Array:
		return []
	return (raw as Array).duplicate(true)



func grant_marathon_run_rewards(xp: int, currency: int) -> void:
	grant_endless_run_rewards(xp, currency)



func playlist_by_id(playlist_id: String) -> Dictionary:
	var pid := str(playlist_id).strip_edges()
	if pid == "":
		return {}
	for raw in get_user_playlists():
		if raw is not Dictionary:
			continue
		var entry := raw as Dictionary
		if str(entry.get("id", "")).strip_edges() == pid:
			return entry.duplicate(true)
	return {}



func record_marathon_run(summary: Dictionary) -> Dictionary:
	const MarathonRouteBadges = preload("res://logic/domain/session/marathon_route_badges.gd")
	_ensure_play_modes_data()
	var route_id := str(summary.get("route_id", "")).strip_edges()
	if route_id == "":
		return {}
	if not data.has("marathon_completions") or not data["marathon_completions"] is Dictionary:
		data["marathon_completions"] = {}
	var completions: Dictionary = data["marathon_completions"]
	var ratio := clampf(float(summary.get("completion_ratio", 0.0)), 0.0, 1.0)
	var avg_acc := maxf(0.0, float(summary.get("average_accuracy", 0.0)))
	var prev: Dictionary = {}
	var prev_raw: Variant = completions.get(route_id, {})
	if prev_raw is Dictionary:
		prev = prev_raw
	var prev_ratio := float(prev.get("best_ratio", 0.0))
	var best_ratio := maxf(prev_ratio, ratio)
	var best_acc := maxf(float(prev.get("best_acc", 0.0)), avg_acc)
	var best_updated := best_ratio > prev_ratio + 0.0001
	var badge_result := MarathonRouteBadges.evaluate(route_id, summary)
	var earned_now: Array = badge_result.get("earned", [])
	var prev_badges: Array = []
	if prev.get("badges") is Array:
		prev_badges = prev.get("badges")
	var merged_badges: Array[String] = []
	for tier in MarathonRouteBadges.TIER_ORDER:
		if prev_badges.has(tier) or earned_now.has(tier):
			merged_badges.append(tier)
	var prev_highest := str(prev.get("best_badge_tier", ""))
	var new_highest := MarathonRouteBadges.highest_tier(merged_badges)
	var badge_improved := (
		MarathonRouteBadges.TIER_ORDER.find(new_highest)
		> MarathonRouteBadges.TIER_ORDER.find(prev_highest)
	)
	var newly_earned: Array[String] = []
	for tier in earned_now:
		if not prev_badges.has(tier):
			newly_earned.append(str(tier))
	completions[route_id] = {
		"best_ratio": best_ratio,
		"best_acc": best_acc,
		"last_reason": str(summary.get("reason", "")),
		"tracks_cleared": int(summary.get("tracks_cleared", 0)),
		"total_tracks": int(summary.get("total_tracks", 0)),
		"badges": merged_badges,
		"best_badge_tier": new_highest,
	}
	data["marathon_completions"] = completions
	_save()
	return {
		"best_updated": best_updated,
		"badge_improved": badge_improved,
		"earned_this_run": earned_now,
		"newly_earned": newly_earned,
		"best_badge_tier": new_highest,
	}



func save_marathon_session_last(route_id: String, config: Dictionary) -> void:
	_ensure_play_modes_data()
	const MarathonSessionConfig = preload("res://logic/domain/session/marathon_session_config.gd")
	const MarathonRouteCatalog = preload("res://logic/domain/session/marathon_route_catalog.gd")
	var rid := str(route_id).strip_edges()
	if rid == "":
		return
	if not data["marathon_session_last"] is Dictionary:
		data["marathon_session_last"] = {}
	var cfg := MarathonSessionConfig.sanitize(config)
	cfg["route_id"] = rid
	cfg["genre_group_id"] = MarathonRouteCatalog.genre_group_for_route(rid)
	data["marathon_session_last"][rid] = cfg
	_save()



func save_playlist(entry: Dictionary) -> void:
	_ensure_play_modes_data()
	const PlaylistCatalog = preload("res://logic/domain/library/playlist_catalog.gd")
	var pid := str(entry.get("id", "")).strip_edges()
	if pid == "":
		return
	var normalized := PlaylistCatalog.normalize_playlist_entry(entry)
	normalized["id"] = pid
	var playlists: Array = []
	var replaced := false
	for raw in get_user_playlists():
		if raw is not Dictionary:
			continue
		var existing := raw as Dictionary
		if str(existing.get("id", "")).strip_edges() == pid:
			playlists.append(normalized)
			replaced = true
		else:
			playlists.append(PlaylistCatalog.normalize_playlist_entry(existing))
	if not replaced:
		playlists.append(normalized)
	data["user_playlists"] = playlists
	_save()
