# scenes/song_select/endless/session_setup_screen.gd
extends BaseScreen

const _PlayModeIds = preload("res://logic/domain/session/play_mode_ids.gd")
const _EndlessSessionConfig = preload("res://logic/domain/session/endless_session_config.gd")
const _SessionScopeResolver = preload("res://logic/domain/session/session_scope_resolver.gd")
const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const _SongSelectUiStyles = preload("res://scenes/song_select/lib/song_select_ui_styles.gd")
const _ModPoolIconScript = preload("res://scenes/song_select/endless/session_mod_pool_icon.gd")
const _PreviewRowScript = preload("res://scenes/song_select/endless/session_setup_preview_row.gd")
const _InstrumentIconScript = preload("res://scenes/song_select/endless/session_instrument_icon.gd")
const _GenreGroupIconScript = preload("res://scenes/song_select/endless/session_genre_group_icon.gd")
const _ProfileGenrePortrait = preload("res://logic/domain/profile/profile_genre_portrait.gd")
const _GenPresetUi = preload("res://logic/ui/generation_preset_ui.gd")
const _NoticeOverlayScene = preload("res://ui/overlays/app_notice_overlay.tscn")
const _UiScreenHotkeys = preload("res://logic/ui/ui_screen_hotkeys.gd")
const _HelpCalloutScene = preload("res://scenes/help/help_callout.tscn")
const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")
const _ChartStyleSettings = preload("res://scenes/song_select/lib/chart_style_settings.gd")
const _PlaylistCatalog = preload("res://logic/domain/library/playlist_catalog.gd")
const _SliderScrollUtils = preload("res://logic/ui/slider_scroll_utils.gd")

var _config: Dictionary = {}
var _notice_overlay: AppNoticeOverlay = null
var _setup_hint_callout: HelpCallout = null
var _source_group: ButtonGroup = null
var _mod_policy_group: ButtonGroup = null
var _mod_count_group: ButtonGroup = null
var _mod_pick_group: ButtonGroup = null
var _gen_mode_policy_group: ButtonGroup = null
var _genre_policy_group: ButtonGroup = null

@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %ScreenTitleLabel
@onready var _subtitle_label: Label = %ScreenSubtitleLabel
@onready var _footer_label: Label = %FooterHintLabel
@onready var _tracks_section_title: Label = %TracksSectionTitle
@onready var _source_cards_row: HBoxContainer = %SourceCardsRow
@onready var _random_favorites_check: CheckButton = %RandomFavoritesCheck
@onready var _unique_songs_check: CheckButton = %UniqueSongsCheck
@onready var _genre_caption: Label = %GenreCaption
@onready var _genre_groups_hint: Label = %GenreGroupsHint
@onready var _genre_groups_toolbar: HBoxContainer = %GenreGroupsToolbar
@onready var _genre_groups_select_all_button: Button = %GenreGroupsSelectAllButton
@onready var _genre_groups_reset_button: Button = %GenreGroupsResetButton
@onready var _genre_groups_count_label: Label = %GenreGroupsCountLabel
@onready var _genre_policy_row: HBoxContainer = %GenrePolicyRow
@onready var _genre_groups_panel: PanelContainer = %GenreGroupsPanel
@onready var _genre_groups_flow: FlowContainer = %GenreGroupsFlow
@onready var _selected_tracks_panel: HBoxContainer = %SelectedTracksPanel
@onready var _selected_tracks_button: Button = %SelectedTracksButton
@onready var _selected_pool_after_panel: VBoxContainer = %SelectedPoolAfterPanel
@onready var _selected_pool_after_caption: Label = %SelectedPoolAfterCaption
@onready var _selected_pool_after_option: OptionButton = %SelectedPoolAfterOption
@onready var _instruments_caption: Label = %InstrumentsCaption
@onready var _instruments_row: HBoxContainer = %InstrumentsRow
@onready var _difficulty_caption: Label = %DifficultyCaption
@onready var _difficulty_min_slider: HSlider = %DifficultyMinSlider
@onready var _difficulty_max_slider: HSlider = %DifficultyMaxSlider
@onready var _difficulty_min_value_label: Label = %DifficultyMinValueLabel
@onready var _difficulty_max_value_label: Label = %DifficultyMaxValueLabel
@onready var _difficulty_range_from_label: Label = %DifficultyRangeFromLabel
@onready var _difficulty_range_to_label: Label = %DifficultyRangeToLabel
@onready var _difficulty_max_over_cap_check: CheckButton = %DifficultyMaxOverCapCheck
@onready var _difficulty_range_row: HBoxContainer = %DifficultyRangeRow
@onready var _duration_range_row: HBoxContainer = %DurationRangeRow
@onready var _duration_caption: Label = %DurationCaption
@onready var _duration_min_slider: HSlider = %DurationMinSlider
@onready var _duration_max_slider: HSlider = %DurationMaxSlider
@onready var _duration_min_value_label: Label = %DurationMinValueLabel
@onready var _duration_max_value_label: Label = %DurationMaxValueLabel
@onready var _duration_range_from_label: Label = %DurationRangeFromLabel
@onready var _duration_range_to_label: Label = %DurationRangeToLabel
@onready var _duration_max_open_check: CheckButton = %DurationMaxOpenCheck
@onready var _gen_mode_caption: Label = %GenModeCaption
@onready var _gen_mode_policy_row: HBoxContainer = %GenModePolicyRow
@onready var _gen_mode_checks_panel: PanelContainer = %GenModeChecksPanel
@onready var _gen_mode_checks_flow: FlowContainer = %GenModeChecksFlow
@onready var _mods_section_divider: HSeparator = %ModsSectionDivider
@onready var _gen_section_divider: HSeparator = %GenSectionDivider
@onready var _generation_section_title: Label = %GenerationSectionTitle
@onready var _modifiers_section_title: Label = %ModifiersSectionTitle
@onready var _mod_policy_row: HBoxContainer = %ModPolicyRow
@onready var _mod_pool_panel: PanelContainer = %ModPoolPanel
@onready var _mod_pool_caption: Label = %ModPoolCaption
@onready var _mod_pool_count_label: Label = %ModPoolCountLabel
@onready var _mod_pool_select_all_button: Button = %ModPoolSelectAllButton
@onready var _mod_pool_reset_button: Button = %ModPoolResetButton
@onready var _mod_pool_flow: FlowContainer = %ModPoolFlow
@onready var _mod_count_caption: Label = %ModCountCaption
@onready var _mod_count_row: HBoxContainer = %ModCountRow
@onready var _mod_pick_caption: Label = %ModPickCaption
@onready var _mod_pick_row: HBoxContainer = %ModPickRow
@onready var _preview_title: Label = %PreviewTitleLabel
@onready var _preview_scope_panel: PanelContainer = %PreviewScopePanel
@onready var _preview_scope_count_label: Label = %PreviewScopeCountLabel
@onready var _preview_scope_sub_label: Label = %PreviewScopeSubLabel
@onready var _preview_rows_vbox: VBoxContainer = %PreviewRowsVBox
@onready var _start_block_hint_label: Label = %StartBlockHintLabel
@onready var _start_button: Button = %StartButton
@onready var _setup_panel: PanelContainer = %SetupPanel
@onready var _preview_panel: PanelContainer = %PreviewPanel

var _source_buttons: Dictionary = {}
var _mod_policy_buttons: Dictionary = {}
var _mod_count_buttons: Dictionary = {}
var _mod_pick_buttons: Dictionary = {}
var _mod_pool_cards: Dictionary = {}
var _gen_mode_policy_buttons: Dictionary = {}
var _gen_mode_checkboxes: Dictionary = {}
var _genre_policy_buttons: Dictionary = {}
var _genre_group_icons: Dictionary = {}
var _instrument_icons: Dictionary = {}
var _preview_rows: Dictionary = {}
var _last_scope_count: int = -1
## Coalesce rapid toggles into one scope scan per frame.
var _preview_sync_queued: bool = false
var _track_filters_panel: VBoxContainer = null
var _track_filter_bodies_container: VBoxContainer = null
var _track_filter_chips_row: HBoxContainer = null
var _track_filter_chips: Dictionary = {}
var _track_filter_bodies: Dictionary = {}
var _active_track_filter: String = ""
var _track_filters_layout_done: bool = false
var _preview_mode_blurb: Label = null
var _chart_style_settings: ChartStyleSettings = null
var _playlist_panel: VBoxContainer = null
var _playlist_summary_label: Label = null
var _playlist_favorites_button: Button = null
var _playlist_pick_button: Button = null
var _playlist_manage_button: Button = null
var _playlist_pick_hint_label: Label = null
var _playlist_ui_ready := false
var _hp_recovery_panel: VBoxContainer = null
var _hp_recovery_slider: HSlider = null
var _hp_recovery_value_label: Label = null
var _hp_recovery_ui_ready := false


func _free_container_children(container: Node) -> void:
	if container == null:
		return
	for child in container.get_children():
		container.remove_child(child)
		child.free()


func _ready() -> void:
	var game_engine := get_parent()
	if game_engine and game_engine.has_method("get_transitions"):
		setup_managers(game_engine.get_transitions())
	_config = _EndlessSessionConfig.default_config()
	if transitions and transitions.has_method("get_staged_endless_session_config"):
		var staged: Dictionary = transitions.get_staged_endless_session_config()
		if not staged.is_empty():
			_config = _EndlessSessionConfig.sanitize(staged)
	elif PlayerDataManager:
		var saved := PlayerDataManager.get_endless_session_last()
		if saved is Dictionary and not saved.is_empty():
			_config = _EndlessSessionConfig.sanitize(saved)
	_notice_overlay = _NoticeOverlayScene.instantiate() as AppNoticeOverlay
	if _notice_overlay:
		add_child(_notice_overlay)
	_apply_panel_styles()
	_ensure_dynamic_ui()
	_setup_random_favorites_check()
	_setup_unique_songs_check()
	_setup_difficulty_sliders()
	_setup_duration_sliders()
	call_deferred("_disable_slider_wheel_scroll")
	_sync_source_selection()
	_sync_random_favorites_visibility()
	_sync_difficulty_ui()
	_sync_duration_ui()
	_ensure_chart_style_settings()
	_sync_chart_style_ui()
	# BaseScreen defers UiInteractionApplier after _ready; re-apply option chip styles
	# so selected chart-style buttons keep accent hover instead of FlatButton blue.
	call_deferred("_sync_chart_style_ui")
	_ensure_hp_recovery_ui()
	_sync_hp_recovery_ui()
	_sync_mod_ui()
	_sync_genre_visibility()
	_sync_playlist_ui()
	_setup_selected_pool_after_option()
	_apply_setup_tooltips()
	_setup_track_filters_layout()
	_setup_preview_mode_blurb()
	_queue_preview_sync()
	if _start_button and not _start_button.pressed.is_connected(_on_start_pressed):
		_start_button.pressed.connect(_on_start_pressed)
	if _selected_tracks_button and not _selected_tracks_button.pressed.is_connected(_on_selected_tracks_pressed):
		_selected_tracks_button.pressed.connect(_on_selected_tracks_pressed)
	if _selected_pool_after_option and not _selected_pool_after_option.item_selected.is_connected(_on_selected_pool_after_changed):
		_selected_pool_after_option.item_selected.connect(_on_selected_pool_after_changed)
	if _back_button and not _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.connect(_on_back_pressed)
	_wire_bulk_action_buttons()
	call_deferred("_sync_ambient_profile")
	call_deferred("_maybe_show_setup_hint")
	call_deferred("_setup_ui_icons")


func _setup_ui_icons() -> void:
	if _start_button:
		var accent := _endless_accent()
		_SongSelectUiStyles.apply_play_button_style(_start_button, accent)
		_UiIconHelper.apply_icon_from_meta(_start_button, 18, accent)
	for bulk_btn in [
		_mod_pool_select_all_button,
		_mod_pool_reset_button,
		_genre_groups_select_all_button,
		_genre_groups_reset_button,
	]:
		if bulk_btn:
			bulk_btn.add_theme_font_size_override("font_size", 15)


func _style_setup_button(btn: Button, min_height: int = 40, font_size: int = 16) -> void:
	if btn == null:
		return
	btn.custom_minimum_size = Vector2(0, min_height)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.set_meta(&"setup_btn_height", min_height)


func _apply_endless_option_button_style(btn: Button, selected: bool) -> void:
	if btn == null:
		return
	_SongSelectUiStyles.apply_option_button_style(btn, selected, _endless_accent())


func _apply_endless_check_row_style(btn: BaseButton) -> void:
	_SongSelectUiStyles.apply_check_row_style(btn)


func _sync_setup_check_row_styles() -> void:
	_apply_endless_check_row_style(_random_favorites_check)
	_apply_endless_check_row_style(_unique_songs_check)
	_apply_endless_check_row_style(_difficulty_max_over_cap_check)
	_apply_endless_check_row_style(_duration_max_open_check)
	for mode_id in _gen_mode_checkboxes.keys():
		_apply_endless_check_row_style(_gen_mode_checkboxes[mode_id] as BaseButton)


