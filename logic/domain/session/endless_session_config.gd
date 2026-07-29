# logic/domain/session/endless_session_config.gd
class_name EndlessSessionConfig
extends RefCounted

const _ChartDifficultyAnalyzer = preload("res://logic/domain/charts/chart_difficulty_analyzer.gd")
const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const _Intents = preload("res://logic/domain/generation/generation_intents.gd")

const TRACK_SOURCE_RANDOM := "random"
const TRACK_SOURCE_SELECTED := "selected"
const TRACK_SOURCE_GENRE := "genre"
const TRACK_SOURCE_PLAYLIST := "playlist"

const CHART_DIFFICULTY_TIER_EASY := "easy"
const CHART_DIFFICULTY_TIER_MEDIUM := "medium"
const CHART_DIFFICULTY_TIER_HARD := "hard"

const ALL_CHART_DIFFICULTY_TIERS: Array[String] = [
	CHART_DIFFICULTY_TIER_EASY,
	CHART_DIFFICULTY_TIER_MEDIUM,
	CHART_DIFFICULTY_TIER_HARD,
]

const CHART_DIFFICULTY_TIER_RANGES: Dictionary = {
	CHART_DIFFICULTY_TIER_EASY: {"min": 1.0, "max": 4.0},
	CHART_DIFFICULTY_TIER_MEDIUM: {"min": 3.5, "max": 7.0},
	CHART_DIFFICULTY_TIER_HARD: {"min": 6.5, "max": 10.0},
}

## Chart goals exposed in session / marathon setup UI.
const UI_CHART_STYLE_GOALS: Array[String] = [
	"original", "arcade",
]
## Legacy alias — same ids as goals for UI toggles.
const UI_CHART_STYLE_INTENTS: Array[String] = UI_CHART_STYLE_GOALS

const SELECTED_POOL_AFTER_RESHUFFLE := "reshuffle"
const SELECTED_POOL_AFTER_EXPAND := "expand_random"
const _SELECTED_POOL_AFTER_STOP_LEGACY := "stop"

const MOD_POLICY_NONE := "none"
const MOD_POLICY_RANDOM_POOL := "random_pool"
const MOD_POLICY_FIXED := "fixed"
const _MOD_POLICY_PRESET_LEGACY := "preset"

const MOD_RANDOM_COUNT_MIN := 1
const MOD_RANDOM_COUNT_MAX := 3
const DEFAULT_MOD_RANDOM_COUNT := 2
const MOD_POOL_MIN_COUNT := 3

const MOD_PICK_STRATEGY_RESAMPLE := "resample"
const MOD_PICK_STRATEGY_FILL := "fill"
const MOD_PICK_STRATEGY_RANDOM := "random"
const DEFAULT_MOD_PICK_STRATEGY := MOD_PICK_STRATEGY_RESAMPLE
const MOD_PICK_RESAMPLE_ATTEMPTS := 12

const MOD_POOL_DEFAULT_OFF: Array[String] = [
	"reverse_scroll",
	"pick_mode",
	"combo_escalation",
	"metronome_only",
	"spotlight",
	"rush",
	"single_lane",
	"fixed_speed_20",
]

const DEFAULT_INSTRUMENT := "drums"

const GENRE_POLICY_ALL := "all"
const GENRE_POLICY_GROUPS := "groups"

const SELECTED_TRACK_PICKER_SOFT_MAX := 20
const SELECTED_TRACK_PICKER_MIN := 3

# Legacy ids kept for staged configs from older builds.
const _TRACK_SOURCE_LIBRARY_LEGACY := "library"
const _TRACK_SOURCE_FAVORITES_LEGACY := "favorites"

const DIFFICULTY_BASE_MIN := 1.0
const DIFFICULTY_BASE_MAX := 10.0
const DIFFICULTY_EFFECTIVE_MAX := 20.0
const DIFFICULTY_STEP := 0.5
const DEFAULT_DIFFICULTY_MIN := 2.0
const DEFAULT_DIFFICULTY_MAX := 8.0

