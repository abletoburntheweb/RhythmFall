# logic/utils/shop_item_locale.gd
extends RefCounted
class_name ShopItemLocale


static func localized_name(item_data: Dictionary) -> String:
	var item_id := str(item_data.get("item_id", ""))
	if item_id.is_empty():
		return _translate("SHOP_NO_NAME")
	var key := "SHOP_ITEM_" + item_id.to_upper()
	var translated := _translate(key)
	if translated != key:
		return translated
	return str(item_data.get("name", _translate("SHOP_NO_NAME")))


static func _translate(key: String) -> String:
	return TranslationServer.translate(key)
