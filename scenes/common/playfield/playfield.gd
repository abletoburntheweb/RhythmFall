# scenes/common/playfield/playfield.gd
extends Panel
class_name GamePlayfield

# Общий Playfield — 1:1 с game_screen.tscn:Playfield, без игровой логики
const DEFAULT_HIT_RATIO := 0.88
const DEFAULT_SPEED := 6.0
const GAME_UPDATE_DELTA := 1.0 / 60.0
const GRID_BEAT_ALPHA := 0.18
const GRID_MEASURE_ALPHA := 0.32
const NOTE_H := 20.0

const ChartEditorStateClass = preload("res://logic/domain/editor/chart_editor_state.gd")
const PerfTrace = preload("res://logic/utils/perf_trace.gd")

var _frame_diag_active: bool = false
var _frame_diag_start_ms: int = 0
var _frame_diag_next_ms: int = 0
var _frame_diag_draw_count: int = 0
var _frame_diag_draw_time: int = 0
var _frame_diag_redraw_count: int = 0
var _frame_diag_notes_drawn: int = 0
var _frame_diag_process_count: int = 0

var lanes: int = 5
var hit_ratio: float = DEFAULT_HIT_RATIO
var speed: float = DEFAULT_SPEED
var hit_y: int = 0
var is_editor: bool = false
var editor_state: ChartEditorStateClass = null
var hidden_note_keys: Dictionary = {}
var note_color_mode: int = 0 # 0 drum, 1 lane
var lane_colors_cache: Array[Color] = []
var hit_effects_enabled: bool = true
var _lane_flash_until: Dictionary = {} # lane -> time

@onready var lanes_container: Control = $LanesContainer
@onready var notes_container: Node2D = $NotesContainer
@onready var hit_zone: ColorRect = $HitZone
@onready var bottom_hud: Control = $BottomHud

func _ready() -> void:
	set_process(true)
	_setup_rounded_clip(self)
	call_deferred("_deferred_update")
	_start_frame_diag()

func _deferred_update() -> void:
	if is_inside_tree():
		_update_lane_layout()

func setup(p_lanes: int = 5, p_hit_ratio: float = DEFAULT_HIT_RATIO, p_speed: float = DEFAULT_SPEED, p_is_editor: bool = false) -> void:
	lanes = clampi(p_lanes, 3, 10)
	hit_ratio = clampf(p_hit_ratio, 0.05, 0.95)
	speed = clampf(p_speed, 1.0, 30.0)
	is_editor = p_is_editor
	if bottom_hud:
		bottom_hud.visible = false # Editor uses fixed playfield, not gameplay HUD
	if notes_container:
		notes_container.visible = false # Editor draws via _draw, not nodes
	# HitZone видна и в редакторе (как в GameScreen) — fixed
	if hit_zone:
		hit_zone.visible = true
	_update_lane_layout()
	queue_redraw()

func set_editor_state(state) -> void:
	editor_state = state
	queue_redraw()

func set_hidden_keys(keys: Dictionary) -> void:
	hidden_note_keys = keys.duplicate()
	queue_redraw()

func set_note_color_mode(mode: int) -> void:
	note_color_mode = clampi(mode, 0, 1)
	queue_redraw()

func set_lane_colors_cache(colors: Array) -> void:
	lane_colors_cache.clear()
	for c in colors:
		if c is Color:
			lane_colors_cache.append(c)
	queue_redraw()

func set_hit_effects_enabled(enabled: bool) -> void:
	hit_effects_enabled = enabled

var lane_highlight_enabled: bool = true
func set_lane_highlight_enabled(enabled: bool) -> void:
	lane_highlight_enabled = enabled
	if not enabled:
		for i in range(lanes):
			var hl = lanes_container.get_node_or_null("Lane%dHighlight" % i) as ColorRect if lanes_container else null
			if hl:
				hl.visible = false
	queue_redraw()

func clear_lane_highlights() -> void:
	_lane_flash_until.clear()
	_update_lane_highlight_flash()

