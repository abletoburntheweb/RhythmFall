# scenes/series_finish/series_finish_screen.gd
extends BaseScreen

const _PlayModeIds = preload("res://logic/domain/session/play_mode_ids.gd")
const _SeriesFinishPresentation = preload("res://logic/ui/series_finish_presentation.gd")
const _EndlessSummaryScreen = preload("res://scenes/endless/endless_summary_screen.gd")
const _MarathonFinishScreen = preload("res://scenes/marathon/marathon_finish_screen.gd")
const _MarathonRouteCatalog = preload("res://logic/domain/session/marathon_route_catalog.gd")
const _MarathonRouteBadges = preload("res://logic/domain/session/marathon_route_badges.gd")
const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")

var _summary: Dictionary = {}
var _return_flag := true
var _best_streak_updated := false
var _best_rr_updated := false
var _best_route_updated := false
var _earned_badges: Array = []
var _newly_earned_badges: Array = []
var _persisted := false

@onready var _hero_ring: Control = %HeroRing
@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _meta_label: Label = %MetaLabel
@onready var _record_banner: Label = %RecordBanner

@onready var _top_stat_0_value: Label = %TopStat0Value
@onready var _top_stat_0_caption: Label = %TopStat0Caption
@onready var _top_stat_0_note: Label = %TopStat0Note
@onready var _top_stat_1_value: Label = %TopStat1Value
@onready var _top_stat_1_caption: Label = %TopStat1Caption
@onready var _top_stat_1_note: Label = %TopStat1Note

@onready var _score_value: Label = %ScoreValue
@onready var _combo_value: Label = %ComboValue
@onready var _max_combo_value: Label = %MaxComboValue
@onready var _accuracy_value: Label = %AccuracyValue
@onready var _perfect_value: Label = %PerfectValue
@onready var _good_value: Label = %GoodValue
@onready var _miss_value: Label = %MissValue

@onready var _rewards_title: Label = %RewardsTitle
@onready var _currency_label: Label = %CurrencyLabel
@onready var _xp_label: Label = %XpLabel
@onready var _xp_progress_bar: ProgressBar = %XpProgressBar
@onready var _xp_progress_label: Label = %XpProgressLabel

@onready var _chart_title: Label = %ChartTitle
@onready var _accuracy_chart: Control = %VictoryAccuracyChart

@onready var _lane_stats_panel: PanelContainer = %LaneStatsPanel
@onready var _lane_stats_title: Label = %LaneStatsTitle
@onready var _lane_stats_chart: Control = %VictoryLaneStats

@onready var _route_badges_panel: PanelContainer = %RouteBadgesPanel
@onready var _route_badges_title: Label = %RouteBadgesTitle
@onready var _route_badges_row: HBoxContainer = %RouteBadgesRow

@onready var _back_button: Button = %BackButton
@onready var _play_again_button: Button = %PlayAgainButton
@onready var _secondary_button: Button = %SecondaryButton


func _ready() -> void:
	if _back_button and not _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.connect(_on_back_pressed)
	if _play_again_button and not _play_again_button.pressed.is_connected(_on_play_again_pressed):
		_play_again_button.pressed.connect(_on_play_again_pressed)
	if _secondary_button and not _secondary_button.pressed.is_connected(_on_secondary_pressed):
		_secondary_button.pressed.connect(_on_secondary_pressed)
	_refresh_all()


func set_summary_data(summary: Dictionary, return_flag: bool = true) -> void:
	_summary = summary if summary is Dictionary else {}
	_return_flag = return_flag
	_persisted = false
	_persist_results()
	if is_node_ready():
		_refresh_all()


func apply_locale() -> void:
	_refresh_all()


func get_ambient_screen_profile() -> StringName:
	if _is_marathon():
		return &"series_finish_marathon"
	return &"series_finish_endless"


func _mode_id() -> String:
	var mid := str(_summary.get("mode_id", "")).strip_edges()
	if mid == _PlayModeIds.MARATHON:
		return _PlayModeIds.MARATHON
	return _PlayModeIds.ENDLESS


