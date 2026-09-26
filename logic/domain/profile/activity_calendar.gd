# logic/domain/profile/activity_calendar.gd
extends RefCounted
class_name ActivityCalendar
## Date helpers + day-snapshot utils for the activity calendar (profile / menu).

const DEFAULT_WINDOW_DAYS := 120
## Cell intensity by tracks: 0 none, 1 (=1), 2 (2–3), 3 (4–6), 4 (7–9), 5 (10+).
const INTENSITY_T2_MIN := 2
const INTENSITY_T3_MIN := 4
const INTENSITY_T4_MIN := 7
const INTENSITY_T5_MIN := 10
## Days that get a calendar star when the run-streak first hits this length (no reward).
const STREAK_MILESTONE_DAYS := [7, 14, 30, 60, 90, 180, 365]
## Day highlight kinds (one per day; higher priority wins).
const HIGHLIGHT_PRIORITY := {
	"streak_milestone": 50,
	"first_ss": 40,
	"score_record": 30,
	"first_instrument": 25,
}
const INSTRUMENTS := ["drums", "bass"]
## Distinct star tint per milestone tier (cell mark + legend).
const STREAK_MILESTONE_COLORS := {
	7: Color("#6EC9C0"),
	14: Color("#7BC47F"),
	30: Color("#F2B35A"),
	60: Color("#E8926A"),
	90: Color("#7EB0E0"),
	180: Color("#D4C06A"),
	365: Color("#F5D76E"),
}
const GRADE_RANK := {
	"SS": 7,
	"S": 6,
	"A": 5,
	"B": 4,
	"C": 3,
	"D": 2,
	"F": 1,
}
## Match victory screen grade palette (readable on calendar cells).
const GRADE_COLORS := {
	"SS": Color("#F2B35A"),
	"S": Color("#C8D2E6"),
	"A": Color("#6B91D2"),
	"B": Color("#59D1BE"),
	"C": Color("#A58EDB"),
	"D": Color("#D56B87"),
	"F": Color("#E07884"),
}


static func today_str() -> String:
	return Time.get_date_string_from_system()


static func empty_calendar(window_days: int = DEFAULT_WINDOW_DAYS) -> Dictionary:
	return {
		"days": {},
		"window_days": maxi(1, int(window_days)),
	}


static func sanitize_calendar(raw: Variant) -> Dictionary:
	var out := empty_calendar()
	if not (raw is Dictionary):
		return out
	out["window_days"] = maxi(1, int(raw.get("window_days", DEFAULT_WINDOW_DAYS)))
	var days_in: Variant = raw.get("days", {})
	if days_in is Dictionary:
		var days_out: Dictionary = {}
		for key in days_in.keys():
			var date_key := str(key)
			if not _is_date_key(date_key):
				continue
			var entry: Variant = days_in[key]
			if entry is Dictionary:
				days_out[date_key] = sanitize_day(entry)
		out["days"] = days_out
	return out


static func milestone_color(milestone: int) -> Color:
	var m := maxi(0, int(milestone))
	if STREAK_MILESTONE_COLORS.has(m):
		return STREAK_MILESTONE_COLORS[m]
	# Nearest lower defined tier.
	var best := 0
	for key in STREAK_MILESTONE_DAYS:
		if int(key) <= m:
			best = int(key)
	if best > 0 and STREAK_MILESTONE_COLORS.has(best):
		return STREAK_MILESTONE_COLORS[best]
	return Color("#F2B35A")


static func highest_milestone_at_or_below(streak: int) -> int:
	var best := 0
	for m in STREAK_MILESTONE_DAYS:
		if int(m) <= int(streak):
			best = int(m)
	return best


static func day_was_played(day: Dictionary) -> bool:
	## Canonical: a day counts only after ≥1 finished run (tracks). Legacy `in` is ignored.
	return int(day.get("tracks", 0)) > 0


