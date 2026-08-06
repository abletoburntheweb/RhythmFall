# logic/domain/library/genre_group_icons.gd
class_name GenreGroupIcons
extends RefCounted

const _ProfileGenrePortrait = preload("res://logic/domain/profile/profile_genre_portrait.gd")

const GROUP_ICON_FILES: Dictionary = {
	"edm": "zap.svg",
	"electronic": "keyboard-music.svg",
	"bass_music": "audio-lines.svg",
	"rock": "guitar.svg",
	"metal": "flame.svg",
	"rap": "mic-vocal.svg",
	"indie_alt": "feather.svg",
	"pop": "sparkles.svg",
	"jazz": "moon.svg",
	"soul_funk": "piano.svg",
	"classical_orchestral": "scroll-text.svg",
	"folk_country": "trees.svg",
	"world": "earth.svg",
	"latin": "sun.svg",
	"reggae_dub": "tree-palm.svg",
	"_other": "tags.svg",
}

const GROUP_TINTS: Dictionary = {
	"edm": Color(0.55, 0.78, 0.98, 1.0),
	"electronic": Color(0.48, 0.72, 0.95, 1.0),
	"bass_music": Color(0.42, 0.88, 0.82, 1.0),
	"rock": Color(0.95, 0.55, 0.42, 1.0),
	"metal": Color(0.72, 0.58, 0.62, 1.0),
	"rap": Color(0.72, 0.58, 0.95, 1.0),
	"indie_alt": Color(0.62, 0.82, 0.72, 1.0),
	"pop": Color(0.98, 0.78, 0.45, 1.0),
	"jazz": Color(0.95, 0.68, 0.38, 1.0),
	"soul_funk": Color(0.92, 0.62, 0.48, 1.0),
	"classical_orchestral": Color(0.75, 0.8, 0.95, 1.0),
	"folk_country": Color(0.72, 0.86, 0.55, 1.0),
	"world": Color(0.58, 0.82, 0.55, 1.0),
	"latin": Color(0.95, 0.52, 0.58, 1.0),
	"reggae_dub": Color(0.42, 0.82, 0.62, 1.0),
	"_other": Color(0.62, 0.68, 0.78, 1.0),
}

static var _cache: Dictionary = {}


static func group_id_for_genre(canonical_genre: String) -> String:
	var group := _ProfileGenrePortrait.map_genre_to_group(canonical_genre)
	return group if group != "" else "_other"


static func tint_for_group(group_id: String) -> Color:
	var key := str(group_id).strip_edges().to_lower()
	if key == "":
		key = "_other"
	return GROUP_TINTS.get(key, GROUP_TINTS["_other"]) as Color


static func tint_for_genre(canonical_genre: String) -> Color:
	return tint_for_group(group_id_for_genre(canonical_genre))


static func icon_file_for_group(group_id: String) -> String:
	var key := str(group_id).strip_edges().to_lower()
	if key == "":
		key = "_other"
	return str(GROUP_ICON_FILES.get(key, GROUP_ICON_FILES["_other"]))


static func icon_for_group(group_id: String, tint: Color = UiIconHelper.ACCENT) -> Texture2D:
	var key := str(group_id).strip_edges().to_lower()
	if key == "":
		key = "_other"
	var cache_key := "%s|%s" % [key, tint.to_html(false)]
	if _cache.has(cache_key):
		return _cache[cache_key]
	var file_name := icon_file_for_group(key)
	var tex := UiIconHelper.load_tinted_icon(file_name, tint)
	_cache[cache_key] = tex
	return tex


static func icon_for_genre(canonical_genre: String, tint: Color = UiIconHelper.ACCENT) -> Texture2D:
	return icon_for_group(group_id_for_genre(canonical_genre), tint)


static func make_icon_frame_for_group(
	group_id: String,
	tint: Color,
	frame_size: int = 36,
	icon_size: int = 20,
	selected: bool = false
) -> PanelContainer:
	var frame := UiIconHelper.make_icon_frame(icon_file_for_group(group_id), frame_size, icon_size, tint)
	UiIconHelper.set_frame_tint(frame, tint, selected)
	return frame


static func make_icon_frame_for_genre(
	canonical_genre: String,
	tint: Color,
	frame_size: int = 36,
	icon_size: int = 20,
	selected: bool = false
) -> PanelContainer:
	return make_icon_frame_for_group(group_id_for_genre(canonical_genre), tint, frame_size, icon_size, selected)