const GEN_MODE_POLICY_ALL := "all"
const GEN_MODE_POLICY_SELECTED := "selected"

const CHART_DIFFICULTY_POLICY_ALL := "all"
const CHART_DIFFICULTY_POLICY_SELECTED := "selected"

const INTER_TRACK_HP_RECOVERY_OPTIONS: Array[int] = [0, 20, 40, 60, 80, 100]
const DEFAULT_INTER_TRACK_HP_RECOVERY_PCT := 100

const ALL_GENERATION_INTENTS: Array[String] = [
	"original", "groove", "arcade", "sparse",
]

# Legacy alias — use ALL_GENERATION_INTENTS.
const ALL_GENERATION_MODES: Array[String] = ALL_GENERATION_INTENTS

const DEFAULT_DURATION_MIN_SEC := 90
const DEFAULT_DURATION_MAX_SEC := 360
const DURATION_SLIDER_MIN_SEC := 60
const DURATION_SLIDER_MAX_SEC := 360
const DURATION_STEP_SEC := 30


static func is_valid_track_source(source: String) -> bool:
	return source in [
		TRACK_SOURCE_RANDOM,
		TRACK_SOURCE_SELECTED,
		TRACK_SOURCE_GENRE,
		TRACK_SOURCE_PLAYLIST,
	]


static func is_valid_selected_pool_after(policy: String) -> bool:
	return (
		policy == SELECTED_POOL_AFTER_RESHUFFLE
		or policy == SELECTED_POOL_AFTER_EXPAND
	)


static func normalize_selected_pool_after(policy: String) -> String:
	var normalized := str(policy).strip_edges()
	if normalized == _SELECTED_POOL_AFTER_STOP_LEGACY:
		return SELECTED_POOL_AFTER_RESHUFFLE
	if is_valid_selected_pool_after(normalized):
		return normalized
	return SELECTED_POOL_AFTER_RESHUFFLE


static func is_valid_mod_pick_strategy(strategy: String) -> bool:
	return strategy in [
		MOD_PICK_STRATEGY_RESAMPLE,
		MOD_PICK_STRATEGY_FILL,
		MOD_PICK_STRATEGY_RANDOM,
	]


static func normalize_mod_pick_strategy(strategy: String) -> String:
	var normalized := str(strategy).strip_edges()
	if is_valid_mod_pick_strategy(normalized):
		return normalized
	return DEFAULT_MOD_PICK_STRATEGY


static func mod_pick_strategy_label_key(strategy: String) -> String:
	match normalize_mod_pick_strategy(strategy):
		MOD_PICK_STRATEGY_FILL:
			return "SESSION_SETUP_MOD_PICK_FILL"
		MOD_PICK_STRATEGY_RANDOM:
			return "SESSION_SETUP_MOD_PICK_RANDOM"
		_:
			return "SESSION_SETUP_MOD_PICK_RESAMPLE"


static func is_valid_mod_policy(policy: String) -> bool:
	return (
		policy == MOD_POLICY_NONE
		or policy == MOD_POLICY_RANDOM_POOL
		or policy == MOD_POLICY_FIXED
	)


static func normalize_mod_policy(policy: String) -> String:
	var normalized := str(policy).strip_edges()
	if normalized == _MOD_POLICY_PRESET_LEGACY:
		return MOD_POLICY_FIXED
	if is_valid_mod_policy(normalized):
		return normalized
	return MOD_POLICY_RANDOM_POOL


static func is_valid_gen_mode_policy(policy: String) -> bool:
	return policy == GEN_MODE_POLICY_ALL or policy == GEN_MODE_POLICY_SELECTED


static func is_valid_chart_difficulty_policy(policy: String) -> bool:
	return policy == CHART_DIFFICULTY_POLICY_ALL or policy == CHART_DIFFICULTY_POLICY_SELECTED


static func normalize_chart_difficulty_policy(policy: String) -> String:
	var normalized := str(policy).strip_edges()
	if is_valid_chart_difficulty_policy(normalized):
		return normalized
	return CHART_DIFFICULTY_POLICY_ALL


