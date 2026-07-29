# scenes/play_modes/play_modes_screen.gd
extends BaseScreen

const MODE_CARD_SCENE := preload("res://scenes/play_modes/mode_card.tscn")
const _PlayModeIds = preload("res://logic/domain/session/play_mode_ids.gd")
const _ChoiceOverlayScene = preload("res://ui/overlays/app_choice_overlay.tscn")
const _NoticeOverlayScene = preload("res://ui/overlays/app_notice_overlay.tscn")
const _Overlay = preload("res://logic/ui/app_overlay_helpers.gd")
const _ResultsHistoryService = preload("res://logic/data/results_history_service.gd")
const _TimeUtils = preload("res://logic/platform/time_utils.gd")
const _RhythmDnaCoverLoader = preload("res://scenes/song_select/rhythm_dna/lib/rhythm_dna_cover_loader.gd")
const _GradeDisplay = preload("res://logic/ui/grade_display.gd")
const _MarathonDailyRoute = preload("res://logic/domain/session/marathon_daily_route.gd")
const _MarathonRouteCatalog = preload("res://logic/domain/session/marathon_route_catalog.gd")
const _MarathonRouteLength = preload("res://logic/domain/session/marathon_route_length.gd")
const _MarathonSeason = preload("res://logic/domain/session/marathon_season.gd")
const _EndlessSessionConfig = preload("res://logic/domain/session/endless_session_config.gd")
const _SessionScopeResolver = preload("res://logic/domain/session/session_scope_resolver.gd")
const _MainMenuNearestAchievement = preload("res://scenes/main_menu/lib/main_menu_nearest_achievement.gd")
const _AchievementLocale = preload("res://logic/i18n/achievement_locale.gd")
const _SettingsSectionUi = preload("res://logic/ui/settings_section_ui.gd")
const _LAST_TRACK_COVER_PX := 72

var _focused_card_index := 0
var _prompt_active := false
var _choice_overlay: AppChoiceOverlay = null
var _notice_overlay: AppNoticeOverlay = null

@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _cards_row: HBoxContainer = %CardsRow
@onready var _footer_label: Label = %FooterLabel

var _cards: Array[PlayModeCard] = []
var _history_service: ResultsHistoryService = null
var _library_paths_by_file: Dictionary = {}
var _library_paths_by_label: Dictionary = {}
var _library_index_built := false
var _cached_latest_session: Dictionary = {}
var _session_cache_valid := false
var _marathon_card: PlayModeCard = null
var _rotation_timer: Timer = null
var _nearest_ach_line_cache: String = ""
var _nearest_ach_line_valid := false
var _help_btn: Button = null


func _ready() -> void:
	var game_engine := get_parent()
	if game_engine and game_engine.has_method("get_transitions"):
		setup_managers(game_engine.get_transitions())
	_history_service = _ResultsHistoryService.new()
	_choice_overlay = _ChoiceOverlayScene.instantiate() as AppChoiceOverlay
	if _choice_overlay:
		add_child(_choice_overlay)
	_notice_overlay = _NoticeOverlayScene.instantiate() as AppNoticeOverlay
	if _notice_overlay:
		add_child(_notice_overlay)
	_ensure_help_icon()
	_build_cards()
	_setup_rotation_timer()
	call_deferred("_deferred_boot")


func _setup_rotation_timer() -> void:
	_rotation_timer = Timer.new()
	_rotation_timer.wait_time = 1.0
	_rotation_timer.autostart = true
	_rotation_timer.timeout.connect(_update_marathon_countdown)
	add_child(_rotation_timer)


func _deferred_boot() -> void:
	_refresh_cards()
	_play_entrance_animation()


func _play_entrance_animation() -> void:
	for i in range(_cards.size()):
		var card := _cards[i]
		if card == null:
			continue
		card.modulate.a = 0.0
		var tw := card.create_tween()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "modulate:a", 1.0, 0.34).set_delay(float(i) * 0.07)


func apply_locale() -> void:
	if _back_button:
		_back_button.text = tr("BTN_BACK")
	if _title_label:
		_title_label.text = tr("PLAY_MODES_TITLE")
	if _subtitle_label:
		_subtitle_label.text = tr("PLAY_MODES_SUBTITLE")
	if _footer_label:
		_footer_label.text = tr("PLAY_MODES_FOOTER_HINT")
	if _help_btn:
		_help_btn.tooltip_text = tr("HELP_LINK_PLAY_MODES")
	_refresh_cards()


func _ensure_help_icon() -> void:
	if _title_label == null:
		return
	_help_btn = _SettingsSectionUi.attach_help_icon_beside_label(
		_title_label,
		tr("HELP_LINK_PLAY_MODES"),
		_on_help_pressed,
		true
	)


func _on_help_pressed() -> void:
	_open_help_item("play_modes_overview")


func _open_help_item(item_id: String) -> void:
	if transitions and transitions.has_method("open_help_item"):
		transitions.open_help_item(item_id)
		return
	var parent := get_parent()
	if parent and parent.has_method("get_transitions"):
		var trans = parent.get_transitions()
		if trans and trans.has_method("open_help_item"):
			trans.open_help_item(item_id)


