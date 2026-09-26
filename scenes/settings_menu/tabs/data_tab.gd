# scenes/settings_menu/tabs/data_tab.gd
extends Control

signal settings_changed

var song_metadata_manager = SongLibrary
const _ProgressBackup = preload("res://logic/platform/progress_backup_service.gd")
const _Overlay = preload("res://logic/ui/app_overlay_helpers.gd")
const _HtmlExport = preload("res://scenes/profile/share/profile_share_html_export.gd")
const _ReplayUi = preload("res://logic/domain/replay/replay_ui.gd")

const _CV := "ScrollWrap/CenterWrap/ContentVBox"
const _BACKUP := "%s/BackupPanel/BackupPanelMargin/BackupRows" % _CV
const _TOOLS := "%s/ToolsPanel/ToolsPanelMargin/ToolsRows" % _CV

@onready var backup_header: Label = get_node("%s/BackupHeader" % _BACKUP)
@onready var backup_hint_label: Label = get_node("%s/BackupHintLabel" % _BACKUP)
@onready var export_progress_button: Button = get_node("%s/BackupButtonsHBox/ExportProgressButton" % _BACKUP)
@onready var import_progress_button: Button = get_node("%s/BackupButtonsHBox/ImportProgressButton" % _BACKUP)
@onready var recap_header: Label = %RecapHeader
@onready var recap_hint: Label = %RecapHint
@onready var recap_status_label: Label = %RecapStatusLabel
@onready var recap_check_button: Button = %RecapCheckButton
@onready var recap_install_button: Button = %RecapInstallButton
@onready var folders_header: Label = %FoldersHeader
@onready var folders_hint: Label = %FoldersHint
@onready var open_data_folder_button: Button = %OpenDataFolderButton
@onready var replay_folder_header: Label = %ReplayFolderHeader
@onready var replay_folder_hint: Label = %ReplayFolderHint
@onready var replay_folder_line_edit: LineEdit = %ReplayFolderLineEdit
@onready var choose_replay_folder_button: Button = %ChooseReplayFolderButton
@onready var open_replay_folder_button: Button = %OpenReplayFolderButton
@onready var replay_auto_save_checkbox: CheckBox = %ReplayAutoSaveCheckbox
@onready var replay_folder_dialog: FileDialog = %ReplayFolderDialog
@onready var tools_header: Label = get_node("%s/ToolsHeader" % _TOOLS)
@onready var tools_hint: Label = get_node("%s/ToolsHint" % _TOOLS)
@onready var reset_bpm_batch_button: Button = get_node("%s/BpmButtonRow/ResetBPMBatchButton" % _TOOLS)
@onready var export_progress_dialog: FileDialog = $ExportProgressDialog
@onready var import_progress_dialog: FileDialog = $ImportProgressDialog
@onready var _notice_overlay: AppNoticeOverlay = %NoticeOverlay
@onready var _confirm_overlay: AppConfirmOverlay = %ConfirmOverlay

var _pending_import_zip_path: String = ""
var _recap_busy := false
var _loading_overlay: LoadingOverlay


func setup_ui_and_manager(_screen = null, metadata_mgr = null, _achievement_manager = null) -> void:
	if metadata_mgr:
		song_metadata_manager = metadata_mgr


func _ready() -> void:
	add_to_group("locale_refresh")
	_setup_native_file_dialogs()
	_apply_initial_replay_settings()
	call_deferred("apply_locale")


func on_settings_page_shown() -> void:
	# Probe Python/Playwright off the freeze path — show status first, then async check.
	_refresh_recap_status_async(false)


func _refresh_recap_status_async(force_reprobe: bool = false) -> void:
	if recap_status_label == null:
		return
	if force_reprobe:
		_HtmlExport.invalidate_availability()
	if _HtmlExport.has_cached_availability():
		_paint_recap_status(_HtmlExport.is_available())
		return
	recap_status_label.text = tr("SETTINGS_RECAP_EXPORT_STATUS_CHECKING")
	if recap_install_button:
		recap_install_button.disabled = true
	if recap_check_button:
		recap_check_button.disabled = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var ok: bool = await _HtmlExport.probe_availability_async()
	if recap_check_button:
		recap_check_button.disabled = _recap_busy
	_paint_recap_status(ok)


func _refresh_recap_status(force_reprobe: bool = true) -> void:
	# Sync path (Install / Check button) — prefer async when uncached.
	if force_reprobe or not _HtmlExport.has_cached_availability():
		await _refresh_recap_status_async(force_reprobe)
		return
	_paint_recap_status(_HtmlExport.is_available())


