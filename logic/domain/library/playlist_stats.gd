# logic/domain/library/playlist_stats.gd
class_name PlaylistStats
extends RefCounted

const _PlaylistCatalog = preload("res://logic/domain/library/playlist_catalog.gd")
const _ChartDifficultyAnalyzer = preload("res://logic/domain/charts/chart_difficulty_analyzer.gd")
const _GoalDiff = preload("res://logic/domain/generation/generation_goal_difficulty.gd")
const _NotesUtils = preload("res://logic/domain/rhythm/notes_utils.gd")
const _ProfileGenrePortrait = preload("res://logic/domain/profile/profile_genre_portrait.gd")
const _GenreGroupIcons = preload("res://logic/domain/library/genre_group_icons.gd")
const _GenPresetUi = preload("res://logic/ui/generation_preset_ui.gd")
const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")

const GENRE_TAG_LIMIT := 3
const DISPLAY_TAG_LIMIT := 5

const DIFFICULTY_ICONS := {
	"relaxed": "feather.svg",
	"standard": "circle-check.svg",
	"dense": "flame_gen.svg",
}

const DIFFICULTY_COLORS := {
	"relaxed": Color(0.62, 0.82, 0.96, 1.0),
	"standard": Color(0.55, 0.78, 0.98, 1.0),
	"dense": Color(1.0, 0.58, 0.32, 1.0),
}

static func compute_stats(playlist_id: String) -> Dictionary:
	return compute_stats_from_entries(
		_PlaylistCatalog.entries_for(playlist_id),
		_PlaylistCatalog.view_filter_for(playlist_id),
	)


static func compute_stats_from_entries(entries: Array, view_filter: Dictionary) -> Dictionary:
	var vf := _PlaylistCatalog.normalize_view_filter(view_filter)
	var instrument := str(vf.get("instrument", "drums"))
	var lanes := int(vf.get("lanes", 4))
	var track_count := 0
	var duration_sec := 0.0
	var rating_sum := 0.0
	var rating_count := 0
	var genre_counts: Dictionary = {}
	for item in entries:
		if item is not Dictionary:
			continue
		var entry := item as Dictionary
		var song_path := str(entry.get("song_path", "")).strip_edges()
		if song_path == "":
			continue
		track_count += 1
		duration_sec += _song_duration_sec(song_path)
		var rating := entry_rating(entry, instrument, lanes, vf)
		if rating > 0.0:
			rating_sum += rating
			rating_count += 1
		_accumulate_genres(song_path, genre_counts)
	var avg_rating := rating_sum / float(rating_count) if rating_count > 0 else 0.0
	return {
		"track_count": track_count,
		"duration_sec": duration_sec,
		"avg_rating": avg_rating,
		"genre_tags": _top_genre_tags(genre_counts),
		"display_tags": compute_display_tags(entries, vf),
	}


