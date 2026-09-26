# logic/achievement_system.gd
class_name AchievementSystem
extends RefCounted

var achievement_manager: AchievementManager = null
var track_stats_manager: TrackStatsManager = null
const SHOP_JSON_PATH := "res://data/shop_data.json"

func _init(ach_manager: AchievementManager, track_stats_mgr: TrackStatsManager):
	achievement_manager = ach_manager
	track_stats_manager = track_stats_mgr
	
	achievement_manager.player_data_mgr = PlayerDataManager
	PlayerDataManager.achievement_manager = ach_manager

func resync_all():
	var _st_total := Time.get_ticks_usec()
	var _trace: Dictionary = {}
	var _st_step: int
	_st_step = Time.get_ticks_usec()
	var paid_purchases = _get_paid_purchases_count()
	_trace["_get_paid_purchases_count_ms"] = (Time.get_ticks_usec() - _st_step) / 1000.0
	_st_step = Time.get_ticks_usec()
	if paid_purchases >= 1:
		achievement_manager.check_first_purchase()
	_trace["check_first_purchase_ms"] = (Time.get_ticks_usec() - _st_step) / 1000.0
	_st_step = Time.get_ticks_usec()
	achievement_manager.check_purchase_count(paid_purchases)
	_trace["check_purchase_count_ms"] = (Time.get_ticks_usec() - _st_step) / 1000.0
	_st_step = Time.get_ticks_usec()
	achievement_manager.check_style_hunter_achievement(PlayerDataManager, false)
	_trace["check_style_hunter_ms"] = (Time.get_ticks_usec() - _st_step) / 1000.0
	_st_step = Time.get_ticks_usec()
	achievement_manager.check_collection_completed_achievement(PlayerDataManager, false)
	_trace["check_collection_ms"] = (Time.get_ticks_usec() - _st_step) / 1000.0
	var total_spent = PlayerDataManager.data.get("spent_currency", 0)
	_st_step = Time.get_ticks_usec()
	achievement_manager.check_currency_achievements(PlayerDataManager)
	_trace["check_currency_ms"] = (Time.get_ticks_usec() - _st_step) / 1000.0
	_st_step = Time.get_ticks_usec()
	achievement_manager.check_spent_currency_achievement(total_spent)
	_trace["check_spent_currency_ms"] = (Time.get_ticks_usec() - _st_step) / 1000.0
	_st_step = Time.get_ticks_usec()
	achievement_manager.check_score_achievements(PlayerDataManager)
	_trace["check_score_ms"] = (Time.get_ticks_usec() - _st_step) / 1000.0
	_st_step = Time.get_ticks_usec()
	achievement_manager.check_playtime_achievements(PlayerDataManager)
	_trace["check_playtime_ms"] = (Time.get_ticks_usec() - _st_step) / 1000.0
	_st_step = Time.get_ticks_usec()
	achievement_manager.check_level_achievements(PlayerDataManager.get_current_level())
	_trace["check_level_ms"] = (Time.get_ticks_usec() - _st_step) / 1000.0
	_st_step = Time.get_ticks_usec()
	achievement_manager.check_daily_quests_completed_achievements(PlayerDataManager)
	_trace["check_daily_ms"] = (Time.get_ticks_usec() - _st_step) / 1000.0
	_st_step = Time.get_ticks_usec()
	achievement_manager.check_unique_levels_completed_achievements(PlayerDataManager)
	_trace["check_unique_ms"] = (Time.get_ticks_usec() - _st_step) / 1000.0
	_st_step = Time.get_ticks_usec()
	achievement_manager.check_accuracy_95_achievements(PlayerDataManager)
	_trace["check_accuracy95_ms"] = (Time.get_ticks_usec() - _st_step) / 1000.0
	_st_step = Time.get_ticks_usec()
	achievement_manager.check_absolute_precision_achievements(PlayerDataManager)
	_trace["check_absolute_ms"] = (Time.get_ticks_usec() - _st_step) / 1000.0
	_st_step = Time.get_ticks_usec()
	achievement_manager.sync_unlocked_achievements_to_player_data()
	_trace["sync_unlocked_ms"] = (Time.get_ticks_usec() - _st_step) / 1000.0
	_st_step = Time.get_ticks_usec()
	achievement_manager.save_achievements()
	_trace["save_achievements_ms"] = (Time.get_ticks_usec() - _st_step) / 1000.0
	_trace["total_ms"] = (Time.get_ticks_usec() - _st_total) / 1000.0
	print("[STARTUP RESYNC TRACE]")
	for k in ["total_ms", "_get_paid_purchases_count_ms", "check_first_purchase_ms", "check_purchase_count_ms", "check_style_hunter_ms", "check_collection_ms", "check_currency_ms", "check_spent_currency_ms", "check_score_ms", "check_playtime_ms", "check_level_ms", "check_daily_ms", "check_unique_ms", "check_accuracy95_ms", "check_absolute_ms", "sync_unlocked_ms", "save_achievements_ms"]:
		var v: Variant = _trace.get(k, null)
		if v != null:
			print("  %-32s %.2f ms" % [k + ":", float(v)])
	# inner file IO details from _get_paid_purchases_count / _load_shop_json
	var ge_inner: Node = Engine.get_main_loop().root.get_node_or_null("GameEngine") if Engine.get_main_loop() and Engine.get_main_loop().root else null
	if ge_inner and "_startup_trace" in ge_inner:
		for subk in ["resync_get_paid_file_check_ms", "resync_get_paid_open_ms", "resync_get_paid_read_ms", "resync_get_paid_parse_ms", "resync_get_paid_loop_ms", "resync_get_paid_total_inner_ms"]:
			if ge_inner._startup_trace.has(subk):
				print("  %-32s %.2f ms" % [subk + ":", float(ge_inner._startup_trace[subk])])
		if ge_inner._startup_trace.has("load_shop_json_calls"):
			print("  %-32s %d" % ["load_shop_json_calls:", int(ge_inner._startup_trace["load_shop_json_calls"])])
			print("  %-32s %.2f ms" % ["load_shop_json_total_ms:", float(ge_inner._startup_trace.get("load_shop_json_total_ms", 0.0))])
			print("  %-32s %.2f ms" % ["load_shop_json_last_ms:", float(ge_inner._startup_trace.get("load_shop_json_last_ms", 0.0))])
	# also store for GameEngine startup trace if available
	var ge: Node = Engine.get_main_loop().root.get_node_or_null("GameEngine") if Engine.get_main_loop() and Engine.get_main_loop().root else null
	if ge and "_startup_trace" in ge:
		ge._startup_trace["resync_total_ms"] = _trace.get("total_ms", 0.0)
		for kk in _trace.keys():
			ge._startup_trace["resync_" + str(kk)] = _trace[kk]

