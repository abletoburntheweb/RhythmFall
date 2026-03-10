# scenes/settings_menu/tabs/misc_tab.gd
extends Control

signal settings_changed

var song_metadata_manager = SongLibrary 
const FILES_TO_CLEAR := ["session_history.json"]

@onready var reset_confirm_dialog: ConfirmationDialog = $ResetConfirmDialog
@onready var reset_bpm_batch_button: Button = $ContentVBox/ResetBPMBatchButton
@onready var clear_all_cache_button: Button = $ContentVBox/ClearAllCacheButton
@onready var reset_all_settings_button: Button = $ContentVBox/ResetAllSettingsButton
@onready var reset_profile_stats_button: Button = $ContentVBox/ResetProfileStatsButton
@onready var debug_menu_checkbox: CheckBox = $ContentVBox/DebugMenuCheckBox
@onready var enable_genre_detection_checkbox: CheckBox = $ContentVBox/EnableGenreDetectionCheckBox 
@onready var show_gen_notifs_checkbox: CheckBox = $ContentVBox/ShowGenNotifsCheckBox
@onready var enable_stems_checkbox: CheckBox = $ContentVBox/EnableStemsCheckBox
@onready var songs_folder_line_edit: LineEdit = $ContentVBox/SongsFolderHBox/SongsFolderLineEdit
@onready var songs_folder_dialog: FileDialog = $SongsFolderDialog
@onready var migrate_paths_dialog: ConfirmationDialog = $MigratePathsDialog


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
	var current_cache = song_metadata_manager._metadata_cache
	var modified = false
	for song_path in current_cache:
		if current_cache[song_path].has("bpm"):
			current_cache[song_path]["bpm"] = "Н/Д"
			modified = true
	if modified:
		song_metadata_manager._save_metadata()
		emit_signal("settings_changed")

func _on_clear_all_cache_pressed():
	song_metadata_manager._metadata_cache = {}
	song_metadata_manager._save_metadata()
	emit_signal("settings_changed")

func _on_clear_notes_pressed():
	_delete_directory_recursive("user://notes")
	emit_signal("settings_changed")

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

func _on_reset_profile_stats_pressed():
	if reset_confirm_dialog:
		reset_confirm_dialog.popup_centered()
	else:
		_confirm_reset_profile_stats()

func _on_reset_all_settings_pressed():
	SettingsManager.reset_all_settings()
	_apply_initial_settings()
	emit_signal("settings_changed")


func _clear_all_results_internal():
	var results_dir_path = "user://results"
	var dir_access = DirAccess.open(results_dir_path)
	if dir_access:
		dir_access.list_dir_begin()
		var file_name = dir_access.get_next()
		while file_name != "":
			if file_name != "." and file_name != "..":
				if not dir_access.current_is_dir():
					dir_access.remove(file_name)
			file_name = dir_access.get_next()
		dir_access.list_dir_end()

	for file_name in FILES_TO_CLEAR:
		var file_path = "user://".path_join(file_name)
		var file_access = FileAccess.open(file_path, FileAccess.WRITE)
		if file_access:
			file_access.store_string("{}")  
			file_access.close()
 
	
func _confirm_reset_profile_stats():
	PlayerDataManager.reset_profile_statistics() 
	PlayerDataManager.reset_login_streak()
	TrackStatsManager.reset_stats()
	_clear_all_results_internal()
	_refresh_profile_ui_if_visible()
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
