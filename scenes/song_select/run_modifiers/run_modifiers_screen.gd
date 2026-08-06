# scenes/song_select/run_modifiers/run_modifiers_screen.gd
extends Control

const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const _Sections = preload("res://scenes/song_select/run_modifiers/run_modifier_sections.gd")
const _DynamicLanesSchedule = preload("res://logic/domain/rhythm/dynamic_lanes_schedule.gd")
const _Overlay = preload("res://logic/ui/app_overlay_helpers.gd")
const _ChoiceOverlayScene = preload("res://ui/overlays/app_choice_overlay.tscn")
const HELP_CALLOUT_SCENE = preload("res://scenes/help/help_callout.tscn")
const PRESETS_DIALOG_SCENE = preload("res://scenes/song_select/run_modifiers/modifier_presets_dialog.tscn")
const _UserPresets = preload("res://logic/domain/modifiers/user_presets.gd")
const _UiModifierSounds = preload("res://logic/ui/ui_modifier_sounds.gd")
const _PresetActiveHeader = preload("res://logic/ui/preset_active_header.gd")
const _StatusToast = preload("res://logic/ui/status_toast.gd")
const _SpotlightTutorialScene = preload("res://ui/spotlight_tutorial.tscn")
const _SettingsSectionUi = preload("res://logic/ui/settings_section_ui.gd")

const TAB_OVERVIEW := "overview"
const TAB_EASING := "easing"
const TAB_HARDENING := "hardening"
const TAB_SPECIAL := "special"
const TAB_DNA := "dna"

const RIGHT_VIEW_SUMMARY := "summary"
const RIGHT_VIEW_DETAIL := "detail"
const RIGHT_VIEW_PARAMS := "params"


static func _dna_tab_title() -> String:
	var beta := TranslationServer.translate("MOD_DNA_BETA_CAPTION")
	if beta == "MOD_DNA_BETA_CAPTION":
		beta = "Бета" if TranslationServer.get_locale().begins_with("ru") else "Beta"
	return "%s · %s" % [TranslationServer.translate("MOD_CAT_DNA"), beta]


static func _dna_beta_callout_body() -> String:
	var body := TranslationServer.translate("MOD_DNA_BETA_CALLOUT")
	if body != "MOD_DNA_BETA_CALLOUT":
		return body
	if TranslationServer.get_locale().begins_with("ru"):
		return (
			"Моды по секциям в бете — поведение и отчёты Rhythm DNA ещё дорабатываются. "
			+ "Нужен sidecar .rfd от генерации ударных."
		)
	return (
		"Section-based mods are in beta — behavior and Rhythm DNA reports may still change. "
		+ "Requires an .rfd sidecar from drum chart generation."
	)


static func _dna_beta_callout_caption() -> String:
	var caption := TranslationServer.translate("MOD_DNA_BETA_CAPTION")
	if caption != "MOD_DNA_BETA_CAPTION":
		return caption
	return "Бета" if TranslationServer.get_locale().begins_with("ru") else "Beta"

const _TUTORIAL_PARAMS_DEMO_MOD := "slow_75"

signal modifiers_changed(active_modifiers: Array)
signal screen_closed

@onready var _back_button: Button = $RootMargin/RootVBox/HeaderRow/BackButton
@onready var _presets_button: Button = $RootMargin/RootVBox/HeaderRow/PresetsButton
@onready var _title_label: Label = $RootMargin/RootVBox/HeaderRow/TitleVBox/TitleLabel
@onready var _subtitle_label: Label = $RootMargin/RootVBox/HeaderRow/TitleVBox/SubtitleLabel
var _active_preset_row: HBoxContainer = null
var _clear_preset_link: LinkButton = null
@onready var _page_title_label: Label = $RootMargin/RootVBox/MainHBox/CenterColumn/PageTitleLabel
@onready var _nav_overview: RunModifierSidebarTab = $RootMargin/RootVBox/MainHBox/SidebarCard/SidebarMargin/SidebarVBox/NavScroll/NavVBox/NavOverview
@onready var _nav_easing: RunModifierSidebarTab = $RootMargin/RootVBox/MainHBox/SidebarCard/SidebarMargin/SidebarVBox/NavScroll/NavVBox/NavEasing
@onready var _nav_hardening: RunModifierSidebarTab = $RootMargin/RootVBox/MainHBox/SidebarCard/SidebarMargin/SidebarVBox/NavScroll/NavVBox/NavHardening
@onready var _nav_special: RunModifierSidebarTab = $RootMargin/RootVBox/MainHBox/SidebarCard/SidebarMargin/SidebarVBox/NavScroll/NavVBox/NavSpecial
@onready var _nav_dna: RunModifierSidebarTab = $RootMargin/RootVBox/MainHBox/SidebarCard/SidebarMargin/SidebarVBox/NavScroll/NavVBox/NavDna
@onready var _nav_params: RunModifierSidebarTab = $RootMargin/RootVBox/MainHBox/SidebarCard/SidebarMargin/SidebarVBox/NavScroll/NavVBox/NavParams
@onready var _overview_tab = $RootMargin/RootVBox/MainHBox/CenterColumn/CenterCard/CenterMargin/TabStack/OverviewTab
@onready var _easing_tab = $RootMargin/RootVBox/MainHBox/CenterColumn/CenterCard/CenterMargin/TabStack/EasingTab
@onready var _hardening_tab = $RootMargin/RootVBox/MainHBox/CenterColumn/CenterCard/CenterMargin/TabStack/HardeningTab
@onready var _special_tab = $RootMargin/RootVBox/MainHBox/CenterColumn/CenterCard/CenterMargin/TabStack/SpecialTab
@onready var _dna_tab = $RootMargin/RootVBox/MainHBox/CenterColumn/CenterCard/CenterMargin/TabStack/DnaTab
@onready var _params_tab = $RootMargin/RootVBox/MainHBox/CenterColumn/CenterCard/CenterMargin/TabStack/ParamsTab
@onready var _detail_panel: RunModifierDetailPanel = $RootMargin/RootVBox/MainHBox/RightCard/RightMargin/RightStack/DetailPanel
@onready var _params_panel: RunModifierParamsPanel = $RootMargin/RootVBox/MainHBox/RightCard/RightMargin/RightStack/ParamsPanel
@onready var _summary_panel: RunModifierSummaryPanel = $RootMargin/RootVBox/MainHBox/RightCard/RightMargin/RightStack/SummaryPanel
@onready var _right_summary_btn: Button = $RootMargin/RootVBox/MainHBox/RightCard/RightMargin/RightStack/RightPanelToggle/TopRow/RightPanelSummaryBtn
@onready var _right_detail_btn: Button = $RootMargin/RootVBox/MainHBox/RightCard/RightMargin/RightStack/RightPanelToggle/TopRow/RightPanelDetailBtn
@onready var _right_params_btn: Button = $RootMargin/RootVBox/MainHBox/RightCard/RightMargin/RightStack/RightPanelToggle/RightPanelParamsBtn
@onready var _conflicts_callout_slot: VBoxContainer = $RootMargin/RootVBox/FooterRow/FooterPanels/ConflictsCalloutSlot
@onready var _hint_callout_slot: VBoxContainer = $RootMargin/RootVBox/FooterRow/FooterPanels/HintCalloutSlot
@onready var _hotkeys_label: Label = $RootMargin/RootVBox/FooterRow/HotkeysLabel
@onready var _sidebar_card: PanelContainer = $RootMargin/RootVBox/MainHBox/SidebarCard
@onready var _center_card: PanelContainer = $RootMargin/RootVBox/MainHBox/CenterColumn/CenterCard

var _conflicts_callout: HelpCallout = null
var _hint_callout: HelpCallout = null
var _dna_help_link: Button = null
var _spotlight_tutorial: CanvasLayer = null

