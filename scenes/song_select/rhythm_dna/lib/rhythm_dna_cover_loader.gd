# scenes/song_select/rhythm_dna/lib/rhythm_dna_cover_loader.gd
extends RefCounted
class_name RhythmDnaCoverLoader

const _TrackPlaceholderCover = preload("res://logic/domain/library/track_placeholder_cover.gd")
const _FilePathUtils = preload("res://logic/platform/file_path_utils.gd")

static var _cover_cache: Dictionary = {}
static var _labels_cache: Dictionary = {}
static var _display_cache: Dictionary = {}
const _DISPLAY_CACHE_LIMIT := 64


static func _canonical_path(path: String) -> String:
	# Единая форма для cache/lookup: strip + "\"→"/" + lower для регистронезависимого кэша.
	# Нижний регистр безопасен: пути к аудио — файловая система Windows (case-insensitive),
	# res:// для песен не используется как ключ реестра; для user:// глобализация также case-insensitive.
	return str(path).strip_edges().replace("\\", "/").to_lower()


static func load_cover(song_path: String) -> Texture2D:
	var raw := str(song_path).strip_edges().replace("\\", "/")
	if raw == "":
		return null
	var key := _canonical_path(raw)
	if _cover_cache.has(key):
		var cached: Variant = _cover_cache[key]
		if cached is Texture2D:
			return cached
		if cached == null:
			# Cached miss (placeholder) — keep returning null to avoid repeat scan.
			return null
	var texture: Texture2D = null
	texture = _try_sidecar_cover(raw)
	if texture == null:
		texture = _try_embedded_cover(raw)
	_cover_cache[key] = texture
	return texture


static func load_track_labels(song_path: String) -> Dictionary:
	var path := song_path.strip_edges()
	if path == "":
		return {"title": "", "artist": ""}
	if _labels_cache.has(path):
		return _labels_cache[path]
	var md := _load_metadata(path)
	if md == null:
		_labels_cache[path] = {"title": "", "artist": ""}
		return _labels_cache[path]
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
	var key := "%s|%d" % [_canonical_path(song_path), display_px]
	if _display_cache.has(key):
		return _display_cache[key]
	var tex := load_cover(song_path)
	if tex == null:
		tex = fallback_cover(song_path)
	var prepared := prepare_display_texture(tex, display_px)
	if _display_cache.size() >= _DISPLAY_CACHE_LIMIT:
		_display_cache.erase(_display_cache.keys()[0])
	_display_cache[key] = prepared
	return prepared


static func _try_sidecar_cover(path: String) -> Texture2D:
	var readable := _readable_audio_path(path)
	var base_global := readable.get_basename()
	var base_res := path.get_basename()
	for base in [base_global, base_res]:
		if base == "":
			continue
		for ext in ["jpg", "jpeg", "png", "webp"]:
			var sidecar := "%s.%s" % [base, ext]
			# FileAccess (handles globalized OS path and res:// in PCK)
			if FileAccess.file_exists(sidecar):
				var img := Image.load_from_file(sidecar)
				if img:
					return ImageTexture.create_from_image(img)
			# Для res:// в PCK/импорте — пробуем ResourceLoader напрямую
			if sidecar.begins_with("res://") and ResourceLoader.exists(sidecar):
				var tex := load(sidecar) as Texture2D
				if tex:
					return tex
	# Fallback via resolved SongLibrary path for stale res://bundled_songs references
	var resolved := _resolve_actual_path(path)
	if resolved != "" and resolved != path:
		var res_readable := _readable_audio_path(resolved)
		var res_base_global := res_readable.get_basename()
		var res_base_res := resolved.get_basename()
		for base in [res_base_global, res_base_res]:
			if base == "" or base == base_global or base == base_res:
				continue
			for ext in ["jpg", "jpeg", "png", "webp"]:
				var sidecar2 := "%s.%s" % [base, ext]
				if FileAccess.file_exists(sidecar2):
					var img2 := Image.load_from_file(sidecar2)
					if img2:
						return ImageTexture.create_from_image(img2)
				if sidecar2.begins_with("res://") and ResourceLoader.exists(sidecar2):
					var tex2 := load(sidecar2) as Texture2D
					if tex2:
						return tex2
	return null


static func _try_embedded_cover(path: String) -> Texture2D:
	var ext := path.get_extension().to_lower()
	if ext not in ["mp3", "wav", "ogg", "flac"]:
		return null
	var md := _load_metadata(path)
	if md != null and md.cover is ImageTexture:
		return md.cover
	return null


