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
	# Упрощённый print
	var msg = "GameScreenPauser.gd: Инициализирован для GameScreen: " + str(game_screen)
	print(msg)

func handle_pause_request():
	if is_paused or game_screen.game_finished or game_screen.countdown_active:
		return
	
	# Упрощённый print
	var msg = "GameScreenPauser.gd: Игра поставлена на паузу."
	print(msg)
	is_paused = true
	
	# --- ИЗМЕНЕНО: Сохраняем и меняем громкость ---
	if music_manager and music_manager.has_method("get_volume_multiplier"):
		original_music_volume = music_manager.get_volume_multiplier()
		# Упрощённый print
		var msg_vol = "GameScreenPauser.gd: Сохранена громкость музыки: " + str(original_music_volume)
		print(msg_vol)
	else:
		original_music_volume = 1.0
		# Упрощённый printerr
		var msg_err = "GameScreenPauser.gd: MusicManager не имеет метода get_volume_multiplier. Используем 1.0."
		printerr(msg_err)
	
	if music_manager and music_manager.has_method("set_volume_multiplier"):
		music_manager.set_volume_multiplier(0.2)
		# Упрощённый print
		var msg_set = "GameScreenPauser.gd: Громкость музыки при паузе установлена на 0.2."
		print(msg_set)
	else:
		# Упрощённый printerr
		var msg_err2 = "GameScreenPauser.gd: MusicManager не имеет метода set_volume_multiplier. Громкость музыки не изменена при паузе."
		printerr(msg_err2)
	# --- /ИЗМЕНЕНО ---
	
	# --- ИЗМЕНЕНО: Сохраняем позицию и останавливаем ТОЛЬКО ИГРОВУЮ музыку ---
	if music_manager and music_manager.has_method("get_game_music_position"):
		paused_music_position = music_manager.get_game_music_position()
		# Упрощённый print
		var msg_pos = "GameScreenPauser.gd: Сохранена позиция игровой музыки: " + str(paused_music_position)
		print(msg_pos)
	else:
		paused_music_position = 0.0
		# Упрощённый printerr
		var msg_err3 = "GameScreenPauser.gd: MusicManager не имеет метода get_game_music_position. Позиция музыки установлена в 0.0 при паузе."
		printerr(msg_err3)
	
	if music_manager and music_manager.has_method("stop_game_music"):
		music_manager.stop_game_music()
		# Упрощённый print
		var msg_stop = "GameScreenPauser.gd: Игровая музыка остановлена при паузе."
		print(msg_stop)
	else:
		# Упрощённый printerr
		var msg_err4 = "GameScreenPauser.gd: MusicManager не имеет метода stop_game_music. Музыка не остановлена при паузе."
		printerr(msg_err4)
	# --- /ИЗМЕНЕНО ---
	
	# Останавливаем таймеры
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
					# Упрощённый print
					var msg_trans = "GameScreenPauser.gd: Transitions передан в PauseMenu."
					print(msg_trans)
				else:
					# Упрощённый printerr
					var msg_err5 = "GameScreenPauser.gd: Не удалось передать Transitions в PauseMenu."
					printerr(msg_err5)
			else:
				# Упрощённый printerr
				var msg_err6 = "GameScreenPauser.gd: Не удалось получить Transitions из GameEngine."
				printerr(msg_err6)
			
			if pause_menu_instance.has_signal("resume_requested"):
				pause_menu_instance.resume_requested.connect(_on_resume_requested)
			if pause_menu_instance.has_signal("song_select_requested"):
				pause_menu_instance.song_select_requested.connect(_on_song_select_requested)
			if pause_menu_instance.has_signal("settings_requested"):
				pause_menu_instance.settings_requested.connect(_on_settings_requested)
			if pause_menu_instance.has_signal("exit_to_menu_requested"):
				pause_menu_instance.exit_to_menu_requested.connect(_on_exit_to_menu_requested)
			
			game_screen.add_child(pause_menu_instance)
			# Упрощённый print
			var msg_add = "GameScreenPauser.gd: Меню паузы добавлено."
			print(msg_add)
		else:
			# Упрощённый printerr
			var msg_err7 = "GameScreenPauser.gd: Не удалось загрузить сцену pause_menu.tscn!"
			printerr(msg_err7)
	else:
		# Упрощённый printerr
		var msg_err8 = "GameScreenPauser.gd: pause_menu_instance уже существует!"
		printerr(msg_err8)