var _tabs: Dictionary = {}
var _nav_items: Array[RunModifierSidebarTab] = []
var _current_tab_id: String = TAB_OVERVIEW
var _pending_active_modifiers: Array[String] = []
var _focused_modifier_id: String = ""
var _panel_lock_id: String = ""
var _panel_lock_mode: String = ""
var _right_panel_view: String = RIGHT_VIEW_SUMMARY
var _right_panel_manual := false
var _right_panel_toggle_group: ButtonGroup = null
var _run_params: Dictionary = {}
var _playfield_lanes: int = 4
var _song_path: String = ""
var _song_instrument: String = "drums"
var _song_mode: String = "basic"
var _committed_modifiers: Array[String] = []
var _committed_params: Dictionary = {}
var _back_prompt_active := false
var _choice_overlay: AppChoiceOverlay = null
var _secondary_tabs_built := false
var _presets_dialog: Control = null
var _preset_active_slot: int = 0
var _preset_baseline: Dictionary = {}
var _keyboard_nav_active := false
var _kb_focus_mod_id := ""


func _ready() -> void:
	CsvTranslationLoader.load_into_translation_server("res://translations/ui.csv")
	UiIconHelper.configure_modal_overlay(self, 100)
	_choice_overlay = _ChoiceOverlayScene.instantiate() as AppChoiceOverlay
	if _choice_overlay:
		add_child(_choice_overlay)
	_bind_nav()
	if _overview_tab:
		_overview_tab.build_overview()
	call_deferred("_build_secondary_modifier_tabs")
	_setup_ui_icons()
	_setup_right_panel_toggle()
	_back_button.pressed.connect(_on_back_pressed)
	if _presets_button:
		_presets_button.pressed.connect(_on_presets_pressed)
	_summary_panel.confirm_pressed.connect(_on_confirm_pressed)
	_summary_panel.reset_pressed.connect(_on_reset_pressed)
	if _params_panel:
		_params_panel.param_changed.connect(_on_param_changed)
	_setup_footer_callouts()
	_connect_card_signals(_overview_tab)
	_connect_card_signals(_easing_tab)
	_connect_card_signals(_hardening_tab)
	_connect_card_signals(_special_tab)
	_connect_card_signals(_dna_tab)
	if _nav_params:
		_nav_params.visible = false
	if _params_tab:
		_params_tab.visible = false
	var title_vbox := _subtitle_label.get_parent() as VBoxContainer
	if title_vbox:
		_active_preset_row = _PresetActiveHeader.attach(title_vbox, _subtitle_label.get_index() + 1)
		_setup_clear_preset_link(title_vbox)
	_apply_pending_modifier_state()
	_load_run_params()
	_select_tab(TAB_OVERVIEW, false)
	call_deferred("_sync_preset_tracking")
	call_deferred("_sync_detail_params")
	call_deferred("apply_locale")
	call_deferred("_maybe_show_modifiers_tutorial")


func _setup_ui_icons() -> void:
	UiIconHelper.apply_standard_back_button(_back_button)
	if _presets_button:
		_presets_button.theme_type_variation = &"FlatBackButton"
		UiIconHelper.configure_button_icon(_presets_button, "tags.svg", UiIconHelper.MUTED, 16)
	if _right_summary_btn:
		UiIconHelper.configure_button_icon(
			_right_summary_btn,
			"layout-dashboard.svg",
			Color(0.95, 0.82, 0.45, 1.0),
			16,
		)
	if _right_detail_btn:
		UiIconHelper.configure_button_icon(
			_right_detail_btn,
			"scroll-text.svg",
			Color(0.55, 0.78, 0.98, 1.0),
			16,
		)
	if _right_params_btn:
		UiIconHelper.configure_button_icon(
			_right_params_btn,
			"settings.svg",
			Color(0.48, 0.72, 0.98, 1.0),
			16,
		)


func apply_locale() -> void:
	if _title_label:
		_title_label.text = tr("MOD_POPUP_TITLE")
	if _subtitle_label:
		_subtitle_label.text = tr("MOD_POPUP_HINT")
	if _hotkeys_label:
		_hotkeys_label.text = tr("MOD_FOOTER_HINT_V2")
	if _back_button:
		_back_button.text = tr("BTN_BACK")
	if _presets_button:
		_presets_button.text = tr("MOD_PRESETS_BUTTON")
	_update_active_preset_header()
	_refresh_footer_callouts()
	if _detail_panel:
		_detail_panel.apply_locale()
	if _params_panel:
		_params_panel.apply_locale()
	_nav_overview.setup(TAB_OVERVIEW, tr("MOD_TAB_OVERVIEW"), "layout-dashboard.svg", Color(0.95, 0.82, 0.45, 1.0))
	_nav_easing.setup(TAB_EASING, tr("MOD_CAT_EASING"), "feather.svg", Color(0.42, 0.88, 0.58, 1.0))
	_nav_hardening.setup(TAB_HARDENING, tr("MOD_CAT_HARDENING"), "flame_gen.svg", Color(0.95, 0.45, 0.42, 1.0))
	_nav_special.setup(TAB_SPECIAL, tr("MOD_CAT_SPECIAL"), "wrench.svg", Color(0.42, 0.72, 0.96, 1.0))
	_nav_dna.setup(TAB_DNA, _dna_tab_title(), "rhythmdna.svg", UiIconHelper.ACCENT_DNA)
	if _overview_tab:
		_overview_tab.apply_locale()
	for tab in [_easing_tab, _hardening_tab, _special_tab, _dna_tab]:
		if tab and tab.has_method("apply_locale"):
			tab.apply_locale()
	if _summary_panel:
		_summary_panel.apply_locale()
	if _right_summary_btn:
		_right_summary_btn.text = tr("MOD_RIGHT_PANEL_SUMMARY")
	if _right_detail_btn:
		_right_detail_btn.text = tr("MOD_RIGHT_PANEL_DETAIL")
	if _right_params_btn:
		_right_params_btn.text = tr("MOD_RIGHT_PANEL_PARAMS")
	_refresh_ui()
	_refresh_dna_gated_modifiers()


func set_active_modifiers(modifiers: Array) -> void:
	_committed_modifiers = _RunModifiers.sanitize(modifiers)
	_pending_active_modifiers = _committed_modifiers.duplicate()
	_load_run_params()
	_committed_params = _run_params.duplicate()
	_apply_pending_modifier_state()
	_sync_preset_tracking()


func set_playfield_lanes(lane_count: int) -> void:
	_playfield_lanes = clampi(lane_count, 1, 5)
	if _playfield_lanes <= 1:
		_deactivate_modifier(_RunModifiers.ID_SINGLE_LANE)
	_refresh_single_lane_visibility()
	_refresh_dynamic_lanes_availability()


func set_song_context(song_path: String, instrument: String, mode: String, lane_count: int) -> void:
	_song_path = song_path.strip_edges()
	_song_instrument = instrument.strip_edges() if instrument != "" else "drums"
	_song_mode = mode.strip_edges() if mode != "" else "basic"
	_playfield_lanes = clampi(lane_count, 1, 5)
	_refresh_dynamic_lanes_availability()


func get_active_modifiers() -> Array[String]:
	var mods: Array[String] = []
	for spec in (
		_Sections.all_ease_specs()
		+ _Sections.all_hard_specs()
		+ _Sections.all_special_specs()
		+ _Sections.all_dna_specs()
	):
		var id := str(spec[0])
		if _is_modifier_active(id):
			mods.append(id)
	return _RunModifiers.sanitize_for_lanes(mods, _playfield_lanes)


func get_draft_snapshot() -> Dictionary:
	return {
		"modifiers": get_active_modifiers().duplicate(),
		"params": _RunModifiers.sanitize_params(_run_params).duplicate(),
	}


func apply_draft_snapshot(snapshot: Dictionary, emit_changed: bool = true) -> void:
	if snapshot is not Dictionary:
		return
	_pending_active_modifiers = _RunModifiers.sanitize(snapshot.get("modifiers", []))
	_run_params = _RunModifiers.sanitize_params(snapshot.get("params", _run_params))
	_apply_pending_modifier_state(false)
	_sync_detail_params()
	if emit_changed:
		modifiers_changed.emit(get_active_modifiers())
	_refresh_ui()


