# scenes/profile/tabs/stats_tab.gd
extends VBoxContainer

const TimeUtils = preload("res://logic/platform/time_utils.gd")
const GradeDisplay = preload("res://logic/ui/grade_display.gd")
const ResultsHistoryService = preload("res://logic/data/results_history_service.gd")
const _ChartCurveUtils = preload("res://logic/domain/charts/chart_curve_utils.gd")
const _RhythmRating = preload("res://logic/domain/rhythm/rhythm_rating.gd")
const _CHART_POINT_SCENE := preload("res://scenes/profile/components/chart_point.tscn")
const _UiCategoryButton = preload("res://logic/ui/ui_category_button.gd")
const _ProfileInsights = preload("res://logic/domain/profile/profile_insights.gd")
const _ProfileStatTrends = preload("res://logic/domain/profile/profile_stat_trends.gd")
const _InstrumentStatsDialog = preload("res://scenes/profile/dialogs/instrument_stats_dialog.gd")

const _LEFT := "StatsBodyRow/StatsLeftStack"
const _RIGHT := "StatsBodyRow/StatsRightStack"
const _CHART := "ChartCard"
const _INSTRUMENT_STATS_BUTTON := "%s/GeneralStatsCard/ContentVBox/HeaderRow/InstrumentStatsButton" % _LEFT

const _TILE_VALUE_COLORS := {
	"notes_hit": Color(0.38039216, 0.78039217, 0.7411765),
	"notes_miss": Color(0.8980392, 0.4509804, 0.4509804),
	"max_streak": Color(0.9490196, 0.7019608, 0.3529412),
	"total_rr": Color(0.9490196, 0.7019608, 0.3529412),
	"medals_total": Color(0.92, 0.78, 0.42),
	"earned": Color(0.38039216, 0.78039217, 0.7411765),
	"spent": Color(0.8980392, 0.4509804, 0.4509804),
	"total_score": Color(0.78431374, 0.8235294, 0.9019608),
}

const _STAT_TILE_SPECS: Array = [
	["unique_tracks", "PROFILE_STAT_UNIQUE_TRACKS"],
	["total_score", "PROFILE_STAT_TOTAL_SCORE"],
	["notes_hit", "PROFILE_STAT_NOTES_HIT"],
	["notes_miss", "PROFILE_STAT_NOTES_MISS"],
	["max_streak", "PROFILE_STAT_MAX_STREAK"],
	["total_rr", "PROFILE_STAT_TOTAL_RR"],
	["medals_total", "PROFILE_STAT_MEDALS_TOTAL"],
	["daily_quests", "PROFILE_STAT_DAILY_QUESTS"],
	["member_since", "PROFILE_STAT_MEMBER_SINCE"],
	["earned", "PROFILE_STAT_EARNED"],
	["spent", "PROFILE_STAT_SPENT"],
]

const _GRADE_TILE_SPECS: Array = [
	["SS", "SS"],
	["S", "S"],
	["A", "A"],
	["B", "B"],
]

const STAT_VALUE_FONT_SIZE := 26
const STAT_CAPTION_FONT_SIZE := 12
const STAT_MEMBER_SINCE_FONT_SIZE := 17
const GRADE_VALUE_FONT_SIZE := 24
const GRADE_CAPTION_FONT_SIZE := 12
const CHART_SESSION_COUNT := 20
const CHART_Y_TICKS := [50.0, 75.0, 90.0, 100.0]
const CHART_METRIC_KEYS := ["accuracy", "score", "rr"]

const PROFILE_ACCENT := Color(0.38039216, 0.78039217, 0.7411765, 1.0)
const CHART_METRIC_SCORE_ACCENT := Color(0.78431374, 0.8235294, 0.9019608, 1.0)
const CHART_METRIC_RR_ACCENT := Color(0.9490196, 0.7019608, 0.3529412, 1.0)

const CHART_METRIC_BUTTON_ACCENTS := {
	"accuracy": PROFILE_ACCENT,
	"score": CHART_METRIC_SCORE_ACCENT,
	"rr": CHART_METRIC_RR_ACCENT,
}

