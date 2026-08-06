extends Node
class_name SongListController

const _SS = preload("res://logic/domain/library/song_select_strings.gd")
const _StatusToast = preload("res://logic/ui/status_toast.gd")
const _SongFavoriteIcons = preload("res://scenes/song_select/lib/song_favorite_icons.gd")
const _UiListSlideTransition = preload("res://logic/ui/ui_list_slide_transition.gd")
const _UiModifierSounds = preload("res://logic/ui/ui_modifier_sounds.gd")
const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const _ProfileGenrePortrait = preload("res://logic/domain/profile/profile_genre_portrait.gd")
const _PlaylistLibraryBrowse = preload("res://logic/domain/library/playlist_library_browse.gd")

signal song_selected(song_data: Dictionary)
signal song_activated(song_data: Dictionary)
signal song_added(song_data: Dictionary)
signal song_add_rejected(reject_info: Dictionary)
signal song_list_changed()
signal song_edited(song_data: Dictionary, item_list_index: int)
signal heavy_list_rebuild_started()
signal heavy_list_rebuild_finished()

var item_list: ItemList = null
var current_grouped_data = []
var current_filter_mode: String = "title"
var current_instrument: String = "drums"
var current_mode: String = "basic"
var current_lanes: int = 4
var active_run_modifiers: Array = []
var _difficulty_decimal_cache: Dictionary = {}
var _difficulty_decimal_cache_key: String = ""
var _notes_ready_cache: Dictionary = {}
var _notes_ready_cache_key: String = ""
var _playlist_browse_id: String = ""

var edit_mode: bool = false
var _list_first_populate := true
var _metadata_edit_lock_checker: Callable
var _unseen_medals_loader: Callable

const _UNSEEN_MEDALS_GOLD := Color("#F2B35A")
const _LIST_ITEM_PANEL_BG := Color(0.1, 0.11, 0.15, 1.0)
const _GROUP_HEADER_BG := Color(0.2, 0.2, 0.2, 1.0)
var _edit_context = {
	"dialog": null,
	"line_edit": null,
	"spin_box": null,
	"song_data": null,
	"field_name": null,
	"selected_index": -1,
	"type": ""
}

func set_item_list(list_control: ItemList):
	item_list = list_control
	if item_list:
		if not item_list.item_selected.is_connected(_on_item_selected):
			item_list.item_selected.connect(_on_item_selected)
		if not item_list.item_activated.is_connected(_on_item_activated):
			item_list.item_activated.connect(_on_item_activated)
		_remove_legacy_medal_overlay()

func set_filter_mode(mode: String):
	current_filter_mode = mode

func set_generation_settings(instrument: String, mode: String, lanes: int):
	current_instrument = instrument
	current_mode = mode
	current_lanes = lanes
	_invalidate_scope_caches()
	refresh_highlight_for_current_settings()


func set_active_run_modifiers(modifiers: Array) -> void:
	active_run_modifiers = _RunModifiers.sanitize(modifiers)
	_invalidate_scope_caches()
	if current_filter_mode == "difficulty":
		populate_items_grouped(true)


func set_playlist_browse(playlist_id: String) -> void:
	_playlist_browse_id = str(playlist_id).strip_edges()
	_invalidate_scope_caches()


func clear_playlist_browse() -> void:
	set_playlist_browse("")


func get_playlist_browse_id() -> String:
	return _playlist_browse_id


func get_playlist_view_filter() -> Dictionary:
	return _PlaylistLibraryBrowse.view_filter_for(_playlist_browse_id)


func populate_items():
	if not item_list:
		return
	item_list.clear()
	var songs_list = SongLibrary.get_songs_list()
	for song_data in songs_list:
		var display_text = _format_display_text(song_data)
		item_list.add_item(display_text)
	emit_signal("song_list_changed")

func populate_items_grouped(skip_transition: bool = false):
	if not item_list:
		return
	var prev = _get_selected_song_path()
	var rebuild := func() -> void:
		item_list.clear()
		current_grouped_data = _build_grouped_data(_songs_input_for_grouping(SongLibrary.get_songs_list()))
		_render_grouped_data()
		emit_signal("song_list_changed")
		_reselect_previous(prev)
	_run_grouped_rebuild(rebuild, skip_transition)

func update_song_count_label(count_label: Label):
	if count_label:
		var song_count = 0
		for item_data in current_grouped_data:
			if item_data.type == "song":
				song_count += 1
		count_label.text = _SS._translate("SONG_COUNT") % song_count

func add_song_from_path(file_path: String):
	var metadata_dict = SongLibrary.add_song(file_path)
	if metadata_dict.has("error"):
		emit_signal("song_add_rejected", metadata_dict)
		return
	if not metadata_dict.is_empty():
		emit_signal("song_added", metadata_dict)

func _on_item_selected(index):
	if index >= 0 and index < current_grouped_data.size():
		var item_data = current_grouped_data[index]
		if item_data.type == "song":
			var selected_song_data = item_data.data
			emit_signal("song_selected", selected_song_data)


func _on_item_activated(index: int) -> void:
	if index < 0 or index >= current_grouped_data.size():
		return
	var item_data = current_grouped_data[index]
	if item_data.type != "song":
		return
	emit_signal("song_activated", item_data.data)

func filter_items(filter_text: String, skip_transition: bool = false):
	if not item_list:
		return
	var prev = _get_selected_song_path()
	var q = _normalize_search_text(filter_text)
	var rebuild := func() -> void:
		item_list.clear()
		if q.is_empty():
			current_grouped_data = _build_grouped_data(_songs_input_for_grouping(SongLibrary.get_songs_list()))
		else:
			var filtered = []
			for song_data in SongLibrary.get_songs_list():
				var display_text = _format_display_text(song_data)
				if _normalize_search_text(display_text).find(q) != -1:
					filtered.append(song_data)
			current_grouped_data = _build_grouped_data(_songs_input_for_grouping(filtered))
		_render_grouped_data()
		emit_signal("song_list_changed")
		_reselect_previous(prev)
	_run_grouped_rebuild(rebuild, skip_transition)


