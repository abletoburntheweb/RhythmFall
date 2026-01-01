# scenes/victory_screen/victory_xp_details.gd
extends Control

@onready var background: ColorRect = $Background
@onready var title_label: Label = $TitleLabel
@onready var base_xp_label: Label = $StatsFrame/BaseXPLabel
@onready var accuracy_bonus_label: Label = $StatsFrame/AccuracyBonusLabel
@onready var combo_bonus_label: Label = $StatsFrame/ComboBonusLabel
@onready var grade_bonus_label: Label = $StatsFrame/GradeBonusLabel
@onready var full_combo_bonus_label: Label = $StatsFrame/FullComboBonusLabel
@onready var total_xp_label: Label = $StatsFrame/TotalXPLabel
@onready var back_button: Button = $ButtonsContainer/BackButton

signal details_closed

var music_manager = null

func _ready():
	visible = false
	
	var parent = get_parent()
	if parent and parent.get_parent() and parent.get_parent().has_method("get_music_manager"):
		music_manager = parent.get_parent().get_music_manager()
	
	back_button.pressed.connect(_on_back_pressed)

func show_details(p_score: int, p_max_combo: int, p_accuracy: float, p_missed_notes: int, p_grade: String, total_xp: int):
	var base_xp = float(p_score) / 200.0
	
	var accuracy_bonus = 0.0
	if p_accuracy >= 100.0:
		accuracy_bonus = 50.0
	elif p_accuracy >= 98.0:
		accuracy_bonus = 30.0
	elif p_accuracy >= 95.0:
		accuracy_bonus = 20.0
	elif p_accuracy >= 90.0:
		accuracy_bonus = 10.0

	var combo_bonus = float(p_max_combo) / 10.0

	var grade_bonus = 0.0
	match p_grade:
		"SS": grade_bonus = 100.0
		"S": grade_bonus = 50.0
		"A": grade_bonus = 25.0
		"B": grade_bonus = 10.0
		"C": grade_bonus = 0.0
		"D": grade_bonus = -10.0
		"F": grade_bonus = -20.0

	var full_combo_bonus = 0.0
	if p_missed_notes == 0:
		full_combo_bonus = 50.0

	base_xp_label.text = "Базовый XP (от счёта): %.1f" % base_xp
	accuracy_bonus_label.text = "Бонус за точность: %.1f" % accuracy_bonus
	combo_bonus_label.text = "Бонус за комбо: %.1f" % combo_bonus
	grade_bonus_label.text = "Бонус за оценку (%s): %.1f" % [p_grade, grade_bonus]
	full_combo_bonus_label.text = "Бонус за полное комбо: %.1f" % full_combo_bonus
	total_xp_label.text = "Итого XP: %d" % total_xp
	
	visible = true
	grab_focus()

func _on_back_pressed():
	if music_manager and music_manager.has_method("play_cancel_sound"):
		music_manager.play_cancel_sound()
	elif music_manager and music_manager.has_method("play_select_sound"):
		music_manager.play_select_sound()
	
	visible = false
	emit_signal("details_closed")

func _input(event):
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_back_pressed()
