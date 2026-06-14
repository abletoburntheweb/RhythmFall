# scenes/song_select/metadata_edit_dialog.gd
extends Control
class_name MetadataEditDialog

signal metadata_saved(fields_to_update: Dictionary)
signal cancelled()

const GENRE_PICKER_SCENE := "res://scenes/song_select/genre_picker_dialog.tscn"

var _title_edit: LineEdit = null
var _artist_edit: LineEdit = null
var _year_spin: SpinBox = null
var _bpm_spin: SpinBox = null
var _genre_button: Button = null

var _song_data: Dictionary = {}
var _focus_field: String = ""

var _genre_changed: bool = false
var _pending_primary_genre: String = ""
var _pending_genres: Array = []
var _genre_picker: Node = null

var _initial_title: String = ""
var _initial_artist: String = ""
var _initial_year_value: int = 0
var _initial_year_present: bool = false
var _initial_bpm_value: int = 0

const _FORM_ROOT := "Container/BodyCenter/CardPanel/FormMargin/Form"

func _ready():
	_title_edit = get_node_or_null("%s/TitleRow/TitleEdit" % _FORM_ROOT)
	_artist_edit = get_node_or_null("%s/ArtistRow/ArtistEdit" % _FORM_ROOT)
	_year_spin = get_node_or_null("%s/MetaGrid/YearRow/YearSpin" % _FORM_ROOT)
	_bpm_spin = get_node_or_null("%s/MetaGrid/BpmRow/BpmSpin" % _FORM_ROOT)
	_genre_button = get_node_or_null("%s/GenreRow/GenreButton" % _FORM_ROOT)
	SpinBoxUtils.apply_value_font_size(_year_spin, 22)
	SpinBoxUtils.apply_value_font_size(_bpm_spin, 22)
	_apply_song_data()
	_focus_initial_field()
	UiInteractionApplier.apply_from_engine(self)

func setup(song_data: Dictionary, focus_field: String = "") -> void:
	_song_data = song_data.duplicate(true)
	_focus_field = focus_field

func _apply_song_data() -> void:
	_initial_title = str(_song_data.get("title", ""))
	if _initial_title == "Без названия":
		_initial_title = ""
	if _title_edit:
		_title_edit.text = _initial_title
	_initial_artist = str(_song_data.get("artist", ""))
	if _initial_artist == "Неизвестен":
		_initial_artist = ""
	if _artist_edit:
		_artist_edit.text = _initial_artist
	var year_str := str(_song_data.get("year", "")).strip_edges()
	var current_year: int = Time.get_datetime_dict_from_system()["year"]
	_initial_year_present = year_str != "" and year_str != "Н/Д" and year_str.is_valid_int()
	if _year_spin:
		_year_spin.min_value = 1900
		_year_spin.max_value = current_year
		_year_spin.step = 1
		if _initial_year_present:
			_initial_year_value = clampi(year_str.to_int(), 1900, current_year)
		else:
			_initial_year_value = current_year
		_year_spin.value = _initial_year_value
	var bpm_str := str(_song_data.get("bpm", "")).strip_edges()
	var bpm_present := bpm_str != "" and bpm_str != "Н/Д" and bpm_str != "-1" and bpm_str.is_valid_int()
	if _bpm_spin:
		if bpm_present:
			_initial_bpm_value = clampi(bpm_str.to_int(), int(_bpm_spin.min_value), int(_bpm_spin.max_value))
		else:
			_initial_bpm_value = int(_bpm_spin.value)
		_bpm_spin.value = _initial_bpm_value
	_pending_primary_genre = str(_song_data.get("primary_genre", ""))
	if _pending_genres is Array:
		var src_genres = _song_data.get("genres", [])
		_pending_genres = src_genres.duplicate() if src_genres is Array else []
	_update_genre_button_text()

func _update_genre_button_text() -> void:
	if not _genre_button:
		return
	var g := str(_pending_primary_genre).strip_edges()
	if g == "" or g == "unknown":
		_genre_button.text = "не указан"
	else:
		_genre_button.text = g

func _focus_initial_field() -> void:
	match _focus_field:
		"artist":
			if _artist_edit:
				_artist_edit.grab_focus()
		"year":
			if _year_spin:
				_year_spin.grab_focus()
		"bpm":
			if _bpm_spin:
				_bpm_spin.grab_focus()
		"primary_genre":
			if _genre_button:
				_genre_button.grab_focus()
		_:
			if _title_edit:
				_title_edit.grab_focus()

func _on_genre_button_pressed() -> void:
	var dlg_scene = load(GENRE_PICKER_SCENE)
	if not dlg_scene:
		return
	var dlg = dlg_scene.instantiate()
	_genre_picker = dlg
	if dlg.has_method("set_initial"):
		dlg.set_initial(_pending_primary_genre)
	dlg.genre_selected.connect(_on_genre_selected_from_picker)
	dlg.tree_exited.connect(func(): _genre_picker = null)
	add_child(dlg)
	UiInteractionApplier.apply_from_engine(dlg)

func _on_genre_selected_from_picker(primary_genre: String, all_genres: Array) -> void:
	_genre_changed = true
	_pending_primary_genre = primary_genre
	if primary_genre == "unknown":
		_pending_genres = []
	elif all_genres is Array and all_genres.size() > 0:
		_pending_genres = all_genres.duplicate()
	else:
		_pending_genres = []
	_update_genre_button_text()

func _collect_changed_fields() -> Dictionary:
	var fields: Dictionary = {}

	if _title_edit:
		var new_title := _title_edit.text.strip_edges()
		if new_title != "" and new_title != _initial_title:
			fields["title"] = new_title

	if _artist_edit:
		var new_artist := _artist_edit.text.strip_edges()
		if new_artist != _initial_artist:
			fields["artist"] = new_artist

	if _year_spin:
		var new_year_int := int(_year_spin.value)
		if new_year_int != _initial_year_value:
			fields["year"] = str(new_year_int)

	if _bpm_spin:
		var new_bpm_int := int(_bpm_spin.value)
		if new_bpm_int != _initial_bpm_value:
			fields["bpm"] = str(new_bpm_int)

	if _genre_changed:
		fields["primary_genre"] = _pending_primary_genre
		if _pending_primary_genre == "unknown":
			fields["genres"] = []
		elif _pending_genres is Array and _pending_genres.size() > 0:
			fields["genres"] = _pending_genres

	return fields

func _on_save_button_pressed() -> void:
	if MusicManager and MusicManager.has_method("play_select_sound"):
		MusicManager.play_select_sound()
	var fields := _collect_changed_fields()
	queue_free()
	emit_signal("metadata_saved", fields)

func _on_back_button_pressed() -> void:
	if MusicManager and MusicManager.has_method("play_cancel_sound"):
		MusicManager.play_cancel_sound()
	queue_free()
	emit_signal("cancelled")

func _input(event: InputEvent) -> void:
	if _genre_picker and is_instance_valid(_genre_picker):
		return
	if event.is_action_pressed("ui_cancel"):
		_on_back_button_pressed()
		accept_event()
