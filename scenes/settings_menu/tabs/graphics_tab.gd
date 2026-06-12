# scenes/settings_menu/tabs/graphics_tab.gd
extends Control

signal settings_changed

const _OptionButtonPopupUtils = preload("res://logic/utils/option_button_popup_utils.gd")
const _SpinBoxUtils = preload("res://logic/utils/spin_box_utils.gd")

var game_engine = null 

const _DISPLAY := "ScrollWrap/CenterWrap/ContentVBox/DisplayPanel/DisplayPanelMargin/DisplayRows"
const _GAMEPLAY := "ScrollWrap/CenterWrap/ContentVBox/GameplayPanel/GameplayPanelMargin/GameplayRows"

@onready var fps_option_button: OptionButton = get_node("%s/FPS/FPSOptionButton" % _DISPLAY)
@onready var graphics_quality_option: OptionButton = get_node("%s/GraphicsQuality/GraphicsQualityOptionButton" % _DISPLAY)
@onready var window_mode_option: OptionButton = get_node("%s/WindowMode/WindowModeOptionButton" % _DISPLAY)
@onready var window_resolution_option: OptionButton = get_node("%s/WindowResolution/WindowResolutionOptionButton" % _DISPLAY)
@onready var scroll_speed_spin: SpinBox = get_node("%s/ScrollSpeed/ScrollSpeedSpinBox" % _GAMEPLAY)
@onready var lane_highlight_brightness_slider: HSlider = get_node("%s/LaneHighlightBrightnessRow/LaneHighlightBrightnessSlider" % _GAMEPLAY)
@onready var note_brightness_slider: HSlider = get_node("%s/NoteBrightnessRow/NoteBrightnessSlider" % _GAMEPLAY)
@onready var note_approach_hint_option: OptionButton = get_node("%s/NoteApproachHint/NoteApproachHintOptionButton" % _GAMEPLAY)

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
	call_deferred("_apply_graphics_quality_popup_font")
	call_deferred("_apply_note_approach_popup_font")
	call_deferred("_apply_scroll_speed_spin_font")
	call_deferred("_apply_window_mode_popup_font")
	call_deferred("_apply_window_resolution_popup_font")

func _apply_scroll_speed_spin_font() -> void:
	if scroll_speed_spin:
		_SpinBoxUtils.apply_value_font_size(scroll_speed_spin, 24)

func _apply_fps_option_popup_font() -> void:
	_OptionButtonPopupUtils.apply_popup_font_size(fps_option_button, 24)

func _apply_graphics_quality_popup_font() -> void:
	_OptionButtonPopupUtils.apply_popup_font_size(graphics_quality_option, 24)

func _apply_note_approach_popup_font() -> void:
	if note_approach_hint_option:
		_OptionButtonPopupUtils.apply_popup_font_size(note_approach_hint_option, 24)

func _apply_window_mode_popup_font() -> void:
	if window_mode_option:
		_OptionButtonPopupUtils.apply_popup_font_size(window_mode_option, 24)

func _apply_window_resolution_popup_font() -> void:
	if window_resolution_option:
		_OptionButtonPopupUtils.apply_popup_font_size(window_resolution_option, 24)

func _select_note_approach_hint_by_id(id: int) -> void:
	if not note_approach_hint_option:
		return
	var count := note_approach_hint_option.get_item_count()
	for i in range(count):
		if note_approach_hint_option.get_item_id(i) == id:
			note_approach_hint_option.select(i)
			return

func _select_fps_by_id(id: int):
	var count = fps_option_button.get_item_count()
	for i in range(count):
		if fps_option_button.get_item_id(i) == id:
			fps_option_button.select(i)
			return

func _select_graphics_quality_by_id(id: int):
	var count = graphics_quality_option.get_item_count()
	for i in range(count):
		if graphics_quality_option.get_item_id(i) == id:
			graphics_quality_option.select(i)
			return

func _select_window_mode_by_id(id: int) -> void:
	if not window_mode_option:
		return
	var count := window_mode_option.get_item_count()
	for i in range(count):
		if window_mode_option.get_item_id(i) == id:
			window_mode_option.select(i)
			return

