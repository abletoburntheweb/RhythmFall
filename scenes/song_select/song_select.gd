# scenes/song_select/song_select.gd
extends Control

var transitions = null

var is_song_selected = false

var song_data_list: Array[Dictionary] = []

var song_item_list_ref: ItemList = null
var file_dialog: FileDialog = null
var preview_player: AudioStreamPlayer = null

func _ready():
	print("SongSelect.gd: _ready вызван")


	var search_bar = $MainVBox/TopBarHBox/SearchBar
	if search_bar:
		print("SongSelect.gd: SearchBar найден.")
		search_bar.text_changed.connect(_on_search_text_changed)
	else:
		push_error("SongSelect.gd: Не найден SearchBar по пути $MainVBox/TopBarHBox/SearchBar")

	var add_btn = $MainVBox/TopBarHBox/AddButton
	if add_btn:
		print("SongSelect.gd: AddButton найден.")
		add_btn.pressed.connect(_on_add_pressed)
	else:
		push_error("SongSelect.gd: Не найден AddButton по пути $MainVBox/TopBarHBox/AddButton")

	var edit_btn = $MainVBox/TopBarHBox/EditButton
	if edit_btn:
		print("SongSelect.gd: EditButton найден.")
		edit_btn.pressed.connect(_on_edit_pressed)
	else:
		push_error("SongSelect.gd: Не найден EditButton по пути $MainVBox/TopBarHBox/EditButton")

	var instr_btn = $MainVBox/TopBarHBox/InstrumentButton
	if instr_btn:
		print("SongSelect.gd: InstrumentButton найден.")
		instr_btn.pressed.connect(_on_instrument_pressed)
	else:
		push_error("SongSelect.gd: Не найден InstrumentButton по пути $MainVBox/TopBarHBox/InstrumentButton")

	var play_btn = $MainVBox/ContentHBox/DetailsVBox/PlayButton
	if play_btn:
		print("SongSelect.gd: PlayButton найден.")
		play_btn.pressed.connect(_on_play_pressed)
	else:
		push_error("SongSelect.gd: Не найден PlayButton по пути $MainVBox/ContentHBox/DetailsVBox/PlayButton")

	var generate_btn = $MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton
	if generate_btn:
		print("SongSelect.gd: GenerateNotesButton найден.")
		generate_btn.pressed.connect(_on_generate_pressed)
	else:
		push_error("SongSelect.gd: Не найден GenerateButton по пути $MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton")

	var delete_btn = $MainVBox/ContentHBox/DetailsVBox/DeleteButton
	if delete_btn:
		print("SongSelect.gd: DeleteButton найден.")
		delete_btn.pressed.connect(_on_delete_pressed)
	else:
		push_error("SongSelect.gd: Не найден DeleteButton по пути $MainVBox/ContentHBox/DetailsVBox/DeleteButton")

	print("SongSelect.gd: Все основные кнопки подключены ✅")

	print("SongSelect.gd: Проверяем существование родителей (новый путь):")
	var main_vbox = $MainVBox
	if main_vbox:
		print("  - MainVBox найден по пути $MainVBox.")
		var content_hbox = main_vbox.get_node("ContentHBox")
		if content_hbox:
			print("  - ContentHBox найден внутри MainVBox.")
			var song_list_vbox = content_hbox.get_node("SongListVBox")
			if song_list_vbox:
				print("  - SongListVBox найден внутри ContentHBox.")
				var song_item_list = song_list_vbox.get_node("SongItemList")
				if song_item_list:
					print("  - SongItemList найден внутри SongListVBox по имени!")
					print("SongSelect.gd: SongItemList найден по указанному пути (через путь).")
					song_item_list_ref = song_item_list
					_populate_demo_items(song_item_list)
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
	if list_via_path:
		print("SongSelect.gd: Альтернативная проверка: SongItemList найден по пути $MainVBox/ContentHBox/SongListVBox/SongItemList")
	else:
		push_error("SongSelect.gd: Альтернативная проверка: Не найден SongItemList по пути $MainVBox/ContentHBox/SongListVBox/SongItemList")


