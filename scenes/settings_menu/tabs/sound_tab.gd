# scenes/settings_menu/tabs/sound_tab.gd
extends Control

signal settings_changed 

var game_screen = null 

@onready var music_volume_slider: HSlider = $ContentVBox/MusicVolumeSlider
@onready var menu_music_volume_slider: HSlider = $ContentVBox/MenuMusicVolumeSlider
@onready var sfx_volume_slider: HSlider = $ContentVBox/SFXVolumeSlider
@onready var hit_sounds_volume_slider: HSlider = $ContentVBox/HitSoundsVolumeSlider
@onready var metronome_volume_slider: HSlider = $ContentVBox/MetronomeVolumeSlider
@onready var preview_volume_slider: HSlider = $ContentVBox/PreviewVolumeSlider

var _last_test_sound_time: float = 0.0
const TEST_SOUND_COOLDOWN: float = 0.2 

func _ready():
	pass

func setup_ui_and_manager(screen = null): 
	game_screen = screen
	_setup_ui()
	_connect_signals()
	_apply_initial_volumes()

func _setup_ui():
	menu_music_volume_slider.set_value_no_signal(SettingsManager.get_menu_music_volume())
	music_volume_slider.set_value_no_signal(SettingsManager.get_music_volume())
	sfx_volume_slider.set_value_no_signal(SettingsManager.get_effects_volume())
	hit_sounds_volume_slider.set_value_no_signal(SettingsManager.get_hit_sounds_volume())
	metronome_volume_slider.set_value_no_signal(SettingsManager.get_metronome_volume())
	preview_volume_slider.set_value_no_signal(SettingsManager.get_preview_volume())

func _apply_initial_volumes():

	var music_vol = music_volume_slider.value
	var menu_music_vol = menu_music_volume_slider.value
	var sfx_vol = sfx_volume_slider.value
	var hit_vol = hit_sounds_volume_slider.value
	var metro_vol = metronome_volume_slider.value
	var preview_vol = preview_volume_slider.value


	call_deferred("_on_menu_music_volume_changed", menu_music_vol)
	call_deferred("_on_music_volume_changed", music_vol)
	call_deferred("_on_sfx_volume_changed", sfx_vol)
	call_deferred("_on_hit_sounds_volume_changed", hit_vol)
	call_deferred("_on_metronome_volume_changed", metro_vol)
	call_deferred("_on_preview_volume_changed", preview_vol)


func _connect_signals():
	if music_volume_slider:
		music_volume_slider.value_changed.connect(_on_music_volume_changed)
	if menu_music_volume_slider:
		menu_music_volume_slider.value_changed.connect(_on_menu_music_volume_changed)
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
	if _can_play_test_sound():
		MusicManager.play_select_sound() 

func _play_test_hit_sound(_value_unused = null):
	if _can_play_test_sound():
		MusicManager.play_hit_sound(true)  

func _play_test_metronome_sound(_value_unused = null):
	if _can_play_test_sound():
		MusicManager.play_metronome_sound(false) 

func _on_music_volume_changed(value: float):
	SettingsManager.set_music_volume(int(value))
	MusicManager.set_music_volume(value)  
	emit_signal("settings_changed") 

func _on_menu_music_volume_changed(value: float):
	SettingsManager.set_menu_music_volume(int(value))
	MusicManager.set_menu_music_volume(value)
	emit_signal("settings_changed")

func _on_sfx_volume_changed(value: float):
	SettingsManager.set_effects_volume(int(value))
	MusicManager.set_sfx_volume(value) 
	emit_signal("settings_changed")

func _on_hit_sounds_volume_changed(value: float):
	SettingsManager.set_hit_sounds_volume(int(value))
	MusicManager.set_hit_sounds_volume(value)  
	emit_signal("settings_changed")

func _on_metronome_volume_changed(value: float):
	SettingsManager.set_metronome_volume(int(value))
	MusicManager.set_metronome_volume(value)  
	emit_signal("settings_changed")

func _on_preview_volume_changed(value: float):
	SettingsManager.set_preview_volume(int(value))
	emit_signal("settings_changed")
	if game_screen and game_screen.has_method("set_preview_volume"):
		game_screen.set_preview_volume(value)

func refresh_ui():
	_setup_ui()
	_apply_initial_volumes()
