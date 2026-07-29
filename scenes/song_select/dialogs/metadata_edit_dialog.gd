# scenes/song_select/metadata_edit_dialog.gd
extends Control
class_name MetadataEditDialog

signal metadata_saved(fields_to_update: Dictionary)
signal cancelled()

const GENRE_PICKER_SCENE := "res://scenes/song_select/dialogs/genre_picker_dialog.tscn"
const _UiModifierSounds = preload("res://logic/ui/ui_modifier_sounds.gd")
const HELP_CALLOUT_SCENE := preload("res://scenes/help/help_callout.tscn")
const _SS = preload("res://logic/domain/library/song_select_strings.gd")

const _BODY := "Container/BodyCenter/CardPanel/CardMargin/BodyHBox"
const _LEFT := _BODY + "/LeftVBox"
const _RIGHT := _BODY + "/RightVBox"
const _FORM := _RIGHT + "/FormVBox"

var _title_edit: LineEdit = null
var _artist_edit: LineEdit = null
var _year_spin: SpinBox = null
var _bpm_spin: SpinBox = null
var _bpm_from_server_badge: PanelContainer = null
var _genre_button: Button = null
var _genre_from_server_badge: PanelContainer = null
var _cover_texture_rect: TextureRect = null
var _track_title_label: Label = null
var _track_artist_label: Label = null
var _format_badge: Label = null
var _duration_label: Label = null
var _file_size_label: Label = null
var _file_path_label: Label = null
var _date_added_label: Label = null

var _song_data: Dictionary = {}
var _focus_field: String = ""

var _genre_changed: bool = false
var _pending_primary_genre: String = ""
var _pending_genres: Array = []
var _pending_genre_from_server: bool = false
var _genre_picker: Node = null

var _initial_title: String = ""
var _initial_artist: String = ""
var _initial_year_value: int = 0
var _initial_year_present: bool = false
var _initial_bpm_value: int = 0
var _initial_bpm_from_server: bool = false
var _initial_genre_from_server: bool = false


func _ready():
	UiIconHelper.configure_modal_overlay(self, 100)
	_bind_nodes()
	SpinBoxUtils.apply_value_font_size(_year_spin, 22)
	SpinBoxUtils.apply_value_font_size(_bpm_spin, 22)
	_apply_song_data()
	_apply_sidebar_info()
	_load_cover_texture()
	_setup_hint_callouts()
	_focus_initial_field()
	_setup_ui_icons()
	call_deferred("apply_locale")
	UiInteractionApplier.apply_from_engine(self)


func _bind_nodes() -> void:
	_title_edit = get_node_or_null("%s/TitleRow/TitleEdit" % _FORM)
	_artist_edit = get_node_or_null("%s/ArtistRow/ArtistEdit" % _FORM)
	_year_spin = get_node_or_null("%s/YearRow/YearSpin" % _FORM)
	_bpm_spin = get_node_or_null("%s/BpmRow/BpmControlsHBox/BpmSpin" % _FORM)
	_bpm_from_server_badge = get_node_or_null("%BpmFromServerBadge")
	_genre_button = get_node_or_null("%s/GenreRow/GenreControlsHBox/GenreButton" % _FORM)
	_genre_from_server_badge = get_node_or_null("%GenreFromServerBadge")
	_cover_texture_rect = get_node_or_null("%CoverTextureRect")
	_track_title_label = get_node_or_null("%TrackTitleLabel")
	_track_artist_label = get_node_or_null("%TrackArtistLabel")
	_format_badge = get_node_or_null("%FormatBadge")
	_duration_label = get_node_or_null("%DurationLabel")
	_file_size_label = get_node_or_null("%FileSizeLabel")
	_file_path_label = get_node_or_null("%FilePathLabel")
	_date_added_label = get_node_or_null("%DateAddedLabel")


