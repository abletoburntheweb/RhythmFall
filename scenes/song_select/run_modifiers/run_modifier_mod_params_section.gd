# scenes/song_select/run_modifiers/run_modifier_mod_params_section.gd
extends VBoxContainer

signal param_changed(param_id: String, value: Variant)

const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const _OptionButtonPopupUtils = preload("res://logic/ui/option_button_popup_utils.gd")
const DETAIL_SLIDER_SCENE := preload("res://scenes/song_select/run_modifiers/run_modifier_detail_slider.tscn")
const CE_SETUP_DIALOG_SCENE := preload("res://scenes/song_select/run_modifiers/run_modifier_ce_setup_dialog.tscn")
const CONFIGURE_LINK_SCENE := preload("res://scenes/song_select/run_modifiers/run_modifier_configure_link.tscn")

var _modifier_id: String = ""
var _sliders: Dictionary = {}
var _ce_pick_mode_option: OptionButton = null
var _ce_configure_row: HBoxContainer = null
var _ce_order_ids: Array[String] = []
var _ce_pool_enabled: Array[String] = []
var _ce_setup_dialog: Control = null
var _ce_pick_modes: Array[String] = [
	_RunModifiers.CE_PICK_NO_REPEAT,
	_RunModifiers.CE_PICK_RANDOM,
	_RunModifiers.CE_PICK_CUSTOM_ORDER,
]
var _pitch_check: CheckButton = null
var _bool_checks: Dictionary = {}
var _silence_schedule_option: OptionButton = null
var _silence_seconds_row: VBoxContainer = null
var _silence_track_row: VBoxContainer = null
var _silence_schedule_modes: Array[String] = [
	_RunModifiers.SILENCE_SCHEDULE_SECONDS,
	_RunModifiers.SILENCE_SCHEDULE_TRACK_PCT,
]
var _heat_step_option: OptionButton = null
var _heat_combo_row: VBoxContainer = null
var _heat_chart_row: VBoxContainer = null
var _heat_step_modes: Array[String] = [
	_RunModifiers.HEAT_STEP_MODE_COMBO,
	_RunModifiers.HEAT_STEP_MODE_CHART_PCT,
]
var _rush_bars_row: VBoxContainer = null
var _rush_time_row: VBoxContainer = null