func find_item_list_index_for_path(song_path: String) -> int:
	if song_path == "":
		return -1
	var norm_path := String(song_path).replace("\\", "/").strip_edges()
	var norm_lower := norm_path.to_lower()
	var file_lower := norm_path.get_file().to_lower()
	var file_match := -1
	for i in range(current_grouped_data.size()):
		var item_data = current_grouped_data[i]
		if item_data.type != "song":
			continue
		var p := String(item_data.data.get("path", "")).replace("\\", "/").strip_edges()
		if p == norm_path or p.to_lower() == norm_lower:
			return i
		# Diary paths sometimes differ only by absolute/relative prefix.
		if file_lower != "" and file_match < 0 and p.get_file().to_lower() == file_lower:
			file_match = i
	return file_match


func select_song_by_path(song_path: String) -> bool:
	var idx := find_item_list_index_for_path(song_path)
	if idx < 0 or item_list == null:
		return false
	item_list.select(idx, true)
	item_list.ensure_current_is_visible()
	_on_item_selected(idx)
	return true


func _run_grouped_rebuild(rebuild: Callable, skip_transition: bool = false) -> void:
	var heavy := current_filter_mode == "difficulty"
	if heavy:
		emit_signal("heavy_list_rebuild_started")
		call_deferred("_run_heavy_grouped_rebuild", rebuild, skip_transition)
		return
	_run_grouped_rebuild_immediate(rebuild, skip_transition)


func _run_heavy_grouped_rebuild(rebuild: Callable, skip_transition: bool = false) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_run_grouped_rebuild_immediate(rebuild, skip_transition)
	emit_signal("heavy_list_rebuild_finished")


func _run_grouped_rebuild_immediate(rebuild: Callable, skip_transition: bool = false) -> void:
	var skip := skip_transition or _list_first_populate
	if _list_first_populate:
		_list_first_populate = false
	_UiListSlideTransition.run(item_list, rebuild, skip)

func group_key_to_text(letter: String) -> String:
	return letter.to_upper()

func get_first_letter(text: String) -> String:
	if text.is_empty():
		return ""
	return text.substr(0, 1).to_lower()

func get_filter_field_value(song_data: Dictionary) -> String:
	if current_filter_mode == "artist":
		return _effective_artist(song_data)
	if current_filter_mode == "year":
		return _effective_year(song_data)
	return _effective_title(song_data)

func _normalize_search_text(text: String) -> String:
	var s = String(text).to_lower().strip_edges()
	s = s.replace("—", "-").replace("–", "-")
	while s.find("  ") != -1:
		s = s.replace("  ", " ")
	return s

func get_song_data_by_item_list_index(item_list_index: int) -> Dictionary:
	if item_list_index >= 0 and item_list_index < current_grouped_data.size():
		var item_data = current_grouped_data[item_list_index]
		if item_data.type == "song":
			return item_data.data.duplicate()
		return {}
	return {}

func update_song_at_index(item_list_index: int, new_song_data: Dictionary) -> bool:
	if not item_list or item_list_index < 0 or item_list_index >= current_grouped_data.size():
		return false
	var item_data = current_grouped_data[item_list_index]
	if item_data.type != "song":
		return false
	current_grouped_data[item_list_index].data = new_song_data.duplicate(true)
	var display_text = _format_display_text(new_song_data)
	item_list.set_item_text(item_list_index, display_text)
	_apply_song_item_visual(item_list_index, new_song_data)
	return true

func set_edit_mode(enabled: bool):
	edit_mode = enabled

func set_metadata_edit_lock_checker(checker: Callable) -> void:
	_metadata_edit_lock_checker = checker

func set_unseen_medals_loader(loader: Callable) -> void:
	_unseen_medals_loader = loader


func refresh_unseen_medals_highlights() -> void:
	_update_medal_outline_indices()

func is_edit_mode_active() -> bool:
	return edit_mode

func start_editing(field_type: String, song_data: Dictionary, selected_item_list_index: int) -> bool:
	if not edit_mode:
		return false
	var song_path := str(song_data.get("path", ""))
	if _metadata_edit_lock_checker.is_valid() and _metadata_edit_lock_checker.call(song_path):
		return false
	_edit_context["song_data"] = song_data.duplicate(true)
	_edit_context["selected_index"] = selected_item_list_index
	_edit_context["field_name"] = field_type
	_edit_context["type"] = "field"
	match field_type:
		"title", "artist", "year", "bpm", "primary_genre":
			_open_metadata_editor(field_type)
		_:
			return false
	return true

func _open_metadata_editor(focus_field: String) -> void:
	var song_data = _edit_context["song_data"]
	var song_path := str(song_data.get("path", ""))
	if song_path != "":
		var raw := SongLibrary.get_metadata_for_song(song_path)
		if not raw.is_empty():
			var merged := raw.duplicate(true)
			merged["path"] = song_path
			song_data = merged
			_edit_context["song_data"] = song_data
	_edit_context["type"] = "metadata_editor"
	var dlg_scene = load("res://scenes/song_select/dialogs/metadata_edit_dialog.tscn")
	if not dlg_scene:
		_cleanup_edit_context()
		return
	var dlg = dlg_scene.instantiate()
	_edit_context["dialog"] = dlg
	if dlg.has_method("setup"):
		dlg.setup(song_data, focus_field)
	dlg.metadata_saved.connect(_on_metadata_saved)
	dlg.cancelled.connect(_on_dialog_closed)
	var host := get_parent() if get_parent() else self
	if host and host.has_method("_suppress_favorite_for_overlay"):
		host.call("_suppress_favorite_for_overlay")
	host.add_child(dlg)
	host.move_child(dlg, -1)
	UiInteractionApplier.apply_from_engine(dlg)
	_UiModifierSounds.play_select()

func _on_metadata_saved(fields_to_update: Dictionary) -> void:
	var song_data = _edit_context["song_data"]
	var selected_item_list_index = _edit_context["selected_index"]
	if song_data and fields_to_update is Dictionary and fields_to_update.size() > 0:
		var song_file_path = str(song_data.get("path", ""))
		if song_file_path != "":
			for key in fields_to_update.keys():
				song_data[key] = fields_to_update[key]
			SongLibrary.update_metadata(song_file_path, fields_to_update)
			_emit_song_edited_after_save(song_file_path, song_data, selected_item_list_index)
	_cleanup_edit_context()

