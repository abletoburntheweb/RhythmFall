# scenes/song_select/playlists/playlist_editor_screen.gd
extends BaseScreen

const FILTER_DIALOG_SCENE := preload("res://scenes/song_select/playlists/playlist_filter_dialog.tscn")

const _PlaylistCatalog = preload("res://logic/domain/library/playlist_catalog.gd")
const _PlaylistStats = preload("res://logic/domain/library/playlist_stats.gd")
const _GoalDiff = preload("res://logic/domain/generation/generation_goal_difficulty.gd")
const _ChartDifficultyAnalyzer = preload("res://logic/domain/charts/chart_difficulty_analyzer.gd")
const _NotesUtils = preload("res://logic/domain/rhythm/notes_utils.gd")
const _SongSelectUiStyles = preload("res://scenes/song_select/lib/song_select_ui_styles.gd")
const _PlaylistUiHelpers = preload("res://scenes/song_select/playlists/playlist_ui_helpers.gd")
const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")
const _ChartExpandRows = preload("res://scenes/song_select/lib/chart_expand_rows.gd")

const _EndlessSessionConfig = preload("res://logic/domain/session/endless_session_config.gd")

const ROW_HEIGHT := 76
const CHECKBOX_SIZE := 28
const ROW_COVER_SIZE := 56
const SEARCH_DEBOUNCE_SEC := 0.18
const CATALOG_YIELD_EVERY := 12
const ROW_YIELD_EVERY := 8
const COVER_PER_FRAME := 3
const META_SONG_PATH := &"song_path"
const META_CHEVRON := &"chevron"
const META_SONG_PANEL := &"song_panel"
const META_TITLE := &"title_lc"
const META_ARTIST := &"artist_lc"

var _playlist_id := ""
var _view_filter: Dictionary = {}
var _entries: Array[Dictionary] = []
var _expanded_paths: Dictionary = {}
## Full filter catalog (no search). Search only toggles row visibility.
var _filter_catalog: Array[Dictionary] = []
var _filter_catalog_key := ""
var _ui_filter_key := ""
var _rebuild_timer: Timer
var _filter_dialog: PlaylistFilterDialog = null
var _rebuild_token := 0
var _cover_queue: Array[Dictionary] = []
var _cover_pump_running := false

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
@onready var _footer_label: Label = %FooterHintLabel
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
	_rebuild_timer.wait_time = SEARCH_DEBOUNCE_SEC
	_rebuild_timer.timeout.connect(_on_search_debounce_timeout)
	add_child(_rebuild_timer)
	_filter_dialog = FILTER_DIALOG_SCENE.instantiate() as PlaylistFilterDialog
	add_child(_filter_dialog)
	_filter_dialog.applied.connect(_on_filter_applied)
	_ensure_modal_dim()
	apply_locale()
	# setup_editor() may run before @onready nodes exist — rebuild once ready.
	if _playlist_id != "":
		_apply_editor_state_to_ui()


func setup_editor(playlist_id: String) -> void:
	_playlist_id = str(playlist_id).strip_edges()
	_view_filter = _PlaylistCatalog.view_filter_for(_playlist_id)
	_entries = []
	for item in _PlaylistCatalog.entries_for(_playlist_id):
		if item is Dictionary:
			_entries.append((item as Dictionary).duplicate(true))
	_invalidate_catalog_cache()
	if is_inside_tree() and _list_vbox != null:
		_apply_editor_state_to_ui()


func _apply_editor_state_to_ui() -> void:
	if _name_edit:
		_name_edit.text = _PlaylistCatalog.display_name(_playlist_id)
	_sync_stats()
	_sync_filter_summary()
	_sync_count_label()
	run_with_loading(tr("UI_LOADING_PLAYLIST_EDITOR"), _rebuild_list_async)


