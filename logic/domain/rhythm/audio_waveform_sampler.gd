extends RefCounted
class_name AudioWaveformSampler

var _cache: Dictionary = {}
static var _shared_cache: Dictionary = {}


func read_pcm_from_wav(path: String) -> Dictionary:
	return _read_pcm_from_wav(path)


func analyze_hit_envelope(path: String, bucket_count: int = 40) -> Dictionary:
	var key := "%s|%d" % [path, bucket_count]
	if _shared_cache.has(key):
		return (_shared_cache[key] as Dictionary).duplicate(true)
	if _cache.has(key):
		return (_cache[key] as Dictionary).duplicate(true)
	var empty := {"envelope": PackedFloat32Array(), "duration": 0.0, "peaks": PackedFloat32Array()}
	if path == "" or not FileAccess.file_exists(path):
		return empty

	var pcm := _read_pcm_from_wav(path)
	var samples: PackedFloat32Array = pcm.get("samples", PackedFloat32Array())
	var sample_rate := int(pcm.get("sample_rate", 0))
	if samples.is_empty() or sample_rate <= 0:
		return empty

	var buckets := maxi(8, bucket_count)
	var bucket_size := maxi(1, int(ceil(float(samples.size()) / float(buckets))))
	var envelope := PackedFloat32Array()
	envelope.resize(buckets)
	var max_peak := 0.0
	for b in buckets:
		var start := b * bucket_size
		var end := mini(start + bucket_size, samples.size())
		var peak := 0.0
		for i in range(start, end):
			peak = maxf(peak, samples[i])
		envelope[b] = peak
		max_peak = maxf(max_peak, peak)
	if max_peak > 0.0001:
		for b in buckets:
			envelope[b] = envelope[b] / max_peak

	var duration := float(samples.size()) / float(sample_rate)
	var peaks := _pick_peak_times(envelope, duration)
	var result := {
		"envelope": envelope,
		"duration": duration,
		"peaks": peaks,
	}
	_cache[key] = result
	_shared_cache[key] = result
	return result.duplicate(true)


func _read_pcm_from_wav(path: String) -> Dictionary:
	var empty := {"samples": PackedFloat32Array(), "sample_rate": 0}
	var wav := AudioStreamWAV.load_from_file(path)
	if wav:
		var decoded := _decode_mono_abs_samples(wav)
		if not decoded.is_empty():
			return {"samples": decoded, "sample_rate": wav.mix_rate}

	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return empty
	return _parse_wav_bytes(bytes)


func _parse_wav_bytes(bytes: PackedByteArray) -> Dictionary:
	var empty := {"samples": PackedFloat32Array(), "sample_rate": 0}
	if bytes.size() < 44:
		return empty
	if bytes.slice(0, 4).get_string_from_ascii() != "RIFF":
		return empty
	if bytes.slice(8, 12).get_string_from_ascii() != "WAVE":
		return empty

	var channels := 1
	var sample_rate := 44100
	var bits_per_sample := 16
	var audio_format := 1
	var data_offset := -1
	var data_size := 0
	var offset := 12
	while offset + 8 <= bytes.size():
		var chunk_id := bytes.slice(offset, offset + 4).get_string_from_ascii()
		var chunk_size := int(bytes.decode_u32(offset + 4))
		offset += 8
		if chunk_id == "fmt " and chunk_size >= 16 and offset + 16 <= bytes.size():
			audio_format = int(bytes.decode_u16(offset))
			channels = int(bytes.decode_u16(offset + 2))
			sample_rate = int(bytes.decode_u32(offset + 4))
			bits_per_sample = int(bytes.decode_u16(offset + 14))
		elif chunk_id == "data":
			data_offset = offset
			data_size = chunk_size
			break
		offset += chunk_size

	if data_offset < 0 or data_size <= 0 or sample_rate <= 0:
		return empty
	if audio_format != 1:
		return empty

	var out := PackedFloat32Array()
	if bits_per_sample == 16:
		var frame_bytes := channels * 2
		var end := mini(data_offset + data_size, bytes.size())
		for i in range(data_offset, end - frame_bytes + 1, frame_bytes):
			var amp := absf(float(bytes.decode_s16(i)) / 32768.0)
			if channels > 1 and i + 3 < end:
				amp = maxf(amp, absf(float(bytes.decode_s16(i + 2)) / 32768.0))
			out.append(amp)
	elif bits_per_sample == 8:
		var frame_bytes := channels
		var end := mini(data_offset + data_size, bytes.size())
		for i in range(data_offset, end - frame_bytes + 1, frame_bytes):
			var amp := absf((float(bytes[i]) - 128.0) / 128.0)
			if channels > 1 and i + 1 < end:
				amp = maxf(amp, absf((float(bytes[i + 1]) - 128.0) / 128.0))
			out.append(amp)
	else:
		return empty

	if out.is_empty():
		return empty
	return {"samples": out, "sample_rate": sample_rate}


func _decode_mono_abs_samples(wav: AudioStreamWAV) -> PackedFloat32Array:
	var bytes := wav.data
	if bytes.is_empty():
		return PackedFloat32Array()
	var out := PackedFloat32Array()
	match wav.format:
		AudioStreamWAV.FORMAT_16_BITS:
			var frame_bytes := 4 if wav.stereo else 2
			for i in range(0, bytes.size() - frame_bytes + 1, frame_bytes):
				var left := _read_i16(bytes, i)
				var amp := absf(float(left) / 32768.0)
				if wav.stereo and i + 3 < bytes.size():
					var right := _read_i16(bytes, i + 2)
					amp = maxf(amp, absf(float(right) / 32768.0))
				out.append(amp)
		AudioStreamWAV.FORMAT_8_BITS:
			var frame_bytes := 2 if wav.stereo else 1
			for i in range(0, bytes.size() - frame_bytes + 1, frame_bytes):
				var left := int(bytes[i]) - 128
				var amp := absf(float(left) / 128.0)
				if wav.stereo and i + 1 < bytes.size():
					var right := int(bytes[i + 1]) - 128
					amp = maxf(amp, absf(float(right) / 128.0))
				out.append(amp)
		_:
			return PackedFloat32Array()
	return out


func _read_i16(bytes: PackedByteArray, index: int) -> int:
	var value := int(bytes[index]) | (int(bytes[index + 1]) << 8)
	if value >= 32768:
		value -= 65536
	return value


func _pick_peak_times(envelope: PackedFloat32Array, duration: float) -> PackedFloat32Array:
	var peaks := PackedFloat32Array()
	if envelope.is_empty() or duration <= 0.0:
		return peaks
	var threshold := 0.22
	for i in envelope.size():
		var amp := envelope[i]
		if amp < threshold:
			continue
		var prev := envelope[i - 1] if i > 0 else 0.0
		var next := envelope[i + 1] if i + 1 < envelope.size() else 0.0
		if amp >= prev and amp >= next:
			var t := (float(i) + 0.5) / float(envelope.size()) * duration
			peaks.append(t)
	if peaks.is_empty():
		var max_i := 0
		var max_v := 0.0
		for i in envelope.size():
			if envelope[i] > max_v:
				max_v = envelope[i]
				max_i = i
		if max_v > 0.01:
			peaks.append((float(max_i) + 0.5) / float(envelope.size()) * duration)
	return peaks
