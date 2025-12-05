# res://scenes/game_screen/game_screen_pauser.gd
class_name GameScreenPauser
extends Node

signal resume_requested
signal song_select_requested
signal settings_requested
signal exit_to_menu_requested

var game_screen: Node2D = null
var game_timer: Timer = null
var music_manager = null
var pause_menu_instance = null

var is_paused: bool = false:
	set(value):
		is_paused = value

var original_music_volume: float = 1.0
var paused_music_position: float = 0.0

func initialize(gs, timer, mm):
	game_screen = gs
	game_timer = timer
	music_manager = mm

func handle_pause_request():
	if is_paused or game_screen.game_finished or game_screen.countdown_active:
		return
	
	is_paused = true
	
	if music_manager and music_manager.has_method("get_volume_multiplier"):
		original_music_volume = music_manager.get_volume_multiplier()
	else:
		original_music_volume = 1.0
	
	if music_manager and music_manager.has_method("set_volume_multiplier"):
		music_manager.set_volume_multiplier(0.2)
	
	if music_manager and music_manager.has_method("get_game_music_position"):
		paused_music_position = music_manager.get_game_music_position()
	else:
		paused_music_position = 0.0
	
	if music_manager and music_manager.has_method("stop_game_music"):
		music_manager.stop_game_music()
	
	if game_timer and not game_timer.is_stopped():
		game_timer.stop()
	if music_manager and music_manager.has_method("stop_metronome"):
		music_manager.stop_metronome()
	
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
	
	if music_manager and music_manager.has_method("set_volume_multiplier"):
		music_manager.set_volume_multiplier(original_music_volume)
	
	if music_manager and music_manager.has_method("play_game_music_at_position"):
		var song_path = game_screen.selected_song_data.get("path", "")
		music_manager.play_game_music_at_position(song_path, paused_music_position)
	elif music_manager and music_manager.has_method("play_game_music") and music_manager.has_method("set_music_position"):
		var song_path = game_screen.selected_song_data.get("path", "")
		music_manager.play_game_music(song_path)
		await get_tree().process_frame
		music_manager.set_music_position(paused_music_position)
	else:
		push_error("GameScreenPauser.gd: MusicManager не имеет метода play_game_music_at_position или play_game_music/set_music_position. Музыка не запущена.")
	
	if game_timer:
		game_timer.start()
	if music_manager and music_manager.has_method("start_metronome"):
		music_manager.start_metronome(game_screen.bpm, game_screen.game_time)
	
	game_screen.input_enabled = true
	
	if pause_menu_instance and is_instance_valid(pause_menu_instance):
		pause_menu_instance.queue_free()
		pause_menu_instance = null

func cleanup_on_game_end():
	if is_paused and pause_menu_instance and is_instance_valid(pause_menu_instance):
		pause_menu_instance.queue_free()
		pause_menu_instance = null
	is_paused = false
	original_music_volume = 1.0
	paused_music_position = 0.0

func _on_resume_requested():
	emit_signal("resume_requested")
	handle_resume_request()

func _on_song_select_requested():
	emit_signal("song_select_requested")

func _on_settings_requested():
	emit_signal("settings_requested")

func _on_exit_to_menu_requested():
	emit_signal("exit_to_menu_requested")