func apply_locale() -> void:
	if _back_button:
		_back_button.text = tr("BTN_BACK")
		_UiIconHelper.apply_standard_back_button(_back_button)
	if _name_edit:
		_name_edit.placeholder_text = tr("PLAYLIST_EDITOR_NAME_PLACEHOLDER")
	if _search_edit:
		_search_edit.placeholder_text = tr("PLAYLIST_EDITOR_SEARCH")
	if _filter_button:
		_filter_button.text = tr("PLAYLIST_EDITOR_FILTER")
	if _done_button:
		_done_button.text = tr("PLAYLIST_EDITOR_DONE")
	if _footer_label:
		_footer_label.text = tr("PLAYLIST_EDITOR_FOOTER_HINT")
	_sync_stats()
	_sync_filter_summary()
	_sync_count_label()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		accept_event()
		_on_back_pressed()
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	if key_event.keycode == KEY_SLASH and _search_edit:
		if not _search_edit.has_focus():
			_search_edit.grab_focus()
		get_viewport().set_input_as_handled()
		return
	if UiScreenHotkeys.should_block_hotkeys(get_viewport()):
		return
	if key_event.keycode == KEY_F:
		_on_filter_pressed()
		get_viewport().set_input_as_handled()
		return
	if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
		_on_done_pressed()
		get_viewport().set_input_as_handled()


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
	var goal_parts: PackedStringArray = []
	var has_arcade := false
	for g in goals:
		var gid := str(g).strip_edges().to_lower()
		if gid == "":
			continue
		if gid == "arcade":
			has_arcade = true
		goal_parts.append(tr("GEN_GOAL_%s" % gid.to_upper()))
	if goal_parts.is_empty():
		goal_parts.append(tr("GEN_GOAL_ORIGINAL"))
	var parts: PackedStringArray = [tr(mode_key), " · ".join(goal_parts)]
	if has_arcade:
		var diffs: Array = vf.get("difficulties", [])
		var abbrevs: PackedStringArray = []
		for d in diffs:
			var key := "SONG_GEN_ABBR_DIFF_%s" % str(d).strip_edges().to_upper()
			var abbr := tr(key)
			if abbr == key:
				abbr = str(d).substr(0, 1).to_upper()
			if abbr != "" and not abbrevs.has(abbr):
				abbrevs.append(abbr)
		if not abbrevs.is_empty():
			parts.append(" · ".join(abbrevs))
	parts.append(
		tr("PLAYLIST_TAG_NOTES_READY")
		if bool(vf.get("notes_ready_only", true))
		else tr("PLAYLIST_EDITOR_FILTER_ALL_CHARTS")
	)
	_filter_summary.text = " · ".join(parts)
	if _tags_row:
		var stats := _PlaylistStats.compute_stats_from_entries(_entries, vf)
		_PlaylistUiHelpers.add_tags_to_row(_tags_row, stats.get("display_tags", []))


func _sync_count_label() -> void:
	if _count_label:
		_count_label.text = tr("PLAYLIST_EDITOR_SELECTED_FMT") % _entries.size()


func _on_search_changed(_text: String) -> void:
	if _rebuild_timer:
		_rebuild_timer.start(SEARCH_DEBOUNCE_SEC)


func _on_search_debounce_timeout() -> void:
	# Search never rebuilds notes catalog — only toggles visibility of existing rows.
	if _ui_filter_key == _filter_only_key() and _list_vbox and _list_vbox.get_child_count() > 0:
		_apply_search_visibility()
		return
	_rebuild_list_async()


func _on_filter_pressed() -> void:
	if _filter_dialog:
		_filter_dialog.open_with_filter(_view_filter)


func _on_filter_applied(filter: Dictionary) -> void:
	_view_filter = _PlaylistCatalog.normalize_view_filter(filter)
	_invalidate_catalog_cache()
	_sync_filter_summary()
	run_with_loading(tr("UI_LOADING_PLAYLIST_FILTER"), _rebuild_list_async)


func _invalidate_catalog_cache() -> void:
	_filter_catalog_key = ""
	_filter_catalog.clear()
	_ui_filter_key = ""


func _filter_only_key() -> String:
	return str(_view_filter.hash())


func _search_query() -> String:
	return str(_search_edit.text if _search_edit else "").strip_edges().to_lower()