const CHART_METRIC_PALETTES := {
	"accuracy": {
		"line": PROFILE_ACCENT,
		"fill": Color(PROFILE_ACCENT.r, PROFILE_ACCENT.g, PROFILE_ACCENT.b, 0.18),
		"ghost": Color(PROFILE_ACCENT.r, PROFILE_ACCENT.g, PROFILE_ACCENT.b, 0.35),
	},
	"score": {
		"line": CHART_METRIC_SCORE_ACCENT,
		"fill": Color(CHART_METRIC_SCORE_ACCENT.r, CHART_METRIC_SCORE_ACCENT.g, CHART_METRIC_SCORE_ACCENT.b, 0.18),
		"ghost": Color(CHART_METRIC_SCORE_ACCENT.r, CHART_METRIC_SCORE_ACCENT.g, CHART_METRIC_SCORE_ACCENT.b, 0.35),
	},
	"rr": {
		"line": CHART_METRIC_RR_ACCENT,
		"fill": Color(CHART_METRIC_RR_ACCENT.r, CHART_METRIC_RR_ACCENT.g, CHART_METRIC_RR_ACCENT.b, 0.18),
		"ghost": Color(CHART_METRIC_RR_ACCENT.r, CHART_METRIC_RR_ACCENT.g, CHART_METRIC_RR_ACCENT.b, 0.35),
	},
}

var screen: ProfileScreen = null

var _stat_tiles: Dictionary = {}
var _stat_caption_tiles: Dictionary = {}
var _stat_trend_tiles: Dictionary = {}
var _grade_tiles: Dictionary = {}
var _grade_trend_tiles: Dictionary = {}
var _profile_tiles_ready: bool = false
var _grades_styled: bool = false
var _chart_metric: String = "accuracy"
var _chart_metric_group: ButtonGroup = null
var _chart_refresh_token: int = 0
var _chart_resize_refresh_scheduled := false
var _insight_card: PanelContainer
var _insight_icon: TextureRect
var _insight_title: Label
var _insight_body: Label
var _insight_ready := false
var _cached_insight: Dictionary = {}
var _last_insight_title := ""

@onready var general_stats_title: Label = get_node_or_null("%s/GeneralStatsCard/ContentVBox/HeaderRow/CardTitle" % _LEFT) as Label
@onready var instrument_stats_button: Button = get_node_or_null(_INSTRUMENT_STATS_BUTTON) as Button
@onready var grades_card_title: Label = get_node_or_null("%s/GradesCard/MainVBox/CardTitle" % _RIGHT) as Label
@onready var chart_title_label: Label = get_node_or_null("%s/ChartContainer/ChartHeaderRow/ChartTitleLabel" % _CHART) as Label
@onready var chart_avg_label: Label = get_node_or_null("%s/ChartContainer/ChartHeaderRow/ChartAvgLabel" % _CHART) as Label
@onready var chart_metric_accuracy: Button = get_node_or_null("%s/ChartContainer/ChartMetricRow/ChartMetricAccuracy" % _CHART) as Button
@onready var chart_metric_score: Button = get_node_or_null("%s/ChartContainer/ChartMetricRow/ChartMetricScore" % _CHART) as Button
@onready var chart_metric_rr: Button = get_node_or_null("%s/ChartContainer/ChartMetricRow/ChartMetricRR" % _CHART) as Button
@onready var chart_x_axis_label: Label = get_node_or_null("%s/ChartContainer/ChartXAxisLabel" % _CHART) as Label
@onready var chart_plot_frame: Control = get_node_or_null("%s/ChartContainer/ChartPlotFrame" % _CHART) as Control
@onready var chart_decor: Control = get_node_or_null("%s/ChartContainer/ChartPlotFrame/ChartDecor" % _CHART) as Control
@onready var chart_fill: Polygon2D = get_node_or_null("%s/ChartContainer/ChartPlotFrame/ChartFill" % _CHART) as Polygon2D
@onready var chart_smooth_line: Line2D = get_node_or_null("%s/ChartContainer/ChartPlotFrame/ChartSmoothLine" % _CHART) as Line2D
@onready var accuracy_chart_line: Line2D = get_node_or_null("%s/ChartContainer/ChartPlotFrame/AccuracyChartLine" % _CHART) as Line2D
@onready var accuracy_chart_points: Control = get_node_or_null("%s/ChartContainer/ChartPlotFrame/AccuracyChartPoints" % _CHART) as Control
@onready var chart_background: ColorRect = get_node_or_null("%s/ChartContainer/ChartPlotFrame/ChartBackground" % _CHART) as ColorRect


func bind(host: ProfileScreen) -> void:
	screen = host


func setup() -> void:
	_setup_insight_card()
	_setup_profile_tiles()
	_setup_instrument_stats_button()
	_setup_grade_tiles()
	_setup_chart_metrics()
	if chart_plot_frame:
		chart_plot_frame.clip_contents = true


