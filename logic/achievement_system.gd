# logic/achievement_system.gd
class_name AchievementSystem
extends RefCounted

var achievement_manager: AchievementManager = null
var player_data_manager: PlayerDataManager = null
var music_manager: MusicManager = null

func _init(ach_manager: AchievementManager, pd_manager: PlayerDataManager, music_mgr: MusicManager):
	achievement_manager = ach_manager
	player_data_manager = pd_manager
	music_manager = music_mgr
	
	achievement_manager.player_data_mgr = pd_manager
	achievement_manager.music_mgr = music_mgr
	player_data_manager.achievement_manager = ach_manager

func on_song_replayed(song_path: String):
	achievement_manager.check_replay_level_achievement(song_path) 

func on_level_completed(accuracy: float, is_drum_mode: bool = false): 
	print("[AchievementSystem] on_level_completed вызван с accuracy: ", accuracy, ", is_drum_mode: ", is_drum_mode)
	achievement_manager.check_first_level_achievement()
	achievement_manager.check_perfect_accuracy_achievement(accuracy)

	if is_drum_mode:
		player_data_manager.add_drum_level_completed()
		var total_drum_levels = player_data_manager.get_drum_levels_completed() 
		print("[AchievementSystem] Total drum levels now: ", total_drum_levels)
		achievement_manager.check_drum_level_achievements(player_data_manager, accuracy, total_drum_levels)
	else:
		player_data_manager.add_completed_level() 

	var total_levels_completed = player_data_manager.get_levels_completed() 
	achievement_manager.check_levels_completed_achievement(total_levels_completed)
	achievement_manager.save_achievements() 

func on_purchase_made():
	var total_purchases = player_data_manager.get_items().size()
	achievement_manager.check_purchase_count(total_purchases)
	achievement_manager.check_style_hunter_achievement(player_data_manager)
	achievement_manager.check_collection_completed_achievement(player_data_manager)
	achievement_manager.save_achievements()

func on_currency_changed():
	var total_earned = player_data_manager.data.get("total_earned_currency", 0)
	var total_spent = player_data_manager.data.get("spent_currency", 0)
	achievement_manager.check_currency_achievements(player_data_manager)
	achievement_manager.check_spent_currency_achievement(total_spent)
	achievement_manager.save_achievements() 

func on_daily_login():
	var login_streak = player_data_manager.get_login_streak()
	achievement_manager.check_daily_login_achievements(player_data_manager)
	achievement_manager.save_achievements()
	
func on_notes_generated():
	achievement_manager.check_note_researcher_achievement() 
	achievement_manager.save_achievements() 

func on_perfect_hit_made():
	var total_notes_hit = player_data_manager.get_total_notes_hit()
	achievement_manager.check_rhythm_master_achievement(total_notes_hit) 
	achievement_manager.save_achievements()

func on_perfect_hit_in_drum_mode(current_drum_streak: int, current_snare_streak: int):
	var player_data = {
		"current_drum_streak": current_drum_streak,
		"current_snare_streak": current_snare_streak,
		"type": "drum_streak"
	}
	player_data_manager.add_delayed_achievement(player_data)

func process_delayed_achievements():
	var delayed_data = player_data_manager.get_and_clear_delayed_achievements()
	
	for data in delayed_data:
		if data.get("type") == "drum_streak":
			var current_drum_streak = data.get("current_drum_streak", 0)
			achievement_manager.check_drum_storm_achievement(player_data_manager, current_drum_streak)
