# scenes/song_select/endless/track_picker_screen.gd
extends BaseScreen

const _EndlessSessionConfig = preload("res://logic/domain/session/endless_session_config.gd")
const _SessionScopeResolver = preload("res://logic/domain/session/session_scope_resolver.gd")
const _ChartDifficultyAnalyzer = preload("res://logic/domain/charts/chart_difficulty_analyzer.gd")
const _RhythmDnaCoverLoader = preload("res://scenes/song_select/rhythm_dna/lib/rhythm_dna_cover_loader.gd")
const _SongSelectUiStyles = preload("res://scenes/song_select/lib/song_select_ui_styles.gd")
const _ProfileGenrePortrait = preload("res://logic/domain/profile/profile_genre_portrait.gd")
const _UiScreenHotkeys = preload("res://logic/ui/ui_screen_hotkeys.gd")
const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")
const _OptionButtonPopupUtils = preload("res://logic/ui/option_button_popup_utils.gd")
const _ChartExpandRows = preload("res://scenes/song_select/lib/chart_expand_rows.gd")
const _GoalDiff = preload("res://logic/domain/generation/generation_goal_difficulty.gd")
const _NotesUtils = preload("res://logic/domain/rhythm/notes_utils.gd")

const ROW_COVER_SIZE := 56
const ROW_HEIGHT := 76
const CHECKBOX_SIZE := 28
const STAT_FONT_SIZE := 16
const GROUP_MODES: Array[String] = ["title", "artist", "genre", "difficulty", "duration"]
const SETTINGS_GROUP_MODE_KEY := "endless_track_picker_group_mode"
const META_SONG_PATH := &"song_path"
const META_ROW_STYLE := &"row_style"
const META_ROW_STYLE_SELECTED := &"row_style_selected"
const META_CHEVRON := &"chevron"
const META_SONG_PANEL := &"song_panel"
const REBUILD_DEBOUNCE_SEC := 0.12

var _config: Dictionary = {}
var _selected_paths: Array[String] = []
var _rows: Array[PanelContainer] = []
var _duration_by_path: Dictionary = {}
var _group_mode: String = "title"
var _catalog_cache: Array[Dictionary] = []
var _catalog_cache_key: String = ""
var _rebuild_timer: Timer
var _expanded_paths: Dictionary = {}

@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _search_edit: LineEdit = %SearchEdit
@onready var _group_by_option: OptionButton = %GroupByOption
@onready var _session_filters_caption: Label = %SessionFiltersCaption
@onready var _filters_label: Label = %FiltersLabel
@onready var _track_list_scroll: ScrollContainer = %TrackListScroll
@onready var _track_list_vbox: VBoxContainer = %TrackListVBox
@onready var _count_label: Label = %CountLabel
@onready var _duration_total_label: Label = %DurationTotalLabel
@onready var _done_button: Button = %DoneButton
@onready var _footer_label: Label = %FooterLabel
@onready var _panel: PanelContainer = %PickerPanel


func _ready() -> void:
	var game_engine := get_parent()
	if game_engine and game_engine.has_method("get_transitions"):
		setup_managers(game_engine.get_transitions())
	if transitions and transitions.has_method("get_staged_endless_session_config"):
		var staged: Dictionary = transitions.get_staged_endless_session_config()
		if not staged.is_empty():
			load_config(staged)
	_group_mode = _restore_group_mode()
	if _panel:
		_panel.add_theme_stylebox_override("panel", _SongSelectUiStyles.card_panel_style())
	_setup_group_by_option()
	if _search_edit and not _search_edit.text_changed.is_connected(_on_search_changed):
		_search_edit.text_changed.connect(_on_search_changed)
	if _group_by_option and not _group_by_option.item_selected.is_connected(_on_group_by_selected):
		_group_by_option.item_selected.connect(_on_group_by_selected)
	if _back_button and not _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.connect(_on_back_pressed)
	if _done_button and not _done_button.pressed.is_connected(_on_done_pressed):
		_done_button.pressed.connect(_on_done_pressed)
	_rebuild_timer = Timer.new()
	_rebuild_timer.one_shot = true
	_rebuild_timer.wait_time = REBUILD_DEBOUNCE_SEC
	_rebuild_timer.timeout.connect(_rebuild_list)
	add_child(_rebuild_timer)
	apply_locale()
	call_deferred("_apply_group_option_popup_font")
	_rebuild_list()


