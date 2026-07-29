# scenes/main_menu/main_menu.gd
extends Control

var transitions = null

var is_game_open = false

const _DailyQuestLocale = preload("res://logic/i18n/daily_quest_locale.gd")
const _UiMotionEffects = preload("res://logic/ui/ui_motion_effects.gd")
const _Overlay = preload("res://logic/ui/app_overlay_helpers.gd")
const _MainMenuTipOfDay = preload("res://scenes/main_menu/lib/main_menu_tip_of_day.gd")
const _RhythmDnaCoverLoader = preload("res://scenes/song_select/rhythm_dna/lib/rhythm_dna_cover_loader.gd")
const _ResultsHistoryService = preload("res://logic/data/results_history_service.gd")
const _MainMenuNearestAchievement = preload("res://scenes/main_menu/lib/main_menu_nearest_achievement.gd")
const _LAST_TRACK_COVER_PX := 100
const _MainMenuActivityFeed = preload("res://scenes/main_menu/lib/main_menu_activity_feed.gd")
const _SongSelectStrings = preload("res://logic/domain/library/song_select_strings.gd")
const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")
const _AchievementCardScene = preload("res://scenes/achievements/achievement_card.tscn")
const _LAST_TRACK_COVER_ACCENT := Color(0.62, 0.86, 0.72, 1.0)

var github_url = "https://github.com/abletoburntheweb/RhythmFall.git"
@onready var _notice_overlay: AppNoticeOverlay = %NoticeOverlay
@onready var _confirm_overlay: AppConfirmOverlay = %ConfirmOverlay
var _pending_update_result: Dictionary = {}
var _results_history_service: ResultsHistoryService = null

const _SIDEBAR := "RootMargin/RootHBox/LeftSidebar"
const _BTNS := "RootMargin/RootHBox/LeftSidebar/MenuPanel/MenuVBox/ButtonContainer"
const _HUB := "RootMargin/RootHBox/RightHub"
const _MENU_ICON_SIZE := 20

@onready var _shop_button: Button = %ShopButton
@onready var _shop_badge: PanelContainer = get_node("%ShopButton/NewRewardsBadge")
@onready var _shop_badge_label: Label = get_node("%ShopButton/NewRewardsBadge/CountLabel")
@onready var _subtitle_label: Label = get_node("%s/SubtitleLabel" % _SIDEBAR)
@onready var _daily_quests_title: Label = get_node("%s/DailyQuestsPanel/ContentVBox/DailyHeaderRow/HeaderLabel" % _HUB)
@onready var _daily_reset_label: Label = %DailyResetLabel
@onready var _song_select_button: Button = %SongSelectButton
@onready var _achievements_button: Button = %AchievementsButton
@onready var _profile_button: Button = %ProfileButton
@onready var _settings_button: Button = %SettingsButton
@onready var _exit_button: Button = %ExitButton
@onready var _github_button: TextureButton = %GitHubButton
@onready var _help_button: Button = %HelpButton
@onready var _play_again_button: Button = %PlayAgainButton
@onready var _stat_tracks_value: Label = %StatTracksValue
@onready var _stat_perfect_value: Label = %StatPerfectValue
@onready var _stat_combo_value: Label = %StatComboValue
@onready var _stat_accuracy_value: Label = %StatAccuracyValue
@onready var _last_track_cover: TextureRect = %LastTrackCover
@onready var _last_track_title: Label = %LastTrackTitle
@onready var _last_track_artist: Label = %LastTrackArtist
@onready var _last_track_difficulty: Label = %LastTrackDifficulty
@onready var _last_track_accuracy: Label = %LastTrackAccuracy
@onready var _last_track_grade: Label = %LastTrackGrade
@onready var _tip_title_label: Label = %TipTitleLabel
@onready var _tip_body_label: Label = %TipBodyLabel
@onready var _tip_icon: TextureRect = %TipIcon
@onready var _stats_header_label: Label = get_node("%s/MiddleRow/StatsPanel/StatsMargin/StatsVBox/StatsHeaderLabel" % _HUB)
@onready var _stat_tracks_caption: Label = get_node("%s/MiddleRow/StatsPanel/StatsMargin/StatsVBox/StatTracksRow/StatTracksCaption" % _HUB)
@onready var _stat_perfect_caption: Label = get_node("%s/MiddleRow/StatsPanel/StatsMargin/StatsVBox/StatPerfectRow/StatPerfectCaption" % _HUB)
@onready var _stat_combo_caption: Label = get_node("%s/MiddleRow/StatsPanel/StatsMargin/StatsVBox/StatComboRow/StatComboCaption" % _HUB)
@onready var _stat_accuracy_caption: Label = get_node("%s/MiddleRow/StatsPanel/StatsMargin/StatsVBox/StatAccuracyRow/StatAccuracyCaption" % _HUB)
@onready var _last_track_header_label: Label = get_node("%s/MiddleRow/LastTrackPanel/LastTrackMargin/LastTrackVBox/LastTrackHeaderLabel" % _HUB)
@onready var _last_track_panel: PanelContainer = get_node("%s/MiddleRow/LastTrackPanel" % _HUB)
@onready var _nearest_ach_header_label: Label = get_node("%s/NearestAchievementPanel/NearestAchHeaderLabel" % _HUB)
@onready var _nearest_ach_card_slot: VBoxContainer = %NearestAchCardSlot
@onready var _nearest_ach_empty_label: Label = %NearestAchEmptyLabel
@onready var _activity_header_label: Label = %ActivityHeaderLabel
@onready var _activity_list_vbox: VBoxContainer = %ActivityListVBox
@onready var _activity_empty_label: Label = %ActivityEmptyLabel

var _nearest_ach_card: PanelContainer = null
var _refresh_on_show_pending := false
var _last_track_cover_path := ""
var _nearest_ach_id := ""
const _QUEST_ICON_FILE := "list-checks.svg"
const _QUEST_ICON_COLORS: Array[Color] = [
	Color(0.62, 0.86, 0.72, 1.0),
	Color(0.72, 0.58, 0.95, 1.0),
	Color(0.95, 0.78, 0.35, 1.0),
]

