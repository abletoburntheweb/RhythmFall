# scenes/settings_menu/tabs/experimental_tab.gd
extends Control

signal settings_changed

const _SettingsSectionUi = preload("res://logic/ui/settings_section_ui.gd")
const _SegmentedOptionUtils = preload("res://logic/ui/segmented_option_utils.gd")
const _SpotlightTutorialScene = preload("res://ui/spotlight_tutorial.tscn")

const _ACCENT_SKY := Color(0.52, 0.76, 0.92, 1.0)
const _COMPARE_MODE_HOTKEY_ID := 0
const _COMPARE_MODE_SPLIT_ID := 1

const _CV := "ScrollWrap/CenterWrap/ContentVBox"
const _CONSOLE := "%s/ConsolePanel/ConsolePanelMargin/ConsoleRows" % _CV
const _COMPARE := "%s/ComparePanel/ComparePanelMargin/CompareRows" % _CV
const _GEN := "%s/GenVariantPanel/GenVariantPanelMargin/GenVariantRows" % _CV
const _TIMING_DEBUG := "%s/TimingDebugPanel/TimingDebugPanelMargin/TimingDebugRows" % _CV
const _CHART_EDITOR := "%s/ChartEditorPanel/ChartEditorPanelMargin/ChartEditorRows" % _CV

@onready var console_header: Label = get_node("%s/ConsoleHeader" % _CONSOLE)
@onready var console_hint: Label = get_node("%s/ConsoleHint" % _CONSOLE)
@onready var debug_menu_checkbox: CheckBox = get_node("%s/DebugMenuCheckBox" % _CONSOLE)
@onready var compare_header: Label = get_node("%s/CompareHeader" % _COMPARE)
@onready var compare_hint: Label = get_node("%s/CompareHint" % _COMPARE)
@onready var split_compare_checkbox: CheckBox = get_node("%s/SplitCompareCheckBox" % _COMPARE)
@onready var compare_mode_option: OptionButton = get_node("%s/CompareModeRow/CompareModeOption" % _COMPARE)
@onready var variant_tag_edit: LineEdit = get_node("%s/VariantTagRow/VariantTagEdit" % _COMPARE)
@onready var gen_variant_header: Label = get_node("%s/GenVariantHeader" % _GEN)
@onready var gen_variant_hint: Label = get_node("%s/GenVariantHint" % _GEN)
@onready var save_experimental_checkbox: CheckBox = get_node("%s/SaveExperimentalCheckBox" % _GEN)
@onready var rhythm_dna_checkbox: CheckBox = get_node("%s/RhythmDnaCheckBox" % _GEN)
@onready var debug_header: Label = get_node("%s/TimingDebugHeader" % _TIMING_DEBUG)
@onready var debug_hint: Label = get_node("%s/TimingDebugHint" % _TIMING_DEBUG)
@onready var timing_log_checkbox: CheckBox = get_node("%s/TimingLogCheckBox" % _TIMING_DEBUG)
@onready var timing_overlay_checkbox: CheckBox = get_node("%s/TimingOverlayCheckBox" % _TIMING_DEBUG)
@onready var timing_autoplay_checkbox: CheckBox = get_node("%s/TimingAutoplayCheckBox" % _TIMING_DEBUG)
@onready var drum_colors_checkbox: CheckBox = get_node("%s/DrumColorsCheckBox" % _TIMING_DEBUG)
@onready var chart_editor_checkbox: CheckBox = get_node_or_null("%s/ChartEditorCheckBox" % _CHART_EDITOR)
@onready var test_play_checkbox: CheckBox = get_node_or_null("%s/TestPlayCheckBox" % _CHART_EDITOR)
@onready var genqa_reports_checkbox: CheckBox = get_node_or_null("%s/GenQAReportsCheckBox" % _CHART_EDITOR)
@onready var midi_samples_folder_line_edit: LineEdit = get_node_or_null("%s/MidiSamplesFolderHBox/MidiSamplesFolderLineEdit" % _CHART_EDITOR)
@onready var midi_samples_folder_dialog: FileDialog = get_node_or_null("MidiSamplesFolderDialog")

