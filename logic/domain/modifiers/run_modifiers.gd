# logic/domain/modifiers/run_modifiers.gd
extends RefCounted
class_name RunModifiers

const _LaneRemap = preload("res://logic/domain/rhythm/lane_remap.gd")
const _EnergyPulseSchedule = preload("res://logic/domain/rhythm/energy_pulse_schedule.gd")
const _DensityFocusSchedule = preload("res://logic/domain/rhythm/density_focus_schedule.gd")
const _DnaVirtualEffects = preload("res://logic/domain/rhythm/dna_virtual_effects.gd")
const _RushScrollSchedule = preload("res://logic/domain/rhythm/rush_scroll_schedule.gd")
const _EnergyBalanceSchedule = preload("res://logic/domain/rhythm/energy_balance_schedule.gd")

const ID_SLOW_75 := "slow_75"
const ID_FAST_150 := "fast_150"
const ID_NO_FAIL := "no_fail"
const ID_EASY_WINDOWS := "easy_windows"
const ID_STRICT_TIMING := "strict_timing"
const ID_NO_MISS_FORGIVENESS := "no_miss_forgiveness"
const ID_SUDDEN_DEATH := "sudden_death"
const ID_FIXED_SPEED_20 := "fixed_speed_20"
const ID_AUTOPLAY := "autoplay"
const ID_HIDDEN := "hidden"
const ID_SUDDEN := "sudden"
const ID_HALF_HP := "half_hp"
const ID_SINGLE_LANE := "single_lane"
const ID_TIME_WARP := "time_warp"
const ID_PICK_MODE := "pick_mode"
const ID_REVERSE_SCROLL := "reverse_scroll"
const ID_MEMORY_MODE := "memory_mode"
const ID_DYNAMIC_LANES := "dynamic_lanes"
const ID_ENERGY_PULSE := "energy_pulse"
const ID_DENSITY_FOCUS := "density_focus"
const ID_PHRASE_SHIFT := "phrase_shift"
const ID_GROOVE_LOCK := "groove_lock"
const ID_ADAPTIVE := "adaptive"
const ID_MIRROR_MODE := "mirror_mode"
const ID_SHUFFLE_MODE := "shuffle_mode"
const ID_RANDOM_MODE := "random_mode"
const ID_COMBO_ESCALATION := "combo_escalation"
const ID_METRONOME_ONLY := "metronome_only"
const ID_HEAT := "heat"
const ID_SPOTLIGHT := "spotlight"
const ID_SILENCE := "silence"
const ID_RUSH := "rush"
const ID_LAST_CHANCE := "last_chance"
const ID_GROOVE_ADDICTION := "groove_addiction"
const ID_ENERGY_BALANCE := "energy_balance"
const SONG_SPEED_DEFAULT := 100.0
const SONG_SPEED_MIN := 25.0
const SONG_SPEED_MAX := 250.0
const SCROLL_SPEED_VALUE_MIN := 8.0
const SCROLL_SPEED_VALUE_MAX := 40.0
const TIME_WARP_PLAYBACK_MIN := 1.0
const TIME_WARP_PLAYBACK_MAX := 2.0

const ALL_IDS: Array[String] = [
	ID_SLOW_75,
	ID_FAST_150,
	ID_NO_FAIL,
	ID_EASY_WINDOWS,
	ID_STRICT_TIMING,
	ID_NO_MISS_FORGIVENESS,
	ID_SUDDEN_DEATH,
	ID_FIXED_SPEED_20,
	ID_AUTOPLAY,
	ID_HIDDEN,
	ID_SUDDEN,
	ID_HALF_HP,
	ID_SINGLE_LANE,
	ID_TIME_WARP,
	ID_PICK_MODE,
	ID_REVERSE_SCROLL,
	ID_MEMORY_MODE,
	ID_DYNAMIC_LANES,
	ID_ENERGY_PULSE,
	ID_DENSITY_FOCUS,
	ID_PHRASE_SHIFT,
	ID_GROOVE_LOCK,
	ID_ADAPTIVE,
	ID_MIRROR_MODE,
	ID_SHUFFLE_MODE,
	ID_RANDOM_MODE,
	ID_COMBO_ESCALATION,
	ID_METRONOME_ONLY,
	ID_HEAT,
	ID_SPOTLIGHT,
	ID_SILENCE,
	ID_RUSH,
	ID_LAST_CHANCE,
	ID_GROOVE_ADDICTION,
	ID_ENERGY_BALANCE,
]

const EASING_IDS: Array[String] = [ID_SLOW_75, ID_NO_FAIL, ID_EASY_WINDOWS]
const HARDENING_IDS: Array[String] = [
	ID_FAST_150,
	ID_STRICT_TIMING,
	ID_NO_MISS_FORGIVENESS,
	ID_SUDDEN_DEATH,
	ID_HIDDEN,
	ID_SUDDEN,
	ID_HALF_HP,
	ID_MEMORY_MODE,
	ID_MIRROR_MODE,
	ID_SHUFFLE_MODE,
	ID_RANDOM_MODE,
	ID_HEAT,
	ID_SPOTLIGHT,
	ID_SILENCE,
	ID_RUSH,
]
const DNA_IDS: Array[String] = [
	ID_DYNAMIC_LANES,
	ID_ENERGY_PULSE,
	ID_DENSITY_FOCUS,
	ID_PHRASE_SHIFT,
	ID_GROOVE_LOCK,
	ID_ADAPTIVE,
	ID_GROOVE_ADDICTION,
	ID_ENERGY_BALANCE,
]
const DNA_BEHAVIOR_IDS: Array[String] = [ID_PHRASE_SHIFT, ID_GROOVE_LOCK, ID_ADAPTIVE]
const DNA_GROOVE_IDS: Array[String] = [ID_GROOVE_LOCK, ID_GROOVE_ADDICTION]
## Detail panel: full MOD_DESC_* text (not MOD_DESC_*_PARAM one-liners).
const NARRATIVE_DESC_IDS: Array[String] = [
	ID_DYNAMIC_LANES,
	ID_ENERGY_PULSE,
	ID_DENSITY_FOCUS,
	ID_PHRASE_SHIFT,
	ID_GROOVE_LOCK,
	ID_ADAPTIVE,
	ID_GROOVE_ADDICTION,
	ID_ENERGY_BALANCE,
	ID_HALF_HP,
	ID_HEAT,
	ID_MEMORY_MODE,
	ID_SPOTLIGHT,
	ID_SILENCE,
	ID_RANDOM_MODE,
]
const SPECIAL_IDS: Array[String] = [
	ID_FIXED_SPEED_20,
	ID_AUTOPLAY,
	ID_SINGLE_LANE,
	ID_TIME_WARP,
	ID_PICK_MODE,
	ID_REVERSE_SCROLL,
	ID_COMBO_ESCALATION,
	ID_METRONOME_ONLY,
	ID_LAST_CHANCE,
]

const REMAP_IDS: Array[String] = [
	ID_MIRROR_MODE,
	ID_SHUFFLE_MODE,
	ID_RANDOM_MODE,
]

const COMBO_ESCALATION_PROGRESS := 0.05
const COMBO_ESCALATION_MIN_STEP := 25

const CE_PICK_RANDOM := "random"
const CE_PICK_NO_REPEAT := "no_repeat"
const CE_PICK_CUSTOM_ORDER := "custom_order"
const CE_PICK_MODE_DEFAULT := CE_PICK_NO_REPEAT

const CE_STEP_PCT_DEFAULT := 5.0
const CE_STEP_PCT_MIN := 2.0
const CE_STEP_PCT_MAX := 20.0
const CE_STEP_MIN_DEFAULT := 25
const CE_STEP_MIN_MIN := 10
const CE_STEP_MIN_MAX := 100
const LANE_REMAP_INTERVAL_DEFAULT := 8.0
const LANE_REMAP_INTERVAL_MIN := 4.0
const LANE_REMAP_INTERVAL_MAX := 30.0
const HALF_HP_START_PCT_DEFAULT := 50.0
const HALF_HP_START_PCT_MIN := 25.0
const HALF_HP_START_PCT_MAX := 100.0
const MEMORY_SPATIAL_BLIND_PCT_DEFAULT := 78.0
const MEMORY_SPATIAL_BLIND_PCT_MIN := 0.0
const MEMORY_SPATIAL_BLIND_PCT_MAX := 100.0
const MEMORY_FADE_MS_DEFAULT := 340.0
const MEMORY_FADE_MS_MIN := 100.0
const MEMORY_FADE_MS_MAX := 800.0
const SLOW_75_SPEED_DEFAULT := 75.0
const SLOW_75_SPEED_MIN := 25.0
const SLOW_75_SPEED_MAX := 99.0
const SLOW_75_SPEED_STEP := 1.0
const FAST_150_SPEED_DEFAULT := 150.0
const FAST_150_SPEED_MIN := 101.0
const FAST_150_SPEED_MAX := 250.0
const FAST_150_SPEED_STEP := 1.0
const TIME_WARP_MIN_PCT_DEFAULT := 100.0
const TIME_WARP_MAX_PCT_DEFAULT := 200.0
const TIME_WARP_SCROLL_PCT_MIN := 50.0
const TIME_WARP_SCROLL_PCT_MAX := 250.0
const ENERGY_PULSE_MIN_PCT_DEFAULT := 90.0
const ENERGY_PULSE_MAX_PCT_DEFAULT := 130.0
const DENSITY_FOCUS_SCROLL_PCT_DEFAULT := 115.0
const DENSITY_FOCUS_SCROLL_PCT_MIN := 100.0
const DENSITY_FOCUS_SCROLL_PCT_MAX := 150.0
const DENSITY_FOCUS_BAND_PX_DEFAULT := 140.0
const DENSITY_FOCUS_BAND_PX_MIN := 80.0
const DENSITY_FOCUS_BAND_PX_MAX := 220.0
const PHRASE_SHIFT_HEAT_SCROLL_PCT_DEFAULT := 125.0
const PHRASE_SHIFT_HEAT_SCROLL_PCT_MIN := 100.0
const PHRASE_SHIFT_HEAT_SCROLL_PCT_MAX := 175.0
const PHRASE_SHIFT_HIDDEN_BAND_PX_DEFAULT := 180.0
const GROOVE_LOCK_SCROLL_PCT_DEFAULT := 115.0
const GROOVE_LOCK_SCROLL_PCT_MIN := 100.0
const GROOVE_LOCK_SCROLL_PCT_MAX := 150.0
const GROOVE_LOCK_TIMING_PCT_DEFAULT := 85.0
const GROOVE_LOCK_TIMING_PCT_MIN := 60.0
const GROOVE_LOCK_TIMING_PCT_MAX := 100.0
const GROOVE_LOCK_BAND_PX_DEFAULT := 160.0
const ADAPTIVE_HEAT_SCROLL_PCT_DEFAULT := 125.0
const ADAPTIVE_HEAT_SCROLL_PCT_MIN := 100.0
const ADAPTIVE_HEAT_SCROLL_PCT_MAX := 175.0
const ADAPTIVE_HIDDEN_BAND_PX_DEFAULT := 150.0
const ADAPTIVE_SPEED_PCT_DEFAULT := 120.0
const ADAPTIVE_SPEED_PCT_MIN := 100.0
const ADAPTIVE_SPEED_PCT_MAX := 150.0

const HEAT_STEP_MODE_COMBO := "combo"
const HEAT_STEP_MODE_CHART_PCT := "chart_pct"
const HEAT_STEP_MODE_DEFAULT := HEAT_STEP_MODE_COMBO
const HEAT_STEP_COMBO_DEFAULT := 25
const HEAT_STEP_COMBO_MIN := 5
const HEAT_STEP_COMBO_MAX := 100
const HEAT_STEP_CHART_PCT_DEFAULT := 5.0
const HEAT_STEP_CHART_PCT_MIN := 2.0
const HEAT_STEP_CHART_PCT_MAX := 15.0
const HEAT_STEP_CHART_MIN_HITS := 5
const HEAT_PEAK_COMBO_DEFAULT := 150
const HEAT_PEAK_COMBO_MIN := 25
const HEAT_PEAK_COMBO_MAX := 500
const HEAT_PEAK_CHART_PCT_DEFAULT := 30.0
const HEAT_PEAK_CHART_PCT_MIN := 10.0
const HEAT_PEAK_CHART_PCT_MAX := 80.0
const HEAT_MAX_SPEED_PCT_DEFAULT := 130.0
const HEAT_MAX_SPEED_PCT_MIN := 100.0
const HEAT_MAX_SPEED_PCT_MAX := 300.0

const SILENCE_SCHEDULE_SECONDS := "seconds"
const SILENCE_SCHEDULE_TRACK_PCT := "track_pct"
const SILENCE_SCHEDULE_MODE_DEFAULT := SILENCE_SCHEDULE_SECONDS
const SILENCE_INTERVAL_SEC_DEFAULT := 15.0
const SILENCE_INTERVAL_SEC_MIN := 5.0
const SILENCE_INTERVAL_SEC_MAX := 30.0
const SILENCE_INTERVAL_TRACK_PCT_DEFAULT := 10.0
const SILENCE_INTERVAL_TRACK_PCT_MIN := 3.0
const SILENCE_INTERVAL_TRACK_PCT_MAX := 25.0
const SILENCE_DURATION_MIN_SEC_DEFAULT := 1.0
const SILENCE_DURATION_MAX_SEC_DEFAULT := 2.0
const SILENCE_DURATION_SEC_MIN := 0.5
const SILENCE_DURATION_SEC_MAX := 6.0

const SPOTLIGHT_BAND_PX_DEFAULT := 180.0
const SPOTLIGHT_BAND_PX_MIN := 80.0
const SPOTLIGHT_BAND_PX_MAX := 400.0
const SPOTLIGHT_DARKNESS_PCT_DEFAULT := 82.0
const SPOTLIGHT_DARKNESS_PCT_MIN := 40.0
const SPOTLIGHT_DARKNESS_PCT_MAX := 95.0

const RUSH_BARS_INTERVAL_DEFAULT := 8.0
const RUSH_BARS_INTERVAL_MIN := 4.0
const RUSH_BARS_INTERVAL_MAX := 16.0
const RUSH_FIRST_BAR_DEFAULT := 4.0
const RUSH_FIRST_BAR_MIN := 2.0
const RUSH_FIRST_BAR_MAX := 16.0
const RUSH_TIME_INTERVAL_MIN_DEFAULT := 10.0
const RUSH_TIME_INTERVAL_MIN_MIN := 8.0
const RUSH_TIME_INTERVAL_MIN_MAX := 45.0
const RUSH_TIME_INTERVAL_MAX_DEFAULT := 18.0
const RUSH_TIME_INTERVAL_MAX_MIN := 12.0
const RUSH_TIME_INTERVAL_MAX_MAX := 60.0
const RUSH_BURST_DURATION_SEC_DEFAULT := 3.0
const RUSH_BURST_DURATION_SEC_MIN := 1.0
const RUSH_BURST_DURATION_SEC_MAX := 5.0
const RUSH_SCROLL_PCT_BARS_DEFAULT := 150.0
const RUSH_SCROLL_PCT_TIME_DEFAULT := 140.0
const RUSH_SCROLL_PCT_MIN := 110.0
const RUSH_SCROLL_PCT_MAX := 185.0
const RUSH_RAMP_SEC_DEFAULT := 0.35
const RUSH_RAMP_SEC_MIN := 0.15
const RUSH_RAMP_SEC_MAX := 1.2

const ENERGY_BALANCE_CALM_PCT_DEFAULT := 120.0
const ENERGY_BALANCE_CALM_PCT_MIN := 100.0
const ENERGY_BALANCE_CALM_PCT_MAX := 150.0
const ENERGY_BALANCE_INTENSE_PCT_DEFAULT := 85.0
const ENERGY_BALANCE_INTENSE_PCT_MIN := 60.0
const ENERGY_BALANCE_INTENSE_PCT_MAX := 100.0

const GROOVE_ADDICTION_SCROLL_PCT_DEFAULT := 120.0
const GROOVE_ADDICTION_SCROLL_PCT_MIN := 100.0
const GROOVE_ADDICTION_SCROLL_PCT_MAX := 150.0
const GROOVE_ADDICTION_TIMING_PCT_DEFAULT := 85.0
const GROOVE_ADDICTION_TIMING_PCT_MIN := 60.0
const GROOVE_ADDICTION_TIMING_PCT_MAX := 100.0
const GROOVE_ADDICTION_MAX_TIER_DEFAULT := 3
const GROOVE_ADDICTION_MAX_TIER_MIN := 1
const GROOVE_ADDICTION_MAX_TIER_MAX := 5

const ESCALATION_POOL: Array[String] = [
	ID_FAST_150,
	ID_STRICT_TIMING,
	ID_NO_MISS_FORGIVENESS,
	ID_SUDDEN_DEATH,
	ID_HIDDEN,
	ID_SUDDEN,
	ID_MEMORY_MODE,
	ID_HEAT,
	ID_SPOTLIGHT,
	ID_SILENCE,
]

const ESCALATION_EASING_BLOCKS := {
	ID_SLOW_75: [ID_FAST_150],
	ID_NO_FAIL: [ID_SUDDEN_DEATH, ID_NO_MISS_FORGIVENESS],
	ID_EASY_WINDOWS: [ID_STRICT_TIMING, ID_NO_MISS_FORGIVENESS, ID_SUDDEN_DEATH],
}

const WINDOW_PERFECT_DEFAULT := 0.05
const WINDOW_GOOD_DEFAULT := 0.15
const WINDOW_PERFECT_STRICT := 0.03
const WINDOW_GOOD_STRICT := 0.10
const WINDOW_PERFECT_EASY := 0.075
const WINDOW_GOOD_EASY := 0.225
const FIXED_SCROLL_SPEED := 20.0
const VISIBILITY_BAND_PX := 220.0
const VISIBILITY_BAND_MIN := 120.0
const VISIBILITY_BAND_MAX := 320.0
const TIMING_WINDOW_PCT_DEFAULT := 100.0
const TIMING_WINDOW_PCT_MIN := 50.0
const TIMING_WINDOW_PCT_MAX := 150.0
const MEMORY_REVEAL_MS_DEFAULT := 500.0
const MEMORY_REVEAL_MS_MIN := 200.0
const MEMORY_REVEAL_MS_MAX := 1000.0
const SCROLL_SPEED_MULT_DEFAULT := 100.0
const SCROLL_SPEED_MULT_MIN := 50.0
const SCROLL_SPEED_MULT_MAX := 200.0
const MEMORY_PHASE_FULL_END := 0.25
const MEMORY_PHASE_REVEAL_500_END := 0.50
const MEMORY_PHASE_REVEAL_300_END := 0.75
const MEMORY_REVEAL_500_SEC := 0.5
const MEMORY_REVEAL_300_SEC := 0.3
const MEMORY_FADE_SEC := 0.34
const MEMORY_SPATIAL_FADE_FRAC := 0.14
const MEMORY_PATTERN_GAP_BEATS := 2.5
const MEMORY_HIDDEN_ALPHA := 0.0
const MEMORY_SPATIAL_BLIND_MAX := 0.78
const SINGLE_LANE_CHART_LANES := 3
const SINGLE_LANE_COUNT_MIN := 1
const SINGLE_LANE_COUNT_MAX := 10
const SINGLE_LANE_COUNT_DEFAULT := 1
const SINGLE_LANE_MAX_LANES := 10
const SINGLE_LANE_EXTENDED_KEYS := [KEY_Z, KEY_X, KEY_C, KEY_V, KEY_B]
const SINGLE_LANE_FALLBACK_KEYS := [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T]

const PITCH_SLOW_75 := 0.75
const PITCH_FAST_150 := 1.5

const REWARD_DELTA: Dictionary = {
	ID_SLOW_75: -0.10,
	ID_FAST_150: 0.12,
	ID_STRICT_TIMING: 0.12,
	ID_NO_MISS_FORGIVENESS: 0.08,
	ID_SUDDEN_DEATH: 0.20,
	ID_NO_FAIL: -0.10,
	ID_EASY_WINDOWS: -0.12,
	ID_HIDDEN: 0.06,
	ID_SUDDEN: 0.10,
	ID_HALF_HP: 0.08,
	ID_MEMORY_MODE: 0.15,
	ID_MIRROR_MODE: 0.08,
	ID_SHUFFLE_MODE: 0.10,
	ID_RANDOM_MODE: 0.13,
	ID_HEAT: 0.10,
	ID_SPOTLIGHT: 0.08,
	ID_SILENCE: 0.12,
	ID_RUSH: 0.10,
}

