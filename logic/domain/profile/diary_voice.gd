# Personal notes for History feed + song museum (project_new §17).
# Tone: warm facts, not literature. Prefer data context over poetic lines.
# Phrase banks may use weighted rarity (stable per event.id).
extends RefCounted
class_name DiaryVoice

const _EventLog = preload("res://logic/domain/profile/profile_event_log.gd")


## Optional grey context line under feed subtitle. Empty = hide.
static func memory_line(ev: Dictionary) -> String:
	if ev.is_empty():
		return ""
	var kind := str(ev.get("kind", "")).strip_edges()
	match kind:
		_EventLog.KIND_GRADE_SS:
			return _note_grade_ss(ev)
		_EventLog.KIND_MILESTONE:
			return _note_milestone(ev)
		_EventLog.KIND_GENRE_GROUP_FIRST:
			return _note_genre_group_first(ev)
		_EventLog.KIND_GENRE_GROUP_SS_FIRST:
			return _note_genre_group_ss_first(ev)
		_EventLog.KIND_GENRE_MASTERY:
			return _note_genre_mastery(ev)
		_EventLog.KIND_RR_TOTAL:
			return _pick_weighted(ev, [
				["DIARY_NOTE_RR_TOTAL_CTX_01", 70],
				["DIARY_NOTE_RR_TOTAL_CTX_02", 30],
			])
		_EventLog.KIND_STREAK:
			return _note_streak(ev)
		_EventLog.KIND_LIBRARY_SIZE:
			return _note_library_size(ev)
		_EventLog.KIND_TRACK_ANNIVERSARY:
			return _note_track_anniversary(ev)
		_EventLog.KIND_ENDLESS_FIRST_CLEAR:
			return _note_endless_first(ev)
		_EventLog.KIND_MARATHON_FIRST_CLEAR:
			return _note_marathon_first(ev)
		_EventLog.KIND_INSTRUMENT_FIRST, _EventLog.KIND_MOD_FIRST, _EventLog.KIND_CHART_STYLE_FIRST:
			return _note_discovery_first(ev)
		_:
			return ""


const _LIVE_MIN_SAMPLES := 5
const _LIVE_PEAK_RATIO := 0.4
const _LIVE_DORMANT_DAYS := 30
const _LIVE_RETURN_SPAN_DAYS := 60
const _LIVE_STREAK_GAP_SEC := 2 * 3600
const _LIVE_STREAK_MIN_PAIRS := 3
const _LIVE_GROWTH_PB_MIN := 3
const _LIVE_SS_MIN := 5


## Stock library details insight (project_new §18). Empty = hide.
## Priority: TOD → season → dormant → streak/returns/PB/growth → hours/library/plays → soft (style/inst/mod/SS).
static func living_library_line(song_path: String) -> String:
	var path := str(song_path).replace("\\", "/").trim_suffix("/")
	if path == "":
		return ""
	return _compute_living_library_line(path)


static func invalidate_living_library_cache(_song_path: String = "") -> void:
	pass


static func _compute_living_library_line(path: String) -> String:
	var first_iso := ""
	var play_seconds := 0
	var play_count := 0
	var ss_count := 0
	if TrackStatsManager:
		first_iso = TrackStatsManager.get_first_played_at(path)
		play_seconds = TrackStatsManager.get_total_play_seconds(path)
		play_count = TrackStatsManager.get_completion_count(path)
		ss_count = TrackStatsManager.get_ss_count(path)

	var results: Array = []
	var svc := ResultsHistoryService.new()
	results = svc.load_results_for_song(path)
	if not results is Array:
		results = []
	if play_count <= 0:
		play_count = results.size()

	var last_iso := ""
	if not results.is_empty():
		var newest: Array = results.duplicate()
		newest.sort_custom(TimeUtils.sort_results_newest_first)
		if newest[0] is Dictionary:
			last_iso = str(newest[0].get("date", "")).strip_edges()
	if first_iso == "":
		first_iso = ResultsHistoryService.oldest_result_datetime(results)

	# --- Strong ---
	var peak := _peak_time_of_day_line(results, path)
	if peak != "":
		return peak

	var season := _peak_season_line(results, path)
	if season != "":
		return season

	var dormant_days := _days_since(last_iso)
	if dormant_days >= _LIVE_DORMANT_DAYS:
		return _pick_temp(path, "dormant", [
			"LIBRARY_INSIGHT_DORMANT_FMT",
			"LIBRARY_INSIGHT_DORMANT_FMT_02",
			"LIBRARY_INSIGHT_DORMANT_03",
		], [
			"LIBRARY_INSIGHT_DORMANT_WARM_01",
		], [
			"LIBRARY_INSIGHT_DORMANT_RARE_01",
			"LIBRARY_INSIGHT_DORMANT_RARE_02",
		], dormant_days)

	# --- Interesting (need history) ---
	var streak := _consecutive_returns_line(results, path)
	if streak != "":
		return streak

	var returns := _long_returns_line(first_iso, last_iso, play_count, path)
	if returns != "":
		return returns

	var pb_period := _pb_period_line(results, path)
	if pb_period != "":
		return pb_period

	var growth := _rr_growth_line(results, path)
	if growth != "":
		return growth

	var genre_fav := _genre_favorite_line(path, play_count)
	if genre_fav != "":
		return genre_fav

	# --- Strong fallbacks ---
	if play_seconds >= 3600:
		var hours := int(round(float(play_seconds) / 3600.0))
		if hours >= 1:
			return _pick_temp(path, "hours", [
				"LIBRARY_INSIGHT_HOURS_FMT",
				"LIBRARY_INSIGHT_HOURS_FMT_02",
				"LIBRARY_INSIGHT_HOURS_FMT_03",
				"LIBRARY_INSIGHT_HOURS_FMT_04",
				"LIBRARY_INSIGHT_HOURS_FMT_05",
				"LIBRARY_INSIGHT_HOURS_FMT_06",
			], [
				"LIBRARY_INSIGHT_HOURS_WARM_FMT",
			], [], hours)

	var days_in_lib := _days_since(first_iso)
	if days_in_lib >= 365:
		return _pick_temp(path, "year", [
			"LIBRARY_INSIGHT_YEAR_01",
			"LIBRARY_INSIGHT_YEAR_02",
			"LIBRARY_INSIGHT_YEAR_03",
		], [
			"LIBRARY_INSIGHT_YEAR_WARM_01",
			"LIBRARY_INSIGHT_YEAR_WARM_02",
			"LIBRARY_INSIGHT_YEAR_WARM_03",
		], [])
	if days_in_lib >= 14:
		return _pick_temp(path, "days", [
			"LIBRARY_INSIGHT_DAYS_FMT",
			"LIBRARY_INSIGHT_DAYS_FMT_02",
			"LIBRARY_INSIGHT_DAYS_FMT_03",
			"LIBRARY_INSIGHT_DAYS_FMT_04",
			"LIBRARY_INSIGHT_DAYS_05",
		], [
			"LIBRARY_INSIGHT_DAYS_WARM_01",
			"LIBRARY_INSIGHT_DAYS_WARM_02",
		], [], days_in_lib)

	if play_count >= 3:
		return _pick_temp(path, "plays", [
			"LIBRARY_INSIGHT_PLAYS_FMT",
			"LIBRARY_INSIGHT_PLAYS_FMT_02",
			"LIBRARY_INSIGHT_PLAYS_FMT_03",
			"LIBRARY_INSIGHT_PLAYS_FMT_04",
			"LIBRARY_INSIGHT_PLAYS_FMT_05",
			"LIBRARY_INSIGHT_PLAYS_FMT_06",
		], [
			"LIBRARY_INSIGHT_PLAYS_WARM_01",
			"LIBRARY_INSIGHT_PLAYS_WARM_FMT",
		], [], play_count)

	# --- Soft / careful ---
	var soft := _soft_preference_line(results, path)
	if soft != "":
		return soft

	if ss_count >= _LIVE_SS_MIN:
		return _pick_temp(path, "ss", [
			"LIBRARY_INSIGHT_SS_FMT",
			"LIBRARY_INSIGHT_SS_FMT_02",
		], [
			"LIBRARY_INSIGHT_SS_WARM_01",
			"LIBRARY_INSIGHT_SS_WARM_FMT",
			"LIBRARY_INSIGHT_SS_WARM_02",
		], [], ss_count)

	return ""


