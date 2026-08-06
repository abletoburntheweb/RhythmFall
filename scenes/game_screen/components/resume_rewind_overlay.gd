# scenes/game_screen/components/resume_rewind_overlay.gd
extends Control
class_name ResumeRewindOverlay

const _UiIcon = preload("res://logic/ui/ui_icon_helper.gd")

var _tint: ColorRect
var _icon: TextureRect
var _hint: Label
var _tween: Tween = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func play(host: Control, duration: float, hint_text: String = "") -> void:
	if host == null or not is_instance_valid(host):
		await get_tree().create_timer(maxf(duration, 0.05)).timeout
		return
	host.add_child(self)
	z_index = 120
	_build_ui(hint_text)
	modulate = Color(1, 1, 1, 0)
	visible = true
	await get_tree().process_frame
	if _icon:
		_icon.pivot_offset = _icon.size * 0.5
	if _tween and _tween.is_valid():
		_tween.kill()
	var fade_in := minf(0.22, duration * 0.1)
	var fade_out := minf(0.35, duration * 0.12)
	var hold := maxf(duration - fade_in - fade_out, 0.05)
	var spin_duration := fade_in + hold
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, fade_in)
	if _icon:
		_tween.tween_property(_icon, "rotation", TAU * -1.25, spin_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _tint:
		_tween.tween_method(_pulse_tint, 0.0, 1.0, spin_duration)
	_tween.set_parallel(false)
	_tween.tween_property(self, "modulate:a", 0.0, fade_out)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _tween.finished
	queue_free()


func _build_ui(hint_text: String) -> void:
	_tint = ColorRect.new()
	_tint.name = "Tint"
	_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint.color = Color(0.12, 0.34, 0.52, 0.0)
	add_child(_tint)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 10)
	center.add_child(stack)

	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.custom_minimum_size = Vector2(56, 56)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture = _UiIcon.load_tinted_icon("rewind.svg", Color(0.62, 0.9, 1.0, 1.0), 96)
	stack.add_child(_icon)

	_hint = Label.new()
	_hint.name = "Hint"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", Color(0.78, 0.92, 1.0, 0.95))
	_hint.text = hint_text
	_hint.visible = hint_text.strip_edges() != ""
	stack.add_child(_hint)


func _pulse_tint(t: float) -> void:
	if _tint == null:
		return
	var pulse := 0.5 + 0.5 * sin(t * TAU * 2.2)
	_tint.color = Color(0.1, 0.32, 0.5, 0.08 + pulse * 0.14)
