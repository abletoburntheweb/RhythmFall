# logic/domain/session/marathon_route_builder.gd
class_name MarathonRouteBuilder
extends RefCounted

const _EndlessSessionConfig = preload("res://logic/domain/session/endless_session_config.gd")
const _SessionScopeResolver = preload("res://logic/domain/session/session_scope_resolver.gd")
const _MarathonRouteCatalog = preload("res://logic/domain/session/marathon_route_catalog.gd")
const _MarathonRouteLength = preload("res://logic/domain/session/marathon_route_length.gd")

const ERROR_NOT_ENOUGH_SONGS := "not_enough_songs"
const ERROR_EMPTY_SCOPE := "empty_scope"
const ERROR_DURATION_SHORT := "duration_short"
const SLOT_ROLE_BODY := "body"
const SLOT_ROLE_FINALE := "finale"


static func preview_for_group(genre_group_id: String, run_config: Dictionary = {}) -> Dictionary:
	return build_for_route(MarathonRouteCatalog.route_id_for_group(genre_group_id), false, run_config)


static func preview_for_route(route_id: String, run_config: Dictionary = {}) -> Dictionary:
	return build_for_route(route_id, true, run_config)


static func build_for_group(
	genre_group_id: String,
	require_playable: bool = true,
	run_config: Dictionary = {}
) -> Dictionary:
	return build_for_route(_MarathonRouteCatalog.route_id_for_group(genre_group_id), require_playable, run_config)


static func build_for_route(
	route_id: String,
	require_playable: bool = true,
	run_config: Dictionary = {}
) -> Dictionary:
	const _MarathonSessionConfig = preload("res://logic/domain/session/marathon_session_config.gd")
	const _MarathonRouteRolls = preload("res://logic/domain/session/marathon_route_rolls.gd")
	var template := _MarathonRouteCatalog.template_for_route(route_id)
	var group_id := str(template.get("genre_group_id", "")).strip_edges()
	if group_id == "":
		group_id = _MarathonRouteCatalog.genre_group_for_route(route_id)
	if group_id == "":
		return _fail(ERROR_EMPTY_SCOPE, template)
	var effective_config := run_config.duplicate(true) if not run_config.is_empty() else _MarathonRouteRolls.rolled_config(template)
	effective_config = _MarathonSessionConfig.resolve_effective_run_config(effective_config, template)
	var built := _build_route_with_config(template, group_id, effective_config, require_playable)
	if bool(built.get("ok", false)):
		return built
	# Narrow chart style (e.g. Arcade-only roll) often blocks routes that work with both styles.
	# When the player can edit style, widen once and retry.
	var err := str(built.get("error", ""))
	var style_locked := _MarathonSessionConfig.is_setup_field_locked(template, "chart_style")
	if (
		not style_locked
		and (err == ERROR_NOT_ENOUGH_SONGS or err == ERROR_EMPTY_SCOPE or err == ERROR_DURATION_SHORT)
		and _is_narrow_chart_style(effective_config)
	):
		var widened := effective_config.duplicate(true)
		widened["generation_mode_policy"] = _EndlessSessionConfig.GEN_MODE_POLICY_ALL
		widened["generation_modes_allowed"] = []
		var retry := _build_route_with_config(template, group_id, widened, require_playable)
		if bool(retry.get("ok", false)):
			retry["chart_style_auto_widened"] = true
			return retry
	return built


static func _is_narrow_chart_style(config: Dictionary) -> bool:
	var policy := str(config.get("generation_mode_policy", _EndlessSessionConfig.GEN_MODE_POLICY_ALL))
	if policy == _EndlessSessionConfig.GEN_MODE_POLICY_ALL:
		return false
	var allowed: Array = config.get("generation_modes_allowed", [])
	if allowed.is_empty():
		return false
	return allowed.size() < _EndlessSessionConfig.UI_CHART_STYLE_GOALS.size()


