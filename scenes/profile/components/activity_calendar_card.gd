# scenes/profile/components/activity_calendar_card.gd
extends PanelContainer

const _ActivityCalendar = preload("res://logic/domain/profile/activity_calendar.gd")

const _CELL_MIN := Vector2(36, 34)
const _ACTIVE := Color(0.45, 0.72, 0.95, 1.0)
const _MISS := Color(0.22, 0.26, 0.34, 1.0)
const _DISABLED := Color(0.14, 0.16, 0.2, 0.55)
const _TODAY_BORDER := Color(0.95, 0.82, 0.45, 0.95)
const _TEXT := Color(0.88, 0.92, 0.98, 1.0)
const _TEXT_MUTED := Color(0.55, 0.6, 0.7, 0.85)

var _year: int = 0
var _month: int = 0
var _selected_date: String = ""
var _day_buttons: Array[Button] = []
var _weekday_labels: Array[Label] = []

@onready var _title_label: Label = $ContentVBox/HeaderRow/TitleLabel
@onready var _streak_label: Label = $ContentVBox/HeaderRow/StreakLabel
@onready var _prev_btn: Button = $ContentVBox/NavRow/PrevMonthButton
@onready var _month_label: Label = $ContentVBox/NavRow/MonthLabel
@onready var _next_btn: Button = $ContentVBox/NavRow/NextMonthButton
@onready var _weekday_row: HBoxContainer = $ContentVBox/WeekdayRow
@onready var _grid: GridContainer = $ContentVBox/DaysGrid
@onready var _detail_label: Label = $ContentVBox/DetailLabel


func _ready() -> void:
	var today := _ActivityCalendar.today_str()
	var parts := today.split("-")
	_year = parts[0].to_int() if parts.size() == 3 else Time.get_datetime_dict_from_system().year
	_month = parts[1].to_int() if parts.size() == 3 else Time.get_datetime_dict_from_system().month
	_selected_date = today
	_ensure_weekdays()
	_ensure_day_buttons()
	if _prev_btn and not _prev_btn.pressed.is_connected(_on_prev_month):
		_prev_btn.pressed.connect(_on_prev_month)
	if _next_btn and not _next_btn.pressed.is_connected(_on_next_month):
		_next_btn.pressed.connect(_on_next_month)
	apply_locale()
	refresh()
	if PlayerDataManager and PlayerDataManager.has_signal("activity_calendar_changed"):
		if not PlayerDataManager.activity_calendar_changed.is_connected(refresh):
			PlayerDataManager.activity_calendar_changed.connect(refresh)


func apply_locale() -> void:
	if _title_label:
		_title_label.text = tr("PROFILE_ACTIVITY_TITLE")
	if _prev_btn:
		_prev_btn.text = "<"
		_prev_btn.tooltip_text = tr("PROFILE_ACTIVITY_PREV_MONTH")
	if _next_btn:
		_next_btn.text = ">"
		_next_btn.tooltip_text = tr("PROFILE_ACTIVITY_NEXT_MONTH")
	_ensure_weekdays()
	for i in mini(7, _weekday_labels.size()):
		_weekday_labels[i].text = tr("PROFILE_ACTIVITY_WEEKDAY_%d" % i)
	_update_streak_label()
	_update_month_label()
	_update_detail()


func refresh() -> void:
	_update_streak_label()
	_update_month_label()
	_rebuild_grid_visuals()
	_update_detail()


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
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", _TEXT_MUTED)
		lbl.text = tr("PROFILE_ACTIVITY_WEEKDAY_%d" % i)
		_weekday_row.add_child(lbl)
		_weekday_labels.append(lbl)


func _ensure_day_buttons() -> void:
	if _grid == null:
		return
	if _day_buttons.size() >= 42:
		return
	for child in _grid.get_children():
		child.queue_free()
	_day_buttons.clear()
	_grid.columns = 7
	for i in range(42):
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = _CELL_MIN
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(_on_day_pressed.bind(i))
		_grid.add_child(btn)
		_day_buttons.append(btn)


