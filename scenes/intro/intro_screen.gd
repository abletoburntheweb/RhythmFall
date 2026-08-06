# scenes/intro/intro_screen.gd
extends Control

@onready var logo_texture_rect = $LogoTextureRect
@onready var intro_timer = $IntroTimer
@onready var animation_player = $IntroAnimationPlayer
@export var play_intro_music: bool = true
@export var play_menu_music_on_exit: bool = true

var game_engine: Node = null
var _leaving_intro: bool = false


func _ready():
	_setup_overlay_visibility()
	if animation_player:
		animation_player.play("fade_in_out")
	call_deferred("_start_intro_music")


func _start_intro_music() -> void:
	if not play_intro_music or MusicManager == null:
		return
	if MusicManager.has_method("load_audio_stream_async"):
		MusicManager.load_audio_stream_async(
			MusicManager.DEFAULT_INTRO_MUSIC,
			MusicManager.BGM_DIR,
			_on_intro_music_ready
		)
		return
	MusicManager.play_menu_music(MusicManager.DEFAULT_INTRO_MUSIC)


func _on_intro_music_ready(stream: Variant) -> void:
	# Skip/timeout may land before async load finishes — never restart intro BGM in the menu.
	if _leaving_intro or not is_inside_tree() or not play_intro_music:
		return
	if stream == null:
		return
	MusicManager.play_menu_music(MusicManager.DEFAULT_INTRO_MUSIC)


func _setup_overlay_visibility():
	var ge = get_parent()
	if ge and ge.has_method("get_level_layer"):
		var level_layer = ge.get_level_layer()
		if level_layer:
			level_layer.visible = false


func set_game_engine_reference(ge: Node):
	game_engine = ge


func _on_timer_timeout():
	go_to_main_menu()


func go_to_main_menu():
	if _leaving_intro:
		return
	_leaving_intro = true
	# Invalidate late async intro-music callback before switching BGM / scene.
	play_intro_music = false
	if intro_timer and not intro_timer.is_stopped():
		intro_timer.stop()

	if play_menu_music_on_exit and MusicManager:
		MusicManager.stop_music()
		MusicManager.play_menu_music(MusicManager.DEFAULT_MENU_MUSIC)

	if game_engine and game_engine.has_method("show_main_menu"):
		game_engine.show_main_menu()
	else:
		push_error("GameEngine не имеет метода show_main_menu")


func _input(event):
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		if _leaving_intro or intro_timer == null or intro_timer.is_stopped():
			return
		go_to_main_menu()
