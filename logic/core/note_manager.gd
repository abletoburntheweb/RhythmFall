# logic/core/note_manager.gd
extends RefCounted

const RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const NotesUtils = preload("res://logic/domain/rhythm/notes_utils.gd")

var total_loaded_notes_count: int = 0

var game_screen
var notes = [] 
var note_spawn_queue = []
var _chart_notes_master: Array = []
var _consumed_chart_keys: Dictionary = {}
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

const DRUM_KICK_COLOR := Color(0.35, 0.55, 1.0, 1.0)
const DRUM_SNARE_COLOR := Color(0.35, 0.85, 0.45, 1.0)
const BASS_HOLD_KINDS := ["HoldNote", "BassHoldNote", "BassSustainNote"]
const BASS_SUSTAIN_KINDS := ["HoldNote", "BassHoldNote", "BassSustainNote", "BassSlideNote"]
const BASS_GHOST_BONUS := 250
const HOLD_HEAD_HEIGHT := 20.0
const HOLD_BODY_WIDTH_RATIO := 0.42
const HOLD_BODY_ALPHA := 0.48
const GHOST_NOTE_TINT := Color(0.72, 0.88, 1.0, 1.0)
const GHOST_NOTE_ALPHA := 0.36

const PLAYFIELD_MAIN := 0
const PLAYFIELD_COMPARE := 1

var playfield_target: int = PLAYFIELD_MAIN
var visual_only: bool = false
var visual_alpha: float = 1.0
var notes_container_override: Node2D = null

func _init(screen):
	game_screen = screen


func _note_approach_mode() -> int:
	if SettingsManager and SettingsManager.has_method("get_note_approach_hint"):
		return SettingsManager.get_note_approach_hint()
	return NOTE_APPROACH_SATURATED


