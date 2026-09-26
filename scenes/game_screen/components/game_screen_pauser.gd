# scenes/game_screen/components/game_screen_pauser.gd
class_name GameScreenPauser
extends Node

signal resume_requested
signal restart_requested 
signal practice_restart_requested
signal song_select_requested
signal settings_requested
signal exit_to_menu_requested
signal pause_menu_shown
signal pause_menu_hidden

var game_screen: Node = null
var game_timer: Timer = null
var pause_menu_instance = null

var is_paused: bool = false:
	set(value):
		is_paused = value

var original_music_volume: float = 1.0
var original_hit_volume: float = -1.0
var paused_music_position: float = 0.0
var paused_song_time: float = 0.0

func initialize(gs, timer):
	game_screen = gs
	game_timer = timer

func handle_pause_request():
	if is_paused or game_screen.game_finished or game_screen.countdown_active:
		return
	if game_screen.has_method("is_resume_rewind_active") and game_screen.is_resume_rewind_active():
		return
	
	is_paused = true
	
	original_music_volume = MusicManager.get_volume_multiplier()
	# Replay Hit volume must be preserved separately — global SettingsManager would otherwise overwrite it on resume.
	if game_screen and game_screen.has_method("_replay_watch_active") and game_screen._replay_watch_active():
		original_hit_volume = float(game_screen.get("_replay_player_hit_volume")) if game_screen.get("_replay_player_hit_volume") != null else -1.0
		if original_hit_volume < 0.0 and MusicManager and MusicManager.has_method("get_hit_sounds_volume"):
			# Fallback: try to read from MusicManager hit player
			original_hit_volume = 0.5
	else:
		original_hit_volume = -1.0
	
	MusicManager.set_music_volume_multiplier(0.2)
	
	paused_song_time = float(game_screen.game_time)
	paused_music_position = MusicManager.get_game_music_position_precise()
	if paused_music_position <= 0.0:
		paused_music_position = MusicManager.get_game_music_position()
	if paused_music_position <= 0.0:
		paused_music_position = paused_song_time
	MusicManager.force_stop_game_track() if MusicManager.has_method("force_stop_game_track") else MusicManager.stop_game_music()
		
	if game_timer and not game_timer.is_stopped():
		game_timer.stop()
	
	if game_screen.victory_delay_timer \
	and is_instance_valid(game_screen.victory_delay_timer) \
	and not game_screen.victory_delay_timer.is_stopped():
		game_screen.victory_delay_timer.stop()
	
	if game_screen.restart_timer \
	and is_instance_valid(game_screen.restart_timer) \
	and not game_screen.restart_timer.is_stopped():
		game_screen.restart_timer.stop()
		game_screen.is_restart_held = false
	
	game_screen.input_enabled = false
	if game_screen.has_method("set_pause_playfield_overlay_hidden"):
		game_screen.set_pause_playfield_overlay_hidden(true)
	if game_screen.has_method("_sync_health_bar_visibility"):
		game_screen._sync_health_bar_visibility()
	
	if not pause_menu_instance:
		var pause_menu_scene = load("res://scenes/pause_menu/pause_menu.tscn")
		if pause_menu_scene:
			pause_menu_instance = pause_menu_scene.instantiate()
			
			var game_engine = game_screen.get_parent()
			if game_engine and game_engine.has_method("get_transitions"):
				var transitions = game_engine.get_transitions()
				if transitions and pause_menu_instance.has_method("set_transitions"):
					pause_menu_instance.set_transitions(transitions)
				else:
					push_error("GameScreenPauser.gd: Не удалось передать Transitions в PauseMenu.")
			else:
				push_error("GameScreenPauser.gd: Не удалось получить Transitions из GameEngine.")
			
			if pause_menu_instance.has_signal("resume_requested"):
				pause_menu_instance.resume_requested.connect(_on_resume_requested)
			if pause_menu_instance.has_signal("restart_requested"):
				pause_menu_instance.restart_requested.connect(_on_restart_requested)
			if pause_menu_instance.has_signal("song_select_requested"):
				pause_menu_instance.song_select_requested.connect(_on_song_select_requested)
			if pause_menu_instance.has_signal("settings_requested"):
				pause_menu_instance.settings_requested.connect(_on_settings_requested)
			if pause_menu_instance.has_signal("exit_to_menu_requested"):
				pause_menu_instance.exit_to_menu_requested.connect(_on_exit_to_menu_requested)
			if pause_menu_instance.has_signal("end_series_requested"):
				pause_menu_instance.end_series_requested.connect(_on_end_series_requested)
			if pause_menu_instance.has_signal("practice_requested"):
				pause_menu_instance.practice_requested.connect(_on_practice_requested)
			if pause_menu_instance.has_signal("practice_restart_requested"):
				pause_menu_instance.practice_restart_requested.connect(_on_practice_restart_requested)
			
			pause_menu_instance.z_index = 100
			game_screen.add_child(pause_menu_instance)
		else:
			push_error("GameScreenPauser.gd: Не удалось загрузить сцену pause_menu.tscn!")
	else:
		pause_menu_instance.z_index = 100
		pause_menu_instance.visible = true
	if game_screen and game_screen.has_method("configure_pause_menu_for_mode"):
		game_screen.configure_pause_menu_for_mode(pause_menu_instance)
	pause_menu_shown.emit()

