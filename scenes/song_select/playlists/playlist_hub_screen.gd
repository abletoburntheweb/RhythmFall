# scenes/song_select/playlists/playlist_hub_screen.gd
extends BaseScreen

const _PlaylistCatalog = preload("res://logic/domain/library/playlist_catalog.gd")
const _PlaylistStats = preload("res://logic/domain/library/playlist_stats.gd")
const _SongSelectUiStyles = preload("res://scenes/song_select/lib/song_select_ui_styles.gd")
const _PlaylistUiHelpers = preload("res://scenes/song_select/playlists/playlist_ui_helpers.gd")
const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")

var _pick_for_run := false
var _browse_library := false
var _selected_playlist_id := ""
var _card_panels: Array[PanelContainer] = []
var _card_playlist_ids: Array[String] = []
var _focus_index := -1
var _keyboard_nav_active := false

@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _list_scroll: ScrollContainer = %ListScroll
@onready var _list_vbox: VBoxContainer = %ListVBox
@onready var _empty_label: Label = %EmptyLabel
@onready var _create_button: Button = %CreateButton
@onready var _panel: PanelContainer = %HubPanel
@onready var _footer_label: Label = %FooterHintLabel


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
	_ensure_modal_dim()
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
		_UiIconHelper.apply_standard_back_button(_back_button)
	if _title_label:
		_title_label.text = tr("PLAYLIST_HUB_TITLE")
	if _subtitle_label:
		if _pick_for_run:
			_subtitle_label.text = tr("PLAYLIST_HUB_PICK_SUBTITLE")
		elif _browse_library:
			_subtitle_label.text = tr("PLAYLIST_HUB_BROWSE_SUBTITLE")
		else:
			_subtitle_label.text = tr("PLAYLIST_HUB_SUBTITLE")
	if _footer_label:
		_footer_label.text = tr("PLAYLIST_HUB_FOOTER_HINT")
	if _create_button:
		_create_button.text = tr("PLAYLIST_HUB_CREATE")
		_create_button.tooltip_text = tr("PLAYLIST_HUB_FOOTER_HINT")
	if _empty_label:
		_empty_label.text = tr("PLAYLIST_HUB_EMPTY")
	_rebuild_list()


