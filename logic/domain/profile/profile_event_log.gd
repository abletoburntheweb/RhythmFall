# Chronological profile event log for History → Timeline (project_new §9).
extends RefCounted
class_name ProfileEventLog

const DATA_KEY := "profile_event_log"
const SCHEMA_VERSION := 1
const MAX_EVENTS := 400

const KIND_GRADE_SS := "grade_ss"
const KIND_GRADE_S := "grade_s"
const KIND_MILESTONE := "milestone"
const KIND_ACHIEVEMENT := "achievement"
const KIND_RR_RECORD := "rr_record"
const KIND_GENRE_UNLOCK := "genre_unlock"
const KIND_GENRE_GROUP_FIRST := "genre_group_first"
const KIND_GENRE_MASTERY := "genre_mastery"
const KIND_RR_TOTAL := "rr_total"
const KIND_MARATHON_MEDAL := "marathon_medal"
const KIND_ENDLESS_PB := "endless_pb"
const KIND_MOD_FIRST := "mod_first"
const KIND_INSTRUMENT_FIRST := "instrument_first"
const KIND_CHART_STYLE_FIRST := "chart_style_first"
const KIND_STREAK := "streak"
const KIND_GENRE_GROUP_SS_FIRST := "genre_group_ss_first"
const KIND_LIBRARY_SIZE := "library_size"
const KIND_TRACK_ANNIVERSARY := "track_anniversary"
const KIND_ENDLESS_FIRST_CLEAR := "endless_first_clear"
const KIND_MARATHON_FIRST_CLEAR := "marathon_first_clear"

const FILTER_ALL := "all"
const FILTER_MILESTONES := "milestones"
const FILTER_ACHIEVEMENTS := "achievements"
const FILTER_RECORDS := "records"
const FILTER_MODES := "modes"

const _PINNED_MILESTONE_KEYS := [
	"first_track_played",
	"first_ss",
	"first_fc",
	"first_mod_clear",
]
const _PINNED_STREAK_DAYS := [180, 365]

const _FILTER_KINDS := {
	FILTER_MILESTONES: [KIND_MILESTONE, KIND_STREAK, KIND_LIBRARY_SIZE, KIND_TRACK_ANNIVERSARY],
	FILTER_ACHIEVEMENTS: [KIND_ACHIEVEMENT],
	FILTER_RECORDS: [KIND_GRADE_SS, KIND_GRADE_S, KIND_RR_RECORD, KIND_RR_TOTAL, KIND_MOD_FIRST],
	FILTER_MODES: [
		KIND_MARATHON_MEDAL,
		KIND_ENDLESS_PB,
		KIND_GENRE_UNLOCK,
		KIND_GENRE_GROUP_FIRST,
		KIND_GENRE_GROUP_SS_FIRST,
		KIND_GENRE_MASTERY,
		KIND_INSTRUMENT_FIRST,
		KIND_CHART_STYLE_FIRST,
		KIND_ENDLESS_FIRST_CLEAR,
		KIND_MARATHON_FIRST_CLEAR,
	],
}

const _KIND_ICONS := {
	KIND_GRADE_SS: "trophy.svg",
	KIND_GRADE_S: "star.svg",
	KIND_MILESTONE: "flag.svg",
	KIND_ACHIEVEMENT: "sparkles.svg",
	KIND_RR_RECORD: "fingerprint-pattern.svg",
	KIND_GENRE_UNLOCK: "tags.svg",
	KIND_GENRE_GROUP_FIRST: "tags.svg",
	KIND_GENRE_GROUP_SS_FIRST: "trophy.svg",
	KIND_GENRE_MASTERY: "tags.svg",
	KIND_RR_TOTAL: "fingerprint-pattern.svg",
	KIND_MARATHON_MEDAL: "trophy.svg",
	KIND_ENDLESS_PB: "repeat.svg",
	KIND_ENDLESS_FIRST_CLEAR: "repeat.svg",
	KIND_MARATHON_FIRST_CLEAR: "layers.svg",
	KIND_LIBRARY_SIZE: "hash.svg",
	KIND_TRACK_ANNIVERSARY: "calendar.svg",
	KIND_MOD_FIRST: "eye-off.svg",
	KIND_INSTRUMENT_FIRST: "drum.svg",
	KIND_CHART_STYLE_FIRST: "layers.svg",
	KIND_STREAK: "flame.svg",
}

