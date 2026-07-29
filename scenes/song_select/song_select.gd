# scenes/song_select/song_select.gd
extends BaseScreen

const GenerationService = preload("res://logic/services/generation_service.gd")
const _OptionButtonPopupUtils = preload("res://logic/ui/option_button_popup_utils.gd")
const _SS = preload("res://logic/domain/library/song_select_strings.gd")
const _StatusToast = preload("res://logic/ui/status_toast.gd")
const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const _SongFavoriteIcons = preload("res://scenes/song_select/lib/song_favorite_icons.gd")
const _SpotlightTutorialScene := preload("res://ui/spotlight_tutorial.tscn")
const _RhythmDnaDialogScene := preload("res://scenes/song_select/rhythm_dna/rhythm_dna_dialog.tscn")
const _UiModifierSounds = preload("res://logic/ui/ui_modifier_sounds.gd")
const _UiMotionEffects = preload("res://logic/ui/ui_motion_effects.gd")
const _Overlay = preload("res://logic/ui/app_overlay_helpers.gd")
const _UserPresets = preload("res://logic/domain/modifiers/user_presets.gd")
const _GoalDiff = preload("res://logic/domain/generation/generation_goal_difficulty.gd")
const _PlaylistCatalog = preload("res://logic/domain/library/playlist_catalog.gd")
const _PlaylistLibraryBrowse = preload("res://logic/domain/library/playlist_library_browse.gd")
const _SongSelectUiStyles = preload("res://scenes/song_select/lib/song_select_ui_styles.gd")
const _UiRoundedClip = preload("res://logic/ui/ui_rounded_clip.gd")
const _COVER_CORNER_RADIUS := 12.0

var background_service: GenerationService = null
var _bg_status_ui_pending := false
var _list_highlight_pending := false
var _pending_highlight_paths: Array[String] = []
var song_list_manager: SongListController
var song_details_manager: SongDetailsManager
var results_manager: ResultsManager

var song_metadata_manager = SongLibrary 

@onready var edit_button: Button = $MainVBox/TopBarPanel/TopBarHBox/EditButton
@onready var modifiers_button: Button = $MainVBox/TopBarPanel/TopBarHBox/ModifiersButton
@onready var _playlists_button: Button = $MainVBox/TopBarPanel/TopBarHBox/PlaylistsButton
@onready var filter_by_letter: OptionButton = $MainVBox/TopBarPanel/TopBarHBox/FilterByLetter
@onready var song_item_list_ref: ItemList = $MainVBox/ContentHBox/ListPanel/ListMargin/SongListVBox/SongItemList
@onready var analyze_bpm_button: Button = $MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/ActionsVBox/AnalyzeBPMButton
@onready var results_button: Button = $MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/ActionsVBox/ResultsButton
@onready var clear_results_button: Button = $MainVBox/TopBarPanel/TopBarHBox/ClearResultsButton
@onready var _notice_overlay: AppNoticeOverlay = %NoticeOverlay
@onready var _confirm_overlay: AppConfirmOverlay = %ConfirmOverlay
var _choice_overlay: AppChoiceOverlay = null
@onready var _back_button: Button = $MainVBox/BackButton
@onready var _search_bar: LineEdit = $MainVBox/TopBarPanel/TopBarHBox/SearchBar
@onready var _gen_settings_button: Button = $MainVBox/TopBarPanel/TopBarHBox/GenerationSettingsButton
@onready var _generate_notes_button: Button = $MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/ActionsVBox/GenerateNotesButton
@onready var _play_button: Button = $MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/ActionsVBox/PlayButton
@onready var _delete_button: Button = $MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/ActionsVBox/DeleteButton
@onready var _screen_title_label: Label = $MainVBox/ScreenTitleLabel
@onready var _screen_subtitle_label: Label = $MainVBox/ScreenSubtitleLabel
@onready var _track_medals_strip: PanelContainer = $MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/TrackMedalsStrip
@onready var _favorite_button: TextureButton = $MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/CoverWrap/FavoriteButton

var generation_settings_selector: Control = null
var run_modifiers_screen: Control = null

var current_instrument: String = "drums"
var current_generation_mode: String = "basic"
var current_lanes: int = 4
var active_run_modifiers: Array[String] = []
var current_selected_song_data: Dictionary = {}
var current_displayed_song_path: String = ""
var _song_list_loading_depth: int = 0
var _details_tween: Tween = null
var tutorials: SongSelectTutorials = null
var filters: SongSelectFilters = null
var modifiers_host: SongSelectRunModifiersHost = null
var _playlist_browse_bar: PanelContainer = null
var _playlist_browse_label: Label = null
var _playlist_browse_clear_button: Button = null
var _pending_browse_playlist_id: String = ""

const CHOICE_OVERLAY_SCENE := preload("res://ui/overlays/app_choice_overlay.tscn")
const _ICON_NEUTRAL := Color(0.82, 0.86, 0.94, 1.0)
const _ICON_PLAY := Color(0.38, 0.78, 0.74, 1.0)
const _ICON_GENERATE := UiIconHelper.ACCENT_MINT
const _ICON_DANGER := Color(0.95, 0.55, 0.48, 1.0)
const _ICON_RESULTS := Color(0.66, 0.58, 0.86, 1.0)

func _ready():
	song_list_manager = SongListController.new()
	song_details_manager = SongDetailsManager.new()
	results_manager = ResultsManager.new()
	_setup_details_cover_clip()

	var game_engine = get_parent()
	var trans = game_engine.get_transitions()
	
	song_metadata_manager = SongLibrary
	
	setup_managers(trans)  
	
	song_metadata_manager.metadata_updated.connect(_on_song_metadata_updated)
	if SongLibrary and SongLibrary.has_signal("songs_list_changed"):
		SongLibrary.songs_list_changed.connect(_on_songs_list_changed_from_library)
		
	SongLibrary.load_songs()
	
	add_child(song_list_manager)
	song_list_manager.set_item_list(song_item_list_ref)
	song_list_manager.set_metadata_edit_lock_checker(_is_song_metadata_edit_locked)
	song_list_manager.set_unseen_medals_loader(func(path: String) -> Array:
		return results_manager.load_unseen_medals_for_song(path) if results_manager else []
	)
	song_list_manager.song_selected.connect(_on_song_item_selected_from_manager)
	song_list_manager.song_activated.connect(_on_song_item_activated_from_manager)
	song_list_manager.song_list_changed.connect(_on_song_list_changed)
	song_list_manager.heavy_list_rebuild_started.connect(_on_song_list_heavy_rebuild_started)
	song_list_manager.heavy_list_rebuild_finished.connect(_on_song_list_heavy_rebuild_finished)

	tutorials = SongSelectTutorials.new()
	tutorials.name = "Tutorials"
	tutorials.initialize(self)
	add_child(tutorials)

	filters = SongSelectFilters.new()
	filters.name = "Filters"
	filters.initialize(self)
	add_child(filters)

	modifiers_host = SongSelectRunModifiersHost.new()
	modifiers_host.name = "RunModifiersHost"
	modifiers_host.initialize(self)
	add_child(modifiers_host)

	if _pending_browse_playlist_id != "":
		song_list_manager.set_playlist_browse(_pending_browse_playlist_id)
		_sync_generation_from_playlist_view_filter()

	filters.restore_and_populate()
	
	add_child(song_details_manager)
	song_details_manager.setup_ui_nodes(
		$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/TitleLabel,
		$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/ArtistLabel,
		$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/YearLabel,
		$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/BpmLabel,
		$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/DurationLabel,
		$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/PrimaryGenreLabel,
		$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/PlayCountLabel,
		$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/BestGradeLabel,
		$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/ChartDifficultySection/ChartDifficultyBaseRow/ChartDifficultyLabel,
		$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/ChartDifficultySection/ChartDifficultyBaseRow/ChartDifficultyMeter,
		$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/ChartDifficultySection/ChartDifficultyBaseRow/ChartDifficultyValueLabel,
		$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/ChartDifficultySection/ChartDifficultyModLabel,
		$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/ChartDensityRow/ChartDensityLabel,
		$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/CoverWrap/CoverTextureRect,
		$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/ActionsVBox/PlayButton,
		$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/ChartIdLabel,
		$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/RhythmRatingLabel,
		$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/ChartDensityRow/RhythmDnaButton,
		$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/ChartDifficultySection/ChartDifficultyEffectiveRow,
		$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/ChartDifficultySection/ChartDifficultyEffectiveRow/ChartDifficultyEffectiveLabel,
		$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/ChartDifficultySection/ChartDifficultyEffectiveRow/ChartDifficultyEffectiveMeter,
		$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/ChartDifficultySection/ChartDifficultyEffectiveRow/ChartDifficultyEffectiveValueLabel
	)
	song_details_manager.rhythm_dna_requested.connect(_on_rhythm_dna_requested)
	song_details_manager.rhythm_dna_unavailable.connect(_on_rhythm_dna_unavailable)
	song_details_manager.rhythm_dna_usage_tutorial_requested.connect(_on_rhythm_dna_usage_tutorial_requested)
	song_details_manager.setup_audio_player()  
	
	song_list_manager.song_edited.connect(_on_song_edited_from_manager)
	song_list_manager.song_add_rejected.connect(_on_song_add_rejected)
		
	background_service = game_engine.get_background_service()
	if background_service:
		background_service.bpm_started.connect(_on_bpm_started)
		background_service.bpm_completed.connect(_on_bpm_completed)
		background_service.bpm_error.connect(_on_bpm_error)
		background_service.notes_started.connect(_on_notes_started)
		background_service.notes_completed.connect(_on_notes_completed)
		background_service.notes_error.connect(_on_notes_error)
		var bpm_task = background_service.get_active_bpm_task()
		if not bpm_task.is_empty():
			if String(bpm_task.get("path", "")) == current_displayed_song_path:
				_on_bpm_analysis_started()
		var notes_task = background_service.get_active_notes_task()
		if not notes_task.is_empty():
			_on_notes_generation_started()
		_apply_background_status_ui()
		if not background_service.notes_progress.is_connected(_on_notes_progress):
			background_service.notes_progress.connect(_on_notes_progress)
		if not background_service.bpm_progress.is_connected(_on_bpm_progress):
			background_service.bpm_progress.connect(_on_bpm_progress)
		if not background_service.queue_changed.is_connected(_on_generation_queue_changed):
			background_service.queue_changed.connect(_on_generation_queue_changed)
	
	
	_connect_ui_signals()
	_configure_details_scroll()
	_configure_song_list_focus()

	if _track_medals_strip and _track_medals_strip.has_signal("unseen_medals_viewed"):
		if not _track_medals_strip.unseen_medals_viewed.is_connected(_on_track_unseen_medals_viewed):
			_track_medals_strip.unseen_medals_viewed.connect(_on_track_unseen_medals_viewed)

	var saved_instrument = SettingsManager.get_setting("last_generation_instrument", "drums")
	var saved_mode = SettingsManager.get_setting("last_generation_mode", "basic")
	var saved_lanes = SettingsManager.get_setting("last_generation_lanes", 4)

	current_instrument = saved_instrument
	current_generation_mode = saved_mode
	current_lanes = saved_lanes
	active_run_modifiers = SettingsManager.get_run_modifiers()

	$MainVBox/TopBarPanel/TopBarHBox/GenerationSettingsButton.text = _format_generation_settings_label(saved_instrument, saved_mode, saved_lanes)
	song_details_manager.set_current_instrument(saved_instrument)
	song_details_manager.set_current_generation_mode(saved_mode)
	song_details_manager.set_current_lanes(saved_lanes)
	song_details_manager.set_active_run_modifiers(active_run_modifiers)
	song_list_manager.set_generation_settings(saved_instrument, saved_mode, saved_lanes)
	song_list_manager.set_active_run_modifiers(active_run_modifiers)
	
	analyze_bpm_button.disabled = true
	results_button.disabled = true
	clear_results_button.disabled = true
	_update_modifiers_button_label()
	call_deferred("_apply_filter_option_popup_font")
	if PlayerDataManager and not PlayerDataManager.favorite_songs_changed.is_connected(_on_favorite_songs_changed):
		PlayerDataManager.favorite_songs_changed.connect(_on_favorite_songs_changed)
	_setup_favorite_button()
	_update_favorite_button("")
	_setup_ui_icons()
	call_deferred("_refresh_filter_option_icon")
	call_deferred("_maybe_show_song_select_tutorial")
	_ensure_playlist_browse_bar()
	_sync_playlist_browse_bar()
	if _pending_browse_playlist_id != "":
		_pending_browse_playlist_id = ""


