# scenes/profile/dialogs/activity_calendar_dialog.gd
class_name ActivityCalendarDialog
extends Control

signal closed()

const _ActivityCalendar = preload("res://logic/domain/profile/activity_calendar.gd")
const _MemoryFacts = preload("res://logic/domain/profile/activity_memory_facts.gd")
const _TimeCapsule = preload("res://logic/domain/profile/time_capsule.gd")
const _PlayerEvolution = preload("res://logic/domain/profile/player_evolution.gd")
const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")
const _UiModifierSounds = preload("res://logic/ui/ui_modifier_sounds.gd")
const _TimeUtils = preload("res://logic/platform/time_utils.gd")
const _GenPresetUi = preload("res://logic/ui/generation_preset_ui.gd")

const _CELL_SIDE_MIN := 32
const _CELL_FONT := 14
const _MILESTONE_ICON := 15
const _ACTIVE := Color(0.45, 0.72, 0.95, 1.0)
## Heatmap fill by intensity 1…5 (tracks: 1 / 2–3 / 4–6 / 7–9 / 10+).
const _ACTIVE_LV := [
	Color(0, 0, 0, 0),
	Color(0.45, 0.72, 0.95, 0.28),
	Color(0.43, 0.70, 0.94, 0.40),
	Color(0.40, 0.68, 0.92, 0.54),
	Color(0.40, 0.74, 0.96, 0.68),
	Color(0.42, 0.78, 0.98, 0.84),
]
const _MISS := Color(0.22, 0.26, 0.34, 1.0)
const _DISABLED := Color(0.14, 0.16, 0.2, 0.55)
const _TODAY_BORDER := Color(0.95, 0.82, 0.45, 0.95)
const _TEXT := Color(0.88, 0.92, 0.98, 1.0)
const _TEXT_MUTED := Color(0.55, 0.6, 0.7, 0.85)
const _STAT_ROW_BG := Color(0.1, 0.13, 0.2, 0.72)
const _STAT_ICON_TRACKS := Color(0.55, 0.78, 0.98, 1.0)
const _STAT_ICON_CLEARS := Color(0.55, 0.85, 0.65, 1.0)
const _STAT_ICON_FAILS := Color(0.95, 0.55, 0.48, 1.0)
const _STAT_ICON_TIME := Color(0.62, 0.86, 0.88, 1.0)
const _STAT_ICON_GRADE := Color(0.95, 0.82, 0.45, 1.0)
const _STAT_ICON_SCORE := Color(0.7, 0.84, 0.98, 1.0)
const _STAT_ICON_COMBO := Color(0.98, 0.68, 0.42, 1.0)
const _STAT_ICON_DRUMS := _GenPresetUi.INSTRUMENT_ICON_COLORS["drums"]
const _STAT_ICON_BASS := _GenPresetUi.INSTRUMENT_ICON_COLORS["bass"]
const _STAT_ICON_HIGHLIGHT := Color(0.98, 0.78, 0.45, 1.0)
const _STAT_ICON_MEMORY := Color(0.78, 0.68, 0.98, 1.0)
const _STAT_ICON_FACT := Color(0.62, 0.86, 0.88, 1.0)
const _PANEL_DAY := "day"
const _PANEL_MONTH := "month"
const _PANEL_WEEK := "week"

var _year: int = 0
var _month: int = 0
var _selected_date: String = ""
var _panel_mode: String = _PANEL_DAY
var _day_buttons: Array[Button] = []
var _weekday_labels: Array[Label] = []
const _GRADE_DOT_SIZE := 7

var _legend_built := false
var _grade_legend_built := false
## Expanded expandable-stat keys for the current day panel (tracks/clears/…).
var _expanded_stats: Dictionary = {}
## When set, right panel shows then/now evolution for this YYYY-MM capsule.
var _evolution_month_key: String = ""

@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %TitleLabel
@onready var _prev_btn: Button = %PrevMonthButton
@onready var _month_label: Label = %MonthLabel
@onready var _next_btn: Button = %NextMonthButton
@onready var _today_btn: Button = %TodayButton
@onready var _weekday_row: HBoxContainer = %WeekdayRow
@onready var _grid: GridContainer = %DaysGrid
@onready var _legend_row: HBoxContainer = %LegendRow
@onready var _grade_legend_row: HBoxContainer = %GradeLegendRow
@onready var _day_mode_btn: Button = %DayModeButton
@onready var _month_mode_btn: Button = %MonthModeButton
@onready var _week_mode_btn: Button = %WeekModeButton
@onready var _day_title_label: Label = %DayTitleLabel
@onready var _stats_scroll: ScrollContainer = %StatsScroll
@onready var _stats_list: VBoxContainer = %StatsList
@onready var _today_status_panel: PanelContainer = %TodayStatusPanel
@onready var _today_status_label: Label = %TodayStatusLabel
@onready var _footer_label: Label = %FooterHintLabel
@onready var _empty_day_label: Label = %EmptyDayLabel


func _ready() -> void:
	visible = false
	add_to_group("locale_refresh")
	_UiIconHelper.configure_modal_overlay(self, 105)
	var bg := get_node_or_null("Background") as ColorRect
	if bg:
		bg.color = Color(0.02, 0.03, 0.06, 0.72)
	var today := _ActivityCalendar.today_str()
	var parts := today.split("-")
	_year = parts[0].to_int() if parts.size() == 3 else Time.get_datetime_dict_from_system().year
	_month = parts[1].to_int() if parts.size() == 3 else Time.get_datetime_dict_from_system().month
	_selected_date = today
	_ensure_weekdays()
	_ensure_day_buttons()
	_ensure_legend()
	_ensure_grade_legend()
	if _back_button and not _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.connect(_on_back_pressed)
	if _prev_btn and not _prev_btn.pressed.is_connected(_on_prev_month):
		_prev_btn.pressed.connect(_on_prev_month)
	if _next_btn and not _next_btn.pressed.is_connected(_on_next_month):
		_next_btn.pressed.connect(_on_next_month)
	if _today_btn and not _today_btn.pressed.is_connected(_on_today_pressed):
		_today_btn.pressed.connect(_on_today_pressed)
	var mode_group := ButtonGroup.new()
	mode_group.allow_unpress = false
	for mode_btn in [_day_mode_btn, _month_mode_btn, _week_mode_btn]:
		if mode_btn == null:
			continue
		mode_btn.toggle_mode = true
		mode_btn.button_group = mode_group
	if _day_mode_btn and not _day_mode_btn.pressed.is_connected(_on_mode_day):
		_day_mode_btn.pressed.connect(_on_mode_day)
	if _month_mode_btn and not _month_mode_btn.pressed.is_connected(_on_mode_month):
		_month_mode_btn.pressed.connect(_on_mode_month)
	if _week_mode_btn and not _week_mode_btn.pressed.is_connected(_on_mode_week):
		_week_mode_btn.pressed.connect(_on_mode_week)
	if _grid and not _grid.resized.is_connected(_fit_square_cells):
		_grid.resized.connect(_fit_square_cells)
	_sync_mode_buttons()
	apply_locale()
	if PlayerDataManager and PlayerDataManager.has_signal("activity_calendar_changed"):
		if not PlayerDataManager.activity_calendar_changed.is_connected(_on_activity_changed):
			PlayerDataManager.activity_calendar_changed.connect(_on_activity_changed)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return visible


