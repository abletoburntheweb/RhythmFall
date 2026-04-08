# scenes/song_select/song_select.gd
extends BaseScreen

const GenerationService = preload("res://logic/generation_service.gd")
const GenerationSettingsSelectorScene = preload("res://scenes/song_select/generation_settings_selector.tscn")
const _OptionButtonPopupUtils = preload("res://logic/utils/option_button_popup_utils.gd")

var background_service: GenerationService = null
var song_list_manager: SongListController = preload("res://scenes/song_select/song_list_controller.gd").new()
var song_details_manager: SongDetailsManager = preload("res://scenes/song_select/song_details_manager.gd").new()
var results_manager: ResultsManager = preload("res://scenes/song_select/results_manager.gd").new()

var song_metadata_manager = SongLibrary 

@onready var edit_button: Button = $MainVBox/TopBarHBox/EditButton
@onready var filter_by_letter: OptionButton = $MainVBox/TopBarHBox/FilterByLetter
@onready var song_item_list_ref: ItemList = $MainVBox/ContentHBox/SongListVBox/SongItemList
@onready var analyze_bpm_button: Button = $MainVBox/ContentHBox/DetailsVBox/AnalyzeBPMButton
@onready var results_button: Button = $MainVBox/ContentHBox/DetailsVBox/ResultsButton
@onready var clear_results_button: Button = $MainVBox/TopBarHBox/ClearResultsButton

var generation_settings_selector: Control = null

var current_instrument: String = "drums"
var current_generation_mode: String = "basic"
var current_lanes: int = 4
var current_selected_song_data: Dictionary = {}
var current_displayed_song_path: String = ""

func _ready():
	var game_engine = get_parent()
	var trans = game_engine.get_transitions()
	
	song_metadata_manager = SongLibrary
	
	setup_managers(trans)  
	
	song_metadata_manager.metadata_updated.connect(_on_song_metadata_updated)
	if SongLibrary and SongLibrary.has_signal("songs_list_changed"):
		SongLibrary.songs_list_changed.connect(_on_songs_list_changed_from_library)
		
	SongLibrary.load_songs()
	
	add_child(song_list_manager)
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
		$MainVBox/ContentHBox/DetailsVBox/PrimaryGenreLabel,
		$MainVBox/ContentHBox/DetailsVBox/PlayCountLabel,
		$MainVBox/ContentHBox/DetailsVBox/BestGradeLabel,
		$MainVBox/ContentHBox/DetailsVBox/CoverTextureRect,
		$MainVBox/ContentHBox/DetailsVBox/PlayButton
	)
	song_details_manager.setup_audio_player()  
	
	song_list_manager.song_edited.connect(_on_song_edited_from_manager)
		
	background_service = game_engine.get_background_service()
	if background_service:
		background_service.bpm_started.connect(_on_bpm_started)
		background_service.bpm_completed.connect(_on_bpm_completed)
		background_service.bpm_error.connect(_on_bpm_error)
		background_service.notes_started.connect(_on_notes_started)
		background_service.notes_completed.connect(_on_notes_completed)
		background_service.notes_error.connect(_on_notes_error)
		var bpm_task = background_service.get_active_bpm_task()
		if not bpm_task.is_empty():
			if String(bpm_task.get("path", "")) == current_displayed_song_path:
				_on_bpm_analysis_started()
		var notes_task = background_service.get_active_notes_task()
		if not notes_task.is_empty():
			_on_notes_generation_started()
		_apply_background_status_ui()
		if not background_service.notes_progress.is_connected(_on_notes_progress):
			background_service.notes_progress.connect(_on_notes_progress)
	
	
	_connect_ui_signals()
	
	var saved_instrument = SettingsManager.get_setting("last_generation_instrument", "drums")
	var saved_mode = SettingsManager.get_setting("last_generation_mode", "basic")
	var saved_lanes = SettingsManager.get_setting("last_generation_lanes", 4)

	current_instrument = saved_instrument
	current_generation_mode = saved_mode
	current_lanes = saved_lanes

	$MainVBox/TopBarHBox/GenerationSettingsButton.text = _format_generation_settings_label(saved_instrument, saved_mode, saved_lanes)
	song_details_manager.set_current_instrument(saved_instrument)
	song_details_manager.set_current_generation_mode(saved_mode)
	song_details_manager.set_current_lanes(saved_lanes)
	song_list_manager.set_generation_settings(saved_instrument, saved_mode, saved_lanes)
	
	analyze_bpm_button.disabled = true
	results_button.disabled = true
	clear_results_button.disabled = true
	call_deferred("_apply_filter_option_popup_font")

