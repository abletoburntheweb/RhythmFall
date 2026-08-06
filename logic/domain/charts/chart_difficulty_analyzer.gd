# logic/domain/charts/chart_difficulty_analyzer.gd
extends RefCounted
class_name ChartDifficultyAnalyzer

const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")

const MAX_RATING: int = 10
const ICON_PATH: String = "res://assets/icons/chart_difficulty.svg"
const CANONICAL_STATS_LANES: int = 4
const _SIMULTANEOUS_WINDOW_SEC: float = 0.05
## Below this avg n/s the chart is treated as sparse/broken; rating follows note_count/duration.
const SPARSE_DENSITY_NPS: float = 0.15
const SPARSE_SCORE_SCALE: float = 10.0

## One chart-difficulty entry per instrument + generation mode (lane count does not change the chart).
static func variant_key(instrument: String, mode: String) -> String:
	return "%s_%s" % [instrument, mode.to_lower()]


static func legacy_variant_key_base(key: String) -> String:
	var marker := "_lanes"
	var idx := key.rfind(marker)
	if idx == -1:
		return key
	var suffix := key.substr(idx + marker.length())
	if suffix.is_valid_int():
		return key.substr(0, idx)
	return key


static func canonical_lanes_for_notes(song_path: String, instrument: String, mode: String) -> int:
	for lanes in [CANONICAL_STATS_LANES, 3, 5]:
		if NotesUtils.notes_exist(song_path, instrument, mode, lanes):
			return lanes
	return CANONICAL_STATS_LANES


static func normalize_persisted_stats(stats: Dictionary) -> Dictionary:
	return {
		"stars": clampi(int(stats.get("stars", 0)), 0, MAX_RATING),
		"avg_nps": float(stats.get("avg_nps", 0.0)),
		"peak_nps": float(stats.get("peak_nps", 0.0)),
		"note_count": maxi(0, int(stats.get("note_count", 0))),
		"score": maxf(0.0, float(stats.get("score", 0.0))),
	}


static func parse_duration_seconds(duration_value: Variant) -> float:
	var s := str(duration_value).strip_edges()
	if s == "" or s == "Н/Д" or s == "00:00" or s == "0:00":
		return 0.0
	if s.contains(":"):
		var parts := s.split(":")
		if parts.size() >= 2:
			var minutes := int(parts[0]) if String(parts[0]).is_valid_int() else 0
			var seconds := int(parts[1]) if String(parts[1]).is_valid_int() else 0
			return float(minutes * 60 + seconds)
	if s.is_valid_float():
		return float(s)
	return 0.0


static func parse_bpm(bpm_value: Variant) -> float:
	var s := str(bpm_value).strip_edges()
	if s.is_valid_float():
		return maxf(1.0, float(s))
	return 120.0


static func analyze(notes: Array, duration_sec: float, lanes: int, bpm: float, instrument: String = "drums") -> Dictionary:
	var times: Array[float] = []
	var lane_at_time: Array[int] = []
	for item in notes:
		if not item is Dictionary:
			continue
		if str(item.get("type", "DefaultNote")) == "HoldNote":
			continue
		times.append(float(item.get("time", 0.0)))
		lane_at_time.append(int(item.get("lane", 0)))

	if times.is_empty():
		return {"stars": 0, "note_count": 0, "avg_nps": 0.0, "peak_nps": 0.0, "score": 0.0}

	var note_count := times.size()
	var span := times[times.size() - 1] - times[0]
	var effective_duration := maxf(duration_sec, span + 1.0)
	if effective_duration <= 0.01:
		effective_duration = 1.0

	var avg_nps := float(note_count) / effective_duration
	var peak_nps := _peak_notes_per_second(times)
	var stack_ratio := _simultaneous_stack_ratio(times, instrument)
	var lane_change_rate := _lane_change_rate(lane_at_time)
	var stack_weight := _stack_score_weight(instrument)

	var score := _composite_score_from_analysis(
		avg_nps, peak_nps, stack_ratio, stack_weight, lane_change_rate, bpm
	)

	var stars := _score_to_rating(score)
	return {
		"stars": stars,
		"note_count": note_count,
		"avg_nps": snappedf(avg_nps, 0.1),
		"peak_nps": snappedf(peak_nps, 0.1),
		"score": snappedf(score, 0.01),
	}


