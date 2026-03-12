# logic/utils/json_utils.gd
extends RefCounted
class_name JsonUtils

static func read_json(path: String, expected: String = "", default_value = null):
	if not FileAccess.file_exists(path):
		return default_value
	var text := ""
	if path.ends_with(".gz"):
		var fa_c := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_GZIP)
		if not fa_c:
			return default_value
		text = fa_c.get_as_text()
		fa_c.close()
	else:
		var fa := FileAccess.open(path, FileAccess.READ)
		if not fa:
			return default_value
		text = fa.get_as_text()
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
	if not DirectoryUtils.ensure_dir_for_file(path):
		return false
	var indent := "  " if pretty else ""
	var text := JSON.stringify(value, indent)
	if not atomic:
		if path.ends_with(".gz"):
			var fa_c := FileAccess.open_compressed(path, FileAccess.WRITE, FileAccess.COMPRESSION_GZIP)
			if not fa_c:
				return false
			fa_c.store_string(text)
			fa_c.close()
			return true
		else:
			var fa := FileAccess.open(path, FileAccess.WRITE)
			if not fa:
				return false
			fa.store_string(text)
			fa.close()
			return true
	var tmp_path := "%s.tmp" % path
	var ok := true
	if path.ends_with(".gz"):
		var fa_tmp_c := FileAccess.open_compressed(tmp_path, FileAccess.WRITE, FileAccess.COMPRESSION_GZIP)
		if not fa_tmp_c:
			return false
		fa_tmp_c.store_string(text)
		fa_tmp_c.close()
	else:
		var fa_tmp := FileAccess.open(tmp_path, FileAccess.WRITE)
		if not fa_tmp:
			return false
		fa_tmp.store_string(text)
		fa_tmp.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var err := DirAccess.rename_absolute(tmp_path, path)
	if err != OK:
		if FileAccess.file_exists(tmp_path):
			DirAccess.remove_absolute(tmp_path)
		return false
	return true
