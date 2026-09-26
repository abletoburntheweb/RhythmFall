# logic/domain/library/song_preview_segment.gd
extends RefCounted
class_name SongPreviewSegment

const _WaveformSampler = preload("res://logic/domain/rhythm/audio_waveform_sampler.gd")

const SNIPPET_SEC := 15.0
const FADE_IN_SEC := 1.2
const FADE_OUT_SEC := 1.6
const WINDOW_STEP_SEC := 0.25


static func compute_plan(stream: AudioStream, filepath: String, snippet_sec: float = SNIPPET_SEC) -> Dictionary:
	var total_sec := _stream_length_sec(stream)
	if total_sec <= 0.0:
		return {"mode": "full", "start_sec": 0.0, "play_sec": 0.0, "total_sec": 0.0}
	if total_sec <= snippet_sec + 0.5:
		return {"mode": "full", "start_sec": 0.0, "play_sec": total_sec, "total_sec": total_sec}
	var start_sec := _find_loudest_start(filepath, total_sec, snippet_sec)
	return {
		"mode": "snippet",
		"start_sec": start_sec,
		"play_sec": snippet_sec,
		"total_sec": total_sec,
	}


static func _stream_length_sec(stream: AudioStream) -> float:
	if stream == null:
		return 0.0
	var length := float(stream.get_length())
	return length if length > 0.0 else 0.0


static func _find_loudest_start(filepath: String, total_sec: float, snippet_sec: float) -> float:
	var ext := filepath.get_extension().to_lower()
	if ext == "wav":
		var wav_start := _loudest_window_from_wav(filepath, total_sec, snippet_sec)
		if wav_start >= 0.0:
			return wav_start
	return _fallback_hook_start(total_sec, snippet_sec)


static func _loudest_window_from_wav(filepath: String, total_sec: float, snippet_sec: float) -> float:
	var sampler := _WaveformSampler.new()
	var pcm: Dictionary = sampler.read_pcm_from_wav(filepath)
	var samples: PackedFloat32Array = pcm.get("samples", PackedFloat32Array())
	var sample_rate := int(pcm.get("sample_rate", 0))
	if samples.is_empty() or sample_rate <= 0:
		return -1.0

	var window_samples := maxi(1, int(round(snippet_sec * float(sample_rate))))
	if samples.size() <= window_samples:
		return 0.0

	var step_samples := maxi(1, int(round(WINDOW_STEP_SEC * float(sample_rate))))
	var best_start := 0
	var best_energy := -1.0
	var last_start := samples.size() - window_samples
	for start in range(0, last_start + 1, step_samples):
		var energy := 0.0
		var end := mini(start + window_samples, samples.size())
		for i in range(start, end):
			var amp := samples[i]
			energy += amp * amp
		if energy > best_energy:
			best_energy = energy
			best_start = start
	return clampf(float(best_start) / float(sample_rate), 0.0, maxf(0.0, total_sec - snippet_sec))


static func _fallback_hook_start(total_sec: float, snippet_sec: float) -> float:
	var max_start := maxf(0.0, total_sec - snippet_sec)
	return clampf(total_sec * 0.35, 0.0, max_start)