func _proximity_t(note, hit_zone_y: float) -> float:
	var dist: float = absf(_distance_to_hit_line(note, hit_zone_y))
	var t: float = 1.0 - clamp(dist / NOTE_PROXIMITY_BAND_PX, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _distance_to_hit_line(note, hit_zone_y: float) -> float:
	if game_screen and game_screen.has_method("is_reverse_scroll_active") and game_screen.is_reverse_scroll_active():
		return float(note.y) - float(hit_zone_y)
	return float(hit_zone_y) - float(note.y)


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
		var alpha_mul := _modifier_visibility_alpha(note, hit_zone_y)
		var rgb := Color(base.r, base.g, base.b, 1.0)
		if (
			game_screen
			and RunModifiers.is_spotlight(game_screen.run_modifiers)
		):
			var rgb_mul := RunModifiers.spotlight_note_rgb_multiplier(
				absf(_distance_to_hit_line(note, hit_zone_y)),
				game_screen.run_modifier_params
			)
			rgb = Color(base.r * rgb_mul, base.g * rgb_mul, base.b * rgb_mul, 1.0)
		return _apply_duo_note_style(
			Color(rgb.r, rgb.g, rgb.b, out_a * alpha_mul)
		)

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

	var alpha_mul := _modifier_visibility_alpha(note, hit_zone_y)
	var final_rgb := tinted_rgb
	if (
		game_screen
		and RunModifiers.is_spotlight(game_screen.run_modifiers)
	):
		var rgb_mul := RunModifiers.spotlight_note_rgb_multiplier(
			absf(_distance_to_hit_line(note, hit_zone_y)),
			game_screen.run_modifier_params
		)
		final_rgb = Color(
			tinted_rgb.r * rgb_mul,
			tinted_rgb.g * rgb_mul,
			tinted_rgb.b * rgb_mul,
			1.0
		)
	return _apply_duo_note_style(
		Color(final_rgb.r, final_rgb.g, final_rgb.b, out_a * alpha_mul)
	)


func _style_ghost_color(base: Color) -> Color:
	var c := base.lerp(GHOST_NOTE_TINT, 0.45)
	c.a = base.a * GHOST_NOTE_ALPHA
	return c


func _attach_ghost_ring(parent: Control, lane_w: float, head_h: float, leading_edge: bool = true) -> void:
	if parent.has_meta("ghost_ring"):
		return
	var ring := ColorRect.new()
	ring.name = "GhostRing"
	ring.size = Vector2(lane_w + 5.0, head_h + 5.0)
	ring.position = Vector2(-2.5, -head_h - 2.5) if leading_edge else Vector2(-2.5, -2.5)
	ring.color = Color(0.85, 0.95, 1.0, 0.28)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(ring)
	parent.move_child(ring, 0)
	parent.set_meta("ghost_ring", ring)


func _apply_note_tint(note, base: Color) -> Color:
	var tint := base
	if note.is_ghost:
		tint = _style_ghost_color(base)
	if visual_only:
		tint.a *= visual_alpha
	return tint


func _duo_active() -> bool:
	return false


func _apply_duo_note_style(color: Color) -> Color:
	if not _duo_active():
		return color
	var is_partner := playfield_target == PLAYFIELD_COMPARE
	var style := DuoMode.current_style()
	if style == DuoMode.STYLE_NONE:
		return color
	if is_partner:
		return DuoMode.apply_note_color(color, true)
	if style == DuoMode.STYLE_WARM_COOL:
		return DuoMode.apply_note_color(color, false)
	return color


func _sync_duo_note_outline(note, visual_rect: ColorRect, tint: Color) -> void:
	if visual_rect == null:
		return
	if not _duo_active() or playfield_target != PLAYFIELD_COMPARE:
		_free_duo_outline(note)
		return
	if not DuoMode.should_draw_partner_outline():
		_free_duo_outline(note)
		return
	var outline: ColorRect = note.get("duo_outline_node") as ColorRect
	if outline == null or not is_instance_valid(outline):
		outline = ColorRect.new()
		outline.name = "DuoOutline"
		outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		outline.z_index = visual_rect.z_index - 1
		visual_rect.get_parent().add_child(outline)
		note.set("duo_outline_node", outline)
	outline.visible = true
	outline.color = DuoMode.partner_outline_color(tint)
	var inset := DuoMode.OUTLINE_INSET_PX
	outline.position = visual_rect.position - Vector2(inset, inset)
	outline.size = visual_rect.size + Vector2(inset * 2.0, inset * 2.0)


func _free_duo_outline(note) -> void:
	if note == null:
		return
	var outline: ColorRect = note.get("duo_outline_node") as ColorRect
	if outline and is_instance_valid(outline):
		outline.queue_free()
	note.set("duo_outline_node", null)


func _modifier_visibility_alpha(note, hit_zone_y: float) -> float:
	if game_screen == null or not ("run_modifiers" in game_screen):
		return 1.0
	var dist_top_to_line: float = _distance_to_hit_line(note, hit_zone_y)
	var alpha: float = RunModifiers.visibility_alpha_multiplier(
		game_screen.run_modifiers, dist_top_to_line, game_screen.run_modifier_params
	)
	if (
		game_screen.modifier_runtime
		and RunModifiers.has_dna_virtual_behavior(game_screen.run_modifiers)
	):
		var dna_virtual: Dictionary = game_screen.modifier_runtime.get_dna_virtual_state()
		alpha *= RunModifiers.dna_virtual_visibility_alpha(dna_virtual, dist_top_to_line)
	if (
		game_screen.modifier_runtime
		and RunModifiers.is_density_focus(game_screen.run_modifiers)
	):
		alpha *= RunModifiers.density_focus_visibility_alpha(
			game_screen.run_modifiers,
			dist_top_to_line,
			game_screen.get_song_time(),
			game_screen.modifier_runtime.density_focus_schedule,
			game_screen.run_modifier_params
		)
	alpha *= _memory_mode_alpha(note, hit_zone_y)
	return alpha


func _memory_mode_alpha(note, hit_zone_y: float) -> float:
	if game_screen == null or not ("run_modifiers" in game_screen):
		return 1.0
	var song_duration: float = 0.0
	if game_screen.has_method("get_song_duration_seconds"):
		song_duration = float(game_screen.get_song_duration_seconds())
	var song_time: float = game_screen.get_song_time()
	var playfield_h: float = game_screen.get_playfield_height_for_target(playfield_target)
	var reverse := false
	if game_screen.has_method("is_reverse_scroll_active"):
		reverse = bool(game_screen.is_reverse_scroll_active())
	return RunModifiers.memory_note_visibility_alpha(
		game_screen.run_modifiers,
		note,
		song_time,
		song_duration,
		float(note.y),
		hit_zone_y,
		playfield_h,
		reverse,
		game_screen.run_modifier_params
	)


func set_note_colors(colors: Array):
	note_colors = colors

func _get_color_for_note(lane: int, default_color: Color) -> Color:
	if note_colors.is_empty():
		return default_color
	
	if note_colors.size() == 1:
		return Color(note_colors[0])
	elif note_colors.size() == 5 or note_colors.size() == 10:
		if lane >= 0 and lane < note_colors.size():
			return Color(note_colors[lane])
	
	return default_color


func _show_drum_class_colors() -> bool:
	return (
		SettingsManager
		and SettingsManager.has_method("get_show_drum_class_colors")
		and SettingsManager.get_show_drum_class_colors()
	)


func _drum_class_from_note_info(note_info: Dictionary) -> String:
	var drum := String(note_info.get("drum", "")).strip_edges().to_lower()
	if drum != "":
		return drum
	if lanes >= 4:
		var lane := int(note_info.get("lane", -1))
		if lane == 0:
			return "kick"
		if lane == 1:
			return "snare"
	return ""


func _palette_lane_index(chart_lane: int, display_lane: int, note_info: Dictionary) -> int:
	if game_screen != null and RunModifiers.is_single_lane(game_screen.run_modifiers):
		if RunModifiers.single_lane_is_collapsed(
			game_screen.run_modifiers, game_screen.run_modifier_params
		):
			return chart_lane
		return display_lane
	if game_screen != null and RunModifiers.has_lane_remap(game_screen.run_modifiers):
		return display_lane
	return chart_lane


func _color_for_spawn(note_info: Dictionary, lane: int, default_color: Color) -> Color:
	if not _show_drum_class_colors():
		return _get_color_for_note(lane, default_color)
	match _drum_class_from_note_info(note_info):
		"kick":
			return DRUM_KICK_COLOR
		"snare":
			return DRUM_SNARE_COLOR
		_:
			return _get_color_for_note(lane, default_color)


func sync_note_color_for_display_lane(note, display_lane: int, hit_zone_y: int) -> void:
	if note == null or game_screen == null:
		return
	if not RunModifiers.has_lane_remap(game_screen.run_modifiers):
		return
	if not (note.visual_node is ColorRect):
		return
	if _show_drum_class_colors():
		var chart_palette := _get_color_for_note(int(note.lane), Color.WHITE)
		if not note.lane_palette_color.is_equal_approx(chart_palette):
			return
	note.lane_palette_color = _get_color_for_note(display_lane, note.lane_palette_color)
	var tint := _note_color_with_proximity(note, hit_zone_y)
	if visual_only:
		tint.a *= visual_alpha
	note.visual_node.color = tint
	_sync_duo_note_outline(note, note.visual_node as ColorRect, tint)

func _chart_instrument() -> String:
	if game_screen == null:
		return "drums"
	if "current_instrument" in game_screen:
		var inst := String(game_screen.current_instrument).strip_edges().to_lower()
		if inst in ["standard", ""]:
			return "drums"
		return inst
	return "drums"


func load_notes_from_file(song_data: Dictionary, generation_mode: String, lanes: int = 4, chart_tag: String = ""):
	self.lanes = clamp(lanes, 3, 5) 
	
	var song_path = song_data.get("path", "")
	if song_path == "":
		print("NoteManager: Путь к песне пуст, загрузка нот невозможна.")
		return

	var instrument := _chart_instrument()
	var notes_path = NotesUtils.notes_path_by_song(song_path, instrument, generation_mode, self.lanes, chart_tag)
	var arr: Array = NotesUtils.load_notes_array(song_path, instrument, generation_mode, self.lanes, chart_tag)
	if arr.size() > 0:
		_chart_notes_master = arr.duplicate(true)
		note_spawn_queue = arr.duplicate()
		note_spawn_queue.sort_custom(func(a, b) -> bool:
			return float(a.get("time", 0.0)) < float(b.get("time", 0.0))
		)
		print("NoteManager: Загружено %d нот из %s" % [note_spawn_queue.size(), notes_path])
		if instrument == "bass":
			var shape_counts := {"tap": 0, "hold": 0, "slide": 0}
			for item in note_spawn_queue:
				if item is Dictionary:
					var sh := String(item.get("shape", "tap")).to_lower()
					if shape_counts.has(sh):
						shape_counts[sh] += 1
			print(
				"NoteManager[bass]: mode=%s chart_lanes=%d play_lanes=%d shapes=%s"
				% [generation_mode, self.lanes, lanes, str(shape_counts)]
			)
	else:
		print(
			"NoteManager: Не удалось открыть или распарсить файл нот: %s (instrument=%s mode=%s)"
			% [notes_path, instrument, generation_mode]
		)

func _chart_source_tag() -> String:
	if game_screen == null:
		return ""
	if "current_chart_tag" in game_screen:
		return str(game_screen.current_chart_tag)
	return ""


func _chart_source_mode() -> String:
	if game_screen == null:
		return "basic"
	if "current_generation_mode" in game_screen:
		return str(game_screen.current_generation_mode)
	return "basic"


func _load_chart_array_from_disk() -> Array:
	if game_screen == null:
		return []
	var song_path := str(game_screen.selected_song_data.get("path", ""))
	if song_path == "":
		return []
	return NotesUtils.load_notes_array(
		song_path,
		_chart_instrument(),
		_chart_source_mode(),
		lanes,
		_chart_source_tag()
	)


func _ensure_chart_master() -> void:
	if not _chart_notes_master.is_empty():
		return
	var arr := _load_chart_array_from_disk()
	if arr.size() > 0:
		_chart_notes_master = arr.duplicate(true)


func get_earliest_note_time() -> float:
	if note_spawn_queue.is_empty():
		return -1.0
	var best := INF
	for item in note_spawn_queue:
		if item is Dictionary:
			best = minf(best, float(item.get("time", INF)))
	return best if best != INF else -1.0


func annotate_memory_patterns(bpm: float) -> void:
	if note_spawn_queue.is_empty():
		return
	var beat_sec := 60.0 / maxf(bpm, 60.0)
	var gap_sec := maxf(0.75, beat_sec * RunModifiers.MEMORY_PATTERN_GAP_BEATS)
	var prev_t := -999999.0
	var pattern_start := float(note_spawn_queue[0].get("time", 0.0))
	for item in note_spawn_queue:
		if not item is Dictionary:
			continue
		var t := float(item.get("time", 0.0))
		if prev_t > -999000.0 and t - prev_t > gap_sec:
			pattern_start = t
		item["memory_pattern_first_beat"] = t < pattern_start + beat_sec + 0.001
		prev_t = t
	
func spawn_notes():
	var game_time = game_screen.get_song_time()
	var speed = game_screen.speed
	var hit_zone_y = game_screen.get_hit_zone_y_for_playfield(playfield_target)
	var container := _notes_container()
	if container == null:
		return

	if note_spawn_queue.size() == 0:
		return
		
	var pixels_per_sec = game_screen.get_note_pixels_per_sec()
	var playfield_h: float = game_screen.get_playfield_height_for_target(playfield_target)
	var distance_to_travel = game_screen.note_spawn_travel_distance(playfield_h, float(hit_zone_y))
	var time_to_reach_hit_zone = distance_to_travel / pixels_per_sec
	var spawn_threshold_time = game_time + time_to_reach_hit_zone
	var chart_lanes: int = (
		game_screen.get_chart_lanes() if game_screen.has_method("get_chart_lanes") else game_screen.lanes
	)

	var spawn_index := 0
	while spawn_index < note_spawn_queue.size():
		var next_info: Dictionary = note_spawn_queue[spawn_index]
		if float(next_info.get("time", 0.0)) > spawn_threshold_time:
			break
		var next_lane := int(next_info.get("lane", 0))
		var note_time := float(next_info.get("time", 0.0))
		if _lane_blocked_at_time(next_lane, note_time):
			spawn_index += 1
			continue
		var remap_ctx := _lane_remap_context(note_time)
		if not RunModifiers.is_chart_lane_playable(
			game_screen.run_modifiers, next_lane, game_screen.lanes, chart_lanes, remap_ctx,
			game_screen.run_modifier_params
		):
			spawn_index += 1
			continue
		var note_info = note_spawn_queue.pop_at(spawn_index)
		var lane_list: Array = note_info.get("lanes", [])
		if lane_list is Array and lane_list.size() > 1:
			for lane_idx in lane_list:
				var piece: Dictionary = note_info.duplicate(true)
				piece["lane"] = float(lane_idx)
				piece["multilane"] = true
				piece.erase("lanes")
				if piece.get("type", "") == "BassOctaveNote":
					piece["type"] = "BassTapNote"
				_spawn_one_note(piece, game_time, hit_zone_y, pixels_per_sec, playfield_h, chart_lanes)
			continue
		if String(note_info.get("type", "")) == "BassOctaveNote":
			note_info["type"] = "BassTapNote"
		_spawn_one_note(note_info, game_time, hit_zone_y, pixels_per_sec, playfield_h, chart_lanes)


func _lane_blocked_at_time(chart_lane: int, note_time: float) -> bool:
	for note in notes:
		if note == null:
			continue
		if str(note.note_kind) not in BASS_SUSTAIN_KINDS:
			continue
		if int(note.lane) != chart_lane:
			continue
		var start_t := float(note.time)
		var end_t := start_t + maxf(float(note.duration), 0.001)
		if note_time > start_t + 0.001 and note_time < end_t - 0.001:
			return true
	return false


func _create_sustain_visual(
	lane_x: float,
	lane_w: float,
	leading_y: float,
	total_h: float,
	base_color: Color
) -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.position = Vector2(lane_x, leading_y)
	var head_h := HOLD_HEAD_HEIGHT
	var body_h := maxf(total_h - head_h, 0.0)
	var body_w := lane_w * HOLD_BODY_WIDTH_RATIO
	var head := ColorRect.new()
	head.name = "HoldHead"
	head.size = Vector2(lane_w, head_h)
	head.position = Vector2(0.0, -head_h)
	head.color = base_color
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var body: ColorRect = null
	if body_h > 0.5:
		body = ColorRect.new()
		body.name = "HoldBody"
		body.size = Vector2(body_w, body_h)
		body.position = Vector2((lane_w - body_w) * 0.5, -total_h)
		var body_color := base_color
		body_color.a *= HOLD_BODY_ALPHA
		body.color = body_color
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(body)
		var fill := ColorRect.new()
		fill.name = "HoldFill"
		fill.size = Vector2(body_w, 0.0)
		fill.position = Vector2(body.position.x, -head_h)
		var fill_color := base_color.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.22)
		fill_color.a = minf(1.0, base_color.a * 0.92)
		fill.color = fill_color
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.visible = false
		root.add_child(fill)
		root.set_meta("hold_fill", fill)
		root.set_meta("hold_body", body)
	root.add_child(head)
	root.set_meta("hold_head", head)
	return root