func _build_cards() -> void:
	if _cards_row == null:
		return
	for child in _cards_row.get_children():
		child.queue_free()
	_cards.clear()
	var specs: Array = [
		_PlayModeIds.LIBRARY,
		_PlayModeIds.ENDLESS,
		_PlayModeIds.MARATHON,
	]
	for mode_id in specs:
		var card := MODE_CARD_SCENE.instantiate() as PlayModeCard
		if card == null:
			continue
		card.mode_id = mode_id
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.size_flags_stretch_ratio = 1.0
		card.action_pressed.connect(_on_card_action_pressed)
		if not card.zone_action_requested.is_connected(_on_card_zone_action):
			card.zone_action_requested.connect(_on_card_zone_action)
		_cards_row.add_child(card)
		_cards.append(card)
	_focused_card_index = clampi(_focused_card_index, 0, maxi(_cards.size() - 1, 0))
	_sync_card_focus()


func _refresh_cards(invalidate_session := false) -> void:
	if _cards.is_empty():
		_build_cards()
	if invalidate_session:
		_session_cache_valid = false
	_nearest_ach_line_valid = false
	for card in _cards:
		if card == null:
			continue
		_apply_card_data(card)
	_sync_card_focus()


func _apply_card_data(card: PlayModeCard) -> void:
	var mode_id := card.mode_id if card.mode_id != "" else _mode_id_for_card(card)
	if mode_id == "":
		return
	card.mode_id = mode_id
	var locked := not PlayerDataManager.is_play_mode_unlocked(mode_id)
	var unlock_ready := locked and PlayerDataManager.meets_play_mode_unlock_requirements(mode_id)
	var title_key := "PLAY_MODE_%s_TITLE" % mode_id.to_upper()
	var desc_key := "PLAY_MODE_%s_DESC" % mode_id.to_upper()
	var action_key := _action_locale_key(mode_id, locked)
	var badge := ""
	if mode_id == _PlayModeIds.LIBRARY:
		badge = tr("PLAY_MODE_ALWAYS_AVAILABLE")
	elif locked:
		badge = tr("PLAY_MODE_LOCKED")
	card.setup(
		mode_id,
		tr(title_key),
		tr(desc_key),
		tr(action_key),
		locked,
		badge,
		_build_zones(mode_id, locked),
		_build_unlock_rows(mode_id, locked),
		unlock_ready,
		_build_accent_hints(mode_id, locked, unlock_ready),
	)
	card.set_hero_streak(_hero_streak_for_mode(mode_id, locked))
	if mode_id == _PlayModeIds.MARATHON:
		_marathon_card = card
		_update_marathon_countdown()


func _update_marathon_countdown() -> void:
	if _marathon_card == null or not _MarathonSeason.is_enabled():
		return
	if PlayerDataManager == null or not PlayerDataManager.is_play_mode_unlocked(_PlayModeIds.MARATHON):
		return
	var caption := tr("MARATHON_ROTATION_RESET_FMT") % _TimeUtils.format_countdown_hms(
		_MarathonSeason.seconds_until_next_season()
	)
	_marathon_card.update_countdown_caption(caption)


func _mode_id_for_card(card: PlayModeCard) -> String:
	var index := _cards.find(card)
	if index < 0:
		return ""
	var order := [_PlayModeIds.LIBRARY, _PlayModeIds.ENDLESS, _PlayModeIds.MARATHON]
	if index < order.size():
		return order[index]
	return ""


func _action_locale_key(mode_id: String, locked: bool) -> String:
	if locked:
		return "PLAY_MODE_UNLOCK_ACTION"
	match mode_id:
		_PlayModeIds.LIBRARY:
			return "PLAY_MODE_LIBRARY_ACTION"
		_PlayModeIds.ENDLESS:
			return "PLAY_MODE_ENDLESS_ACTION"
		_PlayModeIds.MARATHON:
			return "PLAY_MODE_MARATHON_ACTION"
	return "BTN_OK"


func _build_accent_hints(mode_id: String, locked: bool, unlock_ready: bool) -> Array:
	const UNLOCK_GOLD := Color("#F2B35A")
	if locked and unlock_ready:
		return [{"icon": "sparkles.svg", "text": tr("PLAY_MODE_UNLOCK_READY"), "accent": UNLOCK_GOLD}]
	var accent := _PlayModeIds.accent_for(mode_id)
	match mode_id:
		_PlayModeIds.LIBRARY:
			return _mode_hint_chips(accent, [
				["music.svg", "PLAY_MODE_HINT_ANY_TRACK"],
				["settings.svg", "PLAY_MODE_HINT_OWN_MODS"],
				["diamond.svg", "PLAY_MODE_HINT_FULL_REWARDS"],
			])
		_PlayModeIds.ENDLESS:
			return _mode_hint_chips(accent, [
				["repeat.svg", "PLAY_MODE_ENDLESS_HINT_STREAK"],
				["shuffle.svg", "PLAY_MODE_ENDLESS_HINT_RANDOM"],
				["diamond.svg", "PLAY_MODE_ENDLESS_HINT_REWARDS"],
			])
		_PlayModeIds.MARATHON:
			return _mode_hint_chips(accent, [
				["list-checks.svg", "PLAY_MODE_MARATHON_HINT_GENRES"],
				["clock.svg", "PLAY_MODE_MARATHON_HINT_DURATION"],
				["trophy.svg", "PLAY_MODE_MARATHON_HINT_REWARDS"],
			])
	return []