func _edit_primary_genre():
	var song_data = _edit_context["song_data"]
	var old_genre = song_data.get("primary_genre", "")
	_edit_context["type"] = "primary_genre"
	var dlg_scene = load("res://scenes/song_select/dialogs/genre_picker_dialog.tscn")
	if dlg_scene:
		var dlg = dlg_scene.instantiate()
		_edit_context["dialog"] = dlg
		dlg.auto_close = false
		var song_path := str(song_data.get("path", ""))
		var cached_preds: Array = []
		if song_path != "":
			var meta := SongLibrary.get_metadata_for_song(song_path)
			var raw_preds = meta.get("genre_predictions", [])
			if raw_preds is Array:
				cached_preds = raw_preds
		if dlg.has_method("configure"):
			dlg.configure(song_path, cached_preds)
		if dlg.has_method("set_initial"):
			dlg.set_initial(old_genre)
		dlg.genre_selected.connect(_on_genre_selected_from_picker)
		dlg.tree_exited.connect(func() -> void: _UiModifierSounds.play_deselect())
		if get_parent():
			get_parent().add_child(dlg)
		else:
			add_child(dlg)
		UiInteractionApplier.apply_from_engine(dlg)
		_UiModifierSounds.play_select()

func _emit_song_edited_after_save(song_file_path: String, fallback: Dictionary, item_list_index: int) -> void:
	var persisted := SongLibrary.get_display_metadata_for_song(song_file_path)
	if persisted.is_empty():
		emit_signal("song_edited", fallback.duplicate(true), item_list_index)
	else:
		emit_signal("song_edited", persisted, item_list_index)
	_show_metadata_saved_toast()


func _show_metadata_saved_toast() -> void:
	var host := get_parent()
	if host == null:
		return
	_StatusToast.show_from_node(
		host,
		"metadata_saved",
		TranslationServer.translate("STATUS_METADATA_SAVED"),
		"save",
		2.5,
	)

func _on_genre_selected_from_picker(primary_genre: String, all_genres: Array, from_server: bool = false):
	var selected_item_list_index = _edit_context["selected_index"]
	if selected_item_list_index < 0 or selected_item_list_index >= current_grouped_data.size():
		_cleanup_edit_context()
		return
	var item_data = current_grouped_data[selected_item_list_index]
	if item_data.type != "song":
		_cleanup_edit_context()
		return
	var song_data = item_data.data
	var song_file_path = song_data.get("path", "")
	var fields_to_update = {
		"primary_genre": primary_genre,
		"genre_from_server": from_server and primary_genre != "" and primary_genre != "unknown",
	}
	if primary_genre == "unknown":
		fields_to_update["genres"] = []
		fields_to_update["genre_from_server"] = false
	elif all_genres and all_genres is Array and all_genres.size() > 0:
		fields_to_update["genres"] = all_genres
	SongLibrary.update_metadata(song_file_path, fields_to_update)
	_emit_song_edited_after_save(song_file_path, song_data, selected_item_list_index)
	_cleanup_edit_context()

func _cleanup_edit_context():
	var dlg = _edit_context["dialog"]
	if dlg and is_instance_valid(dlg):
		dlg.hide()
	_edit_context["dialog"] = null
	_edit_context["line_edit"] = null
	_edit_context["spin_box"] = null
	_edit_context["song_data"] = null
	_edit_context["field_name"] = null
	_edit_context["selected_index"] = -1
	_edit_context["type"] = ""

func _on_dialog_closed():
	var was_metadata := str(_edit_context.get("type", "")) == "metadata_editor"
	_cleanup_edit_context()
	if was_metadata:
		_UiModifierSounds.play_deselect()
	var host := get_parent()
	if host and host.has_method("_update_favorite_button"):
		var song_path := ""
		if host.has_method("get_current_selected_song"):
			song_path = String(host.get_current_selected_song().get("path", ""))
		host.call("_update_favorite_button", song_path)
	if host and host.has_method("_focus_song_list"):
		host.call_deferred("_focus_song_list")

func _songs_input_for_grouping(songs_list: Array) -> Array:
	var scoped := songs_list
	if _playlist_browse_id != "":
		scoped = _PlaylistLibraryBrowse.filter_songs(songs_list, _playlist_browse_id)
	if current_filter_mode in ["difficulty", "notes_ready", "play_count", "duration", "bpm", "genre_group"]:
		return scoped
	return _sorted_songs(scoped)


func _sorted_songs(songs_list: Array) -> Array:
	var arr = songs_list.duplicate()
	match current_filter_mode:
		"play_count":
			arr.sort_custom(func(a, b):
				var count_a := _play_count_for(String(a.get("path", "")))
				var count_b := _play_count_for(String(b.get("path", "")))
				if count_a != count_b:
					return count_a > count_b
				return _effective_title(a).to_lower() < _effective_title(b).to_lower()
			)
		"artist":
			arr.sort_custom(func(a, b):
				var artist_a = _effective_artist(a).to_lower()
				var artist_b = _effective_artist(b).to_lower()
				if artist_a == artist_b:
					var title_a = _effective_title(a).to_lower()
					var title_b = _effective_title(b).to_lower()
					if title_a == title_b:
						return String(a.get("path","")) < String(b.get("path",""))
					else:
						return title_a < title_b
				else:
					return artist_a < artist_b
			)
		"year":
			arr.sort_custom(func(a, b):
				var year_a := _year_sort_value(a)
				var year_b := _year_sort_value(b)
				if year_a != year_b:
					return year_a > year_b
				var title_a = _effective_title(a).to_lower()
				var title_b = _effective_title(b).to_lower()
				if title_a == title_b:
					return String(a.get("path","")) < String(b.get("path",""))
				return title_a < title_b
			)
		_:
			arr.sort_custom(func(a, b):
				var title_a = _effective_title(a).to_lower()
				var title_b = _effective_title(b).to_lower()
				if title_a == title_b:
					var artist_a = _effective_artist(a).to_lower()
					var artist_b = _effective_artist(b).to_lower()
					if artist_a == artist_b:
						return String(a.get("path","")) < String(b.get("path",""))
					else:
						return artist_a < artist_b
				else:
					return title_a < title_b
			)
	return arr


func _play_count_for(song_path: String) -> int:
	if song_path == "":
		return 0
	if TrackStatsManager and TrackStatsManager.has_method("get_completion_count"):
		return TrackStatsManager.get_completion_count(song_path)
	return 0


