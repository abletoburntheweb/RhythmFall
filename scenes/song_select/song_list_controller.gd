extends Node
class_name SongListController

signal song_selected(song_data: Dictionary)
signal song_added(song_data: Dictionary)
signal song_list_changed()
signal song_edited(song_data: Dictionary, item_list_index: int)

var item_list: ItemList = null
var current_grouped_data = []
var current_filter_mode = "title"
var current_instrument: String = "drums"
var current_mode: String = "basic"
var current_lanes: int = 4

var edit_mode: bool = false
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
		item_list.item_selected.connect(_on_item_selected)

func set_filter_mode(mode: String):
	current_filter_mode = mode

func set_generation_settings(instrument: String, mode: String, lanes: int):
	current_instrument = instrument
	current_mode = mode
	current_lanes = lanes
	refresh_highlight_for_current_settings()

func populate_items():
	if not item_list:
		return
	item_list.clear()
	var songs_list = SongLibrary.get_songs_list()
	for song_data in songs_list:
		var display_text = _format_display_text(song_data)
		item_list.add_item(display_text)
	emit_signal("song_list_changed")

func populate_items_grouped():
	if not item_list:
		return
	var prev = _get_selected_song_path()
	item_list.clear()
	current_grouped_data = _build_grouped_data(_sorted_songs(SongLibrary.get_songs_list()))
	_render_grouped_data()
	emit_signal("song_list_changed")
	_reselect_previous(prev)

func update_song_count_label(count_label: Label):
	if count_label:
		var song_count = 0
		for item_data in current_grouped_data:
			if item_data.type == "song":
				song_count += 1
		count_label.text = "Песен: %d" % song_count

func add_song_from_path(file_path: String):
	var metadata_dict = SongLibrary.add_song(file_path)
	if not metadata_dict.is_empty():
		emit_signal("song_added", metadata_dict)

func _on_item_selected(index):
	if index >= 0 and index < current_grouped_data.size():
		var item_data = current_grouped_data[index]
		if item_data.type == "song":
			var selected_song_data = item_data.data
			emit_signal("song_selected", selected_song_data)

func filter_items(filter_text: String):
	if not item_list:
		return
	var prev = _get_selected_song_path()
	item_list.clear()
	var q = _normalize_search_text(filter_text)
	if q.is_empty():
		current_grouped_data = _build_grouped_data(_sorted_songs(SongLibrary.get_songs_list()))
	else:
		var filtered = []
		for song_data in SongLibrary.get_songs_list():
			var display_text = _format_display_text(song_data)
			if _normalize_search_text(display_text).find(q) != -1:
				filtered.append(song_data)
		current_grouped_data = _build_grouped_data(_sorted_songs(filtered))
	_render_grouped_data()
	emit_signal("song_list_changed")
	_reselect_previous(prev)

func group_key_to_text(letter: String) -> String:
	return letter.to_upper()

func get_first_letter(text: String) -> String:
	if text.is_empty():
		return ""
	return text.substr(0, 1).to_lower()

func get_filter_field_value(song_data: Dictionary) -> String:
	if current_filter_mode == "title":
		return _effective_title(song_data)
	else:
		return _effective_artist(song_data)

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
	return true

func set_edit_mode(enabled: bool):
	edit_mode = enabled

func is_edit_mode_active() -> bool:
	return edit_mode

func start_editing(field_type: String, song_data: Dictionary, selected_item_list_index: int):
	if not edit_mode:
		return
	_edit_context["song_data"] = song_data.duplicate(true)
	_edit_context["selected_index"] = selected_item_list_index
	_edit_context["field_name"] = field_type
	_edit_context["type"] = "field"
	match field_type:
		"title":
			_edit_title()
		"artist":
			_edit_field("artist")
		"year":
			_edit_year()
		"bpm":
			_edit_bpm()
		"primary_genre":
			_edit_primary_genre()
		"cover":
			_edit_cover_stub()
		_:
			pass