const _KIND_TINTS := {
	KIND_GRADE_SS: Color(0.96, 0.78, 0.34, 1.0),
	KIND_GRADE_S: Color(0.95, 0.82, 0.45, 1.0),
	KIND_MILESTONE: Color(0.72, 0.62, 0.95, 1.0),
	KIND_ACHIEVEMENT: Color(0.55, 0.78, 0.98, 1.0),
	KIND_RR_RECORD: Color(0.95, 0.70, 0.35, 1.0),
	KIND_GENRE_UNLOCK: Color(0.62, 0.86, 0.72, 1.0),
	KIND_GENRE_GROUP_FIRST: Color(0.62, 0.86, 0.72, 1.0),
	KIND_GENRE_GROUP_SS_FIRST: Color(0.96, 0.78, 0.34, 1.0),
	KIND_GENRE_MASTERY: Color(0.72, 0.86, 0.58, 1.0),
	KIND_RR_TOTAL: Color(0.95, 0.78, 0.42, 1.0),
	KIND_MARATHON_MEDAL: Color(0.55, 0.72, 0.98, 1.0),
	KIND_ENDLESS_PB: Color(0.72, 0.58, 0.95, 1.0),
	KIND_ENDLESS_FIRST_CLEAR: Color(0.72, 0.58, 0.95, 1.0),
	KIND_MARATHON_FIRST_CLEAR: Color(0.55, 0.72, 0.98, 1.0),
	KIND_LIBRARY_SIZE: Color(0.62, 0.86, 0.72, 1.0),
	KIND_TRACK_ANNIVERSARY: Color(0.95, 0.70, 0.45, 1.0),
	KIND_MOD_FIRST: Color(0.72, 0.58, 0.95, 1.0),
	KIND_INSTRUMENT_FIRST: Color(0.95, 0.70, 0.45, 1.0),
	KIND_CHART_STYLE_FIRST: Color(0.55, 0.72, 0.98, 1.0),
	KIND_STREAK: Color(0.95, 0.55, 0.42, 1.0),
}

## Category → lucide file already present under assets/icons.
const _ACHIEVEMENT_CATEGORY_ICONS := {
	"daily": "calendar.svg",
	"shop": "sparkles.svg",
	"economy": "hash.svg",
	"drums": "drum.svg",
	"bass": "audio-lines.svg",
	"accuracy": "target.svg",
	"combo": "flame.svg",
	"mods": "eye-off.svg",
	"playtime": "clock.svg",
	"collection": "tags.svg",
	"special": "star.svg",
}


static func empty_store() -> Dictionary:
	return {"version": SCHEMA_VERSION, "events": [], "backfilled": false}


static func sanitize_store(raw: Variant) -> Dictionary:
	var out := empty_store()
	if not raw is Dictionary:
		return out
	out["backfilled"] = bool(raw.get("backfilled", false))
	var events_in: Variant = raw.get("events", [])
	if not events_in is Array:
		return out
	var events: Array = []
	for item in events_in:
		var ev := sanitize_event(item)
		if not ev.is_empty():
			events.append(ev)
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _event_sort_key(a) > _event_sort_key(b)
	)
	_ensure_first_rr_total_pin(events)
	events = _trim_preserving_pins(events)
	out["events"] = events
	return out


