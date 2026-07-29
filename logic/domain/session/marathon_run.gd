# logic/domain/session/marathon_run.gd
class_name MarathonRun
extends RefCounted

const _SessionScopeResolver = preload("res://logic/domain/session/session_scope_resolver.gd")
const _RunRewards = preload("res://logic/domain/rewards/run_rewards.gd")
const _EndlessSeriesRating = preload("res://logic/domain/session/endless_series_rating.gd")
const _PlayModeIds = preload("res://logic/domain/session/play_mode_ids.gd")
const _MarathonRouteBuilder = preload("res://logic/domain/session/marathon_route_builder.gd")
const _EndlessSessionConfig = preload("res://logic/domain/session/endless_session_config.gd")
const _MarathonSessionConfig = preload("res://logic/domain/session/marathon_session_config.gd")
const _MarathonRouteCatalog = preload("res://logic/domain/session/marathon_route_catalog.gd")
const _MarathonRunRules = preload("res://logic/domain/session/marathon_run_rules.gd")

var route_id: String = ""
var genre_group_id: String = ""
var template: Dictionary = {}
var run_config: Dictionary = {}
var effective_mod_config: Dictionary = {}
var run_rules: Dictionary = {}
var track_entries: Array[Dictionary] = []
var track_index: int = 0
var tracks_cleared: int = 0
var exit_after_track: bool = false

var total_score: int = 0
var total_hit_notes: int = 0
var total_missed_notes: int = 0
var total_perfect_hits: int = 0
var total_max_combo: int = 0
var ending_combo: int = 0
var _accuracy_weight_sum: float = 0.0
var _accuracy_weighted: float = 0.0
var _lane_hits: PackedInt32Array = PackedInt32Array()
var _lane_misses: PackedInt32Array = PackedInt32Array()

var earned_xp_pending: int = 0
var earned_currency_pending: int = 0
var tracks_log: Array[Dictionary] = []

var _current_entry: Dictionary = {}
var _current_modifiers: Array = []
var _cached_locked_modifiers: Array = []
var _last_finish_reason: String = "defeat"
var _series_chart_best: Dictionary = {}

var _min_hp_ratio: float = 1.0
var _finish_hp_ratio: float = 1.0
var _hp_after_tracks: Array = []


func start_for_group(genre_group_id_in: String, run_config_in: Dictionary = {}) -> bool:
	return start_for_route(_MarathonRouteCatalog.route_id_for_group(genre_group_id_in), run_config_in)


func start_for_route(route_id_in: String, run_config_in: Dictionary = {}) -> bool:
	run_config = _MarathonSessionConfig.sanitize(run_config_in)
	var built := _MarathonRouteBuilder.build_for_route(str(route_id_in).strip_edges(), true, run_config)
	if not bool(built.get("ok", false)):
		return false
	return _start_from_build(built)


func _start_from_build(built: Dictionary) -> bool:
	route_id = str(built.get("route_id", ""))
	genre_group_id = str(built.get("genre_group_id", ""))
	template = built.get("template", {}) if built.get("template") is Dictionary else {}
	run_rules = _MarathonRunRules.parse(template)
	var built_cfg: Variant = built.get("run_config", {})
	if built_cfg is Dictionary and not (built_cfg as Dictionary).is_empty():
		run_config = _MarathonSessionConfig.sanitize(built_cfg)
	var instrument := str(built.get("instrument", run_config.get("instrument", _EndlessSessionConfig.DEFAULT_INSTRUMENT)))
	run_config["instrument"] = instrument
	run_config["instruments"] = [instrument]
	effective_mod_config = _MarathonSessionConfig.resolve_effective_run_config(run_config, template)
	track_entries.clear()
	for raw in built.get("entries", []):
		if raw is Dictionary:
			track_entries.append((raw as Dictionary).duplicate(true))
	track_index = 0
	tracks_cleared = 0
	exit_after_track = false
	total_score = 0
	total_hit_notes = 0
	total_missed_notes = 0
	total_perfect_hits = 0
	total_max_combo = 0
	ending_combo = 0
	_accuracy_weight_sum = 0.0
	_accuracy_weighted = 0.0
	_lane_hits = PackedInt32Array()
	_lane_misses = PackedInt32Array()
	earned_xp_pending = 0
	earned_currency_pending = 0
	tracks_log.clear()
	_current_entry = {}
	_current_modifiers = []
	_cached_locked_modifiers = []
	_last_finish_reason = "defeat"
	_series_chart_best = {}
	_min_hp_ratio = 1.0
	_finish_hp_ratio = 1.0
	_hp_after_tracks = []
	return _prepare_current_track()