## Temperature pick: ~70% neutrals, ~25% warms, ~5% rares. Stable per path+salt.
static func _pick_temp(
	path: String,
	salt: String,
	neutrals: Array,
	warms: Array = [],
	rares: Array = [],
	arg: Variant = null
) -> String:
	var seed := absi(hash("%s|%s" % [path, salt]))
	var roll := seed % 100
	var pool: Array = neutrals
	if roll >= 95 and not rares.is_empty():
		pool = rares
	elif roll >= 70 and not warms.is_empty():
		pool = warms
	elif pool.is_empty():
		if not warms.is_empty():
			pool = warms
		elif not rares.is_empty():
			pool = rares
	if pool.is_empty():
		return ""
	var key := str(pool[int(seed / 100) % pool.size()])
	var text := TranslationServer.translate(key)
	if arg == null:
		return text
	# Apply format only when the translated string still has placeholders.
	if "%d" in text or "%s" in text:
		return text % arg
	return text


static func _peak_time_of_day_line(results: Array, path: String = "") -> String:
	var best_key := _peak_bucket_key(results, true)
	if best_key == "":
		return ""
	match best_key:
		"morning":
			return _pick_temp(path, "tod_morning", [
				"LIBRARY_INSIGHT_PEAK_MORNING",
				"LIBRARY_INSIGHT_PEAK_MORNING_02",
				"LIBRARY_INSIGHT_PEAK_MORNING_03",
				"LIBRARY_INSIGHT_PEAK_MORNING_04",
				"LIBRARY_INSIGHT_PEAK_MORNING_05",
			], [
				"LIBRARY_INSIGHT_PEAK_MORNING_WARM_01",
			], [])
		"day":
			return _pick_temp(path, "tod_day", [
				"LIBRARY_INSIGHT_PEAK_DAY",
				"LIBRARY_INSIGHT_PEAK_DAY_02",
				"LIBRARY_INSIGHT_PEAK_DAY_03",
				"LIBRARY_INSIGHT_PEAK_DAY_04",
				"LIBRARY_INSIGHT_PEAK_DAY_05",
			], [
				"LIBRARY_INSIGHT_PEAK_DAY_WARM_01",
			], [])
		"evening":
			return _pick_temp(path, "tod_evening", [
				"LIBRARY_INSIGHT_PEAK_EVENING",
				"LIBRARY_INSIGHT_PEAK_EVENING_02",
				"LIBRARY_INSIGHT_PEAK_EVENING_03",
				"LIBRARY_INSIGHT_PEAK_EVENING_04",
				"LIBRARY_INSIGHT_PEAK_EVENING_05",
				"LIBRARY_INSIGHT_PEAK_EVENING_06",
			], [
				"LIBRARY_INSIGHT_PEAK_EVENING_WARM_01",
			], [])
		"night":
			return _pick_temp(path, "tod_night", [
				"LIBRARY_INSIGHT_PEAK_NIGHT",
				"LIBRARY_INSIGHT_PEAK_NIGHT_02",
				"LIBRARY_INSIGHT_PEAK_NIGHT_03",
				"LIBRARY_INSIGHT_PEAK_NIGHT_04",
				"LIBRARY_INSIGHT_PEAK_NIGHT_05",
				"LIBRARY_INSIGHT_PEAK_NIGHT_06",
			], [
				"LIBRARY_INSIGHT_PEAK_NIGHT_WARM_01",
			], [])
		_:
			return ""


