# scenes/game_screen/game_screen.gd
extends Control

const ScoreManager = preload("res://logic/score_manager.gd")
const NoteManager = preload("res://logic/note_manager.gd")
const Player = preload("res://logic/player.gd")
const GAME_UPDATE_DELTA = 1.0 / 60.0

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
var current_instrument: String = "standard"
var current_generation_mode: String = "basic"

var selected_song_data: Dictionary = {}

var score_manager
var note_manager
var player
var game_engine
 
var score_label: Label = null
var combo_label: Label = null
var accuracy_label: Label = null
var countdown_label: Label = null
var notes_container: Node2D = null
var judgement_label: Label = null
var progress_bar: ProgressBar = null
var hint_label: Label = null
var _combo_pulse_tween: Tween = null
var _last_combo_value: int = 0
var _combo_reset_tween: Tween = null
var _combo_original_position: Vector2 = Vector2.ZERO
var _combo_default_modulate: Color = Color(1, 1, 1, 1)
var _score_tween: Tween = null
var _score_display_value_internal: float = 0.0
var score_display_value: float:
	set(value):
		_score_display_value_internal = value
		if score_label:
			score_label.text = "Счёт: %d" % int(round(_score_display_value_internal))
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
var check_song_end_timer: Timer

var notes_loaded: bool = false
var skip_used = false
var skip_time_threshold = 10.0
var skip_rewind_seconds = 5.0

var lane_highlight_nodes: Array[ColorRect] = []
var lane_nodes: Array[ColorRect] = []

var debug_menu = null
var auto_play_enabled: bool = false 
var _autoplay_press_until := {}
const AUTOPLAY_NO_PRESS_TIME: float = -1000000000.0
const AUTOPLAY_LINE_TOLERANCE_MIN_PX: float = 10.0

var perfect_hits_this_level: int = 0

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
@export var combo_color_50: Color = Color(1.0, 0.75, 0.3, 1.0)
@export var combo_color_100: Color = Color(1.0, 0.9, 0.1, 1.0)


func _ready():
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
	note_manager = NoteManager.new(self)
	player = Player.new(settings_for_player, lanes)  
	
	player.note_hit.connect(_on_player_hit)
	player.lane_pressed_changed.connect(_on_lane_pressed_changed) 

	_find_ui_elements()
	var playfield_root := get_node_or_null("Playfield") as Control
	if playfield_root:
		playfield_root.resized.connect(_on_playfield_resized)
	_instantiate_debug_menu()
	_load_lane_colors()
	_load_note_colors()
	
	speed = SettingsManager.get_scroll_speed()
	
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
	
	start_countdown()
	restart_timer = Timer.new()
	restart_timer.one_shot = true
	restart_timer.wait_time = 1.5  
	restart_timer.timeout.connect(_on_restart_confirmed)
	add_child(restart_timer)

	call_deferred("_update_lane_layout")

func _on_playfield_resized():
	call_deferred("_update_lane_layout")

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
	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 18
	p.lifetime = 0.45
	p.direction = Vector2(0, -1)
	p.spread = 120.0
	p.gravity = Vector2(0, 700)
	p.initial_velocity_min = 200.0
	p.initial_velocity_max = 420.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.damping_min = 40.0
	p.damping_max = 80.0
	var col := base_color
	if perfect:
		col = base_color.lerp(Color.WHITE, 0.5)
	p.color = col
	var lane_w := get_lane_width_at(lane)
	var lane_x := get_lane_left_x(lane)
	p.position = Vector2(lane_x + lane_w * 0.5, float(hit_zone_y))
	notes_container.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)

func _pulse_hit_zone(strong: bool):
	var hit_zone = get_node_or_null("Playfield/HitZone") as ColorRect
	if not hit_zone:
		return
	var original_color = hit_zone.color
	hit_zone.color = Color(1, 1, 1, 1) if strong else Color(0.95, 0.95, 0.95, 1)
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = 0.08
	t.timeout.connect(func():
		if is_instance_valid(hit_zone):
			hit_zone.color = original_color
		if is_instance_valid(t):
			t.queue_free()
	)
	add_child(t)
	t.start()
	
func set_autoplay_enabled(enabled: bool):
	auto_play_enabled = enabled
	_reset_autoplay_state()
	
func is_autoplay_enabled() -> bool:
	return auto_play_enabled

