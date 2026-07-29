# scenes/song_select/playlists/playlist_editor_screen.gd
extends BaseScreen

const FILTER_DIALOG_SCENE := preload("res://scenes/song_select/playlists/playlist_filter_dialog.tscn")

const _PlaylistCatalog = preload("res://logic/domain/library/playlist_catalog.gd")
const _PlaylistStats = preload("res://logic/domain/library/playlist_stats.gd")
const _GoalDiff = preload("res://logic/domain/generation/generation_goal_difficulty.gd")
const _ChartDifficultyAnalyzer = preload("res://logic/domain/charts/chart_difficulty_analyzer.gd")
const _NotesUtils = preload("res://logic/domain/rhythm/notes_utils.gd")
const _ChartStemChips = preload("res://scenes/song_select/lib/chart_stem_chips.gd")
const _RhythmDnaCoverLoader = preload("res://scenes/song_select/rhythm_dna/lib/rhythm_dna_cover_loader.gd")
const _SongSelectUiStyles = preload("res://scenes/song_select/lib/song_select_ui_styles.gd")
const _PlaylistUiHelpers = preload("res://scenes/song_select/playlists/playlist_ui_helpers.gd")

const ROW_HEIGHT := 76
const CHECKBOX_SIZE := 28
const ROW_COVER_SIZE := 56
const REBUILD_DEBOUNCE_SEC := 0.12

var _playlist_id := ""
var _view_filter: Dictionary = {}
var _entries: Array[Dictionary] = []
var _expanded_paths: Dictionary = {}
var _catalog_cache: Array[Dictionary] = []
var _catalog_cache_key := ""
var _rebuild_timer: Timer
var _filter_dialog: PlaylistFilterDialog = null

@onready var _back_button: Button = %BackButton
@onready var _name_edit: LineEdit = %NameEdit
@onready var _stats_label: Label = %StatsLabel
@onready var _search_edit: LineEdit = %SearchEdit
@onready var _filter_button: Button = %FilterButton
@onready var _filter_summary: Label = %FilterSummaryLabel
@onready var _list_scroll: ScrollContainer = %ListScroll
@onready var _list_vbox: VBoxContainer = %ListVBox
@onready var _empty_label: Label = %EmptyLabel
@onready var _tags_row: HBoxContainer = %TagsRow
@onready var _count_label: Label = %CountLabel
@onready var _done_button: Button = %DoneButton
@onready var _panel: PanelContainer = %EditorPanel


func _ready() -> void:
	var game_engine := get_parent()
	if game_engine and game_engine.has_method("get_transitions"):
		setup_managers(game_engine.get_transitions())
	if _panel:
		_panel.add_theme_stylebox_override("panel", _SongSelectUiStyles.card_panel_style())
	if _back_button and not _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.connect(_on_back_pressed)
	if _done_button and not _done_button.pressed.is_connected(_on_done_pressed):
		_done_button.pressed.connect(_on_done_pressed)
	if _filter_button and not _filter_button.pressed.is_connected(_on_filter_pressed):
		_filter_button.pressed.connect(_on_filter_pressed)
	if _search_edit and not _search_edit.text_changed.is_connected(_on_search_changed):
		_search_edit.text_changed.connect(_on_search_changed)
	if _name_edit and not _name_edit.text_submitted.is_connected(_on_name_submitted):
		_name_edit.text_submitted.connect(_on_name_submitted)
	_rebuild_timer = Timer.new()
	_rebuild_timer.one_shot = true
	_rebuild_timer.wait_time = REBUILD_DEBOUNCE_SEC
	_rebuild_timer.timeout.connect(_rebuild_list)
	add_child(_rebuild_timer)
	_filter_dialog = FILTER_DIALOG_SCENE.instantiate() as PlaylistFilterDialog
	add_child(_filter_dialog)
	_filter_dialog.applied.connect(_on_filter_applied)
	apply_locale()