func _apply_filter_option_popup_font() -> void:
	_OptionButtonPopupUtils.apply_popup_font_size(filter_by_letter, 24)

func _connect_ui_signals():
	_update_edit_button_style()
	var title_label = $MainVBox/ContentHBox/DetailsVBox/TitleLabel
	var artist_label = $MainVBox/ContentHBox/DetailsVBox/ArtistLabel
	var year_label = $MainVBox/ContentHBox/DetailsVBox/YearLabel
	var bpm_label = $MainVBox/ContentHBox/DetailsVBox/BpmLabel
	var cover_rect = $MainVBox/ContentHBox/DetailsVBox/CoverTextureRect
	var primary_genre_label = $MainVBox/ContentHBox/DetailsVBox/PrimaryGenreLabel
	
	title_label.mouse_filter = Control.MOUSE_FILTER_STOP
	artist_label.mouse_filter = Control.MOUSE_FILTER_STOP
	year_label.mouse_filter = Control.MOUSE_FILTER_STOP
	bpm_label.mouse_filter = Control.MOUSE_FILTER_STOP
	cover_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	primary_genre_label.mouse_filter = Control.MOUSE_FILTER_STOP
	
	if not title_label.gui_input.is_connected(_on_gui_input_for_label):
		title_label.gui_input.connect(_on_gui_input_for_label.bind("title"))
	if not artist_label.gui_input.is_connected(_on_gui_input_for_label):
		artist_label.gui_input.connect(_on_gui_input_for_label.bind("artist"))
	if not year_label.gui_input.is_connected(_on_gui_input_for_label):
		year_label.gui_input.connect(_on_gui_input_for_label.bind("year"))
	if not bpm_label.gui_input.is_connected(_on_gui_input_for_label):
		bpm_label.gui_input.connect(_on_gui_input_for_label.bind("bpm"))
	if not cover_rect.gui_input.is_connected(_on_gui_input_for_label):
		cover_rect.gui_input.connect(_on_gui_input_for_label.bind("cover"))
	if not primary_genre_label.gui_input.is_connected(_on_gui_input_for_label):
		primary_genre_label.gui_input.connect(_on_gui_input_for_label.bind("primary_genre"))
 
func _on_bpm_started(_path, _disp):
	if not background_service:
		return
	var t: Dictionary = background_service.get_active_bpm_task()
	var same: bool = (
		t.has("path")
		and String(t.get("path", "")) == current_displayed_song_path
	)
	if same:
		_on_bpm_analysis_started()
 
func _on_bpm_completed(_path, bpm_value, _disp):
	if not background_service:
		return
	var t: Dictionary = background_service.get_active_bpm_task()
	var same: bool = (
		t.has("path")
		and String(t.get("path", "")) == current_displayed_song_path
	)
	if same:
		_on_bpm_analysis_completed(bpm_value)
 
func _on_bpm_error(_path, msg, _disp):
	if not background_service:
		return
	var t: Dictionary = background_service.get_active_bpm_task()
	var same: bool = (
		t.has("path")
		and String(t.get("path", "")) == current_displayed_song_path
	)
	if same:
		_on_bpm_analysis_error(msg)
 
func _on_notes_started(_path, _disp):
	if not background_service:
		return
	var t: Dictionary = background_service.get_active_notes_task()
	if not t.has("path") or String(t.get("path", "")) != current_displayed_song_path:
		return
	var exact: bool = (
		String(t.get("instrument", "")) == current_instrument
		and String(t.get("mode", "")) == current_generation_mode
		and int(t.get("lanes", 0)) == current_lanes
	)
	if exact:
		_on_notes_generation_started()
	else:
		$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.text = "Генерация..."
		$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.disabled = true

func _notes_emit_task_dict() -> Dictionary:
	var t: Dictionary = background_service.get_active_notes_task()
	if t.is_empty():
		t = background_service.get_last_notes_task()
	return t

func _song_path_key(p: String) -> String:
	return String(p).replace("\\", "/").trim_suffix("/")