func rebuild(modifier_id: String, params: Dictionary) -> void:
	_modifier_id = modifier_id
	_clear_children()
	_sliders.clear()
	_ce_pick_mode_option = null
	_ce_configure_row = null
	_pitch_check = null
	_bool_checks.clear()
	_silence_schedule_option = null
	_silence_seconds_row = null
	_silence_track_row = null
	_heat_step_option = null
	_heat_combo_row = null
	_heat_chart_row = null
	_rush_bars_row = null
	_rush_time_row = null
	if modifier_id == "":
		return
	match modifier_id:
		_RunModifiers.ID_SLOW_75:
			_add_slider(
				"slow_75_speed_pct",
				tr("MOD_DETAIL_SPEED_MULT"),
				_RunModifiers.SLOW_75_SPEED_MIN,
				_RunModifiers.SLOW_75_SPEED_MAX,
				_RunModifiers.SLOW_75_SPEED_STEP,
				_RunModifiers.SLOW_75_SPEED_DEFAULT,
				"%",
				0.01
			)
			_apply_speed_slider_tooltip("slow_75_speed_pct")
			_build_pitch_check("slow_75_preserve_pitch", params)
		_RunModifiers.ID_FAST_150:
			_add_slider(
				"fast_150_speed_pct",
				tr("MOD_DETAIL_SPEED_MULT"),
				_RunModifiers.FAST_150_SPEED_MIN,
				_RunModifiers.FAST_150_SPEED_MAX,
				_RunModifiers.FAST_150_SPEED_STEP,
				_RunModifiers.FAST_150_SPEED_DEFAULT,
				"%",
				0.01
			)
			_apply_speed_slider_tooltip("fast_150_speed_pct")
			_build_pitch_check("fast_150_preserve_pitch", params)
		_RunModifiers.ID_FIXED_SPEED_20:
			_add_slider(
				"scroll_speed_value",
				tr("MOD_PARAM_SCROLL_FIXED_VALUE"),
				_RunModifiers.SCROLL_SPEED_VALUE_MIN,
				_RunModifiers.SCROLL_SPEED_VALUE_MAX,
				1.0,
				_RunModifiers.FIXED_SCROLL_SPEED,
				""
			)
		_RunModifiers.ID_EASY_WINDOWS:
			_add_slider(
				"easy_timing_window_pct",
				tr("MOD_PARAM_EASY_TIMING_WINDOW"),
				_RunModifiers.TIMING_WINDOW_PCT_MIN,
				_RunModifiers.TIMING_WINDOW_PCT_MAX,
				5.0,
				_RunModifiers.TIMING_WINDOW_PCT_DEFAULT,
				"%",
				1.0,
				_RunModifiers.ID_EASY_WINDOWS
			)
		_RunModifiers.ID_STRICT_TIMING:
			_add_slider(
				"strict_timing_window_pct",
				tr("MOD_PARAM_STRICT_TIMING_WINDOW"),
				_RunModifiers.TIMING_WINDOW_PCT_MIN,
				_RunModifiers.TIMING_WINDOW_PCT_MAX,
				5.0,
				_RunModifiers.TIMING_WINDOW_PCT_DEFAULT,
				"%",
				1.0,
				_RunModifiers.ID_STRICT_TIMING
			)
		_RunModifiers.ID_HIDDEN, _RunModifiers.ID_SUDDEN:
			_add_slider(
				"visibility_band_px",
				tr("MOD_PARAM_VISIBILITY_BAND_VALUE"),
				_RunModifiers.VISIBILITY_BAND_MIN,
				_RunModifiers.VISIBILITY_BAND_MAX,
				10.0,
				_RunModifiers.VISIBILITY_BAND_PX,
				" px"
			)
		_RunModifiers.ID_HALF_HP:
			_add_slider(
				"half_hp_start_pct",
				tr("MOD_PARAM_HALF_HP_START"),
				_RunModifiers.HALF_HP_START_PCT_MIN,
				_RunModifiers.HALF_HP_START_PCT_MAX,
				5.0,
				_RunModifiers.HALF_HP_START_PCT_DEFAULT,
				"%"
			)
		_RunModifiers.ID_SINGLE_LANE:
			_add_slider(
				"single_lane_count",
				tr("MOD_PARAM_SINGLE_LANE_COUNT"),
				float(_RunModifiers.SINGLE_LANE_COUNT_MIN),
				float(_RunModifiers.SINGLE_LANE_COUNT_MAX),
				1.0,
				float(_RunModifiers.SINGLE_LANE_COUNT_DEFAULT),
				""
			)
		_RunModifiers.ID_MEMORY_MODE:
			_add_slider(
				"memory_reveal_ms",
				tr("MOD_PARAM_MEMORY_REVEAL_VALUE"),
				_RunModifiers.MEMORY_REVEAL_MS_MIN,
				_RunModifiers.MEMORY_REVEAL_MS_MAX,
				50.0,
				_RunModifiers.MEMORY_REVEAL_MS_DEFAULT,
				" мс"
			)
			_add_slider(
				"memory_spatial_blind_pct",
				tr("MOD_PARAM_MEMORY_SPATIAL"),
				_RunModifiers.MEMORY_SPATIAL_BLIND_PCT_MIN,
				_RunModifiers.MEMORY_SPATIAL_BLIND_PCT_MAX,
				1.0,
				_RunModifiers.MEMORY_SPATIAL_BLIND_PCT_DEFAULT,
				"%"
			)
			_add_slider(
				"memory_fade_ms",
				tr("MOD_PARAM_MEMORY_FADE"),
				_RunModifiers.MEMORY_FADE_MS_MIN,
				_RunModifiers.MEMORY_FADE_MS_MAX,
				10.0,
				_RunModifiers.MEMORY_FADE_MS_DEFAULT,
				" мс"
			)
		_RunModifiers.ID_TIME_WARP:
			_add_slider(
				"time_warp_min_pct",
				tr("MOD_PARAM_TIME_WARP_MIN"),
				_RunModifiers.TIME_WARP_SCROLL_PCT_MIN,
				_RunModifiers.TIME_WARP_SCROLL_PCT_MAX,
				5.0,
				_RunModifiers.TIME_WARP_MIN_PCT_DEFAULT,
				"%"
			)
			_add_slider(
				"time_warp_max_pct",
				tr("MOD_PARAM_TIME_WARP_MAX"),
				_RunModifiers.TIME_WARP_SCROLL_PCT_MIN,
				_RunModifiers.TIME_WARP_SCROLL_PCT_MAX,
				5.0,
				_RunModifiers.TIME_WARP_MAX_PCT_DEFAULT,
				"%"
			)
		_RunModifiers.ID_ENERGY_PULSE:
			_add_slider(
				"energy_pulse_min_pct",
				tr("MOD_PARAM_ENERGY_PULSE_MIN"),
				_RunModifiers.TIME_WARP_SCROLL_PCT_MIN,
				_RunModifiers.TIME_WARP_SCROLL_PCT_MAX,
				5.0,
				_RunModifiers.ENERGY_PULSE_MIN_PCT_DEFAULT,
				"%"
			)
			_add_slider(
				"energy_pulse_max_pct",
				tr("MOD_PARAM_ENERGY_PULSE_MAX"),
				_RunModifiers.TIME_WARP_SCROLL_PCT_MIN,
				_RunModifiers.TIME_WARP_SCROLL_PCT_MAX,
				5.0,
				_RunModifiers.ENERGY_PULSE_MAX_PCT_DEFAULT,
				"%"
			)
		_RunModifiers.ID_DENSITY_FOCUS:
			_add_slider(
				"density_focus_scroll_pct",
				tr("MOD_PARAM_DENSITY_FOCUS_SCROLL"),
				_RunModifiers.DENSITY_FOCUS_SCROLL_PCT_MIN,
				_RunModifiers.DENSITY_FOCUS_SCROLL_PCT_MAX,
				5.0,
				_RunModifiers.DENSITY_FOCUS_SCROLL_PCT_DEFAULT,
				"%"
			)
			_add_slider(
				"density_focus_band_px",
				tr("MOD_PARAM_DENSITY_FOCUS_BAND"),
				_RunModifiers.DENSITY_FOCUS_BAND_PX_MIN,
				_RunModifiers.DENSITY_FOCUS_BAND_PX_MAX,
				10.0,
				_RunModifiers.DENSITY_FOCUS_BAND_PX_DEFAULT,
				" px"
			)
		_RunModifiers.ID_PHRASE_SHIFT:
			_add_slider(
				"phrase_shift_heat_scroll_pct",
				tr("MOD_PARAM_PHRASE_SHIFT_HEAT_SCROLL"),
				_RunModifiers.PHRASE_SHIFT_HEAT_SCROLL_PCT_MIN,
				_RunModifiers.PHRASE_SHIFT_HEAT_SCROLL_PCT_MAX,
				5.0,
				_RunModifiers.PHRASE_SHIFT_HEAT_SCROLL_PCT_DEFAULT,
				"%"
			)
			_add_slider(
				"phrase_shift_hidden_band_px",
				tr("MOD_PARAM_PHRASE_SHIFT_HIDDEN_BAND"),
				_RunModifiers.DENSITY_FOCUS_BAND_PX_MIN,
				_RunModifiers.VISIBILITY_BAND_MAX,
				10.0,
				_RunModifiers.PHRASE_SHIFT_HIDDEN_BAND_PX_DEFAULT,
				" px"
			)
		_RunModifiers.ID_GROOVE_LOCK:
			_add_slider(
				"groove_lock_scroll_pct",
				tr("MOD_PARAM_GROOVE_LOCK_SCROLL"),
				_RunModifiers.GROOVE_LOCK_SCROLL_PCT_MIN,
				_RunModifiers.GROOVE_LOCK_SCROLL_PCT_MAX,
				5.0,
				_RunModifiers.GROOVE_LOCK_SCROLL_PCT_DEFAULT,
				"%"
			)
			_add_slider(
				"groove_lock_timing_pct",
				tr("MOD_PARAM_GROOVE_LOCK_TIMING"),
				_RunModifiers.GROOVE_LOCK_TIMING_PCT_MIN,
				_RunModifiers.GROOVE_LOCK_TIMING_PCT_MAX,
				5.0,
				_RunModifiers.GROOVE_LOCK_TIMING_PCT_DEFAULT,
				"%"
			)
			_add_slider(
				"groove_lock_band_px",
				tr("MOD_PARAM_GROOVE_LOCK_BAND"),
				_RunModifiers.DENSITY_FOCUS_BAND_PX_MIN,
				_RunModifiers.VISIBILITY_BAND_MAX,
				10.0,
				_RunModifiers.GROOVE_LOCK_BAND_PX_DEFAULT,
				" px"
			)
		_RunModifiers.ID_ADAPTIVE:
			_add_slider(
				"adaptive_heat_scroll_pct",
				tr("MOD_PARAM_ADAPTIVE_HEAT_SCROLL"),
				_RunModifiers.ADAPTIVE_HEAT_SCROLL_PCT_MIN,
				_RunModifiers.ADAPTIVE_HEAT_SCROLL_PCT_MAX,
				5.0,
				_RunModifiers.ADAPTIVE_HEAT_SCROLL_PCT_DEFAULT,
				"%"
			)
			_add_slider(
				"adaptive_hidden_band_px",
				tr("MOD_PARAM_ADAPTIVE_HIDDEN_BAND"),
				_RunModifiers.DENSITY_FOCUS_BAND_PX_MIN,
				_RunModifiers.VISIBILITY_BAND_MAX,
				10.0,
				_RunModifiers.ADAPTIVE_HIDDEN_BAND_PX_DEFAULT,
				" px"
			)
			_add_slider(
				"adaptive_speed_pct",
				tr("MOD_PARAM_ADAPTIVE_SPEED"),
				_RunModifiers.ADAPTIVE_SPEED_PCT_MIN,
				_RunModifiers.ADAPTIVE_SPEED_PCT_MAX,
				5.0,
				_RunModifiers.ADAPTIVE_SPEED_PCT_DEFAULT,
				"%"
			)
		_RunModifiers.ID_DYNAMIC_LANES, _RunModifiers.ID_RANDOM_MODE:
			_add_slider(
				"lane_remap_min_interval_sec",
				tr("MOD_PARAM_LANE_INTERVAL"),
				_RunModifiers.LANE_REMAP_INTERVAL_MIN,
				_RunModifiers.LANE_REMAP_INTERVAL_MAX,
				1.0,
				_RunModifiers.LANE_REMAP_INTERVAL_DEFAULT,
				" с"
			)
		_RunModifiers.ID_COMBO_ESCALATION:
			_build_ce_block()
		_RunModifiers.ID_HEAT:
			_build_heat_block(params)
		_RunModifiers.ID_SILENCE:
			_build_silence_block(params)
		_RunModifiers.ID_SPOTLIGHT:
			_add_slider(
				"spotlight_band_px",
				tr("MOD_PARAM_SPOTLIGHT_BAND"),
				_RunModifiers.SPOTLIGHT_BAND_PX_MIN,
				_RunModifiers.SPOTLIGHT_BAND_PX_MAX,
				10.0,
				_RunModifiers.SPOTLIGHT_BAND_PX_DEFAULT,
				" px"
			)
			_add_slider(
				"spotlight_darkness_pct",
				tr("MOD_PARAM_SPOTLIGHT_DARKNESS"),
				_RunModifiers.SPOTLIGHT_DARKNESS_PCT_MIN,
				_RunModifiers.SPOTLIGHT_DARKNESS_PCT_MAX,
				1.0,
				_RunModifiers.SPOTLIGHT_DARKNESS_PCT_DEFAULT,
				"%"
			)
		_RunModifiers.ID_RUSH:
			_build_rush_block(params)
		_RunModifiers.ID_ENERGY_BALANCE:
			_add_slider(
				"energy_balance_calm_pct",
				tr("MOD_PARAM_ENERGY_BALANCE_CALM"),
				_RunModifiers.ENERGY_BALANCE_CALM_PCT_MIN,
				_RunModifiers.ENERGY_BALANCE_CALM_PCT_MAX,
				5.0,
				_RunModifiers.ENERGY_BALANCE_CALM_PCT_DEFAULT,
				"%",
				1.0,
				_RunModifiers.ID_ENERGY_BALANCE
			)
			_add_slider(
				"energy_balance_intense_pct",
				tr("MOD_PARAM_ENERGY_BALANCE_INTENSE"),
				_RunModifiers.ENERGY_BALANCE_INTENSE_PCT_MIN,
				_RunModifiers.ENERGY_BALANCE_INTENSE_PCT_MAX,
				5.0,
				_RunModifiers.ENERGY_BALANCE_INTENSE_PCT_DEFAULT,
				"%",
				1.0,
				_RunModifiers.ID_ENERGY_BALANCE
			)
		_RunModifiers.ID_GROOVE_ADDICTION:
			_add_slider(
				"groove_addiction_scroll_pct",
				tr("MOD_PARAM_GROOVE_ADDICTION_SCROLL"),
				_RunModifiers.GROOVE_ADDICTION_SCROLL_PCT_MIN,
				_RunModifiers.GROOVE_ADDICTION_SCROLL_PCT_MAX,
				5.0,
				_RunModifiers.GROOVE_ADDICTION_SCROLL_PCT_DEFAULT,
				"%"
			)
			_add_slider(
				"groove_addiction_timing_pct",
				tr("MOD_PARAM_GROOVE_ADDICTION_TIMING"),
				_RunModifiers.GROOVE_ADDICTION_TIMING_PCT_MIN,
				_RunModifiers.GROOVE_ADDICTION_TIMING_PCT_MAX,
				5.0,
				_RunModifiers.GROOVE_ADDICTION_TIMING_PCT_DEFAULT,
				"%"
			)
			_add_slider(
				"groove_addiction_max_tier",
				tr("MOD_PARAM_GROOVE_ADDICTION_MAX_TIER"),
				float(_RunModifiers.GROOVE_ADDICTION_MAX_TIER_MIN),
				float(_RunModifiers.GROOVE_ADDICTION_MAX_TIER_MAX),
				1.0,
				float(_RunModifiers.GROOVE_ADDICTION_MAX_TIER_DEFAULT),
				""
			)
	apply_params(params)


