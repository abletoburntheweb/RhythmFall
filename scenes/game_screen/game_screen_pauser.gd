# res://scenes/game_screen/game_screen_pauser.gd
class_name GameScreenPauser
extends Node

signal resume_requested
signal restart_requested 
signal song_select_requested
signal settings_requested
signal exit_to_menu_requested

var game_screen: Node2D = null
var game_timer: Timer = null

var pause_menu_instance = null

var is_paused: bool = false:
	set(value):
		is_paused = value

var original_music_volume: float = 1.0
var paused_music_position: float = 0.0

func initialize(gs, timer):
	game_screen = gs
	game_timer = timer

func handle_pause_request():
	if is_paused or game_screen.game_finished or game_screen.countdown_active:
		return
	
	is_paused = true
	
	original_music_volume = MusicManager.get_volume_multiplier()
	
	MusicManager.set_music_volume_multiplier(0.2)
	
	paused_music_position = MusicManager.get_game_music_position()
	MusicManager.stop_game_music()
		
	if game_timer and not game_timer.is_stopped():
		game_timer.stop()
	
	if game_screen.delayed_music_timer \
	and is_instance_valid(game_screen.delayed_music_timer) \
	and not game_screen.delayed_music_timer.is_stopped():
		game_screen.delayed_music_timer.stop()
	
	game_screen.input_enabled = false
	
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
			
			game_screen.add_child(pause_menu_instance)
		else:
			push_error("GameScreenPauser.gd: Не удалось загрузить сцену pause_menu.tscn!")
	else:
		push_error("GameScreenPauser.gd: pause_menu_instance уже существует!")

func handle_resume_request():
	if not is_paused:
		return
	
	is_paused = false
	
	MusicManager.set_music_volume_multiplier(original_music_volume)

	if game_screen.delayed_music_timer \
	and is_instance_valid(game_screen.delayed_music_timer) \
	and game_screen.delayed_music_timer.is_stopped():
		game_screen.delayed_music_timer.start()
	else:
		var song_path = game_screen.selected_song_data.get("path", "")
		if MusicManager.has_method("play_game_music_at_position"):
			MusicManager.play_game_music_at_position(song_path, paused_music_position)
		else:
			MusicManager.play_game_music(song_path)
			await get_tree().process_frame
			MusicManager.set_music_position(paused_music_position)
	
	if game_timer:
		game_timer.start()
	
	var metronome_volume = SettingsManager.get_metronome_volume()
	MusicManager.set_metronome_volume(metronome_volume)
	
	game_screen.input_enabled = true
	
	if pause_menu_instance and is_instance_valid(pause_menu_instance):
		pause_menu_instance.queue_free()
		pause_menu_instance = null

func cleanup_on_game_end():
	if is_paused and pause_menu_instance and is_instance_valid(pause_menu_instance):
		pause_menu_instance.queue_free()
		pause_menu_instance = null
	
	if game_screen.delayed_music_timer and is_instance_valid(game_screen.delayed_music_timer):
		game_screen.delayed_music_timer.queue_free()
		game_screen.delayed_music_timer = null
	
	is_paused = false
	original_music_volume = 1.0
	paused_music_position = 0.0

func _on_resume_requested():
	emit_signal("resume_requested")
	handle_resume_request()
	
func _on_restart_requested():
	emit_signal("restart_requested")
	
	if is_paused:
		handle_resume_request() 
	
	MusicManager.play_restart_sound()
	
	if game_screen and game_screen.has_method("restart_level"):
		game_screen.restart_level()
	else:
		push_error("GameScreenPauser.gd: game_screen не имеет метода restart_level")
		
func _on_song_select_requested():
	emit_signal("song_select_requested")

func _on_settings_requested():
	emit_signal("settings_requested")

func _on_exit_to_menu_requested():
	emit_signal("exit_to_menu_requested")
