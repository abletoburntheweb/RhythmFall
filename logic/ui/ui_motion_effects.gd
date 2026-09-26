# logic/ui/ui_motion_effects.gd
extends RefCounted
class_name UiMotionEffects

const _DIAMOND_TEX: Texture2D = preload("res://assets/icons/diamond.svg")
const FLY_DURATION := 0.55


static func pulse_play_ready(button: Button) -> void:
	if button == null or not is_instance_valid(button):
		return
	if button.has_meta("_play_glow_tween") and button.get_meta("_play_glow_tween") is Tween:
		var old: Tween = button.get_meta("_play_glow_tween")
		if old.is_valid():
			old.kill()
	var glow := Color(0.45, 0.92, 0.82, 1.0)
	button.modulate = Color(1.0, 1.0, 1.0, 1.0)
	var tw := button.create_tween()
	button.set_meta("_play_glow_tween", tw)
	tw.set_trans(Tween.TRANS_SINE)
	tw.tween_property(button, "modulate", glow, 0.12)
	tw.tween_property(button, "modulate", Color.WHITE, 0.28)
	tw.tween_property(button, "scale", Vector2(1.04, 1.04), 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(button, "scale", Vector2.ONE, 0.22).set_ease(Tween.EASE_OUT)


static func pop_favorite_star(btn: Control) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	const META := "_favorite_pop_tween"
	if btn.has_meta(META):
		var old: Variant = btn.get_meta(META)
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	btn.pivot_offset = btn.size * 0.5
	btn.scale = Vector2.ONE
	var tw := btn.create_tween()
	btn.set_meta(META, tw)
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)
	var gold := Color(1.0, 0.88, 0.42, 1.0)
	var settled := Color(1.0, 0.94, 0.72, 1.0)
	tw.tween_property(btn, "scale", Vector2(1.34, 1.34), 0.16)
	tw.parallel().tween_property(btn, "modulate", gold, 0.12)
	tw.tween_property(btn, "scale", Vector2.ONE, 0.24)
	tw.parallel().tween_property(btn, "modulate", settled, 0.2)
	tw.finished.connect(func() -> void:
		if is_instance_valid(btn):
			btn.remove_meta(META)
	, CONNECT_ONE_SHOT)


static func pop_scale(
	control: Control,
	peak: float = 1.12,
	up: float = 0.12,
	down: float = 0.2
) -> void:
	if control == null or not is_instance_valid(control):
		return
	const META := "_ui_pop_scale_tween"
	if control.has_meta(META):
		var old: Variant = control.get_meta(META)
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2.ONE
	var tw := control.create_tween()
	control.set_meta(META, tw)
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(control, "scale", Vector2(peak, peak), up)
	tw.tween_property(control, "scale", Vector2.ONE, down)
	tw.finished.connect(func() -> void:
		if is_instance_valid(control):
			control.scale = Vector2.ONE
			control.remove_meta(META)
	, CONNECT_ONE_SHOT)


static func pulse_menu_badge(badge: Control) -> void:
	if badge == null or not is_instance_valid(badge) or not badge.visible:
		return
	if badge.has_meta("_badge_pulse_tween"):
		var existing: Variant = badge.get_meta("_badge_pulse_tween")
		if existing is Tween and (existing as Tween).is_valid():
			return
	badge.scale = Vector2.ONE
	badge.pivot_offset = badge.size * 0.5
	var tw := badge.create_tween()
	badge.set_meta("_badge_pulse_tween", tw)
	tw.set_loops()
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(badge, "scale", Vector2(1.1, 1.1), 0.6)
	tw.tween_property(badge, "scale", Vector2.ONE, 0.6)


static func stop_menu_badge_pulse(badge: Control) -> void:
	if badge == null or not is_instance_valid(badge):
		return
	if badge.has_meta("_badge_pulse_tween"):
		var existing: Variant = badge.get_meta("_badge_pulse_tween")
		if existing is Tween and (existing as Tween).is_valid():
			(existing as Tween).kill()
		badge.remove_meta("_badge_pulse_tween")
	badge.scale = Vector2.ONE


const META_BORDER_PULSE_TW := "_ui_border_pulse_tween"
const META_BORDER_PULSE_BASE := "_ui_border_pulse_base_styles"
const META_BORDER_PULSE_ACCENT := "_ui_border_pulse_accent"


static func pulse_panel_border(
	panel: Control,
	accent: Color,
	alpha_min: float = 0.42,
	alpha_max: float = 0.92,
	half_period_sec: float = 0.9
) -> void:
	pulse_control_border(panel, accent, ["panel"], alpha_min, alpha_max, half_period_sec)


