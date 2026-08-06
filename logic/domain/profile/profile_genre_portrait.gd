# logic/domain/profile/profile_genre_portrait.gd
class_name ProfileGenrePortrait
extends RefCounted

const _GENRE_GROUPS_PATH := "res://data/genre_groups.json"
const _USER_GENRE_GROUPS_PATH := "user://genre_groups.json"
const GenreSearch = preload("res://logic/domain/library/genre_search.gd")

static var _group_map: Dictionary = {}
static var _group_map_loaded := false


static func _ensure_group_map() -> void:
	if _group_map_loaded:
		return
	_group_map_loaded = true
	_group_map.clear()
	var path := _USER_GENRE_GROUPS_PATH if FileAccess.file_exists(_USER_GENRE_GROUPS_PATH) else _GENRE_GROUPS_PATH
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JsonUtils.read_json(path)
	if not parsed is Dictionary:
		return
	for group_name in parsed:
		var genres: Variant = parsed[group_name]
		if genres is Array:
			for g in genres:
				if g is String:
					_group_map[g.to_lower()] = str(group_name)
	GenreSearch.enrich_group_map(_group_map)
	_enrich_group_map_aliases()


static func _enrich_group_map_aliases() -> void:
	for canonical in GenreSearch.EXTRA_SEARCH_ALIASES:
		var group_id: String = str(_group_map.get(GenreSearch.normalize_canonical(canonical), ""))
		if group_id == "":
			continue
		for alias in GenreSearch.EXTRA_SEARCH_ALIASES[canonical]:
			var alias_key := GenreSearch.normalize_canonical(str(alias))
			if alias_key != "" and not _group_map.has(alias_key):
				_group_map[alias_key] = group_id


static func map_genre_to_group(canonical_genre: String) -> String:
	_ensure_group_map()
	if canonical_genre == "":
		return ""
	var key := GenreSearch.normalize_canonical(canonical_genre)
	if _group_map.has(key):
		return str(_group_map[key])
	var display := GenreSearch.canonical_display_genre(canonical_genre)
	if display != "" and _group_map.has(display):
		return str(_group_map[display])
	return ""


static func aggregate_group_play_counts(genre_play_counts: Dictionary) -> Dictionary:
	_ensure_group_map()
	var out: Dictionary = {}
	for genre in genre_play_counts:
		var count := int(genre_play_counts[genre])
		if count <= 0:
			continue
		var group := map_genre_to_group(str(genre))
		if group == "":
			group = "_other"
		out[group] = int(out.get(group, 0)) + count
	return out


static func top_groups(genre_play_counts: Dictionary, limit: int = 6) -> Array:
	var aggregated := aggregate_group_play_counts(genre_play_counts)
	var rows: Array = []
	for group in aggregated:
		if str(group) == "_other":
			continue
		rows.append({"group": str(group), "count": int(aggregated[group])})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("count", 0)) > int(b.get("count", 0))
	)
	if rows.size() > limit:
		return rows.slice(0, limit)
	return rows


static func group_locale_key(group_id: String) -> String:
	if group_id == "_other":
		return "PROFILE_GENRE_GRP_OTHER"
	return "PROFILE_GENRE_GRP_%s" % str(group_id).to_upper()


static func resolve_song_group_id(song_path: String) -> String:
	if SongLibrary == null or str(song_path).strip_edges() == "":
		return "_other"
	var meta := SongLibrary.get_metadata_for_song(song_path)
	if meta is not Dictionary:
		return "_other"
	var primary := str(meta.get("primary_genre", "")).strip_edges()
	if primary != "":
		var primary_group := map_genre_to_group(primary)
		if primary_group != "":
			return primary_group
	var genres: Variant = meta.get("genres", [])
	if genres is Array:
		for item in genres:
			var group_id := map_genre_to_group(str(item))
			if group_id != "":
				return group_id
	return "_other"


static func sorted_group_ids_for_display(group_ids: Array) -> Array[String]:
	var out: Array[String] = []
	var has_other := false
	for raw in group_ids:
		var gid := str(raw).strip_edges()
		if gid == "" or out.has(gid):
			continue
		if gid == "_other":
			has_other = true
			continue
		out.append(gid)
	out.sort_custom(func(a: String, b: String) -> bool:
		return TranslationServer.translate(group_locale_key(a)).nocasecmp_to(
			TranslationServer.translate(group_locale_key(b))
		) < 0
	)
	if has_other:
		out.append("_other")
	return out


const GROUP_DISPLAY_ORDER: Array[String] = [
	"edm",
	"electronic",
	"bass_music",
	"rock",
	"metal",
	"rap",
	"pop",
	"indie_alt",
	"jazz",
	"soul_funk",
	"classical_orchestral",
	"folk_country",
	"world",
	"latin",
	"reggae_dub",
]


static func all_group_ids() -> Array[String]:
	_ensure_group_map()
	var path := _USER_GENRE_GROUPS_PATH if FileAccess.file_exists(_USER_GENRE_GROUPS_PATH) else _GENRE_GROUPS_PATH
	var known: Dictionary = {}
	if FileAccess.file_exists(path):
		var parsed: Variant = JsonUtils.read_json(path)
		if parsed is Dictionary:
			for key in parsed:
				known[str(key)] = true
	var out: Array[String] = []
	for group_id in GROUP_DISPLAY_ORDER:
		if known.has(group_id):
			out.append(group_id)
	for group_id in known:
		if group_id != "_other" and not out.has(group_id):
			out.append(group_id)
	if known.has("_other"):
		out.append("_other")
	return out


static func group_play_count(genre_play_counts: Dictionary, group_id: String) -> int:
	var aggregated := aggregate_group_play_counts(genre_play_counts)
	return int(aggregated.get(group_id, 0))


static func genres_for_group(group_id: String) -> Array[String]:
	_ensure_group_map()
	var path := _USER_GENRE_GROUPS_PATH if FileAccess.file_exists(_USER_GENRE_GROUPS_PATH) else _GENRE_GROUPS_PATH
	if not FileAccess.file_exists(path):
		return []
	var parsed: Variant = JsonUtils.read_json(path)
	if not parsed is Dictionary:
		return []
	var raw: Variant = parsed.get(group_id, [])
	if not raw is Array:
		return []
	return GenreSearch.dedupe_genre_list(raw)


static func display_genre_play_count(genre_play_counts: Dictionary, display_genre: String) -> int:
	var target := GenreSearch.canonical_display_genre(display_genre)
	if target == "":
		return 0
	var total := 0
	for raw_key in genre_play_counts:
		if GenreSearch.canonical_display_genre(str(raw_key)) == target:
			total += int(genre_play_counts[raw_key])
	return total
