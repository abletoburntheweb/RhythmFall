# scenes/profile/components/profile_genres_panel.gd
class_name ProfileGenresPanel
extends VBoxContainer

const _CARD_SCENE: PackedScene = preload("res://scenes/profile/components/genre_mastery_card.tscn")
const _ProfileGenrePortrait = preload("res://logic/domain/profile/profile_genre_portrait.gd")
const _ProfileGenreMastery = preload("res://logic/domain/profile/profile_genre_mastery.gd")
const GRID_COLUMNS := 2

@onready var _title_label: Label = %TitleLabel
@onready var _catalog_label: Label = %CatalogLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _hint_label: Label = %HintLabel
@onready var _grid: GridContainer = %GenresGrid

var _row_syncing := false
var _built := false
var _refresh_token := 0


func _ready() -> void:
	apply_locale()
	var placeholder := get_node_or_null("../GenresPlaceholderCard")
	if placeholder:
		placeholder.queue_free()


func is_built() -> bool:
	return _built and _grid != null and _grid.get_child_count() > 0


func refresh_catalog_only() -> void:
	_refresh_catalog_label()


func apply_locale() -> void:
	if _title_label:
		_title_label.text = tr("PROFILE_GENRES_TITLE")
		_title_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.98, 1.0))
		_title_label.add_theme_font_size_override("font_size", 24)
	if _catalog_label:
		_catalog_label.add_theme_color_override("font_color", Color(0.62, 0.7, 0.82, 0.95))
	if _subtitle_label:
		_subtitle_label.text = tr("PROFILE_GENRES_SUBTITLE")
		_subtitle_label.add_theme_color_override("font_color", Color(0.55, 0.62, 0.72, 0.9))
		_subtitle_label.add_theme_font_size_override("font_size", 14)
	if _hint_label:
		_hint_label.text = tr("PROFILE_GENRE_MASTERY_HINT")
		_hint_label.add_theme_color_override("font_color", Color(0.48, 0.52, 0.58, 0.88))
	_refresh_catalog_label()
	for card in _grid.get_children():
		if card.has_method("apply_locale"):
			card.apply_locale()


func refresh_async(genre_play_counts: Dictionary = {}, animate_bars: bool = false) -> void:
	if _grid == null:
		return
	_refresh_token += 1
	var token := _refresh_token
	if genre_play_counts.is_empty() and TrackStatsManager:
		genre_play_counts = TrackStatsManager.genre_play_counts

	_refresh_catalog_label(genre_play_counts)
	_built = false

	for child in _grid.get_children():
		child.queue_free()
	await get_tree().process_frame
	if token != _refresh_token:
		return

	var card_index := 0
	for group_id in _ProfileGenrePortrait.all_group_ids():
		var plays := _ProfileGenrePortrait.group_play_count(genre_play_counts, group_id)
		var card: PanelContainer = _CARD_SCENE.instantiate()
		_grid.add_child(card)
		if card.has_method("setup"):
			await card.setup(group_id, plays, genre_play_counts)
		if animate_bars and card.has_method("animate_bar"):
			card.animate_bar(0.55, float(card_index) * 0.04)
		if card.has_signal("expanded_changed"):
			card.expanded_changed.connect(_on_card_expanded_changed)
		card_index += 1
		if card_index % 2 == 0:
			await get_tree().process_frame
		if token != _refresh_token:
			return

	_built = true


func _on_card_expanded_changed(group_id: String, expanded: bool) -> void:
	if _row_syncing or _grid == null:
		return
	var card_index := _card_index_for_group(group_id)
	var partner_index := _row_partner_index(card_index)
	if partner_index < 0:
		return
	var partner := _grid.get_child(partner_index)
	if not partner.has_method("is_expanded") or not partner.has_method("set_expanded"):
		return
	if partner.is_expanded() == expanded:
		return
	_row_syncing = true
	partner.set_expanded(expanded)
	_row_syncing = false


func _card_index_for_group(group_id: String) -> int:
	for i in _grid.get_child_count():
		var card := _grid.get_child(i)
		if card.has_method("get_group_id") and card.get_group_id() == group_id:
			return i
	return -1


func _row_partner_index(card_index: int) -> int:
	if card_index < 0:
		return -1
	var row := int(card_index / GRID_COLUMNS)
	var col := card_index % GRID_COLUMNS
	var partner_index := row * GRID_COLUMNS + (1 - col)
	if partner_index >= _grid.get_child_count():
		return -1
	return partner_index


func _refresh_catalog_label(genre_play_counts: Dictionary = {}) -> void:
	if _catalog_label == null:
		return
	if genre_play_counts.is_empty() and TrackStatsManager:
		genre_play_counts = TrackStatsManager.genre_play_counts
	var discovered := _ProfileGenreMastery.total_discovered(genre_play_counts)
	var catalog := _ProfileGenreMastery.total_catalog_size()
	_catalog_label.text = tr("PROFILE_GENRES_CATALOG_GLOBAL") % [discovered, catalog]
