class_name ReplaySettingsPanel
extends PanelContainer
## Панель настроек просмотра реплея. Только настройки отображения — транспорт
## (play/pause/seek) живёт в ReplayPlayerBar и сюда не лезет. Скорость, скрытие
## элементов интерфейса и громкость звуков попаданий открываются отдельными
## окнами поверх панели (top_level-попапы), чтобы не раздувать панель.

signal section_markers_toggled(value: bool)
signal watch_badge_toggled(value: bool)
signal auto_hide_toggled(value: bool)
signal speed_select_requested
signal speed_selected(value: float)
signal hide_ui_select_requested
signal hide_option_toggled(key: String, value: bool)
signal hit_sounds_volume_changed(value: float)

const PANEL_BG := Color(0.06, 0.08, 0.11, 0.97)
const PANEL_BORDER := Color(0.90, 0.78, 0.34, 0.45)
const ACCENT := Color(0.95, 0.85, 0.40, 1.0)
const TEXT_COLOR := Color(0.88, 0.92, 0.97, 1.0)
const MUTED_COLOR := Color(0.58, 0.64, 0.74, 0.92)

const SPEEDS := [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

const HIDE_OPTIONS := [
	["combo", "REPLAY_SETTINGS_HIDE_COMBO"],
	["hit_effects", "REPLAY_SETTINGS_HIDE_HIT_EFFECTS"],
	["score_accuracy", "REPLAY_SETTINGS_HIDE_SCORE_ACCURACY"],
	["error_meter", "REPLAY_SETTINGS_HIDE_ERROR_METER"],
	["hp", "REPLAY_SETTINGS_HIDE_HP"],
	["lane_highlights", "REPLAY_SETTINGS_HIDE_LANE_HIGHLIGHTS"],
	["judgement", "REPLAY_SETTINGS_HIDE_JUDGEMENT"],
	["progress", "REPLAY_SETTINGS_HIDE_PROGRESS"],
]

var _section_markers_check: CheckButton = null
var _watch_badge_check: CheckButton = null
var _auto_hide_check: CheckButton = null
var _speed_button: Button = null
var _hide_ui_button: Button = null
var _hit_sounds_slider: HSlider = null
var _hit_sounds_value: Label = null
var _speed_picker: PanelContainer = null
var _hide_picker: PanelContainer = null

var _current_speed := 1.0


func setup(
	show_section_markers: bool,
	show_watch_badge: bool,
	auto_hide: bool,
	speed: float,
	hit_sounds_volume: float
) -> void:
	_build()
	print("[REPLAY AUDIO DEBUG] panel_setup hit_volume=%s speed=%s source=setup" % [str(hit_sounds_volume), str(speed)])
	_current_speed = speed
	if _section_markers_check:
		_section_markers_check.button_pressed = show_section_markers
	if _watch_badge_check:
		_watch_badge_check.button_pressed = show_watch_badge
	if _auto_hide_check:
		_auto_hide_check.button_pressed = auto_hide
	if _speed_button:
		_speed_button.text = "%s: %s" % [tr("REPLAY_SETTINGS_SPEED"), _speed_text(speed)]
	if _hit_sounds_slider:
		_hit_sounds_slider.set_value_no_signal(clampf(hit_sounds_volume, 0.0, 100.0))
	if _hit_sounds_value:
		_hit_sounds_value.text = "%d%%" % int(round(clampf(hit_sounds_volume, 0.0, 100.0)))


func set_speed(speed: float) -> void:
	_current_speed = speed
	if _speed_button:
		_speed_button.text = "%s: %s" % [tr("REPLAY_SETTINGS_SPEED"), _speed_text(speed)]


func _speed_text(speed: float) -> String:
	return "×%.2f" % snappedf(speed, 0.01)


func _build() -> void:
	if get_child_count() > 0:
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 5
	custom_minimum_size = Vector2(420, 0)
	var bg := StyleBoxFlat.new()
	bg.bg_color = PANEL_BG
	bg.border_color = PANEL_BORDER
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(10)
	bg.content_margin_left = 16
	bg.content_margin_right = 16
	bg.content_margin_top = 14
	bg.content_margin_bottom = 14
	add_theme_stylebox_override("panel", bg)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	var title := Label.new()
	title.text = tr("REPLAY_SETTINGS_TITLE")
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", ACCENT)
	box.add_child(title)

	box.add_child(_make_separator())

	_speed_button = _make_action_button("REPLAY_SETTINGS_SPEED")
	_speed_button.pressed.connect(func() -> void:
		speed_select_requested.emit()
		_open_speed_picker()
	)
	box.add_child(_speed_button)

	_hide_ui_button = _make_action_button("REPLAY_SETTINGS_HIDE_UI")
	_hide_ui_button.pressed.connect(func() -> void:
		hide_ui_select_requested.emit()
		_open_hide_picker()
	)
	box.add_child(_hide_ui_button)

	_auto_hide_check = _make_check("REPLAY_SETTINGS_AUTO_HIDE", func(pressed: bool) -> void: auto_hide_toggled.emit(pressed))
	box.add_child(_auto_hide_check)

	box.add_child(_make_separator())

	var hit_title := Label.new()
	hit_title.text = tr("REPLAY_SETTINGS_HIT_SOUNDS")
	hit_title.add_theme_font_size_override("font_size", 18)
	hit_title.add_theme_color_override("font_color", TEXT_COLOR)
	box.add_child(hit_title)

	var hit_row := HBoxContainer.new()
	hit_row.add_theme_constant_override("separation", 10)
	box.add_child(hit_row)
	_hit_sounds_slider = HSlider.new()
	_hit_sounds_slider.name = "ReplayHitSoundsVolume"
	_hit_sounds_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hit_sounds_slider.min_value = 0.0
	_hit_sounds_slider.max_value = 100.0
	_hit_sounds_slider.step = 1.0
	_hit_sounds_slider.value = 50.0
	_hit_sounds_slider.focus_mode = Control.FOCUS_NONE
	_hit_sounds_slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_hit_sounds_slider.value_changed.connect(func(v: float) -> void:
		hit_sounds_volume_changed.emit(clampf(v / 100.0, 0.0, 1.0))
		if _hit_sounds_value:
			_hit_sounds_value.text = "%d%%" % int(round(v))
	)
	hit_row.add_child(_hit_sounds_slider)
	_hit_sounds_value = Label.new()
	_hit_sounds_value.add_theme_font_size_override("font_size", 17)
	_hit_sounds_value.add_theme_color_override("font_color", ACCENT)
	_hit_sounds_value.custom_minimum_size = Vector2(56, 0)
	_hit_sounds_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hit_row.add_child(_hit_sounds_value)

	box.add_child(_make_separator())

	_section_markers_check = _make_check(
		"REPLAY_SETTINGS_SECTION_MARKERS",
		func(pressed: bool) -> void: section_markers_toggled.emit(pressed)
	)
	box.add_child(_section_markers_check)
	_watch_badge_check = _make_check(
		"REPLAY_SETTINGS_WATCH_BADGE",
		func(pressed: bool) -> void: watch_badge_toggled.emit(pressed)
	)
	box.add_child(_watch_badge_check)


func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.15)
	return sep


