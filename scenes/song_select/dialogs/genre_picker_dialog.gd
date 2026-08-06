# scenes/song_select/dialogs/genre_picker_dialog.gd
extends Control
class_name GenrePickerDialog

const GenreSearch = preload("res://logic/domain/library/genre_search.gd")
const GenreGroupIcons = preload("res://logic/domain/library/genre_group_icons.gd")
const GenrePortraitRowsUi = preload("res://logic/domain/profile/genre_portrait_rows_ui.gd")
const GenerationApiClient = preload("res://server/generation_api_client.gd")
const _UiMotionEffects = preload("res://logic/ui/ui_motion_effects.gd")

signal genre_selected(primary_genre: String, all_genres: Array, from_server: bool)

@export var allow_multi: bool = false
@export var auto_close: bool = false

const PREDICTION_TOP_K := 5

var _search: LineEdit = null
var _list: ItemList = null
var _all: Array = []
var _filtered: Array = []
var _grouped_data = []
var _genre_nav_index: int = -1

var _song_path: String = ""
var _predictions: Array = []
var _pending_primary: String = "unknown"
var _pending_all: Array = []
var _api_client: GenerationApiClient = null
var _analyzing: bool = false
var _predictions_from_cache: bool = false

var _suggestions_vbox: VBoxContainer = null
var _selected_genre_label: Label = null
var _icon_slot: HBoxContainer = null
var _server_status_label: Label = null
var _refresh_button: Button = null
var _confirm_button: Button = null
var _card_panel: PanelContainer = null
var _selected_panel: PanelContainer = null

const _BODY := "Container/BodyCenter/CardPanel/CardMargin/BodyHBox"
const _LEFT := _BODY + "/LeftVBox"
const _RIGHT := _BODY + "/RightVBox"
const _SEARCH_PATH := _RIGHT + "/SearchRow/SearchLineEdit"
const _LIST_PATH := _RIGHT + "/GenreList"
const _SUGGESTIONS_PATH := _LEFT + "/ServerPanel/ServerVBox/SuggestionsScroll/SuggestionsVBox"

const _GROUP_HEADER_BG := Color(0.2, 0.2, 0.2, 1.0)

const _PILL_BG := Color(0.07, 0.085, 0.12, 0.96)
const _PILL_BORDER := Color(1.0, 1.0, 1.0, 0.1)
const _SELECT_ACCENT := Color(0.38, 0.78, 0.74, 1.0)


func _ready():
	var overlay_layer := 110 if get_parent() is MetadataEditDialog else 100
	UiIconHelper.configure_modal_overlay(self, overlay_layer)
	_search = get_node_or_null(_SEARCH_PATH)
	_list = get_node_or_null(_LIST_PATH) as ItemList
	_suggestions_vbox = get_node_or_null(_SUGGESTIONS_PATH) as VBoxContainer
	_selected_genre_label = get_node_or_null(_LEFT + "/SelectedPanel/SelectedVBox/SelectedGenreRow/SelectedGenreLabel") as Label
	_icon_slot = get_node_or_null(_LEFT + "/SelectedPanel/SelectedVBox/SelectedGenreRow/IconSlot") as HBoxContainer
	_selected_panel = get_node_or_null(_LEFT + "/SelectedPanel") as PanelContainer
	_server_status_label = get_node_or_null(_LEFT + "/ServerPanel/ServerVBox/ServerStatusLabel") as Label
	_refresh_button = get_node_or_null(_LEFT + "/ServerPanel/ServerVBox/ServerHeaderHBox/RefreshButton") as Button
	_confirm_button = get_node_or_null(_LEFT + "/ActionsHBox/ConfirmButton") as Button
	_card_panel = get_node_or_null("Container/BodyCenter/CardPanel") as PanelContainer
	_apply_layout_sizes()
	_populate()
	if _list:
		_grouped_data = _build_grouped_data(_filtered)
		_render_grouped_data()
		_list.deselect_all()
		if allow_multi:
			_list.select_mode = ItemList.SELECT_MULTI
		else:
			_list.select_mode = ItemList.SELECT_SINGLE
		_setup_ui_icons()
		UiInteractionApplier.apply_from_engine(self)
	_render_predictions()
	_update_selected_card()
	_update_cache_status_label()
	call_deferred("apply_locale")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_layout_sizes()


