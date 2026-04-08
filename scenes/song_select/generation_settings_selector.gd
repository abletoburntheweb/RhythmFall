# scenes/song_select/generation_settings_selector.gd
class_name GenerationSettingsSelector
extends Control

const _OptionButtonPopupUtils = preload("res://logic/utils/option_button_popup_utils.gd")

signal generation_settings_confirmed(instrument: String, mode: String, lanes: int)
signal selector_closed

var selected_instrument: String = "drums"
var selected_mode: String = "basic"
var selected_lanes: int = 4
var selected_fill: int = 50
var selected_groove: int = 50
var selected_density: int = 50
var selected_grid_snap_strength: int = 80
var selected_accent_strong_beats: bool = true
var selected_genre_template_strength: int = 60
var selected_enable_genre_detection: bool = true
var selected_use_stems_in_generation: bool = true
var current_song_path: String = ""
var status_label: Label = null
var fill_slider: HSlider = null
var groove_slider: HSlider = null
var density_slider: HSlider = null
var grid_snap_strength_slider: HSlider = null
var accent_strong_beats_checkbox: BaseButton = null
var genre_template_strength_slider: HSlider = null
var fill_label: Label = null
var groove_label: Label = null
var density_label: Label = null
var grid_snap_label: Label = null
var genre_template_label: Label = null
var enable_genre_detection_checkbox: BaseButton = null
var enable_stems_checkbox: BaseButton = null
var advanced_toggle_button: Button = null
var advanced_container: Control = null
var _applying_ui_state: bool = false
const ADVANCED_SECTION_TITLE := "Расширенные настройки"

const ACTIVE_COLOR = Color(0.8, 0.8, 1.0, 1.0)
const DEFAULT_COLOR = Color(1.0, 1.0, 1.0, 1.0)

const MODES := ["minimal", "basic", "enhanced", "natural", "custom"]
const MODE_LABELS := ["Минимал", "Базовый", "Усложнённый", "Натуральный", "Пользовательский"]
const FILL_LABEL_BASE := "Заполнение"
const GROOVE_LABEL_BASE := "Живость"
const DENSITY_LABEL_BASE := "Плотность"
const GRID_SNAP_LABEL_BASE := "Привязка к сетке"
const GENRE_TEMPLATE_LABEL_BASE := "Сила жанрового шаблона"

const MODE_PRESETS := {
	"minimal":  {"fill": 0,  "groove": 20, "density": 30, "grid_snap_strength": 85, "accent_strong_beats": true,  "genre_template_strength": 45, "enable_genre_detection": true, "use_stems_in_generation": true},
	"basic":    {"fill": 0,  "groove": 50, "density": 50, "grid_snap_strength": 60, "accent_strong_beats": true,  "genre_template_strength": 60, "enable_genre_detection": true, "use_stems_in_generation": true},
	"enhanced": {"fill": 75, "groove": 55, "density": 70, "grid_snap_strength": 35, "accent_strong_beats": false, "genre_template_strength": 80, "enable_genre_detection": true, "use_stems_in_generation": true},
	"natural":  {"fill": 0,  "groove": 50, "density": 50, "grid_snap_strength": 0,  "accent_strong_beats": false, "genre_template_strength": 20, "enable_genre_detection": true, "use_stems_in_generation": true},
}

