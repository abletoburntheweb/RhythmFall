# logic/track_stats_manager.gd
extends Node

const TRACK_STATS_PATH = "user://track_stats.json"

var track_completion_counts: Dictionary = {}
var genre_play_counts: Dictionary = {}  
var best_grades_per_track: Dictionary = {}
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
			best_grades_per_track = json_result.get("best_grades_per_track", {})
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
	best_grades_per_track = {}
	_update_favorite_track()
	_update_favorite_genre()

func _save():
	var data_to_save = {
		"track_completion_counts": track_completion_counts,
		"genre_play_counts": genre_play_counts,
		"best_grades_per_track": best_grades_per_track
	}
	var file_access = FileAccess.open(TRACK_STATS_PATH, FileAccess.WRITE)
	if file_access:
		var json_text = JSON.stringify(data_to_save, "\t")
		file_access.store_string(json_text)
		file_access.close()
		print("TrackStatsManager: Статы треков и жанров сохранены")
	else:
		print("TrackStatsManager: Ошибка сохранения")

var _just_completed_level: bool = false  

func on_track_completed(track_path: String):
	if _just_completed_level:  
		_just_completed_level = false
		return
	
	if track_path.is_empty():
		return

	var normalized_path = track_path.replace("\\", "/").trim_suffix("/")

	track_completion_counts[normalized_path] = track_completion_counts.get(normalized_path, 0) + 1

	var metadata = SongLibrary.get_metadata_for_song(normalized_path)

	var genre = "unknown"
	if metadata and typeof(metadata) == TYPE_DICTIONARY and metadata.has("primary_genre"):
		genre = str(metadata["primary_genre"]).to_lower().strip_edges()

	genre_play_counts[genre] = genre_play_counts.get(genre, 0) + 1

	_update_favorite_track()
	_update_favorite_genre()
	_save()

	PlayerDataManager.data["favorite_track"] = favorite_track
	PlayerDataManager.data["favorite_track_play_count"] = favorite_track_play_count
	PlayerDataManager.data["favorite_genre"] = favorite_genre
	PlayerDataManager._save()
	
	_just_completed_level = true  


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

func get_completion_count(track_path: String) -> int:
	var normalized = track_path.replace("\\", "/").trim_suffix("/")
	return int(track_completion_counts.get(normalized, 0))

func set_best_grade_for_track(track_path: String, grade: String):
	if track_path.is_empty():
		return
	var normalized = track_path.replace("\\", "/").trim_suffix("/")
	best_grades_per_track[normalized] = grade
	_save()

func get_best_grades_map() -> Dictionary:
	return best_grades_per_track.duplicate(true)

func reset_stats():
	_reset_data()
	_save()
	
	PlayerDataManager.data["favorite_track"] = ""
	PlayerDataManager.data["favorite_track_play_count"] = 0
	PlayerDataManager.data["favorite_genre"] = "unknown"
	PlayerDataManager._save()
	
	print("TrackStatsManager: Статы треков и жанров сброшены.")
