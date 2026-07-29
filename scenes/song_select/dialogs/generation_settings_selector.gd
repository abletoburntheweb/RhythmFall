# scenes/song_select/generation_settings_selector.gd
class_name GenerationSettingsSelector
extends Control

const _SS = preload("res://logic/domain/library/song_select_strings.gd")
const _SettingsSectionUi = preload("res://logic/ui/settings_section_ui.gd")
const _Recommender = preload("res://logic/domain/library/generation_preset_recommender.gd")
const _SpotlightTutorialScene = preload("res://ui/spotlight_tutorial.tscn")
const _UserPresets = preload("res://logic/domain/modifiers/user_presets.gd")
const _UiModifierSounds = preload("res://logic/ui/ui_modifier_sounds.gd")
const _GenPresetUi = preload("res://logic/ui/generation_preset_ui.gd")
const _Intents = preload("res://logic/domain/generation/generation_intents.gd")
const _GoalDiff = preload("res://logic/domain/generation/generation_goal_difficulty.gd")
const _SegmentedOptionUtils = preload("res://logic/ui/segmented_option_utils.gd")
const _PreviewRowScene = preload("res://scenes/song_select/endless/session_setup_preview_row.gd")
const PRESETS_DIALOG_SCENE = preload("res://scenes/song_select/run_modifiers/modifier_presets_dialog.tscn")
const _PresetActiveHeader = preload("res://logic/ui/preset_active_header.gd")

const _STATUS_PANEL_WIDTH := 220.0
const _NAV_LEFT := 16.0
const _NAV_TOP := 16.0
const _NAV_GAP_AFTER_BACK := 12.0

signal generation_settings_confirmed(instrument: String, mode: String, lanes: int)
signal selector_closed

var selected_instrument: String = "drums"
var selected_goal: String = "original"
var selected_difficulty: String = "standard"
## Last Arcade tier while Original hides the difficulty row.
var _arcade_difficulty_memory: String = "standard"
var selected_intent: String = "original"
var selected_mode: String = "basic"
var selected_lanes: int = 4
var selected_fill: int = 50
var selected_groove: int = 50
var selected_density: int = 50
var selected_grid_snap_strength: int = 80
var selected_accent_strong_beats: bool = true
var selected_genre_template_strength: int = 60
var selected_enable_genre_detection: bool = true
var selected_use_stems_in_generation: bool = true
var selected_include_hi_hats: bool = true
var selected_critic_strength: int = 50
var selected_groove_completion: bool = true
var selected_raw_adtof: bool = false
var current_song_path: String = ""
var current_song_data: Dictionary = {}
var smart_hint_label: Label = null
var smart_warn_label: Label = null
var status_hint_label: Label = null
var _smart_recommendation: Dictionary = {}

var status_label: Label = null
var status_title_label: Label = null
var fill_slider: HSlider = null
var groove_slider: HSlider = null
var density_slider: HSlider = null
var grid_snap_strength_slider: HSlider = null
var accent_strong_beats_checkbox: BaseButton = null
var genre_template_strength_slider: HSlider = null
var fill_label: Label = null
var groove_label: Label = null
var density_label: Label = null
var grid_snap_label: Label = null
var genre_template_label: Label = null
var enable_genre_detection_checkbox: BaseButton = null
var enable_stems_checkbox: BaseButton = null
var include_hi_hats_checkbox: BaseButton = null
var groove_completion_checkbox: BaseButton = null
var raw_adtof_checkbox: BaseButton = null
var critic_strength_slider: HSlider = null
var critic_strength_label: Label = null
var advanced_toggle_button: Button = null
var advanced_container: Control = null
var _back_button: Button = null
var _presets_button: Button = null
var _mode_help_btn: Button = null
var _screen_margin: MarginContainer = null
var _track_status_panel: PanelContainer = null
var _preview_panel: PanelContainer = null
var _preview_hero_label: Label = null
var _preview_blurb_label: Label = null
var _preview_rows_vbox: VBoxContainer = null
var _preview_status_label: Label = null
var _preview_status_hint_label: Label = null
var _preview_rows: Dictionary = {}
var _difficulty_option: OptionButton = null
var _difficulty_blurb_label: Label = null
var _difficulty_seg: Dictionary = {}

var _applying_ui_state: bool = false
var _instrument_cards: Dictionary = {}
var _goal_cards: Dictionary = {}
var _lane_buttons: Dictionary = {}
var _spotlight_tutorial: CanvasLayer = null
var _presets_dialog: Control = null
var _preset_active_slot: int = 0
var _preset_baseline: Dictionary = {}
var _active_preset_row: HBoxContainer = null
var _intent_card_pick_guard: bool = false
var _style_reset_button: Button = null

const ACTIVE_COLOR := Color(0.8, 0.8, 1.0, 1.0)
const DEFAULT_COLOR := Color(1.0, 1.0, 1.0, 1.0)

const INTENTS := _Intents.INTENTS
const _LANE_BUTTON_LANES := {
	"LaneButton3": 3,
	"LaneButton4": 4,
	"LaneButton5": 5,
}
const ROOT := "ScreenMargin/Container"
const INSTRUMENT_GRID := ROOT + "/BodyHBox/InstrumentPanel/InstrumentPanelVBox/InstrumentGrid"
const MODE_SECTION := ROOT + "/BodyHBox/MainScroll/MainVBox/ModeSection/ModeSectionVBox"
const GOAL_ROW := MODE_SECTION + "/ModeCardsRow"
const DIFFICULTY_SECTION := ROOT + "/BodyHBox/MainScroll/MainVBox/DifficultySection/DifficultySectionVBox"
const DIFFICULTY_OPTION := DIFFICULTY_SECTION + "/DifficultyOptionRow/DifficultyOption"
const PREVIEW_ROOT := ROOT + "/BodyHBox/PreviewPanel/PreviewMargin/PreviewVBox"
const LANES_ROW := ROOT + "/BodyHBox/MainScroll/MainVBox/LanesSection/LanesSectionVBox/LanesButtons"
const ADVANCED := ROOT + "/BodyHBox/MainScroll/MainVBox/AdvancedSection/AdvancedSectionVBox"
const FOOTER := ROOT + "/FooterRow"

const INSTRUMENT_ICONS := _GenPresetUi.INSTRUMENT_ICONS
const INTENT_ICONS := _GenPresetUi.INTENT_ICONS
const INTENT_ICON_COLORS := _GenPresetUi.INTENT_ICON_COLORS
const SECTION_ICON_COLOR := UiIconHelper.ACCENT
const PARAM_ICON_COLORS := _GenPresetUi.PARAM_ICON_COLORS
const INSTRUMENT_ICON_COLORS := _GenPresetUi.INSTRUMENT_ICON_COLORS
const PARAM_ICONS := _GenPresetUi.PARAM_ICONS

const INSTRUMENT_SPECS := [
	{"id": "drums", "title_key": "GEN_INST_DRUMS", "desc_key": "GEN_INST_DRUMS_DESC", "badge_key": "", "enabled": true},
	{"id": "fullmix", "title_key": "GEN_INST_FULLMIX", "desc_key": "GEN_INST_FULLMIX_DESC", "badge_key": "GEN_SOON", "enabled": false},
	{"id": "bass", "title_key": "GEN_INST_BASS", "desc_key": "GEN_INST_BASS_DESC", "badge_key": "GEN_BETA", "enabled": true},
	{"id": "guitar", "title_key": "GEN_INST_GUITAR", "desc_key": "GEN_INST_GUITAR_DESC", "badge_key": "GEN_SOON", "enabled": false},
	{"id": "keys", "title_key": "GEN_INST_KEYS", "desc_key": "GEN_INST_KEYS_DESC", "badge_key": "GEN_SOON", "enabled": false},
	{"id": "vocals", "title_key": "GEN_INST_VOCALS", "desc_key": "GEN_INST_VOCALS_DESC", "badge_key": "GEN_SOON", "enabled": false},
]

const GOAL_SPECS := [
	{"id": "original", "title_key": "GEN_GOAL_ORIGINAL", "desc_key": "GEN_GOAL_DESC_ORIGINAL", "badge_key": "", "locked": false},
	{"id": "arcade", "title_key": "GEN_GOAL_ARCADE", "desc_key": "GEN_GOAL_DESC_ARCADE", "badge_key": "", "locked": false},
]

const INTENT_SPECS := [
	{"id": "original", "title_key": "GEN_INTENT_ORIGINAL", "desc_key": "GEN_INTENT_DESC_ORIGINAL", "badge_key": "", "locked": false},
	{"id": "groove", "title_key": "GEN_INTENT_GROOVE", "desc_key": "GEN_INTENT_DESC_GROOVE", "badge_key": "", "locked": false},
	{"id": "arcade", "title_key": "GEN_INTENT_ARCADE", "desc_key": "GEN_INTENT_DESC_ARCADE", "badge_key": "GEN_SOON", "locked": true},
	{"id": "sparse", "title_key": "GEN_INTENT_SPARSE", "desc_key": "GEN_INTENT_DESC_SPARSE", "badge_key": "", "locked": false},
]


func _ready() -> void:
	UiIconHelper.configure_modal_overlay(self, 100)
	_applying_ui_state = true
	var background := $Background
	if background:
		background.color = Color(0.02, 0.03, 0.06, 0.97)
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	selected_instrument = SettingsManager.get_setting("last_generation_instrument", "drums")
	if selected_instrument not in ["drums", "bass"]:
		selected_instrument = "drums"
	selected_mode = SettingsManager.get_setting("last_generation_mode", "basic")
	var saved_intent := str(SettingsManager.get_setting("last_generation_intent", "")).strip_edges()
	if saved_intent != "" and saved_intent in INTENTS:
		selected_intent = saved_intent
	elif selected_mode == "custom":
		selected_intent = _Intents.closest_intent_for_params(_current_param_snapshot())
		if selected_intent == "":
			selected_intent = "groove"
	else:
		selected_intent = _Intents.migrate_legacy_mode(selected_mode)
	var saved_goal := str(SettingsManager.get_setting("generation_goal", "")).strip_edges()
	var saved_difficulty := str(SettingsManager.get_setting("generation_difficulty", "")).strip_edges()
	if _GoalDiff.is_goal(saved_goal) and _GoalDiff.is_difficulty(saved_difficulty):
		selected_goal = saved_goal
		selected_difficulty = saved_difficulty
	else:
		var migrated := _GoalDiff.from_intent(selected_intent)
		selected_goal = str(migrated.get("goal", _GoalDiff.DEFAULT_GOAL))
		selected_difficulty = str(migrated.get("difficulty", _GoalDiff.DEFAULT_DIFFICULTY))
	selected_intent = _GoalDiff.intent_for(selected_goal, selected_difficulty)
	selected_lanes = SettingsManager.get_setting("last_generation_lanes", 4)
	selected_fill = SettingsManager.get_setting("generation_fill", 50)
	selected_groove = SettingsManager.get_setting("generation_groove", 50)
	selected_density = SettingsManager.get_setting("generation_density", 50)
	selected_grid_snap_strength = int(SettingsManager.get_setting("generation_grid_snap_strength", 80))
	selected_accent_strong_beats = bool(SettingsManager.get_setting("generation_accent_strong_beats", true))
	selected_genre_template_strength = int(SettingsManager.get_setting("generation_genre_template_strength", 60))
	selected_enable_genre_detection = bool(SettingsManager.get_setting("enable_genre_detection", true))
	selected_use_stems_in_generation = bool(SettingsManager.get_setting("use_stems_in_generation", true))
	selected_include_hi_hats = bool(SettingsManager.get_setting("generation_include_hi_hats", true))
	selected_critic_strength = int(SettingsManager.get_setting("generation_critic_strength", 50))
	selected_groove_completion = bool(SettingsManager.get_setting("generation_groove_completion", true))
	selected_raw_adtof = bool(SettingsManager.get_setting("generation_raw_adtof", false))
	var clamped_flags := _Intents.clamp_advanced_flags(
		selected_intent, selected_groove_completion, selected_raw_adtof
	)
	selected_groove_completion = bool(clamped_flags["groove_completion"])
	selected_raw_adtof = bool(clamped_flags["raw_adtof"])

	_bind_controls()
	_setup_active_preset_header()
	_setup_back_button()
	_setup_presets_button()
	_setup_section_icons()
	_ensure_mode_help_icon()
	_setup_param_icons()
	_apply_settings_checkbox_styles()
	_bind_instrument_cards()
	_bind_goal_cards()
	_bind_lane_buttons()
	_setup_difficulty_segmented()
	_setup_preview_panel()
	_ensure_smart_hint_labels()
	_ensure_style_reset_button()

	_apply_sliders_to_ui()

	if selected_mode == "custom":
		_load_custom_generation_state()
		_apply_sliders_to_ui()
	else:
		_apply_goal_difficulty(selected_goal, selected_difficulty, false, true)
	_update_slider_labels()
	_apply_advanced_section_visual()

	_applying_ui_state = false
	_sync_difficulty_section_visibility()
	_update_selection_visuals()
	_update_status_indicator()
	_sync_preview()
	_update_smart_preset_recommendation()
	call_deferred("apply_locale")
	_apply_section_tooltips()
	_setup_footer_icons()
	UiInteractionApplier.apply_from_engine(self)
	_apply_param_tooltips()
	call_deferred("_layout_nav_buttons")
	call_deferred("_maybe_show_generation_settings_tutorial")
	_sync_preset_tracking()


