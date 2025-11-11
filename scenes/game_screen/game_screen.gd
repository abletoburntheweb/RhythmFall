# scenes/game_screen/game_screen.gd
extends Node2D

const ScoreManager = preload("res://logic/score_manager.gd")
const NoteManager = preload("res://logic/note_manager.gd")
const Player = preload("res://logic/player.gd")
const SoundInstrumentFactory = preload("res://logic/sound_instrument_factory.gd")

var game_time: float = 0.0
var countdown_remaining: int = 5
var countdown_active: bool = true
var is_paused: bool = false
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

@onready var score_label: Label = $UIContainer/ScoreLabel
@onready var combo_label: Label = $UIContainer/ComboLabel
@onready var max_combo_label: Label = $UIContainer/MaxComboLabel
@onready var bpm_label: Label = $UIContainer/BpmLabel
@onready var speed_label: Label = $UIContainer/SpeedLabel
@onready var time_label: Label = $UIContainer/TimeLabel
@onready var accuracy_label: Label = $UIContainer/AccuracyLabel
@onready var instrument_label: Label = $UIContainer/InstrumentLabel
@onready var countdown_label: Label = $CountdownLabel
@onready var notes_container: Node2D = $NotesContainer

var game_timer: Timer
var countdown_timer

var notes_loaded: bool = false
var skip_used = false
var skip_time_threshold = 10.0
var skip_rewind_seconds = 5.0

@onready var lane_highlight_nodes: Array[ColorRect] = [$LanesContainer/Lane0Highlight, $LanesContainer/Lane1Highlight, $LanesContainer/Lane2Highlight, $LanesContainer/Lane3Highlight]

func _ready():
	print("GameScreen: _ready вызван")

	game_engine = get_parent()
	
	if game_engine and game_engine.has_method("get_music_manager"):
		music_manager = game_engine.get_music_manager()
		if music_manager:
			print("GameScreen: MusicManager получен.")
		else:
			print("GameScreen: MusicManager не получен из game_engine (null).")
	else:
		print("GameScreen: game_engine не имеет метода get_music_manager.")

	var settings_for_player = {}
	if game_engine and game_engine.has_method("get_settings_manager"):
		var settings_manager = game_engine.get_settings_manager()
		if settings_manager:
			settings_for_player = settings_manager.settings.duplicate(true)
			print("GameScreen: Настройки получены из SettingsManager: ", settings_for_player)
		else:
			print("GameScreen: SettingsManager не получен из game_engine (null).")
	else:
		print("GameScreen: game_engine не имеет метода get_settings_manager.")
		
	score_manager = ScoreManager.new(self)
	note_manager = NoteManager.new(self)
	player = Player.new(settings_for_player)  
	sound_factory = SoundInstrumentFactory.new(music_manager)
	
	player.note_hit.connect(_on_player_hit)
	player.lane_pressed_changed.connect(_on_lane_pressed_changed) 

	game_timer = Timer.new()
	game_timer.wait_time = 0.016 
	game_timer.timeout.connect(_update_game)
	add_child(game_timer)
	
	start_countdown()
	
	set_process_input(true)

func _on_player_hit(lane: int):
	if is_paused:
		return
	print("Player hit detected in lane: %d" % lane)
	check_hit(lane)

func _on_lane_pressed_changed():
	for i in range(lanes):
		if i < lane_highlight_nodes.size() and i < player.lanes_state.size():
			var is_pressed = player.lanes_state[i]
			lane_highlight_nodes[i].visible = is_pressed  
		else:
			printerr("GameScreen: Индекс линии выходит за пределы массивов при обновлении подсветки!")

func start_countdown():
	print("GameScreen: Start countdown called")
	countdown_active = true
	input_enabled = false
	countdown_remaining = 5
	update_countdown_display()

	var scene_tree_timer = get_tree().create_timer(1.0)
	scene_tree_timer.timeout.connect(_update_countdown)
	
	countdown_timer = scene_tree_timer

	game_timer.start()
	print("GameScreen: Timers started")

func _update_countdown():
	print("GameScreen: _update_countdown called, remaining: %d" % countdown_remaining)
	countdown_remaining -= 1
	update_countdown_display()
	
	if countdown_remaining <= 0:
		countdown_active = false
		if countdown_label: 
			countdown_label.visible = false
		input_enabled = true  
		print("GameScreen: Countdown finished, input enabled")
		start_gameplay() 
	else:
		var scene_tree_timer = get_tree().create_timer(1.0)
		scene_tree_timer.timeout.connect(_update_countdown)
		countdown_timer = scene_tree_timer

func _set_selected_song(song_data: Dictionary):
	print("GameScreen: Получена информация о песне: ", song_data)
	selected_song_data = song_data.duplicate() 

func _set_instrument(instrument_type: String):
	print("GameScreen: Установлен инструмент: ", instrument_type)
	current_instrument = instrument_type
	if instrument_label: 
		instrument_label.text = "Инструмент: " + ("Перкуссия" if instrument_type == "drums" else "Стандартный")
	else:
		printerr("GameScreen.gd: instrument_label не найден (null), невозможно обновить текст!")


