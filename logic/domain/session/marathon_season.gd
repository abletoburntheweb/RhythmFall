# logic/domain/session/marathon_season.gd
class_name MarathonSeason
extends RefCounted

const ROUTE_PREFIX := "season_"
const ROUTE_TYPE_SEASON := "season"

const _MarathonRouteCatalog = preload("res://logic/domain/session/marathon_route_catalog.gd")
const _MarathonSessionConfig = preload("res://logic/domain/session/marathon_session_config.gd")
const _MarathonRunRules = preload("res://logic/domain/session/marathon_run_rules.gd")
const _ProfileGenrePortrait = preload("res://logic/domain/profile/profile_genre_portrait.gd")
const _EndlessSessionConfig = preload("res://logic/domain/session/endless_session_config.gd")
const _MarathonGenrePicker = preload("res://logic/domain/session/marathon_genre_picker.gd")
const _MarathonRouteRolls = preload("res://logic/domain/session/marathon_route_rolls.gd")
const _MarathonRouteSetup = preload("res://logic/domain/session/marathon_route_setup.gd")

const DEFAULT_PERIOD_DAYS := 3
const DEFAULT_ANCHOR_ISO := "2026-01-01"

const MOD_ROTATION_POOL: Array[String] = [
	"mirror_mode",
	"hidden",
	"random_modifiers",
	"memory_mode",
]

static var _template_cache: Dictionary = {}


static func reload() -> void:
	_template_cache.clear()


static func is_season_route(route_id: String) -> bool:
	return str(route_id).strip_edges().begins_with(ROUTE_PREFIX)


static func is_enabled() -> bool:
	var cfg := _season_config()
	return bool(cfg.get("enabled", true))


static func period_days() -> int:
	return maxi(1, int(_season_config().get("period_days", DEFAULT_PERIOD_DAYS)))


static func current_season_start_iso() -> String:
	return _season_start_iso_for_date(_today_iso_date())


static func next_season_start_iso() -> String:
	return _add_days_iso(current_season_start_iso(), period_days())


static func seconds_until_next_season() -> int:
	var next_iso := next_season_start_iso()
	var next_unix := TimeUtils.unix_from_local_iso_datetime("%s 00:00:00" % next_iso)
	if next_unix <= 0:
		return 0
	return maxi(0, next_unix - int(Time.get_unix_time_from_system()))


static func all_archetypes() -> Array[Dictionary]:
	var raw: Variant = _MarathonRouteCatalog.get_catalog_field("archetypes", [])
	var out: Array[Dictionary] = []
	if raw is Array:
		for entry in raw:
			if entry is Dictionary:
				var archetype := _sanitize_archetype(entry as Dictionary)
				if not archetype.is_empty():
					out.append(archetype)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("sort_order", 999)) < int(b.get("sort_order", 999))
	)
	return out


static func archetype_by_id(archetype_id: String) -> Dictionary:
	var aid := str(archetype_id).strip_edges()
	for archetype in all_archetypes():
		if str(archetype.get("archetype_id", "")) == aid:
			return archetype.duplicate(true)
	return {}


static func route_id_for(archetype_id: String, season_start_iso: String = "") -> String:
	var start_iso := str(season_start_iso).strip_edges()
	if start_iso == "":
		start_iso = current_season_start_iso()
	return "%s%s_%s" % [ROUTE_PREFIX, str(archetype_id).strip_edges(), start_iso.replace("-", "")]


static func archetype_id_from_route_id(route_id: String) -> String:
	var rid := str(route_id).strip_edges()
	if not is_season_route(rid):
		return ""
	var body := rid.substr(ROUTE_PREFIX.length())
	var parts := body.split("_")
	if parts.size() < 2:
		return ""
	var compact := parts[parts.size() - 1]
	if compact.length() != 8 or not compact.is_valid_int():
		return ""
	var aid := "_".join(parts.slice(0, parts.size() - 1))
	return _MarathonRouteSetup.normalize_archetype_id(aid)