func _ready():
	_applying_ui_state = true
	var background = $Background
	if background:
		background.color = Color(0, 0, 0, 180.0 / 255.0)
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
	selected_instrument = SettingsManager.get_setting("last_generation_instrument", "drums")
	selected_mode = SettingsManager.get_setting("last_generation_mode", "basic")
	selected_lanes = SettingsManager.get_setting("last_generation_lanes", 4)
	selected_fill = SettingsManager.get_setting("generation_fill", 50)
	selected_groove = SettingsManager.get_setting("generation_groove", 50)
	selected_density = SettingsManager.get_setting("generation_density", 50)
	selected_grid_snap_strength = int(SettingsManager.get_setting("generation_grid_snap_strength", 80))
	selected_accent_strong_beats = bool(SettingsManager.get_setting("generation_accent_strong_beats", true))
	selected_genre_template_strength = int(SettingsManager.get_setting("generation_genre_template_strength", 60))
	selected_enable_genre_detection = bool(SettingsManager.get_setting("enable_genre_detection", true))
	selected_use_stems_in_generation = bool(SettingsManager.get_setting("use_stems_in_generation", true))

	status_label = $Container/StatusLabel
	advanced_toggle_button = get_node_or_null("Container/AdvancedSection/AdvancedToggleButton")
	advanced_container = get_node_or_null("Container/AdvancedSection/SlidersContainer")
	fill_slider = $"Container/AdvancedSection/SlidersContainer/FillRow/FillSlider"
	groove_slider = $"Container/AdvancedSection/SlidersContainer/GrooveRow/GrooveSlider"
	density_slider = $"Container/AdvancedSection/SlidersContainer/DensityRow/DensitySlider"
	grid_snap_strength_slider = $"Container/AdvancedSection/SlidersContainer/GridSnapRow/GridSnapStrengthSlider"
	fill_label = get_node_or_null("Container/AdvancedSection/SlidersContainer/FillRow/FillLabel")
	groove_label = get_node_or_null("Container/AdvancedSection/SlidersContainer/GrooveRow/GrooveLabel")
	density_label = get_node_or_null("Container/AdvancedSection/SlidersContainer/DensityRow/DensityLabel")
	grid_snap_label = get_node_or_null("Container/AdvancedSection/SlidersContainer/GridSnapRow/GridSnapLabel")
	genre_template_label = get_node_or_null("Container/AdvancedSection/SlidersContainer/GenreTemplateRow/GenreTemplateLabel")
	accent_strong_beats_checkbox = get_node_or_null("Container/AdvancedSection/SlidersContainer/CheckboxesContainer/AccentStrongBeatsCheckBox")
	if not accent_strong_beats_checkbox:
		accent_strong_beats_checkbox = get_node_or_null("Container/SlidersContainer/CheckboxesContainer/AccentStrongBeatsCheckBox")
	enable_genre_detection_checkbox = get_node_or_null("Container/AdvancedSection/SlidersContainer/CheckboxesContainer/EnableGenreDetectionCheckBox")
	if not enable_genre_detection_checkbox:
		enable_genre_detection_checkbox = get_node_or_null("Container/SlidersContainer/CheckboxesContainer/EnableGenreDetectionCheckBox")
	enable_stems_checkbox = get_node_or_null("Container/AdvancedSection/SlidersContainer/CheckboxesContainer/EnableStemsCheckBox")
	if not enable_stems_checkbox:
		enable_stems_checkbox = get_node_or_null("Container/SlidersContainer/CheckboxesContainer/EnableStemsCheckBox")
	genre_template_strength_slider = $"Container/AdvancedSection/SlidersContainer/GenreTemplateRow/GenreTemplateStrengthSlider"

	if fill_slider:
		fill_slider.set_value_no_signal(float(selected_fill))
	if groove_slider:
		groove_slider.set_value_no_signal(float(selected_groove))
	if density_slider:
		density_slider.set_value_no_signal(float(selected_density))
	if grid_snap_strength_slider:
		grid_snap_strength_slider.set_value_no_signal(float(selected_grid_snap_strength))
	if accent_strong_beats_checkbox:
		_set_checkbox_state(accent_strong_beats_checkbox, selected_accent_strong_beats)
	if enable_genre_detection_checkbox:
		enable_genre_detection_checkbox.toggle_mode = true
		_set_checkbox_state(enable_genre_detection_checkbox, selected_enable_genre_detection)
	if enable_stems_checkbox:
		enable_stems_checkbox.toggle_mode = true
		_set_checkbox_state(enable_stems_checkbox, selected_use_stems_in_generation)
	if genre_template_strength_slider:
		genre_template_strength_slider.set_value_no_signal(float(selected_genre_template_strength))

	if selected_mode == "custom":
		_load_custom_preset_from_settings_into_state()
		if fill_slider:
			fill_slider.set_value_no_signal(float(selected_fill))
		if groove_slider:
			groove_slider.set_value_no_signal(float(selected_groove))
		if density_slider:
			density_slider.set_value_no_signal(float(selected_density))
		if grid_snap_strength_slider:
			grid_snap_strength_slider.set_value_no_signal(float(selected_grid_snap_strength))
		if accent_strong_beats_checkbox:
			_set_checkbox_state(accent_strong_beats_checkbox, selected_accent_strong_beats)
		if enable_genre_detection_checkbox:
			_set_checkbox_state(enable_genre_detection_checkbox, selected_enable_genre_detection)
		if enable_stems_checkbox:
			_set_checkbox_state(enable_stems_checkbox, selected_use_stems_in_generation)
		if genre_template_strength_slider:
			genre_template_strength_slider.set_value_no_signal(float(selected_genre_template_strength))
		SettingsManager.set_setting("enable_genre_detection", selected_enable_genre_detection)
		SettingsManager.set_setting("use_stems_in_generation", selected_use_stems_in_generation)

	var mode_btn := $Container/ModeOptionButton as OptionButton
	if mode_btn:
		var idx := MODES.find(selected_mode)
		var select_idx := idx if idx >= 0 else 1
		mode_btn.select(select_idx)
		_on_mode_selected(select_idx)
	_update_slider_labels()
	_apply_advanced_section_visual()

	_applying_ui_state = false
	_update_ui_from_selection()
	_update_status_indicator()
	call_deferred("_apply_mode_option_popup_font")

