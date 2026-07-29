# scenes/play_modes/mode_card_hero.gd
extends Control

const _PlayModeIds = preload("res://logic/domain/session/play_mode_ids.gd")
const _CORNER_CLIP_SHADER_PATH := "res://shaders/canvas_corner_clip.gdshader"

var mode_key: String = ""
var accent: Color = Color(0.35, 0.86, 0.76, 1.0)
var wash: Color = Color(0.28, 0.72, 0.62, 0.42)
var locked: bool = false

var _overlay_text: String = ""

const REDRAW_INTERVAL := 1.0 / 15.0
const _TOP_CORNER_R := 10.0

var _motion_t: float = 0.0
var _phase_offset: float = 0.0
var _redraw_accum: float = 0.0
var _corner_clip_shader: Shader = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phase_offset = float(hash(mode_key)) * 0.001
	visibility_changed.connect(_on_visibility_changed)
	_update_process_state()
	resized.connect(_on_resized)
	_ensure_corner_clip_material()
	_sync_corner_clip_size()


func _on_resized() -> void:
	_sync_corner_clip_size()
	queue_redraw()


func _ensure_corner_clip_material() -> void:
	if _corner_clip_shader == null:
		if not ResourceLoader.exists(_CORNER_CLIP_SHADER_PATH):
			return
		_corner_clip_shader = load(_CORNER_CLIP_SHADER_PATH) as Shader
	if _corner_clip_shader == null:
		return
	var mat := material as ShaderMaterial
	if mat == null or mat.shader != _corner_clip_shader:
		mat = ShaderMaterial.new()
		mat.shader = _corner_clip_shader
		material = mat
	mat.set_shader_parameter("corner_radius_px", _TOP_CORNER_R)
	mat.set_shader_parameter("mask_top", 1.0)
	mat.set_shader_parameter("mask_bottom", 0.0)


func _sync_corner_clip_size() -> void:
	var mat := material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("rect_size", size)


func _on_visibility_changed() -> void:
	_update_process_state()


func _update_process_state() -> void:
	set_process(is_visible_in_tree())


func configure(p_mode_key: String, p_accent: Color, p_wash: Color, p_locked: bool) -> void:
	mode_key = p_mode_key
	accent = p_accent
	wash = p_wash
	locked = p_locked
	_phase_offset = float(hash(mode_key)) * 0.001
	queue_redraw()


func set_overlay_text(text: String) -> void:
	_overlay_text = str(text).strip_edges()
	queue_redraw()


func _process(delta: float) -> void:
	_motion_t += delta
	_redraw_accum += delta
	if _redraw_accum < REDRAW_INTERVAL:
		return
	_redraw_accum = 0.0
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 1.0 or h <= 1.0:
		return
	var top: Color
	var bottom: Color
	match mode_key:
		_PlayModeIds.LIBRARY:
			top = accent.darkened(0.48)
			bottom = accent.darkened(0.62).lerp(Color(0.05, 0.08, 0.11, 1.0), 0.35)
		_PlayModeIds.ENDLESS:
			top = accent.darkened(0.42)
			bottom = wash.darkened(0.35).lerp(Color(0.05, 0.06, 0.1, 1.0), 0.4)
		_PlayModeIds.MARATHON:
			top = accent.darkened(0.4)
			bottom = wash.darkened(0.3).lerp(Color(0.06, 0.05, 0.09, 1.0), 0.35)
		"drums":
			top = accent.darkened(0.46)
			bottom = accent.darkened(0.58).lerp(Color(0.04, 0.08, 0.09, 1.0), 0.4)
		"bass":
			top = accent.darkened(0.44)
			bottom = wash.darkened(0.28).lerp(Color(0.04, 0.05, 0.1, 1.0), 0.42)
		_:
			top = accent.darkened(0.55)
			bottom = Color(0.05, 0.07, 0.11, 1.0)
	# Match parent card's top corner radius so fill never squares over the frame.
	var top_r := minf(_TOP_CORNER_R, minf(w, h) * 0.5)
	var fill := StyleBoxFlat.new()
	fill.bg_color = top
	fill.set_corner_radius_all(0)
	fill.corner_radius_top_left = int(top_r)
	fill.corner_radius_top_right = int(top_r)
	fill.corner_detail = 12
	fill.anti_aliasing = true
	draw_style_box(fill, Rect2(Vector2.ZERO, size))
	var band_y := h * 0.62
	draw_rect(Rect2(0.0, band_y, w, h - band_y), bottom)

	match mode_key:
		_PlayModeIds.LIBRARY:
			_draw_library_watermark(w, h)
		_PlayModeIds.ENDLESS:
			_draw_endless_watermark(w, h)
		_PlayModeIds.MARATHON:
			_draw_marathon_watermark(w, h)
		"drums":
			_draw_drums_watermark(w, h)
		"bass":
			_draw_bass_watermark(w, h)

	draw_rect(Rect2(0.0, h - 1.0, w, 1.0), Color(0.05, 0.07, 0.11, 1.0))
	if _overlay_text != "":
		_draw_overlay_badge(w, h)


