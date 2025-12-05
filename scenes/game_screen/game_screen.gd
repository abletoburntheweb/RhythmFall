# scenes/game_screen/game_screen.gd
extends Node2D

const ScoreManager = preload("res://logic/score_manager.gd")
const NoteManager = preload("res://logic/note_manager.gd")
const Player = preload("res://logic/player.gd")
const SoundInstrumentFactory = preload("res://logic/sound_instrument_factory.gd")
const AutoPlayer = preload("res://scenes/debug_menu/bot.gd")

var pauser: GameScreenPauser = null

var game_time: float = 0.0
var countdown_remaining: int = 5
var countdown_active: bool = true
var game_finished: bool = false
var input_enabled: bool = false

var bpm: float = 120.0
var speed: float = 6.0
var hit_zone_y: int = 900
var lanes: int = 4
var current_instrument: String = "standard"

var selected_song_data: Dictionary = {}

var score_manager
var note_manager
var player

var game_engine

var music_manager = null
var sound_factory = null

var score_label: Label = null
var combo_label: Label = null
var max_combo_label: Label = null
var bpm_label: Label = null
var speed_label: Label = null
var time_label: Label = null
var accuracy_label: Label = null
var instrument_label: Label = null
var countdown_label: Label = null
var notes_container: Node2D = null

var game_timer: Timer
var countdown_timer
var check_song_end_timer: Timer

var notes_loaded: bool = false
var skip_used = false
var skip_time_threshold = 10.0
var skip_rewind_seconds = 5.0

var lane_highlight_nodes: Array[ColorRect] = []

var debug_menu: DebugMenu = null

var auto_player = null

var perfect_hits_this_level: int = 0

var results_manager = null

func _ready():
	game_engine = get_parent()
	
	if game_engine and game_engine.has_method("get_music_manager"):
		music_manager = game_engine.get_music_manager()
	
	var settings_for_player = {}
	if game_engine and game_engine.has_method("get_settings_manager"):
		var settings_manager = game_engine.get_settings_manager()
		if settings_manager:
			settings_for_player = settings_manager.settings.duplicate(true)

	score_manager = ScoreManager.new(self)
	note_manager = NoteManager.new(self)
	player = Player.new(settings_for_player)  
	sound_factory = SoundInstrumentFactory.new(music_manager)
	
	player.note_hit.connect(_on_player_hit)
	player.lane_pressed_changed.connect(_on_lane_pressed_changed) 

	_find_ui_elements()
	_instantiate_debug_menu()

	auto_player = AutoPlayer.new(self)
	print("GameScreen: AutoPlayer создан.")

	game_timer = Timer.new()
	game_timer.wait_time = 0.016 
	game_timer.timeout.connect(_update_game)
	add_child(game_timer)
	
	check_song_end_timer = Timer.new()
	check_song_end_timer.wait_time = 0.1
	check_song_end_timer.timeout.connect(_check_song_end)
	add_child(check_song_end_timer)
	
	pauser = GameScreenPauser.new()
	pauser.initialize(self, game_timer, music_manager)
	add_child(pauser)
	pauser.song_select_requested.connect(_exit_to_song_select)
	pauser.settings_requested.connect(_open_settings_from_pause)
	pauser.exit_to_menu_requested.connect(_exit_to_main_menu)
	
	set_process_input(true)
	
	start_countdown()

func _instantiate_debug_menu():
	var debug_menu_scene = preload("res://scenes/debug_menu/debug_menu.tscn")
	if debug_menu_scene:
		var new_debug_menu = debug_menu_scene.instantiate() as DebugMenu
		if new_debug_menu:
			add_child(new_debug_menu)
			debug_menu = new_debug_menu

