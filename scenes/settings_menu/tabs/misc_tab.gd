# scenes/settings_menu/tabs/misc_tab.gd
extends Control

signal settings_changed

var song_metadata_manager = SongLibrary 
const FILES_TO_CLEAR := ["session_history.json"]
const _OptionButtonPopupUtils = preload("res://logic/utils/option_button_popup_utils.gd")
const _SpinBoxUtils = preload("res://logic/utils/spin_box_utils.gd")
const _StringCharUtils = preload("res://logic/utils/string_char_utils.gd")

@onready var reset_confirm_dialog: ConfirmationDialog = $"ResetProfileStatsConfirmDialog"
const _CONTENT := "ScrollWrap/CenterWrap/ContentVBox"
const _GENERATION := "%s/GenerationPanel/GenerationPanelMargin/GenerationRows" % _CONTENT
const _SONGS := "%s/SongsPanel/SongsPanelMargin/SongsRows" % _CONTENT
const _DATA := "%s/DataPanel/DataPanelMargin/DataRows" % _CONTENT

@onready var reset_bpm_batch_button: Button = get_node("%s/DataButtonsGrid/ResetBPMBatchButton" % _DATA)
@onready var reset_all_settings_button: Button = get_node("%s/DataButtonsGrid/ResetAllSettingsButton" % _DATA)
@onready var reset_profile_stats_button: Button = get_node("%s/DataButtonsGrid/ResetProfileStatsButton" % _DATA)
@onready var debug_menu_checkbox: CheckBox = get_node("%s/DebugMenuCheckBox" % _DATA)
@onready var show_gen_notifs_checkbox: CheckBox = get_node("%s/ShowGenNotifsCheckBox" % _GENERATION)
@onready var generation_notes_scope_option: OptionButton = get_node("%s/GenerationNotesScopeRow/GenerationNotesScopeOption" % _GENERATION)
@onready var generation_server_location_option: OptionButton = get_node("%s/GenerationServerLocation/GenerationServerLocationOption" % _GENERATION)
@onready var generation_server_lan_host_hbox: HBoxContainer = get_node("%s/GenerationServerLanHostHBox" % _GENERATION)
@onready var generation_server_lan_host_line_edit: LineEdit = get_node("%s/GenerationServerLanHostHBox/GenerationServerLanHostLineEdit" % _GENERATION)
@onready var generation_server_port_spin: SpinBox = get_node("%s/GenerationServerPortHBox/GenerationServerPortSpin" % _GENERATION)
@onready var songs_folder_line_edit: LineEdit = get_node("%s/SongsFolderHBox/SongsFolderLineEdit" % _SONGS)
@onready var songs_folder_dialog: FileDialog = $SongsFolderDialog
@onready var migrate_paths_dialog: ConfirmationDialog = $MigratePathsDialog
@onready var clear_user_paths_button: Button = get_node("%s/DataButtonsGrid/ClearUserPathsButton" % _DATA)
@onready var reset_all_settings_confirm_dialog: ConfirmationDialog = $"ResetAllSettingsConfirmDialog"
@onready var clear_notes_confirm_dialog: ConfirmationDialog = $"ClearNotesConfirmDialog"
@onready var reset_bpm_batch_confirm_dialog: ConfirmationDialog = $"ResetBPMBatchConfirmDialog"
@onready var clear_user_paths_confirm_dialog: ConfirmationDialog = $"ClearUserPathsConfirmDialog"
@onready var change_songs_folder_confirm_dialog: ConfirmationDialog = $"ChangeSongsFolderConfirmDialog"
@onready var change_songs_folder_delete_notes_checkbox: CheckBox = $"ChangeSongsFolderConfirmDialog/ChangeSongsFolderDeleteNotesCheckBox"
@onready var scan_songs_result_dialog: AcceptDialog = $"ScanSongsResultDialog"

var _pending_new_folder_path: String = ""
var _lan_host_ipv4_format_lock: bool = false


