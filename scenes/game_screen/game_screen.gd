# scenes/game_screen/game_screen.gd
extends Node2D

const ScoreManager = preload("res://logic/score_manager.gd")
const NoteManager = preload("res://logic/note_manager.gd")
const Player = preload("res://logic/player.gd")

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

var score_manager
var note_manager
var player

var game_engine

@onready var score_label: Label = $UIContainer/ScoreLabel
@onready var combo_label: Label = $UIContainer/ComboLabel
@onready var max_combo_label: Label = $UIContainer/MaxComboLabel
@onready var bpm_label: Label = $UIContainer/BpmLabel
@onready var speed_label: Label = $UIContainer/SpeedLabel
@onready var time_label: Label = $UIContainer/TimeLabel
@onready var accuracy_label: Label = $UIContainer/AccuracyLabel
@onready var instrument_label: Label = $UIContainer/InstrumentLabel
@onready var countdown_label: Label = $CountdownLabel

var game_timer: Timer
var countdown_timer

var notes_loaded: bool = false

@onready var lane_highlight_nodes: Array[ColorRect] = [$LanesContainer/Lane0Highlight, $LanesContainer/Lane1Highlight, $LanesContainer/Lane2Highlight, $LanesContainer/Lane3Highlight]

func _ready():
	print("GameScreen: _ready вызван")

	game_engine = get_parent()
	
	var settings_for_player = {}
	if game_engine and "settings" in game_engine:
		var game_settings = game_engine.settings
		if game_settings is Dictionary:
			settings_for_player = game_settings
		else:
			print("GameScreen: game_engine.settings не является Dictionary, используем пустой словарь")

	score_manager = ScoreManager.new(self)
	note_manager = NoteManager.new(self)
	player = Player.new(settings_for_player)  

	player.note_hit.connect(_on_player_hit)
	player.lane_pressed_changed.connect(_on_lane_pressed_changed) 

	game_timer = Timer.new()
	game_timer.wait_time = 0.016  # ~60 FPS
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

func start_gameplay():
	print("GameScreen: Game started")
	game_time = 0.0
	var dummy_song_data = {"path": "res://songs/sample.mp3"}  
	note_manager.load_notes_from_file(dummy_song_data)
	
	if note_manager.get_spawn_queue_size() > 0:
		notes_loaded = true
		score_manager.set_total_notes(note_manager.get_spawn_queue_size())
		print("GameScreen: Ноты загружены, всего: %d" % note_manager.get_spawn_queue_size())

	else:
		notes_loaded = false
		print("GameScreen: Ноты не найдены, запуск без нот")

func _update_game():
	if is_paused or game_finished or countdown_active:
		return
	
	game_time += 0.016  # 16ms per frame
	
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
		instrument_label.text = "Инструмент: стандарт"

func update_countdown_display():
	if countdown_label: 
		countdown_label.text = str(countdown_remaining)
		countdown_label.visible = true

func _input(event):
	if not input_enabled: 
		print("GameScreen: Input blocked during countdown")
		return
	
	if event is InputEventKey:
		print("GameScreen: InputEventKey detected, pressed=%s, keycode=%d" % [event.pressed, event.keycode])
		
		if event.pressed:
			if event.keycode == KEY_ESCAPE and not countdown_active:
				pass
			elif event.keycode == KEY_SPACE and not countdown_active:
				pass
			else:
				print("GameScreen: Key press handled by player: %d" % event.keycode)
				player.handle_key_press(event.keycode)
		else:
			print("GameScreen: Key release handled by player: %d" % event.keycode)
			player.handle_key_release(event.keycode)

func check_hit(lane: int):
	if notes_loaded:
		var hit_occurred = false
		var current_time = game_time

		for note in note_manager.get_notes():
			if note.lane == lane and abs(note.y - hit_zone_y) < 30:
				score_manager.add_perfect_hit()
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
