# scenes/game_screen/game_screen.gd
extends Control

const ScoreManager = preload("res://logic/core/score_manager.gd")
const NoteManager = preload("res://logic/core/note_manager.gd")
const Player = preload("res://logic/core/player.gd")
const MAX_LAYOUT_LANES := 10
const DefeatScreenScene = preload("res://scenes/defeat_screen/defeat_screen.tscn")
const HitParticlePresets = preload("res://logic/domain/rhythm/hit_particle_presets.gd")
const _SpotlightTutorialScene = preload("res://ui/spotlight_tutorial.tscn")
const _PlayModeIds = preload("res://logic/domain/session/play_mode_ids.gd")
const _EndlessSessionConfig = preload("res://logic/domain/session/endless_session_config.gd")
const _ModifierIconStrip = preload("res://logic/ui/modifier_icon_strip.gd")
const _ResumeRewindOverlay = preload("res://scenes/game_screen/components/resume_rewind_overlay.gd")
const _RunRewards = preload("res://logic/domain/rewards/run_rewards.gd")
const _GuitarHeroBindings = preload("res://logic/domain/controls/guitar_hero_bindings.gd")
const ResultsHistoryService = preload("res://logic/data/results_history_service.gd")
const _UiRoundedClip = preload("res://logic/ui/ui_rounded_clip.gd")
const _GoalDiff = preload("res://logic/domain/generation/generation_goal_difficulty.gd")
const GAME_UPDATE_DELTA = 1.0 / 60.0
const ENDLESS_TRACK_CUE_SEC := 0.85
const ENDLESS_PROGRESS_RESET_SEC := 0.55
const ENDLESS_TRACK_REVEAL_HOLD_SEC := 2.4
const ENDLESS_TRACK_REVEAL_FADE_SEC := 0.9
const SERIES_INTER_TRACK_FADE_OUT_SEC := 0.38
const SERIES_INTER_TRACK_FADE_IN_SEC := 0.42
const SERIES_TRACK_REVEAL_COMPACT_HOLD_SEC := 1.15
const SERIES_TRACK_REVEAL_COMPACT_FADE_SEC := 0.55
const ENDLESS_MOD_REVEAL_ICON_SIZE := 36
const ENDLESS_MOD_REVEAL_FRAME_SIZE := 52
const RESUME_REWIND_SECONDS := 3.0
const RESUME_REWIND_ANIM_SECONDS := 1.5
const RESUME_REWIND_SNAPSHOT_INTERVAL := 0.08
const RESUME_REWIND_SNAPSHOT_KEEP := 4.5

var original_vsync_mode: int = DisplayServer.VSYNC_ADAPTIVE
var original_max_fps: int = 0
var pauser: GameScreenPauser = null

var game_time: float = 0.0
var countdown_remaining: int = 5
var countdown_active: bool = true
var pending_game_music_path: String = ""
var game_finished: bool = false
var input_enabled: bool = false

var bpm: float = 120.0
var speed: float = 6.0
var hit_zone_y: int = 900
var lanes: int = 4
var _chart_lanes: int = 4
var current_instrument: String = "standard"
var current_generation_mode: String = "basic"
var current_chart_tag: String = ""
var run_modifiers: Array[String] = []
var run_modifiers_player: Array[String] = []
var run_modifier_params: Dictionary = {}
var _score_reward_multiplier: float = 1.0

var selected_song_data: Dictionary = {}

var _play_mode: String = ""
var _endless_run_ref = null
var _endless_countdown_stack: VBoxContainer = null
var _endless_track_number_label: Label = null
var _endless_song_info_label: Label = null
var _endless_mod_reveal: HBoxContainer = null
var _endless_track_cue: Label = null
var _endless_display_track_index: int = 0
var _endless_pool_lap_announce: int = 0
var _marathon_run_ref = null
var _marathon_display_total_tracks: int = 0
var _endless_transition_busy: bool = false
var _endless_progress_tween: Tween = null
var _endless_reveal_tween: Tween = null
var _series_fade_tween: Tween = null
var _series_playfield_base_modulate: Color = Color(1, 1, 1, 1)

var defeat_overlay: Control = null

var score_manager
var note_manager
var player
var game_engine
var modifier_runtime: GameScreenModifierRuntime = null
var chart_compare: GameScreenChartCompare = null
var gen_qa: GameScreenGenQa = null
var audio_background: GameScreenAudioBackground = null
 
var score_label: Label = null
var combo_label: Label = null
var _run_mod_icon_flow: FlowContainer = null
var accuracy_label: Label = null
var countdown_label: Label = null
var notes_container: Node2D = null
var judgement_label: Label = null
var lane_change_label: Label = null
var progress_bar: ProgressBar = null
var hint_label: Label = null
var _transient_hint_text: String = ""
var _transient_hint_until_ms: int = 0
var health_bar: Node = null
var error_meter: ErrorMeter = null
var run_health_ratio: float = 1.0
var _combo_pulse_tween: Tween = null
var _last_combo_value: int = 0
var _combo_reset_tween: Tween = null
var _combo_original_position: Vector2 = Vector2.ZERO
var _combo_default_modulate: Color = Color(1, 1, 1, 1)
const PLAYFIELD_ANCHOR_LEFT_DEFAULT: float = 0.344
const PLAYFIELD_ANCHOR_RIGHT_DEFAULT: float = 0.656
const PLAYFIELD_WIDTH_FRACTION_DEFAULT: float = PLAYFIELD_ANCHOR_RIGHT_DEFAULT - PLAYFIELD_ANCHOR_LEFT_DEFAULT
var _spotlight_tutorial: CanvasLayer = null
var _score_tween: Tween = null
var _score_display_value_internal: float = 0.0
var score_display_value: float:
	set(value):
		_score_display_value_internal = value
		if score_label:
			score_label.text = _format_score_text(int(round(_score_display_value_internal)))
	get:
		return _score_display_value_internal
var _score_count_progress_internal: float = 0.0
var score_count_start: float = 0.0
var score_count_target: float = 0.0
@export var score_count_progress: float:
	set(value):
		_score_count_progress_internal = value
		var t = clamp(value, 0.0, 1.0)
		score_display_value = lerp(score_count_start, score_count_target, t)
	get:
		return _score_count_progress_internal
var animation_player: AnimationPlayer = null
var score_animation_player: AnimationPlayer = null
var accuracy_animation_player: AnimationPlayer = null
var _accuracy_display_value_internal: float = 0.0
var accuracy_display_value: float:
	set(value):
		_accuracy_display_value_internal = value
		if accuracy_label:
			accuracy_label.text = "%.2f%%" % value
	get:
		return _accuracy_display_value_internal
var _accuracy_count_progress_internal: float = 0.0
var accuracy_count_start: float = 0.0
var accuracy_count_target: float = 0.0
@export var accuracy_count_progress: float:
	set(value):
		_accuracy_count_progress_internal = value
		var t = clamp(value, 0.0, 1.0)
		accuracy_display_value = lerp(accuracy_count_start, accuracy_count_target, t)
	get:
		return _accuracy_count_progress_internal

var game_timer: Timer
var countdown_timer
var _countdown_tick_generation: int = 0
var check_song_end_timer: Timer

var notes_loaded: bool = false
var _run_assets_prepared: bool = false
var skip_used = false
var skip_time_threshold = 10.0
var skip_rewind_seconds = 5.0
var _rewind_active: bool = false
var _rewind_pause_at: float = 0.0
var _rewind_state_ring: Array = []
var _rewind_snapshot_accum: float = 0.0

var lane_highlight_nodes: Array[ColorRect] = []
var lane_nodes: Array[ColorRect] = []
var lane_divider_nodes: Array[ColorRect] = []
var _lane_layout_relayout_key: String = ""
const LANE_HIGHLIGHT_Z_INDEX := 1

var debug_menu = null
var auto_play_enabled: bool = false
var _mediator_up_scancodes: Array[int] = []
var _mediator_down_scancodes: Array[int] = []
var _last_strum_at_sec: float = -999.0
const STRUM_PAIR_WINDOW_S := 0.09
const HOLD_SUSTAIN_TICK_MS := 90.0
const HOLD_SUSTAIN_POINTS := 8
var _gh_lane_by_button: Dictionary = {}
var _gh_strum_buttons: Array[int] = []
var _gh_pause_button: int = -1
var _gh_skip_button: int = -1
var _gh_active_device_id: int = -1

var compare_note_manager:
	get:
		return chart_compare.note_manager if chart_compare else null

var perfect_hits_this_level: int = 0
# Накапливаем прогресс во время прогона и пишем на диск только в конце —
# иначе каждый хит дергает _save() / JSON и даёт микрофризы.
var _pending_daily_hit_notes: int = 0
var _pending_drum_perfect_hits: int = 0
var _pending_bass_perfect_hits: int = 0
var _pending_bass_ghost_hits: int = 0
var _pending_bass_multilane_hits: int = 0
var _pending_bass_perfect_holds: int = 0
var _run_bass_hold_early_releases: int = 0
var _accuracy_samples: Array = []
# Поланная статистика прогона: сколько нот по каждой отображаемой линии попали
# (perfect/good) и сколько промазали. Индекс массива = отображаемая линия.
var _lane_hit_counts: PackedInt32Array = PackedInt32Array()
var _lane_miss_counts: PackedInt32Array = PackedInt32Array()
# Живой личный рекорд: лучший счёт на этом чарте до текущего прогона (>0 — есть с
# чем сравнивать; -1/0 — отключено или рекорда ещё нет). Мигающую надпись
# показываем один раз, когда текущий счёт впервые превышает прежний рекорд.
var _prev_best_score: int = -1
var _new_record_triggered: bool = false
var _new_record_label: Label = null
var _hit_particle_preset: Dictionary = HitParticlePresets.DEFAULT_PRESET.duplicate(true)
var _hit_zone_pulse_timer: Timer = null
var _hit_zone_pulse_restore_color: Color = Color(1, 1, 1, 0.28)

var results_manager = null

var restart_timer: Timer = null
var is_restart_held: bool = false


const VICTORY_DELAY_AFTER_NOTES: float = 5.0
const EARLY_NOTE_THRESHOLD: float = 1.0
const MUSIC_START_DELAY_IF_EARLY_NOTES: float = 5.0 
var notes_ended: bool = false
var victory_delay_timer: Timer = null

var gameplay_started: bool = false

var rhythm_notifier: RhythmNotifier = null

const HIT_WINDOW_PERFECT: float = 0.05
const HIT_WINDOW_GOOD: float = 0.15
const HIT_KIND_MISS := "miss"
const HIT_KIND_PERFECT := "perfect"
const HIT_KIND_GOOD := "good"
const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const _DynamicLanesSchedule = preload("res://logic/domain/rhythm/dynamic_lanes_schedule.gd")
const RunHealth = preload("res://logic/domain/rhythm/run_health.gd")
const AUDIO_SYNC_DRIFT_THRESHOLD_SEC: float = 0.02
const TIMING_DEBUG_CSV_PATH := "user://timing_hit_debug.csv"
const TIMING_DEBUG_RING_MAX := 36

var timing_debug_overlay_label: Label = null
var _timing_debug_session_start_unix: int = 0
var _timing_signed_delta_ring_ms: Array[float] = []
var _timing_visual_delta_ring_ms: Array[float] = []
@export var judgement_color_perfect: Color = Color.YELLOW
@export var judgement_color_good: Color = Color.CYAN
@export var judgement_color_other: Color = Color.GRAY
@export var judgement_color_miss: Color = Color(0.85, 0.3, 0.34, 1.0)
var _judgement_tween: Tween = null
var _lane_change_tween: Tween = null
@export var combo_color_50: Color = Color(1.0, 0.75, 0.3, 1.0)
@export var combo_color_100: Color = Color(1.0, 0.9, 0.1, 1.0)


func _ready():
	add_to_group("locale_refresh")
	game_engine = get_parent()
	var game_theme = preload("res://ui/theme/game_theme.gd").build_theme()
	if $UIContainer:
		$UIContainer.theme = game_theme
	if not ResourceLoader.exists("res://ui/theme/game_theme.tres"):
		ResourceSaver.save(game_theme, "res://ui/theme/game_theme.tres")
	
	var transitions = null
	if game_engine and game_engine.has_method("get_transitions"):
		transitions = game_engine.get_transitions()

	original_max_fps = Engine.max_fps
	original_vsync_mode = DisplayServer.window_get_vsync_mode()


	var settings_for_player = SettingsManager.settings.duplicate(true)

	score_manager = ScoreManager.new(self)
	score_manager.set_score_reward_multiplier(_score_reward_multiplier)
	note_manager = NoteManager.new(self)
	player = Player.new(settings_for_player, lanes)  
	
	player.note_hit.connect(_on_player_hit)
	player.lane_pressed_changed.connect(_on_lane_pressed_changed) 
	_reload_control_bindings()
	if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.connect(_on_joy_connection_changed)

	modifier_runtime = GameScreenModifierRuntime.new()
	modifier_runtime.name = "ModifierRuntime"
	modifier_runtime.initialize(self)
	add_child(modifier_runtime)

	chart_compare = GameScreenChartCompare.new()
	chart_compare.name = "ChartCompare"
	chart_compare.initialize(self)
	add_child(chart_compare)

	gen_qa = GameScreenGenQa.new()
	gen_qa.name = "GenQa"
	gen_qa.initialize(self)
	add_child(gen_qa)

	audio_background = GameScreenAudioBackground.new()
	audio_background.name = "AudioBackground"
	audio_background.initialize(self)
	add_child(audio_background)

	_find_ui_elements()
	audio_background.find_background_elements()
	audio_background.setup_audio_reactive_visuals()
	audio_background.reset_visuals()
	call_deferred("_reset_run_health")
	var playfield_root := get_node_or_null("Playfield") as Control
	if playfield_root:
		playfield_root.resized.connect(_on_playfield_resized)
		_setup_playfield_rounded_clip(playfield_root)
	_instantiate_debug_menu()
	_load_lane_colors()
	_load_note_colors()
	_load_hit_particle_preset()
	
	speed = _effective_scroll_speed()
	
	_update_active_sounds_from_player_data()
	PlayerDataManager.active_item_changed.connect(_on_active_item_changed)
 
	_init_rhythm_notifier()

	game_timer = Timer.new()
	game_timer.wait_time = GAME_UPDATE_DELTA  
	game_timer.timeout.connect(_update_game)
	add_child(game_timer)
	
	check_song_end_timer = Timer.new()
	check_song_end_timer.wait_time = 0.1
	check_song_end_timer.timeout.connect(_check_song_end)
	add_child(check_song_end_timer)

	victory_delay_timer = Timer.new()
	victory_delay_timer.timeout.connect(_on_victory_delay_timeout)
	add_child(victory_delay_timer)

	pauser = GameScreenPauser.new()
	pauser.initialize(self, game_timer)
	add_child(pauser)
	pauser.song_select_requested.connect(_exit_to_song_select)
	pauser.settings_requested.connect(_open_settings_from_pause)
	pauser.exit_to_menu_requested.connect(_exit_to_main_menu)
	
	set_process_input(true)
	
	call_deferred("_begin_level_start")
	restart_timer = Timer.new()
	restart_timer.one_shot = true
	restart_timer.wait_time = 1.5  
	restart_timer.timeout.connect(_on_restart_confirmed)
	add_child(restart_timer)

	call_deferred("_refresh_run_hud_layout")
	call_deferred("apply_locale")


func apply_locale() -> void:
	_refresh_score_label()
	_update_hint()
	_timing_debug_update_overlay()


func _format_score_text(score: int) -> String:
	return tr("GAME_SCORE_FMT") % score


func _refresh_score_label() -> void:
	if score_label:
		score_label.text = _format_score_text(int(round(score_display_value)))


func _judgement_text(kind: String) -> String:
	match kind:
		HIT_KIND_PERFECT:
			return tr("GAME_JUDGE_PERFECT")
		HIT_KIND_GOOD:
			return tr("GAME_JUDGE_GOOD")
		_:
			return tr("GAME_JUDGE_MISS")


func _on_playfield_resized():
	call_deferred("_refresh_run_hud_layout")


func _setup_playfield_rounded_clip(playfield: Control) -> void:
	if playfield == null:
		return
	var style := playfield.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		var flat := (style as StyleBoxFlat).duplicate() as StyleBoxFlat
		# Fully opaque fill so clip_children does not multiply translucency onto notes/HUD.
		flat.bg_color = Color(flat.bg_color.r, flat.bg_color.g, flat.bg_color.b, 1.0)
		playfield.add_theme_stylebox_override("panel", flat)
	_UiRoundedClip.clip_to_frame(playfield)
	_UiRoundedClip.ensure_border_on_top(playfield)


func _init_rhythm_notifier():
	rhythm_notifier = RhythmNotifier.new()
	add_child(rhythm_notifier)
	rhythm_notifier.bpm = bpm
	rhythm_notifier.running = false
	if MusicManager.has_method("get_music_player"):
		var mp = MusicManager.get_music_player()
		if mp:
			rhythm_notifier.audio_stream_player = mp
	rhythm_notifier.beats(4).connect(_on_strong_beat)
	rhythm_notifier.beats(1.0).connect(_on_any_beat)

func _on_any_beat(_i):
	_pulse_hit_zone(false)

func _on_strong_beat(_i):
	_pulse_hit_zone(true)

func _spawn_hit_particles(lane: int, base_color: Color, perfect: bool) -> void:
	if not notes_container or not is_instance_valid(notes_container):
		return
	var lane_w := get_lane_width_at(lane)
	var lane_x := get_lane_left_x(lane)
	var pos := Vector2(lane_x + lane_w * 0.5, float(hit_zone_y))
	HitParticlePresets.spawn(notes_container, pos, base_color, perfect, _hit_particle_preset)

func _pulse_hit_zone(strong: bool):
	var hit_zone = get_node_or_null("Playfield/HitZone") as ColorRect
	if not hit_zone:
		return
	if _hit_zone_pulse_timer == null:
		_hit_zone_pulse_timer = Timer.new()
		_hit_zone_pulse_timer.one_shot = true
		_hit_zone_pulse_timer.wait_time = 0.08
		_hit_zone_pulse_timer.timeout.connect(_on_hit_zone_pulse_timeout)
		add_child(_hit_zone_pulse_timer)
	if not _hit_zone_pulse_timer.is_stopped():
		# Уже в пульсе — не перезаписываем исходный цвет и не плодим таймеры.
		hit_zone.color = Color(1, 1, 1, 1) if strong else Color(0.95, 0.95, 0.95, 1)
		_hit_zone_pulse_timer.start()
		return
	_hit_zone_pulse_restore_color = hit_zone.color
	hit_zone.color = Color(1, 1, 1, 1) if strong else Color(0.95, 0.95, 0.95, 1)
	_hit_zone_pulse_timer.start()


func _on_hit_zone_pulse_timeout() -> void:
	var hit_zone = get_node_or_null("Playfield/HitZone") as ColorRect
	if hit_zone and is_instance_valid(hit_zone):
		hit_zone.color = _hit_zone_pulse_restore_color

func set_autoplay_enabled(enabled: bool):
	if auto_play_enabled == enabled:
		return
	auto_play_enabled = enabled
	if modifier_runtime:
		modifier_runtime.reset_autoplay_state()
	
func is_autoplay_enabled() -> bool:
	return auto_play_enabled

func set_autoplay_late_ms(ms: float) -> void:
	if modifier_runtime:
		modifier_runtime.set_autoplay_late_ms(ms)

func get_autoplay_late_ms() -> float:
	return modifier_runtime.get_autoplay_late_ms() if modifier_runtime else 0.0

func get_song_time() -> float:
	if _rewind_active:
		return _rewind_pause_at
	if MusicManager.is_music_playing() and MusicManager.current_game_music_file != "":
		return MusicManager.get_game_music_position_precise() - AudioServer.get_output_latency()
	return game_time


func _resume_rewind_anchor_time() -> float:
	# Snapshots and note rewind use game_time; music position can read 0 while chart runs.
	var chart_t := maxf(0.0, game_time)
	var music_t := 0.0
	if MusicManager and MusicManager.is_music_playing() and MusicManager.current_game_music_file != "":
		music_t = MusicManager.get_game_music_position_precise()
		if music_t <= 0.0:
			music_t = MusicManager.get_game_music_position()
	return maxf(chart_t, music_t)

func get_note_pixels_per_sec() -> float:
	return speed * (1.0 / GAME_UPDATE_DELTA)

func is_reverse_scroll_active() -> bool:
	return modifier_runtime.is_reverse_scroll_active() if modifier_runtime else false

func get_note_scroll_sign() -> float:
	return modifier_runtime.note_scroll_sign() if modifier_runtime else 1.0