func apply_locale() -> void:
	var back_btn := get_node_or_null("Container/BackButton") as Button
	if back_btn:
		back_btn.text = tr("BTN_BACK")
		UiIconHelper.setup_back_button(back_btn)
	var title_label := get_node_or_null("Container/TitleLabel")
	if title_label:
		title_label.text = tr("META_EDIT_TITLE")
	var hint_label := get_node_or_null("Container/SubtitleLabel")
	if hint_label:
		hint_label.text = tr("META_EDIT_HINT")
	var title_field_label := get_node_or_null("%s/TitleRow/TitleFieldLabel" % _FORM)
	if title_field_label:
		title_field_label.text = tr("META_FIELD_TITLE")
	var artist_field_label := get_node_or_null("%s/ArtistRow/ArtistFieldLabel" % _FORM)
	if artist_field_label:
		artist_field_label.text = tr("META_FIELD_ARTIST")
	var year_field_label := get_node_or_null("%s/YearRow/YearFieldLabel" % _FORM)
	if year_field_label:
		year_field_label.text = tr("META_FIELD_YEAR")
	var bpm_field_label := get_node_or_null("%s/BpmRow/BpmFieldLabel" % _FORM)
	if bpm_field_label:
		bpm_field_label.text = tr("META_FIELD_BPM")
	var genre_field_label := get_node_or_null("%s/GenreRow/GenreFieldLabel" % _FORM)
	if genre_field_label:
		genre_field_label.text = tr("META_FIELD_GENRE")
	var bpm_server_lbl := get_node_or_null("%s/BpmRow/BpmControlsHBox/BpmFromServerBadge/BadgeHBox/BpmFromServerLabel" % _FORM)
	if bpm_server_lbl:
		bpm_server_lbl.text = tr("META_BPM_FROM_SERVER")
	var genre_server_lbl := get_node_or_null("%s/GenreRow/GenreControlsHBox/GenreFromServerBadge/BadgeHBox/GenreFromServerLabel" % _FORM)
	if genre_server_lbl:
		genre_server_lbl.text = tr("META_BPM_FROM_SERVER")
	var save_btn := get_node_or_null("%s/FooterHBox/SaveButton" % _RIGHT)
	if save_btn:
		save_btn.text = tr("META_SAVE_CHANGES")
	var esc_hint := get_node_or_null("Container/EscHintLabel")
	if esc_hint:
		esc_hint.text = tr("META_ESC_CANCEL")
	if _title_edit:
		_title_edit.placeholder_text = tr("META_PLACEHOLDER_TITLE")
	if _artist_edit:
		_artist_edit.placeholder_text = tr("META_PLACEHOLDER_ARTIST")
	_update_sidebar_labels()
	_update_genre_button_text()
	_update_bpm_from_server_badge()
	_update_genre_from_server_badge()
	_refresh_info_callout()


func _setup_hint_callouts() -> void:
	var genre_slot := get_node_or_null("%GenreHintSlot") as VBoxContainer
	if genre_slot:
		for child in genre_slot.get_children():
			child.queue_free()
		var genre_tip := HELP_CALLOUT_SCENE.instantiate()
		genre_slot.add_child(genre_tip)
		if genre_tip.has_method("setup"):
			genre_tip.setup("tip", tr("GENRE_PICK_HINT"), true)
	var slot := get_node_or_null("%InfoCalloutSlot") as VBoxContainer
	if slot == null:
		return
	for child in slot.get_children():
		child.queue_free()
	var callout := HELP_CALLOUT_SCENE.instantiate()
	slot.add_child(callout)
	callout.set_meta("meta_info_callout", true)
	if callout.has_method("setup"):
		callout.setup("info", tr("META_INFO_EMPTY"), true)


func _refresh_info_callout() -> void:
	var genre_slot := get_node_or_null("%GenreHintSlot") as VBoxContainer
	if genre_slot:
		for child in genre_slot.get_children():
			if child.has_method("setup"):
				child.setup("tip", tr("GENRE_PICK_HINT"), true)
	var slot := get_node_or_null("%InfoCalloutSlot") as VBoxContainer
	if slot == null:
		return
	for child in slot.get_children():
		if child.has_method("setup"):
			child.setup("info", tr("META_INFO_EMPTY"), true)


