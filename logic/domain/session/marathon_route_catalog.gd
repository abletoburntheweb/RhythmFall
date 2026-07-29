# logic/domain/session/marathon_route_catalog.gd
class_name MarathonRouteCatalog
extends RefCounted

const _ROUTES_PATH := "res://data/marathon_routes.json"
const _USER_ROUTES_PATH := "user://marathon_routes.json"
const _ProfileGenrePortrait = preload("res://logic/domain/profile/profile_genre_portrait.gd")
const _EndlessSessionConfig = preload("res://logic/domain/session/endless_session_config.gd")
const _MarathonRouteLength = preload("res://logic/domain/session/marathon_route_length.gd")

const ROUTE_TYPE_GENRE := "genre"
const ROUTE_TYPE_PLAYLIST := "playlist"
const ROUTE_TYPE_CAMPAIGN := "campaign"

const SOURCE_TYPE_GENRE := "genre"
const SOURCE_TYPE_PLAYLIST := "playlist"

static var _cached: Dictionary = {}
static var _loaded := false


static func reload() -> void:
	_loaded = false
	_cached.clear()
	const MarathonSeason = preload("res://logic/domain/session/marathon_season.gd")
	MarathonSeason.reload()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_cached = {"version": 1, "default": {}, "groups": {}, "routes": []}
	const CatalogDataSync = preload("res://logic/domain/library/catalog_data_sync.gd")
	var path := _USER_ROUTES_PATH if FileAccess.file_exists(_USER_ROUTES_PATH) else ""
	if path == "":
		var bundled := CatalogDataSync.resolve_bundled_path("marathon_routes.json")
		if bundled != "":
			path = bundled
		else:
			path = _ROUTES_PATH
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JsonUtils.read_json(path)
	if not parsed is Dictionary:
		return
	_cached = parsed


static func get_catalog_field(field: String, default: Variant = null) -> Variant:
	_ensure_loaded()
	if _cached.has(field):
		return _cached.get(field)
	return default


static func all_routes() -> Array[Dictionary]:
	_ensure_loaded()
	const MarathonSeason = preload("res://logic/domain/session/marathon_season.gd")
	const MarathonDailyRoute = preload("res://logic/domain/session/marathon_daily_route.gd")
	if MarathonSeason.is_enabled():
		var out: Array[Dictionary] = []
		for meta in MarathonSeason.all_route_metas():
			out.append(meta.duplicate(true))
		out.append(MarathonDailyRoute.route_meta_for_date(MarathonDailyRoute.today_iso_date()))
		return out
	var routes_raw: Variant = _cached.get("routes", [])
	var by_id: Dictionary = {}
	if routes_raw is Array:
		for raw in routes_raw:
			if raw is Dictionary:
				var route := _sanitize_route(raw as Dictionary)
				if route.is_empty():
					continue
				by_id[str(route.get("route_id", ""))] = route
	if by_id.is_empty():
		return []
	var out: Array[Dictionary] = []
	for route in by_id.values():
		out.append(route as Dictionary)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("route_id", "")) < str(b.get("route_id", ""))
	)
	return out


static func all_route_ids() -> Array[String]:
	var out: Array[String] = []
	for route in all_routes():
		out.append(str(route.get("route_id", "")))
	return out


static func route_by_id(route_id: String) -> Dictionary:
	var rid := str(route_id).strip_edges()
	const MarathonDailyRoute = preload("res://logic/domain/session/marathon_daily_route.gd")
	const MarathonSeason = preload("res://logic/domain/session/marathon_season.gd")
	if MarathonDailyRoute.is_daily_route(rid):
		return MarathonDailyRoute.route_meta_for_date(MarathonDailyRoute.iso_date_from_route_id(rid))
	if MarathonSeason.is_season_route(rid):
		var season_route := MarathonSeason.route_by_id(rid)
		if not season_route.is_empty():
			return season_route
	for route in all_routes():
		if str(route.get("route_id", "")) == rid:
			return route.duplicate(true)
	return {}


static func route_id_for_group(genre_group_id: String) -> String:
	return "genre_%s_standard" % str(genre_group_id).strip_edges()


static func genre_group_for_route(route_id: String) -> String:
	var rid := str(route_id).strip_edges()
	const MarathonDailyRoute = preload("res://logic/domain/session/marathon_daily_route.gd")
	if MarathonDailyRoute.is_daily_route(rid):
		return str(MarathonDailyRoute.template_for_route_id(rid).get("genre_group_id", "")).strip_edges()
	const MarathonSeason = preload("res://logic/domain/session/marathon_season.gd")
	if MarathonSeason.is_season_route(rid):
		return str(MarathonSeason.template_for_route_id(rid).get("genre_group_id", "")).strip_edges()
	var route := route_by_id(rid)
	if not route.is_empty():
		if str(route.get("source_type", "")) == SOURCE_TYPE_GENRE:
			return str(route.get("source_id", "")).strip_edges()
	var legacy := str(route_id).strip_edges()
	if legacy.begins_with("marathon_"):
		return legacy.substr("marathon_".length())
	if legacy.begins_with("genre_") and legacy.ends_with("_standard"):
		return legacy.substr("genre_".length(), legacy.length() - "genre_".length() - "_standard".length())
	return ""