func note_y_for_chart_time(note_time: float, song_time: float, hit_y: float, px_per_sec: float) -> float:
	if modifier_runtime:
		return modifier_runtime.note_y_for_chart_time(note_time, song_time, hit_y, px_per_sec)
	return hit_y - (note_time - song_time) * px_per_sec

func note_spawn_travel_distance(playfield_h: float, hit_y: float) -> float:
	if modifier_runtime:
		return modifier_runtime.note_spawn_travel_distance(playfield_h, hit_y)
	return hit_y - (-20.0)

func note_spawn_offscreen(y_spawn: float, playfield_h: float) -> bool:
	if modifier_runtime:
		return modifier_runtime.note_spawn_offscreen(y_spawn, playfield_h)
	return y_spawn > playfield_h + 20.0

func _hit_time_for_judgement() -> float:
	var user_off_sec := 0.0
	if SettingsManager and SettingsManager.has_method("get_timing_offset_ms"):
		user_off_sec = float(SettingsManager.get_timing_offset_ms()) / 1000.0
	return get_song_time() + user_off_sec

func _autoplay_force_perfect() -> bool:
	if modifier_runtime:
		return modifier_runtime._autoplay_force_perfect()
	if SettingsManager and SettingsManager.has_method("get_autoplay_respects_hit_windows"):
		return not SettingsManager.get_autoplay_respects_hit_windows()
	return true

func _timing_debug_log_ok() -> bool:
	return SettingsManager and SettingsManager.has_method("get_timing_debug_log_hits") and SettingsManager.get_timing_debug_log_hits()

func _timing_debug_overlay_ok() -> bool:
	return SettingsManager and SettingsManager.has_method("get_timing_debug_overlay") and SettingsManager.get_timing_debug_overlay()

func _timing_debug_clear_ring() -> void:
	_timing_signed_delta_ring_ms.clear()
	_timing_visual_delta_ring_ms.clear()

func _timing_debug_push_signed_ms(signed_ms: float) -> void:
	if _timing_signed_delta_ring_ms.size() >= TIMING_DEBUG_RING_MAX:
		_timing_signed_delta_ring_ms.pop_front()
	_timing_signed_delta_ring_ms.append(signed_ms)

func _timing_debug_push_visual_ms(visual_ms: float) -> void:
	if _timing_visual_delta_ring_ms.size() >= TIMING_DEBUG_RING_MAX:
		_timing_visual_delta_ring_ms.pop_front()
	_timing_visual_delta_ring_ms.append(visual_ms)

func _timing_debug_mean_visual_ms() -> float:
	if _timing_visual_delta_ring_ms.is_empty():
		return 0.0
	var s := 0.0
	for x in _timing_visual_delta_ring_ms:
		s += x
	return s / float(_timing_visual_delta_ring_ms.size())

func _timing_debug_last_visual_ms() -> float:
	if _timing_visual_delta_ring_ms.is_empty():
		return 0.0
	return _timing_visual_delta_ring_ms[_timing_visual_delta_ring_ms.size() - 1]

func _timing_debug_mean_signed_ms() -> float:
	if _timing_signed_delta_ring_ms.is_empty():
		return 0.0
	var s := 0.0
	for x in _timing_signed_delta_ring_ms:
		s += x
	return s / float(_timing_signed_delta_ring_ms.size())

func _timing_debug_last_signed_ms() -> float:
	if _timing_signed_delta_ring_ms.is_empty():
		return 0.0
	return _timing_signed_delta_ring_ms[_timing_signed_delta_ring_ms.size() - 1]

func _timing_debug_ensure_overlay() -> void:
	if timing_debug_overlay_label != null and is_instance_valid(timing_debug_overlay_label):
		return
	var ui := get_node_or_null("UIContainer") as Control
	if ui == null:
		return
	var lbl := Label.new()
	lbl.name = "TimingDebugOverlay"
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	lbl.offset_left = -460.0
	lbl.offset_right = -12.0
	lbl.offset_top = 72.0
	lbl.offset_bottom = 260.0
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.55, 0.98))
	lbl.add_theme_font_size_override("font_size", 15)
	ui.add_child(lbl)
	timing_debug_overlay_label = lbl

func _timing_debug_update_overlay() -> void:
	if not _timing_debug_overlay_ok():
		if timing_debug_overlay_label:
			timing_debug_overlay_label.visible = false
		return
	_timing_debug_ensure_overlay()
	var lbl := timing_debug_overlay_label
	if lbl == null:
		return
	var show_os := gameplay_started and not game_finished and not countdown_active and not pauser.is_paused
	lbl.visible = show_os
	if not show_os:
		return
	var lat_ms := AudioServer.get_output_latency() * 1000.0
	var music_on := MusicManager.is_music_playing() and MusicManager.current_game_music_file != ""
	var music_pos := MusicManager.get_game_music_position() if music_on else -1.0
	var drift_ms := (music_pos - game_time) * 1000.0 if music_pos >= 0.0 else 0.0
	var n := _timing_signed_delta_ring_ms.size()
	var avg := _timing_debug_mean_signed_ms()
	var last := _timing_debug_last_signed_ms()
	var ap_line := ""
	if auto_play_enabled:
		ap_line = tr("GAME_TIMING_DEBUG_AP_HEADER") + "\n"
		var avg_v := _timing_debug_mean_visual_ms()
		var last_v := _timing_debug_last_visual_ms()
		ap_line += tr("GAME_TIMING_DEBUG_AP_AVG") % [avg_v, last_v] + "\n"
	lbl.text = (
		tr("GAME_TIMING_DEBUG_TITLE") + "\n"
		+ tr("GAME_TIMING_DEBUG_LATENCY") % lat_ms + "\n"
		+ tr("GAME_TIMING_DEBUG_DRIFT") % drift_ms + "\n"
		+ tr("GAME_TIMING_DEBUG_AVG_HIT") % [avg, n] + "\n"
		+ tr("GAME_TIMING_DEBUG_LAST") % last + "\n"
		+ ap_line
		+ tr("GAME_TIMING_DEBUG_HINT_EARLY_LATE") + "\n"
		+ tr("GAME_TIMING_DEBUG_HINT_OFFSET")
	)

func _timing_debug_emit_row(
	lane_idx: int,
	chart_t_json: float,
	note_t_geom: float,
	hit_t_adj: float,
	signed_ms: float,
	abs_ms: float,
	outcome: String,
	autoplay_forced: bool
) -> void:
	var music_on := MusicManager.is_music_playing() and MusicManager.current_game_music_file != ""
	var music_pos := MusicManager.get_game_music_position() if music_on else -1.0
	var drift_ms_val := (music_pos - game_time) * 1000.0 if music_pos >= 0.0 else 0.0
	var user_ms := int(SettingsManager.get_timing_offset_ms()) if SettingsManager.has_method("get_timing_offset_ms") else 0
	var audio_file := String(MusicManager.current_game_music_file if MusicManager else "")

	if _timing_debug_log_ok() or _timing_debug_overlay_ok():
		print("[TimingDebug] lane=%d chart=%.4f geom=%.4f hit_adj=%.4f signed_ms=%.1f abs_ms=%.1f %s autoplay_fp=%s lat_ms=%.1f music=%s drift_ms=%s"
			% [lane_idx, chart_t_json, note_t_geom, hit_t_adj, signed_ms, abs_ms, outcome, str(autoplay_forced),
				AudioServer.get_output_latency() * 1000.0, "on" if music_on else "off",
				("%.1f" % drift_ms_val) if music_pos >= 0.0 else "n/a"])

	if _timing_debug_overlay_ok() and outcome != "empty_zone":
		_timing_debug_push_signed_ms(signed_ms)

	if not _timing_debug_log_ok():
		return

	var path := TIMING_DEBUG_CSV_PATH
	var is_new := not FileAccess.file_exists(path)
	var f: FileAccess = null
	if is_new:
		f = FileAccess.open(path, FileAccess.WRITE)
	else:
		f = FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		return
	if not is_new:
		f.seek_end()
	if is_new:
		f.store_csv_line(PackedStringArray([
			"session_unix", "lane", "chart_time_json", "note_time_geom", "hit_time_adj",
			"signed_delta_ms", "abs_delta_ms", "outcome", "autoplay_forced", "music_playing",
			"output_latency_ms", "user_offset_ms", "game_time", "music_pos", "music_minus_game_ms", "audio_file",
		]))
	var row := PackedStringArray([
		str(_timing_debug_session_start_unix),
		str(lane_idx),
		"%f" % chart_t_json,
		"%f" % note_t_geom,
		"%f" % hit_t_adj,
		"%f" % signed_ms,
		"%f" % abs_ms,
		outcome,
		"1" if autoplay_forced else "0",
		"1" if music_on else "0",
		"%f" % (AudioServer.get_output_latency() * 1000.0),
		str(user_ms),
		"%f" % game_time,
		("%f" % music_pos) if music_pos >= 0.0 else "",
		("%f" % drift_ms_val) if music_pos >= 0.0 else "",
		audio_file,
	])
	f.store_csv_line(row)
	f.close()

func _timing_debug_log_session_start(song_path: String) -> void:
	if not _timing_debug_log_ok():
		return
	var path := TIMING_DEBUG_CSV_PATH
	var is_new := not FileAccess.file_exists(path)
	var f: FileAccess = null
	if is_new:
		f = FileAccess.open(path, FileAccess.WRITE)
	else:
		f = FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		return
	if not is_new:
		f.seek_end()
	if is_new:
		f.store_csv_line(PackedStringArray([
			"session_unix", "lane", "chart_time_json", "note_time_geom", "hit_time_adj",
			"signed_delta_ms", "abs_delta_ms", "outcome", "autoplay_forced", "music_playing",
			"output_latency_ms", "user_offset_ms", "game_time", "music_pos", "music_minus_game_ms", "audio_file",
		]))
	f.store_csv_line(PackedStringArray([
		str(_timing_debug_session_start_unix),
		"", "", "", "", "", "", "SESSION_START", "", "",
		"", "", "", "", "", song_path,
	]))
	f.close()
	print("[TimingDebug] SESSION_START unix=%d song=%s" % [_timing_debug_session_start_unix, song_path])

func _sync_game_time_with_game_music():
	if _rewind_active:
		return
	if game_time < 0.0:
		return
	if not MusicManager.is_music_playing():
		return
	if MusicManager.current_game_music_file == "":
		return
	# Match get_song_time(): precise playhead minus output latency.
	var target := MusicManager.get_game_music_position_precise() - AudioServer.get_output_latency()
	if target < 0.0:
		target = MusicManager.get_game_music_position()
	var drift = target - game_time
	if abs(drift) > AUDIO_SYNC_DRIFT_THRESHOLD_SEC:
		game_time = target

func _autoplay_chart_now() -> float:
	return get_song_time()

func _auto_play_simulate() -> void:
	if modifier_runtime:
		modifier_runtime.simulate_autoplay()

func _reset_autoplay_state() -> void:
	if modifier_runtime:
		modifier_runtime.reset_autoplay_state()

func _on_active_item_changed(category: String, item_id: String):
	if category == "Notes":
		_load_note_colors()
	if category == "HitParticles":
		_load_hit_particle_preset()
	if category == "Kick":
		var user_path = "user://shop_data.json"
		var path = user_path if FileAccess.file_exists(user_path) else "res://data/shop_data.json"
		var shop_data: Dictionary = JsonUtils.read_json_dict(path)
		for item in shop_data.get("items", []):
			if item.get("item_id", "") == item_id:
				var audio_path = item.get("audio", "")
				if audio_path:
					MusicManager.set_active_kick_sound(audio_path)
				break

func _update_active_sounds_from_player_data():
	var active_kick_id = PlayerDataManager.get_active_item("Kick")

	var user_path = "user://shop_data.json"
	var path = user_path if FileAccess.file_exists(user_path) else "res://data/shop_data.json"
	var shop_data: Dictionary = JsonUtils.read_json_dict(path)
	for item in shop_data.get("items", []):
		if item.get("item_id", "") == active_kick_id:
			var audio_path = item.get("audio", "")
			if audio_path:
				MusicManager.set_active_kick_sound(audio_path)
			break

func _instantiate_debug_menu():
	pass

func _sync_error_meter_theme() -> void:
	if error_meter == null:
		return
	error_meter.color_perfect = judgement_color_perfect
	error_meter.color_good = judgement_color_good
	error_meter.color_miss = judgement_color_miss


func _configure_error_meter_for_run() -> void:
	if error_meter == null:
		return
	_sync_error_meter_theme()
	var max_ms := _hit_window_good() * 1000.0 * 1.05
	error_meter.set_max_display_ms(max_ms)
	error_meter.clear()


func _push_error_meter(kind: String, signed_ms: float = 0.0) -> void:
	if error_meter == null or not _error_meter_should_show():
		return
	error_meter.push_entry(kind, signed_ms)


func _hud_shell_visible() -> bool:
	if game_finished:
		return false
	if _rewind_active and gameplay_started:
		return true
	if pauser and pauser.is_paused and gameplay_started:
		return true
	if countdown_active:
		return true
	return gameplay_started and notes_loaded


func _error_meter_should_show() -> bool:
	if not SettingsManager.get_show_error_meter():
		return false
	return _hud_shell_visible()


func _find_ui_elements():
	var ui_container_node = $UIContainer
	if ui_container_node:
		score_label = get_node_or_null("Playfield/BottomHud/StatsPanel/StatsContainer/ScoreLabel") as Label
		combo_label = ui_container_node.get_node_or_null("TopLeftCombo/ComboLabel") as Label
		_run_mod_icon_flow = ui_container_node.get_node_or_null("TopLeftCombo/ModifierIconFlow") as FlowContainer
		accuracy_label = get_node_or_null("Playfield/BottomHud/StatsPanel/StatsContainer/AccuracyLabel") as Label
		judgement_label = ui_container_node.get_node_or_null("JudgementLabel") as Label
		lane_change_label = ui_container_node.get_node_or_null("LaneChangeLabel") as Label
		if lane_change_label:
			lane_change_label.visible = false
			lane_change_label.modulate = Color(1, 1, 1, 0)
		if combo_label:
			_combo_original_position = combo_label.position
			_combo_default_modulate = combo_label.modulate
		animation_player = ui_container_node.get_node_or_null("AnimationPlayer") as AnimationPlayer
		score_animation_player = ui_container_node.get_node_or_null("ScoreAnimationPlayer") as AnimationPlayer
		accuracy_animation_player = ui_container_node.get_node_or_null("AccuracyAnimationPlayer") as AnimationPlayer

		var progress_container = ui_container_node.get_node_or_null("SongProgressContainer")
		if progress_container:
			progress_bar = progress_container.get_node_or_null("SongProgressBar") as ProgressBar
		
		hint_label = ui_container_node.get_node_or_null("HintLabel") as Label
		if hint_label:
			hint_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
			hint_label.clip_text = false
		health_bar = ui_container_node.get_node_or_null("HealthHud/HealthBar")
		if health_bar == null:
			push_warning("GameScreen: HealthBar not found at UIContainer/HealthHud/HealthBar")
		error_meter = get_node_or_null("Playfield/BottomHud/ErrorMeter") as ErrorMeter
		_sync_error_meter_theme()
	_capture_ui_y_layout_snapshots()

	countdown_label = get_node_or_null("UIContainer/CenterContainer/CountdownLabel") as Label
	if countdown_label == null:
		countdown_label = get_node_or_null("CountdownLabel") as Label
	notes_container = get_node_or_null("Playfield/NotesContainer") as Node2D

	var lanes_container_node = get_node_or_null("Playfield/LanesContainer") as Control
	if lanes_container_node:
		lane_highlight_nodes = [
			lanes_container_node.get_node_or_null("Lane0Highlight") as ColorRect,
			lanes_container_node.get_node_or_null("Lane1Highlight") as ColorRect,
			lanes_container_node.get_node_or_null("Lane2Highlight") as ColorRect,
			lanes_container_node.get_node_or_null("Lane3Highlight") as ColorRect,
			lanes_container_node.get_node_or_null("Lane4Highlight") as ColorRect
		]
		lane_nodes = [
			lanes_container_node.get_node_or_null("Lane0") as ColorRect,
			lanes_container_node.get_node_or_null("Lane1") as ColorRect,
			lanes_container_node.get_node_or_null("Lane2") as ColorRect,
			lanes_container_node.get_node_or_null("Lane3") as ColorRect,
			lanes_container_node.get_node_or_null("Lane4") as ColorRect  
		]
		lane_divider_nodes = [
			lanes_container_node.get_node_or_null("LaneDivider0") as ColorRect,
			lanes_container_node.get_node_or_null("LaneDivider1") as ColorRect,
			lanes_container_node.get_node_or_null("LaneDivider2") as ColorRect,
			lanes_container_node.get_node_or_null("LaneDivider3") as ColorRect
		]
		_apply_lane_highlight_draw_order()


func _apply_lane_highlight_draw_order() -> void:
	for lane_node in lane_nodes:
		if lane_node:
			lane_node.z_index = 0
	for hl in lane_highlight_nodes:
		if hl:
			hl.z_index = LANE_HIGHLIGHT_Z_INDEX


func _ensure_lane_ui_capacity(needed: int) -> void:
	var lanes_container_node := get_node_or_null("Playfield/LanesContainer") as Control
	if lanes_container_node == null:
		return
	var cap := clampi(needed, 1, MAX_LAYOUT_LANES)
	var lane_template := lanes_container_node.get_node_or_null("Lane0") as ColorRect
	var highlight_template := lanes_container_node.get_node_or_null("Lane0Highlight") as ColorRect
	var divider_template := lanes_container_node.get_node_or_null("LaneDivider0") as ColorRect
	while lane_nodes.size() < cap:
		var idx := lane_nodes.size()
		var lane := ColorRect.new()
		lane.name = "Lane%d" % idx
		lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if lane_template:
			lane.color = lane_template.color
		lane.z_index = 0
		lanes_container_node.add_child(lane)
		lane_nodes.append(lane)
		var highlight := ColorRect.new()
		highlight.name = "Lane%dHighlight" % idx
		highlight.visible = false
		highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		highlight.z_index = LANE_HIGHLIGHT_Z_INDEX
		if highlight_template:
			highlight.color = highlight_template.color
		lanes_container_node.add_child(highlight)
		lane_highlight_nodes.append(highlight)
	while lane_divider_nodes.size() < cap - 1:
		var divider_idx := lane_divider_nodes.size()
		var divider := ColorRect.new()
		divider.name = "LaneDivider%d" % divider_idx
		divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if divider_template:
			divider.color = divider_template.color
			divider.z_index = divider_template.z_index
		lanes_container_node.add_child(divider)
		lane_divider_nodes.append(divider)

func _load_lane_colors():
	var active_lane_highlight_id = PlayerDataManager.get_active_item("LaneHighlight")
	var user_path = "user://shop_data.json"
	var path = user_path if FileAccess.file_exists(user_path) else "res://data/shop_data.json"
	var shop_data: Dictionary = JsonUtils.read_json_dict(path)
	if shop_data.is_empty():
		_set_lane_highlight_colors(Color("#fec6e580"))
	else:
		for item in shop_data.get("items", []):
			if item.get("item_id", "") == active_lane_highlight_id:
				var color_hex = item.get("color_hex", "#fec6e580")
				var lane_highlight_color = Color(color_hex)
				_set_lane_highlight_colors(lane_highlight_color)
				break

func _load_note_colors():
	if note_manager == null:
		return
	var active_notes_id = PlayerDataManager.get_active_item("Notes")
	var user_path2 = "user://shop_data.json"
	var path2 = user_path2 if FileAccess.file_exists(user_path2) else "res://data/shop_data.json"
	var shop_data2: Dictionary = JsonUtils.read_json_dict(path2)
	for item in shop_data2.get("items", []):
		if item.get("item_id", "") == active_notes_id:
			var colors = item.get("note_colors", [])
			if not colors.is_empty():
				if _RunModifiers.is_single_lane(run_modifiers):
					colors = _RunModifiers.expand_note_palette_for_single_lane(colors)
				note_manager.set_note_colors(colors)
			break


func _load_hit_particle_preset() -> void:
	_hit_particle_preset = HitParticlePresets.resolve_active_preset()


func _set_lane_highlight_colors(color: Color):
	for lane_node in lane_highlight_nodes:
		if lane_node and lane_node is ColorRect:
			lane_node.z_index = LANE_HIGHLIGHT_Z_INDEX
			var b = SettingsManager.get_lane_highlight_brightness() if SettingsManager.has_method("get_lane_highlight_brightness") else 100.0
			var a = clamp(color.a * (b / 100.0), 0.0, 1.0)
			lane_node.color = Color(color.r, color.g, color.b, a)

