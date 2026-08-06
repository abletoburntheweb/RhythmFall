# logic/domain/session/endless_run.gd
class_name EndlessRun
extends RefCounted

const _EndlessSessionConfig = preload("res://logic/domain/session/endless_session_config.gd")
const _SessionScopeResolver = preload("res://logic/domain/session/session_scope_resolver.gd")
const _RunRewards = preload("res://logic/domain/rewards/run_rewards.gd")
const _PlayModeIds = preload("res://logic/domain/session/play_mode_ids.gd")

var config: Dictionary = {}
var deck_state: Dictionary = {}
var rng: RandomNumberGenerator

var track_index: int = 0
var streak: int = 0
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
var tracks_cleared: Array[Dictionary] = []

var _current_entry: Dictionary = {}
var _current_modifiers: Array = []
var _pool_lap_announce: int = 0
var _last_finish_reason: String = "complete"


func start(raw_config: Dictionary) -> bool:
	config = _EndlessSessionConfig.sanitize(raw_config)
	rng = RandomNumberGenerator.new()
	rng.randomize()
	deck_state = {}
	track_index = 0
	streak = 0
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
	tracks_cleared.clear()
	_current_entry = {}
	_current_modifiers = []
	_pool_lap_announce = 0
	_last_finish_reason = "complete"
	if str(config.get("track_source", "")) == _EndlessSessionConfig.TRACK_SOURCE_PLAYLIST:
		const PlaylistCatalog = preload("res://logic/domain/library/playlist_catalog.gd")
		PlaylistCatalog.record_playlist_run(str(config.get("playlist_id", "")))
	return _prepare_current_track()


func request_exit_after_track() -> void:
	exit_after_track = true


func should_end_after_track() -> bool:
	return exit_after_track


func get_finish_reason() -> String:
	return _last_finish_reason


func get_play_mode() -> String:
	return _PlayModeIds.ENDLESS


func get_current_modifiers() -> Array:
	return _current_modifiers.duplicate()


func get_pending_pool_lap_announce() -> int:
	return _pool_lap_announce


