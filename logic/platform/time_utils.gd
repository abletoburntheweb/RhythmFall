# logic/platform/time_utils.gd
extends RefCounted
class_name TimeUtils

static func _month_short_ru(month: int) -> String:
	var m = {
		1: "янв.", 2: "фев.", 3: "мар.", 4: "апр.", 5: "мая",
		6: "июн.", 7: "июл.", 8: "авг.", 9: "сен.", 10: "окт.", 11: "ноя.", 12: "дек."
	}
	return m.get(month, "")

static func format_date_parts_ru(day: int, month: int, year: int) -> String:
	var m = _month_short_ru(month)
	if m == "":
		m = str(month)
	return "%d %s %d" % [day, m, year]


## YYYY-MM-DD from ISO / datetime strings (handles trailing time / "T").
static func iso_date_only(date_str: String) -> String:
	var s := date_str.strip_edges()
	if s.length() >= 10 and s[4] == "-" and s[7] == "-":
		return s.substr(0, 10)
	return s


static func iso_time_hm(date_str: String) -> String:
	var s := date_str.strip_edges()
	if s.length() >= 16 and (s[10] == "T" or s[10] == " "):
		return s.substr(11, 5)
	return ""


## Compact unambiguous date: 30.07.2026 (avoids label clip of "июл. 2026").
static func format_iso_date_dmy(date_str: String) -> String:
	var d := iso_date_only(date_str)
	var parts := d.split("-")
	if parts.size() != 3:
		return d
	return "%02d.%02d.%04d" % [int(parts[2]), int(parts[1]), int(parts[0])]


static func format_iso_date_ru(date_str: String) -> String:
	if date_str == "":
		var d = Time.get_date_dict_from_system()
		return format_date_parts_ru(int(d.get("day", 1)), int(d.get("month", 1)), int(d.get("year", 2000)))
	var only := iso_date_only(date_str)
	var parts = only.split("-")
	if parts.size() == 3:
		var year = int(parts[0])
		var month = int(parts[1])
		var day = int(parts[2])
		return format_date_parts_ru(day, month, year)
	return date_str


static func _month_short_en(month: int) -> String:
	var m = {
		1: "Jan", 2: "Feb", 3: "Mar", 4: "Apr", 5: "May",
		6: "Jun", 7: "Jul", 8: "Aug", 9: "Sep", 10: "Oct", 11: "Nov", 12: "Dec"
	}
	return m.get(month, "")


static func format_date_parts_en(day: int, month: int, year: int) -> String:
	var m := _month_short_en(month)
	if m == "":
		m = str(month)
	return "%d %s %d" % [day, m, year]


static func format_iso_date_en(date_str: String) -> String:
	if date_str == "":
		var d = Time.get_date_dict_from_system()
		return format_date_parts_en(int(d.get("day", 1)), int(d.get("month", 1)), int(d.get("year", 2000)))
	var only := iso_date_only(date_str)
	var parts = only.split("-")
	if parts.size() == 3:
		return format_date_parts_en(int(parts[2]), int(parts[1]), int(parts[0]))
	return date_str


static func format_iso_date_localized(date_str: String) -> String:
	if TranslationServer.get_locale() == "en":
		return format_iso_date_en(date_str)
	return format_iso_date_ru(date_str)


static func format_session_datetime_localized(date_str: String) -> String:
	var s := date_str.strip_edges()
	if s == "":
		return ""
	if s.length() >= 19 and s[4] == "-" and s[7] == "-" and (s[10] == " " or s[10] == "T"):
		var date_text := format_iso_date_localized(s.substr(0, 10))
		var time_text := s.substr(11, 5)
		return "%s, %s" % [date_text, time_text]
	if s.length() >= 10 and s[4] == "-" and s[7] == "-":
		return format_iso_date_localized(s.substr(0, 10))
	return format_iso_date_localized(s)

static func format_unlock_display(unlock_str: String) -> String:
	var parts = unlock_str.split(",")
	if parts.size() == 2:
		var date_part = parts[0].strip_edges()
		var time_part = parts[1].strip_edges()
		var dparts = date_part.split(" ")
		if dparts.size() >= 3:
			var day = int(dparts[0])
			var month_idx = month_str_to_index(dparts[1])
			var year = int(dparts[2])
			var date_text: String
			if TranslationServer.get_locale() == "en":
				date_text = format_date_parts_en(day, month_idx, year)
			else:
				date_text = format_date_parts_ru(day, month_idx, year)
			if time_part != "":
				return "%s, %s" % [date_text, time_part]
			return date_text
	return unlock_str

