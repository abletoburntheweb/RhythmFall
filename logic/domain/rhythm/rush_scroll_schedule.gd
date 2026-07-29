# logic/domain/rhythm/rush_scroll_schedule.gd
extends RefCounted
class_name RushScrollSchedule


static func build_bursts_bar_aligned(
	song_path: String,
	bpm: float,
	song_duration: float,
	bars_interval: float,
	burst_duration_sec: float,
	first_bar: int = 4
) -> Array:
	if song_duration <= 0.01 or bpm <= 0.0:
		return []
	var beat_sec := 60.0 / bpm
	var bar_sec := beat_sec * 4.0
	var every_bars := maxi(int(round(bars_interval)), 2)
	var burst := maxf(burst_duration_sec, 0.25)
	var start_bar := maxi(first_bar, 1)
	var windows: Array = []
	var bar_idx := start_bar
	while bar_idx * bar_sec < song_duration:
		var start_s := bar_idx * bar_sec
		var end_s := minf(start_s + burst, song_duration)
		if end_s - start_s >= 0.2:
			windows.append({"start_s": start_s, "end_s": end_s})
		bar_idx += every_bars
	return windows


static func build_bursts_timed(
	song_path: String,
	song_duration: float,
	interval_min_sec: float,
	interval_max_sec: float,
	burst_duration_sec: float
) -> Array:
	if song_duration <= 0.01:
		return []
	var min_i := maxf(interval_min_sec, 1.0)
	var max_i := maxf(interval_max_sec, min_i)
	var burst := maxf(burst_duration_sec, 0.25)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("rush_bursts_timed|%s" % song_path.strip_edges())
	var windows: Array = []
	var cursor := lerpf(6.0, min_i, rng.randf())
	while cursor < song_duration:
		var end_s := minf(cursor + burst, song_duration)
		if end_s - cursor >= 0.2:
			windows.append({"start_s": cursor, "end_s": end_s})
		var gap := lerpf(min_i, max_i, rng.randf())
		cursor += gap
	return windows


static func scroll_multiplier_at(
	windows: Array,
	song_time: float,
	scroll_pct: float,
	ramp_sec: float = 0.4
) -> float:
	if windows.is_empty():
		return 1.0
	var target := scroll_pct / 100.0
	if is_equal_approx(target, 1.0):
		return 1.0
	var ramp := maxf(ramp_sec, 0.05)
	var best := 1.0
	for w in windows:
		if not w is Dictionary:
			continue
		var start_s := float(w.get("start_s", 0.0))
		var end_s := float(w.get("end_s", start_s))
		if end_s <= start_s:
			continue
		var mult := _burst_multiplier_at(song_time, start_s, end_s, target, ramp)
		best = maxf(best, mult)
	return best


static func _burst_multiplier_at(
	song_time: float, start_s: float, end_s: float, target: float, ramp: float
) -> float:
	var fade_in_start := start_s - ramp
	var fade_out_end := end_s + ramp
	if song_time < fade_in_start or song_time >= fade_out_end:
		return 1.0
	if song_time < start_s:
		var t := clampf((song_time - fade_in_start) / ramp, 0.0, 1.0)
		return lerpf(1.0, target, _smoothstep(t))
	if song_time < end_s:
		return target
	var t_out := clampf((song_time - end_s) / ramp, 0.0, 1.0)
	return lerpf(target, 1.0, _smoothstep(t_out))


static func _smoothstep(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)