static func analyze_notes_file(song_path: String, instrument: String, mode: String, lanes: int = CANONICAL_STATS_LANES) -> Dictionary:
	var analysis_lanes := lanes
	if song_path != "" and not NotesUtils.notes_exist(song_path, instrument, mode, analysis_lanes):
		analysis_lanes = canonical_lanes_for_notes(song_path, instrument, mode)
	if song_path == "" or not NotesUtils.notes_exist(song_path, instrument, mode, analysis_lanes):
		return {}
	var arr := NotesUtils.load_notes_array(song_path, instrument, mode, analysis_lanes)
	var meta := SongLibrary.get_metadata_for_song(song_path)
	var duration_sec := parse_duration_seconds(meta.get("duration", "00:00"))
	var bpm := parse_bpm(meta.get("bpm", 120))
	return analyze(arr, duration_sec, CANONICAL_STATS_LANES, bpm, instrument)


static func ensure_persisted(song_path: String, instrument: String, mode: String, _lanes: int = CANONICAL_STATS_LANES) -> Dictionary:
	var existing := SongLibrary.get_chart_difficulty_variant(song_path, instrument, mode)
	if not existing.is_empty() and _stats_stars(existing) > 0:
		if _stale_sparse_score(existing):
			var refreshed := analyze_notes_file(song_path, instrument, mode)
			if not refreshed.is_empty():
				SongLibrary.set_chart_difficulty_variant(song_path, instrument, mode, refreshed)
				return refreshed
		var enriched := enrich_stats_note_count(existing, song_path, instrument, mode)
		enriched = enrich_stats_score(enriched, song_path, instrument, mode)
		if _persisted_stats_differ(existing, enriched):
			SongLibrary.set_chart_difficulty_variant(
				song_path, instrument, mode, enriched, CANONICAL_STATS_LANES, false
			)
		if float(enriched.get("avg_nps", 0.0)) <= 0.0:
			var fresh := analyze_notes_file(song_path, instrument, mode)
			if float(fresh.get("avg_nps", 0.0)) > 0.0:
				SongLibrary.set_chart_difficulty_variant(song_path, instrument, mode, fresh)
				return fresh
		return enriched
	var stats := analyze_notes_file(song_path, instrument, mode)
	if _stats_stars(stats) > 0 or float(stats.get("avg_nps", 0.0)) > 0.0:
		SongLibrary.set_chart_difficulty_variant(song_path, instrument, mode, stats)
	return stats


static func stats_for_sort(
	song_path: String,
	instrument: String,
	mode: String,
	lanes: int = CANONICAL_STATS_LANES,
) -> Dictionary:
	if song_path == "":
		return {}
	var existing := SongLibrary.get_chart_difficulty_variant(song_path, instrument, mode)
	if not existing.is_empty() and resolve_score(existing) > 0.0:
		return existing
	return {}


static func _persisted_stats_differ(before: Dictionary, after: Dictionary) -> bool:
	for key in ["stars", "avg_nps", "peak_nps", "note_count", "score"]:
		if key == "score":
			if snappedf(float(before.get(key, 0.0)), 0.01) != snappedf(float(after.get(key, 0.0)), 0.01):
				return true
		elif key in ["avg_nps", "peak_nps"]:
			if snappedf(float(before.get(key, 0.0)), 0.1) != snappedf(float(after.get(key, 0.0)), 0.1):
				return true
		elif int(before.get(key, 0)) != int(after.get(key, 0)):
			return true
	return false


