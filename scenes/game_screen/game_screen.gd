# scenes/game_screen/game_screen.gd
extends Node2D

const ScoreManager = preload("res://logic/score_manager.gd")
const NoteManager = preload("res://logic/note_manager.gd")
const Player = preload("res://logic/player.gd")
const SoundInstrumentFactory = preload("res://logic/sound_instrument_factory.gd")
const AutoPlayer = preload("res://scenes/debug_menu/bot.gd")
const GAME_UPDATE_DELTA = 1.0 / 60.0

var original_vsync_mode: int = DisplayServer.VSYNC_ADAPTIVE
var original_max_fps: int = 0
var pauser: GameScreenPauser = null

var game_time: float = 0.0
var countdown_remaining: int = 5
var countdown_active: bool = true
var delayed_music_timer: Timer = null
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
var judgement_label: Label = null
var progress_bar: ProgressBar = null

var game_timer: Timer
var countdown_timer
var check_song_end_timer: Timer

var notes_loaded: bool = false
var skip_used = false
var skip_time_threshold = 10.0
var skip_rewind_seconds = 5.0

var lane_highlight_nodes: Array[ColorRect] = []
var lane_nodes: Array[ColorRect] = []

var debug_menu: DebugMenu = null

var auto_player = null

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

const HIT_WINDOW_PERFECT: float = 0.05
const HIT_WINDOW_GOOD: float = 0.15


func _ready():
	game_engine = get_parent()
	
	var transitions = null
	if game_engine and game_engine.has_method("get_transitions"):
		transitions = game_engine.get_transitions()

	original_max_fps = Engine.max_fps
	original_vsync_mode = DisplayServer.window_get_vsync_mode()

	Engine.max_fps = 60
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)

	var settings_for_player = SettingsManager.settings.duplicate(true)

	score_manager = ScoreManager.new(self)
	note_manager = NoteManager.new(self)
	player = Player.new(settings_for_player, lanes)  
	sound_factory = SoundInstrumentFactory.new()
	
	player.note_hit.connect(_on_player_hit)
	player.lane_pressed_changed.connect(_on_lane_pressed_changed) 

	_find_ui_elements()
	_instantiate_debug_menu()
	_load_lane_colors()
	
	_update_active_sounds_from_player_data()
	PlayerDataManager.active_item_changed.connect(_on_active_item_changed)

	auto_player = AutoPlayer.new(self)

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
	
func _on_active_item_changed(category: String, item_id: String):
	if category == "Kick" or category == "Snare":
		var shop_data_file = FileAccess.open("res://data/shop_data.json", FileAccess.READ)
		if shop_data_file:
			var shop_data = JSON.parse_string(shop_data_file.get_as_text())
			shop_data_file.close()
			
			for item in shop_data.get("items", []):
				if item.get("item_id", "") == item_id:
					var audio_path = item.get("audio", "")
					if audio_path:
						if category == "Kick":
							MusicManager.set_active_kick_sound(audio_path)
						elif category == "Snare":
							MusicManager.set_active_snare_sound(audio_path)
					break