var _compare_mode_seg: Dictionary = {}
var _spotlight_tutorial: CanvasLayer = null


func _ready() -> void:
	add_to_group("locale_refresh")
	if midi_samples_folder_line_edit and not midi_samples_folder_line_edit.text_changed.is_connected(_on_midi_samples_text_changed):
		midi_samples_folder_line_edit.text_changed.connect(_on_midi_samples_text_changed)
	var choose_midi_btn: Button = get_node_or_null("%s/MidiSamplesFolderHBox/ChooseMidiSamplesFolderButton" % _CHART_EDITOR)
	if choose_midi_btn and not choose_midi_btn.pressed.is_connected(_on_choose_midi_samples_folder_pressed):
		choose_midi_btn.pressed.connect(_on_choose_midi_samples_folder_pressed)
	var open_midi_btn: Button = get_node_or_null("%s/MidiSamplesFolderHBox/OpenMidiSamplesFolderButton" % _CHART_EDITOR)
	if open_midi_btn and not open_midi_btn.pressed.is_connected(_on_open_midi_samples_folder_pressed):
		open_midi_btn.pressed.connect(_on_open_midi_samples_folder_pressed)
	if midi_samples_folder_dialog and not midi_samples_folder_dialog.dir_selected.is_connected(_on_midi_samples_folder_dir_selected):
		midi_samples_folder_dialog.dir_selected.connect(_on_midi_samples_folder_dir_selected)
	_setup_midi_folder_dialog()
	if debug_menu_checkbox and not debug_menu_checkbox.toggled.is_connected(_on_debug_menu_toggled):
		debug_menu_checkbox.toggled.connect(_on_debug_menu_toggled)
	if split_compare_checkbox and not split_compare_checkbox.toggled.is_connected(_on_setting_changed):
		split_compare_checkbox.toggled.connect(_on_setting_changed)
	if compare_mode_option:
		if compare_mode_option.item_count == 0:
			compare_mode_option.add_item("Tab swap", _COMPARE_MODE_HOTKEY_ID)
			compare_mode_option.add_item("Split screen", _COMPARE_MODE_SPLIT_ID)
	if save_experimental_checkbox and not save_experimental_checkbox.toggled.is_connected(_on_setting_changed):
		save_experimental_checkbox.toggled.connect(_on_setting_changed)
	if rhythm_dna_checkbox and not rhythm_dna_checkbox.toggled.is_connected(_on_rhythm_dna_toggled):
		rhythm_dna_checkbox.toggled.connect(_on_rhythm_dna_toggled)
	if variant_tag_edit and not variant_tag_edit.text_changed.is_connected(_on_setting_changed):
		variant_tag_edit.text_changed.connect(_on_setting_changed)
	if timing_log_checkbox and not timing_log_checkbox.toggled.is_connected(_on_setting_changed):
		timing_log_checkbox.toggled.connect(_on_setting_changed)
	if timing_overlay_checkbox and not timing_overlay_checkbox.toggled.is_connected(_on_setting_changed):
		timing_overlay_checkbox.toggled.connect(_on_setting_changed)
	if timing_autoplay_checkbox and not timing_autoplay_checkbox.toggled.is_connected(_on_setting_changed):
		timing_autoplay_checkbox.toggled.connect(_on_setting_changed)
	if drum_colors_checkbox and not drum_colors_checkbox.toggled.is_connected(_on_setting_changed):
		drum_colors_checkbox.toggled.connect(_on_setting_changed)
	if chart_editor_checkbox and not chart_editor_checkbox.toggled.is_connected(_on_chart_editor_toggled):
		chart_editor_checkbox.toggled.connect(_on_chart_editor_toggled)
	if test_play_checkbox and not test_play_checkbox.toggled.is_connected(_on_test_play_toggled):
		test_play_checkbox.toggled.connect(_on_test_play_toggled)
	if genqa_reports_checkbox and not genqa_reports_checkbox.toggled.is_connected(_on_genqa_reports_toggled):
		genqa_reports_checkbox.toggled.connect(_on_genqa_reports_toggled)
	call_deferred("_apply_initial_settings")
	call_deferred("_build_compare_mode_segmented")
	call_deferred("apply_locale")
	call_deferred("_apply_settings_checkbox_styles")


