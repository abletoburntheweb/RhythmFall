# scenes/main_menu/lib/main_menu_activity_feed.gd
extends RefCounted
class_name MainMenuActivityFeed

const _AchievementLocale = preload("res://logic/i18n/achievement_locale.gd")
const _DailyQuestLocale = preload("res://logic/i18n/daily_quest_locale.gd")
const _GenPresetUi = preload("res://logic/ui/generation_preset_ui.gd")
const _SongSelectStrings = preload("res://logic/domain/library/song_select_strings.gd")

const MAX_ITEMS := 5

const _ProfileEventLog = preload("res://logic/domain/profile/profile_event_log.gd")
const _DebugProgress = preload("res://logic/debug/debug_progress.gd")
const _DebugScenario = preload("res://logic/debug/debug_scenario.gd")

const PROGRESS_MILESTONES: Array[String] = [
	"first_track_played",
	"first_ss",
	"first_fc",
	"first_mod_clear",
	"unique_100_tracks",
	"clears_250",
	"genre_group_level_10",
	"total_rr_10000",
	"endless_unlocked",
	"marathon_unlocked",
]

const PROGRESS_GENRE_MASTERY_LEVELS: Array[int] = [5, 10, 15, 20]
const PROGRESS_RR_THRESHOLDS: Array[int] = [25000, 50000, 100000, 250000, 500000, 1000000]
const PROGRESS_LIBRARY_THRESHOLDS: Array[int] = [100, 500, 1000]

# Fixed display order in the main-menu activity panel (not sorted by date).
const DISPLAY_ORDER: Array[String] = [
	"session",
	"daily",
	"achievement",
	"generation",
	"progress",
]


static func collect_entries(
	history: Array,
	daily_quests: Array,
	achievements: Array,
	resolve_track_labels: Callable = Callable(),
	daily_quests_date: String = "",
	last_daily_completion: Dictionary = {}
) -> Array:
	if _DebugScenario.has_activity_override():
		return _DebugScenario.get_activity_override()

	var by_kind: Dictionary = {}

	var latest_session := _pick_latest_session(history, resolve_track_labels)
	if not latest_session.is_empty():
		by_kind["session"] = latest_session

	var today := TimeUtils.now_local_datetime_string().substr(0, 10)
	if daily_quests_date.strip_edges() == "":
		daily_quests_date = today
	var daily_entry := _build_daily_entry_from_record(last_daily_completion)
	if daily_entry.is_empty():
		daily_entry = _pick_latest_daily_from_quests(daily_quests, daily_quests_date)
	if not daily_entry.is_empty():
		by_kind["daily"] = daily_entry

	var latest_ach := _pick_latest_achievement(achievements)
	if not latest_ach.is_empty():
		by_kind["achievement"] = latest_ach

	var generation_entry := _build_generation_entry(
		PlayerDataManager.data.get("last_chart_generation", {}) if PlayerDataManager else {}
	)
	if not generation_entry.is_empty():
		by_kind["generation"] = generation_entry

	var progress_entry := _build_progress_entry()
	if not progress_entry.is_empty():
		by_kind["progress"] = progress_entry

	var entries: Array = []
	for kind in DISPLAY_ORDER:
		if by_kind.has(kind):
			entries.append(by_kind[kind])
	return entries


static func _is_progress_milestone(ev: Dictionary) -> bool:
	if str(ev.get("kind", "")) != _ProfileEventLog.KIND_MILESTONE:
		return false
	var raw_key := _ProfileEventLog.milestone_raw_key(ev)
	return PROGRESS_MILESTONES.has(raw_key)

static func _is_progress_event(ev: Dictionary) -> bool:
	var kind := str(ev.get("kind", ""))
	match kind:
		_ProfileEventLog.KIND_MILESTONE:
			return _is_progress_milestone(ev)
		_ProfileEventLog.KIND_GENRE_MASTERY:
			return int(ev.get("level", 0)) in PROGRESS_GENRE_MASTERY_LEVELS
		_ProfileEventLog.KIND_RR_TOTAL:
			var v := int(str(ev.get("title_arg", "")).replace(" ", ""))
			return v in PROGRESS_RR_THRESHOLDS
		_ProfileEventLog.KIND_LIBRARY_SIZE:
			var v2 := int(str(ev.get("title_arg", "")).replace(" ", ""))
			return v2 in PROGRESS_LIBRARY_THRESHOLDS
		_:
			return false

