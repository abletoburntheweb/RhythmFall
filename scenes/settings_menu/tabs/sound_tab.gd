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
@onready var timing_offset_value_label: Label = $ContentVBox/TimingOffsetValueLabel
@onready var start_calibration_button: Button = $ContentVBox/StartCalibrationButton
@onready var calibration_status_label: Label = $ContentVBox/CalibrationStatusLabel
@onready var reset_calibration_confirm_dialog: ConfirmationDialog = $ResetCalibrationConfirmDialog

var _last_test_sound_time: float = 0.0
const TEST_SOUND_COOLDOWN: float = 0.2 

var _is_calibrating: bool = false
var _calibration_bpm: float = 120.0
var _beat_interval: float = 0.5
var _calibration_timer: Timer
var _beat_index: int = 0
var _metronome_start_time: float = 0.0
var _taps_needed: int = 10
var _taps_remaining: int = 0
var _tap_offsets_ms: Array = []
var _lane0_scancode: int = KEY_A

func setup_ui_and_manager(screen = null): 
	game_screen = screen
	_setup_ui()
	_apply_initial_volumes()

func _setup_ui():
	menu_music_volume_slider.set_value_no_signal(SettingsManager.get_menu_music_volume())
	music_volume_slider.set_value_no_signal(SettingsManager.get_music_volume())
	sfx_volume_slider.set_value_no_signal(SettingsManager.get_effects_volume())
	hit_sounds_volume_slider.set_value_no_signal(SettingsManager.get_hit_sounds_volume())
	metronome_volume_slider.set_value_no_signal(SettingsManager.get_metronome_volume())
	preview_volume_slider.set_value_no_signal(SettingsManager.get_preview_volume())
	_update_timing_offset_label()
	_update_lane0_scancode()
	_init_calibration_timer()

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

func _ready():
	set_process_input(true)
	set_process_unhandled_input(true)
	_beat_interval = 60.0 / _calibration_bpm
	_update_timing_offset_label()
	_update_lane0_scancode()
	_init_calibration_timer()

func _init_calibration_timer():
	if _calibration_timer and is_instance_valid(_calibration_timer):
		return
	_calibration_timer = Timer.new()
	_calibration_timer.one_shot = false
	_calibration_timer.wait_time = _beat_interval
	_calibration_timer.timeout.connect(_on_metronome_tick)
	add_child(_calibration_timer)

func _update_lane0_scancode():
	var km = SettingsManager.get_controls_keymap_scancode()
	_lane0_scancode = km.get("lane_0_key", KEY_A)

func _update_timing_offset_label():
	var ms = 0
	if SettingsManager and SettingsManager.has_method("get_timing_offset_ms"):
		ms = SettingsManager.get_timing_offset_ms()
	timing_offset_value_label.text = "Оффсет: %d мс" % int(ms)

func _on_start_calibration_pressed():
	if _is_calibrating:
		_stop_calibration()
		return
	_start_calibration()

func _start_calibration():
	_is_calibrating = true
	_tap_offsets_ms.clear()
	_taps_remaining = _taps_needed
	calibration_status_label.visible = true
	_update_calibration_status_text()
	_beat_index = 0
	_metronome_start_time = Time.get_ticks_msec() / 1000.0
	_calibration_timer.wait_time = _beat_interval
	_calibration_timer.start()
	_on_metronome_tick()
	start_calibration_button.text = "Остановить калибровку"
	start_calibration_button.release_focus()
	start_calibration_button.focus_mode = Control.FOCUS_NONE

	MusicManager.set_metronome_volume(SettingsManager.get_metronome_volume())
	if MusicManager.has_method("pause_music"):
		MusicManager.pause_music()

func _stop_calibration():
	_is_calibrating = false
	if _calibration_timer:
		_calibration_timer.stop()
	calibration_status_label.visible = false
	start_calibration_button.text = "Калибровка аудио"
	start_calibration_button.focus_mode = Control.FOCUS_ALL
	if MusicManager.has_method("resume_music"):
		MusicManager.resume_music()

func _finish_calibration():
	_is_calibrating = false
	if _calibration_timer:
		_calibration_timer.stop()
	calibration_status_label.visible = false
	start_calibration_button.text = "Калибровка аудио"
	start_calibration_button.focus_mode = Control.FOCUS_ALL
	if _tap_offsets_ms.size() > 0:
		_tap_offsets_ms.sort()
		var trimmed = _tap_offsets_ms.duplicate()
		if _tap_offsets_ms.size() >= 6:
			trimmed = _tap_offsets_ms.slice(1, _tap_offsets_ms.size() - 2)
		var sum := 0.0
		for v in trimmed:
			sum += float(v)
		var avg := sum / float(max(1, trimmed.size()))
		var ms := int(clamp(avg, -200.0, 200.0))
		if SettingsManager and SettingsManager.has_method("set_timing_offset_ms"):
			SettingsManager.set_timing_offset_ms(ms)
			SettingsManager.save_settings()
		_update_timing_offset_label()
	if MusicManager.has_method("resume_music"):
		MusicManager.resume_music()

func _on_metronome_tick():
	var strong := (_beat_index % 4) == 0
	MusicManager.play_metronome_sound(strong)
	_beat_index += 1


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

func _input(event):
	if not _is_calibrating:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_stop_calibration()
			if get_viewport():
				get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if get_viewport():
				get_viewport().set_input_as_handled()
			return
		if event.keycode != _lane0_scancode:
			return
		var now := Time.get_ticks_msec() / 1000.0
		var rel := (now - _metronome_start_time) / _beat_interval
		var nearest_index := int(round(rel))
		var expected := _metronome_start_time + float(nearest_index) * _beat_interval
		var offset_sec := now - expected
		var offset_ms := offset_sec * 1000.0
		_tap_offsets_ms.append(offset_ms)
		_taps_remaining = max(0, _taps_remaining - 1)
		_update_calibration_status_text()
		if _taps_remaining <= 0:
			_finish_calibration()

func refresh_ui():
	_setup_ui()
	_apply_initial_volumes()

func _update_calibration_status_text():
	var key_text := ""
	if SettingsManager and SettingsManager.has_method("get_key_text_for_lane"):
		key_text = SettingsManager.get_key_text_for_lane(0)
	else:
		key_text = str(_lane0_scancode)
	calibration_status_label.text = "Осталось %d нажатий\nНажимайте %s в такт метронома\nEsc — выйти из калибровки" % [_taps_remaining, key_text]

func _on_reset_calibration_pressed():
	if reset_calibration_confirm_dialog:
		reset_calibration_confirm_dialog.popup_centered()

func _confirm_reset_calibration():
	if _is_calibrating:
		_stop_calibration()
	if SettingsManager and SettingsManager.has_method("set_timing_offset_ms"):
		SettingsManager.set_timing_offset_ms(0)
		SettingsManager.save_settings()
	_update_timing_offset_label()
