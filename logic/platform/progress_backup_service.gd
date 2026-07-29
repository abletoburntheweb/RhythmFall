# logic/utils/progress_backup_service.gd
extends RefCounted
class_name ProgressBackupService

const FORMAT_NAME := "rhythmfall_progress"
const FORMAT_VERSION := 1
const MANIFEST_NAME := "manifest.json"
const ZIP_EXTENSION := ".zip"

const ROOT_FILES: Array[String] = [
	"player_data.json",
	"track_stats.json",
	"achievements_data.json",
	"session_history.json",
	"profile_milestones.json",
	"song_metadata.json",
]

const OPTIONAL_FILES: Array[String] = [
	"genre_groups.json",
	"daily_quests.json",
]

const RESULTS_DIR := "results"


static func default_export_filename() -> String:
	var dt := Time.get_datetime_string_from_system()
	dt = dt.replace(":", "-").replace("T", "_")
	return "RhythmFall_progress_%s%s" % [dt, ZIP_EXTENSION]


static func export_to_zip(absolute_zip_path: String) -> Dictionary:
	var path := String(absolute_zip_path).strip_edges()
	if path == "":
		return _fail("PROGRESS_EXPORT_ERR_PATH")
	if not path.to_lower().ends_with(ZIP_EXTENSION):
		path += ZIP_EXTENSION

	var parent := path.get_base_dir()
	if parent != "" and not DirAccess.dir_exists_absolute(parent):
		var mk := DirAccess.make_dir_recursive_absolute(parent)
		if mk != OK:
			return _fail("PROGRESS_EXPORT_ERR_PATH")

	var packer := ZIPPacker.new()
	var open_err := packer.open(path)
	if open_err != OK:
		return _fail("PROGRESS_EXPORT_ERR_OPEN", str(open_err))

	var manifest := {
		"format": FORMAT_NAME,
		"format_version": FORMAT_VERSION,
		"exported_at": Time.get_datetime_string_from_system(),
		"app_name": ProjectSettings.get_setting("application/config/name", "RhythmFall"),
	}
	var manifest_bytes := JSON.stringify(manifest).to_utf8_buffer()
	if _zip_write_bytes(packer, MANIFEST_NAME, manifest_bytes) != OK:
		packer.close()
		return _fail("PROGRESS_EXPORT_ERR_WRITE")

	for file_name in ROOT_FILES:
		var user_path := "user://%s" % file_name
		if not FileAccess.file_exists(user_path):
			continue
		var bytes := FileAccess.get_file_as_bytes(user_path)
		if _zip_write_bytes(packer, file_name, bytes) != OK:
			packer.close()
			return _fail("PROGRESS_EXPORT_ERR_WRITE", file_name)

	for file_name in OPTIONAL_FILES:
		var user_path := "user://%s" % file_name
		if not FileAccess.file_exists(user_path):
			continue
		var bytes := FileAccess.get_file_as_bytes(user_path)
		if _zip_write_bytes(packer, file_name, bytes) != OK:
			packer.close()
			return _fail("PROGRESS_EXPORT_ERR_WRITE", file_name)

	if DirAccess.dir_exists_absolute("user://%s" % RESULTS_DIR):
		var zip_err := _zip_add_user_dir(packer, "user://%s" % RESULTS_DIR, RESULTS_DIR)
		if zip_err != OK:
			packer.close()
			return _fail("PROGRESS_EXPORT_ERR_WRITE", RESULTS_DIR)

	packer.close()
	return {"ok": true, "path": path}