static func enrich_stats_note_count(stats: Dictionary, song_path: String, instrument: String, mode: String) -> Dictionary:
	if int(stats.get("note_count", 0)) > 0 or song_path == "" or _stats_stars(stats) <= 0:
		return stats
	var fill := analyze_notes_file(song_path, instrument, mode)
	if int(fill.get("note_count", 0)) <= 0:
		return stats
	var out := stats.duplicate()
	out["note_count"] = fill["note_count"]
	return out


static func enrich_stats_score(stats: Dictionary, song_path: String, instrument: String, mode: String) -> Dictionary:
	if float(stats.get("score", 0.0)) > 0.0:
		return stats
	if _stats_stars(stats) <= 0 and float(stats.get("avg_nps", 0.0)) <= 0.0:
		return stats
	var out := stats.duplicate()
	if float(out.get("avg_nps", 0.0)) > 0.0:
		out["score"] = snappedf(
			_composite_score_from_metrics(
				float(out.get("avg_nps", 0.0)),
				float(out.get("peak_nps", 0.0)),
				float(out.get("chord_ratio", 0.0))
			),
			0.01
		)
	elif song_path != "":
		var fresh := analyze_notes_file(song_path, instrument, mode)
		if float(fresh.get("score", 0.0)) > 0.0:
			out["score"] = fresh["score"]
			if int(out.get("note_count", 0)) <= 0:
				out["note_count"] = fresh.get("note_count", 0)
			if float(out.get("avg_nps", 0.0)) <= 0.0:
				out["avg_nps"] = fresh.get("avg_nps", 0.0)
			if float(out.get("peak_nps", 0.0)) <= 0.0:
				out["peak_nps"] = fresh.get("peak_nps", 0.0)
	return out


static func format_rating(rating: int) -> String:
	var value := clampi(rating, 0, MAX_RATING)
	if value <= 0:
		return "—"
	return "%d/%d" % [value, MAX_RATING]


static func format_rating_for_list(rating: int) -> String:
	return format_rating(rating)


static func format_average_rating(avg: float) -> String:
	if avg <= 0.0:
		return "—"
	return "%.1f/%d" % [snappedf(avg, 0.1), MAX_RATING]


static func format_decimal_rating(rating: float, with_denominator: bool = true) -> String:
	if rating <= 0.0:
		return "—"
	var value := snappedf(rating, 0.1)
	if with_denominator:
		return "%.1f/%d" % [value, MAX_RATING]
	return "%.1f" % value


static func format_compact_rating(rating: float) -> String:
	if rating <= 0.0:
		return "—"
	return "%.1f★" % snappedf(rating, 0.1)


static func format_compact_multiplier(base_decimal: float, effective_decimal: float) -> String:
	if base_decimal <= 0.01 or effective_decimal <= 0.0:
		return ""
	return "×%.1f" % snappedf(effective_decimal / base_decimal, 0.1)


static func format_modifier_influence_percent(base_decimal: float, effective_decimal: float) -> String:
	if base_decimal <= 0.01 or effective_decimal <= 0.0:
		return ""
	var pct := modifier_influence_percent(base_decimal, effective_decimal)
	if absf(pct) < 0.5:
		return "0%"
	var sign := "+" if pct >= 0.0 else ""
	return "%s%d%%" % [sign, int(round(pct))]


static func modifier_influence_percent(base_decimal: float, effective_decimal: float) -> float:
	if base_decimal <= 0.01:
		return 0.0
	return ((effective_decimal / base_decimal) - 1.0) * 100.0


static func resolve_score(stats: Dictionary) -> float:
	var score := float(stats.get("score", 0.0))
	if score > 0.0:
		return score
	var avg := float(stats.get("avg_nps", 0.0))
	if avg > 0.0:
		return _composite_score_from_metrics(avg, float(stats.get("peak_nps", 0.0)), float(stats.get("chord_ratio", 0.0)))
	var stars := _stats_stars(stats)
	if stars > 0:
		return _rating_to_score_midpoint(stars)
	return 0.0