func load_config(config: Dictionary) -> void:
	_config = _EndlessSessionConfig.sanitize(config)
	_invalidate_catalog_cache()
	_selected_paths = []
	var picker_playlist_id := str(_config.get("_picker_playlist_id", "")).strip_edges()
	if picker_playlist_id != "":
		const PlaylistCatalog = preload("res://logic/domain/library/playlist_catalog.gd")
		for path in PlaylistCatalog.song_paths_for(picker_playlist_id):
			if not _selected_paths.has(path):
				_selected_paths.append(path)
	else:
		for path in _config.get("selected_song_paths", []):
			var song_path := str(path).strip_edges()
			if song_path != "" and not _selected_paths.has(song_path):
				_selected_paths.append(song_path)


func apply_locale() -> void:
	if _back_button:
		_back_button.text = tr("BTN_BACK")
	if _title_label:
		_title_label.text = tr("SESSION_TRACK_PICKER_TITLE")
	if _subtitle_label:
		_subtitle_label.text = tr("SESSION_TRACK_PICKER_SUBTITLE")
	if _search_edit:
		_search_edit.placeholder_text = tr("SESSION_TRACK_PICKER_SEARCH")
	if _session_filters_caption:
		_session_filters_caption.text = tr("SESSION_TRACK_PICKER_SESSION_FILTERS")
	if _done_button:
		_done_button.text = tr("SESSION_TRACK_PICKER_DONE")
	if _footer_label:
		_footer_label.text = tr("SESSION_TRACK_PICKER_FOOTER")
	_setup_group_by_option()
	_sync_filters_label()
	_sync_count_label()


func _setup_group_by_option() -> void:
	if _group_by_option == null:
		return
	_group_by_option.set_block_signals(true)
	while _group_by_option.item_count < GROUP_MODES.size():
		_group_by_option.add_item("")
	_group_by_option.set_item_text(0, tr("SONG_FILTER_TITLE"))
	_group_by_option.set_item_text(1, tr("SONG_FILTER_ARTIST"))
	_group_by_option.set_item_text(2, tr("SONG_FILTER_GENRE_GROUP"))
	_group_by_option.set_item_text(3, tr("SONG_FILTER_DIFFICULTY"))
	_group_by_option.set_item_text(4, tr("SONG_FILTER_DURATION"))
	var idx := clampi(GROUP_MODES.find(_group_mode), 0, GROUP_MODES.size() - 1)
	_group_by_option.select(idx)
	_group_by_option.set_block_signals(false)
	_refresh_group_option_icon()


func _apply_group_option_popup_font() -> void:
	if _group_by_option:
		_OptionButtonPopupUtils.apply_popup_font_size(_group_by_option, 24)


func _refresh_group_option_icon() -> void:
	if _group_by_option == null:
		return
	var icon_file := "arrow-down-narrow-wide.svg"
	var tint := Color(0.62, 0.7, 0.82, 0.95)
	if _group_mode == "difficulty":
		icon_file = "chart_difficulty.svg"
		tint = _UiIconHelper.ACCENT
	elif _group_mode == "genre":
		icon_file = "tags.svg"
		tint = _UiIconHelper.ACCENT
	_UiIconHelper.mark_option_button_icon(_group_by_option, icon_file, tint)


func _on_group_by_selected(index: int) -> void:
	var mode := GROUP_MODES[clampi(index, 0, GROUP_MODES.size() - 1)]
	if mode == _group_mode:
		return
	_group_mode = mode
	_persist_group_mode()
	_refresh_group_option_icon()
	if MusicManager:
		MusicManager.play_modifier_select_sound()
	if _rebuild_timer:
		_rebuild_timer.stop()
	_rebuild_list()


