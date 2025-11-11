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

func set_victory_data(p_score: int, p_combo: int, p_max_combo: int, p_accuracy: float, p_song_info: Dictionary = {}):
	score = p_score
	combo = p_combo
	max_combo = p_max_combo
	accuracy = p_accuracy
	song_info = p_song_info
	
	earned_currency = _calculate_currency()

	call_deferred("_deferred_update_ui")

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
		currency_label.text = "Валюта: %d" % earned_currency 
		
	var game_engine = get_parent()
	if game_engine and game_engine.has_method("get_player_data_manager"):
		var player_data_manager = game_engine.get_player_data_manager()
		if player_data_manager:
			player_data_manager.add_currency(earned_currency)
			print("💰 Игрок заработал валюту: %d" % earned_currency)
			if is_instance_valid(currency_label):
				currency_label.text = "Валюта: %d" % player_data_manager.get_currency()
		else:
			printerr("VictoryScreen: Не удалось получить player_data_manager")
	else:
		printerr("VictoryScreen: Не удалось получить game_engine или метод get_player_data_manager")

func _calculate_currency() -> int:
	var currency = int(score * 0.01 + max_combo * 0.1 + accuracy * 10)
	return max(0, currency)
