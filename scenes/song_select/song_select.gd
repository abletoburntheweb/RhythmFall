# scenes/song_select/song_select.gd
extends BaseScreen

const SongManager = preload("res://logic/song_manager.gd")
const BPMAnalyzerClient = preload("res://logic/bpm_analyzer_client.gd")
const NoteGeneratorClient = preload("res://logic/note_generator_client.gd") 
const InstrumentSelector = preload("res://scenes/song_select/instrument_selector.gd")

var song_manager: SongManager = null

var edit_button: Button = null 

var song_item_list_ref: ItemList = null
var file_dialog: FileDialog = null

var song_list_manager: SongListManager = preload("res://scenes/song_select/song_list_manager.gd").new()
var song_details_manager: SongDetailsManager = preload("res://scenes/song_select/song_details_manager.gd").new()
var song_edit_manager: SongEditManager = preload("res://scenes/song_select/song_edit_manager.gd").new()
const InstrumentSelectorScene = preload("res://scenes/song_select/instrument_selector.tscn")
var settings_manager: SettingsManager = null

var analyze_bpm_button: Button = null
var bpm_analyzer_client: BPMAnalyzerClient = null
var note_generator_client: NoteGeneratorClient = null  
var song_metadata_manager = null
var instrument_selector: Control = null
var current_instrument: String = "drums"
var current_selected_song_data: Dictionary = {}
var current_displayed_song_path: String = ""

func _ready():
	print("SongSelect.gd: _ready вызван")

	var game_engine = get_parent() 

	if game_engine and \
	   game_engine.has_method("get_music_manager") and \
	   game_engine.has_method("get_transitions") and \
	   game_engine.has_method("get_player_data_manager") and \
	   game_engine.has_method("get_song_metadata_manager") and \
	   game_engine.has_method("get_settings_manager"):
		
		var music_mgr = game_engine.get_music_manager()
		var trans = game_engine.get_transitions()
		var player_data_mgr = game_engine.get_player_data_manager()
		settings_manager = game_engine.get_settings_manager()
		song_metadata_manager = game_engine.get_song_metadata_manager()

		setup_managers(trans, music_mgr, player_data_mgr) 

		print("SongSelect.gd: MusicManager, Transitions, PlayerDataManager, SettingsManager и SongMetadataManager получены через GameEngine.")
	else:
		printerr("SongSelect.gd: Не удалось получить один или несколько необходимых менеджеров (music_manager, transitions, player_data_manager, song_metadata_manager, settings_manager) через GameEngine.")

	current_instrument = "drums"
	
	song_manager = SongManager.new()
	
	if song_metadata_manager: 
		song_manager.set_metadata_manager(song_metadata_manager) 
		print("SongSelect.gd: SongMetadataManager передан в SongManager.")
		song_metadata_manager.metadata_updated.connect(_on_song_metadata_updated)
	else:
		printerr("SongSelect.gd: SongMetadataManager не получен, пользовательские метаданные песен не будут загружаться/сохраняться.")
	
	song_manager.load_songs()

	add_child(song_list_manager)
	song_list_manager.set_song_manager(song_manager)

	add_child(song_details_manager)
	song_details_manager.setup_ui_nodes(
		$MainVBox/ContentHBox/DetailsVBox/TitleLabel,
		$MainVBox/ContentHBox/DetailsVBox/ArtistLabel,
		$MainVBox/ContentHBox/DetailsVBox/YearLabel,
		$MainVBox/ContentHBox/DetailsVBox/BpmLabel,
		$MainVBox/ContentHBox/DetailsVBox/DurationLabel,
		$MainVBox/ContentHBox/DetailsVBox/CoverTextureRect,
		$MainVBox/ContentHBox/DetailsVBox/PlayButton
	)
	song_details_manager.setup_audio_player(music_manager)
	
	if settings_manager: 
		song_details_manager.set_settings_manager(settings_manager)
		print("SongSelect.gd: SettingsManager передан в SongDetailsManager.")
	else:
		printerr("SongSelect.gd: SettingsManager не установлен в SongSelect (получен от GameEngine)!")

	if player_data_manager:
		song_details_manager.set_player_data_manager(player_data_manager)
		print("SongSelect.gd: PlayerDataManager передан в SongDetailsManager.")
	else:
		printerr("SongSelect.gd: player_data_manager (унаследованный из BaseScreen) не установлен! Резервные обложки не будут работать.")

	add_child(song_edit_manager)
	song_edit_manager.set_song_manager(song_manager)
	if song_metadata_manager:
		song_edit_manager.set_metadata_manager(song_metadata_manager)
		print("SongSelect.gd: SongMetadataManager передан в SongEditManager.")
		song_edit_manager.song_edited.connect(_on_song_edited)
	else:
		printerr("SongSelect.gd: SongMetadataManager не получен для передачи в SongEditManager.")

	var song_item_list = $MainVBox/ContentHBox/SongListVBox/SongItemList
	if song_item_list:
		song_item_list_ref = song_item_list 
		song_list_manager.set_item_list(song_item_list)

		song_list_manager.song_selected.connect(_on_song_item_selected_from_manager) 
		song_list_manager.song_list_changed.connect(_on_song_list_changed) 
		song_list_manager.populate_items() 
		
		song_edit_manager.set_item_list(song_item_list_ref) 
	else:
		push_error("SongSelect.gd: SongItemList не найден по пути $MainVBox/ContentHBox/SongListVBox/SongItemList!")

	bpm_analyzer_client = BPMAnalyzerClient.new()
	bpm_analyzer_client.bpm_analysis_started.connect(_on_bpm_analysis_started)
	bpm_analyzer_client.bpm_analysis_completed.connect(_on_bpm_analysis_completed)
	bpm_analyzer_client.bpm_analysis_error.connect(_on_bpm_analysis_error)
	add_child(bpm_analyzer_client)

	note_generator_client = NoteGeneratorClient.new()
	note_generator_client.notes_generation_started.connect(_on_notes_generation_started)
	note_generator_client.notes_generation_completed.connect(_on_notes_generation_completed)
	note_generator_client.notes_generation_error.connect(_on_notes_generation_error)
	add_child(note_generator_client)

	_connect_ui_signals() 

	var instrument_btn = $MainVBox/TopBarHBox/InstrumentButton
	if instrument_btn:
		instrument_btn.text = "Инструмент: Перкуссия"

