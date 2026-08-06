# scenes/settings_menu/tabs/library_tab.gd
extends Control

signal settings_changed

const _SettingsDialogUtils = preload("res://logic/ui/settings_dialog_utils.gd")
const _Overlay = preload("res://logic/ui/app_overlay_helpers.gd")
const _SettingsSectionUi = preload("res://logic/ui/settings_section_ui.gd")

var song_metadata_manager = SongLibrary

const _CV := "ScrollWrap/CenterWrap/ContentVBox"
const _SONGS := "%s/SongsFolderPanel/SongsFolderPanelMargin/SongsFolderRows" % _CV
const _SCAN := "%s/ScanPanel/ScanPanelMargin/ScanRows" % _CV
const _NOTES := "%s/NotesFolderPanel/NotesFolderPanelMargin/NotesFolderRows" % _CV
const _OPTS := "%s/LibraryOptionsPanel/LibraryOptionsPanelMargin/LibraryOptionsRows" % _CV
const _DIARY := "%s/DiaryLinksPanel/DiaryLinksPanelMargin/DiaryLinksRows" % _CV

@onready var songs_header: Label = get_node("%s/SongsFolderHeader" % _SONGS)
@onready var songs_folder_hint: Label = get_node("%s/SongsFolderHint" % _SONGS)
@onready var scan_header: Label = get_node("%s/ScanHeader" % _SCAN)
@onready var scan_hint: Label = get_node("%s/ScanHint" % _SCAN)
@onready var last_scan_label: Label = get_node("%s/LastScanLabel" % _SCAN)
@onready var notes_header: Label = get_node("%s/NotesFolderHeader" % _NOTES)
@onready var notes_hint: Label = get_node_or_null("%s/NotesHint" % _NOTES)
@onready var notes_help_link: LinkButton = get_node_or_null("%s/NotesHelpLink" % _NOTES)
@onready var options_header: Label = get_node("%s/LibraryOptionsHeader" % _OPTS)
@onready var library_options_hint: Label = get_node("%s/LibraryOptionsHint" % _OPTS)
@onready var songs_folder_line_edit: LineEdit = get_node("%s/SongsFolderHBox/SongsFolderLineEdit" % _SONGS)
@onready var notes_folder_line_edit: LineEdit = get_node("%s/NotesFolderHBox/NotesFolderLineEdit" % _NOTES)
@onready var open_songs_folder_button: Button = %OpenSongsFolderButton
@onready var open_notes_folder_button: Button = %OpenNotesFolderButton
@onready var show_chart_id_checkbox: CheckBox = get_node("%s/ShowChartIdCheckBox" % _OPTS)
@onready var diary_links_header: Label = get_node_or_null("%s/DiaryLinksHeader" % _DIARY)
@onready var diary_links_hint: Label = get_node_or_null("%s/DiaryLinksHint" % _DIARY)
@onready var diary_history_open_day_checkbox: CheckBox = get_node_or_null("%s/DiaryHistoryOpenDayCheckBox" % _DIARY)
@onready var diary_history_open_track_checkbox: CheckBox = get_node_or_null("%s/DiaryHistoryOpenTrackCheckBox" % _DIARY)
@onready var diary_open_track_museum_checkbox: CheckBox = get_node_or_null("%s/DiaryOpenTrackMuseumCheckBox" % _DIARY)
@onready var songs_folder_dialog: FileDialog = $SongsFolderDialog
@onready var notes_folder_dialog: FileDialog = $NotesFolderDialog
@onready var _notice_overlay: AppNoticeOverlay = %NoticeOverlay
@onready var _confirm_overlay: AppConfirmOverlay = %ConfirmOverlay
@onready var _songs_folder_overlay: AppSongsFolderChangeOverlay = %SongsFolderChangeOverlay

var _pending_new_folder_path: String = ""
var _pending_new_notes_folder_path: String = ""
var _pending_dedupe_user_root: String = ""
var _pending_dedupe_match_count: int = 0