func _process(_delta: float) -> void:
	_frame_diag_process_count += 1
	if _lane_flash_until.size() > 0:
		_update_lane_highlight_flash()
	if _frame_diag_active:
		_frame_diag_log()

func flash_lane(lane: int, duration: float = 0.12) -> void:
	if lane < 0 or lane >= lanes:
		return
	if not hit_effects_enabled:
		return
	if not lane_highlight_enabled:
		return
	_lane_flash_until[lane] = Time.get_ticks_msec() / 1000.0 + duration
	_update_lane_highlight_flash()
	if is_inside_tree():
		await get_tree().create_timer(duration).timeout
		if is_instance_valid(self):
			_update_lane_highlight_flash()

func _update_lane_highlight_flash() -> void:
	if lanes_container == null:
		return
	var now = Time.get_ticks_msec() / 1000.0
	for i in range(lanes):
		var hl = lanes_container.get_node_or_null("Lane%dHighlight" % i) as ColorRect
		if hl:
			var until = float(_lane_flash_until.get(i, 0.0))
			hl.visible = until > now

func set_lanes(n: int) -> void:
	lanes = clampi(n, 3, 10)
	_update_lane_layout()

func set_hit_ratio(r: float) -> void:
	hit_ratio = clampf(r, 0.05, 0.95)
	_update_lane_layout()

func set_speed(s: float) -> void:
	speed = clampf(s, 1.0, 30.0)

func get_hit_y() -> int:
	return hit_y

func get_playfield_size() -> Vector2:
	return size

func get_playfield_height() -> float:
	return size.y

func get_note_pixels_per_sec() -> float:
	return speed * (1.0 / GAME_UPDATE_DELTA)

func _lane_left_edges_px(playfield_w: float, lane_count: int) -> PackedFloat32Array:
	var total_px = int(round(maxf(playfield_w, float(lane_count))))
	total_px = maxi(total_px, lane_count)
	var base_w = total_px / lane_count
	var rem = total_px % lane_count
	var edges = PackedFloat32Array()
	edges.resize(lane_count + 1)
	var cum = 0
	for i in range(lane_count):
		edges[i] = float(cum)
		cum += base_w + (1 if i < rem else 0)
	edges[lane_count] = playfield_w
	return edges

func get_lane_edges() -> PackedFloat32Array:
	return _lane_left_edges_px(size.x, lanes)

func get_lane_width_at(lane: int) -> float:
	var edges = get_lane_edges()
	if lane < 0 or lane >= edges.size() - 1:
		return size.x / float(maxi(1, lanes))
	return edges[lane + 1] - edges[lane]

func get_lane_left_x(lane: int) -> float:
	var edges = get_lane_edges()
	if lane < 0 or lane >= edges.size() - 1:
		return 0.0
	return edges[lane]

func get_lane_at_x(x: float) -> int:
	var edges = get_lane_edges()
	for i in range(edges.size() - 1):
		if x >= edges[i] and x < edges[i + 1]:
			return i
	if is_equal_approx(x, edges[edges.size() - 1]):
		return edges.size() - 2
	return -1

func get_lane_rect(lane: int) -> Rect2:
	var x = get_lane_left_x(lane)
	var w = get_lane_width_at(lane)
	return Rect2(Vector2(x, 0), Vector2(w, size.y))

func note_y(chart_time: float, song_time: float) -> float:
	var px = get_note_pixels_per_sec()
	return note_y_for_chart_time(chart_time, song_time, float(hit_y), px)

func note_y_for_chart_time(chart_time: float, song_time: float, hit_y_f: float, px_per_sec: float) -> float:
	# Единая gameplay-модель и для Game, и для Editor (TOP→BOTTOM к HitZone)
	return hit_y_f - (chart_time - song_time) * px_per_sec

func world_to_time(world_y: float, song_time: float) -> float:
	var px = get_note_pixels_per_sec()
	return (float(hit_y) - world_y) / px + song_time