static func sanitize_event(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var kind := str(raw.get("kind", "")).strip_edges()
	if kind == "":
		return {}
	var ts := str(raw.get("ts", "")).strip_edges()
	if ts == "":
		ts = Time.get_datetime_string_from_system(true)
	else:
		const _TimeUtils = preload("res://logic/platform/time_utils.gd")
		ts = _TimeUtils.normalize_to_local_iso(ts)
	var out := {
		"id": str(raw.get("id", "")).strip_edges(),
		"ts": ts,
		"kind": kind,
		"title_key": str(raw.get("title_key", "")),
		"title_arg": str(raw.get("title_arg", "")),
		"detail": str(raw.get("detail", "")),
		"song_path": str(raw.get("song_path", "")),
		"route_id": str(raw.get("route_id", "")).strip_edges(),
		"icon": str(raw.get("icon", _KIND_ICONS.get(kind, "sparkles.svg"))),
		"badges": [],
		"pin": bool(raw.get("pin", false)),
	}
	if kind == KIND_GENRE_MASTERY:
		out["level"] = int(raw.get("level", 0))
	if kind == KIND_MILESTONE:
		out["title_arg"] = _resolve_milestone_arg(str(out.get("title_arg", "")))
	var badges_raw: Variant = raw.get("badges", [])
	if badges_raw is Array:
		for b in badges_raw:
			var tier := str(b).strip_edges()
			if tier != "":
				out["badges"].append(tier)
	# Legacy detail "bronze, silver, gold" → badges when missing.
	if out["badges"].is_empty() and kind == KIND_MARATHON_MEDAL:
		for part in str(out["detail"]).split(","):
			var tier2 := part.strip_edges().to_lower()
			if tier2 in ["bronze", "silver", "gold", "platinum", "legend"]:
				out["badges"].append(tier2)
		if not out["badges"].is_empty():
			out["detail"] = ""
	if out["route_id"] == "" and kind == KIND_MARATHON_MEDAL:
		out["route_id"] = str(out["title_arg"])
	if out["id"] == "":
		out["id"] = "%s_%s" % [kind, ts]
	return out


static func get_store_from_player_data(player_data: Dictionary) -> Dictionary:
	return sanitize_store(player_data.get(DATA_KEY, {}))


static func write_store_to_player_data(player_data: Dictionary, store: Dictionary) -> void:
	player_data[DATA_KEY] = sanitize_store(store)


static func append_event(player_data: Dictionary, kind: String, opts: Dictionary = {}) -> Dictionary:
	var store := get_store_from_player_data(player_data)
	var ev := sanitize_event({
		"id": str(opts.get("id", "")),
		"ts": str(opts.get("ts", Time.get_datetime_string_from_system(true))),
		"kind": kind,
		"title_key": str(opts.get("title_key", _default_title_key(kind))),
		"title_arg": str(opts.get("title_arg", "")),
		"detail": str(opts.get("detail", "")),
		"song_path": str(opts.get("song_path", "")),
		"route_id": str(opts.get("route_id", "")),
		"badges": opts.get("badges", []),
		"icon": str(opts.get("icon", _KIND_ICONS.get(kind, "sparkles.svg"))),
		"level": int(opts.get("level", 0)),
		"pin": bool(opts.get("pin", false)),
	})
	if ev.is_empty():
		return {}
	# Dedup identical id.
	var events: Array = store.get("events", [])
	for existing in events:
		if existing is Dictionary and str(existing.get("id", "")) == str(ev.get("id", "")):
			return {}
	if kind == KIND_RR_TOTAL and not bool(ev.get("pin", false)):
		var has_rr := false
		for existing2 in events:
			if existing2 is Dictionary and str(existing2.get("kind", "")) == KIND_RR_TOTAL:
				has_rr = true
				break
		if not has_rr:
			ev["pin"] = true
	events.push_front(ev)
	events = _trim_preserving_pins(events)
	store["events"] = events
	write_store_to_player_data(player_data, store)
	return ev


## Lifetime firsts / long streaks / first RR ladder — never dropped on trim.
static func is_pinned(ev: Dictionary) -> bool:
	if ev.is_empty():
		return false
	if bool(ev.get("pin", false)):
		return true
	var kind := str(ev.get("kind", ""))
	match kind:
		KIND_MILESTONE:
			return _PINNED_MILESTONE_KEYS.has(milestone_raw_key(ev))
		KIND_STREAK:
			var days := int(str(ev.get("title_arg", "0")))
			return _PINNED_STREAK_DAYS.has(days)
		_:
			return false


static func milestone_raw_key(ev: Dictionary) -> String:
	var arg := str(ev.get("title_arg", "")).strip_edges()
	if arg.begins_with("PROFILE_RECORD_MILESTONE_"):
		match arg:
			"PROFILE_RECORD_MILESTONE_FIRST_SS":
				return "first_ss"
			"PROFILE_RECORD_MILESTONE_FIRST_FC":
				return "first_fc"
			"PROFILE_RECORD_MILESTONE_FIRST_TRACK":
				return "first_track_played"
			"PROFILE_RECORD_MILESTONE_FIRST_MOD":
				return "first_mod_clear"
			"PROFILE_RECORD_MILESTONE_ENDLESS":
				return "endless_unlocked"
			"PROFILE_RECORD_MILESTONE_MARATHON":
				return "marathon_unlocked"
			_:
				return ""
	match arg:
		"first_ss", "first_fc", "first_track_played", "first_mod_clear", "endless_unlocked", "marathon_unlocked":
			return arg
		_:
			return ""


static func _trim_preserving_pins(events: Array) -> Array:
	if events.size() <= MAX_EVENTS:
		return events
	var out: Array = events.duplicate()
	while out.size() > MAX_EVENTS:
		var dropped := false
		for i in range(out.size() - 1, -1, -1):
			var item: Variant = out[i]
			if item is Dictionary and is_pinned(item):
				continue
			out.remove_at(i)
			dropped = true
			break
		if not dropped:
			break
	return out


static func _ensure_first_rr_total_pin(events: Array) -> void:
	var oldest_idx: int = -1
	var oldest_ts: int = 2147483647
	var any_pinned := false
	for i in range(events.size()):
		var item: Variant = events[i]
		if not item is Dictionary:
			continue
		var ev: Dictionary = item
		if str(ev.get("kind", "")) != KIND_RR_TOTAL:
			continue
		if bool(ev.get("pin", false)):
			any_pinned = true
			break
		var key: int = _event_sort_key(ev)
		if oldest_idx < 0 or key < oldest_ts:
			oldest_idx = i
			oldest_ts = key
	if any_pinned or oldest_idx < 0:
		return
	var pinned: Dictionary = events[oldest_idx]
	pinned["pin"] = true
	events[oldest_idx] = pinned


static func list_events(player_data: Dictionary, filter_id: String = FILTER_ALL) -> Array:
	var store := get_store_from_player_data(player_data)
	var events: Array = store.get("events", [])
	var fid := str(filter_id).strip_edges().to_lower()
	var out: Array = []
	if fid == "" or fid == FILTER_ALL:
		out = events.duplicate(true)
	else:
		var allowed: Array = _FILTER_KINDS.get(fid, [])
		if allowed.is_empty():
			return []
		for ev in events:
			if ev is Dictionary and allowed.has(str(ev.get("kind", ""))):
				out.append(ev)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _event_sort_key(a) > _event_sort_key(b)
	)
	return out