const _ICON_HELP_FALLBACK := Color(0.8, 0.86, 0.94, 1.0)
const _ICON_PLAY := Color(0.38, 0.78, 0.74, 1.0)
const _ICON_ACHIEVEMENTS := Color(0.72, 0.58, 0.95, 1.0)
const _ICON_PROFILE := Color(0.55, 0.78, 0.98, 1.0)
const _ICON_SHOP := Color(0.48, 0.86, 0.58, 1.0)
const _ICON_SETTINGS := Color(0.52, 0.76, 0.92, 1.0)
const _ICON_EXIT := Color(0.86, 0.52, 0.72, 1.0)
const _ICON_TIP_STAR := Color(0.45, 0.88, 0.62, 1.0)

func _ready():
	add_to_group("locale_refresh")
	_results_history_service = _ResultsHistoryService.new()
	MusicManager.play_menu_music()
	PlayerDataManager.ensure_daily_quests_for_today()
	if PlayerDataManager.has_signal("daily_quests_updated"):
		PlayerDataManager.connect("daily_quests_updated", Callable(self, "_render_daily_quests"))
	if PlayerDataManager.has_signal("calendar_day_changed"):
		PlayerDataManager.calendar_day_changed.connect(_on_calendar_day_changed)
	if PlayerDataManager.has_signal("shop_new_rewards_changed"):
		PlayerDataManager.shop_new_rewards_changed.connect(_update_shop_badge)
	if PlayerDataManager.has_signal("level_changed"):
		PlayerDataManager.level_changed.connect(func(_l, _x, _n): _update_shop_badge())
	_update_shop_badge()
	call_deferred("_finish_menu_ui_setup")
	call_deferred("_maybe_show_server_setup_notice")
	call_deferred("_maybe_check_updates_on_startup")

	if UpdateChecker and not UpdateChecker.check_completed.is_connected(_on_update_check_completed):
		UpdateChecker.check_completed.connect(_on_update_check_completed)

	if LocaleManager and not LocaleManager.locale_changed.is_connected(_on_locale_changed):
		LocaleManager.locale_changed.connect(_on_locale_changed)
	visibility_changed.connect(_on_visibility_changed)
	_setup_last_track_cover_frame()


func _setup_last_track_cover_frame() -> void:
	## Match nearest-achievement icon frame, with a slightly tighter pad.
	if _last_track_cover == null:
		return
	var frame := _last_track_cover.get_parent() as PanelContainer
	if frame == null:
		return
	var stale := _last_track_cover.get_node_or_null("UiRoundedBorderOverlay")
	if stale:
		_last_track_cover.remove_child(stale)
		stale.queue_free()
	frame.clip_contents = false
	frame.clip_children = CanvasItem.CLIP_CHILDREN_DISABLED
	frame.custom_minimum_size = Vector2(108, 108)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.06, 0.09)
	box.border_color = Color(
		_LAST_TRACK_COVER_ACCENT.r,
		_LAST_TRACK_COVER_ACCENT.g,
		_LAST_TRACK_COVER_ACCENT.b,
		0.5
	)
	box.border_width_top = 3
	box.border_width_left = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.set_corner_radius_all(10)
	box.corner_detail = 12
	box.content_margin_left = 4.0
	box.content_margin_top = 4.0
	box.content_margin_right = 4.0
	box.content_margin_bottom = 4.0
	frame.add_theme_stylebox_override("panel", box)
	_last_track_cover.custom_minimum_size = Vector2(100, 100)
	_last_track_cover.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_last_track_cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_last_track_cover.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Drop heavy rounded-clip helper; achievement shader is already on the TextureRect.


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		if MusicManager and MusicManager.has_method("update_volumes_from_settings"):
			MusicManager.update_volumes_from_settings()
		queue_refresh_on_show()


func queue_refresh_on_show() -> void:
	if _refresh_on_show_pending:
		return
	_refresh_on_show_pending = true
	call_deferred("_run_refresh_on_show")


func _run_refresh_on_show() -> void:
	_refresh_on_show_pending = false
	if not is_visible_in_tree():
		return
	refresh_shop_badge()
	refresh_daily_quests()
	_render_hub_panels()
	refresh_menu_chrome()


func _exit_tree() -> void:
	if LocaleManager and LocaleManager.locale_changed.is_connected(_on_locale_changed):
		LocaleManager.locale_changed.disconnect(_on_locale_changed)


func _on_locale_changed(_locale: String) -> void:
	apply_locale()


func apply_locale() -> void:
	if _subtitle_label:
		_subtitle_label.text = tr("MAIN_SUBTITLE")
	if _song_select_button:
		_song_select_button.text = tr("MAIN_PLAY")
	if _achievements_button:
		_achievements_button.text = tr("MAIN_ACHIEVEMENTS")
	if _profile_button:
		_profile_button.text = tr("MAIN_PROFILE")
	if _shop_button:
		_shop_button.text = tr("MAIN_SHOP")
	if _settings_button:
		_settings_button.text = tr("MAIN_SETTINGS")
	if _exit_button:
		_exit_button.text = tr("MAIN_EXIT")
	if _daily_quests_title:
		_daily_quests_title.text = tr("MAIN_DAILY_QUESTS")
	if _stats_header_label:
		_stats_header_label.text = tr("MAIN_STATISTICS")
	if _stat_tracks_caption:
		_stat_tracks_caption.text = tr("MAIN_STAT_TRACKS")
	if _stat_perfect_caption:
		_stat_perfect_caption.text = tr("MAIN_STAT_PERFECT")
	if _stat_combo_caption:
		_stat_combo_caption.text = tr("MAIN_STAT_COMBO")
	if _stat_accuracy_caption:
		_stat_accuracy_caption.text = tr("MAIN_STAT_ACCURACY")
	if _last_track_header_label:
		_last_track_header_label.text = tr("MAIN_LAST_TRACK")
	if _nearest_ach_header_label:
		_nearest_ach_header_label.text = tr("MAIN_NEAREST_ACHIEVEMENT")
	if _nearest_ach_empty_label:
		_nearest_ach_empty_label.text = tr("MAIN_NEAREST_ACHIEVEMENT_EMPTY")
	if _activity_header_label:
		_activity_header_label.text = tr("MAIN_ACTIVITY_TITLE")
	if _activity_empty_label:
		_activity_empty_label.text = tr("MAIN_ACTIVITY_EMPTY")
	if _play_again_button:
		_play_again_button.text = tr("MAIN_PLAY_AGAIN")
	if _tip_title_label:
		_tip_title_label.text = tr("MAIN_TIP_TITLE")
	if _confirm_overlay:
		_confirm_overlay.apply_locale()
	if _notice_overlay:
		_notice_overlay.apply_locale()
	_apply_help_button_locale()
	refresh_menu_chrome()
	queue_refresh_on_show()
	UiInteractionApplier.clear_redundant_button_tooltips(self)