func _start_frame_diag() -> void:
	if not PerfTrace.is_enabled(PerfTrace.Level.DETAIL):
		return
	_frame_diag_active = true
	_frame_diag_start_ms = Time.get_ticks_msec()
	_frame_diag_next_ms = _frame_diag_start_ms
	_frame_diag_draw_count = 0
	_frame_diag_draw_time = 0
	_frame_diag_redraw_count = 0
	_frame_diag_notes_drawn = 0
	_frame_diag_process_count = 0

func _frame_print(msg: String) -> void:
	var c := get_tree().root.get_node_or_null("Console") if get_tree() and get_tree().root else null
	if c and c.has_method("print_line"):
		c.call("print_line", msg)

func _frame_diag_log() -> void:
	var now := Time.get_ticks_msec()
	if now < _frame_diag_next_ms:
		return
	var elapsed := float(now - _frame_diag_start_ms) / 1000.0
	var avg_draw := float(_frame_diag_draw_time) / float(maxi(_frame_diag_draw_count,1)) / 1000.0
	_frame_print("[PERF][FRAME] playfield t=%.2f draw=%d draw_time=%.2fms notes=%d redraw=%d process=%d" % [elapsed, _frame_diag_draw_count, avg_draw, _frame_diag_notes_drawn, _frame_diag_redraw_count, _frame_diag_process_count])
	_frame_diag_next_ms = now + 100
	if now - _frame_diag_start_ms >= 1500:
		_frame_diag_active = false
		_frame_print("[PERF][FRAME] playfield summary draws=%d avg_draw=%.2fms" % [_frame_diag_draw_count, avg_draw])

func _draw() -> void:
	var _t_draw := PerfTrace.begin("perf.detail.chart_editor.playfield_draw")
	_frame_diag_draw_count += 1
	_frame_diag_redraw_count += 1
	var _t_start := Time.get_ticks_usec()
	if is_editor and editor_state != null:
		_draw_editor()
	var _elapsed := Time.get_ticks_usec() - _t_start
	_frame_diag_draw_time += _elapsed
	PerfTrace.end("perf.detail.chart_editor.playfield_draw", _t_draw)
	if _frame_diag_active:
		_frame_diag_log()

