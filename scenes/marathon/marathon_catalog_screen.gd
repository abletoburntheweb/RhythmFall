# scenes/marathon/marathon_catalog_screen.gd
extends BaseScreen

const _PlayModeIds = preload("res://logic/domain/session/play_mode_ids.gd")
const _MarathonRouteBuilder = preload("res://logic/domain/session/marathon_route_builder.gd")
const _MarathonRouteCatalog = preload("res://logic/domain/session/marathon_route_catalog.gd")
const _MarathonRunRules = preload("res://logic/domain/session/marathon_run_rules.gd")
const _MarathonRouteBadges = preload("res://logic/domain/session/marathon_route_badges.gd")
const _MarathonSessionConfig = preload("res://logic/domain/session/marathon_session_config.gd")
const _ProfileGenrePortrait = preload("res://logic/domain/profile/profile_genre_portrait.gd")
const _GenreGroupIcons = preload("res://logic/domain/library/genre_group_icons.gd")
const _EndlessSessionConfig = preload("res://logic/domain/session/endless_session_config.gd")
const _RhythmDnaCoverLoader = preload("res://scenes/song_select/rhythm_dna/lib/rhythm_dna_cover_loader.gd")
const _MarathonCourseSettings = preload("res://scenes/marathon/marathon_course_settings.gd")
const _NoticeOverlayScene = preload("res://ui/overlays/app_notice_overlay.tscn")
const _SongSelectUiStyles = preload("res://scenes/song_select/lib/song_select_ui_styles.gd")
const _ChartDifficultyAnalyzer = preload("res://logic/domain/charts/chart_difficulty_analyzer.gd")
const _PreviewRowScript = preload("res://scenes/song_select/endless/session_setup_preview_row.gd")
const _MarathonSummaryBadgesPanel = preload("res://scenes/marathon/marathon_summary_badges_panel.gd")
const _MarathonSummaryRulesPanel = preload("res://scenes/marathon/marathon_summary_rules_panel.gd")
const _MarathonSummaryModsPanel = preload("res://scenes/marathon/marathon_summary_mods_panel.gd")
const _MarathonSummaryRewardsPanel = preload("res://scenes/marathon/marathon_summary_rewards_panel.gd")
const _MarathonRoutePreviewPanel = preload("res://scenes/marathon/marathon_route_preview_panel.gd")
const _SongDetailsManagerScript = preload("res://scenes/song_select/controllers/song_details_manager.gd")
const _MarathonRouteProgressPanel = preload("res://scenes/marathon/marathon_route_progress_panel.gd")
const _MarathonRouteCharacter = preload("res://logic/domain/session/marathon_route_character.gd")
const _MarathonSeason = preload("res://logic/domain/session/marathon_season.gd")
const _TimeUtils = preload("res://logic/platform/time_utils.gd")
const _SettingsSectionUi = preload("res://logic/ui/settings_section_ui.gd")
const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")

var _accent: Color = _PlayModeIds.accent_for(_PlayModeIds.MARATHON)

const _MarathonDailyRoute = preload("res://logic/domain/session/marathon_daily_route.gd")
const _MarathonRouteLength = preload("res://logic/domain/session/marathon_route_length.gd")
const _MarathonRouteRolls = preload("res://logic/domain/session/marathon_route_rolls.gd")
const GenerationService = preload("res://logic/services/generation_service.gd")
const _ConfirmOverlayScene = preload("res://ui/overlays/app_confirm_overlay.tscn")
const _Overlay = preload("res://logic/ui/app_overlay_helpers.gd")
const _SessionScopeResolver = preload("res://logic/domain/session/session_scope_resolver.gd")

var _courses: Array[Dictionary] = []
var _selected_route_id := ""
var _run_config: Dictionary = {}
var _course_settings: MarathonCourseSettings = null
var _list_item_nodes: Dictionary = {}
var _notice_overlay: AppNoticeOverlay = null
var _summary_rows: Dictionary = {}
var _rules_panel: MarathonSummaryRulesPanel = null
var _rewards_panel: MarathonSummaryRewardsPanel = null
var _mods_panel: MarathonSummaryModsPanel = null
var _badges_panel: MarathonSummaryBadgesPanel = null
var _preview_panel: MarathonRoutePreviewPanel = null
var _progress_panel: MarathonRouteProgressPanel = null
var _preview_cache: Dictionary = {}
var _candidate_cache: Dictionary = {}
var _cached_route: Dictionary = {}
var _cached_route_id: String = ""
var _cached_template: Dictionary = {}
var _cached_template_id: String = ""
var _cold_token: int = 0
var _cold_start_usec: int = 0
var _season_reset_label: Label = null
var _next_set_toggle: Button = null
var _next_set_vbox: VBoxContainer = null
var _next_set_scroll: ScrollContainer = null
var _next_set_visible := false
var _season_timer: Timer = null
var _route_preview_player: SongDetailsManager = null
var _library_refresh_timer: Timer = null
var _refresh_pool_button: Button = null
var _generate_missing_button: Button = null
var _confirm_overlay: AppConfirmOverlay = null
var _generation_service: GenerationService = null
var _preview_audio_song_path := ""
var _settings_refresh_timer: Timer = null
var _pending_settings_rebuild_list := false
var _pending_settings_full_refresh := false
var _suppress_settings_changed := false
var _cached_selected_preview: Dictionary = {}
var _cached_selected_preview_key: String = ""
var _help_btn: Button = null
var _rebuild_token: int = 0
var _initial_build_done: bool = false
const _REBUILD_BATCH_SIZE := 4

const _POOL_AFFECTING_KEYS: Array[String] = [
	"generation_mode_policy",
	"generation_modes_allowed",
	"chart_difficulty_policy",
	"chart_difficulty_tiers_allowed",
	"difficulty_min",
	"difficulty_max",
	"instrument",
	"instruments",
]

@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _courses_title: Label = %CoursesTitle
@onready var _courses_scroll: ScrollContainer = %CoursesScroll
@onready var _courses_list_vbox: VBoxContainer = %CoursesListVBox
@onready var _playlists_placeholder: Label = %PlaylistsPlaceholder
@onready var _hero_panel: PanelContainer = %HeroPanel
@onready var _hero_cover: TextureRect = %HeroCover
@onready var _hero_title_label: Label = %HeroTitleLabel
@onready var _hero_subtitle_label: Label = %HeroSubtitleLabel
@onready var _stat_tracks_label: Label = %StatTracksLabel
@onready var _stat_duration_label: Label = %StatDurationLabel
@onready var _stat_difficulty_label: Label = %StatDifficultyLabel
var _stat_difficulty_zap: Control = null
@onready var _settings_host: VBoxContainer = %SettingsHost
@onready var _summary_title: Label = %SummaryTitle
@onready var _summary_vbox: VBoxContainer = %SummaryVBox
@onready var _start_button: Button = %StartButton
@onready var _footer_label: Label = %FooterLabel


func _ready() -> void:
	var _cold_t := Time.get_ticks_usec()
	_cold_token += 1
	_cold_start_usec = _cold_t
	var game_engine := get_parent()
	if game_engine and game_engine.has_method("get_transitions"):
		setup_managers(game_engine.get_transitions())
	_notice_overlay = _NoticeOverlayScene.instantiate() as AppNoticeOverlay
	if _notice_overlay:
		add_child(_notice_overlay)
	if _back_button and not _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.connect(_on_back_pressed)
	if _start_button and not _start_button.pressed.is_connected(_on_start_pressed):
		_start_button.pressed.connect(_on_start_pressed)
	_setup_panels()
	_setup_summary_rows()
	_setup_course_settings()
	_setup_route_preview_player()
	_setup_season_ui()
	if SongLibrary and SongLibrary.has_signal("songs_list_changed"):
		if not SongLibrary.songs_list_changed.is_connected(_on_library_changed):
			SongLibrary.songs_list_changed.connect(_on_library_changed)
	_setup_generation_refresh_hooks()
	visibility_changed.connect(_on_visibility_changed)
	_ensure_help_icon()
	call_deferred("_deferred_boot")


func _setup_route_preview_player() -> void:
	_route_preview_player = _SongDetailsManagerScript.new()
	_route_preview_player.name = "RoutePreviewPlayer"
	add_child(_route_preview_player)
	_route_preview_player.setup_audio_player()


func _deferred_boot() -> void:
	var _t := Time.get_ticks_usec()
	_sync_ambient_profile()
	var _t_rc := Time.get_ticks_usec()
	_rebuild_courses()
	_initial_build_done = true
	# Defer heavy selected-route preview to next frame — keep open frame shell-only (4 cards) for smooth animation.
	await get_tree().process_frame
	if not is_inside_tree():
		return
	if _selected_route_id == "" and not _courses.is_empty():
		var _t_sel := Time.get_ticks_usec()
		_select_route(str(_courses[0].get("route_id", "")))


