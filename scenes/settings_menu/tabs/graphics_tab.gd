# scenes/settings_menu/tabs/graphics_tab.gd
extends Control

signal settings_changed

const _OptionButtonPopupUtils = preload("res://logic/ui/option_button_popup_utils.gd")
const _SpinBoxUtils = preload("res://logic/ui/spin_box_utils.gd")
const _SegmentedOptionUtils = preload("res://logic/ui/segmented_option_utils.gd")
const _DuoMode = preload("res://logic/domain/rhythm/duo_mode.gd")
const _SettingsSectionUi = preload("res://logic/ui/settings_section_ui.gd")
const _SliderScrollUtils = preload("res://logic/ui/slider_scroll_utils.gd")

const _DUO_NOTE_STYLE_IDS: Array[String] = [
	_DuoMode.STYLE_WARM_COOL,
	_DuoMode.STYLE_TINT,
	_DuoMode.STYLE_OUTLINE,
	_DuoMode.STYLE_NONE,
]

var game_engine = null 

const _DISPLAY := "ScrollWrap/CenterWrap/ContentVBox/DisplayPanel/DisplayPanelMargin/DisplayRows"
const _GAMEPLAY := "ScrollWrap/CenterWrap/ContentVBox/GameplayPanel/GameplayPanelMargin/GameplayRows"

@onready var fps_option_button: OptionButton = get_node("%s/FPS/FPSOptionButton" % _DISPLAY)
@onready var graphics_quality_option: OptionButton = get_node("%s/GraphicsQuality/GraphicsQualityOptionButton" % _DISPLAY)
@onready var window_mode_option: OptionButton = get_node("%s/WindowMode/WindowModeOptionButton" % _DISPLAY)
@onready var window_resolution_option: OptionButton = get_node("%s/WindowResolution/WindowResolutionOptionButton" % _DISPLAY)
@onready var scroll_speed_spin: SpinBox = get_node("%s/ScrollSpeed/ScrollSpeedSpinBox" % _GAMEPLAY)
@onready var lane_highlight_brightness_slider: HSlider = get_node("%s/LaneHighlightBrightnessRow/LaneHighlightBrightnessSlider" % _GAMEPLAY)
@onready var lane_highlight_brightness_percent: Label = get_node("%s/LaneHighlightBrightnessRow/LaneHighlightBrightnessPercent" % _GAMEPLAY)
@onready var note_brightness_slider: HSlider = get_node("%s/NoteBrightnessRow/NoteBrightnessSlider" % _GAMEPLAY)
@onready var note_brightness_percent: Label = get_node("%s/NoteBrightnessRow/NoteBrightnessPercent" % _GAMEPLAY)
@onready var playfield_width_header: Label = get_node("%s/PlayfieldWidthHeader" % _GAMEPLAY)
@onready var playfield_width_3_label: Label = get_node("%s/PlayfieldWidth3Row/PlayfieldWidth3Label" % _GAMEPLAY)
@onready var playfield_width_3_slider: HSlider = get_node("%s/PlayfieldWidth3Row/PlayfieldWidth3Slider" % _GAMEPLAY)
@onready var playfield_width_3_percent: Label = get_node("%s/PlayfieldWidth3Row/PlayfieldWidth3Percent" % _GAMEPLAY)
@onready var playfield_width_4_label: Label = get_node("%s/PlayfieldWidth4Row/PlayfieldWidth4Label" % _GAMEPLAY)
@onready var playfield_width_4_slider: HSlider = get_node("%s/PlayfieldWidth4Row/PlayfieldWidth4Slider" % _GAMEPLAY)
@onready var playfield_width_4_percent: Label = get_node("%s/PlayfieldWidth4Row/PlayfieldWidth4Percent" % _GAMEPLAY)
@onready var playfield_width_5_label: Label = get_node("%s/PlayfieldWidth5Row/PlayfieldWidth5Label" % _GAMEPLAY)
@onready var playfield_width_5_slider: HSlider = get_node("%s/PlayfieldWidth5Row/PlayfieldWidth5Slider" % _GAMEPLAY)
@onready var playfield_width_5_percent: Label = get_node("%s/PlayfieldWidth5Row/PlayfieldWidth5Percent" % _GAMEPLAY)
@onready var note_approach_hint_option: OptionButton = get_node("%s/NoteApproachHint/NoteApproachHintOptionButton" % _GAMEPLAY)
@onready var duo_partner_note_style_option: OptionButton = get_node("%s/DuoPartnerNoteStyle/DuoPartnerNoteStyleOptionButton" % _GAMEPLAY)
@onready var show_error_meter_checkbox: CheckBox = get_node("%s/ShowErrorMeterCheckBox" % _GAMEPLAY)
@onready var show_health_bar_checkbox: CheckBox = get_node("%s/ShowHealthBarCheckBox" % _GAMEPLAY)
@onready var pause_resume_rewind_checkbox: CheckBox = get_node("%s/PauseResumeRewindCheckBox" % _GAMEPLAY)
@onready var reduce_bg_effects_checkbox: CheckBox = get_node("%s/ReduceBgEffectsCheckBox" % _GAMEPLAY)
@onready var ambient_particles_checkbox: CheckBox = get_node("%s/AmbientParticlesCheckBox" % _GAMEPLAY)
@onready var audio_reactive_bg_checkbox: CheckBox = get_node("%s/AudioReactiveBgCheckBox" % _GAMEPLAY)
@onready var shop_kick_waveform_checkbox: CheckBox = get_node("%s/ShopKickWaveformCheckBox" % _GAMEPLAY)
@onready var series_inter_track_countdown_checkbox: CheckBox = get_node("%s/SeriesInterTrackCountdownCheckBox" % _GAMEPLAY)

