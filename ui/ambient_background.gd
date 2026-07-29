# ui/ambient_background.gd
extends Control
class_name AmbientBackground

const DOT_COUNT := 14
const DOT_RADIUS_MIN := 1.0
const DOT_RADIUS_MAX := 2.6
const EDGE_MARGIN := 40.0
const WASH_LERP_SEC := 1.15

const DOT_COLORS: Array[Color] = [
	Color(0.55, 0.88, 0.8, 1.0),
	Color(0.62, 0.76, 0.95, 1.0),
	Color(0.72, 0.68, 0.92, 1.0),
	Color(0.82, 0.78, 0.62, 1.0),
]

const WASH_PROFILES: Dictionary = {
	&"menu": [
		{"anchor": Vector2(0.14, 0.18), "radius": 320.0, "color": Color(0.35, 0.82, 0.72, 0.028)},
		{"anchor": Vector2(0.86, 0.62), "radius": 280.0, "color": Color(0.55, 0.45, 0.92, 0.022)},
		{"anchor": Vector2(0.5, 0.88), "radius": 240.0, "color": Color(0.42, 0.58, 0.88, 0.018)},
	],
	&"song_select": [
		{"anchor": Vector2(0.08, 0.42), "radius": 300.0, "color": Color(0.38, 0.72, 0.92, 0.03)},
		{"anchor": Vector2(0.92, 0.28), "radius": 340.0, "color": Color(0.58, 0.42, 0.9, 0.026)},
		{"anchor": Vector2(0.62, 0.84), "radius": 220.0, "color": Color(0.35, 0.82, 0.74, 0.02)},
	],
	&"victory": [
		{"anchor": Vector2(0.5, 0.22), "radius": 360.0, "color": Color(0.38, 0.86, 0.76, 0.034)},
		{"anchor": Vector2(0.18, 0.72), "radius": 260.0, "color": Color(0.92, 0.72, 0.38, 0.018)},
		{"anchor": Vector2(0.84, 0.58), "radius": 280.0, "color": Color(0.48, 0.62, 0.95, 0.022)},
	],
	&"series_finish_endless": [
		{"anchor": Vector2(0.5, 0.2), "radius": 360.0, "color": Color(0.52, 0.34, 0.92, 0.038)},
		{"anchor": Vector2(0.16, 0.7), "radius": 270.0, "color": Color(0.42, 0.28, 0.78, 0.024)},
		{"anchor": Vector2(0.86, 0.55), "radius": 290.0, "color": Color(0.62, 0.48, 0.95, 0.022)},
	],
	&"series_finish_marathon": [
		{"anchor": Vector2(0.5, 0.2), "radius": 360.0, "color": Color(0.79, 0.57, 0.35, 0.036)},
		{"anchor": Vector2(0.16, 0.72), "radius": 270.0, "color": Color(0.62, 0.44, 0.28, 0.022)},
		{"anchor": Vector2(0.86, 0.56), "radius": 290.0, "color": Color(0.92, 0.72, 0.42, 0.02)},
	],
	&"defeat": [
		{"anchor": Vector2(0.5, 0.35), "radius": 340.0, "color": Color(0.42, 0.28, 0.48, 0.03)},
		{"anchor": Vector2(0.16, 0.68), "radius": 250.0, "color": Color(0.55, 0.35, 0.55, 0.02)},
		{"anchor": Vector2(0.82, 0.78), "radius": 230.0, "color": Color(0.28, 0.34, 0.62, 0.018)},
	],
	&"profile": [
		{"anchor": Vector2(0.22, 0.24), "radius": 300.0, "color": Color(0.42, 0.58, 0.9, 0.026)},
		{"anchor": Vector2(0.78, 0.5), "radius": 290.0, "color": Color(0.52, 0.46, 0.88, 0.022)},
		{"anchor": Vector2(0.48, 0.9), "radius": 210.0, "color": Color(0.35, 0.74, 0.82, 0.016)},
	],
	&"shop": [
		{"anchor": Vector2(0.12, 0.55), "radius": 310.0, "color": Color(0.92, 0.68, 0.34, 0.022)},
		{"anchor": Vector2(0.88, 0.32), "radius": 280.0, "color": Color(0.55, 0.42, 0.88, 0.024)},
		{"anchor": Vector2(0.5, 0.82), "radius": 250.0, "color": Color(0.38, 0.78, 0.72, 0.018)},
	],
	&"achievements": [
		{"anchor": Vector2(0.5, 0.16), "radius": 330.0, "color": Color(0.62, 0.48, 0.92, 0.028)},
		{"anchor": Vector2(0.1, 0.62), "radius": 260.0, "color": Color(0.38, 0.8, 0.78, 0.02)},
		{"anchor": Vector2(0.9, 0.72), "radius": 240.0, "color": Color(0.48, 0.56, 0.9, 0.02)},
	],
	&"play_modes": [
		{"anchor": Vector2(0.16, 0.28), "radius": 320.0, "color": Color(0.35, 0.86, 0.76, 0.032)},
		{"anchor": Vector2(0.5, 0.86), "radius": 280.0, "color": Color(0.62, 0.48, 0.95, 0.028)},
		{"anchor": Vector2(0.84, 0.38), "radius": 300.0, "color": Color(0.79, 0.57, 0.35, 0.024)},
	],
	&"play_modes_endless": [
		{"anchor": Vector2(0.18, 0.24), "radius": 340.0, "color": Color(0.52, 0.34, 0.92, 0.036)},
		{"anchor": Vector2(0.82, 0.42), "radius": 300.0, "color": Color(0.42, 0.28, 0.78, 0.028)},
		{"anchor": Vector2(0.55, 0.88), "radius": 250.0, "color": Color(0.58, 0.38, 0.88, 0.02)},
	],
	&"play_modes_marathon": [
		{"anchor": Vector2(0.2, 0.22), "radius": 330.0, "color": Color(0.79, 0.57, 0.35, 0.028)},
		{"anchor": Vector2(0.78, 0.48), "radius": 290.0, "color": Color(0.62, 0.44, 0.28, 0.022)},
		{"anchor": Vector2(0.48, 0.86), "radius": 240.0, "color": Color(0.52, 0.38, 0.24, 0.016)},
	],
	&"help": [
		{"anchor": Vector2(0.2, 0.2), "radius": 280.0, "color": Color(0.4, 0.7, 0.88, 0.022)},
		{"anchor": Vector2(0.8, 0.65), "radius": 260.0, "color": Color(0.5, 0.5, 0.82, 0.018)},
		{"anchor": Vector2(0.5, 0.5), "radius": 200.0, "color": Color(0.35, 0.62, 0.72, 0.012)},
	],
}