static var _template_resolve_depth := 0
const _TEMPLATE_RESOLVE_MAX_DEPTH := 8


static func template_for_route(route_id: String) -> Dictionary:
	var rid := str(route_id).strip_edges()
	if rid == "":
		return _sanitize_template({})
	if _template_resolve_depth >= _TEMPLATE_RESOLVE_MAX_DEPTH:
		push_warning("MarathonRouteCatalog: template_for_route depth limit for %s" % rid)
		return _sanitize_template({})
	_template_resolve_depth += 1
	var result := _template_for_route_impl(rid)
	_template_resolve_depth -= 1
	return result


static func _template_for_route_impl(route_id: String) -> Dictionary:
	var rid := str(route_id).strip_edges()
	const MarathonDailyRoute = preload("res://logic/domain/session/marathon_daily_route.gd")
	const MarathonSeason = preload("res://logic/domain/session/marathon_season.gd")
	if MarathonDailyRoute.is_daily_route(rid):
		return MarathonDailyRoute.template_for_route_id(rid)
	if MarathonSeason.is_season_route(rid):
		return MarathonSeason.template_for_route_id(rid)
	var route := route_by_id(rid)
	if route.is_empty():
		var group_id := genre_group_for_route(route_id)
		if group_id != "":
			return template_for_group(group_id)
		return _sanitize_template({})
	return _template_from_route(route)


static func template_for_group(genre_group_id: String) -> Dictionary:
	var group_id := str(genre_group_id).strip_edges()
	if group_id == "":
		return _sanitize_template({})
	var synthetic := _sanitize_route({
		"route_id": route_id_for_group(group_id),
		"title_key": _ProfileGenrePortrait.group_locale_key(group_id),
		"subtitle_key": "MARATHON_ROUTE_GENRE_SUBTITLE",
		"route_type": ROUTE_TYPE_GENRE,
		"source_type": SOURCE_TYPE_GENRE,
		"source_id": group_id,
		"length_class": "short",
	})
	if synthetic.is_empty():
		return _sanitize_template({})
	return _template_from_route(synthetic)


static func _template_from_route(route: Dictionary) -> Dictionary:
	var defaults: Dictionary = {}
	var default_raw: Variant = _cached.get("default", {})
	if default_raw is Dictionary:
		defaults = default_raw.duplicate(true)
	var merged := defaults.duplicate(true)
	for key in route:
		if key in ["route_id", "title_key", "subtitle_key", "route_type", "source_type", "source_id", "length_class"]:
			continue
		merged[key] = route[key]
	var source_type := str(route.get("source_type", SOURCE_TYPE_GENRE)).strip_edges()
	var source_id := str(route.get("source_id", "")).strip_edges()
	if source_type == SOURCE_TYPE_GENRE and source_id != "":
		merged["genre_group_id"] = source_id
	var groups: Variant = _cached.get("groups", {})
	if groups is Dictionary and source_id != "":
		var override: Variant = groups.get(source_id, {})
		if override is Dictionary:
			for key in override:
				merged[key] = override[key]
	merged["route_id"] = str(route.get("route_id", ""))
	merged["route_type"] = str(route.get("route_type", ROUTE_TYPE_GENRE))
	merged["source_type"] = source_type
	merged["source_id"] = source_id
	merged["title_key"] = str(route.get("title_key", ""))
	merged["subtitle_key"] = str(route.get("subtitle_key", ""))
	merged["length_class"] = str(route.get("length_class", "standard"))
	if not merged.has("genre_group_id") or str(merged.get("genre_group_id", "")) == "":
		merged["genre_group_id"] = source_id
	return _sanitize_template(merged)


static func sanitize_template(raw: Dictionary) -> Dictionary:
	return _sanitize_template(raw)


static func _synthetic_genre_routes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for group_id in _ProfileGenrePortrait.all_group_ids():
		if str(group_id) == "_other":
			continue
		var gid := str(group_id)
		out.append(_sanitize_route({
			"route_id": route_id_for_group(gid),
			"title_key": _ProfileGenrePortrait.group_locale_key(gid),
			"subtitle_key": "MARATHON_ROUTE_GENRE_SUBTITLE",
			"route_type": ROUTE_TYPE_GENRE,
			"source_type": SOURCE_TYPE_GENRE,
			"source_id": gid,
			"length_class": "short",
		}))
	return out


