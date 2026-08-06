# scenes/settings_menu/tabs/generation_tab.gd
extends Control

signal settings_changed

const _OptionButtonPopupUtils = preload("res://logic/ui/option_button_popup_utils.gd")
const _SpinBoxUtils = preload("res://logic/ui/spin_box_utils.gd")
const _StringCharUtils = preload("res://logic/platform/string_char_utils.gd")
const _SegmentedOptionUtils = preload("res://logic/ui/segmented_option_utils.gd")
const _SettingsSectionUi = preload("res://logic/ui/settings_section_ui.gd")
const _GenerationBulkQueueActions = preload("res://logic/ui/generation_bulk_queue_actions.gd")
const _UiModifierSounds = preload("res://logic/ui/ui_modifier_sounds.gd")
const _AppOverlayHelpers = preload("res://logic/ui/app_overlay_helpers.gd")
const _GenerationGpuStack = preload("res://logic/services/generation_gpu_stack.gd")

const _GPU_OPTION_IDS := ["auto", "nvidia", "amd", "cpu"]

const _GenStatusMode = preload("res://logic/domain/library/generation_status_mode.gd")

const _GoalDiff = preload("res://logic/domain/generation/generation_goal_difficulty.gd")
const _GenPresetUi = preload("res://logic/ui/generation_preset_ui.gd")
const _SongSelectUiStyles = preload("res://scenes/song_select/lib/song_select_ui_styles.gd")
const _ToggleIconScript = preload("res://scenes/song_select/endless/session_toggle_icon.gd")
const _GenReadyPresetsUi = preload("res://logic/ui/generation_ready_presets_ui.gd")

const _READY_DIFF_ICONS := {
	"easy": "feather.svg",
	"medium": "circle-check.svg",
	"hard": "flame_gen.svg",
}
const _READY_DIFF_COLORS := {
	"easy": Color(0.62, 0.82, 0.96, 1.0),
	"medium": Color(0.55, 0.78, 0.98, 1.0),
	"hard": Color(1.0, 0.58, 0.32, 1.0),
}

const _CV := "ScrollWrap/CenterWrap/ContentVBox"
const _SERVER := "%s/ServerPanel/ServerPanelMargin/ServerRows" % _CV
const _PARAMS := "%s/ParamsPanel/ParamsPanelMargin/ParamsRows" % _CV
const _BULK := "%s/BulkPanel/BulkPanelMargin/BulkRows" % _CV

@onready var server_header: Label = get_node("%s/ServerHeader" % _SERVER)
@onready var params_header: Label = get_node("%s/ParamsHeader" % _PARAMS)
@onready var generation_status_mode_option: OptionButton = get_node("%s/GenerationStatusModeRow/GenerationStatusModeOption" % _PARAMS)
@onready var confirm_before_rerun_checkbox: CheckBox = get_node("%s/ConfirmBeforeRerunCheckBox" % _PARAMS)
@onready var notify_done_minimized_checkbox: CheckBox = get_node_or_null("%s/NotifyDoneMinimizedCheckBox" % _PARAMS)
@onready var stem_retention_option: OptionButton = get_node("%s/StemRetentionRow/StemRetentionOption" % _PARAMS)
@onready var stem_keep_all_checkbox: CheckBox = get_node("%s/StemKeepAllCheckBox" % _PARAMS)
@onready var bulk_force_regen_checkbox: CheckBox = get_node("%s/BulkForceRegenCheckBox" % _BULK)
@onready var bulk_bpm_button: Button = get_node("%s/BulkButtonsRow/BulkBpmButton" % _BULK)
@onready var bulk_notes_button: Button = get_node("%s/BulkButtonsRow/BulkNotesButton" % _BULK)
@onready var _confirm_overlay: AppConfirmOverlay = %ConfirmOverlay
@onready var _notice_overlay: AppNoticeOverlay = %NoticeOverlay
@onready var ready_axes_host: VBoxContainer = get_node_or_null("%s/GenerationReadyAxesBlock/ReadyAxesHost" % _PARAMS)
@onready var generation_server_location_option: OptionButton = get_node("%s/GenerationServerLocation/GenerationServerLocationOption" % _SERVER)
@onready var generation_server_lan_host_hbox: HBoxContainer = get_node("%s/GenerationServerLanHostHBox" % _SERVER)
@onready var generation_server_lan_host_line_edit: LineEdit = get_node("%s/GenerationServerLanHostHBox/GenerationServerLanHostLineEdit" % _SERVER)
@onready var generation_server_port_spin: SpinBox = get_node("%s/GenerationServerPortHBox/GenerationServerPortSpin" % _SERVER)
@onready var gpu_stack_hint: Label = get_node_or_null("%s/GpuStackHint" % _SERVER)
@onready var gpu_stack_status_label: Label = get_node_or_null("%s/GpuStackStatusLabel" % _SERVER)
@onready var gpu_stack_label: Label = get_node_or_null("%s/GpuStackRow/GpuStackLabel" % _SERVER)
@onready var gpu_stack_option: OptionButton = get_node_or_null("%s/GpuStackRow/GpuStackOption" % _SERVER)
@onready var gpu_stack_scan_button: Button = get_node_or_null("%s/GpuStackActionsRow/GpuStackScanButton" % _SERVER)
@onready var gpu_stack_apply_button: Button = get_node_or_null("%s/GpuStackActionsRow/GpuStackApplyButton" % _SERVER)

@onready var server_hint: Label = get_node_or_null("%s/ServerHint" % _SERVER)
@onready var server_help_link: LinkButton = get_node_or_null("%s/ServerHelpLink" % _SERVER)
@onready var params_hint: Label = get_node_or_null("%s/ParamsHint" % _PARAMS)
@onready var scope_hint: Label = get_node_or_null("%s/ScopeHint" % _PARAMS)
@onready var scope_help_link: LinkButton = get_node_or_null("%s/ScopeHelpLink" % _PARAMS)
@onready var stem_retention_hint: Label = get_node_or_null("%s/StemRetentionHint" % _PARAMS)
@onready var bulk_header: Label = get_node_or_null("%s/BulkHeader" % _BULK)
@onready var bulk_hint: Label = get_node_or_null("%s/BulkHint" % _BULK)
var _server_loc_seg: Dictionary = {}
var _status_mode_seg: Dictionary = {}
var _gpu_stack_seg: Dictionary = {}
var _lan_host_ipv4_format_lock := false
var _ready_axis_captions: Dictionary = {}
var _ready_axis_sections: Dictionary = {}
var _ready_value_icons: Dictionary = {}
var _ready_axes_built := false
var _ready_axes_syncing := false
var _ready_presets_state: Dictionary = {}
var _ready_accent := Color(0.42, 0.72, 0.98, 1.0)
var _gpu_stack_busy := false
var _installed_gpu_mode := ""
var _recommended_gpu_mode := ""
var _gpu_scan_adapters := ""
var _gpu_scan_loaded := false

func _notification(what: int) -> void:
	if what != NOTIFICATION_VISIBILITY_CHANGED:
		return
	if not is_visible_in_tree():
		return
	call_deferred("_sync_generation_server_lan_row_visibility")
	call_deferred("_refresh_gpu_stack_status")
	if _ready_axes_built:
		call_deferred("_sync_ready_axes_ui_from_settings")


func _ready() -> void:
	add_to_group("locale_refresh")
	if generation_server_lan_host_line_edit:
		generation_server_lan_host_line_edit.text_changed.connect(_on_generation_server_lan_host_text_changed)
	call_deferred("_ensure_ready_axes_ui")
	call_deferred("_apply_initial_settings")
	call_deferred("_setup_generation_server_location_popup_font")
	call_deferred("_setup_generation_server_port_spin_font")
	call_deferred("_setup_stem_retention_popup_font")
	call_deferred("_setup_gpu_stack_popup_font")
	call_deferred("_build_server_location_segmented")
	call_deferred("_build_status_mode_segmented")
	call_deferred("apply_locale")
	call_deferred("_build_gpu_stack_segmented")
	call_deferred("_apply_settings_checkbox_styles")
	call_deferred("_refresh_gpu_stack_status")


