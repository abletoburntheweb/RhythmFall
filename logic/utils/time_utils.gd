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

static func format_iso_date_ru(date_str: String) -> String:
	if date_str == "":
		var d = Time.get_date_dict_from_system()
		return format_date_parts_ru(int(d.get("day", 1)), int(d.get("month", 1)), int(d.get("year", 2000)))
	var parts = date_str.split("-")
	if parts.size() == 3:
		var year = int(parts[0])
		var month = int(parts[1])
		var day = int(parts[2])
		return format_date_parts_ru(day, month, year)
	return date_str

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
			var date_text = format_date_parts_ru(day, month_idx, year)
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

static func format_iso_to_ddmmyyyy_hhmmss(date_str: String) -> String:
	if date_str.length() >= 19 and date_str[4] == '-' and date_str[7] == '-' and (date_str[10] == ' ' or date_str[10] == 'T') and date_str[13] == ':' and date_str[16] == ':':
		var year_v = date_str.substr(0, 4)
		var month_v = date_str.substr(5, 2)
		var day_v = date_str.substr(8, 2)
		var time_part_v = date_str.substr(11, 8)
		return "%s.%s.%s %s" % [day_v, month_v, year_v, time_part_v]
	return date_str