func _finish_menu_ui_setup() -> void:
	_apply_menu_ui_interactions()
	refresh_menu_chrome()
	apply_locale()


func refresh_menu_chrome() -> void:
	_setup_menu_icons()
	_setup_help_button()
	_setup_tip_icon()


func _maybe_show_server_setup_notice() -> void:
	if SettingsManager:
		if not SettingsManager.has_method("get_seen_server_setup_notice"):
			return
		if SettingsManager.get_seen_server_setup_notice():
			return
	else:
		return
	_show_server_setup_notice()


func _show_server_setup_notice() -> void:
	var action := await _Overlay.notify_with_actions(
		_notice_overlay,
		tr("MAIN_WELCOME_TITLE"),
		tr("MAIN_SERVER_SETUP_TEXT"),
		tr("MAIN_BTN_GOT_IT"),
		tr("MAIN_NOTICE_OPEN_HELP"),
	)
	_mark_server_setup_notice_seen()
	if action == "secondary":
		_on_help_pressed()


func debug_show_welcome_notice() -> void:
	_show_server_setup_notice()


func _mark_server_setup_notice_seen() -> void:
	if SettingsManager and SettingsManager.has_method("set_seen_server_setup_notice"):
		SettingsManager.set_seen_server_setup_notice(true)


func _maybe_check_updates_on_startup() -> void:
	if UpdateChecker == null or UpdateChecker.is_busy():
		return
	if not bool(SettingsManager.get_setting("check_updates_on_startup", true)):
		return
	UpdateChecker.check_for_updates(true)


func _on_update_check_completed(result: Dictionary) -> void:
	if not result.get("silent", false):
		return
	if not result.get("ok", false):
		return
	if result.get("up_to_date", false):
		return
	var latest := str(result.get("latest", ""))
	if UpdateChecker.should_skip_startup_notice(latest):
		return
	_show_update_available_dialog(result)


func _show_update_available_dialog(result: Dictionary) -> void:
	_pending_update_result = result
	var accepted := await _Overlay.ask(
		_confirm_overlay,
		tr("UPDATE_AVAILABLE_TEXT") % [
			str(result.get("latest", "")),
			str(result.get("current", AppVersion.get_display_version())),
		],
		"info",
		tr("UPDATE_AVAILABLE_TITLE"),
		tr("UPDATE_BTN_OPEN"),
		tr("UPDATE_BTN_LATER"),
	)
	if accepted:
		_on_update_available_confirmed()
	else:
		_on_update_available_canceled()


func _on_update_available_confirmed() -> void:
	OS.shell_open(str(_pending_update_result.get("latest_url", AppVersion.get_releases_url())))
	_pending_update_result = {}


func _on_update_available_canceled() -> void:
	UpdateChecker.remember_dismissed_version(str(_pending_update_result.get("latest", "")))
	_pending_update_result = {}


func _apply_menu_ui_interactions() -> void:
	UiInteractionApplier.apply_from_engine(self)
	if _github_button:
		_github_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _setup_help_button() -> void:
	if _help_button == null:
		return
	var help_color := _ICON_HELP_FALLBACK
	var game_engine := get_tree().root.get_node_or_null("GameEngine")
	if game_engine != null and game_engine.theme != null:
		var app_theme: Theme = game_engine.theme
		help_color = app_theme.get_color("accent_slate", "Palette")
		_apply_help_button_theme(app_theme)
	UiIconHelper.configure_button_icon(_help_button, "circle-question-mark.svg", help_color, 22)
	_help_button.text = ""
	_help_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_help_button.custom_minimum_size = Vector2(44, 44)
	_help_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_help_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_help_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_help_button_locale()


func _apply_help_button_theme(app_theme: Theme) -> void:
	if _help_button == null or app_theme == null:
		return
	var type_name := &"FlatMenuHelpButton"
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var stylebox := app_theme.get_stylebox(state, type_name)
		if stylebox is StyleBoxFlat:
			var shell := (stylebox as StyleBoxFlat).duplicate()
			shell.border_width_left = 2
			shell.border_width_top = 2
			shell.border_width_right = 2
			shell.border_width_bottom = 2
			shell.content_margin_left = 16
			shell.content_margin_right = 12
			shell.content_margin_top = 10
			shell.content_margin_bottom = 10
			_help_button.add_theme_stylebox_override(state, shell)


func _apply_help_button_locale() -> void:
	if _help_button:
		_help_button.tooltip_text = tr("MAIN_OPEN_HELP")


func _setup_menu_icons() -> void:
	var nav_buttons: Array[Dictionary] = [
		{"button": _song_select_button, "icon": "circle-play.svg", "tint": _ICON_PLAY},
		{"button": _achievements_button, "icon": "trophy.svg", "tint": _ICON_ACHIEVEMENTS},
		{"button": _profile_button, "icon": "fingerprint-pattern.svg", "tint": _ICON_PROFILE},
		{"button": _shop_button, "icon": "diamond.svg", "tint": _ICON_SHOP},
		{"button": _settings_button, "icon": "settings.svg", "tint": _ICON_SETTINGS},
		{"button": _exit_button, "icon": "log-out.svg", "tint": _ICON_EXIT},
	]
	for entry in nav_buttons:
		var button: Button = entry.get("button")
		if button == null:
			continue
		UiIconHelper.configure_button_icon(
			button,
			str(entry.get("icon", "")),
			entry.get("tint", UiIconHelper.ACCENT),
			_MENU_ICON_SIZE,
		)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if _play_again_button:
		UiIconHelper.configure_button_icon(_play_again_button, "circle-play.svg", _ICON_PLAY, _MENU_ICON_SIZE)


