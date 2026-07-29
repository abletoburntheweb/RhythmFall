# logic/domain/session/endless_series_rating.gd
class_name EndlessSeriesRating
extends RefCounted

const _RhythmRating = preload("res://logic/domain/rhythm/rhythm_rating.gd")
const _RunRewards = preload("res://logic/domain/rewards/run_rewards.gd")
const _EndlessSessionConfig = preload("res://logic/domain/session/endless_session_config.gd")

# Marathon counts only RR improvement per track; scale down vs library clears.
# Endless does not award RR (see endless_run.gd).
const SERIES_TRACK_RR_SCALE := 0.72


static func compute_track_rr(stats: Dictionary, scope_entry: Dictionary) -> int:
	var accuracy := float(stats.get("accuracy", 0.0))
	var missed := int(stats.get("missed_notes", 0))
	var total := int(stats.get("total_notes", 0))
	var modifiers: Array = stats.get("modifiers", [])
	var chart_rating := int(floor(float(scope_entry.get("decimal_rating", 0.0))))
	var grade := _RunRewards.compute_grade(accuracy)
	var full_combo := missed == 0 and total > 0
	return _RhythmRating.compute(accuracy, chart_rating, grade, full_combo, modifiers)


static func compute_track_rr_delta(
	stats: Dictionary,
	scope_entry: Dictionary,
	in_run_bests: Dictionary
) -> int:
	var run_rr := compute_track_rr(stats, scope_entry)
	if run_rr <= 0:
		return 0
	var song_path := str(scope_entry.get("song_path", "")).strip_edges()
	var instrument := str(scope_entry.get("instrument", _EndlessSessionConfig.DEFAULT_INSTRUMENT))
	var mode := str(scope_entry.get("mode", "basic"))
	var lanes := int(scope_entry.get("lanes", 4))
	var modifiers: Array = stats.get("modifiers", [])
	var profile_best := 0
	if ProfileMilestonesManager != null:
		profile_best = ProfileMilestonesManager.get_best_rr_for_chart(
			song_path, instrument, mode, lanes, modifiers
		)
	var ckey := _RhythmRating.chart_key(song_path, instrument, mode, lanes, modifiers)
	var run_best := int(in_run_bests.get(ckey, 0))
	var baseline := maxi(profile_best, run_best)
	var delta := maxi(0, run_rr - baseline)
	in_run_bests[ckey] = maxi(run_best, run_rr)
	if delta <= 0:
		return 0
	return maxi(0, int(round(float(delta) * SERIES_TRACK_RR_SCALE)))


static func compute_series_rr(tracks_cleared: Array) -> int:
	var total := 0
	for track in tracks_cleared:
		if track is not Dictionary:
			continue
		total += int(track.get("track_rr", 0))
	return total
