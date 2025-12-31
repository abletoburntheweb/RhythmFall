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
@onready var total_score_label: Label = $MainContent/MainVBox/StatsVBox/TotalScoreLabel
@onready var total_drum_score_label: Label = $MainContent/MainVBox/StatsVBox/TotalDrumScoreContainer/TotalDrumScoreLabel

@onready var ss_label: Label = $MainContent/MainVBox/StatsVBox/HBoxContainer/SSLabel
@onready var s_label: Label = $MainContent/MainVBox/StatsVBox/HBoxContainer/SLabel
@onready var a_label: Label = $MainContent/MainVBox/StatsVBox/HBoxContainer/ALabel
@onready var b_label: Label = $MainContent/MainVBox/StatsVBox/HBoxContainer/BLabel

@onready var accuracy_chart_line: Line2D = $MainContent/MainVBox/StatsVBox/ChartContainer/ChartBackground/AccuracyChartLine
@onready var accuracy_chart_points: Control = $MainContent/MainVBox/StatsVBox/ChartContainer/ChartBackground/AccuracyChartPoints
@onready var chart_background: ColorRect = $MainContent/MainVBox/StatsVBox/ChartContainer/ChartBackground
@onready var tooltip_label: RichTextLabel = get_node_or_null(NodePath("MainContent/MainVBox/StatsVBox/ChartContainer/TooltipLabel")) as RichTextLabel

var session_history_manager = null

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
		
		var session_hist_mgr = null
		if game_engine.has_method("get_session_history_manager"):
			session_hist_mgr = game_engine.get_session_history_manager()

		if session_hist_mgr:
			setup_session_history_manager(session_hist_mgr)
		else:
			printerr("ProfileScreen.gd: SessionHistoryManager не получен из GameEngine.")

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

func setup_session_history_manager(session_history_mgr):
	session_history_manager = session_history_mgr
	refresh_stats()

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

	total_notes_hit_label.text = "Точных попаданий: %d" % total_notes_hit
	total_drum_hits_label.text = "Перкуссия: %d" % total_drum_hits
	total_notes_missed_label.text = "Промахов: %d" % total_notes_missed
	total_drum_misses_label.text = "Перкуссия: %d" % total_drum_misses
	
	var max_streak = player_data_manager.data.get("max_combo_ever", 0)
	var max_drum_streak = player_data_manager.data.get("max_drum_combo_ever", 0)
	max_hit_streak_label.text = "Рекордная серия попаданий подряд: %d" % max_streak
	max_drum_hit_streak_label.text = "Перкуссия: %d" % max_drum_streak

	total_earned_currency_label.text = "Заработано всего: %d" % player_data_manager.data.get("total_earned_currency", 0)
	spent_currency_label.text = "Потрачено: %d" % player_data_manager.data.get("spent_currency", 0)

	var total_score = player_data_manager.data.get("total_score_ever", 0)
	var total_drum_score = player_data_manager.data.get("total_drum_score_ever", 0)
	if total_score_label:
		total_score_label.text = "Всего очков: %d" % total_score
	if total_drum_score_label:
		total_drum_score_label.text = "Перкуссия: %d" % total_drum_score

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

	if session_history_manager:
		_update_accuracy_chart()

func _update_accuracy_chart():
	if session_history_manager == null:
		printerr("ProfileScreen: SessionHistoryManager не установлен!")
		accuracy_chart_line.points = []
		for child in accuracy_chart_points.get_children():
			child.queue_free()
		if tooltip_label:
			tooltip_label.visible = false
		return

	var history = session_history_manager.get_history()
	if history.size() == 0:
		print("ProfileScreen: Нет истории сессий для отображения.")
		accuracy_chart_line.points = []
		for child in accuracy_chart_points.get_children():
			child.queue_free()
		if tooltip_label:
			tooltip_label.visible = false
		return

	for child in accuracy_chart_points.get_children():
		if child.has_signal("point_hovered"):
			child.point_hovered.disconnect(_on_point_hovered)
		if child.has_signal("point_unhovered"):
			child.point_unhovered.disconnect(_on_point_unhovered)
		child.queue_free()

	var start_index = max(0, history.size() - 20)
	var relevant_history = history.slice(start_index, history.size())

	var points = []
	for i in range(20):
		var session = null
		if i < relevant_history.size():
			session = relevant_history[i]
		else:
			session = {
				"accuracy": 0.0,
				"grade_color": {"r": 0.5, "g": 0.5, "b": 0.5, "a": 1.0} 
			}

		var accuracy = session.get("accuracy", 0.0)
		var bg_width = chart_background.size.x
		var bg_height = chart_background.size.y
		var x = 20 + i * ((bg_width - 40) / 19.0) if 19 > 0 else 20
		var y = bg_height - (accuracy / 100.0) * bg_height
		points.append(Vector2(x, y))
	accuracy_chart_line.points = points

	for i in range(20):
		var session = null
		var tooltip_text = "Н/Д - Н/Д (0.00%)"
		if i < relevant_history.size():
			session = relevant_history[i]
			var accuracy = session.get("accuracy", 0.0)
			var artist = session.get("artist", "Unknown")
			var title = session.get("title", "Unknown Track")
			tooltip_text = "%s - %s\n(%.2f%%)" % [artist, title, accuracy]
		else:
			var accuracy = session.get("accuracy", 0.0) if session else 0.0
			tooltip_text = "Н/Д - Н/Д\n(%.2f%%)" % accuracy

		var grade_color_dict = session.get("grade_color", {"r": 1.0, "g": 1.0, "b": 1.0, "a": 1.0}) if session else {"r": 0.5, "g": 0.5, "b": 0.5, "a": 1.0}
		var color = Color(grade_color_dict["r"], grade_color_dict["g"], grade_color_dict["b"], grade_color_dict["a"])

		var bg_width = chart_background.size.x
		var bg_height = chart_background.size.y
		var x = 20 + i * ((bg_width - 40) / 19.0) if 19 > 0 else 20
		var y = bg_height - (session.get("accuracy", 0.0) / 100.0) * bg_height if session else bg_height

		var point_position = Vector2(x, y)

		var point_control_script = load("res://scenes/profile/chart_point.gd")
		var point_control = point_control_script.new()

		point_control.set_tooltip_text(tooltip_text)

		point_control.point_color = color
		point_control.point_radius = 6.0
		point_control.border_width = 1.5
		point_control.border_color = Color.BLACK
		
		point_control._ready()

		point_control.position = point_position - point_control.size / 2
		point_control.name = "Point%d" % i

		point_control.point_hovered.connect(_on_point_hovered.bind(i))
		point_control.point_unhovered.connect(_on_point_unhovered)

		accuracy_chart_points.add_child(point_control)

func _on_point_hovered(global_pos: Vector2, tooltip_text: String, index: int):
	if tooltip_label:
		tooltip_label.text = tooltip_text
		tooltip_label.visible = true
		var local_pos = accuracy_chart_points.to_local(global_pos)
		tooltip_label.position = local_pos + Vector2(-tooltip_label.size.x / 2, -tooltip_label.size.y - 15) 

func _on_point_unhovered():
	if tooltip_label:
		tooltip_label.visible = false

func _execute_close_transition():
	if music_manager:
		music_manager.play_cancel_sound()

	if transitions:
		transitions.close_profile()
		
	if is_instance_valid(self):
		if player_data_manager and player_data_manager.is_connected("total_play_time_changed", _on_total_play_time_changed):
			player_data_manager.total_play_time_changed.disconnect(_on_total_play_time_changed)
		queue_free()
