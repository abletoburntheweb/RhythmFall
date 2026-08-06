# logic/domain/generation/arcade_stem_migrator.gd
## One-shot rename of on-disk arcade chart stems:
## arcade_relaxed→easy, arcade_standard→medium, arcade_dense→hard.
## Safe to delete after players have run once on v2 stems (aliases still cover leftovers).
extends RefCounted
class_name ArcadeStemMigrator

const SETTINGS_FLAG := "arcade_stem_v2_migrated"

const _TOKEN_MAP := {
	"relaxed": "easy",
	"standard": "medium",
	"dense": "hard",
}


static func migrate_if_needed() -> int:
	if typeof(SettingsManager) != TYPE_NIL and SettingsManager != null:
		if bool(SettingsManager.get_setting(SETTINGS_FLAG, false)):
			return 0
	var renamed := migrate_notes_root()
	if typeof(SettingsManager) != TYPE_NIL and SettingsManager != null:
		SettingsManager.set_setting(SETTINGS_FLAG, true)
		if SettingsManager.has_method("save_settings"):
			SettingsManager.save_settings()
	if renamed > 0:
		print("[ArcadeStemMigrator] Renamed %d chart file(s) to easy/medium/hard stems." % renamed)
	return renamed


static func migrate_notes_root() -> int:
	var root := str(NotesUtils.get_notes_root()).strip_edges()
	if root == "" or not DirAccess.dir_exists_absolute(root):
		return 0
	return _migrate_dir_recursive(root)


static func _migrate_dir_recursive(dir_path: String) -> int:
	var renamed := 0
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return 0
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var full := dir_path.path_join(entry)
		if dir.current_is_dir():
			renamed += _migrate_dir_recursive(full)
		else:
			renamed += _maybe_rename_file(dir_path, entry)
		entry = dir.get_next()
	dir.list_dir_end()
	return renamed


static func _maybe_rename_file(dir_path: String, file_name: String) -> int:
	var new_name := _mapped_file_name(file_name)
	if new_name == "" or new_name == file_name:
		return 0
	var from_path := dir_path.path_join(file_name)
	var to_path := dir_path.path_join(new_name)
	if FileAccess.file_exists(to_path):
		# Canonical already present — leave legacy file (aliases still read it).
		return 0
	var err := DirAccess.rename_absolute(from_path, to_path)
	if err != OK:
		push_warning("[ArcadeStemMigrator] Rename failed (%s): %s → %s" % [err, from_path, to_path])
		return 0
	return 1


static func _mapped_file_name(file_name: String) -> String:
	var lower := file_name.to_lower()
	# Match arcade_{legacy} token in chart filenames (nested or flat).
	for legacy in _TOKEN_MAP.keys():
		var needle := "arcade_%s" % str(legacy)
		if lower.find(needle) < 0:
			continue
		var modern := "arcade_%s" % str(_TOKEN_MAP[legacy])
		return lower.replace(needle, modern)
	return ""