static func decimal_rating_from_stats(stats: Dictionary) -> float:
	return score_to_decimal(resolve_score(stats))


static func build_rating_snapshot(
	base_stats: Dictionary,
	modifiers: Array,
	params: Dictionary = {}
) -> Dictionary:
	var base_score := resolve_score(base_stats)
	var base_decimal := score_to_decimal(base_score)
	var effective_stats := effective_stats_for_modifiers(base_stats, modifiers, params)
	var effective_decimal := float(effective_stats.get("decimal_rating", base_decimal))
	var has_mods := not _RunModifiers.sanitize(modifiers).is_empty()
	return {
		"base_stats": base_stats,
		"effective_stats": effective_stats,
		"base_decimal": base_decimal,
		"effective_decimal": effective_decimal,
		"mod_percent": modifier_influence_percent(base_decimal, effective_decimal) if has_mods else 0.0,
		"has_mods": has_mods,
	}


static func format_effective_tooltip(snapshot: Dictionary) -> String:
	if snapshot.is_empty():
		return TranslationServer.translate("SONG_TOOLTIP_CHART_DIFFICULTY_NONE")
	var effective := float(snapshot.get("effective_decimal", 0.0))
	if effective <= 0.0:
		return TranslationServer.translate("SONG_TOOLTIP_CHART_DIFFICULTY_NONE")
	var lines: PackedStringArray = []
	lines.append(
		TranslationServer.translate("SONG_TOOLTIP_CHART_DIFFICULTY_EFFECTIVE_FMT")
		% format_decimal_rating(effective, true)
	)
	var effective_stats: Dictionary = snapshot.get("effective_stats", {})
	var overflow := maxf(0.0, effective - float(MAX_RATING))
	if overflow > 0.05:
		lines.append(
			TranslationServer.translate("SONG_TOOLTIP_CHART_DIFFICULTY_OVERFLOW_FMT")
			% snappedf(overflow, 0.1)
		)
	var density := format_density_text(effective_stats, bool(effective_stats.get("modifier_adjusted", false)))
	if density != "":
		lines.append(density)
	return "\n".join(lines)


static func get_run_rating(song_path: String, instrument: String, mode: String, lanes: int) -> int:
	var stats := best_stats_for_song(song_path, instrument, mode, lanes)
	return int(stats.get("stars", 0))


## Metadata-only rating for song list filters (no disk I/O).
static func get_cached_rating(song_path: String, instrument: String, mode: String, lanes: int) -> int:
	if song_path == "":
		return 0
	if not NotesUtils.notes_exist(song_path, instrument, mode, lanes):
		return 0
	var stats := SongLibrary.get_chart_difficulty_variant(song_path, instrument, mode, lanes)
	return int(stats.get("stars", 0))


static func effective_stats_for_modifiers(
	base: Dictionary,
	modifiers: Array,
	params: Dictionary = {}
) -> Dictionary:
	var mods := _RunModifiers.sanitize(modifiers)
	if mods.is_empty() or base.is_empty():
		return base
	var out := base.duplicate()
	var p := _RunModifiers.sync_params_from_modifiers(mods, params)
	var speed := _RunModifiers.song_pitch_scale(mods, p)
	var avg := float(base.get("avg_nps", 0.0)) * speed
	var peak := float(base.get("peak_nps", 0.0)) * speed
	var score := float(base.get("score", 0.0))
	if score <= 0.0:
		score = _composite_score_from_metrics(avg, peak, float(base.get("chord_ratio", 0.0)))
	else:
		var base_avg := float(base.get("avg_nps", 0.0))
		var base_peak := float(base.get("peak_nps", 0.0))
		var base_metric := base_avg * 0.82 + base_peak * 0.45
		var mod_metric := avg * 0.82 + peak * 0.45
		if base_metric > 0.01:
			score = score * (mod_metric / base_metric)
	score += _modifier_score_bonus(mods)
	out["avg_nps"] = snappedf(avg, 0.1)
	out["peak_nps"] = snappedf(peak, 0.1)
	out["score"] = snappedf(score, 0.01)
	out["decimal_rating"] = score_to_decimal(score)
	out["stars"] = _score_to_rating(score)
	out["modifier_adjusted"] = true
	return out


