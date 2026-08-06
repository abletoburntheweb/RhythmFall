# scenes/profile/share/profile_share_snapshot.gd
class_name ProfileShareSnapshot
extends RefCounted

const ResultsHistoryService = preload("res://logic/data/results_history_service.gd")
const _Favorite = preload("res://scenes/profile/share/profile_share_favorite.gd")
const _GenrePortrait = preload("res://logic/domain/profile/profile_genre_portrait.gd")
const _GenreMastery = preload("res://logic/domain/profile/profile_genre_mastery.gd")
const GradeDisplay = preload("res://logic/ui/grade_display.gd")
const ChartDifficultyAnalyzer = preload("res://logic/domain/charts/chart_difficulty_analyzer.gd")
const TimeUtils = preload("res://logic/platform/time_utils.gd")
const _PlayModes = preload("res://logic/domain/profile/profile_play_modes_stats.gd")
const _ProfileEventLog = preload("res://logic/domain/profile/profile_event_log.gd")
const _TimeCapsule = preload("res://logic/domain/profile/time_capsule.gd")
const _Taglines = preload("res://scenes/profile/share/profile_share_taglines.gd")
const PlayModeIds = preload("res://logic/domain/session/play_mode_ids.gd")

const CARD_IDS: Array[String] = ["overview", "statistics", "music", "records", "play_modes"]

# Keep in sync with ProfileShareHtmlPayload.MILESTONE_SPECS (easy → hard).
const SHARE_MILESTONE_KEYS: Array[String] = [
	"first_track_played",
	"first_ss",
	"first_fc",
	"first_mod_clear",
	"endless_unlocked",
	"marathon_unlocked",
	"unique_100_tracks",
	"clears_250",
	"total_rr_10000",
	"genre_group_level_10",
]

const CARD_ACCENT_COLORS := {
	"overview": Color(0.62, 0.52, 0.92, 1.0),
	"statistics": Color(0.45, 0.65, 0.95, 1.0),
	"music": Color(0.38, 0.78, 0.55, 1.0),
	"records": Color(0.92, 0.78, 0.42, 1.0),
	"play_modes": Color(0.75, 0.52, 0.98, 1.0),
}

static var _history_service: ResultsHistoryService = null


static func _history() -> ResultsHistoryService:
	if _history_service == null:
		_history_service = ResultsHistoryService.new()
	return _history_service


static func build_all() -> Dictionary:
	var out := {}
	for card_id in CARD_IDS:
		out[card_id] = build_card(card_id)
	return out


static var _cached_snapshot: Dictionary = {}
static var _cached_snapshot_hash: String = ""


static func build_all_cached() -> Dictionary:
	var fingerprint := _profile_fingerprint()
	if fingerprint == _cached_snapshot_hash and not _cached_snapshot.is_empty():
		return _cached_snapshot
	var fresh := build_all()
	_cached_snapshot = fresh
	_cached_snapshot_hash = fingerprint
	return fresh


static func invalidate_cache() -> void:
	_cached_snapshot.clear()
	_cached_snapshot_hash = ""


static func _profile_fingerprint() -> String:
	var parts: Array[String] = [
		str(PlayerDataManager.get_current_level()),
		"%.4f" % PlayerDataManager.get_xp_progress(),
		str(PlayerDataManager.data.get("total_play_time_seconds", 0)),
		str(TranslationServer.get_locale()),
	]
	if ProfileMilestonesManager:
		parts.append(str(ProfileMilestonesManager.get_total_rr_earned()))
	return "|".join(parts)


static func build_card(card_id: String) -> Dictionary:
	match card_id:
		"overview":
			return _build_overview()
		"statistics":
			return _build_statistics()
		"music":
			return _build_music()
		"records":
			return _build_records()
		"play_modes":
			return _build_play_modes()
	return {"card_id": card_id}


static func export_filename(card_id: String) -> String:
	return "rhythmfall_share_%s.png" % card_id


static func footer_date_text() -> String:
	return export_date_text()


static func export_date_text() -> String:
	var d := Time.get_date_dict_from_system(false)
	var iso := "%04d-%02d-%02d" % [int(d.get("year", 0)), int(d.get("month", 0)), int(d.get("day", 0))]
	return TimeUtils.format_iso_date_localized(iso)