static func normalize_inter_track_hp_recovery_pct(value: Variant) -> int:
	var pct := int(value)
	if INTER_TRACK_HP_RECOVERY_OPTIONS.has(pct):
		return pct
	var closest := DEFAULT_INTER_TRACK_HP_RECOVERY_PCT
	var best_dist := 999
	for option in INTER_TRACK_HP_RECOVERY_OPTIONS:
		var dist := absi(option - pct)
		if dist < best_dist:
			best_dist = dist
			closest = option
	return closest


static func format_inter_track_hp_recovery_pct(pct: int) -> String:
	return "%d%%" % normalize_inter_track_hp_recovery_pct(pct)


static func is_valid_genre_policy(policy: String) -> bool:
	return policy == GENRE_POLICY_ALL or policy == GENRE_POLICY_GROUPS


static func is_valid_instrument(instrument: String) -> bool:
	return instrument == DEFAULT_INSTRUMENT or instrument == "bass"


static func sanitize_instruments(raw: Variant) -> Array:
	var out: Array = []
	var source: Array = []
	if raw is Array:
		source = raw as Array
	elif str(raw).strip_edges() != "":
		source = [raw]
	for item in source:
		var inst := str(item).strip_edges().to_lower()
		if inst == "standard":
			inst = DEFAULT_INSTRUMENT
		if is_valid_instrument(inst) and not out.has(inst):
			out.append(inst)
	if out.is_empty():
		out.append(DEFAULT_INSTRUMENT)
	return out


static func instruments_from_config(config: Dictionary, override: String = "") -> Array:
	var forced := str(override).strip_edges().to_lower()
	if forced != "":
		if forced == "standard":
			forced = DEFAULT_INSTRUMENT
		return sanitize_instruments([forced])
	if config.has("instruments"):
		return sanitize_instruments(config.get("instruments", []))
	return sanitize_instruments([config.get("instrument", DEFAULT_INSTRUMENT)])


static func normalize_track_source(source: String) -> String:
	match str(source).strip_edges():
		_TRACK_SOURCE_LIBRARY_LEGACY, _TRACK_SOURCE_FAVORITES_LEGACY:
			return TRACK_SOURCE_RANDOM
		TRACK_SOURCE_GENRE:
			# Legacy: «по жанрам» объединён с «библиотека» + фильтр групп жанров.
			return TRACK_SOURCE_RANDOM
		TRACK_SOURCE_SELECTED:
			return TRACK_SOURCE_SELECTED
		TRACK_SOURCE_PLAYLIST:
			return TRACK_SOURCE_PLAYLIST
		_:
			return TRACK_SOURCE_RANDOM


static func is_track_source_playable(source: String) -> bool:
	return is_valid_track_source(normalize_track_source(source))


static func chart_difficulty_tier_label_key(tier_id: String) -> String:
	match str(tier_id).strip_edges():
		CHART_DIFFICULTY_TIER_EASY:
			return "SESSION_CHART_DIFFICULTY_EASY"
		CHART_DIFFICULTY_TIER_HARD:
			return "SESSION_CHART_DIFFICULTY_HARD"
		_:
			return "SESSION_CHART_DIFFICULTY_MEDIUM"


static func normalize_chart_difficulty_tier(tier: String) -> String:
	var key := str(tier).strip_edges()
	if ALL_CHART_DIFFICULTY_TIERS.has(key):
		return key
	return CHART_DIFFICULTY_TIER_MEDIUM


static func difficulty_range_for_tier(tier: String) -> Dictionary:
	var key := normalize_chart_difficulty_tier(tier)
	var raw: Variant = CHART_DIFFICULTY_TIER_RANGES.get(key, {})
	if raw is Dictionary:
		return raw
	return CHART_DIFFICULTY_TIER_RANGES[CHART_DIFFICULTY_TIER_MEDIUM].duplicate(true)


static func default_mod_pool() -> Array[String]:
	var out: Array[String] = []
	for mod_id in session_mod_pool_candidates():
		if MOD_POOL_DEFAULT_OFF.has(mod_id):
			continue
		out.append(mod_id)
	return out


