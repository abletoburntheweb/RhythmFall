# scenes/help/help_card.gd
class_name HelpCard
extends VBoxContainer

@export var collapsed_prefix: String = "> "
@export var expanded_prefix: String = "v "
@export var title_modulate_expanded: Color = Color(0.42, 0.57, 0.82)
@export var title_modulate_collapsed: Color = Color.WHITE

var _accordion_title: String = ""

@onready var _header_button: Button = $HeaderButton
@onready var _content_margin: MarginContainer = $ContentMargin
@onready var _content_label: RichTextLabel = $ContentMargin/ContentLabel


func setup(title: String, content: String) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_accordion_title = title
	_content_label.bbcode_enabled = true
	_content_label.text = content
	_header_button.text = collapsed_prefix + title
	_header_button.set_pressed_no_signal(false)
	_content_margin.visible = false
	_content_label.custom_minimum_size = Vector2.ZERO
	_apply_header_visual(false)
	if not _header_button.toggled.is_connected(_on_header_toggled):
		_header_button.toggled.connect(_on_header_toggled)


func _on_header_toggled(pressed: bool) -> void:
	_content_margin.visible = pressed
	_header_button.text = (expanded_prefix if pressed else collapsed_prefix) + _accordion_title
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
			_content_label.custom_minimum_size.y = maxf(h, 24.0)
			_content_label.custom_minimum_size.x = 0.0
			return
	_content_label.custom_minimum_size.x = 0.0
	_content_label.custom_minimum_size.y = 280.0


func _apply_header_visual(pressed: bool) -> void:
	if pressed:
		_header_button.modulate = title_modulate_expanded
	else:
		_header_button.modulate = title_modulate_collapsed