@onready var display_header: Label = get_node("%s/DisplayHeader" % _DISPLAY)
@onready var display_hint: Label = get_node("%s/DisplayHint" % _DISPLAY)
@onready var gameplay_header: Label = get_node("%s/GameplayHeader" % _GAMEPLAY)
@onready var gameplay_hint: Label = get_node("%s/GameplayHint" % _GAMEPLAY)
@onready var graphics_quality_label: Label = get_node("%s/GraphicsQuality/GraphicsQualityLabel" % _DISPLAY)
@onready var window_mode_label: Label = get_node("%s/WindowMode/WindowModeLabel" % _DISPLAY)
@onready var window_resolution_label: Label = get_node("%s/WindowResolution/WindowResolutionLabel" % _DISPLAY)
@onready var fps_label: Label = get_node("%s/FPS/Label" % _DISPLAY)
@onready var scroll_speed_label: Label = get_node("%s/ScrollSpeed/ScrollSpeedLabel" % _GAMEPLAY)
@onready var lane_highlight_label: Label = get_node("%s/LaneHighlightBrightnessRow/LaneHighlightBrightnessLabel" % _GAMEPLAY)
@onready var note_brightness_label: Label = get_node("%s/NoteBrightnessRow/NoteBrightnessLabel" % _GAMEPLAY)
@onready var note_approach_label: Label = get_node("%s/NoteApproachHint/NoteApproachHintLabel" % _GAMEPLAY)
@onready var duo_partner_note_style_label: Label = get_node("%s/DuoPartnerNoteStyle/DuoPartnerNoteStyleLabel" % _GAMEPLAY)
@onready var display_panel: PanelContainer = get_node("ScrollWrap/CenterWrap/ContentVBox/DisplayPanel")
@onready var gameplay_panel: PanelContainer = get_node("ScrollWrap/CenterWrap/ContentVBox/GameplayPanel")

var _gfx_quality_seg: Dictionary = {}
var _fps_seg: Dictionary = {}

func _ready():
	add_to_group("locale_refresh")
	if lane_highlight_brightness_slider:
		lane_highlight_brightness_slider.min_value = 0.0
		lane_highlight_brightness_slider.max_value = 100.0
		lane_highlight_brightness_slider.step = 1.0
	if note_brightness_slider:
		note_brightness_slider.min_value = 0.0
		note_brightness_slider.max_value = 100.0
		note_brightness_slider.step = 1.0
	for slider in [playfield_width_3_slider, playfield_width_4_slider, playfield_width_5_slider]:
		if slider:
			slider.min_value = 70.0
			slider.max_value = 150.0
			slider.step = 1.0
	call_deferred("_disable_slider_wheel_scroll")
	call_deferred("_apply_fps_option_popup_font")
	call_deferred("_apply_graphics_quality_popup_font")
	call_deferred("_apply_note_approach_popup_font")
	call_deferred("_apply_duo_partner_note_style_popup_font")
	call_deferred("_apply_scroll_speed_spin_font")
	call_deferred("_apply_window_mode_popup_font")
	call_deferred("_apply_window_resolution_popup_font")
	call_deferred("_setup_graphics_icons")
	call_deferred("_align_brightness_rows")
	call_deferred("_apply_settings_checkbox_styles")
	call_deferred("_hide_coop_only_settings")


func _hide_coop_only_settings() -> void:
	var duo_row := get_node_or_null("%s/DuoPartnerNoteStyle" % _GAMEPLAY) as Control
	if duo_row:
		duo_row.visible = false


func _setup_graphics_icons() -> void:
	_build_segmented_controls()
	_align_label_control_rows([
		window_mode_label, window_mode_option,
		window_resolution_label, window_resolution_option,
		scroll_speed_label, scroll_speed_spin,
		note_approach_label, note_approach_hint_option,
		duo_partner_note_style_label, duo_partner_note_style_option,
	])


