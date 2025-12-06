# scenes/song_select/song_list_manager.gd
class_name SongListManager
extends Node

signal song_selected(song_data: Dictionary)
signal song_added(song_data: Dictionary)
signal song_list_changed()

var song_manager = null
var item_list: ItemList = null
var current_grouped_data = [] 

func set_song_manager(manager):
	song_manager = manager

func set_item_list(list_control: ItemList):
	item_list = list_control
	if item_list:
		item_list.item_selected.connect(_on_item_selected)

func populate_items():
	if not item_list or not song_manager:
		print("SongListManager: item_list или song_manager не установлены!")
		return

	item_list.clear()
	var songs_list = song_manager.get_songs_list()

	for song_data in songs_list:
		var display_text = song_data.get("artist", "Неизвестен") + " — " + song_data.get("title", "Без названия")
		item_list.add_item(display_text)
	emit_signal("song_list_changed")

func populate_items_grouped():
	if not item_list or not song_manager:
		print("SongListManager: item_list или song_manager не установлены!")
		return

	item_list.clear()
	current_grouped_data.clear()

	var songs_list = song_manager.get_songs_list()
	if songs_list.is_empty():
		emit_signal("song_list_changed")
		return

	songs_list.sort_custom(func(a, b):
		var title_a = a.get("title", "").to_lower()
		var title_b = b.get("title", "").to_lower()
		return title_a < title_b
	)

	var groups = {}
	for song_data in songs_list:
		var first_char = get_first_letter(song_data.get("title", ""))
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
				"data": song_data.duplicate(true) # <-- Добавить .duplicate(true)
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
			var item_index = item_list.add_item(display_text)

	emit_signal("song_list_changed")

func update_song_count_label(count_label: Label):
	if count_label:
		var song_count = 0
		for item_data in current_grouped_data:
			if item_data.type == "song":
				song_count += 1
		
		count_label.text = "Песен: %d" % song_count
		print("SongListManager.gd: Счётчик песен обновлён: %d (только песни)" % song_count)
	else:
		print("SongListManager.gd: Label для счётчика не передан.")

func add_song_from_path(file_path: String):
	if not song_manager:
		return

	var metadata_dict = song_manager.add_song(file_path)
	if not metadata_dict.is_empty():
		emit_signal("song_added", metadata_dict)

func _on_item_selected(index):
	if song_manager and index >= 0 and index < current_grouped_data.size():
		var item_data = current_grouped_data[index]
		if item_data.type == "song": 
			var selected_song_data = item_data.data
			emit_signal("song_selected", selected_song_data)

func filter_items(filter_text: String):
	if not item_list or not song_manager:
		return

	item_list.clear()
	current_grouped_data.clear()

	var songs_list = song_manager.get_songs_list()

	if filter_text.is_empty():
		populate_items_grouped()
		return

	var filtered_songs = []
	for song_data in songs_list:
		var display_text = song_data.get("artist", "Неизвестен") + " — " + song_data.get("title", "Без названия")
		if filter_text.to_lower() in display_text.to_lower():
			filtered_songs.append(song_data)

	var groups = {}
	for song_data in filtered_songs:
		var first_char = get_first_letter(song_data.get("title", ""))
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
				"data": song_data.duplicate(true) # <-- Добавить .duplicate(true)
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
			var item_index = item_list.add_item(display_text)

	emit_signal("song_list_changed")

func get_first_letter(text: String) -> String:
	if text.is_empty():
		return ""
	var first_char = text.substr(0, 1)
	return first_char

# --- Новый метод для получения данных песни по индексу в ItemList ---
func get_song_data_by_item_list_index(item_list_index: int) -> Dictionary:
	# Проверяем, что индекс валиден и указывает на элемент типа "song"
	if item_list_index >= 0 and item_list_index < current_grouped_data.size():
		var item_data = current_grouped_data[item_list_index]
		if item_data.type == "song":
			print("SongListManager.gd: Возвращаем данные песни по индексу %d: %s (путь: %s)" % [item_list_index, item_data.data.get("title", "N/A"), item_data.data.get("path", "N/A")]) # <-- Добавить
			return item_data.data.duplicate() # Возвращаем копию данных
		else:
			print("SongListManager.gd: Индекс %d указывает на заголовок, а не на песню." % item_list_index)
			return {}
	else:
		print("SongListManager.gd: Индекс %d вне диапазона current_grouped_data." % item_list_index)
		return {}
