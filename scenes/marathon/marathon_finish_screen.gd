# scenes/marathon/marathon_finish_screen.gd
extends BaseScreen

const _MarathonRouteCatalog = preload("res://logic/domain/session/marathon_route_catalog.gd")
const _MarathonRouteBadges = preload("res://logic/domain/session/marathon_route_badges.gd")
const _PlayModeIds = preload("res://logic/domain/session/play_mode_ids.gd")
const _SeriesSummaryPresentation = preload("res://logic/ui/series_summary_presentation.gd")

var _summary: Dictionary = {}
var _return_to_catalog := true
var _best_updated := false
var _badge_improved := false
var _earned_badges: Array = []
var _newly_earned_badges: Array = []

@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _progress_label: Label = %ProgressLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _accuracy_label: Label = %AccuracyLabel
@onready var _notes_label: Label = %NotesLabel
@onready var _rr_label: Label = %RrLabel
@onready var _xp_label: Label = %XpLabel
@onready var _currency_label: Label = %CurrencyLabel
@onready var _best_label: Label = %BestLabel
@onready var _badges_label: Label = %BadgesLabel
@onready var _catalog_button: Button = %CatalogButton
@onready var _play_again_button: Button = %PlayAgainButton


func _ready() -> void:
	if _catalog_button and not _catalog_button.pressed.is_connected(_on_catalog_pressed):
		_catalog_button.pressed.connect(_on_catalog_pressed)
	if _play_again_button and not _play_again_button.pressed.is_connected(_on_play_again_pressed):
		_play_again_button.pressed.connect(_on_play_again_pressed)
	_SeriesSummaryPresentation.apply(self, _PlayModeIds.MARATHON)
	apply_locale()
	_refresh_summary()


func set_summary_data(summary: Dictionary, return_to_catalog: bool = true) -> void:
	_summary = summary if summary is Dictionary else {}
	_return_to_catalog = return_to_catalog
	_persist_results()
	if is_node_ready():
		_refresh_summary()


func apply_locale() -> void:
	if _title_label:
		_title_label.text = tr("MARATHON_FINISH_TITLE")
	if _subtitle_label:
		var reason := str(_summary.get("reason", "defeat"))
		var key := "MARATHON_FINISH_SUBTITLE_DEFEAT"
		match reason:
			"victory":
				key = "MARATHON_FINISH_SUBTITLE_VICTORY"
			"exit":
				key = "MARATHON_FINISH_SUBTITLE_EXIT"
			"rule_min_accuracy":
				key = "MARATHON_FINISH_SUBTITLE_RULE_MIN_ACCURACY"
			"rule_max_misses":
				key = "MARATHON_FINISH_SUBTITLE_RULE_MAX_MISSES"
		_subtitle_label.text = tr(key)
	if _catalog_button:
		_catalog_button.text = tr("MARATHON_FINISH_TO_CATALOG")
	if _play_again_button:
		_play_again_button.text = tr("MARATHON_FINISH_RETRY")
	_refresh_summary()