func apply_locale() -> void:
	if server_header:
		server_header.text = tr("MISC_GEN_SERVER_SECTION")
	if server_hint:
		server_hint.text = tr("SETTINGS_SERVER_SECTION_HINT")
	if server_help_link:
		server_help_link.text = tr("SETTINGS_HELP_LINK_SERVER")
	if params_header:
		params_header.text = tr("MISC_GEN_PARAMS_SECTION")
	if params_hint:
		params_hint.text = tr("SETTINGS_PARAMS_SECTION_HINT")
	if scope_hint:
		scope_hint.text = tr("SETTINGS_SCOPE_HINT")
	if scope_help_link:
		scope_help_link.text = tr("SETTINGS_HELP_LINK_SCOPE")
	if bulk_header:
		bulk_header.text = tr("GEN_BULK_SETTINGS_SECTION")
	if bulk_hint:
		bulk_hint.text = tr("GEN_BULK_SETTINGS_HINT")
	if bulk_bpm_button:
		bulk_bpm_button.text = tr("GEN_BULK_QUEUE_BPM_ALL")
	if bulk_notes_button:
		bulk_notes_button.text = tr("GEN_BULK_QUEUE_NOTES_ALL")
	if _confirm_overlay:
		_confirm_overlay.apply_locale()
	if _notice_overlay:
		_notice_overlay.apply_locale()
	_apply_labels()
	_apply_tooltips()
	_refresh_gpu_stack_status()


func _setup_generation_server_location_popup_font() -> void:
	_OptionButtonPopupUtils.apply_popup_font_size(generation_server_location_option, 24)


func _setup_generation_server_port_spin_font() -> void:
	if generation_server_port_spin:
		_SpinBoxUtils.apply_value_font_size(generation_server_port_spin, 24)


func _setup_stem_retention_popup_font() -> void:
	if stem_retention_option:
		_OptionButtonPopupUtils.apply_popup_font_size(stem_retention_option, 24)


func _setup_gpu_stack_popup_font() -> void:
	if gpu_stack_option:
		_OptionButtonPopupUtils.apply_popup_font_size(gpu_stack_option, 24)


func _apply_settings_checkbox_styles() -> void:
	const ACCENT := Color(0.62, 0.86, 0.72, 1.0)
	_SettingsSectionUi.apply_settings_checkbox(confirm_before_rerun_checkbox, 22, false, ACCENT)
	_SettingsSectionUi.apply_settings_checkbox(bulk_force_regen_checkbox, 22, false, ACCENT)
	_SettingsSectionUi.apply_settings_checkbox(stem_keep_all_checkbox, 22, false, ACCENT)
	_SettingsSectionUi.apply_settings_checkbox(notify_done_minimized_checkbox, 22, false, ACCENT)


func _apply_labels() -> void:
	var gen_scope_label: Label = get_node_or_null("%s/GenerationReadyAxesBlock/GenerationNotesScopeLabel" % _PARAMS)
	if gen_scope_label:
		gen_scope_label.text = tr("MISC_GEN_SCOPE")
	_apply_ready_axes_labels()
	var status_mode_label: Label = get_node_or_null("%s/GenerationStatusModeRow/GenerationStatusModeLabel" % _PARAMS)
	if status_mode_label:
		status_mode_label.text = tr("MISC_GEN_STATUS_MODE")
	if generation_status_mode_option:
		generation_status_mode_option.set_block_signals(true)
		if generation_status_mode_option.item_count < 3:
			generation_status_mode_option.clear()
			generation_status_mode_option.add_item(tr("MISC_GEN_STATUS_FULL"), 0)
			generation_status_mode_option.add_item(tr("MISC_GEN_STATUS_COMPACT"), 1)
			generation_status_mode_option.add_item(tr("MISC_GEN_STATUS_OFF"), 2)
		else:
			generation_status_mode_option.set_item_text(0, tr("MISC_GEN_STATUS_FULL"))
			generation_status_mode_option.set_item_text(1, tr("MISC_GEN_STATUS_COMPACT"))
			generation_status_mode_option.set_item_text(2, tr("MISC_GEN_STATUS_OFF"))
		_select_status_mode_option(_GenStatusMode.from_settings())
		generation_status_mode_option.set_block_signals(false)
		if not _status_mode_seg.is_empty():
			_SegmentedOptionUtils.apply_texts(
				_status_mode_seg.get("buttons", []),
				PackedStringArray([tr("MISC_GEN_STATUS_FULL"), tr("MISC_GEN_STATUS_COMPACT"), tr("MISC_GEN_STATUS_OFF")])
			)
			_sync_status_mode_segment()
	if confirm_before_rerun_checkbox:
		confirm_before_rerun_checkbox.text = tr("MISC_CONFIRM_BEFORE_RERUN_LONG")
	if notify_done_minimized_checkbox:
		notify_done_minimized_checkbox.text = tr("MISC_NOTIFY_DONE_MINIMIZED")
	_apply_stem_retention_labels()
	if bulk_force_regen_checkbox:
		bulk_force_regen_checkbox.text = tr("MISC_BULK_FORCE_REGEN_LONG")
	var server_loc_label: Label = get_node_or_null("%s/GenerationServerLocation/GenerationServerLocationLabel" % _SERVER)
	if server_loc_label:
		server_loc_label.text = tr("MISC_SERVER_FLASK")
	if generation_server_location_option:
		generation_server_location_option.set_block_signals(true)
		if generation_server_location_option.item_count < 3:
			generation_server_location_option.clear()
			generation_server_location_option.add_item(tr("MISC_SERVER_AUTO"), 0)
			generation_server_location_option.add_item(tr("MISC_SERVER_MANUAL"), 1)
			generation_server_location_option.add_item(tr("MISC_SERVER_LAN_PC"), 2)
		else:
			generation_server_location_option.set_item_text(0, tr("MISC_SERVER_AUTO"))
			generation_server_location_option.set_item_text(1, tr("MISC_SERVER_MANUAL"))
			generation_server_location_option.set_item_text(2, tr("MISC_SERVER_LAN_PC"))
		var use_lan := bool(SettingsManager.get_setting("generation_server_use_lan_host", false))
		var auto_worker := bool(SettingsManager.get_setting("generation_auto_worker", true))
		var select_idx := 2 if use_lan else (0 if auto_worker else 1)
		generation_server_location_option.select(select_idx)
		generation_server_location_option.set_block_signals(false)
		if not _server_loc_seg.is_empty():
			_SegmentedOptionUtils.apply_texts(
				_server_loc_seg.get("buttons", []),
				PackedStringArray([tr("MISC_SERVER_AUTO"), tr("MISC_SERVER_MANUAL"), tr("MISC_SERVER_LAN_PC")])
			)
			_sync_server_location_segment()
		_apply_generation_server_lan_visibility(use_lan)
	var host_label: Label = get_node_or_null("%s/GenerationServerLanHostHBox/GenerationServerLanHostLabel" % _SERVER)
	if host_label:
		host_label.text = tr("MISC_SERVER_HOST_IP")
	var port_label: Label = get_node_or_null("%s/GenerationServerPortHBox/GenerationServerPortLabel" % _SERVER)
	if port_label:
		port_label.text = tr("MISC_SERVER_PORT_LABEL")
	_apply_gpu_stack_labels()