func _maybe_show_generation_settings_tutorial(force: bool = false) -> void:
	if not SettingsManager or not SettingsManager.has_method("get_tutorial_generation_settings_done"):
		return
	if not force and SettingsManager.get_tutorial_generation_settings_done():
		return
	if _spotlight_tutorial == null:
		_spotlight_tutorial = _SpotlightTutorialScene.instantiate() as CanvasLayer
		if _spotlight_tutorial == null:
			return
		add_child(_spotlight_tutorial)
		if not _spotlight_tutorial.finished.is_connected(_on_generation_settings_tutorial_closed):
			_spotlight_tutorial.finished.connect(_on_generation_settings_tutorial_closed)
		if not _spotlight_tutorial.skipped.is_connected(_on_generation_settings_tutorial_closed):
			_spotlight_tutorial.skipped.connect(_on_generation_settings_tutorial_closed)
	var goal_row := get_node_or_null(GOAL_ROW) as Control
	var difficulty_row := get_node_or_null(DIFFICULTY_SECTION + "/DifficultyOptionRow") as Control
	var lanes_row := get_node_or_null(LANES_ROW) as Control
	var advanced_toggle := advanced_toggle_button
	var confirm_btn := get_node_or_null(FOOTER + "/ConfirmButton") as Control
	var steps: Array = [
		{
			"title_key": "TUTORIAL_GEN_1_TITLE",
			"body_key": "TUTORIAL_GEN_1_BODY",
			"target": goal_row,
		},
		{
			"title_key": "TUTORIAL_GEN_2_TITLE",
			"body_key": "TUTORIAL_GEN_2_BODY",
			"target": difficulty_row,
		},
		{
			"title_key": "TUTORIAL_GEN_3_TITLE",
			"body_key": "TUTORIAL_GEN_3_BODY",
			"target": lanes_row,
		},
		{
			"title_key": "TUTORIAL_GEN_4_TITLE",
			"body_key": "TUTORIAL_GEN_4_BODY",
			"target": confirm_btn,
		},
	]
	if _spotlight_tutorial.has_method("start"):
		_spotlight_tutorial.start(steps)


func _on_generation_settings_tutorial_closed() -> void:
	if SettingsManager and SettingsManager.has_method("set_tutorial_generation_settings_done"):
		SettingsManager.set_tutorial_generation_settings_done(true)


func debug_show_tutorial() -> void:
	_maybe_show_generation_settings_tutorial(true)


func _bind_controls() -> void:
	_back_button = get_node_or_null("BackButton") as Button
	_screen_margin = get_node_or_null("ScreenMargin") as MarginContainer
	_track_status_panel = get_node_or_null(ROOT + "/HeaderTop/TrackStatusPanel") as PanelContainer
	_preview_panel = get_node_or_null(ROOT + "/BodyHBox/PreviewPanel") as PanelContainer
	_preview_hero_label = get_node_or_null(PREVIEW_ROOT + "/PreviewHeroLabel") as Label
	_preview_blurb_label = get_node_or_null(PREVIEW_ROOT + "/PreviewBlurbLabel") as Label
	_preview_rows_vbox = get_node_or_null(PREVIEW_ROOT + "/PreviewRowsVBox") as VBoxContainer
	_preview_status_label = get_node_or_null(PREVIEW_ROOT + "/PreviewStatusPanel/PreviewStatusMargin/PreviewStatusVBox/PreviewStatusLabel") as Label
	_preview_status_hint_label = get_node_or_null(PREVIEW_ROOT + "/PreviewStatusPanel/PreviewStatusMargin/PreviewStatusVBox/PreviewStatusHintLabel") as Label
	_difficulty_option = get_node_or_null(DIFFICULTY_OPTION) as OptionButton
	_difficulty_blurb_label = get_node_or_null(DIFFICULTY_SECTION + "/DifficultyBlurb") as Label
	status_label = get_node(ROOT + "/HeaderTop/TrackStatusPanel/StatusVBox/StatusLabel") as Label
	status_title_label = get_node_or_null(ROOT + "/HeaderTop/TrackStatusPanel/StatusVBox/StatusTitleLabel") as Label
	advanced_toggle_button = get_node_or_null(ADVANCED + "/AdvancedToggleButton")
	advanced_container = get_node_or_null(ADVANCED + "/SlidersContainer")
	fill_slider = get_node(ADVANCED + "/SlidersContainer/SliderColumns/SliderColLeft/FillRow/FillSlider") as HSlider
	groove_slider = get_node(ADVANCED + "/SlidersContainer/SliderColumns/SliderColLeft/GrooveRow/GrooveSlider") as HSlider
	density_slider = get_node(ADVANCED + "/SlidersContainer/SliderColumns/SliderColLeft/DensityRow/DensitySlider") as HSlider
	grid_snap_strength_slider = get_node(ADVANCED + "/SlidersContainer/SliderColumns/SliderColRight/GridSnapRow/GridSnapStrengthSlider") as HSlider
	fill_label = get_node_or_null(ADVANCED + "/SlidersContainer/SliderColumns/SliderColLeft/FillRow/FillLabel")
	groove_label = get_node_or_null(ADVANCED + "/SlidersContainer/SliderColumns/SliderColLeft/GrooveRow/GrooveLabel")
	density_label = get_node_or_null(ADVANCED + "/SlidersContainer/SliderColumns/SliderColLeft/DensityRow/DensityLabel")
	grid_snap_label = get_node_or_null(ADVANCED + "/SlidersContainer/SliderColumns/SliderColRight/GridSnapRow/GridSnapLabel")
	genre_template_label = get_node_or_null(ADVANCED + "/SlidersContainer/SliderColumns/SliderColRight/GenreTemplateRow/GenreTemplateLabel")
	accent_strong_beats_checkbox = get_node_or_null(ADVANCED + "/SlidersContainer/CheckboxesContainer/AccentStrongBeatsCheckBox")
	enable_genre_detection_checkbox = get_node_or_null(ADVANCED + "/SlidersContainer/CheckboxesContainer/EnableGenreDetectionCheckBox")
	enable_stems_checkbox = get_node_or_null(ADVANCED + "/SlidersContainer/CheckboxesContainer/EnableStemsCheckBox")
	include_hi_hats_checkbox = get_node_or_null(ADVANCED + "/SlidersContainer/CheckboxesContainer/IncludeHiHatsCheckBox")
	groove_completion_checkbox = get_node_or_null(ADVANCED + "/SlidersContainer/CheckboxesContainer/GrooveCompletionCheckBox")
	raw_adtof_checkbox = get_node_or_null(ADVANCED + "/SlidersContainer/CheckboxesContainer/RawAdtofCheckBox")
	_presets_button = get_node_or_null("PresetsButton") as Button
	genre_template_strength_slider = get_node(ADVANCED + "/SlidersContainer/SliderColumns/SliderColRight/GenreTemplateRow/GenreTemplateStrengthSlider") as HSlider
	critic_strength_slider = get_node(ADVANCED + "/SlidersContainer/SliderColumns/SliderColRight/CriticStrengthRow/CriticStrengthSlider") as HSlider
	critic_strength_label = get_node_or_null(ADVANCED + "/SlidersContainer/SliderColumns/SliderColRight/CriticStrengthRow/CriticStrengthLabel")
	_configure_advanced_sliders()


func _configure_advanced_sliders() -> void:
	for slider in [fill_slider, groove_slider, density_slider, grid_snap_strength_slider, genre_template_strength_slider, critic_strength_slider]:
		if slider:
			slider.min_value = 0.0
			slider.max_value = 100.0
			slider.step = 5.0


func _setup_active_preset_header() -> void:
	var header_title := get_node_or_null(ROOT + "/HeaderTitle") as VBoxContainer
	var hint_label := get_node_or_null(ROOT + "/HeaderTitle/HintLabel") as Label
	if header_title and hint_label:
		_active_preset_row = _PresetActiveHeader.attach(
			header_title,
			hint_label.get_index() + 1,
			true,
		)


func _update_active_preset_header() -> void:
	if _active_preset_row == null:
		return
	if _preset_active_slot <= 0:
		_active_preset_row.visible = false
		return
	var name := preset_host_get_active_name()
	if name == "":
		name = _UserPresets.generation_display_name(
			SettingsManager.get_generation_presets(),
			_preset_active_slot,
		)
	var prefix := _active_preset_row.get_node_or_null("PrefixLabel") as Label
	if prefix:
		prefix.text = tr("GEN_STATUS_PRESET_LABEL")
	_PresetActiveHeader.update(
		_active_preset_row,
		_preset_active_slot,
		name,
		preset_host_is_dirty(),
	)


func _setup_back_button() -> void:
	if _back_button == null:
		return
	_back_button.z_index = 10
	_back_button.mouse_filter = Control.MOUSE_FILTER_STOP
	UiIconHelper.apply_standard_back_button(_back_button)
	if not _back_button.pressed.is_connected(_on_back_button_pressed):
		_back_button.pressed.connect(_on_back_button_pressed)


func _setup_presets_button() -> void:
	if _presets_button == null:
		return
	_presets_button.theme_type_variation = &"FlatBackButton"
	_presets_button.z_index = 10
	_presets_button.mouse_filter = Control.MOUSE_FILTER_STOP
	UiIconHelper.configure_button_icon(_presets_button, "tags.svg", UiIconHelper.MUTED, 16)
	if not _presets_button.pressed.is_connected(_on_presets_pressed):
		_presets_button.pressed.connect(_on_presets_pressed)


func _layout_nav_buttons() -> void:
	if _back_button == null:
		return
	_back_button.position = Vector2(_NAV_LEFT, _NAV_TOP)
	var back_h := UiIconHelper.BACK_BUTTON_MIN_SIZE.y
	_back_button.size = UiIconHelper.BACK_BUTTON_MIN_SIZE
	var header_row_y := _NAV_TOP + back_h + _NAV_GAP_AFTER_BACK
	if _screen_margin:
		_screen_margin.add_theme_constant_override("margin_top", int(header_row_y))
	if _presets_button == null:
		return
	var presets_size := UiIconHelper.BACK_BUTTON_MIN_SIZE
	_presets_button.custom_minimum_size = presets_size
	_presets_button.size = presets_size
	_presets_button.position = Vector2(size.x - presets_size.x - _NAV_LEFT, _NAV_TOP)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		call_deferred("_layout_nav_buttons")