func _sync_setup_option_styles() -> void:
	for source_id in _source_buttons.keys():
		var source_btn: Button = _source_buttons[source_id]
		if source_btn:
			_apply_endless_option_button_style(source_btn, source_btn.button_pressed)
	for policy_id in _mod_policy_buttons.keys():
		var mod_btn: Button = _mod_policy_buttons[policy_id]
		if mod_btn:
			_apply_endless_option_button_style(mod_btn, mod_btn.button_pressed)
	for count in _mod_count_buttons.keys():
		var count_btn: Button = _mod_count_buttons[count]
		if count_btn:
			_apply_endless_option_button_style(count_btn, count_btn.button_pressed)
	for strategy_id in _mod_pick_buttons.keys():
		var pick_btn: Button = _mod_pick_buttons[strategy_id]
		if pick_btn:
			_apply_endless_option_button_style(pick_btn, pick_btn.button_pressed)
	for policy_id in _genre_policy_buttons.keys():
		var genre_btn: Button = _genre_policy_buttons[policy_id]
		if genre_btn:
			_apply_endless_option_button_style(genre_btn, genre_btn.button_pressed)
	for policy_id in _gen_mode_policy_buttons.keys():
		var gen_btn: Button = _gen_mode_policy_buttons[policy_id]
		if gen_btn:
			_apply_endless_option_button_style(gen_btn, gen_btn.button_pressed)
	for chip_id in _track_filter_chips.keys():
		var chip: Button = _track_filter_chips[chip_id]
		if chip:
			_apply_endless_option_button_style(chip, str(chip_id) == _active_track_filter)
	_sync_setup_check_row_styles()


func _wire_bulk_action_buttons() -> void:
	if _mod_pool_select_all_button and not _mod_pool_select_all_button.pressed.is_connected(_on_mod_pool_select_all_pressed):
		_mod_pool_select_all_button.pressed.connect(_on_mod_pool_select_all_pressed)
	if _mod_pool_reset_button and not _mod_pool_reset_button.pressed.is_connected(_on_mod_pool_reset_pressed):
		_mod_pool_reset_button.pressed.connect(_on_mod_pool_reset_pressed)
	if _genre_groups_select_all_button and not _genre_groups_select_all_button.pressed.is_connected(_on_genre_groups_select_all_pressed):
		_genre_groups_select_all_button.pressed.connect(_on_genre_groups_select_all_pressed)
	if _genre_groups_reset_button and not _genre_groups_reset_button.pressed.is_connected(_on_genre_groups_reset_pressed):
		_genre_groups_reset_button.pressed.connect(_on_genre_groups_reset_pressed)


func _on_mod_pool_select_all_pressed() -> void:
	var pool: Array = []
	for mod_id in _EndlessSessionConfig.session_mod_pool_candidates():
		var sid := str(mod_id)
		if not pool.has(sid):
			pool.append(sid)
	_config["mod_pool"] = pool
	_sync_mod_pool_selection()
	_sync_mod_pool_count_label()
	_queue_preview_sync()
	MusicManager.play_modifier_select_sound()


func _on_mod_pool_reset_pressed() -> void:
	_config["mod_pool"] = _EndlessSessionConfig.default_mod_pool()
	_sync_mod_pool_selection()
	_sync_mod_pool_count_label()
	_queue_preview_sync()
	MusicManager.play_modifier_deselect_sound()


func _on_genre_groups_select_all_pressed() -> void:
	_config["genre_group_ids"] = _ProfileGenrePortrait.all_group_ids()
	_sync_genre_group_icons()
	_queue_preview_sync()
	MusicManager.play_modifier_select_sound()


func _on_genre_groups_reset_pressed() -> void:
	_config["genre_group_ids"] = []
	_sync_genre_group_icons()
	_queue_preview_sync()
	MusicManager.play_modifier_deselect_sound()


func _apply_panel_styles() -> void:
	var card_style := _SongSelectUiStyles.card_panel_style()
	var accent := _endless_accent()
	if _setup_panel:
		var setup_style := card_style.duplicate() as StyleBoxFlat
		# Clearer card vs ambient wash: lighter surface + stronger edge + deeper shadow.
		setup_style.bg_color = Color(0.13, 0.125, 0.18, 0.97)
		setup_style.border_color = Color(accent.r, accent.g, accent.b, 0.22)
		setup_style.set_border_width_all(1)
		setup_style.shadow_color = Color(0, 0, 0, 0.45)
		setup_style.shadow_size = 14
		setup_style.shadow_offset = Vector2(0, 5)
		_setup_panel.add_theme_stylebox_override("panel", setup_style)
	if _preview_panel:
		var preview_style := card_style.duplicate() as StyleBoxFlat
		preview_style.bg_color = Color(0.12, 0.12, 0.17, 0.97)
		preview_style.border_color = accent.lerp(Color.WHITE, 0.22)
		preview_style.shadow_color = Color(0, 0, 0, 0.42)
		preview_style.shadow_size = 12
		preview_style.shadow_offset = Vector2(0, 4)
		_preview_panel.add_theme_stylebox_override("panel", preview_style)
	if _mod_pool_panel:
		var pool_style := card_style.duplicate() as StyleBoxFlat
		pool_style.bg_color = Color(0.09, 0.09, 0.13, 0.88)
		pool_style.border_color = Color(1, 1, 1, 0.12)
		pool_style.content_margin_left = 12.0
		pool_style.content_margin_top = 10.0
		pool_style.content_margin_right = 12.0
		pool_style.content_margin_bottom = 10.0
		_mod_pool_panel.add_theme_stylebox_override("panel", pool_style)
	if _gen_mode_checks_panel:
		var gen_style := card_style.duplicate() as StyleBoxFlat
		gen_style.bg_color = Color(0.09, 0.09, 0.13, 0.88)
		gen_style.border_color = Color(1, 1, 1, 0.12)
		gen_style.content_margin_left = 12.0
		gen_style.content_margin_top = 8.0
		gen_style.content_margin_right = 12.0
		gen_style.content_margin_bottom = 8.0
		_gen_mode_checks_panel.add_theme_stylebox_override("panel", gen_style)
	if _preview_scope_panel:
		var scope_style := card_style.duplicate() as StyleBoxFlat
		scope_style.bg_color = Color(0.11, 0.11, 0.17, 0.92)
		scope_style.border_color = accent.lerp(Color.WHITE, 0.14)
		scope_style.content_margin_left = 0.0
		scope_style.content_margin_top = 0.0
		scope_style.content_margin_right = 0.0
		scope_style.content_margin_bottom = 0.0
		_preview_scope_panel.add_theme_stylebox_override("panel", scope_style)
	_style_section_titles()
	for divider in [_mods_section_divider, _gen_section_divider]:
		if divider:
			divider.add_theme_constant_override("separation", 8)


func _style_section_titles() -> void:
	var accent := _endless_accent()
	var title_color := accent.lerp(Color(0.86, 0.88, 0.96, 1.0), 0.55)
	for label in [_tracks_section_title, _modifiers_section_title, _generation_section_title]:
		if label == null:
			continue
		label.add_theme_color_override("font_color", title_color)
		label.add_theme_font_size_override("font_size", 16)


func _ensure_dynamic_ui() -> void:
	if _source_buttons.is_empty():
		_build_source_buttons()
	if _mod_policy_buttons.is_empty():
		_build_mod_policy_buttons()
	if _mod_pool_cards.is_empty():
		_build_mod_pool_cards()
	if _mod_count_buttons.is_empty():
		_build_mod_count_buttons()
	if _mod_pick_buttons.is_empty():
		_build_mod_pick_buttons()
	if _chart_style_settings == null:
		_ensure_chart_style_settings()
	if not _playlist_ui_ready:
		_ensure_playlist_ui()
	if _genre_policy_buttons.is_empty():
		_build_genre_policy_buttons()
	if _genre_group_icons.is_empty():
		_build_genre_group_icons()
	if _instrument_icons.is_empty():
		_build_instrument_icons()
	if _preview_rows.is_empty():
		_build_preview_rows()


func _update_dynamic_ui_labels() -> void:
	var source_specs: Array = [
		{
			"id": _EndlessSessionConfig.TRACK_SOURCE_RANDOM,
			"key": "SESSION_SETUP_SOURCE_LIBRARY",
			"desc": "SESSION_SETUP_SOURCE_LIBRARY_DESC",
			"locked": false,
		},
		{
			"id": _EndlessSessionConfig.TRACK_SOURCE_GENRE,
			"key": "SESSION_SETUP_SOURCE_GENRE",
			"desc": "SESSION_SETUP_SOURCE_GENRE_DESC",
			"locked": false,
		},
		{
			"id": _EndlessSessionConfig.TRACK_SOURCE_PLAYLIST,
			"key": "SESSION_SETUP_SOURCE_PLAYLISTS",
			"desc": "SESSION_SETUP_SOURCE_PLAYLISTS_DESC",
			"locked": false,
		},
		{
			"id": _EndlessSessionConfig.TRACK_SOURCE_SELECTED,
			"key": "SESSION_SETUP_SOURCE_SELECTED",
			"desc": "SESSION_SETUP_SOURCE_SELECTED_DESC",
			"locked": false,
		},
	]
	for spec in source_specs:
		var source_id := str(spec.get("id", ""))
		var btn: Button = _source_buttons.get(source_id, null)
		if btn == null:
			continue
		btn.text = tr(str(spec.get("key", "")))
		if bool(spec.get("locked", false)):
			btn.tooltip_text = "%s — %s" % [tr("GEN_SOON"), tr(str(spec.get("desc", "")))]
		else:
			btn.tooltip_text = tr(str(spec.get("desc", "")))
	var policy_specs: Array = [
		{"id": _EndlessSessionConfig.MOD_POLICY_NONE, "key": "SESSION_SETUP_MOD_POLICY_NONE"},
		{"id": _EndlessSessionConfig.MOD_POLICY_RANDOM_POOL, "key": "SESSION_SETUP_MOD_POLICY_RANDOM"},
		{"id": _EndlessSessionConfig.MOD_POLICY_FIXED, "key": "SESSION_SETUP_MOD_POLICY_FIXED"},
	]
	for spec in policy_specs:
		var policy_id := str(spec.get("id", ""))
		var btn: Button = _mod_policy_buttons.get(policy_id, null)
		if btn == null:
			continue
		btn.text = tr(str(spec.get("key", "")))
		if policy_id == _EndlessSessionConfig.MOD_POLICY_FIXED:
			btn.tooltip_text = tr("SESSION_SETUP_MOD_POLICY_FIXED_HINT")
	if _mod_count_caption:
		_mod_count_caption.text = tr("SESSION_SETUP_MOD_COUNT")
	if _mod_pick_caption:
		_mod_pick_caption.text = tr("SESSION_SETUP_MOD_PICK_CAPTION")
	if _chart_style_settings:
		_chart_style_settings.apply_locale()
	var genre_policy_specs: Array = [
		{"id": _EndlessSessionConfig.GENRE_POLICY_ALL, "key": "SESSION_SETUP_GENRE_ALL"},
		{"id": _EndlessSessionConfig.GENRE_POLICY_GROUPS, "key": "SESSION_SETUP_GENRE_GROUPS"},
	]
	for spec in genre_policy_specs:
		var policy_id := str(spec.get("id", ""))
		var btn: Button = _genre_policy_buttons.get(policy_id, null)
		if btn:
			btn.text = tr(str(spec.get("key", "")))
	for icon in _mod_pool_cards.values():
		if icon and icon.has_method("refresh_locale"):
			icon.refresh_locale()
	for icon in _genre_group_icons.values():
		if icon and icon.has_method("refresh_locale"):
			icon.refresh_locale()
	for icon in _instrument_icons.values():
		if icon and icon.has_method("refresh_locale"):
			icon.refresh_locale()


func _build_source_buttons() -> void:
	if _source_cards_row == null:
		return
	_free_container_children(_source_cards_row)
	_source_buttons.clear()
	_source_group = ButtonGroup.new()
	_source_group.allow_unpress = false
	var specs: Array = [
		{
			"id": _EndlessSessionConfig.TRACK_SOURCE_RANDOM,
			"key": "SESSION_SETUP_SOURCE_LIBRARY",
			"desc": "SESSION_SETUP_SOURCE_LIBRARY_DESC",
			"locked": false,
		},
		{
			"id": _EndlessSessionConfig.TRACK_SOURCE_PLAYLIST,
			"key": "SESSION_SETUP_SOURCE_PLAYLISTS",
			"desc": "SESSION_SETUP_SOURCE_PLAYLISTS_DESC",
			"locked": false,
		},
		{
			"id": _EndlessSessionConfig.TRACK_SOURCE_SELECTED,
			"key": "SESSION_SETUP_SOURCE_SELECTED",
			"desc": "SESSION_SETUP_SOURCE_SELECTED_DESC",
			"locked": false,
		},
	]
	for spec in specs:
		var btn := Button.new()
		btn.toggle_mode = true
		btn.button_group = _source_group
		btn.text = tr(str(spec.get("key", "")))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.theme_type_variation = &"FlatButton"
		_style_setup_button(btn, 42, 16)
		var source_id := str(spec.get("id", ""))
		var locked := bool(spec.get("locked", false))
		if locked:
			btn.disabled = true
			btn.tooltip_text = "%s — %s" % [tr("GEN_SOON"), tr(str(spec.get("desc", "")))]
		elif source_id == _EndlessSessionConfig.TRACK_SOURCE_SELECTED:
			btn.tooltip_text = tr("SESSION_SETUP_SOURCE_SELECTED_DESC")
		else:
			btn.tooltip_text = tr(str(spec.get("desc", "")))
		btn.toggled.connect(_on_source_button_toggled.bind(source_id))
		_source_cards_row.add_child(btn)
		_source_buttons[source_id] = btn


