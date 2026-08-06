# scenes/song_select/rhythm_dna/lib/rhythm_dna_cover_loader.gd
extends RefCounted
class_name RhythmDnaCoverLoader

const _TrackPlaceholderCover = preload("res://logic/domain/library/track_placeholder_cover.gd")

static var _cover_cache: Dictionary = {}
static var _labels_cache: Dictionary = {}


static func load_cover(song_path: String) -> Texture2D:
	var path := song_path.strip_edges()
	if path == "":
		return null
	if _cover_cache.has(path):
		var cached: Variant = _cover_cache[path]
		if cached is Texture2D:
			return cached
	var texture: Texture2D = null
	var sidecar := _try_sidecar_cover(path)
	if sidecar:
		texture = sidecar
	else:
		texture = _try_embedded_cover(path)
	_cover_cache[path] = texture
	return texture


static func load_track_labels(song_path: String) -> Dictionary:
	var path := song_path.strip_edges()
	if path == "":
		return {"title": "", "artist": ""}
	if _labels_cache.has(path):
		return _labels_cache[path]
	var global_path := _readable_audio_path(path)
	if global_path == "" or not FileAccess.file_exists(global_path):
		_labels_cache[path] = {"title": "", "artist": ""}
		return _labels_cache[path]
	var file_access := FileAccess.open(global_path, FileAccess.READ)
	if file_access == null:
		_labels_cache[path] = {"title": "", "artist": ""}
		return _labels_cache[path]
	var file_data := file_access.get_buffer(file_access.get_length())
	file_access.close()
	var md := MusicMetadata.new()
	md.set_from_data(file_data)
	var labels := {
		"title": str(md.title).strip_edges(),
		"artist": str(md.artist).strip_edges(),
	}
	_labels_cache[path] = labels
	return labels


static func _readable_audio_path(path: String) -> String:
	var normalized := String(path).replace("\\", "/").strip_edges()
	if normalized == "":
		return ""
	if normalized.begins_with("res://") or normalized.begins_with("user://"):
		return ProjectSettings.globalize_path(normalized)
	return normalized


static func fallback_cover(song_path: String) -> Texture2D:
	return _TrackPlaceholderCover.load_texture(song_path, true)


static func prepare_display_texture(tex: Texture2D, display_px: int) -> Texture2D:
	if tex == null or display_px <= 0:
		return tex
	var image := tex.get_image()
	if image == null or image.is_empty():
		return tex
	var target_px := maxi(display_px * 2, 96)
	var width := image.get_width()
	var height := image.get_height()
	if width <= 0 or height <= 0:
		return tex
	var max_dim := maxi(width, height)
	var min_dim := mini(width, height)
	if max_dim <= int(target_px * 1.1) and min_dim >= int(display_px * 0.9):
		return tex
	var scale := float(target_px) / float(max_dim)
	var new_w := maxi(1, int(round(float(width) * scale)))
	var new_h := maxi(1, int(round(float(height) * scale)))
	if new_w == width and new_h == height:
		return tex
	var scaled := image.duplicate()
	scaled.resize(new_w, new_h, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(scaled)


static func load_cover_for_display(song_path: String, display_px: int) -> Texture2D:
	var tex := load_cover(song_path)
	if tex == null:
		tex = fallback_cover(song_path)
	return prepare_display_texture(tex, display_px)


static func _try_sidecar_cover(path: String) -> Texture2D:
	var base := _readable_audio_path(path).get_basename()
	if base == "":
		base = path.get_basename()
	for ext in ["jpg", "jpeg", "png", "webp"]:
		var sidecar := "%s.%s" % [base, ext]
		if FileAccess.file_exists(sidecar):
			var img := Image.load_from_file(sidecar)
			if img:
				return ImageTexture.create_from_image(img)
	return null


static func _try_embedded_cover(path: String) -> Texture2D:
	var ext := path.get_extension().to_lower()
	if ext not in ["mp3", "wav", "ogg", "flac"]:
		return null
	var global_path := _readable_audio_path(path)
	if global_path == "" or not FileAccess.file_exists(global_path):
		return null
	var file_access := FileAccess.open(global_path, FileAccess.READ)
	if not file_access:
		return null
	var file_data := file_access.get_buffer(file_access.get_length())
	file_access.close()
	var md := MusicMetadata.new()
	md.set_from_data(file_data)
	if md.cover is ImageTexture:
		return md.cover
	return null