static func recompute_streak_milestones(days: Dictionary, _best_login_streak: int = 0) -> Dictionary:
	## ★ only on the calendar day where consecutive play-days in the window hit 7/14/30/…
	## Do not paint a legacy “best streak” star on the latest day — that shows ★14 on a 2-day streak.
	var out: Dictionary = {}
	for key in days.keys():
		var day := sanitize_day(days[key] if days[key] is Dictionary else {})
		day["streak_milestone"] = 0
		out[str(key)] = day
	var dates: Array = out.keys()
	dates.sort()
	var streak := 0
	var prev_date := ""
	for date_key in dates:
		var day: Dictionary = out[date_key]
		if not day_was_played(day):
			continue
		if prev_date != "" and is_yesterday(prev_date, str(date_key)):
			streak += 1
		else:
			streak = 1
		prev_date = str(date_key)
		if is_streak_milestone(streak):
			day["streak_milestone"] = streak
			out[date_key] = day
	return out


static func normalize_instrument(raw: String) -> String:
	var key := str(raw).strip_edges().to_lower()
	match key:
		"bass":
			return "bass"
		"drums", "drum", "standard", "fullmix", "":
			return "drums"
		_:
			return "drums"


static func empty_instrument_bucket() -> Dictionary:
	return {
		"tracks": 0,
		"clears": 0,
		"fails": 0,
		"best_grade": "",
		"best_score": 0,
		"max_combo": 0,
	}


static func sanitize_instrument_bucket(raw: Variant) -> Dictionary:
	var base := empty_instrument_bucket()
	if not (raw is Dictionary):
		return base
	base["tracks"] = maxi(0, int(raw.get("tracks", 0)))
	base["clears"] = maxi(0, int(raw.get("clears", 0)))
	base["fails"] = maxi(0, int(raw.get("fails", 0)))
	base["best_grade"] = str(raw.get("best_grade", "")).strip_edges().to_upper()
	base["best_score"] = maxi(0, int(raw.get("best_score", 0)))
	base["max_combo"] = maxi(0, int(raw.get("max_combo", 0)))
	return base