static func _peak_season_line(results: Array, path: String = "") -> String:
	var best_key := _peak_bucket_key(results, false)
	if best_key == "":
		return ""
	match best_key:
		"winter":
			return _pick_temp(path, "season_winter", [
				"LIBRARY_INSIGHT_SEASON_WINTER",
				"LIBRARY_INSIGHT_SEASON_WINTER_02",
				"LIBRARY_INSIGHT_SEASON_WINTER_03",
				"LIBRARY_INSIGHT_SEASON_WINTER_04",
				"LIBRARY_INSIGHT_SEASON_WINTER_05",
			], [
				"LIBRARY_INSIGHT_SEASON_WINTER_WARM_01",
				"LIBRARY_INSIGHT_SEASON_WINTER_WARM_02",
			], [])
		"spring":
			return _pick_temp(path, "season_spring", [
				"LIBRARY_INSIGHT_SEASON_SPRING",
				"LIBRARY_INSIGHT_SEASON_SPRING_02",
				"LIBRARY_INSIGHT_SEASON_SPRING_03",
				"LIBRARY_INSIGHT_SEASON_SPRING_04",
				"LIBRARY_INSIGHT_SEASON_SPRING_05",
			], [
				"LIBRARY_INSIGHT_SEASON_SPRING_WARM_01",
				"LIBRARY_INSIGHT_SEASON_SPRING_WARM_02",
			], [])
		"summer":
			return _pick_temp(path, "season_summer", [
				"LIBRARY_INSIGHT_SEASON_SUMMER",
				"LIBRARY_INSIGHT_SEASON_SUMMER_02",
				"LIBRARY_INSIGHT_SEASON_SUMMER_03",
				"LIBRARY_INSIGHT_SEASON_SUMMER_04",
				"LIBRARY_INSIGHT_SEASON_SUMMER_05",
			], [
				"LIBRARY_INSIGHT_SEASON_SUMMER_WARM_01",
				"LIBRARY_INSIGHT_SEASON_SUMMER_WARM_02",
			], [])
		"autumn":
			return _pick_temp(path, "season_autumn", [
				"LIBRARY_INSIGHT_SEASON_AUTUMN",
				"LIBRARY_INSIGHT_SEASON_AUTUMN_02",
				"LIBRARY_INSIGHT_SEASON_AUTUMN_03",
				"LIBRARY_INSIGHT_SEASON_AUTUMN_04",
				"LIBRARY_INSIGHT_SEASON_AUTUMN_05",
				"LIBRARY_INSIGHT_SEASON_AUTUMN_06",
			], [
				"LIBRARY_INSIGHT_SEASON_AUTUMN_WARM_01",
				"LIBRARY_INSIGHT_SEASON_AUTUMN_WARM_02",
			], [])
		_:
			return ""


static func _peak_bucket_key(results: Array, by_hour: bool) -> String:
	if results.size() < _LIVE_MIN_SAMPLES:
		return ""
	var buckets: Dictionary
	if by_hour:
		buckets = {"morning": 0, "day": 0, "evening": 0, "night": 0}
	else:
		buckets = {"winter": 0, "spring": 0, "summer": 0, "autumn": 0}
	var total := 0
	for item in results:
		if not item is Dictionary:
			continue
		if by_hour:
			var hour := _hour_from_iso(str(item.get("date", "")))
			if hour < 0:
				continue
			total += 1
			if hour >= 5 and hour < 11:
				buckets["morning"] += 1
			elif hour >= 11 and hour < 17:
				buckets["day"] += 1
			elif hour >= 17 and hour < 22:
				buckets["evening"] += 1
			else:
				buckets["night"] += 1
		else:
			var month := _month_from_iso(str(item.get("date", "")))
			if month < 1:
				continue
			total += 1
			if month == 12 or month <= 2:
				buckets["winter"] += 1
			elif month <= 5:
				buckets["spring"] += 1
			elif month <= 8:
				buckets["summer"] += 1
			else:
				buckets["autumn"] += 1
	if total < _LIVE_MIN_SAMPLES:
		return ""
	var best_key := ""
	var best_n := 0
	for key in buckets.keys():
		var n := int(buckets[key])
		if n > best_n:
			best_n = n
			best_key = str(key)
	if best_key == "" or float(best_n) / float(total) < _LIVE_PEAK_RATIO:
		return ""
	return best_key


static func _consecutive_returns_line(results: Array, path: String) -> String:
	if results.size() < _LIVE_MIN_SAMPLES:
		return ""
	var chron: Array = results.duplicate()
	chron.sort_custom(func(a, b) -> bool:
		return TimeUtils.result_datetime_sort_key(str(a.get("date", ""))) \
			< TimeUtils.result_datetime_sort_key(str(b.get("date", "")))
	)
	var pairs := 0
	var prev_unix := -1
	for item in chron:
		if not item is Dictionary:
			continue
		var iso := str(item.get("date", "")).strip_edges()
		var u := _unix_from_result_iso(iso)
		if u < 0:
			continue
		if prev_unix >= 0 and u - prev_unix > 0 and u - prev_unix <= _LIVE_STREAK_GAP_SEC:
			pairs += 1
		prev_unix = u
	if pairs < _LIVE_STREAK_MIN_PAIRS:
		return ""
	return _pick_temp(path, "streak", [
		"LIBRARY_INSIGHT_STREAK_01",
		"LIBRARY_INSIGHT_STREAK_02",
		"LIBRARY_INSIGHT_STREAK_03",
		"LIBRARY_INSIGHT_STREAK_04",
	], [
		"LIBRARY_INSIGHT_STREAK_WARM_01",
	], [])


