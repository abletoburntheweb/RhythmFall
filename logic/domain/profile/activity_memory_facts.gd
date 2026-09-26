# logic/domain/profile/activity_memory_facts.gd
extends RefCounted
class_name ActivityMemoryFacts
## Calendar «year ago» (p6) + light day/month facts (p12). No separate progression.

const _ActivityCalendar = preload("res://logic/domain/profile/activity_calendar.gd")

## Day plaque: anniversary wins over a same-day fact. Never both.
## Month: up to this many narrative facts in Monthly Recap.
const MONTH_FACT_CAP := 4


static func pick_day_plaque(date_key: String, day: Dictionary) -> Dictionary:
	var anniversary := find_anniversary_for_date(date_key)
	if not anniversary.is_empty():
		return anniversary
	return pick_day_fact(day)


## Best first-play anniversary matching MM-DD of date_key (years_ago >= 1).
static func find_anniversary_for_date(date_key: String) -> Dictionary:
	if date_key.length() < 10 or TrackStatsManager == null:
		return {}
	var target_mmdd := date_key.substr(5, 5) # MM-DD
	var target_year := date_key.substr(0, 4).to_int()
	if target_year <= 0:
		return {}
	var best_years := 0
	var best_path := ""
	var best_title := ""
	var map: Dictionary = TrackStatsManager.first_played_at_per_track
	for path_v in map.keys():
		var iso := str(map[path_v]).strip_edges()
		if iso.length() < 10:
			continue
		if iso.substr(5, 5) != target_mmdd:
			continue
		var y := iso.substr(0, 4).to_int()
		if y <= 0 or y >= target_year:
			continue
		var years := target_year - y
		if years < 1:
			continue
		if years > best_years:
			best_years = years
			best_path = str(path_v)
			best_title = _track_title(best_path)
	if best_years < 1 or best_path == "":
		return {}
	return {
		"kind": "anniversary",
		"icon": "rewind.svg",
		"years": best_years,
		"path": best_path,
		"title": best_title,
	}


## Same-day fact when there is no anniversary. Skips empty / boring days.
static func pick_day_fact(day: Dictionary) -> Dictionary:
	var d := _ActivityCalendar.sanitize_day(day)
	if not _ActivityCalendar.day_was_played(d):
		return {}
	var tracks := int(d.get("tracks", 0))
	var clears := int(d.get("clears", 0))
	var fails := int(d.get("fails", 0))
	# Clean session: several clears, no fails (and not already the highlight story).
	if fails == 0 and clears >= 3:
		return {
			"kind": "fact",
			"fact_id": "clean_day",
			"icon": "circle-check.svg",
			"clears": clears,
		}
	if tracks >= 8:
		return {
			"kind": "fact",
			"fact_id": "busy_day",
			"icon": "zap.svg",
			"tracks": tracks,
		}
	# No combo_day fact — max combo is already a day stat row.
	return {}


## Up to MONTH_FACT_CAP narrative facts for Monthly Recap (priority order).
static func collect_month_facts(days: Dictionary, year: int, month: int, recap: Dictionary) -> Array:
	var out: Array = []
	if year <= 0 or month < 1 or month > 12:
		return out
	var prefix := "%04d-%02d-" % [year, month]

	var ann_count := count_anniversaries_in_month(year, month)
	if ann_count > 0:
		out.append({
			"kind": "fact",
			"fact_id": "month_anniversaries",
			"icon": "rewind.svg",
			"count": ann_count,
		})

	var kinds: Dictionary = recap.get("highlight_kinds", {}) if recap.get("highlight_kinds", {}) is Dictionary else {}
	if int(kinds.get("first_ss", 0)) > 0:
		out.append({
			"kind": "fact",
			"fact_id": "month_first_ss",
			"icon": "crown.svg",
			"count": int(kinds.get("first_ss", 0)),
		})
	if int(kinds.get("score_record", 0)) > 0:
		out.append({
			"kind": "fact",
			"fact_id": "month_score_records",
			"icon": "target.svg",
			"count": int(kinds.get("score_record", 0)),
		})

	var clean_days := 0
	var max_combo := 0
	for key in days.keys():
		var date_key := str(key)
		if not date_key.begins_with(prefix):
			continue
		var day := _ActivityCalendar.sanitize_day(days[key] if days[key] is Dictionary else {})
		if not _ActivityCalendar.day_was_played(day):
			continue
		if int(day.get("fails", 0)) == 0 and int(day.get("clears", 0)) >= 1:
			clean_days += 1
		max_combo = maxi(max_combo, int(day.get("max_combo", 0)))
	if clean_days >= 2:
		out.append({
			"kind": "fact",
			"fact_id": "month_clean_days",
			"icon": "circle-check.svg",
			"count": clean_days,
		})
	if max_combo >= 100:
		out.append({
			"kind": "fact",
			"fact_id": "month_max_combo",
			"icon": "flame.svg",
			"combo": max_combo,
		})

	var new_firsts := count_first_plays_in_month(year, month)
	if new_firsts >= 3:
		out.append({
			"kind": "fact",
			"fact_id": "month_new_tracks",
			"icon": "music.svg",
			"count": new_firsts,
		})

	if out.size() > MONTH_FACT_CAP:
		out.resize(MONTH_FACT_CAP)
	return out


static func count_anniversaries_in_month(year: int, month: int) -> int:
	if TrackStatsManager == null:
		return 0
	var count := 0
	var map: Dictionary = TrackStatsManager.first_played_at_per_track
	for path_v in map.keys():
		var iso := str(map[path_v]).strip_edges()
		if iso.length() < 10:
			continue
		var y := iso.substr(0, 4).to_int()
		var m := iso.substr(5, 2).to_int()
		var d := iso.substr(8, 2).to_int()
		if m != month or d < 1 or d > 31:
			continue
		if y >= year:
			continue
		# Anniversary day exists this month/year (ignore whether calendar has a play day).
		count += 1
	return count


static func count_first_plays_in_month(year: int, month: int) -> int:
	if TrackStatsManager == null:
		return 0
	var prefix := "%04d-%02d-" % [year, month]
	var count := 0
	var map: Dictionary = TrackStatsManager.first_played_at_per_track
	for path_v in map.keys():
		var iso := str(map[path_v]).strip_edges()
		if iso.begins_with(prefix):
			count += 1
	return count


static func _track_title(path: String) -> String:
	if path == "":
		return ""
	if SongLibrary and SongLibrary.has_method("get_metadata_for_song"):
		var meta = SongLibrary.get_metadata_for_song(path)
		if meta is Dictionary:
			var title := str(meta.get("title", "")).strip_edges()
			if title != "":
				return title
			var artist := str(meta.get("artist", "")).strip_edges()
			if artist != "" and artist.to_lower() != "unknown":
				return artist
	return path.get_file().get_basename()