func apply_params(params: Dictionary) -> void:
	var p := _RunModifiers.sanitize_params(params)
	for param_id in _sliders:
		var slider = _sliders[param_id]
		if slider and p.has(param_id):
			slider.set_value(float(p[param_id]))
	if _pitch_check:
		var key := str(_pitch_check.get_meta("param_id", ""))
		if p.has(key):
			_pitch_check.set_pressed_no_signal(bool(p[key]))
	for param_id in _bool_checks:
		var cb: CheckButton = _bool_checks[param_id]
		if cb and p.has(param_id):
			cb.set_pressed_no_signal(bool(p[param_id]))
	if _silence_schedule_option:
		var mode := str(p.get("silence_schedule_mode", _RunModifiers.SILENCE_SCHEDULE_MODE_DEFAULT))
		var idx := _silence_schedule_modes.find(mode)
		_silence_schedule_option.select(maxi(idx, 0))
		_update_silence_schedule_visibility()
	if _heat_step_option:
		var heat_mode := str(p.get("heat_step_mode", _RunModifiers.HEAT_STEP_MODE_DEFAULT))
		var heat_idx := _heat_step_modes.find(heat_mode)
		_heat_step_option.select(maxi(heat_idx, 0))
		_update_heat_step_visibility()
	_update_rush_mode_visibility()
	if _ce_pick_mode_option:
		var mode := str(p.get("combo_escalation_pick_mode", _RunModifiers.CE_PICK_MODE_DEFAULT))
		var idx := _ce_pick_modes.find(mode)
		_ce_pick_mode_option.select(maxi(idx, 0))
		_update_ce_configure_visibility()
	_set_ce_order(p.get("combo_escalation_order", _RunModifiers.default_combo_escalation_order()))
	_set_ce_pool_enabled(p.get("combo_escalation_pool_enabled", _RunModifiers.default_combo_escalation_pool_enabled()))