func _apply_gpu_stack_labels() -> void:
	if gpu_stack_hint:
		gpu_stack_hint.text = tr("MISC_GPU_STACK_HINT")
	if gpu_stack_label:
		gpu_stack_label.text = tr("MISC_GPU_STACK_LABEL")
	if gpu_stack_scan_button:
		gpu_stack_scan_button.text = tr("MISC_GPU_STACK_SCAN")
	if gpu_stack_apply_button:
		gpu_stack_apply_button.text = tr("MISC_GPU_STACK_APPLY")
	if gpu_stack_option:
		gpu_stack_option.set_block_signals(true)
		if gpu_stack_option.item_count < 4:
			gpu_stack_option.clear()
			gpu_stack_option.add_item(tr("MISC_GPU_STACK_AUTO"), 0)
			gpu_stack_option.add_item(tr("MISC_GPU_STACK_NVIDIA"), 1)
			gpu_stack_option.add_item(tr("MISC_GPU_STACK_AMD"), 2)
			gpu_stack_option.add_item(tr("MISC_GPU_STACK_CPU"), 3)
		else:
			gpu_stack_option.set_item_text(0, tr("MISC_GPU_STACK_AUTO"))
			gpu_stack_option.set_item_text(1, tr("MISC_GPU_STACK_NVIDIA"))
			gpu_stack_option.set_item_text(2, tr("MISC_GPU_STACK_AMD"))
			gpu_stack_option.set_item_text(3, tr("MISC_GPU_STACK_CPU"))
		var mode := _GenerationGpuStack.normalize_mode(str(SettingsManager.get_setting("generation_gpu_stack", "auto")))
		var idx := _GPU_OPTION_IDS.find(mode)
		gpu_stack_option.select(maxi(idx, 0))
		gpu_stack_option.set_block_signals(false)
	_load_gpu_scan_cache()
	_sync_gpu_stack_segment_texts()
	_update_gpu_stack_enabled()


func _build_gpu_stack_segmented() -> void:
	if _gpu_stack_seg.is_empty() and gpu_stack_option:
		if gpu_stack_option.item_count < 4:
			gpu_stack_option.clear()
			gpu_stack_option.add_item(tr("MISC_GPU_STACK_AUTO"), 0)
			gpu_stack_option.add_item(tr("MISC_GPU_STACK_NVIDIA"), 1)
			gpu_stack_option.add_item(tr("MISC_GPU_STACK_AMD"), 2)
			gpu_stack_option.add_item(tr("MISC_GPU_STACK_CPU"), 3)
		_gpu_stack_seg = _SegmentedOptionUtils.build_from_option_button(
			gpu_stack_option,
			16,
			44,
			420.0
		)
		for btn in _gpu_stack_seg.get("buttons", []):
			(btn as Button).pressed.connect(_on_gpu_stack_segment_pressed.bind(btn))
	_sync_gpu_stack_segment_texts()
	_update_gpu_stack_enabled()


func _on_gpu_stack_segment_pressed(btn: Button) -> void:
	if gpu_stack_option == null or _gpu_stack_busy:
		return
	var id := _SegmentedOptionUtils.id_from_button(btn)
	for i in range(gpu_stack_option.item_count):
		if gpu_stack_option.get_item_id(i) == id:
			_SegmentedOptionUtils.play_segment_select_sound()
			gpu_stack_option.set_block_signals(true)
			gpu_stack_option.select(i)
			gpu_stack_option.set_block_signals(false)
			var mode := _selected_gpu_mode()
			SettingsManager.set_setting("generation_gpu_stack", mode)
			_SegmentedOptionUtils.select_id(_gpu_stack_seg.get("buttons", []), id)
			_update_gpu_stack_enabled()
			emit_signal("settings_changed")
			return


func _sync_gpu_stack_segment_texts() -> void:
	if _gpu_stack_seg.is_empty():
		return
	var installed := _installed_gpu_mode
	var texts := PackedStringArray([
		tr("MISC_GPU_STACK_AUTO"),
		tr("MISC_GPU_STACK_NVIDIA"),
		tr("MISC_GPU_STACK_AMD"),
		tr("MISC_GPU_STACK_CPU"),
	])
	var mark := tr("MISC_GPU_STACK_INSTALLED_SUFFIX")
	for i in range(_GPU_OPTION_IDS.size()):
		var mode := str(_GPU_OPTION_IDS[i])
		if mode != "auto" and mode == installed and mark.strip_edges() != "":
			texts[i] = "%s %s" % [texts[i], mark]
	_SegmentedOptionUtils.apply_texts(_gpu_stack_seg.get("buttons", []), texts)
	if gpu_stack_option:
		_SegmentedOptionUtils.select_id(
			_gpu_stack_seg.get("buttons", []),
			gpu_stack_option.get_item_id(maxi(gpu_stack_option.selected, 0))
		)


func _apply_tooltips() -> void:
	var gen_scope_label: Label = get_node_or_null("%s/GenerationReadyAxesBlock/GenerationNotesScopeLabel" % _PARAMS)
	if gen_scope_label:
		gen_scope_label.tooltip_text = tr("SETTINGS_SCOPE_HINT")
	_apply_ready_axes_labels()
	var status_mode_label: Label = get_node_or_null("%s/GenerationStatusModeRow/GenerationStatusModeLabel" % _PARAMS)
	if status_mode_label:
		status_mode_label.tooltip_text = tr("MISC_GEN_STATUS_MODE_TOOLTIP")
	if generation_status_mode_option:
		generation_status_mode_option.tooltip_text = tr("MISC_GEN_STATUS_MODE_TOOLTIP")
	if confirm_before_rerun_checkbox:
		confirm_before_rerun_checkbox.tooltip_text = tr("MISC_CONFIRM_BEFORE_RERUN_TOOLTIP")
	if notify_done_minimized_checkbox:
		notify_done_minimized_checkbox.tooltip_text = tr("MISC_NOTIFY_DONE_MINIMIZED_TOOLTIP")
	_apply_stem_retention_tooltips()
	if bulk_force_regen_checkbox:
		bulk_force_regen_checkbox.tooltip_text = tr("MISC_BULK_FORCE_REGEN_TOOLTIP")
	var server_loc_label: Label = get_node_or_null("%s/GenerationServerLocation/GenerationServerLocationLabel" % _SERVER)
	if server_loc_label:
		server_loc_label.tooltip_text = tr("MISC_SERVER_FLASK_TOOLTIP")
	if generation_server_location_option:
		generation_server_location_option.tooltip_text = tr("MISC_SERVER_FLASK_TOOLTIP")
	var host_label: Label = get_node_or_null("%s/GenerationServerLanHostHBox/GenerationServerLanHostLabel" % _SERVER)
	if host_label:
		host_label.tooltip_text = tr("MISC_SERVER_HOST_IP_TOOLTIP")
	if generation_server_lan_host_line_edit:
		generation_server_lan_host_line_edit.tooltip_text = tr("MISC_SERVER_HOST_IP_TOOLTIP")
	var port_label: Label = get_node_or_null("%s/GenerationServerPortHBox/GenerationServerPortLabel" % _SERVER)
	if port_label:
		port_label.tooltip_text = tr("MISC_SERVER_PORT_TOOLTIP")
	if generation_server_port_spin:
		generation_server_port_spin.tooltip_text = tr("MISC_SERVER_PORT_TOOLTIP")
	if gpu_stack_option:
		gpu_stack_option.tooltip_text = tr("MISC_GPU_STACK_TOOLTIP")
	if gpu_stack_scan_button:
		gpu_stack_scan_button.tooltip_text = tr("MISC_GPU_STACK_SCAN_TOOLTIP")
	if gpu_stack_apply_button:
		gpu_stack_apply_button.tooltip_text = tr("MISC_GPU_STACK_TOOLTIP")
	if gpu_stack_label:
		gpu_stack_label.tooltip_text = tr("MISC_GPU_STACK_TOOLTIP")


func _on_server_help_link_pressed() -> void:
	_open_help_topic("SETTINGS_HELP_SEARCH_SERVER")


func _on_scope_help_link_pressed() -> void:
	_open_help_topic("SETTINGS_HELP_SEARCH_SCOPE")


func _open_help_topic(search_key: String) -> void:
	var shell := _settings_shell()
	if shell and shell.has_method("open_help_topic"):
		shell.open_help_topic(search_key)


func _settings_shell() -> Node:
	var node: Node = self
	while node:
		if node.has_method("open_help_topic"):
			return node
		node = node.get_parent()
	return null


