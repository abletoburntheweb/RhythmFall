# scenes/song_select/song_select.gd
extends BaseScreen

const SongManager = preload("res://logic/song_manager.gd")
const ServerClients = preload("res://logic/server_clients.gd")
const ManualTrackInputScene = preload("res://scenes/song_select/manual_track_input.tscn")
const InstrumentSelectorScene = preload("res://scenes/song_select/instrument_selector.tscn")
const GenerationSelectorScene = preload("res://scenes/song_select/generation_selector.tscn")

var song_manager: SongManager = SongManager.new()
var server_clients: ServerClients = ServerClients.new()
var song_list_manager: SongListManager = preload("res://scenes/song_select/song_list_manager.gd").new()
var song_details_manager: SongDetailsManager = preload("res://scenes/song_select/song_details_manager.gd").new()
var song_edit_manager: SongEditManager = preload("res://scenes/song_select/song_edit_manager.gd").new()
var results_manager: ResultsManager = preload("res://scenes/song_select/results_manager.gd").new()

var song_metadata_manager = SongMetadataManager 

@onready var edit_button: Button = $MainVBox/TopBarHBox/EditButton
@onready var filter_by_letter: OptionButton = $MainVBox/TopBarHBox/FilterByLetter
@onready var song_item_list_ref: ItemList = $MainVBox/ContentHBox/SongListVBox/SongItemList
@onready var analyze_bpm_button: Button = $MainVBox/ContentHBox/DetailsVBox/AnalyzeBPMButton
@onready var results_button: Button = $MainVBox/ContentHBox/DetailsVBox/ResultsButton
@onready var clear_results_button: Button = $ClearResultsButton

var instrument_selector: Control = null
var generation_selector: Control = null
var file_dialog: FileDialog = null
var manual_track_input_dialog: Control = null

var current_instrument: String = "drums"
var current_generation_mode: String = "basic"
var current_selected_song_data: Dictionary = {}
var current_displayed_song_path: String = ""
var pending_manual_identification_song_path: String = ""
var pending_manual_identification_bpm: float = -1.0
var pending_manual_identification_lanes: int = -1
var pending_manual_identification_sync_tolerance: float = -1.0

func _ready():
	var game_engine = get_parent()
	var music_mgr = game_engine.get_music_manager()
	var trans = game_engine.get_transitions()
	
	song_metadata_manager = SongMetadataManager
	
	setup_managers(trans, music_mgr)  
	
	song_metadata_manager.metadata_updated.connect(_on_song_metadata_updated)
		
	song_manager.load_songs()
	
	add_child(song_list_manager)
	song_list_manager.set_song_manager(song_manager)
	song_list_manager.set_item_list(song_item_list_ref)
	song_list_manager.song_selected.connect(_on_song_item_selected_from_manager)
	song_list_manager.song_list_changed.connect(_on_song_list_changed)
	song_list_manager.populate_items_grouped()
	
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
	
	add_child(song_edit_manager)
	song_edit_manager.set_song_manager(song_manager)
	song_edit_manager.set_item_list(song_item_list_ref)
	song_edit_manager.song_edited.connect(_on_song_edited_from_manager)
		
	add_child(server_clients)
	server_clients.bpm_analysis_started.connect(_on_bpm_analysis_started)
	server_clients.bpm_analysis_completed.connect(_on_bpm_analysis_completed)
	server_clients.bpm_analysis_error.connect(_on_bpm_analysis_error)
	server_clients.notes_generation_started.connect(_on_notes_generation_started)
	server_clients.notes_generation_completed.connect(_on_notes_generation_completed)
	server_clients.notes_generation_error.connect(_on_notes_generation_error)
	server_clients.manual_identification_needed.connect(_on_manual_identification_needed)
	server_clients.genres_detection_completed.connect(_on_genres_detection_completed)
	server_clients.genres_detection_error.connect(_on_genres_detection_error)
	
	_connect_ui_signals()
	
	$MainVBox/TopBarHBox/InstrumentButton.text = "Инструмент: Перкуссия"
	$MainVBox/TopBarHBox/GenerationModeButton.text = "Режим генерации: Базовый"
	filter_by_letter.item_selected.connect(_on_filter_by_letter_selected)
	analyze_bpm_button.disabled = true
	results_button.disabled = true
	clear_results_button.disabled = true

