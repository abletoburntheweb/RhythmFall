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

## Рамки подсветки целей: первая — статичная HighlightFrame из сцены, остальные
## (для нескольких целей, например три строки результата) — клоны из пула,
## создаются лениво и переиспользуются между шагами.
var _highlight_pool: Array[PanelContainer] = []


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
		_highlight_pool.append(_highlight_frame)


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
	var step_label_text := str(step.get("step_label_text", ""))
	if not step_label_text.is_empty():
		_step_label.text = step_label_text
	else:
		_step_label.text = tr("TUTORIAL_STEP_FMT") % [index + 1, _steps.size()]
	_title_label.text = _resolve_text(step, "title")
	_body_label.text = _resolve_text(step, "body")
	if _nav_hint_label:
		_nav_hint_label.text = tr("TUTORIAL_NAV_HINT")
	_step_label.visible = not bool(step.get("hide_step_label", false))
	if _nav_hint_label:
		_nav_hint_label.visible = not bool(step.get("hide_nav_hint", false))
	_back_button.visible = index > 0
	var skip_key := str(step.get("skip_key", ""))
	if not skip_key.is_empty():
		_skip_button.text = tr(skip_key)
	else:
		_skip_button.text = tr("TUTORIAL_SKIP")
	var next_key := str(step.get("next_key", ""))
	if not next_key.is_empty():
		_next_button.text = tr(next_key)
	else:
		_next_button.text = tr("TUTORIAL_DONE") if index >= _steps.size() - 1 else tr("TUTORIAL_NEXT")
	_skip_button.visible = not bool(step.get("hide_skip", false))
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


func _resolve_text(step: Dictionary, field: String) -> String:
	var literal_key := "%s_text" % field
	if step.has(literal_key):
		return str(step[literal_key])
	var key := str(step.get("%s_key" % field, ""))
	if key != "":
		return tr(key)
	return ""


func _position_ui_for_target(target: Control) -> void:
	if target == null or not is_instance_valid(target):
		_center_card()
		return
	_set_blocks_background_input(not (target is BaseButton))
	# Спотлайт может быть вынут из дерева в том же кадре (смена экрана) —
	# корутина ждёт сигнал SceneTree, поэтому проверяем is_inside_tree и до,
	# и после await, иначе get_tree() вернёт null.
	if not is_inside_tree():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var rect := target.get_global_rect()
	_position_highlights([rect])
	_position_card_near_rect(rect)


func _position_ui_for_targets(targets: Array) -> void:
	var rect := _union_control_rects(targets)
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		_center_card()
		return
	if not is_inside_tree():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	# Спотлайт с целями не должен блокировать ввод: игрок сам кликает
	# подсвеченную кнопку/строку. Совпадает с поведением одиночного target
	# (BaseButton) — dim не перехватывает клики, glow остаётся визуальным.
	_set_blocks_background_input(false)
	var rects: Array = []
	for node in targets:
		if node is Control and is_instance_valid(node):
			rects.append((node as Control).get_global_rect())
	_position_highlights(rects)
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


func _ensure_highlight_frames(count: int) -> void:
	if _highlight_frame == null:
		return
	while _highlight_pool.size() < count:
		var clone := _highlight_frame.duplicate() as PanelContainer
		clone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clone.visible = false
		_highlight_frame.get_parent().add_child(clone)
		_highlight_pool.append(clone)


## Каждая цель получает СВОЮ рамку (для массива целей), а не общий контур
## вокруг их объединения: рамка вокруг union трёх несвязанных строк выглядела
## как странный прямоугольник поверх всего блока.
func _position_highlights(rects: Array) -> void:
	var valid: Array[Rect2] = []
	for r in rects:
		if r.size.x > 1.0 and r.size.y > 1.0:
			valid.append(r)
	_ensure_highlight_frames(valid.size())
	for i in valid.size():
		var frame := _highlight_pool[i]
		frame.visible = true
		var padded := valid[i].grow(HIGHLIGHT_PAD)
		frame.global_position = padded.position
		frame.size = padded.size
	for i in range(valid.size(), _highlight_pool.size()):
		_highlight_pool[i].visible = false


func _hide_highlight() -> void:
	for frame in _highlight_pool:
		if frame:
			frame.visible = false


func _position_card_near_rect(rect: Rect2) -> void:
	if _card == null:
		return
	_card.reset_size()
	var card_size := _card.get_combined_minimum_size()
	if _card.size.x > 1.0 and _card.size.y > 1.0:
		card_size = _card.size
	var viewport := get_viewport()
	var viewport_size := viewport.get_visible_rect().size if viewport else Vector2(1920, 1080)
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
	if _card == null or not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree() or _card == null or not is_instance_valid(_card):
		return
	_card.reset_size()
	var viewport = get_viewport()
	var viewport_size := viewport.get_visible_rect().size if viewport else Vector2(1920, 1080)
	var card_size := _card.get_combined_minimum_size()
	if _card.size.x > 1.0 and _card.size.y > 1.0:
		card_size = _card.size
	_card.global_position = Vector2(
		(viewport_size.x - card_size.x) * 0.5,
		viewport_size.y - card_size.y - 48.0
	)


func _on_back_pressed() -> void:
	if MusicManager and MusicManager.has_method("play_modifier_deselect_sound"):
		MusicManager.play_modifier_deselect_sound()
	if _index > 0:
		_show_step(_index - 1)


func _on_next_pressed() -> void:
	if MusicManager and MusicManager.has_method("play_modifier_select_sound"):
		MusicManager.play_modifier_select_sound()
	if _index >= _steps.size() - 1:
		_finish()
	else:
		_show_step(_index + 1)


func _on_skip_pressed() -> void:
	if MusicManager and MusicManager.has_method("play_modifier_deselect_sound"):
		MusicManager.play_modifier_deselect_sound()
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