func _setup_tip_icon() -> void:
	if _tip_icon == null:
		return
	_tip_icon.texture = UiIconHelper.load_tinted_icon("star.svg", _ICON_TIP_STAR)


func set_transitions(transitions_instance):
	transitions = transitions_instance

func _on_github_pressed():
	OS.shell_open(github_url)

func _on_song_select_pressed():
	MusicManager.play_select_sound()
	if transitions:
		transitions.open_play_modes()

func _on_play_again_pressed() -> void:
	var session := _get_latest_session()
	if session.is_empty():
		_on_song_select_pressed()
		return
	var song_path := _resolve_song_path_for_session(session)
	if song_path == "":
		_on_song_select_pressed()
		return
	var song_data := _build_replay_song_data(session, song_path)
	if song_data.is_empty():
		_on_song_select_pressed()
		return
	MusicManager.play_select_sound()
	MusicManager.pause_menu_music()
	if transitions == null:
		return
	var instrument := _instrument_key_from_session(session)
	var results_mgr := _get_results_history_service()
	transitions.open_game_with_song(song_data, instrument, results_mgr, "basic", 4, [])

func _on_achievements_pressed():
	MusicManager.play_select_sound()
	if transitions:
		transitions.open_achievements()

func _on_shop_pressed():
	MusicManager.play_select_sound()
	if transitions:
		transitions.open_shop()

func _on_profile_pressed(): 
	MusicManager.play_select_sound()
	if transitions:
		transitions.open_profile()

func _on_help_pressed():
	MusicManager.play_select_sound()
	if transitions:
		transitions.open_help()

func _on_settings_pressed():
	MusicManager.play_select_sound()
	if transitions:
		transitions.open_settings()


func _unhandled_input(event: InputEvent) -> void:
	if _confirm_overlay and _confirm_overlay.visible:
		return
	if _notice_overlay and _notice_overlay.visible:
		return
	if UiScreenHotkeys.try_handle(_main_menu_hotkey_bindings(), event, get_viewport()):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_show_exit_dialog()
		get_viewport().set_input_as_handled()


func _main_menu_hotkey_bindings() -> Dictionary:
	return {
		KEY_1: _hotkey_press_main_menu_button.bind(0),
		KEY_2: _hotkey_press_main_menu_button.bind(1),
		KEY_3: _hotkey_press_main_menu_button.bind(2),
		KEY_4: _hotkey_press_main_menu_button.bind(3),
		KEY_5: _hotkey_press_main_menu_button.bind(4),
		KEY_6: _hotkey_press_main_menu_button.bind(5),
		KEY_F1: _on_help_pressed,
	}


func _hotkey_press_main_menu_button(index: int) -> void:
	var buttons: Array[Button] = [
		_song_select_button,
		_achievements_button,
		_profile_button,
		_shop_button,
		_settings_button,
		_exit_button,
	]
	if index < 0 or index >= buttons.size():
		return
	UiScreenHotkeys.press_button(buttons[index])


func _on_exit_pressed():
	_show_exit_dialog()


func exit_to_main_menu():
	MusicManager.play_menu_music()
	if transitions:
		transitions.exit_to_main_menu()
	queue_refresh_on_show()

func refresh_shop_badge() -> void:
	_update_shop_badge()

func refresh_daily_quests() -> void:
	PlayerDataManager.sync_calendar_day_if_needed()
	_render_daily_quests()
	_update_daily_reset_label()

func _on_calendar_day_changed(_new_date: String) -> void:
	_render_daily_quests()
	_render_tip_of_day()
	_update_daily_reset_label()

func _on_daily_reset_timer_timeout() -> void:
	_update_daily_reset_label()

func _update_shop_badge() -> void:
	if not is_instance_valid(_shop_badge) or not is_instance_valid(_shop_badge_label):
		return
	var count := PlayerDataManager.get_unseen_shop_reward_count()
	if count <= 0:
		_shop_badge.visible = false
		_UiMotionEffects.stop_menu_badge_pulse(_shop_badge)
		return
	_shop_badge.visible = true
	_shop_badge_label.text = "99+" if count > 99 else str(count)
	call_deferred("_pulse_shop_badge")


func _pulse_shop_badge() -> void:
	if is_instance_valid(_shop_badge) and _shop_badge.visible:
		_UiMotionEffects.pulse_menu_badge(_shop_badge)

func _render_daily_quests():
	var quests = PlayerDataManager.get_daily_quests()
	for i in range(3):
		var item_name = "QuestItem%d" % (i + 1)
		var item = find_child(item_name, true, false)
		if not item:
			continue
		if item is Control:
			item.clip_contents = true

		var title_label = item.find_child("QuestTitleLabel", true, false)
		var desc_label = item.find_child("QuestDescriptionLabel", true, false)
		var pb = item.find_child("QuestProgressBar", true, false)
		var quest_icon := item.find_child("QuestIcon", true, false) as TextureRect

		if i < quests.size():
			var q = quests[i]
			var title = _DailyQuestLocale.localized_title(q)
			var goal = int(q.get("goal", 1))
			var reward = int(q.get("reward_currency", 0))
			var progress = int(q.get("progress", 0))
			var completed = bool(q.get("completed", false))

			if quest_icon:
				var tint := _QUEST_ICON_COLORS[i] if i < _QUEST_ICON_COLORS.size() else _QUEST_ICON_COLORS[0]
				quest_icon.texture = _UiIconHelper.load_tinted_icon(_QUEST_ICON_FILE, tint)
				quest_icon.visible = true

			if item is PanelContainer:
				_apply_quest_item_style(item, completed)
				_UiMotionEffects.stop_panel_border_pulse(item)
				if not completed and goal > 0 and progress >= goal - 1 and progress < goal:
					_UiMotionEffects.pulse_panel_border(
						item,
						Color(0.95, 0.78, 0.35),
						0.42,
						0.88,
						0.85
					)

			if title_label:
				title_label.text = title
				if completed:
					title_label.add_theme_color_override("font_color", Color(0.95, 0.70, 0.30, 1.0))
				else:
					title_label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.96))

			if desc_label:
				var desc_text = tr("DAILY_QUEST_META") % [reward, goal]
				if completed:
					desc_text += " " + tr("DAILY_QUEST_DONE")
				else:
					desc_text += tr("DAILY_QUEST_PROGRESS") % [progress, goal]
				desc_label.text = desc_text
				if completed:
					desc_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
				else:
					desc_label.add_theme_color_override("font_color", Color(0.72, 0.78, 0.88))

			if pb:
				pb.max_value = goal
				pb.value = min(progress, goal)
				_apply_quest_progress_style(pb, completed)

			item.show() 
		else:
			if item is PanelContainer:
				_UiMotionEffects.stop_panel_border_pulse(item)
			item.hide()
	_update_daily_reset_label()