func _setup_season_ui() -> void:
	if not _MarathonSeason.is_enabled():
		return
	var tab_row := get_node_or_null("%TabRow") as Control
	if tab_row:
		tab_row.visible = false
	if _playlists_placeholder:
		_playlists_placeholder.visible = false
	var left_col := _courses_title.get_parent() if _courses_title else null
	if left_col == null:
		return
	_season_reset_label = Label.new()
	_season_reset_label.add_theme_font_size_override("font_size", 12)
	_season_reset_label.add_theme_color_override("font_color", Color(0.68, 0.72, 0.82, 0.92))
	left_col.add_child(_season_reset_label)
	left_col.move_child(_season_reset_label, _courses_title.get_index())
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	left_col.remove_child(_courses_title)
	title_row.add_child(_courses_title)
	_courses_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next_set_toggle = Button.new()
	_next_set_toggle.toggle_mode = true
	_next_set_toggle.text = tr("MARATHON_ROTATION_NEXT_TOGGLE")
	_next_set_toggle.add_theme_font_size_override("font_size", 12)
	_next_set_toggle.toggled.connect(_on_next_set_toggled)
	title_row.add_child(_next_set_toggle)
	left_col.add_child(title_row)
	left_col.move_child(title_row, _season_reset_label.get_index() + 1)
	_next_set_scroll = ScrollContainer.new()
	_next_set_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next_set_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_next_set_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_next_set_scroll.visible = false
	left_col.add_child(_next_set_scroll)
	_next_set_vbox = VBoxContainer.new()
	_next_set_vbox.add_theme_constant_override("separation", 6)
	_next_set_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next_set_scroll.add_child(_next_set_vbox)
	if _courses_scroll:
		left_col.move_child(_next_set_scroll, _courses_scroll.get_index() + 1)
	_season_timer = Timer.new()
	_season_timer.wait_time = 1.0
	_season_timer.autostart = true
	_season_timer.timeout.connect(_update_season_labels)
	add_child(_season_timer)
	_update_season_labels()


func _on_next_set_toggled(on: bool) -> void:
	_next_set_visible = on
	if _courses_scroll:
		_courses_scroll.visible = not on
	_sync_courses_title()
	_rebuild_next_set_preview()


func _rebuild_next_set_preview() -> void:
	if _next_set_vbox == null:
		return
	for child in _next_set_vbox.get_children():
		child.queue_free()
	if _next_set_scroll:
		_next_set_scroll.visible = _next_set_visible
	if not _next_set_visible:
		return
	var metas := _MarathonSeason.all_route_metas(_MarathonSeason.next_season_start_iso())
	for meta in metas:
		var route_id := str(meta.get("route_id", "")).strip_edges()
		if route_id == "":
			continue
		var template: Dictionary = {}
		var raw_tmpl: Variant = meta.get("template", {})
		if raw_tmpl is Dictionary:
			template = raw_tmpl as Dictionary
		# Next-set cards are locked previews — skip heavy playable scope scan.
		var card := _make_route_list_card(route_id, false, template)
		if not template.is_empty():
			var fill := _MarathonSeason.fill_summary_line(template)
			if fill != "":
				_set_list_card_subtitle(card, fill)
		_next_set_vbox.add_child(card)




func _update_season_labels() -> void:
	if not _MarathonSeason.is_enabled():
		return
	if _season_reset_label:
		_season_reset_label.text = tr("MARATHON_ROTATION_RESET_FMT") % _TimeUtils.format_countdown_hms(
			_MarathonSeason.seconds_until_next_season()
		)
	if _next_set_toggle:
		var expanded := _next_set_visible
		_next_set_toggle.text = (
			tr("MARATHON_ROTATION_NEXT_HIDE") if expanded else tr("MARATHON_ROTATION_NEXT_TOGGLE")
		)
	_sync_courses_title()


func _sync_courses_title() -> void:
	if _courses_title == null:
		return
	if not _MarathonSeason.is_enabled():
		_courses_title.text = tr("MARATHON_CATALOG_COURSES_TITLE")
		return
	if _next_set_visible:
		_courses_title.text = tr("MARATHON_ROTATION_NEXT_TITLE")
	else:
		_courses_title.text = tr("MARATHON_SEASON_ROUTES_TITLE")


func _setup_panels() -> void:
	_style_panel(_hero_panel, _accent, 16)
	var summary_panel: PanelContainer = get_node_or_null("%SummaryPanel") as PanelContainer
	if summary_panel:
		_style_panel(summary_panel, _accent, 16)
	_wrap_settings_host()
	if _start_button:
		_start_button.theme_type_variation = &""
		_SongSelectUiStyles.apply_play_button_style(_start_button, _accent)
		UiIconHelper.apply_icon_from_meta(_start_button, 18, _accent)


func _wrap_settings_host() -> void:
	if _settings_host == null or _settings_host.get_parent() == null:
		return
	var parent := _settings_host.get_parent()
	if parent.get_node_or_null("SettingsPanel") != null:
		return
	var panel := PanelContainer.new()
	panel.name = "SettingsPanel"
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.clip_contents = true
	_style_panel(panel, _accent, 16)
	var scroll := ScrollContainer.new()
	scroll.name = "SettingsScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	var idx := _settings_host.get_index()
	parent.remove_child(_settings_host)
	_settings_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Natural height inside scroll — do not expand to fill the viewport.
	_settings_host.size_flags_vertical = 0
	margin.add_child(_settings_host)
	scroll.add_child(margin)
	panel.add_child(scroll)
	parent.add_child(panel)
	parent.move_child(panel, idx)


func _setup_summary_rows() -> void:
	if _summary_vbox == null:
		return
	for child in _summary_vbox.get_children():
		child.queue_free()
	_summary_rows.clear()
	var specs: Array[Dictionary] = [
		{"id": "route", "icon": "list-checks.svg"},
		{"id": "order", "icon": "shuffle.svg"},
		{"id": "best", "icon": "trophy.svg"},
		{"id": "pool", "icon": "music.svg"},
		{"id": "locked", "icon": "lock_keyhole.svg"},
	]
	for spec in specs:
		var row := _PreviewRowScript.new() as SessionSetupPreviewRow
		row.setup(str(spec.get("icon", "circle-check.svg")), "", _accent.lerp(Color.WHITE, 0.08))
		_summary_vbox.add_child(row)
		_summary_rows[str(spec.get("id", ""))] = row

	_rules_panel = _MarathonSummaryRulesPanel.new()
	_rules_panel.setup(_accent)
	_summary_vbox.add_child(_rules_panel)

	_rewards_panel = _MarathonSummaryRewardsPanel.new()
	_rewards_panel.setup(_accent)
	_summary_vbox.add_child(_rewards_panel)

	_mods_panel = _MarathonSummaryModsPanel.new()
	_mods_panel.setup(_accent)
	_summary_vbox.add_child(_mods_panel)

	_badges_panel = _MarathonSummaryBadgesPanel.new()
	_badges_panel.setup(_accent)
	_summary_vbox.add_child(_badges_panel)

	_preview_panel = _MarathonRoutePreviewPanel.new()
	_preview_panel.setup(_accent)
	_summary_vbox.add_child(_preview_panel)

	_progress_panel = _MarathonRouteProgressPanel.new()
	_progress_panel.setup(_accent)
	_summary_vbox.add_child(_progress_panel)

	_refresh_pool_button = Button.new()
	_refresh_pool_button.text = tr("MARATHON_CATALOG_REFRESH_POOL")
	_refresh_pool_button.visible = false
	_refresh_pool_button.pressed.connect(_on_refresh_pool_pressed)
	_summary_vbox.add_child(_refresh_pool_button)

	_generate_missing_button = Button.new()
	_generate_missing_button.text = tr("MARATHON_GENERATE_MISSING")
	if _generate_missing_button.text == "MARATHON_GENERATE_MISSING" or _generate_missing_button.text.strip_edges() == "":
		_generate_missing_button.text = "Сгенерировать отсутствующие чарты"
	_generate_missing_button.visible = false
	_generate_missing_button.pressed.connect(_on_generate_missing_pressed)
	_summary_vbox.add_child(_generate_missing_button)

	# Keep rules/badges above detail rows.
	_summary_vbox.move_child(_preview_panel, 0)
	_summary_vbox.move_child(_rules_panel, 1)
	_summary_vbox.move_child(_rewards_panel, 2)
	_summary_vbox.move_child(_mods_panel, 3)
	_summary_vbox.move_child(_badges_panel, 4)
	_summary_vbox.move_child(_progress_panel, 5)


func _setup_course_settings() -> void:
	if _settings_host == null:
		return
	_course_settings = _MarathonCourseSettings.new()
	_course_settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_course_settings.set_accent_color(_accent)
	_course_settings.config_changed.connect(_on_course_settings_changed)
	_settings_host.add_child(_course_settings)


func _style_panel(panel: PanelContainer, accent: Color, radius: int) -> void:
	if panel == null:
		return
	var box := _SongSelectUiStyles.card_panel_style().duplicate() as StyleBoxFlat
	box.set_corner_radius_all(radius)
	box.border_color = Color(accent.r, accent.g, accent.b, 0.38)
	box.content_margin_left = 14.0
	box.content_margin_right = 14.0
	box.content_margin_top = 12.0
	box.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", box)


func _sync_ambient_profile() -> void:
	var engine := get_parent()
	if engine and engine.has_method("set_ambient_screen_profile"):
		engine.set_ambient_screen_profile(&"play_modes_marathon")


func _ensure_help_icon() -> void:
	if _title_label == null:
		return
	_help_btn = _SettingsSectionUi.attach_help_icon_beside_label(
		_title_label,
		tr("HELP_LINK_MARATHON_ROUTES"),
		_on_help_pressed,
		true
	)


func _on_help_pressed() -> void:
	_open_help_item("marathon_mode")


func _open_help_item(item_id: String) -> void:
	if transitions and transitions.has_method("open_help_item"):
		transitions.open_help_item(item_id)
		return
	var parent := get_parent()
	if parent and parent.has_method("get_transitions"):
		var trans = parent.get_transitions()
		if trans and trans.has_method("open_help_item"):
			trans.open_help_item(item_id)