func _sync_sustain_hold_fill(note, tint: Color) -> void:
	if note.visual_node == null or not (note.visual_node is Control):
		return
	var fill: ColorRect = note.visual_node.get_meta("hold_fill", null)
	var body: ColorRect = note.visual_node.get_meta("hold_body", null)
	if fill == null or body == null:
		return
	var progress := clampf(float(note.hit_progress), 0.0, 1.0)
	if not note.was_hit and not note.is_being_held:
		fill.visible = false
		return
	var body_h := body.size.y
	var filled_h := body_h * progress
	fill.size = Vector2(body.size.x, filled_h)
	fill.position = Vector2(body.position.x, body.position.y + body_h - filled_h)
	var fill_color := tint.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.28)
	fill_color.a = minf(1.0, tint.a * 0.95)
	fill.color = fill_color
	fill.visible = filled_h > 0.5


func _sync_sustain_visual(note, lane_x: float, lane_w: float, leading_y: float, tint: Color) -> void:
	if note.visual_node == null or not (note.visual_node is Control):
		return
	note.visual_node.position = Vector2(lane_x, leading_y)
	var head: ColorRect = note.visual_node.get_meta("hold_head", null)
	if head:
		head.color = tint
	var body: ColorRect = note.visual_node.get_meta("hold_body", null)
	if body:
		var body_tint := tint
		body_tint.a *= HOLD_BODY_ALPHA
		body.color = body_tint
	_sync_sustain_hold_fill(note, tint)