static func mod_pool_min_size() -> int:
	return MOD_POOL_MIN_COUNT


static func session_mod_pool_candidates() -> Array[String]:
	var out: Array[String] = []
	for mod_id in _RunModifiers.ALL_IDS:
		if _is_allowed_in_session_pool(str(mod_id)):
			out.append(str(mod_id))
	return out


static func _is_allowed_in_session_pool(mod_id: String) -> bool:
	if not _RunModifiers.ALL_IDS.has(mod_id):
		return false
	match mod_id:
		_RunModifiers.ID_NO_FAIL, _RunModifiers.ID_AUTOPLAY:
			return false
		_RunModifiers.ID_SUDDEN_DEATH, _RunModifiers.ID_LAST_CHANCE:
			return false
		_:
			return not _RunModifiers.DNA_IDS.has(mod_id)


static func default_config() -> Dictionary:
	return {
		"mode_id": PlayModeIds.ENDLESS,
		"track_source": TRACK_SOURCE_RANDOM,
		"random_favorites_only": false,
		"genre_policy": GENRE_POLICY_ALL,
		"genre_group_ids": [],
		"selected_song_paths": [],
		"instrument": DEFAULT_INSTRUMENT,
		"instruments": [DEFAULT_INSTRUMENT],
		"difficulty_min": DEFAULT_DIFFICULTY_MIN,
		"difficulty_max": DEFAULT_DIFFICULTY_MAX,
		"difficulty_max_over_cap": false,
		"mod_policy": MOD_POLICY_RANDOM_POOL,
		"mod_pool": default_mod_pool(),
		"mod_random_count": DEFAULT_MOD_RANDOM_COUNT,
		"mod_pick_strategy": DEFAULT_MOD_PICK_STRATEGY,
		"mod_preset_slot": 0,
		"generation_mode_policy": GEN_MODE_POLICY_ALL,
		"generation_modes_allowed": [],
		"chart_difficulty_policy": CHART_DIFFICULTY_POLICY_ALL,
		"chart_difficulty_tiers_allowed": ALL_CHART_DIFFICULTY_TIERS.duplicate(),
		"chart_difficulty_tier": CHART_DIFFICULTY_TIER_MEDIUM,
		"inter_track_hp_recovery_pct": DEFAULT_INTER_TRACK_HP_RECOVERY_PCT,
		"duration_min_sec": DEFAULT_DURATION_MIN_SEC,
		"duration_max_sec": DEFAULT_DURATION_MAX_SEC,
		"duration_max_open": false,
		"selected_pool_after": SELECTED_POOL_AFTER_RESHUFFLE,
		"unique_songs_only": false,
		"playlist_id": "favorites",
	}


