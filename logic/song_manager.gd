# song_manager.gd
extends RefCounted # Удобно для менеджеров, не требует добавления в сцену

const CACHE_FILE_PATH = "user://songs_cache.json"
const SONGS_FOLDER_PATH = "res://songs/" # Или "user://songs/" если песни копируются туда

var songs: Array[Dictionary] = []
var cached_previews: Dictionary = {}

# --- Загрузка песен ---
func load_songs():
	songs.clear()
	var cache = _load_cache()

	# Получаем список файлов в папке songs
	var dir = DirAccess.open(SONGS_FOLDER_PATH)
	if not dir:
		print("SongManager.gd: ОШИБКА: Не удалось открыть папку песен: ", SONGS_FOLDER_PATH)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and _is_audio_file(file_name):
			var file_path = SONGS_FOLDER_PATH + file_name
			var file_modified_time = dir.get_modified_time(file_path)

			# Проверяем кэш
			var cached_song = cache.get(file_path)
			if cached_song and cached_song.get("file_mtime") == file_modified_time:
				# Используем закэшированные данные
				var song_data = cached_song.duplicate() # Копируем, чтобы не изменять кэш
				song_data["path"] = file_path
				songs.append(song_data)
			else:
				# Загружаем и анализируем файл
				var song_data = _read_metadata(file_path)
				song_data["file_mtime"] = file_modified_time
				songs.append(song_data)

		file_name = dir.get_next()

	_save_cache(cache) # Сохраняем обновлённый кэш
	print("SongManager.gd: Загружено песен: ", songs.size())


# --- Чтение метаданных (ограниченно) ---
func _read_metadata(filepath: String) -> Dictionary:
	var metadata = {
		"path": filepath,
		"title": "Н/Д",
		"artist": "Неизвестен",
		"cover": null, # GDScript не может читать обложки из .mp3
		"bpm": "Н/Д",
		"year": "Н/Д",
		"duration": "00:00",
		"file_mtime": 0 # Будет установлен позже
	}

	var file_extension = filepath.get_extension().to_lower()

	# Попробуем извлечь базовую информацию из имени файла
	var filename_stem = filepath.get_file().get_basename()
	if " - " in filename_stem:
		var parts = filename_stem.split(" - ", false, 1) # Разделить на 2 части максимум
		if parts.size() == 2:
			metadata["artist"] = parts[0].strip_edges()
			metadata["title"] = parts[1].strip_edges()

	if metadata["title"] == "Н/Д":
		metadata["title"] = filename_stem # Если не нашли в имени файла

	# Чтение .wav заголовка (ограниченно)
	if file_extension == "wav":
		var wav_info = _read_wav_header(filepath)
		if wav_info:
			metadata["duration"] = wav_info.get("duration_str", "00:00")
			metadata["bpm"] = "Н/Д" # WAV не содержит BPM
			metadata["year"] = "Н/Д" # WAV не содержит год

	# Чтение .mp3 заголовка (НЕТ в GDScript)
	if file_extension == "mp3":
		print("SongManager.gd: Предупреждение: Чтение метаданных .mp3 не поддерживается в GDScript. Используем имя файла.")
		# Можно попытаться использовать внешний Python скрипт здесь

	return metadata