func apply_locale() -> void:
	if general_stats_title:
		general_stats_title.text = tr("PROFILE_GENERAL_STATS")
	if instrument_stats_button:
		instrument_stats_button.text = tr("PROFILE_STAT_INSTR_OPEN_BUTTON")
		UiIconHelper.apply_icon_from_meta(instrument_stats_button, 16)
	if grades_card_title:
		grades_card_title.text = tr("PROFILE_GRADES")
	_apply_chart_title()
	if chart_metric_accuracy:
		chart_metric_accuracy.text = tr("PROFILE_CHART_METRIC_ACCURACY")
	if chart_metric_score:
		chart_metric_score.text = tr("PROFILE_CHART_METRIC_SCORE")
	if chart_metric_rr:
		chart_metric_rr.text = tr("PROFILE_CHART_METRIC_RR")
	if chart_x_axis_label:
		chart_x_axis_label.text = tr("PROFILE_CHART_X_AXIS")
	_apply_stat_caption_labels()
	_cached_insight.clear()
	_refresh_insight_card(false)


func refresh_fast() -> void:
	_refresh_insight_card(false)
	var total_notes_hit = PlayerDataManager.get_total_notes_hit()
	var total_notes_missed = PlayerDataManager.get_total_notes_missed()
	var max_streak = PlayerDataManager.data.get("max_combo_ever", 0)
	var total_score = PlayerDataManager.data.get("total_score_ever", 0)

	_set_stat_tile("unique_tracks", str(PlayerDataManager.get_unique_levels_completed()))
	_set_stat_tile("total_score", str(total_score))
	_set_stat_tile("notes_hit", str(total_notes_hit))
	_set_stat_tile("notes_miss", str(total_notes_missed))
	_set_stat_tile("max_streak", str(max_streak))
	_set_stat_tile("total_rr", str(screen.get_total_rr_earned() if screen else 0))
	_set_stat_tile("medals_total", str(int(_get_global_medal_stats().get("total_medal_count", 0))))
	_set_stat_tile("daily_quests", str(PlayerDataManager.get_daily_quests_completed_total()))
	_set_stat_tile("member_since", TimeUtils.format_iso_date_localized(str(PlayerDataManager.data.get("profile_created_date", ""))))
	_set_stat_tile("earned", str(PlayerDataManager.data.get("total_earned_currency", 0)))
	_set_stat_tile("spent", str(PlayerDataManager.data.get("spent_currency", 0)))
	_apply_stat_trends()

	var grades = PlayerDataManager.data.get("grades", {})
	_set_grade_tile("SS", int(grades.get("SS", 0)))
	_set_grade_tile("S", int(grades.get("S", 0)))
	_set_grade_tile("A", int(grades.get("A", 0)))
	_set_grade_tile("B", int(grades.get("B", 0)))


func on_daily_quests_updated() -> void:
	_set_stat_tile("daily_quests", str(PlayerDataManager.get_daily_quests_completed_total()))
	_refresh_insight_card(false)


func on_tab_shown() -> void:
	_refresh_insight_card(true)


func request_chart_update() -> void:
	if not visible:
		return
	_chart_refresh_token += 1
	var token := _chart_refresh_token
	call_deferred("_run_session_chart_update", token)


func update_session_chart() -> void:
	_update_session_chart()


func get_chart_card() -> Control:
	return get_node_or_null(_CHART) as Control


func get_chart_metric_button(metric_key: String) -> Button:
	match metric_key:
		"accuracy":
			return chart_metric_accuracy
		"score":
			return chart_metric_score
		"rr":
			return chart_metric_rr
		_:
			return null


func hotkey_select_chart_metric(index: int) -> void:
	if index < 0 or index >= CHART_METRIC_KEYS.size():
		return
	var metric_key := String(CHART_METRIC_KEYS[index])
	var button := get_chart_metric_button(metric_key)
	if button == null:
		return
	button.button_pressed = true
	_on_chart_metric_pressed()


func _apply_stat_caption_labels() -> void:
	for spec in _STAT_TILE_SPECS:
		var tile_key := String(spec[0])
		var locale_key := String(spec[1])
		if _stat_caption_tiles.has(tile_key):
			(_stat_caption_tiles[tile_key] as Label).text = tr(locale_key)


func _setup_instrument_stats_button() -> void:
	if instrument_stats_button == null:
		return
	instrument_stats_button.set_meta("ui_icon_file", "layers.svg")
	instrument_stats_button.set_meta("ui_accent_color", PROFILE_ACCENT)
	instrument_stats_button.focus_mode = Control.FOCUS_NONE
	if not instrument_stats_button.pressed.is_connected(_on_instrument_stats_pressed):
		instrument_stats_button.pressed.connect(_on_instrument_stats_pressed)


func _on_instrument_stats_pressed() -> void:
	UiScreenHotkeys.play_section_switch_sound()
	var dialog := _get_instrument_stats_dialog()
	if dialog == null:
		return
	var history: Array = []
	if screen and screen.results_history_service and screen.results_history_service.has_method("get_history"):
		history = screen.results_history_service.get_history()
	dialog.open(history)


