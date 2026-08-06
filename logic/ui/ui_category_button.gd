# logic/ui/ui_category_button.gd
extends RefCounted
class_name UiCategoryButton

const _UiMotionEffects = preload("res://logic/ui/ui_motion_effects.gd")

const META_ICON := &"ui_icon_file"
const META_VAR_INACTIVE := &"ui_variation_inactive"
const META_VAR_ACTIVE := &"ui_variation_active"
const META_ACCENT := &"ui_accent_color"
const META_HOVER_RESET := &"ui_hover_reset_active"
const ICON_DIM := Color(0.58, 0.62, 0.72, 0.88)
const INACTIVE_MODULATE := Color(0.88, 0.9, 0.94, 0.92)


static func is_configured(btn: Button) -> bool:
	return (
		btn != null
		and btn.has_meta(META_ICON)
		and btn.has_meta(META_VAR_INACTIVE)
		and btn.has_meta(META_VAR_ACTIVE)
	)


static func apply_selection(
	btn: Button,
	active: bool,
	icon_size: int = 14,
	compact: bool = false,
	tinted_idle: bool = false
) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	var configured := is_configured(btn)
	reset_hover_visual(btn)
	if configured:
		var variation: StringName = btn.get_meta(META_VAR_ACTIVE if active else META_VAR_INACTIVE)
		btn.theme_type_variation = variation
		btn.button_pressed = active
		var accent := _accent_for_button(btn)
		_apply_configured_styleboxes(btn, active, accent, compact, tinted_idle)
		_apply_font_colors(btn, active, accent, tinted_idle)
		_refresh_icon(btn, active, icon_size, accent, tinted_idle)
		_UiMotionEffects.stop_control_border_pulse(btn)
		if active:
			_UiMotionEffects.pulse_button_outline(btn, accent.lightened(0.12), 0.52, 0.95, 0.85)
		return
	var accent := _accent_for_button(btn)
	_apply_accent_border(btn, active, compact, accent, tinted_idle)
	_apply_font_colors(btn, active, accent, tinted_idle)
	_refresh_icon(btn, active, icon_size, accent, tinted_idle)
	_UiMotionEffects.stop_control_border_pulse(btn)
	if active:
		_UiMotionEffects.pulse_button_outline(btn, accent.lightened(0.12), 0.52, 0.95, 0.85)