func _draw_editor() -> void:
	if editor_state == null or editor_state.document == null:
		return
	var w = size.x
	var h = size.y
	var px = get_note_pixels_per_sec()
	var song_t = float(editor_state.song_time) if editor_state else 0.0
	# Видимое временное окно: top -> bottom относительно HitZone
	var t_top = world_to_time(0.0, song_t)
	var t_bottom = world_to_time(h, song_t)
	var t0 = minf(t_top, t_bottom)
	var t1 = maxf(t_top, t_bottom)
	# Grid — uses snap as source of truth when enabled (visual density matches division)
	if editor_state and editor_state.grid:
		if editor_state.snap_enabled and editor_state.snap_division > 0 and editor_state.grid.beat_interval > 0.0:
			var snap_div: int = int(editor_state.snap_division)
			var snap_step: float = editor_state.grid.beat_interval * 4.0 / float(snap_div)
			if snap_step > 0.001:
				var t_start: float = floor((t0 - 0.5) / snap_step) * snap_step
				var t: float = t_start
				var max_iter: int = 5000
				var iter: int = 0
				while t <= t1 + 0.5 and iter < max_iter:
					var y: float = note_y(t, song_t)
					if y >= -4 and y <= h + 4:
						var is_measure := false
						if editor_state.grid.measure_duration > 0.0:
							var rel_m := fmod(t - editor_state.grid.first_measure_start, editor_state.grid.measure_duration)
							if rel_m < 0:
								rel_m += editor_state.grid.measure_duration
							is_measure = rel_m < 0.001 or (editor_state.grid.measure_duration - rel_m) < 0.001
						var is_beat := false
						if not is_measure:
							var rel_beat := fmod(t - editor_state.grid.first_measure_start, editor_state.grid.beat_interval)
							if rel_beat < 0:
								rel_beat += editor_state.grid.beat_interval
							is_beat = rel_beat < 0.001 or (editor_state.grid.beat_interval - rel_beat) < 0.001
						var col: Color
						var width: float
						if is_measure:
							col = Color(1,1,1, GRID_MEASURE_ALPHA)
							width = 1.5
						elif is_beat:
							col = Color(1,1,1, GRID_BEAT_ALPHA)
							width = 1.0
						else:
							var a := 0.09
							if snap_div == 1:
								a = 0.14
							elif snap_div == 2:
								a = 0.12
							elif snap_div == 32:
								a = 0.06
							col = Color(1,1,1, a)
							width = 0.8
						draw_line(Vector2(0, y), Vector2(w, y), col, width)
					t += snap_step
					iter += 1
		else:
			# OFF — snap disabled, show only faint musical grid (or hide snap part)
			var beats = editor_state.grid.beat_times_in_range(t0 - 0.5, t1 + 0.5)
			for bt in beats:
				var y = note_y(bt, song_t)
				if y < -4 or y > h + 4:
					continue
				var is_measure = false
				if editor_state.grid.measure_duration > 0.0:
					var rel = bt - editor_state.grid.first_measure_start
					var m = int(floor(rel / editor_state.grid.measure_duration + 0.001))
					var mt = editor_state.grid.first_measure_start + float(m) * editor_state.grid.measure_duration
					is_measure = absf(bt - mt) < 0.001
				var col = Color(1,1,1, GRID_MEASURE_ALPHA * 0.45) if is_measure else Color(1,1,1, GRID_BEAT_ALPHA * 0.45)
				var width = 1.5 if is_measure else 1.0
				draw_line(Vector2(0, y), Vector2(w, y), col, width)
	# HitZone already drawn by _update_lane_layout, but ensure lane lines visible via that
	# Notes — только видимые в окне (+ margin)
	var doc = editor_state.document
	if doc == null or doc.notes.is_empty():
		return
	for n in doc.notes:
		if _frame_diag_active:
			_frame_diag_notes_drawn += 1
		var key = EditorNoteUtils.note_key(n as Dictionary)
		if hidden_note_keys.has(key):
			continue
		var t = float(n.get("time", 0.0))
		if t < t0 - 1.0 or t > t1 + 1.0:
			continue
		var lane = int(n.get("lane", 0))
		var drum = String(n.get("drum", "kick")).to_lower()
		var y = note_y(t, song_t)
		if y < -14 or y > h + 14:
			continue
		var x = get_lane_left_x(lane)
		var lane_w = get_lane_width_at(lane)
		var rect = Rect2(Vector2(x + 1.0, y - NOTE_H * 0.5), Vector2(lane_w - 2.0, NOTE_H))
		var base_col: Color
		if note_color_mode == 1 and lane_colors_cache.size() > 0:
			var idx = clampi(lane, 0, lane_colors_cache.size() - 1)
			if lane < lane_colors_cache.size():
				base_col = lane_colors_cache[lane]
			else:
				base_col = lane_colors_cache[idx % lane_colors_cache.size()]
		else:
			base_col = EditorNoteUtils.color_for_drum(drum)
		var selected = editor_state.selected_keys.has(key)
		if selected:
			base_col = base_col.lightened(0.35)
			draw_rect(rect.grow(2.0), Color(1,1,1,0.95), false, 2.0)
		draw_rect(rect, base_col, true)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2.0)), Color(1,1,1,0.35), true)
	# Ghost handled by overlay