func setup_ui_and_manager(_game_screen = null) -> void:
	pass


func _build_compare_mode_segmented() -> void:
	if not _compare_mode_seg.is_empty() or compare_mode_option == null:
		return
	_compare_mode_seg = _SegmentedOptionUtils.build_from_option_button(
		compare_mode_option,
		18,
		44,
		360.0
	)
	for btn in _compare_mode_seg.get("buttons", []):
		(btn as Button).pressed.connect(_on_compare_mode_segment_pressed.bind(btn))
	_sync_compare_mode_segmented()


func _sync_compare_mode_segmented() -> void:
	var mode := SettingsManager.get_chart_compare_mode() if SettingsManager else "hotkey"
	_select_compare_mode(mode)


func _select_compare_mode(mode: String) -> void:
	if compare_mode_option == null:
		return
	var id := _COMPARE_MODE_SPLIT_ID if mode == "split" else _COMPARE_MODE_HOTKEY_ID
	for i in range(compare_mode_option.get_item_count()):
		if compare_mode_option.get_item_id(i) == id:
			compare_mode_option.select(i)
			break
	if not _compare_mode_seg.is_empty():
		_SegmentedOptionUtils.select_id(_compare_mode_seg.get("buttons", []), id, _ACCENT_SKY)


func _on_compare_mode_segment_pressed(btn: Button) -> void:
	var id := _SegmentedOptionUtils.id_from_button(btn)
	var mode := "split" if id == _COMPARE_MODE_SPLIT_ID else "hotkey"
	if SettingsManager and SettingsManager.get_chart_compare_mode() == mode:
		return
	_SegmentedOptionUtils.play_segment_select_sound()
	if SettingsManager:
		SettingsManager.set_chart_compare_mode(mode)
	_select_compare_mode(mode)
	settings_changed.emit()


func apply_locale() -> void:
	if console_header:
		console_header.text = tr("MISC_DEBUG_SECTION")
	if console_hint:
		console_hint.text = tr("SETTINGS_CONSOLE_SECTION_HINT")
	if debug_menu_checkbox:
		debug_menu_checkbox.text = tr("MISC_ENABLE_CONSOLE")
	if compare_header:
		compare_header.text = tr("EXP_COMPARE_SECTION")
	if compare_hint:
		compare_hint.text = tr("EXP_COMPARE_SECTION_HINT")
	if split_compare_checkbox:
		split_compare_checkbox.text = tr("EXP_CHART_COMPARE_ENABLE")
	if debug_header:
		debug_header.text = tr("EXP_DEBUG_SECTION")
	if debug_hint:
		debug_hint.text = tr("EXP_DEBUG_SECTION_HINT")
	if timing_log_checkbox:
		timing_log_checkbox.text = tr("EXP_TIMING_DEBUG_LOG")
	if timing_overlay_checkbox:
		timing_overlay_checkbox.text = tr("EXP_TIMING_DEBUG_OVERLAY")
	if timing_autoplay_checkbox:
		timing_autoplay_checkbox.text = tr("EXP_TIMING_DEBUG_AUTOPLAY")
	if drum_colors_checkbox:
		drum_colors_checkbox.text = tr("EXP_DRUM_CLASS_COLORS")
	if compare_mode_option:
		compare_mode_option.set_item_text(0, tr("EXP_COMPARE_MODE_HOTKEY"))
		compare_mode_option.set_item_text(1, tr("EXP_COMPARE_MODE_SPLIT"))
	if not _compare_mode_seg.is_empty():
		_SegmentedOptionUtils.apply_texts(
			_compare_mode_seg.get("buttons", []),
			PackedStringArray([tr("EXP_COMPARE_MODE_HOTKEY"), tr("EXP_COMPARE_MODE_SPLIT")])
		)
	var mode_label: Label = get_node_or_null("%s/CompareModeRow/CompareModeLabel" % _COMPARE)
	if mode_label:
		mode_label.text = tr("EXP_COMPARE_MODE_LABEL")
	if gen_variant_header:
		gen_variant_header.text = tr("EXP_GEN_VARIANT_SECTION")
	if gen_variant_hint:
		gen_variant_hint.text = tr("EXP_GEN_VARIANT_SECTION_HINT")
	if save_experimental_checkbox:
		save_experimental_checkbox.text = tr("EXP_SAVE_EXPERIMENTAL_CHART")
	if rhythm_dna_checkbox:
		rhythm_dna_checkbox.text = tr("EXP_SHOW_RHYTHM_DNA_BUTTON")
	var tag_label: Label = get_node_or_null("%s/VariantTagRow/VariantTagLabel" % _COMPARE)
	if tag_label:
		tag_label.text = tr("EXP_VARIANT_TAG_LABEL")
	var chart_header: Label = get_node_or_null("%s/ChartEditorHeader" % _CHART_EDITOR)
	if chart_header:
		chart_header.text = tr("EXP_CHART_EDITOR_HEADER")
	var chart_hint: Label = get_node_or_null("%s/ChartEditorHint" % _CHART_EDITOR)
	if chart_hint:
		chart_hint.text = tr("EXP_CHART_EDITOR_HINT")
	if chart_editor_checkbox:
		chart_editor_checkbox.text = tr("EXP_CHART_EDITOR_ENABLE")
	if test_play_checkbox:
		var _tp_text := tr("EXP_TEST_PLAY_ENABLE")
		test_play_checkbox.text = _tp_text if _tp_text != "EXP_TEST_PLAY_ENABLE" else "Показывать «Test Play» при нажатии ПКМ на «Играть»"
	if genqa_reports_checkbox:
		genqa_reports_checkbox.text = tr("EXP_GENQA_REPORTS_ENABLE")
	_apply_tooltips()
	_sync_compare_mode_segmented()


