# scenes/profile/components/profile_insights_panel.gd
extends VBoxContainer
class_name ProfileInsightsPanel

const _ProfileInsights = preload("res://logic/domain/profile/profile_insights.gd")

var _persistent_row: HBoxContainer
var _dynamic_card: PanelContainer
var _dynamic_icon: TextureRect
var _dynamic_title: Label
var _dynamic_body: Label


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_build_nodes()


func refresh(history: Array, rotate_dynamic: bool = false) -> void:
	_refresh_persistent_row()
	_refresh_dynamic_card(history, rotate_dynamic)


func _build_nodes() -> void:
	_persistent_row = HBoxContainer.new()
	_persistent_row.name = "PersistentRow"
	_persistent_row.add_theme_constant_override("separation", 8)
	_persistent_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_persistent_row)

	_dynamic_card = PanelContainer.new()
	_dynamic_card.name = "DynamicCard"
	_dynamic_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_card_style(_dynamic_card)
	add_child(_dynamic_card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_dynamic_card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	_dynamic_icon = TextureRect.new()
	_dynamic_icon.custom_minimum_size = Vector2(28, 28)
	_dynamic_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_dynamic_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_dynamic_icon)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 2)
	row.add_child(text_col)

	_dynamic_title = Label.new()
	_dynamic_title.add_theme_font_size_override("font_size", 15)
	_dynamic_title.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0, 1.0))
	text_col.add_child(_dynamic_title)

	_dynamic_body = Label.new()
	_dynamic_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dynamic_body.add_theme_font_size_override("font_size", 13)
	_dynamic_body.add_theme_color_override("font_color", Color(0.72, 0.78, 0.88, 1.0))
	text_col.add_child(_dynamic_body)


func _refresh_persistent_row() -> void:
	for child in _persistent_row.get_children():
		child.queue_free()
	for fact in _ProfileInsights.build_persistent_facts():
		if fact is Dictionary:
			_persistent_row.add_child(_make_persistent_chip(fact as Dictionary))


func _make_persistent_chip(fact: Dictionary) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var accent: Color = fact.get("accent", Color(0.55, 0.92, 0.78, 1.0))
	var box := StyleBoxFlat.new()
	box.bg_color = Color(accent.r, accent.g, accent.b, 0.12)
	box.border_color = accent.lerp(Color.WHITE, 0.18)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	chip.add_theme_stylebox_override("panel", box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	chip.add_child(row)

	var icon_file := str(fact.get("icon", "")).strip_edges()
	if icon_file != "":
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(14, 14)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = UiIconHelper.load_tinted_icon(icon_file, accent.lightened(0.1), 14)
		row.add_child(icon)

	var label := Label.new()
	label.text = str(fact.get("text", ""))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", accent.lerp(Color.WHITE, 0.42))
	row.add_child(label)
	return chip


func _refresh_dynamic_card(history: Array, rotate_dynamic: bool) -> void:
	var visit_index := int(SettingsManager.get_setting("profile_insight_visit", 0))
	if rotate_dynamic:
		visit_index += 1
		SettingsManager.set_setting("profile_insight_visit", visit_index)
		SettingsManager.save_settings()
	var insight: Dictionary = _ProfileInsights.pick_dynamic_insight(history, visit_index)
	var accent: Color = insight.get("accent", Color(0.55, 0.92, 0.78, 1.0))
	var icon_file := str(insight.get("icon", "sparkles.svg"))
	_dynamic_icon.texture = UiIconHelper.load_tinted_icon(icon_file, accent.lightened(0.08), 28)
	_dynamic_title.text = str(insight.get("title", ""))
	_dynamic_body.text = str(insight.get("body", ""))
	_apply_card_style(_dynamic_card, accent)


func _apply_card_style(card: PanelContainer, accent: Color = Color(0.55, 0.92, 0.78, 1.0)) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(accent.r, accent.g, accent.b, 0.1)
	box.border_color = accent.lerp(Color.WHITE, 0.12)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	card.add_theme_stylebox_override("panel", box)
