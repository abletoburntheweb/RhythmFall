# logic/domain/session/marathon_route_badges.gd
class_name MarathonRouteBadges
extends RefCounted

const TIER_BRONZE := "bronze"
const TIER_SILVER := "silver"
const TIER_GOLD := "gold"
const TIER_PLATINUM := "platinum"
const TIER_LEGEND := "legend"

const TIER_ORDER: Array[String] = [
	TIER_BRONZE,
	TIER_SILVER,
	TIER_GOLD,
	TIER_PLATINUM,
	TIER_LEGEND,
]

const CONDITION_COMPLETE := "complete"
const CONDITION_AVG_ACCURACY_85 := "avg_accuracy_85"
const CONDITION_AVG_ACCURACY_90 := "avg_accuracy_90"
const CONDITION_PERFECT_ROUTE := "perfect_route"
const CONDITION_IRON_HANDS := "iron_hands"
const CONDITION_ENCORE := "encore"
const CONDITION_PRECISION_MASTER := "precision_master"
const CONDITION_MIRROR_MASTER := "mirror_master"
const CONDITION_HIDDEN_MASTER := "hidden_master"

## Iron Hands: never drop below this HP ratio after any track.
const IRON_HANDS_MIN_HP_RATIO := 0.40
## Encore ("on the edge"): stretch accuracy goal.
const ENCORE_AVG_ACCURACY := 95.0

const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")


static func badge_defs_for_template(route_id: String, template: Dictionary) -> Dictionary:
	var raw: Variant = template.get("badges", {})
	if raw is Dictionary and not (raw as Dictionary).is_empty():
		return _normalize_badge_defs(raw as Dictionary)
	return _default_badge_defs(route_id)


static func active_tiers_for_template(route_id: String, template: Dictionary) -> Array[String]:
	var defs := badge_defs_for_template(route_id, template)
	var out: Array[String] = []
	for tier in TIER_ORDER:
		if str(defs.get(tier, "")).strip_edges() != "":
			out.append(tier)
	return out


static func medal_def(route_id: String, tier: String, template: Dictionary) -> Dictionary:
	var defs := badge_defs_for_template(route_id, template)
	var raw: Variant = defs.get(tier, "")
	var condition := ""
	var name_key := ""
	if raw is Dictionary:
		condition = str(raw.get("condition", "")).strip_edges()
		name_key = str(raw.get("name_key", "")).strip_edges()
	else:
		condition = str(raw).strip_edges()
	if name_key == "":
		name_key = _default_medal_name_key(route_id, tier, condition)
	return {
		"tier": tier,
		"condition": condition,
		"name_key": name_key,
		"desc_key": condition_preview_key(condition),
	}


static func medal_name(route_id: String, tier: String, template: Dictionary) -> String:
	var def := medal_def(route_id, tier, template)
	return TranslationServer.translate(str(def.get("name_key", "")))


static func medal_description(route_id: String, tier: String, template: Dictionary) -> String:
	var def := medal_def(route_id, tier, template)
	return TranslationServer.translate(str(def.get("desc_key", "")))


static func medal_tooltip(route_id: String, tier: String, template: Dictionary) -> String:
	var name := medal_name(route_id, tier, template)
	var desc := medal_description(route_id, tier, template)
	if desc == "":
		return name
	return "%s\n%s" % [name, desc]


static func evaluate(route_id: String, summary: Dictionary) -> Dictionary:
	var template: Dictionary = summary.get("template", {}) if summary.get("template") is Dictionary else {}
	var defs := badge_defs_for_template(route_id, template)
	var earned: Array[String] = []
	for tier in TIER_ORDER:
		var condition := _tier_condition(defs, tier)
		if condition == "":
			continue
		if _condition_met(condition, summary):
			earned.append(tier)
	var highest := highest_tier(earned)
	return {
		"earned": earned,
		"highest_tier": highest,
		"defs": defs,
	}


static func highest_tier(badges: Array) -> String:
	var best_idx := -1
	for badge_id in badges:
		var tier := str(badge_id).strip_edges()
		var idx := TIER_ORDER.find(tier)
		if idx > best_idx:
			best_idx = idx
	if best_idx < 0:
		return ""
	return TIER_ORDER[best_idx]


static func tier_label_key(tier: String) -> String:
	match str(tier).strip_edges():
		TIER_SILVER:
			return "MARATHON_BADGE_SILVER"
		TIER_GOLD:
			return "MARATHON_BADGE_GOLD"
		TIER_PLATINUM:
			return "MARATHON_BADGE_PLATINUM"
		TIER_LEGEND:
			return "MARATHON_BADGE_LEGEND"
		_:
			return "MARATHON_BADGE_BRONZE"


