# logic/domain/profile/achievements_utils.gd
extends RefCounted

static var _icon_texture_cache: Dictionary = {}
static var _missing_icon_texture: ImageTexture = null
const PerfTrace = preload("res://logic/utils/perf_trace.gd")

const _ACCENT_BY_CATEGORY: Dictionary = {
	"mastery": Color(0.66, 0.58, 0.86),
	"drums": Color(0.38, 0.78, 0.74),
	"bass": Color(0.45, 0.62, 0.92),
	"genres": Color(0.86, 0.52, 0.72),
	"system": Color(0.8, 0.86, 0.94),
	"shop": Color(0.52, 0.76, 0.92),
	"economy": Color(0.95, 0.78, 0.35),
	"daily": Color(0.62, 0.86, 0.72),
	"playtime": Color(0.42, 0.57, 0.82),
	"events": Color(0.95, 0.55, 0.45),
	"level": Color(0.55, 0.92, 0.65),
	"modifiers": Color(0.52, 0.76, 0.94),
	"play_modes": Color(0.62, 0.48, 0.95),
	"default": Color(0.42, 0.57, 0.82),
}

static func accent_color_for_category(category: String) -> Color:
	return _ACCENT_BY_CATEGORY.get(category, _ACCENT_BY_CATEGORY["default"])

static func category_map() -> Dictionary:
	return {
		"Мастерство": "mastery",
		"Перкуссия": "drums",
		"Бас": "bass",
		"Жанры": "genres",
		"Системные": "system",
		"Магазин": "shop",
		"Экономика": "economy",
		"Ежедневные": "daily",
		"Время в игре": "playtime",
		"Событийные": "events",
		"Уровень": "level",
		"Модификаторы": "modifiers"
	}

static func category_ru_to_internal(ru: String) -> String:
	var m = category_map()
	return str(m.get(ru, "")).strip_edges()

static func icon_path_for_category(category: String) -> String:
	match category:
		"mastery": return "res://assets/achievements/mastery.png"
		"drums": return "res://assets/achievements/drums.png"
		"bass": return "res://assets/achievements/bass.png"
		"genres": return "res://assets/achievements/genres.png"
		"system": return "res://assets/achievements/system.png"
		"shop": return "res://assets/achievements/shop.png"
		"economy": return "res://assets/achievements/economy.png"
		"daily": return "res://assets/achievements/daily.png"
		"playtime": return "res://assets/achievements/playtime.png"
		"events": return "res://assets/achievements/events.png"
		"level": return "res://assets/achievements/level.png"
		"modifiers": return "res://assets/achievements/modifiers.png"
		"play_modes": return "res://assets/achievements/play_modes.png"
		_: return "res://assets/achievements/default.png"

static func _dummy_icon_texture() -> ImageTexture:
	if _missing_icon_texture == null:
		var dummy := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		dummy.set_pixel(0, 0, Color.WHITE)
		_missing_icon_texture = ImageTexture.create_from_image(dummy)
	return _missing_icon_texture


static func load_icon_texture_for_category(category: String) -> Texture2D:
	var _t_icon := PerfTrace.begin("perf.detail.achievements.icon_load")
	var path := icon_path_for_category(category)
	if _icon_texture_cache.has(path):
		PerfTrace.end("perf.detail.achievements.icon_load", _t_icon)
		return _icon_texture_cache[path]
	if not FileAccess.file_exists(path):
		var d := _dummy_icon_texture()
		_icon_texture_cache[path] = d
		PerfTrace.end("perf.detail.achievements.icon_load", _t_icon)
		return d
	var res: Resource = ResourceLoader.load(path)
	if res != null and res is Texture2D:
		var tex: Texture2D = res as Texture2D
		_icon_texture_cache[path] = tex
		PerfTrace.end("perf.detail.achievements.icon_load", _t_icon)
		return tex
	var img := Image.new()
	if img.load(path) == OK:
		var itex := ImageTexture.create_from_image(img)
		_icon_texture_cache[path] = itex
		PerfTrace.end("perf.detail.achievements.icon_load", _t_icon)
		return itex
	var fallback := _dummy_icon_texture()
	_icon_texture_cache[path] = fallback
	PerfTrace.end("perf.detail.achievements.icon_load", _t_icon)
	return fallback
