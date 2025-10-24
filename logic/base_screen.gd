# logic/base_screen.gd
class_name BaseScreen
extends Control

var transitions = null 
var music_manager = null
var player_data_manager = null

func setup_managers(trans, music: MusicManager, player_data: PlayerDataManager = null) -> void:
	print("BaseScreen.gd: setup_managers вызван.")
	transitions = trans
	music_manager = music
	player_data_manager = player_data

func _on_back_pressed():
	print("BaseScreen.gd: Нажата кнопка Назад или Escape.")
	var game_engine = get_parent()
	if game_engine and game_engine.has_method("prepare_screen_exit"):
		if game_engine.prepare_screen_exit(self):
			print("BaseScreen.gd: Экран подготовлен к выходу через GameEngine.")
		else:
			print("BaseScreen.gd: ОШИБКА подготовки экрана к выходу через GameEngine.")
	else:
		printerr("BaseScreen.gd: Не удалось получить GameEngine или метод prepare_screen_exit!")

	cleanup_before_exit()

	if music_manager:
		music_manager.play_cancel_sound()
		print("BaseScreen.gd: play_cancel_sound вызван через music_manager.")
	else:
		printerr("BaseScreen.gd: music_manager не установлен!")

	if player_data_manager:
		print("BaseScreen.gd: Данные игрока сохранены перед выходом из экрана.")
	_execute_close_transition()

func _execute_close_transition() -> void:
	push_warning("BaseScreen.gd: _execute_close_transition() не переопределён в " + get_script().resource_path)
	if transitions:
		transitions.open_main_menu()

func cleanup_before_exit() -> void:
	print("BaseScreen.gd: cleanup_before_exit вызван (заглушка). Переопределите в наследнике.")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		print("BaseScreen.gd: Обнаружено нажатие Escape, вызываю _on_back_pressed.")
		accept_event()
		_on_back_pressed()

func _exit_tree() -> void:
	print("BaseScreen.gd: _exit_tree вызван для %s. Экран удаляется из дерева сцен." % get_script().resource_path)
	cleanup_before_exit()
