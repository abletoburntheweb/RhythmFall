# logic/domain/profile/profile_insights.gd
extends RefCounted
class_name ProfileInsights

const SONG_QUEST_EVENTS := {
	"levels_completed": true,
	"play_drum_level": true,
	"play_bass_level": true,
	"accuracy_80": true,
	"accuracy_90": true,
	"accuracy_95": true,
	"combo_reached": true,
	"combo_reached_60": true,
	"combo_reached_100": true,
	"missless": true,
	"play_genre_group": true,
}


static func pick_random_insight(history: Array, avoid_title: String = "") -> Dictionary:
	var eligible := _collect_eligible_insights(history)
	if eligible.is_empty():
		return _fallback_insight()

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var pick_idx := rng.randi_range(0, eligible.size() - 1)
	if eligible.size() > 1 and avoid_title != "":
		for _attempt in range(eligible.size()):
			var candidate: Dictionary = eligible[pick_idx]
			if str(candidate.get("title", "")) != avoid_title:
				return candidate
			pick_idx = (pick_idx + 1 + rng.randi_range(0, eligible.size() - 2)) % eligible.size()
	return eligible[pick_idx]


static func _collect_eligible_insights(history: Array) -> Array:
	var eligible: Array = []

	var streak := PlayerDataManager.get_login_streak()
	if streak >= 2:
		eligible.append(_insight(
			"flame.svg", Color(0.95, 0.62, 0.32, 1.0),
			"PROFILE_DYNAMIC_STREAK_TITLE",
			TranslationServer.translate("PROFILE_DYNAMIC_STREAK_BODY") % streak,
		))

	var best_streak := PlayerDataManager.get_best_login_streak()
	if best_streak >= 3 and best_streak > streak:
		eligible.append(_insight(
			"trophy.svg", Color(0.95, 0.78, 0.35, 1.0),
			"PROFILE_DYNAMIC_BEST_STREAK_TITLE",
			TranslationServer.translate("PROFILE_DYNAMIC_BEST_STREAK_BODY_FMT") % best_streak,
		))

	var songs_today := _count_sessions_today(history)
	if songs_today <= 0:
		eligible.append(_insight(
			"music.svg", Color(0.45, 0.82, 0.78, 1.0),
			"PROFILE_DYNAMIC_NO_PLAY_TITLE",
			TranslationServer.translate("PROFILE_DYNAMIC_NO_PLAY_BODY"),
		))
	elif songs_today > 0:
		eligible.append(_insight(
			"circle-play.svg", Color(0.55, 0.82, 0.95, 1.0),
			"PROFILE_DYNAMIC_TODAY_PLAYS_TITLE",
			TranslationServer.translate("PROFILE_DYNAMIC_TODAY_PLAYS_BODY") % songs_today,
		))

	var daily_hint := _best_daily_quest_hint()
	if not daily_hint.is_empty():
		var remaining := int(daily_hint.get("remaining", 0))
		var quest: Dictionary = daily_hint.get("quest", {})
		var event := str(quest.get("event", ""))
		var body := ""
		if SONG_QUEST_EVENTS.has(event):
			body = TranslationServer.translate("PROFILE_DYNAMIC_DAILY_SONGS_BODY_FMT") % remaining
		else:
			body = TranslationServer.translate("PROFILE_DYNAMIC_DAILY_GENERIC_BODY_FMT") % remaining
		eligible.append(_insight(
			"list-checks.svg", Color(0.95, 0.78, 0.35, 1.0),
			"PROFILE_DYNAMIC_DAILY_TITLE",
			body,
		))

	var xp_left := PlayerDataManager.get_xp_remaining_to_next_level()
	if xp_left > 0:
		eligible.append(_insight(
			"star.svg", Color(0.72, 0.58, 0.95, 1.0),
			"PROFILE_DYNAMIC_XP_TITLE",
			TranslationServer.translate("PROFILE_DYNAMIC_XP_BODY_FMT") % xp_left,
		))
	else:
		eligible.append(_insight(
			"star.svg", Color(0.92, 0.78, 0.42, 1.0),
			"PROFILE_DYNAMIC_LEVEL_MAX_TITLE",
			TranslationServer.translate("PROFILE_DYNAMIC_LEVEL_MAX_BODY"),
		))

	var days := PlayerDataManager.get_days_in_rhythmfall()
	if days >= 2:
		eligible.append(_insight(
			"trees.svg", Color(0.45, 0.82, 0.58, 1.0),
			"PROFILE_DYNAMIC_MEMBER_TITLE",
			TranslationServer.translate("PROFILE_INSIGHT_MEMBER_DAY_FMT") % days,
		))

	var week_plays := ProfileStatTrends.week_session_count(history)
	if week_plays > 0:
		eligible.append(_insight(
			"activity.svg", Color(0.55, 0.82, 0.95, 1.0),
			"PROFILE_DYNAMIC_WEEK_PLAYS_TITLE",
			TranslationServer.translate("PROFILE_DYNAMIC_WEEK_PLAYS_BODY") % week_plays,
		))

	var acc_delta := ProfileStatTrends.week_accuracy_delta(history)
	if absf(acc_delta) >= 1.0:
		var recent_avg := ProfileStatTrends.week_average_accuracy(history)
		eligible.append(_insight(
			"chart-column.svg", Color(0.55, 0.92, 0.78, 1.0),
			"PROFILE_DYNAMIC_ACCURACY_TITLE",
			TranslationServer.translate("PROFILE_DYNAMIC_ACCURACY_BODY_FMT") % [
				"%.1f" % recent_avg,
				"%+.1f" % acc_delta,
			],
		))

	var week_ss := ProfileStatTrends.week_grade_count(history, "SS")
	if week_ss > 0:
		eligible.append(_insight(
			"crown.svg", Color(0.92, 0.78, 0.42, 1.0),
			"PROFILE_DYNAMIC_WEEK_SS_TITLE",
			TranslationServer.translate("PROFILE_DYNAMIC_WEEK_SS_BODY_FMT") % week_ss,
		))

	var max_combo := int(PlayerDataManager.data.get("max_combo_ever", 0))
	if max_combo >= 15:
		eligible.append(_insight(
			"zap.svg", Color(0.95, 0.78, 0.35, 1.0),
			"PROFILE_DYNAMIC_COMBO_TITLE",
			TranslationServer.translate("PROFILE_DYNAMIC_COMBO_BODY_FMT") % max_combo,
		))

	var notes_hit := PlayerDataManager.get_total_notes_hit()
	var perfect_hits := PlayerDataManager.get_total_perfect_hits()
	if notes_hit >= 50 and perfect_hits > 0:
		var perfect_pct := int(round((float(perfect_hits) / float(notes_hit)) * 100.0))
		if perfect_pct >= 25:
			eligible.append(_insight(
				"target.svg", Color(0.55, 0.92, 0.78, 1.0),
				"PROFILE_DYNAMIC_PERFECT_TITLE",
				TranslationServer.translate("PROFILE_DYNAMIC_PERFECT_BODY_FMT") % perfect_pct,
			))

	var grades: Dictionary = PlayerDataManager.data.get("grades", {})
	var ss_count := int(grades.get("SS", 0))
	if ss_count > 0:
		eligible.append(_insight(
			"star.svg", Color(0.92, 0.78, 0.42, 1.0),
			"PROFILE_DYNAMIC_SS_TITLE",
			TranslationServer.translate("PROFILE_DYNAMIC_SS_BODY_FMT") % ss_count,
		))

	var unique_tracks := PlayerDataManager.get_unique_levels_completed()
	if unique_tracks >= 3:
		eligible.append(_insight(
			"disc-3.svg", Color(0.72, 0.58, 0.95, 1.0),
			"PROFILE_DYNAMIC_UNIQUE_TITLE",
			TranslationServer.translate("PROFILE_DYNAMIC_UNIQUE_BODY_FMT") % unique_tracks,
		))

	var play_seconds := PlayerDataManager.get_total_play_time_seconds()
	if play_seconds >= 3600:
		eligible.append(_insight(
			"clock.svg", Color(0.78431374, 0.8235294, 0.9019608, 1.0),
			"PROFILE_DYNAMIC_PLAYTIME_TITLE",
			TranslationServer.translate("PROFILE_DYNAMIC_PLAYTIME_BODY") % PlayerDataManager.get_total_play_time_formatted(),
		))

	var medals := PlayerDataManager.get_total_medals_earned()
	if medals > 0:
		eligible.append(_insight(
			"diamond.svg", Color(0.92, 0.78, 0.42, 1.0),
			"PROFILE_DYNAMIC_MEDALS_TITLE",
			TranslationServer.translate("PROFILE_DYNAMIC_MEDALS_BODY_FMT") % medals,
		))

	var quests_done := PlayerDataManager.get_daily_quests_completed_total()
	if quests_done >= 5:
		eligible.append(_insight(
			"scroll-text.svg", Color(0.45, 0.82, 0.78, 1.0),
			"PROFILE_DYNAMIC_QUESTS_DONE_TITLE",
			TranslationServer.translate("PROFILE_DYNAMIC_QUESTS_DONE_BODY_FMT") % quests_done,
		))

	var notes_miss := PlayerDataManager.get_total_notes_missed()
	var notes_total := notes_hit + notes_miss
	if notes_total >= 100 and notes_miss > 0:
		var miss_pct := (float(notes_miss) / float(notes_total)) * 100.0
		if miss_pct <= 8.0:
			eligible.append(_insight(
				"circle-check.svg", Color(0.42, 0.82, 0.62, 1.0),
				"PROFILE_DYNAMIC_MISS_LOW_TITLE",
				TranslationServer.translate("PROFILE_DYNAMIC_MISS_LOW_BODY_FMT") % ("%.1f" % miss_pct),
			))

	if history.size() >= 3 and notes_hit > 0:
		var avg_hits := int(round(float(notes_hit) / float(history.size())))
		if avg_hits >= 20:
			eligible.append(_insight(
				"activity.svg", Color(0.55, 0.82, 0.95, 1.0),
				"PROFILE_DYNAMIC_AVG_HITS_TITLE",
				TranslationServer.translate("PROFILE_DYNAMIC_AVG_HITS_BODY_FMT") % avg_hits,
			))

	var total_score := int(PlayerDataManager.data.get("total_score_ever", 0))
	if total_score >= 10000:
		eligible.append(_insight(
			"hash.svg", Color(0.9490196, 0.7019608, 0.3529412, 1.0),
			"PROFILE_DYNAMIC_SCORE_TITLE",
			TranslationServer.translate("PROFILE_DYNAMIC_SCORE_BODY_FMT") % _format_grouped(total_score),
		))

	var earned_currency := int(PlayerDataManager.data.get("total_earned_currency", 0))
	if earned_currency >= 500:
		eligible.append(_insight(
			"diamond.svg", Color(0.55, 0.92, 0.95, 1.0),
			"PROFILE_DYNAMIC_CURRENCY_TITLE",
			TranslationServer.translate("PROFILE_DYNAMIC_CURRENCY_BODY_FMT") % _format_grouped(earned_currency),
		))

	for evergreen in _evergreen_insights():
		eligible.append(evergreen)

	return eligible


