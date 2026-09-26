# scenes/game_screen/components/replay_player_bar.gd
## Транспортная панель Replay Player — рисуется поверх game screen в watch mode.
## Видеоплеерный набор: play/pause, timeline с перемоткой (клик/перетаскивание),
## переключение секций, громкость + mute, кнопка Replay Settings.
## Скорость управляется только из Advanced Settings (не в транспорте).
## Чистый UI: всю логику воспроизведения выполняет game_screen через сигналы.
class_name ReplayPlayerBar
extends Control

signal play_pause_requested
signal section_prev_requested
signal section_next_requested
signal seek_requested(time_s: float)
signal seek_preview(time_s: float)
signal speed_select_requested # legacy — теперь не используется в баре, остаётся для совместимости
signal volume_changed(value: float)
signal mute_requested
signal settings_requested

const ACCENT := Color(0.6, 0.82, 0.95, 1.0)
const ICON_PX := 22
const PANEL_BG := Color(0.06, 0.08, 0.11, 0.92)
const PANEL_BORDER := Color(0.22, 0.30, 0.38, 0.9)

var _play_button: Button = null
var _prev_button: Button = null
var _next_button: Button = null
var _time_label: Label = null
var _timeline: HSlider = null
var _markers: Control = null
var _mute_button: Button = null
var _volume_slider: HSlider = null
var _speed_button: Button = null
var _settings_button: Button = null

var _duration_s: float = 0.0
var _sections: Array = []
var _dragging := false
var _playing := false
var _muted := false
var _volume := 1.0


func _ready() -> void:
	_build()


func setup(duration_s: float, sections: Array) -> void:
	_duration_s = maxf(0.0, duration_s)
	_sections = []
	for s in sections:
		if s is Dictionary:
			_sections.append(s)
	if _timeline:
		_timeline.max_value = maxf(1.0, _duration_s)
	if _markers:
		_markers.queue_redraw()
	if _time_label:
		_refresh_label(0.0)


func set_playing(playing: bool) -> void:
	_playing = playing
	if _play_button:
		UiIconHelper.configure_button_icon(
			_play_button,
			"pause.svg" if playing else "play.svg",
			ReplayPlayerBar.ACCEPT_COLOR() if playing else ACCENT,
			ICON_PX,
		)
		_play_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_play_button.tooltip_text = tr("REPLAY_PLAYER_PAUSE") if playing else tr("REPLAY_PLAYER_PLAY")


func set_muted(muted: bool) -> void:
	_muted = muted
	_refresh_volume_icon()


func set_volume(linear: float) -> void:
	_volume = clampf(linear, 0.0, 1.0)
	if _volume_slider:
		_volume_slider.set_value_no_signal(_volume * 100.0)
	_refresh_volume_icon()


func set_speed_text(text: String) -> void:
	if _speed_button:
		_speed_button.text = text


func refresh(time_s: float) -> void:
	if _timeline and not _dragging:
		_timeline.set_value_no_signal(clampf(time_s, 0.0, maxf(1.0, _duration_s)))
	_refresh_label(time_s)


func _refresh_label(time_s: float) -> void:
	if _time_label == null:
		return
	var t := clampf(time_s, 0.0, maxf(1.0, _duration_s))
	var fmt := _format_clock
	_time_label.text = "%s / %s" % [fmt.call(t), fmt.call(_duration_s)]


static func _format_clock(sec: float) -> String:
	var s := maxi(0, int(floor(sec)))
	return "%d:%02d" % [s / 60, s % 60]


