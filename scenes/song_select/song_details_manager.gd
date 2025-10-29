# scenes/song_select/song_details_manager.gd
class_name SongDetailsManager
extends Node

var title_label: Label = null
var artist_label: Label = null
var year_label: Label = null
var bpm_label: Label = null
var duration_label: Label = null
var cover_texture_rect: TextureRect = null
var play_button: Button = null

var preview_player: AudioStreamPlayer = null

var music_manager = null
var player_data_manager = null
var settings_manager = null

var _current_preview_file_path: String = ""

func setup_ui_nodes(title_lbl: Label, artist_lbl: Label, year_lbl: Label, bpm_lbl: Label, duration_lbl: Label, cover_tex_rect: TextureRect, play_btn: Button):
	title_label = title_lbl
	artist_label = artist_lbl
	year_label = year_lbl
	bpm_label = bpm_lbl
	duration_label = duration_lbl
	cover_texture_rect = cover_tex_rect
	play_button = play_btn

func setup_audio_player(music_mgr):
	music_manager = music_mgr
	preview_player = AudioStreamPlayer.new()
	preview_player.name = "PreviewPlayer"
	preview_player.finished.connect(_on_preview_finished)
	add_child(preview_player)

func set_settings_manager(settings_mgr):
	settings_manager = settings_mgr
	print("SongDetailsManager.gd: SettingsManager передан.")

func set_player_data_manager(player_data_mgr):
	player_data_manager = player_data_mgr

func update_details(song_data: Dictionary):
	print("SongDetailsManager.gd: Обновление информации о песне: %s" % song_data)

	if title_label:
		title_label.text = "Название: " + song_data.get("title", "Н/Д")
	if artist_label:
		artist_label.text = "Исполнитель: " + song_data.get("artist", "Н/Д")
	if year_label:
		year_label.text = "Год: " + song_data.get("year", "Н/Д")
	if bpm_label:
		bpm_label.text = "BPM: " + song_data.get("bpm", "Н/Д")
	if duration_label:
		duration_label.text = "Длительность: " + song_data.get("duration", "00:00")

	var cover_texture = song_data.get("cover", null)
	if cover_texture_rect:
		if cover_texture and cover_texture is ImageTexture:
			cover_texture_rect.texture = cover_texture
			print("SongDetailsManager.gd: Установлена обложка из метаданных.")
		else:
			var fallback_texture = _get_fallback_cover_texture()
			if fallback_texture:
				cover_texture_rect.texture = fallback_texture
				print("SongDetailsManager.gd: Установлена резервная обложка из активного пака.")
			else:
				var gray_image = Image.create(400, 400, false, Image.FORMAT_RGBA8)
				gray_image.fill(Color(0.5, 0.5, 0.5, 1.0))
				var gray_texture = ImageTexture.create_from_image(gray_image)
				cover_texture_rect.texture = gray_texture
				print("SongDetailsManager.gd: Обложка отсутствует, установлен серый квадрат.")

	_update_play_button_state()

func _get_fallback_cover_texture():
	if not player_data_manager:
		print("SongDetailsManager.gd: PlayerDataManager не установлен, невозможно получить резервную обложку.")
		return null

	var active_cover_item_id = player_data_manager.get_active_item("Covers")
	print("SongDetailsManager.gd: Попытка получить резервную обложку из пака: ", active_cover_item_id)

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
				print("SongDetailsManager.gd: Резервная обложка (%s) загружена из: %s" % [fallback_cover_filename, fallback_cover_path])
				return texture
			else:
				print("SongDetailsManager.gd: Ошибка создания ImageTexture из Image для: ", fallback_cover_path)
		else:
			print("SongDetailsManager.gd: Ошибка загрузки Image из файла (%d) : %s" % [error, fallback_cover_path])
	else:
		print("SongDetailsManager.gd: Файл резервной обложки не найден: ", fallback_cover_path)
		var fallback_fallback_path = "res://assets/shop/covers/%s/cover1.png" % folder_name
		if fallback_cover_path != fallback_fallback_path and FileAccess.file_exists(fallback_fallback_path):
			var image_ff = Image.new()
			var error_ff = image_ff.load(fallback_fallback_path)
			if error_ff == OK:
				var texture_ff = ImageTexture.create_from_image(image_ff)
				if texture_ff:
					print("SongDetailsManager.gd: Резервная обложка (cover1.png) загружена из: ", fallback_fallback_path)
					return texture_ff
				else:
					print("SongDetailsManager.gd: Ошибка создания ImageTexture из Image для запасного файла: ", fallback_fallback_path)
			else:
				print("SongDetailsManager.gd: Ошибка загрузки Image из запасного файла (%d) : %s" % [error_ff, fallback_fallback_path])

	return null

func _update_play_button_state():
	if play_button:
		if play_button.get_parent() and play_button.get_parent().get_parent():
			play_button.disabled = false
			play_button.text = "Играть"
		else:
			play_button.disabled = true
			play_button.text = "Сначала сгенерируйте ноты"

func _on_preview_finished():
	if _current_preview_file_path != "":
		print("SongDetailsManager.gd: Воспроизведение предпросмотра завершено, перезапуск: ", _current_preview_file_path)
		play_song_preview(_current_preview_file_path)
	else:
		print("SongDetailsManager.gd: _current_preview_file_path пуст, нечего перезапускать.")

func play_song_preview(filepath: String):
	if filepath == "":
		print("SongDetailsManager.gd: Путь к файлу пуст, воспроизведение невозможно.")
		return

	if not FileAccess.file_exists(filepath):
		print("SongDetailsManager.gd: Файл не найден: ", filepath)
		return

	var file_extension = filepath.get_extension().to_lower()
	if file_extension != "mp3" and file_extension != "wav":
		print("SongDetailsManager.gd: Неподдерживаемый формат файла для воспроизведения: ", file_extension)
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

		if settings_manager:
			var preview_volume_percent = settings_manager.get_preview_volume()
			preview_player.volume_db = linear_to_db(preview_volume_percent / 100.0)
			print("SongDetailsManager.gd: Громкость preview_player установлена из SettingsManager: %.2f dB (%.1f%%)" % [preview_player.volume_db, preview_volume_percent])
		else:
			print("SongDetailsManager.gd: SettingsManager не установлен, используем значение по умолчанию для preview_player.")

		preview_player.play()
		print("SongDetailsManager.gd: Воспроизведение предпросмотра запущено.")
	else:
		print("SongDetailsManager.gd: Не удалось загрузить аудио поток из: ", filepath)

func stop_preview():
	_current_preview_file_path = ""
	if preview_player and preview_player.playing:
		preview_player.stop()
		print("SongDetailsManager.gd: Воспроизведение остановлено.")