static func format_density_text(stats: Dictionary, modified: bool = false) -> String:
	var avg := float(stats.get("avg_nps", 0.0))
	var peak := float(stats.get("peak_nps", 0.0))
	if avg <= 0.0 and peak <= 0.0:
		return ""
	var text := ""
	if peak > avg + 0.05:
		text = TranslationServer.translate("SONG_DENSITY_PEAK_FMT") % [avg, peak]
	else:
		text = TranslationServer.translate("SONG_DENSITY_FMT") % avg
	if modified:
		return TranslationServer.translate("SONG_DENSITY_MOD_SUFFIX") % text
	return text


static func format_density_tooltip(stats: Dictionary) -> String:
	var note_count := int(stats.get("note_count", 0))
	if note_count > 0:
		var fmt := TranslationServer.translate("SONG_TOOLTIP_DENSITY_NOTES_FMT")
		if fmt == "SONG_TOOLTIP_DENSITY_NOTES_FMT":
			fmt = "Нот в чарте: %d"
		return fmt % note_count
	return format_density_text(stats, bool(stats.get("modifier_adjusted", false)))


static func _stats_stars(stats: Dictionary) -> int:
	return clampi(int(round(float(stats.get("stars", 0)))), 0, MAX_RATING)


static func format_difficulty_tooltip(stats: Dictionary) -> String:
	var rating := decimal_rating_from_stats(stats)
	if rating <= 0.0:
		return TranslationServer.translate("SONG_TOOLTIP_CHART_DIFFICULTY_NONE")
	var lines: PackedStringArray = [
		TranslationServer.translate("SONG_TOOLTIP_CHART_DIFFICULTY_FMT") % format_decimal_rating(rating, true)
	]
	var overflow := maxf(0.0, rating - float(MAX_RATING))
	if overflow > 0.05:
		lines.append(
			TranslationServer.translate("SONG_TOOLTIP_CHART_DIFFICULTY_OVERFLOW_FMT")
			% snappedf(overflow, 0.1)
		)
	return "\n".join(lines)


static func rating_color_for_decimal(rating: float) -> Color:
	return rating_color(int(clampf(rating, 1.0, float(MAX_RATING))))


static func _composite_score_from_analysis(
	avg_nps: float,
	peak_nps: float,
	stack_ratio: float,
	stack_weight: float,
	lane_change_rate: float,
	bpm: float,
) -> float:
	if avg_nps < SPARSE_DENSITY_NPS:
		return avg_nps * SPARSE_SCORE_SCALE
	var score := avg_nps * 0.82 + peak_nps * 0.45 + stack_ratio * stack_weight
	score += lane_change_rate * 0.10
	if bpm > 170.0:
		score += 0.04
	elif bpm > 150.0:
		score += 0.02
	return score


static func _composite_score_from_metrics(avg_nps: float, peak_nps: float, chord_ratio: float) -> float:
	return _composite_score_from_analysis(avg_nps, peak_nps, chord_ratio, 1.65, 0.0, 120.0)


static func _stale_sparse_score(stats: Dictionary) -> bool:
	if not _is_sparse_chart_stats(stats):
		return false
	return float(stats.get("score", 0.0)) >= 0.5


