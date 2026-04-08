# scenes/settings_menu/tabs/graphics_tab.gd
extends Control

signal settings_changed

const _OptionButtonPopupUtils = preload("res://logic/utils/option_button_popup_utils.gd")

var game_engine = null 

@onready var fps_option_button: OptionButton = $ContentVBox/FPS/FPSOptionButton
@onready var fullscreen_checkbox: CheckBox = $ContentVBox/FullscreenCheckBox 
@onready var scroll_speed_spin: SpinBox = $ContentVBox/ScrollSpeed/ScrollSpeedSpinBox
@onready var lane_highlight_brightness_slider: HSlider = $ContentVBox/LaneHighlightBrightnessSlider
@onready var note_brightness_slider: HSlider = $ContentVBox/NoteBrightnessSlider

func _ready():
	if lane_highlight_brightness_slider:
		lane_highlight_brightness_slider.min_value = 0.0
		lane_highlight_brightness_slider.max_value = 100.0
		lane_highlight_brightness_slider.step = 1.0
	if note_brightness_slider:
		note_brightness_slider.min_value = 0.0
		note_brightness_slider.max_value = 100.0
		note_brightness_slider.step = 1.0
	call_deferred("_apply_fps_option_popup_font")

func _apply_fps_option_popup_font() -> void:
	_OptionButtonPopupUtils.apply_popup_font_size(fps_option_button, 24)

func _select_fps_by_id(id: int):
	var count = fps_option_button.get_item_count()
	for i in range(count):
		if fps_option_button.get_item_id(i) == id:
			fps_option_button.select(i)
			return

func setup_ui_and_manager(game_engine_node = null):
	game_engine = game_engine_node 
	_setup_ui()

func _setup_ui():
	var current_fps_mode = SettingsManager.get_fps_mode()
	_select_fps_by_id(current_fps_mode)
	
	fullscreen_checkbox.set_pressed_no_signal(SettingsManager.get_fullscreen())
	
	var spd = SettingsManager.get_scroll_speed()
	scroll_speed_spin.set_value_no_signal(spd)
	
	if lane_highlight_brightness_slider:
		var lh_b = SettingsManager.get_lane_highlight_brightness() if SettingsManager.has_method("get_lane_highlight_brightness") else 1.0
		lane_highlight_brightness_slider.set_value_no_signal(lh_b)
	if note_brightness_slider:
		var n_b = SettingsManager.get_note_brightness() if SettingsManager.has_method("get_note_brightness") else 1.0
		note_brightness_slider.set_value_no_signal(n_b)


func _on_fps_mode_selected(index: int):
	var id = fps_option_button.get_selected_id()
	SettingsManager.set_fps_mode(id)
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

func _on_scroll_speed_spin_changed(value: float):
	SettingsManager.set_scroll_speed(value)
	emit_signal("settings_changed")

func _on_lane_highlight_brightness_changed(value: float):
	SettingsManager.set_lane_highlight_brightness(value)
	emit_signal("settings_changed")

func _on_note_brightness_changed(value: float):
	SettingsManager.set_note_brightness(value)
	emit_signal("settings_changed")
