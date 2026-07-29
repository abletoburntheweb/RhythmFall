extends ItemList
class_name SongItemList

## Draws gold outlines for tracks with unseen medals, aligned with ItemList rows.

var medal_outline_indices: PackedInt32Array = PackedInt32Array()
var difficulty_header_visuals: Dictionary = {}
static var _outline_style: StyleBoxFlat
static var _header_bar_style: StyleBoxFlat

const _UNSEEN_MEDALS_GOLD := Color("#F2B35A")
const _DIFFICULTY_HEADER_ICON_SIZE := 16
const _DIFFICULTY_HEADER_ICON_INSET := 10.0
const _DIFFICULTY_HEADER_TEXT_GAP := 8.0
const _HEADER_BG_BOTTOM_GAP := 6.0
const _HEADER_BG_CORNER_RADIUS := 6
const _ITEM_V_SEPARATION := 4
const _GROUP_HEADER_BG := Color(0.2, 0.2, 0.2, 1.0)


func _ready() -> void:
	add_theme_constant_override("v_separation", _ITEM_V_SEPARATION)
	if not draw.is_connected(_draw_overlays):
		draw.connect(_draw_overlays)
	var vbar := get_v_scroll_bar()
	if vbar and not vbar.value_changed.is_connected(_on_scroll_changed):
		vbar.value_changed.connect(_on_scroll_changed)
	if not resized.is_connected(_on_scroll_changed):
		resized.connect(_on_scroll_changed)


func set_medal_outline_indices(indices: PackedInt32Array) -> void:
	medal_outline_indices = indices
	queue_redraw()


func set_difficulty_header_visuals(visuals_by_index: Dictionary) -> void:
	difficulty_header_visuals = visuals_by_index
	queue_redraw()


func _on_scroll_changed(_value: float = 0.0) -> void:
	queue_redraw()


static func _outline_stylebox() -> StyleBoxFlat:
	if _outline_style:
		return _outline_style
	var gold := _UNSEEN_MEDALS_GOLD
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.97, 0.88, 0.08)
	style.border_color = Color(gold.r, gold.g, gold.b, 0.92)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(gold.r, gold.g, gold.b, 0.38)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 1)
	_outline_style = style
	return _outline_style


func is_item_visible(index: int) -> bool:
	if index < 0 or index >= item_count:
		return false
	var rect := _visible_item_rect(index)
	return Rect2(Vector2.ZERO, size).intersects(rect)


func _visible_item_rect(index: int) -> Rect2:
	var rect := get_item_rect(index, true)
	var vbar := get_v_scroll_bar()
	if vbar:
		rect.position.y -= vbar.get_value()
	var hbar := get_h_scroll_bar()
	if hbar:
		rect.position.x -= hbar.get_value()
	return rect


func _draw_overlays() -> void:
	_draw_difficulty_header_visuals()
	_draw_medal_outlines()


static func _header_bar_stylebox() -> StyleBoxFlat:
	if _header_bar_style:
		return _header_bar_style
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(_HEADER_BG_CORNER_RADIUS)
	style.bg_color = _GROUP_HEADER_BG
	_header_bar_style = style
	return _header_bar_style


func _header_bar_rect(index: int) -> Rect2:
	var rect := _visible_item_rect(index)
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return Rect2()
	var bar_h := maxf(rect.size.y - _HEADER_BG_BOTTOM_GAP, 12.0)
	return Rect2(rect.position, Vector2(rect.size.x, bar_h))


func _draw_difficulty_header_visuals() -> void:
	if difficulty_header_visuals.is_empty():
		return
	var view := Rect2(Vector2.ZERO, size)
	var style := _header_bar_stylebox()
	var icon_size := float(_DIFFICULTY_HEADER_ICON_SIZE)
	var font := get_theme_font(&"font")
	var font_size := get_theme_font_size(&"font_size")
	for idx_key in difficulty_header_visuals.keys():
		var idx := int(idx_key)
		if idx < 0 or idx >= item_count:
			continue
		var visual: Dictionary = difficulty_header_visuals[idx_key]
		var rating := int(visual.get("rating", 0))
		var count := int(visual.get("count", 0))
		var color: Color = visual.get("color", Color.WHITE)
		var bar_rect := _header_bar_rect(idx)
		if bar_rect.size.x <= 1.0 or bar_rect.size.y <= 1.0:
			continue
		if not view.intersects(bar_rect):
			continue
		style.bg_color = _GROUP_HEADER_BG
		style.draw(get_canvas_item(), bar_rect)
		var text_x := bar_rect.position.x + _DIFFICULTY_HEADER_ICON_INSET
		var texture: Texture2D = ChartDifficultyAnalyzer.rating_icon(rating)
		if texture:
			var icon_rect := Rect2(
				Vector2(text_x, bar_rect.position.y + (bar_rect.size.y - icon_size) * 0.5),
				Vector2(icon_size, icon_size)
			)
			draw_texture_rect(texture, icon_rect, false)
			text_x += icon_size + _DIFFICULTY_HEADER_TEXT_GAP
		if font:
			var label := "%d  %d" % [rating, count]
			var ascent := font.get_ascent(font_size)
			var descent := font.get_descent(font_size)
			var text_y := bar_rect.position.y + (bar_rect.size.y + ascent - descent) * 0.5
			draw_string(font, Vector2(text_x, text_y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_medal_outlines() -> void:
	if medal_outline_indices.is_empty():
		return
	var style := _outline_stylebox()
	var view := Rect2(Vector2.ZERO, size)
	for idx in medal_outline_indices:
		if idx < 0 or idx >= item_count:
			continue
		var rect := _visible_item_rect(idx)
		if rect.size.x <= 1.0 or rect.size.y <= 1.0:
			continue
		if not view.intersects(rect):
			continue
		rect = rect.grow(-2.0)
		style.draw(get_canvas_item(), rect)
