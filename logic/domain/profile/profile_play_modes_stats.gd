class_name ProfilePlayModesStats
extends RefCounted

const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const _MarathonRouteCatalog = preload("res://logic/domain/session/marathon_route_catalog.gd")
const _MarathonRouteCharacter = preload("res://logic/domain/session/marathon_route_character.gd")
const _MarathonRouteBadges = preload("res://logic/domain/session/marathon_route_badges.gd")

const MOD_STAT_SPECS: Array = [
	["clears_hidden", _RunModifiers.ID_HIDDEN],
	["clears_sudden", _RunModifiers.ID_SUDDEN],
	["clears_sudden_death", _RunModifiers.ID_SUDDEN_DEATH],
	["clears_no_miss_forgiveness", _RunModifiers.ID_NO_MISS_FORGIVENESS],
	["clears_strict_timing", _RunModifiers.ID_STRICT_TIMING],
	["clears_memory_mode", _RunModifiers.ID_MEMORY_MODE],
	["clears_dynamic_lanes", _RunModifiers.ID_DYNAMIC_LANES],
	["clears_lane_remap", _RunModifiers.ID_MIRROR_MODE],
	["clears_combo_escalation", _RunModifiers.ID_COMBO_ESCALATION],
	["clears_metronome_only", _RunModifiers.ID_METRONOME_ONLY],
	["clears_reverse_scroll", _RunModifiers.ID_REVERSE_SCROLL],
	["clears_time_warp", _RunModifiers.ID_TIME_WARP],
	["clears_pick_mode", _RunModifiers.ID_PICK_MODE],
]


static func marathon_summary() -> Dictionary:
	var completions := _marathon_completions()
	var routes_attempted := 0
	var routes_completed := 0
	var total_badges := 0
	var best_tier := ""
	for route_id in completions.keys():
		var entry: Variant = completions.get(route_id, {})
		if not entry is Dictionary:
			continue
		var ratio := float((entry as Dictionary).get("best_ratio", 0.0))
		if ratio <= 0.0:
			continue
		routes_attempted += 1
		if ratio >= 0.999:
			routes_completed += 1
		var badges: Variant = (entry as Dictionary).get("badges", [])
		if badges is Array:
			total_badges += (badges as Array).size()
		var tier := str((entry as Dictionary).get("best_badge_tier", ""))
		if _MarathonRouteBadges.TIER_ORDER.find(tier) > _MarathonRouteBadges.TIER_ORDER.find(best_tier):
			best_tier = tier
	return {
		"routes_attempted": routes_attempted,
		"routes_completed": routes_completed,
		"total_badges": total_badges,
		"best_badge_tier": best_tier,
	}


static func mod_summary() -> Dictionary:
	var stats := _modifier_stats()
	var clears_any := int(stats.get("clears_any", 0))
	var mods_used := 0
	var top_mod_id := ""
	var top_mod_count := 0
	for spec in MOD_STAT_SPECS:
		var count := int(stats.get(str(spec[0]), 0))
		if count <= 0:
			continue
		mods_used += 1
		if count > top_mod_count:
			top_mod_count = count
			top_mod_id = str(spec[1])
	var hardest_stack := 0
	for threshold in [5, 4, 3, 2]:
		if int(stats.get("clears_%dplus" % threshold, 0)) > 0:
			hardest_stack = threshold
			break
	return {
		"clears_any": clears_any,
		"mods_used": mods_used,
		"top_mod_id": top_mod_id,
		"top_mod_count": top_mod_count,
		"hardest_stack": hardest_stack,
	}


static func mods_mastered_count() -> int:
	var stats := _modifier_stats()
	var count := 0
	for spec in MOD_STAT_SPECS:
		if int(stats.get(str(spec[0]), 0)) > 0:
			count += 1
	return count


