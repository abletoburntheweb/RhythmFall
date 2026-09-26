# logic/domain/editor/chart_grid.gd
extends RefCounted
class_name ChartGrid

# Grid for editor snapping — mirrors audio_analysis quant logic but editor-owned.

var bpm: float = 120.0
var first_measure_start: float = 0.0
var beat_interval: float = 0.5
var measure_duration: float = 2.0
var duration_s: float = 0.0
var beats: Array[float] = []

# Maps division -> step. 0 = free. Must match SnapOption ids (0=Off,1,2,4,8,16,32).
const DIVISION_STEPS := {
	1: "1",
	2: "1/2",
	4: "1/4",
	8: "1/8",
	16: "1/16",
	32: "1/32",
}

func _init(p_bpm: float = 120.0, p_duration: float = 0.0, p_beats: Array = []) -> void:
	bpm = maxf(1.0, p_bpm) if p_bpm > 0.0 else 120.0
	duration_s = maxf(0.0, p_duration)
	beat_interval = 60.0 / bpm
	measure_duration = beat_interval * 4.0
	if p_beats is Array and not p_beats.is_empty():
		var tmp: Array[float] = []
		for v in p_beats:
			tmp.append(float(v))
		tmp.sort()
		beats = tmp
		if not beats.is_empty():
			first_measure_start = beats[0]
			if beats.size() >= 2:
				# Use median beat interval when real beats exist.
				var diffs: Array[float] = []
				for i in range(1, beats.size()):
					diffs.append(beats[i] - beats[i - 1])
				diffs.sort()
				beat_interval = diffs[diffs.size() / 2]
				measure_duration = beat_interval * 4.0
	else:
		beats = []
		first_measure_start = 0.0

func snap_time(t: float, division: int) -> float:
	# Free or invalid -> no snap. Single source of truth: snap_enabled + snap_division.
	if division <= 0 or division not in DIVISION_STEPS:
		return EditorNoteUtils.sanitize_time(t)
	var step := beat_interval * 4.0 / float(division)
	if step <= 0.0:
		return EditorNoteUtils.sanitize_time(t)
	var idx := roundi((t - first_measure_start) / step)
	var snapped := first_measure_start + float(idx) * step
	return EditorNoteUtils.sanitize_time(snapped)

func measure_index(t: float) -> int:
	if measure_duration <= 0.0:
		return 0
	return int(floor((t - first_measure_start) / measure_duration))

func measure_start_time(measure_idx: int) -> float:
	return first_measure_start + float(measure_idx) * measure_duration

func beat_index(t: float) -> int:
	if beat_interval <= 0.0:
		return 0
	return int(floor((t - first_measure_start) / beat_interval))

func nearest_beat_time(t: float) -> float:
	if beats.is_empty():
		var idx := roundi((t - first_measure_start) / beat_interval)
		return first_measure_start + float(idx) * beat_interval
	var best := beats[0]
	var best_d := absf(t - best)
	for b in beats:
		var d := absf(t - b)
		if d < best_d:
			best_d = d
			best = b
	return best

func beat_times_in_range(from_s: float, to_s: float) -> Array[float]:
	var out: Array[float] = []
	if beats.is_empty():
		var start_idx := ceili((from_s - first_measure_start) / beat_interval)
		var end_idx := floori((to_s - first_measure_start) / beat_interval)
		for i in range(start_idx, end_idx + 1):
			var bt := first_measure_start + float(i) * beat_interval
			if bt >= from_s and bt <= to_s:
				out.append(bt)
		return out
	for b in beats:
		if b >= from_s and b <= to_s:
			out.append(b)
	return out

func measure_times_in_range(from_s: float, to_s: float) -> Array[float]:
	var out: Array[float] = []
	var start_idx := ceili((from_s - first_measure_start) / measure_duration)
	var end_idx := floori((to_s - first_measure_start) / measure_duration)
	for i in range(start_idx, end_idx + 1):
		var mt := first_measure_start + float(i) * measure_duration
		if mt >= from_s and mt <= to_s:
			out.append(mt)
	return out

func format_time_label(t: float) -> String:
	var m := measure_index(t) + 1
	var rel := t - measure_start_time(measure_index(t))
	var beat_f := rel / beat_interval if beat_interval > 0.0 else 0.0
	return "m%d:%.2f" % [m, beat_f + 1.0]