static func _event_sort_key(ev: Dictionary) -> int:
	const _TimeUtils = preload("res://logic/platform/time_utils.gd")
	return _TimeUtils.unix_from_any_datetime(str(ev.get("ts", "")))


## One-shot backfill for older saves so Timeline is not empty.
static func ensure_backfill(player_data: Dictionary, milestones_data: Dictionary = {}) -> bool:
	var store := get_store_from_player_data(player_data)
	if bool(store.get("backfilled", false)):
		return false
	var added := 0
	var milestones: Dictionary = {}
	if milestones_data.get("milestones", {}) is Dictionary:
		milestones = milestones_data.get("milestones", {})
	for key in milestones.keys():
		var entry: Variant = milestones.get(key)
		if not entry is Dictionary:
			continue
		var date_str := str(entry.get("date", "")).strip_edges()
		if date_str == "":
			continue
		var track := _track_line(entry)
		append_event(player_data, KIND_MILESTONE, {
			"id": "bf_ms_%s" % key,
			"ts": date_str,
			"title_key": "PROFILE_EVENT_MILESTONE",
			"title_arg": _milestone_title_key(str(key)),
			"detail": track,
			"song_path": str(entry.get("song_path", "")),
			"icon": _milestone_icon(str(key)),
		})
		added += 1
	var extremes: Variant = milestones_data.get("extremes", {})
	if extremes is Dictionary:
		var last_rec: Variant = extremes.get("last_personal_record")
		if last_rec is Dictionary and int(last_rec.get("best_rr", 0)) > 0:
			var d := str(last_rec.get("date", "")).strip_edges()
			if d != "":
				append_event(player_data, KIND_RR_RECORD, {
					"id": "bf_rr_last",
					"ts": d,
					"title_key": "PROFILE_EVENT_RR_RECORD",
					"title_arg": str(int(last_rec.get("best_rr", 0))),
					"detail": _track_line(last_rec),
					"song_path": str(last_rec.get("song_path", "")),
					"icon": "fingerprint-pattern.svg",
				})
				added += 1
	var am = PlayerDataManager.achievement_manager if PlayerDataManager else null
	if am != null:
		var ach_raw: Variant = am.get("achievements")
		if ach_raw is Array:
			for a in ach_raw:
				if not a is Dictionary:
					continue
				if not bool(a.get("unlocked", false)):
					continue
				var ud := str(a.get("unlock_date", "")).strip_edges()
				if ud == "":
					continue
				append_event(player_data, KIND_ACHIEVEMENT, {
					"id": "bf_ach_%d" % int(a.get("id", -1)),
					"ts": ud,
					"title_key": "PROFILE_EVENT_ACHIEVEMENT",
					"title_arg": str(a.get("title", a.get("name", ""))),
					"detail": "",
					"icon": icon_for_achievement_category(str(a.get("category", ""))),
				})
				added += 1
	store = get_store_from_player_data(player_data)
	store["backfilled"] = true
	write_store_to_player_data(player_data, store)
	return added > 0


