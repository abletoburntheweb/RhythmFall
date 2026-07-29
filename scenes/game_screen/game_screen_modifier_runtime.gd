# scenes/game_screen/game_screen_modifier_runtime.gd
class_name GameScreenModifierRuntime
extends Node

const NoteManager = preload("res://logic/core/note_manager.gd")
const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const _SpotlightOverlay = preload("res://scenes/game_screen/components/modifier_spotlight_overlay.gd")
const _DynamicLanesSchedule = preload("res://logic/domain/rhythm/dynamic_lanes_schedule.gd")
const _EnergyPulseSchedule = preload("res://logic/domain/rhythm/energy_pulse_schedule.gd")
const _EnergyBalanceSchedule = preload("res://logic/domain/rhythm/energy_balance_schedule.gd")
const _DensityFocusSchedule = preload("res://logic/domain/rhythm/density_focus_schedule.gd")
const _LaneRemap = preload("res://logic/domain/rhythm/lane_remap.gd")
const _GrooveAddictionSchedule = preload("res://logic/domain/rhythm/groove_addiction_schedule.gd")

const LANE_CHANGE_ANIM_SEC := 0.75
const GAME_UPDATE_DELTA := 1.0 / 60.0
const SCROLL_SPEED_LERP_RATE := 22.0
const AUTOPLAY_NO_PRESS_TIME: float = -1000000000.0
const AUTOPLAY_LINE_TOLERANCE_MIN_PX: float = 10.0

const _HIT_ZONE_ANCHOR_REVERSE_TOP := 0.05
const _HIT_ZONE_ANCHOR_REVERSE_BOTTOM := 0.077
const _HIT_ZONE_ANCHOR_NORMAL_TOP := 0.88
const _HIT_ZONE_ANCHOR_NORMAL_BOTTOM := 0.907

const _UI_MIRROR_RELPATHS: Array[String] = [
	"SongProgressContainer",
	"TopLeftCombo",
	"HealthHud",
	"JudgementLabel",
	"HintLabel",
]

const _PLAYFIELD_MIRROR_RELPATHS: Array[String] = [
	"BottomHud",
]

var game_screen = null

var lane_schedule: Array = []
var energy_pulse_schedule: Array = []
var energy_balance_schedule: Array = []
var density_focus_schedule: Array = []
var rush_bursts: Array = []
var groove_addiction_schedule: Array = []
var dna_virtual_schedule: Array = []
var _dna_behavior_mod: String = ""
var _reverse_scroll_layout_applied: bool = false
var dynamic_lanes_applied: int = -1
var lane_change_tween: Tween = null
var _last_lane_change_song_time: float = -999.0

var ui_y_layout_snapshots: Dictionary = {}
var ui_y_layout_mirrored: bool = false

var autoplay_late_ms: float = 0.0
var autoplay_press_until := {}

var _random_lane_segment: int = -1
var _last_random_remap_song_time: float = -999.0
var random_lane_schedule: Array = []

var _escalation_tier: int = -1
var _escalation_injected: String = ""
var _escalation_run_seed: int = 0
var _escalation_used_ids: Array[String] = []

var _spotlight_overlay: ModifierSpotlightOverlay = null
var _spotlight_overlay_key: String = ""
var _silence_was_muted: bool = false

var _last_notice_heat_pct: int = 100
var _last_rush_burst_notice_active: bool = false
var _last_notice_speed_pct: Dictionary = {}

var _groove_addiction_tier: int = 0
var _groove_addiction_segment_idx: int = -1
var _groove_addiction_segment_had_miss: bool = false
var last_chance_active: bool = false


func initialize(gs) -> void:
	game_screen = gs


# --- Run modifier apply / pitch / scroll ---

func apply_runtime() -> void:
	# Autoplay lives in player selection; effective run_modifiers may omit it after CE inject.
	# Enable when the mod is selected, but never disable here — debug console may toggle autoplay.
	if _RunModifiers.has_modifier(game_screen.run_modifiers_player, _RunModifiers.ID_AUTOPLAY):
		game_screen.set_autoplay_enabled(true)
	game_screen._score_reward_multiplier = _RunModifiers.reward_multiplier(
		game_screen.run_modifiers_player, game_screen.run_modifier_params
	)
	game_screen._apply_score_reward_multiplier()
	apply_game_pitch_scale()
	game_screen.speed = effective_scroll_speed()
	apply_audio_modifiers()
	apply_spotlight_overlay()
	_reset_speed_notice_state()
	_notify_run_start_speed_mods()


func _notify_run_start_speed_mods() -> void:
	if game_screen == null or not game_screen.has_method("show_modifier_speed_notice"):
		return
	if _RunModifiers.has_modifier(game_screen.run_modifiers, _RunModifiers.ID_FAST_150):
		game_screen.show_modifier_speed_notice(_RunModifiers.ID_FAST_150, 150)
	if _RunModifiers.has_modifier(game_screen.run_modifiers, _RunModifiers.ID_SLOW_75):
		game_screen.show_modifier_speed_notice(_RunModifiers.ID_SLOW_75, 75)


func _reset_speed_notice_state() -> void:
	_last_notice_heat_pct = 100
	_last_rush_burst_notice_active = false
	_last_notice_speed_pct.clear()


func apply_audio_modifiers() -> void:
	var metro_only := _RunModifiers.is_metronome_only(game_screen.run_modifiers_player)
	var silence := _RunModifiers.is_silence(game_screen.run_modifiers_player)
	if silence:
		MusicManager.set_external_metronome_control(false)
		if MusicManager.has_method("set_game_music_muted"):
			MusicManager.set_game_music_muted(false)
		_silence_was_muted = false
		update_silence_audio()
		return
	MusicManager.set_external_metronome_control(metro_only)
	if MusicManager.has_method("set_game_music_muted"):
		MusicManager.set_game_music_muted(metro_only)
	_silence_was_muted = false


func update_silence_audio() -> void:
	if game_screen == null:
		return
	if not _RunModifiers.is_silence(game_screen.run_modifiers_player):
		if _silence_was_muted and MusicManager.has_method("set_game_music_muted"):
			MusicManager.set_game_music_muted(false)
			MusicManager.set_external_metronome_control(false)
		_silence_was_muted = false
		return
	if game_screen.countdown_active or not game_screen.gameplay_started:
		return
	var song_time: float = float(game_screen.get_song_time())
	var song_duration: float = 0.0
	if game_screen.has_method("_get_song_duration_seconds"):
		song_duration = float(game_screen._get_song_duration_seconds())
	var muted := _RunModifiers.silence_is_muted(
		song_time, game_screen.run_modifier_params, song_duration
	)
	var keep_metro := _RunModifiers.silence_metronome_enabled(game_screen.run_modifier_params)
	if MusicManager.has_method("set_game_music_muted"):
		MusicManager.set_game_music_muted(muted)
	MusicManager.set_external_metronome_control(muted and keep_metro)
	if muted and keep_metro:
		MusicManager.update_metronome(
			GAME_UPDATE_DELTA, song_time, game_screen.bpm
		)
	_silence_was_muted = muted


func update_metronome_tick(delta: float) -> void:
	if _RunModifiers.is_silence(game_screen.run_modifiers_player):
		update_silence_audio()
		return
	if not _RunModifiers.is_metronome_only(game_screen.run_modifiers_player):
		return
	if game_screen.countdown_active or not game_screen.gameplay_started:
		return
	MusicManager.update_metronome(
		delta, game_screen.get_song_time(), game_screen.bpm
	)


