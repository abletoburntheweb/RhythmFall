# logic/utils/notes_utils.gd
extends RefCounted
class_name NotesUtils

static func base_name_from_song_path(song_path: String) -> String:
	return FileUtils.sanitize_name_for_fs(song_path.get_file().get_basename())

static func notes_filename(base_name: String, instrument: String, mode: String, lanes: int) -> String:
	return "%s_%s_%s_lanes%d.json" % [base_name, instrument, mode.to_lower(), lanes]

static func notes_dir(base_name: String) -> String:
	return "user://notes/%s" % base_name

static func notes_path_by_song(song_path: String, instrument: String, mode: String, lanes: int) -> String:
	var base_name = base_name_from_song_path(song_path)
	var fname = notes_filename(base_name, instrument, mode, lanes)
	return "%s/%s" % [notes_dir(base_name), fname]

static func notes_exist(song_path: String, instrument: String, mode: String, lanes: int) -> bool:
	var p = notes_path_by_song(song_path, instrument, mode, lanes)
	var fa = FileAccess.open(p, FileAccess.READ)
	if fa:
		fa.close()
		return true
	return false