func _apply_quest_item_style(item: PanelContainer, completed: bool) -> void:
	var shell := StyleBoxFlat.new()
	if completed:
		shell.bg_color = Color(0.13, 0.14, 0.18)
		shell.border_color = Color(0.95, 0.78, 0.35, 0.55)
	else:
		shell.bg_color = Color(0.11, 0.12, 0.16)
		shell.border_color = Color(0.62, 0.86, 0.72, 0.45)
	shell.border_width_top = 2
	shell.border_width_left = 1
	shell.border_width_right = 1
	shell.border_width_bottom = 1
	shell.set_corner_radius_all(10)
	item.add_theme_stylebox_override("panel", shell)

func _apply_quest_progress_style(pb: ProgressBar, completed: bool) -> void:
	if completed:
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.95, 0.78, 0.35)
		fill.set_corner_radius_all(5)
		pb.add_theme_stylebox_override("fill", fill)
	else:
		pb.remove_theme_stylebox_override("fill")

func _render_hub_panels() -> void:
	_render_stats_panel()
	_render_last_track_panel()
	call_deferred("_render_hub_phase_activity")


func _render_hub_phase_activity() -> void:
	if not is_visible_in_tree():
		return
	_render_activity_feed()
	call_deferred("_render_hub_phase_achievement")


func _render_hub_phase_achievement() -> void:
	if not is_visible_in_tree():
		return
	_render_nearest_achievement_panel()
	_render_tip_of_day()
	_update_daily_reset_label()


func _render_hub_panels_deferred() -> void:
	_render_hub_phase_activity()

func _render_stats_panel() -> void:
	if _stat_tracks_value:
		_stat_tracks_value.text = _format_int_grouped(PlayerDataManager.get_levels_completed())
	if _stat_perfect_value:
		_stat_perfect_value.text = _format_int_grouped(PlayerDataManager.get_total_perfect_hits())
	if _stat_combo_value:
		_stat_combo_value.text = _format_int_grouped(int(PlayerDataManager.data.get("max_combo_ever", 0)))
	if _stat_accuracy_value:
		_stat_accuracy_value.text = "%.2f%%" % _compute_overall_accuracy()

func _render_last_track_panel() -> void:
	var session := _get_latest_session()
	var song_path := _resolve_song_path_for_session(session)
	var has_session := not session.is_empty()
	var title_text := tr("MAIN_LAST_TRACK_EMPTY")
	var artist_text := ""
	var accuracy_text := ""
	var grade_text := ""
	var difficulty_text := ""

	if has_session:
		var labels := _resolve_last_track_labels(session, song_path)
		var display_path := str(labels.get("path", song_path)).strip_edges()
		if display_path != "":
			song_path = display_path
		title_text = str(labels.get("title", "")).strip_edges()
		artist_text = str(labels.get("artist", "")).strip_edges()
		var accuracy := float(session.get("accuracy", 0.0))
		accuracy_text = "%.2f%%" % accuracy
		grade_text = str(session.get("grade", ""))
		difficulty_text = _resolve_last_track_difficulty_label(song_path, session)
		var grade_color_data = session.get("grade_color", {})
		if grade_text != "" and _last_track_grade and grade_color_data is Dictionary:
			_last_track_grade.add_theme_color_override(
				"font_color",
				Color(
					float(grade_color_data.get("r", 0.95)),
					float(grade_color_data.get("g", 0.82)),
					float(grade_color_data.get("b", 0.35)),
					float(grade_color_data.get("a", 1.0)),
				)
			)

	var title_label := _last_track_title_label()
	var artist_label := _last_track_artist_label()
	if title_label:
		title_label.text = title_text
		title_label.visible = has_session
		title_label.modulate = Color.WHITE
	if artist_label:
		artist_label.text = artist_text
		artist_label.visible = has_session
		artist_label.modulate = Color.WHITE
	if _last_track_difficulty:
		_last_track_difficulty.text = difficulty_text
		_last_track_difficulty.visible = difficulty_text != ""
	if _last_track_accuracy:
		_last_track_accuracy.text = accuracy_text
		_last_track_accuracy.visible = accuracy_text != ""
	if _last_track_grade:
		_last_track_grade.text = grade_text
		_last_track_grade.visible = grade_text != ""
	if _play_again_button:
		_play_again_button.visible = has_session
	if _last_track_cover:
		_last_track_cover.visible = has_session
		if has_session and song_path != "":
			if song_path != _last_track_cover_path:
				_last_track_cover_path = song_path
				_last_track_cover.texture = null
				call_deferred("_apply_last_track_cover", song_path)
		elif has_session:
			if _last_track_cover_path != "":
				_last_track_cover_path = ""
				_last_track_cover.texture = null
		else:
			_last_track_cover_path = ""
			_last_track_cover.texture = null
	if _last_track_panel:
		_UiMotionEffects.stop_panel_border_pulse(_last_track_panel)
		if has_session:
			_UiMotionEffects.pulse_panel_border(
				_last_track_panel,
				Color(0.95, 0.72, 0.28),
				0.38,
				0.78,
				0.95
			)