func _invalidate_difficulty_decimal_cache() -> void:
	_difficulty_decimal_cache.clear()
	_difficulty_decimal_cache_key = ""


func _invalidate_scope_caches() -> void:
	_invalidate_difficulty_decimal_cache()
	_notes_ready_cache.clear()
	_notes_ready_cache_key = ""


func _notes_ready_cache_token() -> String:
	return "%s|%s|%d" % [current_instrument, _chart_lookup_key(), current_lanes]


func _invalidate_notes_ready_cache_for_path(song_path: String) -> void:
	if song_path != "":
		_notes_ready_cache.erase(song_path)


func _difficulty_decimal_cache_token() -> String:
	return "%s|%s|%d|%s" % [current_instrument, _chart_lookup_key(), current_lanes, str(active_run_modifiers)]


func _chart_lookup_key() -> String:
	var intent := ""
	if SettingsManager:
		intent = str(SettingsManager.get_setting("last_generation_intent", ""))
	return GenerationIntents.chart_lookup_key(current_mode, intent)


func _chart_decimal_for_sort(song_path: String) -> float:
	if song_path == "":
		return 0.0
	var token := _difficulty_decimal_cache_token()
	if token != _difficulty_decimal_cache_key:
		_difficulty_decimal_cache.clear()
		_difficulty_decimal_cache_key = token
	if _difficulty_decimal_cache.has(song_path):
		return float(_difficulty_decimal_cache[song_path])
	var base := ChartDifficultyAnalyzer.stats_for_sort(
		song_path, current_instrument, _chart_lookup_key(), current_lanes
	)
	var decimal := 0.0
	if not base.is_empty():
		if active_run_modifiers.is_empty():
			decimal = ChartDifficultyAnalyzer.decimal_rating_from_stats(base)
		else:
			var stats := ChartDifficultyAnalyzer.effective_stats_for_modifiers(
				base,
				active_run_modifiers,
				_RunModifiers.sync_params_from_modifiers(
					active_run_modifiers,
					SettingsManager.get_run_modifier_params()
				)
			)
			decimal = float(stats.get("decimal_rating", ChartDifficultyAnalyzer.decimal_rating_from_stats(base)))
	_difficulty_decimal_cache[song_path] = decimal
	return decimal


func _difficulty_decimals_for_songs(songs_list: Array) -> Dictionary:
	var out: Dictionary = {}
	for song_data in songs_list:
		if not song_data is Dictionary:
			continue
		var path := String(song_data.get("path", ""))
		if path == "" or out.has(path):
			continue
		out[path] = _chart_decimal_for_sort(path)
	return out


func _chart_rating_for_sort(song_path: String) -> int:
	return int(floor(_chart_decimal_for_sort(song_path)))


func _play_count_bucket(count: int) -> String:
	if count >= 10:
		return "10+"
	if count >= 1:
		return "<10"
	return "0"


func _play_count_bucket_label(bucket: String) -> String:
	match bucket:
		"10+":
			return _SS._translate("SONG_GROUP_PLAY_10_PLUS")
		"<10":
			return _SS._translate("SONG_GROUP_PLAY_UNDER_10")
		_:
			return _SS._translate("SONG_GROUP_PLAY_NEVER")


func _difficulty_bucket_label(rating: int) -> String:
	if rating <= 0:
		return _SS._translate("SONG_GROUP_DIFFICULTY_NONE")
	return str(rating)


func _group_header_text(count: int, label: String) -> String:
	var fmt := _SS._translate("SONG_GROUP_HEADER_FMT")
	if fmt.find("%") == -1:
		fmt = "%d %s"
	return fmt % [count, label]


func _sort_songs_by_title(songs: Array) -> Array:
	var arr = songs.duplicate()
	arr.sort_custom(func(a, b):
		var title_a = _effective_title(a).to_lower()
		var title_b = _effective_title(b).to_lower()
		if title_a == title_b:
			return String(a.get("path", "")) < String(b.get("path", ""))
		return title_a < title_b
	)
	return arr


func _sort_songs_by_metric_desc(songs: Array, metric: Callable) -> Array:
	var arr = songs.duplicate()
	arr.sort_custom(func(a, b):
		var value_a: Variant = metric.call(a)
		var value_b: Variant = metric.call(b)
		if value_a != value_b:
			return value_a > value_b
		return _effective_title(a).to_lower() < _effective_title(b).to_lower()
	)
	return arr


func _sort_songs_by_difficulty_desc(songs: Array) -> Array:
	return _sort_songs_by_metric_desc(
		songs,
		func(song_data: Dictionary) -> float:
			return _chart_decimal_for_sort(String(song_data.get("path", "")))
	)


func _sort_songs_by_bpm_desc(songs: Array) -> Array:
	return _sort_songs_by_metric_desc(
		songs,
		func(song_data: Dictionary) -> int:
			return _bpm_value_for(song_data)
	)


func _sort_songs_by_year_desc(songs: Array) -> Array:
	return _sort_songs_by_metric_desc(
		songs,
		func(song_data: Dictionary) -> int:
			return _year_sort_value(song_data)
	)


func _sort_songs_by_duration_desc(songs: Array) -> Array:
	return _sort_songs_by_metric_desc(
		songs,
		func(song_data: Dictionary) -> float:
			return _duration_seconds_for(song_data)
	)


func _sort_songs_by_play_count(songs: Array) -> Array:
	var arr = songs.duplicate()
	arr.sort_custom(func(a, b):
		var count_a := _play_count_for(String(a.get("path", "")))
		var count_b := _play_count_for(String(b.get("path", "")))
		if count_a != count_b:
			return count_a > count_b
		return _effective_title(a).to_lower() < _effective_title(b).to_lower()
	)
	return arr


