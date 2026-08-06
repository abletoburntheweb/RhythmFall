# logic/domain/session/marathon_route_rolls.gd
class_name MarathonRouteRolls
extends RefCounted

const _EndlessSessionConfig = preload("res://logic/domain/session/endless_session_config.gd")
const _MarathonSessionConfig = preload("res://logic/domain/session/marathon_session_config.gd")
const _MarathonRouteSetup = preload("res://logic/domain/session/marathon_route_setup.gd")

const LANES_OPTIONS: Array[int] = [3, 4, 5]
const MOD_COUNT_OPTIONS: Array[int] = [1, 2, 3]


static func apply_to_template(template: Dictionary, seed_text: String) -> Dictionary:
	var out := template.duplicate(true)
	var rng := _seeded_rng(seed_text)
	out["rolled_lanes"] = LANES_OPTIONS[rng.randi_range(0, LANES_OPTIONS.size() - 1)]
	_roll_chart_styles(out, rng)
	if not bool(out.get("mod_policy_locked", false)):
		_roll_mod_policy(out, rng)
	out = _MarathonRouteSetup.apply_to_template(out, rng)
	return out


static func config_for_route(template: Dictionary, saved: Dictionary = {}) -> Dictionary:
	var base := rolled_config(template)
	if saved.is_empty():
		return _MarathonSessionConfig.resolve_effective_run_config(base, template)
	var cfg := _MarathonSessionConfig.sanitize(saved)
	if str(cfg.get("route_id", "")).strip_edges() != str(template.get("route_id", "")).strip_edges():
		return _MarathonSessionConfig.resolve_effective_run_config(base, template)
	var locked: Dictionary = template.get("setup_locked", {}) if template.get("setup_locked") is Dictionary else {}
	if not bool(locked.get("lanes", false)):
		base["lanes"] = cfg["lanes"]
	if not bool(locked.get("track_order", false)):
		base["track_order"] = cfg["track_order"]
	if not bool(locked.get("chart_style", false)):
		base["generation_mode_policy"] = cfg["generation_mode_policy"]
		base["generation_modes_allowed"] = (cfg.get("generation_modes_allowed", []) as Array).duplicate()
	if not bool(locked.get("mods", false)) and not _MarathonSessionConfig.is_mod_policy_locked(template):
		base["mod_policy"] = cfg["mod_policy"]
		base["mod_random_count"] = cfg["mod_random_count"]
		base["mod_pool"] = (cfg.get("mod_pool", []) as Array).duplicate()
	if bool(cfg.get("instrument_locked", false)):
		base["instrument"] = cfg.get("instrument", _EndlessSessionConfig.DEFAULT_INSTRUMENT)
		base["instruments"] = (cfg.get("instruments", [base["instrument"]]) as Array).duplicate()
		base["instrument_locked"] = true
	return _MarathonSessionConfig.resolve_effective_run_config(base, template)


static func rolled_config(template: Dictionary) -> Dictionary:
	var cfg := _MarathonSessionConfig.default_config()
	cfg["route_id"] = str(template.get("route_id", "")).strip_edges()
	cfg["genre_group_id"] = str(template.get("genre_group_id", "")).strip_edges()
	if template.has("rolled_lanes"):
		cfg["lanes"] = clampi(int(template.get("rolled_lanes", 4)), 3, 5)
	if template.has("rolled_track_order"):
		var order := str(template.get("rolled_track_order", _MarathonSessionConfig.TRACK_ORDER_COURSE))
		cfg["track_order"] = order
	if template.has("rolled_mod_policy"):
		cfg["mod_policy"] = str(template.get("rolled_mod_policy", _EndlessSessionConfig.MOD_POLICY_NONE))
	if template.has("rolled_mod_random_count"):
		cfg["mod_random_count"] = int(template.get("rolled_mod_random_count", _EndlessSessionConfig.DEFAULT_MOD_RANDOM_COUNT))
	if template.get("rolled_mod_pool") is Array:
		cfg["mod_pool"] = (template.get("rolled_mod_pool") as Array).duplicate()
	if template.has("rolled_generation_mode_policy"):
		cfg["generation_mode_policy"] = str(template.get("rolled_generation_mode_policy", _EndlessSessionConfig.GEN_MODE_POLICY_ALL))
	if template.get("rolled_generation_modes_allowed") is Array:
		cfg["generation_modes_allowed"] = (template.get("rolled_generation_modes_allowed") as Array).duplicate()
	return _MarathonSessionConfig.sanitize(cfg)


static func is_challenge_archetype(archetype_id: String) -> bool:
	return _MarathonRouteSetup.is_featured_challenge(archetype_id)


static func _roll_mod_policy(out: Dictionary, rng: RandomNumberGenerator) -> void:
	if rng.randf() < 0.72:
		out["rolled_mod_policy"] = _EndlessSessionConfig.MOD_POLICY_RANDOM_POOL
		out["rolled_mod_random_count"] = MOD_COUNT_OPTIONS[rng.randi_range(0, MOD_COUNT_OPTIONS.size() - 1)]
		out["rolled_mod_pool"] = _pick_mod_pool(rng)
	else:
		out["rolled_mod_policy"] = _EndlessSessionConfig.MOD_POLICY_NONE


static func _roll_chart_styles(out: Dictionary, rng: RandomNumberGenerator) -> void:
	# Prefer wider pools so open routes are playable more often on mixed libraries.
	var roll := rng.randf()
	if roll < 0.28:
		out["rolled_generation_mode_policy"] = _EndlessSessionConfig.GEN_MODE_POLICY_SELECTED
		out["rolled_generation_modes_allowed"] = ["arcade"]
	elif roll < 0.48:
		out["rolled_generation_mode_policy"] = _EndlessSessionConfig.GEN_MODE_POLICY_SELECTED
		out["rolled_generation_modes_allowed"] = ["original"]
	elif roll < 0.72:
		out["rolled_generation_mode_policy"] = _EndlessSessionConfig.GEN_MODE_POLICY_SELECTED
		out["rolled_generation_modes_allowed"] = ["arcade", "original"]
	else:
		out["rolled_generation_mode_policy"] = _EndlessSessionConfig.GEN_MODE_POLICY_ALL
		out["rolled_generation_modes_allowed"] = []


static func _pick_mod_pool(rng: RandomNumberGenerator) -> Array[String]:
	var candidates := _MarathonSessionConfig.marathon_mod_pool_candidates()
	if candidates.is_empty():
		return []
	var count := mini(5, maxi(3, rng.randi_range(3, 5)))
	var pool := candidates.duplicate()
	pool.shuffle()
	return pool.slice(0, count)


static func _seeded_rng(seed_text: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absi(str(seed_text).hash()))
	return rng