func _apply_mode_option_popup_font() -> void:
	var mode_btn := $Container/ModeOptionButton as OptionButton
	_OptionButtonPopupUtils.apply_popup_font_size(mode_btn, 24)

func _update_ui_from_selection():
	for btn in [$Container/InstrumentButtons/PercussionButton, $Container/InstrumentButtons/FullMixButton]:
		btn.self_modulate = DEFAULT_COLOR
	for btn in [$Container/LanesButtons/Lanes3Button, $Container/LanesButtons/Lanes4Button, $Container/LanesButtons/Lanes5Button]:
		btn.self_modulate = DEFAULT_COLOR

	if selected_instrument == "drums":
		$Container/InstrumentButtons/PercussionButton.self_modulate = ACTIVE_COLOR
	elif selected_instrument == "fullmix":
		$Container/InstrumentButtons/FullMixButton.self_modulate = ACTIVE_COLOR

	match selected_lanes:
		3: $Container/LanesButtons/Lanes3Button.self_modulate = ACTIVE_COLOR
		4: $Container/LanesButtons/Lanes4Button.self_modulate = ACTIVE_COLOR
		5: $Container/LanesButtons/Lanes5Button.self_modulate = ACTIVE_COLOR
	_update_status_indicator()
		
func _on_percussion_selected():
	selected_instrument = "drums"
	_set_active_button($Container/InstrumentButtons/PercussionButton)

func _on_fullmix_selected():
	selected_instrument = "fullmix"
	_set_active_button($Container/InstrumentButtons/FullMixButton)

func _persist_custom_preset_to_settings():
	SettingsManager.set_setting("generation_custom_fill", selected_fill)
	SettingsManager.set_setting("generation_custom_groove", selected_groove)
	SettingsManager.set_setting("generation_custom_density", selected_density)
	SettingsManager.set_setting("generation_custom_grid_snap_strength", selected_grid_snap_strength)
	SettingsManager.set_setting("generation_custom_accent_strong_beats", selected_accent_strong_beats)
	SettingsManager.set_setting("generation_custom_genre_template_strength", selected_genre_template_strength)
	SettingsManager.set_setting("generation_custom_enable_genre_detection", selected_enable_genre_detection)
	SettingsManager.set_setting("generation_custom_use_stems_in_generation", selected_use_stems_in_generation)