# Resolve stale res://bundled_songs path to actual existing filesystem path via SongLibrary.
# Profile records stores res://bundled_songs/... but actual file may be D:/.../songs/... (user folder)
# after library migration/dedupe. Reuses existing SongLibrary index.
static func _resolve_actual_path(path: String) -> String:
	var norm := String(path).replace("\\", "/").strip_edges()
	if norm == "":
		return ""
	# Already exists — no need to resolve
	if FileAccess.file_exists(norm):
		return norm
	if norm.begins_with("res://") and ResourceLoader.exists(norm):
		return norm
	var glob := _readable_audio_path(norm)
	if glob != "" and FileAccess.file_exists(glob):
		return glob
	# Stale bundled reference — lookup by filename / basename in SongLibrary
	if SongLibrary and SongLibrary.has_method("get_songs_list"):
		var fname := norm.get_file().to_lower()
		var stem := norm.get_file().get_basename().to_lower()
		var lst = SongLibrary.get_songs_list()
		for s in lst:
			if not s is Dictionary:
				continue
			var p := str(s.get("path", "")).replace("\\", "/").strip_edges()
			if p == "":
				continue
			if p.get_file().to_lower() == fname:
				return p
			if p.get_file().get_basename().to_lower() == stem:
				# Extra safety: ensure file actually exists
				if FileAccess.file_exists(p) or (p.begins_with("res://") and ResourceLoader.exists(p)):
					return p
				var pg := _readable_audio_path(p)
				if pg != "" and FileAccess.file_exists(pg):
					return p
	return ""


# Unified metadata loader that reuses existing SongLibrary/MusicMetadata pipeline.
# Для res:// НЕ используется globalize как основной путь. Сначала FilePathUtils.load_audio_stream_for_path
# -> ResourceLoader/imported AudioStreamMP3 -> MusicMetadata.set_from_stream -> APIC cover.
# Fallback: FileAccess на res:// (VFS/PCK), resolved SongLibrary path, и globalized/normalized для user:// и абсолютных.
static func _load_metadata(path: String) -> MusicMetadata:
	var normalized := String(path).replace("\\", "/").strip_edges()
	if normalized == "":
		return null
	# 1) Bundled res:// via AudioStream (preferred — reuses FilePathUtils / ResourceLoader pipeline)
	if normalized.begins_with("res://"):
		var stream := _FilePathUtils.load_audio_stream_for_path(normalized)
		if stream != null:
			var md_stream := MusicMetadata.new()
			md_stream.set_from_stream(stream)
			# Возвращаем metadata независимо от наличия title/artist/cover (требование п.3)
			return md_stream
		# Direct FileAccess на res:// (работает внутри PCK/editor VFS)
		if FileAccess.file_exists(normalized):
			var fa_res := FileAccess.open(normalized, FileAccess.READ)
			if fa_res:
				var data_res := fa_res.get_buffer(fa_res.get_length())
				fa_res.close()
				if data_res.size() > 0:
					var md_res := MusicMetadata.new()
					md_res.set_from_data(data_res)
					return md_res
		# Stale bundled path -> resolve to actual SongLibrary file and retry via FilePathUtils/FileAccess
		var resolved := _resolve_actual_path(normalized)
		if resolved != "" and resolved != normalized:
			var stream2 := _FilePathUtils.load_audio_stream_for_path(resolved)
			if stream2 != null:
				var md2 := MusicMetadata.new()
				md2.set_from_stream(stream2)
				return md2
			if FileAccess.file_exists(resolved):
				var fa2 := FileAccess.open(resolved, FileAccess.READ)
				if fa2:
					var d2 := fa2.get_buffer(fa2.get_length())
					fa2.close()
					if d2.size() > 0:
						var md2b := MusicMetadata.new()
						md2b.set_from_data(d2)
						return md2b
			var glob2 := _readable_audio_path(resolved)
			if glob2 != "" and glob2 != resolved and FileAccess.file_exists(glob2):
				var fa2g := FileAccess.open(glob2, FileAccess.READ)
				if fa2g:
					var d2g := fa2g.get_buffer(fa2g.get_length())
					fa2g.close()
					if d2g.size() > 0:
						var md2g := MusicMetadata.new()
						md2g.set_from_data(d2g)
						return md2g
	# 2) Globalized path (user:// -> OS путь, абсолютные не-res)
	var glob := _readable_audio_path(normalized)
	if glob != "" and glob != normalized and FileAccess.file_exists(glob):
		var fa_glob := FileAccess.open(glob, FileAccess.READ)
		if fa_glob:
			var data_glob := fa_glob.get_buffer(fa_glob.get_length())
			fa_glob.close()
			if data_glob.size() > 0:
				var md_glob := MusicMetadata.new()
				md_glob.set_from_data(data_glob)
				return md_glob
	# 3) Normalized direct (абсолютные OS пути, edge cases)
	if FileAccess.file_exists(normalized):
		var fa_norm := FileAccess.open(normalized, FileAccess.READ)
		if fa_norm:
			var data_norm := fa_norm.get_buffer(fa_norm.get_length())
			fa_norm.close()
			if data_norm.size() > 0:
				var md_norm := MusicMetadata.new()
				md_norm.set_from_data(data_norm)
				return md_norm
	return null