func _maybe_show_song_select_tutorial(force: bool = false) -> void:
	if tutorials:
		tutorials.maybe_show_song_select(force)


func _on_song_select_tutorial_closed() -> void:
	if tutorials:
		tutorials.on_song_select_closed()


func debug_show_tutorial() -> void:
	if tutorials:
		tutorials.debug_show_song_select()


func _on_rhythm_dna_usage_tutorial_requested(target: Control) -> void:
	if tutorials:
		tutorials.maybe_show_rhythm_dna_usage(target)


func _maybe_show_rhythm_dna_usage_tutorial(target: Control, force: bool = false) -> void:
	if tutorials:
		tutorials.maybe_show_rhythm_dna_usage(target, force)


func debug_show_rhythm_dna_usage_tutorial() -> void:
	var target: Control = null
	if song_details_manager and song_details_manager.rhythm_dna_caption:
		target = song_details_manager.rhythm_dna_caption
	if target == null:
		return
	if tutorials:
		tutorials.debug_show_rhythm_dna_usage(target)


func _on_rhythm_dna_usage_tutorial_closed() -> void:
	if tutorials:
		tutorials.on_rhythm_dna_usage_closed()


func _ensure_filter_option_items() -> void:
	if filters:
		filters.ensure_option_items()


func _sync_filter_option_selection() -> void:
	if filters:
		filters.sync_option_selection()


func _on_modifiers_button_pressed() -> void:
	if modifiers_host:
		modifiers_host.open()


func _on_playlists_button_pressed() -> void:
	MusicManager.play_modifier_select_sound()
	if transitions and transitions.has_method("open_playlist_hub_from_song_select"):
		transitions.open_playlist_hub_from_song_select()


func apply_playlist_browse(playlist_id: String) -> void:
	var pid := str(playlist_id).strip_edges()
	if not is_node_ready() or song_list_manager == null:
		_pending_browse_playlist_id = pid
		return
	_pending_browse_playlist_id = ""
	if pid == "":
		clear_playlist_browse()
		return
	song_list_manager.set_playlist_browse(pid)
	_sync_generation_from_playlist_view_filter()
	_ensure_playlist_browse_bar()
	_sync_playlist_browse_bar()
	_refresh_playlist_browse_list()


func clear_playlist_browse() -> void:
	_pending_browse_playlist_id = ""
	if song_list_manager:
		song_list_manager.clear_playlist_browse()
	if transitions and transitions.has_method("set_song_select_browse_playlist"):
		transitions.set_song_select_browse_playlist("")
	_sync_playlist_browse_bar()
	_refresh_playlist_browse_list()


func _ensure_playlist_browse_bar() -> void:
	if _playlist_browse_bar != null:
		return
	var main_vbox := $MainVBox
	if main_vbox == null:
		return
	_playlist_browse_bar = PanelContainer.new()
	_playlist_browse_bar.name = "PlaylistBrowseBar"
	_playlist_browse_bar.visible = false
	_playlist_browse_bar.add_theme_stylebox_override("panel", _SongSelectUiStyles.card_panel_style())
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_playlist_browse_bar.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	_playlist_browse_label = Label.new()
	_playlist_browse_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_playlist_browse_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_playlist_browse_label.add_theme_font_size_override("font_size", 14)
	_playlist_browse_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.98, 1.0))
	row.add_child(_playlist_browse_label)
	_playlist_browse_clear_button = Button.new()
	_playlist_browse_clear_button.theme_type_variation = &"FlatButton"
	_playlist_browse_clear_button.custom_minimum_size = Vector2(0, 36)
	if not _playlist_browse_clear_button.pressed.is_connected(_on_playlist_browse_clear_pressed):
		_playlist_browse_clear_button.pressed.connect(_on_playlist_browse_clear_pressed)
	row.add_child(_playlist_browse_clear_button)
	var top_bar := $MainVBox/TopBarPanel
	if top_bar:
		main_vbox.add_child(_playlist_browse_bar)
		main_vbox.move_child(_playlist_browse_bar, top_bar.get_index())


func _sync_playlist_browse_bar() -> void:
	_ensure_playlist_browse_bar()
	if _playlist_browse_bar == null:
		return
	var pid := song_list_manager.get_playlist_browse_id() if song_list_manager else ""
	var active := pid != ""
	_playlist_browse_bar.visible = active
	if not active:
		return
	if _playlist_browse_label:
		_playlist_browse_label.text = tr("SONG_SELECT_PLAYLIST_BROWSE_ACTIVE_FMT") % _PlaylistCatalog.display_name(pid)
	if _playlist_browse_clear_button:
		_playlist_browse_clear_button.text = tr("SONG_SELECT_PLAYLIST_BROWSE_CLEAR")


func _on_playlist_browse_clear_pressed() -> void:
	MusicManager.play_modifier_deselect_sound()
	clear_playlist_browse()


func _sync_generation_from_playlist_view_filter() -> void:
	if song_list_manager == null:
		return
	var vf := song_list_manager.get_playlist_view_filter()
	current_instrument = str(vf.get("instrument", current_instrument))
	current_lanes = int(vf.get("lanes", current_lanes))
	song_list_manager.set_generation_settings(current_instrument, current_generation_mode, current_lanes)
	song_details_manager.set_current_instrument(current_instrument)
	song_details_manager.set_current_lanes(current_lanes)
	if _gen_settings_button:
		_gen_settings_button.text = _format_generation_settings_label(
			current_instrument, current_generation_mode, current_lanes
		)
	refresh_generation_notes_highlights()


func _refresh_playlist_browse_list() -> void:
	if song_list_manager == null:
		return
	var q := _search_bar.text if _search_bar else ""
	if str(q).strip_edges() != "":
		song_list_manager.filter_items(str(q))
	else:
		song_list_manager.populate_items_grouped()
	_update_song_count_label()


func _open_run_modifiers_screen() -> void:
	if modifiers_host:
		modifiers_host.open()


func _on_run_modifiers_screen_closed() -> void:
	if modifiers_host:
		modifiers_host.on_closed()


func _on_run_modifiers_changed(mods: Array) -> void:
	if modifiers_host:
		modifiers_host.on_modifiers_changed(mods)


func _update_modifiers_button_label() -> void:
	if modifiers_host:
		modifiers_host.update_button_label()


func _on_filter_option_item_selected(_index: int) -> void:
	call_deferred("_refresh_filter_option_icon")


func _refresh_filter_option_icon() -> void:
	if filters:
		filters.refresh_option_icon()


func _restore_song_list_filter_and_populate() -> void:
	if filters:
		filters.restore_and_populate()


func _persist_song_select_filters() -> void:
	if filters:
		filters.persist()


func _apply_filter_option_popup_font() -> void:
	if filters:
		filters.apply_popup_font()


