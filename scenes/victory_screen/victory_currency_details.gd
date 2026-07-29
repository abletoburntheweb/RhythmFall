# scenes/victory_screen/victory_currency_details.gd
extends Control

const ACCENT := Color(0.94902, 0.701961, 0.352941, 1.0)

const ICON_BASE := "gauge.svg"
const ICON_COMBO := "zap.svg"
const ICON_ACCURACY := "crosshair.svg"
const ICON_FULL_COMBO := "star.svg"
const ICON_MULTIPLIER := "sparkles.svg"

const COLOR_BASE := Color(0.52549, 0.72549, 0.952941, 1.0)
const COLOR_COMBO := Color(0.647059, 0.556863, 0.858824, 1.0)
const COLOR_ACCURACY := Color(0.47451, 0.890196, 0.835294, 1.0)
const COLOR_FULL_COMBO := Color(0.556863, 0.831373, 0.615686, 1.0)
const COLOR_MULTIPLIER := Color(0.584314, 0.717647, 0.921569, 1.0)

@onready var title_label: Label = $CenterWrap/DialogPanel/Margin/DialogVBox/HeaderHBox/HeaderText/TitleLabel
@onready var subtitle_label: Label = $CenterWrap/DialogPanel/Margin/DialogVBox/HeaderHBox/HeaderText/SubtitleLabel
@onready var hero_total_label: Label = $CenterWrap/DialogPanel/Margin/DialogVBox/HeaderHBox/HeaderText/FinalRewardRow/HeroTotalLabel
@onready var final_reward_caption: Label = $CenterWrap/DialogPanel/Margin/DialogVBox/HeaderHBox/HeaderText/FinalRewardRow/FinalRewardCaption
@onready var footer_total_label: Label = $CenterWrap/DialogPanel/Margin/DialogVBox/FooterHBox/FooterTotalLabel
@onready var footer_value_label: Label = $CenterWrap/DialogPanel/Margin/DialogVBox/FooterHBox/FooterValueLabel
@onready var row_base: HBoxContainer = $CenterWrap/DialogPanel/Margin/DialogVBox/RowsVBox/RowBase
@onready var row_combo: HBoxContainer = $CenterWrap/DialogPanel/Margin/DialogVBox/RowsVBox/RowCombo
@onready var row_accuracy: HBoxContainer = $CenterWrap/DialogPanel/Margin/DialogVBox/RowsVBox/RowAccuracy
@onready var row_full_combo: HBoxContainer = $CenterWrap/DialogPanel/Margin/DialogVBox/RowsVBox/RowFullCombo
@onready var row_multiplier: HBoxContainer = $CenterWrap/DialogPanel/Margin/DialogVBox/RowsVBox/RowMultiplier
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
		title_label.text = tr("VICTORY_CUR_DETAIL_TITLE").to_upper()
	if subtitle_label:
		subtitle_label.text = tr("VICTORY_CUR_DETAIL_SUBTITLE")
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
	p_total_notes: int,
	p_missed_notes: int,
	p_combo_multiplier: float,
	total_currency: int
) -> void:
	_detail_data = {
		"score": p_score,
		"max_combo": p_max_combo,
		"accuracy": p_accuracy,
		"total_notes": p_total_notes,
		"missed_notes": p_missed_notes,
		"combo_multiplier": p_combo_multiplier,
		"total_currency": total_currency,
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
	var p_total_notes := int(_detail_data.get("total_notes", 0))
	var p_missed_notes := int(_detail_data.get("missed_notes", 0))
	var p_combo_multiplier := float(_detail_data.get("combo_multiplier", 1.0))
	var total_currency := int(_detail_data.get("total_currency", 0))

	var base_currency := sqrt(float(p_score)) * 0.9
	var combo_bonus := 0.0
	if p_max_combo > 0:
		combo_bonus = log(float(p_max_combo) + 1.0) * 3.0
	var accuracy_bonus := 0.0
	if p_accuracy >= 100.0:
		accuracy_bonus = 20.0
	elif p_accuracy >= 95.0:
		accuracy_bonus = (p_accuracy - 90.0) * 0.5
	var full_combo_bonus := 0.0
	if p_missed_notes == 0 and p_total_notes > 0:
		full_combo_bonus = 10.0
	var multiplier_bonus := (p_combo_multiplier - 1.0) * 2.0

	var amounts := [
		base_currency,
		combo_bonus,
		accuracy_bonus,
		full_combo_bonus,
		multiplier_bonus,
	]
	var max_amount := 0.0
	for amount in amounts:
		max_amount = maxf(max_amount, amount)

	if hero_total_label:
		hero_total_label.text = str(total_currency)
	if footer_value_label:
		footer_value_label.text = str(total_currency)

	_configure_row(
		row_base,
		ICON_BASE,
		COLOR_BASE,
		tr("VICTORY_REWARD_ROW_BASE"),
		base_currency,
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
		row_accuracy,
		ICON_ACCURACY,
		COLOR_ACCURACY,
		tr("VICTORY_REWARD_ROW_ACCURACY_FMT") % p_accuracy,
		accuracy_bonus,
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
	_configure_row(
		row_multiplier,
		ICON_MULTIPLIER,
		COLOR_MULTIPLIER,
		tr("VICTORY_REWARD_ROW_MULT_FMT") % p_combo_multiplier,
		multiplier_bonus,
		max_amount,
		false
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
