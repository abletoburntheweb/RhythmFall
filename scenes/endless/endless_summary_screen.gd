# scenes/endless/endless_summary_screen.gd
extends BaseScreen

const _PlayModeIds = preload("res://logic/domain/session/play_mode_ids.gd")
const _SeriesSummaryPresentation = preload("res://logic/ui/series_summary_presentation.gd")

var _summary: Dictionary = {}
var _return_to_play_modes := true
var _best_updated := false
var _best_rr_updated := false

@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _streak_label: Label = %StreakLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _accuracy_label: Label = %AccuracyLabel
@onready var _notes_label: Label = %NotesLabel
@onready var _rr_label: Label = %RrLabel
@onready var _xp_label: Label = %XpLabel
@onready var _currency_label: Label = %CurrencyLabel
@onready var _best_label: Label = %BestLabel
@onready var _best_rr_label: Label = %BestRrLabel
@onready var _play_modes_button: Button = %PlayModesButton
@onready var _play_again_button: Button = %PlayAgainButton


func _ready() -> void:
	if _play_modes_button and not _play_modes_button.pressed.is_connected(_on_play_modes_pressed):
		_play_modes_button.pressed.connect(_on_play_modes_pressed)
	if _play_again_button and not _play_again_button.pressed.is_connected(_on_play_again_pressed):
		_play_again_button.pressed.connect(_on_play_again_pressed)
	_SeriesSummaryPresentation.apply(self, _PlayModeIds.ENDLESS)
	apply_locale()
	_refresh_summary()


func set_summary_data(summary: Dictionary, return_to_play_modes: bool = true) -> void:
	_summary = summary if summary is Dictionary else {}
	_return_to_play_modes = return_to_play_modes
	_persist_results()
	if is_node_ready():
		_refresh_summary()


func apply_locale() -> void:
	if _title_label:
		_title_label.text = tr("ENDLESS_SUMMARY_TITLE")
	if _subtitle_label:
		var reason := str(_summary.get("reason", "defeat"))
		var key := "ENDLESS_SUMMARY_SUBTITLE_DEFEAT"
		if reason == "exit":
			key = "ENDLESS_SUMMARY_SUBTITLE_EXIT"
		elif reason == "pool_exhausted":
			key = "ENDLESS_SUMMARY_SUBTITLE_POOL"
		elif reason == "complete":
			key = "ENDLESS_SUMMARY_SUBTITLE_COMPLETE"
		_subtitle_label.text = tr(key)
	if _play_modes_button:
		_play_modes_button.text = tr("ENDLESS_SUMMARY_TO_PLAY_MODES")
	if _play_again_button:
		_play_again_button.text = tr("ENDLESS_SUMMARY_PLAY_AGAIN")
	_refresh_summary()


func _refresh_summary() -> void:
	var streak := int(_summary.get("streak", 0))
	if _streak_label:
		_streak_label.text = tr("ENDLESS_SUMMARY_STREAK_FMT") % streak
	if _score_label:
		_score_label.text = tr("ENDLESS_SUMMARY_SCORE_FMT") % int(_summary.get("total_score", 0))
	if _accuracy_label:
		_accuracy_label.text = tr("ENDLESS_SUMMARY_ACCURACY_FMT") % float(_summary.get("average_accuracy", 0.0))
	if _notes_label:
		_notes_label.text = tr("ENDLESS_SUMMARY_NOTES_FMT") % int(_summary.get("total_hit_notes", 0))
	if _rr_label:
		_rr_label.visible = false
	if _xp_label:
		_xp_label.text = tr("ENDLESS_SUMMARY_XP_FMT") % int(_summary.get("earned_xp", 0))
	if _currency_label:
		_currency_label.text = tr("ENDLESS_SUMMARY_CURRENCY_FMT") % int(_summary.get("earned_currency", 0))
	if _best_label:
		if _best_updated:
			_best_label.text = tr("ENDLESS_SUMMARY_NEW_BEST_FMT") % streak
			_best_label.visible = true
		else:
			_best_label.visible = false
	if _best_rr_label:
		_best_rr_label.visible = false


func _persist_results() -> void:
	var meta := persist_summary(_summary)
	_best_updated = bool(meta.get("best_streak_updated", false))
	_best_rr_updated = bool(meta.get("best_series_rr_updated", false))


static func persist_summary(summary: Dictionary) -> Dictionary:
	if PlayerDataManager == null or summary.is_empty():
		return {}
	var xp := int(summary.get("earned_xp", 0))
	var currency := int(summary.get("earned_currency", 0))
	if PlayerDataManager.has_method("grant_endless_run_rewards"):
		PlayerDataManager.grant_endless_run_rewards(xp, currency)
	else:
		if xp > 0:
			PlayerDataManager.add_xp(xp)
		if currency > 0:
			PlayerDataManager.add_currency(currency)
		PlayerDataManager.flush_save()
	var meta: Dictionary = {}
	if PlayerDataManager.has_method("update_endless_best_streak"):
		meta["best_streak_updated"] = PlayerDataManager.update_endless_best_streak(int(summary.get("streak", 0)))
	if PlayerDataManager.has_method("record_endless_run"):
		var record_meta: Dictionary = PlayerDataManager.record_endless_run(summary)
		for key in record_meta.keys():
			meta[key] = record_meta[key]
	var achievement_mgr = PlayerDataManager.achievement_manager
	if achievement_mgr != null and achievement_mgr.has_method("check_endless_run_achievements"):
		achievement_mgr.check_endless_run_achievements(summary, PlayerDataManager)
	return meta


func _on_play_modes_pressed() -> void:
	MusicManager.play_select_sound()
	if transitions:
		transitions.open_play_modes()


func _on_play_again_pressed() -> void:
	MusicManager.play_select_sound()
	var config: Dictionary = _summary.get("config", {})
	if transitions == null:
		return
	if config is Dictionary and not config.is_empty() and transitions.has_method("open_endless_run"):
		transitions.open_endless_run(config)
		return
	if transitions.has_method("open_endless_session_setup_from_play_modes"):
		transitions.open_endless_session_setup_from_play_modes()


func _execute_close_transition() -> void:
	if transitions:
		if _return_to_play_modes:
			transitions.open_play_modes()
		else:
			transitions.open_main_menu()
