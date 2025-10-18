# logic/game_engine.gd
extends Control

var transitions = null
var main_menu_instance = null
var intro_instance = null
var current_screen = null

func _ready():
	print("GameEngine запущен")
	initialize_logic()
	initialize_screens()
	show_intro()

func initialize_logic():
	transitions = preload("res://logic/transitions.gd").new(self)

func initialize_screens():
	print("GameEngine.gd: initialize_screens вызван")
	main_menu_instance = preload("res://scenes/main_menu/main_menu.tscn").instantiate()
	print("GameEngine.gd: main_menu_instance инстанцирован: ", main_menu_instance)
	if main_menu_instance:
		print("GameEngine.gd: main_menu_instance не null, вызываем set_transitions")
		if main_menu_instance.has_method("set_transitions"):
			main_menu_instance.set_transitions(transitions)
		if transitions.has_method("set_main_menu_instance"):
			print("GameEngine.gd: Вызываем set_main_menu_instance в transitions")
			transitions.set_main_menu_instance(main_menu_instance)
	else:
		print("GameEngine.gd: ОШИБКА! main_menu_instance равен null после instantiate!")


func show_intro():
	print("GameEngine.gd: show_intro вызван")
	if intro_instance:
		_switch_to_screen(intro_instance)
		show_main_menu()
	else:
		print("GameEngine.gd: Intro отсутствует, переходим к главному меню.")
		show_main_menu() 

func show_main_menu():
	print("GameEngine.gd: show_main_menu вызван. current_screen перед вызовом Transitions: ", current_screen)
	if transitions:
		transitions.open_main_menu()
		print("GameEngine.gd: transitions.open_main_menu() завершён. current_screen после: ", current_screen)
	else:
		print("GameEngine.gd: ОШИБКА! transitions не установлен!")

func _switch_to_screen(new_screen_instance):
	print("GameEngine.gd: _switch_to_screen вызван для ", new_screen_instance, ". current_screen до: ", current_screen)
	if current_screen and current_screen != new_screen_instance:
		print("GameEngine.gd: Удаляем предыдущий экран: ", current_screen)
		current_screen.queue_free()
		current_screen = null
	if new_screen_instance:
		print("GameEngine.gd: Добавляем новый экран как дочерний: ", new_screen_instance)
		add_child(new_screen_instance)
		current_screen = new_screen_instance
		print("GameEngine.gd: current_screen обновлён на: ", current_screen)

func request_quit():
	print("GameEngine.gd: request_quit вызван. Пытаемся закрыть игру.")
	get_tree().quit()

func get_main_menu_instance():
	return main_menu_instance

func get_transitions():
	return transitions
