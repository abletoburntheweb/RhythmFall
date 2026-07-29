# scenes/settings_menu/tabs/sound_tab.gd
extends Control

signal settings_changed

const _OptionButtonPopupUtils = preload("res://logic/ui/option_button_popup_utils.gd")
const _SettingsDialogUtils = preload("res://logic/ui/settings_dialog_utils.gd")
const _Overlay = preload("res://logic/ui/app_overlay_helpers.gd")
const _SpotlightTutorialScene = preload("res://ui/spotlight_tutorial.tscn")
const _SettingsSectionUi = preload("res://logic/ui/settings_section_ui.gd")
const _SliderScrollUtils = preload("res://logic/ui/slider_scroll_utils.gd")

var game_screen = null

const _VP := "ScrollWrap/CenterWrap/ContentVBox/AudioTopRow/VolumePanel/VolumePanelMargin/VolumeInner"
const _SLIDERS := "%s/VolumeSlidersColumn" % _VP
const _OPTS := "ScrollWrap/CenterWrap/ContentVBox/AudioTopRow/OptionsColumn"
const _PREVIEW := "%s/PreviewPanel/PreviewPanelMargin/PreviewRows/PreviewBlock" % _OPTS
const _CAL := "ScrollWrap/CenterWrap/ContentVBox/CalibrationPanel/CalibrationPanelMargin/CalibrationInner"
const _ACTIONS := "%s/CalibrationColumns/ActionsCard/ActionsCardMargin/ActionsCardVBox" % _CAL

