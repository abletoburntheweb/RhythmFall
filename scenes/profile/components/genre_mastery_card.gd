# scenes/profile/genre_mastery_card.gd
extends PanelContainer

signal expanded_changed(group_id: String, expanded: bool)

const _ProfileGenrePortrait = preload("res://logic/domain/profile/profile_genre_portrait.gd")
const _ProfileGenreMastery = preload("res://logic/domain/profile/profile_genre_mastery.gd")
const _GenreGroupIcons = preload("res://logic/domain/library/genre_group_icons.gd")
const _UiModifierSounds = preload("res://logic/ui/ui_modifier_sounds.gd")

const COLOR_VALUE := Color(0.784314, 0.823529, 0.901961, 1)
const COLOR_MUTED := Color(0.55, 0.58, 0.65, 0.92)

@export var style_active: StyleBox
@export var style_locked: StyleBox

@onready var _header_row: HBoxContainer = %HeaderRow
@onready var _name_label: Label = %NameLabel
@onready var _expand_label: Label = %ExpandLabel
@onready var _level_label: Label = %LevelLabel
@onready var _progress_bar: ProgressBar = %ProgressBar
@onready var _meta_label: Label = %MetaLabel
@onready var _icon_host: HBoxContainer = %IconHost
@onready var _subgenres_panel: VBoxContainer = %SubgenresPanel
@onready var _subgenres_sep: HSeparator = %SubgenresSep
@onready var _subgenres_flow: FlowContainer = %SubgenresFlow

var _group_id := ""
var _plays := 0
var _genre_play_counts: Dictionary = {}
var _expanded := false
var _subgenres: Array[String] = []
var _chips_built := false
var _bar_styles: Dictionary = {}
var _chip_styles: Dictionary = {}
var _target_bar_value: float = 0.0
var _bar_tween: Tween
var _last_accent := Color.WHITE
var _last_locked := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	gui_input.connect(_on_card_gui_input)
	mouse_entered.connect(_on_card_mouse_entered)
	mouse_exited.connect(_on_card_mouse_exited)
	if _meta_label:
		_meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _subgenres_sep:
		_subgenres_sep.visible = false


func _on_card_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _group_id != "":
			if _expanded:
				_UiModifierSounds.play_deselect()
			else:
				_UiModifierSounds.play_select()
			set_expanded(not _expanded)
			accept_event()


func _on_card_mouse_entered() -> void:
	if _name_label:
		_name_label.add_theme_color_override("font_color", COLOR_VALUE.lightened(0.08))


func _on_card_mouse_exited() -> void:
	_refresh_name_color()


func setup(group_id: String, plays: int, genre_play_counts: Dictionary = {}) -> void:
	_group_id = group_id
	_plays = plays
	_genre_play_counts = genre_play_counts
	_subgenres = _ProfileGenrePortrait.genres_for_group(group_id)
	_dedupe_subgenres()
	_sort_subgenres_by_plays()
	if not is_node_ready():
		await ready
	_chips_built = false
	_apply_state(group_id, plays)


func apply_locale() -> void:
	if _group_id != "":
		_apply_state(_group_id, _plays)
		if _expanded:
			_chips_built = false
			_ensure_subgenre_chips()


func set_expanded(expanded: bool) -> void:
	if _expanded == expanded:
		return
	_expanded = expanded
	if _subgenres_panel:
		_subgenres_panel.visible = _expanded
	if _subgenres_sep:
		_subgenres_sep.visible = _expanded
	if _expand_label:
		_expand_label.text = "▴" if _expanded else "▾"
	if _expanded:
		_ensure_subgenre_chips()
	_apply_card_panel_style()
	_update_meta_text()
	expanded_changed.emit(_group_id, _expanded)


func collapse() -> void:
	set_expanded(false)


func is_expanded() -> bool:
	return _expanded


func get_group_id() -> String:
	return _group_id


func _apply_state(group_id: String, plays: int) -> void:
	_group_id = group_id
	_plays = plays
	var progress: Dictionary = _ProfileGenreMastery.progress_to_next_level(plays)
	var level := int(progress.get("level", 0))
	var at_max := bool(progress.get("at_max", false))
	var locked := level <= 0
	var accent := _ProfileGenreMastery.level_accent_color(level if not locked else 0)
	_last_accent = accent
	_last_locked = locked

	_apply_card_panel_style()

	_name_label.text = _group_label(group_id)
	_refresh_name_color(locked)

	_update_group_icon(group_id, accent if not locked else Color(0.38, 0.4, 0.46, 1), locked)

	if at_max:
		_level_label.text = tr("PROFILE_GENRE_LEVEL_MAX")
	else:
		_level_label.text = tr("PROFILE_GENRE_LEVEL_FMT") % level
	_level_label.add_theme_color_override("font_color", COLOR_MUTED if locked else accent)

	_apply_bar_fill(accent if not locked else Color(0.38, 0.4, 0.46, 1))
	_target_bar_value = 1000.0 if at_max else float(int(round(float(progress.get("ratio", 0.0)) * 1000.0)))
	_progress_bar.value = _target_bar_value
	_update_meta_text(progress, at_max, locked, plays)


func _apply_card_panel_style() -> void:
	var base: StyleBox = style_locked if _last_locked else style_active
	if base == null:
		return
	var sb := base.duplicate() as StyleBoxFlat
	if _expanded:
		sb.bg_color = Color(0.1, 0.105, 0.13, 1.0)
	add_theme_stylebox_override("panel", sb)