static func tier_accent(tier: String) -> Color:
	match str(tier).strip_edges():
		TIER_SILVER:
			return Color(0.78, 0.84, 0.94, 1.0)
		TIER_GOLD:
			return Color(0.96, 0.78, 0.34, 1.0)
		TIER_PLATINUM:
			return Color(0.72, 0.88, 0.98, 1.0)
		TIER_LEGEND:
			return Color(0.86, 0.62, 0.98, 1.0)
		_:
			return Color(0.78, 0.52, 0.28, 1.0)


static func tier_icon_file(tier: String) -> String:
	match str(tier).strip_edges():
		TIER_SILVER:
			return "star.svg"
		TIER_GOLD:
			return "crown.svg"
		TIER_PLATINUM:
			return "diamond.svg"
		TIER_LEGEND:
			return "sparkles.svg"
		_:
			return "disc-3.svg"


static func condition_preview_key(condition: String) -> String:
	return _condition_preview_key(condition)


static func tier_route_label_key(route_id: String, tier: String) -> String:
	return _default_medal_name_key(route_id, tier, "")


static func format_earned_badges(route_id: String, badges: Array, template: Dictionary = {}) -> String:
	if badges.is_empty():
		return ""
	var tpl := template
	if tpl.is_empty() and route_id != "":
		const MarathonRouteCatalog = preload("res://logic/domain/session/marathon_route_catalog.gd")
		tpl = MarathonRouteCatalog.template_for_route(route_id)
	var parts: PackedStringArray = []
	for tier in TIER_ORDER:
		if badges.has(tier):
			parts.append(medal_name(route_id, tier, tpl))
	return ", ".join(parts)


static func format_badge_defs_preview(route_id: String, template: Dictionary) -> String:
	var parts: PackedStringArray = []
	for tier in active_tiers_for_template(route_id, template):
		parts.append(medal_name(route_id, tier, template))
	if parts.is_empty():
		return TranslationServer.translate("MARATHON_BADGE_PREVIEW_NONE")
	return " · ".join(parts)


static func _default_badge_defs(route_id: String) -> Dictionary:
	var rid := str(route_id).strip_edges().to_lower()
	var gold := CONDITION_PERFECT_ROUTE
	var platinum := CONDITION_ENCORE
	if rid.ends_with("_survival"):
		gold = CONDITION_IRON_HANDS
		platinum = CONDITION_ENCORE
	elif rid.ends_with("_precision"):
		gold = CONDITION_PRECISION_MASTER
		platinum = CONDITION_PERFECT_ROUTE
	elif rid.contains("mirror"):
		gold = CONDITION_MIRROR_MASTER
		platinum = CONDITION_AVG_ACCURACY_90
	elif rid.contains("hidden"):
		gold = CONDITION_HIDDEN_MASTER
		platinum = CONDITION_AVG_ACCURACY_90
	elif rid.ends_with("_boss_rush"):
		gold = CONDITION_PRECISION_MASTER
		platinum = CONDITION_PERFECT_ROUTE
	return {
		TIER_BRONZE: CONDITION_COMPLETE,
		TIER_SILVER: CONDITION_AVG_ACCURACY_90,
		TIER_GOLD: gold,
	}


static func _default_medal_name_key(route_id: String, tier: String, condition: String) -> String:
	var rid := str(route_id).strip_edges().to_upper()
	var cond := str(condition).strip_edges()
	match str(tier).strip_edges():
		TIER_GOLD:
			if cond == CONDITION_IRON_HANDS or rid.contains("SURVIVAL"):
				return "MARATHON_MEDAL_NAME_IRON_HANDS"
			if cond == CONDITION_PRECISION_MASTER or rid.contains("PRECISION"):
				return "MARATHON_MEDAL_NAME_PRECISION_MASTER"
			if cond == CONDITION_MIRROR_MASTER or rid.contains("MIRROR"):
				return "MARATHON_MEDAL_NAME_MIRROR_MASTER"
			if cond == CONDITION_HIDDEN_MASTER or rid.contains("HIDDEN"):
				return "MARATHON_MEDAL_NAME_HIDDEN_MASTER"
			if cond == CONDITION_AVG_ACCURACY_85:
				return "MARATHON_MEDAL_NAME_SHARP_SHOOTER"
			return "MARATHON_MEDAL_NAME_ROUTE_MASTER"
		TIER_PLATINUM:
			if cond == CONDITION_ENCORE:
				return "MARATHON_MEDAL_NAME_ENCORE"
			if cond == CONDITION_PERFECT_ROUTE:
				return "MARATHON_MEDAL_NAME_FLAWLESS"
			return "MARATHON_MEDAL_NAME_ELITE"
		TIER_LEGEND:
			if cond == CONDITION_PERFECT_ROUTE:
				return "MARATHON_MEDAL_NAME_FLAWLESS"
			return "MARATHON_MEDAL_NAME_LEGEND"
		TIER_SILVER:
			return "MARATHON_MEDAL_NAME_STEADY_RUN"
		_:
			return "MARATHON_MEDAL_NAME_ROUTE_CLEAR"


