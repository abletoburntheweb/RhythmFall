# logic/utils/victory_track_recommender.gd
extends RefCounted
class_name VictoryTrackRecommender

enum Criterion { SIMILAR_BPM, SIMILAR_GENRE, HARDER, RANDOM }

const BPM_TOLERANCE := 15.0

static var _genre_group_map: Dictionary = {}


static func pick_next(song_info: Dictionary, grade: String) -> Dictionary:
	var current_path := str(song_info.get("path", "")).replace("\\", "/")
	if current_path == "":
		return {}

	var instrument := str(song_info.get("instrument", "standard"))
	var mode := str(song_info.get("mode", "basic"))
	var lanes := int(song_info.get("lanes", 4))

	var candidates := _collect_playable_candidates(current_path, instrument, mode, lanes)
	if candidates.is_empty():
		return {}

	var criterion := _pick_criterion(grade)
	var pick := _pick_by_criterion(candidates, song_info, instrument, mode, lanes, criterion)
	if pick.is_empty():
		pick = _make_result(candidates[randi() % candidates.size()], Criterion.RANDOM, "")
	return pick


static func build_launch_song_data(recommended_song: Dictionary, run_song_info: Dictionary) -> Dictionary:
	var launch := recommended_song.duplicate(true)
	launch["instrument"] = run_song_info.get("instrument", "standard")
	launch["mode"] = str(run_song_info.get("mode", "basic"))
	launch["lanes"] = int(run_song_info.get("lanes", 4))
	var mods: Variant = run_song_info.get("modifiers", [])
	launch["modifiers"] = mods.duplicate() if mods is Array else []
	return launch


static func _collect_playable_candidates(exclude_path: String, instrument: String, mode: String, lanes: int) -> Array:
	var result: Array = []
	for song in SongLibrary.get_songs_list():
		var path := str(song.get("path", "")).replace("\\", "/")
		if path == "" or path == exclude_path:
			continue
		if not NotesUtils.notes_ready_for_scope(path, instrument, mode, lanes):
			continue
		result.append(_enrich_song(song, path))
	return result


static func _enrich_song(song: Dictionary, path: String) -> Dictionary:
	var enriched := song.duplicate(true)
	var meta := SongLibrary.get_metadata_for_song(path)
	for key in meta:
		var current := str(enriched.get(key, "")).strip_edges()
		var incoming = meta[key]
		if key == "title" or key == "artist":
			if _is_placeholder_field(key, current, path):
				enriched[key] = incoming
		elif not enriched.has(key) or current in ["", "Н/Д", "-1"]:
			enriched[key] = incoming
	enriched["path"] = path
	return enriched


static func get_display_names(song: Dictionary) -> Dictionary:
	var path := str(song.get("path", "")).replace("\\", "/")
	var meta := SongLibrary.get_metadata_for_song(path)
	var artist := str(song.get("artist", meta.get("artist", "")))
	var title := str(song.get("title", meta.get("title", "")))
	if not meta.is_empty():
		if _is_placeholder_field("artist", artist, path):
			artist = str(meta.get("artist", ""))
		if _is_placeholder_field("title", title, path):
			title = str(meta.get("title", ""))
	if _is_placeholder_field("title", title, path) and path != "":
		title = path.get_file().get_basename()
	return {
		"artist": _sanitize_display_text(artist),
		"title": _sanitize_display_text(title),
	}


static func _is_placeholder_field(field: String, value: String, path: String) -> bool:
	var text := str(value).strip_edges()
	match field:
		"title":
			if text == "" or text == "Без названия" or text == "No title":
				return true
			if path != "" and text == path.get_file().get_basename():
				return true
			return false
		"artist":
			return text == "" or text == "Неизвестен" or text == "Unknown"
		_:
			return text == ""


static func _sanitize_display_text(text: String) -> String:
	var cleaned := str(text).strip_edges()
	cleaned = cleaned.replace("\r", " ").replace("\n", " ").replace("\t", " ")
	cleaned = cleaned.replace("\u200B", "").replace("\u2028", " ").replace("\u2029", " ")
	return " ".join(cleaned.split(" ", false))


static func _parse_bpm(value: Variant) -> float:
	var text := str(value).strip_edges()
	if text == "" or text == "Н/Д" or text == "-1":
		return -1.0
	if text.is_valid_float():
		return float(text)
	return -1.0


static func _primary_genre(song: Dictionary) -> String:
	var primary := str(song.get("primary_genre", "")).strip_edges().to_lower()
	if primary != "" and primary != "unknown":
		return GenreSearch.normalize_canonical(primary)
	var genres: Variant = song.get("genres", "")
	if genres is Array and genres.size() > 0:
		return GenreSearch.normalize_canonical(str(genres[0]))
	var genres_text := str(genres).strip_edges()
	if genres_text != "":
		return GenreSearch.normalize_canonical(genres_text.split(",")[0].strip_edges())
	return ""


