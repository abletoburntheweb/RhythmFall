# Monthly profile snapshots — foundation for «Player Evolution» (then/now).
extends RefCounted
class_name TimeCapsule

const _ActivityCalendar = preload("res://logic/domain/profile/activity_calendar.gd")

const DATA_KEY := "time_capsules"
const SCHEMA_VERSION := 1
## Keep a few years of monthly capsules; older months dropped on write.
const MAX_CAPSULES := 36
## Temporary: seed a lowered previous-month capsule so evolution UI is testable.
## Set to false (or delete ensure path) when real monthly captures are enough.
const DEMO_CAPSULE_ENABLED := false


static func empty_store() -> Dictionary:
	return {"version": SCHEMA_VERSION, "months": {}}


static func sanitize_store(raw) -> Dictionary:
	var out := empty_store()
	if not raw is Dictionary:
		return out
	var months_in = raw.get("months", {})
	if not months_in is Dictionary:
		return out
	var months: Dictionary = {}
	for key in months_in.keys():
		var month_key := str(key).strip_edges()
		if not _is_month_key(month_key):
			continue
		var snap := sanitize_capsule(months_in[key])
		if not snap.is_empty():
			months[month_key] = snap
	out["months"] = months
	return out


static func sanitize_capsule(raw) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var d: Dictionary = raw
	var out := {
		"schema": SCHEMA_VERSION,
		"month": str(d.get("month", "")),
		"captured_at": str(d.get("captured_at", "")),
		"level": int(d.get("level", 1)),
		"total_xp": int(d.get("total_xp", 0)),
		"login_streak": int(d.get("login_streak", 0)),
		"best_login_streak": int(d.get("best_login_streak", 0)),
		"favorite_genre": str(d.get("favorite_genre", "unknown")),
		"favorite_track": str(d.get("favorite_track", "")),
		"favorite_track_play_count": int(d.get("favorite_track_play_count", 0)),
		"total_rr": int(d.get("total_rr", 0)),
		"levels_completed": int(d.get("levels_completed", 0)),
		"grades": _sanitize_grades(d.get("grades", {})),
		"month_tracks": int(d.get("month_tracks", 0)),
		"month_clears": int(d.get("month_clears", 0)),
		"month_fails": int(d.get("month_fails", 0)),
		"month_play_seconds": int(d.get("month_play_seconds", 0)),
		"month_best_grade": str(d.get("month_best_grade", "")),
		"month_best_score": int(d.get("month_best_score", 0)),
		"month_max_combo": int(d.get("month_max_combo", 0)),
		"month_favorite_instrument": str(d.get("month_favorite_instrument", "")),
		"month_play_days": int(d.get("month_play_days", 0)),
	}
	if bool(d.get("demo", false)):
		out["demo"] = true
	return out


static func _sanitize_grades(raw: Variant) -> Dictionary:
	var out := {"SS": 0, "S": 0, "A": 0, "B": 0, "C": 0, "D": 0, "F": 0}
	if not raw is Dictionary:
		return out
	for k in out.keys():
		out[k] = maxi(0, int(raw.get(k, 0)))
	return out


## Weighted average grade letter from capsule grades counts. Empty → "".
static func average_grade_letter(grades_raw: Variant) -> String:
	var grades := _sanitize_grades(grades_raw)
	var weights := {"SS": 6.0, "S": 5.0, "A": 4.0, "B": 3.0, "C": 2.0, "D": 1.0, "F": 0.0}
	var total := 0.0
	var count := 0.0
	for g in weights.keys():
		var n := float(grades.get(g, 0))
		if n <= 0.0:
			continue
		total += float(weights[g]) * n
		count += n
	if count <= 0.0:
		return ""
	var avg := total / count
	if avg >= 5.5:
		return "SS"
	if avg >= 4.5:
		return "S"
	if avg >= 3.5:
		return "A"
	if avg >= 2.5:
		return "B"
	if avg >= 1.5:
		return "C"
	if avg >= 0.5:
		return "D"
	return "F"


## Zap count 0–5 from average grade (SS=5 … F=0).
static func average_grade_zap_count(grades_raw: Variant) -> int:
	var letter := average_grade_letter(grades_raw)
	match letter:
		"SS":
			return 5
		"S":
			return 4
		"A":
			return 3
		"B":
			return 2
		"C":
			return 1
		"D", "F":
			return 1 if letter == "D" else 0
		_:
			return 0