func _invalidate_catalog_cache() -> void:
	_catalog_cache_key = ""
	_catalog_cache.clear()


func _config_cache_key() -> String:
	var scope_config := _config.duplicate(true)
	scope_config.erase("selected_song_paths")
	scope_config.erase("track_source")
	return str(_EndlessSessionConfig.sanitize(scope_config).hash())


func _ensure_catalog_cache() -> void:
	var key := _config_cache_key()
	if key == _catalog_cache_key and not _catalog_cache.is_empty():
		return
	_catalog_cache_key = key
	_catalog_cache.clear()
	var instrument := str(_config.get("instrument", _EndlessSessionConfig.DEFAULT_INSTRUMENT))
	if SongLibrary == null or not SongLibrary.has_method("get_songs_list"):
		return
	for song in SongLibrary.get_songs_list():
		if song is not Dictionary:
			continue
		var path := str(song.get("path", "")).strip_edges()
		if path == "":
			continue
		if not _song_in_scope(path, instrument):
			continue
		_catalog_cache.append(_build_entry(song as Dictionary, instrument))


func _rebuild_list() -> void:
	if _track_list_vbox == null:
		return
	_ensure_catalog_cache()
	for child in _track_list_vbox.get_children():
		_track_list_vbox.remove_child(child)
		child.queue_free()
	_rows.clear()
	_duration_by_path.clear()
	var favorite_entries: Array[Dictionary] = []
	var other_entries: Array[Dictionary] = []
	for entry in _catalog_cache:
		if not _matches_search(entry):
			continue
		var path := str(entry.get("path", ""))
		_duration_by_path[path] = int(entry.get("duration_sec", 0))
		if _is_song_favorite(path):
			favorite_entries.append(entry)
		else:
			other_entries.append(entry)
	var search_active := _search_query() != ""
	if not search_active and not favorite_entries.is_empty():
		_track_list_vbox.add_child(_make_section_header(tr("SESSION_TRACK_PICKER_SECTION_FAVORITES")))
		for entry in favorite_entries:
			_add_track_row(entry)
		if not other_entries.is_empty():
			_track_list_vbox.add_child(_make_section_header(tr("SESSION_TRACK_PICKER_SECTION_LIBRARY")))
	for group in _build_groups(other_entries):
		if group.get("type", "") == "header":
			_track_list_vbox.add_child(_make_section_header(str(group.get("text", ""))))
		else:
			_add_track_row(group.get("entry", {}) as Dictionary)
	_sync_count_label()


func _build_groups(entries: Array[Dictionary]) -> Array[Dictionary]:
	if entries.is_empty():
		return []
	match _group_mode:
		"artist":
			return _build_letter_groups(entries, "artist")
		"genre":
			return _build_genre_groups(entries)
		"difficulty":
			return _build_difficulty_groups(entries)
		"duration":
			return _build_duration_groups(entries)
		_:
			return _build_letter_groups(entries, "title")


func _build_genre_groups(entries: Array[Dictionary]) -> Array[Dictionary]:
	var buckets: Dictionary = {}
	for entry in entries:
		var group_id := _ProfileGenrePortrait.resolve_song_group_id(str(entry.get("path", "")))
		if not buckets.has(group_id):
			buckets[group_id] = []
		(buckets[group_id] as Array).append(entry)
	var group_ids := _ProfileGenrePortrait.sorted_group_ids_for_display(buckets.keys())
	var out: Array[Dictionary] = []
	for group_id in group_ids:
		var group_entries: Array = (buckets[group_id] as Array).duplicate()
		group_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return str(a.get("title", "")).nocasecmp_to(str(b.get("title", ""))) < 0
		)
		out.append({
			"type": "header",
			"text": tr("SONG_GROUP_HEADER_FMT") % [
				group_entries.size(),
				tr(_ProfileGenrePortrait.group_locale_key(group_id)),
			],
		})
		for entry in group_entries:
			out.append({"type": "entry", "entry": entry})
	return out