func _build_difficulty_grouped_data(songs_list: Array) -> Array:
	var decimals := _difficulty_decimals_for_songs(songs_list)
	var buckets: Dictionary = {}
	for song_data in songs_list:
		if not song_data is Dictionary:
			continue
		var path := String(song_data.get("path", ""))
		var rating := float(decimals.get(path, 0.0))
		var bucket := int(floor(rating))
		if not buckets.has(bucket):
			buckets[bucket] = []
		buckets[bucket].append(song_data)
	var ratings: Array = buckets.keys()
	ratings.sort()
	ratings.reverse()
	var grouped: Array = []
	for bucket in ratings:
		var songs_in_group: Array = buckets[bucket].duplicate()
		songs_in_group.sort_custom(func(a, b):
			var value_a: float = float(decimals.get(String(a.get("path", "")), 0.0))
			var value_b: float = float(decimals.get(String(b.get("path", "")), 0.0))
			if value_a != value_b:
				return value_a > value_b
			return _effective_title(a).to_lower() < _effective_title(b).to_lower()
		)
		if songs_in_group.is_empty():
			continue
		var header_path := String(songs_in_group[0].get("path", ""))
		var header_rating := float(decimals.get(header_path, 0.0))
		var header_label := (
			"%s  %d" % [ChartDifficultyAnalyzer.format_compact_rating(header_rating), songs_in_group.size()]
			if int(bucket) > 0
			else _group_header_text(songs_in_group.size(), _difficulty_bucket_label(int(bucket)))
		)
		grouped.append({
			"type": "header",
			"text": header_label,
			"difficulty_rating": int(bucket),
			"difficulty_rating_decimal": header_rating,
			"group_count": songs_in_group.size(),
			"expanded": true,
		})
		for song_data in songs_in_group:
			grouped.append({
				"type": "song",
				"data": song_data.duplicate(true),
			})
	return grouped


func _build_year_grouped_data(songs_list: Array) -> Array:
	var buckets: Dictionary = {}
	for song_data in songs_list:
		if not song_data is Dictionary:
			continue
		var bucket_key := _year_bucket_key(song_data)
		if not buckets.has(bucket_key):
			buckets[bucket_key] = []
		buckets[bucket_key].append(song_data)
	var years: Array = buckets.keys()
	years.sort_custom(func(a, b):
		var year_a := _year_sort_value_from_bucket(String(a))
		var year_b := _year_sort_value_from_bucket(String(b))
		return year_a > year_b
	)
	var grouped: Array = []
	for bucket_key in years:
		var songs_in_group: Array = _sort_songs_by_year_desc(buckets[bucket_key])
		if songs_in_group.is_empty():
			continue
		grouped.append({
			"type": "header",
			"text": _group_header_text(songs_in_group.size(), _year_bucket_label(String(bucket_key))),
			"expanded": true,
		})
		for song_data in songs_in_group:
			grouped.append({
				"type": "song",
				"data": song_data.duplicate(true),
			})
	return grouped


func _bpm_value_for(song_data: Dictionary) -> int:
	if not song_data is Dictionary:
		return -1
	var path := String(song_data.get("path", ""))
	var bpm: Variant = song_data.get("bpm", "")
	if _SS.is_missing_metadata_value(bpm) and path != "":
		bpm = SongLibrary.get_metadata_for_song(path).get("bpm", "")
	if _SS.is_missing_metadata_value(bpm):
		return -1
	var text := str(bpm).strip_edges().split(".")[0]
	if not text.is_valid_int():
		return -1
	return int(text)


func _bpm_decade_bucket(song_data: Dictionary) -> int:
	var bpm := _bpm_value_for(song_data)
	if bpm < 0:
		return -1
	return int(bpm / 10) * 10


func _bpm_bucket_label(bucket_key: int) -> String:
	if bucket_key < 0:
		return _SS._translate("SONG_GROUP_BPM_UNKNOWN")
	return _SS._translate("SONG_GROUP_BPM_FMT") % bucket_key


func _build_bpm_grouped_data(songs_list: Array) -> Array:
	var buckets: Dictionary = {}
	for song_data in songs_list:
		if not song_data is Dictionary:
			continue
		var bucket_key := _bpm_decade_bucket(song_data)
		if not buckets.has(bucket_key):
			buckets[bucket_key] = []
		buckets[bucket_key].append(song_data)
	var keys: Array = buckets.keys()
	keys.sort_custom(func(a, b):
		var ia := int(a)
		var ib := int(b)
		if ia < 0:
			return false
		if ib < 0:
			return true
		if ia != ib:
			return ia > ib
		return false
	)
	var grouped: Array = []
	for bucket_key in keys:
		var songs_in_group: Array = _sort_songs_by_bpm_desc(buckets[bucket_key])
		if songs_in_group.is_empty():
			continue
		grouped.append({
			"type": "header",
			"text": _group_header_text(songs_in_group.size(), _bpm_bucket_label(int(bucket_key))),
			"bpm_bucket": int(bucket_key),
			"expanded": true,
		})
		for song_data in songs_in_group:
			grouped.append({
				"type": "song",
				"data": song_data.duplicate(true),
			})
	return grouped


func _build_play_count_grouped_data(songs_list: Array) -> Array:
	var bucket_order: Array[String] = ["10+", "<10", "0"]
	var buckets: Dictionary = {"10+": [], "<10": [], "0": []}
	for song_data in songs_list:
		if not song_data is Dictionary:
			continue
		var bucket := _play_count_bucket(_play_count_for(String(song_data.get("path", ""))))
		buckets[bucket].append(song_data)
	var grouped: Array = []
	for bucket in bucket_order:
		var songs_in_group: Array = buckets.get(bucket, [])
		if songs_in_group.is_empty():
			continue
		songs_in_group = _sort_songs_by_play_count(songs_in_group)
		grouped.append({
			"type": "header",
			"text": _group_header_text(songs_in_group.size(), _play_count_bucket_label(bucket)),
			"expanded": true,
		})
		for song_data in songs_in_group:
			grouped.append({
				"type": "song",
				"data": song_data.duplicate(true),
			})
	return grouped


func _duration_seconds_for(song_data: Dictionary) -> float:
	if not song_data is Dictionary:
		return 0.0
	var path := String(song_data.get("path", ""))
	var dur_value: Variant = song_data.get("duration", "")
	if _SS.is_missing_metadata_value(dur_value) and path != "":
		dur_value = SongLibrary.get_metadata_for_song(path).get("duration", "")
	return ChartDifficultyAnalyzer.parse_duration_seconds(dur_value)


func _duration_minute_bucket(song_data: Dictionary) -> int:
	var seconds := _duration_seconds_for(song_data)
	if seconds <= 0.0:
		return -1
	if seconds < 60.0:
		return 0
	return int(ceil(seconds / 60.0))