static func _unix_from_result_iso(iso: String) -> int:
	var s := iso.strip_edges()
	if s == "":
		return -1
	return TimeUtils.unix_from_any_datetime(s)


static func _long_returns_line(first_iso: String, last_iso: String, play_count: int, path: String) -> String:
	if play_count < 4:
		return ""
	var span := _days_between(first_iso, last_iso)
	if span < _LIVE_RETURN_SPAN_DAYS:
		return ""
	return _pick_temp(path, "returns", [
		"LIBRARY_INSIGHT_RETURNS_01",
		"LIBRARY_INSIGHT_RETURNS_02",
		"LIBRARY_INSIGHT_RETURNS_03",
	], [
		"LIBRARY_INSIGHT_RETURNS_WARM_01",
		"LIBRARY_INSIGHT_RETURNS_WARM_02",
	], [])


static func _days_between(earlier_iso: String, later_iso: String) -> int:
	var a := _days_since(later_iso)
	var b := _days_since(earlier_iso)
	if a < 0 or b < 0:
		return -1
	# days_since is "now - iso"; span ≈ b - a
	return maxi(0, b - a)


static func _pb_period_line(results: Array, path: String) -> String:
	if results.size() < _LIVE_MIN_SAMPLES:
		return ""
	var top: Array = []
	for item in results:
		if item is Dictionary:
			top.append(item)
	if top.size() < 3:
		return ""
	top.sort_custom(func(a, b) -> bool:
		var rr_a := int(a.get("run_rr", 0))
		var rr_b := int(b.get("run_rr", 0))
		if rr_a != rr_b:
			return rr_a > rr_b
		return float(a.get("accuracy", 0.0)) > float(b.get("accuracy", 0.0))
	)
	var elite: Array = []
	for i in mini(5, top.size()):
		elite.append(top[i])
	var season_key := _peak_bucket_key(elite, false)
	if season_key != "":
		match season_key:
			"winter":
				return _pick_temp(path, "pb_winter", [
					"LIBRARY_INSIGHT_PB_SEASON_WINTER",
					"LIBRARY_INSIGHT_PB_SEASON_WINTER_02",
					"LIBRARY_INSIGHT_PB_GENERIC_01",
					"LIBRARY_INSIGHT_PB_GENERIC_02",
					"LIBRARY_INSIGHT_PB_GENERIC_03",
				], [
					"LIBRARY_INSIGHT_PB_WARM_01",
					"LIBRARY_INSIGHT_PB_WARM_02",
				], [
					"LIBRARY_INSIGHT_PB_RARE_01",
				])
			"spring":
				return _pick_temp(path, "pb_spring", [
					"LIBRARY_INSIGHT_PB_SEASON_SPRING",
					"LIBRARY_INSIGHT_PB_SEASON_SPRING_02",
					"LIBRARY_INSIGHT_PB_GENERIC_01",
					"LIBRARY_INSIGHT_PB_GENERIC_02",
					"LIBRARY_INSIGHT_PB_GENERIC_03",
				], [
					"LIBRARY_INSIGHT_PB_WARM_01",
					"LIBRARY_INSIGHT_PB_WARM_02",
				], [
					"LIBRARY_INSIGHT_PB_RARE_01",
				])
			"summer":
				return _pick_temp(path, "pb_summer", [
					"LIBRARY_INSIGHT_PB_SEASON_SUMMER",
					"LIBRARY_INSIGHT_PB_SEASON_SUMMER_02",
					"LIBRARY_INSIGHT_PB_GENERIC_01",
					"LIBRARY_INSIGHT_PB_GENERIC_02",
					"LIBRARY_INSIGHT_PB_GENERIC_03",
				], [
					"LIBRARY_INSIGHT_PB_WARM_01",
					"LIBRARY_INSIGHT_PB_WARM_02",
				], [
					"LIBRARY_INSIGHT_PB_RARE_01",
				])
			"autumn":
				return _pick_temp(path, "pb_autumn", [
					"LIBRARY_INSIGHT_PB_SEASON_AUTUMN",
					"LIBRARY_INSIGHT_PB_SEASON_AUTUMN_02",
					"LIBRARY_INSIGHT_PB_GENERIC_01",
					"LIBRARY_INSIGHT_PB_GENERIC_02",
					"LIBRARY_INSIGHT_PB_GENERIC_03",
				], [
					"LIBRARY_INSIGHT_PB_WARM_01",
					"LIBRARY_INSIGHT_PB_WARM_02",
				], [
					"LIBRARY_INSIGHT_PB_RARE_01",
				])
	var tod_key := _peak_bucket_key(elite, true)
	if tod_key != "":
		match tod_key:
			"morning":
				return _pick_temp(path, "pb_tod_morning", [
					"LIBRARY_INSIGHT_PB_TOD_MORNING",
					"LIBRARY_INSIGHT_PB_TOD_MORNING_02",
					"LIBRARY_INSIGHT_PB_GENERIC_01",
					"LIBRARY_INSIGHT_PB_GENERIC_02",
					"LIBRARY_INSIGHT_PB_GENERIC_03",
				], [
					"LIBRARY_INSIGHT_PB_WARM_01",
					"LIBRARY_INSIGHT_PB_WARM_02",
				], [
					"LIBRARY_INSIGHT_PB_RARE_01",
				])
			"day":
				return _pick_temp(path, "pb_tod_day", [
					"LIBRARY_INSIGHT_PB_TOD_DAY",
					"LIBRARY_INSIGHT_PB_TOD_DAY_02",
					"LIBRARY_INSIGHT_PB_GENERIC_01",
					"LIBRARY_INSIGHT_PB_GENERIC_02",
					"LIBRARY_INSIGHT_PB_GENERIC_03",
				], [
					"LIBRARY_INSIGHT_PB_WARM_01",
					"LIBRARY_INSIGHT_PB_WARM_02",
				], [
					"LIBRARY_INSIGHT_PB_RARE_01",
				])
			"evening":
				return _pick_temp(path, "pb_tod_evening", [
					"LIBRARY_INSIGHT_PB_TOD_EVENING",
					"LIBRARY_INSIGHT_PB_TOD_EVENING_02",
					"LIBRARY_INSIGHT_PB_GENERIC_01",
					"LIBRARY_INSIGHT_PB_GENERIC_02",
					"LIBRARY_INSIGHT_PB_GENERIC_03",
				], [
					"LIBRARY_INSIGHT_PB_WARM_01",
					"LIBRARY_INSIGHT_PB_WARM_02",
				], [
					"LIBRARY_INSIGHT_PB_RARE_01",
				])
			"night":
				return _pick_temp(path, "pb_tod_night", [
					"LIBRARY_INSIGHT_PB_TOD_NIGHT",
					"LIBRARY_INSIGHT_PB_TOD_NIGHT_02",
					"LIBRARY_INSIGHT_PB_GENERIC_01",
					"LIBRARY_INSIGHT_PB_GENERIC_02",
					"LIBRARY_INSIGHT_PB_GENERIC_03",
				], [
					"LIBRARY_INSIGHT_PB_WARM_01",
					"LIBRARY_INSIGHT_PB_WARM_02",
				], [
					"LIBRARY_INSIGHT_PB_RARE_01",
				])
	return ""