func _on_presets_pressed() -> void:
	if _presets_dialog and is_instance_valid(_presets_dialog):
		return
	_UiModifierSounds.play_select()
	_presets_dialog = PRESETS_DIALOG_SCENE.instantiate()
	if _presets_dialog.has_method("set_preset_host"):
		_presets_dialog.set_preset_host(self)
	var host := get_parent()
	if host:
		host.add_child(_presets_dialog)
		host.move_child(_presets_dialog, -1)
	if _presets_dialog.has_signal("closed"):
		_presets_dialog.closed.connect(_on_presets_dialog_closed)
	if _presets_dialog.has_method("apply_locale"):
		_presets_dialog.apply_locale()
	UiInteractionApplier.apply_from_engine(_presets_dialog)


func _sync_preset_tracking() -> void:
	var presets := SettingsManager.get_run_modifier_presets()
	_preset_active_slot = int(presets.get("active_slot", 0))
	_preset_baseline = get_draft_snapshot().duplicate(true)
	_update_active_preset_header()


func preset_host_get_active_slot() -> int:
	return _preset_active_slot


func preset_host_get_active_name() -> String:
	if _preset_active_slot <= 0:
		return ""
	return _UserPresets.display_name(SettingsManager.get_run_modifier_presets(), _preset_active_slot)


func preset_host_is_dirty() -> bool:
	if _preset_active_slot <= 0:
		return false
	return not _UserPresets.modifier_states_equal(_preset_baseline, get_draft_snapshot())


func preset_host_get_current_state() -> Dictionary:
	return get_draft_snapshot()


func preset_host_apply_preset(slot: int, payload: Dictionary) -> void:
	apply_draft_snapshot(payload, true)
	_preset_active_slot = slot
	_preset_baseline = get_draft_snapshot().duplicate(true)


func preset_host_mark_saved(slot: int) -> void:
	_preset_active_slot = slot
	_preset_baseline = get_draft_snapshot().duplicate(true)
	_update_active_preset_header()


func preset_host_clear_active() -> void:
	_preset_active_slot = 0
	_preset_baseline = {}
	_update_active_preset_header()


func preset_host_clear_preset() -> void:
	_pending_active_modifiers = []
	_run_params = _RunModifiers.default_params()
	_preset_active_slot = 0
	_preset_baseline = get_draft_snapshot().duplicate(true)
	_apply_pending_modifier_state(false)
	_sync_detail_params()
	_focused_modifier_id = ""
	var mods := get_active_modifiers()
	_committed_modifiers = mods.duplicate()
	_committed_params = _RunModifiers.sanitize_params(_run_params).duplicate()
	SettingsManager.set_run_modifier_params(_run_params)
	SettingsManager.set_run_modifiers(mods)
	SettingsManager.sync_active_run_modifier_preset(mods, _run_params)
	modifiers_changed.emit(mods.duplicate())
	_refresh_ui()


func _update_active_preset_header() -> void:
	if _active_preset_row == null:
		return
	var name := preset_host_get_active_name()
	if name == "" and _preset_active_slot > 0:
		name = _UserPresets.display_name(
			SettingsManager.get_run_modifier_presets(),
			_preset_active_slot,
		)
	_PresetActiveHeader.update(
		_active_preset_row,
		_preset_active_slot,
		name,
		preset_host_is_dirty(),
	)
	_update_clear_preset_link()


func _setup_clear_preset_link(parent: VBoxContainer) -> void:
	if parent == null or _clear_preset_link != null:
		return
	_clear_preset_link = LinkButton.new()
	_clear_preset_link.name = &"ClearPresetLink"
	_clear_preset_link.text = tr("MOD_PRESETS_CLEAR_ACTIVE")
	_clear_preset_link.add_theme_font_size_override("font_size", 14)
	_clear_preset_link.add_theme_color_override("font_color", Color(0.55, 0.64, 0.76, 0.92))
	_clear_preset_link.add_theme_color_override("font_hover_color", Color(0.72, 0.82, 0.96, 1.0))
	_clear_preset_link.visible = false
	_clear_preset_link.pressed.connect(_on_clear_preset_link_pressed)
	parent.add_child(_clear_preset_link)


func _update_clear_preset_link() -> void:
	if _clear_preset_link:
		_clear_preset_link.visible = _preset_active_slot > 0
		_clear_preset_link.text = tr("MOD_PRESETS_CLEAR_ACTIVE")


func _on_clear_preset_link_pressed() -> void:
	if _preset_active_slot <= 0:
		return
	await _commit_clear_active_preset()


func _commit_clear_active_preset() -> bool:
	if _preset_active_slot <= 0 and _active_slot_from_settings() <= 0:
		return false
	if _is_dirty():
		var choice := await _prompt_clear_preset_dirty()
		if choice != "confirm":
			return false
	var presets := SettingsManager.get_run_modifier_presets()
	presets = _UserPresets.clear_active_modifier_slot(presets)
	SettingsManager.set_run_modifier_presets(presets)
	preset_host_clear_preset()
	_UiModifierSounds.play_deselect()
	return true


func _active_slot_from_settings() -> int:
	return int(SettingsManager.get_run_modifier_presets().get("active_slot", 0))


func _prompt_clear_preset_dirty() -> String:
	_back_prompt_active = true
	var choice := await _Overlay.choose(
		_choice_overlay,
		tr("MOD_PRESET_CLEAR_CONFIRM_DIRTY"),
		"warning",
		"",
		tr("MOD_PRESETS_CLEAR_ACTIVE"),
		tr("BTN_CANCEL"),
	)
	_back_prompt_active = false
	return choice


func _on_presets_dialog_closed(preset_loaded: bool = false) -> void:
	_presets_dialog = null
	_update_active_preset_header()
	if not preset_loaded:
		_UiModifierSounds.play_deselect()


func _bind_nav() -> void:
	_tabs = {
		TAB_OVERVIEW: _overview_tab,
		TAB_EASING: _easing_tab,
		TAB_HARDENING: _hardening_tab,
		TAB_SPECIAL: _special_tab,
		TAB_DNA: _dna_tab,
	}
	_nav_items = [_nav_overview, _nav_easing, _nav_hardening, _nav_special, _nav_dna]
	for nav in _nav_items:
		if nav:
			nav.tab_selected.connect(_select_tab)


func _build_tab_contents() -> void:
	if _overview_tab:
		_overview_tab.build_overview()
	_build_secondary_modifier_tabs()


func _build_secondary_modifier_tabs() -> void:
	if _secondary_tabs_built:
		return
	_secondary_tabs_built = true
	if _easing_tab:
		_easing_tab.build_sections(_Sections.ease_subsections(), 2)
	if _hardening_tab:
		_hardening_tab.build_sections(_Sections.hard_subsections(), 2)
	if _special_tab:
		_special_tab.build_sections(_Sections.special_subsections(), 2)
	if _dna_tab:
		_dna_tab.build_sections(_Sections.dna_subsections(), 2)


func _connect_card_signals(tab_node) -> void:
	if tab_node == null:
		return
	if tab_node.has_signal("card_toggled"):
		tab_node.card_toggled.connect(_on_card_toggled)
	if tab_node.has_signal("card_hovered"):
		tab_node.card_hovered.connect(_on_card_hovered)
	if tab_node.has_signal("card_unhovered"):
		tab_node.card_unhovered.connect(_on_card_unhovered)
	if tab_node.has_signal("card_info_requested"):
		tab_node.card_info_requested.connect(_on_card_info_requested)
	if tab_node.has_signal("card_dna_enable_blocked"):
		tab_node.card_dna_enable_blocked.connect(_on_card_dna_enable_blocked)


func _setup_right_panel_toggle() -> void:
	if _right_summary_btn == null or _right_detail_btn == null or _right_params_btn == null:
		return
	_right_panel_toggle_group = ButtonGroup.new()
	_right_summary_btn.toggle_mode = true
	_right_detail_btn.toggle_mode = true
	_right_params_btn.toggle_mode = true
	_right_summary_btn.button_group = _right_panel_toggle_group
	_right_detail_btn.button_group = _right_panel_toggle_group
	_right_params_btn.button_group = _right_panel_toggle_group
	_right_summary_btn.theme_type_variation = &"FlatButton"
	_right_detail_btn.theme_type_variation = &"FlatButton"
	_right_params_btn.theme_type_variation = &"FlatButton"
	_right_summary_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_detail_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_params_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_summary_btn.toggled.connect(_on_right_panel_summary_toggled)
	_right_detail_btn.toggled.connect(_on_right_panel_detail_toggled)
	_right_params_btn.toggled.connect(_on_right_panel_params_toggled)
	_right_summary_btn.set_pressed_no_signal(true)
	_right_panel_view = RIGHT_VIEW_SUMMARY