func _resolve_last_track_cover(song_path: String) -> Texture2D:
	return _RhythmDnaCoverLoader.load_cover_for_display(song_path, _LAST_TRACK_COVER_PX)


func _apply_last_track_cover(song_path: String) -> void:
	if not is_visible_in_tree() or _last_track_cover == null:
		return
	if song_path != _last_track_cover_path:
		return
	_last_track_cover.texture = _resolve_last_track_cover(song_path)


func _render_activity_feed() -> void:
	if _activity_list_vbox == null:
		return
	for child in _activity_list_vbox.get_children():
		_activity_list_vbox.remove_child(child)
		child.free()
	var achievements: Array = []
	var mgr := _get_achievement_manager()
	if mgr:
		achievements = mgr.achievements
	var history: Array = []
	var history_svc := _get_results_history_service()
	if history_svc:
		history = history_svc.get_history()
	var resolve_labels := Callable(self, "_activity_feed_track_labels")
	var daily_meta: Dictionary = PlayerDataManager.data.get("daily_quests", {})
	var daily_date := str(daily_meta.get("date", ""))
	var quests: Array = PlayerDataManager.get_daily_quests()
	var last_daily: Dictionary = PlayerDataManager.data.get("last_daily_quest_completion", {})
	var entries: Array = _MainMenuActivityFeed.collect_entries(
		history,
		quests,
		achievements,
		resolve_labels,
		daily_date,
		last_daily if last_daily is Dictionary else {}
	)
	var has_entries := not entries.is_empty()
	if _activity_empty_label:
		_activity_empty_label.visible = not has_entries
	if not has_entries:
		return
	for entry in entries:
		if not entry is Dictionary:
			continue
		_activity_list_vbox.add_child(_build_activity_row(entry))
	if is_inside_tree():
		_activity_list_vbox.queue_sort()


func _format_activity_entry_text(entry: Dictionary) -> String:
	match str(entry.get("kind", "")):
		"session":
			return tr("MAIN_ACTIVITY_SESSION") % [
				str(entry.get("artist", "—")),
				str(entry.get("title", "—")),
				str(entry.get("grade", "—")),
			]
		"daily":
			return tr("MAIN_ACTIVITY_DAILY") % str(entry.get("quest_title", ""))
		"achievement":
			var ach: Dictionary = entry.get("achievement", {})
			return tr("MAIN_ACTIVITY_ACHIEVEMENT") % _MainMenuNearestAchievement.title_for(ach)
		"generation":
			return _MainMenuActivityFeed.format_entry_text(entry)
		"record":
			return _MainMenuActivityFeed.format_entry_text(entry)
	return ""


func _format_activity_entry_time(entry: Dictionary) -> String:
	return _MainMenuActivityFeed.format_entry_time(entry)


func _activity_feed_track_labels(session: Dictionary) -> Dictionary:
	var song_path := _resolve_song_path_for_session(session)
	return _resolve_last_track_labels(session, song_path)


func _activity_feed_track_title(session: Dictionary) -> String:
	var labels := _activity_feed_track_labels(session)
	return str(labels.get("title", "")).strip_edges()


func _build_activity_row(entry: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size = Vector2(0, 26)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(20, 20)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_file := str(entry.get("icon_file", "activity.svg"))
	var icon_color: Color = entry.get("icon_color", Color(0.72, 0.86, 1.0))
	icon.texture = _UiIconHelper.load_tinted_icon(icon_file, icon_color)
	row.add_child(icon)

	var text_label := Label.new()
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.size_flags_stretch_ratio = 1.0
	text_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_label.text = _format_activity_entry_text(entry)
	text_label.theme = theme
	text_label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.96))
	text_label.add_theme_font_size_override("font_size", 15)
	text_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	text_label.clip_text = false
	text_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(text_label)

	var time_label := Label.new()
	time_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	time_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	time_label.custom_minimum_size.x = 118
	time_label.text = _format_activity_entry_time(entry)
	time_label.theme = theme
	time_label.add_theme_color_override("font_color", Color(0.58, 0.64, 0.74))
	time_label.add_theme_font_size_override("font_size", 13)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(time_label)

	return row

func _render_tip_of_day() -> void:
	if _tip_body_label:
		var tip_key := _MainMenuTipOfDay.tip_key_for_today()
		_tip_body_label.text = tr(tip_key) if tip_key != "" else ""

func _update_daily_reset_label() -> void:
	if _daily_reset_label == null:
		return
	_daily_reset_label.text = tr("MAIN_DAILY_RESET") % _format_time_until_midnight()

func _get_latest_session() -> Dictionary:
	var svc := _get_results_history_service()
	if svc == null:
		return {}
	var history := svc.get_history()
	if history.is_empty():
		return {}
	return history[0]

func _resolve_song_path_for_session(session: Dictionary) -> String:
	if session.is_empty():
		return ""
	var path := _normalize_track_path(str(session.get("song_path", "")))
	if path != "":
		var library_path := _find_library_song_path(path)
		if library_path != "":
			return library_path
		if FileAccess.file_exists(path) or FileAccess.file_exists(_readable_track_path(path)):
			return path
	var title := _clean_track_label(str(session.get("title", "")))
	var artist := _clean_track_label(str(session.get("artist", "")))
	if title == "":
		return ""
	return _find_library_song_path_by_labels(title, artist)


func _normalize_track_path(path: String) -> String:
	return String(path).replace("\\", "/").strip_edges()


func _readable_track_path(path: String) -> String:
	var normalized := _normalize_track_path(path)
	if normalized == "":
		return ""
	if normalized.begins_with("res://") or normalized.begins_with("user://"):
		return ProjectSettings.globalize_path(normalized)
	return normalized


func _find_library_song_path(path: String) -> String:
	if path == "" or SongLibrary == null:
		return ""
	var normalized := _normalize_track_path(path)
	var readable := _readable_track_path(normalized)
	for song in SongLibrary.get_songs_list():
		if typeof(song) != TYPE_DICTIONARY:
			continue
		var candidate := _normalize_track_path(str(song.get("path", "")))
		if candidate == "":
			continue
		if candidate == normalized:
			return candidate
		if candidate.get_file().to_lower() == normalized.get_file().to_lower():
			return candidate
		if readable != "" and _readable_track_path(candidate) == readable:
			return candidate
	return ""


