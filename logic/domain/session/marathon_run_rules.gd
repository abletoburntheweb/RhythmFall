# logic/domain/session/marathon_run_rules.gd
class_name MarathonRunRules
extends RefCounted

const _EndlessSessionConfig = preload("res://logic/domain/session/endless_session_config.gd")

const FAIL_REASON_MIN_ACCURACY := "rule_min_accuracy"
const FAIL_REASON_MAX_MISSES := "rule_max_misses"
const FAIL_REASON_MAX_GOOD_NOTES := "rule_max_good_notes"
const FAIL_REASON_MIN_STREAK := "rule_min_streak"

const DEFAULT_HP_RECOVERY_PCT := 100
const UNLIMITED_MISSES := -1
const UNLIMITED_GOOD_NOTES := -1
const NO_STREAK_REQUIREMENT := 0


static func parse(template: Dictionary) -> Dictionary:
	var rule_ids := _sanitize_rule_ids(template.get("run_rules", []))
	var hp_pct := DEFAULT_HP_RECOVERY_PCT
	if template.has("inter_track_hp_recovery_pct"):
		hp_pct = _EndlessSessionConfig.normalize_inter_track_hp_recovery_pct(
			template.get("inter_track_hp_recovery_pct", DEFAULT_HP_RECOVERY_PCT)
		)
	var max_misses := UNLIMITED_MISSES
	var min_accuracy := 0.0
	var max_good_notes := UNLIMITED_GOOD_NOTES
	var min_streak := NO_STREAK_REQUIREMENT
	if template.has("max_misses_total"):
		max_misses = maxi(0, int(template.get("max_misses_total", UNLIMITED_MISSES)))
	if template.has("min_accuracy_per_track"):
		min_accuracy = clampf(float(template.get("min_accuracy_per_track", 0.0)), 0.0, 100.0)
	if template.has("max_good_notes_total"):
		max_good_notes = maxi(0, int(template.get("max_good_notes_total", UNLIMITED_GOOD_NOTES)))
	if template.has("min_streak_per_track"):
		min_streak = maxi(0, int(template.get("min_streak_per_track", NO_STREAK_REQUIREMENT)))
	for rule_id in rule_ids:
		var rid := str(rule_id).strip_edges()
		if rid.begins_with("hp_recovery_"):
			hp_pct = _parse_hp_recovery_rule(rid, hp_pct)
		elif rid.begins_with("max_misses_"):
			max_misses = _parse_max_misses_rule(rid, max_misses)
		elif rid.begins_with("min_accuracy_"):
			min_accuracy = maxf(min_accuracy, _parse_min_accuracy_rule(rid))
		elif rid.begins_with("max_good_notes_"):
			max_good_notes = _parse_max_good_notes_rule(rid, max_good_notes)
		elif rid.begins_with("min_streak_"):
			min_streak = maxi(min_streak, _parse_min_streak_rule(rid))
	return {
		"rule_ids": rule_ids,
		"inter_track_hp_recovery_pct": hp_pct,
		"max_misses_total": max_misses,
		"min_accuracy_per_track": min_accuracy,
		"max_good_notes_total": max_good_notes,
		"min_streak_per_track": min_streak,
	}


static func check_after_track(stats: Dictionary, total_missed_notes: int, total_good_notes: int, rules: Dictionary) -> Dictionary:
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
	var max_good_notes := int(rules.get("max_good_notes_total", UNLIMITED_GOOD_NOTES))
	if max_good_notes >= 0 and total_good_notes >= 0 and total_good_notes > max_good_notes:
		return {
			"ok": false,
			"reason": FAIL_REASON_MAX_GOOD_NOTES,
			"detail": max_good_notes,
		}
	var min_streak := int(rules.get("min_streak_per_track", NO_STREAK_REQUIREMENT))
	if min_streak > 0:
		var max_combo := int(stats.get("max_combo", 0))
		if max_combo < min_streak:
			return {
				"ok": false,
				"reason": FAIL_REASON_MIN_STREAK,
				"detail": min_streak,
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
	var max_good_notes := int(rules.get("max_good_notes_total", UNLIMITED_GOOD_NOTES))
	if max_good_notes >= 0:
		parts.append(TranslationServer.translate("MARATHON_RUN_RULE_MAX_GOOD_NOTES_FMT") % max_good_notes)
	var min_accuracy := float(rules.get("min_accuracy_per_track", 0.0))
	if min_accuracy > 0.0:
		parts.append(TranslationServer.translate("MARATHON_RUN_RULE_MIN_ACCURACY_FMT") % int(round(min_accuracy)))
	var min_streak := int(rules.get("min_streak_per_track", NO_STREAK_REQUIREMENT))
	if min_streak > 0:
		parts.append(TranslationServer.translate("MARATHON_RUN_RULE_MIN_STREAK_FMT") % min_streak)
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
	var max_good_notes := int(rules.get("max_good_notes_total", UNLIMITED_GOOD_NOTES))
	if max_good_notes >= 0:
		items.append({
			"icon": "circle-dot.svg",
			"text": TranslationServer.translate("MARATHON_RUN_RULE_MAX_GOOD_NOTES_FMT") % max_good_notes,
			"tint": Color(0.82, 0.68, 0.92, 1.0),
		})
	var min_accuracy := float(rules.get("min_accuracy_per_track", 0.0))
	if min_accuracy > 0.0:
		items.append({
			"icon": "crosshair.svg",
			"text": TranslationServer.translate("MARATHON_RUN_RULE_MIN_ACCURACY_FMT") % int(round(min_accuracy)),
			"tint": Color(0.58, 0.82, 0.96, 1.0),
		})
	var min_streak := int(rules.get("min_streak_per_track", NO_STREAK_REQUIREMENT))
	if min_streak > 0:
		items.append({
			"icon": "flame.svg",
			"text": TranslationServer.translate("MARATHON_RUN_RULE_MIN_STREAK_FMT") % min_streak,
			"tint": Color(0.96, 0.58, 0.42, 1.0),
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


static func _parse_max_good_notes_rule(rule_id: String, current: int) -> int:
	var suffix := rule_id.substr("max_good_notes_".length())
	if suffix.is_valid_int():
		return maxi(0, int(suffix))
	return current


static func _parse_min_streak_rule(rule_id: String) -> int:
	var suffix := rule_id.substr("min_streak_".length())
	if suffix.is_valid_int():
		return maxi(0, int(suffix))
	return 0
