# scenes/settings_menu/tabs/graphics_tab.gd
extends Control

signal settings_changed

var music_manager = null 

var settings_manager: SettingsManager = null
var game_screen = null 

@onready var show_fps_checkbox: CheckBox = $ContentVBox/ShowFPSCheckBox
@onready var fullscreen_checkbox: CheckBox = $ContentVBox/FullscreenCheckBox 

func _ready():
	print("GraphicsTab.gd: _ready вызван.")

func setup_ui_and_manager(manager: SettingsManager, _music_manager, screen = null):
	settings_manager = manager
	self.music_manager = _music_manager
	game_screen = screen
	_setup_ui()
	_connect_signals()

func _setup_ui():
	if not settings_manager:
		printerr("GraphicsTab.gd: settings_manager не установлен, невозможно настроить UI.")
		return

	print("GraphicsTab.gd: _setup_ui вызван.")
	show_fps_checkbox.set_pressed_no_signal(settings_manager.get_show_fps())
	fullscreen_checkbox.set_pressed_no_signal(settings_manager.get_fullscreen())

func _connect_signals():
	if show_fps_checkbox:
		show_fps_checkbox.toggled.connect(_on_show_fps_toggled)
	if fullscreen_checkbox:
		fullscreen_checkbox.toggled.connect(_on_fullscreen_toggled)

func _on_show_fps_toggled(enabled: bool):
	if settings_manager:
		settings_manager.set_show_fps(enabled)
		emit_signal("settings_changed")
	else:
		printerr("GraphicsTab.gd: _on_show_fps_toggled: settings_manager не установлен!")

func _on_fullscreen_toggled(enabled: bool):
	if settings_manager:
		settings_manager.set_fullscreen(enabled)
		emit_signal("settings_changed")
	else:
		printerr("GraphicsTab.gd: _on_fullscreen_toggled: settings_manager не установлен!")

func refresh_ui():
	_setup_ui()
