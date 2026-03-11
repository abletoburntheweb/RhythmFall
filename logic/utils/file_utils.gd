# logic/utils/file_utils.gd
extends RefCounted
class_name FileUtils

static func sanitize_name_for_fs(name: String) -> String:
	var s := String(name)
	var forbidden := ['<', '>', '"', ':', '/', '\\', '|', '?', '*']
	for ch in forbidden:
		s = s.replace(String(ch), "_")
	s = s.strip_edges()
	while s.ends_with(" ") or s.ends_with("."):
		if s.ends_with(" "):
			s = s.substr(0, s.length() - 1)
		elif s.ends_with("."):
			s = s.trim_suffix(".")
	while s.find("..") != -1:
		s = s.replace("..", ".")
	if s == "":
		s = "untitled"
	return s

static func delete_dir_recursive(dir_path: String) -> void:
	var dir = DirAccess.open(dir_path)
	if not dir:
		return
	dir.list_dir_begin()
	var name = dir.get_next()
	while name != "":
		if name != "." and name != "..":
			var child_path = "%s/%s" % [dir_path, name]
			if dir.current_is_dir():
				delete_dir_recursive(child_path)
			var root = DirAccess.open("user://")
			if root:
				root.remove(child_path)
		name = dir.get_next()
	dir.list_dir_end()
	var root2 = DirAccess.open("user://")
	if root2:
		root2.remove(dir_path)
