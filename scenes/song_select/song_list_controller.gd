extends Node
class_name SongListController

signal song_selected(song_data: Dictionary)
signal song_added(song_data: Dictionary)
signal song_list_changed()
signal song_edited(song_data: Dictionary, item_list_index: int)

var item_list: ItemList = null
var current_grouped_data = []
var current_filter_mode = "title"

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

func populate_items():
	if not item_list:
		return
	item_list.clear()
	var songs_list = SongLibrary.get_songs_list()
	for song_data in songs_list:
		var display_text = song_data.get("artist", "Неизвестен") + " — " + song_data.get("title", "Без названия")
		item_list.add_item(display_text)
	emit_signal("song_list_changed")

func populate_items_grouped():
	if not item_list:
		return
	var previous_path = ""
	var selected_indices = item_list.get_selected_items() if item_list else []
	if selected_indices.size() > 0:
		var si = selected_indices[0]
		if si >= 0 and si < current_grouped_data.size():
			var prev_item = current_grouped_data[si]
			if prev_item.type == "song":
				previous_path = prev_item.data.get("path", "")
	item_list.clear()
	current_grouped_data.clear()
	var songs_list = SongLibrary.get_songs_list()
	if songs_list.is_empty():
		emit_signal("song_list_changed")
		return
	if current_filter_mode == "title":
		songs_list.sort_custom(func(a, b):
			var title_a = a.get("title", "").to_lower()
			var title_b = b.get("title", "").to_lower()
			return title_a < title_b
		)
	else:
		songs_list.sort_custom(func(a, b):
			var artist_a = a.get("artist", "").to_lower()
			var artist_b = b.get("artist", "").to_lower()
			return artist_a < artist_b
		)
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
	for letter in sorted_letters:
		var songs_in_group = groups[letter]
		var header_text = "%d %s" % [songs_in_group.size(), letter.to_upper()]
		current_grouped_data.append({
			"type": "header",
			"text": header_text,
			"letter": letter,
			"expanded": true
		})
		for song_data in songs_in_group:
			current_grouped_data.append({
				"type": "song",
				"data": song_data.duplicate(true)
			})
	for item_data in current_grouped_data:
		if item_data.type == "header":
			var display_text = item_data.text
			var item_index = item_list.add_item(display_text)
			item_list.set_item_custom_bg_color(item_index, Color(0.2, 0.2, 0.2, 1.0))
			item_list.set_item_selectable(item_index, false)
		else:
			var song_data = item_data.data
			var display_text = song_data.get("artist", "Неизвестен") + " — " + song_data.get("title", "Без названия")
			item_list.add_item(display_text)
	emit_signal("song_list_changed")
	if previous_path != "":
		for i in range(current_grouped_data.size()):
			var it = current_grouped_data[i]
			if it.type == "song" and it.data.get("path", "") == previous_path:
				item_list.select(i, true)
				break

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
	var previous_path = ""
	var selected_indices = item_list.get_selected_items() if item_list else []
	if selected_indices.size() > 0:
		var si = selected_indices[0]
		if si >= 0 and si < current_grouped_data.size():
			var prev_item = current_grouped_data[si]
			if prev_item.type == "song":
				previous_path = prev_item.data.get("path", "")
	item_list.clear()
	current_grouped_data.clear()
	var songs_list = SongLibrary.get_songs_list()
	if filter_text.is_empty():
		populate_items_grouped()
		return
	var filtered_songs = []
	for song_data in songs_list:
		var display_text = song_data.get("artist", "Неизвестен") + " — " + song_data.get("title", "Без названия")
		if filter_text.to_lower() in display_text.to_lower():
			filtered_songs.append(song_data)
	if current_filter_mode == "title":
		filtered_songs.sort_custom(func(a, b):
			var title_a = a.get("title", "").to_lower()
			var title_b = b.get("title", "").to_lower()
			return title_a < title_b
		)
	else:
		filtered_songs.sort_custom(func(a, b):
			var artist_a = a.get("artist", "").to_lower()
			var artist_b = b.get("artist", "").to_lower()
			return artist_a < artist_b
		)
	var groups = {}
	for song_data in filtered_songs:
		var first_char = get_first_letter(get_filter_field_value(song_data).to_lower())
		if first_char == "":
			first_char = "?"
		if not groups.has(first_char):
			groups[first_char] = []
		groups[first_char].append(song_data)
	var sorted_letters = groups.keys()
	sorted_letters.sort()
	for letter in sorted_letters:
		var songs_in_group = groups[letter]
		var header_text = "%d %s" % [songs_in_group.size(), group_key_to_text(letter)]
		current_grouped_data.append({
			"type": "header",
			"text": "%d %s" % [songs_in_group.size(), letter.to_upper()],
			"letter": letter,
			"expanded": true
		})
		for song_data in songs_in_group:
			current_grouped_data.append({
				"type": "song",
				"data": song_data.duplicate(true)
			})
	for item_data in current_grouped_data:
		if item_data.type == "header":
			var display_text = item_data.text
			var item_index = item_list.add_item(display_text)
			item_list.set_item_custom_bg_color(item_index, Color(0.2, 0.2, 0.2, 1.0))
			item_list.set_item_selectable(item_index, false)
		else:
			var song_data = item_data.data
			var display_text = song_data.get("artist", "Неизвестен") + " — " + song_data.get("title", "Без названия")
			item_list.add_item(display_text)
	emit_signal("song_list_changed")
	if previous_path != "":
		for i in range(current_grouped_data.size()):
			var it = current_grouped_data[i]
			if it.type == "song" and it.data.get("path", "") == previous_path:
				item_list.select(i, true)
				break