var _dots: Array[Dictionary] = []
var _motion_tweens: Array[Tween] = []
var _motion_active: bool = true
var _particles_enabled: bool = true
var _rng := RandomNumberGenerator.new()
var _wash_from: Array[Dictionary] = []
var _wash_to: Array[Dictionary] = []
var _wash_blend: float = 1.0
var _active_profile: StringName = &"menu"


func _ready() -> void:
	_rng.randomize()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_wash_from = _profile_washes(&"menu")
	_wash_to = _wash_from.duplicate(true)
	_wash_blend = 1.0
	resized.connect(_on_resized)
	call_deferred("_bootstrap")


func _bootstrap() -> void:
	_reset_dots()
	if _motion_active:
		_start_motion()


func set_motion_active(active: bool) -> void:
	_motion_active = active
	visible = active
	set_process(active and _particles_enabled)
	if active:
		_start_motion()
	else:
		_stop_motion()
		queue_redraw()


func set_particles_enabled(enabled: bool) -> void:
	_particles_enabled = enabled
	if not _motion_active:
		return
	set_process(enabled)
	if enabled:
		if _dots.is_empty():
			_reset_dots()
		_start_motion()
	else:
		_stop_motion()
	queue_redraw()


func set_screen_profile(profile: StringName) -> void:
	var key := profile if WASH_PROFILES.has(profile) else &"menu"
	if key == _active_profile and _wash_blend >= 0.999:
		return
	_active_profile = key
	_wash_from = _sample_washes(_wash_blend)
	_wash_to = _profile_washes(key)
	_wash_blend = 0.0
	var blend_tw := create_tween()
	_motion_tweens.append(blend_tw)
	blend_tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	blend_tw.tween_method(_set_wash_blend, 0.0, 1.0, WASH_LERP_SEC)
	blend_tw.tween_callback(queue_redraw)