func _on_right_panel_summary_toggled(pressed: bool) -> void:
	if not pressed or _right_panel_view == RIGHT_VIEW_SUMMARY:
		return
	_right_panel_manual = true
	_UiModifierSounds.play_select()
	_set_right_panel_view(RIGHT_VIEW_SUMMARY)


func _on_right_panel_detail_toggled(pressed: bool) -> void:
	if not pressed or _right_panel_view == RIGHT_VIEW_DETAIL:
		return
	_right_panel_manual = true
	_UiModifierSounds.play_select()
	_set_right_panel_view(RIGHT_VIEW_DETAIL)


func _on_right_panel_params_toggled(pressed: bool) -> void:
	if not pressed or _right_panel_view == RIGHT_VIEW_PARAMS:
		return
	if _right_params_btn and _right_params_btn.disabled:
		_right_params_btn.set_pressed_no_signal(false)
		return
	_right_panel_manual = true
	_UiModifierSounds.play_select()
	_set_right_panel_view(RIGHT_VIEW_PARAMS)


func _set_right_panel_view(view: String, refresh: bool = true) -> void:
	var changed := _right_panel_view != view
	_right_panel_view = view
	if _right_summary_btn and _right_detail_btn and _right_params_btn:
		_right_summary_btn.set_pressed_no_signal(view == RIGHT_VIEW_SUMMARY)
		_right_detail_btn.set_pressed_no_signal(view == RIGHT_VIEW_DETAIL)
		_right_params_btn.set_pressed_no_signal(view == RIGHT_VIEW_PARAMS)
	if refresh or changed:
		_update_right_panel_mode()


func _select_tab(tab_id: String, play_sound: bool = true) -> void:
	var prev_tab := _current_tab_id
	_current_tab_id = tab_id
	_clear_keyboard_mod_focus()
	for nav in _nav_items:
		if nav:
			nav.set_selected(nav.tab_id == tab_id)
	for id in _tabs.keys():
		var node = _tabs[id]
		if node:
			node.visible = id == tab_id
	_update_page_title()
	if not _right_panel_manual:
		if tab_id == TAB_OVERVIEW:
			_set_right_panel_view(RIGHT_VIEW_SUMMARY, false)
		else:
			_set_right_panel_view(RIGHT_VIEW_DETAIL, false)
	_update_right_panel_mode()
	_refresh_ui()
	if play_sound and prev_tab != tab_id:
		MusicManager.play_modifier_select_sound()


func _update_page_title() -> void:
	if _page_title_label == null:
		return
	match _current_tab_id:
		TAB_OVERVIEW:
			_page_title_label.text = tr("MOD_TAB_OVERVIEW")
		TAB_EASING:
			_page_title_label.text = tr("MOD_CAT_EASING")
		TAB_HARDENING:
			_page_title_label.text = tr("MOD_CAT_HARDENING")
		TAB_SPECIAL:
			_page_title_label.text = tr("MOD_CAT_SPECIAL")
		TAB_DNA:
			_page_title_label.text = _dna_tab_title()
		_:
			_page_title_label.text = tr("MOD_POPUP_TITLE")


func _update_right_panel_mode() -> void:
	var preview_id := _preview_source_id()
	var has_params := (
		preview_id != "" and _RunModifiers.modifier_has_detail_params(preview_id)
	)
	if _right_params_btn:
		_right_params_btn.disabled = not has_params
	if _right_panel_view == RIGHT_VIEW_PARAMS and not has_params:
		_right_panel_view = RIGHT_VIEW_DETAIL
		if _right_detail_btn:
			_right_detail_btn.set_pressed_no_signal(true)
		if _right_params_btn:
			_right_params_btn.set_pressed_no_signal(false)

	var show_summary := _right_panel_view == RIGHT_VIEW_SUMMARY
	var show_detail := _right_panel_view == RIGHT_VIEW_DETAIL
	var show_params := _right_panel_view == RIGHT_VIEW_PARAMS
	var full_summary := show_summary and _current_tab_id == TAB_OVERVIEW
	if _summary_panel:
		_summary_panel.visible = true
		_summary_panel.set_compact_mode(not full_summary if show_summary else true, not show_summary)
	if _detail_panel:
		_detail_panel.visible = show_detail
		_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL if show_detail else Control.SIZE_SHRINK_CENTER
		if show_detail:
			if preview_id != "":
				_detail_panel.show_modifier(
					preview_id,
					get_active_modifiers(),
					_run_params,
					_is_dna_gated(preview_id)
				)
			else:
				_detail_panel.clear()
	if _params_panel:
		_params_panel.visible = show_params
		_params_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL if show_params else Control.SIZE_SHRINK_CENTER
		if show_params:
			if has_params:
				_params_panel.show_modifier(preview_id, get_active_modifiers(), _run_params)
			else:
				_params_panel.clear()


func _should_show_full_active_list() -> bool:
	return _right_panel_view == RIGHT_VIEW_SUMMARY and _current_tab_id == TAB_OVERVIEW


func _apply_pending_modifier_state(refresh_ui: bool = true) -> void:
	for spec in (
		_Sections.all_ease_specs()
		+ _Sections.all_hard_specs()
		+ _Sections.all_special_specs()
		+ _Sections.all_dna_specs()
	):
		var id := str(spec[0])
		_set_modifier_active_everywhere(id, _pending_active_modifiers.has(id))
	if refresh_ui:
		_refresh_ui()


func _set_modifier_active_everywhere(modifier_id: String, active: bool) -> void:
	for tab_id in [TAB_OVERVIEW, TAB_EASING, TAB_HARDENING, TAB_SPECIAL, TAB_DNA]:
		var tab = _tabs.get(tab_id, null)
		if tab and tab.has_method("set_modifier_active"):
			tab.set_modifier_active(modifier_id, active)


func _is_modifier_active(modifier_id: String) -> bool:
	return _pending_active_modifiers.has(modifier_id)


func _on_card_toggled(modifier_id: String, pressed: bool) -> void:
	if _is_dna_gated(modifier_id):
		_open_modifier_preview(modifier_id, _card_click_panel_view())
		return
	var card: Control = _get_card(modifier_id)
	if card != null and card.disabled:
		_apply_pending_modifier_state()
		return
	var open_view := _card_click_panel_view()
	if not pressed and _pending_active_modifiers.has(modifier_id):
		var already_open := _panel_lock_id == modifier_id and _panel_lock_mode == "summary"
		if not already_open:
			_focused_modifier_id = modifier_id
			_panel_lock_id = modifier_id
			_panel_lock_mode = "summary"
			_set_modifier_active_everywhere(modifier_id, true)
			_right_panel_manual = true
			_set_right_panel_view(open_view)
			_refresh_ui()
			MusicManager.play_modifier_select_sound()
			return
	_focused_modifier_id = modifier_id
	_panel_lock_id = modifier_id
	_panel_lock_mode = "summary"
	if pressed:
		_pending_active_modifiers = _RunModifiers.enable_modifier(_pending_active_modifiers, modifier_id)
		_apply_modifier_param_links(modifier_id, true)
	else:
		_pending_active_modifiers = _RunModifiers.disable_modifier(_pending_active_modifiers, modifier_id)
		_clear_modifier_param_links(modifier_id)
	_apply_pending_modifier_state(false)
	_right_panel_manual = true
	_set_right_panel_view(open_view)
	_refresh_ui()
	modifiers_changed.emit(get_active_modifiers())
	if pressed:
		MusicManager.play_modifier_select_sound()
	else:
		MusicManager.play_modifier_deselect_sound()


func _on_card_info_requested(modifier_id: String) -> void:
	if modifier_id == "":
		return
	_open_modifier_preview(modifier_id, RIGHT_VIEW_DETAIL)


func _on_card_dna_enable_blocked(modifier_id: String) -> void:
	if modifier_id == "":
		return
	MusicManager.play_analysis_error()
	_open_modifier_preview(modifier_id, _card_click_panel_view())