func handle_hotkey(event: InputEvent) -> bool:
	if not visible:
		return false
	if event.is_action_pressed("ui_cancel"):
		_close()
		return true
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return false
	# Q / E — previous / next month.
	if event.keycode == KEY_Q:
		_on_prev_month()
		return true
	if event.keycode == KEY_E:
		_on_next_month()
		return true
	# 1–3 — Day / Month / Week panels.
	if event.keycode == KEY_1:
		_on_mode_day()
		return true
	if event.keycode == KEY_2:
		_on_mode_month()
		return true
	if event.keycode == KEY_3:
		_on_mode_week()
		return true
	# W — jump to today (same idea as "today" button).
	if event.keycode == KEY_W:
		_on_today_pressed()
		return true
	return false


func apply_locale() -> void:
	if _back_button:
		_back_button.text = tr("BTN_BACK")
		_UiIconHelper.apply_standard_back_button(_back_button)
	if _title_label:
		_title_label.text = tr("PROFILE_ACTIVITY_TITLE")
	if _prev_btn:
		_prev_btn.text = "<"
		_prev_btn.tooltip_text = tr("PROFILE_ACTIVITY_PREV_MONTH")
	if _next_btn:
		_next_btn.text = ">"
		_next_btn.tooltip_text = tr("PROFILE_ACTIVITY_NEXT_MONTH")
	if _today_btn:
		_today_btn.text = tr("PROFILE_ACTIVITY_JUMP_TODAY")
		_today_btn.tooltip_text = tr("PROFILE_ACTIVITY_JUMP_TODAY_TIP")
	if _day_mode_btn:
		_day_mode_btn.text = tr("PROFILE_ACTIVITY_MODE_DAY")
	if _month_mode_btn:
		_month_mode_btn.text = tr("PROFILE_ACTIVITY_MODE_MONTH")
	if _week_mode_btn:
		_week_mode_btn.text = tr("PROFILE_ACTIVITY_MODE_WEEK")
	if _footer_label:
		_footer_label.text = tr("PROFILE_ACTIVITY_MODAL_FOOTER")
	_ensure_weekdays()
	for i in mini(7, _weekday_labels.size()):
		_weekday_labels[i].text = tr("PROFILE_ACTIVITY_WEEKDAY_%d" % i)
	_legend_built = false
	_grade_legend_built = false
	_ensure_legend()
	_ensure_grade_legend()
	if visible:
		refresh()


func open() -> void:
	var today := _ActivityCalendar.today_str()
	var parts := today.split("-")
	if parts.size() == 3:
		_year = parts[0].to_int()
		_month = parts[1].to_int()
	_selected_date = today
	_panel_mode = _PANEL_DAY
	_expanded_stats.clear()
	_evolution_month_key = ""
	_sync_mode_buttons()
	refresh()
	visible = true
	call_deferred("_fit_square_cells")
	if _back_button:
		_back_button.grab_focus()
	_UiModifierSounds.play_select()


## Open calendar focused on a past/current YYYY-MM in Month panel mode.
func open_month(year: int, month: int) -> void:
	_year = clampi(year, 1970, 2100)
	_month = clampi(month, 1, 12)
	var today := _ActivityCalendar.today_str()
	var prefix := "%04d-%02d" % [_year, _month]
	if today.begins_with(prefix):
		_selected_date = today
	else:
		_selected_date = "%04d-%02d-01" % [_year, _month]
	_panel_mode = _PANEL_MONTH
	_expanded_stats.clear()
	_evolution_month_key = ""
	_sync_mode_buttons()
	refresh()
	visible = true
	move_to_front()
	call_deferred("_fit_square_cells")
	if _back_button:
		_back_button.grab_focus()
	_UiModifierSounds.play_select()


## Open calendar on a specific day (YYYY-MM-DD or any datetime TimeUtils can parse). Day panel.
func open_day(date_iso: String) -> void:
	var date_key := _TimeUtils.iso_date_only(str(date_iso).strip_edges())
	var today := _ActivityCalendar.today_str()
	if date_key.length() < 10:
		open()
		return
	if date_key > today:
		date_key = today
	var parts := date_key.split("-")
	if parts.size() < 3:
		open()
		return
	_year = clampi(parts[0].to_int(), 1970, 2100)
	_month = clampi(parts[1].to_int(), 1, 12)
	_selected_date = date_key
	_panel_mode = _PANEL_DAY
	_expanded_stats.clear()
	_evolution_month_key = ""
	_sync_mode_buttons()
	refresh()
	visible = true
	move_to_front()
	call_deferred("_fit_square_cells")
	if _back_button:
		_back_button.grab_focus()
	_UiModifierSounds.play_select()


func refresh() -> void:
	_update_month_label()
	_rebuild_grid_visuals()
	_update_side_panel()
	_update_today_status()
	call_deferred("_fit_square_cells")


func _on_activity_changed() -> void:
	if visible:
		refresh()


func _ensure_weekdays() -> void:
	if _weekday_row == null:
		return
	if _weekday_labels.size() >= 7:
		return
	for child in _weekday_row.get_children():
		child.queue_free()
	_weekday_labels.clear()
	for i in range(7):
		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", _TEXT_MUTED)
		lbl.text = tr("PROFILE_ACTIVITY_WEEKDAY_%d" % i)
		_weekday_row.add_child(lbl)
		_weekday_labels.append(lbl)


func _ensure_day_buttons() -> void:
	if _grid == null:
		return
	var needs_rebuild := _day_buttons.size() < 42
	if not needs_rebuild and not _day_buttons.is_empty():
		var mark := _day_buttons[0].get_node_or_null("MilestoneMark")
		needs_rebuild = _day_buttons[0].get_node_or_null("CellCenter/DayCol/DayLabel") == null \
			or not (mark is TextureRect) \
			or not bool(_day_buttons[0].get_meta("milestone_tl", false))
	if not needs_rebuild:
		return
	for child in _grid.get_children():
		child.queue_free()
	_day_buttons.clear()
	_grid.columns = 7
	var side := _CELL_SIDE_MIN
	for i in range(42):
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(side, side)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.text = ""
		# Keep false so the ★ inset isn’t clipped by the cell’s rounded rect.
		btn.clip_contents = false
		btn.pressed.connect(_on_day_pressed.bind(i))
		var center := CenterContainer.new()
		center.name = "CellCenter"
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var col := VBoxContainer.new()
		col.name = "DayCol"
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 2)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var day_lbl := Label.new()
		day_lbl.name = "DayLabel"
		day_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		day_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		day_lbl.add_theme_font_size_override("font_size", _CELL_FONT)
		day_lbl.add_theme_color_override("font_color", _TEXT)
		day_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var dot := PanelContainer.new()
		dot.name = "GradeDot"
		dot.custom_minimum_size = Vector2(_GRADE_DOT_SIZE, _GRADE_DOT_SIZE)
		dot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.visible = false
		col.add_child(day_lbl)
		col.add_child(dot)
		center.add_child(col)
		btn.add_child(center)
		var milestone := TextureRect.new()
		milestone.name = "MilestoneMark"
		milestone.visible = false
		milestone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		milestone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		milestone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# Top-left, inset so the cell border does not cover the star.
		milestone.custom_minimum_size = Vector2(_MILESTONE_ICON, _MILESTONE_ICON)
		milestone.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		milestone.offset_left = 4.0
		milestone.offset_top = 4.0
		milestone.offset_right = 4.0 + float(_MILESTONE_ICON)
		milestone.offset_bottom = 4.0 + float(_MILESTONE_ICON)
		btn.add_child(milestone)
		btn.set_meta("milestone_tl", true)
		_grid.add_child(btn)
		_day_buttons.append(btn)