func apply_game_pitch_scale() -> void:
	if MusicManager == null or not MusicManager.has_method("set_game_pitch_scale"):
		return
	if MusicManager.has_method("set_preserve_pitch"):
		MusicManager.set_preserve_pitch(
			_RunModifiers.song_pitch_preserve_enabled(
				game_screen.run_modifiers, game_screen.run_modifier_params
			)
		)
	var base_pitch := _RunModifiers.song_pitch_scale(
		game_screen.run_modifiers, game_screen.run_modifier_params
	)
	if _RunModifiers.has_modifier(game_screen.run_modifiers, _RunModifiers.ID_TIME_WARP):
		base_pitch *= _RunModifiers.time_warp_playback_multiplier(
			game_screen.run_modifiers,
			game_screen.get_song_time(),
			game_screen._get_song_duration_seconds(),
			game_screen.run_modifier_params
		)
	elif _RunModifiers.is_energy_pulse(game_screen.run_modifiers):
		base_pitch *= _RunModifiers.energy_pulse_playback_multiplier(
			energy_pulse_schedule,
			game_screen.get_song_time(),
			game_screen.run_modifier_params
		)
	elif not dna_virtual_schedule.is_empty():
		var dna_virtual: Dictionary = _RunModifiers.dna_virtual_state(
			dna_virtual_schedule, game_screen.get_song_time()
		)
		base_pitch *= float(dna_virtual.get("playback_mult", 1.0))
	base_pitch *= _heat_song_speed_multiplier()
	base_pitch *= _rush_song_speed_multiplier()
	MusicManager.set_game_pitch_scale(base_pitch)


func effective_scroll_speed() -> float:
	var scroll := _RunModifiers.effective_scroll_speed(
		game_screen.run_modifiers,
		SettingsManager.get_scroll_speed(),
		game_screen.run_modifier_params
	)
	if _RunModifiers.is_heat(game_screen.run_modifiers):
		if not _RunModifiers.heat_affects_song_speed(game_screen.run_modifier_params):
			var combo := 0
			var total_notes := 0
			if game_screen.score_manager:
				combo = game_screen.score_manager.get_combo()
				total_notes = game_screen.score_manager.total_notes
			scroll *= _RunModifiers.heat_scroll_multiplier(
				combo, game_screen.run_modifier_params, total_notes
			)
	if _RunModifiers.is_density_focus(game_screen.run_modifiers):
		scroll *= _RunModifiers.density_focus_scroll_multiplier(
			density_focus_schedule,
			game_screen.get_song_time(),
			game_screen.run_modifier_params
		)
	if not dna_virtual_schedule.is_empty():
		var dna_virtual: Dictionary = _RunModifiers.dna_virtual_state(
			dna_virtual_schedule, game_screen.get_song_time()
		)
		scroll *= float(dna_virtual.get("scroll_mult", 1.0))
	if _RunModifiers.is_rush(game_screen.run_modifiers):
		if not _RunModifiers.rush_affects_song_speed(game_screen.run_modifier_params):
			scroll *= _RunModifiers.rush_scroll_multiplier(
				rush_bursts,
				game_screen.get_song_time(),
				game_screen.run_modifier_params
			)
	scroll *= _groove_addiction_scroll_multiplier()
	return scroll


func _groove_addiction_scroll_multiplier() -> float:
	if not _RunModifiers.is_groove_addiction(game_screen.run_modifiers):
		return 1.0
	if groove_addiction_schedule.is_empty():
		return 1.0
	if not _GrooveAddictionSchedule.is_groove_segment(
		groove_addiction_schedule, game_screen.get_song_time()
	):
		return 1.0
	var p: Dictionary = game_screen.run_modifier_params
	var mults: Dictionary = _GrooveAddictionSchedule.tier_multipliers(
		_groove_addiction_tier,
		_RunModifiers.groove_addiction_max_tier(p),
		float(p.get("groove_addiction_scroll_pct", _RunModifiers.GROOVE_ADDICTION_SCROLL_PCT_DEFAULT)),
		float(p.get("groove_addiction_timing_pct", _RunModifiers.GROOVE_ADDICTION_TIMING_PCT_DEFAULT))
	)
	return float(mults.get("scroll_mult", 1.0))


func _groove_addiction_timing_multiplier() -> float:
	if not _RunModifiers.is_groove_addiction(game_screen.run_modifiers):
		return 1.0
	if groove_addiction_schedule.is_empty():
		return 1.0
	if not _GrooveAddictionSchedule.is_groove_segment(
		groove_addiction_schedule, game_screen.get_song_time()
	):
		return 1.0
	var p: Dictionary = game_screen.run_modifier_params
	var mults: Dictionary = _GrooveAddictionSchedule.tier_multipliers(
		_groove_addiction_tier,
		_RunModifiers.groove_addiction_max_tier(p),
		float(p.get("groove_addiction_scroll_pct", _RunModifiers.GROOVE_ADDICTION_SCROLL_PCT_DEFAULT)),
		float(p.get("groove_addiction_timing_pct", _RunModifiers.GROOVE_ADDICTION_TIMING_PCT_DEFAULT))
	)
	return float(mults.get("timing_mult", 1.0))


func poll_heat_scroll(delta: float = GAME_UPDATE_DELTA) -> void:
	if game_screen == null:
		return
	if (
		not _RunModifiers.is_heat(game_screen.run_modifiers)
		and not _RunModifiers.is_density_focus(game_screen.run_modifiers)
		and not _RunModifiers.is_rush(game_screen.run_modifiers)
		and not _RunModifiers.is_groove_addiction(game_screen.run_modifiers)
		and dna_virtual_schedule.is_empty()
	):
		return
	var target := effective_scroll_speed()
	var blend := 1.0 - exp(-SCROLL_SPEED_LERP_RATE * maxf(delta, 0.0))
	if not is_equal_approx(game_screen.speed, target):
		game_screen.speed = lerpf(float(game_screen.speed), target, blend)
	_maybe_notify_speed_changes()
	if _uses_dynamic_song_pitch():
		apply_game_pitch_scale()


func _heat_song_speed_multiplier() -> float:
	if game_screen == null or not _RunModifiers.is_heat(game_screen.run_modifiers):
		return 1.0
	if not _RunModifiers.heat_affects_song_speed(game_screen.run_modifier_params):
		return 1.0
	var combo := 0
	var total_notes := 0
	if game_screen.score_manager:
		combo = game_screen.score_manager.get_combo()
		total_notes = game_screen.score_manager.total_notes
	return _RunModifiers.heat_scroll_multiplier(
		combo, game_screen.run_modifier_params, total_notes
	)


func _rush_song_speed_multiplier() -> float:
	if game_screen == null or not _RunModifiers.is_rush(game_screen.run_modifiers):
		return 1.0
	if not _RunModifiers.rush_affects_song_speed(game_screen.run_modifier_params):
		return 1.0
	return _RunModifiers.rush_scroll_multiplier(
		rush_bursts,
		game_screen.get_song_time(),
		game_screen.run_modifier_params
	)


func _uses_dynamic_song_pitch() -> bool:
	if game_screen == null:
		return false
	var p: Dictionary = game_screen.run_modifier_params
	if _RunModifiers.is_heat(game_screen.run_modifiers) and _RunModifiers.heat_affects_song_speed(p):
		return true
	if _RunModifiers.is_rush(game_screen.run_modifiers) and _RunModifiers.rush_affects_song_speed(p):
		return true
	return false


