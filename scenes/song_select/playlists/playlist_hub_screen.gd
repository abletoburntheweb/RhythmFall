# scenes/song_select/playlists/playlist_hub_screen.gd
extends BaseScreen

const _PlaylistCatalog = preload("res://logic/domain/library/playlist_catalog.gd")
const _PlaylistStats = preload("res://logic/domain/library/playlist_stats.gd")
const _SongSelectUiStyles = preload("res://scenes/song_select/lib/song_select_ui_styles.gd")
const _PlaylistUiHelpers = preload("res://scenes/song_select/playlists/playlist_ui_helpers.gd")

var _pick_for_run := false
var _browse_library := false
var _selected_playlist_id := ""

@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _list_scroll: ScrollContainer = %ListScroll
@onready var _list_vbox: VBoxContainer = %ListVBox
@onready var _empty_label: Label = %EmptyLabel
@onready var _create_button: Button = %CreateButton
@onready var _panel: PanelContainer = %HubPanel


func _ready() -> void:
	var game_engine := get_parent()
	if game_engine and game_engine.has_method("get_transitions"):
		setup_managers(game_engine.get_transitions())
	if _panel:
		_panel.add_theme_stylebox_override("panel", _SongSelectUiStyles.card_panel_style())
	if _back_button and not _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.connect(_on_back_pressed)
	if _create_button and not _create_button.pressed.is_connected(_on_create_pressed):
		_create_button.pressed.connect(_on_create_pressed)
	apply_locale()
	_rebuild_list()


func setup_hub(pick_for_run: bool, selected_playlist_id: String = "", browse_library: bool = false) -> void:
	_pick_for_run = pick_for_run
	_browse_library = browse_library
	_selected_playlist_id = str(selected_playlist_id).strip_edges()
	_rebuild_list()


func apply_locale() -> void:
	if _back_button:
		_back_button.text = tr("BTN_BACK")
	if _title_label:
		_title_label.text = tr("PLAYLIST_HUB_TITLE")
	if _subtitle_label:
		if _pick_for_run:
			_subtitle_label.text = tr("PLAYLIST_HUB_PICK_SUBTITLE")
		elif _browse_library:
			_subtitle_label.text = tr("PLAYLIST_HUB_BROWSE_SUBTITLE")
		else:
			_subtitle_label.text = tr("PLAYLIST_HUB_SUBTITLE")
	if _create_button:
		_create_button.text = tr("PLAYLIST_HUB_CREATE")
	if _empty_label:
		_empty_label.text = tr("PLAYLIST_HUB_EMPTY")
	_rebuild_list()


func _rebuild_list() -> void:
	if _list_vbox == null:
		return
	for child in _list_vbox.get_children():
		_list_vbox.remove_child(child)
		child.queue_free()
	var playlists: Array[Dictionary] = []
	if _browse_library or _pick_for_run:
		playlists = _PlaylistCatalog.all_playlists()
	else:
		playlists = _PlaylistCatalog.user_playlists_only()
	if _empty_label:
		_empty_label.visible = playlists.is_empty() and not _browse_library
	for entry in playlists:
		var pid := str(entry.get("id", "")).strip_edges()
		if pid == "":
			continue
		if not _browse_library and not _pick_for_run and bool(entry.get("builtin", false)):
			continue
		_list_vbox.add_child(_make_playlist_card(pid, bool(entry.get("builtin", false))))
	if not _pick_for_run and not _browse_library:
		_list_vbox.add_child(_make_favorites_hint_row())


func _make_favorites_hint_row() -> Label:
	var hint := Label.new()
	hint.text = tr("SESSION_SETUP_PLAYLIST_FAVORITES_HINT")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.58, 0.66, 0.78, 0.92))
	return hint


