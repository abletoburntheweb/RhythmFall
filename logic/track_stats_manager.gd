# logic/track_stats_manager.gd
class_name TrackStatsManager
extends RefCounted

const TRACK_STATS_PATH = "user://track_stats.json"

var track_completion_counts: Dictionary = {}
var favorite_track: String = ""
var favorite_track_play_count: int = 0

var player_data_manager: PlayerDataManager = null

func _init(pdm: PlayerDataManager):
	player_data_manager = pdm
	_load()

func _load():
	var file_access = FileAccess.open(TRACK_STATS_PATH, FileAccess.READ)
	if file_access:
		var json_text = file_access.get_as_text()
		file_access.close()
		var json_result = JSON.parse_string(json_text)
		if json_result is Dictionary:
			track_completion_counts = json_result.get("track_completion_counts", {})
			_update_favorite_track()
			print("TrackStatsManager: Загружены статы треков из ", TRACK_STATS_PATH)
		else:
			print("TrackStatsManager: Ошибка парсинга JSON в ", TRACK_STATS_PATH)
			track_completion_counts = {}
			_update_favorite_track()
	else:
		print("TrackStatsManager: Файл track_stats.json не найден, создаём пустой")
		track_completion_counts = {}
		_update_favorite_track()

func _save():
	var data_to_save = {
		"track_completion_counts": track_completion_counts
	}
	var file_access = FileAccess.open(TRACK_STATS_PATH, FileAccess.WRITE)
	if file_access:
		var json_text = JSON.stringify(data_to_save, "\t")
		file_access.store_string(json_text)
		file_access.close()
		print("TrackStatsManager: Статы треков сохранены в ", TRACK_STATS_PATH)
	else:
		print("TrackStatsManager: Ошибка при сохранении track_stats.json")

func on_track_completed(track_path: String):
	if track_path.is_empty():
		return

	var current_count = track_completion_counts.get(track_path, 0) + 1
	track_completion_counts[track_path] = current_count

	_save()

	_update_favorite_track()

	if player_data_manager:
		player_data_manager.data["favorite_track"] = favorite_track
		player_data_manager.data["favorite_track_play_count"] = favorite_track_play_count

func _update_favorite_track():
	var max_count = 0
	var max_track = ""
	for track_path in track_completion_counts:
		var count = track_completion_counts[track_path]
		if count > max_count:
			max_count = count
			max_track = track_path

	favorite_track = max_track
	favorite_track_play_count = max_count

	print("TrackStatsManager: Обновлён любимый трек: '%s' (%d раз)" % [favorite_track, favorite_track_play_count])

func get_favorite_track() -> String:
	return favorite_track

func get_favorite_track_count() -> int:
	return favorite_track_play_count

func reset_stats():
	track_completion_counts = {}
	_update_favorite_track()
	_save()
	print("TrackStatsManager: Статы треков сброшены.")
