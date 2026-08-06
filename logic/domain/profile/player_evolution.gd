# Then/now comparison from a monthly time capsule vs current profile.
extends RefCounted
class_name PlayerEvolution

const _ActivityCalendar = preload("res://logic/domain/profile/activity_calendar.gd")
const _TimeCapsule = preload("res://logic/domain/profile/time_capsule.gd")


static func build_now_snapshot(player_data: Dictionary) -> Dictionary:
	var today := _ActivityCalendar.today_str()
	var month_key := _TimeCapsule.month_key_from_date(today)
	var total_rr := 0
	if ProfileMilestonesManager != null and ProfileMilestonesManager.has_method("get_total_rr_earned"):
		total_rr = int(ProfileMilestonesManager.get_total_rr_earned())
	var cal := _ActivityCalendar.sanitize_calendar(player_data.get("activity_calendar", {}))
	var days: Dictionary = cal.get("days", {})
	var parts := month_key.split("-")
	var month_summary := {}
	if parts.size() >= 2:
		month_summary = _ActivityCalendar.summarize_month(days, int(parts[0]), int(parts[1]))
	var grades = player_data.get("grades", {})
	return _TimeCapsule.sanitize_capsule({
		"month": month_key,
		"captured_at": Time.get_datetime_string_from_system(true),
		"level": int(player_data.get("current_level", 1)),
		"total_xp": int(player_data.get("total_xp", 0)),
		"login_streak": int(player_data.get("login_streak", 0)),
		"best_login_streak": int(player_data.get("best_login_streak", 0)),
		"favorite_genre": str(player_data.get("favorite_genre", "unknown")),
		"favorite_track": str(player_data.get("favorite_track", "")),
		"favorite_track_play_count": int(player_data.get("favorite_track_play_count", 0)),
		"total_rr": total_rr,
		"levels_completed": int(player_data.get("levels_completed", 0)),
		"grades": grades if grades is Dictionary else {},
		"month_tracks": int(month_summary.get("tracks", 0)),
		"month_clears": int(month_summary.get("clears", 0)),
		"month_fails": int(month_summary.get("fails", 0)),
		"month_play_seconds": int(month_summary.get("play_seconds", 0)),
		"month_best_grade": str(month_summary.get("best_grade", "")),
		"month_best_score": int(month_summary.get("best_score", 0)),
		"month_max_combo": int(month_summary.get("max_combo", 0)),
		"month_favorite_instrument": str(month_summary.get("favorite_instrument", "")),
		"month_play_days": int(month_summary.get("play_days", 0)),
	})


## Returns rows: {caption_key, icon, then_text, now_text, delta_text, tint_hint}
## tint_hint: "up" | "down" | "same" | "changed" | ""
static func build_comparison(capsule: Dictionary, player_data: Dictionary) -> Array:
	var then_s := _TimeCapsule.sanitize_capsule(capsule)
	if then_s.is_empty():
		return []
	return build_comparison_snapshots(then_s, build_now_snapshot(player_data))


## Compare two capsule-shaped snapshots (month A vs month B, or A vs now).
static func build_comparison_snapshots(left_raw: Dictionary, right_raw: Dictionary) -> Array:
	var then_s := _TimeCapsule.sanitize_capsule(left_raw)
	var now_s := _TimeCapsule.sanitize_capsule(right_raw)
	if then_s.is_empty() or now_s.is_empty():
		return []
	var rows: Array = []

	rows.append(_int_row(
		"PLAYER_EVOLUTION_LEVEL",
		int(then_s.get("level", 0)),
		int(now_s.get("level", 0)),
		"chart-column.svg"
	))
	rows.append(_int_row(
		"PLAYER_EVOLUTION_RR",
		int(then_s.get("total_rr", 0)),
		int(now_s.get("total_rr", 0)),
		"fingerprint-pattern.svg"
	))
	rows.append(_int_row(
		"PLAYER_EVOLUTION_CLEARS",
		int(then_s.get("levels_completed", 0)),
		int(now_s.get("levels_completed", 0)),
		"target.svg"
	))
	rows.append(_int_row(
		"PLAYER_EVOLUTION_BEST_STREAK",
		int(then_s.get("best_login_streak", 0)),
		int(now_s.get("best_login_streak", 0)),
		"calendar.svg"
	))
	rows.append(_grades_ss_row(then_s, now_s))
	rows.append(_text_row(
		"PLAYER_EVOLUTION_GENRE",
		_genre_label(str(then_s.get("favorite_genre", ""))),
		_genre_label(str(now_s.get("favorite_genre", ""))),
		"headphones.svg"
	))
	rows.append(_text_row(
		"PLAYER_EVOLUTION_TRACK",
		_track_label(str(then_s.get("favorite_track", ""))),
		_track_label(str(now_s.get("favorite_track", ""))),
		"circle-play.svg"
	))
	rows.append(_int_row(
		"PLAYER_EVOLUTION_MONTH_TRACKS",
		int(then_s.get("month_tracks", 0)),
		int(now_s.get("month_tracks", 0)),
		"music.svg"
	))
	rows.append(_text_row(
		"PLAYER_EVOLUTION_MONTH_GRADE",
		_grade_or_dash(str(then_s.get("month_best_grade", ""))),
		_grade_or_dash(str(now_s.get("month_best_grade", ""))),
		"zap.svg"
	))

	var out: Array = []
	for row in rows:
		if row is Dictionary and not row.is_empty():
			out.append(row)
	return out


