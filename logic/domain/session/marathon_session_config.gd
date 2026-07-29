# logic/domain/session/marathon_session_config.gd
class_name MarathonSessionConfig
extends RefCounted

const _EndlessSessionConfig = preload("res://logic/domain/session/endless_session_config.gd")
const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const _PlayModeIds = preload("res://logic/domain/session/play_mode_ids.gd")

const TRACK_ORDER_COURSE := "course"
const TRACK_ORDER_RANDOM := "random"

const MOD_POOL_MIN_COUNT := 3
const MOD_REWARD_BONUS_PER_EXTRA := 0.15


static func default_config() -> Dictionary:
	return {
		"mode_id": _PlayModeIds.MARATHON,
		"genre_group_id": "",
		"route_id": "",
		"lanes": 4,
		"track_order": TRACK_ORDER_COURSE,
		"instrument": _EndlessSessionConfig.DEFAULT_INSTRUMENT,
		"instruments": [_EndlessSessionConfig.DEFAULT_INSTRUMENT],
		"instrument_locked": false,
		"mod_policy": _EndlessSessionConfig.MOD_POLICY_NONE,
		"mod_pool": default_mod_pool(),
		"mod_random_count": _EndlessSessionConfig.DEFAULT_MOD_RANDOM_COUNT,
		"mod_pick_strategy": _EndlessSessionConfig.DEFAULT_MOD_PICK_STRATEGY,
		"mod_preset_slot": 0,
		"generation_mode_policy": _EndlessSessionConfig.GEN_MODE_POLICY_ALL,
		"generation_modes_allowed": [],
		"chart_difficulty_policy": _EndlessSessionConfig.CHART_DIFFICULTY_POLICY_ALL,
		"chart_difficulty_tiers_allowed": _EndlessSessionConfig.ALL_CHART_DIFFICULTY_TIERS.duplicate(),
		"chart_difficulty_tier": _EndlessSessionConfig.CHART_DIFFICULTY_TIER_MEDIUM,
	}


static func marathon_mod_pool_candidates() -> Array[String]:
	var out: Array[String] = []
	for mod_id in _EndlessSessionConfig.session_mod_pool_candidates():
		if _RunModifiers.EASING_IDS.has(mod_id):
			continue
		out.append(mod_id)
	return out


static func default_mod_pool() -> Array[String]:
	var out: Array[String] = []
	for mod_id in marathon_mod_pool_candidates():
		if _EndlessSessionConfig.MOD_POOL_DEFAULT_OFF.has(mod_id):
			continue
		out.append(mod_id)
	return out


static func mod_reward_multiplier(config: Dictionary) -> float:
	var policy := str(sanitize(config).get("mod_policy", _EndlessSessionConfig.MOD_POLICY_NONE))
	if policy == _EndlessSessionConfig.MOD_POLICY_NONE:
		return 1.0
	var count := clampi(
		int(config.get("mod_random_count", _EndlessSessionConfig.DEFAULT_MOD_RANDOM_COUNT)),
		_EndlessSessionConfig.MOD_RANDOM_COUNT_MIN,
		_EndlessSessionConfig.MOD_RANDOM_COUNT_MAX
	)
	return 1.0 + MOD_REWARD_BONUS_PER_EXTRA * float(count - 1)


static func sanitize(config: Dictionary) -> Dictionary:
	var base := _EndlessSessionConfig.sanitize(config)
	var out := default_config()
	out["mode_id"] = _PlayModeIds.MARATHON
	out["genre_group_id"] = str(config.get("genre_group_id", "")).strip_edges()
	out["route_id"] = str(config.get("route_id", "")).strip_edges()
	out["lanes"] = clampi(int(config.get("lanes", 4)), 3, 5)
	var track_order := str(config.get("track_order", TRACK_ORDER_COURSE)).strip_edges()
	out["track_order"] = TRACK_ORDER_RANDOM if track_order == TRACK_ORDER_RANDOM else TRACK_ORDER_COURSE
	out["mod_policy"] = str(base.get("mod_policy", _EndlessSessionConfig.MOD_POLICY_NONE))
	out["mod_random_count"] = clampi(
		int(base.get("mod_random_count", _EndlessSessionConfig.DEFAULT_MOD_RANDOM_COUNT)),
		_EndlessSessionConfig.MOD_RANDOM_COUNT_MIN,
		_EndlessSessionConfig.MOD_RANDOM_COUNT_MAX
	)
	out["mod_pick_strategy"] = str(base.get("mod_pick_strategy", _EndlessSessionConfig.DEFAULT_MOD_PICK_STRATEGY))
	out["mod_preset_slot"] = int(base.get("mod_preset_slot", 0))
	out["generation_mode_policy"] = str(base.get("generation_mode_policy", _EndlessSessionConfig.GEN_MODE_POLICY_ALL))
	out["generation_modes_allowed"] = base.get("generation_modes_allowed", [])
	out["chart_difficulty_policy"] = str(
		base.get("chart_difficulty_policy", _EndlessSessionConfig.CHART_DIFFICULTY_POLICY_ALL)
	)
	out["chart_difficulty_tiers_allowed"] = base.get("chart_difficulty_tiers_allowed", [])
	out["chart_difficulty_tier"] = str(base.get("chart_difficulty_tier", _EndlessSessionConfig.CHART_DIFFICULTY_TIER_MEDIUM))
	out["instruments"] = _EndlessSessionConfig.sanitize_instruments(
		config.get("instruments", [config.get("instrument", base.get("instrument", _EndlessSessionConfig.DEFAULT_INSTRUMENT))])
	)
	out["instrument"] = str(out["instruments"][0]) if not out["instruments"].is_empty() else _EndlessSessionConfig.DEFAULT_INSTRUMENT
	out["instrument_locked"] = bool(config.get("instrument_locked", false))
	if out["mod_policy"] == _EndlessSessionConfig.MOD_POLICY_RANDOM_POOL:
		out["mod_pool"] = _sanitize_mod_pool(config.get("mod_pool", default_mod_pool()))
	elif out["mod_policy"] == _EndlessSessionConfig.MOD_POLICY_FIXED:
		out["mod_pool"] = _sanitize_fixed_mod_pool(config.get("mod_pool", []))
	else:
		out["mod_pool"] = []
	return out


