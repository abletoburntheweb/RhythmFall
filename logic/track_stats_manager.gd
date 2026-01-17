# logic/track_stats_manager.gd
class_name TrackStatsManager
extends RefCounted

const TRACK_STATS_PATH = "user://track_stats.json"

var track_completion_counts: Dictionary = {}
var genre_play_counts: Dictionary = {}  
var favorite_track: String = ""
var favorite_track_play_count: int = 0
var favorite_genre: String = "unknown"  

func _init():
	_load()

func _load():
	var file_access = FileAccess.open(TRACK_STATS_PATH, FileAccess.READ)
	if file_access:
		var json_text = file_access.get_as_text()
		file_access.close()
		var json_result = JSON.parse_string(json_text)
		if json_result is Dictionary:
			track_completion_counts = json_result.get("track_completion_counts", {})
			genre_play_counts = json_result.get("genre_play_counts", {}) 
			_update_favorite_track()
			_update_favorite_genre()  
			print("TrackStatsManager: Загружены статы треков и жанров")
		else:
			_reset_data()
	else:
		_reset_data()

func _reset_data():
	track_completion_counts = {}
	genre_play_counts = {}
	_update_favorite_track()
	_update_favorite_genre()

func _save():
	var data_to_save = {
		"track_completion_counts": track_completion_counts,
		"genre_play_counts": genre_play_counts  
	}
	var file_access = FileAccess.open(TRACK_STATS_PATH, FileAccess.WRITE)
	if file_access:
		var json_text = JSON.stringify(data_to_save, "\t")
		file_access.store_string(json_text)
		file_access.close()
		print("TrackStatsManager: Статы треков и жанров сохранены")
	else:
		print("TrackStatsManager: Ошибка сохранения")

func on_track_completed(track_path: String):
	if track_path.is_empty():
		return

	track_completion_counts[track_path] = track_completion_counts.get(track_path, 0) + 1

	var metadata = SongMetadataManager.get_metadata_for_song(track_path)
	var genre = "unknown"
	if not metadata.is_empty():
		genre = metadata.get("primary_genre", "unknown")

	genre_play_counts[genre] = genre_play_counts.get(genre, 0) + 1

	_update_favorite_track()
	_update_favorite_genre()

	_save()

	PlayerDataManager.data["favorite_track"] = favorite_track
	PlayerDataManager.data["favorite_track_play_count"] = favorite_track_play_count
	PlayerDataManager.data["favorite_genre"] = favorite_genre
	PlayerDataManager._save()

func _update_favorite_track():
	favorite_track = ""
	favorite_track_play_count = 0
	for track in track_completion_counts:
		var count = track_completion_counts[track]
		if count > favorite_track_play_count:
			favorite_track_play_count = count
			favorite_track = track

func _update_favorite_genre():
	favorite_genre = "unknown"
	var max_count = 0
	for genre in genre_play_counts:
		var count = genre_play_counts[genre]
		if count > max_count:
			max_count = count
			favorite_genre = genre

func get_favorite_track() -> String:
	return favorite_track

func get_favorite_track_count() -> int:
	return favorite_track_play_count

func get_favorite_genre() -> String:
	return favorite_genre

func reset_stats():
	_reset_data()
	_save()
	
	PlayerDataManager.data["favorite_track"] = ""
	PlayerDataManager.data["favorite_track_play_count"] = 0
	PlayerDataManager.data["favorite_genre"] = "unknown"
	PlayerDataManager._save()
	
	print("TrackStatsManager: Статы треков и жанров сброшены.")
