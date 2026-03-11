# logic/song_library.gd
extends Node

signal metadata_updated(song_file_path: String)
signal songs_list_changed()
signal id3_scan_started()
signal id3_scan_finished()

const BUILT_IN_FOLDER_PATH = "res://bundled_songs/"
const USER_DEFAULT_FOLDER_PATH = "user://Songs/"
const METADATA_FILE_PATH = "user://song_metadata.json"

var songs: Array[Dictionary] = []
var _metadata_cache: Dictionary = {}
var _id3_thread: Thread = null
var _id3_queue: Array = []
var _id3_running: bool = false

func _init():
	_load_metadata()

func _ready():
	load_songs()

func _get_effective_user_songs_path() -> String:
	var p = ""
	if SettingsManager and SettingsManager.has_method("get_setting"):
		p = String(SettingsManager.get_setting("user_songs_path", ""))
	if p == "":
		p = USER_DEFAULT_FOLDER_PATH
	if not p.ends_with("/"):
		p += "/"
	return p

func _ensure_user_dir_exists():
	var path = _get_effective_user_songs_path()
	var base = path
	if base.begins_with("user://"):
		var root = DirAccess.open("user://")
		if root:
			var rel = base.trim_prefix("user://")
			var parts = rel.split("/", false)
			var current = "user://"
			for part in parts:
				if part == "":
					continue
				current += part + "/"
				var d = DirAccess.open(current)
				if not d:
					var parent_path = current.get_base_dir()
					var parent = DirAccess.open(parent_path)
					if parent:
						parent.make_dir(current.get_file())

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
				var val = user_metadata[key]
				if _is_placeholder(key, val, filepath):
					continue
				metadata[key] = val
	return metadata

