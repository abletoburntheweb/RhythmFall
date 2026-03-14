# logic/utils/file_path_utils.gd
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

static func load_audio_stream_for_path(path: String, base_dir: String = "") -> AudioStream:
	var full_path = (base_dir + path) if base_dir != "" else path
	if is_res_path(full_path):
		if ResourceLoader.exists(full_path):
			return load(full_path) as AudioStream
		var gres = ProjectSettings.globalize_path(full_path)
		if FileAccess.file_exists(gres):
			var f1 = FileAccess.open(gres, FileAccess.READ)
			if f1:
				var data1 = f1.get_buffer(f1.get_length())
				f1.close()
				var ext1 = gres.get_extension().to_lower()
				if ext1 == "mp3":
					var s_mp3a := AudioStreamMP3.new()
					s_mp3a.data = data1
					return s_mp3a
				elif ext1 == "wav":
					var s_wava := AudioStreamWAV.new()
					s_wava.data = data1
					return s_wava
				elif ext1 == "ogg":
					var s_ogga := AudioStreamOggVorbis.new()
					s_ogga.data = data1
					return s_ogga
		return null
	var real_path = to_real_path(full_path)
	if real_path == "":
		return null
	var f = FileAccess.open(real_path, FileAccess.READ)
	if not f:
		return null
	var bytes = f.get_buffer(f.get_length())
	f.close()
	var ext = real_path.get_extension().to_lower()
	if ext == "mp3":
		var s_mp3 := AudioStreamMP3.new()
		s_mp3.data = bytes
		return s_mp3
	elif ext == "wav":
		var s_wav := AudioStreamWAV.new()
		s_wav.data = bytes
		return s_wav
	elif ext == "ogg":
		var s_ogg := AudioStreamOggVorbis.new()
		s_ogg.data = bytes
		return s_ogg
	return null
