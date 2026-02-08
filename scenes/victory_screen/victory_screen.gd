# scenes/victory_screen/victory_screen.gd
extends Control

signal song_select_requested
signal replay_requested

var score: int
var combo: int
var max_combo: int
var accuracy: float
var song_info: Dictionary = {}
var earned_currency: int = 0
var earned_xp: int = 0 

var calculated_combo_multiplier: float = 1.0 
var calculated_total_notes: int = 0
var calculated_missed_notes: int = 0
var perfect_hits_this_level: int = 0
var hit_notes_this_level: int = 0

var results_manager = null

var session_history_manager = null

@onready var background: ColorRect = $Background
@onready var title_label: Label = $TitleLabel
@onready var song_label: Label = $SongLabel
@onready var stats_frame: Panel = $StatsFrame
@onready var score_label: Label = $StatsFrame/ScoreLabel
@onready var combo_label: Label = $StatsFrame/ComboLabel
@onready var max_combo_label: Label = $StatsFrame/MaxComboLabel
@onready var accuracy_label: Label = $StatsFrame/AccuracyLabel
@onready var grade_label: Label = $StatsFrame/GradeLabel
@onready var currency_label: Label = $StatsFrame/CurrencyLabel
@onready var xp_label: Label = $StatsFrame/XPLabel 
@onready var hit_notes_label: Label = $StatsFrame/HitNotesLabel 
@onready var missed_notes_label: Label = $StatsFrame/MissedNotesLabel 
@onready var replay_button: Button = $ButtonsContainer/ReplayButton
@onready var song_select_button: Button = $ButtonsContainer/SongSelectButton


func _ready():
	replay_button.pressed.connect(_on_replay_button_pressed)
	song_select_button.pressed.connect(_on_song_select_button_pressed)
	
	if currency_label:
		currency_label.mouse_filter = Control.MOUSE_FILTER_STOP
		currency_label.gui_input.connect(_on_currency_label_clicked)
	
	if xp_label:
		xp_label.mouse_filter = Control.MOUSE_FILTER_STOP
		xp_label.gui_input.connect(_on_xp_label_clicked)

func _calculate_grade() -> String:
	if accuracy == 100.0: 
		return "SS"
	elif accuracy >= 95.0: 
		return "S"
	elif accuracy >= 90.0:
		return "A"
	elif accuracy >= 80.0: 
		return "B"
	elif accuracy >= 70.0:
		return "C"
	elif accuracy >= 60.0:
		return "D"
	else: 
		return "F"
		
func _get_grade_color(grade: String) -> Color:
	match grade:
		"SS": return Color("#F2B35A")
		"S": return Color("#C8D2E6")
		"A": return Color("#6B91D2")
		"B": return Color("#59D1BE")
		"C": return Color("#A58EDB")
		"D": return Color("#D56B87")
		"F": return Color("#8A2F39")
		_: return Color("#FFFFFF")

func _calculate_xp_new() -> int:
	var base_xp = sqrt(float(score)) * 2.0 

	var accuracy_bonus = 0.0
	if accuracy >= 100.0:
		accuracy_bonus = 40.0
	elif accuracy >= 98.0:
		accuracy_bonus = 25.0
	elif accuracy >= 95.0:
		accuracy_bonus = 15.0
	elif accuracy >= 90.0:
		accuracy_bonus = 5.0

	var combo_bonus = 0.0
	if max_combo > 0:
		combo_bonus = log(float(max_combo) + 1.0) * 10.0 

	var grade_bonus = 0.0
	var grade = _calculate_grade()
	match grade:
		"SS": grade_bonus = 80.0
		"S":  grade_bonus = 40.0
		"A":  grade_bonus = 20.0
		"B":  grade_bonus = 5.0
	var full_combo_bonus = 0.0
	if calculated_missed_notes == 0 and calculated_total_notes > 0:
		full_combo_bonus = 60.0

	var total_xp = int(base_xp + accuracy_bonus + combo_bonus + grade_bonus + full_combo_bonus)
	return max(1, total_xp)

func _on_replay_button_pressed():
	MusicManager.stop_game_music()
	MusicManager.play_select_sound()
	
	var game_engine = get_parent()
	if game_engine and game_engine.has_method("get_transitions"):
		var transitions = game_engine.get_transitions()
		if transitions and transitions.has_method("open_game_with_song"):
			var instrument_to_use = song_info.get("instrument", "standard")
			transitions.open_game_with_song(song_info, instrument_to_use, results_manager)
	
	queue_free()