func _load_custom_preset_from_settings_into_state():
	selected_fill = int(SettingsManager.get_setting("generation_custom_fill", 50))
	selected_groove = int(SettingsManager.get_setting("generation_custom_groove", 50))
	selected_density = int(SettingsManager.get_setting("generation_custom_density", 50))
	selected_grid_snap_strength = int(SettingsManager.get_setting("generation_custom_grid_snap_strength", 50))
	selected_accent_strong_beats = bool(SettingsManager.get_setting("generation_custom_accent_strong_beats", false))
	selected_genre_template_strength = int(SettingsManager.get_setting("generation_custom_genre_template_strength", 50))
	selected_enable_genre_detection = bool(SettingsManager.get_setting("generation_custom_enable_genre_detection", false))
	selected_use_stems_in_generation = bool(SettingsManager.get_setting("generation_custom_use_stems_in_generation", false))

func _on_mode_selected(index: int):
	if _applying_ui_state:
		selected_mode = MODES[index] if index >= 0 and index < MODES.size() else selected_mode
	if index < 0 or index >= MODES.size():
		return
	var new_mode: String = MODES[index]
	if selected_mode == "custom" and new_mode != "custom":
		_persist_custom_preset_to_settings()
		SettingsManager.save_settings()
	selected_mode = new_mode
	var preset = MODE_PRESETS.get(selected_mode)
	if preset:
		selected_fill = preset["fill"]
		selected_groove = preset["groove"]
		selected_density = preset["density"]
		selected_grid_snap_strength = int(preset["grid_snap_strength"])
		selected_accent_strong_beats = bool(preset["accent_strong_beats"])
		selected_genre_template_strength = int(preset["genre_template_strength"])
		selected_enable_genre_detection = bool(preset["enable_genre_detection"])
		selected_use_stems_in_generation = bool(preset["use_stems_in_generation"])
		if fill_slider:
			fill_slider.set_value_no_signal(float(selected_fill))
		if groove_slider:
			groove_slider.set_value_no_signal(float(selected_groove))
		if density_slider:
			density_slider.set_value_no_signal(float(selected_density))
		if grid_snap_strength_slider:
			grid_snap_strength_slider.set_value_no_signal(float(selected_grid_snap_strength))
		if accent_strong_beats_checkbox:
			_set_checkbox_state(accent_strong_beats_checkbox, selected_accent_strong_beats)
		if enable_genre_detection_checkbox:
			_set_checkbox_state(enable_genre_detection_checkbox, selected_enable_genre_detection)
		if enable_stems_checkbox:
			_set_checkbox_state(enable_stems_checkbox, selected_use_stems_in_generation)
		if genre_template_strength_slider:
			genre_template_strength_slider.set_value_no_signal(float(selected_genre_template_strength))
		SettingsManager.set_setting("enable_genre_detection", selected_enable_genre_detection)
		SettingsManager.set_setting("use_stems_in_generation", selected_use_stems_in_generation)
	elif selected_mode == "custom":
		_load_custom_preset_from_settings_into_state()
		if fill_slider:
			fill_slider.set_value_no_signal(float(selected_fill))
		if groove_slider:
			groove_slider.set_value_no_signal(float(selected_groove))
		if density_slider:
			density_slider.set_value_no_signal(float(selected_density))
		if grid_snap_strength_slider:
			grid_snap_strength_slider.set_value_no_signal(float(selected_grid_snap_strength))
		if genre_template_strength_slider:
			genre_template_strength_slider.set_value_no_signal(float(selected_genre_template_strength))
		if accent_strong_beats_checkbox:
			_set_checkbox_state(accent_strong_beats_checkbox, selected_accent_strong_beats)
		if enable_genre_detection_checkbox:
			_set_checkbox_state(enable_genre_detection_checkbox, selected_enable_genre_detection)
		if enable_stems_checkbox:
			_set_checkbox_state(enable_stems_checkbox, selected_use_stems_in_generation)
		SettingsManager.set_setting("enable_genre_detection", selected_enable_genre_detection)
		SettingsManager.set_setting("use_stems_in_generation", selected_use_stems_in_generation)
	_update_slider_labels()
	_update_status_indicator()

