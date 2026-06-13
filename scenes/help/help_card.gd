# scenes/help/help_card.gd
class_name HelpCard
extends PanelContainer

const DEFAULT_HEADER_FONT_SIZE := 26
const DEFAULT_BODY_FONT_SIZE := 26
const CARD_BORDER := Color(0.22, 0.26, 0.32, 0.55)
const CARD_BORDER_ACTIVE := Color(0.30, 0.36, 0.44, 0.75)
const CARD_BG := Color(0.025, 0.025, 0.028, 1.0)
const CARD_BG_EXPANDED := Color(0.032, 0.032, 0.036, 1.0)

@export var collapsed_prefix: String = "> "
@export var expanded_prefix: String = "v "
@export var title_modulate_expanded: Color = Color(0.97, 0.98, 1.0, 1.0)
@export var title_modulate_collapsed: Color = Color(0.82, 0.86, 0.91, 1.0)

var _accordion_title: String = ""

@onready var _header_button: Button = $InnerVBox/HeaderButton
@onready var _content_margin: MarginContainer = $InnerVBox/ContentMargin
@onready var _content_label: RichTextLabel = $InnerVBox/ContentMargin/ContentLabel


func setup(title: String, content: String) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_accordion_title = title
	_content_label.bbcode_enabled = true
	_content_label.text = content
	_header_button.text = collapsed_prefix + title
	_header_button.set_pressed_no_signal(false)
	_header_button.add_theme_font_size_override("font_size", DEFAULT_HEADER_FONT_SIZE)
	_content_label.add_theme_font_size_override("normal_font_size", DEFAULT_BODY_FONT_SIZE)
	_content_label.add_theme_color_override("default_color", Color(0.90, 0.92, 0.96, 1.0))
	_apply_card_panel(false)
	_apply_header_button_styles()
	_content_margin.visible = false
	_content_label.custom_minimum_size = Vector2.ZERO
	_apply_header_visual(false)
	if not _header_button.toggled.is_connected(_on_header_toggled):
		_header_button.toggled.connect(_on_header_toggled)


func _apply_card_panel(expanded: bool) -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = CARD_BG_EXPANDED if expanded else CARD_BG
	panel.draw_center = true
	panel.border_width_left = 3 if expanded else 1
	panel.border_width_top = 1
	panel.border_width_right = 1
	panel.border_width_bottom = 1
	if expanded:
		panel.border_color = CARD_BORDER_ACTIVE
	else:
		panel.border_color = CARD_BORDER
	panel.set_corner_radius_all(8)
	panel.content_margin_left = 4
	panel.content_margin_top = 2
	panel.content_margin_right = 4
	panel.content_margin_bottom = 4
	add_theme_stylebox_override("panel", panel)


func _apply_header_button_styles() -> void:
	var empty := StyleBoxEmpty.new()
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(1, 1, 1, 0.035)
	hover.set_corner_radius_all(6)
	_header_button.add_theme_stylebox_override("normal", empty)
	_header_button.add_theme_stylebox_override("hover", hover)
	_header_button.add_theme_stylebox_override("pressed", hover)
	_header_button.add_theme_stylebox_override("focus", empty)
	_header_button.add_theme_stylebox_override("disabled", empty)


func _on_header_toggled(pressed: bool) -> void:
	_content_margin.visible = pressed
	_header_button.text = (expanded_prefix if pressed else collapsed_prefix) + _accordion_title
	_apply_card_panel(pressed)
	_apply_header_visual(pressed)
	if pressed:
		call_deferred("_update_richtext_layout")
	else:
		_content_label.custom_minimum_size = Vector2.ZERO


func _update_richtext_layout() -> void:
	if not _content_margin.visible:
		return
	for _i in range(10):
		await get_tree().process_frame
		_content_label.queue_redraw()
		var mw: float = _content_margin.size.x
		if mw > 2.0 and _content_label.size.x < 2.0:
			_content_label.custom_minimum_size.x = mw
		var h: float = _content_label.get_content_height()
		if h >= 1.0:
			_content_label.custom_minimum_size.y = maxf(h, 28.0)
			_content_label.custom_minimum_size.x = 0.0
			return
	_content_label.custom_minimum_size.x = 0.0
	_content_label.custom_minimum_size.y = 280.0


func _apply_header_visual(pressed: bool) -> void:
	if pressed:
		_header_button.modulate = title_modulate_expanded
	else:
		_header_button.modulate = title_modulate_collapsed