func _connect_ui_signals():
	$MainVBox/BackButton.pressed.connect(_on_back_pressed)
	$MainVBox/TopBarHBox/SearchBar.text_changed.connect(song_list_manager.filter_items)
	$MainVBox/TopBarHBox/AddButton.pressed.connect(_on_add_pressed)
	edit_button.pressed.connect(_toggle_edit_mode)
	_update_edit_button_style()
	$MainVBox/TopBarHBox/InstrumentButton.pressed.connect(_on_instrument_pressed)
	$MainVBox/TopBarHBox/GenerationModeButton.pressed.connect(_on_generation_mode_pressed)
	$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.pressed.connect(_on_generate_pressed)
	analyze_bpm_button.pressed.connect(_on_analyze_bpm_pressed)
	$MainVBox/ContentHBox/DetailsVBox/DeleteButton.pressed.connect(_on_delete_pressed)
	results_button.pressed.connect(_on_results_pressed)
	clear_results_button.pressed.connect(_on_clear_results_pressed)
	
	$MainVBox/ContentHBox/DetailsVBox/PlayButton.pressed.connect(_on_play_pressed)
	
	$MainVBox/ContentHBox/DetailsVBox/TitleLabel.mouse_filter = Control.MOUSE_FILTER_STOP
	$MainVBox/ContentHBox/DetailsVBox/TitleLabel.gui_input.connect(_on_gui_input_for_label.bind("title"))
	$MainVBox/ContentHBox/DetailsVBox/ArtistLabel.mouse_filter = Control.MOUSE_FILTER_STOP
	$MainVBox/ContentHBox/DetailsVBox/ArtistLabel.gui_input.connect(_on_gui_input_for_label.bind("artist"))
	$MainVBox/ContentHBox/DetailsVBox/YearLabel.mouse_filter = Control.MOUSE_FILTER_STOP
	$MainVBox/ContentHBox/DetailsVBox/YearLabel.gui_input.connect(_on_gui_input_for_label.bind("year"))
	$MainVBox/ContentHBox/DetailsVBox/BpmLabel.mouse_filter = Control.MOUSE_FILTER_STOP
	$MainVBox/ContentHBox/DetailsVBox/BpmLabel.gui_input.connect(_on_gui_input_for_label.bind("bpm"))
	$MainVBox/ContentHBox/DetailsVBox/CoverTextureRect.mouse_filter = Control.MOUSE_FILTER_STOP
	$MainVBox/ContentHBox/DetailsVBox/CoverTextureRect.gui_input.connect(_on_gui_input_for_label.bind("cover"))

func _on_bpm_analysis_started():
	print("SongSelect.gd: BPM анализ начат.")
	analyze_bpm_button.text = "Вычисление..."
	analyze_bpm_button.disabled = true

func _on_bpm_analysis_completed(bpm_value: int):
	print("SongSelect.gd: BPM анализ завершён. BPM: ", bpm_value)
	$MainVBox/ContentHBox/DetailsVBox/BpmLabel.text = "BPM: " + str(bpm_value)
	analyze_bpm_button.text = "Готово"
	analyze_bpm_button.disabled = false
	
	var selected_items = song_item_list_ref.get_selected_items()
	if selected_items.size() > 0:
		var selected_song_data = song_list_manager.get_song_data_by_item_list_index(selected_items[0])
		var song_path = selected_song_data.get("path", "")
		
		if song_path != "":
			var metadata = song_metadata_manager.get_metadata_for_song(song_path)
			if metadata.is_empty():
				metadata = {
					"title": selected_song_data.get("title", "Без названия"),
					"artist": selected_song_data.get("artist", "Неизвестен"),
					"bpm": str(bpm_value),
					"year": selected_song_data.get("year", "Н/Д"),
					"duration": selected_song_data.get("duration", "00:00")
				}
			else:
				metadata["bpm"] = str(bpm_value)
			song_metadata_manager.update_metadata(song_path, metadata)
			print("SongSelect.gd: BPM обновлён в SongMetadataManager для: ", song_path)

func _on_bpm_analysis_error(error_message: String):
	print("SongSelect.gd: Ошибка BPM анализа: ", error_message)
	$MainVBox/ContentHBox/DetailsVBox/BpmLabel.text = "BPM: Ошибка"
	analyze_bpm_button.text = "Ошибка вычисления"
	analyze_bpm_button.disabled = false

func _on_notes_generation_started():
	print("SongSelect.gd: Генерация нот начата.")
	$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.text = "Генерация..."
	$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.disabled = true

func _on_notes_generation_completed(notes_data: Array, bpm_value: float, instrument_type: String):
	print("SongSelect.gd: Генерация нот завершена. Нот: %d, BPM: %f, инструмент: %s" % [notes_data.size(), bpm_value, instrument_type])
	$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.text = "Готово"
	$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.disabled = false
	song_details_manager._update_play_button_state()
	
	var game_engine = get_parent()
	var achievement_system = game_engine.get_achievement_system()
	achievement_system.on_notes_generated()