func _select_window_resolution_by_id(id: int) -> void:
	if not window_resolution_option:
		return
	var count := window_resolution_option.get_item_count()
	for i in range(count):
		if window_resolution_option.get_item_id(i) == id:
			window_resolution_option.select(i)
			return

func _update_window_resolution_control_enabled() -> void:
	if not window_resolution_option:
		return
	var borderless: bool = SettingsManager.get_window_mode() == 2
	window_resolution_option.disabled = borderless
	window_resolution_option.focus_mode = Control.FOCUS_NONE if borderless else Control.FOCUS_ALL

func setup_ui_and_manager(game_engine_node = null):
	game_engine = game_engine_node 
	_setup_ui()

func _setup_ui():
	var current_fps_mode = SettingsManager.get_fps_mode()
	_select_fps_by_id(current_fps_mode)
	if SettingsManager.has_method("get_graphics_quality"):
		_select_graphics_quality_by_id(SettingsManager.get_graphics_quality())
	
	if window_mode_option:
		_select_window_mode_by_id(SettingsManager.get_window_mode())
	if window_resolution_option:
		_select_window_resolution_by_id(SettingsManager.get_window_resolution())
	_update_window_resolution_control_enabled()

	var spd = SettingsManager.get_scroll_speed()
	scroll_speed_spin.set_value_no_signal(spd)
	
	if lane_highlight_brightness_slider:
		var lh_b = SettingsManager.get_lane_highlight_brightness() if SettingsManager.has_method("get_lane_highlight_brightness") else 1.0
		lane_highlight_brightness_slider.set_value_no_signal(lh_b)
	if note_brightness_slider:
		var n_b = SettingsManager.get_note_brightness() if SettingsManager.has_method("get_note_brightness") else 1.0
		note_brightness_slider.set_value_no_signal(n_b)
	if note_approach_hint_option and SettingsManager.has_method("get_note_approach_hint"):
		_select_note_approach_hint_by_id(SettingsManager.get_note_approach_hint())


func _on_note_approach_hint_selected(index: int) -> void:
	if not note_approach_hint_option:
		return
	var id := note_approach_hint_option.get_item_id(index)
	if SettingsManager.has_method("set_note_approach_hint"):
		SettingsManager.set_note_approach_hint(id)
	emit_signal("settings_changed")


func _on_fps_mode_selected(index: int):
	var id = fps_option_button.get_item_id(index)
	SettingsManager.set_fps_mode(id)
	emit_signal("settings_changed")
	_apply_display_settings()

func _on_graphics_quality_selected(index: int):
	var id = graphics_quality_option.get_item_id(index)
	if SettingsManager.has_method("set_graphics_quality"):
		SettingsManager.set_graphics_quality(id)
	else:
		SettingsManager.set_setting("graphics_quality", id)
		SettingsManager.save_settings()
	print("GraphicsTab: качество графики изменено на id=", id)
	emit_signal("settings_changed")
	_apply_display_settings()

func _on_window_mode_selected(index: int) -> void:
	if not window_mode_option:
		return
	var id := window_mode_option.get_item_id(index)
	SettingsManager.set_window_mode(id)
	_update_window_resolution_control_enabled()
	emit_signal("settings_changed")
	_apply_display_settings()

func _on_window_resolution_selected(index: int) -> void:
	if not window_resolution_option:
		return
	var id := window_resolution_option.get_item_id(index)
	SettingsManager.set_window_resolution(id)
	emit_signal("settings_changed")
	_apply_display_settings()

func _apply_display_settings() -> void:
	var engine = _get_game_engine()
	if engine and engine.has_method("update_display_settings"):
		engine.update_display_settings()

func _get_game_engine():
	if game_engine and is_instance_valid(game_engine):
		return game_engine
	var root := get_tree().root
	if root.has_node("GameEngine"):
		game_engine = root.get_node("GameEngine")
		return game_engine
	for child in root.get_children():
		if child.has_method("update_display_settings"):
			game_engine = child
			return game_engine
	return null

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