func _ensure_filter_catalog_async() -> void:
	var key := _filter_only_key()
	if key == _filter_catalog_key:
		return
	_filter_catalog_key = key
	_filter_catalog.clear()
	var instrument := str(_view_filter.get("instrument", "drums"))
	var lanes := int(_view_filter.get("lanes", 4))
	var notes_only := bool(_view_filter.get("notes_ready_only", true))
	var n := 0
	if SongLibrary != null and SongLibrary.has_method("get_songs_list"):
		for song in SongLibrary.get_songs_list():
			if song is not Dictionary:
				continue
			var path := str(song.get("path", "")).strip_edges()
			if path == "":
				continue
			var item := _build_catalog_item(song as Dictionary, instrument, lanes, notes_only)
			if item.is_empty():
				continue
			_filter_catalog.append(item)
			n += 1
			if n % CATALOG_YIELD_EVERY == 0:
				await get_tree().process_frame
	_merge_selected_into_filter_catalog()
	if str(_view_filter.get("display_mode", "")) == _PlaylistCatalog.DISPLAY_MODE_FILTERED:
		_filter_catalog.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var ra := float(a.get("best_rating", 0.0))
			var rb := float(b.get("best_rating", 0.0))
			if ra != rb:
				return ra > rb
			return str(a.get("title", "")).nocasecmp_to(str(b.get("title", ""))) < 0
		)
	else:
		_filter_catalog.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return str(a.get("title", "")).nocasecmp_to(str(b.get("title", ""))) < 0
		)


func _merge_selected_into_filter_catalog() -> void:
	var by_path: Dictionary = {}
	for item in _filter_catalog:
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
		_filter_catalog.append(item)


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
	var picker: Array[String] = [] if stem == "" else [stem]
	var duration_sec := _song_duration_sec(path)
	return {
		"path": path,
		"title": str(song.get("title", path.get_file())),
		"artist": str(song.get("artist", "")),
		"bpm": _song_bpm(song, path),
		"duration_sec": duration_sec,
		"duration": _EndlessSessionConfig.format_duration_sec(int(duration_sec)) if duration_sec > 0 else "—",
		"best_rating": 0.0,
		"best_stem": stem,
		"ready_stems": picker.duplicate(),
		"picker_stems": picker.duplicate(),
		"pinned_selected": true,
	}


func _ordered_catalog_items() -> Array:
	var ordered: Array = _filter_catalog.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ta := str(a.get("title", "")).to_lower()
		var tb := str(b.get("title", "")).to_lower()
		if ta == tb:
			return str(a.get("artist", "")).to_lower() < str(b.get("artist", "")).to_lower()
		return ta < tb
	)
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
	var all_mode := (
		str(_view_filter.get("display_mode", "")) == _PlaylistCatalog.DISPLAY_MODE_ALL_CHARTS
	)
	var best_rating := 0.0
	var best_stem := ""
	var ready_stems: Array[String] = []
	for stem in _GoalDiff.stems_for_ready_axes(goals, diffs):
		var exists := _NotesUtils.notes_exist(path, instrument, stem, lanes)
		if not exists:
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
	var picker_stems: Array[String] = _ChartExpandRows.stems_for_filter(
		path, instrument, lanes, goals, diffs, notes_only, all_mode
	)
	var duration_sec := _song_duration_sec(path)
	return {
		"path": path,
		"title": str(song.get("title", "")),
		"artist": str(song.get("artist", "")),
		"bpm": _song_bpm(song, path),
		"duration_sec": duration_sec,
		"duration": _EndlessSessionConfig.format_duration_sec(int(duration_sec)) if duration_sec > 0 else "—",
		"best_rating": best_rating,
		"best_stem": best_stem,
		"ready_stems": ready_stems,
		"picker_stems": picker_stems,
	}


func _song_duration_sec(song_path: String) -> float:
	if SongLibrary == null:
		return 0.0
	var meta := SongLibrary.get_metadata_for_song(song_path)
	return _ChartDifficultyAnalyzer.parse_duration_seconds(meta.get("duration", "00:00"))


