# scenes/game_screen/components/health_bar.gd
extends Control
class_name HealthBar

const _UiRoundedClip = preload("res://logic/ui/ui_rounded_clip.gd")

@onready var _track: Panel = $Track
@onready var _fill: ColorRect = $Track/Fill

var _tween: Tween = null

const COLOR_HIGH     := Color(0.48, 0.78, 0.98, 1.0)
const COLOR_MID      := Color(0.36, 0.58, 0.9,  1.0)
const COLOR_LOW      := Color(0.28, 0.42, 0.78, 1.0)
const COLOR_CRITICAL := Color(0.62, 0.34, 0.72, 1.0)
const COLOR_NF       := Color(0.72, 0.42, 0.88, 0.9)
const COLOR_LAST_CHANCE_FROZEN := Color(0.42, 0.44, 0.48, 0.92)
const FROZEN_MIN_VISIBLE_RATIO := 0.05

var _last_chance_frozen: bool = false
var _stored_ratio: float = 1.0


func _ready() -> void:
	if _track:
		_UiRoundedClip.clip_to_frame(_track)
		_UiRoundedClip.ensure_border_on_top(_track)


func set_ratio(value: float, instant: bool = false, tween_duration: float = 0.14) -> void:
	_stored_ratio = clampf(value, 0.0, 1.0)
	if _last_chance_frozen:
		return
	var ratio      := _stored_ratio
	var top_anchor := 1.0 - ratio
	var col        := _color_for_ratio(ratio)

	if _tween and _tween.is_valid():
		_tween.kill()

	if instant or not is_inside_tree():
		_fill.anchor_top = top_anchor
		_fill.color = col
		return

	_tween = _fill.create_tween()
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(_fill, "anchor_top", top_anchor, tween_duration)
	_tween.parallel().tween_property(_fill, "color", col, tween_duration)


func set_nf_at_zero(active: bool) -> void:
	if _last_chance_frozen:
		return
	_fill.color = COLOR_NF if active else _color_for_ratio(get_ratio())


func set_last_chance_frozen(active: bool) -> void:
	_last_chance_frozen = active
	if _tween and _tween.is_valid():
		_tween.kill()
	if active:
		_fill.anchor_top = 1.0 - FROZEN_MIN_VISIBLE_RATIO
		_fill.color = COLOR_LAST_CHANCE_FROZEN
	else:
		var top_anchor := 1.0 - _stored_ratio
		_fill.anchor_top = top_anchor
		_fill.color = _color_for_ratio(_stored_ratio)


func is_last_chance_frozen() -> bool:
	return _last_chance_frozen


func get_ratio() -> float:
	return _stored_ratio


func _color_for_ratio(ratio: float) -> Color:
	if ratio <= 0.18:
		return COLOR_CRITICAL
	if ratio <= 0.42:
		return COLOR_LOW.lerp(COLOR_MID, ratio / 0.42)
	if ratio <= 0.72:
		return COLOR_MID.lerp(COLOR_HIGH, (ratio - 0.42) / 0.3)
	return COLOR_HIGH
