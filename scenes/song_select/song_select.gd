# scenes/song_select/song_select.gd
extends Control

const SongManager = preload("res://logic/song_manager.gd")

var transitions = null

var song_manager: SongManager = null

var edit_mode: bool = false
var edit_button: Button = null 

var _edit_context = {
	"dialog": null,
	"line_edit": null, 
	"spin_box": null,  
	"song_data": null,
	"field_name": null, 
	"selected_index": -1,
	"type": "" 
}

var song_item_list_ref: ItemList = null
var file_dialog: FileDialog = null
var preview_player: AudioStreamPlayer = null

func _ready():
	print("SongSelect.gd: _ready вызван")
	song_manager = SongManager.new()
	song_manager.load_songs()

	var search_bar = $MainVBox/TopBarHBox/SearchBar
	if search_bar:
		search_bar.text_changed.connect(_on_search_text_changed)
	else:
		push_error("SongSelect.gd: Не найден SearchBar по пути $MainVBox/TopBarHBox/SearchBar")

	var add_btn = $MainVBox/TopBarHBox/AddButton
	if add_btn:
		add_btn.pressed.connect(_on_add_pressed)
	else:
		push_error("SongSelect.gd: Не найден AddButton по пути $MainVBox/TopBarHBox/AddButton")

	edit_button = $MainVBox/TopBarHBox/EditButton
	if edit_button:
		print("SongSelect.gd: EditButton найден.")
		edit_button.pressed.connect(_toggle_edit_mode)
		_update_edit_button_style()
	else:
		push_error("SongSelect.gd: Не найден EditButton по пути $MainVBox/TopBarHBox/EditButton")

	var instr_btn = $MainVBox/TopBarHBox/InstrumentButton
	if instr_btn:
		instr_btn.pressed.connect(_on_instrument_pressed)
	else:
		push_error("SongSelect.gd: Не найден InstrumentButton по пути $MainVBox/TopBarHBox/InstrumentButton")

	var play_btn = $MainVBox/ContentHBox/DetailsVBox/PlayButton
	if play_btn:
		play_btn.pressed.connect(_on_play_pressed)
	else:
		push_error("SongSelect.gd: Не найден PlayButton по пути $MainVBox/ContentHBox/DetailsVBox/PlayButton")

	var generate_btn = $MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton
	if generate_btn:
		generate_btn.pressed.connect(_on_generate_pressed)
	else:
		push_error("SongSelect.gd: Не найден GenerateButton по пути $MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton")

	var delete_btn = $MainVBox/ContentHBox/DetailsVBox/DeleteButton
	if delete_btn:
		delete_btn.pressed.connect(_on_delete_pressed)
	else:
		push_error("SongSelect.gd: Не найден DeleteButton по пути $MainVBox/ContentHBox/DetailsVBox/DeleteButton")

	print("SongSelect.gd: Все основные кнопки подключены ✅")

	var title_label = $MainVBox/ContentHBox/DetailsVBox/TitleLabel
	if title_label:
		title_label.mouse_filter = Control.MOUSE_FILTER_STOP
		title_label.gui_input.connect(_on_gui_input_for_label.bind("title"))
	var artist_label = $MainVBox/ContentHBox/DetailsVBox/ArtistLabel
	if artist_label:
		artist_label.mouse_filter = Control.MOUSE_FILTER_STOP
		artist_label.gui_input.connect(_on_gui_input_for_label.bind("artist"))
	var year_label = $MainVBox/ContentHBox/DetailsVBox/YearLabel
	if year_label:
		year_label.mouse_filter = Control.MOUSE_FILTER_STOP
		year_label.gui_input.connect(_on_gui_input_for_label.bind("year"))
	var bpm_label = $MainVBox/ContentHBox/DetailsVBox/BpmLabel
	if bpm_label:
		bpm_label.mouse_filter = Control.MOUSE_FILTER_STOP
		bpm_label.gui_input.connect(_on_gui_input_for_label.bind("bpm"))
	var cover_rect = $MainVBox/ContentHBox/DetailsVBox/CoverTextureRect
	if cover_rect:
		cover_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		cover_rect.gui_input.connect(_on_gui_input_for_label.bind("cover"))

	print("SongSelect.gd: Проверяем существование родителей (новый путь):")
	var main_vbox = $MainVBox
	if main_vbox:
		var content_hbox = main_vbox.get_node("ContentHBox")
		if content_hbox:
			var song_list_vbox = content_hbox.get_node("SongListVBox")
			if song_list_vbox:
				var song_item_list = song_list_vbox.get_node("SongItemList")
				if song_item_list:
					song_item_list_ref = song_item_list
					_populate_items_from_manager()
					song_item_list.item_selected.connect(_on_song_item_selected)
				else:
					push_error("SongSelect.gd: ОШИБКА: SongItemList НЕ найден внутри SongListVBox по имени!")
			else:
				push_error("SongSelect.gd: ОШИБКА: SongListVBox НЕ найден внутри ContentHBox по имени!")
		else:
			push_error("SongSelect.gd: ОШИБКА: ContentHBox НЕ найден внутри MainVBox по имени!")
	else:
		push_error("SongSelect.gd: ОШИБКА: MainVBox НЕ найден по пути $MainVBox!")

	var list_via_path = $MainVBox/ContentHBox/SongListVBox/SongItemList
	if not list_via_path:
		push_error("SongSelect.gd: Альтернативная проверка: Не найден SongItemList по пути $MainVBox/ContentHBox/SongListVBox/SongItemList")


