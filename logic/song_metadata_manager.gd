# logic/song_metadata_manager.gd
class_name SongMetadataManager
extends Node
signal metadata_updated(song_file_path: String)
const METADATA_FILE_PATH = "user://song_metadata.json"

var _metadata_cache: Dictionary = {}

func _init():
	_load_metadata()

func get_metadata_for_song(song_file_path: String) -> Dictionary:
	if _metadata_cache.has(song_file_path):
		return _metadata_cache[song_file_path].duplicate(true)
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
			"cover": null
		}
	
	_metadata_cache[song_file_path]["file_mtime"] = FileAccess.get_modified_time(song_file_path)

	for field_name in updated_fields:
		_metadata_cache[song_file_path][field_name] = updated_fields[field_name]
	
	_save_metadata()
	print("SongMetadataManager.gd: Метаданные для '%s' обновлены и сохранены." % song_file_path)
	
	emit_signal("metadata_updated", song_file_path)

# --- НОВОЕ: Метод для удаления метаданных ---
func remove_metadata(song_file_path: String):
	if _metadata_cache.erase(song_file_path):
		_save_metadata()
		print("SongMetadataManager.gd: Метаданные для '%s' удалены и изменения сохранены." % song_file_path)
	else:
		print("SongMetadataManager.gd: Попытка удаления несуществующих метаданных для '%s'." % song_file_path)
# --- КОНЕЦ НОВОГО ---

func _load_metadata():
	var file_access = FileAccess.open(METADATA_FILE_PATH, FileAccess.READ)
	if file_access:
		var json_text = file_access.get_as_text()
		file_access.close()
		var parse_result = JSON.parse_string(json_text)
		if parse_result is Dictionary:
			_metadata_cache = parse_result
			print("SongMetadataManager.gd: Метаданные песен загружены из %s. Найдено записей: %d" % [METADATA_FILE_PATH, _metadata_cache.size()])
		else:
			printerr("SongMetadataManager.gd: Ошибка парсинга JSON из %s или данные не являются словарём." % METADATA_FILE_PATH)
			_metadata_cache = {}
	else:
		print("SongMetadataManager.gd: Файл метаданных %s не найден. Будет создан новый при первом сохранении." % METADATA_FILE_PATH)
		_metadata_cache = {}

func _save_metadata():
	var file_access = FileAccess.open(METADATA_FILE_PATH, FileAccess.WRITE)
	if file_access:
		var json_text = JSON.stringify(_metadata_cache, "\t")
		file_access.store_string(json_text)
		file_access.close()
		print("SongMetadataManager.gd: Метаданные песен сохранены в %s." % METADATA_FILE_PATH)
	else:
		printerr("SongMetadataManager.gd: Ошибка открытия файла %s для записи!" % METADATA_FILE_PATH)