static func month_str_to_index(month_token: String) -> int:
	var s = month_token.strip_edges().to_lower()
	if s.ends_with("."):
		s = s.trim_suffix(".")
	var map = {
		"янв": 1, "фев": 2, "мар": 3, "апр": 4, "мая": 5,
		"июн": 6, "июл": 7, "авг": 8, "сен": 9, "окт": 10, "ноя": 11, "дек": 12
	}
	return int(map.get(s, 0))

static func unlock_date_key(s: String) -> PackedInt32Array:
	var parts = s.split(",")
	if parts.size() != 2:
		return PackedInt32Array([0,0,0,0,0])
	var date_part = parts[0].strip_edges()
	var time_part = parts[1].strip_edges()
	var dparts = date_part.split(" ")
	if dparts.size() < 3:
		return PackedInt32Array([0,0,0,0,0])
	var day = int(dparts[0])
	var month = month_str_to_index(dparts[1])
	var year = int(dparts[2])
	var tparts = time_part.split(":")
	var hour = tparts[0].to_int() if tparts.size() >= 1 else 0
	var minute = tparts[1].to_int() if tparts.size() >= 2 else 0
	return PackedInt32Array([year, month, day, hour, minute])

static func now_local_datetime_string() -> String:
	return Time.get_datetime_string_from_system()


static func format_iso_to_ddmmyyyy_hhmmss(date_str: String) -> String:
	if date_str.length() >= 19 and date_str[4] == '-' and date_str[7] == '-' and (date_str[10] == ' ' or date_str[10] == 'T') and date_str[13] == ':' and date_str[16] == ':':
		var year_v = date_str.substr(0, 4)
		var month_v = date_str.substr(5, 2)
		var day_v = date_str.substr(8, 2)
		var time_part_v = date_str.substr(11, 8)
		return "%s.%s.%s %s" % [day_v, month_v, year_v, time_part_v]
	return date_str

static func result_datetime_sort_key(date_str: String) -> int:
	return unix_from_local_iso_datetime(date_str)


static func unix_from_local_iso_datetime(date_str: String) -> int:
	var s := String(date_str).strip_edges()
	if s == "" or s == "N/A":
		return 0
	s = s.replace("T", " ")
	# Date-only YYYY-MM-DD → noon local (stable chronological sort).
	if s.length() == 10 and s[4] == "-" and s[7] == "-":
		s = s + " 12:00:00"
	if s.length() < 16 or s[4] != "-" or s[7] != "-":
		return 0
	var dt := {
		"year": s.substr(0, 4).to_int(),
		"month": s.substr(5, 2).to_int(),
		"day": s.substr(8, 2).to_int(),
		"hour": s.substr(11, 2).to_int(),
		"minute": s.substr(13, 2).to_int(),
		"second": 0 if s.length() < 19 else s.substr(16, 2).to_int(),
	}
	var as_utc := int(Time.get_unix_time_from_datetime_dict(dt))
	return as_utc - _local_wall_clock_unix_offset()


## ISO datetime, date-only ISO, or achievement unlock ("3 авг. 2026, 15:55").
static func unix_from_any_datetime(date_str: String) -> int:
	var iso := unix_from_local_iso_datetime(date_str)
	if iso > 0:
		return iso
	# DD.MM.YYYY or DD.MM.YYYY HH:MM
	var s := String(date_str).strip_edges()
	if s.length() >= 10 and s[2] == "." and s[5] == ".":
		var day := s.substr(0, 2).to_int()
		var month := s.substr(3, 2).to_int()
		var year := s.substr(6, 4).to_int()
		var hour := 12
		var minute := 0
		if s.length() >= 16 and (s[10] == " " or s[10] == ","):
			var rest := s.substr(11).strip_edges()
			var tp := rest.split(":")
			if tp.size() >= 2:
				hour = tp[0].to_int()
				minute = tp[1].to_int()
		if year > 0 and month > 0 and day > 0:
			var as_utc := int(Time.get_unix_time_from_datetime_dict({
				"year": year, "month": month, "day": day,
				"hour": hour, "minute": minute, "second": 0,
			}))
			return as_utc - _local_wall_clock_unix_offset()
	return unix_from_unlock_date(date_str)


## Normalize mixed legacy timestamps to local ISO "YYYY-MM-DD HH:MM:SS".
static func normalize_to_local_iso(date_str: String) -> String:
	var unix := unix_from_any_datetime(date_str)
	if unix <= 0:
		return String(date_str).strip_edges()
	var wall := unix + _local_wall_clock_unix_offset()
	var dt := Time.get_datetime_dict_from_unix_time(wall)
	return "%04d-%02d-%02d %02d:%02d:%02d" % [
		int(dt.get("year", 1970)),
		int(dt.get("month", 1)),
		int(dt.get("day", 1)),
		int(dt.get("hour", 0)),
		int(dt.get("minute", 0)),
		int(dt.get("second", 0)),
	]