func _mode_hint_chips(accent: Color, specs: Array) -> Array:
	var out: Array = []
	for i in range(specs.size()):
		var spec: Array = specs[i]
		if spec.size() < 2:
			continue
		var chip_accent := accent
		if specs.size() > 1:
			var t := float(i) / float(maxi(specs.size() - 1, 1))
			chip_accent = accent.lerp(accent.lightened(0.14), t * 0.35)
		out.append({
			"icon": str(spec[0]),
			"text": tr(str(spec[1])),
			"accent": chip_accent,
		})
	return out


func _build_zones(mode_id: String, _locked: bool) -> Array:
	match mode_id:
		_PlayModeIds.LIBRARY:
			return _build_library_zones()
		_PlayModeIds.ENDLESS:
			return _build_endless_zones(_locked)
		_PlayModeIds.MARATHON:
			return _build_marathon_zones(_locked)
	return []


func _build_library_zones() -> Array:
	var zones: Array = []
	var session := _get_latest_session()
	if session.is_empty():
		zones.append({
			"type": "last_track",
			"caption": tr("PLAY_MODE_ZONE_LAST_TRACK"),
			"title": tr("PLAY_MODE_LIBRARY_NO_LAST"),
		})
	else:
		var artist := str(session.get("artist", "")).strip_edges()
		var title := str(session.get("title", "")).strip_edges()
		var track_line := "%s — %s" % [artist, title] if artist != "" and title != "" else title
		if track_line.strip_edges() == "":
			track_line = tr("PLAY_MODE_LIBRARY_NO_LAST")
		var song_path := _resolve_session_song_path(session)
		var grade := str(session.get("grade", "")).strip_edges()
		var grade_color := _GradeDisplay.color_from_saved_result(session)
		zones.append({
			"type": "last_track",
			"caption": tr("PLAY_MODE_ZONE_LAST_TRACK"),
			"title": track_line,
			"grade": grade,
			"grade_color": grade_color,
			"when": _TimeUtils.format_relative_ago_from_local_iso(str(session.get("date", ""))),
			"cover_path": song_path,
			"replay_enabled": true,
			"replay_text": tr("PLAY_MODE_REPLAY_LAST"),
			"session": session.duplicate(true),
		})

	var stats_rows: Array = []
	var best_rr := _best_rr_highlight()
	if best_rr != "":
		stats_rows.append({"icon": "star.svg", "text": best_rr})
	stats_rows.append({
		"icon": "music.svg",
		"text": tr("PLAY_MODE_ZONE_SONGS_PLAYED_FMT") % _format_int_grouped(PlayerDataManager.get_levels_completed()),
	})
	zones.append({"caption": tr("PLAY_MODE_ZONE_YOUR_STATS"), "rows": stats_rows})
	return zones


func _build_endless_zones(locked: bool) -> Array:
	if locked:
		return _build_endless_locked_preview()
	return _build_endless_unlocked_zones()


func _build_endless_locked_preview() -> Array:
	return [
		{
			"type": "bullets",
			"caption": tr("PLAY_MODE_ZONE_FEATURES"),
			"bullets": [
				tr("PLAY_MODE_ENDLESS_FEATURE_STREAK"),
				tr("PLAY_MODE_ENDLESS_FEATURE_MODS"),
				tr("PLAY_MODE_ENDLESS_FEATURE_REWARDS"),
			],
		},
		{
			"type": "bullets",
			"caption": tr("PLAY_MODE_ZONE_AFTER_UNLOCK"),
			"bullets": [
				{"icon": "repeat.svg", "text": tr("PLAY_MODE_ENDLESS_PREVIEW_STREAK")},
				{"icon": "chart-column.svg", "text": tr("PLAY_MODE_ENDLESS_PREVIEW_STATS")},
				{"icon": "trophy.svg", "text": tr("PLAY_MODE_ENDLESS_PREVIEW_ACH")},
			],
		},
	]