func _is_marathon() -> bool:
	return _mode_id() == _PlayModeIds.MARATHON


func _refresh_all() -> void:
	var mode_id := _mode_id()
	var accent: Color = _PlayModeIds.accent_for(mode_id)
	_SeriesFinishPresentation.apply(self, mode_id)
	_apply_ambient_profile()
	if _hero_ring and _hero_ring.has_method("configure"):
		_hero_ring.configure(mode_id, accent)
	_refresh_header()
	_refresh_top_stats()
	_refresh_stat_grid()
	_refresh_lane_stats()
	_refresh_rewards()
	_refresh_chart(accent)
	_refresh_side_panels()
	_refresh_buttons()


func _apply_ambient_profile() -> void:
	var engine := get_parent()
	if engine == null or not engine.has_method("set_ambient_screen_profile"):
		return
	if engine.has_method("set_ambient_motion_active"):
		engine.set_ambient_motion_active(true)
	engine.set_ambient_screen_profile(get_ambient_screen_profile())


func _refresh_header() -> void:
	var marathon := _is_marathon()
	if _title_label:
		_title_label.text = tr("MARATHON_FINISH_TITLE" if marathon else "ENDLESS_SUMMARY_TITLE")
	if _subtitle_label:
		_subtitle_label.text = _subtitle_for_reason()
	if _meta_label:
		_meta_label.text = _build_meta_line()
	if _record_banner:
		var notes: PackedStringArray = []
		if marathon:
			if _best_route_updated:
				notes.append(tr("MARATHON_FINISH_NEW_BEST"))
			if str(_summary.get("reason", "")) == "victory":
				notes.append(tr("SERIES_FINISH_ROUTE_CLEARED"))
		else:
			if _best_streak_updated:
				notes.append(tr("ENDLESS_SUMMARY_NEW_BEST_FMT") % int(_summary.get("streak", 0)))
		_record_banner.text = " · ".join(notes)
		_record_banner.visible = not notes.is_empty()


func _subtitle_for_reason() -> String:
	var reason := str(_summary.get("reason", "defeat"))
	if _is_marathon():
		match reason:
			"victory":
				return tr("MARATHON_FINISH_SUBTITLE_VICTORY")
			"exit":
				return tr("MARATHON_FINISH_SUBTITLE_EXIT")
			"rule_min_accuracy":
				return tr("MARATHON_FINISH_SUBTITLE_RULE_MIN_ACCURACY")
			"rule_max_misses":
				return tr("MARATHON_FINISH_SUBTITLE_RULE_MAX_MISSES")
			_:
				return tr("MARATHON_FINISH_SUBTITLE_DEFEAT")
	match reason:
		"exit":
			return tr("ENDLESS_SUMMARY_SUBTITLE_EXIT")
		"pool_exhausted":
			return tr("ENDLESS_SUMMARY_SUBTITLE_POOL")
		"complete":
			return tr("ENDLESS_SUMMARY_SUBTITLE_COMPLETE")
		_:
			return tr("ENDLESS_SUMMARY_SUBTITLE_DEFEAT")


func _build_meta_line() -> String:
	var parts: PackedStringArray = []
	if _is_marathon():
		var cleared := int(_summary.get("tracks_cleared", 0))
		var total := int(_summary.get("total_tracks", 0))
		parts.append("%d / %d" % [cleared, total])
		var route_id := str(_summary.get("route_id", "")).strip_edges()
		if route_id != "":
			parts.append(route_id)
	else:
		parts.append(tr("SERIES_FINISH_TRACKS_META_FMT") % int(_summary.get("streak", 0)))
		var config: Dictionary = _summary.get("config", {}) if _summary.get("config") is Dictionary else {}
		var instrument := str(config.get("instrument", "")).strip_edges()
		if instrument != "":
			parts.append(instrument)
	var last := _last_track_entry()
	if not last.is_empty():
		var title := str(last.get("title", "")).strip_edges()
		if title != "":
			parts.append(title)
	return " · ".join(parts)