static func season_start_from_route_id(route_id: String) -> String:
	var rid := str(route_id).strip_edges()
	if not is_season_route(rid):
		return ""
	var body := rid.substr(ROUTE_PREFIX.length())
	var parts := body.split("_")
	if parts.is_empty():
		return ""
	var compact := str(parts[parts.size() - 1])
	if compact.length() != 8:
		return ""
	return "%s-%s-%s" % [compact.substr(0, 4), compact.substr(4, 2), compact.substr(6, 2)]


static func all_route_metas(season_start_iso: String = "") -> Array[Dictionary]:
	var start_iso := str(season_start_iso).strip_edges()
	if start_iso == "":
		start_iso = current_season_start_iso()
	var out: Array[Dictionary] = []
	for archetype in all_archetypes():
		var aid := str(archetype.get("archetype_id", "")).strip_edges()
		if aid == "":
			continue
		out.append(route_meta_for_archetype(aid, start_iso))
	return out


static func current_rotation_route_ids(season_start_iso: String = "") -> Array[String]:
	var start_iso := str(season_start_iso).strip_edges()
	if start_iso == "":
		start_iso = current_season_start_iso()
	var out: Array[String] = []
	for archetype in all_archetypes():
		var aid := str(archetype.get("archetype_id", "")).strip_edges()
		if aid == "":
			continue
		out.append(route_id_for(aid, start_iso))
	return out


static func route_meta_for_archetype(archetype_id: String, season_start_iso: String = "") -> Dictionary:
	var start_iso := str(season_start_iso).strip_edges()
	if start_iso == "":
		start_iso = current_season_start_iso()
	var archetype := archetype_by_id(archetype_id)
	var rid := route_id_for(archetype_id, start_iso)
	var template := template_for_route_id(rid)
	return {
		"route_id": str(template.get("route_id", "")),
		"archetype_id": archetype_id,
		"title_key": str(archetype.get("title_key", "")),
		"subtitle_key": str(archetype.get("subtitle_key", "")),
		"route_type": ROUTE_TYPE_SEASON,
		"source_type": _MarathonRouteCatalog.SOURCE_TYPE_GENRE,
		"source_id": str(template.get("genre_group_id", "")),
		"length_class": str(archetype.get("length_class", "standard")),
		"season_start": start_iso,
		"icon_emoji": str(archetype.get("icon_emoji", "")),
		"template": template,
	}


static func route_by_id(route_id: String) -> Dictionary:
	if not is_season_route(route_id):
		return {}
	var aid := archetype_id_from_route_id(route_id)
	if aid == "":
		return {}
	var start_iso := season_start_from_route_id(route_id)
	return route_meta_for_archetype(aid, start_iso)


static func template_for_route_id(route_id: String) -> Dictionary:
	if not is_season_route(route_id):
		return {}
	var cache_key := route_id
	if _template_cache.has(cache_key):
		return (_template_cache[cache_key] as Dictionary).duplicate(true)
	var aid := archetype_id_from_route_id(route_id)
	var start_iso := season_start_from_route_id(route_id)
	if aid == "" or start_iso == "":
		return {}
	var template := build_template(aid, start_iso)
	_template_cache[cache_key] = template.duplicate(true)
	return template.duplicate(true)