@onready var music_volume_slider: HSlider = get_node("%s/MusicVolumeRow/MusicVolumeSlider" % _SLIDERS)
@onready var menu_music_volume_slider: HSlider = get_node("%s/MenuMusicVolumeRow/MenuMusicVolumeSlider" % _SLIDERS)
@onready var sfx_volume_slider: HSlider = get_node("%s/SFXVolumeRow/SFXVolumeSlider" % _SLIDERS)
@onready var hit_sounds_volume_slider: HSlider = get_node("%s/HitSoundsVolumeRow/HitSoundsVolumeSlider" % _SLIDERS)
@onready var metronome_volume_slider: HSlider = get_node("%s/MetronomeVolumeRow/MetronomeVolumeSlider" % _SLIDERS)
@onready var preview_volume_slider: HSlider = get_node("%s/PreviewVolumeRow/PreviewVolumeSlider" % _SLIDERS)
@onready var music_volume_label: Label = get_node("%s/MusicVolumeRow/MusicVolumeLabel" % _SLIDERS)
@onready var menu_music_volume_label: Label = get_node("%s/MenuMusicVolumeRow/MenuMusicVolumeLabel" % _SLIDERS)
@onready var sfx_volume_label: Label = get_node("%s/SFXVolumeRow/SFXVolumeLabel" % _SLIDERS)
@onready var hit_sounds_volume_label: Label = get_node("%s/HitSoundsVolumeRow/HitSoundsVolumeLabel" % _SLIDERS)
@onready var metronome_volume_label: Label = get_node("%s/MetronomeVolumeRow/MetronomeVolumeLabel" % _SLIDERS)
@onready var preview_volume_label: Label = get_node("%s/PreviewVolumeRow/PreviewVolumeLabel" % _SLIDERS)
@onready var music_volume_percent: Label = get_node("%s/MusicVolumeRow/MusicVolumePercent" % _SLIDERS)
@onready var menu_music_volume_percent: Label = get_node("%s/MenuMusicVolumeRow/MenuMusicVolumePercent" % _SLIDERS)
@onready var sfx_volume_percent: Label = get_node("%s/SFXVolumeRow/SFXVolumePercent" % _SLIDERS)
@onready var hit_sounds_volume_percent: Label = get_node("%s/HitSoundsVolumeRow/HitSoundsVolumePercent" % _SLIDERS)
@onready var metronome_volume_percent: Label = get_node("%s/MetronomeVolumeRow/MetronomeVolumePercent" % _SLIDERS)
@onready var preview_volume_percent: Label = get_node("%s/PreviewVolumeRow/PreviewVolumePercent" % _SLIDERS)
@onready var preview_mode_option: OptionButton = get_node("%s/PreviewModeOption" % _PREVIEW)
@onready var preview_mode_title_label: Label = get_node("%s/PreviewModeTitleLabel" % _PREVIEW)
@onready var preview_mode_desc_label: Label = get_node("%s/PreviewModeDescLabel" % _PREVIEW)
@onready var output_hint_label: Label = get_node("%s/OutputHintLabel" % _CAL)
@onready var timing_offset_value_label: Label = get_node("%s/CalibrationColumns/OffsetCard/OffsetCardMargin/OffsetCardVBox/TimingOffsetValueLabel" % _CAL)
@onready var output_latency_label: Label = get_node("%s/CalibrationColumns/LatencyCard/LatencyCardMargin/LatencyCardVBox/OutputLatencyLabel" % _CAL)
@onready var offset_title_label: Label = get_node("%s/CalibrationColumns/OffsetCard/OffsetCardMargin/OffsetCardVBox/OffsetTitleLabel" % _CAL)
@onready var offset_hint_label: Label = get_node("%s/CalibrationColumns/OffsetCard/OffsetCardMargin/OffsetCardVBox/OffsetHintLabel" % _CAL)
@onready var latency_title_label: Label = get_node("%s/CalibrationColumns/LatencyCard/LatencyCardMargin/LatencyCardVBox/LatencyTitleLabel" % _CAL)
@onready var latency_hint_label: Label = get_node("%s/CalibrationColumns/LatencyCard/LatencyCardMargin/LatencyCardVBox/LatencyHintLabel" % _CAL)
@onready var actions_title_label: Label = get_node("%s/ActionsTitleLabel" % _ACTIONS)
@onready var start_calibration_button: Button = get_node("%s/CalibrationButtonsRow/StartCalibrationButton" % _ACTIONS)
@onready var calibration_status_label: Label = get_node("%s/CalibrationStatusLabel" % _ACTIONS)
@onready var _confirm_overlay: AppConfirmOverlay = %ConfirmOverlay
@onready var volume_header: Label = get_node("%s/VolumeHeader" % _VP)
@onready var volume_hint: Label = get_node("%s/VolumeHint" % _VP)
@onready var calibration_header: Label = get_node("%s/CalibrationHeader" % _CAL)
@onready var calibration_hint: Label = get_node("%s/CalibrationHint" % _CAL)
@onready var reset_calibration_button: Button = get_node("%s/CalibrationButtonsRow/ResetCalibrationButton" % _ACTIONS)

var _last_test_sound_time: float = 0.0
const TEST_SOUND_COOLDOWN: float = 0.2

var _is_calibrating: bool = false
var _calibration_help_btn: Button = null
var _calibration_bpm: float = 120.0
var _beat_interval: float = 0.5
var _calibration_timer: Timer
var _beat_index: int = 0
var _metronome_start_time: float = 0.0
const CALIBRATION_TOTAL_TAPS: int = 20
const CALIBRATION_WARMUP_DISCARD: int = 4
var _taps_needed: int = CALIBRATION_TOTAL_TAPS
var _taps_remaining: int = 0
var _tap_offsets_ms: Array = []
var _lane0_scancode: int = KEY_A
var _spotlight_tutorial: CanvasLayer = null


func setup_ui_and_manager(screen = null) -> void:
	game_screen = screen
	_setup_ui()
	_apply_initial_volumes()