func _song_bpm(song: Dictionary, song_path: String) -> String:
	var bpm := str(song.get("bpm", "")).strip_edges()
	if bpm != "":
		return bpm
	if SongLibrary == null:
		return ""
	var meta := SongLibrary.get_metadata_for_song(song_path)
	return str(meta.get("bpm", "")).strip_edges()


func _rebuild_list_async() -> void:
	if _list_vbox == null:
		return
	_rebuild_token += 1
	var token := _rebuild_token
	_cover_queue.clear()
	await _ensure_filter_catalog_async()
	if token != _rebuild_token or not is_inside_tree():
		return
	var scroll_y := _list_scroll.scroll_vertical if _list_scroll else 0
	for child in _list_vbox.get_children():
		_list_vbox.remove_child(child)
		child.queue_free()
	var items := _ordered_catalog_items()
	var n := 0
	for item in items:
		if token != _rebuild_token:
			return
		_list_vbox.add_child(_make_expandable_row(item))
		n += 1
		if n % ROW_YIELD_EVERY == 0:
			await get_tree().process_frame
	if token != _rebuild_token:
		return
	_ui_filter_key = _filter_only_key()
	_apply_search_visibility()
	_sync_count_label()
	_sync_stats()
	if _list_scroll:
		await get_tree().process_frame
		_list_scroll.scroll_vertical = scroll_y
	_pump_cover_queue()


func _apply_search_visibility() -> void:
	if _list_vbox == null:
		return
	var any_visible := false
	for child in _list_vbox.get_children():
		if child is not VBoxContainer:
			continue
		var title_lc := str(child.get_meta(META_TITLE, "")).to_lower()
		var artist_lc := str(child.get_meta(META_ARTIST, "")).to_lower()
		var q := _search_query()
		var vis := q == "" or title_lc.contains(q) or artist_lc.contains(q)
		(child as Control).visible = vis
		if vis:
			any_visible = true
	if _empty_label:
		_empty_label.visible = not any_visible
		if not any_visible:
			_empty_label.text = tr("PLAYLIST_EDITOR_LIST_EMPTY")


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


func _path_has_selection(song_path: String) -> bool:
	for entry in _entries:
		if str(entry.get("song_path", "")).strip_edges() == song_path:
			return true
	return false


func _selected_stem_count(song_path: String) -> int:
	var n := 0
	for entry in _entries:
		if str(entry.get("song_path", "")).strip_edges() != song_path:
			continue
		n += 1
	return n


func _find_catalog_item(song_path: String) -> Dictionary:
	for item in _filter_catalog:
		if str(item.get("path", "")).strip_edges() == song_path:
			return item
	return {}


func _find_row_wrap(song_path: String) -> VBoxContainer:
	if _list_vbox == null:
		return null
	for child in _list_vbox.get_children():
		if child is VBoxContainer and str(child.get_meta(META_SONG_PATH, "")) == song_path:
			return child as VBoxContainer
	return null


func _toggle_song(song_path: String, chart_stem: String = "") -> void:
	var stem := str(chart_stem).strip_edges().to_lower()
	if stem != "":
		var kept: Array[Dictionary] = []
		for entry in _entries:
			var path := str(entry.get("song_path", "")).strip_edges()
			var estem := str(entry.get("chart_stem", "")).strip_edges().to_lower()
			if path == song_path and estem == "":
				continue
			kept.append(entry)
		_entries = kept
	var key := _PlaylistCatalog.entry_key({"song_path": song_path, "chart_stem": stem})
	var found := -1
	for i in range(_entries.size()):
		if _PlaylistCatalog.entry_key(_entries[i]) == key:
			found = i
			break
	if found >= 0:
		_entries.remove_at(found)
	else:
		var entry := {"song_path": song_path}
		if stem != "":
			entry["chart_stem"] = stem
		_entries.append(entry)
	if MusicManager:
		MusicManager.play_modifier_select_sound()
	_save_all()
	_refresh_path_row(song_path)