func _bind_instrument_cards() -> void:
	_instrument_cards.clear()
	var grid := get_node_or_null(INSTRUMENT_GRID) as GridContainer
	if grid == null:
		return
	var inst_group := ButtonGroup.new()
	inst_group.allow_unpress = false
	for child in grid.get_children():
		var card := child as GenerationSelectCard
		if card == null or card.card_id.strip_edges() == "":
			continue
		card.button_group = inst_group
		if not card.card_selected.is_connected(_on_instrument_card_selected):
			card.card_selected.connect(_on_instrument_card_selected)
		_instrument_cards[card.card_id] = card


func _bind_goal_cards() -> void:
	_goal_cards.clear()
	var row := get_node_or_null(GOAL_ROW) as HBoxContainer
	if row == null:
		return
	for child in row.get_children():
		var card := child as GenerationSelectCard
		if card == null or card.card_id.strip_edges() == "":
			continue
		if card.card_id not in _GoalDiff.GOALS:
			continue
		if not card.card_selected.is_connected(_on_goal_card_selected):
			card.card_selected.connect(_on_goal_card_selected)
		_goal_cards[card.card_id] = card


func _find_goal_spec(goal_id: String) -> Dictionary:
	for spec in GOAL_SPECS:
		if str(spec.get("id", "")) == goal_id:
			return spec
	return {}


func _difficulty_option_labels() -> PackedStringArray:
	return PackedStringArray([
		tr(_GoalDiff.difficulty_label_key(selected_goal, "relaxed")),
		tr(_GoalDiff.difficulty_label_key(selected_goal, "standard")),
		tr(_GoalDiff.difficulty_label_key(selected_goal, "dense")),
	])


func _setup_difficulty_segmented() -> void:
	if _difficulty_option == null:
		return
	if _difficulty_seg.is_empty():
		_difficulty_option.clear()
		_difficulty_option.add_item(
			tr(_GoalDiff.difficulty_label_key(selected_goal, "relaxed")),
			_GoalDiff.difficulty_option_id("relaxed"),
		)
		_difficulty_option.add_item(
			tr(_GoalDiff.difficulty_label_key(selected_goal, "standard")),
			_GoalDiff.difficulty_option_id("standard"),
		)
		_difficulty_option.add_item(
			tr(_GoalDiff.difficulty_label_key(selected_goal, "dense")),
			_GoalDiff.difficulty_option_id("dense"),
		)
		_difficulty_seg = _SegmentedOptionUtils.build_from_option_button(
			_difficulty_option,
			18,
			52,
			360.0,
		)
		for btn in _difficulty_seg.get("buttons", []):
			(btn as Button).pressed.connect(_on_difficulty_segment_pressed.bind(btn))
	_sync_difficulty_segment()


func _refresh_difficulty_option_labels() -> void:
	if _difficulty_option == null:
		return
	var labels := _difficulty_option_labels()
	for i in range(mini(labels.size(), _difficulty_option.get_item_count())):
		_difficulty_option.set_item_text(i, labels[i])
	if not _difficulty_seg.is_empty():
		_SegmentedOptionUtils.apply_texts(_difficulty_seg.get("buttons", []), labels)
	_sync_difficulty_segment()


func _sync_difficulty_segment() -> void:
	if _difficulty_option == null or _difficulty_seg.is_empty():
		return
	for i in range(_difficulty_option.get_item_count()):
		if _difficulty_option.get_item_id(i) == _GoalDiff.difficulty_option_id(selected_difficulty):
			_difficulty_option.select(i)
			break
	_SegmentedOptionUtils.sync_from_option_button(_difficulty_seg)
	_update_difficulty_blurb()


func _on_difficulty_segment_pressed(btn: Button) -> void:
	var option_id := _SegmentedOptionUtils.id_from_button(btn)
	var new_difficulty := _GoalDiff.difficulty_from_option_id(option_id)
	if new_difficulty == selected_difficulty:
		return
	_apply_goal_difficulty(selected_goal, new_difficulty, true)
	UiScreenHotkeys.play_section_switch_sound()


func _update_difficulty_blurb() -> void:
	if _difficulty_blurb_label:
		_difficulty_blurb_label.text = tr(_GoalDiff.blurb_key(selected_goal, selected_difficulty))
	if _preview_blurb_label:
		_preview_blurb_label.text = tr(_GoalDiff.blurb_key(selected_goal, selected_difficulty))
	_update_difficulty_tooltips()


func _update_difficulty_tooltips() -> void:
	if _difficulty_seg.is_empty():
		return
	for btn in _difficulty_seg.get("buttons", []):
		if not (btn is Button):
			continue
		var diff_id := _GoalDiff.difficulty_from_option_id(_SegmentedOptionUtils.id_from_button(btn))
		btn.tooltip_text = tr(_GoalDiff.blurb_key(selected_goal, diff_id))


func _setup_preview_panel() -> void:
	if _preview_rows_vbox == null:
		return
	_build_preview_rows()
	var status_title := get_node_or_null(
		PREVIEW_ROOT + "/PreviewStatusPanel/PreviewStatusMargin/PreviewStatusVBox/PreviewStatusTitleLabel"
	) as Label
	if status_title:
		status_title.text = tr("GEN_TRACK_STATUS_TITLE")
	var preview_title := get_node_or_null(PREVIEW_ROOT + "/PreviewTitleLabel") as Label
	if preview_title:
		preview_title.text = tr("GEN_PREVIEW_TITLE")


func _build_preview_rows() -> void:
	if _preview_rows_vbox == null:
		return
	for child in _preview_rows_vbox.get_children():
		child.queue_free()
	_preview_rows.clear()
	var specs: Array = [
		{"id": "instrument", "icon": "drum.svg", "tint": INSTRUMENT_ICON_COLORS.get("drums", SECTION_ICON_COLOR)},
		{"id": "goal", "icon": "audio-lines.svg", "tint": INTENT_ICON_COLORS.get("original", SECTION_ICON_COLOR)},
		{"id": "difficulty", "icon": "layers.svg", "tint": SECTION_ICON_COLOR},
		{"id": "lanes", "icon": "between-horizontal-start.svg", "tint": SECTION_ICON_COLOR},
		{"id": "tuning", "icon": "settings-2.svg", "tint": SECTION_ICON_COLOR},
	]
	for spec in specs:
		var row := _PreviewRowScene.new() as SessionSetupPreviewRow
		row.setup(
			str(spec.get("icon", "")),
			"",
			spec.get("tint", SECTION_ICON_COLOR) as Color,
		)
		_preview_rows_vbox.add_child(row)
		_preview_rows[str(spec.get("id", ""))] = row


func _set_preview_row(
	row_id: String,
	text: String,
	visible_row: bool = true,
	tone: String = "normal",
	icon_file: String = "",
	icon_tint: Color = SECTION_ICON_COLOR,
) -> void:
	var row: SessionSetupPreviewRow = _preview_rows.get(row_id, null)
	if row == null:
		return
	row.visible = visible_row
	if visible_row:
		row.set_text(text)
		if icon_file.strip_edges() != "":
			row.set_icon(icon_file, icon_tint)
		row.set_tone(tone)


func _sync_preview() -> void:
	if _preview_hero_label:
		if selected_goal == "original":
			# Original has no difficulty tier — don't show "Readable"/«Читаемая».
			_preview_hero_label.text = tr("GEN_PREVIEW_HERO_ORIGINAL_FMT") % [
				tr("GEN_GOAL_ORIGINAL"),
				selected_lanes,
			]
		else:
			_preview_hero_label.text = tr("GEN_PREVIEW_HERO_FMT") % [
				tr("GEN_GOAL_%s" % selected_goal.to_upper()),
				tr(_GoalDiff.difficulty_label_key(selected_goal, selected_difficulty)),
				selected_lanes,
			]
	_update_difficulty_blurb()
	var inst_icon := str(INSTRUMENT_ICONS.get(selected_instrument, "drum.svg"))
	var inst_tint := INSTRUMENT_ICON_COLORS.get(selected_instrument, SECTION_ICON_COLOR) as Color
	_set_preview_row(
		"instrument",
		tr("GEN_INST_%s" % selected_instrument.to_upper()),
		true,
		"normal",
		inst_icon,
		inst_tint,
	)
	var goal_icon := str(INTENT_ICONS.get(selected_goal, "audio-lines.svg"))
	var goal_tint := INTENT_ICON_COLORS.get(selected_goal, SECTION_ICON_COLOR) as Color
	_set_preview_row(
		"goal",
		tr("GEN_GOAL_%s" % selected_goal.to_upper()),
		true,
		"normal",
		goal_icon,
		goal_tint,
	)
	if selected_goal == "original":
		var diff_row: Control = _preview_rows.get("difficulty", null) as Control
		if diff_row:
			diff_row.visible = false
	else:
		_set_preview_row(
			"difficulty",
			tr(_GoalDiff.difficulty_label_key(selected_goal, selected_difficulty)),
			true,
		)
	_set_preview_row(
		"lanes",
		_SS.format_lanes_button_label(selected_lanes),
		true,
	)
	var tuning_text := tr("GEN_PREVIEW_TUNING_DEFAULT")
	if _style_is_customized():
		tuning_text = tr("GEN_PREVIEW_TUNING_CUSTOM")
	elif _preset_active_slot > 0:
		tuning_text = tr("GEN_PREVIEW_TUNING_PRESET") % preset_host_get_active_name()
	if _is_bass_generation():
		var tuning_row: Control = _preview_rows.get("tuning", null) as Control
		if tuning_row:
			tuning_row.visible = false
	else:
		_set_preview_row("tuning", tuning_text, true, "warn" if _style_is_customized() else "normal")
	_sync_preview_status()


func _sync_preview_status() -> void:
	var exists := _notes_exist_for_selection()
	var stem := _GoalDiff.chart_stem(selected_goal, selected_difficulty)
	var label := _preview_status_label if _preview_status_label else status_label
	if label:
		if exists:
			label.text = tr("SONG_STATUS_NOTES_READY")
			label.add_theme_color_override("font_color", Color(0.45, 0.82, 0.58, 1.0))
		else:
			label.text = tr("SONG_STATUS_NO_NOTES")
			label.add_theme_color_override("font_color", Color(0.62, 0.7, 0.82, 0.92))
	var hint := _preview_status_hint_label if _preview_status_hint_label else status_hint_label
	if hint:
		var dna := _Recommender.load_dna_for_song(
			current_song_path,
			selected_instrument,
			stem,
			selected_lanes,
		)
		if _percussion_low_from_dna(dna):
			hint.visible = true
			hint.text = tr("GEN_SMART_TRACK_PERCUSSION")
			hint.tooltip_text = tr("DNA_BADGE_WEAK_PERCUSSION_TIP")
		else:
			hint.visible = false
			hint.text = ""
			hint.tooltip_text = ""


func _bind_intent_cards() -> void:
	_bind_goal_cards()


func _find_intent_spec(intent_id: String) -> Dictionary:
	for spec in INTENT_SPECS:
		if str(spec.get("id", "")) == intent_id:
			return spec
	return {}


func _bind_lane_buttons() -> void:
	_lane_buttons.clear()
	var row := get_node_or_null(LANES_ROW) as HBoxContainer
	if row == null:
		return
	for child in row.get_children():
		if not (child is Button):
			continue
		var lanes := int(_LANE_BUTTON_LANES.get(child.name, 0))
		if lanes <= 0:
			continue
		var btn := child as Button
		if not btn.pressed.is_connected(_on_lane_button_pressed):
			btn.pressed.connect(_on_lane_button_pressed.bind(lanes))
		_lane_buttons[lanes] = btn


func _normalize_instrument_card_layout() -> void:
	var max_h := 120.0
	for card_id in _instrument_cards:
		var card: GenerationSelectCard = _instrument_cards[card_id]
		if card == null or not card.visible:
			continue
		max_h = maxf(max_h, card.get_combined_minimum_size().y)
	max_h += 4.0
	for card_id in _instrument_cards:
		var card: GenerationSelectCard = _instrument_cards[card_id]
		if card == null or not card.visible:
			continue
		card.custom_minimum_size.y = max_h