func _clear_children() -> void:
	for child in get_children():
		child.queue_free()


func _add_slider(
	param_id: String,
	title: String,
	min_v: float,
	max_v: float,
	step: float,
	default_v: float,
	suffix: String,
	display_mult: float = 1.0,
	timing_modifier_id: String = "",
	hits_suffix: bool = false,
	host: VBoxContainer = null
) -> void:
	var target: Node = host if host else self
	var block := DETAIL_SLIDER_SCENE.instantiate()
	target.add_child(block)
	block.setup(
		param_id,
		title,
		min_v,
		max_v,
		step,
		default_v,
		suffix,
		display_mult,
		timing_modifier_id,
		hits_suffix
	)
	block.value_changed.connect(_on_slider_changed)
	_sliders[param_id] = block


func _apply_speed_slider_tooltip(param_id: String) -> void:
	var block = _sliders.get(param_id, null)
	if block and block.has_method("set_hint_tooltip"):
		block.set_hint_tooltip(tr("MOD_DETAIL_SPEED_MULT_TIP"))


func _build_heat_block(_params: Dictionary) -> void:
	var mode_lbl := Label.new()
	mode_lbl.text = tr("MOD_PARAM_HEAT_STEP_MODE")
	mode_lbl.add_theme_font_size_override("font_size", 14)
	add_child(mode_lbl)
	_heat_step_option = OptionButton.new()
	_heat_step_option.add_theme_font_size_override("font_size", 16)
	_heat_step_option.add_item(tr("MOD_PARAM_HEAT_STEP_COMBO"))
	_heat_step_option.set_item_metadata(0, _RunModifiers.HEAT_STEP_MODE_COMBO)
	_heat_step_option.add_item(tr("MOD_PARAM_HEAT_STEP_CHART"))
	_heat_step_option.set_item_metadata(1, _RunModifiers.HEAT_STEP_MODE_CHART_PCT)
	_heat_step_option.item_selected.connect(_on_heat_step_selected)
	add_child(_heat_step_option)
	call_deferred("_setup_heat_step_option")

	_heat_combo_row = VBoxContainer.new()
	add_child(_heat_combo_row)
	_add_slider(
		"heat_step_combo",
		tr("MOD_PARAM_HEAT_STEP_COMBO"),
		float(_RunModifiers.HEAT_STEP_COMBO_MIN),
		float(_RunModifiers.HEAT_STEP_COMBO_MAX),
		5.0,
		float(_RunModifiers.HEAT_STEP_COMBO_DEFAULT),
		"",
		1.0,
		"",
		false,
		_heat_combo_row
	)
	_add_slider(
		"heat_peak_combo",
		tr("MOD_PARAM_HEAT_PEAK_COMBO"),
		float(_RunModifiers.HEAT_PEAK_COMBO_MIN),
		float(_RunModifiers.HEAT_PEAK_COMBO_MAX),
		5.0,
		float(_RunModifiers.HEAT_PEAK_COMBO_DEFAULT),
		"",
		1.0,
		"",
		false,
		_heat_combo_row
	)

	_heat_chart_row = VBoxContainer.new()
	add_child(_heat_chart_row)
	_add_slider(
		"heat_step_chart_pct",
		tr("MOD_PARAM_HEAT_STEP_CHART"),
		_RunModifiers.HEAT_STEP_CHART_PCT_MIN,
		_RunModifiers.HEAT_STEP_CHART_PCT_MAX,
		1.0,
		_RunModifiers.HEAT_STEP_CHART_PCT_DEFAULT,
		"%",
		1.0,
		"",
		false,
		_heat_chart_row
	)
	_add_slider(
		"heat_peak_chart_pct",
		tr("MOD_PARAM_HEAT_PEAK_CHART"),
		_RunModifiers.HEAT_PEAK_CHART_PCT_MIN,
		_RunModifiers.HEAT_PEAK_CHART_PCT_MAX,
		1.0,
		_RunModifiers.HEAT_PEAK_CHART_PCT_DEFAULT,
		"%",
		1.0,
		"",
		false,
		_heat_chart_row
	)

	_add_slider(
		"heat_max_speed_pct",
		tr("MOD_PARAM_HEAT_MAX_SPEED"),
		_RunModifiers.HEAT_MAX_SPEED_PCT_MIN,
		_RunModifiers.HEAT_MAX_SPEED_PCT_MAX,
		1.0,
		_RunModifiers.HEAT_MAX_SPEED_PCT_DEFAULT,
		"%"
	)
	_build_bool_check("heat_affect_song_speed", tr("MOD_PARAM_HEAT_AFFECT_SONG"), _params)
	_build_pitch_check("heat_preserve_pitch", _params)
	_update_heat_step_visibility()


