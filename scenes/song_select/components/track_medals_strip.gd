extends PanelContainer

signal unseen_medals_viewed

const _UiStyles = preload("res://scenes/song_select/lib/song_select_ui_styles.gd")
const _TrackMedals = preload("res://logic/domain/library/track_medals.gd")
const MEDAL_ICON_SLOT_SCENE := preload("res://scenes/ui/medal_icon_slot.tscn")
const MEDAL_SLOT_COUNT := 8

@onready var _title_label: Label = $Margin/VBox/HeaderRow/MedalsTitleLabel
@onready var _count_label: Label = $Margin/VBox/HeaderRow/MedalsCountLabel
@onready var _detail_label: Label = $Margin/VBox/MedalsDetailLabel
@onready var _grid: GridContainer = $Margin/VBox/MedalsGrid

var _slot_panels: Array[PanelContainer] = []
var _earned_count: int = 0
var _hover_slot_index: int = -1
var _unseen_ids: Array[String] = []
var _pulse_tweens: Dictionary = {}
var _icon_cache: Dictionary = {}


func _ready() -> void:
	add_theme_stylebox_override("panel", _UiStyles.top_bar_panel_style())
	_collect_slots()
	apply_locale()
	clear_track()
	set_process(true)


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var mouse := get_global_mouse_position()
	var new_index := -1
	for i in _slot_panels.size():
		var slot := _slot_panels[i]
		if slot and slot.get_global_rect().has_point(mouse):
			new_index = i
			break
	if new_index != _hover_slot_index:
		_hover_slot_index = new_index
		_update_detail_label()
		_try_acknowledge_unseen_hover()


func _try_acknowledge_unseen_hover() -> void:
	if _hover_slot_index < 0 or _hover_slot_index >= _TrackMedals.ALL_IDS.size():
		return
	if _unseen_ids.is_empty():
		return
	var medal_id := _TrackMedals.ALL_IDS[_hover_slot_index]
	if not _unseen_ids.has(medal_id):
		return
	unseen_medals_viewed.emit()


func _collect_slots() -> void:
	_slot_panels.clear()
	for child in _grid.get_children():
		if child is PanelContainer:
			_slot_panels.append(child)
			_configure_slot_input(child)
	while _slot_panels.size() < MEDAL_SLOT_COUNT:
		_slot_panels.append(null)


func _configure_slot_input(slot: PanelContainer) -> void:
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var center := slot.get_node_or_null("Center") as Control
	if center:
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_slot_icon(slot)
	var abbr_label := slot.get_node_or_null("Center/AbbrLabel") as Control
	if abbr_label:
		abbr_label.visible = false


func apply_locale() -> void:
	if _title_label:
		_title_label.text = tr("TRACK_MEDALS_TITLE")
	_update_detail_label()
	for i in mini(_slot_panels.size(), _TrackMedals.ALL_IDS.size()):
		var slot := _slot_panels[i]
		if slot == null:
			continue
		var medal_id := _TrackMedals.ALL_IDS[i]
		_apply_slot_icon(slot, medal_id, false)
		var unlocked: bool = slot.has_meta("unlocked") and bool(slot.get_meta("unlocked"))
		_apply_slot_detail_meta(slot, medal_id)
	_update_count_label(_earned_count)


func set_track_medals(unlocked_ids: Array, unseen_ids: Array = []) -> void:
	var sanitized := _TrackMedals.sanitize_unlocked(unlocked_ids)
	_unseen_ids = _TrackMedals.sanitize_unlocked(unseen_ids)
	var earned := 0
	for i in mini(_slot_panels.size(), _TrackMedals.ALL_IDS.size()):
		var slot := _slot_panels[i]
		if slot == null:
			continue
		var medal_id := _TrackMedals.ALL_IDS[i]
		var is_unlocked := sanitized.has(medal_id)
		if is_unlocked:
			earned += 1
		var is_unseen := is_unlocked and _unseen_ids.has(medal_id)
		_set_slot_state(slot, medal_id, is_unlocked, is_unseen)
	_earned_count = earned
	_update_count_label(earned)