func _update_active_sounds_from_player_data():
	var active_kick_id = PlayerDataManager.get_active_item("Kick")
	var active_snare_id = PlayerDataManager.get_active_item("Snare")

	var shop_data_file = FileAccess.open("res://data/shop_data.json", FileAccess.READ)
	if shop_data_file:
		var shop_data = JSON.parse_string(shop_data_file.get_as_text())
		shop_data_file.close()
		
		for item in shop_data.get("items", []):
			if item.get("item_id", "") == active_kick_id:
				var audio_path = item.get("audio", "")
				if audio_path:
					MusicManager.set_active_kick_sound(audio_path)
				break
		
		for item in shop_data.get("items", []):
			if item.get("item_id", "") == active_snare_id:
				var audio_path = item.get("audio", "")
				if audio_path:
					MusicManager.set_active_snare_sound(audio_path)
				break

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
		score_label = ui_container_node.get_node_or_null("StatsContainer/ScoreLabel") as Label
		combo_label = ui_container_node.get_node_or_null("StatsContainer/ComboLabel") as Label
		max_combo_label = ui_container_node.get_node_or_null("StatsContainer/MaxComboLabel") as Label
		bpm_label = ui_container_node.get_node_or_null("StatsContainer/BpmLabel") as Label
		speed_label = ui_container_node.get_node_or_null("StatsContainer/SpeedLabel") as Label
		time_label = ui_container_node.get_node_or_null("StatsContainer/TimeLabel") as Label
		accuracy_label = ui_container_node.get_node_or_null("StatsContainer/AccuracyLabel") as Label
		instrument_label = ui_container_node.get_node_or_null("StatsContainer/InstrumentLabel") as Label
		judgement_label = ui_container_node.get_node_or_null("JudgementLabel") as Label

		var progress_container = ui_container_node.get_node_or_null("SongProgressContainer")
		if progress_container:
			progress_bar = progress_container.get_node_or_null("SongProgressBar") as ProgressBar

	countdown_label = get_node_or_null("CountdownLabel") as Label
	notes_container = get_node_or_null("NotesContainer") as Node2D

	var lanes_container_node = get_node_or_null("LanesContainer")
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
	var shop_data_file = FileAccess.open("res://data/shop_data.json", FileAccess.READ)
	if shop_data_file:
		var shop_data = JSON.parse_string(shop_data_file.get_as_text())
		shop_data_file.close()
		
		for item in shop_data.get("items", []):
			if item.get("item_id", "") == active_lane_highlight_id:
				var color_hex = item.get("color_hex", "#fec6e580")
				var lane_highlight_color = Color(color_hex)
				_set_lane_highlight_colors(lane_highlight_color)
				break
	else:
		var default_color = Color("#fec6e580")
		_set_lane_highlight_colors(default_color)


func _set_lane_highlight_colors(color: Color):
	for lane_node in lane_highlight_nodes:
		if lane_node and lane_node is ColorRect:
			lane_node.color = color

func _on_player_hit(lane: int):
	if pauser.is_paused:
		return
	check_hit(lane)
	
func set_results_manager(results_mgr):
	results_manager = results_mgr
	
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
	if not countdown_active:
		return
	
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
		
func _set_lanes(lane_count: int):
	lanes = clamp(lane_count, 3, 5)
	print("GameScreen.gd: Установлено количество линий: ", lanes)
	_update_lane_layout()

func _update_lane_layout():
	var screen_width = DisplayServer.screen_get_size().x  
	var lane_width = screen_width / lanes

	for i in range(5): 
		var is_active = (i < lanes)

		if i < lane_nodes.size():
			var lane_node = lane_nodes[i]
			if lane_node:
				lane_node.visible = is_active
				if is_active:
					lane_node.position.x = i * lane_width
					lane_node.size.x = lane_width

		if i < lane_highlight_nodes.size():
			var highlight_node = lane_highlight_nodes[i]
			if highlight_node:
				highlight_node.visible = false
				if is_active:
					highlight_node.position.x = i * lane_width
					highlight_node.size.x = lane_width

	var hit_zone = get_node_or_null("HitZone")
	if hit_zone:
		hit_zone.size.x = screen_width
	
func _set_generation_mode(mode: String): 
	current_generation_mode = mode
	print("GameScreen.gd: Режим генерации установлен: ", mode)

