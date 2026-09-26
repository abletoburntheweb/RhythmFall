# scenes/song_select/playlists/playlist_hub_screen.gd
extends BaseScreen

const _PlaylistCatalog = preload("res://logic/domain/library/playlist_catalog.gd")
const _PlaylistStats = preload("res://logic/domain/library/playlist_stats.gd")
const _SongSelectUiStyles = preload("res://scenes/song_select/lib/song_select_ui_styles.gd")
const _PlaylistUiHelpers = preload("res://scenes/song_select/playlists/playlist_ui_helpers.gd")
const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")
const _Overlay = preload("res://logic/ui/app_overlay_helpers.gd")
const _ConfirmOverlayScene = preload("res://ui/overlays/app_confirm_overlay.tscn")
const _HelpSectionUi = preload("res://logic/ui/settings_section_ui.gd")

var _pick_for_run := false
var _browse_library := false
var _selected_playlist_id := ""
var _card_panels: Array[PanelContainer] = []
var _card_playlist_ids: Array[String] = []
var _focus_index := -1
var _keyboard_nav_active := false
var _confirm_overlay: AppConfirmOverlay = null
var _rebuild_token: int = 0
const REBUILD_BATCH_SIZE := 4
var _stats_cache: Dictionary = {}
var _cover_queue: Array[Dictionary] = []
var _cover_pump_running: bool = false
const COVER_PER_FRAME := 3

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
	_ensure_confirm_overlay()
	_ensure_help_button()
	apply_locale()
	_rebuild_list()


func _ensure_confirm_overlay() -> void:
	if _confirm_overlay != null and is_instance_valid(_confirm_overlay):
		return
	var existing := get_node_or_null("%ConfirmOverlay") as AppConfirmOverlay
	if existing != null:
		_confirm_overlay = existing
		return
	if _ConfirmOverlayScene != null and _ConfirmOverlayScene is PackedScene:
		var inst := (_ConfirmOverlayScene as PackedScene).instantiate() as AppConfirmOverlay
		if inst != null:
			add_child(inst)
			_confirm_overlay = inst


func _ensure_help_button() -> void:
	if _title_label == null or not is_instance_valid(_title_label):
		return
	if _title_label.has_meta("help_icon_btn"):
		var existing_meta: Variant = _title_label.get_meta("help_icon_btn")
		if existing_meta is Button and is_instance_valid(existing_meta):
			(existing_meta as Button).tooltip_text = tr("HELP_LINK_LIBRARY_OVERVIEW")
			(existing_meta as Button).visible = true
			return
	var parent := _title_label.get_parent()
	if parent == null:
		return
	var existing_btn := parent.get_node_or_null("HelpButton") as Button
	if existing_btn != null and is_instance_valid(existing_btn):
		existing_btn.tooltip_text = tr("HELP_LINK_LIBRARY_OVERVIEW")
		existing_btn.visible = true
		return
	var row_existing := parent.get_node_or_null("TitleHelpRow") as HBoxContainer
	if row_existing != null:
		var btn_in_row := row_existing.get_node_or_null("HelpButton") as Button
		if btn_in_row != null and is_instance_valid(btn_in_row):
			btn_in_row.tooltip_text = tr("HELP_LINK_LIBRARY_OVERVIEW")
			btn_in_row.visible = true
			return
	var legacy_row := parent.get_node_or_null("TitleLabelHelpRow") as HBoxContainer
	if legacy_row != null:
		var btn_legacy := legacy_row.get_node_or_null("HelpButton") as Button
		if btn_legacy != null and is_instance_valid(btn_legacy):
			btn_legacy.tooltip_text = tr("HELP_LINK_LIBRARY_OVERVIEW")
			return
	var btn := _HelpSectionUi.attach_help_icon_beside_label(
		_title_label,
		tr("HELP_LINK_LIBRARY_OVERVIEW"),
		_on_help_pressed,
		true
	)
	if btn and is_instance_valid(btn):
		btn.name = "HelpButton"
		btn.visible = true