func _fit_square_cells() -> void:
	if _grid == null or _day_buttons.is_empty():
		return
	var sep_h := _grid.get_theme_constant("h_separation")
	var sep_v := _grid.get_theme_constant("v_separation")
	var avail_w := 0.0
	var avail_h := 0.0
	var cal_vbox := _grid.get_parent() as Control
	var cal_panel := cal_vbox.get_parent() as Control if cal_vbox else null
	if cal_panel:
		avail_w = cal_panel.size.x - 28.0
		# Nav + weekdays + two legend rows — tighter so the modal fits the viewport.
		avail_h = cal_panel.size.y - 112.0
	if avail_w < 32.0:
		avail_w = maxf(_grid.size.x, float(_CELL_SIDE_MIN * 7 + sep_h * 6))
	var side_w := floori((avail_w - float(sep_h) * 6.0) / 7.0)
	var side_h := floori((maxf(avail_h, float(_CELL_SIDE_MIN * 6)) - float(sep_v) * 5.0) / 6.0)
	var side := maxi(_CELL_SIDE_MIN, mini(side_w, side_h))
	# Prefer a slightly smaller cell so legends/footer stay visible.
	side = maxi(_CELL_SIDE_MIN, side - 3)
	var cell := Vector2(side, side)
	for btn in _day_buttons:
		if btn:
			btn.custom_minimum_size = cell
	_grid.custom_minimum_size = Vector2(side * 7 + sep_h * 6, side * 6 + sep_v * 5)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _ensure_legend() -> void:
	if _legend_row == null or _legend_built:
		return
	_legend_built = true
	for child in _legend_row.get_children():
		child.queue_free()
	var items: Array = [
		{"color": _ACTIVE_LV[1], "label": "1"},
		{"color": _ACTIVE_LV[2], "label": "2–3"},
		{"color": _ACTIVE_LV[3], "label": "4–6"},
		{"color": _ACTIVE_LV[4], "label": "7–9"},
		{"color": _ACTIVE_LV[5], "label": "10+"},
		{"color": _MISS, "label": "0"},
		{"color": Color(0.16, 0.2, 0.28, 1.0), "key": "PROFILE_ACTIVITY_LEGEND_TODAY", "outline": true},
	]
	for item in items:
		_legend_row.add_child(_make_swatch_chip(item))


func _ensure_grade_legend() -> void:
	if _grade_legend_row == null or _grade_legend_built:
		return
	_grade_legend_built = true
	for child in _grade_legend_row.get_children():
		child.queue_free()
	for grade in ["SS", "S", "A", "B", "C", "D", "F"]:
		_grade_legend_row.add_child(_make_grade_legend_item(grade))
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(10, 0)
	_grade_legend_row.add_child(sep)
	for m in _ActivityCalendar.STREAK_MILESTONE_DAYS:
		_grade_legend_row.add_child(_make_milestone_legend_item(int(m)))


func _make_swatch_chip(item: Dictionary) -> HBoxContainer:
	var color: Color = item.get("color", _MISS)
	var outline := bool(item.get("outline", false))
	var chip := HBoxContainer.new()
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_theme_constant_override("separation", 4)
	var wrap := _make_fixed_dot(color, 11, 3, outline)
	chip.add_child(wrap)
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", _TEXT_MUTED)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if item.has("key"):
		lbl.text = tr(str(item.get("key")))
		lbl.set_meta("legend_key", str(item.get("key")))
	else:
		lbl.text = str(item.get("label", ""))
	chip.add_child(lbl)
	return chip


func _make_milestone_legend_item(milestone: int) -> HBoxContainer:
	var chip := HBoxContainer.new()
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_theme_constant_override("separation", 3)
	var tint := _ActivityCalendar.milestone_color(milestone)
	var icon := _UiIconHelper.make_texture_rect(
		_UiIconHelper.load_tinted_icon("star.svg", tint, _UiIconHelper.raster_size_for_display(12)),
		12
	)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_child(icon)
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", _TEXT_MUTED)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lbl.text = str(milestone)
	chip.add_child(lbl)
	return chip


func _make_grade_legend_item(grade: String) -> HBoxContainer:
	var chip := HBoxContainer.new()
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_theme_constant_override("separation", 4)
	chip.add_child(_make_fixed_dot(_ActivityCalendar.grade_color(grade), 8, 8, false))
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", _TEXT_MUTED)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lbl.text = grade
	chip.add_child(lbl)
	return chip


func _make_fixed_dot(color: Color, size_px: int, corner: int, outline: bool) -> Control:
	## CenterContainer + fixed Panel so HBox height never stretches the swatch into a bar.
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(size_px, size_px)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wrap := PanelContainer.new()
	wrap.custom_minimum_size = Vector2(size_px, size_px)
	wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(corner)
	if outline:
		box.set_border_width_all(2)
		box.border_color = _TODAY_BORDER
	wrap.add_theme_stylebox_override("panel", box)
	holder.add_child(wrap)
	return holder


func _relabel_legend() -> void:
	if _legend_row == null:
		return
	_ensure_legend()
	for chip in _legend_row.get_children():
		for child in chip.get_children():
			if child is Label and child.has_meta("legend_key"):
				(child as Label).text = tr(str(child.get_meta("legend_key")))


func _on_prev_month() -> void:
	var prev := _ActivityCalendar.prev_month(_year, _month)
	_year = int(prev.year)
	_month = int(prev.month)
	_evolution_month_key = ""
	_UiModifierSounds.play_select()
	refresh()


func _on_next_month() -> void:
	var nxt := _ActivityCalendar.next_month(_year, _month)
	_year = int(nxt.year)
	_month = int(nxt.month)
	_evolution_month_key = ""
	_UiModifierSounds.play_select()
	refresh()


func _on_today_pressed() -> void:
	var today := _ActivityCalendar.today_str()
	var parts := today.split("-")
	if parts.size() == 3:
		_year = parts[0].to_int()
		_month = parts[1].to_int()
	_selected_date = today
	_UiModifierSounds.play_select()
	refresh()


func _on_mode_day() -> void:
	_set_panel_mode(_PANEL_DAY)


func _on_mode_month() -> void:
	_set_panel_mode(_PANEL_MONTH)


func _on_mode_week() -> void:
	_set_panel_mode(_PANEL_WEEK)


func _set_panel_mode(mode: String) -> void:
	if _panel_mode == mode:
		_sync_mode_buttons()
		return
	_panel_mode = mode
	_expanded_stats.clear()
	if mode != _PANEL_MONTH:
		_evolution_month_key = ""
	_sync_mode_buttons()
	_UiModifierSounds.play_select()
	_update_side_panel()


func _sync_mode_buttons() -> void:
	if _day_mode_btn:
		_day_mode_btn.set_pressed_no_signal(_panel_mode == _PANEL_DAY)
	if _month_mode_btn:
		_month_mode_btn.set_pressed_no_signal(_panel_mode == _PANEL_MONTH)
	if _week_mode_btn:
		_week_mode_btn.set_pressed_no_signal(_panel_mode == _PANEL_WEEK)