func apply_locale() -> void:
	if _screen_title_label:
		_screen_title_label.text = tr("SONG_SELECT_TITLE")
	if _screen_subtitle_label:
		_screen_subtitle_label.text = tr("SONG_SELECT_SUBTITLE")
	if _back_button:
		_back_button.text = tr("BTN_BACK")
	if _search_bar:
		_search_bar.placeholder_text = tr("SONG_SEARCH_PLACEHOLDER")
	_ensure_filter_option_items()
	_sync_filter_option_selection()
	if clear_results_button:
		clear_results_button.text = tr("SONG_CLEAR_RESULTS")
	if results_button:
		results_button.text = tr("SONG_RESULTS")
	if _delete_button:
		_delete_button.text = tr("SONG_DELETE")
	song_details_manager.apply_locale()
	if _track_medals_strip and _track_medals_strip.has_method("apply_locale"):
		_track_medals_strip.apply_locale()
	if _play_button:
		_play_button.text = tr("SONG_PLAY")
	if analyze_bpm_button:
		analyze_bpm_button.text = tr("SONG_ANALYZE_BPM")
	if _generate_notes_button:
		_generate_notes_button.text = tr("SONG_GEN_NOTES")
	_update_song_count_label()
	_update_edit_button_style()
	_update_metadata_edit_availability()
	_apply_background_status_ui()
	refresh_generation_notes_highlights()
	refresh_chart_id_visibility()
	refresh_rhythm_dna_button_visibility()
	if _gen_settings_button:
		_gen_settings_button.text = _format_generation_settings_label(current_instrument, current_generation_mode, current_lanes)
	if _playlists_button:
		_playlists_button.text = tr("PLAYLIST_HUB_TITLE")
		_playlists_button.tooltip_text = tr("SONG_SELECT_PLAYLISTS_TOOLTIP")
	_sync_playlist_browse_bar()
	_update_favorite_button(current_displayed_song_path)
	_update_modifiers_button_label()


func _setup_ui_icons() -> void:
	if _search_bar:
		UiIconHelper.setup_search_field(_search_bar)
	UiIconHelper.apply_icons_from_meta([
		edit_button,
		modifiers_button,
		_playlists_button,
		_gen_settings_button,
		clear_results_button,
		_play_button,
		analyze_bpm_button,
		_generate_notes_button,
		results_button,
		_delete_button,
	], 18)
	if _generate_notes_button:
		UiIconHelper.apply_icon_from_meta(_generate_notes_button, 18, UiIconHelper.ACCENT_MINT)
	if filter_by_letter:
		UiIconHelper.mark_option_button_icon(filter_by_letter, "arrow-down-narrow-wide.svg", _ICON_NEUTRAL)
		if not filter_by_letter.item_selected.is_connected(_on_filter_option_item_selected):
			filter_by_letter.item_selected.connect(_on_filter_option_item_selected)
	_refresh_toolbar_icon_tints()


func _refresh_toolbar_icon_tints() -> void:
	if edit_button:
		var edit_on := song_list_manager != null and song_list_manager.is_edit_mode_active()
		var edit_tint := UiIconHelper.ACCENT_BRIGHT if edit_on else _ICON_NEUTRAL
		UiIconHelper.apply_icon_from_meta(edit_button, 18, edit_tint)
	if modifiers_button:
		var mod_tint := UiIconHelper.ACCENT if not active_run_modifiers.is_empty() else _ICON_NEUTRAL
		UiIconHelper.apply_icon_from_meta(modifiers_button, 18, mod_tint)


func _configure_details_scroll() -> void:
	var details_scroll := $MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll as ScrollContainer
	if details_scroll:
		details_scroll.focus_mode = Control.FOCUS_NONE
		details_scroll.mouse_default_cursor_shape = Control.CURSOR_ARROW


func _configure_song_list_focus() -> void:
	if song_item_list_ref:
		song_item_list_ref.focus_mode = Control.FOCUS_ALL
		call_deferred("_focus_song_list")


func _is_search_bar_focused() -> bool:
	return _search_bar != null and _search_bar.has_focus()


func _focus_song_list() -> void:
	if _is_search_bar_focused():
		return
	if song_item_list_ref and song_item_list_ref.visible and is_visible_in_tree():
		if not _is_song_select_overlay_open():
			song_item_list_ref.grab_focus()


func _is_song_select_overlay_open() -> bool:
	if generation_settings_selector and is_instance_valid(generation_settings_selector):
		return true
	if modifiers_host and modifiers_host.overlay and is_instance_valid(modifiers_host.overlay):
		return true
	for child in get_children():
		if child is RhythmDnaDialog or child is MetadataEditDialog or child is GenrePickerDialog:
			return true
	return false


func _input(event: InputEvent) -> void:
	if not _is_search_bar_focused():
		return
	if _is_song_select_overlay_open():
		return
	if _handle_song_list_arrow_keys(event):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if UiScreenHotkeys.is_global_loading_active(get_viewport()):
		get_viewport().set_input_as_handled()
		return
	if _is_song_select_overlay_open():
		return
	if _handle_song_list_arrow_keys(event):
		get_viewport().set_input_as_handled()
		return
	if (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE) or event.is_action_pressed("ui_cancel"):
		accept_event()
		_on_back_pressed()


