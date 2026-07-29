# logic/domain/session/session_scope_resolver.gd
class_name SessionScopeResolver
extends RefCounted

const _Intents = preload("res://logic/domain/generation/generation_intents.gd")
const _GoalDiff = preload("res://logic/domain/generation/generation_goal_difficulty.gd")
const _EndlessSessionConfig = preload("res://logic/domain/session/endless_session_config.gd")
const _ChartDifficultyAnalyzer = preload("res://logic/domain/charts/chart_difficulty_analyzer.gd")
const _NotesUtils = preload("res://logic/domain/rhythm/notes_utils.gd")
const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const _ProfileGenrePortrait = preload("res://logic/domain/profile/profile_genre_portrait.gd")
const _PlaylistCatalog = preload("res://logic/domain/library/playlist_catalog.gd")

const DEFAULT_INSTRUMENT := EndlessSessionConfig.DEFAULT_INSTRUMENT


static func resolve_scope(
	config: Dictionary,
	instrument: String = ""
) -> Array[Dictionary]:
	var cfg := _EndlessSessionConfig.sanitize(config)
	var instruments: Array = _EndlessSessionConfig.instruments_from_config(cfg, instrument)
	var source := str(cfg.get("track_source", _EndlessSessionConfig.TRACK_SOURCE_RANDOM))
	if source == _EndlessSessionConfig.TRACK_SOURCE_PLAYLIST:
		var playlist_out: Array[Dictionary] = []
		for inst in instruments:
			playlist_out.append_array(_resolve_playlist_scope(cfg, str(inst)))
		return playlist_out
	var out: Array[Dictionary] = []
	for song_path in _collect_song_paths(cfg):
		for inst in instruments:
			out.append_array(_entries_for_song(song_path, cfg, str(inst)))
	return out


static func scope_count(config: Dictionary, instrument: String = "") -> int:
	return resolve_scope(config, instrument).size()


## Best chart for one song after applying session difficulty / duration / generation filters.
## Used by track picker to show rating and to decide if a song is in scope.
static func best_scope_chart_for_song(
	song_path: String,
	config: Dictionary,
	instrument: String = ""
) -> Dictionary:
	var cfg := _preview_filter_config(config)
	var instruments: Array = _EndlessSessionConfig.instruments_from_config(cfg, instrument)
	var best: Dictionary = {}
	var best_rating := 0.0
	for inst in instruments:
		for entry in _entries_for_song(song_path, cfg, str(inst)):
			var rating := float(entry.get("decimal_rating", 0.0))
			if rating > best_rating:
				best_rating = rating
				best = entry
	return best


static func _preview_filter_config(config: Dictionary) -> Dictionary:
	var cfg := _EndlessSessionConfig.sanitize(config)
	cfg["track_source"] = _EndlessSessionConfig.TRACK_SOURCE_RANDOM
	cfg["random_favorites_only"] = false
	cfg["selected_song_paths"] = []
	return cfg


static func pick_random_entry(
	config: Dictionary,
	rng: RandomNumberGenerator = null,
	instrument: String = ""
) -> Dictionary:
	var cfg := _EndlessSessionConfig.sanitize(config)
	var scope := resolve_scope(cfg, instrument)
	if scope.is_empty():
		return {}
	var picker := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		picker.randomize()
	return scope[picker.randi_range(0, scope.size() - 1)]


## Picks the next scope entry for an endless run.
## deck_state: { "last_song_path": String, "deck": Array[String] } — mutated in place.
static func pick_next_entry(
	config: Dictionary,
	deck_state: Dictionary,
	rng: RandomNumberGenerator = null,
	instrument: String = ""
) -> Dictionary:
	var cfg := _EndlessSessionConfig.sanitize(config)
	var scope := resolve_scope(cfg, instrument)
	if scope.is_empty():
		return {}
	var picker := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		picker.randomize()
	var last_path := str(deck_state.get("last_song_path", "")).strip_edges()
	var used_paths: Array = deck_state.get("used_song_paths", [])
	if not used_paths is Array:
		used_paths = []
	var unique_only := bool(cfg.get("unique_songs_only", false))
	var source := str(cfg.get("track_source", _EndlessSessionConfig.TRACK_SOURCE_RANDOM))
	var entry: Dictionary = {}
	if (
		source == _EndlessSessionConfig.TRACK_SOURCE_SELECTED
		or source == _EndlessSessionConfig.TRACK_SOURCE_PLAYLIST
	):
		entry = _pick_next_selected_entry(scope, cfg, deck_state, last_path, picker, used_paths, unique_only)
	else:
		entry = _pick_next_random_entry(scope, deck_state, last_path, picker, unique_only)
	if not entry.is_empty() and unique_only:
		var song_path := str(entry.get("song_path", "")).strip_edges()
		if song_path != "" and not used_paths.has(song_path):
			used_paths.append(song_path)
			deck_state["used_song_paths"] = used_paths
	return entry


