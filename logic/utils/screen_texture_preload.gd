extends RefCounted
class_name ScreenTexturePreload

const SHOP_USER := "user://shop_data.json"
const SHOP_RES := "res://data/shop_data.json"

const ACHIEVEMENT_ICON_PATHS: PackedStringArray = [
	"res://assets/achievements/mastery.png",
	"res://assets/achievements/drums.png",
	"res://assets/achievements/genres.png",
	"res://assets/achievements/system.png",
	"res://assets/achievements/shop.png",
	"res://assets/achievements/economy.png",
	"res://assets/achievements/daily.png",
	"res://assets/achievements/playtime.png",
	"res://assets/achievements/events.png",
	"res://assets/achievements/level.png",
	"res://assets/achievements/default.png",
]


static func _load_shop_data() -> Dictionary:
	for path in [SHOP_USER, SHOP_RES]:
		if not FileAccess.file_exists(path):
			continue
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var text := f.get_as_text()
		f.close()
		var parsed = JSON.parse_string(text)
		if parsed is Dictionary:
			return parsed
	return {}


static func _request_path(loader: ThreadedTextureLoader, path: String, seen: Dictionary) -> void:
	if path.is_empty() or seen.has(path):
		return
	if not FileAccess.file_exists(path):
		return
	seen[path] = true
	loader.request(path)


static func warmup_shop_textures() -> void:
	var loader: ThreadedTextureLoader = ThreadedTextureLoader.get_instance()
	if loader == null:
		return
	var seen: Dictionary = {}
	var data := _load_shop_data()
	var items: Array = data.get("items", []) as Array
	for item in items:
		if not item is Dictionary:
			continue
		var ip := str(item.get("image", ""))
		_request_path(loader, ip, seen)
		var folder := str(item.get("images_folder", ""))
		var cnt := int(item.get("images_count", 0))
		for i in range(1, cnt + 1):
			var cp := "%s/cover%d.png" % [folder, i]
			_request_path(loader, cp, seen)


static func warmup_achievement_icons() -> void:
	var loader: ThreadedTextureLoader = ThreadedTextureLoader.get_instance()
	if loader == null:
		return
	var seen: Dictionary = {}
	for p in ACHIEVEMENT_ICON_PATHS:
		_request_path(loader, String(p), seen)


static func warmup_active_cover_pack() -> void:
	var loader: ThreadedTextureLoader = ThreadedTextureLoader.get_instance()
	if loader == null:
		return
	var seen: Dictionary = {}
	var active_id := str(PlayerDataManager.get_active_item("Covers"))
	if active_id.is_empty():
		active_id = "covers_default"
	var folder_name_map := {"covers_default": "default_covers"}
	var folder: String = str(folder_name_map.get(active_id, active_id.replace("covers_", "")))
	var base := "res://assets/shop/covers/%s" % folder
	for i in range(1, 8):
		_request_path(loader, base + "/cover%d.png" % i, seen)


static func warmup_all() -> void:
	warmup_shop_textures()
	warmup_achievement_icons()
	warmup_active_cover_pack()