static func relative_day_label(ts: String) -> String:
	const _TimeUtils = preload("res://logic/platform/time_utils.gd")
	var normalized := _TimeUtils.normalize_to_local_iso(ts)
	var day := _TimeUtils.iso_date_only(normalized)
	var time_hm := _TimeUtils.iso_time_hm(normalized)
	var now := Time.get_datetime_dict_from_system()
	var today := "%04d-%02d-%02d" % [int(now.get("year", 0)), int(now.get("month", 0)), int(now.get("day", 0))]
	if day == today:
		var base := TranslationServer.translate("PROFILE_EVENT_TODAY")
		return "%s %s" % [base, time_hm] if time_hm != "" else base
	var today_unix := Time.get_unix_time_from_datetime_dict({
		"year": int(now.get("year", 0)),
		"month": int(now.get("month", 0)),
		"day": int(now.get("day", 0)),
		"hour": 12,
		"minute": 0,
		"second": 0,
	})
	var parts := day.split("-")
	if parts.size() < 3:
		return _TimeUtils.format_iso_date_dmy(normalized)
	var day_unix := Time.get_unix_time_from_datetime_dict({
		"year": int(parts[0]),
		"month": int(parts[1]),
		"day": int(parts[2]),
		"hour": 12,
		"minute": 0,
		"second": 0,
	})
	if day_unix <= 0 or today_unix <= 0:
		return _TimeUtils.format_iso_date_dmy(normalized)
	var diff_days := int(floor((float(today_unix) - float(day_unix)) / 86400.0))
	if diff_days == 1:
		var ybase := TranslationServer.translate("PROFILE_EVENT_YESTERDAY")
		return "%s %s" % [ybase, time_hm] if time_hm != "" else ybase
	if diff_days > 1 and diff_days < 14:
		return TranslationServer.translate("PROFILE_EVENT_DAYS_AGO_FMT") % diff_days
	return _TimeUtils.format_iso_date_dmy(normalized)


