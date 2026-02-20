# scenes/settings_menu/tabs/misc_tab.gd
extends Control

signal settings_changed

var song_metadata_manager = SongMetadataManager 

@onready var clear_achievements_button: Button = $ContentVBox/ClearAchievementsButton
@onready var reset_bpm_batch_button: Button = $ContentVBox/ResetBPMBatchButton
@onready var clear_all_cache_button: Button = $ContentVBox/ClearAllCacheButton
@onready var reset_all_settings_button: Button = $ContentVBox/ResetAllSettingsButton
@onready var reset_profile_stats_button: Button = $ContentVBox/ResetProfileStatsButton
@onready var clear_all_results_button: Button = $ContentVBox/ClearAllResultsButton
@onready var debug_menu_checkbox: CheckBox = $ContentVBox/DebugMenuCheckBox
@onready var enable_genre_detection_checkbox: CheckBox = $ContentVBox/EnableGenreDetectionCheckBox 
@onready var show_gen_notifs_checkbox: CheckBox = $ContentVBox/ShowGenNotifsCheckBox


func _ready():
	_connect_signals()

func setup_ui_and_manager(music, screen = null, song_metadata_mgr = null, achievement_mgr = null):
	song_metadata_manager = song_metadata_mgr if song_metadata_mgr else SongMetadataManager
	_apply_initial_settings()

func _connect_signals():
	if clear_achievements_button:
		clear_achievements_button.pressed.connect(_on_clear_achievements_pressed)
	if reset_bpm_batch_button:
		reset_bpm_batch_button.pressed.connect(_on_reset_bpm_batch_pressed)
	if clear_all_cache_button:
		clear_all_cache_button.pressed.connect(_on_clear_all_cache_pressed)
	if reset_all_settings_button:
		reset_all_settings_button.pressed.connect(_on_reset_all_settings_pressed)
	if reset_profile_stats_button: 
		reset_profile_stats_button.pressed.connect(_on_reset_profile_stats_pressed) 
	else:
		printerr("MiscTab.gd: ОШИБКА: reset_profile_stats_button НЕ найдена в _connect_signals!")
	if clear_all_results_button:
		clear_all_results_button.pressed.connect(_on_clear_all_results_pressed)
	else:
		printerr("MiscTab.gd: ОШИБКА: clear_all_results_button НЕ найдена в _connect_signals!")
	if debug_menu_checkbox:
		debug_menu_checkbox.toggled.connect(_on_debug_menu_toggled)
	if enable_genre_detection_checkbox:  
		enable_genre_detection_checkbox.toggled.connect(_on_enable_genre_detection_toggled) 
	if show_gen_notifs_checkbox:
		show_gen_notifs_checkbox.toggled.connect(_on_show_gen_notifs_toggled)


func _apply_initial_settings():
	debug_menu_checkbox.set_pressed_no_signal(SettingsManager.get_enable_debug_menu())
	
	var enable_genre = SettingsManager.get_setting("enable_genre_detection", true)
	enable_genre_detection_checkbox.set_pressed_no_signal(enable_genre)  
	
	var show_notifs = SettingsManager.get_setting("show_generation_notifications", true)
	show_gen_notifs_checkbox.set_pressed_no_signal(show_notifs)


func _on_debug_menu_toggled(enabled: bool):
	SettingsManager.set_enable_debug_menu(enabled)
	emit_signal("settings_changed")

func _on_clear_achievements_pressed():
	var game_engine = get_tree().root.get_node("GameEngine")
	if game_engine and game_engine.has_method("get_achievement_manager"):
		var achievement_manager = game_engine.get_achievement_manager()
		achievement_manager.reset_all_achievements_and_player_data(PlayerDataManager)
	else:
		printerr("MiscTab.gd: achievement_manager не доступен!")

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
	else:
		pass

func _on_clear_all_cache_pressed():
	song_metadata_manager._metadata_cache = {}
	song_metadata_manager._save_metadata()
	emit_signal("settings_changed")

func _on_reset_profile_stats_pressed():
	PlayerDataManager.reset_profile_statistics() 
	TrackStatsManager.reset_stats()
	if get_parent() and get_parent().get_parent() and get_parent().get_parent().has_method("refresh_stats"):
		get_parent().get_parent().get_parent().refresh_stats() 

func _on_reset_all_settings_pressed():
	SettingsManager.reset_all_settings()
	_apply_initial_settings()
	emit_signal("settings_changed")

func _on_clear_all_results_pressed():
	var results_dir_path = "user://results"
	var dir_access = DirAccess.open(results_dir_path)

	var results_dir_exists = DirAccess.open("user://").dir_exists("results")

	var all_deleted_in_results = true

	if not dir_access:
		if not results_dir_exists:
			pass
		else:
			printerr("MiscTab.gd: _on_clear_all_results_pressed: Не удалось открыть директорию: ", results_dir_path)
	else:
		dir_access.list_dir_begin()
		var file_name = dir_access.get_next()

		while file_name != "":
			if file_name != "." and file_name != "..":
				if not dir_access.current_is_dir():
					var file_path = results_dir_path.path_join(file_name) 
					var err = dir_access.remove(file_name)
					if err != OK:
						printerr("MiscTab.gd: _on_clear_all_results_pressed: Ошибка удаления файла: ", file_path, ". Код ошибки: ", err)
						all_deleted_in_results = false
					else:
						pass
				else:
					pass
			file_name = dir_access.get_next()

		dir_access.list_dir_end()

		if all_deleted_in_results:
			pass
		else:
			printerr("MiscTab.gd: _on_clear_all_results_pressed: Не все файлы из папки ", results_dir_path, " были удалены.")

	var user_dir_access = DirAccess.open("user://")
	if not user_dir_access:
		printerr("MiscTab.gd: _on_clear_all_results_pressed: Не удалось открыть корневую директорию user://")
		return

	var files_to_clear = ["best_grades.json", "session_history.json"]

	for file_name in files_to_clear:
		var file_path = "user://".path_join(file_name)
		var file_access = FileAccess.open(file_path, FileAccess.WRITE)
		if file_access:
			file_access.store_string("{}")  
			file_access.close()
		else:
			printerr("MiscTab.gd: _on_clear_all_results_pressed: Не удалось открыть файл для записи: ", file_path)

	
	
func _on_enable_genre_detection_toggled(enabled: bool):
	SettingsManager.set_setting("enable_genre_detection", enabled)
	SettingsManager.save_settings()
	emit_signal("settings_changed")

func _on_show_gen_notifs_toggled(enabled: bool):
	SettingsManager.set_setting("show_generation_notifications", enabled)
	SettingsManager.save_settings()
	emit_signal("settings_changed")


func _on_btn_misc_pressed() -> void:
	pass # Replace with function body.
