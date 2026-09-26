# ui/target_glow.gd
class_name TargetGlow
extends CanvasLayer

## Переиспользуемая пульсирующая подсветка вокруг реальных UI-контролов
## (target glow). Один экземпляр на guide-хост; цели задаются через
## set_targets(). Не меняет layout, не перекрывает текст, не блокирует ввод
## (mouse_filter IGNORE), следует за Control каждый кадр, гаснет, если цель
## невидима/уничтожена, и не оставляет следов после clear_targets().

const PAD := 6.0
const PULSE_FREQ := 0.5
const MIN_ALPHA := 0.30
const MAX_ALPHA := 0.85
const MIN_WIDTH := 1.5
const MAX_WIDTH := 3.5

var _outline: Control = null
var _targets: Array = []
var _rects: Array[Rect2] = []
var _time := 0.0
var _color := Color(0.85, 0.95, 1.0, 1.0)
var _inner_style := StyleBoxFlat.new()
var _outer_style := StyleBoxFlat.new()


func _ready() -> void:
	# Слой НИЖЕ модальных оверлеев (spotlight CanvasLayer 120, AppOverlayBase z120,
	# settings-from-pause z150): glow никогда не рисуется поверх модалки/dim.
	# При этом он остаётся ВЫШЕ обычного UI (z0-100), включая pause menu (z100).
	layer = 119
	_outline = Control.new()
	_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outline.set_anchors_preset(Control.PRESET_FULL_RECT)
	_outline.draw.connect(_draw_outline)
	add_child(_outline)
	_inner_style.bg_color = Color(0, 0, 0, 0)
	_inner_style.set_corner_radius_all(8)
	_outer_style.bg_color = Color(0, 0, 0, 0)
	_outer_style.set_corner_radius_all(12)
	visible = false


func set_targets(targets: Array) -> void:
	_targets = []
	for t in targets:
		if t is Control and is_instance_valid(t):
			_targets.append(t)
	visible = _targets.size() > 0
	if visible:
		_time = 0.0


func set_color(color: Color) -> void:
	_color = color


func clear_targets() -> void:
	_targets = []
	visible = false


## Любая модалка открыта: AppOverlayBase (confirm/notice/choice) или любой
## диалог, настроенный через UiIconHelper.configure_modal_overlay (generation
## settings, scope modal, queue dialog и т.п.). Glow лежит на CanvasLayer 119 и
## рисуется ВЫШЕ таких диалогов (z100+ на дефолтном canvas) — поэтому при
## открытой модалке его нужно прятать явно, иначе обводка просвечивает сквозь
## фон/backdrop диалога.
static func is_modal_open() -> bool:
	if AppOverlayBase.is_modal_open():
		return true
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	for node in tree.get_nodes_in_group("app_modal_overlays"):
		if node != null and is_instance_valid(node) and node.visible:
			return true
	return false


func _any_modal_open() -> bool:
	return is_modal_open()


func _process(delta: float) -> void:
	if _any_modal_open():
		visible = false
		return

	if _targets.is_empty():
		visible = false
		return
	# Каждая цель получает СВОЮ рамку: единый union-контур вокруг нескольких
	# несвязанных элементов (например, три строки результата) выглядел как
	# странный размытый прямоугольник, а не подсветка трёх кнопок.
	_rects.clear()
	var any_visible := false
	for t in _targets:
		if (t as Control).is_visible_in_tree():
			any_visible = true
			_rects.append((t as Control).get_global_rect())
	if not any_visible:
		visible = false
		return
	visible = true
	_time += delta
	_outline.queue_redraw()


func _draw_outline() -> void:
	var pulse := 0.5 + 0.5 * sin(_time * TAU * PULSE_FREQ)
	var alpha := lerpf(MIN_ALPHA, MAX_ALPHA, pulse)
	var width := int(round(lerpf(MIN_WIDTH, MAX_WIDTH, pulse)))
	_inner_style.border_color = Color(_color.r, _color.g, _color.b, alpha)
	_inner_style.set_border_width_all(width)
	_outer_style.border_color = Color(_color.r, _color.g, _color.b, alpha * 0.22)
	_outer_style.set_border_width_all(10)
	var offset := _outline.global_position
	for r in _rects:
		var local := Rect2(r.position - offset, r.size).grow(PAD)
		_outline.draw_style_box(_inner_style, local)
		_outline.draw_style_box(_outer_style, local.grow(2))