static func member_since_text() -> String:
	var iso := str(PlayerDataManager.data.get("profile_created_date", "")).strip_edges()
	if iso == "":
		return ""
	var formatted := TimeUtils.format_iso_date_localized(iso)
	return TranslationServer.translate("PROFILE_SHARE_MEMBER_SINCE") % formatted


static func _hit_rate_percent() -> float:
	var hit := PlayerDataManager.get_total_notes_hit()
	var miss := PlayerDataManager.get_total_notes_missed()
	var played := hit + miss
	if played <= 0:
		return 0.0
	return (float(hit) / float(played)) * 100.0


static func _session_count() -> int:
	return _history().get_history().size()


static func _rr_top_rows(limit: int = 3) -> Array:
	if not ProfileMilestonesManager:
		return []
	var top: Array = ProfileMilestonesManager.get_rhythm_rating_top10()
	var rows: Array = []
	for entry in top:
		if not entry is Dictionary:
			continue
		if int(entry.get("best_rr", 0)) <= 0:
			continue
		rows.append(entry.duplicate(true))
		if rows.size() >= limit:
			break
	return rows


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


static func _overall_accuracy_percent() -> float:
	var hit := PlayerDataManager.get_total_notes_hit()
	var miss := PlayerDataManager.get_total_notes_missed()
	var played := hit + miss
	if played > 0:
		return (float(hit) / float(played)) * 100.0
	return 0.0


static func _rr_earned() -> int:
	if ProfileMilestonesManager:
		return ProfileMilestonesManager.get_total_rr_earned()
	return 0


static func _medal_total() -> int:
	return int(_history().get_global_medal_stats().get("total_medal_count", 0))


static func _accuracy_trend_points(limit: int = 20) -> Array:
	var history: Array = _history().get_history()
	if history.is_empty():
		return []
	var start := maxi(0, history.size() - limit)
	var points: Array = []
	for session in history.slice(start, history.size()):
		if session is Dictionary:
			points.append(float(session.get("accuracy", 0.0)))
	return points


static func _days_in_game() -> int:
	var iso := str(PlayerDataManager.data.get("profile_created_date", "")).strip_edges()
	if iso == "":
		return 0
	var parts := iso.split("-")
	if parts.size() < 3:
		return 0
	var created: int = int(Time.get_unix_time_from_datetime_dict({
		"year": int(parts[0]),
		"month": int(parts[1]),
		"day": int(parts[2]),
		"hour": 0,
		"minute": 0,
		"second": 0,
	}))
	if created <= 0:
		return 0
	var now := Time.get_datetime_dict_from_system(true)
	var now_unix := Time.get_unix_time_from_datetime_dict(now)
	return maxi(0, int((now_unix - created) / 86400))


static func _avg_chart_difficulty() -> float:
	if PlayerDataManager.has_method("_maybe_rebuild_chart_difficulty_stats_from_results"):
		PlayerDataManager._maybe_rebuild_chart_difficulty_stats_from_results()
	return PlayerDataManager.get_average_chart_difficulty_cleared()


static func _top_genre_rows(limit: int = 6) -> Array:
	var counts := TrackStatsManager.genre_play_counts
	var aggregated := _GenrePortrait.aggregate_group_play_counts(counts)
	var total := 0
	for group in aggregated:
		total += int(aggregated[group])
	var top := _GenrePortrait.top_groups(counts, limit)
	var rows: Array = []
	for row in top:
		var group_id := str(row.get("group", ""))
		var count := int(row.get("count", 0))
		var percent := 0.0
		if total > 0:
			percent = (float(count) / float(total)) * 100.0
		rows.append({
			"group_id": group_id,
			"count": count,
			"percent": percent,
		})
	return rows


static func _top_genre_rows_with_mastery(limit: int = 5) -> Array:
	var counts := TrackStatsManager.genre_play_counts
	var discovery := _discovery_firsts()
	var rows := _top_genre_rows(limit)
	for row in rows:
		var group_id := str(row.get("group_id", ""))
		var plays := _GenrePortrait.group_play_count(counts, group_id)
		var prog := _GenreMastery.progress_to_next_level(plays)
		row["plays"] = plays
		row["mastery_level"] = int(prog.get("level", 0))
		row["mastery_ratio"] = float(prog.get("ratio", 0.0))
		row["discovered"] = _GenreMastery.discovered_count_in_group(group_id, counts)
		row["catalog"] = _GenreMastery.catalog_size_for_group(group_id)
		row["trend"] = _genre_trend(group_id, int(row["mastery_level"]), plays, discovery)
	return rows