func _draw_overlay_badge(w: float, h: float) -> void:
	var font := ThemeDB.fallback_font
	var font_size := 15
	var text_size := font.get_string_size(_overlay_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pad_x := 10.0
	var pad_y := 5.0
	var box_w := text_size.x + pad_x * 2.0
	var box_h := text_size.y + pad_y * 2.0
	var rect := Rect2(w - box_w - 14.0, 12.0, box_w, box_h)
	var bg := accent.darkened(0.55)
	bg.a = 0.88
	draw_rect(rect, bg)
	draw_rect(rect, accent.lightened(0.05), false, 1.0)
	var text_col := Color(0.96, 0.98, 1.0, 0.96)
	draw_string(font, rect.position + Vector2(pad_x, pad_y + text_size.y * 0.82), _overlay_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_col)


func _draw_library_watermark(w: float, h: float) -> void:
	var lane_count := 4
	var lane_w := w / float(lane_count + 1)
	var lane_col := accent.lightened(0.1)
	lane_col.a = 0.18 if locked else 0.3
	for i in range(lane_count):
		var x := lane_w * float(i + 1)
		draw_line(Vector2(x, h * 0.12), Vector2(x, h * 0.92), lane_col, 1.5)
	for wave_i in range(3):
		var y_base := h * (0.28 + float(wave_i) * 0.18)
		var prev := Vector2(0.0, y_base)
		for step in range(1, 25):
			var t := float(step) / 24.0
			var x := t * w
			var y := y_base + sin(t * 8.0 + _motion_t * 1.2 + float(wave_i)) * 6.0
			var wave_col := wash.lerp(accent, 0.5)
			wave_col.a = 0.14 if locked else 0.24
			draw_line(prev, Vector2(x, y), wave_col, 1.0)
			prev = Vector2(x, y)


func _draw_endless_watermark(w: float, h: float) -> void:
	var center := Vector2(w * 0.5, h * 0.52)
	var base_r := minf(w, h) * 0.34
	var spin := _motion_t * 0.35
	for ring_i in range(4):
		var r := base_r * (0.45 + float(ring_i) * 0.22)
		var ring_col := wash.lerp(accent, 0.35 + float(ring_i) * 0.1)
		ring_col.a = 0.14 if locked else 0.26
		draw_arc(center, r, spin + float(ring_i) * 0.4, spin + PI * 1.6 + float(ring_i) * 0.4, 48, ring_col, 1.5, true)
	# Corner ticks instead of orbiting circles — distinct from library note dots.
	var tick_offsets: Array[Vector2] = [
		Vector2(w * 0.16, h * 0.24),
		Vector2(w * 0.84, h * 0.22),
		Vector2(w * 0.18, h * 0.78),
		Vector2(w * 0.82, h * 0.8),
	]
	for tick_i in range(tick_offsets.size()):
		var base_pos := tick_offsets[tick_i]
		var pulse := sin(_motion_t * 1.4 + float(tick_i) * 1.1) * 2.0
		var tick_col := accent.lightened(0.12)
		tick_col.a = 0.2 if locked else 0.38
		var dir := (base_pos - center).normalized()
		var ortho := Vector2(-dir.y, dir.x)
		var tip := base_pos + dir * (4.0 + pulse)
		draw_line(base_pos - ortho * 3.0, tip, tick_col, 1.4)
		draw_line(base_pos + ortho * 3.0, tip, tick_col, 1.4)


func _draw_marathon_watermark(w: float, h: float) -> void:
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(w * 0.12, h * 0.72),
		Vector2(w * 0.28, h * 0.42),
		Vector2(w * 0.46, h * 0.58),
		Vector2(w * 0.62, h * 0.3),
		Vector2(w * 0.82, h * 0.48),
		Vector2(w * 0.9, h * 0.22),
	])
	var progress := fmod(_motion_t * 0.12, 1.15)
	var route_col := wash.lerp(accent, 0.45)
	route_col.a = 0.22 if locked else 0.42
	var total_len := 0.0
	for i in range(points.size() - 1):
		total_len += points[i].distance_to(points[i + 1])
	var draw_len := total_len * clampf(progress, 0.0, 1.0)
	var walked := 0.0
	var prev := points[0]
	for i in range(points.size() - 1):
		var seg_start := points[i]
		var seg_end := points[i + 1]
		var seg_len := seg_start.distance_to(seg_end)
		if walked + seg_len <= draw_len:
			draw_line(seg_start, seg_end, route_col, 2.0)
			prev = seg_end
			walked += seg_len
		else:
			var remain := draw_len - walked
			if remain > 0.0:
				var dir := (seg_end - seg_start).normalized()
				var partial := seg_start + dir * remain
				draw_line(seg_start, partial, route_col, 2.0)
				prev = partial
			break
	for i in range(points.size()):
		var marker_col := accent if i == 0 else wash.lerp(accent, 0.4)
		marker_col.a = 0.28 if locked else 0.48
		if float(i) / float(points.size() - 1) <= progress:
			var p := points[i]
			if i == points.size() - 1:
				draw_rect(Rect2(p.x - 2.0, p.y - 5.0, 4.0, 10.0), marker_col)
			else:
				draw_rect(Rect2(p.x - 2.5, p.y - 2.5, 5.0, 5.0), marker_col)
	var flag_col := accent.lightened(0.15)
	flag_col.a = 0.28 if locked else 0.45
	draw_line(points[-1], points[-1] + Vector2(0.0, -h * 0.14), flag_col, 1.5)


