# scenes/song_select/run_modifiers/tabs/params_tab_content.gd
extends VBoxContainer

const PARAM_ROW_SCENE := preload("res://scenes/song_select/run_modifiers/run_modifier_param_row.tscn")
const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const _OptionButtonPopupUtils = preload("res://logic/ui/option_button_popup_utils.gd")

const SONG_SPEED_MIN := 25.0
const SONG_SPEED_MAX := 250.0
const SONG_SPEED_STEP := 1.0
const SONG_SPEED_DEFAULT := 100.0

signal param_changed(param_id: String, value: Variant)
signal param_focused(param_id: String)
signal reset_params_pressed

@onready var _intro_label: Label = $Scroll/ParamsVBox/IntroLabel
@onready var _reset_params_btn: Button = $Scroll/ParamsVBox/IntroRow/ResetParamsBtn
@onready var _song_section_header: Label = $Scroll/ParamsVBox/SongSection/SongSectionHeader
@onready var _song_row_host: VBoxContainer = $Scroll/ParamsVBox/SongSection/SongRowHost
@onready var _scroll_section_header: Label = $Scroll/ParamsVBox/ScrollSection/ScrollSectionHeader
@onready var _scroll_section_hint: Label = $Scroll/ParamsVBox/ScrollSection/ScrollSectionHint
@onready var _fixed_scroll_check: CheckButton = $Scroll/ParamsVBox/ScrollSection/FixedScrollCheck
@onready var _scroll_mult_row_host: VBoxContainer = $Scroll/ParamsVBox/ScrollSection/ScrollMultRowHost
@onready var _scroll_row_host: VBoxContainer = $Scroll/ParamsVBox/ScrollSection/ScrollRowHost
@onready var _timing_section_header: Label = $Scroll/ParamsVBox/TimingSection/TimingSectionHeader
@onready var _timing_section_hint: Label = $Scroll/ParamsVBox/TimingSection/TimingSectionHint
@onready var _timing_row_host: VBoxContainer = $Scroll/ParamsVBox/TimingSection/TimingRowHost
@onready var _visibility_section_header: Label = $Scroll/ParamsVBox/VisibilitySection/VisibilitySectionHeader
@onready var _visibility_section_hint: Label = $Scroll/ParamsVBox/VisibilitySection/VisibilitySectionHint
@onready var _visibility_row_host: VBoxContainer = $Scroll/ParamsVBox/VisibilitySection/VisibilityRowHost
@onready var _memory_section_header: Label = $Scroll/ParamsVBox/MemorySection/MemorySectionHeader
@onready var _memory_section_hint: Label = $Scroll/ParamsVBox/MemorySection/MemorySectionHint
@onready var _memory_row_host: VBoxContainer = $Scroll/ParamsVBox/MemorySection/MemoryRowHost
@onready var _ce_section_header: Label = $Scroll/ParamsVBox/ComboEscalationSection/ComboEscalationSectionHeader
@onready var _ce_section_hint: Label = $Scroll/ParamsVBox/ComboEscalationSection/ComboEscalationSectionHint
@onready var _ce_pick_mode_label: Label = $Scroll/ParamsVBox/ComboEscalationSection/PickModeLabel
@onready var _ce_pick_mode_option: OptionButton = $Scroll/ParamsVBox/ComboEscalationSection/PickModeOption
@onready var _ce_order_section: VBoxContainer = $Scroll/ParamsVBox/ComboEscalationSection/OrderSection
@onready var _ce_order_hint: Label = $Scroll/ParamsVBox/ComboEscalationSection/OrderSection/OrderHint
@onready var _ce_order_vbox: VBoxContainer = $Scroll/ParamsVBox/ComboEscalationSection/OrderSection/OrderScroll/OrderVBox
@onready var _ce_move_up_btn: Button = $Scroll/ParamsVBox/ComboEscalationSection/OrderSection/OrderButtons/MoveUpBtn
@onready var _ce_move_down_btn: Button = $Scroll/ParamsVBox/ComboEscalationSection/OrderSection/OrderButtons/MoveDownBtn
@onready var _extra_params_host: VBoxContainer = $Scroll/ParamsVBox/ExtraParamsHost
@onready var _ce_pool_host: VBoxContainer = $Scroll/ParamsVBox/ComboEscalationSection/CePoolHost

var _rows: Dictionary = {}
var _ce_pool_checks: Dictionary = {}
var _ce_pick_modes: Array[String] = [
	_RunModifiers.CE_PICK_NO_REPEAT,
	_RunModifiers.CE_PICK_RANDOM,
	_RunModifiers.CE_PICK_CUSTOM_ORDER,
]
var _ce_order_ids: Array[String] = []
var _ce_selected_index: int = -1
var _ce_order_syncing := false


