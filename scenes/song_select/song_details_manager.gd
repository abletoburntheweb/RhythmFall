# scenes/song_select/song_details_manager.gd
class_name SongDetailsManager
extends Node

var title_label: Label = null
var artist_label: Label = null
var year_label: Label = null
var bpm_label: Label = null
var duration_label: Label = null
var primary_genre_label: Label = null
var play_count_label: Label = null
var best_grade_label: Label = null
var cover_texture_rect: TextureRect = null
var play_button: Button = null

var preview_player: AudioStreamPlayer = null

var _current_preview_file_path: String = ""
var _preview_request_id: int = 0
var _cover_loader: ThreadedTextureLoader = null
var _cover_loader_connected: bool = false
var _cover_request_id: int = 0
var _sidecar_cover_thread: Thread = null
var _sidecar_cover_request_id: int = 0
var _embedded_cover_thread: Thread = null
var _embedded_cover_request_id: int = 0
static var _sidecar_cover_cache: Dictionary = {}
static var _embedded_cover_cache: Dictionary = {}

var current_instrument: String = "standard"
var current_generation_mode: String = "basic"
var current_lanes: int = 4  

var generation_status_label: Label = null
var is_generating_notes: bool = false

func set_generation_status_label(status_lbl: Label):
	generation_status_label = status_lbl

func set_current_instrument(instrument: String):
	current_instrument = instrument
	_update_play_button_state()
	
func set_current_generation_mode(mode: String):
	current_generation_mode = mode
	_update_play_button_state()

func set_current_lanes(lanes: int):
	current_lanes = lanes
	_update_play_button_state()

func setup_ui_nodes(title_lbl: Label, artist_lbl: Label, year_lbl: Label, bpm_lbl: Label, duration_lbl: Label, genre_lbl: Label, play_count_lbl: Label, best_grade_lbl: Label, cover_tex_rect: TextureRect, play_btn: Button):
	title_label = title_lbl
	artist_label = artist_lbl
	year_label = year_lbl
	bpm_label = bpm_lbl
	duration_label = duration_lbl
	primary_genre_label = genre_lbl
	play_count_label = play_count_lbl
	best_grade_label = best_grade_lbl
	cover_texture_rect = cover_tex_rect
	play_button = play_btn

func setup_audio_player():
	preview_player = AudioStreamPlayer.new()
	preview_player.name = "PreviewPlayer"
	preview_player.finished.connect(_on_preview_finished)
	add_child(preview_player)

func _load_audio_stream_for_path(p: String) -> AudioStream:
	return FilePathUtils.load_audio_stream_for_path(p)
func update_details(song_data: Dictionary):
	
	if title_label:
		title_label.text = "Название: " + String(song_data.get("title", "Н/Д")).strip_edges()
	if artist_label:
		artist_label.text = "Исполнитель: " + String(song_data.get("artist", "Н/Д")).strip_edges()
	if year_label:
		year_label.text = "Год: " + String(song_data.get("year", "Н/Д")).strip_edges()
	if bpm_label:
		bpm_label.text = "BPM: " + String(song_data.get("bpm", "Н/Д")).strip_edges()
	_update_duration_if_unknown(song_data)
	if title_label or artist_label or year_label:
		_apply_tags_if_needed(song_data)
	
	if primary_genre_label:
		var genre = String(song_data.get("primary_genre", "Н/Д")).strip_edges()
		if genre == "unknown":
			genre = "Н/Д"
		primary_genre_label.text = "Жанр: " + genre
	if play_count_label:
		var path = song_data.get("path", "")
		var count = 0
		if TrackStatsManager and TrackStatsManager.has_method("get_completion_count"):
			count = TrackStatsManager.get_completion_count(path)
		play_count_label.text = "Сыгран: %d раз" % count
	if best_grade_label:
		var song_path = song_data.get("path", "")
		var best_grade_text = "Лучшая оценка: Н/Д"
		var color_to_apply = Color.WHITE
		if song_path != "":
			var svc = ResultsHistoryService.new()
			var top = svc.get_top_result_for_song(song_path)
			if top and top is Dictionary and not top.is_empty():
				var grade_str = str(top.get("grade", "Н/Д"))
				best_grade_text = "Лучшая оценка: " + grade_str
				if grade_str == "SS":
					color_to_apply = Color("#F2B35A")
				else:
					var saved_color = top.get("grade_color", null)
					if saved_color and saved_color is Dictionary and saved_color.has("r"):
						color_to_apply = Color(
							float(saved_color.get("r", 1.0)),
							float(saved_color.get("g", 1.0)),
							float(saved_color.get("b", 1.0)),
							float(saved_color.get("a", 1.0))
						)
		best_grade_label.text = best_grade_text
		best_grade_label.self_modulate = color_to_apply

	var cover_texture = song_data.get("cover", null)
	if cover_texture_rect:
		_apply_cover_texture(song_data)

	_update_play_button_state()
	_update_generation_status() 