func _handle_song_list_arrow_keys(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return false
	if _is_song_select_overlay_open():
		return false
	var delta := 0
	match event.keycode:
		KEY_UP, KEY_KP_8:
			delta = -1
		KEY_DOWN, KEY_KP_2:
			delta = 1
		_:
			return false
	if not song_item_list_ref or not song_item_list_ref.visible:
		return false
	var moved := song_list_manager != null and song_list_manager.move_selection_by_delta(delta)
	if moved and not _is_search_bar_focused():
		song_item_list_ref.grab_focus()
	return moved


func _connect_ui_signals() -> void:
	_update_edit_button_style()
	var title_label = $MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/TitleLabel
	var artist_label = $MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/ArtistLabel
	var year_label = $MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/YearLabel
	var bpm_label = $MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/BpmLabel
	var primary_genre_label = $MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/PrimaryGenreLabel
	
	title_label.mouse_filter = Control.MOUSE_FILTER_STOP
	artist_label.mouse_filter = Control.MOUSE_FILTER_STOP
	year_label.mouse_filter = Control.MOUSE_FILTER_STOP
	bpm_label.mouse_filter = Control.MOUSE_FILTER_STOP
	primary_genre_label.mouse_filter = Control.MOUSE_FILTER_STOP
	
	_connect_label_edit_input(title_label, "title")
	_connect_label_edit_input(artist_label, "artist")
	_connect_label_edit_input(year_label, "year")
	_connect_label_edit_input(bpm_label, "bpm")
	_connect_label_edit_input(primary_genre_label, "primary_genre")
	_update_metadata_edit_availability()

func _connect_label_edit_input(node: Control, field_type: String) -> void:
	if node == null:
		return
	var bound := _on_gui_input_for_label.bind(field_type)
	if not node.gui_input.is_connected(bound):
		node.gui_input.connect(bound)
 
func _on_bpm_started(path, _disp):
	if _song_path_key(path) == _song_path_key(current_displayed_song_path):
		_on_bpm_analysis_started()
	_apply_background_status_ui()
 
func _on_bpm_completed(path, bpm_value, _disp):
	if _song_path_key(path) == _song_path_key(current_displayed_song_path):
		_on_bpm_analysis_completed(bpm_value)
	_apply_background_status_ui()
 
func _on_bpm_error(path, msg, _disp):
	if _song_path_key(path) != _song_path_key(current_displayed_song_path):
		return
	if _is_cancel_message(msg):
		var prev_bpm := String(current_selected_song_data.get("bpm", "")).strip_edges()
		if _SS.is_missing_metadata_value(prev_bpm):
			$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/BpmLabel.text = _SS._translate("SONG_FIELD_BPM") % _SS._translate("VALUE_NA")
		else:
			$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/BpmLabel.text = _SS._translate("SONG_FIELD_BPM") % prev_bpm
		_apply_bpm_dependent_ui()
		_apply_background_status_ui()
		return
	_on_bpm_analysis_error(msg)
	_apply_background_status_ui()
 
func _on_notes_started(_path, _disp):
	if not background_service:
		return
	var t: Dictionary = background_service.get_active_notes_task()
	if not t.has("path") or String(t.get("path", "")) != current_displayed_song_path:
		return
	var exact: bool = _notes_task_matches_current_settings(t)
	if exact:
		_on_notes_generation_started()
	else:
		_apply_background_status_ui()

func _notes_emit_task_dict() -> Dictionary:
	var t: Dictionary = background_service.get_active_notes_task()
	if t.is_empty():
		t = background_service.get_last_notes_task()
	return t

func _generation_queue_lookup_key() -> String:
	return GenerationIntents.chart_lookup_key(current_generation_mode, _saved_generation_intent())


func _notes_task_matches_current_settings(task: Dictionary) -> bool:
	if task.is_empty() or not task.has("path"):
		return false
	if _song_path_key(String(task.get("path", ""))) != _song_path_key(current_displayed_song_path):
		return false
	if not background_service:
		return false
	return background_service.notes_job_matches(
		current_displayed_song_path,
		current_instrument,
		_generation_queue_lookup_key(),
		current_lanes,
		task,
	)


func _song_path_key(p: String) -> String:
	return String(p).replace("\\", "/").trim_suffix("/")

func _on_notes_completed(path: String, instr: String, _disp: String):
	if not background_service:
		return
	var t: Dictionary = _notes_emit_task_dict()
	if not t.is_empty() and t.has("path"):
		SongDetailsManager.mark_play_glow_pending(
			String(t.get("path", path)),
			String(t.get("instrument", instr)),
			GenerationIntents.chart_lookup_key_from_job(t),
			int(t.get("lanes", current_lanes))
		)
	if _song_path_key(path) == _song_path_key(current_displayed_song_path):
		if _notes_task_matches_current_settings(t):
			_on_notes_generation_completed([], 0.0, instr)
		else:
			_apply_background_status_ui()
	call_deferred("_deferred_refresh_generation_notes_highlights", [path])
	_apply_background_status_ui()
	if _song_path_key(path) == _song_path_key(current_displayed_song_path):
		refresh_rhythm_dna_button_visibility()

func _on_rhythm_dna_unavailable(_song_path: String) -> void:
	_StatusToast.show_from_node(
		self,
		"rhythm_dna_missing",
		_SS._translate("DNA_TOAST_UNAVAILABLE"),
		"info",
		4.5
	)

func _on_rhythm_dna_requested(song_path: String) -> void:
	if song_path.strip_edges() == "":
		return
	var dna := NotesUtils.load_rhythm_dna(
		song_path, current_instrument, _generation_queue_lookup_key(), current_lanes
	)
	if dna.is_empty() or NotesUtils.is_minimal_rhythm_dna(dna):
		_on_rhythm_dna_unavailable(song_path)
		return
	song_details_manager._update_rhythm_dna_button(song_path)
	var cover_tex: Texture2D = null
	if song_details_manager and song_details_manager.cover_texture_rect:
		cover_tex = song_details_manager.cover_texture_rect.texture
	var dialog = _RhythmDnaDialogScene.instantiate()
	if dialog.has_signal("closed"):
		dialog.closed.connect(_on_rhythm_dna_dialog_closed)
	add_child(dialog)
	dialog.setup(dna, song_path, cover_tex)
	dialog.apply_locale()
	_trigger_rhythm_dna_opened_achievement()
	_UiModifierSounds.play_select()


func _trigger_rhythm_dna_opened_achievement() -> void:
	var game_engine := get_parent()
	if game_engine and game_engine.has_method("get_achievement_system"):
		var ach_sys = game_engine.get_achievement_system()
		if ach_sys and ach_sys.has_method("on_rhythm_dna_opened"):
			ach_sys.on_rhythm_dna_opened()


func _on_rhythm_dna_dialog_closed() -> void:
	_UiModifierSounds.play_deselect()
	call_deferred("_focus_song_list")

func _deferred_refresh_generation_notes_highlights(paths: Array = []):
	refresh_generation_notes_highlights(paths)

func _is_cancel_message(msg: String) -> bool:
	return _SS.is_cancel_message(msg)

func _on_notes_error(path: String, msg: String, _disp: String):
	if not background_service:
		return
	if _song_path_key(path) == _song_path_key(current_displayed_song_path):
		if _is_cancel_message(msg):
			_on_notes_generation_cancelled()
		else:
			var t: Dictionary = _notes_emit_task_dict()
			var exact: bool = (
				t.has("path")
				and String(t.get("instrument", "")) == current_instrument
				and String(t.get("mode", "")) == current_generation_mode
				and int(t.get("lanes", 0)) == current_lanes
			)
			if exact:
				_on_notes_generation_error(msg)
	_apply_background_status_ui()
func _on_notes_progress(_path: String, _k: int, _total: int, _status: String):
	_apply_background_status_ui()

func _on_bpm_progress(_path: String, _k: int, _total: int, _status: String):
	_apply_background_status_ui()
	
func _on_bpm_analysis_started():
	analyze_bpm_button.text = _SS._translate("SONG_ANALYZE_PROGRESS")
	analyze_bpm_button.disabled = true
	_update_metadata_edit_availability()

func _on_bpm_analysis_completed(bpm_value: int):
	var bpm_str := str(bpm_value)
	$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/BpmLabel.text = _SS._translate("SONG_FIELD_BPM") % bpm_str
	current_selected_song_data["bpm"] = bpm_str
	var song_path := String(current_selected_song_data.get("path", ""))
	if song_path != "":
		SongLibrary.update_metadata(song_path, {"bpm": bpm_str})
	_apply_bpm_dependent_ui()
	_pop_button(analyze_bpm_button)

func _on_bpm_analysis_error(error_message: String):
	printerr("SongSelect.gd: Ошибка BPM анализа: " + error_message)
	$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/BpmLabel.text = _SS._translate("SONG_BPM_ERROR")
	analyze_bpm_button.text = _SS._translate("SONG_ANALYZE_ERROR")
	analyze_bpm_button.disabled = false
	_update_metadata_edit_availability()
	
func _on_notes_generation_started():
	$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/ActionsVBox/GenerateNotesButton.text = _SS._translate("SONG_GEN_PROGRESS")
	$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/ActionsVBox/GenerateNotesButton.disabled = true
	_update_metadata_edit_availability()

func _on_notes_generation_completed(notes_data: Array, bpm_value: float, instrument_type: String):
	_set_generate_notes_button_idle()
	$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/ActionsVBox/PlayButton.disabled = false  
	song_details_manager._update_play_button_state()
	song_details_manager.set_generation_status(_SS._translate("SONG_GEN_DONE"), false)
	_update_metadata_edit_availability()
	if not current_selected_song_data.is_empty():
		song_details_manager.update_details(current_selected_song_data)
	_pop_button($MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/ActionsVBox/GenerateNotesButton)
	_maybe_show_first_chart_help_nudge()


func _maybe_show_first_chart_help_nudge() -> void:
	if SettingsManager == null or not SettingsManager.has_method("get_help_nudge_first_chart_done"):
		return
	if SettingsManager.get_help_nudge_first_chart_done():
		return
	SettingsManager.set_help_nudge_first_chart_done(true)
	_StatusToast.show_from_node(self, "help_nudge_first_chart", tr("HELP_NUDGE_FIRST_CHART"), "info", 5.0)

func _on_notes_generation_error(error_message: String):
	printerr("SongSelect.gd: Ошибка генерации нот: " + error_message)
	$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/ActionsVBox/GenerateNotesButton.text = _SS._translate("SONG_GEN_ERROR")
	$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/ActionsVBox/GenerateNotesButton.disabled = false
	song_details_manager.set_generation_status(_SS._translate("SONG_GEN_STATUS_ERROR") % error_message, true)
	_update_metadata_edit_availability()

func _on_notes_generation_cancelled():
	_apply_background_status_ui()
	song_details_manager.set_generation_status("", false)
	_update_metadata_edit_availability()
	
func _on_filter_by_letter_selected(index: int):
	if filters and filters.restoring:
		return
	if song_list_manager.is_edit_mode_active():
		pass
	var modes: Array[String] = [
		"title", "artist", "year", "bpm", "duration", "difficulty", "play_count", "notes_ready", "genre_group"
	]
	var mode := modes[clampi(index, 0, modes.size() - 1)]
	if song_list_manager and song_list_manager.current_filter_mode == mode:
		return
	_UiModifierSounds.play_select()
	song_list_manager.set_filter_mode(mode)
	var search_bar = $MainVBox/TopBarPanel/TopBarHBox/SearchBar
	var defer_heavy := mode == "difficulty"
	if search_bar:
		var q = String(search_bar.text)
		if defer_heavy:
			song_list_manager.call_deferred("filter_items", q, true)
		else:
			song_list_manager.filter_items(q)
	else:
		if defer_heavy:
			song_list_manager.call_deferred("populate_items_grouped", true)
		else:
			song_list_manager.populate_items_grouped()
	_persist_song_select_filters()
	call_deferred("_refresh_filter_option_icon")
	
func _on_search_text_changed(new_text: String) -> void:
	_apply_search_filter(new_text)


func _on_search_text_submitted(_new_text: String) -> void:
	_apply_search_filter()


func _apply_search_filter(query: String = "") -> void:
	if song_list_manager == null:
		return
	var text := query
	if text == "" and _search_bar:
		text = _search_bar.text
	song_list_manager.filter_items(text)
	_persist_song_select_filters()

func _update_filters_visibility():
	var is_edit_mode = song_list_manager.is_edit_mode_active()

func _on_song_edited_from_manager(song_data: Dictionary, item_list_index: int):
	var path := String(song_data.get("path", ""))
	var display_data := song_data.duplicate(true)
	if path != "":
		var persisted := SongLibrary.get_display_metadata_for_song(path)
		if not persisted.is_empty():
			display_data = persisted
	if song_list_manager.update_song_at_index(item_list_index, display_data):
		var selected_indices = song_item_list_ref.get_selected_items()
		if selected_indices.has(item_list_index) or current_displayed_song_path == path:
			if selected_indices.has(item_list_index):
				song_item_list_ref.select(item_list_index, true)
			current_selected_song_data = display_data.duplicate(true)
			var cur_bpm = String(current_selected_song_data.get("bpm", "")).strip_edges()
			if cur_bpm == "":
				current_selected_song_data["bpm"] = _SS._translate("VALUE_NA")
				if path != "":
					SongLibrary.update_metadata(path, {"bpm": _SS._translate("VALUE_NA")})
			current_displayed_song_path = path
			song_details_manager.update_details(current_selected_song_data)
			_apply_bpm_dependent_ui()
	else:
		song_list_manager.populate_items_grouped(true)

func _generate_notes_button_caption() -> String:
	if _check_if_notes_exist_for_current_settings():
		return _SS._translate("SONG_GEN_REGEN")
	return _SS._translate("SONG_GEN_NOTES")


func _set_generate_notes_button_idle() -> void:
	if _generate_notes_button == null:
		return
	_generate_notes_button.text = _generate_notes_button_caption()
	_generate_notes_button.disabled = false
	if _check_if_notes_exist_for_current_settings():
		_generate_notes_button.tooltip_text = tr("SONG_GEN_TOOLTIP_REGEN")
	else:
		_generate_notes_button.tooltip_text = ""


func _apply_bpm_dependent_ui():
	var song_bpm = current_selected_song_data.get("bpm", "")
	if _SS.is_missing_metadata_value(song_bpm):
		analyze_bpm_button.text = _SS._translate("SONG_ANALYZE_BPM")
		$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/ActionsVBox/GenerateNotesButton.text = _SS._translate("SONG_GEN_NEED_BPM")
		$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/ActionsVBox/GenerateNotesButton.disabled = true
		$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/ActionsVBox/PlayButton.disabled = true
	else:
		analyze_bpm_button.text = _SS._translate("SONG_BPM_DONE")
		_set_generate_notes_button_idle()
		if _check_if_notes_exist_for_current_settings():
			$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/ActionsVBox/PlayButton.disabled = false
			song_details_manager._update_play_button_state()
		else:
			$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/ActionsVBox/PlayButton.disabled = true
			song_details_manager._update_play_button_state()
	_apply_background_status_ui()

func _play_details_transition() -> void:
	var details = $MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox
	if not details:
		return
	if _details_tween and _details_tween.is_valid():
		_details_tween.kill()
	details.modulate.a = 0.25
	_details_tween = create_tween()
	_details_tween.tween_property(details, "modulate:a", 1.0, 0.18)

func _pop_button(btn: Button) -> void:
	if not btn or not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size * 0.5
	btn.scale = Vector2(1.12, 1.12)
	var tw := create_tween()
	tw.tween_property(btn, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _update_track_medals_display(song_path: String) -> void:
	if _track_medals_strip == null:
		return
	if song_path.is_empty():
		if _track_medals_strip.has_method("clear_track"):
			_track_medals_strip.clear_track()
		return
	var medals: Array[String] = []
	var unseen: Array[String] = []
	if results_manager:
		medals = results_manager.load_medals_for_song(song_path)
		unseen = results_manager.load_unseen_medals_for_song(song_path)
	if _track_medals_strip.has_method("set_track_medals"):
		_track_medals_strip.set_track_medals(medals, unseen)
	elif _track_medals_strip.has_method("clear_track"):
		_track_medals_strip.clear_track()


func _on_track_unseen_medals_viewed() -> void:
	var song_path := current_displayed_song_path
	if song_path.is_empty():
		return
	if results_manager:
		results_manager.mark_medals_seen_for_song(song_path)
	_update_track_medals_display(song_path)
	if song_list_manager:
		song_list_manager.refresh_unseen_medals_highlights()


func _setup_favorite_button() -> void:
	if _favorite_button == null:
		return
	_favorite_button.z_index = 0
	_favorite_button.z_as_relative = true
	var inactive := _SongFavoriteIcons.inactive_icon()
	var active := _SongFavoriteIcons.active_icon()
	if inactive == null and active == null:
		push_warning("SongSelect: favorite star icon failed to load")
		_favorite_button.visible = false
		return
	_favorite_button.texture_normal = inactive if inactive else active
	_favorite_button.texture_pressed = active if active else inactive
	_favorite_button.texture_hover = active if active else inactive
	_apply_favorite_button_backplate()
	_favorite_button.visible = false


func _apply_favorite_button_backplate() -> void:
	if _favorite_button == null:
		return
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.05, 0.07, 0.12, 0.62)
	plate.set_corner_radius_all(10)
	plate.set_content_margin_all(6)
	_favorite_button.add_theme_stylebox_override("normal", plate)
	var plate_hover := plate.duplicate() as StyleBoxFlat
	plate_hover.bg_color = Color(0.08, 0.1, 0.16, 0.78)
	_favorite_button.add_theme_stylebox_override("hover", plate_hover)
	var plate_pressed := plate.duplicate() as StyleBoxFlat
	plate_pressed.bg_color = Color(0.12, 0.1, 0.06, 0.85)
	_favorite_button.add_theme_stylebox_override("pressed", plate_pressed)


func _update_favorite_button(song_path: String) -> void:
	if _favorite_button == null:
		return
	song_path = String(song_path).strip_edges()
	if song_path == "":
		_favorite_button.visible = false
		return
	_favorite_button.visible = true
	var is_fav := PlayerDataManager != null and PlayerDataManager.is_song_favorite(song_path)
	if is_fav:
		_favorite_button.texture_normal = _SongFavoriteIcons.active_icon()
		_favorite_button.modulate = Color(1.0, 0.94, 0.72, 1.0)
		_favorite_button.tooltip_text = tr("SONG_FAVORITE_REMOVE")
	else:
		_favorite_button.texture_normal = _SongFavoriteIcons.inactive_icon()
		_favorite_button.modulate = Color(1, 1, 1, 0.92)
		_favorite_button.tooltip_text = tr("SONG_FAVORITE_ADD")


func _on_favorite_button_pressed() -> void:
	var song_path := String(current_displayed_song_path).strip_edges()
	if song_path == "" or PlayerDataManager == null:
		return
	var added := PlayerDataManager.toggle_song_favorite(song_path)
	if added:
		_UiMotionEffects.pop_favorite_star(_favorite_button)


func _on_favorite_songs_changed() -> void:
	_update_favorite_button(current_displayed_song_path)
	if song_list_manager == null:
		return
	if _search_bar and _search_bar.text.strip_edges() != "":
		song_list_manager.filter_items(_search_bar.text)
	else:
		song_list_manager.populate_items_grouped()
	_on_song_list_changed()


func _on_song_item_selected_from_manager(song_data: Dictionary):
	var enriched_song_data = song_data.duplicate()
	
	var song_path = song_data.get("path", "")
	
	if song_path != "":
		var metadata = SongLibrary.get_metadata_for_song(song_path)
		if not metadata.is_empty():
			for key in metadata:
				enriched_song_data[key] = metadata[key]
		var bpm_val := str(enriched_song_data.get("bpm", "")).strip_edges()
		if bpm_val == "":
			enriched_song_data["bpm"] = _SS._translate("VALUE_NA")
			SongLibrary.update_metadata(song_path, {"bpm": _SS._translate("VALUE_NA")})
	
	current_selected_song_data = enriched_song_data
	song_details_manager.stop_preview()
	song_details_manager.update_details(enriched_song_data)
	_update_track_medals_display(song_path)
	_update_favorite_button(song_path)
	_play_details_transition()
	
	var song_file_path = enriched_song_data.get("path", "")
	if song_file_path != "":
		current_displayed_song_path = song_file_path
		song_details_manager.play_song_preview(song_file_path)
		analyze_bpm_button.disabled = false
		results_button.disabled = false
		clear_results_button.disabled = false
		song_details_manager._update_play_button_state()
		_apply_background_status_ui()
	else:
		analyze_bpm_button.disabled = true
		results_button.disabled = true
		clear_results_button.disabled = true
	
	var song_bpm = enriched_song_data.get("bpm", "")
	if _SS.is_missing_metadata_value(song_bpm):
		analyze_bpm_button.text = _SS._translate("SONG_ANALYZE_BPM")
		$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/ActionsVBox/GenerateNotesButton.text = _SS._translate("SONG_GEN_NEED_BPM")
		$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/ActionsVBox/GenerateNotesButton.disabled = true
		$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/ActionsVBox/PlayButton.disabled = true
	else:
		analyze_bpm_button.text = _SS._translate("SONG_BPM_DONE")
		_set_generate_notes_button_idle()
		if _check_if_notes_exist_for_current_settings():
			$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/ActionsVBox/PlayButton.disabled = false
			song_details_manager._update_play_button_state()
		else:
			$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/ActionsVBox/PlayButton.disabled = true
			song_details_manager._update_play_button_state()
	_apply_background_status_ui()


func _on_song_item_activated_from_manager(song_data: Dictionary) -> void:
	if song_list_manager.is_edit_mode_active():
		return
	if song_data.is_empty():
		return
	var path := String(song_data.get("path", ""))
	if path != String(current_selected_song_data.get("path", "")):
		_on_song_item_selected_from_manager(song_data)
	if _play_button and not _play_button.disabled:
		_on_play_pressed()


func _on_song_list_heavy_rebuild_started() -> void:
	_song_list_loading_depth += 1
	if _song_list_loading_depth != 1:
		return
	var overlay := _get_loading_overlay()
	if overlay:
		overlay.show_loading(tr("UI_LOADING_SONG_LIST"), true)


func _on_song_list_heavy_rebuild_finished() -> void:
	_song_list_loading_depth = maxi(0, _song_list_loading_depth - 1)
	if _song_list_loading_depth != 0:
		return
	var overlay := _get_loading_overlay()
	if overlay:
		overlay.hide_loading()


func _on_song_list_changed():
	_update_song_count_label()
	call_deferred("_focus_song_list")

func _on_generation_settings_pressed():
	_UiModifierSounds.play_select()
	run_with_loading(tr("UI_LOADING_GEN_SETTINGS"), _open_generation_settings_selector)


func _suppress_favorite_for_overlay() -> void:
	if _favorite_button:
		_favorite_button.visible = false


func _open_generation_settings_selector():
	_suppress_favorite_for_overlay()
	if generation_settings_selector and is_instance_valid(generation_settings_selector):
		generation_settings_selector.queue_free()

	generation_settings_selector = load("res://scenes/song_select/dialogs/generation_settings_selector.tscn").instantiate()
	generation_settings_selector.generation_settings_confirmed.connect(_on_generation_settings_confirmed)
	generation_settings_selector.selector_closed.connect(_on_generation_settings_closed)
	if current_displayed_song_path != "":
		generation_settings_selector.set_current_song_data(current_selected_song_data)
	var host := get_parent()
	host.add_child(generation_settings_selector)
	host.move_child(generation_settings_selector, -1)
	UiInteractionApplier.apply_from_engine(generation_settings_selector)
	await get_tree().process_frame

func _is_song_metadata_edit_locked(song_path: String) -> bool:
	if not background_service:
		return false
	return background_service.is_song_metadata_edit_locked(song_path)


func _setup_details_cover_clip() -> void:
	var cover := get_node_or_null(
		"MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/CoverWrap/CoverTextureRect"
	) as TextureRect
	if cover:
		_UiRoundedClip.apply_to_canvas_item(cover, _COVER_CORNER_RADIUS)


func _editable_metadata_label_nodes() -> Array:
	return [
		$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/TitleLabel,
		$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/ArtistLabel,
		$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/YearLabel,
		$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/BpmLabel,
		$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/PrimaryGenreLabel
	]

func _update_metadata_edit_availability() -> void:
	var edit_active := song_list_manager.is_edit_mode_active()
	var locked := _is_song_metadata_edit_locked(current_displayed_song_path)
	var tint := Color(1.0, 1.0, 1.0, 1.0)
	var editable := edit_active and not locked
	if edit_active and locked:
		tint = Color(0.55, 0.55, 0.55, 1.0)
	elif edit_active:
		tint = Color(0.68235296, 0.75686276, 1.0, 1.0)
	for node in _editable_metadata_label_nodes():
		if node == null:
			continue
		node.self_modulate = tint
		if editable:
			node.set_meta("ui_force_cursor", Control.CURSOR_POINTING_HAND)
			node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			node.tooltip_text = _SS._translate("SONG_TOOLTIP_EDIT")
		else:
			if node.has_meta("ui_force_cursor"):
				node.remove_meta("ui_force_cursor")
			node.mouse_default_cursor_shape = Control.CURSOR_ARROW
			node.tooltip_text = ""
	_update_delete_button_state()

func _on_gui_input_for_label(event: InputEvent, field_type: String) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.double_click):
		return
	if not song_list_manager.is_edit_mode_active():
		return
	var selected_indices = song_item_list_ref.get_selected_items()
	if selected_indices.is_empty():
		return
	var song_data = song_list_manager.get_song_data_by_item_list_index(selected_indices[0])
	if song_data.is_empty():
		return
	song_list_manager.start_editing(field_type, song_data, selected_indices[0])

