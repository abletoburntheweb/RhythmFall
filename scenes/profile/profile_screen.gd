# scenes/profile/profile_screen.gd
class_name ProfileScreen
extends BaseScreen

const _SpotlightTutorialScene = preload("res://ui/spotlight_tutorial.tscn")
const UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")
const _UiRoundedClip = preload("res://logic/ui/ui_rounded_clip.gd")
const _FAVORITE_COVER_RADIUS := 10.0

const _ROOT := "MainVBox/ProfileRoot"
const _CATEGORIES_HBOX_PATH := "MainVBox/CategoryRow/CategoryBarPanel/CategoriesHBox"

var current_profile_category: String = "overview"
var _profile_initial_refresh_done := false
var _profile_skip_category_transition := true
var category_nav: ProfileCategoryNav = null

var session_history_manager = null
var results_history_service = null
var achievement_manager: AchievementManager = null

var overview_tab
var stats_tab
var genres_tab
var records_tab

var _share_recap_loading := false
var _nav_loading_held := false
var _spotlight_tutorial: CanvasLayer = null
var _refresh_stats_scheduled := false
var _applying_locale := false
var _initial_profile_refresh_running := false

@onready var back_button: Button = get_node_or_null("MainVBox/BackButton") as Button
@onready var title_label: Label = get_node_or_null("MainVBox/TitleRow/TitleLabel") as Label
@onready var subtitle_label: Label = get_node_or_null("MainVBox/TitleRow/SubtitleLabel") as Label
@onready var calendar_button: Button = get_node_or_null("%CalendarButton") as Button
@onready var history_button: Button = get_node_or_null("%HistoryButton") as Button
@onready var share_cards_button: Button = get_node_or_null("%ShareCardsButton") as Button
@onready var footer_label: Label = get_node_or_null("MainVBox/FooterLabel") as Label
@onready var _share_modal: ProfileShareModal = get_node_or_null("ProfileShareModal") as ProfileShareModal
@onready var _activity_calendar_dialog: Control = get_node_or_null("ActivityCalendarDialog") as Control
@onready var _history_dialog: Control = get_node_or_null("ProfileHistoryDialog") as Control
@onready var profile_root: Control = get_node_or_null(_ROOT) as Control
@onready var category_bar_panel: PanelContainer = get_node_or_null(
	"MainVBox/CategoryRow/CategoryBarPanel"
) as PanelContainer


func apply_locale() -> void:
	if _applying_locale:
		return
	_applying_locale = true
	if back_button:
		back_button.text = tr("BTN_BACK")
	if title_label:
		title_label.text = tr("PROFILE_TITLE")
		title_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.98, 1.0))
		title_label.add_theme_font_size_override("font_size", 34)
	if subtitle_label:
		subtitle_label.text = tr("PROFILE_SUBTITLE")
		subtitle_label.add_theme_color_override("font_color", Color(0.55, 0.62, 0.72, 0.9))
		subtitle_label.add_theme_font_size_override("font_size", 15)
	if calendar_button:
		calendar_button.text = tr("PROFILE_CALENDAR_OPEN_BUTTON")
		calendar_button.tooltip_text = tr("PROFILE_ACTIVITY_OPEN_TIP")
		calendar_button.set_meta("ui_icon_file", "calendar.svg")
		UiIconHelper.apply_icon_from_meta(calendar_button, 18)
	if history_button:
		history_button.text = tr("PROFILE_HISTORY_OPEN_BUTTON")
		history_button.tooltip_text = tr("PROFILE_HISTORY_OPEN_TIP")
		history_button.set_meta("ui_icon_file", "scroll-text.svg")
		UiIconHelper.apply_icon_from_meta(history_button, 18)
	if share_cards_button:
		share_cards_button.text = tr("PROFILE_SHARE_OPEN_BUTTON")
		share_cards_button.tooltip_text = tr("PROFILE_SHARE_OPEN_TIP")
		share_cards_button.set_meta("ui_icon_file", "file-chart-column.svg")
		UiIconHelper.apply_icon_from_meta(share_cards_button, 18)
	call_deferred("_balance_category_export_row")
	if footer_label:
		_refresh_footer_hint()
	if category_nav:
		category_nav.apply_button_labels()
	if _history_dialog and _history_dialog.has_method("apply_locale"):
		_history_dialog.apply_locale()
	if _profile_initial_refresh_done and not _initial_profile_refresh_running:
		_apply_profile_category_visibility(current_profile_category)
	if overview_tab and overview_tab.has_method("apply_locale"):
		overview_tab.apply_locale()
	if stats_tab and stats_tab.has_method("apply_locale"):
		stats_tab.apply_locale()
	if genres_tab and genres_tab.has_method("apply_locale"):
		genres_tab.apply_locale()
	_applying_locale = false