func _apply_settings_checkbox_styles() -> void:
	const ACCENT := Color(0.52, 0.76, 0.92, 1.0)
	_SettingsSectionUi.apply_settings_checkbox(debug_menu_checkbox, 22, false, ACCENT)
	_SettingsSectionUi.apply_settings_checkbox(split_compare_checkbox, 22, false, ACCENT)
	_SettingsSectionUi.apply_settings_checkbox(save_experimental_checkbox, 22, false, ACCENT)
	_SettingsSectionUi.apply_settings_checkbox(rhythm_dna_checkbox, 22, false, ACCENT)
	_SettingsSectionUi.apply_settings_checkbox(timing_log_checkbox, 22, false, ACCENT)
	_SettingsSectionUi.apply_settings_checkbox(timing_overlay_checkbox, 22, false, ACCENT)
	_SettingsSectionUi.apply_settings_checkbox(timing_autoplay_checkbox, 22, false, ACCENT)
	_SettingsSectionUi.apply_settings_checkbox(drum_colors_checkbox, 22, false, ACCENT)
	if chart_editor_checkbox:
		_SettingsSectionUi.apply_settings_checkbox(chart_editor_checkbox, 22, false, ACCENT)
	if test_play_checkbox:
		_SettingsSectionUi.apply_settings_checkbox(test_play_checkbox, 22, false, ACCENT)
	if genqa_reports_checkbox:
		_SettingsSectionUi.apply_settings_checkbox(genqa_reports_checkbox, 22, false, ACCENT)