func _connect_ui_signals():
	
	var back_btn = $MainVBox/BackButton
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
		print("SongSelect.gd: Подключён сигнал pressed кнопки Назад (вызов _on_back_pressed из BaseScreen).")
	else:
		push_error("SongSelect.gd: Не найден BackButton по пути $MainVBox/BackButton!")

	var search_bar = $MainVBox/TopBarHBox/SearchBar
	if search_bar:
		search_bar.text_changed.connect(song_list_manager.filter_items)
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

	analyze_bpm_button = $MainVBox/ContentHBox/DetailsVBox/AnalyzeBPMButton 
	if analyze_bpm_button:
		analyze_bpm_button.pressed.connect(_on_analyze_bpm_pressed)
		print("SongSelect.gd: Подключён сигнал pressed кнопки AnalyzeBPM.")
		analyze_bpm_button.disabled = true
	else:
		push_error("SongSelect.gd: Не найдена кнопка AnalyzeBPM по пути $MainVBox/ContentHBox/DetailsVBox/AnalyzeBPMButton")

	var delete_btn = $MainVBox/ContentHBox/DetailsVBox/DeleteButton
	if delete_btn:
		delete_btn.pressed.connect(_on_delete_pressed)
	else:
		push_error("SongSelect.gd: Не найден DeleteButton по пути $MainVBox/ContentHBox/DetailsVBox/DeleteButton")

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

func _on_song_item_selected_from_manager(song_data: Dictionary):
	print("SongSelect.gd: Получен сигнал song_selected от SongListManager для: %s" % song_data.get("title"))
	current_selected_song_data = song_data
	song_details_manager.stop_preview() 
	song_details_manager.update_details(song_data)
	var song_file_path = song_data.get("path", "")
	if song_file_path != "":
		current_displayed_song_path = song_file_path
		song_details_manager.play_song_preview(song_file_path)
		if analyze_bpm_button:
			analyze_bpm_button.disabled = false
	else:
		print("SongSelect.gd: Нет пути к файлу для воспроизведения.")
		if analyze_bpm_button:
			analyze_bpm_button.disabled = true

	var generate_btn = $MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton
	if generate_btn:
		generate_btn.text = "Сгенерировать ноты"
		generate_btn.disabled = false

func _on_song_list_changed():
	_update_song_count_label()

func _on_add_pressed():
	print("SongSelect.gd: Открыт диалог для добавления песни.")
	_open_file_dialog_for_add()