func handle_resume_request():
	if not is_paused:
		return
	# Resume from the CHART time captured at pause, not from the (latency-ahead)
	# music playhead. This keeps the note positions exactly where they were;
	# using max(playhead, chart_time) and then clamping to 0 made pre-roll pauses
	# jump the chart forward as if the pre-roll had already elapsed.
	var from_time := paused_song_time
	var restore_volume := original_music_volume
	if pause_menu_instance and is_instance_valid(pause_menu_instance):
		if pause_menu_instance.has_method("stop_practice_preview"):
			pause_menu_instance.stop_practice_preview()
		pause_menu_instance.queue_free()
		pause_menu_instance = null
	pause_menu_hidden.emit()
	# Clear pause before async rewind so a failed start cannot softlock the run.
	is_paused = false
	# Still in the negative pre-roll window: restore the exact chart position
	# (nothing to rewind yet) and let the pending music start when the clock
	# crosses 0, so approaching notes never teleport forward.
	if from_time < 0.0:
		_resume_immediate(from_time, restore_volume)
		return
	if SettingsManager and not SettingsManager.get_pause_resume_rewind_enabled():
		_resume_immediate(from_time, restore_volume)
		return
	if game_screen and game_screen.has_method("begin_resume_rewind"):
		game_screen.begin_resume_rewind(from_time, restore_volume, "pause")
		return
	_resume_immediate(from_time, restore_volume)

func _resume_immediate(from_time: float, restore_volume: float) -> void:
	if game_screen:
		game_screen.speed = game_screen._effective_scroll_speed() if game_screen.has_method("_effective_scroll_speed") else SettingsManager.get_scroll_speed()
		# Keep chart clock exactly at the pause position. Do NOT clamp to 0:
		# a negative from_time means the run was paused inside pre-roll, and
		# clamping would cut the pre-roll short and make notes teleport forward.
		var _old_gt_res2: float = float(game_screen.game_time)
		game_screen.game_time = from_time
		if game_screen.has_method("_game_trace_time_set"):
			game_screen._game_trace_time_set("RESUME2", _old_gt_res2, from_time)
	if game_screen and game_screen.pending_game_music_path != "":
		pass
	elif game_screen:
		var song_path = game_screen.selected_song_data.get("path", "")
		if MusicManager.has_method("play_game_music_at_position"):
			MusicManager.play_game_music_at_position(song_path, from_time)
		else:
			MusicManager.play_game_music(song_path)
			await get_tree().process_frame
			MusicManager.set_music_position(from_time)
	# Replay panel volume is authoritative — apply AFTER play_game_music_at_position (which resets to global music volume)
	if game_screen and game_screen._replay_watch_active():
		game_screen._replay_player_apply_volume()
		if original_hit_volume >= 0.0:
			game_screen._replay_player_apply_hit_volume()
		else:
			game_screen._replay_player_apply_hit_volume()
	else:
		MusicManager.set_music_volume_multiplier(restore_volume)
		if original_hit_volume >= 0.0 and MusicManager.has_method("set_hit_sounds_volume"):
			MusicManager.set_hit_sounds_volume(original_hit_volume * 100.0)
	if game_screen and game_screen.has_method("_apply_run_modifier_runtime"):
		game_screen._apply_run_modifier_runtime()
	if game_timer:
		game_timer.start()
	if game_screen:
		game_screen.input_enabled = true
		if game_screen.has_method("set_pause_playfield_overlay_hidden"):
			game_screen.set_pause_playfield_overlay_hidden(false)
		if game_screen.has_method("_sync_health_bar_visibility"):
			game_screen._sync_health_bar_visibility()

