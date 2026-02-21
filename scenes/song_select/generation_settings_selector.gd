# scenes/song_select/generation_settings_selector.gd
class_name GenerationSettingsSelector
extends Control

signal generation_settings_confirmed(instrument: String, mode: String, lanes: int)
signal selector_closed

var selected_instrument: String = "drums"
var selected_mode: String = "basic"
var selected_lanes: int = 4

const ACTIVE_COLOR = Color(0.8, 0.8, 1.0, 1.0)
const DEFAULT_COLOR = Color(1.0, 1.0, 1.0, 1.0)

func _ready():
	var background = $Background
	if background:
		background.color = Color(0, 0, 0, 180.0 / 255.0)
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
	selected_instrument = SettingsManager.get_setting("last_generation_instrument", "drums")
	selected_mode = SettingsManager.get_setting("last_generation_mode", "basic")
	selected_lanes = SettingsManager.get_setting("last_generation_lanes", 4)
	

	_update_ui_from_selection()

	
func _update_ui_from_selection():
	for btn in [$Container/InstrumentButtons/PercussionButton]:
		btn.self_modulate = DEFAULT_COLOR
	for btn in [$Container/ModeButtons/BasicButton, $Container/ModeButtons/EnhancedButton]:
		btn.self_modulate = DEFAULT_COLOR
	for btn in [$Container/LanesButtons/Lanes3Button, $Container/LanesButtons/Lanes4Button, $Container/LanesButtons/Lanes5Button]:
		btn.self_modulate = DEFAULT_COLOR

	if selected_instrument == "drums":
		$Container/InstrumentButtons/PercussionButton.self_modulate = ACTIVE_COLOR

	if selected_mode == "basic":
		$Container/ModeButtons/BasicButton.self_modulate = ACTIVE_COLOR
	elif selected_mode == "enhanced":
		$Container/ModeButtons/EnhancedButton.self_modulate = ACTIVE_COLOR

	match selected_lanes:
		3: $Container/LanesButtons/Lanes3Button.self_modulate = ACTIVE_COLOR
		4: $Container/LanesButtons/Lanes4Button.self_modulate = ACTIVE_COLOR
		5: $Container/LanesButtons/Lanes5Button.self_modulate = ACTIVE_COLOR
		
func _on_percussion_selected():
	selected_instrument = "drums"
	_set_active_button($Container/InstrumentButtons/PercussionButton)

func _on_basic_selected():
	selected_mode = "basic"
	_set_active_button($Container/ModeButtons/BasicButton)

func _on_enhanced_selected():
	selected_mode = "enhanced"
	_set_active_button($Container/ModeButtons/EnhancedButton)

func _on_lanes3_selected():
	selected_lanes = 3
	_set_active_button($Container/LanesButtons/Lanes3Button)

func _on_lanes4_selected():
	selected_lanes = 4
	_set_active_button($Container/LanesButtons/Lanes4Button)

func _on_lanes5_selected():
	selected_lanes = 5
	_set_active_button($Container/LanesButtons/Lanes5Button)

func _set_active_button(active_btn: Button):
	var group_container = active_btn.get_parent()
	for child in group_container.get_children():
		if child is Button:
			child.self_modulate = DEFAULT_COLOR
	
	active_btn.self_modulate = ACTIVE_COLOR

func _on_confirm_pressed():
	SettingsManager.set_setting("last_generation_instrument", selected_instrument)
	SettingsManager.set_setting("last_generation_mode", selected_mode)
	SettingsManager.set_setting("last_generation_lanes", selected_lanes)
	SettingsManager.save_settings()
	
	MusicManager.play_instrument_select_sound(selected_instrument)
	
	emit_signal("generation_settings_confirmed", selected_instrument, selected_mode, selected_lanes)
	emit_signal("selector_closed")

func _on_back_button_pressed():
	MusicManager.play_cancel_sound()
	emit_signal("selector_closed")

func _input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		_on_back_button_pressed()
		accept_event()
