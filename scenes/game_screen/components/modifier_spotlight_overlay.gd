# scenes/game_screen/components/modifier_spotlight_overlay.gd
extends Control
class_name ModifierSpotlightOverlay

const _DRAW_STEPS := 28

var _hit_y: float = 0.0
var _band_px: float = 180.0
var _reverse_scroll: bool = false
var _darkness_alpha: float = 0.82


func configure(
	hit_y: float, band_px: float, reverse_scroll: bool = false, darkness_alpha: float = 0.82
) -> void:
	_hit_y = hit_y
	_band_px = maxf(band_px, 1.0)
	_reverse_scroll = reverse_scroll
	_darkness_alpha = clampf(darkness_alpha, 0.0, 1.0)
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	z_index = 48
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)


func _on_resized() -> void:
	queue_redraw()


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var half := _band_px * 0.5
	if _reverse_scroll:
		var y_clear_top := clampf(_hit_y, 0.0, size.y)
		var y_clear_bottom := clampf(_hit_y + half, 0.0, size.y)
		if y_clear_top > 0.5:
			_draw_vignette_above(y_clear_top, y_clear_top)
		if y_clear_bottom < size.y - 0.5:
			_draw_vignette_below_clear(y_clear_bottom, size.y)
	else:
		var y_clear_top := clampf(_hit_y - half, 0.0, size.y)
		var y_clear_bottom := clampf(_hit_y + half, 0.0, size.y)
		if y_clear_top > 0.5:
			_draw_vignette_above(y_clear_top, y_clear_top)
		if y_clear_bottom < size.y - 0.5:
			_draw_vignette_below_clear(y_clear_bottom, size.y)


func _draw_vignette_above(y_clear_bottom: float, y_dark_end: float) -> void:
	if y_clear_bottom <= 0.0:
		draw_rect(Rect2(0.0, 0.0, size.x, y_dark_end), Color(0.0, 0.0, 0.0, _darkness_alpha))
		return
	for i in _DRAW_STEPS:
		var t0 := float(i) / float(_DRAW_STEPS)
		var t1 := float(i + 1) / float(_DRAW_STEPS)
		var y_a := lerpf(y_clear_bottom, 0.0, t0)
		var y_b := lerpf(y_clear_bottom, 0.0, t1)
		var alpha := lerpf(0.0, _darkness_alpha, 1.0 - t0)
		draw_rect(Rect2(0.0, y_b, size.x, y_a - y_b), Color(0.0, 0.0, 0.0, alpha))


func _draw_vignette_below_clear(y_clear_top: float, y_bottom: float) -> void:
	if y_bottom <= y_clear_top + 0.5:
		return
	for i in _DRAW_STEPS:
		var t0 := float(i) / float(_DRAW_STEPS)
		var t1 := float(i + 1) / float(_DRAW_STEPS)
		var y_a := lerpf(y_clear_top, y_bottom, t0)
		var y_b := lerpf(y_clear_top, y_bottom, t1)
		var alpha := lerpf(0.0, _darkness_alpha, t0)
		draw_rect(Rect2(0.0, y_a, size.x, y_b - y_a), Color(0.0, 0.0, 0.0, alpha))
