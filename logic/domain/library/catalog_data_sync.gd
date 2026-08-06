# logic/domain/library/catalog_data_sync.gd
extends RefCounted
class_name CatalogDataSync

## Merges bundled reference JSON (next to exe / res://data) into user:// copies.
## Player progress stays in player_data.json and achievement progress fields.
##
## achievements_data.json: merge by achievement id — bundled title/description/total/category
## come from the new build; only current, unlocked, unlock_date are kept from user://.

const _ACHIEVEMENT_PROGRESS_KEYS := ["current", "unlocked", "unlock_date"]


static func _achievement_id_key(raw_id: Variant) -> String:
	if typeof(raw_id) == TYPE_FLOAT or typeof(raw_id) == TYPE_INT:
		return str(int(raw_id))
	return str(raw_id).strip_edges()

static func sync_catalogs_from_bundled() -> void:
	_sync_shop_data()
	_sync_replace_whole_file("genre_groups.json")
	_sync_replace_whole_file("daily_quests.json")
	_sync_replace_whole_file("help_content.json")
	_sync_versioned_reference("marathon_routes.json")
	_sync_achievements_data()


static func resolve_bundled_path(file_name: String) -> String:
	var res_path := "res://data/" + file_name
	if FileAccess.file_exists(res_path):
		return res_path
	var exe_dir := OS.get_executable_path().get_base_dir()
	var ext_path := exe_dir.path_join("data/" + file_name).replace("\\", "/")
	if FileAccess.file_exists(ext_path):
		return ext_path
	return ""


static func _user_path(file_name: String) -> String:
	return "user://" + file_name


static func _sync_replace_whole_file(file_name: String) -> void:
	var bundled_path := resolve_bundled_path(file_name)
	if bundled_path == "":
		return
	var bundled: Variant = JsonUtils.read_json(bundled_path)
	if bundled == null:
		return
	var user_path := _user_path(file_name)
	if not FileAccess.file_exists(user_path):
		JsonUtils.write_json(user_path, bundled, false, true)
		return
	var user_data: Variant = JsonUtils.read_json(user_path)
	if user_data == null:
		JsonUtils.write_json(user_path, bundled, false, true)
		return
	if JSON.stringify(user_data) == JSON.stringify(bundled):
		return
	JsonUtils.write_json(user_path, bundled, false, true)


## Copies bundled JSON to user:// when missing, or when bundled `version` is newer.
static func _sync_versioned_reference(file_name: String) -> void:
	var bundled_path := resolve_bundled_path(file_name)
	if bundled_path == "":
		return
	var bundled: Variant = JsonUtils.read_json(bundled_path)
	if not bundled is Dictionary:
		return
	var user_path := _user_path(file_name)
	if not FileAccess.file_exists(user_path):
		JsonUtils.write_json(user_path, bundled, false, true)
		return
	var user_data: Variant = JsonUtils.read_json(user_path)
	if not user_data is Dictionary:
		JsonUtils.write_json(user_path, bundled, false, true)
		return
	var bundled_ver := int(bundled.get("version", 0))
	var user_ver := int(user_data.get("version", 0))
	if bundled_ver > user_ver:
		JsonUtils.write_json(user_path, bundled, false, true)
		return
	if bundled_ver == user_ver and JSON.stringify(user_data) != JSON.stringify(bundled):
		JsonUtils.write_json(user_path, bundled, false, true)


static func _sync_shop_data() -> void:
	var bundled_path := resolve_bundled_path("shop_data.json")
	if bundled_path == "":
		return
	var bundled: Dictionary = JsonUtils.read_json_dict(bundled_path)
	if bundled.is_empty() or not (bundled.get("items") is Array):
		return

	var user_path := _user_path("shop_data.json")
	var user: Dictionary = {}
	if FileAccess.file_exists(user_path):
		user = JsonUtils.read_json_dict(user_path)

	var merged: Dictionary = merge_shop_items(user, bundled)
	if JSON.stringify(user) == JSON.stringify(merged):
		return
	JsonUtils.write_json(user_path, merged, false, true)