func _get_fallback_cover_texture():
	var path := _get_fallback_cover_path()
	if path != "" and _cover_loader:
		var cached := _cover_loader.get_cached(path)
		if cached:
			return cached
	return null

func _get_fallback_cover_path() -> String:
	var active_cover_item_id = PlayerDataManager.get_active_item("Covers")

	var folder_name_map = {
		"covers_default": "default_covers"
	}
	var folder_name = folder_name_map.get(active_cover_item_id, active_cover_item_id.replace("covers_", ""))
	var base_folder = "res://assets/shop/covers/"
	var dir = DirAccess.open(base_folder)
	if not dir or not dir.dir_exists(folder_name):
		folder_name = "default_covers"

	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var random_index = rng.randi_range(1, 7)
	var fallback_cover_filename = "cover%d.png" % random_index
	var fallback_cover_path = "res://assets/shop/covers/%s/%s" % [folder_name, fallback_cover_filename]
	if FileAccess.file_exists(fallback_cover_path):
		return fallback_cover_path
	var fallback_fallback_path = "res://assets/shop/covers/%s/cover1.png" % folder_name
	if fallback_cover_path != fallback_fallback_path and FileAccess.file_exists(fallback_fallback_path):
		return fallback_fallback_path

	return ""

func _has_notes_for_instrument(song_path: String, instrument: String) -> bool:
	if song_path == "":
		return false
	return NotesUtils.notes_exist(song_path, instrument, current_generation_mode, current_lanes)

func _update_play_button_state():
	if play_button:
		if _current_preview_file_path != "" and _has_notes_for_instrument(_current_preview_file_path, current_instrument):
			play_button.disabled = false
			play_button.text = "Играть"
		else:
			play_button.disabled = true
			play_button.text = "Сначала сгенерируйте ноты"

func set_generation_status(status: String, is_error: bool = false):
	if generation_status_label:
		generation_status_label.text = status
		if is_error:
			generation_status_label.modulate = Color.RED
		else:
			generation_status_label.modulate = Color.YELLOW if status.contains("Генерация") else Color.GREEN

func _update_generation_status():
	if _current_preview_file_path != "":
		if _has_notes_for_instrument(_current_preview_file_path, current_instrument):
			set_generation_status("Готово", false)
		else:
			set_generation_status("Нет нот", false)
	else:
		set_generation_status("", false)

func _on_preview_finished():
	if _current_preview_file_path != "":
		play_song_preview(_current_preview_file_path)
	else:
		pass

func play_song_preview(filepath: String):
	var started_ms := Time.get_ticks_msec()
	if filepath == "":
		printerr("SongDetailsManager.gd: Путь к файлу пуст, воспроизведение невозможно.")
		return

	var file_extension = filepath.get_extension().to_lower()
	if file_extension != "mp3" and file_extension != "wav":
		printerr("SongDetailsManager.gd: Неподдерживаемый формат файла для воспроизведения: " + file_extension)
		return

	if preview_player.playing:
		preview_player.stop()

	_preview_request_id += 1
	var request_id := _preview_request_id
	_current_preview_file_path = filepath
	if MusicManager and MusicManager.has_method("load_audio_stream_async"):
		MusicManager.load_audio_stream_async(filepath, "", func(audio_stream): _on_preview_stream_loaded(filepath, request_id, audio_stream))
	else:
		printerr("SongDetailsManager.gd: MusicManager не поддерживает асинхронную загрузку preview.")
	print("[Perf] SongDetails preview request: %d ms" % [Time.get_ticks_msec() - started_ms])

func _on_preview_stream_loaded(filepath: String, request_id: int, audio_stream: AudioStream) -> void:
	if request_id != _preview_request_id or filepath != _current_preview_file_path:
		return
	if audio_stream:
		preview_player.stream = audio_stream
		var preview_volume_percent = SettingsManager.get_preview_volume()
		preview_player.volume_db = linear_to_db(preview_volume_percent / 100.0)
		preview_player.play()
	else:
		printerr("SongDetailsManager.gd: Не удалось загрузить аудио поток из: " + filepath)

