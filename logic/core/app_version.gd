# logic/app_version.gd
extends RefCounted
class_name AppVersion

## Единственное место для версии клиента (HUD, проверка обновлений, сборка installer).
const CLIENT_VERSION = "1.2.0"
const CLIENT_BUILD = 416


static func get_version() -> String:
	return CLIENT_VERSION.strip_edges().lstrip("vV")


static func get_display_version() -> String:
	var v := get_version()
	if v.begins_with("v") or v.begins_with("V"):
		return v
	return "v%s" % v


static func get_build() -> int:
	return CLIENT_BUILD


static func get_release_label() -> String:
	var label := "%s • Release" % get_display_version()
	if CLIENT_BUILD > 0:
		label += " (Build %d)" % CLIENT_BUILD
	return label


static func get_releases_url() -> String:
	return str(
		ProjectSettings.get_setting(
			"rhythmfall/releases_url",
			"https://github.com/abletoburntheweb/RhythmFall/releases"
		)
	).strip_edges()


static func parse_version_parts(tag: String) -> PackedInt32Array:
	var s := String(tag).strip_edges()
	if s.begins_with("v") or s.begins_with("V"):
		s = s.substr(1)
	var parts := s.split(".")
	var out := PackedInt32Array()
	for i in range(3):
		if i < parts.size() and String(parts[i]).is_valid_int():
			out.append(int(parts[i]))
		else:
			out.append(0)
	return out


## Returns -1 if a < b, 0 if equal, 1 if a > b.
static func compare_tags(a: String, b: String) -> int:
	var va := parse_version_parts(a)
	var vb := parse_version_parts(b)
	for i in range(3):
		if va[i] < vb[i]:
			return -1
		if va[i] > vb[i]:
			return 1
	return 0