const _REMOVED_COVER_ITEM_IDS := [
	"covers_default",
	"covers_geometric",
	"covers_flowing_lines",
	"covers_music_note",
	"covers_ink_splash",
	"covers_vinyl",
	"covers_spiderweb",
	"covers_explosion",
	"covers_shards",
	"covers_cross",
	"covers_brush",
	"covers_falling_blocks",
	"pixel_amp",
	"covers_shatter",
	"covers_marble_flow",
]


static func _is_removed_shop_item(item: Dictionary) -> bool:
	var item_id := str(item.get("item_id", "")).strip_edges()
	if item_id == "":
		return false
	if item_id in _REMOVED_COVER_ITEM_IDS or item_id.begins_with("covers_"):
		return true
	var category := str(item.get("category", "")).strip_edges()
	return category == "Обложки" or category.to_lower() == "covers"


static func merge_shop_items(user: Dictionary, bundled: Dictionary) -> Dictionary:
	var user_items: Array = user.get("items", []) if user.get("items") is Array else []
	var bundled_items: Array = bundled.get("items", [])
	var by_id: Dictionary = {}

	for raw in user_items:
		if raw is Dictionary and raw.has("item_id"):
			by_id[str(raw["item_id"])] = raw

	var bundled_ids: Dictionary = {}
	var merged_items: Array = []

	for raw in bundled_items:
		if not raw is Dictionary or not raw.has("item_id"):
			continue
		var item_id := str(raw["item_id"])
		bundled_ids[item_id] = true
		merged_items.append(raw.duplicate(true))

	for raw in user_items:
		if not raw is Dictionary or not raw.has("item_id"):
			continue
		var item_id := str(raw["item_id"])
		if bundled_ids.has(item_id):
			continue
		# Covers removed from shop; orphaned user:// rows must not reappear under «Все».
		if _is_removed_shop_item(raw as Dictionary):
			continue
		merged_items.append(raw.duplicate(true))

	var out: Dictionary = {"items": merged_items}
	if bundled.get("collections") is Array:
		out["collections"] = (bundled["collections"] as Array).duplicate(true)
	return out


static func _sync_achievements_data() -> void:
	var bundled_path := resolve_bundled_path("achievements_data.json")
	if bundled_path == "":
		return
	var bundled: Dictionary = JsonUtils.read_json_dict(bundled_path)
	if bundled.is_empty() or not (bundled.get("achievements") is Array):
		return

	var user_path := _user_path("achievements_data.json")
	var user: Dictionary = {}
	if FileAccess.file_exists(user_path):
		user = JsonUtils.read_json_dict(user_path)

	var merged: Dictionary = _merge_achievements(user, bundled)
	if JSON.stringify(user) == JSON.stringify(merged):
		return
	JsonUtils.write_json(user_path, merged, false, true)


static func _merge_achievements(user: Dictionary, bundled: Dictionary) -> Dictionary:
	var user_list: Array = user.get("achievements", []) if user.get("achievements") is Array else []
	var bundled_list: Array = bundled.get("achievements", [])
	var user_by_id: Dictionary = {}

	for raw in user_list:
		if raw is Dictionary and raw.has("id"):
			user_by_id[_achievement_id_key(raw["id"])] = raw

	var merged_list: Array = []
	var bundled_ids: Dictionary = {}

	for raw in bundled_list:
		if not raw is Dictionary or not raw.has("id"):
			continue
		var ach_id := _achievement_id_key(raw["id"])
		bundled_ids[ach_id] = true
		var merged: Dictionary = raw.duplicate(true)
		if user_by_id.has(ach_id):
			var prev: Dictionary = user_by_id[ach_id]
			for key in _ACHIEVEMENT_PROGRESS_KEYS:
				if prev.has(key):
					merged[key] = prev[key]
		merged_list.append(merged)

	for raw in user_list:
		if not raw is Dictionary or not raw.has("id"):
			continue
		var ach_id := _achievement_id_key(raw["id"])
		if bundled_ids.has(ach_id):
			continue
		merged_list.append(raw.duplicate(true))

	var out: Dictionary = bundled.duplicate(true)
	out["achievements"] = merged_list
	return out