func on_level_completed(accuracy: float, song_path: String, is_drum_mode: bool = false, grade: String = "", run_modifiers: Array = [], is_bass_mode: bool = false):
	
	achievement_manager.check_first_level_achievement()
	achievement_manager.check_perfect_accuracy_achievement(accuracy)
	achievement_manager.check_absolute_precision_achievements(PlayerDataManager)

	if track_stats_manager: 
		track_stats_manager.on_track_completed(song_path)
		var meta = SongLibrary.get_metadata_for_song(song_path.replace("\\", "/").trim_suffix("/"))
		if meta and typeof(meta) == TYPE_DICTIONARY and meta.has("primary_genre"):
			var genre_val = str(meta["primary_genre"]).to_lower().strip_edges()
			if genre_val != "":
				PlayerDataManager.increment_daily_progress("play_genre_group", 1, {"genre": genre_val})
		achievement_manager.check_replay_level_achievement(track_stats_manager.track_completion_counts)
		achievement_manager.check_genre_achievements(track_stats_manager)
		achievement_manager.check_genre_mastery_achievements(track_stats_manager)
		achievement_manager.check_genre_collector_achievements(track_stats_manager)
		achievement_manager.check_unique_levels_completed_achievements(PlayerDataManager)

	var total_drum_levels = PlayerDataManager.get_drum_levels_completed()
	achievement_manager.check_drum_level_achievements(PlayerDataManager, accuracy, total_drum_levels)

	var total_bass_levels = PlayerDataManager.get_bass_levels_completed()
	achievement_manager.check_bass_level_achievements(PlayerDataManager, accuracy, total_bass_levels, is_bass_mode)

	var total_levels_completed = PlayerDataManager.get_levels_completed()
	achievement_manager.check_levels_completed_achievement(total_levels_completed)
	achievement_manager.check_accuracy_95_achievements(PlayerDataManager)
	
	achievement_manager.check_score_achievements(PlayerDataManager)
	if grade == "SS":
		achievement_manager.check_ss_achievements(PlayerDataManager)

	achievement_manager.check_modifier_achievements(PlayerDataManager)

	achievement_manager.check_generation_achievements(PlayerDataManager)
	achievement_manager.check_genre_analysis_achievements(PlayerDataManager)
	achievement_manager.check_medal_achievements()
	achievement_manager.check_chart_difficulty_achievements(PlayerDataManager)
	achievement_manager.check_rr_mastery_achievements()

	achievement_manager.save_achievements()