func _find_ui_elements():
	var ui_container_node = $UIContainer
	if ui_container_node:
		score_label = ui_container_node.get_node_or_null("ScoreLabel") as Label
		combo_label = ui_container_node.get_node_or_null("ComboLabel") as Label
		max_combo_label = ui_container_node.get_node_or_null("MaxComboLabel") as Label
		bpm_label = ui_container_node.get_node_or_null("BpmLabel") as Label
		speed_label = ui_container_node.get_node_or_null("SpeedLabel") as Label
		time_label = ui_container_node.get_node_or_null("TimeLabel") as Label
		accuracy_label = ui_container_node.get_node_or_null("AccuracyLabel") as Label
		instrument_label = ui_container_node.get_node_or_null("InstrumentLabel") as Label

	countdown_label = get_node_or_null("CountdownLabel") as Label
	notes_container = get_node_or_null("NotesContainer") as Node2D

	var lanes_container_node = get_node_or_null("LanesContainer")
	if lanes_container_node:
		lane_highlight_nodes = [
			lanes_container_node.get_node_or_null("Lane0Highlight") as ColorRect,
			lanes_container_node.get_node_or_null("Lane1Highlight") as ColorRect,
			lanes_container_node.get_node_or_null("Lane2Highlight") as ColorRect,
			lanes_container_node.get_node_or_null("Lane3Highlight") as ColorRect
		]

func _on_player_hit(lane: int):
	if pauser.is_paused:
		return
	check_hit(lane)
	
func set_results_manager(results_mgr):
	results_manager = results_mgr
	print("GameScreen.gd: ResultsManager установлен.")
	
func _on_lane_pressed_changed():
	for i in range(lanes):
		if i < lane_highlight_nodes.size() and i < player.lanes_state.size():
			var is_pressed = player.lanes_state[i]
			if lane_highlight_nodes[i]:
				lane_highlight_nodes[i].visible = is_pressed

func start_countdown():
	countdown_active = true
	input_enabled = false
	countdown_remaining = 5
	update_countdown_display()

	var scene_tree_timer = get_tree().create_timer(1.0)
	scene_tree_timer.timeout.connect(_update_countdown)
	
	countdown_timer = scene_tree_timer

	game_timer.start()

func _update_countdown():
	countdown_remaining -= 1
	update_countdown_display()
	
	if countdown_remaining <= 0:
		countdown_active = false
		if countdown_label: 
			countdown_label.visible = false
		input_enabled = true  
		start_gameplay() 
	else:
		var scene_tree_timer = get_tree().create_timer(1.0)
		scene_tree_timer.timeout.connect(_update_countdown)
		countdown_timer = scene_tree_timer

func _set_selected_song(song_data: Dictionary):
	selected_song_data = song_data.duplicate() 

func _set_instrument(instrument_type: String):
	current_instrument = instrument_type
	if instrument_label: 
		instrument_label.text = "Инструмент: " + ("Перкуссия" if instrument_type == "drums" else "Стандартный")

func start_gameplay():
	game_time = 0.0
	
	if music_manager and selected_song_data and selected_song_data.get("path"):
		var song_path = selected_song_data.get("path")
		if music_manager.has_method("play_game_music"):
			music_manager.play_game_music(song_path)

	var song_to_load = selected_song_data
	if not song_to_load or not song_to_load.get("path"):
		song_to_load = {"path": "res://songs/sample.mp3"}

	note_manager.load_notes_from_file(song_to_load)

	if song_to_load and song_to_load.has("bpm"):
		var bpm_str = str(song_to_load.get("bpm", ""))
		if bpm_str != "" and bpm_str != "Н/Д" and bpm_str != "-1":
			var new_bpm = float(bpm_str)
			if new_bpm > 0:
				bpm = new_bpm
				update_speed_from_bpm() 
	
	if note_manager.get_spawn_queue_size() > 0:
		notes_loaded = true
		var total_note_count = note_manager.get_spawn_queue_size()
		score_manager.set_total_notes(total_note_count)
		print("GameScreen.gd: Установлено total_notes: %d" % total_note_count)
	
	if music_manager and music_manager.has_method("start_metronome"):
		music_manager.start_metronome(bpm, 0) 
	
	check_song_end_timer.start()

func update_speed_from_bpm():
	var base_bpm = 120.0
	var base_speed = 6.0
	speed = base_speed * (bpm / base_bpm)
	speed = clamp(speed, 2.0, 12.0)

func _update_game():
	if pauser.is_paused or game_finished or countdown_active:
		if pauser.is_paused and music_manager and music_manager.has_method("stop_metronome"):
			music_manager.stop_metronome()
		return
	
	if not pauser.is_paused and not music_manager.is_metronome_active() and music_manager and music_manager.has_method("start_metronome"):
		music_manager.start_metronome(bpm, 0)
	
	game_time += 0.016  
	
	if not countdown_active:
		note_manager.spawn_notes()
	
	update_ui()
	
	if auto_player:
		auto_player.simulate()
	
	if debug_menu and debug_menu.visible and debug_menu.has_method("update_debug_info"):
		debug_menu.update_debug_info(self)
	
	note_manager.update_notes()