func setup_ui_and_manager(_screen = null, metadata_mgr = null, _achievement_manager = null) -> void:
	if metadata_mgr:
		song_metadata_manager = metadata_mgr


func _ready() -> void:
	add_to_group("locale_refresh")
	_setup_folder_dialogs()
	call_deferred("_apply_initial_settings")
	call_deferred("apply_locale")
	call_deferred("_apply_dialog_styles")
	call_deferred("_apply_settings_checkbox_styles")


func _apply_dialog_styles() -> void:
	_SettingsDialogUtils.apply_to_descendants(self)


func _apply_settings_checkbox_styles() -> void:
	const AMBER := Color(0.92, 0.78, 0.45, 1.0)
	_SettingsSectionUi.apply_settings_checkbox(show_chart_id_checkbox, 22, false, AMBER)
	_SettingsSectionUi.apply_settings_checkbox(diary_history_open_day_checkbox, 22, false, AMBER)
	_SettingsSectionUi.apply_settings_checkbox(diary_history_open_track_checkbox, 22, false, AMBER)
	_SettingsSectionUi.apply_settings_checkbox(diary_open_track_museum_checkbox, 22, false, AMBER)


func apply_locale() -> void:
	if songs_header:
		songs_header.text = tr("MISC_SONGS_FOLDER_SECTION")
	if songs_folder_hint:
		songs_folder_hint.text = tr("LIBRARY_SONGS_FOLDER_SECTION_HINT")
	if scan_header:
		scan_header.text = tr("MISC_LIBRARY_SCAN_SECTION")
	if scan_hint:
		scan_hint.text = tr("LIBRARY_SCAN_SECTION_HINT")
	_update_last_scan_label()
	if notes_header:
		notes_header.text = tr("MISC_NOTES_FOLDER_SECTION")
	if notes_hint:
		notes_hint.text = tr("MISC_NOTES_FOLDER_TOOLTIP")
	if notes_help_link:
		notes_help_link.text = tr("SETTINGS_HELP_LINK_NOTES")
		notes_help_link.add_theme_color_override("font_color", Color(0.96, 0.82, 0.34, 1.0))
	if options_header:
		options_header.text = tr("MISC_LIBRARY_OPTIONS_SECTION")
	if library_options_hint:
		library_options_hint.text = tr("LIBRARY_OPTIONS_SECTION_HINT")
	var songs_folder_label: Label = get_node_or_null("%s/SongsFolderHBox/SongsFolderLabel" % _SONGS)
	if songs_folder_label:
		songs_folder_label.text = tr("MISC_SONGS_FOLDER_LABEL")
	var choose_folder_btn: Button = get_node_or_null("%s/SongsFolderHBox/ChooseSongsFolderButton" % _SONGS)
	if choose_folder_btn:
		choose_folder_btn.text = tr("MISC_CHOOSE_FOLDER")
	if open_songs_folder_button:
		open_songs_folder_button.text = tr("LIBRARY_OPEN_FOLDER")
	var scan_btn: Button = get_node_or_null("%s/ScanButtonRow/ScanSongsButton" % _SCAN)
	if scan_btn:
		scan_btn.text = tr("MISC_SCAN_SONGS")
	var notes_folder_label: Label = get_node_or_null("%s/NotesFolderHBox/NotesFolderLabel" % _NOTES)
	if notes_folder_label:
		notes_folder_label.text = tr("MISC_NOTES_FOLDER_LABEL")
	var choose_notes_btn: Button = get_node_or_null("%s/NotesFolderHBox/ChooseNotesFolderButton" % _NOTES)
	if choose_notes_btn:
		choose_notes_btn.text = tr("MISC_CHOOSE_FOLDER")
	if open_notes_folder_button:
		open_notes_folder_button.text = tr("LIBRARY_OPEN_FOLDER")
	if show_chart_id_checkbox:
		show_chart_id_checkbox.text = tr("MISC_SHOW_CHART_ID")
	if diary_links_header:
		diary_links_header.text = tr("SETTINGS_DIARY_LINKS_SECTION")
	if diary_links_hint:
		diary_links_hint.text = tr("SETTINGS_DIARY_LINKS_HINT")
	if diary_history_open_day_checkbox:
		diary_history_open_day_checkbox.text = tr("SETTINGS_DIARY_HISTORY_OPEN_DAY")
		diary_history_open_day_checkbox.tooltip_text = tr("SETTINGS_DIARY_HISTORY_OPEN_DAY_TIP")
	if diary_history_open_track_checkbox:
		diary_history_open_track_checkbox.text = tr("SETTINGS_DIARY_HISTORY_OPEN_TRACK")
		diary_history_open_track_checkbox.tooltip_text = tr("SETTINGS_DIARY_HISTORY_OPEN_TRACK_TIP")
	if diary_open_track_museum_checkbox:
		diary_open_track_museum_checkbox.text = tr("SETTINGS_DIARY_OPEN_TRACK_MUSEUM")
		diary_open_track_museum_checkbox.tooltip_text = tr("SETTINGS_DIARY_OPEN_TRACK_MUSEUM_TIP")
	_apply_dialogs()
	_apply_tooltips()
	_apply_dialog_styles()


