# logic/utils/notes_utils.gd
extends RefCounted
class_name NotesUtils

static func base_name_from_song_path(song_path: String) -> String:
	return FileUtils.sanitize_name_for_fs(song_path.get_file().get_basename())

static func notes_filename(base_name: String, instrument: String, mode: String, lanes: int) -> String:
	return "%s_%s_%s_lanes%d.json.gz" % [base_name, instrument, mode.to_lower(), lanes]

static func notes_dir(base_name: String) -> String:
	return "user://notes/%s" % base_name

static func notes_path_by_song(song_path: String, instrument: String, mode: String, lanes: int) -> String:
	var base_name = base_name_from_song_path(song_path)
	var dir = notes_dir(base_name)
	var fname_compressed = "%s_%s_%s_lanes%d.json.gz" % [base_name, instrument, mode.to_lower(), lanes]
	var fname_plain = "%s_%s_%s_lanes%d.json" % [base_name, instrument, mode.to_lower(), lanes]
	var path_compressed = "%s/%s" % [dir, fname_compressed]
	var path_plain = "%s/%s" % [dir, fname_plain]
	if FileAccess.file_exists(path_compressed):
		return path_compressed
	if FileAccess.file_exists(path_plain):
		return path_plain
	return path_compressed

static func notes_exist(song_path: String, instrument: String, mode: String, lanes: int) -> bool:
	var base_name = base_name_from_song_path(song_path)
	var dir = notes_dir(base_name)
	var fname_compressed = "%s_%s_%s_lanes%d.json.gz" % [base_name, instrument, mode.to_lower(), lanes]
	var fname_plain = "%s_%s_%s_lanes%d.json" % [base_name, instrument, mode.to_lower(), lanes]
	var path_compressed = "%s/%s" % [dir, fname_compressed]
	var path_plain = "%s/%s" % [dir, fname_plain]
	return FileAccess.file_exists(path_compressed) or FileAccess.file_exists(path_plain)