func _check_song_end():
	if pauser.is_paused or game_finished:
		return
	
	if selected_song_data and selected_song_data.has("duration"):
		var duration_value = selected_song_data.get("duration", 0.0)
		if typeof(duration_value) == TYPE_FLOAT and duration_value > 0:
			var duration = duration_value
			if game_time >= duration - 0.1:
				end_game()
				return
	
	if music_manager and music_manager.has_method("is_game_music_playing"):
		if not music_manager.is_game_music_playing():
			end_game()

func end_game():
	if game_finished:
		return
	
	if pauser.is_paused:
		print("GameScreen.gd: end_game вызвано во время паузы, вызываем cleanup.")
		pauser.cleanup_on_game_end()
		return
	
	print("GameScreen: Игра завершена, подготовка к переходу к VictoryScreen...")
	game_finished = true
	
	if not game_timer.is_stopped():
		game_timer.stop()
	if not check_song_end_timer.is_stopped():
		check_song_end_timer.stop()
	
	if music_manager:
		if music_manager.has_method("stop_music"):
			music_manager.stop_music()            
			print("GameScreen.gd: ВСЯ музыка (включая игровую) остановлена в end_game через stop_music.")
		else:
			if music_manager.has_method("stop_game_music"):
				music_manager.stop_game_music()
				print("GameScreen.gd: Игровая музыка остановлена в end_game через stop_game_music.")
			else:
				printerr("GameScreen.gd: Ни stop_music, ни stop_game_music не найдены в MusicManager!")
		if music_manager.has_method("stop_metronome"):
			music_manager.stop_metronome()
			print("GameScreen.gd: Метроном остановлен в end_game.")
	
	if auto_player:
		auto_player.reset()
	
	var accuracy = score_manager.get_accuracy()
	var is_drum_mode = (current_instrument == "drums")
	
	var achievement_system = null
	if game_engine and game_engine.has_method("get_achievement_system"):
		achievement_system = game_engine.get_achievement_system()
	
	if achievement_system:
		print("🎯 Вызываем ачивки за уровень через AchievementSystem...")
		achievement_system.on_level_completed(accuracy, is_drum_mode)
	else:
		printerr("GameScreen.gd: AchievementSystem не найден через GameEngine!")
	
	var victory_scene = preload("res://scenes/victory_screen/victory_screen.tscn")
	if victory_scene:
		var new_victory_screen = victory_scene.instantiate()
		
		var victory_song_info = selected_song_data.duplicate()
		victory_song_info["instrument"] = current_instrument 
		var debug_score = score_manager.get_score()
		var debug_combo = score_manager.get_combo()
		var debug_max_combo = score_manager.get_max_combo()
		var debug_accuracy = score_manager.get_accuracy()
		var debug_perfect_hits = perfect_hits_this_level
		print("GameScreen: Отправляем в VictoryScreen - Счёт=%d, Комбо=%d, Макс.комбо=%d, Точность=%.1f%%, Совершенных попаданий=%d" % [
			debug_score,
			debug_combo,
			debug_max_combo,
			debug_accuracy,
			debug_perfect_hits
		])
		
		new_victory_screen.set_victory_data(
			debug_score,      
			debug_combo,    
			debug_max_combo,  
			debug_accuracy,  
			victory_song_info,
			score_manager.get_combo_multiplier(), 
			note_manager.get_spawn_queue_size(), 
			score_manager.get_missed_notes_count(), 
			debug_perfect_hits 
		)
		
		if new_victory_screen.has_method("set_results_manager") and results_manager:
			new_victory_screen.set_results_manager(results_manager)
			print("GameScreen.gd: ResultsManager передан в VictoryScreen.")
		elif results_manager:
			printerr("GameScreen.gd: VictoryScreen не имеет метода set_results_manager, но ResultsManager передан.")
		
		var parent_node = get_parent()
		if parent_node:
			parent_node.remove_child(self)
			parent_node.add_child(new_victory_screen)
			queue_free()