static func make_accent_stylebox(accent: Color, compact: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(accent.r, accent.g, accent.b, 0.16).lerp(Color(0.11, 0.12, 0.16, 0.92), 0.45)
	box.border_color = accent.lightened(0.12)
	box.set_border_width_all(2)
	box.set_corner_radius_all(8 if compact else 10)
	if compact:
		box.content_margin_left = 10.0
		box.content_margin_right = 10.0
		box.content_margin_top = 6.0
		box.content_margin_bottom = 6.0
	else:
		box.content_margin_left = 14.0
		box.content_margin_right = 14.0
		box.content_margin_top = 8.0
		box.content_margin_bottom = 8.0
	return box


static func make_dimmed_accent_stylebox(accent: Color, compact: bool = false) -> StyleBoxFlat:
	var box := make_accent_stylebox(accent, compact)
	box.bg_color = Color(accent.r, accent.g, accent.b, 0.08).lerp(Color(0.10, 0.11, 0.15, 0.95), 0.55)
	box.border_color = Color(accent.r, accent.g, accent.b, 0.55)
	box.set_border_width_all(1)
	return box


static func _accent_for_button(btn: Button) -> Color:
	if btn.has_meta(META_ACCENT):
		return btn.get_meta(META_ACCENT)
	return btn.get_theme_color("font_color")


static func _apply_accent_border(
	btn: Button,
	active: bool,
	compact: bool,
	accent: Color,
	tinted_idle: bool = false
) -> void:
	var states := ["normal", "hover", "pressed", "focus", "disabled"]
	if not active:
		var idle: StyleBoxFlat = (
			make_dimmed_accent_stylebox(accent, compact) if tinted_idle else _neutral_inactive_stylebox(compact)
		)
		for state in states:
			btn.add_theme_stylebox_override(state, idle.duplicate())
		return
	var box := make_accent_stylebox(accent, compact)
	for state in states:
		btn.add_theme_stylebox_override(state, box)


static func _apply_configured_styleboxes(
	btn: Button,
	active: bool,
	accent: Color,
	compact: bool,
	tinted_idle: bool = false
) -> void:
	var box: StyleBoxFlat
	if active:
		box = make_accent_stylebox(accent, compact)
	elif tinted_idle:
		box = make_dimmed_accent_stylebox(accent, compact)
	else:
		box = _neutral_inactive_stylebox(compact)
	var states := ["normal", "hover", "pressed", "focus", "disabled"]
	for state in states:
		btn.add_theme_stylebox_override(state, box.duplicate())


static func _neutral_inactive_stylebox(compact: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.10, 0.11, 0.15, 0.95)
	box.border_color = Color(1, 1, 1, 0.08)
	box.set_border_width_all(1)
	box.set_corner_radius_all(8 if compact else 10)
	if compact:
		box.content_margin_left = 10.0
		box.content_margin_right = 10.0
		box.content_margin_top = 6.0
		box.content_margin_bottom = 6.0
	else:
		box.content_margin_left = 14.0
		box.content_margin_right = 14.0
		box.content_margin_top = 8.0
		box.content_margin_bottom = 8.0
	return box


static func _apply_font_colors(btn: Button, active: bool, accent: Color, tinted_idle: bool = false) -> void:
	var keys := ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]
	if active:
		for key in keys:
			btn.add_theme_color_override(key, accent)
	elif tinted_idle:
		var dim := Color(accent.r, accent.g, accent.b, 0.82).lerp(Color(0.78, 0.82, 0.9, 1.0), 0.35)
		for key in keys:
			btn.add_theme_color_override(key, dim)
	else:
		for key in keys:
			btn.remove_theme_color_override(key)


static func _refresh_icon(
	btn: Button,
	active: bool,
	icon_size: int,
	accent: Color,
	tinted_idle: bool = false
) -> void:
	if btn == null or not btn.has_meta(META_ICON):
		return
	var icon_file := str(btn.get_meta(META_ICON))
	if icon_file.strip_edges() == "":
		return
	var tint: Color
	if active:
		tint = accent.lightened(0.12)
	elif tinted_idle:
		tint = Color(accent.r, accent.g, accent.b, 0.72)
	else:
		tint = ICON_DIM
	UiIconHelper.configure_button_icon(btn, icon_file, tint, icon_size)
	btn.modulate = Color.WHITE if active or tinted_idle else INACTIVE_MODULATE


static func reset_hover_state(control: Control) -> void:
	reset_hover_visual(control)
	if control is BaseButton:
		(control as BaseButton).set_pressed(false)


static func is_hover_reset_in_progress(control: Control = null) -> bool:
	if _hover_reset_depth > 0:
		return true
	if control != null and is_instance_valid(control):
		return bool(control.get_meta(META_HOVER_RESET, false))
	return false


static var _hover_reset_depth := 0


static func reset_hover_visual(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	if is_hover_reset_in_progress(control):
		return
	_hover_reset_depth += 1
	control.set_meta(META_HOVER_RESET, true)
	# apply_selection often runs before add_child — release_focus requires the tree.
	if control is BaseButton and control.is_inside_tree():
		(control as BaseButton).release_focus()
	if control.is_inside_tree():
		control.notification(Control.NOTIFICATION_MOUSE_EXIT)
	control.remove_meta(META_HOVER_RESET)
	_hover_reset_depth -= 1


static func reset_hover_in_subtree(root: Node) -> void:
	if root == null or not is_instance_valid(root):
		return
	if root is BaseButton:
		reset_hover_state(root as Control)
	for child in root.get_children():
		reset_hover_in_subtree(child)