func _ensure_chart_style_settings() -> void:
	if _chart_style_settings != null:
		return
	if _generation_section_title == null:
		return
	_chart_style_settings = _ChartStyleSettings.new()
	_chart_style_settings.set_accent_color(_endless_accent())
	_chart_style_settings.set_help_article_id("modes")
	if not _chart_style_settings.settings_changed.is_connected(_on_chart_style_settings_changed):
		_chart_style_settings.settings_changed.connect(_on_chart_style_settings_changed)
	var parent := _generation_section_title.get_parent()
	if parent:
		var idx := _generation_section_title.get_index() + 1
		parent.add_child(_chart_style_settings)
		parent.move_child(_chart_style_settings, idx)
	if _gen_mode_caption:
		_gen_mode_caption.visible = false
	if _gen_mode_policy_row:
		_gen_mode_policy_row.visible = false
	if _gen_mode_checks_panel:
		_gen_mode_checks_panel.visible = false
	_chart_style_settings.set_config(_config)


func _sync_chart_style_ui() -> void:
	if _chart_style_settings == null:
		return
	_chart_style_settings.set_accent_color(_endless_accent())
	_chart_style_settings.set_config(_config)


func _on_chart_style_settings_changed(fragment: Dictionary) -> void:
	for key in fragment.keys():
		_config[key] = fragment[key]
	_queue_preview_sync()
	MusicManager.play_modifier_select_sound()


func _ensure_hp_recovery_ui() -> void:
	if _hp_recovery_ui_ready or _modifiers_section_title == null:
		return
	var parent := _modifiers_section_title.get_parent()
	if parent == null:
		return
	_hp_recovery_panel = VBoxContainer.new()
	_hp_recovery_panel.name = "HpRecoveryPanel"
	_hp_recovery_panel.add_theme_constant_override("separation", 8)
	parent.add_child(_hp_recovery_panel)
	parent.move_child(_hp_recovery_panel, _modifiers_section_title.get_index())

	var caption := Label.new()
	caption.name = "HpRecoveryCaption"
	caption.text = tr("SESSION_SETUP_HP_RECOVERY")
	caption.add_theme_font_size_override("font_size", 14)
	caption.add_theme_color_override("font_color", Color(0.72, 0.8, 0.92, 0.95))
	caption.tooltip_text = tr("SESSION_SETUP_HP_RECOVERY_HINT")
	_hp_recovery_panel.add_child(caption)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_hp_recovery_panel.add_child(row)

	_hp_recovery_slider = HSlider.new()
	_hp_recovery_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_recovery_slider.min_value = 0.0
	_hp_recovery_slider.max_value = float(_EndlessSessionConfig.INTER_TRACK_HP_RECOVERY_OPTIONS.size() - 1)
	_hp_recovery_slider.step = 1.0
	_hp_recovery_slider.tick_count = _EndlessSessionConfig.INTER_TRACK_HP_RECOVERY_OPTIONS.size()
	_hp_recovery_slider.custom_minimum_size = Vector2(0, 36)
	if not _hp_recovery_slider.value_changed.is_connected(_on_hp_recovery_slider_changed):
		_hp_recovery_slider.value_changed.connect(_on_hp_recovery_slider_changed)
	row.add_child(_hp_recovery_slider)
	_SliderScrollUtils.disable_wheel_on_slider(_hp_recovery_slider)

	_hp_recovery_value_label = Label.new()
	_hp_recovery_value_label.custom_minimum_size = Vector2(52, 0)
	_hp_recovery_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hp_recovery_value_label.add_theme_font_size_override("font_size", 15)
	_hp_recovery_value_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.98, 1.0))
	row.add_child(_hp_recovery_value_label)

	_hp_recovery_ui_ready = true
	_sync_hp_recovery_ui()


func _sync_hp_recovery_ui() -> void:
	if not _hp_recovery_ui_ready or _hp_recovery_slider == null:
		return
	var pct := _EndlessSessionConfig.normalize_inter_track_hp_recovery_pct(
		_config.get("inter_track_hp_recovery_pct", _EndlessSessionConfig.DEFAULT_INTER_TRACK_HP_RECOVERY_PCT)
	)
	var idx := _EndlessSessionConfig.INTER_TRACK_HP_RECOVERY_OPTIONS.find(pct)
	if idx < 0:
		idx = _EndlessSessionConfig.INTER_TRACK_HP_RECOVERY_OPTIONS.size() - 1
	if not is_equal_approx(_hp_recovery_slider.value, float(idx)):
		_hp_recovery_slider.set_value_no_signal(float(idx))
	if _hp_recovery_value_label:
		_hp_recovery_value_label.text = _EndlessSessionConfig.format_inter_track_hp_recovery_pct(pct)


func _on_hp_recovery_slider_changed(value: float) -> void:
	var idx := clampi(int(round(value)), 0, _EndlessSessionConfig.INTER_TRACK_HP_RECOVERY_OPTIONS.size() - 1)
	_config["inter_track_hp_recovery_pct"] = _EndlessSessionConfig.INTER_TRACK_HP_RECOVERY_OPTIONS[idx]
	_sync_hp_recovery_ui()
	_queue_preview_sync()
	MusicManager.play_modifier_select_sound()


