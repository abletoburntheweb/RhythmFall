# scenes/song_select/generation_selector.gd
class_name GenerationSelector
extends Control

signal generation_mode_selected(mode: String)
signal selector_closed

var music_manager = null

func set_managers(music_mgr):
	music_manager = music_mgr
	if music_manager:
		print("GenerationSelector.gd: MusicManager установлен.")
	else:
		print("GenerationSelector.gd: MusicManager не установлен (null).")

func _ready():
	print("GenerationSelector.gd: _ready вызван")
	
	var background = $Background
	if background and background is ColorRect:
		background.color = Color(0, 0, 0, 180.0 / 255.0)
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE 

	var back_button = $Container/BackButton
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
		print("GenerationSelector.gd: Подключён сигнал BackButton")

	var basic_button = $Container/Content/BasicButton
	if basic_button:
		basic_button.pressed.connect(_on_basic_pressed)
		print("GenerationSelector.gd: Подключён сигнал BasicButton")
	else:
		printerr("GenerationSelector.gd: Кнопка BasicButton не найдена в сцене!")

	var enhanced_button = $Container/Content/EnhancedButton
	if enhanced_button:
		enhanced_button.pressed.connect(_on_enhanced_pressed)
		print("GenerationSelector.gd: Подключён сигнал EnhancedButton")
	else:
		printerr("GenerationSelector.gd: Кнопка EnhancedButton не найдена в сцене!")

	show()

func _on_basic_pressed():
	print("GenerationSelector.gd: Нажата кнопка Базовый!")
	emit_signal("generation_mode_selected", "basic")
	emit_signal("selector_closed")

func _on_enhanced_pressed():
	print("GenerationSelector.gd: Нажата кнопка Улучшенный!")
	emit_signal("generation_mode_selected", "enhanced")
	emit_signal("selector_closed")

func _on_close_pressed():
	print("GenerationSelector.gd: Нажата кнопка Закрыть")
	if music_manager and music_manager.has_method("play_cancel_sound"):
		music_manager.play_cancel_sound()
	emit_signal("selector_closed")

func _on_back_button_pressed():
	print("GenerationSelector.gd: Нажата кнопка Назад")
	if music_manager and music_manager.has_method("play_cancel_sound"):
		music_manager.play_cancel_sound()
	emit_signal("selector_closed")

func _input(event: InputEvent):
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		print("GenerationSelector.gd: Нажат Escape")
		if music_manager and music_manager.has_method("play_cancel_sound"):
			music_manager.play_cancel_sound()
		_on_back_button_pressed()