static func build_song_info(song_path: String) -> Dictionary:
	var path := str(song_path).strip_edges()
	var info: Dictionary = {}
	if SongLibrary == null or path == "":
		return {"path": path}
	if SongLibrary.has_method("get_songs_list"):
		for song in SongLibrary.get_songs_list():
			if song is not Dictionary:
				continue
			if str(song.get("path", "")).strip_edges() == path:
				info = (song as Dictionary).duplicate(true)
				break
	if info.is_empty() and SongLibrary.has_method("get_metadata_for_song"):
		var meta := SongLibrary.get_metadata_for_song(path)
		if meta is Dictionary:
			info = meta.duplicate(true)
	info["path"] = path
	return info


static func resolve_chart_tag_for_entry(entry: Dictionary) -> String:
	var song_path := str(entry.get("song_path", "")).strip_edges()
	if song_path == "":
		return ""
	return _NotesUtils.resolve_play_chart_tag(
		song_path,
		str(entry.get("instrument", DEFAULT_INSTRUMENT)),
		str(entry.get("mode", "basic")),
		int(entry.get("lanes", 4)),
	)


static func _pick_next_random_entry(
	scope: Array[Dictionary],
	deck_state: Dictionary,
	last_path: String,
	rng: RandomNumberGenerator,
	unique_only: bool = false
) -> Dictionary:
	var used_paths: Array = deck_state.get("used_song_paths", [])
	if not used_paths is Array:
		used_paths = []
	var candidates := _filter_random_candidates(scope, last_path, used_paths, unique_only)
	if candidates.is_empty() and unique_only and not scope.is_empty():
		_begin_new_pool_lap(deck_state)
		used_paths = deck_state.get("used_song_paths", [])
		candidates = _filter_random_candidates(scope, last_path, used_paths, unique_only)
	if candidates.is_empty():
		return {}
	return candidates[rng.randi_range(0, candidates.size() - 1)]


static func _filter_random_candidates(
	scope: Array[Dictionary],
	last_path: String,
	used_paths: Array,
	unique_only: bool
) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = scope.duplicate()
	if unique_only:
		var unique_filtered: Array[Dictionary] = []
		for entry in candidates:
			var path := str(entry.get("song_path", "")).strip_edges()
			if path != "" and not used_paths.has(path):
				unique_filtered.append(entry)
		candidates = unique_filtered
	elif last_path != "" and candidates.size() > 1:
		var filtered: Array[Dictionary] = []
		for entry in candidates:
			if str(entry.get("song_path", "")).strip_edges() != last_path:
				filtered.append(entry)
		if not filtered.is_empty():
			candidates = filtered
	return candidates


static func _begin_new_pool_lap(deck_state: Dictionary) -> int:
	var lap := int(deck_state.get("pool_lap", 1)) + 1
	deck_state["pool_lap"] = lap
	deck_state["announce_pool_lap"] = lap
	deck_state["used_song_paths"] = []
	return lap


