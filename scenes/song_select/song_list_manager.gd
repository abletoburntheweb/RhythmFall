# scenes/song_select/song_list_manager.gd
class_name SongListManager
extends Node

signal song_selected(song_data: Dictionary)
signal song_added(song_data: Dictionary)
signal song_list_changed()

var song_manager = null
var item_list: ItemList = null

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

func update_song_count_label(count_label: Label):
	if count_label and item_list:
		var count = item_list.get_item_count()
		count_label.text = "Песен: %d" % count
		print("SongListManager.gd: Счётчик песен обновлён: %d (через ItemList)" % count)
	elif count_label:
		count_label.text = "Песен: 0"
		print("SongListManager.gd: ItemList не установлен, счётчик установлен в 0.")
	else:
		print("SongListManager.gd: Label для счётчика не передан.")

func add_song_from_path(file_path: String):
	if not song_manager:
		return

	var metadata_dict = song_manager.add_song(file_path)
	if not metadata_dict.is_empty():
		populate_items()
		emit_signal("song_added", metadata_dict)

func _on_item_selected(index):
	if song_manager:
		var songs_list = song_manager.get_songs_list()
		if index >= 0 and index < songs_list.size():
			var selected_song_data = songs_list[index]
			emit_signal("song_selected", selected_song_data) 

func filter_items(filter_text: String):
	if not item_list or not song_manager:
		return

	item_list.clear()
	var songs_list = song_manager.get_songs_list()

	for song_data in songs_list:
		var display_text = song_data.get("artist", "Неизвестен") + " — " + song_data.get("title", "Без названия")
		if filter_text.is_empty() or filter_text.to_lower() in display_text.to_lower():
			item_list.add_item(display_text)
	emit_signal("song_list_changed")