func _notification(what: int) -> void:
	if what != NOTIFICATION_VISIBILITY_CHANGED:
		return
	if not is_visible_in_tree():
		return
	call_deferred("_sync_generation_server_lan_row_visibility")


func _ready():
	if generation_server_lan_host_line_edit:
		generation_server_lan_host_line_edit.text_changed.connect(_on_generation_server_lan_host_text_changed)
	call_deferred("_apply_initial_settings")
	call_deferred("_setup_generation_notes_scope_popup_font")
	call_deferred("_setup_generation_server_location_popup_font")
	call_deferred("_setup_generation_server_port_spin_font")
	call_deferred("_setup_change_songs_folder_dialog")


func _setup_change_songs_folder_dialog() -> void:
	if change_songs_folder_confirm_dialog == null:
		return
	var prune_btn: Button = change_songs_folder_confirm_dialog.add_button("Удалить из метаданных", false, "")
	if prune_btn:
		prune_btn.pressed.connect(_on_change_songs_folder_prune_pressed)


func _setup_generation_notes_scope_popup_font() -> void:
	_OptionButtonPopupUtils.apply_popup_font_size(generation_notes_scope_option, 24)


func _setup_generation_server_location_popup_font() -> void:
	_OptionButtonPopupUtils.apply_popup_font_size(generation_server_location_option, 24)


func _setup_generation_server_port_spin_font() -> void:
	if generation_server_port_spin:
		_SpinBoxUtils.apply_value_font_size(generation_server_port_spin, 24)


func _apply_generation_server_lan_visibility(use_lan: bool) -> void:
	if generation_server_lan_host_hbox:
		generation_server_lan_host_hbox.visible = use_lan


func _sync_generation_server_lan_row_visibility() -> void:
	if generation_server_lan_host_hbox == null:
		return
	var use_lan := bool(SettingsManager.get_setting("generation_server_use_lan_host", false))
	generation_server_lan_host_hbox.visible = use_lan


func _apply_initial_settings():
	debug_menu_checkbox.set_pressed_no_signal(SettingsManager.get_enable_debug_menu())
	var show_notifs = SettingsManager.get_setting("show_generation_notifications", true)
	show_gen_notifs_checkbox.set_pressed_no_signal(show_notifs)
	if generation_notes_scope_option and generation_notes_scope_option.item_count > 0:
		var max_idx = generation_notes_scope_option.item_count - 1
		var scope = int(clamp(int(SettingsManager.get_setting("generation_notes_ready_scope", 0)), 0, max_idx))
		generation_notes_scope_option.set_block_signals(true)
		generation_notes_scope_option.select(scope)
		generation_notes_scope_option.set_block_signals(false)
	
	var p = String(SettingsManager.get_setting("user_songs_path", ""))
	if p == "":
		p = "user://Songs"
	songs_folder_line_edit.text = p

	if generation_server_location_option:
		var use_lan := bool(SettingsManager.get_setting("generation_server_use_lan_host", false))
		generation_server_location_option.set_block_signals(true)
		generation_server_location_option.select(1 if use_lan else 0)
		generation_server_location_option.set_block_signals(false)
		_apply_generation_server_lan_visibility(use_lan)
	if generation_server_lan_host_line_edit:
		_lan_host_ipv4_format_lock = true
		generation_server_lan_host_line_edit.text = String(SettingsManager.get_setting("generation_server_lan_host", ""))
		_lan_host_ipv4_format_lock = false
	if generation_server_port_spin:
		var pv := clampi(int(SettingsManager.get_setting("generation_server_port", 5000)), 1, 65535)
		generation_server_port_spin.set_block_signals(true)
		generation_server_port_spin.value = pv
		generation_server_port_spin.set_block_signals(false)

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
func _on_generation_notes_scope_selected(index: int):
	var max_idx = (generation_notes_scope_option.item_count - 1) if generation_notes_scope_option else 3
	SettingsManager.set_setting("generation_notes_ready_scope", int(clamp(index, 0, max_idx)))
	SettingsManager.save_settings()
	emit_signal("settings_changed")
	_refresh_song_select_notes_highlights()

