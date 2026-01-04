# logic/note_manager.gd
extends RefCounted

var total_loaded_notes_count: int = 0

var game_screen
var notes = [] 
var note_spawn_queue = []

var BaseNote = load("res://scenes/game_screen/notes/base_note.gd")
var DefaultNote = load("res://scenes/game_screen/notes/default_note.gd")
var HoldNote = load("res://scenes/game_screen/notes/hold_note.gd")
var KickNote = load("res://scenes/game_screen/notes/kick_note.gd")
var SnareNote = load("res://scenes/game_screen/notes/snare_note.gd")

func _init(screen):
	game_screen = screen

func load_notes_from_file(song_data):
	clear_notes()

	if not song_data or not "path" in song_data:
		printerr("NoteManager: Нет данных о песне или пути к файлу.")
		return

	var song_path = song_data["path"]
	var base_name = song_path.get_file().get_basename()

	var current_instrument = "standard"
	if game_screen and "current_instrument" in game_screen:
		current_instrument = game_screen.current_instrument

	var notes_file_path = "user://notes/%s/%s_%s.json" % [base_name, base_name, current_instrument]

	var file = FileAccess.open(notes_file_path, FileAccess.READ)
	if not file:
		printerr("NoteManager: Не удалось открыть файл нот: ", notes_file_path)
		return

	var json_text = file.get_as_text()
	file.close()
	if json_text.is_empty():
		printerr("NoteManager: Файл нот пуст: ", notes_file_path)
		return

	var json_result = JSON.parse_string(json_text)
	if not json_result or typeof(json_result) != TYPE_ARRAY:
		printerr("NoteManager: Не удалось распарсить JSON или это не массив: ", notes_file_path)
		return

	for note_data in json_result:
		var note_type = note_data.get("type", "DefaultNote")
		var lane = note_data.get("lane", 0)
		var time = note_data.get("time", 0.0)
		note_spawn_queue.append(note_data)

	total_loaded_notes_count = note_spawn_queue.size()
	print("NoteManager: Загружено %d нот в очередь (total_loaded_notes_count)." % total_loaded_notes_count)

func get_earliest_note_time() -> float:
	if note_spawn_queue.is_empty():
		return -1.0 
	if note_spawn_queue.size() > 0:
		return note_spawn_queue[0].get("time", 0.0)
	return -1.0
	
func spawn_notes():
	var game_time = game_screen.game_time
	var speed = game_screen.speed
	var hit_zone_y = game_screen.hit_zone_y
	var initial_y_offset_from_top = -20

	if note_spawn_queue.size() == 0:
		return
		
	var pixels_per_sec = speed * (1000.0 / 16.0)
	var distance_to_travel = hit_zone_y - initial_y_offset_from_top
	var time_to_reach_hit_zone = distance_to_travel / pixels_per_sec
	var spawn_threshold_time = game_time + time_to_reach_hit_zone
	while note_spawn_queue.size() > 0 and note_spawn_queue[0].get("time", 0.0) <= spawn_threshold_time:
		var note_info = note_spawn_queue.pop_front()
		var lane = note_info.get("lane", 0)
		var note_time = note_info.get("time", 0.0)
		var note_type = note_info.get("type", "DefaultNote")
		var time_diff = note_time - game_time
		var y_spawn = hit_zone_y - time_diff * pixels_per_sec
		if y_spawn > game_screen.get_viewport_rect().size.y + 20:
			continue

		var note_object = null
		var visual_rect = ColorRect.new()

		if note_type == "DefaultNote":
			note_object = DefaultNote.new(lane, y_spawn)
			visual_rect.color = note_object.color
		elif note_type == "HoldNote":
			var duration = note_info.get("duration", 1.0)
			var height = int(duration * pixels_per_sec)
			note_object = HoldNote.new(lane, y_spawn, height, duration * 1000)
			visual_rect.color = note_object.color
		elif note_type == "KickNote":
			note_object = KickNote.new(lane, y_spawn)
			visual_rect.color = note_object.color
		elif note_type == "SnareNote":
			note_object = SnareNote.new(lane, y_spawn)
			visual_rect.color = note_object.color
		else:
			continue

		if note_object:
			note_object.time = note_time
			note_object.visual_node = visual_rect

			var lane_width = 480.0 
			var default_note_height = 20.0 

			if note_type == "HoldNote":
				visual_rect.size = Vector2(lane_width, note_object.height)
			else:
				visual_rect.size = Vector2(lane_width, default_note_height)

			visual_rect.position = Vector2(lane * lane_width, y_spawn)

			game_screen.notes_container.add_child(visual_rect)

			notes.append(note_object) 

func update_notes():
	var speed = game_screen.speed
	var hit_zone_y = game_screen.hit_zone_y
	var miss_threshold: float = 30 

	for i in range(notes.size() - 1, -1, -1): 
		var note = notes[i]
		note.update(speed)

		if note.y > hit_zone_y + miss_threshold and not note.was_hit and not note.is_missed:
			note.is_missed = true 
			if game_screen.score_manager:
				game_screen.score_manager.add_miss_hit()
				var current_accuracy = game_screen.score_manager.get_accuracy()
				print("[NoteManager] Нота в линии %d пропущена (y=%.2f), вызван add_miss_hit. Текущая точность: %.2f%%" % [note.lane, note.y, current_accuracy])

		if not note.active and note.visual_node and note.visual_node.get_parent():
			note.visual_node.queue_free()

		if not note.active:
			notes.remove_at(i)


func get_notes():
	return notes

func get_spawn_queue():
	return note_spawn_queue

func skip_notes_before_time(time_threshold: float):
	var i = 0
	while i < note_spawn_queue.size():
		var note_data = note_spawn_queue[i]
		if note_data.get("time", 0.0) < time_threshold:
			note_spawn_queue.remove_at(i)
		else:
			i += 1

func clear_notes():
	for note in notes:
		if note.visual_node and note.visual_node.get_parent():
			note.visual_node.queue_free()
	notes.clear()
	note_spawn_queue.clear()
	total_loaded_notes_count = 0


func get_spawn_queue_size() -> int:
	return note_spawn_queue.size()

func get_total_loaded_count() -> int:
	return total_loaded_notes_count
