# scenes/settings_menu/settings_menu.gd
extends BaseScreen

var game_screen = null
var achievement_manager = null

@onready var btn_sound: Button = $MainVBox/TabsHBox/BtnSound
@onready var btn_graphics: Button = $MainVBox/TabsHBox/BtnGraphics
@onready var btn_controls: Button = $MainVBox/TabsHBox/BtnControls
@onready var btn_misc: Button = $MainVBox/TabsHBox/BtnMisc
@onready var tab_container: TabContainer = $MainVBox/ContentContainer/SettingsTabContainer
@onready var back_button: Button = $MainVBox/BackButton

 

func _ready():
	var parent_node = get_parent()
	var trans = null

	if parent_node and parent_node.has_method("get_transitions"):
		trans = parent_node.get_transitions()

	if trans:
		setup_managers(trans)

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

	for i in range(tab_container.get_child_count()):
		var child = tab_container.get_child(i)
		var tab_title = child.name.replace("Tab", "")
		tab_container.set_tab_title(i, tab_title)
		if child.has_method("setup_ui_and_manager"):
			if child.name == "MiscTab":
				child.setup_ui_and_manager(
					game_screen,
					song_metadata_mgr,
					self.achievement_manager
				)
			elif child.name == "GraphicsTab":
				var game_engine = null
				if get_parent() and get_parent().has_method("get_settings_manager"):
					game_engine = get_parent()
				elif get_tree().root.has_node("GameEngine"):
					game_engine = get_tree().root.get_node("GameEngine")
				child.setup_ui_and_manager(game_engine)
			else:
				child.setup_ui_and_manager(game_screen)
		if child.has_signal("settings_changed"):
			child.connect("settings_changed", Callable(self, "save_settings"))

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
		var from_pause = false
		if transitions and transitions.game_engine:
			from_pause = (current_parent == transitions.game_engine.current_screen)
		transitions.close_settings(from_pause)
	else:
		pass

func cleanup_before_exit():
	save_settings()

func save_settings():
	SettingsManager.save_settings()