static func import_from_zip(absolute_zip_path: String) -> Dictionary:
	var path := String(absolute_zip_path).strip_edges()
	if path == "" or not FileAccess.file_exists(path):
		return _fail("PROGRESS_IMPORT_ERR_NOT_FOUND")

	var reader := ZIPReader.new()
	var open_err := reader.open(path)
	if open_err != OK:
		return _fail("PROGRESS_IMPORT_ERR_OPEN", str(open_err))

	var files := reader.get_files()
	if files.is_empty():
		reader.close()
		return _fail("PROGRESS_IMPORT_ERR_EMPTY")

	if not files.has(MANIFEST_NAME):
		reader.close()
		return _fail("PROGRESS_IMPORT_ERR_MANIFEST")

	var manifest_raw := reader.read_file(MANIFEST_NAME)
	var manifest: Variant = JSON.parse_string(manifest_raw.get_string_from_utf8())
	if not (manifest is Dictionary):
		reader.close()
		return _fail("PROGRESS_IMPORT_ERR_MANIFEST")
	if String(manifest.get("format", "")) != FORMAT_NAME:
		reader.close()
		return _fail("PROGRESS_IMPORT_ERR_FORMAT")
	var version := int(manifest.get("format_version", 0))
	if version > FORMAT_VERSION:
		reader.close()
		return _fail("PROGRESS_IMPORT_ERR_VERSION")

	var has_player := files.has("player_data.json")
	if not has_player:
		reader.close()
		return _fail("PROGRESS_IMPORT_ERR_NO_PLAYER")

	for file_name in files:
		if file_name == MANIFEST_NAME:
			continue
		if file_name.begins_with("%s/" % RESULTS_DIR) or file_name == RESULTS_DIR:
			continue
		if not _is_allowed_root_file(file_name):
			continue
		var bytes := reader.read_file(file_name)
		var dest := "user://%s" % file_name
		if not DirectoryUtils.ensure_dir_for_file(dest):
			reader.close()
			return _fail("PROGRESS_IMPORT_ERR_WRITE", file_name)
		var write_err := FileAccess.open(dest, FileAccess.WRITE)
		if write_err == null:
			reader.close()
			return _fail("PROGRESS_IMPORT_ERR_WRITE", file_name)
		write_err.store_buffer(bytes)
		write_err.close()

	var has_results := false
	for file_name in files:
		if file_name.begins_with("%s/" % RESULTS_DIR) and file_name != RESULTS_DIR:
			has_results = true
			break

	if has_results:
		DirectoryUtils.delete_dir_recursive("user://%s" % RESULTS_DIR)
		DirectoryUtils.ensure_dir("user://%s" % RESULTS_DIR)
		for file_name in files:
			if not file_name.begins_with("%s/" % RESULTS_DIR) or file_name == RESULTS_DIR:
				continue
			var rel := file_name.substr(RESULTS_DIR.length() + 1)
			if rel == "" or rel.contains("/"):
				continue
			var bytes := reader.read_file(file_name)
			var dest := "user://%s/%s" % [RESULTS_DIR, rel]
			if not DirectoryUtils.ensure_dir_for_file(dest):
				reader.close()
				return _fail("PROGRESS_IMPORT_ERR_WRITE", file_name)
			var write_err := FileAccess.open(dest, FileAccess.WRITE)
			if write_err == null:
				reader.close()
				return _fail("PROGRESS_IMPORT_ERR_WRITE", file_name)
			write_err.store_buffer(bytes)
			write_err.close()

	reader.close()
	apply_runtime_reload()
	return {"ok": true}


static func apply_runtime_reload() -> void:
	if PlayerDataManager:
		PlayerDataManager._load()
		PlayerDataManager._total_play_time_seconds = PlayerDataManager._play_time_string_to_seconds(
			PlayerDataManager.data.get("total_play_time", "00:00")
		)
		PlayerDataManager.emit_signal("daily_quests_updated")
		if PlayerDataManager.has_signal("shop_new_rewards_changed"):
			PlayerDataManager.emit_signal("shop_new_rewards_changed")
	if TrackStatsManager:
		TrackStatsManager._load()
	if SongLibrary:
		SongLibrary._load_metadata()
		if SongLibrary.has_signal("songs_list_changed"):
			SongLibrary.songs_list_changed.emit()

	var root := Engine.get_main_loop() as SceneTree
	if root:
		var ge: Node = root.root.get_node_or_null("GameEngine")
		if ge and ge.has_method("get_achievement_system"):
			var ach_sys: AchievementSystem = ge.get_achievement_system() as AchievementSystem
			if ach_sys and ach_sys.achievement_manager:
				ach_sys.achievement_manager.load_achievements()
				if ach_sys.achievement_manager.has_method("sync_unlocked_achievements_to_player_data"):
					ach_sys.achievement_manager.sync_unlocked_achievements_to_player_data(true)


static func _zip_write_bytes(packer: ZIPPacker, entry_name: String, bytes: PackedByteArray) -> Error:
	if packer.start_file(entry_name) != OK:
		return ERR_CANT_CREATE
	return packer.write_file(bytes)


static func _zip_add_user_dir(packer: ZIPPacker, user_dir: String, zip_prefix: String) -> Error:
	var abs_dir := ProjectSettings.globalize_path(user_dir)
	if not DirAccess.dir_exists_absolute(abs_dir):
		return OK
	var dir := DirAccess.open(user_dir)
	if dir == null:
		return ERR_CANT_OPEN
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name == "." or name == "..":
			name = dir.get_next()
			continue
		if dir.current_is_dir():
			name = dir.get_next()
			continue
		var user_path := "%s/%s" % [user_dir.trim_suffix("/"), name]
		var bytes := FileAccess.get_file_as_bytes(user_path)
		var entry := "%s/%s" % [zip_prefix, name]
		if _zip_write_bytes(packer, entry, bytes) != OK:
			dir.list_dir_end()
			return ERR_CANT_CREATE
		name = dir.get_next()
	dir.list_dir_end()
	return OK


static func _is_allowed_root_file(file_name: String) -> bool:
	if ROOT_FILES.has(file_name) or OPTIONAL_FILES.has(file_name):
		return true
	return false


static func _fail(error_key: String, detail: String = "") -> Dictionary:
	return {"ok": false, "error_key": error_key, "detail": detail}