static func _pick_latest_progress() -> Dictionary:
	if not PlayerDataManager:
		return {}
	var store: Dictionary = _ProfileEventLog.get_store_from_player_data(PlayerDataManager.data)
	var events: Variant = store.get("events", [])
	if not events is Array:
		return {}
	var best: Dictionary = {}
	var best_ts := -1
	for ev in events:
		if not ev is Dictionary:
			continue
		if not _is_progress_event(ev):
			continue
		var ts := _ProfileEventLog._event_sort_key(ev)
		if ts > best_ts:
			best_ts = ts
			best = ev
	# Fallback: if event log empty but milestones dict has whitelisted entries (e.g. before backfill), pick from milestones directly
	if best.is_empty() and ProfileMilestonesManager:
		var data: Dictionary = ProfileMilestonesManager.get_data()
		var milestones: Variant = data.get("milestones", {})
		if milestones is Dictionary:
			for key in PROGRESS_MILESTONES:
				var entry: Variant = milestones.get(key, null)
				if not entry is Dictionary or (entry as Dictionary).is_empty():
					continue
				var date_str := str(entry.get("date", ""))
				var ts2 := TimeUtils.unix_from_local_iso_datetime(date_str)
				if ts2 > best_ts:
					best_ts = ts2
					# Synthesize minimal event-like dict for fallback
					best = {
						"kind": _ProfileEventLog.KIND_MILESTONE,
						"ts": date_str,
						"title_key": "PROFILE_EVENT_MILESTONE",
						"title_arg": _ProfileEventLog._milestone_title_key(key),
						"detail": str(entry.get("title", "")) if str(entry.get("title", "")) != "" else _ProfileEventLog._track_line(entry),
						"song_path": str(entry.get("song_path", "")),
						"icon": _ProfileEventLog._milestone_icon(key),
					}
	# Consider debug progress event (runtime only, no persistence) — must pass same whitelist check
	if _DebugProgress.has_event():
		var dbg := _DebugProgress.get_event()
		if _is_progress_event(dbg):
			var dbg_ts := _ProfileEventLog._event_sort_key(dbg)
			if dbg_ts > best_ts:
				best_ts = dbg_ts
				best = dbg

	return best

static func _build_progress_entry() -> Dictionary:
	var ev := _pick_latest_progress()
	if ev.is_empty():
		return {}
	var ts := _ProfileEventLog._event_sort_key(ev)
	var icon_file := str(ev.get("icon", "flag.svg"))
	var icon_color: Color = _ProfileEventLog.tint_for_event(ev)
	var title := _ProfileEventLog.format_subtitle(ev)
	if title.strip_edges() == "":
		title = _ProfileEventLog.format_headline(ev)
	return {
		"kind": "progress",
		"timestamp": ts,
		"icon_file": icon_file,
		"icon_color": icon_color,
		"progress_title": title,
		"event": ev,
	}


static func _pick_latest_session(history: Array, resolve_track_labels: Callable = Callable()) -> Dictionary:
	var latest: Dictionary = {}
	var latest_ts := -1
	for session in history:
		if not session is Dictionary:
			continue
		var date_str := str(session.get("date", ""))
		var ts := TimeUtils.unix_from_local_iso_datetime(date_str)
		if ts <= 0 or ts <= latest_ts:
			continue
		var title := ""
		var artist := ""
		if resolve_track_labels.is_valid():
			var resolved: Variant = resolve_track_labels.call(session)
			if resolved is Dictionary:
				title = str(resolved.get("title", "")).strip_edges()
				artist = str(resolved.get("artist", "")).strip_edges()
		var song_path := str(session.get("path", "")).strip_edges()
		if song_path == "":
			song_path = str(session.get("song_path", "")).strip_edges()
		var stem := song_path.get_file().get_basename() if song_path != "" else ""
		if title == "":
			title = _SongSelectStrings.display_track_title(session.get("title", ""), stem)
		if artist == "":
			artist = _SongSelectStrings.display_track_artist(session.get("artist", ""))
		var grade := str(session.get("grade", "")).strip_edges()
		if grade == "":
			grade = "—"
		latest_ts = ts
		latest = {
			"kind": "session",
			"timestamp": ts,
			"date_str": date_str,
			"icon_file": "circle-play.svg",
			"icon_color": Color(0.55, 0.92, 0.78, 1.0),
			"title": title,
			"artist": artist,
			"grade": grade,
		}
	return latest