func apply_locale() -> void:
	if _back_button:
		_back_button.text = tr("BTN_BACK")
	if _title_label:
		_title_label.text = tr("MARATHON_CATALOG_TITLE")
	if _subtitle_label:
		_subtitle_label.text = tr("MARATHON_CATALOG_SUBTITLE")
	if _help_btn:
		_help_btn.tooltip_text = tr("HELP_LINK_MARATHON_ROUTES")
	if _courses_title:
		_sync_courses_title()
	if _playlists_placeholder:
		_playlists_placeholder.text = tr("MARATHON_DAILY_TAB_HINT")
	if _summary_title:
		_summary_title.text = tr("MARATHON_CATALOG_SUMMARY_TITLE")
	if _start_button:
		_start_button.text = tr("MARATHON_CATALOG_START_MARATHON")
	if _footer_label:
		_footer_label.text = tr("MARATHON_CATALOG_FOOTER_HINT")
	if _course_settings:
		_course_settings.apply_locale()
	if _rules_panel:
		_rules_panel.apply_locale()
	if _rewards_panel:
		_rewards_panel.apply_locale()
	if _mods_panel:
		_mods_panel.apply_locale()
	if _badges_panel:
		_badges_panel.apply_locale()
	if _refresh_pool_button:
		_refresh_pool_button.text = tr("MARATHON_CATALOG_REFRESH_POOL")
	if _progress_panel:
		_progress_panel.apply_locale()
	_update_season_labels()
	_refresh_selection_ui()


func _rebuild_courses() -> void:
	var _t := Time.get_ticks_usec()
	var _t_all := Time.get_ticks_usec()
	var _routes := _MarathonRouteCatalog.all_routes()
	var _t_all_ms := (Time.get_ticks_usec()-_t_all)/1000.0
	var _g_all_calls := MarathonGenrePicker._diag_all_calls
	var _g_hits := MarathonGenrePicker._diag_all_hits
	var _g_misses := MarathonGenrePicker._diag_all_misses
	var _g_res_total: float = 0.0
	for _v in MarathonGenrePicker._diag_per_route.values():
		_g_res_total += float((_v as Dictionary).get("resolve_total", 0.0))
	_clear_preview_cache()
	_courses.clear()
	for route in _routes:
		_courses.append(route.duplicate(true))
	if not _MarathonSeason.is_enabled():
		_courses.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var key_a := _route_title(a)
			var key_b := _route_title(b)
			return key_a.naturalnocasecmp_to(key_b) < 0
		)
	var _t_list := Time.get_ticks_usec()
	_rebuild_list()


func _route_title(route: Dictionary, template: Dictionary = {}) -> String:
	if not template.is_empty():
		return _MarathonRouteCharacter.display_title(template, route)
	if str(route.get("route_type", "")) == _MarathonDailyRoute.ROUTE_TYPE_DAILY:
		return tr("MARATHON_DAILY_TITLE")
	var title_key := str(route.get("title_key", "")).strip_edges()
	if title_key != "":
		var emoji := str(route.get("icon_emoji", "")).strip_edges()
		var title := tr(title_key)
		if emoji != "":
			return "%s %s" % [emoji, title]
		return title
	return str(route.get("route_id", ""))


func _route_fill_line(route_id: String, template: Dictionary) -> String:
	var tagline := _MarathonRouteCharacter.tagline(template)
	if tagline != "":
		return tagline
	if _MarathonDailyRoute.is_daily_route(route_id):
		return _MarathonDailyRoute.summary_line(template)
	if _MarathonSeason.is_season_route(route_id):
		return _MarathonSeason.current_fill_line(template)
	return tr(_ProfileGenrePortrait.group_locale_key(str(template.get("genre_group_id", ""))))


func _rebuild_list() -> void:
	var _t := Time.get_ticks_usec()
	if _courses_list_vbox == null:
		return
	_rebuild_token += 1
	var token := _rebuild_token
	for child in _courses_list_vbox.get_children():
		child.queue_free()
	_list_item_nodes.clear()
	if _courses_scroll:
		_courses_scroll.visible = not _next_set_visible
	var challenge_routes: Array[Dictionary] = []
	var rotation_routes: Array[Dictionary] = []
	for course in _courses:
		var route_id := str(course.get("route_id", "")).strip_edges()
		if route_id == "":
			continue
		if _MarathonDailyRoute.is_daily_route(route_id):
			challenge_routes.append(course)
			continue
		var archetype_id := str(course.get("archetype_id", "")).strip_edges()
		if _MarathonRouteRolls.is_challenge_archetype(archetype_id):
			challenge_routes.append(course)
			continue
		rotation_routes.append(course)
	# Create shells synchronously (light), then fill previews batched.
	var _t_shell := Time.get_ticks_usec()
	if not challenge_routes.is_empty():
		_add_list_section(tr("MARATHON_CATALOG_CHALLENGES_TITLE"), challenge_routes, true)
	if not rotation_routes.is_empty():
		var rotation_title := tr("MARATHON_SEASON_ROUTES_TITLE") if _MarathonSeason.is_enabled() else tr("MARATHON_CATALOG_COURSES_TITLE")
		_add_list_section(rotation_title, rotation_routes, true)
	# Kick batched preview fill for all routes.
	var all_for_preview: Array[Dictionary] = []
	all_for_preview.append_array(challenge_routes)
	all_for_preview.append_array(rotation_routes)
	var _t_kick := Time.get_ticks_usec()
	_kick_batched_preview_fill(token, all_for_preview)


func _kick_batched_preview_fill(token: int, courses: Array[Dictionary]) -> void:
	if courses.is_empty():
		return
	# Use existing async helper if available, otherwise inline.
	var engine := get_parent()
	if engine and engine.has_method("run_async"):
		engine.run_async(_batched_preview_coro.bind(token, courses))
	else:
		_batched_preview_coro(token, courses)


func _batched_preview_coro(token: int, courses: Array[Dictionary]) -> void:
	var _diag_start := Time.get_ticks_usec()
	var _diag_count := 0
	var _diag_hits := 0
	var _diag_miss := 0
	var _diag_min_ms := INF
	var _diag_max_ms := 0.0
	if token != _rebuild_token or not is_inside_tree():
		return
	var batch_count := 0
	for course in courses:
		if token != _rebuild_token or not is_inside_tree():
			return
		var route_id := str(course.get("route_id", "")).strip_edges()
		if route_id == "":
			continue
		# Selected route preview is deferred via _deferred_refresh_selected_preview — skip here to avoid double heavy.
		if route_id == _selected_route_id:
			continue
		var cfg: Dictionary = {}
		var key := _preview_cache_key(route_id, cfg)
		if _preview_cache.has(key):
			_diag_hits += 1
			# Cache hit — still ensure card meta is synced without heavy recompute.
			var cached: Dictionary = _preview_cache[key] as Dictionary
			_update_card_with_preview(route_id, cached)
			continue
		_diag_miss += 1
		# Heavy sync work — one route at a time via cached wrapper.
		var _p_t := Time.get_ticks_usec()
		var preview := _preview_for_route(route_id)
		var _p_ms := (Time.get_ticks_usec() - _p_t) / 1000.0
		_diag_min_ms = minf(_diag_min_ms, _p_ms)
		_diag_max_ms = maxf(_diag_max_ms, _p_ms)
		_diag_count += 1
		if not _preview_cache.has(key) and not preview.is_empty():
			_preview_cache[key] = preview
		_update_card_with_preview(route_id, preview)
		batch_count += 1
		if batch_count % _REBUILD_BATCH_SIZE == 0:
			await get_tree().process_frame
			if token != _rebuild_token or not is_inside_tree():
				return
	# After all batches, selection hero already handled via deferred refresh; no extra heavy call here.


func _update_card_with_preview(route_id: String, preview: Dictionary) -> void:
	var panel: PanelContainer = _list_item_nodes.get(route_id, null) as PanelContainer
	if panel == null or not is_instance_valid(panel):
		return
	# Update playable meta and visual state without recreating card.
	var playable: bool = bool(preview.get("ok", false))
	panel.set_meta("route_playable", playable)
	# Update border and modulate via existing helper.
	_sync_list_item_focus(route_id)
	# Update meta label (catalog_list_subtitle) if present.
	# Find text_col -> meta is 3rd child of text_col (title, fill, meta)
	var preview_template: Dictionary = preview.get("template", {}) as Dictionary if preview.get("template") is Dictionary else {}
	var template: Dictionary = preview_template
	if template.is_empty():
		template = _MarathonRouteCatalog.template_for_route(route_id)
		if template.is_empty() and _MarathonSeason.is_season_route(route_id):
			template = _MarathonSeason.template_for_route_id(route_id)
	var meta_text := _MarathonRouteLength.catalog_list_subtitle(template, preview)
	var best_text := _best_completion_label(route_id) if playable else ""
	# Locate card structure: panel -> root HBox -> text_col VBox
	var root := panel.get_child(0) as HBoxContainer
	if root == null or root.get_child_count() < 2:
		return
	var text_col := root.get_child(1) as VBoxContainer
	if text_col == null:
		return
	# Children: title(0), fill(1), meta(2), best(3?)
	if text_col.get_child_count() >= 3:
		var meta_label := text_col.get_child(2) as Label
		if meta_label:
			meta_label.text = meta_text
			meta_label.add_theme_color_override("font_color", Color(0.72, 0.78, 0.88, 1.0) if playable else Color(0.82, 0.62, 0.58, 1.0))
	if text_col.get_child_count() >= 4:
		var best_label := text_col.get_child(3) as Label
		if best_label:
			if best_text != "":
				best_label.text = best_text
				best_label.visible = true
				best_label.modulate = Color.WHITE
				var done := _route_is_completed(route_id)
				best_label.add_theme_color_override(
					"font_color",
					Color(0.55, 0.88, 0.7, 1.0) if done else Color(0.96, 0.78, 0.34, 1.0)
				)
			else:
				# Keep placeholder height stable (16px) — no layout jump.
				best_label.text = ""
				best_label.add_theme_color_override("font_color", Color(0, 0, 0, 0))
				best_label.modulate = Color(1, 1, 1, 0)
				best_label.visible = true