func _ready() -> void:
	overview_tab = get_node_or_null("%s/OverviewPanel" % _ROOT)
	stats_tab = get_node_or_null("%s/StatsPanel" % _ROOT)
	genres_tab = get_node_or_null("%s/GenresPanel" % _ROOT)
	records_tab = get_node_or_null("%s/RecordsPanel" % _ROOT)
	var favorite_cover := get_node_or_null(
		"%s/OverviewPanel/FavoriteTrackCard/MarginContainer/HBoxContainer/FavoriteCoverTextureRect" % _ROOT
	) as TextureRect
	if favorite_cover:
		_UiRoundedClip.apply_to_canvas_item(favorite_cover, _FAVORITE_COVER_RADIUS)
	if overview_tab and overview_tab.has_method("bind"):
		overview_tab.bind(self)
	if stats_tab and stats_tab.has_method("bind"):
		stats_tab.bind(self)
	if genres_tab and genres_tab.has_method("bind"):
		genres_tab.bind(self)
	var game_engine = get_parent()
	if game_engine and game_engine.has_method("get_transitions"):
		var trans = game_engine.get_transitions()
		setup_managers(trans)

		var session_hist_mgr = null
		if game_engine.has_method("get_results_history_service"):
			results_history_service = game_engine.get_results_history_service()
			session_hist_mgr = results_history_service
		if game_engine.has_method("get_achievement_manager"):
			achievement_manager = game_engine.get_achievement_manager()

		if session_hist_mgr:
			setup_session_history_manager(session_hist_mgr)

		PlayerDataManager.total_play_time_changed.connect(_on_total_play_time_changed)
		PlayerDataManager.daily_quests_updated.connect(_on_daily_quests_updated)
		if PlayerDataManager.has_signal("calendar_day_changed"):
			PlayerDataManager.calendar_day_changed.connect(_on_calendar_day_changed)
		if PlayerDataManager.has_signal("profile_statistics_reset"):
			if not PlayerDataManager.profile_statistics_reset.is_connected(_on_profile_statistics_reset):
				PlayerDataManager.profile_statistics_reset.connect(_on_profile_statistics_reset)
	else:
		printerr("ProfileScreen.gd: Не удалось получить transitions через GameEngine.")

	if overview_tab and overview_tab.has_method("setup"):
		overview_tab.setup()
	if stats_tab and stats_tab.has_method("setup"):
		stats_tab.setup()

	category_nav = ProfileCategoryNav.new()
	category_nav.name = "CategoryNav"
	category_nav.initialize(self)
	category_nav.skip_transition = _profile_skip_category_transition
	add_child(category_nav)

	_restore_profile_category_from_settings()
	_migrate_legacy_profile_layout()
	if category_nav.has_method("remove_records_category_button"):
		category_nav.remove_records_category_button()
	_setup_profile_categories()

	if calendar_button and not calendar_button.pressed.is_connected(_on_calendar_button_pressed):
		calendar_button.pressed.connect(_on_calendar_button_pressed)
	if history_button and not history_button.pressed.is_connected(_on_history_button_pressed):
		history_button.pressed.connect(_on_history_button_pressed)
	if share_cards_button and not share_cards_button.pressed.is_connected(_on_share_cards_pressed):
		share_cards_button.pressed.connect(_on_share_cards_pressed)
		call_deferred("_balance_category_export_row")
	if _share_modal and not _share_modal.closed.is_connected(_on_share_modal_closed):
		_share_modal.closed.connect(_on_share_modal_closed)
	if _history_dialog and _history_dialog.has_signal("closed") and not _history_dialog.closed.is_connected(_on_history_dialog_closed):
		_history_dialog.closed.connect(_on_history_dialog_closed)
	var category_row := get_node_or_null("MainVBox/CategoryRow") as Control
	if category_row and not category_row.resized.is_connected(_balance_category_export_row):
		category_row.resized.connect(_balance_category_export_row)

	call_deferred("_initial_profile_refresh")

	if back_button == null:
		printerr("ProfileScreen: Кнопка back_button не найдена!")