func _ready() -> void:
	if _fixed_scroll_check:
		_fixed_scroll_check.toggled.connect(_on_fixed_scroll_toggled)
	if _ce_pick_mode_option:
		_ce_pick_mode_option.item_selected.connect(_on_ce_pick_mode_selected)
	if _ce_move_up_btn:
		_ce_move_up_btn.pressed.connect(_on_ce_move_up)
	if _ce_move_down_btn:
		_ce_move_down_btn.pressed.connect(_on_ce_move_down)
	if _reset_params_btn:
		_reset_params_btn.pressed.connect(_on_reset_params_pressed)
	call_deferred("_build_default_rows")
	call_deferred("_setup_ce_pick_mode_option")
	if _ce_pick_mode_option:
		_OptionButtonPopupUtils.apply_popup_font_size(_ce_pick_mode_option, 18)


func apply_locale() -> void:
	if _intro_label:
		_intro_label.text = tr("MOD_PARAMS_INTRO")
	if _song_section_header:
		_song_section_header.text = tr("MOD_PARAM_SEC_EASING")
	if _scroll_section_header:
		_scroll_section_header.text = tr("MOD_PARAM_SCROLL_SECTION")
	if _scroll_section_hint:
		_scroll_section_hint.text = tr("MOD_PARAM_SCROLL_FROM_SETTINGS_HINT")
	if _fixed_scroll_check:
		_fixed_scroll_check.text = tr("MOD_PARAM_SCROLL_FIXED_ENABLE")
	if _timing_section_header:
		_timing_section_header.text = tr("MOD_PARAM_TIMING_SECTION")
	if _timing_section_hint:
		_timing_section_hint.text = tr("MOD_PARAM_TIMING_HINT")
	if _visibility_section_header:
		_visibility_section_header.text = tr("MOD_PARAM_VISIBILITY_SECTION")
	if _visibility_section_hint:
		_visibility_section_hint.text = tr("MOD_PARAM_VISIBILITY_HINT")
	if _memory_section_header:
		_memory_section_header.text = tr("MOD_PARAM_MEMORY_SECTION")
	if _memory_section_hint:
		_memory_section_hint.text = tr("MOD_PARAM_MEMORY_HINT")
	if _ce_section_header:
		_ce_section_header.text = tr("MOD_PARAM_CE_SECTION")
	if _ce_section_hint:
		_ce_section_hint.text = tr("MOD_PARAM_CE_HINT")
	if _ce_pick_mode_label:
		_ce_pick_mode_label.text = tr("MOD_PARAM_CE_PICK_MODE")
	if _ce_order_hint:
		_ce_order_hint.text = tr("MOD_PARAM_CE_ORDER_HINT")
	if _ce_move_up_btn:
		_ce_move_up_btn.text = tr("MOD_PARAM_CE_ORDER_UP")
	if _ce_move_down_btn:
		_ce_move_down_btn.text = tr("MOD_PARAM_CE_ORDER_DOWN")
	if _reset_params_btn:
		_reset_params_btn.text = tr("MOD_PARAM_RESET_DEFAULTS")
	_apply_row_titles()
	_update_scroll_section_visibility()
	_setup_ce_pick_mode_option()
	_rebuild_ce_order_ui()


func _apply_row_titles() -> void:
	var title_map := {
		"slow_75_speed_pct": "MOD_PARAM_SLOW_75_SPEED",
		"scroll_speed_mult_pct": "MOD_PARAM_SCROLL_MULT_VALUE",
		"scroll_speed_value": "MOD_PARAM_SCROLL_FIXED_VALUE",
		"timing_window_pct": "MOD_PARAM_TIMING_WINDOW_VALUE",
		"visibility_band_px": "MOD_PARAM_VISIBILITY_BAND_VALUE",
		"memory_reveal_ms": "MOD_PARAM_MEMORY_REVEAL_VALUE",
	}
	for param_id in title_map:
		var row = _rows.get(param_id, null)
		if row and row.has_method("set_title"):
			row.set_title(_param_title(param_id, title_map[param_id]))


func _setup_ce_pick_mode_option() -> void:
	if _ce_pick_mode_option == null:
		return
	var selected_mode := _current_ce_pick_mode()
	var labels := [
		tr("MOD_PARAM_CE_PICK_NO_REPEAT"),
		tr("MOD_PARAM_CE_PICK_RANDOM"),
		tr("MOD_PARAM_CE_PICK_CUSTOM_ORDER"),
	]
	_ce_pick_mode_option.clear()
	for i in range(_ce_pick_modes.size()):
		_ce_pick_mode_option.add_item(labels[i], i)
		_ce_pick_mode_option.set_item_metadata(i, _ce_pick_modes[i])
	var pick_idx := _ce_pick_modes.find(selected_mode)
	if pick_idx < 0:
		pick_idx = 0
	_ce_pick_mode_option.select(pick_idx)
	_update_ce_order_section_visibility()


