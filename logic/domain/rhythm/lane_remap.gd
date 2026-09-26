# logic/domain/rhythm/lane_remap.gd
extends RefCounted
class_name LaneRemap

const _DynamicLanesSchedule = preload("res://logic/domain/rhythm/dynamic_lanes_schedule.gd")

const MODE_MIRROR := "mirror"
const MODE_SHUFFLE := "shuffle"
const MODE_RANDOM := "random"

const RANDOM_BEATS_PER_PERM := 2.0


static func seed_for_run(song_path: String, modifier_id: String) -> int:
	return hash("%s|%s" % [song_path.strip_edges(), modifier_id])


static func build_shuffle_perm(chart_lanes: int, seed: int) -> PackedInt32Array:
	var n := clampi(chart_lanes, 3, 5)
	var order: Array[int] = []
	for i in range(n):
		order.append(i)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in range(n - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: int = order[i]
		order[i] = order[j]
		order[j] = tmp
	return PackedInt32Array(order)


static func random_segment_index(song_time: float, bpm: float) -> int:
	var beat_rate := maxf(bpm, 60.0) / 60.0
	var beats := maxf(song_time, 0.0) * beat_rate
	return int(floor(beats / RANDOM_BEATS_PER_PERM))


static func random_segment_index_for_context(
	note_time: float,
	bpm: float,
	remap_ctx: Dictionary = {}
) -> int:
	var schedule: Variant = remap_ctx.get("dna_schedule", [])
	if schedule is Array and not schedule.is_empty():
		return _DynamicLanesSchedule.segment_index_at(schedule, note_time)
	return random_segment_index(note_time, bpm)


static func mirror_lane(chart_lane: int, chart_lanes: int) -> int:
	var chart := clampi(chart_lanes, 3, 5)
	var lane := clampi(chart_lane, 0, chart - 1)
	return chart - 1 - lane


static func apply_perm(chart_lane: int, perm: PackedInt32Array) -> int:
	var lane := clampi(chart_lane, 0, perm.size() - 1)
	if lane < 0 or lane >= perm.size():
		return chart_lane
	return perm[lane]


static func remap_local_lane(
	local_lane: int,
	lane_count: int,
	mode: String,
	song_path: String,
	modifier_id: String,
	note_time: float,
	bpm: float,
	remap_ctx: Dictionary = {}
) -> int:
	var n := clampi(lane_count, 3, 5)
	var lane := clampi(local_lane, 0, n - 1)
	match mode:
		MODE_MIRROR:
			return n - 1 - lane
		MODE_SHUFFLE:
			var perm := build_shuffle_perm(n, seed_for_run(song_path, modifier_id))
			return apply_perm(lane, perm)
		MODE_RANDOM:
			var base_seed := seed_for_run(song_path, modifier_id)
			var seg := random_segment_index_for_context(note_time, bpm, remap_ctx)
			var perm_r := build_shuffle_perm(n, base_seed + seg)
			return apply_perm(lane, perm_r)
		_:
			return lane


static func remap_lane(
	chart_lane: int,
	chart_lanes: int,
	mode: String,
	song_path: String,
	modifier_id: String,
	note_time: float,
	bpm: float,
	remap_ctx: Dictionary = {}
) -> int:
	var chart := clampi(chart_lanes, 3, 5)
	var lane := clampi(chart_lane, 0, chart - 1)
	match mode:
		MODE_MIRROR:
			return mirror_lane(lane, chart)
		MODE_SHUFFLE:
			var perm := build_shuffle_perm(chart, seed_for_run(song_path, modifier_id))
			return apply_perm(lane, perm)
		MODE_RANDOM:
			var base_seed := seed_for_run(song_path, modifier_id)
			var seg := random_segment_index_for_context(note_time, bpm, remap_ctx)
			var perm_r := build_shuffle_perm(chart, base_seed + seg)
			return apply_perm(lane, perm_r)
		_:
			return lane