func open_activity_calendar() -> void:
	_close_profile_overlays("calendar")
	if _activity_calendar_dialog and _activity_calendar_dialog.has_method("open"):
		_activity_calendar_dialog.open()


func open_activity_calendar_month(month_key: String) -> void:
	var key := str(month_key).strip_edges()
	if key.length() < 7:
		open_activity_calendar()
		return
	var parts := key.split("-")
	if parts.size() < 2:
		open_activity_calendar()
		return
	_close_profile_overlays("calendar")
	if _activity_calendar_dialog and _activity_calendar_dialog.has_method("open_month"):
		_activity_calendar_dialog.open_month(int(parts[0]), int(parts[1]))
	else:
		open_activity_calendar()


func open_activity_calendar_day(date_iso: String) -> void:
	var raw := str(date_iso).strip_edges()
	if raw == "":
		open_activity_calendar()
		return
	_close_profile_overlays("calendar")
	if _activity_calendar_dialog and _activity_calendar_dialog.has_method("open_day"):
		_activity_calendar_dialog.open_day(raw)
	else:
		open_activity_calendar()


func open_library_song(song_path: String) -> void:
	var path := str(song_path).replace("\\", "/").strip_edges()
	if path == "":
		return
	var open_museum := bool(SettingsManager.get_setting("diary_open_track_museum", false))
	_close_profile_overlays("")
	if transitions and transitions.has_method("open_song_select_focusing"):
		transitions.open_song_select_focusing(path, open_museum)


func open_history(section: String = "timeline", focus_section_id: String = "") -> void:
	_close_profile_overlays("history")
	if _history_dialog and _history_dialog.has_method("open"):
		_history_dialog.open(section, focus_section_id)
		_refresh_footer_hint()


func _on_history_dialog_closed() -> void:
	_refresh_footer_hint()


func _refresh_footer_hint() -> void:
	if footer_label == null:
		return
	var history_open: bool = (
		_history_dialog != null
		and _history_dialog.has_method("is_open")
		and bool(_history_dialog.is_open())
	)
	if history_open and _history_dialog.has_method("get_footer_hint"):
		footer_label.text = str(_history_dialog.get_footer_hint())
	elif history_open:
		footer_label.text = tr("PROFILE_HISTORY_FOOTER_HINT")
	elif current_profile_category == "stats":
		footer_label.text = tr("PROFILE_FOOTER_HINT_STATS")
	else:
		footer_label.text = tr("PROFILE_FOOTER_HINT")


func get_total_rr_earned() -> int:
	if ProfileMilestonesManager:
		return ProfileMilestonesManager.get_total_rr_earned()
	return 0


