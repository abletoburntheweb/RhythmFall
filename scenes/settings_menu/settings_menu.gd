# scenes/settings_menu/settings_menu.gd
extends BaseScreen

var settings_manager: SettingsManager = null
var game_screen = null

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
	print("SettingsMenu.gd: _ready вызван.")
	if not settings_manager:
		print("SettingsMenu.gd: settings_manager не передан, создаю новый экземпляр.")
		settings_manager = SettingsManager.new()
	var game_engine = get_parent()
	if game_engine and game_engine.has_method("get_music_manager") and game_engine.has_method("get_transitions"):
		var music_mgr = game_engine.get_music_manager()
		var trans = game_engine.get_transitions()

		setup_managers(trans, music_mgr, null)

		print("SettingsMenu.gd: MusicManager и Transitions получены через GameEngine.")
	else:
		printerr("SettingsMenu.gd: Не удалось получить один из менеджеров (music_manager, transitions) через GameEngine.")

	_setup_tabs()
	_connect_signals()

	if tab_container.get_tab_count() > 0:
		tab_container.current_tab = 0
		print("SettingsMenu.gd: Установлена первая вкладка по умолчанию.")

func _setup_tabs():
	print("SettingsMenu.gd: _setup_tabs вызван.")
	var song_metadata_mgr = null
	if get_parent() and get_parent().has_method("get_song_metadata_manager"):
		song_metadata_mgr = get_parent().get_song_metadata_manager()

	var loaded_tabs_count = 0

	for tab_name in TAB_PATHS:
		var scene_path = TAB_PATHS[tab_name]
		var scene_resource = load(scene_path)

		if not scene_resource:
			printerr("SettingsMenu.gd: Не удалось загрузить ресурс сцены для %s по пути: %s" % [tab_name, scene_path])
			continue

		if not scene_resource is PackedScene:
			printerr("SettingsMenu.gd: Загруженный ресурс для %s не является PackedScene: %s" % [tab_name, scene_path])
			continue

		var tab_instance = scene_resource.instantiate()
		if not tab_instance:
			printerr("SettingsMenu.gd: instantiate вернул null для %s!" % tab_name)
			continue

		tab_container.add_child(tab_instance)
		print("SettingsMenu.gd: Экземпляр вкладки %s добавлен в TabContainer." % tab_name)

		var tab_title = tab_name.replace("Tab", "")
		tab_container.set_tab_title(tab_container.get_tab_count() - 1, tab_title)
		print("SettingsMenu.gd: Заголовок вкладки %s установлен на '%s'." % [tab_name, tab_title])

		if tab_instance.has_method("setup_ui_and_manager"):
			print("SettingsMenu.gd: Вызываю setup_ui_and_manager для %s." % tab_name)
			if tab_name == "MiscTab":
				tab_instance.setup_ui_and_manager(settings_manager, music_manager, game_screen, song_metadata_mgr)
			else:
				tab_instance.setup_ui_and_manager(settings_manager, music_manager, game_screen)
			print("SettingsMenu.gd: Менеджеры переданы в %s." % tab_name)
		else:
			print("SettingsMenu.gd: Вкладка %s не имеет метода setup_ui_and_manager." % tab_name)

		if tab_name == "SoundTab":
			if tab_instance.has_signal("settings_changed"):
				tab_instance.connect("settings_changed", Callable(self, "save_settings"))
				print("SettingsMenu.gd: Подключён сигнал settings_changed от %s." % tab_name)
			else:
				print("SettingsMenu.gd: Вкладка SoundTab не имеет сигнала settings_changed.")

		if tab_name == "ControlsTab":
			if tab_instance.has_signal("settings_changed"):
				tab_instance.connect("settings_changed", Callable(self, "save_settings"))
				print("SettingsMenu.gd: Подключён сигнал settings_changed от %s." % tab_name)
			else:
				print("SettingsMenu.gd: Вкладка ControlsTab не имеет сигнала settings_changed.")

		loaded_tabs_count += 1

	print("SettingsMenu.gd: Загружено вкладок: %d из %d." % [loaded_tabs_count, TAB_PATHS.size()])

func _connect_signals():
	print("SettingsMenu.gd: _connect_signals вызван.")

	if btn_sound:
		btn_sound.pressed.connect(_on_sound_tab_pressed)
		print("SettingsMenu.gd: Подключён сигнал pressed кнопки Звук.")
	else:
		printerr("SettingsMenu.gd: Кнопка btn_sound не найдена!")

	if btn_graphics:
		btn_graphics.pressed.connect(_on_graphics_tab_pressed)
		print("SettingsMenu.gd: Подключён сигнал pressed кнопки Графика.")
	else:
		printerr("SettingsMenu.gd: Кнопка btn_graphics не найдена!")

	if btn_controls:
		btn_controls.pressed.connect(_on_controls_tab_pressed)
		print("SettingsMenu.gd: Подключён сигнал pressed кнопки Управление.")
	else:
		printerr("SettingsMenu.gd: Кнопка btn_controls не найдена!")

	if btn_misc:
		btn_misc.pressed.connect(_on_misc_tab_pressed)
		print("SettingsMenu.gd: Подключён сигнал pressed кнопки Прочее.")
	else:
		printerr("SettingsMenu.gd: Кнопка btn_misc не найдена!")

	if back_button:
		back_button.pressed.connect(_on_back_pressed)
		print("SettingsMenu.gd: Подключён сигнал pressed кнопки Назад (вызов _on_back_pressed из BaseScreen).")
	else:
		printerr("SettingsMenu.gd: Кнопка back_button не найдена!")

func _on_sound_tab_pressed():
	print("SettingsMenu.gd: Нажата вкладка Звук.")
	tab_container.current_tab = 0

func _on_graphics_tab_pressed():
	print("SettingsMenu.gd: Нажата вкладка Графика.")
	tab_container.current_tab = 1

func _on_controls_tab_pressed():
	print("SettingsMenu.gd: Нажата вкладка Управление.")
	tab_container.current_tab = 2

func _on_misc_tab_pressed():
	print("SettingsMenu.gd: Нажата вкладка Прочее.")
	tab_container.current_tab = 3

func _execute_close_transition():
	if transitions:
		var from_pause = game_screen != null
		print("SettingsMenu.gd: Закрываю настройки, from_pause: %s" % from_pause)
		transitions.close_settings(from_pause)
		print("SettingsMenu.gd: Закрываю настройки через Transitions.")
	else:
		printerr("SettingsMenu.gd: transitions не установлен, невозможно закрыть настройки.")

func cleanup_before_exit():
	print("SettingsMenu.gd: cleanup_before_exit вызван. Сохраняем настройки.")
	save_settings()

func save_settings():
	if settings_manager:
		settings_manager.save_settings()
		print("SettingsMenu.gd: Настройки сохранены через SettingsManager.")
	else:
		printerr("SettingsMenu.gd: settings_manager не установлен, невозможно сохранить настройки.")

func set_managers(settings, music, game_scr, trans):
	print("SettingsMenu.gd: set_managers вызван.")
	settings_manager = settings
	setup_managers(trans, music, null)
	game_screen = game_scr
	print("SettingsMenu.gd: Менеджеры установлены через set_managers и setup_managers.")