func _open_file_dialog_for_add():
	if file_dialog and file_dialog.is_inside_tree():
		print("SongSelect.gd: FileDialog уже открыт.")
		return

	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.title = "Выберите аудиофайл"
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = ["*.mp3; MP3 Audio", "*.wav; WAV Audio"]
	file_dialog.file_selected.connect(_on_file_selected_internal)
	add_child(file_dialog)
	file_dialog.popup_centered()

func _on_file_selected_internal(path):
	print("SongSelect.gd: Выбран файл для добавления: ", path)
	var file_extension = path.get_extension().to_lower()
	if file_extension != "mp3" and file_extension != "wav":
		print("SongSelect.gd: Неподдерживаемый формат файла: ", file_extension)
		_cleanup_file_dialog()
		return
	song_list_manager.add_song_from_path(path)
	_cleanup_file_dialog()

func _cleanup_file_dialog():
	if file_dialog and is_instance_valid(file_dialog):
		file_dialog.queue_free()
		file_dialog = null

func _on_gui_input_for_label(event: InputEvent, field_type: String):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		if song_edit_manager.is_edit_mode_active():
			print("SongSelect.gd: Двойной клик по полю '", field_type, "' в режиме редактирования.")
			var selected_indices = []
			if song_item_list_ref:
				selected_indices = song_item_list_ref.get_selected_items()
			if selected_indices.size() > 0:
				var selected_index = selected_indices[0]
				var songs_list = song_manager.get_songs_list()
				if selected_index >= 0 and selected_index < songs_list.size():
					var song_data = songs_list[selected_index]
					song_edit_manager.start_editing(field_type, song_data, selected_index)
				else:
					print("SongSelect.gd: Индекс песни за пределами списка.")
			else:
				print("SongSelect.gd: Нет выбранной песни для редактирования.")

func _toggle_edit_mode():
	song_edit_manager.set_edit_mode(!song_edit_manager.is_edit_mode_active())
	_update_edit_button_style()

func _update_edit_button_style():
	if not edit_button:
		return
	if song_edit_manager.is_edit_mode_active():
		edit_button.self_modulate = Color(0.8, 0.8, 1.0, 1.0)
		edit_button.text = "Редактировать (ВКЛ)"
	else:
		edit_button.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
		edit_button.text = "Редактировать"

func _on_instrument_pressed():
	print("SongSelect.gd: Открыт селектор инструментов.")
	_open_instrument_selector()

func _on_generate_pressed():
	print("SongSelect.gd: Генерация нот для инструмента: ", current_instrument)
	_generate_notes_for_current_song()

func _generate_notes_for_current_song():
	var selected_items = song_item_list_ref.get_selected_items()
	if selected_items.size() == 0:
		print("SongSelect.gd: Нет выбранной песни для генерации нот.")
		return

	var selected_index = selected_items[0]
	var songs_list = song_manager.get_songs_list()
	if selected_index < 0 or selected_index >= songs_list.size():
		print("SongSelect.gd: Индекс выбранной песни вне диапазона.")
		return

	var selected_song_data = songs_list[selected_index]
	var song_path = selected_song_data.get("path", "")
	if song_path == "":
		print("SongSelect.gd: Путь к файлу выбранной песни пуст.")
		return

	var song_bpm = selected_song_data.get("bpm", -1)
	if str(song_bpm) == "-1" or song_bpm == "Н/Д":
		print("SongSelect.gd: BPM не указан для песни. Сначала проанализируйте BPM.")
		return

	note_generator_client.generate_notes(song_path, current_instrument, float(song_bpm))

func _on_notes_generation_started():
	print("SongSelect.gd: Генерация нот начата.")
	var generate_btn = $MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton
	if generate_btn:
		generate_btn.text = "Генерация..."
		generate_btn.disabled = true

func _on_notes_generation_completed(notes_data: Array, bpm_value: float, instrument_type: String):
	print("SongSelect.gd: Генерация нот завершена. Нот: %d, BPM: %f, инструмент: %s" % [notes_data.size(), bpm_value, instrument_type])
	
	var generate_btn = $MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton
	if generate_btn:
		generate_btn.text = "Готово"
		generate_btn.disabled = false

	if song_details_manager:
		song_details_manager._update_play_button_state()
		
	if song_details_manager:
		song_details_manager._update_play_button_state()

func _on_notes_generation_error(error_message: String):
	print("SongSelect.gd: Ошибка генерации нот: ", error_message)
	
	var generate_btn = $MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton
	if generate_btn:
		generate_btn.text = "Ошибка генерации"
		generate_btn.disabled = false