func _setup_ui() -> void:
	menu_music_volume_slider.set_value_no_signal(SettingsManager.get_menu_music_volume())
	music_volume_slider.set_value_no_signal(SettingsManager.get_music_volume())
	sfx_volume_slider.set_value_no_signal(SettingsManager.get_effects_volume())
	hit_sounds_volume_slider.set_value_no_signal(SettingsManager.get_hit_sounds_volume())
	metronome_volume_slider.set_value_no_signal(SettingsManager.get_metronome_volume())
	preview_volume_slider.set_value_no_signal(SettingsManager.get_preview_volume())
	_setup_preview_mode_option()
	_update_volume_labels()
	call_deferred("_align_volume_rows")
	_update_timing_offset_label()
	_update_output_latency_label()
	_update_lane0_scancode()
	_init_calibration_timer()
	_sync_calibration_buttons()
	_apply_volume_label_tooltips()
	_ensure_calibration_help_icon()


func _notification(what: int) -> void:
	if what != NOTIFICATION_VISIBILITY_CHANGED:
		return
	if not is_visible_in_tree():
		return
	call_deferred("_maybe_show_calibration_tutorial")


func _maybe_show_calibration_tutorial(force: bool = false) -> void:
	if not SettingsManager or not SettingsManager.has_method("get_tutorial_calibration_done"):
		return
	if not force and SettingsManager.get_tutorial_calibration_done():
		return
	if not is_visible_in_tree():
		return
	if _spotlight_tutorial == null:
		_spotlight_tutorial = _SpotlightTutorialScene.instantiate() as CanvasLayer
		if _spotlight_tutorial == null:
			return
		add_child(_spotlight_tutorial)
		if not _spotlight_tutorial.finished.is_connected(_on_calibration_tutorial_closed):
			_spotlight_tutorial.finished.connect(_on_calibration_tutorial_closed)
		if not _spotlight_tutorial.skipped.is_connected(_on_calibration_tutorial_closed):
			_spotlight_tutorial.skipped.connect(_on_calibration_tutorial_closed)
	var offset_card := get_node_or_null("%s/CalibrationColumns/OffsetCard" % _CAL) as Control
	var steps: Array = [
		{
			"title_key": "TUTORIAL_CAL_1_TITLE",
			"body_key": "TUTORIAL_CAL_1_BODY",
			"target": offset_card,
		},
		{
			"title_key": "TUTORIAL_CAL_2_TITLE",
			"body_key": "TUTORIAL_CAL_2_BODY",
			"target": start_calibration_button,
		},
	]
	if _spotlight_tutorial.has_method("start"):
		_spotlight_tutorial.start(steps)


func _on_calibration_tutorial_closed() -> void:
	if SettingsManager and SettingsManager.has_method("set_tutorial_calibration_done"):
		SettingsManager.set_tutorial_calibration_done(true)


func debug_show_tutorial() -> void:
	_maybe_show_calibration_tutorial(true)


func _apply_initial_volumes() -> void:
	call_deferred("_sync_volumes_to_audio")


func _ready() -> void:
	add_to_group("locale_refresh")
	set_process_input(true)
	set_process_unhandled_input(true)
	_beat_interval = 60.0 / _calibration_bpm
	_init_calibration_timer()
	call_deferred("_align_volume_rows")
	call_deferred("_layout_wide_sound_panels")
	call_deferred("_apply_dialog_styles")
	call_deferred("_disable_slider_wheel_scroll")


func _disable_slider_wheel_scroll() -> void:
	_SliderScrollUtils.disable_wheel_under(self)


func _apply_dialog_styles() -> void:
	_SettingsDialogUtils.apply_to_descendants(self)


