# scenes/marathon/marathon_route_progress_panel.gd
extends VBoxContainer
class_name MarathonRouteProgressPanel

const _MarathonRouteCharacter = preload("res://logic/domain/session/marathon_route_character.gd")
const _MarathonRouteBadges = preload("res://logic/domain/session/marathon_route_badges.gd")
const _SongSelectUiStyles = preload("res://scenes/song_select/lib/song_select_ui_styles.gd")
const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")

var _accent := Color(0.79, 0.57, 0.35, 1.0)
var _title_label: Label = null
var _best_label: Label = null
var _next_title: Label = null
var _next_body: Label = null


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	if _title_label == null:
		_build_ui()


func setup(accent: Color) -> void:
	_accent = accent
	if _title_label == null:
		_build_ui()
	if _title_label:
		_title_label.add_theme_color_override("font_color", _accent.lerp(Color.WHITE, 0.12))


func apply_locale() -> void:
	if _title_label:
		_title_label.text = tr("MARATHON_PROGRESS_TITLE")


func refresh(route_id: String, template: Dictionary) -> void:
	if _title_label == null:
		_build_ui()
	var snap := _MarathonRouteCharacter.progress_snapshot(route_id, template)
	visible = str(route_id).strip_edges() != ""
	if not visible:
		return
	if not bool(snap.get("attempted", false)):
		_best_label.text = tr("MARATHON_PROGRESS_NO_ATTEMPT")
		_next_title.text = tr("MARATHON_PROGRESS_FIRST_GOAL")
		var tiers := _MarathonRouteBadges.active_tiers_for_template(route_id, template)
		if tiers.is_empty():
			_next_body.text = tr("MARATHON_PROGRESS_COMPLETE_ROUTE_HINT")
		else:
			var first_tier: String = tiers[0]
			_next_body.text = "□ %s" % _MarathonRouteBadges.medal_description(route_id, first_tier, template)
		return
	var best_parts: PackedStringArray = []
	var tier := str(snap.get("best_badge_tier", "")).strip_edges()
	if tier != "":
		best_parts.append(_MarathonRouteBadges.medal_name(route_id, tier, template))
	var acc := float(snap.get("best_acc", 0.0))
	if acc > 0.0:
		best_parts.append("%.2f%%" % acc)
	var ratio := float(snap.get("best_ratio", 0.0))
	if ratio >= 0.999 and tier == "":
		best_parts.append(tr("MARATHON_PROGRESS_COMPLETED"))
	if best_parts.is_empty():
		_best_label.text = tr("MARATHON_PROGRESS_IN_PROGRESS") % int(round(ratio * 100.0))
	else:
		_best_label.text = tr("MARATHON_PROGRESS_BEST_FMT") % " · ".join(best_parts)
	if bool(snap.get("all_complete", false)):
		_next_title.text = tr("MARATHON_PROGRESS_ALL_MEDALS")
		_next_body.text = tr("MARATHON_PROGRESS_ALL_MEDALS_HINT")
		return
	var next_name := str(snap.get("next_medal_name", "")).strip_edges()
	var next_desc := str(snap.get("next_medal_desc", "")).strip_edges()
	if next_name != "":
		_next_title.text = tr("MARATHON_PROGRESS_NEXT_FMT") % next_name
	else:
		_next_title.text = tr("MARATHON_PROGRESS_NEXT_GOAL")
	_next_body.text = "□ %s" % next_desc if next_desc != "" else tr("MARATHON_PROGRESS_COMPLETE_ROUTE_HINT")
	var earned: Array = snap.get("earned_badges", [])
	if not earned.is_empty():
		var done_lines: PackedStringArray = []
		for earned_tier in earned:
			var t := str(earned_tier)
			done_lines.append("✓ %s" % _MarathonRouteBadges.medal_name(route_id, t, template))
		_next_body.text = "\n".join(done_lines) + "\n" + _next_body.text


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()
	_title_label = Label.new()
	_title_label.text = tr("MARATHON_PROGRESS_TITLE")
	_title_label.add_theme_font_size_override("font_size", 13)
	add_child(_title_label)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	_best_label = Label.new()
	_best_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_best_label.add_theme_font_size_override("font_size", 13)
	_best_label.add_theme_color_override("font_color", Color(0.9, 0.94, 0.98, 1.0))
	box.add_child(_best_label)
	_next_title = Label.new()
	_next_title.add_theme_font_size_override("font_size", 12)
	_next_title.add_theme_color_override("font_color", _accent.lerp(Color.WHITE, 0.2))
	box.add_child(_next_title)
	_next_body = Label.new()
	_next_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_next_body.add_theme_font_size_override("font_size", 12)
	_next_body.add_theme_color_override("font_color", Color(0.72, 0.78, 0.88, 0.96))
	box.add_child(_next_body)


func _panel_style() -> StyleBoxFlat:
	var box := _SongSelectUiStyles.card_panel_style().duplicate() as StyleBoxFlat
	box.bg_color = Color(0.07, 0.09, 0.13, 0.94)
	box.border_color = Color(_accent.r, _accent.g, _accent.b, 0.28)
	return box