func _build_endless_unlocked_zones() -> Array:
	var zones: Array = []
	var ach_line := _nearest_play_mode_achievement_line()
	if ach_line != "":
		zones.append({
			"caption": tr("PLAY_MODE_ZONE_NEAREST_ACH"),
			"rows": [ach_line],
			"highlight": ach_line,
		})
	var stats: Dictionary = PlayerDataManager.get_endless_stats() if PlayerDataManager.has_method("get_endless_stats") else {}
	var last_run: Dictionary = stats.get("last_run", {}) if stats.get("last_run") is Dictionary else {}
	var best: int = PlayerDataManager.get_endless_best_streak()
	var best_rows: PackedStringArray = []
	if best > 0:
		best_rows.append(tr("PLAY_MODE_ENDLESS_BEST_VALUE_FMT") % best)
	else:
		best_rows.append(tr("PLAY_MODE_ENDLESS_NO_BEST"))
	zones.append({
		"caption": tr("PLAY_MODE_ZONE_BEST_RUN"),
		"rows": best_rows,
		"highlight": best_rows[0] if best > 0 else "",
	})

	if not last_run.is_empty():
		var streak := int(last_run.get("streak", 0))
		var run_acc := float(last_run.get("average_accuracy", 0.0))
		var summary := tr("PLAY_MODE_ENDLESS_LAST_RUN_FMT") % [streak, run_acc]
		zones.append({
			"type": "replay_run",
			"caption": tr("PLAY_MODE_ZONE_LAST_RUN"),
			"summary": summary,
			"button_text": tr("PLAY_MODE_REPLAY_RUN"),
		})

	var saved_setup: Dictionary = PlayerDataManager.get_endless_session_last() if PlayerDataManager.has_method("get_endless_session_last") else {}
	if _endless_has_played_runs() and saved_setup is Dictionary and not saved_setup.is_empty():
		zones.append({
			"type": "replay_run",
			"caption": tr("PLAY_MODE_ZONE_SAME_SETUP"),
			"summary": tr("PLAY_MODE_ENDLESS_SAME_SETUP_HINT"),
			"button_text": tr("PLAY_MODE_ENDLESS_SAME_SETUP_ACTION"),
			"action": "same_setup_endless",
		})

	var avg_acc := float(stats.get("best_avg_accuracy", 0.0))
	var stats_rows: PackedStringArray = []
	if avg_acc > 0.0:
		stats_rows.append("%.2f%%" % avg_acc)
	else:
		stats_rows.append(tr("PLAY_MODE_PLACEHOLDER_DASH"))
	stats_rows.append(tr("PLAY_MODE_ENDLESS_MODS_PREVIEW"))
	zones.append({"caption": tr("PLAY_MODE_ZONE_AVG_ACCURACY"), "rows": stats_rows})
	return zones


func _endless_has_played_runs() -> bool:
	if PlayerDataManager == null:
		return false
	if PlayerDataManager.get_endless_best_streak() > 0:
		return true
	if not PlayerDataManager.has_method("get_endless_stats"):
		return false
	var stats: Dictionary = PlayerDataManager.get_endless_stats()
	if int(stats.get("total_runs", 0)) > 0:
		return true
	var last_run: Variant = stats.get("last_run", {})
	return last_run is Dictionary and not (last_run as Dictionary).is_empty()


func _build_marathon_zones(locked: bool) -> Array:
	if locked:
		return _build_marathon_locked_preview()
	return _build_marathon_unlocked_zones()


func _build_marathon_locked_preview() -> Array:
	var playlists_line := _marathon_playlists_line()
	return [
		_build_marathon_daily_zone(),
		{
			"caption": tr("PLAY_MODE_ZONE_PLAYLISTS_AVAILABLE"),
			"rows": [{"icon": "layers.svg", "text": playlists_line}],
			"highlight": playlists_line if PlayerDataManager.get_marathon_courses_total_count() > 0 else "",
		},
		{
			"caption": tr("PLAY_MODE_ZONE_LONGEST"),
			"rows": [{"icon": "gauge.svg", "text": tr("PLAY_MODE_MARATHON_LONGEST_PREVIEW")}],
		},
		{
			"type": "bullets",
			"caption": tr("PLAY_MODE_ZONE_FEATURES"),
			"bullets": [
				{"icon": "flag.svg", "text": tr("PLAY_MODE_MARATHON_FEATURE_ROUTES")},
				{"icon": "chart-column.svg", "text": tr("PLAY_MODE_MARATHON_FEATURE_PROGRESS")},
				{"icon": "trophy.svg", "text": tr("PLAY_MODE_MARATHON_FEATURE_REWARDS")},
			],
		},
	]


func _build_marathon_unlocked_zones() -> Array:
	var zones: Array = []
	if _MarathonSeason.is_enabled():
		zones.append({
			"type": "countdown",
			"caption": tr("MARATHON_ROTATION_RESET_FMT") % _TimeUtils.format_countdown_hms(
				_MarathonSeason.seconds_until_next_season()
			),
			"rows": [{"icon": "clock.svg", "text": tr("MARATHON_ROTATION_NEXT_TITLE")}],
		})
		var season_prog := _marathon_current_rotation_progress()
		if season_prog.get("total", 0) > 0:
			zones.append({
				"caption": tr("PLAY_MODE_ZONE_ROTATION_PROGRESS"),
				"rows": [
					tr("PLAY_MODE_MARATHON_ROTATION_PROGRESS_FMT") % [
						int(season_prog.get("completed", 0)),
						int(season_prog.get("total", 0)),
					]
				],
				"highlight": tr("PLAY_MODE_MARATHON_ROTATION_PROGRESS_FMT") % [
					int(season_prog.get("completed", 0)),
					int(season_prog.get("total", 0)),
				],
			})
	var ach_line := _nearest_play_mode_achievement_line()
	if ach_line != "":
		zones.append({
			"caption": tr("PLAY_MODE_ZONE_NEAREST_ACH"),
			"rows": [ach_line],
			"highlight": ach_line,
		})
	zones.append(_build_marathon_daily_zone())
	var playlists_line := _marathon_playlists_line()
	zones.append({
		"caption": tr("PLAY_MODE_ZONE_PLAYLISTS"),
		"rows": [{"icon": "layers.svg", "text": playlists_line}],
		"highlight": playlists_line if PlayerDataManager.get_marathon_courses_total_count() > 0 else "",
	})
	zones.append({
		"caption": tr("PLAY_MODE_ZONE_BEST_ROUTE"),
		"rows": [{"icon": "flag.svg", "text": _marathon_best_course_label()}],
	})
	zones.append({
		"caption": tr("PLAY_MODE_ZONE_TOTAL_COMPLETED"),
		"rows": [{"icon": "circle-check.svg", "text": str(_marathon_total_completions())}],
	})
	return zones