func _on_player_hit(lane: int):
	if _defeat_blocks_gameplay_input() or game_finished or not input_enabled:
		return
	if pauser.is_paused:
		return
	if _modifier_strum_mode() and not _strum_is_fresh():
		return
	check_hit(lane)


func _modifier_strum_mode() -> bool:
	return _RunModifiers.has_modifier(run_modifiers, _RunModifiers.ID_PICK_MODE)


func _reload_control_bindings() -> void:
	if SettingsManager:
		if player:
			var keymap := SettingsManager.build_active_lane_keymap()
			if _RunModifiers.is_single_lane(run_modifiers):
				keymap = _RunModifiers.build_single_lane_keymap(keymap, _layout_lane_count())
			player.set_keymap(keymap)
			player.set_num_lanes(_layout_lane_count())
		_mediator_up_scancodes = SettingsManager.get_active_mediator_up_scancodes()
		_mediator_down_scancodes = SettingsManager.get_active_mediator_down_scancodes()
	_reload_gh_bindings()


func _reload_gh_bindings() -> void:
	_gh_lane_by_button.clear()
	_gh_strum_buttons.clear()
	_gh_active_device_id = -1
	if SettingsManager == null or not SettingsManager.get_controls_gh_enabled():
		return
	_gh_active_device_id = SettingsManager.resolve_gh_device_id()
	if _gh_active_device_id < 0:
		return
	var lane_buttons := SettingsManager.get_controls_gh_lane_buttons()
	for lane in range(mini(lane_buttons.size(), _GuitarHeroBindings.MAX_LANES)):
		_gh_lane_by_button[int(lane_buttons[lane])] = lane
	_gh_strum_buttons = [
		SettingsManager.get_controls_gh_strum_up_button(),
		SettingsManager.get_controls_gh_strum_down_button(),
	]
	_gh_pause_button = SettingsManager.get_controls_gh_pause_button()
	_gh_skip_button = SettingsManager.get_controls_gh_skip_button()


func _gh_input_active() -> bool:
	return SettingsManager != null and SettingsManager.get_controls_gh_enabled() and _gh_active_device_id >= 0


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_reload_gh_bindings()


func _gh_joypad_matches(event: InputEventJoypadButton) -> bool:
	if not _gh_input_active():
		return false
	return event.device == _gh_active_device_id


func _gh_handle_system_button(event: InputEventJoypadButton) -> bool:
	if not _gh_joypad_matches(event) or not event.pressed:
		return false
	var button_index := event.button_index
	if button_index == _gh_skip_button:
		if countdown_active:
			skip_countdown()
			accept_event()
			return true
		if _can_skip_to_next_track():
			end_game()
			accept_event()
			return true
		if not input_enabled or _defeat_blocks_gameplay_input() or game_finished:
			return false
		if pauser and pauser.is_paused:
			return false
		if skip_intro():
			_update_hint()
			accept_event()
			return true
		return false
	if button_index == _gh_pause_button and not countdown_active:
		if _defeat_blocks_gameplay_input():
			return false
		if _rewind_active:
			return false
		if pauser.is_paused:
			if _pause_overlay_blocks_esc():
				return false
			pauser.handle_resume_request()
		else:
			pauser.handle_pause_request()
		accept_event()
		return true
	return false


func _handle_gh_joypad_button(event: InputEventJoypadButton) -> void:
	if not _gh_joypad_matches(event) or player == null:
		return
	if _gh_handle_system_button(event):
		return
	if _defeat_blocks_gameplay_input() or game_finished or not input_enabled or countdown_active:
		return
	if pauser and pauser.is_paused:
		return
	if is_autoplay_enabled():
		return
	var button_index := event.button_index
	if _gh_strum_buttons.has(button_index):
		if event.pressed:
			_register_strum_input()
			accept_event()
		return
	if not _gh_lane_by_button.has(button_index):
		return
	var lane := int(_gh_lane_by_button[button_index])
	if event.pressed:
		player.press_lane(lane)
		accept_event()
	else:
		player.release_lane(lane)
		accept_event()


func _reload_strum_keys() -> void:
	_reload_control_bindings()


func _strum_is_fresh() -> bool:
	return (Time.get_ticks_usec() / 1000000.0 - _last_strum_at_sec) <= STRUM_PAIR_WINDOW_S


func _is_mediator_key(keycode: int) -> bool:
	return _mediator_up_scancodes.has(keycode) or _mediator_down_scancodes.has(keycode)


func _register_strum_input() -> void:
	_last_strum_at_sec = Time.get_ticks_usec() / 1000000.0
	if not _modifier_strum_mode() or player == null:
		return
	for i in range(mini(lanes, player.lanes_state.size())):
		if player.lanes_state[i]:
			check_hit(i)
	
func set_results_manager(results_mgr):
	results_manager = results_mgr
	
func _on_lane_pressed_changed():
	if not player:
		return
	var layout_lanes := _layout_lane_count()
	var single_lane := _RunModifiers.is_single_lane(run_modifiers)
	var single_lane_collapsed := single_lane and _RunModifiers.single_lane_is_collapsed(
		run_modifiers, run_modifier_params
	)
	var any_pressed := false
	if single_lane_collapsed:
		for i in range(player.lanes_state.size()):
			if player.lanes_state[i]:
				any_pressed = true
				break
	for i in range(mini(layout_lanes, lane_highlight_nodes.size())):
		var hl = lane_highlight_nodes[i]
		if not hl:
			continue
		if single_lane_collapsed:
			hl.visible = any_pressed and i == 0
		elif i >= player.lanes_state.size():
			hl.visible = false
		else:
			hl.visible = player.lanes_state[i]
	for i in range(layout_lanes, lane_highlight_nodes.size()):
		var extra_hl = lane_highlight_nodes[i]
		if extra_hl:
			extra_hl.visible = false
	_process_hold_sustain()


func _process_hold_sustain() -> void:
	if not gameplay_started or pauser.is_paused or _rewind_active or not notes_loaded:
		return
	if player == null or note_manager == null or score_manager == null:
		return
	var song_time := get_song_time()
	for note in note_manager.get_notes():
		if str(note.note_kind) not in note_manager.BASS_SUSTAIN_KINDS:
			continue
		if not note.was_hit or note.captured:
			continue
		var display_lane := int(note.display_lane)
		if display_lane < 0 or display_lane >= player.lanes_state.size():
			continue
		if note.is_being_held and not player.lanes_state[display_lane]:
			note.is_being_held = false
			note.hold_released_early = true
			if current_instrument == "bass":
				_run_bass_hold_early_releases += 1
			continue
		if not note.is_being_held or note.hold_released_early:
			continue
		if song_time > float(note.time) + float(note.duration):
			note.captured = true
			note.active = false
			if current_instrument == "bass" and not note.perfect_hold_counted:
				note.perfect_hold_counted = true
				_pending_bass_perfect_holds += 1
			continue
		var elapsed_ms := (song_time - float(note.time)) * 1000.0
		if elapsed_ms - float(note.hold_last_tick_ms) < HOLD_SUSTAIN_TICK_MS:
			continue
		note.hold_last_tick_ms = elapsed_ms
		score_manager.add_hold_sustain_points(HOLD_SUSTAIN_POINTS)
	_tally_new_bass_perfect_holds()


func _tally_new_bass_perfect_holds() -> void:
	if current_instrument != "bass" or note_manager == null:
		return
	for note in note_manager.get_notes():
		if note == null:
			continue
		if str(note.note_kind) not in note_manager.BASS_SUSTAIN_KINDS:
			continue
		if note.captured and not note.hold_released_early and not note.perfect_hold_counted:
			note.perfect_hold_counted = true
			_pending_bass_perfect_holds += 1

func start_countdown():
	if not _run_assets_prepared:
		_prepare_run_assets()
	_cancel_countdown_tick()
	_hide_endless_mod_reveal()
	countdown_active = true
	_prepare_health_intro()
	_configure_error_meter_for_run()
	_sync_health_bar_visibility()
	if error_meter:
		error_meter.visible = _error_meter_should_show()
	input_enabled = false
	countdown_remaining = 5
	update_countdown_display()
	_update_hint()
	_refresh_run_hud_layout()
	call_deferred("_refresh_run_hud_layout")
	var layout_timer := get_tree().create_timer(0.05)
	layout_timer.timeout.connect(_refresh_run_hud_layout, CONNECT_ONE_SHOT)

	_schedule_countdown_tick()

	game_timer.start()


func _cancel_countdown_tick() -> void:
	_countdown_tick_generation += 1
	countdown_timer = null


func _schedule_countdown_tick() -> void:
	var generation := _countdown_tick_generation
	var scene_tree_timer = get_tree().create_timer(1.0)
	scene_tree_timer.timeout.connect(func() -> void:
		if generation != _countdown_tick_generation:
			return
		_update_countdown()
	, CONNECT_ONE_SHOT)
	countdown_timer = scene_tree_timer


func _can_skip_to_next_track() -> bool:
	return (
		notes_ended
		and not game_finished
		and not _endless_transition_busy
		and not _defeat_blocks_gameplay_input()
		and not _rewind_active
		and (pauser == null or not pauser.is_paused)
	)


func _update_countdown():
	if not countdown_active:
		return
	
	countdown_remaining -= 1
	update_countdown_display()
	_update_hint()
	
	if countdown_remaining <= 0:
		countdown_active = false
		if countdown_label: 
			countdown_label.visible = false
		input_enabled = true
		_refresh_run_hud_layout()
		if _is_series_mode():
			_fade_series_playfield_in()
			_show_series_track_reveal(false)
		start_gameplay()
		_reset_run_health()
		_update_hint()
	else:
		_schedule_countdown_tick()

func _begin_level_start() -> void:
	_maybe_show_gameplay_tutorial()


func _maybe_show_gameplay_tutorial(force: bool = false) -> void:
	if not SettingsManager or not SettingsManager.has_method("get_tutorial_gameplay_done"):
		start_countdown()
		return
	if not force and SettingsManager.get_tutorial_gameplay_done():
		start_countdown()
		return
	if _spotlight_tutorial == null:
		_spotlight_tutorial = _SpotlightTutorialScene.instantiate() as CanvasLayer
		if _spotlight_tutorial == null:
			start_countdown()
			return
		add_child(_spotlight_tutorial)
		if not _spotlight_tutorial.finished.is_connected(_on_gameplay_tutorial_closed):
			_spotlight_tutorial.finished.connect(_on_gameplay_tutorial_closed)
		if not _spotlight_tutorial.skipped.is_connected(_on_gameplay_tutorial_closed):
			_spotlight_tutorial.skipped.connect(_on_gameplay_tutorial_closed)
	var hit_zone := get_node_or_null("Playfield/HitZone") as Control
	var hud_target: Control = null
	if SettingsManager.get_show_health_bar():
		hud_target = get_node_or_null("UIContainer/HealthHud") as Control
	if hud_target == null:
		hud_target = get_node_or_null("Playfield/BottomHud/StatsPanel") as Control
	var playfield := get_node_or_null("Playfield") as Control
	var steps: Array = [
		{
			"title_key": "TUTORIAL_GP_1_TITLE",
			"body_key": "TUTORIAL_GP_1_BODY",
			"target": hit_zone,
		},
	]
	if hud_target:
		steps.append({
			"title_key": "TUTORIAL_GP_2_TITLE",
			"body_key": "TUTORIAL_GP_2_BODY",
			"target": hud_target,
		})
	steps.append({
		"title_key": "TUTORIAL_GP_3_TITLE",
		"body_key": "TUTORIAL_GP_3_BODY",
		"target": playfield,
	})
	if _spotlight_tutorial.has_method("start"):
		_spotlight_tutorial.start(steps)


func _on_gameplay_tutorial_closed() -> void:
	if SettingsManager and SettingsManager.has_method("set_tutorial_gameplay_done"):
		SettingsManager.set_tutorial_gameplay_done(true)
	start_countdown()


func debug_show_tutorial() -> void:
	_maybe_show_gameplay_tutorial(true)


func _set_selected_song(song_data):
	if song_data == null:
		selected_song_data = {}
	elif song_data is Dictionary:
		selected_song_data = song_data.duplicate(true)
	elif song_data is String:
		selected_song_data = {"path": song_data}
	else:
		selected_song_data = {}

func _set_instrument(instrument_type: String):
	current_instrument = instrument_type
		
func _set_lanes(lane_count: int):
	lanes = clamp(lane_count, 3, 5)
	print("GameScreen.gd: Установлено количество линий: ", lanes)
	_apply_playfield_width_for_lanes()
	_update_lane_layout()


func _set_chart_tag(chart_tag: String) -> void:
	current_chart_tag = NotesUtils.normalize_chart_tag(chart_tag)


func get_chart_lanes() -> int:
	return _chart_lanes


func lane_remap_context(note_time: float = 0.0) -> Dictionary:
	var ctx := {
		"song_path": str(selected_song_data.get("path", "")),
		"note_time": note_time,
		"bpm": bpm,
		"dna_schedule": [],
	}
	if modifier_runtime:
		ctx["dna_schedule"] = modifier_runtime.get_random_lane_schedule()
	return ctx


func _setup_dynamic_lanes_for_run(song_data: Dictionary) -> void:
	if modifier_runtime:
		modifier_runtime.prepare_dynamic_lanes_for_run(song_data)


func _poll_dynamic_lane_schedule() -> void:
	if modifier_runtime:
		modifier_runtime.poll_dynamic_lane_schedule()
		modifier_runtime.poll_random_lane_remap()


func refresh_playfield_layout() -> void:
	_refresh_run_hud_layout()


func _playfield_width_scale() -> float:
	var layout_lanes := maxi(_layout_lane_count(), 1)
	var ref_lanes := clampi(lanes, 3, 5)
	var base_pct := 100.0
	if SettingsManager and SettingsManager.has_method("get_playfield_width_percent"):
		base_pct = SettingsManager.get_playfield_width_percent(ref_lanes)
	# При Single Lane / Dynamic Lanes расширяем поле, чтобы ширина одной линии
	# оставалась близкой к обычному чарту (3–5 линий).
	return (base_pct / 100.0) * (float(layout_lanes) / float(ref_lanes))


func _setup_chart_compare_charts(song_data: Dictionary) -> void:
	if chart_compare:
		chart_compare.setup_for_run(song_data)


func _chart_compare_hotkey_ready() -> bool:
	return chart_compare.hotkey_ready() if chart_compare else false


func _swap_chart_ab_hotkey() -> void:
	if chart_compare:
		chart_compare.swap_hotkey()


func _chart_compare_hint_line() -> String:
	return chart_compare.hint_line() if chart_compare else ""


func _setup_split_compare_charts(song_data: Dictionary) -> void:
	_setup_chart_compare_charts(song_data)


func _playfield_anchor_bounds() -> Vector2:
	var width_fraction := PLAYFIELD_WIDTH_FRACTION_DEFAULT * _playfield_width_scale()
	var layout_lanes := _layout_lane_count()
	var max_fraction := 0.48
	if layout_lanes > 5:
		max_fraction = clampf(0.48 + float(layout_lanes - 5) * 0.034, 0.48, 0.74)
	width_fraction = clampf(width_fraction, 0.18, max_fraction)
	var half := width_fraction * 0.5
	return Vector2(0.5 - half, 0.5 + half)


func _apply_playfield_width_for_lanes() -> void:
	var left := 0.0
	var right := 1.0
	var playfield := get_node_or_null("Playfield") as Control
	if chart_compare and chart_compare.split_active_runtime:
		var split: Dictionary = chart_compare.apply_playfield_width(playfield)
		left = float(split.get("left", left))
		right = float(split.get("right", right))
	else:
		var bounds := _playfield_anchor_bounds()
		left = bounds.x
		right = bounds.y
		if playfield:
			playfield.anchor_left = left
			playfield.anchor_right = right

	var background := get_node_or_null("Background") as Control
	if background:
		var glow_left := background.get_node_or_null("BgGlowLeft") as Control
		var glow_right := background.get_node_or_null("BgGlowRight") as Control
		if glow_left:
			glow_left.anchor_right = left
		if glow_right:
			glow_right.anchor_left = right

	var ui := get_node_or_null("UIContainer") as Control
	if ui == null:
		return

	var progress := ui.get_node_or_null("SongProgressContainer") as Control
	if progress:
		# Inset from playfield corner radius so the bar doesn't paint over the rounded frame.
		const PROGRESS_CORNER_INSET := 14.0
		progress.anchor_left = left
		progress.anchor_right = right
		progress.offset_left = PROGRESS_CORNER_INSET
		progress.offset_right = -PROGRESS_CORNER_INSET

	var combo := ui.get_node_or_null("TopLeftCombo") as Control
	if combo:
		combo.anchor_left = left

	var health_hud := ui.get_node_or_null("HealthHud") as Control
	if health_hud:
		health_hud.anchor_left = right
		health_hud.anchor_right = right
		# Keep a clear gap so the HP track doesn't sit on the playfield border/lanes.
		health_hud.offset_left = 10.0
		health_hud.offset_right = 34.0


func _lane_left_edges_px(playfield_w: float, lane_count: int) -> PackedFloat32Array:
	var ln: int = maxi(lane_count, 1)
	var edges := PackedFloat32Array()
	edges.resize(ln + 1)
	var total_px: int = maxi(int(round(playfield_w)), ln)
	var base_w: int = total_px / ln
	var rem: int = total_px % ln
	var cum: int = 0
	edges[0] = 0.0
	for i in range(ln):
		cum += base_w + (1 if i < rem else 0)
		edges[i + 1] = float(cum)
	edges[ln] = playfield_w
	return edges


func _update_lane_layout():
	var hit_zone = get_node_or_null("Playfield/HitZone") as ColorRect
	var playfield = get_node_or_null("Playfield") as Control
	var lanes_parent := get_node_or_null("Playfield/LanesContainer") as Control
	if not hit_zone or not playfield:
		return
	if modifier_runtime:
		modifier_runtime.apply_hit_zone_anchors(hit_zone, is_reverse_scroll_active())
	var start_x := 0.0
	var playfield_width: float = maxf(playfield.size.x, hit_zone.size.x)
	var playfield_height: float = playfield.size.y
	var lane_y: float = hit_zone.position.y
	if lanes_parent:
		lane_y = hit_zone.global_position.y - lanes_parent.global_position.y

	var layout_lanes := _RunModifiers.layout_lane_count(run_modifiers, lanes, run_modifier_params)
	_ensure_lane_ui_capacity(layout_lanes)
	_apply_lane_highlight_draw_order()
	if player and player.num_active_lanes != layout_lanes:
		_reload_control_bindings()
	var lane_edges := _lane_left_edges_px(playfield_width, layout_lanes)
	var single_lane_collapsed := _RunModifiers.is_single_lane(run_modifiers) and _RunModifiers.single_lane_is_collapsed(
		run_modifiers, run_modifier_params
	)

	for i in range(lane_nodes.size()):
		var is_active := (i < layout_lanes)
		var x0 := 0.0
		var lw := 0.0
		if is_active:
			x0 = start_x + lane_edges[i]
			lw = lane_edges[i + 1] - lane_edges[i]

		if i < lane_nodes.size():
			var lane_node = lane_nodes[i]
			if lane_node:
				lane_node.visible = is_active
				if is_active:
					lane_node.position.x = x0
					lane_node.size.x = lw
					lane_node.position.y = lane_y
					lane_node.size.y = hit_zone.size.y
					lane_node.modulate = Color(1, 1, 1, 1)

		if i < lane_highlight_nodes.size():
			var highlight_node = lane_highlight_nodes[i]
			if highlight_node:
				if is_active:
					var hl_x := x0
					var hl_w := lw
					if single_lane_collapsed:
						hl_w = _RunModifiers.single_lane_note_width(playfield_width)
						hl_x = _RunModifiers.single_lane_note_x(playfield_width)
					highlight_node.position.x = hl_x
					highlight_node.size.x = hl_w
					highlight_node.position.y = 0.0
					highlight_node.size.y = playfield_height
					highlight_node.visible = false
					highlight_node.modulate = Color(1, 1, 1, 1)
				else:
					highlight_node.visible = false

	for d in range(lane_divider_nodes.size()):
		var divider := lane_divider_nodes[d]
		if divider == null:
			continue
		var lane_idx := d + 1
		divider.visible = lane_idx < layout_lanes
		if divider.visible:
			var x_edge := start_x + lane_edges[lane_idx]
			divider.position = Vector2(x_edge - 1.0, 0.0)
			divider.size = Vector2(2.0, playfield_height)

	hit_zone_y = int(hit_zone.global_position.y - playfield.global_position.y)

	if chart_compare:
		chart_compare.sync_compare_hit_zone(hit_zone)

	if player:
		_on_lane_pressed_changed()
	if modifier_runtime:
		modifier_runtime.apply_reverse_scroll_ui_layout(is_reverse_scroll_active())
	var relayout_key := "%d|%.2f|%.2f|%s" % [
		layout_lanes,
		playfield_width,
		playfield_height,
		str(_RunModifiers.single_lane_is_collapsed(run_modifiers, run_modifier_params)),
	]
	if relayout_key != _lane_layout_relayout_key:
		_lane_layout_relayout_key = relayout_key
		_relayout_active_note_visuals()