func _setup_ui_icons() -> void:
	var save_btn := get_node_or_null("%s/FooterHBox/SaveButton" % _RIGHT) as Button
	UiIconHelper.setup_confirm_button(save_btn)
	var title_lbl := get_node_or_null("%s/TitleRow/TitleFieldLabel" % _FORM) as Label
	var artist_lbl := get_node_or_null("%s/ArtistRow/ArtistFieldLabel" % _FORM) as Label
	var year_lbl := get_node_or_null("%s/YearRow/YearFieldLabel" % _FORM) as Label
	var bpm_lbl := get_node_or_null("%s/BpmRow/BpmFieldLabel" % _FORM) as Label
	var genre_lbl := get_node_or_null("%s/GenreRow/GenreFieldLabel" % _FORM) as Label
	UiIconHelper.add_icon_before_label(title_lbl, "pencil.svg", false, UiIconHelper.ACCENT)
	UiIconHelper.add_icon_before_label(artist_lbl, "mic-vocal.svg", false, UiIconHelper.ACCENT)
	UiIconHelper.add_icon_before_label(year_lbl, "hash.svg", false, UiIconHelper.ACCENT)
	UiIconHelper.add_icon_before_label(bpm_lbl, "metronome.svg", false, UiIconHelper.ACCENT)
	UiIconHelper.add_icon_before_label(genre_lbl, "tags.svg", false, UiIconHelper.ACCENT)
	_populate_readonly_icon(_LEFT + "/ReadOnlyPanel/ReadOnlyVBox/DurationRow/DurationIconSlot", "circle-play.svg")
	_populate_readonly_icon(_LEFT + "/ReadOnlyPanel/ReadOnlyVBox/FileSizeRow/FileSizeIconSlot", "database.svg")
	_populate_readonly_icon(_LEFT + "/ReadOnlyPanel/ReadOnlyVBox/FilePathRow/FilePathIconSlot", "folder-open.svg")
	_populate_readonly_icon(_LEFT + "/ReadOnlyPanel/ReadOnlyVBox/DateAddedRow/DateAddedIconSlot", "archive.svg")
	var badge_icon := get_node_or_null("%s/BpmRow/BpmControlsHBox/BpmFromServerBadge/BadgeHBox/BadgeIconSlot" % _FORM)
	if badge_icon:
		_populate_readonly_icon_node(badge_icon, "server.svg", Color(0.38, 0.78, 0.74))
	var genre_badge_icon := get_node_or_null("%s/GenreRow/GenreControlsHBox/GenreFromServerBadge/BadgeHBox/BadgeIconSlot" % _FORM)
	if genre_badge_icon:
		_populate_readonly_icon_node(genre_badge_icon, "server.svg", Color(0.38, 0.78, 0.74))


func _populate_readonly_icon(slot_path: String, icon_file: String, tint: Color = UiIconHelper.MUTED) -> void:
	var slot := get_node_or_null(slot_path) as HBoxContainer
	if slot == null:
		return
	_populate_readonly_icon_node(slot, icon_file, tint)


func _populate_readonly_icon_node(slot: HBoxContainer, icon_file: String, tint: Color = UiIconHelper.MUTED) -> void:
	if slot == null:
		return
	for child in slot.get_children():
		child.queue_free()
	slot.add_child(UiIconHelper.make_icon_frame(icon_file, 28, 15, tint))


func setup(song_data: Dictionary, focus_field: String = "") -> void:
	_song_data = song_data.duplicate(true)
	_focus_field = focus_field


func _apply_song_data() -> void:
	_initial_title = str(_song_data.get("title", ""))
	if _initial_title == "Без названия" or _initial_title == _SS._translate("VALUE_NO_TITLE"):
		_initial_title = ""
	if _title_edit:
		_title_edit.text = _initial_title
	_initial_artist = str(_song_data.get("artist", ""))
	if _initial_artist == "Неизвестен" or _initial_artist == _SS._translate("VALUE_UNKNOWN_ARTIST") or _initial_artist == "Unknown":
		_initial_artist = ""
	if _artist_edit:
		_artist_edit.text = _initial_artist
	var year_str := str(_song_data.get("year", "")).strip_edges()
	var current_year: int = Time.get_datetime_dict_from_system()["year"]
	_initial_year_present = year_str != "" and not _SS.is_missing_metadata_value(year_str) and year_str.is_valid_int()
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
	var bpm_present := not _SS.is_missing_metadata_value(bpm_str) and bpm_str.is_valid_int()
	if _bpm_spin:
		if bpm_present:
			_initial_bpm_value = clampi(bpm_str.to_int(), int(_bpm_spin.min_value), int(_bpm_spin.max_value))
		else:
			_initial_bpm_value = int(_bpm_spin.value)
		_bpm_spin.value = _initial_bpm_value
	_initial_bpm_from_server = bool(_song_data.get("bpm_from_server", false))
	_update_bpm_from_server_badge()
	_initial_genre_from_server = bool(_song_data.get("genre_from_server", false))
	_pending_genre_from_server = _initial_genre_from_server
	_update_genre_from_server_badge()
	_pending_primary_genre = str(_song_data.get("primary_genre", ""))
	if _pending_genres is Array:
		var src_genres = _song_data.get("genres", [])
		_pending_genres = src_genres.duplicate() if src_genres is Array else []
	_update_genre_button_text()
	_update_sidebar_preview_text()