func _open_modifier_preview(modifier_id: String, view: String) -> void:
	_focused_modifier_id = modifier_id
	_panel_lock_id = modifier_id
	_panel_lock_mode = "detail" if view == RIGHT_VIEW_DETAIL else "summary"
	_right_panel_manual = true
	_set_right_panel_view(view)
	_refresh_ui()


func _on_card_hovered(_modifier_id: String) -> void:
	pass


func _on_card_unhovered(_modifier_id: String) -> void:
	pass


func _card_click_panel_view() -> String:
	return RIGHT_VIEW_SUMMARY if _current_tab_id == TAB_OVERVIEW else RIGHT_VIEW_DETAIL


func _preview_source_id() -> String:
	if _panel_lock_id != "":
		return _panel_lock_id
	return _focused_modifier_id


func _get_card(modifier_id: String) -> Control:
	for tab_id in [TAB_OVERVIEW, TAB_EASING, TAB_HARDENING, TAB_SPECIAL, TAB_DNA]:
		var tab = _tabs.get(tab_id, null)
		if tab and tab.has_method("get_card"):
			var card: Variant = tab.get_card(modifier_id)
			if card is Control:
				return card as Control
	return null


func _on_param_changed(param_id: String, value: Variant) -> void:
	match param_id:
		"slow_75_speed_pct":
			_run_params["slow_75_speed_pct"] = float(value)
		"fast_150_speed_pct":
			_run_params["fast_150_speed_pct"] = float(value)
		"scroll_speed_value":
			_run_params["scroll_speed_value"] = float(value)
			_run_params["scroll_speed_mode"] = "fixed"
		"combo_escalation_pick_mode":
			_run_params["combo_escalation_pick_mode"] = str(value)
		"combo_escalation_order":
			_run_params["combo_escalation_order"] = value
		"combo_escalation_pool_enabled":
			_run_params["combo_escalation_pool_enabled"] = value
		_:
			if param_id in _RunModifiers.default_params():
				_run_params[param_id] = value
	_run_params = _RunModifiers.sanitize_params(_run_params)
	_sync_detail_params()
	_refresh_ui()
	modifiers_changed.emit(get_active_modifiers())


func _resolve_conflicts(mod_id: String) -> void:
	if mod_id == _RunModifiers.ID_COMBO_ESCALATION:
		_deactivate_all_hardening()
		_deactivate_all_easing()
	elif mod_id in _RunModifiers.HARDENING_IDS or mod_id in _RunModifiers.EASING_IDS:
		_deactivate_modifier(_RunModifiers.ID_COMBO_ESCALATION)
	if mod_id == _RunModifiers.ID_EASY_WINDOWS:
		_deactivate_modifier(_RunModifiers.ID_STRICT_TIMING)
	elif mod_id == _RunModifiers.ID_STRICT_TIMING:
		_deactivate_modifier(_RunModifiers.ID_EASY_WINDOWS)
	elif mod_id == _RunModifiers.ID_NO_FAIL:
		_deactivate_modifier(_RunModifiers.ID_SUDDEN_DEATH)
	elif mod_id == _RunModifiers.ID_SUDDEN_DEATH:
		_deactivate_modifier(_RunModifiers.ID_NO_FAIL)
	elif mod_id == _RunModifiers.ID_HIDDEN:
		_deactivate_modifier(_RunModifiers.ID_SUDDEN)
		_deactivate_modifier(_RunModifiers.ID_MEMORY_MODE)
		_deactivate_modifier(_RunModifiers.ID_SPOTLIGHT)
		_deactivate_modifier(_RunModifiers.ID_DENSITY_FOCUS)
		_deactivate_dna_behavior_modifiers()
	elif mod_id == _RunModifiers.ID_SUDDEN:
		_deactivate_modifier(_RunModifiers.ID_HIDDEN)
		_deactivate_modifier(_RunModifiers.ID_MEMORY_MODE)
		_deactivate_modifier(_RunModifiers.ID_SPOTLIGHT)
		_deactivate_modifier(_RunModifiers.ID_DENSITY_FOCUS)
		_deactivate_dna_behavior_modifiers()
	elif mod_id == _RunModifiers.ID_MEMORY_MODE:
		_deactivate_modifier(_RunModifiers.ID_HIDDEN)
		_deactivate_modifier(_RunModifiers.ID_SUDDEN)
		_deactivate_modifier(_RunModifiers.ID_SPOTLIGHT)
		_deactivate_modifier(_RunModifiers.ID_DENSITY_FOCUS)
		_deactivate_dna_behavior_modifiers()
	elif mod_id == _RunModifiers.ID_SPOTLIGHT:
		_deactivate_modifier(_RunModifiers.ID_HIDDEN)
		_deactivate_modifier(_RunModifiers.ID_SUDDEN)
		_deactivate_modifier(_RunModifiers.ID_MEMORY_MODE)
		_deactivate_modifier(_RunModifiers.ID_DENSITY_FOCUS)
		_deactivate_dna_behavior_modifiers()
	elif mod_id == _RunModifiers.ID_SILENCE:
		_deactivate_modifier(_RunModifiers.ID_METRONOME_ONLY)
	elif mod_id == _RunModifiers.ID_METRONOME_ONLY:
		_deactivate_modifier(_RunModifiers.ID_SILENCE)
	elif mod_id == _RunModifiers.ID_DYNAMIC_LANES:
		_deactivate_modifier(_RunModifiers.ID_SINGLE_LANE)
		_deactivate_remap_modifiers("")
	elif mod_id == _RunModifiers.ID_SINGLE_LANE:
		_deactivate_modifier(_RunModifiers.ID_DYNAMIC_LANES)
		_deactivate_remap_modifiers("")
	elif mod_id in _RunModifiers.REMAP_IDS:
		_deactivate_remap_modifiers(mod_id)
		_deactivate_modifier(_RunModifiers.ID_SINGLE_LANE)
		_deactivate_modifier(_RunModifiers.ID_DYNAMIC_LANES)
	elif mod_id == _RunModifiers.ID_SLOW_75:
		_deactivate_modifier(_RunModifiers.ID_FAST_150)
		_deactivate_modifier(_RunModifiers.ID_HEAT)
		_deactivate_modifier(_RunModifiers.ID_ENERGY_PULSE)
	elif mod_id == _RunModifiers.ID_FAST_150:
		_deactivate_modifier(_RunModifiers.ID_SLOW_75)
		_deactivate_modifier(_RunModifiers.ID_HEAT)
		_deactivate_modifier(_RunModifiers.ID_ENERGY_PULSE)
	elif mod_id == _RunModifiers.ID_HEAT:
		_deactivate_modifier(_RunModifiers.ID_SLOW_75)
		_deactivate_modifier(_RunModifiers.ID_FAST_150)
		_deactivate_dna_behavior_modifiers()
	elif mod_id == _RunModifiers.ID_REVERSE_SCROLL:
		_deactivate_modifier(_RunModifiers.ID_PHRASE_SHIFT)
		_deactivate_modifier(_RunModifiers.ID_ADAPTIVE)
	elif mod_id == _RunModifiers.ID_STRICT_TIMING:
		_deactivate_modifier(_RunModifiers.ID_GROOVE_LOCK)
		_deactivate_modifier(_RunModifiers.ID_ADAPTIVE)
	elif mod_id == _RunModifiers.ID_TIME_WARP:
		_deactivate_modifier(_RunModifiers.ID_ENERGY_PULSE)
		_deactivate_modifier(_RunModifiers.ID_ADAPTIVE)
	elif mod_id == _RunModifiers.ID_ENERGY_PULSE:
		_deactivate_modifier(_RunModifiers.ID_TIME_WARP)
		_deactivate_modifier(_RunModifiers.ID_SLOW_75)
		_deactivate_modifier(_RunModifiers.ID_FAST_150)
		_deactivate_modifier(_RunModifiers.ID_ADAPTIVE)
	elif mod_id == _RunModifiers.ID_DENSITY_FOCUS:
		_deactivate_modifier(_RunModifiers.ID_HIDDEN)
		_deactivate_modifier(_RunModifiers.ID_SUDDEN)
		_deactivate_modifier(_RunModifiers.ID_MEMORY_MODE)
		_deactivate_modifier(_RunModifiers.ID_SPOTLIGHT)
	elif mod_id == _RunModifiers.ID_PHRASE_SHIFT:
		_deactivate_dna_behavior_modifiers(mod_id)
		_deactivate_modifier(_RunModifiers.ID_REVERSE_SCROLL)
		_deactivate_modifier(_RunModifiers.ID_HEAT)
		_deactivate_modifier(_RunModifiers.ID_DENSITY_FOCUS)
		_deactivate_visibility_modifiers()
	elif mod_id == _RunModifiers.ID_GROOVE_LOCK:
		_deactivate_dna_behavior_modifiers(mod_id)
		_deactivate_modifier(_RunModifiers.ID_STRICT_TIMING)
		_deactivate_modifier(_RunModifiers.ID_HEAT)
		_deactivate_modifier(_RunModifiers.ID_DENSITY_FOCUS)
		_deactivate_visibility_modifiers()
	elif mod_id == _RunModifiers.ID_ADAPTIVE:
		_deactivate_dna_behavior_modifiers(mod_id)
		_deactivate_modifier(_RunModifiers.ID_TIME_WARP)
		_deactivate_modifier(_RunModifiers.ID_ENERGY_PULSE)
		_deactivate_modifier(_RunModifiers.ID_SLOW_75)
		_deactivate_modifier(_RunModifiers.ID_FAST_150)
		_deactivate_modifier(_RunModifiers.ID_REVERSE_SCROLL)
		_deactivate_modifier(_RunModifiers.ID_HEAT)
		_deactivate_modifier(_RunModifiers.ID_STRICT_TIMING)
		_deactivate_modifier(_RunModifiers.ID_DENSITY_FOCUS)
		_deactivate_visibility_modifiers()


