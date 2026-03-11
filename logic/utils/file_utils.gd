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