func _build_segmented_controls() -> void:
	if _gfx_quality_seg.is_empty() and graphics_quality_option:
		_gfx_quality_seg = _SegmentedOptionUtils.build_from_option_button(
			graphics_quality_option,
			18,
			44,
			280.0
		)
		for btn in _gfx_quality_seg.get("buttons", []):
			(btn as Button).pressed.connect(_on_graphics_quality_segment_pressed.bind(btn))
	if _fps_seg.is_empty() and fps_option_button:
		_fps_seg = _SegmentedOptionUtils.build_from_option_button(
			fps_option_button,
			18,
			44,
			280.0
		)
		for btn in _fps_seg.get("buttons", []):
			(btn as Button).pressed.connect(_on_fps_segment_pressed.bind(btn))
	_sync_segmented_controls()


func _sync_segmented_controls() -> void:
	if not _gfx_quality_seg.is_empty():
		_select_graphics_quality_by_id(SettingsManager.get_graphics_quality())
	elif SettingsManager.has_method("get_graphics_quality"):
		_select_graphics_quality_by_id(SettingsManager.get_graphics_quality())
	if not _fps_seg.is_empty():
		_select_fps_by_id(SettingsManager.get_fps_mode())
	else:
		_select_fps_by_id(SettingsManager.get_fps_mode())
	if graphics_quality_label:
		graphics_quality_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if fps_label:
		fps_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _align_label_control_rows(pairs: Array) -> void:
	const CONTROL_MIN_W := 280.0
	var i := 0
	while i + 1 < pairs.size():
		var label: Control = pairs[i]
		var control: Control = pairs[i + 1]
		if label:
			label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if control:
			control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			if control is BaseButton or control is SpinBox:
				var min_sz := control.custom_minimum_size
				control.custom_minimum_size = Vector2(maxf(min_sz.x, CONTROL_MIN_W), min_sz.y)
		i += 2


func _apply_scroll_speed_spin_font() -> void:
	if scroll_speed_spin:
		_SpinBoxUtils.apply_value_font_size(scroll_speed_spin, 24)

func _disable_slider_wheel_scroll() -> void:
	_SliderScrollUtils.disable_wheel_under(self)


func _apply_fps_option_popup_font() -> void:
	_OptionButtonPopupUtils.apply_popup_font_size(fps_option_button, 24)

func _apply_graphics_quality_popup_font() -> void:
	_OptionButtonPopupUtils.apply_popup_font_size(graphics_quality_option, 24)

func _apply_note_approach_popup_font() -> void:
	if note_approach_hint_option:
		_OptionButtonPopupUtils.apply_popup_font_size(note_approach_hint_option, 24)


func _apply_duo_partner_note_style_popup_font() -> void:
	if duo_partner_note_style_option:
		_OptionButtonPopupUtils.apply_popup_font_size(duo_partner_note_style_option, 24)


func _apply_window_mode_popup_font() -> void:
	if window_mode_option:
		_OptionButtonPopupUtils.apply_popup_font_size(window_mode_option, 24)

func _apply_window_resolution_popup_font() -> void:
	if window_resolution_option:
		_OptionButtonPopupUtils.apply_popup_font_size(window_resolution_option, 24)

func _select_duo_partner_note_style(style: String) -> void:
	if not duo_partner_note_style_option:
		return
	var style_id := _DUO_NOTE_STYLE_IDS.find(_DuoMode.sanitize_style(style))
	if style_id < 0:
		style_id = 0
	var count := duo_partner_note_style_option.get_item_count()
	for i in range(count):
		if duo_partner_note_style_option.get_item_id(i) == style_id:
			duo_partner_note_style_option.select(i)
			return


func _select_note_approach_hint_by_id(id: int) -> void:
	if not note_approach_hint_option:
		return
	var count := note_approach_hint_option.get_item_count()
	for i in range(count):
		if note_approach_hint_option.get_item_id(i) == id:
			note_approach_hint_option.select(i)
			return

func _select_fps_by_id(id: int) -> void:
	if fps_option_button:
		fps_option_button.set_block_signals(true)
		for i in range(fps_option_button.get_item_count()):
			if fps_option_button.get_item_id(i) == id:
				fps_option_button.select(i)
				break
		fps_option_button.set_block_signals(false)
	if not _fps_seg.is_empty():
		_SegmentedOptionUtils.select_id(_fps_seg.get("buttons", []), id)


func _select_graphics_quality_by_id(id: int) -> void:
	if graphics_quality_option:
		graphics_quality_option.set_block_signals(true)
		for i in range(graphics_quality_option.get_item_count()):
			if graphics_quality_option.get_item_id(i) == id:
				graphics_quality_option.select(i)
				break
		graphics_quality_option.set_block_signals(false)
	if not _gfx_quality_seg.is_empty():
		_SegmentedOptionUtils.select_id(_gfx_quality_seg.get("buttons", []), id)
		return
	var count = graphics_quality_option.get_item_count()
	for i in range(count):
		if graphics_quality_option.get_item_id(i) == id:
			graphics_quality_option.select(i)
			return