func setup_editor(playlist_id: String) -> void:
	_playlist_id = str(playlist_id).strip_edges()
	_view_filter = _PlaylistCatalog.view_filter_for(_playlist_id)
	_entries = []
	for item in _PlaylistCatalog.entries_for(_playlist_id):
		if item is Dictionary:
			_entries.append((item as Dictionary).duplicate(true))
	if _name_edit:
		_name_edit.text = _PlaylistCatalog.display_name(_playlist_id)
	_invalidate_catalog_cache()
	_sync_stats()
	_sync_filter_summary()
	_rebuild_list()


func apply_locale() -> void:
	if _back_button:
		_back_button.text = tr("BTN_BACK")
	if _name_edit:
		_name_edit.placeholder_text = tr("PLAYLIST_EDITOR_NAME_PLACEHOLDER")
	if _search_edit:
		_search_edit.placeholder_text = tr("PLAYLIST_EDITOR_SEARCH")
	if _filter_button:
		_filter_button.text = tr("PLAYLIST_EDITOR_FILTER")
	if _done_button:
		_done_button.text = tr("PLAYLIST_EDITOR_DONE")
	_sync_stats()
	_sync_filter_summary()
	_sync_count_label()


func _on_name_submitted(_text: String) -> void:
	_save_name()


func _save_name() -> void:
	if _name_edit == null:
		return
	_PlaylistCatalog.rename_playlist(_playlist_id, _name_edit.text)


func _save_all() -> void:
	_save_name()
	_PlaylistCatalog.save_entries(_playlist_id, _entries, _view_filter)


func _sync_stats() -> void:
	if _stats_label == null:
		return
	var stats := _PlaylistStats.compute_stats_from_entries(_entries, _view_filter)
	_stats_label.text = tr("PLAYLIST_EDITOR_STATS_FMT") % [
		int(stats.get("track_count", 0)),
		_PlaylistStats.format_duration(float(stats.get("duration_sec", 0.0))),
		_PlaylistStats.format_avg_rating(float(stats.get("avg_rating", 0.0))),
	]


func _sync_filter_summary() -> void:
	if _filter_summary == null:
		return
	var vf := _PlaylistCatalog.normalize_view_filter(_view_filter)
	var mode_key := (
		"PLAYLIST_FILTER_MODE_FILTERED"
		if str(vf.get("display_mode", "")) == _PlaylistCatalog.DISPLAY_MODE_FILTERED
		else "PLAYLIST_FILTER_MODE_ALL"
	)
	var goals: Array = vf.get("goals", [])
	var goal_label := tr("GEN_GOAL_%s" % str(goals[0] if not goals.is_empty() else "original").to_upper())
	var diffs: Array = vf.get("difficulties", [])
	var diff_label := tr("PLAYLIST_EDITOR_FILTER_DIFFS_FMT") % diffs.size()
	var notes_label := (
		tr("PLAYLIST_TAG_NOTES_READY")
		if bool(vf.get("notes_ready_only", true))
		else tr("PLAYLIST_EDITOR_FILTER_ALL_CHARTS")
	)
	_filter_summary.text = tr("PLAYLIST_EDITOR_FILTER_SUMMARY_FULL_FMT") % [
		tr(mode_key),
		goal_label,
		diff_label,
		notes_label,
	]
	if _tags_row:
		var stats := _PlaylistStats.compute_stats_from_entries(_entries, vf)
		_PlaylistUiHelpers.add_tags_to_row(_tags_row, stats.get("display_tags", []))


func _sync_count_label() -> void:
	if _count_label:
		_count_label.text = tr("PLAYLIST_EDITOR_SELECTED_FMT") % _entries.size()


func _on_search_changed(_text: String) -> void:
	if _rebuild_timer:
		_rebuild_timer.start(REBUILD_DEBOUNCE_SEC)


func _on_filter_pressed() -> void:
	if _filter_dialog:
		_filter_dialog.open_with_filter(_view_filter)


func _on_filter_applied(filter: Dictionary) -> void:
	_view_filter = _PlaylistCatalog.normalize_view_filter(filter)
	_invalidate_catalog_cache()
	_sync_filter_summary()
	_rebuild_list()


func _invalidate_catalog_cache() -> void:
	_catalog_cache_key = ""
	_catalog_cache.clear()