func _apply_tooltips() -> void:
	if debug_menu_checkbox:
		debug_menu_checkbox.tooltip_text = tr("MISC_ENABLE_CONSOLE_TOOLTIP")
	if split_compare_checkbox:
		split_compare_checkbox.tooltip_text = tr("EXP_CHART_COMPARE_ENABLE_TOOLTIP")
	if compare_mode_option:
		compare_mode_option.tooltip_text = tr("EXP_COMPARE_MODE_TOOLTIP")
	if save_experimental_checkbox:
		save_experimental_checkbox.tooltip_text = tr("EXP_SAVE_EXPERIMENTAL_CHART_TOOLTIP")
	if rhythm_dna_checkbox:
		rhythm_dna_checkbox.tooltip_text = tr("EXP_SHOW_RHYTHM_DNA_BUTTON_TOOLTIP")
	if variant_tag_edit:
		variant_tag_edit.tooltip_text = tr("EXP_VARIANT_TAG_TOOLTIP")
	if timing_log_checkbox:
		timing_log_checkbox.tooltip_text = tr("EXP_TIMING_DEBUG_LOG_TOOLTIP")
	if timing_overlay_checkbox:
		timing_overlay_checkbox.tooltip_text = tr("EXP_TIMING_DEBUG_OVERLAY_TOOLTIP")
	if timing_autoplay_checkbox:
		timing_autoplay_checkbox.tooltip_text = tr("EXP_TIMING_DEBUG_AUTOPLAY_TOOLTIP")
	if drum_colors_checkbox:
		drum_colors_checkbox.tooltip_text = tr("EXP_DRUM_CLASS_COLORS_TOOLTIP")
	if chart_editor_checkbox:
		chart_editor_checkbox.tooltip_text = tr("EXP_CHART_EDITOR_ENABLE_TOOLTIP")
	if test_play_checkbox:
		var _tp_tip := tr("EXP_TEST_PLAY_ENABLE_TOOLTIP")
		test_play_checkbox.tooltip_text = _tp_tip if _tp_tip != "EXP_TEST_PLAY_ENABLE_TOOLTIP" else tr("EXP_CHART_EDITOR_ENABLE_TOOLTIP")
	if genqa_reports_checkbox:
		genqa_reports_checkbox.tooltip_text = tr("EXP_GENQA_REPORTS_ENABLE_TOOLTIP")


func _apply_initial_settings() -> void:
	if debug_menu_checkbox:
		debug_menu_checkbox.set_pressed_no_signal(SettingsManager.get_enable_debug_menu())
	_apply_console_state_from_settings()
	if split_compare_checkbox:
		split_compare_checkbox.button_pressed = SettingsManager.get_chart_compare_enabled()
	_select_compare_mode(SettingsManager.get_chart_compare_mode() if SettingsManager else "hotkey")
	if save_experimental_checkbox:
		save_experimental_checkbox.button_pressed = bool(SettingsManager.get_setting("generation_save_experimental_chart", false))
	if rhythm_dna_checkbox:
		rhythm_dna_checkbox.button_pressed = bool(SettingsManager.get_setting("show_rhythm_dna_button", false))
	if variant_tag_edit:
		variant_tag_edit.text = String(SettingsManager.get_setting("split_compare_variant_tag", "exp"))
	if timing_log_checkbox:
		timing_log_checkbox.button_pressed = SettingsManager.get_timing_debug_log_hits()
	if timing_overlay_checkbox:
		timing_overlay_checkbox.button_pressed = SettingsManager.get_timing_debug_overlay()
	if timing_autoplay_checkbox:
		timing_autoplay_checkbox.button_pressed = SettingsManager.get_autoplay_respects_hit_windows()
	if drum_colors_checkbox:
		drum_colors_checkbox.button_pressed = SettingsManager.get_show_drum_class_colors()
	if chart_editor_checkbox:
		chart_editor_checkbox.button_pressed = SettingsManager.get_chart_editor_enabled() if SettingsManager and SettingsManager.has_method("get_chart_editor_enabled") else false
	if test_play_checkbox:
		test_play_checkbox.button_pressed = SettingsManager.get_chart_editor_test_play_enabled() if SettingsManager and SettingsManager.has_method("get_chart_editor_test_play_enabled") else false
	if genqa_reports_checkbox:
		genqa_reports_checkbox.button_pressed = SettingsManager.get_genqa_reports_enabled() if SettingsManager and SettingsManager.has_method("get_genqa_reports_enabled") else true
	if midi_samples_folder_line_edit:
		var mp := String(SettingsManager.get_midi_samples_path() if SettingsManager.has_method("get_midi_samples_path") else SettingsManager.get_setting("midi_samples_path", "user://midi"))
		if mp.strip_edges() == "":
			mp = "user://midi"
		# Display default as user://midi/ (with trailing slash) to match replay's user://replays/
		if mp == "user://midi":
			mp = "user://midi/"
		midi_samples_folder_line_edit.text = mp