func _on_notes_completed(path: String, instr: String, _disp: String):
	if not background_service:
		return
	if _song_path_key(path) == _song_path_key(current_displayed_song_path):
		var t: Dictionary = _notes_emit_task_dict()
		var exact: bool = (
			t.has("path")
			and String(t.get("instrument", "")) == current_instrument
			and String(t.get("mode", "")) == current_generation_mode
			and int(t.get("lanes", 0)) == current_lanes
		)
		if exact:
			_on_notes_generation_completed([], 0.0, instr)
		else:
			_apply_background_status_ui()
	call_deferred("_deferred_refresh_generation_notes_highlights")

func _deferred_refresh_generation_notes_highlights():
	refresh_generation_notes_highlights()

func _on_notes_error(path: String, msg: String, _disp: String):
	if not background_service:
		return
	if _song_path_key(path) != _song_path_key(current_displayed_song_path):
		return
	var t: Dictionary = _notes_emit_task_dict()
	var exact: bool = (
		t.has("path")
		and String(t.get("instrument", "")) == current_instrument
		and String(t.get("mode", "")) == current_generation_mode
		and int(t.get("lanes", 0)) == current_lanes
	)
	if exact:
		_on_notes_generation_error(msg)
	else:
		_apply_background_status_ui()
func _on_notes_progress(_path: String, _k: int, _total: int, _status: String):
	_apply_background_status_ui()
	
func _on_bpm_analysis_started():
	analyze_bpm_button.text = "Вычисление..."
	analyze_bpm_button.disabled = true

func _on_bpm_analysis_completed(bpm_value: int):
	$MainVBox/ContentHBox/DetailsVBox/BpmLabel.text = "BPM: " + str(bpm_value)
	analyze_bpm_button.text = "BPM вычислен"
	analyze_bpm_button.disabled = false
	
	var selected_items = song_item_list_ref.get_selected_items()
	if selected_items.size() > 0:
		var selected_song_data = song_list_manager.get_song_data_by_item_list_index(selected_items[0])
		var song_path = selected_song_data.get("path", "")
		
		if song_path != "":
			var metadata = SongLibrary.get_metadata_for_song(song_path)
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
			SongLibrary.update_metadata(song_path, metadata)
			
			if current_selected_song_data.get("path", "") == song_path:
				if _check_if_notes_exist_for_current_settings():
					$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.text = "Ноты сгенерированы"
				else:
					$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.text = "Сгенерировать ноты"
				$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.disabled = false

func _on_bpm_analysis_error(error_message: String):
	printerr("SongSelect.gd: Ошибка BPM анализа: " + error_message)
	$MainVBox/ContentHBox/DetailsVBox/BpmLabel.text = "BPM: Ошибка"
	analyze_bpm_button.text = "Ошибка вычисления"
	analyze_bpm_button.disabled = false
	
func _on_notes_generation_started():
	$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.text = "Генерация..."
	$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.disabled = true

func _on_notes_generation_completed(notes_data: Array, bpm_value: float, instrument_type: String):
	$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.text = "Ноты сгенерированы"
	$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.disabled = false
	$MainVBox/ContentHBox/DetailsVBox/PlayButton.disabled = false  
	song_details_manager._update_play_button_state()
	song_details_manager.set_generation_status("Ноты сгенерированы", false)

func _on_notes_generation_error(error_message: String):
	printerr("SongSelect.gd: Ошибка генерации нот: " + error_message)
	$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.text = "Ошибка генерации"
	$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.disabled = false
	song_details_manager.set_generation_status("Ошибка: %s" % error_message, true)
	
func _on_filter_by_letter_selected(index: int):
	if song_list_manager.is_edit_mode_active():
		pass
	var selected_text = filter_by_letter.get_item_text(index)
	var mode = "title" if selected_text == "Название" else "artist"
	song_list_manager.set_filter_mode(mode)
	var search_bar = $MainVBox/TopBarHBox/SearchBar
	if search_bar:
		var q = String(search_bar.text)
		song_list_manager.filter_items(q)
	else:
		song_list_manager.populate_items_grouped()
	
func _on_search_text_changed(new_text: String):
	song_list_manager.filter_items(new_text)

func _update_filters_visibility():
	var is_edit_mode = song_list_manager.is_edit_mode_active()