func _on_day_pressed(index: int) -> void:
	var cells := _ActivityCalendar.month_grid_cells(_year, _month)
	if index < 0 or index >= cells.size():
		return
	var cell: Dictionary = cells[index]
	var date_key := str(cell.get("date", ""))
	var today := _ActivityCalendar.today_str()
	var cal := PlayerDataManager.get_activity_calendar() if PlayerDataManager else _ActivityCalendar.empty_calendar()
	var window_days := int(cal.get("window_days", _ActivityCalendar.DEFAULT_WINDOW_DAYS))
	if date_key > today:
		return
	if not _ActivityCalendar.is_within_window(date_key, today, window_days):
		return
	var mode_changed := _panel_mode != _PANEL_DAY
	if date_key == _selected_date and not mode_changed:
		return
	_selected_date = date_key
	_panel_mode = _PANEL_DAY
	_expanded_stats.clear()
	_sync_mode_buttons()
	_UiModifierSounds.play_select()
	_rebuild_grid_visuals()
	_update_side_panel()


func _update_month_label() -> void:
	if _month_label == null:
		return
	_month_label.text = tr("PROFILE_ACTIVITY_MONTH_%d" % _month) + " %d" % _year


func _rebuild_grid_visuals() -> void:
	_ensure_day_buttons()
	var cells := _ActivityCalendar.month_grid_cells(_year, _month)
	var today := _ActivityCalendar.today_str()
	var cal := PlayerDataManager.get_activity_calendar() if PlayerDataManager else _ActivityCalendar.empty_calendar()
	var days: Dictionary = cal.get("days", {})
	var window_days := int(cal.get("window_days", _ActivityCalendar.DEFAULT_WINDOW_DAYS))
	for i in range(mini(42, _day_buttons.size())):
		var btn := _day_buttons[i]
		if i >= cells.size():
			btn.visible = false
			continue
		btn.visible = true
		var cell: Dictionary = cells[i]
		var date_key := str(cell.get("date", ""))
		var in_month := bool(cell.get("in_month", false))
		var day_num := int(cell.get("day", 0))
		btn.text = ""
		var day_lbl := btn.get_node_or_null("CellCenter/DayCol/DayLabel") as Label
		var grade_dot := btn.get_node_or_null("CellCenter/DayCol/GradeDot") as PanelContainer
		var milestone_mark := btn.get_node_or_null("MilestoneMark") as TextureRect
		if day_lbl:
			day_lbl.text = str(day_num)
		var future := date_key > today
		var in_window := _ActivityCalendar.is_within_window(date_key, today, window_days)
		var day_data: Dictionary = {}
		if days.has(date_key) and days[date_key] is Dictionary:
			day_data = _ActivityCalendar.sanitize_day(days[date_key])
		var intensity := _ActivityCalendar.day_intensity(day_data)
		var interactive := in_month and in_window and not future
		btn.disabled = not interactive
		btn.modulate = Color.WHITE if in_month else Color(1, 1, 1, 0.35)
		var bg := _MISS
		var border := Color(1, 1, 1, 0.08)
		var border_w := 1
		var font_color := _TEXT_MUTED
		var grade := ""
		var milestone := int(day_data.get("streak_milestone", 0))
		if not in_window or future or not in_month:
			bg = _DISABLED
			btn.tooltip_text = ""
		elif intensity <= 0:
			btn.tooltip_text = tr("PROFILE_ACTIVITY_CELL_TIP_EMPTY") % _format_day_title(date_key)
		else:
			var lv := clampi(intensity, 1, 5)
			bg = _ACTIVE_LV[lv]
			font_color = _TEXT
			grade = str(day_data.get("best_grade", "")).strip_edges()
			var tip_grade := grade if grade != "" else "—"
			if milestone > 0:
				btn.tooltip_text = tr("PROFILE_ACTIVITY_CELL_TIP_MILESTONE_FMT") % [
					_format_day_title(date_key),
					int(day_data.get("tracks", 0)),
					int(day_data.get("clears", 0)),
					int(day_data.get("fails", 0)),
					tip_grade,
					milestone,
				]
			else:
				btn.tooltip_text = tr("PROFILE_ACTIVITY_CELL_TIP_GRADE_FMT") % [
					_format_day_title(date_key),
					int(day_data.get("tracks", 0)),
					int(day_data.get("clears", 0)),
					int(day_data.get("fails", 0)),
					tip_grade,
				]
		if day_lbl:
			day_lbl.add_theme_color_override("font_color", font_color)
		_set_grade_dot(grade_dot, grade if intensity > 0 else "")
		_set_milestone_mark(milestone_mark, milestone if intensity > 0 else 0)
		var is_today := date_key == today and in_month
		if is_today:
			# Always mark today (even with no run); keep gold over selection so “today” stays obvious.
			border = _TODAY_BORDER
			border_w = 2
			if intensity <= 0 and in_window and not future:
				bg = _MISS.lerp(Color(_TODAY_BORDER.r, _TODAY_BORDER.g, _TODAY_BORDER.b, 1.0), 0.22)
		elif date_key == _selected_date and interactive:
			border = _ACTIVE
			border_w = 2
		_apply_cell_style(btn, bg, border, border_w)


func _set_grade_dot(dot: PanelContainer, grade: String) -> void:
	if dot == null:
		return
	if grade.strip_edges() == "":
		dot.visible = false
		return
	dot.visible = true
	var box := StyleBoxFlat.new()
	box.bg_color = _ActivityCalendar.grade_color(grade)
	box.set_corner_radius_all(_GRADE_DOT_SIZE)
	box.set_border_width_all(0)
	dot.add_theme_stylebox_override("panel", box)
	dot.custom_minimum_size = Vector2(_GRADE_DOT_SIZE, _GRADE_DOT_SIZE)


func _set_milestone_mark(icon: TextureRect, milestone: int) -> void:
	if icon == null:
		return
	if milestone <= 0:
		icon.visible = false
		return
	var tint := _ActivityCalendar.milestone_color(milestone)
	icon.texture = _UiIconHelper.load_tinted_icon(
		"star.svg", tint, _UiIconHelper.raster_size_for_display(_MILESTONE_ICON)
	)
	icon.modulate = Color.WHITE
	icon.visible = true
	icon.tooltip_text = tr("PROFILE_ACTIVITY_MILESTONE_TIP") % milestone


func _apply_cell_style(btn: Button, bg: Color, border: Color, border_w: int) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(10)
	box.set_border_width_all(border_w)
	box.border_color = border
	box.set_content_margin_all(0)
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		btn.add_theme_stylebox_override(StringName(state_name), box)


func _format_day_title(date_key: String) -> String:
	if date_key.strip_edges() == "":
		return "—"
	return _TimeUtils.format_iso_date_localized(date_key)


func _update_side_panel() -> void:
	match _panel_mode:
		_PANEL_WEEK:
			_update_week_panel()
		_PANEL_MONTH:
			_update_month_panel()
		_:
			_update_day_panel()