func hold_nav_loading() -> void:
	## Called from Transitions before the nav overlay hide — keeps spinner through first paint.
	if _nav_loading_held:
		return
	var overlay := _resolve_loading_overlay()
	if overlay == null:
		return
	overlay.show_loading(tr("UI_LOADING_PROFILE"), true)
	_nav_loading_held = true


func _resolve_loading_overlay() -> LoadingOverlay:
	var overlay := _get_loading_overlay()
	if overlay:
		return overlay
	# Before enter_tree, get_parent() is null — fall back via Transitions.
	if transitions and transitions.get("game_engine") and transitions.game_engine.has_method("get_loading_overlay"):
		return transitions.game_engine.get_loading_overlay()
	return null


func _release_nav_loading() -> void:
	if not _nav_loading_held:
		return
	_nav_loading_held = false
	var overlay := _resolve_loading_overlay()
	if overlay:
		overlay.hide_loading()


func with_profile_loading(action: Callable, message_key: String = "UI_LOADING_PROFILE") -> void:
	var overlay := _resolve_loading_overlay()
	if overlay:
		overlay.show_loading(tr(message_key), true)
	# Let the spinner paint before heavy sync work freezes the main thread.
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await action.call()
	if overlay:
		overlay.hide_loading()


func setup_session_history_manager(session_history_mgr) -> void:
	session_history_manager = session_history_mgr
	results_history_service = session_history_mgr
	if _profile_initial_refresh_done and not _initial_profile_refresh_running:
		refresh_stats()


func refresh_stats() -> void:
	if _refresh_stats_scheduled:
		return
	_refresh_stats_scheduled = true
	call_deferred("_run_refresh_stats")


func _run_refresh_stats() -> void:
	_refresh_stats_scheduled = false
	if overview_tab and overview_tab.has_method("refresh_fast"):
		overview_tab.refresh_fast()
	if stats_tab and stats_tab.has_method("refresh_fast"):
		stats_tab.refresh_fast()
	if genres_tab and genres_tab.has_method("refresh_if_visible"):
		genres_tab.refresh_if_visible()
	if _initial_profile_refresh_running or not _profile_initial_refresh_done:
		if achievement_manager:
			achievement_manager.check_rr_mastery_achievements()
		return
	if current_profile_category == "overview" and overview_tab and overview_tab.has_method("schedule_heavy_refresh"):
		overview_tab.schedule_heavy_refresh()
	elif current_profile_category == "stats" and stats_tab and stats_tab.has_method("request_chart_update"):
		stats_tab.request_chart_update()
	if achievement_manager:
		achievement_manager.check_rr_mastery_achievements()


func on_category_nav_changed(category: String) -> void:
	current_profile_category = category
	_apply_profile_category_visibility(category)
	_refresh_footer_hint()
	if category == "stats" and stats_tab and stats_tab.has_method("on_tab_shown"):
		stats_tab.on_tab_shown()


func _on_profile_category_selected(category: String) -> void:
	if category_nav:
		category_nav.select(category)


func _initial_profile_refresh() -> void:
	_initial_profile_refresh_running = true
	if _nav_loading_held:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		await _run_initial_profile_data_refresh()
		_release_nav_loading()
	else:
		await with_profile_loading(_run_initial_profile_data_refresh)
	_initial_profile_refresh_running = false
	_profile_initial_refresh_done = true
	_profile_skip_category_transition = false
	call_deferred("_maybe_show_profile_tutorial")


func _run_initial_profile_data_refresh() -> void:
	refresh_stats()
	await get_tree().process_frame
	match current_profile_category:
		"overview":
			if overview_tab and overview_tab.has_method("refresh_content_async"):
				await overview_tab.refresh_content_async()
		"stats":
			if stats_tab and stats_tab.has_method("update_session_chart"):
				stats_tab.update_session_chart()
			await get_tree().process_frame
		"genres":
			if genres_tab and genres_tab.has_method("rebuild_async"):
				await genres_tab.rebuild_async()