func _select_window_mode_by_id(id: int) -> void:
	if not window_mode_option:
		return
	var count := window_mode_option.get_item_count()
	for i in range(count):
		if window_mode_option.get_item_id(i) == id:
			window_mode_option.select(i)
			return

func _select_window_resolution_by_id(id: int) -> void:
	if not window_resolution_option:
		return
	var count := window_resolution_option.get_item_count()
	for i in range(count):
		if window_resolution_option.get_item_id(i) == id:
			window_resolution_option.select(i)
			return

func _update_window_resolution_control_enabled() -> void:
	if not window_resolution_option:
		return
	var borderless: bool = SettingsManager.get_window_mode() == 2
	window_resolution_option.disabled = borderless
	window_resolution_option.focus_mode = Control.FOCUS_NONE if borderless else Control.FOCUS_ALL

func setup_ui_and_manager(game_engine_node = null):
	game_engine = game_engine_node 
	_setup_ui()

func _setup_ui():
	var current_fps_mode = SettingsManager.get_fps_mode()
	_select_fps_by_id(current_fps_mode)
	if SettingsManager.has_method("get_graphics_quality"):
		_select_graphics_quality_by_id(SettingsManager.get_graphics_quality())
	
	if window_mode_option:
		_select_window_mode_by_id(SettingsManager.get_window_mode())
	if window_resolution_option:
		_select_window_resolution_by_id(SettingsManager.get_window_resolution())
	_update_window_resolution_control_enabled()

	var spd = SettingsManager.get_scroll_speed()
	scroll_speed_spin.set_value_no_signal(spd)
	
	if lane_highlight_brightness_slider:
		var lh_b = SettingsManager.get_lane_highlight_brightness() if SettingsManager.has_method("get_lane_highlight_brightness") else 1.0
		lane_highlight_brightness_slider.set_value_no_signal(lh_b)
	if note_brightness_slider:
		var n_b = SettingsManager.get_note_brightness() if SettingsManager.has_method("get_note_brightness") else 1.0
		note_brightness_slider.set_value_no_signal(n_b)
	_setup_playfield_width_sliders()
	if note_approach_hint_option and SettingsManager.has_method("get_note_approach_hint"):
		_select_note_approach_hint_by_id(SettingsManager.get_note_approach_hint())
	if duo_partner_note_style_option and SettingsManager.has_method("get_duo_partner_note_style"):
		_select_duo_partner_note_style(SettingsManager.get_duo_partner_note_style())
	if show_error_meter_checkbox:
		show_error_meter_checkbox.set_pressed_no_signal(SettingsManager.get_show_error_meter())
	if show_health_bar_checkbox:
		show_health_bar_checkbox.set_pressed_no_signal(SettingsManager.get_show_health_bar())
	if pause_resume_rewind_checkbox:
		pause_resume_rewind_checkbox.set_pressed_no_signal(SettingsManager.get_pause_resume_rewind_enabled())
	if reduce_bg_effects_checkbox:
		# Positive framing: checked = effects ON (stored setting is inverse).
		reduce_bg_effects_checkbox.set_pressed_no_signal(not SettingsManager.get_reduce_bg_effects())
	if ambient_particles_checkbox:
		ambient_particles_checkbox.set_pressed_no_signal(SettingsManager.get_ambient_particles_enabled())
	if audio_reactive_bg_checkbox:
		audio_reactive_bg_checkbox.set_pressed_no_signal(SettingsManager.get_audio_reactive_background())
	if shop_kick_waveform_checkbox:
		shop_kick_waveform_checkbox.set_pressed_no_signal(SettingsManager.get_shop_kick_waveform_preview())
	if series_inter_track_countdown_checkbox:
		series_inter_track_countdown_checkbox.set_pressed_no_signal(
			SettingsManager.get_series_inter_track_countdown_enabled()
		)
	_update_brightness_labels()
	_align_brightness_rows()
	_sync_segmented_controls()


func _setup_playfield_width_sliders() -> void:
	var rows := [
		[3, playfield_width_3_slider],
		[4, playfield_width_4_slider],
		[5, playfield_width_5_slider],
	]
	for row in rows:
		var slider: HSlider = row[1]
		if slider and SettingsManager.has_method("get_playfield_width_percent"):
			slider.set_value_no_signal(SettingsManager.get_playfield_width_percent(int(row[0])))


func _on_note_approach_hint_selected(index: int) -> void:
	if not note_approach_hint_option:
		return
	var id := note_approach_hint_option.get_item_id(index)
	if SettingsManager.has_method("set_note_approach_hint"):
		SettingsManager.set_note_approach_hint(id)
	emit_signal("settings_changed")


