# scenes/settings_menu/tabs/sound_tab.gd
extends Control

signal settings_changed 

var settings_manager: SettingsManager = null
var music_manager = null 
var game_screen = null 

@onready var music_volume_slider: HSlider = $ContentVBox/MusicVolumeSlider
@onready var sfx_volume_slider: HSlider = $ContentVBox/SFXVolumeSlider
@onready var hit_sounds_volume_slider: HSlider = $ContentVBox/HitSoundsVolumeSlider
@onready var metronome_volume_slider: HSlider = $ContentVBox/MetronomeVolumeSlider2
@onready var preview_volume_slider: HSlider = $ContentVBox/PreviewVolumeSlider

var _last_test_sound_time: float = 0.0
const TEST_SOUND_COOLDOWN: float = 0.2 

func _ready():
	print("SoundTab.gd: _ready вызван.")

func setup_ui_and_manager(manager: SettingsManager, mm: MusicManager, screen = null): 
	settings_manager = manager
	music_manager = mm
	game_screen = screen
	_setup_ui()
	_connect_signals()
	_apply_initial_volumes()

func _setup_ui():
	if not settings_manager:
		printerr("SoundTab.gd: settings_manager не установлен, невозможно настроить UI.")
		return

	if not music_manager:
		printerr("SoundTab.gd: music_manager не установлен, невозможно настроить UI.")
		return

	print("SoundTab.gd: _setup_ui вызван.")

	music_volume_slider.set_value_no_signal(settings_manager.get_music_volume())
	sfx_volume_slider.set_value_no_signal(settings_manager.get_effects_volume())
	hit_sounds_volume_slider.set_value_no_signal(settings_manager.get_hit_sounds_volume())
	metronome_volume_slider.set_value_no_signal(settings_manager.get_metronome_volume())
	preview_volume_slider.set_value_no_signal(settings_manager.get_preview_volume())

func _apply_initial_volumes():
	if not settings_manager or not music_manager:
		printerr("SoundTab.gd: _apply_initial_volumes: settings_manager или music_manager не установлен!")
		return

	print("SoundTab.gd: _apply_initial_volumes вызван.")

	var music_vol = music_volume_slider.value
	var sfx_vol = sfx_volume_slider.value
	var hit_vol = hit_sounds_volume_slider.value
	var metro_vol = metronome_volume_slider.value
	var preview_vol = preview_volume_slider.value

	print("SoundTab.gd: Применяем начальные значения: music=%.1f, sfx=%.1f, hit=%.1f, metro=%.1f, preview=%.1f" % [music_vol, sfx_vol, hit_vol, metro_vol, preview_vol])

	call_deferred("_on_music_volume_changed", music_vol)
	call_deferred("_on_sfx_volume_changed", sfx_vol)
	call_deferred("_on_hit_sounds_volume_changed", hit_vol)
	call_deferred("_on_metronome_volume_changed", metro_vol)
	call_deferred("_on_preview_volume_changed", preview_vol)

	print("SoundTab.gd: Начальные значения отправлены на применение через call_deferred.")

func _connect_signals():
	if music_volume_slider:
		music_volume_slider.value_changed.connect(_on_music_volume_changed)
	if sfx_volume_slider:
		sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
		sfx_volume_slider.value_changed.connect(_play_test_sfx_sound)
	if hit_sounds_volume_slider:
		hit_sounds_volume_slider.value_changed.connect(_on_hit_sounds_volume_changed)
		hit_sounds_volume_slider.value_changed.connect(_play_test_hit_sound)
	if metronome_volume_slider:
		metronome_volume_slider.value_changed.connect(_on_metronome_volume_changed)
		metronome_volume_slider.value_changed.connect(_play_test_metronome_sound)
	if preview_volume_slider:
		preview_volume_slider.value_changed.connect(_on_preview_volume_changed)

func _can_play_test_sound() -> bool:
	var now = Time.get_ticks_msec() / 1000.0
	if now - _last_test_sound_time > TEST_SOUND_COOLDOWN:
		_last_test_sound_time = now
		return true
	return false

func _play_test_sfx_sound(_value_unused = null):
	if music_manager and _can_play_test_sound():
		music_manager.play_select_sound()
		print("SoundTab.gd: Проигран тестовый SFX звук (select_click).")

func _play_test_hit_sound(_value_unused = null):
	if music_manager and _can_play_test_sound():
		music_manager.play_hit_sound(true)
		print("SoundTab.gd: Проигран тестовый звук удара (kick).")

func _play_test_metronome_sound(_value_unused = null):
	if music_manager and _can_play_test_sound():
		music_manager.play_metronome_sound(false) 
		print("SoundTab.gd: Проигран тестовый звук метронома (weak beat).")

func _on_music_volume_changed(value: float):
	if settings_manager and music_manager:
		settings_manager.set_music_volume(int(value))
		music_manager.set_music_volume(value)
		emit_signal("settings_changed") 
		print("SoundTab.gd: Громкость музыки изменена на %.1f%% (DB: %.2f)" % [value, music_manager.music_player.volume_db if music_manager.music_player else -INF]) 
	else:
		printerr("SoundTab.gd: _on_music_volume_changed: settings_manager или music_manager не установлен!")

func _on_sfx_volume_changed(value: float):
	if settings_manager and music_manager:
		settings_manager.set_effects_volume(int(value))
		music_manager.set_sfx_volume(value)
		emit_signal("settings_changed")
		print("SoundTab.gd: Громкость звуков изменена на %.1f%% (DB: %.2f)" % [value, music_manager.sfx_player.volume_db if music_manager.sfx_player else -INF])
	else:
		printerr("SoundTab.gd: _on_sfx_volume_changed: settings_manager или music_manager не установлен!")

func _on_hit_sounds_volume_changed(value: float):
	if settings_manager and music_manager:
		settings_manager.set_hit_sounds_volume(int(value))
		music_manager.set_hit_sounds_volume(value)
		emit_signal("settings_changed")
		print("SoundTab.gd: Громкость нажатий изменена на %.1f%% (DB: %.2f)" % [value, music_manager.hit_sound_player.volume_db if music_manager.hit_sound_player else -INF])
	else:
		printerr("SoundTab.gd: _on_hit_sounds_volume_changed: settings_manager или music_manager не установлен!")

func _on_metronome_volume_changed(value: float):
	if settings_manager and music_manager:
		settings_manager.set_metronome_volume(int(value))
		music_manager.set_metronome_volume(value)
		emit_signal("settings_changed")
		print("SoundTab.gd: Громкость метронома изменена на %.1f%%" % value) 
	else:
		printerr("SoundTab.gd: _on_metronome_volume_changed: settings_manager или music_manager не установлен!")

func _on_preview_volume_changed(value: float):
	if settings_manager:
		settings_manager.set_preview_volume(int(value))
		emit_signal("settings_changed")
		if game_screen and game_screen.has_method("set_preview_volume"):
			game_screen.set_preview_volume(value)
		print("SoundTab.gd: Громкость предпросмотра изменена на %.1f%%" % value) 
	else:
		printerr("SoundTab.gd: _on_preview_volume_changed: settings_manager не установлен!")


func refresh_ui():
	_setup_ui()
	_apply_initial_volumes()