static func marathon_record_entries() -> Array[Dictionary]:
	var completions := _marathon_completions()
	var out: Array[Dictionary] = []
	for route_id_raw in completions.keys():
		var route_id := str(route_id_raw).strip_edges()
		var entry: Variant = completions.get(route_id_raw, {})
		if route_id == "" or not entry is Dictionary:
			continue
		var ratio := float((entry as Dictionary).get("best_ratio", 0.0))
		if ratio <= 0.0:
			continue
		var badges: Array = []
		var badges_raw: Variant = (entry as Dictionary).get("badges", [])
		if badges_raw is Array:
			badges = badges_raw as Array
		out.append({
			"route_id": route_id,
			"title": route_display_title_light(route_id),
			"best_ratio": ratio,
			"best_acc": float((entry as Dictionary).get("best_acc", 0.0)),
			"badges": badges,
			"best_badge_tier": str((entry as Dictionary).get("best_badge_tier", "")),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ratio_a := float(a.get("best_ratio", 0.0))
		var ratio_b := float(b.get("best_ratio", 0.0))
		if absf(ratio_a - ratio_b) > 0.0001:
			return ratio_a > ratio_b
		return str(a.get("title", "")) < str(b.get("title", ""))
	)
	return out


static func mod_clear_entries() -> Array[Dictionary]:
	var stats := _modifier_stats()
	var out: Array[Dictionary] = []
	for spec in MOD_STAT_SPECS:
		var stat_key := str(spec[0])
		var mod_id := str(spec[1])
		var count := int(stats.get(stat_key, 0))
		if count <= 0:
			continue
		out.append({"mod_id": mod_id, "count": count})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var count_a := int(a.get("count", 0))
		var count_b := int(b.get("count", 0))
		if count_a != count_b:
			return count_a > count_b
		return str(a.get("mod_id", "")) < str(b.get("mod_id", ""))
	)
	return out


static func route_display_title(route_id: String) -> String:
	return route_display_title_light(route_id)


static func route_display_title_light(route_id: String) -> String:
	var rid := str(route_id).strip_edges()
	if rid == "":
		return ""
	const MarathonDailyRoute = preload("res://logic/domain/session/marathon_daily_route.gd")
	if MarathonDailyRoute.is_daily_route(rid):
		return TranslationServer.translate("MARATHON_DAILY_TITLE")
	const MarathonSeason = preload("res://logic/domain/session/marathon_season.gd")
	if MarathonSeason.is_season_route(rid):
		var route := _MarathonRouteCatalog.route_by_id(rid)
		var title_key := str(route.get("title_key", "")).strip_edges()
		if title_key != "":
			return TranslationServer.translate(title_key)
		return rid
	var route := _MarathonRouteCatalog.route_by_id(rid)
	if route.is_empty():
		return rid
	var title_key := str(route.get("title_key", "")).strip_edges()
	if title_key != "":
		var emoji := str(route.get("icon_emoji", "")).strip_edges()
		var title := TranslationServer.translate(title_key)
		if emoji != "":
			return "%s %s" % [emoji, title]
		return title
	return rid


static func route_display_title_full(route_id: String) -> String:
	var rid := str(route_id).strip_edges()
	if rid == "":
		return ""
	var route := _MarathonRouteCatalog.route_by_id(rid)
	if route.is_empty():
		return rid
	var template := _MarathonRouteCatalog.template_for_route(rid)
	if not template.is_empty():
		return _MarathonRouteCharacter.display_title(template, route)
	var title_key := str(route.get("title_key", "")).strip_edges()
	if title_key != "":
		return TranslationServer.translate(title_key)
	return rid


static func badge_tier_label(tier: String) -> String:
	var key := ""
	match tier:
		_MarathonRouteBadges.TIER_BRONZE:
			key = "MARATHON_BADGE_BRONZE"
		_MarathonRouteBadges.TIER_SILVER:
			key = "MARATHON_BADGE_SILVER"
		_MarathonRouteBadges.TIER_GOLD:
			key = "MARATHON_BADGE_GOLD"
		_MarathonRouteBadges.TIER_PLATINUM:
			key = "MARATHON_BADGE_PLATINUM"
		_MarathonRouteBadges.TIER_LEGEND:
			key = "MARATHON_BADGE_LEGEND"
	if key == "":
		return ""
	return TranslationServer.translate(key)


static func mod_label(mod_id: String, tr_fn: Callable) -> String:
	var ids: Array[String] = [str(mod_id)]
	return _RunModifiers.format_abbr_list(ids, tr_fn)


static func _marathon_completions() -> Dictionary:
	if PlayerDataManager == null:
		return {}
	var raw: Variant = PlayerDataManager.data.get("marathon_completions", {})
	if raw is Dictionary:
		return raw as Dictionary
	return {}


static func _modifier_stats() -> Dictionary:
	if PlayerDataManager == null or not PlayerDataManager.has_method("get_modifier_stats"):
		return {}
	return PlayerDataManager.get_modifier_stats()
