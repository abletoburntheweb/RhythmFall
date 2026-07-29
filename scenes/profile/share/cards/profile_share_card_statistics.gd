# scenes/profile/share/cards/profile_share_card_statistics.gd
extends ProfileShareCardBase

const _ChartCurveUtils = preload("res://logic/domain/charts/chart_curve_utils.gd")

@onready var _hero_value: Label = %HeroValue
@onready var _hero_caption: Label = %HeroCaption
@onready var _chip_hit: PanelContainer = %ChipHit
@onready var _chip_miss: PanelContainer = %ChipMiss
@onready var _chip_combo: PanelContainer = %ChipCombo
@onready var _chip_score: PanelContainer = %ChipScore
@onready var _chip_tracks: PanelContainer = %ChipTracks
@onready var _chip_medals: PanelContainer = %ChipMedals
@onready var _grade_ss: Label = %GradeSS
@onready var _grade_s: Label = %GradeS
@onready var _grade_a: Label = %GradeA
@onready var _grade_b: Label = %GradeB
@onready var _chart_line: Line2D = %ChartLine
@onready var _chart_fill: Polygon2D = %ChartFill
@onready var _chart_frame: Control = %ChartFrame


func _ready() -> void:
	card_id = "statistics"
	super._ready()


func _apply_card_content(data: Dictionary) -> void:
	var hits := int(data.get("notes_hit", 0))
	_set_label(_hero_value, _fmt_int(hits), 68, _accent())
	_set_label(_hero_caption, tr("PROFILE_STAT_NOTES_HIT"), 22, _MUTED)
	_apply_glass_panel(get_node_or_null("%HeroPanel") as PanelContainer, true)

	_apply_chip(_chip_hit, tr("PROFILE_STAT_NOTES_HIT"), _fmt_int(hits), _Wrapped.VALUE_COLORS["accuracy"], 32, 18)
	_apply_chip(_chip_miss, tr("PROFILE_STAT_NOTES_MISS"), _fmt_int(int(data.get("notes_miss", 0))), _Wrapped.VALUE_COLORS["miss"], 32, 18)
	_apply_chip(_chip_combo, tr("PROFILE_STAT_MAX_STREAK"), str(int(data.get("max_combo", 0))), _Wrapped.VALUE_COLORS["combo"], 32, 18)
	_apply_chip(_chip_score, tr("PROFILE_STAT_TOTAL_SCORE"), _fmt_int(int(data.get("total_score", 0))), _Wrapped.VALUE_COLORS["score"], 28, 18)
	_apply_chip(_chip_tracks, tr("PROFILE_STAT_UNIQUE_TRACKS"), str(int(data.get("unique_tracks", 0))), _TEXT, 32, 18)
	_apply_chip(_chip_medals, tr("PROFILE_STAT_MEDALS_TOTAL"), str(int(data.get("medals_total", 0))), _Wrapped.VALUE_COLORS["medal"], 32, 18)

	_set_grade(_grade_ss, "SS", int(data.get("ss", 0)))
	_set_grade(_grade_s, "S", int(data.get("s", 0)))
	_set_grade(_grade_a, "A", int(data.get("a", 0)))
	_set_grade(_grade_b, "B", int(data.get("b", 0)))
	_apply_glass_panel(get_node_or_null("%GradesPanel") as PanelContainer)

	if _chart_frame:
		_chart_frame.custom_minimum_size = Vector2(0, _fs(120))
	_apply_glass_panel(get_node_or_null("%ChartPanel") as PanelContainer)
	call_deferred("_deferred_update_chart", data.get("accuracy_points", []))


func _set_grade(label: Label, grade: String, count: int) -> void:
	if label == null:
		return
	var color := GradeDisplay.grade_color(grade)
	_set_label(label, "%s\n%d" % [grade, count], 26, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _deferred_update_chart(points: Variant) -> void:
	_update_chart(points)


func _update_chart(points: Variant) -> void:
	if _chart_frame == null or _chart_line == null:
		return
	var raw: Array = points if points is Array else []
	var frame_size := _chart_frame.size
	if frame_size.x < 4.0:
		frame_size = _chart_frame.custom_minimum_size
	if frame_size.x < 4.0:
		frame_size = Vector2(_fs(900), _fs(120))
	var anchors: PackedVector2Array = PackedVector2Array()
	if raw.is_empty():
		_chart_line.points = anchors
		if _chart_fill:
			_chart_fill.polygon = PackedVector2Array()
		return
	var count := raw.size()
	for i in range(count):
		var value := clampf(float(raw[i]), 0.0, 100.0)
		var x := 0.0 if count <= 1 else frame_size.x * float(i) / float(count - 1)
		var y := frame_size.y - (value / 100.0) * frame_size.y
		anchors.append(Vector2(x, y))
	_chart_line.width = maxf(2.0, _fs(4))
	_chart_line.default_color = Color(_accent().r, _accent().g, _accent().b, 0.95)
	_chart_line.points = anchors
	if _chart_fill:
		_chart_fill.color = Color(_accent().r, _accent().g, _accent().b, 0.22)
		_chart_fill.polygon = _ChartCurveUtils.fill_polygon_under_curve(anchors, frame_size.y, 0.0, frame_size.x)