func _maybe_notify_speed_changes() -> void:
	if game_screen == null or not game_screen.has_method("show_modifier_speed_notice"):
		return
	if game_screen.countdown_active or not game_screen.gameplay_started:
		return
	var p: Dictionary = game_screen.run_modifier_params
	if _RunModifiers.is_heat(game_screen.run_modifiers):
		var mult := _heat_song_speed_multiplier()
		if not _RunModifiers.heat_affects_song_speed(p):
			var combo := 0
			var total_notes := 0
			if game_screen.score_manager:
				combo = game_screen.score_manager.get_combo()
				total_notes = game_screen.score_manager.total_notes
			mult = _RunModifiers.heat_scroll_multiplier(combo, p, total_notes)
		_notify_speed_pct_step(_RunModifiers.ID_HEAT, int(round(mult * 100.0)), 6, 105, "_heat_legacy")
	if _RunModifiers.is_rush(game_screen.run_modifiers):
		var rush_mult := _rush_song_speed_multiplier()
		if not _RunModifiers.rush_affects_song_speed(p):
			rush_mult = _RunModifiers.rush_scroll_multiplier(
				rush_bursts, game_screen.get_song_time(), p
			)
		var burst_active := rush_mult > 1.02
		if burst_active and not _last_rush_burst_notice_active:
			game_screen.show_modifier_speed_notice(
				_RunModifiers.ID_RUSH,
				int(round(_RunModifiers.rush_effective_scroll_pct(p)))
			)
		_last_rush_burst_notice_active = burst_active
	if _RunModifiers.is_density_focus(game_screen.run_modifiers):
		var df_mult := _RunModifiers.density_focus_scroll_multiplier(
			density_focus_schedule,
			game_screen.get_song_time(),
			p
		)
		_notify_speed_pct_step(_RunModifiers.ID_DENSITY_FOCUS, int(round(df_mult * 100.0)))
	if _RunModifiers.is_energy_pulse(game_screen.run_modifiers):
		var ep_mult := _RunModifiers.energy_pulse_playback_multiplier(
			energy_pulse_schedule,
			game_screen.get_song_time(),
			p
		)
		_notify_speed_pct_step(_RunModifiers.ID_ENERGY_PULSE, int(round(ep_mult * 100.0)))
	if _RunModifiers.has_modifier(game_screen.run_modifiers, _RunModifiers.ID_TIME_WARP):
		var duration := 0.0
		if game_screen.has_method("_get_song_duration_seconds"):
			duration = float(game_screen._get_song_duration_seconds())
		var tw_mult := _RunModifiers.time_warp_playback_multiplier(
			game_screen.run_modifiers,
			game_screen.get_song_time(),
			duration,
			p
		)
		_notify_speed_pct_step(_RunModifiers.ID_TIME_WARP, int(round(tw_mult * 100.0)), 8, 105)
	if not dna_virtual_schedule.is_empty():
		var dna_virtual: Dictionary = _RunModifiers.dna_virtual_state(
			dna_virtual_schedule, game_screen.get_song_time()
		)
		var dna_mult := float(dna_virtual.get("scroll_mult", 1.0)) * float(dna_virtual.get("playback_mult", 1.0))
		if _dna_behavior_mod != "":
			_notify_speed_pct_step(_dna_behavior_mod, int(round(dna_mult * 100.0)), 8, 108)


func _notify_speed_pct_step(
	mod_id: String,
	pct: int,
	step: int = 6,
	min_pct: int = 105,
	legacy_key: String = ""
) -> void:
	if mod_id == "":
		return
	var track_key := legacy_key if legacy_key != "" else mod_id
	if mod_id == _RunModifiers.ID_HEAT and legacy_key == "_heat_legacy":
		if pct >= min_pct and pct - _last_notice_heat_pct >= step:
			game_screen.show_modifier_speed_notice(mod_id, pct)
			_last_notice_heat_pct = pct
		elif pct <= 101:
			_last_notice_heat_pct = 100
		return
	var last := int(_last_notice_speed_pct.get(track_key, 100))
	if pct >= min_pct and pct - last >= step:
		game_screen.show_modifier_speed_notice(mod_id, pct)
		_last_notice_speed_pct[track_key] = pct
	elif pct <= 101:
		_last_notice_speed_pct[track_key] = 100


func apply_spotlight_overlay() -> void:
	if game_screen == null:
		return
	if not _RunModifiers.is_spotlight(game_screen.run_modifiers):
		_remove_spotlight_overlay()
		return
	var playfield := game_screen.get_node_or_null("Playfield") as Control
	if playfield == null:
		return
	var band := _RunModifiers.spotlight_band_px(game_screen.run_modifier_params)
	var darkness := _RunModifiers.spotlight_darkness_alpha(game_screen.run_modifier_params)
	var reverse := is_reverse_scroll_active()
	var overlay_key := "%.1f|%.1f|%s|%.3f" % [float(game_screen.hit_zone_y), band, str(reverse), darkness]
	var overlay_ready := (
		_spotlight_overlay != null
		and is_instance_valid(_spotlight_overlay)
		and _spotlight_overlay.size.x > 1.0
		and _spotlight_overlay.size.y > 1.0
	)
	if overlay_key == _spotlight_overlay_key and overlay_ready:
		return
	if _spotlight_overlay == null or not is_instance_valid(_spotlight_overlay):
		_spotlight_overlay = _SpotlightOverlay.new()
		_spotlight_overlay.name = "ModifierSpotlightOverlay"
		playfield.add_child(_spotlight_overlay)
	_ensure_spotlight_overlay_layout(playfield)
	playfield.move_child(_spotlight_overlay, playfield.get_child_count() - 1)
	_spotlight_overlay.z_index = 48
	_spotlight_overlay.visible = true
	_spotlight_overlay_key = overlay_key
	_spotlight_overlay.configure(float(game_screen.hit_zone_y), band, reverse, darkness)


func _ensure_spotlight_overlay_layout(playfield: Control) -> void:
	if _spotlight_overlay == null or playfield == null:
		return
	_spotlight_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_spotlight_overlay.offset_left = 0.0
	_spotlight_overlay.offset_top = 0.0
	_spotlight_overlay.offset_right = 0.0
	_spotlight_overlay.offset_bottom = 0.0
	_spotlight_overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_spotlight_overlay.grow_vertical = Control.GROW_DIRECTION_BOTH


func _remove_spotlight_overlay() -> void:
	if _spotlight_overlay and is_instance_valid(_spotlight_overlay):
		_spotlight_overlay.queue_free()
	_spotlight_overlay = null
	_spotlight_overlay_key = ""


func cleanup_modifier_overlays() -> void:
	_remove_spotlight_overlay()
	_silence_was_muted = false


func chart_playback_rate_at(chart_time: float) -> float:
	var rate := _RunModifiers.song_pitch_scale(
		game_screen.run_modifiers, game_screen.run_modifier_params
	)
	if _RunModifiers.has_modifier(game_screen.run_modifiers, _RunModifiers.ID_TIME_WARP):
		var duration := 0.0
		if game_screen.has_method("_get_song_duration_seconds"):
			duration = float(game_screen._get_song_duration_seconds())
		rate *= _RunModifiers.time_warp_playback_multiplier(
			game_screen.run_modifiers,
			maxf(0.0, chart_time),
			duration,
			game_screen.run_modifier_params
		)
	elif _RunModifiers.is_energy_pulse(game_screen.run_modifiers):
		rate *= _RunModifiers.energy_pulse_playback_multiplier(
			energy_pulse_schedule,
			maxf(0.0, chart_time),
			game_screen.run_modifier_params
		)
	elif not dna_virtual_schedule.is_empty():
		var dna_virtual: Dictionary = _RunModifiers.dna_virtual_state(dna_virtual_schedule, maxf(0.0, chart_time))
		rate *= float(dna_virtual.get("playback_mult", 1.0))
	rate *= _heat_song_speed_multiplier()
	rate *= _rush_song_speed_multiplier()
	return rate