func _apply_tooltips() -> void:
	var songs_folder_label: Label = get_node_or_null("%s/SongsFolderHBox/SongsFolderLabel" % _SONGS)
	if songs_folder_label:
		songs_folder_label.tooltip_text = tr("MISC_SONGS_FOLDER_TOOLTIP")
	if songs_folder_line_edit:
		songs_folder_line_edit.tooltip_text = tr("MISC_SONGS_FOLDER_TOOLTIP")
	var choose_folder_btn: Button = get_node_or_null("%s/SongsFolderHBox/ChooseSongsFolderButton" % _SONGS)
	if choose_folder_btn:
		choose_folder_btn.tooltip_text = tr("MISC_CHOOSE_FOLDER_TOOLTIP")
	if open_songs_folder_button:
		open_songs_folder_button.tooltip_text = tr("LIBRARY_OPEN_FOLDER_TOOLTIP")
	var scan_btn: Button = get_node_or_null("%s/ScanButtonRow/ScanSongsButton" % _SCAN)
	if scan_btn:
		scan_btn.tooltip_text = tr("MISC_SCAN_SONGS_TOOLTIP")
	if open_notes_folder_button:
		open_notes_folder_button.tooltip_text = tr("LIBRARY_OPEN_FOLDER_TOOLTIP")
	if notes_folder_line_edit:
		notes_folder_line_edit.tooltip_text = tr("MISC_NOTES_FOLDER_TOOLTIP")
	if show_chart_id_checkbox:
		show_chart_id_checkbox.tooltip_text = tr("MISC_SHOW_CHART_ID_TOOLTIP")


func _on_notes_help_link_pressed() -> void:
	var shell := _settings_shell()
	if shell and shell.has_method("open_help_item"):
		shell.open_help_item("notes_folder_rf")
	elif shell and shell.has_method("open_help_topic"):
		shell.open_help_topic("SETTINGS_HELP_SEARCH_NOTES")


func _settings_shell() -> Node:
	var node: Node = self
	while node:
		if node.has_method("open_help_topic"):
			return node
		node = node.get_parent()
	return null


func _apply_dialogs() -> void:
	if _confirm_overlay:
		_confirm_overlay.apply_locale()
	if _notice_overlay:
		_notice_overlay.apply_locale()
	if _songs_folder_overlay:
		_songs_folder_overlay.apply_locale()


func _setup_folder_dialogs() -> void:
	for dlg in [songs_folder_dialog, notes_folder_dialog]:
		if dlg == null:
			continue
		dlg.use_native_dialog = true
		dlg.access = FileDialog.ACCESS_FILESYSTEM
		dlg.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		dlg.unresizable = true


func _hide_window_dialog(dlg: Window) -> void:
	if dlg and is_instance_valid(dlg) and dlg.visible:
		dlg.hide()