func _on_total_play_time_changed(_new_time: String) -> void:
	if overview_tab and overview_tab.has_method("on_play_time_changed"):
		overview_tab.on_play_time_changed()


func _on_daily_quests_updated() -> void:
	if stats_tab and stats_tab.has_method("on_daily_quests_updated"):
		stats_tab.on_daily_quests_updated()


func _on_calendar_day_changed(_new_date: String) -> void:
	if overview_tab and overview_tab.has_method("on_calendar_day_changed"):
		overview_tab.on_calendar_day_changed()


func _on_profile_statistics_reset() -> void:
	ProfileShareSnapshot.invalidate_cache()
	refresh_stats()


func _restore_profile_category_from_settings() -> void:
	category_nav.restore_from_settings()
	current_profile_category = category_nav.current_category


func _migrate_legacy_profile_layout() -> void:
	var hbox := get_node_or_null(_CATEGORIES_HBOX_PATH) as HBoxContainer
	if hbox:
		var medals_btn := hbox.get_node_or_null("CategoryButtonMedals") as Button
		if medals_btn:
			hbox.remove_child(medals_btn)
			medals_btn.queue_free()
		var records_btn := hbox.get_node_or_null("CategoryButtonRecords") as Button
		if records_btn:
			hbox.remove_child(records_btn)
			records_btn.queue_free()

	if current_profile_category == "medals" or current_profile_category == "records":
		current_profile_category = "overview"
		if category_nav:
			category_nav.current_category = "overview"

	if overview_tab and overview_tab.has_method("migrate_legacy_layout"):
		overview_tab.migrate_legacy_layout()


func _setup_profile_categories() -> void:
	category_nav.current_category = current_profile_category
	category_nav.setup()
	_apply_profile_category_visibility(current_profile_category)
	if current_profile_category == "stats" and stats_tab and stats_tab.has_method("on_tab_shown"):
		stats_tab.call_deferred("on_tab_shown")


func _apply_profile_category_visibility(category: String) -> void:
	if overview_tab:
		overview_tab.visible = category == "overview"
	if stats_tab:
		stats_tab.visible = category == "stats"
	if genres_tab:
		genres_tab.visible = category == "genres"
	if records_tab:
		records_tab.visible = false
	if not _profile_initial_refresh_done or _initial_profile_refresh_running:
		return
	if category == "stats" and stats_tab and stats_tab.has_method("request_chart_update"):
		stats_tab.request_chart_update()
	if category == "genres" and _profile_initial_refresh_done:
		if genres_tab:
			var panel = genres_tab.get_genres_panel() if genres_tab.has_method("get_genres_panel") else null
			if panel and panel.is_built():
				panel.refresh_catalog_only()
			else:
				call_deferred("_refresh_genres_panel")
	if category == "overview" and _profile_initial_refresh_done and overview_tab and overview_tab.has_method("schedule_heavy_refresh"):
		call_deferred("_schedule_overview_heavy_refresh")


func open_records_section(section_id: String = "") -> void:
	var sid := str(section_id).strip_edges()
	var group := ProfileRecordsView.group_for_section_id(sid)
	open_history(group, sid)


func _schedule_overview_heavy_refresh() -> void:
	if overview_tab and overview_tab.has_method("schedule_heavy_refresh"):
		overview_tab.schedule_heavy_refresh()


func _refresh_genres_panel() -> void:
	if genres_tab and genres_tab.has_method("refresh_panel"):
		genres_tab.refresh_panel()


func _maybe_show_profile_tutorial(force: bool = false) -> void:
	if not SettingsManager or not SettingsManager.has_method("get_tutorial_profile_done"):
		return
	if not force and SettingsManager.get_tutorial_profile_done():
		return
	_run_profile_tutorial(force)


