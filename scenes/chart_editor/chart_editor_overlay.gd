# scenes/chart_editor/chart_editor_overlay.gd
extends Control
class_name ChartEditorOverlay

# Editor interaction layer поверх GamePlayfield — выделение, drag, box, RMB add
signal note_clicked(key: String, event: InputEvent)
signal notes_box_selected(keys: Array, additive: bool)
signal notes_dragged(keys: Array, delta_t: float, delta_lane: int, snap_div: int)
signal note_add_requested(time: float, lane: int)
signal selection_cleared()
signal notes_deleted(keys: Array)
signal selection_changed()

var state = null
var playfield = null
var current_tool: String = "select" # "select" or "pencil"

func set_tool(tool: String) -> void:
	current_tool = tool.strip_edges().to_lower()
	if current_tool != "pencil":
		current_tool = "select"
	queue_redraw()

var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_start_time: float = 0.0
var _drag_keys: Array[String] = []
var _drag_before_times: Dictionary = {}
var _drag_before_lanes: Dictionary = {}
var _is_dragging: bool = false
var _is_boxing: bool = false
var _box_start: Vector2 = Vector2.ZERO
var _box_end: Vector2 = Vector2.ZERO
var _drag_current_delta_t: float = 0.0
var _drag_current_delta_lane: int = 0
# Pencil specific — click vs drag distinction (spec 2,3)
var _pencil_pending_action: String = "" # "" | "delete" | "paint_add"
var _pencil_pending_hit_key: String = ""
var _pencil_press_pos: Vector2 = Vector2.ZERO
var _pencil_is_drag: bool = false
var _pencil_paint_last_t: float = 0.0
var _pencil_paint_last_lane: int = -1
var _pencil_delete_visited: Dictionary = {}
var _is_pencil_painting: bool = false
const PENCIL_DRAG_THRESHOLD: float = 6.0
var _rmb_hold_active: bool = false
var _rmb_delete_visited: Dictionary = {}

func setup(p_state, p_playfield) -> void:
	state = p_state
	playfield = p_playfield
	queue_redraw()

var _ghost_time: float = 0.0
var _ghost_lane: int = 0
var _ghost_visible: bool = false
var _pattern_ghost_visible: bool = false
var _pattern_ghost_notes: Array = []
var _pattern_ghost_start: float = 0.0

func _draw() -> void:
	if _is_boxing:
		var r = Rect2(_box_start, _box_end - _box_start)
		r = r.abs()
		if playfield is Control:
			var pf_rect := (playfield as Control).get_rect()
			# pf_rect is local to playfield (0,0,size), clamp box to it
			var clamped := r.intersection(Rect2(Vector2.ZERO, (playfield as Control).size))
			if clamped.size.x > 0 and clamped.size.y > 0:
				r = clamped
		draw_rect(r, Color(0.45, 0.78, 1.0, 0.18), true)
		draw_rect(r, Color(0.45, 0.78, 1.0, 0.9), false, 1.5)
	if _ghost_visible and state and playfield and not _drag_keys.is_empty():
		# Ghost for all selected notes (offset by current delta)
		for k in _drag_keys:
			var base_t = float(_drag_before_times.get(k, 0.0))
			var base_lane = int(_drag_before_lanes.get(k, 0))
			var ghost_t = base_t + _drag_current_delta_t
			var ghost_lane = clampi(base_lane + _drag_current_delta_lane, 0, playfield.lanes - 1)
			var y = playfield.note_y(ghost_t, state.song_time)
			var x = playfield.get_lane_left_x(ghost_lane)
			var w = playfield.get_lane_width_at(ghost_lane)
			var rect = Rect2(Vector2(x + 1.0, y - 10.0), Vector2(w - 2.0, 20.0))
			draw_rect(rect, Color(1, 1, 1, 0.18), true)
			draw_rect(rect, Color(1, 1, 1, 0.85), false, 1.8)
	if _pattern_ghost_visible and state and playfield and not _pattern_ghost_notes.is_empty():
		# Anchor marker at bar_start (visual indication of drop point, not moving notes)
		var anchor_y: float = float(playfield.note_y(_pattern_ghost_start, state.song_time)) if playfield.has_method("note_y") else 0.0
		var pw: float = float((playfield as Control).size.x) if playfield is Control else 600.0
		# Horizontal anchor line across playfield at bar_start
		draw_line(Vector2(0, anchor_y), Vector2(pw, anchor_y), Color(0.95, 0.78, 0.32, 0.9), 2.0)
		# Small triangle marker at left edge
		var tri := PackedVector2Array([Vector2(6, anchor_y - 6), Vector2(16, anchor_y), Vector2(6, anchor_y + 6)])
		draw_colored_polygon(tri, Color(0.95, 0.78, 0.32, 0.95))
		for n in _pattern_ghost_notes:
			if not n is Dictionary:
				continue
			var pt = float(n.get("time", 0.0))
			var pl = int(n.get("lane", 0))
			var y = playfield.note_y(pt, state.song_time)
			var x = playfield.get_lane_left_x(pl)
			var w = playfield.get_lane_width_at(pl)
			var rect = Rect2(Vector2(x + 1.0, y - 10.0), Vector2(w - 2.0, 20.0))
			draw_rect(rect, Color(0.6, 0.85, 1.0, 0.22), true)
			draw_rect(rect, Color(0.6, 0.85, 1.0, 0.9), false, 1.6)
		# Also single ghost for add preview? Not needed

