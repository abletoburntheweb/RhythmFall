# scenes/settings_menu/settings_menu.gd
extends BaseScreen

var settings_manager: SettingsManager = null
var game_screen = null
var achievement_manager = null

@onready var btn_sound: Button = $MainVBox/TabsHBox/BtnSound
@onready var btn_graphics: Button = $MainVBox/TabsHBox/BtnGraphics
@onready var btn_controls: Button = $MainVBox/TabsHBox/BtnControls
@onready var btn_misc: Button = $MainVBox/TabsHBox/BtnMisc
@onready var tab_container: TabContainer = $MainVBox/ContentContainer/SettingsTabContainer
@onready var back_button: Button = $MainVBox/BackButton

const TAB_PATHS = {
	"SoundTab": "res://scenes/settings_menu/tabs/sound_tab.tscn",
	"GraphicsTab": "res://scenes/settings_menu/tabs/graphics_tab.tscn",
	"ControlsTab": "res://scenes/settings_menu/tabs/controls_tab.tscn",
	"MiscTab": "res://scenes/settings_menu/tabs/misc_tab.tscn",
}

func _ready():
	if not settings_manager:
		settings_manager = SettingsManager.new()
	
	var parent_node = get_parent()
	var music_mgr = null
	var trans = null

	if parent_node:
		if parent_node.has_method("get_music_manager") and parent_node.has_method("get_transitions"):
			music_mgr = parent_node.get_music_manager()
			trans = parent_node.get_transitions()

	setup_managers(trans, music_mgr)

	var game_engine_node = null
	if parent_node and parent_node.has_method("get_achievement_manager"):
		game_engine_node = parent_node
	else:
		if get_tree().root.has_node("GameEngine"):
			game_engine_node = get_tree().root.get_node("GameEngine")
		else:
			for child in get_tree().root.get_children():
				if child.has_method("get_achievement_manager"):
					game_engine_node = child
					break

	if game_engine_node and game_engine_node.has_method("get_achievement_manager"):
		self.achievement_manager = game_engine_node.get_achievement_manager()
	else:
		self.achievement_manager = null

	tab_container.tabs_visible = false
	
	_setup_tabs()
	_connect_signals()

	if tab_container.get_tab_count() > 0:
		tab_container.current_tab = 0

func _setup_tabs():
	var song_metadata_mgr = null
	if get_parent() and get_parent().has_method("get_song_metadata_manager"):
		song_metadata_mgr = get_parent().get_song_metadata_manager()

	for tab_name in TAB_PATHS:
		var scene_path = TAB_PATHS[tab_name]
		var scene_resource = load(scene_path)

		if not scene_resource or not (scene_resource is PackedScene):
			continue

		var tab_instance = scene_resource.instantiate()
		if not tab_instance:
			continue

		tab_container.add_child(tab_instance)
		var tab_title = tab_name.replace("Tab", "")
		tab_container.set_tab_title(tab_container.get_tab_count() - 1, tab_title)

		if tab_instance.has_method("setup_ui_and_manager"):
			if tab_name == "MiscTab":
				tab_instance.setup_ui_and_manager(
					settings_manager,
					music_manager,
					game_screen,
					song_metadata_mgr,   
					self.achievement_manager
				)
			elif tab_name == "GraphicsTab":
				var game_engine = null
				if get_parent() and get_parent().has_method("get_settings_manager"):
					game_engine = get_parent()
				elif get_tree().root.has_node("GameEngine"):
					game_engine = get_tree().root.get_node("GameEngine")

				tab_instance.setup_ui_and_manager(
					settings_manager,
					music_manager,
					game_engine
				)
			else:
				tab_instance.setup_ui_and_manager(
					settings_manager,
					music_manager,
					game_screen
				)

		if tab_name in ["SoundTab", "ControlsTab"] and tab_instance.has_signal("settings_changed"):
			tab_instance.connect("settings_changed", Callable(self, "save_settings"))

func _connect_signals():
	if btn_sound:
		btn_sound.pressed.connect(_on_sound_tab_pressed)
	if btn_graphics:
		btn_graphics.pressed.connect(_on_graphics_tab_pressed)
	if btn_controls:
		btn_controls.pressed.connect(_on_controls_tab_pressed)
	if btn_misc:
		btn_misc.pressed.connect(_on_misc_tab_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

func _on_sound_tab_pressed():
	tab_container.current_tab = 0

func _on_graphics_tab_pressed():
	tab_container.current_tab = 1

func _on_controls_tab_pressed():
	tab_container.current_tab = 2

func _on_misc_tab_pressed():
	tab_container.current_tab = 3

func _execute_close_transition():
	if transitions:
		var current_parent = get_parent()
		var is_child_of_pause = (
			current_parent != null and
			(current_parent.has_signal("resume_requested") or current_parent.has_method("handle_resume_request"))
		)
		transitions.close_settings(is_child_of_pause)
	else:
		pass

func cleanup_before_exit():
	save_settings()

func save_settings():
	if settings_manager:
		settings_manager.save_settings()

func set_managers(settings, music, game_scr, trans, achievement_mgr = null):
	settings_manager = settings
	setup_managers(trans, music) 
	game_screen = game_scr
	self.achievement_manager = achievement_mgr