func _on_notes_generation_error(error_message: String):
	print("SongSelect.gd: Ошибка генерации нот: ", error_message)
	$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.text = "Ошибка генерации"
	$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.disabled = false
	song_details_manager.set_generation_status("Ошибка: %s" % error_message, true)

func _on_manual_identification_needed(song_path: String):
	print("SongSelect.gd: Получен сигнал manual_identification_needed для: ", song_path)
	pending_manual_identification_song_path = song_path
	var song_bpm = current_selected_song_data.get("bpm", -1)
	if str(song_bpm) == "-1" or song_bpm == "Н/Д":
		print("SongSelect.gd: Ошибка: BPM неизвестен при ожидании ручной идентификации.")
		return
	pending_manual_identification_bpm = float(song_bpm)
	pending_manual_identification_lanes = -1
	pending_manual_identification_sync_tolerance = -1.0
	_show_manual_track_input("Неизвестен", "Н/Д")

func _on_genres_detection_completed(artist: String, title: String, genres: Array):
	print("SongSelect.gd: Жанры получены для '%s - %s': %s" % [artist, title, genres])
	server_clients.generate_notes(
		pending_manual_identification_song_path,
		current_instrument,
		pending_manual_identification_bpm,
		pending_manual_identification_lanes,
		pending_manual_identification_sync_tolerance,
		false,
		artist,
		title,
		current_generation_mode
	)
	pending_manual_identification_song_path = ""
	pending_manual_identification_bpm = -1.0
	pending_manual_identification_lanes = -1
	pending_manual_identification_sync_tolerance = -1.0

func _on_genres_detection_error(error_message: String):
	print("SongSelect.gd: Ошибка получения жанров: ", error_message)
	$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.text = "Ошибка жанров"
	$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.disabled = false
	pending_manual_identification_song_path = ""
	pending_manual_identification_bpm = -1.0
	pending_manual_identification_lanes = -1
	pending_manual_identification_sync_tolerance = -1.0

func _on_filter_by_letter_selected(index: int):
	if song_edit_manager.is_edit_mode_active(): return
	var selected_text = filter_by_letter.get_item_text(index)
	var mode = "title" if selected_text == "Название" else "artist"
	song_list_manager.set_filter_mode(mode)
	song_list_manager.populate_items_grouped()

func _update_filters_visibility():
	var is_edit_mode = song_edit_manager.is_edit_mode_active()
	filter_by_letter.visible = !is_edit_mode
	if is_edit_mode:
		song_list_manager.set_filter_mode("title")
		filter_by_letter.select(0)

func _on_song_edited_from_manager(song_data: Dictionary, item_list_index: int):
	song_list_manager.populate_items_grouped()

func _on_song_item_selected_from_manager(song_data: Dictionary):
	current_selected_song_data = song_data
	song_details_manager.stop_preview()
	song_details_manager.update_details(song_data)
	
	var song_file_path = song_data.get("path", "")
	if song_file_path != "":
		current_displayed_song_path = song_file_path
		song_details_manager.play_song_preview(song_file_path)
		analyze_bpm_button.disabled = false
		results_button.disabled = false
		clear_results_button.disabled = false
	else:
		analyze_bpm_button.disabled = true
		results_button.disabled = true
		clear_results_button.disabled = true
	
	$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.text = "Сгенерировать ноты"
	$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.disabled = false

func _on_song_list_changed():
	_update_song_count_label()

func _on_add_pressed():
	_open_file_dialog_for_add()

func _open_file_dialog_for_add():
	if file_dialog and file_dialog.is_inside_tree(): return
	
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.title = "Выберите аудиофайл"
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = ["*.mp3; MP3 Audio", "*.wav; WAV Audio"]
	file_dialog.file_selected.connect(_on_file_selected_internal)
	add_child(file_dialog)
	file_dialog.popup_centered()

func _on_file_selected_internal(path):
	var file_extension = path.get_extension().to_lower()
	if file_extension != "mp3" and file_extension != "wav":
		_cleanup_file_dialog()
		return
	song_list_manager.add_song_from_path(path)
	song_list_manager.populate_items_grouped()
	_cleanup_file_dialog()

func _cleanup_file_dialog():
	if file_dialog and is_instance_valid(file_dialog):
		file_dialog.queue_free()
		file_dialog = null