func relayout_active_note_visuals() -> void:
	_lane_layout_relayout_key = ""
	_relayout_active_note_visuals()


func _relayout_active_note_visuals() -> void:
	if note_manager == null:
		return
	for note in note_manager.get_notes():
		if note == null or not note.active or note.visual_node == null:
			continue
		if not (note.visual_node is ColorRect):
			continue
		var lane_idx: int = int(note.lane)
		var chart_lanes := get_chart_lanes()
		var display_lane := _RunModifiers.display_lane_for_chart_lane(
			lane_idx, lanes, chart_lanes, run_modifiers, lane_remap_context(float(note.time)),
			run_modifier_params
		)
		if display_lane < 0:
			note.display_lane = -1
			continue
		note.display_lane = display_lane
		var lane_w := get_lane_width_at(display_lane)
		var lane_x := get_lane_left_x(display_lane)
		if _RunModifiers.is_single_lane(run_modifiers) and _RunModifiers.single_lane_is_collapsed(
			run_modifiers, run_modifier_params
		):
			var pf_w := get_playfield_width()
			lane_w = _RunModifiers.single_lane_note_width(pf_w)
			lane_x = _RunModifiers.single_lane_note_x(pf_w)
		note.visual_node.position.x = lane_x
		note.visual_node.size.x = lane_w
		if note_manager:
			note_manager.sync_note_color_for_display_lane(
				note, display_lane, get_hit_zone_y_for_playfield(NoteManager.PLAYFIELD_MAIN)
			)

func get_hit_zone_y_for_playfield(target: int) -> int:
	if target == NoteManager.PLAYFIELD_COMPARE and chart_compare:
		return chart_compare.hit_zone_y
	return hit_zone_y


func _layout_lanes_for_playfield(target: int) -> int:
	if target == NoteManager.PLAYFIELD_COMPARE:
		return lanes
	return _layout_lane_count()


func get_playfield_width_for_target(target: int) -> float:
	if target == NoteManager.PLAYFIELD_COMPARE and chart_compare:
		return chart_compare.get_playfield_width()
	var pf := get_node_or_null("Playfield") as Control
	if pf == null:
		return get_playfield_width()
	var hz := get_node_or_null("Playfield/HitZone") as Control
	var w: float = pf.size.x
	if hz:
		w = maxf(w, hz.size.x)
	return w if w > 1.0 else 600.0


func get_lane_left_x_for_playfield(target: int, lane: int) -> float:
	var w: float = get_playfield_width_for_target(target)
	var layout_lanes := _layout_lanes_for_playfield(target)
	var lane_clamped: int = clampi(lane, 0, maxi(layout_lanes, 1) - 1)
	var edges := _lane_left_edges_px(w, layout_lanes)
	return edges[lane_clamped]


func get_lane_width_at_for_playfield(target: int, lane: int) -> float:
	var w: float = get_playfield_width_for_target(target)
	var layout_lanes := _layout_lanes_for_playfield(target)
	var lane_clamped: int = clampi(lane, 0, maxi(layout_lanes, 1) - 1)
	var edges := _lane_left_edges_px(w, layout_lanes)
	return edges[lane_clamped + 1] - edges[lane_clamped]


func get_playfield_height_for_target(target: int) -> float:
	if target == NoteManager.PLAYFIELD_COMPARE and chart_compare:
		return chart_compare.get_playfield_height()
	var pf := get_node_or_null("Playfield") as Control
	if pf:
		return maxf(pf.size.y, 1.0)
	return maxf(float(get_viewport_rect().size.y), 400.0)


func get_note_despawn_y_for_target(target: int) -> float:
	var h := get_playfield_height_for_target(target)
	if modifier_runtime:
		return modifier_runtime.note_despawn_y(h)
	return h + 80.0


func _capture_ui_y_layout_snapshots() -> void:
	if modifier_runtime:
		modifier_runtime.capture_ui_layout_snapshots()


func _refresh_run_hud_layout() -> void:
	if modifier_runtime and modifier_runtime.ui_y_layout_snapshots.is_empty():
		modifier_runtime.capture_ui_layout_snapshots()
	_apply_playfield_width_for_lanes()
	_update_lane_layout()
	_sync_health_bar_visibility()
	if error_meter:
		error_meter.visible = _error_meter_should_show()
	if modifier_runtime:
		modifier_runtime.apply_spotlight_overlay()


func get_playfield_width() -> float:
	return get_playfield_width_for_target(NoteManager.PLAYFIELD_MAIN)


func _layout_lane_count() -> int:
	return _RunModifiers.layout_lane_count(run_modifiers, lanes, run_modifier_params)


func get_lane_width() -> float:
	return get_playfield_width() / float(maxi(_layout_lane_count(), 1))


func get_lane_left_x(lane: int) -> float:
	var w: float = get_playfield_width()
	var layout_lanes := _layout_lane_count()
	var lane_clamped: int = clampi(lane, 0, maxi(layout_lanes, 1) - 1)
	var edges := _lane_left_edges_px(w, layout_lanes)
	return edges[lane_clamped]


func get_lane_width_at(lane: int) -> float:
	var w: float = get_playfield_width()
	var layout_lanes := _layout_lane_count()
	var lane_clamped: int = clampi(lane, 0, maxi(layout_lanes, 1) - 1)
	var edges := _lane_left_edges_px(w, layout_lanes)
	return edges[lane_clamped + 1] - edges[lane_clamped]

func get_playfield_start_x() -> float:
	return 0.0


func get_playfield_height_for_notes() -> float:
	var playfield = get_node_or_null("Playfield") as Control
	if playfield:
		return maxf(playfield.size.y, 1.0)
	return maxf(float(get_viewport_rect().size.y), 400.0)


func get_note_despawn_y() -> float:
	return get_note_despawn_y_for_target(NoteManager.PLAYFIELD_MAIN)


func _set_generation_mode(mode: String): 
	current_generation_mode = mode
	print("GameScreen.gd: Режим генерации установлен: ", mode)


func _set_run_modifiers(modifiers: Array) -> void:
	run_modifiers_player = _RunModifiers.sanitize_for_lanes(_RunModifiers.sanitize(modifiers), lanes)
	run_modifiers = run_modifiers_player.duplicate()
	run_modifier_params = _RunModifiers.sync_params_from_modifiers(
		run_modifiers_player,
		SettingsManager.get_run_modifier_params()
	)
	if modifier_runtime:
		modifier_runtime.reset_combo_escalation_state()
	_apply_run_modifier_runtime()


func _apply_run_modifier_runtime() -> void:
	if modifier_runtime:
		modifier_runtime.apply_runtime()
	if not is_node_ready():
		call_deferred("_sync_run_modifier_ui")
		return
	_sync_run_modifier_ui()


func _sync_run_modifier_ui() -> void:
	_reload_control_bindings()
	_load_note_colors()
	_update_lane_layout()
	_sync_run_modifier_icon_row()


func _sync_run_modifier_icon_row() -> void:
	if _run_mod_icon_flow == null:
		return
	var mods := _RunModifiers.sanitize(run_modifiers)
	_ModifierIconStrip.fill_hud_flow(_run_mod_icon_flow, mods)


func _apply_game_pitch_scale() -> void:
	if modifier_runtime:
		modifier_runtime.apply_game_pitch_scale()


func debug_apply_run_modifiers(modifiers: Array) -> void:
	_set_run_modifiers(modifiers)
	_configure_error_meter_for_run()


func _apply_score_reward_multiplier() -> void:
	if score_manager:
		score_manager.set_score_reward_multiplier(_score_reward_multiplier)


func _effective_scroll_speed() -> float:
	return modifier_runtime.effective_scroll_speed() if modifier_runtime else SettingsManager.get_scroll_speed()


func _hit_window_perfect() -> float:
	return modifier_runtime.hit_window_perfect() if modifier_runtime else HIT_WINDOW_PERFECT


func _hit_window_good() -> float:
	return modifier_runtime.hit_window_good() if modifier_runtime else HIT_WINDOW_GOOD


func _modifier_no_miss_forgiveness() -> bool:
	return _RunModifiers.has_modifier(run_modifiers, _RunModifiers.ID_NO_MISS_FORGIVENESS)


func _modifier_no_fail() -> bool:
	return _RunModifiers.has_modifier(run_modifiers, _RunModifiers.ID_NO_FAIL)


func _modifier_last_chance() -> bool:
	return _RunModifiers.has_modifier(run_modifiers, _RunModifiers.ID_LAST_CHANCE)


func _last_chance_at_zero() -> bool:
	return _modifier_last_chance() and modifier_runtime != null and modifier_runtime.last_chance_active


func _sync_health_bar_visibility() -> void:
	var show_setting := SettingsManager.get_show_health_bar()
	var visible_in_run := _hud_shell_visible()
	var hud := get_node_or_null("UIContainer/HealthHud")
	if hud:
		hud.visible = show_setting and visible_in_run
	else:
		var bar := _ensure_health_bar()
		if bar:
			bar.visible = show_setting and visible_in_run


func _ensure_health_bar() -> Node:
	if health_bar != null:
		return health_bar
	var ui_container_node = get_node_or_null("UIContainer")
	if ui_container_node:
		health_bar = ui_container_node.get_node_or_null("HealthHud/HealthBar")
	return health_bar


func _apply_health_bar(instant: bool = false, tween_duration: float = 0.14) -> void:
	var bar := _ensure_health_bar()
	if bar == null or not bar.has_method("set_ratio"):
		return
	var frozen := _last_chance_at_zero()
	if bar.has_method("set_last_chance_frozen"):
		bar.set_last_chance_frozen(false)
	bar.set_ratio(run_health_ratio, instant, tween_duration)
	if bar.has_method("set_last_chance_frozen"):
		bar.set_last_chance_frozen(frozen)
	if bar.has_method("set_nf_at_zero"):
		bar.set_nf_at_zero((_modifier_no_fail() or _last_chance_at_zero()) and run_health_ratio <= 0.0)


func _prepare_health_intro() -> void:
	var bar := _ensure_health_bar()
	if bar and bar.has_method("set_ratio"):
		bar.set_ratio(0.0, true)


func _reset_run_health(animate: bool = true) -> void:
	run_health_ratio = _RunModifiers.start_health_ratio(run_modifiers, run_modifier_params)
	var intro_duration: float = 0.55 if animate else 0.14
	_apply_health_bar(not animate, intro_duration if animate else 0.14)
	_sync_health_bar_visibility()


func _apply_inter_track_health_recovery(recovery_pct: int, animate: bool = true) -> void:
	var max_ratio := _RunModifiers.start_health_ratio(run_modifiers, run_modifier_params)
	var pct := _EndlessSessionConfig.normalize_inter_track_hp_recovery_pct(recovery_pct)
	if pct >= 100:
		run_health_ratio = max_ratio
	elif pct <= 0:
		run_health_ratio = clampf(run_health_ratio, 0.0, max_ratio)
	else:
		run_health_ratio = minf(max_ratio, run_health_ratio + float(pct) / 100.0)
	var intro_duration: float = 0.55 if animate else 0.14
	_apply_health_bar(not animate, intro_duration if animate else 0.14)
	_sync_health_bar_visibility()


func _on_run_health_hit(hit_kind: String) -> void:
	if _last_chance_at_zero():
		return
	run_health_ratio = RunHealth.apply_hit(run_health_ratio, hit_kind)
	_apply_health_bar()


func _on_run_health_miss() -> void:
	if _modifier_last_chance() and modifier_runtime and modifier_runtime.last_chance_active:
		call_deferred("end_game_defeat")
		return
	if _modifier_sudden_death():
		_try_sudden_death_end()
		return
	run_health_ratio = RunHealth.apply_miss(run_health_ratio)
	_apply_health_bar()
	if run_health_ratio <= 0.0:
		if _modifier_no_fail():
			return
		if _modifier_last_chance() and modifier_runtime and not modifier_runtime.last_chance_active:
			modifier_runtime.last_chance_active = true
			_apply_health_bar()
			var from_time := _resume_rewind_anchor_time()
			var vol := MusicManager.get_volume_multiplier() if MusicManager else 1.0
			call_deferred("begin_resume_rewind", from_time, vol, "last_chance")
			return
		call_deferred("end_game_defeat")


func _modifier_sudden_death() -> bool:
	return _RunModifiers.has_modifier(run_modifiers, _RunModifiers.ID_SUDDEN_DEATH)


func _error_meter_miss_offset_ms() -> float:
	if error_meter:
		return error_meter.max_display_ms
	return _hit_window_good() * 1000.0 * 1.05


func register_miss(show_judgement: bool = true, at_song_time: float = -1.0, partner_miss: bool = false, miss_chart_lane: int = -1, miss_chart_time: float = -1.0) -> void:
	if partner_miss:
		return
	if pauser.is_paused or _rewind_active or game_finished or countdown_active or not notes_loaded:
		return
	if score_manager:
		score_manager.add_miss_hit()
	# Авто-промах (нота ушла за линию) относим к её отображаемой линии для Lane Stats.
	if miss_chart_lane >= 0:
		var ctx_time := miss_chart_time if miss_chart_time >= 0.0 else get_song_time()
		var disp_lane := _RunModifiers.display_lane_for_chart_lane(
			miss_chart_lane, lanes, get_chart_lanes(), run_modifiers, lane_remap_context(ctx_time),
			run_modifier_params
		)
		_lane_stats_record(disp_lane, false)
	var sample_time := at_song_time if at_song_time >= 0.0 else get_song_time()
	_record_accuracy_sample(sample_time)
	_push_error_meter(HIT_KIND_MISS, _error_meter_miss_offset_ms())
	if show_judgement:
		_show_judgement(_judgement_text(HIT_KIND_MISS), judgement_color_miss)
	_combo_shake_and_dim()
	MusicManager.play_miss_hit_sound()
	if modifier_runtime:
		modifier_runtime.notify_groove_addiction_miss()
	_on_run_health_miss()


func _try_sudden_death_end() -> void:
	if not _modifier_sudden_death():
		return
	if _RunModifiers.blocks_sudden_death(run_modifiers):
		return
	if game_finished or countdown_active or not gameplay_started:
		return
	call_deferred("restart_level")


func _prepare_run_assets() -> bool:
	if _run_assets_prepared and notes_loaded:
		return true

	_apply_score_reward_multiplier()

	var song_to_load = selected_song_data
	if not song_to_load or not song_to_load.get("path"):
		song_to_load = {"path": "res://songs/sample.mp3"}

	if modifier_runtime:
		modifier_runtime.reset_dynamic_lanes_state()
	if _RunModifiers.is_single_lane(run_modifiers):
		_chart_lanes = _DynamicLanesSchedule.resolve_chart_lanes(
			String(song_to_load.get("path", "")),
			current_instrument,
			current_generation_mode,
			lanes
		)
	elif _RunModifiers.is_dynamic_lanes(run_modifiers):
		_setup_dynamic_lanes_for_run(song_to_load)
	else:
		_chart_lanes = _DynamicLanesSchedule.resolve_chart_lanes(
			String(song_to_load.get("path", "")),
			current_instrument,
			current_generation_mode,
			lanes
		)

	if modifier_runtime and _RunModifiers.is_random_mode(run_modifiers):
		modifier_runtime.prepare_random_lanes_for_run(song_to_load)
	if modifier_runtime and _RunModifiers.is_energy_pulse(run_modifiers):
		modifier_runtime.prepare_energy_pulse_for_run(song_to_load)
	if modifier_runtime and _RunModifiers.is_energy_balance(run_modifiers):
		modifier_runtime.prepare_energy_balance_for_run(song_to_load)
	note_manager.load_notes_from_file(song_to_load, current_generation_mode, _chart_lanes, current_chart_tag)
	note_manager.prune_non_play_lanes(run_modifiers, lanes, _chart_lanes)
	if modifier_runtime and _RunModifiers.is_rush(run_modifiers):
		modifier_runtime.prepare_rush_for_run(song_to_load)
	if modifier_runtime and _RunModifiers.is_density_focus(run_modifiers):
		modifier_runtime.prepare_density_focus_for_run(song_to_load)
	if modifier_runtime and _RunModifiers.is_groove_addiction(run_modifiers):
		modifier_runtime.prepare_groove_addiction_for_run(song_to_load)
	if modifier_runtime and _RunModifiers.has_dna_virtual_behavior(run_modifiers):
		modifier_runtime.prepare_dna_virtual_for_run(song_to_load)
	_setup_chart_compare_charts(song_to_load)
	_refresh_run_hud_layout()

	if song_to_load and song_to_load.has("bpm"):
		var bpm_str = str(song_to_load.get("bpm", ""))
		if bpm_str != "" and bpm_str != "-1" and bpm_str != "Н/Д" and bpm_str != "N/A":
			var new_bpm = float(bpm_str)
			if new_bpm > 0:
				bpm = new_bpm

	if note_manager.get_spawn_queue_size() > 0:
		notes_loaded = true
		_run_assets_prepared = true
		score_manager.set_total_notes(note_manager.get_spawn_queue_size())
		return true

	notes_loaded = false
	_run_assets_prepared = false
	return false


func start_gameplay():
	if gameplay_started:
		return

	if not _run_assets_prepared and not _prepare_run_assets():
		return

	gameplay_started = true
	speed = _effective_scroll_speed()
	_sync_health_bar_visibility()
	_clear_accuracy_samples()
	_lane_stats_reset()
	_new_record_setup()
	_configure_error_meter_for_run()
	_timing_debug_session_start_unix = int(Time.get_unix_time_from_system())
	_lane_layout_relayout_key = ""
	_timing_debug_clear_ring()
	_reset_autoplay_state()

	var song_to_load = selected_song_data
	if not song_to_load or not song_to_load.get("path"):
		song_to_load = {"path": "res://songs/sample.mp3"}

	if modifier_runtime:
		modifier_runtime.on_run_start_memory_patterns()
		modifier_runtime.bootstrap_combo_escalation()

	var should_delay_music = false
	var earliest_note_time = note_manager.get_earliest_note_time()
	var pre_delay := 0.0
	if earliest_note_time > 0:
		var pixels_per_sec = speed * (1.0 / GAME_UPDATE_DELTA)
		var playfield_h := get_playfield_height_for_target(NoteManager.PLAYFIELD_MAIN)
		var distance_to_travel = note_spawn_travel_distance(playfield_h, float(hit_zone_y))
		var time_to_reach_hit_zone = distance_to_travel / pixels_per_sec
		if earliest_note_time <= time_to_reach_hit_zone:
			should_delay_music = true
			pre_delay = time_to_reach_hit_zone - earliest_note_time

	pending_game_music_path = ""
	if should_delay_music and pre_delay > 1e-4:
		game_time = -pre_delay
		pending_game_music_path = selected_song_data.get("path", "")
	elif should_delay_music:
		game_time = 0.0
	else:
		game_time = 0.0

	MusicManager.play_level_start_sound()

	var song_path = selected_song_data.get("path", "")
	if pending_game_music_path != "":
		pass
	elif song_path != "":
		MusicManager.play_game_music(song_path)
		_apply_game_pitch_scale()
		if modifier_runtime:
			modifier_runtime.apply_audio_modifiers()

	check_song_end_timer.start()
	_update_hint()
	_timing_debug_log_session_start(String(song_to_load.get("path", "")))

func _chart_time_advance_delta() -> float:
	var advance := GAME_UPDATE_DELTA
	if not gameplay_started or modifier_runtime == null:
		return advance
	if modifier_runtime.uses_manual_chart_clock():
		advance *= modifier_runtime.chart_playback_rate_at(game_time)
	return advance


func _rewind_visual_tick() -> void:
	update_ui()
	if note_manager:
		note_manager.update_notes()
	if chart_compare and chart_compare.split_active_runtime and chart_compare.note_manager:
		chart_compare.note_manager.update_notes()


func _capture_resume_rewind_snapshot(delta: float) -> void:
	if not gameplay_started or game_finished or pauser.is_paused or countdown_active:
		return
	if score_manager == null:
		return
	_rewind_snapshot_accum += delta
	if _rewind_snapshot_accum < RESUME_REWIND_SNAPSHOT_INTERVAL:
		return
	_rewind_snapshot_accum = 0.0
	var snap := {
		"t": game_time,
		"score": score_manager.capture_rewind_snapshot(),
		"hp": run_health_ratio,
		"perfect": perfect_hits_this_level,
	}
	_rewind_state_ring.append(snap)
	var cutoff := game_time - RESUME_REWIND_SNAPSHOT_KEEP
	while not _rewind_state_ring.is_empty() and float(_rewind_state_ring[0].get("t", 0.0)) < cutoff:
		_rewind_state_ring.pop_front()