func _update_delete_button_state() -> void:
	var delete_button = $MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/ActionsVBox/DeleteButton
	if delete_button == null:
		return
	var gen_active := _is_song_metadata_edit_locked(current_displayed_song_path)
	var can_delete := SongLibrary.can_delete_song(current_displayed_song_path)
	delete_button.disabled = gen_active or current_displayed_song_path == "" or not can_delete
	if current_displayed_song_path != "" and not can_delete:
		delete_button.tooltip_text = _SS._translate("SONG_TOOLTIP_BUILTIN_DELETE")
	else:
		delete_button.tooltip_text = ""

func _toggle_edit_mode():
	var entering := not song_list_manager.is_edit_mode_active()
	song_list_manager.set_edit_mode(entering)
	_UiModifierSounds.play_toggle(entering)
	_update_edit_button_style()
	_update_metadata_edit_availability()
	_update_filters_visibility()

func _update_edit_button_style():
	if song_list_manager.is_edit_mode_active():
		edit_button.self_modulate = Color(0.8, 0.8, 1.0, 1.0)
		edit_button.text = _SS._translate("SONG_EDIT_ON")
	else:
		edit_button.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
		edit_button.text = _SS._translate("SONG_EDIT")
	_refresh_toolbar_icon_tints()


func _on_generate_pressed():
	if _generate_notes_button == null or _generate_notes_button.disabled:
		return
	_pop_button(_generate_notes_button)
	await _generate_notes_for_current_song()


