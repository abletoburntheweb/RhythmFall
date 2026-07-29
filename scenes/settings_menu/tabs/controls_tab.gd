# scenes/settings_menu/tabs/controls_tab.gd
extends Control

signal settings_changed

const ControlsBindings = preload("res://scenes/settings_menu/lib/controls_bindings.gd")
const _GuitarHeroBindings = preload("res://logic/domain/controls/guitar_hero_bindings.gd")
const _OptionButtonPopupUtils = preload("res://logic/ui/option_button_popup_utils.gd")
const _StatusToast = preload("res://logic/ui/status_toast.gd")
const _SettingsSectionUi = preload("res://logic/ui/settings_section_ui.gd")
const _CONTENT := "ScrollWrap/CenterWrap/ContentVBox"
const _LAYOUT := "%s/LayoutPanel/LayoutPanelMargin/LayoutRows" % _CONTENT
const _PANEL_VBOX := "%s/KeysPanel/KeysPanelMargin/KeysPanelVBox" % _CONTENT
const _PRIMARY_KEYS := "%s/KeysColumnsHBox/PrimaryColumn" % _PANEL_VBOX
const _ALT_KEYS := "%s/KeysColumnsHBox/AltColumn" % _PANEL_VBOX

@onready var _primary_keys: VBoxContainer = get_node(_PRIMARY_KEYS)
@onready var _alt_keys: VBoxContainer = get_node(_ALT_KEYS)
@onready var layout_mode_option: OptionButton = get_node("%s/LayoutModeOption" % _LAYOUT)
@onready var layout_header: Label = get_node("%s/LayoutHeader" % _LAYOUT)
@onready var layout_hint: Label = get_node("%s/LayoutHint" % _LAYOUT)
@onready var section_header: Label = get_node("%s/SectionHeader" % _PANEL_VBOX)
@onready var keys_hint: Label = get_node("%s/KeysHint" % _PANEL_VBOX)
@onready var reset_controls_button: Button = get_node("%s/ResetControlsButton" % _PANEL_VBOX)
@onready var hint_label: Label = get_node("%s/HintLabel" % _CONTENT)

var game_screen = null
var _binding_buttons: Dictionary = {}
var _remap_active: bool = false
var _remap_target_id: String = ""
var _remap_target_button: Button = null
var _remap_old_scancode: int = 0

var _gh_panel: PanelContainer = null
var _gh_header: Label = null
var _gh_help_btn: Button = null
var _gh_hint: Label = null
var _gh_enable_check: CheckBox = null
var _gh_auto_detect_check: CheckBox = null
var _gh_device_option: OptionButton = null
var _gh_status_label: Label = null
var _gh_reset_button: Button = null
var _gh_refresh_button: Button = null
var _gh_binding_buttons: Dictionary = {}
var _gh_remap_active: bool = false
var _gh_remap_target_id: String = ""
var _gh_remap_target_button: Button = null
var _gh_remap_old_button: int = 0
var _gh_test_label: Label = null
var _gh_test_hint: Label = null
var _gh_fret_indicators: Array[ColorRect] = []
var _gh_test_lane_labels: Array[Label] = []
var _gh_fret_row_labels: Array[Label] = []
var _gh_last_toast_device_id: int = -2

func _ready() -> void:
	add_to_group("locale_refresh")
	if not Input.joy_connection_changed.is_connected(_on_gh_joy_connection_changed):
		Input.joy_connection_changed.connect(_on_gh_joy_connection_changed)
	call_deferred("_build_gh_ui")
	call_deferred("_build_bindings_ui")
	call_deferred("_setup_layout_option_popup_font")
	call_deferred("apply_locale")


func setup_ui_and_manager(screen = null) -> void:
	game_screen = screen
	_refresh_binding_labels()


func apply_locale() -> void:
	if section_header:
		section_header.text = tr("CONTROLS_KEYMAP")
	if keys_hint:
		keys_hint.text = tr("CONTROLS_DESC")
	if layout_header:
		layout_header.text = tr("CONTROLS_LAYOUT_MODE")
	if layout_hint:
		layout_hint.text = tr("CONTROLS_LAYOUT_DESC")
	if reset_controls_button:
		reset_controls_button.text = tr("CONTROLS_RESET_KEYS")
	if hint_label:
		hint_label.text = _controls_hint_text()
	_populate_layout_mode_option()
	if not _remap_active and not _gh_remap_active:
		_build_bindings_ui()
	_refresh_gh_ui()