func _apply_initial_settings() -> void:
	if generation_status_mode_option:
		_select_status_mode_option(_GenStatusMode.from_settings())
		_sync_status_mode_segment()
	var confirm_before_rerun = SettingsManager.get_setting("generation_confirm_before_rerun", true)
	confirm_before_rerun_checkbox.set_pressed_no_signal(confirm_before_rerun)
	if notify_done_minimized_checkbox:
		notify_done_minimized_checkbox.set_pressed_no_signal(
			bool(SettingsManager.get_setting("notify_generation_done_when_minimized", true))
		)
	var bulk_force_regen = SettingsManager.get_setting("generation_bulk_force_regen", true)
	if bulk_force_regen_checkbox:
		bulk_force_regen_checkbox.set_pressed_no_signal(bulk_force_regen)
	_apply_stem_retention_settings()
	_sync_ready_axes_ui_from_settings()
	if generation_server_location_option:
		var use_lan := bool(SettingsManager.get_setting("generation_server_use_lan_host", false))
		var auto_worker := bool(SettingsManager.get_setting("generation_auto_worker", true))
		generation_server_location_option.set_block_signals(true)
		if use_lan:
			generation_server_location_option.select(2)
		elif auto_worker:
			generation_server_location_option.select(0)
		else:
			generation_server_location_option.select(1)
		generation_server_location_option.set_block_signals(false)
		_apply_generation_server_lan_visibility(use_lan)
	if generation_server_lan_host_line_edit:
		_lan_host_ipv4_format_lock = true
		generation_server_lan_host_line_edit.text = String(SettingsManager.get_setting("generation_server_lan_host", ""))
		_lan_host_ipv4_format_lock = false
	if generation_server_port_spin:
		var pv := clampi(int(SettingsManager.get_setting("generation_server_port", 5000)), 1, 65535)
		generation_server_port_spin.set_block_signals(true)
		generation_server_port_spin.value = pv
		generation_server_port_spin.set_block_signals(false)
	_sync_server_location_segment()


func _status_mode_from_option_id(option_id: int) -> String:
	match option_id:
		1:
			return _GenStatusMode.COMPACT
		2:
			return _GenStatusMode.OFF
		_:
			return _GenStatusMode.FULL


func _option_id_for_status_mode(mode: String) -> int:
	match String(mode).strip_edges().to_lower():
		_GenStatusMode.COMPACT:
			return 1
		_GenStatusMode.OFF:
			return 2
		_:
			return 0


func _select_status_mode_option(mode: String) -> void:
	_select_status_mode_by_id(_option_id_for_status_mode(mode))


func _select_status_mode_by_id(option_id: int) -> void:
	if generation_status_mode_option:
		generation_status_mode_option.set_block_signals(true)
		for i in range(generation_status_mode_option.item_count):
			if generation_status_mode_option.get_item_id(i) == option_id:
				generation_status_mode_option.select(i)
				break
		generation_status_mode_option.set_block_signals(false)
	if not _status_mode_seg.is_empty():
		_SegmentedOptionUtils.select_id(_status_mode_seg.get("buttons", []), option_id)


func _build_status_mode_segmented() -> void:
	if _status_mode_seg.is_empty() and generation_status_mode_option:
		if generation_status_mode_option.item_count < 3:
			generation_status_mode_option.clear()
			generation_status_mode_option.add_item(tr("MISC_GEN_STATUS_FULL"), 0)
			generation_status_mode_option.add_item(tr("MISC_GEN_STATUS_COMPACT"), 1)
			generation_status_mode_option.add_item(tr("MISC_GEN_STATUS_OFF"), 2)
		_status_mode_seg = _SegmentedOptionUtils.build_from_option_button(
			generation_status_mode_option,
			18,
			44,
			360.0
		)
		for btn in _status_mode_seg.get("buttons", []):
			(btn as Button).pressed.connect(_on_status_mode_segment_pressed.bind(btn))
	_sync_status_mode_segment()


func _sync_status_mode_segment() -> void:
	if generation_status_mode_option == null:
		return
	var idx := generation_status_mode_option.selected
	if idx < 0:
		idx = 0
	_select_status_mode_by_id(generation_status_mode_option.get_item_id(idx))


func _on_status_mode_segment_pressed(btn: Button) -> void:
	var id := _SegmentedOptionUtils.id_from_button(btn)
	if generation_status_mode_option == null:
		return
	for i in range(generation_status_mode_option.item_count):
		if generation_status_mode_option.get_item_id(i) == id:
			_on_generation_status_mode_selected(i)
			return


func _build_server_location_segmented() -> void:
	if _server_loc_seg.is_empty() and generation_server_location_option:
		if generation_server_location_option.item_count < 3:
			generation_server_location_option.clear()
			generation_server_location_option.add_item(tr("MISC_SERVER_AUTO"), 0)
			generation_server_location_option.add_item(tr("MISC_SERVER_MANUAL"), 1)
			generation_server_location_option.add_item(tr("MISC_SERVER_LAN_PC"), 2)
		_server_loc_seg = _SegmentedOptionUtils.build_from_option_button(
			generation_server_location_option,
			18,
			44,
			360.0
		)
		for btn in _server_loc_seg.get("buttons", []):
			(btn as Button).pressed.connect(_on_server_location_segment_pressed.bind(btn))
	_sync_server_location_segment()


func _sync_server_location_segment() -> void:
	if generation_server_location_option == null:
		return
	var idx := generation_server_location_option.selected
	if idx < 0:
		idx = 0
	_select_server_location_index(idx)


func _on_server_location_segment_pressed(btn: Button) -> void:
	var id := _SegmentedOptionUtils.id_from_button(btn)
	if generation_server_location_option == null:
		return
	for i in range(generation_server_location_option.item_count):
		if generation_server_location_option.get_item_id(i) == id:
			_on_generation_server_location_selected(i)
			return


func _select_server_location_index(index: int) -> void:
	if generation_server_location_option == null:
		return
	var idx := clampi(index, 0, generation_server_location_option.item_count - 1)
	generation_server_location_option.set_block_signals(true)
	generation_server_location_option.select(idx)
	generation_server_location_option.set_block_signals(false)
	if not _server_loc_seg.is_empty():
		_SegmentedOptionUtils.select_id(
			_server_loc_seg.get("buttons", []),
			generation_server_location_option.get_item_id(idx)
		)


func _apply_generation_server_lan_visibility(use_lan: bool) -> void:
	if generation_server_lan_host_hbox:
		generation_server_lan_host_hbox.visible = use_lan


func _sync_generation_server_lan_row_visibility() -> void:
	if generation_server_lan_host_hbox == null:
		return
	var use_lan := bool(SettingsManager.get_setting("generation_server_use_lan_host", false))
	generation_server_lan_host_hbox.visible = use_lan


func _ensure_ready_axes_ui() -> void:
	if ready_axes_host == null:
		return
	if _ready_axes_built:
		return
	_ready_axes_built = true
	_add_ready_axis_icons("instruments", "MISC_GEN_SCOPE_AXIS_INSTRUMENTS", _GoalDiff.READY_INSTRUMENTS)
	_add_ready_axis_icons("goals", "MISC_GEN_SCOPE_AXIS_GOALS", _GoalDiff.GOALS)
	_add_ready_axis_icons("diffs", "MISC_GEN_SCOPE_AXIS_DIFFS", _GoalDiff.DIFFICULTIES)
	_ready_presets_state = _GenReadyPresetsUi.attach(ready_axes_host, _ready_accent)
	_GenReadyPresetsUi.apply_labels(_ready_presets_state)
	_sync_ready_axes_ui_from_settings()


func _ready_value_label_key(axis_id: String, value_id: String) -> String:
	match axis_id:
		"goals":
			return "GEN_GOAL_%s" % value_id.to_upper()
		"diffs":
			return "GEN_DIFF_%s" % value_id.to_upper()
		_:
			return "GEN_INST_%s" % value_id.to_upper()


func _ready_value_tooltip(axis_id: String, value_id: String) -> String:
	# Difficulties apply to Arcade only — Original is a single documentary chart.
	if axis_id == "diffs":
		return tr("GEN_DIFF_%s" % value_id.to_upper())
	return tr(_ready_value_label_key(axis_id, value_id))