func _apply_layout_sizes() -> void:
	if _card_panel == null:
		return
	var vp_size := get_viewport_rect().size
	var card_h := clampf(vp_size.y - 210.0, 620.0, 860.0)
	_card_panel.custom_minimum_size = Vector2(0.0, card_h)
	if _list:
		_list.custom_minimum_size.y = maxf(420.0, card_h - 180.0)


func configure(song_path: String, cached_predictions: Array = []) -> void:
	_song_path = str(song_path).strip_edges()
	_predictions_from_cache = false
	if cached_predictions is Array and cached_predictions.size() > 0:
		_predictions = cached_predictions.duplicate(true)
		_predictions_from_cache = true
	elif cached_predictions is Array:
		_predictions = []
	if is_inside_tree():
		_render_predictions()
		_update_cache_status_label()


func apply_locale() -> void:
	var back_btn := get_node_or_null("Container/BackButton")
	if back_btn:
		back_btn.text = tr("BTN_BACK")
	var title_label := get_node_or_null("Container/InstrumentLabel")
	if title_label:
		title_label.text = tr("GENRE_PICK_TITLE")
	var hint_label := get_node_or_null("Container/SubtitleLabel")
	if hint_label:
		hint_label.text = tr("GENRE_PICK_HINT")
	var server_title := get_node_or_null(_LEFT + "/ServerPanel/ServerVBox/ServerHeaderHBox/ServerTitleLabel")
	if server_title:
		server_title.text = tr("GENRE_SERVER_TITLE")
	if _refresh_button:
		_refresh_button.text = tr("GENRE_REFRESH_ANALYSIS")
	var server_hint := get_node_or_null(_LEFT + "/ServerPanel/ServerVBox/ServerHintLabel")
	if server_hint:
		server_hint.text = tr("GENRE_SERVER_HINT")
	var selected_title := get_node_or_null(_LEFT + "/SelectedPanel/SelectedVBox/SelectedTitleLabel")
	if selected_title:
		selected_title.text = tr("GENRE_SELECTED_TITLE")
	var selected_hint := get_node_or_null(_LEFT + "/SelectedPanel/SelectedVBox/SelectedHintLabel")
	if selected_hint:
		selected_hint.text = tr("GENRE_SELECTED_HINT")
	var search_label := get_node_or_null(_RIGHT + "/SearchRow/SearchFieldLabel")
	if search_label:
		search_label.text = tr("GENRE_SEARCH")
	if _search:
		_search.placeholder_text = tr("GENRE_SEARCH_PLACEHOLDER")
	var reset_btn := get_node_or_null(_LEFT + "/ActionsHBox/ResetButton")
	if reset_btn:
		reset_btn.text = tr("GENRE_RESET")
	if _confirm_button:
		_confirm_button.text = tr("GENRE_CONFIRM")
	var footer := get_node_or_null("Container/FooterHintLabel")
	if footer:
		footer.text = tr("GENRE_FOOTER_HINT")
	_update_selected_card()
	_update_cache_status_label()


func _update_cache_status_label() -> void:
	if _server_status_label == null or _analyzing:
		return
	if _predictions_from_cache and _predictions.size() > 0:
		_server_status_label.text = tr("GENRE_PREDICTIONS_CACHED")
		_server_status_label.visible = true
	elif _predictions.size() > 0:
		_server_status_label.text = tr("GENRE_PREDICTIONS_FRESH")
		_server_status_label.visible = true
	else:
		_server_status_label.text = ""
		_server_status_label.visible = false


func _setup_ui_icons() -> void:
	if _search:
		UiIconHelper.setup_search_field(_search)
	var reset_btn := get_node_or_null(_LEFT + "/ActionsHBox/ResetButton") as Button
	UiIconHelper.setup_reset_button(reset_btn)
	UiIconHelper.setup_confirm_button(_confirm_button)