func _catalog_key() -> String:
	var entry_parts: PackedStringArray = []
	for entry in _entries:
		if entry is Dictionary:
			entry_parts.append(_PlaylistCatalog.entry_key(entry as Dictionary))
	entry_parts.sort()
	return "%s|%s|%s" % [_view_filter.hash(), _search_query(), "|".join(entry_parts)]


func _search_query() -> String:
	return str(_search_edit.text if _search_edit else "").strip_edges().to_lower()


func _ensure_catalog() -> void:
	var key := _catalog_key()
	if key == _catalog_cache_key:
		return
	_catalog_cache_key = key
	_catalog_cache.clear()
	var instrument := str(_view_filter.get("instrument", "drums"))
	var lanes := int(_view_filter.get("lanes", 4))
	var notes_only := bool(_view_filter.get("notes_ready_only", true))
	if SongLibrary != null and SongLibrary.has_method("get_songs_list"):
		for song in SongLibrary.get_songs_list():
			if song is not Dictionary:
				continue
			var path := str(song.get("path", "")).strip_edges()
			if path == "" or not _matches_search(song as Dictionary):
				continue
			var item := _build_catalog_item(song as Dictionary, instrument, lanes, notes_only)
			if item.is_empty():
				continue
			_catalog_cache.append(item)
	_merge_selected_into_catalog()
	if str(_view_filter.get("display_mode", "")) == _PlaylistCatalog.DISPLAY_MODE_FILTERED:
		_catalog_cache.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var ra := float(a.get("best_rating", 0.0))
			var rb := float(b.get("best_rating", 0.0))
			if ra != rb:
				return ra > rb
			return str(a.get("title", "")).nocasecmp_to(str(b.get("title", ""))) < 0
		)
	else:
		_catalog_cache.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return str(a.get("title", "")).nocasecmp_to(str(b.get("title", ""))) < 0
		)


func _merge_selected_into_catalog() -> void:
	var by_path: Dictionary = {}
	for item in _catalog_cache:
		var path := str(item.get("path", "")).strip_edges()
		if path != "":
			by_path[path] = item
	for entry in _entries:
		if entry is not Dictionary:
			continue
		var song_path := str((entry as Dictionary).get("song_path", "")).strip_edges()
		if song_path == "" or by_path.has(song_path):
			continue
		var song := _song_dict_for_path(song_path)
		var instrument := str(_view_filter.get("instrument", "drums"))
		var lanes := int(_view_filter.get("lanes", 4))
		var notes_only := bool(_view_filter.get("notes_ready_only", true))
		var item := _build_catalog_item(song, instrument, lanes, notes_only)
		if item.is_empty():
			item = _build_fallback_catalog_item(song, entry as Dictionary)
		by_path[song_path] = item
		_catalog_cache.append(item)


func _song_dict_for_path(song_path: String) -> Dictionary:
	if SongLibrary != null and SongLibrary.has_method("get_songs_list"):
		for song in SongLibrary.get_songs_list():
			if song is Dictionary and str(song.get("path", "")).strip_edges() == song_path:
				return song as Dictionary
	return {
		"path": song_path,
		"title": song_path.get_file().get_basename(),
		"artist": "",
	}


func _build_fallback_catalog_item(song: Dictionary, entry: Dictionary) -> Dictionary:
	var path := str(song.get("path", "")).strip_edges()
	var stem := str(entry.get("chart_stem", "")).strip_edges().to_lower()
	return {
		"path": path,
		"title": str(song.get("title", path.get_file())),
		"artist": str(song.get("artist", "")),
		"duration_sec": _song_duration_sec(path),
		"best_rating": 0.0,
		"best_stem": stem,
		"ready_stems": [] if stem == "" else [stem],
		"pinned_selected": true,
	}


func _ordered_catalog_items() -> Array:
	var by_path: Dictionary = {}
	for item in _catalog_cache:
		var path := str(item.get("path", "")).strip_edges()
		if path != "":
			by_path[path] = item
	var ordered: Array = []
	var used: Dictionary = {}
	for entry in _entries:
		if entry is not Dictionary:
			continue
		var path := str((entry as Dictionary).get("song_path", "")).strip_edges()
		if path == "" or used.has(path):
			continue
		if by_path.has(path):
			ordered.append(by_path[path])
			used[path] = true
	for item in _catalog_cache:
		var path := str(item.get("path", "")).strip_edges()
		if path == "" or used.has(path):
			continue
		ordered.append(item)
	return ordered


