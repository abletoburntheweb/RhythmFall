# scenes/chart_editor/chart_editor_ruler.gd
extends Control

# Декоративный ruler для мокапа: горизонтальная шкала тактов + индикатор плейхеда.
# Не меняет логику Y=time, просто визуально повторяет мокап (такты 25-30 и тд).

signal seek_requested(time: float)

var state = null
var playfield = null
var _dragging: bool = false

func setup(p_state, p_playfield) -> void:
	state = p_state
	playfield = p_playfield
	# Ensure we receive mouse
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if state == null:
		return
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				var t = _x_to_time(mb.position.x)
				emit_signal("seek_requested", t)
				get_viewport().set_input_as_handled()
			else:
				_dragging = false
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		var t = _x_to_time((event as InputEventMouseMotion).position.x)
		emit_signal("seek_requested", t)
		get_viewport().set_input_as_handled()

func _x_to_time(x: float) -> float:
	var dur = state.duration_s if state and state.duration_s > 0.0 else 200.0
	if size.x <= 0:
		return 0.0
	var frac = clampf(x / size.x, 0.0, 1.0)
	return frac * dur

func _draw() -> void:
	if state == null:
		_draw_placeholder()
		return
	var w = size.x
	var h = size.y
	if w <= 0 or h <= 0:
		return
	# BG
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.13, 0.17, 1.0))
	# Timeline: measure/beatOverview + note density
	var dur = state.duration_s if state.duration_s > 0.0 else 200.0
	if state.grid:
		var measures = state.grid.measure_times_in_range(0.0, dur)
		var step = 1
		if measures.size() > 48:
			step = int(ceil(measures.size() / 48.0))
		for i in range(0, measures.size(), step):
			var mt = measures[i]
			var x = (mt / dur) * w if dur > 0.0 else 0.0
			draw_line(Vector2(x, h * 0.35), Vector2(x, h), Color(1, 1, 1, 0.22), 1.2)
			var beat_step = state.grid.beat_interval
			if beat_step > 0 and step == 1:
				for b in range(1, 4):
					var bt = mt + float(b) * beat_step
					if bt >= dur:
						break
					var bx = (bt / dur) * w
					draw_line(Vector2(bx, h * 0.62), Vector2(bx, h), Color(1, 1, 1, 0.12), 1.0)
			var m_idx = state.grid.measure_index(mt) + 1
			var label = str(m_idx)
			var font = ThemeDB.fallback_font
			var fs = 11
			if font:
				draw_string(font, Vector2(x + 4, 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.72, 0.78, 0.88, 0.95))
	# Note density markers (compact)
	if state.document and state.document.notes.size() > 0:
		for n in state.document.notes:
			var t = float(n.get("time", 0.0))
			var x = (t / dur) * w if dur > 0 else 0
			var drum = String(n.get("drum", "kick")).to_lower()
			var col = EditorNoteUtils.color_for_drum(drum)
			col.a = 0.55
			# Small tick
			draw_rect(Rect2(Vector2(x, h * 0.78), Vector2(2, 6)), col)
		# Selected notes highlighted
		for n in state.document.notes:
			var k = EditorNoteUtils.note_key(n as Dictionary)
			if state.selected_keys.has(k):
				var t = float(n.get("time", 0.0))
				var x = (t / dur) * w
				draw_rect(Rect2(Vector2(x - 1, h * 0.74), Vector2(4, 10)), Color(1,1,1,0.95))
	# Playhead
	var cur_t = state.song_time
	var dur2 = dur
	var px = clampf((cur_t / dur2) * w, 0, w)
	draw_line(Vector2(px, 0), Vector2(px, h), Color(0.95, 0.85, 0.35, 0.95), 1.8)
	# Time label
	var time_str = _format_mmss(cur_t)
	var font2 = ThemeDB.fallback_font
	if font2:
		var tw = font2.get_string_size(time_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		var tx = clampf(px - tw * 0.5, 2, w - tw - 2)
		draw_rect(Rect2(Vector2(tx - 3, 2), Vector2(tw + 6, 12)), Color(0.95, 0.85, 0.35, 1.0))
		draw_string(font2, Vector2(tx, 11), time_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.08, 0.08, 0.11, 1.0))
	# Bottom ticks
	for i in range(0, int(w), 8):
		var alpha = 0.18 if i % 40 == 0 else 0.08
		draw_line(Vector2(float(i), h - 1), Vector2(float(i), h - 4), Color(1, 1, 1, alpha), 1.0)

func _draw_placeholder() -> void:
	var w = size.x
	var h = size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.13, 0.17, 1.0))
	for i in range(0, int(w), 16):
		var x = float(i)
		draw_line(Vector2(x, h * 0.5), Vector2(x, h), Color(1,1,1,0.12), 1.0)
	var font = ThemeDB.fallback_font
	if font:
		draw_string(font, Vector2(8, 12), "Takte — ruler", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6,0.65,0.75,1.0))

func _format_mmss(t: float) -> String:
	var total_ms = int(round(maxf(0.0, t) * 1000.0))
	var mins = total_ms / 60000
	var secs = (total_ms % 60000) / 1000
	var ms = total_ms % 1000
	return "%d:%02d.%03d" % [mins, secs, ms]