func _get_instrument_stats_dialog() -> _InstrumentStatsDialog:
	if screen == null:
		return null
	return screen.get_node_or_null("InstrumentStatsDialog") as _InstrumentStatsDialog


func _setup_insight_card() -> void:
	if _insight_ready:
		return
	_insight_ready = true
	var body_row := get_node_or_null("StatsBodyRow") as Control
	if body_row == null:
		return

	_insight_card = PanelContainer.new()
	_insight_card.name = "StatsInsightCard"
	_insight_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_insight_card)
	move_child(_insight_card, body_row.get_index())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_insight_card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	_insight_icon = TextureRect.new()
	_insight_icon.custom_minimum_size = Vector2(24, 24)
	_insight_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_insight_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_insight_icon)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 2)
	row.add_child(text_col)

	_insight_title = Label.new()
	_insight_title.add_theme_font_size_override("font_size", 15)
	_insight_title.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0, 1.0))
	text_col.add_child(_insight_title)

	_insight_body = Label.new()
	_insight_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_insight_body.add_theme_font_size_override("font_size", 13)
	_insight_body.add_theme_color_override("font_color", Color(0.72, 0.78, 0.88, 1.0))
	text_col.add_child(_insight_body)


func _refresh_insight_card(rotate: bool) -> void:
	if _insight_card == null:
		return
	var history: Array = []
	if screen and screen.results_history_service and screen.results_history_service.has_method("get_history"):
		history = screen.results_history_service.get_history()
	if rotate or _cached_insight.is_empty():
		_cached_insight = _ProfileInsights.pick_random_insight(history, _last_insight_title if rotate else "")
		_last_insight_title = str(_cached_insight.get("title", ""))
	var insight: Dictionary = _cached_insight
	var accent: Color = PROFILE_ACCENT
	var icon_file := str(insight.get("icon", "sparkles.svg"))
	_insight_icon.texture = UiIconHelper.load_tinted_icon(icon_file, accent.lightened(0.08), 24)
	_insight_title.text = str(insight.get("title", ""))
	_insight_body.text = str(insight.get("body", ""))
	var box := StyleBoxFlat.new()
	box.bg_color = Color(accent.r, accent.g, accent.b, 0.1)
	box.border_color = accent.lerp(Color.WHITE, 0.12)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	_insight_card.add_theme_stylebox_override("panel", box)


func _setup_profile_tiles() -> void:
	if _profile_tiles_ready:
		return
	_profile_tiles_ready = true

	var grid := get_node_or_null("%s/GeneralStatsCard/ContentVBox/StatsGrid" % _LEFT) as GridContainer
	if grid == null:
		printerr("StatsTab: StatsGrid not found in profile_screen.tscn")
		return
	_bind_stat_tiles_from_grid(grid)


func _bind_stat_tiles_from_grid(grid: GridContainer) -> void:
	for spec in _STAT_TILE_SPECS:
		var tile_key := str(spec[0])
		var tile := grid.get_node_or_null("%sTile" % tile_key) as PanelContainer
		if tile == null:
			continue
		var value_label := tile.get_node_or_null("VBox/ValueLabel") as Label
		var caption_label := tile.get_node_or_null("VBox/CaptionLabel") as Label
		if value_label:
			var value_font_size := STAT_MEMBER_SINCE_FONT_SIZE if tile_key == "member_since" else STAT_VALUE_FONT_SIZE
			value_label.add_theme_font_size_override("font_size", value_font_size)
			var value_color: Color = _TILE_VALUE_COLORS.get(tile_key, Color(0.95, 0.95, 0.97))
			value_label.add_theme_color_override("font_color", value_color)
			_stat_tiles[tile_key] = value_label
		if caption_label:
			_stat_caption_tiles[tile_key] = caption_label
		var tile_vbox := tile.get_node_or_null("VBox") as VBoxContainer
		if tile_vbox and tile_vbox.get_node_or_null("TrendLabel") == null:
			var trend_label := Label.new()
			trend_label.name = "TrendLabel"
			trend_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			trend_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			trend_label.add_theme_font_size_override("font_size", 11)
			trend_label.visible = false
			tile_vbox.add_child(trend_label)
			_stat_trend_tiles[tile_key] = trend_label


func _setup_grade_tiles() -> void:
	if _grades_styled:
		return
	_grades_styled = true

	var grades_hbox := get_node_or_null("%s/GradesCard/MainVBox/ContentHBox" % _RIGHT) as HBoxContainer
	if grades_hbox == null:
		printerr("StatsTab: grade tiles row not found in profile_screen.tscn")
		return
	if not _bind_grade_tiles_from_hbox(grades_hbox):
		printerr("StatsTab: incomplete grade tiles in profile_screen.tscn")