static func sanitize(config: Dictionary) -> Dictionary:
	var out := default_config()
	if config is Dictionary:
		var mode_id := str(config.get("mode_id", PlayModeIds.ENDLESS)).strip_edges()
		if mode_id == PlayModeIds.ENDLESS:
			out["mode_id"] = mode_id
		out["track_source"] = normalize_track_source(str(config.get("track_source", TRACK_SOURCE_RANDOM)))
		var raw_track_source := str(config.get("track_source", TRACK_SOURCE_RANDOM)).strip_edges()
		var legacy_genre_source := raw_track_source == TRACK_SOURCE_GENRE
		out["random_favorites_only"] = bool(config.get("random_favorites_only", false))
		if out["track_source"] != TRACK_SOURCE_RANDOM:
			out["random_favorites_only"] = false
		out["playlist_id"] = _normalize_playlist_id(
			str(config.get("playlist_id", "favorites")),
			str(out.get("track_source", TRACK_SOURCE_RANDOM))
		)
		if out["track_source"] != TRACK_SOURCE_PLAYLIST:
			out["playlist_id"] = "favorites"
		var genre_policy := str(config.get("genre_policy", GENRE_POLICY_ALL)).strip_edges()
		if legacy_genre_source:
			out["genre_policy"] = GENRE_POLICY_GROUPS
		elif is_valid_genre_policy(genre_policy):
			out["genre_policy"] = genre_policy
		out["genre_group_ids"] = _sanitize_genre_group_ids(config.get("genre_group_ids", []))
		if out["genre_policy"] == GENRE_POLICY_ALL:
			out["genre_group_ids"] = []
		out["selected_song_paths"] = _sanitize_selected_song_paths(config.get("selected_song_paths", []))
		out["instruments"] = sanitize_instruments(
			config.get("instruments", [config.get("instrument", DEFAULT_INSTRUMENT)])
		)
		out["instrument"] = str(out["instruments"][0])
		var legacy_tier := normalize_chart_difficulty_tier(
			str(config.get("chart_difficulty_tier", CHART_DIFFICULTY_TIER_MEDIUM))
		)
		var diff_policy_raw := str(config.get("chart_difficulty_policy", "")).strip_edges()
		if diff_policy_raw == "":
			diff_policy_raw = CHART_DIFFICULTY_POLICY_ALL
		out["chart_difficulty_policy"] = normalize_chart_difficulty_policy(diff_policy_raw)
		out["chart_difficulty_tiers_allowed"] = _sanitize_chart_difficulty_tiers(
			config.get("chart_difficulty_tiers_allowed", []),
			legacy_tier,
			str(out.get("chart_difficulty_policy", CHART_DIFFICULTY_POLICY_ALL))
		)
		out["chart_difficulty_tier"] = (
			out["chart_difficulty_tiers_allowed"][0]
			if not (out["chart_difficulty_tiers_allowed"] as Array).is_empty()
			else legacy_tier
		)
		out["inter_track_hp_recovery_pct"] = normalize_inter_track_hp_recovery_pct(
			config.get("inter_track_hp_recovery_pct", DEFAULT_INTER_TRACK_HP_RECOVERY_PCT)
		)
		var dmin := _snap_base_difficulty(float(config.get("difficulty_min", DEFAULT_DIFFICULTY_MIN)))
		var dmax := _snap_base_difficulty(float(config.get("difficulty_max", DEFAULT_DIFFICULTY_MAX)))
		var max_over_cap := bool(config.get("difficulty_max_over_cap", false))
		if dmax > DIFFICULTY_BASE_MAX or max_over_cap:
			dmax = DIFFICULTY_BASE_MAX
			max_over_cap = true
		if dmin > dmax:
			var swap := dmin
			dmin = dmax
			dmax = swap
		if dmax < DIFFICULTY_BASE_MAX:
			max_over_cap = false
		out["difficulty_min"] = dmin
		out["difficulty_max"] = dmax
		out["difficulty_max_over_cap"] = max_over_cap
		out["mod_policy"] = normalize_mod_policy(str(config.get("mod_policy", MOD_POLICY_RANDOM_POOL)))
		out["mod_pool"] = _sanitize_mod_pool(config.get("mod_pool", default_mod_pool()), false)
		if out["mod_policy"] == MOD_POLICY_RANDOM_POOL:
			out["mod_pool"] = _ensure_mod_pool_valid(out["mod_pool"])
		elif out["mod_policy"] == MOD_POLICY_FIXED and out["mod_pool"].is_empty():
			out["mod_pool"] = default_mod_pool()
		out["mod_random_count"] = clampi(
			int(config.get("mod_random_count", DEFAULT_MOD_RANDOM_COUNT)),
			MOD_RANDOM_COUNT_MIN,
			MOD_RANDOM_COUNT_MAX
		)
		out["mod_pick_strategy"] = normalize_mod_pick_strategy(
			str(config.get("mod_pick_strategy", DEFAULT_MOD_PICK_STRATEGY))
		)
		if out["mod_policy"] == MOD_POLICY_NONE:
			out["mod_pool"] = []
		out["mod_preset_slot"] = clampi(int(config.get("mod_preset_slot", 0)), 0, 10)
		var gen_policy := str(config.get("generation_mode_policy", GEN_MODE_POLICY_ALL)).strip_edges()
		if is_valid_gen_mode_policy(gen_policy):
			out["generation_mode_policy"] = gen_policy
		out["generation_modes_allowed"] = _sanitize_generation_modes(config.get("generation_modes_allowed", []))
		if out["generation_mode_policy"] == GEN_MODE_POLICY_ALL:
			out["generation_modes_allowed"] = []
		elif (out["generation_modes_allowed"] as Array).is_empty():
			out["generation_modes_allowed"] = ["original", "arcade"]
		var dur_min := clampi(int(config.get("duration_min_sec", DEFAULT_DURATION_MIN_SEC)), DURATION_SLIDER_MIN_SEC, DURATION_SLIDER_MAX_SEC)
		var dur_max := clampi(int(config.get("duration_max_sec", DEFAULT_DURATION_MAX_SEC)), DURATION_SLIDER_MIN_SEC, DURATION_SLIDER_MAX_SEC)
		var dur_max_open := bool(config.get("duration_max_open", false))
		if dur_max_open:
			dur_max = DURATION_SLIDER_MAX_SEC
		if dur_min > dur_max:
			var swap_d := dur_min
			dur_min = dur_max
			dur_max = swap_d
		out["duration_min_sec"] = dur_min
		out["duration_max_sec"] = dur_max
		out["duration_max_open"] = dur_max_open
		out["selected_pool_after"] = normalize_selected_pool_after(
			str(config.get("selected_pool_after", SELECTED_POOL_AFTER_RESHUFFLE))
		)
		if out["track_source"] != TRACK_SOURCE_SELECTED:
			out["selected_pool_after"] = SELECTED_POOL_AFTER_RESHUFFLE
		out["unique_songs_only"] = bool(config.get("unique_songs_only", false))
	return out


