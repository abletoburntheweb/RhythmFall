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

func update_details(song_data: Dictionary):
	
	if title_label:
		title_label.text = "Название: " + song_data.get("title", "Н/Д")
	if artist_label:
		artist_label.text = "Исполнитель: " + song_data.get("artist", "Н/Д")
	if year_label:
		year_label.text = "Год: " + song_data.get("year", "Н/Д")
	if bpm_label:
		bpm_label.text = "BPM: " + song_data.get("bpm", "Н/Д")
	_update_duration_if_unknown(song_data)
	if title_label or artist_label or year_label:
		_apply_tags_if_needed(song_data)
	
	if primary_genre_label:
		var genre = song_data.get("primary_genre", "Н/Д")
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
		var image = Image.new()
		var error = image.load(fallback_cover_path)
		if error == OK:
			var texture = ImageTexture.create_from_image(image)
			if texture:
				return texture
			else:
				printerr("SongDetailsManager.gd: Ошибка создания ImageTexture из Image для: " + fallback_cover_path)
		else:
			printerr("SongDetailsManager.gd: Ошибка загрузки Image из файла (%d) : %s" % [error, fallback_cover_path])
	else:
		printerr("SongDetailsManager.gd: Файл резервной обложки не найден: " + fallback_cover_path)
		var fallback_fallback_path = "res://assets/shop/covers/%s/cover1.png" % folder_name
		if fallback_cover_path != fallback_fallback_path and FileAccess.file_exists(fallback_fallback_path):
			var image_ff = Image.new()
			var error_ff = image_ff.load(fallback_fallback_path)
			if error_ff == OK:
				var texture_ff = ImageTexture.create_from_image(image_ff)
				if texture_ff:
					return texture_ff
				else:
					printerr("SongDetailsManager.gd: Ошибка создания ImageTexture из Image для запасного файла: " + fallback_fallback_path)
			else:
				printerr("SongDetailsManager.gd: Ошибка загрузки Image из запасного файла (%d) : %s" % [error_ff, fallback_fallback_path])

	return null

