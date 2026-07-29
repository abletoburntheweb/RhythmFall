# scenes/help/help_nav_question.gd
extends Button
class_name HelpNavQuestion

const _UiMotionEffects = preload("res://logic/ui/ui_motion_effects.gd")

signal question_pressed(item: Dictionary)

const _BG_NORMAL := Color(0.07, 0.08, 0.11, 0.45)
const _BG_SELECTED := Color(0.09, 0.12, 0.16, 0.92)
const _TEXT_NORMAL := Color(0.78, 0.82, 0.88, 0.95)
const _CHEVRON := Color(0.45, 0.5, 0.58, 0.75)

var _item: Dictionary = {}
var _title_text := ""
var _accent := Color(0.38, 0.78, 0.74, 1.0)
var _nav_active := false

@onready var _panel: PanelContainer = $Panel
@onready var _title_label: Label = $Panel/HBox/TitleLabel
@onready var _chevron_label: Label = $Panel/HBox/ChevronLabel


func _ready() -> void:
	text = ""
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(0, 40)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	pressed.connect(_on_pressed)
	resized.connect(_sync_style)
	_sync_style()


func configure(item: Dictionary, title: String, accent: Color) -> void:
	_item = item if item is Dictionary else {}
	_title_text = title
	_accent = accent
	if _title_label:
		_title_label.text = title
		_title_label.clip_text = true
		_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_sync_style()


func get_item_id() -> String:
	return str(_item.get("id", ""))


func set_nav_selected(active: bool) -> void:
	_nav_active = active
	set_pressed_no_signal(active)
	_request_style_sync()


func _on_pressed() -> void:
	if _item.is_empty():
		return
	question_pressed.emit(_item)


func _request_style_sync() -> void:
	if is_node_ready():
		_sync_style()
	else:
		call_deferred("_sync_style")


func _sync_style() -> void:
	var panel := _panel if _panel != null else get_node_or_null("Panel") as PanelContainer
	var title_label := _title_label if _title_label != null else get_node_or_null("Panel/HBox/TitleLabel") as Label
	var chevron_label := _chevron_label if _chevron_label != null else get_node_or_null("Panel/HBox/ChevronLabel") as Label
	if panel == null:
		return
	var active := _nav_active
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(8)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 7.0
	box.content_margin_bottom = 7.0
	if active:
		box.bg_color = _BG_SELECTED
		box.set_border_width_all(2)
		box.border_color = _accent.lightened(0.1)
	else:
		box.bg_color = _BG_NORMAL
		box.set_border_width_all(1)
		box.border_color = Color(1, 1, 1, 0.06)
	panel.add_theme_stylebox_override("panel", box)
	_UiMotionEffects.stop_panel_border_pulse(panel)
	if active:
		_UiMotionEffects.pulse_panel_border(panel, _accent.lightened(0.1), 0.5, 0.92, 0.82)
	if title_label:
		title_label.add_theme_color_override(
			"font_color",
			_accent if active else _TEXT_NORMAL
		)
	if chevron_label:
		chevron_label.text = "v" if active else ">"
		chevron_label.add_theme_color_override(
			"font_color",
			_accent if active else _CHEVRON
		)
