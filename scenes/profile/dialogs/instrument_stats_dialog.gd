# scenes/profile/dialogs/instrument_stats_dialog.gd
class_name InstrumentStatsDialog
extends Control

signal closed()

const _ProfileInstrumentStats = preload("res://logic/domain/profile/profile_instrument_stats.gd")
const _InstrumentStatsCardScene = preload("res://scenes/profile/components/instrument_stats_card.tscn")
const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")
const _UiModifierSounds = preload("res://logic/ui/ui_modifier_sounds.gd")

@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _footer_label: Label = %FooterHintLabel
@onready var _cards_row: HBoxContainer = %CardsRow

var _cards: Dictionary = {}


func _ready() -> void:
	visible = false
	add_to_group("locale_refresh")
	UiIconHelper.configure_modal_overlay(self, 105)
	_build_cards()
	if _back_button and not _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.connect(_on_back_pressed)
	apply_locale()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func apply_locale() -> void:
	if _back_button:
		_back_button.text = tr("BTN_BACK")
		_UiIconHelper.setup_back_button(_back_button)
	if _title_label:
		_title_label.text = tr("PROFILE_STAT_INSTR_TITLE")
	if _subtitle_label:
		_subtitle_label.text = tr("PROFILE_STAT_INSTR_MODAL_SUB")
	if _footer_label:
		_footer_label.text = tr("PROFILE_STAT_INSTR_MODAL_FOOTER")
	_refresh_cards()


func open(history: Array = []) -> void:
	_refresh_cards(history)
	visible = true
	if _back_button:
		_back_button.grab_focus()
	_play_entrance()


func _refresh_cards(history: Array = []) -> void:
	var bass_summary := _ProfileInstrumentStats.bass_summary(history)
	var drums_summary := _ProfileInstrumentStats.drums_summary(history)
	var progress_caption := tr("PROFILE_STAT_INSTR_PROGRESS_CAPTION")
	for instrument_id in _ProfileInstrumentStats.instrument_ids():
		var card: InstrumentStatsCard = _cards.get(instrument_id)
		if card == null:
			continue
		var spec: Dictionary = _ProfileInstrumentStats.instrument_spec(instrument_id)
		var summary: Dictionary = drums_summary if instrument_id == "drums" else bass_summary
		var rows: Array = _ProfileInstrumentStats.stat_rows(instrument_id, summary)
		for row in rows:
			if row is Dictionary:
				(row as Dictionary)["label"] = tr(str((row as Dictionary).get("label_key", "")))
		card.setup(
			instrument_id,
			tr(str(spec.get("title_key", ""))),
			tr(str(spec.get("subtitle_key", ""))),
			str(spec.get("icon", "")),
			spec.get("accent", Color.WHITE),
			rows,
			progress_caption,
		)


func _build_cards() -> void:
	if _cards_row == null:
		return
	for child in _cards_row.get_children():
		child.queue_free()
	_cards.clear()
	for instrument_id in _ProfileInstrumentStats.instrument_ids():
		var card: InstrumentStatsCard = _InstrumentStatsCardScene.instantiate() as InstrumentStatsCard
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_cards_row.add_child(card)
		_cards[instrument_id] = card


func _play_entrance() -> void:
	if _cards_row == null:
		return
	var index := 0
	for instrument_id in _ProfileInstrumentStats.instrument_ids():
		var card: Control = _cards.get(instrument_id)
		if card == null:
			continue
		card.modulate.a = 0.0
		var tw := card.create_tween()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "modulate:a", 1.0, 0.34).set_delay(float(index) * 0.07)
		index += 1


func _on_back_pressed() -> void:
	_close()


func _close() -> void:
	if not visible:
		return
	_UiModifierSounds.play_deselect()
	visible = false
	closed.emit()