func _find_instrument_spec(inst_id: String) -> Dictionary:
	for spec in INSTRUMENT_SPECS:
		if str(spec.get("id", "")) == inst_id:
			return spec
	return {}


func apply_locale() -> void:
	if _back_button:
		_back_button.text = tr("BTN_BACK")
	var footer_hint := get_node_or_null("ScreenMargin/Container/FooterHintLabel") as Label
	if footer_hint:
		footer_hint.text = tr("GEN_SETTINGS_FOOTER_HINT")
	var screen_title := get_node_or_null(ROOT + "/HeaderTitle/TitleLabel")
	if screen_title:
		screen_title.text = tr("GEN_SCREEN_TITLE")
	var screen_hint := get_node_or_null(ROOT + "/HeaderTitle/HintLabel")
	if screen_hint:
		screen_hint.text = tr("GEN_SCREEN_SUBTITLE")
	if status_title_label:
		status_title_label.text = tr("GEN_TRACK_STATUS_TITLE")
	_set_section_label_in(ROOT + "/BodyHBox/InstrumentPanel/InstrumentPanelVBox", "InstrumentTitle", "GEN_TITLE")
	_set_section_label(ROOT + "/BodyHBox/InstrumentPanel/InstrumentPanelVBox/InstrumentSubtitle", "GEN_INST_SECTION_SUB")
	_set_section_label_in(ROOT + "/BodyHBox/MainScroll/MainVBox/ModeSection/ModeSectionVBox", "ModeTitle", "GEN_GOAL_SECTION_TITLE")
	_set_section_label(ROOT + "/BodyHBox/MainScroll/MainVBox/ModeSection/ModeSectionVBox/ModeSubtitle", "GEN_GOAL_SECTION_SUB")
	if _mode_help_btn:
		_mode_help_btn.tooltip_text = tr("HELP_LINK_CHART_STYLE")
	_set_section_label_in(DIFFICULTY_SECTION, "DifficultyTitle", "GEN_DIFF_SECTION_TITLE")
	_set_section_label(DIFFICULTY_SECTION + "/DifficultySubtitle", "GEN_DIFF_SECTION_SUB")
	_set_section_label_in(ROOT + "/BodyHBox/MainScroll/MainVBox/LanesSection/LanesSectionVBox", "LanesTitle", "GEN_LANES_LABEL")
	_set_section_label(ROOT + "/BodyHBox/MainScroll/MainVBox/LanesSection/LanesSectionVBox/LanesSubtitle", "GEN_LANES_SECTION_SUB")
	for card_id in _instrument_cards:
		var spec := _find_instrument_spec(card_id)
		if spec.is_empty():
			continue
		var card: GenerationSelectCard = _instrument_cards[card_id]
		var desc_key := str(spec.get("desc_key", ""))
		card.setup(
			card_id,
			tr(str(spec["title_key"])),
			tr(desc_key) if desc_key != "" else "",
			tr(str(spec["badge_key"])),
			not bool(spec.get("enabled", false)),
			INSTRUMENT_ICONS.get(card_id, ""),
			INSTRUMENT_ICON_COLORS.get(card_id, SECTION_ICON_COLOR)
		)
	call_deferred("_normalize_instrument_card_layout")
	for goal_id in _goal_cards:
		var spec := _find_goal_spec(goal_id)
		var gcard: GenerationSelectCard = _goal_cards.get(goal_id)
		if gcard == null or spec.is_empty():
			continue
		gcard.setup(
			goal_id,
			tr(str(spec.get("title_key", ""))),
			tr(str(spec.get("desc_key", ""))),
			"",
			false,
			INTENT_ICONS.get(goal_id, ""),
			INTENT_ICON_COLORS.get(goal_id, SECTION_ICON_COLOR),
		)
		gcard.tooltip_text = tr(str(spec.get("desc_key", "")))
	if _difficulty_option:
		if _difficulty_seg.is_empty():
			_setup_difficulty_segmented()
		else:
			_refresh_difficulty_option_labels()
	_setup_preview_panel()
	_update_smart_preset_recommendation()
	_apply_section_tooltips()
	for lanes in _lane_buttons:
		var btn: Button = _lane_buttons[lanes]
		btn.text = _SS.format_lanes_button_label(lanes)
	var accent_cb := accent_strong_beats_checkbox
	if accent_cb:
		accent_cb.text = tr("GEN_ACCENT_STRONG")
	var genre_cb := enable_genre_detection_checkbox
	if genre_cb:
		genre_cb.text = tr("GEN_ENABLE_GENRE")
	var stems_cb := enable_stems_checkbox
	if stems_cb:
		stems_cb.text = tr("GEN_ENABLE_STEMS")
	var hi_hats_cb := include_hi_hats_checkbox
	if hi_hats_cb:
		hi_hats_cb.text = tr("GEN_INCLUDE_HI_HATS")
	var groove_completion_cb := groove_completion_checkbox
	if groove_completion_cb:
		groove_completion_cb.text = tr("GEN_GROOVE_COMPLETION")
	var raw_adtof_cb := raw_adtof_checkbox
	if raw_adtof_cb:
		raw_adtof_cb.text = tr("GEN_RAW_ADTOF")
	if _presets_button:
		_presets_button.text = tr("GEN_PRESETS_BUTTON")
	_update_active_preset_header()
	var reset_btn := get_node_or_null(FOOTER + "/ResetButton")
	if reset_btn:
		reset_btn.text = tr("GEN_RESET_SETTINGS")
	var confirm_btn := get_node_or_null(FOOTER + "/ConfirmButton")
	if confirm_btn:
		confirm_btn.text = tr("GEN_CONFIRM")
	_apply_advanced_section_visual()
	_update_slider_labels()
	_apply_param_tooltips()
	_update_status_indicator()
	_update_selection_visuals()
	_sync_preview()
	call_deferred("_layout_nav_buttons")


func _set_section_label(path: String, key: String) -> void:
	var lbl := get_node_or_null(path) as Label
	if lbl:
		lbl.text = tr(key)


func _set_section_label_in(container_path: String, label_name: String, key: String) -> void:
	var lbl := _find_section_label(container_path, label_name)
	if lbl:
		lbl.text = tr(key)


func _find_section_label(container_path: String, label_name: String) -> Label:
	var box := get_node_or_null(container_path)
	if box == null:
		return null
	return box.find_child(label_name, true, false) as Label


func _ensure_mode_help_icon() -> void:
	if _mode_help_btn != null and is_instance_valid(_mode_help_btn):
		return
	var title := _find_section_label(
		ROOT + "/BodyHBox/MainScroll/MainVBox/ModeSection/ModeSectionVBox",
		"ModeTitle"
	)
	if title == null:
		return
	var parent := title.get_parent()
	if parent == null:
		return
	_mode_help_btn = _SettingsSectionUi.make_help_icon_button(tr("HELP_LINK_CHART_STYLE"))
	_mode_help_btn.pressed.connect(_on_mode_help_pressed)
	if parent is HBoxContainer:
		parent.add_child(_mode_help_btn)
		parent.move_child(_mode_help_btn, title.get_index() + 1)
		title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return
	var row := HBoxContainer.new()
	row.name = "ModeTitleRow"
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var idx := title.get_index()
	parent.add_child(row)
	parent.move_child(row, idx)
	parent.remove_child(title)
	row.add_child(title)
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_mode_help_btn)


func _on_mode_help_pressed() -> void:
	_open_help_item("modes")


func _open_help_item(item_id: String) -> void:
	var node: Node = self
	while node:
		if node.has_method("get_transitions"):
			var trans = node.get_transitions()
			if trans and trans.has_method("open_help_item"):
				trans.open_help_item(item_id)
				return
		if node.has_method("open_help_item") and node != self:
			node.open_help_item(item_id)
			return
		node = node.get_parent()
	var tree := get_tree()
	if tree == null:
		return
	for child in tree.root.get_children():
		if child.has_method("get_transitions"):
			var root_trans = child.get_transitions()
			if root_trans and root_trans.has_method("open_help_item"):
				root_trans.open_help_item(item_id)
				return


func _setup_section_icons() -> void:
	_add_icon_before_label(
		get_node_or_null(ROOT + "/BodyHBox/InstrumentPanel/InstrumentPanelVBox/InstrumentTitle") as Label,
		"music.svg",
		false,
		SECTION_ICON_COLOR
	)
	_add_icon_before_label(
		get_node_or_null(ROOT + "/BodyHBox/MainScroll/MainVBox/ModeSection/ModeSectionVBox/ModeTitle") as Label,
		"chart-no-axes-column-increasing.svg",
		true,
		SECTION_ICON_COLOR
	)
	_add_icon_before_label(
		get_node_or_null(DIFFICULTY_SECTION + "/DifficultyTitle") as Label,
		"star.svg",
		true,
		SECTION_ICON_COLOR
	)
	_add_icon_before_label(
		get_node_or_null(ROOT + "/BodyHBox/MainScroll/MainVBox/LanesSection/LanesSectionVBox/LanesTitle") as Label,
		"layers.svg",
		true,
		SECTION_ICON_COLOR
	)


func _apply_settings_checkbox_styles() -> void:
	_SettingsSectionUi.apply_settings_checkbox(accent_strong_beats_checkbox as CheckBox, 20, true)
	_SettingsSectionUi.apply_settings_checkbox(include_hi_hats_checkbox as CheckBox, 20, true)
	_SettingsSectionUi.apply_settings_checkbox(groove_completion_checkbox as CheckBox, 20, true)
	_SettingsSectionUi.apply_settings_checkbox(raw_adtof_checkbox as CheckBox, 20, true)
	_SettingsSectionUi.apply_settings_checkbox(enable_genre_detection_checkbox as CheckBox, 20, true)
	_SettingsSectionUi.apply_settings_checkbox(enable_stems_checkbox as CheckBox, 20, true)


func _setup_param_icons() -> void:
	_add_icon_before_label(fill_label, PARAM_ICONS.fill, true, PARAM_ICON_COLORS.fill)
	_add_icon_before_label(groove_label, PARAM_ICONS.groove, true, PARAM_ICON_COLORS.groove)
	_add_icon_before_label(density_label, PARAM_ICONS.density, true, PARAM_ICON_COLORS.density)
	_add_icon_before_label(grid_snap_label, PARAM_ICONS.grid_snap, true, PARAM_ICON_COLORS.grid_snap)
	_add_icon_before_label(genre_template_label, PARAM_ICONS.genre_template, true, PARAM_ICON_COLORS.genre_template)
	_add_icon_before_label(critic_strength_label, PARAM_ICONS.critic_strength, true, PARAM_ICON_COLORS.critic_strength)
	_set_checkbox_icon(accent_strong_beats_checkbox, "accent")
	_set_checkbox_icon(include_hi_hats_checkbox, "hi_hats")
	_set_checkbox_icon(groove_completion_checkbox, "groove_completion")
	_set_checkbox_icon(raw_adtof_checkbox, "raw_adtof")
	_set_checkbox_icon(enable_genre_detection_checkbox, "genre_detect")
	_set_checkbox_icon(enable_stems_checkbox, "stems")


func _add_icon_before_label(
	label: Label,
	file_name: String,
	center_row: bool = true,
	tint: Color = SECTION_ICON_COLOR
) -> void:
	if label == null or file_name.strip_edges() == "":
		return
	if label.get_meta("gen_icon_wrapped", false):
		return
	var parent := label.get_parent()
	if parent == null:
		return
	var idx := label.get_index()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER if center_row else BoxContainer.ALIGNMENT_BEGIN
	parent.remove_child(label)
	parent.add_child(row)
	parent.move_child(row, idx)
	row.add_child(UiIconHelper.make_icon_frame(file_name, 28, 16, tint))
	row.add_child(label)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.set_meta("gen_icon_wrapped", true)