func _edit_primary_genre():
	var song_data = _edit_context["song_data"]
	var old_genre = song_data.get("primary_genre", "")
	_edit_context["type"] = "primary_genre"
	var dlg_scene = load("res://scenes/song_select/genre_picker_dialog.tscn")
	if dlg_scene:
		var dlg = dlg_scene.instantiate()
		_edit_context["dialog"] = dlg
		if dlg.has_method("set_initial"):
			dlg.set_initial(old_genre)
		dlg.genre_selected.connect(_on_genre_selected_from_picker)
		if get_parent():
			get_parent().add_child(dlg)
		else:
			add_child(dlg)

func _edit_year():
	var song_data = _edit_context["song_data"]
	var old_year = song_data.get("year", "Н/Д")
	var old_year_int = -1
	if old_year is int:
		old_year_int = old_year
	elif old_year is String and old_year.is_valid_int():
		old_year_int = old_year.to_int()
	_edit_context["type"] = "year"
	var dialog = AcceptDialog.new()
	dialog.title = "Редактировать год"
	dialog.dialog_text = "Введите год выпуска:"
	var spin_box = SpinBox.new()
	var current_year = Time.get_datetime_dict_from_system()["year"]
	spin_box.set_min(1900)
	spin_box.set_max(current_year)
	spin_box.set_step(1)
	var desired_year = old_year_int if old_year_int != -1 else current_year
	if desired_year < 1900:
		desired_year = 1900
	if desired_year > current_year:
		desired_year = current_year
	spin_box.value = desired_year
	spin_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit_context["spin_box"] = spin_box
	var vbox_container = VBoxContainer.new()
	vbox_container.add_child(spin_box)
	dialog.add_child(vbox_container)
	dialog.confirmed.connect(_on_edit_year_confirmed)
	dialog.close_requested.connect(_on_dialog_closed)
	_edit_context["dialog"] = dialog
	if get_parent():
		get_parent().add_child(dialog)
	else:
		add_child(dialog)
	dialog.popup_centered()

func _on_edit_year_confirmed():
	var dialog = _edit_context["dialog"]
	var spin_box = _edit_context["spin_box"]
	var song_data = _edit_context["song_data"]
	var selected_item_list_index = _edit_context["selected_index"]
	var old_year = song_data.get("year", "Н/Д")
	var old_year_int = -1
	if old_year is int:
		old_year_int = old_year
	elif old_year is String and old_year.is_valid_int():
		old_year_int = old_year.to_int()
	if dialog and spin_box:
		var new_year_int = int(spin_box.value)
		if new_year_int != old_year_int:
			var new_year_str = str(new_year_int)
			song_data["year"] = new_year_str
			var song_file_path = song_data["path"]
			var fields_to_update = {"year": new_year_str}
			SongLibrary.update_metadata(song_file_path, fields_to_update)
			emit_signal("song_edited", song_data, selected_item_list_index)
	_cleanup_edit_context()

func _edit_title():
	var song_data = _edit_context["song_data"]
	var old_title = song_data.get("title", "")
	_edit_context["type"] = "title"
	var dialog = AcceptDialog.new()
	dialog.title = "Редактировать название"
	dialog.dialog_text = "Введите новое название:"
	var line_edit = LineEdit.new()
	line_edit.text = old_title
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit_context["line_edit"] = line_edit
	var vbox_container = VBoxContainer.new()
	vbox_container.add_child(line_edit)
	dialog.add_child(vbox_container)
	dialog.confirmed.connect(_on_edit_title_confirmed)
	dialog.close_requested.connect(_on_dialog_closed)
	_edit_context["dialog"] = dialog
	if get_parent():
		get_parent().add_child(dialog)
	else:
		add_child(dialog)
	dialog.popup_centered()

func _edit_field(field_name: String):
	var song_data = _edit_context["song_data"]
	var old_value = str(song_data.get(field_name, ""))
	_edit_context["type"] = "field"
	var dialog = AcceptDialog.new()
	var rus_name = field_name
	if field_name == "artist":
		rus_name = "Исполнитель"
	elif field_name == "year":
		rus_name = "Год"
	dialog.title = "Редактировать " + rus_name
	dialog.dialog_text = "Введите новое значение для \"" + rus_name + "\":"
	var line_edit = LineEdit.new()
	line_edit.text = old_value
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit_context["line_edit"] = line_edit
	var vbox_container = VBoxContainer.new()
	vbox_container.add_child(line_edit)
	dialog.add_child(vbox_container)
	dialog.confirmed.connect(_on_edit_field_confirmed)
	dialog.close_requested.connect(_on_dialog_closed)
	_edit_context["dialog"] = dialog
	if get_parent():
		get_parent().add_child(dialog)
	else:
		add_child(dialog)
	dialog.popup_centered()