func _clear_resume_rewind_snapshots() -> void:
	_rewind_state_ring.clear()
	_rewind_snapshot_accum = 0.0


func _find_resume_rewind_snapshot(target_time: float) -> Dictionary:
	if _rewind_state_ring.is_empty():
		return {}
	var best: Dictionary = {}
	var best_dist := INF
	for raw in _rewind_state_ring:
		if raw is not Dictionary:
			continue
		var snap := raw as Dictionary
		var t := float(snap.get("t", 0.0))
		if t > target_time + 0.02:
			continue
		var dist := absf(target_time - t)
		if dist < best_dist:
			best_dist = dist
			best = snap
	if best.is_empty():
		var first: Variant = _rewind_state_ring[0]
		if first is Dictionary:
			best = first
	return best


func _restore_resume_rewind_snapshot(target_time: float) -> void:
	var snap := _find_resume_rewind_snapshot(target_time)
	if snap.is_empty():
		return
	if score_manager and snap.get("score") is Dictionary:
		score_manager.restore_rewind_snapshot(snap.get("score"))
	run_health_ratio = clampf(float(snap.get("hp", run_health_ratio)), 0.0, 1.0)
	perfect_hits_this_level = maxi(0, int(snap.get("perfect", perfect_hits_this_level)))
	_apply_health_bar(true)


func _update_game():
	if game_finished or countdown_active:
		return
	if pauser.is_paused:
		return
	if _rewind_active:
		_rewind_visual_tick()
		return

	_capture_resume_rewind_snapshot(GAME_UPDATE_DELTA)

	game_time += _chart_time_advance_delta()

	if pending_game_music_path != "" and game_time >= 0.0:
		var p := pending_game_music_path
		pending_game_music_path = ""
		MusicManager.play_game_music(p)
		_apply_game_pitch_scale()
		if modifier_runtime:
			modifier_runtime.apply_audio_modifiers()

	_sync_game_time_with_game_music()
	speed = _effective_scroll_speed()
	if gameplay_started and not game_finished:
		_apply_game_pitch_scale()

	_maybe_flash_new_record()

	if modifier_runtime:
		modifier_runtime.poll_dynamic_lane_schedule()
		modifier_runtime.poll_random_lane_remap()
		modifier_runtime.update_metronome_tick(GAME_UPDATE_DELTA)
		modifier_runtime.poll_combo_escalation()
		modifier_runtime.poll_heat_scroll()
		modifier_runtime.poll_groove_addiction()
		modifier_runtime.poll_dna_virtual_layout()
		modifier_runtime.apply_spotlight_overlay()

	if not countdown_active: 
		note_manager.spawn_notes()
		if chart_compare and chart_compare.split_active_runtime and chart_compare.note_manager:
			chart_compare.note_manager.spawn_notes()
		_update_hint()
	
	update_ui()
	if audio_background:
		audio_background.update(GAME_UPDATE_DELTA)
	
	if rhythm_notifier:
		rhythm_notifier.bpm = bpm
		if rhythm_notifier.audio_stream_player == null:
			rhythm_notifier.current_position = MusicManager.get_current_music_position()

	# Автоплей симулируем ДО update_notes: там ноты помечаются промахами по
	# позиции, а на высокой скорости нота проскакивает зону за один кадр. Если
	# автоплей отработает первым, он успеет «нажать» ноту (was_hit) до проверки
	# промаха, и update_notes её просто пропустит.
	if auto_play_enabled:
		_auto_play_simulate()

	_process_hold_sustain()

	note_manager.update_notes()
	if chart_compare and chart_compare.split_active_runtime and chart_compare.note_manager:
		chart_compare.note_manager.update_notes()
	_tally_new_bass_perfect_holds()

	_timing_debug_update_overlay()
	
	if debug_menu and debug_menu.visible and debug_menu.has_method("update_debug_info"):
		debug_menu.update_debug_info(self)

func _check_song_end():
	if pauser.is_paused or game_finished or _rewind_active:
		return

	var spawn_queue_empty = note_manager.get_spawn_queue_size() == 0
	var active_notes_empty = note_manager.get_notes().size() == 0

	if spawn_queue_empty and active_notes_empty:
		notes_ended = true 
		_update_hint()
		if victory_delay_timer.is_stopped():
			victory_delay_timer.one_shot = true
			var wait_total: float = VICTORY_DELAY_AFTER_NOTES
			var duration_seconds := 0.0
			if selected_song_data and selected_song_data.has("duration"):
				duration_seconds = _parse_duration_string(selected_song_data.get("duration", "0:00"))
			if duration_seconds > 0.0:
				var remaining_to_100: float = max(0.0, duration_seconds - clamp(game_time, 0.0, duration_seconds))
				wait_total += remaining_to_100
			victory_delay_timer.wait_time = wait_total
			victory_delay_timer.start()

	if selected_song_data and selected_song_data.has("duration"):
		var duration_value = selected_song_data.get("duration", 0)
		var duration_seconds: float = 0.0
		if typeof(duration_value) == TYPE_FLOAT:
			duration_seconds = float(duration_value)
		elif typeof(duration_value) == TYPE_STRING:
			duration_seconds = _parse_duration_string(String(duration_value))
		if duration_seconds > 0.0:
			if game_time >= duration_seconds - 0.1:
				var sqe = note_manager.get_spawn_queue_size() == 0
				var ane = note_manager.get_notes().size() == 0
				if sqe and ane:
					notes_ended = true
					_update_hint()
					if victory_delay_timer.is_stopped():
						victory_delay_timer.one_shot = true
						victory_delay_timer.wait_time = VICTORY_DELAY_AFTER_NOTES
						victory_delay_timer.start()
					return

func _on_victory_delay_timeout():
	if pauser.is_paused:
		return
	end_game() 

func _reset_modifier_audio() -> void:
	if modifier_runtime:
		modifier_runtime.cleanup_modifier_overlays()
	MusicManager.set_external_metronome_control(false)
	if MusicManager.has_method("set_game_music_muted"):
		MusicManager.set_game_music_muted(false)


func end_game():
	if game_finished:
		return
	if _is_series_mode():
		_end_game_series_track_cleared()
		return
	Engine.max_fps = original_max_fps
	DisplayServer.window_set_vsync_mode(original_vsync_mode)
	
	if pauser.is_paused:
		pauser.cleanup_on_game_end()
		return

	if notes_ended:
		notes_ended = false
	if not victory_delay_timer.is_stopped():
		victory_delay_timer.stop()

	game_finished = true
	
	if not game_timer.is_stopped():
		game_timer.stop()
	if not check_song_end_timer.is_stopped():
		check_song_end_timer.stop()
	
	_reset_modifier_audio()
	MusicManager.stop_game_music()
	
	if debug_menu:
		debug_menu.auto_play_reset(self)
	auto_play_enabled = false
	var bass_holds_this_run := _pending_bass_perfect_holds
	var bass_early_releases := _run_bass_hold_early_releases
	var skip_instrument_achs := _RunModifiers.has_modifier(run_modifiers_player, _RunModifiers.ID_AUTOPLAY)
	_flush_pending_run_progress()
	
	var song_path = selected_song_data.get("path", "")
	TrackStatsManager.on_track_completed(song_path)
	
	PlayerDataManager.add_completed_level()
	if current_instrument == "drums":
		PlayerDataManager.add_drum_level_completed()
		if not skip_instrument_achs:
			var mode_stem := str(current_generation_mode)
			var pair := _GoalDiff.pair_from_stem(mode_stem)
			if str(pair.get("difficulty", "")) == "dense" or mode_stem.ends_with("_dense"):
				PlayerDataManager.add_drum_dense_clear()
	elif current_instrument == "bass":
		PlayerDataManager.add_bass_level_completed()
		if not skip_instrument_achs and bass_early_releases <= 0 and bass_holds_this_run > 0:
			PlayerDataManager.add_bass_clean_hold_clear()
	PlayerDataManager.increment_daily_progress("levels_completed", 1, {})
	PlayerDataManager.increment_daily_progress("play_drum_level", 1, {"is_drum_mode": current_instrument == "drums"})
	PlayerDataManager.increment_daily_progress("play_bass_level", 1, {"is_bass_mode": current_instrument == "bass"})
	
	var victory_song_info = selected_song_data.duplicate()
	victory_song_info["instrument"] = current_instrument 
	victory_song_info["mode"] = current_generation_mode
	victory_song_info["lanes"] = lanes
	victory_song_info["modifiers"] = run_modifiers_player.duplicate()
	victory_song_info["modifier_params"] = run_modifier_params.duplicate()
	victory_song_info["accuracy_timeline"] = _accuracy_samples.duplicate(true)
	victory_song_info["accuracy_timeline_duration"] = _get_song_duration_seconds()
	victory_song_info["lane_stats"] = _build_lane_stats()
	_apply_score_reward_multiplier()
	var debug_score: int = score_manager.get_score()
	if debug_score <= 0 and score_manager.get_raw_score() > 0:
		debug_score = maxi(
			0,
			int(round(float(score_manager.get_raw_score()) * _score_reward_multiplier))
		)
	if current_instrument == "drums" and not skip_instrument_achs:
		PlayerDataManager.note_max_drum_score_single_run(debug_score)
	var debug_combo = score_manager.get_combo()
	var debug_max_combo = score_manager.get_max_combo()
	var debug_accuracy = score_manager.get_accuracy()
	var debug_perfect_hits = perfect_hits_this_level
	var debug_missed_notes = score_manager.get_missed_notes_count()
	var debug_hit_notes = score_manager.get_hit_notes_count()
	if debug_accuracy >= 80.0:
		PlayerDataManager.increment_daily_progress("accuracy_80", 1, {"accuracy": debug_accuracy})
	if debug_accuracy >= 90.0:
		PlayerDataManager.increment_daily_progress("accuracy_90", 1, {"accuracy": debug_accuracy})
	if debug_accuracy >= 95.0:
		PlayerDataManager.increment_daily_progress("accuracy_95", 1, {"accuracy": debug_accuracy})
	if debug_max_combo >= 30:
		PlayerDataManager.increment_daily_progress("combo_reached", 1, {"max_combo": debug_max_combo})
	if debug_max_combo >= 60:
		PlayerDataManager.increment_daily_progress("combo_reached_60", 1, {"max_combo": debug_max_combo})
	if debug_max_combo >= 100:
		PlayerDataManager.increment_daily_progress("combo_reached_100", 1, {"max_combo": debug_max_combo})
	if debug_missed_notes <= 0:
		PlayerDataManager.increment_daily_progress("missless", 1, {"missed_notes": debug_missed_notes})

	if not _RunModifiers.has_modifier(run_modifiers_player, _RunModifiers.ID_AUTOPLAY):
		PlayerDataManager.record_modifier_victory(run_modifiers_player)
		SettingsManager.record_run_modifier_preset_clear(
			run_modifiers_player,
			SettingsManager.get_run_modifier_params(),
		)

	var transitions = null
	if game_engine and game_engine.has_method("get_transitions"):
		transitions = game_engine.get_transitions()

	transitions.open_victory_screen(
		debug_score,      
		debug_combo,    
		debug_max_combo,  
		debug_accuracy,  
		victory_song_info,
		results_manager, 
		debug_missed_notes, 
		debug_perfect_hits, 
		debug_hit_notes    
	)

	var parent_node = get_parent()
	if parent_node:
		parent_node.remove_child(self)
		call_deferred("queue_free")


func _flush_pending_run_progress() -> void:
	var hit_notes := _pending_daily_hit_notes
	var drum_perfects := _pending_drum_perfect_hits
	var bass_perfects := _pending_bass_perfect_hits
	var bass_ghosts := _pending_bass_ghost_hits
	var bass_multilane := _pending_bass_multilane_hits
	var bass_holds := _pending_bass_perfect_holds
	_pending_daily_hit_notes = 0
	_pending_drum_perfect_hits = 0
	_pending_bass_perfect_hits = 0
	_pending_bass_ghost_hits = 0
	_pending_bass_multilane_hits = 0
	_pending_bass_perfect_holds = 0
	if hit_notes > 0:
		PlayerDataManager.increment_daily_progress("hit_notes", hit_notes, {})
	if drum_perfects > 0:
		PlayerDataManager.add_total_drum_perfect_hits(drum_perfects)
	if bass_perfects > 0:
		PlayerDataManager.add_total_bass_perfect_hits(bass_perfects)
	if bass_ghosts > 0:
		PlayerDataManager.add_bass_ghost_hits(bass_ghosts)
	if bass_multilane > 0:
		PlayerDataManager.add_bass_multilane_hits(bass_multilane)
	if bass_holds > 0:
		PlayerDataManager.add_bass_perfect_holds(bass_holds)


func end_game_defeat() -> void:
	if game_finished:
		return
	if _is_series_mode():
		_end_game_series_defeat()
		return

	Engine.max_fps = original_max_fps
	DisplayServer.window_set_vsync_mode(original_vsync_mode)

	if pauser.is_paused:
		pauser.cleanup_on_game_end()

	if notes_ended:
		notes_ended = false
	if not victory_delay_timer.is_stopped():
		victory_delay_timer.stop()

	game_finished = true

	if not game_timer.is_stopped():
		game_timer.stop()
	if not check_song_end_timer.is_stopped():
		check_song_end_timer.stop()

	_reset_modifier_audio()
	MusicManager.stop_game_music()

	if debug_menu:
		debug_menu.auto_play_reset(self)
	auto_play_enabled = false
	input_enabled = false
	_reset_autoplay_state()
	_flush_pending_run_progress()

	var defeat_song_info := selected_song_data.duplicate()
	defeat_song_info["instrument"] = current_instrument
	defeat_song_info["mode"] = current_generation_mode
	defeat_song_info["lanes"] = lanes
	defeat_song_info["modifiers"] = run_modifiers_player.duplicate()

	_show_defeat_overlay(
		score_manager.get_score(),
		score_manager.get_combo(),
		score_manager.get_max_combo(),
		score_manager.get_accuracy(),
		defeat_song_info
	)


func _show_defeat_overlay(
	p_score: int,
	p_combo: int,
	p_max_combo: int,
	p_accuracy: float,
	p_song_info: Dictionary
) -> void:
	_close_defeat_overlay()
	var overlay := DefeatScreenScene.instantiate() as Control
	if overlay == null:
		return
	defeat_overlay = overlay
	if overlay.has_method("set_results_manager"):
		overlay.set_results_manager(results_manager)
	if overlay.has_method("set_defeat_data"):
		overlay.set_defeat_data(p_score, p_combo, p_max_combo, p_accuracy, p_song_info)
	if overlay.has_signal("replay_requested"):
		overlay.replay_requested.connect(_on_defeat_replay_requested)
	if overlay.has_signal("song_select_requested"):
		overlay.song_select_requested.connect(_on_defeat_song_select_requested)
	overlay.z_index = 200
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	MusicManager.play_defeat_sound()


func _close_defeat_overlay() -> void:
	if MusicManager and MusicManager.has_method("stop_screen_ambient_music"):
		MusicManager.stop_screen_ambient_music()
	if defeat_overlay and is_instance_valid(defeat_overlay):
		defeat_overlay.queue_free()
	defeat_overlay = null


func _on_defeat_replay_requested() -> void:
	_close_defeat_overlay()
	game_finished = false
	restart_level()


func _on_defeat_song_select_requested() -> void:
	_close_defeat_overlay()
	_exit_to_song_select()

func update_ui():
	if score_label:
		var target_score = _series_hud_score() if _is_series_mode() else score_manager.get_score()
		if int(score_display_value) != target_score:
			var ap := score_animation_player if score_animation_player != null else animation_player
			if ap and ap.has_animation("ScoreCount"):
				if ap.is_playing() and ap.current_animation == "ScoreCount":
					score_count_target = float(target_score)
				else:
					score_count_start = score_display_value
					score_count_target = float(target_score)
					score_count_progress = 0.0
					ap.play("ScoreCount")
			else:
				score_display_value = float(target_score)
	if combo_label:
		var new_combo = score_manager.get_combo()
		combo_label.text = "%d (x%.1f)" % [new_combo, score_manager.get_combo_multiplier()]
		if new_combo > 0 and combo_label.modulate.a < 1.0:
			combo_label.modulate = _combo_default_modulate
		if new_combo > _last_combo_value:
			if new_combo % 100 == 0 and new_combo > 0:
				_combo_burst(1.3)
			elif new_combo % 50 == 0 and new_combo > 0:
				_combo_burst(1.25)
			else:
				_pulse_combo_label()
		_last_combo_value = new_combo
	if accuracy_label:
		var target_acc = _series_hud_accuracy() if _is_series_mode() else score_manager.get_accuracy()
		if absf(accuracy_display_value - target_acc) > 0.001:
			var ap2 := accuracy_animation_player if accuracy_animation_player != null else score_animation_player if score_animation_player != null else animation_player
			if ap2 and ap2.has_animation("AccuracyCount"):
				if ap2.is_playing() and ap2.current_animation == "AccuracyCount":
					accuracy_count_target = float(target_acc)
				else:
					accuracy_count_start = accuracy_display_value
					accuracy_count_target = float(target_acc)
					accuracy_count_progress = 0.0
					ap2.play("AccuracyCount")
			else:
				accuracy_display_value = float(target_acc)

	if error_meter:
		error_meter.visible = _error_meter_should_show()
	_sync_health_bar_visibility()
	
	if progress_bar and selected_song_data.has("duration"):
		var duration_str = selected_song_data.get("duration", "0:00")
		var duration_seconds = _parse_duration_string(duration_str)  
		if duration_seconds > 0:
			var current_progress = clamp(game_time / duration_seconds, 0.0, 1.0)
			progress_bar.value = current_progress * 100


func _parse_duration_string(time_str: String) -> float:
	var parts = time_str.split(":")
	if parts.size() == 2:
		var minutes = int(parts[0])
		var seconds = int(parts[1])
		return float(minutes * 60 + seconds)
	else:
		return 0.0


func _clear_accuracy_samples() -> void:
	_accuracy_samples.clear()


func _lane_stats_reset() -> void:
	var n := maxi(1, _layout_lane_count())
	_lane_hit_counts = PackedInt32Array()
	_lane_miss_counts = PackedInt32Array()
	_lane_hit_counts.resize(n)
	_lane_miss_counts.resize(n)


func _lane_stats_ensure_size(index: int) -> void:
	if index < 0:
		return
	if index >= _lane_hit_counts.size():
		_lane_hit_counts.resize(index + 1)
	if index >= _lane_miss_counts.size():
		_lane_miss_counts.resize(index + 1)


func _lane_stats_record(display_lane: int, is_hit: bool) -> void:
	if display_lane < 0:
		return
	_lane_stats_ensure_size(display_lane)
	if is_hit:
		_lane_hit_counts[display_lane] += 1
	else:
		_lane_miss_counts[display_lane] += 1


func _build_lane_stats() -> Array:
	var lane_count := maxi(1, _layout_lane_count())
	var out: Array = []
	var total_recorded := 0
	for i in lane_count:
		var hits := _lane_hit_counts[i] if i < _lane_hit_counts.size() else 0
		var misses := _lane_miss_counts[i] if i < _lane_miss_counts.size() else 0
		var total := hits + misses
		total_recorded += total
		var acc := 100.0
		if total > 0:
			acc = float(hits) / float(total) * 100.0
		out.append({
			"lane": i,
			"hits": hits,
			"misses": misses,
			"total": total,
			"acc": acc,
		})
	if total_recorded == 0 and score_manager:
		var total_hits: int = score_manager.get_hit_notes_count()
		var total_misses: int = score_manager.get_missed_notes_count()
		if total_hits + total_misses > 0:
			return _synthesize_lane_stats(lane_count, total_hits, total_misses)
	return out


func _synthesize_lane_stats(lane_count: int, total_hits: int, total_misses: int) -> Array:
	var rng := RandomNumberGenerator.new()
	var path_key := str(selected_song_data.get("path", ""))
	var acc_key := int(round(score_manager.get_accuracy() * 100.0)) if score_manager else 0
	rng.seed = hash(path_key) ^ acc_key ^ lane_count
	var hits_per_lane := PackedInt32Array()
	var misses_per_lane := PackedInt32Array()
	hits_per_lane.resize(lane_count)
	misses_per_lane.resize(lane_count)
	for _i in total_hits:
		hits_per_lane[rng.randi_range(0, lane_count - 1)] += 1
	for _j in total_misses:
		misses_per_lane[rng.randi_range(0, lane_count - 1)] += 1
	var out: Array = []
	for i in lane_count:
		var hits := hits_per_lane[i]
		var misses := misses_per_lane[i]
		var total := hits + misses
		var acc := 100.0
		if total > 0:
			acc = float(hits) / float(total) * 100.0
		out.append({
			"lane": i,
			"hits": hits,
			"misses": misses,
			"total": total,
			"acc": acc,
		})
	return out