func _spawn_one_note(
	note_info: Dictionary,
	game_time: float,
	hit_zone_y,
	pixels_per_sec: float,
	playfield_h: float,
	chart_lanes: int
) -> void:
		var lane = note_info.get("lane", 0)
		var note_time := float(note_info.get("time", 0.0))
		var note_type = note_info.get("type", "DefaultNote")
		if note_type == "BassSlideNote":
			note_info["type"] = "BassHoldNote"
			note_type = "BassHoldNote"
		var y_spawn = game_screen.note_y_for_chart_time(
			float(note_time), game_time, float(hit_zone_y), pixels_per_sec
		)

		if game_screen.note_spawn_offscreen(y_spawn, playfield_h):
			var late_by: float = game_time - note_time
			var good_win: float = 0.15
			if game_screen.has_method("_hit_window_good"):
				good_win = float(game_screen._hit_window_good())
			if late_by > good_win * 1.75:
				return
			y_spawn = float(hit_zone_y)

		var note_object = null
		var visual_rect = ColorRect.new()

		if note_type in BASS_HOLD_KINDS:
			var duration = float(note_info.get("duration", note_info.get("end", note_time) - note_time))
			duration = maxf(duration, 0.05)
			var height = int(duration * pixels_per_sec)
			var kind := "BassHoldNote" if note_type in ["BassHoldNote", "BassSustainNote"] else "HoldNote"
			note_object = Note.new(lane, y_spawn, game_time, kind, height, duration * 1000.0)
		elif note_type == "BassSlideNote":
			var duration = float(note_info.get("duration", note_info.get("end", note_time) - note_time))
			duration = maxf(duration, 0.05)
			var height = int(duration * pixels_per_sec)
			var lane_end := int(note_info.get("lane_end", lane))
			note_object = Note.new(lane, y_spawn, game_time, "BassSlideNote", height, duration * 1000.0, lane_end)
		elif note_type == "DrumNote":
			note_object = Note.new(lane, y_spawn, game_time, "DrumNote")
		else:
			note_object = Note.new(lane, y_spawn, game_time, "DefaultNote")

		note_object.is_ghost = bool(note_info.get("ghost", false))
		note_object.is_multilane = bool(note_info.get("multilane", false))

		var display_lane := RunModifiers.display_lane_for_chart_lane(
			int(lane), game_screen.lanes, chart_lanes, game_screen.run_modifiers,
			_lane_remap_context(float(note_time)), game_screen.run_modifier_params
		)
		if display_lane < 0:
			return

		note_object.display_lane = display_lane
		var palette_lane := _palette_lane_index(int(lane), display_lane, note_info)
		var base_color = _color_for_spawn(note_info, palette_lane, note_object.color)
		note_object.lane_palette_color = base_color

		if note_object:
			note_object.time = note_time
			if RunModifiers.is_memory_mode(game_screen.run_modifiers):
				note_object.memory_pattern_first_beat = bool(
					note_info.get("memory_pattern_first_beat", false)
				)
				var song_duration: float = 0.0
				if game_screen.has_method("get_song_duration_seconds"):
					song_duration = float(game_screen.get_song_duration_seconds())
				var note_progress := RunModifiers.memory_chart_progress(float(note_time), song_duration)
				var reveal_ms := RunModifiers.memory_reveal_ms_for_note(
					note_progress,
					bool(note_info.get("memory_pattern_first_beat", true)),
					game_screen.run_modifier_params
				)
				if reveal_ms < 0.0:
					note_object.memory_hide_at = -1.0
				else:
					var spawn_song_time: float = game_screen.get_song_time()
					note_object.memory_hide_at = spawn_song_time + reveal_ms / 1000.0

			var default_note_height = 20.0
			var pf_w: float = game_screen.get_playfield_width_for_target(playfield_target)
			var lane_w: float = game_screen.get_lane_width_at_for_playfield(playfield_target, display_lane)
			var lane_x: float = game_screen.get_lane_left_x_for_playfield(playfield_target, display_lane)
			if (
				RunModifiers.is_single_lane(game_screen.run_modifiers)
				and RunModifiers.single_lane_is_collapsed(
					game_screen.run_modifiers, game_screen.run_modifier_params
				)
			):
				lane_w = RunModifiers.single_lane_note_width(pf_w)
				lane_x = RunModifiers.single_lane_note_x(pf_w)

			if note_object.note_kind in BASS_HOLD_KINDS or note_object.note_kind == "BassSlideNote":
				note_object.y = y_spawn
				note_object.spawn_y = y_spawn
				var tint_hold := _apply_note_tint(note_object, _note_color_with_proximity(note_object, hit_zone_y))
				var sustain_root := _create_sustain_visual(
					lane_x, lane_w, y_spawn, note_object.height, tint_hold
				)
				note_object.visual_node = sustain_root
				note_object.hold_head_node = sustain_root.get_meta("hold_head")
				note_object.hold_body_node = sustain_root.get_meta("hold_body", null)
				if note_object.is_ghost and note_object.hold_head_node:
					_attach_ghost_ring(sustain_root, lane_w, HOLD_HEAD_HEIGHT)
				_sync_duo_note_outline(note_object, note_object.hold_head_node, tint_hold)
			else:
				note_object.visual_node = visual_rect
				visual_rect.size = Vector2(lane_w, default_note_height)
				visual_rect.position = Vector2(lane_x, y_spawn)
				var tint := _apply_note_tint(note_object, _note_color_with_proximity(note_object, hit_zone_y))
				visual_rect.color = tint
				if note_object.is_ghost:
					_attach_ghost_ring(visual_rect, lane_w, default_note_height, false)
				visual_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_sync_duo_note_outline(note_object, visual_rect, tint)

			var container := _notes_container()
			if container and note_object.visual_node:
				container.add_child(note_object.visual_node)
				notes.append(note_object)