static func _int_row(caption_key: String, then_v: int, now_v: int, icon: String = "sparkles.svg") -> Dictionary:
	var delta := now_v - then_v
	var hint := "same"
	if delta > 0:
		hint = "up"
	elif delta < 0:
		hint = "down"
	var delta_text := "—"
	if delta > 0:
		delta_text = "+%d" % delta
	elif delta < 0:
		delta_text = str(delta)
	return {
		"caption_key": caption_key,
		"icon": icon,
		"then_text": str(then_v),
		"now_text": str(now_v),
		"then_value": float(then_v),
		"now_value": float(now_v),
		"numeric": true,
		"delta_text": delta_text,
		"tint_hint": hint,
	}


static func _grades_ss_row(then_s: Dictionary, now_s: Dictionary) -> Dictionary:
	var then_g: Dictionary = then_s.get("grades", {}) if then_s.get("grades", {}) is Dictionary else {}
	var now_g: Dictionary = now_s.get("grades", {}) if now_s.get("grades", {}) is Dictionary else {}
	return _int_row(
		"PLAYER_EVOLUTION_SS",
		int(then_g.get("SS", 0)),
		int(now_g.get("SS", 0)),
		"trophy.svg"
	)


static func _text_row(caption_key: String, then_text: String, now_text: String, icon: String = "sparkles.svg") -> Dictionary:
	var a := then_text.strip_edges()
	var b := now_text.strip_edges()
	if a == "" and b == "":
		return {}
	if a == "":
		a = "—"
	if b == "":
		b = "—"
	var hint := "same" if a == b else "changed"
	return {
		"caption_key": caption_key,
		"icon": icon,
		"then_text": a,
		"now_text": b,
		"then_value": 0.0,
		"now_value": 0.0,
		"numeric": false,
		"delta_text": "" if hint == "same" else "→",
		"tint_hint": hint,
	}


static func _genre_label(raw: String) -> String:
	var g := raw.strip_edges()
	if g == "" or g.to_lower() == "unknown":
		return ""
	const _ProfileGenrePortrait = preload("res://logic/domain/profile/profile_genre_portrait.gd")
	var group := _ProfileGenrePortrait.map_genre_to_group(g.to_lower())
	if group == "":
		group = g.to_lower()
	var key := _ProfileGenrePortrait.group_locale_key(group)
	var tr_label := TranslationServer.translate(key)
	if tr_label != key:
		return tr_label
	return g


static func _track_label(path: String) -> String:
	var p := path.strip_edges()
	if p == "":
		return ""
	return p.get_file().get_basename()


static func _grade_or_dash(grade: String) -> String:
	var g := grade.strip_edges()
	return g if g != "" else "—"


static func month_title(month_key: String) -> String:
	if month_key.length() < 7:
		return month_key
	var parts := month_key.split("-")
	if parts.size() < 2:
		return month_key
	var month := int(parts[1])
	var year := int(parts[0])
	var key := "PROFILE_ACTIVITY_MONTH_%d" % month
	return "%s %d" % [TranslationServer.translate(key), year]