static func _is_sparse_chart_stats(stats: Dictionary) -> bool:
	var note_count := int(stats.get("note_count", 0))
	if note_count <= 0:
		return false
	var avg := float(stats.get("avg_nps", 0.0))
	if avg <= 0.0:
		return true
	return avg < SPARSE_DENSITY_NPS


static func _modifier_score_bonus(modifiers: Array) -> float:
	var bonus := 0.0
	if _RunModifiers.has_modifier(modifiers, _RunModifiers.ID_FAST_150):
		bonus += 0.55
	if _RunModifiers.has_modifier(modifiers, _RunModifiers.ID_SLOW_75):
		bonus -= 0.45
	if _RunModifiers.has_modifier(modifiers, _RunModifiers.ID_STRICT_TIMING):
		bonus += 0.35
	if _RunModifiers.has_modifier(modifiers, _RunModifiers.ID_NO_MISS_FORGIVENESS):
		bonus += 0.25
	if _RunModifiers.has_modifier(modifiers, _RunModifiers.ID_EASY_WINDOWS):
		bonus -= 0.30
	if _RunModifiers.has_modifier(modifiers, _RunModifiers.ID_NO_FAIL):
		bonus -= 0.20
	if _RunModifiers.has_modifier(modifiers, _RunModifiers.ID_HIDDEN):
		bonus += 0.20
	if _RunModifiers.has_modifier(modifiers, _RunModifiers.ID_SUDDEN):
		bonus += 0.30
	if _RunModifiers.has_modifier(modifiers, _RunModifiers.ID_SINGLE_LANE):
		bonus += 0.20
	if _RunModifiers.has_modifier(modifiers, _RunModifiers.ID_TIME_WARP):
		bonus += 0.10
	if _RunModifiers.has_modifier(modifiers, _RunModifiers.ID_SUDDEN_DEATH):
		bonus += 0.40
	if _RunModifiers.has_modifier(modifiers, _RunModifiers.ID_HALF_HP):
		bonus += 0.15
	return bonus


static func best_stats_for_song(song_path: String, instrument: String, mode: String, lanes: int) -> Dictionary:
	if song_path == "":
		return {}
	if NotesUtils.notes_exist(song_path, instrument, mode, lanes):
		return ensure_persisted(song_path, instrument, mode, lanes)
	return {}


static func rating_color(rating: int) -> Color:
	var value := clampi(rating, 0, MAX_RATING)
	if value <= 0:
		return Color(0.62, 0.7, 0.82, 0.92)
	# Every 2 rating points share one tier (1–2, 3–4, …, 9–10).
	var tier := clampi((value - 1) / 2, 0, 4)
	match tier:
		0:
			return Color(0.48, 0.9, 0.62, 1.0) # 1–2 easy
		1:
			return Color(0.42, 0.82, 0.95, 1.0) # 3–4 light
		2:
			return Color(0.72, 0.62, 0.92, 1.0) # 5–6 medium
		3:
			return Color(0.98, 0.72, 0.38, 1.0) # 7–8 hard
		_:
			return Color(0.98, 0.5, 0.48, 1.0) # 9–10 extreme


static func _peak_notes_per_second(times: Array[float]) -> float:
	if times.is_empty():
		return 0.0
	var buckets: Dictionary = {}
	for t in times:
		var bucket := int(floor(t))
		buckets[bucket] = int(buckets.get(bucket, 0)) + 1
	var peak := 0.0
	for bucket_key in buckets.keys():
		peak = maxf(peak, float(buckets[bucket_key]))
	return peak


static func _stack_score_weight(instrument: String) -> float:
	if instrument == "drums":
		return 1.10
	return 1.65


static func _simultaneous_stack_ratio(times: Array[float], instrument: String) -> float:
	if instrument == "drums":
		return _drum_stack_ratio(times)
	return _chord_ratio(times)