func refresh_ui() -> void:
	_apply_initial_settings()


func _on_setting_changed(_arg = null) -> void:
	if split_compare_checkbox:
		SettingsManager.set_chart_compare_enabled(split_compare_checkbox.button_pressed)
	if save_experimental_checkbox:
		SettingsManager.set_setting("generation_save_experimental_chart", save_experimental_checkbox.button_pressed)
	if variant_tag_edit:
		var tag := NotesUtils.normalize_chart_tag(variant_tag_edit.text)
		if tag == "":
			tag = "exp"
			variant_tag_edit.text = tag
		SettingsManager.set_setting("split_compare_variant_tag", tag)
	if timing_log_checkbox:
		SettingsManager.set_timing_debug_log_hits(timing_log_checkbox.button_pressed)
	if timing_overlay_checkbox:
		SettingsManager.set_timing_debug_overlay(timing_overlay_checkbox.button_pressed)
	if timing_autoplay_checkbox:
		SettingsManager.set_autoplay_respects_hit_windows(timing_autoplay_checkbox.button_pressed)
	if drum_colors_checkbox:
		SettingsManager.set_show_drum_class_colors(drum_colors_checkbox.button_pressed)
	settings_changed.emit()


func _on_chart_editor_toggled(enabled: bool) -> void:
	if SettingsManager and SettingsManager.has_method("set_chart_editor_enabled"):
		SettingsManager.set_chart_editor_enabled(enabled)
	settings_changed.emit()


func _on_test_play_toggled(enabled: bool) -> void:
	if SettingsManager and SettingsManager.has_method("set_chart_editor_test_play_enabled"):
		SettingsManager.set_chart_editor_test_play_enabled(enabled)
	else:
		SettingsManager.set_setting("chart_editor_test_play_enabled", enabled)
	settings_changed.emit()


func _on_genqa_reports_toggled(enabled: bool) -> void:
	if SettingsManager and SettingsManager.has_method("set_genqa_reports_enabled"):
		SettingsManager.set_genqa_reports_enabled(enabled)
	settings_changed.emit()


func _on_rhythm_dna_toggled(enabled: bool) -> void:
	SettingsManager.set_setting("show_rhythm_dna_button", enabled)
	settings_changed.emit()
	_call_refresh_rhythm_dna_button_recursive(get_tree().root)
	if enabled:
		call_deferred("_maybe_show_rhythm_dna_setting_tutorial")


func _maybe_show_rhythm_dna_setting_tutorial(force: bool = false) -> void:
	if FirstStepsManager and FirstStepsManager.is_active():
		return
	if not SettingsManager or not SettingsManager.has_method("get_tutorial_rhythm_dna_setting_done"):
		return
	if not force and SettingsManager.get_tutorial_rhythm_dna_setting_done():
		return
	if not is_visible_in_tree():
		return
	if _spotlight_tutorial == null:
		_spotlight_tutorial = _SpotlightTutorialScene.instantiate() as CanvasLayer
		if _spotlight_tutorial == null:
			return
		add_child(_spotlight_tutorial)
		if not _spotlight_tutorial.finished.is_connected(_on_rhythm_dna_setting_tutorial_closed):
			_spotlight_tutorial.finished.connect(_on_rhythm_dna_setting_tutorial_closed)
		if not _spotlight_tutorial.skipped.is_connected(_on_rhythm_dna_setting_tutorial_closed):
			_spotlight_tutorial.skipped.connect(_on_rhythm_dna_setting_tutorial_closed)
	var steps: Array = [
		{
			"title_key": "TUTORIAL_DNA_SET_1_TITLE",
			"body_key": "TUTORIAL_DNA_SET_1_BODY",
			"target": rhythm_dna_checkbox,
		},
		{
			"title_key": "TUTORIAL_DNA_SET_2_TITLE",
			"body_key": "TUTORIAL_DNA_SET_2_BODY",
			"target": rhythm_dna_checkbox,
		},
	]
	if _spotlight_tutorial.has_method("start"):
		_spotlight_tutorial.start(steps)