func _populate():
	_all = []
	var user_path = "user://genre_groups.json"
	var res_path = "res://data/genre_groups.json"
	var open_path = user_path if FileAccess.file_exists(user_path) else res_path
	if not FileAccess.file_exists(open_path):
		var exe_dir = OS.get_executable_path().get_base_dir()
		var ext = exe_dir.path_join("data/genre_groups.json").replace("\\", "/")
		if FileAccess.file_exists(ext):
			open_path = ext
	var fa = FileAccess.open(open_path, FileAccess.READ)
	if fa:
		var txt = fa.get_as_text()
		fa.close()
		var parsed = JSON.parse_string(txt)
		if parsed is Dictionary:
			for k in parsed.keys():
				var arr = parsed[k]
				if arr is Array:
					for g in arr:
						if g is String:
							var s = g.strip_edges()
							if s != "":
								_all.append(s)
	var normalized: Array = []
	for s in _all:
		normalized.append(GenreSearch.canonical_display_genre(str(s)))
	var seen := {}
	var deduped: Array = []
	for s in normalized:
		if s == "" or seen.has(s):
			continue
		seen[s] = true
		deduped.append(s)
	deduped.sort()
	_all = deduped.duplicate()
	_filtered = _all.duplicate()
	if _list:
		_grouped_data = _build_grouped_data(_filtered)
		_render_grouped_data()


func _on_search_changed(text: String):
	_filtered = GenreSearch.filter_genres(_all, text)
	_genre_nav_index = -1
	if _list:
		_grouped_data = _build_grouped_data(_filtered)
		_render_grouped_data()
		_sync_list_selection()


func _on_item_selected(index: int) -> void:
	if auto_close:
		return
	_apply_list_index_to_pending(index)


func _on_item_activated(index: int) -> void:
	if auto_close:
		_apply_list_index_to_pending(index)
		_emit_selection_and_close()
	else:
		_apply_list_index_to_pending(index)


func _apply_list_index_to_pending(index: int) -> void:
	if not _list or index < 0 or index >= _grouped_data.size():
		return
	var it = _grouped_data[index]
	if not (it.has("type") and it["type"] == "genre"):
		return
	_genre_nav_index = index
	_set_pending_genre(GenreSearch.normalize_canonical(str(it["text"])))


func _set_pending_genre(genre_id: String) -> void:
	var key := GenreSearch.normalize_canonical(genre_id)
	if key == "" or key == "unknown":
		_pending_primary = "unknown"
		_pending_all = []
	else:
		_pending_primary = key
		_pending_all = [key]
	_update_selected_card()
	_sync_list_selection()
	_highlight_suggestion_rows()


func _update_selected_card() -> void:
	if not _selected_genre_label:
		return
	var g := str(_pending_primary).strip_edges()
	_clear_children(_icon_slot)
	var pulse_accent := _SELECT_ACCENT
	if g == "" or g == "unknown":
		_selected_genre_label.text = tr("META_GENRE_NONE")
		_selected_genre_label.add_theme_color_override("font_color", Color(0.55, 0.63, 0.76, 0.95))
		_apply_panel_border(_selected_panel, false)
	else:
		var tint := GenreGroupIcons.tint_for_genre(g)
		pulse_accent = tint.lightened(0.12)
		_selected_genre_label.text = g
		_selected_genre_label.add_theme_color_override("font_color", tint.lightened(0.12))
		if _icon_slot:
			_icon_slot.add_child(GenreGroupIcons.make_icon_frame_for_genre(g, tint, 40, 22, true))
		_apply_panel_border(_selected_panel, true, tint)
	_UiMotionEffects.stop_panel_border_pulse(_selected_panel)
	if g != "" and g != "unknown":
		_UiMotionEffects.pulse_panel_border(_selected_panel, pulse_accent, 0.42, 0.88, 0.85)


