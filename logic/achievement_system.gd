# logic/achievement_system.gd
class_name AchievementSystem
extends RefCounted

var achievement_manager: AchievementManager = null
var player_data_manager: PlayerDataManager = null
var music_manager: MusicManager = null
var track_stats_manager: TrackStatsManager = null

func _init(ach_manager: AchievementManager, pd_manager: PlayerDataManager, music_mgr: MusicManager, track_stats_mgr: TrackStatsManager):
	achievement_manager = ach_manager
	player_data_manager = pd_manager
	music_manager = music_mgr
	track_stats_manager = track_stats_mgr
	
	achievement_manager.player_data_mgr = pd_manager
	achievement_manager.music_mgr = music_mgr
	player_data_manager.achievement_manager = ach_manager


func on_level_completed(accuracy: float, song_path: String, is_drum_mode: bool = false, grade: String = ""):
	print("[AchievementSystem] on_level_completed вызван с song_path: ", song_path, ", accuracy: ", accuracy, ", is_drum_mode: ", is_drum_mode, ", grade: ", grade)
	achievement_manager.check_first_level_achievement()
	achievement_manager.check_perfect_accuracy_achievement(accuracy)

	if track_stats_manager: 
		track_stats_manager.on_track_completed(song_path)
		achievement_manager.check_replay_level_achievement(track_stats_manager.track_completion_counts)

	player_data_manager.add_completed_level() 

	if is_drum_mode:
		player_data_manager.add_drum_level_completed()
		var total_drum_levels = player_data_manager.get_drum_levels_completed()
		print("[AchievementSystem] Total drum levels now: ", total_drum_levels)
		achievement_manager.check_drum_level_achievements(player_data_manager, accuracy, total_drum_levels)

	var total_levels_completed = player_data_manager.get_levels_completed()
	achievement_manager.check_levels_completed_achievement(total_levels_completed)
	
	achievement_manager.check_score_achievements(player_data_manager)
	if grade == "SS":
		achievement_manager.check_ss_achievements(player_data_manager)

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
	achievement_manager.check_event_achievements()
	achievement_manager.save_achievements()
	
func on_notes_generated():
	achievement_manager.check_note_researcher_achievement() 
	achievement_manager.save_achievements() 

func on_perfect_hit_made():
	var total_notes_hit = player_data_manager.get_total_notes_hit()
	achievement_manager.check_rhythm_master_achievement(total_notes_hit) 
	achievement_manager.save_achievements()

func on_perfect_hit_in_drum_mode(current_drum_streak: int, current_snare_streak: int):
	pass 

func process_delayed_achievements():
	var delayed_data = player_data_manager.get_and_clear_delayed_achievements()
	
	for data in delayed_data:
		pass 

func check_drum_storm_achievement():
	achievement_manager.check_drum_storm_achievement(player_data_manager)

func on_playtime_changed(new_time_formatted: String):
	print("[AchievementSystem] on_playtime_changed вызван. Новое время: ", new_time_formatted)
	achievement_manager.check_playtime_achievements(player_data_manager)
	achievement_manager.save_achievements()

func on_score_earned():
	achievement_manager.check_score_achievements(player_data_manager)
	achievement_manager.save_achievements()

func on_grade_earned(grade: String):
	if grade == "SS":
		achievement_manager.check_ss_achievements(player_data_manager)
	achievement_manager.save_achievements()