static func is_mod_policy_locked(template: Dictionary) -> bool:
	return bool(template.get("mod_policy_locked", false))


static func resolve_effective_run_config(run_config: Dictionary, template: Dictionary) -> Dictionary:
	var cfg := resolve_effective_mod_config(run_config, template)
	var locked: Variant = template.get("setup_locked", {})
	if not locked is Dictionary:
		return cfg
	var locks := locked as Dictionary
	if bool(locks.get("lanes", false)) and template.has("rolled_lanes"):
		cfg["lanes"] = clampi(int(template.get("rolled_lanes", cfg.get("lanes", 4))), 3, 5)
	if bool(locks.get("track_order", false)) and template.has("rolled_track_order"):
		var order := str(template.get("rolled_track_order", TRACK_ORDER_COURSE)).strip_edges()
		cfg["track_order"] = TRACK_ORDER_RANDOM if order == TRACK_ORDER_RANDOM else TRACK_ORDER_COURSE
	if bool(locks.get("chart_style", false)):
		if template.has("rolled_generation_mode_policy"):
			cfg["generation_mode_policy"] = str(
				template.get("rolled_generation_mode_policy", _EndlessSessionConfig.GEN_MODE_POLICY_ALL)
			)
		if template.get("rolled_generation_modes_allowed") is Array:
			cfg["generation_modes_allowed"] = (template.get("rolled_generation_modes_allowed") as Array).duplicate()
	return sanitize(cfg)


static func is_setup_field_locked(template: Dictionary, field_id: String) -> bool:
	var locked: Variant = template.get("setup_locked", {})
	if not locked is Dictionary:
		return false
	return bool((locked as Dictionary).get(field_id, false))


static func resolve_effective_mod_config(run_config: Dictionary, template: Dictionary) -> Dictionary:
	var cfg := sanitize(run_config)
	if not is_mod_policy_locked(template):
		return cfg
	var fixed := _sanitize_fixed_mod_pool(template.get("fixed_modifiers", []))
	if not fixed.is_empty():
		cfg["mod_policy"] = _EndlessSessionConfig.MOD_POLICY_FIXED
		cfg["mod_pool"] = fixed
		return sanitize(cfg)
	var policy := str(template.get("mod_policy", _EndlessSessionConfig.MOD_POLICY_NONE)).strip_edges()
	if _EndlessSessionConfig.is_valid_mod_policy(policy):
		cfg["mod_policy"] = policy
	if cfg["mod_policy"] == _EndlessSessionConfig.MOD_POLICY_RANDOM_POOL:
		cfg["mod_pool"] = _sanitize_mod_pool(template.get("mod_pool", cfg.get("mod_pool", default_mod_pool())))
		cfg["mod_random_count"] = clampi(
			int(template.get("mod_random_count", cfg.get("mod_random_count", _EndlessSessionConfig.DEFAULT_MOD_RANDOM_COUNT))),
			_EndlessSessionConfig.MOD_RANDOM_COUNT_MIN,
			_EndlessSessionConfig.MOD_RANDOM_COUNT_MAX
		)
	return sanitize(cfg)


static func sanitize_fixed_modifiers(raw: Variant) -> Array[String]:
	return _sanitize_fixed_mod_pool(raw)


