# logic/utils/shop_reward_notifications.gd
class_name ShopRewardNotifications
extends RefCounted

const SHOP_DATA_PATHS := [
	"user://shop_data.json",
	"res://shop_data.json",
	"res://data/shop_data.json",
]


static func load_shop_items() -> Array:
	for path in SHOP_DATA_PATHS:
		if not FileAccess.file_exists(path):
			continue
		var parsed: Dictionary = JsonUtils.read_json_dict(path)
		if parsed.has("items") and parsed["items"] is Array:
			return parsed["items"]
	return []


static func is_reward_item(item: Dictionary) -> bool:
	return bool(item.get("is_level_reward", false)) \
		or bool(item.get("is_achievement_reward", false)) \
		or bool(item.get("is_daily_reward", false))


static func is_reward_available(item: Dictionary) -> bool:
	if not is_reward_item(item):
		return false
	if bool(item.get("is_level_reward", false)):
		return PlayerDataManager.get_current_level() >= int(item.get("required_level", 0))
	if bool(item.get("is_achievement_reward", false)):
		var achievement_id := str(item.get("achievement_required", ""))
		if achievement_id != "" and achievement_id.is_valid_int():
			return PlayerDataManager.is_achievement_unlocked(int(achievement_id))
		return false
	if bool(item.get("is_daily_reward", false)):
		return PlayerDataManager.get_daily_quests_completed_total() >= int(item.get("required_daily_completed", 0))
	return false


static func get_available_reward_ids(shop_items: Array) -> PackedStringArray:
	var ids := PackedStringArray()
	for item in shop_items:
		if not (item is Dictionary):
			continue
		if not is_reward_available(item):
			continue
		var item_id := str(item.get("item_id", ""))
		if item_id != "":
			ids.append(item_id)
	return ids