static func _discovery_firsts() -> Dictionary:
	if ProfileMilestonesManager == null or not ProfileMilestonesManager.has_method("get_data"):
		return {}
	var data := ProfileMilestonesManager.get_data()
	var raw: Variant = data.get("discovery_firsts", {})
	return raw if raw is Dictionary else {}


static func _genre_trend(group_id: String, level: int, plays: int, discovery: Dictionary) -> String:
	if group_id == "" or group_id == "_other":
		return ""
	var first_date := str(discovery.get("ggroup_%s" % group_id, "")).strip_edges()
	if first_date != "" and _days_since(first_date) <= 45:
		return "new"
	if level <= 1 and plays > 0 and plays < 8:
		return "new"
	if level >= 3 or plays >= 25:
		return "growing"
	return ""


static func _days_since(date_str: String) -> int:
	var day := TimeUtils.iso_date_only(TimeUtils.normalize_to_local_iso(date_str))
	if day == "":
		return 9999
	var parts := day.split("-")
	if parts.size() < 3:
		return 9999
	var then_unix := Time.get_unix_time_from_datetime_dict({
		"year": int(parts[0]),
		"month": int(parts[1]),
		"day": int(parts[2]),
		"hour": 0,
		"minute": 0,
		"second": 0,
	})
	var now := Time.get_datetime_dict_from_system()
	var now_unix := Time.get_unix_time_from_datetime_dict({
		"year": int(now.get("year", 0)),
		"month": int(now.get("month", 0)),
		"day": int(now.get("day", 0)),
		"hour": 0,
		"minute": 0,
		"second": 0,
	})
	return int(floor(float(now_unix - then_unix) / 86400.0))


static func _story_lines(limit: int = 3) -> Array:
	if PlayerDataManager == null:
		return []
	var events := _ProfileEventLog.list_events(PlayerDataManager.data, _ProfileEventLog.FILTER_ALL)
	var lines: Array = []
	for ev in events:
		if lines.size() >= limit:
			break
		if not ev is Dictionary:
			continue
		var head := _ProfileEventLog.format_headline(ev)
		var sub := _ProfileEventLog.format_subtitle(ev)
		var line := head.strip_edges()
		if sub.strip_edges() != "":
			line = "%s · %s" % [line, sub.strip_edges()] if line != "" else sub.strip_edges()
		if line == "":
			continue
		lines.append(line)
	var level := PlayerDataManager.get_current_level()
	if level >= 2 and lines.size() < limit:
		lines.append(TranslationServer.translate("PROFILE_SHARE_STORY_LEVEL") % level)
	return lines


static func _capsule_deltas() -> Dictionary:
	if PlayerDataManager == null:
		return {}
	var store := PlayerDataManager.get_time_capsules()
	var prev_key := _TimeCapsule.previous_month_key()
	var capsule := _TimeCapsule.get_capsule(store, prev_key)
	if capsule.is_empty():
		return {}
	var now_level := PlayerDataManager.get_current_level()
	var now_tracks := PlayerDataManager.get_unique_levels_completed()
	var now_rr := _rr_earned()
	var then_level := int(capsule.get("level", 0))
	var then_tracks := int(capsule.get("levels_completed", 0))
	var then_rr := int(capsule.get("total_rr", 0))
	return {
		"level_delta": now_level - then_level,
		"tracks_delta": now_tracks - then_tracks,
		"rr_delta": now_rr - then_rr,
		"has_capsule": true,
	}


static func _accuracy_delta_from_trend(points: Array) -> float:
	if points.size() < 6:
		return 0.0
	var mid := int(points.size() / 2)
	var older := 0.0
	var newer := 0.0
	var oc := 0
	var nc := 0
	for i in range(points.size()):
		var v := float(points[i])
		if i < mid:
			older += v
			oc += 1
		else:
			newer += v
			nc += 1
	if oc <= 0 or nc <= 0:
		return 0.0
	return (newer / float(nc)) - (older / float(oc))