func _current_ce_pick_mode() -> String:
	if _ce_pick_mode_option == null or _ce_pick_mode_option.item_count == 0:
		return _RunModifiers.CE_PICK_MODE_DEFAULT
	var idx := _ce_pick_mode_option.selected
	if idx < 0:
		idx = 0
	return str(_ce_pick_mode_option.get_item_metadata(idx))


func _update_ce_order_section_visibility() -> void:
	if _ce_order_section:
		_ce_order_section.visible = _current_ce_pick_mode() == _RunModifiers.CE_PICK_CUSTOM_ORDER


func _on_ce_pick_mode_selected(_index: int) -> void:
	_update_ce_order_section_visibility()
	param_changed.emit("combo_escalation_pick_mode", _current_ce_pick_mode())


func _modifier_label(modifier_id: String) -> String:
	return tr(_RunModifiers.title_i18n_key(modifier_id))


func _set_ce_order(order: Array) -> void:
	_ce_order_syncing = true
	_ce_order_ids = _RunModifiers.sanitize_combo_escalation_order(order)
	if _ce_selected_index >= _ce_order_ids.size():
		_ce_selected_index = _ce_order_ids.size() - 1
	_rebuild_ce_order_ui()
	_ce_order_syncing = false


func _get_ce_order() -> Array[String]:
	return _ce_order_ids.duplicate()


func _rebuild_ce_order_ui() -> void:
	if _ce_order_vbox == null:
		return
	for child in _ce_order_vbox.get_children():
		child.queue_free()
	for i in range(_ce_order_ids.size()):
		_ce_order_vbox.add_child(_make_ce_order_row(_ce_order_ids[i], i))


func _make_ce_order_row(modifier_id: String, index: int) -> PanelContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 36)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var selected := index == _ce_selected_index
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.12, 0.17, 0.95)
	box.border_color = Color(0.55, 0.72, 0.98, 0.72) if selected else Color(1, 1, 1, 0.08)
	box.set_border_width_all(2 if selected else 1)
	box.set_corner_radius_all(8)
	box.content_margin_left = 8
	box.content_margin_top = 6
	box.content_margin_right = 8
	box.content_margin_bottom = 6
	row.add_theme_stylebox_override("panel", box)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hbox)

	var icon_file := _RunModifiers.icon_file(modifier_id)
	var tint := _RunModifiers.category_tint(modifier_id, true)
	if icon_file.strip_edges() != "":
		hbox.add_child(UiIconHelper.make_icon_frame(icon_file, 30, 16, tint))

	var title := Label.new()
	title.text = _modifier_label(modifier_id)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.86, 0.92, 0.98, 0.98))
	hbox.add_child(title)

	row.gui_input.connect(func(event: InputEvent): _on_ce_order_row_input(index, event))
	return row