func _on_song_edited_from_manager(song_data: Dictionary, item_list_index: int):
	var was_selected = false
	var selected_indices = song_item_list_ref.get_selected_items()
	if selected_indices.has(item_list_index):
		was_selected = true

	if song_list_manager.update_song_at_index(item_list_index, song_data):
		if was_selected:
			song_item_list_ref.select(item_list_index, true)
			var path = String(song_data.get("path", ""))
			var persisted = SongLibrary.get_metadata_for_song(path)
			if persisted.is_empty():
				current_selected_song_data = song_data.duplicate(true)
			else:
				current_selected_song_data = persisted.duplicate(true)
			var cur_bpm = String(current_selected_song_data.get("bpm", "")).strip_edges()
			if cur_bpm == "":
				current_selected_song_data["bpm"] = "Н/Д"
				if path != "":
					SongLibrary.update_metadata(path, {"bpm": "Н/Д"})
			current_displayed_song_path = path
			song_details_manager.update_details(current_selected_song_data)
			_apply_bpm_dependent_ui()

		if current_selected_song_data.get("path") == song_data.get("path"):
			var song_path = song_data.get("path", "")
			var latest = {}
			if song_path != "":
				for s in SongLibrary.get_songs_list():
					if s.get("path", "") == song_path:
						latest = s.duplicate(true)
						break
			if latest.is_empty():
				latest = song_data.duplicate(true)
			var latest_bpm = String(latest.get("bpm", "")).strip_edges()
			if latest_bpm == "":
				latest["bpm"] = "Н/Д"
				if song_path != "":
					SongLibrary.update_metadata(song_path, {"bpm": "Н/Д"})
			current_selected_song_data = latest
			song_details_manager.update_details(latest)
			_apply_bpm_dependent_ui()
	else:
		song_list_manager.populate_items_grouped()

func _apply_bpm_dependent_ui():
	var song_bpm = current_selected_song_data.get("bpm", "Н/Д")
	if str(song_bpm) == "-1" or song_bpm == "Н/Д":
		analyze_bpm_button.text = "Вычислить BPM"
		$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.text = "Сначала вычислите BPM"
		$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.disabled = true
		$MainVBox/ContentHBox/DetailsVBox/PlayButton.disabled = true
	else:
		analyze_bpm_button.text = "BPM вычислен"
		if _check_if_notes_exist_for_current_settings():
			$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.text = "Ноты сгенерированы"
		else:
			$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.text = "Сгенерировать ноты"
		$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.disabled = false
		if _check_if_notes_exist_for_current_settings():
			$MainVBox/ContentHBox/DetailsVBox/PlayButton.disabled = false
			song_details_manager._update_play_button_state()
		else:
			$MainVBox/ContentHBox/DetailsVBox/PlayButton.disabled = true
			song_details_manager._update_play_button_state()
	_apply_background_status_ui()

func _on_song_item_selected_from_manager(song_data: Dictionary):
	var enriched_song_data = song_data.duplicate()
	
	var song_path = song_data.get("path", "")
	
	if song_path != "":
		var metadata = SongLibrary.get_metadata_for_song(song_path)
		if not metadata.is_empty():
			for key in metadata:
				enriched_song_data[key] = metadata[key]
		var bpm_val := str(enriched_song_data.get("bpm", "")).strip_edges()
		if bpm_val == "":
			enriched_song_data["bpm"] = "Н/Д"
			SongLibrary.update_metadata(song_path, {"bpm": "Н/Д"})
	
	current_selected_song_data = enriched_song_data
	song_details_manager.stop_preview()
	song_details_manager.update_details(enriched_song_data)
	
	var song_file_path = enriched_song_data.get("path", "")
	if song_file_path != "":
		current_displayed_song_path = song_file_path
		song_details_manager.play_song_preview(song_file_path)
		analyze_bpm_button.disabled = false
		results_button.disabled = false
		clear_results_button.disabled = false
		song_details_manager._update_play_button_state()
		_apply_background_status_ui()
	else:
		analyze_bpm_button.disabled = true
		results_button.disabled = true
		clear_results_button.disabled = true
	
	var song_bpm = enriched_song_data.get("bpm", "Н/Д")
	if str(song_bpm) == "-1" or song_bpm == "Н/Д":
		analyze_bpm_button.text = "Вычислить BPM"
		$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.text = "Сначала вычислите BPM"
		$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.disabled = true
		$MainVBox/ContentHBox/DetailsVBox/PlayButton.disabled = true
	else:
		analyze_bpm_button.text = "BPM вычислен"
		if _check_if_notes_exist_for_current_settings():
			$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.text = "Ноты сгенерированы"
		else:
			$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.text = "Сгенерировать ноты"
		$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.disabled = false
		
		if _check_if_notes_exist_for_current_settings():
			$MainVBox/ContentHBox/DetailsVBox/PlayButton.disabled = false
			song_details_manager._update_play_button_state()
		else:
			$MainVBox/ContentHBox/DetailsVBox/PlayButton.disabled = true
			song_details_manager._update_play_button_state()
	_apply_background_status_ui()