func uses_manual_chart_clock() -> bool:
	return (
		str(game_screen.pending_game_music_path) != ""
		or not MusicManager.is_music_playing()
		or MusicManager.current_game_music_file == ""
	)


func hit_window_perfect() -> float:
	var base := _RunModifiers.hit_window_perfect(
		game_screen.run_modifiers, game_screen.run_modifier_params
	)
	if _RunModifiers.is_energy_balance(game_screen.run_modifiers):
		base *= _RunModifiers.energy_balance_timing_multiplier(
			energy_balance_schedule,
			game_screen.get_song_time(),
			game_screen.run_modifier_params
		)
	base *= _groove_addiction_timing_multiplier()
	if dna_virtual_schedule.is_empty():
		return base
	var dna_virtual: Dictionary = _RunModifiers.dna_virtual_state(dna_virtual_schedule, game_screen.get_song_time())
	return _RunModifiers.dna_virtual_hit_window_perfect(base, dna_virtual)


func hit_window_good() -> float:
	var base := _RunModifiers.hit_window_good(
		game_screen.run_modifiers, game_screen.run_modifier_params
	)
	if _RunModifiers.is_energy_balance(game_screen.run_modifiers):
		base *= _RunModifiers.energy_balance_timing_multiplier(
			energy_balance_schedule,
			game_screen.get_song_time(),
			game_screen.run_modifier_params
		)
	base *= _groove_addiction_timing_multiplier()
	if dna_virtual_schedule.is_empty():
		return base
	var dna_virtual: Dictionary = _RunModifiers.dna_virtual_state(dna_virtual_schedule, game_screen.get_song_time())
	return _RunModifiers.dna_virtual_hit_window_good(base, dna_virtual)


# --- Reverse scroll geometry ---

func is_reverse_scroll_active() -> bool:
	if _RunModifiers.is_reverse_scroll(game_screen.run_modifiers):
		return true
	if dna_virtual_schedule.is_empty():
		return false
	var dna_virtual: Dictionary = _RunModifiers.dna_virtual_state(
		dna_virtual_schedule, game_screen.get_song_time()
	)
	return bool(dna_virtual.get("reverse_scroll", false))


func get_dna_virtual_state() -> Dictionary:
	if dna_virtual_schedule.is_empty():
		return _RunModifiers.dna_virtual_state([], 0.0)
	return _RunModifiers.dna_virtual_state(dna_virtual_schedule, game_screen.get_song_time())


func poll_dna_virtual_layout() -> void:
	if dna_virtual_schedule.is_empty():
		return
	var reverse := is_reverse_scroll_active()
	if reverse == _reverse_scroll_layout_applied:
		return
	_reverse_scroll_layout_applied = reverse
	var hit_zone := game_screen.get_node_or_null("Playfield/HitZone") as ColorRect
	if hit_zone:
		apply_hit_zone_anchors(hit_zone, reverse)
	apply_reverse_scroll_ui_layout(reverse)
	if game_screen.has_method("_refresh_run_hud_layout"):
		game_screen._refresh_run_hud_layout()


func note_scroll_sign() -> float:
	return -1.0 if is_reverse_scroll_active() else 1.0


func note_y_for_chart_time(note_time: float, song_time: float, hit_y: float, px_per_sec: float) -> float:
	if is_reverse_scroll_active():
		return hit_y + (note_time - song_time) * px_per_sec
	return hit_y - (note_time - song_time) * px_per_sec


func note_spawn_travel_distance(playfield_h: float, hit_y: float) -> float:
	if is_reverse_scroll_active():
		return (playfield_h + 20.0) - hit_y
	return hit_y - (-20.0)


func note_spawn_offscreen(y_spawn: float, playfield_h: float) -> bool:
	if is_reverse_scroll_active():
		return y_spawn < -20.0
	return y_spawn > playfield_h + 20.0


func note_despawn_y(playfield_height: float) -> float:
	if is_reverse_scroll_active():
		return -80.0
	return playfield_height + 80.0


func apply_hit_zone_anchors(hit_zone: ColorRect, reverse: bool) -> void:
	hit_zone.anchor_left = 0.0
	hit_zone.anchor_right = 1.0
	if reverse:
		hit_zone.anchor_top = _HIT_ZONE_ANCHOR_REVERSE_TOP
		hit_zone.anchor_bottom = _HIT_ZONE_ANCHOR_REVERSE_BOTTOM
	else:
		hit_zone.anchor_top = _HIT_ZONE_ANCHOR_NORMAL_TOP
		hit_zone.anchor_bottom = _HIT_ZONE_ANCHOR_NORMAL_BOTTOM
	hit_zone.offset_left = 0.0
	hit_zone.offset_top = 0.0
	hit_zone.offset_right = 0.0
	hit_zone.offset_bottom = 0.0


func capture_ui_layout_snapshots() -> void:
	_capture_ui_y_layout_snapshots()


func apply_reverse_scroll_ui_layout(reverse: bool) -> void:
	if ui_y_layout_snapshots.is_empty():
		_capture_ui_y_layout_snapshots()
	if ui_y_layout_snapshots.is_empty():
		return
	var ui := game_screen.get_node_or_null("UIContainer") as Control
	if ui == null:
		return
	if reverse != ui_y_layout_mirrored:
		for rel_path in _UI_MIRROR_RELPATHS:
			if not ui_y_layout_snapshots.has(rel_path):
				continue
			var node := ui.get_node_or_null(rel_path) as Control
			if node == null:
				continue
			_apply_control_y_layout(node, ui_y_layout_snapshots[rel_path], reverse)
		var playfield := game_screen.get_node_or_null("Playfield") as Control
		if playfield:
			for rel_path in _PLAYFIELD_MIRROR_RELPATHS:
				var snap_key := "Playfield/" + rel_path
				if not ui_y_layout_snapshots.has(snap_key):
					continue
				var pf_node := playfield.get_node_or_null(rel_path) as Control
				if pf_node == null:
					continue
				_apply_control_y_layout(pf_node, ui_y_layout_snapshots[snap_key], reverse)
		ui_y_layout_mirrored = reverse
	if reverse:
		_pin_reverse_scroll_hud()
	if game_screen.combo_label:
		game_screen._combo_original_position = game_screen.combo_label.position


# --- Dynamic lanes ---