func _set_checkbox_icon(checkbox: BaseButton, icon_key: String) -> void:
	if checkbox == null or icon_key.strip_edges() == "":
		return
	var file_name: String = PARAM_ICONS.get(icon_key, "")
	if file_name == "":
		return
	var color: Color = PARAM_ICON_COLORS.get(icon_key, SECTION_ICON_COLOR)
	_add_icon_before_checkbox(checkbox, file_name, color)


func _add_icon_before_checkbox(checkbox: CheckBox, file_name: String, tint: Color) -> void:
	if checkbox == null or file_name.strip_edges() == "":
		return
	if checkbox.get_meta("gen_icon_wrapped", false):
		return
	var parent := checkbox.get_parent()
	if parent == null:
		return
	var idx := checkbox.get_index()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	parent.remove_child(checkbox)
	parent.add_child(row)
	parent.move_child(row, idx)
	row.add_child(UiIconHelper.make_icon_frame(file_name, 28, 16, tint))
	row.add_child(checkbox)
	checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	checkbox.set_meta("gen_icon_wrapped", true)


func _setup_footer_icons() -> void:
	var reset_btn := get_node_or_null(FOOTER + "/ResetButton")
	var confirm_btn := get_node_or_null(FOOTER + "/ConfirmButton")
	UiIconHelper.setup_reset_button(reset_btn)
	UiIconHelper.setup_confirm_button(confirm_btn)


func _apply_section_tooltips() -> void:
	_set_tooltip(_find_section_label(ROOT + "/BodyHBox/InstrumentPanel/InstrumentPanelVBox", "InstrumentTitle"), "GEN_INST_SECTION_SUB")
	_set_tooltip(_find_section_label(ROOT + "/BodyHBox/MainScroll/MainVBox/ModeSection/ModeSectionVBox", "ModeTitle"), "GEN_GOAL_SECTION_SUB")
	_set_tooltip(_find_section_label(DIFFICULTY_SECTION, "DifficultyTitle"), "GEN_DIFF_SECTION_SUB")
	_set_tooltip(_find_section_label(ROOT + "/BodyHBox/MainScroll/MainVBox/LanesSection/LanesSectionVBox", "LanesTitle"), "GEN_LANES_SECTION_SUB")
	if advanced_toggle_button:
		advanced_toggle_button.tooltip_text = tr(_advanced_section_hint_key())
	for goal_id in _goal_cards:
		var gcard: GenerationSelectCard = _goal_cards[goal_id]
		if gcard:
			var spec := _find_goal_spec(goal_id)
			gcard.tooltip_text = tr(str(spec.get("desc_key", "")))


func _on_instrument_card_selected(card_id: String) -> void:
	if not _instrument_cards.has(card_id):
		return
	var card: GenerationSelectCard = _instrument_cards[card_id]
	if card.disabled:
		return
	if card_id == selected_instrument:
		return
	selected_instrument = card_id
	MusicManager.play_instrument_select_sound(selected_instrument)
	_update_selection_visuals()
	_sync_preview()


func _on_goal_card_selected(goal_id: String) -> void:
	if _intent_card_pick_guard:
		return
	if goal_id not in _GoalDiff.GOALS:
		return
	if goal_id != selected_goal or selected_mode == "custom":
		_apply_goal_difficulty(goal_id, selected_difficulty, true)
		UiScreenHotkeys.play_section_switch_sound()
		_intent_card_pick_guard = true
		call_deferred("_release_intent_card_pick_guard")
		return
	if _params_differ_from_intent_preset():
		_reset_style_to_intent_defaults()
		UiScreenHotkeys.play_section_switch_sound()
		_intent_card_pick_guard = true
		call_deferred("_release_intent_card_pick_guard")
		return
	_on_confirm_pressed()


func _on_intent_card_selected(intent_id: String) -> void:
	_on_goal_card_selected(intent_id)


func _release_intent_card_pick_guard() -> void:
	_intent_card_pick_guard = false


func _on_lane_button_pressed(lanes: int) -> void:
	if lanes == selected_lanes:
		return
	selected_lanes = lanes
	UiScreenHotkeys.play_section_switch_sound()
	_update_selection_visuals()
	_sync_preview()


func _apply_goal_difficulty(
	new_goal: String,
	new_difficulty: String,
	persist_custom: bool,
	preserve_slider_state: bool = false,
) -> void:
	if not _GoalDiff.is_goal(new_goal) or not _GoalDiff.is_difficulty(new_difficulty):
		return
	# Original = documentary chart only (no Easy/Med/Hard). Arcade keeps tiers.
	if new_goal == "original":
		if selected_goal == "arcade":
			_arcade_difficulty_memory = selected_difficulty
		new_difficulty = _GoalDiff.DEFAULT_DIFFICULTY
	elif selected_goal == "original" and new_goal == "arcade":
		var mem := _GoalDiff.sanitize_difficulty(_arcade_difficulty_memory)
		if new_difficulty == _GoalDiff.DEFAULT_DIFFICULTY or new_difficulty == selected_difficulty:
			new_difficulty = mem
	var mapped_intent := _GoalDiff.intent_for(new_goal, new_difficulty)
	if mapped_intent not in INTENTS or _Intents.is_locked(mapped_intent):
		return
	selected_goal = new_goal
	selected_difficulty = new_difficulty
	if new_goal == "arcade":
		_arcade_difficulty_memory = new_difficulty
	if selected_mode == "custom" and preserve_slider_state:
		selected_intent = mapped_intent
		_refresh_difficulty_option_labels()
		_sync_difficulty_section_visibility()
		_update_selection_visuals()
		_sync_preview()
		return
	_apply_intent(mapped_intent, persist_custom, preserve_slider_state, false)
	selected_goal = new_goal
	selected_difficulty = new_difficulty
	_refresh_difficulty_option_labels()
	_sync_difficulty_segment()
	_sync_difficulty_section_visibility()
	_update_selection_visuals()
	_sync_preview()


func _sync_difficulty_section_visibility() -> void:
	var section := get_node_or_null(
		ROOT + "/BodyHBox/MainScroll/MainVBox/DifficultySection"
	) as Control
	if section:
		section.visible = selected_goal != "original"

func _apply_intent(
	new_intent: String,
	persist_custom: bool,
	preserve_slider_state: bool = false,
	derive_pair: bool = false,
) -> void:
	if new_intent not in INTENTS or _Intents.is_locked(new_intent):
		return
	if persist_custom and selected_mode == "custom":
		_persist_custom_preset_to_settings()
		SettingsManager.save_settings()
	_clear_generation_active_preset()
	selected_intent = new_intent
	selected_mode = _Intents.intent_to_legacy_mode(new_intent)
	var preset := _Intents.preset_for(new_intent)
	var prev_applying := _applying_ui_state
	_applying_ui_state = true
	if not preserve_slider_state:
		selected_fill = int(preset["fill"])
		selected_groove = int(preset["groove"])
		selected_density = int(preset["density"])
		selected_grid_snap_strength = int(preset["grid_snap_strength"])
		selected_accent_strong_beats = bool(preset["accent_strong_beats"])
		selected_genre_template_strength = int(preset["genre_template_strength"])
		selected_enable_genre_detection = bool(preset["enable_genre_detection"])
		selected_use_stems_in_generation = bool(preset["use_stems_in_generation"])
		selected_include_hi_hats = bool(preset["include_hi_hats"])
		selected_critic_strength = int(preset["critic_strength"])
		selected_groove_completion = bool(preset["groove_completion"])
		selected_raw_adtof = bool(preset["raw_adtof"])
	_apply_sliders_to_ui()
	SettingsManager.set_setting("enable_genre_detection", selected_enable_genre_detection)
	SettingsManager.set_setting("use_stems_in_generation", selected_use_stems_in_generation)
	_applying_ui_state = prev_applying
	if derive_pair:
		var pair := _GoalDiff.from_intent(selected_intent)
		selected_goal = str(pair.get("goal", _GoalDiff.DEFAULT_GOAL))
		selected_difficulty = str(pair.get("difficulty", _GoalDiff.DEFAULT_DIFFICULTY))
	_update_slider_labels()
	_sync_difficulty_segment()
	_update_selection_visuals()
	_sync_preview()


func _apply_sliders_to_ui() -> void:
	if fill_slider:
		fill_slider.set_value_no_signal(float(selected_fill))
	if groove_slider:
		groove_slider.set_value_no_signal(float(selected_groove))
	if density_slider:
		density_slider.set_value_no_signal(float(selected_density))
	if grid_snap_strength_slider:
		grid_snap_strength_slider.set_value_no_signal(float(selected_grid_snap_strength))
	if accent_strong_beats_checkbox:
		_set_checkbox_state(accent_strong_beats_checkbox, selected_accent_strong_beats)
	if enable_genre_detection_checkbox:
		_set_checkbox_state(enable_genre_detection_checkbox, selected_enable_genre_detection)
	if enable_stems_checkbox:
		_set_checkbox_state(enable_stems_checkbox, selected_use_stems_in_generation)
	if include_hi_hats_checkbox:
		_set_checkbox_state(include_hi_hats_checkbox, selected_include_hi_hats)
	if genre_template_strength_slider:
		genre_template_strength_slider.set_value_no_signal(float(selected_genre_template_strength))
	if critic_strength_slider:
		critic_strength_slider.set_value_no_signal(float(selected_critic_strength))
	if groove_completion_checkbox:
		_set_checkbox_state(groove_completion_checkbox, selected_groove_completion)
	if raw_adtof_checkbox:
		_set_checkbox_state(raw_adtof_checkbox, selected_raw_adtof)
	_apply_intent_advanced_guards()


func _update_selection_visuals() -> void:
	for id in _instrument_cards:
		var card: GenerationSelectCard = _instrument_cards[id]
		card.set_card_selected(id == selected_instrument)
	for goal_id in _goal_cards:
		var gcard: GenerationSelectCard = _goal_cards[goal_id]
		var goal_selected: bool = goal_id == selected_goal
		gcard.set_card_selected(goal_selected)
		gcard.set_params_tuned(
			goal_selected
			and _preset_active_slot <= 0
			and _params_differ_from_intent_preset()
		)
		var desc_key := str(_find_goal_spec(goal_id).get("desc_key", ""))
		if goal_selected and _preset_active_slot > 0:
			gcard.tooltip_text = tr("GEN_INTENT_PRESET_ACTIVE_TOOLTIP") % preset_host_get_active_name()
		elif goal_selected and _params_differ_from_intent_preset():
			gcard.tooltip_text = tr("GEN_INTENT_TUNED_TOOLTIP")
		else:
			gcard.tooltip_text = tr(desc_key) if desc_key != "" else ""
	for lanes in _lane_buttons:
		var btn: Button = _lane_buttons[lanes]
		btn.self_modulate = ACTIVE_COLOR if lanes == selected_lanes else DEFAULT_COLOR
	_update_smart_preset_recommendation()
	_update_active_preset_header()
	_apply_intent_advanced_guards()
	_apply_instrument_advanced_visibility()
	_sync_style_reset_button()


func _is_bass_generation() -> bool:
	return selected_instrument == "bass"


func _advanced_section_hint_key() -> String:
	return "GEN_ADVANCED_BASS_HINT" if _is_bass_generation() else "GEN_ADVANCED_SECTION_SUB"


func _set_advanced_control_visible(control: Control, visible: bool) -> void:
	if control == null:
		return
	var row: Control = control
	if control.get_meta("gen_icon_wrapped", false):
		var parent := control.get_parent()
		if parent is Control:
			row = parent as Control
	row.visible = visible