func _deactivate_visibility_modifiers() -> void:
	_deactivate_modifier(_RunModifiers.ID_HIDDEN)
	_deactivate_modifier(_RunModifiers.ID_SUDDEN)
	_deactivate_modifier(_RunModifiers.ID_MEMORY_MODE)
	_deactivate_modifier(_RunModifiers.ID_SPOTLIGHT)


func _deactivate_dna_behavior_modifiers(keep_id: String = "") -> void:
	for behavior_id in _RunModifiers.DNA_BEHAVIOR_IDS:
		if behavior_id != keep_id:
			_deactivate_modifier(behavior_id)


func _apply_modifier_param_links(mod_id: String, _pressed: bool) -> void:
	match mod_id:
		_RunModifiers.ID_SLOW_75:
			_deactivate_modifier(_RunModifiers.ID_FAST_150)
		_RunModifiers.ID_FAST_150:
			_deactivate_modifier(_RunModifiers.ID_SLOW_75)
		_RunModifiers.ID_HEAT:
			_deactivate_modifier(_RunModifiers.ID_FAST_150)
			_deactivate_modifier(_RunModifiers.ID_SLOW_75)
		_RunModifiers.ID_FIXED_SPEED_20:
			_run_params["scroll_speed_mode"] = "fixed"
			if not _run_params.has("scroll_speed_value"):
				_run_params["scroll_speed_value"] = _RunModifiers.FIXED_SCROLL_SPEED
			_sync_detail_params()


func _clear_modifier_param_links(mod_id: String) -> void:
	if mod_id == _RunModifiers.ID_FIXED_SPEED_20:
		if str(_run_params.get("scroll_speed_mode", "settings")) == "fixed":
			_run_params["scroll_speed_mode"] = "settings"
			_sync_detail_params()


func _load_run_params() -> void:
	_run_params = _RunModifiers.sanitize_params(SettingsManager.get_run_modifier_params())
	_run_params = _RunModifiers.sync_params_from_modifiers(_pending_active_modifiers, _run_params)
	if _committed_params.is_empty():
		_committed_params = _run_params.duplicate()


func _sync_detail_params() -> void:
	_run_params = _RunModifiers.sanitize_params(_run_params)
	if _detail_panel and _detail_panel.has_method("apply_params"):
		_detail_panel.apply_params(_run_params)
	if _params_panel and _params_panel.has_method("apply_params"):
		_params_panel.apply_params(_run_params)


func _refresh_single_lane_visibility() -> void:
	var show_sl := _playfield_lanes > 1
	for tab_id in [TAB_OVERVIEW, TAB_SPECIAL]:
		var tab = _tabs.get(tab_id, null)
		if tab and tab.has_method("set_card_visible"):
			tab.set_card_visible(_RunModifiers.ID_SINGLE_LANE, show_sl)


func _dynamic_lanes_available() -> bool:
	if _song_path == "":
		return false
	return _DynamicLanesSchedule.has_usable_dna(
		_song_path, _song_instrument, _song_mode, _playfield_lanes
	)


func _refresh_dna_gated_modifiers() -> void:
	var available := _dynamic_lanes_available()
	var tooltip := "" if available else tr("MOD_DNA_REQUIRED")
	for dna_id in _RunModifiers.DNA_IDS:
		for tab_id in [TAB_OVERVIEW, TAB_SPECIAL, TAB_DNA]:
			var tab = _tabs.get(tab_id, null)
			if tab == null:
				continue
			if tab.has_method("set_card_dna_gated"):
				tab.set_card_dna_gated(dna_id, not available, tooltip)
			elif tab.has_method("set_card_disabled"):
				tab.set_card_disabled(dna_id, not available, tooltip)
		if not available and _is_modifier_active(dna_id):
			_deactivate_modifier(dna_id)


func _is_dna_gated(modifier_id: String) -> bool:
	return modifier_id in _RunModifiers.DNA_IDS and not _dynamic_lanes_available()


func _refresh_dynamic_lanes_availability() -> void:
	_refresh_dna_gated_modifiers()


func _deactivate_remap_modifiers(keep_id: String = "") -> void:
	for rid in _RunModifiers.REMAP_IDS:
		if rid != keep_id:
			_deactivate_modifier(rid)


func _deactivate_all_hardening() -> void:
	for hid in _RunModifiers.HARDENING_IDS:
		_deactivate_modifier(hid)


func _deactivate_all_easing() -> void:
	for eid in _RunModifiers.EASING_IDS:
		_deactivate_modifier(eid)


func _deactivate_modifier(modifier_id: String) -> void:
	_pending_active_modifiers = _RunModifiers.disable_modifier(_pending_active_modifiers, modifier_id)
	_set_modifier_active_everywhere(modifier_id, false)


func _refresh_ui() -> void:
	_update_right_panel_mode()
	var mods := get_active_modifiers()
	_sync_detail_params()
	var mult := _RunModifiers.reward_multiplier(mods, _run_params)
	var ease_count := _count_active_in_specs(_Sections.all_ease_specs())
	var hard_count := _count_active_in_specs(_Sections.all_hard_specs())
	var special_count := _count_active_in_specs(_Sections.all_special_specs())
	var dna_count := _count_active_in_specs(_Sections.all_dna_specs())
	if _summary_panel:
		_summary_panel.set_summary(
			mult,
			mods,
			ease_count,
			hard_count,
			special_count,
			dna_count
		)
		if _should_show_full_active_list():
			_summary_panel.show_full_active_list(mods)
	_update_nav_badges()
	_update_conflicts_footer(mods)
	if _detail_panel and _detail_panel.visible:
		var preview_id := _preview_source_id()
		if preview_id != "":
			_detail_panel.show_modifier(
				preview_id,
				mods,
				_run_params,
				_is_dna_gated(preview_id)
			)
		else:
			_detail_panel.clear()
	if _params_panel and _params_panel.visible:
		var params_preview_id := _preview_source_id()
		if params_preview_id != "":
			_params_panel.show_modifier(params_preview_id, mods, _run_params)
		else:
			_params_panel.clear()
	_update_card_preview_ui()
	_update_active_preset_header()


func _refresh_card_params() -> void:
	for tab_id in [TAB_OVERVIEW, TAB_EASING, TAB_HARDENING, TAB_SPECIAL, TAB_DNA]:
		var tab = _tabs.get(tab_id, null)
		if tab and tab.has_method("refresh_card_params"):
			tab.refresh_card_params(_run_params)