func _setup_heat_step_option() -> void:
	if _heat_step_option:
		_OptionButtonPopupUtils.apply_popup_font_size(_heat_step_option, 16)


func _current_heat_step_mode() -> String:
	if _heat_step_option == null or _heat_step_option.item_count == 0:
		return _RunModifiers.HEAT_STEP_MODE_DEFAULT
	var idx := _heat_step_option.selected
	if idx < 0:
		return _RunModifiers.HEAT_STEP_MODE_DEFAULT
	return str(_heat_step_option.get_item_metadata(idx))


func _on_heat_step_selected(_idx: int) -> void:
	_update_heat_step_visibility()
	param_changed.emit("heat_step_mode", _current_heat_step_mode())


func _update_heat_step_visibility() -> void:
	var chart := _current_heat_step_mode() == _RunModifiers.HEAT_STEP_MODE_CHART_PCT
	if _heat_combo_row:
		_heat_combo_row.visible = not chart
	if _heat_chart_row:
		_heat_chart_row.visible = chart


func _build_silence_block(params: Dictionary) -> void:
	var mode_lbl := Label.new()
	mode_lbl.text = tr("MOD_PARAM_SILENCE_SCHEDULE_MODE")
	mode_lbl.add_theme_font_size_override("font_size", 14)
	add_child(mode_lbl)
	_silence_schedule_option = OptionButton.new()
	_silence_schedule_option.add_theme_font_size_override("font_size", 16)
	_silence_schedule_option.add_item(tr("MOD_PARAM_SILENCE_SCHEDULE_SECONDS"))
	_silence_schedule_option.set_item_metadata(0, _RunModifiers.SILENCE_SCHEDULE_SECONDS)
	_silence_schedule_option.add_item(tr("MOD_PARAM_SILENCE_SCHEDULE_TRACK"))
	_silence_schedule_option.set_item_metadata(1, _RunModifiers.SILENCE_SCHEDULE_TRACK_PCT)
	_silence_schedule_option.item_selected.connect(_on_silence_schedule_selected)
	add_child(_silence_schedule_option)
	call_deferred("_setup_silence_schedule_option")

	_silence_seconds_row = VBoxContainer.new()
	add_child(_silence_seconds_row)
	_add_slider(
		"silence_interval_sec",
		tr("MOD_PARAM_SILENCE_INTERVAL"),
		_RunModifiers.SILENCE_INTERVAL_SEC_MIN,
		_RunModifiers.SILENCE_INTERVAL_SEC_MAX,
		1.0,
		_RunModifiers.SILENCE_INTERVAL_SEC_DEFAULT,
		" с",
		1.0,
		"",
		false,
		_silence_seconds_row
	)

	_silence_track_row = VBoxContainer.new()
	add_child(_silence_track_row)
	_add_slider(
		"silence_interval_track_pct",
		tr("MOD_PARAM_SILENCE_INTERVAL_TRACK"),
		_RunModifiers.SILENCE_INTERVAL_TRACK_PCT_MIN,
		_RunModifiers.SILENCE_INTERVAL_TRACK_PCT_MAX,
		1.0,
		_RunModifiers.SILENCE_INTERVAL_TRACK_PCT_DEFAULT,
		"%",
		1.0,
		"",
		false,
		_silence_track_row
	)

	_add_slider(
		"silence_duration_min_sec",
		tr("MOD_PARAM_SILENCE_DURATION_MIN"),
		_RunModifiers.SILENCE_DURATION_SEC_MIN,
		_RunModifiers.SILENCE_DURATION_SEC_MAX,
		0.1,
		_RunModifiers.SILENCE_DURATION_MIN_SEC_DEFAULT,
		" с"
	)
	_add_slider(
		"silence_duration_max_sec",
		tr("MOD_PARAM_SILENCE_DURATION_MAX"),
		_RunModifiers.SILENCE_DURATION_SEC_MIN,
		_RunModifiers.SILENCE_DURATION_SEC_MAX,
		0.1,
		_RunModifiers.SILENCE_DURATION_MAX_SEC_DEFAULT,
		" с"
	)
	_build_bool_check("silence_metronome", "MOD_PARAM_SILENCE_METRONOME", params)
	_update_silence_schedule_visibility()