static func sanitize_by_instrument(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	var src: Dictionary = raw if raw is Dictionary else {}
	for inst in INSTRUMENTS:
		out[inst] = sanitize_instrument_bucket(src.get(inst, {}))
	return out


static func sanitize_highlight(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return {}
	var kind := str(raw.get("kind", "")).strip_edges()
	if kind == "":
		return {}
	var priority := maxi(0, int(raw.get("priority", 0)))
	if priority <= 0:
		priority = int(HIGHLIGHT_PRIORITY.get(kind, 0))
	return {
		"kind": kind,
		"priority": priority,
		"instrument": str(raw.get("instrument", "")).strip_edges(),
		"value": str(raw.get("value", "")).strip_edges(),
		"milestone": maxi(0, int(raw.get("milestone", 0))),
	}


static func sanitize_day(raw: Dictionary) -> Dictionary:
	var tracks := maxi(0, int(raw.get("tracks", 0)))
	var played := tracks > 0
	var out := {
		# Mirror of played; presence is tracks > 0 (legacy login-only `in` no longer counts).
		"in": played,
		"tracks": tracks,
		"clears": maxi(0, int(raw.get("clears", 0))),
		"fails": maxi(0, int(raw.get("fails", 0))),
		# play_seconds = sum of run durations; app_seconds = wall time (stored, not shown in UI).
		"play_seconds": maxi(0, int(raw.get("play_seconds", 0))),
		"app_seconds": maxi(0, int(raw.get("app_seconds", 0))),
		"currency_earned": maxi(0, int(raw.get("currency_earned", 0))),
		"best_grade": str(raw.get("best_grade", "")).strip_edges().to_upper(),
		"best_score": maxi(0, int(raw.get("best_score", 0))),
		"max_combo": maxi(0, int(raw.get("max_combo", 0))),
		"by_instrument": sanitize_by_instrument(raw.get("by_instrument", {})),
		# 7 / 14 / 30 / … / 365 — fact mark only (no currency).
		"streak_milestone": maxi(0, int(raw.get("streak_milestone", 0))),
	}
	var highlight := sanitize_highlight(raw.get("highlight", {}))
	if not highlight.is_empty():
		out["highlight"] = highlight
	return out


static func is_streak_milestone(streak: int) -> bool:
	return int(streak) in STREAK_MILESTONE_DAYS


static func day_play_seconds(day: Dictionary) -> int:
	## Run time only — what the calendar UI should show.
	return maxi(0, int(day.get("play_seconds", 0)))


static func day_presence_seconds(day: Dictionary) -> int:
	## Alias for UI/call sites: prefer run durations (not AFK wall-clock).
	return day_play_seconds(day)


static func apply_highlight(day: Dictionary, candidate: Dictionary) -> Dictionary:
	## Keep a single highlight per day; higher priority replaces.
	var out := day.duplicate(true)
	var nxt := sanitize_highlight(candidate)
	if nxt.is_empty():
		return out
	var cur := sanitize_highlight(out.get("highlight", {}))
	var p_new := int(nxt.get("priority", 0))
	var p_old := int(cur.get("priority", 0))
	if cur.is_empty() or p_new > p_old:
		out["highlight"] = nxt
	return out


static func calendar_had_grade_before(days: Dictionary, before_date: String, grade: String) -> bool:
	var target := str(grade).strip_edges().to_upper()
	if target == "" or before_date == "":
		return false
	var target_rank := int(GRADE_RANK.get(target, 0))
	for key in days.keys():
		var date_key := str(key)
		if date_key >= before_date:
			continue
		var day := sanitize_day(days[key] if days[key] is Dictionary else {})
		if not day_was_played(day):
			continue
		var g := str(day.get("best_grade", "")).strip_edges().to_upper()
		if int(GRADE_RANK.get(g, 0)) >= target_rank and target_rank > 0 and g == target:
			return true
		# Also treat any day whose highlight already recorded first_ss.
		var hl := sanitize_highlight(day.get("highlight", {}))
		if str(hl.get("kind", "")) == "first_ss" and target == "SS":
			return true
	return false


static func calendar_had_instrument_before(days: Dictionary, before_date: String, instrument: String) -> bool:
	var inst := normalize_instrument(instrument)
	if before_date == "":
		return false
	for key in days.keys():
		var date_key := str(key)
		if date_key >= before_date:
			continue
		var day := sanitize_day(days[key] if days[key] is Dictionary else {})
		if int(instrument_bucket(day, inst).get("tracks", 0)) > 0:
			return true
	return false


static func calendar_best_score_before(days: Dictionary, before_date: String) -> int:
	var best := 0
	for key in days.keys():
		var date_key := str(key)
		if before_date != "" and date_key >= before_date:
			continue
		var day := sanitize_day(days[key] if days[key] is Dictionary else {})
		best = maxi(best, int(day.get("best_score", 0)))
	return best


static func week_monday(date_str: String) -> String:
	## Monday (Mon=start) of the week that contains date_str.
	var unix := date_to_unix(date_str)
	if unix <= 0:
		return ""
	var wd_sun := int(Time.get_datetime_dict_from_unix_time(unix).get("weekday", 0))
	var wd_mon := (wd_sun + 6) % 7
	return add_days(date_str, -wd_mon)


static func summarize_date_keys(days: Dictionary, date_keys: Array) -> Dictionary:
	## Shared day-like totals for a set of dates (+ busiest day, favorite instrument).
	var play_days := 0
	var tracks := 0
	var clears := 0
	var fails := 0
	var play_seconds := 0
	var best_grade := ""
	var best_score := 0
	var max_combo := 0
	var by_inst := sanitize_by_instrument({})
	var busiest_date := ""
	var busiest_tracks := 0
	for key in date_keys:
		var date_key := str(key)
		if not days.has(date_key):
			continue
		var day := sanitize_day(days[date_key] if days[date_key] is Dictionary else {})
		if not day_was_played(day):
			continue
		play_days += 1
		var day_tracks := int(day.get("tracks", 0))
		tracks += day_tracks
		clears += int(day.get("clears", 0))
		fails += int(day.get("fails", 0))
		play_seconds += day_play_seconds(day)
		best_grade = better_grade(best_grade, str(day.get("best_grade", "")))
		best_score = maxi(best_score, int(day.get("best_score", 0)))
		max_combo = maxi(max_combo, int(day.get("max_combo", 0)))
		if day_tracks > busiest_tracks:
			busiest_tracks = day_tracks
			busiest_date = date_key
		for inst in INSTRUMENTS:
			var src := instrument_bucket(day, inst)
			var dst: Dictionary = by_inst[inst]
			dst["tracks"] = int(dst.get("tracks", 0)) + int(src.get("tracks", 0))
			dst["clears"] = int(dst.get("clears", 0)) + int(src.get("clears", 0))
			dst["fails"] = int(dst.get("fails", 0)) + int(src.get("fails", 0))
			dst["best_grade"] = better_grade(str(dst.get("best_grade", "")), str(src.get("best_grade", "")))
			dst["best_score"] = maxi(int(dst.get("best_score", 0)), int(src.get("best_score", 0)))
			dst["max_combo"] = maxi(int(dst.get("max_combo", 0)), int(src.get("max_combo", 0)))
			by_inst[inst] = dst
	var drums_tracks := int(by_inst["drums"].get("tracks", 0))
	var bass_tracks := int(by_inst["bass"].get("tracks", 0))
	var favorite := ""
	if drums_tracks > bass_tracks:
		favorite = "drums"
	elif bass_tracks > drums_tracks:
		favorite = "bass"
	elif drums_tracks > 0:
		favorite = "drums"
	return {
		"play_days": play_days,
		"tracks": tracks,
		"clears": clears,
		"fails": fails,
		"play_seconds": play_seconds,
		"best_grade": best_grade,
		"best_score": best_score,
		"max_combo": max_combo,
		"favorite_instrument": favorite,
		"drums_tracks": drums_tracks,
		"bass_tracks": bass_tracks,
		"by_instrument": by_inst,
		"busiest_date": busiest_date,
		"busiest_tracks": busiest_tracks,
	}


static func summarize_month(days: Dictionary, year: int, month: int) -> Dictionary:
	var prefix := "%04d-%02d-" % [year, month]
	var keys: Array = []
	for key in days.keys():
		if str(key).begins_with(prefix):
			keys.append(str(key))
	keys.sort()
	var out := summarize_date_keys(days, keys)
	out["year"] = year
	out["month"] = month
	return out


static func build_month_recap(days: Dictionary, year: int, month: int) -> Dictionary:
	## Narrative month summary for the calendar «Monthly Recap» block (calendar data only).
	const _MemoryFacts = preload("res://logic/domain/profile/activity_memory_facts.gd")
	var summary := summarize_month(days, year, month)
	var weekdays := summarize_weekdays(days, year, month)
	var prefix := "%04d-%02d-" % [year, month]
	var milestone_best := 0
	var milestone_date := ""
	var highlight_kinds: Dictionary = {}
	for key in days.keys():
		var date_key := str(key)
		if not date_key.begins_with(prefix):
			continue
		var day := sanitize_day(days[key] if days[key] is Dictionary else {})
		if not day_was_played(day):
			continue
		var m := int(day.get("streak_milestone", 0))
		if m > milestone_best:
			milestone_best = m
			milestone_date = date_key
		var hl := sanitize_highlight(day.get("highlight", {}))
		var kind := str(hl.get("kind", ""))
		if kind != "":
			highlight_kinds[kind] = int(highlight_kinds.get(kind, 0)) + 1
	summary["busiest_weekday"] = int(weekdays.get("busiest_weekday", -1))
	summary["busiest_weekday_tracks"] = int(weekdays.get("busiest_tracks", 0))
	summary["milestone_best"] = milestone_best
	summary["milestone_date"] = milestone_date
	summary["highlight_kinds"] = highlight_kinds
	summary["story_facts"] = _MemoryFacts.collect_month_facts(days, year, month, summary)
	return summary


static func summarize_week(days: Dictionary, anchor_date: String) -> Dictionary:
	## Calendar week (Mon–Sun) containing anchor_date — same metric shape as month.
	var mon := week_monday(anchor_date if anchor_date != "" else today_str())
	if mon == "":
		return summarize_date_keys(days, [])
	var keys: Array = []
	for i in range(7):
		keys.append(add_days(mon, i))
	var out := summarize_date_keys(days, keys)
	out["start"] = mon
	out["end"] = add_days(mon, 6)
	return out


static func summarize_weekdays(days: Dictionary, year: int = 0, month: int = 0) -> Dictionary:
	## Mon=0 … Sun=6. Optional year/month filters to that month; else whole window.
	var tracks_by := [0, 0, 0, 0, 0, 0, 0]
	var days_by := [0, 0, 0, 0, 0, 0, 0]
	var prefix := ""
	if year > 0 and month >= 1 and month <= 12:
		prefix = "%04d-%02d-" % [year, month]
	for key in days.keys():
		var date_key := str(key)
		if prefix != "" and not date_key.begins_with(prefix):
			continue
		var day := sanitize_day(days[key] if days[key] is Dictionary else {})
		if not day_was_played(day):
			continue
		var unix := date_to_unix(date_key)
		if unix <= 0:
			continue
		var wd_sun := int(Time.get_datetime_dict_from_unix_time(unix).get("weekday", 0))
		var wd_mon := (wd_sun + 6) % 7
		tracks_by[wd_mon] = int(tracks_by[wd_mon]) + int(day.get("tracks", 0))
		days_by[wd_mon] = int(days_by[wd_mon]) + 1
	var busiest := -1
	var busiest_tracks := 0
	for i in range(7):
		if int(tracks_by[i]) > busiest_tracks:
			busiest_tracks = int(tracks_by[i])
			busiest = i
	return {
		"tracks": tracks_by,
		"play_days": days_by,
		"busiest_weekday": busiest,
		"busiest_tracks": busiest_tracks,
	}


static func find_best_month(days: Dictionary) -> Dictionary:
	## Month with the most tracks in the window.
	var buckets: Dictionary = {}
	for key in days.keys():
		var date_key := str(key)
		var parts := _parse_date(date_key)
		if parts.is_empty():
			continue
		var day := sanitize_day(days[key] if days[key] is Dictionary else {})
		if not day_was_played(day):
			continue
		var mk := "%04d-%02d" % [int(parts.year), int(parts.month)]
		if not buckets.has(mk):
			buckets[mk] = {"year": int(parts.year), "month": int(parts.month), "tracks": 0, "play_days": 0}
		var b: Dictionary = buckets[mk]
		b["tracks"] = int(b.get("tracks", 0)) + int(day.get("tracks", 0))
		b["play_days"] = int(b.get("play_days", 0)) + 1
		buckets[mk] = b
	var best_key := ""
	var best_tracks := 0
	for mk in buckets.keys():
		var t := int(buckets[mk].get("tracks", 0))
		if t > best_tracks:
			best_tracks = t
			best_key = str(mk)
	if best_key == "" or not buckets.has(best_key):
		return {}
	return buckets[best_key]


static func current_play_streak(days: Dictionary, today: String = "") -> Dictionary:
	## Active streak from calendar play-days: consecutive days ending on today or yesterday.
	## Returns {length, last_date}. length=0 if last play is older than yesterday.
	var today_key := today if today != "" else today_str()
	var latest := ""
	for key in days.keys():
		var date_key := str(key)
		if date_key > today_key:
			continue
		var day := sanitize_day(days[key] if days[key] is Dictionary else {})
		if not day_was_played(day):
			continue
		if latest == "" or date_key > latest:
			latest = date_key
	if latest == "":
		return {"length": 0, "last_date": ""}
	if latest != today_key and not is_yesterday(latest, today_key):
		return {"length": 0, "last_date": latest}
	var length := 0
	var cursor := latest
	while cursor != "":
		var raw: Variant = days.get(cursor, {})
		var day := sanitize_day(raw if raw is Dictionary else {})
		if not day_was_played(day):
			break
		length += 1
		cursor = add_days(cursor, -1)
	return {"length": length, "last_date": latest}


static func longest_play_streak(days: Dictionary) -> Dictionary:
	## Longest consecutive play-day run inside the saved window.
	var dates: Array = []
	for key in days.keys():
		var day := sanitize_day(days[key] if days[key] is Dictionary else {})
		if day_was_played(day):
			dates.append(str(key))
	dates.sort()
	if dates.is_empty():
		return {"length": 0, "start": "", "end": ""}
	var best_len := 1
	var best_start: String = dates[0]
	var best_end: String = dates[0]
	var cur_len := 1
	var cur_start: String = dates[0]
	for i in range(1, dates.size()):
		var prev := str(dates[i - 1])
		var cur := str(dates[i])
		if is_yesterday(prev, cur):
			cur_len += 1
		else:
			cur_len = 1
			cur_start = cur
		if cur_len > best_len:
			best_len = cur_len
			best_start = cur_start
			best_end = cur
	return {"length": best_len, "start": best_start, "end": best_end}


static func grade_color(grade: String) -> Color:
	var key := str(grade).strip_edges().to_upper()
	if GRADE_COLORS.has(key):
		return GRADE_COLORS[key]
	return Color(0.88, 0.92, 0.98, 1.0)


static func instrument_bucket(day: Dictionary, instrument: String) -> Dictionary:
	var by_i: Dictionary = day.get("by_instrument", {}) if day.get("by_instrument", {}) is Dictionary else {}
	return sanitize_instrument_bucket(by_i.get(normalize_instrument(instrument), {}))


static func apply_run_to_bucket(bucket: Dictionary, summary: Dictionary) -> Dictionary:
	var out := sanitize_instrument_bucket(bucket)
	out["tracks"] = int(out.get("tracks", 0)) + 1
	if bool(summary.get("cleared", true)):
		out["clears"] = int(out.get("clears", 0)) + 1
	else:
		out["fails"] = int(out.get("fails", 0)) + 1
	var grade := str(summary.get("grade", "")).strip_edges().to_upper()
	if grade != "":
		out["best_grade"] = better_grade(str(out.get("best_grade", "")), grade)
	var run_score := maxi(0, int(summary.get("score", 0)))
	if run_score > int(out.get("best_score", 0)):
		out["best_score"] = run_score
	var run_combo := maxi(0, int(summary.get("max_combo", 0)))
	if run_combo > int(out.get("max_combo", 0)):
		out["max_combo"] = run_combo
	return out


static func day_intensity(day: Dictionary) -> int:
	## 0 none · 1 (=1) · 2 (2–3) · 3 (4–6) · 4 (7–9) · 5 (10+).
	var tracks := maxi(0, int(day.get("tracks", 0)))
	if not day_was_played(day):
		return 0
	if tracks >= INTENSITY_T5_MIN:
		return 5
	if tracks >= INTENSITY_T4_MIN:
		return 4
	if tracks >= INTENSITY_T3_MIN:
		return 3
	if tracks >= INTENSITY_T2_MIN:
		return 2
	return 1


static func format_play_hms(play_seconds: int) -> String:
	var total := maxi(0, play_seconds)
	var h := int(total / 3600)
	var m := int((total % 3600) / 60)
	var s := int(total % 60)
	return "%02d:%02d:%02d" % [h, m, s]


static func format_score(score: int) -> String:
	var n := maxi(0, score)
	var raw := str(n)
	var out := ""
	var count := 0
	for i in range(raw.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = " " + out
		out = raw[i] + out
		count += 1
	return out if out != "" else "0"


static func better_grade(a: String, b: String) -> String:
	var ra := int(GRADE_RANK.get(str(a).to_upper(), 0))
	var rb := int(GRADE_RANK.get(str(b).to_upper(), 0))
	if rb > ra:
		return str(b).to_upper()
	if ra > 0:
		return str(a).to_upper()
	return str(b).to_upper() if str(b) != "" else str(a).to_upper()


static func date_to_unix(date_str: String) -> int:
	var parts := _parse_date(date_str)
	if parts.is_empty():
		return 0
	return int(Time.get_unix_time_from_datetime_dict({
		"year": parts.year,
		"month": parts.month,
		"day": parts.day,
		"hour": 12,
		"minute": 0,
		"second": 0,
	}))


static func add_days(date_str: String, delta_days: int) -> String:
	var unix := date_to_unix(date_str)
	if unix <= 0:
		return ""
	return Time.get_date_string_from_unix_time(unix + delta_days * 86400)


static func is_yesterday(last_date: String, today: String) -> bool:
	if last_date == "" or today == "":
		return false
	return add_days(last_date, 1) == today


static func days_between(earlier: String, later: String) -> int:
	var a := date_to_unix(earlier)
	var b := date_to_unix(later)
	if a <= 0 or b <= 0:
		return 9999
	return int(floor(float(b - a) / 86400.0))


static func is_within_window(date_str: String, today: String, window_days: int) -> bool:
	if not _is_date_key(date_str):
		return false
	var delta := days_between(date_str, today)
	return delta >= 0 and delta < maxi(1, window_days)


static func truncate_days(days: Dictionary, today: String, window_days: int) -> Dictionary:
	var kept: Dictionary = {}
	for key in days.keys():
		var date_key := str(key)
		if is_within_window(date_key, today, window_days):
			kept[date_key] = days[key]
	return kept


static func month_grid_cells(year: int, month: int) -> Array:
	## Returns up to 42 dicts: {date, day, in_month, weekday} weekday Mon=0.
	var cells: Array = []
	if year < 1 or month < 1 or month > 12:
		return cells
	var first := "%04d-%02d-01" % [year, month]
	var first_unix := date_to_unix(first)
	if first_unix <= 0:
		return cells
	var first_dict := Time.get_datetime_dict_from_unix_time(first_unix)
	# Godot weekday: 0=Sunday … 6=Saturday → convert to Mon=0.
	var sunday_based := int(first_dict.get("weekday", 0))
	var monday_based := (sunday_based + 6) % 7
	var days_in_month := _days_in_month(year, month)
	var leading := monday_based
	var start_offset := -leading
	for i in range(42):
		var day_index := start_offset + i + 1
		var cell_year := year
		var cell_month := month
		var cell_day := day_index
		var in_month := day_index >= 1 and day_index <= days_in_month
		if day_index < 1:
			var prev := _prev_month(year, month)
			cell_year = prev.year
			cell_month = prev.month
			cell_day = _days_in_month(cell_year, cell_month) + day_index
		elif day_index > days_in_month:
			var nxt := _next_month(year, month)
			cell_year = nxt.year
			cell_month = nxt.month
			cell_day = day_index - days_in_month
		var date_key := "%04d-%02d-%02d" % [cell_year, cell_month, cell_day]
		cells.append({
			"date": date_key,
			"day": cell_day,
			"in_month": in_month,
			"weekday": i % 7,
		})
	return cells


static func format_play_minutes(play_seconds: int) -> String:
	var mins := int(round(float(maxi(0, play_seconds)) / 60.0))
	return str(maxi(0, mins))


static func _is_date_key(date_str: String) -> bool:
	return not _parse_date(date_str).is_empty()


static func _parse_date(date_str: String) -> Dictionary:
	var parts := str(date_str).split("-")
	if parts.size() != 3:
		return {}
	var y := parts[0].to_int()
	var m := parts[1].to_int()
	var d := parts[2].to_int()
	if y < 1 or m < 1 or m > 12 or d < 1 or d > 31:
		return {}
	return {"year": y, "month": m, "day": d}


static func _days_in_month(year: int, month: int) -> int:
	match month:
		1, 3, 5, 7, 8, 10, 12:
			return 31
		4, 6, 9, 11:
			return 30
		2:
			var leap := (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)
			return 29 if leap else 28
		_:
			return 30


static func prev_month(year: int, month: int) -> Dictionary:
	if month <= 1:
		return {"year": year - 1, "month": 12}
	return {"year": year, "month": month - 1}


static func next_month(year: int, month: int) -> Dictionary:
	if month >= 12:
		return {"year": year + 1, "month": 1}
	return {"year": year, "month": month + 1}


static func _prev_month(year: int, month: int) -> Dictionary:
	return prev_month(year, month)


static func _next_month(year: int, month: int) -> Dictionary:
	return next_month(year, month)