static func _pick_next_selected_entry(
	scope: Array[Dictionary],
	config: Dictionary,
	deck_state: Dictionary,
	last_path: String,
	rng: RandomNumberGenerator,
	used_paths: Array = [],
	unique_only: bool = false
) -> Dictionary:
	if bool(deck_state.get("expanded_random", false)):
		return _pick_next_expanded_random_entry(config, deck_state, last_path, rng, used_paths, unique_only)
	var deck: Array = deck_state.get("deck", [])
	if deck.is_empty():
		if bool(deck_state.get("initial_deck_built", false)):
			return _handle_selected_pool_cycle_end(scope, config, deck_state, last_path, rng, used_paths, unique_only)
		deck = _build_selected_deck(scope, config, rng)
		deck_state["deck"] = deck
		deck_state["initial_deck_built"] = true
		if not deck_state.has("pool_lap"):
			deck_state["pool_lap"] = 1
		if deck.is_empty():
			return {}
	var attempts := deck.size() + 1
	while attempts > 0:
		attempts -= 1
		if deck.is_empty():
			return _handle_selected_pool_cycle_end(scope, config, deck_state, last_path, rng, used_paths, unique_only)
		var deck_key := str(deck[0]).strip_edges()
		deck.remove_at(0)
		deck_state["deck"] = deck
		var song_path := _song_path_from_deck_key(deck_key)
		if unique_only and used_paths.has(song_path):
			continue
		if song_path == last_path and deck.size() > 0:
			deck.append(deck_key)
			deck_state["deck"] = deck
			continue
		var entry := _pick_entry_for_deck_key(scope, deck_key, rng)
		if entry.is_empty():
			continue
		return entry
	return {}


static func _handle_selected_pool_cycle_end(
	scope: Array[Dictionary],
	config: Dictionary,
	deck_state: Dictionary,
	last_path: String,
	rng: RandomNumberGenerator,
	used_paths: Array = [],
	unique_only: bool = false
) -> Dictionary:
	var policy := str(
		config.get("selected_pool_after", _EndlessSessionConfig.SELECTED_POOL_AFTER_RESHUFFLE)
	)
	var source := str(config.get("track_source", _EndlessSessionConfig.TRACK_SOURCE_SELECTED))
	var playlist_id := str(config.get("playlist_id", "")).strip_edges()
	var preserve_playlist_order := (
		source == _EndlessSessionConfig.TRACK_SOURCE_PLAYLIST
		and _PlaylistCatalog.preserve_order_for(playlist_id)
	)
	var force_reshuffle := (
		unique_only
		or (
			source == _EndlessSessionConfig.TRACK_SOURCE_PLAYLIST
			and not preserve_playlist_order
		)
	)
	if force_reshuffle or policy == _EndlessSessionConfig.SELECTED_POOL_AFTER_RESHUFFLE:
		if unique_only:
			deck_state["used_song_paths"] = []
		var deck := _build_selected_deck(scope, config, rng)
		deck_state["deck"] = deck
		if bool(deck_state.get("initial_deck_built", false)):
			_begin_new_pool_lap(deck_state)
		elif not deck_state.has("pool_lap"):
			deck_state["pool_lap"] = 1
		if deck.is_empty():
			return {}
		return _pick_next_selected_entry(scope, config, deck_state, last_path, rng, used_paths, unique_only)
	match policy:
		_EndlessSessionConfig.SELECTED_POOL_AFTER_EXPAND:
			deck_state["expanded_random"] = true
			return _pick_next_expanded_random_entry(config, deck_state, last_path, rng, used_paths, unique_only)
		_:
			var deck := _build_selected_deck(scope, config, rng)
			deck_state["deck"] = deck
			_begin_new_pool_lap(deck_state)
			if deck.is_empty():
				return {}
			return _pick_next_selected_entry(scope, config, deck_state, last_path, rng, used_paths, unique_only)


static func _pick_next_expanded_random_entry(
	config: Dictionary,
	deck_state: Dictionary,
	last_path: String,
	rng: RandomNumberGenerator,
	used_paths: Array = [],
	unique_only: bool = false
) -> Dictionary:
	var expanded_cfg := config.duplicate(true)
	expanded_cfg["track_source"] = _EndlessSessionConfig.TRACK_SOURCE_RANDOM
	expanded_cfg["selected_song_paths"] = []
	var scope := resolve_scope(expanded_cfg, "")
	if scope.is_empty():
		return {}
	return _pick_next_random_entry(scope, deck_state, last_path, rng, unique_only)


static func _build_shuffled_selected_deck(scope: Array[Dictionary], rng: RandomNumberGenerator) -> Array:
	var paths: Array[String] = []
	for entry in scope:
		var path := str(entry.get("song_path", "")).strip_edges()
		if path != "" and not paths.has(path):
			paths.append(path)
	var deck: Array = []
	for path in paths:
		deck.append(path)
	deck.shuffle()
	return deck


