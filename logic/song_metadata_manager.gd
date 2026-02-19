# logic/song_metadata_manager.gd
extends Node

signal metadata_updated(song_file_path: String)

const METADATA_FILE_PATH = "user://song_metadata.json"

var _metadata_cache: Dictionary = {}

func _init():
	_load_metadata()

func get_metadata_for_song(song_file_path: String) -> Dictionary:	
	if _metadata_cache.has(song_file_path):
		var result = _metadata_cache[song_file_path].duplicate(true)
		return result
	else:
		return {}

func update_metadata(song_file_path: String, updated_fields: Dictionary):
	if not _metadata_cache.has(song_file_path):
		_metadata_cache[song_file_path] = {
			"path": song_file_path,
			"title": "Без названия",
			"artist": "Неизвестен",
			"bpm": "Н/Д",
			"year": "Н/Д",
			"duration": "00:00",
			"cover": null,
			"genres": "",
			"primary_genre": "unknown"
		}

	if not _metadata_cache.has(song_file_path):
		_metadata_cache[song_file_path]["file_mtime"] = int(FileAccess.get_modified_time(song_file_path))

	if updated_fields.has("genres") and typeof(updated_fields["genres"]) == TYPE_ARRAY:
		var genres_array = updated_fields["genres"]
		var genres_str = ", ".join(genres_array)
		_metadata_cache[song_file_path]["genres"] = genres_str

		if !genres_array.is_empty():
			_metadata_cache[song_file_path]["primary_genre"] = str(genres_array[0])
		else:
			_metadata_cache[song_file_path]["primary_genre"] = "unknown"

		updated_fields = updated_fields.duplicate()
		updated_fields.erase("genres")

	for field_name in updated_fields:
		if field_name != "cover":
			_metadata_cache[song_file_path][field_name] = updated_fields[field_name]

	_save_metadata()
	emit_signal("metadata_updated", song_file_path)

func remove_metadata(song_file_path: String):
	if _metadata_cache.erase(song_file_path):
		_save_metadata()
	else:
		pass

func _load_metadata():
	var file_access = FileAccess.open(METADATA_FILE_PATH, FileAccess.READ)
	if file_access:
		var json_text = file_access.get_as_text()
		file_access.close()
		var parse_result = JSON.parse_string(json_text)
		if parse_result is Dictionary:
			_metadata_cache = parse_result
			for key in _metadata_cache.keys():
				_metadata_cache[key].erase("cover")
		else:
			printerr("SongMetadataManager.gd: Ошибка парсинга JSON из %s или данные не являются словарём." % METADATA_FILE_PATH)
			_metadata_cache = {}
	else:
		_metadata_cache = {}

func _save_metadata():
	var file_access = FileAccess.open(METADATA_FILE_PATH, FileAccess.WRITE)
	if file_access:
		var cache_to_save = {}
		for path in _metadata_cache.keys():
			var song_data_copy = _metadata_cache[path].duplicate(true)
			song_data_copy.erase("cover")
			cache_to_save[path] = song_data_copy
		var json_text = JSON.stringify(cache_to_save, "\t")
		file_access.store_string(json_text)
		file_access.close()
	else:
		printerr("SongMetadataManager.gd: Ошибка открытия файла %s для записи!" % METADATA_FILE_PATH)