func _setup_silence_schedule_option() -> void:
	if _silence_schedule_option:
		_OptionButtonPopupUtils.apply_popup_font_size(_silence_schedule_option, 16)


func _current_silence_schedule_mode() -> String:
	if _silence_schedule_option == null or _silence_schedule_option.item_count == 0:
		return _RunModifiers.SILENCE_SCHEDULE_MODE_DEFAULT
	var idx := _silence_schedule_option.selected
	if idx < 0:
		idx = 0
	return str(_silence_schedule_option.get_item_metadata(idx))


func _on_silence_schedule_selected(_idx: int) -> void:
	_update_silence_schedule_visibility()
	param_changed.emit("silence_schedule_mode", _current_silence_schedule_mode())


func _update_silence_schedule_visibility() -> void:
	var track := _current_silence_schedule_mode() == _RunModifiers.SILENCE_SCHEDULE_TRACK_PCT
	if _silence_seconds_row:
		_silence_seconds_row.visible = not track
	if _silence_track_row:
		_silence_track_row.visible = track


func _build_rush_block(params: Dictionary) -> void:
	_build_bool_check("rush_bar_mode", tr("MOD_PARAM_RUSH_BAR_MODE"), params, true)
	var bar_cb: CheckButton = _bool_checks.get("rush_bar_mode", null)
	if bar_cb:
		bar_cb.toggled.connect(_on_rush_bar_mode_toggled)

	_rush_bars_row = VBoxContainer.new()
	add_child(_rush_bars_row)
	_add_slider(
		"rush_bars_interval",
		tr("MOD_PARAM_RUSH_BARS_INTERVAL"),
		_RunModifiers.RUSH_BARS_INTERVAL_MIN,
		_RunModifiers.RUSH_BARS_INTERVAL_MAX,
		1.0,
		_RunModifiers.RUSH_BARS_INTERVAL_DEFAULT,
		"",
		1.0,
		"",
		false,
		_rush_bars_row
	)
	_add_slider(
		"rush_first_bar",
		tr("MOD_PARAM_RUSH_FIRST_BAR"),
		_RunModifiers.RUSH_FIRST_BAR_MIN,
		_RunModifiers.RUSH_FIRST_BAR_MAX,
		1.0,
		_RunModifiers.RUSH_FIRST_BAR_DEFAULT,
		"",
		1.0,
		"",
		false,
		_rush_bars_row
	)
	_add_slider(
		"rush_scroll_pct_bars",
		tr("MOD_PARAM_RUSH_SCROLL_BARS"),
		_RunModifiers.RUSH_SCROLL_PCT_MIN,
		_RunModifiers.RUSH_SCROLL_PCT_MAX,
		5.0,
		_RunModifiers.RUSH_SCROLL_PCT_BARS_DEFAULT,
		"%",
		1.0,
		"",
		false,
		_rush_bars_row
	)

	_rush_time_row = VBoxContainer.new()
	add_child(_rush_time_row)
	_add_slider(
		"rush_time_interval_min_sec",
		tr("MOD_PARAM_RUSH_TIME_INTERVAL_MIN"),
		_RunModifiers.RUSH_TIME_INTERVAL_MIN_MIN,
		_RunModifiers.RUSH_TIME_INTERVAL_MIN_MAX,
		1.0,
		_RunModifiers.RUSH_TIME_INTERVAL_MIN_DEFAULT,
		" с",
		1.0,
		"",
		false,
		_rush_time_row
	)
	_add_slider(
		"rush_time_interval_max_sec",
		tr("MOD_PARAM_RUSH_TIME_INTERVAL_MAX"),
		_RunModifiers.RUSH_TIME_INTERVAL_MAX_MIN,
		_RunModifiers.RUSH_TIME_INTERVAL_MAX_MAX,
		1.0,
		_RunModifiers.RUSH_TIME_INTERVAL_MAX_DEFAULT,
		" с",
		1.0,
		"",
		false,
		_rush_time_row
	)
	_add_slider(
		"rush_scroll_pct_time",
		tr("MOD_PARAM_RUSH_SCROLL_TIME"),
		_RunModifiers.RUSH_SCROLL_PCT_MIN,
		_RunModifiers.RUSH_SCROLL_PCT_MAX,
		5.0,
		_RunModifiers.RUSH_SCROLL_PCT_TIME_DEFAULT,
		"%",
		1.0,
		"",
		false,
		_rush_time_row
	)

	_add_slider(
		"rush_burst_duration_sec",
		tr("MOD_PARAM_RUSH_BURST_DURATION"),
		_RunModifiers.RUSH_BURST_DURATION_SEC_MIN,
		_RunModifiers.RUSH_BURST_DURATION_SEC_MAX,
		0.25,
		_RunModifiers.RUSH_BURST_DURATION_SEC_DEFAULT,
		" с"
	)
	_add_slider(
		"rush_ramp_sec",
		tr("MOD_PARAM_RUSH_RAMP"),
		_RunModifiers.RUSH_RAMP_SEC_MIN,
		_RunModifiers.RUSH_RAMP_SEC_MAX,
		0.05,
		_RunModifiers.RUSH_RAMP_SEC_DEFAULT,
		" с"
	)
	_build_bool_check("rush_affect_song_speed", tr("MOD_PARAM_RUSH_AFFECT_SONG"), params)
	_build_pitch_check("rush_preserve_pitch", params)
	_update_rush_mode_visibility()