func _build_marathon_daily_zone() -> Dictionary:
	var route_id := _MarathonDailyRoute.today_route_id()
	var template := _MarathonDailyRoute.template_for_route_id(route_id)
	var iso_date := str(template.get("daily_date", _MarathonDailyRoute.today_iso_date()))
	var done := _marathon_daily_is_complete(route_id)
	return {
		"type": "daily_marathon",
		"caption": tr("MAIN_DAILY_MARATHON_TITLE"),
		"date": tr("MAIN_DAILY_MARATHON_DATE_FMT") % _TimeUtils.format_iso_date_localized(iso_date),
		"summary": _MarathonDailyRoute.summary_line(template),
		"status": _marathon_daily_completion_status(route_id),
		"emphasis": not done,
		"play_text": tr("MAIN_DAILY_MARATHON_PLAY"),
		"details_text": tr("MAIN_DAILY_MARATHON_DETAILS"),
	}


func _marathon_daily_is_complete(route_id: String) -> bool:
	var completions: Variant = PlayerDataManager.data.get("marathon_completions", {})
	if not completions is Dictionary:
		return false
	var entry: Variant = completions.get(route_id, {})
	return entry is Dictionary and float(entry.get("best_ratio", 0.0)) >= 0.999


func _marathon_daily_completion_status(route_id: String) -> String:
	if _marathon_daily_is_complete(route_id):
		return tr("MAIN_DAILY_MARATHON_STATUS_DONE")
	return tr("MAIN_DAILY_MARATHON_STATUS_OPEN")


func _marathon_playlists_line() -> String:
	var total := PlayerDataManager.get_marathon_courses_total_count()
	if total <= 0:
		return tr("PLAY_MODE_MARATHON_PLAYLISTS_TEASER")
	var completed := PlayerDataManager.get_marathon_courses_completed_count()
	return tr("PLAY_MODE_MARATHON_PLAYLISTS_FMT") % [completed, total]


func _best_rr_highlight() -> String:
	var top: Array = ProfileMilestonesManager.get_rhythm_rating_top10()
	if top.is_empty():
		return ""
	var entry: Dictionary = top[0] if top[0] is Dictionary else {}
	var rr := int(entry.get("best_rr", 0))
	if rr <= 0:
		return ""
	return tr("PLAY_MODE_ZONE_BEST_RR_FMT") % rr


func _history_average_accuracy() -> float:
	var svc := _ResultsHistoryService.new()
	var history := svc.get_history()
	if history.is_empty():
		return -1.0
	var sum := 0.0
	for item in history:
		sum += float(item.get("accuracy", 0.0))
	return sum / float(history.size())


func _marathon_best_course_label() -> String:
	var completions: Variant = PlayerDataManager.data.get("marathon_completions", {})
	if not completions is Dictionary or completions.is_empty():
		return tr("PLAY_MODE_PLACEHOLDER_DASH")
	var best_id := ""
	var best_ratio := -1.0
	for course_id in completions.keys():
		var entry: Variant = completions[course_id]
		if not entry is Dictionary:
			continue
		var ratio := float(entry.get("best_ratio", 0.0))
		if ratio > best_ratio:
			best_ratio = ratio
			best_id = str(course_id)
	if best_id == "":
		return tr("PLAY_MODE_PLACEHOLDER_DASH")
	var title := best_id.replace("marathon_", "").replace("_", " ").capitalize()
	if best_ratio >= 0.999:
		return "%s · 100%%" % title
	return "%s · %.0f%%" % [title, best_ratio * 100.0]


func _marathon_total_completions() -> int:
	var completions: Variant = PlayerDataManager.data.get("marathon_completions", {})
	if not completions is Dictionary:
		return 0
	return completions.size()


func _format_int_grouped(value: int) -> String:
	var negative := value < 0
	var digits := str(abs(value))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = " " + out
		out = digits[i] + out
		count += 1
	return ("-" if negative else "") + out


