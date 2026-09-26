# logic/platform/rfr_replay_codec.gd
extends RefCounted
class_name RfrReplayCodec

const FORMAT_VERSION := "0.1"
const FILE_EXTENSION := "rfr"


static func serialize(payload: Dictionary) -> String:
	return "# RFR %s\n# RhythmFall run replay\n%s\n" % [
		FORMAT_VERSION,
		JSON.stringify(payload, "\t"),
	]


static func parse(text: String) -> Dictionary:
	var body := String(text).strip_edges()
	if body.begins_with("#"):
		var json_lines: PackedStringArray = PackedStringArray()
		for line in body.split("\n", false):
			var trimmed := line.strip_edges()
			if trimmed.begins_with("#") or trimmed == "":
				continue
			json_lines.append(line)
		body = "\n".join(json_lines)
	if body == "":
		return {}
	var parsed: Variant = JSON.parse_string(body)
	if parsed is Dictionary:
		return parsed
	return {}


static func read_file(abs_path: String) -> Dictionary:
	var path := abs_path.strip_edges()
	if path == "":
		return {}
	var normalized := path.replace("\\", "/")
	if not FileAccess.file_exists(normalized) and FileAccess.file_exists(path):
		normalized = path
	if not FileAccess.file_exists(normalized):
		return {}
	var file := FileAccess.open(normalized, FileAccess.READ)
	if file == null:
		return {}
	return parse(file.get_as_text())