func _find_library_song_path_by_labels(title: String, artist: String) -> String:
	if title == "" or SongLibrary == null:
		return ""
	for song in SongLibrary.get_songs_list():
		if typeof(song) != TYPE_DICTIONARY:
			continue
		var song_path := _normalize_track_path(str(song.get("path", "")))
		if song_path == "":
			continue
		var meta := SongLibrary.get_metadata_for_song(song_path)
		var song_title := _clean_track_label(str(meta.get("title", song.get("title", ""))))
		var song_artist := _clean_track_label(str(meta.get("artist", song.get("artist", ""))))
		if song_title != title:
			continue
		if artist != "" and song_artist != "" and song_artist != artist:
			continue
		return song_path
	return ""


func _last_track_title_label() -> Label:
	if _last_track_title:
		return _last_track_title
	return get_node_or_null(
		"RootMargin/RootHBox/RightHub/MiddleRow/LastTrackPanel/LastTrackMargin/LastTrackVBox/LastTrackBody/LastTrackMetaVBox/LastTrackTitle"
	) as Label


func _last_track_artist_label() -> Label:
	if _last_track_artist:
		return _last_track_artist
	return get_node_or_null(
		"RootMargin/RootHBox/RightHub/MiddleRow/LastTrackPanel/LastTrackMargin/LastTrackVBox/LastTrackBody/LastTrackMetaVBox/LastTrackArtist"
	) as Label


func _resolve_last_track_labels(session: Dictionary, song_path: String) -> Dictionary:
	var resolved_path := song_path
	if resolved_path == "":
		resolved_path = _resolve_song_path_for_session(session)
	var title := _clean_track_label(str(session.get("title", "")))
	var artist := _clean_track_label(str(session.get("artist", "")))
	if resolved_path != "":
		if SongLibrary:
			var meta := _lookup_song_metadata(resolved_path)
			if not meta.is_empty():
				var meta_title := _clean_track_label(str(meta.get("title", "")))
				var meta_artist := _clean_track_label(str(meta.get("artist", "")))
				if meta_title != "":
					title = meta_title
				if meta_artist != "":
					artist = meta_artist
		if title == "" or artist == "":
			var tags := _RhythmDnaCoverLoader.load_track_labels(resolved_path)
			if title == "":
				title = _clean_track_label(str(tags.get("title", "")))
			if artist == "":
				artist = _clean_track_label(str(tags.get("artist", "")))
		if title == "" or artist == "":
			var parsed := _labels_from_filename(resolved_path)
			if title == "":
				title = _clean_track_label(str(parsed.get("title", "")))
			if artist == "":
				artist = _clean_track_label(str(parsed.get("artist", "")))
	if resolved_path == "" and title != "":
		resolved_path = _find_library_song_path_by_labels(title, artist)
		if resolved_path != "":
			if artist == "":
				var tags := _RhythmDnaCoverLoader.load_track_labels(resolved_path)
				artist = _clean_track_label(str(tags.get("artist", "")))
			if artist == "" and SongLibrary:
				var meta := _lookup_song_metadata(resolved_path)
				artist = _clean_track_label(str(meta.get("artist", "")))
	if title == "" and resolved_path != "":
		title = _clean_track_label(str(_labels_from_filename(resolved_path).get("title", "")))
	if title == "" and resolved_path != "":
		title = resolved_path.get_file().get_basename()
	var stem := resolved_path.get_file().get_basename() if resolved_path != "" else ""
	return {
		"title": _SongSelectStrings.display_track_title(title, stem),
		"artist": _SongSelectStrings.display_track_artist(artist),
		"path": resolved_path,
	}


func _labels_from_filename(song_path: String) -> Dictionary:
	var base := song_path.get_file().get_basename().strip_edges()
	if base == "":
		return {"title": "", "artist": ""}
	var sep := " - "
	if base.find(sep) != -1:
		var parts := base.split(sep, false, 1)
		if parts.size() >= 2:
			return {
				"artist": parts[0].strip_edges(),
				"title": parts[1].strip_edges(),
			}
	return {"title": base, "artist": ""}


func _build_replay_song_data(session: Dictionary, song_path: String) -> Dictionary:
	var labels := _resolve_last_track_labels(session, song_path)
	var resolved_path := str(labels.get("path", song_path)).strip_edges()
	if resolved_path == "":
		resolved_path = song_path
	var data := {
		"path": resolved_path,
		"title": str(labels.get("title", "")),
		"artist": str(labels.get("artist", "")),
	}
	if SongLibrary:
		var display := SongLibrary.get_display_metadata_for_song(resolved_path)
		if display is Dictionary and not display.is_empty():
			data = display.duplicate(true)
			data["path"] = resolved_path
			var resolved_title := str(labels.get("title", ""))
			var resolved_artist := str(labels.get("artist", ""))
			if resolved_title != "" and resolved_title != tr("VALUE_NA"):
				data["title"] = resolved_title
			if resolved_artist != "":
				data["artist"] = resolved_artist
	return data


func _instrument_key_from_session(session: Dictionary) -> String:
	var instrument := str(session.get("instrument", ""))
	if instrument.find("еркусс") != -1 or instrument.to_lower().find("drum") != -1:
		return "drums"
	return "standard"


func _get_results_history_service() -> ResultsHistoryService:
	var game_engine := get_tree().root.get_node_or_null("GameEngine")
	if game_engine != null and game_engine.has_method("get_results_history_service"):
		return game_engine.get_results_history_service()
	return _results_history_service


func _ensure_nearest_ach_card() -> void:
	if _nearest_ach_card != null or _nearest_ach_card_slot == null:
		return
	_nearest_ach_card = _AchievementCardScene.instantiate() as PanelContainer
	if _nearest_ach_card == null:
		return
	_reset_embedded_achievement_card_layout(_nearest_ach_card)
	_nearest_ach_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nearest_ach_card_slot.add_child(_nearest_ach_card)


