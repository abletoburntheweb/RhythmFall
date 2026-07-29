# scenes/profile/share/profile_share_favorite.gd
class_name ProfileShareFavorite
extends RefCounted

const ChartDifficultyAnalyzer = preload("res://logic/domain/charts/chart_difficulty_analyzer.gd")
const SongSelectStrings = preload("res://logic/domain/library/song_select_strings.gd")


static func resolve() -> Dictionary:
	var track_path := str(PlayerDataManager.data.get("favorite_track", ""))
	var play_count := int(PlayerDataManager.data.get("favorite_track_play_count", 0))
	if track_path == "" or play_count == 0:
		track_path = TrackStatsManager.get_favorite_track()
		play_count = TrackStatsManager.get_favorite_track_count()

	var title := TranslationServer.translate("VALUE_NA")
	var artist := TranslationServer.translate("VALUE_UNKNOWN_ARTIST")
	var genre := TranslationServer.translate("VALUE_NA")
	var cover: Texture2D = null

	if track_path != "":
		track_path = track_path.replace("\\", "/").trim_suffix("/")
		var basic := _read_basic_metadata(track_path)
		title = str(basic.get("title", title))
		artist = str(basic.get("artist", artist))
		cover = basic.get("cover") as Texture2D
		var user_md: Dictionary = SongLibrary.get_metadata_for_song(track_path)
		if user_md is Dictionary and not user_md.is_empty():
			title = str(user_md.get("title", title))
			artist = str(user_md.get("artist", artist))
			genre = _format_genre(track_path, user_md)
		if cover == null:
			cover = _get_cover_from_file(track_path)
		if cover == null:
			cover = _get_fallback_cover_texture()

	var stem := track_path.get_file().get_basename() if track_path != "" else ""
	title = SongSelectStrings.display_track_title(title, stem)
	artist = SongSelectStrings.display_track_artist(artist)

	var hit := PlayerDataManager.get_total_notes_hit()
	var miss := PlayerDataManager.get_total_notes_missed()
	var played := hit + miss
	var accuracy := 0.0
	if played > 0:
		accuracy = (float(hit) / float(played)) * 100.0

	return {
		"track_path": track_path,
		"title": title,
		"artist": artist,
		"genre": genre,
		"play_count": play_count,
		"cover": cover,
		"level": PlayerDataManager.get_current_level(),
		"accuracy": accuracy,
		"play_time": PlayerDataManager.get_total_play_time_formatted(),
		"unique_tracks": PlayerDataManager.get_unique_levels_completed(),
		"levels_completed": PlayerDataManager.get_levels_completed(),
	}


static func _format_genre(song_path: String, user_md: Dictionary) -> String:
	if song_path == "":
		return TranslationServer.translate("VALUE_NA")
	var genre := str(user_md.get("primary_genre", "")).strip_edges()
	if genre != "" and genre.to_lower() != "unknown":
		return genre
	var genres: Variant = user_md.get("genres", [])
	if genres is Array and genres.size() > 0:
		var first := str(genres[0]).strip_edges()
		if first != "" and first.to_lower() != "unknown":
			return first
	return TranslationServer.translate("VALUE_NA")


static func _read_basic_metadata(filepath: String) -> Dictionary:
	var result := {
		"title": filepath.get_file().get_basename(),
		"artist": TranslationServer.translate("VALUE_UNKNOWN_ARTIST"),
		"cover": null,
	}
	if filepath == "":
		return result
	var ext := filepath.get_extension().to_lower()
	var global_path := ProjectSettings.globalize_path(filepath)
	if FileAccess.file_exists(global_path):
		var f := FileAccess.open(global_path, FileAccess.READ)
		if f:
			var data := f.get_buffer(f.get_length())
			f.close()
			var md := MusicMetadata.new()
			md.set_from_data(data)
			if md.title != "":
				result["title"] = md.title
			if md.artist != "":
				result["artist"] = md.artist
			result["cover"] = md.cover
	if ext == "wav" and result["title"] == filepath.get_file().get_basename():
		var stem := filepath.get_file().get_basename()
		if " - " in stem:
			var parts := stem.split(" - ", false, 1)
			if parts.size() == 2:
				result["artist"] = parts[0].strip_edges()
				result["title"] = parts[1].strip_edges()
	return result


static func _get_cover_from_file(filepath: String) -> Texture2D:
	if filepath == "":
		return null
	var ext := filepath.get_extension().to_lower()
	if ext != "mp3" and ext != "wav":
		return null
	var global_path := ProjectSettings.globalize_path(filepath)
	if not FileAccess.file_exists(global_path):
		return null
	var file_access := FileAccess.open(global_path, FileAccess.READ)
	if not file_access:
		return null
	var file_data := file_access.get_buffer(file_access.get_length())
	file_access.close()
	var md := MusicMetadata.new()
	md.set_from_data(file_data)
	return md.cover as Texture2D


static func _get_fallback_cover_texture() -> Texture2D:
	return TrackPlaceholderCover.load_texture("", false)
