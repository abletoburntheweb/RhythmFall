# scenes/marathon/marathon_route_preview_panel.gd
extends VBoxContainer
class_name MarathonRoutePreviewPanel

const _MarathonRouteCharacter = preload("res://logic/domain/session/marathon_route_character.gd")
const _MarathonRouteLength = preload("res://logic/domain/session/marathon_route_length.gd")
const _MarathonRunRules = preload("res://logic/domain/session/marathon_run_rules.gd")
const _SongSelectUiStyles = preload("res://scenes/song_select/lib/song_select_ui_styles.gd")
const _ChartDifficultyAnalyzer = preload("res://logic/domain/charts/chart_difficulty_analyzer.gd")
const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")

var _accent := Color(0.79, 0.57, 0.35, 1.0)
var _stars_row: HBoxContainer = null
var _tracks_label: Label = null
var _bpm_label: Label = null
var _idea_label: Label = null
var _tagline_label: Label = null


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	if _stars_row == null:
		_build_ui()


func setup(accent: Color) -> void:
	_accent = accent
	if _stars_row == null:
		_build_ui()


func apply_locale() -> void:
	pass


func refresh(template: Dictionary, preview: Dictionary, route_meta: Dictionary = {}) -> void:
	if _stars_row == null:
		_build_ui()
	var route_id := str(template.get("route_id", "")).strip_edges()
	visible = route_id != ""
	if not visible:
		return
	var count := _MarathonRouteCharacter.difficulty_star_count(template)
	var tint := _ChartDifficultyAnalyzer.rating_color(count)
	for child in _stars_row.get_children():
		child.queue_free()
	# ZAP pattern — count and tint from ChartDifficultyAnalyzer (1-2 green, 3-4 light, 5-6 purple, 7-8 yellow, 9-10 red) — bigger for summary
	for i in range(count):
		_stars_row.add_child(_UiIconHelper.make_icon_frame("zap.svg", 24, 14, tint))
	var built := int(preview.get("track_count", template.get("track_count", 0)))
	if bool(preview.get("ok", false)) and built > 0:
		_tracks_label.text = tr("MARATHON_PREVIEW_TRACKS_FMT") % built
	else:
		_tracks_label.text = _MarathonRouteLength.hint_line(template)
	var bpm := _MarathonRouteCharacter.avg_bpm_from_preview(preview)
	if bpm > 0:
		_bpm_label.text = tr("MARATHON_PREVIEW_BPM_FMT") % bpm
		_bpm_label.visible = true
	else:
		_bpm_label.visible = false
	var idea := _MarathonRouteCharacter.idea_label(template)
	if idea != "":
		_idea_label.text = idea
		_idea_label.visible = true
	else:
		_idea_label.visible = false
	var tagline := _MarathonRouteCharacter.tagline(template)
	if tagline != "":
		_tagline_label.text = "\"%s\"" % tagline
		_tagline_label.visible = true
	else:
		_tagline_label.visible = false


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)
	_stars_row = HBoxContainer.new()
	_stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_stars_row.add_theme_constant_override("separation", 3)
	root.add_child(_stars_row)
	_tagline_label = Label.new()
	_tagline_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tagline_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tagline_label.add_theme_font_size_override("font_size", 13)
	_tagline_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.92, 0.95))
	root.add_child(_tagline_label)
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 16)
	root.add_child(stats)
	_tracks_label = Label.new()
	_tracks_label.add_theme_font_size_override("font_size", 12)
	_tracks_label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.92, 1.0))
	stats.add_child(_tracks_label)
	_bpm_label = Label.new()
	_bpm_label.add_theme_font_size_override("font_size", 12)
	_bpm_label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.92, 1.0))
	stats.add_child(_bpm_label)
	_idea_label = Label.new()
	_idea_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_idea_label.add_theme_font_size_override("font_size", 11)
	_idea_label.add_theme_color_override("font_color", Color(_accent.r, _accent.g, _accent.b, 0.88))
	root.add_child(_idea_label)


func _panel_style() -> StyleBoxFlat:
	var box := _SongSelectUiStyles.card_panel_style().duplicate() as StyleBoxFlat
	box.bg_color = Color(0.07, 0.09, 0.13, 0.94)
	box.border_color = Color(_accent.r, _accent.g, _accent.b, 0.32)
	return box