static func _normalize_badge_defs(raw: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for tier in TIER_ORDER:
		var condition: Variant = raw.get(tier, "")
		if condition is Dictionary:
			var entry: Dictionary = (condition as Dictionary).duplicate(true)
			entry["condition"] = str(entry.get("condition", "")).strip_edges()
			if entry["condition"] != "":
				out[tier] = entry
			continue
		var key := str(condition).strip_edges()
		if key != "":
			out[tier] = key
	return out


static func _tier_condition(defs: Dictionary, tier: String) -> String:
	var raw: Variant = defs.get(tier, "")
	if raw is Dictionary:
		return str((raw as Dictionary).get("condition", "")).strip_edges()
	return str(raw).strip_edges()


static func _condition_preview_key(condition: String) -> String:
	match str(condition).strip_edges():
		CONDITION_AVG_ACCURACY_85:
			return "MARATHON_MEDAL_DESC_AVG_85"
		CONDITION_AVG_ACCURACY_90:
			return "MARATHON_MEDAL_DESC_AVG_90"
		CONDITION_PERFECT_ROUTE:
			return "MARATHON_MEDAL_DESC_PERFECT"
		CONDITION_IRON_HANDS:
			return "MARATHON_MEDAL_DESC_IRON_HANDS"
		CONDITION_ENCORE:
			return "MARATHON_MEDAL_DESC_ENCORE"
		CONDITION_PRECISION_MASTER:
			return "MARATHON_MEDAL_DESC_PRECISION"
		CONDITION_MIRROR_MASTER:
			return "MARATHON_MEDAL_DESC_MIRROR"
		CONDITION_HIDDEN_MASTER:
			return "MARATHON_MEDAL_DESC_HIDDEN"
		_:
			return "MARATHON_MEDAL_DESC_COMPLETE"


static func _condition_met(condition: String, summary: Dictionary) -> bool:
	if not _is_victory(summary):
		return false
	match str(condition).strip_edges():
		CONDITION_COMPLETE:
			return true
		CONDITION_AVG_ACCURACY_85:
			return float(summary.get("average_accuracy", 0.0)) >= 85.0
		CONDITION_AVG_ACCURACY_90:
			return float(summary.get("average_accuracy", 0.0)) >= 90.0
		CONDITION_PERFECT_ROUTE:
			return int(summary.get("total_missed_notes", 0)) <= 0
		CONDITION_IRON_HANDS:
			var telemetry: Dictionary = summary.get("run_telemetry", {}) if summary.get("run_telemetry") is Dictionary else {}
			return float(telemetry.get("min_hp_ratio", 0.0)) >= IRON_HANDS_MIN_HP_RATIO
		CONDITION_ENCORE:
			return float(summary.get("average_accuracy", 0.0)) >= ENCORE_AVG_ACCURACY
		CONDITION_PRECISION_MASTER:
			return float(summary.get("average_accuracy", 0.0)) >= 92.0
		CONDITION_MIRROR_MASTER:
			return _route_used_modifier(summary, _RunModifiers.ID_MIRROR_MODE)
		CONDITION_HIDDEN_MASTER:
			return _route_used_modifier(summary, _RunModifiers.ID_HIDDEN)
		_:
			return false


static func _is_victory(summary: Dictionary) -> bool:
	return str(summary.get("reason", "")).strip_edges() == "victory"


static func _route_used_modifier(summary: Dictionary, modifier_id: String) -> bool:
	var want := str(modifier_id).strip_edges()
	if want == "":
		return false
	var log: Variant = summary.get("tracks_log", [])
	if log is Array and not (log as Array).is_empty():
		for entry in log as Array:
			if entry is not Dictionary:
				return false
			var mods: Variant = (entry as Dictionary).get("modifiers", [])
			if mods is not Array or not _RunModifiers.has_modifier(mods as Array, want):
				return false
		return true
	# Preview / incomplete summary: fall back to locked route mods.
	var template: Dictionary = summary.get("template", {}) if summary.get("template") is Dictionary else {}
	var fixed: Variant = template.get("fixed_modifiers", [])
	if fixed is Array and _RunModifiers.has_modifier(fixed as Array, want):
		return true
	var run_config: Dictionary = summary.get("run_config", {}) if summary.get("run_config") is Dictionary else {}
	var cfg_mods: Variant = run_config.get("modifiers", run_config.get("fixed_modifiers", []))
	if cfg_mods is Array and _RunModifiers.has_modifier(cfg_mods as Array, want):
		return true
	return false
