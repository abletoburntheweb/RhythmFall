# scenes/profile/share/profile_share_export_messages.gd
class_name ProfileShareExportMessages
extends RefCounted


static func format_all_ok(count: int, path: String) -> String:
	var n := maxi(0, int(count))
	if TranslationServer.get_locale().begins_with("ru"):
		return "Сохранено %d %s в %s" % [n, _ru_cards_word(n), str(path)]
	return TranslationServer.translate("PROFILE_SHARE_EXPORT_ALL_OK") % [n, str(path)]


static func _ru_cards_word(count: int) -> String:
	var mod10 := count % 10
	var mod100 := count % 100
	if mod10 == 1 and mod100 != 11:
		return "карточку"
	if mod10 >= 2 and mod10 <= 4 and (mod100 < 12 or mod100 > 14):
		return "карточки"
	return "карточек"