static func _normalize_playlist_id(playlist_id: String, track_source: String) -> String:
	if str(track_source).strip_edges() != TRACK_SOURCE_PLAYLIST:
		return "favorites"
	const PlaylistCatalog = preload("res://logic/domain/library/playlist_catalog.gd")
	return PlaylistCatalog.normalize_playlist_id(playlist_id)


static func _sanitize_genre_group_ids(raw: Variant) -> Array[String]:
	var allowed := ProfileGenrePortrait.all_group_ids()
	var out: Array[String] = []
	if raw is Array:
		for item in raw:
			var group_id := str(item).strip_edges().to_lower()
			if group_id == "" or not allowed.has(group_id):
				continue
			if out.has(group_id):
				continue
			out.append(group_id)
	return out


static func _sanitize_chart_difficulty_tiers(raw: Variant, legacy_tier: String, policy: String) -> Array[String]:
	if str(policy) != CHART_DIFFICULTY_POLICY_SELECTED:
		return []
	var out: Array[String] = []
	if raw is Array:
		for item in raw:
			var tier_id := normalize_chart_difficulty_tier(str(item))
			if not out.has(tier_id):
				out.append(tier_id)
	if out.is_empty():
		var fallback := normalize_chart_difficulty_tier(legacy_tier)
		out.append(fallback)
	return out