func _build_catalog_item(
	song: Dictionary,
	instrument: String,
	lanes: int,
	notes_only: bool
) -> Dictionary:
	var path := str(song.get("path", "")).strip_edges()
	var goals: Array = _view_filter.get("goals", _GoalDiff.GOALS)
	var diffs: Array = _view_filter.get("difficulties", _GoalDiff.DIFFICULTIES)
	var best_rating := 0.0
	var best_stem := ""
	var ready_stems: Array[String] = []
	for g in goals:
		for d in diffs:
			var stem := _GoalDiff.chart_stem(str(g), str(d))
			if not _NotesUtils.notes_exist(path, instrument, stem, lanes):
				if notes_only:
					continue
			else:
				ready_stems.append(stem)
			var stats := SongLibrary.get_chart_difficulty_variant(path, instrument, stem, lanes)
			var rating := _ChartDifficultyAnalyzer.decimal_rating_from_stats(stats)
			if rating > best_rating:
				best_rating = rating
				best_stem = stem
	if notes_only and ready_stems.is_empty():
		return {}
	if str(_view_filter.get("display_mode", "")) == _PlaylistCatalog.DISPLAY_MODE_FILTERED and best_rating <= 0.0:
		return {}
	return {
		"path": path,
		"title": str(song.get("title", "")),
		"artist": str(song.get("artist", "")),
		"duration_sec": _song_duration_sec(path),
		"best_rating": best_rating,
		"best_stem": best_stem,
		"ready_stems": ready_stems,
	}


func _matches_search(song: Dictionary) -> bool:
	var q := _search_query()
	if q == "":
		return true
	var title := str(song.get("title", "")).to_lower()
	var artist := str(song.get("artist", "")).to_lower()
	return title.contains(q) or artist.contains(q)


func _song_duration_sec(song_path: String) -> float:
	if SongLibrary == null:
		return 0.0
	var meta := SongLibrary.get_metadata_for_song(song_path)
	return _ChartDifficultyAnalyzer.parse_duration_seconds(meta.get("duration", "00:00"))


func _rebuild_list() -> void:
	if _list_vbox == null:
		return
	_ensure_catalog()
	for child in _list_vbox.get_children():
		_list_vbox.remove_child(child)
		child.queue_free()
	var items := _ordered_catalog_items()
	if _empty_label:
		_empty_label.visible = items.is_empty()
		if items.is_empty():
			_empty_label.text = tr("PLAYLIST_EDITOR_LIST_EMPTY")
	var all_charts := (
		str(_view_filter.get("display_mode", "")) == _PlaylistCatalog.DISPLAY_MODE_ALL_CHARTS
	)
	for item in items:
		var path := str(item.get("path", "")).strip_edges()
		if all_charts:
			_list_vbox.add_child(_make_expandable_row(item))
		else:
			_list_vbox.add_child(_make_filtered_row(item))
	_sync_count_label()
	_sync_stats()


func _is_entry_selected(song_path: String, chart_stem: String = "") -> bool:
	for entry in _entries:
		var path := str(entry.get("song_path", "")).strip_edges()
		if path != song_path:
			continue
		var stem := str(entry.get("chart_stem", "")).strip_edges().to_lower()
		if chart_stem == "":
			if stem == "":
				return true
		elif stem == chart_stem.strip_edges().to_lower():
			return true
	return false


func _toggle_song(song_path: String, chart_stem: String = "") -> void:
	var key := _PlaylistCatalog.entry_key({"song_path": song_path, "chart_stem": chart_stem})
	var found := -1
	for i in range(_entries.size()):
		if _PlaylistCatalog.entry_key(_entries[i]) == key:
			found = i
			break
	if found >= 0:
		_entries.remove_at(found)
	else:
		var entry := {"song_path": song_path}
		var stem := str(chart_stem).strip_edges().to_lower()
		if stem != "":
			entry["chart_stem"] = stem
		_entries.append(entry)
	if MusicManager:
		MusicManager.play_modifier_select_sound()
	_save_all()
	_rebuild_list()