func set_transitions(transitions_instance):
	transitions = transitions_instance
	print("SongSelect.gd: Transitions инстанс получен")


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

	var target_dir = "res://songs/" 
	var target_path = target_dir + path.get_file() 

	var base_dir_path = "res://"
	var base_dir = DirAccess.open(base_dir_path)
	if not base_dir:
		print("SongSelect.gd: ОШИБКА: Не удалось открыть корневую директорию проекта: ", base_dir_path)
		return

	var songs_dir_name = "songs"
	if not base_dir.dir_exists(songs_dir_name): 
		print("SongSelect.gd: Создаём папку: ", target_dir)
		var error = base_dir.make_dir(songs_dir_name)
		if error != OK:
			print("SongSelect.gd: ОШИБКА при создании папки: ", target_dir, ", код ошибки: ", error)
			return
		base_dir = DirAccess.open(base_dir_path)
		if not base_dir:
			print("SongSelect.gd: ОШИБКА: Не удалось повторно открыть корневую директорию после создания папки: ", base_dir_path)
			return

	var copy_result = base_dir.copy(path, target_path) 
	if copy_result != OK:
		print("SongSelect.gd: ОШИБКА при копировании файла: ", path, " -> ", target_path, ", код ошибки: ", copy_result)
		return
	else:
		print("SongSelect.gd: Файл скопирован в: ", target_path)

	if song_item_list_ref:
		var item_index = song_item_list_ref.item_count 
		song_item_list_ref.add_item(path.get_file())

		var song_info = {
			"path": target_path, 
			"title": path.get_file(),
			"artist": "Неизвестен",
			"year": "Н/Д",
			"bpm": "Н/Д",
			"duration": "00:00"
		}

		song_data_list.append(song_info)

		print("SongSelect.gd: Файл добавлен в список: ", path.get_file(), " по индексу ", item_index)
		print("SongSelect.gd: Данные о песне сохранены: ", song_info)
		_update_song_count_label()
	else:
		print("SongSelect.gd: song_item_list_ref не сохранён!")





func _on_edit_pressed():
	print("Редактировать песню")

func _on_instrument_pressed():
	print("Выбор инструмента")

func _on_play_pressed():
	print("Играть песню")
	if transitions:
		transitions.open_game()
	else:
		print("SongSelect.gd: transitions не установлен!")

func _on_generate_pressed():
	print("Сгенерировать ноты")

func _on_delete_pressed():
	print("Удалить песню")

func _on_search_text_changed(new_text):
	print("Поиск:", new_text)



func _populate_demo_items(item_list: ItemList):
	item_list.clear()
	song_data_list.clear()

	print("SongSelect.gd: Очищен список.")
	for i in range(5):
		var song_name = "Песня %d" % (i + 1)
		item_list.add_item(song_name)

		var demo_song_info = {
			"path": "",
			"title": song_name,
			"artist": "Неизвестен",
			"year": "Н/Д",
			"bpm": "Н/Д",
			"duration": "00:00"
		}
		song_data_list.append(demo_song_info)

	print("SongSelect.gd: Добавлены демо-песни в количество %d штук." % item_list.item_count)
	_update_song_count_label()

func _update_song_count_label():
	var count = song_data_list.size()
	var label = $MainVBox/TopBarHBox/SongCountLabel
	if label:
		label.text = "Песен: %d" % count
		print("SongSelect.gd: Счётчик песен обновлён: %d" % count)
	else:
		print("SongSelect.gd: ОШИБКА: Не найден SongCountLabel по пути $MainVBox/TopBarHBox/SongCountLabel")


func _on_song_item_selected(index):
	print("SongSelect.gd: Выбран элемент с индексом: %d" % index)

	_stop_preview()

	var song_data = {}
	if index >= 0 and index < song_data_list.size():
		song_data = song_data_list[index]
	else:
		print("SongSelect.gd: ОШИБКА: Индекс %d выходит за пределы song_data_list (размер %d)" % [index, song_data_list.size()])
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

	$MainVBox/ContentHBox/DetailsVBox/CoverTextureRect.texture = null

	is_song_selected = true

	_update_play_button_state()


func _update_play_button_state():
	if not is_song_selected:
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
