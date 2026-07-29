# logic/domain/profile/profile_stat_trends.gd
extends RefCounted
class_name ProfileStatTrends

const WEEK_SEC := 7 * 86400

const TREND_TILE_KEYS := [
	"unique_tracks",
	"total_score",
	"total_rr",
]


static func compute_tile_trends(history: Array) -> Dictionary:
	var now_unix := int(Time.get_unix_time_from_system())
	var recent := _sessions_between(history, now_unix - WEEK_SEC, now_unix + 1)
	var prior := _sessions_between(history, now_unix - WEEK_SEC * 2, now_unix - WEEK_SEC)
	var trends: Dictionary = {}

	var recent_unique := _unique_song_paths(recent).size()
	var prior_unique := _unique_song_paths(prior).size()
	trends["unique_tracks"] = _make_trend(recent_unique, prior_unique, recent.size(), prior.size())

	var recent_score := _sum_int(recent, "score")
	var prior_score := _sum_int(prior, "score")
	trends["total_score"] = _make_trend(recent_score, prior_score, recent.size(), prior.size())

	var recent_rr := _sum_rr(recent)
	var prior_rr := _sum_rr(prior)
	trends["total_rr"] = _make_trend(recent_rr, prior_rr, recent.size(), prior.size())

	for grade in ["SS", "S", "A", "B"]:
		var recent_grade := _count_grade(recent, grade)
		var prior_grade := _count_grade(prior, grade)
		trends["grade_%s" % grade] = _make_trend(recent_grade, prior_grade, recent.size(), prior.size())

	return trends


static func format_trend_line(trend: Dictionary) -> String:
	if trend.is_empty() or not bool(trend.get("show", false)):
		return ""
	var delta := int(trend.get("delta", 0))
	if delta > 0:
		return TranslationServer.translate("PROFILE_STAT_TREND_UP_FMT") % _format_delta(delta)
	if delta < 0:
		return TranslationServer.translate("PROFILE_STAT_TREND_DOWN_FMT") % _format_delta(absi(delta))
	return TranslationServer.translate("PROFILE_STAT_TREND_FLAT")


static func trend_color(trend: Dictionary) -> Color:
	if trend.is_empty() or not bool(trend.get("show", false)):
		return Color(0.62, 0.66, 0.74, 1.0)
	var delta := int(trend.get("delta", 0))
	if delta > 0:
		return Color(0.42, 0.82, 0.62, 1.0)
	if delta < 0:
		return Color(0.9, 0.48, 0.48, 1.0)
	return Color(0.62, 0.66, 0.74, 1.0)


static func week_session_count(history: Array) -> int:
	var now_unix := int(Time.get_unix_time_from_system())
	return _sessions_between(history, now_unix - WEEK_SEC, now_unix + 1).size()


static func week_average_accuracy(history: Array) -> float:
	var now_unix := int(Time.get_unix_time_from_system())
	var recent := _sessions_between(history, now_unix - WEEK_SEC, now_unix + 1)
	return _average_accuracy(recent)


static func week_accuracy_delta(history: Array) -> float:
	var now_unix := int(Time.get_unix_time_from_system())
	var recent := _sessions_between(history, now_unix - WEEK_SEC, now_unix + 1)
	var prior := _sessions_between(history, now_unix - WEEK_SEC * 2, now_unix - WEEK_SEC)
	if recent.is_empty() or prior.is_empty():
		return 0.0
	return _average_accuracy(recent) - _average_accuracy(prior)


static func week_grade_count(history: Array, grade: String) -> int:
	var now_unix := int(Time.get_unix_time_from_system())
	var recent := _sessions_between(history, now_unix - WEEK_SEC, now_unix + 1)
	return _count_grade(recent, grade)


static func _make_trend(recent_value: int, prior_value: int, recent_sessions: int, prior_sessions: int) -> Dictionary:
	if recent_sessions <= 0 and prior_sessions <= 0:
		return {}
	return {
		"show": true,
		"delta": recent_value - prior_value,
		"recent": recent_value,
		"prior": prior_value,
	}


static func _sessions_between(history: Array, start_unix: int, end_unix: int) -> Array:
	var result: Array = []
	for session in history:
		if not session is Dictionary:
			continue
		var ts := _session_unix(session as Dictionary)
		if ts >= start_unix and ts < end_unix:
			result.append(session)
	return result


static func _session_unix(session: Dictionary) -> int:
	return TimeUtils.unix_from_local_iso_datetime(str(session.get("date", "")))


static func _unique_song_paths(sessions: Array) -> Dictionary:
	var paths: Dictionary = {}
	for session in sessions:
		if not session is Dictionary:
			continue
		var path := str((session as Dictionary).get("song_path", "")).strip_edges()
		if path == "":
			path = str((session as Dictionary).get("path", "")).strip_edges()
		if path != "":
			paths[path] = true
	return paths


static func _sum_int(sessions: Array, key: String) -> int:
	var total := 0
	for session in sessions:
		if session is Dictionary:
			total += int((session as Dictionary).get(key, 0))
	return total


static func _sum_rr(sessions: Array) -> int:
	var total := 0
	for session in sessions:
		if not session is Dictionary:
			continue
		var rr := int((session as Dictionary).get("run_rr", -1))
		if rr >= 0:
			total += rr
	return total


static func _count_grade(sessions: Array, grade: String) -> int:
	var count := 0
	for session in sessions:
		if session is Dictionary and str((session as Dictionary).get("grade", "")) == grade:
			count += 1
	return count


static func _average_accuracy(sessions: Array) -> float:
	if sessions.is_empty():
		return 0.0
	var sum := 0.0
	for session in sessions:
		if session is Dictionary:
			sum += float((session as Dictionary).get("accuracy", 0.0))
	return sum / float(sessions.size())


static func _format_delta(value: int) -> String:
	if value >= 10000:
		return "%dK" % int(round(float(value) / 1000.0))
	if value >= 1000:
		var k := float(value) / 1000.0
		return "%.1fK" % k if fmod(k, 1.0) > 0.05 else "%dK" % int(k)
	return str(value)
