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

func initialize(gs, timer, mm):
	game_screen = gs
	game_timer = timer
	music_manager = mm
	print("GameScreenPauser.gd: Инициализирован для GameScreen: ", game_screen)

func handle_pause_request():
	if is_paused or game_screen.game_finished or game_screen.countdown_active:
		return
	
	print("GameScreenPauser.gd: Игра поставлена на паузу.")
	is_paused = true
	
	if game_timer and not game_timer.is_stopped():
		game_timer.stop()
	if music_manager and music_manager.has_method("stop_metronome"):
		music_manager.stop_metronome()
	
	if music_manager and music_manager.has_method("pause_game_music"):
		music_manager.pause_game_music()
	elif music_manager and music_manager.has_method("set_volume_multiplier"):
		music_manager.set_volume_multiplier(0.2)

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
					print("GameScreenPauser.gd: Transitions передан в PauseMenu.")
				else:
					printerr("GameScreenPauser.gd: Не удалось передать Transitions в PauseMenu.")
			else:
				printerr("GameScreenPauser.gd: Не удалось получить Transitions из GameEngine.")
			
			if pause_menu_instance.has_signal("resume_requested"):
				pause_menu_instance.resume_requested.connect(_on_resume_requested)
			if pause_menu_instance.has_signal("song_select_requested"):
				pause_menu_instance.song_select_requested.connect(_on_song_select_requested)
			if pause_menu_instance.has_signal("settings_requested"):
				pause_menu_instance.settings_requested.connect(_on_settings_requested)
			if pause_menu_instance.has_signal("exit_to_menu_requested"):
				pause_menu_instance.exit_to_menu_requested.connect(_on_exit_to_menu_requested)
			
			game_screen.add_child(pause_menu_instance)
			print("GameScreenPauser.gd: Меню паузы добавлено.")
		else:
			printerr("GameScreenPauser.gd: Не удалось загрузить сцену pause_menu.tscn!")
	else:
		printerr("GameScreenPauser.gd: pause_menu_instance уже существует!")

func handle_resume_request():
	if not is_paused:
		return
	
	print("GameScreenPauser.gd: Игра возобновлена.")
	is_paused = false
	
	if game_timer:
		game_timer.start()
	if music_manager and music_manager.has_method("start_metronome"):
		music_manager.start_metronome(game_screen.bpm, game_screen.game_time)
	
	if music_manager and music_manager.has_method("resume_game_music"):
		music_manager.resume_game_music()
	elif music_manager and music_manager.has_method("set_volume_multiplier"):
		music_manager.set_volume_multiplier(1.0)

	game_screen.input_enabled = true
	
	if pause_menu_instance and is_instance_valid(pause_menu_instance):
		pause_menu_instance.queue_free()
		pause_menu_instance = null
		print("GameScreenPauser.gd: Меню паузы удалено.")

func cleanup_on_game_end():
	if is_paused and pause_menu_instance and is_instance_valid(pause_menu_instance):
		pause_menu_instance.queue_free()
		pause_menu_instance = null
		print("GameScreenPauser.gd: Меню паузы убрано перед завершением игры.")
	is_paused = false

func _on_resume_requested():
	emit_signal("resume_requested")
	handle_resume_request()

func _on_song_select_requested():
	emit_signal("song_select_requested")

func _on_settings_requested():
	emit_signal("settings_requested")

func _on_exit_to_menu_requested():
	emit_signal("exit_to_menu_requested")