static func _rr_growth_line(results: Array, path: String) -> String:
	if results.size() < _LIVE_MIN_SAMPLES:
		return ""
	var chron: Array = results.duplicate()
	chron.sort_custom(func(a, b) -> bool:
		return TimeUtils.result_datetime_sort_key(str(a.get("date", ""))) \
			< TimeUtils.result_datetime_sort_key(str(b.get("date", "")))
	)
	var best_rr := 0
	var improvements := 0
	for item in chron:
		if not item is Dictionary:
			continue
		var rr := int(item.get("run_rr", 0))
		if rr <= 0:
			continue
		if rr > best_rr:
			if best_rr > 0:
				improvements += 1
			best_rr = rr
	if improvements < _LIVE_GROWTH_PB_MIN:
		return ""
	return _pick_temp(path, "growth", [
		"LIBRARY_INSIGHT_GROWTH_01",
		"LIBRARY_INSIGHT_GROWTH_02",
		"LIBRARY_INSIGHT_GROWTH_03",
		"LIBRARY_INSIGHT_GROWTH_04",
		"LIBRARY_INSIGHT_PB_GENERIC_01",
		"LIBRARY_INSIGHT_PB_GENERIC_02",
		"LIBRARY_INSIGHT_PB_GENERIC_03",
	], [
		"LIBRARY_INSIGHT_GROWTH_WARM_01",
		"LIBRARY_INSIGHT_PB_WARM_01",
		"LIBRARY_INSIGHT_PB_WARM_02",
	], [
		"LIBRARY_INSIGHT_PB_RARE_01",
	])


static func _genre_favorite_line(path: String, play_count: int) -> String:
	if play_count < 5 or TrackStatsManager == null or SongLibrary == null:
		return ""
	var meta: Dictionary = SongLibrary.get_metadata_for_song(path) if SongLibrary.has_method("get_metadata_for_song") else {}
	var genre := str(meta.get("primary_genre", "")).strip_edges().to_lower()
	if genre == "" or genre == "unknown":
		return ""
	var counts: Dictionary = TrackStatsManager.track_completion_counts
	var best_path := path
	var best_n := play_count
	var peers := 0
	for other_path in counts.keys():
		var op := str(other_path).replace("\\", "/").trim_suffix("/")
		var om: Dictionary = SongLibrary.get_metadata_for_song(op) if SongLibrary.has_method("get_metadata_for_song") else {}
		var og := str(om.get("primary_genre", "")).strip_edges().to_lower()
		if og != genre:
			continue
		peers += 1
		var n := int(counts[other_path])
		if n > best_n:
			best_n = n
			best_path = op
	if peers < 3:
		return ""
	if best_path != path:
		return ""
	var label := genre
	if SongLibrary.has_method("display_genre_label"):
		label = str(SongLibrary.display_genre_label(genre))
	else:
		label = genre.capitalize()
	return _pick_temp(path, "genre_fav", [
		"LIBRARY_INSIGHT_GENRE_FAV_FMT",
		"LIBRARY_INSIGHT_GENRE_FAV_FMT_02",
		"LIBRARY_INSIGHT_GENRE_FAV_FMT_03",
		"LIBRARY_INSIGHT_GENRE_FAV_04",
		"LIBRARY_INSIGHT_GENRE_FAV_FMT_05",
	], [], [], label)


