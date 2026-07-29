# scenes/settings_menu/tabs/danger_tab.gd
extends Control

signal settings_changed

const _Overlay = preload("res://logic/ui/app_overlay_helpers.gd")

const _CV := "ScrollWrap/CenterWrap/ContentVBox"
const _ACTIONS := "%s/ActionsPanel/ActionsPanelMargin/ActionsRows" % _CV

var song_metadata_manager = SongLibrary

@onready var warning_header: Label = get_node("%s/WarningPanel/WarningPanelMargin/WarningRows/WarningHeader" % _CV)
@onready var danger_warning_label: Label = get_node("%s/WarningPanel/WarningPanelMargin/WarningRows/DangerWarningLabel" % _CV)
@onready var actions_header: Label = get_node("%s/ActionsHeader" % _ACTIONS)
@onready var actions_hint: Label = get_node("%s/ActionsHint" % _ACTIONS)
@onready var actions_buttons_grid: GridContainer = get_node("%s/ActionsButtonsGrid" % _ACTIONS)
@onready var reset_all_settings_button: Button = get_node("%s/ActionsButtonsGrid/ResetAllSettingsButton" % _ACTIONS)
@onready var reset_profile_stats_button: Button = get_node("%s/ActionsButtonsGrid/ResetProfileStatsButton" % _ACTIONS)
@onready var _confirm_overlay: AppConfirmOverlay = %ConfirmOverlay

var _delete_user_charts_button: Button = null
var _delete_user_songs_button: Button = null

func _ensure_content_buttons() -> void:
	if actions_buttons_grid == null:
		return

	if _delete_user_charts_button == null:
		var b := Button.new()
		b.theme_type_variation = &"FlatExitButton"
		b.add_theme_font_size_override("font_size", 18)
		b.custom_minimum_size = Vector2(0, 50)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.text = "Удалить пользовательские чарты"
		b.pressed.connect(_on_delete_user_charts_pressed)
		actions_buttons_grid.add_child(b)
		_delete_user_charts_button = b

	if _delete_user_songs_button == null:
		var b2 := Button.new()
		b2.theme_type_variation = &"FlatExitButton"
		b2.add_theme_font_size_override("font_size", 18)
		b2.custom_minimum_size = Vector2(0, 50)
		b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b2.text = "Удалить пользовательские песни"
		b2.pressed.connect(_on_delete_user_songs_pressed)
		actions_buttons_grid.add_child(b2)
		_delete_user_songs_button = b2


func _ready() -> void:
	add_to_group("locale_refresh")
	_ensure_content_buttons()
	call_deferred("apply_locale")


func apply_locale() -> void:
	if warning_header:
		warning_header.text = tr("SETTINGS_NAV_DANGER")
	if danger_warning_label:
		danger_warning_label.text = tr("MISC_DANGER_WARNING")
	if actions_header:
		actions_header.text = tr("MISC_DANGER_ACTIONS_SECTION")
	if actions_hint:
		actions_hint.text = tr("SETTINGS_DANGER_ACTIONS_HINT")
	if reset_all_settings_button:
		reset_all_settings_button.text = tr("MISC_RESET_ALL_SETTINGS")
	if reset_profile_stats_button:
		reset_profile_stats_button.text = tr("MISC_RESET_PROFILE")
	if _delete_user_charts_button:
		_delete_user_charts_button.text = "Удалить пользовательские чарты"
	if _delete_user_songs_button:
		_delete_user_songs_button.text = "Удалить пользовательские песни"
	_apply_tooltips()


func _apply_tooltips() -> void:
	if reset_all_settings_button:
		reset_all_settings_button.tooltip_text = tr("MISC_RESET_ALL_SETTINGS_TOOLTIP")
	if reset_profile_stats_button:
		reset_profile_stats_button.tooltip_text = tr("MISC_RESET_PROFILE_TOOLTIP")
	if _delete_user_charts_button:
		_delete_user_charts_button.tooltip_text = tr("DLG_CLEAR_NOTES_TEXT")
	if _delete_user_songs_button:
		_delete_user_songs_button.tooltip_text = tr("DLG_CLEAR_PATHS_TEXT")


func request_reset_all_settings() -> void:
	_on_reset_all_settings_pressed()


func _on_reset_all_settings_pressed() -> void:
	if await _Overlay.ask(_confirm_overlay, tr("DLG_RESET_SETTINGS_TEXT"), "danger"):
		_confirm_reset_all_settings()


func _on_reset_profile_stats_pressed() -> void:
	if await _Overlay.ask(_confirm_overlay, tr("DLG_RESET_PROFILE_TEXT"), "danger"):
		_confirm_reset_profile_stats()


func _on_delete_user_charts_pressed() -> void:
	if await _Overlay.ask(_confirm_overlay, tr("DLG_CLEAR_NOTES_TEXT"), "danger"):
		_confirm_clear_notes()


func _on_delete_user_songs_pressed() -> void:
	if await _Overlay.ask(_confirm_overlay, tr("DLG_CLEAR_PATHS_TEXT"), "danger"):
		_confirm_clear_user_paths()


func _confirm_reset_profile_stats() -> void:
	PlayerDataManager.reset_profile_statistics()
	PlayerDataManager.reset_login_streak()
	TrackStatsManager.reset_stats()
	if ProfileMilestonesManager:
		ProfileMilestonesManager.reset_all()
	_clear_all_results_internal()
	if SettingsManager and SettingsManager.has_method("set_seen_server_setup_notice"):
		SettingsManager.set_seen_server_setup_notice(false)
	_refresh_profile_ui_if_visible()
	emit_signal("settings_changed")


func _confirm_reset_all_settings() -> void:
	SettingsManager.reset_all_settings()
	if MusicManager and MusicManager.has_method("update_volumes_from_settings"):
		MusicManager.update_volumes_from_settings()
	_refresh_all_settings_tabs()


func _clear_all_results_internal() -> void:
	DirectoryUtils.delete_dir_recursive("user://results")
	JsonUtils.write_json("user://session_history.json", [], true, true)


func _confirm_clear_notes() -> void:
	DirectoryUtils.delete_dir_recursive(NotesUtils.get_notes_root())
	if NotesUtils.get_notes_root() != NotesUtils.DEFAULT_NOTES_ROOT and DirectoryUtils.exists(NotesUtils.DEFAULT_NOTES_ROOT):
		DirectoryUtils.delete_dir_recursive(NotesUtils.DEFAULT_NOTES_ROOT)
	NotesUtils.invalidate_notes_cache()
	emit_signal("settings_changed")


func _confirm_clear_user_paths() -> void:
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


func _refresh_profile_ui_if_visible() -> void:
	_call_refresh_recursive(get_tree().root, "refresh_stats")


func _refresh_all_settings_tabs() -> void:
	var root = get_tree().root
	_call_refresh_recursive(root, "refresh_ui")
	_call_refresh_recursive(root, "apply_locale")


func _call_refresh_recursive(node: Node, method: String) -> void:
	if node == null:
		return
	if node.has_method(method):
		node.call(method)
	for child in node.get_children():
		_call_refresh_recursive(child, method)
