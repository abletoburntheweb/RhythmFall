# scenes/main_menu/lib/main_menu_tip_of_day.gd
extends RefCounted
class_name MainMenuTipOfDay

const TIP_KEYS: Array[String] = [
	"MAIN_TIP_COMBO_CHAIN",
	"MAIN_TIP_GENERATE_NOTES",
	"MAIN_TIP_DAILY_QUESTS",
	"MAIN_TIP_SHOP_COLLECTIONS",
	"MAIN_TIP_CALIBRATION",
	"MAIN_TIP_MODIFIERS",
	"MAIN_TIP_ENDLESS",
	"MAIN_TIP_LIBRARY",
	"MAIN_TIP_PROFILE",
	"MAIN_TIP_PRACTICE",
	"MAIN_TIP_HELP_F1",
]


static func tip_key_for_today() -> String:
	if TIP_KEYS.is_empty():
		return ""
	var day := Time.get_date_dict_from_system()
	var seed_val := int(day.get("year", 2026)) * 10000 + int(day.get("month", 1)) * 100 + int(day.get("day", 1))
	var idx := seed_val % TIP_KEYS.size()
	return TIP_KEYS[idx]