static func _soft_preference_line(results: Array, path: String) -> String:
	if results.size() < _LIVE_MIN_SAMPLES:
		return ""
	var inst_counts: Dictionary = {}
	var mode_counts: Dictionary = {}
	var lane_counts: Dictionary = {}
	var mod_counts: Dictionary = {}
	var total := 0
	for item in results:
		if not item is Dictionary:
			continue
		total += 1
		var inst := str(item.get("instrument", "")).strip_edges()
		if inst != "":
			inst_counts[inst] = int(inst_counts.get(inst, 0)) + 1
		var mode := str(item.get("mode", "")).strip_edges()
		if mode != "":
			mode_counts[mode] = int(mode_counts.get(mode, 0)) + 1
		var lanes := int(item.get("lanes", 0))
		if lanes > 0:
			lane_counts[lanes] = int(lane_counts.get(lanes, 0)) + 1
		var mods: Variant = item.get("modifiers", [])
		if mods is Array and not mods.is_empty():
			var mid := str(mods[0]).strip_edges()
			if mid != "":
				mod_counts[mid] = int(mod_counts.get(mid, 0)) + 1
	if total < _LIVE_MIN_SAMPLES:
		return ""

	var pick := absi(path.hash()) % 4
	match pick:
		0:
			var mode_id := str(_majority_key(mode_counts, total))
			if mode_id != "":
				return _pick_temp(path, "soft_style", [
					"LIBRARY_INSIGHT_STYLE_FMT",
					"LIBRARY_INSIGHT_STYLE_FMT_02",
					"LIBRARY_INSIGHT_STYLE_FMT_03",
					"LIBRARY_INSIGHT_STYLE_FMT_04",
					"LIBRARY_INSIGHT_STYLE_FMT_05",
				], [], [], _style_label(mode_id))
		1:
			var inst_id := str(_majority_key(inst_counts, total))
			if inst_id != "":
				return _pick_temp(path, "soft_inst", [
					"LIBRARY_INSIGHT_INST_FMT",
					"LIBRARY_INSIGHT_INST_FMT_02",
					"LIBRARY_INSIGHT_INST_FMT_03",
					"LIBRARY_INSIGHT_INST_FMT_04",
					"LIBRARY_INSIGHT_INST_FMT_05",
					"LIBRARY_INSIGHT_INST_FMT_06",
				], [], [], _instrument_label(inst_id))
		2:
			var lane_raw: Variant = _majority_key(lane_counts, total)
			if str(lane_raw) != "":
				return _pick_temp(path, "soft_lanes", [
					"LIBRARY_INSIGHT_LANES_FMT",
					"LIBRARY_INSIGHT_LANES_FMT_02",
					"LIBRARY_INSIGHT_LANES_FMT_03",
					"LIBRARY_INSIGHT_LANES_FMT_04",
					"LIBRARY_INSIGHT_LANES_FMT_05",
				], [], [], int(lane_raw))
		_:
			var mod_id := str(_majority_key(mod_counts, total))
			if mod_id != "":
				return _pick_temp(path, "soft_mod", [
					"LIBRARY_INSIGHT_MOD_FMT",
					"LIBRARY_INSIGHT_MOD_FMT_02",
					"LIBRARY_INSIGHT_MOD_FMT_03",
					"LIBRARY_INSIGHT_MOD_FMT_04",
					"LIBRARY_INSIGHT_MOD_FMT_05",
				], [], [], _mod_label(mod_id))
	return ""


static func _majority_key(counts: Dictionary, total: int) -> Variant:
	var best_k: Variant = null
	var best_n := 0
	for k in counts.keys():
		var n := int(counts[k])
		if n > best_n:
			best_n = n
			best_k = k
	if best_k == null or float(best_n) / float(total) < _LIVE_PEAK_RATIO:
		return ""
	return best_k


static func _style_label(mode_id: String) -> String:
	var m := mode_id.strip_edges().to_lower()
	if m.begins_with("arcade"):
		return TranslationServer.translate("GEN_GOAL_ARCADE")
	if m.begins_with("original") or m == "basic" or m == "":
		return TranslationServer.translate("GEN_GOAL_ORIGINAL")
	var key := "GEN_GOAL_%s" % m.to_upper()
	var t := TranslationServer.translate(key)
	return t if t != key else mode_id.capitalize()


static func _instrument_label(inst_id: String) -> String:
	var key := "GEN_INST_%s" % inst_id.to_upper()
	var t := TranslationServer.translate(key)
	return t if t != key else inst_id.capitalize()


static func _mod_label(mod_id: String) -> String:
	var key := "MOD_%s" % mod_id.to_upper()
	var t := TranslationServer.translate(key)
	if t != key:
		return t
	key = "RUN_MOD_%s" % mod_id.to_upper()
	t = TranslationServer.translate(key)
	return t if t != key else mod_id.capitalize()


static func _hour_from_iso(iso: String) -> int:
	var s := iso.strip_edges()
	if s.length() < 13:
		return -1
	# YYYY-MM-DDTHH or YYYY-MM-DD HH
	var time_part := ""
	if "T" in s:
		time_part = s.get_slice("T", 1)
	elif " " in s:
		time_part = s.get_slice(" ", 1)
	else:
		return -1
	if time_part.length() < 2 or not time_part.substr(0, 2).is_valid_int():
		return -1
	return clampi(int(time_part.substr(0, 2)), 0, 23)


static func _month_from_iso(iso: String) -> int:
	var s := iso.strip_edges()
	if s.length() < 7:
		return -1
	var parts := s.substr(0, 10).split("-")
	if parts.size() < 2:
		return -1
	var m := int(parts[1])
	return m if m >= 1 and m <= 12 else -1