func _ready_courses() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for course in _courses:
		var preview := _preview_for_route(str(course.get("route_id", "")))
		if bool(preview.get("ok", false)):
			out.append(course)
	return out


func _locked_courses() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for course in _courses:
		var preview := _preview_for_route(str(course.get("route_id", "")))
		if not bool(preview.get("ok", false)):
			out.append(course)
	return out


func _add_list_section(title: String, courses: Array[Dictionary], use_placeholder: bool = false) -> void:
	if courses.is_empty():
		return
	var header := Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", _accent.lerp(Color.WHITE, 0.1))
	_courses_list_vbox.add_child(header)
	for course in courses:
		_add_course_row(str(course.get("route_id", "")), use_placeholder)


func _make_route_list_card(
	route_id: String,
	selectable: bool = true,
	template_hint: Dictionary = {},
	use_placeholder: bool = false
) -> PanelContainer:
	# Selectable rows need playable scope; locked next-set previews use template only.
	var preview := {}
	var playable := false
	if selectable:
		if use_placeholder:
			# Fast path: use cached preview if available, otherwise placeholder (assume playable).
			if _preview_cache.has(route_id):
				preview = _preview_cache[route_id] as Dictionary
				playable = bool(preview.get("ok", false))
			else:
				preview = {}
				playable = true
		else:
			preview = _preview_for_route(route_id)
			playable = bool(preview.get("ok", false))
	var route := _MarathonRouteCatalog.route_by_id(route_id)
	if route.is_empty() and _MarathonSeason.is_season_route(route_id):
		route = _MarathonSeason.route_by_id(route_id)
	var group_id := str(route.get("source_id", _MarathonRouteCatalog.genre_group_for_route(route_id)))
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 88)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.clip_contents = true
	panel.mouse_filter = Control.MOUSE_FILTER_STOP if selectable else Control.MOUSE_FILTER_IGNORE
	if selectable:
		UiClick.connect_clicked(panel, func() -> void: _select_route(route_id))
	else:
		panel.tooltip_text = tr("MARATHON_ROTATION_PREVIEW_LOCKED")
		panel.modulate = Color(0.88, 0.9, 0.94, 0.85)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.1, 0.14, 0.98)
	box.border_color = _accent.lerp(Color.WHITE, -0.2)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", box)

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(root)

	var tint := _GenreGroupIcons.tint_for_group(group_id)
	root.add_child(_GenreGroupIcons.make_icon_frame_for_group(group_id, tint, 36, 18, false))

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 2)
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(text_col)

	var template: Dictionary = template_hint.duplicate(true) if not template_hint.is_empty() else {}
	if template.is_empty() and preview.get("template") is Dictionary:
		template = preview.get("template") as Dictionary
	if template.is_empty():
		template = _MarathonRouteCatalog.template_for_route(route_id)
	if template.is_empty() and _MarathonSeason.is_season_route(route_id):
		template = _MarathonSeason.template_for_route_id(route_id)

	var title := Label.new()
	title.text = _route_title(route, template) if not route.is_empty() else tr("MARATHON_CATALOG_NO_SELECTION")
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 1.0))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_col.add_child(title)

	var fill := Label.new()
	fill.text = _route_fill_line(route_id, template)
	fill.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fill.add_theme_font_size_override("font_size", 12)
	fill.add_theme_color_override("font_color", Color(0.72, 0.78, 0.88, 1.0))
	text_col.add_child(fill)

	var meta := Label.new()
	meta.text = _MarathonRouteLength.catalog_list_subtitle(template, preview)
	meta.add_theme_font_size_override("font_size", 12)
	meta.add_theme_color_override("font_color", Color(0.72, 0.78, 0.88, 1.0) if playable else Color(0.82, 0.62, 0.58, 1.0))
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_col.add_child(meta)

	var best_label := _best_completion_label(route_id) if selectable else ""
	var best := Label.new()
	best.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	best.add_theme_font_size_override("font_size", 12)
	best.custom_minimum_size = Vector2(0, 16)
	if best_label != "":
		best.text = best_label
		var done := _route_is_completed(route_id)
		best.add_theme_color_override(
			"font_color",
			Color(0.55, 0.88, 0.7, 1.0) if done else Color(0.96, 0.78, 0.34, 1.0)
		)
		best.visible = true
		best.modulate = Color.WHITE
		if done:
			box.border_color = Color(0.55, 0.88, 0.7, 0.55)
			root.add_child(_UiIconHelper.make_icon_frame("circle-check.svg", 28, 16, Color(0.55, 0.88, 0.7, 1.0)))
	else:
		# Placeholder keeps 88px card height stable — no jump when preview fills or best appears.
		best.text = ""
		best.add_theme_color_override("font_color", Color(0, 0, 0, 0))
		best.modulate = Color(1, 1, 1, 0)
		best.visible = true
	text_col.add_child(best)

	if not playable and selectable:
		panel.modulate = Color(0.88, 0.9, 0.94, 1.0)
	if selectable:
		panel.set_meta("route_playable", playable)
		_list_item_nodes[route_id] = panel
		_sync_list_item_focus(route_id)
		if playable:
			panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			# Hover — whole card, reuse existing focus colors, no new animations
			panel.mouse_entered.connect(func() -> void:
				if route_id == _selected_route_id:
					return
				var b := panel.get_theme_stylebox("panel") as StyleBoxFlat
				if b:
					b.border_color = _accent.lightened(0.22)
			)
			panel.mouse_exited.connect(func() -> void:
				_sync_list_item_focus(route_id)
			)
		else:
			panel.mouse_default_cursor_shape = Control.CURSOR_ARROW
	else:
		panel.mouse_default_cursor_shape = Control.CURSOR_ARROW
	return panel


func _set_list_card_subtitle(card: PanelContainer, text: String) -> void:
	if card == null or str(text).strip_edges() == "":
		return
	var root := card.get_child(0) as HBoxContainer
	if root == null or root.get_child_count() < 2:
		return
	var text_col := root.get_child(1) as VBoxContainer
	if text_col == null or text_col.get_child_count() < 2:
		return
	var fill := text_col.get_child(1) as Label
	if fill:
		fill.text = text


func _add_course_row(route_id: String, use_placeholder: bool = false) -> void:
	if _courses_list_vbox == null:
		return
	_courses_list_vbox.add_child(_make_route_list_card(route_id, true, {}, use_placeholder))


func _select_route(route_id: String) -> void:
	var rid := str(route_id).strip_edges()
	if rid == "":
		return
	# Same card again: keep audio/preview, only refresh selection chrome.
	if rid == _selected_route_id:
		for item_route_id in _list_item_nodes.keys():
			_sync_list_item_focus(str(item_route_id))
		return
	_selected_route_id = rid
	var template := _MarathonRouteCatalog.template_for_route(rid)
	if PlayerDataManager:
		_run_config = _MarathonRouteRolls.config_for_route(
			template,
			PlayerDataManager.get_marathon_session_last(rid)
		)
	if _run_config.is_empty():
		_run_config = _MarathonRouteRolls.rolled_config(template)
	_run_config = _MarathonSessionConfig.resolve_effective_run_config(_run_config, template)
	_run_config["route_id"] = rid
	_run_config["genre_group_id"] = _MarathonRouteCatalog.genre_group_for_route(rid)
	# Fresh route selection re-rolls instrument unless a prior session lock is present.
	if not bool(_run_config.get("instrument_locked", false)):
		_run_config.erase("instrument")
		_run_config.erase("instruments")
	_suppress_settings_changed = true
	if _course_settings:
		_course_settings.set_config(_run_config)
		_course_settings.set_route_template(_MarathonRouteCatalog.template_for_route(rid))
	_suppress_settings_changed = false
	for item_route_id in _list_item_nodes.keys():
		_sync_list_item_focus(str(item_route_id))
	_preview_audio_song_path = ""
	_cached_selected_preview.clear()
	_cached_selected_preview_key = ""
	# Keep click frame light: show placeholder immediately, defer heavy preview+cover to next frame.
	_refresh_selection_ui_placeholder()
	call_deferred("_deferred_refresh_selected_preview", rid, _rebuild_token)


func _refresh_selection_ui_placeholder() -> void:
	var _diag_t := Time.get_ticks_usec()
	# Light placeholder — no preview_for_route / Image.load. Heavy work deferred to next frame.
	var route_id := _selected_route_id
	if route_id == "":
		_refresh_selection_ui()
		return
	var _s_route := Time.get_ticks_usec()
	var route := _get_route_cached(route_id)
	var _s_tmpl := Time.get_ticks_usec()
	var template: Dictionary
	if not route.is_empty() and route.has("template") and route["template"] is Dictionary and not (route["template"] as Dictionary).is_empty():
		template = route["template"] as Dictionary
		_cached_template = template
		_cached_template_id = route_id
	else:
		template = _get_template_cached(route_id)
	var _s_hero := Time.get_ticks_usec()
	if _hero_title_label:
		_hero_title_label.text = _MarathonRouteCharacter.display_title(template, route) if not template.is_empty() else _route_title(route)
	if _hero_subtitle_label:
		_hero_subtitle_label.text = _MarathonRouteCharacter.tagline(template) if not template.is_empty() and _MarathonRouteCharacter.tagline(template) != "" else tr("MARATHON_CATALOG_PICK_COURSE")
	var _s_stat := Time.get_ticks_usec()
	if _stat_tracks_label:
		_stat_tracks_label.text = _MarathonRouteLength.hint_line(template) if not template.is_empty() else "..."
	if _stat_duration_label:
		_stat_duration_label.text = tr("MARATHON_CATALOG_STAT_DURATION_FMT") % _format_duration_minutes(0.0)
	var _s_btn := Time.get_ticks_usec()
	if _start_button:
		_start_button.disabled = true
		_start_button.modulate = Color(0.58, 0.62, 0.72, 0.72)
	# Keep summary rows showing loading hint (reuse existing full refresh with empty preview lazily if needed).
	# Do not call _selected_preview here.