static func _pick_latest_achievement(achievements: Array) -> Dictionary:
	var latest: Dictionary = {}
	var latest_ts := -1
	for ach in achievements:
		if not ach is Dictionary:
			continue
		if not bool(ach.get("unlocked", false)):
			continue
		var unlock_raw: Variant = ach.get("unlock_date", null)
		if unlock_raw == null:
			continue
		var unlock_str := str(unlock_raw).strip_edges()
		if unlock_str == "":
			continue
		var ts := TimeUtils.unix_from_unlock_date(unlock_str)
		if ts <= 0 or ts <= latest_ts:
			continue
		latest_ts = ts
		latest = {
			"kind": "achievement",
			"timestamp": ts,
			"unlock_str": unlock_str,
			"icon_file": "trophy.svg",
			"icon_color": Color(0.72, 0.58, 0.95, 1.0),
			"achievement": ach,
		}
	return latest


static func _build_generation_entry(record: Dictionary) -> Dictionary:
	if not record is Dictionary or record.is_empty():
		return {}
	var completed_at := str(record.get("completed_at", "")).strip_edges()
	if completed_at == "":
		return {}
	var ts := TimeUtils.unix_from_local_iso_datetime(completed_at)
	if ts <= 0:
		return {}
	var title := str(record.get("title", "")).strip_edges()
	var artist := str(record.get("artist", "")).strip_edges()
	if title == "" or title == "N/A":
		title = "—"
	if artist == "" or artist == "N/A":
		artist = "—"
	return {
		"kind": "generation",
		"timestamp": ts,
		"completed_at": completed_at,
		"icon_file": "sparkles.svg",
		"icon_color": Color(0.78, 0.66, 0.98, 1.0),
		"title": title,
		"artist": artist,
		"instrument": str(record.get("instrument", "drums")),
		"mode": str(record.get("mode", "basic")),
		"lanes": int(record.get("lanes", 4)),
	}




static func format_entry_text(entry: Dictionary) -> String:
	match str(entry.get("kind", "")):
		"session":
			return TranslationServer.translate("MAIN_ACTIVITY_SESSION") % [
				str(entry.get("artist", "—")),
				str(entry.get("title", "—")),
				str(entry.get("grade", "—")),
			]
		"daily":
			return TranslationServer.translate("MAIN_ACTIVITY_DAILY") % str(entry.get("quest_title", ""))
		"achievement":
			var ach: Dictionary = entry.get("achievement", {})
			return TranslationServer.translate("MAIN_ACTIVITY_ACHIEVEMENT") % _AchievementLocale.localized_title(ach)
		"generation":
			var settings := "%s · %s" % [
				_GenPresetUi.localized_instrument(str(entry.get("instrument", "drums"))),
				_GenPresetUi.localized_mode(str(entry.get("mode", "basic"))),
			]
			return TranslationServer.translate("MAIN_ACTIVITY_GENERATION") % [
				str(entry.get("artist", "—")),
				str(entry.get("title", "—")),
				settings,
			]
		"progress":
			var evp: Dictionary = entry.get("event", {})
			var txt := str(entry.get("progress_title", ""))
			if txt.strip_edges() == "" and not evp.is_empty():
				txt = _ProfileEventLog.format_subtitle(evp)
			if txt.strip_edges() == "" and not evp.is_empty():
				txt = _ProfileEventLog.format_headline(evp)
			if txt.strip_edges() == "":
				txt = str(entry.get("title", ""))
			return TranslationServer.translate("MAIN_ACTIVITY_PROGRESS") % txt
	return ""


