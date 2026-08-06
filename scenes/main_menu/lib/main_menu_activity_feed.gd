# scenes/main_menu/lib/main_menu_activity_feed.gd
extends RefCounted
class_name MainMenuActivityFeed

const _AchievementLocale = preload("res://logic/i18n/achievement_locale.gd")
const _DailyQuestLocale = preload("res://logic/i18n/daily_quest_locale.gd")
const _GenPresetUi = preload("res://logic/ui/generation_preset_ui.gd")
const _SongSelectStrings = preload("res://logic/domain/library/song_select_strings.gd")

const MAX_ITEMS := 5

# Fixed display order in the main-menu activity panel (not sorted by date).
const DISPLAY_ORDER: Array[String] = [
	"session",
	"daily",
	"achievement",
	"generation",
	"record",
]


static func collect_entries(
	history: Array,
	daily_quests: Array,
	achievements: Array,
	resolve_track_labels: Callable = Callable(),
	daily_quests_date: String = "",
	last_daily_completion: Dictionary = {}
) -> Array:
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

	var record_entry := _build_record_entry(_read_last_personal_record())
	if not record_entry.is_empty():
		by_kind["record"] = record_entry

	var entries: Array = []
	for kind in DISPLAY_ORDER:
		if by_kind.has(kind):
			entries.append(by_kind[kind])
	return entries


static func _read_last_personal_record() -> Dictionary:
	if not ProfileMilestonesManager:
		return {}
	var extremes: Variant = ProfileMilestonesManager.get_data().get("extremes", {})
	if not extremes is Dictionary:
		return {}
	var last_rec: Variant = extremes.get("last_personal_record", {})
	return last_rec if last_rec is Dictionary else {}


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


static func _build_record_entry(record: Dictionary) -> Dictionary:
	if not record is Dictionary or record.is_empty():
		return {}
	var best_rr := int(record.get("best_rr", 0))
	if best_rr <= 0:
		return {}
	var date_str := str(record.get("date", "")).strip_edges()
	var ts := TimeUtils.unix_from_local_iso_datetime(date_str) if date_str != "" else 0
	var title := str(record.get("title", "")).strip_edges()
	var artist := str(record.get("artist", "")).strip_edges()
	if title == "" or title == "N/A":
		title = "—"
	if artist == "" or artist == "N/A":
		artist = "—"
	return {
		"kind": "record",
		"timestamp": ts,
		"date_str": date_str,
		"icon_file": "flame.svg",
		"icon_color": Color(1.0, 0.58, 0.32, 1.0),
		"title": title,
		"artist": artist,
		"best_rr": best_rr,
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
		"record":
			return TranslationServer.translate("MAIN_ACTIVITY_RECORD") % [
				str(entry.get("artist", "—")),
				str(entry.get("title", "—")),
				int(entry.get("best_rr", 0)),
			]
	return ""


static func format_entry_time(entry: Dictionary) -> String:
	var ts := int(entry.get("timestamp", 0))
	if ts <= 0:
		match str(entry.get("kind", "")):
			"session", "record":
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