func _tr_format(key: String, args: Array) -> String:
	var parts: Array[String] = []
	for a in args:
		parts.append(str(a))
	return tr(key) % parts


func _confirm_action(title: String, message: String, ok_text: String) -> bool:
	var accepted := await _Overlay.ask(
		_confirm_overlay,
		message,
		"warning",
		title,
		ok_text,
	)
	# Overlay leaves focus on a hidden confirm button — restore list so arrows sync.
	call_deferred("_focus_song_list")
	return accepted


func _confirm_regeneration_enabled() -> bool:
	return bool(SettingsManager.get_setting("generation_confirm_before_rerun", true))


func _ensure_choice_overlay() -> AppChoiceOverlay:
	if _choice_overlay != null and is_instance_valid(_choice_overlay):
		return _choice_overlay
	_choice_overlay = CHOICE_OVERLAY_SCENE.instantiate() as AppChoiceOverlay
	if _choice_overlay:
		add_child(_choice_overlay)
	return _choice_overlay


func _active_generation_preset_slot() -> int:
	return NotesUtils.get_active_generation_preset_slot()


func _should_block_mass_generation(_scope: int = 0) -> bool:
	return _scope_is_mass() and _active_generation_preset_slot() > 0


func _prompt_dirty_preset_generation() -> String:
	var overlay := _ensure_choice_overlay()
	if overlay == null:
		return "cancel"
	return await _Overlay.choose(
		overlay,
		tr("GEN_PRESET_DIRTY_GEN_TITLE"),
		"warning",
		"",
		tr("GEN_PRESET_DIRTY_GEN_SAVE"),
		tr("BTN_CANCEL"),
		tr("GEN_PRESET_DIRTY_GEN_TEMP"),
	)


func _scope_is_mass(_scope: int = 0) -> bool:
	return _GoalDiff.ready_axes_is_mass(_GoalDiff.resolve_ready_axes({}, "", "", current_instrument))


func _chart_tag_for_generation_job(mode: String, custom_chart_tag: String) -> String:
	if mode != "custom":
		return ""
	return custom_chart_tag


func _collect_missing_generation_jobs(song_path: String, custom_chart_tag: String = "") -> Array:
	var axes := _GoalDiff.resolve_ready_axes({}, "", "", current_instrument)
	var stems := _GoalDiff.stems_for_ready_axes(axes.get("goals", []), axes.get("diffs", []))
	var instruments: Array = axes.get("instruments", [current_instrument])
	var jobs: Array = []
	for inst_raw in instruments:
		var inst := str(inst_raw)
		for stem_id in stems:
			var tag := _chart_tag_for_generation_job(current_generation_mode, custom_chart_tag)
			if not NotesUtils.notes_exist(song_path, inst, stem_id, current_lanes, tag):
				var pair := _GoalDiff.pair_from_stem(stem_id)
				jobs.append(_generation_job_dict(
					str(pair.get("goal", _GoalDiff.DEFAULT_GOAL)),
					str(pair.get("difficulty", _GoalDiff.DEFAULT_DIFFICULTY)),
					stem_id,
					current_lanes,
					inst,
				))
	return jobs


func _generation_job_dict(goal_v: String, diff_v: String, stem: String, lanes: int, instrument: String = "") -> Dictionary:
	return {
		"mode": current_generation_mode,
		"chart_intent": _GoalDiff.intent_for(goal_v, diff_v),
		"chart_stem": stem,
		"goal": goal_v,
		"difficulty": diff_v,
		"lanes": lanes,
		"instrument": instrument if instrument != "" else current_instrument,
	}


func _collect_all_generation_jobs(song_path: String) -> Array:
	var axes := _GoalDiff.resolve_ready_axes({}, "", "", current_instrument)
	var stems := _GoalDiff.stems_for_ready_axes(axes.get("goals", []), axes.get("diffs", []))
	var instruments: Array = axes.get("instruments", [current_instrument])
	var jobs: Array = []
	for inst_raw in instruments:
		var inst := str(inst_raw)
		for stem_id in stems:
			var pair := _GoalDiff.pair_from_stem(stem_id)
			jobs.append(_generation_job_dict(
				str(pair.get("goal", _GoalDiff.DEFAULT_GOAL)),
				str(pair.get("difficulty", _GoalDiff.DEFAULT_DIFFICULTY)),
				stem_id,
				current_lanes,
				inst,
			))
	return jobs