func set_transitions(transitions_instance):
	transitions = transitions_instance
	print("SongSelect.gd: Transitions инстанс получен")


func _populate_items_from_manager():
	if not song_item_list_ref or not song_manager:
		print("SongSelect.gd: Ошибка: song_item_list_ref или song_manager не инициализированы.")
		return

	song_item_list_ref.clear()

	var songs_list = song_manager.get_songs_list()
	print("SongSelect.gd: Очищен список. Заполняем из SongManager: ", songs_list.size(), " песен.")

	for i in range(songs_list.size()):
		var song_data = songs_list[i]
		var display_text = song_data.get("artist", "Неизвестен") + " — " + song_data.get("title", "Без названия")
		song_item_list_ref.add_item(display_text)

	print("SongSelect.gd: Список песен заполнен из SongManager.")
	_update_song_count_label()


func _on_add_pressed():
	print("Добавить песню (открытие диалога)")

	if file_dialog and file_dialog.is_inside_tree():
		print("FileDialog уже открыт.")
		return

	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.title = "Выберите аудиофайл"
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM

	file_dialog.filters = ["*.mp3; MP3 Audio", "*.wav; WAV Audio"]

	file_dialog.file_selected.connect(_on_file_selected)

	add_child(file_dialog)

	file_dialog.popup_centered()

func _on_file_selected(path):
	print("Выбран файл:", path)

	var file_extension = path.get_extension().to_lower()
	if file_extension != "mp3" and file_extension != "wav":
		print("Неподдерживаемый формат файла: ", file_extension)
		return

	print("Файл прошёл проверку: ", path)

	if file_dialog:
		file_dialog.queue_free()
		file_dialog = null

	var metadata_dict = song_manager.add_song(path)
	if metadata_dict.is_empty():
		print("SongSelect.gd: Ошибка добавления песни через SongManager.")
		return

	if song_item_list_ref:
		_populate_items_from_manager()
		var last_index = song_manager.get_song_count() - 1
		if last_index >= 0:
			song_item_list_ref.select(last_index)
		print("SongSelect.gd: Список обновлён после добавления песни.")
	else:
		print("SongSelect.gd: song_item_list_ref не сохранён!")


func _toggle_edit_mode():
	edit_mode = !edit_mode
	print("SongSelect.gd: Режим редактирования ", "ВКЛЮЧЕН" if edit_mode else "ВЫКЛЮЧЕН")
	_update_edit_button_style()

func _update_edit_button_style():
	if not edit_button:
		return
	if edit_mode:
		edit_button.self_modulate = Color(0.8, 0.8, 1.0, 1.0) 
		edit_button.text = "Редактировать (ON)"
	else:
		edit_button.self_modulate = Color(1.0, 1.0, 1.0, 1.0) 
		edit_button.text = "Редактировать"

func _on_gui_input_for_label(event: InputEvent, field_type: String):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		if edit_mode:
			print("SongSelect.gd: Двойной клик по полю '", field_type, "' в режиме редактирования.")
			match field_type:
				"title":
					_edit_title()
				"artist":
					_edit_field("artist")
				"year":
					_edit_field("year")
				"bpm":
					_edit_bpm()
				"cover":
					_edit_cover()
				_:
					print("SongSelect.gd: Редактирование для поля '", field_type, "' не реализовано.")