func _on_duo_partner_note_style_selected(index: int) -> void:
	if not duo_partner_note_style_option:
		return
	var id := duo_partner_note_style_option.get_item_id(index)
	if id < 0 or id >= _DUO_NOTE_STYLE_IDS.size():
		id = 0
	if SettingsManager.has_method("set_duo_partner_note_style"):
		SettingsManager.set_duo_partner_note_style(_DUO_NOTE_STYLE_IDS[id])
	emit_signal("settings_changed")


func _on_fps_mode_selected(index: int):
	var id = fps_option_button.get_item_id(index)
	if id == SettingsManager.get_fps_mode():
		return
	_SegmentedOptionUtils.play_segment_select_sound()
	_apply_fps_mode(id)


func _on_fps_segment_pressed(btn: Button) -> void:
	var id := _SegmentedOptionUtils.id_from_button(btn)
	if id == SettingsManager.get_fps_mode():
		return
	_SegmentedOptionUtils.play_segment_select_sound()
	_apply_fps_mode(id)


func _apply_fps_mode(id: int) -> void:
	SettingsManager.set_fps_mode(id)
	emit_signal("settings_changed")
	_apply_display_settings()
	_select_fps_by_id(id)


func _on_graphics_quality_selected(index: int):
	var id = graphics_quality_option.get_item_id(index)
	var current_id := SettingsManager.get_graphics_quality() if SettingsManager.has_method("get_graphics_quality") else int(SettingsManager.get_setting("graphics_quality", 1))
	if id == current_id:
		return
	_SegmentedOptionUtils.play_segment_select_sound()
	_apply_graphics_quality(id)


func _on_graphics_quality_segment_pressed(btn: Button) -> void:
	var id := _SegmentedOptionUtils.id_from_button(btn)
	var current_id := SettingsManager.get_graphics_quality() if SettingsManager.has_method("get_graphics_quality") else int(SettingsManager.get_setting("graphics_quality", 1))
	if id == current_id:
		return
	_SegmentedOptionUtils.play_segment_select_sound()
	_apply_graphics_quality(id)


func _apply_graphics_quality(id: int) -> void:
	if SettingsManager.has_method("set_graphics_quality"):
		SettingsManager.set_graphics_quality(id)
	else:
		SettingsManager.set_setting("graphics_quality", id)
	print("GraphicsTab: качество графики изменено на id=", id)
	emit_signal("settings_changed")
	_apply_display_settings()
	_select_graphics_quality_by_id(id)

func _on_window_mode_selected(index: int) -> void:
	if not window_mode_option:
		return
	var id := window_mode_option.get_item_id(index)
	SettingsManager.set_window_mode(id)
	_update_window_resolution_control_enabled()
	emit_signal("settings_changed")
	_apply_display_settings()
	if AppWindowManager:
		AppWindowManager.refresh_unfocus_mute()


func _on_window_resolution_selected(index: int) -> void:
	if not window_resolution_option:
		return
	var id := window_resolution_option.get_item_id(index)
	SettingsManager.set_window_resolution(id)
	emit_signal("settings_changed")
	_apply_display_settings()

func _apply_display_settings() -> void:
	var engine = _get_game_engine()
	if engine and engine.has_method("update_display_settings"):
		engine.update_display_settings()

func _get_game_engine():
	if game_engine and is_instance_valid(game_engine):
		return game_engine
	var root := get_tree().root
	if root.has_node("GameEngine"):
		game_engine = root.get_node("GameEngine")
		return game_engine
	for child in root.get_children():
		if child.has_method("update_display_settings"):
			game_engine = child
			return game_engine
	return null

func refresh_ui():
	_setup_ui()

func _on_scroll_speed_spin_changed(value: float):
	SettingsManager.set_scroll_speed(value)
	emit_signal("settings_changed")

func _on_lane_highlight_brightness_changed(value: float):
	SettingsManager.set_lane_highlight_brightness(value)
	_update_brightness_labels()
	emit_signal("settings_changed")

func _on_note_brightness_changed(value: float):
	SettingsManager.set_note_brightness(value)
	_update_brightness_labels()
	emit_signal("settings_changed")


func _on_playfield_width_3_changed(value: float) -> void:
	_apply_playfield_width_percent(3, value)


func _on_playfield_width_4_changed(value: float) -> void:
	_apply_playfield_width_percent(4, value)


func _on_playfield_width_5_changed(value: float) -> void:
	_apply_playfield_width_percent(5, value)


func _apply_playfield_width_percent(lane_count: int, value: float) -> void:
	if SettingsManager.has_method("set_playfield_width_percent"):
		SettingsManager.set_playfield_width_percent(lane_count, value)
	_update_brightness_labels()
	emit_signal("settings_changed")
	_refresh_playfield_layout_if_in_game()


func _refresh_playfield_layout_if_in_game() -> void:
	var engine = _get_game_engine()
	if engine == null or not ("current_screen" in engine):
		return
	var screen = engine.current_screen
	if screen and screen.has_method("refresh_playfield_layout"):
		screen.refresh_playfield_layout()


