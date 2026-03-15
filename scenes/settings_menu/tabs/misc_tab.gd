# scenes/settings_menu/tabs/misc_tab.gd
extends Control

signal settings_changed

var song_metadata_manager = SongLibrary 
const FILES_TO_CLEAR := ["session_history.json"]

@onready var reset_confirm_dialog: ConfirmationDialog = $"ResetProfileStatsConfirmDialog"
@onready var reset_bpm_batch_button: Button = $ContentVBox/ResetBPMBatchButton
@onready var reset_all_settings_button: Button = $ContentVBox/ResetAllSettingsButton
@onready var reset_profile_stats_button: Button = $ContentVBox/ResetProfileStatsButton
@onready var debug_menu_checkbox: CheckBox = $ContentVBox/DebugMenuCheckBox
@onready var enable_genre_detection_checkbox: CheckBox = $ContentVBox/EnableGenreDetectionCheckBox 
@onready var show_gen_notifs_checkbox: CheckBox = $ContentVBox/ShowGenNotifsCheckBox
@onready var enable_stems_checkbox: CheckBox = $ContentVBox/EnableStemsCheckBox
@onready var songs_folder_line_edit: LineEdit = $ContentVBox/SongsFolderHBox/SongsFolderLineEdit
@onready var songs_folder_dialog: FileDialog = $SongsFolderDialog
@onready var migrate_paths_dialog: ConfirmationDialog = $MigratePathsDialog
@onready var clear_user_paths_button: Button = $ContentVBox/ClearUserPathsButton
@onready var reset_all_settings_confirm_dialog: ConfirmationDialog = $"ResetAllSettingsConfirmDialog"
@onready var clear_notes_confirm_dialog: ConfirmationDialog = $"ClearNotesConfirmDialog"
@onready var reset_bpm_batch_confirm_dialog: ConfirmationDialog = $"ResetBPMBatchConfirmDialog"
@onready var clear_user_paths_confirm_dialog: ConfirmationDialog = $"ClearUserPathsConfirmDialog"


func _ready():
	call_deferred("_apply_initial_settings")

func _apply_initial_settings():
	debug_menu_checkbox.set_pressed_no_signal(SettingsManager.get_enable_debug_menu())
	
	var enable_genre = SettingsManager.get_setting("enable_genre_detection", true)
	enable_genre_detection_checkbox.set_pressed_no_signal(enable_genre)  
	
	var show_notifs = SettingsManager.get_setting("show_generation_notifications", true)
	show_gen_notifs_checkbox.set_pressed_no_signal(show_notifs)
	
	var use_stems = SettingsManager.get_setting("use_stems_in_generation", true)
	enable_stems_checkbox.set_pressed_no_signal(use_stems)
	
	var p = String(SettingsManager.get_setting("user_songs_path", ""))
	if p == "":
		p = "user://Songs"
	songs_folder_line_edit.text = p
	_apply_console_state_from_settings()


func _on_debug_menu_toggled(enabled: bool):
	SettingsManager.set_enable_debug_menu(enabled)
	_apply_console_state_from_settings()
	emit_signal("settings_changed")


func _on_reset_bpm_batch_pressed():
	if reset_bpm_batch_confirm_dialog:
		reset_bpm_batch_confirm_dialog.popup_centered()
	else:
		_confirm_reset_bpm_batch()

func _on_clear_notes_pressed():
	if clear_notes_confirm_dialog:
		clear_notes_confirm_dialog.popup_centered()
	else:
		_confirm_clear_notes()


func _on_reset_profile_stats_pressed():
	if reset_confirm_dialog:
		reset_confirm_dialog.popup_centered()
	else:
		_confirm_reset_profile_stats()

func _on_reset_all_settings_pressed():
	if reset_all_settings_confirm_dialog:
		reset_all_settings_confirm_dialog.popup_centered()
	else:
		_confirm_reset_all_settings()


func _clear_all_results_internal():
	DirectoryUtils.delete_dir_recursive("user://results")
	JsonUtils.write_json("user://session_history.json", [], true, true)
 
	
func _confirm_reset_profile_stats():
	PlayerDataManager.reset_profile_statistics() 
	PlayerDataManager.reset_login_streak()
	TrackStatsManager.reset_stats()
	_clear_all_results_internal()
	_refresh_profile_ui_if_visible()
	emit_signal("settings_changed")

func _confirm_reset_all_settings():
	SettingsManager.reset_all_settings()
	if MusicManager and MusicManager.has_method("update_volumes_from_settings"):
		MusicManager.update_volumes_from_settings()
	_apply_initial_settings()
	_refresh_sound_tab_ui_if_present()
	emit_signal("settings_changed")

func _confirm_clear_notes():
	DirectoryUtils.delete_dir_recursive("user://notes")
	emit_signal("settings_changed")

func _confirm_reset_bpm_batch():
	var current_cache = song_metadata_manager._metadata_cache
	var modified = false
	for song_path in current_cache:
		if current_cache[song_path].has("bpm"):
			current_cache[song_path]["bpm"] = "Н/Д"
			modified = true
	if modified:
		song_metadata_manager._save_metadata()
		emit_signal("settings_changed")
	
