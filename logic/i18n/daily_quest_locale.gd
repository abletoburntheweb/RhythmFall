# logic/i18n/daily_quest_locale.gd
extends RefCounted
class_name DailyQuestLocale


static func localized_title(quest: Dictionary) -> String:
	var qid := str(quest.get("id", "")).strip_edges()
	if qid.is_empty():
		return _translate("DAILY_QUEST_DEFAULT")
	var key := "DAILY_QUEST_" + qid.replace("-", "_").to_upper()
	var translated := _translate(key)
	if translated != key:
		return translated
	return str(quest.get("title", _translate("DAILY_QUEST_DEFAULT")))


static func _translate(key: String) -> String:
	return TranslationServer.translate(key)