func _edit_title():
	var selected_index = -1
	if song_item_list_ref:
		var selected_indices = song_item_list_ref.get_selected_items()
		if selected_indices.size() > 0:
			selected_index = selected_indices[0]

	if selected_index == -1:
		print("SongSelect.gd: Нет выбранной песни для редактирования названия.")
		return

	var songs_list = song_manager.get_songs_list()
	if selected_index >= songs_list.size():
		print("SongSelect.gd: Ошибка индекса при редактировании названия.")
		return

	var song_data = songs_list[selected_index]
	var old_title = song_data.get("title", "")

	_edit_context["song_data"] = song_data
	_edit_context["selected_index"] = selected_index
	_edit_context["type"] = "title"

	var dialog = AcceptDialog.new()
	dialog.title = "Редактировать название"
	dialog.dialog_text = "Введите новое название:"

	var line_edit = LineEdit.new()
	line_edit.text = old_title
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit_context["line_edit"] = line_edit

	var vbox_container = VBoxContainer.new()
	vbox_container.add_child(line_edit)
	dialog.add_child(vbox_container)

	dialog.confirmed.connect(_on_edit_title_confirmed)
	dialog.close_requested.connect(dialog.queue_free)

	_edit_context["dialog"] = dialog

	add_child(dialog)
	dialog.popup_centered()

func _on_edit_title_confirmed():
	var dialog = _edit_context["dialog"]
	var line_edit = _edit_context["line_edit"]
	var song_data = _edit_context["song_data"]
	var selected_index = _edit_context["selected_index"]
	var old_title = song_data.get("title", "")

	if dialog and line_edit:
		var new_title = line_edit.text.strip_edges()
		if new_title != "" and new_title != old_title:
			song_data["title"] = new_title
			if song_item_list_ref and selected_index < song_item_list_ref.item_count:
				var display_text = song_data.get("artist", "Неизвестен") + " — " + new_title
				song_item_list_ref.set_item_text(selected_index, display_text)
			_update_song_details(song_data)
			print("SongSelect.gd: Название обновлено: '", old_title, "' -> '", new_title, "'")

	_cleanup_edit_context()


func _edit_field(field_name: String):
	var selected_index = -1
	if song_item_list_ref:
		var selected_indices = song_item_list_ref.get_selected_items()
		if selected_indices.size() > 0:
			selected_index = selected_indices[0]

	if selected_index == -1:
		print("SongSelect.gd: Нет выбранной песни для редактирования поля ", field_name)
		return

	var songs_list = song_manager.get_songs_list()
	if selected_index >= songs_list.size():
		print("SongSelect.gd: Ошибка индекса при редактировании поля ", field_name)
		return

	var song_data = songs_list[selected_index]
	var old_value = str(song_data.get(field_name, ""))

	_edit_context["song_data"] = song_data
	_edit_context["selected_index"] = selected_index
	_edit_context["field_name"] = field_name
	_edit_context["type"] = "field"

	var dialog = AcceptDialog.new()
	dialog.title = "Редактировать " + field_name.capitalize()
	dialog.dialog_text = "Введите новое значение для '" + field_name + "':"

	var line_edit = LineEdit.new()
	line_edit.text = old_value
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit_context["line_edit"] = line_edit

	var vbox_container = VBoxContainer.new()
	vbox_container.add_child(line_edit)
	dialog.add_child(vbox_container)

	dialog.confirmed.connect(_on_edit_field_confirmed)
	dialog.close_requested.connect(dialog.queue_free)

	_edit_context["dialog"] = dialog

	add_child(dialog)
	dialog.popup_centered()

func _on_edit_field_confirmed():
	var dialog = _edit_context["dialog"]
	var line_edit = _edit_context["line_edit"]
	var song_data = _edit_context["song_data"]
	var selected_index = _edit_context["selected_index"]
	var field_name = _edit_context["field_name"]
	var old_value = str(song_data.get(field_name, ""))

	if dialog and line_edit and song_data and field_name:
		var new_value = line_edit.text.strip_edges()
		if new_value != old_value:
			song_data[field_name] = new_value
			if song_item_list_ref and selected_index < song_item_list_ref.item_count:
				var display_text = song_data.get("artist", "Неизвестен") + " — " + song_data.get("title", "Без названия")
				song_item_list_ref.set_item_text(selected_index, display_text)
			_update_song_details(song_data)
			print("SongSelect.gd: Поле '", field_name, "' обновлено: '", old_value, "' -> '", new_value, "'")

	_cleanup_edit_context()