func _build_unlock_rows(mode_id: String, locked: bool) -> Array:
	if not locked:
		return []
	var req: Dictionary = _PlayModeIds.unlock_requirements_for(mode_id)
	if req.is_empty():
		return []
	var level_need: int = int(req.get("min_level", 0))
	var diamond_need: int = int(req.get("diamond_cost", 0))
	var medal_need: int = int(req.get("min_medals", 0))
	var level_have: int = PlayerDataManager.get_current_level()
	var diamond_have: int = PlayerDataManager.get_currency()
	var medal_have: int = PlayerDataManager.get_total_medals_earned()
	return [
		{
			"label": tr("PLAY_MODE_REQ_LEVEL_FMT") % [level_need, level_have],
			"met": level_have >= level_need,
		},
		{
			"label": tr("PLAY_MODE_REQ_DIAMONDS_FMT") % [diamond_need, diamond_have],
			"met": diamond_have >= diamond_need,
		},
		{
			"label": tr("PLAY_MODE_REQ_MEDALS_FMT") % [medal_need, medal_have],
			"met": medal_have >= medal_need,
		},
	]


func _unlock_requirements_text(mode_id: String) -> String:
	var rows: Array = _build_unlock_rows(mode_id, true)
	if rows.is_empty():
		return ""
	var lines: PackedStringArray = []
	for entry in rows:
		if entry is Dictionary:
			lines.append(str(entry.get("label", "")))
	return tr("PLAY_MODE_UNLOCK_ALL_REQUIRED") + "\n" + "\n".join(lines)


func _get_latest_session() -> Dictionary:
	if _session_cache_valid:
		return _cached_latest_session
	_session_cache_valid = true
	_cached_latest_session = {}
	if _history_service == null:
		_history_service = _ResultsHistoryService.new()
	var history := _history_service.get_history()
	if history.is_empty():
		return _cached_latest_session
	_cached_latest_session = history[0]
	return _cached_latest_session


func _ensure_library_index() -> void:
	if _library_index_built:
		return
	_library_index_built = true
	_library_paths_by_file.clear()
	_library_paths_by_label.clear()
	if SongLibrary == null:
		return
	for song in SongLibrary.get_songs_list():
		if typeof(song) != TYPE_DICTIONARY:
			continue
		var song_path := str(song.get("path", "")).replace("\\", "/").strip_edges()
		if song_path == "":
			continue
		var file_key := song_path.get_file().to_lower()
		if file_key != "" and not _library_paths_by_file.has(file_key):
			_library_paths_by_file[file_key] = song_path
		if not _library_paths_by_file.has(song_path):
			_library_paths_by_file[song_path] = song_path
		var meta := SongLibrary.get_metadata_for_song(song_path)
		var meta_title := str(meta.get("title", "")).strip_edges()
		var meta_artist := str(meta.get("artist", "")).strip_edges()
		if meta_title != "":
			var label_key := "%s|%s" % [meta_title, meta_artist]
			if not _library_paths_by_label.has(label_key):
				_library_paths_by_label[label_key] = song_path


func _resolve_session_song_path(session: Dictionary) -> String:
	if session.is_empty():
		return ""
	_ensure_library_index()
	var path := str(session.get("song_path", "")).replace("\\", "/").strip_edges()
	if path != "":
		if _library_paths_by_file.has(path):
			return str(_library_paths_by_file[path])
		var file_key := path.get_file().to_lower()
		if _library_paths_by_file.has(file_key):
			return str(_library_paths_by_file[file_key])
		if FileAccess.file_exists(path):
			return path
	var title := str(session.get("title", "")).strip_edges()
	var artist := str(session.get("artist", "")).strip_edges()
	if title == "":
		return ""
	return _find_library_song_path_by_labels(title, artist)


func _find_library_song_path(path: String) -> String:
	_ensure_library_index()
	if path == "":
		return ""
	if _library_paths_by_file.has(path):
		return str(_library_paths_by_file[path])
	var file_key := path.get_file().to_lower()
	if _library_paths_by_file.has(file_key):
		return str(_library_paths_by_file[file_key])
	return ""


func _find_library_song_path_by_labels(title: String, artist: String) -> String:
	_ensure_library_index()
	if title == "":
		return ""
	var exact_key := "%s|%s" % [title, artist]
	if _library_paths_by_label.has(exact_key):
		return str(_library_paths_by_label[exact_key])
	var title_only_key := "%s|" % title
	if artist == "" and _library_paths_by_label.has(title_only_key):
		return str(_library_paths_by_label[title_only_key])
	for label_key in _library_paths_by_label.keys():
		if str(label_key).begins_with("%s|" % title):
			return str(_library_paths_by_label[label_key])
	return ""


func _on_card_action_pressed(mode_id: String) -> void:
	if mode_id != _PlayModeIds.LIBRARY:
		MusicManager.play_modifier_select_sound()
	if mode_id == _PlayModeIds.LIBRARY:
		_open_library()
		return
	if not PlayerDataManager.is_play_mode_unlocked(mode_id):
		_show_unlock_dialog(mode_id)
		return
	if mode_id == _PlayModeIds.ENDLESS:
		_open_endless_session_setup()
		return
	if mode_id == _PlayModeIds.MARATHON:
		_open_marathon_catalog()
		return
	_show_coming_soon_notice(mode_id)


func _on_card_zone_action(action: String, payload: Dictionary) -> void:
	if action == "replay_library":
		_replay_library_session(payload)
	elif action == "replay_endless":
		_replay_endless_last_config()
	elif action == "same_setup_endless":
		_start_endless_same_setup()
	elif action == "daily_marathon_play":
		_start_daily_marathon_run()
	elif action == "daily_marathon_details":
		_open_marathon_daily_catalog()