func _make_playlist_card(playlist_id: String, is_builtin: bool = false) -> PanelContainer:
	var stats := _PlaylistStats.compute_stats(playlist_id)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _SongSelectUiStyles.row_panel_style(false))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 4)
	row.add_child(text_col)
	var name_label := Label.new()
	name_label.text = _PlaylistCatalog.display_name(playlist_id)
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.82, 0.9, 0.98, 1.0))
	text_col.add_child(name_label)
	var stats_label := Label.new()
	stats_label.text = tr("PLAYLIST_HUB_CARD_STATS_FMT") % [
		int(stats.get("track_count", 0)),
		_PlaylistStats.format_duration(float(stats.get("duration_sec", 0.0))),
		_PlaylistStats.format_avg_rating(float(stats.get("avg_rating", 0.0))),
	]
	stats_label.add_theme_font_size_override("font_size", 13)
	stats_label.add_theme_color_override("font_color", Color(0.62, 0.7, 0.82, 0.95))
	text_col.add_child(stats_label)
	var tags: Array = stats.get("display_tags", [])
	if not tags.is_empty():
		var tag_row := HBoxContainer.new()
		tag_row.add_theme_constant_override("separation", 6)
		text_col.add_child(tag_row)
		_PlaylistUiHelpers.add_tags_to_row(tag_row, tags)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	row.add_child(actions)
	if _pick_for_run:
		var use_btn := Button.new()
		use_btn.text = tr("PLAYLIST_HUB_USE")
		use_btn.theme_type_variation = &"PrimaryButton"
		use_btn.custom_minimum_size = Vector2(120, 40)
		use_btn.pressed.connect(_on_use_pressed.bind(playlist_id))
		actions.add_child(use_btn)
	elif _browse_library:
		var browse_btn := Button.new()
		browse_btn.text = tr("PLAYLIST_HUB_BROWSE")
		browse_btn.theme_type_variation = &"PrimaryButton"
		browse_btn.custom_minimum_size = Vector2(120, 40)
		browse_btn.pressed.connect(_on_browse_pressed.bind(playlist_id))
		actions.add_child(browse_btn)
		if not is_builtin:
			var edit_btn := Button.new()
			edit_btn.text = tr("PLAYLIST_HUB_EDIT")
			edit_btn.theme_type_variation = &"FlatButton"
			edit_btn.custom_minimum_size = Vector2(100, 40)
			edit_btn.pressed.connect(_on_edit_pressed.bind(playlist_id))
			actions.add_child(edit_btn)
			var delete_btn := Button.new()
			delete_btn.text = tr("PLAYLIST_HUB_DELETE")
			delete_btn.theme_type_variation = &"FlatButton"
			delete_btn.custom_minimum_size = Vector2(100, 40)
			delete_btn.pressed.connect(_on_delete_pressed.bind(playlist_id))
			actions.add_child(delete_btn)
	else:
		var edit_btn := Button.new()
		edit_btn.text = tr("PLAYLIST_HUB_EDIT")
		edit_btn.theme_type_variation = &"FlatButton"
		edit_btn.custom_minimum_size = Vector2(100, 40)
		edit_btn.pressed.connect(_on_edit_pressed.bind(playlist_id))
		actions.add_child(edit_btn)
		var delete_btn := Button.new()
		delete_btn.text = tr("PLAYLIST_HUB_DELETE")
		delete_btn.theme_type_variation = &"FlatButton"
		delete_btn.custom_minimum_size = Vector2(100, 40)
		delete_btn.pressed.connect(_on_delete_pressed.bind(playlist_id))
		actions.add_child(delete_btn)
	var selected := false
	if _pick_for_run and playlist_id == _selected_playlist_id:
		selected = true
	elif _browse_library and playlist_id == _selected_playlist_id:
		selected = true
	if selected:
		panel.add_theme_stylebox_override("panel", _SongSelectUiStyles.row_panel_style(true))
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				if _pick_for_run:
					_on_use_pressed(playlist_id)
				elif _browse_library:
					_on_browse_pressed(playlist_id)
				else:
					_on_edit_pressed(playlist_id)
	)
	return panel


func _on_create_pressed() -> void:
	if MusicManager:
		MusicManager.play_modifier_select_sound()
	var new_id := _PlaylistCatalog.create_playlist(tr("PLAYLIST_DEFAULT_NAME"))
	if new_id == "":
		return
	if transitions and transitions.has_method("open_playlist_editor"):
		transitions.open_playlist_editor(new_id, true)


func _on_edit_pressed(playlist_id: String) -> void:
	if MusicManager:
		MusicManager.play_modifier_select_sound()
	if transitions and transitions.has_method("open_playlist_editor"):
		transitions.open_playlist_editor(playlist_id, false)


func _on_use_pressed(playlist_id: String) -> void:
	if MusicManager:
		MusicManager.play_modifier_select_sound()
	if transitions and transitions.has_method("close_playlist_hub_to_session_setup"):
		transitions.close_playlist_hub_to_session_setup(playlist_id, true)


func _on_browse_pressed(playlist_id: String) -> void:
	if MusicManager:
		MusicManager.play_modifier_select_sound()
	_selected_playlist_id = str(playlist_id).strip_edges()
	if transitions and transitions.has_method("close_playlist_hub_to_session_setup"):
		transitions.close_playlist_hub_to_session_setup(playlist_id, true)


func _on_delete_pressed(playlist_id: String) -> void:
	if MusicManager:
		MusicManager.play_modifier_deselect_sound()
	if _PlaylistCatalog.delete_playlist(playlist_id):
		if _selected_playlist_id == playlist_id:
			_selected_playlist_id = ""
		_rebuild_list()


func _on_back_pressed() -> void:
	if MusicManager:
		MusicManager.play_modifier_deselect_sound()
	if transitions and transitions.has_method("close_playlist_hub_to_session_setup"):
		transitions.close_playlist_hub_to_session_setup("", false)