static func _is_month_key(key: String) -> bool:
	if key.length() != 7 or key[4] != "-":
		return false
	return key.substr(0, 4).is_valid_int() and key.substr(5, 2).is_valid_int()


static func month_key_from_date(date_yyyy_mm_dd: String) -> String:
	var s := date_yyyy_mm_dd.strip_edges()
	if s.length() >= 7:
		return s.substr(0, 7)
	return ""


static func previous_month_key(from_date: String = "") -> String:
	var anchor := from_date.strip_edges()
	if anchor == "":
		anchor = _ActivityCalendar.today_str()
	var unix := _ActivityCalendar.date_to_unix(anchor if anchor.length() >= 10 else (anchor + "-01"))
	if unix <= 0:
		return ""
	# Mid-month minus ~32 days lands in the previous calendar month.
	var prev := Time.get_datetime_dict_from_unix_time(unix - 32 * 24 * 3600)
	return "%04d-%02d" % [int(prev.get("year", 0)), int(prev.get("month", 0))]


static func build_capsule_for_month(player_data: Dictionary, month_key: String) -> Dictionary:
	if not _is_month_key(month_key):
		return {}
	var parts := month_key.split("-")
	var year := int(parts[0])
	var month := int(parts[1])
	var cal := _ActivityCalendar.sanitize_calendar(player_data.get("activity_calendar", {}))
	var days: Dictionary = cal.get("days", {})
	var summary := _ActivityCalendar.summarize_month(days, year, month)
	var total_rr := 0
	if ProfileMilestonesManager != null and ProfileMilestonesManager.has_method("get_total_rr_earned"):
		total_rr = int(ProfileMilestonesManager.get_total_rr_earned())
	var grades = player_data.get("grades", {})
	return sanitize_capsule({
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
		"month_tracks": int(summary.get("tracks", 0)),
		"month_clears": int(summary.get("clears", 0)),
		"month_fails": int(summary.get("fails", 0)),
		"month_play_seconds": int(summary.get("play_seconds", 0)),
		"month_best_grade": str(summary.get("best_grade", "")),
		"month_best_score": int(summary.get("best_score", 0)),
		"month_max_combo": int(summary.get("max_combo", 0)),
		"month_favorite_instrument": str(summary.get("favorite_instrument", "")),
		"month_play_days": int(summary.get("play_days", 0)),
	})


## Lowered snapshot of "now" for the previous month — temporary evolution demo.
static func build_demo_capsule(player_data: Dictionary, month_key: String = "") -> Dictionary:
	var mk := month_key.strip_edges()
	if mk == "":
		mk = previous_month_key()
	if not _is_month_key(mk) or not is_past_month(mk):
		return {}
	var base := build_capsule_for_month(player_data, mk)
	if base.is_empty():
		return {}
	var level_now := maxi(1, int(base.get("level", 1)))
	var rr_now := maxi(0, int(base.get("total_rr", 0)))
	var clears_now := maxi(0, int(base.get("levels_completed", 0)))
	var grades: Dictionary = _sanitize_grades(base.get("grades", {}))
	for g in ["SS", "S", "A"]:
		grades[g] = int(grades.get(g, 0)) * 55 / 100
	var genre_now := str(base.get("favorite_genre", "unknown"))
	var genre_then := "unknown"
	if genre_now != "" and genre_now != "unknown":
		genre_then = "pop" if genre_now != "pop" else "rock"
	return sanitize_capsule({
		"month": mk,
		"captured_at": Time.get_datetime_string_from_system(true),
		"demo": true,
		"level": maxi(1, level_now - maxi(2, level_now / 4)),
		"total_xp": maxi(0, int(base.get("total_xp", 0)) * 55 / 100),
		"login_streak": maxi(0, int(base.get("login_streak", 0)) / 2),
		"best_login_streak": maxi(0, int(base.get("best_login_streak", 0)) * 70 / 100),
		"favorite_genre": genre_then,
		"favorite_track": "",
		"favorite_track_play_count": 0,
		"total_rr": maxi(0, rr_now * 60 / 100),
		"levels_completed": maxi(0, clears_now * 65 / 100),
		"grades": grades,
		"month_tracks": int(base.get("month_tracks", 0)),
		"month_clears": int(base.get("month_clears", 0)),
		"month_fails": int(base.get("month_fails", 0)),
		"month_play_seconds": int(base.get("month_play_seconds", 0)),
		"month_best_grade": str(base.get("month_best_grade", "")),
		"month_best_score": int(base.get("month_best_score", 0)),
		"month_max_combo": int(base.get("month_max_combo", 0)),
		"month_favorite_instrument": str(base.get("month_favorite_instrument", "")),
		"month_play_days": int(base.get("month_play_days", 0)),
	})