func start_gameplay():
	if gameplay_started:
		return

	gameplay_started = true

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
				update_speed_from_bpm()

	if note_manager.get_spawn_queue_size() > 0:
		notes_loaded = true
		var total_note_count = note_manager.get_spawn_queue_size()
		score_manager.set_total_notes(total_note_count)

	var should_delay_music = false
	var earliest_note_time = note_manager.get_earliest_note_time()
	if earliest_note_time > 0 and earliest_note_time <= EARLY_NOTE_THRESHOLD:
		should_delay_music = true

	if should_delay_music:
		game_time = -MUSIC_START_DELAY_IF_EARLY_NOTES
	else:
		game_time = 0.0

	MusicManager.set_external_metronome_control(true)
	MusicManager.play_level_start_sound()
	
	var metronome_volume = SettingsManager.get_metronome_volume()
	MusicManager.set_metronome_volume(metronome_volume)
	
	var song_path = selected_song_data.get("path", "")

	if should_delay_music:
		if delayed_music_timer and is_instance_valid(delayed_music_timer):
			delayed_music_timer.queue_free()
			delayed_music_timer = null

		delayed_music_timer = Timer.new()
		delayed_music_timer.name = "DelayedMusicTimer"
		delayed_music_timer.wait_time = MUSIC_START_DELAY_IF_EARLY_NOTES
		delayed_music_timer.one_shot = true

		delayed_music_timer.timeout.connect(func():
			game_time = 0.0
			MusicManager.play_game_music(song_path)
			if is_instance_valid(delayed_music_timer) and delayed_music_timer.get_parent() == self:
				delayed_music_timer.queue_free()
				delayed_music_timer = null
		)

		add_child(delayed_music_timer)
		delayed_music_timer.start()
	else:
		MusicManager.play_game_music(song_path)

	check_song_end_timer.start()

func update_speed_from_bpm():
	var base_bpm = 120.0
	var base_speed = 6.0
	speed = base_speed * (bpm / base_bpm)
	speed = clamp(speed, 2.0, 12.0)

func _update_game():
	if pauser.is_paused or game_finished or countdown_active:  
		return  
	
	game_time += GAME_UPDATE_DELTA 
	
	if not countdown_active: 
		note_manager.spawn_notes() 
	
	update_ui()
	
	if auto_player:
		auto_player.simulate()
	
	if debug_menu and debug_menu.visible and debug_menu.has_method("update_debug_info"):
		debug_menu.update_debug_info(self)
	
	note_manager.update_notes()
	
	if not pauser.is_paused:
		MusicManager.update_metronome(GAME_UPDATE_DELTA, game_time, bpm)  

func _check_song_end():
	if pauser.is_paused or game_finished or notes_ended:
		return

	var spawn_queue_empty = note_manager.get_spawn_queue_size() == 0
	var active_notes_empty = note_manager.get_notes().size() == 0

	if spawn_queue_empty and active_notes_empty:
		notes_ended = true 
		victory_delay_timer.start(VICTORY_DELAY_AFTER_NOTES) 
		return

	if selected_song_data and selected_song_data.has("duration"):
		var duration_value = selected_song_data.get("duration", 0.0)
		if typeof(duration_value) == TYPE_FLOAT and duration_value > 0:
			var duration = duration_value
			if game_time >= duration - 0.1:
				end_game()
				return

func _on_victory_delay_timeout():
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
	MusicManager.stop_metronome()
	
	if auto_player:
		auto_player.reset()
	
	var song_path = selected_song_data.get("path", "")
	TrackStatsManager.on_track_completed(song_path)
	
	PlayerDataManager.add_completed_level()
	if current_instrument == "drums":
		PlayerDataManager.add_drum_level_completed()
	
	var victory_song_info = selected_song_data.duplicate()
	victory_song_info["instrument"] = current_instrument 
	var debug_score = score_manager.get_score()
	var debug_combo = score_manager.get_combo()
	var debug_max_combo = score_manager.get_max_combo()
	var debug_accuracy = score_manager.get_accuracy()
	var debug_perfect_hits = perfect_hits_this_level
	var debug_missed_notes = score_manager.get_missed_notes_count()
	var debug_hit_notes = score_manager.get_hit_notes_count()

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

func _input(event):
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
		countdown_remaining = 0
		countdown_active = false
		if countdown_label: 
			countdown_label.visible = false
		input_enabled = true
		if countdown_timer:
			pass
		start_gameplay()

func skip_intro() -> bool:
	if game_time < 0: 
		return false

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

	MusicManager.set_music_position(target_time)
	note_manager.skip_notes_before_time(target_time) 

	skip_used = true
	return true