static func compute_display_tags(entries: Array, view_filter: Dictionary) -> Array[Dictionary]:
	var vf := _PlaylistCatalog.normalize_view_filter(view_filter)
	var instrument := str(vf.get("instrument", "drums"))
	var lanes := int(vf.get("lanes", 4))
	var out: Array[Dictionary] = []
	var genre_counts: Dictionary = {}
	var rating_sum := 0.0
	var rating_count := 0
	var bpm_sum := 0.0
	var bpm_count := 0
	var tier_counts: Dictionary = {}
	for item in entries:
		if item is not Dictionary:
			continue
		var entry := item as Dictionary
		var song_path := str(entry.get("song_path", "")).strip_edges()
		if song_path == "":
			continue
		_accumulate_genres(song_path, genre_counts)
		var rating := entry_rating(entry, instrument, lanes, vf)
		if rating > 0.0:
			rating_sum += rating
			rating_count += 1
		var bpm := _song_bpm(song_path)
		if bpm > 0.0:
			bpm_sum += bpm
			bpm_count += 1
		var pair := _resolved_chart_pair(entry, instrument, lanes, vf)
		if not pair.is_empty():
			var tier_key := "%s|%s" % [str(pair.get("goal", "")), str(pair.get("difficulty", ""))]
			tier_counts[tier_key] = int(tier_counts.get(tier_key, 0)) + 1
	for group_id in _top_genre_tags(genre_counts):
		if out.size() >= 2:
			break
		var gid := str(group_id).strip_edges()
		if gid == "":
			continue
		out.append({
			"icon": _GenreGroupIcons.icon_file_for_group(gid),
			"text": TranslationServer.translate(_ProfileGenrePortrait.group_locale_key(gid)),
			"accent": _GenreGroupIcons.tint_for_group(gid),
		})
	if out.size() < DISPLAY_TAG_LIMIT and rating_count > 0:
		var avg := rating_sum / float(rating_count)
		out.append({
			"icon": "star.svg",
			"text": TranslationServer.translate("PLAYLIST_TAG_AVG_RATING_FMT") % format_avg_rating(avg),
			"accent": Color(0.98, 0.82, 0.38, 1.0),
		})
	if out.size() < DISPLAY_TAG_LIMIT and bpm_count > 0:
		var avg_bpm := int(round(bpm_sum / float(bpm_count)))
		out.append({
			"icon": "activity.svg",
			"text": TranslationServer.translate("PLAYLIST_TAG_AVG_BPM_FMT") % avg_bpm,
			"accent": Color(0.58, 0.78, 0.98, 1.0),
		})
	var top_tier := _top_tier_pair(tier_counts)
	if out.size() < DISPLAY_TAG_LIMIT and not top_tier.is_empty():
		var goal := str(top_tier.get("goal", _GoalDiff.DEFAULT_GOAL)).strip_edges().to_lower()
		var diff := str(top_tier.get("difficulty", _GoalDiff.DEFAULT_DIFFICULTY)).strip_edges().to_lower()
		var goal_label := TranslationServer.translate("GEN_GOAL_%s" % goal.to_upper())
		var tag_text := goal_label
		if _GoalDiff.sanitize_goal(goal) != "original":
			tag_text = TranslationServer.translate("PLAYLIST_TAG_DOMINANT_FMT") % [
				goal_label,
				TranslationServer.translate(_GoalDiff.difficulty_label_key(goal, diff)),
			]
		out.append({
			"icon": str(_GenPresetUi.INTENT_ICONS.get(goal, DIFFICULTY_ICONS.get(diff, "layers.svg"))),
			"text": tag_text,
			"accent": DIFFICULTY_COLORS.get(diff, _UiIconHelper.ACCENT),
		})
	return out.slice(0, DISPLAY_TAG_LIMIT)


static func format_duration(seconds: float) -> String:
	var total := maxi(0, int(round(seconds)))
	var mins := total / 60
	var secs := total % 60
	return "%d:%02d" % [mins, secs]


static func format_duration_long(seconds: float) -> String:
	var total := maxi(0, int(round(seconds)))
	if total < 3600:
		return format_duration(seconds)
	var hours := total / 3600
	var mins := (total % 3600) / 60
	return "%dh %02dm" % [hours, mins]


static func format_avg_rating(rating: float) -> String:
	if rating <= 0.0:
		return "—"
	return _ChartDifficultyAnalyzer.format_compact_rating(rating)


static func entry_rating(
	entry: Dictionary,
	instrument: String,
	lanes: int,
	view_filter: Dictionary
) -> float:
	var song_path := str(entry.get("song_path", "")).strip_edges()
	if song_path == "":
		return 0.0
	var stem := str(entry.get("chart_stem", "")).strip_edges().to_lower()
	if stem != "" and _GoalDiff.is_chart_stem(stem):
		if not _NotesUtils.notes_exist(song_path, instrument, stem, lanes):
			return 0.0
		var stats := SongLibrary.get_chart_difficulty_variant(song_path, instrument, stem, lanes)
		return _ChartDifficultyAnalyzer.decimal_rating_from_stats(stats)
	var best := 0.0
	for g in view_filter.get("goals", _GoalDiff.GOALS):
		for d in view_filter.get("difficulties", _GoalDiff.DIFFICULTIES):
			var chart_stem := _GoalDiff.chart_stem(str(g), str(d))
			if not _NotesUtils.notes_exist(song_path, instrument, chart_stem, lanes):
				continue
			var stats := SongLibrary.get_chart_difficulty_variant(song_path, instrument, chart_stem, lanes)
			var rating := _ChartDifficultyAnalyzer.decimal_rating_from_stats(stats)
			if rating > best:
				best = rating
	return best