func _start_daily_marathon_run() -> void:
	MusicManager.play_select_sound()
	if transitions == null or not transitions.has_method("open_marathon_daily_run"):
		return
	if not transitions.open_marathon_daily_run():
		var route_id := _MarathonDailyRoute.today_route_id()
		var template := _MarathonRouteCatalog.template_for_route(route_id)
		_show_notice(_MarathonRouteLength.not_enough_songs_message(template))


func _open_marathon_daily_catalog() -> void:
	MusicManager.play_select_sound()
	if transitions and transitions.has_method("open_marathon_catalog_daily"):
		transitions.open_marathon_catalog_daily()


func _replay_endless_last_config() -> void:
	if transitions == null:
		return
	var config: Dictionary = PlayerDataManager.get_endless_session_last()
	if config.is_empty():
		var stats: Dictionary = PlayerDataManager.get_endless_stats()
		var last_run: Variant = stats.get("last_run", {})
		if last_run is Dictionary:
			config = last_run.get("config", {})
	if config is not Dictionary or config.is_empty():
		_show_notice(tr("PLAY_MODE_ENDLESS_NO_LAST_CONFIG"))
		return
	if not _endless_config_has_playable_scope(config):
		_show_notice(tr("PLAY_MODE_SETUP_POOL_EMPTY"))
		return
	MusicManager.play_select_sound()
	if transitions.has_method("open_endless_run"):
		transitions.open_endless_run(config)


func _start_endless_same_setup() -> void:
	if transitions == null:
		return
	var config: Dictionary = PlayerDataManager.get_endless_session_last() if PlayerDataManager.has_method("get_endless_session_last") else {}
	if config.is_empty():
		_show_notice(tr("PLAY_MODE_ENDLESS_NO_LAST_CONFIG"))
		return
	if not _endless_config_has_playable_scope(config):
		_show_notice(tr("PLAY_MODE_SETUP_POOL_EMPTY"))
		return
	MusicManager.play_select_sound()
	if transitions.has_method("open_endless_run"):
		transitions.open_endless_run(config)


func _endless_config_has_playable_scope(config: Dictionary) -> bool:
	var sanitized := _EndlessSessionConfig.sanitize(config)
	return not _SessionScopeResolver.resolve_scope(sanitized).is_empty()


func _hero_streak_for_mode(mode_id: String, locked: bool) -> int:
	if locked or mode_id != _PlayModeIds.ENDLESS:
		return 0
	if PlayerDataManager.has_method("get_endless_best_streak"):
		return int(PlayerDataManager.get_endless_best_streak())
	return 0


func _nearest_play_mode_achievement_line() -> String:
	if _nearest_ach_line_valid:
		return _nearest_ach_line_cache
	var mgr := _get_achievement_manager()
	if mgr == null:
		_nearest_ach_line_valid = true
		_nearest_ach_line_cache = ""
		return ""
	var candidates: Array[Dictionary] = []
	for raw in mgr.achievements:
		if not raw is Dictionary:
			continue
		var ach: Dictionary = raw
		if ach.get("unlocked", false):
			continue
		var ach_id := int(ach.get("id", -1))
		if ach_id < 152 or ach_id > 165:
			continue
		candidates.append(ach)
	if candidates.is_empty():
		_nearest_ach_line_valid = true
		_nearest_ach_line_cache = ""
		return ""
	var picked := _MainMenuNearestAchievement.pick_nearest(candidates)
	if picked.is_empty():
		_nearest_ach_line_valid = true
		_nearest_ach_line_cache = ""
		return ""
	var ach: Dictionary = picked.get("achievement", {})
	var title := _AchievementLocale.localized_title(ach)
	var progress := _MainMenuNearestAchievement.progress_label_for(ach, mgr)
	_nearest_ach_line_cache = tr("PLAY_MODE_NEAREST_ACH_FMT") % [title, progress]
	_nearest_ach_line_valid = true
	return _nearest_ach_line_cache


func _marathon_current_rotation_progress() -> Dictionary:
	var total := 0
	var completed := 0
	if not _MarathonSeason.is_enabled():
		return {"completed": completed, "total": total}
	for rid in _MarathonSeason.current_rotation_route_ids():
		total += 1
		if _marathon_route_is_complete(rid):
			completed += 1
	return {"completed": completed, "total": total}


func _marathon_route_is_complete(route_id: String) -> bool:
	var completions: Variant = PlayerDataManager.data.get("marathon_completions", {})
	if not completions is Dictionary:
		return false
	var entry: Variant = completions.get(route_id, {})
	return entry is Dictionary and float(entry.get("best_ratio", 0.0)) >= 0.999


func _get_achievement_manager() -> AchievementManager:
	var game_engine := get_parent()
	if game_engine != null and game_engine.has_method("get_achievement_manager"):
		return game_engine.get_achievement_manager()
	return null