func _notes_container() -> Node2D:
	if notes_container_override:
		return notes_container_override
	if game_screen and "notes_container" in game_screen:
		return game_screen.notes_container
	return null

func update_notes():
	var speed = game_screen.speed
	var hit_zone_y = game_screen.get_hit_zone_y_for_playfield(playfield_target)
	var miss_threshold: float = 40
	var reverse: bool = game_screen.is_reverse_scroll_active()
	var scroll_sign: float = game_screen.get_note_scroll_sign()

	var despawn_y: float = game_screen.get_note_despawn_y_for_target(playfield_target)
	var song_time: float = game_screen.get_song_time()
	var pixels_per_sec: float = game_screen.get_note_pixels_per_sec()
	var skip_misses: bool = (
		game_screen
		and game_screen.has_method("is_resume_rewind_active")
		and game_screen.is_resume_rewind_active()
	) or (
		game_screen
		and game_screen.has_method("is_replay_watch_mode")
		and game_screen.is_replay_watch_mode()
	)
	var i := notes.size() - 1
	while i >= 0:
		if i >= notes.size():
			i -= 1
			continue
		var note = notes[i]
		if note == null:
			notes.remove_at(i)
			i -= 1
			continue
		if note.note_kind in BASS_HOLD_KINDS or note.note_kind == "BassSlideNote":
			var leading_y: float = game_screen.note_y_for_chart_time(
				float(note.time), song_time, float(hit_zone_y), pixels_per_sec
			)
			note.y = leading_y
			note.update(speed, despawn_y, scroll_sign, song_time)
			if note.active and note.visual_node is Control:
				var chart_lanes: int = (
					game_screen.get_chart_lanes() if game_screen.has_method("get_chart_lanes") else game_screen.lanes
				)
				var chart_lane: int = note.current_chart_lane() if note.is_being_held else int(note.lane)
				var vis_lane := RunModifiers.display_lane_for_chart_lane(
					chart_lane, game_screen.lanes, chart_lanes, game_screen.run_modifiers,
					_lane_remap_context(float(note.time)), game_screen.run_modifier_params
				)
				if vis_lane >= 0:
					var pf_w: float = game_screen.get_playfield_width_for_target(playfield_target)
					var lane_w: float = game_screen.get_lane_width_at_for_playfield(playfield_target, vis_lane)
					var lane_x: float = game_screen.get_lane_left_x_for_playfield(playfield_target, vis_lane)
					if (
						RunModifiers.is_single_lane(game_screen.run_modifiers)
						and RunModifiers.single_lane_is_collapsed(
							game_screen.run_modifiers, game_screen.run_modifier_params
						)
					):
						lane_w = RunModifiers.single_lane_note_width(pf_w)
						lane_x = RunModifiers.single_lane_note_x(pf_w)
					var tint_hold := _apply_note_tint(note, _note_color_with_proximity(note, hit_zone_y))
					_sync_sustain_visual(note, lane_x, lane_w, leading_y, tint_hold)
					if note.hold_head_node:
						_sync_duo_note_outline(note, note.hold_head_node, tint_hold)
		else:
			note.y = game_screen.note_y_for_chart_time(
				float(note.time), song_time, float(hit_zone_y), pixels_per_sec
			)
			if note.visual_node:
				note.visual_node.position.y = note.y
			var passed_despawn: bool = note.y < despawn_y if reverse else note.y > despawn_y
			if passed_despawn and not note.is_being_held:
				note.active = false

		if note.visual_node is ColorRect and note.active and note.note_kind not in BASS_SUSTAIN_KINDS:
			var tint := _apply_note_tint(note, _note_color_with_proximity(note, hit_zone_y))
			note.visual_node.color = tint
			_sync_duo_note_outline(note, note.visual_node as ColorRect, tint)

		if visual_only:
			if not note.active and note.visual_node and note.visual_node.get_parent():
				_free_duo_outline(note)
				note.visual_node.queue_free()
			if not note.active:
				notes.remove_at(i)
			i -= 1
			continue

		if skip_misses:
			var passed_hit: bool
			if reverse:
				passed_hit = note.y < hit_zone_y - miss_threshold
			else:
				passed_hit = note.y > hit_zone_y + miss_threshold
			if passed_hit and not note.was_hit:
				# Re-queue from chart master so resume rewind never drops notes permanently.
				var key := _live_note_key(note)
				note.active = false
				if note.visual_node and note.visual_node.get_parent():
					_free_duo_outline(note)
					note.visual_node.queue_free()
				notes.remove_at(i)
				if not _consumed_chart_keys.has(key):
					for raw in _chart_notes_master:
						if raw is Dictionary and _chart_item_key(raw) == key:
							note_spawn_queue.append((raw as Dictionary).duplicate(true))
							break
					note_spawn_queue.sort_custom(func(a, b) -> bool:
						return float(a.get("time", 0.0)) < float(b.get("time", 0.0))
					)
				i -= 1
				continue
			if not note.active and note.visual_node and note.visual_node.get_parent():
				_free_duo_outline(note)
				note.visual_node.queue_free()
			if not note.active:
				notes.remove_at(i)
			i -= 1
			continue

		var passed_miss: bool
		if reverse:
			passed_miss = note.y < hit_zone_y - miss_threshold
		else:
			passed_miss = note.y > hit_zone_y + miss_threshold
		if passed_miss and not note.was_hit and not note.is_missed:
			if note.note_kind in BASS_SUSTAIN_KINDS:
				var late_limit: float = 0.15
				if game_screen.has_method("_hit_window_good"):
					late_limit = float(game_screen._hit_window_good())
				if song_time <= float(note.time) + late_limit:
					i -= 1
					continue
			if note.is_ghost:
				note.active = false
				mark_chart_note_consumed(note, "miss")
				if note.visual_node and note.visual_node.get_parent():
					_free_duo_outline(note)
					note.visual_node.queue_free()
				notes.remove_at(i)
				i -= 1
				continue
			note.is_missed = true
			mark_chart_note_consumed(note, "miss")
			var partner_miss: bool = (
				playfield_target == PLAYFIELD_COMPARE
				and game_screen.chart_compare != null
				and game_screen.chart_compare.split_active_runtime
			)
			if game_screen and game_screen.has_method("register_miss"):
				game_screen.register_miss(true, -1.0, partner_miss, int(note.lane), float(note.time))
			elif game_screen.score_manager:
				game_screen.score_manager.add_miss_hit()
				MusicManager.play_miss_hit_sound()  
				if game_screen and game_screen.has_method("_combo_shake_and_dim"):
					game_screen._combo_shake_and_dim()
				if game_screen and game_screen.has_method("show_miss_judgement"):
					game_screen.show_miss_judgement()
			var current_accuracy = game_screen.score_manager.get_accuracy()
			print("[NoteManager] Нота в линии %d пропущена (y=%.2f), вызван add_miss_hit. Текущая точность: %.2f%%" % [note.lane, note.y, current_accuracy])

		if not note.active and note.visual_node and note.visual_node.get_parent():
			_free_duo_outline(note)
			note.visual_node.queue_free()

		if not note.active:
			notes.remove_at(i)
		i -= 1


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