func _on_ce_order_row_input(index: int, event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_ce_selected_index = index
		_rebuild_ce_order_ui()


func _emit_ce_order_changed() -> void:
	if _ce_order_syncing:
		return
	param_changed.emit("combo_escalation_order", _get_ce_order())


func _on_ce_move_up() -> void:
	_move_ce_order_item(-1)


func _on_ce_move_down() -> void:
	_move_ce_order_item(1)


func _move_ce_order_item(delta: int) -> void:
	if _ce_order_ids.is_empty():
		return
	if _ce_selected_index < 0:
		_ce_selected_index = 0
	var to_idx := _ce_selected_index + delta
	if to_idx < 0 or to_idx >= _ce_order_ids.size():
		return
	var tmp := _ce_order_ids[_ce_selected_index]
	_ce_order_ids[_ce_selected_index] = _ce_order_ids[to_idx]
	_ce_order_ids[to_idx] = tmp
	_ce_selected_index = to_idx
	_rebuild_ce_order_ui()
	_emit_ce_order_changed()


func _param_title(param_id: String, base_key: String) -> String:
	var title := tr(base_key)
	var affects := _RunModifiers.param_affects_label(param_id)
	if affects != "":
		title += " " + affects
	return title


func _on_reset_params_pressed() -> void:
	reset_params_pressed.emit()


func reset_all_params() -> void:
	for row in _rows.values():
		if row and row.has_method("reset_to_default"):
			row.reset_to_default(false)
	if _fixed_scroll_check:
		_fixed_scroll_check.set_pressed_no_signal(false)
	_update_scroll_section_visibility()
	_set_ce_pool_enabled(_RunModifiers.default_combo_escalation_pool_enabled())
	_set_ce_order(_RunModifiers.default_combo_escalation_order())
	if _ce_pick_mode_option:
		var idx := _ce_pick_modes.find(_RunModifiers.CE_PICK_MODE_DEFAULT)
		_ce_pick_mode_option.select(maxi(idx, 0))
	_update_ce_order_section_visibility()
	param_changed.emit("reset_all", true)


func _build_default_rows() -> void:
	_add_row(
		"slow_75_speed_pct",
		_song_row_host,
		_param_title("slow_75_speed_pct", "MOD_PARAM_SLOW_75_SPEED"),
		_RunModifiers.SLOW_75_SPEED_MIN,
		_RunModifiers.SLOW_75_SPEED_MAX,
		SONG_SPEED_STEP,
		_RunModifiers.SLOW_75_SPEED_DEFAULT,
		"%"
	)
	_build_extra_param_rows()
	_build_ce_pool_checks()
	_add_row(
		"scroll_speed_mult_pct",
		_scroll_mult_row_host,
		tr("MOD_PARAM_SCROLL_MULT_VALUE"),
		_RunModifiers.SCROLL_SPEED_MULT_MIN,
		_RunModifiers.SCROLL_SPEED_MULT_MAX,
		5.0,
		_RunModifiers.SCROLL_SPEED_MULT_DEFAULT,
		"%"
	)
	_add_row(
		"scroll_speed_value",
		_scroll_row_host,
		tr("MOD_PARAM_SCROLL_FIXED_VALUE"),
		_RunModifiers.SCROLL_SPEED_VALUE_MIN,
		_RunModifiers.SCROLL_SPEED_VALUE_MAX,
		1.0,
		_RunModifiers.FIXED_SCROLL_SPEED,
		""
	)
	_add_row(
		"timing_window_pct",
		_timing_row_host,
		tr("MOD_PARAM_TIMING_WINDOW_VALUE"),
		_RunModifiers.TIMING_WINDOW_PCT_MIN,
		_RunModifiers.TIMING_WINDOW_PCT_MAX,
		5.0,
		_RunModifiers.TIMING_WINDOW_PCT_DEFAULT,
		"%"
	)
	_add_row(
		"visibility_band_px",
		_visibility_row_host,
		tr("MOD_PARAM_VISIBILITY_BAND_VALUE"),
		_RunModifiers.VISIBILITY_BAND_MIN,
		_RunModifiers.VISIBILITY_BAND_MAX,
		10.0,
		_RunModifiers.VISIBILITY_BAND_PX,
		" px"
	)
	_add_row(
		"memory_reveal_ms",
		_memory_row_host,
		tr("MOD_PARAM_MEMORY_REVEAL_VALUE"),
		_RunModifiers.MEMORY_REVEAL_MS_MIN,
		_RunModifiers.MEMORY_REVEAL_MS_MAX,
		50.0,
		_RunModifiers.MEMORY_REVEAL_MS_DEFAULT,
		" ms"
	)
	_set_ce_order(_RunModifiers.default_combo_escalation_order())
	apply_locale()


func _build_extra_param_rows() -> void:
	if _extra_params_host == null:
		return
	_add_section_label(_extra_params_host, "MOD_PARAM_SEC_HARDENING")
	_add_row_to(
		"fast_150_speed_pct", _extra_params_host, "MOD_PARAM_FAST_150_SPEED",
		_RunModifiers.FAST_150_SPEED_MIN, _RunModifiers.FAST_150_SPEED_MAX,
		_RunModifiers.FAST_150_SPEED_STEP, _RunModifiers.FAST_150_SPEED_DEFAULT, "%"
	)
	_add_row_to(
		"half_hp_start_pct", _extra_params_host, "MOD_PARAM_HALF_HP_START",
		_RunModifiers.HALF_HP_START_PCT_MIN, _RunModifiers.HALF_HP_START_PCT_MAX,
		5.0, _RunModifiers.HALF_HP_START_PCT_DEFAULT, "%"
	)
	_add_row_to(
		"memory_spatial_blind_pct", _extra_params_host, "MOD_PARAM_MEMORY_SPATIAL",
		_RunModifiers.MEMORY_SPATIAL_BLIND_PCT_MIN, _RunModifiers.MEMORY_SPATIAL_BLIND_PCT_MAX,
		1.0, _RunModifiers.MEMORY_SPATIAL_BLIND_PCT_DEFAULT, "%"
	)
	_add_row_to(
		"memory_fade_ms", _extra_params_host, "MOD_PARAM_MEMORY_FADE",
		_RunModifiers.MEMORY_FADE_MS_MIN, _RunModifiers.MEMORY_FADE_MS_MAX,
		10.0, _RunModifiers.MEMORY_FADE_MS_DEFAULT, " ms"
	)
	_add_row_to(
		"heat_step_chart_pct", _extra_params_host, "MOD_PARAM_HEAT_STEP_CHART",
		_RunModifiers.HEAT_STEP_CHART_PCT_MIN, _RunModifiers.HEAT_STEP_CHART_PCT_MAX,
		1.0, _RunModifiers.HEAT_STEP_CHART_PCT_DEFAULT, "%"
	)
	_add_row_to(
		"heat_peak_chart_pct", _extra_params_host, "MOD_PARAM_HEAT_PEAK_CHART",
		_RunModifiers.HEAT_PEAK_CHART_PCT_MIN, _RunModifiers.HEAT_PEAK_CHART_PCT_MAX,
		1.0, _RunModifiers.HEAT_PEAK_CHART_PCT_DEFAULT, "%"
	)
	_add_row_to(
		"heat_step_combo", _extra_params_host, "MOD_PARAM_HEAT_STEP_COMBO",
		float(_RunModifiers.HEAT_STEP_COMBO_MIN), float(_RunModifiers.HEAT_STEP_COMBO_MAX),
		5.0, float(_RunModifiers.HEAT_STEP_COMBO_DEFAULT), ""
	)
	_add_row_to(
		"heat_max_speed_pct", _extra_params_host, "MOD_PARAM_HEAT_MAX_SPEED",
		_RunModifiers.HEAT_MAX_SPEED_PCT_MIN, _RunModifiers.HEAT_MAX_SPEED_PCT_MAX,
		1.0, _RunModifiers.HEAT_MAX_SPEED_PCT_DEFAULT, "%"
	)
	_add_row_to(
		"heat_peak_combo", _extra_params_host, "MOD_PARAM_HEAT_PEAK_COMBO",
		float(_RunModifiers.HEAT_PEAK_COMBO_MIN), float(_RunModifiers.HEAT_PEAK_COMBO_MAX),
		5.0, float(_RunModifiers.HEAT_PEAK_COMBO_DEFAULT), ""
	)
	_add_row_to(
		"silence_interval_sec", _extra_params_host, "MOD_PARAM_SILENCE_INTERVAL",
		_RunModifiers.SILENCE_INTERVAL_SEC_MIN, _RunModifiers.SILENCE_INTERVAL_SEC_MAX,
		1.0, _RunModifiers.SILENCE_INTERVAL_SEC_DEFAULT, " s"
	)
	_add_row_to(
		"silence_duration_min_sec", _extra_params_host, "MOD_PARAM_SILENCE_DURATION_MIN",
		_RunModifiers.SILENCE_DURATION_SEC_MIN, _RunModifiers.SILENCE_DURATION_SEC_MAX,
		0.1, _RunModifiers.SILENCE_DURATION_MIN_SEC_DEFAULT, " s"
	)
	_add_row_to(
		"silence_duration_max_sec", _extra_params_host, "MOD_PARAM_SILENCE_DURATION_MAX",
		_RunModifiers.SILENCE_DURATION_SEC_MIN, _RunModifiers.SILENCE_DURATION_SEC_MAX,
		0.1, _RunModifiers.SILENCE_DURATION_MAX_SEC_DEFAULT, " s"
	)
	_add_row_to(
		"spotlight_band_px", _extra_params_host, "MOD_PARAM_SPOTLIGHT_BAND",
		_RunModifiers.SPOTLIGHT_BAND_PX_MIN, _RunModifiers.SPOTLIGHT_BAND_PX_MAX,
		10.0, _RunModifiers.SPOTLIGHT_BAND_PX_DEFAULT, " px"
	)
	_add_row_to(
		"spotlight_darkness_pct", _extra_params_host, "MOD_PARAM_SPOTLIGHT_DARKNESS",
		_RunModifiers.SPOTLIGHT_DARKNESS_PCT_MIN, _RunModifiers.SPOTLIGHT_DARKNESS_PCT_MAX,
		1.0, _RunModifiers.SPOTLIGHT_DARKNESS_PCT_DEFAULT, "%"
	)
	_add_section_label(_extra_params_host, "MOD_PARAM_SEC_SPECIAL")
	_add_row_to(
		"lane_remap_min_interval_sec", _extra_params_host, "MOD_PARAM_LANE_INTERVAL",
		_RunModifiers.LANE_REMAP_INTERVAL_MIN, _RunModifiers.LANE_REMAP_INTERVAL_MAX,
		1.0, _RunModifiers.LANE_REMAP_INTERVAL_DEFAULT, " s"
	)
	_add_row_to(
		"time_warp_min_pct", _extra_params_host, "MOD_PARAM_TIME_WARP_MIN",
		_RunModifiers.TIME_WARP_SCROLL_PCT_MIN, _RunModifiers.TIME_WARP_SCROLL_PCT_MAX,
		5.0, _RunModifiers.TIME_WARP_MIN_PCT_DEFAULT, "%"
	)
	_add_row_to(
		"time_warp_max_pct", _extra_params_host, "MOD_PARAM_TIME_WARP_MAX",
		_RunModifiers.TIME_WARP_SCROLL_PCT_MIN, _RunModifiers.TIME_WARP_SCROLL_PCT_MAX,
		5.0, _RunModifiers.TIME_WARP_MAX_PCT_DEFAULT, "%"
	)
	_add_row_to(
		"combo_escalation_step_pct", _extra_params_host, "MOD_PARAM_CE_STEP_PCT",
		_RunModifiers.CE_STEP_PCT_MIN, _RunModifiers.CE_STEP_PCT_MAX,
		1.0, _RunModifiers.CE_STEP_PCT_DEFAULT, "%"
	)
	_add_row_to(
		"combo_escalation_step_min", _extra_params_host, "MOD_PARAM_CE_STEP_MIN",
		_RunModifiers.CE_STEP_MIN_MIN, _RunModifiers.CE_STEP_MIN_MAX,
		1.0, _RunModifiers.CE_STEP_MIN_DEFAULT, ""
	)


func _add_section_label(host: VBoxContainer, key: String) -> void:
	var lbl := Label.new()
	lbl.text = tr(key)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.86, 0.92, 0.98, 1.0))
	host.add_child(lbl)