func total_tracks() -> int:
	return track_entries.size()


func request_exit_after_track() -> void:
	exit_after_track = true


func should_end_after_track() -> bool:
	return exit_after_track


func get_finish_reason() -> String:
	return _last_finish_reason


func get_play_mode() -> String:
	return _PlayModeIds.MARATHON


func get_current_modifiers() -> Array:
	return _current_modifiers.duplicate()


func get_pause_stats() -> Dictionary:
	return {
		"streak": tracks_cleared,
		"track_index": track_index,
		"total_tracks": total_tracks(),
		"earned_xp": earned_xp_pending,
		"earned_currency": earned_currency_pending,
		"series_rr": series_rr(),
		"route_id": route_id,
		"genre_group_id": genre_group_id,
	}


func get_launch_params() -> Dictionary:
	if _current_entry.is_empty():
		return {}
	var song_path := str(_current_entry.get("song_path", "")).strip_edges()
	var song_info := _SessionScopeResolver.build_song_info(song_path)
	var instrument := str(_current_entry.get("instrument", _EndlessSessionConfig.DEFAULT_INSTRUMENT))
	var generation_mode := str(_current_entry.get("intent", "")).strip_edges()
	if generation_mode == "":
		generation_mode = GenerationIntents.resolve_chart_stem(str(_current_entry.get("mode", "basic")))
	var lane_count := int(_current_entry.get("lanes", 4))
	var cfg_lanes := int(run_config.get("lanes", 0))
	if cfg_lanes >= 3:
		lane_count = cfg_lanes
	var chart_tag := _SessionScopeResolver.resolve_chart_tag_for_entry(_current_entry)
	return {
		"song_info": song_info,
		"instrument": instrument,
		"generation_mode": generation_mode,
		"lane_count": lane_count,
		"run_modifiers": _current_modifiers.duplicate(),
		"chart_tag": chart_tag,
		"track_index": track_index,
		"total_tracks": total_tracks(),
		"tracks_cleared": tracks_cleared,
		"route_id": route_id,
		"genre_group_id": genre_group_id,
		"inter_track_hp_recovery_pct": int(
			run_rules.get("inter_track_hp_recovery_pct", _MarathonRunRules.DEFAULT_HP_RECOVERY_PCT)
		),
	}


func on_track_cleared(stats: Dictionary) -> bool:
	tracks_cleared += 1
	_accumulate_track_stats(stats, true)
	_record_track_telemetry(stats)
	var rule_check := _MarathonRunRules.check_after_track(stats, total_missed_notes, run_rules)
	if not bool(rule_check.get("ok", true)):
		_last_finish_reason = str(rule_check.get("reason", "defeat"))
		return false
	if exit_after_track:
		_last_finish_reason = "exit"
		return false
	if tracks_cleared >= total_tracks():
		_last_finish_reason = "victory"
		return false
	return _prepare_current_track()


func on_track_defeat(stats: Dictionary) -> void:
	_accumulate_track_stats(stats, false)
	_record_track_telemetry(stats)
	_last_finish_reason = "defeat"


func on_series_manual_exit(stats: Dictionary) -> void:
	_accumulate_track_stats(stats, false)
	_record_track_telemetry(stats)
	_last_finish_reason = "exit"


func series_rr() -> int:
	return _EndlessSeriesRating.compute_series_rr(tracks_log)


func completion_ratio() -> float:
	if total_tracks() <= 0:
		return 0.0
	return float(tracks_cleared) / float(total_tracks())


func build_summary(reason: String) -> Dictionary:
	var resolved_reason := reason
	if reason == "complete" and _last_finish_reason != "complete":
		resolved_reason = _last_finish_reason
	var earned_xp := 0
	var earned_currency := 0
	if resolved_reason == "victory":
		var completion := _RunRewards.compute_marathon_completion_rewards(
			template,
			run_config,
			total_tracks()
		)
		earned_xp = int(completion.get("xp", 0))
		earned_currency = int(completion.get("currency", 0))
	return {
		"reason": resolved_reason,
		"mode_id": _PlayModeIds.MARATHON,
		"route_id": route_id,
		"genre_group_id": genre_group_id,
		"tracks_cleared": tracks_cleared,
		"total_tracks": total_tracks(),
		"completion_ratio": completion_ratio(),
		"track_index": track_index,
		"total_score": total_score,
		"total_hit_notes": total_hit_notes,
		"total_missed_notes": total_missed_notes,
		"total_perfect_hits": total_perfect_hits,
		"total_max_combo": total_max_combo,
		"ending_combo": ending_combo,
		"average_accuracy": average_accuracy(),
		"series_rr": series_rr(),
		"earned_xp": earned_xp,
		"earned_currency": earned_currency,
		"tracks_log": tracks_log.duplicate(true),
		"lane_stats": _aggregated_lane_stats(),
		"template": template.duplicate(true),
		"run_config": run_config.duplicate(true),
		"run_rules": run_rules.duplicate(true),
		"run_telemetry": _run_telemetry(),
	}