static func _sanitize_route(raw: Dictionary) -> Dictionary:
	var route := raw.duplicate(true)
	var route_id := str(route.get("route_id", "")).strip_edges()
	if route_id == "":
		return {}
	route["route_id"] = route_id
	route["route_type"] = str(route.get("route_type", ROUTE_TYPE_GENRE)).strip_edges()
	route["source_type"] = str(route.get("source_type", SOURCE_TYPE_GENRE)).strip_edges()
	var source_id := str(route.get("source_id", "")).strip_edges()
	var title_key := str(route.get("title_key", "")).strip_edges()
	if title_key.begins_with("GENGROUP_"):
		var legacy_group := title_key.substr("GENGROUP_".length()).to_lower()
		if source_id == "":
			source_id = legacy_group
		title_key = ""
	if source_id == "" and route["source_type"] == SOURCE_TYPE_GENRE:
		source_id = _infer_genre_source_id(route_id)
	route["source_id"] = source_id
	if title_key == "":
		if route["source_type"] == SOURCE_TYPE_GENRE and source_id != "":
			route["title_key"] = _ProfileGenrePortrait.group_locale_key(source_id)
		else:
			route["title_key"] = "MARATHON_ROUTE_GENERIC_TITLE"
	else:
		route["title_key"] = title_key
	if route.get("subtitle_key") == null or str(route.get("subtitle_key", "")) == "":
		route["subtitle_key"] = _default_subtitle_key(route)
	route["length_class"] = str(route.get("length_class", "standard")).strip_edges()
	return route


static func _infer_genre_source_id(route_id: String) -> String:
	var legacy := str(route_id).strip_edges()
	if not legacy.begins_with("genre_"):
		return ""
	var body := legacy.substr("genre_".length())
	var suffixes := ["_standard", "_sprint", "_boss_rush", "_survival", "_precision"]
	for suffix in suffixes:
		if body.ends_with(suffix):
			return body.substr(0, body.length() - suffix.length())
	var parts := body.split("_")
	return parts[0] if not parts.is_empty() else ""


static func _default_subtitle_key(route: Dictionary) -> String:
	var route_id := str(route.get("route_id", "")).strip_edges().to_lower()
	if route_id.ends_with("_sprint"):
		return "MARATHON_ROUTE_SPRINT_SUBTITLE"
	if route_id.ends_with("_boss_rush"):
		return "MARATHON_ROUTE_BOSS_RUSH_SUBTITLE"
	if route_id.ends_with("_survival"):
		return "MARATHON_ROUTE_SURVIVAL_SUBTITLE"
	if route_id.ends_with("_precision"):
		return "MARATHON_ROUTE_PRECISION_SUBTITLE"
	return "MARATHON_ROUTE_GENRE_SUBTITLE"


static func _sanitize_template(raw: Dictionary) -> Dictionary:
	var out := raw.duplicate(true)
	out = _MarathonRouteLength.apply_policy_to_template(out)
	if _MarathonRouteLength.uses_duration_policy(out):
		var policy := _MarathonRouteLength.policy_from_template(out)
		out["min_songs_required"] = int(policy.get("min_songs_required", 3))
		out["track_count"] = int(policy.get("max_tracks", out.get("track_count", 5)))
	else:
		out["track_count"] = clampi(int(out.get("track_count", 5)), 3, 20)
		out["min_songs_required"] = clampi(int(out.get("min_songs_required", 3)), 2, out["track_count"])
	out["difficulty_min"] = clampf(
		float(out.get("difficulty_min", 2.0)),
		_EndlessSessionConfig.DIFFICULTY_BASE_MIN,
		_EndlessSessionConfig.DIFFICULTY_BASE_MAX
	)
	out["difficulty_max"] = clampf(
		float(out.get("difficulty_max", 7.0)),
		_EndlessSessionConfig.DIFFICULTY_BASE_MIN,
		_EndlessSessionConfig.DIFFICULTY_BASE_MAX
	)
	if out["difficulty_min"] > out["difficulty_max"]:
		var swap: float = out["difficulty_min"]
		out["difficulty_min"] = out["difficulty_max"]
		out["difficulty_max"] = swap
	out["duration_min_sec"] = clampi(int(out.get("duration_min_sec", 90)), 60, 600)
	out["duration_max_sec"] = clampi(int(out.get("duration_max_sec", 420)), 60, 600)
	if out["duration_min_sec"] > out["duration_max_sec"]:
		var swap_d: int = out["duration_min_sec"]
		out["duration_min_sec"] = out["duration_max_sec"]
		out["duration_max_sec"] = swap_d
	var mod_policy := str(out.get("mod_policy", _EndlessSessionConfig.MOD_POLICY_NONE)).strip_edges()
	if _EndlessSessionConfig.is_valid_mod_policy(mod_policy):
		out["mod_policy"] = mod_policy
	else:
		out["mod_policy"] = _EndlessSessionConfig.MOD_POLICY_NONE
	const MarathonRunRules = preload("res://logic/domain/session/marathon_run_rules.gd")
	const MarathonSessionConfig = preload("res://logic/domain/session/marathon_session_config.gd")
	out["run_rules"] = MarathonRunRules.parse(out).get("rule_ids", [])
	out["mod_policy_locked"] = bool(out.get("mod_policy_locked", false))
	if out.get("fixed_modifiers") is Array:
		out["fixed_modifiers"] = MarathonSessionConfig.sanitize_fixed_modifiers(out.get("fixed_modifiers"))
	else:
		out["fixed_modifiers"] = []
	if out.get("badges") is Dictionary:
		out["badges"] = out.get("badges").duplicate(true)
	return out