# --- Чтение WAV заголовка (простой PCM) ---
func _read_wav_header(filepath: String) -> Dictionary:
	var file = FileAccess.open(filepath, FileAccess.READ)
	if not file:
		print("SongManager.gd: Ошибка открытия .wav файла: ", filepath)
		return {}

	# Проверка заголовка RIFF
	var riff_chunk_id = file.get_32()
	if riff_chunk_id != 0x46464952: # 'RIFF'
		print("SongManager.gd: Неверный заголовок RIFF в .wav файле: ", filepath)
		file.close()
		return {}

	file.get_32() # riff_chunk_size
	var wave_format = file.get_32()
	if wave_format != 0x45564157: # 'WAVE'
		print("SongManager.gd: Неверный формат WAVE в .wav файле: ", filepath)
		file.close()
		return {}

	# Поиск 'fmt ' chunk
	while file.get_position() < file.get_length():
		var subchunk_id = file.get_32()
		var subchunk_size = file.get_32()

		if subchunk_id == 0x20746D66: # 'fmt '
			var audio_format = file.get_16()
			var num_channels = file.get_16()
			var sample_rate = file.get_32()
			file.get_32() # byte_rate
			file.get_16() # block_align
			var bits_per_sample = file.get_16()

			# Проверяем, является ли формат PCM
			if audio_format != 1:
				print("SongManager.gd: Формат .wav не PCM, пропускаем: ", filepath)
				file.close()
				return {}

			# Поиск 'data' chunk
			continue
		elif subchunk_id == 0x61746164: # 'data'
			var data_size = subchunk_size
			var total_samples = data_size / (bits_per_sample / 8) / num_channels
			var duration_seconds = total_samples / sample_rate

			var minutes = int(duration_seconds) / 60
			var seconds = int(duration_seconds) % 60
			var duration_str = "%02d:%02d" % [minutes, seconds]

			file.close()
			return {
				"sample_rate": sample_rate,
				"num_channels": num_channels,
				"bits_per_sample": bits_per_sample,
				"duration": duration_seconds,
				"duration_str": duration_str
			}
		else:
			# Пропускаем неизвестный chunk
			file.seek(file.get_position() + subchunk_size)

	print("SongManager.gd: Не найден 'data' chunk в .wav файле: ", filepath)
	file.close()
	return {}


# --- Вспомогательная функция ---
func _is_audio_file(filename: String) -> bool:
	var ext = filename.get_extension().to_lower()
	return ext == "mp3" or ext == "wav"


# --- Кэширование ---
func _load_cache() -> Dictionary:
	var file = FileAccess.open(CACHE_FILE_PATH, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()
		var json_result = JSON.parse_string(json_text)
		if json_result != null and json_result is Dictionary:
			return json_result
		else:
			print("SongManager.gd: Ошибка парсинга JSON кэша песен.")
	else:
		print("SongManager.gd: Файл кэша песен не найден, создаём новый: ", CACHE_FILE_PATH)

	return {} # Возвращаем пустой словарь, если кэш не существует или повреждён


func _save_cache(cache: Dictionary):
	# Обновляем кэш на основе текущего списка songs
	var updated_cache = {}
	for song in songs:
		var path = song.get("path")
		if path:
			var song_data = song.duplicate() # Копируем, чтобы не сохранять служебные поля типа 'path' дважды
			song_data.erase("path") # Удаляем 'path', он будет ключом
			updated_cache[path] = song_data

	var file = FileAccess.open(CACHE_FILE_PATH, FileAccess.WRITE)
	if file:
		var json_text = JSON.stringify(updated_cache, "\t") # "\t" для отступов
		file.store_string(json_text)
		file.close()
		print("SongManager.gd: Кэш песен сохранён.")
	else:
		print("SongManager.gd: Ошибка сохранения кэша песен: ", CACHE_FILE_PATH)


# --- Получение списка песен ---
func get_songs() -> Array[Dictionary]:
	return songs


# --- Добавление песни ---
func add_song(file_path: String) -> bool:
	if not FileAccess.file_exists(file_path) or not _is_audio_file(file_path):
		print("SongManager.gd: Неверный файл для добавления: ", file_path)
		return false

	# Здесь можно добавить логику копирования файла в SONGS_FOLDER_PATH
	# var target_path = SONGS_FOLDER_PATH + file_path.get_file()
	# DirAccess.copy_absolute(file_path, target_path)

	load_songs() # Перезагружаем список
	return true


# --- Удаление песни ---
func remove_song(song_path: String) -> bool:
	var index_to_remove = -1
	for i in range(songs.size()):
		if songs[i].get("path") == song_path:
			index_to_remove = i
			break

	if index_to_remove != -1:
		var song_to_remove = songs[index_to_remove]
		songs.remove_at(index_to_remove)

		# Удаляем файл
		if FileAccess.file_exists(song_path):
			var err = DirAccess.remove_absolute(song_path)
			if err != OK:
				print("SongManager.gd: Ошибка удаления файла: ", song_path, ", ошибка: ", err)
				return false # Не удаляем из кэша, если файл не удалён

		# Удаляем из кэша
		var cache = _load_cache()
		cache.erase(song_path)
		_save_cache(cache)

		print("SongManager.gd: Песня удалена: ", song_path)
		return true
	else:
		print("SongManager.gd: Песня не найдена для удаления: ", song_path)
		return false