func _make_filtered_row(item: Dictionary) -> PanelContainer:
	var path := str(item.get("path", "")).strip_edges()
	var stem := str(item.get("best_stem", "")).strip_edges()
	if stem == "":
		for entry in _entries:
			if str(entry.get("song_path", "")).strip_edges() == path:
				stem = str(entry.get("chart_stem", "")).strip_edges()
				if stem != "":
					break
	var selected := _is_entry_selected(path, stem if stem != "" else "")
	return _make_song_row(item, selected, func() -> void:
		_toggle_song(path, stem)
	)


func _make_expandable_row(item: Dictionary) -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 6)
	var path := str(item.get("path", "")).strip_edges()
	var song_selected := _is_entry_selected(path, "")
	var panel := _make_song_row(item, song_selected, func() -> void:
		_expanded_paths[path] = not bool(_expanded_paths.get(path, false))
		_rebuild_list()
	)
	wrap.add_child(panel)
	if bool(_expanded_paths.get(path, false)):
		var instrument := str(_view_filter.get("instrument", "drums"))
		var lanes := int(_view_filter.get("lanes", 4))
		var selected_stems: Array = []
		for entry in _entries:
			if str(entry.get("song_path", "")).strip_edges() != path:
				continue
			var stem := str(entry.get("chart_stem", "")).strip_edges().to_lower()
			if stem != "":
				selected_stems.append(stem)
		var chips := _ChartStemChips.build_panel(
			path,
			instrument,
			lanes,
			selected_stems,
			func(stem_id: String) -> void:
				_toggle_song(path, stem_id),
			tr("PLAYLIST_EDITOR_CHARTS_TITLE"),
		)
		wrap.add_child(chips)
	return wrap


func _make_song_row(item: Dictionary, selected: bool, on_pressed: Callable) -> PanelContainer:
	var path := str(item.get("path", "")).strip_edges()
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _SongSelectUiStyles.row_panel_style(selected))
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and on_pressed.is_valid():
				on_pressed.call()
	)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)
	var check := CheckBox.new()
	check.button_pressed = selected
	check.custom_minimum_size = Vector2(CHECKBOX_SIZE, CHECKBOX_SIZE)
	check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(check)
	var cover_parts: Dictionary = _SongSelectUiStyles.make_row_cover_thumbnail(ROW_COVER_SIZE)
	var cover_frame: PanelContainer = cover_parts.get("frame")
	var cover: TextureRect = cover_parts.get("cover")
	row.add_child(cover_frame)
	call_deferred("_load_row_cover", cover, path)
	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_col)
	var title := Label.new()
	title.text = str(item.get("title", path.get_file()))
	title.add_theme_font_size_override("font_size", 17)
	text_col.add_child(title)
	var meta := Label.new()
	var rating := float(item.get("best_rating", 0.0))
	var rating_text := _ChartDifficultyAnalyzer.format_compact_rating(rating) if rating > 0.0 else "—"
	meta.text = "%s · %s" % [str(item.get("artist", "")), rating_text]
	meta.add_theme_font_size_override("font_size", 13)
	meta.add_theme_color_override("font_color", Color(0.62, 0.7, 0.82, 0.95))
	text_col.add_child(meta)
	return panel


func _load_row_cover(cover: TextureRect, song_path: String) -> void:
	if not is_instance_valid(cover):
		return
	_SongSelectUiStyles.apply_row_cover_texture(cover, song_path, ROW_COVER_SIZE)


func _on_back_pressed() -> void:
	_save_all()
	if MusicManager:
		MusicManager.play_modifier_deselect_sound()
	if transitions and transitions.has_method("close_playlist_editor_to_hub"):
		transitions.close_playlist_editor_to_hub()


func _on_done_pressed() -> void:
	_save_all()
	if MusicManager:
		MusicManager.play_modifier_select_sound()
	if transitions and transitions.has_method("close_playlist_editor_to_hub"):
		transitions.close_playlist_editor_to_hub()