## Drums: pairs (kick+snare) are normal; only 3+ simultaneous hits add load.
static func _drum_stack_ratio(times: Array[float]) -> float:
	if times.size() < 3:
		return 0.0
	var stacked_notes := 0
	var i := 0
	while i < times.size():
		var j := i + 1
		while j < times.size() and times[j] - times[i] <= _SIMULTANEOUS_WINDOW_SEC:
			j += 1
		var group_size := j - i
		if group_size >= 3:
			stacked_notes += group_size
		i = j if group_size >= 3 else i + 1
	return float(stacked_notes) / float(times.size())


static func _chord_ratio(times: Array[float]) -> float:
	if times.size() < 2:
		return 0.0
	var chord_notes := 0
	var i := 0
	while i < times.size():
		var j := i + 1
		while j < times.size() and times[j] - times[i] <= _SIMULTANEOUS_WINDOW_SEC:
			j += 1
		var group_size := j - i
		if group_size > 1:
			chord_notes += group_size
		i = j if group_size > 1 else i + 1
	return float(chord_notes) / float(times.size())


static func _lane_change_rate(lanes: Array[int]) -> float:
	if lanes.size() < 2:
		return 0.0
	var changes := 0
	for i in range(1, lanes.size()):
		if lanes[i] != lanes[i - 1]:
			changes += 1
	return float(changes) / float(lanes.size() - 1)


static func _score_to_rating(score: float) -> int:
	var decimal := score_to_decimal(score)
	if decimal < 0.05:
		return 0
	return int(clampi(int(round(decimal)), 1, MAX_RATING))


static func score_to_decimal(score: float) -> float:
	if score <= 0.0:
		return 0.0
	if score < 0.5:
		return snappedf(score, 0.1)
	var breaks: Array[float] = [0.0, 0.9, 1.6, 2.3, 3.1, 3.9, 4.7, 5.6, 6.6, 7.8]
	for i in breaks.size() - 1:
		var lo := breaks[i]
		var hi := breaks[i + 1]
		if score < hi:
			var span := hi - lo
			var t := (score - lo) / span if span > 0.0 else 1.0
			return float(i + 1) + t
	return 10.0 + (score - breaks[breaks.size() - 1]) / 1.2


static func _rating_to_score_midpoint(rating: int) -> float:
	var value := clampi(rating, 1, MAX_RATING)
	var breaks: Array[float] = [0.0, 0.9, 1.6, 2.3, 3.1, 3.9, 4.7, 5.6, 6.6, 7.8]
	var lo := breaks[value - 1]
	var hi := breaks[value] if value < breaks.size() else breaks[breaks.size() - 1] + 1.2
	return (lo + hi) * 0.5


static var _rating_icon_base: Texture2D
static var _rating_icon_tiers: Dictionary = {}


static func rating_icon(rating: int) -> Texture2D:
	if rating <= 0:
		return null
	var tier := clampi((rating - 1) / 2, 0, 4)
	if _rating_icon_tiers.has(tier):
		return _rating_icon_tiers[tier]
	if _rating_icon_base == null:
		_rating_icon_base = load(ICON_PATH) as Texture2D
	if _rating_icon_base == null:
		return null
	var image: Image = _rating_icon_base.get_image()
	if image == null or image.is_empty():
		_rating_icon_tiers[tier] = _rating_icon_base
		return _rating_icon_base
	var tinted := _tint_icon_image(image, rating_color(rating))
	var tex := ImageTexture.create_from_image(tinted)
	_rating_icon_tiers[tier] = tex
	return tex


static func _tint_icon_image(src: Image, color: Color) -> Image:
	var out := src.duplicate()
	if out.get_format() != Image.FORMAT_RGBA8:
		out.convert(Image.FORMAT_RGBA8)
	for y in range(out.get_height()):
		for x in range(out.get_width()):
			var pixel: Color = out.get_pixel(x, y)
			if pixel.a <= 0.001:
				continue
			out.set_pixel(x, y, Color(color.r, color.g, color.b, pixel.a))
	return out