static func icon_for_event(ev: Dictionary) -> String:
	var kind := str(ev.get("kind", ""))
	var icon := str(ev.get("icon", "")).strip_edges()
	if icon != "" and icon != "sparkles.svg":
		return icon
	if kind == KIND_ACHIEVEMENT:
		# Prefer category icon when stored as sparkles from older backfill.
		var ach_id := _achievement_id_from_event(ev)
		if ach_id >= 0 and PlayerDataManager and PlayerDataManager.achievement_manager:
			var a = PlayerDataManager.achievement_manager.get_achievement_by_id(ach_id)
			if a is Dictionary:
				return icon_for_achievement_category(str(a.get("category", "")))
	return str(_KIND_ICONS.get(kind, "sparkles.svg"))


static func tint_for_event(ev: Dictionary) -> Color:
	var kind := str(ev.get("kind", ""))
	if kind == KIND_ACHIEVEMENT:
		var palette: Array[Color] = [
			Color(0.55, 0.78, 0.98, 1.0),
			Color(0.62, 0.86, 0.72, 1.0),
			Color(0.72, 0.62, 0.95, 1.0),
			Color(0.96, 0.78, 0.34, 1.0),
			Color(0.95, 0.55, 0.42, 1.0),
			Color(0.55, 0.88, 0.82, 1.0),
		]
		var h := hash(str(ev.get("id", ev.get("title_arg", ""))))
		return palette[absi(h) % palette.size()]
	return _KIND_TINTS.get(kind, Color(0.72, 0.62, 0.95, 1.0))


static func icon_for_achievement_category(category: String) -> String:
	var cat := category.strip_edges().to_lower()
	return str(_ACHIEVEMENT_CATEGORY_ICONS.get(cat, "sparkles.svg"))


static func _achievement_id_from_event(ev: Dictionary) -> int:
	var id_str := str(ev.get("id", ""))
	if id_str.begins_with("bf_ach_"):
		return int(id_str.substr(7))
	if id_str.begins_with("ach_"):
		var rest := id_str.substr(4)
		var cut := rest.find("_")
		if cut > 0:
			return int(rest.substr(0, cut))
		if rest.is_valid_int():
			return int(rest)
	if id_str.is_valid_int():
		return int(id_str)
	return -1


static func format_title(ev: Dictionary) -> String:
	var head := format_headline(ev)
	var sub := format_subtitle(ev)
	if head == "":
		return sub
	if sub == "":
		return head
	return "%s — %s" % [head, sub]


static func format_headline(ev: Dictionary) -> String:
	var key := str(ev.get("title_key", "")).strip_edges()
	if key == "":
		key = _default_title_key(str(ev.get("kind", "")))
	var base := TranslationServer.translate(key)
	# Strip legacy " — %s" / " — %d" patterns if old CSV still cached.
	var cut := base.find(" — %")
	if cut >= 0:
		base = base.substr(0, cut)
	base = base.replace(" — %s", "").replace(" — %d", "").replace(" — %s", "")
	base = base.replace("%s", "").replace("%d", "").strip_edges()
	if base.ends_with("—") or base.ends_with("-"):
		base = base.substr(0, base.length() - 1).strip_edges()
	return base