func _on_song_select_button_pressed():
	MusicManager.stop_game_music()
	MusicManager.play_select_sound()
	
	var game_engine = get_parent()
	if game_engine and game_engine.has_method("get_transitions"):
		var transitions = game_engine.get_transitions()
		if transitions and transitions.has_method("open_song_select"):
			transitions.open_song_select()

	queue_free()

func _on_currency_label_clicked(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_show_currency_details()

func _show_currency_details():
	var currency_details_scene = load("res://scenes/victory_screen/victory_currency_details.tscn")
	var currency_details = currency_details_scene.instantiate()
	
	currency_details.details_closed.connect(_on_currency_details_closed)
	
	add_child(currency_details)
	
	currency_details.show_details(
		score, 
		max_combo, 
		accuracy, 
		calculated_total_notes, 
		calculated_missed_notes, 
		calculated_combo_multiplier, 
		earned_currency
	)

func _on_currency_details_closed():
	pass

func _on_xp_label_clicked(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_show_xp_details()

func _show_xp_details():
	var xp_details_scene = load("res://scenes/victory_screen/victory_xp_details.tscn")
	var xp_details = xp_details_scene.instantiate()
	
	add_child(xp_details)
	
	var grade = _calculate_grade()
	xp_details.show_details(
		score,
		max_combo,
		accuracy,
		calculated_missed_notes,
		grade,
		earned_xp
	)

func set_results_manager(results_mgr):
	results_manager = results_mgr

func set_session_history_manager(session_hist_mgr):
	session_history_manager = session_hist_mgr

func set_achievement_system(ach_sys):
	if results_manager and results_manager.has_method("set_achievement_system"):
		results_manager.set_achievement_system(ach_sys)

func set_victory_data(p_score: int, p_combo: int, p_max_combo: int, p_accuracy: float, p_song_info: Dictionary = {}, p_combo_multiplier: float = 1.0, p_total_notes: int = 0, p_missed_notes: int = 0, p_perfect_hits: int = 0, p_hit_notes: int = 0):
	score = p_score
	combo = p_combo
	max_combo = p_max_combo
	accuracy = p_accuracy
	song_info = p_song_info.duplicate() 
	
	calculated_combo_multiplier = min(4.0, 1.0 + floor(float(max_combo) / 10.0))
	
	if p_total_notes <= 0:
		calculated_total_notes = p_hit_notes + p_missed_notes
	else:
		calculated_total_notes = p_total_notes
	calculated_missed_notes = p_missed_notes
	perfect_hits_this_level = p_perfect_hits
	hit_notes_this_level = p_hit_notes 
	
	earned_currency = _calculate_currency_new()
	earned_xp = _calculate_xp_new() 

	call_deferred("_deferred_update_ui")

func _calculate_currency_new() -> int:
	var base_currency = sqrt(float(score)) * 1.5  

	var combo_bonus = 0.0
	if max_combo > 0:
		combo_bonus = log(float(max_combo) + 1.0) * 5.0 

	var accuracy_bonus = 0.0
	if accuracy >= 100.0:
		accuracy_bonus = 40.0
	elif accuracy >= 95.0:
		accuracy_bonus = (accuracy - 90.0) * 1.0 

	var full_combo_bonus = 0.0
	if calculated_missed_notes == 0 and calculated_total_notes > 0:
		full_combo_bonus = 25.0

	var multiplier_bonus = (calculated_combo_multiplier - 1.0) * 4.0 

	var total_currency = base_currency + combo_bonus + accuracy_bonus + full_combo_bonus + multiplier_bonus
	return max(1, int(total_currency))

func _deferred_update_ui():
	if is_instance_valid(song_label) and song_info.get("title"):
		song_label.text = song_info["title"]
	
	if is_instance_valid(score_label):
		score_label.text = "Счёт: %d" % score  
		
	if is_instance_valid(combo_label):
		combo_label.text = "Комбо: %d" % combo  
	
	if is_instance_valid(max_combo_label):
		max_combo_label.text = "Макс. комбо: %d" % max_combo 
	
	if is_instance_valid(accuracy_label):
		accuracy_label.text = "Точность: %.1f%%" % accuracy  

	if is_instance_valid(grade_label):
		var grade = _calculate_grade()
		var grade_color = _get_grade_color(grade)
		grade_label.text = "Оценка: %s" % grade
		grade_label.modulate = grade_color
	
	if is_instance_valid(currency_label):
		currency_label.text = "Валюта за уровень: %d" % earned_currency
		currency_label.modulate = Color.GOLD

	if is_instance_valid(xp_label):
		xp_label.text = "XP за уровень: %d" % earned_xp
		xp_label.modulate = Color.CYAN  

	if is_instance_valid(hit_notes_label):
		hit_notes_label.text = "Попаданий: %d" % hit_notes_this_level 
	if is_instance_valid(missed_notes_label):
		missed_notes_label.text = "Промахов: %d" % calculated_missed_notes

	PlayerDataManager.add_missed_notes(calculated_missed_notes)
	PlayerDataManager.add_currency(earned_currency)
	PlayerDataManager.add_perfect_hits(perfect_hits_this_level)
	
	var current_max_combo = PlayerDataManager.data.get("max_combo_ever", 0)
	if max_combo > current_max_combo:
		PlayerDataManager.data["max_combo_ever"] = max_combo
		PlayerDataManager._save()

	var instrument_used_for_combo_check = song_info.get("instrument", "standard")
	var current_max_drum_combo = PlayerDataManager.data.get("max_drum_combo_ever", 0)
	if instrument_used_for_combo_check == "drums" and max_combo > current_max_drum_combo:
		PlayerDataManager.data["max_drum_combo_ever"] = max_combo
		PlayerDataManager._save()

	if instrument_used_for_combo_check == "drums":
		var current_drum_hits = PlayerDataManager.data.get("total_drum_hits", 0)
		var new_drum_hits = current_drum_hits + hit_notes_this_level
		PlayerDataManager.data["total_drum_hits"] = new_drum_hits
		
		var current_drum_misses = PlayerDataManager.data.get("total_drum_misses", 0)
		var new_drum_misses = current_drum_misses + calculated_missed_notes
		PlayerDataManager.data["total_drum_misses"] = new_drum_misses
		
		PlayerDataManager._save()

	var is_drum_mode = (instrument_used_for_combo_check == "drums")
	PlayerDataManager.add_score_to_total(score, is_drum_mode)

	var should_save_result_later = (results_manager and song_info and song_info.get("path"))
	if should_save_result_later:
		var instrument_for_result = song_info.get("instrument", "standard")
		if instrument_for_result == "drums":
			instrument_for_result = "Перкуссия"
		var grade_for_result = _calculate_grade()
		var grade_color_for_result = _get_grade_color(grade_for_result)
		var result_datetime_for_result = Time.get_datetime_string_from_system(true, true)
		results_manager.save_result_for_song(
			song_info.get("path", ""), 
			instrument_for_result,          
			score,                    
			accuracy,                  
			grade_for_result,                   
			grade_color_for_result,              
			result_datetime_for_result           
		)

	var song_path = song_info.get("path", "")
	if !song_path.is_empty():
		var final_grade = _calculate_grade()
		PlayerDataManager.update_best_grade_for_track(song_path, final_grade)

	var achievement_system = null
	var achievement_manager = null
	
	var game_engine = get_parent()
	if game_engine:
		if game_engine.has_method("get_achievement_system"):
			achievement_system = game_engine.get_achievement_system()
		if game_engine.has_method("get_achievement_manager"):
			achievement_manager = game_engine.get_achievement_manager()
			if achievement_manager:
				achievement_manager.notification_mgr = game_engine

	if session_history_manager:
		var instrument_type_for_history = song_info.get("instrument", "standard")
		if instrument_type_for_history == "drums":
			instrument_type_for_history = "Перкуссия"
		var grade_for_history = _calculate_grade()
		var grade_color_for_history = _get_grade_color(grade_for_history)
		var current_time_string = Time.get_datetime_string_from_system(true, true)
		
		var artist = song_info.get("artist", "N/A")
		var title = song_info.get("title", "N/A")
		
		session_history_manager.add_session_result(
			accuracy,                    
			current_time_string,        
			grade_for_history,          
			grade_color_for_history,    
			instrument_type_for_history,
			score,
			artist,
			title
		)

	if achievement_system:
		achievement_system.on_level_completed(accuracy, song_path, is_drum_mode, _calculate_grade())
	else:
		if achievement_manager:
			achievement_manager.check_first_level_achievement()
			achievement_manager.check_perfect_accuracy_achievement(accuracy)

			if is_drum_mode:
				var total_drum_levels = PlayerDataManager.get_drum_levels_completed()
				achievement_manager.check_drum_level_achievements(PlayerDataManager, accuracy, total_drum_levels)

			achievement_manager.check_score_achievements(PlayerDataManager)
			if _calculate_grade() == "SS":
				achievement_manager.check_ss_achievements(PlayerDataManager)

	if achievement_manager and achievement_manager.has_method("show_all_delayed_mastery_achievements"):
		achievement_manager.show_all_delayed_mastery_achievements()
		achievement_manager.clear_new_mastery_achievements()

	PlayerDataManager.add_xp(earned_xp)