func _deferred_refresh_selected_preview(expected_rid: String, token: int) -> void:
	var _diag_t := Time.get_ticks_usec()
	if token != _rebuild_token or not is_inside_tree():
		return
	if str(expected_rid).strip_edges() != str(_selected_route_id).strip_edges():
		return
	# Now safe to do heavy preview + cover + sync.
	_refresh_selection_ui()


func _on_course_settings_changed(config: Dictionary) -> void:
	if _suppress_settings_changed:
		return
	var prev := _run_config.duplicate(true)
	_run_config = config.duplicate(true)
	if _selected_route_id != "":
		_run_config["route_id"] = _selected_route_id
		_run_config["genre_group_id"] = _MarathonRouteCatalog.genre_group_for_route(_selected_route_id)
	var pool_changed := _pool_affecting_config_changed(prev, _run_config)
	var order_changed := str(prev.get("track_order", "")) != str(_run_config.get("track_order", ""))
	if pool_changed:
		_clear_preview_cache()
		_pending_settings_rebuild_list = true
		_pending_settings_full_refresh = true
	elif order_changed:
		_pending_settings_full_refresh = true
	# Do not clear preview audio here — _sync_route_audio_preview restarts only when
	# the first route song path actually changes.
	_schedule_settings_refresh()


func _pool_affecting_config_changed(prev: Dictionary, next: Dictionary) -> bool:
	for key in _POOL_AFFECTING_KEYS:
		var a: Variant = prev.get(key, null)
		var b: Variant = next.get(key, null)
		if str(a) != str(b):
			return true
	return false


func _config_hash(cfg: Dictionary) -> String:
	if cfg.is_empty():
		return ""
	var parts: Array[String] = []
	for k in _POOL_AFFECTING_KEYS:
		parts.append(str(cfg.get(k, "")))
	parts.append(str(cfg.get("track_order", "")))
	parts.append(str(cfg.get("instrument", "")))
	return "|".join(parts)


func _preview_cache_key(rid: String, cfg: Dictionary) -> String:
	var h := _config_hash(cfg)
	if h == "":
		return rid
	return "%s|%s" % [rid, h]


func _candidate_cache_key(rid: String, scope_cfg: Dictionary) -> String:
	var h := _config_hash(scope_cfg)
	if h == "":
		return "cand|%s" % rid
	return "cand|%s|%s" % [rid, h]


func _candidate_songs_for_route(route_id: String, effective_config: Dictionary = {}) -> int:
	var rid := str(route_id).strip_edges()
	if rid == "":
		return 0
	var template := _MarathonRouteCatalog.template_for_route(rid)
	if template.is_empty():
		return 0
	var scope_cfg: Dictionary
	if not effective_config.is_empty():
		scope_cfg = _MarathonSessionConfig.to_scope_config(effective_config, template)
	else:
		var gid := str(template.get("genre_group_id", "")).strip_edges()
		scope_cfg = _EndlessSessionConfig.sanitize({
			"track_source": _EndlessSessionConfig.TRACK_SOURCE_RANDOM,
			"genre_policy": _EndlessSessionConfig.GENRE_POLICY_GROUPS,
			"genre_group_ids": [gid] if gid != "" else [],
			"difficulty_min": float(template.get("difficulty_min", 2.0)),
			"difficulty_max": float(template.get("difficulty_max", 7.0)),
			"duration_min_sec": int(template.get("duration_min_sec", 90)),
			"duration_max_sec": int(template.get("duration_max_sec", 420)),
			"mod_policy": str(template.get("mod_policy", _EndlessSessionConfig.MOD_POLICY_NONE)),
			"generation_mode_policy": _EndlessSessionConfig.GEN_MODE_POLICY_ALL,
		})
	var key := _candidate_cache_key(rid, scope_cfg)
	if _candidate_cache.has(key):
		return int(_candidate_cache[key])
	var _t := Time.get_ticks_usec()
	var stats: Dictionary = _SessionScopeResolver.candidate_pool_stats(scope_cfg)
	var cand: int = int(stats.get("songs", 0))
	_candidate_cache[key] = cand
	return cand


func _get_route_cached(route_id: String) -> Dictionary:
	var rid := str(route_id).strip_edges()
	if rid == "":
		return {}
	if _cached_route_id == rid and not _cached_route.is_empty():
		return _cached_route
	var r := _MarathonRouteCatalog.route_by_id(rid)
	_cached_route = r
	_cached_route_id = rid
	return r


func _get_template_cached(route_id: String) -> Dictionary:
	var rid := str(route_id).strip_edges()
	if rid == "":
		return _MarathonRouteCatalog.sanitize_template({})
	if _cached_template_id == rid and not _cached_template.is_empty():
		return _cached_template
	var t := _MarathonRouteCatalog.template_for_route(rid)
	_cached_template = t
	_cached_template_id = rid
	return t


func _schedule_settings_refresh() -> void:
	if _settings_refresh_timer == null:
		_settings_refresh_timer = Timer.new()
		_settings_refresh_timer.one_shot = true
		_settings_refresh_timer.wait_time = 0.12
		add_child(_settings_refresh_timer)
		_settings_refresh_timer.timeout.connect(_on_settings_refresh_debounced)
	_settings_refresh_timer.start()


func _on_settings_refresh_debounced() -> void:
	if _pending_settings_rebuild_list:
		_pending_settings_rebuild_list = false
		_rebuild_list()
	if _pending_settings_full_refresh:
		_pending_settings_full_refresh = false
		_cached_selected_preview.clear()
		_cached_selected_preview_key = ""
		_refresh_selection_ui()
	else:
		_refresh_settings_chrome_only()


func _refresh_settings_chrome_only() -> void:
	# Mods / cosmetic settings: update summary chrome without rebuilding the route pool.
	var template := _MarathonRouteCatalog.template_for_route(_selected_route_id)
	if _mods_panel:
		_mods_panel.visible = _selected_route_id != ""
		if _selected_route_id != "":
			_mods_panel.refresh(template, _run_config)
	if _rewards_panel and _selected_route_id != "":
		var playable := true
		if not _cached_selected_preview.is_empty():
			playable = bool(_cached_selected_preview.get("ok", false))
		var reward_tracks := int(_cached_selected_preview.get("track_count", template.get("track_count", 0)))
		_rewards_panel.refresh(template, _run_config, reward_tracks, playable)
	var order_row: SessionSetupPreviewRow = _summary_rows.get("order", null)
	if order_row:
		var order_key := str(_run_config.get("track_order", _MarathonSessionConfig.TRACK_ORDER_COURSE))
		if order_key == _MarathonSessionConfig.TRACK_ORDER_RANDOM:
			order_row.set_text(tr("MARATHON_CATALOG_SUMMARY_ORDER_RANDOM"))
		else:
			order_row.set_text(tr("MARATHON_CATALOG_SUMMARY_ORDER_COURSE"))
	for item_route_id in _list_item_nodes.keys():
		_sync_list_item_focus(str(item_route_id))


func _clear_preview_cache() -> void:
	_preview_cache.clear()
	_candidate_cache.clear()
	MarathonGenrePicker.clear_meets_cache()
	_cached_route.clear()
	_cached_route_id = ""
	_cached_template.clear()
	_cached_template_id = ""
	_cached_selected_preview.clear()
	_cached_selected_preview_key = ""


func _preview_for_route(route_id: String) -> Dictionary:
	var rid := str(route_id).strip_edges()
	if rid == "":
		return {}
	var config := _run_config if rid == _selected_route_id else {}
	var key := _preview_cache_key(rid, config)
	if _preview_cache.has(key):
		return _preview_cache[key] as Dictionary
	var built := _MarathonRouteBuilder.preview_for_route(rid, config)
	_preview_cache[key] = built
	return built





func _selected_preview() -> Dictionary:
	if _selected_route_id == "":
		return {}
	var key := _preview_cache_key(_selected_route_id, _run_config)
	if _cached_selected_preview_key == key and not _cached_selected_preview.is_empty():
		return _cached_selected_preview
	# Reuse _preview_cache if already built for this config.
	if _preview_cache.has(key):
		_cached_selected_preview = _preview_cache[key] as Dictionary
		_cached_selected_preview_key = key
		return _cached_selected_preview
	_cached_selected_preview = _MarathonRouteBuilder.preview_for_route(_selected_route_id, _run_config)
	_cached_selected_preview_key = key
	_preview_cache[key] = _cached_selected_preview
	return _cached_selected_preview


func _sync_instrument_from_preview(preview: Dictionary) -> void:
	if preview.is_empty():
		return
	var inst := str(preview.get("instrument", "")).strip_edges()
	if inst == "" and preview.get("run_config") is Dictionary:
		inst = str((preview.get("run_config") as Dictionary).get("instrument", "")).strip_edges()
	if inst == "":
		return
	_run_config["instrument"] = inst
	_run_config["instruments"] = [inst]
	_run_config["instrument_locked"] = true
	if _course_settings and _course_settings.has_method("set_resolved_instrument"):
		_course_settings.set_resolved_instrument(inst)


func _sync_chart_style_from_preview(preview: Dictionary) -> void:
	if preview.is_empty() or not bool(preview.get("chart_style_auto_widened", false)):
		return
	var rc: Variant = preview.get("run_config", {})
	if rc is not Dictionary:
		return
	var policy := str((rc as Dictionary).get("generation_mode_policy", ""))
	var allowed: Array = (rc as Dictionary).get("generation_modes_allowed", [])
	if policy == "":
		return
	_run_config["generation_mode_policy"] = policy
	_run_config["generation_modes_allowed"] = allowed.duplicate()
	if _course_settings == null:
		return
	_suppress_settings_changed = true
	_course_settings.set_config(_run_config)
	_suppress_settings_changed = false


