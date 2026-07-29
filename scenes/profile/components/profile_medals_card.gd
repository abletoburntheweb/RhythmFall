# scenes/profile/profile_medals_card.gd
extends PanelContainer

const _TrackMedals = preload("res://logic/domain/library/track_medals.gd")
const _UiStyles = preload("res://scenes/song_select/lib/song_select_ui_styles.gd")

var _count_labels: Array[Label] = []
var _icon_nodes: Array[TextureRect] = []
var _slot_panels: Array[PanelContainer] = []
var _counts_cache: Dictionary = {}
var _icon_cache: Dictionary = {}

@onready var _title_label: Label = $ContentVBox/CardTitle
@onready var _grid: GridContainer = $ContentVBox/MedalsGrid


func _ready() -> void:
	_build_grid_if_needed()
	apply_locale()
	set_counts({})


func _build_grid_if_needed() -> void:
	if _grid.get_child_count() > 0:
		return
	_count_labels.clear()
	_icon_nodes.clear()
	_slot_panels.clear()
	for medal_id in _TrackMedals.ALL_IDS:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 4)

		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(0, 40)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var center := CenterContainer.new()
		center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		center.size_flags_vertical = Control.SIZE_EXPAND_FILL
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(20, 20)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = _icon_texture(medal_id)
		center.add_child(icon)
		slot.add_child(center)

		var count := Label.new()
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.add_theme_font_size_override("font_size", 13)
		count.add_theme_color_override("font_color", Color(0.654902, 0.654902, 0.678431, 1))

		cell.add_child(slot)
		cell.add_child(count)
		_grid.add_child(cell)

		_slot_panels.append(slot)
		_icon_nodes.append(icon)
		_count_labels.append(count)
		slot.tooltip_text = _tooltip_for(medal_id)


func apply_locale() -> void:
	if _title_label:
		_title_label.text = tr("PROFILE_MEDALS_SUMMARY")
	_build_grid_if_needed()
	for i in _TrackMedals.ALL_IDS.size():
		if i >= _slot_panels.size():
			break
		var medal_id := _TrackMedals.ALL_IDS[i]
		_slot_panels[i].tooltip_text = _tooltip_for(medal_id)


func set_counts(counts_by_id: Dictionary) -> void:
	_build_grid_if_needed()
	_counts_cache = counts_by_id.duplicate(true)
	for i in _TrackMedals.ALL_IDS.size():
		if i >= _count_labels.size():
			break
		var medal_id := _TrackMedals.ALL_IDS[i]
		var count := int(counts_by_id.get(medal_id, 0))
		_count_labels[i].text = str(count)
		_apply_slot_style(i, count)


func _apply_slot_style(index: int, count: int) -> void:
	var slot := _slot_panels[index]
	var icon := _icon_nodes[index]
	var medal_id := _TrackMedals.ALL_IDS[index]
	if count > 0:
		slot.add_theme_stylebox_override("panel", _UiStyles.medal_slot_earned_style())
		slot.modulate = Color.WHITE
		icon.modulate = Color.WHITE
	else:
		slot.add_theme_stylebox_override("panel", _UiStyles.medal_slot_locked_style())
		slot.modulate = Color(0.72, 0.76, 0.84, 0.92)
		icon.modulate = Color(0.72, 0.76, 0.84, 0.95)
	slot.tooltip_text = _tooltip_for(medal_id)


func _tooltip_for(medal_id: String) -> String:
	return "%s — %s" % [
		tr(_TrackMedals.title_i18n_key(medal_id)),
		tr(_TrackMedals.desc_i18n_key(medal_id)),
	]


func _icon_texture(medal_id: String) -> Texture2D:
	if _icon_cache.has(medal_id):
		return _icon_cache[medal_id]
	var path := _TrackMedals.icon_path(medal_id)
	if path == "":
		return null
	var tex := load(path) as Texture2D
	if tex:
		_icon_cache[medal_id] = tex
	return tex
