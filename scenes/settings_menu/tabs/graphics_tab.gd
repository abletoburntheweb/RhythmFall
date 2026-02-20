# scenes/settings_menu/tabs/graphics_tab.gd
extends Control

signal settings_changed

var game_engine = null 

@onready var fps_option_button: OptionButton = $ContentVBox/FPS/FPSOptionButton
@onready var fullscreen_checkbox: CheckBox = $ContentVBox/FullscreenCheckBox 

func _ready():
	_setup_fps_options()

func _setup_fps_options():
	fps_option_button.clear()
	fps_option_button.add_item("Нет", 0)
	fps_option_button.add_item("Обычный", 1) 
	fps_option_button.add_item("Контрастный", 2)

func setup_ui_and_manager(game_engine_node = null):
	game_engine = game_engine_node 
	_setup_ui()

func _setup_ui():
	
	var current_fps_mode = SettingsManager.get_fps_mode()
	fps_option_button.select(current_fps_mode)
	
	fullscreen_checkbox.set_pressed_no_signal(SettingsManager.get_fullscreen())


func _on_fps_mode_selected(index: int):
	SettingsManager.set_fps_mode(index)
	emit_signal("settings_changed")
	if game_engine and game_engine.has_method("update_display_settings"):
		game_engine.update_display_settings()

func _on_fullscreen_toggled(enabled: bool):
	SettingsManager.set_fullscreen(enabled)
	emit_signal("settings_changed")
	if game_engine and game_engine.has_method("update_display_settings"):
		game_engine.update_display_settings()

func refresh_ui():
	_setup_ui()


 