func _gui_input(event: InputEvent) -> void:
	if state == null or playfield == null:
		return
	# MIDI drag owns the gesture — block Pencil/Select/Move/Box entirely (one LMB gesture = one owner)
	# Use direct property access via get() with fallback to has_method, more robust than get("_var")
	var screen_for_midi = get_parent()
	var depth := 0
	while screen_for_midi and depth < 10:
		if screen_for_midi.has_method("_on_add_requested") or screen_for_midi.has_method("_insert_pattern_at") or " _pattern_drag_active" in str(screen_for_midi):
			# Check for ChartEditorScreen by looking for known vars
			if screen_for_midi.has_method("_get_midi_samples_root") or "_pattern_drag_active" in screen_for_midi:
				break
		screen_for_midi = screen_for_midi.get_parent()
		depth += 1
		if screen_for_midi == null:
			# Fallback: try current scene
			var cs = get_tree().current_scene if get_tree() else null
			if cs and cs.has_method("_on_add_requested"):
				screen_for_midi = cs
				break
	if screen_for_midi:
		var is_midi_drag: bool = false
		if "_pattern_drag_active" in screen_for_midi and screen_for_midi.get("_pattern_drag_active") == true:
			is_midi_drag = true
		elif "_gesture_owner" in screen_for_midi and str(screen_for_midi.get("_gesture_owner")) == "midi":
			is_midi_drag = true
		if not is_midi_drag and screen_for_midi.has_method("get"):
			var v1 = screen_for_midi.get("_pattern_drag_active")
			var v2 = screen_for_midi.get("_gesture_owner")
			if v1 == true or str(v2) == "midi":
				is_midi_drag = true
		if is_midi_drag:
			return
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		var pos: Vector2 = mb.position
		var lane = playfield.get_lane_at_x(pos.x) if playfield else -1
		var t = playfield.world_to_time(pos.y, state.song_time) if playfield else pos.y / 600.0
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var hit_key = _hit_test(pos)
			if current_tool == "pencil":
				# Pencil: LMB empty→create, LMB note→select/drag (NOT delete), RMB→delete
				if hit_key != "":
					# In Pencil, LMB on note should select/drag, not delete (delete only on RMB)
					# Prepare drag data (use selection if hit in selection)
					_drag_keys.clear()
					_drag_before_times.clear()
					_drag_before_lanes.clear()
					if state.selected_keys.has(hit_key):
						for k in state.selected_keys.keys():
							_drag_keys.append(String(k))
					else:
						# Select this single note first
						state.select_only([hit_key])
						emit_signal("selection_changed")
						_drag_keys = [hit_key]
					for n in state.document.notes:
						var k = EditorNoteUtils.note_key(n as Dictionary)
						if k in _drag_keys:
							_drag_before_times[k] = float(n.get("time", 0.0))
							_drag_before_lanes[k] = int(n.get("lane", 0))
					_drag_start_pos = pos
					_drag_start_time = playfield.world_to_time(pos.y, state.song_time)
					_drag_current_delta_t = 0.0
					_drag_current_delta_lane = 0
					_ghost_visible = false
					_is_dragging = true
					_pencil_pending_action = ""
					_pencil_is_drag = false
					queue_redraw()
					playfield.queue_redraw()
					get_viewport().set_input_as_handled()
					return
				else:
					if lane >= 0:
						var snapped_t = t
						if state.snap_enabled and state.grid and state.snap_division > 0:
							snapped_t = state.grid.snap_time(t, state.snap_division)
						emit_signal("note_add_requested", snapped_t, lane)
						_pencil_pending_action = "paint_add"
						_pencil_paint_last_t = snapped_t
						_pencil_paint_last_lane = lane
						_is_pencil_painting = true
						_pencil_press_pos = pos
						_pencil_delete_visited.clear()
					get_viewport().set_input_as_handled()
					return
			# SELECT tool — strict: LMB note→select, LMB empty→box/clear, never create
			if hit_key != "":
				if mb.ctrl_pressed or mb.meta_pressed:
					state.toggle_selection([hit_key])
					emit_signal("selection_changed")
					queue_redraw()
					playfield.queue_redraw()
					get_viewport().set_input_as_handled()
					return
				elif mb.shift_pressed and not state.selected_keys.is_empty():
					var range_keys = _range_keys_between(state.primary_key, hit_key)
					state.select_only(range_keys)
					emit_signal("selection_changed")
					queue_redraw()
					playfield.queue_redraw()
					get_viewport().set_input_as_handled()
					return
				else:
					if not state.selected_keys.has(hit_key):
						state.select_only([hit_key])
						emit_signal("selection_changed")
					else:
						emit_signal("selection_changed")
					# Prepare drag with ghost
					_drag_keys = []
					for k in state.selected_keys.keys():
						_drag_keys.append(String(k))
					_drag_before_times.clear()
					_drag_before_lanes.clear()
					for n in state.document.notes:
						var k = EditorNoteUtils.note_key(n as Dictionary)
						if state.selected_keys.has(k):
							_drag_before_times[k] = float(n.get("time", 0.0))
							_drag_before_lanes[k] = int(n.get("lane", 0))
					_drag_start_pos = pos
					_drag_start_time = playfield.world_to_time(pos.y, state.song_time)
					_drag_current_delta_t = 0.0
					_drag_current_delta_lane = 0
					_ghost_visible = false
					_is_dragging = true
					# Clear pencil states
					_pencil_pending_action = ""
					_is_pencil_painting = false
					queue_redraw()
					get_viewport().set_input_as_handled()
					return
			else:
				# Click on empty — clear or start box (spec 2: Select never creates)
				if mb.shift_pressed:
					_is_boxing = true
					_box_start = pos
					_box_end = pos
					queue_redraw()
					get_viewport().set_input_as_handled()
					return
				else:
					if not mb.ctrl_pressed:
						state.clear_selection()
						emit_signal("selection_cleared")
					_is_boxing = true
					_box_start = pos
					_box_end = pos
					queue_redraw()
					get_viewport().set_input_as_handled()
					return
		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			# Pencil painting end
			if _is_pencil_painting:
				_is_pencil_painting = false
				_pencil_pending_action = ""
				get_viewport().set_input_as_handled()
				# Do not return yet — also need to handle potential drag/box below if not pencil?
				_is_dragging = false
				_pencil_is_drag = false
				_pencil_pending_action = ""
				_pencil_pending_hit_key = ""
				_pencil_delete_visited.clear()
				_drag_keys.clear()
				_ghost_visible = false
				queue_redraw()
				playfield.queue_redraw()
				get_viewport().set_input_as_handled()
				return
			if _is_dragging:
				_ghost_visible = false
				if _drag_keys.is_empty():
					_is_dragging = false
					queue_redraw()
					return
				var end_t = playfield.world_to_time(mb.position.y, state.song_time)
				var delta_t = end_t - _drag_start_time
				if state.snap_enabled and state.grid and state.snap_division > 0:
					if not _drag_keys.is_empty():
						var primary = _drag_keys[0]
						var base_t = float(_drag_before_times.get(primary, end_t))
						var ghost_t = base_t + delta_t
						var snapped = state.grid.snap_time(ghost_t, state.snap_division)
						delta_t = snapped - base_t
				var delta_lane = _drag_current_delta_lane
				if absf(delta_t) < 0.005 and delta_lane == 0:
					_is_dragging = false
					_drag_keys.clear()
					_ghost_visible = false
					queue_redraw()
					playfield.queue_redraw()
					get_viewport().set_input_as_handled()
					return
				var snap_div = state.snap_division if state.snap_enabled else 0
				emit_signal("notes_dragged", _drag_keys.duplicate(), delta_t, delta_lane, snap_div)
				_is_dragging = false
				_drag_keys.clear()
				_ghost_visible = false
				queue_redraw()
				playfield.queue_redraw()
				get_viewport().set_input_as_handled()
				return
			if _is_boxing:
				_box_end = mb.position
				var rect = Rect2(_box_start, _box_end - _box_start).abs()
				if rect.size.length() < 4.0:
					pass
				else:
					var keys = _keys_in_rect(rect)
					var additive = mb.ctrl_pressed or mb.meta_pressed or mb.shift_pressed
					emit_signal("notes_box_selected", keys, additive)
				_is_boxing = false
				queue_redraw()
				playfield.queue_redraw()
				get_viewport().set_input_as_handled()
				return
			# Cleanup pencil states if not already
			_pencil_pending_action = ""
			_pencil_pending_hit_key = ""
			_is_pencil_painting = false
			_pencil_delete_visited.clear()
			get_viewport().set_input_as_handled()
			return
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			var hit_key: String = _hit_test(pos)
			if mb.pressed:
				if current_tool == "pencil":
					# Pencil RMB hold paint-delete: start hold even from empty, so subsequent motion over notes deletes (spec 2,4)
					_rmb_hold_active = true
					_rmb_delete_visited.clear()
					if hit_key != "":
						emit_signal("notes_deleted", [hit_key])
						_rmb_delete_visited[hit_key] = true
				else:
					_rmb_hold_active = false
					_rmb_delete_visited.clear()
				# Select RMB → nothing, but consume
				get_viewport().set_input_as_handled()
			else:
				_rmb_hold_active = false
				_rmb_delete_visited.clear()
				get_viewport().set_input_as_handled()
			return
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if state == null or playfield == null:
				return
			var is_ctrl: bool = mb.ctrl_pressed
			if is_ctrl:
				# Ctrl+wheel -> same Scale as slider (spec 11)
				var delta: float = 20.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -20.0
				if state:
					var new_val: float = clampf(state.px_per_sec + delta, 180.0, 720.0)
					var screen: Node = get_parent()
					while screen and not screen.has_method("_on_zoom_changed"):
						screen = screen.get_parent()
					if screen and screen.has_method("_on_zoom_changed"):
						screen.call("_on_zoom_changed", new_val)
				get_viewport().set_input_as_handled()
				return
			else:
				# Wheel over chart -> scroll time (spec 10) — inverted per spec 7: WHEEL_UP → forward
				var scroll_delta: float = 0.5 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -0.5
				if state:
					var new_t: float = clampf(state.song_time + scroll_delta, 0.0, state.duration_s)
					state.song_time = new_t
					var scr: Node = get_parent()
					while scr and not scr.has_method("_go_to_time"):
						scr = scr.get_parent()
					if scr and scr.has_method("_go_to_time"):
						scr.call("_go_to_time", new_t)
					else:
						playfield.queue_redraw()
						queue_redraw()
				get_viewport().set_input_as_handled()
				return
	elif event is InputEventMouseMotion:
		var motion_pos: Vector2 = (event as InputEventMouseMotion).position
		if _is_dragging or _pencil_is_drag:
			var cur_t = playfield.world_to_time((event as InputEventMouseMotion).position.y, state.song_time)
			var delta_t = cur_t - _drag_start_time
			var cur_lane = playfield.get_lane_at_x((event as InputEventMouseMotion).position.x)
			var start_lane = playfield.get_lane_at_x(_drag_start_pos.x)
			var delta_lane = 0
			if cur_lane >= 0 and start_lane >= 0:
				delta_lane = cur_lane - start_lane
			if state.snap_enabled and state.grid and state.snap_division > 0 and not _drag_keys.is_empty():
				var primary = _drag_keys[0]
				var base_t = float(_drag_before_times.get(primary, cur_t))
				var ghost_t = base_t + delta_t
				var snapped = state.grid.snap_time(ghost_t, state.snap_division)
				delta_t = snapped - base_t
			_drag_current_delta_t = delta_t
			_drag_current_delta_lane = delta_lane
			_ghost_visible = true
			queue_redraw()
			playfield.queue_redraw()
			get_viewport().set_input_as_handled()
			return
		if _is_boxing:
			_box_end = (event as InputEventMouseMotion).position
			queue_redraw()
			get_viewport().set_input_as_handled()
			return
		# Pencil paint add on hold (empty area)
		if _is_pencil_painting and current_tool == "pencil":
			var cur_lane: int = playfield.get_lane_at_x(motion_pos.x)
			var cur_t: float = playfield.world_to_time(motion_pos.y, state.song_time)
			var snapped_t: float = cur_t
			if state.snap_enabled and state.grid and state.snap_division > 0:
				snapped_t = state.grid.snap_time(cur_t, state.snap_division)
			# Deduplicate: only add if snapped position/lane changed and cell empty
			if snapped_t != _pencil_paint_last_t or cur_lane != _pencil_paint_last_lane:
				if cur_lane >= 0:
					var hit_at: String = _hit_test(motion_pos)
					if hit_at == "":
						emit_signal("note_add_requested", snapped_t, cur_lane)
						_pencil_paint_last_t = snapped_t
						_pencil_paint_last_lane = cur_lane
			get_viewport().set_input_as_handled()
			return
		# RMB hold paint delete (Pencil) — spec 4
		if _rmb_hold_active and current_tool == "pencil":
			if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
				_rmb_hold_active = false
				_rmb_delete_visited.clear()
			else:
				var rmb_hit: String = _hit_test(motion_pos)
				if rmb_hit != "" and not _rmb_delete_visited.has(rmb_hit):
					emit_signal("notes_deleted", [rmb_hit])
					_rmb_delete_visited[rmb_hit] = true
					get_viewport().set_input_as_handled()
					return