func _duration_bucket_label(bucket: int) -> String:
	match bucket:
		-1:
			return _SS._translate("SONG_GROUP_DURATION_UNKNOWN")
		0:
			return _SS._translate("SONG_GROUP_DURATION_UNDER_1")
		1:
			return _SS._translate("SONG_GROUP_DURATION_1_MIN")
		_:
			return _SS._translate("SONG_GROUP_DURATION_N_MIN") % bucket


func _build_duration_grouped_data(songs_list: Array) -> Array:
	var buckets: Dictionary = {}
	for song_data in songs_list:
		if not song_data is Dictionary:
			continue
		var bucket := _duration_minute_bucket(song_data)
		if not buckets.has(bucket):
			buckets[bucket] = []
		buckets[bucket].append(song_data)
	var keys: Array = buckets.keys()
	keys.sort_custom(func(a, b):
		var ai := int(a)
		var bi := int(b)
		if ai < 0:
			return false
		if bi < 0:
			return true
		if ai != bi:
			return ai > bi
		return false
	)
	var grouped: Array = []
	for bucket_key in keys:
		var songs_in_group: Array = _sort_songs_by_duration_desc(buckets[bucket_key])
		if songs_in_group.is_empty():
			continue
		grouped.append({
			"type": "header",
			"text": _group_header_text(songs_in_group.size(), _duration_bucket_label(int(bucket_key))),
			"duration_bucket": int(bucket_key),
			"expanded": true,
		})
		for song_data in songs_in_group:
			grouped.append({
				"type": "song",
				"data": song_data.duplicate(true),
			})
	return grouped


func _notes_ready_for_current_settings(song_path: String) -> bool:
	if song_path == "":
		return false
	return NotesUtils.notes_ready_for_scope(song_path, current_instrument, _chart_lookup_key(), current_lanes)


func _notes_ready_group_header(has_notes: bool, count: int) -> String:
	if has_notes:
		return _SS._translate("SONG_GROUP_NOTES_HAVE_FMT") % count
	return _SS._translate("SONG_GROUP_NOTES_MISSING_FMT") % count


func _build_notes_ready_grouped_data(songs_list: Array) -> Array:
	var buckets: Dictionary = {"yes": [], "no": []}
	for song_data in songs_list:
		if not song_data is Dictionary:
			continue
		var song_path := String(song_data.get("path", ""))
		var key := "yes" if _notes_ready_for_current_settings(song_path) else "no"
		buckets[key].append(song_data)
	var grouped: Array = []
	for bucket_key in ["yes", "no"]:
		var songs_in_group: Array = _sort_songs_by_title(buckets.get(bucket_key, []))
		if songs_in_group.is_empty():
			continue
		grouped.append({
			"type": "header",
			"text": _notes_ready_group_header(bucket_key == "yes", songs_in_group.size()),
			"notes_ready": bucket_key == "yes",
			"expanded": true,
		})
		for song_data in songs_in_group:
			var ready_bucket := _notes_ready_for_current_settings(String(song_data.get("path", "")))
			grouped.append({
				"type": "song",
				"data": song_data.duplicate(true),
				"notes_ready_bucket": ready_bucket,
			})
	return grouped

func _build_grouped_data(songs_list: Array) -> Array:
	var parts := _partition_favorites(songs_list)
	var grouped: Array
	match current_filter_mode:
		"difficulty":
			grouped = _build_difficulty_grouped_data(parts.rest)
		"play_count":
			grouped = _build_play_count_grouped_data(parts.rest)
		"notes_ready":
			grouped = _build_notes_ready_grouped_data(parts.rest)
		"duration":
			grouped = _build_duration_grouped_data(parts.rest)
		"bpm":
			grouped = _build_bpm_grouped_data(parts.rest)
		"year":
			grouped = _build_year_grouped_data(parts.rest)
		"genre_group":
			grouped = _build_genre_group_grouped_data(parts.rest)
		_:
			grouped = _build_letter_grouped_data(parts.rest)
	return _prepend_favorites_section(grouped, parts.favorites)


func _build_genre_group_grouped_data(songs_list: Array) -> Array:
	var buckets: Dictionary = {}
	for song_data in songs_list:
		if song_data is not Dictionary:
			continue
		var group_id := _ProfileGenrePortrait.resolve_song_group_id(str(song_data.get("path", "")))
		if not buckets.has(group_id):
			buckets[group_id] = []
		(buckets[group_id] as Array).append(song_data)
	var group_ids := _ProfileGenrePortrait.sorted_group_ids_for_display(buckets.keys())
	var grouped: Array = []
	for group_id in group_ids:
		var songs_in_group: Array = _sort_songs_by_title(buckets.get(group_id, []))
		if songs_in_group.is_empty():
			continue
		grouped.append({
			"type": "header",
			"text": _group_header_text(
				songs_in_group.size(),
				tr(_ProfileGenrePortrait.group_locale_key(group_id)),
			),
			"expanded": true,
		})
		for song_data in songs_in_group:
			grouped.append({
				"type": "song",
				"data": song_data.duplicate(true),
			})
	return grouped


func _partition_favorites(songs_list: Array) -> Dictionary:
	var favorites: Array = []
	var rest: Array = []
	for song_data in songs_list:
		if not song_data is Dictionary:
			continue
		var path := String(song_data.get("path", ""))
		if _is_favorite_path(path):
			favorites.append(song_data)
		else:
			rest.append(song_data)
	return {
		"favorites": _sort_songs_by_title(favorites),
		"rest": rest,
	}


func _prepend_favorites_section(grouped: Array, favorites: Array) -> Array:
	if favorites.is_empty():
		return grouped
	var out: Array = [{
		"type": "header",
		"text": _group_header_text(favorites.size(), _SS._translate("SONG_GROUP_FAVORITES")),
		"favorites_section": true,
		"expanded": true,
	}]
	for song_data in favorites:
		out.append({
			"type": "song",
			"data": song_data.duplicate(true),
		})
	return out + grouped


func _is_favorite_path(path: String) -> bool:
	if path == "":
		return false
	if PlayerDataManager and PlayerDataManager.has_method("is_song_favorite"):
		return PlayerDataManager.is_song_favorite(path)
	return false


func _favorite_star_icon() -> Texture2D:
	return _SongFavoriteIcons.active_icon()