static func _most_replayed_track() -> Dictionary:
	if TrackStatsManager == null:
		return {}
	var path := str(TrackStatsManager.get_favorite_track()).replace("\\", "/").trim_suffix("/")
	var plays := int(TrackStatsManager.get_favorite_track_count())
	if path == "" or plays < 2:
		return {}
	var title := path.get_file().get_basename()
	var artist := ""
	if SongLibrary:
		var md := SongLibrary.get_metadata_for_song(path)
		if md is Dictionary:
			title = str(md.get("title", title))
			artist = str(md.get("artist", ""))
	return {
		"song_path": path,
		"title": title,
		"artist": artist,
		"plays": plays,
		"track": _track_line({"title": title, "artist": artist}),
	}


static func _format_delta(value: float, suffix: String = "", decimals: int = 0) -> String:
	if absf(value) < 0.05 and decimals > 0:
		return ""
	if absf(value) < 0.5 and decimals == 0:
		return ""
	var arrow := "↑" if value > 0.0 else "↓"
	var sign := "+" if value > 0.0 else ""
	if decimals > 0:
		return "%s %s%.1f%s" % [arrow, sign, absf(value), suffix]
	return "%s %s%d%s" % [arrow, sign, int(round(absf(value))), suffix]


static func _best_mastery_group_id() -> String:
	var leaders := _mastery_leaders(1)
	if leaders.is_empty():
		return ""
	return str(leaders[0].get("group_id", ""))


static func _milestone_unlocked(milestones: Dictionary, key: String) -> bool:
	if milestones.has(key):
		return true
	if key == "first_hidden_clear" and milestones.has("first_hidden"):
		return true
	return false


static func _milestones_unlocked_count(milestones: Dictionary) -> int:
	var n := 0
	for key in SHARE_MILESTONE_KEYS:
		if _milestone_unlocked(milestones, key):
			n += 1
	return n


static func _rr_spread(rr_top: Array) -> int:
	if rr_top.size() < 2:
		return 0
	var first_rr := int(rr_top[0].get("best_rr", 0)) if rr_top[0] is Dictionary else 0
	var last_rr := int(rr_top[rr_top.size() - 1].get("best_rr", 0)) if rr_top[rr_top.size() - 1] is Dictionary else 0
	if first_rr <= 0 or last_rr <= 0:
		return 0
	return maxi(0, first_rr - last_rr)


static func _shared_extreme_track(extremes: Dictionary) -> String:
	if extremes.is_empty():
		return ""
	var track_counts: Dictionary = {}
	for key in extremes:
		var entry: Variant = extremes[key]
		if not entry is Dictionary:
			continue
		var line := _track_line(entry)
		if line == "":
			continue
		track_counts[line] = int(track_counts.get(line, 0)) + 1
	for line in track_counts:
		if int(track_counts[line]) >= 2:
			return str(line)
	return ""


static func _mod_hard_bonus(mod_records: Dictionary) -> int:
	if not mod_records is Dictionary:
		return 0
	var hard_rec: Variant = mod_records.get("hardest_mod_combo")
	if not hard_rec is Dictionary:
		return 0
	return int(round(float(hard_rec.get("hardness", 0.0)) * 100.0))


static func _mastery_leaders(limit: int = 3) -> Array:
	var counts := TrackStatsManager.genre_play_counts
	var rows: Array = []
	for group_id in _GenrePortrait.all_group_ids():
		var plays := _GenrePortrait.group_play_count(counts, group_id)
		var level := _GenreMastery.level_from_plays(plays)
		if level <= 0:
			continue
		rows.append({"group_id": group_id, "level": level, "plays": plays})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("level", 0)) != int(b.get("level", 0)):
			return int(a.get("level", 0)) > int(b.get("level", 0))
		return int(a.get("plays", 0)) > int(b.get("plays", 0))
	)
	if rows.size() > limit:
		return rows.slice(0, limit)
	return rows


