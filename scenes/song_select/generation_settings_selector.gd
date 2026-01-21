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

	$Container/InstrumentButtons/PercussionButton.pressed.connect(_on_percussion_selected)
	$Container/ModeButtons/BasicButton.pressed.connect(_on_basic_selected)
	$Container/ModeButtons/EnhancedButton.pressed.connect(_on_enhanced_selected)
	$Container/LanesButtons/Lanes3Button.pressed.connect(_on_lanes3_selected)
	$Container/LanesButtons/Lanes4Button.pressed.connect(_on_lanes4_selected)
	$Container/LanesButtons/Lanes5Button.pressed.connect(_on_lanes5_selected)
	$Container/ConfirmButton.pressed.connect(_on_confirm_pressed)
	$Container/BackButton.pressed.connect(_on_back_button_pressed)

	_on_percussion_selected()   
	_on_basic_selected()
	_on_lanes4_selected()

	show()

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
	MusicManager.play_select_sound()
	emit_signal("generation_settings_confirmed", selected_instrument, selected_mode, selected_lanes)
	emit_signal("selector_closed")

func _on_back_button_pressed():
	MusicManager.play_cancel_sound()
	emit_signal("selector_closed")

func _input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		MusicManager.play_cancel_sound()
		_on_back_button_pressed()