func load_songs():
	songs.clear()
	var dir = DirAccess.open(BUILT_IN_FOLDER_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				var file_lower = file_name.to_lower()
				if file_lower.ends_with(".mp3") or file_lower.ends_with(".wav"):
					var path = BUILT_IN_FOLDER_PATH + file_name
					var metadata = read_metadata(path)
					if str(metadata.get("duration", "00:00")) == "00:00":
						var dur = _compute_duration_str(path)
						if dur != "00:00":
							metadata["duration"] = dur
							update_metadata(path, {"duration": dur})
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
					metadata["source"] = "built_in"
					songs.append(metadata)
			file_name = dir.get_next()
		dir.list_dir_end()
	var user_root = _get_effective_user_songs_path()
	for k in _metadata_cache.keys():
		var p := String(k)
		if p.begins_with(user_root):
			if FileAccess.file_exists(p):
				var md = read_metadata(p)
				md["source"] = "user"
				songs.append(md)
	_start_id3_enrichment_if_needed()
	emit_signal("songs_list_changed")

func scan_user_songs():
	var user_path = _get_effective_user_songs_path()
	_ensure_user_dir_exists()
	var dir = DirAccess.open(user_path)
	if not dir:
		printerr("SongLibrary.gd: Ошибка открытия папки пользователя: " + user_path)
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var file_lower = file_name.to_lower()
			if file_lower.ends_with(".mp3") or file_lower.ends_with(".wav"):
				var path = user_path + file_name
				var exists := false
				for s in songs:
					if s.get("path", "") == path:
						exists = true
						break
				if not exists:
					var metadata = read_metadata(path)
					if str(metadata.get("duration", "00:00")) == "00:00":
						var dur = _compute_duration_str(path)
						if dur != "00:00":
							metadata["duration"] = dur
							update_metadata(path, {"duration": dur})
					metadata["source"] = "user"
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
	emit_signal("songs_list_changed")

func add_song(file_path: String) -> Dictionary:
	var file_extension = file_path.get_extension().to_lower()
	if not (file_path.ends_with(".mp3") or file_path.ends_with(".wav")):
		printerr("SongLibrary.gd: Неподдерживаемый формат файла: " + file_extension)
		return {}
	var user_root = _get_effective_user_songs_path()
	_ensure_user_dir_exists()
	var dest_path = user_root + file_path.get_file()
	var base_dir = DirAccess.open("res://")
	if not base_dir:
		printerr("SongLibrary.gd: Ошибка открытия корневой директории проекта.")
		return {}
	var copy_result = base_dir.copy(file_path, dest_path)
	if copy_result != OK:
		printerr("SongLibrary.gd: Ошибка копирования файла: " + file_path + " -> " + dest_path)
		return {}
	var metadata = read_metadata(dest_path)
	metadata["source"] = "user"
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
	emit_signal("songs_list_changed")
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
	var parse_result: Dictionary = JsonUtils.read_json_dict(METADATA_FILE_PATH)
	if parse_result is Dictionary and not parse_result.is_empty():
		_metadata_cache = parse_result
		for key in _metadata_cache.keys():
			_metadata_cache[key].erase("cover")
			_metadata_cache[key].erase("metronome_offset")
	else:
		_metadata_cache = {}

func _save_metadata():
	var cache_to_save = {}
	for path in _metadata_cache.keys():
		var song_data_copy = _metadata_cache[path].duplicate(true)
		song_data_copy.erase("cover")
		cache_to_save[path] = song_data_copy
	JsonUtils.write_json(METADATA_FILE_PATH, cache_to_save, true, true)

func _normalize_dir_path(p: String) -> String:
	var res = String(p)
	if res == "":
		res = USER_DEFAULT_FOLDER_PATH
	if not res.ends_with("/"):
		res += "/"
	return res

func _index_audio_files(root: String) -> Dictionary:
	var index := {}
	var dir = DirAccess.open(root)
	if not dir:
		return index
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var lower = file_name.to_lower()
			if lower.ends_with(".mp3") or lower.ends_with(".wav"):
				index[file_name] = root + file_name
		file_name = dir.get_next()
	dir.list_dir_end()
	return index

func prepare_user_path_migration(old_root: String, new_root: String) -> Dictionary:
	var old_r = _normalize_dir_path(old_root)
	var new_r = _normalize_dir_path(new_root)
	var matches := {}
	var new_index = _index_audio_files(new_r)
	for k in _metadata_cache.keys():
		var s := String(k)
		if s.begins_with(old_r):
			var fname := s.get_file()
			if new_index.has(fname):
				matches[s] = new_index[fname]
	return {"matches": matches}

func apply_user_path_migration(matches: Dictionary, remove_unmatched_under_old_root: bool, old_root: String):
	var old_r = _normalize_dir_path(old_root)
	for old_path in matches.keys():
		var new_path = matches[old_path]
		var old_record = _metadata_cache.get(old_path, null)
		if old_record:
			var merged = {}
			if _metadata_cache.has(new_path):
				merged = _metadata_cache[new_path].duplicate(true)
			else:
				merged = old_record.duplicate(true)
			for key in old_record.keys():
				if not merged.has(key) or str(merged[key]) == "" or str(merged[key]) == "Н/Д" or str(merged[key]) == "unknown" or str(merged[key]) == "0":
					merged[key] = old_record[key]
			merged["path"] = new_path
			_metadata_cache[new_path] = merged
			_metadata_cache.erase(old_path)
	for k in _metadata_cache.keys():
		pass
	if remove_unmatched_under_old_root:
		var snapshot = _metadata_cache.keys()
		for k2 in snapshot:
			var s2 := String(k2)
			if s2.begins_with(old_r) and not matches.has(s2):
				_metadata_cache.erase(k2)
	_save_metadata()
	emit_signal("songs_list_changed")

func clear_metadata_under_root(root: String):
	var r = _normalize_dir_path(root)
	var snapshot = _metadata_cache.keys()
	var changed := false
	for k in snapshot:
		var s := String(k)
		if s.begins_with(r):
			_metadata_cache.erase(k)
			changed = true
	if changed:
		_save_metadata()
	emit_signal("songs_list_changed")

func _is_placeholder(field: String, value, path_for_stem: String) -> bool:
	var v = str(value)
	match field:
		"title":
			var stem = path_for_stem.get_file().get_basename()
			return v == "" or v == "Без названия" or v == stem
		"artist":
			return v == "" or v == "Неизвестен"
		"bpm":
			return v == "" or v == "Н/Д" or v == "0" or v == "-1"
		"year":
			return v == "" or v == "Н/Д" or v == "0"
		"duration":
			return v == "" or v == "00:00"
		"primary_genre":
			return v == "" or v == "unknown"
		"genres":
			return v == ""
		_:
			return v == ""

func _dedupe_metadata_for_user_root(current_root: String):
	var r = _normalize_dir_path(current_root)
	var index := {}
	for k in _metadata_cache.keys():
		var s := String(k)
		if s.begins_with(r):
			if FileAccess.file_exists(s):
				index[s.get_file()] = s
	var changed := false
	var snapshot = _metadata_cache.keys()
	for k in snapshot:
		var old_path := String(k)
		if old_path.begins_with(r):
			continue
		var fname = old_path.get_file()
		if index.has(fname):
			var new_path = index[fname]
			var old_rec = _metadata_cache.get(old_path, {})
			var new_rec = _metadata_cache.get(new_path, {})
			var merged = new_rec.duplicate(true) if not new_rec.is_empty() else old_rec.duplicate(true)
			var fields = ["title","artist","bpm","year","duration","primary_genre","genres"]
			for f in fields:
				var cur_val = merged.get(f, "")
				var old_val = old_rec.get(f, "")
				if _is_placeholder(f, cur_val, new_path) and not _is_placeholder(f, old_val, old_path):
					merged[f] = old_val
			merged["path"] = new_path
			_metadata_cache[new_path] = merged
			_metadata_cache.erase(old_path)
			changed = true
	if changed:
		_save_metadata()

func prepare_dedupe_for_user_root(current_root: String) -> Dictionary:
	var r = _normalize_dir_path(current_root)
	var index := {}
	for k in _metadata_cache.keys():
		var s := String(k)
		if s.begins_with(r) and FileAccess.file_exists(s):
			index[s.get_file()] = s
	var matches := {}
	for k in _metadata_cache.keys():
		var old_path := String(k)
		if old_path.begins_with(r):
			continue
		var fname = old_path.get_file()
		if index.has(fname):
			matches[old_path] = index[fname]
	return {"matches": matches}

func apply_dedupe_for_user_root(current_root: String):
	_dedupe_metadata_for_user_root(current_root)
	emit_signal("songs_list_changed")

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

func _load_stream_for_duration(p: String) -> AudioStream:
	var full = String(p)
	if full.begins_with("res://"):
		var s_res := load(full) as AudioStream
		if s_res:
			return s_res
	var real_path = full
	if full.begins_with("user://"):
		real_path = full
	elif not FileAccess.file_exists(full):
		var g = ProjectSettings.globalize_path(full)
		if FileAccess.file_exists(g):
			real_path = g
		else:
			return null
	var f = FileAccess.open(real_path, FileAccess.READ)
	if not f:
		return null
	var bytes = f.get_buffer(f.get_length())
	f.close()
	var ext = real_path.get_extension().to_lower()
	if ext == "mp3":
		var s_mp3 := AudioStreamMP3.new()
		s_mp3.data = bytes
		return s_mp3
	elif ext == "wav":
		var s_wav := AudioStreamWAV.new()
		s_wav.data = bytes
		return s_wav
	return null

func _compute_duration_str(p: String) -> String:
	var ext = p.get_extension().to_lower()
	var stream = _load_stream_for_duration(p)
	if stream == null:
		if ext == "mp3":
			stream = ResourceLoader.load(p, "AudioStreamMP3")
		elif ext == "wav":
			stream = ResourceLoader.load(p, "AudioStreamWAV")
	if stream and stream is AudioStream:
		var seconds = stream.get_length()
		if seconds > 0:
			var minutes_i = int(seconds) / 60
			var seconds_i = int(seconds) % 60
			return "%02d:%02d" % [minutes_i, seconds_i]
	return "00:00"

func _apply_id3_result(path: String, fields: Dictionary):
	update_metadata(path, fields)

func _finish_id3_worker():
	if _id3_thread:
		_id3_thread.wait_to_finish()
		_id3_thread = null
	_id3_queue.clear()
	_id3_running = false
	emit_signal("id3_scan_finished")
