# scenes/song_select/instrument_selector.gd
class_name InstrumentSelector
extends Control

signal instrument_selected(instrument_type: String)
signal selector_closed

var music_manager = null

func set_managers(music_mgr):
	music_manager = music_mgr
	if music_manager:
		print("InstrumentSelector.gd: MusicManager установлен.")
	else:
		print("InstrumentSelector.gd: MusicManager не установлен (null).")

func _ready():
	print("InstrumentSelector.gd: _ready вызван")
	
	var background = $Background
	if background and background is ColorRect:
		background.color = Color(0, 0, 0, 180.0 / 255.0)
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE 

	var back_button = $Container/BackButton
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
		print("InstrumentSelector.gd: Подключён сигнал BackButton")

	var percussion_button = $Container/Content/PercussionButton
	if percussion_button:
		percussion_button.pressed.connect(_on_percussion_pressed)
		print("InstrumentSelector.gd: Подключён сигнал PercussionButton")
	else:
		printerr("InstrumentSelector.gd: Кнопка PercussionButton не найдена в сцене!")

	show()

func _on_percussion_pressed():
	print("InstrumentSelector.gd: Нажата кнопка Перкуссия!")
	if music_manager and music_manager.has_method("play_select_sound"):
		music_manager.play_select_sound()
		print("InstrumentSelector.gd: Воспроизведен звук select")
	
	emit_signal("instrument_selected", "drums")
	emit_signal("selector_closed")

func _on_close_pressed():
	print("InstrumentSelector.gd: Нажата кнопка Закрыть")
	if music_manager and music_manager.has_method("play_cancel_sound"):
		music_manager.play_cancel_sound()
	emit_signal("selector_closed")

func _on_back_button_pressed():
	print("InstrumentSelector.gd: Нажата кнопка Назад")
	if music_manager and music_manager.has_method("play_cancel_sound"):
		music_manager.play_cancel_sound()
	emit_signal("selector_closed")

func _input(event: InputEvent):
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		print("InstrumentSelector.gd: Нажат Escape")
		if music_manager and music_manager.has_method("play_cancel_sound"):
			music_manager.play_cancel_sound()
		_on_back_button_pressed()
