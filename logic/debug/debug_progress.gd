# logic/debug/debug_progress.gd
extends RefCounted
class_name DebugProgress

const _ProfileEventLog = preload("res://logic/domain/profile/profile_event_log.gd")
const _TimeUtils = preload("res://logic/platform/time_utils.gd")
const _GenreGroupIcons = preload("res://logic/domain/library/genre_group_icons.gd")
const _ProfileGenrePortrait = preload("res://logic/domain/profile/profile_genre_portrait.gd")

static var _event: Dictionary = {}

static func has_event() -> bool:
	return not _event.is_empty()

static func get_event() -> Dictionary:
	return _event.duplicate(true)

static func clear() -> void:
	_event.clear()

static func set_milestone(id: String) -> bool:
	var key := id.strip_edges()
	if key == "":
		return false
	# Whitelist is defined in MainMenuActivityFeed, but duplicate minimal check here for validation
	# Use same list to avoid second independent whitelist - keep in sync with activity feed
	const _Whitelist: Array[String] = [
		"first_track_played", "first_ss", "first_fc", "first_mod_clear",
		"unique_100_tracks", "clears_250", "genre_group_level_10",
		"total_rr_10000", "endless_unlocked", "marathon_unlocked",
	]
	if not _Whitelist.has(key):
		return false
	var ts := _TimeUtils.now_local_datetime_string()
	var title_key := _ProfileEventLog._milestone_title_key(key)
	# Fallback if mapping fails
	if title_key.strip_edges() == "" or title_key == key:
		title_key = "PROFILE_EVENT_MILESTONE"
		var mapped := _ProfileEventLog._milestone_title_key(key)
		if mapped != "" and mapped != key:
			title_key = mapped
	var icon := _ProfileEventLog._milestone_icon(key)
	if icon == "":
		icon = "flag.svg"
	var detail := ""
	# For genre_group_level_10, detail is group title
	if key == "genre_group_level_10":
		detail = "Electronic"
	var ev := {
		"id": "debug_progress_milestone_%s_%s" % [key, ts],
		"ts": ts,
		"kind": _ProfileEventLog.KIND_MILESTONE,
		"title_key": "PROFILE_EVENT_MILESTONE",
		"title_arg": title_key,
		"detail": detail,
		"song_path": "",
		"icon": icon,
	}
	# Sanitize via ProfileEventLog to ensure icon/timestamp normalization
	ev = _ProfileEventLog.sanitize_event(ev)
	if ev.is_empty():
		return false
	_event = ev
	return true

static func set_genre_mastery(level_str: String) -> bool:
	var lvl := int(level_str.strip_edges())
	const _Allowed: Array[int] = [5, 10, 15, 20]
	if not _Allowed.has(lvl):
		return false
	var ts := _TimeUtils.now_local_datetime_string()
	# Use a default group for debug - rock
	var gid := "rock"
	var group_key := _ProfileGenrePortrait.group_locale_key(gid)
	var ev := {
		"id": "debug_progress_genre_mastery_%d_%s" % [lvl, ts],
		"ts": ts,
		"kind": _ProfileEventLog.KIND_GENRE_MASTERY,
		"title_key": "PROFILE_EVENT_GENRE_MASTERY",
		"title_arg": group_key,
		"detail": "",
		"song_path": "",
		"icon": "tags.svg",
		"level": lvl,
	}
	ev = _ProfileEventLog.sanitize_event(ev)
	if ev.is_empty():
		return false
	_event = ev
	return true

static func set_rr_total(threshold_str: String) -> bool:
	var v := int(str(threshold_str).strip_edges().replace(" ", "").replace(",", ""))
	const _Allowed: Array[int] = [25000, 50000, 100000, 250000, 500000, 1000000]
	if not _Allowed.has(v):
		return false
	var ts := _TimeUtils.now_local_datetime_string()
	var ev := {
		"id": "debug_progress_rr_total_%d_%s" % [v, ts],
		"ts": ts,
		"kind": _ProfileEventLog.KIND_RR_TOTAL,
		"title_key": "PROFILE_EVENT_RR_TOTAL",
		"title_arg": str(v),
		"detail": "",
		"song_path": "",
		"icon": "fingerprint-pattern.svg",
	}
	ev = _ProfileEventLog.sanitize_event(ev)
	if ev.is_empty():
		return false
	_event = ev
	return true

static func set_library(threshold_str: String) -> bool:
	var v := int(str(threshold_str).strip_edges().replace(" ", ""))
	const _Allowed: Array[int] = [100, 500, 1000]
	if not _Allowed.has(v):
		return false
	var ts := _TimeUtils.now_local_datetime_string()
	var ev := {
		"id": "debug_progress_library_%d_%s" % [v, ts],
		"ts": ts,
		"kind": _ProfileEventLog.KIND_LIBRARY_SIZE,
		"title_key": "PROFILE_EVENT_LIBRARY_SIZE",
		"title_arg": str(v),
		"detail": "",
		"song_path": "",
		"icon": "hash.svg",
	}
	ev = _ProfileEventLog.sanitize_event(ev)
	if ev.is_empty():
		return false
	_event = ev
	return true