func _sync_mode_from_sliders():
	var mode_btn := $Container/ModeOptionButton as OptionButton
	if not mode_btn:
		return
	for mode_key in MODE_PRESETS:
		var preset = MODE_PRESETS[mode_key]
		var genre_toggle_ok = true
		var stems_toggle_ok = true
		genre_toggle_ok = bool(preset["enable_genre_detection"]) == selected_enable_genre_detection
		stems_toggle_ok = bool(preset["use_stems_in_generation"]) == selected_use_stems_in_generation
		if preset["fill"] == selected_fill and preset["groove"] == selected_groove and preset["density"] == selected_density and preset["grid_snap_strength"] == selected_grid_snap_strength and preset["accent_strong_beats"] == selected_accent_strong_beats and preset["genre_template_strength"] == selected_genre_template_strength and genre_toggle_ok and stems_toggle_ok:
			var idx := MODES.find(mode_key)
			if idx >= 0:
				selected_mode = mode_key
				mode_btn.select(idx)
				return
	selected_mode = "custom"
	mode_btn.select(MODES.find("custom"))

func _on_lanes3_selected():
	selected_lanes = 3
	_set_active_button($Container/LanesButtons/Lanes3Button)

func _on_lanes4_selected():
	selected_lanes = 4
	_set_active_button($Container/LanesButtons/Lanes4Button)

func _on_lanes5_selected():
	selected_lanes = 5
	_set_active_button($Container/LanesButtons/Lanes5Button)

func _set_active_button(active_btn: Button):
	var group_container = active_btn.get_parent()
	for child in group_container.get_children():
		if child is Button:
			child.self_modulate = DEFAULT_COLOR
	
	active_btn.self_modulate = ACTIVE_COLOR
	_update_status_indicator()

func _on_fill_slider_changed(value: float):
	if _applying_ui_state:
		return
	selected_fill = int(value)
	_update_slider_labels()
	_sync_mode_from_sliders()

func _on_groove_slider_changed(value: float):
	if _applying_ui_state:
		return
	selected_groove = int(value)
	_update_slider_labels()
	_sync_mode_from_sliders()

func _on_density_slider_changed(value: float):
	if _applying_ui_state:
		return
	selected_density = int(value)
	_update_slider_labels()
	_sync_mode_from_sliders()

func _on_grid_snap_strength_changed(value: float):
	if _applying_ui_state:
		return
	selected_grid_snap_strength = int(value)
	_update_slider_labels()
	_sync_mode_from_sliders()

func _on_accent_strong_beats_toggled(toggled_on: bool):
	if _applying_ui_state:
		return
	selected_accent_strong_beats = toggled_on
	_sync_mode_from_sliders()

func _on_genre_template_strength_changed(value: float):
	if _applying_ui_state:
		return
	selected_genre_template_strength = int(value)
	_update_slider_labels()
	_sync_mode_from_sliders()

func _on_enable_genre_detection_toggled(enabled: bool):
	if _applying_ui_state:
		return
	selected_enable_genre_detection = enabled
	SettingsManager.set_setting("enable_genre_detection", enabled)
	_sync_mode_from_sliders()