func _refresh_top_stats() -> void:
	var rr := int(_summary.get("series_rr", 0))
	var rr_text := "%+d" % rr if rr != 0 else "0"
	if _is_marathon():
		var cleared := int(_summary.get("tracks_cleared", 0))
		var total := int(_summary.get("total_tracks", 0))
		_set_top_stat(0, "%d / %d" % [cleared, total], tr("SERIES_FINISH_TOP_PROGRESS"), _top_note_progress())
		_set_top_stat(
			1,
			rr_text,
			tr("SERIES_FINISH_TOP_RR_ROUTE"),
			tr("SERIES_FINISH_NEW_RECORD") if _best_route_updated else ""
		)
	else:
		_set_top_stat(
			0,
			str(int(_summary.get("streak", 0))),
			tr("SERIES_FINISH_TOP_TRACKS"),
			tr("SERIES_FINISH_NEW_RECORD") if _best_streak_updated else ""
		)
		var avg_acc := float(_summary.get("average_accuracy", 0.0))
		_set_top_stat(
			1,
			"%.1f%%" % avg_acc,
			tr("SERIES_FINISH_TOP_AVG_ACC"),
			""
		)


func _top_note_progress() -> String:
	if str(_summary.get("reason", "")) == "victory":
		return tr("SERIES_FINISH_ROUTE_CLEARED")
	return ""


func _set_top_stat(index: int, value: String, caption: String, note: String) -> void:
	var value_lbl: Label = [_top_stat_0_value, _top_stat_1_value][index]
	var caption_lbl: Label = [_top_stat_0_caption, _top_stat_1_caption][index]
	var note_lbl: Label = [_top_stat_0_note, _top_stat_1_note][index]
	if value_lbl:
		value_lbl.text = value
	if caption_lbl:
		caption_lbl.text = caption
	if note_lbl:
		note_lbl.text = note
		note_lbl.visible = note.strip_edges() != ""


func _refresh_stat_grid() -> void:
	_set_stat_caption("ScoreTile", "VICTORY_STAT_SCORE")
	_set_stat_caption("ComboTile", "VICTORY_STAT_COMBO")
	_set_stat_caption("MaxComboTile", "VICTORY_STAT_MAX_COMBO")
	_set_stat_caption("AccuracyTile", "VICTORY_STAT_ACCURACY")
	_set_stat_caption("PerfectTile", "VICTORY_STAT_PERFECT")
	_set_stat_caption("GoodTile", "VICTORY_STAT_GOOD")
	_set_stat_caption("MissTile", "VICTORY_STAT_MISS")
	_ensure_stat_icons()
	var perfect := int(_summary.get("total_perfect_hits", 0))
	var hit := int(_summary.get("total_hit_notes", 0))
	var good := maxi(0, hit - perfect)
	if _score_value:
		_score_value.text = str(int(_summary.get("total_score", 0)))
	if _combo_value:
		_combo_value.text = str(int(_summary.get("ending_combo", 0)))
	if _max_combo_value:
		_max_combo_value.text = str(int(_summary.get("total_max_combo", 0)))
	if _accuracy_value:
		_accuracy_value.text = "%.1f%%" % _normalize_accuracy(float(_summary.get("average_accuracy", 0.0)))
	if _perfect_value:
		_perfect_value.text = str(perfect)
	if _good_value:
		_good_value.text = str(good)
	if _miss_value:
		_miss_value.text = str(int(_summary.get("total_missed_notes", 0)))


func _set_stat_caption(tile_name: String, key: String) -> void:
	var tile := find_child(tile_name, true, false) as Control
	if tile == null:
		return
	var cap := tile.find_child("Cap", true, false) as Label
	if cap:
		cap.text = tr(key)