func _draw_drums_watermark(w: float, h: float) -> void:
	# Falling hit dots across lanes — discrete percussion feel (kept quiet for readability).
	var lane_count := 4
	var lane_w := w / float(lane_count + 1)
	var lane_col := accent.lightened(0.08)
	lane_col.a = 0.08 if locked else 0.14
	for i in range(lane_count):
		var x := lane_w * float(i + 1)
		draw_line(Vector2(x, h * 0.1), Vector2(x, h * 0.9), lane_col, 1.2)
	var hit_phases: Array[float] = [0.0, 0.33, 0.58, 0.82]
	for lane_i in range(lane_count):
		var x := lane_w * float(lane_i + 1)
		for hit_i in range(hit_phases.size()):
			var phase := fmod(_motion_t * 0.18 + hit_phases[hit_i] + float(lane_i) * 0.17 + _phase_offset, 1.0)
			var y := h * (0.12 + phase * 0.72)
			var pulse := 1.0 - absf(phase - 0.55) * 1.4
			pulse = clampf(pulse, 0.25, 1.0)
			var r := (2.0 + float((lane_i + hit_i) % 3) * 0.6) * pulse
			var hit_col := wash.lerp(accent, 0.55 + float(hit_i % 2) * 0.15)
			hit_col.a = (0.08 if locked else 0.16) * pulse
			draw_circle(Vector2(x, y), r, hit_col)


func _draw_bass_watermark(w: float, h: float) -> void:
	# Sustained waveform + soft hold bars — continuous bass feel (kept quiet for readability).
	var wave_col := wash.lerp(accent, 0.55)
	wave_col.a = 0.08 if locked else 0.14
	for wave_i in range(2):
		var y_base := h * (0.34 + float(wave_i) * 0.22)
		var amp := 5.0 + float(wave_i) * 2.0
		var prev := Vector2(0.0, y_base)
		for step in range(1, 33):
			var t := float(step) / 32.0
			var x := t * w
			var y := y_base + sin(t * 6.5 + _motion_t * 0.9 + float(wave_i) * 1.4 + _phase_offset) * amp
			draw_line(prev, Vector2(x, y), wave_col, 1.15 if wave_i == 0 else 0.9)
			prev = Vector2(x, y)
	var hold_col := accent.lightened(0.1)
	hold_col.a = 0.07 if locked else 0.12
	var holds: Array[Dictionary] = [
		{"x": w * 0.18, "y": h * 0.22, "len": h * 0.28},
		{"x": w * 0.52, "y": h * 0.3, "len": h * 0.36},
		{"x": w * 0.78, "y": h * 0.18, "len": h * 0.42},
	]
	for hold in holds:
		var x: float = hold["x"]
		var y0: float = hold["y"]
		var len_h: float = hold["len"]
		var sway := sin(_motion_t * 0.9 + x * 0.02) * 1.2
		draw_line(Vector2(x + sway, y0), Vector2(x + sway, y0 + len_h), hold_col, 2.4)
		var head := accent.lightened(0.18)
		head.a = 0.12 if locked else 0.2
		draw_circle(Vector2(x + sway, y0), 2.6, head)