static func _sanitize_fixed_mod_pool(raw: Variant) -> Array[String]:
	var allowed := marathon_mod_pool_candidates()
	var allowed_set: Dictionary = {}
	for mod_id in allowed:
		allowed_set[mod_id] = true
	var out: Array[String] = []
	if raw is Array:
		for item in raw:
			var sid := str(item).strip_edges()
			if sid != "" and allowed_set.has(sid) and not out.has(sid):
				out.append(sid)
	return out


static func _sanitize_mod_pool(raw: Variant) -> Array[String]:
	var allowed := marathon_mod_pool_candidates()
	var allowed_set: Dictionary = {}
	for mod_id in allowed:
		allowed_set[mod_id] = true
	var out: Array[String] = []
	if raw is Array:
		for item in raw:
			var sid := str(item).strip_edges()
			if sid != "" and allowed_set.has(sid) and not out.has(sid):
				out.append(sid)
	if out.is_empty():
		return default_mod_pool()
	var min_size := mini(MOD_POOL_MIN_COUNT, allowed.size())
	while out.size() < min_size:
		for mod_id in allowed:
			if not out.has(mod_id):
				out.append(mod_id)
				break
		if out.size() < min_size and out.size() >= allowed.size():
			break
	return out


static func to_scope_config(run_config: Dictionary, template: Dictionary) -> Dictionary:
	var cfg := sanitize(run_config)
	var group_id := str(template.get("genre_group_id", "")).strip_edges()
	if group_id != "":
		cfg["genre_group_id"] = group_id
	var template_min := float(template.get("difficulty_min", 2.0))
	var template_max := float(template.get("difficulty_max", 7.0))
	var scope_diff_min := template_min
	var scope_diff_max := template_max
	var diff_policy := str(cfg.get("chart_difficulty_policy", _EndlessSessionConfig.CHART_DIFFICULTY_POLICY_ALL))
	if diff_policy == _EndlessSessionConfig.CHART_DIFFICULTY_POLICY_SELECTED:
		var tiers: Array = cfg.get("chart_difficulty_tiers_allowed", [])
		if tiers.is_empty():
			tiers = [str(cfg.get("chart_difficulty_tier", _EndlessSessionConfig.CHART_DIFFICULTY_TIER_MEDIUM))]
		var union_min := _EndlessSessionConfig.DIFFICULTY_BASE_MAX
		var union_max := _EndlessSessionConfig.DIFFICULTY_BASE_MIN
		for tier_id in tiers:
			var tier_range: Dictionary = _EndlessSessionConfig.difficulty_range_for_tier(str(tier_id))
			union_min = minf(union_min, float(tier_range.get("min", 1.0)))
			union_max = maxf(union_max, float(tier_range.get("max", 10.0)))
		scope_diff_min = maxf(template_min, union_min)
		scope_diff_max = minf(template_max, union_max)
	if scope_diff_min > scope_diff_max:
		var swap: float = scope_diff_min
		scope_diff_min = scope_diff_max
		scope_diff_max = swap
	return _EndlessSessionConfig.sanitize({
		"track_source": _EndlessSessionConfig.TRACK_SOURCE_RANDOM,
		"genre_policy": _EndlessSessionConfig.GENRE_POLICY_GROUPS,
		"genre_group_ids": [group_id] if group_id != "" else [],
		"difficulty_min": scope_diff_min,
		"difficulty_max": scope_diff_max,
		"duration_min_sec": int(template.get("duration_min_sec", 90)),
		"duration_max_sec": int(template.get("duration_max_sec", 420)),
		"mod_policy": cfg.get("mod_policy", _EndlessSessionConfig.MOD_POLICY_NONE),
		"mod_pool": cfg.get("mod_pool", []),
		"mod_random_count": cfg.get("mod_random_count", _EndlessSessionConfig.DEFAULT_MOD_RANDOM_COUNT),
		"mod_pick_strategy": cfg.get("mod_pick_strategy", _EndlessSessionConfig.DEFAULT_MOD_PICK_STRATEGY),
		"mod_preset_slot": cfg.get("mod_preset_slot", 0),
		"generation_mode_policy": cfg.get("generation_mode_policy", _EndlessSessionConfig.GEN_MODE_POLICY_ALL),
		"generation_modes_allowed": cfg.get("generation_modes_allowed", []),
		"chart_difficulty_policy": cfg.get("chart_difficulty_policy", _EndlessSessionConfig.CHART_DIFFICULTY_POLICY_ALL),
		"chart_difficulty_tiers_allowed": cfg.get("chart_difficulty_tiers_allowed", []),
		"instrument": cfg.get("instrument", _EndlessSessionConfig.DEFAULT_INSTRUMENT),
		"instruments": cfg.get(
			"instruments",
			[cfg.get("instrument", _EndlessSessionConfig.DEFAULT_INSTRUMENT)]
		),
	})