func _edit_bpm():
	var selected_index = -1
	if song_item_list_ref:
		var selected_indices = song_item_list_ref.get_selected_items()
		if selected_indices.size() > 0:
			selected_index = selected_indices[0]

	if selected_index == -1:
		print("SongSelect.gd: Нет выбранной песни для редактирования BPM.")
		return

	var songs_list = song_manager.get_songs_list()
	if selected_index >= songs_list.size():
		print("SongSelect.gd: Ошибка индекса при редактировании BPM.")
		return

	var song_data = songs_list[selected_index]
	var old_bpm = song_data.get("bpm", "Н/Д")
	var old_bpm_int = -1
	if old_bpm is int:
		old_bpm_int = old_bpm
	elif old_bpm is String and old_bpm.is_valid_int():
		old_bpm_int = old_bpm.to_int()

	_edit_context["song_data"] = song_data
	_edit_context["selected_index"] = selected_index
	_edit_context["type"] = "bpm"

	var dialog = AcceptDialog.new()
	dialog.title = "Редактировать BPM"
	dialog.dialog_text = "Введите новый BPM (60-200):"

	var spin_box = SpinBox.new()
	spin_box.min = 60
	spin_box.max = 200
	spin_box.step = 1
	spin_box.value = old_bpm_int if old_bpm_int != -1 else 120
	spin_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit_context["spin_box"] = spin_box

	var vbox_container = VBoxContainer.new()
	vbox_container.add_child(spin_box)
	dialog.add_child(vbox_container)

	dialog.confirmed.connect(_on_edit_bpm_confirmed)
	dialog.close_requested.connect(dialog.queue_free)

	_edit_context["dialog"] = dialog

	add_child(dialog)
	dialog.popup_centered()

func _on_edit_bpm_confirmed():
	var dialog = _edit_context["dialog"]
	var spin_box = _edit_context["spin_box"]
	var song_data = _edit_context["song_data"]
	var selected_index = _edit_context["selected_index"]
	var old_bpm = song_data.get("bpm", "Н/Д")
	var old_bpm_int = -1
	if old_bpm is int:
		old_bpm_int = old_bpm
	elif old_bpm is String and old_bpm.is_valid_int():
		old_bpm_int = old_bpm.to_int()

	if dialog and spin_box:
		var new_bpm_int = int(spin_box.value)
		if new_bpm_int != old_bpm_int:
			var new_bpm_str = str(new_bpm_int)
			song_data["bpm"] = new_bpm_str
			_update_song_details(song_data)
			print("SongSelect.gd: BPM обновлен: '", old_bpm, "' -> '", new_bpm_str, "'")

	_cleanup_edit_context()

func _cleanup_edit_context():
	_edit_context["dialog"] = null
	_edit_context["line_edit"] = null
	_edit_context["spin_box"] = null
	_edit_context["song_data"] = null
	_edit_context["field_name"] = null
	_edit_context["selected_index"] = -1
	_edit_context["type"] = ""

func _edit_cover():
	print("SongSelect.gd: Редактирование обложки пока не реализовано (двойной клик).")


func _on_edit_pressed():
	_toggle_edit_mode() 

func _on_instrument_pressed():
	print("Выбор инструмента")

func _on_generate_pressed():
	print("Сгенерировать ноты")

func _on_delete_pressed():
	print("Удалить песню")


func _on_play_pressed():
	print("Играть песню")
	if transitions:
		transitions.open_game()
	else:
		print("SongSelect.gd: transitions не установлен!")


func _on_search_text_changed(new_text):
	print("Поиск:", new_text)


func _update_song_count_label():
	var count = song_manager.get_song_count()
	var label = $MainVBox/TopBarHBox/SongCountLabel
	if label:
		label.text = "Песен: %d" % count
		print("SongSelect.gd: Счётчик песен обновлён: %d" % count)
	else:
		print("SongSelect.gd: ОШИБКА: Не найден SongCountLabel по пути $MainVBox/TopBarHBox/SongCountLabel")