func _build_letter_grouped_data(songs_list: Array) -> Array:
	var groups = {}
	for song_data in songs_list:
		var first_char = get_first_letter(get_filter_field_value(song_data).to_lower())
		if first_char == "":
			first_char = "?"
		if not groups.has(first_char):
			groups[first_char] = []
		groups[first_char].append(song_data)
	var sorted_letters = groups.keys()
	sorted_letters.sort()
	var grouped = []
	for letter in sorted_letters:
		var songs_in_group = groups[letter]
		var header_text = _group_header_text(songs_in_group.size(), letter.to_upper())
		grouped.append({
			"type": "header",
			"text": header_text,
			"letter": letter,
			"expanded": true
		})
		for song_data in songs_in_group:
			grouped.append({
				"type": "song",
				"data": song_data.duplicate(true)
			})
	return grouped

func _render_grouped_data():
	item_list.remove_theme_constant_override("icon_max_width")
	var difficulty_header_visuals: Dictionary = {}
	var use_difficulty_header_icons: bool = current_filter_mode == "difficulty"
	for item_data in current_grouped_data:
		if item_data.type == "header":
			var header_text: String = str(item_data.text)
			if item_data.get("favorites_section", false):
				header_text = "★ " + header_text
			var rating := int(item_data.get("difficulty_rating", -1))
			if use_difficulty_header_icons and rating > 0:
				header_text = " "
			var idx = item_list.add_item(header_text)
			item_list.set_item_selectable(idx, false)
			if use_difficulty_header_icons and rating > 0:
				item_list.set_item_custom_bg_color(idx, _LIST_ITEM_PANEL_BG)
				difficulty_header_visuals[idx] = {
					"rating": rating,
					"count": int(item_data.get("group_count", 0)),
					"color": ChartDifficultyAnalyzer.rating_color(rating),
				}
			else:
				item_list.set_item_custom_bg_color(idx, _GROUP_HEADER_BG)
			if rating > 0 and not use_difficulty_header_icons:
				item_list.set_item_custom_fg_color(idx, ChartDifficultyAnalyzer.rating_color(rating))
			elif rating == 0:
				item_list.set_item_custom_fg_color(idx, ChartDifficultyAnalyzer.rating_color(0))
			elif item_data.has("notes_ready"):
				var ready := bool(item_data.get("notes_ready", false))
				item_list.set_item_custom_fg_color(idx, Color("#61C7BD") if ready else Color(0.72, 0.8, 0.92, 1.0))
			elif item_data.get("favorites_section", false):
				item_list.set_item_custom_fg_color(idx, Color("#F2B35A"))
		else:
			var song_data = item_data.data
			var text = _format_display_text(song_data)
			if _is_favorite_path(String(song_data.get("path", ""))):
				text = "★ " + text
			var idx = item_list.add_item(text)
			_apply_song_item_visual(idx, song_data)
	if item_list is SongItemList:
		var song_list := item_list as SongItemList
		song_list.set_difficulty_header_visuals(difficulty_header_visuals)
	elif item_list.has_method("set_difficulty_header_visuals"):
		item_list.call("set_difficulty_header_visuals", difficulty_header_visuals)
	call_deferred("_update_medal_outline_indices")

func _format_display_text(song_data: Dictionary) -> String:
	var artist = str(song_data.get("artist", "")).strip_edges()
	var title = str(song_data.get("title", "")).strip_edges()
	var path = String(song_data.get("path", ""))
	var stem = path.get_file().get_basename() if path != "" else ""
	var artist_invalid = _SS.is_default_artist(artist)
	var title_invalid = _SS.is_default_title(title, stem)
	if artist_invalid and title_invalid:
		return stem
	if artist_invalid:
		return title if title != "" else stem
	if title_invalid:
		return artist
	return artist + " — " + title

func _stem_for(song_data: Dictionary) -> String:
	var path = String(song_data.get("path", ""))
	if path == "":
		return ""
	return path.get_file().get_basename()

func _effective_title(song_data: Dictionary) -> String:
	var t = str(song_data.get("title", "")).strip_edges()
	var stem = _stem_for(song_data)
	if _SS.is_default_title(t, stem):
		return stem
	return t

func _effective_artist(song_data: Dictionary) -> String:
	var a = str(song_data.get("artist", "")).strip_edges()
	if _SS.is_default_artist(a):
		return _effective_title(song_data)
	return a


func _parse_year_value(value: Variant) -> int:
	if value is int:
		return value if value >= 1900 else -1
	var s := String(value).strip_edges()
	if s == "" or s.to_lower() in ["н/д", "n/a", "unknown", "неизвестен"]:
		return -1
	if s.is_valid_int():
		var year := s.to_int()
		return year if year >= 1900 else -1
	return -1


func _year_sort_value(song_data: Dictionary) -> int:
	return _parse_year_value(song_data.get("year", ""))


func _year_sort_value_from_bucket(bucket_key: String) -> int:
	if bucket_key == "unknown":
		return -1
	if bucket_key.is_valid_int():
		return bucket_key.to_int()
	return -1


func _year_bucket_key(song_data: Dictionary) -> String:
	var year := _parse_year_value(song_data.get("year", ""))
	return str(year) if year > 0 else "unknown"


func _year_bucket_label(bucket_key: String) -> String:
	if bucket_key == "unknown":
		return _SS._translate("SONG_GROUP_YEAR_UNKNOWN")
	return bucket_key


func _effective_year(song_data: Dictionary) -> String:
	var year := _parse_year_value(song_data.get("year", ""))
	if year > 0:
		return str(year)
	return _SS._translate("SONG_GROUP_YEAR_UNKNOWN")

func _get_selected_song_path() -> String:
	var selected = item_list.get_selected_items() if item_list else []
	if selected.size() > 0:
		var si = selected[0]
		if si >= 0 and si < current_grouped_data.size():
			var prev_item = current_grouped_data[si]
			if prev_item.type == "song":
				return prev_item.data.get("path", "")
	return ""

func _reselect_previous(previous_path: String) -> void:
	if previous_path == "":
		return
	for i in range(current_grouped_data.size()):
		var it = current_grouped_data[i]
		if it.type == "song" and it.data.get("path", "") == previous_path:
			# ItemList.select() does not emit item_selected — sync details panel explicitly.
			item_list.select(i, true)
			item_list.ensure_current_is_visible()
			_on_item_selected(i)
			break