func _folder_dialog_start_dir(setting_key: String, default_path: String) -> String:
	var stored := String(SettingsManager.get_setting(setting_key, ""))
	var path := stored if stored != "" else default_path
	if path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	if path.begins_with("res://"):
		return ProjectSettings.globalize_path(path)
	return path


func _sanitize_path(path: String) -> String:
	return String(path).strip_edges().replace("\uFFFD", "")


func _on_open_songs_folder_pressed() -> void:
	var path := _normalize_songs_folder_path(String(SettingsManager.get_setting("user_songs_path", "")))
	_open_folder_path(path)


func _on_open_notes_folder_pressed() -> void:
	var stored := String(SettingsManager.get_setting("user_notes_path", ""))
	var path := stored if stored != "" else NotesUtils.DEFAULT_NOTES_ROOT
	_open_folder_path(path)


func _open_folder_path(path: String) -> void:
	var abs_path := path.strip_edges()
	if abs_path == "":
		return
	if abs_path.begins_with("user://") or abs_path.begins_with("res://"):
		abs_path = ProjectSettings.globalize_path(abs_path)
	abs_path = abs_path.replace("\\", "/")
	DirAccess.make_dir_recursive_absolute(abs_path)
	OS.shell_open(abs_path)


func _apply_initial_settings() -> void:
	var p = String(SettingsManager.get_setting("user_songs_path", ""))
	if p == "":
		p = "user://Songs"
	songs_folder_line_edit.text = p
	var notes_p := String(SettingsManager.get_setting("user_notes_path", ""))
	if notes_p == "":
		notes_p = NotesUtils.DEFAULT_NOTES_ROOT
	notes_folder_line_edit.text = notes_p
	show_chart_id_checkbox.set_pressed_no_signal(bool(SettingsManager.get_setting("show_chart_id", false)))
	if diary_history_open_day_checkbox:
		diary_history_open_day_checkbox.set_pressed_no_signal(
			bool(SettingsManager.get_setting("diary_history_open_day", false))
		)
	if diary_history_open_track_checkbox:
		diary_history_open_track_checkbox.set_pressed_no_signal(
			bool(SettingsManager.get_setting("diary_history_open_track", false))
		)
	if diary_open_track_museum_checkbox:
		diary_open_track_museum_checkbox.set_pressed_no_signal(
			bool(SettingsManager.get_setting("diary_open_track_museum", false))
		)
	_update_last_scan_label()


func _update_last_scan_label() -> void:
	if last_scan_label == null:
		return
	var unix := int(SettingsManager.get_setting("library_last_scan_unix", 0))
	if unix <= 0:
		last_scan_label.text = tr("MISC_LIBRARY_LAST_SCAN_NEVER")
		return
	var when := Time.get_datetime_string_from_unix_time(unix, true)
	last_scan_label.text = tr("MISC_LIBRARY_LAST_SCAN") % when


func _sync_settings_snapshot() -> void:
	var shell := _settings_shell()
	if shell and shell.has_method("sync_persisted_settings_snapshot"):
		shell.sync_persisted_settings_snapshot()


func _record_library_scan() -> void:
	SettingsManager.set_setting("library_last_scan_unix", int(Time.get_unix_time_from_system()))
	SettingsManager.save_settings()
	_update_last_scan_label()
	_sync_settings_snapshot()


func _on_choose_songs_folder_pressed() -> void:
	if songs_folder_dialog:
		songs_folder_dialog.current_dir = _folder_dialog_start_dir("user_songs_path", "user://Songs")
		songs_folder_dialog.popup_centered()


func _on_choose_notes_folder_pressed() -> void:
	if notes_folder_dialog:
		notes_folder_dialog.current_dir = _folder_dialog_start_dir("user_notes_path", NotesUtils.DEFAULT_NOTES_ROOT)
		notes_folder_dialog.popup_centered()


func _normalize_notes_folder_path(p: String) -> String:
	return NotesUtils.normalize_notes_root(p)