func _generate_notes_for_current_song():
	var song_path = current_selected_song_data.get("path", "")
	if song_path == "": return
	var song_title := String(current_selected_song_data.get("title", song_path.get_file())).strip_edges()
	if song_title == "":
		song_title = song_path.get_file()
	
	var song_bpm = current_selected_song_data.get("bpm", -1)
	if _SS.is_missing_metadata_value(song_bpm):
		var meta_bpm = SongLibrary.get_metadata_for_song(song_path).get("bpm", "")
		if _SS.is_missing_metadata_value(meta_bpm):
			return
		song_bpm = str(meta_bpm)
		current_selected_song_data["bpm"] = song_bpm

	var metadata = SongLibrary.get_metadata_for_song(song_path)
	var has_genres := false
	if metadata.has("genres"):
		if typeof(metadata["genres"]) == TYPE_ARRAY:
			has_genres = metadata["genres"].size() > 0
		else:
			has_genres = str(metadata["genres"]).strip_edges() != ""
	if not has_genres and metadata.has("primary_genre"):
		var pg = str(metadata["primary_genre"]).strip_edges().to_lower()
		has_genres = (pg != "" and pg != "unknown")
	var enable_genre_detection = SettingsManager.get_setting("enable_genre_detection", true)

	var auto_identify := true
	var manual_artist := ""
	var manual_title := ""
	if has_genres:
		auto_identify = false
	elif not enable_genre_detection:
		auto_identify = false
		manual_artist = "Unknown"
		manual_title = "Unknown"

	if not background_service:
		_StatusToast.show_from_node(self, "gen_no_service", tr("SONG_GEN_SERVICE_UNAVAILABLE"), "warning", 3.0)
		return

	var queue_lookup := _generation_queue_lookup_key()
	if background_service.get_notes_queue_position(
		song_path, current_instrument, queue_lookup, current_lanes
	) > 0:
		_StatusToast.show_from_node(self, "gen_queue_dup", tr("GEN_QUEUE_ALREADY"), "info", 2.5)
		_apply_background_status_ui()
		return

	var scope_mass := _scope_is_mass()
	if _should_block_mass_generation():
		await _Overlay.ask(
			_confirm_overlay,
			tr("GEN_PRESET_MASS_BLOCKED"),
			"warning",
			"",
			tr("BTN_OK"),
		)
		return

	var generation_chart_tag := ""
	if current_generation_mode == "custom" and _active_generation_preset_slot() > 0:
		if _UserPresets.is_active_generation_preset_dirty():
			var dirty_choice := await _prompt_dirty_preset_generation()
			if dirty_choice == "cancel":
				return
			if dirty_choice == "confirm":
				_UserPresets.save_active_generation_preset_body()
				generation_chart_tag = NotesUtils.chart_tag_for_preset_slot(_active_generation_preset_slot())
			else:
				generation_chart_tag = ""
		else:
			generation_chart_tag = NotesUtils.chart_tag_for_preset_slot(_active_generation_preset_slot())

	var missing_jobs: Array = _collect_missing_generation_jobs(song_path, generation_chart_tag)
	var all_jobs: Array = _collect_all_generation_jobs(song_path)
	# Align with missing_jobs (intent/tag), not legacy current_generation_mode ("basic").
	var notes_ready := missing_jobs.is_empty() and not all_jobs.is_empty()
	var include_existing := false

	if notes_ready:
		if not _confirm_regeneration_enabled():
			include_existing = true
		else:
			var ready_msg := _tr_format("SONG_GEN_CONFIRM_ALREADY_READY", [song_title, _SS.format_gen_settings_label(current_instrument, current_lanes, _saved_generation_goal(), _saved_generation_difficulty())])
			if not await _confirm_action(tr("SONG_GEN_CONFIRM_TITLE"), ready_msg, tr("SONG_GEN_CONFIRM_CONTINUE")):
				return
			include_existing = true
	elif scope_mass:
		var existing_count: int = maxi(0, all_jobs.size() - missing_jobs.size())
		if existing_count > 0 and missing_jobs.size() > 0:
			if not _confirm_regeneration_enabled():
				include_existing = true
			else:
				var regen_msg := _tr_format("SONG_GEN_CONFIRM_MASS_REGEN", [song_title, existing_count, missing_jobs.size()])
				if not await _confirm_action(tr("SONG_GEN_CONFIRM_TITLE"), regen_msg, tr("SONG_GEN_CONFIRM_REGEN_ALL")):
					return
				include_existing = true

	var jobs: Array = all_jobs if include_existing else missing_jobs
	if jobs.is_empty():
		if notes_ready and _confirm_regeneration_enabled():
			return
		_StatusToast.show_from_node(self, "gen_no_jobs", tr("SONG_GEN_NOTHING_TO_DO"), "info", 2.5)
		return

	var bpm_f := float(song_bpm)
	var saw_duplicate := false
	for job in jobs:
		var mode: String = str(job.get("mode", current_generation_mode))
		var lanes: int = int(job.get("lanes", current_lanes))
		var job_instrument := str(job.get("instrument", current_instrument))
		var chart_tag := ""
		if not scope_mass:
			if mode == "custom":
				chart_tag = generation_chart_tag
		var chart_intent := str(job.get("chart_intent", "")).strip_edges()
		if chart_intent == "":
			chart_intent = str(SettingsManager.get_setting("last_generation_intent", "original")).strip_edges()
		if chart_intent == "":
			chart_intent = GenerationIntents.resolve_chart_stem(mode)
		var api_mode := mode
		if GenerationIntents.is_chart_intent(mode):
			api_mode = GenerationIntents.intent_to_legacy_mode(mode)
		elif chart_intent != "":
			api_mode = GenerationIntents.intent_to_legacy_mode(chart_intent)
		var job_goal := str(job.get("goal", "")).strip_edges()
		var job_difficulty := str(job.get("difficulty", "")).strip_edges()
		if job_goal == "":
			job_goal = _saved_generation_goal()
		if job_difficulty == "":
			job_difficulty = _saved_generation_difficulty()
		var pos := background_service.start_notes_generation(
			song_path,
			job_instrument,
			bpm_f,
			lanes,
			0.2,
			auto_identify,
			manual_artist,
			manual_title,
			api_mode,
			chart_tag,
			chart_intent,
			job_goal,
			job_difficulty,
		)
		if pos == 0:
			saw_duplicate = true
	if saw_duplicate:
		_StatusToast.show_from_node(self, "gen_queue_dup", tr("GEN_QUEUE_ALREADY"), "info", 2.5)
	_apply_background_status_ui()

func _on_delete_pressed():
	var song_path := String(current_selected_song_data.get("path", current_displayed_song_path)).strip_edges()
	if song_path == "":
		return
	if _is_song_metadata_edit_locked(song_path):
		return
	if not SongLibrary.can_delete_song(song_path):
		_show_delete_notice(_SS._translate("SONG_DELETE_BUILTIN"))
		return

	var title := str(current_selected_song_data.get("title", song_path.get_file()))
	_request_delete_song(song_path, title)


func _request_delete_song(song_path: String, title: String) -> void:
	if await _Overlay.ask(
		_confirm_overlay,
		_SS._translate("SONG_DELETE_CONFIRM") % title,
		"danger",
		tr("SONG_DELETE_TITLE"),
		tr("SONG_DELETE"),
	):
		_perform_delete_song(song_path)


func _show_delete_notice(text: String) -> void:
	_Overlay.notify(_notice_overlay, text)

func _on_song_add_rejected(reject_info: Dictionary) -> void:
	var artist := str(reject_info.get("artist", "")).strip_edges()
	var title := str(reject_info.get("title", "")).strip_edges()
	var label := title
	if artist != "" and title != "":
		label = "%s — %s" % [artist, title]
	elif artist != "":
		label = artist
	if label == "":
		label = str(reject_info.get("existing_path", "")).get_file()
	_show_delete_notice(_SS._translate("SONG_DUPLICATE_MSG") % label)

func _perform_delete_song(song_path: String) -> void:
	song_details_manager.stop_preview()
	if not SongLibrary.delete_song(song_path):
		printerr("SongSelect.gd: Не удалось удалить файл: ", song_path)
		_show_delete_notice(_SS._translate("SONG_DELETE_FAIL"))
		return

	if PlayerDataManager:
		PlayerDataManager.remove_favorite_song(song_path)

	results_manager.clear_results_for_song(song_path)
	NotesUtils.delete_notes_for_song(song_path)

	SongLibrary.load_songs()
	song_list_manager.populate_items_grouped()
	_on_song_list_changed()

	current_selected_song_data = {}
	current_displayed_song_path = ""
	song_details_manager.update_details({})
	_update_favorite_button("")
	analyze_bpm_button.disabled = true
	results_button.disabled = true
	clear_results_button.disabled = true
	_apply_bpm_dependent_ui()
	_update_metadata_edit_availability()

func _on_results_pressed():
	var song_item_list = $MainVBox/ContentHBox/ListPanel/ListMargin/SongListVBox/SongItemList
	var results_list = $MainVBox/ContentHBox/ListPanel/ListMargin/SongListVBox/ResultsItemList
	
	if song_item_list.visible:
		song_item_list.visible = false
		results_list.visible = true
		clear_results_button.visible = true
		results_manager.show_results_for_song(current_selected_song_data, results_list)
	else:
		results_list.visible = false
		song_item_list.visible = true
		clear_results_button.visible = false

func _on_clear_results_pressed():
	var song_path = current_selected_song_data.get("path", "")
	if song_path.is_empty(): return
	
	if results_manager.clear_results_for_song(song_path):
		var results_list = $MainVBox/ContentHBox/ListPanel/ListMargin/SongListVBox/ResultsItemList
		results_manager.show_results_for_song(current_selected_song_data, results_list)
		_update_track_medals_display(song_path)

func _on_analyze_bpm_pressed():
	if background_service and background_service.is_notes_pipeline_busy():
		return
	var selected_items = song_item_list_ref.get_selected_items()
	if selected_items.size() == 0: return
	
	var selected_song_data = song_list_manager.get_song_data_by_item_list_index(selected_items[0])
	if selected_song_data.is_empty(): return
	
	var song_path = selected_song_data.get("path", "")
	if song_path == "": return
	var selected_bpm := String(selected_song_data.get("bpm", "")).strip_edges()
	if not _SS.is_missing_metadata_value(selected_bpm):
		if _confirm_regeneration_enabled():
			var title := String(selected_song_data.get("title", song_path.get_file())).strip_edges()
			if title == "":
				title = song_path.get_file()
			var msg := tr("SONG_BPM_CONFIRM_RECALC") % [title, selected_bpm]
			if not await _confirm_action(tr("SONG_BPM_CONFIRM_TITLE"), msg, tr("SONG_GEN_CONFIRM_CONTINUE")):
				return
	
	$MainVBox/ContentHBox/DetailsPanel/DetailsMargin/DetailsVBox/DetailsInfoScroll/DetailsInfoVBox/BpmLabel.text = _SS._translate("SONG_BPM_LOADING")
	if background_service:
		var bpm_pos := background_service.start_bpm_analysis(song_path)
		if bpm_pos == 0:
			_StatusToast.show_from_node(self, "gen_queue_dup", tr("GEN_QUEUE_ALREADY"), "info", 2.5)
		_apply_background_status_ui()

func _on_play_pressed():
	if current_selected_song_data.is_empty():
		printerr("SongSelect.gd: Нет выбранной песни!")
		return

	MusicManager.play_restart_sound()
	var chart_tag := NotesUtils.resolve_play_chart_tag(
		str(current_selected_song_data.get("path", "")),
		current_instrument,
		current_generation_mode,
		current_lanes,
	)
	var lookup_key := GenerationIntents.chart_lookup_key(current_generation_mode, _saved_generation_intent())
	transitions.open_game_with_song(
		current_selected_song_data,
		current_instrument,
		results_manager,
		lookup_key,
		current_lanes,
		active_run_modifiers.duplicate(),
		chart_tag,
	)
	
func _update_song_count_label():
	song_list_manager.update_song_count_label($MainVBox/TopBarPanel/TopBarHBox/SongCountLabel)

 
	
