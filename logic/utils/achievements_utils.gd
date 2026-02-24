# logic/utils/achievements_utils.gd
extends RefCounted

static func category_map() -> Dictionary:
	return {
		"Мастерство": "mastery",
		"Перкуссия": "drums",
		"Жанры": "genres",
		"Системные": "system",
		"Магазин": "shop",
		"Экономика": "economy",
		"Ежедневные": "daily",
		"Время в игре": "playtime",
		"Событийные": "events",
		"Уровень": "level"
	}

static func category_ru_to_internal(ru: String) -> String:
	var m = category_map()
	return str(m.get(ru, "")).strip_edges()

static func icon_path_for_category(category: String) -> String:
	match category:
		"mastery": return "res://assets/achievements/mastery.png"
		"drums": return "res://assets/achievements/drums.png"
		"genres": return "res://assets/achievements/genres.png"
		"system": return "res://assets/achievements/system.png"
		"shop": return "res://assets/achievements/shop.png"
		"economy": return "res://assets/achievements/economy.png"
		"daily": return "res://assets/achievements/daily.png"
		"playtime": return "res://assets/achievements/playtime.png"
		"events": return "res://assets/achievements/events.png"
		"level": return "res://assets/achievements/level.png"
		_: return "res://assets/achievements/default.png"

static func load_icon_texture_for_category(category: String) -> ImageTexture:
	var path = icon_path_for_category(category)
	if FileAccess.file_exists(path):
		var res = ResourceLoader.load(path, "ImageTexture", ResourceLoader.CACHE_MODE_IGNORE)
		if res and res is ImageTexture:
			return res
		var img = Image.new()
		var err = img.load(path)
		if err == OK:
			return ImageTexture.create_from_image(img)
	var dummy = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	dummy.set_pixel(0, 0, Color.WHITE)
	return ImageTexture.create_from_image(dummy)