func _make_action_button(label_key: String) -> Button:
	var btn := Button.new()
	btn.text = tr(label_key)
	btn.flat = false
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 46)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", TEXT_COLOR)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.14, 0.18, 0.96)
	normal.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.14, 0.20, 0.26, 0.98)
	hover.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.8)
	for state in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state, hover if state == "hover" else normal)
	return btn


func _make_check(label_key: String, on_toggled: Callable) -> CheckButton:
	var check := CheckButton.new()
	check.text = tr(label_key)
	check.focus_mode = Control.FOCUS_NONE
	check.add_theme_font_size_override("font_size", 17)
	check.add_theme_color_override("font_color", TEXT_COLOR)
	check.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	check.toggled.connect(on_toggled)
	return check


func open_speed_picker() -> void:
	_close_pickers()
	_open_speed_picker()


func _open_speed_picker() -> void:
	_close_pickers()
	_speed_picker = _make_popup(320)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_speed_picker.add_child(vbox)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)
	var back := Button.new()
	back.focus_mode = Control.FOCUS_NONE
	UiIconHelper.apply_standard_back_button(back)
	back.text = ""
	back.tooltip_text = tr("BTN_BACK")
	back.custom_minimum_size = Vector2(36, 36)
	back.pressed.connect(func() -> void: _close_pickers())
	header.add_child(back)
	var cap := Label.new()
	cap.text = tr("REPLAY_SPEED_PICKER_TITLE")
	cap.add_theme_font_size_override("font_size", 19)
	cap.add_theme_color_override("font_color", ACCENT)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(cap)
	# Spacer to balance compact back button (36px instead of 90)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(36, 0)
	header.add_child(spacer)
	for speed in SPEEDS:
		var btn := Button.new()
		btn.text = _speed_text(speed)
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(0, 40)
		btn.add_theme_font_size_override("font_size", 18)
		btn.add_theme_color_override("font_color", ACCENT if _current_speed == speed else TEXT_COLOR)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(func() -> void:
			MusicManager.play_modifier_select_sound()
			speed_selected.emit(speed)
			_close_pickers()
		)
		vbox.add_child(btn)
	_position_popup(_speed_picker)