func _update_day_panel() -> void:
	if _day_title_label:
		_day_title_label.text = _format_day_title(_selected_date)
	var today := _ActivityCalendar.today_str()
	var cal := PlayerDataManager.get_activity_calendar() if PlayerDataManager else _ActivityCalendar.empty_calendar()
	var window_days := int(cal.get("window_days", _ActivityCalendar.DEFAULT_WINDOW_DAYS))
	var day: Dictionary = {}
	var has_run := false
	if _selected_date != "" and _selected_date <= today and _ActivityCalendar.is_within_window(_selected_date, today, window_days):
		day = PlayerDataManager.get_activity_day(_selected_date) if PlayerDataManager else {}
		has_run = _ActivityCalendar.day_was_played(day)
	var anniversary_only := false
	if not has_run and _selected_date != "" and _selected_date <= today:
		var ann := _MemoryFacts.find_anniversary_for_date(_selected_date)
		anniversary_only = not ann.is_empty()
	if _empty_day_label:
		_empty_day_label.visible = not has_run and not anniversary_only
		if not has_run and not anniversary_only:
			if _selected_date == "":
				_empty_day_label.text = tr("PROFILE_ACTIVITY_DETAIL_EMPTY")
			elif _selected_date > today or not _ActivityCalendar.is_within_window(_selected_date, today, window_days):
				_empty_day_label.text = tr("PROFILE_ACTIVITY_DETAIL_OUT_OF_RANGE")
			else:
				_empty_day_label.text = tr("PROFILE_ACTIVITY_DETAIL_NO_RUN") % _format_day_title(_selected_date)
	var show_stats := has_run or anniversary_only
	if _stats_scroll:
		_stats_scroll.visible = show_stats
	if _stats_list:
		_stats_list.visible = show_stats
	if not show_stats:
		_clear_stats_list()
		return
	_rebuild_day_stats(day)


func _update_month_panel() -> void:
	if _day_title_label:
		_day_title_label.text = tr("PROFILE_ACTIVITY_MONTH_%d" % _month) + " %d" % _year
	var cal := PlayerDataManager.get_activity_calendar() if PlayerDataManager else _ActivityCalendar.empty_calendar()
	var days: Dictionary = cal.get("days", {})
	var recap := _ActivityCalendar.build_month_recap(days, _year, _month)
	var play_days := int(recap.get("play_days", 0))
	var month_key := "%04d-%02d" % [int(recap.get("year", _year)), int(recap.get("month", _month))]
	# Evolution can exist (incl. demo capsule) even when the month has no play days in-window.
	var show_evolution := _evolution_month_key != "" or _capsule_usable(month_key)
	var show_panel := play_days > 0 or show_evolution
	if _empty_day_label:
		_empty_day_label.visible = not show_panel
		if not show_panel:
			_empty_day_label.text = tr("PROFILE_ACTIVITY_MONTH_EMPTY")
	if _stats_scroll:
		_stats_scroll.visible = show_panel
	if _stats_list:
		_stats_list.visible = show_panel
	if not show_panel:
		_clear_stats_list()
		return
	_rebuild_month_recap_and_stats(recap)


func _update_week_panel() -> void:
	var cal := PlayerDataManager.get_activity_calendar() if PlayerDataManager else _ActivityCalendar.empty_calendar()
	var days: Dictionary = cal.get("days", {})
	var anchor := _selected_date if _selected_date != "" else _ActivityCalendar.today_str()
	var summary := _ActivityCalendar.summarize_week(days, anchor)
	var start := str(summary.get("start", ""))
	var end := str(summary.get("end", ""))
	if _day_title_label:
		if start != "" and end != "":
			_day_title_label.text = tr("PROFILE_ACTIVITY_WEEK_RANGE_FMT") % [
				_format_day_title(start),
				_format_day_title(end),
			]
		else:
			_day_title_label.text = tr("PROFILE_ACTIVITY_MODE_WEEK")
	var play_days := int(summary.get("play_days", 0))
	if _empty_day_label:
		_empty_day_label.visible = play_days <= 0
		if play_days <= 0:
			_empty_day_label.text = tr("PROFILE_ACTIVITY_WEEK_EMPTY")
	if _stats_scroll:
		_stats_scroll.visible = play_days > 0
	if _stats_list:
		_stats_list.visible = play_days > 0
	if play_days <= 0:
		_clear_stats_list()
		return
	_rebuild_period_stats(summary)


func _rebuild_month_recap_and_stats(recap: Dictionary) -> void:
	_clear_stats_list()
	if _stats_list == null:
		return
	if _evolution_month_key != "":
		_rebuild_evolution_panel(_evolution_month_key)
		return
	_stats_list.add_theme_constant_override("separation", 6)
	var month_key := "%04d-%02d" % [int(recap.get("year", _year)), int(recap.get("month", _month))]
	if _capsule_usable(month_key):
		_stats_list.add_child(_make_evolution_open_button(month_key))
	_append_period_stat_rows(recap)


func _capsule_usable(month_key: String) -> bool:
	if not _TimeCapsule.is_past_month(month_key):
		return false
	if PlayerDataManager == null:
		return false
	return not PlayerDataManager.get_time_capsule(month_key).is_empty()


func _make_evolution_open_button(month_key: String) -> Button:
	var btn := Button.new()
	btn.text = tr("PLAYER_EVOLUTION_OPEN")
	btn.custom_minimum_size = Vector2(0, 40)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.theme_type_variation = &"FlatPlayButton"
	btn.focus_mode = Control.FOCUS_NONE
	btn.tooltip_text = tr("PLAYER_EVOLUTION_OPEN_HINT")
	_UiIconHelper.configure_button_icon(btn, "sparkles.svg", Color(0.72, 0.62, 0.95, 1.0), 16)
	btn.pressed.connect(func() -> void:
		_UiModifierSounds.play_select()
		_evolution_month_key = month_key
		_update_side_panel()
	)
	return btn


func _rebuild_evolution_panel(month_key: String) -> void:
	_clear_stats_list()
	if _stats_list == null:
		return
	_stats_list.add_theme_constant_override("separation", 6)
	if not _capsule_usable(month_key):
		_evolution_month_key = ""
		_update_side_panel()
		return
	var capsule := PlayerDataManager.get_time_capsule(month_key)
	var header := PanelContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.72, 0.62, 0.95, 0.14)
	box.border_color = Color(0.72, 0.62, 0.95, 0.45)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	header.add_theme_stylebox_override("panel", box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	header.add_child(col)
	var title := Label.new()
	title.text = tr("PLAYER_EVOLUTION_TITLE") % _PlayerEvolution.month_title(month_key)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.9, 0.86, 1.0, 1.0))
	col.add_child(title)
	var blurb := Label.new()
	blurb.text = tr("PLAYER_EVOLUTION_BLURB")
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.add_theme_font_size_override("font_size", 12)
	blurb.add_theme_color_override("font_color", _TEXT_MUTED)
	col.add_child(blurb)
	if bool(capsule.get("demo", false)):
		var demo_note := Label.new()
		demo_note.text = tr("PLAYER_EVOLUTION_DEMO_NOTE")
		demo_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		demo_note.add_theme_font_size_override("font_size", 11)
		demo_note.add_theme_color_override("font_color", Color(0.86, 0.72, 0.42, 0.95))
		col.add_child(demo_note)
	_stats_list.add_child(header)

	var back_btn := Button.new()
	back_btn.text = tr("PLAYER_EVOLUTION_BACK")
	back_btn.custom_minimum_size = Vector2(0, 36)
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.theme_type_variation = &"FlatBackButton"
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.pressed.connect(func() -> void:
		_UiModifierSounds.play_select()
		_evolution_month_key = ""
		_update_side_panel()
	)
	_stats_list.add_child(back_btn)

	var legend := Label.new()
	legend.text = "%s → %s" % [tr("PLAYER_EVOLUTION_THEN"), tr("PLAYER_EVOLUTION_NOW")]
	legend.add_theme_font_size_override("font_size", 12)
	legend.add_theme_color_override("font_color", _TEXT_MUTED)
	_stats_list.add_child(legend)

	var pdata: Dictionary = PlayerDataManager.data if PlayerDataManager else {}
	for row in _PlayerEvolution.build_comparison(capsule, pdata):
		if row is Dictionary:
			_stats_list.add_child(_make_evolution_row(row as Dictionary))


