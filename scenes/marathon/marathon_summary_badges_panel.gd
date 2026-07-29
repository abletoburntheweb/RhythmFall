# scenes/marathon/marathon_summary_badges_panel.gd
extends VBoxContainer
class_name MarathonSummaryBadgesPanel

const _MarathonRouteBadges = preload("res://logic/domain/session/marathon_route_badges.gd")
const _SongSelectUiStyles = preload("res://scenes/song_select/lib/song_select_ui_styles.gd")
const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")

var _accent := Color(0.79, 0.57, 0.35, 1.0)
var _title_label: Label = null
var _cards_flow: FlowContainer = null
var _route_id := ""
var _template: Dictionary = {}


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	if _title_label == null:
		_build_ui()


func setup(accent: Color) -> void:
	_accent = accent
	if _title_label == null:
		_build_ui()
	_style_header()


func apply_locale() -> void:
	if _title_label:
		_title_label.text = tr("MARATHON_SUMMARY_BADGES_TITLE")
	if _route_id != "":
		refresh(_route_id, _template, _last_earned_badges())


var _earned_cache: Array = []


func _last_earned_badges() -> Array:
	return _earned_cache


func refresh(route_id: String, template: Dictionary, earned_badges: Array) -> void:
	if _title_label == null:
		_build_ui()
	_route_id = str(route_id).strip_edges()
	_template = template if template is Dictionary else {}
	_earned_cache = earned_badges if earned_badges is Array else []
	visible = _route_id != ""
	if not visible:
		return
	var tiers := _MarathonRouteBadges.active_tiers_for_template(_route_id, _template)
	var earned_set: Dictionary = {}
	for tier in _earned_cache:
		earned_set[str(tier)] = true
	for child in _cards_flow.get_children():
		child.queue_free()
	for tier in tiers:
		var medal: Dictionary = _MarathonRouteBadges.medal_def(_route_id, tier, _template)
		var condition := str(medal.get("condition", "")).strip_edges()
		if condition == "":
			continue
		_cards_flow.add_child(_make_medal_card(_route_id, tier, earned_set.has(tier)))


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	_title_label = Label.new()
	_title_label.text = tr("MARATHON_SUMMARY_BADGES_TITLE")
	_title_label.add_theme_font_size_override("font_size", 13)
	add_child(_title_label)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _card_panel_style())
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	_cards_flow = FlowContainer.new()
	_cards_flow.add_theme_constant_override("h_separation", 8)
	_cards_flow.add_theme_constant_override("v_separation", 8)
	margin.add_child(_cards_flow)


func _make_medal_card(route_id: String, tier: String, earned: bool) -> PanelContainer:
	var tier_color := _MarathonRouteBadges.tier_accent(tier)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(132, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.tooltip_text = _MarathonRouteBadges.medal_tooltip(route_id, tier, _template)
	panel.add_theme_stylebox_override("panel", _medal_card_style(tier, earned))

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(header)

	header.add_child(
		_UiIconHelper.make_icon_frame(
			_MarathonRouteBadges.tier_icon_file(tier),
			26,
			14,
			tier_color if earned else tier_color.darkened(0.22)
		)
	)

	var name_label := Label.new()
	name_label.text = _MarathonRouteBadges.medal_name(route_id, tier, _template)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override(
		"font_color",
		Color(0.92, 0.94, 0.98, 1.0) if earned else Color(0.68, 0.72, 0.82, 0.92)
	)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(name_label)

	var status_label := Label.new()
	status_label.text = tr("MARATHON_SUMMARY_BADGE_EARNED") if earned else tr("MARATHON_SUMMARY_BADGE_LOCKED")
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.add_theme_color_override(
		"font_color",
		tier_color.lightened(0.06) if earned else Color(0.52, 0.58, 0.68, 0.88)
	)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(status_label)

	return panel


func _card_panel_style() -> StyleBoxFlat:
	var box := _SongSelectUiStyles.card_panel_style().duplicate() as StyleBoxFlat
	box.bg_color = Color(0.07, 0.09, 0.13, 0.94)
	box.border_color = Color(_accent.r, _accent.g, _accent.b, 0.28)
	box.content_margin_left = 0.0
	box.content_margin_right = 0.0
	box.content_margin_top = 0.0
	box.content_margin_bottom = 0.0
	return box


func _medal_card_style(tier: String, earned: bool) -> StyleBoxFlat:
	var tier_color := _MarathonRouteBadges.tier_accent(tier)
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(10)
	box.set_border_width_all(1)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	if earned:
		box.bg_color = tier_color.lerp(Color(0.08, 0.1, 0.14, 1.0), 0.82)
		box.border_color = Color(tier_color.r, tier_color.g, tier_color.b, 0.72)
	else:
		box.bg_color = Color(0.06, 0.08, 0.12, 0.92)
		box.border_color = Color(tier_color.r, tier_color.g, tier_color.b, 0.22)
	return box


func _style_header() -> void:
	if _title_label:
		_title_label.add_theme_color_override("font_color", _accent.lerp(Color.WHITE, 0.12))