func _open_instrument_selector():
	if instrument_selector and is_instance_valid(instrument_selector):
		instrument_selector.queue_free()
	
	instrument_selector = InstrumentSelectorScene.instantiate()

	if instrument_selector.has_method("set_managers"):
		instrument_selector.set_managers(music_manager)

	if instrument_selector.has_signal("instrument_selected"):
		if not instrument_selector.is_connected("instrument_selected", _on_instrument_selected):
			instrument_selector.connect("instrument_selected", _on_instrument_selected.bind())
	
	if instrument_selector.has_signal("selector_closed"):
		if not instrument_selector.is_connected("selector_closed", _on_instrument_selector_closed):
			instrument_selector.connect("selector_closed", _on_instrument_selector_closed.bind())
	
	get_parent().add_child(instrument_selector)

func _on_instrument_selector_closed():
	if instrument_selector:
		if instrument_selector.is_connected("instrument_selected", _on_instrument_selected):
			instrument_selector.disconnect("instrument_selected", _on_instrument_selected)
		if instrument_selector.is_connected("selector_closed", _on_instrument_selector_closed):
			instrument_selector.disconnect("selector_closed", _on_instrument_selector_closed)
		instrument_selector.queue_free()
		instrument_selector = null

func _on_instrument_selected(instrument_type: String):
	current_instrument = instrument_type
	var instrument_btn = $MainVBox/TopBarHBox/InstrumentButton
	if instrument_btn:
		var instrument_name = "Перкуссия" if instrument_type == "drums" else "Стандартный"
		instrument_btn.text = "Инструмент: " + instrument_name
	print("SongSelect.gd: Выбран инструмент: ", instrument_type)
	
	if song_details_manager:
		song_details_manager.set_current_instrument(current_instrument)
		song_details_manager._update_play_button_state()


func _on_delete_pressed():
	print("SongSelect.gd: Запрос на удаление песни.")
	var selected_items = song_item_list_ref.get_selected_items()
	if selected_items.size() == 0:
		print("SongSelect.gd: Нет выбранной песни для удаления.")
		return

	var selected_index = selected_items[0]
	var songs_list = song_manager.get_songs_list()
	if selected_index < 0 or selected_index >= songs_list.size():
		print("SongSelect.gd: Индекс выбранной песни вне диапазона.")
		return

	var selected_song_data = songs_list[selected_index]
	var song_path = selected_song_data.get("path", "")
	if song_path == "":
		print("SongSelect.gd: Путь к файлу выбранной песни пуст.")
		return
		
	var dir = DirAccess.open("res://")
	if dir:
		var error = dir.remove(song_path)
		if error == OK:
			print("SongSelect.gd: Файл песни удалён: ", song_path)
			if song_metadata_manager:
				song_metadata_manager.remove_metadata(song_path)
				print("SongSelect.gd: Метаданные для песни удалены из SongMetadataManager: ", song_path)
			else:
				printerr("SongSelect.gd: SongMetadataManager недоступен, метаданные не удалены.")

			song_manager.load_songs() 
			song_list_manager.populate_items() 
			_on_song_list_changed()

			var current_selected_items = song_item_list_ref.get_selected_items()
			if current_selected_items.size() == 0 or current_selected_items[0] >= song_item_list_ref.item_count:
				song_details_manager.update_details({}) 
				song_details_manager.stop_preview()
				if analyze_bpm_button:
					analyze_bpm_button.disabled = true
		else:
			printerr("SongSelect.gd: Ошибка удаления файла песни: ", song_path, " Код ошибки: ", error)
	else:
		printerr("SongSelect.gd: Не удалось открыть директорию res:// для удаления файла.")

func _on_analyze_bpm_pressed():
	print("SongSelect.gd: Нажата кнопка AnalyzeBPM.")
	var selected_items = song_item_list_ref.get_selected_items()
	if selected_items.size() == 0:
		print("SongSelect.gd: Нет выбранной песни для анализа BPM.")
		return

	var selected_index = selected_items[0]
	var songs_list = song_manager.get_songs_list()
	if selected_index < 0 or selected_index >= songs_list.size():
		print("SongSelect.gd: Индекс выбранной песни вне диапазона.")
		return

	var selected_song_data = songs_list[selected_index]
	var song_path = selected_song_data.get("path", "")
	if song_path == "":
		print("SongSelect.gd: Путь к файлу выбранной песни пуст.")
		return

	var bpm_label = $MainVBox/ContentHBox/DetailsVBox/BpmLabel
	if bpm_label:
		bpm_label.text = "BPM: Загрузка..."

	bpm_analyzer_client.analyze_bpm(song_path)

