# logic/platform/rfd_passport_codec.gd
extends RefCounted
class_name RfdPassportCodec

const FORMAT_VERSION := "0.1"


static func serialize(payload: Dictionary) -> String:
	return "# RFD %s\n# RhythmFall generation passport\n%s\n" % [
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