func _bind_grade_tiles_from_hbox(grades_hbox: HBoxContainer) -> bool:
	var bound := 0
	for spec in _GRADE_TILE_SPECS:
		var tile_key := str(spec[0])
		var tile := grades_hbox.get_node_or_null("%sGradeTile" % tile_key) as PanelContainer
		if tile == null:
			continue
		var grade_color: Color = GradeDisplay.grade_color(tile_key)
		if tile.has_method("apply_grade"):
			tile.apply_grade(tile_key, "0", grade_color, GRADE_VALUE_FONT_SIZE)
		var caption_label := tile.get_node_or_null("VBox/CaptionLabel") as Label
		if caption_label:
			caption_label.add_theme_font_size_override("font_size", GRADE_CAPTION_FONT_SIZE)
			caption_label.add_theme_color_override("font_color", grade_color)
		var value_label := tile.get_node_or_null("VBox/ValueLabel") as Label
		if value_label:
			_grade_tiles[tile_key] = value_label
			bound += 1
		var tile_vbox := tile.get_node_or_null("VBox") as VBoxContainer
		if tile_vbox and tile_vbox.get_node_or_null("TrendLabel") == null:
			var trend_label := Label.new()
			trend_label.name = "TrendLabel"
			trend_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			trend_label.add_theme_font_size_override("font_size", 11)
			trend_label.visible = false
			tile_vbox.add_child(trend_label)
			_grade_trend_tiles[tile_key] = trend_label
	return bound >= _GRADE_TILE_SPECS.size()


func _set_grade_tile(key: String, value: int) -> void:
	if _grade_tiles.has(key):
		(_grade_tiles[key] as Label).text = str(value)


func _set_stat_tile(key: String, value: String) -> void:
	if _stat_tiles.has(key):
		(_stat_tiles[key] as Label).text = value


func _apply_stat_trends() -> void:
	var history: Array = []
	if screen and screen.results_history_service and screen.results_history_service.has_method("get_history"):
		history = screen.results_history_service.get_history()
	var trends: Dictionary = _ProfileStatTrends.compute_tile_trends(history)
	for tile_key in _STAT_TILE_SPECS:
		var key := str(tile_key[0])
		_set_tile_trend(_stat_trend_tiles, key, trends.get(key, {}))
	for spec in _GRADE_TILE_SPECS:
		var grade_key := str(spec[0])
		_set_tile_trend(_grade_trend_tiles, grade_key, trends.get("grade_%s" % grade_key, {}))


func _set_tile_trend(store: Dictionary, key: String, trend: Dictionary) -> void:
	if not store.has(key):
		return
	var label: Label = store[key] as Label
	if label == null:
		return
	var text := _ProfileStatTrends.format_trend_line(trend)
	label.text = text
	label.visible = text != ""
	if label.visible:
		label.add_theme_color_override("font_color", _ProfileStatTrends.trend_color(trend))


func _get_global_medal_stats() -> Dictionary:
	if screen and screen.results_history_service and screen.results_history_service.has_method("get_global_medal_stats"):
		return screen.results_history_service.get_global_medal_stats()
	return ResultsHistoryService.new().get_global_medal_stats()


func _setup_chart_metrics() -> void:
	_chart_metric_group = ButtonGroup.new()
	for metric_key in CHART_METRIC_KEYS:
		var button := get_chart_metric_button(metric_key)
		if button == null:
			continue
		button.button_group = _chart_metric_group
		var accent: Color = CHART_METRIC_BUTTON_ACCENTS.get(metric_key, PROFILE_ACCENT)
		button.set_meta("ui_accent_color", accent)
		button.set_meta("ui_variation_inactive", &"CategoryKick")
		button.set_meta("ui_variation_active", &"ActiveKick")
		if not button.pressed.is_connected(_on_chart_metric_pressed):
			button.pressed.connect(_on_chart_metric_pressed)
		if not button.mouse_entered.is_connected(_on_chart_metric_mouse_entered):
			button.mouse_entered.connect(_on_chart_metric_mouse_entered.bind(button))
	_sync_chart_metric_from_buttons()
	_apply_chart_metric_theme(_chart_metric)
	_refresh_chart_metric_buttons()


func _on_chart_metric_mouse_entered(hovered: Button) -> void:
	for button in [chart_metric_accuracy, chart_metric_score, chart_metric_rr]:
		if button == null or button == hovered:
			continue
		_UiCategoryButton.reset_hover_visual(button)


func _reapply_chart_metric_styles() -> void:
	_apply_chart_metric_buttons(_chart_metric)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible():
		_reapply_chart_metric_styles()


