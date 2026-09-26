# scenes/main_menu/lib/main_menu_nearest_achievement.gd
extends RefCounted
class_name MainMenuNearestAchievement

const _AchievementLocale = preload("res://logic/i18n/achievement_locale.gd")
const _AchievementsUtils = preload("res://logic/domain/profile/achievements_utils.gd")


static func pick_nearest(achievements: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_ratio := -1.0
	var best_remaining := INF
	var best_total := INF

	for raw in achievements:
		if not raw is Dictionary:
			continue
		var ach: Dictionary = raw
		if ach.get("unlocked", false):
			continue
		if bool(ach.get("deprecated", false)):
			continue
		var total := float(ach.get("total", 1))
		if total <= 0.0:
			continue
		var current := clampf(float(ach.get("current", 0)), 0.0, total)
		var ratio := current / total
		var remaining := total - current
		var is_better := best.is_empty()
		if not is_better:
			if ratio > best_ratio + 0.000001:
				is_better = true
			elif absf(ratio - best_ratio) <= 0.000001:
				if remaining < best_remaining - 0.000001:
					is_better = true
				elif absf(remaining - best_remaining) <= 0.000001 and total < best_total:
					is_better = true
		if is_better:
			best = ach
			best_ratio = ratio
			best_remaining = remaining
			best_total = total

	if best.is_empty():
		return {}
	return {
		"achievement": best,
		"current": clampf(float(best.get("current", 0)), 0.0, float(best.get("total", 1))),
		"total": float(best.get("total", 1)),
		"ratio": best_ratio,
	}


static func progress_label_for(ach: Dictionary, achievement_manager: AchievementManager = null) -> String:
	var current = ach.get("current", 0)
	var total = ach.get("total", 1)
	var unlocked := bool(ach.get("unlocked", false))
	if achievement_manager:
		var formatted: Variant = achievement_manager.get_formatted_achievement_progress(int(ach.get("id", -1)))
		if formatted is Dictionary and not formatted.is_empty():
			var raw_total = ach.get("total", 1.0)
			var display_total := str(int(raw_total)) if raw_total == floor(raw_total) else "%0.2f" % [raw_total]
			if unlocked:
				return "%s / %s" % [display_total, display_total]
			return "%s / %s" % [str(formatted.get("current", "0")), display_total]
	if typeof(total) == TYPE_FLOAT or typeof(current) == TYPE_FLOAT:
		if unlocked:
			return "%0.2f / %0.2f" % [float(total), float(total)]
		return "%0.2f / %0.2f" % [float(current), float(total)]
	if unlocked:
		return "%d / %d" % [int(total), int(total)]
	return "%d / %d" % [int(current), int(total)]


static func icon_for(ach: Dictionary) -> Texture2D:
	var category := str(ach.get("category", ""))
	return _AchievementsUtils.load_icon_texture_for_category(category)


static func title_for(ach: Dictionary) -> String:
	return _AchievementLocale.localized_title(ach)