static func _build_overview() -> Dictionary:
	var fav := _Favorite.resolve()
	var top_genres := _top_genre_rows(1)
	var favorite_group := ""
	var favorite_group_percent := 0.0
	if not top_genres.is_empty():
		favorite_group = str(top_genres[0].get("group_id", ""))
		favorite_group_percent = float(top_genres[0].get("percent", 0.0))
	var track_path := str(fav.get("track_path", ""))
	var best_grade := GradeDisplay.best_grade_for_track(track_path)
	var data := {
		"card_id": "overview",
		"level": PlayerDataManager.get_current_level(),
		"xp_text": PlayerDataManager.get_xp_progress_text(),
		"xp_ratio": PlayerDataManager.get_xp_progress(),
		"rr_earned": _rr_earned(),
		"accuracy": _overall_accuracy_percent(),
		"play_time": fav.get("play_time", "0:00"),
		"levels_completed": PlayerDataManager.get_unique_levels_completed(),
		"member_since": member_since_text(),
		"medals_total": _medal_total(),
		"avg_difficulty": _avg_chart_difficulty(),
		"max_combo": int(PlayerDataManager.data.get("max_combo_ever", 0)),
		"total_score": int(PlayerDataManager.data.get("total_score_ever", 0)),
		"daily_quests": PlayerDataManager.get_daily_quests_completed_total(),
		"ss": int(PlayerDataManager.data.get("grades", {}).get("SS", 0)),
		"s": int(PlayerDataManager.data.get("grades", {}).get("S", 0)),
		"a": int(PlayerDataManager.data.get("grades", {}).get("A", 0)),
		"b": int(PlayerDataManager.data.get("grades", {}).get("B", 0)),
		"title": fav.get("title", ""),
		"artist": fav.get("artist", ""),
		"genre": fav.get("genre", ""),
		"play_count": int(fav.get("play_count", 0)),
		"cover": fav.get("cover"),
		"best_grade": best_grade,
		"favorite_group_id": favorite_group,
		"favorite_group_percent": favorite_group_percent,
		"top_genres_pair": _top_genre_rows(2),
		"days_in_game": _days_in_game(),
		"story_lines": _story_lines(3),
		"login_streak": int(PlayerDataManager.data.get("login_streak", 0)),
		"best_login_streak": int(PlayerDataManager.data.get("best_login_streak", 0)),
		"footer_date": footer_date_text(),
	}
	data["tagline"] = _Taglines.pick("overview", data)
	return data


static func _build_statistics() -> Dictionary:
	var grades: Dictionary = PlayerDataManager.data.get("grades", {})
	var points := _accuracy_trend_points(20)
	var deltas := _capsule_deltas()
	var acc_delta := _accuracy_delta_from_trend(points)
	var data := {
		"card_id": "statistics",
		"unique_tracks": PlayerDataManager.get_unique_levels_completed(),
		"total_score": int(PlayerDataManager.data.get("total_score_ever", 0)),
		"notes_hit": PlayerDataManager.get_total_notes_hit(),
		"notes_miss": PlayerDataManager.get_total_notes_missed(),
		"hit_rate": _hit_rate_percent(),
		"accuracy": _overall_accuracy_percent(),
		"max_combo": int(PlayerDataManager.data.get("max_combo_ever", 0)),
		"rr_earned": _rr_earned(),
		"medals_total": _medal_total(),
		"daily_quests": PlayerDataManager.get_daily_quests_completed_total(),
		"ss": int(grades.get("SS", 0)),
		"s": int(grades.get("S", 0)),
		"a": int(grades.get("A", 0)),
		"b": int(grades.get("B", 0)),
		"avg_difficulty": _avg_chart_difficulty(),
		"accuracy_points": points,
		"session_count": points.size(),
		"accuracy_delta_text": _format_delta(acc_delta, "%", 1),
		"tracks_delta_text": _format_delta(float(deltas.get("tracks_delta", 0)), "", 0),
		"rr_delta_text": _format_delta(float(deltas.get("rr_delta", 0)), "", 0),
		"footer_date": footer_date_text(),
	}
	data["tagline"] = _Taglines.pick("statistics", data)
	return data