func _refresh_chart_metric_buttons() -> void:
	_apply_chart_metric_buttons(_chart_metric)


func _apply_chart_metric_buttons(selected: String) -> void:
	for metric_key in CHART_METRIC_KEYS:
		var button := get_chart_metric_button(metric_key)
		if button:
			var active: bool = selected == metric_key
			button.set_block_signals(true)
			button.button_pressed = active
			button.set_block_signals(false)
			_style_chart_metric_button(button, metric_key, active)
	if screen and screen.get_tree():
		screen.get_tree().create_timer(0.05).timeout.connect(
			func() -> void: _apply_chart_metric_buttons_immediate(selected),
			CONNECT_ONE_SHOT
		)


func _apply_chart_metric_buttons_immediate(selected: String) -> void:
	for metric_key in CHART_METRIC_KEYS:
		var button := get_chart_metric_button(metric_key)
		if button:
			_style_chart_metric_button(button, metric_key, selected == metric_key)


func _style_chart_metric_button(button: Button, metric_key: String, active: bool) -> void:
	# Idle: per-metric text color, dim icon. Active: accent on icon + text + outline.
	_UiCategoryButton.apply_selection(button, active, 16, true, false)
	var accent: Color = CHART_METRIC_BUTTON_ACCENTS.get(metric_key, PROFILE_ACCENT)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, accent)
	button.modulate = Color.WHITE


func _on_chart_metric_pressed() -> void:
	UiScreenHotkeys.play_section_switch_sound()
	_sync_chart_metric_from_buttons()
	_apply_chart_title()
	request_chart_update()


func _apply_chart_metric_theme(metric: String) -> void:
	var palette: Dictionary = CHART_METRIC_PALETTES.get(metric, CHART_METRIC_PALETTES["accuracy"])
	var line_color: Color = palette.get("line", Color.WHITE)
	var fill_color: Color = palette.get("fill", Color.WHITE)
	var ghost_color: Color = palette.get("ghost", Color.WHITE)
	if chart_smooth_line:
		chart_smooth_line.default_color = line_color
	if accuracy_chart_line:
		accuracy_chart_line.default_color = ghost_color
	if chart_fill:
		chart_fill.color = fill_color
	if chart_avg_label:
		chart_avg_label.add_theme_color_override("font_color", line_color.lightened(0.08))


func _run_session_chart_update(token: int) -> void:
	if token != _chart_refresh_token:
		return
	if not _chart_can_draw():
		return
	if screen:
		await screen.with_profile_loading(_update_session_chart)


func _sync_chart_metric_from_buttons() -> void:
	for metric_key in CHART_METRIC_KEYS:
		var button := get_chart_metric_button(metric_key)
		if button and button.button_pressed:
			if _chart_metric == metric_key:
				_refresh_chart_metric_buttons()
				return
			_chart_metric = metric_key
			_apply_chart_metric_theme(_chart_metric)
			_refresh_chart_metric_buttons()
			return


func _apply_chart_title() -> void:
	if chart_title_label == null:
		return
	match _chart_metric:
		"score":
			chart_title_label.text = tr("PROFILE_CHART_TITLE_SCORE")
		"rr":
			chart_title_label.text = tr("PROFILE_CHART_TITLE_RR")
		_:
			chart_title_label.text = tr("PROFILE_CHART_TITLE")


func _chart_can_draw() -> bool:
	if chart_plot_frame == null:
		return false
	if not visible:
		return false
	return chart_plot_frame.size.x > 0 and chart_plot_frame.size.y > 0


func _clear_session_chart() -> void:
	if chart_smooth_line:
		chart_smooth_line.points = PackedVector2Array()
	if accuracy_chart_line:
		accuracy_chart_line.points = PackedVector2Array()
	if chart_fill:
		chart_fill.polygon = PackedVector2Array()
	if accuracy_chart_points:
		for child in accuracy_chart_points.get_children():
			child.queue_free()
	if chart_avg_label:
		chart_avg_label.text = tr("PROFILE_CHART_AVG_EMPTY")


func _get_chart_relevant_history() -> Array[Dictionary]:
	if screen == null or screen.results_history_service == null:
		return []
	var history: Array[Dictionary] = screen.results_history_service.get_history()
	if history.is_empty():
		return []
	var start_index := maxi(0, history.size() - CHART_SESSION_COUNT)
	return history.slice(start_index, history.size())


func _session_has_data(index: int, relevant_count: int) -> bool:
	return index < relevant_count


func _session_metric_value(session: Dictionary, metric: String) -> float:
	match metric:
		"accuracy":
			return float(session.get("accuracy", 0.0))
		"score":
			return float(session.get("score", 0))
		"rr":
			return float(_session_run_rr(session))
		_:
			return 0.0


