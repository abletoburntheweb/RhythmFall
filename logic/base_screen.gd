# logic/base_screen.gd
class_name BaseScreen
extends Control

var transitions = null 


func setup_managers(trans) -> void:  
	transitions = trans

func _on_back_pressed():
	var parent_node = get_parent()
	var game_engine = null
	if parent_node and parent_node.has_method("prepare_screen_exit"):
		game_engine = parent_node
	elif get_tree().root.has_node("GameEngine"):
		game_engine = get_tree().root.get_node("GameEngine")

	if game_engine and game_engine.has_method("prepare_screen_exit") and game_engine.current_screen == self:
		if game_engine.prepare_screen_exit(self):
			pass
		else:
			printerr("BaseScreen.gd: ОШИБКА подготовки экрана к выходу через GameEngine.")

	cleanup_before_exit()

	MusicManager.play_cancel_sound()

	_execute_close_transition()

func _execute_close_transition() -> void:
	push_warning("BaseScreen.gd: _execute_close_transition() не переопределён в " + get_script().resource_path)
	if transitions:
		transitions.open_main_menu()

func cleanup_before_exit() -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		accept_event()
		_on_back_pressed()

func _exit_tree() -> void:
	cleanup_before_exit()