func _on_gui_input_for_label(event: InputEvent, field_type: String):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		if song_edit_manager.is_edit_mode_active():
			var selected_indices = song_item_list_ref.get_selected_items()
			if selected_indices.size() > 0:
				var song_data = song_list_manager.get_song_data_by_item_list_index(selected_indices[0])
				if not song_data.is_empty():
					song_edit_manager.start_editing(field_type, song_data, selected_indices[0])

func _toggle_edit_mode():
	if filter_by_letter.is_connected("item_selected", _on_filter_by_letter_selected):
		filter_by_letter.disconnect("item_selected", _on_filter_by_letter_selected)
	
	song_edit_manager.set_edit_mode(!song_edit_manager.is_edit_mode_active())
	_update_edit_button_style()
	_update_filters_visibility()
	
	filter_by_letter.item_selected.connect(_on_filter_by_letter_selected)

func _update_edit_button_style():
	if song_edit_manager.is_edit_mode_active():
		edit_button.self_modulate = Color(0.8, 0.8, 1.0, 1.0)
		edit_button.text = "Редактировать (ВКЛ)"
	else:
		edit_button.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
		edit_button.text = "Редактировать"

func _on_instrument_pressed():
	_open_instrument_selector()

func _on_generation_mode_pressed():
	_open_generation_selector()

func _on_generate_pressed():
	_generate_notes_for_current_song()

func _generate_notes_for_current_song():
	var song_path = current_selected_song_data.get("path", "")
	if song_path == "": return
	
	var song_bpm = current_selected_song_data.get("bpm", -1)
	if str(song_bpm) == "-1" or song_bpm == "Н/Д": return
	
	print("SongSelect.gd: Отправка на генерацию нот для: ", song_path)
	server_clients.generate_notes(
		song_path,
		current_instrument,
		float(song_bpm),
		-1,
		-1.0,
		true,
		"",
		"",
		current_generation_mode
	)

func _open_instrument_selector():
	if instrument_selector and is_instance_valid(instrument_selector):
		instrument_selector.queue_free()
	
	instrument_selector = InstrumentSelectorScene.instantiate()
	if instrument_selector.has_method("set_managers"):
		instrument_selector.set_managers(music_manager)
	instrument_selector.instrument_selected.connect(_on_instrument_selected)
	instrument_selector.selector_closed.connect(_on_instrument_selector_closed)
	get_parent().add_child(instrument_selector)

func _on_instrument_selector_closed():
	if instrument_selector:
		instrument_selector.queue_free()
		instrument_selector = null

func _on_instrument_selected(instrument_type: String):
	current_instrument = instrument_type
	var instrument_name = "Перкуссия" if instrument_type == "drums" else "Стандартный"
	$MainVBox/TopBarHBox/InstrumentButton.text = "Инструмент: " + instrument_name
	music_manager.play_instrument_select_sound(instrument_type)
	song_details_manager.set_current_instrument(current_instrument)
	song_details_manager._update_play_button_state()

func _open_generation_selector():
	if generation_selector and is_instance_valid(generation_selector):
		generation_selector.queue_free()
	
	generation_selector = GenerationSelectorScene.instantiate()
	if generation_selector.has_method("set_managers"):
		generation_selector.set_managers(music_manager)
	generation_selector.generation_mode_selected.connect(_on_generation_mode_selected)
	generation_selector.selector_closed.connect(_on_generation_selector_closed)
	get_parent().add_child(generation_selector)

func _on_generation_mode_selected(mode: String):
	current_generation_mode = mode
	var display_text = "Улучшенный" if mode == "enhanced" else "Базовый"
	$MainVBox/TopBarHBox/GenerationModeButton.text = "Режим генерации: " + display_text
	song_details_manager.set_current_generation_mode(mode)  
	song_details_manager._update_play_button_state()


func _on_generation_selector_closed():
	if generation_selector:
		generation_selector.queue_free()
		generation_selector = null

func _on_delete_pressed():
	var selected_items = song_item_list_ref.get_selected_items()
	if selected_items.size() == 0: return
	
	var selected_index = selected_items[0]
	var songs_list = song_manager.get_songs_list()
	if selected_index < 0 or selected_index >= songs_list.size(): return
	
	var song_path = songs_list[selected_index].get("path", "")
	if song_path == "": return
	
	var dir = DirAccess.open("res://")
	if dir and dir.remove(song_path) == OK:
		song_metadata_manager.remove_metadata(song_path)
		results_manager.clear_results_for_song(song_path)
		song_manager.load_songs()
		song_list_manager.populate_items_grouped()
		_on_song_list_changed()
		
		var current_selected_items = song_item_list_ref.get_selected_items()
		if current_selected_items.size() == 0 or current_selected_items[0] >= song_item_list_ref.item_count:
			song_details_manager.update_details({})
			song_details_manager.stop_preview()
			analyze_bpm_button.disabled = true