func prepare_dynamic_lanes_for_run(song_data: Dictionary) -> void:
	var song_path := String(song_data.get("path", ""))
	game_screen._chart_lanes = _DynamicLanesSchedule.resolve_chart_lanes(
		song_path,
		game_screen.current_instrument,
		game_screen.current_generation_mode,
		game_screen.lanes
	)
	var dna := NotesUtils.load_rhythm_dna(
		song_path,
		game_screen.current_instrument,
		game_screen.current_generation_mode,
		game_screen._chart_lanes
	)
	var duration: float = game_screen._get_song_duration_seconds()
	if duration <= 0.01 and dna.get("track", {}) is Dictionary:
		var track: Dictionary = dna.get("track", {})
		var track_bpm := float(track.get("bpm", 0.0))
		if track_bpm > 0.0:
			duration = 180.0
	lane_schedule = _DynamicLanesSchedule.build_from_dna(dna, duration)
	var initial := _DynamicLanesSchedule.lanes_at(lane_schedule, 0.0)
	game_screen.lanes = initial
	dynamic_lanes_applied = initial
	_last_lane_change_song_time = 0.0
	if game_screen.player:
		game_screen.player.set_num_lanes(initial)


func prepare_energy_pulse_for_run(song_data: Dictionary) -> void:
	energy_pulse_schedule.clear()
	if not _RunModifiers.is_energy_pulse(game_screen.run_modifiers):
		return
	var song_path := String(song_data.get("path", ""))
	if song_path.strip_edges() == "":
		return
	var dna := NotesUtils.load_rhythm_dna(
		song_path,
		game_screen.current_instrument,
		game_screen.current_generation_mode,
		game_screen._chart_lanes
	)
	var duration: float = game_screen._get_song_duration_seconds()
	if duration <= 0.01 and dna.get("track", {}) is Dictionary:
		var track: Dictionary = dna.get("track", {})
		var track_bpm := float(track.get("bpm", 0.0))
		if track_bpm > 0.0:
			duration = 180.0
	energy_pulse_schedule = _EnergyPulseSchedule.build_from_dna(dna, duration)


func prepare_rush_for_run(song_data: Dictionary) -> void:
	rush_bursts.clear()
	if not _RunModifiers.is_rush(game_screen.run_modifiers):
		return
	var song_path := String(song_data.get("path", ""))
	var duration: float = game_screen._get_song_duration_seconds()
	if duration <= 0.01:
		duration = 180.0
	var track_bpm := float(game_screen.bpm)
	if track_bpm <= 0.0 and song_data.has("bpm"):
		var bpm_raw: Variant = song_data.get("bpm", 0)
		if typeof(bpm_raw) == TYPE_STRING:
			var bpm_str := String(bpm_raw).strip_edges()
			if bpm_str != "" and bpm_str != "-1" and bpm_str != "Н/Д" and bpm_str != "N/A":
				track_bpm = float(bpm_str)
		elif typeof(bpm_raw) == TYPE_FLOAT or typeof(bpm_raw) == TYPE_INT:
			track_bpm = float(bpm_raw)
	rush_bursts = _RunModifiers.build_rush_bursts(
		song_path, duration, game_screen.run_modifier_params, track_bpm
	)


func prepare_energy_balance_for_run(song_data: Dictionary) -> void:
	energy_balance_schedule.clear()
	if not _RunModifiers.is_energy_balance(game_screen.run_modifiers):
		return
	var song_path := String(song_data.get("path", ""))
	if song_path.strip_edges() == "":
		return
	var dna := NotesUtils.load_rhythm_dna(
		song_path,
		game_screen.current_instrument,
		game_screen.current_generation_mode,
		game_screen._chart_lanes
	)
	var duration: float = game_screen._get_song_duration_seconds()
	if duration <= 0.01 and dna.get("track", {}) is Dictionary:
		var track: Dictionary = dna.get("track", {})
		var track_bpm := float(track.get("bpm", 0.0))
		if track_bpm > 0.0:
			duration = 180.0
	energy_balance_schedule = _EnergyBalanceSchedule.build_from_dna(dna, duration)


func prepare_groove_addiction_for_run(song_data: Dictionary) -> void:
	groove_addiction_schedule.clear()
	reset_groove_addiction_state()
	if not _RunModifiers.is_groove_addiction(game_screen.run_modifiers):
		return
	var song_path := String(song_data.get("path", ""))
	if song_path.strip_edges() == "":
		return
	var dna := NotesUtils.load_rhythm_dna(
		song_path,
		game_screen.current_instrument,
		game_screen.current_generation_mode,
		game_screen._chart_lanes
	)
	var duration: float = game_screen._get_song_duration_seconds()
	if duration <= 0.01 and dna.get("track", {}) is Dictionary:
		var track: Dictionary = dna.get("track", {})
		var track_bpm := float(track.get("bpm", 0.0))
		if track_bpm > 0.0:
			duration = 180.0
	groove_addiction_schedule = _GrooveAddictionSchedule.build_from_dna(dna, duration)


func reset_groove_addiction_state() -> void:
	_groove_addiction_tier = 0
	_groove_addiction_segment_idx = -1
	_groove_addiction_segment_had_miss = false


func reset_last_chance_state() -> void:
	last_chance_active = false


func notify_groove_addiction_miss() -> void:
	if _RunModifiers.is_groove_addiction(game_screen.run_modifiers):
		_groove_addiction_segment_had_miss = true


func poll_groove_addiction() -> void:
	if not _RunModifiers.is_groove_addiction(game_screen.run_modifiers):
		return
	if groove_addiction_schedule.is_empty():
		return
	var song_time: float = float(game_screen.get_song_time())
	var idx: int = _GrooveAddictionSchedule.segment_index_at(groove_addiction_schedule, song_time)
	if idx == _groove_addiction_segment_idx:
		return
	if _groove_addiction_segment_idx >= 0:
		var prev: Dictionary = groove_addiction_schedule[_groove_addiction_segment_idx]
		if bool(prev.get("is_groove", false)) and not _groove_addiction_segment_had_miss:
			var max_tier: int = _RunModifiers.groove_addiction_max_tier(game_screen.run_modifier_params)
			var new_tier := mini(_groove_addiction_tier + 1, max_tier)
			if new_tier > _groove_addiction_tier and game_screen.has_method("show_modifier_speed_notice"):
				var p: Dictionary = game_screen.run_modifier_params
				var mults: Dictionary = _GrooveAddictionSchedule.tier_multipliers(
					new_tier,
					max_tier,
					float(p.get("groove_addiction_scroll_pct", _RunModifiers.GROOVE_ADDICTION_SCROLL_PCT_DEFAULT)),
					float(p.get("groove_addiction_timing_pct", _RunModifiers.GROOVE_ADDICTION_TIMING_PCT_DEFAULT))
				)
				var scroll_pct := int(round(float(mults.get("scroll_mult", 1.0)) * 100.0))
				game_screen.show_modifier_speed_notice(_RunModifiers.ID_GROOVE_ADDICTION, scroll_pct)
			_groove_addiction_tier = new_tier
	_groove_addiction_segment_idx = idx
	_groove_addiction_segment_had_miss = false


func prepare_density_focus_for_run(song_data: Dictionary) -> void:
	density_focus_schedule.clear()
	if not _RunModifiers.is_density_focus(game_screen.run_modifiers):
		return
	var song_path := String(song_data.get("path", ""))
	if song_path.strip_edges() == "":
		return
	var dna := NotesUtils.load_rhythm_dna(
		song_path,
		game_screen.current_instrument,
		game_screen.current_generation_mode,
		game_screen._chart_lanes
	)
	var duration: float = game_screen._get_song_duration_seconds()
	if duration <= 0.01 and dna.get("track", {}) is Dictionary:
		var track: Dictionary = dna.get("track", {})
		var track_bpm := float(track.get("bpm", 0.0))
		if track_bpm > 0.0:
			duration = 180.0
	var schedule := _DensityFocusSchedule.build_from_dna(dna, duration)
	var notes: Array = []
	if game_screen.note_manager:
		notes = game_screen.note_manager.get_spawn_queue()
	density_focus_schedule = _DensityFocusSchedule.enrich_with_chart_notes(schedule, notes)