func _ensure_playlist_ui() -> void:
	if _playlist_ui_ready:
		return
	if _selected_pool_after_panel == null:
		return
	var parent := _selected_pool_after_panel.get_parent()
	if parent == null:
		return
	_playlist_panel = VBoxContainer.new()
	_playlist_panel.name = "PlaylistPanel"
	_playlist_panel.visible = false
	_playlist_panel.add_theme_constant_override("separation", 8)
	parent.add_child(_playlist_panel)
	parent.move_child(_playlist_panel, _selected_pool_after_panel.get_index() + 1)

	var caption := Label.new()
	caption.text = tr("SESSION_SETUP_PLAYLIST_CAPTION")
	caption.add_theme_font_size_override("font_size", 14)
	caption.add_theme_color_override("font_color", Color(0.72, 0.8, 0.92, 0.95))
	_playlist_panel.add_child(caption)

	_playlist_summary_label = Label.new()
	_playlist_summary_label.add_theme_font_size_override("font_size", 15)
	_playlist_summary_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.98, 1.0))
	_playlist_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_playlist_panel.add_child(_playlist_summary_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_playlist_panel.add_child(row)

	_playlist_favorites_button = Button.new()
	_playlist_favorites_button.text = tr("PLAYLIST_FAVORITES_TITLE")
	_playlist_favorites_button.custom_minimum_size = Vector2(0, 40)
	_playlist_favorites_button.theme_type_variation = &"FlatButton"
	_style_setup_button(_playlist_favorites_button, 40, 15)
	if not _playlist_favorites_button.pressed.is_connected(_on_playlist_favorites_pressed):
		_playlist_favorites_button.pressed.connect(_on_playlist_favorites_pressed)
	row.add_child(_playlist_favorites_button)

	_playlist_pick_button = Button.new()
	_playlist_pick_button.text = tr("SESSION_SETUP_PLAYLIST_PICK")
	_playlist_pick_button.custom_minimum_size = Vector2(0, 40)
	_playlist_pick_button.theme_type_variation = &"FlatButton"
	_style_setup_button(_playlist_pick_button, 40, 15)
	if not _playlist_pick_button.pressed.is_connected(_on_playlist_pick_pressed):
		_playlist_pick_button.pressed.connect(_on_playlist_pick_pressed)
	row.add_child(_playlist_pick_button)

	_playlist_manage_button = Button.new()
	_playlist_manage_button.text = tr("SESSION_SETUP_PLAYLIST_MANAGE")
	_playlist_manage_button.custom_minimum_size = Vector2(0, 40)
	_playlist_manage_button.theme_type_variation = &"FlatButton"
	_style_setup_button(_playlist_manage_button, 40, 15)
	if not _playlist_manage_button.pressed.is_connected(_on_playlist_manage_pressed):
		_playlist_manage_button.pressed.connect(_on_playlist_manage_pressed)
	row.add_child(_playlist_manage_button)

	_playlist_pick_hint_label = Label.new()
	_playlist_pick_hint_label.text = tr("SESSION_SETUP_PLAYLIST_PICK_HINT")
	_playlist_pick_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_playlist_pick_hint_label.add_theme_font_size_override("font_size", 13)
	_playlist_pick_hint_label.add_theme_color_override("font_color", Color(0.58, 0.66, 0.78, 0.92))
	_playlist_panel.add_child(_playlist_pick_hint_label)

	_playlist_ui_ready = true
	_sync_playlist_ui()


func _sync_playlist_ui() -> void:
	if not _playlist_ui_ready:
		return
	var is_playlist := (
		str(_config.get("track_source", "")) == _EndlessSessionConfig.TRACK_SOURCE_PLAYLIST
	)
	if _playlist_panel:
		_playlist_panel.visible = is_playlist
	if not is_playlist:
		return
	var playlist_id := str(_config.get("playlist_id", _PlaylistCatalog.BUILTIN_FAVORITES_ID)).strip_edges()
	if _playlist_summary_label:
		const PlaylistStats = preload("res://logic/domain/library/playlist_stats.gd")
		var stats := PlaylistStats.compute_stats(playlist_id)
		_playlist_summary_label.text = tr("SESSION_SETUP_PLAYLIST_SUMMARY_FMT") % [
			_PlaylistCatalog.display_name(playlist_id),
			int(stats.get("track_count", 0)),
			PlaylistStats.format_duration(float(stats.get("duration_sec", 0.0))),
			PlaylistStats.format_avg_rating(float(stats.get("avg_rating", 0.0))),
		]
	if _playlist_favorites_button:
		var is_fav := playlist_id == _PlaylistCatalog.BUILTIN_FAVORITES_ID
		_SongSelectUiStyles.apply_option_button_style(
			_playlist_favorites_button,
			is_fav,
			_UiIconHelper.ACCENT,
		)


func _on_playlist_favorites_pressed() -> void:
	_config["playlist_id"] = _PlaylistCatalog.BUILTIN_FAVORITES_ID
	_config["track_source"] = _EndlessSessionConfig.TRACK_SOURCE_PLAYLIST
	_sync_playlist_ui()
	_queue_preview_sync()
	MusicManager.play_modifier_select_sound()


func _on_playlist_pick_pressed() -> void:
	if transitions and transitions.has_method("open_playlist_hub_from_session_setup"):
		transitions.open_playlist_hub_from_session_setup(_EndlessSessionConfig.sanitize(_config), true)


func _on_playlist_manage_pressed() -> void:
	if transitions and transitions.has_method("open_playlist_hub_from_session_setup"):
		transitions.open_playlist_hub_from_session_setup(_EndlessSessionConfig.sanitize(_config), false)


func _build_instrument_icons() -> void:
	if _instruments_row == null:
		return
	_free_container_children(_instruments_row)
	_instrument_icons.clear()
	for spec in [
		{"id": "drums", "locked": false},
		{"id": "bass", "locked": false},
	]:
		var icon := _InstrumentIconScript.new()
		icon.setup(str(spec.get("id", "")), bool(spec.get("locked", false)))
		if not icon.pool_toggled.is_connected(_on_instrument_pool_toggled):
			icon.pool_toggled.connect(_on_instrument_pool_toggled)
		_instruments_row.add_child(icon)
		_instrument_icons[str(spec.get("id", ""))] = icon
	_sync_instrument_icons()


func _on_instrument_pool_toggled(instrument_id: String, pressed: bool) -> void:
	if instrument_id not in ["drums", "bass"]:
		return
	var pool: Array = _EndlessSessionConfig.sanitize_instruments(
		_config.get("instruments", [_config.get("instrument", _EndlessSessionConfig.DEFAULT_INSTRUMENT)])
	)
	if pressed:
		if not pool.has(instrument_id):
			pool.append(instrument_id)
	else:
		if pool.size() <= 1:
			_sync_instrument_icons()
			if MusicManager.has_method("play_cancel_sound"):
				MusicManager.play_cancel_sound()
			else:
				MusicManager.play_modifier_deselect_sound()
			return
		pool.erase(instrument_id)
	_config["instruments"] = pool
	_config["instrument"] = str(pool[0])
	_sync_instrument_icons()
	_queue_preview_sync()
	if pressed:
		MusicManager.play_modifier_select_sound()
	else:
		MusicManager.play_modifier_deselect_sound()


func _sync_instrument_icons() -> void:
	var pool: Array = _EndlessSessionConfig.sanitize_instruments(
		_config.get("instruments", [_config.get("instrument", _EndlessSessionConfig.DEFAULT_INSTRUMENT)])
	)
	_config["instruments"] = pool
	_config["instrument"] = str(pool[0])
	for inst_id in _instrument_icons.keys():
		var icon: SessionInstrumentIcon = _instrument_icons[inst_id]
		if icon:
			icon.set_pool_selected(pool.has(str(inst_id)))


func _build_genre_policy_buttons() -> void:
	if _genre_policy_row == null:
		return
	_free_container_children(_genre_policy_row)
	_genre_policy_buttons.clear()
	_genre_policy_group = ButtonGroup.new()
	_genre_policy_group.allow_unpress = false
	var specs: Array = [
		{"id": _EndlessSessionConfig.GENRE_POLICY_ALL, "key": "SESSION_SETUP_GENRE_ALL"},
		{"id": _EndlessSessionConfig.GENRE_POLICY_GROUPS, "key": "SESSION_SETUP_GENRE_GROUPS"},
	]
	for spec in specs:
		var btn := Button.new()
		btn.toggle_mode = true
		btn.button_group = _genre_policy_group
		btn.text = tr(str(spec.get("key", "")))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.theme_type_variation = &"FlatButton"
		_style_setup_button(btn, 38, 16)
		var policy_id := str(spec.get("id", ""))
		btn.toggled.connect(_on_genre_policy_toggled.bind(policy_id))
		_genre_policy_row.add_child(btn)
		_genre_policy_buttons[policy_id] = btn


func _on_genre_policy_toggled(on: bool, policy_id: String) -> void:
	if not on:
		return
	_config["genre_policy"] = policy_id
	if policy_id == _EndlessSessionConfig.GENRE_POLICY_ALL:
		_config["genre_group_ids"] = []
	_sync_genre_policy_buttons()
	_sync_genre_group_icons()
	_sync_genre_visibility()
	_queue_preview_sync()
	MusicManager.play_modifier_select_sound()


func _sync_genre_policy_buttons() -> void:
	var policy := str(_config.get("genre_policy", _EndlessSessionConfig.GENRE_POLICY_ALL))
	for policy_id in _genre_policy_buttons.keys():
		var btn: Button = _genre_policy_buttons[policy_id]
		if btn:
			btn.set_block_signals(true)
			btn.button_pressed = str(policy_id) == policy
			btn.set_block_signals(false)


func _build_genre_group_icons() -> void:
	if _genre_groups_flow == null:
		return
	_free_container_children(_genre_groups_flow)
	_genre_group_icons.clear()
	if _genre_groups_panel:
		var group_style := _SongSelectUiStyles.card_panel_style().duplicate() as StyleBoxFlat
		group_style.bg_color = Color(0.09, 0.1, 0.14, 0.72)
		group_style.border_color = Color(1, 1, 1, 0.08)
		group_style.content_margin_left = 12.0
		group_style.content_margin_top = 8.0
		group_style.content_margin_right = 12.0
		group_style.content_margin_bottom = 8.0
		_genre_groups_panel.add_theme_stylebox_override("panel", group_style)
	for group_id in _ProfileGenrePortrait.all_group_ids():
		var icon := _GenreGroupIconScript.new()
		icon.setup(group_id)
		if not icon.group_toggled.is_connected(_on_genre_group_toggled):
			icon.group_toggled.connect(_on_genre_group_toggled)
		_genre_groups_flow.add_child(icon)
		_genre_group_icons[group_id] = icon
	_sync_genre_group_icons()


func _on_genre_group_toggled(group_id: String, pressed: bool) -> void:
	var allowed: Array = (_config.get("genre_group_ids", []) as Array).duplicate()
	var gid := str(group_id)
	if pressed:
		if not allowed.has(gid):
			allowed.append(gid)
	else:
		allowed.erase(gid)
	_config["genre_group_ids"] = allowed
	_sync_genre_group_icons()
	_queue_preview_sync()
	if pressed:
		MusicManager.play_modifier_select_sound()
	else:
		MusicManager.play_modifier_deselect_sound()


func _sync_genre_group_icons() -> void:
	var allowed: Array = _config.get("genre_group_ids", [])
	for group_id in _genre_group_icons.keys():
		var icon: SessionGenreGroupIcon = _genre_group_icons[group_id]
		if icon:
			icon.set_group_selected(allowed.has(str(group_id)))
	_sync_genre_groups_count_label()


func _build_preview_rows() -> void:
	if _preview_rows_vbox == null:
		return
	_free_container_children(_preview_rows_vbox)
	_preview_rows.clear()
	var accent := _endless_accent()
	var specs: Array = [
		{"id": "source", "icon": "shuffle.svg", "tint": accent},
		{"id": "favorites", "icon": "star.svg", "tint": accent},
		{"id": "unique", "icon": "repeat.svg", "tint": accent},
		{"id": "instrument", "icon": "drum.svg", "tint": _GenPresetUi.INSTRUMENT_ICON_COLORS.get("drums", accent)},
		{"id": "genre", "icon": "tags.svg", "tint": accent},
		{"id": "playlist", "icon": "layers.svg", "tint": accent},
		{"id": "tracks", "icon": "music.svg", "tint": accent},
		{"id": "difficulty", "icon": "star.svg", "tint": accent},
		{"id": "duration", "icon": "clock.svg", "tint": accent},
		{"id": "gen_modes", "icon": "settings-2.svg", "tint": accent},
		{"id": "hp_recovery", "icon": "heart-pulse.svg", "tint": accent},
		{"id": "mods", "icon": "zap.svg", "tint": accent},
		{"id": "scope", "icon": "list-checks.svg", "tint": accent},
	]
	for spec in specs:
		var row := _PreviewRowScript.new()
		row.setup(str(spec.get("icon", "info.svg")), "", spec.get("tint", accent) as Color)
		_preview_rows_vbox.add_child(row)
		_preview_rows[str(spec.get("id", ""))] = row


func _set_preview_row(row_id: String, text: String, visible_row: bool = true, tone: String = "normal") -> void:
	var row: SessionSetupPreviewRow = _preview_rows.get(row_id, null)
	if row == null:
		return
	row.visible = visible_row
	if visible_row:
		row.set_text(text)
		row.set_tone(tone)


func _sync_genre_groups_count_label() -> void:
	if _genre_groups_count_label == null:
		return
	var allowed: Array = _config.get("genre_group_ids", [])
	var total := _ProfileGenrePortrait.all_group_ids().size()
	_genre_groups_count_label.text = tr("SESSION_SETUP_GENRE_GROUPS_COUNT_FMT") % [
		allowed.size(),
		total,
	]


func _sync_scope_hero(scope_count: int, scope_ok: bool) -> void:
	if _preview_scope_count_label:
		_preview_scope_count_label.text = str(scope_count)
		var count_color := _endless_accent() if scope_ok else Color(0.95, 0.48, 0.52, 1.0)
		if scope_ok and scope_count <= 5:
			count_color = Color(0.95, 0.78, 0.42, 1.0)
		_preview_scope_count_label.add_theme_color_override("font_color", count_color)
	if _preview_scope_sub_label:
		_preview_scope_sub_label.text = tr("SESSION_SETUP_PREVIEW_SCOPE_HERO_SUB")
	if _preview_scope_panel:
		var panel_style := _preview_scope_panel.get_theme_stylebox("panel") as StyleBoxFlat
		if panel_style:
			var accent := _endless_accent()
			panel_style.border_color = accent.lerp(Color.WHITE, 0.12) if scope_ok else Color(0.95, 0.48, 0.52, 0.35)
	_last_scope_count = scope_count


func _sync_start_button_state(
	fav_ok: bool,
	mods_ok: bool,
	scope_ok: bool,
	genre_ok: bool,
	selected_ok: bool,
	favorites_only: bool,
	fav_count: int,
	selected_count: int,
	genre_groups: Array,
	pool: Array
) -> void:
	if _start_button == null:
		return
	var enabled := fav_ok and mods_ok and scope_ok and genre_ok and selected_ok
	_start_button.disabled = not enabled
	_start_button.modulate = Color.WHITE if enabled else Color(0.58, 0.62, 0.72, 0.72)
	var reasons := _start_block_reasons(
		fav_ok, mods_ok, scope_ok, genre_ok, selected_ok, favorites_only, fav_count, selected_count, genre_groups, pool
	)
	if _start_block_hint_label:
		if enabled:
			_start_block_hint_label.visible = false
			_start_block_hint_label.text = ""
		else:
			_start_block_hint_label.visible = true
			_start_block_hint_label.text = tr("SESSION_SETUP_START_BLOCK_HINT") + "\n" + "\n".join(reasons)
	if enabled:
		_start_button.tooltip_text = ""
	else:
		_start_button.tooltip_text = "\n".join(reasons)


func _start_block_reasons(
	fav_ok: bool,
	mods_ok: bool,
	scope_ok: bool,
	genre_ok: bool,
	selected_ok: bool,
	favorites_only: bool,
	fav_count: int,
	selected_count: int,
	genre_groups: Array,
	pool: Array
) -> PackedStringArray:
	var reasons: PackedStringArray = []
	if not fav_ok and favorites_only:
		reasons.append(tr("SESSION_SETUP_START_BLOCK_FAVORITES") % fav_count)
	if not scope_ok:
		reasons.append(tr("SESSION_SETUP_START_BLOCK_SCOPE"))
	if not genre_ok:
		reasons.append(tr("SESSION_SETUP_START_BLOCK_GENRE") % genre_groups.size())
	if not mods_ok:
		reasons.append(tr("SESSION_SETUP_START_BLOCK_MODS") % pool.size())
	if not selected_ok:
		reasons.append(
			tr("SESSION_SETUP_START_BLOCK_TRACKS") % [
				_EndlessSessionConfig.SELECTED_TRACK_PICKER_MIN,
				selected_count,
			]
		)
	return reasons


func _setup_unique_songs_check() -> void:
	if _unique_songs_check == null:
		return
	_unique_songs_check.button_pressed = bool(_config.get("unique_songs_only", false))
	_apply_endless_check_row_style(_unique_songs_check)
	if not _unique_songs_check.toggled.is_connected(_on_unique_songs_toggled):
		_unique_songs_check.toggled.connect(_on_unique_songs_toggled)


func _on_unique_songs_toggled(on: bool) -> void:
	_config["unique_songs_only"] = on
	_queue_preview_sync()


func _setup_random_favorites_check() -> void:
	if _random_favorites_check == null:
		return
	_random_favorites_check.button_pressed = bool(_config.get("random_favorites_only", false))
	_apply_endless_check_row_style(_random_favorites_check)
	if not _random_favorites_check.toggled.is_connected(_on_random_favorites_toggled):
		_random_favorites_check.toggled.connect(_on_random_favorites_toggled)


func _on_random_favorites_toggled(on: bool) -> void:
	_config["random_favorites_only"] = on
	_queue_preview_sync()


func _setup_difficulty_sliders() -> void:
	var cfg := _EndlessSessionConfig
	for slider in [_difficulty_min_slider, _difficulty_max_slider]:
		if slider == null:
			continue
		slider.min_value = cfg.DIFFICULTY_BASE_MIN
		slider.max_value = cfg.DIFFICULTY_BASE_MAX
		slider.step = cfg.DIFFICULTY_STEP
	if _difficulty_min_slider:
		_difficulty_min_slider.value = float(_config.get("difficulty_min", cfg.DEFAULT_DIFFICULTY_MIN))
		if not _difficulty_min_slider.value_changed.is_connected(_on_difficulty_min_changed):
			_difficulty_min_slider.value_changed.connect(_on_difficulty_min_changed)
		_wire_slider_double_click_reset(_difficulty_min_slider, "_reset_difficulty_min_to_default")
	if _difficulty_max_slider:
		_difficulty_max_slider.value = float(_config.get("difficulty_max", cfg.DEFAULT_DIFFICULTY_MAX))
		if not _difficulty_max_slider.value_changed.is_connected(_on_difficulty_max_changed):
			_difficulty_max_slider.value_changed.connect(_on_difficulty_max_changed)
		_wire_slider_double_click_reset(_difficulty_max_slider, "_reset_difficulty_max_to_default")
	if _difficulty_max_over_cap_check:
		_difficulty_max_over_cap_check.button_pressed = bool(_config.get("difficulty_max_over_cap", false))
		_apply_endless_check_row_style(_difficulty_max_over_cap_check)
		if not _difficulty_max_over_cap_check.toggled.is_connected(_on_difficulty_max_over_cap_toggled):
			_difficulty_max_over_cap_check.toggled.connect(_on_difficulty_max_over_cap_toggled)


func _setup_duration_sliders() -> void:
	var cfg := _EndlessSessionConfig
	for slider in [_duration_min_slider, _duration_max_slider]:
		if slider == null:
			continue
		slider.min_value = cfg.DURATION_SLIDER_MIN_SEC
		slider.max_value = cfg.DURATION_SLIDER_MAX_SEC
		slider.step = cfg.DURATION_STEP_SEC
	if _duration_min_slider:
		_duration_min_slider.value = float(_config.get("duration_min_sec", cfg.DEFAULT_DURATION_MIN_SEC))
		if not _duration_min_slider.value_changed.is_connected(_on_duration_min_changed):
			_duration_min_slider.value_changed.connect(_on_duration_min_changed)
		_wire_slider_double_click_reset(_duration_min_slider, "_reset_duration_min_to_default")
	if _duration_max_slider:
		_duration_max_slider.value = float(_config.get("duration_max_sec", cfg.DEFAULT_DURATION_MAX_SEC))
		if not _duration_max_slider.value_changed.is_connected(_on_duration_max_changed):
			_duration_max_slider.value_changed.connect(_on_duration_max_changed)
		_wire_slider_double_click_reset(_duration_max_slider, "_reset_duration_max_to_default")
	if _duration_max_open_check:
		_duration_max_open_check.button_pressed = bool(_config.get("duration_max_open", false))
		_apply_endless_check_row_style(_duration_max_open_check)
		if not _duration_max_open_check.toggled.is_connected(_on_duration_max_open_toggled):
			_duration_max_open_check.toggled.connect(_on_duration_max_open_toggled)


func _wire_slider_double_click_reset(slider: HSlider, reset_method: String) -> void:
	if slider == null or reset_method.strip_edges() == "":
		return
	var bound := _on_setup_slider_gui_input.bind(reset_method)
	if not slider.gui_input.is_connected(bound):
		slider.gui_input.connect(bound)


func _disable_slider_wheel_scroll() -> void:
	_SliderScrollUtils.disable_wheel_under(self)


func _on_setup_slider_gui_input(event: InputEvent, reset_method: String) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.double_click):
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if has_method(reset_method):
		call(reset_method)
	accept_event()


func _reset_difficulty_min_to_default() -> void:
	_on_difficulty_min_changed(_EndlessSessionConfig.DEFAULT_DIFFICULTY_MIN)