func _update_bpm_from_server_badge() -> void:
	if _bpm_from_server_badge:
		_bpm_from_server_badge.visible = _initial_bpm_from_server


func _update_genre_from_server_badge() -> void:
	if _genre_from_server_badge:
		var show_badge := _pending_genre_from_server if _genre_changed else _initial_genre_from_server
		_genre_from_server_badge.visible = show_badge


func _update_sidebar_preview_text() -> void:
	if _track_title_label:
		var title := _initial_title
		if title == "":
			title = tr("VALUE_NO_TITLE")
		_track_title_label.text = title
	if _track_artist_label:
		var artist := _initial_artist
		if artist == "":
			artist = tr("VALUE_UNKNOWN_ARTIST")
		_track_artist_label.text = artist


func _update_sidebar_labels() -> void:
	if _duration_label:
		var dur := str(_song_data.get("duration", "00:00"))
		if _SS.is_missing_metadata_value(dur):
			dur = "00:00"
		_duration_label.text = "%s: %s" % [tr("META_FIELD_DURATION"), dur]
	if _file_size_label:
		_file_size_label.text = "%s: %s" % [tr("META_FIELD_FILE_SIZE"), _format_file_size(_song_data.get("path", ""))]
	if _file_path_label:
		_file_path_label.text = "%s: %s" % [tr("META_FIELD_FILE_PATH"), _display_path(str(_song_data.get("path", "")))]
	if _date_added_label:
		_date_added_label.text = "%s: %s" % [tr("META_FIELD_DATE_ADDED"), _format_date_added()]
	if _format_badge:
		_format_badge.text = _format_badge_text(str(_song_data.get("path", "")))


func _apply_sidebar_info() -> void:
	_update_sidebar_labels()


func _format_badge_text(path: String) -> String:
	if path == "":
		return "—"
	return path.get_extension().to_upper()


func _format_file_size(path: String) -> String:
	if path == "":
		return "—"
	var global_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(global_path):
		return "—"
	var bytes := FileAccess.get_size(global_path)
	if bytes < 1024:
		return "%d B" % bytes
	if bytes < 1024 * 1024:
		return "%.1f KB" % (float(bytes) / 1024.0)
	return "%.1f MB" % (float(bytes) / (1024.0 * 1024.0))


func _display_path(path: String) -> String:
	if path == "":
		return "—"
	var norm := path.replace("\\", "/")
	var lib := str(SettingsManager.get_setting("music_folder_path", "")).replace("\\", "/").trim_suffix("/")
	if lib != "" and norm.begins_with(lib):
		var rel := norm.substr(lib.length()).trim_prefix("/")
		if rel != "":
			return rel
	var parts := norm.split("/")
	if parts.size() >= 2:
		return "%s/%s" % [parts[parts.size() - 2], parts[parts.size() - 1]]
	return norm.get_file()


func _format_date_added() -> String:
	var mtime: int = int(_song_data.get("file_mtime", 0))
	if mtime <= 0:
		var path := str(_song_data.get("path", ""))
		if path != "":
			mtime = int(FileAccess.get_modified_time(ProjectSettings.globalize_path(path)))
	if mtime <= 0:
		return "—"
	var dt := Time.get_datetime_dict_from_unix_time(mtime)
	return "%02d.%02d.%04d %02d:%02d" % [
		int(dt.get("day", 1)),
		int(dt.get("month", 1)),
		int(dt.get("year", 2000)),
		int(dt.get("hour", 0)),
		int(dt.get("minute", 0)),
	]


func _load_cover_texture() -> void:
	if _cover_texture_rect == null:
		return
	var path := str(_song_data.get("path", ""))
	var cover = _song_data.get("cover", null)
	if cover is ImageTexture:
		_cover_texture_rect.texture = cover
		return
	if path == "":
		return
	var sidecar := _try_sidecar_cover(path)
	if sidecar:
		_cover_texture_rect.texture = sidecar
		return
	call_deferred("_load_embedded_cover", path)


func _try_sidecar_cover(path: String) -> Texture2D:
	var base := path.get_basename()
	for ext in ["jpg", "jpeg", "png", "webp"]:
		var sidecar := "%s.%s" % [base, ext]
		if FileAccess.file_exists(ProjectSettings.globalize_path(sidecar)):
			var img := Image.load_from_file(ProjectSettings.globalize_path(sidecar))
			if img:
				return ImageTexture.create_from_image(img)
	return null