func _layout_wide_sound_panels() -> void:
	var content: VBoxContainer = get_node_or_null("ScrollWrap/CenterWrap/ContentVBox")
	var audio_top: HBoxContainer = get_node_or_null("ScrollWrap/CenterWrap/ContentVBox/AudioTopRow")
	if content == null or audio_top == null or audio_top.get_meta("sound_layout_wide", false):
		return
	var volume_panel := audio_top.get_node_or_null("VolumePanel")
	var options_col := audio_top.get_node_or_null("OptionsColumn")
	if volume_panel == null or options_col == null:
		return

	var parent := audio_top.get_parent()
	var insert_idx := audio_top.get_index()
	var top_vbox := VBoxContainer.new()
	top_vbox.name = "AudioTopRow"
	top_vbox.add_theme_constant_override("separation", 16)
	top_vbox.set_meta("sound_layout_wide", true)

	parent.remove_child(audio_top)
	parent.add_child(top_vbox)
	parent.move_child(top_vbox, insert_idx)

	audio_top.remove_child(volume_panel)
	audio_top.remove_child(options_col)
	top_vbox.add_child(volume_panel)
	volume_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_panel.size_flags_stretch_ratio = 1.0

	var options_row := HBoxContainer.new()
	options_row.name = "OptionsRow"
	options_row.add_theme_constant_override("separation", 16)
	top_vbox.add_child(options_row)

	while options_col.get_child_count() > 0:
		var child := options_col.get_child(0)
		options_col.remove_child(child)
		options_row.add_child(child)
		child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		child.size_flags_stretch_ratio = 1.0

	options_col.queue_free()
	audio_top.queue_free()
	content.custom_minimum_size.x = maxf(content.custom_minimum_size.x, 920.0)
	call_deferred("_align_volume_rows")



func _init_calibration_timer() -> void:
	if _calibration_timer and is_instance_valid(_calibration_timer):
		return
	_calibration_timer = Timer.new()
	_calibration_timer.one_shot = false
	_calibration_timer.wait_time = _beat_interval
	_calibration_timer.timeout.connect(_on_metronome_tick)
	add_child(_calibration_timer)


func _update_lane0_scancode() -> void:
	var km = SettingsManager.get_controls_keymap_scancode()
	_lane0_scancode = km.get("lane_0_key", KEY_A)


func _update_timing_offset_label() -> void:
	var ms := 0
	if SettingsManager and SettingsManager.has_method("get_timing_offset_ms"):
		ms = SettingsManager.get_timing_offset_ms()
	var sign := "+" if ms > 0 else ""
	timing_offset_value_label.text = "%s%d ms" % [sign, ms] if ms != 0 else "0 ms"


func _update_output_latency_label() -> void:
	var ms := int(round(AudioServer.get_output_latency() * 1000.0))
	output_latency_label.text = "%d ms" % ms


func _on_start_calibration_pressed() -> void:
	if _is_calibrating:
		return
	_start_calibration()


func _start_calibration() -> void:
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
	_sync_calibration_buttons()
	MusicManager.set_metronome_volume(SettingsManager.get_metronome_volume())
	if MusicManager.has_method("pause_music"):
		MusicManager.pause_music()


func _stop_calibration() -> void:
	_is_calibrating = false
	if _calibration_timer:
		_calibration_timer.stop()
	calibration_status_label.visible = false
	_sync_calibration_buttons()
	if MusicManager.has_method("resume_music"):
		MusicManager.resume_music()


func _finish_calibration() -> void:
	_is_calibrating = false
	if _calibration_timer:
		_calibration_timer.stop()
	calibration_status_label.visible = false
	_sync_calibration_buttons()
	if _tap_offsets_ms.size() > 0:
		var samples: Array = _tap_offsets_ms.duplicate()
		if samples.size() > CALIBRATION_WARMUP_DISCARD:
			samples = samples.slice(CALIBRATION_WARMUP_DISCARD, samples.size())
		samples.sort()
		var trimmed: Array = samples
		var n := samples.size()
		if n >= 8:
			var cut := maxi(1, int(round(n * 0.15)))
			trimmed = samples.slice(cut, n - cut)
		elif n >= 4:
			trimmed = samples.slice(1, n - 1)
		if trimmed.is_empty():
			trimmed = samples
		trimmed.sort()
		var tsize := trimmed.size()
		if tsize > 0:
			var ms_float: float
			if tsize % 2 == 1:
				ms_float = float(trimmed[tsize / 2])
			else:
				ms_float = (float(trimmed[tsize / 2 - 1]) + float(trimmed[tsize / 2])) / 2.0
			var ms := int(clamp(round(ms_float), -500.0, 500.0))
			if SettingsManager and SettingsManager.has_method("set_timing_offset_ms"):
				SettingsManager.set_timing_offset_ms(ms)
			_update_timing_offset_label()
			emit_signal("settings_changed")
	if MusicManager.has_method("resume_music"):
		MusicManager.resume_music()