func group_key_to_text(letter: String) -> String:
	return letter.to_upper()

func get_first_letter(text: String) -> String:
	if text.is_empty():
		return ""
	return text.substr(0, 1).to_lower()

func get_filter_field_value(song_data: Dictionary) -> String:
	if current_filter_mode == "title":
		return song_data.get("title", "")
	else:
		return song_data.get("artist", "")

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
	var display_text = new_song_data.get("artist", "Неизвестен") + " — " + new_song_data.get("title", "Без названия")
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
	var old_genre = song_data.get("primary_genre", "Н/Д")
	if old_genre == "unknown":
		old_genre = ""
	_edit_context["type"] = "primary_genre"
	var dialog = AcceptDialog.new()
	dialog.title = "Редактировать жанр"
	dialog.dialog_text = "Введите основной жанр трека (например: electronic, rap, rock):"
	var line_edit = LineEdit.new()
	line_edit.text = old_genre
	line_edit.placeholder_text = "electronic, k-pop, rock..."
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit_context["line_edit"] = line_edit
	var vbox_container = VBoxContainer.new()
	vbox_container.add_child(line_edit)
	dialog.add_child(vbox_container)
	dialog.confirmed.connect(_on_edit_primary_genre_confirmed)
	dialog.close_requested.connect(_on_dialog_closed)
	_edit_context["dialog"] = dialog
	if get_parent():
		get_parent().add_child(dialog)
	else:
		add_child(dialog)
	dialog.popup_centered()

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
	dialog.dialog_text = "Введите новый BPM (60-200):"
	var spin_box = SpinBox.new()
	spin_box.set_min(60)
	spin_box.set_max(200)
	spin_box.set_step(1)
	spin_box.value = old_bpm_int if old_bpm_int != -1 else 120
	spin_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit_context["spin_box"] = spin_box
	var vbox_container = VBoxContainer.new()
	vbox_container.add_child(spin_box)
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

func _on_edit_primary_genre_confirmed():
	var dialog = _edit_context["dialog"]
	var line_edit = _edit_context["line_edit"]
	var song_data = _edit_context["song_data"]
	var selected_item_list_index = _edit_context["selected_index"]
	var old_genre = song_data.get("primary_genre", "unknown")
	if dialog and line_edit:
		var new_genre = line_edit.text.strip_edges().to_lower()
		if new_genre == "":
			new_genre = "unknown"
		if new_genre != old_genre:
			song_data["primary_genre"] = new_genre
			var song_file_path = song_data["path"]
			var fields_to_update = {"primary_genre": new_genre}
			SongLibrary.update_metadata(song_file_path, fields_to_update)
			emit_signal("song_edited", song_data, selected_item_list_index)
	_cleanup_edit_context()

func _on_edit_bpm_confirmed():
	var dialog = _edit_context["dialog"]
	var spin_box = _edit_context["spin_box"]
	var song_data = _edit_context["song_data"]
	var selected_item_list_index = _edit_context["selected_index"]
	var old_bpm = song_data.get("bpm", "Н/Д")
	var old_bpm_int = -1
	if old_bpm is int:
		old_bpm_int = old_bpm
	elif old_bpm is String and old_bpm.is_valid_int():
		old_bpm_int = old_bpm.to_int()
	if dialog and spin_box:
		var new_bpm_int = int(spin_box.value)
		if new_bpm_int != old_bpm_int:
			var new_bpm_str = str(new_bpm_int)
			song_data["bpm"] = new_bpm_str
			var song_file_path = song_data["path"]
			var fields_to_update = {"bpm": new_bpm_str}
			SongLibrary.update_metadata(song_file_path, fields_to_update)
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