func _make_evolution_row(row: Dictionary) -> PanelContainer:
	var hint := str(row.get("tint_hint", ""))
	var value_color := _TEXT
	match hint:
		"up":
			value_color = _STAT_ICON_CLEARS
		"down":
			value_color = _STAT_ICON_FAILS
		"changed":
			value_color = Color(0.86, 0.80, 0.98, 1.0)
		_:
			value_color = _TEXT
	var then_text := str(row.get("then_text", "—"))
	var now_text := str(row.get("now_text", "—"))
	var delta := str(row.get("delta_text", "")).strip_edges()
	var value := "%s → %s" % [then_text, now_text]
	if delta != "" and delta != "→":
		value = "%s  (%s)" % [value, delta]
	var icon := str(row.get("icon", "sparkles.svg")).strip_edges()
	if icon == "":
		icon = "sparkles.svg"
	return _make_stat_row(
		icon,
		_evolution_icon_tint(icon),
		tr(str(row.get("caption_key", ""))),
		value,
		false,
		false,
		value_color
	)


func _evolution_icon_tint(icon_file: String) -> Color:
	match icon_file:
		"chart-column.svg":
			return Color(0.72, 0.58, 0.95, 1.0)
		"fingerprint-pattern.svg":
			return Color(0.75, 0.52, 0.98, 1.0)
		"target.svg":
			return _STAT_ICON_SCORE
		"calendar.svg":
			return _STAT_ICON_TRACKS
		"trophy.svg":
			return _STAT_ICON_GRADE
		"headphones.svg":
			return Color(0.86, 0.72, 0.98, 1.0)
		"circle-play.svg":
			return _STAT_ICON_TRACKS
		"music.svg":
			return _STAT_ICON_TRACKS
		"zap.svg":
			return _STAT_ICON_GRADE
		_:
			return Color(0.72, 0.62, 0.95, 1.0)


func _rebuild_period_stats(summary: Dictionary) -> void:
	## Week panel: same core metrics as the day panel (+ play days + busiest day).
	_clear_stats_list()
	if _stats_list == null:
		return
	_stats_list.add_theme_constant_override("separation", 6)
	_append_period_stat_rows(summary)


func _append_period_stat_rows(summary: Dictionary) -> void:
	if _stats_list == null:
		return
	_stats_list.add_child(_make_stat_row(
		"calendar.svg", _STAT_ICON_TRACKS,
		tr("PROFILE_ACTIVITY_STAT_PLAY_DAYS"),
		str(int(summary.get("play_days", 0))),
		false
	))
	var day_like := {
		"tracks": int(summary.get("tracks", 0)),
		"clears": int(summary.get("clears", 0)),
		"fails": int(summary.get("fails", 0)),
		"play_seconds": int(summary.get("play_seconds", 0)),
		"best_grade": str(summary.get("best_grade", "")),
		"best_score": int(summary.get("best_score", 0)),
		"max_combo": int(summary.get("max_combo", 0)),
		"by_instrument": summary.get("by_instrument", {}),
	}
	_stats_list.add_child(_make_stat_row(
		"clock.svg",
		_STAT_ICON_TIME,
		tr("PROFILE_ACTIVITY_STAT_PLAY_TIME"),
		_ActivityCalendar.format_play_hms(int(day_like.get("play_seconds", 0))),
		false
	))
	var breakdown := _instrument_breakdown(day_like)
	var grade := str(day_like.get("best_grade", "")).strip_edges()
	var score := int(day_like.get("best_score", 0))
	var combo := int(day_like.get("max_combo", 0))
	_stats_list.add_child(_make_expandable_stat(
		"tracks", "music.svg", _STAT_ICON_TRACKS,
		tr("PROFILE_ACTIVITY_STAT_TRACKS"),
		str(int(day_like.get("tracks", 0))),
		breakdown, "tracks"
	))
	_stats_list.add_child(_make_expandable_stat(
		"clears", "trophy.svg", _STAT_ICON_CLEARS,
		tr("PROFILE_ACTIVITY_STAT_CLEARS"),
		str(int(day_like.get("clears", 0))),
		breakdown, "clears"
	))
	_stats_list.add_child(_make_expandable_stat(
		"fails", "ban.svg", _STAT_ICON_FAILS,
		tr("PROFILE_ACTIVITY_STAT_FAILS"),
		str(int(day_like.get("fails", 0))),
		breakdown, "fails"
	))
	_stats_list.add_child(_make_expandable_stat(
		"best_grade", "zap.svg", _STAT_ICON_GRADE,
		tr("PROFILE_ACTIVITY_STAT_BEST_GRADE"),
		grade if grade != "" else "—",
		breakdown, "best_grade",
		_ActivityCalendar.grade_color(grade) if grade != "" else _TEXT
	))
	_stats_list.add_child(_make_expandable_stat(
		"best_score", "target.svg", _STAT_ICON_SCORE,
		tr("PROFILE_ACTIVITY_STAT_BEST_SCORE"),
		_ActivityCalendar.format_score(score) if score > 0 else "—",
		breakdown, "best_score"
	))
	_stats_list.add_child(_make_expandable_stat(
		"max_combo", "flame.svg", _STAT_ICON_COMBO,
		tr("PROFILE_ACTIVITY_STAT_MAX_COMBO"),
		str(combo) if combo > 0 else "—",
		breakdown, "max_combo"
	))
	var fav := str(summary.get("favorite_instrument", ""))
	if fav != "":
		var fav_icon := "drum.svg" if fav == "drums" else "guitar.svg"
		var fav_tint := _STAT_ICON_DRUMS if fav == "drums" else _STAT_ICON_BASS
		_stats_list.add_child(_make_stat_row(
			fav_icon, fav_tint,
			tr("PROFILE_ACTIVITY_STAT_FAVORITE_INSTRUMENT"),
			_GenPresetUi.localized_instrument(fav),
			false
		))
	var busiest := str(summary.get("busiest_date", ""))
	var busiest_tracks := int(summary.get("busiest_tracks", 0))
	if busiest != "" and busiest_tracks > 0:
		_stats_list.add_child(_make_stat_row(
			"trophy.svg", _STAT_ICON_GRADE,
			tr("PROFILE_ACTIVITY_STAT_BUSIEST_DAY"),
			"%s · %d" % [_format_day_title(busiest), busiest_tracks],
			false
		))