func get_pause_stats() -> Dictionary:
	var track_source := str(config.get("track_source", _EndlessSessionConfig.TRACK_SOURCE_RANDOM))
	var selected_remaining := -1
	var selected_total := 0
	if (
		track_source == _EndlessSessionConfig.TRACK_SOURCE_SELECTED
		or track_source == _EndlessSessionConfig.TRACK_SOURCE_PLAYLIST
	):
		if track_source == _EndlessSessionConfig.TRACK_SOURCE_PLAYLIST:
			const PlaylistCatalog = preload("res://logic/domain/library/playlist_catalog.gd")
			selected_total = PlaylistCatalog.song_paths_for(str(config.get("playlist_id", ""))).size()
		else:
			selected_total = (_config_selected_paths() as Array).size()
		var deck: Variant = deck_state.get("deck", [])
		selected_remaining = (deck as Array).size() if deck is Array else 0
	return {
		"streak": streak,
		"earned_xp": earned_xp_pending,
		"earned_currency": earned_currency_pending,
		"series_rr": series_rr(),
		"track_source": track_source,
		"selected_remaining": selected_remaining,
		"selected_total": selected_total,
		"expanded_random": bool(deck_state.get("expanded_random", false)),
		"pool_lap": int(deck_state.get("pool_lap", 1)),
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
	var chart_tag := _SessionScopeResolver.resolve_chart_tag_for_entry(_current_entry)
	return {
		"song_info": song_info,
		"instrument": instrument,
		"generation_mode": generation_mode,
		"lane_count": lane_count,
		"run_modifiers": _current_modifiers.duplicate(),
		"chart_tag": chart_tag,
		"track_index": track_index,
		"streak": streak,
		"pool_lap_announce": _pool_lap_announce,
		"inter_track_hp_recovery_pct": int(
			config.get("inter_track_hp_recovery_pct", _EndlessSessionConfig.DEFAULT_INTER_TRACK_HP_RECOVERY_PCT)
		),
	}


func on_track_cleared(stats: Dictionary) -> bool:
	streak += 1
	_accumulate_track_stats(stats, true)
	if str(config.get("track_source", "")) == _EndlessSessionConfig.TRACK_SOURCE_PLAYLIST:
		const PlaylistCatalog = preload("res://logic/domain/library/playlist_catalog.gd")
		PlaylistCatalog.record_playlist_session_clear(str(config.get("playlist_id", "")))
	if exit_after_track:
		_last_finish_reason = "exit"
		return false
	return _prepare_current_track()


func on_track_defeat(stats: Dictionary) -> void:
	_accumulate_track_stats(stats, false)
	_last_finish_reason = "defeat"


func on_series_manual_exit(stats: Dictionary) -> void:
	_accumulate_track_stats(stats, false)
	_last_finish_reason = "exit"


func series_rr() -> int:
	# Endless does not award RR; kept for summary schema compatibility.
	return 0


func build_summary(reason: String) -> Dictionary:
	var resolved_reason := reason
	if reason == "complete" and _last_finish_reason != "complete":
		resolved_reason = _last_finish_reason
	var flawless := _is_flawless_series()
	var finalized := _RunRewards.finalize_endless_run_rewards(
		earned_xp_pending,
		earned_currency_pending,
		tracks_cleared.size()
	)
	return {
		"reason": resolved_reason,
		"mode_id": _PlayModeIds.ENDLESS,
		"streak": streak,
		"track_index": track_index,
		"total_score": total_score,
		"total_hit_notes": total_hit_notes,
		"total_missed_notes": total_missed_notes,
		"total_perfect_hits": total_perfect_hits,
		"total_max_combo": total_max_combo,
		"ending_combo": ending_combo,
		"average_accuracy": average_accuracy(),
		"series_rr": series_rr(),
		"flawless_series": flawless,
		"earned_xp": int(finalized.get("xp", 0)),
		"earned_currency": int(finalized.get("currency", 0)),
		"tracks_cleared": tracks_cleared.duplicate(true),
		"lane_stats": _aggregated_lane_stats(),
		"config": config.duplicate(true),
	}


func average_accuracy() -> float:
	if _accuracy_weight_sum <= 0.0:
		return 0.0
	return _accuracy_weighted / _accuracy_weight_sum


func _prepare_current_track() -> bool:
	# Empty instrument → use config instruments pool (drums and/or bass).
	var entry := _SessionScopeResolver.pick_next_entry(config, deck_state, rng, "")
	if entry.is_empty():
		_current_entry = {}
		_current_modifiers = []
		if not exit_after_track:
			_last_finish_reason = _resolve_empty_prepare_reason()
		return false
	deck_state["last_song_path"] = str(entry.get("song_path", "")).strip_edges()
	_current_entry = entry
	_current_modifiers = _SessionScopeResolver.pick_track_modifiers(config, rng)
	_pool_lap_announce = int(deck_state.get("announce_pool_lap", 0))
	if _pool_lap_announce > 0:
		deck_state.erase("announce_pool_lap")
	track_index += 1
	return true


func _resolve_empty_prepare_reason() -> String:
	return "complete"


func _config_selected_paths() -> Array:
	var paths: Array = config.get("selected_song_paths", [])
	return paths if paths is Array else []


func _is_flawless_series() -> bool:
	if tracks_cleared.is_empty():
		return false
	for track in tracks_cleared:
		if track is not Dictionary:
			return false
		if int(track.get("missed_notes", 0)) > 0:
			return false
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
		var rewards := _RunRewards.compute_endless_track_rewards(stats)
		earned_xp_pending += int(rewards.get("xp", 0))
		earned_currency_pending += int(rewards.get("currency", 0))
		# Endless awards XP/currency only — RR stays a library (and Marathon) rating.
		tracks_cleared.append({
			"song_path": str(stats.get("song_path", "")),
			"title": str(stats.get("title", "")),
			"score": score,
			"accuracy": accuracy,
			"combo": combo,
			"max_combo": max_combo,
			"missed_notes": missed,
			"hit_notes": hit,
			"track_rr": 0,
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