func _on_notes_folder_dir_selected(path: String) -> void:
	_hide_window_dialog(notes_folder_dialog)
	path = _sanitize_path(path)
	var old_path := _normalize_notes_folder_path(String(SettingsManager.get_setting("user_notes_path", "")))
	if old_path == "":
		old_path = NotesUtils.DEFAULT_NOTES_ROOT
	var new_path := _normalize_notes_folder_path(path)
	notes_folder_line_edit.text = new_path
	if old_path == new_path:
		return
	_pending_new_notes_folder_path = new_path
	_confirm_change_notes_folder()


func _confirm_change_notes_folder() -> void:
	if await _Overlay.ask(
		_confirm_overlay,
		tr("DLG_CHANGE_NOTES_FOLDER_TEXT"),
		"warning",
		"",
		tr("BTN_SAVE"),
	):
		if _pending_new_notes_folder_path != "":
			_apply_new_notes_folder_path(_pending_new_notes_folder_path)
	else:
		_on_change_notes_folder_canceled()


func _apply_new_notes_folder_path(new_path: String) -> void:
	var stored := new_path
	if stored == NotesUtils.DEFAULT_NOTES_ROOT:
		stored = ""
	SettingsManager.set_setting("user_notes_path", stored)
	notes_folder_line_edit.text = new_path if stored != "" else NotesUtils.DEFAULT_NOTES_ROOT
	_pending_new_notes_folder_path = ""
	emit_signal("settings_changed")


func _on_change_notes_folder_canceled() -> void:
	_pending_new_notes_folder_path = ""
	var stored := String(SettingsManager.get_setting("user_notes_path", ""))
	notes_folder_line_edit.text = stored if stored != "" else NotesUtils.DEFAULT_NOTES_ROOT


func _on_show_chart_id_toggled(enabled: bool) -> void:
	SettingsManager.set_setting("show_chart_id", enabled)
	emit_signal("settings_changed")
	_call_refresh_chart_id_recursive(get_tree().root)


func _on_diary_history_open_day_toggled(enabled: bool) -> void:
	SettingsManager.set_setting("diary_history_open_day", enabled)
	emit_signal("settings_changed")


func _on_diary_history_open_track_toggled(enabled: bool) -> void:
	SettingsManager.set_setting("diary_history_open_track", enabled)
	emit_signal("settings_changed")


func _on_diary_open_track_museum_toggled(enabled: bool) -> void:
	SettingsManager.set_setting("diary_open_track_museum", enabled)
	emit_signal("settings_changed")


func _call_refresh_chart_id_recursive(node: Node) -> void:
	if node == null:
		return
	if node.has_method("refresh_chart_id_visibility"):
		node.refresh_chart_id_visibility()
	for child in node.get_children():
		_call_refresh_chart_id_recursive(child)


func _normalize_songs_folder_path(p: String) -> String:
	var s := String(p)
	if s == "":
		s = "user://Songs/"
	if not s.ends_with("/"):
		s += "/"
	return s


func _on_songs_folder_dir_selected(path: String) -> void:
	_hide_window_dialog(songs_folder_dialog)
	path = _sanitize_path(path)
	var old_path := _normalize_songs_folder_path(String(SettingsManager.get_setting("user_songs_path", "")))
	var new_path := _normalize_songs_folder_path(String(path))
	songs_folder_line_edit.text = new_path
	if old_path == new_path:
		return
	_pending_new_folder_path = new_path
	_confirm_change_songs_folder()


func _confirm_change_songs_folder() -> void:
	var result := await _Overlay.ask_songs_folder_change(
		_songs_folder_overlay,
		tr("DLG_CHANGE_SONGS_FOLDER_TEXT"),
	)
	match String(result.get("action", "cancel")):
		"save":
			if _pending_new_folder_path != "":
				_apply_new_songs_folder_path(_pending_new_folder_path, false, false)
		"prune":
			if _pending_new_folder_path != "":
				_apply_new_songs_folder_path(
					_pending_new_folder_path,
					true,
					bool(result.get("delete_notes", false)),
				)
		_:
			_on_change_songs_folder_canceled()