static func _sanitize_selected_song_paths(raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if raw is Array:
		for item in raw:
			var path := str(item).strip_edges()
			if path == "" or out.has(path):
				continue
			out.append(path)
			if out.size() >= SELECTED_TRACK_PICKER_SOFT_MAX:
				break
	return out


static func _sanitize_generation_modes(raw: Variant) -> Array[String]:
	return sanitize_generation_goals(raw)


## Map legacy intents / modes to session chart goals (original|arcade).
static func sanitize_generation_goals(raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if raw is Array or raw is PackedStringArray:
		for item in raw:
			var goal := generation_goal_from_legacy_id(str(item))
			if goal == "":
				continue
			if out.has(goal):
				continue
			out.append(goal)
	return out


static func generation_goal_from_legacy_id(raw_id: String) -> String:
	var key := normalize_generation_intent_id(raw_id)
	if key == "":
		return ""
	match key:
		"original", "sparse":
			return "original"
		"arcade", "groove":
			return "arcade"
		_:
			if key in UI_CHART_STYLE_GOALS:
				return key
			return ""


static func normalize_generation_intent_id(raw_id: String) -> String:
	var key := raw_id.strip_edges().to_lower()
	if key in UI_CHART_STYLE_GOALS:
		return key
	if key in ALL_GENERATION_INTENTS:
		return key
	return _Intents.migrate_legacy_mode(key)


static func is_locked_generation_intent(intent_id: String) -> bool:
	return _Intents.is_locked(intent_id)


static func _sanitize_mod_pool(raw: Variant, refill_if_empty: bool = true) -> Array[String]:
	var allowed := session_mod_pool_candidates()
	var out: Array[String] = []
	if raw is Array:
		for item in raw:
			var mod_id := str(item).strip_edges()
			if mod_id == "" or not allowed.has(mod_id):
				continue
			if out.has(mod_id):
				continue
			out.append(mod_id)
	if out.is_empty() and refill_if_empty and allowed.size() > 0:
		return default_mod_pool()
	return out


static func _ensure_mod_pool_valid(pool: Array[String]) -> Array[String]:
	var candidates := session_mod_pool_candidates()
	var out: Array[String] = []
	for mod_id in pool:
		if candidates.has(mod_id) and not out.has(mod_id):
			out.append(mod_id)
	if out.is_empty():
		return candidates.duplicate()
	var min_size := mod_pool_min_size()
	if out.size() < min_size:
		for mod_id in candidates:
			if out.size() >= min_size:
				break
			if not out.has(mod_id):
				out.append(mod_id)
	return out


static func _snap_base_difficulty(value: float) -> float:
	return clampf(
		snappedf(value, DIFFICULTY_STEP),
		DIFFICULTY_BASE_MIN,
		DIFFICULTY_BASE_MAX
	)


static func format_difficulty_value(value: float, over_cap: bool = false) -> String:
	if over_cap and value >= DIFFICULTY_BASE_MAX - 0.001:
		return "10+"
	if value <= 0.0:
		return "—"
	return _ChartDifficultyAnalyzer.format_compact_rating(snappedf(value, 0.1))


static func format_difficulty_range(min_value: float, max_value: float, max_over_cap: bool = false) -> String:
	return "%s – %s" % [
		format_difficulty_value(min_value),
		format_difficulty_value(max_value, max_over_cap),
	]


static func format_duration_sec(sec: int, open_ended: bool = false) -> String:
	if open_ended and sec >= DURATION_SLIDER_MAX_SEC:
		return "6:00+"
	var safe_sec := maxi(0, sec)
	return "%d:%02d" % [safe_sec / 60, safe_sec % 60]


static func format_duration_range(min_sec: int, max_sec: int, max_open: bool = false) -> String:
	return "%s – %s" % [
		format_duration_sec(min_sec),
		format_duration_sec(max_sec, max_open),
	]


static func generation_intent_label_key(intent_id: String) -> String:
	var goal := generation_goal_from_legacy_id(str(intent_id))
	if goal == "original":
		return "GEN_GOAL_ORIGINAL"
	if goal == "arcade":
		return "GEN_GOAL_ARCADE"
	var key := normalize_generation_intent_id(str(intent_id))
	if key in ALL_GENERATION_INTENTS:
		return "GEN_INTENT_%s" % key.to_upper()
	return "GEN_GOAL_ORIGINAL"


static func generation_mode_label_key(mode_id: String) -> String:
	return generation_intent_label_key(mode_id)


static func preview_generation_modes_text(policy: String, allowed: Array) -> String:
	if str(policy) == GEN_MODE_POLICY_ALL:
		return TranslationServer.translate("SESSION_SETUP_GEN_MODE_ALL")
	var goals := sanitize_generation_goals(allowed)
	var parts: PackedStringArray = []
	for goal_id in UI_CHART_STYLE_GOALS:
		if goals.has(goal_id):
			parts.append(TranslationServer.translate(generation_intent_label_key(goal_id)))
	if parts.is_empty():
		return TranslationServer.translate("SESSION_SETUP_GEN_MODE_NONE")
	return ", ".join(parts)


static func track_source_label_key(source: String) -> String:
	match normalize_track_source(source):
		TRACK_SOURCE_SELECTED:
			return "SESSION_SETUP_SOURCE_SELECTED"
		TRACK_SOURCE_GENRE:
			return "SESSION_SETUP_SOURCE_GENRE"
		TRACK_SOURCE_PLAYLIST:
			return "SESSION_SETUP_SOURCE_PLAYLISTS"
		_:
			return "SESSION_SETUP_SOURCE_LIBRARY"


static func preview_playlist_text(playlist_id: String) -> String:
	const PlaylistCatalog = preload("res://logic/domain/library/playlist_catalog.gd")
	var pid := str(playlist_id).strip_edges()
	if pid == "":
		return TranslationServer.translate("SESSION_SETUP_PLAYLIST_NONE")
	return PlaylistCatalog.display_name(pid)


static func preview_source_text(source: String, favorites_only: bool = false) -> String:
	var base := TranslationServer.translate(track_source_label_key(source))
	if normalize_track_source(source) == TRACK_SOURCE_RANDOM and favorites_only:
		return "%s · %s" % [
			base,
			TranslationServer.translate("SESSION_SETUP_RANDOM_FAVORITES_SHORT"),
		]
	return base


static func preview_chart_difficulty_tiers_text(diff_policy: String, tiers: Array) -> String:
	if str(diff_policy) != CHART_DIFFICULTY_POLICY_SELECTED:
		return TranslationServer.translate("SESSION_CHART_DIFFICULTY_ALL")
	var parts: PackedStringArray = []
	for tier_id in ALL_CHART_DIFFICULTY_TIERS:
		if tiers.has(tier_id):
			parts.append(TranslationServer.translate(chart_difficulty_tier_label_key(tier_id)))
	if parts.is_empty():
		return TranslationServer.translate("SESSION_CHART_DIFFICULTY_NONE")
	return ", ".join(parts)


static func preview_chart_style_text(
	policy: String,
	allowed: Array,
	diff_policy: String = CHART_DIFFICULTY_POLICY_ALL,
	tiers: Array = []
) -> String:
	var style_part := preview_generation_modes_text(policy, allowed)
	var tier_part := preview_chart_difficulty_tiers_text(diff_policy, tiers)
	return "%s · %s" % [style_part, tier_part]


static func preview_genre_text(policy: String, group_ids: Array) -> String:
	if str(policy) != GENRE_POLICY_GROUPS:
		return TranslationServer.translate("SESSION_SETUP_GENRE_ALL")
	if group_ids.is_empty():
		return TranslationServer.translate("SESSION_SETUP_GENRE_NONE")
	var parts: PackedStringArray = []
	for group_id in group_ids:
		parts.append(TranslationServer.translate(ProfileGenrePortrait.group_locale_key(str(group_id))))
	return ", ".join(parts)


static func preview_instrument_text(instrument_or_pool: Variant) -> String:
	var pool := sanitize_instruments(instrument_or_pool)
	if pool.size() >= 2:
		return TranslationServer.translate("SESSION_SETUP_INSTRUMENTS_BOTH")
	match str(pool[0]):
		"bass":
			return TranslationServer.translate("GEN_INST_BASS")
		_:
			return TranslationServer.translate("GEN_INST_DRUMS")


static func mod_policy_label_key(policy: String) -> String:
	match str(policy):
		MOD_POLICY_RANDOM_POOL:
			return "SESSION_SETUP_MOD_POLICY_RANDOM"
		MOD_POLICY_FIXED:
			return "SESSION_SETUP_MOD_POLICY_FIXED"
		_:
			return "SESSION_SETUP_MOD_POLICY_NONE"


static func selected_pool_after_label_key(policy: String) -> String:
	match normalize_selected_pool_after(policy):
		SELECTED_POOL_AFTER_EXPAND:
			return "SESSION_SETUP_POOL_AFTER_EXPAND"
		_:
			return "SESSION_SETUP_POOL_AFTER_RESHUFFLE"
