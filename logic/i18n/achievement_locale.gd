# logic/i18n/achievement_locale.gd
extends RefCounted
class_name AchievementLocale


static func achievement_id(ach: Dictionary) -> int:
	return int(ach.get("id", -1))


static func localized_title(ach: Dictionary) -> String:
	var aid := achievement_id(ach)
	if aid < 0:
		return str(ach.get("title", _translate("ACH_NO_TITLE")))
	var key := "ACH_%d_TITLE" % aid
	var translated := _translate(key)
	if translated != key:
		return translated
	return str(ach.get("title", _translate("ACH_NO_TITLE")))


static func localized_description(ach: Dictionary) -> String:
	var aid := achievement_id(ach)
	if aid < 0:
		return str(ach.get("description", _translate("ACH_NO_DESC")))
	var key := "ACH_%d_DESC" % aid
	var translated := _translate(key)
	if translated != key:
		return translated
	return str(ach.get("description", _translate("ACH_NO_DESC")))


static func localized_title_strict(ach: Dictionary) -> String:
	var aid := achievement_id(ach)
	if aid < 0:
		return ""
	var key := "ACH_%d_TITLE" % aid
	var translated := _translate(key)
	if translated != key:
		return translated
	return ""


static func localized_description_strict(ach: Dictionary) -> String:
	var aid := achievement_id(ach)
	if aid < 0:
		return ""
	var key := "ACH_%d_DESC" % aid
	var translated := _translate(key)
	if translated != key:
		return translated
	return ""


static func _translate(key: String) -> String:
	return TranslationServer.translate(key)