func _session_run_rr(session: Dictionary) -> int:
	if session.has("run_rr"):
		return int(session.get("run_rr", 0))
	return _RhythmRating.compute(
		float(session.get("accuracy", 0.0)),
		0,
		str(session.get("grade", "")),
		false,
		[]
	)


func _chart_scale_max(sessions: Array, metric: String) -> float:
	if metric == "accuracy":
		return 100.0
	var max_value := 1.0
	for session in sessions:
		if session is Dictionary:
			max_value = maxf(max_value, _session_metric_value(session, metric))
	return max_value


func _chart_metric_to_plot_value(raw_value: float, metric: String, scale_max: float) -> float:
	if metric == "accuracy":
		return raw_value
	if scale_max <= 0.0:
		return 0.0
	return clampf(raw_value / scale_max * 100.0, 0.0, 100.0)


func _chart_plot_value_to_y(plot_value: float, decor: Control) -> float:
	if decor and decor.has_method("value_to_y"):
		return float(decor.call("value_to_y", plot_value))
	return 0.0


func _chart_index_to_x(index: int, decor: Control) -> float:
	if decor and decor.has_method("session_index_to_x"):
		return float(decor.call("session_index_to_x", index, CHART_SESSION_COUNT))
	return 0.0


func _build_chart_tick_labels(scale_max: float, metric: String) -> Dictionary:
	var tick_values := PackedFloat32Array()
	var tick_labels := PackedStringArray()
	for tick in CHART_Y_TICKS:
		tick_values.append(tick)
		if metric == "accuracy":
			tick_labels.append("%d%%" % int(tick))
		else:
			var raw: float = scale_max * tick / 100.0
			if metric == "score":
				tick_labels.append(_format_chart_score(raw))
			else:
				tick_labels.append(str(int(round(raw))))
	return {
		"values": tick_values,
		"labels": tick_labels,
	}


func _format_chart_score(value: float) -> String:
	if value >= 1000000.0:
		return "%.1fM" % (value / 1000000.0)
	if value >= 1000.0:
		return "%.1fk" % (value / 1000.0)
	return str(int(round(value)))


func _format_chart_metric_value(metric: String, value: float) -> String:
	match metric:
		"accuracy":
			return "%.1f%%" % value
		"score":
			return _format_chart_score(value)
		"rr":
			return str(int(round(value)))
		_:
			return str(value)


func _format_chart_avg_label(metric: String, avg_value: float) -> String:
	return tr("PROFILE_CHART_AVG_FMT") % _format_chart_metric_value(metric, avg_value)


func _build_session_chart_tooltip(session: Dictionary) -> String:
	var na := tr("VALUE_NA")
	var artist := str(session.get("artist", tr("VALUE_UNKNOWN_ARTIST")))
	var title := str(session.get("title", na))
	var date_text := TimeUtils.format_session_datetime_localized(str(session.get("date", "")))
	if date_text == "":
		date_text = na
	var grade := str(session.get("grade", na))
	var instrument := _localize_session_instrument(str(session.get("instrument", na)))
	var accuracy := float(session.get("accuracy", 0.0))
	var score := int(session.get("score", 0))
	var rr := _session_run_rr(session)
	var line1 := tr("PROFILE_CHART_TOOLTIP_TRACK") % [artist, title]
	var line2 := tr("PROFILE_CHART_TOOLTIP_META") % [date_text, grade, instrument]
	var line3 := "%s  ·  %s  ·  %s" % [
		tr("PROFILE_CHART_TOOLTIP_ACCURACY") % ("%.1f" % accuracy),
		tr("PROFILE_CHART_TOOLTIP_SCORE") % _format_chart_score(float(score)),
		tr("PROFILE_CHART_TOOLTIP_RR") % str(rr),
	]
	return "%s\n%s\n%s" % [line1, line2, line3]


func _localize_session_instrument(instrument: String) -> String:
	var key := instrument.strip_edges().to_lower()
	match key:
		"drums", "перкуссия", "percussion":
			return tr("GEN_INST_DRUMS")
		"fullmix", "микс", "mix", "общий микс":
			return tr("GEN_INST_FULLMIX")
		"standard", "стандарт":
			return tr("GEN_INST_STANDARD")
		_:
			if instrument == "" or instrument == "N/A":
				return tr("VALUE_NA")
			return instrument


func _create_chart_point() -> Control:
	return _CHART_POINT_SCENE.instantiate() as Control