static func _build_music() -> Dictionary:
	var counts := TrackStatsManager.genre_play_counts
	var top_genres := _top_genre_rows_with_mastery(5)
	var groups_unlocked := _GenreMastery.groups_at_least_level(counts, 1)
	var best_mastery_level := _GenreMastery.best_level_in_groups(counts)
	var new_discoveries: Array = []
	for row in top_genres:
		if str(row.get("trend", "")) == "new" and new_discoveries.size() < 4:
			new_discoveries.append(str(row.get("group_id", "")))
	var data := {
		"card_id": "music",
		"top_genres": top_genres,
		"mastery_leaders": _mastery_leaders(4),
		"groups_unlocked": groups_unlocked,
		"groups_total": _GenrePortrait.all_group_ids().size(),
		"best_mastery_level": best_mastery_level,
		"best_mastery_group_id": _best_mastery_group_id(),
		"favorite_group_id": _best_mastery_group_id(),
		"genres_discovered": _GenreMastery.total_discovered(counts),
		"catalog_total": _GenreMastery.total_catalog_size(),
		"full_groups_count": _GenreMastery.groups_with_full_discovery(counts),
		"new_discovery_ids": new_discoveries,
		"footer_date": footer_date_text(),
	}
	data["tagline"] = _Taglines.pick("music", data)
	return data


static func _build_records() -> Dictionary:
	var milestones := {}
	var extremes := {}
	var mod_records := {}
	var rr_top := _rr_top_rows(3)
	var best_rr_peak := 0
	var best_rr_track := ""
	if not rr_top.is_empty():
		var first: Dictionary = rr_top[0]
		best_rr_peak = int(first.get("best_rr", 0))
		best_rr_track = _track_line(first)
	if ProfileMilestonesManager:
		var ms_data := ProfileMilestonesManager.get_data()
		milestones = ms_data.get("milestones", {}) if ms_data.get("milestones") is Dictionary else {}
		extremes = ms_data.get("extremes", {}) if ms_data.get("extremes") is Dictionary else {}
		mod_records = ms_data.get("mod_records", {}) if ms_data.get("mod_records") is Dictionary else {}
	var extreme_accuracy_line := ""
	if extremes.has("highest_accuracy") and extremes["highest_accuracy"] is Dictionary:
		var acc_entry: Dictionary = extremes["highest_accuracy"]
		var acc_val := "%.2f%%" % float(acc_entry.get("value", 0.0))
		var acc_track := _track_line(acc_entry)
		if acc_track != "":
			extreme_accuracy_line = "%s — %s" % [acc_val, acc_track]
	var milestones_unlocked := _milestones_unlocked_count(milestones)
	var mod_record_count := 0
	if mod_records is Dictionary:
		if mod_records.get("max_mod_count") is Dictionary:
			mod_record_count += 1
		if mod_records.get("hardest_mod_combo") is Dictionary:
			mod_record_count += 1
	var most_replayed := _most_replayed_track()
	var hall := _hall_of_fame_rows(extremes, mod_records, most_replayed)
	var data := {
		"card_id": "records",
		"milestones": milestones,
		"extremes": extremes,
		"mod_records": mod_records,
		"rr_top": rr_top,
		"best_rr_peak": best_rr_peak,
		"best_rr_track": best_rr_track,
		"extreme_accuracy_line": extreme_accuracy_line,
		"milestones_unlocked": milestones_unlocked,
		"milestones_total": SHARE_MILESTONE_KEYS.size(),
		"mod_record_count": mod_record_count,
		"rr_spread": _rr_spread(rr_top),
		"shared_extreme_track": _shared_extreme_track(extremes),
		"mod_hard_bonus": _mod_hard_bonus(mod_records),
		"hall_rows": hall,
		"most_replayed": most_replayed,
		"footer_date": footer_date_text(),
	}
	data["tagline"] = _Taglines.pick("records", data)
	return data


static func _hall_of_fame_rows(
	extremes: Dictionary,
	mod_records: Dictionary,
	most_replayed: Dictionary
) -> Array:
	var rows: Array = []
	# Highest RR stays in the hero panel; hall lists the other legendary runs.
	if extremes.has("hardest_chart_cleared") and extremes["hardest_chart_cleared"] is Dictionary:
		var hard: Dictionary = extremes["hardest_chart_cleared"]
		var rating := float(hard.get("value", 0.0))
		if rating > 0.0:
			rows.append({
				"id": "hardest_chart",
				"caption_key": "PROFILE_SHARE_HALL_HARDEST",
				"value": "%.1f" % rating,
				"track": _track_line(hard),
			})
	if extremes.has("longest_fc") and extremes["longest_fc"] is Dictionary:
		var fc: Dictionary = extremes["longest_fc"]
		var combo := int(fc.get("value", 0))
		if combo > 0:
			rows.append({
				"id": "longest_fc",
				"caption_key": "PROFILE_SHARE_HALL_LONGEST_FC",
				"value": str(combo),
				"track": _track_line(fc),
			})
	if not most_replayed.is_empty():
		rows.append({
			"id": "most_replayed",
			"caption_key": "PROFILE_SHARE_HALL_MOST_REPLAYED",
			"value": TranslationServer.translate("PROFILE_SHARE_HALL_PLAYS_FMT") % int(most_replayed.get("plays", 0)),
			"track": str(most_replayed.get("track", "")),
		})
	# Hardest mod stack lives under «Рекорды модов» — keep Hall free of that duplicate.
	return rows