func on_purchase_made():
	var paid_purchases = _get_paid_purchases_count()
	if paid_purchases >= 1:
		achievement_manager.check_first_purchase()
	achievement_manager.check_purchase_count(paid_purchases)
	achievement_manager.check_style_hunter_achievement(PlayerDataManager)
	achievement_manager.check_collection_completed_achievement(PlayerDataManager)
	achievement_manager.save_achievements()

func on_currency_changed():
	var total_spent = PlayerDataManager.data.get("spent_currency", 0)
	achievement_manager.check_currency_achievements(PlayerDataManager)
	achievement_manager.check_spent_currency_achievement(total_spent)
	achievement_manager.save_achievements() 

func on_daily_login():
	var login_streak = PlayerDataManager.get_login_streak()
	PlayerDataManager.ensure_daily_quests_for_today()
	achievement_manager.check_daily_login_achievements(PlayerDataManager)
	achievement_manager.check_event_achievements()
	achievement_manager.save_achievements()
	

## Cold-start event check: PlayerDataManager consumes `last_login_date` in its
## autoload _ready(), before GameEngine wires achievement_bridge, so the
## on_daily_login() path never reaches event achievements on a fresh day.
## GameEngine calls this once per start via _deferred_check_event_achievements().
func check_event_achievements() -> void:
	achievement_manager.check_event_achievements()
	
func on_daily_quests_updated():
	achievement_manager.check_daily_quests_completed_achievements(PlayerDataManager)
	achievement_manager.save_achievements()
	
func on_notes_generated():
	PlayerDataManager.ensure_daily_quests_for_today()
	PlayerDataManager.increment_daily_progress("notes_generated", 1, {})
	achievement_manager.check_note_researcher_achievement() 
	achievement_manager.save_achievements() 
	
func on_bpm_computed():
	achievement_manager.check_first_bpm_achievement()
	achievement_manager.save_achievements()
	
func on_analysis_canceled():
	achievement_manager.check_cancel_analysis_achievement()
	achievement_manager.save_achievements()

func on_perfect_hit_made():
	var total_perfect_hits = PlayerDataManager.get_total_perfect_hits()
	achievement_manager.check_rhythm_master_achievement(total_perfect_hits) 
	achievement_manager.save_achievements()


func process_delayed_achievements():
	var delayed_data = PlayerDataManager.get_and_clear_delayed_achievements()
	
	for data in delayed_data:
		pass 

func check_drum_storm_achievement():
	achievement_manager.check_drum_storm_achievement(PlayerDataManager)