func _apply_new_songs_folder_path(new_path: String, prune: bool, delete_notes: bool) -> void:
	SettingsManager.set_setting("user_songs_path", new_path)
	SettingsManager.save_settings()
	songs_folder_line_edit.text = new_path
	if prune and SongLibrary and SongLibrary.has_method("prune_user_metadata_not_under_root"):
		SongLibrary.prune_user_metadata_not_under_root(new_path, delete_notes)
	if SongLibrary:
		SongLibrary.load_songs()
	_pending_new_folder_path = ""
	_sync_settings_snapshot()


func _on_change_songs_folder_canceled() -> void:
	_pending_new_folder_path = ""
	songs_folder_line_edit.text = _normalize_songs_folder_path(String(SettingsManager.get_setting("user_songs_path", "")))


func _find_status_dock() -> StatusDock:
	var ge := get_tree().root.get_node_or_null("GameEngine")
	if ge and ge.has_method("get_status_dock"):
		return ge.get_status_dock()
	return null


func _on_scan_songs_pressed() -> void:
	if not SongLibrary or not SongLibrary.has_method("scan_user_songs"):
		return
	var dock := _find_status_dock()
	if dock:
		dock.show_transient("library_scan", tr("STATUS_LIBRARY_SCANNING"), "scan", 0.0)
	var added: int = SongLibrary.scan_user_songs()
	_record_library_scan()
	if dock:
		if added > 0:
			dock.show_transient("library_scan", tr("MISC_SCAN_SONGS_ADDED") % added, "success", 3.0)
		else:
			dock.show_transient("library_scan", tr("MISC_SCAN_SONGS_NONE"), "info", 2.5)
	_pending_dedupe_user_root = ""
	_pending_dedupe_match_count = 0
	var current_root = String(SettingsManager.get_setting("user_songs_path", ""))
	if current_root == "":
		current_root = "user://Songs/"
	if not current_root.ends_with("/"):
		current_root += "/"
	if SongLibrary.has_method("prepare_dedupe_for_user_root"):
		var prep = SongLibrary.prepare_dedupe_for_user_root(current_root)
		var matches: Dictionary = prep.get("matches", {})
		if matches.size() > 0:
			_pending_dedupe_user_root = current_root
			_pending_dedupe_match_count = matches.size()
	_show_scan_result_flow(added)
	if _pending_dedupe_match_count > 0 and dock:
		dock.show_transient(
			"library_dedupe",
			tr("STATUS_LIBRARY_DEDUPE_HINT") % _pending_dedupe_match_count,
			"warning",
			4.5
		)


func _show_scan_result_flow(added: int) -> void:
	var message := tr("MISC_SCAN_SONGS_ADDED") % added if added > 0 else tr("MISC_SCAN_SONGS_NONE")
	_notice_overlay.show_message(message)
	await _notice_overlay.dismissed
	if _pending_dedupe_match_count > 0:
		await _show_dedupe_confirm()


func _show_dedupe_confirm() -> void:
	if _pending_dedupe_match_count <= 0:
		return
	if await _Overlay.ask(
		_confirm_overlay,
		tr("DLG_DEDUPE_METADATA_TEXT") % _pending_dedupe_match_count,
		"warning",
		"",
		tr("BTN_OK"),
	):
		_on_dedupe_metadata_confirmed()
	else:
		_on_dedupe_metadata_canceled()


func _on_dedupe_metadata_confirmed() -> void:
	var root := _pending_dedupe_user_root
	_pending_dedupe_user_root = ""
	_pending_dedupe_match_count = 0
	if root != "" and SongLibrary and SongLibrary.has_method("apply_dedupe_for_user_root"):
		SongLibrary.apply_dedupe_for_user_root(root)


func _on_dedupe_metadata_canceled() -> void:
	_pending_dedupe_user_root = ""
	_pending_dedupe_match_count = 0
