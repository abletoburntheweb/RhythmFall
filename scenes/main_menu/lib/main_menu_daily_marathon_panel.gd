# scenes/main_menu/lib/main_menu_daily_marathon_panel.gd
extends PanelContainer
class_name MainMenuDailyMarathonPanel

signal play_pressed()
signal details_pressed()

const _MarathonDailyRoute = preload("res://logic/domain/session/marathon_daily_route.gd")
const _PlayModeIds = preload("res://logic/domain/session/play_mode_ids.gd")
const _SongSelectUiStyles = preload("res://scenes/song_select/lib/song_select_ui_styles.gd")
const _TimeUtils = preload("res://logic/platform/time_utils.gd")

var _title_label: Label = null
var _date_label: Label = null
var _summary_label: Label = null
var _status_label: Label = null
var _play_button: Button = null
var _details_button: Button = null


func _ready() -> void:
	_build_ui()
	apply_locale()
	refresh()


func apply_locale() -> void:
	if _title_label:
		_title_label.text = tr("MAIN_DAILY_MARATHON_TITLE")
	if _play_button:
		_play_button.text = tr("MAIN_DAILY_MARATHON_PLAY")
	if _details_button:
		_details_button.text = tr("MAIN_DAILY_MARATHON_DETAILS")
	refresh()


func refresh() -> void:
	var route_id := _MarathonDailyRoute.today_route_id()
	var template := _MarathonDailyRoute.template_for_route_id(route_id)
	if _date_label:
		_date_label.text = tr("MAIN_DAILY_MARATHON_DATE_FMT") % _TimeUtils.format_iso_date_localized(
			str(template.get("daily_date", _MarathonDailyRoute.today_iso_date()))
		)
	if _summary_label:
		_summary_label.text = _MarathonDailyRoute.summary_line(template)
	if _status_label:
		_status_label.text = _completion_status(route_id)


func _completion_status(route_id: String) -> String:
	if PlayerDataManager == null:
		return tr("MAIN_DAILY_MARATHON_STATUS_OPEN")
	var completions: Variant = PlayerDataManager.data.get("marathon_completions", {})
	if not completions is Dictionary:
		return tr("MAIN_DAILY_MARATHON_STATUS_OPEN")
	var entry: Variant = completions.get(route_id, {})
	if entry is Dictionary and float(entry.get("best_ratio", 0.0)) >= 0.999:
		return tr("MAIN_DAILY_MARATHON_STATUS_DONE")
	return tr("MAIN_DAILY_MARATHON_STATUS_OPEN")


func _build_ui() -> void:
	var accent := _PlayModeIds.accent_for(_PlayModeIds.MARATHON)
	var box := _SongSelectUiStyles.card_panel_style().duplicate() as StyleBoxFlat
	box.bg_color = Color(0.1, 0.09, 0.08, 0.96)
	box.border_color = Color(accent.r, accent.g, accent.b, 0.34)
	box.content_margin_left = 14.0
	box.content_margin_right = 14.0
	box.content_margin_top = 12.0
	box.content_margin_bottom = 12.0
	add_theme_stylebox_override("panel", box)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 15)
	_title_label.add_theme_color_override("font_color", accent)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_date_label = Label.new()
	_date_label.add_theme_font_size_override("font_size", 12)
	_date_label.add_theme_color_override("font_color", Color(0.68, 0.72, 0.82, 0.92))
	header.add_child(_date_label)

	_summary_label = Label.new()
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_label.add_theme_font_size_override("font_size", 13)
	_summary_label.add_theme_color_override("font_color", Color(0.84, 0.88, 0.96, 0.96))
	root.add_child(_summary_label)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.62, 0.82, 0.72, 0.95))
	root.add_child(_status_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	root.add_child(buttons)

	_play_button = Button.new()
	_play_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play_button.theme_type_variation = &"FlatButton"
	_SongSelectUiStyles.apply_play_button_style(_play_button, accent)
	_play_button.pressed.connect(func(): play_pressed.emit())
	buttons.add_child(_play_button)

	_details_button = Button.new()
	_details_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details_button.theme_type_variation = &"FlatButton"
	_details_button.pressed.connect(func(): details_pressed.emit())
	buttons.add_child(_details_button)