func _apply_instrument_advanced_visibility() -> void:
	var is_bass := _is_bass_generation()
	var slider_columns := get_node_or_null(ADVANCED + "/SlidersContainer/SliderColumns") as Control
	if slider_columns:
		slider_columns.visible = not is_bass
	for cb in [
		accent_strong_beats_checkbox,
		include_hi_hats_checkbox,
		groove_completion_checkbox,
		enable_genre_detection_checkbox,
		raw_adtof_checkbox,
	]:
		_set_advanced_control_visible(cb as Control, not is_bass)
	_set_advanced_control_visible(enable_stems_checkbox as Control, true)
	var hint := get_node_or_null(ADVANCED + "/AdvancedHintLabel") as Label
	if hint:
		hint.text = tr(_advanced_section_hint_key())
	if advanced_toggle_button:
		advanced_toggle_button.tooltip_text = tr(_advanced_section_hint_key())


func _style_is_customized() -> bool:
	return selected_mode == "custom" or _params_differ_from_intent_preset()


func _reset_style_to_intent_defaults() -> void:
	var mapped := _GoalDiff.intent_for(selected_goal, selected_difficulty)
	if mapped.strip_edges() == "" or mapped not in INTENTS:
		mapped = "original"
	_clear_generation_active_preset()
	var prev := _applying_ui_state
	_applying_ui_state = true
	_apply_intent(mapped, false, false, false)
	selected_goal = _GoalDiff.sanitize_goal(selected_goal)
	selected_difficulty = _GoalDiff.sanitize_difficulty(selected_difficulty)
	selected_intent = _GoalDiff.intent_for(selected_goal, selected_difficulty)
	_applying_ui_state = prev
	_update_slider_labels()
	_update_selection_visuals()
	_sync_preview()


func _ensure_style_reset_button() -> void:
	var section := get_node_or_null(MODE_SECTION) as VBoxContainer
	if section == null:
		return
	_style_reset_button = section.get_node_or_null("StyleResetButton") as Button
	if _style_reset_button == null:
		_style_reset_button = Button.new()
		_style_reset_button.name = &"StyleResetButton"
		_style_reset_button.focus_mode = Control.FOCUS_ALL
		_style_reset_button.theme_type_variation = &"FlatButton"
		_style_reset_button.add_theme_font_size_override("font_size", 14)
		_style_reset_button.add_theme_color_override("font_color", Color(0.62, 0.78, 0.98, 0.95))
		_style_reset_button.add_theme_color_override("font_hover_color", Color(0.72, 0.86, 1.0, 1.0))
		if not _style_reset_button.pressed.is_connected(_on_style_reset_pressed):
			_style_reset_button.pressed.connect(_on_style_reset_pressed)
		var subtitle := section.get_node_or_null("ModeSubtitle") as Control
		var insert_idx := subtitle.get_index() + 1 if subtitle else 2
		section.add_child(_style_reset_button)
		section.move_child(_style_reset_button, insert_idx)
	_sync_style_reset_button()


func _style_reset_needed() -> bool:
	return _preset_active_slot > 0 or _style_is_customized()


func _sync_style_reset_button() -> void:
	if _style_reset_button == null:
		return
	var has_preset := _preset_active_slot > 0
	var customized := _style_is_customized()
	var show := has_preset or customized
	_style_reset_button.visible = show
	_style_reset_button.disabled = not show
	if has_preset and not customized:
		_style_reset_button.text = tr("GEN_CLEAR_ACTIVE_PRESET")
		_style_reset_button.tooltip_text = tr("GEN_CLEAR_ACTIVE_PRESET_TOOLTIP")
	else:
		_style_reset_button.text = tr("GEN_RESET_STYLE")
		_style_reset_button.tooltip_text = tr("GEN_RESET_STYLE_TOOLTIP")


func _on_style_reset_pressed() -> void:
	if not _style_reset_needed():
		return
	_UiModifierSounds.play_select()
	if _preset_active_slot > 0 and not _style_is_customized():
		_clear_generation_active_preset()
		_update_selection_visuals()
		_sync_preview()
		return
	_reset_style_to_intent_defaults()


func _params_differ_from_intent_preset() -> bool:
	if selected_intent.strip_edges() == "":
		return false
	return not _Intents.params_match_intent(_current_param_snapshot(), selected_intent)


func _apply_intent_advanced_guards() -> void:
	if _is_bass_generation():
		return
	var clamped := _Intents.clamp_advanced_flags(
		selected_intent, selected_groove_completion, selected_raw_adtof
	)
	selected_groove_completion = bool(clamped["groove_completion"])
	selected_raw_adtof = bool(clamped["raw_adtof"])
	var gc_enabled := _Intents.can_toggle_groove_completion(selected_intent) and not selected_raw_adtof
	var raw_enabled := _Intents.can_toggle_raw_adtof(selected_intent)
	if selected_raw_adtof:
		selected_groove_completion = false
	if groove_completion_checkbox:
		groove_completion_checkbox.disabled = not gc_enabled
		if not _applying_ui_state:
			_set_checkbox_state(groove_completion_checkbox, selected_groove_completion)
		groove_completion_checkbox.tooltip_text = tr("GEN_GROOVE_COMPLETION_TOOLTIP")
		if not gc_enabled:
			groove_completion_checkbox.tooltip_text = tr("GEN_GROOVE_COMPLETION_LOCKED_TOOLTIP")
	if raw_adtof_checkbox:
		raw_adtof_checkbox.disabled = not raw_enabled
		if not _applying_ui_state:
			_set_checkbox_state(raw_adtof_checkbox, selected_raw_adtof)
		raw_adtof_checkbox.tooltip_text = tr("GEN_RAW_ADTOF_TOOLTIP")
		if not raw_enabled:
			raw_adtof_checkbox.tooltip_text = tr("GEN_RAW_ADTOF_LOCKED_TOOLTIP")


func _persist_custom_preset_to_settings() -> void:
	SettingsManager.set_setting("generation_custom_fill", selected_fill)
	SettingsManager.set_setting("generation_custom_groove", selected_groove)
	SettingsManager.set_setting("generation_custom_density", selected_density)
	SettingsManager.set_setting("generation_custom_grid_snap_strength", selected_grid_snap_strength)
	SettingsManager.set_setting("generation_custom_accent_strong_beats", selected_accent_strong_beats)
	SettingsManager.set_setting("generation_custom_genre_template_strength", selected_genre_template_strength)
	SettingsManager.set_setting("generation_custom_enable_genre_detection", selected_enable_genre_detection)
	SettingsManager.set_setting("generation_custom_use_stems_in_generation", selected_use_stems_in_generation)
	SettingsManager.set_setting("generation_custom_include_hi_hats", selected_include_hi_hats)
	SettingsManager.set_setting("generation_custom_critic_strength", selected_critic_strength)
	SettingsManager.set_setting("generation_custom_groove_completion", selected_groove_completion)
	SettingsManager.set_setting("generation_custom_raw_adtof", selected_raw_adtof)


func _load_custom_preset_from_settings_into_state() -> void:
	selected_fill = int(SettingsManager.get_setting("generation_custom_fill", 50))
	selected_groove = int(SettingsManager.get_setting("generation_custom_groove", 50))
	selected_density = int(SettingsManager.get_setting("generation_custom_density", 50))
	selected_grid_snap_strength = int(SettingsManager.get_setting("generation_custom_grid_snap_strength", 50))
	selected_accent_strong_beats = bool(SettingsManager.get_setting("generation_custom_accent_strong_beats", false))
	selected_genre_template_strength = int(SettingsManager.get_setting("generation_custom_genre_template_strength", 50))
	selected_enable_genre_detection = bool(SettingsManager.get_setting("generation_custom_enable_genre_detection", false))
	selected_use_stems_in_generation = bool(SettingsManager.get_setting("generation_custom_use_stems_in_generation", false))
	selected_include_hi_hats = bool(SettingsManager.get_setting("generation_custom_include_hi_hats", true))
	selected_critic_strength = int(SettingsManager.get_setting("generation_custom_critic_strength", 50))
	selected_groove_completion = bool(SettingsManager.get_setting("generation_custom_groove_completion", true))
	selected_raw_adtof = bool(SettingsManager.get_setting("generation_custom_raw_adtof", false))


func _load_custom_generation_state() -> void:
	var presets := SettingsManager.get_generation_presets()
	var active := int(presets.get("active_slot", 0))
	if active > 0 and _UserPresets.is_generation_slot_filled(presets, active):
		_preset_active_slot = active
		apply_preset_snapshot(_UserPresets.get_generation_slot(presets, active))
		return
	_preset_active_slot = 0
	_load_custom_preset_from_settings_into_state()


func _on_params_changed_from_ui() -> void:
	if selected_mode == "custom":
		_update_active_preset_header()
	_update_selection_visuals()
	_sync_preview()


func _current_param_snapshot() -> Dictionary:
	return {
		"fill": selected_fill,
		"groove": selected_groove,
		"density": selected_density,
		"grid_snap_strength": selected_grid_snap_strength,
		"accent_strong_beats": selected_accent_strong_beats,
		"genre_template_strength": selected_genre_template_strength,
		"enable_genre_detection": selected_enable_genre_detection,
		"use_stems_in_generation": selected_use_stems_in_generation,
		"include_hi_hats": selected_include_hi_hats,
		"critic_strength": selected_critic_strength,
		"groove_completion": selected_groove_completion,
		"raw_adtof": selected_raw_adtof,
	}


func _set_tooltip(control: Control, key: String) -> void:
	if control and key.strip_edges() != "":
		control.tooltip_text = tr(key)


func _apply_param_tooltips() -> void:
	_set_tooltip(fill_label, "GEN_FILL_TOOLTIP")
	_set_tooltip(fill_slider, "GEN_FILL_TOOLTIP")
	_set_tooltip(groove_label, "GEN_GROOVE_TOOLTIP")
	_set_tooltip(groove_slider, "GEN_GROOVE_TOOLTIP")
	_set_tooltip(density_label, "GEN_DENSITY_TOOLTIP")
	_set_tooltip(density_slider, "GEN_DENSITY_TOOLTIP")
	_set_tooltip(grid_snap_label, "GEN_GRID_SNAP_TOOLTIP")
	_set_tooltip(grid_snap_strength_slider, "GEN_GRID_SNAP_TOOLTIP")
	_set_tooltip(genre_template_label, "GEN_GENRE_TEMPLATE_TOOLTIP")
	_set_tooltip(genre_template_strength_slider, "GEN_GENRE_TEMPLATE_TOOLTIP")
	_set_tooltip(critic_strength_label, "GEN_CRITIC_STRENGTH_TOOLTIP")
	_set_tooltip(critic_strength_slider, "GEN_CRITIC_STRENGTH_TOOLTIP")
	_set_tooltip(accent_strong_beats_checkbox, "GEN_ACCENT_STRONG_TOOLTIP")
	_set_tooltip(include_hi_hats_checkbox, "GEN_INCLUDE_HI_HATS_TOOLTIP")
	_set_tooltip(groove_completion_checkbox, "GEN_GROOVE_COMPLETION_TOOLTIP")
	_set_tooltip(raw_adtof_checkbox, "GEN_RAW_ADTOF_TOOLTIP")
	_set_tooltip(enable_genre_detection_checkbox, "GEN_ENABLE_GENRE_TOOLTIP")
	_set_tooltip(enable_stems_checkbox, "GEN_ENABLE_STEMS_TOOLTIP")


func _on_fill_slider_changed(value: float) -> void:
	if _applying_ui_state:
		return
	selected_fill = int(value)
	_update_slider_labels()
	_on_params_changed_from_ui()


func _on_groove_slider_changed(value: float) -> void:
	if _applying_ui_state:
		return
	selected_groove = int(value)
	_update_slider_labels()
	_on_params_changed_from_ui()


func _on_density_slider_changed(value: float) -> void:
	if _applying_ui_state:
		return
	selected_density = int(value)
	_update_slider_labels()
	_on_params_changed_from_ui()


func _on_grid_snap_strength_changed(value: float) -> void:
	if _applying_ui_state:
		return
	selected_grid_snap_strength = int(value)
	_update_slider_labels()
	_on_params_changed_from_ui()


