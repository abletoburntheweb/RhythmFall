# scenes/victory_screen/victory_xp_details.gd
extends Control

const ACCENT := Color(0.34902, 0.819608, 0.745098, 1.0)

const ICON_BASE := "gauge.svg"
const ICON_ACCURACY := "crosshair.svg"
const ICON_COMBO := "zap.svg"
const ICON_GRADE := "star.svg"
const ICON_FULL_COMBO := "sparkles.svg"

const COLOR_BASE := Color(0.52549, 0.72549, 0.952941, 1.0)
const COLOR_ACCURACY := Color(0.34902, 0.819608, 0.745098, 1.0)
const COLOR_COMBO := Color(0.647059, 0.556863, 0.858824, 1.0)
const COLOR_GRADE := Color(0.94902, 0.701961, 0.352941, 1.0)
const COLOR_FULL_COMBO := Color(0.556863, 0.831373, 0.615686, 1.0)

@onready var title_label: Label = $CenterWrap/DialogPanel/Margin/DialogVBox/HeaderHBox/HeaderText/TitleLabel
@onready var subtitle_label: Label = $CenterWrap/DialogPanel/Margin/DialogVBox/HeaderHBox/HeaderText/SubtitleLabel
@onready var hero_total_label: Label = $CenterWrap/DialogPanel/Margin/DialogVBox/HeaderHBox/HeaderText/FinalRewardRow/HeroTotalLabel
@onready var final_reward_caption: Label = $CenterWrap/DialogPanel/Margin/DialogVBox/HeaderHBox/HeaderText/FinalRewardRow/FinalRewardCaption
@onready var footer_total_label: Label = $CenterWrap/DialogPanel/Margin/DialogVBox/FooterHBox/FooterTotalLabel
@onready var footer_value_label: Label = $CenterWrap/DialogPanel/Margin/DialogVBox/FooterHBox/FooterValueLabel
@onready var row_base: HBoxContainer = $CenterWrap/DialogPanel/Margin/DialogVBox/RowsVBox/RowBase
@onready var row_accuracy: HBoxContainer = $CenterWrap/DialogPanel/Margin/DialogVBox/RowsVBox/RowAccuracy
@onready var row_combo: HBoxContainer = $CenterWrap/DialogPanel/Margin/DialogVBox/RowsVBox/RowCombo
@onready var row_grade: HBoxContainer = $CenterWrap/DialogPanel/Margin/DialogVBox/RowsVBox/RowGrade
@onready var row_full_combo: HBoxContainer = $CenterWrap/DialogPanel/Margin/DialogVBox/RowsVBox/RowFullCombo
@onready var close_button: Button = $CenterWrap/DialogPanel/Margin/DialogVBox/CloseButton

signal details_closed

var _detail_data: Dictionary = {}


func _ready() -> void:
	add_to_group("locale_refresh")
	visible = false
	close_button.pressed.connect(_on_back_pressed)
	call_deferred("apply_locale")


func apply_locale() -> void:
	if title_label:
		title_label.text = tr("VICTORY_XP_DETAIL_TITLE").to_upper()
	if subtitle_label:
		subtitle_label.text = tr("VICTORY_XP_DETAIL_SUBTITLE")
	if final_reward_caption:
		final_reward_caption.text = tr("VICTORY_REWARD_FINAL_LABEL")
	if footer_total_label:
		footer_total_label.text = tr("VICTORY_REWARD_TOTAL_RECEIVED").to_upper()
	if close_button:
		close_button.text = tr("VICTORY_REWARD_BTN_CLOSE").to_upper()
	if not _detail_data.is_empty():
		_apply_detail_texts()


func show_details(
	p_score: int,
	p_max_combo: int,
	p_accuracy: float,
	p_missed_notes: int,
	p_grade: String,
	total_xp: int
) -> void:
	_detail_data = {
		"score": p_score,
		"max_combo": p_max_combo,
		"accuracy": p_accuracy,
		"missed_notes": p_missed_notes,
		"grade": p_grade,
		"total_xp": total_xp,
	}
	_apply_detail_texts()
	visible = true
	grab_focus()


func _apply_detail_texts() -> void:
	if _detail_data.is_empty():
		return
	var p_score := int(_detail_data.get("score", 0))
	var p_max_combo := int(_detail_data.get("max_combo", 0))
	var p_accuracy := float(_detail_data.get("accuracy", 0.0))
	var p_missed_notes := int(_detail_data.get("missed_notes", 0))
	var p_grade := str(_detail_data.get("grade", ""))
	var total_xp := int(_detail_data.get("total_xp", 0))

	var base_xp := sqrt(float(p_score)) * 1.2
	var accuracy_bonus := 0.0
	if p_accuracy >= 100.0:
		accuracy_bonus = 20.0
	elif p_accuracy >= 98.0:
		accuracy_bonus = 12.0
	elif p_accuracy >= 95.0:
		accuracy_bonus = 7.0
	elif p_accuracy >= 90.0:
		accuracy_bonus = 2.0
	var combo_bonus := 0.0
	if p_max_combo > 0:
		combo_bonus = log(float(p_max_combo) + 1.0) * 6.0
	var grade_bonus := 0.0
	match p_grade:
		"SS":
			grade_bonus = 50.0
		"S":
			grade_bonus = 25.0
		"A":
			grade_bonus = 10.0
		"B":
			grade_bonus = 3.0
	var full_combo_bonus := 0.0
	if p_missed_notes == 0 and p_max_combo > 0:
		full_combo_bonus = 15.0

	var amounts := [
		base_xp,
		accuracy_bonus,
		combo_bonus,
		grade_bonus,
		full_combo_bonus,
	]
	var max_amount := 0.0
	for amount in amounts:
		max_amount = maxf(max_amount, amount)

	if hero_total_label:
		hero_total_label.text = str(total_xp)
	if footer_value_label:
		footer_value_label.text = str(total_xp)

	_configure_row(row_base, ICON_BASE, COLOR_BASE, tr("VICTORY_REWARD_ROW_BASE"), base_xp, max_amount)
	_configure_row(
		row_accuracy,
		ICON_ACCURACY,
		COLOR_ACCURACY,
		tr("VICTORY_REWARD_ROW_ACCURACY_FMT") % p_accuracy,
		accuracy_bonus,
		max_amount
	)
	_configure_row(
		row_combo,
		ICON_COMBO,
		COLOR_COMBO,
		tr("VICTORY_REWARD_ROW_COMBO_FMT") % p_max_combo,
		combo_bonus,
		max_amount
	)
	_configure_row(
		row_grade,
		ICON_GRADE,
		COLOR_GRADE,
		tr("VICTORY_REWARD_ROW_GRADE_FMT") % p_grade,
		grade_bonus,
		max_amount
	)
	_configure_row(
		row_full_combo,
		ICON_FULL_COMBO,
		COLOR_FULL_COMBO,
		tr("VICTORY_REWARD_ROW_FULL_COMBO"),
		full_combo_bonus,
		max_amount
	)


func _configure_row(
	row: HBoxContainer,
	icon_file: String,
	icon_color: Color,
	title_text: String,
	amount: float,
	max_amount: float,
	hide_when_zero: bool = true
) -> void:
	if row == null or not row.has_method("configure"):
		return
	row.configure(icon_file, icon_color, title_text, amount, max_amount, ACCENT, hide_when_zero)


func _on_back_pressed() -> void:
	MusicManager.play_modifier_deselect_sound()
	visible = false
	_detail_data.clear()
	emit_signal("details_closed")


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_back_pressed()