func _add_row_to(
	param_id: String,
	host: VBoxContainer,
	title_key: String,
	min_v: float,
	max_v: float,
	step: float,
	default_v: float,
	suffix: String
) -> void:
	_add_row(param_id, host, _param_title(param_id, title_key), min_v, max_v, step, default_v, suffix)


func _build_ce_pool_checks() -> void:
	if _ce_pool_host == null:
		return
	for child in _ce_pool_host.get_children():
		child.queue_free()
	_ce_pool_checks.clear()
	var lbl := Label.new()
	lbl.text = tr("MOD_PARAM_CE_POOL")
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.72, 0.8, 0.92, 0.95))
	_ce_pool_host.add_child(lbl)
	for mod_id in _RunModifiers.ESCALATION_POOL:
		var cb := CheckButton.new()
		cb.text = tr(_RunModifiers.title_i18n_key(mod_id))
		cb.add_theme_font_size_override("font_size", 16)
		cb.button_pressed = true
		cb.toggled.connect(func(_on: bool): _emit_ce_pool_changed())
		_ce_pool_host.add_child(cb)
		_ce_pool_checks[mod_id] = cb


func _set_ce_pool_enabled(enabled_ids: Array) -> void:
	var enabled: Array[String] = []
	for item in enabled_ids:
		enabled.append(str(item))
	for mod_id in _ce_pool_checks:
		var cb: CheckButton = _ce_pool_checks[mod_id]
		cb.set_pressed_no_signal(enabled.has(mod_id) or enabled.is_empty())