static func _genre_group(genre: String) -> String:
	if genre == "":
		return ""
	_ensure_genre_group_map()
	return str(_genre_group_map.get(genre, ""))


static func _ensure_genre_group_map() -> void:
	if not _genre_group_map.is_empty():
		return
	var user_path := "user://genre_groups.json"
	var path := user_path if FileAccess.file_exists(user_path) else "res://data/genre_groups.json"
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	for group_name in parsed:
		var genres: Variant = parsed[group_name]
		if not genres is Array:
			continue
		for genre in genres:
			_genre_group_map[GenreSearch.normalize_canonical(str(genre))] = str(group_name)
	GenreSearch.enrich_group_map(_genre_group_map)


static func _chart_stars(song_path: String, instrument: String, mode: String, lanes: int) -> int:
	return ChartDifficultyAnalyzer.get_cached_rating(song_path, instrument, mode, lanes)


static func _pick_criterion(grade: String) -> int:
	var weights := {
		Criterion.SIMILAR_BPM: 25,
		Criterion.SIMILAR_GENRE: 25,
		Criterion.HARDER: 25,
		Criterion.RANDOM: 25,
	}
	match grade:
		"SS", "S":
			weights[Criterion.HARDER] = 45
			weights[Criterion.SIMILAR_BPM] = 20
			weights[Criterion.SIMILAR_GENRE] = 20
			weights[Criterion.RANDOM] = 15
		"C", "D", "F":
			weights[Criterion.SIMILAR_BPM] = 40
			weights[Criterion.SIMILAR_GENRE] = 35
			weights[Criterion.HARDER] = 10
			weights[Criterion.RANDOM] = 15
	var total := 0
	for weight in weights.values():
		total += int(weight)
	var roll := randi() % maxi(1, total)
	var acc := 0
	for criterion in weights:
		acc += int(weights[criterion])
		if roll < acc:
			return criterion
	return Criterion.RANDOM


static func _pick_by_criterion(
	candidates: Array,
	song_info: Dictionary,
	instrument: String,
	mode: String,
	lanes: int,
	criterion: int
) -> Dictionary:
	var current_path := str(song_info.get("path", ""))
	var current_meta := SongLibrary.get_metadata_for_song(current_path)
	var current_bpm := _parse_bpm(song_info.get("bpm", current_meta.get("bpm", "")))
	var current_genre := _primary_genre(song_info)
	if current_genre == "":
		current_genre = _primary_genre(current_meta)
	var current_stars := _chart_stars(current_path, instrument, mode, lanes)

	match criterion:
		Criterion.SIMILAR_BPM:
			if current_bpm < 0.0:
				return {}
			var matches: Array = []
			var best_delta := 9999.0
			for song in candidates:
				var bpm := _parse_bpm(song.get("bpm", ""))
				if bpm < 0.0:
					continue
				var delta := absf(bpm - current_bpm)
				if delta > BPM_TOLERANCE:
					continue
				if delta < best_delta - 0.01:
					best_delta = delta
					matches = [song]
				elif absf(delta - best_delta) < 0.01:
					matches.append(song)
			if matches.is_empty():
				return {}
			var picked: Dictionary = matches[randi() % matches.size()]
			var picked_bpm := int(round(_parse_bpm(picked.get("bpm", current_bpm))))
			return _make_result(picked, Criterion.SIMILAR_BPM, str(picked_bpm))

		Criterion.SIMILAR_GENRE:
			if current_genre == "":
				return {}
			var current_group := _genre_group(current_genre)
			var matches: Array = []
			for song in candidates:
				var genre := _primary_genre(song)
				if genre == "":
					continue
				if genre == current_genre:
					matches.append(song)
					continue
				if current_group != "" and _genre_group(genre) == current_group:
					matches.append(song)
			if matches.is_empty():
				return {}
			var picked: Dictionary = matches[randi() % matches.size()]
			var picked_genre := _primary_genre(picked)
			return _make_result(picked, Criterion.SIMILAR_GENRE, picked_genre)

		Criterion.HARDER:
			if current_stars <= 0:
				return {}
			var matches: Array = []
			var target_stars := 999
			for song in candidates:
				var stars := _chart_stars(str(song.get("path", "")), instrument, mode, lanes)
				if stars <= current_stars:
					continue
				if stars < target_stars:
					target_stars = stars
					matches = [song]
				elif stars == target_stars:
					matches.append(song)
			if matches.is_empty():
				return {}
			return _make_result(matches[randi() % matches.size()], Criterion.HARDER, str(target_stars))

		_:
			return _make_result(candidates[randi() % candidates.size()], Criterion.RANDOM, "")


static func _make_result(song: Dictionary, criterion: int, detail: String) -> Dictionary:
	return {
		"song": song,
		"criterion": criterion,
		"detail": detail,
	}