func _on_song_list_changed():
	_update_song_count_label()

func _on_generation_settings_pressed():
	_open_generation_settings_selector()
	
func _open_generation_settings_selector():
	if generation_settings_selector and is_instance_valid(generation_settings_selector):
		generation_settings_selector.queue_free()
	
	generation_settings_selector = GenerationSettingsSelectorScene.instantiate()
	generation_settings_selector.generation_settings_confirmed.connect(_on_generation_settings_confirmed)
	generation_settings_selector.selector_closed.connect(_on_generation_settings_closed)
	if current_displayed_song_path != "":
		generation_settings_selector.set_current_song_path(current_displayed_song_path)
	get_parent().add_child(generation_settings_selector)

func _on_gui_input_for_label(event: InputEvent, field_type: String):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.double_click:
		if song_list_manager.is_edit_mode_active():
			var selected_indices = song_item_list_ref.get_selected_items()
			if selected_indices.size() > 0:
				var song_data = song_list_manager.get_song_data_by_item_list_index(selected_indices[0])
				if not song_data.is_empty():
					song_list_manager.start_editing(field_type, song_data, selected_indices[0])

func _toggle_edit_mode():
	song_list_manager.set_edit_mode(!song_list_manager.is_edit_mode_active())
	_update_edit_button_style()
	_update_filters_visibility()
	var search_bar = $MainVBox/TopBarHBox/SearchBar
	if search_bar:
		var q = String(search_bar.text)
		song_list_manager.filter_items(q)

func _update_edit_button_style():
	if song_list_manager.is_edit_mode_active():
		edit_button.self_modulate = Color(0.8, 0.8, 1.0, 1.0)
		edit_button.text = "Редактировать (ВКЛ)"
	else:
		edit_button.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
		edit_button.text = "Редактировать"

func _on_generate_pressed():
	_generate_notes_for_current_song()

func _collect_missing_generation_jobs(song_path: String) -> Array:
	var scope := int(SettingsManager.get_setting("generation_notes_ready_scope", 0))
	var inst := current_instrument
	var jobs: Array = []
	match scope:
		0:
			for ln in NotesUtils.LANE_COUNTS:
				if not NotesUtils.notes_exist(song_path, inst, current_generation_mode, ln):
					jobs.append({"mode": current_generation_mode, "lanes": ln})
		1:
			if not NotesUtils.notes_exist(song_path, inst, current_generation_mode, current_lanes):
				jobs.append({"mode": current_generation_mode, "lanes": current_lanes})
		2:
			for m in NotesUtils.GENERATION_MODES:
				for ln in NotesUtils.LANE_COUNTS:
					if not NotesUtils.notes_exist(song_path, inst, m, ln):
						jobs.append({"mode": m, "lanes": ln})
		3:
			for m in NotesUtils.GENERATION_MODES:
				if not NotesUtils.notes_exist(song_path, inst, m, current_lanes):
					jobs.append({"mode": m, "lanes": current_lanes})
		_:
			if not NotesUtils.notes_exist(song_path, inst, current_generation_mode, current_lanes):
				jobs.append({"mode": current_generation_mode, "lanes": current_lanes})
	return jobs

