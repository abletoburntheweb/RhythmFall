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

const NOTE_PROXIMITY_BAND_PX := 220.0
const NOTE_APPROACH_NONE := 0
const NOTE_APPROACH_LIGHTER := 1
const NOTE_APPROACH_DARKER := 2
const NOTE_APPROACH_SATURATED := 3
const NOTE_PROXIMITY_LIGHTEN_AMOUNT := 0.42
const NOTE_PROXIMITY_DARKEN_AMOUNT := 0.38
const NOTE_PROXIMITY_SATURATION_GAIN := 0.5

func _init(screen):
	game_screen = screen


func _note_approach_mode() -> int:
	if SettingsManager and SettingsManager.has_method("get_note_approach_hint"):
		return SettingsManager.get_note_approach_hint()
	return NOTE_APPROACH_SATURATED


func _proximity_t(note, hit_zone_y: float) -> float:
	var dist_top_to_line: float = float(hit_zone_y) - float(note.y)
	var t: float = 1.0 - clamp(dist_top_to_line / NOTE_PROXIMITY_BAND_PX, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _rgb_boost_saturation(c: Color, t: float) -> Color:
	var lum: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
	var k: float = 1.0 + NOTE_PROXIMITY_SATURATION_GAIN * t
	return Color(
		clamp(lum + (c.r - lum) * k, 0.0, 1.0),
		clamp(lum + (c.g - lum) * k, 0.0, 1.0),
		clamp(lum + (c.b - lum) * k, 0.0, 1.0),
		1.0
	)


func _note_color_with_proximity(note, hit_zone_y: float) -> Color:
	var base: Color = note.lane_palette_color
	var nb := 100.0
	if SettingsManager and SettingsManager.has_method("get_note_brightness"):
		nb = float(SettingsManager.get_note_brightness())
	var out_a: float = clamp(base.a * (nb / 100.0), 0.0, 1.0)

	var mode := _note_approach_mode()
	if mode == NOTE_APPROACH_NONE:
		return Color(base.r, base.g, base.b, out_a)

	var t: float = _proximity_t(note, hit_zone_y)
	var rgb := Color(base.r, base.g, base.b, 1.0)
	var tinted_rgb: Color = rgb
	match mode:
		NOTE_APPROACH_LIGHTER:
			tinted_rgb = rgb.lerp(Color.WHITE, NOTE_PROXIMITY_LIGHTEN_AMOUNT * t)
		NOTE_APPROACH_DARKER:
			tinted_rgb = rgb.lerp(Color.BLACK, NOTE_PROXIMITY_DARKEN_AMOUNT * t)
		NOTE_APPROACH_SATURATED:
			tinted_rgb = _rgb_boost_saturation(rgb, t)
		_:
			tinted_rgb = rgb

	return Color(tinted_rgb.r, tinted_rgb.g, tinted_rgb.b, out_a)

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

	var notes_path = NotesUtils.notes_path_by_song(song_path, "drums", generation_mode, self.lanes)
	var arr: Array = JsonUtils.read_json_array(notes_path)
	if arr.size() > 0:
		note_spawn_queue = arr.duplicate()
		print("NoteManager: Загружено %d нот из %s" % [note_spawn_queue.size(), notes_path])
	else:
		print("NoteManager: Не удалось открыть или распарсить файл нот: %s" % notes_path)

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
		
	var pixels_per_sec = speed * 60.0
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

		var playfield_h: float = game_screen.get_playfield_height_for_notes()
		if y_spawn > playfield_h + 20.0:
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
		var base_color = _get_color_for_note(lane, note_object.color)
		note_object.lane_palette_color = base_color

		if note_object:
			note_object.time = note_time
			note_object.visual_node = visual_rect

			var default_note_height = 20.0
			var lane_w = game_screen.get_lane_width_at(lane)
			var lane_x = game_screen.get_lane_left_x(lane)

			if note_object.note_kind == "HoldNote":
				visual_rect.size = Vector2(lane_w, note_object.height)
			else:
				visual_rect.size = Vector2(lane_w, default_note_height)

			visual_rect.position = Vector2(lane_x, y_spawn)
			visual_rect.color = _note_color_with_proximity(note_object, hit_zone_y)
			
			game_screen.notes_container.add_child(visual_rect)
			notes.append(note_object)

func update_notes():
	var speed = game_screen.speed
	var hit_zone_y = game_screen.hit_zone_y
	var miss_threshold: float = 40 

	var despawn_y: float = game_screen.get_note_despawn_y()
	for i in range(notes.size() - 1, -1, -1): 
		var note = notes[i]
		note.update(speed, despawn_y)

		if note.visual_node is ColorRect and note.active:
			note.visual_node.color = _note_color_with_proximity(note, hit_zone_y)

		if note.y > hit_zone_y + miss_threshold and not note.was_hit and not note.is_missed:
			note.is_missed = true 
			if game_screen.score_manager:
				game_screen.score_manager.add_miss_hit()
				MusicManager.play_miss_hit_sound()  
				if game_screen and game_screen.has_method("_combo_shake_and_dim"):
					game_screen._combo_shake_and_dim()
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
	
func clear_active_notes():
	for note in notes:
		if note.visual_node and note.visual_node.get_parent():
			note.visual_node.queue_free()
	notes.clear()


func get_spawn_queue_size() -> int:
	return note_spawn_queue.size()

func get_total_loaded_count() -> int:
	return total_loaded_notes_count
