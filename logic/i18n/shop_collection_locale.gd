# logic/i18n/shop_collection_locale.gd
extends RefCounted
class_name ShopCollectionLocale


static func localized_name(collection: Dictionary) -> String:
	var key := str(collection.get("name_key", "")).strip_edges()
	if key == "":
		return str(collection.get("collection_id", ""))
	var translated := TranslationServer.translate(key)
	return translated if translated != key else key


static func localized_tagline(collection: Dictionary) -> String:
	var key := str(collection.get("tagline_key", "")).strip_edges()
	if key == "":
		return ""
	var translated := TranslationServer.translate(key)
	return translated if translated != key else ""


static func localized_short_name(collection: Dictionary) -> String:
	var full := localized_name(collection)
	var cut := full.replace(" Collection", "").replace(" collection", "")
	cut = cut.replace(" коллекция", "").replace(" Коллекция", "")
	cut = cut.strip_edges()
	return cut if cut != "" else full


static func collections_from_shop_data(shop_data: Dictionary) -> Array:
	var raw: Array = shop_data.get("collections", [])
	if raw.is_empty():
		return []
	var out: Array = []
	for entry in raw:
		if entry is Dictionary and str(entry.get("collection_id", "")).strip_edges() != "":
			out.append(entry)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("sort_order", 0)) < int(b.get("sort_order", 0))
	)
	return out