static func _insight(icon: String, accent: Color, title_key: String, body: String) -> Dictionary:
	return {
		"icon": icon,
		"accent": accent,
		"title": TranslationServer.translate(title_key),
		"body": body,
	}


static func _evergreen_insights() -> Array:
	return [
		_insight(
			"settings-2.svg", Color(0.62, 0.72, 0.88, 1.0),
			"PROFILE_DYNAMIC_FACT_CALIBRATION_TITLE",
			TranslationServer.translate("PROFILE_DYNAMIC_FACT_CALIBRATION_BODY"),
		),
		_insight(
			"repeat.svg", Color(0.72, 0.58, 0.95, 1.0),
			"PROFILE_DYNAMIC_FACT_RETRY_TITLE",
			TranslationServer.translate("PROFILE_DYNAMIC_FACT_RETRY_BODY"),
		),
		_insight(
			"chart-column.svg", Color(0.55, 0.92, 0.78, 1.0),
			"PROFILE_DYNAMIC_FACT_CHART_TITLE",
			TranslationServer.translate("PROFILE_DYNAMIC_FACT_CHART_BODY"),
		),
		_insight(
			"sparkles.svg", Color(0.95, 0.78, 0.35, 1.0),
			"PROFILE_DYNAMIC_FACT_MODS_TITLE",
			TranslationServer.translate("PROFILE_DYNAMIC_FACT_MODS_BODY"),
		),
	]