func _highlight_label(highlight: Dictionary) -> String:
	var kind := str(highlight.get("kind", ""))
	match kind:
		"streak_milestone":
			return tr("PROFILE_ACTIVITY_HIGHLIGHT_STREAK") % int(highlight.get("milestone", 0))
		"first_ss":
			return tr("PROFILE_ACTIVITY_HIGHLIGHT_FIRST_SS")
		"score_record":
			var score := int(str(highlight.get("value", "0")))
			return tr("PROFILE_ACTIVITY_HIGHLIGHT_SCORE") % _ActivityCalendar.format_score(score)
		"first_instrument":
			var inst := str(highlight.get("instrument", "drums"))
			return tr("PROFILE_ACTIVITY_HIGHLIGHT_FIRST_INSTRUMENT") % _GenPresetUi.localized_instrument(inst)
		_:
			return ""


func _clear_stats_list() -> void:
	if _stats_list == null:
		return
	for child in _stats_list.get_children():
		child.queue_free()


func _instrument_breakdown(day: Dictionary) -> Array:
	## [{id, label, icon, tint, bucket}, ...] only instruments with tracks > 0.
	var out: Array = []
	var by_i: Dictionary = day.get("by_instrument", {}) if day.get("by_instrument", {}) is Dictionary else {}
	var specs := [
		["drums", "drum.svg", _STAT_ICON_DRUMS],
		["bass", "guitar.svg", _STAT_ICON_BASS],
	]
	for spec in specs:
		var inst := str(spec[0])
		var bucket := _ActivityCalendar.sanitize_instrument_bucket(by_i.get(inst, {}))
		if int(bucket.get("tracks", 0)) <= 0:
			continue
		out.append({
			"id": inst,
			"label": _GenPresetUi.localized_instrument(inst),
			"icon": str(spec[1]),
			"tint": spec[2],
			"bucket": bucket,
		})
	return out


func _render_day_plaque(plaque: Dictionary) -> Dictionary:
	if plaque.is_empty():
		return {}
	if str(plaque.get("kind", "")) == "anniversary":
		var years := int(plaque.get("years", 1))
		var title := str(plaque.get("title", "")).strip_edges()
		if title == "":
			title = "—"
		var value := tr("PROFILE_ACTIVITY_MEMORY_YEARS_FMT") % [years, title]
		if years == 1:
			value = tr("PROFILE_ACTIVITY_MEMORY_ONE_YEAR_FMT") % title
		return {
			"icon": str(plaque.get("icon", "rewind.svg")),
			"tint": _STAT_ICON_MEMORY,
			"caption": tr("PROFILE_ACTIVITY_STAT_MEMORY"),
			"value": value,
		}
	var rendered := _render_story_fact(plaque)
	if rendered.is_empty():
		return {}
	return {
		"icon": str(rendered.get("icon", "sparkles.svg")),
		"tint": rendered.get("tint", _STAT_ICON_FACT),
		"caption": tr("PROFILE_ACTIVITY_STAT_FACT"),
		"value": str(rendered.get("value", "")),
	}


func _render_story_fact(fact: Dictionary) -> Dictionary:
	if fact.is_empty():
		return {}
	var fact_id := str(fact.get("fact_id", ""))
	var icon := str(fact.get("icon", "sparkles.svg"))
	var tint := _STAT_ICON_FACT
	var value := ""
	match fact_id:
		"clean_day":
			value = tr("PROFILE_ACTIVITY_FACT_CLEAN_DAY_FMT") % int(fact.get("clears", 0))
			tint = _STAT_ICON_CLEARS
		"busy_day":
			value = tr("PROFILE_ACTIVITY_FACT_BUSY_DAY_FMT") % int(fact.get("tracks", 0))
			tint = _STAT_ICON_TRACKS
		"combo_day":
			value = tr("PROFILE_ACTIVITY_FACT_COMBO_DAY_FMT") % int(fact.get("combo", 0))
			tint = _STAT_ICON_COMBO
		"month_anniversaries":
			value = tr("PROFILE_ACTIVITY_FACT_MONTH_ANNIVERSARIES_FMT") % int(fact.get("count", 0))
			tint = _STAT_ICON_MEMORY
			icon = "rewind.svg"
		"month_first_ss":
			var n := int(fact.get("count", 0))
			value = tr("PROFILE_ACTIVITY_HIGHLIGHT_FIRST_SS") if n <= 1 else (tr("PROFILE_ACTIVITY_FACT_MONTH_FIRST_SS_FMT") % n)
			tint = _STAT_ICON_GRADE
			icon = "crown.svg"
		"month_score_records":
			value = tr("PROFILE_ACTIVITY_RECAP_SCORE_RECORDS_FMT") % int(fact.get("count", 0))
			tint = _STAT_ICON_SCORE
			icon = "target.svg"
		"month_clean_days":
			value = tr("PROFILE_ACTIVITY_FACT_MONTH_CLEAN_DAYS_FMT") % int(fact.get("count", 0))
			tint = _STAT_ICON_CLEARS
		"month_max_combo":
			value = tr("PROFILE_ACTIVITY_FACT_MONTH_MAX_COMBO_FMT") % int(fact.get("combo", 0))
			tint = _STAT_ICON_COMBO
		"month_new_tracks":
			value = tr("PROFILE_ACTIVITY_FACT_MONTH_NEW_TRACKS_FMT") % int(fact.get("count", 0))
			tint = _STAT_ICON_TRACKS
		_:
			return {}
	return {
		"icon": icon,
		"tint": tint,
		"caption": tr("PROFILE_ACTIVITY_RECAP_FACT"),
		"value": value,
	}


func _rebuild_day_stats(day: Dictionary) -> void:
	_clear_stats_list()
	if _stats_list == null:
		return
	_stats_list.add_theme_constant_override("separation", 6)
	var has_run := _ActivityCalendar.day_was_played(day)
	var highlight := _ActivityCalendar.sanitize_highlight(day.get("highlight", {}))
	var hl_text := _highlight_label(highlight)
	if hl_text != "":
		_stats_list.add_child(_make_stat_row(
			"sparkles.svg",
			_STAT_ICON_HIGHLIGHT,
			tr("PROFILE_ACTIVITY_STAT_HIGHLIGHT"),
			hl_text,
			false
		))
	if has_run:
		_stats_list.add_child(_make_stat_row(
			"clock.svg",
			_STAT_ICON_TIME,
			tr("PROFILE_ACTIVITY_STAT_PLAY_TIME"),
			_ActivityCalendar.format_play_hms(_ActivityCalendar.day_play_seconds(day)),
			false
		))
		var breakdown := _instrument_breakdown(day)
		var grade := str(day.get("best_grade", "")).strip_edges()
		var score := int(day.get("best_score", 0))
		var combo := int(day.get("max_combo", 0))
		_stats_list.add_child(_make_expandable_stat(
			"tracks", "music.svg", _STAT_ICON_TRACKS,
			tr("PROFILE_ACTIVITY_STAT_TRACKS"),
			str(int(day.get("tracks", 0))),
			breakdown, "tracks"
		))
		_stats_list.add_child(_make_expandable_stat(
			"clears", "trophy.svg", _STAT_ICON_CLEARS,
			tr("PROFILE_ACTIVITY_STAT_CLEARS"),
			str(int(day.get("clears", 0))),
			breakdown, "clears"
		))
		_stats_list.add_child(_make_expandable_stat(
			"fails", "ban.svg", _STAT_ICON_FAILS,
			tr("PROFILE_ACTIVITY_STAT_FAILS"),
			str(int(day.get("fails", 0))),
			breakdown, "fails"
		))
		var grade_block := _make_expandable_stat(
			"best_grade", "zap.svg", _STAT_ICON_GRADE,
			tr("PROFILE_ACTIVITY_STAT_BEST_GRADE"),
			grade if grade != "" else "—",
			breakdown, "best_grade",
			_ActivityCalendar.grade_color(grade) if grade != "" else _TEXT
		)
		_stats_list.add_child(grade_block)
		_stats_list.add_child(_make_expandable_stat(
			"best_score", "target.svg", _STAT_ICON_SCORE,
			tr("PROFILE_ACTIVITY_STAT_BEST_SCORE"),
			_ActivityCalendar.format_score(score) if score > 0 else "—",
			breakdown, "best_score"
		))
		_stats_list.add_child(_make_expandable_stat(
			"max_combo", "flame.svg", _STAT_ICON_COMBO,
			tr("PROFILE_ACTIVITY_STAT_MAX_COMBO"),
			str(combo) if combo > 0 else "—",
			breakdown, "max_combo"
		))
	# Year-ago / day fact after the numbers (not competing with max combo etc.).
	var plaque := _MemoryFacts.pick_day_plaque(_selected_date, day)
	var plaque_row := _render_day_plaque(plaque)
	if not plaque_row.is_empty():
		_stats_list.add_child(_make_stat_row(
			str(plaque_row.get("icon", "sparkles.svg")),
			plaque_row.get("tint", _STAT_ICON_FACT) as Color,
			str(plaque_row.get("caption", "")),
			str(plaque_row.get("value", "")),
			false
		))


