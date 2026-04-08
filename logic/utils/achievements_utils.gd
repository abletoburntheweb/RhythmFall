# logic/utils/achievements_utils.gd
extends RefCounted

static var _icon_texture_cache: Dictionary = {}
static var _missing_icon_texture: ImageTexture = null


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

static func _dummy_icon_texture() -> ImageTexture:
	if _missing_icon_texture == null:
		var dummy := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		dummy.set_pixel(0, 0, Color.WHITE)
		_missing_icon_texture = ImageTexture.create_from_image(dummy)
	return _missing_icon_texture


static func load_icon_texture_for_category(category: String) -> Texture2D:
	var path := icon_path_for_category(category)
	if _icon_texture_cache.has(path):
		return _icon_texture_cache[path]
	if not FileAccess.file_exists(path):
		var d := _dummy_icon_texture()
		_icon_texture_cache[path] = d
		return d
	var res: Resource = ResourceLoader.load(path)
	if res != null and res is Texture2D:
		var tex: Texture2D = res as Texture2D
		_icon_texture_cache[path] = tex
		return tex
	var img := Image.new()
	if img.load(path) == OK:
		var itex := ImageTexture.create_from_image(img)
		_icon_texture_cache[path] = itex
		return itex
	var fallback := _dummy_icon_texture()
	_icon_texture_cache[path] = fallback
	return fallback
