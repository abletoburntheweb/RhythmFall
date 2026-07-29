# logic/utils/generation_preset_recommender.gd
extends RefCounted
class_name GenerationPresetRecommender

const CHILL_GENRES := [
	"chillwave", "chillout", "ambient", "downtempo", "vaporwave", "witch house",
	"dark ambient", "drone", "berlin school", "dungeon synth",
]
const ROCK_GROUPS := ["rock"]
const METAL_GROUPS := ["metal"]
const GUITAR_HEAVY_GROUPS := ROCK_GROUPS + METAL_GROUPS
const EDM_GROUPS := ["edm", "electronic", "bass_music", "pop"]
const DENSE_ELECTRONIC_GENRES := ["hyperpop", "brostep", "drum and bass", "breakcore", "hardcore"]

static var _genre_group_map: Dictionary = {}


static func recommend(song: Dictionary, dna: Dictionary = {}) -> Dictionary:
	var bpm := _parse_bpm(song.get("bpm", ""))
	var genre := _primary_genre(song)
	var group := _genre_group(genre)
	var result := {
		"intent": "groove",
		"mode": "basic",
		"reason_key": "GEN_SMART_REASON_DEFAULT",
		"reason_args": {},
		"warn_mode": "",
		"warn_key": "",
	}

	if bpm > 0.0 and bpm < 95.0:
		result["intent"] = "original"
		result["mode"] = "natural"
		result["reason_key"] = "GEN_SMART_REASON_SLOW_AMBIENT"
		result["reason_args"] = {"bpm": int(round(bpm))}
	elif _genre_in_list(genre, CHILL_GENRES) or (
		group == "electronic" and bpm > 0.0 and bpm < 120.0
	):
		result["intent"] = "groove"
		result["mode"] = "basic"
		result["reason_key"] = "GEN_SMART_REASON_CHILL"
	elif _genre_in_list(genre, DENSE_ELECTRONIC_GENRES) or (
		bpm >= 165.0 and group in EDM_GROUPS
	):
		result["intent"] = "groove"
		result["mode"] = "basic"
		result["reason_key"] = "GEN_SMART_REASON_DENSE_ELECTRONIC"
		result["reason_args"] = {"bpm": int(round(bpm))} if bpm > 0.0 else {}
	elif group in METAL_GROUPS and bpm >= 170.0:
		result["intent"] = "groove"
		result["mode"] = "basic"
		result["reason_key"] = "GEN_SMART_REASON_METAL_FAST"
		result["reason_args"] = {"bpm": int(round(bpm))}
	elif group in METAL_GROUPS:
		result["intent"] = "groove"
		result["mode"] = "basic"
		result["reason_key"] = "GEN_SMART_REASON_METAL"
	elif group in ROCK_GROUPS and bpm >= 170.0:
		result["intent"] = "groove"
		result["mode"] = "basic"
		result["reason_key"] = "GEN_SMART_REASON_ROCK_FAST"
		result["reason_args"] = {"bpm": int(round(bpm))}
	elif group in ROCK_GROUPS:
		result["intent"] = "groove"
		result["mode"] = "basic"
		result["reason_key"] = "GEN_SMART_REASON_ROCK"
	elif group in EDM_GROUPS and bpm >= 120.0:
		result["intent"] = "groove"
		result["mode"] = "basic"
		result["reason_key"] = "GEN_SMART_REASON_EDM"
		result["reason_args"] = {"bpm": int(round(bpm))} if bpm > 0.0 else {}

	_apply_dna_signals(dna, result)

	result["warn_mode"] = ""
	result["warn_key"] = _warn_key_for_mismatch(result["intent"], genre, group, bpm)
	if result["warn_key"] != "":
		result["warn_mode"] = result["intent"]
	return result


static func _apply_dna_signals(dna: Dictionary, result: Dictionary) -> void:
	if dna.is_empty():
		return
	var genes: Dictionary = dna.get("genes", {}) if dna.get("genes", {}) is Dictionary else {}
	var rhythm: Dictionary = genes.get("rhythm", {}) if genes.get("rhythm", {}) is Dictionary else {}
	var structure: Dictionary = genes.get("structure", {}) if genes.get("structure", {}) is Dictionary else {}

	if String(rhythm.get("percussion_viable", "")).strip_edges().to_lower() == "low":
		result["intent"] = "groove"
		result["mode"] = "basic"
		result["reason_key"] = "GEN_SMART_REASON_WEAK_DRUMS"
		return

	var quiet := int(structure.get("loud_mix_quiet_drum", 0) or 0)
	if quiet <= 0:
		var warnings: Variant = dna.get("warnings", [])
		if warnings is Array:
			for w in warnings:
				if w is Dictionary and String(w.get("key", "")) == "DNA_WARN_QUIET_DRUM_SECTIONS":
					quiet = int(w.get("args", {}).get("count", 0) if w.get("args", {}) is Dictionary else 0)
					break
	if quiet >= 6:
		result["intent"] = "groove"
		result["mode"] = "basic"
		result["reason_key"] = "GEN_SMART_REASON_QUIET_SECTIONS"
		result["reason_args"] = {"count": quiet}


static func _warn_key_for_mismatch(intent: String, genre: String, group: String, bpm: float) -> String:
	if intent == "groove":
		if _genre_in_list(genre, CHILL_GENRES) or (group == "electronic" and bpm > 0.0 and bpm < 120.0):
			return "GEN_SMART_WARN_ENHANCED_CHILL"
		if group in GUITAR_HEAVY_GROUPS and bpm >= 170.0:
			return "GEN_SMART_WARN_ENHANCED_METAL"
	return ""


static func warn_if_selected(selected_intent: String, recommendation: Dictionary) -> String:
	var recommended := str(recommendation.get("intent", recommendation.get("mode", "groove")))
	if selected_intent == recommended:
		return ""
	if selected_intent == "original" and recommended == "groove":
		var reason := str(recommendation.get("reason_key", ""))
		if reason in [
			"GEN_SMART_REASON_METAL_FAST", "GEN_SMART_REASON_METAL",
			"GEN_SMART_REASON_ROCK_FAST", "GEN_SMART_REASON_ROCK",
			"GEN_SMART_REASON_DENSE_ELECTRONIC",
		]:
			return "GEN_SMART_WARN_ORIGINAL_DENSE"
	if selected_intent == "sparse" and recommended == "groove":
		var reason := str(recommendation.get("reason_key", ""))
		if reason in [
			"GEN_SMART_REASON_EDM", "GEN_SMART_REASON_METAL", "GEN_SMART_REASON_ROCK",
			"GEN_SMART_REASON_DENSE_ELECTRONIC",
		]:
			return "GEN_SMART_WARN_MINIMAL_BUSY"
	return ""


static func load_dna_for_song(song_path: String, instrument: String, mode: String, lanes: int) -> Dictionary:
	if song_path == "":
		return {}
	if not NotesUtils.has_full_rhythm_dna(song_path, instrument, mode, lanes):
		return {}
	return NotesUtils.load_rhythm_dna(song_path, instrument, mode, lanes)


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


static func _genre_in_list(genre: String, list: Array) -> bool:
	if genre == "":
		return false
	for item in list:
		if genre == GenreSearch.normalize_canonical(str(item)):
			return true
	return false


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
		for g in genres:
			_genre_group_map[GenreSearch.normalize_canonical(str(g))] = str(group_name)
	GenreSearch.enrich_group_map(_genre_group_map)