static func _build_selected_deck(
	scope: Array[Dictionary],
	config: Dictionary,
	rng: RandomNumberGenerator
) -> Array:
	var source := str(config.get("track_source", _EndlessSessionConfig.TRACK_SOURCE_SELECTED))
	if source == _EndlessSessionConfig.TRACK_SOURCE_PLAYLIST:
		var playlist_id := str(config.get("playlist_id", "")).strip_edges()
		if _PlaylistCatalog.preserve_order_for(playlist_id):
			return _build_ordered_playlist_deck(playlist_id, scope)
	return _build_shuffled_selected_deck(scope, rng)


static func _build_ordered_playlist_deck(playlist_id: String, scope: Array[Dictionary]) -> Array:
	var deck: Array = []
	var seen: Dictionary = {}
	for pl_entry in _PlaylistCatalog.entries_for(playlist_id):
		if pl_entry is not Dictionary:
			continue
		var key := _PlaylistCatalog.entry_key(pl_entry as Dictionary)
		if key == "" or seen.has(key):
			continue
		if not _scope_has_deck_key(scope, key):
			continue
		seen[key] = true
		deck.append(key)
	return deck


static func _scope_has_deck_key(scope: Array[Dictionary], deck_key: String) -> bool:
	return not _pick_entry_for_deck_key(scope, deck_key, null).is_empty()


static func _song_path_from_deck_key(deck_key: String) -> String:
	var key := str(deck_key).strip_edges()
	if key.contains("|"):
		return key.split("|", false, 1)[0]
	return key


static func _pick_entry_for_deck_key(
	scope: Array[Dictionary],
	deck_key: String,
	rng: RandomNumberGenerator
) -> Dictionary:
	var key := str(deck_key).strip_edges()
	if key == "":
		return {}
	if key.contains("|"):
		var parts := key.split("|", false, 1)
		var song_path := str(parts[0]).strip_edges()
		var stem := str(parts[1]).strip_edges().to_lower()
		for entry in scope:
			if str(entry.get("song_path", "")).strip_edges() != song_path:
				continue
			var intent := str(entry.get("intent", "")).strip_edges()
			var entry_stem := _GoalDiff.stem_from_intent_legacy(intent)
			if entry_stem == stem:
				return entry
		return {}
	var song_path := key
	if rng != null:
		return _pick_random_entry_for_song(scope, song_path, rng)
	return _best_entry_for_song(scope, song_path)


static func _resolve_playlist_scope(cfg: Dictionary, instrument: String) -> Array[Dictionary]:
	var playlist_id := str(cfg.get("playlist_id", "")).strip_edges()
	if playlist_id == "":
		return []
	var out: Array[Dictionary] = []
	var seen_keys: Dictionary = {}
	for pl_entry in _PlaylistCatalog.entries_for(playlist_id):
		if pl_entry is not Dictionary:
			continue
		var song_path := str((pl_entry as Dictionary).get("song_path", "")).strip_edges()
		if song_path == "":
			continue
		var stem := str((pl_entry as Dictionary).get("chart_stem", "")).strip_edges().to_lower()
		if stem != "" and _GoalDiff.is_chart_stem(stem):
			var pinned := _entry_for_pinned_stem(song_path, stem, instrument, cfg)
			if pinned.is_empty():
				continue
			var pkey := _PlaylistCatalog.entry_key(pl_entry as Dictionary)
			if seen_keys.has(pkey):
				continue
			seen_keys[pkey] = true
			out.append(pinned)
			continue
		for entry in _entries_for_song(song_path, cfg, instrument):
			var ekey := "%s|%s" % [
				str(entry.get("song_path", "")).strip_edges(),
				_GoalDiff.stem_from_intent_legacy(str(entry.get("intent", ""))),
			]
			if seen_keys.has(ekey):
				continue
			seen_keys[ekey] = true
			out.append(entry)
	return out