## If previous month has no capsule yet, write one demo snapshot (when enabled).
## While DEMO_CAPSULE_ENABLED, also replaces a non-demo previous-month capsule so evolution is testable.
static func ensure_demo_capsule(player_data: Dictionary, store: Dictionary) -> Dictionary:
	if not DEMO_CAPSULE_ENABLED:
		return sanitize_store(store)
	var out := sanitize_store(store)
	var prev := previous_month_key()
	if prev == "":
		return out
	if has_capsule(out, prev):
		var existing := get_capsule(out, prev)
		if bool(existing.get("demo", false)):
			return out
		# Real auto-capture often equals "now" → no visible deltas; overwrite while demo flag is on.
	var demo := build_demo_capsule(player_data, prev)
	if demo.is_empty():
		return out
	return upsert_capsule(out, demo)


static func has_capsule(store: Dictionary, month_key: String) -> bool:
	var months = store.get("months", {})
	return months is Dictionary and months.has(month_key)


static func list_month_keys(store: Dictionary) -> PackedStringArray:
	var months = store.get("months", {})
	var keys: Array = []
	if months is Dictionary:
		for k in months.keys():
			keys.append(str(k))
	keys.sort()
	keys.reverse()
	return PackedStringArray(keys)


static func get_capsule(store: Dictionary, month_key: String) -> Dictionary:
	var months = store.get("months", {})
	if not months is Dictionary:
		return {}
	return sanitize_capsule(months.get(month_key, {}))


static func upsert_capsule(store: Dictionary, capsule: Dictionary) -> Dictionary:
	var out := sanitize_store(store)
	var snap := sanitize_capsule(capsule)
	var month_key := str(snap.get("month", ""))
	if not _is_month_key(month_key) or snap.is_empty():
		return out
	var months: Dictionary = out.get("months", {})
	months[month_key] = snap
	# Trim oldest if over cap.
	var keys: Array = months.keys()
	keys.sort()
	while keys.size() > MAX_CAPSULES:
		var drop := str(keys[0])
		months.erase(drop)
		keys.remove_at(0)
	out["months"] = months
	return out


## Capture the previous calendar month once it has play data and no capsule yet.
## Also backfills any older month still in the activity window.
static func maybe_capture(player_data: Dictionary, store: Dictionary) -> Dictionary:
	var out := sanitize_store(store)
	var cal := _ActivityCalendar.sanitize_calendar(player_data.get("activity_calendar", {}))
	var days: Dictionary = cal.get("days", {})
	var month_keys: Dictionary = {}
	for date_key in days.keys():
		var mk := month_key_from_date(str(date_key))
		if mk != "":
			month_keys[mk] = true
	var current := month_key_from_date(_ActivityCalendar.today_str())
	# Never keep a capsule for the month that is still in progress.
	if current != "" and has_capsule(out, current):
		var months: Dictionary = out.get("months", {})
		if months is Dictionary:
			months.erase(current)
			out["months"] = months
	for mk in month_keys.keys():
		var month_key := str(mk)
		if month_key == current:
			continue
		var parts := month_key.split("-")
		if parts.size() < 2:
			continue
		var summary := _ActivityCalendar.summarize_month(days, int(parts[0]), int(parts[1]))
		if int(summary.get("tracks", 0)) <= 0:
			continue
		# First capture once; refresh previous month while it is still settling.
		# Never overwrite a temporary demo capsule.
		var prev := previous_month_key()
		if has_capsule(out, month_key):
			var existing := get_capsule(out, month_key)
			if bool(existing.get("demo", false)):
				continue
			if month_key != prev:
				continue
		out = upsert_capsule(out, build_capsule_for_month(player_data, month_key))
	return out


static func is_past_month(month_key: String, today: String = "") -> bool:
	var current := month_key_from_date(today if today != "" else _ActivityCalendar.today_str())
	return _is_month_key(month_key) and current != "" and month_key < current