func _ready_icon_spec(axis_id: String, value_id: String) -> Dictionary:
	match axis_id:
		"goals":
			return {
				"icon": str(_GenPresetUi.INTENT_ICONS.get(value_id, "audio-lines.svg")),
				"tint": _GenPresetUi.INTENT_ICON_COLORS.get(value_id, _ready_accent),
			}
		"diffs":
			return {
				"icon": str(_READY_DIFF_ICONS.get(value_id, "circle-check.svg")),
				"tint": _READY_DIFF_COLORS.get(value_id, _ready_accent),
			}
		_:
			return {
				"icon": str(_GenPresetUi.INSTRUMENT_ICONS.get(value_id, "drum.svg")),
				"tint": _GenPresetUi.INSTRUMENT_ICON_COLORS.get(value_id, _ready_accent),
			}


func _add_ready_axis_icons(axis_id: String, caption_key: String, values: Array) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	ready_axes_host.add_child(section)
	_ready_axis_sections[axis_id] = section
	var caption := Label.new()
	caption.text = tr(caption_key)
	caption.add_theme_font_size_override("font_size", 14)
	caption.add_theme_color_override("font_color", Color(0.62, 0.7, 0.82, 0.95))
	section.add_child(caption)
	_ready_axis_captions[axis_id] = caption
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _SongSelectUiStyles.card_panel_style())
	section.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	_ready_value_icons[axis_id] = {}
	for value_id in values:
		var vid := str(value_id)
		var spec := _ready_icon_spec(axis_id, vid)
		var icon := _ToggleIconScript.new() as SessionToggleIcon
		icon.setup(vid, str(spec.get("icon", "")), spec.get("tint", _ready_accent) as Color, _ready_value_tooltip(axis_id, vid))
		icon.option_toggled.connect(_on_ready_icon_toggled.bind(axis_id))
		row.add_child(icon)
		_ready_value_icons[axis_id][vid] = icon


func _ready_goals_include_arcade() -> bool:
	var icons: Dictionary = _ready_value_icons.get("goals", {})
	var arcade: SessionToggleIcon = icons.get("arcade")
	if arcade:
		return arcade.button_pressed
	var goals: Variant = SettingsManager.get_setting("generation_ready_goals", [_GoalDiff.DEFAULT_GOAL])
	if goals is Array or goals is PackedStringArray:
		for g in goals:
			if str(g).strip_edges().to_lower() == "arcade":
				return true
	return false


func _sync_ready_diffs_row_visibility() -> void:
	## Original is one documentary chart — Arcade difficulties row only when Arcade is selected.
	var section: Control = _ready_axis_sections.get("diffs")
	if section:
		section.visible = _ready_goals_include_arcade()


func _apply_ready_axes_labels() -> void:
	var caption_keys := {
		"goals": "MISC_GEN_SCOPE_AXIS_GOALS",
		"diffs": "MISC_GEN_SCOPE_AXIS_DIFFS",
		"instruments": "MISC_GEN_SCOPE_AXIS_INSTRUMENTS",
	}
	for axis_id in _ready_axis_captions.keys():
		var caption: Label = _ready_axis_captions[axis_id]
		if caption:
			caption.text = tr(str(caption_keys.get(axis_id, "")))
		var icons: Dictionary = _ready_value_icons.get(axis_id, {})
		for value_id in icons.keys():
			var icon: SessionToggleIcon = icons[value_id]
			if icon:
				icon.set_tooltip_text_value(_ready_value_tooltip(str(axis_id), str(value_id)))
	_GenReadyPresetsUi.apply_labels(_ready_presets_state)


func _sync_ready_axes_ui_from_settings() -> void:
	if ready_axes_host == null or not _ready_axes_built:
		return
	_ready_axes_syncing = true
	_set_ready_axis_icons(
		"goals",
		SettingsManager.get_setting("generation_ready_goals", [_GoalDiff.DEFAULT_GOAL]),
		_GoalDiff.GOALS,
		str(SettingsManager.get_setting("generation_goal", _GoalDiff.DEFAULT_GOAL))
	)
	_set_ready_axis_icons(
		"diffs",
		SettingsManager.get_setting("generation_ready_diffs", [_GoalDiff.DEFAULT_DIFFICULTY]),
		_GoalDiff.DIFFICULTIES,
		str(SettingsManager.get_setting("generation_difficulty", _GoalDiff.DEFAULT_DIFFICULTY))
	)
	_set_ready_axis_icons(
		"instruments",
		SettingsManager.get_setting("generation_ready_instruments", [_GoalDiff.DEFAULT_READY_INSTRUMENT]),
		_GoalDiff.READY_INSTRUMENTS,
		str(SettingsManager.get_setting("last_generation_instrument", _GoalDiff.DEFAULT_READY_INSTRUMENT))
	)
	_sync_ready_diffs_row_visibility()
	_GenReadyPresetsUi.sync_from_settings(_ready_presets_state)
	_ready_axes_syncing = false


func _set_ready_axis_icons(axis_id: String, selected_raw: Variant, allowed: Array, fallback: String) -> void:
	var selected := _GoalDiff.sanitize_ready_string_list(selected_raw, allowed, fallback)
	var icons: Dictionary = _ready_value_icons.get(axis_id, {})
	for value_id in icons.keys():
		var icon: SessionToggleIcon = icons[value_id]
		if icon:
			icon.set_selected(selected.has(str(value_id)))


func _on_ready_icon_toggled(_value_id: String, pressed: bool, axis_id: String) -> void:
	if _ready_axes_syncing:
		return
	if not pressed and _count_axis_selected(axis_id) <= 0:
		var icon: SessionToggleIcon = _ready_value_icons.get(axis_id, {}).get(_value_id)
		if icon:
			icon.set_selected(true)
		if MusicManager and MusicManager.has_method("play_cancel_sound"):
			MusicManager.play_cancel_sound()
		else:
			_UiModifierSounds.play_deselect()
		return
	_persist_ready_axis_values(axis_id)
	if axis_id == "goals":
		_sync_ready_diffs_row_visibility()
	_UiModifierSounds.play_toggle(pressed)
	NotesUtils.invalidate_notes_cache()
	emit_signal("settings_changed")
	_refresh_song_select_notes_highlights()


func _count_axis_selected(axis_id: String) -> int:
	var count := 0
	var icons: Dictionary = _ready_value_icons.get(axis_id, {})
	for icon in icons.values():
		if icon and (icon as SessionToggleIcon).button_pressed:
			count += 1
	return count


func _ensure_axis_has_selection(axis_id: String) -> void:
	if _count_axis_selected(axis_id) > 0:
		return
	var fallback := ""
	match axis_id:
		"goals":
			fallback = str(SettingsManager.get_setting("generation_goal", _GoalDiff.DEFAULT_GOAL))
		"diffs":
			fallback = str(SettingsManager.get_setting("generation_difficulty", _GoalDiff.DEFAULT_DIFFICULTY))
		_:
			fallback = str(SettingsManager.get_setting("last_generation_instrument", _GoalDiff.DEFAULT_READY_INSTRUMENT))
	var icons: Dictionary = _ready_value_icons.get(axis_id, {})
	var icon: SessionToggleIcon = icons.get(fallback)
	if icon == null and not icons.is_empty():
		icon = icons.values()[0]
	if icon:
		icon.set_selected(true)


func _persist_ready_axis_values(axis_id: String) -> void:
	var selected: Array[String] = []
	var icons: Dictionary = _ready_value_icons.get(axis_id, {})
	for value_id in icons.keys():
		var icon: SessionToggleIcon = icons[value_id]
		if icon and icon.button_pressed:
			selected.append(str(value_id))
	if selected.is_empty():
		_ensure_axis_has_selection(axis_id)
		for value_id in icons.keys():
			var icon2: SessionToggleIcon = icons[value_id]
			if icon2 and icon2.button_pressed:
				selected.append(str(value_id))
	SettingsManager.set_setting("generation_ready_%s" % axis_id, selected)


func _refresh_song_select_notes_highlights() -> void:
	_call_refresh_notes_highlights_recursive(get_tree().root)