func _refresh_selection_ui() -> void:
	var _diag_t := Time.get_ticks_usec()
	var _diag_steps_sum := 0.0
	var _diag_preview_t := Time.get_ticks_usec()
	var preview := _selected_preview()
	var _diag_preview_ms := (Time.get_ticks_usec() - _diag_preview_t) / 1000.0
	_diag_steps_sum += _diag_preview_ms
	var _s_result_handling := Time.get_ticks_usec()
	var playable := bool(preview.get("ok", false))
	var template: Dictionary = preview.get("template", {}) if preview.get("template") is Dictionary else {}
	if template.is_empty() and _selected_route_id != "":
		var _s_tmpl2 := Time.get_ticks_usec()
		template = _get_template_cached(_selected_route_id)
		var _d_tmpl2 := (Time.get_ticks_usec()-_s_tmpl2)/1000.0
		_diag_steps_sum += _d_tmpl2
	var route_id := _selected_route_id
	var _d_result_handling := (Time.get_ticks_usec()-_s_result_handling)/1000.0
	_diag_steps_sum += _d_result_handling
	var _s_route_lookup := Time.get_ticks_usec()
	var route: Dictionary
	if route_id == "":
		route = {}
	else:
		route = _get_route_cached(route_id)
	var _d_route_lookup := (Time.get_ticks_usec()-_s_route_lookup)/1000.0
	_diag_steps_sum += _d_route_lookup

	var _s_sync_inst := Time.get_ticks_usec()
	_sync_instrument_from_preview(preview)
	var _d_sync_inst := (Time.get_ticks_usec()-_s_sync_inst)/1000.0
	_diag_steps_sum += _d_sync_inst
	var _s_sync_style := Time.get_ticks_usec()
	_sync_chart_style_from_preview(preview)
	var _d_sync_style := (Time.get_ticks_usec()-_s_sync_style)/1000.0
	_diag_steps_sum += _d_sync_style
	var _s_course_prev := Time.get_ticks_usec()
	if _course_settings and _course_settings.has_method("set_route_preview"):
		_course_settings.set_route_preview(preview)
	var _d_course_prev := (Time.get_ticks_usec()-_s_course_prev)/1000.0
	_diag_steps_sum += _d_course_prev

	var _s_hero_labels := Time.get_ticks_usec()
	if _hero_title_label:
		if route_id == "":
			_hero_title_label.text = tr("MARATHON_CATALOG_NO_SELECTION")
		else:
			_hero_title_label.text = _MarathonRouteCharacter.display_title(template, route) if not template.is_empty() else _route_title(route)
	if _hero_subtitle_label:
		if route_id == "":
			_hero_subtitle_label.text = tr("MARATHON_CATALOG_PICK_COURSE")
		else:
			var tagline := _MarathonRouteCharacter.tagline(template)
			if tagline != "":
				_hero_subtitle_label.text = "\"%s\"" % tagline
			elif _MarathonDailyRoute.is_daily_route(route_id):
				_hero_subtitle_label.text = _MarathonDailyRoute.summary_line(template)
			else:
				var idea := _MarathonRouteCharacter.idea_label(template)
				_hero_subtitle_label.text = idea if idea != "" else tr("MARATHON_CATALOG_PICK_COURSE")
	var _d_hero_labels := (Time.get_ticks_usec()-_s_hero_labels)/1000.0
	_diag_steps_sum += _d_hero_labels
	var _s_cover := Time.get_ticks_usec()
	_update_hero_cover(preview)
	var _d_cover := (Time.get_ticks_usec()-_s_cover)/1000.0
	_diag_steps_sum += _d_cover

	var _s_stats := Time.get_ticks_usec()
	var built_count := int(preview.get("track_count", 0))
	var est_sec := float(preview.get("estimated_duration_sec", 0.0))
	var dmin := float(template.get("difficulty_min", 2.0))
	var dmax := float(template.get("difficulty_max", 7.0))
	if _stat_tracks_label:
		if playable and built_count > 0:
			_stat_tracks_label.text = tr("MARATHON_CATALOG_STAT_TRACKS_FMT") % built_count
		else:
			_stat_tracks_label.text = _MarathonRouteLength.hint_line(template)
	if _stat_duration_label:
		_stat_duration_label.text = tr("MARATHON_CATALOG_STAT_DURATION_FMT") % _format_duration_minutes(est_sec)
	if _stat_difficulty_label:
		# Keep numeric range, ZAP icon shows difficulty tier (reuse ChartDifficultyAnalyzer pattern)
		_stat_difficulty_label.text = "%.1f → %.1f" % [dmin, dmax]
		var avg := (dmin + dmax) * 0.5
		var tint := _ChartDifficultyAnalyzer.rating_color(int(round(avg)))
		if _stat_difficulty_zap and is_instance_valid(_stat_difficulty_zap):
			_stat_difficulty_zap.queue_free()
			_stat_difficulty_zap = null
		_stat_difficulty_zap = _UiIconHelper.make_icon_frame("zap.svg", 20, 12, tint)
		var stats_row := _stat_difficulty_label.get_parent() as HBoxContainer
		if stats_row:
			var idx := _stat_difficulty_label.get_index()
			stats_row.add_child(_stat_difficulty_zap)
			stats_row.move_child(_stat_difficulty_zap, idx + 1)
	if _playlists_placeholder:
		if _MarathonDailyRoute.is_daily_route(route_id):
			_playlists_placeholder.text = "%s\n\n%s" % [
				tr("MARATHON_DAILY_TAB_HINT"),
				_MarathonDailyRoute.summary_line(template),
			]
		elif route_id == "":
			_playlists_placeholder.text = tr("MARATHON_DAILY_TAB_HINT")
	var _d_stats := (Time.get_ticks_usec()-_s_stats)/1000.0
	_diag_steps_sum += _d_stats
	var _s_summary := Time.get_ticks_usec()
	_refresh_summary_rows(preview, playable, template, route_id, route)
	var _d_summary := (Time.get_ticks_usec()-_s_summary)/1000.0
	_diag_steps_sum += _d_summary
	var _s_audio := Time.get_ticks_usec()
	_sync_route_audio_preview(preview)
	var _d_audio := (Time.get_ticks_usec()-_s_audio)/1000.0
	_diag_steps_sum += _d_audio

	var _s_tail := Time.get_ticks_usec()
	if _start_button:
		_start_button.disabled = not playable or route_id == ""
		_start_button.modulate = Color.WHITE if _start_button.disabled == false else Color(0.58, 0.62, 0.72, 0.72)
	if _course_settings:
		_course_settings.visible = route_id != ""
		if _course_settings.has_method("set_interactive"):
			_course_settings.set_interactive(playable)
	if route_id == "":
		if _hero_cover:
			_hero_cover.texture = null
	var _d_tail := (Time.get_ticks_usec()-_s_tail)/1000.0
	_diag_steps_sum += _d_tail
	var _total_ms := (Time.get_ticks_usec()-_diag_t)/1000.0
	var _unaccounted := _total_ms - _diag_steps_sum