func handle_resume_request():
	if not is_paused:
		return
	
	# Упрощённый print
	var msg_res = "GameScreenPauser.gd: Игра возобновлена."
	print(msg_res)
	is_paused = false
	
	# --- ИЗМЕНЕНО: Восстанавливаем громкость ---
	if music_manager and music_manager.has_method("set_volume_multiplier"):
		music_manager.set_volume_multiplier(original_music_volume)
		# Упрощённый print
		var msg_restore = "GameScreenPauser.gd: Громкость музыки восстановлена до: " + str(original_music_volume)
		print(msg_restore)
	else:
		# Упрощённый printerr
		var msg_err9 = "GameScreenPauser.gd: MusicManager не имеет метода set_volume_multiplier. Громкость музыки не восстановлена."
		printerr(msg_err9)
	# --- /ИЗМЕНЕНО ---
	
	# --- ИЗМЕНЕНО: Возобновляем ТОЛЬКО ИГРОВУЮ музыку с сохранённой позиции ---
	if music_manager and music_manager.has_method("play_game_music_at_position"):
		var song_path = game_screen.selected_song_data.get("path", "")
		music_manager.play_game_music_at_position(song_path, paused_music_position)
		# Упрощённый print
		var msg_resume = "GameScreenPauser.gd: Игровая музыка возобновлена с позиции: " + str(paused_music_position)
		print(msg_resume)
	elif music_manager and music_manager.has_method("play_game_music") and music_manager.has_method("set_music_position"):
		var song_path = game_screen.selected_song_data.get("path", "")
		music_manager.play_game_music(song_path)
		await get_tree().process_frame
		music_manager.set_music_position(paused_music_position)
		# Упрощённый print
		var msg_seek = "GameScreenPauser.gd: Игровая музыка запущена и установлена на позицию: " + str(paused_music_position)
		print(msg_seek)
	else:
		# Упрощённый printerr
		var msg_err10 = "GameScreenPauser.gd: MusicManager не имеет метода play_game_music_at_position или play_game_music/set_music_position. Музыка не запущена."
		printerr(msg_err10)
	# --- /ИЗМЕНЕНО ---
	
	# Возобновляем таймеры
	if game_timer:
		game_timer.start()
	if music_manager and music_manager.has_method("start_metronome"):
		music_manager.start_metronome(game_screen.bpm, game_screen.game_time)
	
	game_screen.input_enabled = true
	
	if pause_menu_instance and is_instance_valid(pause_menu_instance):
		pause_menu_instance.queue_free()
		pause_menu_instance = null
		# Упрощённый print
		var msg_rm = "GameScreenPauser.gd: Меню паузы удалено."
		print(msg_rm)

func cleanup_on_game_end():
	if is_paused and pause_menu_instance and is_instance_valid(pause_menu_instance):
		pause_menu_instance.queue_free()
		pause_menu_instance = null
		# Упрощённый print
		var msg_clean = "GameScreenPauser.gd: Меню паузы убрано перед завершением игры."
		print(msg_clean)
	is_paused = false
	original_music_volume = 1.0
	paused_music_position = 0.0
	# Упрощённый print
	var msg_reset = "GameScreenPauser.gd: Состояние очищено после завершения игры."
	print(msg_reset)

func _on_resume_requested():
	emit_signal("resume_requested")
	handle_resume_request()

func _on_song_select_requested():
	emit_signal("song_select_requested")

func _on_settings_requested():
	emit_signal("settings_requested")

func _on_exit_to_menu_requested():
	emit_signal("exit_to_menu_requested")