func _setup_native_file_dialogs() -> void:
	for dlg in [export_progress_dialog, import_progress_dialog, replay_folder_dialog]:
		if dlg == null:
			continue
		dlg.use_native_dialog = true
		dlg.access = FileDialog.ACCESS_FILESYSTEM
		dlg.unresizable = true
	if replay_folder_dialog:
		replay_folder_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR


func apply_locale() -> void:
	if backup_header:
		backup_header.text = tr("MISC_PROGRESS_BACKUP_HEADER")
	if backup_hint_label:
		backup_hint_label.text = tr("MISC_PROGRESS_BACKUP_HINT")
	if folders_header:
		folders_header.text = tr("SETTINGS_FOLDERS_SECTION")
	if folders_hint:
		folders_hint.text = tr("SETTINGS_FOLDERS_SECTION_HINT")
	if open_data_folder_button:
		open_data_folder_button.text = tr("SETTINGS_OPEN_DATA_FOLDER")
	if replay_folder_header:
		replay_folder_header.text = tr("SETTINGS_REPLAY_FOLDER_HEADER")
	if replay_folder_hint:
		replay_folder_hint.text = tr("SETTINGS_REPLAY_FOLDER_HINT")
	var replay_folder_label: Label = get_node_or_null(
		"ScrollWrap/CenterWrap/ContentVBox/FoldersPanel/FoldersPanelMargin/FoldersRows/ReplayFolderHBox/ReplayFolderLabel"
	)
	if replay_folder_label:
		replay_folder_label.text = tr("SETTINGS_REPLAY_FOLDER_LABEL")
	if choose_replay_folder_button:
		choose_replay_folder_button.text = tr("MISC_CHOOSE_FOLDER")
	if open_replay_folder_button:
		open_replay_folder_button.text = tr("LIBRARY_OPEN_FOLDER")
	if replay_auto_save_checkbox:
		replay_auto_save_checkbox.text = tr("SETTINGS_REPLAY_AUTO_SAVE")
	if tools_header:
		tools_header.text = tr("SETTINGS_CACHE_SECTION")
	if tools_hint:
		tools_hint.text = tr("SETTINGS_CACHE_SECTION_HINT")
	if export_progress_button:
		export_progress_button.text = tr("MISC_EXPORT_PROGRESS")
	if import_progress_button:
		import_progress_button.text = tr("MISC_IMPORT_PROGRESS")
	if recap_header:
		recap_header.text = tr("SETTINGS_RECAP_EXPORT_HEADER")
	if recap_hint:
		recap_hint.text = tr("SETTINGS_RECAP_EXPORT_HINT")
	if recap_check_button:
		recap_check_button.text = tr("SETTINGS_RECAP_EXPORT_CHECK")
	if recap_install_button:
		recap_install_button.text = tr("SETTINGS_RECAP_EXPORT_INSTALL")
	if reset_bpm_batch_button:
		reset_bpm_batch_button.text = tr("MISC_RESET_BPM_CACHE")
	if export_progress_dialog:
		export_progress_dialog.title = tr("MISC_EXPORT_PROGRESS")
	if import_progress_dialog:
		import_progress_dialog.title = tr("MISC_IMPORT_PROGRESS")
	_apply_tooltips()
	_apply_recap_status_labels_only()


func _apply_tooltips() -> void:
	if reset_bpm_batch_button:
		reset_bpm_batch_button.tooltip_text = tr("MISC_RESET_BPM_CACHE_TOOLTIP")
	if export_progress_button:
		export_progress_button.tooltip_text = tr("MISC_EXPORT_PROGRESS_TOOLTIP")
	if import_progress_button:
		import_progress_button.tooltip_text = tr("MISC_IMPORT_PROGRESS_TOOLTIP")
	if recap_check_button:
		recap_check_button.tooltip_text = tr("SETTINGS_RECAP_EXPORT_CHECK_TOOLTIP")
	if recap_install_button:
		recap_install_button.tooltip_text = tr("SETTINGS_RECAP_EXPORT_INSTALL_TOOLTIP")
	if open_data_folder_button:
		open_data_folder_button.tooltip_text = tr("SETTINGS_OPEN_DATA_FOLDER_TOOLTIP")
	if choose_replay_folder_button:
		choose_replay_folder_button.tooltip_text = tr("MISC_CHOOSE_FOLDER_TOOLTIP")
	if open_replay_folder_button:
		open_replay_folder_button.tooltip_text = tr("SETTINGS_REPLAY_OPEN_FOLDER_TOOLTIP")
	if replay_auto_save_checkbox:
		replay_auto_save_checkbox.tooltip_text = tr("SETTINGS_REPLAY_AUTO_SAVE_TOOLTIP")
	if replay_folder_line_edit:
		replay_folder_line_edit.tooltip_text = tr("SETTINGS_REPLAY_FOLDER_HINT")