func prepare_dna_virtual_for_run(song_data: Dictionary) -> void:
	dna_virtual_schedule.clear()
	_dna_behavior_mod = _RunModifiers.active_dna_behavior_id(game_screen.run_modifiers)
	_reverse_scroll_layout_applied = false
	if _dna_behavior_mod == "":
		return
	var song_path := String(song_data.get("path", ""))
	if song_path.strip_edges() == "":
		return
	var dna := NotesUtils.load_rhythm_dna(
		song_path,
		game_screen.current_instrument,
		game_screen.current_generation_mode,
		game_screen._chart_lanes
	)
	var duration: float = game_screen._get_song_duration_seconds()
	if duration <= 0.01 and dna.get("track", {}) is Dictionary:
		var track: Dictionary = dna.get("track", {})
		var track_bpm := float(track.get("bpm", 0.0))
		if track_bpm > 0.0:
			duration = 180.0
	var notes: Array = []
	if game_screen.note_manager:
		notes = game_screen.note_manager.get_spawn_queue()
	dna_virtual_schedule = _RunModifiers.build_dna_virtual_schedule(
		_dna_behavior_mod, dna, duration, notes, game_screen.run_modifier_params
	)
	_reverse_scroll_layout_applied = is_reverse_scroll_active()


func reset_dynamic_lanes_state() -> void:
	lane_schedule.clear()
	energy_pulse_schedule.clear()
	energy_balance_schedule.clear()
	density_focus_schedule.clear()
	rush_bursts.clear()
	groove_addiction_schedule.clear()
	dna_virtual_schedule.clear()
	reset_groove_addiction_state()
	reset_last_chance_state()
	_dna_behavior_mod = ""
	_reverse_scroll_layout_applied = false
	dynamic_lanes_applied = -1
	_last_lane_change_song_time = -999.0
	_random_lane_segment = -1
	_last_random_remap_song_time = -999.0
	random_lane_schedule.clear()


func prepare_random_lanes_for_run(song_data: Dictionary) -> void:
	random_lane_schedule.clear()
	_random_lane_segment = -1
	_last_random_remap_song_time = -999.0
	if not _RunModifiers.is_random_mode(game_screen.run_modifiers):
		return
	var song_path := String(song_data.get("path", ""))
	if song_path.strip_edges() == "":
		return
	var dna := NotesUtils.load_rhythm_dna(
		song_path,
		game_screen.current_instrument,
		game_screen.current_generation_mode,
		game_screen._chart_lanes
	)
	random_lane_schedule = _DynamicLanesSchedule.build_random_remap_schedule(dna)


func get_random_lane_schedule() -> Array:
	return random_lane_schedule


func _lane_remap_min_interval() -> float:
	return _RunModifiers.lane_remap_min_interval_sec(game_screen.run_modifier_params)


func poll_dynamic_lane_schedule() -> void:
	if not _RunModifiers.is_dynamic_lanes(game_screen.run_modifiers):
		return
	if lane_schedule.is_empty():
		return
	var song_time: float = game_screen.get_song_time()
	var target: int = _DynamicLanesSchedule.lanes_at(lane_schedule, song_time)
	if target == dynamic_lanes_applied:
		return
	if (
		dynamic_lanes_applied >= _DynamicLanesSchedule.MIN_LANES
		and song_time - _last_lane_change_song_time < _lane_remap_min_interval()
	):
		return
	var from_lanes: int = dynamic_lanes_applied
	_apply_lanes_animated(target)
	dynamic_lanes_applied = target
	_last_lane_change_song_time = song_time
	if game_screen.has_method("show_lane_change_notice"):
		game_screen.show_lane_change_notice(from_lanes, target)
	game_screen.note_manager.cull_notes_outside_playable_lanes(
		game_screen.run_modifiers, game_screen.lanes, game_screen._chart_lanes
	)


func poll_random_lane_remap() -> void:
	if not _RunModifiers.is_random_mode(game_screen.run_modifiers):
		return
	var song_time: float = game_screen.get_song_time()
	var ctx: Dictionary = game_screen.lane_remap_context(song_time)
	var seg: int = _LaneRemap.random_segment_index_for_context(
		song_time, game_screen.bpm, ctx
	)
	if _random_lane_segment >= 0 and seg == _random_lane_segment:
		return
	if (
		_random_lane_segment >= 0
		and song_time - _last_random_remap_song_time < _lane_remap_min_interval()
	):
		return
	_random_lane_segment = seg
	_last_random_remap_song_time = song_time
	if song_time < 0.05:
		return
	if game_screen.has_method("show_lane_remap_notice"):
		game_screen.show_lane_remap_notice(not random_lane_schedule.is_empty())


func reset_combo_escalation_state() -> void:
	_escalation_tier = -1
	_escalation_injected = ""
	_escalation_run_seed = randi()
	_escalation_used_ids.clear()
	if game_screen == null:
		return
	game_screen.run_modifiers = game_screen.run_modifiers_player.duplicate()


func bootstrap_combo_escalation() -> void:
	if game_screen == null:
		return
	if not _RunModifiers.is_combo_escalation(game_screen.run_modifiers_player):
		return
	if _escalation_tier >= 0:
		return
	_try_apply_escalation_tier(0)


func poll_combo_escalation() -> void:
	if game_screen == null or game_screen.score_manager == null:
		return
	if not _RunModifiers.is_combo_escalation(game_screen.run_modifiers_player):
		return
	if game_screen.countdown_active or not game_screen.gameplay_started:
		return
	var total_notes: int = game_screen.score_manager.total_notes
	if total_notes <= 0:
		return
	var notes_hit: int = game_screen.score_manager.get_hit_notes_count()
	var tier: int = _RunModifiers.combo_escalation_tier(
		notes_hit, total_notes, game_screen.run_modifier_params
	)
	if tier == _escalation_tier:
		return
	_try_apply_escalation_tier(tier)


func _try_apply_escalation_tier(tier: int) -> void:
	var song_path := str(game_screen.selected_song_data.get("path", ""))
	var picked := _RunModifiers.pick_escalation_modifier(
		game_screen.run_modifiers_player,
		_escalation_injected,
		_escalation_used_ids,
		song_path,
		tier,
		_escalation_run_seed,
		game_screen.run_modifier_params
	)
	if picked == "":
		return
	_escalation_tier = tier
	var changed := picked != _escalation_injected
	_escalation_injected = picked
	if not _escalation_used_ids.has(picked):
		_escalation_used_ids.append(picked)
	_rebuild_effective_modifiers()
	if not game_screen.run_modifiers.has(_escalation_injected):
		_escalation_injected = ""
		return
	if changed:
		_apply_escalation_runtime()
		if game_screen.has_method("show_combo_escalation_notice"):
			game_screen.show_combo_escalation_notice(picked)
		if game_screen.has_method("_sync_run_modifier_icon_row"):
			game_screen._sync_run_modifier_icon_row()


func _rebuild_effective_modifiers() -> void:
	game_screen.run_modifiers = game_screen.run_modifiers_player.duplicate()
	if _escalation_injected != "" and not game_screen.run_modifiers.has(_escalation_injected):
		game_screen.run_modifiers.append(_escalation_injected)
	game_screen.run_modifiers = _RunModifiers.sanitize(
		game_screen.run_modifiers,
		_escalation_injected
	)