func _generate_notes_for_current_song():
	var song_path = current_selected_song_data.get("path", "")
	if song_path == "": return
	
	var song_bpm = current_selected_song_data.get("bpm", -1)
	if str(song_bpm) == "-1" or song_bpm == "Н/Д": return

	var metadata = SongLibrary.get_metadata_for_song(song_path)
	var has_genres := false
	if metadata.has("genres"):
		if typeof(metadata["genres"]) == TYPE_ARRAY:
			has_genres = metadata["genres"].size() > 0
		else:
			has_genres = str(metadata["genres"]).strip_edges() != ""
	if not has_genres and metadata.has("primary_genre"):
		var pg = str(metadata["primary_genre"]).strip_edges().to_lower()
		has_genres = (pg != "" and pg != "unknown")
	var enable_genre_detection = SettingsManager.get_setting("enable_genre_detection", true)

	var auto_identify := true
	var manual_artist := ""
	var manual_title := ""
	if has_genres:
		auto_identify = false
	elif not enable_genre_detection:
		auto_identify = false
		manual_artist = "Unknown"
		manual_title = "Unknown"

	if not background_service:
		return

	var jobs: Array = _collect_missing_generation_jobs(song_path)
	if jobs.is_empty():
		jobs.append({"mode": current_generation_mode, "lanes": current_lanes})

	var bpm_f := float(song_bpm)
	for job in jobs:
		var mode: String = str(job.get("mode", current_generation_mode))
		var lanes: int = int(job.get("lanes", current_lanes))
		background_service.start_notes_generation(
			song_path,
			current_instrument,
			bpm_f,
			lanes,
			0.2,
			auto_identify,
			manual_artist,
			manual_title,
			mode
		)
	_apply_background_status_ui()

func _on_delete_pressed():
	var selected_items = song_item_list_ref.get_selected_items()
	if selected_items.size() == 0:
		return

	var selected_song_data = song_list_manager.get_song_data_by_item_list_index(selected_items[0])
	if selected_song_data.is_empty():
		printerr("SongSelect.gd: Выбран не трек (возможно, заголовок группы).")
		return

	var song_path = selected_song_data.get("path", "")
	if song_path == "":
		return

	var dir = DirAccess.open("res://")
	if dir and dir.remove(song_path) == OK:
		SongLibrary.remove_metadata(song_path)
		results_manager.clear_results_for_song(song_path)
		
		var base_name = NotesUtils.base_name_from_song_path(song_path)
		var notes_dir_path = NotesUtils.notes_dir(base_name)
		var user_dir = DirAccess.open("user://")
		if user_dir and user_dir.dir_exists(notes_dir_path):
			DirectoryUtils.delete_dir_recursive(notes_dir_path)
		
		SongLibrary.load_songs()
		
		song_list_manager.populate_items_grouped()
		_on_song_list_changed()
		
		var current_selected_items = song_item_list_ref.get_selected_items()
		if current_selected_items.size() == 0 or current_selected_items[0] >= song_item_list_ref.item_count:
			song_details_manager.update_details({})
			song_details_manager.stop_preview()
			analyze_bpm_button.disabled = true
			
		pass
	else:
		printerr("SongSelect.gd: Не удалось удалить файл: ", song_path)

func _delete_directory_recursive(dir_path: String) -> void:
	var dir = DirAccess.open(dir_path)
	if not dir:
		return
	dir.list_dir_begin()
	var name = dir.get_next()
	while name != "":
		if name != "." and name != "..":
			var child_path = "%s/%s" % [dir_path, name]
			if dir.current_is_dir():
				_delete_directory_recursive(child_path)
			var root = DirAccess.open("user://")
			if root:
				root.remove(child_path)
		name = dir.get_next()
	dir.list_dir_end()
	var root2 = DirAccess.open("user://")
	if root2:
		root2.remove(dir_path)

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
	
	$MainVBox/ContentHBox/DetailsVBox/BpmLabel.text = "BPM: Загрузка..."
	if background_service:
		background_service.start_bpm_analysis(song_path)
		_apply_background_status_ui()

func _on_play_pressed():
	if current_selected_song_data.is_empty():
		printerr("SongSelect.gd: Нет выбранной песни!")
		return
	
	transitions.open_game_with_song(
		current_selected_song_data,  
		current_instrument,           
		results_manager,             
		current_generation_mode,
		current_lanes 
	)
	
func _update_song_count_label():
	song_list_manager.update_song_count_label($MainVBox/TopBarHBox/SongCountLabel)

 
	
func _on_generation_settings_confirmed(instrument: String, mode: String, lanes: int):
	current_instrument = instrument
	current_generation_mode = mode
	current_lanes = lanes
	
	song_details_manager.set_current_instrument(current_instrument)
	song_details_manager.set_current_generation_mode(current_generation_mode)
	song_details_manager.set_current_lanes(lanes)
	song_list_manager.set_generation_settings(current_instrument, current_generation_mode, current_lanes)
	
	$MainVBox/TopBarHBox/GenerationSettingsButton.text = _format_generation_settings_label(instrument, mode, lanes)
	_apply_background_status_ui()