static func _build_play_modes() -> Dictionary:
	var marathon := _PlayModes.marathon_summary()
	var mod := _PlayModes.mod_summary()
	var mod_total := _PlayModes.MOD_STAT_SPECS.size()
	var mod_mastered := _PlayModes.mods_mastered_count()
	var marathon_entries := _PlayModes.marathon_record_entries()
	var mod_entries := _PlayModes.mod_clear_entries()

	var top_marathon: Array = []
	for i in range(mini(3, marathon_entries.size())):
		var entry: Dictionary = marathon_entries[i]
		var ratio := float(entry.get("best_ratio", 0.0))
		var ratio_text := "100%" if ratio >= 0.999 else "%.0f%%" % (ratio * 100.0)
		var tier := str(entry.get("best_badge_tier", ""))
		top_marathon.append({
			"title": str(entry.get("title", "")),
			"ratio_text": ratio_text,
			"badge_tier": tier,
			"badge_label": _PlayModes.badge_tier_label(tier) if tier != "" else "",
		})

	var mod_clears: Array = []
	for entry in mod_entries:
		if mod_clears.size() >= 5:
			break
		mod_clears.append({
			"mod_id": str(entry.get("mod_id", "")),
			"count": int(entry.get("count", 0)),
		})

	var routes_completed := int(marathon.get("routes_completed", 0))
	var routes_attempted := int(marathon.get("routes_attempted", 0))
	var clears_any := int(mod.get("clears_any", 0))
	var hero_value := routes_completed if routes_completed > 0 else clears_any
	var hero_kind := "marathon" if routes_completed > 0 else "mods"
	var endless := _endless_share_slice()
	var endless_story := ""
	var best_streak := int(endless.get("best_streak", 0))
	if best_streak > 0:
		endless_story = TranslationServer.translate("PROFILE_SHARE_STORY_ENDLESS") % best_streak
	var marathon_story := ""
	if not top_marathon.is_empty():
		var best_m: Dictionary = top_marathon[0]
		var badge := str(best_m.get("badge_label", "")).strip_edges()
		var title := str(best_m.get("title", "")).strip_edges()
		if title != "" and badge != "":
			marathon_story = TranslationServer.translate("PROFILE_SHARE_STORY_MARATHON") % [title, badge]
		elif title != "":
			marathon_story = title

	var data := {
		"card_id": "play_modes",
		"marathon": marathon,
		"mod": mod,
		"mod_total": mod_total,
		"mod_mastered": mod_mastered,
		"top_marathon": top_marathon,
		"mod_clears": mod_clears,
		"endless": endless,
		"hero_value": hero_value,
		"hero_kind": hero_kind,
		"routes_completed": routes_completed,
		"routes_attempted": routes_attempted,
		"endless_story": endless_story,
		"marathon_story": marathon_story,
		"footer_date": footer_date_text(),
	}
	data["tagline"] = _Taglines.pick("play_modes", data)
	return data


static func _endless_share_slice() -> Dictionary:
	if PlayerDataManager == null:
		return {}
	if not PlayerDataManager.is_play_mode_unlocked(PlayModeIds.ENDLESS):
		return {}
	if not PlayerDataManager.has_method("get_endless_stats"):
		return {}
	var stats: Dictionary = PlayerDataManager.get_endless_stats()
	return {
		"best_streak": PlayerDataManager.get_endless_best_streak(),
		"best_rr": int(stats.get("best_series_rr", 0)),
		"best_accuracy": float(stats.get("best_avg_accuracy", 0.0)),
		"total_runs": int(stats.get("total_runs", 0)),
	}