func _reset_difficulty_max_to_default() -> void:
	_config["difficulty_max_over_cap"] = false
	_on_difficulty_max_changed(_EndlessSessionConfig.DEFAULT_DIFFICULTY_MAX)


func _reset_duration_min_to_default() -> void:
	_on_duration_min_changed(float(_EndlessSessionConfig.DEFAULT_DURATION_MIN_SEC))


func _reset_duration_max_to_default() -> void:
	_config["duration_max_open"] = false
	_on_duration_max_changed(float(_EndlessSessionConfig.DEFAULT_DURATION_MAX_SEC))


func _on_duration_min_changed(value: float) -> void:
	_config["duration_min_sec"] = int(round(value))
	if int(_config.get("duration_max_sec", value)) < int(value):
		_config["duration_max_sec"] = int(round(value))
		if _duration_max_slider:
			_duration_max_slider.set_value_no_signal(value)
	_sync_duration_ui()
	_queue_preview_sync()


func _on_duration_max_changed(value: float) -> void:
	_config["duration_max_sec"] = int(round(value))
	if int(_config.get("duration_min_sec", value)) > int(value):
		_config["duration_min_sec"] = int(round(value))
		if _duration_min_slider:
			_duration_min_slider.set_value_no_signal(value)
	if value < _EndlessSessionConfig.DURATION_SLIDER_MAX_SEC:
		_config["duration_max_open"] = false
	_sync_duration_ui()
	_queue_preview_sync()


func _on_duration_max_open_toggled(on: bool) -> void:
	_config["duration_max_open"] = on
	if on and _duration_max_slider:
		_config["duration_max_sec"] = _EndlessSessionConfig.DURATION_SLIDER_MAX_SEC
		_duration_max_slider.set_value_no_signal(_EndlessSessionConfig.DURATION_SLIDER_MAX_SEC)
	_sync_duration_ui()
	_queue_preview_sync()


func _sync_duration_ui() -> void:
	_config = _EndlessSessionConfig.sanitize(_config)
	var dmin := int(_config.get("duration_min_sec", _EndlessSessionConfig.DEFAULT_DURATION_MIN_SEC))
	var dmax := int(_config.get("duration_max_sec", _EndlessSessionConfig.DEFAULT_DURATION_MAX_SEC))
	var max_open := bool(_config.get("duration_max_open", false))
	if _duration_min_slider and not is_equal_approx(_duration_min_slider.value, float(dmin)):
		_duration_min_slider.set_value_no_signal(float(dmin))
	if _duration_max_slider and not is_equal_approx(_duration_max_slider.value, float(dmax)):
		_duration_max_slider.set_value_no_signal(float(dmax))
	if _duration_max_open_check:
		var can_open := dmax >= _EndlessSessionConfig.DURATION_SLIDER_MAX_SEC
		_duration_max_open_check.visible = can_open
		_duration_max_open_check.disabled = not can_open
		if _duration_max_open_check.button_pressed != max_open:
			_duration_max_open_check.set_block_signals(true)
			_duration_max_open_check.button_pressed = max_open and can_open
			_duration_max_open_check.set_block_signals(false)
	if _duration_min_value_label:
		_duration_min_value_label.text = _EndlessSessionConfig.format_duration_sec(dmin)
	if _duration_max_value_label:
		_duration_max_value_label.text = _EndlessSessionConfig.format_duration_sec(dmax, max_open)


func _on_gen_mode_policy_toggled(_on: bool, _policy_id: String) -> void:
	# Replaced by ChartStyleSettings; keep handlers so old signal wiring cannot crash.
	pass


func _on_gen_mode_check_toggled(_on: bool, _mode_id: String) -> void:
	pass


func _sync_gen_mode_ui() -> void:
	if _gen_mode_checks_panel:
		_gen_mode_checks_panel.visible = false


func _sync_gen_mode_checks() -> void:
	pass


func _build_mod_policy_buttons() -> void:
	if _mod_policy_row == null:
		return
	_free_container_children(_mod_policy_row)
	_mod_policy_buttons.clear()
	_mod_policy_group = ButtonGroup.new()
	_mod_policy_group.allow_unpress = false
	var specs: Array = [
		{"id": _EndlessSessionConfig.MOD_POLICY_NONE, "key": "SESSION_SETUP_MOD_POLICY_NONE"},
		{"id": _EndlessSessionConfig.MOD_POLICY_RANDOM_POOL, "key": "SESSION_SETUP_MOD_POLICY_RANDOM"},
		{"id": _EndlessSessionConfig.MOD_POLICY_FIXED, "key": "SESSION_SETUP_MOD_POLICY_FIXED"},
	]
	for spec in specs:
		var btn := Button.new()
		btn.toggle_mode = true
		btn.button_group = _mod_policy_group
		btn.text = tr(str(spec.get("key", "")))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.theme_type_variation = &"FlatButton"
		_style_setup_button(btn, 42, 16)
		var policy_id := str(spec.get("id", ""))
		if policy_id == _EndlessSessionConfig.MOD_POLICY_FIXED:
			btn.tooltip_text = tr("SESSION_SETUP_MOD_POLICY_FIXED_HINT")
		btn.toggled.connect(_on_mod_policy_toggled.bind(policy_id))
		_mod_policy_row.add_child(btn)
		_mod_policy_buttons[policy_id] = btn


func _build_mod_count_buttons() -> void:
	if _mod_count_row == null:
		return
	_free_container_children(_mod_count_row)
	_mod_count_buttons.clear()
	_mod_count_group = ButtonGroup.new()
	_mod_count_group.allow_unpress = false
	for count in range(
		_EndlessSessionConfig.MOD_RANDOM_COUNT_MIN,
		_EndlessSessionConfig.MOD_RANDOM_COUNT_MAX + 1
	):
		var btn := Button.new()
		btn.toggle_mode = true
		btn.button_group = _mod_count_group
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.text = str(count)
		btn.theme_type_variation = &"FlatButton"
		_style_setup_button(btn, 42, 16)
		btn.toggled.connect(_on_mod_count_toggled.bind(count))
		_mod_count_row.add_child(btn)
		_mod_count_buttons[count] = btn


func _build_mod_pick_buttons() -> void:
	if _mod_pick_row == null:
		return
	_free_container_children(_mod_pick_row)
	_mod_pick_buttons.clear()
	_mod_pick_group = ButtonGroup.new()
	_mod_pick_group.allow_unpress = false
	var strategies: Array[Dictionary] = [
		{
			"id": _EndlessSessionConfig.MOD_PICK_STRATEGY_RESAMPLE,
			"key": "SESSION_SETUP_MOD_PICK_RESAMPLE",
			"hint": "SESSION_SETUP_MOD_PICK_RESAMPLE_HINT",
		},
		{
			"id": _EndlessSessionConfig.MOD_PICK_STRATEGY_FILL,
			"key": "SESSION_SETUP_MOD_PICK_FILL",
			"hint": "SESSION_SETUP_MOD_PICK_FILL_HINT",
		},
		{
			"id": _EndlessSessionConfig.MOD_PICK_STRATEGY_RANDOM,
			"key": "SESSION_SETUP_MOD_PICK_RANDOM",
			"hint": "SESSION_SETUP_MOD_PICK_RANDOM_HINT",
		},
	]
	for item in strategies:
		var strategy_id: String = str(item.get("id", ""))
		var btn := Button.new()
		btn.toggle_mode = true
		btn.button_group = _mod_pick_group
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.text = tr(str(item.get("key", "")))
		btn.tooltip_text = tr(str(item.get("hint", "")))
		btn.theme_type_variation = &"FlatButton"
		_style_setup_button(btn, 42, 16)
		btn.toggled.connect(_on_mod_pick_toggled.bind(strategy_id))
		_mod_pick_row.add_child(btn)
		_mod_pick_buttons[strategy_id] = btn


func _on_mod_pick_toggled(on: bool, strategy_id: String) -> void:
	if not on:
		return
	_config["mod_pick_strategy"] = strategy_id
	_queue_preview_sync()


func _build_gen_mode_policy_buttons() -> void:
	# Legacy UI replaced by ChartStyleSettings.
	pass


func _build_gen_mode_checkboxes() -> void:
	pass


func _build_mod_pool_cards() -> void:
	if _mod_pool_flow == null:
		return
	_free_container_children(_mod_pool_flow)
	_mod_pool_cards.clear()
	var pool_set := {}
	for mod_id in _config.get("mod_pool", _EndlessSessionConfig.default_mod_pool()):
		pool_set[str(mod_id)] = true
	for mod_id in _EndlessSessionConfig.session_mod_pool_candidates():
		var icon := _ModPoolIconScript.new() as SessionModPoolIcon
		if icon == null:
			continue
		icon.setup(mod_id)
		icon.pool_toggled.connect(_on_mod_pool_icon_toggled)
		_mod_pool_flow.add_child(icon)
		_mod_pool_cards[mod_id] = icon
		icon.set_pool_selected(pool_set.has(mod_id))


func _on_mod_policy_toggled(on: bool, policy_id: String) -> void:
	if not on:
		return
	_config["mod_policy"] = policy_id
	if policy_id in [_EndlessSessionConfig.MOD_POLICY_RANDOM_POOL, _EndlessSessionConfig.MOD_POLICY_FIXED]:
		var pool: Variant = _config.get("mod_pool", [])
		if pool is Array and (pool as Array).is_empty():
			_config["mod_pool"] = _EndlessSessionConfig.default_mod_pool()
	_sync_mod_ui()
	_queue_preview_sync()
	MusicManager.play_modifier_select_sound()


func _persist_config() -> void:
	if PlayerDataManager:
		PlayerDataManager.save_endless_session_last(_config)


func _on_mod_count_toggled(on: bool, count: int) -> void:
	if not on:
		return
	_config["mod_random_count"] = count
	_queue_preview_sync()
	MusicManager.play_modifier_select_sound()


func _on_mod_pool_icon_toggled(modifier_id: String, pressed: bool) -> void:
	var pool: Array = (_config.get("mod_pool", []) as Array).duplicate()
	var sid := str(modifier_id)
	if pressed:
		if not pool.has(sid):
			pool.append(sid)
	else:
		if pool.size() <= _mod_pool_min_for_policy():
			_sync_mod_pool_selection()
			if MusicManager.has_method("play_cancel_sound"):
				MusicManager.play_cancel_sound()
			else:
				MusicManager.play_modifier_deselect_sound()
			return
		pool.erase(sid)
	_config["mod_pool"] = pool
	_sync_mod_pool_selection()
	_sync_mod_pool_count_label()
	_queue_preview_sync()
	if pressed:
		MusicManager.play_modifier_select_sound()
	else:
		MusicManager.play_modifier_deselect_sound()


func _on_difficulty_min_changed(value: float) -> void:
	_config["difficulty_min"] = value
	if float(_config.get("difficulty_max", value)) < value:
		_config["difficulty_max"] = value
		if _difficulty_max_slider:
			_difficulty_max_slider.set_value_no_signal(value)
	_sync_difficulty_ui()
	_queue_preview_sync()


func _on_difficulty_max_changed(value: float) -> void:
	_config["difficulty_max"] = value
	if float(_config.get("difficulty_min", value)) > value:
		_config["difficulty_min"] = value
		if _difficulty_min_slider:
			_difficulty_min_slider.set_value_no_signal(value)
	if value < _EndlessSessionConfig.DIFFICULTY_BASE_MAX:
		_config["difficulty_max_over_cap"] = false
	_sync_difficulty_ui()
	_queue_preview_sync()


func _on_difficulty_max_over_cap_toggled(on: bool) -> void:
	_config["difficulty_max_over_cap"] = on
	if on and _difficulty_max_slider:
		_config["difficulty_max"] = _EndlessSessionConfig.DIFFICULTY_BASE_MAX
		_difficulty_max_slider.set_value_no_signal(_EndlessSessionConfig.DIFFICULTY_BASE_MAX)
	_sync_difficulty_ui()
	_queue_preview_sync()


func _sync_difficulty_ui() -> void:
	_config = _EndlessSessionConfig.sanitize(_config)
	var dmin := float(_config.get("difficulty_min", _EndlessSessionConfig.DEFAULT_DIFFICULTY_MIN))
	var dmax := float(_config.get("difficulty_max", _EndlessSessionConfig.DEFAULT_DIFFICULTY_MAX))
	var max_over_cap := bool(_config.get("difficulty_max_over_cap", false))
	if _difficulty_min_slider and not is_equal_approx(_difficulty_min_slider.value, dmin):
		_difficulty_min_slider.set_value_no_signal(dmin)
	if _difficulty_max_slider and not is_equal_approx(_difficulty_max_slider.value, dmax):
		_difficulty_max_slider.set_value_no_signal(dmax)
	if _difficulty_max_over_cap_check:
		var can_over_cap := dmax >= _EndlessSessionConfig.DIFFICULTY_BASE_MAX - 0.001
		_difficulty_max_over_cap_check.visible = can_over_cap
		_difficulty_max_over_cap_check.disabled = not can_over_cap
		if _difficulty_max_over_cap_check.button_pressed != max_over_cap:
			_difficulty_max_over_cap_check.set_block_signals(true)
			_difficulty_max_over_cap_check.button_pressed = max_over_cap and can_over_cap
			_difficulty_max_over_cap_check.set_block_signals(false)
	if _difficulty_min_value_label:
		_difficulty_min_value_label.text = _EndlessSessionConfig.format_difficulty_value(dmin)
	if _difficulty_max_value_label:
		_difficulty_max_value_label.text = _EndlessSessionConfig.format_difficulty_value(dmax, max_over_cap)