func _sync_calibration_buttons() -> void:
	if start_calibration_button:
		start_calibration_button.disabled = _is_calibrating


func _on_metronome_tick() -> void:
	var strong := (_beat_index % 4) == 0
	MusicManager.play_metronome_sound(strong)
	_beat_index += 1


func _can_play_test_sound() -> bool:
	var now = Time.get_ticks_msec() / 1000.0
	if now - _last_test_sound_time > TEST_SOUND_COOLDOWN:
		_last_test_sound_time = now
		return true
	return false


func _play_test_sfx_sound(_value_unused = null) -> void:
	if _can_play_test_sound():
		MusicManager.play_select_sound()


func _play_test_hit_sound(_value_unused = null) -> void:
	if _can_play_test_sound():
		MusicManager.play_hit_sound(true)


func _play_test_metronome_sound(_value_unused = null) -> void:
	if _can_play_test_sound():
		MusicManager.play_metronome_sound(false)


func _sync_volumes_to_audio() -> void:
	if MusicManager == null:
		return
	MusicManager.set_menu_music_volume(menu_music_volume_slider.value)
	MusicManager.set_music_volume(music_volume_slider.value)
	MusicManager.set_sfx_volume(sfx_volume_slider.value)
	MusicManager.set_hit_sounds_volume(hit_sounds_volume_slider.value)
	MusicManager.set_metronome_volume(metronome_volume_slider.value)
	if game_screen and game_screen.has_method("set_preview_volume"):
		game_screen.set_preview_volume(preview_volume_slider.value)


func _on_music_volume_changed(value: float) -> void:
	SettingsManager.set_music_volume(int(value))
	MusicManager.set_music_volume(value)
	_update_volume_labels()
	emit_signal("settings_changed")


func _on_menu_music_volume_changed(value: float) -> void:
	SettingsManager.set_menu_music_volume(int(value))
	MusicManager.set_menu_music_volume(value)
	_update_volume_labels()
	emit_signal("settings_changed")


func _on_sfx_volume_changed(value: float) -> void:
	SettingsManager.set_effects_volume(int(value))
	MusicManager.set_sfx_volume(value)
	_update_volume_labels()
	emit_signal("settings_changed")


func _on_hit_sounds_volume_changed(value: float) -> void:
	SettingsManager.set_hit_sounds_volume(int(value))
	MusicManager.set_hit_sounds_volume(value)
	_update_volume_labels()
	emit_signal("settings_changed")


func _on_metronome_volume_changed(value: float) -> void:
	SettingsManager.set_metronome_volume(int(value))
	MusicManager.set_metronome_volume(value)
	_update_volume_labels()
	emit_signal("settings_changed")


func _setup_preview_mode_option() -> void:
	if preview_mode_option == null:
		return
	_OptionButtonPopupUtils.apply_popup_font_size(preview_mode_option, 24)
	preview_mode_option.clear()
	preview_mode_option.add_item(tr("SOUND_PREVIEW_MODE_SNIPPET"), 0)
	preview_mode_option.add_item(tr("SOUND_PREVIEW_MODE_FULL"), 1)
	var mode := SettingsManager.get_song_preview_mode()
	preview_mode_option.select(1 if mode == "full" else 0)


func _on_preview_mode_selected(index: int) -> void:
	var mode := "full" if index == 1 else "snippet"
	SettingsManager.set_song_preview_mode(mode)
	emit_signal("settings_changed")