func _controls_hint_text() -> String:
	if _gh_remap_active:
		return tr("CONTROLS_GH_HINT")
	if _remap_active:
		return tr("CONTROLS_HINT")
	return tr("CONTROLS_HINT")


func _build_gh_ui() -> void:
	if _gh_panel != null:
		return
	var content := get_node_or_null(_CONTENT)
	var keys_panel := get_node_or_null("%s/KeysPanel" % _CONTENT)
	if content == null or keys_panel == null:
		return

	_gh_panel = PanelContainer.new()
	_gh_panel.theme_type_variation = &"SectionPanelPink"

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	_gh_panel.add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 14)
	margin.add_child(rows)

	_gh_header = Label.new()
	_gh_header.theme_type_variation = &"SectionHeaderPink"
	_gh_header.add_theme_font_size_override("font_size", 22)
	rows.add_child(_gh_header)
	_ensure_gh_help_icon()

	_gh_hint = Label.new()
	_gh_hint.add_theme_color_override("font_color", Color(0.58, 0.66, 0.78, 0.92))
	_gh_hint.add_theme_font_size_override("font_size", 14)
	_gh_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_gh_hint)

	_gh_enable_check = CheckBox.new()
	_gh_enable_check.add_theme_font_size_override("font_size", 18)
	_gh_enable_check.toggled.connect(_on_gh_enable_toggled)
	_SettingsSectionUi.apply_settings_checkbox(_gh_enable_check, 18)
	rows.add_child(_gh_enable_check)

	_gh_auto_detect_check = CheckBox.new()
	_gh_auto_detect_check.add_theme_font_size_override("font_size", 18)
	_gh_auto_detect_check.toggled.connect(_on_gh_auto_detect_toggled)
	_SettingsSectionUi.apply_settings_checkbox(_gh_auto_detect_check, 18)
	rows.add_child(_gh_auto_detect_check)

	var device_row := HBoxContainer.new()
	device_row.add_theme_constant_override("separation", 12)
	var device_label := Label.new()
	device_label.name = "GhDeviceLabel"
	device_label.add_theme_font_size_override("font_size", 18)
	device_row.add_child(device_label)
	_gh_device_option = OptionButton.new()
	_gh_device_option.custom_minimum_size = Vector2(420, 50)
	_gh_device_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if layout_mode_option:
		_gh_device_option.theme = layout_mode_option.theme
		_gh_device_option.theme_type_variation = layout_mode_option.theme_type_variation
		_gh_device_option.add_theme_font_size_override("font_size", 20)
		_OptionButtonPopupUtils.apply_popup_font_size(_gh_device_option, 20)
	_gh_device_option.item_selected.connect(_on_gh_device_selected)
	device_row.add_child(_gh_device_option)
	rows.add_child(device_row)

	_gh_status_label = Label.new()
	_gh_status_label.add_theme_font_size_override("font_size", 16)
	_gh_status_label.add_theme_color_override("font_color", Color(0.72, 0.78, 0.9, 0.95))
	_gh_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_gh_status_label)

	_add_subheader(rows, tr("CONTROLS_GH_FRETS"))
	for lane in range(_GuitarHeroBindings.MAX_LANES):
		_add_gh_fret_binding_row(
			rows,
			"gh:lane:%d" % lane,
			_GuitarHeroBindings.lane_row_label(lane),
			_GuitarHeroBindings.lane_color(lane)
		)

	_add_subheader(rows, tr("CONTROLS_GH_STRAM"))
	_add_gh_binding_row(rows, "gh:strum_up", tr("CONTROLS_GH_STRAM_UP"))
	_add_gh_binding_row(rows, "gh:strum_down", tr("CONTROLS_GH_STRAM_DOWN"))

	_add_subheader(rows, tr("CONTROLS_GH_SYSTEM"))
	_add_gh_binding_row(rows, "gh:pause", tr("CONTROLS_GH_PAUSE"))
	_add_gh_binding_row(rows, "gh:skip", tr("CONTROLS_GH_SKIP"))

	_add_subheader(rows, tr("CONTROLS_GH_TEST"))
	_gh_test_hint = Label.new()
	_gh_test_hint.add_theme_font_size_override("font_size", 14)
	_gh_test_hint.add_theme_color_override("font_color", Color(0.58, 0.66, 0.78, 0.92))
	_gh_test_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_gh_test_hint)
	var fret_test_row := HBoxContainer.new()
	fret_test_row.add_theme_constant_override("separation", 10)
	for lane in range(_GuitarHeroBindings.MAX_LANES):
		var lane_test_col := VBoxContainer.new()
		lane_test_col.add_theme_constant_override("separation", 4)
		lane_test_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var indicator := ColorRect.new()
		indicator.custom_minimum_size = Vector2(0, 18)
		indicator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		indicator.color = Color(_GuitarHeroBindings.lane_color(lane), 0.22)
		lane_test_col.add_child(indicator)
		var lane_label := Label.new()
		lane_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lane_label.add_theme_font_size_override("font_size", 12)
		lane_label.add_theme_color_override("font_color", _GuitarHeroBindings.lane_color(lane))
		lane_label.text = _GuitarHeroBindings.lane_row_label(lane)
		lane_test_col.add_child(lane_label)
		fret_test_row.add_child(lane_test_col)
		_gh_fret_indicators.append(indicator)
		_gh_test_lane_labels.append(lane_label)
	rows.add_child(fret_test_row)
	_gh_test_label = Label.new()
	_gh_test_label.add_theme_font_size_override("font_size", 18)
	_gh_test_label.text = "—"
	rows.add_child(_gh_test_label)

	var gh_buttons := HBoxContainer.new()
	gh_buttons.add_theme_constant_override("separation", 12)
	_gh_refresh_button = Button.new()
	_gh_refresh_button.custom_minimum_size = Vector2(220, 44)
	_gh_refresh_button.add_theme_font_size_override("font_size", 18)
	_gh_refresh_button.pressed.connect(_on_gh_refresh_pressed)
	gh_buttons.add_child(_gh_refresh_button)
	_gh_reset_button = Button.new()
	_gh_reset_button.custom_minimum_size = Vector2(280, 50)
	_gh_reset_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if reset_controls_button:
		_gh_reset_button.theme = reset_controls_button.theme
		_gh_reset_button.theme_type_variation = reset_controls_button.theme_type_variation
		_gh_reset_button.add_theme_font_size_override("font_size", 20)
	_gh_reset_button.pressed.connect(_on_gh_reset_pressed)
	gh_buttons.add_child(_gh_reset_button)
	rows.add_child(gh_buttons)

	var gh_panel_idx := keys_panel.get_index() + 1
	content.add_child(_gh_panel)
	content.move_child(_gh_panel, gh_panel_idx)
	_refresh_gh_ui()