func _open_hide_picker() -> void:
	_close_pickers()
	_hide_picker = _make_popup(420)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_hide_picker.add_child(vbox)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)
	var back := Button.new()
	back.focus_mode = Control.FOCUS_NONE
	UiIconHelper.apply_standard_back_button(back)
	back.text = ""
	back.tooltip_text = tr("BTN_BACK")
	back.custom_minimum_size = Vector2(36, 36)
	back.pressed.connect(func() -> void: _close_pickers())
	header.add_child(back)
	var cap := Label.new()
	cap.text = tr("REPLAY_SETTINGS_HIDE_UI")
	cap.add_theme_font_size_override("font_size", 19)
	cap.add_theme_color_override("font_color", ACCENT)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(cap)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(36, 0)
	header.add_child(spacer)
	for option in HIDE_OPTIONS:
		var key := String(option[0])
		var label_key := String(option[1])
		var check := CheckButton.new()
		check.text = tr(label_key)
		check.focus_mode = Control.FOCUS_NONE
		check.add_theme_font_size_override("font_size", 17)
		check.add_theme_color_override("font_color", TEXT_COLOR)
		check.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		check.button_pressed = _get_hide_option(key)
		check.toggled.connect(func(pressed: bool) -> void: hide_option_toggled.emit(key, pressed))
		vbox.add_child(check)
	_position_popup(_hide_picker)


func _get_hide_option(key: String) -> bool:
	if SettingsManager and SettingsManager.has_method("get_replay_hide_option"):
		return SettingsManager.get_replay_hide_option(key)
	return false


func _make_popup(width: int) -> PanelContainer:
	var popup := PanelContainer.new()
	popup.name = "ReplaySettingsPopup"
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	# Overlay INSIDE Advanced Settings — перекрывает содержимое панели, не вылезает за её границы
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.offset_left = 0
	popup.offset_top = 0
	popup.offset_right = 0
	popup.offset_bottom = 0
	popup.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	popup.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.08, 0.11, 0.98)
	bg.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.55)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(10)
	bg.content_margin_left = 12
	bg.content_margin_right = 12
	bg.content_margin_top = 12
	bg.content_margin_bottom = 12
	popup.add_theme_stylebox_override("panel", bg)
	add_child(popup)
	# Ensure overlay is drawn on top of main content
	move_child(popup, get_child_count() - 1)
	return popup


func _position_popup(popup: PanelContainer) -> void:
	# No-op: popup now fills the panel (inside overlay). Kept for compatibility.
	if popup == null or not is_instance_valid(popup):
		return
	popup.visible = true


func has_open_picker() -> bool:
	return (_speed_picker != null and is_instance_valid(_speed_picker)) or (_hide_picker != null and is_instance_valid(_hide_picker))


func close_pickers() -> void:
	_close_pickers()


func _close_pickers() -> void:
	if _speed_picker and is_instance_valid(_speed_picker):
		_speed_picker.queue_free()
	_speed_picker = null
	if _hide_picker and is_instance_valid(_hide_picker):
		_hide_picker.queue_free()
	_hide_picker = null