func stop_preview():
	_current_preview_file_path = ""
	if preview_player and preview_player.playing:
		preview_player.stop()

func _update_duration_if_unknown(song_data: Dictionary) -> void:
	if not duration_label:
		return
	var dur = song_data.get("duration", "00:00")
	duration_label.text = "Длительность: " + dur
	if dur != "00:00":
		return
	var path = song_data.get("path", "")
	if path == "":
		return
	if SongLibrary and SongLibrary.has_method("request_duration_update"):
		SongLibrary.request_duration_update(path)

var _tag_sync_in_progress := false

func _apply_tags_if_needed(song_data: Dictionary) -> void:
	var path_for_tags = song_data.get("path", "")
	if path_for_tags == "":
		return
	if _tag_sync_in_progress:
		return
	var current_meta = SongLibrary.get_metadata_for_song(path_for_tags)
	var stem: String = String(path_for_tags).get_file().get_basename()
	var need_title := true
	var need_artist := true
	var need_year := true
	var need_bpm := true
	if not current_meta.is_empty():
		var cur_title = str(current_meta.get("title", ""))
		var cur_artist = str(current_meta.get("artist", "Неизвестен"))
		var cur_year = str(current_meta.get("year", "Н/Д"))
		var cur_bpm = str(current_meta.get("bpm", "Н/Д"))
		need_title = (cur_title == "" or cur_title == stem or cur_title == "Без названия")
		need_artist = (cur_artist == "" or cur_artist == "Неизвестен")
		need_year = (cur_year == "" or cur_year == "Н/Д" or cur_year == "0")
		need_bpm = (cur_bpm == "" or cur_bpm == "Н/Д" or cur_bpm == "-1" or cur_bpm == "0")
	var global_path = ProjectSettings.globalize_path(path_for_tags)
	if not FileAccess.file_exists(global_path):
		return
	if need_title or need_artist or need_year or need_bpm:
		if SongLibrary and SongLibrary.has_method("request_id3_update"):
			SongLibrary.request_id3_update(path_for_tags)

func _apply_cover_texture(song_data: Dictionary) -> void:
	var cover_texture = song_data.get("cover", null)
	if cover_texture and cover_texture is ImageTexture:
		cover_texture_rect.texture = cover_texture
		return
	var path_for_cover = song_data.get("path", "")
	_cover_request_id += 1
	var request_id := _cover_request_id
	if path_for_cover != "":
		var global_path = ProjectSettings.globalize_path(path_for_cover)
		if _embedded_cover_cache.has(global_path):
			cover_texture_rect.texture = _embedded_cover_cache[global_path]
			return
		if _sidecar_cover_cache.has(global_path):
			cover_texture_rect.texture = _sidecar_cover_cache[global_path]
			return
		_start_embedded_cover_load(global_path, request_id)
		_start_sidecar_cover_load(global_path, request_id)
	_request_fallback_cover_texture(request_id)

func _start_embedded_cover_load(global_audio_path: String, request_id: int) -> void:
	if _embedded_cover_thread and _embedded_cover_thread.is_alive():
		return
	if not FileAccess.file_exists(global_audio_path):
		return
	_embedded_cover_request_id = request_id
	_embedded_cover_thread = Thread.new()
	var err := _embedded_cover_thread.start(Callable(self, "_embedded_cover_worker").bind(global_audio_path))
	if err != OK:
		_embedded_cover_thread = null
		return
	call_deferred("_poll_embedded_cover_thread")

func _embedded_cover_worker(global_audio_path: String) -> Dictionary:
	var buf := _read_id3_tag_blob(global_audio_path)
	if buf.is_empty():
		var fa := FileAccess.open(global_audio_path, FileAccess.READ)
		if not fa:
			return {}
		buf = fa.get_buffer(fa.get_length())
		fa.close()
	var mm := MusicMetadata.new()
	mm.set_from_data(buf)
	if mm.cover and mm.cover is ImageTexture:
		var img := mm.cover.get_image()
		if img:
			return {"audio_path": global_audio_path, "image": img}
	return {}