func _call_refresh_notes_highlights_recursive(node: Node) -> void:
	if node == null:
		return
	if node.has_method("refresh_generation_notes_highlights"):
		node.refresh_generation_notes_highlights()
	for child in node.get_children():
		_call_refresh_notes_highlights_recursive(child)


func _on_generation_status_mode_selected(index: int) -> void:
	if generation_status_mode_option == null:
		return
	var option_id := generation_status_mode_option.get_item_id(index)
	var mode := _status_mode_from_option_id(option_id)
	var prev := _GenStatusMode.from_settings()
	if mode == prev:
		return
	_SegmentedOptionUtils.play_segment_select_sound()
	SettingsManager.set_setting("generation_status_mode", mode)
	SettingsManager.set_setting("show_generation_notifications", mode != _GenStatusMode.OFF)
	_select_status_mode_by_id(option_id)
	# Off previously only blocked new pushes — the active StatusDock panel stayed visible.
	_apply_generation_status_mode_live(mode)
	emit_signal("settings_changed")


func _find_status_dock() -> StatusDock:
	var ge := get_tree().root.get_node_or_null("GameEngine")
	if ge and ge.has_method("get_status_dock"):
		return ge.get_status_dock() as StatusDock
	return null


func _apply_generation_status_mode_live(mode: String) -> void:
	var dock := _find_status_dock()
	if dock == null:
		return
	if mode == _GenStatusMode.OFF:
		dock.clear_immediately()


func _on_confirm_before_rerun_toggled(enabled: bool) -> void:
	SettingsManager.set_setting("generation_confirm_before_rerun", enabled)
	emit_signal("settings_changed")


func _on_notify_done_minimized_toggled(enabled: bool) -> void:
	SettingsManager.set_setting("notify_generation_done_when_minimized", enabled)
	emit_signal("settings_changed")


func _on_bulk_force_regen_toggled(enabled: bool) -> void:
	SettingsManager.set_setting("generation_bulk_force_regen", enabled)
	emit_signal("settings_changed")


func _stem_mode_from_option_id(option_id: int) -> String:
	match option_id:
		1:
			return "ttl"
		2:
			return "keep_recent"
		_:
			return "after_job"


func _option_id_for_stem_mode(mode: String) -> int:
	match String(mode).strip_edges().to_lower():
		"ttl", "ttl_15min", "15min":
			return 1
		"keep_recent", "keep_last_10", "recent":
			return 2
		_:
			return 0


func _ensure_stem_retention_option() -> void:
	if stem_retention_option == null:
		return
	if stem_retention_option.item_count == 3:
		return
	stem_retention_option.clear()
	stem_retention_option.add_item(tr("GEN_STEM_RETENTION_AFTER_JOB"), 0)
	stem_retention_option.add_item(tr("GEN_STEM_RETENTION_TTL"), 1)
	stem_retention_option.add_item(tr("GEN_STEM_RETENTION_KEEP_RECENT"), 2)


func _apply_stem_retention_labels() -> void:
	var stem_label: Label = get_node_or_null("%s/StemRetentionRow/StemRetentionLabel" % _PARAMS)
	if stem_label:
		stem_label.text = tr("GEN_STEM_RETENTION_LABEL")
	if stem_retention_hint:
		stem_retention_hint.text = tr("GEN_STEM_RETENTION_HINT")
	if stem_retention_option:
		_ensure_stem_retention_option()
		stem_retention_option.set_block_signals(true)
		if stem_retention_option.item_count >= 3:
			stem_retention_option.set_item_text(0, tr("GEN_STEM_RETENTION_AFTER_JOB"))
			stem_retention_option.set_item_text(1, tr("GEN_STEM_RETENTION_TTL"))
			stem_retention_option.set_item_text(2, tr("GEN_STEM_RETENTION_KEEP_RECENT"))
		var mode := str(SettingsManager.get_setting("generation_stem_retention_mode", "after_job"))
		for i in range(stem_retention_option.item_count):
			if stem_retention_option.get_item_id(i) == _option_id_for_stem_mode(mode):
				stem_retention_option.select(i)
				break
		stem_retention_option.set_block_signals(false)
	if stem_keep_all_checkbox:
		stem_keep_all_checkbox.text = tr("GEN_STEM_KEEP_ALL")
	_sync_stem_retention_controls_enabled()


func _apply_stem_retention_tooltips() -> void:
	var stem_label: Label = get_node_or_null("%s/StemRetentionRow/StemRetentionLabel" % _PARAMS)
	if stem_label:
		stem_label.tooltip_text = tr("GEN_STEM_RETENTION_TOOLTIP")
	if stem_retention_option:
		stem_retention_option.tooltip_text = tr("GEN_STEM_RETENTION_TOOLTIP")
	if stem_keep_all_checkbox:
		stem_keep_all_checkbox.tooltip_text = tr("GEN_STEM_KEEP_ALL_TOOLTIP")
	if stem_retention_hint:
		stem_retention_hint.tooltip_text = tr("GEN_STEM_RETENTION_HINT")


func _apply_stem_retention_settings() -> void:
	if stem_keep_all_checkbox:
		stem_keep_all_checkbox.set_pressed_no_signal(
			bool(SettingsManager.get_setting("generation_stem_keep_all", true))
		)
	if stem_retention_option:
		_ensure_stem_retention_option()
		var mode := str(SettingsManager.get_setting("generation_stem_retention_mode", "after_job"))
		stem_retention_option.set_block_signals(true)
		for i in range(stem_retention_option.item_count):
			if stem_retention_option.get_item_id(i) == _option_id_for_stem_mode(mode):
				stem_retention_option.select(i)
				break
		stem_retention_option.set_block_signals(false)
	_sync_stem_retention_controls_enabled()


func _sync_stem_retention_controls_enabled() -> void:
	var keep_all := stem_keep_all_checkbox != null and stem_keep_all_checkbox.button_pressed
	if stem_retention_option:
		stem_retention_option.disabled = keep_all


func _on_stem_retention_selected(index: int) -> void:
	if stem_retention_option == null:
		return
	var option_id := stem_retention_option.get_item_id(index)
	SettingsManager.set_setting("generation_stem_retention_mode", _stem_mode_from_option_id(option_id))
	emit_signal("settings_changed")


func _on_stem_keep_all_toggled(enabled: bool) -> void:
	SettingsManager.set_setting("generation_stem_keep_all", enabled)
	_sync_stem_retention_controls_enabled()
	emit_signal("settings_changed")


func _on_bulk_bpm_pressed() -> void:
	await _GenerationBulkQueueActions.enqueue_bpm_for_library(self, _confirm_overlay)


func _on_bulk_notes_pressed() -> void:
	await _GenerationBulkQueueActions.enqueue_notes_for_library(self, _confirm_overlay)


func _selected_gpu_mode() -> String:
	if gpu_stack_option == null:
		return "auto"
	var idx := clampi(gpu_stack_option.selected, 0, _GPU_OPTION_IDS.size() - 1)
	return str(_GPU_OPTION_IDS[idx])


func _load_gpu_scan_cache() -> void:
	_gpu_scan_loaded = false
	_recommended_gpu_mode = ""
	_gpu_scan_adapters = ""
	if SettingsManager == null:
		return
	var raw: Variant = SettingsManager.get_setting("generation_gpu_scan", {})
	if not (raw is Dictionary) or (raw as Dictionary).is_empty():
		return
	var scan: Dictionary = raw
	_gpu_scan_adapters = str(scan.get("adapters", "")).strip_edges()
	_recommended_gpu_mode = _GenerationGpuStack.normalize_mode(str(scan.get("recommended", "")))
	if _recommended_gpu_mode == "auto":
		_recommended_gpu_mode = ""
	var cached_installed := str(scan.get("installed", "")).strip_edges().to_lower()
	if cached_installed in ["nvidia", "amd", "cpu"] and _installed_gpu_mode == "":
		_installed_gpu_mode = cached_installed
	_gpu_scan_loaded = _gpu_scan_adapters != "" or _recommended_gpu_mode != "" or cached_installed != ""