func _on_rush_bar_mode_toggled(_on: bool) -> void:
	_update_rush_mode_visibility()


func _update_rush_mode_visibility() -> void:
	var bar_mode := true
	if _bool_checks.has("rush_bar_mode"):
		bar_mode = bool(_bool_checks["rush_bar_mode"].button_pressed)
	if _rush_bars_row:
		_rush_bars_row.visible = bar_mode
	if _rush_time_row:
		_rush_time_row.visible = not bar_mode


func _build_bool_check(param_id: String, label_key: String, params: Dictionary, default_on: bool = false) -> void:
	var cb := CheckButton.new()
	cb.text = tr(label_key)
	cb.add_theme_font_size_override("font_size", 15)
	cb.set_meta("param_id", param_id)
	cb.set_pressed_no_signal(bool(_RunModifiers.sanitize_params(params).get(param_id, default_on)))
	cb.toggled.connect(func(on: bool): param_changed.emit(param_id, on))
	add_child(cb)
	_bool_checks[param_id] = cb


func _build_pitch_check(param_id: String, params: Dictionary) -> void:
	var cb := CheckButton.new()
	cb.text = tr("MOD_DETAIL_PRESERVE_PITCH")
	cb.tooltip_text = tr("MOD_DETAIL_PRESERVE_PITCH_TIP")
	cb.add_theme_font_size_override("font_size", 15)
	cb.set_meta("param_id", param_id)
	var default_on := param_id in ["heat_preserve_pitch", "rush_preserve_pitch"]
	cb.set_pressed_no_signal(
		bool(_RunModifiers.sanitize_params(params).get(param_id, default_on))
	)
	cb.toggled.connect(func(on: bool): param_changed.emit(param_id, on))
	add_child(cb)
	_pitch_check = cb


