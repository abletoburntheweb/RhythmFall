# logic/note_manager.gd
extends RefCounted

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
	if not song_data or not "path" in song_data:
		return

	var song_path = song_data["path"]
	var base_name = song_path.get_file().get_basename()

	var current_instrument = "standard"
	if game_screen and "current_instrument" in game_screen:
		current_instrument = game_screen.current_instrument

	var notes_file_path = "user://notes/%s/%s_%s.json" % [base_name, base_name, current_instrument]

	var file = FileAccess.open(notes_file_path, FileAccess.READ)
	if not file:
		return

	var json_text = file.get_as_text()
	file.close()

	var json_result = JSON.parse_string(json_text)
	if not json_result or typeof(json_result) != TYPE_ARRAY:
		return

	for note_data in json_result:
		var note_type = note_data.get("type", "DefaultNote")
		var lane = note_data.get("lane", 0)
		var time = note_data.get("time", 0.0)
		note_spawn_queue.append(note_data)

func spawn_notes():
	var game_time = game_screen.game_time
	var speed = game_screen.speed
	var hit_zone_y = game_screen.hit_zone_y

	if note_spawn_queue.size() == 0:
		return

	while note_spawn_queue.size() > 0 and note_spawn_queue[0].get("time", 0.0) <= game_time:
		var note_info = note_spawn_queue.pop_front()
		var lane = note_info.get("lane", 0)
		var time = note_info.get("time", 0.0)
		var note_type = note_info.get("type", "DefaultNote")

		var pixels_per_sec = speed * (1000.0 / 16.0)
		var initial_y_offset_from_top = -20
		var y_now = initial_y_offset_from_top + (game_time - time) * pixels_per_sec

		var note_object = null
		var visual_rect = ColorRect.new()

		if note_type == "DefaultNote":
			if y_now < game_screen.get_viewport_rect().size.y + 20:
				note_object = DefaultNote.new(lane, y_now)
				visual_rect.color = note_object.color
		elif note_type == "HoldNote":
			var duration = note_info.get("duration", 1.0)
			var height = int(duration * pixels_per_sec)
			if y_now < game_screen.get_viewport_rect().size.y + height:
				note_object = HoldNote.new(lane, y_now, height, duration * 1000)
				visual_rect.color = note_object.color
		elif note_type == "KickNote":
			if y_now < game_screen.get_viewport_rect().size.y + 20:
				note_object = KickNote.new(lane, y_now)
				visual_rect.color = note_object.color
		elif note_type == "SnareNote":
			if y_now < game_screen.get_viewport_rect().size.y + 20:
				note_object = SnareNote.new(lane, y_now)
				visual_rect.color = note_object.color
		else:
			continue

		if note_object:
			note_object.time = time
			note_object.visual_node = visual_rect

			var lane_width = 480.0 
			var default_note_height = 20.0 

			if note_type == "HoldNote":
				visual_rect.size = Vector2(lane_width, note_object.height)
			else:
				visual_rect.size = Vector2(lane_width, default_note_height)

			visual_rect.position = Vector2(lane * lane_width, y_now)

			game_screen.notes_container.add_child(visual_rect)

			notes.append(note_object) 

func update_notes():
	var speed = game_screen.speed
	var hit_zone_y = game_screen.hit_zone_y

	for i in range(notes.size() - 1, -1, -1): 
		var note = notes[i]
		note.update(speed)

		if not note.active and note.visual_node and note.visual_node.get_parent():
			note.visual_node.queue_free()

		if not note.active:
			notes.remove_at(i)

func get_notes():
	return notes

func clear_notes():
	for note in notes:
		if note.visual_node and note.visual_node.get_parent():
			note.visual_node.queue_free()
	notes.clear()
	note_spawn_queue.clear()

func get_spawn_queue_size() -> int:
	return note_spawn_queue.size()