func _setup_footer_callouts() -> void:
	if _conflicts_callout_slot:
		for child in _conflicts_callout_slot.get_children():
			child.queue_free()
		_conflicts_callout = HELP_CALLOUT_SCENE.instantiate() as HelpCallout
		_conflicts_callout_slot.add_child(_conflicts_callout)
	if _hint_callout_slot:
		for child in _hint_callout_slot.get_children():
			child.queue_free()
		_hint_callout = HELP_CALLOUT_SCENE.instantiate() as HelpCallout
		_hint_callout_slot.add_child(_hint_callout)
	_ensure_dna_help_icon()
	call_deferred("_refresh_footer_callouts")


func _ensure_dna_help_icon() -> void:
	if _dna_help_link != null and is_instance_valid(_dna_help_link):
		return
	if _page_title_label == null:
		return
	var parent := _page_title_label.get_parent()
	if parent == null:
		return
	_dna_help_link = _SettingsSectionUi.make_help_icon_button(tr("HELP_LINK_RHYTHM_DNA"))
	_dna_help_link.pressed.connect(_on_dna_help_link_pressed)
	_dna_help_link.visible = false
	if parent is BoxContainer and not (parent as BoxContainer).vertical:
		parent.add_child(_dna_help_link)
		parent.move_child(_dna_help_link, _page_title_label.get_index() + 1)
		_page_title_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		return
	# Wrap title + (?) in a horizontal row once.
	var row := HBoxContainer.new()
	row.name = "PageTitleRow"
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var idx := _page_title_label.get_index()
	parent.add_child(row)
	parent.move_child(row, idx)
	parent.remove_child(_page_title_label)
	row.add_child(_page_title_label)
	_page_title_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_page_title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_dna_help_link)


func _refresh_footer_callouts() -> void:
	if _conflicts_callout:
		_conflicts_callout.setup(
			"warning",
			tr("MOD_CONFLICTS_FOOTER_HINT"),
			true,
			tr("MOD_CONFLICTS_CAPTION")
		)
	if _hint_callout:
		if _current_tab_id == TAB_DNA:
			_hint_callout.setup(
				"warning",
				_dna_beta_callout_body(),
				true,
				_dna_beta_callout_caption(),
			)
		else:
			_hint_callout.setup("tip", tr("MOD_SUMMARY_TIP"), true, tr("MOD_HINT_CAPTION"))
	if _dna_help_link:
		_dna_help_link.tooltip_text = tr("HELP_LINK_RHYTHM_DNA")
		_dna_help_link.visible = _current_tab_id == TAB_DNA


func _on_dna_help_link_pressed() -> void:
	_open_help_item("rhythm_dna_overview")


func _open_help_item(item_id: String) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var parent := get_parent()
	while parent:
		if parent.has_method("get_transitions"):
			var trans = parent.get_transitions()
			if trans and trans.has_method("open_help_item"):
				trans.open_help_item(item_id)
				return
		if parent.has_method("open_help_item"):
			parent.open_help_item(item_id)
			return
		parent = parent.get_parent()
	for child in tree.root.get_children():
		if child.has_method("get_transitions"):
			var root_trans = child.get_transitions()
			if root_trans and root_trans.has_method("open_help_item"):
				root_trans.open_help_item(item_id)
				return


func _update_card_preview_ui() -> void:
	var info_lock_id := _panel_lock_id if _panel_lock_mode == "detail" else ""
	var active_conflicts: Array[String] = _RunModifiers.ui_conflict_highlight_ids(_pending_active_modifiers)
	for tab_id in [TAB_OVERVIEW, TAB_EASING, TAB_HARDENING, TAB_SPECIAL, TAB_DNA]:
		var tab = _tabs.get(tab_id, null)
		if tab == null:
			continue
		if tab.has_method("set_card_info_locked"):
			tab.set_card_info_locked(info_lock_id)
		if tab.has_method("set_conflict_previews"):
			tab.set_conflict_previews(active_conflicts)
	_apply_keyboard_preview_focus()
	_refresh_card_params()


func _update_nav_badges() -> void:
	var ease_count := _count_active_in_specs(_Sections.all_ease_specs())
	var hard_count := _count_active_in_specs(_Sections.all_hard_specs())
	var special_count := _count_active_in_specs(_Sections.all_special_specs())
	var dna_count := _count_active_in_specs(_Sections.all_dna_specs())
	if _nav_easing:
		_nav_easing.set_active_count(ease_count)
	if _nav_hardening:
		_nav_hardening.set_active_count(hard_count)
	if _nav_special:
		_nav_special.set_active_count(special_count)
	if _nav_dna:
		_nav_dna.set_active_count(dna_count)
	if _nav_overview:
		_nav_overview.set_active_count(ease_count + hard_count + special_count + dna_count)


func _count_active_in_specs(specs: Array) -> int:
	var n := 0
	for spec in specs:
		if _is_modifier_active(str(spec[0])):
			n += 1
	return n


func _update_conflicts_footer(_mods: Array) -> void:
	_refresh_footer_callouts()


func _commit_changes() -> Array:
	var mods := get_active_modifiers()
	_pending_active_modifiers = mods
	_sync_detail_params()
	_committed_modifiers = mods
	_committed_params = _RunModifiers.sanitize_params(_run_params).duplicate()
	SettingsManager.set_run_modifier_params(_run_params)
	SettingsManager.set_run_modifiers(mods)
	SettingsManager.sync_active_run_modifier_preset(mods, _run_params)
	modifiers_changed.emit(mods.duplicate())
	return mods


func _on_confirm_pressed() -> void:
	_commit_changes()
	_close()


# Сохранение изменений «на месте» (по пробелу), как в настройках: применяем моды
# и показываем уведомление, не закрывая экран.
func _save_changes_in_place() -> void:
	if not _is_dirty():
		return
	_commit_changes()
	_update_active_preset_header()
	_notify(tr("MOD_TOAST_APPLIED"))


func _on_reset_pressed() -> void:
	_pending_active_modifiers = []
	for spec in (
		_Sections.all_ease_specs()
		+ _Sections.all_hard_specs()
		+ _Sections.all_special_specs()
		+ _Sections.all_dna_specs()
	):
		_set_modifier_active_everywhere(str(spec[0]), false)
	_run_params = _RunModifiers.default_params()
	_sync_detail_params()
	var mods := get_active_modifiers()
	modifiers_changed.emit(mods.duplicate())
	_refresh_ui()
	MusicManager.play_modifier_deselect_sound()


func _on_back_pressed() -> void:
	if _back_prompt_active:
		return
	# Выбор модов/пресета уже подразумевает сохранение — при выходе просто
	# применяем изменения без вопроса «сохранить?».
	if _is_dirty():
		_commit_changes()
		_notify(tr("MOD_TOAST_APPLIED"))
	_close()


func _revert_pending() -> void:
	_pending_active_modifiers = _committed_modifiers.duplicate()
	_run_params = _committed_params.duplicate()
	_apply_pending_modifier_state(false)
	_sync_detail_params()
	SettingsManager.sync_active_run_modifier_preset(_committed_modifiers, _committed_params)
	modifiers_changed.emit(_committed_modifiers.duplicate())
	_refresh_ui()


func _is_dirty() -> bool:
	var saved := {
		"modifiers": _committed_modifiers,
		"params": _committed_params,
	}
	return not _UserPresets.modifier_states_equal(saved, get_draft_snapshot())


func _on_reset_params_pressed() -> void:
	_run_params = _RunModifiers.default_params()
	_sync_detail_params()
	if _focused_modifier_id != "" and _detail_panel:
		_detail_panel.show_modifier(
			_focused_modifier_id,
			get_active_modifiers(),
			_run_params,
			_is_dna_gated(_focused_modifier_id)
		)
	if _params_panel and _right_panel_view == RIGHT_VIEW_PARAMS and _focused_modifier_id != "":
		_params_panel.show_modifier(_focused_modifier_id, get_active_modifiers(), _run_params)
	_refresh_ui()


func has_unsaved_changes() -> bool:
	return _is_dirty()


func _close() -> void:
	screen_closed.emit()
	queue_free()


