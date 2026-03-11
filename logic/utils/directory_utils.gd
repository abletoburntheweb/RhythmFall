# logic/utils/directory_utils.gd
extends RefCounted
class_name DirectoryUtils

static func ensure_dir(path: String) -> bool:
	return DirAccess.make_dir_recursive_absolute(path) == OK

static func ensure_dir_for_file(path: String) -> bool:
	var dir_path := path.get_base_dir()
	if dir_path == "" or dir_path == ".":
		return true
	return ensure_dir(dir_path)

static func exists(path: String) -> bool:
	var d = DirAccess.open(path)
	return d != null

static func is_empty(path: String) -> bool:
	var d = DirAccess.open(path)
	if not d:
		return true
	d.list_dir_begin()
	var name = d.get_next()
	while name != "":
		if name != "." and name != "..":
			d.list_dir_end()
			return false
		name = d.get_next()
	d.list_dir_end()
	return true

static func delete_dir_recursive(dir_path: String) -> bool:
	var d = DirAccess.open(dir_path)
	if not d:
		return true
	d.list_dir_begin()
	var name = d.get_next()
	while name != "":
		if name != "." and name != "..":
			var child_path = "%s/%s" % [dir_path, name]
			if d.current_is_dir():
				delete_dir_recursive(child_path)
			else:
				DirAccess.remove_absolute(child_path)
		name = d.get_next()
	d.list_dir_end()
	DirAccess.remove_absolute(dir_path)
	return true