func _apply_initial_replay_settings() -> void:
	if replay_folder_line_edit:
		replay_folder_line_edit.text = SettingsManager.get_replay_save_folder()
	if replay_auto_save_checkbox:
		replay_auto_save_checkbox.set_pressed_no_signal(SettingsManager.get_replay_auto_save())


func _replay_folder_dialog_start_dir() -> String:
	var path := SettingsManager.get_replay_save_folder()
	if path.begins_with("user://") or path.begins_with("res://"):
		return ProjectSettings.globalize_path(path).replace("\\", "/")
	return path.replace("\\", "/")


func _on_choose_replay_folder_pressed() -> void:
	if replay_folder_dialog:
		replay_folder_dialog.current_dir = _replay_folder_dialog_start_dir()
		replay_folder_dialog.popup_centered()


func _on_replay_folder_dir_selected(path: String) -> void:
	if replay_folder_dialog:
		replay_folder_dialog.hide()
	var normalized := String(path).strip_edges().replace("\\", "/")
	if normalized == "":
		return
	if not normalized.ends_with("/"):
		normalized += "/"
	SettingsManager.set_replay_save_folder(normalized)
	if replay_folder_line_edit:
		replay_folder_line_edit.text = SettingsManager.get_replay_save_folder()
	SettingsManager.save_settings()
	emit_signal("settings_changed")


func _on_open_replay_folder_pressed() -> void:
	_ReplayUi.open_replays_folder()


func _on_replay_auto_save_toggled(enabled: bool) -> void:
	SettingsManager.set_replay_auto_save(enabled)
	SettingsManager.save_settings()
	emit_signal("settings_changed")


func _on_open_data_folder_pressed() -> void:
	var abs_path := ProjectSettings.globalize_path("user://").replace("\\", "/")
	DirAccess.make_dir_recursive_absolute(abs_path)
	OS.shell_open(abs_path)


func _apply_recap_status_labels_only() -> void:
	## Locale/UI text without spawning Python (Settings open must stay snappy).
	if recap_status_label == null:
		return
	if _HtmlExport.has_cached_availability():
		_paint_recap_status(_HtmlExport.is_available())
	elif recap_install_button:
		recap_install_button.disabled = _recap_busy


func _paint_recap_status(ok: bool) -> void:
	if recap_status_label == null:
		return
	if ok:
		recap_status_label.text = tr("SETTINGS_RECAP_EXPORT_STATUS_OK")
		if recap_install_button:
			recap_install_button.text = tr("SETTINGS_RECAP_EXPORT_REPAIR")
	else:
		var code := _HtmlExport.get_last_error_code()
		if code == "":
			code = "—"
		recap_status_label.text = tr("SETTINGS_RECAP_EXPORT_STATUS_BAD") % code
		if recap_install_button:
			recap_install_button.text = tr("SETTINGS_RECAP_EXPORT_INSTALL")
	if recap_install_button:
		recap_install_button.disabled = _recap_busy or not _HtmlExport.can_install_export_toolchain()


func _on_recap_check_pressed() -> void:
	if _recap_busy:
		return
	await _refresh_recap_status_async(true)
	if _HtmlExport.is_available():
		_Overlay.notify(_notice_overlay, tr("SETTINGS_RECAP_EXPORT_STATUS_OK"))
	else:
		var code := _HtmlExport.get_last_error_code()
		if code == "":
			code = "E005"
		_Overlay.notify(_notice_overlay, tr("SETTINGS_RECAP_EXPORT_STATUS_BAD") % code)


func _on_recap_install_pressed() -> void:
	if _recap_busy:
		return
	if not _HtmlExport.can_install_export_toolchain() and not _HtmlExport.is_available():
		await _refresh_recap_status_async(false)
		_Overlay.notify(_notice_overlay, tr("SETTINGS_RECAP_EXPORT_NO_PYTHON"))
		return
	_recap_busy = true
	if recap_check_button:
		recap_check_button.disabled = true
	if recap_install_button:
		recap_install_button.disabled = true
	_push_loading(tr("PROFILE_SHARE_INSTALL_EXPORT_BUSY"))
	var result: Dictionary = await _HtmlExport.install_export_toolchain_async()
	_pop_loading()
	_recap_busy = false
	if recap_check_button:
		recap_check_button.disabled = false
	await _refresh_recap_status_async(true)
	if bool(result.get("ok", false)):
		_Overlay.notify(_notice_overlay, tr("PROFILE_SHARE_INSTALL_EXPORT_OK"))
	else:
		var code := str(result.get("error_code", _HtmlExport.get_last_error_code()))
		if code == "":
			code = "E002"
		_Overlay.notify(_notice_overlay, tr("SETTINGS_RECAP_EXPORT_STATUS_BAD") % code)