func _update_brightness_labels() -> void:
	var rows := [
		[lane_highlight_label, lane_highlight_brightness_percent, lane_highlight_brightness_slider],
		[note_brightness_label, note_brightness_percent, note_brightness_slider],
		[playfield_width_3_label, playfield_width_3_percent, playfield_width_3_slider],
		[playfield_width_4_label, playfield_width_4_percent, playfield_width_4_slider],
		[playfield_width_5_label, playfield_width_5_percent, playfield_width_5_slider],
	]
	for row in rows:
		if row[1] and row[2]:
			row[1].text = "%d%%" % int(round(row[2].value))


func _align_brightness_rows() -> void:
	const LABEL_W := 220.0
	const PCT_W := 48.0
	const NEUTRAL_PCT := Color(0.62, 0.7, 0.82, 0.95)
	for row_path in [
		"%s/LaneHighlightBrightnessRow" % _GAMEPLAY,
		"%s/NoteBrightnessRow" % _GAMEPLAY,
		"%s/PlayfieldWidth3Row" % _GAMEPLAY,
		"%s/PlayfieldWidth4Row" % _GAMEPLAY,
		"%s/PlayfieldWidth5Row" % _GAMEPLAY,
	]:
		var hbox: HBoxContainer = get_node_or_null(row_path)
		if hbox == null:
			continue
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for child in hbox.get_children():
			if child is Label and str(child.name).ends_with("Label"):
				child.custom_minimum_size.x = LABEL_W
				child.clip_text = true
			elif child is HSlider:
				child.custom_minimum_size = Vector2(0, 28)
				child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			elif child is Label and str(child.name).ends_with("Percent"):
				child.custom_minimum_size.x = PCT_W
				child.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				child.add_theme_color_override("font_color", NEUTRAL_PCT)


func _on_show_error_meter_toggled(enabled: bool) -> void:
	SettingsManager.set_show_error_meter(enabled)
	emit_signal("settings_changed")


func _on_show_health_bar_toggled(enabled: bool) -> void:
	SettingsManager.set_show_health_bar(enabled)
	emit_signal("settings_changed")


func _on_pause_resume_rewind_toggled(enabled: bool) -> void:
	SettingsManager.set_pause_resume_rewind_enabled(enabled)
	emit_signal("settings_changed")


func _on_reduce_bg_effects_toggled(enabled: bool) -> void:
	# Checkbox is "effects ON"; stored flag is "reduce effects", so invert.
	SettingsManager.set_reduce_bg_effects(not enabled)
	emit_signal("settings_changed")


func _on_ambient_particles_toggled(enabled: bool) -> void:
	SettingsManager.set_ambient_particles_enabled(enabled)
	emit_signal("settings_changed")
	var engine = _get_game_engine()
	if engine and engine.has_method("apply_ambient_settings"):
		engine.apply_ambient_settings()


func _on_audio_reactive_bg_toggled(enabled: bool) -> void:
	SettingsManager.set_audio_reactive_background(enabled)
	emit_signal("settings_changed")


func _on_shop_kick_waveform_toggled(enabled: bool) -> void:
	SettingsManager.set_shop_kick_waveform_preview(enabled)
	emit_signal("settings_changed")


func _on_series_inter_track_countdown_toggled(enabled: bool) -> void:
	SettingsManager.set_series_inter_track_countdown_enabled(enabled)
	emit_signal("settings_changed")


func _set_tooltip(control: Control, key: String) -> void:
	if control == null:
		return
	control.tooltip_text = tr(key)
	if control is Label:
		control.mouse_filter = Control.MOUSE_FILTER_PASS