static func _entry_for_pinned_stem(
	song_path: String,
	chart_stem: String,
	instrument: String,
	cfg: Dictionary
) -> Dictionary:
	var lanes := _ChartDifficultyAnalyzer.canonical_lanes_for_notes(song_path, instrument, chart_stem)
	if not _NotesUtils.notes_exist(song_path, instrument, chart_stem, lanes):
		return {}
	var stats := SongLibrary.get_chart_difficulty_variant(song_path, instrument, chart_stem, lanes)
	if stats.is_empty():
		return {}
	var decimal_rating := _ChartDifficultyAnalyzer.decimal_rating_from_stats(stats)
	if not _matches_difficulty(decimal_rating, cfg):
		return {}
	var duration_sec := _song_duration_sec(song_path)
	if not _matches_duration(duration_sec, cfg):
		return {}
	var intent_id := _GoalDiff.intent_for(
		str(_GoalDiff.pair_from_stem(chart_stem).get("goal", _GoalDiff.DEFAULT_GOAL)),
		str(_GoalDiff.pair_from_stem(chart_stem).get("difficulty", _GoalDiff.DEFAULT_DIFFICULTY)),
	)
	return {
		"song_path": song_path,
		"instrument": instrument,
		"mode": _Intents.intent_to_legacy_mode(intent_id),
		"intent": intent_id,
		"lanes": lanes,
		"decimal_rating": decimal_rating,
		"duration_sec": duration_sec,
		"chart_stem": chart_stem,
	}


static func _pick_random_entry_for_song(
	scope: Array[Dictionary],
	song_path: String,
	rng: RandomNumberGenerator
) -> Dictionary:
	var matches: Array[Dictionary] = []
	for entry in scope:
		if str(entry.get("song_path", "")).strip_edges() != song_path:
			continue
		matches.append(entry)
	if matches.is_empty():
		return {}
	return matches[rng.randi_range(0, matches.size() - 1)]


static func _best_entry_for_song(scope: Array[Dictionary], song_path: String) -> Dictionary:
	var best: Dictionary = {}
	var best_rating := 0.0
	for entry in scope:
		if str(entry.get("song_path", "")).strip_edges() != song_path:
			continue
		var rating := float(entry.get("decimal_rating", 0.0))
		if rating > best_rating:
			best_rating = rating
			best = entry
	return best


static func pick_track_modifiers(config: Dictionary, rng: RandomNumberGenerator = null) -> Array:
	var cfg := _EndlessSessionConfig.sanitize(config)
	var policy := str(cfg.get("mod_policy", _EndlessSessionConfig.MOD_POLICY_NONE))
	match policy:
		_EndlessSessionConfig.MOD_POLICY_NONE:
			return []
		_EndlessSessionConfig.MOD_POLICY_FIXED:
			return _fixed_pool_modifiers(cfg)
		_:
			return _random_pool_modifiers(cfg, rng)


static func _collect_song_paths(cfg: Dictionary) -> Array[String]:
	var paths: Array[String] = []
	var source := str(cfg.get("track_source", _EndlessSessionConfig.TRACK_SOURCE_RANDOM))
	if source == _EndlessSessionConfig.TRACK_SOURCE_PLAYLIST:
		return _PlaylistCatalog.song_paths_for(str(cfg.get("playlist_id", "")))
	if source == _EndlessSessionConfig.TRACK_SOURCE_SELECTED:
		var manual: Variant = cfg.get("selected_song_paths", [])
		if manual is Array:
			for item in manual:
				var path := str(item).strip_edges()
				if path != "" and not paths.has(path):
					paths.append(path)
		return paths
	if SongLibrary == null or not SongLibrary.has_method("get_songs_list"):
		return paths
	var favorites_only := bool(cfg.get("random_favorites_only", false))
	for song in SongLibrary.get_songs_list():
		if song is not Dictionary:
			continue
		var path := str(song.get("path", "")).strip_edges()
		if path == "":
			continue
		if favorites_only and PlayerDataManager and not PlayerDataManager.is_song_favorite(path):
			continue
		if not _matches_genre_scope(path, cfg):
			continue
		if not paths.has(path):
			paths.append(path)
	return paths