static func pulse_button_outline(
	btn: Button,
	accent: Color,
	alpha_min: float = 0.38,
	alpha_max: float = 0.88,
	half_period_sec: float = 0.72
) -> void:
	pulse_control_border(btn, accent, ["normal", "hover", "pressed", "focus"], alpha_min, alpha_max, half_period_sec)


static func stop_panel_border_pulse(control: Control) -> void:
	stop_control_border_pulse(control)


static func stop_control_border_pulse(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	if control.has_meta(META_BORDER_PULSE_TW):
		var tw: Variant = control.get_meta(META_BORDER_PULSE_TW)
		if tw is Tween and (tw as Tween).is_valid():
			(tw as Tween).kill()
		control.remove_meta(META_BORDER_PULSE_TW)
	if control.has_meta(META_BORDER_PULSE_BASE):
		var bases: Variant = control.get_meta(META_BORDER_PULSE_BASE)
		if bases is Dictionary:
			for state in (bases as Dictionary):
				var box: StyleBoxFlat = (bases as Dictionary)[state]
				if box != null:
					control.add_theme_stylebox_override(state, box.duplicate())
		control.remove_meta(META_BORDER_PULSE_BASE)
	if control.has_meta(META_BORDER_PULSE_ACCENT):
		control.remove_meta(META_BORDER_PULSE_ACCENT)


static func pulse_control_border(
	control: Control,
	accent: Color,
	style_states: Array,
	alpha_min: float = 0.42,
	alpha_max: float = 0.92,
	half_period_sec: float = 0.9
) -> void:
	if control == null or not is_instance_valid(control) or style_states.is_empty():
		return
	stop_control_border_pulse(control)
	var base_styles: Dictionary = {}
	for state_name in style_states:
		var state := StringName(String(state_name))
		var captured := _capture_stylebox(control, state)
		base_styles[state] = captured
		control.add_theme_stylebox_override(state, captured.duplicate())
	control.set_meta(META_BORDER_PULSE_BASE, base_styles)
	control.set_meta(META_BORDER_PULSE_ACCENT, accent)
	if not control.is_inside_tree():
		return
	var tw := control.create_tween()
	control.set_meta(META_BORDER_PULSE_TW, tw)
	tw.set_loops()
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(
		func(alpha: float) -> void:
			_apply_border_alpha(control, base_styles, accent, alpha),
		alpha_min,
		alpha_max,
		half_period_sec
	)
	tw.tween_method(
		func(alpha: float) -> void:
			_apply_border_alpha(control, base_styles, accent, alpha),
		alpha_max,
		alpha_min,
		half_period_sec
	)


static func _capture_stylebox(control: Control, state: StringName) -> StyleBoxFlat:
	var existing := control.get_theme_stylebox(state)
	if existing is StyleBoxFlat:
		return (existing as StyleBoxFlat).duplicate()
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(8)
	box.set_border_width_all(2)
	box.bg_color = Color(0.11, 0.12, 0.16, 0.85)
	return box


static func _apply_border_alpha(
	control: Control,
	base_styles: Dictionary,
	accent: Color,
	alpha: float
) -> void:
	if control == null or not is_instance_valid(control):
		return
	for state in base_styles:
		var base: StyleBoxFlat = base_styles[state]
		if base == null:
			continue
		var box := base.duplicate() as StyleBoxFlat
		box.border_color = Color(accent.r, accent.g, accent.b, alpha)
		control.add_theme_stylebox_override(state, box)


static func fly_diamond(tree: SceneTree, from_global: Vector2, to_global: Vector2) -> void:
	if tree == null or tree.root == null:
		return
	if from_global == Vector2.ZERO:
		return
	if to_global == Vector2.ZERO:
		var vp := tree.root.get_viewport()
		if vp:
			var r := vp.get_visible_rect()
			to_global = Vector2(r.position.x + r.size.x - 72.0, r.position.y + 96.0)
	var layer := CanvasLayer.new()
	layer.layer = 120
	tree.root.add_child(layer)
	var icon := TextureRect.new()
	icon.texture = _DIAMOND_TEX
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = Vector2(28, 28)
	icon.pivot_offset = icon.size * 0.5
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Color(1.0, 1.0, 1.0, 1.0)
	layer.add_child(icon)
	icon.global_position = from_global - icon.size * 0.5
	var tw := layer.create_tween()
	tw.set_parallel(true)
	tw.tween_property(icon, "global_position", to_global - icon.size * 0.5, FLY_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(icon, "scale", Vector2(0.65, 0.65), FLY_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(icon, "modulate:a", 0.9, FLY_DURATION * 0.85)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(layer):
			layer.queue_free()
	)