func _has_notes_for_instrument(song_path: String, instrument: String) -> bool:
	if song_path == "":
		return false
	var base_name = song_path.get_file().get_basename()
	var notes_filename = "%s_%s_%s_lanes%d.json" % [
		base_name,
		instrument,
		current_generation_mode.to_lower(),
		current_lanes
	]
	var notes_path = "user://notes/%s/%s" % [base_name, notes_filename]
	
	var notes_file_exists = FileAccess.file_exists(notes_path)
	return notes_file_exists

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
	if filepath == "":
		printerr("SongDetailsManager.gd: Путь к файлу пуст, воспроизведение невозможно.")
		return

	if not FileAccess.file_exists(filepath):
		printerr("SongDetailsManager.gd: Файл не найден: " + filepath)
		return

	var file_extension = filepath.get_extension().to_lower()
	if file_extension != "mp3" and file_extension != "wav":
		printerr("SongDetailsManager.gd: Неподдерживаемый формат файла для воспроизведения: " + file_extension)
		return

	if preview_player.playing:
		preview_player.stop()

	var audio_stream = null
	if file_extension == "mp3":
		audio_stream = ResourceLoader.load(filepath, "AudioStreamMP3")
	elif file_extension == "wav":
		audio_stream = ResourceLoader.load(filepath, "AudioStreamWAV")

	if audio_stream:
		preview_player.stream = audio_stream
		_current_preview_file_path = filepath

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
	var ext = path.get_extension().to_lower()
	var stream = null
	if ext == "mp3":
		stream = ResourceLoader.load(path, "AudioStreamMP3")
	elif ext == "wav":
		stream = ResourceLoader.load(path, "AudioStreamWAV")
	if stream and stream is AudioStream:
		var seconds = stream.get_length()
		if seconds > 0:
			var minutes_i = int(seconds) / 60
			var seconds_i = int(seconds) % 60
			var dur_str = "%02d:%02d" % [minutes_i, seconds_i]
			duration_label.text = "Длительность: " + dur_str
			SongLibrary.update_metadata(path, {"duration": dur_str})

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
	# Не затираем ручные правки: если в кеше уже есть осмысленные значения, оставляем их
	if not current_meta.is_empty():
		var cur_title = String(current_meta.get("title", ""))
		var cur_artist = String(current_meta.get("artist", "Неизвестен"))
		var cur_year = String(current_meta.get("year", "Н/Д"))
		need_title = (cur_title == "" or cur_title == stem or cur_title == "Без названия")
		need_artist = (cur_artist == "" or cur_artist == "Неизвестен")
		need_year = (cur_year == "" or cur_year == "Н/Д" or cur_year == "0")
	var global_path = ProjectSettings.globalize_path(path_for_tags)
	if not FileAccess.file_exists(global_path):
		return
	var fa = FileAccess.open(global_path, FileAccess.READ)
	if not fa:
		return
	var buf = fa.get_buffer(fa.get_length())
	fa.close()
	var mm = MusicMetadata.new()
	mm.set_from_data(buf)
	var updated = {}
	if mm.title != "" and need_title:
		if title_label and ("Название: " + mm.title != title_label.text):
			title_label.text = "Название: " + mm.title
		updated["title"] = mm.title
	if mm.artist != "" and need_artist:
		if artist_label and ("Исполнитель: " + mm.artist != artist_label.text):
			artist_label.text = "Исполнитель: " + mm.artist
		updated["artist"] = mm.artist
	if mm.year != 0 and need_year:
		var y = str(mm.year)
		if year_label and ("Год: " + y != year_label.text):
			year_label.text = "Год: " + y
		updated["year"] = y
	if not updated.is_empty():
		_tag_sync_in_progress = true
		# Обновляем только отличающиеся значения
		var diff := {}
		for k in updated.keys(): 
			if not current_meta.has(k) or String(current_meta[k]) != String(updated[k]):
				diff[k] = updated[k]
		if not diff.is_empty():
			SongLibrary.update_metadata(path_for_tags, diff)
		_tag_sync_in_progress = false

func _apply_cover_texture(song_data: Dictionary) -> void:
	var cover_texture = song_data.get("cover", null)
	if cover_texture and cover_texture is ImageTexture:
		cover_texture_rect.texture = cover_texture
		return
	var path_for_cover = song_data.get("path", "")
	var applied = false
	if path_for_cover != "":
		var global_path = ProjectSettings.globalize_path(path_for_cover)
		if FileAccess.file_exists(global_path):
			var fa = FileAccess.open(global_path, FileAccess.READ)
			if fa:
				var buf = fa.get_buffer(fa.get_length())
				fa.close()
				var mm = MusicMetadata.new()
				mm.set_from_data(buf)
				if mm.cover and mm.cover is ImageTexture:
					cover_texture_rect.texture = mm.cover
					applied = true
			# Sidecar изображения рядом с файлом: <basename>.jpg/.png или cover.jpg/.png
			if not applied:
				var base_dir = global_path.get_base_dir()
				var stem = path_for_cover.get_file().get_basename()
				var candidates = [
					base_dir + "/" + stem + ".jpg",
					base_dir + "/" + stem + ".png",
					base_dir + "/cover.jpg",
					base_dir + "/cover.png"
				]
				for img_path in candidates:
					if FileAccess.file_exists(img_path):
						var img_file = FileAccess.open(img_path, FileAccess.READ)
						if img_file:
							var img_buf = img_file.get_buffer(img_file.get_length())
							img_file.close()
							var image = Image.new()
							var ok = image.load_png_from_buffer(img_buf)
							if ok != OK:
								ok = image.load_jpg_from_buffer(img_buf)
							if ok == OK:
								var tex = ImageTexture.create_from_image(image)
								cover_texture_rect.texture = tex
								applied = true
								break
	if applied:
		return
	var fallback_texture = _get_fallback_cover_texture()
	if fallback_texture:
		cover_texture_rect.texture = fallback_texture