func update_ui():
	if score_label:
		score_label.text = "Счёт: %d" % score_manager.get_score()
	if combo_label:
		combo_label.text = "Комбо: %d (x%.1f)" % [score_manager.get_combo(), score_manager.get_combo_multiplier()]
	if max_combo_label:
		max_combo_label.text = "Макс. комбо: %d" % score_manager.get_max_combo()
	if bpm_label:
		if notes_loaded:
			bpm_label.text = "BPM: %.1f" % bpm
		else:
			bpm_label.text = "BPM: Н/Д"
	if speed_label:
		if notes_loaded:
			speed_label.text = "Скорость: %.2f" % speed
		else:
			speed_label.text = "Скорость: Н/Д"
	if time_label:
		time_label.text = "Время: %.3fс" % game_time
	if accuracy_label:
		accuracy_label.text = "Точность: %.2f%%" % score_manager.get_accuracy()
	if instrument_label:
		instrument_label.text = "Инструмент: " + ("Перкуссия" if current_instrument == "drums" else "Стандартный")

func update_countdown_display():
	if countdown_label: 
		countdown_label.text = str(countdown_remaining)
		countdown_label.visible = true

func _input(event):
	if event is InputEventKey and event.pressed:
		var keycode = event.keycode
		var shift_pressed = Input.is_key_pressed(KEY_SHIFT) 

		if keycode == KEY_QUOTELEFT and shift_pressed:
			if debug_menu:
				var settings_manager = game_engine.get_settings_manager() if game_engine else null
				if settings_manager and settings_manager.get_enable_debug_menu():
					debug_menu.toggle_visibility()
				else:
					print("DebugMenu: Отключено в настройках")
			return		
			
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if countdown_active:
			skip_countdown()
			return
	
	if not input_enabled: 
		return
	
	if event is InputEventKey and event.pressed:
		var keycode = event.keycode
		
		if keycode == KEY_ESCAPE and not countdown_active:
			if pauser.is_paused:
				pauser.handle_resume_request()
			else:
				pauser.handle_pause_request()
			return 
		
		elif keycode == KEY_SPACE and not countdown_active:
			if skip_intro():
				return
		
		if not countdown_active:
			player.handle_key_press(keycode)
	
	elif event is InputEventKey and not event.pressed: 
		var keycode = event.keycode
		player.handle_key_release(keycode)
		
func skip_countdown():
	if countdown_active:
		if countdown_timer:
			countdown_remaining = 0
			_update_countdown()
		print("Обратный отсчет пропущен")

func skip_intro() -> bool:
	if pauser.is_paused or game_finished or countdown_active:
		return false
	if skip_used:
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

	if music_manager and music_manager.has_method("set_music_position"):
		music_manager.set_music_position(target_time)
	note_manager.skip_notes_before_time(target_time) 

	skip_used = true
	return true

func check_hit(lane: int):
	if pauser.is_paused:
		return
	if notes_loaded:
		var hit_occurred = false
		var current_time = game_time

		for note in note_manager.get_notes():
			if note.lane == lane and abs(note.y - hit_zone_y) < 30:
				var points = note.on_hit()
				score_manager.add_perfect_hit()
				
				if current_instrument == "drums":
					var player_data_manager = null
					if game_engine and game_engine.has_method("get_player_data_manager"):
						player_data_manager = game_engine.get_player_data_manager()
					
					if player_data_manager:
						player_data_manager.update_drum_perfect_hits_streak(true)
						var is_snare_note = (note.note_type == "SnareNote") 
						player_data_manager.update_snare_streak(is_snare_note)
						player_data_manager.add_total_drum_perfect_hit()
						
				if sound_factory and music_manager:
					var note_type = note.note_type 
					var sound_path = sound_factory.get_sound_path_for_note(note_type, current_instrument)
					
					music_manager.play_custom_hit_sound(sound_path) 
				hit_occurred = true
				perfect_hits_this_level += 1
				break 
	else:
		score_manager.add_perfect_hit()
		perfect_hits_this_level += 1

func _process(delta):
	if not countdown_active:
		update_ui()

func _exit_to_song_select():
	pauser.cleanup_on_game_end()
	var game_engine = get_parent()
	if game_engine and game_engine.has_method("get_transitions"):
		var transitions = game_engine.get_transitions()
		if transitions:
			transitions.open_song_select()

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