func _edit_bpm():
	var song_data = _edit_context["song_data"]
	var old_bpm = song_data.get("bpm", "Н/Д")
	var old_bpm_int = -1
	if old_bpm is int:
		old_bpm_int = old_bpm
	elif old_bpm is String and old_bpm.is_valid_int():
		old_bpm_int = old_bpm.to_int()
	_edit_context["type"] = "bpm"
	var dialog = AcceptDialog.new()
	dialog.title = "Редактировать BPM"
	dialog.dialog_text = "Введите новый BPM (пусто — очистить; минимум 90):"
	var line_edit = LineEdit.new()
	line_edit.text = str(old_bpm_int) if old_bpm_int != -1 else ""
	line_edit.placeholder_text = "Например: 120"
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit_context["line_edit"] = line_edit
	var vbox_container = VBoxContainer.new()
	vbox_container.add_child(line_edit)
	dialog.add_child(vbox_container)
	dialog.confirmed.connect(_on_edit_bpm_confirmed)
	dialog.close_requested.connect(_on_dialog_closed)
	_edit_context["dialog"] = dialog
	if get_parent():
		get_parent().add_child(dialog)
	else:
		add_child(dialog)
	dialog.popup_centered()

func _edit_cover_stub():
	pass

func _on_edit_title_confirmed():
	var dialog = _edit_context["dialog"]
	var line_edit = _edit_context["line_edit"]
	var song_data = _edit_context["song_data"]
	var selected_item_list_index = _edit_context["selected_index"]
	var old_title = song_data.get("title", "")
	if dialog and line_edit:
		var new_title = line_edit.text.strip_edges()
		if new_title != "" and new_title != old_title:
			song_data["title"] = new_title
			var song_file_path = song_data["path"]
			var fields_to_update = {"title": new_title}
			SongLibrary.update_metadata(song_file_path, fields_to_update)
			emit_signal("song_edited", song_data, selected_item_list_index)
	_cleanup_edit_context()

func _on_edit_field_confirmed():
	var dialog = _edit_context["dialog"]
	var line_edit = _edit_context["line_edit"]
	var song_data = _edit_context["song_data"]
	var selected_item_list_index = _edit_context["selected_index"]
	var field_name = _edit_context["field_name"]
	var old_value = str(song_data.get(field_name, ""))
	if dialog and line_edit and song_data and field_name:
		var new_value = line_edit.text.strip_edges()
		if new_value != old_value:
			song_data[field_name] = new_value
			var song_file_path = song_data["path"]
			var fields_to_update = {field_name: new_value}
			SongLibrary.update_metadata(song_file_path, fields_to_update)
			emit_signal("song_edited", song_data, selected_item_list_index)
	_cleanup_edit_context()


func _on_genre_selected_from_picker(primary_genre: String, all_genres: Array):
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
	var fields_to_update = {"primary_genre": primary_genre}
	if primary_genre == "unknown":
		fields_to_update["genres"] = []
	elif all_genres and all_genres is Array and all_genres.size() > 0:
		fields_to_update["genres"] = all_genres
	SongLibrary.update_metadata(song_file_path, fields_to_update)
	var persisted = SongLibrary.get_metadata_for_song(song_file_path)
	if persisted.is_empty():
		song_data["primary_genre"] = primary_genre
		if all_genres and all_genres is Array and all_genres.size() > 0:
			song_data["genres"] = all_genres
		emit_signal("song_edited", song_data, selected_item_list_index)
	else:
		emit_signal("song_edited", persisted, selected_item_list_index)
	_cleanup_edit_context()