func _reset_embedded_achievement_card_layout(card: Control) -> void:
	card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	card.anchor_right = 0.0
	card.anchor_bottom = 0.0
	card.offset_left = 0
	card.offset_top = 0
	card.offset_right = 0
	card.offset_bottom = 0
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func _render_nearest_achievement_panel() -> void:
	_ensure_nearest_ach_card()
	var mgr := _get_achievement_manager()
	var picked: Dictionary = {}
	if mgr:
		picked = _MainMenuNearestAchievement.pick_nearest(mgr.achievements)
	var has_nearest := not picked.is_empty()
	if _nearest_ach_header_label:
		_nearest_ach_header_label.visible = true
	if _nearest_ach_empty_label:
		_nearest_ach_empty_label.visible = not has_nearest
	if _nearest_ach_card_slot:
		_nearest_ach_card_slot.visible = has_nearest
	if not has_nearest:
		if _nearest_ach_card:
			_nearest_ach_card.visible = false
		return
	var ach: Dictionary = picked.get("achievement", {})
	var ach_id := str(ach.get("id", ""))
	if ach_id != "" and ach_id == _nearest_ach_id and _nearest_ach_card and _nearest_ach_card.visible:
		return
	_nearest_ach_id = ach_id
	if _nearest_ach_card:
		_nearest_ach_card.visible = true
		if _nearest_ach_card.has_method("apply_achievement"):
			_nearest_ach_card.apply_achievement(ach, mgr)
		elif _nearest_ach_card.has_method("apply_locale"):
			_nearest_ach_card.apply_locale()


func _get_achievement_manager() -> AchievementManager:
	var game_engine := get_tree().root.get_node_or_null("GameEngine")
	if game_engine != null and game_engine.has_method("get_achievement_manager"):
		return game_engine.get_achievement_manager()
	return null


func _lookup_song_metadata(song_path: String) -> Dictionary:
	if SongLibrary == null or song_path == "":
		return {}
	var normalized := _normalize_track_path(song_path)
	var meta := SongLibrary.get_metadata_for_song(normalized)
	if meta is Dictionary and not meta.is_empty():
		return meta
	var library_path := _find_library_song_path(normalized)
	if library_path != "":
		meta = SongLibrary.get_metadata_for_song(library_path)
		if meta is Dictionary and not meta.is_empty():
			return meta
	for song in SongLibrary.get_songs_list():
		if typeof(song) != TYPE_DICTIONARY:
			continue
		var candidate := _normalize_track_path(str(song.get("path", "")))
		if candidate == normalized or candidate.get_file().to_lower() == normalized.get_file().to_lower():
			if song.has("title") or song.has("artist"):
				return song
			break
	return {}


func _clean_track_label(value: String) -> String:
	var text := value.strip_edges()
	if text == "":
		return ""
	if text == "N/A" or text == tr("VALUE_NA") or text == tr("VALUE_NO_TITLE") or text == tr("VALUE_UNKNOWN_ARTIST"):
		return ""
	if text in ["Без названия", "Неизвестен", "Unknown", "No title"]:
		return ""
	return text

func _resolve_last_track_difficulty_label(song_path: String, session: Dictionary) -> String:
	if song_path == "" or SongLibrary == null:
		return ""
	var instrument := str(session.get("instrument", ""))
	var inst_key := "drums"
	if instrument.find("еркусс") != -1 or instrument.to_lower().find("drum") != -1:
		inst_key = "drums"
	var modes_to_try: Array[String] = []
	var session_mode := str(session.get("generation_mode", session.get("mode", ""))).strip_edges().to_lower()
	if session_mode != "":
		modes_to_try.append(session_mode)
	for mode in ["basic", "enhanced", "minimal", "natural", "custom"]:
		if mode not in modes_to_try:
			modes_to_try.append(mode)
	for mode in modes_to_try:
		var variant := SongLibrary.get_chart_difficulty_variant(song_path, inst_key, mode)
		if variant.is_empty():
			continue
		var decimal := ChartDifficultyAnalyzer.decimal_rating_from_stats(variant)
		if decimal <= 0.0:
			continue
		return ChartDifficultyAnalyzer.format_decimal_rating(decimal, true)
	return ""

func _compute_overall_accuracy() -> float:
	var total_notes_hit = PlayerDataManager.get_total_notes_hit()
	var total_notes_missed = PlayerDataManager.get_total_notes_missed()
	var total_notes_played = total_notes_hit + total_notes_missed
	if total_notes_played > 0:
		return (float(total_notes_hit) / float(total_notes_played)) * 100.0
	if _results_history_service:
		var hist := _get_results_history_service().get_history()
		if hist.size() > 0:
			var sum_acc := 0.0
			for item in hist:
				sum_acc += float(item.get("accuracy", 0.0))
			return sum_acc / float(hist.size())
	return 0.0

func _format_time_until_midnight() -> String:
	var now := Time.get_datetime_dict_from_system()
	var seconds_left := (24 * 3600) - (
		int(now.get("hour", 0)) * 3600
		+ int(now.get("minute", 0)) * 60
		+ int(now.get("second", 0))
	)
	seconds_left = max(0, seconds_left)
	var hours := int(seconds_left / 3600)
	var minutes := int((seconds_left % 3600) / 60)
	var seconds := seconds_left % 60
	return "%02d:%02d:%02d" % [hours, minutes, seconds]

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

func _show_exit_dialog() -> void:
	if MusicManager and MusicManager.has_method("play_cancel_sound"):
		MusicManager.play_cancel_sound()
	_request_exit()


func _request_exit() -> void:
	var game_engine := get_tree().root.get_node_or_null("GameEngine")
	if game_engine and game_engine.has_method("request_application_exit"):
		await game_engine.request_application_exit()
		return
	if await _Overlay.ask(
		_confirm_overlay,
		tr("MAIN_EXIT_TEXT"),
		"warning",
		tr("MAIN_EXIT_TITLE"),
		tr("BTN_OK"),
		tr("BTN_CANCEL"),
	):
		_on_exit_confirmed()

func _on_exit_confirmed():
	if transitions:
		MusicManager.stop_music()
		transitions.exit_game()