func _refresh_summary_rows(
	preview: Dictionary,
	playable: bool,
	template: Dictionary,
	route_id: String,
	route: Dictionary = {}
) -> void:
	var _diag_t := Time.get_ticks_usec()
	var _route_for_panel: Dictionary = route
	if _route_for_panel.is_empty() and route_id != "":
		_route_for_panel = _get_route_cached(route_id)
	var route_row: SessionSetupPreviewRow = _summary_rows.get("route", null)
	var order_row: SessionSetupPreviewRow = _summary_rows.get("order", null)
	var best_row: SessionSetupPreviewRow = _summary_rows.get("best", null)
	var pool_row: SessionSetupPreviewRow = _summary_rows.get("pool", null)
	var locked_row: SessionSetupPreviewRow = _summary_rows.get("locked", null)

	var built_count := int(preview.get("track_count", 0))
	var tracks_label := _MarathonRouteLength.tracks_range_label(template)
	var available := int(preview.get("available_songs", 0))

	var _s_route_row := Time.get_ticks_usec()
	if route_row:
		if route_id == "":
			route_row.set_text(tr("MARATHON_CATALOG_SUMMARY_EMPTY"))
			route_row.set_tone("default")
		elif playable and built_count > 0:
			route_row.set_text(
				tr("MARATHON_CATALOG_SUMMARY_PROGRESS_FMT") % [built_count, tracks_label]
			)
			route_row.set_tone("hero")
		else:
			route_row.set_text(tr("MARATHON_CATALOG_SUMMARY_LENGTH_FMT") % _MarathonRouteLength.hint_line(template))
			route_row.set_tone("warn")
		route_row.visible = true
	var _s_rules := Time.get_ticks_usec()
	if _rules_panel:
		if route_id == "":
			_rules_panel.visible = false
		else:
			_rules_panel.refresh(template)

	var _s_rewards := Time.get_ticks_usec()
	if _rewards_panel:
		if route_id == "" or not playable:
			_rewards_panel.visible = false
		else:
			var effective_cfg := _MarathonSessionConfig.resolve_effective_mod_config(_run_config, template)
			var reward_tracks := built_count if built_count > 0 else int(template.get("track_count", 5))
			_rewards_panel.refresh(template, effective_cfg, reward_tracks, playable)
	var _s_mods := Time.get_ticks_usec()
	if _mods_panel:
		if route_id == "":
			_mods_panel.visible = false
		else:
			var mod_cfg := _MarathonSessionConfig.resolve_effective_mod_config(_run_config, template)
			_mods_panel.refresh(template, mod_cfg)
	var _s_badges := Time.get_ticks_usec()
	if _badges_panel:
		if route_id == "":
			_badges_panel.visible = false
		else:
			_badges_panel.refresh(route_id, template, _earned_badges(route_id))
	var _s_preview_panel := Time.get_ticks_usec()
	if _preview_panel:
		if route_id == "":
			_preview_panel.visible = false
		else:
			_preview_panel.refresh(template, preview, _route_for_panel)
	var _s_progress := Time.get_ticks_usec()
	if _progress_panel:
		if route_id == "":
			_progress_panel.visible = false
		else:
			_progress_panel.refresh(route_id, template)

	var _s_order := Time.get_ticks_usec()
	if order_row:
		if route_id == "":
			order_row.visible = false
		else:
			order_row.visible = true
			var order_key := str(_run_config.get("track_order", _MarathonSessionConfig.TRACK_ORDER_COURSE))
			if order_key == _MarathonSessionConfig.TRACK_ORDER_RANDOM:
				order_row.set_text(tr("MARATHON_CATALOG_SUMMARY_ORDER_RANDOM"))
			else:
				order_row.set_text(tr("MARATHON_CATALOG_SUMMARY_ORDER_COURSE"))
			order_row.set_tone("default")
	var _s_best := Time.get_ticks_usec()
	if best_row:
		if route_id == "":
			best_row.visible = false
		else:
			best_row.visible = true
			var best := _best_completion_label(route_id)
			best_row.set_text(best if best != "" else tr("MARATHON_CATALOG_SUMMARY_NO_BEST"))
			best_row.set_tone("good" if best != "" else "default")

	var _s_pool := Time.get_ticks_usec()
	if pool_row:
		if route_id == "":
			pool_row.visible = false
		else:
			pool_row.visible = true
			var cand_eff: Dictionary = preview.get("run_config", _run_config) as Dictionary if preview.get("run_config", null) is Dictionary else _run_config
			var candidate := _candidate_songs_for_route(route_id, cand_eff)
			if candidate <= 0:
				candidate = available
			if candidate > available:
				pool_row.set_text("Подходит: %d · Готово: %d" % [candidate, available])
			else:
				pool_row.set_text(tr("MARATHON_CATALOG_SUMMARY_POOL_FMT") % available)
			pool_row.set_tone("default")
	var _s_locked := Time.get_ticks_usec()
	if locked_row:
		if playable or route_id == "":
			locked_row.visible = false
		else:
			locked_row.visible = true
			var cand_eff2: Dictionary = preview.get("run_config", _run_config) as Dictionary if preview.get("run_config", null) is Dictionary else _run_config
			var candidate2 := _candidate_songs_for_route(route_id, cand_eff2)
			if candidate2 <= 0:
				candidate2 = available
			if candidate2 > available and candidate2 >= int(preview.get("required_track_count", 0)):
				var missing := candidate2 - available
				locked_row.set_text("Для %d треков отсутствуют чарты · %d готово / %d подходит" % [missing, available, candidate2])
			else:
				locked_row.set_text(_MarathonRouteLength.catalog_status_message(template, preview))
			locked_row.set_tone("bad")

	if _refresh_pool_button:
		_refresh_pool_button.visible = not playable and route_id != ""
	# Generate missing uses effective run config; visible when candidate sufficient but playable insufficient.
	if _generate_missing_button:
		var show_gen := false
		if not playable and route_id != "":
			var cand_eff3: Dictionary = preview.get("run_config", _run_config) as Dictionary if preview.get("run_config", null) is Dictionary else _run_config
			var cand := _candidate_songs_for_route(route_id, cand_eff3)
			if cand <= 0:
				cand = available
			if cand >= int(preview.get("required_track_count", 3)) and cand > available:
				show_gen = true
		_generate_missing_button.visible = show_gen
		if show_gen:
			var cand_eff4: Dictionary = preview.get("run_config", _run_config) as Dictionary if preview.get("run_config", null) is Dictionary else _run_config
			var cand := _candidate_songs_for_route(route_id, cand_eff4)
			if cand <= 0:
				cand = available
			var miss := cand - available
			var btn_txt := tr("MARATHON_GENERATE_MISSING_FMT")
			if btn_txt == "MARATHON_GENERATE_MISSING_FMT" or btn_txt.strip_edges() == "":
				btn_txt = "Сгенерировать %d чартов" % miss
			else:
				btn_txt = btn_txt % miss
			_generate_missing_button.text = btn_txt


func _sync_route_audio_preview(preview: Dictionary) -> void:
	var _diag_t := Time.get_ticks_usec()
	if _route_preview_player == null:
		return
	if not bool(preview.get("ok", false)):
		_preview_audio_song_path = ""
		_route_preview_player.stop_preview()
		return
	var entries: Variant = preview.get("entries", [])
	if not entries is Array or (entries as Array).is_empty():
		_preview_audio_song_path = ""
		_route_preview_player.stop_preview()
		return
	var first: Variant = (entries as Array)[0]
	if not first is Dictionary:
		_preview_audio_song_path = ""
		_route_preview_player.stop_preview()
		return
	var song_path := str((first as Dictionary).get("song_path", "")).strip_edges()
	if song_path == "":
		_preview_audio_song_path = ""
		_route_preview_player.stop_preview()
		return
	if song_path == _preview_audio_song_path:
		return
	_preview_audio_song_path = song_path
	_route_preview_player.stop_preview()
	var _t2 := Time.get_ticks_usec()
	_route_preview_player.play_song_preview(song_path)


func _setup_generation_refresh_hooks() -> void:
	var game_engine := get_parent()
	if game_engine == null or not game_engine.has_method("get_background_service"):
		return
	_generation_service = game_engine.get_background_service()
	if _generation_service == null:
		return
	if not _generation_service.notes_completed.is_connected(_on_notes_generation_completed):
		_generation_service.notes_completed.connect(_on_notes_generation_completed)


func _on_notes_generation_completed(_song_path: String, _instrument: String, _display_name: String) -> void:
	_on_library_changed()


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		if not _initial_build_done:
			return
		_clear_preview_cache()
		_rebuild_list()
		_refresh_selection_ui()


func _on_library_changed() -> void:
	if _library_refresh_timer == null:
		_library_refresh_timer = Timer.new()
		_library_refresh_timer.one_shot = true
		_library_refresh_timer.wait_time = 0.3
		add_child(_library_refresh_timer)
		_library_refresh_timer.timeout.connect(_on_library_refresh_debounced)
	_library_refresh_timer.start()


func _on_library_refresh_debounced() -> void:
	_clear_preview_cache()
	_rebuild_list()
	if _next_set_visible:
		_rebuild_next_set_preview()
	_refresh_selection_ui()


func _on_refresh_pool_pressed() -> void:
	_clear_preview_cache()
	_rebuild_list()
	if _next_set_visible:
		_rebuild_next_set_preview()
	_refresh_selection_ui()
	var preview := _selected_preview()
	var playable := bool(preview.get("ok", false))
	if playable:
		_show_notice(tr("MARATHON_CATALOG_REFRESH_POOL_OK"))
	else:
		_show_notice(tr("MARATHON_CATALOG_REFRESH_POOL_STILL"))


func _ensure_confirm_overlay() -> AppConfirmOverlay:
	if _confirm_overlay != null and is_instance_valid(_confirm_overlay):
		return _confirm_overlay
	var existing := get_node_or_null("%ConfirmOverlay") as AppConfirmOverlay
	if existing != null:
		_confirm_overlay = existing
		return _confirm_overlay
	if _ConfirmOverlayScene != null and _ConfirmOverlayScene is PackedScene:
		var inst := (_ConfirmOverlayScene as PackedScene).instantiate() as AppConfirmOverlay
		if inst != null:
			add_child(inst)
			_confirm_overlay = inst
			return inst
	return null


func _on_generate_missing_pressed() -> void:
	if _selected_route_id == "":
		return
	var missing: Array[Dictionary] = _MarathonRouteBuilder.missing_chart_requirements(_selected_route_id, _run_config)
	if missing.is_empty():
		_show_notice(tr("MARATHON_GENERATE_MISSING_NONE"))
		return
	var preview := _selected_preview()
	var candidate := int(preview.get("candidate_songs", 0))
	var available := int(preview.get("available_songs", 0))
	var title := tr("MARATHON_GENERATE_MISSING_TITLE")
	if title == "MARATHON_GENERATE_MISSING_TITLE" or title.strip_edges() == "":
		title = "Сгенерировать чарты"
	var msg := tr("MARATHON_GENERATE_MISSING_FMT") % [missing.size(), candidate, available]
	if msg == "MARATHON_GENERATE_MISSING_FMT" or msg.strip_edges() == "":
		msg = "Будет сгенерировано %d чартов.\nПодходит: %d · Готово: %d.\nПродолжить?" % [missing.size(), candidate, available]
	# Detail first 5 variants
	var detail_lines: PackedStringArray = []
	for i in range(mini(missing.size(), 5)):
		var r := missing[i]
		var path: String = str(r.get("song_path", "")).get_file().get_basename()
		if path == "":
			path = str(r.get("song_path", "")).strip_edges()
		detail_lines.append("%s · %s (%s)" % [path, str(r.get("instrument", "")), str(r.get("chart_stem", ""))])
	if detail_lines.size() > 0:
		msg += "\n\n" + "\n".join(detail_lines)
		if missing.size() > 5:
			msg += "\n… +%d" % (missing.size() - 5)
	_ensure_confirm_overlay()
	if _confirm_overlay == null:
		return
	var confirmed: bool = await _Overlay.ask(_confirm_overlay, msg, "info", title, tr("BTN_OK"), tr("BTN_CANCEL"))
	if not confirmed:
		return
	_start_missing_generation(missing)