static func format_subtitle(ev: Dictionary) -> String:
	var arg := str(ev.get("title_arg", "")).strip_edges()
	var kind := str(ev.get("kind", ""))
	if kind == KIND_MARATHON_MEDAL or kind == KIND_MARATHON_FIRST_CLEAR:
		var route_id := str(ev.get("route_id", arg)).strip_edges()
		if route_id != "":
			const _PlayModes = preload("res://logic/domain/profile/profile_play_modes_stats.gd")
			return _PlayModes.route_display_title_full(route_id)
	if kind == KIND_MILESTONE:
		arg = _resolve_milestone_arg(arg)
	if kind == KIND_STREAK and arg.is_valid_int():
		return TranslationServer.translate("PROFILE_EVENT_STREAK_DAYS_FMT") % int(arg)
	if kind == KIND_RR_TOTAL and arg.is_valid_int():
		return TranslationServer.translate("PROFILE_EVENT_RR_TOTAL_AMT") % _format_rr_amount(int(arg))
	if kind == KIND_LIBRARY_SIZE and arg.is_valid_int():
		return TranslationServer.translate("PROFILE_EVENT_LIBRARY_SIZE_FMT") % int(arg)
	if kind == KIND_TRACK_ANNIVERSARY and arg.is_valid_int():
		var years := int(arg)
		if years <= 1:
			return TranslationServer.translate("PROFILE_EVENT_TRACK_ANNIVERSARY_YEAR")
		return TranslationServer.translate("PROFILE_EVENT_TRACK_ANNIVERSARY_YEARS_FMT") % years
	if kind == KIND_GENRE_MASTERY:
		var group_tr := TranslationServer.translate(arg)
		var level := int(ev.get("level", 0))
		if level > 0:
			return TranslationServer.translate("PROFILE_EVENT_GENRE_MASTERY_FMT") % [group_tr if group_tr != arg else arg, level]
		return group_tr if group_tr != arg else arg
	if kind == KIND_CHART_STYLE_FIRST:
		const _Discovery = preload("res://logic/domain/profile/profile_discovery_firsts.gd")
		return _Discovery.format_chart_style_arg(arg)
	if arg == "":
		return ""
	var arg_tr := TranslationServer.translate(arg)
	if arg_tr != arg:
		return arg_tr
	return arg


static func _format_rr_amount(n: int) -> String:
	var s := str(maxi(0, n))
	var out := ""
	var i := 0
	for j in range(s.length() - 1, -1, -1):
		if i > 0 and i % 3 == 0:
			out = " " + out
		out = s[j] + out
		i += 1
	return out


static func _resolve_milestone_arg(arg: String) -> String:
	var a := arg.strip_edges()
	if a == "":
		return ""
	if a.begins_with("PROFILE_"):
		return a
	var mapped := _milestone_title_key(a)
	if mapped != a:
		return mapped
	# Legacy ids that were stored raw.
	match a:
		"first_medal", "first_hidden", "first_hidden_clear":
			return _milestone_title_key(a if a != "first_hidden" else "first_hidden_clear")
		_:
			return a