func _on_song_item_selected(index):
	print("SongSelect.gd: Выбран элемент с индексом: %d" % index)

	_stop_preview()

	var songs_list = song_manager.get_songs_list()
	var song_data = {}
	if index >= 0 and index < songs_list.size():
		song_data = songs_list[index]
	else:
		print("SongSelect.gd: ОШИБКА: Индекс %d выходит за пределы списка песен SongManager (размер %d)" % [index, songs_list.size()])
		return

	_update_song_details(song_data)

	var song_file_path = song_data.get("path", "")
	if song_file_path != "":
		_play_song_preview(song_file_path)
	else:
		print("SongSelect.gd: Нет пути к файлу для воспроизведения.")


func _update_song_details(song_data):
	print("SongSelect.gd: Обновление информации о песне: %s" % song_data)

	$MainVBox/ContentHBox/DetailsVBox/TitleLabel.text = "Название: " + song_data.get("title", "Н/Д")
	$MainVBox/ContentHBox/DetailsVBox/ArtistLabel.text = "Исполнитель: " + song_data.get("artist", "Н/Д")
	$MainVBox/ContentHBox/DetailsVBox/YearLabel.text = "Год: " + song_data.get("year", "Н/Д")
	$MainVBox/ContentHBox/DetailsVBox/BpmLabel.text = "BPM: " + song_data.get("bpm", "Н/Д")
	$MainVBox/ContentHBox/DetailsVBox/DurationLabel.text = "Длительность: " + song_data.get("duration", "00:00")

	var cover_texture = song_data.get("cover", null)
	if cover_texture and cover_texture is ImageTexture:
		$MainVBox/ContentHBox/DetailsVBox/CoverTextureRect.texture = cover_texture
		print("SongSelect.gd: Установлена обложка из метаданных.")
	else:
		var gray_image = Image.create(400, 400, false, Image.FORMAT_RGBA8)
		gray_image.fill(Color(0.5, 0.5, 0.5, 1.0))
		var gray_texture = ImageTexture.create_from_image(gray_image)
		$MainVBox/ContentHBox/DetailsVBox/CoverTextureRect.texture = gray_texture
		print("SongSelect.gd: Обложка отсутствует, установлен серый квадрат.")

	_update_play_button_state()


func _update_play_button_state():
	var selected_indices = []
	if song_item_list_ref:
		selected_indices = song_item_list_ref.get_selected_items()
	if selected_indices.size() == 0:
		$MainVBox/ContentHBox/DetailsVBox/PlayButton.disabled = true
		$MainVBox/ContentHBox/DetailsVBox/PlayButton.text = "Сначала сгенерируйте ноты"
		return
	$MainVBox/ContentHBox/DetailsVBox/PlayButton.disabled = false
	$MainVBox/ContentHBox/DetailsVBox/PlayButton.text = "Играть"


func _play_song_preview(filepath):
	if filepath == "":
		print("SongSelect.gd: Путь к файлу пуст, воспроизведение невозможно.")
		return

	print("SongSelect.gd: Попытка воспроизвести: ", filepath)

	if not FileAccess.file_exists(filepath):
		print("SongSelect.gd: Файл не найден: ", filepath)
		return

	var file_extension = filepath.get_extension().to_lower()
	if file_extension != "mp3" and file_extension != "wav":
		print("SongSelect.gd: Неподдерживаемый формат файла для воспроизведения: ", file_extension)
		return

	if not preview_player:
		preview_player = AudioStreamPlayer.new()
		add_child(preview_player)

	if preview_player.playing:
		preview_player.stop()

	var audio_stream = null
	if file_extension == "mp3":
		audio_stream = ResourceLoader.load(filepath, "AudioStreamMP3")
	elif file_extension == "wav":
		audio_stream = ResourceLoader.load(filepath, "AudioStreamWAV")

	if audio_stream:
		preview_player.stream = audio_stream
		preview_player.play()
		print("SongSelect.gd: Воспроизведение запущено.")
	else:
		print("SongSelect.gd: Не удалось загрузить аудио поток из: ", filepath)

func _stop_preview():
	if preview_player and preview_player.playing:
		preview_player.stop()
		print("SongSelect.gd: Воспроизведение остановлено.")


func exit_to_main_menu():
	if transitions:
		transitions.exit_to_main_menu()
	else:
		print("SongSelect.gd: transitions не установлен!")