static func _build_route_with_config(
	template: Dictionary,
	group_id: String,
	effective_config: Dictionary,
	require_playable: bool
) -> Dictionary:
	var scope_config := _scope_config_for_template(template, effective_config)
	var policy := _MarathonRouteLength.policy_from_template(template)
	var min_required := int(policy.get("min_songs_required", 3))
	var preferred := ""
	if bool(effective_config.get("instrument_locked", false)):
		preferred = str(effective_config.get("instrument", "")).strip_edges()
	var instrument_pick := _pick_viable_instrument(scope_config, min_required, preferred)
	var instrument := str(instrument_pick.get("instrument", _EndlessSessionConfig.DEFAULT_INSTRUMENT))
	effective_config["instrument"] = instrument
	effective_config["instruments"] = [instrument]
	effective_config["instrument_locked"] = true
	scope_config["instrument"] = instrument
	scope_config["instruments"] = [instrument]
	var scope: Array = instrument_pick.get("scope", [])
	if scope.is_empty():
		scope = _SessionScopeResolver.resolve_scope(scope_config)
	if scope.is_empty():
		return _fail(ERROR_EMPTY_SCOPE, template, 0, 0, {}, effective_config, instrument)
	var by_song := _group_scope_by_song(scope)
	var song_count := by_song.size()
	if require_playable and song_count < min_required:
		return _fail(ERROR_NOT_ENOUGH_SONGS, template, song_count, min_required, policy, effective_config, instrument)
	var entries := _assign_entries(by_song, template, policy)
	if entries.is_empty():
		return _fail(ERROR_NOT_ENOUGH_SONGS, template, song_count, min_required, policy, effective_config, instrument)
	entries = _apply_track_order(entries, effective_config)
	var entry_count := entries.size()
	if require_playable:
		if entry_count < min_required:
			return _fail_partial(
				ERROR_NOT_ENOUGH_SONGS,
				template,
				entries,
				song_count,
				min_required,
				policy,
				effective_config,
				instrument
			)
		var total_sec := _entries_duration_sec(entries)
		if total_sec + 0.001 < float(policy.get("min_duration_sec", 0.0)):
			return _fail_partial(
				ERROR_DURATION_SHORT,
				template,
				entries,
				song_count,
				min_required,
				policy,
				effective_config,
				instrument
			)
	elif entry_count < min_required:
		return _fail_partial(
			ERROR_NOT_ENOUGH_SONGS,
			template,
			entries,
			song_count,
			min_required,
			policy,
			effective_config,
			instrument
		)
	var estimated_sec := _entries_duration_sec(entries)
	return {
		"ok": true,
		"error": "",
		"template": template,
		"route_id": str(template.get("route_id", "")),
		"genre_group_id": group_id,
		"instrument": instrument,
		"run_config": effective_config,
		"entries": entries,
		"available_songs": song_count,
		"track_count": entries.size(),
		"target_track_count": entries.size(),
		"required_track_count": min_required,
		"length_policy": policy,
		"estimated_duration_sec": estimated_sec,
		"has_finale": bool(policy.get("has_finale", false)),
		"chart_style_auto_widened": false,
	}


static func _scope_config_for_template(template: Dictionary, run_config: Dictionary = {}) -> Dictionary:
	const _MarathonSessionConfig = preload("res://logic/domain/session/marathon_session_config.gd")
	if not run_config.is_empty():
		return _MarathonSessionConfig.to_scope_config(run_config, template)
	var group_id := str(template.get("genre_group_id", "")).strip_edges()
	return _EndlessSessionConfig.sanitize({
		"track_source": _EndlessSessionConfig.TRACK_SOURCE_RANDOM,
		"genre_policy": _EndlessSessionConfig.GENRE_POLICY_GROUPS,
		"genre_group_ids": [group_id] if group_id != "" else [],
		"difficulty_min": float(template.get("difficulty_min", 2.0)),
		"difficulty_max": float(template.get("difficulty_max", 7.0)),
		"duration_min_sec": int(template.get("duration_min_sec", 90)),
		"duration_max_sec": int(template.get("duration_max_sec", 420)),
		"mod_policy": str(template.get("mod_policy", _EndlessSessionConfig.MOD_POLICY_NONE)),
		"generation_mode_policy": _EndlessSessionConfig.GEN_MODE_POLICY_ALL,
	})


static func _group_scope_by_song(scope: Array) -> Dictionary:
	var by_song: Dictionary = {}
	for raw in scope:
		if raw is not Dictionary:
			continue
		var entry: Dictionary = raw
		var song_path := str(entry.get("song_path", "")).strip_edges()
		if song_path == "":
			continue
		if not by_song.has(song_path):
			by_song[song_path] = []
		(by_song[song_path] as Array).append(entry)
	return by_song


static func _assign_entries(by_song: Dictionary, template: Dictionary, policy: Dictionary) -> Array[Dictionary]:
	if bool(policy.get("has_finale", false)):
		return _assign_entries_with_finale(by_song, template, policy)
	return _assign_standard_entries(by_song, template, policy)