func _start_missing_generation(reqs: Array[Dictionary]) -> void:
	if reqs.is_empty() or _generation_service == null:
		if _generation_service == null:
			var eng := get_parent()
			if eng and eng.has_method("get_background_service"):
				_generation_service = eng.get_background_service() as GenerationService
			if _generation_service == null:
				_show_notice("Generation service unavailable")
				return
	for req in reqs:
		var song_path := str(req.get("song_path", "")).strip_edges()
		if song_path == "":
			continue
		var instrument := str(req.get("instrument", _EndlessSessionConfig.DEFAULT_INSTRUMENT))
		var chart_stem := str(req.get("chart_stem", "arcade_medium"))
		var pair := _MarathonRouteCatalog.template_for_route(_selected_route_id) # not used, but keep
		var lanes := int(req.get("lanes", 4))
		var goal := str(req.get("goal", "arcade"))
		var difficulty := str(req.get("difficulty", "medium"))
		var meta := SongLibrary.get_metadata_for_song(song_path) if SongLibrary else {}
		var bpm_raw: Variant = meta.get("bpm", "0") if meta else "0"
		var bpm := 120.0
		if bpm_raw is int or bpm_raw is float:
			bpm = float(bpm_raw)
		else:
			var s := str(bpm_raw).strip_edges()
			if s.is_valid_float():
				bpm = float(s)
		if bpm <= 0.0:
			bpm = 120.0
		var artist := str(meta.get("artist", "Unknown")) if meta else "Unknown"
		var title := str(meta.get("title", song_path.get_file())) if meta else song_path.get_file()
		if artist.strip_edges() == "":
			artist = "Unknown"
		if title.strip_edges() == "":
			title = "Unknown"
		_generation_service.start_notes_generation(song_path, instrument, bpm, lanes, 0.2, true, artist, title, "basic", "", "", goal, difficulty, 0)
		# Note: start_notes_generation handles queue; we fire all, StatusDock shows combined.
	_show_notice(tr("MARATHON_GENERATE_MISSING_STARTED") if tr("MARATHON_GENERATE_MISSING_STARTED") != "MARATHON_GENERATE_MISSING_STARTED" else "Генерация запущена — прогресс слева")


func cleanup_before_exit() -> void:
	if _route_preview_player:
		_route_preview_player.stop_preview()
	_preview_audio_song_path = ""
	super.cleanup_before_exit()


func _update_hero_cover(preview: Dictionary) -> void:
	var _diag_t := Time.get_ticks_usec()
	if _hero_cover == null:
		return
	var song_path := ""
	var entries: Variant = preview.get("entries", [])
	if entries is Array and not (entries as Array).is_empty():
		var first: Variant = (entries as Array)[0]
		if first is Dictionary:
			song_path = str((first as Dictionary).get("song_path", "")).strip_edges()
	var tex: Texture2D = null
	if song_path != "":
		tex = _RhythmDnaCoverLoader.load_cover_for_display(song_path, 512)
	if tex == null and song_path != "":
		tex = _RhythmDnaCoverLoader.fallback_cover(song_path)
	_hero_cover.texture = tex


func _sync_list_item_focus(route_id: String) -> void:
	var _diag_t := Time.get_ticks_usec()
	var panel: PanelContainer = _list_item_nodes.get(route_id, null) as PanelContainer
	if panel == null:
		return
	var playable := true
	if panel.has_meta("route_playable"):
		playable = bool(panel.get_meta("route_playable"))
	var selected := route_id == _selected_route_id
	var box: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if box == null:
		return
	if selected:
		box.bg_color = Color(0.12, 0.18, 0.28, 0.98)
		box.border_color = _accent.lightened(0.15)
		box.set_border_width_all(2)
		box.border_width_left = 5
		box.shadow_size = 12
		box.shadow_color = Color(_accent.r, _accent.g, _accent.b, 0.35)
		panel.modulate = Color.WHITE
	else:
		box.bg_color = Color(0.08, 0.1, 0.14, 0.98)
		box.border_color = _accent.lerp(Color.WHITE, -0.2 if playable else -0.35)
		box.set_border_width_all(1)
		box.shadow_size = 0
		panel.modulate = Color(0.88, 0.9, 0.94, 1.0) if not playable else Color.WHITE


func _best_completion_label(route_id: String) -> String:
	if PlayerDataManager == null or route_id == "":
		return ""
	var rid := str(route_id).strip_edges()
	var completions: Variant = PlayerDataManager.data.get("marathon_completions", {})
	if not completions is Dictionary:
		return ""
	var entry: Variant = completions.get(rid, {})
	if not entry is Dictionary:
		return ""
	var ratio := float(entry.get("best_ratio", 0.0))
	if ratio <= 0.0:
		return ""
	var badge_text := _earned_badges_label(rid)
	if ratio >= 0.999:
		if badge_text != "":
			return tr("MARATHON_CATALOG_BEST_COMPLETE_BADGE_FMT") % badge_text
		return tr("MARATHON_CATALOG_BEST_COMPLETE")
	if badge_text != "":
		return tr("MARATHON_CATALOG_BEST_RATIO_BADGE_FMT") % [int(round(ratio * 100.0)), badge_text]
	return tr("MARATHON_CATALOG_BEST_RATIO_FMT") % int(round(ratio * 100.0))


func _route_is_completed(route_id: String) -> bool:
	if PlayerDataManager == null or route_id == "":
		return false
	var completions: Variant = PlayerDataManager.data.get("marathon_completions", {})
	if not completions is Dictionary:
		return false
	var entry: Variant = completions.get(route_id, {})
	return entry is Dictionary and float(entry.get("best_ratio", 0.0)) >= 0.999


func _earned_badges(route_id: String) -> Array:
	if PlayerDataManager == null or route_id == "":
		return []
	var completions: Variant = PlayerDataManager.data.get("marathon_completions", {})
	if not completions is Dictionary:
		return []
	var entry: Variant = completions.get(route_id, {})
	if not entry is Dictionary:
		return []
	var badges: Variant = entry.get("badges", [])
	if badges is Array:
		return badges as Array
	return []


func _earned_badges_label(route_id: String) -> String:
	if PlayerDataManager == null or route_id == "":
		return ""
	var completions: Variant = PlayerDataManager.data.get("marathon_completions", {})
	if not completions is Dictionary:
		return ""
	var entry: Variant = completions.get(route_id, {})
	if not entry is Dictionary:
		return ""
	var badges: Variant = entry.get("badges", [])
	if not badges is Array or (badges as Array).is_empty():
		return ""
	return _MarathonRouteBadges.format_earned_badges(route_id, badges as Array, _MarathonRouteCatalog.template_for_route(route_id))


func _format_duration_minutes(seconds: float) -> String:
	var mins := maxi(1, int(round(seconds / 60.0)))
	return tr("MARATHON_CATALOG_DURATION_MIN_FMT") % mins


func _select_daily_route() -> void:
	_select_route(_MarathonDailyRoute.today_route_id())


func _on_start_pressed() -> void:
	if transitions == null or _selected_route_id == "":
		return
	var preview := _selected_preview()
	if not bool(preview.get("ok", false)):
		_show_notice(_MarathonRouteLength.catalog_status_message(
			preview.get("template", {}) if preview.get("template") is Dictionary else {},
			preview
		))
		return
	var template := _MarathonRouteCatalog.template_for_route(_selected_route_id)
	var launch_config := _MarathonSessionConfig.resolve_effective_run_config(_run_config, template)
	launch_config["route_id"] = _selected_route_id
	launch_config["genre_group_id"] = _MarathonRouteCatalog.genre_group_for_route(_selected_route_id)
	MusicManager.play_select_sound()
	if PlayerDataManager:
		PlayerDataManager.save_marathon_session_last(_selected_route_id, launch_config)
	if transitions.has_method("open_marathon_run"):
		if not transitions.open_marathon_run(_selected_route_id, launch_config):
			var built := _MarathonRouteBuilder.preview_for_route(_selected_route_id, launch_config)
			_show_notice(_MarathonRouteLength.catalog_status_message(template, built))


func _execute_close_transition() -> void:
	if transitions:
		transitions.close_marathon_catalog()


func _unhandled_input(event: InputEvent) -> void:
	if UiScreenHotkeys.try_handle(_hotkey_bindings(), event, get_viewport()):
		accept_event()
		return
	super._unhandled_input(event)


func _hotkey_bindings() -> Dictionary:
	return {
		KEY_UP: _move_focus.bind(-1),
		KEY_DOWN: _move_focus.bind(1),
		KEY_ENTER: _activate_focused,
		KEY_KP_ENTER: _activate_focused,
	}


func _visible_route_ids() -> Array[String]:
	var out: Array[String] = []
	for course in _courses:
		out.append(str(course.get("route_id", "")))
	return out


func _move_focus(delta: int) -> void:
	var ids := _visible_route_ids()
	if ids.is_empty():
		return
	var index := ids.find(_selected_route_id)
	if index < 0:
		index = 0
	else:
		index = clampi(index + delta, 0, ids.size() - 1)
	_select_route(ids[index])


func _activate_focused() -> void:
	if _start_button and not _start_button.disabled:
		_on_start_pressed()
		return
	var preview := _selected_preview()
	if not bool(preview.get("ok", false)):
		_show_notice(_MarathonRouteLength.catalog_status_message(
			preview.get("template", {}) if preview.get("template") is Dictionary else {},
			preview
		))


func _show_notice(message: String) -> void:
	if _notice_overlay:
		_notice_overlay.show_message(message)