func _apply_panel_border(panel: PanelContainer, selected: bool, accent: Color = _SELECT_ACCENT) -> void:
	if panel == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.11, 0.92)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 14
	sb.content_margin_top = 12
	sb.content_margin_right = 14
	sb.content_margin_bottom = 12
	if selected:
		sb.border_color = Color(accent.r, accent.g, accent.b, 0.85)
		sb.set_border_width_all(2)
	else:
		sb.border_color = Color(1, 1, 1, 0.08)
		sb.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", sb)


func _pill_stylebox(selected: bool, accent: Color = _SELECT_ACCENT) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = _PILL_BG
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_top = 8
	sb.content_margin_right = 12
	sb.content_margin_bottom = 8
	if selected:
		sb.border_color = Color(accent.r, accent.g, accent.b, 0.8)
		sb.set_border_width_all(1)
	else:
		sb.border_color = _PILL_BORDER
		sb.set_border_width_all(1)
	return sb


func _apply_button_pill_style(btn: Button, stylebox: StyleBoxFlat) -> void:
	if btn == null:
		return
	for state in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state, stylebox)


func _on_confirm_pressed() -> void:
	MusicManager.play_select_sound()
	_emit_selection_and_close()


func _emit_selection_and_close() -> void:
	var primary := GenreSearch.normalize_canonical(_pending_primary)
	var all_genres: Array = []
	if primary != "unknown":
		all_genres = _pending_all.duplicate() if _pending_all.size() > 0 else [primary]
	var from_server := _is_genre_from_server_predictions(primary)
	if from_server:
		_notify_achievement("on_genre_picked_from_server")
	emit_signal("genre_selected", primary, all_genres, from_server)
	queue_free()


func _on_back_button_pressed() -> void:
	queue_free()


func _on_reset_pressed() -> void:
	if auto_close:
		emit_signal("genre_selected", "unknown", [], false)
		queue_free()
	else:
		MusicManager.play_cancel_sound()
		_set_pending_genre("unknown")


func _on_refresh_analysis_pressed() -> void:
	if _analyzing or _song_path == "":
		return
	MusicManager.play_select_sound()
	if GenerationProcessManager:
		var ensure_res = GenerationProcessManager.ensure_running()
		if ensure_res is Dictionary and ensure_res.get("ok", false) == false:
			var err_key := str(ensure_res.get("error_key", "GENRE_ANALYSIS_ERROR"))
			_show_analysis_error(tr(err_key) if err_key.begins_with("GEN_") else err_key)
			return
	_ensure_api_client()
	_analyzing = true
	_predictions_from_cache = false
	if _server_status_label:
		_server_status_label.visible = true
		_server_status_label.text = tr("GENRE_STATUS_CONNECTING")
	if _refresh_button:
		_refresh_button.disabled = true
		_refresh_button.text = tr("GENRE_REFRESHING")
	_api_client.analyze_genre_predictions(_song_path)


func _ensure_api_client() -> void:
	if _api_client and is_instance_valid(_api_client):
		return
	_api_client = GenerationApiClient.new()
	add_child(_api_client)
	_api_client.genre_analysis_completed.connect(_on_genre_analysis_completed)
	_api_client.genre_analysis_error.connect(_on_genre_analysis_error)
	_api_client.genre_analysis_status.connect(_on_genre_analysis_status)


func _on_genre_analysis_status(status_key: String, detail: String) -> void:
	if _server_status_label == null:
		return
	match status_key:
		"reading_file":
			_server_status_label.text = tr("GENRE_STATUS_READING_FILE")
		"uploading":
			var size_mb := float(detail) if detail != "" else 0.0
			_server_status_label.text = tr("GENRE_STATUS_UPLOADING") % size_mb
		"analyzing":
			_server_status_label.text = tr("GENRE_STATUS_ANALYZING")
		_:
			if status_key.begins_with("GEN_"):
				_server_status_label.text = tr(status_key)
			elif detail != "":
				_server_status_label.text = "%s %s" % [status_key, detail]
	_server_status_label.visible = true