func _refresh_volume_icon() -> void:
	if _mute_button == null:
		return
	var icon := "volume-x.svg"
	if not _muted:
		icon = "volume-1.svg" if _volume < 0.5 else "volume_2.svg"
	UiIconHelper.configure_button_icon(_mute_button, icon, ACCENT, 20)
	_mute_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	offset_left = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	offset_top = -84.0
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	mouse_filter = Control.MOUSE_FILTER_STOP

	var panel := Panel.new()
	panel.name = "ReplayPlayerBackdrop"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := StyleBoxFlat.new()
	bg.bg_color = PANEL_BG
	bg.border_color = PANEL_BORDER
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(12)
	bg.content_margin_left = 14
	bg.content_margin_right = 14
	bg.content_margin_top = 10
	bg.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", bg)
	add_child(panel)

	var box := VBoxContainer.new()
	box.name = "Rows"
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 8.0
	box.offset_top = 6.0
	box.offset_right = -8.0
	box.offset_bottom = -6.0
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var row1 := HBoxContainer.new()
	row1.name = "RowTransport"
	row1.add_theme_constant_override("separation", 8)
	row1.add_theme_constant_override("h_separation", 8)
	box.add_child(row1)

	_prev_button = _make_chip("rewind.svg", tr("REPLAY_PLAYER_PREV_SECTION"))
	_prev_button.pressed.connect(func() -> void: section_prev_requested.emit())
	row1.add_child(_prev_button)

	_play_button = _make_chip("play.svg", tr("REPLAY_PLAYER_PLAY"), 40)
	_play_button.pressed.connect(func() -> void: play_pause_requested.emit())
	row1.add_child(_play_button)

	_next_button = _make_chip("fast-forward.svg", tr("REPLAY_PLAYER_NEXT_SECTION"))
	_next_button.pressed.connect(func() -> void: section_next_requested.emit())
	row1.add_child(_next_button)

	_time_label = Label.new()
	_time_label.name = "ReplayTimeLabel"
	_time_label.add_theme_font_size_override("font_size", 16)
	_time_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95, 1.0))
	_time_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	_time_label.add_theme_constant_override("outline_size", 4)
	_time_label.custom_minimum_size = Vector2(150, 0)
	_time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row1.add_child(_time_label)

	var timeline_area := Control.new()
	timeline_area.name = "TimelineArea"
	timeline_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline_area.custom_minimum_size = Vector2(0, 28)
	row1.add_child(timeline_area)

	_timeline = HSlider.new()
	_timeline.name = "ReplayTimeline"
	_timeline.set_anchors_preset(Control.PRESET_FULL_RECT)
	_timeline.min_value = 0.0
	_timeline.max_value = 1.0
	_timeline.step = 0.01
	_timeline.value = 0.0
	_timeline.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_timeline.focus_mode = Control.FOCUS_NONE
	timeline_area.add_child(_timeline)

	_markers = Control.new()
	_markers.name = "ReplaySectionMarkers"
	_markers.set_anchors_preset(Control.PRESET_FULL_RECT)
	_markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_markers.draw.connect(_draw_markers)
	timeline_area.add_child(_markers)

	_timeline.value_changed.connect(_on_timeline_value_changed)
	_timeline.gui_input.connect(_on_timeline_gui_input)

	var row2 := HBoxContainer.new()
	row2.name = "RowSecondary"
	row2.add_theme_constant_override("separation", 8)
	box.add_child(row2)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(spacer)

	_mute_button = _make_chip("volume-x.svg", tr("REPLAY_PLAYER_MUTE"), 32)
	_mute_button.pressed.connect(func() -> void: mute_requested.emit())
	row2.add_child(_mute_button)

	_volume_slider = HSlider.new()
	_volume_slider.name = "ReplayVolume"
	_volume_slider.custom_minimum_size = Vector2(140, 0)
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 100.0
	_volume_slider.step = 1.0
	_volume_slider.value = 100.0
	_volume_slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_volume_slider.focus_mode = Control.FOCUS_NONE
	_volume_slider.value_changed.connect(func(v: float) -> void: volume_changed.emit(v / 100.0))
	row2.add_child(_volume_slider)

	_settings_button = _make_chip("settings-2.svg", tr("REPLAY_PLAYER_SETTINGS"), 32)
	_settings_button.pressed.connect(func() -> void: settings_requested.emit())
	row2.add_child(_settings_button)

	refresh(0.0)


func _make_chip(icon_file: String, tooltip: String, chip_size: int = 36) -> Button:
	var btn := Button.new()
	btn.text = ""
	btn.focus_mode = Control.FOCUS_NONE
	btn.flat = true
	btn.custom_minimum_size = Vector2(chip_size, chip_size)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.tooltip_text = tooltip
	var tint := ACCENT
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.14, 0.18, 0.96)
	normal.border_color = Color(tint.r, tint.g, tint.b, 0.40)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(chip_size / 2)
	normal.content_margin_left = 5
	normal.content_margin_top = 5
	normal.content_margin_right = 5
	normal.content_margin_bottom = 5
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.14, 0.20, 0.26, 0.98)
	hover.border_color = Color(tint.r, tint.g, tint.b, 0.8)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.08, 0.11, 0.15, 0.98)
	for state in ["normal", "hover", "pressed", "focus"]:
		var box: StyleBoxFlat = normal
		if state == "hover":
			box = hover
		elif state == "pressed":
			box = pressed
		btn.add_theme_stylebox_override(state, box)
	UiIconHelper.configure_button_icon(btn, icon_file, tint, ICON_PX)
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.add_theme_constant_override("h_separation", 0)
	return btn


func _on_timeline_value_changed(value: float) -> void:
	if not _dragging:
		return
	_refresh_label(value)
	seek_preview.emit(value)


func _on_timeline_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_refresh_label(_timeline.value)
			elif _dragging:
				_dragging = false
				seek_requested.emit(_timeline.value)


func _draw_markers() -> void:
	if _markers == null or _duration_s <= 0.0:
		return
	var w := _markers.size.x
	var h := _markers.size.y
	for s in _sections:
		var start_s := float(s.get("start_s", 0.0))
		if start_s <= 0.0:
			continue
		var x := w * clampf(start_s / _duration_s, 0.0, 1.0)
		_markers.draw_line(
			Vector2(x, 2.0),
			Vector2(x, h - 2.0),
			Color(0.95, 0.85, 0.4, 0.55),
			1.5,
		)


static func ACCEPT_COLOR() -> Color:
	return Color(0.62, 0.92, 0.72, 1.0)