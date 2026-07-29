# ui/spotlight_tutorial.gd
extends CanvasLayer

signal finished
signal skipped
signal step_shown(step_index: int)

const HIGHLIGHT_PAD := 8.0
@onready var _dim: ColorRect = $Root/Dim
@onready var _highlight_frame: PanelContainer = $Root/HighlightFrame
@onready var _card: PanelContainer = $Root/Card
@onready var _accent_bar: ColorRect = $Root/Card/Row/AccentBar
@onready var _step_label: Label = $Root/Card/Row/BodyMargin/VBox/StepLabel
@onready var _title_label: Label = $Root/Card/Row/BodyMargin/VBox/TitleLabel
@onready var _body_label: Label = $Root/Card/Row/BodyMargin/VBox/BodyLabel
@onready var _nav_hint_label: Label = $Root/Card/Row/BodyMargin/VBox/NavHintLabel
@onready var _back_button: Button = $Root/Card/Row/BodyMargin/VBox/ButtonsRow/BackButton
@onready var _skip_button: Button = $Root/Card/Row/BodyMargin/VBox/ButtonsRow/SkipButton
@onready var _next_button: Button = $Root/Card/Row/BodyMargin/VBox/ButtonsRow/NextButton

var _steps: Array = []
var _index: int = 0


func _ready() -> void:
	visible = false
	set_process_input(true)
	_apply_visual_style()
	_back_button.pressed.connect(_on_back_pressed)
	_skip_button.pressed.connect(_on_skip_pressed)
	_next_button.pressed.connect(_on_next_pressed)
	if _highlight_frame:
		_highlight_frame.visible = false
		_highlight_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _apply_visual_style() -> void:
	if _card:
		_card.add_theme_stylebox_override("panel", AppOverlayStyles.tutorial_panel())
	if _highlight_frame:
		_highlight_frame.add_theme_stylebox_override("panel", AppOverlayStyles.tutorial_highlight_panel())
	var accent := AppOverlayStyles.tutorial_accent_color()
	if _accent_bar:
		_accent_bar.color = accent
	if _step_label:
		_step_label.add_theme_color_override("font_color", accent)


func start(steps: Array) -> void:
	_steps = steps.duplicate(true)
	_index = 0
	visible = true
	_set_blocks_background_input(true)
	_show_step(0)


func _show_step(index: int) -> void:
	_hide_highlight()
	if index < 0 or index >= _steps.size():
		_finish()
		return
	_index = index
	var step: Dictionary = _steps[index]
	_step_label.text = tr("TUTORIAL_STEP_FMT") % [index + 1, _steps.size()]
	_title_label.text = tr(str(step.get("title_key", "")))
	_body_label.text = tr(str(step.get("body_key", "")))
	if _nav_hint_label:
		_nav_hint_label.text = tr("TUTORIAL_NAV_HINT")
	_back_button.visible = index > 0
	_skip_button.text = tr("TUTORIAL_SKIP")
	_next_button.text = tr("TUTORIAL_DONE") if index >= _steps.size() - 1 else tr("TUTORIAL_NEXT")
	if _back_button.visible:
		_back_button.text = tr("TUTORIAL_BACK")
	step_shown.emit(index)
	var target: Control = step.get("target", null)
	var extra_targets: Array = step.get("targets", [])
	if not extra_targets.is_empty():
		call_deferred("_position_ui_for_targets", extra_targets)
	elif target and is_instance_valid(target):
		call_deferred("_position_ui_for_target", target)
	else:
		call_deferred("_center_card")


func _position_ui_for_target(target: Control) -> void:
	if target == null or not is_instance_valid(target):
		_center_card()
		return
	_set_blocks_background_input(not (target is BaseButton))
	await get_tree().process_frame
	await get_tree().process_frame
	var rect := target.get_global_rect()
	_position_highlight(rect)
	_position_card_near_rect(rect)


func _position_ui_for_targets(targets: Array) -> void:
	var rect := _union_control_rects(targets)
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		_center_card()
		return
	await get_tree().process_frame
	await get_tree().process_frame
	_position_highlight(rect)
	_position_card_near_rect(rect)


func _union_control_rects(targets: Array) -> Rect2:
	var rect := Rect2()
	var has_rect := false
	for node in targets:
		if node is Control and is_instance_valid(node):
			var control := node as Control
			if not has_rect:
				rect = control.get_global_rect()
				has_rect = true
			else:
				rect = rect.merge(control.get_global_rect())
	return rect if has_rect else Rect2()


func _position_highlight(rect: Rect2) -> void:
	if _highlight_frame == null:
		return
	_highlight_frame.visible = rect.size.x > 1.0 and rect.size.y > 1.0
	if not _highlight_frame.visible:
		return
	var padded := rect.grow(HIGHLIGHT_PAD)
	_highlight_frame.global_position = padded.position
	_highlight_frame.size = padded.size


func _hide_highlight() -> void:
	if _highlight_frame:
		_highlight_frame.visible = false


func _position_card_near_rect(rect: Rect2) -> void:
	if _card == null:
		return
	_card.reset_size()
	var card_size := _card.get_combined_minimum_size()
	if _card.size.x > 1.0 and _card.size.y > 1.0:
		card_size = _card.size
	var viewport_size := get_viewport().get_visible_rect().size
	var margin := 20.0
	var target_cx := rect.position.x + rect.size.x * 0.5
	var x := clampf(target_cx - card_size.x * 0.5, margin, viewport_size.x - card_size.x - margin)
	var below_y := rect.position.y + rect.size.y + 16.0
	var above_y := rect.position.y - card_size.y - 16.0
	var y := below_y
	if below_y + card_size.y > viewport_size.y - margin and above_y >= margin:
		y = above_y
	y = clampf(y, margin, viewport_size.y - card_size.y - margin)
	_card.global_position = Vector2(x, y)


func _center_card() -> void:
	if _card == null:
		return
	await get_tree().process_frame
	_card.reset_size()
	var viewport_size := get_viewport().get_visible_rect().size
	var card_size := _card.get_combined_minimum_size()
	if _card.size.x > 1.0 and _card.size.y > 1.0:
		card_size = _card.size
	_card.global_position = Vector2(
		(viewport_size.x - card_size.x) * 0.5,
		viewport_size.y - card_size.y - 48.0
	)


func _on_back_pressed() -> void:
	if _index > 0:
		_show_step(_index - 1)


func _on_next_pressed() -> void:
	if _index >= _steps.size() - 1:
		_finish()
	else:
		_show_step(_index + 1)


func _on_skip_pressed() -> void:
	_hide_highlight()
	_set_blocks_background_input(false)
	visible = false
	skipped.emit()


func _finish() -> void:
	_hide_highlight()
	_set_blocks_background_input(false)
	visible = false
	finished.emit()


func _set_blocks_background_input(block: bool) -> void:
	if _dim:
		_dim.mouse_filter = Control.MOUSE_FILTER_STOP if block else Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_ESCAPE:
			_on_skip_pressed()
			get_viewport().set_input_as_handled()
		KEY_LEFT, KEY_BACKSPACE:
			if _index > 0:
				_on_back_pressed()
			get_viewport().set_input_as_handled()
		KEY_RIGHT, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			_on_next_pressed()
			get_viewport().set_input_as_handled()