func _save_gpu_scan_cache(hw: Dictionary, installed: String) -> void:
	var names: PackedStringArray = hw.get("names", PackedStringArray())
	var adapters := ", ".join(names)
	var recommended := str(hw.get("recommended", "cpu"))
	var payload := {
		"adapters": adapters,
		"recommended": recommended,
		"installed": installed,
		"has_nvidia": bool(hw.get("has_nvidia", false)),
		"has_amd": bool(hw.get("has_amd", false)),
		"unix": int(Time.get_unix_time_from_system()),
	}
	if SettingsManager:
		SettingsManager.set_setting("generation_gpu_scan", payload)
	_gpu_scan_adapters = adapters
	_recommended_gpu_mode = recommended if recommended in ["nvidia", "amd", "cpu"] else ""
	_gpu_scan_loaded = true


func _gpu_stack_already_ok(selected: String, install_mode: String = "") -> bool:
	if _installed_gpu_mode == "":
		return false
	if selected != "auto" and selected == _installed_gpu_mode:
		return true
	if selected == "auto":
		var target := install_mode
		if target == "" or target == "auto":
			target = _recommended_gpu_mode
		return target != "" and target == _installed_gpu_mode
	return false


func _update_gpu_stack_enabled() -> void:
	var local_ok := _GenerationGpuStack.is_windows() and not _GenerationGpuStack.is_lan_mode() and not _gpu_stack_busy
	if gpu_stack_option:
		gpu_stack_option.disabled = not local_ok
	for btn in _gpu_stack_seg.get("buttons", []):
		if btn is Button:
			(btn as Button).disabled = not local_ok
	if gpu_stack_scan_button:
		gpu_stack_scan_button.disabled = not local_ok
	var already := _gpu_stack_already_ok(_selected_gpu_mode())
	if gpu_stack_apply_button:
		gpu_stack_apply_button.disabled = not local_ok or already
		if already:
			gpu_stack_apply_button.tooltip_text = tr("MISC_GPU_STACK_ALREADY")
		else:
			gpu_stack_apply_button.tooltip_text = tr("MISC_GPU_STACK_TOOLTIP")


func _refresh_gpu_stack_status() -> void:
	if gpu_stack_status_label == null:
		return
	_load_gpu_scan_cache()
	if _GenerationGpuStack.is_lan_mode():
		gpu_stack_status_label.text = tr("MISC_GPU_STACK_STATUS_LAN")
		_installed_gpu_mode = ""
		_sync_gpu_stack_segment_texts()
		_update_gpu_stack_enabled()
		return
	if not _GenerationGpuStack.is_windows():
		gpu_stack_status_label.text = tr("MISC_GPU_STACK_WINDOWS_ONLY")
		_installed_gpu_mode = ""
		_sync_gpu_stack_segment_texts()
		_update_gpu_stack_enabled()
		return
	var health := {}
	if GenerationProcessManager:
		health = GenerationProcessManager.fetch_health_payload()
	var live_installed := _GenerationGpuStack.resolve_installed_mode(health)
	if live_installed != "":
		_installed_gpu_mode = live_installed
	var status := ""
	if health.get("ok", false):
		status = _GenerationGpuStack.format_backend_status(health)
	if status == "":
		status = _GenerationGpuStack.format_backend_status({})
	var lines: PackedStringArray = PackedStringArray()
	if status != "":
		lines.append(tr("MISC_GPU_STACK_STATUS_FMT") % status)
	elif _installed_gpu_mode != "":
		lines.append(tr("MISC_GPU_STACK_STATUS_FMT") % _gpu_mode_label(_installed_gpu_mode))
	else:
		lines.append(tr("MISC_GPU_STACK_STATUS_UNKNOWN"))
	if _gpu_scan_loaded:
		var rec := _gpu_mode_label(_recommended_gpu_mode) if _recommended_gpu_mode != "" else "—"
		var inst := _gpu_mode_label(_installed_gpu_mode) if _installed_gpu_mode != "" else "—"
		var adapters := _gpu_scan_adapters if _gpu_scan_adapters != "" else "—"
		lines.append(tr("MISC_GPU_STACK_SCAN_SUMMARY_FMT") % [adapters, rec, inst])
	else:
		lines.append(tr("MISC_GPU_STACK_SCAN_NEEDED"))
	gpu_stack_status_label.text = "\n".join(lines)
	_sync_gpu_stack_segment_texts()
	_update_gpu_stack_enabled()


func _gpu_mode_label(mode: String) -> String:
	if mode.strip_edges() == "":
		return "—"
	return tr(_GenerationGpuStack.mode_label_key(mode))


func _gpu_adapters_text(hw: Dictionary) -> String:
	var names: PackedStringArray = hw.get("names", PackedStringArray())
	if names.is_empty():
		return tr("MISC_GPU_STACK_DETECT_NONE")
	return tr("MISC_GPU_STACK_DETECT_ADAPTERS_FMT") % ", ".join(names)


func _gpu_selection_mismatch(selected: String, hw: Dictionary) -> bool:
	match selected:
		"nvidia":
			return not bool(hw.get("has_nvidia", false))
		"amd":
			return not bool(hw.get("has_amd", false))
		_:
			return false


func _build_gpu_stack_plan_message(selected: String, install_mode: String, hw: Dictionary) -> String:
	var adapters := _gpu_adapters_text(hw)
	var install_label := _gpu_mode_label(install_mode)
	var footer := tr("DLG_GPU_STACK_REINSTALL_FOOTER")
	if selected == "auto":
		return "%s\n%s\n\n%s\n\n%s" % [
			adapters,
			tr("MISC_GPU_STACK_DETECT_RECOMMENDED_FMT") % install_label,
			tr("DLG_GPU_STACK_PLAN_AUTO_BODY") % install_label,
			footer,
		]
	if _gpu_selection_mismatch(selected, hw):
		var expected := _gpu_mode_label(str(hw.get("recommended", "cpu")))
		return "%s\n\n%s\n\n%s" % [
			adapters,
			tr("DLG_GPU_STACK_PLAN_MISMATCH_BODY") % [_gpu_mode_label(selected), expected, install_label],
			footer,
		]
	if install_mode == "cpu":
		return "%s\n\n%s\n\n%s" % [adapters, tr("DLG_GPU_STACK_PLAN_CPU_BODY"), footer]
	return "%s\n\n%s\n\n%s" % [
		adapters,
		tr("DLG_GPU_STACK_PLAN_MATCH_BODY") % install_label,
		footer,
	]


func _run_gpu_probe_with_overlay() -> Dictionary:
	var overlay: LoadingOverlay = null
	var ge := get_tree().root.get_node_or_null("GameEngine")
	if ge and ge.has_method("get_loading_overlay"):
		overlay = ge.get_loading_overlay()
	if overlay:
		overlay.show_loading(tr("UI_LOADING_GPU_DETECT"), true)
		await get_tree().process_frame
	var hw: Dictionary = _GenerationGpuStack.detect_hardware()
	var health := {}
	if GenerationProcessManager:
		health = GenerationProcessManager.fetch_health_payload()
	var installed := _GenerationGpuStack.resolve_installed_mode(health)
	if installed == "":
		installed = _installed_gpu_mode
	_installed_gpu_mode = installed
	_save_gpu_scan_cache(hw, installed)
	if overlay:
		overlay.hide_loading()
	return hw


func _on_gpu_stack_scan_pressed() -> void:
	if _gpu_stack_busy:
		return
	if not _GenerationGpuStack.is_windows():
		_AppOverlayHelpers.notify(_notice_overlay, tr("MISC_GPU_STACK_WINDOWS_ONLY"))
		return
	if _GenerationGpuStack.is_lan_mode():
		_AppOverlayHelpers.notify(_notice_overlay, tr("MISC_GPU_STACK_LAN_BLOCKED"))
		return
	_gpu_stack_busy = true
	_update_gpu_stack_enabled()
	var hw: Dictionary = await _run_gpu_probe_with_overlay()
	_gpu_stack_busy = false
	_refresh_gpu_stack_status()
	var rec := _gpu_mode_label(str(hw.get("recommended", "cpu")))
	var inst := _gpu_mode_label(_installed_gpu_mode) if _installed_gpu_mode != "" else "—"
	var adapters := _gpu_adapters_text(hw)
	_AppOverlayHelpers.notify(
		_notice_overlay,
		tr("MISC_GPU_STACK_SCAN_DONE_FMT") % [adapters, rec, inst]
	)
	emit_signal("settings_changed")