static func _assign_standard_entries(by_song: Dictionary, template: Dictionary, policy: Dictionary) -> Array[Dictionary]:
	var max_tracks := int(policy.get("max_tracks", int(template.get("track_count", 5))))
	var min_tracks := int(policy.get("min_tracks", 3))
	var min_dur := float(policy.get("min_duration_sec", 0.0))
	var max_dur := float(policy.get("max_duration_sec", INF))
	var target_dur := float(policy.get("target_duration_sec", 0.0))
	var dmin := float(template.get("difficulty_min", 2.0))
	var dmax := float(template.get("difficulty_max", 7.0))
	var used_songs: Dictionary = {}
	var out: Array[Dictionary] = []
	for slot in range(max_tracks):
		var target := dmin
		if max_tracks > 1:
			target = lerpf(dmin, dmax, float(slot) / float(max_tracks - 1))
		var best_entry := _pick_best_entry(by_song, used_songs, target)
		if best_entry.is_empty():
			break
		var chosen_path := str(best_entry.get("song_path", "")).strip_edges()
		used_songs[chosen_path] = true
		out.append(_tag_entry(best_entry, SLOT_ROLE_BODY))
		var total_sec := _entries_duration_sec(out)
		if out.size() < min_tracks:
			continue
		if total_sec >= min_dur and total_sec <= max_dur:
			if absf(total_sec - target_dur) <= maxf(60.0, target_dur * 0.15):
				break
		if total_sec > max_dur and out.size() > min_tracks:
			out.pop_back()
			used_songs.erase(chosen_path)
			break
	while out.size() > min_tracks and _entries_duration_sec(out) > max_dur:
		var removed: Dictionary = out.pop_back()
		var removed_path := str(removed.get("song_path", "")).strip_edges()
		if removed_path != "":
			used_songs.erase(removed_path)
	return out


static func _assign_entries_with_finale(by_song: Dictionary, template: Dictionary, policy: Dictionary) -> Array[Dictionary]:
	var body_min := int(policy.get("body_min_tracks", 1))
	var body_max := int(policy.get("body_max_tracks", body_min))
	var min_dur := float(policy.get("min_duration_sec", 0.0))
	var max_dur := float(policy.get("max_duration_sec", INF))
	var target_dur := float(policy.get("target_duration_sec", 0.0))
	var dmin := float(template.get("difficulty_min", 2.0))
	var dmax := float(template.get("difficulty_max", 7.0))
	var finale_min := float(template.get("finale_difficulty_min", dmax))
	var finale_max := float(template.get("finale_difficulty_max", 10.0))
	var used_songs: Dictionary = {}
	var body: Array[Dictionary] = []
	for slot in range(body_max):
		var target := dmin
		if body_max > 1:
			target = lerpf(dmin, dmax, float(slot) / float(body_max - 1))
		var best_entry := _pick_best_entry(by_song, used_songs, target)
		if best_entry.is_empty():
			break
		var chosen_path := str(best_entry.get("song_path", "")).strip_edges()
		used_songs[chosen_path] = true
		body.append(_tag_entry(best_entry, SLOT_ROLE_BODY))
		var body_sec := _entries_duration_sec(body)
		if body.size() < body_min:
			continue
		if body_sec >= min_dur and body_sec <= max_dur:
			if absf(body_sec - target_dur) <= maxf(60.0, target_dur * 0.15):
				break
		if body_sec > max_dur and body.size() > body_min:
			body.pop_back()
			used_songs.erase(chosen_path)
			break
	while body.size() > body_min and _entries_duration_sec(body) > max_dur:
		var removed: Dictionary = body.pop_back()
		var removed_path := str(removed.get("song_path", "")).strip_edges()
		if removed_path != "":
			used_songs.erase(removed_path)
	if body.size() < body_min:
		return []
	var finale := _pick_finale_entry(by_song, used_songs, finale_min, finale_max)
	if finale.is_empty():
		return []
	body.append(_tag_entry(finale, SLOT_ROLE_FINALE))
	return body


static func _tag_entry(raw: Dictionary, slot_role: String) -> Dictionary:
	var out := raw.duplicate(true)
	out["slot_role"] = slot_role
	return out


static func _pick_best_entry(by_song: Dictionary, used_songs: Dictionary, target_rating: float) -> Dictionary:
	var best_entry: Dictionary = {}
	var best_dist := INF
	for song_path in by_song.keys():
		if used_songs.has(song_path):
			continue
		for raw in by_song[song_path]:
			if raw is not Dictionary:
				continue
			var entry: Dictionary = raw
			var dist := absf(float(entry.get("decimal_rating", 0.0)) - target_rating)
			if dist < best_dist:
				best_dist = dist
				best_entry = entry
	return best_entry


static func _pick_finale_entry(
	by_song: Dictionary,
	used_songs: Dictionary,
	rating_min: float,
	rating_max: float
) -> Dictionary:
	var best_entry: Dictionary = {}
	var best_rating := -1.0
	for song_path in by_song.keys():
		if used_songs.has(song_path):
			continue
		for raw in by_song[song_path]:
			if raw is not Dictionary:
				continue
			var entry: Dictionary = raw
			var rating := float(entry.get("decimal_rating", 0.0))
			if rating + 0.001 < rating_min:
				continue
			if rating_max > 0.0 and rating > rating_max + 0.001:
				continue
			if rating > best_rating:
				best_rating = rating
				best_entry = entry
	if not best_entry.is_empty():
		return best_entry
	for song_path in by_song.keys():
		if used_songs.has(song_path):
			continue
		for raw in by_song[song_path]:
			if raw is not Dictionary:
				continue
			var entry: Dictionary = raw
			var rating := float(entry.get("decimal_rating", 0.0))
			if rating > best_rating:
				best_rating = rating
				best_entry = entry
	return best_entry


