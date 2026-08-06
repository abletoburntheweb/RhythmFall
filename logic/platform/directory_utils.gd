# logic/platform/directory_utils.gd
extends RefCounted
class_name DirectoryUtils


static func to_absolute(path: String) -> String:
	var p := String(path).replace("\\", "/").strip_edges()
	if p.is_empty():
		return ""
	if p.begins_with("user://") or p.begins_with("res://"):
		p = ProjectSettings.globalize_path(p)
	return String(p).replace("\\", "/")


static func open_file(path: String, mode: FileAccess.ModeFlags) -> FileAccess:
	var abs := to_absolute(path)
	if abs == "":
		return null
	var file := FileAccess.open(abs, mode)
	if file != null:
		return file
	if abs.find("\\") == -1 and abs.find("/") != -1 and OS.get_name() == "Windows":
		return FileAccess.open(abs.replace("/", "\\"), mode)
	return null


static func ensure_dir(path: String) -> bool:
	var abs := to_absolute(path)
	if abs.is_empty():
		return false
	return DirAccess.make_dir_recursive_absolute(abs) == OK


static func ensure_dir_for_file(path: String) -> bool:
	var abs := to_absolute(path)
	if abs.is_empty():
		return false
	var dir_path := abs.get_base_dir()
	if dir_path.is_empty() or dir_path == ".":
		return true
	return ensure_dir(dir_path)


static func exists(path: String) -> bool:
	var abs := to_absolute(path)
	if abs.is_empty():
		return false
	return DirAccess.dir_exists_absolute(abs)


static func is_empty(path: String) -> bool:
	var abs := to_absolute(path)
	if abs.is_empty() or not DirAccess.dir_exists_absolute(abs):
		return true
	var d := DirAccess.open(abs)
	if d == null:
		return true
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if name != "." and name != "..":
			d.list_dir_end()
			return false
		name = d.get_next()
	d.list_dir_end()
	return true


static func delete_dir_recursive(dir_path: String) -> bool:
	var abs := to_absolute(dir_path)
	if abs.is_empty() or not DirAccess.dir_exists_absolute(abs):
		return true
	var d := DirAccess.open(abs)
	if d == null:
		return false
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if name != "." and name != "..":
			var child_path := "%s/%s" % [abs, name]
			if d.current_is_dir():
				delete_dir_recursive(child_path)
			else:
				DirAccess.remove_absolute(child_path)
		name = d.get_next()
	d.list_dir_end()
	DirAccess.remove_absolute(abs)
	return true