func _new_record_setup() -> void:
	_new_record_triggered = false
	_prev_best_score = -1
	# На модификаторах, блокирующих сохранение результата, рекорд не отслеживаем.
	if _RunModifiers.blocks_track_result_save(run_modifiers):
		return
	var results_service := ResultsHistoryService.resolve_backend(results_manager)
	if results_service == null:
		return
	var song_path := str(selected_song_data.get("path", "")) if selected_song_data else ""
	if song_path.strip_edges() == "":
		return
	var best := 0
	for raw in results_service.load_results_for_song(song_path):
		if not raw is Dictionary:
			continue
		if not _new_record_result_matches_scope(raw):
			continue
		best = maxi(best, int(raw.get("score", 0)))
	_prev_best_score = best


func _new_record_norm_instrument(raw: String) -> String:
	var key := raw.strip_edges().to_lower()
	match key:
		"drums", "перкуссия":
			return "drums"
		"standard", "стандарт":
			return "standard"
		"fullmix", "микс":
			return "fullmix"
		_:
			return key


func _new_record_result_matches_scope(result: Dictionary) -> bool:
	var result_mode := str(result.get("mode", "")).strip_edges().to_lower()
	var run_mode := str(current_generation_mode).strip_edges().to_lower()
	if result_mode != "" and run_mode != "" and result_mode != run_mode:
		return false
	var result_lanes := int(result.get("lanes", 0))
	if result_lanes > 0 and lanes > 0 and result_lanes != lanes:
		return false
	var result_inst := _new_record_norm_instrument(str(result.get("instrument", "")))
	var run_inst := _new_record_norm_instrument(str(current_instrument))
	if result_inst != "" and run_inst != "" and result_inst != run_inst:
		return false
	return true


func _maybe_flash_new_record() -> void:
	if _new_record_triggered or _prev_best_score <= 0 or score_manager == null:
		return
	if score_manager.get_score() > _prev_best_score:
		_new_record_triggered = true
		_show_new_record_flash()


func _show_new_record_flash() -> void:
	var parent := get_node_or_null("UIContainer") as Node
	if parent == null:
		parent = self
	if _new_record_label == null or not is_instance_valid(_new_record_label):
		_new_record_label = Label.new()
		_new_record_label.name = "NewRecordFlash"
		_new_record_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_new_record_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_new_record_label.add_theme_font_size_override("font_size", 34)
		_new_record_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.42, 1.0))
		_new_record_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
		_new_record_label.add_theme_constant_override("outline_size", 6)
		_new_record_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_new_record_label.anchor_left = 0.0
		_new_record_label.anchor_right = 1.0
		_new_record_label.anchor_top = 0.0
		_new_record_label.anchor_bottom = 0.0
		_new_record_label.offset_left = 0.0
		_new_record_label.offset_right = 0.0
		_new_record_label.offset_top = 108.0
		_new_record_label.offset_bottom = 158.0
		parent.add_child(_new_record_label)
	_new_record_label.text = tr("HUD_NEW_RECORD")
	_new_record_label.visible = true
	_new_record_label.modulate = Color(1, 1, 1, 0)
	if MusicManager and MusicManager.has_method("play_grade_pop_sound"):
		MusicManager.play_grade_pop_sound()
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	tw.tween_property(_new_record_label, "modulate:a", 1.0, 0.2)
	for i in 3:
		tw.tween_property(_new_record_label, "modulate:a", 0.35, 0.26)
		tw.tween_property(_new_record_label, "modulate:a", 1.0, 0.26)
	tw.tween_interval(0.5)
	tw.tween_property(_new_record_label, "modulate:a", 0.0, 0.5)
	tw.tween_callback(_hide_new_record_flash)


func _hide_new_record_flash() -> void:
	if is_instance_valid(_new_record_label):
		_new_record_label.visible = false


func _record_accuracy_sample(song_time: float) -> void:
	if score_manager == null:
		return
	var t := maxf(0.0, float(song_time))
	var acc: float = score_manager.get_accuracy()
	if _accuracy_samples.is_empty():
		_accuracy_samples.append({"t": t, "acc": acc})
		return
	var n := _accuracy_samples.size()
	var last: Dictionary = _accuracy_samples[n - 1]
	var last_t := float(last.get("t", -1.0))
	var last_acc := float(last.get("acc", -1.0))
	if last_t == t and is_equal_approx(last_acc, acc):
		return
	# Схлопываем коллинеарные точки: если и предыдущая, и последняя точки имеют ту
	# же точность, что и новая (ровный участок графика), просто сдвигаем последнюю
	# точку вправо, а не добавляем новую вершину. Иначе на фулл-комбо в график
	# попадали тысячи одинаковых точек, чьи субпиксельные различия при отрисовке
	# давали «рваные» метки, хотя линия должна быть идеально ровной.
	if is_equal_approx(last_acc, acc) and n >= 2:
		var prev: Dictionary = _accuracy_samples[n - 2]
		if is_equal_approx(float(prev.get("acc", -1.0)), acc):
			_accuracy_samples[n - 1] = {"t": t, "acc": acc}
			return
	_accuracy_samples.append({"t": t, "acc": acc})


func get_song_duration_seconds() -> float:
	return _get_song_duration_seconds()


func _get_song_duration_seconds() -> float:
	var duration_seconds := 0.0
	if selected_song_data and selected_song_data.has("duration"):
		var duration_value: Variant = selected_song_data.get("duration", 0)
		if typeof(duration_value) == TYPE_FLOAT or typeof(duration_value) == TYPE_INT:
			duration_seconds = float(duration_value)
		elif typeof(duration_value) == TYPE_STRING:
			duration_seconds = _parse_duration_string(String(duration_value))
	if duration_seconds > 0.0:
		return duration_seconds
	if note_manager and note_manager.has_method("get_latest_chart_time"):
		var chart_end := float(note_manager.get_latest_chart_time())
		if chart_end > 0.0:
			return chart_end + 2.0
	if note_manager and note_manager.has_method("get_notes"):
		var max_note_t := 0.0
		for note in note_manager.get_notes():
			if note == null:
				continue
			max_note_t = maxf(max_note_t, float(note.time))
		if max_note_t > 0.0:
			return max_note_t + 2.0
	if _accuracy_samples.size() > 0:
		var last: Dictionary = _accuracy_samples[_accuracy_samples.size() - 1]
		return maxf(float(last.get("t", 0.0)), game_time)
	return maxf(game_time, 1.0)


func update_countdown_display():
	if countdown_label: 
		countdown_label.text = str(countdown_remaining)
		countdown_label.visible = true

func show_lane_change_notice(from_lanes: int, to_lanes: int) -> void:
	if from_lanes < 0:
		return
	show_center_game_notice(
		tr("GAME_NOTICE_DYNAMIC_LANES") % [from_lanes, to_lanes],
		Color(0.55, 0.88, 0.95, 1.0)
	)


func show_center_game_notice(
	text: String,
	accent: Color = Color(0.55, 0.88, 0.95, 1.0),
	hold_sec: float = 2.2
) -> void:
	if lane_change_label == null or not is_instance_valid(lane_change_label):
		return
	if _lane_change_tween and _lane_change_tween.is_valid():
		_lane_change_tween.kill()
	lane_change_label.text = text
	lane_change_label.add_theme_color_override("font_color", accent)
	lane_change_label.visible = true
	lane_change_label.modulate = Color(1, 1, 1, 0)
	lane_change_label.scale = Vector2(0.94, 0.94)
	lane_change_label.pivot_offset = lane_change_label.size * 0.5
	_lane_change_tween = create_tween()
	_lane_change_tween.set_parallel(true)
	_lane_change_tween.tween_property(lane_change_label, "modulate:a", 1.0, 0.16)
	_lane_change_tween.tween_property(lane_change_label, "scale", Vector2.ONE, 0.16)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_lane_change_tween.set_parallel(false)
	_lane_change_tween.tween_interval(maxf(hold_sec, 0.5))
	_lane_change_tween.tween_property(lane_change_label, "modulate:a", 0.0, 0.35)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_lane_change_tween.finished.connect(func() -> void:
		if is_instance_valid(lane_change_label):
			lane_change_label.visible = false
	, CONNECT_ONE_SHOT)


func show_lane_remap_notice(dna_section: bool = false) -> void:
	var key := "GAME_NOTICE_LANES_REMAPPED_DNA" if dna_section else "GAME_NOTICE_LANES_REMAPPED"
	show_center_game_notice(tr(key), Color(0.55, 0.88, 0.95, 1.0))


func show_combo_escalation_notice(modifier_id: String) -> void:
	var title := tr(_RunModifiers.title_i18n_key(modifier_id))
	var accent := _RunModifiers.category_tint(modifier_id, true)
	show_center_game_notice(tr("GAME_NOTICE_COMBO_ESCALATION") % title, accent, 2.8)


func show_modifier_speed_notice(modifier_id: String, speed_pct: int) -> void:
	var pct := clampi(speed_pct, 50, 400)
	var accent := _RunModifiers.category_tint(modifier_id, true)
	var text: String
	if pct < 100:
		text = tr("GAME_NOTICE_SPEED_SLOW") % (100 - pct)
	elif modifier_id == _RunModifiers.ID_HEAT:
		text = tr("GAME_NOTICE_SPEED_HEAT") % (pct - 100)
	elif modifier_id == _RunModifiers.ID_RUSH:
		text = tr("GAME_NOTICE_SPEED_RUSH") % (pct - 100)
	else:
		text = tr("GAME_NOTICE_SPEED_MOD") % [
			tr(_RunModifiers.title_i18n_key(modifier_id)),
			pct - 100,
		]
	show_center_game_notice(text, accent, 0.95)


func show_transient_hint(text: String, duration_sec: float = 2.8) -> void:
	_transient_hint_text = text
	_transient_hint_until_ms = Time.get_ticks_msec() + int(maxf(duration_sec, 0.5) * 1000.0)
	_update_hint()


func _update_hint():
	if hint_label == null:
		return
	var now_ms := Time.get_ticks_msec()
	if _transient_hint_until_ms > 0 and now_ms >= _transient_hint_until_ms:
		_transient_hint_text = ""
		_transient_hint_until_ms = 0
	if _transient_hint_text != "" and now_ms < _transient_hint_until_ms:
		hint_label.text = _transient_hint_text
		hint_label.visible = true
		return
	var text := ""
	if countdown_active:
		text = tr("GAME_HINT_SKIP_COUNTDOWN")
	elif _skip_intro_available():
		text = tr("GAME_HINT_SKIP_INTRO")
	elif notes_ended and not game_finished:
		if _is_series_mode():
			text = tr("GAME_HINT_SKIP_TO_NEXT_TRACK")
		else:
			text = tr("GAME_HINT_SKIP_TO_RESULTS")
	else:
		text = ""
	var compare_h := _chart_compare_hint_line()
	if compare_h != "":
		text = compare_h if text == "" else "%s\n%s" % [text, compare_h]
	hint_label.text = text
	hint_label.visible = (text != "")


func _get_mark_song_time() -> float:
	if pauser and pauser.is_paused:
		return maxf(0.0, pauser.paused_music_position)
	return maxf(0.0, get_song_time())


func _open_generation_quality_report() -> void:
	if gen_qa:
		gen_qa.open_report()


func _close_generation_quality_range_end() -> void:
	if gen_qa:
		gen_qa.close_range_end()


func _restore_gen_qa_music_position() -> void:
	if gen_qa:
		gen_qa.restore_music_position()


func _gen_qa_dialog_blocks_input() -> bool:
	return gen_qa.blocks_input() if gen_qa else false


func _is_before_first_note() -> bool:
	if not note_manager:
		return false
	if score_manager:
		if score_manager.get_hit_notes_count() > 0 or score_manager.get_missed_notes_count() > 0:
			return false
	if note_manager.get_notes().size() > 0:
		return false
	var spawn_queue = note_manager.get_spawn_queue()
	if not spawn_queue or spawn_queue.size() == 0:
		return false
	var first_note_time = spawn_queue[0].get("time", 0.0)
	return first_note_time > game_time

func _skip_intro_available() -> bool:
	if game_time < 0:
		return false
	if pauser.is_paused or game_finished or countdown_active:
		return false
	if skip_used:
		return false
	if note_manager and note_manager.get_notes().size() > 0:
		return false
	if score_manager:
		if score_manager.get_hit_notes_count() > 0:
			return false
		if score_manager.get_missed_notes_count() > 0:
			return false
	if game_time >= skip_time_threshold:
		return false
	var spawn_queue = note_manager.get_spawn_queue()
	if not spawn_queue or spawn_queue.size() == 0:
		return false
	var first_note_time = spawn_queue[0].get("time", 0.0)
	if first_note_time <= game_time:
		return false
	if first_note_time < skip_time_threshold:
		return false
	return true

func _defeat_blocks_gameplay_input() -> bool:
	return defeat_overlay != null and is_instance_valid(defeat_overlay)


func _pause_overlay_blocks_esc() -> bool:
	if _gen_qa_dialog_blocks_input():
		return true
	if _defeat_blocks_gameplay_input():
		return true
	if _spotlight_tutorial and is_instance_valid(_spotlight_tutorial) and _spotlight_tutorial.visible:
		return true
	return false


func set_pause_playfield_overlay_hidden(hidden: bool) -> void:
	var hit_zone := get_node_or_null("Playfield/HitZone") as CanvasItem
	if hit_zone:
		hit_zone.visible = not hidden


func _input(event):
	if get_tree() and get_tree().root:
		var c = get_tree().root.get_node_or_null("Console")
		if c and c.is_visible():
			return
	if _gen_qa_dialog_blocks_input():
		return
	if _defeat_blocks_gameplay_input():
		return
	if event is InputEventKey and !event.echo:
		var ctrl_pressed = Input.is_physical_key_pressed(KEY_CTRL)
		var r_pressed = Input.is_physical_key_pressed(KEY_R)

		if event.pressed and event.physical_keycode == KEY_R and ctrl_pressed:
			if not is_restart_held and not restart_timer.is_stopped():
				restart_timer.stop()
			if not is_restart_held:
				is_restart_held = true
				restart_timer.start()
				print("GameScreen: Начат отсчёт рестарта (удерживайте Ctrl+R)...")

		if event is InputEventKey and not event.pressed:
			if (event.physical_keycode == KEY_CTRL or event.physical_keycode == KEY_R) and is_restart_held:
				if not restart_timer.is_stopped():
					restart_timer.stop()
					print("GameScreen: Рестарт отменён (клавиша отпущена)")
				is_restart_held = false

		var keycode = event.keycode
		var shift_pressed = Input.is_key_pressed(KEY_SHIFT)

		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_TAB and _chart_compare_hotkey_ready():
				_swap_chart_ab_hotkey()
				accept_event()
				return
			if event.keycode == KEY_F10:
				if not countdown_active and not game_finished and not _defeat_blocks_gameplay_input():
					if event.shift_pressed:
						_close_generation_quality_range_end()
					else:
						_open_generation_quality_report()
				accept_event()
				return
			if event.keycode == KEY_QUOTELEFT and event.shift_pressed:
				if debug_menu and SettingsManager.get_enable_debug_menu():
					debug_menu.toggle_visibility()
				return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			if is_visible_in_tree():
				accept_event()
			if countdown_active:
				skip_countdown()
				return
			if _can_skip_to_next_track():
				end_game()
				return
		if event.keycode == KEY_ESCAPE and not countdown_active:
			if _defeat_blocks_gameplay_input():
				return
			if _rewind_active:
				return
			if pauser.is_paused:
				if _pause_overlay_blocks_esc():
					return
				pauser.handle_resume_request()
			else:
				pauser.handle_pause_request()
			return

	if event is InputEventJoypadButton and event.pressed:
		if _gh_handle_system_button(event as InputEventJoypadButton):
			return

	if not input_enabled:
		return

	if event is InputEventKey and event.pressed:
		var keycode = event.keycode
		if keycode == KEY_SPACE and not countdown_active:
			if pauser.is_paused:
				return
			if _can_skip_to_next_track():
				end_game()
				return
			if skip_intro():
				_update_hint()
				return
		if not countdown_active:
			if is_autoplay_enabled() and player and (keycode in player.keymap) and keycode != KEY_SPACE:
				return
			if _is_mediator_key(keycode) and event.pressed:
				_register_strum_input()
				accept_event()
				return
			player.handle_key_press(keycode)

	elif event is InputEventKey and not event.pressed:
		var keycode = event.keycode
		if is_autoplay_enabled() and player and (keycode in player.keymap) and keycode != KEY_SPACE:
			return
		if _is_mediator_key(keycode):
			return
		player.handle_key_release(keycode)

	elif event is InputEventJoypadButton:
		_handle_gh_joypad_button(event)
		
func skip_countdown():
	if countdown_active:
		countdown_remaining = 0
		countdown_active = false
		if countdown_label: 
			countdown_label.visible = false
		input_enabled = true
		_cancel_countdown_tick()
		_refresh_run_hud_layout()
		if _is_series_mode():
			_fade_series_playfield_in()
			_show_series_track_reveal(false)
		start_gameplay()
		_reset_run_health()
		_update_hint()

func is_resume_rewind_active() -> bool:
	return _rewind_active


func auto_pause_on_unfocus() -> void:
	if pauser == null or pauser.is_paused:
		return
	if game_finished or countdown_active or not gameplay_started:
		return
	if _rewind_active:
		return
	pauser.handle_pause_request()


func _rewind_blocks_gameplay() -> bool:
	return _rewind_active


func rewind_song_to_time(target_time: float, seek_music: bool = false) -> void:
	game_time = maxf(0.0, target_time)
	if note_manager:
		note_manager.rewind_chart_to_time(game_time)
	if chart_compare and chart_compare.split_active_runtime and chart_compare.note_manager:
		chart_compare.note_manager.rewind_chart_to_time(game_time)
	if seek_music and MusicManager:
		MusicManager.set_music_position(game_time)


func begin_resume_rewind(
	from_song_time: float,
	restore_volume: float,
	reason: String = "pause"
) -> void:
	if _rewind_active or game_finished or countdown_active or not notes_loaded:
		return
	_rewind_active = true
	input_enabled = false
	var pause_at := maxf(maxf(0.0, from_song_time), maxf(0.0, game_time))
	var start_at := maxf(0.0, pause_at - RESUME_REWIND_SECONDS)
	var score_floor: Dictionary = score_manager.capture_rewind_snapshot() if score_manager else {}
	_rewind_pause_at = start_at
	game_time = start_at
	if MusicManager:
		if MusicManager.has_method("force_stop_game_track"):
			MusicManager.force_stop_game_track()
		else:
			MusicManager.stop_game_music()
	_restore_resume_rewind_snapshot(start_at)
	if score_manager and not score_floor.is_empty():
		score_manager.apply_rewind_score_floor(score_floor)
	rewind_song_to_time(start_at, false)
	if note_manager and note_manager.has_method("spawn_notes"):
		note_manager.spawn_notes()
		note_manager.update_notes()
	if chart_compare and chart_compare.split_active_runtime and chart_compare.note_manager:
		if chart_compare.note_manager.has_method("spawn_notes"):
			chart_compare.note_manager.spawn_notes()
		chart_compare.note_manager.update_notes()
	var song_path := ""
	if pending_game_music_path != "":
		song_path = pending_game_music_path
		pending_game_music_path = ""
	elif selected_song_data:
		song_path = str(selected_song_data.get("path", ""))
	if pauser:
		pauser.is_paused = false
	set_pause_playfield_overlay_hidden(false)
	_sync_health_bar_visibility()
	if game_timer and game_timer.is_stopped():
		game_timer.start()
	if MusicManager and MusicManager.has_method("play_resume_rewind_sound"):
		MusicManager.play_resume_rewind_sound()
	var overlay_host := get_node_or_null("Playfield") as Control
	var overlay := _ResumeRewindOverlay.new()
	var hint := ""
	if reason == "last_chance":
		hint = tr("GAME_NOTICE_LAST_CHANCE")
	elif reason == "pause":
		hint = tr("GAME_NOTICE_RESUME_REWIND")
	overlay.play(overlay_host, RESUME_REWIND_ANIM_SECONDS, hint)
	await get_tree().create_timer(RESUME_REWIND_ANIM_SECONDS).timeout
	game_time = start_at
	if song_path != "" and MusicManager:
		if MusicManager.has_method("play_game_music_at_position"):
			MusicManager.play_game_music_at_position(song_path, start_at)
		else:
			MusicManager.play_game_music(song_path)
			await get_tree().process_frame
			MusicManager.set_music_position(start_at)
		_apply_game_pitch_scale()
		if modifier_runtime:
			modifier_runtime.apply_audio_modifiers()
	if MusicManager:
		MusicManager.set_music_volume_multiplier(restore_volume)
	_apply_run_modifier_runtime()
	_rewind_active = false
	_rewind_pause_at = 0.0
	input_enabled = true
	_apply_health_bar(true)
	_sync_health_bar_visibility()
	if score_manager:
		_last_combo_value = score_manager.get_combo()
	update_ui()