func _on_preview_volume_changed(value: float) -> void:
	SettingsManager.set_preview_volume(int(value))
	_update_volume_labels()
	emit_signal("settings_changed")
	if game_screen and game_screen.has_method("set_preview_volume"):
		game_screen.set_preview_volume(value)



func _update_volume_labels() -> void:
	var rows := [
		[music_volume_label, music_volume_percent, music_volume_slider, "SOUND_VOL_MUSIC"],
		[menu_music_volume_label, menu_music_volume_percent, menu_music_volume_slider, "SOUND_VOL_MENU"],
		[sfx_volume_label, sfx_volume_percent, sfx_volume_slider, "SOUND_VOL_SFX"],
		[hit_sounds_volume_label, hit_sounds_volume_percent, hit_sounds_volume_slider, "SOUND_VOL_HIT"],
		[metronome_volume_label, metronome_volume_percent, metronome_volume_slider, "SOUND_VOL_METRONOME"],
		[preview_volume_label, preview_volume_percent, preview_volume_slider, "SOUND_VOL_PREVIEW"],
	]
	for row in rows:
		if row[0]:
			row[0].text = tr(row[3])
		if row[1] and row[2]:
			row[1].text = "%d%%" % int(round(row[2].value))


func _align_volume_rows() -> void:
	const LABEL_W := 220.0
	const PCT_W := 48.0
	const NEUTRAL_PCT := Color(0.62, 0.7, 0.82, 0.95)
	for row in [
		"%s/MusicVolumeRow" % _SLIDERS,
		"%s/MenuMusicVolumeRow" % _SLIDERS,
		"%s/SFXVolumeRow" % _SLIDERS,
		"%s/HitSoundsVolumeRow" % _SLIDERS,
		"%s/MetronomeVolumeRow" % _SLIDERS,
		"%s/PreviewVolumeRow" % _SLIDERS,
	]:
		var hbox: HBoxContainer = get_node_or_null(row)
		if hbox == null:
			continue
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for child in hbox.get_children():
			if child is Label and str(child.name).ends_with("Label"):
				child.custom_minimum_size.x = LABEL_W
				child.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			elif child is HSlider:
				child.custom_minimum_size = Vector2(0, 28)
				child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				child.size_flags_stretch_ratio = 1.0
			elif child is Label and str(child.name).ends_with("Percent"):
				child.custom_minimum_size.x = PCT_W
				child.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				child.size_flags_horizontal = Control.SIZE_SHRINK_END
				child.add_theme_color_override("font_color", NEUTRAL_PCT)


func _input(event: InputEvent) -> void:
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
		var expected := _metronome_start_time + float(nearest_index) * _beat_interval + AudioServer.get_output_latency()
		var offset_sec := now - expected
		var offset_ms := offset_sec * 1000.0
		_tap_offsets_ms.append(offset_ms)
		_taps_remaining = max(0, _taps_remaining - 1)
		_update_calibration_status_text()
		if _taps_remaining <= 0:
			_finish_calibration()


func refresh_ui() -> void:
	_setup_ui()
	_apply_initial_volumes()


func _update_calibration_status_text() -> void:
	var key_text := ""
	if SettingsManager and SettingsManager.has_method("get_key_text_for_lane"):
		key_text = SettingsManager.get_key_text_for_lane(0)
	else:
		key_text = str(_lane0_scancode)
	calibration_status_label.text = tr("SOUND_CALIB_STATUS") % [_taps_remaining, key_text]


func _set_tooltip(control: Control, key: String) -> void:
	if control == null:
		return
	control.tooltip_text = tr(key)
	if control is Label:
		control.mouse_filter = Control.MOUSE_FILTER_STOP


