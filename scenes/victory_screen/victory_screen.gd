# victory_screen/victory_screen.gd
extends Control

signal song_select_requested
signal replay_requested

var score: int
var combo: int
var max_combo: int
var accuracy: float
var song_info: Dictionary = {}
var displayed_score: int = 0
var displayed_combo: int = 0
var displayed_max_combo: int = 0
var displayed_accuracy: float = 0.0
var displayed_currency: int = 0
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

var animation_timer: Timer

func _ready():
	replay_button.pressed.connect(_on_replay_button_pressed)
	song_select_button.pressed.connect(_on_song_select_button_pressed)
	
	animation_timer = Timer.new()
	animation_timer.wait_time = 0.03
	animation_timer.timeout.connect(_animate_results)
	add_child(animation_timer)

func _on_replay_button_pressed():
	var game_engine = get_parent()
	if game_engine and game_engine.has_method("get_transitions"):
		var transitions = game_engine.get_transitions()
		if transitions and transitions.has_method("open_game_with_song"):
			transitions.open_game_with_song(song_info, "standard")

func _on_song_select_button_pressed():
	var game_engine = get_parent()
	if game_engine and game_engine.has_method("get_transitions"):
		var transitions = game_engine.get_transitions()
		if transitions and transitions.has_method("open_song_select"):
			transitions.open_song_select()

func _animate_results():
	var finished = true
	
	if displayed_score < score:
		displayed_score += max(1, int(score * 0.02))
		if displayed_score > score:
			displayed_score = score
		if is_instance_valid(score_label):
			score_label.text = "Счёт: %d" % displayed_score
		finished = false
	
	if displayed_combo < combo:
		displayed_combo += 1
		if is_instance_valid(combo_label):
			combo_label.text = "Комбо: %d" % displayed_combo
		finished = false
	
	if displayed_max_combo < max_combo:
		displayed_max_combo += 1
		if is_instance_valid(max_combo_label):
			max_combo_label.text = "Макс. комбо: %d" % displayed_max_combo
		finished = false
	
		displayed_accuracy += 0.5
		if displayed_accuracy > accuracy:
			displayed_accuracy = accuracy
		if is_instance_valid(accuracy_label):
			accuracy_label.text = "Точность: %.1f%%" % displayed_accuracy
		finished = false
	
	if displayed_currency < earned_currency:
		displayed_currency += max(1, int(earned_currency * 0.03))
		if displayed_currency > earned_currency:
			displayed_currency = earned_currency
		if is_instance_valid(currency_label):
			currency_label.text = "Валюта: %d" % displayed_currency
		finished = false
	
	if finished:
		animation_timer.stop()
		
		var player_data_manager = get_tree().current_scene.get_node("PlayerDataManager")
		if player_data_manager:
			player_data_manager.add_currency(earned_currency)
		print("💰 Игрок заработал валюту: %d" % earned_currency)

func set_victory_data(p_score: int, p_combo: int, p_max_combo: int, p_accuracy: float, p_song_info: Dictionary = {}):
	call_deferred("_deferred_set_victory_data", p_score, p_combo, p_max_combo, p_accuracy, p_song_info)

func _deferred_set_victory_data(p_score: int, p_combo: int, p_max_combo: int, p_accuracy: float, p_song_info: Dictionary = {}):
	score = p_score
	combo = p_combo
	max_combo = p_max_combo
	accuracy = p_accuracy
	song_info = p_song_info
	
	earned_currency = _calculate_currency()
	
	if song_info.get("title"):
		if is_instance_valid(song_label): 
			song_label.text = song_info["title"]
		else:
			printerr("victory_screen.gd: song_label не найден!")
	
	if is_instance_valid(score_label):
		score_label.text = "Счёт: 0"
	else:
		printerr("victory_screen.gd: score_label не найден!")
	
	if is_instance_valid(combo_label):
		combo_label.text = "Комбо: 0"
	else:
		printerr("victory_screen.gd: combo_label не найден!")
	
	if is_instance_valid(max_combo_label):
		max_combo_label.text = "Макс. комбо: 0"
	else:
		printerr("victory_screen.gd: max_combo_label не найден!")
	
	if is_instance_valid(accuracy_label):
		accuracy_label.text = "Точность: 0%"
	else:
		printerr("victory_screen.gd: accuracy_label не найден!")
	
	if is_instance_valid(currency_label):
		currency_label.text = "Валюта: 0"
	else:
		printerr("victory_screen.gd: currency_label не найден!")

func _calculate_currency() -> int:
	var currency = int(score * 0.01 + max_combo * 0.1 + accuracy * 10)
	return max(0, currency)
