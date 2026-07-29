# logic/utils/genre_search.gd
extends RefCounted
class_name GenreSearch

# Старые сохранённые значения → актуальный канонический id в genre_groups.json
const LEGACY_CANONICAL := {
	"r&b": "rnb",
}

# Доп. варианты для поиска (канонический жанр → синонимы)
const EXTRA_SEARCH_ALIASES := {
	"rnb": ["r&b", "r and b", "rhythm and blues", "contemporary r&b"],
	"hip hop": ["hip-hop", "hiphop"],
	"lo-fi": ["lofi", "lo fi"],
	"drum and bass": ["dnb", "drum n bass"],
	"post-punk": ["post punk", "postpunk"],
	"post-rock": ["post rock", "postrock"],
	"post-hardcore": ["post hardcore", "posthardcore"],
	"synthpop": ["synth-pop", "synth pop"],
	"electropop": ["electro-pop", "electro pop"],
	"neo soul": ["neosoul", "neo-soul"],
	"bossa nova": ["bossanova"],
	"witch house": ["witchhouse"],
	"future funk": ["futurefunk"],
	"hyperpop": ["hyper pop"],
	"art pop": ["artpop"],
	"indie pop": ["indie-pop"],
	"blues rock": ["bluesrock"],
	"pop punk": ["poppunk"],
	"math rock": ["mathrock"],
	"space rock": ["spacerock"],
	"ambient rock": ["ambientrock"],
	"instrumental rock": ["instrumentalrock"],
	"cloud rap": ["cloudrap"],
	"trip hop": ["triphop"],
	"emo rap": ["emorap"],
	"dance pop": ["dancepop"],
	"teen pop": ["teenpop"],
	"modern classical": ["modernclassical"],
	"world music": ["worldmusic"],
	"dark ambient": ["darkambient"],
	"liquid dnb": ["liquiddnb"],
	"electronic dance music": ["edm"],
	"electronic": ["electronica"],
	"cha cha": ["cha-cha"],
	"berlin school": ["berlin-school"],
	"avant-garde jazz": ["avant garde jazz"],
	"afro-cuban jazz": ["afro cuban jazz"],
	"cut-up / dj": ["cut up/dj"],
	"dance-pop": ["dance pop"],
	"afro-cuban": ["afro cuban"],
}


static func normalize_canonical(genre: String) -> String:
	var key := str(genre).strip_edges().to_lower()
	if key == "":
		return ""
	return str(LEGACY_CANONICAL.get(key, key))


static func compact_token(text: String) -> String:
	var t := str(text).strip_edges().to_lower()
	var out := ""
	for i in t.length():
		var c: String = t[i]
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			out += c
	return out


static func _search_variants(genre: String) -> Array[String]:
	var variants: Array[String] = []
	var canonical := normalize_canonical(genre)
	if canonical == "":
		return variants
	variants.append(canonical)
	variants.append(canonical.replace("-", " "))
	variants.append(canonical.replace(" ", "-"))
	if canonical.contains("-"):
		variants.append(canonical.replace("-", ""))
	if canonical.contains(" "):
		variants.append(canonical.replace(" ", ""))
	if EXTRA_SEARCH_ALIASES.has(canonical):
		for alias in EXTRA_SEARCH_ALIASES[canonical]:
			variants.append(str(alias))
	for legacy in LEGACY_CANONICAL:
		if LEGACY_CANONICAL[legacy] == canonical:
			variants.append(legacy)
	return variants


static func genre_matches_query(genre: String, query: String) -> bool:
	var q := compact_token(query)
	if q == "":
		return true
	for variant in _search_variants(genre):
		var compact := compact_token(variant)
		if compact.contains(q) or q.contains(compact):
			return true
	return false


static func filter_genres(genres: Array, query: String) -> Array:
	var q := str(query).strip_edges()
	if q == "":
		return genres.duplicate()
	var out: Array = []
	for g in genres:
		if genre_matches_query(str(g), q):
			out.append(g)
	return out


static func enrich_group_map(group_map: Dictionary) -> void:
	for legacy in LEGACY_CANONICAL:
		var canonical: String = LEGACY_CANONICAL[legacy]
		if group_map.has(canonical) and not group_map.has(legacy):
			group_map[legacy] = group_map[canonical]


static var _display_canonical_loaded := false
static var _alias_to_display: Dictionary = {}


static func _ensure_display_canonical() -> void:
	if _display_canonical_loaded:
		return
	_display_canonical_loaded = true
	for canonical in EXTRA_SEARCH_ALIASES:
		var display := normalize_canonical(canonical)
		_alias_to_display[display] = display
		for alias in EXTRA_SEARCH_ALIASES[canonical]:
			_alias_to_display[normalize_canonical(str(alias))] = display
	for legacy in LEGACY_CANONICAL:
		_alias_to_display[legacy] = normalize_canonical(LEGACY_CANONICAL[legacy])


static func canonical_display_genre(genre: String) -> String:
	_ensure_display_canonical()
	var key := normalize_canonical(genre)
	if key == "":
		return ""
	return str(_alias_to_display.get(key, key))


static func dedupe_genre_list(genres: Array) -> Array[String]:
	var seen: Dictionary = {}
	var out: Array[String] = []
	for g in genres:
		var display := canonical_display_genre(str(g))
		if display == "" or seen.has(display):
			continue
		seen[display] = true
		out.append(display)
	out.sort()
	return out