func _mod_pool_min_for_policy() -> int:
	var policy := str(_config.get("mod_policy", _EndlessSessionConfig.MOD_POLICY_NONE))
	if policy == _EndlessSessionConfig.MOD_POLICY_RANDOM_POOL:
		return _EndlessSessionConfig.mod_pool_min_size()
	if policy == _EndlessSessionConfig.MOD_POLICY_FIXED:
		return 1
	return 0


func _sync_mod_ui() -> void:
	_config = _EndlessSessionConfig.sanitize(_config)
	var policy := str(_config.get("mod_policy", _EndlessSessionConfig.MOD_POLICY_RANDOM_POOL))
	for policy_id in _mod_policy_buttons.keys():
		var btn: Button = _mod_policy_buttons[policy_id]
		if btn:
			btn.set_block_signals(true)
			btn.button_pressed = policy_id == policy
			btn.set_block_signals(false)
	var pool_visible := (
		policy == _EndlessSessionConfig.MOD_POLICY_RANDOM_POOL
		or policy == _EndlessSessionConfig.MOD_POLICY_FIXED
	)
	var count_visible := policy == _EndlessSessionConfig.MOD_POLICY_RANDOM_POOL
	if _mod_pool_panel:
		_mod_pool_panel.visible = pool_visible
	if _mod_pool_caption:
		_mod_pool_caption.visible = pool_visible
		if pool_visible:
			_mod_pool_caption.text = (
				tr("SESSION_SETUP_MOD_POOL_FIXED")
				if policy == _EndlessSessionConfig.MOD_POLICY_FIXED
				else tr("SESSION_SETUP_MOD_POOL")
			)
	if _mod_pool_count_label:
		_mod_pool_count_label.visible = pool_visible
	if _mod_pool_flow:
		_mod_pool_flow.visible = pool_visible
	if _mod_count_caption:
		_mod_count_caption.visible = count_visible
	if _mod_count_row:
		_mod_count_row.visible = count_visible
	if _mod_pick_caption:
		_mod_pick_caption.visible = count_visible
	if _mod_pick_row:
		_mod_pick_row.visible = count_visible
	_sync_mod_pool_count_label()
	var count := int(_config.get("mod_random_count", _EndlessSessionConfig.DEFAULT_MOD_RANDOM_COUNT))
	for c in _mod_count_buttons.keys():
		var btn: Button = _mod_count_buttons[c]
		if btn:
			btn.set_block_signals(true)
			btn.button_pressed = int(c) == count
			btn.set_block_signals(false)
	var pick_strategy := str(
		_config.get("mod_pick_strategy", _EndlessSessionConfig.DEFAULT_MOD_PICK_STRATEGY)
	)
	for strategy_id in _mod_pick_buttons.keys():
		var pick_btn: Button = _mod_pick_buttons[strategy_id]
		if pick_btn:
			pick_btn.set_block_signals(true)
			pick_btn.button_pressed = str(strategy_id) == pick_strategy
			pick_btn.set_block_signals(false)
	_sync_mod_pool_selection()


func _sync_selected_tracks_count_label() -> void:
	if _selected_tracks_button == null:
		return
	var paths: Array = _config.get("selected_song_paths", [])
	_selected_tracks_button.text = tr("SESSION_SETUP_SELECTED_TRACKS_FMT") % [
		paths.size(),
		_EndlessSessionConfig.SELECTED_TRACK_PICKER_SOFT_MAX,
	]


func _sync_mod_pool_selection() -> void:
	var pool: Array = _config.get("mod_pool", [])
	var pool_set := {}
	for mod_id in pool:
		pool_set[str(mod_id)] = true
	for mod_id in _mod_pool_cards.keys():
		var icon = _mod_pool_cards[mod_id]
		if icon and icon.has_method("set_pool_selected"):
			icon.set_pool_selected(pool_set.has(str(mod_id)))


func _sync_mod_pool_count_label() -> void:
	if _mod_pool_count_label == null:
		return
	var pool: Array = _config.get("mod_pool", [])
	var total := _EndlessSessionConfig.session_mod_pool_candidates().size()
	_mod_pool_count_label.text = tr("SESSION_SETUP_MOD_POOL_COUNT_FMT") % [pool.size(), total]


func _on_source_button_toggled(on: bool, source_id: String) -> void:
	if not on:
		return
	if source_id == "":
		_sync_source_selection()
		return
	_config["track_source"] = source_id
	if source_id == _EndlessSessionConfig.TRACK_SOURCE_PLAYLIST:
		if str(_config.get("playlist_id", "")).strip_edges() == "":
			_config["playlist_id"] = _PlaylistCatalog.BUILTIN_FAVORITES_ID
	var opened_picker := false
	if source_id == _EndlessSessionConfig.TRACK_SOURCE_SELECTED:
		var paths: Array = _config.get("selected_song_paths", [])
		if paths.is_empty():
			_open_track_picker()
			opened_picker = true
	_sync_source_selection()
	_sync_random_favorites_visibility()
	_sync_genre_visibility()
	_queue_preview_sync()
	if not opened_picker:
		MusicManager.play_modifier_select_sound()


func _sync_source_selection() -> void:
	var source := str(_config.get("track_source", _EndlessSessionConfig.TRACK_SOURCE_RANDOM))
	for id in _source_buttons.keys():
		var btn: Button = _source_buttons[id]
		if btn:
			btn.set_block_signals(true)
			btn.button_pressed = str(id) == source
			btn.set_block_signals(false)
	_sync_random_favorites_visibility()


func _sync_random_favorites_visibility() -> void:
	if _random_favorites_check == null:
		return
	var is_random := str(_config.get("track_source", _EndlessSessionConfig.TRACK_SOURCE_RANDOM)) == _EndlessSessionConfig.TRACK_SOURCE_RANDOM
	_random_favorites_check.visible = is_random
	if not is_random:
		_config["random_favorites_only"] = false
		_random_favorites_check.button_pressed = false
	_sync_genre_visibility()
	_sync_track_filters_visibility()
	_sync_filter_chip_summaries()


func _sync_genre_visibility() -> void:
	var source := str(_config.get("track_source", _EndlessSessionConfig.TRACK_SOURCE_RANDOM))
	var is_library := source == _EndlessSessionConfig.TRACK_SOURCE_RANDOM
	if _genre_caption:
		_genre_caption.visible = is_library
		if is_library:
			_genre_caption.text = tr("SESSION_SETUP_GENRE_POLICY")
	if _genre_policy_row:
		_genre_policy_row.visible = is_library
	var genre_policy := str(_config.get("genre_policy", _EndlessSessionConfig.GENRE_POLICY_ALL))
	var show_groups := is_library and genre_policy == _EndlessSessionConfig.GENRE_POLICY_GROUPS
	if _genre_groups_panel:
		_genre_groups_panel.visible = show_groups
	if _genre_groups_hint:
		_genre_groups_hint.visible = show_groups
	if _genre_groups_count_label:
		_genre_groups_count_label.visible = show_groups
	if _genre_groups_toolbar:
		_genre_groups_toolbar.visible = show_groups
	var is_selected := str(_config.get("track_source", "")) == _EndlessSessionConfig.TRACK_SOURCE_SELECTED
	if _selected_tracks_panel:
		_selected_tracks_panel.visible = is_selected
	if _selected_pool_after_panel:
		_selected_pool_after_panel.visible = is_selected
	if is_selected:
		_sync_selected_tracks_count_label()
		_sync_selected_pool_after_option()
	_sync_playlist_ui()


func _open_track_picker() -> void:
	if transitions and transitions.has_method("open_track_picker_from_session_setup"):
		transitions.open_track_picker_from_session_setup(_EndlessSessionConfig.sanitize(_config))


func _setup_preview_mode_blurb() -> void:
	if _preview_title == null or _preview_rows_vbox == null:
		return
	if _preview_mode_blurb != null:
		return
	_preview_mode_blurb = Label.new()
	_preview_mode_blurb.name = "PreviewModeBlurb"
	_preview_mode_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_mode_blurb.add_theme_font_size_override("font_size", 13)
	_preview_mode_blurb.add_theme_color_override("font_color", Color(0.58, 0.66, 0.78, 0.95))
	_preview_mode_blurb.text = tr("SESSION_SETUP_PREVIEW_MODE_BLURB")
	var parent := _preview_title.get_parent()
	if parent:
		var title_idx := _preview_title.get_index()
		parent.add_child(_preview_mode_blurb)
		parent.move_child(_preview_mode_blurb, title_idx + 1)


func _setup_track_filters_layout() -> void:
	if _track_filters_layout_done or _unique_songs_check == null:
		return
	var setup_vbox := _unique_songs_check.get_parent() as VBoxContainer
	if setup_vbox == null:
		return
	_track_filters_panel = VBoxContainer.new()
	_track_filters_panel.name = "TrackFiltersPanel"
	_track_filters_panel.add_theme_constant_override("separation", 8)
	var filters_shell := PanelContainer.new()
	filters_shell.name = "TrackFiltersShell"
	filters_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filters_shell.add_theme_stylebox_override("panel", _track_filters_shell_style())
	var filters_content := VBoxContainer.new()
	filters_content.add_theme_constant_override("separation", 10)
	filters_shell.add_child(filters_content)
	_track_filters_panel.add_child(filters_shell)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	var title := Label.new()
	title.text = tr("SESSION_SETUP_TRACK_FILTERS_TITLE")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.74, 0.78, 0.88, 0.95))
	title.tooltip_text = tr("SESSION_SETUP_TRACK_FILTERS_TITLE_HINT")
	header.add_child(title)
	filters_content.add_child(header)
	_track_filter_chips_row = HBoxContainer.new()
	_track_filter_chips_row.add_theme_constant_override("separation", 8)
	filters_content.add_child(_track_filter_chips_row)
	var chip_specs: Array[Dictionary] = [
		{"id": "genre", "label": "SESSION_SETUP_FILTER_CHIP_GENRE", "hint": "SESSION_SETUP_GENRE_POLICY_HINT"},
		{"id": "instrument", "label": "SESSION_SETUP_FILTER_CHIP_INSTRUMENT", "hint": "SESSION_SETUP_FILTER_CHIP_INSTRUMENT_HINT"},
		{"id": "difficulty", "label": "SESSION_SETUP_FILTER_CHIP_DIFFICULTY", "hint": "SESSION_SETUP_DIFFICULTY_HINT"},
		{"id": "duration", "label": "SESSION_SETUP_FILTER_CHIP_DURATION", "hint": "SESSION_SETUP_DURATION_HINT"},
	]
	for spec in chip_specs:
		var chip_id := str(spec.get("id", ""))
		var chip := Button.new()
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.clip_text = true
		chip.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_style_setup_button(chip, 52, 12)
		chip.tooltip_text = tr(str(spec.get("hint", "")))
		chip.pressed.connect(_on_track_filter_chip_pressed.bind(chip_id))
		_track_filter_chips_row.add_child(chip)
		_track_filter_chips[chip_id] = chip
	_track_filter_bodies_container = VBoxContainer.new()
	_track_filter_bodies_container.name = "TrackFilterBodies"
	_track_filter_bodies_container.add_theme_constant_override("separation", 8)
	filters_content.add_child(_track_filter_bodies_container)
	var filter_groups: Array[Dictionary] = [
		{
			"id": "genre",
			"nodes": [
				_genre_caption,
				_genre_policy_row,
				_genre_groups_toolbar,
				_genre_groups_count_label,
				_genre_groups_panel,
			],
		},
		{
			"id": "instrument",
			"nodes": [_instruments_caption, _instruments_row],
		},
		{
			"id": "difficulty",
			"nodes": [_difficulty_caption, _difficulty_range_row],
		},
		{
			"id": "duration",
			"nodes": [_duration_caption, _duration_range_row],
		},
	]
	for group in filter_groups:
		var filter_id := str(group.get("id", ""))
		var body_panel := _make_track_filter_body(filter_id, group.get("nodes", []) as Array)
		_track_filter_bodies_container.add_child(body_panel)
	var insert_idx := _unique_songs_check.get_index() + 1
	setup_vbox.add_child(_track_filters_panel)
	setup_vbox.move_child(_track_filters_panel, insert_idx)
	_track_filters_layout_done = true
	_set_active_track_filter("")
	_sync_setup_option_styles()


func _track_filters_shell_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.085, 0.12, 0.72)
	style.border_color = Color(1, 1, 1, 0.14)
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 12.0
	style.content_margin_top = 10.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 10.0
	return style


func _filter_body_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.075, 0.11, 0.8)
	style.border_color = Color(1, 1, 1, 0.12)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 12.0
	style.content_margin_top = 10.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 10.0
	return style


func _make_track_filter_body(filter_id: String, nodes: Array) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "%sFilterBody" % filter_id.capitalize()
	panel.visible = false
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _filter_body_panel_style())
	var body_vbox := VBoxContainer.new()
	body_vbox.add_theme_constant_override("separation", 8)
	panel.add_child(body_vbox)
	for node in nodes:
		var ctrl := node as Control
		if ctrl == null or ctrl.get_parent() == null:
			continue
		ctrl.get_parent().remove_child(ctrl)
		body_vbox.add_child(ctrl)
	_track_filter_bodies[filter_id] = panel
	return panel


func _on_track_filter_chip_pressed(chip_id: String) -> void:
	if chip_id == "genre":
		var is_random := (
			str(_config.get("track_source", _EndlessSessionConfig.TRACK_SOURCE_RANDOM))
			== _EndlessSessionConfig.TRACK_SOURCE_RANDOM
		)
		if not is_random:
			return
	if _active_track_filter == chip_id:
		_set_active_track_filter("")
	else:
		_set_active_track_filter(chip_id)
		call_deferred("_ensure_active_filter_body_visible")