static func _fallback_insight() -> Dictionary:
	return _insight(
		"sparkles.svg", Color(0.55, 0.92, 0.78, 1.0),
		"PROFILE_DYNAMIC_FALLBACK_TITLE",
		TranslationServer.translate("PROFILE_DYNAMIC_FALLBACK_BODY"),
	)


static func _format_grouped(value: int) -> String:
	var negative := value < 0
	var digits := str(absi(value))
	if digits.length() <= 3:
		return ("-" if negative else "") + digits
	var parts: PackedStringArray = []
	while digits.length() > 3:
		parts.insert(0, digits.substr(digits.length() - 3, 3))
		digits = digits.substr(0, digits.length() - 3)
	parts.insert(0, digits)
	return ("-" if negative else "") + " ".join(parts)


static func _count_sessions_today(history: Array) -> int:
	var today := Time.get_date_string_from_system()
	var count := 0
	for session in history:
		if not session is Dictionary:
			continue
		if str((session as Dictionary).get("date", "")).begins_with(today):
			count += 1
	return count


static func _best_daily_quest_hint() -> Dictionary:
	var quests := PlayerDataManager.get_daily_quests()
	var best_remaining := -1
	var best_quest: Dictionary = {}
	for quest in quests:
		if not quest is Dictionary:
			continue
		if bool((quest as Dictionary).get("completed", false)):
			continue
		var goal := int((quest as Dictionary).get("goal", 0))
		var progress := int((quest as Dictionary).get("progress", 0))
		var remaining := goal - progress
		if remaining <= 0:
			continue
		if best_remaining < 0 or remaining < best_remaining:
			best_remaining = remaining
			best_quest = quest as Dictionary
	if best_remaining < 0:
		return {}
	return {"remaining": best_remaining, "quest": best_quest}
