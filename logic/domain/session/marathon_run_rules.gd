# logic/domain/session/marathon_run_rules.gd
class_name MarathonRunRules
extends RefCounted

const _EndlessSessionConfig = preload("res://logic/domain/session/endless_session_config.gd")

const FAIL_REASON_MIN_ACCURACY := "rule_min_accuracy"
const FAIL_REASON_MAX_MISSES := "rule_max_misses"

const DEFAULT_HP_RECOVERY_PCT := 100
const UNLIMITED_MISSES := -1


static func parse(template: Dictionary) -> Dictionary:
	var rule_ids := _sanitize_rule_ids(template.get("run_rules", []))
	var hp_pct := DEFAULT_HP_RECOVERY_PCT
	if template.has("inter_track_hp_recovery_pct"):
		hp_pct = _EndlessSessionConfig.normalize_inter_track_hp_recovery_pct(
			template.get("inter_track_hp_recovery_pct", DEFAULT_HP_RECOVERY_PCT)
		)
	var max_misses := UNLIMITED_MISSES
	var min_accuracy := 0.0
	if template.has("max_misses_total"):
		max_misses = maxi(0, int(template.get("max_misses_total", UNLIMITED_MISSES)))
	if template.has("min_accuracy_per_track"):
		min_accuracy = clampf(float(template.get("min_accuracy_per_track", 0.0)), 0.0, 100.0)
	for rule_id in rule_ids:
		var rid := str(rule_id).strip_edges()
		if rid.begins_with("hp_recovery_"):
			hp_pct = _parse_hp_recovery_rule(rid, hp_pct)
		elif rid.begins_with("max_misses_"):
			max_misses = _parse_max_misses_rule(rid, max_misses)
		elif rid.begins_with("min_accuracy_"):
			min_accuracy = maxf(min_accuracy, _parse_min_accuracy_rule(rid))
	return {
		"rule_ids": rule_ids,
		"inter_track_hp_recovery_pct": hp_pct,
		"max_misses_total": max_misses,
		"min_accuracy_per_track": min_accuracy,
	}


static func check_after_track(stats: Dictionary, total_missed_notes: int, rules: Dictionary) -> Dictionary:
	var min_accuracy := float(rules.get("min_accuracy_per_track", 0.0))
	if min_accuracy > 0.0:
		var accuracy := float(stats.get("accuracy", 0.0))
		if accuracy + 0.001 < min_accuracy:
			return {
				"ok": false,
				"reason": FAIL_REASON_MIN_ACCURACY,
				"detail": min_accuracy,
			}
	var max_misses := int(rules.get("max_misses_total", UNLIMITED_MISSES))
	if max_misses >= 0 and total_missed_notes > max_misses:
		return {
			"ok": false,
			"reason": FAIL_REASON_MAX_MISSES,
			"detail": max_misses,
		}
	return {"ok": true, "reason": ""}


static func preview_parts(rules: Dictionary) -> PackedStringArray:
	var parts: PackedStringArray = []
	var hp_pct := int(rules.get("inter_track_hp_recovery_pct", DEFAULT_HP_RECOVERY_PCT))
	if hp_pct < 100:
		parts.append(
			TranslationServer.translate("MARATHON_RUN_RULE_HP_RECOVERY_FMT")
			% _EndlessSessionConfig.format_inter_track_hp_recovery_pct(hp_pct)
		)
	var max_misses := int(rules.get("max_misses_total", UNLIMITED_MISSES))
	if max_misses >= 0:
		parts.append(TranslationServer.translate("MARATHON_RUN_RULE_MAX_MISSES_FMT") % max_misses)
	var min_accuracy := float(rules.get("min_accuracy_per_track", 0.0))
	if min_accuracy > 0.0:
		parts.append(TranslationServer.translate("MARATHON_RUN_RULE_MIN_ACCURACY_FMT") % int(round(min_accuracy)))
	return parts


static func preview_text(template: Dictionary) -> String:
	var parts := preview_parts(parse(template))
	if parts.is_empty():
		return TranslationServer.translate("MARATHON_RUN_RULES_NONE")
	return ", ".join(parts)


static func preview_items(template: Dictionary) -> Array[Dictionary]:
	return preview_items_for_template(template)


static func preview_items_for_template(template: Dictionary) -> Array[Dictionary]:
	var rules := parse(template)
	var items: Array[Dictionary] = []
	var hp_pct := int(rules.get("inter_track_hp_recovery_pct", DEFAULT_HP_RECOVERY_PCT))
	if hp_pct < 100:
		items.append({
			"icon": "heart-pulse.svg",
			"text": TranslationServer.translate("MARATHON_RUN_RULE_HP_RECOVERY_FMT")
				% _EndlessSessionConfig.format_inter_track_hp_recovery_pct(hp_pct),
			"tint": Color(0.92, 0.48, 0.52, 1.0),
		})
	else:
		items.append({
			"icon": "heart.svg",
			"text": TranslationServer.translate("MARATHON_RUN_RULE_HP_CARRIES"),
			"tint": Color(0.92, 0.58, 0.62, 1.0),
		})
	var max_misses := int(rules.get("max_misses_total", UNLIMITED_MISSES))
	if max_misses >= 0:
		items.append({
			"icon": "ban.svg",
			"text": TranslationServer.translate("MARATHON_RUN_RULE_MAX_MISSES_FMT") % max_misses,
			"tint": Color(0.95, 0.62, 0.42, 1.0),
		})
	var min_accuracy := float(rules.get("min_accuracy_per_track", 0.0))
	if min_accuracy > 0.0:
		items.append({
			"icon": "crosshair.svg",
			"text": TranslationServer.translate("MARATHON_RUN_RULE_MIN_ACCURACY_FMT") % int(round(min_accuracy)),
			"tint": Color(0.58, 0.82, 0.96, 1.0),
		})
	return items


static func _sanitize_rule_ids(raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if raw is Array:
		for item in raw:
			var rule_id := str(item).strip_edges()
			if rule_id == "" or out.has(rule_id):
				continue
			out.append(rule_id)
	return out


static func _parse_hp_recovery_rule(rule_id: String, current: int) -> int:
	var suffix := rule_id.substr("hp_recovery_".length())
	if suffix == "0" or suffix == "none":
		return 0
	return _EndlessSessionConfig.normalize_inter_track_hp_recovery_pct(int(suffix))


static func _parse_max_misses_rule(rule_id: String, current: int) -> int:
	var suffix := rule_id.substr("max_misses_".length())
	if suffix.is_valid_int():
		return maxi(0, int(suffix))
	return current


static func _parse_min_accuracy_rule(rule_id: String) -> float:
	var suffix := rule_id.substr("min_accuracy_".length())
	if suffix.is_valid_float() or suffix.is_valid_int():
		return clampf(float(suffix), 0.0, 100.0)
	return 0.0