func _add_gh_fret_binding_row(
	column: VBoxContainer,
	binding_id: String,
	action_text: String,
	action_color: Color
) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var action_label := Label.new()
	action_label.text = action_text
	action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_label.add_theme_font_size_override("font_size", 20)
	action_label.add_theme_color_override("font_color", action_color)
	var key_button := Button.new()
	key_button.custom_minimum_size = Vector2(160, 44)
	key_button.add_theme_font_size_override("font_size", 20)
	key_button.pressed.connect(_on_gh_binding_button_pressed.bind(binding_id))
	row.add_child(action_label)
	row.add_child(key_button)
	column.add_child(row)
	_gh_binding_buttons[binding_id] = key_button
	_gh_fret_row_labels.append(action_label)


func _add_gh_binding_row(column: VBoxContainer, binding_id: String, action_text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var action_label := Label.new()
	action_label.text = action_text
	action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_label.add_theme_font_size_override("font_size", 20)
	var key_button := Button.new()
	key_button.custom_minimum_size = Vector2(140, 44)
	key_button.add_theme_font_size_override("font_size", 20)
	key_button.pressed.connect(_on_gh_binding_button_pressed.bind(binding_id))
	row.add_child(action_label)
	row.add_child(key_button)
	column.add_child(row)
	_gh_binding_buttons[binding_id] = key_button


func _ensure_gh_help_icon() -> void:
	if _gh_header == null:
		return
	_gh_help_btn = _SettingsSectionUi.attach_help_icon_beside_label(
		_gh_header,
		tr("HELP_LINK_GUITAR_HERO"),
		_on_gh_help_pressed,
		false
	)


func _on_gh_help_pressed() -> void:
	var node: Node = self
	while node:
		if node.has_method("open_help_item"):
			node.open_help_item("guitar_hero_controller")
			return
		if node.has_method("get_transitions"):
			var trans = node.get_transitions()
			if trans and trans.has_method("open_help_item"):
				trans.open_help_item("guitar_hero_controller")
				return
		node = node.get_parent()


func _refresh_gh_ui() -> void:
	if _gh_panel == null:
		return
	if _gh_header:
		_gh_header.text = tr("CONTROLS_GH_SECTION")
	if _gh_help_btn:
		_gh_help_btn.tooltip_text = tr("HELP_LINK_GUITAR_HERO")
	if _gh_hint:
		_gh_hint.text = tr("CONTROLS_GH_DESC")
	if _gh_enable_check:
		_gh_enable_check.text = tr("CONTROLS_GH_ENABLE")
		_gh_enable_check.set_block_signals(true)
		_gh_enable_check.button_pressed = SettingsManager.get_controls_gh_enabled()
		_gh_enable_check.set_block_signals(false)
	if _gh_auto_detect_check:
		_gh_auto_detect_check.text = tr("CONTROLS_GH_AUTO_DETECT")
		_gh_auto_detect_check.set_block_signals(true)
		_gh_auto_detect_check.button_pressed = SettingsManager.get_controls_gh_auto_detect()
		_gh_auto_detect_check.set_block_signals(false)
	if _gh_test_hint:
		_gh_test_hint.text = tr("CONTROLS_GH_TEST_HINT")
	if _gh_test_label and not _gh_remap_active:
		_gh_test_label.text = tr("CONTROLS_GH_TEST_IDLE")
	if _gh_reset_button:
		_gh_reset_button.text = tr("CONTROLS_GH_RESET_KEYS")
	if _gh_refresh_button:
		_gh_refresh_button.text = tr("CONTROLS_GH_REFRESH")
	for lane in range(_gh_fret_row_labels.size()):
		var fret_label: Label = _gh_fret_row_labels[lane]
		if fret_label:
			fret_label.text = _GuitarHeroBindings.lane_row_label(lane)
	for lane in range(_gh_test_lane_labels.size()):
		var lane_label: Label = _gh_test_lane_labels[lane]
		if lane_label:
			lane_label.text = _GuitarHeroBindings.lane_row_label(lane)
	var device_label := _gh_panel.find_child("GhDeviceLabel", true, false)
	if device_label is Label:
		device_label.text = tr("CONTROLS_GH_DEVICE")
	_populate_gh_device_option()
	_refresh_gh_binding_labels()
	_update_gh_status_label()
	_update_gh_section_enabled()


func _update_gh_section_enabled() -> void:
	var enabled := SettingsManager.get_controls_gh_enabled()
	for node in [
		_gh_auto_detect_check,
		_gh_device_option,
		_gh_reset_button,
		_gh_refresh_button,
	]:
		if node:
			node.disabled = not enabled
	if _gh_status_label:
		_gh_status_label.modulate = Color(1, 1, 1, 1 if enabled else 0.55)
	for button in _gh_binding_buttons.values():
		if button:
			button.disabled = not enabled


func _populate_gh_device_option() -> void:
	if _gh_device_option == null:
		return
	var selected := SettingsManager.get_controls_gh_device_id()
	var selected_idx := 0
	_gh_device_option.set_block_signals(true)
	_gh_device_option.clear()
	_gh_device_option.add_item(tr("CONTROLS_GH_DEVICE_AUTO"), 0)
	_gh_device_option.set_item_metadata(0, -1)
	var resolved := SettingsManager.resolve_gh_device_id()
	for device_id in Input.get_connected_joypads():
		var device_name := Input.get_joy_name(device_id)
		if device_id == resolved and SettingsManager.get_controls_gh_device_id() < 0:
			device_name += " ✓"
		elif _GuitarHeroBindings.is_likely_guitar_device(device_id):
			device_name += " *"
		var idx := _gh_device_option.item_count
		_gh_device_option.add_item(device_name, idx)
		_gh_device_option.set_item_metadata(idx, device_id)
		if device_id == selected:
			selected_idx = idx
	_gh_device_option.select(selected_idx)
	_gh_device_option.set_block_signals(false)


func _update_gh_status_label() -> void:
	if _gh_status_label == null:
		return
	if not SettingsManager.get_controls_gh_enabled():
		_gh_status_label.text = tr("CONTROLS_GH_STATUS_DISABLED")
		return
	var device_id := SettingsManager.resolve_gh_device_id()
	if device_id < 0:
		_gh_status_label.text = tr("CONTROLS_GH_STATUS") % tr("CONTROLS_GH_DEVICE_NONE")
		return
	var device_name := Input.get_joy_name(device_id)
	if _GuitarHeroBindings.is_likely_guitar_device(device_id):
		device_name += " (%s)" % tr("CONTROLS_GH_DETECTED")
	_gh_status_label.text = tr("CONTROLS_GH_STATUS") % device_name


func _refresh_gh_binding_labels() -> void:
	for binding_id in _gh_binding_buttons:
		var button: Button = _gh_binding_buttons[binding_id]
		if button:
			button.text = _gh_binding_label_for(binding_id)


func _gh_binding_label_for(binding_id: String) -> String:
	var parts := binding_id.split(":")
	if parts.size() < 2:
		return "?"
	match parts[1]:
		"lane":
			if parts.size() < 3:
				return "?"
			var lane := int(parts[2])
			return _GuitarHeroBindings.lane_button_label(
				lane,
				SettingsManager.get_controls_gh_lane_button(lane)
			)
		"strum_up":
			return SettingsManager.get_controls_gh_strum_up_text()
		"strum_down":
			return SettingsManager.get_controls_gh_strum_down_text()
		"pause":
			return SettingsManager.get_controls_gh_pause_text()
		"skip":
			return SettingsManager.get_controls_gh_skip_text()
		_:
			return "?"


func _gh_button_for_binding(binding_id: String) -> int:
	var parts := binding_id.split(":")
	if parts.size() < 2:
		return -1
	match parts[1]:
		"lane":
			if parts.size() < 3:
				return -1
			return SettingsManager.get_controls_gh_lane_button(int(parts[2]))
		"strum_up":
			return SettingsManager.get_controls_gh_strum_up_button()
		"strum_down":
			return SettingsManager.get_controls_gh_strum_down_button()
		"pause":
			return SettingsManager.get_controls_gh_pause_button()
		"skip":
			return SettingsManager.get_controls_gh_skip_button()
		_:
			return -1


func _set_gh_button_for_binding(binding_id: String, button_index: int) -> void:
	var parts := binding_id.split(":")
	if parts.size() < 2:
		return
	match parts[1]:
		"lane":
			if parts.size() >= 3:
				SettingsManager.set_controls_gh_lane_button(int(parts[2]), button_index)
		"strum_up":
			SettingsManager.set_controls_gh_strum_up_button(button_index)
		"strum_down":
			SettingsManager.set_controls_gh_strum_down_button(button_index)
		"pause":
			SettingsManager.set_controls_gh_pause_button(button_index)
		"skip":
			SettingsManager.set_controls_gh_skip_button(button_index)


func _on_gh_joy_connection_changed(_device: int, connected: bool) -> void:
	_populate_gh_device_option()
	_update_gh_status_label()
	if connected and SettingsManager.get_controls_gh_enabled():
		var resolved := SettingsManager.resolve_gh_device_id()
		if resolved >= 0 and resolved != _gh_last_toast_device_id:
			_gh_last_toast_device_id = resolved
			_StatusToast.show_from_node(
				self,
				"gh_detected_%d" % resolved,
				tr("CONTROLS_GH_TOAST_DETECTED") % Input.get_joy_name(resolved),
				"info",
				3.0
			)


func _gh_test_input_allowed() -> bool:
	return SettingsManager.get_controls_gh_enabled() and not _gh_remap_active and not _remap_active


func _describe_gh_press(button_index: int) -> String:
	for lane in range(_GuitarHeroBindings.MAX_LANES):
		if SettingsManager.get_controls_gh_lane_button(lane) == button_index:
			return _GuitarHeroBindings.lane_row_label(lane)
	if button_index == SettingsManager.get_controls_gh_strum_up_button():
		return tr("CONTROLS_GH_STRAM_UP")
	if button_index == SettingsManager.get_controls_gh_strum_down_button():
		return tr("CONTROLS_GH_STRAM_DOWN")
	if button_index == SettingsManager.get_controls_gh_pause_button():
		return tr("CONTROLS_GH_PAUSE")
	if button_index == SettingsManager.get_controls_gh_skip_button():
		return tr("CONTROLS_GH_SKIP")
	return _GuitarHeroBindings.button_display_name(button_index)


func _update_gh_test_feedback(event: InputEventJoypadButton) -> void:
	var device_id := SettingsManager.resolve_gh_device_id()
	if device_id < 0 or event.device != device_id:
		return
	_refresh_gh_test_indicators(device_id)
	if _gh_test_label == null:
		return
	if event.pressed:
		_gh_test_label.text = tr("CONTROLS_GH_TEST_LAST") % _describe_gh_press(event.button_index)
	elif not _gh_any_test_input_held(device_id):
		_gh_test_label.text = tr("CONTROLS_GH_TEST_IDLE")


func _gh_any_test_input_held(device_id: int) -> bool:
	for lane in range(_GuitarHeroBindings.MAX_LANES):
		var lane_button := SettingsManager.get_controls_gh_lane_button(lane)
		if Input.is_joy_button_pressed(device_id, lane_button):
			return true
	for button_index in [
		SettingsManager.get_controls_gh_strum_up_button(),
		SettingsManager.get_controls_gh_strum_down_button(),
		SettingsManager.get_controls_gh_pause_button(),
		SettingsManager.get_controls_gh_skip_button(),
	]:
		if Input.is_joy_button_pressed(device_id, button_index):
			return true
	return false


func _refresh_gh_test_indicators(device_id: int) -> void:
	for lane in range(_gh_fret_indicators.size()):
		var indicator: ColorRect = _gh_fret_indicators[lane]
		if indicator == null:
			continue
		var lane_button := SettingsManager.get_controls_gh_lane_button(lane)
		var held := Input.is_joy_button_pressed(device_id, lane_button)
		var base := _GuitarHeroBindings.lane_color(lane)
		indicator.color = Color(base.r, base.g, base.b, 1.0 if held else 0.22)


func _process(_delta: float) -> void:
	if not _gh_test_input_allowed() or _gh_fret_indicators.is_empty():
		return
	var device_id := SettingsManager.resolve_gh_device_id()
	if device_id < 0:
		return
	_refresh_gh_test_indicators(device_id)


func _on_gh_enable_toggled(enabled: bool) -> void:
	SettingsManager.set_controls_gh_enabled(enabled)
	_update_gh_section_enabled()
	_update_gh_status_label()
	emit_signal("settings_changed")
	_update_player_bindings()


func _on_gh_auto_detect_toggled(enabled: bool) -> void:
	SettingsManager.set_controls_gh_auto_detect(enabled)
	_update_gh_status_label()
	emit_signal("settings_changed")
	_update_player_bindings()


func _on_gh_device_selected(index: int) -> void:
	if _gh_device_option == null:
		return
	var device_id := int(_gh_device_option.get_item_metadata(index))
	SettingsManager.set_controls_gh_device_id(device_id)
	_update_gh_status_label()
	emit_signal("settings_changed")
	_update_player_bindings()


func _on_gh_refresh_pressed() -> void:
	_populate_gh_device_option()
	_update_gh_status_label()


func _on_gh_reset_pressed() -> void:
	SettingsManager.reset_gh_controls_to_default()
	_populate_gh_device_option()
	_refresh_gh_binding_labels()
	_update_gh_status_label()
	emit_signal("settings_changed")
	_update_player_bindings()


func _on_gh_binding_button_pressed(binding_id: String) -> void:
	if _remap_active:
		_clear_remap_state()
	if _gh_remap_active and _gh_remap_target_button:
		_gh_remap_target_button.text = _gh_binding_label_for(_gh_remap_target_id)
	_gh_remap_target_id = binding_id
	_gh_remap_target_button = _gh_binding_buttons.get(binding_id, null)
	_gh_remap_old_button = _gh_button_for_binding(binding_id)
	if _gh_remap_target_button:
		_gh_remap_target_button.text = "..."
	_gh_remap_active = true
	if hint_label:
		hint_label.text = _controls_hint_text()


func _find_duplicate_gh_binding(new_button: int) -> String:
	for binding_id in _gh_binding_buttons:
		if binding_id == _gh_remap_target_id:
			continue
		if _gh_button_for_binding(binding_id) == new_button:
			return binding_id
	return ""


func _clear_gh_remap_state() -> void:
	_gh_remap_active = false
	_gh_remap_target_id = ""
	_gh_remap_target_button = null
	_gh_remap_old_button = 0
	if hint_label:
		hint_label.text = _controls_hint_text()


func _setup_layout_option_popup_font() -> void:
	_OptionButtonPopupUtils.apply_popup_font_size(layout_mode_option, 24)


func _populate_layout_mode_option() -> void:
	if layout_mode_option == null:
		return
	var selected := SettingsManager.get_controls_layout_mode()
	var selected_idx := 0
	layout_mode_option.set_block_signals(true)
	layout_mode_option.clear()
	var items := [
		[ControlsBindings.LAYOUT_PRIMARY, tr("CONTROLS_LAYOUT_PRIMARY")],
		[ControlsBindings.LAYOUT_ALT, tr("CONTROLS_LAYOUT_ALT")],
		[ControlsBindings.LAYOUT_BOTH, tr("CONTROLS_LAYOUT_BOTH")],
	]
	for i in range(items.size()):
		layout_mode_option.add_item(str(items[i][1]), i)
		layout_mode_option.set_item_metadata(i, items[i][0])
		if str(items[i][0]) == selected:
			selected_idx = i
	layout_mode_option.select(selected_idx)
	layout_mode_option.set_block_signals(false)


func _on_layout_mode_selected(index: int) -> void:
	if layout_mode_option == null:
		return
	var mode := str(layout_mode_option.get_item_metadata(index))
	SettingsManager.set_controls_layout_mode(mode)
	emit_signal("settings_changed")
	_update_player_bindings()


func _build_bindings_ui() -> void:
	if _primary_keys == null or _alt_keys == null:
		return
	_clear_column(_primary_keys)
	_clear_column(_alt_keys)
	_binding_buttons.clear()
	_build_layout_column(_primary_keys, tr("CONTROLS_SECTION_PRIMARY"), "primary")
	_build_layout_column(_alt_keys, tr("CONTROLS_SECTION_ALT"), "alt")
	_refresh_binding_labels()


func _clear_column(column: VBoxContainer) -> void:
	for child in column.get_children():
		child.queue_free()


func _build_layout_column(column: VBoxContainer, title: String, prefix: String) -> void:
	_add_section_header(column, title)
	_add_subheader(column, tr("CONTROLS_SECTION_LANES"))
	for lane in range(5):
		_add_binding_row(column, "%s:lane:%d" % [prefix, lane], tr("CONTROLS_LANE") % (lane + 1))
	_add_subheader(column, tr("CONTROLS_SECTION_MEDIATOR"))
	_add_binding_row(column, "%s:mediator_up" % prefix, tr("CONTROLS_MEDIATOR_UP"))
	_add_binding_row(column, "%s:mediator_down" % prefix, tr("CONTROLS_MEDIATOR_DOWN"))


func _add_section_header(column: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.86, 0.52, 0.72, 1.0))
	column.add_child(label)