func _refresh_summary() -> void:
	var cleared := int(_summary.get("tracks_cleared", 0))
	var total := int(_summary.get("total_tracks", 0))
	if _progress_label:
		_progress_label.text = tr("MARATHON_FINISH_PROGRESS_FMT") % [cleared, total]
	if _score_label:
		_score_label.text = tr("MARATHON_FINISH_SCORE_FMT") % int(_summary.get("total_score", 0))
	if _accuracy_label:
		_accuracy_label.text = tr("MARATHON_FINISH_ACCURACY_FMT") % float(_summary.get("average_accuracy", 0.0))
	if _notes_label:
		_notes_label.text = tr("MARATHON_FINISH_NOTES_FMT") % int(_summary.get("total_hit_notes", 0))
	if _rr_label:
		_rr_label.text = tr("MARATHON_FINISH_RR_FMT") % int(_summary.get("series_rr", 0))
	if _xp_label:
		_xp_label.text = tr("MARATHON_FINISH_XP_FMT") % int(_summary.get("earned_xp", 0))
	if _currency_label:
		_currency_label.text = tr("MARATHON_FINISH_CURRENCY_FMT") % int(_summary.get("earned_currency", 0))
	if _best_label:
		if _best_updated:
			_best_label.text = tr("MARATHON_FINISH_NEW_BEST")
			_best_label.visible = true
		else:
			_best_label.visible = false
	if _badges_label:
		if _earned_badges.is_empty() or str(_summary.get("reason", "")) != "victory":
			_badges_label.visible = false
		else:
			var route_id := str(_summary.get("route_id", "")).strip_edges()
			var template: Dictionary = {}
			if _summary.get("template") is Dictionary:
				template = (_summary.get("template") as Dictionary).duplicate(true)
			elif route_id != "":
				template = _MarathonRouteCatalog.template_for_route(route_id)
			var earned_text := _MarathonRouteBadges.format_earned_badges(route_id, _earned_badges, template)
			if _newly_earned_badges.is_empty():
				_badges_label.text = tr("MARATHON_FINISH_BADGES_FMT") % earned_text
			else:
				var new_text := _MarathonRouteBadges.format_earned_badges(route_id, _newly_earned_badges, template)
				_badges_label.text = tr("MARATHON_FINISH_BADGES_NEW_FMT") % [new_text, earned_text]
			_badges_label.visible = earned_text != ""


func _persist_results() -> void:
	var meta := persist_summary(_summary)
	_apply_persist_meta(meta)


static func persist_summary(summary: Dictionary) -> Dictionary:
	if PlayerDataManager == null or summary.is_empty():
		return {}
	var xp := int(summary.get("earned_xp", 0))
	var currency := int(summary.get("earned_currency", 0))
	if PlayerDataManager.has_method("grant_marathon_run_rewards"):
		PlayerDataManager.grant_marathon_run_rewards(xp, currency)
	elif PlayerDataManager.has_method("grant_endless_run_rewards"):
		PlayerDataManager.grant_endless_run_rewards(xp, currency)
	var meta: Dictionary = {}
	if PlayerDataManager.has_method("record_marathon_run"):
		meta = PlayerDataManager.record_marathon_run(summary)
	var achievement_mgr = PlayerDataManager.achievement_manager
	if achievement_mgr != null and achievement_mgr.has_method("check_marathon_run_achievements"):
		achievement_mgr.check_marathon_run_achievements(summary, PlayerDataManager)
	return meta


func _apply_persist_meta(meta: Dictionary) -> void:
	_best_updated = bool(meta.get("best_updated", false))
	_badge_improved = bool(meta.get("badge_improved", false))
	if meta.get("earned_this_run") is Array:
		_earned_badges = (meta.get("earned_this_run") as Array).duplicate()
	if meta.get("newly_earned") is Array:
		_newly_earned_badges = (meta.get("newly_earned") as Array).duplicate()


func _on_catalog_pressed() -> void:
	MusicManager.play_select_sound()
	if transitions:
		transitions.open_marathon_catalog_from_play_modes()


func _on_play_again_pressed() -> void:
	MusicManager.play_select_sound()
	var route_id := str(_summary.get("route_id", "")).strip_edges()
	if route_id == "":
		route_id = _MarathonRouteCatalog.route_id_for_group(str(_summary.get("genre_group_id", "")).strip_edges())
	if transitions == null or route_id == "":
		return
	var run_config: Dictionary = {}
	if _summary.get("run_config") is Dictionary:
		run_config = (_summary.get("run_config") as Dictionary).duplicate(true)
	if transitions.has_method("open_marathon_run"):
		transitions.open_marathon_run(route_id, run_config)


func _execute_close_transition() -> void:
	if transitions:
		if _return_to_catalog:
			transitions.open_marathon_catalog_from_play_modes()
		else:
			transitions.open_play_modes()
