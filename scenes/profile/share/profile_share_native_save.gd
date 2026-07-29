# scenes/profile/share/profile_share_native_save.gd
class_name ProfileShareNativeSave
extends RefCounted


static func request_save_file(title: String, default_name: String, on_path: Callable) -> void:
	var start_dir := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	DisplayServer.file_dialog_show(
		title,
		start_dir,
		default_name,
		false,
		DisplayServer.FILE_DIALOG_MODE_SAVE_FILE,
		PackedStringArray(["*.png ; PNG Images"]),
		func(status: bool, paths: PackedStringArray, _idx: int) -> void:
			if status and not paths.is_empty():
				on_path.call(String(paths[0]))
	)


static func request_save_dir(title: String, on_path: Callable) -> void:
	var start_dir := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	DisplayServer.file_dialog_show(
		title,
		start_dir,
		"",
		false,
		DisplayServer.FILE_DIALOG_MODE_OPEN_DIR,
		PackedStringArray(),
		func(status: bool, paths: PackedStringArray, _idx: int) -> void:
			if status and not paths.is_empty():
				on_path.call(String(paths[0]))
	)