func _load_embedded_cover(path: String) -> void:
	if _cover_texture_rect == null or path == "":
		return
	var ext := path.get_extension().to_lower()
	if ext != "mp3" and ext != "wav" and ext != "ogg" and ext != "flac":
		_apply_fallback_cover()
		return
	var global_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(global_path):
		_apply_fallback_cover()
		return
	var file_access := FileAccess.open(global_path, FileAccess.READ)
	if not file_access:
		_apply_fallback_cover()
		return
	var file_data := file_access.get_buffer(file_access.get_length())
	file_access.close()
	var md := MusicMetadata.new()
	md.set_from_data(file_data)
	if md.cover is ImageTexture:
		_cover_texture_rect.texture = md.cover
	else:
		_apply_fallback_cover()


func _apply_fallback_cover() -> void:
	if _cover_texture_rect == null:
		return
	var song_path := str(_song_data.get("path", ""))
	var texture := TrackPlaceholderCover.load_texture(song_path, true)
	if texture:
		_cover_texture_rect.texture = texture


func _update_genre_button_text() -> void:
	if not _genre_button:
		return
	var g := str(_pending_primary_genre).strip_edges()
	if g == "" or g == "unknown":
		_genre_button.text = tr("META_GENRE_NONE")
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
	_UiModifierSounds.play_select()
	var dlg_scene = load(GENRE_PICKER_SCENE)
	if not dlg_scene:
		return
	var dlg = dlg_scene.instantiate()
	_genre_picker = dlg
	dlg.auto_close = false
	var song_path := str(_song_data.get("path", ""))
	var cached_preds: Array = []
	if song_path != "":
		var meta := SongLibrary.get_metadata_for_song(song_path)
		var raw_preds = meta.get("genre_predictions", [])
		if raw_preds is Array:
			cached_preds = raw_preds
	if dlg.has_method("configure"):
		dlg.configure(song_path, cached_preds)
	if dlg.has_method("set_initial"):
		dlg.set_initial(_pending_primary_genre)
	dlg.genre_selected.connect(_on_genre_selected_from_picker)
	dlg.tree_exited.connect(func() -> void:
		_genre_picker = null
		_UiModifierSounds.play_deselect()
	)
	add_child(dlg)
	UiInteractionApplier.apply_from_engine(dlg)


func _on_genre_selected_from_picker(primary_genre: String, all_genres: Array, from_server: bool = false) -> void:
	_genre_changed = true
	_pending_primary_genre = primary_genre
	_pending_genre_from_server = from_server and primary_genre != "" and primary_genre != "unknown"
	if primary_genre == "unknown":
		_pending_genres = []
	elif all_genres is Array and all_genres.size() > 0:
		_pending_genres = all_genres.duplicate()
	else:
		_pending_genres = []
	_update_genre_button_text()
	_update_genre_from_server_badge()


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
			fields["bpm_from_server"] = false

	if _genre_changed:
		fields["primary_genre"] = _pending_primary_genre
		fields["genre_from_server"] = _pending_genre_from_server
		if _pending_primary_genre == "unknown":
			fields["genres"] = []
		elif _pending_genres is Array and _pending_genres.size() > 0:
			fields["genres"] = _pending_genres

	return fields


func _on_save_button_pressed() -> void:
	var fields := _collect_changed_fields()
	if fields.size() > 0:
		_notify_metadata_saved_achievement()
	_UiModifierSounds.play_deselect()
	queue_free()
	emit_signal("metadata_saved", fields)


func _notify_metadata_saved_achievement() -> void:
	var ge := get_tree().root.get_node_or_null("GameEngine")
	if ge == null:
		ge = get_tree().root.find_child("GameEngine", true, false)
	if ge and ge.has_method("get_achievement_system"):
		var ach = ge.get_achievement_system()
		if ach and ach.has_method("on_metadata_saved"):
			ach.on_metadata_saved()


func _on_back_button_pressed() -> void:
	queue_free()
	emit_signal("cancelled")


func _input(event: InputEvent) -> void:
	if _genre_picker and is_instance_valid(_genre_picker):
		return
	if event.is_action_pressed("ui_cancel"):
		_on_back_button_pressed()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if _genre_picker and is_instance_valid(_genre_picker):
		return
	var bindings := {
		KEY_ENTER: _on_save_button_pressed,
		KEY_KP_ENTER: _on_save_button_pressed,
	}
	if UiScreenHotkeys.try_handle(bindings, event, get_viewport()):
		get_viewport().set_input_as_handled()