func _run_profile_tutorial(force: bool) -> void:
	if not force and SettingsManager and SettingsManager.get_tutorial_profile_done():
		return
	if current_profile_category != "overview":
		current_profile_category = "overview"
		category_nav.update_buttons("overview")
		_apply_profile_category_visibility("overview")
	await get_tree().process_frame
	await get_tree().process_frame
	if _spotlight_tutorial == null:
		_spotlight_tutorial = _SpotlightTutorialScene.instantiate() as CanvasLayer
		if _spotlight_tutorial == null:
			return
		add_child(_spotlight_tutorial)
		if not _spotlight_tutorial.finished.is_connected(_on_profile_tutorial_closed):
			_spotlight_tutorial.finished.connect(_on_profile_tutorial_closed)
		if not _spotlight_tutorial.skipped.is_connected(_on_profile_tutorial_closed):
			_spotlight_tutorial.skipped.connect(_on_profile_tutorial_closed)
		if _spotlight_tutorial.has_signal("step_shown") and not _spotlight_tutorial.step_shown.is_connected(_on_profile_tutorial_step_shown):
			_spotlight_tutorial.step_shown.connect(_on_profile_tutorial_step_shown)
	var category_hbox := get_node_or_null(_CATEGORIES_HBOX_PATH) as Control
	var overview_btn := category_nav.get_category_button("overview")
	var chart_card: Control = null
	var chart_metric_accuracy: Button = null
	var genres_panel_node: Node = null
	if stats_tab and stats_tab.has_method("get_chart_card"):
		chart_card = stats_tab.get_chart_card()
	if stats_tab and stats_tab.has_method("get_chart_metric_button"):
		chart_metric_accuracy = stats_tab.get_chart_metric_button("accuracy")
	if genres_tab and genres_tab.has_method("get_genres_panel"):
		genres_panel_node = genres_tab.get_genres_panel()
	elif genres_tab:
		genres_panel_node = genres_tab
	var steps: Array = [
		{
			"title_key": "TUTORIAL_PRO_1_TITLE",
			"body_key": "TUTORIAL_PRO_1_BODY",
			"target": overview_tab if overview_tab else overview_btn,
		},
		{
			"title_key": "TUTORIAL_PRO_2_TITLE",
			"body_key": "TUTORIAL_PRO_2_BODY",
			"target": chart_card if chart_card else chart_metric_accuracy,
		},
		{
			"title_key": "TUTORIAL_PRO_3_TITLE",
			"body_key": "TUTORIAL_PRO_3_BODY",
			"target": genres_panel_node if genres_panel_node else genres_tab,
		},
		{
			"title_key": "TUTORIAL_PRO_4_TITLE",
			"body_key": "TUTORIAL_PRO_4_BODY",
			"target": history_button if history_button else calendar_button,
		},
		{
			"title_key": "TUTORIAL_PRO_5_TITLE",
			"body_key": "TUTORIAL_PRO_5_BODY",
			"target": share_cards_button,
		},
	]
	if category_hbox:
		steps.insert(0, {
			"title_key": "TUTORIAL_PRO_0_TITLE",
			"body_key": "TUTORIAL_PRO_0_BODY",
			"target": category_hbox,
		})
	if _spotlight_tutorial.has_method("start"):
		_spotlight_tutorial.start(steps)


func _switch_profile_category_for_tutorial(category: String) -> void:
	if not category_nav.is_valid_category(category):
		return
	if current_profile_category == category:
		return
	current_profile_category = category
	category_nav.update_buttons(category)
	_apply_profile_category_visibility(category)
	if category == "stats" and stats_tab and stats_tab.has_method("request_chart_update"):
		stats_tab.request_chart_update()
	elif category == "genres" and genres_tab and genres_tab.has_method("refresh_if_visible"):
		genres_tab.refresh_if_visible()