func _apply_volume_label_tooltips() -> void:
	_set_tooltip(music_volume_label, "SOUND_VOL_MUSIC_TOOLTIP")
	_set_tooltip(menu_music_volume_label, "SOUND_VOL_MENU_TOOLTIP")
	_set_tooltip(sfx_volume_label, "SOUND_VOL_SFX_TOOLTIP")
	_set_tooltip(hit_sounds_volume_label, "SOUND_VOL_HIT_TOOLTIP")
	_set_tooltip(metronome_volume_label, "SOUND_VOL_METRONOME_TOOLTIP")
	_set_tooltip(preview_volume_label, "SOUND_VOL_PREVIEW_TOOLTIP")


func apply_locale() -> void:
	if volume_header:
		volume_header.text = tr("SOUND_VOLUME")
	if volume_hint:
		volume_hint.text = tr("SETTINGS_VOLUME_SECTION_HINT")
	if calibration_header:
		calibration_header.text = tr("SOUND_CALIBRATION")
		_set_tooltip(calibration_header, "SOUND_CALIBRATION_TOOLTIP")
	if _calibration_help_btn:
		_calibration_help_btn.tooltip_text = tr("HELP_LINK_AUDIO_TIMING")
	if calibration_hint:
		calibration_hint.text = tr("SETTINGS_CALIBRATION_SECTION_HINT")
	if preview_mode_title_label:
		preview_mode_title_label.text = tr("SOUND_PREVIEW_MODE_LABEL")
		_set_tooltip(preview_mode_title_label, "SOUND_PREVIEW_MODE_TOOLTIP")
	if preview_mode_option:
		_set_tooltip(preview_mode_option, "SOUND_PREVIEW_MODE_TOOLTIP")
	if preview_mode_desc_label:
		preview_mode_desc_label.text = tr("SOUND_PREVIEW_DESC")
	if output_hint_label:
		output_hint_label.text = tr("SOUND_HINT_OUTPUT_LATENCY")
	if offset_title_label:
		offset_title_label.text = tr("SOUND_OFFSET_TITLE")
	if offset_hint_label:
		offset_hint_label.text = tr("SOUND_OFFSET_HINT")
	if latency_title_label:
		latency_title_label.text = tr("SOUND_LATENCY_TITLE")
	if latency_hint_label:
		latency_hint_label.text = tr("SOUND_LATENCY_HINT")
	if actions_title_label:
		actions_title_label.text = tr("SOUND_CALIB_CARD_TITLE")
	_apply_volume_label_tooltips()
	if reset_calibration_button:
		reset_calibration_button.text = tr("SOUND_RESET_CALIBRATION")
	if start_calibration_button:
		start_calibration_button.text = tr("SOUND_START_CALIBRATION")
	_update_volume_labels()
	_setup_preview_mode_option()
	_update_timing_offset_label()
	_update_output_latency_label()
	call_deferred("_align_volume_rows")
	if _is_calibrating:
		_update_calibration_status_text()
	_apply_dialog_styles()


func _ensure_calibration_help_icon() -> void:
	if calibration_header == null:
		return
	_calibration_help_btn = _SettingsSectionUi.attach_help_icon_beside_label(
		calibration_header,
		tr("HELP_LINK_AUDIO_TIMING"),
		_on_calibration_help_pressed,
		false
	)


func _on_calibration_help_pressed() -> void:
	var node: Node = self
	while node:
		if node.has_method("open_help_item"):
			node.open_help_item("audio_timing")
			return
		if node.has_method("get_transitions"):
			var trans = node.get_transitions()
			if trans and trans.has_method("open_help_item"):
				trans.open_help_item("audio_timing")
				return
		node = node.get_parent()


func _on_reset_calibration_pressed() -> void:
	if not await _Overlay.ask(
		_confirm_overlay,
		tr("DLG_RESET_CALIB_TEXT"),
		"danger",
		"",
		tr("BTN_RESET"),
	):
		return
	if _is_calibrating:
		_stop_calibration()
	if SettingsManager and SettingsManager.has_method("set_timing_offset_ms"):
		SettingsManager.set_timing_offset_ms(0)
	_update_timing_offset_label()
	emit_signal("settings_changed")