func _on_prev_month() -> void:
	var prev := _ActivityCalendar.prev_month(_year, _month)
	_year = int(prev.year)
	_month = int(prev.month)
	refresh()


func _on_next_month() -> void:
	var nxt := _ActivityCalendar.next_month(_year, _month)
	_year = int(nxt.year)
	_month = int(nxt.month)
	refresh()


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
	_selected_date = date_key
	_rebuild_grid_visuals()
	_update_detail()


func _update_streak_label() -> void:
	if _streak_label == null or PlayerDataManager == null:
		return
	var cur := PlayerDataManager.get_login_streak()
	var best := PlayerDataManager.get_best_login_streak()
	_streak_label.text = tr("PROFILE_ACTIVITY_STREAK_FMT") % [cur, best]


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
		btn.text = str(day_num)
		var future := date_key > today
		var in_window := _ActivityCalendar.is_within_window(date_key, today, window_days)
		var day_data: Dictionary = {}
		if days.has(date_key) and days[date_key] is Dictionary:
			day_data = _ActivityCalendar.sanitize_day(days[date_key])
		var played := bool(day_data.get("in", false)) or int(day_data.get("tracks", 0)) > 0
		var interactive := in_month and in_window and not future
		btn.disabled = not interactive
		btn.modulate = Color.WHITE if in_month else Color(1, 1, 1, 0.35)
		var bg := _MISS
		var border := Color(1, 1, 1, 0.08)
		var border_w := 1
		if not in_window or future or not in_month:
			bg = _DISABLED
			btn.add_theme_color_override("font_color", _TEXT_MUTED)
		elif played:
			bg = Color(_ACTIVE.r, _ACTIVE.g, _ACTIVE.b, 0.35)
			btn.add_theme_color_override("font_color", _TEXT)
		else:
			btn.add_theme_color_override("font_color", _TEXT_MUTED)
		if date_key == today and in_month:
			border = _TODAY_BORDER
			border_w = 2
		if date_key == _selected_date and interactive:
			border = _ACTIVE
			border_w = 2
		_apply_cell_style(btn, bg, border, border_w)


func _apply_cell_style(btn: Button, bg: Color, border: Color, border_w: int) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(6)
	box.set_border_width_all(border_w)
	box.border_color = border
	box.set_content_margin_all(2)
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		btn.add_theme_stylebox_override(StringName(state_name), box)


func _update_detail() -> void:
	if _detail_label == null:
		return
	if _selected_date == "":
		_detail_label.text = tr("PROFILE_ACTIVITY_DETAIL_EMPTY")
		return
	var today := _ActivityCalendar.today_str()
	var cal := PlayerDataManager.get_activity_calendar() if PlayerDataManager else _ActivityCalendar.empty_calendar()
	var window_days := int(cal.get("window_days", _ActivityCalendar.DEFAULT_WINDOW_DAYS))
	if _selected_date > today or not _ActivityCalendar.is_within_window(_selected_date, today, window_days):
		_detail_label.text = tr("PROFILE_ACTIVITY_DETAIL_OUT_OF_RANGE")
		return
	var day := PlayerDataManager.get_activity_day(_selected_date) if PlayerDataManager else {}
	var tracks := int(day.get("tracks", 0))
	if not _ActivityCalendar.day_was_played(day):
		_detail_label.text = tr("PROFILE_ACTIVITY_DETAIL_NO_RUN") % _selected_date
		return
	var mins := _ActivityCalendar.format_play_minutes(_ActivityCalendar.day_play_seconds(day))
	var grade := str(day.get("best_grade", ""))
	if grade == "":
		grade = "—"
	var clears := int(day.get("clears", 0))
	var fails := int(day.get("fails", 0))
	_detail_label.text = tr("PROFILE_ACTIVITY_DETAIL_FMT") % [
		_selected_date,
		tracks,
		clears,
		fails,
		mins,
		grade,
	]