func _update_session_chart() -> void:
	if not _chart_can_draw():
		return
	if accuracy_chart_points == null or chart_plot_frame == null:
		return

	_clear_session_chart()

	if screen == null or screen.results_history_service == null:
		printerr("StatsTab: ResultsHistoryService не установлен!")
		return

	var relevant_history := _get_chart_relevant_history()
	if relevant_history.is_empty():
		return

	var scale_max := _chart_scale_max(relevant_history, _chart_metric)
	var tick_data := _build_chart_tick_labels(scale_max, _chart_metric)
	if chart_decor and chart_decor.has_method("configure"):
		chart_decor.call(
			"configure",
			_chart_metric,
			0.0,
			100.0,
			tick_data["values"],
			tick_data["labels"]
		)

	var metric_sum := 0.0
	var metric_count := 0
	var anchor_points := PackedVector2Array()
	var plot_left := 0.0
	var plot_right := 0.0
	var baseline_y := 0.0
	if chart_decor:
		var plot_rect: Rect2 = chart_decor.get_plot_rect() if chart_decor.has_method("get_plot_rect") else Rect2()
		plot_left = plot_rect.position.x
		plot_right = plot_rect.position.x + plot_rect.size.x
		baseline_y = plot_rect.position.y + plot_rect.size.y

	for i in range(CHART_SESSION_COUNT):
		if not _session_has_data(i, relevant_history.size()):
			continue
		var session: Dictionary = relevant_history[i]
		var raw_value := _session_metric_value(session, _chart_metric)
		metric_sum += raw_value
		metric_count += 1
		var plot_value := _chart_metric_to_plot_value(raw_value, _chart_metric, scale_max)
		var x := _chart_index_to_x(i, chart_decor)
		var y := _chart_plot_value_to_y(plot_value, chart_decor)
		y = _clamp_chart_point_y(y, chart_decor)
		anchor_points.append(Vector2(x, y))

		var color := GradeDisplay.color_from_saved_result(session)
		var point_control: Control = _create_chart_point()
		point_control.point_color = color
		point_control.point_radius = 6.0
		point_control.border_width = 1.5
		point_control.border_color = Color(0.05, 0.05, 0.08, 0.85)
		var grade := str(session.get("grade", ""))
		if grade != "" and grade != "N/A":
			point_control.set_grade_label(grade)
		point_control.set_point_tooltip(_build_session_chart_tooltip(session))
		point_control.name = "Point%d" % i
		accuracy_chart_points.add_child(point_control)
		var point_center := Vector2(x, y)
		point_control.position = point_center - point_control.get_point_center()

	if metric_count > 0 and chart_avg_label:
		chart_avg_label.text = _format_chart_avg_label(_chart_metric, metric_sum / float(metric_count))
	elif chart_avg_label:
		chart_avg_label.text = tr("PROFILE_CHART_AVG_EMPTY")

	if anchor_points.size() == 0:
		return

	var smooth_points := _clamp_curve_to_plot(_ChartCurveUtils.catmull_rom(anchor_points, 6), chart_decor)
	if chart_smooth_line:
		chart_smooth_line.points = smooth_points
	if accuracy_chart_line:
		accuracy_chart_line.points = anchor_points
	if chart_fill and smooth_points.size() > 0:
		chart_fill.polygon = _ChartCurveUtils.fill_polygon_under_curve(
			smooth_points,
			baseline_y,
			plot_left,
			plot_right
		)


func _chart_plot_bounds(decor: Control) -> Rect2:
	if decor and decor.has_method("get_plot_rect"):
		return decor.call("get_plot_rect") as Rect2
	return Rect2()


func _clamp_chart_point_y(y: float, decor: Control) -> float:
	var plot := _chart_plot_bounds(decor)
	if plot.size.y <= 0.0:
		return y
	var top_pad := 10.0
	# Keep dots above grade captions so labels aren't clipped by plot frame.
	var bottom_pad := 16.0
	return clampf(y, plot.position.y + top_pad, plot.position.y + plot.size.y - bottom_pad)


func _clamp_curve_to_plot(points: PackedVector2Array, decor: Control) -> PackedVector2Array:
	var plot := _chart_plot_bounds(decor)
	if plot.size.y <= 0.0 or points.is_empty():
		return points
	var top_y := plot.position.y + 2.0
	var bottom_y := plot.position.y + plot.size.y - 2.0
	var left_x := plot.position.x
	var right_x := plot.position.x + plot.size.x
	var out := PackedVector2Array()
	for point in points:
		out.append(Vector2(clampf(point.x, left_x, right_x), clampf(point.y, top_y, bottom_y)))
	return out


func _on_chart_background_resized() -> void:
	if _chart_resize_refresh_scheduled:
		return
	_chart_resize_refresh_scheduled = true
	call_deferred("_deferred_chart_resize_refresh")


func _deferred_chart_resize_refresh() -> void:
	_chart_resize_refresh_scheduled = false
	request_chart_update()