func _set_wash_blend(value: float) -> void:
	_wash_blend = value
	queue_redraw()


func _profile_washes(profile: StringName) -> Array[Dictionary]:
	var raw: Variant = WASH_PROFILES.get(profile, WASH_PROFILES[&"menu"])
	var out: Array[Dictionary] = []
	if raw is Array:
		for entry in raw:
			if entry is Dictionary:
				out.append((entry as Dictionary).duplicate(true))
	if out.is_empty():
		return _profile_washes(&"menu")
	return out


func _sample_washes(t: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var count := maxi(_wash_from.size(), _wash_to.size())
	for i in count:
		var a: Dictionary = _wash_from[i] if i < _wash_from.size() else _wash_to[i]
		var b: Dictionary = _wash_to[i] if i < _wash_to.size() else _wash_from[i]
		out.append(_lerp_wash_spec(a, b, t))
	return out


func _lerp_wash_spec(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var anchor_a: Vector2 = a.get("anchor", Vector2.ZERO)
	var anchor_b: Vector2 = b.get("anchor", Vector2.ZERO)
	var color_a: Color = a.get("color", Color.WHITE)
	var color_b: Color = b.get("color", Color.WHITE)
	return {
		"anchor": anchor_a.lerp(anchor_b, t),
		"radius": lerpf(float(a.get("radius", 0.0)), float(b.get("radius", 0.0)), t),
		"color": color_a.lerp(color_b, t),
	}


func _plot_rect() -> Rect2:
	var w := maxf(1.0, size.x)
	var h := maxf(1.0, size.y)
	if w <= 1.0 or h <= 1.0:
		var view := get_viewport_rect().size
		w = maxf(1.0, view.x)
		h = maxf(1.0, view.y)
	return Rect2(
		EDGE_MARGIN,
		EDGE_MARGIN,
		maxf(1.0, w - EDGE_MARGIN * 2.0),
		maxf(1.0, h - EDGE_MARGIN * 2.0)
	)


func _reset_dots() -> void:
	_dots.clear()
	var plot := _plot_rect()
	var count := clampi(DOT_COUNT + _rng.randi_range(-2, 3), 12, 18)
	for _i in count:
		_dots.append(_spawn_dot(plot))


func _spawn_dot(plot: Rect2) -> Dictionary:
	var drift := Vector2(_rng.randf_range(-10.0, 10.0), _rng.randf_range(-8.0, 8.0))
	if drift.length_squared() < 4.0:
		drift = Vector2(6.0, -4.0)
	return {
		"pos": Vector2(
			_rng.randf_range(plot.position.x, plot.position.x + plot.size.x),
			_rng.randf_range(plot.position.y, plot.position.y + plot.size.y)
		),
		"drift": drift,
		"radius": _rng.randf_range(DOT_RADIUS_MIN, DOT_RADIUS_MAX),
		"color": DOT_COLORS[_rng.randi_range(0, DOT_COLORS.size() - 1)],
		"alpha": _rng.randf_range(0.0, 0.22),
		"alpha_target": _rng.randf_range(0.18, 0.42),
		"fade_phase": _rng.randf_range(0.0, TAU),
	}


func _on_resized() -> void:
	var plot := _plot_rect()
	for dot in _dots:
		dot["pos"] = _clamp_to_plot(dot.get("pos", Vector2.ZERO), plot)


func _clamp_to_plot(pos: Vector2, plot: Rect2) -> Vector2:
	return Vector2(
		clampf(pos.x, plot.position.x, plot.position.x + plot.size.x),
		clampf(pos.y, plot.position.y, plot.position.y + plot.size.y)
	)


func _process(delta: float) -> void:
	if not _motion_active or not _particles_enabled or _dots.is_empty():
		return
	var plot := _plot_rect()
	var t := Time.get_ticks_msec() * 0.001
	for dot in _dots:
		var pos: Vector2 = dot.get("pos", Vector2.ZERO)
		var drift: Vector2 = dot.get("drift", Vector2.ZERO)
		pos += drift * delta
		dot["pos"] = _clamp_to_plot(pos, plot)
		var phase: float = float(dot.get("fade_phase", 0.0))
		var target: float = float(dot.get("alpha_target", 0.24))
		var wave := (sin(t * 0.55 + phase) + 1.0) * 0.5
		dot["alpha"] = lerpf(0.06, target, wave)
	queue_redraw()


func _draw() -> void:
	if not _motion_active:
		return
	_draw_ambient_wash()
	if not _particles_enabled:
		return
	for dot in _dots:
		var base: Color = dot.get("color", Color.WHITE)
		var alpha: float = float(dot.get("alpha", 0.18))
		var radius: float = float(dot.get("radius", 1.5))
		var pos: Vector2 = dot.get("pos", Vector2.ZERO)
		var col := Color(base.r, base.g, base.b, alpha)
		draw_circle(pos, radius + 1.4, Color(col.r, col.g, col.b, alpha * 0.24))
		draw_circle(pos, radius, col)


func _draw_ambient_wash() -> void:
	var view := size
	if view.x <= 1.0 or view.y <= 1.0:
		view = get_viewport_rect().size
	var specs := _sample_washes(_wash_blend)
	for spec in specs:
		var anchor: Vector2 = spec.get("anchor", Vector2.ZERO)
		var radius: float = float(spec.get("radius", 0.0))
		var color: Color = spec.get("color", Color.WHITE)
		draw_circle(view * anchor, radius, color)


func _start_motion() -> void:
	if not _motion_active:
		return
	_stop_motion()
	if _particles_enabled and _dots.is_empty():
		_reset_dots()
	set_process(_particles_enabled)
	if _particles_enabled:
		_schedule_respawn_cycle()


func _schedule_respawn_cycle() -> void:
	if not _motion_active or not _particles_enabled:
		return
	var wait := _rng.randf_range(2.0, 4.2)
	var tw := create_tween()
	_motion_tweens.append(tw)
	tw.tween_interval(wait)
	tw.tween_callback(_respawn_random_dot)
	tw.tween_callback(_schedule_respawn_cycle)


func _respawn_random_dot() -> void:
	if not _motion_active or _dots.is_empty():
		return
	var idx := _rng.randi_range(0, _dots.size() - 1)
	var dot: Dictionary = _dots[idx]
	var plot := _plot_rect()
	var tw := create_tween()
	_motion_tweens.append(tw)
	tw.tween_method(
		func(alpha: float) -> void:
			dot["alpha"] = alpha,
		float(dot.get("alpha", 0.2)),
		0.0,
		0.75
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		_dots[idx] = _spawn_dot(plot)
		var fade_in := create_tween()
		_motion_tweens.append(fade_in)
		fade_in.tween_method(
			func(alpha: float) -> void:
				_dots[idx]["alpha"] = alpha,
			0.0,
			float(_dots[idx].get("alpha_target", 0.24)),
			0.95
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)


func _stop_motion() -> void:
	set_process(false)
	for tw in _motion_tweens:
		if tw and tw.is_valid():
			tw.kill()
	_motion_tweens.clear()