func _get_ce_pool_enabled() -> Array[String]:
	var out: Array[String] = []
	for mod_id in _RunModifiers.ESCALATION_POOL:
		var cb: CheckButton = _ce_pool_checks.get(mod_id, null)
		if cb and cb.button_pressed:
			out.append(mod_id)
	return out


func _emit_ce_pool_changed() -> void:
	if _get_ce_pool_enabled().is_empty():
		var first_id: String = _RunModifiers.ESCALATION_POOL[0]
		var cb: CheckButton = _ce_pool_checks.get(first_id, null)
		if cb:
			cb.set_pressed_no_signal(true)
	param_changed.emit("combo_escalation_pool_enabled", _get_ce_pool_enabled())


func _add_row(
	param_id: String,
	host: VBoxContainer,
	title: String,
	min_value: float,
	max_value: float,
	step: float,
	default_value: float,
	value_suffix: String
) -> void:
	if host == null or _rows.has(param_id):
		return
	var row := PARAM_ROW_SCENE.instantiate()
	host.add_child(row)
	row.setup(param_id, title, min_value, max_value, step, default_value, value_suffix)
	row.value_changed.connect(_on_row_changed)
	row.gui_input.connect(func(event): _on_row_focus(param_id, event))
	_rows[param_id] = row


func _on_fixed_scroll_toggled(_enabled: bool) -> void:
	_update_scroll_section_visibility()
	var fixed_on := _fixed_scroll_check.button_pressed if _fixed_scroll_check else false
	param_changed.emit("scroll_speed_mode", "fixed" if fixed_on else "settings")


func _update_scroll_section_visibility() -> void:
	var fixed_on := _fixed_scroll_check.button_pressed if _fixed_scroll_check else false
	if _scroll_row_host:
		_scroll_row_host.visible = fixed_on
	if _scroll_mult_row_host:
		_scroll_mult_row_host.visible = not fixed_on
	if _scroll_section_hint:
		_scroll_section_hint.visible = not fixed_on


