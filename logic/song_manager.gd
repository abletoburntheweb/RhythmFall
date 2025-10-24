# logic/song_manager.gd
extends RefCounted

const SONG_FOLDER_PATH = "res://songs/"

var songs: Array[Dictionary] = []
var cached_previews: Dictionary = {}

var song_metadata_manager = null

func _init():
	_create_directories_if_missing()

func set_metadata_manager(sm_manager):
	song_metadata_manager = sm_manager
	if song_metadata_manager:
		print("SongManager.gd: SongMetadataManager установлен.")
	else:
		print("SongManager.gd: SongMetadataManager сброшен.")

func _create_directories_if_missing():
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("songs"):
		dir.make_dir("songs")

func _read_mp3_metadata(filepath: String) -> Dictionary:
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

	if song_metadata_manager:
		var user_metadata = song_metadata_manager.get_metadata_for_song(filepath)
		
		if not user_metadata.is_empty():
			print("SongManager.gd: Найдены пользовательские метаданные для ", filepath)
			for key in user_metadata.keys():
				if metadata.has(key):
					metadata[key] = user_metadata[key]
		else:
			print("SongManager.gd: Пользовательские метаданные для ", filepath, " не найдены.")

	return metadata

func _read_wav_metadata(filepath: String) -> Dictionary:
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

	var audio_stream = ResourceLoader.load(filepath, "", ResourceLoader.CACHE_MODE_IGNORE)
	if audio_stream and audio_stream is AudioStream:
		var duration_seconds = audio_stream.get_length()
		if duration_seconds > 0:
			var minutes = int(duration_seconds) / 60
			var seconds = int(duration_seconds) % 60
			metadata["duration"] = "%02d:%02d" % [minutes, seconds]

	if metadata["title"] == filepath.get_file().get_basename():
		var filename_stem = filepath.get_file().get_basename()
		if " - " in filename_stem:
			var parts = filename_stem.split(" - ", false, 1) 
			if parts.size() == 2:
				metadata["artist"] = parts[0].strip_edges()
				metadata["title"] = parts[1].strip_edges()
				
	if song_metadata_manager:
		var user_metadata = song_metadata_manager.get_metadata_for_song(filepath)
		
		if not user_metadata.is_empty():
			print("SongManager.gd: Найдены пользовательские метаданные для ", filepath)
			for key in user_metadata.keys():
				if metadata.has(key):
					metadata[key] = user_metadata[key]
		else:
			print("SongManager.gd: Пользовательские метаданные для ", filepath, " не найдены.")

	return metadata

func load_songs():
	songs.clear()

	var dir = DirAccess.open(SONG_FOLDER_PATH)
	if not dir:
		print("SongManager.gd: Ошибка открытия папки: ", SONG_FOLDER_PATH)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var file_lower = file_name.to_lower()
			if file_lower.ends_with(".mp3") or file_lower.ends_with(".wav"):
				var path = SONG_FOLDER_PATH + file_name
				var file_modified_time = FileAccess.get_modified_time(path)

				if file_lower.ends_with(".mp3"):
					songs.append(_read_mp3_metadata(path))
				else: 
					songs.append(_read_wav_metadata(path))
				print("SongManager.gd: Прочитаны метаданные для: ", path)

		file_name = dir.get_next()
	dir.list_dir_end()

	print("SongManager.gd: Загружено песен: ", songs.size())

func add_song(file_path: String) -> Dictionary:
	var file_extension = file_path.get_extension().to_lower()
	if not (file_path.ends_with(".mp3") or file_path.ends_with(".wav")):
		print("SongManager.gd: Неподдерживаемый формат файла: ", file_extension)
		return {}

	var dest_path = SONG_FOLDER_PATH + file_path.get_file()

	var base_dir = DirAccess.open("res://")
	if not base_dir:
		print("SongManager.gd: Ошибка открытия корневой директории проекта.")
		return {}

	var copy_result = base_dir.copy(file_path, dest_path)
	if copy_result != OK:
		print("SongManager.gd: Ошибка копирования файла: ", file_path, " -> ", dest_path)
		return {}


	var metadata: Dictionary
	if file_extension == "mp3":
		metadata = _read_mp3_metadata(dest_path)
	else:
		metadata = _read_wav_metadata(dest_path)

	songs.append(metadata)

	print("SongManager.gd: Добавлена новая песня: ", metadata.get("title"))
	
	if song_metadata_manager:

		var fields_to_save = {
			"title": metadata.get("title", "Без названия"),
			"artist": metadata.get("artist", "Неизвестен"),
			"bpm": metadata.get("bpm", "Н/Д"),
			"year": metadata.get("year", "Н/Д"),
			"duration": metadata.get("duration", "00:00"),
			"cover": metadata.get("cover", null),
		}
		song_metadata_manager.update_metadata(dest_path, fields_to_save)
		print("SongManager.gd: Базовые метаданные для новой песни '%s' переданы в SongMetadataManager для сохранения." % dest_path)
	else:
		printerr("SongManager.gd: SongMetadataManager не установлен, базовые метаданные новой песни не будут сохранены!")

	return metadata

func get_songs_list() -> Array[Dictionary]:
	return songs.duplicate(true)

func get_song_count() -> int:
	return songs.size()

func _update_song_data(song_file_path: String):
	var index = -1
	for i in range(songs.size()):
		if songs[i]["path"] == song_file_path:
			index = i
			break
	
	if index != -1:
		var user_metadata = song_metadata_manager.get_metadata_for_song(song_file_path)

		for key in user_metadata.keys():
			if songs[index].has(key):
				songs[index][key] = user_metadata[key]
		
		print("SongManager.gd: Данные песни '%s' обновлены из метаданных." % song_file_path)
	else:
		printerr("SongManager.gd: Песня с путём '%s' не найдена в списке для обновления." % song_file_path)

func _on_metadata_updated(song_file_path: String):
	_update_song_data(song_file_path)
