# logic/domain/library/playlist_library_browse.gd
class_name PlaylistLibraryBrowse
extends RefCounted

const _PlaylistCatalog = preload("res://logic/domain/library/playlist_catalog.gd")


static func view_filter_for(playlist_id: String) -> Dictionary:
	var pid := str(playlist_id).strip_edges()
	if pid == "":
		return _PlaylistCatalog.default_view_filter()
	if _PlaylistCatalog.is_user_playlist(pid):
		return _PlaylistCatalog.view_filter_for(pid)
	return _PlaylistCatalog.default_view_filter()


static func filter_songs(songs: Array, playlist_id: String) -> Array:
	var pid := str(playlist_id).strip_edges()
	if pid == "":
		return songs
	var library_by_key: Dictionary = {}
	for song in songs:
		if not song is Dictionary:
			continue
		var path := str((song as Dictionary).get("path", "")).strip_edges()
		if path == "":
			continue
		library_by_key[_path_key(path)] = song
	var ordered: Array = []
	for path in _PlaylistCatalog.song_paths_for(pid):
		var key := _path_key(path)
		if library_by_key.has(key):
			ordered.append(library_by_key[key])
			continue
		var resolved := _resolve_song_from_library(path, songs)
		if not resolved.is_empty():
			ordered.append(resolved)
			continue
		ordered.append({
			"path": path,
			"title": path.get_file().get_basename(),
			"artist": "",
		})
	return ordered


static func _resolve_song_from_library(playlist_path: String, songs: Array) -> Dictionary:
	var target_key := _path_key(playlist_path)
	var target_file := playlist_path.get_file().to_lower()
	for song in songs:
		if not song is Dictionary:
			continue
		var path := str((song as Dictionary).get("path", "")).strip_edges()
		if path == "":
			continue
		if _path_key(path) == target_key:
			return song as Dictionary
		if target_file != "" and path.get_file().to_lower() == target_file:
			return song as Dictionary
	return {}


static func _path_key(path: String) -> String:
	return String(path).replace("\\", "/").strip_edges().to_lower()
