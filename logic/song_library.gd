# logic/song_library.gd
extends Node

signal metadata_updated(song_file_path: String)

const SONG_FOLDER_PATH = "res://songs/"
const METADATA_FILE_PATH = "user://song_metadata.json"

var songs: Array[Dictionary] = []
var _metadata_cache: Dictionary = {}

func _init():
	_load_metadata()

func _ready():
	_create_directories_if_missing()

func _create_directories_if_missing():
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("songs"):
		dir.make_dir("songs")

func read_metadata(filepath: String) -> Dictionary:
	var metadata = {
		"path": filepath,
		"title": filepath.get_file().get_basename(),
		"artist": "Неизвестен",
		"cover": null,
		"bpm": "Н/Д",
		"year": "Н/Д",
		"duration": "00:00",
		"file_mtime": FileAccess.get_modified_time(filepath)
	}
	var global_path = ProjectSettings.globalize_path(filepath)
	if FileAccess.file_exists(global_path):
		var file_access = FileAccess.open(global_path, FileAccess.READ)
		if file_access:
			var file_data = file_access.get_buffer(file_access.get_length())
			file_access.close()
			var metadata_instance = MusicMetadata.new()
			metadata_instance.set_from_data(file_data)
			if metadata_instance.title != "":
				metadata["title"] = metadata_instance.title
			if metadata_instance.artist != "":
				metadata["artist"] = metadata_instance.artist
			if metadata_instance.year != 0:
				metadata["year"] = str(metadata_instance.year)
			metadata["cover"] = metadata_instance.cover
	var audio_stream = ResourceLoader.load(filepath, "", ResourceLoader.CACHE_MODE_IGNORE)
	if audio_stream and audio_stream is AudioStream:
		var duration_seconds = audio_stream.get_length()
		if duration_seconds > 0:
			var minutes = int(duration_seconds) / 60
			var seconds = int(duration_seconds) % 60
			metadata["duration"] = "%02d:%02d" % [minutes, seconds]
	var filename_stem = filepath.get_file().get_basename()
	if metadata["title"] == filename_stem:
		if " - " in filename_stem:
			var parts = filename_stem.split(" - ", false, 1)
			if parts.size() == 2:
				metadata["artist"] = parts[0].strip_edges()
				metadata["title"] = parts[1].strip_edges()
	var user_metadata = get_metadata_for_song(filepath)
	if not user_metadata.is_empty():
		for key in user_metadata.keys():
			if metadata.has(key):
				metadata[key] = user_metadata[key]
	return metadata

func load_songs():
	songs.clear()
	var dir = DirAccess.open(SONG_FOLDER_PATH)
	if not dir:
		printerr("SongLibrary.gd: Ошибка открытия папки: " + SONG_FOLDER_PATH)
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var file_lower = file_name.to_lower()
			if file_lower.ends_with(".mp3") or file_lower.ends_with(".wav"):
				var path = SONG_FOLDER_PATH + file_name
				var metadata = read_metadata(path)
				var cached_metadata = get_metadata_for_song(path)
				if cached_metadata.is_empty():
					var fields_to_save = {
						"title": metadata.get("title", "Без названия"),
						"artist": metadata.get("artist", "Неизвестен"),
						"bpm": metadata.get("bpm", "Н/Д"),
						"year": metadata.get("year", "Н/Д"),
						"duration": metadata.get("duration", "00:00")
					}
					update_metadata(path, fields_to_save)
				songs.append(metadata)
		file_name = dir.get_next()
	dir.list_dir_end()

func add_song(file_path: String) -> Dictionary:
	var file_extension = file_path.get_extension().to_lower()
	if not (file_path.ends_with(".mp3") or file_path.ends_with(".wav")):
		printerr("SongLibrary.gd: Неподдерживаемый формат файла: " + file_extension)
		return {}
	var dest_path = SONG_FOLDER_PATH + file_path.get_file()
	var base_dir = DirAccess.open("res://")
	if not base_dir:
		printerr("SongLibrary.gd: Ошибка открытия корневой директории проекта.")
		return {}
	var copy_result = base_dir.copy(file_path, dest_path)
	if copy_result != OK:
		printerr("SongLibrary.gd: Ошибка копирования файла: " + file_path + " -> " + dest_path)
		return {}
	var metadata = read_metadata(dest_path)
	songs.append(metadata)
	var fields_to_save = {
		"title": metadata.get("title", "Без названия"),
		"artist": metadata.get("artist", "Неизвестен"),
		"bpm": metadata.get("bpm", "Н/Д"),
		"year": metadata.get("year", "Н/Д"),
		"duration": metadata.get("duration", "00:00"),
		"cover": metadata.get("cover", null)
	}
	update_metadata(dest_path, fields_to_save)
	return metadata

func get_songs_list() -> Array[Dictionary]:
	return songs.duplicate(true)

func get_song_count() -> int:
	return songs.size()

func get_metadata_for_song(song_file_path: String) -> Dictionary:
	if _metadata_cache.has(song_file_path):
		return _metadata_cache[song_file_path].duplicate(true)
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
	_update_song_in_list(song_file_path)
	emit_signal("metadata_updated", song_file_path)

func remove_metadata(song_file_path: String):
	if _metadata_cache.erase(song_file_path):
		_save_metadata()
	_update_song_in_list(song_file_path)

func _update_song_in_list(song_file_path: String):
	var index = -1
	for i in range(songs.size()):
		if songs[i]["path"] == song_file_path:
			index = i
			break
	if index != -1:
		var user_metadata = get_metadata_for_song(song_file_path)
		for key in user_metadata.keys():
			if key == "cover":
				continue
			elif key == "duration":
				if user_metadata[key] != "Н/Д":
					songs[index][key] = user_metadata[key]
			elif key == "bpm":
				var bpm_value = user_metadata[key]
				if bpm_value != "Н/Д":
					if bpm_value is String:
						if bpm_value.is_valid_int() and bpm_value.to_int() != 0:
							songs[index][key] = bpm_value
					elif bpm_value is int:
						if bpm_value != 0:
							songs[index][key] = bpm_value
			else:
				songs[index][key] = user_metadata[key]
 
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
			printerr("SongLibrary.gd: Ошибка парсинга JSON из %s или данные не являются словарём." % METADATA_FILE_PATH)
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
		printerr("SongLibrary.gd: Ошибка открытия файла %s для записи!" % METADATA_FILE_PATH)