func apply_locale() -> void:
	if display_header:
		display_header.text = tr("GFX_DISPLAY")
	if display_hint:
		display_hint.text = tr("SETTINGS_DISPLAY_SECTION_HINT")
	if gameplay_header:
		gameplay_header.text = tr("GFX_GAMEPLAY")
	if gameplay_hint:
		gameplay_hint.text = tr("SETTINGS_GAMEPLAY_SECTION_HINT")
	if graphics_quality_label:
		graphics_quality_label.text = tr("GFX_GRAPHICS_QUALITY")
		_set_tooltip(graphics_quality_label, "GFX_QUALITY_TOOLTIP")
	if not _gfx_quality_seg.is_empty():
		_SegmentedOptionUtils.apply_texts(
			_gfx_quality_seg.get("buttons", []),
			PackedStringArray([tr("GFX_QUALITY_LOW"), tr("GFX_QUALITY_MEDIUM"), tr("GFX_QUALITY_HIGH")])
		)
	if window_mode_label:
		window_mode_label.text = tr("GFX_WINDOW_MODE")
	if window_resolution_label:
		window_resolution_label.text = tr("GFX_RESOLUTION")
	if fps_label:
		fps_label.text = tr("GFX_FPS")
		_set_tooltip(fps_label, "GFX_FPS_MODE_TOOLTIP")
	if not _fps_seg.is_empty():
		_SegmentedOptionUtils.apply_texts(
			_fps_seg.get("buttons", []),
			PackedStringArray([tr("GFX_FPS_NONE"), tr("GFX_FPS_NORMAL"), tr("GFX_FPS_CONTRAST")])
		)
	if scroll_speed_label:
		scroll_speed_label.text = tr("GFX_SCROLL_SPEED")
		_set_tooltip(scroll_speed_label, "GFX_SCROLL_SPEED_TOOLTIP")
	if scroll_speed_spin:
		_set_tooltip(scroll_speed_spin, "GFX_SCROLL_SPEED_TOOLTIP")
	if lane_highlight_label:
		lane_highlight_label.text = tr("GFX_LANE_HIGHLIGHT")
		_set_tooltip(lane_highlight_label, "GFX_LANE_HIGHLIGHT_TOOLTIP")
	if lane_highlight_brightness_slider:
		_set_tooltip(lane_highlight_brightness_slider, "GFX_LANE_HIGHLIGHT_TOOLTIP")
	if note_brightness_label:
		note_brightness_label.text = tr("GFX_NOTE_BRIGHTNESS")
		_set_tooltip(note_brightness_label, "GFX_NOTE_BRIGHTNESS_TOOLTIP")
	if note_brightness_slider:
		_set_tooltip(note_brightness_slider, "GFX_NOTE_BRIGHTNESS_TOOLTIP")
	if playfield_width_header:
		playfield_width_header.text = tr("GFX_PLAYFIELD_WIDTH_HEADER")
		_set_tooltip(playfield_width_header, "GFX_PLAYFIELD_WIDTH_TOOLTIP")
	if playfield_width_3_label:
		playfield_width_3_label.text = tr("GFX_PLAYFIELD_WIDTH_3")
		_set_tooltip(playfield_width_3_label, "GFX_PLAYFIELD_WIDTH_TOOLTIP")
	if playfield_width_3_slider:
		_set_tooltip(playfield_width_3_slider, "GFX_PLAYFIELD_WIDTH_TOOLTIP")
	if playfield_width_4_label:
		playfield_width_4_label.text = tr("GFX_PLAYFIELD_WIDTH_4")
		_set_tooltip(playfield_width_4_label, "GFX_PLAYFIELD_WIDTH_TOOLTIP")
	if playfield_width_4_slider:
		_set_tooltip(playfield_width_4_slider, "GFX_PLAYFIELD_WIDTH_TOOLTIP")
	if playfield_width_5_label:
		playfield_width_5_label.text = tr("GFX_PLAYFIELD_WIDTH_5")
		_set_tooltip(playfield_width_5_label, "GFX_PLAYFIELD_WIDTH_TOOLTIP")
	if playfield_width_5_slider:
		_set_tooltip(playfield_width_5_slider, "GFX_PLAYFIELD_WIDTH_TOOLTIP")
	if note_approach_label:
		note_approach_label.text = tr("GFX_LINE_ACCENT")
		_set_tooltip(note_approach_label, "GFX_LINE_ACCENT_TOOLTIP")
	if note_approach_hint_option:
		_set_tooltip(note_approach_hint_option, "GFX_LINE_ACCENT_TOOLTIP")
	if duo_partner_note_style_label:
		duo_partner_note_style_label.text = tr("GFX_DUO_PARTNER_NOTE_STYLE")
		_set_tooltip(duo_partner_note_style_label, "GFX_DUO_PARTNER_NOTE_STYLE_TOOLTIP")
	if duo_partner_note_style_option:
		_set_tooltip(duo_partner_note_style_option, "GFX_DUO_PARTNER_NOTE_STYLE_TOOLTIP")
	if show_error_meter_checkbox:
		show_error_meter_checkbox.text = tr("GFX_SHOW_ERROR_METER")
		_set_tooltip(show_error_meter_checkbox, "GFX_SHOW_ERROR_METER_TOOLTIP")
	if show_health_bar_checkbox:
		show_health_bar_checkbox.text = tr("GFX_SHOW_HEALTH_BAR")
		_set_tooltip(show_health_bar_checkbox, "GFX_SHOW_HEALTH_BAR_TOOLTIP")
	if pause_resume_rewind_checkbox:
		pause_resume_rewind_checkbox.text = tr("GFX_PAUSE_RESUME_REWIND")
		_set_tooltip(pause_resume_rewind_checkbox, "GFX_PAUSE_RESUME_REWIND_TOOLTIP")
	if reduce_bg_effects_checkbox:
		reduce_bg_effects_checkbox.text = tr("GFX_REDUCE_BG_EFFECTS")
		_set_tooltip(reduce_bg_effects_checkbox, "GFX_REDUCE_BG_EFFECTS_TOOLTIP")
	if ambient_particles_checkbox:
		ambient_particles_checkbox.text = tr("GFX_AMBIENT_PARTICLES")
		_set_tooltip(ambient_particles_checkbox, "GFX_AMBIENT_PARTICLES_TOOLTIP")
	if audio_reactive_bg_checkbox:
		audio_reactive_bg_checkbox.text = tr("GFX_AUDIO_REACTIVE_BG")
		_set_tooltip(audio_reactive_bg_checkbox, "GFX_AUDIO_REACTIVE_BG_TOOLTIP")
	if shop_kick_waveform_checkbox:
		shop_kick_waveform_checkbox.text = tr("GFX_SHOP_KICK_WAVEFORM")
		_set_tooltip(shop_kick_waveform_checkbox, "GFX_SHOP_KICK_WAVEFORM_TOOLTIP")
	if series_inter_track_countdown_checkbox:
		series_inter_track_countdown_checkbox.text = tr("GFX_SERIES_INTER_TRACK_COUNTDOWN")
		_set_tooltip(series_inter_track_countdown_checkbox, "GFX_SERIES_INTER_TRACK_COUNTDOWN_TOOLTIP")
	if graphics_quality_option and graphics_quality_option.item_count >= 3:
		graphics_quality_option.set_block_signals(true)
		graphics_quality_option.set_item_text(0, tr("GFX_QUALITY_LOW"))
		graphics_quality_option.set_item_text(1, tr("GFX_QUALITY_MEDIUM"))
		graphics_quality_option.set_item_text(2, tr("GFX_QUALITY_HIGH"))
		graphics_quality_option.set_block_signals(false)
	if window_mode_option and window_mode_option.item_count >= 3:
		window_mode_option.set_block_signals(true)
		window_mode_option.set_item_text(0, tr("GFX_WINDOW_WINDOWED"))
		window_mode_option.set_item_text(1, tr("GFX_WINDOW_FULLSCREEN"))
		window_mode_option.set_item_text(2, tr("GFX_WINDOW_BORDERLESS"))
		window_mode_option.set_block_signals(false)
	if fps_option_button and fps_option_button.item_count >= 3:
		fps_option_button.set_block_signals(true)
		fps_option_button.set_item_text(0, tr("GFX_FPS_NONE"))
		fps_option_button.set_item_text(1, tr("GFX_FPS_NORMAL"))
		fps_option_button.set_item_text(2, tr("GFX_FPS_CONTRAST"))
		fps_option_button.set_block_signals(false)
	if note_approach_hint_option and note_approach_hint_option.item_count >= 4:
		note_approach_hint_option.set_block_signals(true)
		note_approach_hint_option.set_item_text(0, tr("GFX_APPROACH_NONE"))
		note_approach_hint_option.set_item_text(1, tr("GFX_APPROACH_LIGHTER"))
		note_approach_hint_option.set_item_text(2, tr("GFX_APPROACH_DARKER"))
		note_approach_hint_option.set_item_text(3, tr("GFX_APPROACH_RICHER"))
		note_approach_hint_option.set_block_signals(false)
	if duo_partner_note_style_option and duo_partner_note_style_option.item_count >= 4:
		duo_partner_note_style_option.set_block_signals(true)
		duo_partner_note_style_option.set_item_text(0, tr("GFX_DUO_NOTE_WARM_COOL"))
		duo_partner_note_style_option.set_item_text(1, tr("GFX_DUO_NOTE_TINT"))
		duo_partner_note_style_option.set_item_text(2, tr("GFX_DUO_NOTE_OUTLINE"))
		duo_partner_note_style_option.set_item_text(3, tr("GFX_DUO_NOTE_NONE"))
		duo_partner_note_style_option.set_block_signals(false)
	_apply_segmented_tooltips()
	_update_brightness_labels()
	_sync_segmented_controls()
	call_deferred("_align_brightness_rows")


func _apply_segmented_tooltips() -> void:
	for btn in _gfx_quality_seg.get("buttons", []):
		_set_tooltip(btn as Control, "GFX_QUALITY_TOOLTIP")
	for btn in _fps_seg.get("buttons", []):
		_set_tooltip(btn as Control, "GFX_FPS_MODE_TOOLTIP")


func _apply_settings_checkbox_styles() -> void:
	const ACCENT := Color(0.42, 0.57, 0.82, 1.0)
	for checkbox in [
		show_error_meter_checkbox,
		show_health_bar_checkbox,
		pause_resume_rewind_checkbox,
		reduce_bg_effects_checkbox,
		ambient_particles_checkbox,
		audio_reactive_bg_checkbox,
		shop_kick_waveform_checkbox,
		series_inter_track_countdown_checkbox,
	]:
		_SettingsSectionUi.apply_settings_checkbox(checkbox, 22, false, ACCENT)
