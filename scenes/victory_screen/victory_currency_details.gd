# scenes/victory_screen/victory_currency_details.gd
extends Control

@onready var background: ColorRect = $Background
@onready var title_label: Label = $TitleLabel
@onready var score_label: Label = $StatsFrame/ScoreLabel
@onready var combo_label: Label = $StatsFrame/ComboLabel
@onready var accuracy_label: Label = $StatsFrame/AccuracyLabel
@onready var full_combo_label: Label = $StatsFrame/FullComboLabel
@onready var multiplier_label: Label = $StatsFrame/MultiplierLabel
@onready var total_label: Label = $StatsFrame/TotalLabel
@onready var back_button: Button = $ButtonsContainer/BackButton

signal details_closed

func _ready():
	visible = false
	back_button.pressed.connect(_on_back_pressed)

func show_details(p_score: int, p_max_combo: int, p_accuracy: float, p_total_notes: int, p_missed_notes: int, p_combo_multiplier: float, total_currency: int):
	var base_currency = float(p_score) / 100.0
	var accuracy_bonus = 0.0
	if p_accuracy >= 95.0 and p_accuracy < 100.0:
		accuracy_bonus = (p_accuracy - 90.0) * 1.5
	elif p_accuracy >= 100.0:
		accuracy_bonus = 50.0
	var full_combo_bonus = 0.0
	if p_missed_notes == 0 and p_total_notes > 0:
		full_combo_bonus = 20.0
	var multiplier_bonus = (p_combo_multiplier - 1.0) * 5.0
	
	score_label.text = "Счёт: %.1f" % base_currency
	combo_label.text = "Макс. комбо: %d" % p_max_combo
	accuracy_label.text = "Точность: %.1f" % accuracy_bonus
	full_combo_label.text = "Полное комбо: %.1f" % full_combo_bonus
	multiplier_label.text = "Бонус за множитель: %.1f" % multiplier_bonus
	total_label.text = "Валюта: %d" % total_currency
	
	visible = true
	grab_focus()

func _on_back_pressed():
	MusicManager.play_cancel_sound()
	visible = false
	emit_signal("details_closed")

func _input(event):
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_back_pressed()