func _add_subheader(column: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color(0.72, 0.78, 0.9, 0.95))
	column.add_child(label)


func _add_binding_row(column: VBoxContainer, binding_id: String, action_text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var action_label := Label.new()
	action_label.text = action_text
	action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_label.add_theme_font_size_override("font_size", 20)
	var key_button := Button.new()
	key_button.custom_minimum_size = Vector2(120, 44)
	key_button.add_theme_font_size_override("font_size", 20)
	key_button.pressed.connect(_on_binding_button_pressed.bind(binding_id))
	row.add_child(action_label)
	row.add_child(key_button)
	column.add_child(row)
	_binding_buttons[binding_id] = key_button


func _refresh_binding_labels() -> void:
	for binding_id in _binding_buttons:
		var button: Button = _binding_buttons[binding_id]
		if button:
			button.text = _binding_label_for(binding_id)


func _binding_label_for(binding_id: String) -> String:
	var parts := binding_id.split(":")
	if parts.size() < 2:
		return "?"
	var alt := parts[0] == "alt"
	match parts[1]:
		"lane":
			if parts.size() < 3:
				return "?"
			return SettingsManager.get_key_text_for_lane(int(parts[2]), alt)
		"mediator_up":
			return SettingsManager.get_mediator_up_key_text(alt)
		"mediator_down":
			return SettingsManager.get_mediator_down_key_text(alt)
		_:
			return "?"


func _scancode_for_binding(binding_id: String) -> int:
	var parts := binding_id.split(":")
	if parts.size() < 2:
		return KEY_X
	var alt := parts[0] == "alt"
	match parts[1]:
		"lane":
			return SettingsManager.get_key_scancode_for_lane(int(parts[2]), alt)
		"mediator_up":
			return SettingsManager.get_mediator_up_scancode(alt)
		"mediator_down":
			return SettingsManager.get_mediator_down_scancode(alt)
		_:
			return KEY_X


func _set_scancode_for_binding(binding_id: String, scancode: int) -> void:
	var parts := binding_id.split(":")
	if parts.size() < 2:
		return
	var alt := parts[0] == "alt"
	match parts[1]:
		"lane":
			SettingsManager.set_key_scancode_for_lane(int(parts[2]), scancode, alt)
		"mediator_up":
			SettingsManager.set_mediator_up_scancode(scancode, alt)
		"mediator_down":
			SettingsManager.set_mediator_down_scancode(scancode, alt)


func _on_binding_button_pressed(binding_id: String) -> void:
	if _gh_remap_active:
		_clear_gh_remap_state()
	if _remap_active and _remap_target_button:
		_remap_target_button.text = _binding_label_for(_remap_target_id)
	_remap_target_id = binding_id
	_remap_target_button = _binding_buttons.get(binding_id, null)
	_remap_old_scancode = _scancode_for_binding(binding_id)
	if _remap_target_button:
		_remap_target_button.text = "..."
	_remap_active = true
	if hint_label:
		hint_label.text = _controls_hint_text()


func _input(event: InputEvent) -> void:
	if _gh_test_input_allowed() and event is InputEventJoypadButton:
		_update_gh_test_feedback(event as InputEventJoypadButton)
	if _gh_remap_active and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _gh_remap_target_button:
			_gh_remap_target_button.text = _gh_binding_label_for(_gh_remap_target_id)
		_clear_gh_remap_state()
		get_viewport().set_input_as_handled()
		return
	if _gh_remap_active and event is InputEventJoypadButton and event.pressed:
		var joy_event := event as InputEventJoypadButton
		var new_button: int = joy_event.button_index
		var duplicate_id := _find_duplicate_gh_binding(new_button)
		if duplicate_id != "":
			_set_gh_button_for_binding(duplicate_id, _gh_remap_old_button)
			_set_gh_button_for_binding(_gh_remap_target_id, new_button)
			_refresh_gh_binding_labels()
		else:
			_set_gh_button_for_binding(_gh_remap_target_id, new_button)
			if _gh_remap_target_button:
				_gh_remap_target_button.text = _gh_binding_label_for(_gh_remap_target_id)
		emit_signal("settings_changed")
		_update_player_bindings()
		_clear_gh_remap_state()
		get_viewport().set_input_as_handled()
		return
	if not _remap_active or not (event is InputEventKey and event.pressed):
		return
	var new_scancode: int = int(event.keycode)
	if new_scancode == KEY_NONE:
		new_scancode = int(event.physical_keycode)
	if new_scancode == KEY_ESCAPE:
		if _remap_target_button:
			_remap_target_button.text = _binding_label_for(_remap_target_id)
		_clear_remap_state()
		get_viewport().set_input_as_handled()
		return
	if event.alt_pressed and event.ctrl_pressed:
		get_viewport().set_input_as_handled()
		return
	if SettingsManager.is_service_key(new_scancode):
		get_viewport().set_input_as_handled()
		return
	var duplicate_id := _find_duplicate_binding(new_scancode)
	if duplicate_id != "":
		_set_scancode_for_binding(duplicate_id, _remap_old_scancode)
		_set_scancode_for_binding(_remap_target_id, new_scancode)
		_refresh_binding_labels()
	else:
		_set_scancode_for_binding(_remap_target_id, new_scancode)
		if _remap_target_button:
			_remap_target_button.text = _binding_label_for(_remap_target_id)
	emit_signal("settings_changed")
	_update_player_bindings()
	_clear_remap_state()
	if hint_label:
		hint_label.text = _controls_hint_text()
	get_viewport().set_input_as_handled()


func _find_duplicate_binding(new_scancode: int) -> String:
	for binding_id in _binding_buttons:
		if binding_id == _remap_target_id:
			continue
		if _scancode_for_binding(binding_id) == new_scancode:
			return binding_id
	return ""


func _clear_remap_state() -> void:
	_remap_active = false
	_remap_target_id = ""
	_remap_target_button = null
	_remap_old_scancode = 0


func _on_reset_controls_pressed() -> void:
	for i in range(5):
		SettingsManager.set_key_scancode_for_lane(
			i,
			int(ControlsBindings.DEFAULT_KEYMAP_PRIMARY["lane_%d_key" % i]),
			false
		)
		SettingsManager.set_key_scancode_for_lane(
			i,
			int(ControlsBindings.DEFAULT_KEYMAP_ALT["lane_%d_key" % i]),
			true
		)
	SettingsManager.set_mediator_up_scancode(KEY_UP, false)
	SettingsManager.set_mediator_down_scancode(KEY_DOWN, false)
	SettingsManager.set_mediator_up_scancode(KEY_Q, true)
	SettingsManager.set_mediator_down_scancode(KEY_E, true)
	SettingsManager.set_controls_layout_mode(ControlsBindings.LAYOUT_PRIMARY)
	_populate_layout_mode_option()
	emit_signal("settings_changed")
	_update_player_bindings()
	_refresh_binding_labels()


func _update_player_bindings() -> void:
	if game_screen:
		if game_screen.has_method("_reload_control_bindings"):
			game_screen._reload_control_bindings()
		elif game_screen.has_method("_reload_strum_keys"):
			game_screen._reload_strum_keys()
	if game_screen and game_screen.player:
		game_screen.player.set_keymap(SettingsManager.build_active_lane_keymap())


func refresh_ui() -> void:
	_populate_layout_mode_option()
	_refresh_binding_labels()
	_refresh_gh_ui()