func mark_chart_note_consumed(note, reason: String = "hit") -> void:
	if note == null:
		return
	var kind := "miss" if reason == "miss" else "hit"
	_consumed_chart_keys[_live_note_key(note)] = kind


func _live_note_key(note) -> String:
	return "%0.5f|%d|%s" % [float(note.time), int(note.lane), str(note.note_kind)]


func _chart_item_key(item: Dictionary) -> String:
	return "%0.5f|%d|%s" % [
		float(item.get("time", 0.0)),
		int(item.get("lane", 0)),
		str(item.get("type", "DefaultNote")),
	]


func _unconsume_misses_from_time(target_time: float) -> void:
	## Misses at/after rewind point become retryable; hits stay consumed.
	var to_erase: Array[String] = []
	for key in _consumed_chart_keys.keys():
		if str(_consumed_chart_keys[key]) != "miss":
			continue
		var parts := str(key).split("|")
		if parts.is_empty():
			continue
		if float(parts[0]) + 0.00001 >= target_time:
			to_erase.append(str(key))
	for key in to_erase:
		_consumed_chart_keys.erase(key)


func rewind_chart_to_time(target_time: float) -> void:
	clear_active_notes()
	_ensure_chart_master()
	note_spawn_queue.clear()
	_unconsume_misses_from_time(target_time)
	if _chart_notes_master.is_empty():
		push_warning("NoteManager: rewind_chart_to_time — chart master empty")
		return
	for item in _chart_notes_master:
		if not item is Dictionary:
			continue
		if float(item.get("time", 0.0)) < target_time:
			continue
		if _consumed_chart_keys.has(_chart_item_key(item)):
			continue
		note_spawn_queue.append(item.duplicate(true))
	note_spawn_queue.sort_custom(func(a, b) -> bool:
		return float(a.get("time", 0.0)) < float(b.get("time", 0.0))
	)