func clear_track() -> void:
	set_track_medals([], [])


func _set_slot_state(slot: PanelContainer, medal_id: String, unlocked: bool, is_unseen: bool = false) -> void:
	slot.set_meta("unlocked", unlocked)
	_apply_slot_icon(slot, medal_id, unlocked)
	if unlocked:
		slot.add_theme_stylebox_override("panel", _UiStyles.medal_slot_earned_style())
		slot.modulate = Color.WHITE
	else:
		slot.add_theme_stylebox_override("panel", _UiStyles.medal_slot_locked_style())
		slot.modulate = Color(0.72, 0.76, 0.84, 0.92)
	_apply_slot_detail_meta(slot, medal_id)
	_set_slot_pulse(slot, unlocked and is_unseen)


func _ensure_slot_icon(slot: PanelContainer) -> TextureRect:
	var center := slot.get_node_or_null("Center") as Control
	if center == null:
		return null
	var existing := center.get_node_or_null("MedalIcon") as TextureRect
	if existing:
		existing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return existing
	var icon := MEDAL_ICON_SLOT_SCENE.instantiate() as TextureRect
	icon.name = "MedalIcon"
	icon.apply_icon(null, Color.WHITE, Vector2(20, 20))
	center.add_child(icon)
	return icon


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


func _apply_slot_icon(slot: PanelContainer, medal_id: String, unlocked: bool) -> void:
	var icon := _ensure_slot_icon(slot)
	if icon == null:
		return
	icon.texture = _icon_texture(medal_id)
	icon.modulate = Color.WHITE if unlocked else Color(0.72, 0.76, 0.84, 0.95)


func _set_slot_pulse(slot: PanelContainer, enabled: bool) -> void:
	if enabled:
		_start_slot_pulse(slot)
	else:
		_stop_slot_pulse(slot)


func _start_slot_pulse(slot: PanelContainer) -> void:
	if _pulse_tweens.has(slot):
		return
	slot.pivot_offset = slot.size * 0.5
	var tw := create_tween().set_loops()
	tw.tween_property(slot, "scale", Vector2(1.1, 1.1), 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(slot, "modulate", Color(1.35, 1.15, 0.82, 1.0), 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(slot, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(slot, "modulate", Color.WHITE, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tweens[slot] = tw


func _stop_slot_pulse(slot: PanelContainer) -> void:
	if _pulse_tweens.has(slot):
		var tw: Tween = _pulse_tweens[slot]
		if tw and tw.is_valid():
			tw.kill()
		_pulse_tweens.erase(slot)
	slot.scale = Vector2.ONE


func _apply_slot_detail_meta(slot: PanelContainer, medal_id: String) -> void:
	var title := tr(_TrackMedals.title_i18n_key(medal_id))
	var desc := tr(_TrackMedals.desc_i18n_key(medal_id))
	slot.set_meta("medal_detail", "%s — %s" % [title, desc])
	slot.tooltip_text = ""


func _update_detail_label() -> void:
	if _detail_label == null:
		return
	if _hover_slot_index >= 0 and _hover_slot_index < _slot_panels.size():
		var slot := _slot_panels[_hover_slot_index]
		if slot:
			_detail_label.text = str(slot.get_meta("medal_detail", ""))
			_detail_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.98, 1.0))
			return
	_detail_label.text = tr("TRACK_MEDALS_HINT")
	_detail_label.add_theme_color_override("font_color", Color(0.55, 0.64, 0.76, 0.88))


func _update_count_label(earned: int, total: int = MEDAL_SLOT_COUNT) -> void:
	if _count_label:
		var clamped_earned := clampi(earned, 0, total)
		var clamped_total := maxi(total, 1)
		_count_label.text = tr("TRACK_MEDALS_COUNT_FMT") % [clamped_earned, clamped_total]
