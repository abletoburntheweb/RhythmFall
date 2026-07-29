# scenes/settings_menu/tabs/data_tab.gd
extends Control

signal settings_changed

var song_metadata_manager = SongLibrary
const _ProgressBackup = preload("res://logic/platform/progress_backup_service.gd")
const _Overlay = preload("res://logic/ui/app_overlay_helpers.gd")

const _CV := "ScrollWrap/CenterWrap/ContentVBox"
const _BACKUP := "%s/BackupPanel/BackupPanelMargin/BackupRows" % _CV
const _TOOLS := "%s/ToolsPanel/ToolsPanelMargin/ToolsRows" % _CV

@onready var backup_header: Label = get_node("%s/BackupHeader" % _BACKUP)
@onready var backup_hint_label: Label = get_node("%s/BackupHintLabel" % _BACKUP)
@onready var export_progress_button: Button = get_node("%s/BackupButtonsHBox/ExportProgressButton" % _BACKUP)
@onready var import_progress_button: Button = get_node("%s/BackupButtonsHBox/ImportProgressButton" % _BACKUP)
@onready var tools_header: Label = get_node("%s/ToolsHeader" % _TOOLS)
@onready var tools_hint: Label = get_node("%s/ToolsHint" % _TOOLS)
@onready var reset_bpm_batch_button: Button = get_node("%s/BpmButtonRow/ResetBPMBatchButton" % _TOOLS)
@onready var export_progress_dialog: FileDialog = $ExportProgressDialog
@onready var import_progress_dialog: FileDialog = $ImportProgressDialog
@onready var _notice_overlay: AppNoticeOverlay = %NoticeOverlay
@onready var _confirm_overlay: AppConfirmOverlay = %ConfirmOverlay

var _pending_import_zip_path: String = ""


func setup_ui_and_manager(_screen = null, metadata_mgr = null, _achievement_manager = null) -> void:
	if metadata_mgr:
		song_metadata_manager = metadata_mgr


func _ready() -> void:
	add_to_group("locale_refresh")
	_setup_native_file_dialogs()
	call_deferred("apply_locale")


func _setup_native_file_dialogs() -> void:
	for dlg in [export_progress_dialog, import_progress_dialog]:
		if dlg == null:
			continue
		dlg.use_native_dialog = true
		dlg.access = FileDialog.ACCESS_FILESYSTEM
		dlg.unresizable = true


func apply_locale() -> void:
	if backup_header:
		backup_header.text = tr("MISC_PROGRESS_BACKUP_HEADER")
	if backup_hint_label:
		backup_hint_label.text = tr("MISC_PROGRESS_BACKUP_HINT")
	if tools_header:
		tools_header.text = "Кэш"
	if tools_hint:
		tools_hint.text = "Сброс локального кэша BPM. Чарты и прогресс не удаляются."
	if export_progress_button:
		export_progress_button.text = tr("MISC_EXPORT_PROGRESS")
	if import_progress_button:
		import_progress_button.text = tr("MISC_IMPORT_PROGRESS")
	if reset_bpm_batch_button:
		reset_bpm_batch_button.text = tr("MISC_RESET_BPM_CACHE")
	if export_progress_dialog:
		export_progress_dialog.title = tr("MISC_EXPORT_PROGRESS")
	if import_progress_dialog:
		import_progress_dialog.title = tr("MISC_IMPORT_PROGRESS")
	_apply_tooltips()


func _apply_tooltips() -> void:
	if reset_bpm_batch_button:
		reset_bpm_batch_button.tooltip_text = tr("MISC_RESET_BPM_CACHE_TOOLTIP")
	if export_progress_button:
		export_progress_button.tooltip_text = tr("MISC_EXPORT_PROGRESS_TOOLTIP")
	if import_progress_button:
		import_progress_button.tooltip_text = tr("MISC_IMPORT_PROGRESS_TOOLTIP")


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