func clear_notes():
	for note in notes:
		_free_duo_outline(note)
		if note.visual_node and note.visual_node.get_parent():
			note.visual_node.queue_free()
	notes.clear()
	note_spawn_queue.clear()
	_chart_notes_master.clear()
	_consumed_chart_keys.clear()
	total_loaded_notes_count = 0
	
func clear_active_notes():
	for note in notes:
		_free_duo_outline(note)
		if note.visual_node and note.visual_node.get_parent():
			note.visual_node.queue_free()
	notes.clear()


func prune_non_play_lanes(modifiers: Array, active_lanes: int, chart_lanes: int = -1) -> void:
	if RunModifiers.is_dynamic_lanes(modifiers):
		return
	if note_spawn_queue.is_empty():
		return
	var chart := chart_lanes if chart_lanes > 0 else active_lanes
	var params: Dictionary = game_screen.run_modifier_params if game_screen else {}
	var filtered: Array = []
	for item in note_spawn_queue:
		if item is Dictionary:
			var lane_idx := int(item.get("lane", 0))
			var note_time := float(item.get("time", 0.0))
			var remap_ctx := _lane_remap_context(note_time)
			if RunModifiers.is_chart_lane_playable(
				modifiers, lane_idx, active_lanes, chart, remap_ctx, params
			):
				filtered.append(item)
	note_spawn_queue = filtered