func check_hit(lane: int):
	if pauser.is_paused:
		return
	if not notes_loaded:
		return

	var current_time = game_time
	var hit_zone_y_float = float(hit_zone_y)
	var candidates = []

	for note in note_manager.get_notes():
		if note.lane == lane and abs(note.y - hit_zone_y_float) < 50:
			candidates.append(note)

	if candidates.size() == 0:
		score_manager.add_miss_hit()
		MusicManager.play_miss_hit_sound()
		print("[GameScreen] Игрок нажал в линии %d, но нот в зоне не было - сброс комбо" % lane)
		return

	var closest_note = candidates[0]
	var closest_distance = abs(closest_note.y - hit_zone_y_float)
	for note in candidates:
		var dist = abs(note.y - hit_zone_y_float)
		if dist < closest_distance:
			closest_note = note
			closest_distance = dist

	var pixels_per_sec = speed * (1000.0 / 16.0)
	var note_time = closest_note.spawn_time + (hit_zone_y_float - closest_note.spawn_y) / pixels_per_sec
	var time_diff = abs(current_time - note_time)

	var hit_type = "miss"
	var judgement_successful = false

	if time_diff <= HIT_WINDOW_PERFECT:
		score_manager.add_perfect_hit()
		hit_type = "PERFECT"
		judgement_successful = true
		perfect_hits_this_level += 1
	elif time_diff <= HIT_WINDOW_GOOD:
		score_manager.add_good_hit()
		hit_type = "GOOD"
		judgement_successful = true

	if judgement_successful:
		var points = closest_note.on_hit()

		if current_instrument == "drums":
			PlayerDataManager.add_total_drum_perfect_hit()

		var note_type = closest_note.note_type
		var sound_path = sound_factory.get_sound_path_for_note(note_type, current_instrument)
		MusicManager.play_custom_hit_sound(sound_path)

		if judgement_label:
			judgement_label.text = hit_type
			if hit_type == "PERFECT":
				judgement_label.modulate = Color.YELLOW
			elif hit_type == "GOOD":
				judgement_label.modulate = Color.CYAN
			else:
				judgement_label.modulate = Color.GRAY

		print("[GameScreen] Игрок нажал в линии %d, попадание: %s (time_diff: %.3fs)" % [lane, hit_type, time_diff])
	else:
		score_manager.add_miss_hit()
		MusicManager.play_miss_hit_sound()
		print("[GameScreen] Игрок нажал в линии %d, но попадание не засчитано (time_diff: %.3fs) - сброс комбо" % [lane, time_diff])


func _process(delta):
	if not countdown_active:
		update_ui()
		
func restart_level():
	Engine.max_fps = original_max_fps
	DisplayServer.window_set_vsync_mode(original_vsync_mode)
	
	Engine.max_fps = 60
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)

	if game_finished:
		return

	if pauser and pauser.is_paused:
		pauser.is_paused = false
		if game_timer:
			game_timer.start()

	if not check_song_end_timer.is_stopped():
		check_song_end_timer.stop()
	if victory_delay_timer and not victory_delay_timer.is_stopped():
		victory_delay_timer.stop()
	if delayed_music_timer and is_instance_valid(delayed_music_timer):
		delayed_music_timer.queue_free()
		delayed_music_timer = null

	MusicManager.stop_game_music()
	MusicManager.stop_metronome()

	player.reset()
	score_manager.reset()
	note_manager.clear_notes()
	perfect_hits_this_level = 0
	game_time = 0.0
	game_finished = false
	notes_ended = false
	skip_used = false
	input_enabled = false
	countdown_active = true
	gameplay_started = false

	update_ui()
	if countdown_label:
		countdown_label.visible = true

	if game_timer and game_timer.is_stopped():
		game_timer.start()

	start_countdown()
	
func _on_restart_confirmed():
	is_restart_held = false
	print("GameScreen: Рестарт подтверждён!")
	MusicManager.play_restart_sound()
	restart_level()	
	
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