func _ensure_stat_icons() -> void:
	for tile_name in _SeriesFinishPresentation.STAT_ICONS.keys():
		var tile := find_child(String(tile_name), true, false) as Control
		if tile == null:
			continue
		var cap := tile.find_child("Cap", true, false) as Label
		if cap == null:
			continue
		var icon_file := str(_SeriesFinishPresentation.STAT_ICONS[tile_name])
		var tint: Color = _SeriesFinishPresentation.STAT_VALUE_COLORS.get(
			tile_name, Color(0.7, 0.76, 0.88, 1.0)
		)
		if bool(cap.get_meta("ui_icon_wrapped", false)):
			_UiIconHelper.update_icon_before_label(cap, icon_file, tint)
		else:
			_UiIconHelper.add_icon_before_label(cap, icon_file, true, tint)


func _refresh_lane_stats() -> void:
	if _lane_stats_chart == null or not _lane_stats_chart.has_method("setup"):
		if _lane_stats_panel:
			_lane_stats_panel.visible = false
		return
	var raw: Variant = _summary.get("lane_stats", [])
	var stats: Array = raw if raw is Array else []
	_lane_stats_chart.setup(stats)
	var has_stats: bool = _lane_stats_chart.has_method("has_data") and bool(_lane_stats_chart.has_data())
	if _lane_stats_panel:
		_lane_stats_panel.visible = has_stats
	if _lane_stats_title:
		_lane_stats_title.text = tr("VICTORY_LANE_STATS_TITLE")


func _refresh_rewards() -> void:
	var xp := int(_summary.get("earned_xp", 0))
	var currency := int(_summary.get("earned_currency", 0))
	var accent: Color = _PlayModeIds.accent_for(_mode_id())
	if _rewards_title:
		_rewards_title.text = tr("VICTORY_REWARDS_TITLE")
	if _currency_label:
		_currency_label.text = str(currency)
		_currency_label.add_theme_color_override("font_color", Color(0.94902, 0.701961, 0.352941, 1))
	if _xp_label:
		_xp_label.text = str(xp)
		_xp_label.add_theme_color_override("font_color", accent.lightened(0.05))
	var currency_cap := find_child("CurrencyCaption", true, false) as Label
	if currency_cap:
		currency_cap.text = tr("VICTORY_REWARD_CURRENCY")
	var xp_cap := find_child("XpCaption", true, false) as Label
	if xp_cap:
		xp_cap.text = "XP"
	if _xp_progress_bar and PlayerDataManager:
		var progress := PlayerDataManager.get_xp_progress()
		_xp_progress_bar.max_value = 100.0
		_xp_progress_bar.value = progress * 100.0
		_apply_xp_bar_style(accent)
	if _xp_progress_label and PlayerDataManager:
		_xp_progress_label.text = PlayerDataManager.get_xp_progress_text()


func _apply_xp_bar_style(accent: Color = Color.WHITE) -> void:
	if _xp_progress_bar == null:
		return
	if accent == Color.WHITE:
		accent = _PlayModeIds.accent_for(_mode_id())
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.08, 0.12, 0.9)
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(accent.r, accent.g, accent.b, 0.85)
	fill.set_corner_radius_all(4)
	_xp_progress_bar.add_theme_stylebox_override("background", bg)
	_xp_progress_bar.add_theme_stylebox_override("fill", fill)


func _refresh_chart(accent: Color) -> void:
	if _chart_title:
		_chart_title.text = tr("VICTORY_ACCURACY_CHART_TITLE")
	if _accuracy_chart == null:
		return
	if _accuracy_chart.has_method("set_accent"):
		_accuracy_chart.set_accent(accent)
	var samples := _build_accuracy_samples()
	var final_acc := _normalize_accuracy(float(_summary.get("average_accuracy", 0.0)))
	if samples.is_empty() and final_acc > 0.0:
		samples = [{"t": 0.0, "acc": final_acc}, {"t": 1.0, "acc": final_acc}]
	var duration := float(maxi(1, samples.size()))
	if _accuracy_chart.has_method("setup_and_cache"):
		_accuracy_chart.setup_and_cache(samples, duration, final_acc)
	elif _accuracy_chart.has_method("setup"):
		_accuracy_chart.setup(samples, duration, final_acc)
	call_deferred("_reveal_chart_after_layout")