func _lane_remap_context(note_time: float) -> Dictionary:
	if game_screen and game_screen.has_method("lane_remap_context"):
		return game_screen.lane_remap_context(note_time)
	return {"song_path": "", "note_time": note_time, "bpm": 120.0}


func cull_notes_outside_playable_lanes(modifiers: Array, active_lanes: int, chart_lanes: int = -1) -> void:
	var chart := chart_lanes if chart_lanes > 0 else active_lanes
	var params: Dictionary = game_screen.run_modifier_params if game_screen else {}
	for i in range(notes.size() - 1, -1, -1):
		var note = notes[i]
		if note == null:
			continue
		if RunModifiers.is_chart_lane_playable(
			modifiers, int(note.lane), active_lanes, chart, _lane_remap_context(float(note.time)), params
		):
			continue
		if note.visual_node and note.visual_node.get_parent():
			_free_duo_outline(note)
			note.visual_node.queue_free()
		notes.remove_at(i)


func get_latest_chart_time() -> float:
	var best := 0.0
	for item in note_spawn_queue:
		if item is Dictionary:
			best = maxf(best, float(item.get("time", 0.0)))
	for note in notes:
		if note != null:
			best = maxf(best, float(note.time))
	return best


func get_spawn_queue_size() -> int:
	return note_spawn_queue.size()

func get_total_loaded_count() -> int:
	return total_loaded_notes_count