func _get_loading_overlay() -> LoadingOverlay:
	if _loading_overlay and is_instance_valid(_loading_overlay):
		return _loading_overlay
	var ge := get_tree().root.get_node_or_null("GameEngine")
	if ge and ge.has_method("get_loading_overlay"):
		_loading_overlay = ge.get_loading_overlay()
	return _loading_overlay


func _push_loading(message: String) -> void:
	var overlay := _get_loading_overlay()
	if overlay:
		overlay.show_loading(message, true)


func _pop_loading() -> void:
	var overlay := _get_loading_overlay()
	if overlay:
		overlay.hide_loading()


func _on_reset_bpm_batch_pressed() -> void:
	if await _Overlay.ask(_confirm_overlay, tr("DLG_RESET_BPM_TEXT"), "danger"):
		_confirm_reset_bpm_batch()


func _confirm_reset_bpm_batch() -> void:
	var current_cache = song_metadata_manager._metadata_cache
	var modified = false
	for song_path in current_cache:
		if current_cache[song_path].has("bpm"):
			current_cache[song_path]["bpm"] = tr("VALUE_NA")
			modified = true
	if modified:
		song_metadata_manager._save_metadata()


func _on_export_progress_pressed() -> void:
	if export_progress_dialog:
		export_progress_dialog.current_file = _ProgressBackup.default_export_filename()
		export_progress_dialog.popup_centered()
	else:
		_run_export_progress("")


func _on_export_progress_file_selected(path: String) -> void:
	_run_export_progress(path)


func _run_export_progress(path: String) -> void:
	var result := _ProgressBackup.export_to_zip(path)
	if result.get("ok", false):
		var saved := str(result.get("path", path))
		_show_progress_backup_result(tr("DLG_EXPORT_PROGRESS_SUCCESS") % saved)
	else:
		var key := str(result.get("error_key", "PROGRESS_EXPORT_ERR_WRITE"))
		var detail := str(result.get("detail", ""))
		var msg := tr(key)
		if detail != "":
			msg = "%s (%s)" % [msg, detail]
		_show_progress_backup_result(msg)


func _on_import_progress_pressed() -> void:
	if import_progress_dialog:
		import_progress_dialog.popup_centered()


func _on_import_progress_file_selected(path: String) -> void:
	_pending_import_zip_path = String(path).strip_edges()
	if _pending_import_zip_path == "":
		return
	if await _Overlay.ask(
		_confirm_overlay,
		tr("DLG_IMPORT_PROGRESS_TEXT"),
		"warning",
		"",
		tr("MISC_IMPORT_PROGRESS"),
	):
		_confirm_import_progress()


func _confirm_import_progress() -> void:
	if _pending_import_zip_path == "":
		return
	var result := _ProgressBackup.import_from_zip(_pending_import_zip_path)
	_pending_import_zip_path = ""
	if result.get("ok", false):
		_refresh_dependent_ui()
		emit_signal("settings_changed")
		_show_progress_backup_result(tr("DLG_IMPORT_PROGRESS_SUCCESS"))
	else:
		var key := str(result.get("error_key", "PROGRESS_IMPORT_ERR_WRITE"))
		var detail := str(result.get("detail", ""))
		var msg := tr(key)
		if detail != "":
			msg = "%s (%s)" % [msg, detail]
		_show_progress_backup_result(msg)


func _refresh_dependent_ui() -> void:
	var root = get_tree().root
	_call_refresh_recursive(root, "refresh_ui")
	_call_refresh_recursive(root, "refresh_stats")
	_call_refresh_recursive(root, "refresh_generation_notes_highlights")


func _call_refresh_recursive(node: Node, method: String) -> void:
	if node == null:
		return
	if node.has_method(method):
		node.call(method)
	for child in node.get_children():
		_call_refresh_recursive(child, method)


func _show_progress_backup_result(text: String, _is_error: bool = false) -> void:
	_Overlay.notify(_notice_overlay, text)