static func build_template(archetype_id: String, season_start_iso: String = "") -> Dictionary:
	var aid := str(archetype_id).strip_edges()
	var start_iso := str(season_start_iso).strip_edges()
	if start_iso == "":
		start_iso = current_season_start_iso()
	var archetype := archetype_by_id(aid)
	if archetype.is_empty():
		return {}
	var defaults: Dictionary = {}
	var default_raw: Variant = _MarathonRouteCatalog.get_catalog_field("default", {})
	if default_raw is Dictionary:
		defaults = default_raw.duplicate(true)
	var merged := defaults.duplicate(true)
	for key in archetype:
		if key in [
			"archetype_id", "title_key", "subtitle_key", "tagline_key", "idea_key",
			"icon_emoji", "sort_order", "persistent", "mod_rotation", "mod_pool",
		]:
			continue
		merged[key] = archetype[key]
	merged["route_id"] = route_id_for(aid, start_iso)
	merged["route_type"] = ROUTE_TYPE_SEASON
	merged["archetype_id"] = aid
	merged["season_start"] = start_iso
	merged["season_seed"] = _seed_number("%s_%s" % [start_iso, aid])
	var genre_pick := _MarathonGenrePicker.pick_genre_for_template(merged, start_iso, aid)
	merged["genre_group_id"] = genre_pick.get("genre_id", "")
	merged["source_type"] = _MarathonRouteCatalog.SOURCE_TYPE_GENRE
	merged["source_id"] = str(merged.get("genre_group_id", ""))
	merged["genre_fallback"] = genre_pick.get("used_fallback", false)
	merged["genre_preferred"] = genre_pick.get("preferred_id", "")
	if bool(archetype.get("mod_rotation", false)):
		var mod_id := _pick_mod(start_iso, aid, archetype)
		if mod_id != "":
			merged["mod_policy_locked"] = true
			merged["fixed_modifiers"] = [mod_id]
	if not merged.has("badges") or not merged.get("badges") is Dictionary:
		merged["badges"] = _default_badges_for_archetype(aid)
	merged["title_key"] = str(archetype.get("title_key", ""))
	merged["subtitle_key"] = str(archetype.get("subtitle_key", ""))
	merged["tagline_key"] = str(archetype.get("tagline_key", ""))
	merged["idea_key"] = str(archetype.get("idea_key", ""))
	merged["length_class"] = str(archetype.get("length_class", "standard"))
	return _MarathonRouteRolls.apply_to_template(
		_MarathonRouteCatalog.sanitize_template(merged),
		"%s_%s_rolls" % [start_iso, aid]
	)


static func current_fill_line(template: Dictionary) -> String:
	return TranslationServer.translate("MARATHON_SEASON_NOW_FMT") % _fill_summary(template)


static func fill_summary_line(template: Dictionary) -> String:
	return _fill_summary(template)


static func _fill_summary(template: Dictionary) -> String:
	var genre_id := str(template.get("genre_group_id", "")).strip_edges()
	var genre_name := TranslationServer.translate(_ProfileGenrePortrait.group_locale_key(genre_id))
	var parts: PackedStringArray = [genre_name]
	var mods: Array = template.get("fixed_modifiers", [])
	if not mods.is_empty():
		const RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
		var mod_names: PackedStringArray = []
		for mod_id in mods:
			mod_names.append(TranslationServer.translate(RunModifiers.title_i18n_key(str(mod_id))))
		parts.append(", ".join(mod_names))
	var rules_text := MarathonRunRules.preview_text(template)
	if rules_text.strip_edges() != "":
		parts.append(rules_text)
	return ", ".join(parts)


static func preview_line_for_meta(route_meta: Dictionary) -> String:
	var template: Variant = route_meta.get("template", {})
	if template is Dictionary:
		return fill_summary_line(template as Dictionary)
	var aid := str(route_meta.get("archetype_id", ""))
	if aid == "":
		return ""
	return current_fill_line(build_template(aid, str(route_meta.get("season_start", current_season_start_iso()))))


static func next_season_preview_lines() -> PackedStringArray:
	var next_iso := next_season_start_iso()
	var lines: PackedStringArray = []
	for archetype in all_archetypes():
		var aid := str(archetype.get("archetype_id", "")).strip_edges()
		if aid == "":
			continue
		var title := TranslationServer.translate(str(archetype.get("title_key", aid)))
		var template := build_template(aid, next_iso)
		var fill := _fill_summary(template)
		lines.append("%s · %s" % [title, fill])
	return lines


