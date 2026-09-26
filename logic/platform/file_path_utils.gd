# logic/platform/file_path_utils.gd
extends RefCounted
class_name FilePathUtils

static func is_res_path(p: String) -> bool:
	return String(p).begins_with("res://")

static func is_user_path(p: String) -> bool:
	return String(p).begins_with("user://")

static func ensure_trailing_slash(p: String) -> String:
	var s = String(p)
	if not s.ends_with("/"):
		s += "/"
	return s

static func to_real_path(p: String) -> String:
	var full = String(p)
	if is_res_path(full) or is_user_path(full):
		return full
	if FileAccess.file_exists(full):
		return full
	var g = ProjectSettings.globalize_path(full)
	if FileAccess.file_exists(g):
		return g
	return ""

const PerfTrace = preload("res://logic/utils/perf_trace.gd")

static func load_audio_stream_for_path(path: String, base_dir: String = "") -> AudioStream:
	var _t_all := PerfTrace.begin("perf.detail.chart_editor.audio.load")
	var full_path = (base_dir + path) if base_dir != "" else path
	if is_res_path(full_path):
		if ResourceLoader.exists(full_path):
			var _t_res := PerfTrace.begin("perf.detail.chart_editor.audio.resource_load")
			var res := load(full_path) as AudioStream
			PerfTrace.end("perf.detail.chart_editor.audio.resource_load", _t_res)
			PerfTrace.end("perf.detail.chart_editor.audio.load", _t_all)
			return res
		var gres = ProjectSettings.globalize_path(full_path)
		if FileAccess.file_exists(gres):
			var _t_fr := PerfTrace.begin("perf.detail.chart_editor.audio.file_read")
			var f1 = FileAccess.open(gres, FileAccess.READ)
			var data1: PackedByteArray = PackedByteArray()
			if f1:
				data1 = f1.get_buffer(f1.get_length())
				f1.close()
			PerfTrace.end("perf.detail.chart_editor.audio.file_read", _t_fr)
			if not data1.is_empty():
				var ext1 = gres.get_extension().to_lower()
				var _t_dec := PerfTrace.begin("perf.detail.chart_editor.audio.decode")
				var out: AudioStream = null
				if ext1 == "mp3":
					var s_mp3a := AudioStreamMP3.new()
					s_mp3a.data = data1
					out = s_mp3a
				elif ext1 == "wav":
					var s_wava := AudioStreamWAV.load_from_file(gres)
					if s_wava:
						out = s_wava
					else:
						var fallback_wava := AudioStreamWAV.new()
						fallback_wava.data = data1
						out = fallback_wava
				elif ext1 == "ogg":
					var s_ogga := AudioStreamOggVorbis.new()
					s_ogga.data = data1
					out = s_ogga
				PerfTrace.end("perf.detail.chart_editor.audio.decode", _t_dec)
				PerfTrace.end("perf.detail.chart_editor.audio.load", _t_all)
				if out != null:
					return out
		PerfTrace.end("perf.detail.chart_editor.audio.load", _t_all)
		return null
	var real_path = to_real_path(full_path)
	if real_path == "":
		PerfTrace.end("perf.detail.chart_editor.audio.load", _t_all)
		return null
	var _t_fr2 := PerfTrace.begin("perf.detail.chart_editor.audio.file_read")
	var f = FileAccess.open(real_path, FileAccess.READ)
	var bytes: PackedByteArray = PackedByteArray()
	if f:
		bytes = f.get_buffer(f.get_length())
		f.close()
	PerfTrace.end("perf.detail.chart_editor.audio.file_read", _t_fr2)
	if bytes.is_empty():
		PerfTrace.end("perf.detail.chart_editor.audio.load", _t_all)
		return null
	var ext = real_path.get_extension().to_lower()
	var _t_dec2 := PerfTrace.begin("perf.detail.chart_editor.audio.decode")
	var out2: AudioStream = null
	if ext == "mp3":
		var s_mp3 := AudioStreamMP3.new()
		s_mp3.data = bytes
		out2 = s_mp3
	elif ext == "wav":
		var s_wav := AudioStreamWAV.load_from_file(real_path)
		if s_wav:
			out2 = s_wav
		else:
			var fallback_wav := AudioStreamWAV.new()
			fallback_wav.data = bytes
			out2 = fallback_wav
	elif ext == "ogg":
		var s_ogg := AudioStreamOggVorbis.new()
		s_ogg.data = bytes
		out2 = s_ogg
	PerfTrace.end("perf.detail.chart_editor.audio.decode", _t_dec2)
	PerfTrace.end("perf.detail.chart_editor.audio.load", _t_all)
	if out2 != null:
		return out2
	return null
