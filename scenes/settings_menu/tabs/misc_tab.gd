# scenes/settings_menu/tabs/misc_tab.gd
extends Control

signal settings_changed

var settings_manager: SettingsManager = null
var song_metadata_manager = null
var player_data_manager = null 

@onready var debug_menu_checkbox: CheckBox = $ContentVBox/DebugMenuCheckBox
@onready var clear_achievements_button: Button = $ContentVBox/ClearAchievementsButton
@onready var reset_bpm_batch_button: Button = $ContentVBox/ResetBPMBatchButton
@onready var clear_all_cache_button: Button = $ContentVBox/ClearAllCacheButton

func _ready():
	print("MiscTab.gd: _ready вызван.")
	_connect_signals()

func setup_ui_and_manager(manager: SettingsManager, music, screen = null, metadata_manager = null):
	settings_manager = manager
	song_metadata_manager = metadata_manager
	_apply_initial_settings()

func _connect_signals():
	if debug_menu_checkbox:
		debug_menu_checkbox.toggled.connect(_on_debug_menu_toggled)
	if clear_achievements_button:
		clear_achievements_button.pressed.connect(_on_clear_achievements_pressed)
	if reset_bpm_batch_button:
		reset_bpm_batch_button.pressed.connect(_on_reset_bpm_batch_pressed)
	if clear_all_cache_button:
		clear_all_cache_button.pressed.connect(_on_clear_all_cache_pressed)

func _apply_initial_settings():
	if settings_manager:
		debug_menu_checkbox.set_pressed_no_signal(settings_manager.get_enable_debug_menu())
	else:
		printerr("MiscTab.gd: settings_manager не установлен, невозможно применить начальные настройки.")

func _on_debug_menu_toggled(enabled: bool):
	if settings_manager:
		settings_manager.set_enable_debug_menu(enabled)
		emit_signal("settings_changed")
		print("MiscTab.gd: Дебаг меню %s." % ("включено" if enabled else "выключено"))
	else:
		printerr("MiscTab.gd: settings_manager не установлен, невозможно изменить настройку дебаг меню.")

func _on_clear_achievements_pressed():
	print("MiscTab.gd: Запрос на очистку прогресса ачивок.")

func _on_reset_bpm_batch_pressed():
	print("MiscTab.gd: Запрос на сброс кэша BPM.")
	if song_metadata_manager:
		var current_cache = song_metadata_manager._metadata_cache
		var modified = false
		for song_path in current_cache:
			if current_cache[song_path].has("bpm"):
				current_cache[song_path]["bpm"] = "Н/Д"
				modified = true
				print("MiscTab.gd: BPM сброшен для %s" % song_path.get_file())
		if modified:
			song_metadata_manager._save_metadata()
			print("MiscTab.gd: Кэш BPM сброшен для всех песен и сохранён.")
			emit_signal("settings_changed")
		else:
			print("MiscTab.gd: Кэш метаданных пуст или не содержит BPM для сброса.")
	else:
		printerr("MiscTab.gd: song_metadata_manager не установлен, невозможно сбросить кэш BPM.")

func _on_clear_all_cache_pressed():
	print("MiscTab.gd: Запрос на очистку всего кэша.")
	if song_metadata_manager:
		song_metadata_manager._metadata_cache = {}
		song_metadata_manager._save_metadata()
		print("MiscTab.gd: Весь кэш метаданных песен очищен и сохранён.")
		emit_signal("settings_changed")
	else:
		printerr("MiscTab.gd: song_metadata_manager не установлен, невозможно очистить кэш.")