static func _pick_mod(season_start_iso: String, archetype_id: String, archetype: Dictionary) -> String:
	var pool: Array = archetype.get("mod_pool", MOD_ROTATION_POOL)
	if pool.is_empty():
		pool = MOD_ROTATION_POOL
	var rng := _seeded_rng("%s_%s_mod" % [season_start_iso, archetype_id])
	return str(pool[rng.randi_range(0, maxi(0, pool.size() - 1))]).strip_edges()


static func _default_badges_for_archetype(archetype_id: String) -> Dictionary:
	match str(archetype_id).strip_edges():
		"boss_rush":
			return {
				"bronze": "complete",
				"silver": "avg_accuracy_90",
				"gold": "precision_master",
				"platinum": "perfect_route",
			}
		"precision":
			return {"bronze": "complete", "silver": "avg_accuracy_90", "gold": "precision_master"}
		"chaos":
			return {"bronze": "complete", "silver": "avg_accuracy_85", "gold": "avg_accuracy_90"}
		"accelerando":
			return {
				"bronze": "complete",
				"silver": "avg_accuracy_90",
				"gold": "iron_hands",
				"platinum": "encore",
			}
		"journey", "weekly":
			return {"bronze": "complete", "silver": "avg_accuracy_90", "gold": "perfect_route"}
		"ultimate":
			return {
				"bronze": "complete",
				"silver": "avg_accuracy_90",
				"gold": "iron_hands",
				"platinum": "perfect_route",
				"legend": "encore",
			}
		_:
			return {"bronze": "complete", "silver": "avg_accuracy_90", "gold": "encore"}


static func _sanitize_archetype(raw: Dictionary) -> Dictionary:
	var aid := str(raw.get("archetype_id", "")).strip_edges()
	if aid == "":
		return {}
	var out := raw.duplicate(true)
	out["archetype_id"] = aid
	out["sort_order"] = int(raw.get("sort_order", 999))
	out["persistent"] = bool(raw.get("persistent", true))
	out["mod_rotation"] = bool(raw.get("mod_rotation", false))
	return out


static func _season_config() -> Dictionary:
	var raw: Variant = _MarathonRouteCatalog.get_catalog_field("season", {})
	if raw is Dictionary:
		return raw as Dictionary
	return {"enabled": true, "period_days": DEFAULT_PERIOD_DAYS, "anchor_iso": DEFAULT_ANCHOR_ISO}


static func _today_iso_date() -> String:
	var parts := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [
		int(parts.get("year", 2000)),
		int(parts.get("month", 1)),
		int(parts.get("day", 1)),
	]


static func _season_start_iso_for_date(iso_date: String) -> String:
	var anchor := str(_season_config().get("anchor_iso", DEFAULT_ANCHOR_ISO)).strip_edges()
	var period := period_days()
	var days := _days_between_iso(anchor, iso_date)
	if days < 0:
		return anchor
	var period_index := int(float(days) / float(period))
	return _add_days_iso(anchor, period_index * period)


static func _days_between_iso(from_iso: String, to_iso: String) -> int:
	var from_unix := TimeUtils.unix_from_local_iso_datetime("%s 00:00:00" % from_iso)
	var to_unix := TimeUtils.unix_from_local_iso_datetime("%s 00:00:00" % to_iso)
	if from_unix <= 0 or to_unix <= 0:
		return 0
	return int((to_unix - from_unix) / 86400)


static func _add_days_iso(iso_date: String, days: int) -> String:
	var unix := TimeUtils.unix_from_local_iso_datetime("%s 12:00:00" % iso_date)
	if unix <= 0:
		return iso_date
	var dt := Time.get_datetime_dict_from_unix_time(unix + days * 86400)
	return "%04d-%02d-%02d" % [
		int(dt.get("year", 2000)),
		int(dt.get("month", 1)),
		int(dt.get("day", 1)),
	]


static func _seed_number(key: String) -> int:
	return int(absi(str(key).hash()))


static func _seeded_rng(key: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_number(key)
	return rng