static func _entries_duration_sec(entries: Array) -> float:
	var total := 0.0
	for entry in entries:
		if entry is Dictionary:
			total += float((entry as Dictionary).get("duration_sec", 0.0))
	return total


static func _apply_track_order(entries: Array[Dictionary], run_config: Dictionary) -> Array[Dictionary]:
	const _MarathonSessionConfig = preload("res://logic/domain/session/marathon_session_config.gd")
	if entries.size() <= 1:
		return entries
	if str(run_config.get("track_order", _MarathonSessionConfig.TRACK_ORDER_COURSE)) != _MarathonSessionConfig.TRACK_ORDER_RANDOM:
		return entries
	var body: Array[Dictionary] = []
	var finale: Dictionary = {}
	for entry in entries:
		if str(entry.get("slot_role", "")) == SLOT_ROLE_FINALE:
			finale = entry
		else:
			body.append(entry)
	body.shuffle()
	if not finale.is_empty():
		body.append(finale)
	return body


static func _pick_viable_instrument(
	scope_config: Dictionary,
	min_required: int,
	preferred: String = ""
) -> Dictionary:
	"""Try preferred (if set), else shuffle drums/bass; first with enough songs wins."""
	var order: Array[String] = ["drums", "bass"]
	order.shuffle()
	var pref := preferred.strip_edges()
	if pref == "drums" or pref == "bass":
		order.erase(pref)
		order.insert(0, pref)
	var best := {
		"instrument": _EndlessSessionConfig.DEFAULT_INSTRUMENT,
		"scope": [],
		"song_count": 0,
	}
	for inst in order:
		var cfg := scope_config.duplicate(true)
		cfg["instrument"] = inst
		cfg["instruments"] = [inst]
		var scope: Array = _SessionScopeResolver.resolve_scope(cfg)
		var song_count := _group_scope_by_song(scope).size()
		if song_count > int(best.get("song_count", 0)):
			best = {
				"instrument": inst,
				"scope": scope,
				"song_count": song_count,
			}
		if song_count >= min_required:
			return {
				"instrument": inst,
				"scope": scope,
				"song_count": song_count,
			}
	return best


static func _fail_partial(
	error_code: String,
	template: Dictionary,
	entries: Array,
	available_songs: int,
	required_tracks: int,
	policy: Dictionary,
	run_config: Dictionary,
	instrument: String = ""
) -> Dictionary:
	var ordered := entries
	if not entries.is_empty():
		ordered = _apply_track_order(entries, run_config)
	var inst := str(instrument).strip_edges()
	if inst == "":
		inst = str(run_config.get("instrument", _EndlessSessionConfig.DEFAULT_INSTRUMENT))
	return {
		"ok": false,
		"error": error_code,
		"template": template,
		"route_id": str(template.get("route_id", "")),
		"genre_group_id": str(template.get("genre_group_id", "")),
		"instrument": inst,
		"run_config": run_config,
		"entries": ordered,
		"available_songs": available_songs,
		"track_count": ordered.size(),
		"required_track_count": required_tracks,
		"length_policy": policy,
		"estimated_duration_sec": _entries_duration_sec(ordered),
		"has_finale": bool(policy.get("has_finale", false)),
	}


static func _fail(
	error_code: String,
	template: Dictionary,
	available_songs: int = 0,
	required_tracks: int = 0,
	policy: Dictionary = {},
	run_config: Dictionary = {},
	instrument: String = ""
) -> Dictionary:
	if policy.is_empty():
		policy = _MarathonRouteLength.policy_from_template(template)
	var inst := str(instrument).strip_edges()
	if inst == "":
		inst = str(run_config.get("instrument", _EndlessSessionConfig.DEFAULT_INSTRUMENT))
	return {
		"ok": false,
		"error": error_code,
		"template": template,
		"route_id": str(template.get("route_id", "")),
		"genre_group_id": str(template.get("genre_group_id", "")),
		"instrument": inst,
		"run_config": run_config,
		"entries": [],
		"available_songs": available_songs,
		"track_count": 0,
		"required_track_count": required_tracks,
		"length_policy": policy,
		"estimated_duration_sec": 0.0,
		"has_finale": bool(policy.get("has_finale", false)),
	}