func _ensure_active_filter_body_visible() -> void:
	if _active_track_filter == "" or _setup_panel == null:
		return
	var body: Control = _track_filter_bodies.get(_active_track_filter, null)
	if body == null:
		return
	var scroll := _setup_panel.get_node_or_null("SetupMargin/SetupScroll") as ScrollContainer
	if scroll:
		scroll.ensure_control_visible(body)


func _set_active_track_filter(filter_id: String) -> void:
	_active_track_filter = filter_id
	_sync_active_track_filter()


func _sync_active_track_filter() -> void:
	for filter_id in _track_filter_bodies.keys():
		var body: Control = _track_filter_bodies[filter_id]
		if body:
			body.visible = str(filter_id) == _active_track_filter and _active_track_filter != ""
	_sync_setup_option_styles()
	if _active_track_filter == "genre":
		_sync_genre_visibility()


func _sync_filter_chip_styles() -> void:
	_sync_setup_option_styles()


func _sync_track_filters_visibility() -> void:
	if _track_filters_panel == null:
		return
	var is_random := (
		str(_config.get("track_source", _EndlessSessionConfig.TRACK_SOURCE_RANDOM))
		== _EndlessSessionConfig.TRACK_SOURCE_RANDOM
	)
	_track_filters_panel.visible = true
	if _track_filter_chips.has("genre"):
		var genre_chip: Button = _track_filter_chips["genre"]
		if genre_chip:
			genre_chip.visible = is_random
	if not is_random and _active_track_filter == "genre":
		_set_active_track_filter("")


func _sync_filter_chip_summaries() -> void:
	if _track_filter_chips.is_empty():
		return
	var genre_policy := str(_config.get("genre_policy", _EndlessSessionConfig.GENRE_POLICY_ALL))
	var genre_groups: Array = _config.get("genre_group_ids", [])
	var genre_summary := _EndlessSessionConfig.preview_genre_text(genre_policy, genre_groups)
	_set_filter_chip_text("genre", tr("SESSION_SETUP_FILTER_CHIP_GENRE"), genre_summary)
	var inst_summary := _EndlessSessionConfig.preview_instrument_text(
		_config.get("instruments", [_config.get("instrument", _EndlessSessionConfig.DEFAULT_INSTRUMENT)])
	)
	_set_filter_chip_text("instrument", tr("SESSION_SETUP_FILTER_CHIP_INSTRUMENT"), inst_summary)
	var dmin := float(_config.get("difficulty_min", _EndlessSessionConfig.DEFAULT_DIFFICULTY_MIN))
	var dmax := float(_config.get("difficulty_max", _EndlessSessionConfig.DEFAULT_DIFFICULTY_MAX))
	var max_over_cap := bool(_config.get("difficulty_max_over_cap", false))
	var diff_summary := "%s – %s" % [
		_EndlessSessionConfig.format_difficulty_value(dmin),
		_EndlessSessionConfig.format_difficulty_value(dmax, max_over_cap),
	]
	_set_filter_chip_text("difficulty", tr("SESSION_SETUP_FILTER_CHIP_DIFFICULTY"), diff_summary)
	var dur_min := int(_config.get("duration_min_sec", _EndlessSessionConfig.DEFAULT_DURATION_MIN_SEC))
	var dur_max := int(_config.get("duration_max_sec", _EndlessSessionConfig.DEFAULT_DURATION_MAX_SEC))
	var dur_max_open := bool(_config.get("duration_max_open", false))
	var dur_summary := "%s – %s" % [
		_EndlessSessionConfig.format_duration_sec(dur_min),
		_EndlessSessionConfig.format_duration_sec(dur_max, dur_max_open),
	]
	_set_filter_chip_text("duration", tr("SESSION_SETUP_FILTER_CHIP_DURATION"), dur_summary)


func _set_filter_chip_text(chip_id: String, label: String, summary: String) -> void:
	var chip: Button = _track_filter_chips.get(chip_id, null)
	if chip == null:
		return
	chip.text = "%s\n%s" % [label, summary]


func _apply_setup_tooltips() -> void:
	if _random_favorites_check:
		_random_favorites_check.tooltip_text = tr("SESSION_SETUP_RANDOM_FAVORITES_HINT")
	if _unique_songs_check:
		_unique_songs_check.tooltip_text = tr("SESSION_SETUP_UNIQUE_SONGS_HINT")
	if _difficulty_caption:
		_difficulty_caption.tooltip_text = tr("SESSION_SETUP_DIFFICULTY_HINT")
	if _difficulty_max_over_cap_check:
		_difficulty_max_over_cap_check.tooltip_text = tr("SESSION_SETUP_DIFF_MAX_OVER_CAP_HINT")
	if _duration_caption:
		_duration_caption.tooltip_text = tr("SESSION_SETUP_DURATION_HINT")
	if _duration_max_open_check:
		_duration_max_open_check.tooltip_text = tr("SESSION_SETUP_DURATION_MAX_OPEN_HINT")
	if _genre_caption:
		_genre_caption.tooltip_text = tr("SESSION_SETUP_GENRE_POLICY_HINT")
	if _gen_mode_caption:
		_gen_mode_caption.tooltip_text = tr("SESSION_SETUP_GEN_MODE_POLICY_HINT")
	if _mod_pool_caption:
		_mod_pool_caption.tooltip_text = tr("SESSION_SETUP_MOD_POOL_HINT")
	if _mod_count_caption:
		_mod_count_caption.tooltip_text = tr("SESSION_SETUP_MOD_COUNT_HINT")
	if _mod_pick_caption:
		_mod_pick_caption.tooltip_text = tr("SESSION_SETUP_MOD_PICK_CAPTION_HINT")
	if _selected_pool_after_caption:
		_selected_pool_after_caption.tooltip_text = tr("SESSION_SETUP_POOL_AFTER_HINT")
	if _selected_pool_after_option:
		_selected_pool_after_option.tooltip_text = tr("SESSION_SETUP_POOL_AFTER_HINT")
	if _playlist_pick_button:
		_playlist_pick_button.tooltip_text = tr("SESSION_SETUP_PLAYLIST_PICK_HINT")
	if _playlist_manage_button:
		_playlist_manage_button.tooltip_text = tr("SESSION_SETUP_PLAYLIST_MANAGE_HINT")
	if _playlist_favorites_button:
		_playlist_favorites_button.tooltip_text = tr("SESSION_SETUP_PLAYLIST_FAVORITES_HINT")
	for count in _mod_count_buttons.keys():
		var btn: Button = _mod_count_buttons[count]
		if btn:
			btn.tooltip_text = tr("SESSION_SETUP_MOD_COUNT_VALUE_HINT") % int(count)


func _setup_selected_pool_after_option() -> void:
	if _selected_pool_after_option == null:
		return
	_selected_pool_after_option.clear()
	_selected_pool_after_option.add_item(tr("SESSION_SETUP_POOL_AFTER_RESHUFFLE"), 0)
	_selected_pool_after_option.set_item_metadata(0, _EndlessSessionConfig.SELECTED_POOL_AFTER_RESHUFFLE)
	_selected_pool_after_option.add_item(tr("SESSION_SETUP_POOL_AFTER_EXPAND"), 1)
	_selected_pool_after_option.set_item_metadata(1, _EndlessSessionConfig.SELECTED_POOL_AFTER_EXPAND)
	_sync_selected_pool_after_option()


func _sync_selected_pool_after_option() -> void:
	if _selected_pool_after_option == null:
		return
	var policy := _EndlessSessionConfig.normalize_selected_pool_after(
		str(_config.get("selected_pool_after", _EndlessSessionConfig.SELECTED_POOL_AFTER_RESHUFFLE))
	)
	for i in range(_selected_pool_after_option.item_count):
		if str(_selected_pool_after_option.get_item_metadata(i)) == policy:
			_selected_pool_after_option.select(i)
			break


func _on_selected_pool_after_changed(index: int) -> void:
	if _selected_pool_after_option == null:
		return
	var policy := str(_selected_pool_after_option.get_item_metadata(index))
	_config["selected_pool_after"] = _EndlessSessionConfig.normalize_selected_pool_after(policy)
	_queue_preview_sync()


func _on_selected_tracks_pressed() -> void:
	_open_track_picker()


func _queue_preview_sync() -> void:
	if _preview_sync_queued:
		return
	_preview_sync_queued = true
	call_deferred("_flush_preview_sync")


func _flush_preview_sync() -> void:
	_preview_sync_queued = false
	_sync_preview()


func _sync_preview() -> void:
	_config = _EndlessSessionConfig.sanitize(_config)
	var source := str(_config.get("track_source", _EndlessSessionConfig.TRACK_SOURCE_RANDOM))
	var favorites_only := bool(_config.get("random_favorites_only", false))
	var fav_count := _favorite_track_count()
	var dmin := float(_config.get("difficulty_min", _EndlessSessionConfig.DEFAULT_DIFFICULTY_MIN))
	var dmax := float(_config.get("difficulty_max", _EndlessSessionConfig.DEFAULT_DIFFICULTY_MAX))
	var max_over_cap := bool(_config.get("difficulty_max_over_cap", false))
	var source_text := _EndlessSessionConfig.preview_source_text(source, false)
	_set_preview_row("source", source_text, true)
	_set_preview_row(
		"favorites",
		tr("SESSION_SETUP_PREVIEW_FAVORITES_ON") if favorites_only else tr("SESSION_SETUP_PREVIEW_FAVORITES_OFF"),
		source == _EndlessSessionConfig.TRACK_SOURCE_RANDOM
	)
	var unique_only := bool(_config.get("unique_songs_only", false))
	_set_preview_row(
		"unique",
		tr("SESSION_SETUP_PREVIEW_UNIQUE_ON") if unique_only else tr("SESSION_SETUP_PREVIEW_UNIQUE_OFF"),
		true
	)
	_set_preview_row(
		"instrument",
		_EndlessSessionConfig.preview_instrument_text(str(_config.get("instrument", _EndlessSessionConfig.DEFAULT_INSTRUMENT))),
		true
	)
	var genre_policy := str(_config.get("genre_policy", _EndlessSessionConfig.GENRE_POLICY_ALL))
	var genre_groups: Array = _config.get("genre_group_ids", [])
	var show_genre := source == _EndlessSessionConfig.TRACK_SOURCE_RANDOM
	_set_preview_row(
		"genre",
		_EndlessSessionConfig.preview_genre_text(genre_policy, genre_groups),
		show_genre
	)
	var selected_paths: Array = _config.get("selected_song_paths", [])
	_set_preview_row(
		"tracks",
		tr("SESSION_SETUP_PREVIEW_TRACKS_FMT") % selected_paths.size(),
		source == _EndlessSessionConfig.TRACK_SOURCE_SELECTED
	)
	var playlist_id := str(_config.get("playlist_id", _PlaylistCatalog.BUILTIN_FAVORITES_ID))
	var playlist_paths: Array[String] = []
	if source == _EndlessSessionConfig.TRACK_SOURCE_PLAYLIST:
		playlist_paths = _PlaylistCatalog.song_paths_for(playlist_id)
	_set_preview_row(
		"playlist",
		tr("SESSION_SETUP_PREVIEW_PLAYLIST_FMT") % [
			_EndlessSessionConfig.preview_playlist_text(playlist_id),
			playlist_paths.size(),
		],
		source == _EndlessSessionConfig.TRACK_SOURCE_PLAYLIST
	)
	_set_preview_row(
		"difficulty",
		tr("SESSION_SETUP_PREVIEW_DIFFICULTY_FMT") % [
			_EndlessSessionConfig.format_difficulty_value(dmin),
			_EndlessSessionConfig.format_difficulty_value(dmax, max_over_cap),
		],
		true
	)
	var dur_min := int(_config.get("duration_min_sec", _EndlessSessionConfig.DEFAULT_DURATION_MIN_SEC))
	var dur_max := int(_config.get("duration_max_sec", _EndlessSessionConfig.DEFAULT_DURATION_MAX_SEC))
	var dur_max_open := bool(_config.get("duration_max_open", false))
	_set_preview_row(
		"duration",
		tr("SESSION_SETUP_PREVIEW_DURATION_FMT") % [
			_EndlessSessionConfig.format_duration_sec(dur_min),
			_EndlessSessionConfig.format_duration_sec(dur_max, dur_max_open),
		],
		true
	)
	var gen_policy := str(_config.get("generation_mode_policy", _EndlessSessionConfig.GEN_MODE_POLICY_ALL))
	var gen_allowed: Array = _config.get("generation_modes_allowed", [])
	var diff_policy := str(_config.get("chart_difficulty_policy", _EndlessSessionConfig.CHART_DIFFICULTY_POLICY_ALL))
	var diff_tiers: Array = _config.get("chart_difficulty_tiers_allowed", [])
	_set_preview_row(
		"gen_modes",
		tr("SESSION_SETUP_PREVIEW_CHART_STYLE_FMT") % _EndlessSessionConfig.preview_chart_style_text(
			gen_policy, gen_allowed, diff_policy, diff_tiers
		),
		true
	)
	var hp_pct := _EndlessSessionConfig.normalize_inter_track_hp_recovery_pct(
		_config.get("inter_track_hp_recovery_pct", _EndlessSessionConfig.DEFAULT_INTER_TRACK_HP_RECOVERY_PCT)
	)
	_set_preview_row(
		"hp_recovery",
		tr("SESSION_SETUP_PREVIEW_HP_RECOVERY_FMT") % _EndlessSessionConfig.format_inter_track_hp_recovery_pct(hp_pct),
		true
	)
	_set_preview_row("mods", tr("SESSION_SETUP_PREVIEW_MODS_FMT") % _preview_mods_text(), true)
	var scope_count := _SessionScopeResolver.scope_count(_config)
	var scope_ok := scope_count > 0
	_sync_scope_hero(scope_count, scope_ok)
	_set_preview_row("scope", tr("SESSION_SETUP_PREVIEW_SCOPE_FMT") % scope_count, false)
	_sync_genre_policy_buttons()
	_sync_genre_group_icons()
	_sync_genre_visibility()
	_sync_playlist_ui()
	_sync_instrument_icons()
	var fav_ok := not favorites_only or fav_count > 0
	var mod_policy := str(_config.get("mod_policy", _EndlessSessionConfig.MOD_POLICY_NONE))
	var pool: Array = _config.get("mod_pool", [])
	var mods_ok := (
		mod_policy == _EndlessSessionConfig.MOD_POLICY_NONE
		or (
			mod_policy in [
				_EndlessSessionConfig.MOD_POLICY_RANDOM_POOL,
				_EndlessSessionConfig.MOD_POLICY_FIXED,
			]
			and pool.size() >= _mod_pool_min_for_policy()
		)
	)
	var genre_applies := source == _EndlessSessionConfig.TRACK_SOURCE_RANDOM
	var genre_ok := (
		not genre_applies
		or genre_policy != _EndlessSessionConfig.GENRE_POLICY_GROUPS
		or not genre_groups.is_empty()
	)
	var selected_ok := (
		source != _EndlessSessionConfig.TRACK_SOURCE_SELECTED
		or selected_paths.size() >= _EndlessSessionConfig.SELECTED_TRACK_PICKER_MIN
	)
	if _footer_label:
		if scope_ok:
			_footer_label.text = tr("SESSION_SETUP_FOOTER_HINT")
		else:
			_footer_label.text = tr("SESSION_SETUP_SCOPE_EMPTY")
	_sync_start_button_state(
		fav_ok,
		mods_ok,
		scope_ok,
		genre_ok,
		selected_ok,
		favorites_only,
		fav_count,
		selected_paths.size(),
		genre_groups,
		pool
	)
	_sync_filter_chip_summaries()
	_sync_setup_option_styles()
	_persist_config()