func get_song_time() -> float:
	if MusicManager.is_music_playing() and MusicManager.current_game_music_file != "":
		return MusicManager.get_game_music_position_precise() - AudioServer.get_output_latency()
	return game_time

func get_note_pixels_per_sec() -> float:
	return speed * (1.0 / GAME_UPDATE_DELTA)

func _hit_time_for_judgement() -> float:
	var user_off_sec := 0.0
	if SettingsManager and SettingsManager.has_method("get_timing_offset_ms"):
		user_off_sec = float(SettingsManager.get_timing_offset_ms()) / 1000.0
	return get_song_time() + user_off_sec

func _autoplay_force_perfect() -> bool:
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
		ap_line = "autoplay: avg по линии (без offset)\n"
		var avg_v := _timing_debug_mean_visual_ms()
		var last_v := _timing_debug_last_visual_ms()
		ap_line += "avg(линия): %.1f мс  посл.: %.1f мс\n" % [avg_v, last_v]
	lbl.text = (
		"Тайминг [отладка]\n"
		+ "Задержка вывода: %.1f мс\n" % lat_ms
		+ "music − game_time: %.1f мс\n" % drift_ms
		+ "avg(hit−note): %.1f мс (n=%d)\n" % [avg, n]
		+ "последн.: %.1f мс\n" % last
		+ ap_line
		+ "<0 раньше чарта, >0 позже\n"
		+ "hit−note = с учётом offset в настройках"
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
	if game_time < 0.0:
		return
	if not MusicManager.is_music_playing():
		return
	if MusicManager.current_game_music_file == "":
		return
	var target = MusicManager.get_game_music_position()
	var drift = target - game_time
	if abs(drift) > AUDIO_SYNC_DRIFT_THRESHOLD_SEC:
		game_time = target

func _autoplay_line_tolerance_px() -> float:
	return maxf(AUTOPLAY_LINE_TOLERANCE_MIN_PX, speed * 1.8)

func _autoplay_note_at_hit_line(note) -> bool:
	return absf(float(note.y) - float(hit_zone_y)) <= _autoplay_line_tolerance_px()

func _autoplay_chart_now() -> float:
	return get_song_time()

func _autoplay_now() -> float:
	return _hit_time_for_judgement()

func _auto_play_simulate():
	if pauser and pauser.is_paused:
		return
	if not notes_loaded:
		return

	var chart_now := _autoplay_chart_now()
	var tick := GAME_UPDATE_DELTA
	var force_perfect := _autoplay_force_perfect()
	var late_limit := tick * 4.0 if force_perfect else HIT_WINDOW_GOOD

	var pending: Array = []
	for note in note_manager.get_notes():
		if note.is_missed:
			continue
		var lane_idx := int(note.lane)
		if lane_idx < 0 or lane_idx >= lanes:
			continue
		if note.note_kind != "HoldNote" and note.was_hit:
			continue
		if note.note_kind == "HoldNote" and note.captured:
			continue
		pending.append(note)

	pending.sort_custom(func(a, b): return float(a.time) < float(b.time))

	for note in pending:
		var lane_idx := int(note.lane)
		var note_time := float(note.time)

		if note.note_kind == "HoldNote" and note.is_being_held:
			var hold_until := note_time + float(note.duration) + 0.05
			_autoplay_press_until[lane_idx] = maxf(
				float(_autoplay_press_until.get(lane_idx, AUTOPLAY_NO_PRESS_TIME)),
				hold_until
			)
			continue

		if chart_now > note_time + late_limit:
			continue

		var ready := false
		if note.note_kind == "HoldNote":
			ready = chart_now >= note_time - tick * 0.25 and chart_now <= note_time + late_limit
		else:
			ready = _autoplay_note_at_hit_line(note)

		if not ready:
			continue

		_check_hit_for_autoplay(lane_idx, note)

		if note.note_kind == "HoldNote":
			var hold_until := note_time + float(note.duration) + 0.05
			_autoplay_press_until[lane_idx] = maxf(
				float(_autoplay_press_until.get(lane_idx, AUTOPLAY_NO_PRESS_TIME)),
				hold_until
			)
		else:
			var tap_until := chart_now + 0.08
			_autoplay_press_until[lane_idx] = maxf(
				float(_autoplay_press_until.get(lane_idx, AUTOPLAY_NO_PRESS_TIME)),
				tap_until
			)

	_autoplay_update_lane_highlights()

func _check_hit_for_autoplay(lane: int, note = null):
	if pauser.is_paused or not notes_loaded:
		return
	check_hit(lane, _autoplay_force_perfect(), note)

func _reset_autoplay_state():
	_autoplay_press_until.clear()
	if player and not player.lanes_state.is_empty():
		for i in range(player.lanes_state.size()):
			player.lanes_state[i] = false
		player.lane_pressed_changed.emit()
	for i in range(lane_highlight_nodes.size()):
		if lane_highlight_nodes[i]:
			lane_highlight_nodes[i].visible = false
 
func _autoplay_update_lane_highlights():
	if not player or player.lanes_state.is_empty():
		return
	var changed := false
	var now := _autoplay_chart_now()
	for i in range(lanes):
		var should_pressed = _autoplay_press_until.get(i, AUTOPLAY_NO_PRESS_TIME) > now
		if i < player.lanes_state.size() and player.lanes_state[i] != should_pressed:
			player.lanes_state[i] = should_pressed
			changed = true
	if changed:
		player.lane_pressed_changed.emit()
	
func _on_active_item_changed(category: String, item_id: String):
	if category == "Notes":
		_load_note_colors()
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

func _find_ui_elements():
	var ui_container_node = $UIContainer
	if ui_container_node:
		score_label = ui_container_node.get_node_or_null("StatsContainer/ScoreLabel") as Label
		combo_label = ui_container_node.get_node_or_null("TopLeftCombo/ComboLabel") as Label
		accuracy_label = ui_container_node.get_node_or_null("StatsContainer/AccuracyLabel") as Label
		judgement_label = ui_container_node.get_node_or_null("JudgementLabel") as Label
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
	var active_notes_id = PlayerDataManager.get_active_item("Notes")
	var user_path2 = "user://shop_data.json"
	var path2 = user_path2 if FileAccess.file_exists(user_path2) else "res://data/shop_data.json"
	var shop_data2: Dictionary = JsonUtils.read_json_dict(path2)
	for item in shop_data2.get("items", []):
		if item.get("item_id", "") == active_notes_id:
			var colors = item.get("note_colors", [])
			if not colors.is_empty():
				note_manager.set_note_colors(colors)
			break


func _set_lane_highlight_colors(color: Color):
	for lane_node in lane_highlight_nodes:
		if lane_node and lane_node is ColorRect:
			var b = SettingsManager.get_lane_highlight_brightness() if SettingsManager.has_method("get_lane_highlight_brightness") else 100.0
			var a = clamp(color.a * (b / 100.0), 0.0, 1.0)
			lane_node.color = Color(color.r, color.g, color.b, a)

func _on_player_hit(lane: int):
	if pauser.is_paused:
		return
	check_hit(lane)
	
func set_results_manager(results_mgr):
	results_manager = results_mgr
	
func _on_lane_pressed_changed():
	if not player:
		return
	for i in range(lane_highlight_nodes.size()):
		var hl = lane_highlight_nodes[i]
		if not hl:
			continue
		if i >= lanes or i >= player.lanes_state.size():
			hl.visible = false
		else:
			hl.visible = player.lanes_state[i]

func start_countdown():
	countdown_active = true
	input_enabled = false
	countdown_remaining = 5
	update_countdown_display()
	_update_hint()

	var scene_tree_timer = get_tree().create_timer(1.0)
	scene_tree_timer.timeout.connect(_update_countdown)
	
	countdown_timer = scene_tree_timer

	game_timer.start()

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
		start_gameplay() 
		_update_hint()
	else:
		var scene_tree_timer = get_tree().create_timer(1.0)
		scene_tree_timer.timeout.connect(_update_countdown)
		countdown_timer = scene_tree_timer

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
	_update_lane_layout()


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
	var start_x := 0.0
	var playfield_width: float = maxf(playfield.size.x, hit_zone.size.x)
	var playfield_height: float = playfield.size.y
	var lane_y: float = hit_zone.position.y
	if lanes_parent:
		lane_y = hit_zone.global_position.y - lanes_parent.global_position.y

	var lane_edges := _lane_left_edges_px(playfield_width, lanes)

	for i in range(5):
		var is_active := (i < lanes)
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

		if i < lane_highlight_nodes.size():
			var highlight_node = lane_highlight_nodes[i]
			if highlight_node:
				if is_active:
					highlight_node.position.x = x0
					highlight_node.size.x = lw
					highlight_node.position.y = 0.0
					highlight_node.size.y = playfield_height
				else:
					highlight_node.visible = false

	hit_zone_y = int(hit_zone.global_position.y - playfield.global_position.y)

	if player:
		_on_lane_pressed_changed()
	
func get_playfield_width() -> float:
	var pf = get_node_or_null("Playfield") as Control
	var hz = get_node_or_null("Playfield/HitZone") as ColorRect
	var w: float = 0.0
	if pf:
		w = pf.size.x
	if hz:
		w = maxf(w, hz.size.x)
	return w if w > 1.0 else 600.0

func get_lane_width() -> float:
	return get_playfield_width() / float(maxi(lanes, 1))


func get_lane_left_x(lane: int) -> float:
	var w: float = get_playfield_width()
	var lane_clamped: int = clampi(lane, 0, maxi(lanes, 1) - 1)
	var edges := _lane_left_edges_px(w, lanes)
	return edges[lane_clamped]


func get_lane_width_at(lane: int) -> float:
	var w: float = get_playfield_width()
	var lane_clamped: int = clampi(lane, 0, maxi(lanes, 1) - 1)
	var edges := _lane_left_edges_px(w, lanes)
	return edges[lane_clamped + 1] - edges[lane_clamped]

func get_playfield_start_x() -> float:
	return 0.0


func get_playfield_height_for_notes() -> float:
	var playfield = get_node_or_null("Playfield") as Control
	if playfield:
		return maxf(playfield.size.y, 1.0)
	return maxf(float(get_viewport_rect().size.y), 400.0)


func get_note_despawn_y() -> float:
	return get_playfield_height_for_notes() + 80.0


func _set_generation_mode(mode: String): 
	current_generation_mode = mode
	print("GameScreen.gd: Режим генерации установлен: ", mode)

func start_gameplay():
	if gameplay_started:
		return

	gameplay_started = true
	speed = SettingsManager.get_scroll_speed()
	_timing_debug_session_start_unix = int(Time.get_unix_time_from_system())
	_timing_debug_clear_ring()
	_reset_autoplay_state()

	var song_to_load = selected_song_data
	if not song_to_load or not song_to_load.get("path"):
		song_to_load = {"path": "res://songs/sample.mp3"}

	note_manager.load_notes_from_file(song_to_load, current_generation_mode, lanes)

	_update_lane_layout()

	if song_to_load and song_to_load.has("bpm"):
		var bpm_str = str(song_to_load.get("bpm", ""))
		if bpm_str != "" and bpm_str != "Н/Д" and bpm_str != "-1":
			var new_bpm = float(bpm_str)
			if new_bpm > 0:
				bpm = new_bpm

	if note_manager.get_spawn_queue_size() > 0:
		notes_loaded = true
		var total_note_count = note_manager.get_spawn_queue_size()
		score_manager.set_total_notes(total_note_count)

	var should_delay_music = false
	var earliest_note_time = note_manager.get_earliest_note_time()
	var pre_delay := 0.0
	if earliest_note_time > 0:
		var pixels_per_sec = speed * (1.0 / GAME_UPDATE_DELTA) 
		var initial_y_offset_from_top = -20.0
		var distance_to_travel = float(hit_zone_y) - initial_y_offset_from_top
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

	check_song_end_timer.start()
	_update_hint()
	_timing_debug_log_session_start(String(song_to_load.get("path", "")))

func _update_game():
	if pauser.is_paused or game_finished or countdown_active:  
		return  
	
	game_time += GAME_UPDATE_DELTA

	if pending_game_music_path != "" and game_time >= 0.0:
		var p := pending_game_music_path
		pending_game_music_path = ""
		MusicManager.play_game_music(p)

	_sync_game_time_with_game_music()

	if not countdown_active: 
		note_manager.spawn_notes() 
		_update_hint()
	
	update_ui()
	
	if rhythm_notifier:
		rhythm_notifier.bpm = bpm
		if rhythm_notifier.audio_stream_player == null:
			rhythm_notifier.current_position = MusicManager.get_current_music_position()

	note_manager.update_notes()

	if auto_play_enabled:
		_auto_play_simulate()

	_timing_debug_update_overlay()
	
	if debug_menu and debug_menu.visible and debug_menu.has_method("update_debug_info"):
		debug_menu.update_debug_info(self)

func _check_song_end():
	if pauser.is_paused or game_finished:
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

func end_game():
	if game_finished:
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
	
	MusicManager.stop_game_music()
	
	if debug_menu:
		debug_menu.auto_play_reset(self)
	auto_play_enabled = false
	
	var song_path = selected_song_data.get("path", "")
	TrackStatsManager.on_track_completed(song_path)
	
	PlayerDataManager.add_completed_level()
	if current_instrument == "drums":
		PlayerDataManager.add_drum_level_completed()
	PlayerDataManager.increment_daily_progress("levels_completed", 1, {})
	PlayerDataManager.increment_daily_progress("play_drum_level", 1, {"is_drum_mode": current_instrument == "drums"})
	
	var victory_song_info = selected_song_data.duplicate()
	victory_song_info["instrument"] = current_instrument 
	victory_song_info["mode"] = current_generation_mode
	victory_song_info["lanes"] = lanes
	var debug_score = score_manager.get_score()
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
		queue_free()

func update_ui():
	if score_label:
		var target_score = score_manager.get_score()
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
		var target_acc = score_manager.get_accuracy()
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

func update_countdown_display():
	if countdown_label: 
		countdown_label.text = str(countdown_remaining)
		countdown_label.visible = true

func _update_hint():
	if hint_label == null:
		return
	var text := ""
	if countdown_active:
		text = "Нажмите пробел, чтобы пропустить отсчёт"
	elif _skip_intro_available():
		text = "Нажмите пробел, чтобы пропустить вступление"
	elif notes_ended and not game_finished:
		text = "Нажмите пробел, чтобы перейти к результатам"
	else:
		text = ""
	hint_label.text = text
	hint_label.visible = (text != "")

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

func _input(event):
	if get_tree() and get_tree().root:
		var c = get_tree().root.get_node_or_null("Console")
		if c and c.is_visible():
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
			if event.keycode == KEY_QUOTELEFT and event.shift_pressed:
				if debug_menu and SettingsManager.get_enable_debug_menu():
					debug_menu.toggle_visibility()
				return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			if countdown_active:
				skip_countdown()
				return
		if event.keycode == KEY_ESCAPE and not countdown_active:
			if pauser.is_paused:
				pauser.handle_resume_request()
			else:
				pauser.handle_pause_request()
			return

	if not input_enabled:
		return

	if event is InputEventKey and event.pressed:
		var keycode = event.keycode
		if keycode == KEY_SPACE and not countdown_active:
			if pauser.is_paused:
				return
			if notes_ended and not game_finished:
				end_game()
				return
			if skip_intro():
				_update_hint()
				return
		if not countdown_active:
			if is_autoplay_enabled() and player and (keycode in player.keymap) and keycode != KEY_SPACE:
				return
			player.handle_key_press(keycode)

	elif event is InputEventKey and not event.pressed:
		var keycode = event.keycode
		if is_autoplay_enabled() and player and (keycode in player.keymap) and keycode != KEY_SPACE:
			return
		player.handle_key_release(keycode)
		
func skip_countdown():
	if countdown_active:
		countdown_remaining = 0
		countdown_active = false
		if countdown_label: 
			countdown_label.visible = false
		input_enabled = true
		if countdown_timer:
			pass
		start_gameplay()
		_update_hint()

func skip_intro() -> bool:
	if game_time < 0: 
		return false

	if pauser.is_paused or game_finished or countdown_active:
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
	if pauser.is_paused:
		return
	if not notes_loaded:
		return

	var current_time_adjusted = _hit_time_for_judgement()
	var hit_zone_y_float = float(hit_zone_y)
	var closest_note = null

	if autoplay_target != null:
		if autoplay_target.lane != lane or autoplay_target.was_hit or autoplay_target.is_missed:
			return
		closest_note = autoplay_target
	else:
		var candidates = []
		for note in note_manager.get_notes():
			if note.lane == lane and not note.was_hit and not note.is_missed and abs(note.y - hit_zone_y_float) < 50:
				candidates.append(note)

		if candidates.size() == 0:
			if force_perfect:
				return
			if _is_before_first_note():
				return
			_timing_debug_emit_row(lane, -1.0, -1.0, current_time_adjusted, 0.0, 0.0, "empty_zone", force_perfect)
			_combo_shake_and_dim()
			score_manager.reset_combo()
			MusicManager.play_miss_hit_sound()
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
	elif time_diff <= HIT_WINDOW_PERFECT:
		outcome = "perfect"
	elif time_diff <= HIT_WINDOW_GOOD:
		outcome = "good"

	_timing_debug_emit_row(lane, chart_json, note_time, current_time_adjusted, signed_ms, time_diff * 1000.0, outcome, force_perfect)

	if autoplay_target != null and _timing_debug_overlay_ok():
		_timing_debug_push_visual_ms((_autoplay_chart_now() - note_time) * 1000.0)

	var hit_type = "ПРОМАХ"
	var judgement_successful = false

	if force_perfect:
		score_manager.add_perfect_hit()
		hit_type = "ИДЕАЛЬНО"
		judgement_successful = true
		perfect_hits_this_level += 1
	elif time_diff <= HIT_WINDOW_PERFECT:
		score_manager.add_perfect_hit()
		hit_type = "ИДЕАЛЬНО"
		judgement_successful = true
		perfect_hits_this_level += 1
	elif time_diff <= HIT_WINDOW_GOOD:
		score_manager.add_good_hit()
		hit_type = "ХОРОШО"
		judgement_successful = true

	if judgement_successful:
		var points = closest_note.on_hit()
		if current_instrument == "drums" and hit_type == "ИДЕАЛЬНО":
			PlayerDataManager.add_total_drum_perfect_hit()
		PlayerDataManager.increment_daily_progress("hit_notes", 1, {})

		var note_type = closest_note.note_type
		var use_kick = true
		MusicManager.play_hit_sound(use_kick)

		_spawn_hit_particles(lane, closest_note.lane_palette_color, hit_type == "ИДЕАЛЬНО")

		var jcolor := judgement_color_other
		if hit_type == "ИДЕАЛЬНО":
			jcolor = judgement_color_perfect
		elif hit_type == "ХОРОШО":
			jcolor = judgement_color_good
		_show_judgement(hit_type, jcolor)

		print("[GameScreen] Игрок нажал в линии %d, попадание: %s (time_diff: %.3fs)" % [lane, hit_type, time_diff])
	else:
		closest_note.is_missed = true
		score_manager.add_miss_hit()
		MusicManager.play_miss_hit_sound()
		_combo_shake_and_dim()
		_show_judgement("ПРОМАХ", judgement_color_miss)
		print("[GameScreen] Игрок нажал в линии %d, но попадание не засчитано (time_diff: %.3fs) - сброс комбо" % [lane, time_diff])


func _process(delta):
	if not countdown_active:
		update_ui()
		
func restart_level():
	speed = SettingsManager.get_scroll_speed()

	if game_finished:
		return

	if pauser and pauser.is_paused:
		pauser.cleanup_on_game_end()

	if not check_song_end_timer.is_stopped():
		check_song_end_timer.stop()
	if victory_delay_timer and not victory_delay_timer.is_stopped():
		victory_delay_timer.stop()
	pending_game_music_path = ""

	MusicManager.stop_game_music()

	_timing_debug_clear_ring()
	_reset_autoplay_state()
	player.reset()
	score_manager.reset()
	note_manager.clear_notes()
	perfect_hits_this_level = 0
	_last_combo_value = 0
	game_time = 0.0
	game_finished = false
	notes_ended = false
	skip_used = false
	input_enabled = false
	countdown_active = true
	gameplay_started = false
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
	_show_judgement("ПРОМАХ", judgement_color_miss)

func _combo_shake_and_dim():
	if combo_label == null:
		return
	if animation_player and animation_player.has_animation("ComboMiss"):
		animation_player.stop(true)
		animation_player.play("ComboMiss")

func _open_settings_from_pause():
	pauser.cleanup_on_game_end()
	var game_engine = get_parent()
	if game_engine and game_engine.has_method("get_transitions"):
		var transitions = game_engine.get_transitions()
		if transitions:
			transitions.open_settings(true) 

func _exit_to_main_menu():
	pauser.cleanup_on_game_end() 
	var game_engine = get_parent()
	if game_engine and game_engine.has_method("get_transitions"):
		var transitions = game_engine.get_transitions()
		if transitions:
			transitions.exit_to_main_menu()

func _exit_tree() -> void:
	Engine.max_fps = original_max_fps
	DisplayServer.window_set_vsync_mode(original_vsync_mode)
 
