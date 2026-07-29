# scenes/marathon/marathon_summary_rules_panel.gd
extends VBoxContainer
class_name MarathonSummaryRulesPanel

const _MarathonRunRules = preload("res://logic/domain/session/marathon_run_rules.gd")
const _SongSelectUiStyles = preload("res://scenes/song_select/lib/song_select_ui_styles.gd")
const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")

var _accent := Color(0.79, 0.57, 0.35, 1.0)
var _title_label: Label = null
var _chips_flow: FlowContainer = null


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
		_title_label.text = tr("MARATHON_SUMMARY_RULES_TITLE")


func refresh(template: Dictionary) -> void:
	if _title_label == null:
		_build_ui()
	var items := _MarathonRunRules.preview_items_for_template(template)
	visible = not items.is_empty()
	if not visible:
		return
	for child in _chips_flow.get_children():
		child.queue_free()
	for item in items:
		_chips_flow.add_child(_make_chip(item))


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	_title_label = Label.new()
	_title_label.text = tr("MARATHON_SUMMARY_RULES_TITLE")
	_title_label.add_theme_font_size_override("font_size", 13)
	add_child(_title_label)

	var panel := PanelContainer.new()
	var box := _SongSelectUiStyles.card_panel_style().duplicate() as StyleBoxFlat
	box.bg_color = Color(0.07, 0.09, 0.13, 0.94)
	box.border_color = Color(_accent.r, _accent.g, _accent.b, 0.28)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", box)
	add_child(panel)

	_chips_flow = FlowContainer.new()
	_chips_flow.add_theme_constant_override("h_separation", 8)
	_chips_flow.add_theme_constant_override("v_separation", 8)
	panel.add_child(_chips_flow)


func _make_chip(item: Dictionary) -> PanelContainer:
	var tint: Color = _accent
	var raw_tint: Variant = item.get("tint")
	if raw_tint is Color:
		tint = raw_tint
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(tint.r, tint.g, tint.b, 0.12)
	box.border_color = Color(tint.r, tint.g, tint.b, 0.42)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.content_margin_left = 8.0
	box.content_margin_right = 10.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)

	row.add_child(_UiIconHelper.make_icon_frame(str(item.get("icon", "circle-check.svg")), 26, 14, tint))

	var label := Label.new()
	label.text = str(item.get("text", ""))
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.84, 0.88, 0.96, 0.98))
	row.add_child(label)
	return panel