func _preview_mods_text() -> String:
	var policy := str(_config.get("mod_policy", _EndlessSessionConfig.MOD_POLICY_NONE))
	if policy == _EndlessSessionConfig.MOD_POLICY_NONE:
		return tr("SESSION_SETUP_MOD_POLICY_NONE")
	if policy == _EndlessSessionConfig.MOD_POLICY_FIXED:
		var fixed_pool: Array = _config.get("mod_pool", [])
		return tr("SESSION_SETUP_PREVIEW_MODS_FIXED_FMT") % fixed_pool.size()
	var count := int(_config.get("mod_random_count", _EndlessSessionConfig.DEFAULT_MOD_RANDOM_COUNT))
	var pool: Array = _config.get("mod_pool", [])
	var pick_strategy := str(
		_config.get("mod_pick_strategy", _EndlessSessionConfig.DEFAULT_MOD_PICK_STRATEGY)
	)
	return "%s · %s" % [
		tr("SESSION_SETUP_PREVIEW_MODS_RANDOM_FMT") % [pool.size(), count],
		tr(_EndlessSessionConfig.mod_pick_strategy_label_key(pick_strategy)),
	]


func _favorite_track_count() -> int:
	if PlayerDataManager == null:
		return 0
	if PlayerDataManager.has_method("_ensure_favorite_song_paths"):
		PlayerDataManager._ensure_favorite_song_paths()
	var paths: Variant = PlayerDataManager.data.get("favorite_song_paths", PackedStringArray())
	if paths is PackedStringArray:
		return (paths as PackedStringArray).size()
	return 0


func _endless_accent() -> Color:
	return _PlayModeIds.accent_for(_PlayModeIds.ENDLESS)


func _sync_ambient_profile() -> void:
	var engine := get_parent()
	if engine and engine.has_method("set_ambient_screen_profile"):
		engine.set_ambient_screen_profile(&"play_modes_endless")


func apply_locale() -> void:
	if _back_button:
		_back_button.text = tr("BTN_BACK")
	if _title_label:
		_title_label.text = tr("SESSION_SETUP_TITLE")
	if _subtitle_label:
		_subtitle_label.text = tr("SESSION_SETUP_SUBTITLE")
	if _footer_label:
		_footer_label.text = tr("SESSION_SETUP_FOOTER_HINT")
	if _tracks_section_title:
		_tracks_section_title.text = tr("SESSION_SETUP_SECTION_TRACKS")
	if _random_favorites_check:
		_random_favorites_check.text = tr("SESSION_SETUP_RANDOM_FAVORITES")
	if _unique_songs_check:
		_unique_songs_check.text = tr("SESSION_SETUP_UNIQUE_SONGS")
	if _genre_caption:
		_genre_caption.text = tr("SESSION_SETUP_GENRE_POLICY")
	if _genre_groups_hint:
		_genre_groups_hint.text = tr("SESSION_SETUP_GENRE_GROUPS_HINT")
	if _genre_groups_count_label:
		_sync_genre_groups_count_label()
	if _generation_section_title:
		_generation_section_title.text = tr("SESSION_SETUP_SECTION_CHART_STYLE")
	if _difficulty_range_from_label:
		_difficulty_range_from_label.text = tr("SESSION_SETUP_RANGE_FROM")
	if _difficulty_range_to_label:
		_difficulty_range_to_label.text = tr("SESSION_SETUP_RANGE_TO")
	if _duration_range_from_label:
		_duration_range_from_label.text = tr("SESSION_SETUP_RANGE_FROM")
	if _duration_range_to_label:
		_duration_range_to_label.text = tr("SESSION_SETUP_RANGE_TO")
	if _preview_scope_sub_label:
		_preview_scope_sub_label.text = tr("SESSION_SETUP_PREVIEW_SCOPE_HERO_SUB")
	if _instruments_caption:
		_instruments_caption.text = tr("SESSION_SETUP_INSTRUMENTS")
		_instruments_caption.tooltip_text = tr("SESSION_SETUP_INSTRUMENTS_HINT")
	if _instruments_row:
		_instruments_row.tooltip_text = tr("SESSION_SETUP_INSTRUMENTS_HINT")
	if _selected_tracks_button:
		_selected_tracks_button.tooltip_text = tr("SESSION_SETUP_SELECTED_TRACKS_HINT")
		_sync_selected_tracks_count_label()
	if _selected_pool_after_caption:
		_selected_pool_after_caption.text = tr("SESSION_SETUP_POOL_AFTER_CAPTION")
	_setup_selected_pool_after_option()
	if _difficulty_caption:
		_difficulty_caption.text = tr("SESSION_SETUP_DIFFICULTY")
	if _duration_caption:
		_duration_caption.text = tr("SESSION_SETUP_DURATION")
	if _duration_max_open_check:
		_duration_max_open_check.text = tr("SESSION_SETUP_DURATION_MAX_OPEN")
	if _chart_style_settings:
		_chart_style_settings.apply_locale()
	if _hp_recovery_panel:
		var hp_caption := _hp_recovery_panel.get_node_or_null("HpRecoveryCaption") as Label
		if hp_caption:
			hp_caption.text = tr("SESSION_SETUP_HP_RECOVERY")
			hp_caption.tooltip_text = tr("SESSION_SETUP_HP_RECOVERY_HINT")
	if _difficulty_max_over_cap_check:
		_difficulty_max_over_cap_check.text = tr("SESSION_SETUP_DIFF_MAX_OVER_CAP")
	if _modifiers_section_title:
		_modifiers_section_title.text = tr("SESSION_SETUP_SECTION_MODS")
	if _mod_pool_caption:
		_mod_pool_caption.text = tr("SESSION_SETUP_MOD_POOL")
	if _mod_count_caption:
		_mod_count_caption.text = tr("SESSION_SETUP_MOD_COUNT")
	if _mod_pick_caption:
		_mod_pick_caption.text = tr("SESSION_SETUP_MOD_PICK_CAPTION")
	for strategy_id in _mod_pick_buttons.keys():
		var pick_btn: Button = _mod_pick_buttons[strategy_id]
		if pick_btn == null:
			continue
		pick_btn.text = tr(_EndlessSessionConfig.mod_pick_strategy_label_key(str(strategy_id)))
		match str(strategy_id):
			_EndlessSessionConfig.MOD_PICK_STRATEGY_FILL:
				pick_btn.tooltip_text = tr("SESSION_SETUP_MOD_PICK_FILL_HINT")
			_EndlessSessionConfig.MOD_PICK_STRATEGY_RANDOM:
				pick_btn.tooltip_text = tr("SESSION_SETUP_MOD_PICK_RANDOM_HINT")
			_:
				pick_btn.tooltip_text = tr("SESSION_SETUP_MOD_PICK_RESAMPLE_HINT")
	if _mod_pool_count_label:
		_sync_mod_pool_count_label()
	if _mod_pool_select_all_button:
		_mod_pool_select_all_button.text = tr("SESSION_BULK_SELECT_ALL")
	if _mod_pool_reset_button:
		_mod_pool_reset_button.text = tr("SESSION_BULK_RESET")
	if _genre_groups_select_all_button:
		_genre_groups_select_all_button.text = tr("SESSION_BULK_SELECT_ALL")
	if _genre_groups_reset_button:
		_genre_groups_reset_button.text = tr("SESSION_BULK_RESET")
	if _preview_title:
		_preview_title.text = tr("SESSION_SETUP_PREVIEW_TITLE")
	if _preview_mode_blurb:
		_preview_mode_blurb.text = tr("SESSION_SETUP_PREVIEW_MODE_BLURB")
	if _start_button:
		_start_button.text = tr("SESSION_SETUP_START")
	_ensure_dynamic_ui()
	_update_dynamic_ui_labels()
	if _playlist_pick_button:
		_playlist_pick_button.text = tr("SESSION_SETUP_PLAYLIST_PICK")
	if _playlist_manage_button:
		_playlist_manage_button.text = tr("SESSION_SETUP_PLAYLIST_MANAGE")
	if _playlist_favorites_button:
		_playlist_favorites_button.text = tr("PLAYLIST_FAVORITES_TITLE")
	if _playlist_pick_hint_label:
		_playlist_pick_hint_label.text = tr("SESSION_SETUP_PLAYLIST_PICK_HINT")
	if _playlist_ui_ready:
		_sync_playlist_ui()
	_setup_random_favorites_check()
	_setup_difficulty_sliders()
	_setup_duration_sliders()
	_sync_source_selection()
	_sync_difficulty_ui()
	_sync_duration_ui()
	_sync_chart_style_ui()
	_sync_hp_recovery_ui()
	_sync_mod_ui()
	_sync_genre_visibility()
	_sync_playlist_ui()
	_sync_active_track_filter()
	_queue_preview_sync()
	_apply_setup_tooltips()


func cleanup_before_exit() -> void:
	_persist_config()
	if PlayerDataManager:
		PlayerDataManager.flush_save()


func _maybe_show_setup_hint() -> void:
	if SettingsManager == null or SettingsManager.get_endless_setup_hint_seen():
		return
	if _difficulty_caption == null:
		return
	var callout := _HelpCalloutScene.instantiate() as HelpCallout
	if callout == null:
		return
	callout.setup("tip", tr("ENDLESS_SETUP_HINT_BODY"), false)
	_setup_hint_callout = callout
	var parent_node := _difficulty_caption.get_parent()
	if parent_node:
		var insert_idx := _difficulty_caption.get_index()
		parent_node.add_child(callout)
		parent_node.move_child(callout, insert_idx)
	SettingsManager.set_endless_setup_hint_seen(true)


func _execute_close_transition() -> void:
	if transitions:
		transitions.close_endless_session_setup()


func _on_start_pressed() -> void:
	var config := _EndlessSessionConfig.sanitize(_config)
	if transitions and transitions.has_method("stage_endless_session_config"):
		transitions.stage_endless_session_config(config)
	if transitions and transitions.has_method("open_endless_run"):
		transitions.open_endless_run(config)
		MusicManager.play_modifier_select_sound()
		return
	if _notice_overlay:
		_notice_overlay.show_with_actions(
			tr("SESSION_SETUP_START_STUB_TITLE"),
			tr("SESSION_SETUP_START_STUB_BODY"),
		)
	MusicManager.play_modifier_select_sound()


func _unhandled_input(event: InputEvent) -> void:
	if _notice_overlay and _notice_overlay.visible:
		return
	if _UiScreenHotkeys.try_handle(_hotkey_bindings(), event, get_viewport()):
		accept_event()
		return
	super._unhandled_input(event)


func _hotkey_bindings() -> Dictionary:
	return {
		KEY_1: _select_source.bind(_EndlessSessionConfig.TRACK_SOURCE_RANDOM),
		KEY_2: _select_source.bind(_EndlessSessionConfig.TRACK_SOURCE_PLAYLIST),
		KEY_3: _select_source.bind(_EndlessSessionConfig.TRACK_SOURCE_SELECTED),
		KEY_ENTER: _on_start_pressed,
		KEY_KP_ENTER: _on_start_pressed,
	}


func _select_source(source_id: String) -> void:
	_on_source_button_toggled(true, source_id)


func get_session_config() -> Dictionary:
	return _EndlessSessionConfig.sanitize(_config)