func _on_gpu_stack_apply_pressed() -> void:
	if _gpu_stack_busy:
		return
	if not _GenerationGpuStack.is_windows():
		_AppOverlayHelpers.notify(_notice_overlay, tr("MISC_GPU_STACK_WINDOWS_ONLY"))
		return
	if _GenerationGpuStack.is_lan_mode():
		_AppOverlayHelpers.notify(_notice_overlay, tr("MISC_GPU_STACK_LAN_BLOCKED"))
		return
	var selected := _selected_gpu_mode()
	_gpu_stack_busy = true
	_update_gpu_stack_enabled()
	var hw: Dictionary = await _run_gpu_probe_with_overlay()
	_gpu_stack_busy = false
	_update_gpu_stack_enabled()

	var install_mode := selected
	if selected == "auto":
		install_mode = str(hw.get("recommended", "cpu"))

	if _gpu_stack_already_ok(selected, install_mode):
		_refresh_gpu_stack_status()
		_AppOverlayHelpers.notify(
			_notice_overlay,
			tr("MISC_GPU_STACK_ALREADY_AUTO_FMT") % _gpu_mode_label(_installed_gpu_mode)
		)
		return

	var plan_msg := _build_gpu_stack_plan_message(selected, install_mode, hw)
	var plan_title := tr("DLG_GPU_STACK_REINSTALL_TITLE")
	if _gpu_selection_mismatch(selected, hw):
		plan_title = tr("DLG_GPU_STACK_MISMATCH_TITLE")
	var accepted := await _AppOverlayHelpers.ask(
		_confirm_overlay,
		plan_msg,
		"warning" if _gpu_selection_mismatch(selected, hw) else "info",
		plan_title,
		tr("MISC_GPU_STACK_APPLY"),
		tr("BTN_CANCEL"),
	)
	if not accepted:
		_refresh_gpu_stack_status()
		return

	_gpu_stack_busy = true
	_update_gpu_stack_enabled()
	var overlay: LoadingOverlay = null
	var ge := get_tree().root.get_node_or_null("GameEngine")
	if ge and ge.has_method("get_loading_overlay"):
		overlay = ge.get_loading_overlay()
	if overlay:
		overlay.show_loading(tr("UI_LOADING_GPU_STACK"), true)
	var result: Dictionary = await _GenerationGpuStack.reinstall_async(install_mode, selected)
	if overlay:
		overlay.hide_loading()
	_gpu_stack_busy = false
	# Refresh installed from marker/health after install.
	if GenerationProcessManager:
		_installed_gpu_mode = _GenerationGpuStack.resolve_installed_mode(
			GenerationProcessManager.fetch_health_payload()
		)
	if _installed_gpu_mode == "":
		_installed_gpu_mode = install_mode if install_mode in ["nvidia", "amd", "cpu"] else ""
	_save_gpu_scan_cache(hw, _installed_gpu_mode)
	_refresh_gpu_stack_status()
	if result.get("ok", false):
		_AppOverlayHelpers.notify(_notice_overlay, tr("MISC_GPU_STACK_DONE"))
	else:
		var err_key := str(result.get("error_key", "MISC_GPU_STACK_FAILED"))
		var detail := str(result.get("detail", "")).strip_edges()
		var msg := tr(err_key)
		if detail != "":
			var clipped := detail
			if clipped.length() > 400:
				clipped = clipped.substr(clipped.length() - 400, 400)
			msg = "%s\n\n%s" % [msg, clipped]
		_AppOverlayHelpers.notify(_notice_overlay, msg)
	emit_signal("settings_changed")


func _on_generation_server_location_selected(index: int) -> void:
	var use_lan := index == 2
	var auto_worker := index == 0
	var prev_lan := bool(SettingsManager.get_setting("generation_server_use_lan_host", false))
	var prev_auto := bool(SettingsManager.get_setting("generation_auto_worker", true))
	if use_lan == prev_lan and auto_worker == prev_auto:
		return
	_SegmentedOptionUtils.play_segment_select_sound()
	SettingsManager.set_setting("generation_server_use_lan_host", use_lan)
	SettingsManager.set_setting("generation_auto_worker", auto_worker)
	_apply_generation_server_lan_visibility(use_lan)
	_select_server_location_index(index)
	_refresh_gpu_stack_status()
	emit_signal("settings_changed")


func _generation_server_insert_ipv4_dots(text: String) -> String:
	var cur := text
	var guard := 0
	while guard < 16:
		guard += 1
		var parts := cur.split(".")
		if parts.is_empty():
			break
		var last: String = parts[parts.size() - 1]
		if last.length() < 4 or not last.is_valid_int():
			break
		var oct := last.substr(0, 3)
		var rest := last.substr(3)
		if not oct.is_valid_int() or int(oct) > 255:
			break
		var rebuilt: PackedStringArray = []
		for i in range(parts.size() - 1):
			rebuilt.append(parts[i])
		rebuilt.append(oct + "." + rest)
		cur = ".".join(rebuilt)
	return cur


func _generation_server_join_dot_segments(parts: Array) -> String:
	var r := ""
	for i in parts.size():
		if i > 0:
			r += "."
		r += str(parts[i])
	return r


func _generation_server_sanitize_digit_dot_ipv4(s: String) -> String:
	if s.is_empty():
		return s
	var parts: Array = Array(s.split("."))
	if parts.is_empty():
		return s
	if parts.size() > 4:
		var trailing_dot := String(parts[parts.size() - 1]) == ""
		if trailing_dot and parts.size() == 5:
			pass
		elif trailing_dot:
			var head: Array = parts.slice(0, 4)
			head.append("")
			parts = head
		else:
			parts = parts.slice(0, 4)
	for i in parts.size():
		var seg := String(parts[i])
		if seg.is_empty():
			continue
		if seg.is_valid_int():
			parts[i] = str(clampi(int(seg), 0, 255))
	return _generation_server_join_dot_segments(parts)


func _on_generation_server_lan_host_text_changed(new_text: String) -> void:
	if _lan_host_ipv4_format_lock or generation_server_lan_host_line_edit == null:
		return
	var result := new_text
	if _StringCharUtils.is_decimal_digit_dot_only(result):
		result = _generation_server_insert_ipv4_dots(result)
		result = _generation_server_sanitize_digit_dot_ipv4(result)
	if result == new_text:
		return
	var caret := generation_server_lan_host_line_edit.caret_column
	var delta := result.length() - new_text.length()
	_lan_host_ipv4_format_lock = true
	generation_server_lan_host_line_edit.text = result
	var new_caret := caret + delta
	if new_caret < 0:
		new_caret = 0
	generation_server_lan_host_line_edit.caret_column = mini(result.length(), new_caret)
	_lan_host_ipv4_format_lock = false


func _save_generation_server_lan_host() -> void:
	if generation_server_lan_host_line_edit == null:
		return
	var raw := generation_server_lan_host_line_edit.text
	var t := raw.strip_edges()
	if _StringCharUtils.is_decimal_digit_dot_only(t):
		t = _generation_server_sanitize_digit_dot_ipv4(_generation_server_insert_ipv4_dots(t))
	if t != raw:
		_lan_host_ipv4_format_lock = true
		generation_server_lan_host_line_edit.text = t
		_lan_host_ipv4_format_lock = false
	SettingsManager.set_setting("generation_server_lan_host", t)
	emit_signal("settings_changed")


func _on_generation_server_lan_host_submitted(_new_text: String) -> void:
	_save_generation_server_lan_host()


func _on_generation_server_lan_host_focus_exited() -> void:
	_save_generation_server_lan_host()


func _on_generation_server_port_changed(value: float) -> void:
	SettingsManager.set_setting("generation_server_port", clampi(int(value), 1, 65535))
	emit_signal("settings_changed")