static func _song_duration_sec(song_path: String) -> float:
	if SongLibrary == null:
		return 0.0
	var meta := SongLibrary.get_metadata_for_song(song_path)
	return _ChartDifficultyAnalyzer.parse_duration_seconds(meta.get("duration", "00:00"))


static func _accumulate_genres(song_path: String, genre_counts: Dictionary) -> void:
	if SongLibrary == null:
		return
	var meta := SongLibrary.get_metadata_for_song(song_path)
	var primary := str(meta.get("primary_genre", "")).strip_edges()
	if primary != "":
		var group := _ProfileGenrePortrait.map_genre_to_group(primary)
		if group == "":
			group = "_other"
		genre_counts[group] = int(genre_counts.get(group, 0)) + 2
	var genres: Variant = meta.get("genres", [])
	if genres is Array:
		for item in genres:
			var group_id := _ProfileGenrePortrait.map_genre_to_group(str(item))
			if group_id == "":
				group_id = "_other"
			genre_counts[group_id] = int(genre_counts.get(group_id, 0)) + 1


static func _resolved_chart_pair(
	entry: Dictionary,
	instrument: String,
	lanes: int,
	view_filter: Dictionary
) -> Dictionary:
	var song_path := str(entry.get("song_path", "")).strip_edges()
	if song_path == "":
		return {}
	var stem := str(entry.get("chart_stem", "")).strip_edges().to_lower()
	if stem != "" and _GoalDiff.is_chart_stem(stem):
		if _NotesUtils.notes_exist(song_path, instrument, stem, lanes):
			return _GoalDiff.pair_from_stem(stem)
	var best_rating := 0.0
	var best_pair: Dictionary = {}
	for g in view_filter.get("goals", _GoalDiff.GOALS):
		for d in view_filter.get("difficulties", _GoalDiff.DIFFICULTIES):
			var chart_stem := _GoalDiff.chart_stem(str(g), str(d))
			if not _NotesUtils.notes_exist(song_path, instrument, chart_stem, lanes):
				continue
			var stats := SongLibrary.get_chart_difficulty_variant(song_path, instrument, chart_stem, lanes)
			var rating := _ChartDifficultyAnalyzer.decimal_rating_from_stats(stats)
			if rating > best_rating:
				best_rating = rating
				best_pair = {"goal": str(g), "difficulty": str(d)}
	return best_pair


static func _top_tier_pair(tier_counts: Dictionary) -> Dictionary:
	var ranked: Array[Dictionary] = []
	for tier_key in tier_counts.keys():
		var parts := str(tier_key).split("|")
		if parts.size() < 2:
			continue
		ranked.append({
			"goal": parts[0],
			"difficulty": parts[1],
			"count": int(tier_counts[tier_key]),
		})
	if ranked.is_empty():
		return {}
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("count", 0)) > int(b.get("count", 0))
	)
	return ranked[0]


static func _song_bpm(song_path: String) -> float:
	if SongLibrary == null:
		return 0.0
	var meta := SongLibrary.get_metadata_for_song(song_path)
	var raw: Variant = meta.get("bpm", "Н/Д")
	if raw is int:
		return float(raw) if int(raw) > 0 else 0.0
	if raw is float:
		return raw if raw > 0.0 else 0.0
	var text := str(raw).strip_edges()
	if text == "" or text == "Н/Д" or text.to_lower() == "n/a":
		return 0.0
	if text.is_valid_float():
		var value := text.to_float()
		return value if value > 0.0 else 0.0
	if text.is_valid_int():
		var iv := text.to_int()
		return float(iv) if iv > 0 else 0.0
	return 0.0


static func _top_genre_tags(genre_counts: Dictionary) -> Array[String]:
	var ranked: Array[Dictionary] = []
	for group_id in genre_counts.keys():
		ranked.append({"id": str(group_id), "count": int(genre_counts[group_id])})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("count", 0)) > int(b.get("count", 0))
	)
	var out: Array[String] = []
	for item in ranked:
		var gid := str(item.get("id", "")).strip_edges()
		if gid == "" or out.has(gid):
			continue
		out.append(gid)
		if out.size() >= GENRE_TAG_LIMIT:
			break
	return out