func _refresh_song_select_notes_highlights():
	var root = get_tree().root
	_call_refresh_notes_highlights_recursive(root)

func _call_refresh_notes_highlights_recursive(node: Node):
	if node == null:
		return
	if node.has_method("refresh_generation_notes_highlights"):
		node.refresh_generation_notes_highlights()
	for child in node.get_children():
		_call_refresh_notes_highlights_recursive(child)

func _on_show_gen_notifs_toggled(enabled: bool):
	SettingsManager.set_setting("show_generation_notifications", enabled)
	SettingsManager.save_settings()
	emit_signal("settings_changed")


func _on_generation_server_location_selected(index: int) -> void:
	var use_lan := index == 1
	SettingsManager.set_setting("generation_server_use_lan_host", use_lan)
	SettingsManager.save_settings()
	_apply_generation_server_lan_visibility(use_lan)
	emit_signal("settings_changed")


func _generation_server_insert_ipv4_dots(text: String) -> String:
	var cur := text
	var guard := 0
	while guard < 16:
		guard += 1
		var parts := cur.split(".")
		if parts.is_empty():
			break
		var last: String = parts[parts.size() - 1]
		if last.length() < 4 or not last.is_valid_int():
			break
		var oct := last.substr(0, 3)
		var rest := last.substr(3)
		if not oct.is_valid_int() or int(oct) > 255:
			break
		var rebuilt: PackedStringArray = []
		for i in range(parts.size() - 1):
			rebuilt.append(parts[i])
		rebuilt.append(oct + "." + rest)
		cur = ".".join(rebuilt)
	return cur


func _generation_server_join_dot_segments(parts: Array) -> String:
	var r := ""
	for i in parts.size():
		if i > 0:
			r += "."
		r += str(parts[i])
	return r


func _generation_server_sanitize_digit_dot_ipv4(s: String) -> String:
	if s.is_empty():
		return s
	var parts: Array = Array(s.split("."))
	if parts.is_empty():
		return s
	if parts.size() > 4:
		var trailing_dot := String(parts[parts.size() - 1]) == ""
		if trailing_dot and parts.size() == 5:
			pass
		elif trailing_dot:
			var head: Array = parts.slice(0, 4)
			head.append("")
			parts = head
		else:
			parts = parts.slice(0, 4)
	for i in parts.size():
		var seg := String(parts[i])
		if seg.is_empty():
			continue
		if seg.is_valid_int():
			parts[i] = str(clampi(int(seg), 0, 255))
	return _generation_server_join_dot_segments(parts)


func _on_generation_server_lan_host_text_changed(new_text: String) -> void:
	if _lan_host_ipv4_format_lock or generation_server_lan_host_line_edit == null:
		return
	var result := new_text
	if _StringCharUtils.is_decimal_digit_dot_only(result):
		result = _generation_server_insert_ipv4_dots(result)
		result = _generation_server_sanitize_digit_dot_ipv4(result)
	if result == new_text:
		return
	var caret := generation_server_lan_host_line_edit.caret_column
	var delta := result.length() - new_text.length()
	_lan_host_ipv4_format_lock = true
	generation_server_lan_host_line_edit.text = result
	var new_caret := caret + delta
	if new_caret < 0:
		new_caret = 0
	generation_server_lan_host_line_edit.caret_column = mini(result.length(), new_caret)
	_lan_host_ipv4_format_lock = false


func _save_generation_server_lan_host() -> void:
	if generation_server_lan_host_line_edit == null:
		return
	var raw := generation_server_lan_host_line_edit.text
	var t := raw.strip_edges()
	if _StringCharUtils.is_decimal_digit_dot_only(t):
		t = _generation_server_sanitize_digit_dot_ipv4(_generation_server_insert_ipv4_dots(t))
	if t != raw:
		_lan_host_ipv4_format_lock = true
		generation_server_lan_host_line_edit.text = t
		_lan_host_ipv4_format_lock = false
	SettingsManager.set_setting("generation_server_lan_host", t)
	SettingsManager.save_settings()
	emit_signal("settings_changed")