func _apply_console_state_from_settings():
	var console_node = get_tree().root.get_node_or_null("Console")
	if console_node:
		if SettingsManager.get_enable_debug_menu():
			if console_node.has_method("enable"):
				console_node.enable()
		else:
			if console_node.has_method("disable"):
				console_node.disable()
				
func _refresh_profile_ui_if_visible():
	var root = get_tree().root
	_call_refresh_stats_recursive(root)
	
func _call_refresh_stats_recursive(node):
	if not node:
		return false
	var called = false
	if node.has_method("refresh_stats"):
		node.refresh_stats()
		called = true
	for child in node.get_children():
		called = _call_refresh_stats_recursive(child) or called
	return called
func _refresh_sound_tab_ui_if_present():
	var tabs = get_parent()
	if tabs:
		var sound_tab = tabs.get_node_or_null("SoundTab")
		if sound_tab and sound_tab.has_method("refresh_ui"):
			sound_tab.refresh_ui()
func _on_enable_genre_detection_toggled(enabled: bool):
	SettingsManager.set_setting("enable_genre_detection", enabled)
	SettingsManager.save_settings()

func _on_show_gen_notifs_toggled(enabled: bool):
	SettingsManager.set_setting("show_generation_notifications", enabled)
	SettingsManager.save_settings()
	emit_signal("settings_changed")

func _on_enable_stems_toggled(enabled: bool):
	SettingsManager.set_setting("use_stems_in_generation", enabled)
	SettingsManager.save_settings()
	emit_signal("settings_changed")

func _on_choose_songs_folder_pressed():
	if songs_folder_dialog:
		songs_folder_dialog.current_dir = "user://"
		songs_folder_dialog.popup_centered()

func _on_songs_folder_dir_selected(path: String):
	var old_path = String(SettingsManager.get_setting("user_songs_path", ""))
	if old_path == "":
		old_path = "user://Songs/"
	if not old_path.ends_with("/"):
		old_path += "/"
	var new_path = String(path)
	if not new_path.ends_with("/"):
		new_path += "/"
	SettingsManager.set_setting("user_songs_path", new_path)
	SettingsManager.save_settings()
	if songs_folder_line_edit:
		songs_folder_line_edit.text = new_path
	emit_signal("settings_changed")

var _pending_migration_map: Dictionary = {}
var _pending_old_user_path: String = ""
var _pending_new_user_path: String = ""

func _on_migrate_paths_confirmed():
	if SongLibrary and SongLibrary.has_method("apply_user_path_migration"):
		SongLibrary.apply_user_path_migration(_pending_migration_map, false, _pending_old_user_path)
	SettingsManager.set_setting("user_songs_path", _pending_new_user_path)
	SettingsManager.save_settings()
	if songs_folder_line_edit:
		songs_folder_line_edit.text = _pending_new_user_path
	_pending_migration_map.clear()
	_pending_old_user_path = ""
	_pending_new_user_path = ""
	emit_signal("settings_changed")

func _confirm_clear_user_paths():
	if not song_metadata_manager:
		return
	var built_in_root = String(song_metadata_manager.BUILT_IN_FOLDER_PATH)
	var exe_dir = OS.get_executable_path().get_base_dir()
	var external_bundled_root = exe_dir.path_join("bundled_songs").replace("\\", "/") + "/"
	var snapshot: Array = song_metadata_manager._metadata_cache.keys()
	var changed := false
	for k in snapshot:
		var p := String(k)
		if not p.begins_with(built_in_root) and not p.begins_with(external_bundled_root):
			if song_metadata_manager._metadata_cache.erase(k):
				changed = true
	if changed:
		song_metadata_manager._save_metadata()
		song_metadata_manager.emit_signal("songs_list_changed")
	emit_signal("settings_changed")

func _on_scan_songs_pressed():
	if SongLibrary and SongLibrary.has_method("scan_user_songs"):
		SongLibrary.scan_user_songs()
		var current_root = String(SettingsManager.get_setting("user_songs_path", ""))
		if current_root == "":
			current_root = "user://Songs/"
		if not current_root.ends_with("/"):
			current_root += "/"
		if SongLibrary.has_method("prepare_dedupe_for_user_root"):
			var prep = SongLibrary.prepare_dedupe_for_user_root(current_root)
			var matches: Dictionary = prep.get("matches", {})
			if matches.size() > 0:
				var dlg = ConfirmationDialog.new()
				dlg.title = "Объединение метаданных"
				dlg.dialog_text = "Найдено %d совпадений по именам файлов.\nОбъединить метаданные со старых путей в новую папку?" % matches.size()
				dlg.confirmed.connect(func():
					if SongLibrary and SongLibrary.has_method("apply_dedupe_for_user_root"):
						SongLibrary.apply_dedupe_for_user_root(current_root)
					if is_instance_valid(dlg):
						dlg.queue_free()
				)
				dlg.canceled.connect(func():
					if is_instance_valid(dlg):
						dlg.queue_free()
				)
				add_child(dlg)
				dlg.popup_centered()

func _on_clear_user_paths_pressed():
	if clear_user_paths_confirm_dialog:
		clear_user_paths_confirm_dialog.popup_centered()
	else:
		_confirm_clear_user_paths()