func average_accuracy() -> float:
	if _accuracy_weight_sum <= 0.0:
		return 0.0
	return _accuracy_weighted / _accuracy_weight_sum


func _run_telemetry() -> Dictionary:
	return {
		"min_hp_ratio": _min_hp_ratio,
		"finish_hp_ratio": _finish_hp_ratio,
		"hp_after_tracks": _hp_after_tracks.duplicate(),
	}


func _record_track_telemetry(stats: Dictionary) -> void:
	var hp := clampf(float(stats.get("end_hp_ratio", 1.0)), 0.0, 1.0)
	_finish_hp_ratio = hp
	_min_hp_ratio = minf(_min_hp_ratio, hp)
	_hp_after_tracks.append(hp)


func _prepare_current_track() -> bool:
	if track_index >= track_entries.size():
		_current_entry = {}
		_current_modifiers = []
		return false
	_current_entry = track_entries[track_index].duplicate(true)
	_current_modifiers = []
	var mod_policy := str(effective_mod_config.get("mod_policy", _EndlessSessionConfig.MOD_POLICY_NONE))
	if mod_policy != _EndlessSessionConfig.MOD_POLICY_NONE:
		if (
			_MarathonSessionConfig.is_mod_policy_locked(template)
			and not _cached_locked_modifiers.is_empty()
		):
			_current_modifiers = _cached_locked_modifiers.duplicate()
		else:
			_current_modifiers = _SessionScopeResolver.pick_track_modifiers(effective_mod_config, null)
			if _MarathonSessionConfig.is_mod_policy_locked(template):
				_cached_locked_modifiers = _current_modifiers.duplicate()
	track_index += 1
	return true


func _accumulate_track_stats(stats: Dictionary, cleared: bool) -> void:
	var score := int(stats.get("score", 0))
	var accuracy := float(stats.get("accuracy", 0.0))
	var combo := int(stats.get("combo", 0))
	var max_combo := int(stats.get("max_combo", 0))
	var missed := int(stats.get("missed_notes", 0))
	var hit := int(stats.get("hit_notes", 0))
	var perfect := int(stats.get("perfect_hits", 0))
	var total_notes := int(stats.get("total_notes", hit + missed))
	var weight := float(maxi(1, total_notes))

	total_score += score
	total_hit_notes += hit
	total_missed_notes += missed
	total_perfect_hits += perfect
	total_max_combo = maxi(total_max_combo, max_combo)
	ending_combo = combo
	_accuracy_weight_sum += weight
	_accuracy_weighted += accuracy * weight
	_merge_lane_stats(stats.get("lane_stats", []))

	if cleared:
		var track_rr := _EndlessSeriesRating.compute_track_rr_delta(stats, _current_entry, _series_chart_best)
		tracks_log.append({
			"song_path": str(stats.get("song_path", "")),
			"title": str(stats.get("title", "")),
			"score": score,
			"accuracy": accuracy,
			"combo": combo,
			"max_combo": max_combo,
			"missed_notes": missed,
			"hit_notes": hit,
			"track_rr": track_rr,
			"end_hp_ratio": float(stats.get("end_hp_ratio", 1.0)),
			"modifiers": stats.get("modifiers", []),
		})


func _merge_lane_stats(raw: Variant) -> void:
	if raw is not Array:
		return
	for entry in raw:
		if entry is not Dictionary:
			continue
		var lane := int(entry.get("lane", 0))
		if lane < 0:
			continue
		while _lane_hits.size() <= lane:
			_lane_hits.append(0)
			_lane_misses.append(0)
		_lane_hits[lane] += int(entry.get("hits", 0))
		_lane_misses[lane] += int(entry.get("misses", 0))


func _aggregated_lane_stats() -> Array:
	var out: Array = []
	for i in _lane_hits.size():
		var hits := int(_lane_hits[i])
		var misses := int(_lane_misses[i])
		var total := hits + misses
		var acc := 100.0
		if total > 0:
			acc = float(hits) / float(total) * 100.0
		out.append({
			"lane": i,
			"hits": hits,
			"misses": misses,
			"total": total,
			"acc": acc,
		})
	return out