func move_selection_by_delta(delta: int) -> bool:
	if not item_list or item_list.item_count == 0 or delta == 0:
		return false
	var selected := item_list.get_selected_items()
	var idx := int(selected[0]) if selected.size() > 0 else -1
	var attempts := current_grouped_data.size()
	while attempts > 0:
		attempts -= 1
		idx += delta
		if idx < 0 or idx >= current_grouped_data.size():
			break
		var item_data = current_grouped_data[idx]
		if item_data.type == "song":
			# ItemList.select() does not emit item_selected — sync details panel explicitly.
			item_list.select(idx, true)
			item_list.ensure_current_is_visible()
			_on_item_selected(idx)
			return true
	return false

func refresh_highlight_for_current_settings():
	if not item_list:
		return
	if current_filter_mode == "notes_ready" and _notes_ready_regroup_needed():
		populate_items_grouped(true)
		return
	_refresh_song_highlights_incremental(false)


func refresh_highlights_for_paths(paths: Array, visible_only: bool = false) -> void:
	if not item_list or paths.is_empty():
		return
	var normalized: Dictionary = {}
	for raw in paths:
		var key := String(raw).replace("\\", "/")
		if key != "":
			normalized[key] = true
	if normalized.is_empty():
		return
	if current_filter_mode == "notes_ready":
		for path_key in normalized.keys():
			_invalidate_notes_ready_cache_for_path(path_key)
			if _notes_ready_bucket_changed_for_path(path_key):
				populate_items_grouped(true)
				return
	for path_key in normalized.keys():
		var idx := find_item_list_index_for_path(path_key)
		if idx < 0:
			continue
		var item_data = current_grouped_data[idx]
		if item_data.type != "song":
			continue
		if visible_only and not _is_item_index_visible(idx):
			continue
		_invalidate_notes_ready_cache_for_path(path_key)
		_apply_song_item_visual(idx, item_data.data)


func _refresh_song_highlights_incremental(visible_only: bool) -> void:
	for i in range(current_grouped_data.size()):
		var item_data = current_grouped_data[i]
		if item_data.type != "song":
			continue
		if visible_only and not _is_item_index_visible(i):
			continue
		_apply_song_item_visual(i, item_data.data)


func _is_item_index_visible(index: int) -> bool:
	if not item_list or index < 0 or index >= item_list.item_count:
		return false
	if item_list is SongItemList:
		return (item_list as SongItemList).is_item_visible(index)
	return true


func _notes_ready_bucket_changed_for_path(song_path: String) -> bool:
	var idx := find_item_list_index_for_path(song_path)
	if idx < 0:
		return false
	var item_data = current_grouped_data[idx]
	if item_data.type != "song":
		return false
	var old_bucket := bool(item_data.get("notes_ready_bucket", _song_ready_for_current_settings(item_data.data)))
	var new_bucket := _song_ready_for_current_settings(item_data.data)
	return old_bucket != new_bucket


func _notes_ready_regroup_needed() -> bool:
	for item_data in current_grouped_data:
		if item_data.type != "song":
			continue
		var song_path := String(item_data.data.get("path", ""))
		if song_path == "":
			continue
		var cached_bucket: Variant = item_data.get("notes_ready_bucket", null)
		if cached_bucket == null:
			return true
		if bool(cached_bucket) != _song_ready_for_current_settings(item_data.data):
			return true
	return false

func _has_unseen_medals(song_path: String) -> bool:
	if song_path == "" or not _unseen_medals_loader.is_valid():
		return false
	var unseen = _unseen_medals_loader.call(song_path)
	return unseen is Array and not unseen.is_empty()

func _apply_song_item_visual(idx: int, song_data: Dictionary) -> void:
	if not item_list or idx < 0:
		return
	var song_path := String(song_data.get("path", ""))
	var display_text := _format_display_text(song_data)
	if _is_favorite_path(song_path):
		display_text = "★ " + display_text
	item_list.set_item_text(idx, display_text)
	if _song_ready_for_current_settings(song_data):
		item_list.set_item_custom_fg_color(idx, Color("#61C7BD"))
	else:
		item_list.set_item_custom_fg_color(idx, Color.WHITE)
	if idx < current_grouped_data.size():
		var item_entry = current_grouped_data[idx]
		if item_entry.type == "song":
			item_entry["notes_ready_bucket"] = _song_ready_for_current_settings(song_data)

func _remove_legacy_medal_overlay() -> void:
	if not item_list:
		return
	var legacy := item_list.get_node_or_null("UnseenMedalOutlineOverlay")
	if legacy:
		legacy.queue_free()


func _update_medal_outline_indices() -> void:
	if not item_list:
		return
	var indices := PackedInt32Array()
	var count := mini(item_list.item_count, current_grouped_data.size())
	for i in range(count):
		if current_grouped_data[i].type != "song":
			continue
		if _has_unseen_medals(String(current_grouped_data[i].data.get("path", ""))):
			indices.append(i)
	if item_list is SongItemList:
		(item_list as SongItemList).set_medal_outline_indices(indices)
	elif item_list.has_method("set_medal_outline_indices"):
		item_list.call("set_medal_outline_indices", indices)

func _song_has_valid_bpm(song_data: Dictionary) -> bool:
	var path := String(song_data.get("path", ""))
	var bpm = song_data.get("bpm", "")
	if _SS.is_missing_metadata_value(bpm) and path != "":
		bpm = SongLibrary.get_metadata_for_song(path).get("bpm", "")
	return not _SS.is_missing_metadata_value(bpm)


func _song_ready_for_current_settings(song_data: Dictionary) -> bool:
	var song_path := String(song_data.get("path", ""))
	if song_path == "":
		return false
	if not _song_has_valid_bpm(song_data):
		return false
	var token := _notes_ready_cache_token()
	if token != _notes_ready_cache_key:
		_notes_ready_cache.clear()
		_notes_ready_cache_key = token
	if _notes_ready_cache.has(song_path):
		return bool(_notes_ready_cache[song_path])
	var ready := NotesUtils.notes_ready_for_scope(song_path, current_instrument, _chart_lookup_key(), current_lanes)
	_notes_ready_cache[song_path] = ready
	return ready