func _build_letter_groups(entries: Array[Dictionary], field: String) -> Array[Dictionary]:
	var buckets: Dictionary = {}
	for entry in entries:
		var source := str(entry.get(field, "")).strip_edges().to_lower()
		var letter := source.substr(0, 1) if source != "" else "?"
		if letter == "":
			letter = "?"
		if not buckets.has(letter):
			buckets[letter] = []
		(buckets[letter] as Array).append(entry)
	var letters: Array = buckets.keys()
	letters.sort()
	var out: Array[Dictionary] = []
	for letter in letters:
		var group_entries: Array = (buckets[letter] as Array).duplicate()
		group_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _entry_sort_key(a, field).nocasecmp_to(_entry_sort_key(b, field)) < 0
		)
		out.append({
			"type": "header",
			"text": tr("SONG_GROUP_HEADER_FMT") % [group_entries.size(), String(letter).to_upper()],
		})
		for entry in group_entries:
			out.append({"type": "entry", "entry": entry})
	return out


func _build_difficulty_groups(entries: Array[Dictionary]) -> Array[Dictionary]:
	var buckets: Dictionary = {}
	for entry in entries:
		var rating := float(entry.get("rating", 0.0))
		var bucket := int(floor(rating)) if rating > 0.0 else 0
		if not buckets.has(bucket):
			buckets[bucket] = []
		(buckets[bucket] as Array).append(entry)
	var keys: Array = buckets.keys()
	keys.sort()
	keys.reverse()
	var out: Array[Dictionary] = []
	for bucket_key in keys:
		var group_entries: Array = (buckets[bucket_key] as Array).duplicate()
		group_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var ra := float(a.get("rating", 0.0))
			var rb := float(b.get("rating", 0.0))
			if ra != rb:
				return ra > rb
			return str(a.get("title", "")).nocasecmp_to(str(b.get("title", ""))) < 0
		)
		var header_rating := float(group_entries[0].get("rating", 0.0))
		var header_label := (
			_ChartDifficultyAnalyzer.format_compact_rating(header_rating)
			if int(bucket_key) > 0
			else tr("SONG_GROUP_DIFFICULTY_NONE")
		)
		out.append({
			"type": "header",
			"text": tr("SONG_GROUP_HEADER_FMT") % [group_entries.size(), header_label],
		})
		for entry in group_entries:
			out.append({"type": "entry", "entry": entry})
	return out


func _build_duration_groups(entries: Array[Dictionary]) -> Array[Dictionary]:
	var buckets: Dictionary = {}
	for entry in entries:
		var bucket := _duration_bucket(entry)
		if not buckets.has(bucket):
			buckets[bucket] = []
		(buckets[bucket] as Array).append(entry)
	var keys: Array = buckets.keys()
	keys.sort_custom(func(a, b) -> bool:
		var ai := int(a)
		var bi := int(b)
		if ai < 0:
			return false
		if bi < 0:
			return true
		return ai > bi
	)
	var out: Array[Dictionary] = []
	for bucket_key in keys:
		var group_entries: Array = (buckets[bucket_key] as Array).duplicate()
		group_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("duration_sec", 0)) > int(b.get("duration_sec", 0))
		)
		out.append({
			"type": "header",
			"text": tr("SONG_GROUP_HEADER_FMT") % [
				group_entries.size(),
				_duration_bucket_label(int(bucket_key)),
			],
		})
		for entry in group_entries:
			out.append({"type": "entry", "entry": entry})
	return out


func _entry_sort_key(entry: Dictionary, field: String) -> String:
	return str(entry.get(field, "")).strip_edges()


func _duration_bucket(entry: Dictionary) -> int:
	var sec := int(entry.get("duration_sec", 0))
	if sec <= 0:
		return -1
	var minutes := sec / 60
	if minutes < 1:
		return 0
	return minutes


