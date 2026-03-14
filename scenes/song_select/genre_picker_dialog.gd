# scenes/song_select/genre_picker_dialog.gd
extends Control
class_name GenrePickerDialog

signal genre_selected(primary_genre: String, all_genres: Array)

@export var allow_multi: bool = false
@export var auto_close: bool = true

var _search: LineEdit = null
var _list: ItemList = null
var _all: Array = []
var _filtered: Array = []
var _grouped_data = []

func _ready():
	_search = get_node_or_null("SearchLineEdit")
	if _search == null:
		_search = get_node_or_null("Container/SearchLineEdit")
	if _search == null:
		_search = get_node_or_null("SearchBar")
	if _search == null:
		_search = get_node_or_null("Container/SearchBar")
	_list = get_node_or_null("GenreList")
	if _list == null:
		_list = get_node_or_null("Container/GenreList")
	_populate()
	if _list:
		_grouped_data = _build_grouped_data(_filtered)
		_render_grouped_data()
		_list.deselect_all()
		if allow_multi:
			_list.select_mode = ItemList.SELECT_MULTI
		else:
			_list.select_mode = ItemList.SELECT_SINGLE

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
		normalized.append(str(s).to_lower())
	var seen := {}
	var deduped: Array = []
	for s in normalized:
		if not seen.has(s):
			seen[s] = true
			deduped.append(s)
	deduped.sort()
	_all = deduped.duplicate()
	_filtered = _all.duplicate()
	if _list:
		_grouped_data = _build_grouped_data(_filtered)
		_render_grouped_data()

func _on_search_changed(text: String):
	var q = text.strip_edges().to_lower()
	if q == "":
		_filtered = _all.duplicate()
	else:
		_filtered = []
		for g in _all:
			if q in g:
				_filtered.append(g)
	if _list:
		_grouped_data = _build_grouped_data(_filtered)
		_render_grouped_data()

func _on_item_activated(index: int):
	if not _list:
		return
	var selected: Array = []
	if allow_multi:
		for i in range(_list.item_count):
			if _list.is_selected(i):
				if i >= 0 and i < _grouped_data.size():
					var it = _grouped_data[i]
					if it.has("type") and it["type"] == "genre":
						selected.append(str(it["text"]))
	else:
		if index >= 0 and index < _list.item_count:
			if index < _grouped_data.size():
				var it2 = _grouped_data[index]
				if it2.has("type") and it2["type"] == "genre":
					selected.append(str(it2["text"]))
	if selected.size() == 0:
		return
	var primary = str(selected[0])
	emit_signal("genre_selected", primary, selected)
	if auto_close:
		queue_free()

func _on_back_button_pressed():
	MusicManager.play_cancel_sound()
	queue_free()

func _on_reset_pressed():
	MusicManager.play_cancel_sound()
	emit_signal("genre_selected", "unknown", [])
	if auto_close:
		queue_free()

func _input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		_on_back_button_pressed()
		accept_event()

func set_initial(primary_genre: String):
	if not _list:
		return
	_list.deselect_all()
	var key = str(primary_genre).strip_edges().to_lower()
	for i in range(_list.item_count):
		var t = _list.get_item_text(i)
		if t == key:
			_list.select(i, true)
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

func _render_grouped_data():
	_list.clear()
	for it in _grouped_data:
		if it.has("type") and it["type"] == "header":
			var idx = _list.add_item(str(it["text"]))
			_list.set_item_custom_bg_color(idx, Color(0.2, 0.2, 0.2, 1.0))
			_list.set_item_selectable(idx, false)
		else:
			_list.add_item(str(it["text"]))