const PARAM_REWARD_STRENGTH := 0.42


static func default_params() -> Dictionary:
	return {
		"song_speed": SONG_SPEED_DEFAULT,
		"slow_75_speed_pct": SLOW_75_SPEED_DEFAULT,
		"fast_150_speed_pct": FAST_150_SPEED_DEFAULT,
		"slow_75_preserve_pitch": false,
		"fast_150_preserve_pitch": false,
		"scroll_speed_mode": "settings",
		"scroll_speed_value": FIXED_SCROLL_SPEED,
		"scroll_speed_mult_pct": SCROLL_SPEED_MULT_DEFAULT,
		"timing_window_pct": TIMING_WINDOW_PCT_DEFAULT,
		"easy_timing_window_pct": TIMING_WINDOW_PCT_DEFAULT,
		"strict_timing_window_pct": TIMING_WINDOW_PCT_DEFAULT,
		"visibility_band_px": VISIBILITY_BAND_PX,
		"memory_reveal_ms": MEMORY_REVEAL_MS_DEFAULT,
		"memory_spatial_blind_pct": MEMORY_SPATIAL_BLIND_PCT_DEFAULT,
		"memory_fade_ms": MEMORY_FADE_MS_DEFAULT,
		"half_hp_start_pct": HALF_HP_START_PCT_DEFAULT,
		"lane_remap_min_interval_sec": LANE_REMAP_INTERVAL_DEFAULT,
		"combo_escalation_step_pct": CE_STEP_PCT_DEFAULT,
		"combo_escalation_step_min": CE_STEP_MIN_DEFAULT,
		"combo_escalation_pick_mode": CE_PICK_MODE_DEFAULT,
		"combo_escalation_order": default_combo_escalation_order(),
		"combo_escalation_pool_enabled": default_combo_escalation_pool_enabled(),
		"time_warp_min_pct": TIME_WARP_MIN_PCT_DEFAULT,
		"time_warp_max_pct": TIME_WARP_MAX_PCT_DEFAULT,
		"energy_pulse_min_pct": ENERGY_PULSE_MIN_PCT_DEFAULT,
		"energy_pulse_max_pct": ENERGY_PULSE_MAX_PCT_DEFAULT,
		"density_focus_scroll_pct": DENSITY_FOCUS_SCROLL_PCT_DEFAULT,
		"density_focus_band_px": DENSITY_FOCUS_BAND_PX_DEFAULT,
		"phrase_shift_heat_scroll_pct": PHRASE_SHIFT_HEAT_SCROLL_PCT_DEFAULT,
		"phrase_shift_hidden_band_px": PHRASE_SHIFT_HIDDEN_BAND_PX_DEFAULT,
		"groove_lock_scroll_pct": GROOVE_LOCK_SCROLL_PCT_DEFAULT,
		"groove_lock_timing_pct": GROOVE_LOCK_TIMING_PCT_DEFAULT,
		"groove_lock_band_px": GROOVE_LOCK_BAND_PX_DEFAULT,
		"adaptive_heat_scroll_pct": ADAPTIVE_HEAT_SCROLL_PCT_DEFAULT,
		"adaptive_hidden_band_px": ADAPTIVE_HIDDEN_BAND_PX_DEFAULT,
		"adaptive_speed_pct": ADAPTIVE_SPEED_PCT_DEFAULT,
		"heat_step_mode": HEAT_STEP_MODE_DEFAULT,
		"heat_step_combo": HEAT_STEP_COMBO_DEFAULT,
		"heat_step_chart_pct": HEAT_STEP_CHART_PCT_DEFAULT,
		"heat_peak_combo": HEAT_PEAK_COMBO_DEFAULT,
		"heat_peak_chart_pct": HEAT_PEAK_CHART_PCT_DEFAULT,
		"heat_max_speed_pct": HEAT_MAX_SPEED_PCT_DEFAULT,
		"heat_affect_song_speed": false,
		"heat_preserve_pitch": true,
		"silence_schedule_mode": SILENCE_SCHEDULE_MODE_DEFAULT,
		"silence_interval_sec": SILENCE_INTERVAL_SEC_DEFAULT,
		"silence_interval_track_pct": SILENCE_INTERVAL_TRACK_PCT_DEFAULT,
		"silence_duration_min_sec": SILENCE_DURATION_MIN_SEC_DEFAULT,
		"silence_duration_max_sec": SILENCE_DURATION_MAX_SEC_DEFAULT,
		"silence_metronome": false,
		"spotlight_band_px": SPOTLIGHT_BAND_PX_DEFAULT,
		"spotlight_darkness_pct": SPOTLIGHT_DARKNESS_PCT_DEFAULT,
		"rush_bar_mode": true,
		"rush_bars_interval": RUSH_BARS_INTERVAL_DEFAULT,
		"rush_first_bar": RUSH_FIRST_BAR_DEFAULT,
		"rush_time_interval_min_sec": RUSH_TIME_INTERVAL_MIN_DEFAULT,
		"rush_time_interval_max_sec": RUSH_TIME_INTERVAL_MAX_DEFAULT,
		"rush_burst_duration_sec": RUSH_BURST_DURATION_SEC_DEFAULT,
		"rush_scroll_pct_bars": RUSH_SCROLL_PCT_BARS_DEFAULT,
		"rush_scroll_pct_time": RUSH_SCROLL_PCT_TIME_DEFAULT,
		"rush_ramp_sec": RUSH_RAMP_SEC_DEFAULT,
		"rush_affect_song_speed": false,
		"rush_preserve_pitch": true,
		"energy_balance_calm_pct": ENERGY_BALANCE_CALM_PCT_DEFAULT,
		"energy_balance_intense_pct": ENERGY_BALANCE_INTENSE_PCT_DEFAULT,
		"groove_addiction_scroll_pct": GROOVE_ADDICTION_SCROLL_PCT_DEFAULT,
		"groove_addiction_timing_pct": GROOVE_ADDICTION_TIMING_PCT_DEFAULT,
		"groove_addiction_max_tier": GROOVE_ADDICTION_MAX_TIER_DEFAULT,
		"single_lane_count": SINGLE_LANE_COUNT_DEFAULT,
	}


static func default_combo_escalation_pool_enabled() -> Array[String]:
	return ESCALATION_POOL.duplicate()


static func default_combo_escalation_order() -> Array[String]:
	return ESCALATION_POOL.duplicate()


static func _migrate_legacy_rush_params(raw: Dictionary, out: Dictionary) -> void:
	if not raw is Dictionary:
		return
	if raw.has("rush_bars_interval") or raw.has("rush_time_interval_min_sec") or raw.has("rush_bar_mode"):
		return
	if raw.has("rush_interval_min_sec"):
		var legacy_min := float(raw["rush_interval_min_sec"])
		if legacy_min <= 16.0:
			out["rush_bar_mode"] = true
			out["rush_bars_interval"] = clampf(
				legacy_min, RUSH_BARS_INTERVAL_MIN, RUSH_BARS_INTERVAL_MAX
			)
		else:
			out["rush_bar_mode"] = false
			out["rush_time_interval_min_sec"] = clampf(
				legacy_min, RUSH_TIME_INTERVAL_MIN_MIN, RUSH_TIME_INTERVAL_MIN_MAX
			)
	if raw.has("rush_interval_max_sec"):
		var legacy_max := float(raw["rush_interval_max_sec"])
		if bool(out.get("rush_bar_mode", true)) and legacy_max <= 16.0:
			out["rush_first_bar"] = clampf(legacy_max, RUSH_FIRST_BAR_MIN, RUSH_FIRST_BAR_MAX)
		elif not bool(out.get("rush_bar_mode", true)):
			out["rush_time_interval_max_sec"] = clampf(
				legacy_max, RUSH_TIME_INTERVAL_MAX_MIN, RUSH_TIME_INTERVAL_MAX_MAX
			)
	if raw.has("rush_scroll_pct"):
		var legacy_scroll := clampf(
			float(raw["rush_scroll_pct"]), RUSH_SCROLL_PCT_MIN, RUSH_SCROLL_PCT_MAX
		)
		out["rush_scroll_pct_bars"] = legacy_scroll
		out["rush_scroll_pct_time"] = clampf(
			legacy_scroll - 10.0, RUSH_SCROLL_PCT_MIN, RUSH_SCROLL_PCT_MAX
		)


static func sanitize_params(raw: Variant) -> Dictionary:
	var out := default_params()
	if raw is Dictionary:
		if raw.has("song_speed"):
			out["song_speed"] = clampf(float(raw["song_speed"]), SONG_SPEED_MIN, SONG_SPEED_MAX)
		var mode := str(raw.get("scroll_speed_mode", "settings")).strip_edges()
		out["scroll_speed_mode"] = "fixed" if mode == "fixed" else "settings"
		if raw.has("scroll_speed_value"):
			out["scroll_speed_value"] = clampf(
				float(raw["scroll_speed_value"]),
				SCROLL_SPEED_VALUE_MIN,
				SCROLL_SPEED_VALUE_MAX
			)
		if raw.has("scroll_speed_mult_pct"):
			out["scroll_speed_mult_pct"] = clampf(
				float(raw["scroll_speed_mult_pct"]),
				SCROLL_SPEED_MULT_MIN,
				SCROLL_SPEED_MULT_MAX
			)
		if raw.has("timing_window_pct"):
			var legacy_timing := clampf(
				float(raw["timing_window_pct"]),
				TIMING_WINDOW_PCT_MIN,
				TIMING_WINDOW_PCT_MAX
			)
			out["timing_window_pct"] = legacy_timing
			if not raw.has("easy_timing_window_pct"):
				out["easy_timing_window_pct"] = legacy_timing
			if not raw.has("strict_timing_window_pct"):
				out["strict_timing_window_pct"] = legacy_timing
		if raw.has("easy_timing_window_pct"):
			out["easy_timing_window_pct"] = clampf(
				float(raw["easy_timing_window_pct"]),
				TIMING_WINDOW_PCT_MIN,
				TIMING_WINDOW_PCT_MAX
			)
		if raw.has("strict_timing_window_pct"):
			out["strict_timing_window_pct"] = clampf(
				float(raw["strict_timing_window_pct"]),
				TIMING_WINDOW_PCT_MIN,
				TIMING_WINDOW_PCT_MAX
			)
		if raw.has("visibility_band_px"):
			out["visibility_band_px"] = clampf(
				float(raw["visibility_band_px"]),
				VISIBILITY_BAND_MIN,
				VISIBILITY_BAND_MAX
			)
		if raw.has("memory_reveal_ms"):
			out["memory_reveal_ms"] = clampf(
				float(raw["memory_reveal_ms"]),
				MEMORY_REVEAL_MS_MIN,
				MEMORY_REVEAL_MS_MAX
			)
		if raw.has("combo_escalation_pick_mode"):
			out["combo_escalation_pick_mode"] = sanitize_combo_escalation_pick_mode(
				raw["combo_escalation_pick_mode"]
			)
		if raw.has("combo_escalation_order"):
			out["combo_escalation_order"] = sanitize_combo_escalation_order(
				raw["combo_escalation_order"]
			)
		if raw.has("combo_escalation_pool_enabled"):
			out["combo_escalation_pool_enabled"] = sanitize_combo_escalation_pool_enabled(
				raw["combo_escalation_pool_enabled"]
			)
		if raw.has("slow_75_speed_pct"):
			out["slow_75_speed_pct"] = clampf(
				roundf(float(raw["slow_75_speed_pct"])), SLOW_75_SPEED_MIN, SLOW_75_SPEED_MAX
			)
		if raw.has("fast_150_speed_pct"):
			var fast_pct := roundf(float(raw["fast_150_speed_pct"]))
			if is_equal_approx(fast_pct, 151.0):
				fast_pct = FAST_150_SPEED_DEFAULT
			out["fast_150_speed_pct"] = clampf(fast_pct, FAST_150_SPEED_MIN, FAST_150_SPEED_MAX)
		if raw.has("slow_75_preserve_pitch"):
			out["slow_75_preserve_pitch"] = bool(raw["slow_75_preserve_pitch"])
		if raw.has("fast_150_preserve_pitch"):
			out["fast_150_preserve_pitch"] = bool(raw["fast_150_preserve_pitch"])
		if raw.has("combo_escalation_step_pct"):
			out["combo_escalation_step_pct"] = clampf(
				float(raw["combo_escalation_step_pct"]), CE_STEP_PCT_MIN, CE_STEP_PCT_MAX
			)
		if raw.has("combo_escalation_step_min"):
			out["combo_escalation_step_min"] = clampi(
				int(raw["combo_escalation_step_min"]), CE_STEP_MIN_MIN, CE_STEP_MIN_MAX
			)
		if raw.has("lane_remap_min_interval_sec"):
			out["lane_remap_min_interval_sec"] = clampf(
				float(raw["lane_remap_min_interval_sec"]),
				LANE_REMAP_INTERVAL_MIN,
				LANE_REMAP_INTERVAL_MAX
			)
		if raw.has("half_hp_start_pct"):
			out["half_hp_start_pct"] = clampf(
				float(raw["half_hp_start_pct"]), HALF_HP_START_PCT_MIN, HALF_HP_START_PCT_MAX
			)
		if raw.has("memory_spatial_blind_pct"):
			out["memory_spatial_blind_pct"] = clampf(
				float(raw["memory_spatial_blind_pct"]),
				MEMORY_SPATIAL_BLIND_PCT_MIN,
				MEMORY_SPATIAL_BLIND_PCT_MAX
			)
		if raw.has("memory_fade_ms"):
			out["memory_fade_ms"] = clampf(
				float(raw["memory_fade_ms"]), MEMORY_FADE_MS_MIN, MEMORY_FADE_MS_MAX
			)
		if raw.has("time_warp_min_pct"):
			out["time_warp_min_pct"] = clampf(
				float(raw["time_warp_min_pct"]), TIME_WARP_SCROLL_PCT_MIN, TIME_WARP_SCROLL_PCT_MAX
			)
		if raw.has("time_warp_max_pct"):
			out["time_warp_max_pct"] = clampf(
				float(raw["time_warp_max_pct"]), TIME_WARP_SCROLL_PCT_MIN, TIME_WARP_SCROLL_PCT_MAX
			)
		if out["time_warp_min_pct"] > out["time_warp_max_pct"]:
			out["time_warp_min_pct"] = out["time_warp_max_pct"]
		if raw.has("energy_pulse_min_pct"):
			out["energy_pulse_min_pct"] = clampf(
				float(raw["energy_pulse_min_pct"]),
				TIME_WARP_SCROLL_PCT_MIN,
				TIME_WARP_SCROLL_PCT_MAX
			)
		if raw.has("energy_pulse_max_pct"):
			out["energy_pulse_max_pct"] = clampf(
				float(raw["energy_pulse_max_pct"]),
				TIME_WARP_SCROLL_PCT_MIN,
				TIME_WARP_SCROLL_PCT_MAX
			)
		if out["energy_pulse_min_pct"] > out["energy_pulse_max_pct"]:
			out["energy_pulse_min_pct"] = out["energy_pulse_max_pct"]
		if raw.has("density_focus_scroll_pct"):
			out["density_focus_scroll_pct"] = clampf(
				float(raw["density_focus_scroll_pct"]),
				DENSITY_FOCUS_SCROLL_PCT_MIN,
				DENSITY_FOCUS_SCROLL_PCT_MAX
			)
		if raw.has("density_focus_band_px"):
			out["density_focus_band_px"] = clampf(
				float(raw["density_focus_band_px"]),
				DENSITY_FOCUS_BAND_PX_MIN,
				DENSITY_FOCUS_BAND_PX_MAX
			)
		if raw.has("phrase_shift_heat_scroll_pct"):
			out["phrase_shift_heat_scroll_pct"] = clampf(
				float(raw["phrase_shift_heat_scroll_pct"]),
				PHRASE_SHIFT_HEAT_SCROLL_PCT_MIN,
				PHRASE_SHIFT_HEAT_SCROLL_PCT_MAX
			)
		if raw.has("phrase_shift_hidden_band_px"):
			out["phrase_shift_hidden_band_px"] = clampf(
				float(raw["phrase_shift_hidden_band_px"]),
				DENSITY_FOCUS_BAND_PX_MIN,
				VISIBILITY_BAND_MAX
			)
		if raw.has("groove_lock_scroll_pct"):
			out["groove_lock_scroll_pct"] = clampf(
				float(raw["groove_lock_scroll_pct"]),
				GROOVE_LOCK_SCROLL_PCT_MIN,
				GROOVE_LOCK_SCROLL_PCT_MAX
			)
		if raw.has("groove_lock_timing_pct"):
			out["groove_lock_timing_pct"] = clampf(
				float(raw["groove_lock_timing_pct"]),
				GROOVE_LOCK_TIMING_PCT_MIN,
				GROOVE_LOCK_TIMING_PCT_MAX
			)
		if raw.has("groove_lock_band_px"):
			out["groove_lock_band_px"] = clampf(
				float(raw["groove_lock_band_px"]),
				DENSITY_FOCUS_BAND_PX_MIN,
				VISIBILITY_BAND_MAX
			)
		if raw.has("adaptive_heat_scroll_pct"):
			out["adaptive_heat_scroll_pct"] = clampf(
				float(raw["adaptive_heat_scroll_pct"]),
				ADAPTIVE_HEAT_SCROLL_PCT_MIN,
				ADAPTIVE_HEAT_SCROLL_PCT_MAX
			)
		if raw.has("adaptive_hidden_band_px"):
			out["adaptive_hidden_band_px"] = clampf(
				float(raw["adaptive_hidden_band_px"]),
				DENSITY_FOCUS_BAND_PX_MIN,
				VISIBILITY_BAND_MAX
			)
		if raw.has("adaptive_speed_pct"):
			out["adaptive_speed_pct"] = clampf(
				float(raw["adaptive_speed_pct"]),
				ADAPTIVE_SPEED_PCT_MIN,
				ADAPTIVE_SPEED_PCT_MAX
			)
		if raw.has("heat_step_mode"):
			out["heat_step_mode"] = sanitize_heat_step_mode(raw["heat_step_mode"])
		if raw.has("heat_step_combo"):
			out["heat_step_combo"] = clampi(
				int(raw["heat_step_combo"]), HEAT_STEP_COMBO_MIN, HEAT_STEP_COMBO_MAX
			)
		if raw.has("heat_step_chart_pct"):
			out["heat_step_chart_pct"] = clampf(
				float(raw["heat_step_chart_pct"]),
				HEAT_STEP_CHART_PCT_MIN,
				HEAT_STEP_CHART_PCT_MAX
			)
		if raw.has("heat_peak_combo"):
			out["heat_peak_combo"] = clampi(
				int(raw["heat_peak_combo"]), HEAT_PEAK_COMBO_MIN, HEAT_PEAK_COMBO_MAX
			)
		if raw.has("heat_peak_chart_pct"):
			out["heat_peak_chart_pct"] = clampf(
				float(raw["heat_peak_chart_pct"]),
				HEAT_PEAK_CHART_PCT_MIN,
				HEAT_PEAK_CHART_PCT_MAX
			)
		if raw.has("heat_max_speed_pct"):
			out["heat_max_speed_pct"] = clampf(
				float(raw["heat_max_speed_pct"]), HEAT_MAX_SPEED_PCT_MIN, HEAT_MAX_SPEED_PCT_MAX
			)
		if raw.has("heat_affect_song_speed"):
			out["heat_affect_song_speed"] = bool(raw["heat_affect_song_speed"])
		if raw.has("heat_preserve_pitch"):
			out["heat_preserve_pitch"] = bool(raw["heat_preserve_pitch"])
		_migrate_legacy_heat_params(raw, out)
		_clamp_heat_peak_above_step(out)
		if raw.has("silence_schedule_mode"):
			out["silence_schedule_mode"] = sanitize_silence_schedule_mode(
				raw["silence_schedule_mode"]
			)
		if raw.has("silence_interval_sec"):
			out["silence_interval_sec"] = clampf(
				float(raw["silence_interval_sec"]),
				SILENCE_INTERVAL_SEC_MIN,
				SILENCE_INTERVAL_SEC_MAX
			)
		if raw.has("silence_duration_min_sec"):
			out["silence_duration_min_sec"] = clampf(
				float(raw["silence_duration_min_sec"]),
				SILENCE_DURATION_SEC_MIN,
				SILENCE_DURATION_SEC_MAX
			)
		if raw.has("silence_duration_max_sec"):
			out["silence_duration_max_sec"] = clampf(
				float(raw["silence_duration_max_sec"]),
				SILENCE_DURATION_SEC_MIN,
				SILENCE_DURATION_SEC_MAX
			)
		if raw.has("silence_duration_sec"):
			var legacy_dur := float(raw["silence_duration_sec"])
			out["silence_duration_min_sec"] = legacy_dur
			out["silence_duration_max_sec"] = legacy_dur
		var sil_min := float(out.get("silence_duration_min_sec", SILENCE_DURATION_MIN_SEC_DEFAULT))
		var sil_max := float(out.get("silence_duration_max_sec", SILENCE_DURATION_MAX_SEC_DEFAULT))
		if sil_max < sil_min:
			out["silence_duration_max_sec"] = sil_min
		if raw.has("silence_interval_track_pct"):
			out["silence_interval_track_pct"] = clampf(
				float(raw["silence_interval_track_pct"]),
				SILENCE_INTERVAL_TRACK_PCT_MIN,
				SILENCE_INTERVAL_TRACK_PCT_MAX
			)
		if raw.has("silence_metronome"):
			out["silence_metronome"] = bool(raw["silence_metronome"])
		if raw.has("spotlight_band_px"):
			out["spotlight_band_px"] = clampf(
				float(raw["spotlight_band_px"]),
				SPOTLIGHT_BAND_PX_MIN,
				SPOTLIGHT_BAND_PX_MAX
			)
		if raw.has("spotlight_darkness_pct"):
			out["spotlight_darkness_pct"] = clampf(
				float(raw["spotlight_darkness_pct"]),
				SPOTLIGHT_DARKNESS_PCT_MIN,
				SPOTLIGHT_DARKNESS_PCT_MAX
			)
		if raw.has("rush_bar_mode"):
			out["rush_bar_mode"] = bool(raw["rush_bar_mode"])
		_migrate_legacy_rush_params(raw, out)
		if raw.has("rush_bars_interval"):
			out["rush_bars_interval"] = clampf(
				float(raw["rush_bars_interval"]),
				RUSH_BARS_INTERVAL_MIN,
				RUSH_BARS_INTERVAL_MAX
			)
		if raw.has("rush_first_bar"):
			out["rush_first_bar"] = clampf(
				float(raw["rush_first_bar"]),
				RUSH_FIRST_BAR_MIN,
				RUSH_FIRST_BAR_MAX
			)
		if raw.has("rush_time_interval_min_sec"):
			out["rush_time_interval_min_sec"] = clampf(
				float(raw["rush_time_interval_min_sec"]),
				RUSH_TIME_INTERVAL_MIN_MIN,
				RUSH_TIME_INTERVAL_MIN_MAX
			)
		if raw.has("rush_time_interval_max_sec"):
			out["rush_time_interval_max_sec"] = clampf(
				float(raw["rush_time_interval_max_sec"]),
				RUSH_TIME_INTERVAL_MAX_MIN,
				RUSH_TIME_INTERVAL_MAX_MAX
			)
		if out["rush_time_interval_min_sec"] > out["rush_time_interval_max_sec"]:
			out["rush_time_interval_min_sec"] = out["rush_time_interval_max_sec"]
		if raw.has("rush_burst_duration_sec"):
			out["rush_burst_duration_sec"] = clampf(
				float(raw["rush_burst_duration_sec"]),
				RUSH_BURST_DURATION_SEC_MIN,
				RUSH_BURST_DURATION_SEC_MAX
			)
		if raw.has("rush_scroll_pct_bars"):
			out["rush_scroll_pct_bars"] = clampf(
				float(raw["rush_scroll_pct_bars"]),
				RUSH_SCROLL_PCT_MIN,
				RUSH_SCROLL_PCT_MAX
			)
		if raw.has("rush_scroll_pct_time"):
			out["rush_scroll_pct_time"] = clampf(
				float(raw["rush_scroll_pct_time"]),
				RUSH_SCROLL_PCT_MIN,
				RUSH_SCROLL_PCT_MAX
			)
		if raw.has("rush_ramp_sec"):
			out["rush_ramp_sec"] = clampf(
				float(raw["rush_ramp_sec"]),
				RUSH_RAMP_SEC_MIN,
				RUSH_RAMP_SEC_MAX
			)
		if raw.has("rush_affect_song_speed"):
			out["rush_affect_song_speed"] = bool(raw["rush_affect_song_speed"])
		if raw.has("rush_preserve_pitch"):
			out["rush_preserve_pitch"] = bool(raw["rush_preserve_pitch"])
		if raw.has("energy_balance_calm_pct"):
			out["energy_balance_calm_pct"] = clampf(
				float(raw["energy_balance_calm_pct"]),
				ENERGY_BALANCE_CALM_PCT_MIN,
				ENERGY_BALANCE_CALM_PCT_MAX
			)
		if raw.has("energy_balance_intense_pct"):
			out["energy_balance_intense_pct"] = clampf(
				float(raw["energy_balance_intense_pct"]),
				ENERGY_BALANCE_INTENSE_PCT_MIN,
				ENERGY_BALANCE_INTENSE_PCT_MAX
			)
		if raw.has("groove_addiction_scroll_pct"):
			out["groove_addiction_scroll_pct"] = clampf(
				float(raw["groove_addiction_scroll_pct"]),
				GROOVE_ADDICTION_SCROLL_PCT_MIN,
				GROOVE_ADDICTION_SCROLL_PCT_MAX
			)
		if raw.has("groove_addiction_timing_pct"):
			out["groove_addiction_timing_pct"] = clampf(
				float(raw["groove_addiction_timing_pct"]),
				GROOVE_ADDICTION_TIMING_PCT_MIN,
				GROOVE_ADDICTION_TIMING_PCT_MAX
			)
		if raw.has("groove_addiction_max_tier"):
			out["groove_addiction_max_tier"] = clampi(
				int(raw["groove_addiction_max_tier"]),
				GROOVE_ADDICTION_MAX_TIER_MIN,
				GROOVE_ADDICTION_MAX_TIER_MAX
			)
		if raw.has("single_lane_count"):
			out["single_lane_count"] = clampi(
				int(raw["single_lane_count"]),
				SINGLE_LANE_COUNT_MIN,
				SINGLE_LANE_COUNT_MAX
			)
		# Legacy single song_speed slider → per-mod speeds when unset.
		if raw is Dictionary and raw.has("song_speed") and not raw.has("slow_75_speed_pct"):
			var legacy := clampf(float(raw["song_speed"]), SONG_SPEED_MIN, SONG_SPEED_MAX)
			if legacy < SONG_SPEED_DEFAULT:
				out["slow_75_speed_pct"] = legacy
			elif legacy > SONG_SPEED_DEFAULT:
				out["fast_150_speed_pct"] = legacy
	return out


