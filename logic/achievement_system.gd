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
	var paid_purchases = _get_paid_purchases_count()
	if paid_purchases >= 1:
		achievement_manager.check_first_purchase()
	achievement_manager.check_purchase_count(paid_purchases)
	achievement_manager.check_style_hunter_achievement(PlayerDataManager)
	achievement_manager.check_collection_completed_achievement(PlayerDataManager)
	var total_earned = PlayerDataManager.data.get("total_earned_currency", 0)
	var total_spent = PlayerDataManager.data.get("spent_currency", 0)
	achievement_manager.check_currency_achievements(PlayerDataManager)
	achievement_manager.check_spent_currency_achievement(total_spent)
	achievement_manager.check_score_achievements(PlayerDataManager)
	achievement_manager.check_playtime_achievements(PlayerDataManager)
	achievement_manager.check_level_achievements(PlayerDataManager.get_current_level())
	achievement_manager.check_daily_quests_completed_achievements(PlayerDataManager)
	achievement_manager.save_achievements()

func on_level_completed(accuracy: float, song_path: String, is_drum_mode: bool = false, grade: String = ""):
	print("[AchievementSystem] on_level_completed вызван с song_path: ", song_path, ", accuracy: ", accuracy, ", is_drum_mode: ", is_drum_mode, ", grade: ", grade)
	
	achievement_manager.check_first_level_achievement()
	achievement_manager.check_perfect_accuracy_achievement(accuracy)

	if track_stats_manager: 
		track_stats_manager.on_track_completed(song_path)
		achievement_manager.check_replay_level_achievement(track_stats_manager.track_completion_counts)
		achievement_manager.check_genre_achievements(track_stats_manager)

	var total_drum_levels = PlayerDataManager.get_drum_levels_completed()
	achievement_manager.check_drum_level_achievements(PlayerDataManager, accuracy, total_drum_levels)

	var total_levels_completed = PlayerDataManager.get_levels_completed()
	achievement_manager.check_levels_completed_achievement(total_levels_completed)
	
	achievement_manager.check_score_achievements(PlayerDataManager)
	if grade == "SS":
		achievement_manager.check_ss_achievements(PlayerDataManager)

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
	var total_earned = PlayerDataManager.data.get("total_earned_currency", 0)
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
	
func on_daily_quests_updated():
	achievement_manager.check_daily_quests_completed_achievements(PlayerDataManager)
	achievement_manager.save_achievements()
	
func on_notes_generated():
	PlayerDataManager.ensure_daily_quests_for_today()
	PlayerDataManager.increment_daily_progress("notes_generated", 1, {})
	achievement_manager.check_note_researcher_achievement() 
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
	var unlocked_items = PlayerDataManager.get_items()
	var file = FileAccess.open(SHOP_JSON_PATH, FileAccess.READ)
	if not file:
		return 0
	var json_text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(json_text)
	if not (parsed and parsed.has("items")):
		return 0
	var count = 0
	for item in parsed.items:
		var price = int(item.get("price", 0))
		if price > 0:
			var item_id = item.get("item_id", "")
			if unlocked_items.has(item_id):
				count += 1
	return count
