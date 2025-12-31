# scenes/intro/intro_screen.gd
extends Control

@onready var logo_texture_rect = $LogoTextureRect
@onready var intro_timer = $IntroTimer
@onready var animation_player = $IntroAnimationPlayer

var game_engine: Node = null

var music_manager: MusicManager = null

func _ready():
	if game_engine and game_engine.has_method("get_music_manager"):
		music_manager = game_engine.get_music_manager()
	if not music_manager:
		music_manager = get_tree().root.get_node("MusicManager") as MusicManager
		if not music_manager:
			print("MusicManager не найден, звук не будет воспроизводиться")

	animation_player.play("fade_in_out")

	intro_timer.timeout.connect(_on_timer_timeout)
	intro_timer.start()

	if music_manager:
		music_manager.play_menu_music(MusicManager.DEFAULT_INTRO_MUSIC)

func set_game_engine_reference(ge: Node):
	game_engine = ge

func _on_timer_timeout():
	go_to_main_menu()

func go_to_main_menu():
	if music_manager:
		music_manager.stop_music()
		music_manager.play_menu_music(MusicManager.DEFAULT_MENU_MUSIC)

	if game_engine and game_engine.has_method("show_main_menu"):
		game_engine.show_main_menu()
	else:
		push_error("GameEngine не имеет метода show_main_menu")

func _input(event):
	if event.is_action_pressed("ui_accept"): 
		if intro_timer.is_stopped():
			return
		intro_timer.stop()
		go_to_main_menu()
	elif event.is_action_pressed("ui_cancel"): 
		if intro_timer.is_stopped():
			return
		intro_timer.stop()
		go_to_main_menu()