static func _entries_for_song(song_path: String, cfg: Dictionary, instrument: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var duration_sec := _song_duration_sec(song_path)
	var seen_charts: Dictionary = {}
	for chart_stem in _allowed_chart_stems(cfg):
		var lanes := _ChartDifficultyAnalyzer.canonical_lanes_for_notes(song_path, instrument, chart_stem)
		var chart_key := "%s|%d" % [chart_stem, lanes]
		if seen_charts.has(chart_key):
			continue
		if not _NotesUtils.notes_exist(song_path, instrument, chart_stem, lanes):
			continue
		var stats := SongLibrary.get_chart_difficulty_variant(song_path, instrument, chart_stem, lanes)
		if stats.is_empty():
			continue
		var decimal_rating := _ChartDifficultyAnalyzer.decimal_rating_from_stats(stats)
		if not _matches_difficulty(decimal_rating, cfg):
			continue
		if not _matches_duration(duration_sec, cfg):
			continue
		seen_charts[chart_key] = true
		var pair := _GoalDiff.pair_from_stem(chart_stem)
		var intent_id := _GoalDiff.intent_for(
			str(pair.get("goal", _GoalDiff.DEFAULT_GOAL)),
			str(pair.get("difficulty", _GoalDiff.DEFAULT_DIFFICULTY)),
		)
		out.append({
			"song_path": song_path,
			"instrument": instrument,
			"mode": _Intents.intent_to_legacy_mode(intent_id),
			"intent": intent_id,
			"chart_stem": chart_stem,
			"lanes": lanes,
			"decimal_rating": decimal_rating,
			"duration_sec": duration_sec,
		})
	return out


static func _matches_genre_scope(song_path: String, cfg: Dictionary) -> bool:
	if str(cfg.get("genre_policy", _EndlessSessionConfig.GENRE_POLICY_ALL)) != _EndlessSessionConfig.GENRE_POLICY_GROUPS:
		return true
	var allowed: Array = cfg.get("genre_group_ids", [])
	if allowed.is_empty():
		return false
	if SongLibrary == null:
		return false
	var meta := SongLibrary.get_metadata_for_song(song_path)
	var primary := str(meta.get("primary_genre", "")).strip_edges()
	if primary != "":
		var primary_group := _ProfileGenrePortrait.map_genre_to_group(primary)
		if primary_group == "":
			primary_group = "_other"
		if allowed.has(primary_group):
			return true
	var genres: Variant = meta.get("genres", [])
	if genres is Array:
		for item in genres:
			var group_id := _ProfileGenrePortrait.map_genre_to_group(str(item))
			if group_id == "":
				group_id = "_other"
			if allowed.has(group_id):
				return true
	return false


static func _song_duration_sec(song_path: String) -> float:
	if SongLibrary == null:
		return 0.0
	var meta := SongLibrary.get_metadata_for_song(song_path)
	return _ChartDifficultyAnalyzer.parse_duration_seconds(meta.get("duration", "00:00"))


static func _allowed_chart_stems(cfg: Dictionary) -> Array[String]:
	var policy := str(cfg.get("generation_mode_policy", _EndlessSessionConfig.GEN_MODE_POLICY_ALL))
	if policy == _EndlessSessionConfig.GEN_MODE_POLICY_ALL:
		return _GoalDiff.all_stems()
	var goals := _EndlessSessionConfig.sanitize_generation_goals(cfg.get("generation_modes_allowed", []))
	if goals.is_empty():
		goals = _EndlessSessionConfig.UI_CHART_STYLE_GOALS.duplicate()
	var out: Array[String] = []
	for goal in goals:
		for difficulty in _GoalDiff.DIFFICULTIES:
			var stem := _GoalDiff.chart_stem(str(goal), str(difficulty))
			if not out.has(stem):
				out.append(stem)
	return out


static func _matches_difficulty(decimal_rating: float, cfg: Dictionary) -> bool:
	if decimal_rating <= 0.0:
		return false
	var dmin := float(cfg.get("difficulty_min", _EndlessSessionConfig.DEFAULT_DIFFICULTY_MIN))
	var dmax := float(cfg.get("difficulty_max", _EndlessSessionConfig.DEFAULT_DIFFICULTY_MAX))
	var max_over_cap := bool(cfg.get("difficulty_max_over_cap", false))
	if decimal_rating + 0.001 < dmin:
		return false
	if not max_over_cap and decimal_rating > dmax + 0.001:
		return false
	var diff_policy := str(
		cfg.get("chart_difficulty_policy", _EndlessSessionConfig.CHART_DIFFICULTY_POLICY_ALL)
	)
	if diff_policy != _EndlessSessionConfig.CHART_DIFFICULTY_POLICY_SELECTED:
		return true
	var allowed: Array = cfg.get("chart_difficulty_tiers_allowed", [])
	if allowed.is_empty():
		return true
	for tier_id in allowed:
		var tier_range := _EndlessSessionConfig.difficulty_range_for_tier(str(tier_id))
		var tier_min := float(tier_range.get("min", _EndlessSessionConfig.DIFFICULTY_BASE_MIN))
		var tier_max := float(tier_range.get("max", _EndlessSessionConfig.DIFFICULTY_BASE_MAX))
		if decimal_rating + 0.001 >= tier_min and decimal_rating <= tier_max + 0.001:
			return true
	return false


static func _matches_duration(duration_sec: float, cfg: Dictionary) -> bool:
	if duration_sec <= 0.0:
		return true
	var dmin := int(cfg.get("duration_min_sec", _EndlessSessionConfig.DEFAULT_DURATION_MIN_SEC))
	var dmax := int(cfg.get("duration_max_sec", _EndlessSessionConfig.DEFAULT_DURATION_MAX_SEC))
	var max_open := bool(cfg.get("duration_max_open", false))
	if int(duration_sec) < dmin:
		return false
	if max_open:
		return true
	return int(duration_sec) <= dmax


static func _random_pool_modifiers(cfg: Dictionary, rng: RandomNumberGenerator) -> Array:
	match str(cfg.get("mod_pick_strategy", _EndlessSessionConfig.DEFAULT_MOD_PICK_STRATEGY)):
		_EndlessSessionConfig.MOD_PICK_STRATEGY_RANDOM:
			return _random_pool_modifiers_random(cfg, rng)
		_EndlessSessionConfig.MOD_PICK_STRATEGY_FILL:
			return _random_pool_modifiers_fill(cfg, rng)
		_:
			return _random_pool_modifiers_resample(cfg, rng)


static func _random_pool_target_count(cfg: Dictionary, pool: Array) -> int:
	return mini(
		clampi(
			int(cfg.get("mod_random_count", _EndlessSessionConfig.DEFAULT_MOD_RANDOM_COUNT)),
			_EndlessSessionConfig.MOD_RANDOM_COUNT_MIN,
			_EndlessSessionConfig.MOD_RANDOM_COUNT_MAX
		),
		pool.size()
	)


static func _random_pool_modifiers_random(cfg: Dictionary, rng: RandomNumberGenerator) -> Array:
	var pool: Array = cfg.get("mod_pool", [])
	if pool.is_empty():
		return []
	var picker := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		picker.randomize()
	var target := _random_pool_target_count(cfg, pool)
	var shuffled := pool.duplicate()
	shuffled.shuffle()
	var picked: Array = shuffled.slice(0, target)
	return _RunModifiers.sanitize(picked)


static func _random_pool_modifiers_fill(cfg: Dictionary, rng: RandomNumberGenerator) -> Array:
	var pool: Array = cfg.get("mod_pool", [])
	if pool.is_empty():
		return []
	var picker := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		picker.randomize()
	var target := _random_pool_target_count(cfg, pool)
	var shuffled := pool.duplicate()
	shuffled.shuffle()
	var out: Array[String] = []
	for raw_id in shuffled:
		if out.size() >= target:
			break
		var trial: Array = out.duplicate()
		trial.append(str(raw_id))
		var sanitized := _RunModifiers.sanitize(trial)
		if sanitized.size() > out.size():
			out = sanitized
	return out


static func _random_pool_modifiers_resample(cfg: Dictionary, rng: RandomNumberGenerator) -> Array:
	var pool: Array = cfg.get("mod_pool", [])
	if pool.is_empty():
		return []
	var target := _random_pool_target_count(cfg, pool)
	var best: Array[String] = []
	for _attempt in range(_EndlessSessionConfig.MOD_PICK_RESAMPLE_ATTEMPTS):
		var trial: Array[String] = _random_pool_modifiers_random(cfg, rng)
		if trial.size() > best.size():
			best = trial
		if trial.size() >= target:
			return trial
	if best.size() >= target:
		return best
	var filled := _random_pool_modifiers_fill(cfg, rng)
	if filled.size() > best.size():
		return filled
	return best


static func _fixed_pool_modifiers(cfg: Dictionary) -> Array:
	var pool: Array = cfg.get("mod_pool", [])
	if pool.is_empty():
		return []
	return _RunModifiers.sanitize(pool)