func _build_ce_block() -> void:
	_add_slider(
		"combo_escalation_step_pct",
		tr("MOD_PARAM_CE_STEP_PCT"),
		_RunModifiers.CE_STEP_PCT_MIN,
		_RunModifiers.CE_STEP_PCT_MAX,
		1.0,
		_RunModifiers.CE_STEP_PCT_DEFAULT,
		"%"
	)
	_add_slider(
		"combo_escalation_step_min",
		tr("MOD_PARAM_CE_STEP_MIN"),
		_RunModifiers.CE_STEP_MIN_MIN,
		_RunModifiers.CE_STEP_MIN_MAX,
		1.0,
		_RunModifiers.CE_STEP_MIN_DEFAULT,
		"",
		1.0,
		"",
		true
	)
	var pick_lbl := Label.new()
	pick_lbl.text = tr("MOD_PARAM_CE_PICK_MODE")
	pick_lbl.add_theme_font_size_override("font_size", 14)
	add_child(pick_lbl)
	_ce_pick_mode_option = OptionButton.new()
	_ce_pick_mode_option.add_theme_font_size_override("font_size", 16)
	for mode in _ce_pick_modes:
		match mode:
			_RunModifiers.CE_PICK_NO_REPEAT:
				_ce_pick_mode_option.add_item(tr("MOD_PARAM_CE_PICK_NO_REPEAT"))
			_RunModifiers.CE_PICK_RANDOM:
				_ce_pick_mode_option.add_item(tr("MOD_PARAM_CE_PICK_RANDOM"))
			_RunModifiers.CE_PICK_CUSTOM_ORDER:
				_ce_pick_mode_option.add_item(tr("MOD_PARAM_CE_PICK_CUSTOM_ORDER"))
	_ce_pick_mode_option.item_selected.connect(_on_ce_pick_mode_selected)
	add_child(_ce_pick_mode_option)
	call_deferred("_setup_ce_pick_mode_option")
	_ce_configure_row = HBoxContainer.new()
	add_child(_ce_configure_row)
	var configure_hint := Label.new()
	configure_hint.text = tr("MOD_PARAM_CE_SETUP_HINT")
	configure_hint.add_theme_font_size_override("font_size", 13)
	configure_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	configure_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ce_configure_row.add_child(configure_hint)
	var configure_link: LinkButton = CONFIGURE_LINK_SCENE.instantiate()
	configure_link.text = tr("MOD_PARAM_CE_CONFIGURE_ORDER")
	configure_link.pressed.connect(_open_ce_setup_dialog)
	_ce_configure_row.add_child(configure_link)


func _on_slider_changed(param_id: String, value: Variant) -> void:
	param_changed.emit(param_id, value)


func _setup_ce_pick_mode_option() -> void:
	if _ce_pick_mode_option:
		_OptionButtonPopupUtils.apply_popup_font_size(_ce_pick_mode_option, 16)


func _on_ce_pick_mode_selected(_idx: int) -> void:
	_update_ce_configure_visibility()
	param_changed.emit("combo_escalation_pick_mode", _current_ce_pick_mode())


func _current_ce_pick_mode() -> String:
	if _ce_pick_mode_option == null:
		return _RunModifiers.CE_PICK_MODE_DEFAULT
	var idx := _ce_pick_mode_option.selected
	if idx < 0 or idx >= _ce_pick_modes.size():
		return _RunModifiers.CE_PICK_MODE_DEFAULT
	return _ce_pick_modes[idx]


func _update_ce_configure_visibility() -> void:
	if _ce_configure_row == null or _ce_configure_row.get_child_count() == 0:
		return
	var hint := _ce_configure_row.get_child(0)
	if hint is Label:
		if _current_ce_pick_mode() == _RunModifiers.CE_PICK_CUSTOM_ORDER:
			(hint as Label).text = tr("MOD_PARAM_CE_SETUP_HINT")
		else:
			(hint as Label).text = tr("MOD_PARAM_CE_POOL_HINT")


func _set_ce_order(order: Variant) -> void:
	_ce_order_ids = _RunModifiers.sanitize_combo_escalation_order(order)


func _set_ce_pool_enabled(enabled_ids: Variant) -> void:
	_ce_pool_enabled = _RunModifiers.sanitize_combo_escalation_pool_enabled(enabled_ids)


func _ensure_ce_setup_dialog() -> void:
	if _ce_setup_dialog != null:
		return
	_ce_setup_dialog = CE_SETUP_DIALOG_SCENE.instantiate()
	get_tree().root.add_child(_ce_setup_dialog)
	_ce_setup_dialog.setup_confirmed.connect(_on_ce_setup_dialog_confirmed)


func _open_ce_setup_dialog() -> void:
	_ensure_ce_setup_dialog()
	_ce_setup_dialog.open_with(_ce_order_ids, _ce_pool_enabled, _current_ce_pick_mode())


func _on_ce_setup_dialog_confirmed(order: Array, pool_enabled: Array) -> void:
	_ce_order_ids = _RunModifiers.sanitize_combo_escalation_order(order)
	_ce_pool_enabled = _RunModifiers.sanitize_combo_escalation_pool_enabled(pool_enabled)
	param_changed.emit("combo_escalation_order", _ce_order_ids.duplicate())
	param_changed.emit("combo_escalation_pool_enabled", _ce_pool_enabled.duplicate())