## One relationship line for song museum passport. Empty = hide.
static func museum_line(passport: Dictionary) -> String:
	if passport.is_empty():
		return ""
	var play_seconds := int(passport.get("play_seconds", 0))
	var play_count := int(passport.get("play_count", 0))
	var first_iso := str(passport.get("first_played", "")).strip_edges()
	var last_iso := str(passport.get("last_played", "")).strip_edges()

	# Prefer dormant if last play was long ago.
	var dormant_days := _days_since(last_iso)
	if dormant_days >= 30:
		return TranslationServer.translate("DIARY_NOTE_MUSEUM_DORMANT_FMT") % dormant_days

	if play_seconds >= 3600:
		var hours := int(round(float(play_seconds) / 3600.0))
		if hours >= 1:
			return TranslationServer.translate("DIARY_NOTE_MUSEUM_HOURS_FMT") % hours

	var days_in_lib := _days_since(first_iso)
	if days_in_lib >= 14:
		return TranslationServer.translate("DIARY_NOTE_MUSEUM_DAYS_FMT") % days_in_lib

	if play_count >= 10:
		return TranslationServer.translate("DIARY_NOTE_MUSEUM_PLAYS_FMT") % play_count

	return ""


static func _note_grade_ss(ev: Dictionary) -> String:
	var path := str(ev.get("song_path", "")).strip_edges()
	if path == "" or TrackStatsManager == null:
		return _pick_weighted(ev, [
			["DIARY_NOTE_SS_CTX_01", 70],
			["DIARY_NOTE_SS_CTX_02", 30],
		])
	var ss_n := TrackStatsManager.get_ss_count(path)
	var plays := TrackStatsManager.get_completion_count(path)
	if ss_n <= 1 and plays >= 2:
		return TranslationServer.translate("DIARY_NOTE_SS_AFTER_PLAYS_FMT") % plays
	if ss_n <= 1:
		return TranslationServer.translate("DIARY_NOTE_SS_FIRST_ON_TRACK")
	if plays >= 5:
		return TranslationServer.translate("DIARY_NOTE_SS_PLAYS_FMT") % plays
	return _pick_weighted(ev, [
		["DIARY_NOTE_SS_CTX_01", 70],
		["DIARY_NOTE_SS_CTX_02", 30],
	])


static func _note_milestone(ev: Dictionary) -> String:
	var key := _EventLog.milestone_raw_key(ev)
	match key:
		"first_ss":
			return _pick_weighted(ev, [
				["DIARY_NOTE_MS_FIRST_SS_01", 55],
				["DIARY_NOTE_MS_FIRST_SS_02", 30],
				["DIARY_NOTE_MS_FIRST_SS_03", 15],
			])
		"first_fc":
			return _pick_weighted(ev, [
				["DIARY_NOTE_MS_FIRST_FC_01", 55],
				["DIARY_NOTE_MS_FIRST_FC_02", 30],
				["DIARY_NOTE_MS_FIRST_FC_03", 15],
			])
		"first_track_played":
			return _pick_weighted(ev, [
				["DIARY_NOTE_MS_FIRST_TRACK_01", 50],
				["DIARY_NOTE_MS_FIRST_TRACK_02", 30],
				["DIARY_NOTE_MS_FIRST_TRACK_03", 20],
			])
		"first_mod_clear":
			return _pick_weighted(ev, [
				["DIARY_NOTE_MS_FIRST_MOD_01", 70],
				["DIARY_NOTE_MS_FIRST_MOD_02", 30],
			])
		"endless_unlocked", "marathon_unlocked":
			return _note_mode_unlock(ev)
		_:
			return ""


static func _note_mode_unlock(ev: Dictionary) -> String:
	return _pick_weighted(ev, [
		["DIARY_NOTE_MODE_UNLOCK_01", 35],
		["DIARY_NOTE_MODE_UNLOCK_02", 25],
		["DIARY_NOTE_MODE_UNLOCK_03", 20],
		["DIARY_NOTE_MODE_UNLOCK_04", 15],
		["DIARY_NOTE_MODE_UNLOCK_05", 5],
	])


static func _note_genre_group_first(ev: Dictionary) -> String:
	var label := _group_label(str(ev.get("title_arg", "")))
	if label == "":
		return TranslationServer.translate("DIARY_NOTE_GENRE_FIRST_CTX_01")
	var key := _pick_weighted_key(ev, [
		["DIARY_NOTE_GENRE_FIRST_FMT_01", 70],
		["DIARY_NOTE_GENRE_FIRST_FMT_02", 30],
	])
	return TranslationServer.translate(key) % label


static func _note_genre_group_ss_first(ev: Dictionary) -> String:
	var label := _group_label(str(ev.get("title_arg", "")))
	if label == "":
		return TranslationServer.translate("DIARY_NOTE_GENRE_SS_FIRST_CTX")
	var key := _pick_weighted_key(ev, [
		["DIARY_NOTE_GENRE_SS_FIRST_FMT_01", 70],
		["DIARY_NOTE_GENRE_SS_FIRST_FMT_02", 25],
		["DIARY_NOTE_GENRE_SS_FIRST_FMT_03", 5],
	])
	return TranslationServer.translate(key) % label


static func _note_genre_mastery(ev: Dictionary) -> String:
	var label := _group_label(str(ev.get("title_arg", "")))
	if label == "":
		return ""
	var key := _pick_weighted_key(ev, [
		["DIARY_NOTE_MASTERY_CTX_01", 70],
		["DIARY_NOTE_MASTERY_CTX_02", 30],
	])
	return TranslationServer.translate(key) % label


static func _note_library_size(ev: Dictionary) -> String:
	var n := int(str(ev.get("title_arg", "0")))
	if n <= 0:
		return ""
	var key := _pick_weighted_key(ev, [
		["DIARY_NOTE_LIBRARY_FMT_05", 40],
		["DIARY_NOTE_LIBRARY_FMT_01", 25],
		["DIARY_NOTE_LIBRARY_FMT_02", 20],
		["DIARY_NOTE_LIBRARY_03", 10],
		["DIARY_NOTE_LIBRARY_04", 5],
	])
	if key == "DIARY_NOTE_LIBRARY_03" or key == "DIARY_NOTE_LIBRARY_04":
		return TranslationServer.translate(key)
	return TranslationServer.translate(key) % n