func skip_intro() -> bool:
	if game_time < 0: 
		return false

	if pauser.is_paused or game_finished or countdown_active or _rewind_active:
		return false
	if skip_used:
		return false
	if note_manager and note_manager.get_notes().size() > 0:
		return false

	if game_time >= skip_time_threshold:
		return false

	var spawn_queue = note_manager.get_spawn_queue() 
	if not spawn_queue or spawn_queue.size() == 0:
		return false

	var first_note_time = spawn_queue[0].get("time", 0.0)
	if first_note_time <= game_time:
		return false

	if first_note_time < skip_time_threshold:
		return false

	var target_time = max(0.0, first_note_time - skip_rewind_seconds)
	game_time = target_time

	MusicManager.set_music_position(target_time)
	note_manager.skip_notes_before_time(target_time) 

	skip_used = true
	return true

func check_hit(lane: int, force_perfect: bool = false, autoplay_target = null):
	if pauser.is_paused or _rewind_active:
		return
	if _RunModifiers.is_single_lane(run_modifiers) and _RunModifiers.single_lane_is_collapsed(
		run_modifiers, run_modifier_params
	):
		lane = 0
	if not _RunModifiers.is_display_lane_playable(run_modifiers, lane, _layout_lane_count(), run_modifier_params):
		if _modifier_no_miss_forgiveness():
			register_miss(true)
		return
	if not notes_loaded:
		return

	var current_time_adjusted = _hit_time_for_judgement()
	var hit_zone_y_float := float(hit_zone_y)
	var active_notes = note_manager.get_notes()
	var closest_note = null

	if autoplay_target != null:
		if autoplay_target.was_hit or autoplay_target.is_missed:
			return
		closest_note = autoplay_target
	else:
		var candidates = []
		var single_lane_collapsed := _RunModifiers.is_single_lane(run_modifiers) and _RunModifiers.single_lane_is_collapsed(
			run_modifiers, run_modifier_params
		)
		for note in active_notes:
			if note.was_hit or note.is_missed:
				continue
			if str(note.note_kind) in note_manager.BASS_SUSTAIN_KINDS:
				if current_time_adjusted > float(note.time) + _hit_window_good():
					continue
			if abs(note.y - hit_zone_y_float) >= 50.0:
				continue
			if single_lane_collapsed:
				pass
			else:
				var note_display_lane := int(note.display_lane)
				if note_display_lane < 0:
					note_display_lane = _RunModifiers.display_lane_for_chart_lane(
						int(note.lane), lanes, _chart_lanes, run_modifiers,
						lane_remap_context(float(note.time)), run_modifier_params
					)
					note.display_lane = note_display_lane
				if note_display_lane != lane:
					continue
			candidates.append(note)

		if candidates.size() == 0:
			if force_perfect:
				return
			if _is_before_first_note():
				return
			_timing_debug_emit_row(lane, -1.0, -1.0, current_time_adjusted, 0.0, 0.0, "empty_zone", force_perfect)
			if _modifier_no_miss_forgiveness():
				register_miss(true)
			else:
				_combo_shake_and_dim()
				score_manager.reset_combo()
				MusicManager.play_miss_hit_sound()
				if OS.is_debug_build():
					print("[GameScreen] Игрок нажал в линии %d, но нот в зоне не было - сброс комбо (без штрафа точности)" % lane)
			return

		closest_note = candidates[0]
		var closest_distance = abs(closest_note.y - hit_zone_y_float)
		for note in candidates:
			var dist = abs(note.y - hit_zone_y_float)
			if dist < closest_distance:
				closest_note = note
				closest_distance = dist

	var note_time: float = float(closest_note.time)
	var hit_adj: float = float(current_time_adjusted)
	var time_diff: float = absf(hit_adj - note_time)
	var chart_json: float = float(closest_note.time)
	var signed_ms: float = (hit_adj - note_time) * 1000.0

	var outcome := "miss_timing"
	if force_perfect:
		outcome = "perfect_forced"
	elif time_diff <= _hit_window_perfect():
		outcome = "perfect"
	elif time_diff <= _hit_window_good():
		outcome = "good"

	_timing_debug_emit_row(lane, chart_json, note_time, current_time_adjusted, signed_ms, time_diff * 1000.0, outcome, force_perfect)

	if autoplay_target != null and _timing_debug_overlay_ok():
		_timing_debug_push_visual_ms((_autoplay_chart_now() - note_time) * 1000.0)

	if str(closest_note.note_kind) in note_manager.BASS_SUSTAIN_KINDS and closest_note.was_hit:
		return

	var hit_kind := HIT_KIND_MISS
	var judgement_successful = false

	if force_perfect:
		score_manager.add_perfect_hit()
		hit_kind = HIT_KIND_PERFECT
		judgement_successful = true
		perfect_hits_this_level += 1
	elif time_diff <= _hit_window_perfect():
		score_manager.add_perfect_hit()
		hit_kind = HIT_KIND_PERFECT
		judgement_successful = true
		perfect_hits_this_level += 1
	elif time_diff <= _hit_window_good():
		score_manager.add_good_hit()
		hit_kind = HIT_KIND_GOOD
		judgement_successful = true

	if judgement_successful:
		closest_note.on_hit()
		note_manager.mark_chart_note_consumed(closest_note)
		if current_instrument in ["drums", "standard"] and hit_kind == HIT_KIND_PERFECT:
			_pending_drum_perfect_hits += 1
		elif current_instrument == "bass" and hit_kind == HIT_KIND_PERFECT:
			_pending_bass_perfect_hits += 1
		_pending_daily_hit_notes += 1

		MusicManager.play_hit_sound(true)

		_spawn_hit_particles(lane, closest_note.lane_palette_color, hit_kind == HIT_KIND_PERFECT)

		var jcolor := judgement_color_other
		if hit_kind == HIT_KIND_PERFECT:
			jcolor = judgement_color_perfect
		elif hit_kind == HIT_KIND_GOOD:
			jcolor = judgement_color_good
		_show_judgement(_judgement_text(hit_kind), jcolor)

		_on_run_health_hit(hit_kind)
		if closest_note.is_ghost:
			score_manager.add_bonus_points(NoteManager.BASS_GHOST_BONUS)
			if current_instrument == "bass":
				_pending_bass_ghost_hits += 1
		if current_instrument == "bass" and closest_note.is_multilane:
			_pending_bass_multilane_hits += 1
		_record_accuracy_sample(note_time)
		_lane_stats_record(lane, true)
		_push_error_meter(hit_kind, signed_ms)

		if OS.is_debug_build():
			print("[GameScreen] Игрок нажал в линии %d, попадание: %s (time_diff: %.3fs)" % [lane, hit_kind, time_diff])
	else:
		if closest_note.is_ghost:
			closest_note.active = false
			note_manager.mark_chart_note_consumed(closest_note, "miss")
			if closest_note.visual_node:
				closest_note.visual_node.queue_free()
			return
		closest_note.is_missed = true
		note_manager.mark_chart_note_consumed(closest_note, "miss")
		score_manager.add_miss_hit()
		_record_accuracy_sample(note_time)
		_lane_stats_record(lane, false)
		_push_error_meter(HIT_KIND_MISS, signed_ms)
		MusicManager.play_miss_hit_sound()
		_combo_shake_and_dim()
		_show_judgement(_judgement_text(HIT_KIND_MISS), judgement_color_miss)
		_on_run_health_miss()
		if OS.is_debug_build():
			print("[GameScreen] Игрок нажал в линии %d, но попадание не засчитано (time_diff: %.3fs) - сброс комбо" % [lane, time_diff])


func _process(delta):
	# HUD и геймплейный тик — в _update_game (60 Гц). Здесь только отсчёт и фон.
	if countdown_active:
		update_ui()
		if audio_background:
			audio_background.update(delta)
		
func restart_level():
	_close_defeat_overlay()
	speed = _effective_scroll_speed()

	if game_finished:
		return

	if pauser and pauser.is_paused:
		pauser.cleanup_on_game_end()

	if not check_song_end_timer.is_stopped():
		check_song_end_timer.stop()
	if victory_delay_timer and not victory_delay_timer.is_stopped():
		victory_delay_timer.stop()
	pending_game_music_path = ""

	_reset_modifier_audio()
	MusicManager.stop_game_music()

	_lane_layout_relayout_key = ""
	_timing_debug_clear_ring()
	_configure_error_meter_for_run()
	_last_strum_at_sec = -999.0
	_reset_autoplay_state()
	_flush_pending_run_progress()
	player.reset()
	score_manager.reset()
	run_modifiers = run_modifiers_player.duplicate()
	if modifier_runtime:
		modifier_runtime.reset_dynamic_lanes_state()
		modifier_runtime.reset_combo_escalation_state()
	_apply_run_modifier_runtime()
	note_manager.clear_notes()
	if chart_compare:
		chart_compare.reset_runtime()
	perfect_hits_this_level = 0
	_clear_resume_rewind_snapshots()
	_pending_daily_hit_notes = 0
	_pending_drum_perfect_hits = 0
	_pending_bass_perfect_hits = 0
	_pending_bass_ghost_hits = 0
	_pending_bass_multilane_hits = 0
	_pending_bass_perfect_holds = 0
	_run_bass_hold_early_releases = 0
	_clear_accuracy_samples()
	_clear_resume_rewind_snapshots()
	_last_combo_value = 0
	if audio_background:
		audio_background.reset_visuals()
	game_time = 0.0
	game_finished = false
	notes_ended = false
	skip_used = false
	input_enabled = false
	countdown_active = true
	gameplay_started = false
	notes_loaded = false
	_run_assets_prepared = false
	PlayerDataManager.increment_daily_progress("level_restarted", 1, {})

	update_ui()
	_update_hint()
	if countdown_label:
		countdown_label.visible = true

	if game_timer and game_timer.is_stopped():
		game_timer.start()

	start_countdown()
	
func _on_restart_confirmed():
	is_restart_held = false
	print("GameScreen: Рестарт подтверждён!")
	MusicManager.play_restart_sound()
	if pauser and pauser.is_paused:
		pauser.cleanup_on_game_end()
	restart_level()	
	
func _exit_to_song_select():
	_flush_pending_run_progress()
	pauser.cleanup_on_game_end()
	var game_engine = get_parent()
	if game_engine and game_engine.has_method("get_transitions"):
		var transitions = game_engine.get_transitions()
		if transitions:
			transitions.open_song_select()

func _pulse_combo_label():
	if combo_label == null:
		return
	combo_label.modulate = _combo_default_modulate
	if animation_player and animation_player.has_animation("ComboPulse"):
		animation_player.stop(true)
		animation_player.play("ComboPulse")

func _combo_burst(mult: float):
	if combo_label == null:
		return
	if animation_player:
		if mult >= 1.3 and animation_player.has_animation("ComboBurst100"):
			animation_player.stop(true)
			_flash_combo_label_color(combo_color_100, 0.45)
			animation_player.play("ComboBurst100")
		elif mult >= 1.25 and animation_player.has_animation("ComboBurst50"):
			animation_player.stop(true)
			_flash_combo_label_color(combo_color_50, 0.45)
			animation_player.play("ComboBurst50")

func _flash_combo_label_color(col: Color, duration: float):
	if combo_label == null:
		return
	var prev := combo_label.get_theme_color("font_color", "Label")
	combo_label.add_theme_color_override("font_color", col)
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = max(0.05, duration)
	t.timeout.connect(func():
		if is_instance_valid(combo_label):
			combo_label.add_theme_color_override("font_color", prev)
		if is_instance_valid(t) and t.get_parent() == self:
			t.queue_free()
	)
	add_child(t)
	t.start()

func _show_judgement(text: String, color: Color) -> void:
	if not judgement_label or not is_instance_valid(judgement_label):
		return
	if _judgement_tween and _judgement_tween.is_valid():
		_judgement_tween.kill()
	judgement_label.text = text
	var c := color
	c.a = 1.0
	judgement_label.modulate = c
	judgement_label.pivot_offset = judgement_label.size * 0.5
	judgement_label.scale = Vector2(1.4, 1.4)
	_judgement_tween = create_tween()
	_judgement_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_judgement_tween.tween_property(judgement_label, "scale", Vector2.ONE, 0.18)
	_judgement_tween.tween_interval(0.22)
	_judgement_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_judgement_tween.tween_property(judgement_label, "modulate:a", 0.0, 0.3)

func show_miss_judgement() -> void:
	_show_judgement(_judgement_text(HIT_KIND_MISS), judgement_color_miss)

func _combo_shake_and_dim():
	if combo_label == null:
		return
	if animation_player and animation_player.has_animation("ComboMiss"):
		animation_player.stop(true)
		animation_player.play("ComboMiss")


func _open_settings_from_pause() -> void:
	if pauser:
		pauser.hide_pause_menu_for_settings()
	var game_engine = get_parent()
	if game_engine and game_engine.has_method("get_transitions"):
		var transitions = game_engine.get_transitions()
		if transitions:
			transitions.open_settings(true)


func restore_pause_menu_after_settings() -> void:
	if pauser:
		pauser.show_pause_menu_after_settings()


func _set_play_mode(mode: String) -> void:
	_play_mode = str(mode).strip_edges()


func _is_endless_mode() -> bool:
	return _play_mode == _PlayModeIds.ENDLESS


func _is_marathon_mode() -> bool:
	return _play_mode == _PlayModeIds.MARATHON


func _is_series_mode() -> bool:
	return _is_endless_mode() or _is_marathon_mode()


func configure_marathon_run(run_ref) -> void:
	_marathon_run_ref = run_ref
	_endless_run_ref = null
	_ensure_endless_hud()
	_apply_series_hud_colors()
	if run_ref != null and run_ref.has_method("get_launch_params"):
		var launch: Dictionary = run_ref.get_launch_params()
		_endless_display_track_index = int(launch.get("track_index", 0))
		_marathon_display_total_tracks = int(launch.get("total_tracks", 0))


func configure_endless_run(run_ref) -> void:
	_endless_run_ref = run_ref
	_marathon_run_ref = null
	_ensure_endless_hud()
	if run_ref != null:
		if "track_index" in run_ref:
			_endless_display_track_index = int(run_ref.track_index)
		elif run_ref.has_method("get_launch_params"):
			var launch: Dictionary = run_ref.get_launch_params()
			_endless_display_track_index = int(launch.get("track_index", 0))


func configure_pause_menu_for_mode(pause_menu: Control) -> void:
	if pause_menu == null:
		return
	if pause_menu.has_method("configure_for_endless"):
		var stats: Dictionary = {}
		if _is_series_mode():
			var run_ref = _get_series_run()
			if run_ref != null and run_ref.has_method("get_pause_stats"):
				stats = run_ref.get_pause_stats()
		pause_menu.configure_for_endless(_is_series_mode(), stats)


func _ensure_endless_hud() -> void:
	if not is_node_ready():
		call_deferred("_ensure_endless_hud")
		return
	var ui_container := get_node_or_null("UIContainer") as Control
	if ui_container == null:
		return
	var center := get_node_or_null("UIContainer/CenterContainer") as CenterContainer
	if center == null:
		return
	if _endless_countdown_stack == null:
		_endless_countdown_stack = VBoxContainer.new()
		_endless_countdown_stack.name = "EndlessCountdownStack"
		_endless_countdown_stack.alignment = BoxContainer.ALIGNMENT_CENTER
		_endless_countdown_stack.add_theme_constant_override("separation", 12)
		_endless_countdown_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_endless_countdown_stack.visible = false
		center.add_child(_endless_countdown_stack)
		center.move_child(_endless_countdown_stack, 0)
	if _endless_track_number_label == null:
		_endless_track_number_label = Label.new()
		_endless_track_number_label.name = "EndlessTrackNumberLabel"
		_endless_track_number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_endless_track_number_label.add_theme_font_size_override("font_size", 38)
		_endless_track_number_label.add_theme_color_override("font_color", Color(0.88, 0.78, 1.0, 0.98))
		_endless_track_number_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		_endless_track_number_label.add_theme_constant_override("outline_size", 8)
		_endless_track_number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_endless_track_number_label.visible = false
		_endless_countdown_stack.add_child(_endless_track_number_label)
	if _endless_song_info_label == null:
		_endless_song_info_label = Label.new()
		_endless_song_info_label.name = "EndlessSongInfoLabel"
		_endless_song_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_endless_song_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_endless_song_info_label.add_theme_font_size_override("font_size", 24)
		_endless_song_info_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.98, 0.96))
		_endless_song_info_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
		_endless_song_info_label.add_theme_constant_override("outline_size", 6)
		_endless_song_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_endless_song_info_label.visible = false
		_endless_countdown_stack.add_child(_endless_song_info_label)
	if _endless_mod_reveal == null:
		_endless_mod_reveal = HBoxContainer.new()
		_endless_mod_reveal.name = "EndlessModReveal"
		_endless_mod_reveal.alignment = BoxContainer.ALIGNMENT_CENTER
		_endless_mod_reveal.add_theme_constant_override("separation", 8)
		_endless_mod_reveal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_endless_mod_reveal.visible = false
		_endless_countdown_stack.add_child(_endless_mod_reveal)
	elif _endless_mod_reveal.get_parent() != _endless_countdown_stack:
		var old_parent := _endless_mod_reveal.get_parent()
		if old_parent:
			old_parent.remove_child(_endless_mod_reveal)
		_endless_countdown_stack.add_child(_endless_mod_reveal)
	if _endless_track_cue == null:
		_endless_track_cue = Label.new()
		_endless_track_cue.name = "EndlessTrackCue"
		_endless_track_cue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_endless_track_cue.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_endless_track_cue.add_theme_font_size_override("font_size", 18)
		_endless_track_cue.add_theme_color_override("font_color", Color(0.72, 0.58, 0.98, 0.95))
		_endless_track_cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_endless_track_cue.visible = false
		ui_container.add_child(_endless_track_cue)
		_endless_track_cue.set_anchors_preset(Control.PRESET_TOP_WIDE)
		_endless_track_cue.offset_top = 30.0
		_endless_track_cue.offset_bottom = 58.0


func _endless_track_reveal_song_line() -> String:
	var artist := str(selected_song_data.get("artist", "")).strip_edges()
	var title := str(selected_song_data.get("title", "")).strip_edges()
	if title == "":
		title = str(selected_song_data.get("path", "")).get_file().get_basename()
	var song_line := title
	if artist != "" and artist != "Неизвестен" and artist.to_lower() != "unknown":
		song_line = "%s — %s" % [artist, title]
	var inst := _EndlessSessionConfig.preview_instrument_text(current_instrument)
	var gen := tr(_EndlessSessionConfig.generation_mode_label_key(current_generation_mode))
	return "%s (%s · %s)" % [song_line, inst, gen]


func _apply_series_hud_colors() -> void:
	if not _is_marathon_mode():
		return
	if _endless_track_number_label:
		_endless_track_number_label.add_theme_color_override("font_color", Color(0.92, 0.82, 0.68, 0.98))
	if _endless_song_info_label:
		_endless_song_info_label.add_theme_color_override("font_color", Color(0.86, 0.76, 0.58, 0.96))
	if _endless_track_cue:
		_endless_track_cue.add_theme_color_override("font_color", Color(0.79, 0.57, 0.35, 0.95))


func _show_series_track_reveal(compact: bool = false) -> void:
	_show_endless_track_reveal(compact)


