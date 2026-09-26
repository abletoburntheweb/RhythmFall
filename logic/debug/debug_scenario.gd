# logic/debug/debug_scenario.gd
extends RefCounted
class_name DebugScenario

const _DailyQuestLocale = preload("res://logic/i18n/daily_quest_locale.gd")
const _AchievementLocale = preload("res://logic/i18n/achievement_locale.gd")
const _GenPresetUi = preload("res://logic/ui/generation_preset_ui.gd")
const _ProfileEventLog = preload("res://logic/domain/profile/profile_event_log.gd")
const _TimeUtils = preload("res://logic/platform/time_utils.gd")

static var _activity_override: Array = []

static func has_activity_override() -> bool:
	return not _activity_override.is_empty()

static func get_activity_override() -> Array:
	return _activity_override.duplicate(true)

static func clear_activity() -> void:
	_activity_override.clear()

static func set_activity() -> void:
	var now_str := _TimeUtils.now_local_datetime_string()
	var ts := _TimeUtils.unix_from_local_iso_datetime(now_str)
	if ts <= 0:
		ts = int(Time.get_unix_time_from_system())
	# 1. session — very long title/artist, grade SS
	var session_entry := {
		"kind": "session",
		"timestamp": ts,
		"date_str": now_str,
		"icon_file": "circle-play.svg",
		"icon_color": Color(0.55, 0.92, 0.78, 1.0),
		"title": "Супер-длинное название трека для проверки автопереноса и обрезки эллипсисом — The Longest Track Name That Should Wrap Or Ellipsize Correctly And Even Longer To Test Overflow Handling In Activity Feed Row With Extra Length To Ensure Proper Display Behavior In All Languages",
		"artist": "Исполнитель с очень длинным именем для проверки обрезки — Artist With Extremely Long Name For Testing Ellipsis And Wrapping Behavior In Session Entry With Additional Characters To Push Limits",
		"grade": "SS",
	}
	# 2. daily — real quest id play_group_rock_2
	var quest := {"id": "play_group_rock_2"}
	var quest_title := _DailyQuestLocale.localized_title(quest)
	# Fallback if locale returns empty
	if quest_title.strip_edges() == "":
		quest_title = "Сыграть в рок (2)"
	var daily_entry := {
		"kind": "daily",
		"timestamp": ts,
		"completed_at": now_str,
		"completed_at_estimated": false,
		"icon_file": "list-checks.svg",
		"icon_color": Color(0.95, 0.78, 0.35, 1.0),
		"quest_title": quest_title,
		"date_key": now_str.substr(0, 10),
	}
	# 3. achievement — long title, current time
	var unlock_str := ""
	var date_dict := Time.get_date_dict_from_system()
	var time_dict := Time.get_time_dict_from_system()
	var date_text := _TimeUtils.format_date_parts_ru(int(date_dict.day), int(date_dict.month), int(date_dict.year))
	unlock_str = "%s, %02d:%02d" % [date_text, int(time_dict.hour), int(time_dict.minute)]
	var ach_title := "Очень длинное название достижения для проверки переполнения и обрезки в строке Activity — This Is A Very Long Achievement Name That Should Test Wrapping And Ellipsis Handling In The Activity Feed Row Correctly With Extra Length"
	var ach := {
		"id": 9999,
		"title": ach_title,
		"category": "test",
		"unlocked": true,
		"unlock_date": unlock_str,
		"current": 1,
		"total": 1,
	}
	var achievement_entry := {
		"kind": "achievement",
		"timestamp": _TimeUtils.unix_from_unlock_date(unlock_str) if _TimeUtils.unix_from_unlock_date(unlock_str) > 0 else ts,
		"unlock_str": unlock_str,
		"icon_file": "trophy.svg",
		"icon_color": Color(0.72, 0.58, 0.95, 1.0),
		"achievement": ach,
	}
	# 4. generation — long title/artist, valid instrument/mode/lanes
	var generation_entry := {
		"kind": "generation",
		"timestamp": ts,
		"completed_at": now_str,
		"icon_file": "sparkles.svg",
		"icon_color": Color(0.78, 0.66, 0.98, 1.0),
		"title": "Очень длинное название сгенерированного трека для проверки переноса — The Longest Generated Track Title For Testing Overflow Handling In Activity Feed Row And Ensuring Correct Display With Extra Length",
		"artist": "Исполнитель с очень длинным именем для проверки обрезки — Artist With Extremely Long Name For Testing Ellipsis And Wrapping Behavior In Generation Entry With Additional Characters",
		"instrument": "drums",
		"mode": "basic",
		"lanes": 4,
	}
	# 5. progress — whitelist milestone unique_100_tracks via DebugProgress-compatible event
	var progress_event := {
		"id": "debug_scenario_progress_milestone_unique_100_tracks_%s" % now_str,
		"ts": now_str,
		"kind": _ProfileEventLog.KIND_MILESTONE,
		"title_key": "PROFILE_EVENT_MILESTONE",
		"title_arg": _ProfileEventLog._milestone_title_key("unique_100_tracks"),
		"detail": "Debug Scenario — 100 уникальных треков",
		"song_path": "",
		"icon": _ProfileEventLog._milestone_icon("unique_100_tracks"),
	}
	progress_event = _ProfileEventLog.sanitize_event(progress_event)
	var progress_title := _ProfileEventLog.format_subtitle(progress_event)
	if progress_title.strip_edges() == "":
		progress_title = _ProfileEventLog.format_headline(progress_event)
	if progress_title.strip_edges() == "":
		progress_title = "100 уникальных треков"
	var progress_entry := {
		"kind": "progress",
		"timestamp": _ProfileEventLog._event_sort_key(progress_event),
		"icon_file": str(progress_event.get("icon", "flag.svg")),
		"icon_color": _ProfileEventLog.tint_for_event(progress_event),
		"progress_title": progress_title,
		"event": progress_event,
	}
	# Ensure timestamp is valid
	if int(progress_entry.get("timestamp", 0)) <= 0:
		progress_entry["timestamp"] = ts

	_activity_override = [session_entry, daily_entry, achievement_entry, generation_entry, progress_entry]