func set_pattern_ghost(visible: bool, notes: Array = [], start_time: float = 0.0) -> void:
	_pattern_ghost_visible = visible
	_pattern_ghost_notes = notes
	_pattern_ghost_start = start_time
	queue_redraw()
	if playfield:
		playfield.queue_redraw()

func clear_pattern_ghost() -> void:
	_pattern_ghost_visible = false
	_pattern_ghost_notes.clear()
	queue_redraw()
	if playfield:
		playfield.queue_redraw()

func _hit_test(pos: Vector2) -> String:
	if state == null or state.document == null or playfield == null:
		return ""
	for n in state.document.notes:
		var t = float(n.get("time", 0.0))
		var lane = int(n.get("lane", 0))
		var y = playfield.note_y(t, state.song_time)
		var x = playfield.get_lane_left_x(lane)
		var w = playfield.get_lane_width_at(lane)
		var rect = Rect2(Vector2(x, y - 10.0), Vector2(w, 20.0))
		rect = rect.grow(3.0)
		if rect.has_point(pos):
			return EditorNoteUtils.note_key(n as Dictionary)
	return ""

func _keys_in_rect(rect: Rect2) -> Array:
	var out: Array = []
	if state == null or state.document == null or playfield == null:
		return out
	var abs_rect = rect.abs()
	for n in state.document.notes:
		var t = float(n.get("time", 0.0))
		var lane = int(n.get("lane", 0))
		var y = playfield.note_y(t, state.song_time)
		var x = playfield.get_lane_left_x(lane)
		var w = playfield.get_lane_width_at(lane)
		var note_rect = Rect2(Vector2(x, y - 10.0), Vector2(w, 20.0))
		if abs_rect.intersects(note_rect):
			out.append(EditorNoteUtils.note_key(n as Dictionary))
	return out

func _range_keys_between(a_key: String, b_key: String) -> Array:
	if state == null or state.document == null:
		return [a_key, b_key]
	var a_idx = -1
	var b_idx = -1
	for i in range(state.document.notes.size()):
		var k = EditorNoteUtils.note_key(state.document.notes[i] as Dictionary)
		if k == a_key:
			a_idx = i
		if k == b_key:
			b_idx = i
	if a_idx < 0 or b_idx < 0:
		return [b_key]
	var lo = mini(a_idx, b_idx)
	var hi = maxi(a_idx, b_idx)
	var out: Array = []
	for i in range(lo, hi + 1):
		out.append(EditorNoteUtils.note_key(state.document.notes[i] as Dictionary))
	return out
