# logic/note_manager.gd
extends RefCounted

var game_screen
var notes = []
var note_spawn_queue = []

var Notes = load("res://logic/notes.gd")

func _init(screen):
	game_screen = screen

func load_notes_from_file(song_data):
	if not song_data or not "path" in song_data:
		print("[NoteManager] Нет данных о песне для загрузки нот.")
		return

	var song_path = song_data["path"]
	var base_name = song_path.get_file().get_basename()

	var current_instrument = "standard" 
	if game_screen and "current_instrument" in game_screen:
		current_instrument = game_screen.current_instrument

	var notes_file_path = "res://songs/notes/%s/%s_%s.json" % [base_name, base_name, current_instrument]

	print("[NoteManager] Попытка загрузки нот из: %s" % notes_file_path)

	var file = FileAccess.open(notes_file_path, FileAccess.READ)
	if not file:
		print("[NoteManager] Файл нот не найден: %s" % notes_file_path)
		return

	var json_text = file.get_as_text()
	file.close()

	var json_result = JSON.parse_string(json_text)
	if not json_result or typeof(json_result) != TYPE_ARRAY:
		print("[NoteManager] Файл нот пуст или не является массивом.")
		return

	for note_data in json_result:
		var note_type = note_data.get("type", "DefaultNote")
		var lane = note_data.get("lane", 0)
		var time = note_data.get("time", 0.0)
		note_spawn_queue.append(note_data)

	print("[NoteManager] Загружено %d нот из %s" % [json_result.size(), notes_file_path.get_file()])

func spawn_notes():
	var game_time = game_screen.game_time
	var speed = game_screen.speed
	var hit_zone_y = game_screen.hit_zone_y

	while note_spawn_queue.size() > 0 and note_spawn_queue[0].get("time", 0.0) <= game_time:
		var note_info = note_spawn_queue.pop_front()
		var lane = note_info.get("lane", 0)
		var time = note_info.get("time", 0.0)
		var note_type = note_info.get("type", "DefaultNote")

		var pixels_per_sec = speed * (1000.0 / 16.0)
		var initial_y_offset_from_top = -20
		var y_now = initial_y_offset_from_top + (game_time - time) * pixels_per_sec

		if note_type == "DefaultNote":
			if y_now < game_screen.get_viewport_rect().size.y + 20:
				var note = Notes.new().DefaultNote.new(lane, y_now)
				note.time = time
				notes.append(note)
		elif note_type == "HoldNote":
			var duration = note_info.get("duration", 1.0)
			var height = int(duration * pixels_per_sec)
			if y_now < game_screen.get_viewport_rect().size.y + height:
				var note = Notes.new().HoldNote.new(lane, y_now, height, duration * 1000)
				note.time = time
				notes.append(note)
		elif note_type == "KickNote":
			if y_now < game_screen.get_viewport_rect().size.y + 20:
				var note = Notes.new().KickNote.new(lane, y_now)
				note.time = time
				notes.append(note)
		elif note_type == "SnareNote":
			if y_now < game_screen.get_viewport_rect().size.y + 20:
				var note = Notes.new().SnareNote.new(lane, y_now)
				note.time = time
				notes.append(note)
		else:
			print("Неизвестный тип ноты: %s" % note_type)

func update_notes():
	var speed = game_screen.speed
	var hit_zone_y = game_screen.hit_zone_y

	for note in notes:
		note.update(speed)
		if note.y > hit_zone_y + 20:
			game_screen.score_manager.add_miss_hit()
			note.active = false

	notes = notes.filter(func(n): return n.active)

func get_notes():
	return notes

func clear_notes():
	notes.clear()
	note_spawn_queue.clear()

func get_spawn_queue_size() -> int:
	return note_spawn_queue.size()