func _toggle_path_selection(song_path: String) -> void:
	var kept: Array[Dictionary] = []
	for entry in _entries:
		if str(entry.get("song_path", "")).strip_edges() != song_path:
			kept.append(entry)
	if _path_has_selection(song_path):
		_entries = kept
	else:
		kept.append({"song_path": song_path})
		_entries = kept
	if MusicManager:
		MusicManager.play_modifier_select_sound()
	_save_all()
	_refresh_path_row(song_path)


func _refresh_path_row(song_path: String) -> void:
	var wrap := _find_row_wrap(song_path)
	var item := _find_catalog_item(song_path)
	if wrap == null or item.is_empty():
		_sync_count_label()
		_sync_stats()
		return
	var idx := wrap.get_index()
	var expanded := bool(_expanded_paths.get(song_path, false))
	_list_vbox.remove_child(wrap)
	wrap.queue_free()
	var new_wrap := _make_expandable_row(item)
	_list_vbox.add_child(new_wrap)
	_list_vbox.move_child(new_wrap, idx)
	_apply_search_visibility()
	_sync_count_label()
	_sync_stats()
	_pump_cover_queue()


func _picker_stems_for_item(item: Dictionary, song_path: String) -> Array[String]:
	var cached: Variant = item.get("picker_stems", null)
	if cached is Array:
		var out: Array[String] = []
		for s in cached as Array:
			out.append(str(s))
		return out
	var instrument := str(_view_filter.get("instrument", "drums"))
	var lanes := int(_view_filter.get("lanes", 4))
	var notes_only := bool(_view_filter.get("notes_ready_only", true))
	var all_mode := (
		str(_view_filter.get("display_mode", "")) == _PlaylistCatalog.DISPLAY_MODE_ALL_CHARTS
	)
	var goals: Array = _view_filter.get("goals", _GoalDiff.GOALS)
	var diffs: Array = _view_filter.get("difficulties", _GoalDiff.DIFFICULTIES)
	return _ChartExpandRows.stems_for_filter(
		song_path, instrument, lanes, goals, diffs, notes_only, all_mode
	)


func _make_expandable_row(item: Dictionary) -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 6)
	var path := str(item.get("path", "")).strip_edges()
	wrap.set_meta(META_SONG_PATH, path)
	wrap.set_meta(META_TITLE, str(item.get("title", "")).to_lower())
	wrap.set_meta(META_ARTIST, str(item.get("artist", "")).to_lower())
	var expanded := bool(_expanded_paths.get(path, false))
	var built := _make_song_row(item, _path_has_selection(path), expanded)
	var panel: PanelContainer = built.get("panel")
	wrap.set_meta(META_SONG_PANEL, panel)
	wrap.set_meta(META_CHEVRON, built.get("chevron"))
	wrap.add_child(panel)
	if expanded:
		wrap.add_child(_make_chart_picker(path, item))
	return wrap


func _toggle_expand(song_path: String, wrap: VBoxContainer) -> void:
	var expanded := not bool(_expanded_paths.get(song_path, false))
	_expanded_paths[song_path] = expanded
	while wrap.get_child_count() > 1:
		var c := wrap.get_child(1)
		wrap.remove_child(c)
		c.queue_free()
	var chevron: Label = wrap.get_meta(META_CHEVRON, null) as Label
	if chevron:
		chevron.text = "▾" if expanded else "▸"
	if expanded:
		var item := _find_catalog_item(song_path)
		wrap.add_child(_make_chart_picker(song_path, item))


func _make_chart_picker(song_path: String, item: Dictionary = {}) -> PanelContainer:
	var instrument := str(_view_filter.get("instrument", "drums"))
	var lanes := int(_view_filter.get("lanes", 4))
	var parts: Dictionary = _ChartExpandRows.make_picker_panel(tr("PLAYLIST_EDITOR_CHARTS_TITLE"))
	var panel: PanelContainer = parts.get("panel")
	var outer: VBoxContainer = parts.get("outer")
	var stems := _picker_stems_for_item(item, song_path)
	if stems.is_empty():
		var empty := Label.new()
		empty.text = tr("PLAYLIST_EDITOR_CHARTS_EMPTY")
		empty.add_theme_font_size_override("font_size", 13)
		empty.add_theme_color_override("font_color", Color(0.62, 0.7, 0.82, 0.95))
		outer.add_child(empty)
		return panel
	for stem_id in stems:
		var stem_selected := _is_entry_selected(song_path, stem_id)
		var song_level := _is_entry_selected(song_path, "")
		var selected := stem_selected or song_level
		outer.add_child(_ChartExpandRows.make_chart_row(
			song_path,
			stem_id,
			instrument,
			lanes,
			selected,
			true,
			func() -> void: _toggle_song(song_path, stem_id),
			song_level and not stem_selected
		))
	return panel