func _on_accent_strong_beats_toggled(toggled_on: bool) -> void:
	if _applying_ui_state:
		return
	selected_accent_strong_beats = toggled_on
	_on_params_changed_from_ui()


func _on_genre_template_strength_changed(value: float) -> void:
	if _applying_ui_state:
		return
	selected_genre_template_strength = int(value)
	_update_slider_labels()
	_on_params_changed_from_ui()


func _on_enable_genre_detection_toggled(enabled: bool) -> void:
	if _applying_ui_state:
		return
	selected_enable_genre_detection = enabled
	SettingsManager.set_setting("enable_genre_detection", enabled)
	_on_params_changed_from_ui()


func _on_enable_stems_toggled(enabled: bool) -> void:
	if _applying_ui_state:
		return
	selected_use_stems_in_generation = enabled
	SettingsManager.set_setting("use_stems_in_generation", enabled)
	_on_params_changed_from_ui()


func _on_include_hi_hats_toggled(enabled: bool) -> void:
	if _applying_ui_state:
		return
	selected_include_hi_hats = enabled
	SettingsManager.set_setting("generation_include_hi_hats", enabled)
	_on_params_changed_from_ui()


func _on_critic_strength_changed(value: float) -> void:
	if _applying_ui_state:
		return
	selected_critic_strength = int(value)
	_update_slider_labels()
	_on_params_changed_from_ui()


func _on_groove_completion_toggled(enabled: bool) -> void:
	if _applying_ui_state or groove_completion_checkbox == null or groove_completion_checkbox.disabled:
		return
	selected_groove_completion = enabled
	_on_params_changed_from_ui()


func _on_raw_adtof_toggled(enabled: bool) -> void:
	if _applying_ui_state or raw_adtof_checkbox == null or raw_adtof_checkbox.disabled:
		return
	selected_raw_adtof = enabled
	if enabled:
		selected_groove_completion = false
	_apply_intent_advanced_guards()
	_on_params_changed_from_ui()


func _set_checkbox_state(checkbox: BaseButton, value: bool) -> void:
	if not checkbox:
		return
	checkbox.set_pressed_no_signal(value)


func _on_advanced_section_toggled(pressed: bool) -> void:
	if advanced_container:
		advanced_container.visible = pressed
	_apply_advanced_toggle_visual(pressed)


func _apply_advanced_section_visual() -> void:
	if not advanced_toggle_button:
		return
	var on := advanced_toggle_button.button_pressed
	if advanced_container:
		advanced_container.visible = on
	_apply_advanced_toggle_visual(on)


func _apply_advanced_toggle_visual(pressed: bool) -> void:
	if advanced_toggle_button:
		var key := "GEN_ADVANCED_TOGGLE_EXPANDED" if pressed else "GEN_ADVANCED_TOGGLE_COLLAPSED"
		advanced_toggle_button.text = ("v " if pressed else "> ") + tr(key)
		advanced_toggle_button.modulate = Color(0.42, 0.57, 0.82) if pressed else Color.WHITE
	var hint := get_node_or_null(ADVANCED + "/AdvancedHintLabel") as Label
	if hint:
		hint.visible = pressed
		if pressed:
			hint.text = tr(_advanced_section_hint_key())


func _update_slider_labels() -> void:
	if fill_label:
		fill_label.text = tr("GEN_SLIDER_FMT") % [tr("GEN_FILL"), selected_fill]
	if groove_label:
		groove_label.text = tr("GEN_SLIDER_FMT") % [tr("GEN_GROOVE"), selected_groove]
	if density_label:
		density_label.text = tr("GEN_SLIDER_FMT") % [tr("GEN_DENSITY"), selected_density]
	if grid_snap_label:
		grid_snap_label.text = tr("GEN_SLIDER_FMT") % [tr("GEN_GRID_SNAP"), selected_grid_snap_strength]
	if genre_template_label:
		genre_template_label.text = tr("GEN_SLIDER_FMT") % [tr("GEN_GENRE_TEMPLATE"), selected_genre_template_strength]
	if critic_strength_label:
		critic_strength_label.text = tr("GEN_SLIDER_FMT") % [tr("GEN_CRITIC_STRENGTH"), selected_critic_strength]


func _on_reset_pressed() -> void:
	MusicManager.play_cancel_sound()
	_applying_ui_state = true
	selected_instrument = "drums"
	selected_lanes = 4
	selected_goal = _GoalDiff.DEFAULT_GOAL
	selected_difficulty = _GoalDiff.DEFAULT_DIFFICULTY
	_apply_goal_difficulty(selected_goal, selected_difficulty, false)
	if advanced_toggle_button:
		advanced_toggle_button.button_pressed = false
	_apply_advanced_section_visual()
	_applying_ui_state = false
	_update_selection_visuals()
	_sync_preview()


func _on_confirm_pressed() -> void:
	selected_goal = _GoalDiff.sanitize_goal(selected_goal)
	selected_difficulty = _GoalDiff.sanitize_difficulty(selected_difficulty)
	selected_intent = _GoalDiff.intent_for(selected_goal, selected_difficulty)
	SettingsManager.set_setting("last_generation_instrument", selected_instrument)
	SettingsManager.set_setting("generation_goal", selected_goal)
	SettingsManager.set_setting("generation_difficulty", selected_difficulty)
	SettingsManager.set_setting("last_generation_intent", selected_intent)
	SettingsManager.set_setting("last_generation_mode", selected_mode)
	SettingsManager.set_setting("last_generation_lanes", selected_lanes)
	SettingsManager.set_setting("generation_fill", selected_fill)
	SettingsManager.set_setting("generation_groove", selected_groove)
	SettingsManager.set_setting("generation_density", selected_density)
	SettingsManager.set_setting("generation_grid_snap_strength", selected_grid_snap_strength)
	SettingsManager.set_setting("generation_accent_strong_beats", selected_accent_strong_beats)
	SettingsManager.set_setting("generation_genre_template_strength", selected_genre_template_strength)
	SettingsManager.set_setting("enable_genre_detection", selected_enable_genre_detection)
	SettingsManager.set_setting("use_stems_in_generation", selected_use_stems_in_generation)
	SettingsManager.set_setting("generation_include_hi_hats", selected_include_hi_hats)
	SettingsManager.set_setting("generation_critic_strength", selected_critic_strength)
	SettingsManager.set_setting("generation_groove_completion", selected_groove_completion)
	SettingsManager.set_setting("generation_raw_adtof", selected_raw_adtof)
	if selected_mode == "custom":
		_persist_custom_preset_to_settings()
	SettingsManager.save_settings()
	emit_signal("generation_settings_confirmed", selected_instrument, selected_mode, selected_lanes)
	emit_signal("selector_closed")


func _on_back_button_pressed() -> void:
	emit_signal("selector_closed")


func set_current_song_path(path: String) -> void:
	set_current_song_data({"path": path})


func set_current_song_data(song: Dictionary) -> void:
	current_song_data = song.duplicate(true) if not song.is_empty() else {}
	current_song_path = str(current_song_data.get("path", "")).replace("\\", "/")
	_update_status_indicator()
	_update_smart_preset_recommendation()
	_sync_preview()


func _ensure_smart_hint_labels() -> void:
	var section := get_node_or_null(MODE_SECTION) as VBoxContainer
	if section == null:
		return
	smart_hint_label = section.get_node_or_null("SmartHintLabel") as Label
	if smart_hint_label == null:
		smart_hint_label = Label.new()
		smart_hint_label.name = "SmartHintLabel"
		smart_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		smart_hint_label.add_theme_font_size_override("font_size", 13)
		smart_hint_label.add_theme_color_override("font_color", Color(0.72, 0.82, 0.95, 0.95))
		section.add_child(smart_hint_label)
		section.move_child(smart_hint_label, section.get_child_count())
	smart_warn_label = section.get_node_or_null("SmartWarnLabel") as Label
	if smart_warn_label == null:
		smart_warn_label = Label.new()
		smart_warn_label.name = "SmartWarnLabel"
		smart_warn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		smart_warn_label.add_theme_font_size_override("font_size", 12)
		smart_warn_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35, 0.92))
		smart_warn_label.visible = false
		section.add_child(smart_warn_label)
		section.move_child(smart_warn_label, section.get_child_count())
	var status_vbox := get_node_or_null(ROOT + "/HeaderTop/TrackStatusPanel/StatusVBox") as VBoxContainer
	if status_vbox == null:
		return
	status_hint_label = status_vbox.get_node_or_null("StatusHintLabel") as Label
	if status_hint_label == null:
		status_hint_label = Label.new()
		status_hint_label.name = "StatusHintLabel"
		status_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status_hint_label.add_theme_font_size_override("font_size", 12)
		status_hint_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35, 0.9))
		status_hint_label.visible = false
		status_vbox.add_child(status_hint_label)


func _update_smart_preset_recommendation() -> void:
	if _goal_cards.is_empty():
		return
	var song := _song_data_for_recommendation()
	var dna := _Recommender.load_dna_for_song(
		current_song_path,
		selected_instrument,
		_GoalDiff.chart_stem(selected_goal, selected_difficulty),
		selected_lanes,
	)
	_smart_recommendation = _Recommender.recommend(song, dna)
	var recommended_intent := str(_smart_recommendation.get("intent", "groove"))
	var recommended_pair := _GoalDiff.from_intent(recommended_intent)
	var recommended_goal := str(recommended_pair.get("goal", "arcade"))
	for goal_id in _goal_cards:
		var gcard: GenerationSelectCard = _goal_cards[goal_id]
		gcard.set_recommended(goal_id == recommended_goal and current_song_path != "")
	if smart_hint_label:
		if current_song_path == "":
			smart_hint_label.visible = false
			smart_hint_label.text = ""
		else:
			var goal_name := tr("GEN_GOAL_%s" % recommended_goal.to_upper())
			var reason_key := str(_smart_recommendation.get("reason_key", "GEN_SMART_REASON_DEFAULT"))
			var reason_args: Variant = _smart_recommendation.get("reason_args", {})
			var reason := _format_tr_with_args(reason_key, reason_args)
			smart_hint_label.visible = true
			smart_hint_label.text = tr("GEN_SMART_HINT_FMT") % [goal_name, reason]
	if smart_warn_label:
		var warn_key := _Recommender.warn_if_selected(selected_intent, _smart_recommendation)
		if warn_key == "":
			smart_warn_label.visible = false
			smart_warn_label.text = ""
		else:
			smart_warn_label.visible = true
			smart_warn_label.text = tr(warn_key)


func _format_tr_with_args(key: String, args: Variant) -> String:
	var text := tr(key)
	if not args is Dictionary or args.is_empty():
		return text
	if text.find("%") < 0:
		return text
	if args.has("count"):
		return text % int(args["count"])
	if args.has("bpm"):
		return text % int(args["bpm"])
	return text


func _song_data_for_recommendation() -> Dictionary:
	if not current_song_data.is_empty():
		return current_song_data
	if current_song_path == "":
		return {}
	var meta := SongLibrary.get_metadata_for_song(current_song_path)
	var merged := meta.duplicate(true)
	merged["path"] = current_song_path
	return merged


func _percussion_low_from_dna(dna: Dictionary) -> bool:
	if dna.is_empty():
		return false
	var genes: Dictionary = dna.get("genes", {}) if dna.get("genes", {}) is Dictionary else {}
	var rhythm: Dictionary = genes.get("rhythm", {}) if genes.get("rhythm", {}) is Dictionary else {}
	return String(rhythm.get("percussion_viable", "")).strip_edges().to_lower() == "low"


func _update_status_indicator() -> void:
	_sync_preview()
	call_deferred("_layout_nav_buttons")


func _notes_exist_for_selection() -> bool:
	if current_song_path == "":
		return false
	return NotesUtils.notes_ready_for_scope(
		current_song_path,
		selected_instrument,
		_GoalDiff.chart_stem(selected_goal, selected_difficulty),
		selected_lanes,
	)



