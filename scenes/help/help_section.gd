class_name HelpSection
extends VBoxContainer

signal question_selected(item: Dictionary)

const NAV_ITEM_SCENE := preload("res://scenes/help/help_nav_question.tscn")
const HEADER_HEIGHT := 54

var _section: Dictionary = {}
var _items: Array = []
var _accent := Color(0.38, 0.78, 0.74, 1.0)
var _icon_file := "circle-question-mark.svg"
var _expanded := false
var _selected_item_id := ""

@onready var _header: Button = $HeaderButton
@onready var _icon_frame: PanelContainer = $HeaderButton/Panel/HBox/IconFrame
@onready var _title_label: Label = $HeaderButton/Panel/HBox/TextVBox/TitleLabel
@onready var _count_label: Label = $HeaderButton/Panel/HBox/TextVBox/CountLabel
@onready var _chevron_label: Label = $HeaderButton/Panel/HBox/ChevronLabel
@onready var _questions_wrap: MarginContainer = $QuestionsWrap
@onready var _questions_vbox: VBoxContainer = $QuestionsWrap/QuestionsVBox


func _ready() -> void:
	if _header and not _header.toggled.is_connected(_on_header_toggled):
		_header.toggled.connect(_on_header_toggled)


func configure(
	section: Dictionary,
	items: Array,
	auto_expand: bool,
	accent_color: Color,
	icon_file: String
) -> void:
	_section = section if section is Dictionary else {}
	_items = items if items is Array else []
	_accent = accent_color
	_icon_file = icon_file if icon_file.strip_edges() != "" else "circle-question-mark.svg"
	_expanded = auto_expand
	const HelpLocale = preload("res://logic/i18n/help_locale.gd")
	var section_title := HelpLocale.localized_section_title(_section)
	if _title_label:
		_title_label.text = section_title
		_title_label.clip_text = true
		_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if _count_label:
		_count_label.text = tr("HELP_SECTION_COUNT") % _items.size()
	_apply_icon()
	_set_expanded(auto_expand, false)
	if auto_expand:
		_build_questions()


func get_section_id() -> String:
	return str(_section.get("id", ""))


func get_section() -> Dictionary:
	return _section


func get_items() -> Array:
	return _items


func set_expanded(expanded: bool, play_sound: bool = true) -> void:
	_set_expanded(expanded, play_sound)


func set_selected_item_id(item_id: String) -> void:
	_selected_item_id = item_id
	_apply_nav_selection()
	call_deferred("_apply_nav_selection")


func _apply_nav_selection() -> void:
	if _questions_vbox == null:
		return
	for child in _questions_vbox.get_children():
		if child is HelpNavQuestion:
			var nav := child as HelpNavQuestion
			nav.set_nav_selected(nav.get_item_id() == _selected_item_id)
	_sync_header_style()


func get_selected_nav_control() -> Control:
	if _selected_item_id == "" or _questions_vbox == null:
		return null
	for child in _questions_vbox.get_children():
		if child is HelpNavQuestion:
			var nav := child as HelpNavQuestion
			if nav.get_item_id() == _selected_item_id:
				return nav
	return null


func _set_expanded(expanded: bool, play_sound: bool) -> void:
	var was_expanded := _expanded
	_expanded = expanded
	if _header:
		_header.set_pressed_no_signal(expanded)
	if _questions_wrap:
		_questions_wrap.visible = expanded
	if _chevron_label:
		_chevron_label.text = "v" if expanded else ">"
	if expanded and _questions_vbox.get_child_count() == 0:
		_build_questions()
	_sync_header_style()
	if play_sound and expanded and not was_expanded:
		UiScreenHotkeys.play_section_switch_sound()


func _build_questions() -> void:
	if _questions_vbox == null:
		return
	for child in _questions_vbox.get_children():
		_questions_vbox.remove_child(child)
		child.queue_free()
	for item in _items:
		if not (item is Dictionary):
			continue
		var nav := NAV_ITEM_SCENE.instantiate() as HelpNavQuestion
		_questions_vbox.add_child(nav)
		var title := _localized_item_title(item)
		nav.configure(item, title, _accent)
		nav.set_nav_selected(str(item.get("id", "")) == _selected_item_id)
		if not nav.question_pressed.is_connected(_on_question_pressed):
			nav.question_pressed.connect(_on_question_pressed)


func _on_header_toggled(pressed: bool) -> void:
	_set_expanded(pressed, true)


func _on_question_pressed(item: Dictionary) -> void:
	if not (item is Dictionary):
		return
	_selected_item_id = str(item.get("id", ""))
	set_selected_item_id(_selected_item_id)
	UiScreenHotkeys.play_section_switch_sound()
	question_selected.emit(item)


func _apply_icon() -> void:
	if _icon_frame == null:
		return
	var icon_rect := _icon_frame.get_node_or_null("IconTexture") as TextureRect
	if icon_rect == null:
		return
	icon_rect.custom_minimum_size = Vector2(18, 18)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon_frame.custom_minimum_size = Vector2(34, 34)
	_icon_frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_icon_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon_frame.set_meta("ui_icon_file", _icon_file)
	_icon_frame.set_meta("ui_icon_rect", icon_rect)
	if _icon_frame.get_theme_stylebox("panel") is StyleBoxFlat:
		_icon_frame.set_meta("ui_icon_frame_box", (_icon_frame.get_theme_stylebox("panel") as StyleBoxFlat).duplicate())
	UiIconHelper.set_frame_tint(_icon_frame, _accent, _expanded)


func _sync_header_style() -> void:
	if _header == null:
		return
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(10)
	box.content_margin_left = 8.0
	box.content_margin_right = 10.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	if _expanded:
		box.bg_color = Color(_accent.r, _accent.g, _accent.b, 0.14).lerp(Color(0.1, 0.11, 0.15, 0.95), 0.35)
		box.set_border_width_all(2)
		box.border_color = _accent.lightened(0.08)
	else:
		box.bg_color = Color(0.09, 0.1, 0.14, 0.55)
		box.set_border_width_all(1)
		box.border_color = Color(1, 1, 1, 0.07)
	_header.add_theme_stylebox_override("normal", box)
	_header.add_theme_stylebox_override("hover", box)
	_header.add_theme_stylebox_override("pressed", box)
	_header.add_theme_stylebox_override("focus", box)
	if _title_label:
		_title_label.add_theme_color_override(
			"font_color",
			_accent if _expanded else Color(0.9, 0.93, 0.97, 1.0)
		)
	_apply_icon()


func _localized_item_title(item: Dictionary) -> String:
	const HelpLocale = preload("res://logic/i18n/help_locale.gd")
	return HelpLocale.localized_item_title(item)