func _on_help_pressed() -> void:
	var n: Node = self
	while n:
		if n.has_method("open_help_item"):
			n.open_help_item("library_overview")
			return
		if n.has_method("get_transitions"):
			var t = n.get_transitions()
			if t and t.has_method("open_help_item"):
				t.open_help_item("library_overview")
				return
		n = n.get_parent()
	var trans := get_tree().root.get_node_or_null("GameEngine") as Node
	if trans and trans.has_method("get_transitions"):
		var t2 = trans.get_transitions()
		if t2 and t2.has_method("open_help_item"):
			t2.open_help_item("library_overview")


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
	_ensure_help_button()
	_rebuild_list()


func _rebuild_list() -> void:
	_rebuild_token += 1
	var token := _rebuild_token
	_cover_queue.clear()
	_cover_pump_running = false
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
	# Filter to actual display list first (light)
	var display_pids: Array[String] = []
	for entry in playlists:
		var pid := str(entry.get("id", "")).strip_edges()
		if pid == "":
			continue
		if not _browse_library and not _pick_for_run and bool(entry.get("builtin", false)):
			continue
		display_pids.append(pid)
	# Create cards in batches
	var batch_count := 0
	for pid in display_pids:
		if token != _rebuild_token or not is_inside_tree():
			return
		var is_builtin := false
		for e in playlists:
			if str(e.get("id", "")) == pid:
				is_builtin = bool(e.get("builtin", false))
				break
		var card := _make_playlist_card(pid, is_builtin)
		_list_vbox.add_child(card)
		_card_panels.append(card)
		_card_playlist_ids.append(pid)
		batch_count += 1
		if batch_count % REBUILD_BATCH_SIZE == 0:
			await get_tree().process_frame
			if token != _rebuild_token or not is_inside_tree():
				return
	if not _pick_for_run and not _browse_library:
		_list_vbox.add_child(_make_favorites_hint_row())
	# Sync styles/arrows after all cards exist — fixes lifecycle where _make_playlist_card called before append.
	_refresh_card_styles()


func _make_favorites_hint_row() -> Label:
	var hint := Label.new()
	hint.text = tr("SESSION_SETUP_PLAYLIST_FAVORITES_HINT")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.58, 0.66, 0.78, 0.92))
	return hint