func _on_edit_bpm_confirmed():
	var dialog = _edit_context["dialog"]
	var line_edit = _edit_context["line_edit"]
	var song_data = _edit_context["song_data"]
	var selected_item_list_index = _edit_context["selected_index"]
	var old_bpm = song_data.get("bpm", "Н/Д")
	var old_bpm_int = -1
	if old_bpm is int:
		old_bpm_int = old_bpm
	elif old_bpm is String and old_bpm.is_valid_int():
		old_bpm_int = old_bpm.to_int()
	if dialog and line_edit:
		var text: String = String(line_edit.text).strip_edges()
		var song_file_path = song_data.get("path", "")
		if text == "":
			if old_bpm != "Н/Д":
				song_data["bpm"] = "Н/Д"
				SongLibrary.update_metadata(song_file_path, {"bpm": "Н/Д"})
				emit_signal("song_edited", song_data, selected_item_list_index)
		elif text.is_valid_int():
			var new_bpm_int = int(text)
			if new_bpm_int < 90:
				new_bpm_int = 90
			if new_bpm_int != old_bpm_int:
				var new_bpm_str = str(new_bpm_int)
				song_data["bpm"] = new_bpm_str
				SongLibrary.update_metadata(song_file_path, {"bpm": new_bpm_str})
				emit_signal("song_edited", song_data, selected_item_list_index)
	_cleanup_edit_context()

func _cleanup_edit_context():
	if _edit_context["dialog"] and is_instance_valid(_edit_context["dialog"]):
		_edit_context["dialog"].queue_free()
		_edit_context["dialog"] = null
		_edit_context["line_edit"] = null
		_edit_context["spin_box"] = null
		_edit_context["song_data"] = null
		_edit_context["field_name"] = null
		_edit_context["selected_index"] = -1
		_edit_context["type"] = ""

func _on_dialog_closed():
	_cleanup_edit_context()

func _sorted_songs(songs_list: Array) -> Array:
	var arr = songs_list.duplicate()
	if current_filter_mode == "title":
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
	else:
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
	return arr

func _build_grouped_data(songs_list: Array) -> Array:
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
		var header_text = "%d %s" % [songs_in_group.size(), letter.to_upper()]
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
	for item_data in current_grouped_data:
		if item_data.type == "header":
			var idx = item_list.add_item(item_data.text)
			item_list.set_item_custom_bg_color(idx, Color(0.2, 0.2, 0.2, 1.0))
			item_list.set_item_selectable(idx, false)
		else:
			var song_data = item_data.data
			var text = _format_display_text(song_data)
			var idx = item_list.add_item(text)
			var song_path = String(song_data.get("path", ""))
			if _notes_exist_for(song_path, current_instrument, current_mode, current_lanes):
				item_list.set_item_custom_fg_color(idx, Color("#61C7BD"))

func _format_display_text(song_data: Dictionary) -> String:
	var artist = str(song_data.get("artist", "")).strip_edges()
	var title = str(song_data.get("title", "")).strip_edges()
	var path = String(song_data.get("path", ""))
	var stem = path.get_file().get_basename() if path != "" else ""
	var artist_invalid = (artist == "" or artist == "Неизвестен")
	var title_invalid = (title == "" or title == "Без названия" or title == stem)
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
	if t == "" or t == "Без названия" or t == stem:
		return stem
	return t

func _effective_artist(song_data: Dictionary) -> String:
	var a = str(song_data.get("artist", "")).strip_edges()
	if a == "" or a == "Неизвестен":
		return _effective_title(song_data)
	return a
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
			item_list.select(i, true)
			break

func refresh_highlight_for_current_settings():
	if not item_list:
		return
	for i in range(current_grouped_data.size()):
		var item_data = current_grouped_data[i]
		if item_data.type == "song":
			var song_path = String(item_data.data.get("path", ""))
			if _notes_exist_for(song_path, current_instrument, current_mode, current_lanes):
				item_list.set_item_custom_fg_color(i, Color("#61C7BD"))
			else:
				item_list.set_item_custom_fg_color(i, Color.WHITE)

func _notes_exist_for(song_path: String, instrument: String, mode: String, lanes: int) -> bool:
	if song_path == "":
		return false
	return NotesUtils.notes_exist(song_path, instrument, mode, lanes)