func _on_generation_server_lan_host_submitted(_new_text: String) -> void:
	_save_generation_server_lan_host()


func _on_generation_server_lan_host_focus_exited() -> void:
	_save_generation_server_lan_host()


func _on_generation_server_port_changed(value: float) -> void:
	SettingsManager.set_setting("generation_server_port", clampi(int(value), 1, 65535))
	SettingsManager.save_settings()
	emit_signal("settings_changed")


func _on_choose_songs_folder_pressed():
	if songs_folder_dialog:
		songs_folder_dialog.current_dir = "user://"
		songs_folder_dialog.popup_centered()


func _normalize_songs_folder_path(p: String) -> String:
	var s := String(p)
	if s == "":
		s = "user://Songs/"
	if not s.ends_with("/"):
		s += "/"
	return s


func _on_songs_folder_dir_selected(path: String):
	var old_path := _normalize_songs_folder_path(String(SettingsManager.get_setting("user_songs_path", "")))
	var new_path := _normalize_songs_folder_path(String(path))
	if songs_folder_line_edit:
		songs_folder_line_edit.text = new_path
	if old_path == new_path:
		return
	_pending_new_folder_path = new_path
	if change_songs_folder_delete_notes_checkbox:
		change_songs_folder_delete_notes_checkbox.button_pressed = false
	if change_songs_folder_confirm_dialog:
		change_songs_folder_confirm_dialog.popup_centered()
	else:
		_apply_new_songs_folder_path(new_path, false, false)


func _apply_new_songs_folder_path(new_path: String, prune: bool, delete_notes: bool) -> void:
	SettingsManager.set_setting("user_songs_path", new_path)
	SettingsManager.save_settings()
	if songs_folder_line_edit:
		songs_folder_line_edit.text = new_path
	if prune and SongLibrary and SongLibrary.has_method("prune_user_metadata_not_under_root"):
		SongLibrary.prune_user_metadata_not_under_root(new_path, delete_notes)
	if SongLibrary:
		SongLibrary.load_songs()
	_pending_new_folder_path = ""
	emit_signal("settings_changed")


func _on_change_songs_folder_keep_confirmed() -> void:
	if _pending_new_folder_path == "":
		return
	_apply_new_songs_folder_path(_pending_new_folder_path, false, false)


func _on_change_songs_folder_canceled() -> void:
	_pending_new_folder_path = ""
	if songs_folder_line_edit:
		songs_folder_line_edit.text = _normalize_songs_folder_path(String(SettingsManager.get_setting("user_songs_path", "")))


func _on_change_songs_folder_prune_pressed() -> void:
	if _pending_new_folder_path == "":
		return
	var delete_notes := change_songs_folder_delete_notes_checkbox.button_pressed if change_songs_folder_delete_notes_checkbox else false
	_apply_new_songs_folder_path(_pending_new_folder_path, true, delete_notes)
	if change_songs_folder_confirm_dialog:
		change_songs_folder_confirm_dialog.hide()


func _russian_song_word_form(n: int) -> String:
	var n10 := n % 10
	var n100 := n % 100
	if n10 == 1 and n100 != 11:
		return "песня"
	if n10 >= 2 and n10 <= 4 and (n100 < 10 or n100 > 20):
		return "песни"
	return "песен"

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
	if not SongLibrary or not SongLibrary.has_method("scan_user_songs"):
		return
	var added: int = SongLibrary.scan_user_songs()
	if scan_songs_result_dialog:
		if added > 0:
			scan_songs_result_dialog.dialog_text = "Добавлено %d %s." % [added, _russian_song_word_form(added)]
		else:
			scan_songs_result_dialog.dialog_text = "Новых песен не найдено."
		scan_songs_result_dialog.popup_centered()
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