func _on_rhythm_dna_setting_tutorial_closed() -> void:
	if SettingsManager and SettingsManager.has_method("set_tutorial_rhythm_dna_setting_done"):
		SettingsManager.set_tutorial_rhythm_dna_setting_done(true)


func debug_show_rhythm_dna_tutorial() -> void:
	_maybe_show_rhythm_dna_setting_tutorial(true)


func debug_show_tutorial() -> void:
	_maybe_show_rhythm_dna_setting_tutorial(true)


func _call_refresh_rhythm_dna_button_recursive(node: Node) -> void:
	if node == null:
		return
	if node.has_method("refresh_rhythm_dna_button_visibility"):
		node.refresh_rhythm_dna_button_visibility()
	for child in node.get_children():
		_call_refresh_rhythm_dna_button_recursive(child)


func _setup_midi_folder_dialog() -> void:
	if midi_samples_folder_dialog == null:
		return
	midi_samples_folder_dialog.use_native_dialog = true
	midi_samples_folder_dialog.access = FileDialog.ACCESS_FILESYSTEM
	midi_samples_folder_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	midi_samples_folder_dialog.unresizable = true

func _on_choose_midi_samples_folder_pressed() -> void:
	if midi_samples_folder_dialog == null:
		return
	var cur := String(SettingsManager.get_midi_samples_path() if SettingsManager.has_method("get_midi_samples_path") else SettingsManager.get_setting("midi_samples_path", "user://midi"))
	if cur.strip_edges() == "":
		cur = "user://midi"
	if cur.begins_with("user://") or cur.begins_with("res://"):
		cur = ProjectSettings.globalize_path(cur)
	midi_samples_folder_dialog.current_dir = cur
	midi_samples_folder_dialog.popup_centered()

func _on_open_midi_samples_folder_pressed() -> void:
	var path := String(SettingsManager.get_midi_samples_path() if SettingsManager.has_method("get_midi_samples_path") else SettingsManager.get_setting("midi_samples_path", "user://midi"))
	if path.strip_edges() == "":
		path = "user://midi"
	if path.begins_with("user://") or path.begins_with("res://"):
		path = ProjectSettings.globalize_path(path)
	path = path.replace("\\", "/")
	DirAccess.make_dir_recursive_absolute(path)
	OS.shell_open(path)

func _on_midi_samples_folder_dir_selected(path: String) -> void:
	if midi_samples_folder_dialog and is_instance_valid(midi_samples_folder_dialog) and midi_samples_folder_dialog.visible:
		midi_samples_folder_dialog.hide()
	path = String(path).strip_edges().replace("\\", "/")
	if path == "":
		return
	if SettingsManager.has_method("set_midi_samples_path"):
		SettingsManager.set_midi_samples_path(path)
	else:
		SettingsManager.set_setting("midi_samples_path", path)
		SettingsManager.save_settings()
	if midi_samples_folder_line_edit:
		midi_samples_folder_line_edit.text = path
	settings_changed.emit()

func _on_midi_samples_text_changed(new_text: String) -> void:
	var p := String(new_text).strip_edges().replace("\\", "/")
	if p == "":
		return
	# Defer save until focus lost? For now save on change
	if SettingsManager.has_method("set_midi_samples_path"):
		SettingsManager.set_midi_samples_path(p)
	else:
		SettingsManager.set_setting("midi_samples_path", p)
		SettingsManager.save_settings()
	settings_changed.emit()

func _on_debug_menu_toggled(enabled: bool) -> void:
	SettingsManager.set_enable_debug_menu(enabled)
	_apply_console_state_from_settings()
	settings_changed.emit()


func _apply_console_state_from_settings() -> void:
	var console_node = get_tree().root.get_node_or_null("Console")
	if console_node:
		if SettingsManager.get_enable_debug_menu():
			if console_node.has_method("enable"):
				console_node.enable()
		else:
			if console_node.has_method("disable"):
				console_node.disable()