func _rebuild_list() -> void:
	if _list_vbox == null:
		return
	for child in _list_vbox.get_children():
		_list_vbox.remove_child(child)
		child.queue_free()
	_card_panels.clear()
	_card_playlist_ids.clear()
	_focus_index = -1
	_keyboard_nav_active = false
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
		var card := _make_playlist_card(pid, bool(entry.get("builtin", false)))
		_list_vbox.add_child(card)
		_card_panels.append(card)
		_card_playlist_ids.append(pid)
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
	panel.custom_minimum_size = Vector2(0, 108)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)

	row.add_child(_PlaylistUiHelpers.make_cover_mosaic(stats.get("cover_paths", [])))

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 5)
	row.add_child(text_col)
	var name_label := Label.new()
	name_label.text = _PlaylistCatalog.display_name(playlist_id)
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(0.92, 0.95, 0.99, 1.0))
	text_col.add_child(name_label)
	var stats_label := Label.new()
	var coverage_total := int(stats.get("coverage_total", stats.get("unique_track_count", 0)))
	var charts_total := int(stats.get("charts_total", coverage_total))
	stats_label.text = tr("PLAYLIST_HUB_CARD_STATS_FMT") % [
		int(stats.get("track_count", 0)),
		_PlaylistStats.format_duration(float(stats.get("duration_sec", 0.0))),
		int(stats.get("coverage_cleared", 0)),
		coverage_total,
		int(stats.get("charts_ready", 0)),
		charts_total,
	]
	stats_label.tooltip_text = tr("PLAYLIST_HUB_CARD_STATS_TIP")
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.add_theme_color_override("font_color", Color(0.62, 0.7, 0.82, 0.95))
	text_col.add_child(stats_label)
	var tags: Array = stats.get("display_tags", [])
	if not tags.is_empty():
		var tag_row := HBoxContainer.new()
		tag_row.add_theme_constant_override("separation", 6)
		text_col.add_child(tag_row)
		_PlaylistUiHelpers.add_tags_to_row(tag_row, tags)

	var meta_col := VBoxContainer.new()
	meta_col.add_theme_constant_override("separation", 8)
	meta_col.custom_minimum_size = Vector2(158, 0)
	meta_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(meta_col)
	meta_col.add_child(_PlaylistUiHelpers.make_meta_line(
		"clock.svg",
		tr("PLAYLIST_HUB_LAST_LAUNCH"),
		_PlaylistUiHelpers.format_last_played(str(stats.get("last_played", ""))),
		Color(0.62, 0.78, 0.95, 1.0)
	))
	# activity.svg is optically centered; chart-column sits left in its viewBox and looks shifted.
	var runs_line := _PlaylistUiHelpers.make_meta_line(
		"activity.svg",
		tr("PLAYLIST_HUB_PLAY_COUNT_CAPTION"),
		str(int(stats.get("play_count", 0))),
		Color(0.55, 0.82, 0.98, 1.0)
	)
	runs_line.tooltip_text = tr("PLAYLIST_HUB_PLAY_COUNT_TIP")
	meta_col.add_child(runs_line)
	var session_line := _PlaylistUiHelpers.make_meta_line(
		"trophy.svg",
		tr("PLAYLIST_HUB_SESSION_CLEARS_CAPTION"),
		str(int(stats.get("session_clears", 0))),
		Color(0.62, 0.86, 0.72, 1.0)
	)
	session_line.tooltip_text = tr("PLAYLIST_HUB_SESSION_CLEARS_TIP")
	meta_col.add_child(session_line)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.custom_minimum_size = Vector2(172, 0)
	row.add_child(actions)
	if _pick_for_run:
		var use_btn := Button.new()
		use_btn.text = tr("PLAYLIST_HUB_USE")
		use_btn.theme_type_variation = &"PrimaryButton"
		use_btn.custom_minimum_size = Vector2(120, 44)
		use_btn.pressed.connect(_on_use_pressed.bind(playlist_id))
		actions.add_child(use_btn)
	elif _browse_library:
		var browse_btn := Button.new()
		browse_btn.text = tr("PLAYLIST_HUB_BROWSE")
		browse_btn.theme_type_variation = &"PrimaryButton"
		browse_btn.custom_minimum_size = Vector2(120, 44)
		browse_btn.pressed.connect(_on_browse_pressed.bind(playlist_id))
		actions.add_child(browse_btn)
		if not is_builtin:
			actions.add_child(_make_more_menu(playlist_id))
		else:
			# Keep Open aligned with cards that have ⋯.
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(44, 44)
			actions.add_child(spacer)
	else:
		var edit_btn := Button.new()
		edit_btn.text = tr("PLAYLIST_HUB_EDIT")
		edit_btn.theme_type_variation = &"PrimaryButton"
		edit_btn.custom_minimum_size = Vector2(120, 44)
		edit_btn.pressed.connect(_on_edit_pressed.bind(playlist_id))
		actions.add_child(edit_btn)
		actions.add_child(_make_more_menu(playlist_id, false))

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


func _make_more_menu(playlist_id: String, include_edit: bool = true) -> ActionPopupMenu:
	var more := ActionPopupMenu.new()
	more.set_menu_tooltip(tr("PLAYLIST_HUB_MORE"))
	more.custom_minimum_size = Vector2(44, 44)
	var items: Array = []
	if include_edit:
		items.append({"id": 0, "label": tr("PLAYLIST_HUB_EDIT")})
	items.append({"id": 1, "label": tr("PLAYLIST_HUB_DELETE")})
	more.setup_items(items)
	more.action_id_pressed.connect(func(id: int) -> void:
		if id == 0 and include_edit:
			_on_edit_pressed(playlist_id)
		elif id == 1:
			_on_delete_pressed(playlist_id)
	)
	return more


