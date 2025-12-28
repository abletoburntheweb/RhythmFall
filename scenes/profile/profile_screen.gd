# scenes/profile/profile_screen.gd
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
	else:
		printerr("ProfileScreen.gd: Не удалось получить один из менеджеров (music_manager, transitions, player_data_manager) через GameEngine.")

	refresh_stats()

	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	else:
		printerr("ProfileScreen: Кнопка back_button не найдена!")

func refresh_stats():
	if player_data_manager == null:
		printerr("ProfileScreen: PlayerDataManager не установлен через setup_managers!")
		return

	levels_completed_label.text = "Завершено уровней: %d" % player_data_manager.get_levels_completed()
	drum_levels_completed_label.text = "Перкуссия: %d" % player_data_manager.get_drum_levels_completed()
	
	# Обновляем значения для новых лейблов
	favorite_genre_label.text = "Любимый жанр: %s" % str(player_data_manager.data.get("favorite_genre", "Н/Д"))
	favorite_track_label.text = "Любимый трек: %s" % str(player_data_manager.data.get("favorite_track", "Н/Д"))
	
	var total_notes_hit = player_data_manager.get_total_notes_hit()
	var total_notes_missed = player_data_manager.get_total_notes_missed()
	var total_notes_played = total_notes_hit + total_notes_missed
	var overall_accuracy = 0.0
	if total_notes_played > 0:
		overall_accuracy = (float(total_notes_hit) / float(total_notes_played)) * 100.0
	overall_accuracy_label.text = "Общая точность: %.2f%%" % overall_accuracy
	
	# Точность для барабанов (если есть данные)
	var total_drum_hits = player_data_manager.data.get("total_drum_hits", 0)
	var total_drum_misses = player_data_manager.data.get("total_drum_misses", 0)
	var total_drum_notes = total_drum_hits + total_drum_misses
	var drum_accuracy = 0.0
	if total_drum_notes > 0:
		drum_accuracy = (float(total_drum_hits) / float(total_drum_notes)) * 100.0
	drum_overall_accuracy_label.text = "Перкуссия: %.2f%%" % drum_accuracy
	
	# Время в игре (пока всегда 00:00, т.к. не отслеживается)
	var play_time_seconds = player_data_manager.data.get("total_play_time_seconds", 0.0)
	var play_time_hours = int(play_time_seconds) / 3600
	var play_time_minutes = (int(play_time_seconds) % 3600) / 60
	var play_time_formatted = str(play_time_hours).pad_zeros(2) + ":" + str(play_time_minutes).pad_zeros(2)
	play_time_label.text = "Времени в игре: %s" % play_time_formatted

	total_notes_hit_label.text = "Попаданий: %d" % total_notes_hit
	total_drum_hits_label.text = "Перкуссия: %d" % total_drum_hits
	total_notes_missed_label.text = "Промахов: %d" % total_notes_missed
	total_drum_misses_label.text = "Перкуссия: %d" % total_drum_misses
	
	# Рекордные серии
	var max_streak = player_data_manager.data.get("max_combo_ever", 0)
	var max_drum_streak = player_data_manager.data.get("max_drum_combo_ever", 0)
	max_hit_streak_label.text = "Рекордная серия попаданий подряд: %d" % max_streak
	max_drum_hit_streak_label.text = "Перкуссия: %d" % max_drum_streak

	total_earned_currency_label.text = "Заработано всего: %d" % player_data_manager.data.get("total_earned_currency", 0)
	spent_currency_label.text = "Потрачено: %d" % player_data_manager.data.get("spent_currency", 0)

func _execute_close_transition():
	if music_manager:
		music_manager.play_cancel_sound()

	if transitions:
		transitions.close_profile()
		
	if is_instance_valid(self):
		queue_free()