func _on_genre_analysis_completed(song_path: String, predictions: Array) -> void:
	_analyzing = false
	if _refresh_button:
		_refresh_button.disabled = false
		_refresh_button.text = tr("GENRE_REFRESH_ANALYSIS")
	if str(song_path) != _song_path:
		return
	_predictions = predictions.duplicate(true) if predictions is Array else []
	_predictions_from_cache = false
	if _song_path != "" and _predictions.size() > 0:
		SongLibrary.update_metadata(_song_path, {"genre_predictions": _predictions})
	_render_predictions()
	_update_cache_status_label()
	_notify_achievement("on_genre_analyzed")


func _on_genre_analysis_error(message: String) -> void:
	_analyzing = false
	if _refresh_button:
		_refresh_button.disabled = false
		_refresh_button.text = tr("GENRE_REFRESH_ANALYSIS")
	_show_analysis_error(message)
	if _server_status_label:
		_server_status_label.text = ""
		_server_status_label.visible = false


func _show_analysis_error(message: String) -> void:
	if not _suggestions_vbox:
		return
	_clear_children(_suggestions_vbox)
	var lbl := Label.new()
	lbl.text = tr("GENRE_ANALYSIS_ERROR") % message
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_color", Color(0.95, 0.55, 0.45, 1))
	lbl.add_theme_font_size_override("font_size", 14)
	_suggestions_vbox.add_child(lbl)


func _render_predictions() -> void:
	if not _suggestions_vbox:
		return
	_clear_children(_suggestions_vbox)
	if _predictions.is_empty():
		var empty := Label.new()
		empty.text = tr("GENRE_NO_PREDICTIONS")
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_color_override("font_color", Color(0.55, 0.63, 0.76, 0.9))
		empty.add_theme_font_size_override("font_size", 14)
		_suggestions_vbox.add_child(empty)
		return
	_suggestions_vbox.add_theme_constant_override("separation", 4)
	var shown := 0
	for i in range(_predictions.size()):
		if shown >= PREDICTION_TOP_K:
			break
		var pred = _predictions[i]
		if typeof(pred) != TYPE_DICTIONARY:
			continue
		var genre_id := GenreSearch.normalize_canonical(str(pred.get("id", "")))
		if genre_id == "":
			continue
		var percent := float(pred.get("percent", 0.0))
		var color := GenreGroupIcons.tint_for_genre(genre_id)
		_suggestions_vbox.add_child(_make_suggestion_row(genre_id, percent, color))
		shown += 1
	_highlight_suggestion_rows()


func _make_suggestion_row(genre_id: String, percent: float, bar_color: Color) -> Button:
	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size.y = GenrePortraitRowsUi.ROW_MIN_HEIGHT + 4
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.set_meta("genre_id", genre_id)
	btn.pressed.connect(func(): _set_pending_genre(genre_id))
	_apply_button_pill_style(btn, _pill_stylebox(false, bar_color))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 2)
	margin.add_theme_constant_override("margin_right", 2)
	btn.add_child(margin)

	var tint := GenreGroupIcons.tint_for_genre(genre_id)
	margin.add_child(
		GenrePortraitRowsUi.build_row_hbox(
			GenrePortraitRowsUi.icon_cell_for_genre(genre_id, tint),
			genre_id,
			percent,
			100.0,
			"%.0f%%" % percent,
			bar_color
		)
	)
	return btn


func _highlight_suggestion_rows() -> void:
	if not _suggestions_vbox:
		return
	for child in _suggestions_vbox.get_children():
		if child is Button and child.has_meta("genre_id"):
			var gid := str(child.get_meta("genre_id"))
			var selected := gid == _pending_primary
			var color := GenreGroupIcons.tint_for_genre(gid)
			_apply_button_pill_style(child, _pill_stylebox(selected, color))
			_UiMotionEffects.stop_control_border_pulse(child)
			if selected:
				_UiMotionEffects.pulse_button_outline(child, color.lightened(0.12), 0.45, 0.9, 0.75)