func _duration_bucket_label(bucket: int) -> String:
	match bucket:
		-1:
			return tr("SONG_GROUP_DURATION_UNKNOWN")
		0:
			return tr("SONG_GROUP_DURATION_UNDER_1")
		1:
			return tr("SONG_GROUP_DURATION_1_MIN")
		_:
			return tr("SONG_GROUP_DURATION_N_MIN") % bucket


func _add_track_row(entry: Dictionary) -> void:
	var path := str(entry.get("path", ""))
	var wrap := _make_expandable_track_row(entry, _selected_paths.has(path))
	_track_list_vbox.add_child(wrap)
	var panel: PanelContainer = wrap.get_meta(META_SONG_PANEL, null) as PanelContainer
	if panel:
		_rows.append(panel)


func _make_section_header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.55, 0.62, 0.74, 0.95))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_expandable_track_row(entry: Dictionary, selected: bool) -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 6)
	var song_path := str(entry.get("path", "")).strip_edges()
	wrap.set_meta(META_SONG_PATH, song_path)
	var expanded := bool(_expanded_paths.get(song_path, false))
	var built := _make_track_row(entry, selected, expanded)
	var panel: PanelContainer = built.get("panel")
	wrap.set_meta(META_SONG_PANEL, panel)
	wrap.set_meta(META_CHEVRON, built.get("chevron"))
	wrap.add_child(panel)
	if expanded:
		wrap.add_child(_make_session_chart_picker(song_path))
	return wrap