func _reveal_chart_after_layout() -> void:
	if _accuracy_chart == null:
		return
	if _accuracy_chart.has_method("_rebuild_from_cached"):
		_accuracy_chart._rebuild_from_cached()
	if _accuracy_chart.has_method("play_reveal"):
		_accuracy_chart.play_reveal(1.25)


func _normalize_accuracy(raw: float) -> float:
	if raw >= 0.0 and raw <= 1.5:
		return clampf(raw * 100.0, 0.0, 100.0)
	return clampf(raw, 0.0, 100.0)


func _build_accuracy_samples() -> Array:
	var samples: Array = []
	var tracks: Array = []
	if _is_marathon():
		var log_v: Variant = _summary.get("tracks_log", [])
		if log_v is Array:
			tracks = log_v
	else:
		var cleared_v: Variant = _summary.get("tracks_cleared", [])
		if cleared_v is Array:
			tracks = cleared_v
	var i := 0
	for entry in tracks:
		if entry is not Dictionary:
			continue
		i += 1
		samples.append({
			"t": float(i),
			"acc": _normalize_accuracy(float((entry as Dictionary).get("accuracy", 0.0))),
		})
	return samples


func _refresh_side_panels() -> void:
	if _is_marathon():
		if _route_badges_panel:
			_route_badges_panel.visible = true
		_refresh_route_badges()
	else:
		if _route_badges_panel:
			_route_badges_panel.visible = false


func _refresh_route_badges() -> void:
	if _route_badges_row == null:
		return
	for child in _route_badges_row.get_children():
		child.queue_free()
	if _route_badges_title:
		_route_badges_title.text = tr("SERIES_FINISH_ROUTE_REWARDS")
	var route_id := str(_summary.get("route_id", "")).strip_edges()
	var template: Dictionary = {}
	if _summary.get("template") is Dictionary:
		template = (_summary.get("template") as Dictionary).duplicate(true)
	elif route_id != "":
		template = _MarathonRouteCatalog.template_for_route(route_id)
	var tiers := _MarathonRouteBadges.active_tiers_for_template(route_id, template)
	if tiers.is_empty():
		tiers = [
			_MarathonRouteBadges.TIER_BRONZE,
			_MarathonRouteBadges.TIER_SILVER,
			_MarathonRouteBadges.TIER_GOLD,
			_MarathonRouteBadges.TIER_PLATINUM,
		]
	var earned := _earned_badges
	var accent: Color = _PlayModeIds.accent_for(_PlayModeIds.MARATHON)
	for tier in tiers:
		if tier == _MarathonRouteBadges.TIER_LEGEND:
			continue
		var wrap := PanelContainer.new()
		var box := StyleBoxFlat.new()
		var is_earned := earned.has(tier) or _newly_earned_badges.has(tier)
		box.bg_color = Color(0.05, 0.06, 0.09, 0.95)
		box.set_corner_radius_all(999)
		box.set_border_width_all(2 if is_earned else 1)
		box.border_color = accent.lightened(0.1) if is_earned else Color(0.35, 0.38, 0.45, 0.55)
		box.content_margin_left = 8
		box.content_margin_right = 8
		box.content_margin_top = 8
		box.content_margin_bottom = 8
		wrap.add_theme_stylebox_override("panel", box)
		wrap.tooltip_text = _MarathonRouteBadges.medal_tooltip(route_id, tier, template)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var tint := accent.lightened(0.15) if is_earned else Color(0.45, 0.48, 0.55, 0.7)
		icon.texture = _UiIconHelper.load_tinted_icon(_MarathonRouteBadges.tier_icon_file(tier), tint, 24)
		wrap.modulate = Color(1, 1, 1, 1) if is_earned else Color(0.7, 0.72, 0.78, 0.75)
		wrap.add_child(icon)
		_route_badges_row.add_child(wrap)