func _make_song_row(item: Dictionary, selected: bool, expanded: bool) -> Dictionary:
	var path := str(item.get("path", "")).strip_edges()
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _SongSelectUiStyles.row_panel_style(selected))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)
	var check := CheckBox.new()
	check.button_pressed = selected
	check.custom_minimum_size = Vector2(CHECKBOX_SIZE, CHECKBOX_SIZE)
	check.mouse_filter = Control.MOUSE_FILTER_STOP
	check.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				_toggle_path_selection(path)
				get_viewport().set_input_as_handled()
	)
	row.add_child(check)
	var cover_parts: Dictionary = _SongSelectUiStyles.make_row_cover_thumbnail(ROW_COVER_SIZE)
	var cover_frame: PanelContainer = cover_parts.get("frame")
	var cover: TextureRect = cover_parts.get("cover")
	row.add_child(cover_frame)
	_enqueue_cover(cover, path)
	var stems := _picker_stems_for_item(item, path)
	var sel_n := _selected_stem_count(path)
	var charts_bit := tr("PLAYLIST_EDITOR_CHARTS_META_FMT") % [sel_n, stems.size()]
	row.add_child(_ChartExpandRows.make_title_artist_column(
		str(item.get("title", path.get_file())),
		str(item.get("artist", "")),
		charts_bit
	))
	row.add_child(_ChartExpandRows.make_bpm_duration_stats(
		str(item.get("bpm", "")),
		str(item.get("duration", "—"))
	))
	var chevron := Label.new()
	chevron.text = "▾" if expanded else "▸"
	chevron.add_theme_font_size_override("font_size", 18)
	chevron.add_theme_color_override("font_color", Color(0.72, 0.8, 0.9, 1.0))
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(chevron)
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				var wrap := panel.get_parent() as VBoxContainer
				if wrap:
					_toggle_expand(path, wrap)
	)
	return {"panel": panel, "chevron": chevron}


func _enqueue_cover(cover: TextureRect, song_path: String) -> void:
	_cover_queue.append({"cover": cover, "path": song_path})
	_pump_cover_queue()


func _pump_cover_queue() -> void:
	if _cover_pump_running:
		return
	_cover_pump_running = true
	call_deferred("_cover_pump_step")


func _cover_pump_step() -> void:
	if not is_inside_tree():
		_cover_pump_running = false
		return
	if _cover_queue.is_empty():
		_cover_pump_running = false
		return
	var batch := mini(COVER_PER_FRAME, _cover_queue.size())
	for _i in range(batch):
		var job: Dictionary = _cover_queue.pop_front()
		var cover: TextureRect = job.get("cover") as TextureRect
		var path := str(job.get("path", ""))
		if is_instance_valid(cover) and path != "":
			_SongSelectUiStyles.apply_row_cover_texture(cover, path, ROW_COVER_SIZE)
	if _cover_queue.is_empty():
		_cover_pump_running = false
	else:
		call_deferred("_cover_pump_step")


func _ensure_modal_dim() -> void:
	if get_node_or_null("ModalDim") != null:
		return
	var dim := ColorRect.new()
	dim.name = "ModalDim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.06, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	move_child(dim, 0)


func _on_back_pressed() -> void:
	_save_all()
	if transitions and transitions.has_method("close_playlist_editor_to_hub"):
		transitions.close_playlist_editor_to_hub(false)


func _on_done_pressed() -> void:
	_save_all()
	if transitions and transitions.has_method("close_playlist_editor_to_hub"):
		transitions.close_playlist_editor_to_hub(true)
