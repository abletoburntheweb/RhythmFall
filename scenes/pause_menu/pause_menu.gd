# scenes/pause_menu/pause_menu.gd
extends Control

signal resume_requested
signal restart_requested
signal song_select_requested
signal settings_requested
signal exit_to_menu_requested

var transitions = null

func _ready():
	$MenuContainer/ResumeButton.pressed.connect(_on_resume_pressed)
	$MenuContainer/RestartButton.pressed.connect(_on_restart_pressed)
	$MenuContainer/SongSelectButton.pressed.connect(_on_song_select_pressed)
	$MenuContainer/SettingsButton.pressed.connect(_on_settings_pressed)
	$MenuContainer/ExitToMenuButton.pressed.connect(_on_exit_to_menu_pressed)

func set_transitions(transitions_instance):
	transitions = transitions_instance
	print("PauseMenu.gd: Transitions установлен")

func _on_resume_pressed():
	resume_requested.emit()
	
func _on_restart_pressed():
	restart_requested.emit()
	
func _on_song_select_pressed():
	if transitions:
		transitions.open_song_select() 
	else:
		printerr("PauseMenu.gd: transitions не установлен!")

func _on_settings_pressed():
	if transitions:
		transitions.open_settings(true) 
	else:
		printerr("PauseMenu.gd: transitions не установлен!")

func _on_exit_to_menu_pressed():
	if transitions:
		transitions.exit_to_main_menu()
	else:
		printerr("PauseMenu.gd: transitions не установлен!")