func _read_id3_tag_blob(global_audio_path: String) -> PackedByteArray:
	var fa := FileAccess.open(global_audio_path, FileAccess.READ)
	if not fa:
		return PackedByteArray()
	var header := fa.get_buffer(10)
	if header.size() < 10:
		fa.close()
		return PackedByteArray()
	var is_id3 := header.slice(0, 3).get_string_from_ascii() == "ID3"
	if not is_id3:
		fa.close()
		return PackedByteArray()
	var size_bytes := header.slice(6, 10)
	var size := 0
	for b in size_bytes:
		size = (size << 7) | int(b & 0x7f)
	var tag := fa.get_buffer(size)
	fa.close()
	var data := PackedByteArray()
	data.append_array(header)
	data.append_array(tag)
	return data


func _poll_embedded_cover_thread() -> void:
	if not _embedded_cover_thread:
		return
	if _embedded_cover_thread.is_alive():
		await get_tree().process_frame
		call_deferred("_poll_embedded_cover_thread")
		return
	var result = _embedded_cover_thread.wait_to_finish()
	_embedded_cover_thread = null
	if not result is Dictionary or result.is_empty():
		return
	if _embedded_cover_request_id != _cover_request_id:
		return
	var image = result.get("image", null)
	var audio_path := str(result.get("audio_path", ""))
	if image and image is Image:
		var tex := ImageTexture.create_from_image(image)
		_embedded_cover_cache[audio_path] = tex
		if cover_texture_rect:
			cover_texture_rect.texture = tex

func _start_sidecar_cover_load(global_audio_path: String, request_id: int) -> void:
	if _sidecar_cover_thread and _sidecar_cover_thread.is_alive():
		return
	var candidates := _get_sidecar_cover_candidates(global_audio_path)
	if candidates.is_empty():
		return
	_sidecar_cover_request_id = request_id
	_sidecar_cover_thread = Thread.new()
	var err := _sidecar_cover_thread.start(Callable(self, "_sidecar_cover_worker").bind(global_audio_path, candidates))
	if err != OK:
		_sidecar_cover_thread = null
		return
	call_deferred("_poll_sidecar_cover_thread")

func _get_sidecar_cover_candidates(global_audio_path: String) -> Array:
	var base_dir = global_audio_path.get_base_dir()
	var stem = global_audio_path.get_file().get_basename()
	var candidates := [
		base_dir + "/" + stem + ".jpg",
		base_dir + "/" + stem + ".png",
		base_dir + "/cover.jpg",
		base_dir + "/cover.png"
	]
	var existing := []
	for img_path in candidates:
		if FileAccess.file_exists(img_path):
			existing.append(img_path)
	return existing

func _sidecar_cover_worker(global_audio_path: String, candidates: Array) -> Dictionary:
	for img_path in candidates:
		var image := Image.new()
		var err := image.load(String(img_path))
		if err == OK:
			return {"audio_path": global_audio_path, "image": image}
	return {}

func _poll_sidecar_cover_thread() -> void:
	if not _sidecar_cover_thread:
		return
	if _sidecar_cover_thread.is_alive():
		await get_tree().process_frame
		call_deferred("_poll_sidecar_cover_thread")
		return
	var result = _sidecar_cover_thread.wait_to_finish()
	_sidecar_cover_thread = null
	if not result is Dictionary or result.is_empty():
		return
	if _sidecar_cover_request_id != _cover_request_id:
		return
	var image = result.get("image", null)
	var audio_path := str(result.get("audio_path", ""))
	if image and image is Image:
		var tex := ImageTexture.create_from_image(image)
		_sidecar_cover_cache[audio_path] = tex
		if cover_texture_rect:
			cover_texture_rect.texture = tex

func _request_fallback_cover_texture(request_id: int) -> void:
	var fallback_path := _get_fallback_cover_path()
	if fallback_path == "":
		return
	if _cover_loader == null:
		_cover_loader = ThreadedTextureLoader.get_instance()
	if _cover_loader == null:
		return
	if not _cover_loader_connected:
		_cover_loader.loaded.connect(_on_fallback_cover_loaded)
		_cover_loader_connected = true
	var cached := _cover_loader.get_cached(fallback_path)
	if cached:
		cover_texture_rect.texture = cached
		return
	_cover_loader.request(fallback_path)

func _on_fallback_cover_loaded(path: String, tex: Texture2D) -> void:
	if not cover_texture_rect or tex == null:
		return
	cover_texture_rect.texture = tex
