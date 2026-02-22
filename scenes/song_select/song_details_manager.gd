# scenes/song_select/song_details_manager.gd
class_name SongDetailsManager
extends Node

var title_label: Label = null
var artist_label: Label = null
var year_label: Label = null
var bpm_label: Label = null
var duration_label: Label = null
var primary_genre_label: Label = null
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

func setup_ui_nodes(title_lbl: Label, artist_lbl: Label, year_lbl: Label, bpm_lbl: Label, duration_lbl: Label, genre_lbl: Label, cover_tex_rect: TextureRect, play_btn: Button):
	title_label = title_lbl
	artist_label = artist_lbl
	year_label = year_lbl
	bpm_label = bpm_lbl
	duration_label = duration_lbl
	primary_genre_label = genre_lbl
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
	if duration_label:
		var dur = song_data.get("duration", "00:00")
		duration_label.text = "Длительность: " + dur
		if dur == "00:00":
			var path = song_data.get("path", "")
			if path != "":
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
	if title_label or artist_label or year_label:
		var path_for_tags = song_data.get("path", "")
		var title_val = song_data.get("title", "")
		var artist_val = song_data.get("artist", "Неизвестен")
		var need_tags = false
		var stem = ""
		if path_for_tags != "":
			stem = path_for_tags.get_file().get_basename()
		if title_val == stem or artist_val == "Неизвестен":
			need_tags = true
		if need_tags and path_for_tags != "":
			var global_path = ProjectSettings.globalize_path(path_for_tags)
			if FileAccess.file_exists(global_path):
				var fa = FileAccess.open(global_path, FileAccess.READ)
				if fa:
					var buf = fa.get_buffer(fa.get_length())
					fa.close()
					var mm = MusicMetadata.new()
					mm.set_from_data(buf)
					var updated = {}
					if mm.title != "" and title_label:
						title_label.text = "Название: " + mm.title
						updated["title"] = mm.title
					if mm.artist != "" and artist_label:
						artist_label.text = "Исполнитель: " + mm.artist
						updated["artist"] = mm.artist
					if mm.year != 0 and year_label:
						year_label.text = "Год: " + str(mm.year)
						updated["year"] = str(mm.year)
					if not updated.is_empty():
						SongLibrary.update_metadata(path_for_tags, updated)
	
	if primary_genre_label:
		var genre = song_data.get("primary_genre", "Н/Д")
		if genre == "unknown":
			genre = "Н/Д"
		primary_genre_label.text = "Жанр: " + genre

	var cover_texture = song_data.get("cover", null)
	if cover_texture_rect:
		if cover_texture and cover_texture is ImageTexture:
			cover_texture_rect.texture = cover_texture
		else:
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
			if not applied:
				var fallback_texture = _get_fallback_cover_texture()
				if fallback_texture:
					cover_texture_rect.texture = fallback_texture
				else:
					var gray_image = Image.create(400, 400, false, Image.FORMAT_RGBA8)
					gray_image.fill(Color(0.5, 0.5, 0.5, 1.0))
					var gray_texture = ImageTexture.create_from_image(gray_image)
					cover_texture_rect.texture = gray_texture

	_update_play_button_state()
	_update_generation_status() 

func _get_fallback_cover_texture():
	var active_cover_item_id = PlayerDataManager.get_active_item("Covers")

	var folder_name_map = {
		"covers_default": "default_covers"
	}
	var folder_name = folder_name_map.get(active_cover_item_id, active_cover_item_id.replace("covers_", ""))

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