func _on_generation_settings_confirmed(instrument: String, mode: String, lanes: int):
	current_instrument = instrument
	current_generation_mode = mode
	current_lanes = lanes
	
	song_details_manager.set_current_instrument(current_instrument)
	song_details_manager.set_current_generation_mode(current_generation_mode)
	song_details_manager.set_current_lanes(lanes)
	song_list_manager.set_generation_settings(current_instrument, current_generation_mode, current_lanes)
	
	$MainVBox/TopBarPanel/TopBarHBox/GenerationSettingsButton.text = _format_generation_settings_label(instrument, mode, lanes)
	_apply_background_status_ui()
	_show_gen_settings_toast(instrument, mode, lanes)


func _show_gen_settings_toast(instrument: String, mode: String, lanes: int) -> void:
	var text := _SS.format_gen_settings_toast(
		instrument,
		lanes,
		_saved_generation_goal(),
		_saved_generation_difficulty(),
	)
	var kind := "drums" if instrument == "drums" else "music"
	_StatusToast.show_from_node(self, "gen_settings", text, kind, 2.5)

func _on_generation_queue_changed(snapshot: Dictionary) -> void:
	_apply_background_status_ui()
	_schedule_list_highlight_refresh(snapshot)


func _schedule_list_highlight_refresh(snapshot: Dictionary) -> void:
	var paths := _paths_from_queue_snapshot(snapshot)
	if paths.is_empty():
		return
	for path_key in paths:
		if path_key not in _pending_highlight_paths:
			_pending_highlight_paths.append(path_key)
	if _list_highlight_pending:
		return
	_list_highlight_pending = true
	call_deferred("_flush_list_highlight_refresh")


func _flush_list_highlight_refresh() -> void:
	_list_highlight_pending = false
	if _pending_highlight_paths.is_empty():
		return
	var paths: Array = _pending_highlight_paths.duplicate()
	_pending_highlight_paths.clear()
	refresh_generation_notes_highlights(paths)
	if current_displayed_song_path != "":
		var shown := current_displayed_song_path.replace("\\", "/")
		for path_key in paths:
			if _song_path_key(path_key) == _song_path_key(shown):
				song_details_manager._update_play_button_state()
				song_details_manager._update_generation_status()
				if current_displayed_song_path != "":
					_set_generate_notes_button_idle()
				break


func _paths_from_queue_snapshot(snapshot: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var seen: Dictionary = {}
	for item in snapshot.get("items", []):
		if not item is Dictionary:
			continue
		var path := String((item as Dictionary).get("path", "")).replace("\\", "/")
		if path == "" or seen.has(path):
			continue
		seen[path] = true
		out.append(path)
	for entry in snapshot.get("history", []):
		if not entry is Dictionary:
			continue
		var path := String((entry as Dictionary).get("path", "")).replace("\\", "/")
		if path == "" or seen.has(path):
			continue
		seen[path] = true
		out.append(path)
	return out


func _apply_background_status_ui() -> void:
	if _bg_status_ui_pending:
		return
	_bg_status_ui_pending = true
	call_deferred("_flush_background_status_ui")


func _flush_background_status_ui() -> void:
	_bg_status_ui_pending = false
	if not background_service:
		return
	var notes_busy := background_service.is_notes_pipeline_busy()
	var pos_bpm = background_service.get_bpm_queue_position(current_displayed_song_path)
	if notes_busy:
		analyze_bpm_button.disabled = true
		if pos_bpm == 0:
			analyze_bpm_button.text = _SS._translate("SONG_ANALYZE_BPM")
	elif pos_bpm == 1:
		analyze_bpm_button.text = _SS._translate("SONG_ANALYZE_PROGRESS")
		analyze_bpm_button.disabled = true
	elif pos_bpm > 1:
		analyze_bpm_button.text = _SS._translate("SONG_ANALYZE_QUEUE") % pos_bpm
		analyze_bpm_button.disabled = true
	else:
		var song_bpm_for_btn = current_selected_song_data.get("bpm", "")
		if _SS.is_missing_metadata_value(song_bpm_for_btn):
			analyze_bpm_button.text = _SS._translate("SONG_ANALYZE_BPM")
		else:
			analyze_bpm_button.text = _SS._translate("SONG_BPM_DONE")
		analyze_bpm_button.disabled = current_displayed_song_path == ""
	var queue_lookup := _generation_queue_lookup_key()
	var pos_notes = background_service.get_notes_queue_position(
		current_displayed_song_path, current_instrument, queue_lookup, current_lanes
	)
	var pos_notes_song = background_service.get_notes_queue_position_for_song(current_displayed_song_path)
	if pos_notes == 1:
		_generate_notes_button.text = _SS._translate("SONG_GEN_PROGRESS")
		_generate_notes_button.disabled = true
		_generate_notes_button.tooltip_text = tr("SONG_GEN_TOOLTIP_IN_PROGRESS")
	elif pos_notes > 1:
		_generate_notes_button.text = _SS._translate("SONG_GEN_QUEUE") % pos_notes
		_generate_notes_button.disabled = true
		_generate_notes_button.tooltip_text = tr("SONG_GEN_TOOLTIP_QUEUED")
	elif pos_notes_song > 1:
		_generate_notes_button.text = _SS._translate("SONG_GEN_QUEUE") % pos_notes_song
		_generate_notes_button.disabled = true
		_generate_notes_button.tooltip_text = tr("SONG_GEN_TOOLTIP_QUEUED")
	else:
		var song_bpm_val = current_selected_song_data.get("bpm", "")
		if not _SS.is_missing_metadata_value(song_bpm_val):
			_set_generate_notes_button_idle()
			if pos_notes_song > 0:
				_generate_notes_button.tooltip_text = tr("SONG_GEN_TOOLTIP_QUEUE_OTHER")
			else:
				_generate_notes_button.tooltip_text = ""
		else:
			_generate_notes_button.text = _SS._translate("SONG_GEN_NEED_BPM")
			_generate_notes_button.disabled = true
			_generate_notes_button.tooltip_text = ""
	_update_metadata_edit_availability()

func _format_generation_settings_label(instrument: String, _mode: String, lanes: int) -> String:
	return _SS.format_gen_style_button_label(
		instrument,
		lanes,
		_saved_generation_goal(),
		_saved_generation_difficulty(),
	)


func _saved_generation_intent() -> String:
	return str(SettingsManager.get_setting("last_generation_intent", "original"))


func _saved_generation_goal() -> String:
	return str(SettingsManager.get_setting("generation_goal", "original"))


func _saved_generation_difficulty() -> String:
	return str(SettingsManager.get_setting("generation_difficulty", "standard"))
func _on_generation_settings_closed():
	if generation_settings_selector and is_instance_valid(generation_settings_selector):
		generation_settings_selector.queue_free()
		generation_settings_selector = null
	_UiModifierSounds.play_deselect()
	_update_favorite_button(current_displayed_song_path)
	call_deferred("_focus_song_list")
		
func _on_song_metadata_updated(song_file_path: String):
	var norm_path := String(song_file_path).replace("\\", "/")
	var norm_current := String(current_displayed_song_path).replace("\\", "/")
	if norm_current == norm_path:
		for song in SongLibrary.get_songs_list():
			if song.path == song_file_path:
				song_details_manager.update_details(song)
				break
	if song_list_manager:
		var persisted := SongLibrary.get_display_metadata_for_song(song_file_path)
		if not persisted.is_empty():
			var idx := song_list_manager.find_item_list_index_for_path(song_file_path)
			if idx >= 0 and song_list_manager.update_song_at_index(idx, persisted):
				return
		var search_bar = $MainVBox/TopBarPanel/TopBarHBox/SearchBar
		if search_bar:
			var q = String(search_bar.text)
			song_list_manager.filter_items(q, true)
		else:
			song_list_manager.populate_items_grouped(true)

func _on_songs_list_changed_from_library():
	if song_list_manager:
		var search_bar = $MainVBox/TopBarPanel/TopBarHBox/SearchBar
		if search_bar:
			var q = String(search_bar.text)
			song_list_manager.filter_items(q)
		else:
			song_list_manager.populate_items_grouped()
		_on_song_list_changed()

func _execute_close_transition() -> void:
	if transitions:
		transitions.close_song_select()


func cleanup_before_exit():
	_persist_song_select_filters()
	song_details_manager.stop_preview()

func get_current_selected_song() -> Dictionary:
	return current_selected_song_data.duplicate()

func get_results_manager():
	return results_manager
	
func _check_if_notes_exist_for_current_settings() -> bool:
	var song_path := String(current_selected_song_data.get("path", "")).strip_edges()
	if song_path == "":
		return false
	var chart_tag := ""
	if current_generation_mode == "custom" and _active_generation_preset_slot() > 0:
		if not _UserPresets.is_active_generation_preset_dirty():
			chart_tag = NotesUtils.chart_tag_for_preset_slot(_active_generation_preset_slot())
	return _collect_missing_generation_jobs(song_path, chart_tag).is_empty() \
		and not _collect_all_generation_jobs(song_path).is_empty()

func refresh_generation_notes_highlights(paths: Array = []):
	if paths.is_empty():
		song_list_manager.refresh_highlight_for_current_settings()
	else:
		song_list_manager.refresh_highlights_for_paths(paths, true)
	song_details_manager._update_play_button_state()
	song_details_manager._update_generation_status()
	if current_displayed_song_path != "":
		_apply_background_status_ui()


func refresh_chart_id_visibility() -> void:
	if song_details_manager and song_details_manager.has_method("refresh_chart_id_visibility"):
		song_details_manager.refresh_chart_id_visibility()


func refresh_rhythm_dna_button_visibility() -> void:
	if song_details_manager and song_details_manager.has_method("refresh_rhythm_dna_button_visibility"):
		song_details_manager.refresh_rhythm_dna_button_visibility()
