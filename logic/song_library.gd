# logic/song_library.gd
extends Node

signal metadata_updated(song_file_path: String)
signal id3_scan_started()
signal id3_scan_finished()

const SONG_FOLDER_PATH = "res://songs/"
const METADATA_FILE_PATH = "user://song_metadata.json"

var songs: Array[Dictionary] = []
var _metadata_cache: Dictionary = {}
var _id3_thread: Thread = null
var _id3_queue: Array = []
var _id3_running: bool = false

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

	var filename_stem = filepath.get_file().get_basename()
	if str(metadata["artist"]) == "Неизвестен" or str(metadata["title"]) == filename_stem:
		if " - " in filename_stem:
			var parts = filename_stem.split(" - ", false, 1)
			if parts.size() == 2:
				var first := parts[0].strip_edges()
				var second := parts[1].strip_edges()
				metadata["title"] = first
				metadata["artist"] = second
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
				if str(metadata.get("artist", "Неизвестен")) == "Неизвестен" or str(metadata.get("title", "")) == path.get_file().get_basename():
					_id3_queue.append(path)
				songs.append(metadata)
		file_name = dir.get_next()
	dir.list_dir_end()
	_start_id3_enrichment_if_needed()

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
	if str(metadata.get("artist", "Неизвестен")) == "Неизвестен" or str(metadata.get("title", "")) == dest_path.get_file().get_basename():
		_id3_queue.append(dest_path)
		_start_id3_enrichment_if_needed()
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
	if _metadata_cache.has(song_file_path) and not _metadata_cache[song_file_path].has("file_mtime"):
		_metadata_cache[song_file_path]["file_mtime"] = int(FileAccess.get_modified_time(song_file_path))
	var any_changed := false
	var had_genres := updated_fields.has("genres") and typeof(updated_fields["genres"]) == TYPE_ARRAY
	if had_genres:
		var genres_array = updated_fields["genres"]
		var genres_str = ", ".join(genres_array)
		var old_genres = _metadata_cache[song_file_path].get("genres", "")
		if str(old_genres) != str(genres_str):
			any_changed = true
		_metadata_cache[song_file_path]["genres"] = genres_str
		var old_pg = _metadata_cache[song_file_path].get("primary_genre", "unknown")
		var new_pg = "unknown"
		if !genres_array.is_empty():
			new_pg = str(genres_array[0])
		_metadata_cache[song_file_path]["primary_genre"] = new_pg
		if str(old_pg) != str(new_pg):
			any_changed = true
		updated_fields = updated_fields.duplicate()
		updated_fields.erase("genres")
	for field_name in updated_fields:
		if field_name == "cover":
			continue
		var new_val = updated_fields[field_name]
		var old_val = _metadata_cache[song_file_path].get(field_name, null)
		if str(old_val) != str(new_val):
			_metadata_cache[song_file_path][field_name] = new_val
			any_changed = true
	if any_changed:
		_save_metadata()
		_update_song_in_list(song_file_path)
		emit_signal("metadata_updated", song_file_path)
	else:
		pass

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

func _start_id3_enrichment_if_needed():
	if _id3_running:
		return
	if _id3_queue.is_empty():
		return
	emit_signal("id3_scan_started")
	_id3_running = true
	_id3_thread = Thread.new()
	var err = _id3_thread.start(func(): _id3_worker(_id3_queue.duplicate()))
	if err != OK:
		_id3_running = false
		_id3_thread = null
		printerr("SongLibrary.gd: Не удалось запустить поток ID3: " + str(err))

func _id3_worker(queue: Array):
	var MusicMetadataRes = load("res://addons/MusicMetadata/MusicMetadata.gd")
	for p in queue:
		var fa := FileAccess.open(p, FileAccess.READ)
		if fa:
			var header := fa.get_buffer(10)
			var ok := (header.size() >= 10 and header.slice(0, 3).get_string_from_ascii() == "ID3")
			var fields := {}
			if ok:
				var size_bytes := header.slice(6, 10)
				var size := 0
				for b in size_bytes:
					size = (size << 7) | int(b & 0x7f)
				var tag := fa.get_buffer(size)
				var data := PackedByteArray()
				data.append_array(header)
				data.append_array(tag)
				var md = MusicMetadataRes.new(data)
				if md:
					var id3_title: String = str(md.title).strip_edges()
					var id3_artist: String = str(md.artist).strip_edges()
					var id3_year_val: int = int(md.year)
					var id3_bpm_val: int = int(md.bpm)
					if id3_title != "":
						fields["title"] = id3_title
					if id3_artist != "":
						fields["artist"] = id3_artist
					if id3_year_val > 0:
						fields["year"] = str(id3_year_val)
					if id3_bpm_val > 0:
						fields["bpm"] = str(id3_bpm_val)
			fa.close()
			if not fields.is_empty():
				call_deferred("_apply_id3_result", p, fields)
		OS.delay_msec(5)
	call_deferred("_finish_id3_worker")

func _apply_id3_result(path: String, fields: Dictionary):
	update_metadata(path, fields)

func _finish_id3_worker():
	if _id3_thread:
		_id3_thread.wait_to_finish()
		_id3_thread = null
	_id3_queue.clear()
	_id3_running = false
	emit_signal("id3_scan_finished")
