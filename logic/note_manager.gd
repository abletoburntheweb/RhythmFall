# logic/note_manager.gd
extends RefCounted

var total_loaded_notes_count: int = 0

var game_screen
var notes = [] 
var note_spawn_queue = []
var lanes: int = 4
var note_colors: Array = []

var BaseNote = preload("res://scenes/game_screen/notes/base_note.gd")
var Note = preload("res://scenes/game_screen/notes/note.gd")

func _init(screen):
	game_screen = screen

func set_note_colors(colors: Array):
	note_colors = colors

func _get_color_for_note(lane: int, default_color: Color) -> Color:
	if note_colors.is_empty():
		return default_color
	
	if note_colors.size() == 1:
		return Color(note_colors[0])
	elif note_colors.size() == 5:
		if lane >= 0 and lane < note_colors.size():
			return Color(note_colors[lane])
	
	return default_color

func load_notes_from_file(song_data: Dictionary, generation_mode: String, lanes: int = 4):
	self.lanes = clamp(lanes, 3, 5) 
	
	var song_path = song_data.get("path", "")
	if song_path == "":
		print("NoteManager: Путь к песне пуст, загрузка нот невозможна.")
		return

	var base_name = song_path.get_file().get_basename()
	var notes_filename = "%s_drums_%s_lanes%d.json" % [base_name, generation_mode.to_lower(), self.lanes]
	var notes_path = "user://notes/%s/%s" % [base_name, notes_filename]

	var file_access = FileAccess.open(notes_path, FileAccess.READ)
	if file_access:
		var json_text = file_access.get_as_text()
		file_access.close()
		var json_result = JSON.parse_string(json_text)
		if json_result is Array:
			note_spawn_queue = json_result.duplicate()
			print("NoteManager: Загружено %d нот из %s" % [note_spawn_queue.size(), notes_path])
		else:
			print("NoteManager: Некорректный формат файла нот: %s" % notes_path)
	else:
		print("NoteManager: Не удалось открыть файл нот: %s" % notes_path)

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

	var screen_width = DisplayServer.screen_get_size().x
	var lane_width = screen_width / lanes

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

		if note_type == "HoldNote":
			var duration = note_info.get("duration", 1.0)
			var height = int(duration * pixels_per_sec)
			note_object = Note.new(lane, y_spawn, game_time, "HoldNote", height, duration * 1000)
		elif note_type == "DrumNote":
			note_object = Note.new(lane, y_spawn, game_time, "DrumNote")
		else:
			note_object = Note.new(lane, y_spawn, game_time, "DefaultNote")
		visual_rect.color = _get_color_for_note(lane, note_object.color)

		if note_object:
			note_object.time = note_time
			note_object.visual_node = visual_rect

			var default_note_height = 20.0 

			if note_object.note_kind == "HoldNote":
				visual_rect.size = Vector2(lane_width, note_object.height)
			else:
				visual_rect.size = Vector2(lane_width, default_note_height)

			visual_rect.position = Vector2(lane * lane_width, y_spawn)
			
			game_screen.notes_container.add_child(visual_rect)
			notes.append(note_object)

func update_notes():
	var speed = game_screen.speed
	var hit_zone_y = game_screen.hit_zone_y
	var miss_threshold: float = 40 

	for i in range(notes.size() - 1, -1, -1): 
		var note = notes[i]
		note.update(speed)

		if note.y > hit_zone_y + miss_threshold and not note.was_hit and not note.is_missed:
			note.is_missed = true 
			if game_screen.score_manager:
				game_screen.score_manager.add_miss_hit()
				MusicManager.play_miss_hit_sound()  
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