static func format_entry_time(entry: Dictionary) -> String:
	var ts := int(entry.get("timestamp", 0))
	if ts <= 0:
		match str(entry.get("kind", "")):
			"session":
				return TimeUtils.format_relative_ago_from_local_iso(str(entry.get("date_str", "")))
			"progress":
				var ev2: Dictionary = entry.get("event", {})
				if not ev2.is_empty():
					return TimeUtils.format_relative_ago_from_unix(_ProfileEventLog._event_sort_key(ev2))
				return TimeUtils.format_relative_ago_from_local_iso(str(entry.get("date_str", "")))
			"daily", "generation":
				return TimeUtils.format_relative_ago_from_local_iso(str(entry.get("completed_at", "")))
			"achievement":
				return TimeUtils.format_relative_ago_from_unix(
					TimeUtils.unix_from_unlock_date(str(entry.get("unlock_str", "")))
				)
		return ""
	return TimeUtils.format_relative_ago_from_unix(ts)


static func _build_daily_entry_from_record(record: Dictionary) -> Dictionary:
	if not record is Dictionary or record.is_empty():
		return {}
	var quest_id := str(record.get("id", "")).strip_edges()
	var completed_at := str(record.get("completed_at", "")).strip_edges()
	if quest_id == "" or completed_at == "":
		return {}
	var ts := TimeUtils.unix_from_local_iso_datetime(completed_at)
	if ts <= 0:
		return {}
	var date_key := str(record.get("date", completed_at.substr(0, 10))).strip_edges()
	var quest := {"id": quest_id}
	return {
		"kind": "daily",
		"timestamp": ts,
		"completed_at": completed_at,
		"completed_at_estimated": bool(record.get("estimated", false)),
		"icon_file": "list-checks.svg",
		"icon_color": Color(0.95, 0.78, 0.35, 1.0),
		"quest_title": _DailyQuestLocale.localized_title(quest),
		"date_key": date_key,
	}


static func _pick_latest_daily_from_quests(daily_quests: Array, daily_quests_date: String) -> Dictionary:
	var latest_daily: Dictionary = {}
	var latest_daily_ts := -1
	for quest in daily_quests:
		if not quest is Dictionary:
			continue
		if not bool(quest.get("completed", false)):
			continue
		var completed_at := str(quest.get("completed_at", "")).strip_edges()
		var ts_daily := TimeUtils.unix_from_local_iso_datetime(completed_at)
		var estimated := false
		if ts_daily <= 0 and daily_quests_date.strip_edges() != "":
			var backfill := _backfill_daily_timestamp(daily_quests_date)
			ts_daily = TimeUtils.unix_from_local_iso_datetime(backfill)
			completed_at = backfill
			estimated = true
		if ts_daily <= 0:
			continue
		if ts_daily > latest_daily_ts:
			latest_daily_ts = ts_daily
			latest_daily = {
				"kind": "daily",
				"timestamp": ts_daily,
				"completed_at": completed_at,
				"completed_at_estimated": estimated,
				"icon_file": "list-checks.svg",
				"icon_color": Color(0.95, 0.78, 0.35, 1.0),
				"quest_title": _DailyQuestLocale.localized_title(quest),
				"date_key": daily_quests_date,
			}
	return latest_daily


static func _backfill_daily_timestamp(day: String) -> String:
	var day_key := day.strip_edges()
	var today := Time.get_date_string_from_system()
	if day_key == "":
		day_key = today
	var now_str := TimeUtils.now_local_datetime_string()
	if day_key < today:
		return "%s 12:00:00" % day_key
	if day_key == today:
		var noon := "%s 12:00:00" % day_key
		if TimeUtils.unix_from_local_iso_datetime(noon) <= TimeUtils.unix_from_local_iso_datetime(now_str):
			return noon
		return "%s 00:00:01" % day_key
	return "%s 12:00:00" % day_key