func _format_bucket_field(bucket: Dictionary, field: String) -> String:
	match field:
		"tracks", "clears", "fails":
			return str(int(bucket.get(field, 0)))
		"best_grade":
			var g := str(bucket.get("best_grade", "")).strip_edges()
			return g if g != "" else "—"
		"best_score":
			var sc := int(bucket.get("best_score", 0))
			return _ActivityCalendar.format_score(sc) if sc > 0 else "—"
		"max_combo":
			var c := int(bucket.get("max_combo", 0))
			return str(c) if c > 0 else "—"
		_:
			return "—"


func _make_expandable_stat(
	key: String,
	icon_file: String,
	tint: Color,
	caption_text: String,
	value_text: String,
	breakdown: Array,
	field: String,
	value_color: Color = _TEXT
) -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 4)
	var can_expand := not breakdown.is_empty()
	var expanded := can_expand and bool(_expanded_stats.get(key, false))
	var header := _make_stat_row(icon_file, tint, caption_text, value_text, can_expand, expanded, value_color)
	wrap.add_child(header)
	var detail := VBoxContainer.new()
	detail.name = "Detail"
	detail.visible = expanded
	detail.add_theme_constant_override("separation", 4)
	for entry in breakdown:
		if not entry is Dictionary:
			continue
		var bucket: Dictionary = entry.get("bucket", {})
		var line := _make_instrument_detail_row(
			str(entry.get("icon", "music.svg")),
			entry.get("tint", _STAT_ICON_TRACKS) as Color,
			str(entry.get("label", "")),
			_format_bucket_field(bucket, field),
			field,
			bucket
		)
		detail.add_child(line)
	wrap.add_child(detail)
	if can_expand:
		header.gui_input.connect(_on_expandable_header_gui_input.bind(key, detail, header))
		header.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return wrap


func _on_expandable_header_gui_input(
	event: InputEvent,
	key: String,
	detail: VBoxContainer,
	header: PanelContainer
) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var now_open := not detail.visible
	detail.visible = now_open
	_expanded_stats[key] = now_open
	_set_expand_chevron(header, now_open)
	_UiModifierSounds.play_select()


func _set_expand_chevron(header: PanelContainer, expanded: bool) -> void:
	var chevron := header.find_child("Chevron", true, false) as Label
	if chevron:
		chevron.text = "▾" if expanded else "▸"


func _make_instrument_detail_row(
	icon_file: String,
	tint: Color,
	label_text: String,
	value_text: String,
	field: String,
	bucket: Dictionary
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.1, 0.16, 0.85)
	box.set_corner_radius_all(8)
	box.set_border_width_all(1)
	box.border_color = Color(tint.r, tint.g, tint.b, 0.22)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var indent := Control.new()
	indent.custom_minimum_size = Vector2(10, 0)
	row.add_child(indent)
	row.add_child(_UiIconHelper.make_icon_frame(icon_file, 24, 13, tint))
	var caption := Label.new()
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.add_theme_font_size_override("font_size", 13)
	caption.add_theme_color_override("font_color", _TEXT_MUTED)
	caption.text = label_text
	row.add_child(caption)
	var value := Label.new()
	value.add_theme_font_size_override("font_size", 15)
	var vcolor := _TEXT
	if field == "best_grade":
		var g := str(bucket.get("best_grade", "")).strip_edges()
		if g != "":
			vcolor = _ActivityCalendar.grade_color(g)
	value.add_theme_color_override("font_color", vcolor)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.text = value_text
	row.add_child(value)
	return panel


func _make_stat_row(
	icon_file: String,
	tint: Color,
	caption_text: String,
	value_text: String,
	expandable: bool = false,
	expanded: bool = false,
	value_color: Color = _TEXT
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := StyleBoxFlat.new()
	box.bg_color = _STAT_ROW_BG
	box.set_corner_radius_all(10)
	box.set_border_width_all(1)
	box.border_color = Color(1, 1, 1, 0.06)
	box.content_margin_left = 10.0
	box.content_margin_right = 12.0
	box.content_margin_top = 7.0
	box.content_margin_bottom = 7.0
	panel.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	row.add_child(_UiIconHelper.make_icon_frame(icon_file, 28, 15, tint))
	var caption := Label.new()
	caption.name = "Caption"
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	caption.add_theme_font_size_override("font_size", 13)
	caption.add_theme_color_override("font_color", _TEXT_MUTED)
	caption.text = caption_text
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(caption)
	var value := Label.new()
	value.name = "Value"
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	value.add_theme_font_size_override("font_size", 17)
	value.add_theme_color_override("font_color", value_color)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.text = value_text
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(value)
	if expandable:
		var chevron := Label.new()
		chevron.name = "Chevron"
		chevron.add_theme_font_size_override("font_size", 14)
		chevron.add_theme_color_override("font_color", _TEXT_MUTED)
		chevron.text = "▾" if expanded else "▸"
		chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(chevron)
	return panel


func _update_today_status() -> void:
	if _today_status_label == null:
		return
	var played := false
	if PlayerDataManager and PlayerDataManager.has_method("activity_played_today"):
		played = PlayerDataManager.activity_played_today()
	if played:
		_today_status_label.text = tr("PROFILE_ACTIVITY_TODAY_COUNTED")
	else:
		_today_status_label.text = tr("PROFILE_ACTIVITY_TODAY_PENDING")


func _on_back_pressed() -> void:
	_close()


func close(with_sound: bool = true) -> void:
	_close(with_sound)


func _close(with_sound: bool = true) -> void:
	if not visible:
		return
	if with_sound:
		_UiModifierSounds.play_deselect()
	visible = false
	closed.emit()