func hide_pause_menu_for_settings() -> void:
	if pause_menu_instance and is_instance_valid(pause_menu_instance):
		pause_menu_instance.visible = false


func show_pause_menu_after_settings() -> void:
	if not is_paused:
		return
	if pause_menu_instance and is_instance_valid(pause_menu_instance):
		pause_menu_instance.z_index = 100
		pause_menu_instance.visible = true


func cleanup_on_game_end():
	if is_paused and pause_menu_instance and is_instance_valid(pause_menu_instance):
		if pause_menu_instance.has_method("stop_practice_preview"):
			pause_menu_instance.stop_practice_preview()
		pause_menu_instance.queue_free()
		pause_menu_instance = null
	
	if game_screen:
		game_screen.pending_game_music_path = ""

	is_paused = false
	original_music_volume = 1.0
	paused_music_position = 0.0
	paused_song_time = 0.0

func _on_resume_requested():
	emit_signal("resume_requested")
	handle_resume_request()
	
func _on_restart_requested():
	emit_signal("restart_requested")
	if is_paused:
		_dismiss_pause_menu_only()
	MusicManager.play_restart_sound()
	if game_screen and game_screen.has_method("restart_level"):
		game_screen.restart_level()
	else:
		push_error("GameScreenPauser.gd: game_screen не имеет метода restart_level")


func _dismiss_pause_menu_only() -> void:
	is_paused = false
	if pause_menu_instance and is_instance_valid(pause_menu_instance):
		if pause_menu_instance.has_method("stop_practice_preview"):
			pause_menu_instance.stop_practice_preview()
		pause_menu_instance.queue_free()
		pause_menu_instance = null
	MusicManager.set_music_volume_multiplier(original_music_volume)
	if game_screen:
		game_screen.input_enabled = true
		if game_screen.has_method("set_pause_playfield_overlay_hidden"):
			game_screen.set_pause_playfield_overlay_hidden(false)
		if game_screen.has_method("_sync_health_bar_visibility"):
			game_screen._sync_health_bar_visibility()
		
func _on_song_select_requested():
	emit_signal("song_select_requested")

func _on_settings_requested():
	emit_signal("settings_requested")

func _on_exit_to_menu_requested():
	emit_signal("exit_to_menu_requested")


func _on_end_series_requested():
	if game_screen and game_screen.has_method("request_series_exit_after_track"):
		game_screen.request_series_exit_after_track()
		return
	if game_screen and game_screen.has_method("abandon_series_and_show_summary"):
		game_screen.abandon_series_and_show_summary()


func _on_practice_requested(start_idx: int, end_idx: int) -> void:
	if game_screen and game_screen.has_method("start_practice"):
		game_screen.start_practice(start_idx, end_idx)


## Restart from the pause while a Practice run is active: dismiss the pause and
## ask game_screen to replay the same range (reset attempt, pre-roll, session
## stats/Attempts/Best untouched) instead of restarting the whole song.
func _on_practice_restart_requested():
	emit_signal("practice_restart_requested")
	if is_paused:
		_dismiss_pause_menu_only()
	MusicManager.play_restart_sound()
	if game_screen and game_screen.has_method("restart_practice_run"):
		game_screen.restart_practice_run()
	else:
		push_error("GameScreenPauser.gd: game_screen не имеет метода restart_practice_run")
