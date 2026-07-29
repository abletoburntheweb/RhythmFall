# scenes/series_finish/series_finish_hero_ring.gd
extends Control
class_name SeriesFinishHeroRing

const _PlayModeIds = preload("res://logic/domain/session/play_mode_ids.gd")
const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")

var mode_id: String = ""
var accent: Color = Color(0.62, 0.48, 0.95, 1.0)

var _icon: TextureRect = null
var _glyph: Label = null
var _motion_t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(280, 280)
	clip_contents = false
	_ensure_children()
	set_process(true)
	resized.connect(_on_resized)


func configure(p_mode_id: String, p_accent: Color) -> void:
	mode_id = p_mode_id
	accent = p_accent
	_ensure_children()
	_refresh_icon()
	queue_redraw()


func _on_resized() -> void:
	_center_icon()
	if _glyph:
		_glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()


func _ensure_children() -> void:
	if _icon == null:
		_icon = TextureRect.new()
		_icon.name = "ModeIcon"
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon.custom_minimum_size = Vector2(72, 72)
		_icon.size = Vector2(72, 72)
		add_child(_icon)
	if _glyph == null:
		_glyph = Label.new()
		_glyph.name = "InfinityGlyph"
		_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_glyph.add_theme_font_size_override("font_size", 72)
		_glyph.text = "∞"
		_glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_glyph)


func _refresh_icon() -> void:
	_ensure_children()
	var use_infinity := mode_id == _PlayModeIds.ENDLESS
	_glyph.visible = use_infinity
	_icon.visible = not use_infinity
	_glyph.add_theme_color_override("font_color", accent.lightened(0.2))
	if use_infinity:
		return
	var icon_file := _PlayModeIds.icon_for(mode_id)
	_icon.texture = _UiIconHelper.load_tinted_icon(icon_file, accent.lightened(0.18), 48)
	_icon.custom_minimum_size = Vector2(72, 72)
	_icon.size = Vector2(72, 72)
	_center_icon()


func _center_icon() -> void:
	if _icon == null or size.x <= 1.0:
		return
	_icon.position = (size - _icon.size) * 0.5


func _process(delta: float) -> void:
	_motion_t += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 2.0 or h <= 2.0:
		return
	var center := size * 0.5
	var radius := minf(w, h) * 0.42
	var fill := accent.darkened(0.55)
	fill.a = 0.35
	draw_circle(center, radius * 0.72, fill)
	var segments := 28
	var gap := 0.22
	var sweep := (TAU / float(segments)) * (1.0 - gap)
	var spin := _motion_t * 0.28
	var ring_col := accent.lerp(Color.WHITE, 0.18)
	ring_col.a = 0.9
	var glow := accent
	glow.a = 0.28
	for i in range(segments):
		var a0 := spin + float(i) * (TAU / float(segments))
		var a1 := a0 + sweep
		draw_arc(center, radius, a0, a1, 10, glow, 6.0, true)
		draw_arc(center, radius, a0, a1, 10, ring_col, 2.4, true)
	var inner := accent.lightened(0.1)
	inner.a = 0.35
	draw_arc(center, radius * 0.78, 0.0, TAU, 64, inner, 1.2, true)
	_center_icon()