func _on_play_pressed():
	print("SongSelect.gd: Играть песню с инструментом: ", current_instrument)
	if transitions:
		transitions.open_game_with_instrument(current_instrument)
	else:
		print("SongSelect.gd: transitions не установлен!")

func _update_song_count_label():
	var label = $MainVBox/TopBarHBox/SongCountLabel
	if song_list_manager:
		song_list_manager.update_song_count_label(label)
	else:
		if label:
			label.text = "Песен: 0"
		printerr("SongSelect.gd: song_list_manager не установлен для обновления счётчика песен.")

func cleanup_before_exit():
	print("SongSelect.gd: cleanup_before_exit вызван. Очищаем ресурсы SongSelect.")
	if song_details_manager:
		song_details_manager.stop_preview()

	if instrument_selector and is_instance_valid(instrument_selector):
		instrument_selector.queue_free()
		instrument_selector = null

	if file_dialog and is_instance_valid(file_dialog):
		file_dialog.queue_free()
		file_dialog = null
		print("SongSelect.gd: FileDialog очищен в cleanup_before_exit.")

	if song_edit_manager:
		pass

func _on_bpm_analysis_started():
	if analyze_bpm_button:
		analyze_bpm_button.disabled = true
	print("SongSelect.gd: BPM анализ начат.")

func _on_bpm_analysis_completed(bpm_value: int):
	var bpm_label = $MainVBox/ContentHBox/DetailsVBox/BpmLabel
	if bpm_label:
		bpm_label.text = "BPM: " + str(bpm_value)

	var selected_items = song_item_list_ref.get_selected_items()
	if selected_items.size() > 0:
		var selected_index = selected_items[0]
		var songs_list = song_manager.get_songs_list()
		if selected_index >= 0 and selected_index < songs_list.size():
			var selected_song_data = songs_list[selected_index]
			var song_path = selected_song_data.get("path", "")

			if song_path != "" and song_metadata_manager: 
				var current_metadata = song_metadata_manager.get_metadata_for_song(song_path)
				if current_metadata.is_empty():
					current_metadata = {
						"title": selected_song_data.get("title", "Без названия"),
						"artist": selected_song_data.get("artist", "Неизвестен"),
						"bpm": str(bpm_value),
						"year": selected_song_data.get("year", "Н/Д"),
						"duration": selected_song_data.get("duration", "00:00"),
						"cover": selected_song_data.get("cover", null)
					}
				else:
					current_metadata["bpm"] = str(bpm_value)

				song_metadata_manager.update_metadata(song_path, current_metadata)
				print("SongSelect.gd: BPM обновлён в SongMetadataManager для: ", song_path)


			elif song_path != "":
				printerr("SongSelect.gd: SongMetadataManager недоступен, BPM не сохранён в пользовательские метаданные.")

	print("SongSelect.gd: BPM анализ завершён. BPM: ", bpm_value)
	if analyze_bpm_button:
		analyze_bpm_button.disabled = false

func _on_bpm_analysis_error(error_message: String):
	var bpm_label = $MainVBox/ContentHBox/DetailsVBox/BpmLabel
	if bpm_label:
		bpm_label.text = "BPM: Ошибка"

	print("SongSelect.gd: Ошибка BPM анализа: ", error_message)
	if analyze_bpm_button:
		analyze_bpm_button.disabled = false


func _on_song_edited(song_data: Dictionary):
	print("SongSelect.gd: Песня отредактирована: ", song_data)
	
	if current_displayed_song_path == song_data.path:
		song_details_manager.update_details(song_data)
		print("SongSelect.gd: Информация справа обновлена для песни: ", song_data.title)

func _on_song_metadata_updated(song_file_path: String):
	print("SongSelect.gd: Метаданные обновлены для: ", song_file_path)
	
	if current_displayed_song_path == song_file_path:
		var songs_list = song_manager.get_songs_list()
		for song in songs_list:
			if song.path == song_file_path:
				song_details_manager.update_details(song)
				print("SongSelect.gd: Информация справа обновлена из кэша метаданных для песни: ", song.title)
				break
				
func get_current_selected_song() -> Dictionary:
	return current_selected_song_data.duplicate()
