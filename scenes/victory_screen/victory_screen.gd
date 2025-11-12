# victory_screen/victory_screen.gd
extends Control

signal song_select_requested
signal replay_requested

var score: int
var combo: int
var max_combo: int
var accuracy: float
var song_info: Dictionary = {}
var earned_currency: int = 0

var calculated_combo_multiplier: float = 1.0 
var calculated_total_notes: int = 0
var calculated_missed_notes: int = 0

@onready var background: ColorRect = $Background
@onready var title_label: Label = $TitleLabel
@onready var song_label: Label = $SongLabel
@onready var stats_frame: Panel = $StatsFrame
@onready var score_label: Label = $StatsFrame/ScoreLabel
@onready var combo_label: Label = $StatsFrame/ComboLabel
@onready var max_combo_label: Label = $StatsFrame/MaxComboLabel
@onready var accuracy_label: Label = $StatsFrame/AccuracyLabel
@onready var currency_label: Label = $StatsFrame/CurrencyLabel
@onready var replay_button: Button = $ButtonsContainer/ReplayButton
@onready var song_select_button: Button = $ButtonsContainer/SongSelectButton

func _ready():
	replay_button.pressed.connect(_on_replay_button_pressed)
	song_select_button.pressed.connect(_on_song_select_button_pressed)

func _on_replay_button_pressed():
	var game_engine = get_parent()
	if game_engine and game_engine.has_method("get_transitions"):
		var transitions = game_engine.get_transitions()
		if transitions and transitions.has_method("open_game_with_song"):
			var instrument_to_use = song_info.get("instrument", "standard")
			transitions.open_game_with_song(song_info, instrument_to_use)
	
	queue_free()

func _on_song_select_button_pressed():
	var game_engine = get_parent()
	if game_engine and game_engine.has_method("get_transitions"):
		var transitions = game_engine.get_transitions()
		if transitions and transitions.has_method("open_song_select"):
			transitions.open_song_select()

	queue_free()

func set_victory_data(p_score: int, p_combo: int, p_max_combo: int, p_accuracy: float, p_song_info: Dictionary = {}, p_combo_multiplier: float = 1.0, p_total_notes: int = 0, p_missed_notes: int = 0):
	score = p_score
	combo = p_combo
	max_combo = p_max_combo
	accuracy = p_accuracy
	song_info = p_song_info.duplicate() 
	
	calculated_combo_multiplier = p_combo_multiplier
	calculated_total_notes = p_total_notes
	calculated_missed_notes = p_missed_notes
	
	earned_currency = _calculate_currency_new()

	call_deferred("_deferred_update_ui")

func _calculate_currency_new() -> int:
	var base_currency = float(score) / 100.0
	var combo_bonus = sqrt(float(max_combo)) * 2.0
	var accuracy_bonus = 0.0
	if accuracy >= 95.0 and accuracy < 100.0:
		accuracy_bonus = (accuracy - 90.0) * 1.5
	elif accuracy >= 100.0:
		accuracy_bonus = 50.0 
	var full_combo_bonus = 0.0
	if calculated_missed_notes == 0 and calculated_total_notes > 0:
		full_combo_bonus = 20.0
	var multiplier_bonus = (calculated_combo_multiplier - 1.0) * 5.0
	var total_currency = base_currency + combo_bonus + accuracy_bonus + full_combo_bonus + multiplier_bonus
	var final_currency = int(total_currency)
	return max(1, final_currency)

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
	
	if is_instance_valid(currency_label):
		currency_label.text = "Валюта за уровень: %d" % earned_currency 
		
	var game_engine = get_parent()
	if game_engine and game_engine.has_method("get_player_data_manager"):
		var player_data_manager = game_engine.get_player_data_manager()
		if player_data_manager:
			player_data_manager.add_currency(earned_currency)
			print("💰 Игрок заработал валюту: %d" % earned_currency)
		else:
			printerr("VictoryScreen: Не удалось получить player_data_manager")
	else:
		printerr("VictoryScreen: Не удалось получить game_engine или метод get_player_data_manager")
