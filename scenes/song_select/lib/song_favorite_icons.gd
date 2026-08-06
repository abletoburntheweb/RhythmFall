# scenes/song_select/lib/song_favorite_icons.gd
class_name SongFavoriteIcons
extends RefCounted

const STAR_FILE := "star.svg"
const COLOR_ACTIVE := Color("#F2B35A")
const COLOR_INACTIVE := Color(0.58, 0.64, 0.76, 0.82)
const DISPLAY_PX := 28

static var _active: Texture2D
static var _inactive: Texture2D


static func active_icon() -> Texture2D:
	_ensure_icons()
	return _active


static func inactive_icon() -> Texture2D:
	_ensure_icons()
	return _inactive


static func _ensure_icons() -> void:
	if _active != null and _inactive != null:
		return
	var raster_px := UiIconHelper.raster_size_for_display(DISPLAY_PX)
	_active = UiIconHelper.load_tinted_icon(STAR_FILE, COLOR_ACTIVE, raster_px)
	_inactive = UiIconHelper.load_tinted_icon(STAR_FILE, COLOR_INACTIVE, raster_px)