static func _local_wall_clock_unix_offset() -> int:
	var now_local := Time.get_datetime_dict_from_system()
	var now_as_utc := int(Time.get_unix_time_from_datetime_dict({
		"year": int(now_local.get("year", 1970)),
		"month": int(now_local.get("month", 1)),
		"day": int(now_local.get("day", 1)),
		"hour": int(now_local.get("hour", 0)),
		"minute": int(now_local.get("minute", 0)),
		"second": int(now_local.get("second", 0)),
	}))
	return now_as_utc - int(Time.get_unix_time_from_system())


static func unix_from_unlock_date(unlock_str: String) -> int:
	var key := unlock_date_key(unlock_str)
	if key.size() < 5:
		return 0
	var dt := {
		"year": key[0],
		"month": key[1],
		"day": key[2],
		"hour": key[3],
		"minute": key[4],
		"second": 0,
	}
	var as_utc := int(Time.get_unix_time_from_datetime_dict(dt))
	return as_utc - _local_wall_clock_unix_offset()


static func format_relative_ago_from_unix(unix_ts: int) -> String:
	if unix_ts <= 0:
		return ""
	var diff := int(Time.get_unix_time_from_system()) - unix_ts
	if diff < 0:
		diff = 0
	if diff < 45:
		return TranslationServer.translate("TIME_AGO_JUST_NOW")
	if diff < 3600:
		var mins := maxi(1, diff / 60)
		return TranslationServer.translate("TIME_AGO_MINUTES") % mins
	if diff < 86400:
		var hours := maxi(1, diff / 3600)
		return TranslationServer.translate("TIME_AGO_HOURS") % hours
	if diff < 172800:
		return TranslationServer.translate("TIME_AGO_YESTERDAY")
	var days := maxi(1, diff / 86400)
	return TranslationServer.translate("TIME_AGO_DAYS") % days


static func format_relative_ago_from_local_iso(date_str: String) -> String:
	var ts := unix_from_local_iso_datetime(date_str)
	if ts <= 0:
		return ""
	return format_relative_ago_from_unix(ts)


## Relative time for recent events; calendar date when older than yesterday.
static func format_relative_ago_or_date_from_unix(unix_ts: int) -> String:
	if unix_ts <= 0:
		return ""
	var diff := int(Time.get_unix_time_from_system()) - unix_ts
	if diff < 0:
		diff = 0
	if diff < 172800:
		if diff < 45:
			return TranslationServer.translate("TIME_AGO_JUST_NOW")
		if diff < 3600:
			return TranslationServer.translate("TIME_AGO_MINUTES") % maxi(1, diff / 60)
		if diff < 86400:
			return TranslationServer.translate("TIME_AGO_HOURS") % maxi(1, diff / 3600)
		return TranslationServer.translate("TIME_AGO_YESTERDAY")
	var dt := Time.get_datetime_dict_from_unix_time(unix_ts)
	var locale := TranslationServer.get_locale()
	if locale.begins_with("en"):
		return format_date_parts_en(int(dt.get("day", 1)), int(dt.get("month", 1)), int(dt.get("year", 2000)))
	return format_date_parts_ru(int(dt.get("day", 1)), int(dt.get("month", 1)), int(dt.get("year", 2000)))

static func sort_results_newest_first(a: Dictionary, b: Dictionary) -> bool:
	var key_a := result_datetime_sort_key(str(a.get("date", "")))
	var key_b := result_datetime_sort_key(str(b.get("date", "")))
	if key_a != key_b:
		return key_a > key_b
	return int(a.get("score", 0)) > int(b.get("score", 0))

static func format_countdown_hms(seconds_left: int) -> String:
	var sec := maxi(0, seconds_left)
	var days := sec / 86400
	sec %= 86400
	var hours := sec / 3600
	sec %= 3600
	var minutes := sec / 60
	var seconds := sec % 60
	if days > 0:
		return "%d %s %02d:%02d:%02d" % [
			days,
			TranslationServer.translate("TIME_COUNTDOWN_DAYS_SUFFIX"),
			hours,
			minutes,
			seconds,
		]
	return "%02d:%02d:%02d" % [hours, minutes, seconds]


static func sort_results_by_score(a: Dictionary, b: Dictionary) -> bool:
	if int(a.get("score", 0)) != int(b.get("score", 0)):
		return int(a.get("score", 0)) > int(b.get("score", 0))
	return float(a.get("accuracy", 0.0)) > float(b.get("accuracy", 0.0))