func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var viewport := get_viewport()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_on_back_button_pressed()
			viewport.set_input_as_handled()
			return
		if event.keycode == KEY_R and event.shift_pressed:
			_on_reset_pressed()
			viewport.set_input_as_handled()
			return
	if UiScreenHotkeys.try_handle(_generation_hotkey_bindings(), event, viewport):
		viewport.set_input_as_handled()


func _generation_hotkey_bindings() -> Dictionary:
	return {
		KEY_1: _hotkey_select_instrument.bind("drums"),
		KEY_2: _hotkey_select_instrument.bind("bass"),
		KEY_Q: _hotkey_select_goal.bind("original"),
		KEY_W: _hotkey_select_goal.bind("arcade"),
		KEY_E: _hotkey_select_difficulty.bind("relaxed"),
		KEY_R: _hotkey_select_difficulty.bind("standard"),
		KEY_T: _hotkey_select_difficulty.bind("dense"),
		KEY_Z: _hotkey_toggle_advanced,
		KEY_A: _hotkey_select_lanes.bind(3),
		KEY_S: _hotkey_select_lanes.bind(4),
		KEY_D: _hotkey_select_lanes.bind(5),
		KEY_ENTER: _on_confirm_pressed,
		KEY_KP_ENTER: _on_confirm_pressed,
	}


func _hotkey_select_instrument(instrument_id: String) -> void:
	if not _is_instrument_hotkey_enabled(instrument_id):
		return
	var prev := selected_instrument
	_on_instrument_card_selected(instrument_id)
	if prev != selected_instrument and _instrument_cards.has(instrument_id):
		_pulse_hotkey_target(_instrument_cards[instrument_id])


func _is_instrument_hotkey_enabled(instrument_id: String) -> bool:
	for spec in INSTRUMENT_SPECS:
		if str(spec.get("id", "")) == instrument_id:
			return bool(spec.get("enabled", false))
	return false


func _hotkey_select_goal(goal_id: String) -> void:
	if goal_id not in _GoalDiff.GOALS:
		return
	var prev_goal := selected_goal
	var prev_mode := selected_mode
	_on_goal_card_selected(goal_id)
	if (prev_goal != selected_goal or prev_mode != selected_mode) and _goal_cards.has(goal_id):
		_pulse_hotkey_target(_goal_cards[goal_id])


func _hotkey_select_difficulty(difficulty_id: String) -> void:
	if selected_goal == "original":
		return
	if difficulty_id not in _GoalDiff.DIFFICULTIES:
		return
	var prev := selected_difficulty
	_apply_goal_difficulty(selected_goal, difficulty_id, true)
	if prev != selected_difficulty:
		UiScreenHotkeys.play_section_switch_sound()
		var seg_buttons: Array = _difficulty_seg.get("buttons", [])
		for btn in seg_buttons:
			if btn is Button and _GoalDiff.difficulty_from_option_id(_SegmentedOptionUtils.id_from_button(btn)) == selected_difficulty:
				_pulse_hotkey_target(btn)
				break


func _hotkey_select_intent(intent_id: String) -> void:
	_on_goal_card_selected(intent_id)


func _hotkey_select_lanes(lanes: int) -> void:
	var prev := selected_lanes
	_on_lane_button_pressed(lanes)
	if prev != selected_lanes and _lane_buttons.has(lanes):
		_pulse_hotkey_target(_lane_buttons[lanes])


func _pulse_hotkey_target(control: Control) -> void:
	if control == null:
		return
	control.notification(Control.NOTIFICATION_MOUSE_ENTER)
	var tree := get_tree()
	if tree == null:
		return
	tree.create_timer(0.12).timeout.connect(func() -> void:
		if is_instance_valid(control):
			control.notification(Control.NOTIFICATION_MOUSE_EXIT)
	, CONNECT_ONE_SHOT)


func _hotkey_toggle_advanced() -> void:
	if not advanced_toggle_button:
		return
	advanced_toggle_button.button_pressed = not advanced_toggle_button.button_pressed


func get_draft_snapshot() -> Dictionary:
	return {
		"instrument": selected_instrument,
		"goal": selected_goal,
		"difficulty": selected_difficulty,
		"intent": selected_intent,
		"mode": selected_mode,
		"lanes": selected_lanes,
		"fill": selected_fill,
		"groove": selected_groove,
		"density": selected_density,
		"grid_snap_strength": selected_grid_snap_strength,
		"accent_strong_beats": selected_accent_strong_beats,
		"genre_template_strength": selected_genre_template_strength,
		"enable_genre_detection": selected_enable_genre_detection,
		"use_stems_in_generation": selected_use_stems_in_generation,
		"include_hi_hats": selected_include_hi_hats,
		"critic_strength": selected_critic_strength,
		"groove_completion": selected_groove_completion,
		"raw_adtof": selected_raw_adtof,
	}


func apply_preset_snapshot(snapshot: Dictionary) -> void:
	var sanitized := _UserPresets.sanitize_generation_slot(snapshot)
	_applying_ui_state = true
	selected_instrument = str(sanitized.get("instrument", "drums"))
	if selected_instrument not in ["drums", "bass"]:
		selected_instrument = "drums"
	selected_lanes = int(sanitized.get("lanes", 4))
	selected_fill = int(sanitized.get("fill", 50))
	selected_groove = int(sanitized.get("groove", 50))
	selected_density = int(sanitized.get("density", 50))
	selected_grid_snap_strength = int(sanitized.get("grid_snap_strength", 50))
	selected_accent_strong_beats = bool(sanitized.get("accent_strong_beats", false))
	selected_genre_template_strength = int(sanitized.get("genre_template_strength", 50))
	selected_enable_genre_detection = bool(sanitized.get("enable_genre_detection", true))
	selected_use_stems_in_generation = bool(sanitized.get("use_stems_in_generation", true))
	selected_include_hi_hats = bool(sanitized.get("include_hi_hats", true))
	selected_critic_strength = int(sanitized.get("critic_strength", 50))
	selected_groove_completion = bool(sanitized.get("groove_completion", true))
	selected_raw_adtof = bool(sanitized.get("raw_adtof", false))
	selected_mode = "custom"
	var saved_intent := str(sanitized.get("intent", "")).strip_edges()
	if saved_intent != "" and saved_intent in INTENTS:
		selected_intent = saved_intent
	else:
		selected_intent = _Intents.closest_intent_for_params({
			"fill": selected_fill,
			"groove": selected_groove,
			"density": selected_density,
			"grid_snap_strength": selected_grid_snap_strength,
			"accent_strong_beats": selected_accent_strong_beats,
			"genre_template_strength": selected_genre_template_strength,
			"enable_genre_detection": selected_enable_genre_detection,
			"use_stems_in_generation": selected_use_stems_in_generation,
			"include_hi_hats": selected_include_hi_hats,
			"critic_strength": selected_critic_strength,
			"groove_completion": selected_groove_completion,
			"raw_adtof": selected_raw_adtof,
		})
		if selected_intent == "":
			selected_intent = "groove"
	var saved_goal := str(sanitized.get("goal", "")).strip_edges().to_lower()
	var saved_difficulty := str(sanitized.get("difficulty", "")).strip_edges().to_lower()
	if _GoalDiff.is_goal(saved_goal) and _GoalDiff.is_difficulty(saved_difficulty):
		selected_goal = saved_goal
		selected_difficulty = saved_difficulty
		selected_intent = _GoalDiff.intent_for(selected_goal, selected_difficulty)
	else:
		var pair := _GoalDiff.from_intent(selected_intent)
		selected_goal = str(pair.get("goal", _GoalDiff.DEFAULT_GOAL))
		selected_difficulty = str(pair.get("difficulty", _GoalDiff.DEFAULT_DIFFICULTY))
	_apply_goal_difficulty(selected_goal, selected_difficulty, false, true)
	_applying_ui_state = false
	_update_selection_visuals()
	_sync_preview()


func _on_presets_pressed() -> void:
	if _presets_dialog and is_instance_valid(_presets_dialog):
		return
	_UiModifierSounds.play_select()
	_presets_dialog = PRESETS_DIALOG_SCENE.instantiate()
	if _presets_dialog.has_method("configure"):
		_presets_dialog.configure(_UserPresets.DOMAIN_GENERATION)
	if _presets_dialog.has_method("set_preset_host"):
		_presets_dialog.set_preset_host(self)
	add_child(_presets_dialog)
	move_child(_presets_dialog, -1)
	if _presets_dialog.has_signal("closed"):
		_presets_dialog.closed.connect(_on_presets_dialog_closed)
	if _presets_dialog.has_method("apply_locale"):
		_presets_dialog.apply_locale()
	UiInteractionApplier.apply_from_engine(_presets_dialog)


func _sync_preset_tracking() -> void:
	var presets := SettingsManager.get_generation_presets()
	_preset_active_slot = int(presets.get("active_slot", 0))
	if _preset_active_slot > 0:
		_load_custom_generation_state()
		_apply_sliders_to_ui()
	_reconcile_preset_baseline()
	_update_active_preset_header()


func _reconcile_preset_baseline() -> void:
	_preset_baseline = _UserPresets.generation_body_from_slot(get_draft_snapshot()).duplicate(true)


func preset_host_get_active_slot() -> int:
	return _preset_active_slot


func preset_host_get_active_name() -> String:
	if _preset_active_slot <= 0:
		return ""
	return _UserPresets.generation_display_name(
		SettingsManager.get_generation_presets(),
		_preset_active_slot,
	)


func preset_host_is_dirty() -> bool:
	if _preset_active_slot <= 0:
		return false
	var presets := SettingsManager.get_generation_presets()
	if not _UserPresets.is_generation_slot_filled(presets, _preset_active_slot):
		return false
	var saved := _UserPresets.generation_body_from_slot(
		_UserPresets.get_generation_slot(presets, _preset_active_slot)
	)
	var current := _UserPresets.generation_body_from_slot(get_draft_snapshot())
	return saved != current


func preset_host_get_song_path() -> String:
	return current_song_path


func preset_host_get_chart_tag() -> String:
	if _preset_active_slot <= 0:
		return ""
	return NotesUtils.resolve_chart_tag_for_generation(
		"custom",
		_preset_active_slot,
		preset_host_is_dirty(),
	)


func preset_host_is_custom_with_active_preset() -> bool:
	return _preset_active_slot > 0


func preset_host_should_block_mass_generation() -> bool:
	return int(SettingsManager.get_generation_presets().get("active_slot", 0)) > 0


func preset_host_preset_chart_exists() -> bool:
	if _preset_active_slot <= 0 or current_song_path == "":
		return false
	return NotesUtils.preset_chart_exists(current_song_path, selected_instrument, _preset_active_slot)


func _clear_generation_active_preset() -> void:
	if _preset_active_slot <= 0:
		return
	var presets := SettingsManager.get_generation_presets()
	if int(presets.get("active_slot", 0)) == _preset_active_slot:
		presets = _UserPresets.set_active_generation_slot(presets, 0)
		SettingsManager.set_generation_presets(presets)
	_preset_active_slot = 0
	_preset_baseline = {}
	_update_active_preset_header()


func preset_host_get_current_state() -> Dictionary:
	return get_draft_snapshot()


func preset_host_apply_preset(slot: int, snapshot: Dictionary) -> void:
	apply_preset_snapshot(snapshot)
	_preset_active_slot = slot
	_reconcile_preset_baseline()
	_update_active_preset_header()


func preset_host_mark_saved(slot: int) -> void:
	_preset_active_slot = slot
	_reconcile_preset_baseline()
	_update_active_preset_header()


func preset_host_clear_active() -> void:
	_reset_style_to_intent_defaults()


func _on_presets_dialog_closed(preset_loaded: bool = false) -> void:
	_presets_dialog = null
	_update_active_preset_header()
	if not preset_loaded:
		_UiModifierSounds.play_deselect()