func _on_row_changed(param_id: String, value: Variant) -> void:
	param_changed.emit(param_id, value)


func _on_row_focus(param_id: String, event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		param_focused.emit(param_id)


func _set_row_value(param_id: String, value: float) -> void:
	var row = _rows.get(param_id, null)
	if row:
		row.set_value(value)


func set_song_speed(value: float) -> void:
	_set_row_value("slow_75_speed_pct", value)


func set_scroll_fixed(value: int, fixed_enabled: bool) -> void:
	if _fixed_scroll_check:
		_fixed_scroll_check.set_pressed_no_signal(fixed_enabled)
	_set_row_value("scroll_speed_value", float(value))
	_update_scroll_section_visibility()


func apply_params(params: Dictionary) -> void:
	var p := _RunModifiers.sanitize_params(params)
	_set_row_value("slow_75_speed_pct", float(p.get("slow_75_speed_pct", _RunModifiers.SLOW_75_SPEED_DEFAULT)))
	_set_row_value("fast_150_speed_pct", float(p.get("fast_150_speed_pct", _RunModifiers.FAST_150_SPEED_DEFAULT)))
	_set_row_value("half_hp_start_pct", float(p.get("half_hp_start_pct", _RunModifiers.HALF_HP_START_PCT_DEFAULT)))
	_set_row_value("memory_spatial_blind_pct", float(p.get("memory_spatial_blind_pct", _RunModifiers.MEMORY_SPATIAL_BLIND_PCT_DEFAULT)))
	_set_row_value("memory_fade_ms", float(p.get("memory_fade_ms", _RunModifiers.MEMORY_FADE_MS_DEFAULT)))
	_set_row_value("lane_remap_min_interval_sec", float(p.get("lane_remap_min_interval_sec", _RunModifiers.LANE_REMAP_INTERVAL_DEFAULT)))
	_set_row_value("time_warp_min_pct", float(p.get("time_warp_min_pct", _RunModifiers.TIME_WARP_MIN_PCT_DEFAULT)))
	_set_row_value("time_warp_max_pct", float(p.get("time_warp_max_pct", _RunModifiers.TIME_WARP_MAX_PCT_DEFAULT)))
	_set_row_value("combo_escalation_step_pct", float(p.get("combo_escalation_step_pct", _RunModifiers.CE_STEP_PCT_DEFAULT)))
	_set_row_value("combo_escalation_step_min", float(p.get("combo_escalation_step_min", _RunModifiers.CE_STEP_MIN_DEFAULT)))
	var fixed_on := str(p.get("scroll_speed_mode", "settings")) == "fixed"
	set_scroll_fixed(int(p.get("scroll_speed_value", 20.0)), fixed_on)
	_set_row_value("scroll_speed_mult_pct", float(p.get("scroll_speed_mult_pct", 100.0)))
	_set_row_value("timing_window_pct", float(p.get("timing_window_pct", 100.0)))
	_set_row_value("visibility_band_px", float(p.get("visibility_band_px", 220.0)))
	_set_row_value("memory_reveal_ms", float(p.get("memory_reveal_ms", 500.0)))
	_set_row_value("heat_step_chart_pct", float(p.get("heat_step_chart_pct", _RunModifiers.HEAT_STEP_CHART_PCT_DEFAULT)))
	_set_row_value("heat_peak_chart_pct", float(p.get("heat_peak_chart_pct", _RunModifiers.HEAT_PEAK_CHART_PCT_DEFAULT)))
	_set_row_value("heat_step_combo", float(p.get("heat_step_combo", _RunModifiers.HEAT_STEP_COMBO_DEFAULT)))
	_set_row_value("heat_max_speed_pct", float(p.get("heat_max_speed_pct", _RunModifiers.HEAT_MAX_SPEED_PCT_DEFAULT)))
	_set_row_value("heat_peak_combo", float(p.get("heat_peak_combo", _RunModifiers.HEAT_PEAK_COMBO_DEFAULT)))
	_set_row_value("silence_interval_sec", float(p.get("silence_interval_sec", _RunModifiers.SILENCE_INTERVAL_SEC_DEFAULT)))
	_set_row_value("silence_duration_min_sec", float(p.get("silence_duration_min_sec", _RunModifiers.SILENCE_DURATION_MIN_SEC_DEFAULT)))
	_set_row_value("silence_duration_max_sec", float(p.get("silence_duration_max_sec", _RunModifiers.SILENCE_DURATION_MAX_SEC_DEFAULT)))
	_set_row_value("spotlight_band_px", float(p.get("spotlight_band_px", _RunModifiers.SPOTLIGHT_BAND_PX_DEFAULT)))
	_set_row_value("spotlight_darkness_pct", float(p.get("spotlight_darkness_pct", _RunModifiers.SPOTLIGHT_DARKNESS_PCT_DEFAULT)))
	_set_ce_pool_enabled(p.get("combo_escalation_pool_enabled", _RunModifiers.default_combo_escalation_pool_enabled()))
	_set_ce_order(p.get("combo_escalation_order", _RunModifiers.default_combo_escalation_order()))
	if _ce_pick_mode_option:
		var mode := str(p.get("combo_escalation_pick_mode", _RunModifiers.CE_PICK_MODE_DEFAULT))
		var pick_idx := _ce_pick_modes.find(mode)
		if pick_idx < 0:
			pick_idx = 0
		_ce_pick_mode_option.select(pick_idx)
	_update_ce_order_section_visibility()


func get_params_dict() -> Dictionary:
	var scroll_fixed := _fixed_scroll_check.button_pressed if _fixed_scroll_check else false
	return {
		"song_speed": SONG_SPEED_DEFAULT,
		"slow_75_speed_pct": _row_value("slow_75_speed_pct", _RunModifiers.SLOW_75_SPEED_DEFAULT),
		"fast_150_speed_pct": _row_value("fast_150_speed_pct", _RunModifiers.FAST_150_SPEED_DEFAULT),
		"half_hp_start_pct": _row_value("half_hp_start_pct", _RunModifiers.HALF_HP_START_PCT_DEFAULT),
		"memory_spatial_blind_pct": _row_value("memory_spatial_blind_pct", _RunModifiers.MEMORY_SPATIAL_BLIND_PCT_DEFAULT),
		"memory_fade_ms": _row_value("memory_fade_ms", _RunModifiers.MEMORY_FADE_MS_DEFAULT),
		"lane_remap_min_interval_sec": _row_value("lane_remap_min_interval_sec", _RunModifiers.LANE_REMAP_INTERVAL_DEFAULT),
		"time_warp_min_pct": _row_value("time_warp_min_pct", _RunModifiers.TIME_WARP_MIN_PCT_DEFAULT),
		"time_warp_max_pct": _row_value("time_warp_max_pct", _RunModifiers.TIME_WARP_MAX_PCT_DEFAULT),
		"combo_escalation_step_pct": _row_value("combo_escalation_step_pct", _RunModifiers.CE_STEP_PCT_DEFAULT),
		"combo_escalation_step_min": _row_value("combo_escalation_step_min", _RunModifiers.CE_STEP_MIN_DEFAULT),
		"scroll_speed_mode": "fixed" if scroll_fixed else "settings",
		"scroll_speed_value": _row_value("scroll_speed_value", 20.0),
		"scroll_speed_mult_pct": _row_value("scroll_speed_mult_pct", 100.0),
		"timing_window_pct": _row_value("timing_window_pct", 100.0),
		"visibility_band_px": _row_value("visibility_band_px", 220.0),
		"memory_reveal_ms": _row_value("memory_reveal_ms", 500.0),
		"heat_step_chart_pct": _row_value("heat_step_chart_pct", _RunModifiers.HEAT_STEP_CHART_PCT_DEFAULT),
		"heat_peak_chart_pct": _row_value("heat_peak_chart_pct", _RunModifiers.HEAT_PEAK_CHART_PCT_DEFAULT),
		"heat_step_combo": _row_value("heat_step_combo", _RunModifiers.HEAT_STEP_COMBO_DEFAULT),
		"heat_max_speed_pct": _row_value("heat_max_speed_pct", _RunModifiers.HEAT_MAX_SPEED_PCT_DEFAULT),
		"heat_peak_combo": _row_value("heat_peak_combo", _RunModifiers.HEAT_PEAK_COMBO_DEFAULT),
		"silence_interval_sec": _row_value("silence_interval_sec", _RunModifiers.SILENCE_INTERVAL_SEC_DEFAULT),
		"silence_duration_min_sec": _row_value("silence_duration_min_sec", _RunModifiers.SILENCE_DURATION_MIN_SEC_DEFAULT),
		"silence_duration_max_sec": _row_value("silence_duration_max_sec", _RunModifiers.SILENCE_DURATION_MAX_SEC_DEFAULT),
		"spotlight_band_px": _row_value("spotlight_band_px", _RunModifiers.SPOTLIGHT_BAND_PX_DEFAULT),
		"spotlight_darkness_pct": _row_value("spotlight_darkness_pct", _RunModifiers.SPOTLIGHT_DARKNESS_PCT_DEFAULT),
		"combo_escalation_pick_mode": _current_ce_pick_mode(),
		"combo_escalation_order": _get_ce_order(),
		"combo_escalation_pool_enabled": _get_ce_pool_enabled(),
	}


func _row_value(param_id: String, fallback: float) -> float:
	var row = _rows.get(param_id, null)
	if row:
		return row.get_value()
	return fallback