func _show_endless_track_reveal(compact: bool = false) -> void:
	_ensure_endless_hud()
	if _endless_countdown_stack == null:
		return
	if _endless_reveal_tween and is_instance_valid(_endless_reveal_tween):
		_endless_reveal_tween.kill()
		_endless_reveal_tween = null
	if _endless_track_number_label and _endless_display_track_index > 0:
		if _is_marathon_mode() and _marathon_display_total_tracks > 0:
			_endless_track_number_label.text = tr("MARATHON_TRACK_NUMBER_FMT") % [
				_endless_display_track_index,
				_marathon_display_total_tracks,
			]
		else:
			if _endless_pool_lap_announce > 1:
				_endless_track_number_label.text = tr("ENDLESS_POOL_LAP_START_FMT") % _endless_pool_lap_announce
			else:
				_endless_track_number_label.text = tr("ENDLESS_SONG_NUMBER_FMT") % _endless_display_track_index
		_endless_track_number_label.visible = true
	elif _endless_track_number_label:
		_endless_track_number_label.visible = false
	if _endless_song_info_label:
		_endless_song_info_label.text = _endless_track_reveal_song_line()
		_endless_song_info_label.visible = true
	if _endless_mod_reveal:
		_ModifierIconStrip.fill(
			_endless_mod_reveal,
			run_modifiers_player,
			ENDLESS_MOD_REVEAL_ICON_SIZE,
			ENDLESS_MOD_REVEAL_FRAME_SIZE
		)
		_endless_mod_reveal.visible = not run_modifiers_player.is_empty()
	var show_stack := (
		(_endless_track_number_label and _endless_track_number_label.visible)
		or (_endless_song_info_label and _endless_song_info_label.visible)
		or (_endless_mod_reveal and _endless_mod_reveal.visible)
	)
	_endless_countdown_stack.visible = show_stack
	_endless_countdown_stack.modulate = Color(1, 1, 1, 1)
	if not show_stack:
		return
	var hold_sec := SERIES_TRACK_REVEAL_COMPACT_HOLD_SEC if compact else ENDLESS_TRACK_REVEAL_HOLD_SEC
	var fade_sec := SERIES_TRACK_REVEAL_COMPACT_FADE_SEC if compact else ENDLESS_TRACK_REVEAL_FADE_SEC
	_endless_reveal_tween = create_tween()
	_endless_reveal_tween.tween_interval(hold_sec)
	_endless_reveal_tween.tween_property(
		_endless_countdown_stack,
		"modulate:a",
		0.0,
		fade_sec
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_endless_reveal_tween.finished.connect(_hide_endless_mod_reveal, CONNECT_ONE_SHOT)


func _hide_endless_mod_reveal() -> void:
	if _endless_reveal_tween and is_instance_valid(_endless_reveal_tween):
		_endless_reveal_tween.kill()
		_endless_reveal_tween = null
	if _endless_countdown_stack:
		_endless_countdown_stack.visible = false
		_endless_countdown_stack.modulate = Color(1, 1, 1, 1)
	if _endless_mod_reveal:
		_endless_mod_reveal.visible = false
	if _endless_track_number_label:
		_endless_track_number_label.visible = false
	if _endless_song_info_label:
		_endless_song_info_label.visible = false
	_endless_pool_lap_announce = 0


func _get_marathon_run():
	if _marathon_run_ref != null:
		return _marathon_run_ref
	var transitions = _get_transitions()
	if transitions != null and transitions.has_method("get_marathon_run"):
		return transitions.get_marathon_run()
	return null


func _get_series_run():
	if _is_marathon_mode():
		return _get_marathon_run()
	return _get_endless_run()


func _get_endless_run():
	if _endless_run_ref != null:
		return _endless_run_ref
	var transitions = _get_transitions()
	if transitions != null and transitions.has_method("get_endless_run"):
		return transitions.get_endless_run()
	return null


func _series_hud_score() -> int:
	var run = _get_series_run()
	var series_base := int(run.total_score) if run != null else 0
	return series_base + score_manager.get_score()


func _endless_hud_score() -> int:
	return _series_hud_score()


func _series_hud_accuracy() -> float:
	var run = _get_series_run()
	if run == null:
		return score_manager.get_accuracy()
	var hit: int = int(run.total_hit_notes) + int(score_manager.get_hit_notes_count())
	var miss: int = int(run.total_missed_notes) + int(score_manager.get_missed_notes_count())
	var played: int = hit + miss
	if played <= 0:
		return 100.0
	return clampf(float(hit) / float(played) * 100.0, 0.0, 100.0)


func _endless_hud_accuracy() -> float:
	return _series_hud_accuracy()


func _collect_endless_track_stats() -> Dictionary:
	_apply_score_reward_multiplier()
	var hit_notes: int = int(score_manager.get_hit_notes_count())
	var missed_notes: int = int(score_manager.get_missed_notes_count())
	var max_combo: int = int(score_manager.get_max_combo())
	var stats := {
		"score": score_manager.get_score(),
		"accuracy": score_manager.get_accuracy(),
		"combo": int(score_manager.get_combo()),
		"max_combo": max_combo,
		"missed_notes": missed_notes,
		"hit_notes": hit_notes,
		"perfect_hits": perfect_hits_this_level,
		"total_notes": hit_notes + missed_notes,
		"combo_multiplier": _RunRewards.compute_combo_multiplier(max_combo),
		"modifiers": run_modifiers_player.duplicate(),
		"song_path": str(selected_song_data.get("path", "")),
		"title": str(selected_song_data.get("title", selected_song_data.get("path", "").get_file())),
		"lane_stats": _build_lane_stats(),
	}
	if _is_series_mode():
		stats["end_hp_ratio"] = run_health_ratio
	return stats


func _get_transitions():
	if game_engine and game_engine.has_method("get_transitions"):
		return game_engine.get_transitions()
	return null


func _end_game_series_track_cleared() -> void:
	if _is_marathon_mode():
		_end_game_marathon_track_cleared()
	else:
		_end_game_endless_track_cleared()


func _end_game_series_defeat() -> void:
	if _is_marathon_mode():
		_end_game_marathon_defeat()
	else:
		_end_game_endless_defeat()


func _end_game_marathon_track_cleared() -> void:
	if game_finished or _endless_transition_busy:
		return
	if pauser.is_paused:
		pauser.cleanup_on_game_end()
		return

	game_finished = true
	notes_ended = false
	input_enabled = false
	if not game_timer.is_stopped():
		game_timer.stop()
	if not check_song_end_timer.is_stopped():
		check_song_end_timer.stop()
	if not victory_delay_timer.is_stopped():
		victory_delay_timer.stop()
	_reset_modifier_audio()
	MusicManager.stop_game_music()
	auto_play_enabled = false
	_flush_pending_run_progress()

	var transitions = _get_transitions()
	if transitions == null or not transitions.has_method("get_marathon_run"):
		return
	var run = transitions.get_marathon_run()
	if run == null:
		return

	var stats := _collect_endless_track_stats()
	var has_next: bool = bool(run.on_track_cleared(stats))
	if run.should_end_after_track() or not has_next:
		var reason: String = "exit" if run.should_end_after_track() else str(run.get_finish_reason())
		if transitions.has_method("finish_marathon_run"):
			transitions.finish_marathon_run(reason)
		return
	_play_series_inter_track_transition(transitions)


func _end_game_marathon_defeat() -> void:
	if game_finished:
		return
	if pauser.is_paused:
		pauser.cleanup_on_game_end()

	game_finished = true
	input_enabled = false
	if not game_timer.is_stopped():
		game_timer.stop()
	if not check_song_end_timer.is_stopped():
		check_song_end_timer.stop()
	if not victory_delay_timer.is_stopped():
		victory_delay_timer.stop()
	_reset_modifier_audio()
	MusicManager.stop_game_music()
	auto_play_enabled = false
	_flush_pending_run_progress()

	var transitions = _get_transitions()
	if transitions == null or not transitions.has_method("get_marathon_run"):
		return
	var run = transitions.get_marathon_run()
	if run != null:
		run.on_track_defeat(_collect_endless_track_stats())
	if transitions.has_method("finish_marathon_run"):
		transitions.finish_marathon_run("defeat")


func _end_game_endless_track_cleared() -> void:
	if game_finished or _endless_transition_busy:
		return
	if pauser.is_paused:
		pauser.cleanup_on_game_end()
		return

	game_finished = true
	notes_ended = false
	input_enabled = false
	if not game_timer.is_stopped():
		game_timer.stop()
	if not check_song_end_timer.is_stopped():
		check_song_end_timer.stop()
	if not victory_delay_timer.is_stopped():
		victory_delay_timer.stop()
	_reset_modifier_audio()
	MusicManager.stop_game_music()
	auto_play_enabled = false
	_flush_pending_run_progress()

	var transitions = _get_transitions()
	if transitions == null or not transitions.has_method("get_endless_run"):
		return
	var run = transitions.get_endless_run()
	if run == null:
		return

	var stats := _collect_endless_track_stats()
	var has_next: bool = bool(run.on_track_cleared(stats))
	if run.should_end_after_track() or not has_next:
		var reason: String = "exit" if run.should_end_after_track() else str(run.get_finish_reason())
		if transitions.has_method("finish_endless_run"):
			transitions.finish_endless_run(reason)
		return
	_play_endless_inter_track_transition(transitions)


func _end_game_endless_defeat() -> void:
	if game_finished:
		return
	if pauser.is_paused:
		pauser.cleanup_on_game_end()

	game_finished = true
	input_enabled = false
	if not game_timer.is_stopped():
		game_timer.stop()
	if not check_song_end_timer.is_stopped():
		check_song_end_timer.stop()
	if not victory_delay_timer.is_stopped():
		victory_delay_timer.stop()
	_reset_modifier_audio()
	MusicManager.stop_game_music()
	auto_play_enabled = false
	_flush_pending_run_progress()

	var transitions = _get_transitions()
	if transitions == null or not transitions.has_method("get_endless_run"):
		return
	var run = transitions.get_endless_run()
	if run != null:
		run.on_track_defeat(_collect_endless_track_stats())
	if transitions.has_method("finish_endless_run"):
		transitions.finish_endless_run("defeat")


func _play_endless_inter_track_transition(transitions) -> void:
	_play_series_inter_track_transition(transitions)


func _play_series_inter_track_transition(transitions) -> void:
	_endless_transition_busy = true
	input_enabled = false
	MusicManager.play_restart_sound()
	_fade_series_playfield_out()
	var run = _get_series_run()
	if _endless_track_cue:
		if _is_marathon_mode() and run != null:
			var cleared := int(run.tracks_cleared)
			var total := int(run.total_tracks()) if run.has_method("total_tracks") else 0
			_endless_track_cue.text = tr("MARATHON_TRACK_CLEARED_FMT") % [cleared, total]
		elif run != null:
			var lap_announce := 0
			if run.has_method("get_pending_pool_lap_announce"):
				lap_announce = int(run.get_pending_pool_lap_announce())
			if lap_announce > 1:
				_endless_track_cue.text = tr("ENDLESS_POOL_LAP_INTER_FMT") % lap_announce
			else:
				_endless_track_cue.text = tr("ENDLESS_TRACK_CLEARED_FMT") % int(run.streak)
		_endless_track_cue.modulate = Color(1, 1, 1, 1)
		_endless_track_cue.visible = true
	if progress_bar:
		progress_bar.value = 100.0
	var cue_timer := get_tree().create_timer(ENDLESS_TRACK_CUE_SEC)
	cue_timer.timeout.connect(func() -> void:
		if _endless_track_cue:
			_endless_track_cue.visible = false
		_tween_series_progress_reset(transitions)
	, CONNECT_ONE_SHOT)


func _tween_series_progress_reset(transitions) -> void:
	if progress_bar == null:
		_finish_series_inter_track_transition(transitions)
		return
	if _endless_progress_tween and is_instance_valid(_endless_progress_tween):
		_endless_progress_tween.kill()
	_endless_progress_tween = create_tween()
	_endless_progress_tween.tween_property(progress_bar, "value", 0.0, ENDLESS_PROGRESS_RESET_SEC)
	_endless_progress_tween.finished.connect(func() -> void:
		_finish_series_inter_track_transition(transitions)
	, CONNECT_ONE_SHOT)


func _tween_endless_progress_reset(transitions) -> void:
	_tween_series_progress_reset(transitions)


func _finish_series_inter_track_transition(transitions) -> void:
	if _is_marathon_mode():
		if transitions.has_method("continue_marathon_on_game_screen"):
			transitions.continue_marathon_on_game_screen(self)
	else:
		if transitions.has_method("continue_endless_on_game_screen"):
			transitions.continue_endless_on_game_screen(self)
	_endless_transition_busy = false


func _finish_endless_inter_track_transition(transitions) -> void:
	_finish_series_inter_track_transition(transitions)


func load_next_series_track(launch: Dictionary) -> void:
	load_next_endless_track(launch)
	_marathon_display_total_tracks = int(launch.get("total_tracks", _marathon_display_total_tracks))


func load_next_endless_track(launch: Dictionary) -> void:
	_cancel_countdown_tick()
	_endless_transition_busy = false
	_close_defeat_overlay()
	_hide_endless_mod_reveal()
	_endless_display_track_index = int(launch.get("track_index", 0))
	_endless_pool_lap_announce = int(launch.get("pool_lap_announce", 0))
	_set_selected_song(launch.get("song_info", {}))
	_set_instrument(str(launch.get("instrument", current_instrument)))
	_set_generation_mode(str(launch.get("generation_mode", current_generation_mode)))
	_set_lanes(int(launch.get("lane_count", lanes)))
	_set_chart_tag(str(launch.get("chart_tag", "")))
	_set_run_modifiers(launch.get("run_modifiers", []))

	speed = _effective_scroll_speed()
	if not check_song_end_timer.is_stopped():
		check_song_end_timer.stop()
	if victory_delay_timer and not victory_delay_timer.is_stopped():
		victory_delay_timer.stop()
	pending_game_music_path = ""
	_reset_modifier_audio()
	MusicManager.stop_game_music()
	_lane_layout_relayout_key = ""
	_timing_debug_clear_ring()
	_configure_error_meter_for_run()
	_last_strum_at_sec = -999.0
	_reset_autoplay_state()
	player.reset()
	var carried_combo: int = score_manager.get_combo() if score_manager else 0
	score_manager.reset()
	if carried_combo > 0:
		score_manager.combo = carried_combo
		score_manager.max_combo = maxi(score_manager.max_combo, carried_combo)
		score_manager.combo_multiplier = minf(4.0, 1.0 + float(int(carried_combo / 10)))
	if modifier_runtime:
		modifier_runtime.reset_dynamic_lanes_state()
		modifier_runtime.reset_combo_escalation_state()
	_apply_run_modifier_runtime()
	note_manager.clear_notes()
	if chart_compare:
		chart_compare.reset_runtime()
	perfect_hits_this_level = 0
	_clear_resume_rewind_snapshots()
	_clear_accuracy_samples()
	_last_combo_value = carried_combo
	if audio_background:
		audio_background.reset_visuals()
	game_time = 0.0
	game_finished = false
	notes_ended = false
	skip_used = false
	input_enabled = false
	var use_series_countdown := _should_use_series_inter_track_countdown(launch)
	countdown_active = use_series_countdown
	gameplay_started = false
	notes_loaded = false
	_run_assets_prepared = false
	if _is_series_mode():
		var default_hp := _EndlessSessionConfig.DEFAULT_INTER_TRACK_HP_RECOVERY_PCT
		if _is_marathon_mode():
			default_hp = 100
		var pct := int(launch.get("inter_track_hp_recovery_pct", default_hp))
		_apply_inter_track_health_recovery(pct)
	else:
		_reset_run_health()
	var run = _get_series_run()
	if run != null:
		score_display_value = float(int(run.total_score))
		accuracy_display_value = _series_hud_accuracy()
	update_ui()
	_update_hint()
	if countdown_label:
		countdown_label.visible = countdown_active
	if game_timer and game_timer.is_stopped():
		game_timer.start()
	if use_series_countdown:
		start_countdown()
	else:
		_start_series_track_without_countdown()


func _should_use_series_inter_track_countdown(_launch: Dictionary) -> bool:
	if not _is_series_mode():
		return true
	if SettingsManager == null or not SettingsManager.has_method("get_series_inter_track_countdown_enabled"):
		return false
	return SettingsManager.get_series_inter_track_countdown_enabled()


func _get_playfield() -> Control:
	return get_node_or_null("Playfield") as Control


func _kill_series_fade_tween() -> void:
	if _series_fade_tween and is_instance_valid(_series_fade_tween):
		_series_fade_tween.kill()
	_series_fade_tween = null


func _fade_series_playfield_out() -> void:
	var playfield := _get_playfield()
	if playfield == null:
		return
	_series_playfield_base_modulate = playfield.modulate
	if _series_playfield_base_modulate.a <= 0.01:
		_series_playfield_base_modulate = Color(1, 1, 1, 1)
	_kill_series_fade_tween()
	_series_fade_tween = create_tween()
	var target := Color(
		_series_playfield_base_modulate.r,
		_series_playfield_base_modulate.g,
		_series_playfield_base_modulate.b,
		0.0
	)
	_series_fade_tween.tween_property(
		playfield,
		"modulate",
		target,
		SERIES_INTER_TRACK_FADE_OUT_SEC
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _fade_series_playfield_in() -> void:
	var playfield := _get_playfield()
	if playfield == null:
		return
	_kill_series_fade_tween()
	_series_fade_tween = create_tween()
	_series_fade_tween.tween_property(
		playfield,
		"modulate",
		_series_playfield_base_modulate,
		SERIES_INTER_TRACK_FADE_IN_SEC
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _start_series_track_without_countdown() -> void:
	if not _run_assets_prepared:
		_prepare_run_assets()
	_cancel_countdown_tick()
	_hide_endless_mod_reveal()
	countdown_active = false
	_prepare_health_intro()
	_configure_error_meter_for_run()
	_sync_health_bar_visibility()
	if error_meter:
		error_meter.visible = _error_meter_should_show()
	input_enabled = false
	if countdown_label:
		countdown_label.visible = false
	_refresh_run_hud_layout()
	call_deferred("_refresh_run_hud_layout")
	if game_timer and game_timer.is_stopped():
		game_timer.start()
	_fade_series_playfield_in()
	_show_series_track_reveal(true)
	input_enabled = true
	start_gameplay()
	_reset_run_health()
	_update_hint()


func request_endless_exit_after_track() -> void:
	request_series_exit_after_track()


func request_series_exit_after_track() -> void:
	var transitions = _get_transitions()
	if transitions == null:
		return
	var run = _get_series_run()
	if run != null and run.has_method("request_exit_after_track"):
		run.request_exit_after_track()
	if pauser and pauser.is_paused:
		pauser.handle_resume_request()
	var notice_key := "MARATHON_EXIT_AFTER_TRACK" if _is_marathon_mode() else "ENDLESS_EXIT_AFTER_TRACK"
	show_center_game_notice(tr(notice_key), Color(0.79, 0.57, 0.35, 1.0), 3.0)


func abandon_series_and_show_summary() -> void:
	_finalize_series_abandon(false)


func abandon_series_and_exit_main_menu() -> void:
	_finalize_series_abandon(true)


func _finalize_series_abandon(to_main_menu: bool) -> void:
	if not _is_series_mode() or game_finished:
		return
	_stop_series_gameplay_for_abandon()
	var transitions = _get_transitions()
	if transitions == null:
		return
	var run = _get_series_run()
	var stats := _collect_endless_track_stats()
	if run != null and run.has_method("on_series_manual_exit"):
		run.on_series_manual_exit(stats)
	elif run != null and run.has_method("on_track_defeat"):
		run.on_track_defeat(stats)
	if _is_marathon_mode():
		if to_main_menu and transitions.has_method("finish_marathon_run_to_main_menu"):
			transitions.finish_marathon_run_to_main_menu("exit")
		elif transitions.has_method("finish_marathon_run"):
			transitions.finish_marathon_run("exit")
		return
	if to_main_menu and transitions.has_method("finish_endless_run_to_main_menu"):
		transitions.finish_endless_run_to_main_menu("exit")
	elif transitions.has_method("finish_endless_run"):
		transitions.finish_endless_run("exit")


func _stop_series_gameplay_for_abandon() -> void:
	if pauser and pauser.is_paused:
		pauser.cleanup_on_game_end()
	game_finished = true
	input_enabled = false
	if not game_timer.is_stopped():
		game_timer.stop()
	if not check_song_end_timer.is_stopped():
		check_song_end_timer.stop()
	if not victory_delay_timer.is_stopped():
		victory_delay_timer.stop()
	_reset_modifier_audio()
	MusicManager.stop_game_music()
	auto_play_enabled = false
	_flush_pending_run_progress()


func _request_endless_deferred_exit() -> void:
	request_series_exit_after_track()


func _exit_to_main_menu():
	if _is_series_mode():
		abandon_series_and_exit_main_menu()
		return
	_flush_pending_run_progress()
	pauser.cleanup_on_game_end() 
	var game_engine = get_parent()
	if game_engine and game_engine.has_method("get_transitions"):
		var transitions = game_engine.get_transitions()
		if transitions:
			transitions.exit_to_main_menu()

func _exit_tree() -> void:
	_flush_pending_run_progress()
	Engine.max_fps = original_max_fps
	DisplayServer.window_set_vsync_mode(original_vsync_mode)
 