func _clear_children(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		child.queue_free()


func _input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		_on_back_button_pressed()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if UiScreenHotkeys.should_block_hotkeys(get_viewport()):
		return
	match event.keycode:
		KEY_UP, KEY_KP_8:
			_move_genre_selection(-1)
			get_viewport().set_input_as_handled()
		KEY_DOWN, KEY_KP_2:
			_move_genre_selection(1)
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER:
			if auto_close and _genre_nav_index >= 0:
				_on_item_activated(_genre_nav_index)
			else:
				_on_confirm_pressed()
			get_viewport().set_input_as_handled()


func _move_genre_selection(delta: int) -> void:
	if _list == null or _list.item_count == 0:
		return
	var idx := _genre_nav_index
	if idx < 0:
		idx = 0 if delta > 0 else _list.item_count - 1
	var attempts := _list.item_count
	while attempts > 0:
		idx = (idx + delta + _list.item_count) % _list.item_count
		if _list.is_item_selectable(idx):
			_genre_nav_index = idx
			_list.select(idx, true)
			_list.ensure_current_is_visible()
			if not auto_close:
				_apply_list_index_to_pending(idx)
			return
		attempts -= 1


func set_initial(primary_genre: String):
	var key := GenreSearch.normalize_canonical(primary_genre)
	if key == "":
		key = "unknown"
	_pending_primary = key
	if key != "unknown":
		_pending_all = [key]
	else:
		_pending_all = []
	_sync_list_selection()
	_update_selected_card()
	_highlight_suggestion_rows()


func _sync_list_selection() -> void:
	if not _list:
		return
	_list.deselect_all()
	var key := str(_pending_primary)
	if key == "" or key == "unknown":
		return
	for i in range(_list.item_count):
		if i >= _grouped_data.size():
			break
		var it = _grouped_data[i]
		if it.has("type") and it["type"] == "genre" and str(it["text"]) == key:
			_list.select(i, true)
			_genre_nav_index = i
			_list.ensure_current_is_visible()
			break


func _build_grouped_data(genres_arr: Array) -> Array:
	var groups = {}
	for g in genres_arr:
		var s = str(g)
		var letter = s.substr(0, 1).to_lower() if s.length() > 0 else "?"
		if not groups.has(letter):
			groups[letter] = []
		groups[letter].append(s)
	var letters = groups.keys()
	letters.sort()
	var res = []
	for letter in letters:
		var items = groups[letter]
		items.sort()
		var header_text = "%d %s" % [items.size(), letter.to_upper()]
		res.append({"type": "header", "text": header_text, "letter": letter})
		for s2 in items:
			res.append({"type": "genre", "text": s2})
	return res


func _render_grouped_data() -> void:
	if _list == null:
		return
	_list.clear()
	for it in _grouped_data:
		if it.has("type") and it["type"] == "header":
			var idx = _list.add_item(str(it["text"]))
			_list.set_item_custom_bg_color(idx, _GROUP_HEADER_BG)
			_list.set_item_selectable(idx, false)
		else:
			var genre_id := GenreSearch.normalize_canonical(str(it["text"]))
			_list.add_item(genre_id)


func _exit_tree() -> void:
	if _api_client and is_instance_valid(_api_client):
		_api_client.queue_free()
		_api_client = null


func _is_genre_from_server_predictions(primary: String) -> bool:
	if primary == "" or primary == "unknown" or _predictions.is_empty():
		return false
	var limit := mini(_predictions.size(), PREDICTION_TOP_K)
	for i in range(limit):
		var pred = _predictions[i]
		if typeof(pred) != TYPE_DICTIONARY:
			continue
		var genre_id := GenreSearch.normalize_canonical(str(pred.get("id", "")))
		if genre_id == primary:
			return true
	return false


func _notify_achievement(method: String) -> void:
	var ge := get_tree().root.get_node_or_null("GameEngine")
	if ge == null:
		ge = get_tree().root.find_child("GameEngine", true, false)
	if ge and ge.has_method("get_achievement_system"):
		var ach = ge.get_achievement_system()
		if ach and ach.has_method(method):
			ach.call(method)