func _make_track_row(entry: Dictionary, selected: bool, expanded: bool) -> Dictionary:
	var song_path := str(entry.get("path", "")).strip_edges()
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.focus_mode = Control.FOCUS_ALL
	panel.set_meta(META_SONG_PATH, song_path)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.13, 0.72)
	style.border_color = Color(1, 1, 1, 0.06)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 14
	style.content_margin_bottom = 10
	var style_selected := style.duplicate() as StyleBoxFlat
	style_selected.bg_color = Color(0.12, 0.14, 0.2, 0.95)
	style_selected.border_color = Color(0.62, 0.48, 0.95, 0.55)
	panel.set_meta(META_ROW_STYLE, style)
	panel.set_meta(META_ROW_STYLE_SELECTED, style_selected)
	panel.add_theme_stylebox_override("panel", style_selected if selected else style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)

	var check := CheckBox.new()
	check.focus_mode = Control.FOCUS_NONE
	check.mouse_filter = Control.MOUSE_FILTER_STOP
	check.button_pressed = selected
	check.custom_minimum_size = Vector2(CHECKBOX_SIZE, CHECKBOX_SIZE)
	check.add_theme_font_size_override("font_size", 18)
	check.set_meta(META_SONG_PATH, song_path)
	check.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				_toggle_row_selection(panel, check)
				get_viewport().set_input_as_handled()
	)
	row.add_child(check)

	var cover_parts: Dictionary = _SongSelectUiStyles.make_row_cover_thumbnail(ROW_COVER_SIZE)
	var cover_frame: PanelContainer = cover_parts.get("frame")
	var cover: TextureRect = cover_parts.get("cover")
	cover_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(cover_frame)
	var tex: Variant = entry.get("cover", null)
	if tex is Texture2D:
		cover.texture = _RhythmDnaCoverLoader.prepare_display_texture(tex, ROW_COVER_SIZE)
	elif song_path != "":
		_SongSelectUiStyles.apply_row_cover_texture(cover, song_path, ROW_COVER_SIZE)
		call_deferred("_load_row_cover", cover, song_path)

	row.add_child(_ChartExpandRows.make_title_artist_column(
		str(entry.get("title", song_path.get_file())),
		str(entry.get("artist", ""))
	))
	row.add_child(_ChartExpandRows.make_bpm_duration_stats(
		str(entry.get("bpm", "")),
		str(entry.get("duration", "—")),
		STAT_FONT_SIZE
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
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				var wrap := panel.get_parent() as VBoxContainer
				if wrap:
					_toggle_track_expand(song_path, wrap)
				get_viewport().set_input_as_handled()
		elif event is InputEventKey:
			var key := event as InputEventKey
			if key.pressed and (key.keycode == KEY_SPACE or key.keycode == KEY_ENTER):
				_toggle_row_selection(panel, check)
				get_viewport().set_input_as_handled()
	)
	return {"panel": panel, "chevron": chevron, "check": check}


func _toggle_track_expand(song_path: String, wrap: VBoxContainer) -> void:
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
		wrap.add_child(_make_session_chart_picker(song_path))


func _make_session_chart_picker(song_path: String) -> PanelContainer:
	var instrument := str(_config.get("instrument", _EndlessSessionConfig.DEFAULT_INSTRUMENT))
	var parts: Dictionary = _ChartExpandRows.make_picker_panel(tr("PLAYLIST_EDITOR_CHARTS_TITLE"))
	var panel: PanelContainer = parts.get("panel")
	var outer: VBoxContainer = parts.get("outer")
	var stems := _session_stems_for_song(song_path, instrument)
	if stems.is_empty():
		var empty := Label.new()
		empty.text = tr("PLAYLIST_EDITOR_CHARTS_EMPTY")
		empty.add_theme_font_size_override("font_size", 13)
		empty.add_theme_color_override("font_color", Color(0.62, 0.7, 0.82, 0.95))
		outer.add_child(empty)
		return panel
	for stem_id in stems:
		var lanes := _ChartDifficultyAnalyzer.canonical_lanes_for_notes(song_path, instrument, stem_id)
		outer.add_child(_ChartExpandRows.make_chart_row(
			song_path,
			stem_id,
			instrument,
			lanes,
			false,
			false,
			Callable(),
			false
		))
	return panel


func _session_stems_for_song(song_path: String, instrument: String) -> Array[String]:
	# Match SessionScopeResolver stem set: goals from session styles, all GoalDiff axes.
	# Rating tiers (easy/med/hard) filter scope, not stem ids.
	var policy := str(_config.get("generation_mode_policy", _EndlessSessionConfig.GEN_MODE_POLICY_ALL))
	var goals: Array = _config.get("generation_modes_allowed", [])
	if policy == _EndlessSessionConfig.GEN_MODE_POLICY_ALL or goals.is_empty():
		goals = _EndlessSessionConfig.UI_CHART_STYLE_GOALS.duplicate()
	var out: Array[String] = []
	for stem in _GoalDiff.stems_for_ready_axes(goals, _GoalDiff.DIFFICULTIES):
		var stem_lanes := _ChartDifficultyAnalyzer.canonical_lanes_for_notes(song_path, instrument, stem)
		if _NotesUtils.notes_exist(song_path, instrument, stem, stem_lanes):
			if not out.has(stem):
				out.append(stem)
	return out


func _toggle_row_selection(panel: PanelContainer, check: CheckBox) -> void:
	var song_path := str(panel.get_meta(META_SONG_PATH, ""))
	if song_path == "":
		return
	var selected := not check.button_pressed
	if selected and not _selected_paths.has(song_path):
		if _selected_paths.size() >= _EndlessSessionConfig.SELECTED_TRACK_PICKER_SOFT_MAX:
			if MusicManager and MusicManager.has_method("play_cancel_sound"):
				MusicManager.play_cancel_sound()
			return
		_selected_paths.append(song_path)
		if MusicManager:
			MusicManager.play_modifier_select_sound()
	elif not selected:
		_selected_paths.erase(song_path)
		if MusicManager:
			MusicManager.play_modifier_deselect_sound()
	_set_row_selected(panel, check, _selected_paths.has(song_path))
	_sync_count_label()


func _set_row_selected(panel: PanelContainer, check: CheckBox, selected: bool) -> void:
	check.button_pressed = selected
	var style: StyleBoxFlat = panel.get_meta(META_ROW_STYLE) as StyleBoxFlat
	var style_selected: StyleBoxFlat = panel.get_meta(META_ROW_STYLE_SELECTED) as StyleBoxFlat
	panel.add_theme_stylebox_override("panel", style_selected if selected else style)


func _build_entry(song: Dictionary, instrument: String) -> Dictionary:
	var path := str(song.get("path", "")).strip_edges()
	var title := _sanitize_display_text(str(song.get("title", path.get_file())).strip_edges())
	var artist := _sanitize_display_text(str(song.get("artist", "")).strip_edges())
	var display := title if artist == "" else "%s — %s" % [artist, title]
	var meta := SongLibrary.get_metadata_for_song(path) if SongLibrary else {}
	var bpm := _sanitize_display_text(str(song.get("bpm", meta.get("bpm", ""))).strip_edges())
	var duration_raw := str(song.get("duration", meta.get("duration", ""))).strip_edges()
	var duration_sec := _ChartDifficultyAnalyzer.parse_duration_seconds(duration_raw)
	var scope_chart := _scope_chart_for_song(path, instrument)
	if duration_sec <= 0:
		duration_sec = int(scope_chart.get("duration_sec", 0))
	var duration_text := _EndlessSessionConfig.format_duration_sec(duration_sec) if duration_sec > 0 else duration_raw
	if duration_text == "":
		duration_text = "—"
	var rating := float(scope_chart.get("decimal_rating", 0.0))
	return {
		"path": path,
		"title": title,
		"artist": artist,
		"display": display,
		"bpm": bpm,
		"duration": duration_text,
		"duration_sec": duration_sec,
		"rating": rating,
		"rating_mode": str(scope_chart.get("mode", "")),
	}


func _load_row_cover(cover: TextureRect, song_path: String) -> void:
	if not is_instance_valid(cover):
		return
	_SongSelectUiStyles.apply_row_cover_texture(cover, song_path, ROW_COVER_SIZE)


func _scope_chart_for_song(song_path: String, instrument: String) -> Dictionary:
	return _SessionScopeResolver.best_scope_chart_for_song(song_path, _config, instrument)


func _song_in_scope(song_path: String, instrument: String) -> bool:
	return not _scope_chart_for_song(song_path, instrument).is_empty()


func _is_song_favorite(path: String) -> bool:
	if PlayerDataManager == null:
		return false
	if PlayerDataManager.has_method("is_song_favorite"):
		return PlayerDataManager.is_song_favorite(path)
	return false


func _sync_filters_label() -> void:
	if _filters_label == null:
		return
	var dmin := float(_config.get("difficulty_min", _EndlessSessionConfig.DIFFICULTY_BASE_MIN))
	var dmax := float(_config.get("difficulty_max", _EndlessSessionConfig.DIFFICULTY_BASE_MAX))
	var max_over_cap := bool(_config.get("difficulty_max_over_cap", false))
	var dur_min := int(_config.get("duration_min_sec", _EndlessSessionConfig.DEFAULT_DURATION_MIN_SEC))
	var dur_max := int(_config.get("duration_max_sec", _EndlessSessionConfig.DEFAULT_DURATION_MAX_SEC))
	var dur_open := bool(_config.get("duration_max_open", false))
	var gen_text := _EndlessSessionConfig.preview_generation_modes_text(
		str(_config.get("generation_mode_policy", _EndlessSessionConfig.GEN_MODE_POLICY_ALL)),
		_config.get("generation_modes_allowed", [])
	)
	_filters_label.text = tr("SESSION_TRACK_PICKER_FILTERS_SUMMARY_FMT") % [
		_EndlessSessionConfig.format_difficulty_range(dmin, dmax, max_over_cap),
		_EndlessSessionConfig.format_duration_range(dur_min, dur_max, dur_open),
		gen_text,
	]


func _sync_count_label() -> void:
	if _count_label:
		_count_label.text = tr("SESSION_TRACK_PICKER_COUNT_FMT") % [
			_selected_paths.size(),
			_EndlessSessionConfig.SELECTED_TRACK_PICKER_SOFT_MAX,
		]
	if _duration_total_label:
		var total_sec := _total_selected_duration_sec()
		_duration_total_label.text = tr("SESSION_TRACK_PICKER_SELECTED_DURATION_FMT") % [
			_EndlessSessionConfig.format_duration_sec(total_sec) if total_sec > 0 else "—",
		]
	if _done_button:
		_done_button.disabled = _selected_paths.size() < _EndlessSessionConfig.SELECTED_TRACK_PICKER_MIN


func _total_selected_duration_sec() -> int:
	var total := 0
	for path in _selected_paths:
		if _duration_by_path.has(path):
			total += int(_duration_by_path[path])
		else:
			total += _fallback_duration_sec(path)
	return total


func _fallback_duration_sec(path: String) -> int:
	var instrument := str(_config.get("instrument", _EndlessSessionConfig.DEFAULT_INSTRUMENT))
	var scope_chart := _scope_chart_for_song(path, instrument)
	return int(scope_chart.get("duration_sec", 0))


func _search_query() -> String:
	return _search_edit.text.strip_edges().to_lower() if _search_edit else ""


func _matches_search(entry: Dictionary) -> bool:
	var query := _search_query()
	if query == "":
		return true
	var display := str(entry.get("display", "")).to_lower()
	var path := str(entry.get("path", "")).to_lower()
	return display.contains(query) or path.contains(query)


func _restore_group_mode() -> String:
	if SettingsManager == null:
		return "title"
	var raw := str(SettingsManager.get_setting(SETTINGS_GROUP_MODE_KEY, "title")).strip_edges()
	return raw if GROUP_MODES.has(raw) else "title"


func _persist_group_mode() -> void:
	if SettingsManager == null:
		return
	SettingsManager.set_setting(SETTINGS_GROUP_MODE_KEY, _group_mode)
	SettingsManager.save_settings()


static func _sanitize_display_text(text: String) -> String:
	if text.is_empty():
		return text
	var parts: PackedStringArray = []
	var i := 0
	while i < text.length():
		var cp := text.unicode_at(i)
		if cp >= 0xD800 and cp <= 0xDBFF:
			if i + 1 < text.length():
				var cp2 := text.unicode_at(i + 1)
				if cp2 >= 0xDC00 and cp2 <= 0xDFFF:
					parts.append(text.substr(i, 2))
					i += 2
					continue
			i += 1
			continue
		if cp >= 0xDC00 and cp <= 0xDFFF:
			i += 1
			continue
		parts.append(String.chr(cp))
		i += 1
	return "".join(parts)


func _on_search_changed(_text: String) -> void:
	if _rebuild_timer:
		_rebuild_timer.start(REBUILD_DEBOUNCE_SEC)
	else:
		_rebuild_list()


func _on_back_pressed() -> void:
	if transitions and transitions.has_method("close_track_picker_to_session_setup"):
		transitions.close_track_picker_to_session_setup(_selected_paths, false)
	else:
		_execute_close_transition()


func _on_done_pressed() -> void:
	if _selected_paths.size() < _EndlessSessionConfig.SELECTED_TRACK_PICKER_MIN:
		return
	if transitions and transitions.has_method("close_track_picker_to_session_setup"):
		transitions.close_track_picker_to_session_setup(_selected_paths, true)
	else:
		_execute_close_transition()


func _execute_close_transition() -> void:
	if transitions:
		transitions.close_track_picker_to_session_setup(_selected_paths, false)


func _unhandled_input(event: InputEvent) -> void:
	if _UiScreenHotkeys.try_handle(_hotkey_bindings(), event, get_viewport()):
		accept_event()
		return
	super._unhandled_input(event)


func _hotkey_bindings() -> Dictionary:
	return {
		KEY_ENTER: _on_done_pressed,
		KEY_KP_ENTER: _on_done_pressed,
	}