func _update_lane_layout() -> void:
	if not is_inside_tree():
		return
	if lanes_container == null:
		lanes_container = get_node_or_null("LanesContainer") as Control
	if hit_zone == null:
		hit_zone = get_node_or_null("HitZone") as ColorRect
	if notes_container == null:
		notes_container = get_node_or_null("NotesContainer") as Node2D
	if bottom_hud == null:
		bottom_hud = get_node_or_null("BottomHud") as Control
	if bottom_hud:
		bottom_hud.visible = false
	if hit_zone:
		hit_zone.visible = true
		hit_zone.anchor_top = hit_ratio
		hit_zone.anchor_bottom = hit_ratio + 0.027
		hit_zone.anchor_left = 0.0
		hit_zone.anchor_right = 1.0
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var playfield_w = size.x
	var playfield_h = size.y
	if playfield_w <= 0 or playfield_h <= 0:
		return
	_ensure_lane_ui_capacity(lanes)
	var edges = _lane_left_edges_px(playfield_w, lanes)
	for i in range(lanes):
		var lane_node = lanes_container.get_node_or_null("Lane%d" % i) as ColorRect
		var hl_node = lanes_container.get_node_or_null("Lane%dHighlight" % i) as ColorRect
		if lane_node:
			lane_node.position = Vector2(edges[i], 0)
			lane_node.visible = false # Lane markers hidden in both modes (HitZone is primary)
		if hl_node:
			hl_node.position = Vector2(edges[i], 0)
			hl_node.size = Vector2(edges[i+1]-edges[i], playfield_h)
			hl_node.visible = false
	for i in range(4):
		var div = lanes_container.get_node_or_null("LaneDivider%d" % i) as ColorRect
		if div:
			if i + 1 < lanes:
				div.visible = true
				div.position = Vector2(edges[i+1] - 1.0, 0)
				div.size = Vector2(2, playfield_h)
			else:
				div.visible = false
	# HitY — canonical, одинаковый для Game и Editor
	if hit_zone and is_inside_tree():
		# Use ratio directly (fixed viewport), no scroll compensation
		hit_y = int(playfield_h * hit_ratio)
		if hit_y <= 0:
			hit_y = int(0.88 * playfield_h)

func set_hit_y_viewport(viewport_h: float) -> void:
	if is_editor:
		hit_y = int(viewport_h * hit_ratio)

func _ensure_lane_ui_capacity(needed: int) -> void:
	if lanes_container == null:
		return
	for i in range(5, needed):
		var lane_name = "Lane%d" % i
		if lanes_container.get_node_or_null(lane_name) == null:
			var src = lanes_container.get_node_or_null("Lane0") as ColorRect
			if src:
				var nl = src.duplicate() as ColorRect
				nl.name = lane_name
				lanes_container.add_child(nl)
		var hl_name = "Lane%dHighlight" % i
		if lanes_container.get_node_or_null(hl_name) == null:
			var src_hl = lanes_container.get_node_or_null("Lane0Highlight") as ColorRect
			if src_hl:
				var nhl = src_hl.duplicate() as ColorRect
				nhl.name = hl_name
				lanes_container.add_child(nhl)
		var div_name = "LaneDivider%d" % (i - 1) if i > 0 else ""
		if i > 0 and i < needed and div_name != "" and lanes_container.get_node_or_null(div_name) == null:
			var src_div = lanes_container.get_node_or_null("LaneDivider0") as ColorRect
			if src_div:
				var nd = src_div.duplicate() as ColorRect
				nd.name = div_name
				lanes_container.add_child(nd)

func _setup_rounded_clip(pf: Control) -> void:
	var style = pf.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		var flat = (style as StyleBoxFlat).duplicate() as StyleBoxFlat
		flat.bg_color = Color(flat.bg_color.r, flat.bg_color.g, flat.bg_color.b, 1.0)
		pf.add_theme_stylebox_override("panel", flat)
	if pf.has_method("set_clip_children_mode"):
		pf.clip_children = Control.CLIP_CHILDREN_AND_DRAW

func add_note_visual(c: Control) -> void:
	if notes_container:
		notes_container.add_child(c)

func clear_notes() -> void:
	if notes_container:
		for ch in notes_container.get_children():
			ch.queue_free()

func get_notes_container() -> Node2D:
	return notes_container