static func sanitize_silence_schedule_mode(raw: Variant) -> String:
	var mode := str(raw).strip_edges()
	if mode == SILENCE_SCHEDULE_TRACK_PCT:
		return SILENCE_SCHEDULE_TRACK_PCT
	return SILENCE_SCHEDULE_SECONDS


static func sanitize_heat_step_mode(raw: Variant) -> String:
	var mode := str(raw).strip_edges()
	if mode == HEAT_STEP_MODE_CHART_PCT:
		return HEAT_STEP_MODE_CHART_PCT
	return HEAT_STEP_MODE_COMBO


static func _clamp_heat_peak_above_step(out: Dictionary) -> void:
	var peak_combo := int(out.get("heat_peak_combo", HEAT_PEAK_COMBO_DEFAULT))
	var step_combo := int(out.get("heat_step_combo", HEAT_STEP_COMBO_DEFAULT))
	if peak_combo < step_combo:
		out["heat_peak_combo"] = step_combo
	var step_pct := float(out.get("heat_step_chart_pct", HEAT_STEP_CHART_PCT_DEFAULT))
	var peak_pct := float(out.get("heat_peak_chart_pct", HEAT_PEAK_CHART_PCT_DEFAULT))
	if peak_pct < step_pct:
		out["heat_peak_chart_pct"] = step_pct


static func _migrate_legacy_heat_params(raw: Dictionary, out: Dictionary) -> void:
	if not raw.has("heat_peak_combo") and raw.has("heat_tier3_combo"):
		out["heat_peak_combo"] = clampi(
			int(raw["heat_tier3_combo"]), HEAT_PEAK_COMBO_MIN, HEAT_PEAK_COMBO_MAX
		)
	if not raw.has("heat_max_speed_pct"):
		if raw.has("heat_mult_tier3_pct"):
			out["heat_max_speed_pct"] = clampf(
				float(raw["heat_mult_tier3_pct"]), HEAT_MAX_SPEED_PCT_MIN, HEAT_MAX_SPEED_PCT_MAX
			)
		elif raw.has("heat_mult_tier3"):
			out["heat_max_speed_pct"] = clampf(
				float(raw["heat_mult_tier3"]) * 100.0, HEAT_MAX_SPEED_PCT_MIN, HEAT_MAX_SPEED_PCT_MAX
			)
	if not raw.has("heat_step_combo") and raw.has("heat_tier1_combo") and raw.has("heat_tier2_combo"):
		var delta := int(raw["heat_tier2_combo"]) - int(raw["heat_tier1_combo"])
		if delta > 0:
			out["heat_step_combo"] = clampi(delta, HEAT_STEP_COMBO_MIN, HEAT_STEP_COMBO_MAX)
	for legacy_key in ["heat_mult_tier1", "heat_mult_tier2", "heat_mult_tier3"]:
		if not raw.has(legacy_key):
			continue
		var pct_key := "%s_pct" % legacy_key
		if raw.has(pct_key):
			continue
		var legacy_val := float(raw[legacy_key])
		if legacy_val <= 3.5:
			out[pct_key] = clampf(legacy_val * 100.0, HEAT_MAX_SPEED_PCT_MIN, HEAT_MAX_SPEED_PCT_MAX)


static func sanitize_combo_escalation_pick_mode(raw: Variant) -> String:
	var mode := str(raw).strip_edges()
	match mode:
		CE_PICK_RANDOM, CE_PICK_NO_REPEAT, CE_PICK_CUSTOM_ORDER:
			return mode
	return CE_PICK_MODE_DEFAULT