static func _note_track_anniversary(ev: Dictionary) -> String:
	var years := int(str(ev.get("title_arg", "1")))
	if years >= 2:
		return _pick_weighted(ev, [
			["DIARY_NOTE_ANNIV_05", 55],
			["DIARY_NOTE_ANNIV_02", 25],
			["DIARY_NOTE_ANNIV_04", 15],
			["DIARY_NOTE_ANNIV_03", 5],
		])
	return _pick_weighted(ev, [
		["DIARY_NOTE_ANNIV_01", 55],
		["DIARY_NOTE_ANNIV_02", 20],
		["DIARY_NOTE_ANNIV_03", 12],
		["DIARY_NOTE_ANNIV_04", 10],
		["DIARY_NOTE_ANNIV_05", 3],
	])


static func _note_endless_first(ev: Dictionary) -> String:
	return _pick_weighted(ev, [
		["DIARY_NOTE_ENDLESS_FIRST_01", 40],
		["DIARY_NOTE_ENDLESS_FIRST_04", 25],
		["DIARY_NOTE_ENDLESS_FIRST_05", 20],
		["DIARY_NOTE_ENDLESS_FIRST_02", 10],
		["DIARY_NOTE_ENDLESS_FIRST_03", 5],
	])


static func _note_marathon_first(ev: Dictionary) -> String:
	return _pick_weighted(ev, [
		["DIARY_NOTE_MARATHON_FIRST_01", 35],
		["DIARY_NOTE_MARATHON_FIRST_02", 25],
		["DIARY_NOTE_MARATHON_FIRST_04", 20],
		["DIARY_NOTE_MARATHON_FIRST_03", 15],
		["DIARY_NOTE_MARATHON_FIRST_05", 5],
	])


static func _note_streak(ev: Dictionary) -> String:
	var days := int(str(ev.get("title_arg", "0")))
	if days <= 0:
		return ""
	if days >= 365:
		return TranslationServer.translate("DIARY_NOTE_STREAK_YEAR")
	if days >= 180:
		return TranslationServer.translate("DIARY_NOTE_STREAK_HALF_YEAR")
	if days >= 30:
		return TranslationServer.translate("DIARY_NOTE_STREAK_MONTH")
	if days >= 7:
		return _pick_weighted(ev, [
			["DIARY_NOTE_STREAK_WEEK", 70],
			["DIARY_NOTE_STREAK_WEEK_02", 30],
		])
	return TranslationServer.translate("DIARY_NOTE_STREAK_CTX")


static func _note_discovery_first(ev: Dictionary) -> String:
	var kind := str(ev.get("kind", ""))
	match kind:
		_EventLog.KIND_INSTRUMENT_FIRST:
			return TranslationServer.translate("DIARY_NOTE_INSTRUMENT_FIRST_CTX")
		_EventLog.KIND_MOD_FIRST:
			return TranslationServer.translate("DIARY_NOTE_MOD_FIRST_CTX")
		_EventLog.KIND_CHART_STYLE_FIRST:
			return TranslationServer.translate("DIARY_NOTE_STYLE_FIRST_CTX")
		_:
			return ""


static func _group_label(title_arg: String) -> String:
	var a := title_arg.strip_edges()
	if a == "":
		return ""
	var tr := TranslationServer.translate(a)
	return tr if tr != "" else a


## weighted: Array of [translation_key, weight]. Stable per event.id.
static func _pick_weighted(ev: Dictionary, weighted: Array) -> String:
	var key := _pick_weighted_key(ev, weighted)
	if key == "":
		return ""
	return TranslationServer.translate(key)


static func _pick_weighted_key(ev: Dictionary, weighted: Array) -> String:
	if weighted.is_empty():
		return ""
	var total := 0
	for item in weighted:
		if item is Array and item.size() >= 2:
			total += maxi(0, int(item[1]))
	if total <= 0:
		return str(weighted[0][0]) if weighted[0] is Array else ""
	var roll := _index(ev, total)
	var acc := 0
	for item in weighted:
		if not item is Array or item.size() < 2:
			continue
		acc += maxi(0, int(item[1]))
		if roll < acc:
			return str(item[0])
	var last: Variant = weighted[weighted.size() - 1]
	return str(last[0]) if last is Array else ""


static func _pick(ev: Dictionary, keys: Array) -> String:
	if keys.is_empty():
		return ""
	var key := str(keys[_index(ev, keys.size())])
	return TranslationServer.translate(key)


static func _index(ev: Dictionary, modulo: int) -> int:
	if modulo <= 1:
		return 0
	var id := str(ev.get("id", ev.get("ts", "")))
	var h := 0
	for i in id.length():
		h = (h * 31 + id.unicode_at(i)) & 0x7fffffff
	return h % modulo


static func _days_since(iso: String) -> int:
	var s := iso.strip_edges()
	if s.length() < 10:
		return -1
	var day := s.substr(0, 10)
	var parts := day.split("-")
	if parts.size() < 3:
		return -1
	var y := int(parts[0])
	var m := int(parts[1])
	var d := int(parts[2])
	if y < 1970 or m < 1 or d < 1:
		return -1
	var then_unix := Time.get_unix_time_from_datetime_dict({"year": y, "month": m, "day": d, "hour": 12})
	var now := Time.get_datetime_dict_from_system(false)
	var now_unix := Time.get_unix_time_from_datetime_dict({
		"year": int(now.get("year", 1970)),
		"month": int(now.get("month", 1)),
		"day": int(now.get("day", 1)),
		"hour": 12,
	})
	return int(floor(float(now_unix - then_unix) / 86400.0))