func _refresh_buttons() -> void:
	if _is_marathon():
		if _back_button:
			_back_button.text = tr("MARATHON_FINISH_TO_CATALOG")
		if _play_again_button:
			_play_again_button.text = tr("MARATHON_FINISH_RETRY")
		if _secondary_button:
			_secondary_button.visible = false
	else:
		if _back_button:
			_back_button.text = tr("ENDLESS_SUMMARY_TO_PLAY_MODES")
		if _play_again_button:
			_play_again_button.text = tr("ENDLESS_SUMMARY_PLAY_AGAIN")
		if _secondary_button:
			_secondary_button.visible = true
			_secondary_button.text = tr("SERIES_FINISH_NEW_SETUP")
	_UiIconHelper.configure_button_icon(_play_again_button, "repeat.svg", _PlayModeIds.accent_for(_mode_id()))
	if _secondary_button and _secondary_button.visible:
		_UiIconHelper.configure_button_icon(_secondary_button, "settings-2.svg", Color(0.72, 0.78, 0.88, 1.0))


func _last_track_entry() -> Dictionary:
	var tracks: Array = []
	if _is_marathon():
		var log_v: Variant = _summary.get("tracks_log", [])
		if log_v is Array:
			tracks = log_v
	else:
		var cleared_v: Variant = _summary.get("tracks_cleared", [])
		if cleared_v is Array:
			tracks = cleared_v
	if tracks.is_empty():
		return {}
	var last = tracks[tracks.size() - 1]
	return last if last is Dictionary else {}


func _persist_results() -> void:
	if _persisted or _summary.is_empty():
		return
	_persisted = true
	if _is_marathon():
		var meta := _MarathonFinishScreen.persist_summary(_summary)
		_best_route_updated = bool(meta.get("best_updated", false))
		if meta.get("earned_this_run") is Array:
			_earned_badges = (meta.get("earned_this_run") as Array).duplicate()
		if meta.get("newly_earned") is Array:
			_newly_earned_badges = (meta.get("newly_earned") as Array).duplicate()
	else:
		var meta := _EndlessSummaryScreen.persist_summary(_summary)
		_best_streak_updated = bool(meta.get("best_streak_updated", false))
		_best_rr_updated = bool(meta.get("best_series_rr_updated", false))


func _stop_results_music() -> void:
	if MusicManager and MusicManager.has_method("stop_screen_ambient_music"):
		MusicManager.stop_screen_ambient_music()


func _on_back_pressed() -> void:
	MusicManager.play_select_sound()
	_stop_results_music()
	if transitions == null:
		return
	if _is_marathon():
		transitions.open_marathon_catalog_from_play_modes()
	else:
		transitions.open_play_modes()


func _on_play_again_pressed() -> void:
	MusicManager.play_select_sound()
	_stop_results_music()
	if transitions == null:
		return
	if _is_marathon():
		var route_id := str(_summary.get("route_id", "")).strip_edges()
		if route_id == "":
			route_id = _MarathonRouteCatalog.route_id_for_group(str(_summary.get("genre_group_id", "")).strip_edges())
		if route_id == "":
			return
		var run_config: Dictionary = {}
		if _summary.get("run_config") is Dictionary:
			run_config = (_summary.get("run_config") as Dictionary).duplicate(true)
		if transitions.has_method("open_marathon_run"):
			transitions.open_marathon_run(route_id, run_config)
		return
	var config: Dictionary = _summary.get("config", {})
	if config is Dictionary and not config.is_empty() and transitions.has_method("open_endless_run"):
		transitions.open_endless_run(config)
		return
	if transitions.has_method("open_endless_session_setup_from_play_modes"):
		transitions.open_endless_session_setup_from_play_modes()


func _on_secondary_pressed() -> void:
	MusicManager.play_select_sound()
	_stop_results_music()
	if transitions and transitions.has_method("open_endless_session_setup_from_play_modes"):
		transitions.open_endless_session_setup_from_play_modes()


func _execute_close_transition() -> void:
	_stop_results_music()
	if transitions == null:
		return
	if _is_marathon():
		if _return_flag:
			transitions.open_marathon_catalog_from_play_modes()
		else:
			transitions.open_play_modes()
	else:
		if _return_flag:
			transitions.open_play_modes()
		else:
			transitions.open_main_menu()
