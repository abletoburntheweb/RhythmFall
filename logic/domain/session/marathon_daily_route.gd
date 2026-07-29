# logic/domain/session/marathon_daily_route.gd
class_name MarathonDailyRoute
extends RefCounted

const _MarathonRouteCatalog = preload("res://logic/domain/session/marathon_route_catalog.gd")
const _MarathonSessionConfig = preload("res://logic/domain/session/marathon_session_config.gd")
const _EndlessSessionConfig = preload("res://logic/domain/session/endless_session_config.gd")
const _ProfileGenrePortrait = preload("res://logic/domain/profile/profile_genre_portrait.gd")
const _MarathonRouteLength = preload("res://logic/domain/session/marathon_route_length.gd")
const _MarathonGenrePicker = preload("res://logic/domain/session/marathon_genre_picker.gd")
const _MarathonRouteRolls = preload("res://logic/domain/session/marathon_route_rolls.gd")

const ROUTE_PREFIX := "daily_"
const ROUTE_TYPE_DAILY := "daily"

static var _template_cache: Dictionary = {}

const DIFFICULTY_BANDS: Array[Dictionary] = [
	{"min": 2.0, "max": 5.0},
	{"min": 3.0, "max": 6.5},
	{"min": 4.0, "max": 8.0},
	{"min": 5.0, "max": 9.5},
]


static func today_iso_date() -> String:
	var parts := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [
		int(parts.get("year", 2000)),
		int(parts.get("month", 1)),
		int(parts.get("day", 1)),
	]


static func route_id_for_date(iso_date: String = "") -> String:
	var date_key := str(iso_date).strip_edges()
	if date_key == "":
		date_key = today_iso_date()
	return "%s%s" % [ROUTE_PREFIX, date_key.replace("-", "")]


static func today_route_id() -> String:
	return route_id_for_date(today_iso_date())


static func is_daily_route(route_id: String) -> bool:
	return str(route_id).strip_edges().begins_with(ROUTE_PREFIX)


static func iso_date_from_route_id(route_id: String) -> String:
	var rid := str(route_id).strip_edges()
	if not is_daily_route(rid):
		return ""
	var compact := rid.substr(ROUTE_PREFIX.length())
	if compact.length() != 8 or not compact.is_valid_int():
		return ""
	return "%s-%s-%s" % [compact.substr(0, 4), compact.substr(4, 2), compact.substr(6, 2)]


static func template_for_route_id(route_id: String) -> Dictionary:
	var rid := str(route_id).strip_edges()
	if _template_cache.has(rid):
		return (_template_cache[rid] as Dictionary).duplicate(true)
	var iso_date := iso_date_from_route_id(rid)
	if iso_date == "":
		iso_date = today_iso_date()
	var template := build_template(iso_date)
	_template_cache[rid] = template.duplicate(true)
	return template.duplicate(true)


static func route_meta_for_date(iso_date: String = "") -> Dictionary:
	var date_key := str(iso_date).strip_edges()
	if date_key == "":
		date_key = today_iso_date()
	var template := build_template(date_key)
	return {
		"route_id": str(template.get("route_id", "")),
		"title_key": "MARATHON_DAILY_TITLE",
		"subtitle_key": "MARATHON_DAILY_SUBTITLE",
		"route_type": ROUTE_TYPE_DAILY,
		"source_type": _MarathonRouteCatalog.SOURCE_TYPE_GENRE,
		"source_id": str(template.get("genre_group_id", "")),
		"length_class": "short",
		"daily_date": date_key,
		"template": template,
	}


static func build_template(iso_date: String) -> Dictionary:
	var date_key := str(iso_date).strip_edges()
	if date_key == "":
		date_key = today_iso_date()
	var rng := _seeded_rng(date_key)
	var mods := _MarathonSessionConfig.marathon_mod_pool_candidates()
	var band: Dictionary = DIFFICULTY_BANDS[rng.randi_range(0, DIFFICULTY_BANDS.size() - 1)]
	var route_id := route_id_for_date(date_key)
	var out := _MarathonRouteCatalog.template_for_group("rock").duplicate(true)
	out["route_id"] = route_id
	out["route_type"] = ROUTE_TYPE_DAILY
	out["source_type"] = _MarathonRouteCatalog.SOURCE_TYPE_GENRE
	out["target_duration_minutes"] = 15
	out["min_tracks"] = 3
	out["max_tracks"] = 5
	out["difficulty_min"] = float(band.get("min", 2.0))
	out["difficulty_max"] = float(band.get("max", 7.0))
	out["mod_policy_locked"] = true
	out["fixed_modifiers"] = [mods[rng.randi_range(0, maxi(0, mods.size() - 1))] if not mods.is_empty() else "hidden"]
	out["is_daily"] = true
	out["daily_date"] = date_key
	out["daily_seed"] = _seed_number(date_key)
	out["subtitle_key"] = "MARATHON_DAILY_SUBTITLE"
	out["tagline_key"] = "MARATHON_DAILY_TAGLINE"
	out["idea_key"] = "MARATHON_IDEA_DAILY"
	out["badges"] = {
		"bronze": "complete",
		"silver": "avg_accuracy_90",
		"gold": "perfect_route",
	}
	out = _MarathonRouteCatalog.sanitize_template(out)
	var genre_pick := _MarathonGenrePicker.pick_genre_for_template(out, date_key, "daily")
	out["genre_group_id"] = genre_pick.get("genre_id", "rock")
	out["source_id"] = str(out.get("genre_group_id", ""))
	out["genre_fallback"] = genre_pick.get("used_fallback", false)
	out["genre_preferred"] = genre_pick.get("preferred_id", "")
	return _MarathonRouteRolls.apply_to_template(out, "%s_daily_rolls" % date_key)


static func summary_line(template: Dictionary) -> String:
	var genre_id := str(template.get("genre_group_id", "")).strip_edges()
	var genre_name := TranslationServer.translate(_ProfileGenrePortrait.group_locale_key(genre_id))
	var mods: Array = template.get("fixed_modifiers", [])
	var mod_names: PackedStringArray = []
	const RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
	for mod_id in mods:
		mod_names.append(TranslationServer.translate(RunModifiers.title_i18n_key(str(mod_id))))
	var mod_text := ", ".join(mod_names) if not mod_names.is_empty() else "—"
	return TranslationServer.translate("MARATHON_DAILY_SUMMARY_FMT") % [
		genre_name,
		_MarathonRouteLength.hint_line(template),
		mod_text,
	]


static func _seed_number(iso_date: String) -> int:
	return int(absi(str(iso_date).hash()))


static func _seeded_rng(iso_date: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_number(iso_date)
	return rng