func on_playtime_changed(new_time_formatted: String):
	achievement_manager.check_playtime_achievements(PlayerDataManager)
	achievement_manager.save_achievements()

func on_score_earned():
	achievement_manager.check_score_achievements(PlayerDataManager)
	achievement_manager.save_achievements()

func on_grade_earned(grade: String):
	if grade == "SS":
		achievement_manager.check_ss_achievements(PlayerDataManager)
	achievement_manager.save_achievements()
	
func on_player_level_changed(new_level: int):
	achievement_manager.check_level_achievements(new_level)
	achievement_manager.save_achievements()

func _get_paid_purchases_count() -> int:
	var _st_total_inner := Time.get_ticks_usec()
	var _st_file_check := Time.get_ticks_usec()
	var unlocked_items = PlayerDataManager.get_items()
	var user_path = "user://shop_data.json"
	var open_path = user_path if FileAccess.file_exists(user_path) else SHOP_JSON_PATH
	var _file_check_ms := (Time.get_ticks_usec() - _st_file_check) / 1000.0
	var _st_open := Time.get_ticks_usec()
	var file = FileAccess.open(open_path, FileAccess.READ)
	var _open_ms := (Time.get_ticks_usec() - _st_open) / 1000.0
	if not file:
		return 0
	var _st_read := Time.get_ticks_usec()
	var json_text = file.get_as_text()
	file.close()
	var _read_ms := (Time.get_ticks_usec() - _st_read) / 1000.0
	var _st_parse := Time.get_ticks_usec()
	var parsed = JSON.parse_string(json_text)
	var _parse_ms := (Time.get_ticks_usec() - _st_parse) / 1000.0
	if not (parsed and parsed.has("items")):
		return 0
	var _st_loop := Time.get_ticks_usec()
	var count = 0
	for item in parsed.items:
		var price = int(item.get("price", 0))
		if price > 0:
			var item_id = item.get("item_id", "")
			if unlocked_items.has(item_id):
				count += 1
	var _loop_ms := (Time.get_ticks_usec() - _st_loop) / 1000.0
	var _total_inner_ms := (Time.get_ticks_usec() - _st_total_inner) / 1000.0
	var ge: Node = Engine.get_main_loop().root.get_node_or_null("GameEngine") if Engine.get_main_loop() and Engine.get_main_loop().root else null
	if ge and "_startup_trace" in ge:
		ge._startup_trace["resync_get_paid_file_check_ms"] = _file_check_ms
		ge._startup_trace["resync_get_paid_open_ms"] = _open_ms
		ge._startup_trace["resync_get_paid_read_ms"] = _read_ms
		ge._startup_trace["resync_get_paid_parse_ms"] = _parse_ms
		ge._startup_trace["resync_get_paid_loop_ms"] = _loop_ms
		ge._startup_trace["resync_get_paid_total_inner_ms"] = _total_inner_ms
	return count

func on_genre_analyzed():
	PlayerDataManager.record_genre_analyzed()
	achievement_manager.check_first_genre_analysis_achievement()
	achievement_manager.check_genre_analysis_achievements(PlayerDataManager)
	achievement_manager.save_achievements()



func on_genre_picked_from_server():
	PlayerDataManager.record_genre_from_server_pick()
	achievement_manager.check_genre_analysis_achievements(PlayerDataManager)
	achievement_manager.save_achievements()



func on_metadata_saved():
	PlayerDataManager.record_metadata_saved()
	achievement_manager.check_genre_analysis_achievements(PlayerDataManager)
	achievement_manager.save_achievements()


func on_song_replayed(_song_path: String) -> void:
	if achievement_manager == null or track_stats_manager == null:
		return
	achievement_manager.check_replay_level_achievement(track_stats_manager.track_completion_counts)
	achievement_manager.save_achievements()



func on_rhythm_dna_opened() -> void:
	achievement_manager.check_first_rhythm_dna_achievement()
	achievement_manager.save_achievements()