func _on_create_pressed() -> void:
	var new_id := _PlaylistCatalog.create_playlist(tr("PLAYLIST_DEFAULT_NAME"))
	if new_id == "":
		return
	if transitions and transitions.has_method("open_playlist_editor"):
		transitions.open_playlist_editor(new_id, true)


func _on_edit_pressed(playlist_id: String) -> void:
	if transitions and transitions.has_method("open_playlist_editor"):
		transitions.open_playlist_editor(playlist_id, false)


func _on_use_pressed(playlist_id: String) -> void:
	if transitions and transitions.has_method("close_playlist_hub_to_session_setup"):
		transitions.close_playlist_hub_to_session_setup(playlist_id, true)


func _on_browse_pressed(playlist_id: String) -> void:
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


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_clear_keyboard_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		accept_event()
		_on_back_pressed()
		return
	if not (event is InputEventKey) or not event.pressed:
		return
	var key_event := event as InputEventKey
	var is_list_nav := key_event.keycode == KEY_UP or key_event.keycode == KEY_DOWN
	if key_event.echo and not is_list_nav:
		return
	if UiScreenHotkeys.should_block_hotkeys(get_viewport()):
		return
	if key_event.keycode == KEY_N and not key_event.echo:
		if _create_button and _create_button.visible and not _create_button.disabled:
			_on_create_pressed()
			get_viewport().set_input_as_handled()
		return
	if key_event.keycode == KEY_UP:
		_move_focus(-1)
		get_viewport().set_input_as_handled()
		return
	if key_event.keycode == KEY_DOWN:
		_move_focus(1)
		get_viewport().set_input_as_handled()
		return
	if (key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER) and not key_event.echo:
		_activate_focused_card()
		get_viewport().set_input_as_handled()


func _clear_keyboard_focus() -> void:
	if not _keyboard_nav_active and _focus_index < 0:
		return
	_keyboard_nav_active = false
	_focus_index = -1
	_refresh_card_styles()


func _move_focus(delta: int) -> void:
	if _card_panels.is_empty():
		return
	_keyboard_nav_active = true
	var next := _focus_index
	if next < 0:
		next = 0 if delta > 0 else _card_panels.size() - 1
	else:
		next = clampi(next + delta, 0, _card_panels.size() - 1)
	_set_focus_index(next, true)


func _set_focus_index(index: int, play_sound: bool) -> void:
	if index < 0 or index >= _card_panels.size():
		return
	if play_sound and index != _focus_index:
		UiScreenHotkeys.play_section_switch_sound()
	_focus_index = index
	_keyboard_nav_active = true
	_refresh_card_styles()
	var focused := _card_panels[_focus_index]
	if focused and _list_scroll:
		_list_scroll.ensure_control_visible(focused)


func _refresh_card_styles() -> void:
	for i in range(_card_panels.size()):
		var panel := _card_panels[i]
		if panel == null or not is_instance_valid(panel):
			continue
		var selected := _keyboard_nav_active and i == _focus_index
		var pid := _card_playlist_ids[i] if i < _card_playlist_ids.size() else ""
		var pinned := (
			(_pick_for_run or _browse_library)
			and pid != ""
			and pid == _selected_playlist_id
		)
		panel.add_theme_stylebox_override(
			"panel",
			_SongSelectUiStyles.row_panel_style(selected or pinned)
		)


func _activate_focused_card() -> void:
	if _card_panels.is_empty():
		return
	if _focus_index < 0 or _focus_index >= _card_playlist_ids.size():
		_move_focus(1)
	if _focus_index < 0 or _focus_index >= _card_playlist_ids.size():
		return
	var playlist_id := _card_playlist_ids[_focus_index]
	if playlist_id == "":
		return
	if _pick_for_run:
		_on_use_pressed(playlist_id)
	elif _browse_library:
		_on_browse_pressed(playlist_id)
	else:
		_on_edit_pressed(playlist_id)


func _on_back_pressed() -> void:
	if transitions and transitions.has_method("close_playlist_hub_to_session_setup"):
		transitions.close_playlist_hub_to_session_setup("", false)