func _on_profile_tutorial_step_shown(step_index: int) -> void:
	# After optional CategoryBar intro: overview, stats, genres/music; history+export stay on overview.
	var categories := ["overview", "stats", "genres", "overview", "overview"]
	var category_hbox := get_node_or_null(_CATEGORIES_HBOX_PATH) as Control
	var offset := 1 if category_hbox else 0
	if step_index < offset:
		return
	var category_index := step_index - offset
	if category_index < 0 or category_index >= categories.size():
		return
	_switch_profile_category_for_tutorial(categories[category_index])


func _on_profile_tutorial_closed() -> void:
	if SettingsManager and SettingsManager.has_method("set_tutorial_profile_done"):
		SettingsManager.set_tutorial_profile_done(true)


func debug_show_tutorial() -> void:
	_run_profile_tutorial(true)


func cleanup_before_exit() -> void:
	_nav_loading_held = false
	var overlay := _get_loading_overlay()
	if overlay:
		overlay.reset_loading()


func _balance_category_export_row() -> void:
	# Tabs centered; Calendar / History / Export overlaid on the right (rightmost = Export).
	var row := get_node_or_null("MainVBox/CategoryRow") as Control
	if row == null or category_bar_panel == null:
		return
	category_bar_panel.reset_size()
	var bar_size := category_bar_panel.get_combined_minimum_size()
	if bar_size.x <= 1.0:
		bar_size = category_bar_panel.size
	var row_h := maxf(row.size.y, maxf(bar_size.y, 58.0))
	row.custom_minimum_size.y = row_h
	var bar_x := (row.size.x - bar_size.x) * 0.5
	var bar_y := (row_h - bar_size.y) * 0.5
	category_bar_panel.position = Vector2(maxf(bar_x, 0.0), maxf(bar_y, 0.0))
	category_bar_panel.size = bar_size
	var gap := 8.0
	var right_x := row.size.x
	if share_cards_button and is_instance_valid(share_cards_button):
		share_cards_button.reset_size()
		var share_size := share_cards_button.get_combined_minimum_size()
		if share_size.x <= 1.0:
			share_size = share_cards_button.size
		var share_y := (row_h - share_size.y) * 0.5
		share_cards_button.position = Vector2(maxf(right_x - share_size.x, 0.0), maxf(share_y, 0.0))
		share_cards_button.size = share_size
		right_x = share_cards_button.position.x - gap
	if history_button and is_instance_valid(history_button):
		history_button.reset_size()
		var hist_size := history_button.get_combined_minimum_size()
		if hist_size.x <= 1.0:
			hist_size = history_button.size
		var hist_y := (row_h - hist_size.y) * 0.5
		history_button.position = Vector2(maxf(right_x - hist_size.x, 0.0), maxf(hist_y, 0.0))
		history_button.size = hist_size
		right_x = history_button.position.x - gap
	if calendar_button and is_instance_valid(calendar_button):
		calendar_button.reset_size()
		var cal_size := calendar_button.get_combined_minimum_size()
		if cal_size.x <= 1.0:
			cal_size = calendar_button.size
		var cal_y := (row_h - cal_size.y) * 0.5
		calendar_button.position = Vector2(maxf(right_x - cal_size.x, 0.0), maxf(cal_y, 0.0))
		calendar_button.size = cal_size


func _on_calendar_button_pressed() -> void:
	# Dialog open() plays modifier_select — avoid stacking MusicManager select.
	open_activity_calendar()


func _on_history_button_pressed() -> void:
	# Dialog open() plays modifier_select — avoid stacking MusicManager select.
	open_history("timeline")


func _on_share_cards_pressed() -> void:
	if _share_modal == null or _share_recap_loading:
		return
	_open_share_recap_async()


func _open_share_recap_async() -> void:
	_close_profile_overlays("share")
	_share_recap_loading = true
	if share_cards_button:
		share_cards_button.disabled = true
	if _share_modal:
		await _share_modal.prepare_and_open()
	if share_cards_button:
		share_cards_button.disabled = false
	_share_recap_loading = false


func _on_share_modal_closed() -> void:
	pass


