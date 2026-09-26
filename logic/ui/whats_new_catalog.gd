# logic/ui/whats_new_catalog.gd
extends RefCounted
class_name WhatsNewCatalog

const ROOT := "res://docs/whats_new"
const INDEX_PATH := ROOT + "/index.json"


static func list_release_ids() -> PackedStringArray:
	var raw := JsonUtils.read_json_dict(INDEX_PATH)
	var releases: Variant = raw.get("releases", [])
	if not releases is Array:
		return PackedStringArray()
	var out := PackedStringArray()
	for item in releases:
		var id := str(item).strip_edges()
		if id != "":
			out.append(id)
	return out


static func load_latest(locale: String = "") -> Dictionary:
	var ids := list_release_ids()
	if ids.is_empty():
		return {}
	return load_release(ids[0], locale)


static func load_release(release_id: String, locale: String = "") -> Dictionary:
	var id := release_id.strip_edges()
	if id == "":
		return {}
	var loc := _normalize_locale(locale)
	var data := JsonUtils.read_json_dict("%s/%s.%s.json" % [ROOT, id, loc])
	if data.is_empty() and loc != "en":
		data = JsonUtils.read_json_dict("%s/%s.en.json" % [ROOT, id])
	return _sanitize(data)


static func _normalize_locale(locale: String) -> String:
	var loc := locale.strip_edges().to_lower()
	if loc == "" and LocaleManager:
		loc = str(LocaleManager.get_locale()).to_lower()
	if loc.begins_with("ru"):
		return "ru"
	return "en"


static func _sanitize(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var src: Dictionary = raw
	var out := {
		"version": str(src.get("version", "")).strip_edges(),
		"tagline": str(src.get("tagline", "")).strip_edges(),
		"sections": [],
	}
	var sections_in: Variant = src.get("sections", [])
	if not sections_in is Array:
		return out
	var sections: Array = []
	for item in sections_in:
		if not item is Dictionary:
			continue
		var sec: Dictionary = item
		var title := str(sec.get("title", "")).strip_edges()
		var body := str(sec.get("body", "")).strip_edges()
		if title == "" and body == "":
			continue
		sections.append({
			"icon": str(sec.get("icon", "sparkles.svg")).strip_edges(),
			"tint": str(sec.get("tint", "")).strip_edges(),
			"title": title,
			"body": body,
		})
	out["sections"] = sections
	return out
