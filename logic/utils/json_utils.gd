# logic/utils/json_utils.gd
extends RefCounted
class_name JsonUtils

static func _ensure_dir_for_file(path: String) -> bool:
	var dir_path := path.get_base_dir()
	if dir_path == "" or dir_path == ".":
		return true
	var ok := DirAccess.make_dir_recursive_absolute(dir_path) == OK
	return ok

static func read_json(path: String, expected: String = "", default_value = null):
	if not FileAccess.file_exists(path):
		return default_value
	var fa := FileAccess.open(path, FileAccess.READ)
	if not fa:
		return default_value
	var text := fa.get_as_text()
	fa.close()
	if text == "":
		return default_value
	var data = JSON.parse_string(text)
	if data == null:
		return default_value
	if expected == "Dictionary" and typeof(data) != TYPE_DICTIONARY:
		return default_value
	if expected == "Array" and typeof(data) != TYPE_ARRAY:
		return default_value
	return data

static func read_json_dict(path: String) -> Dictionary:
	var d = read_json(path, "Dictionary", {})
	return d if typeof(d) == TYPE_DICTIONARY else {}

static func read_json_array(path: String) -> Array:
	var a = read_json(path, "Array", [])
	return a if typeof(a) == TYPE_ARRAY else []

static func write_json(path: String, value, pretty: bool = false, atomic: bool = true) -> bool:
	if not _ensure_dir_for_file(path):
		return false
	var indent := "  " if pretty else ""
	var text := JSON.stringify(value, indent)
	if not atomic:
		var fa := FileAccess.open(path, FileAccess.WRITE)
		if not fa:
			return false
		fa.store_string(text)
		fa.close()
		return true
	var tmp_path := "%s.tmp" % path
	var fa_tmp := FileAccess.open(tmp_path, FileAccess.WRITE)
	if not fa_tmp:
		return false
	fa_tmp.store_string(text)
	fa_tmp.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var err := DirAccess.rename_absolute(tmp_path, path)
	if err != OK:
		# попытка отката: удалить tmp если осталось
		if FileAccess.file_exists(tmp_path):
			DirAccess.remove_absolute(tmp_path)
		return false
	return true