func _apply_escalation_runtime() -> void:
	if _escalation_injected == _RunModifiers.ID_RANDOM_MODE:
		prepare_random_lanes_for_run(game_screen.selected_song_data)
	if _escalation_injected == _RunModifiers.ID_MEMORY_MODE:
		game_screen.note_manager.annotate_memory_patterns(game_screen.bpm)
	apply_runtime()
	game_screen._relayout_active_note_visuals()
	if game_screen.has_method("_configure_error_meter_for_run"):
		game_screen._configure_error_meter_for_run()


func on_run_start_memory_patterns() -> void:
	if _RunModifiers.is_memory_mode(game_screen.run_modifiers):
		game_screen.note_manager.annotate_memory_patterns(game_screen.bpm)


# --- Autoplay ---

func set_autoplay_late_ms(ms: float) -> void:
	autoplay_late_ms = maxf(0.0, ms)


func get_autoplay_late_ms() -> float:
	return autoplay_late_ms


func reset_autoplay_state() -> void:
	autoplay_press_until.clear()
	var player = game_screen.player
	if player and not player.lanes_state.is_empty():
		for i in range(player.lanes_state.size()):
			player.lanes_state[i] = false
		player.lane_pressed_changed.emit()
	for i in range(game_screen.lane_highlight_nodes.size()):
		if game_screen.lane_highlight_nodes[i]:
			game_screen.lane_highlight_nodes[i].visible = false


func simulate_autoplay() -> void:
	if game_screen.pauser and game_screen.pauser.is_paused:
		return
	if game_screen.has_method("is_resume_rewind_active") and game_screen.is_resume_rewind_active():
		return
	if not game_screen.notes_loaded:
		return
	_simulate_autoplay_for_manager(game_screen.note_manager, game_screen.hit_zone_y)
	_update_autoplay_lane_highlights()


func _simulate_autoplay_for_manager(nm: NoteManager, hit_zone_y: int) -> void:
	if nm == null:
		return
	var chart_now: float = game_screen.get_song_time()
	var tick: float = GAME_UPDATE_DELTA
	var force_perfect := _autoplay_force_perfect()
	var late_offset_s: float = 0.0 if force_perfect else autoplay_late_ms / 1000.0
	var late_limit: float = tick * 4.0 if force_perfect else hit_window_good() + late_offset_s

	var pending: Array = []
	for note in nm.get_notes():
		if note.is_missed:
			continue
		var lane_idx := int(note.lane)
		if lane_idx < 0:
			continue
		if lane_idx >= game_screen._chart_lanes:
			continue
		if not _RunModifiers.is_chart_lane_playable(
			game_screen.run_modifiers,
			lane_idx,
			game_screen.lanes,
			game_screen._chart_lanes,
			game_screen.lane_remap_context(float(note.time)),
			game_screen.run_modifier_params
		):
			continue
		if note.note_kind != "HoldNote" and note.note_kind != "BassHoldNote" and note.note_kind != "BassSustainNote" and note.note_kind != "BassSlideNote" and note.was_hit:
			continue
		if note.note_kind in ["HoldNote", "BassHoldNote", "BassSustainNote", "BassSlideNote"] and note.captured:
			continue
		pending.append(note)

	pending.sort_custom(func(a, b): return float(a.time) < float(b.time))

	for note in pending:
		var lane_idx := int(note.lane)
		var display_lane := _RunModifiers.display_lane_for_chart_lane(
			lane_idx,
			game_screen.lanes,
			game_screen._chart_lanes,
			game_screen.run_modifiers,
			game_screen.lane_remap_context(float(note.time)),
			game_screen.run_modifier_params
		)
		if display_lane < 0:
			continue
		var note_time := float(note.time)

		if note.note_kind in ["HoldNote", "BassHoldNote", "BassSustainNote", "BassSlideNote"] and note.is_being_held:
			var hold_until := note_time + float(note.duration) + 0.05
			autoplay_press_until[display_lane] = maxf(
				float(autoplay_press_until.get(display_lane, AUTOPLAY_NO_PRESS_TIME)),
				hold_until
			)
			continue

		# В идеальном автоплее ноту нельзя пропускать как «просроченную»: на
		# высокой скорости (Ускорение/Рывок) она за один кадр перескакивает зону
		# попадания, и такой пропуск оборачивался промахом. Поэтому ограничение
		# по позднему тайму применяем только в режиме с учётом окон попадания.
		if not force_perfect and chart_now > note_time + late_limit:
			continue

		var ready := false
		if note.note_kind in ["HoldNote", "BassHoldNote", "BassSustainNote", "BassSlideNote"]:
			ready = chart_now >= note_time - tick * 0.25 and (
				force_perfect or chart_now <= note_time + late_limit
			)
		elif force_perfect:
			# Позиция даёт красивое нажатие ровно по линии, но при резких скачках
			# скорости нота может проскочить зону за один кадр — поэтому дожимаем
			# её и по времени, как только чарт-время достигло её момента.
			ready = _autoplay_note_at_hit_line_for(note, hit_zone_y) or chart_now >= note_time
		else:
			var target_time := note_time + late_offset_s
			ready = chart_now >= target_time - tick * 0.25 and chart_now <= note_time + late_limit

		if not ready:
			continue

		game_screen.check_hit(display_lane, _autoplay_force_perfect(), note)

		if note.note_kind in ["HoldNote", "BassHoldNote", "BassSustainNote", "BassSlideNote"]:
			var hold_until2 := note_time + float(note.duration) + 0.05
			autoplay_press_until[display_lane] = maxf(
				float(autoplay_press_until.get(display_lane, AUTOPLAY_NO_PRESS_TIME)),
				hold_until2
			)
		else:
			var tap_until: float = chart_now + 0.08
			autoplay_press_until[display_lane] = maxf(
				float(autoplay_press_until.get(display_lane, AUTOPLAY_NO_PRESS_TIME)),
				tap_until
			)


func _apply_lanes_animated(target_lanes: int) -> void:
	target_lanes = clampi(target_lanes, 3, 5)
	if target_lanes == game_screen.lanes and (lane_change_tween == null or not lane_change_tween.is_running()):
		return
	var prev_lanes: int = game_screen.lanes
	game_screen.lanes = target_lanes
	if game_screen.player:
		game_screen.player.set_num_lanes(target_lanes)
	game_screen.note_manager.prune_non_play_lanes(
		game_screen.run_modifiers, game_screen.lanes, game_screen._chart_lanes
	)
	var playfield := game_screen.get_node_or_null("Playfield") as Control
	if playfield == null:
		game_screen._apply_playfield_width_for_lanes()
		game_screen._update_lane_layout()
		game_screen._relayout_active_note_visuals()
		return
	var start_left: float = playfield.anchor_left
	var start_right: float = playfield.anchor_right
	game_screen._apply_playfield_width_for_lanes()
	var end_left: float = playfield.anchor_left
	var end_right: float = playfield.anchor_right
	playfield.anchor_left = start_left
	playfield.anchor_right = start_right
	if lane_change_tween and lane_change_tween.is_valid():
		lane_change_tween.kill()
	lane_change_tween = game_screen.create_tween()
	lane_change_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	lane_change_tween.tween_property(playfield, "anchor_left", end_left, LANE_CHANGE_ANIM_SEC)
	lane_change_tween.parallel().tween_property(playfield, "anchor_right", end_right, LANE_CHANGE_ANIM_SEC)
	lane_change_tween.parallel().tween_method(_on_lane_width_anim_step, 0.0, 1.0, LANE_CHANGE_ANIM_SEC)
	lane_change_tween.finished.connect(_on_lane_width_anim_finished)
	_fade_lane_dividers(prev_lanes, target_lanes)