func _on_results_pressed():
	var song_item_list = $MainVBox/ContentHBox/SongListVBox/SongItemList
	var results_list = $MainVBox/ContentHBox/SongListVBox/ResultsItemList
	
	if song_item_list.visible:
		song_item_list.visible = false
		results_list.visible = true
		clear_results_button.visible = true
		results_manager.show_results_for_song(current_selected_song_data, results_list)
	else:
		results_list.visible = false
		song_item_list.visible = true
		clear_results_button.visible = false

func _on_clear_results_pressed():
	var song_path = current_selected_song_data.get("path", "")
	if song_path.is_empty(): return
	
	if results_manager.clear_results_for_song(song_path):
		var results_list = $MainVBox/ContentHBox/SongListVBox/ResultsItemList
		results_manager.show_results_for_song(current_selected_song_data, results_list)

func _on_analyze_bpm_pressed():
	var selected_items = song_item_list_ref.get_selected_items()
	if selected_items.size() == 0: return
	
	var selected_song_data = song_list_manager.get_song_data_by_item_list_index(selected_items[0])
	if selected_song_data.is_empty(): return
	
	var song_path = selected_song_data.get("path", "")
	if song_path == "": return
	
	print("SongSelect.gd: Отправка на анализ BPM файла: ", song_path)
	$MainVBox/ContentHBox/DetailsVBox/BpmLabel.text = "BPM: Загрузка..."
	server_clients.analyze_bpm(song_path)

func _on_play_pressed():
	print("SongSelect.gd: _on_play_pressed вызван")
	if current_selected_song_data.is_empty():
		printerr("SongSelect.gd: Нет выбранной песни!")
		return
	
	transitions.open_game_with_song(
		current_selected_song_data,  
		current_instrument,           
		results_manager,             
		current_generation_mode       
	)
func _update_song_count_label():
	song_list_manager.update_song_count_label($MainVBox/TopBarHBox/SongCountLabel)

func _show_manual_track_input(artist: String, title: String):
	if manual_track_input_dialog and is_instance_valid(manual_track_input_dialog):
		manual_track_input_dialog.queue_free()
	
	var corrected_artist = artist
	var corrected_title = title
	var song_filename = pending_manual_identification_song_path.get_file().get_basename()
	
	if artist == "Неизвестен" and title == "Н/Д":
		var parts = song_filename.split(" - ", false, 1)
		if parts.size() == 2:
			corrected_artist = parts[0]
			corrected_title = parts[1]
		else:
			corrected_artist = song_filename
			corrected_title = "Н/Д"
	
	manual_track_input_dialog = ManualTrackInputScene.instantiate()
	manual_track_input_dialog.set_expected_track(corrected_artist, corrected_title)
	manual_track_input_dialog.confirmed.connect(_on_manual_track_confirmed)
	manual_track_input_dialog.cancelled.connect(_on_manual_track_cancelled)
	manual_track_input_dialog.manual_entry_confirmed.connect(_on_manual_entry_confirmed)
	add_child(manual_track_input_dialog)
	manual_track_input_dialog.show_modal_for_track(corrected_artist, corrected_title)

func _on_manual_track_confirmed():
	$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.text = "Сгенерировать ноты"
	$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.disabled = false

func _on_manual_track_cancelled():
	$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.text = "Ручной ввод"
	$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.disabled = false

func _on_manual_entry_confirmed(artist: String, title: String):
	print("SongSelect.gd: Пользователь ввёл артиста: '%s', название: '%s'" % [artist, title])
	if pending_manual_identification_song_path == "": return
	server_clients.get_genres_for_manual_entry(artist, title)

func _on_song_metadata_updated(song_file_path: String):
	if current_displayed_song_path == song_file_path:
		for song in song_manager.get_songs_list():
			if song.path == song_file_path:
				song_details_manager.update_details(song)
				break

func cleanup_before_exit():
	song_details_manager.stop_preview()
	if manual_track_input_dialog and is_instance_valid(manual_track_input_dialog):
		manual_track_input_dialog.queue_free()
		manual_track_input_dialog = null
	if instrument_selector and is_instance_valid(instrument_selector):
		instrument_selector.queue_free()
		instrument_selector = null
	if file_dialog and is_instance_valid(file_dialog):
		file_dialog.queue_free()
		file_dialog = null

func get_current_selected_song() -> Dictionary:
	return current_selected_song_data.duplicate()

func get_results_manager():
	return results_manager