func _is_calendar_open() -> bool:
	return (
		_activity_calendar_dialog != null
		and _activity_calendar_dialog.has_method("is_open")
		and bool(_activity_calendar_dialog.is_open())
	)


func _is_history_open() -> bool:
	return (
		_history_dialog != null
		and _history_dialog.has_method("is_open")
		and bool(_history_dialog.is_open())
	)


func _is_share_open() -> bool:
	return _share_modal != null and _share_modal.is_open()


func _close_profile_overlays(except: String = "") -> void:
	## Silently dismiss Calendar / History / Recap except the named surface.
	if except != "history" and _is_history_open():
		if _history_dialog.has_method("close"):
			_history_dialog.close(false)
		else:
			_history_dialog.visible = false
	if except != "calendar" and _is_calendar_open():
		if _activity_calendar_dialog.has_method("close"):
			_activity_calendar_dialog.close(false)
		else:
			_activity_calendar_dialog.visible = false
	if except != "share" and _is_share_open():
		_share_modal.close_modal(false)


func _unhandled_input(event: InputEvent) -> void:
	if UiScreenHotkeys.is_global_loading_active(get_viewport()):
		get_viewport().set_input_as_handled()
		return
	# Calendar on top of History: handle first so Q/E change months, not feed filters.
	if (
		_is_calendar_open()
		and _activity_calendar_dialog.has_method("handle_hotkey")
		and _activity_calendar_dialog.handle_hotkey(event)
	):
		get_viewport().set_input_as_handled()
		return
	if (
		_is_history_open()
		and _history_dialog.has_method("handle_hotkey")
		and _history_dialog.handle_hotkey(event)
	):
		get_viewport().set_input_as_handled()
		return
	if _is_share_open():
		if _share_modal.handle_hotkey(event):
			get_viewport().set_input_as_handled()
			return
	if _handle_profile_hotkeys(event):
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


func _handle_profile_hotkeys(event: InputEvent) -> bool:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return false
	if UiScreenHotkeys.should_block_hotkeys(get_viewport()):
		return false
	if event.keycode >= KEY_1 and event.keycode <= KEY_3:
		var index := int(event.keycode - KEY_1)
		_hotkey_select_profile_category(index)
		return true
	if event.keycode == KEY_4:
		_hotkey_open_calendar()
		return true
	if event.keycode == KEY_5:
		_hotkey_open_history()
		return true
	if event.keycode == KEY_6:
		_hotkey_open_share()
		return true
	if current_profile_category == "stats" and stats_tab and stats_tab.has_method("hotkey_select_chart_metric"):
		if event.keycode == KEY_Q:
			stats_tab.hotkey_select_chart_metric(0)
			return true
		if event.keycode == KEY_W:
			stats_tab.hotkey_select_chart_metric(1)
			return true
		if event.keycode == KEY_E:
			stats_tab.hotkey_select_chart_metric(2)
			return true
	return false


func _hotkey_select_profile_category(index: int) -> void:
	if category_nav == null:
		return
	if index < 0 or index >= ProfileCategoryNav.CATEGORY_BUTTON_SPECS.size():
		return
	var category := String(ProfileCategoryNav.CATEGORY_BUTTON_SPECS[index][0])
	_on_profile_category_selected(category)


func _hotkey_open_calendar() -> void:
	if _is_calendar_open():
		return
	open_activity_calendar()


func _hotkey_open_history() -> void:
	if _is_history_open():
		return
	open_history("timeline")


func _hotkey_open_share() -> void:
	if _is_share_open() or _share_recap_loading:
		return
	_open_share_recap_async()


func _execute_close_transition() -> void:
	if transitions:
		transitions.close_profile()
	if is_instance_valid(self):
		if PlayerDataManager.is_connected("total_play_time_changed", _on_total_play_time_changed):
			PlayerDataManager.total_play_time_changed.disconnect(_on_total_play_time_changed)
		queue_free()