func _on_lane_width_anim_step(_t: float) -> void:
	game_screen._apply_playfield_width_for_lanes()
	game_screen._update_lane_layout()


func _on_lane_width_anim_finished() -> void:
	game_screen._apply_playfield_width_for_lanes()
	game_screen._update_lane_layout()
	game_screen._relayout_active_note_visuals()
	game_screen.note_manager.cull_notes_outside_playable_lanes(
		game_screen.run_modifiers, game_screen.lanes, game_screen._chart_lanes
	)


func _fade_lane_dividers(from_lanes: int, to_lanes: int) -> void:
	for d in range(game_screen.lane_divider_nodes.size()):
		var divider: ColorRect = game_screen.lane_divider_nodes[d]
		if divider == null:
			continue
		var lane_idx := d + 1
		var now_visible := lane_idx < to_lanes
		var was_visible := lane_idx < from_lanes
		if now_visible and not was_visible:
			divider.modulate.a = 0.0
			var tw: Tween = game_screen.create_tween()
			tw.tween_property(divider, "modulate:a", 1.0, LANE_CHANGE_ANIM_SEC * 0.85)
		elif not now_visible and was_visible:
			var tw: Tween = game_screen.create_tween()
			tw.tween_property(divider, "modulate:a", 0.0, LANE_CHANGE_ANIM_SEC * 0.55)


func _capture_ui_y_layout_snapshots() -> void:
	var ui := game_screen.get_node_or_null("UIContainer") as Control
	if ui == null:
		return
	for rel_path in _UI_MIRROR_RELPATHS:
		var node := ui.get_node_or_null(rel_path) as Control
		if node == null:
			continue
		var snap := {
			"anchor_top": node.anchor_top,
			"anchor_bottom": node.anchor_bottom,
			"offset_top": node.offset_top,
			"offset_bottom": node.offset_bottom,
		}
		if node is MarginContainer:
			snap["margin_top"] = node.get_theme_constant("margin_top")
			snap["margin_bottom"] = node.get_theme_constant("margin_bottom")
		ui_y_layout_snapshots[rel_path] = snap
	var playfield := game_screen.get_node_or_null("Playfield") as Control
	if playfield == null:
		return
	for rel_path in _PLAYFIELD_MIRROR_RELPATHS:
		var node := playfield.get_node_or_null(rel_path) as Control
		if node == null:
			continue
		ui_y_layout_snapshots["Playfield/" + rel_path] = {
			"anchor_top": node.anchor_top,
			"anchor_bottom": node.anchor_bottom,
			"offset_top": node.offset_top,
			"offset_bottom": node.offset_bottom,
		}


func _apply_control_y_layout(node: Control, snap: Dictionary, mirror: bool) -> void:
	if mirror:
		node.anchor_top = 1.0 - float(snap["anchor_bottom"])
		node.anchor_bottom = 1.0 - float(snap["anchor_top"])
		node.offset_top = -float(snap["offset_bottom"])
		node.offset_bottom = -float(snap["offset_top"])
	else:
		node.anchor_top = float(snap["anchor_top"])
		node.anchor_bottom = float(snap["anchor_bottom"])
		node.offset_top = float(snap["offset_top"])
		node.offset_bottom = float(snap["offset_bottom"])
	if node is MarginContainer and snap.has("margin_top"):
		var mc := node as MarginContainer
		if mirror:
			mc.add_theme_constant_override("margin_top", int(snap["margin_bottom"]))
			mc.add_theme_constant_override("margin_bottom", int(snap["margin_top"]))
		else:
			mc.add_theme_constant_override("margin_top", int(snap["margin_top"]))
			mc.add_theme_constant_override("margin_bottom", int(snap["margin_bottom"]))


func _reverse_scroll_hud_height(snap: Dictionary, fallback: float) -> float:
	var top := float(snap.get("offset_top", 0.0))
	var bottom := float(snap.get("offset_bottom", fallback))
	return maxf(absf(bottom - top), 8.0)


func _pin_reverse_scroll_hud() -> void:
	var ui := game_screen.get_node_or_null("UIContainer") as Control
	var playfield := game_screen.get_node_or_null("Playfield") as Control
	var hit_zone := game_screen.get_node_or_null("Playfield/HitZone") as Control
	if ui == null or playfield == null or hit_zone == null:
		return
	var bottom_hud := playfield.get_node_or_null("BottomHud") as Control
	if bottom_hud == null:
		return
	var hud_snap: Dictionary = ui_y_layout_snapshots.get("Playfield/BottomHud", {})
	var hud_h := _reverse_scroll_hud_height(hud_snap, 90.0)
	var gap := 12.0
	var anchor_global_y := hit_zone.global_position.y + hit_zone.size.y + gap
	var local_top := playfield.get_global_transform_with_canvas().affine_inverse() * Vector2(0.0, anchor_global_y)
	bottom_hud.anchor_top = 0.0
	bottom_hud.anchor_bottom = 0.0
	bottom_hud.offset_top = local_top.y
	bottom_hud.offset_bottom = local_top.y + hud_h

	var combo := ui.get_node_or_null("TopLeftCombo") as Control
	if combo:
		var combo_snap: Dictionary = ui_y_layout_snapshots.get("TopLeftCombo", {})
		var combo_h := _reverse_scroll_hud_height(combo_snap, 92.0)
		var combo_gap := 8.0
		var combo_top := local_top.y + hud_h + combo_gap
		combo.anchor_top = 0.0
		combo.anchor_bottom = 0.0
		combo.offset_top = combo_top
		combo.offset_bottom = combo_top + combo_h


func _autoplay_force_perfect() -> bool:
	if SettingsManager and SettingsManager.has_method("get_autoplay_respects_hit_windows"):
		return not SettingsManager.get_autoplay_respects_hit_windows()
	return true


func _autoplay_line_tolerance_px() -> float:
	return maxf(AUTOPLAY_LINE_TOLERANCE_MIN_PX, game_screen.speed * 1.8)


func _autoplay_note_at_hit_line(note) -> bool:
	return _autoplay_note_at_hit_line_for(note, game_screen.hit_zone_y)


func _autoplay_note_at_hit_line_for(note, hit_zone_y: int) -> bool:
	return absf(float(note.y) - float(hit_zone_y)) <= _autoplay_line_tolerance_px()


func _check_hit_for_autoplay(lane: int, note = null) -> void:
	if game_screen.pauser.is_paused or not game_screen.notes_loaded:
		return
	game_screen.check_hit(lane, _autoplay_force_perfect(), note)


func _update_autoplay_lane_highlights() -> void:
	var player = game_screen.player
	if not player or player.lanes_state.is_empty():
		return
	var layout_lanes: int = int(game_screen._layout_lane_count())
	var changed := false
	var now: float = game_screen.get_song_time()
	for i in range(layout_lanes):
		var should_pressed = autoplay_press_until.get(i, AUTOPLAY_NO_PRESS_TIME) > now
		if i < player.lanes_state.size() and player.lanes_state[i] != should_pressed:
			player.lanes_state[i] = should_pressed
			changed = true
	if changed:
		player.lane_pressed_changed.emit()