func _replay_library_session(payload: Dictionary) -> void:
	var session: Dictionary = payload.get("session", {})
	if session.is_empty():
		session = _get_latest_session()
	if session.is_empty():
		return
	var song_path := _resolve_session_song_path(session)
	if song_path == "":
		return
	var song_data := _build_replay_song_data(session, song_path)
	if song_data.is_empty():
		return
	MusicManager.play_select_sound()
	MusicManager.pause_menu_music()
	if transitions == null:
		return
	var instrument := _instrument_key_from_session(session)
	transitions.open_game_with_song(song_data, instrument, _history_service, "basic", 4, [])


func _build_replay_song_data(session: Dictionary, song_path: String) -> Dictionary:
	var title := str(session.get("title", "")).strip_edges()
	var artist := str(session.get("artist", "")).strip_edges()
	var data := {
		"path": song_path,
		"title": title,
		"artist": artist,
	}
	if SongLibrary and SongLibrary.has_method("get_display_metadata_for_song"):
		var display := SongLibrary.get_display_metadata_for_song(song_path)
		if display is Dictionary and not display.is_empty():
			data = display.duplicate(true)
			data["path"] = song_path
			if title != "":
				data["title"] = title
			if artist != "":
				data["artist"] = artist
	return data


func _instrument_key_from_session(session: Dictionary) -> String:
	var instrument := str(session.get("instrument", ""))
	if instrument.find("еркусс") != -1 or instrument.to_lower().find("drum") != -1:
		return "drums"
	return "standard"


func _open_marathon_catalog() -> void:
	if transitions and transitions.has_method("open_marathon_catalog_from_play_modes"):
		transitions.open_marathon_catalog_from_play_modes()


func _open_endless_session_setup() -> void:
	if transitions:
		transitions.open_endless_session_setup_from_play_modes()


func _open_library() -> void:
	MusicManager.play_modifier_select_sound()
	if transitions:
		transitions.open_song_select_from_play_modes()


func _show_coming_soon_notice(mode_id: String) -> void:
	if _notice_overlay == null:
		return
	var title_key := "PLAY_MODE_%s_TITLE" % mode_id.to_upper()
	_notice_overlay.show_with_actions(
		tr("PLAY_MODE_COMING_SOON_TITLE"),
		tr("PLAY_MODE_COMING_SOON_BODY") % tr(title_key),
	)


func _show_unlock_dialog(mode_id: String) -> void:
	if _choice_overlay == null or _prompt_active:
		return
	_prompt_active = true
	var title_key := "PLAY_MODE_%s_TITLE" % mode_id.to_upper()
	var message := tr("PLAY_MODE_UNLOCK_BODY") % tr(title_key)
	message += "\n\n" + _unlock_requirements_text(mode_id)
	var can_unlock: bool = PlayerDataManager.meets_play_mode_unlock_requirements(mode_id)
	var choice := await _Overlay.choose(
		_choice_overlay,
		message,
		"info",
		tr("PLAY_MODE_UNLOCK_TITLE"),
		tr("PLAY_MODE_UNLOCK_ACTION") if can_unlock else "",
		tr("BTN_CANCEL"),
		"",
	)
	_prompt_active = false
	if choice == "confirm" and can_unlock:
		if PlayerDataManager.try_unlock_play_mode_with_diamonds(mode_id):
			_refresh_cards(true)
		else:
			_show_notice(tr("PLAY_MODE_UNLOCK_FAILED"))


func _show_notice(message: String) -> void:
	if _notice_overlay:
		_notice_overlay.show_message(message)


func _execute_close_transition() -> void:
	if transitions:
		transitions.close_play_modes()


func _unhandled_input(event: InputEvent) -> void:
	if _prompt_active:
		return
	if UiScreenHotkeys.try_handle(_hotkey_bindings(), event, get_viewport()):
		accept_event()
		return
	super._unhandled_input(event)


func _hotkey_bindings() -> Dictionary:
	return {
		KEY_1: _activate_card.bind(0),
		KEY_2: _activate_card.bind(1),
		KEY_3: _activate_card.bind(2),
		KEY_ENTER: _activate_focused_card,
		KEY_KP_ENTER: _activate_focused_card,
	}


func _activate_card(index: int) -> void:
	if index < 0 or index >= _cards.size():
		return
	_focused_card_index = index
	_sync_card_focus()
	_cards[index].action_pressed.emit(_cards[index].mode_id)


func _activate_focused_card() -> void:
	_activate_card(_focused_card_index)


func _sync_card_focus() -> void:
	for i in range(_cards.size()):
		if _cards[i]:
			_cards[i].set_focused(i == _focused_card_index)
	_sync_ambient_for_focus()


func _sync_ambient_for_focus() -> void:
	var engine := get_parent()
	if engine == null or not engine.has_method("set_ambient_screen_profile"):
		return
	var mode_id := ""
	if _focused_card_index >= 0 and _focused_card_index < _cards.size():
		var card := _cards[_focused_card_index]
		if card:
			mode_id = card.mode_id
	match mode_id:
		_PlayModeIds.ENDLESS:
			engine.set_ambient_screen_profile(&"play_modes_endless")
		_PlayModeIds.MARATHON:
			engine.set_ambient_screen_profile(&"play_modes_marathon")
		_:
			engine.set_ambient_screen_profile(&"play_modes")