static func _default_title_key(kind: String) -> String:
	match kind:
		KIND_GRADE_SS:
			return "PROFILE_EVENT_GRADE_SS"
		KIND_GRADE_S:
			return "PROFILE_EVENT_GRADE_S"
		KIND_MILESTONE:
			return "PROFILE_EVENT_MILESTONE"
		KIND_ACHIEVEMENT:
			return "PROFILE_EVENT_ACHIEVEMENT"
		KIND_RR_RECORD:
			return "PROFILE_EVENT_RR_RECORD"
		KIND_GENRE_UNLOCK:
			return "PROFILE_EVENT_GENRE_UNLOCK"
		KIND_GENRE_GROUP_FIRST:
			return "PROFILE_EVENT_GENRE_GROUP_FIRST"
		KIND_GENRE_GROUP_SS_FIRST:
			return "PROFILE_EVENT_GENRE_GROUP_SS_FIRST"
		KIND_GENRE_MASTERY:
			return "PROFILE_EVENT_GENRE_MASTERY"
		KIND_RR_TOTAL:
			return "PROFILE_EVENT_RR_TOTAL"
		KIND_MARATHON_MEDAL:
			return "PROFILE_EVENT_MARATHON_MEDAL"
		KIND_ENDLESS_PB:
			return "PROFILE_EVENT_ENDLESS_PB"
		KIND_ENDLESS_FIRST_CLEAR:
			return "PROFILE_EVENT_ENDLESS_FIRST"
		KIND_MARATHON_FIRST_CLEAR:
			return "PROFILE_EVENT_MARATHON_FIRST"
		KIND_LIBRARY_SIZE:
			return "PROFILE_EVENT_LIBRARY_SIZE"
		KIND_TRACK_ANNIVERSARY:
			return "PROFILE_EVENT_TRACK_ANNIVERSARY"
		KIND_MOD_FIRST:
			return "PROFILE_EVENT_MOD_FIRST"
		KIND_INSTRUMENT_FIRST:
			return "PROFILE_EVENT_INSTRUMENT_FIRST"
		KIND_CHART_STYLE_FIRST:
			return "PROFILE_EVENT_CHART_STYLE_FIRST"
		KIND_STREAK:
			return "PROFILE_EVENT_STREAK_LOGIN"
		_:
			return "PROFILE_EVENT_GENERIC"


static func _track_line(entry: Dictionary) -> String:
	var title := str(entry.get("title", "")).strip_edges()
	var artist := str(entry.get("artist", "")).strip_edges()
	if title == "" and artist == "":
		return ""
	if artist == "":
		return title
	if title == "":
		return artist
	return "%s — %s" % [artist, title]


static func _milestone_title_key(key: String) -> String:
	match key:
		"first_track_played":
			return "PROFILE_RECORD_MILESTONE_FIRST_TRACK"
		"first_ss":
			return "PROFILE_RECORD_MILESTONE_FIRST_SS"
		"first_s":
			return "PROFILE_RECORD_MILESTONE_FIRST_S"
		"first_hidden_clear":
			return "PROFILE_RECORD_MILESTONE_FIRST_HIDDEN"
		"first_fc":
			return "PROFILE_RECORD_MILESTONE_FIRST_FC"
		"first_medal":
			return "PROFILE_RECORD_MILESTONE_FIRST_MEDAL"
		"unique_100_tracks":
			return "PROFILE_RECORD_MILESTONE_UNIQUE_100"
		"clears_1000":
			return "PROFILE_RECORD_MILESTONE_CLEARS_1000"
		"clears_250":
			return "PROFILE_RECORD_MILESTONE_CLEARS_250"
		"endless_unlocked":
			return "PROFILE_RECORD_MILESTONE_ENDLESS"
		"marathon_unlocked":
			return "PROFILE_RECORD_MILESTONE_MARATHON"
		"first_mod_clear":
			return "PROFILE_RECORD_MILESTONE_FIRST_MOD"
		"genre_group_level_10":
			return "PROFILE_RECORD_MILESTONE_GENRE_L10"
		"total_rr_10000":
			return "PROFILE_RECORD_MILESTONE_RR_10K"
		_:
			return key


static func _milestone_icon(key: String) -> String:
	match key:
		"first_track_played":
			return "circle-play.svg"
		"first_ss":
			return "trophy.svg"
		"first_s":
			return "star.svg"
		"first_hidden_clear":
			return "eye-off.svg"
		"first_fc":
			return "clock.svg"
		"first_medal":
			return "trophy.svg"
		"unique_100_tracks":
			return "hash.svg"
		"clears_1000":
			return "target.svg"
		"clears_250":
			return "target.svg"
		"endless_unlocked":
			return "repeat.svg"
		"marathon_unlocked":
			return "layers.svg"
		"first_mod_clear":
			return "eye-off.svg"
		"genre_group_level_10":
			return "tags.svg"
		"total_rr_10000":
			return "fingerprint-pattern.svg"
		_:
			return "sparkles.svg"