func start_gameplay():
	print("GameScreen: Game started")
	game_time = 0.0
	
	if music_manager and selected_song_data and selected_song_data.get("path"):
		var song_path = selected_song_data.get("path")
		print("GameScreen: Пытаемся запустить музыку: ", song_path)
		if music_manager.has_method("play_game_music"):
			music_manager.play_game_music(song_path)
		else:
			printerr("GameScreen: MusicManager не имеет метода play_game_music!")
	else:
		print("GameScreen: MusicManager или selected_song_data.path не доступны для воспроизведения музыки.")

	var song_to_load = selected_song_data
	if not song_to_load or not song_to_load.get("path"):
		song_to_load = {"path": "res://songs/sample.mp3"}
		print("GameScreen: Песня не передана, используем заглушку: res://songs/sample.mp3")

	note_manager.load_notes_from_file(song_to_load)

	if song_to_load and song_to_load.has("bpm"):
		var bpm_str = str(song_to_load.get("bpm", ""))
		if bpm_str != "" and bpm_str != "Н/Д" and bpm_str != "-1":
			var new_bpm = float(bpm_str)
			if new_bpm > 0:
				bpm = new_bpm
				update_speed_from_bpm() 
				print("GameScreen: BPM обновлён из данных песни: ", bpm)
	
	
	if note_manager.get_spawn_queue_size() > 0:
		notes_loaded = true
		score_manager.set_total_notes(note_manager.get_spawn_queue_size())
		print("GameScreen: Ноты загружены, всего: %d" % note_manager.get_spawn_queue_size())

	else:
		notes_loaded = false
		print("GameScreen: Ноты не найдены, запуск без нот")
	
	if music_manager and music_manager.has_method("start_metronome"):
		music_manager.start_metronome(bpm, 0) 
		print("GameScreen: Метроном запущен с BPM: ", bpm)
	else:
		print("GameScreen: MusicManager не имеет метода start_metronome или не установлен.")
		
func update_speed_from_bpm():
	var base_bpm = 120.0
	var base_speed = 6.0
	speed = base_speed * (bpm / base_bpm)
	speed = clamp(speed, 2.0, 12.0)
	print("GameScreen: Скорость обновлена: BPM=%.1f, Speed=%.2f" % [bpm, speed])

func _update_game():
	if is_paused or game_finished or countdown_active:
		if is_paused and music_manager and music_manager.has_method("stop_metronome"):
			music_manager.stop_metronome()
			print("GameScreen: Метроном остановлен (пауза).")
		return
	
	if not is_paused and not music_manager.is_metronome_active() and music_manager and music_manager.has_method("start_metronome"):
		music_manager.start_metronome(bpm, 0)
		print("GameScreen: Метроном возобновлен (снятие с паузы).")
	
	game_time += 0.016  
	
	if not countdown_active:
		note_manager.spawn_notes()
	
	update_ui()
	
	note_manager.update_notes()

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
	if not input_enabled: 
		return
	
	if event is InputEventKey and event.pressed:
		var keycode = event.keycode
		
		if keycode == KEY_ESCAPE and not countdown_active:
			return
		elif keycode == KEY_SPACE and not countdown_active:
			if skip_intro():
				return
		
		if not countdown_active:
			print("GameScreen: Key press handled by player: %d" % keycode)
			player.handle_key_press(keycode)
	
	elif event is InputEventKey and not event.pressed: 
		var keycode = event.keycode
		print("GameScreen: Key release handled by player: %d" % keycode)
		player.handle_key_release(keycode)

func skip_intro() -> bool:
	if is_paused or game_finished or countdown_active:
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
	print("[GameScreen] Пропуск вступления. Текущее время: %.2f, первая нота: %.2f, перемотка к: %.2f" % [game_time, first_note_time, target_time])

	game_time = target_time

	if music_manager and music_manager.has_method("set_music_position"):
		music_manager.set_music_position(target_time)
		print("[GameScreen] Позиция аудио установлена на %.2fс" % target_time)
	else:
		printerr("[GameScreen] MusicManager не имеет метода set_music_position или не установлен.")

	note_manager.skip_notes_before_time(target_time) 

	skip_used = true
	return true


func check_hit(lane: int):
	if notes_loaded:
		var hit_occurred = false
		var current_time = game_time

		for note in note_manager.get_notes():
			if note.lane == lane and abs(note.y - hit_zone_y) < 30:
				score_manager.add_perfect_hit()
				
				if sound_factory and music_manager:
					var note_type = note.note_type 
					var sound_path = sound_factory.get_sound_path_for_note(note_type, current_instrument)
					
					music_manager.play_custom_hit_sound(sound_path) 
				else:
					printerr("GameScreen: sound_factory или music_manager не установлены для проигрывания звука хита.")
				
				note.active = false 
				print("PERFECT HIT lane %d | Combo: %d" % [lane, score_manager.get_combo()])
				hit_occurred = true
				break 

		if not hit_occurred:
			score_manager.reset_combo() 
			print("MISSED HIT lane %d | Combo сброшен" % lane)
	else:
		score_manager.add_perfect_hit()
		print("TEST HIT in lane %d (no notes loaded)" % lane)

func _process(delta):
	if not countdown_active:
		update_ui()
