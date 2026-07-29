class_name ChartDifficultyMeter
extends HBoxContainer

const ICON_SIZE := 20
const SLOT_SEPARATION := 2
const MAX_SLOTS := ChartDifficultyAnalyzer.MAX_RATING

var _texture: Texture2D
var _slots: Array[Control] = []


func _ready() -> void:
	add_theme_constant_override("separation", SLOT_SEPARATION)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ensure_slots()
	_sync_minimum_size(0)


## Sizes the container to exactly the visible (lit) bolts, so a trailing
## label can sit tight against the last bolt instead of a fixed 10-slot gap.
func _sync_minimum_size(shown_count: int) -> void:
	var count := clampi(shown_count, 0, MAX_SLOTS)
	var width := 0.0
	if count > 0:
		width = float(count) * ICON_SIZE + float(count - 1) * SLOT_SEPARATION
	custom_minimum_size = Vector2(width, float(ICON_SIZE))


func set_decimal_rating(rating: float, tier_color: Color = Color.WHITE) -> void:
	_ensure_slots()
	if rating <= 0.0:
		visible = false
		_clear_slots()
		_sync_minimum_size(0)
		return
	visible = true
	var clamped_visual := minf(rating, float(MAX_SLOTS))
	var full := int(floor(clamped_visual))
	var frac := clamped_visual - float(full)
	if frac < 0.001:
		frac = 0.0
	var partial_idx := full if frac > 0.001 else -1
	if full >= MAX_SLOTS:
		full = MAX_SLOTS
		partial_idx = -1
		frac = 0.0
	for i in MAX_SLOTS:
		var fill := 0.0
		if i < full:
			fill = 1.0
		elif i == partial_idx:
			fill = frac
		(_slots[i] as _BoltSlot).set_fill(fill, _texture, tier_color)
	_sync_minimum_size(maxi(full + (1 if partial_idx != -1 else 0), 1))


func _clear_slots() -> void:
	if _slots.is_empty():
		return
	for slot in _slots:
		(slot as _BoltSlot).set_fill(0.0, _texture, Color.WHITE)


func _ensure_slots() -> void:
	if not _slots.is_empty():
		return
	if _texture == null:
		_texture = load(ChartDifficultyAnalyzer.ICON_PATH) as Texture2D
	for _i in MAX_SLOTS:
		var slot := _BoltSlot.new()
		slot.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(slot)
		_slots.append(slot)


class _BoltSlot extends Control:
	const GHOST_TINT := Color(0.48, 0.54, 0.64, 0.38)

	var _fill := 0.0
	var _tex: Texture2D
	var _tint := Color.WHITE

	func set_fill(fill: float, tex: Texture2D, tint: Color) -> void:
		_fill = clampf(fill, 0.0, 1.0)
		_tex = tex
		_tint = tint
		visible = _fill > 0.001
		queue_redraw()

	func _draw() -> void:
		if _tex == null or _fill <= 0.001:
			return
		var icon_rect := _square_icon_rect()
		if icon_rect.size.x <= 0.0 or icon_rect.size.y <= 0.0:
			return
		if _fill < 0.999:
			draw_texture_rect(_tex, icon_rect, false, GHOST_TINT)
			var tw := _tex.get_width()
			var th := _tex.get_height()
			if tw <= 0 or th <= 0:
				return
			var dst_w := icon_rect.size.x * _fill
			var src_w := float(tw) * _fill
			draw_texture_rect_region(
				_tex,
				Rect2(icon_rect.position.x, icon_rect.position.y, dst_w, icon_rect.size.y),
				Rect2(0.0, 0.0, src_w, float(th)),
				_tint
			)
			return
		draw_texture_rect(_tex, icon_rect, false, _tint)


	func _square_icon_rect() -> Rect2:
		var side := minf(size.x, size.y)
		if side <= 0.0:
			return Rect2()
		return Rect2(
			Vector2((size.x - side) * 0.5, (size.y - side) * 0.5),
			Vector2(side, side)
		)