func _on_enable_stems_toggled(enabled: bool):
	if _applying_ui_state:
		return
	selected_use_stems_in_generation = enabled
	SettingsManager.set_setting("use_stems_in_generation", enabled)
	_sync_mode_from_sliders()

func _set_checkbox_state(checkbox: BaseButton, value: bool):
	if not checkbox:
		return
	checkbox.set_pressed_no_signal(value)
	checkbox.button_pressed = value

func _on_advanced_section_toggled(pressed: bool):
	if advanced_container:
		advanced_container.visible = pressed
	if advanced_toggle_button:
		advanced_toggle_button.text = ("v " if pressed else "> ") + ADVANCED_SECTION_TITLE
		advanced_toggle_button.modulate = Color(0.42, 0.57, 0.82) if pressed else Color.WHITE

func _apply_advanced_section_visual():
	if not advanced_toggle_button:
		return
	var on := advanced_toggle_button.button_pressed
	if advanced_container:
		advanced_container.visible = on
	advanced_toggle_button.text = ("v " if on else "> ") + ADVANCED_SECTION_TITLE
	advanced_toggle_button.modulate = Color(0.42, 0.57, 0.82) if on else Color.WHITE

func _update_slider_labels():
	if fill_label:
		fill_label.text = "%s (%d%%)" % [FILL_LABEL_BASE, selected_fill]
	if groove_label:
		groove_label.text = "%s (%d%%)" % [GROOVE_LABEL_BASE, selected_groove]
	if density_label:
		density_label.text = "%s (%d%%)" % [DENSITY_LABEL_BASE, selected_density]
	if grid_snap_label:
		grid_snap_label.text = "%s (%d%%)" % [GRID_SNAP_LABEL_BASE, selected_grid_snap_strength]
	if genre_template_label:
		genre_template_label.text = "%s (%d%%)" % [GENRE_TEMPLATE_LABEL_BASE, selected_genre_template_strength]

func _on_confirm_pressed():
	SettingsManager.set_setting("last_generation_instrument", selected_instrument)
	SettingsManager.set_setting("last_generation_mode", selected_mode)
	SettingsManager.set_setting("last_generation_lanes", selected_lanes)
	SettingsManager.set_setting("generation_fill", selected_fill)
	SettingsManager.set_setting("generation_groove", selected_groove)
	SettingsManager.set_setting("generation_density", selected_density)
	SettingsManager.set_setting("generation_grid_snap_strength", selected_grid_snap_strength)
	SettingsManager.set_setting("generation_accent_strong_beats", selected_accent_strong_beats)
	SettingsManager.set_setting("generation_genre_template_strength", selected_genre_template_strength)
	SettingsManager.set_setting("enable_genre_detection", selected_enable_genre_detection)
	SettingsManager.set_setting("use_stems_in_generation", selected_use_stems_in_generation)
	if selected_mode == "custom":
		_persist_custom_preset_to_settings()
	SettingsManager.save_settings()
	
	MusicManager.play_instrument_select_sound(selected_instrument)
	
	emit_signal("generation_settings_confirmed", selected_instrument, selected_mode, selected_lanes)
	emit_signal("selector_closed")

func _on_back_button_pressed():
	MusicManager.play_cancel_sound()
	emit_signal("selector_closed")
	
func set_current_song_path(path: String):
	current_song_path = path
	_update_status_indicator()
	
func _update_status_indicator():
	if not status_label:
		return
	var exists = _notes_exist_for_selection()
	if exists:
		status_label.text = "Ноты готовы"
		status_label.add_theme_color_override("font_color", Color("#61C7BD"))
	else:
		status_label.text = "Нет нот"
		status_label.add_theme_color_override("font_color", Color("#C99AE5"))
	
func _notes_exist_for_selection() -> bool:
	if current_song_path == "":
		return false
	return NotesUtils.notes_ready_for_scope(current_song_path, selected_instrument, selected_mode, selected_lanes)

func _input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		_on_back_button_pressed()
		accept_event()