func _notify(text: String, kind: String = "success") -> void:
	_StatusToast.show_from_node(self, "run_modifiers", text, kind)


func _is_text_input_focused() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit or focus is CodeEdit


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if _is_choice_overlay_blocking_input():
		return
	if _presets_dialog != null and is_instance_valid(_presets_dialog):
		return
	if event is InputEventMouseButton and event.pressed:
		_clear_keyboard_mod_focus()
	if event is InputEventKey and event.pressed and not event.echo:
		# Пробел — сохранить изменения на месте (как в настройках).
		if event.keycode == KEY_SPACE and not _is_text_input_focused():
			_save_changes_in_place()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _is_choice_overlay_blocking_input():
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey) or not event.pressed:
		return
	var key_event := event as InputEventKey
	var is_card_nav := key_event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]
	if key_event.echo and not is_card_nav:
		return
	if key_event.keycode == KEY_ESCAPE:
		accept_event()
		_on_back_pressed()
		return
	if _is_text_input_focused():
		return
	if is_card_nav:
		var delta := 0
		match key_event.keycode:
			KEY_LEFT, KEY_UP:
				delta = -1
			KEY_RIGHT, KEY_DOWN:
				delta = 1
		_move_keyboard_mod_focus(delta)
		accept_event()
		return
	if key_event.echo:
		return
	if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
		accept_event()
		if _keyboard_nav_active and _kb_focus_mod_id != "":
			_activate_keyboard_focused_modifier()
		else:
			_on_confirm_pressed()
	elif key_event.keycode >= KEY_1 and key_event.keycode <= KEY_5:
		accept_event()
		var index := int(key_event.keycode - KEY_1)
		if index < _nav_items.size() and _nav_items[index]:
			_select_tab(_nav_items[index].tab_id)


func _ordered_visible_mod_ids() -> Array[String]:
	var tab = _tabs.get(_current_tab_id, null)
	if tab and tab.has_method("get_ordered_visible_modifier_ids"):
		return tab.get_ordered_visible_modifier_ids()
	return []


func _move_keyboard_mod_focus(delta: int) -> void:
	var ids := _ordered_visible_mod_ids()
	if ids.is_empty():
		return
	var prev_id := _kb_focus_mod_id
	_keyboard_nav_active = true
	var idx := ids.find(_kb_focus_mod_id)
	if idx < 0:
		idx = 0 if delta > 0 else ids.size() - 1
	else:
		idx = clampi(idx + delta, 0, ids.size() - 1)
	_kb_focus_mod_id = ids[idx]
	_focused_modifier_id = _kb_focus_mod_id
	if _kb_focus_mod_id != prev_id:
		UiScreenHotkeys.play_section_switch_sound()
	_apply_keyboard_preview_focus()
	_ensure_modifier_card_visible(_kb_focus_mod_id)


func _activate_keyboard_focused_modifier() -> void:
	var mod_id := _kb_focus_mod_id
	if mod_id == "":
		return
	if _is_dna_gated(mod_id):
		_open_modifier_preview(mod_id, _card_click_panel_view())
		return
	var new_pressed := not _is_modifier_active(mod_id)
	var card: Control = _get_card(mod_id)
	if card and card.has_method("set_modifier_active"):
		card.set_modifier_active(new_pressed)
	_on_card_toggled(mod_id, new_pressed)


func _clear_keyboard_mod_focus() -> void:
	if not _keyboard_nav_active and _kb_focus_mod_id == "":
		return
	_keyboard_nav_active = false
	_kb_focus_mod_id = ""
	_apply_keyboard_preview_focus()


func _apply_keyboard_preview_focus() -> void:
	var focus_id := _kb_focus_mod_id if _keyboard_nav_active else ""
	for tab_id in [TAB_OVERVIEW, TAB_EASING, TAB_HARDENING, TAB_SPECIAL, TAB_DNA]:
		var tab = _tabs.get(tab_id, null)
		if tab == null or not tab.has_method("set_card_preview_focus"):
			continue
		if tab_id == _current_tab_id:
			tab.set_card_preview_focus(focus_id)
		else:
			tab.set_card_preview_focus("")


func _ensure_modifier_card_visible(mod_id: String) -> void:
	var card: Control = _get_card(mod_id) as Control
	if card == null:
		return
	var node: Node = card
	while node:
		if node is ScrollContainer:
			(node as ScrollContainer).ensure_control_visible(card)
			return
		node = node.get_parent()


func _is_choice_overlay_blocking_input() -> bool:
	return _back_prompt_active or (_choice_overlay != null and _choice_overlay.visible)


func _maybe_show_modifiers_tutorial(force: bool = false) -> void:
	if not SettingsManager or not SettingsManager.has_method("get_tutorial_modifiers_done"):
		return
	if not force and SettingsManager.get_tutorial_modifiers_done():
		return
	if _spotlight_tutorial == null:
		_spotlight_tutorial = _SpotlightTutorialScene.instantiate() as CanvasLayer
		if _spotlight_tutorial == null:
			return
		add_child(_spotlight_tutorial)
		if not _spotlight_tutorial.finished.is_connected(_on_modifiers_tutorial_closed):
			_spotlight_tutorial.finished.connect(_on_modifiers_tutorial_closed)
		if not _spotlight_tutorial.skipped.is_connected(_on_modifiers_tutorial_closed):
			_spotlight_tutorial.skipped.connect(_on_modifiers_tutorial_closed)
		if not _spotlight_tutorial.step_shown.is_connected(_on_modifiers_tutorial_step_shown):
			_spotlight_tutorial.step_shown.connect(_on_modifiers_tutorial_step_shown)
	var confirm_btn: Control = null
	if _summary_panel:
		confirm_btn = _summary_panel.get_node_or_null("ConfirmButton") as Control
	var steps: Array = [
		{
			"title_key": "TUTORIAL_MODS_1_TITLE",
			"body_key": "TUTORIAL_MODS_1_BODY",
			"target": _sidebar_card,
		},
		{
			"title_key": "TUTORIAL_MODS_2_TITLE",
			"body_key": "TUTORIAL_MODS_2_BODY",
			"target": _center_card,
		},
		{
			"title_key": "TUTORIAL_MODS_3_TITLE",
			"body_key": "TUTORIAL_MODS_3_BODY",
			"target": _tutorial_gear_target(),
		},
		{
			"title_key": "TUTORIAL_MODS_4_TITLE",
			"body_key": "TUTORIAL_MODS_4_BODY",
			"target": _params_panel,
		},
		{
			"title_key": "TUTORIAL_MODS_5_TITLE",
			"body_key": "TUTORIAL_MODS_5_BODY",
			"target": confirm_btn,
		},
	]
	if _spotlight_tutorial.has_method("start"):
		_spotlight_tutorial.start(steps)


func _on_modifiers_tutorial_step_shown(step_index: int) -> void:
	if step_index < 2:
		return
	_prepare_tutorial_params_demo(step_index >= 3)


func _prepare_tutorial_params_demo(open_params: bool) -> void:
	_select_tab(TAB_OVERVIEW, false)
	_focused_modifier_id = _TUTORIAL_PARAMS_DEMO_MOD
	_panel_lock_id = _TUTORIAL_PARAMS_DEMO_MOD
	_panel_lock_mode = "detail"
	if _overview_tab:
		_overview_tab.set_card_preview_focus(_TUTORIAL_PARAMS_DEMO_MOD)
		_overview_tab.set_card_info_locked(_TUTORIAL_PARAMS_DEMO_MOD)
	_right_panel_manual = true
	_set_right_panel_view(RIGHT_VIEW_PARAMS if open_params else RIGHT_VIEW_DETAIL)
	_refresh_ui()


func _tutorial_gear_target() -> Control:
	var card := _get_card(_TUTORIAL_PARAMS_DEMO_MOD)
	if card:
		var gear := card.get_node_or_null("GearIcon") as Control
		if gear and gear.visible:
			return gear
		return card
	return _center_card


func _on_modifiers_tutorial_closed() -> void:
	if SettingsManager and SettingsManager.has_method("set_tutorial_modifiers_done"):
		SettingsManager.set_tutorial_modifiers_done(true)


func debug_show_tutorial() -> void:
	_maybe_show_modifiers_tutorial(true)
