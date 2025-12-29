class_name ProfileScreen
extends BaseScreen

@onready var back_button: Button = $MainContent/MainVBox/BackButton
@onready var levels_completed_label: Label = $MainContent/MainVBox/StatsVBox/LevelsCompletedLabel
@onready var drum_levels_completed_label: Label = $MainContent/MainVBox/StatsVBox/DrumLevelsContainer/DrumLevelsCompletedLabel
@onready var favorite_genre_label: Label = $MainContent/MainVBox/StatsVBox/FavoriteGenreLabel
@onready var favorite_track_label: Label = $MainContent/MainVBox/StatsVBox/FavoriteTrackLabel
@onready var overall_accuracy_label: Label = $MainContent/MainVBox/StatsVBox/OverallAccuracyLabel
@onready var drum_overall_accuracy_label: Label = $MainContent/MainVBox/StatsVBox/DrumOverallAccuracyContainer/DrumOverallAccuracyLabel
@onready var play_time_label: Label = $MainContent/MainVBox/StatsVBox/PlayTimeLabel
@onready var total_notes_hit_label: Label = $MainContent/MainVBox/StatsVBox/TotalNotesHitLabel 
@onready var total_drum_hits_label: Label = $MainContent/MainVBox/StatsVBox/TotalDrumHitsContainer/TotalDrumHitsLabel
@onready var total_notes_missed_label: Label = $MainContent/MainVBox/StatsVBox/TotalNotesMissedLabel
@onready var total_drum_misses_label: Label = $MainContent/MainVBox/StatsVBox/TotalDrumMissesContainer/TotalDrumMissesLabel
@onready var max_hit_streak_label: Label = $MainContent/MainVBox/StatsVBox/MaxHitStreakLabel
@onready var max_drum_hit_streak_label: Label = $MainContent/MainVBox/StatsVBox/MaxDrumHitStreakContainer/MaxDrumHitStreakLabel
@onready var total_earned_currency_label: Label = $MainContent/MainVBox/StatsVBox/TotalEarnedCurrencyLabel
@onready var spent_currency_label: Label = $MainContent/MainVBox/StatsVBox/SpentCurrencyLabel

@onready var ss_label: Label = $MainContent/MainVBox/StatsVBox/HBoxContainer/SSLabel
@onready var s_label: Label = $MainContent/MainVBox/StatsVBox/HBoxContainer/SLabel
@onready var a_label: Label = $MainContent/MainVBox/StatsVBox/HBoxContainer/ALabel
@onready var b_label: Label = $MainContent/MainVBox/StatsVBox/HBoxContainer/BLabel

func _play_time_string_to_seconds(time_str: String) -> int:
	var parts = time_str.split(":")
	if parts.size() == 2:
		var hours = parts[0].to_int()
		var minutes = parts[1].to_int()
		return (hours * 3600) + (minutes * 60)
	return 0

func _ready():
	var game_engine = get_parent()
	if game_engine and \
	   game_engine.has_method("get_music_manager") and \
	   game_engine.has_method("get_transitions") and \
	   game_engine.has_method("get_player_data_manager"):
		
		var music_mgr = game_engine.get_music_manager()
		var trans = game_engine.get_transitions()
		var player_data_mgr = game_engine.get_player_data_manager()

		setup_managers(trans, music_mgr, player_data_mgr)
		print("ProfileScreen.gd: setup_managers вызван из _ready().")
		
		if player_data_manager:
			player_data_manager.total_play_time_changed.connect(_on_total_play_time_changed)
	else:
		printerr("ProfileScreen.gd: Не удалось получить один из менеджеров (music_manager, transitions, player_data_manager) через GameEngine.")

	refresh_stats()

	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	else:
		printerr("ProfileScreen: Кнопка back_button не найдена!")

func _on_total_play_time_changed(new_time: String):
	if play_time_label:
		play_time_label.text = "Времени в игре: %s" % new_time

func refresh_stats():
	if player_data_manager == null:
		printerr("ProfileScreen: PlayerDataManager не установлен через setup_managers!")
		return

	levels_completed_label.text = "Завершено уровней: %d" % player_data_manager.get_levels_completed()
	drum_levels_completed_label.text = "Перкуссия: %d" % player_data_manager.get_drum_levels_completed()
	
	favorite_genre_label.text = "Любимый жанр: %s" % str(player_data_manager.data.get("favorite_genre", "Н/Д"))
	favorite_track_label.text = "Любимый трек: %s" % str(player_data_manager.data.get("favorite_track", "Н/Д"))
	
	var total_notes_hit = player_data_manager.get_total_notes_hit()
	var total_notes_missed = player_data_manager.get_total_notes_missed()
	var total_notes_played = total_notes_hit + total_notes_missed
	var overall_accuracy = 0.0
	if total_notes_played > 0:
		overall_accuracy = (float(total_notes_hit) / float(total_notes_played)) * 100.0
	overall_accuracy_label.text = "Общая точность: %.2f%%" % overall_accuracy
	
	var total_drum_hits = player_data_manager.data.get("total_drum_hits", 0)
	var total_drum_misses = player_data_manager.data.get("total_drum_misses", 0)
	var total_drum_notes = total_drum_hits + total_drum_misses
	var drum_accuracy = 0.0
	if total_drum_notes > 0:
		drum_accuracy = (float(total_drum_hits) / float(total_drum_notes)) * 100.0
	drum_overall_accuracy_label.text = "Перкуссия: %.2f%%" % drum_accuracy
	
	var play_time_formatted = player_data_manager.get_total_play_time_formatted() 
	play_time_label.text = "Времени в игре: %s" % play_time_formatted 

	total_notes_hit_label.text = "Попаданий: %d" % total_notes_hit
	total_drum_hits_label.text = "Перкуссия: %d" % total_drum_hits
	total_notes_missed_label.text = "Промахов: %d" % total_notes_missed
	total_drum_misses_label.text = "Перкуссия: %d" % total_drum_misses
	
	var max_streak = player_data_manager.data.get("max_combo_ever", 0)
	var max_drum_streak = player_data_manager.data.get("max_drum_combo_ever", 0)
	max_hit_streak_label.text = "Рекордная серия попаданий подряд: %d" % max_streak
	max_drum_hit_streak_label.text = "Перкуссия: %d" % max_drum_streak

	total_earned_currency_label.text = "Заработано всего: %d" % player_data_manager.data.get("total_earned_currency", 0)
	spent_currency_label.text = "Потрачено: %d" % player_data_manager.data.get("spent_currency", 0)

	var grades = player_data_manager.data.get("grades", {})
	var ss_count = grades.get("SS", 0)
	var s_count = grades.get("S", 0)
	var a_count = grades.get("A", 0)
	var b_count = grades.get("B", 0)

	ss_label.text = "SS: %d" % ss_count
	s_label.text = "S: %d" % s_count
	a_label.text = "A: %d" % a_count
	b_label.text = "B: %d" % b_count

	ss_label.modulate = Color.GOLD
	s_label.modulate = Color.SILVER
	a_label.modulate = Color.GREEN
	b_label.modulate = Color.CYAN

func _execute_close_transition():
	if music_manager:
		music_manager.play_cancel_sound()

	if transitions:
		transitions.close_profile()
		
	if is_instance_valid(self):
		if player_data_manager and player_data_manager.is_connected("total_play_time_changed", _on_total_play_time_changed):
			player_data_manager.total_play_time_changed.disconnect(_on_total_play_time_changed)
		queue_free()