func _make_playlist_card(playlist_id: String, is_builtin: bool = false) -> PanelContainer:
	var stats: Dictionary
	if _stats_cache.has(playlist_id):
		stats = _stats_cache[playlist_id] as Dictionary
	else:
		stats = _PlaylistStats.compute_stats(playlist_id)
		_stats_cache[playlist_id] = stats.duplicate(true)
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
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	row.add_child(_make_cover_mosaic_deferred(stats.get("cover_paths", []), playlist_id))

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
	var track_count := int(stats.get("track_count", 0))
	stats_label.text = tr("PLAYLIST_HUB_CARD_STATS_FMT") % [
		track_count,
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
	if track_count == 0:
		var empty_hint := Label.new()
		var hint_txt := tr("PLAYLIST_CARD_EMPTY_HINT")
		if hint_txt == "PLAYLIST_CARD_EMPTY_HINT" or hint_txt.strip_edges() == "":
			hint_txt = "Empty — add tracks to use in Endless"
		empty_hint.text = hint_txt
		empty_hint.add_theme_font_size_override("font_size", 12)
		empty_hint.add_theme_color_override("font_color", Color(0.95, 0.6, 0.55, 1.0))
		empty_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_col.add_child(empty_hint)
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

	# Reorder arrows — tiny spinbox ⌃/⌄ via chevron icons, always visible, never expands card Y.
	var arrows_col := VBoxContainer.new()
	arrows_col.name = "ReorderArrows"
	arrows_col.add_theme_constant_override("separation", 0)
	arrows_col.custom_minimum_size = Vector2(16, 26)
	arrows_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arrows_col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	arrows_col.alignment = BoxContainer.ALIGNMENT_CENTER
	arrows_col.visible = true
	row.add_child(arrows_col)
	var _spin_empty := StyleBoxEmpty.new()
	var up_btn := Button.new()
	up_btn.name = "UpArrow"
	up_btn.text = ""
	up_btn.custom_minimum_size = Vector2(16, 13)
	up_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	up_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	up_btn.flat = true
	up_btn.focus_mode = Control.FOCUS_NONE
	up_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	for _s in ["normal", "hover", "pressed", "disabled", "focus"]:
		up_btn.add_theme_stylebox_override(_s, _spin_empty)
	# Use chevron icon (⌃-like) — glyph «⌃» missing in game font, icon is guaranteed visible.
	_UiIconHelper.apply_button_icon(up_btn, "chevron-up.svg", Color(0.78, 0.84, 0.92, 0.82), 12)
	up_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	up_btn.add_theme_constant_override("icon_max_width", 12)
	up_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var up_label := tr("PLAYLIST_MOVE_UP")
	if up_label == "PLAYLIST_MOVE_UP" or up_label.strip_edges() == "":
		up_label = "Move up"
	up_btn.tooltip_text = up_label
	up_btn.pressed.connect(_on_move_pressed.bind(playlist_id, -1))
	arrows_col.add_child(up_btn)
	var down_btn := Button.new()
	down_btn.name = "DownArrow"
	down_btn.text = ""
	down_btn.custom_minimum_size = Vector2(16, 13)
	down_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	down_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	down_btn.flat = true
	down_btn.focus_mode = Control.FOCUS_NONE
	down_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	for _s2 in ["normal", "hover", "pressed", "disabled", "focus"]:
		down_btn.add_theme_stylebox_override(_s2, _spin_empty)
	_UiIconHelper.apply_button_icon(down_btn, "chevron-down.svg", Color(0.78, 0.84, 0.92, 0.82), 12)
	down_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	down_btn.add_theme_constant_override("icon_max_width", 12)
	down_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var down_label := tr("PLAYLIST_MOVE_DOWN")
	if down_label == "PLAYLIST_MOVE_DOWN" or down_label.strip_edges() == "":
		down_label = "Move down"
	down_btn.tooltip_text = down_label
	down_btn.pressed.connect(_on_move_pressed.bind(playlist_id, 1))
	arrows_col.add_child(down_btn)
	# Initial disabled at bounds; pointer via existing CURSOR_POINTING_HAND mechanism.
	var _is_user := _PlaylistCatalog.is_user_playlist(playlist_id)
	if not _is_user:
		up_btn.disabled = true
		down_btn.disabled = true
		arrows_col.modulate = Color(1, 1, 1, 0.55)
		up_btn.mouse_default_cursor_shape = Control.CURSOR_ARROW
		down_btn.mouse_default_cursor_shape = Control.CURSOR_ARROW
	else:
		var _user_lists := _PlaylistCatalog.user_playlists_only()
		var _idx := -1
		for i in range(_user_lists.size()):
			if str(_user_lists[i].get("id", "")) == playlist_id:
				_idx = i
				break
		up_btn.disabled = _idx <= 0
		down_btn.disabled = _idx < 0 or _idx >= _user_lists.size() - 1
		arrows_col.modulate = Color.WHITE
		up_btn.mouse_default_cursor_shape = Control.CURSOR_ARROW if up_btn.disabled else Control.CURSOR_POINTING_HAND
		down_btn.mouse_default_cursor_shape = Control.CURSOR_ARROW if down_btn.disabled else Control.CURSOR_POINTING_HAND
	panel.set_meta("reorder_arrows", arrows_col)
	panel.set_meta("reorder_up", up_btn)
	panel.set_meta("reorder_down", down_btn)
	panel.set_meta("playlist_id", playlist_id)

	var selected := false
	if _pick_for_run and playlist_id == _selected_playlist_id:
		selected = true
	elif _browse_library and playlist_id == _selected_playlist_id:
		selected = true
	if selected:
		panel.add_theme_stylebox_override("panel", _SongSelectUiStyles.row_panel_style(true))
	# R1 fix: arrows visible for all user playlists immediately (not only selected).
	arrows_col.visible = _is_user
	# Do not call _update here — panel not yet in _card_panels; _refresh after rebuild will sync via _update.
	UiClick.connect_clicked(panel, func() -> void:
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
	# Duplicate
	var dup_label := tr("PLAYLIST_DUPLICATE")
	if dup_label == "PLAYLIST_DUPLICATE" or dup_label.strip_edges() == "":
		dup_label = "Duplicate"
	items.append({"id": 2, "label": dup_label})
	items.append({"id": 1, "label": tr("PLAYLIST_HUB_DELETE")})
	more.setup_items(items)
	more.action_id_pressed.connect(func(id: int) -> void:
		if id == 0 and include_edit:
			_on_edit_pressed(playlist_id)
		elif id == 1:
			_on_delete_pressed(playlist_id)
		elif id == 2:
			_on_duplicate_pressed(playlist_id)
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
	_ensure_confirm_overlay()
	var display_name := _PlaylistCatalog.display_name(playlist_id)
	var title := tr("PLAYLIST_DELETE_CONFIRM_TITLE")
	if title == "PLAYLIST_DELETE_CONFIRM_TITLE" or title.strip_edges() == "":
		title = tr("PLAYLIST_HUB_DELETE")
	var msg := tr("PLAYLIST_DELETE_CONFIRM")
	if msg == "PLAYLIST_DELETE_CONFIRM" or msg.strip_edges() == "":
		msg = "Delete this playlist?"
	# Include playlist name in message for clarity
	if display_name != "" and display_name != playlist_id:
		msg = "%s\n\n%s" % [msg, display_name]
	var variant := "danger"
	if _confirm_overlay != null:
		_ensure_confirm_overlay()
		var confirmed: bool = await _Overlay.ask(_confirm_overlay, msg, variant, title)
		if not confirmed:
			if MusicManager:
				MusicManager.play_modifier_deselect_sound()
			return
	if MusicManager:
		MusicManager.play_modifier_deselect_sound()
	if _PlaylistCatalog.delete_playlist(playlist_id):
		_stats_cache.erase(playlist_id)
		if _selected_playlist_id == playlist_id:
			_selected_playlist_id = ""
		await _rebuild_list()


func _on_duplicate_pressed(playlist_id: String) -> void:
	var new_id := _PlaylistCatalog.duplicate_playlist(playlist_id)
	if new_id != "":
		if MusicManager:
			MusicManager.play_modifier_select_sound()
		await _rebuild_list()
		# Focus new playlist
		for i in range(_card_playlist_ids.size()):
			if _card_playlist_ids[i] == new_id:
				_set_focus_index(i, false)
				break


func _on_move_pressed(playlist_id: String, delta: int) -> void:
	if not _PlaylistCatalog.move_playlist(playlist_id, delta):
		return
	if MusicManager:
		MusicManager.play_modifier_select_sound()
	# Incremental reorder: move existing Control nodes, no stats/cover recompute.
	var old_idx := -1
	for i in range(_card_playlist_ids.size()):
		if _card_playlist_ids[i] == playlist_id:
			old_idx = i
			break
	if old_idx < 0:
		await _rebuild_list()
		return
	var new_idx := clampi(old_idx + delta, 0, _card_playlist_ids.size() - 1)
	if new_idx == old_idx:
		return
	# Move data in parallel arrays
	var panel: PanelContainer = _card_panels[old_idx]
	_card_panels.remove_at(old_idx)
	_card_panels.insert(new_idx, panel)
	_card_playlist_ids.remove_at(old_idx)
	_card_playlist_ids.insert(new_idx, playlist_id)
	# Move node in ListVBox (exclude favorites hint row at end)
	if _list_vbox and is_instance_valid(panel):
		_list_vbox.move_child(panel, new_idx)
		# _list_vbox has an extra hint row at end when not pick/browse; move_child index must account for it
		# Our _card_panels order now matches display_pids order, and hint row stays last, so direct move is correct.
	_set_focus_index(new_idx, false)
	if _list_scroll and is_instance_valid(panel):
		_list_scroll.ensure_control_visible(panel)


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
	if key_event.shift_pressed and (key_event.keycode == KEY_UP or key_event.keycode == KEY_DOWN):
		if _focus_index >= 0 and _focus_index < _card_playlist_ids.size():
			var pid := _card_playlist_ids[_focus_index]
			var delta := -1 if key_event.keycode == KEY_UP else 1
			_on_move_pressed(pid, delta)
			get_viewport().set_input_as_handled()
			return
		elif _card_playlist_ids.size() > 0:
			# If no focus, focus first and try move
			_move_focus(0)
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
		_update_reorder_arrows_for_panel(panel, selected or pinned)


func _playlist_reorder_index(playlist_id: String) -> int:
	if not _PlaylistCatalog.is_user_playlist(playlist_id):
		return -1
	var user_lists := _PlaylistCatalog.user_playlists_only()
	for i in range(user_lists.size()):
		if str(user_lists[i].get("id", "")) == playlist_id:
			return i
	return -1


func _update_reorder_arrows_for_panel(panel: PanelContainer, _is_selected: bool) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var arrows: VBoxContainer = panel.get_meta("reorder_arrows") as VBoxContainer if panel.has_meta("reorder_arrows") else null
	var up_btn: Button = panel.get_meta("reorder_up") as Button if panel.has_meta("reorder_up") else null
	var down_btn: Button = panel.get_meta("reorder_down") as Button if panel.has_meta("reorder_down") else null
	if arrows == null or up_btn == null or down_btn == null:
		return
	var pid := ""
	if panel.has_meta("playlist_id"):
		pid = str(panel.get_meta("playlist_id")).strip_edges()
	if pid == "":
		# Fallback: find via _card_panels index (for legacy or after reorder).
		for i in range(_card_panels.size()):
			if _card_panels[i] == panel and i < _card_playlist_ids.size():
				pid = _card_playlist_ids[i]
				break
	if pid == "":
		arrows.visible = true
		up_btn.disabled = true
		down_btn.disabled = true
		up_btn.modulate = Color(1, 1, 1, 0.35)
		down_btn.modulate = Color(1, 1, 1, 0.35)
		return
	var is_user := _PlaylistCatalog.is_user_playlist(pid)
	# R1 fix: arrows visible for all user playlists; builtin hidden.
	if not is_user:
		arrows.visible = false
		up_btn.disabled = true
		down_btn.disabled = true
		return
	# R1 fix: always visible for user playlists, disabled by bounds.
	arrows.visible = true
	arrows.modulate = Color.WHITE
	var idx := _playlist_reorder_index(pid)
	var total := _PlaylistCatalog.user_playlists_only().size()
	up_btn.disabled = idx <= 0
	down_btn.disabled = idx < 0 or idx >= total - 1
	up_btn.modulate = Color(1, 1, 1, 0.35) if up_btn.disabled else Color.WHITE
	down_btn.modulate = Color(1, 1, 1, 0.35) if down_btn.disabled else Color.WHITE
	up_btn.mouse_default_cursor_shape = Control.CURSOR_ARROW if up_btn.disabled else Control.CURSOR_POINTING_HAND
	down_btn.mouse_default_cursor_shape = Control.CURSOR_ARROW if down_btn.disabled else Control.CURSOR_POINTING_HAND


func _make_cover_mosaic_deferred(cover_paths: Array, playlist_id: String = "") -> PanelContainer:
	var outer := PanelContainer.new()
	outer.custom_minimum_size = Vector2(88, 88)
	outer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.06, 0.09, 1.0)
	box.set_corner_radius_all(10)
	box.set_border_width_all(1)
	box.border_color = Color(1, 1, 1, 0.08)
	box.content_margin_left = 2
	box.content_margin_right = 2
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	outer.add_theme_stylebox_override("panel", box)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	outer.add_child(grid)
	for i in 4:
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(42, 42)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cell_box := StyleBoxFlat.new()
		cell_box.bg_color = Color(0.12, 0.14, 0.18, 1.0)
		cell_box.set_corner_radius_all(4)
		cell.add_theme_stylebox_override("panel", cell_box)
		var cover := TextureRect.new()
		cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		cover.custom_minimum_size = Vector2(42, 42)
		cell.add_child(cover)
		grid.add_child(cell)
		if i < cover_paths.size():
			var path := str(cover_paths[i]).strip_edges()
			if path != "":
				_cover_queue.append({"cover": cover, "path": path, "token": _rebuild_token, "pid": playlist_id})
	if not _cover_queue.is_empty() and not _cover_pump_running:
		_cover_pump_running = true
		call_deferred("_cover_pump_step")
	return outer


func _resolve_canonical_song_path(path: String) -> String:
	var p := str(path).strip_edges().replace("\\", "/")
	if p == "":
		return p
	if SongLibrary == null or not SongLibrary.has_method("get_metadata_for_song") or not SongLibrary.has_method("get_songs_list"):
		return p
	var meta: Dictionary = SongLibrary.get_metadata_for_song(p)
	if not meta.is_empty():
		return p
	var fname := p.get_file().to_lower()
	if fname == "":
		return p
	for s in SongLibrary.get_songs_list():
		var cand := str(s.get("path", "")).strip_edges()
		if cand == "":
			continue
		if cand.get_file().to_lower() == fname:
			return cand
	return p


func _cover_pump_step() -> void:
	if not is_inside_tree():
		_cover_pump_running = false
		return
	if _cover_queue.is_empty():
		_cover_pump_running = false
		return
	var token := _rebuild_token
	var batch := mini(COVER_PER_FRAME, _cover_queue.size())
	for _i in range(batch):
		if _cover_queue.is_empty():
			break
		var job: Dictionary = _cover_queue.pop_front()
		if int(job.get("token", -1)) != token:
			continue
		var cover: TextureRect = job.get("cover") as TextureRect
		var raw_path := str(job.get("path", ""))
		if not is_instance_valid(cover) or raw_path == "":
			continue
		var path := _resolve_canonical_song_path(raw_path)
		# Use canonical cover loader with fallback chain
		_SongSelectUiStyles.apply_row_cover_texture(cover, path, 42)
		# Diagnostic for fallback: log when cover remains null (after canonical resolve)
		if cover.texture == null:
			var sidecar := path.get_basename() + ".jpg"
			var has_sidecar := FileAccess.file_exists(sidecar)
			var has_sidecar2 := FileAccess.file_exists(path.get_basename() + ".png")
			var meta_empty := false
			if SongLibrary != null and SongLibrary.has_method("get_metadata_for_song"):
				var meta: Dictionary = SongLibrary.get_metadata_for_song(path)
				meta_empty = meta.is_empty()
			print_verbose("[CoverFallback] pid=%s raw=%s canonical=%s sidecar.jpg=%s png=%s meta_empty=%s" % [
				str(job.get("pid", "")),
				raw_path,
				path,
				has_sidecar,
				has_sidecar2,
				meta_empty
			])
		# Note: apply_row_cover_texture is synchronous, but batched 3 per frame spreads load
	if _cover_queue.is_empty():
		_cover_pump_running = false
	else:
		call_deferred("_cover_pump_step")


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
	# Library → Playlist Hub → Back/Esc must be equivalent to "Show all tracks": clear browse filter and show all.
	if _browse_library and transitions and transitions.has_method("set_song_select_browse_playlist"):
		transitions.set_song_select_browse_playlist("")
	if transitions and transitions.has_method("close_playlist_hub_to_session_setup"):
		transitions.close_playlist_hub_to_session_setup("", false)