static func sanitize_combo_escalation_order(raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if raw is Array:
		for item in raw:
			var sid := str(item).strip_edges()
			if ESCALATION_POOL.has(sid) and not out.has(sid):
				out.append(sid)
	for id in ESCALATION_POOL:
		if not out.has(id):
			out.append(id)
	return out


static func sanitize_combo_escalation_pool_enabled(raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if raw is Array:
		for item in raw:
			var sid := str(item).strip_edges()
			if ESCALATION_POOL.has(sid) and not out.has(sid):
				out.append(sid)
	if out.is_empty():
		return [ESCALATION_POOL[0]]
	return out


static func params_equal(a: Dictionary, b: Dictionary) -> bool:
	return JSON.stringify(sanitize_params(a)) == JSON.stringify(sanitize_params(b))


static func sync_params_from_modifiers(modifiers: Array, params: Dictionary) -> Dictionary:
	var out := sanitize_params(params)
	var mods := sanitize(modifiers)
	if mods.has(ID_FIXED_SPEED_20):
		out["scroll_speed_mode"] = "fixed"
		out["scroll_speed_value"] = float(out.get("scroll_speed_value", FIXED_SCROLL_SPEED))
	out["song_speed"] = SONG_SPEED_DEFAULT
	if mods.has(ID_SLOW_75):
		out["song_speed"] = float(out.get("slow_75_speed_pct", SLOW_75_SPEED_DEFAULT))
	elif mods.has(ID_FAST_150):
		out["song_speed"] = float(out.get("fast_150_speed_pct", FAST_150_SPEED_DEFAULT))
	return out


static func is_song_speed_default(params: Dictionary) -> bool:
	var p := sanitize_params(params)
	return (
		is_equal_approx(float(p.get("slow_75_speed_pct", SLOW_75_SPEED_DEFAULT)), SLOW_75_SPEED_DEFAULT)
		and is_equal_approx(float(p.get("fast_150_speed_pct", FAST_150_SPEED_DEFAULT)), FAST_150_SPEED_DEFAULT)
	)


static func speed_reward_delta(modifiers: Array, params: Dictionary) -> float:
	var p := sanitize_params(params)
	var mods := sanitize(modifiers)
	if mods.has(ID_SLOW_75):
		var s := float(p.get("slow_75_speed_pct", SLOW_75_SPEED_DEFAULT)) / SONG_SPEED_DEFAULT
		if is_equal_approx(s, 1.0):
			return 0.0
		return -0.10 * (1.0 - s)
	if mods.has(ID_FAST_150):
		var f := float(p.get("fast_150_speed_pct", FAST_150_SPEED_DEFAULT)) / SONG_SPEED_DEFAULT
		if is_equal_approx(f, 1.0):
			return 0.0
		return 0.12 * (f - 1.0)
	var speed_pct := float(p.get("song_speed", SONG_SPEED_DEFAULT))
	var s_legacy := speed_pct / SONG_SPEED_DEFAULT
	if is_equal_approx(s_legacy, 1.0):
		return 0.0
	if s_legacy < 1.0:
		return -0.10 * (1.0 - s_legacy)
	return 0.12 * (s_legacy - 1.0)


static func start_health_ratio(modifiers: Array, params: Dictionary = {}) -> float:
	if has_modifier(modifiers, ID_HALF_HP):
		return clampf(
			float(sanitize_params(params).get("half_hp_start_pct", HALF_HP_START_PCT_DEFAULT)) / 100.0,
			0.01,
			1.0
		)
	return 1.0


static func lane_remap_min_interval_sec(params: Dictionary = {}) -> float:
	return float(sanitize_params(params).get("lane_remap_min_interval_sec", LANE_REMAP_INTERVAL_DEFAULT))


static func memory_spatial_blind_frac(params: Dictionary = {}) -> float:
	var pct := float(sanitize_params(params).get("memory_spatial_blind_pct", MEMORY_SPATIAL_BLIND_PCT_DEFAULT))
	return clampf(pct, MEMORY_SPATIAL_BLIND_PCT_MIN, MEMORY_SPATIAL_BLIND_PCT_MAX) / 100.0


static func memory_fade_sec(params: Dictionary = {}) -> float:
	return maxf(
		0.05,
		float(sanitize_params(params).get("memory_fade_ms", MEMORY_FADE_MS_DEFAULT)) / 1000.0
	)


static func combo_escalation_step(total_notes: int, params: Dictionary = {}) -> int:
	var p := sanitize_params(params)
	var notes := maxi(total_notes, 1)
	var progress := float(p.get("combo_escalation_step_pct", CE_STEP_PCT_DEFAULT)) / 100.0
	var by_progress := int(ceil(float(notes) * progress))
	var min_step := int(p.get("combo_escalation_step_min", CE_STEP_MIN_DEFAULT))
	return maxi(min_step, by_progress)


static func combo_escalation_tier(notes_hit: int, total_notes: int, params: Dictionary = {}) -> int:
	var step := combo_escalation_step(total_notes, params)
	if step <= 0:
		return 0
	return int(notes_hit / step)


static func is_single_lane(modifiers: Array) -> bool:
	return has_modifier(modifiers, ID_SINGLE_LANE)


static func single_lane_display_count(modifiers: Array, params: Dictionary = {}) -> int:
	if not is_single_lane(modifiers):
		return 0
	return clampi(
		int(sanitize_params(params).get("single_lane_count", SINGLE_LANE_COUNT_DEFAULT)),
		SINGLE_LANE_COUNT_MIN,
		SINGLE_LANE_COUNT_MAX
	)


static func single_lane_is_collapsed(modifiers: Array, params: Dictionary = {}) -> bool:
	return single_lane_display_count(modifiers, params) <= 1


static func single_lane_chart_to_display_lane(
	chart_lane: int,
	chart_lanes: int,
	display_count: int
) -> int:
	if display_count <= 1:
		return 0
	var chart := maxi(chart_lanes, 1)
	var lane := clampi(chart_lane, 0, chart - 1)
	if chart <= 1:
		return clampi(lane, 0, display_count - 1)
	return clampi((lane * (display_count - 1)) / (chart - 1), 0, display_count - 1)


static func layout_lane_count(modifiers: Array, base_lanes: int, params: Dictionary = {}) -> int:
	if is_single_lane(modifiers):
		return single_lane_display_count(modifiers, params)
	return clampi(base_lanes, 3, 5)


static func active_play_lane(modifiers: Array, total_lanes: int) -> int:
	if not is_single_lane(modifiers):
		return -1
	if total_lanes <= 1:
		return -1
	return 0


static func is_play_lane(modifiers: Array, lane: int, active_lanes: int, chart_lanes: int = -1) -> bool:
	return is_chart_lane_playable(modifiers, lane, active_lanes, chart_lanes)


static func is_display_lane_playable(
	modifiers: Array,
	display_lane: int,
	active_lanes: int,
	params: Dictionary = {}
) -> bool:
	if display_lane < 0 or display_lane >= active_lanes:
		return false
	if is_single_lane(modifiers):
		if single_lane_is_collapsed(modifiers, params):
			return display_lane == 0
		return display_lane < single_lane_display_count(modifiers, params)
	var single := active_play_lane(modifiers, active_lanes)
	if single >= 0:
		return display_lane == single
	return true


static func chart_lane_window(active_lanes: int, chart_lanes: int, modifiers: Array = []) -> Vector2i:
	var active := clampi(active_lanes, 3, 5)
	var chart := clampi(chart_lanes, 3, 5)
	if active >= chart:
		return Vector2i(0, chart - 1)
	if is_dynamic_lanes(modifiers) or is_single_lane(modifiers):
		return Vector2i(0, active - 1)
	var offset := int(floor(float(chart - active) * 0.5))
	return Vector2i(offset, offset + active - 1)


static func display_lane_for_chart_lane(
	chart_lane: int,
	active_lanes: int,
	chart_lanes: int,
	modifiers: Array = [],
	remap_ctx: Dictionary = {},
	params: Dictionary = {}
) -> int:
	if is_single_lane(modifiers):
		var sl_count := single_lane_display_count(modifiers, params)
		if sl_count <= 1:
			return 0
		var chart := clampi(chart_lanes, 3, 5)
		var lane := clampi(chart_lane, 0, chart - 1)
		return single_lane_chart_to_display_lane(lane, chart, sl_count)
	var chart := clampi(chart_lanes, 3, 5)
	var active := clampi(active_lanes, 3, 5)
	var win := chart_lane_window(active_lanes, chart, modifiers)
	var lane := clampi(chart_lane, 0, chart - 1)
	if lane < win.x or lane > win.y:
		return -1
	if has_lane_remap(modifiers):
		var mode := lane_remap_mode(modifiers)
		if mode == "":
			return lane - win.x
		var display := _LaneRemap.remap_local_lane(
			lane - win.x,
			active,
			mode,
			str(remap_ctx.get("song_path", "")),
			active_lane_remap_id(modifiers),
			float(remap_ctx.get("note_time", 0.0)),
			float(remap_ctx.get("bpm", 120.0)),
			remap_ctx
		)
		if display < 0 or display >= active:
			return -1
		return display
	var mapped := remap_chart_lane(chart_lane, chart, modifiers, remap_ctx)
	if mapped < win.x or mapped > win.y:
		return -1
	return mapped - win.x


static func chart_lane_for_display_lane(display_lane: int, active_lanes: int, chart_lanes: int, modifiers: Array = []) -> int:
	var win := chart_lane_window(active_lanes, chart_lanes, modifiers)
	return win.x + display_lane


static func single_lane_alt_color(base: Color) -> Color:
	var h := base.h
	var s := base.s
	var v := base.v
	return Color.from_hsv(fmod(h + 0.52, 1.0), clampf(s * 0.82, 0.0, 1.0), clampf(v * 0.9, 0.0, 1.0))


static func expand_note_palette_for_single_lane(colors: Array) -> Array:
	if colors.is_empty():
		return colors
	var expanded: Array = []
	if colors.size() == 1:
		var base_hex := str(colors[0])
		var alt_hex := single_lane_alt_color(Color(base_hex)).to_html(false)
		for _i in range(5):
			expanded.append(base_hex)
		for _j in range(5):
			expanded.append(alt_hex)
		return expanded
	var count := mini(colors.size(), 5)
	for i in range(count):
		expanded.append(str(colors[i]))
	for i in range(count):
		expanded.append(single_lane_alt_color(Color(str(colors[i]))).to_html(false))
	while expanded.size() < 10:
		var tail := str(expanded[expanded.size() - 1])
		expanded.append(tail)
	return expanded.slice(0, 10)


static func build_single_lane_keymap(base: Dictionary, lane_count: int) -> Dictionary:
	var out := base.duplicate(true)
	var cap := clampi(lane_count, SINGLE_LANE_COUNT_MIN, SINGLE_LANE_MAX_LANES)
	if cap <= 5:
		return out
	var used_lanes: Dictionary = {}
	for sc in out:
		used_lanes[int(out[sc])] = true
	var candidates: Array = []
	candidates.append_array(SINGLE_LANE_EXTENDED_KEYS)
	candidates.append_array(SINGLE_LANE_FALLBACK_KEYS)
	for lane in range(5, cap):
		if used_lanes.has(lane):
			continue
		for sc in candidates:
			if out.has(sc):
				continue
			out[sc] = lane
			used_lanes[lane] = true
			break
	return out


static func single_lane_chart_lanes() -> int:
	return SINGLE_LANE_CHART_LANES


static func single_lane_strip(playfield_width: float) -> Dictionary:
	var chart_lanes := maxf(float(SINGLE_LANE_CHART_LANES), 1.0)
	var lane_w := playfield_width / chart_lanes
	var lane_idx := int(floor((chart_lanes - 1.0) * 0.5))
	return {"x": lane_idx * lane_w, "width": lane_w}


static func single_lane_note_width(playfield_width: float) -> float:
	return float(single_lane_strip(playfield_width).get("width", playfield_width))


static func single_lane_note_x(playfield_width: float) -> float:
	return float(single_lane_strip(playfield_width).get("x", 0.0))


static func is_chart_lane_playable(
	modifiers: Array,
	chart_lane: int,
	active_lanes: int,
	chart_lanes: int = -1,
	remap_ctx: Dictionary = {},
	params: Dictionary = {}
) -> bool:
	var chart := chart_lanes if chart_lanes > 0 else active_lanes
	if is_single_lane(modifiers):
		return chart_lane >= 0 and chart_lane < chart
	return display_lane_for_chart_lane(
		chart_lane, active_lanes, chart, modifiers, remap_ctx, params
	) >= 0


static func is_dynamic_lanes(modifiers: Array) -> bool:
	return has_modifier(modifiers, ID_DYNAMIC_LANES)


static func is_energy_pulse(modifiers: Array) -> bool:
	return has_modifier(modifiers, ID_ENERGY_PULSE)


static func is_density_focus(modifiers: Array) -> bool:
	return has_modifier(modifiers, ID_DENSITY_FOCUS)


static func is_phrase_shift(modifiers: Array) -> bool:
	return has_modifier(modifiers, ID_PHRASE_SHIFT)


static func is_groove_lock(modifiers: Array) -> bool:
	return has_modifier(modifiers, ID_GROOVE_LOCK)


static func is_adaptive(modifiers: Array) -> bool:
	return has_modifier(modifiers, ID_ADAPTIVE)


static func active_dna_behavior_id(modifiers: Array) -> String:
	for behavior_id in DNA_BEHAVIOR_IDS:
		if has_modifier(modifiers, behavior_id):
			return behavior_id
	return ""


static func has_dna_virtual_behavior(modifiers: Array) -> bool:
	return active_dna_behavior_id(modifiers) != ""


static func is_mirror_mode(modifiers: Array) -> bool:
	return has_modifier(modifiers, ID_MIRROR_MODE)


static func is_shuffle_mode(modifiers: Array) -> bool:
	return has_modifier(modifiers, ID_SHUFFLE_MODE)


static func is_random_mode(modifiers: Array) -> bool:
	return has_modifier(modifiers, ID_RANDOM_MODE)


static func is_combo_escalation(modifiers: Array) -> bool:
	return has_modifier(modifiers, ID_COMBO_ESCALATION)


static func is_metronome_only(modifiers: Array) -> bool:
	return has_modifier(modifiers, ID_METRONOME_ONLY)


static func is_heat(modifiers: Array) -> bool:
	return has_modifier(modifiers, ID_HEAT)


static func is_silence(modifiers: Array) -> bool:
	return has_modifier(modifiers, ID_SILENCE)


static func is_spotlight(modifiers: Array) -> bool:
	return has_modifier(modifiers, ID_SPOTLIGHT)


static func is_rush(modifiers: Array) -> bool:
	return has_modifier(modifiers, ID_RUSH)


static func is_last_chance(modifiers: Array) -> bool:
	return has_modifier(modifiers, ID_LAST_CHANCE)


static func is_groove_addiction(modifiers: Array) -> bool:
	return has_modifier(modifiers, ID_GROOVE_ADDICTION)


static func is_energy_balance(modifiers: Array) -> bool:
	return has_modifier(modifiers, ID_ENERGY_BALANCE)


static func heat_step_hits(total_notes: int, params: Dictionary = {}) -> int:
	var p := sanitize_params(params)
	if str(p.get("heat_step_mode", HEAT_STEP_MODE_DEFAULT)) == HEAT_STEP_MODE_CHART_PCT:
		var notes := maxi(total_notes, 1)
		var pct := float(p.get("heat_step_chart_pct", HEAT_STEP_CHART_PCT_DEFAULT)) / 100.0
		return maxi(HEAT_STEP_CHART_MIN_HITS, int(ceil(float(notes) * pct)))
	return maxi(int(p.get("heat_step_combo", HEAT_STEP_COMBO_DEFAULT)), 1)


static func heat_peak_hits(total_notes: int, params: Dictionary = {}) -> int:
	var p := sanitize_params(params)
	var step := heat_step_hits(total_notes, p)
	if str(p.get("heat_step_mode", HEAT_STEP_MODE_DEFAULT)) == HEAT_STEP_MODE_CHART_PCT:
		var notes := maxi(total_notes, 1)
		var pct := float(p.get("heat_peak_chart_pct", HEAT_PEAK_CHART_PCT_DEFAULT)) / 100.0
		return maxi(step, int(ceil(float(notes) * pct)))
	return maxi(int(p.get("heat_peak_combo", HEAT_PEAK_COMBO_DEFAULT)), step)


static func _heat_step_and_peak(total_notes: int, params: Dictionary) -> Vector2i:
	var p := sanitize_params(params)
	var combo_mode := (
		str(p.get("heat_step_mode", HEAT_STEP_MODE_DEFAULT)) != HEAT_STEP_MODE_CHART_PCT
	)
	if combo_mode:
		var step_combo := maxi(int(p.get("heat_step_combo", HEAT_STEP_COMBO_DEFAULT)), 1)
		var peak_combo := maxi(int(p.get("heat_peak_combo", HEAT_PEAK_COMBO_DEFAULT)), step_combo)
		return Vector2i(step_combo, peak_combo)
	var step := heat_step_hits(total_notes, p)
	var peak := heat_peak_hits(total_notes, p)
	return Vector2i(step, maxi(peak, step))


static func heat_scroll_multiplier(
	combo: int, params: Dictionary = {}, total_notes: int = 0
) -> float:
	var p := sanitize_params(params)
	var step_peak := _heat_step_and_peak(total_notes, p)
	var step := step_peak.x
	var peak := step_peak.y
	var max_mult := float(p.get("heat_max_speed_pct", HEAT_MAX_SPEED_PCT_DEFAULT)) / 100.0
	if combo <= 0 or is_equal_approx(max_mult, 1.0):
		return 1.0
	if combo >= peak:
		return max_mult
	var steps_total := maxf(ceilf(float(peak) / float(step)), 1.0)
	var step_idx := clampi(int(floorf(float(combo) / float(step))), 0, int(steps_total) - 1)
	var step_start := float(step_idx) * float(step)
	var step_end := minf(float(step_idx + 1) * float(step), float(peak))
	var local := 0.0
	if step_end > step_start:
		local = clampf((float(combo) - step_start) / (step_end - step_start), 0.0, 1.0)
	var progress := clampf(
		(float(step_idx) + _smoothstep_alpha(local)) / steps_total,
		0.0,
		1.0
	)
	return lerpf(1.0, max_mult, progress)


static func silence_interval_sec(params: Dictionary = {}, song_duration: float = 0.0) -> float:
	var p := sanitize_params(params)
	if (
		str(p.get("silence_schedule_mode", SILENCE_SCHEDULE_MODE_DEFAULT))
		== SILENCE_SCHEDULE_TRACK_PCT
	):
		if song_duration <= 0.01:
			return 0.0
		var pct := float(p.get("silence_interval_track_pct", SILENCE_INTERVAL_TRACK_PCT_DEFAULT))
		return song_duration * (pct / 100.0)
	return float(p.get("silence_interval_sec", SILENCE_INTERVAL_SEC_DEFAULT))


static func silence_window_duration_sec(window_index: int, params: Dictionary = {}) -> float:
	var p := sanitize_params(params)
	var min_d := float(p.get("silence_duration_min_sec", SILENCE_DURATION_MIN_SEC_DEFAULT))
	var max_d := float(p.get("silence_duration_max_sec", SILENCE_DURATION_MAX_SEC_DEFAULT))
	if max_d < min_d:
		max_d = min_d
	if is_equal_approx(min_d, max_d):
		return min_d
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("silence_duration|%d" % window_index)
	return lerpf(min_d, max_d, rng.randf())


static func silence_is_muted(
	song_time: float, params: Dictionary = {}, song_duration: float = 0.0
) -> bool:
	var interval := silence_interval_sec(params, song_duration)
	if interval <= 0.01 or song_time < interval:
		return false
	var window_idx := int(floor(song_time / interval)) - 1
	if window_idx < 0:
		return false
	var start := interval * float(window_idx + 1)
	if song_time < start:
		return false
	var dur := silence_window_duration_sec(window_idx, params)
	# Окно тишины всегда должно быть короче интервала, иначе окна перекрываются
	# и музыка глушится непрерывно («звук не возвращается»). Оставляем слышимый
	# промежуток минимум в 40% интервала.
	dur = minf(dur, interval * 0.6)
	return song_time < start + dur


static func silence_metronome_enabled(params: Dictionary = {}) -> bool:
	return bool(sanitize_params(params).get("silence_metronome", false))


static func spotlight_band_px(params: Dictionary = {}) -> float:
	return float(sanitize_params(params).get("spotlight_band_px", SPOTLIGHT_BAND_PX_DEFAULT))


static func spotlight_darkness_alpha(params: Dictionary = {}) -> float:
	var pct := float(
		sanitize_params(params).get("spotlight_darkness_pct", SPOTLIGHT_DARKNESS_PCT_DEFAULT)
	)
	return clampf(pct, SPOTLIGHT_DARKNESS_PCT_MIN, SPOTLIGHT_DARKNESS_PCT_MAX) / 100.0


static func rush_uses_bar_mode(params: Dictionary = {}) -> bool:
	return bool(sanitize_params(params).get("rush_bar_mode", true))


static func rush_effective_scroll_pct(params: Dictionary = {}) -> float:
	var p := sanitize_params(params)
	if rush_uses_bar_mode(p):
		return float(p.get("rush_scroll_pct_bars", RUSH_SCROLL_PCT_BARS_DEFAULT))
	return float(p.get("rush_scroll_pct_time", RUSH_SCROLL_PCT_TIME_DEFAULT))


static func build_rush_bursts(
	song_path: String,
	song_duration: float,
	params: Dictionary = {},
	bpm: float = 0.0
) -> Array:
	var p := sanitize_params(params)
	var burst_duration := float(p.get("rush_burst_duration_sec", RUSH_BURST_DURATION_SEC_DEFAULT))
	if rush_uses_bar_mode(p):
		var track_bpm := bpm
		if track_bpm <= 0.0:
			track_bpm = 120.0
		return _RushScrollSchedule.build_bursts_bar_aligned(
			song_path,
			track_bpm,
			song_duration,
			float(p.get("rush_bars_interval", RUSH_BARS_INTERVAL_DEFAULT)),
			burst_duration,
			int(round(float(p.get("rush_first_bar", RUSH_FIRST_BAR_DEFAULT))))
		)
	return _RushScrollSchedule.build_bursts_timed(
		song_path,
		song_duration,
		float(p.get("rush_time_interval_min_sec", RUSH_TIME_INTERVAL_MIN_DEFAULT)),
		float(p.get("rush_time_interval_max_sec", RUSH_TIME_INTERVAL_MAX_DEFAULT)),
		burst_duration
	)


static func heat_affects_song_speed(params: Dictionary = {}) -> bool:
	return bool(sanitize_params(params).get("heat_affect_song_speed", false))


static func rush_affects_song_speed(params: Dictionary = {}) -> bool:
	return bool(sanitize_params(params).get("rush_affect_song_speed", false))


static func rush_scroll_multiplier(
	bursts: Array, song_time: float, params: Dictionary = {}
) -> float:
	var p := sanitize_params(params)
	return _RushScrollSchedule.scroll_multiplier_at(
		bursts,
		song_time,
		rush_effective_scroll_pct(p),
		float(p.get("rush_ramp_sec", RUSH_RAMP_SEC_DEFAULT))
	)


static func energy_balance_timing_multiplier(
	schedule: Array, song_time: float, params: Dictionary = {}
) -> float:
	if schedule.is_empty():
		return 1.0
	var p := sanitize_params(params)
	return _EnergyBalanceSchedule.timing_multiplier_at(
		schedule,
		song_time,
		float(p.get("energy_balance_calm_pct", ENERGY_BALANCE_CALM_PCT_DEFAULT)),
		float(p.get("energy_balance_intense_pct", ENERGY_BALANCE_INTENSE_PCT_DEFAULT))
	)


static func groove_addiction_max_tier(params: Dictionary = {}) -> int:
	return int(
		sanitize_params(params).get("groove_addiction_max_tier", GROOVE_ADDICTION_MAX_TIER_DEFAULT)
	)


static func escalation_pool_blocked_by_player(player_modifiers: Array) -> Array[String]:
	var blocked: Array[String] = []
	var base := sanitize(player_modifiers)
	for easing_id in EASING_IDS:
		if not has_modifier(base, easing_id):
			continue
		var extra: Variant = ESCALATION_EASING_BLOCKS.get(easing_id, [])
		if extra is Array:
			for conflict_id in extra:
				var cid := str(conflict_id)
				if ESCALATION_POOL.has(cid) and not blocked.has(cid):
					blocked.append(cid)
	return blocked


static func pick_escalation_modifier(
	player_modifiers: Array,
	exclude_id: String,
	used_ids: Array,
	song_path: String,
	tier: int,
	run_seed: int = 0,
	params: Dictionary = {}
) -> String:
	if not is_combo_escalation(player_modifiers):
		return ""
	var p := sanitize_params(params)
	var pick_mode := str(p.get("combo_escalation_pick_mode", CE_PICK_MODE_DEFAULT))
	var easing_blocks := escalation_pool_blocked_by_player(player_modifiers)
	match pick_mode:
		CE_PICK_CUSTOM_ORDER:
			return _pick_escalation_custom_order(exclude_id, easing_blocks, tier, p)
		CE_PICK_RANDOM:
			return _pick_escalation_random(exclude_id, easing_blocks, tier, run_seed, p)
		_:
			return _pick_escalation_no_repeat(
				exclude_id, easing_blocks, used_ids, tier, run_seed, p
			)


static func _pick_escalation_custom_order(
	exclude_id: String,
	easing_blocks: Array,
	tier: int,
	params: Dictionary
) -> String:
	var order := sanitize_combo_escalation_order(params.get("combo_escalation_order", []))
	var pool := sanitize_combo_escalation_pool_enabled(params.get("combo_escalation_pool_enabled", []))
	if order.is_empty():
		return ""
	var start := tier % order.size()
	for offset in range(order.size()):
		var id := order[(start + offset) % order.size()]
		if id == exclude_id:
			continue
		if easing_blocks.has(id):
			continue
		if not pool.has(id):
			continue
		return id
	return ""


static func _pick_escalation_random(
	exclude_id: String,
	easing_blocks: Array,
	tier: int,
	run_seed: int,
	params: Dictionary
) -> String:
	var pool := sanitize_combo_escalation_pool_enabled(params.get("combo_escalation_pool_enabled", []))
	var candidates := _escalation_candidates(exclude_id, easing_blocks, [], false, pool)
	if candidates.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("combo_escalation|random|%d|%d" % [run_seed, tier])
	return candidates[rng.randi_range(0, candidates.size() - 1)]


static func _pick_escalation_no_repeat(
	exclude_id: String,
	easing_blocks: Array,
	used_ids: Array,
	tier: int,
	run_seed: int,
	params: Dictionary
) -> String:
	var pool := sanitize_combo_escalation_pool_enabled(params.get("combo_escalation_pool_enabled", []))
	var candidates := _escalation_candidates(exclude_id, easing_blocks, used_ids, true, pool)
	if candidates.is_empty():
		candidates = _escalation_candidates(exclude_id, easing_blocks, used_ids, false, pool)
	if candidates.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("combo_escalation|no_repeat|%d|%d" % [run_seed, tier])
	return candidates[rng.randi_range(0, candidates.size() - 1)]


static func _escalation_candidates(
	exclude_id: String,
	easing_blocks: Array,
	used_ids: Array,
	skip_used: bool,
	pool_enabled: Array = []
) -> Array[String]:
	var candidates: Array[String] = []
	var pool: Array[String] = []
	if pool_enabled is Array:
		for item in pool_enabled:
			pool.append(str(item))
	if pool.is_empty():
		pool = ESCALATION_POOL.duplicate()
	for id in ESCALATION_POOL:
		if not pool.has(id):
			continue
		if id == exclude_id:
			continue
		if easing_blocks.has(id):
			continue
		if skip_used and used_ids.has(id):
			continue
		candidates.append(id)
	return candidates


static func has_lane_remap(modifiers: Array) -> bool:
	for id in REMAP_IDS:
		if has_modifier(modifiers, id):
			return true
	return false


static func lane_remap_mode(modifiers: Array) -> String:
	if is_mirror_mode(modifiers):
		return _LaneRemap.MODE_MIRROR
	if is_shuffle_mode(modifiers):
		return _LaneRemap.MODE_SHUFFLE
	if is_random_mode(modifiers):
		return _LaneRemap.MODE_RANDOM
	return ""


static func active_lane_remap_id(modifiers: Array) -> String:
	for id in REMAP_IDS:
		if has_modifier(modifiers, id):
			return id
	return ""


static func remap_chart_lane(
	chart_lane: int,
	chart_lanes: int,
	modifiers: Array,
	remap_ctx: Dictionary = {}
) -> int:
	var mode := lane_remap_mode(modifiers)
	if mode == "":
		return chart_lane
	return _LaneRemap.remap_lane(
		chart_lane,
		chart_lanes,
		mode,
		str(remap_ctx.get("song_path", "")),
		active_lane_remap_id(modifiers),
		float(remap_ctx.get("note_time", 0.0)),
		float(remap_ctx.get("bpm", 120.0)),
		remap_ctx
	)


static func is_reverse_scroll(modifiers: Array) -> bool:
	return has_modifier(modifiers, ID_REVERSE_SCROLL)


static func is_memory_mode(modifiers: Array) -> bool:
	return has_modifier(modifiers, ID_MEMORY_MODE)


static func memory_chart_progress(note_time: float, song_duration: float) -> float:
	if song_duration <= 0.01:
		return 0.0
	return clampf(note_time / song_duration, 0.0, 1.0)


static func memory_phase_for_progress(progress: float) -> int:
	if progress < MEMORY_PHASE_FULL_END:
		return 0
	if progress < MEMORY_PHASE_REVEAL_500_END:
		return 1
	if progress < MEMORY_PHASE_REVEAL_300_END:
		return 2
	return 3


static func memory_reveal_ms_for_chart_progress(progress: float, params: Dictionary = {}) -> float:
	var max_ms := float(sanitize_params(params).get("memory_reveal_ms", MEMORY_REVEAL_MS_DEFAULT))
	var min_ms := maxf(MEMORY_REVEAL_MS_MIN, max_ms * 0.36)
	if progress < MEMORY_PHASE_FULL_END:
		return -1.0
	var t := (progress - MEMORY_PHASE_FULL_END) / maxf(1.0 - MEMORY_PHASE_FULL_END, 0.01)
	return lerpf(max_ms, min_ms, _smoothstep_alpha(clampf(t, 0.0, 1.0)))


static func memory_reveal_ms_for_note(
	note_progress: float,
	is_pattern_first_beat: bool,
	params: Dictionary = {}
) -> float:
	var base_ms := memory_reveal_ms_for_chart_progress(note_progress, params)
	if base_ms < 0.0:
		return -1.0
	if memory_phase_for_progress(note_progress) >= 3 and not is_pattern_first_beat:
		return maxf(MEMORY_REVEAL_MS_MIN, base_ms * 0.5)
	return base_ms


static func memory_reveal_sec_for_phase(phase: int, params: Dictionary = {}) -> float:
	var ms := float(sanitize_params(params).get("memory_reveal_ms", MEMORY_REVEAL_MS_DEFAULT))
	match phase:
		1:
			return ms / 1000.0
		2:
			return ms * 0.6 / 1000.0
		_:
			return -1.0


static func memory_spatial_alpha(
	note_y: float,
	hit_zone_y: float,
	playfield_h: float,
	song_progress: float,
	reverse_scroll: bool,
	params: Dictionary = {}
) -> float:
	if playfield_h <= 1.0 or song_progress < MEMORY_PHASE_FULL_END:
		return 1.0
	var t := (song_progress - MEMORY_PHASE_FULL_END) / maxf(1.0 - MEMORY_PHASE_FULL_END, 0.01)
	var blind_max := memory_spatial_blind_frac(params)
	var blind_px := lerpf(0.0, playfield_h * blind_max, clampf(t, 0.0, 1.0))
	var dist_to_line := absf(note_y - hit_zone_y)
	var fade_band := maxf(playfield_h * MEMORY_SPATIAL_FADE_FRAC, 40.0)
	if dist_to_line >= blind_px:
		return 1.0
	if dist_to_line <= blind_px - fade_band:
		return MEMORY_HIDDEN_ALPHA
	var spatial := clampf((dist_to_line - (blind_px - fade_band)) / fade_band, 0.0, 1.0)
	return lerpf(MEMORY_HIDDEN_ALPHA, 1.0, spatial)


static func memory_note_visibility_alpha(
	modifiers: Array,
	note: Variant,
	song_time: float,
	song_duration: float,
	note_y: float = 0.0,
	hit_zone_y: float = 0.0,
	playfield_h: float = 0.0,
	reverse_scroll: bool = false,
	params: Dictionary = {}
) -> float:
	if not is_memory_mode(modifiers):
		return 1.0
	if note == null:
		return 1.0
	if note.note_kind in ["HoldNote", "BassHoldNote", "BassSustainNote", "BassSlideNote"] and note.is_being_held:
		return 1.0
	var song_progress := memory_chart_progress(song_time, song_duration)
	var fade_sec := memory_fade_sec(params)
	var temporal := 1.0
	if float(note.memory_hide_at) >= 0.0 and song_time > float(note.memory_hide_at):
		var fade_elapsed := song_time - float(note.memory_hide_at)
		if fade_elapsed < fade_sec:
			var t := clampf(fade_elapsed / fade_sec, 0.0, 1.0)
			temporal = lerpf(1.0, MEMORY_HIDDEN_ALPHA, 1.0 - _smoothstep_alpha(1.0 - t))
		else:
			temporal = MEMORY_HIDDEN_ALPHA
	var spatial := memory_spatial_alpha(
		note_y, hit_zone_y, playfield_h, song_progress, reverse_scroll, params
	)
	return clampf(temporal * spatial, MEMORY_HIDDEN_ALPHA, 1.0)


static func sanitize(raw: Variant, keep_escalation_hardening: String = "") -> Array[String]:
	var out: Array[String] = []
	if raw is Array:
		for item in raw:
			var sid := str(item).strip_edges()
			if sid == "strum_mode":
				sid = ID_PICK_MODE
			if ALL_IDS.has(sid) and not out.has(sid):
				out.append(sid)
	if out.has(ID_EASY_WINDOWS) and out.has(ID_STRICT_TIMING):
		out.erase(ID_STRICT_TIMING)
	if out.has(ID_NO_FAIL) and out.has(ID_SUDDEN_DEATH):
		out.erase(ID_SUDDEN_DEATH)
	if out.has(ID_HIDDEN) and out.has(ID_SUDDEN):
		out.erase(ID_SUDDEN)
	if out.has(ID_SLOW_75) and out.has(ID_FAST_150):
		out.erase(ID_FAST_150)
	if out.has(ID_MEMORY_MODE):
		if out.has(ID_HIDDEN):
			out.erase(ID_HIDDEN)
		if out.has(ID_SUDDEN):
			out.erase(ID_SUDDEN)
	if out.has(ID_SPOTLIGHT):
		if out.has(ID_HIDDEN):
			out.erase(ID_HIDDEN)
		if out.has(ID_SUDDEN):
			out.erase(ID_SUDDEN)
		if out.has(ID_MEMORY_MODE):
			out.erase(ID_MEMORY_MODE)
	elif out.has(ID_HIDDEN) or out.has(ID_SUDDEN) or out.has(ID_MEMORY_MODE):
		out.erase(ID_SPOTLIGHT)
	if out.has(ID_SILENCE) and out.has(ID_METRONOME_ONLY):
		out.erase(ID_METRONOME_ONLY)
	if out.has(ID_HEAT) and out.has(ID_FAST_150):
		out.erase(ID_FAST_150)
	if out.has(ID_ENERGY_PULSE):
		if out.has(ID_TIME_WARP):
			out.erase(ID_TIME_WARP)
		if out.has(ID_SLOW_75):
			out.erase(ID_SLOW_75)
		if out.has(ID_FAST_150):
			out.erase(ID_FAST_150)
	if out.has(ID_DENSITY_FOCUS):
		if out.has(ID_HIDDEN):
			out.erase(ID_HIDDEN)
		if out.has(ID_SUDDEN):
			out.erase(ID_SUDDEN)
		if out.has(ID_MEMORY_MODE):
			out.erase(ID_MEMORY_MODE)
		if out.has(ID_SPOTLIGHT):
			out.erase(ID_SPOTLIGHT)
	elif out.has(ID_HIDDEN) or out.has(ID_SUDDEN) or out.has(ID_MEMORY_MODE) or out.has(ID_SPOTLIGHT):
		if out.has(ID_DENSITY_FOCUS):
			out.erase(ID_DENSITY_FOCUS)
	_sanitize_dna_behavior_mods(out)
	_sanitize_dna_groove_mods(out)
	if out.has(ID_ADAPTIVE):
		if out.has(ID_ENERGY_PULSE):
			out.erase(ID_ENERGY_PULSE)
		if out.has(ID_DENSITY_FOCUS):
			out.erase(ID_DENSITY_FOCUS)
	if out.has(ID_DYNAMIC_LANES) and out.has(ID_SINGLE_LANE):
		out.erase(ID_SINGLE_LANE)
	var kept_remap := false
	for rid in REMAP_IDS:
		if out.has(rid):
			if kept_remap:
				out.erase(rid)
			else:
				kept_remap = true
	if kept_remap:
		if out.has(ID_SINGLE_LANE):
			out.erase(ID_SINGLE_LANE)
		if out.has(ID_DYNAMIC_LANES):
			out.erase(ID_DYNAMIC_LANES)
	if out.has(ID_COMBO_ESCALATION):
		for hid in HARDENING_IDS:
			if hid == keep_escalation_hardening:
				continue
			out.erase(hid)
		for eid in EASING_IDS:
			out.erase(eid)
	elif _has_any_hardening(out) or _has_any_easing(out):
		out.erase(ID_COMBO_ESCALATION)
	if out.has(ID_RUSH) and out.has(ID_HEAT):
		out.erase(ID_HEAT)
	if out.has(ID_LAST_CHANCE):
		if out.has(ID_NO_FAIL):
			out.erase(ID_NO_FAIL)
		if out.has(ID_SUDDEN_DEATH):
			out.erase(ID_SUDDEN_DEATH)
	if out.has(ID_ENERGY_BALANCE):
		if out.has(ID_EASY_WINDOWS):
			out.erase(ID_EASY_WINDOWS)
		if out.has(ID_STRICT_TIMING):
			out.erase(ID_STRICT_TIMING)
		if out.has(ID_GROOVE_LOCK):
			out.erase(ID_GROOVE_LOCK)
		if out.has(ID_GROOVE_ADDICTION):
			out.erase(ID_GROOVE_ADDICTION)
		if out.has(ID_ADAPTIVE):
			out.erase(ID_ADAPTIVE)
	elif out.has(ID_GROOVE_ADDICTION) or out.has(ID_GROOVE_LOCK):
		if out.has(ID_ENERGY_BALANCE):
			out.erase(ID_ENERGY_BALANCE)
	return out


static func _has_any_easing(modifiers: Array) -> bool:
	for id in EASING_IDS:
		if modifiers.has(id):
			return true
	return false


static func _has_any_hardening(modifiers: Array) -> bool:
	for id in HARDENING_IDS:
		if modifiers.has(id):
			return true
	return false


static func _sanitize_dna_behavior_mods(out: Array) -> void:
	var kept := ""
	for behavior_id in DNA_BEHAVIOR_IDS:
		if not out.has(behavior_id):
			continue
		if kept == "":
			kept = behavior_id
		else:
			out.erase(behavior_id)
	if kept == "":
		return
	if out.has(ID_DENSITY_FOCUS):
		out.erase(ID_DENSITY_FOCUS)
	if out.has(ID_REVERSE_SCROLL):
		out.erase(ID_REVERSE_SCROLL)
	if out.has(ID_HIDDEN):
		out.erase(ID_HIDDEN)
	if out.has(ID_SUDDEN):
		out.erase(ID_SUDDEN)
	if out.has(ID_MEMORY_MODE):
		out.erase(ID_MEMORY_MODE)
	if out.has(ID_SPOTLIGHT):
		out.erase(ID_SPOTLIGHT)
	if out.has(ID_HEAT):
		out.erase(ID_HEAT)
	if kept == ID_GROOVE_LOCK and out.has(ID_STRICT_TIMING):
		out.erase(ID_STRICT_TIMING)
	if kept == ID_ADAPTIVE:
		if out.has(ID_TIME_WARP):
			out.erase(ID_TIME_WARP)
		if out.has(ID_SLOW_75):
			out.erase(ID_SLOW_75)
		if out.has(ID_FAST_150):
			out.erase(ID_FAST_150)


static func _sanitize_dna_groove_mods(out: Array) -> void:
	var kept := ""
	for groove_id in DNA_GROOVE_IDS:
		if not out.has(groove_id):
			continue
		if kept == "":
			kept = groove_id
		else:
			out.erase(groove_id)
	if kept == ID_GROOVE_LOCK and out.has(ID_STRICT_TIMING):
		out.erase(ID_STRICT_TIMING)
	if kept == ID_GROOVE_ADDICTION and out.has(ID_STRICT_TIMING):
		out.erase(ID_STRICT_TIMING)


static func _dna_visibility_conflict_ids() -> Array[String]:
	return [ID_HIDDEN, ID_SUDDEN, ID_MEMORY_MODE, ID_SPOTLIGHT]


static func _dna_behavior_conflict_ids(except_id: String = "") -> Array[String]:
	var out: Array[String] = []
	for behavior_id in DNA_BEHAVIOR_IDS:
		if behavior_id != except_id:
			out.append(behavior_id)
	return out


static func remap_conflict_ids(keep_id: String = "") -> Array[String]:
	var out: Array[String] = []
	for rid in REMAP_IDS:
		if rid != keep_id:
			out.append(rid)
	out.append(ID_SINGLE_LANE)
	out.append(ID_DYNAMIC_LANES)
	return out


static func card_selection_border_color(_modifier_id: String = "") -> Color:
	return Color(0.45, 0.72, 0.98, 1.0)


static func card_active_conflict_border_color() -> Color:
	return Color(0.95, 0.4, 0.38, 0.95)


static func modifiers_are_conflicting(modifier_a: String, modifier_b: String) -> bool:
	var a := str(modifier_a).strip_edges()
	var b := str(modifier_b).strip_edges()
	if a == "" or b == "" or a == b:
		return false
	for cid in ui_conflict_ids(a):
		if str(cid) == b:
			return true
	return false


static func ui_active_conflict_ids(active_modifiers: Array) -> Array[String]:
	var mods := sanitize(active_modifiers)
	var out: Array[String] = []
	for i in range(mods.size()):
		for j in range(i + 1, mods.size()):
			if not modifiers_are_conflicting(mods[i], mods[j]):
				continue
			for id in [mods[i], mods[j]]:
				if not out.has(id):
					out.append(id)
	return out


static func ui_conflict_highlight_ids(active_modifiers: Array) -> Array[String]:
	var mods := sanitize(active_modifiers)
	var out: Array[String] = []
	for active_id in mods:
		for cid in ui_conflict_ids(active_id):
			var sid := str(cid)
			if mods.has(sid):
				continue
			if not out.has(sid):
				out.append(sid)
	return out


static func has_modifier_in_list(modifiers: Array, modifier_id: String) -> bool:
	return has_modifier(sanitize(modifiers), modifier_id)


static func disable_modifier(modifiers: Array, modifier_id: String) -> Array[String]:
	var out := sanitize(modifiers)
	var sid := str(modifier_id).strip_edges()
	if out.has(sid):
		out.erase(sid)
	return out


static func enable_modifier(modifiers: Array, modifier_id: String) -> Array[String]:
	var sid := str(modifier_id).strip_edges()
	if not ALL_IDS.has(sid):
		return sanitize(modifiers)
	var out := sanitize(modifiers)
	if out.has(sid):
		return out
	if sid == ID_COMBO_ESCALATION:
		for id in HARDENING_IDS + EASING_IDS:
			out.erase(id)
	elif sid in HARDENING_IDS or sid in EASING_IDS:
		out.erase(ID_COMBO_ESCALATION)
	if sid == ID_EASY_WINDOWS:
		out.erase(ID_STRICT_TIMING)
		out.erase(ID_ENERGY_BALANCE)
	elif sid == ID_STRICT_TIMING:
		out.erase(ID_EASY_WINDOWS)
		out.erase(ID_GROOVE_LOCK)
		out.erase(ID_ADAPTIVE)
		out.erase(ID_GROOVE_ADDICTION)
		out.erase(ID_ENERGY_BALANCE)
	elif sid == ID_NO_FAIL:
		out.erase(ID_SUDDEN_DEATH)
		out.erase(ID_LAST_CHANCE)
	elif sid == ID_SUDDEN_DEATH:
		out.erase(ID_NO_FAIL)
		out.erase(ID_LAST_CHANCE)
	elif sid == ID_HIDDEN:
		out.erase(ID_SUDDEN)
		out.erase(ID_MEMORY_MODE)
		out.erase(ID_DENSITY_FOCUS)
		for bid in DNA_BEHAVIOR_IDS:
			out.erase(bid)
	elif sid == ID_SUDDEN:
		out.erase(ID_HIDDEN)
		out.erase(ID_MEMORY_MODE)
		out.erase(ID_DENSITY_FOCUS)
		for bid in DNA_BEHAVIOR_IDS:
			out.erase(bid)
	elif sid == ID_MEMORY_MODE:
		out.erase(ID_HIDDEN)
		out.erase(ID_SUDDEN)
		out.erase(ID_DENSITY_FOCUS)
		for bid in DNA_BEHAVIOR_IDS:
			out.erase(bid)
	elif sid == ID_DYNAMIC_LANES:
		out.erase(ID_SINGLE_LANE)
		for rid in remap_conflict_ids(""):
			out.erase(rid)
	elif sid == ID_SINGLE_LANE:
		out.erase(ID_DYNAMIC_LANES)
		for rid in remap_conflict_ids(""):
			out.erase(rid)
	elif sid in REMAP_IDS:
		for rid in remap_conflict_ids(sid):
			out.erase(rid)
		out.erase(ID_SINGLE_LANE)
		out.erase(ID_DYNAMIC_LANES)
	elif sid == ID_SLOW_75:
		out.erase(ID_FAST_150)
		out.erase(ID_ENERGY_PULSE)
	elif sid == ID_FAST_150:
		out.erase(ID_SLOW_75)
		out.erase(ID_ENERGY_PULSE)
	elif sid == ID_TIME_WARP:
		out.erase(ID_ENERGY_PULSE)
	elif sid == ID_ENERGY_PULSE:
		out.erase(ID_TIME_WARP)
		out.erase(ID_SLOW_75)
		out.erase(ID_FAST_150)
		out.erase(ID_ADAPTIVE)
	elif sid == ID_HEAT:
		for bid in DNA_BEHAVIOR_IDS:
			out.erase(bid)
		out.erase(ID_RUSH)
	elif sid == ID_RUSH:
		out.erase(ID_HEAT)
	elif sid == ID_DENSITY_FOCUS:
		out.erase(ID_HIDDEN)
		out.erase(ID_SUDDEN)
		out.erase(ID_MEMORY_MODE)
		out.erase(ID_SPOTLIGHT)
	elif sid == ID_PHRASE_SHIFT:
		for cid in _dna_behavior_conflict_ids(ID_PHRASE_SHIFT):
			out.erase(cid)
		out.erase(ID_REVERSE_SCROLL)
		out.erase(ID_HEAT)
		for vid in _dna_visibility_conflict_ids():
			out.erase(vid)
		out.erase(ID_DENSITY_FOCUS)
	elif sid == ID_GROOVE_LOCK:
		for cid in _dna_behavior_conflict_ids(ID_GROOVE_LOCK):
			out.erase(cid)
		out.erase(ID_GROOVE_ADDICTION)
		out.erase(ID_STRICT_TIMING)
		out.erase(ID_ENERGY_BALANCE)
		out.erase(ID_HEAT)
		for vid in _dna_visibility_conflict_ids():
			out.erase(vid)
		out.erase(ID_DENSITY_FOCUS)
	elif sid == ID_GROOVE_ADDICTION:
		out.erase(ID_GROOVE_LOCK)
		out.erase(ID_STRICT_TIMING)
		out.erase(ID_ENERGY_BALANCE)
		out.erase(ID_ADAPTIVE)
	elif sid == ID_ENERGY_BALANCE:
		out.erase(ID_EASY_WINDOWS)
		out.erase(ID_STRICT_TIMING)
		out.erase(ID_GROOVE_LOCK)
		out.erase(ID_GROOVE_ADDICTION)
		out.erase(ID_ADAPTIVE)
	elif sid == ID_ADAPTIVE:
		for cid in _dna_behavior_conflict_ids(ID_ADAPTIVE):
			out.erase(cid)
		out.erase(ID_GROOVE_ADDICTION)
		out.erase(ID_ENERGY_BALANCE)
		out.erase(ID_TIME_WARP)
		out.erase(ID_ENERGY_PULSE)
		out.erase(ID_SLOW_75)
		out.erase(ID_FAST_150)
		out.erase(ID_REVERSE_SCROLL)
		out.erase(ID_HEAT)
		out.erase(ID_STRICT_TIMING)
		for vid in _dna_visibility_conflict_ids():
			out.erase(vid)
		out.erase(ID_DENSITY_FOCUS)
	elif sid == ID_REVERSE_SCROLL:
		out.erase(ID_PHRASE_SHIFT)
		out.erase(ID_ADAPTIVE)
	elif sid == ID_SPOTLIGHT:
		out.erase(ID_HIDDEN)
		out.erase(ID_SUDDEN)
		out.erase(ID_MEMORY_MODE)
		for bid in DNA_BEHAVIOR_IDS:
			out.erase(bid)
		out.erase(ID_DENSITY_FOCUS)
	elif sid == ID_LAST_CHANCE:
		out.erase(ID_NO_FAIL)
		out.erase(ID_SUDDEN_DEATH)
	if not out.has(sid):
		out.append(sid)
	return sanitize(out)


static func toggle_modifier(modifiers: Array, modifier_id: String) -> Dictionary:
	var sid := str(modifier_id).strip_edges()
	if not ALL_IDS.has(sid):
		return {"modifiers": sanitize(modifiers), "enabled": false}
	var active := sanitize(modifiers)
	if has_modifier(active, sid):
		return {"modifiers": disable_modifier(active, sid), "enabled": false}
	return {"modifiers": enable_modifier(active, sid), "enabled": true}


static func ui_hover_conflict_ids(modifier_id: String) -> Array[String]:
	var out: Array[String] = []
	if modifier_id == "":
		return out
	for cid in ui_conflict_ids(modifier_id):
		var sid := str(cid)
		if sid != modifier_id and not out.has(sid):
			out.append(sid)
	return out


static func _dna_groove_conflict_ids(except_id: String = "") -> Array[String]:
	var out: Array[String] = []
	for groove_id in DNA_GROOVE_IDS:
		if groove_id != except_id:
			out.append(groove_id)
	return out


static func ui_conflict_ids(modifier_id: String) -> Array:
	match modifier_id:
		ID_EASY_WINDOWS:
			return [ID_STRICT_TIMING, ID_COMBO_ESCALATION, ID_ENERGY_BALANCE]
		ID_STRICT_TIMING:
			return [
				ID_EASY_WINDOWS,
				ID_COMBO_ESCALATION,
				ID_GROOVE_LOCK,
				ID_GROOVE_ADDICTION,
				ID_ENERGY_BALANCE,
				ID_ADAPTIVE,
			]
		ID_NO_FAIL:
			return [ID_SUDDEN_DEATH, ID_LAST_CHANCE, ID_COMBO_ESCALATION]
		ID_SUDDEN_DEATH:
			return [ID_NO_FAIL, ID_LAST_CHANCE, ID_COMBO_ESCALATION]
		ID_HIDDEN:
			var hd_out: Array = [ID_SUDDEN, ID_MEMORY_MODE, ID_COMBO_ESCALATION, ID_SPOTLIGHT, ID_DENSITY_FOCUS]
			hd_out.append_array(_dna_behavior_conflict_ids())
			return hd_out
		ID_SUDDEN:
			var sn_out: Array = [ID_HIDDEN, ID_MEMORY_MODE, ID_COMBO_ESCALATION, ID_SPOTLIGHT, ID_DENSITY_FOCUS]
			sn_out.append_array(_dna_behavior_conflict_ids())
			return sn_out
		ID_MEMORY_MODE:
			var mm_out: Array = [ID_HIDDEN, ID_SUDDEN, ID_COMBO_ESCALATION, ID_SPOTLIGHT, ID_DENSITY_FOCUS]
			mm_out.append_array(_dna_behavior_conflict_ids())
			return mm_out
		ID_DYNAMIC_LANES:
			var dl_out: Array = [ID_SINGLE_LANE, ID_COMBO_ESCALATION]
			dl_out.append_array(remap_conflict_ids(""))
			dl_out.erase(ID_DYNAMIC_LANES)
			return dl_out
		ID_SINGLE_LANE:
			var sl_out: Array = [ID_DYNAMIC_LANES, ID_COMBO_ESCALATION]
			sl_out.append_array(remap_conflict_ids(""))
			sl_out.erase(ID_SINGLE_LANE)
			return sl_out
		ID_MIRROR_MODE:
			var mr_out: Array = [ID_COMBO_ESCALATION]
			mr_out.append_array(remap_conflict_ids(ID_MIRROR_MODE))
			return mr_out
		ID_SHUFFLE_MODE:
			var sf_out: Array = [ID_COMBO_ESCALATION]
			sf_out.append_array(remap_conflict_ids(ID_SHUFFLE_MODE))
			return sf_out
		ID_RANDOM_MODE:
			var rn_out: Array = [ID_COMBO_ESCALATION]
			rn_out.append_array(remap_conflict_ids(ID_RANDOM_MODE))
			return rn_out
		ID_SLOW_75:
			return [ID_FAST_150, ID_COMBO_ESCALATION, ID_HEAT, ID_ENERGY_PULSE]
		ID_FAST_150:
			return [ID_SLOW_75, ID_COMBO_ESCALATION, ID_HEAT, ID_ENERGY_PULSE]
		ID_HEAT:
			var he_out: Array = [ID_SLOW_75, ID_FAST_150, ID_COMBO_ESCALATION, ID_RUSH]
			he_out.append_array(_dna_behavior_conflict_ids())
			return he_out
		ID_RUSH:
			return [ID_HEAT, ID_COMBO_ESCALATION]
		ID_LAST_CHANCE:
			return [ID_NO_FAIL, ID_SUDDEN_DEATH, ID_COMBO_ESCALATION]
		ID_REVERSE_SCROLL:
			return [ID_PHRASE_SHIFT, ID_ADAPTIVE]
		ID_TIME_WARP:
			return [ID_ENERGY_PULSE]
		ID_ENERGY_PULSE:
			return [ID_TIME_WARP, ID_SLOW_75, ID_FAST_150, ID_ADAPTIVE]
		ID_DENSITY_FOCUS:
			var df_out: Array = [ID_HIDDEN, ID_SUDDEN, ID_MEMORY_MODE, ID_SPOTLIGHT]
			df_out.append_array(_dna_behavior_conflict_ids())
			return df_out
		ID_PHRASE_SHIFT:
			var ps_out: Array = _dna_behavior_conflict_ids(ID_PHRASE_SHIFT)
			ps_out.append_array([ID_REVERSE_SCROLL, ID_HEAT, ID_DENSITY_FOCUS])
			ps_out.append_array(_dna_visibility_conflict_ids())
			return ps_out
		ID_GROOVE_LOCK:
			var gl_out: Array = _dna_behavior_conflict_ids(ID_GROOVE_LOCK)
			gl_out.append_array([
				ID_GROOVE_ADDICTION,
				ID_ENERGY_BALANCE,
				ID_STRICT_TIMING,
				ID_HEAT,
				ID_DENSITY_FOCUS,
			])
			gl_out.append_array(_dna_visibility_conflict_ids())
			return gl_out
		ID_GROOVE_ADDICTION:
			return [
				ID_GROOVE_LOCK,
				ID_ENERGY_BALANCE,
				ID_STRICT_TIMING,
				ID_ADAPTIVE,
				ID_COMBO_ESCALATION,
			]
		ID_ENERGY_BALANCE:
			return [
				ID_EASY_WINDOWS,
				ID_STRICT_TIMING,
				ID_GROOVE_LOCK,
				ID_GROOVE_ADDICTION,
				ID_ADAPTIVE,
				ID_COMBO_ESCALATION,
			]
		ID_ADAPTIVE:
			var ad_out: Array = _dna_behavior_conflict_ids(ID_ADAPTIVE)
			ad_out.append_array([
				ID_TIME_WARP,
				ID_ENERGY_PULSE,
				ID_SLOW_75,
				ID_FAST_150,
				ID_REVERSE_SCROLL,
				ID_HEAT,
				ID_STRICT_TIMING,
				ID_DENSITY_FOCUS,
				ID_GROOVE_ADDICTION,
				ID_ENERGY_BALANCE,
			])
			ad_out.append_array(_dna_visibility_conflict_ids())
			return ad_out
		ID_SILENCE:
			return [ID_METRONOME_ONLY, ID_COMBO_ESCALATION]
		ID_METRONOME_ONLY:
			return [ID_SILENCE, ID_COMBO_ESCALATION]
		ID_SPOTLIGHT:
			var sp_out: Array = [
				ID_HIDDEN,
				ID_SUDDEN,
				ID_MEMORY_MODE,
				ID_COMBO_ESCALATION,
				ID_DENSITY_FOCUS,
			]
			sp_out.append_array(_dna_behavior_conflict_ids())
			return sp_out
		ID_COMBO_ESCALATION:
			var ce_out: Array[String] = HARDENING_IDS.duplicate()
			ce_out.append_array(EASING_IDS)
			return ce_out
		ID_NO_MISS_FORGIVENESS, ID_HALF_HP:
			return [ID_COMBO_ESCALATION]
		_:
			return []


static func format_speed_mult_pct(pct: float) -> String:
	return "%d%%" % int(round(pct))


static func _conflict_set_has_all(pending: Dictionary, ids: Array) -> bool:
	for id in ids:
		if not pending.has(str(id)):
			return false
	return true


static func ui_conflict_display_lines(modifier_id: String) -> Array[String]:
	if modifier_id == ID_COMBO_ESCALATION:
		return [
			TranslationServer.translate("MOD_CONFLICT_ALL_EASING"),
			TranslationServer.translate("MOD_CONFLICT_ALL_HARDENING"),
		]
	var raw: Array = ui_conflict_ids(modifier_id)
	if raw.is_empty():
		return []
	var pending: Dictionary = {}
	for id in raw:
		pending[str(id)] = true
	pending.erase(modifier_id)
	var lines: Array[String] = []
	if pending.has(ID_COMBO_ESCALATION):
		lines.append(TranslationServer.translate("MOD_CONFLICT_COMBO_ESCALATION"))
		pending.erase(ID_COMBO_ESCALATION)
	if _conflict_set_has_all(pending, EASING_IDS):
		lines.append(TranslationServer.translate("MOD_CONFLICT_ALL_EASING"))
		for id in EASING_IDS:
			pending.erase(str(id))
	if _conflict_set_has_all(pending, HARDENING_IDS):
		lines.append(TranslationServer.translate("MOD_CONFLICT_ALL_HARDENING"))
		for id in HARDENING_IDS:
			pending.erase(str(id))
	var behavior_count := 0
	for id in DNA_BEHAVIOR_IDS:
		if pending.has(id):
			behavior_count += 1
	if behavior_count >= 2:
		lines.append(TranslationServer.translate("MOD_CONFLICT_DNA_BEHAVIOR"))
		for id in DNA_BEHAVIOR_IDS:
			pending.erase(str(id))
	var groove_count := 0
	for id in DNA_GROOVE_IDS:
		if pending.has(id):
			groove_count += 1
	if groove_count >= 2:
		lines.append(TranslationServer.translate("MOD_CONFLICT_DNA_GROOVE"))
		for id in DNA_GROOVE_IDS:
			pending.erase(str(id))
	var remaining: Array[String] = []
	for id in pending.keys():
		remaining.append(str(id))
	remaining.sort()
	for id in remaining:
		lines.append(TranslationServer.translate(title_i18n_key(id)))
	return lines


static func sanitize_for_lanes(modifiers: Array, total_lanes: int) -> Array[String]:
	var out := sanitize(modifiers)
	if total_lanes <= 1 and out.has(ID_SINGLE_LANE):
		out.erase(ID_SINGLE_LANE)
	return out


static func has_modifier(modifiers: Array, modifier_id: String) -> bool:
	return modifiers.has(modifier_id)


static func timing_window_base_perfect(modifier_id: String) -> float:
	match modifier_id:
		ID_EASY_WINDOWS:
			return WINDOW_PERFECT_EASY
		ID_STRICT_TIMING:
			return WINDOW_PERFECT_STRICT
		_:
			return WINDOW_PERFECT_DEFAULT


static func timing_window_base_good(modifier_id: String) -> float:
	match modifier_id:
		ID_EASY_WINDOWS:
			return WINDOW_GOOD_EASY
		ID_STRICT_TIMING:
			return WINDOW_GOOD_STRICT
		_:
			return WINDOW_GOOD_DEFAULT


static func timing_window_pct_for_modifier(modifier_id: String, params: Dictionary) -> float:
	var p := sanitize_params(params)
	match modifier_id:
		ID_EASY_WINDOWS:
			return float(p.get("easy_timing_window_pct", TIMING_WINDOW_PCT_DEFAULT))
		ID_STRICT_TIMING:
			return float(p.get("strict_timing_window_pct", TIMING_WINDOW_PCT_DEFAULT))
		_:
			return float(p.get("timing_window_pct", TIMING_WINDOW_PCT_DEFAULT))


static func timing_window_perfect_ms(modifier_id: String, pct: float) -> int:
	return int(round(timing_window_base_perfect(modifier_id) * (pct / 100.0) * 1000.0))


static func timing_window_good_ms(modifier_id: String, pct: float) -> int:
	return int(round(timing_window_base_good(modifier_id) * (pct / 100.0) * 1000.0))


static func format_timing_windows_label(modifier_id: String, pct: float) -> String:
	return TranslationServer.translate("MOD_TIMING_WINDOWS_MS") % [
		timing_window_perfect_ms(modifier_id, pct),
		timing_window_good_ms(modifier_id, pct),
	]


static func format_timing_window_bound_ms(modifier_id: String, pct: float) -> String:
	return TranslationServer.translate("MOD_TIMING_WINDOW_PERFECT_MS") % timing_window_perfect_ms(
		modifier_id, pct
	)


static func hit_window_perfect(modifiers: Array, params: Dictionary = {}) -> float:
	var base := WINDOW_PERFECT_DEFAULT
	var mult_pct := TIMING_WINDOW_PCT_DEFAULT
	if has_modifier(modifiers, ID_EASY_WINDOWS):
		base = WINDOW_PERFECT_EASY
		mult_pct = timing_window_pct_for_modifier(ID_EASY_WINDOWS, params)
	elif has_modifier(modifiers, ID_STRICT_TIMING):
		base = WINDOW_PERFECT_STRICT
		mult_pct = timing_window_pct_for_modifier(ID_STRICT_TIMING, params)
	else:
		mult_pct = float(sanitize_params(params).get("timing_window_pct", TIMING_WINDOW_PCT_DEFAULT))
	return base * (mult_pct / 100.0)


static func hit_window_good(modifiers: Array, params: Dictionary = {}) -> float:
	var base := WINDOW_GOOD_DEFAULT
	var mult_pct := TIMING_WINDOW_PCT_DEFAULT
	if has_modifier(modifiers, ID_EASY_WINDOWS):
		base = WINDOW_GOOD_EASY
		mult_pct = timing_window_pct_for_modifier(ID_EASY_WINDOWS, params)
	elif has_modifier(modifiers, ID_STRICT_TIMING):
		base = WINDOW_GOOD_STRICT
		mult_pct = timing_window_pct_for_modifier(ID_STRICT_TIMING, params)
	else:
		mult_pct = float(sanitize_params(params).get("timing_window_pct", TIMING_WINDOW_PCT_DEFAULT))
	return base * (mult_pct / 100.0)


static func effective_scroll_speed(modifiers: Array, settings_speed: float, params: Dictionary = {}) -> float:
	var p := sanitize_params(params)
	if str(p.get("scroll_speed_mode", "settings")) == "fixed":
		return float(p.get("scroll_speed_value", FIXED_SCROLL_SPEED))
	if has_modifier(modifiers, ID_FIXED_SPEED_20):
		return FIXED_SCROLL_SPEED
	var scroll := settings_speed * (
		float(p.get("scroll_speed_mult_pct", SCROLL_SPEED_MULT_DEFAULT)) / 100.0
	)
	return scroll


static func visibility_band_px(params: Dictionary = {}) -> float:
	return float(sanitize_params(params).get("visibility_band_px", VISIBILITY_BAND_PX))


static func time_warp_playback_multiplier(
	modifiers: Array,
	song_time: float,
	song_duration: float,
	params: Dictionary = {}
) -> float:
	if not has_modifier(modifiers, ID_TIME_WARP):
		return 1.0
	if song_duration <= 0.01:
		return 1.0
	var p := sanitize_params(params)
	var min_mult := float(p.get("time_warp_min_pct", TIME_WARP_MIN_PCT_DEFAULT)) / 100.0
	var max_mult := float(p.get("time_warp_max_pct", TIME_WARP_MAX_PCT_DEFAULT)) / 100.0
	var t := clampf(song_time / song_duration, 0.0, 1.0)
	var eased := _smoothstep_alpha(t)
	return lerpf(min_mult, max_mult, eased)


static func energy_pulse_playback_multiplier(
	schedule: Array,
	song_time: float,
	params: Dictionary = {}
) -> float:
	if schedule.is_empty():
		return 1.0
	var p := sanitize_params(params)
	var min_pct := float(p.get("energy_pulse_min_pct", ENERGY_PULSE_MIN_PCT_DEFAULT))
	var max_pct := float(p.get("energy_pulse_max_pct", ENERGY_PULSE_MAX_PCT_DEFAULT))
	return _EnergyPulseSchedule.playback_multiplier_at(schedule, song_time, min_pct, max_pct)


static func density_focus_intensity(schedule: Array, song_time: float) -> float:
	if schedule.is_empty():
		return 0.0
	return _DensityFocusSchedule.intensity_at(schedule, song_time)


static func density_focus_scroll_multiplier(
	schedule: Array,
	song_time: float,
	params: Dictionary = {}
) -> float:
	var intensity := density_focus_intensity(schedule, song_time)
	if intensity <= 0.001:
		return 1.0
	var p := sanitize_params(params)
	var max_pct := float(p.get("density_focus_scroll_pct", DENSITY_FOCUS_SCROLL_PCT_DEFAULT))
	return lerpf(1.0, max_pct / 100.0, intensity)


static func density_focus_visibility_alpha(
	modifiers: Array,
	dist_to_hit_line_px: float,
	song_time: float,
	schedule: Array,
	params: Dictionary = {}
) -> float:
	if not is_density_focus(modifiers):
		return 1.0
	var intensity := density_focus_intensity(schedule, song_time)
	if intensity <= 0.001:
		return 1.0
	var p := sanitize_params(params)
	var band := float(p.get("density_focus_band_px", DENSITY_FOCUS_BAND_PX_DEFAULT))
	var hidden_alpha := _smoothstep_alpha(absf(dist_to_hit_line_px) / band)
	return lerpf(1.0, hidden_alpha, intensity)


static func build_dna_virtual_schedule(
	mod_id: String,
	dna: Dictionary,
	song_duration: float,
	notes: Array,
	params: Dictionary = {}
) -> Array:
	return _DnaVirtualEffects.build_schedule(
		mod_id, dna, song_duration, notes, sanitize_params(params)
	)


static func dna_virtual_state(schedule: Array, song_time: float) -> Dictionary:
	return _DnaVirtualEffects.virtual_at(schedule, song_time)


static func dna_virtual_visibility_alpha(virtual: Dictionary, dist_to_hit_line_px: float) -> float:
	var band := float(virtual.get("hidden_band_px", 0.0))
	if band <= 0.01:
		return 1.0
	return _smoothstep_alpha(absf(dist_to_hit_line_px) / band)


static func dna_virtual_hit_window_perfect(base: float, virtual: Dictionary) -> float:
	var pct := float(virtual.get("timing_pct", 100.0))
	if pct >= 99.9:
		return base
	return minf(base, WINDOW_PERFECT_STRICT * (pct / 100.0))


static func dna_virtual_hit_window_good(base: float, virtual: Dictionary) -> float:
	var pct := float(virtual.get("timing_pct", 100.0))
	if pct >= 99.9:
		return base
	return minf(base, WINDOW_GOOD_STRICT * (pct / 100.0))


static func modifier_has_detail_params(modifier_id: String) -> bool:
	return modifier_id in [
		ID_SLOW_75,
		ID_FAST_150,
		ID_FIXED_SPEED_20,
		ID_EASY_WINDOWS,
		ID_STRICT_TIMING,
		ID_HIDDEN,
		ID_SUDDEN,
		ID_HALF_HP,
		ID_MEMORY_MODE,
		ID_TIME_WARP,
		ID_ENERGY_PULSE,
		ID_DENSITY_FOCUS,
		ID_PHRASE_SHIFT,
		ID_GROOVE_LOCK,
		ID_ADAPTIVE,
		ID_DYNAMIC_LANES,
		ID_RANDOM_MODE,
		ID_COMBO_ESCALATION,
		ID_HEAT,
		ID_SPOTLIGHT,
		ID_SILENCE,
		ID_RUSH,
		ID_GROOVE_ADDICTION,
		ID_ENERGY_BALANCE,
		ID_SINGLE_LANE,
	]


static func modifier_detail_param_keys(modifier_id: String) -> Array[String]:
	match modifier_id:
		ID_SLOW_75:
			return ["slow_75_speed_pct", "slow_75_preserve_pitch"]
		ID_FAST_150:
			return ["fast_150_speed_pct", "fast_150_preserve_pitch"]
		ID_FIXED_SPEED_20:
			return ["scroll_speed_value"]
		ID_EASY_WINDOWS:
			return ["easy_timing_window_pct"]
		ID_STRICT_TIMING:
			return ["strict_timing_window_pct"]
		ID_HIDDEN, ID_SUDDEN:
			return ["visibility_band_px"]
		ID_HALF_HP:
			return ["half_hp_start_pct"]
		ID_MEMORY_MODE:
			return ["memory_reveal_ms", "memory_spatial_blind_pct", "memory_fade_ms"]
		ID_TIME_WARP:
			return ["time_warp_min_pct", "time_warp_max_pct"]
		ID_ENERGY_PULSE:
			return ["energy_pulse_min_pct", "energy_pulse_max_pct"]
		ID_DENSITY_FOCUS:
			return ["density_focus_scroll_pct", "density_focus_band_px"]
		ID_PHRASE_SHIFT:
			return ["phrase_shift_heat_scroll_pct", "phrase_shift_hidden_band_px"]
		ID_GROOVE_LOCK:
			return ["groove_lock_scroll_pct", "groove_lock_timing_pct", "groove_lock_band_px"]
		ID_ADAPTIVE:
			return ["adaptive_heat_scroll_pct", "adaptive_hidden_band_px", "adaptive_speed_pct"]
		ID_DYNAMIC_LANES, ID_RANDOM_MODE:
			return ["lane_remap_min_interval_sec"]
		ID_COMBO_ESCALATION:
			return [
				"combo_escalation_step_pct",
				"combo_escalation_step_min",
				"combo_escalation_pick_mode",
				"combo_escalation_order",
				"combo_escalation_pool_enabled",
			]
		ID_HEAT:
			return [
				"heat_step_mode",
				"heat_step_combo",
				"heat_step_chart_pct",
				"heat_peak_combo",
				"heat_peak_chart_pct",
				"heat_max_speed_pct",
				"heat_affect_song_speed",
				"heat_preserve_pitch",
			]
		ID_SILENCE:
			return [
				"silence_schedule_mode",
				"silence_interval_sec",
				"silence_interval_track_pct",
				"silence_duration_min_sec",
				"silence_duration_max_sec",
				"silence_metronome",
			]
		ID_SPOTLIGHT:
			return ["spotlight_band_px", "spotlight_darkness_pct"]
		ID_RUSH:
			return [
				"rush_bar_mode",
				"rush_bars_interval",
				"rush_first_bar",
				"rush_time_interval_min_sec",
				"rush_time_interval_max_sec",
				"rush_burst_duration_sec",
				"rush_scroll_pct_bars",
				"rush_scroll_pct_time",
				"rush_ramp_sec",
				"rush_affect_song_speed",
				"rush_preserve_pitch",
			]
		ID_ENERGY_BALANCE:
			return ["energy_balance_calm_pct", "energy_balance_intense_pct"]
		ID_GROOVE_ADDICTION:
			return [
				"groove_addiction_scroll_pct",
				"groove_addiction_timing_pct",
				"groove_addiction_max_tier",
			]
		ID_SINGLE_LANE:
			return ["single_lane_count"]
		_:
			return []


static func _param_value_equal(a: Variant, b: Variant) -> bool:
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if str(a[i]) != str(b[i]):
				return false
		return true
	if a is float or b is float:
		return is_equal_approx(float(a), float(b))
	return a == b


static func modifier_params_customized(modifier_id: String, params: Dictionary) -> bool:
	if not modifier_has_detail_params(modifier_id):
		return false
	var defaults := default_params()
	var p := sanitize_params(params)
	for key in modifier_detail_param_keys(modifier_id):
		if key == "scroll_speed_mode":
			if str(p.get(key, "settings")) != "fixed":
				return true
			continue
		if not defaults.has(key):
			continue
		if not _param_value_equal(p.get(key), defaults.get(key)):
			return true
	return false


static func modifier_difficulty_stars(modifier_id: String, params: Dictionary = {}) -> int:
	var base := _modifier_difficulty_stars_base(modifier_id)
	var p := sanitize_params(params)
	match modifier_id:
		ID_SLOW_75:
			var spd := float(p.get("slow_75_speed_pct", SLOW_75_SPEED_DEFAULT))
			if spd <= 50.0:
				return maxi(base - 1, 1)
			if spd >= 90.0:
				return mini(base + 1, 5)
		ID_FAST_150:
			var spd := float(p.get("fast_150_speed_pct", FAST_150_SPEED_DEFAULT))
			if spd >= 200.0:
				return mini(base + 1, 5)
			if spd <= 120.0:
				return maxi(base - 1, 1)
		ID_STRICT_TIMING:
			var pct := float(p.get("strict_timing_window_pct", TIMING_WINDOW_PCT_DEFAULT))
			if pct >= 120.0:
				return maxi(base - 1, 1)
			if pct <= 80.0:
				return mini(base + 1, 5)
		ID_EASY_WINDOWS:
			var pct := float(p.get("easy_timing_window_pct", TIMING_WINDOW_PCT_DEFAULT))
			if pct >= 120.0:
				return maxi(base - 1, 1)
			if pct <= 80.0:
				return mini(base + 1, 5)
		ID_MEMORY_MODE:
			var reveal := float(p.get("memory_reveal_ms", MEMORY_REVEAL_MS_DEFAULT))
			if reveal <= 300.0:
				return mini(base + 1, 5)
		ID_HALF_HP:
			var hp := float(p.get("half_hp_start_pct", HALF_HP_START_PCT_DEFAULT))
			if hp <= 35.0:
				return mini(base + 1, 5)
	return base


static func _modifier_difficulty_stars_base(modifier_id: String) -> int:
	match modifier_id:
		ID_SUDDEN_DEATH:
			return 5
		ID_STRICT_TIMING, ID_FAST_150, ID_SUDDEN:
			return 4
		ID_HIDDEN:
			return 3
		ID_HALF_HP:
			return 2
		ID_SINGLE_LANE:
			return 3
		ID_TIME_WARP:
			return 3
		ID_ENERGY_PULSE:
			return 3
		ID_DENSITY_FOCUS:
			return 4
		ID_PHRASE_SHIFT:
			return 4
		ID_GROOVE_LOCK:
			return 4
		ID_ADAPTIVE:
			return 5
		ID_REVERSE_SCROLL:
			return 3
		ID_DYNAMIC_LANES:
			return 5
		ID_MEMORY_MODE:
			return 5
		ID_HEAT, ID_SILENCE, ID_RUSH:
			return 4
		ID_SPOTLIGHT:
			return 3
		ID_GROOVE_ADDICTION:
			return 4
		ID_ENERGY_BALANCE:
			return 4
		ID_LAST_CHANCE:
			return 3
		ID_PICK_MODE:
			return 2
		ID_AUTOPLAY:
			return 0
		ID_NO_FAIL, ID_EASY_WINDOWS, ID_SLOW_75:
			return 1
		_:
			return 2


static func _reward_pct_deviation(
	value: float,
	default: float,
	min_value: float,
	max_value: float,
	harder_when_below_default: bool
) -> float:
	if is_equal_approx(default, 0.0) or is_equal_approx(min_value, max_value):
		return 0.0
	var span := maxf(absf(default - min_value), absf(max_value - default))
	if span <= 0.0001:
		return 0.0
	var raw := (value - default) / span
	if harder_when_below_default:
		raw = -raw
	return clampf(raw, -1.0, 1.0)


static func _reward_scale_from_deviation(deviation: float) -> float:
	return clampf(1.0 + deviation * PARAM_REWARD_STRENGTH, 0.78, 1.24)


static func _reward_scale_from_float(
	value: float,
	default: float,
	min_value: float,
	max_value: float,
	harder_when_below_default: bool
) -> float:
	var deviation := _reward_pct_deviation(
		value, default, min_value, max_value, harder_when_below_default
	)
	return _reward_scale_from_deviation(deviation)


static func _combine_reward_scales(scales: Array) -> float:
	if scales.is_empty():
		return 1.0
	var sum := 0.0
	for scale in scales:
		sum += float(scale)
	return clampf(sum / float(scales.size()), 0.78, 1.24)


static func _param_reward_scale(modifier_id: String, params: Dictionary) -> float:
	if not modifier_has_detail_params(modifier_id):
		return 1.0
	if absf(float(REWARD_DELTA.get(modifier_id, 0.0))) <= 0.0001:
		return 1.0
	var p := sanitize_params(params)
	match modifier_id:
		ID_STRICT_TIMING:
			return _reward_scale_from_float(
				float(p.get("strict_timing_window_pct", TIMING_WINDOW_PCT_DEFAULT)),
				TIMING_WINDOW_PCT_DEFAULT,
				TIMING_WINDOW_PCT_MIN,
				TIMING_WINDOW_PCT_MAX,
				true
			)
		ID_EASY_WINDOWS:
			return _reward_scale_from_float(
				float(p.get("easy_timing_window_pct", TIMING_WINDOW_PCT_DEFAULT)),
				TIMING_WINDOW_PCT_DEFAULT,
				TIMING_WINDOW_PCT_MIN,
				TIMING_WINDOW_PCT_MAX,
				false
			)
		ID_HIDDEN, ID_SUDDEN:
			return _reward_scale_from_float(
				float(p.get("visibility_band_px", VISIBILITY_BAND_PX)),
				VISIBILITY_BAND_PX,
				VISIBILITY_BAND_MIN,
				VISIBILITY_BAND_MAX,
				true
			)
		ID_HALF_HP:
			return _reward_scale_from_float(
				float(p.get("half_hp_start_pct", HALF_HP_START_PCT_DEFAULT)),
				HALF_HP_START_PCT_DEFAULT,
				HALF_HP_START_PCT_MIN,
				HALF_HP_START_PCT_MAX,
				true
			)
		ID_MEMORY_MODE:
			return _combine_reward_scales([
				_reward_scale_from_float(
					float(p.get("memory_reveal_ms", MEMORY_REVEAL_MS_DEFAULT)),
					MEMORY_REVEAL_MS_DEFAULT,
					MEMORY_REVEAL_MS_MIN,
					MEMORY_REVEAL_MS_MAX,
					true
				),
				_reward_scale_from_float(
					float(p.get("memory_spatial_blind_pct", MEMORY_SPATIAL_BLIND_PCT_DEFAULT)),
					MEMORY_SPATIAL_BLIND_PCT_DEFAULT,
					MEMORY_SPATIAL_BLIND_PCT_MIN,
					MEMORY_SPATIAL_BLIND_PCT_MAX,
					false
				),
				_reward_scale_from_float(
					float(p.get("memory_fade_ms", MEMORY_FADE_MS_DEFAULT)),
					MEMORY_FADE_MS_DEFAULT,
					MEMORY_FADE_MS_MIN,
					MEMORY_FADE_MS_MAX,
					true
				),
			])
		ID_RANDOM_MODE:
			return _reward_scale_from_float(
				float(p.get("lane_remap_min_interval_sec", LANE_REMAP_INTERVAL_DEFAULT)),
				LANE_REMAP_INTERVAL_DEFAULT,
				LANE_REMAP_INTERVAL_MIN,
				LANE_REMAP_INTERVAL_MAX,
				true
			)
		ID_HEAT:
			return _combine_reward_scales([
				_reward_scale_from_float(
					float(p.get("heat_max_speed_pct", HEAT_MAX_SPEED_PCT_DEFAULT)),
					HEAT_MAX_SPEED_PCT_DEFAULT,
					HEAT_MAX_SPEED_PCT_MIN,
					HEAT_MAX_SPEED_PCT_MAX,
					false
				),
				_reward_scale_from_float(
					float(p.get("heat_step_combo", HEAT_STEP_COMBO_DEFAULT)),
					float(HEAT_STEP_COMBO_DEFAULT),
					float(HEAT_STEP_COMBO_MIN),
					float(HEAT_STEP_COMBO_MAX),
					true
				),
				_reward_scale_from_float(
					float(p.get("heat_peak_combo", HEAT_PEAK_COMBO_DEFAULT)),
					float(HEAT_PEAK_COMBO_DEFAULT),
					float(HEAT_PEAK_COMBO_MIN),
					float(HEAT_PEAK_COMBO_MAX),
					true
				),
			])
		ID_SPOTLIGHT:
			return _combine_reward_scales([
				_reward_scale_from_float(
					float(p.get("spotlight_band_px", SPOTLIGHT_BAND_PX_DEFAULT)),
					SPOTLIGHT_BAND_PX_DEFAULT,
					SPOTLIGHT_BAND_PX_MIN,
					SPOTLIGHT_BAND_PX_MAX,
					true
				),
				_reward_scale_from_float(
					float(p.get("spotlight_darkness_pct", SPOTLIGHT_DARKNESS_PCT_DEFAULT)),
					SPOTLIGHT_DARKNESS_PCT_DEFAULT,
					SPOTLIGHT_DARKNESS_PCT_MIN,
					SPOTLIGHT_DARKNESS_PCT_MAX,
					false
				),
			])
		ID_SILENCE:
			return _combine_reward_scales([
				_reward_scale_from_float(
					float(p.get("silence_interval_sec", SILENCE_INTERVAL_SEC_DEFAULT)),
					SILENCE_INTERVAL_SEC_DEFAULT,
					SILENCE_INTERVAL_SEC_MIN,
					SILENCE_INTERVAL_SEC_MAX,
					true
				),
				_reward_scale_from_float(
					float(p.get("silence_duration_max_sec", SILENCE_DURATION_MAX_SEC_DEFAULT)),
					SILENCE_DURATION_MAX_SEC_DEFAULT,
					SILENCE_DURATION_SEC_MIN,
					SILENCE_DURATION_SEC_MAX,
					false
				),
			])
		ID_RUSH:
			var bar_mode := rush_uses_bar_mode(p)
			return _combine_reward_scales([
				_reward_scale_from_float(
					float(
						p.get(
							"rush_bars_interval" if bar_mode else "rush_time_interval_min_sec",
							RUSH_BARS_INTERVAL_DEFAULT if bar_mode else RUSH_TIME_INTERVAL_MIN_DEFAULT
						)
					),
					RUSH_BARS_INTERVAL_DEFAULT if bar_mode else RUSH_TIME_INTERVAL_MIN_DEFAULT,
					RUSH_BARS_INTERVAL_MIN if bar_mode else RUSH_TIME_INTERVAL_MIN_MIN,
					RUSH_BARS_INTERVAL_MAX if bar_mode else RUSH_TIME_INTERVAL_MIN_MAX,
					true
				),
				_reward_scale_from_float(
					rush_effective_scroll_pct(p),
					RUSH_SCROLL_PCT_BARS_DEFAULT if bar_mode else RUSH_SCROLL_PCT_TIME_DEFAULT,
					RUSH_SCROLL_PCT_MIN,
					RUSH_SCROLL_PCT_MAX,
					false
				),
			])
		_:
			return 1.0


static func modifier_reward_delta(modifier_id: String, params: Dictionary = {}) -> float:
	if modifier_id == ID_AUTOPLAY:
		return 0.0
	if modifier_id in [ID_SLOW_75, ID_FAST_150]:
		return speed_reward_delta([modifier_id], params)
	var base := float(REWARD_DELTA.get(modifier_id, 0.0))
	if absf(base) <= 0.0001:
		return 0.0
	if not modifier_has_detail_params(modifier_id):
		return base
	return base * _param_reward_scale(modifier_id, sanitize_params(params))


static func card_reward_delta(modifier_id: String, params: Dictionary = {}) -> float:
	return modifier_reward_delta(modifier_id, params)


static func song_pitch_preserve_enabled(modifiers: Array, params: Dictionary = {}) -> bool:
	var p := sanitize_params(params)
	if has_modifier(modifiers, ID_SLOW_75):
		return bool(p.get("slow_75_preserve_pitch", false))
	if has_modifier(modifiers, ID_FAST_150):
		return bool(p.get("fast_150_preserve_pitch", false))
	if has_modifier(modifiers, ID_HEAT) and heat_affects_song_speed(p):
		return bool(p.get("heat_preserve_pitch", true))
	if has_modifier(modifiers, ID_RUSH) and rush_affects_song_speed(p):
		return bool(p.get("rush_preserve_pitch", true))
	return false


static func song_pitch_scale(modifiers: Array, params: Dictionary = {}) -> float:
	var p := sanitize_params(params)
	if has_modifier(modifiers, ID_SLOW_75):
		return float(p.get("slow_75_speed_pct", SLOW_75_SPEED_DEFAULT)) / 100.0
	if has_modifier(modifiers, ID_FAST_150):
		return float(p.get("fast_150_speed_pct", FAST_150_SPEED_DEFAULT)) / 100.0
	var speed_pct := float(p.get("song_speed", SONG_SPEED_DEFAULT))
	return clampf(speed_pct, SONG_SPEED_MIN, SONG_SPEED_MAX) / SONG_SPEED_DEFAULT


static func score_multiplier(modifiers: Array, params: Dictionary = {}) -> float:
	if has_modifier(modifiers, ID_AUTOPLAY) or has_modifier(modifiers, ID_SINGLE_LANE):
		return 0.0
	var mult := 1.0
	for id in sanitize(modifiers):
		if id == ID_SLOW_75 or id == ID_FAST_150:
			continue
		mult += modifier_reward_delta(id, params)
	mult += speed_reward_delta(modifiers, params)
	return maxf(0.0, mult)


static func reward_multiplier(modifiers: Array, params: Dictionary = {}) -> float:
	return score_multiplier(modifiers, params)


static func format_preset_abbr_list(modifiers: Array) -> String:
	return format_abbr_list(modifiers)


static func format_preset_multiplier_label(modifiers: Array, params: Dictionary = {}) -> String:
	var mult := reward_multiplier(modifiers, params)
	if (
		has_modifier(modifiers, ID_AUTOPLAY)
		or has_modifier(modifiers, ID_SINGLE_LANE)
		or has_modifier(modifiers, ID_COMBO_ESCALATION)
	):
		if is_equal_approx(mult, 0.0):
			return "0×"
	return "×%.2f" % snappedf(mult, 0.01)


static func format_preset_summary(modifiers: Array, params: Dictionary = {}) -> String:
	var mods := sanitize(modifiers)
	var abbr := format_preset_abbr_list(mods)
	var mult := format_preset_multiplier_label(mods, params)
	if abbr == "":
		return mult
	return "%s · %s" % [abbr, mult]


static func blocks_track_result_save(modifiers: Array) -> bool:
	return has_modifier(modifiers, ID_AUTOPLAY)


static func blocks_sudden_death(modifiers: Array) -> bool:
	return has_modifier(modifiers, ID_NO_FAIL)


static func visibility_alpha_multiplier(
	modifiers: Array,
	dist_to_hit_line_px: float,
	params: Dictionary = {}
) -> float:
	var dist := absf(dist_to_hit_line_px)
	var band := visibility_band_px(params)
	if has_modifier(modifiers, ID_HIDDEN):
		return _smoothstep_alpha(dist / band)
	if has_modifier(modifiers, ID_SUDDEN):
		var t := clampf(dist / band, 0.0, 1.0)
		return _smoothstep_alpha(1.0 - t)
	if has_modifier(modifiers, ID_SPOTLIGHT):
		return spotlight_note_visibility_alpha(dist, params)
	return 1.0


static func spotlight_note_visibility_alpha(dist_to_hit_line_px: float, params: Dictionary = {}) -> float:
	var half_band := spotlight_band_px(params) * 0.5
	var dist := absf(dist_to_hit_line_px)
	if dist <= half_band:
		return 1.0
	var fade := maxf(spotlight_band_px(params) * 0.35, 20.0)
	var t := clampf((dist - half_band) / fade, 0.0, 1.0)
	var darkness := spotlight_darkness_alpha(params)
	# Outside the bright band: faint silhouettes, not half-visible bars.
	var min_alpha := lerpf(0.28, 0.03, darkness)
	return lerpf(1.0, min_alpha, _smoothstep_alpha(t))


static func spotlight_note_rgb_multiplier(dist_to_hit_line_px: float, params: Dictionary = {}) -> float:
	var half_band := spotlight_band_px(params) * 0.5
	var dist := absf(dist_to_hit_line_px)
	if dist <= half_band:
		return 1.0
	var fade := maxf(spotlight_band_px(params) * 0.35, 20.0)
	var t := clampf((dist - half_band) / fade, 0.0, 1.0)
	var darkness := spotlight_darkness_alpha(params)
	var min_rgb := lerpf(0.35, 0.08, darkness)
	return lerpf(1.0, min_rgb, _smoothstep_alpha(t))


static func _smoothstep_alpha(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


static func format_summary(modifiers: Array) -> String:
	if modifiers.is_empty():
		return ""
	var parts: PackedStringArray = []
	for id in ALL_IDS:
		if has_modifier(modifiers, id):
			parts.append(TranslationServer.translate(title_i18n_key(id)))
	return ", ".join(parts)


static func format_tooltip(modifier_id: String) -> String:
	return "%s — %s" % [
		TranslationServer.translate(title_i18n_key(modifier_id)),
		TranslationServer.translate(desc_i18n_key(modifier_id)),
	]


static func title_i18n_key(modifier_id: String) -> String:
	return "MOD_TITLE_%s" % _title_suffix(modifier_id)


static func desc_i18n_key(modifier_id: String) -> String:
	return "MOD_DESC_%s" % _title_suffix(modifier_id)


static func _title_suffix(modifier_id: String) -> String:
	match modifier_id:
		ID_SLOW_75:
			return "SLOW_75"
		ID_FAST_150:
			return "FAST_150"
		ID_NO_FAIL:
			return "NO_FAIL"
		ID_EASY_WINDOWS:
			return "EASY_WINDOWS"
		ID_STRICT_TIMING:
			return "STRICT_TIMING"
		ID_NO_MISS_FORGIVENESS:
			return "NO_MISS_FORGIVENESS"
		ID_SUDDEN_DEATH:
			return "SUDDEN_DEATH"
		ID_FIXED_SPEED_20:
			return "FIXED_SPEED_20"
		ID_AUTOPLAY:
			return "AUTOPLAY"
		ID_HIDDEN:
			return "HIDDEN"
		ID_SUDDEN:
			return "SUDDEN"
		ID_HALF_HP:
			return "HALF_HP"
		ID_SINGLE_LANE:
			return "SINGLE_LANE"
		ID_TIME_WARP:
			return "TIME_WARP"
		ID_PICK_MODE:
			return "PICK_MODE"
		ID_REVERSE_SCROLL:
			return "REVERSE_SCROLL"
		ID_MEMORY_MODE:
			return "MEMORY_MODE"
		ID_DYNAMIC_LANES:
			return "DYNAMIC_LANES"
		ID_ENERGY_PULSE:
			return "ENERGY_PULSE"
		ID_DENSITY_FOCUS:
			return "DENSITY_FOCUS"
		ID_PHRASE_SHIFT:
			return "PHRASE_SHIFT"
		ID_GROOVE_LOCK:
			return "GROOVE_LOCK"
		ID_ADAPTIVE:
			return "ADAPTIVE"
		ID_RUSH:
			return "RUSH"
		ID_LAST_CHANCE:
			return "LAST_CHANCE"
		ID_GROOVE_ADDICTION:
			return "GROOVE_ADDICTION"
		ID_ENERGY_BALANCE:
			return "ENERGY_BALANCE"
		_:
			return modifier_id.to_upper()


static func format_abbr_list(modifiers: Array, translate_fn: Callable = Callable()) -> String:
	var mods := sanitize(modifiers)
	if mods.is_empty():
		return ""
	var parts: PackedStringArray = []
	for id in ALL_IDS:
		if mods.has(id):
			var key := _abbr_key_for(id)
			if translate_fn.is_valid():
				parts.append(str(translate_fn.call(key)))
			else:
				parts.append(TranslationServer.translate(key))
	return " ".join(parts)


static func format_modifier_description(modifier_id: String, params: Dictionary = {}) -> String:
	if modifier_id in NARRATIVE_DESC_IDS:
		return TranslationServer.translate(desc_i18n_key(modifier_id))
	var p := sanitize_params(params)
	var param_line := _format_modifier_param_line(modifier_id, p)
	if param_line != "":
		return param_line
	return TranslationServer.translate(desc_i18n_key(modifier_id))


static func _format_modifier_param_line(modifier_id: String, p: Dictionary) -> String:
	match modifier_id:
		ID_SLOW_75:
			return TranslationServer.translate("MOD_DESC_SLOW_75_PARAM") % int(
				round(float(p.get("slow_75_speed_pct", SLOW_75_SPEED_DEFAULT)))
			)
		ID_FAST_150:
			return TranslationServer.translate("MOD_DESC_FAST_150_PARAM") % int(
				round(float(p.get("fast_150_speed_pct", FAST_150_SPEED_DEFAULT)))
			)
		ID_HALF_HP:
			return TranslationServer.translate("MOD_DESC_HALF_HP_PARAM") % int(
				round(float(p.get("half_hp_start_pct", HALF_HP_START_PCT_DEFAULT)))
			)
		ID_TIME_WARP:
			return TranslationServer.translate("MOD_DESC_TIME_WARP_PARAM") % [
				int(round(float(p.get("time_warp_min_pct", TIME_WARP_MIN_PCT_DEFAULT)))),
				int(round(float(p.get("time_warp_max_pct", TIME_WARP_MAX_PCT_DEFAULT)))),
			]
		ID_ENERGY_PULSE:
			return TranslationServer.translate("MOD_DESC_ENERGY_PULSE_PARAM") % [
				int(round(float(p.get("energy_pulse_min_pct", ENERGY_PULSE_MIN_PCT_DEFAULT)))),
				int(round(float(p.get("energy_pulse_max_pct", ENERGY_PULSE_MAX_PCT_DEFAULT)))),
			]
		ID_DENSITY_FOCUS:
			return TranslationServer.translate("MOD_DESC_DENSITY_FOCUS_PARAM") % [
				int(round(float(p.get("density_focus_scroll_pct", DENSITY_FOCUS_SCROLL_PCT_DEFAULT)))),
				int(round(float(p.get("density_focus_band_px", DENSITY_FOCUS_BAND_PX_DEFAULT)))),
			]
		ID_PHRASE_SHIFT:
			return TranslationServer.translate("MOD_DESC_PHRASE_SHIFT_PARAM") % [
				int(round(float(p.get("phrase_shift_heat_scroll_pct", PHRASE_SHIFT_HEAT_SCROLL_PCT_DEFAULT)))),
				int(round(float(p.get("phrase_shift_hidden_band_px", PHRASE_SHIFT_HIDDEN_BAND_PX_DEFAULT)))),
			]
		ID_GROOVE_LOCK:
			return TranslationServer.translate("MOD_DESC_GROOVE_LOCK_PARAM") % [
				int(round(float(p.get("groove_lock_scroll_pct", GROOVE_LOCK_SCROLL_PCT_DEFAULT)))),
				int(round(float(p.get("groove_lock_timing_pct", GROOVE_LOCK_TIMING_PCT_DEFAULT)))),
				int(round(float(p.get("groove_lock_band_px", GROOVE_LOCK_BAND_PX_DEFAULT)))),
			]
		ID_ADAPTIVE:
			return TranslationServer.translate("MOD_DESC_ADAPTIVE_PARAM") % [
				int(round(float(p.get("adaptive_heat_scroll_pct", ADAPTIVE_HEAT_SCROLL_PCT_DEFAULT)))),
				int(round(float(p.get("adaptive_hidden_band_px", ADAPTIVE_HIDDEN_BAND_PX_DEFAULT)))),
				int(round(float(p.get("adaptive_speed_pct", ADAPTIVE_SPEED_PCT_DEFAULT)))),
			]
		ID_COMBO_ESCALATION:
			return TranslationServer.translate("MOD_DESC_COMBO_ESCALATION_PARAM") % [
				float(p.get("combo_escalation_step_pct", CE_STEP_PCT_DEFAULT)),
				int(p.get("combo_escalation_step_min", CE_STEP_MIN_DEFAULT)),
			]
		ID_HEAT:
			if (
				str(p.get("heat_step_mode", HEAT_STEP_MODE_DEFAULT)) == HEAT_STEP_MODE_CHART_PCT
			):
				return TranslationServer.translate("MOD_DESC_HEAT_PARAM_CHART") % [
					float(p.get("heat_step_chart_pct", HEAT_STEP_CHART_PCT_DEFAULT)),
					int(round(float(p.get("heat_max_speed_pct", HEAT_MAX_SPEED_PCT_DEFAULT)))),
					float(p.get("heat_peak_chart_pct", HEAT_PEAK_CHART_PCT_DEFAULT)),
				]
			return TranslationServer.translate("MOD_DESC_HEAT_PARAM") % [
				int(p.get("heat_step_combo", HEAT_STEP_COMBO_DEFAULT)),
				int(round(float(p.get("heat_max_speed_pct", HEAT_MAX_SPEED_PCT_DEFAULT)))),
				int(p.get("heat_peak_combo", HEAT_PEAK_COMBO_DEFAULT)),
			]
		ID_SILENCE:
			if (
				str(p.get("silence_schedule_mode", SILENCE_SCHEDULE_MODE_DEFAULT))
				== SILENCE_SCHEDULE_TRACK_PCT
			):
				return TranslationServer.translate("MOD_DESC_SILENCE_PARAM_TRACK") % [
					float(p.get("silence_interval_track_pct", SILENCE_INTERVAL_TRACK_PCT_DEFAULT)),
					float(p.get("silence_duration_min_sec", SILENCE_DURATION_MIN_SEC_DEFAULT)),
					float(p.get("silence_duration_max_sec", SILENCE_DURATION_MAX_SEC_DEFAULT)),
				]
			return TranslationServer.translate("MOD_DESC_SILENCE_PARAM") % [
				float(p.get("silence_interval_sec", SILENCE_INTERVAL_SEC_DEFAULT)),
				float(p.get("silence_duration_min_sec", SILENCE_DURATION_MIN_SEC_DEFAULT)),
				float(p.get("silence_duration_max_sec", SILENCE_DURATION_MAX_SEC_DEFAULT)),
			]
		ID_SPOTLIGHT:
			return TranslationServer.translate("MOD_DESC_SPOTLIGHT_PARAM") % [
				int(round(float(p.get("spotlight_band_px", SPOTLIGHT_BAND_PX_DEFAULT)))),
				int(round(float(p.get("spotlight_darkness_pct", SPOTLIGHT_DARKNESS_PCT_DEFAULT)))),
			]
		ID_RUSH:
			var bar_mode := rush_uses_bar_mode(p)
			if bar_mode:
				return TranslationServer.translate("MOD_DESC_RUSH_PARAM_BARS") % [
					int(round(float(p.get("rush_bars_interval", RUSH_BARS_INTERVAL_DEFAULT)))),
					int(round(float(p.get("rush_first_bar", RUSH_FIRST_BAR_DEFAULT)))),
					int(round(float(p.get("rush_scroll_pct_bars", RUSH_SCROLL_PCT_BARS_DEFAULT)))),
				]
			return TranslationServer.translate("MOD_DESC_RUSH_PARAM_TIME") % [
				int(round(float(p.get("rush_time_interval_min_sec", RUSH_TIME_INTERVAL_MIN_DEFAULT)))),
				int(round(float(p.get("rush_time_interval_max_sec", RUSH_TIME_INTERVAL_MAX_DEFAULT)))),
				int(round(float(p.get("rush_scroll_pct_time", RUSH_SCROLL_PCT_TIME_DEFAULT)))),
			]
		ID_ENERGY_BALANCE:
			return TranslationServer.translate("MOD_DESC_ENERGY_BALANCE_PARAM") % [
				int(round(float(p.get("energy_balance_calm_pct", ENERGY_BALANCE_CALM_PCT_DEFAULT)))),
				int(round(float(p.get("energy_balance_intense_pct", ENERGY_BALANCE_INTENSE_PCT_DEFAULT)))),
			]
		ID_GROOVE_ADDICTION:
			return TranslationServer.translate("MOD_DESC_GROOVE_ADDICTION_PARAM") % [
				int(p.get("groove_addiction_max_tier", GROOVE_ADDICTION_MAX_TIER_DEFAULT)),
				int(round(float(p.get("groove_addiction_scroll_pct", GROOVE_ADDICTION_SCROLL_PCT_DEFAULT)))),
				int(round(float(p.get("groove_addiction_timing_pct", GROOVE_ADDICTION_TIMING_PCT_DEFAULT)))),
			]
		ID_MEMORY_MODE:
			return TranslationServer.translate("MOD_DESC_MEMORY_MODE_PARAM") % [
				int(round(float(p.get("memory_reveal_ms", MEMORY_REVEAL_MS_DEFAULT)))),
				int(round(float(p.get("memory_spatial_blind_pct", MEMORY_SPATIAL_BLIND_PCT_DEFAULT)))),
				int(round(float(p.get("memory_fade_ms", MEMORY_FADE_MS_DEFAULT)))),
			]
		ID_DYNAMIC_LANES:
			return TranslationServer.translate("MOD_DESC_DYNAMIC_LANES_INTERVAL_PARAM") % float(
				p.get("lane_remap_min_interval_sec", LANE_REMAP_INTERVAL_DEFAULT)
			)
		ID_RANDOM_MODE:
			return TranslationServer.translate("MOD_DESC_RANDOM_LANE_INTERVAL_PARAM") % float(
				p.get("lane_remap_min_interval_sec", LANE_REMAP_INTERVAL_DEFAULT)
			)
		ID_EASY_WINDOWS:
			return format_timing_windows_label(
				ID_EASY_WINDOWS,
				float(p.get("easy_timing_window_pct", TIMING_WINDOW_PCT_DEFAULT))
			)
		ID_STRICT_TIMING:
			return format_timing_windows_label(
				ID_STRICT_TIMING,
				float(p.get("strict_timing_window_pct", TIMING_WINDOW_PCT_DEFAULT))
			)
		_:
			return ""


static func param_affects_label(param_id: String) -> String:
	var key := "MOD_PARAM_AFFECTS_%s" % param_id.to_upper()
	var text := TranslationServer.translate(key)
	if text == key:
		return ""
	return text


static func translate_abbr(modifier_id: String, locale_key: String = "") -> String:
	var key := locale_key if locale_key != "" else _abbr_key_for(modifier_id)
	var text := String(TranslationServer.translate(key))
	if text == key and key.begins_with("MOD_ABBR_"):
		return key.substr(9).to_upper()
	for i in text.length():
		if text.unicode_at(i) > 127:
			return text
	return text.to_upper()


static func _abbr_key_for(modifier_id: String) -> String:
	match modifier_id:
		ID_SLOW_75:
			return "MOD_ABBR_HT"
		ID_FAST_150:
			return "MOD_ABBR_DT"
		ID_NO_FAIL:
			return "MOD_ABBR_NF"
		ID_EASY_WINDOWS:
			return "MOD_ABBR_EZ"
		ID_STRICT_TIMING:
			return "MOD_ABBR_ST"
		ID_NO_MISS_FORGIVENESS:
			return "MOD_ABBR_EH"
		ID_SUDDEN_DEATH:
			return "MOD_ABBR_SD"
		ID_FIXED_SPEED_20:
			return "MOD_ABBR_FS"
		ID_AUTOPLAY:
			return "MOD_ABBR_AP"
		ID_HIDDEN:
			return "MOD_ABBR_HD"
		ID_SUDDEN:
			return "MOD_ABBR_SN"
		ID_HALF_HP:
			return "MOD_ABBR_HP"
		ID_SINGLE_LANE:
			return "MOD_ABBR_SL"
		ID_TIME_WARP:
			return "MOD_ABBR_TW"
		ID_PICK_MODE:
			return "MOD_ABBR_PM"
		ID_REVERSE_SCROLL:
			return "MOD_ABBR_RS"
		ID_MEMORY_MODE:
			return "MOD_ABBR_MM"
		ID_DYNAMIC_LANES:
			return "MOD_ABBR_DL"
		ID_ENERGY_PULSE:
			return "MOD_ABBR_EP"
		ID_DENSITY_FOCUS:
			return "MOD_ABBR_DF"
		ID_PHRASE_SHIFT:
			return "MOD_ABBR_PS"
		ID_GROOVE_LOCK:
			return "MOD_ABBR_GL"
		ID_ADAPTIVE:
			return "MOD_ABBR_AD"
		ID_MIRROR_MODE:
			return "MOD_ABBR_MR"
		ID_SHUFFLE_MODE:
			return "MOD_ABBR_SF"
		ID_RANDOM_MODE:
			return "MOD_ABBR_RN"
		ID_COMBO_ESCALATION:
			return "MOD_ABBR_CE"
		ID_METRONOME_ONLY:
			return "MOD_ABBR_MO"
		ID_HEAT:
			return "MOD_ABBR_HE"
		ID_SPOTLIGHT:
			return "MOD_ABBR_SP"
		ID_SILENCE:
			return "MOD_ABBR_SI"
		ID_RUSH:
			return "MOD_ABBR_RU"
		ID_LAST_CHANCE:
			return "MOD_ABBR_LC"
		ID_GROOVE_ADDICTION:
			return "MOD_ABBR_GA"
		ID_ENERGY_BALANCE:
			return "MOD_ABBR_EB"
		_:
			return modifier_id


static func category_tint(modifier_id: String, active: bool = true) -> Color:
	var base: Color
	if EASING_IDS.has(modifier_id):
		base = Color(0.42, 0.88, 0.58, 1.0)
	elif HARDENING_IDS.has(modifier_id):
		base = Color(0.95, 0.45, 0.42, 1.0)
	elif DNA_IDS.has(modifier_id):
		base = UiIconHelper.ACCENT_DNA
	elif SPECIAL_IDS.has(modifier_id):
		base = Color(0.42, 0.72, 0.96, 1.0)
	else:
		base = Color(0.78, 0.82, 0.9, 1.0)
	if active:
		return base
	return base.lerp(Color(0.45, 0.5, 0.58, 1.0), 0.55)


static func cover_path(modifier_id: String) -> String:
	if EASING_IDS.has(modifier_id):
		return "res://assets/modifiers/ease.png"
	if HARDENING_IDS.has(modifier_id):
		return "res://assets/modifiers/hard.png"
	if DNA_IDS.has(modifier_id):
		return "res://assets/modifiers/rhythmdna.png"
	if SPECIAL_IDS.has(modifier_id):
		return "res://assets/modifiers/special.png"
	return "res://assets/modifiers/default.png"


static func icon_file(modifier_id: String) -> String:
	match modifier_id:
		ID_SLOW_75:
			return "rewind.svg"
		ID_FAST_150:
			return "fast-forward.svg"
		ID_NO_FAIL:
			return "heart.svg"
		ID_EASY_WINDOWS:
			return "expand.svg"
		ID_STRICT_TIMING:
			return "crosshair.svg"
		ID_NO_MISS_FORGIVENESS:
			return "ban.svg"
		ID_SUDDEN_DEATH:
			return "skull.svg"
		ID_HIDDEN:
			return "eye-off.svg"
		ID_SUDDEN:
			return "eye.svg"
		ID_FIXED_SPEED_20:
			return "gauge.svg"
		ID_AUTOPLAY:
			return "bot.svg"
		ID_HALF_HP:
			return "heart-pulse.svg"
		ID_SINGLE_LANE:
			return "between-horizontal-start.svg"
		ID_TIME_WARP:
			return "zap.svg"
		ID_PICK_MODE:
			return "hand-metal.svg"
		ID_REVERSE_SCROLL:
			return "arrow-down-narrow-wide.svg"
		ID_MEMORY_MODE:
			return "fingerprint-pattern.svg"
		ID_DYNAMIC_LANES:
			return "layers.svg"
		ID_ENERGY_PULSE:
			return "activity.svg"
		ID_DENSITY_FOCUS:
			return "target.svg"
		ID_PHRASE_SHIFT:
			return "repeat.svg"
		ID_GROOVE_LOCK:
			return "lock_keyhole.svg"
		ID_ADAPTIVE:
			return "cpu.svg"
		ID_MIRROR_MODE:
			return "flip-horizontal-2.svg"
		ID_SHUFFLE_MODE:
			return "shuffle.svg"
		ID_RANDOM_MODE:
			return "dice-5.svg"
		ID_COMBO_ESCALATION:
			return "sparkles.svg"
		ID_METRONOME_ONLY:
			return "metronome.svg"
		ID_HEAT:
			return "flame.svg"
		ID_SPOTLIGHT:
			return "sun.svg"
		ID_SILENCE:
			return "volume-x.svg"
		ID_RUSH:
			return "gauge.svg"
		ID_LAST_CHANCE:
			return "heart-pulse.svg"
		ID_GROOVE_ADDICTION:
			return "magnet.svg"
		ID_ENERGY_BALANCE:
			return "blend.svg"
		_:
			return ""


static func _locale_key_for(modifier_id: String) -> String:
	match modifier_id:
		ID_SLOW_75:
			return "MOD_SLOW_75"
		ID_FAST_150:
			return "MOD_FAST_150"
		ID_NO_FAIL:
			return "MOD_NO_FAIL"
		ID_EASY_WINDOWS:
			return "MOD_EASY_WINDOWS"
		ID_STRICT_TIMING:
			return "MOD_STRICT_TIMING"
		ID_NO_MISS_FORGIVENESS:
			return "MOD_NO_MISS_FORGIVENESS"
		ID_SUDDEN_DEATH:
			return "MOD_SUDDEN_DEATH"
		ID_FIXED_SPEED_20:
			return "MOD_FIXED_SPEED_20"
		ID_AUTOPLAY:
			return "MOD_AUTOPLAY"
		ID_HIDDEN:
			return "MOD_HIDDEN"
		ID_SUDDEN:
			return "MOD_SUDDEN"
		_:
			return modifier_id
