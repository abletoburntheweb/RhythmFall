# logic/domain/session/marathon_route_setup.gd
class_name MarathonRouteSetup
extends RefCounted

const _EndlessSessionConfig = preload("res://logic/domain/session/endless_session_config.gd")
const _MarathonSessionConfig = preload("res://logic/domain/session/marathon_session_config.gd")

const TIER_OPEN := "open"
const TIER_LIGHT := "light"
const TIER_CURATED := "curated"
const TIER_STRICT := "strict"
const TIER_ULTIMATE := "ultimate"

const LEGACY_ARCHETYPE_ALIASES := {
	"weekly": "journey",
}


static func normalize_archetype_id(archetype_id: String) -> String:
	var aid := str(archetype_id).strip_edges()
	return str(LEGACY_ARCHETYPE_ALIASES.get(aid, aid))


static func setup_tier_for(archetype_id: String, template: Dictionary = {}) -> String:
	if bool(template.get("is_daily", false)):
		return TIER_CURATED
	match normalize_archetype_id(archetype_id):
		"sprint", "standard":
			return TIER_OPEN
		"precision":
			return TIER_LIGHT
		"boss_rush", "chaos":
			return TIER_CURATED
		"accelerando", "journey":
			return TIER_STRICT
		"ultimate":
			return TIER_ULTIMATE
		_:
			return TIER_OPEN


static func is_featured_challenge(archetype_id: String) -> bool:
	return normalize_archetype_id(archetype_id) == "journey"


static func apply_to_template(template: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var out := template.duplicate(true)
	var aid := normalize_archetype_id(out.get("archetype_id", ""))
	var tier := setup_tier_for(aid, out)
	out["setup_tier"] = tier
	if tier == TIER_OPEN:
		out["setup_locked"] = _empty_locks()
		return out

	var locked := {
		"mods": true,
		"lanes": true,
		"chart_style": true,
		"track_order": true,
	}
	out["setup_locked"] = locked

	match aid:
		"chaos":
			out["rolled_track_order"] = _MarathonSessionConfig.TRACK_ORDER_RANDOM
		_:
			out["rolled_track_order"] = _MarathonSessionConfig.TRACK_ORDER_COURSE

	match tier:
		TIER_LIGHT:
			out["rolled_lanes"] = 4
			_lock_chart_arcade(out)
			if not bool(out.get("mod_policy_locked", false)):
				_apply_locked_random_mods(out, rng, 1)
		TIER_CURATED:
			out["rolled_lanes"] = 4 if aid == "boss_rush" else int(out.get("rolled_lanes", 4))
			_lock_chart_arcade(out)
		TIER_STRICT:
			out["rolled_lanes"] = 5 if aid == "journey" else int(out.get("rolled_lanes", 4))
			_lock_chart_arcade(out)
			if not bool(out.get("mod_policy_locked", false)):
				_apply_locked_random_mods(out, rng, 2)
		TIER_ULTIMATE:
			out["rolled_lanes"] = 5
			_lock_chart_arcade(out)
			_apply_locked_fixed_mods(out, rng, 3)

	return out


static func is_field_locked(template: Dictionary, field_id: String) -> bool:
	var locked: Variant = template.get("setup_locked", {})
	if locked is Dictionary:
		return bool((locked as Dictionary).get(field_id, false))
	return false


static func _empty_locks() -> Dictionary:
	return {
		"mods": false,
		"lanes": false,
		"chart_style": false,
		"track_order": false,
	}


static func _lock_chart_arcade(out: Dictionary) -> void:
	out["rolled_generation_mode_policy"] = _EndlessSessionConfig.GEN_MODE_POLICY_SELECTED
	out["rolled_generation_modes_allowed"] = ["arcade"]


static func _apply_locked_random_mods(out: Dictionary, rng: RandomNumberGenerator, count: int) -> void:
	var pool := _pick_mod_pool(rng)
	out["mod_policy_locked"] = true
	out["mod_policy"] = _EndlessSessionConfig.MOD_POLICY_RANDOM_POOL
	out["mod_pool"] = pool
	out["mod_random_count"] = clampi(
		count,
		_EndlessSessionConfig.MOD_RANDOM_COUNT_MIN,
		_EndlessSessionConfig.MOD_RANDOM_COUNT_MAX
	)
	out["rolled_mod_policy"] = out["mod_policy"]
	out["rolled_mod_random_count"] = out["mod_random_count"]
	out["rolled_mod_pool"] = pool.duplicate()


static func _apply_locked_fixed_mods(out: Dictionary, rng: RandomNumberGenerator, count: int) -> void:
	var pool := _MarathonSessionConfig.marathon_mod_pool_candidates().duplicate()
	for index in range(pool.size()):
		var swap_index := rng.randi_range(index, maxi(index, pool.size() - 1))
		var tmp: String = pool[index]
		pool[index] = pool[swap_index]
		pool[swap_index] = tmp
	var fixed: Array[String] = []
	for mod_id in pool:
		if fixed.size() >= count:
			break
		fixed.append(str(mod_id))
	out["mod_policy_locked"] = true
	out["mod_policy"] = _EndlessSessionConfig.MOD_POLICY_FIXED
	out["fixed_modifiers"] = fixed
	out["rolled_mod_policy"] = out["mod_policy"]
	out["rolled_mod_pool"] = fixed.duplicate()


static func _pick_mod_pool(rng: RandomNumberGenerator) -> Array[String]:
	var candidates := _MarathonSessionConfig.marathon_mod_pool_candidates()
	if candidates.is_empty():
		return []
	var count := mini(5, maxi(3, rng.randi_range(3, 5)))
	var pool := candidates.duplicate()
	pool.shuffle()
	return pool.slice(0, count)