func _apply_background_status_ui():
	if not background_service:
		return
	var pos_bpm = background_service.get_bpm_queue_position(current_displayed_song_path)
	if pos_bpm == 1:
		analyze_bpm_button.text = "Вычисление..."
		analyze_bpm_button.disabled = true
	elif pos_bpm > 1:
		analyze_bpm_button.text = "В очереди (%d)" % pos_bpm
		analyze_bpm_button.disabled = true
	var pos_notes = background_service.get_notes_queue_position(current_displayed_song_path, current_instrument, current_generation_mode, current_lanes)
	var pos_notes_song = background_service.get_notes_queue_position_for_song(current_displayed_song_path)
	if pos_notes == 1:
		$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.text = "Генерация..."
		$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.disabled = true
	elif pos_notes > 1:
		$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.text = "В очереди (%d)" % pos_notes
		$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.disabled = true
	elif pos_notes_song == 1:
		$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.text = "Генерация..."
		$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.disabled = true
	elif pos_notes_song > 1:
		$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.text = "В очереди (%d)" % pos_notes_song
		$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.disabled = true
	else:
		var song_bpm_val = current_selected_song_data.get("bpm", "Н/Д")
		if str(song_bpm_val) != "-1" and song_bpm_val != "Н/Д":
			if _check_if_notes_exist_for_current_settings():
				$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.text = "Ноты сгенерированы"
			else:
				$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.text = "Сгенерировать ноты"
			$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.disabled = false
	
func _format_generation_settings_label(instrument: String, mode: String, lanes: int) -> String:
	var inst_abbr: String
	match instrument:
		"drums": inst_abbr = "П"
		"fullmix": inst_abbr = "О"
		_: inst_abbr = instrument.substr(0, 1).to_upper()
	var mode_abbr: String
	match mode:
		"basic": mode_abbr = "Б"
		"enhanced": mode_abbr = "У"
		"minimal": mode_abbr = "М"
		"natural": mode_abbr = "Н"
		"custom": mode_abbr = "П"
		_: mode_abbr = mode.substr(0, 1).to_upper()
	return "Настройки генерации: %s %s %d" % [inst_abbr, mode_abbr, lanes]
func _on_generation_settings_closed():
	if generation_settings_selector and is_instance_valid(generation_settings_selector):
		generation_settings_selector.queue_free()
		generation_settings_selector = null
		
func _on_song_metadata_updated(song_file_path: String):
	if current_displayed_song_path == song_file_path:
		for song in SongLibrary.get_songs_list():
			if song.path == song_file_path:
				song_details_manager.update_details(song)
				break
	if song_list_manager:
		var search_bar = $MainVBox/TopBarHBox/SearchBar
		if search_bar:
			var q = String(search_bar.text)
			song_list_manager.filter_items(q)
		else:
			song_list_manager.populate_items_grouped()

func _on_songs_list_changed_from_library():
	if song_list_manager:
		var search_bar = $MainVBox/TopBarHBox/SearchBar
		if search_bar:
			var q = String(search_bar.text)
			song_list_manager.filter_items(q)
		else:
			song_list_manager.populate_items_grouped()
		_on_song_list_changed()

func cleanup_before_exit():
	song_details_manager.stop_preview()

func get_current_selected_song() -> Dictionary:
	return current_selected_song_data.duplicate()

func get_results_manager():
	return results_manager
	
func _check_if_notes_exist_for_current_settings() -> bool:
	var song_path = current_selected_song_data.get("path", "")
	if song_path == "":
		return false
	return NotesUtils.notes_ready_for_scope(song_path, current_instrument, current_generation_mode, current_lanes)

func refresh_generation_notes_highlights():
	song_list_manager.refresh_highlight_for_current_settings()
	song_details_manager._update_play_button_state()
	song_details_manager._update_generation_status()
	if current_displayed_song_path != "":
		if _check_if_notes_exist_for_current_settings():
			$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.text = "Ноты сгенерированы"
		else:
			$MainVBox/ContentHBox/DetailsVBox/GenerateNotesButton.text = "Сгенерировать ноты"
 