func _refresh_name_color(locked: bool = false) -> void:
	if _name_label == null:
		return
	var progress: Dictionary = _ProfileGenreMastery.progress_to_next_level(_plays)
	var level := int(progress.get("level", 0))
	locked = locked or level <= 0
	_name_label.add_theme_color_override("font_color", COLOR_MUTED if locked else COLOR_VALUE)


func _update_meta_text(
	progress: Dictionary = {},
	at_max: bool = false,
	locked: bool = false,
	plays: int = 0,
) -> void:
	if _meta_label == null:
		return
	if progress.is_empty():
		progress = _ProfileGenreMastery.progress_to_next_level(_plays)
		at_max = bool(progress.get("at_max", false))
		locked = int(progress.get("level", 0)) <= 0
		plays = _plays
	var catalog := _subgenres.size()
	var discovered := _ProfileGenreMastery.discovered_count_in_group(_group_id, _genre_play_counts)
	var count_hint := tr("PROFILE_GENRE_GROUP_COUNT_FMT") % [discovered, catalog]
	if at_max:
		_meta_label.text = "%s · %s" % [count_hint, tr("PROFILE_GENRE_PLAYS_FMT") % plays]
	elif locked:
		_meta_label.text = "%s · %s" % [count_hint, tr("PROFILE_GENRE_PROGRESS_LOCKED")]
	else:
		var from_plays := int(progress.get("from", 0))
		var to_plays := int(progress.get("to", 0))
		var span := maxi(to_plays - from_plays, 1)
		var step := clampi(int(progress.get("current", plays)) - from_plays, 0, span)
		_meta_label.text = "%s · %s" % [
			count_hint,
			tr("PROFILE_GENRE_PROGRESS_FMT") % [step, span],
		]


func _dedupe_subgenres() -> void:
	var seen: Dictionary = {}
	var unique: Array[String] = []
	for genre_id in _subgenres:
		var key := str(genre_id).strip_edges().to_lower()
		if key == "" or seen.has(key):
			continue
		seen[key] = true
		unique.append(str(genre_id))
	_subgenres = unique


func _sort_subgenres_by_plays() -> void:
	_subgenres.sort_custom(func(a: String, b: String) -> bool:
		var ca := _ProfileGenrePortrait.display_genre_play_count(_genre_play_counts, a)
		var cb := _ProfileGenrePortrait.display_genre_play_count(_genre_play_counts, b)
		if ca != cb:
			return ca > cb
		return a < b
	)


func _ensure_subgenre_chips() -> void:
	if _chips_built:
		return
	_build_subgenre_chips()
	_chips_built = true


func _build_subgenre_chips() -> void:
	if _subgenres_flow == null:
		return
	for child in _subgenres_flow.get_children():
		child.queue_free()
	for genre_id in _subgenres:
		_subgenres_flow.add_child(_make_genre_chip(str(genre_id)))


func _make_genre_chip(genre_id: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sub_plays := _ProfileGenrePortrait.display_genre_play_count(_genre_play_counts, genre_id)
	var discovered := sub_plays > 0
	chip.add_theme_stylebox_override("panel", _chip_stylebox(discovered))

	var label := Label.new()
	label.text = tr("PROFILE_GENRE_SUBGENRE_PLAYS_FMT") % [genre_id, sub_plays] if discovered else genre_id
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 12)
	if discovered:
		label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.9, 0.98))
	else:
		label.add_theme_color_override("font_color", Color(0.42, 0.44, 0.5, 0.72))
	chip.add_child(label)
	return chip


func _chip_stylebox(discovered: bool = true) -> StyleBoxFlat:
	var key := "discovered" if discovered else "undiscovered"
	if not _chip_styles.has(key):
		var style := StyleBoxFlat.new()
		if discovered:
			style.bg_color = Color(0.11, 0.12, 0.15, 0.88)
		else:
			style.bg_color = Color(0.08, 0.085, 0.1, 0.72)
		style.set_corner_radius_all(6)
		style.content_margin_left = 8
		style.content_margin_top = 3
		style.content_margin_right = 8
		style.content_margin_bottom = 3
		_chip_styles[key] = style
	return _chip_styles[key]


func _apply_bar_fill(color: Color) -> void:
	if _progress_bar == null:
		return
	var key := color.to_html(false)
	if not _bar_styles.has(key):
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(4)
		_bar_styles[key] = style
	_progress_bar.add_theme_stylebox_override("fill", _bar_styles[key])


func animate_bar(duration: float = 0.55, delay: float = 0.0) -> void:
	if _progress_bar == null:
		return
	if _bar_tween and _bar_tween.is_valid():
		_bar_tween.kill()
	_progress_bar.value = 0.0
	_bar_tween = create_tween()
	if delay > 0.0:
		_bar_tween.tween_interval(delay)
	_bar_tween.tween_property(_progress_bar, "value", _target_bar_value, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _group_label(group_id: String) -> String:
	var key := _ProfileGenrePortrait.group_locale_key(group_id)
	var label := tr(key)
	if label == key:
		return group_id.replace("_", " ").capitalize()
	return label


func _update_group_icon(group_id: String, tint: Color, locked: bool) -> void:
	if _icon_host == null:
		return
	for child in _icon_host.get_children():
		child.queue_free()
	var icon_tint := tint if not locked else Color(0.42, 0.44, 0.5, 0.9)
	_icon_host.add_child(_GenreGroupIcons.make_icon_frame_for_group(group_id, icon_tint, 34, 18, false))
