# scenes/settings_menu/settings_nav_item.gd
extends Button
class_name SettingsNavItem

const _UiMotionEffects = preload("res://logic/ui/ui_motion_effects.gd")

signal nav_selected(page_id: String)

@export var page_id: String = ""
@export var icon_file: String = ""
@export var accent_color: Color = Color(0.55, 0.78, 0.98, 1.0)
@export var danger_style: bool = false

const _BG_NORMAL := Color(0.09, 0.11, 0.16, 0.55)
const _BG_SELECTED := Color(0.11, 0.14, 0.2, 0.92)
const _TEXT_TITLE := Color(0.9, 0.94, 0.98, 1.0)
const _TEXT_DESC := Color(0.58, 0.66, 0.78, 0.92)
const _TEXT_DESC_DIM := Color(0.5, 0.56, 0.66, 0.82)

var _panel: PanelContainer
var _title_label: Label
var _desc_label: Label
var _icon_frame: PanelContainer
var _icon_frame_box: StyleBoxFlat
var _accent_color: Color = UiIconHelper.ACCENT
var _icon_file: String = ""
var _danger: bool = false


func _ready() -> void:
	text = ""
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	flat = true
	custom_minimum_size = Vector2(0, 58)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bind_nodes()
	mouse_filter = Control.MOUSE_FILTER_STOP
	pressed.connect(_on_pressed)
	toggled.connect(_on_toggled)
	resized.connect(_sync_style)
	_sync_style()
	if page_id.strip_edges() != "":
		call_deferred("refresh_locale")


func _bind_nodes() -> void:
	if _panel != null:
		return
	_panel = get_node_or_null("Panel") as PanelContainer
	_icon_frame = get_node_or_null("Panel/HBox/IconFrame") as PanelContainer
	_title_label = get_node_or_null("Panel/HBox/TextVBox/TitleLabel") as Label
	_desc_label = get_node_or_null("Panel/HBox/TextVBox/DescLabel") as Label
	_ensure_icon_frame_meta()


func setup(
	p_id: String,
	title_text: String,
	desc_text: String = "",
	icon_file: String = "",
	accent_color: Color = UiIconHelper.ACCENT,
	danger: bool = false
) -> void:
	_bind_nodes()
	page_id = p_id
	_icon_file = icon_file
	_accent_color = accent_color
	_danger = danger
	if _title_label:
		_title_label.text = title_text
		_title_label.clip_text = true
		_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if _desc_label:
		_desc_label.text = desc_text
		_desc_label.clip_text = true
		_desc_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_desc_label.visible = desc_text.strip_edges() != ""
	_apply_icon()
	_sync_style()


func refresh_locale() -> void:
	if page_id.strip_edges() == "":
		return
	var title_key := "SETTINGS_NAV_%s" % page_id.to_upper()
	var desc_key := "SETTINGS_NAV_%s_DESC" % page_id.to_upper()
	setup(page_id, tr(title_key), tr(desc_key), icon_file, accent_color, danger_style)


func set_selected(on: bool) -> void:
	set_pressed_no_signal(on)
	_sync_style()


func _ensure_icon_frame_meta() -> void:
	if _icon_frame == null:
		return
	var icon_rect := _icon_frame.get_node_or_null("IconTexture") as TextureRect
	if icon_rect and not _icon_frame.has_meta("ui_icon_rect"):
		_icon_frame.set_meta("ui_icon_rect", icon_rect)
	if not _icon_frame.has_meta("ui_icon_frame_box"):
		var panel_style := _icon_frame.get_theme_stylebox("panel")
		if panel_style is StyleBoxFlat:
			_icon_frame.set_meta("ui_icon_frame_box", (panel_style as StyleBoxFlat).duplicate())


func _apply_icon() -> void:
	if _icon_frame == null or _icon_file.strip_edges() == "":
		return
	_ensure_icon_frame_meta()
	_icon_frame.set_meta("ui_icon_file", _icon_file)
	var tint := Color(0.95, 0.45, 0.42, 1.0) if _danger else _accent_color
	UiIconHelper.set_frame_tint(_icon_frame, tint, button_pressed)


func _sync_style() -> void:
	if _panel == null:
		return
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(10)
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.content_margin_left = 10
	box.content_margin_top = 8
	box.content_margin_right = 10
	box.content_margin_bottom = 8
	var selected := button_pressed
	if _danger:
		box.bg_color = Color(0.18, 0.08, 0.1, 0.55) if not selected else Color(0.22, 0.1, 0.12, 0.88)
		box.border_color = Color(0.9, 0.35, 0.35, 0.45) if not selected else Color(0.95, 0.42, 0.42, 0.9)
	elif selected:
		box.bg_color = _BG_SELECTED
		box.border_color = Color(_accent_color.r, _accent_color.g, _accent_color.b, 0.92)
	else:
		box.bg_color = _BG_NORMAL
		box.border_color = Color(_accent_color.r, _accent_color.g, _accent_color.b, 0.3)
	_UiMotionEffects.stop_panel_border_pulse(_panel)
	_panel.add_theme_stylebox_override("panel", box)
	if selected:
		var pulse_color := Color(0.95, 0.42, 0.42, 1.0) if _danger else _accent_color
		_UiMotionEffects.pulse_panel_border(_panel, pulse_color, 0.52, 0.95, 0.85)
	if _title_label:
		var title_color := _TEXT_TITLE
		if _danger:
			title_color = Color(0.98, 0.55, 0.52, 1.0)
		elif selected:
			title_color = _accent_color
		_title_label.add_theme_color_override("font_color", title_color)
	if _desc_label:
		var desc_color := _TEXT_DESC_DIM if selected else _TEXT_DESC
		if selected and not _danger:
			desc_color = Color(_accent_color.r, _accent_color.g, _accent_color.b, 0.82)
		_desc_label.add_theme_color_override("font_color", desc_color)
	if _icon_frame:
		_icon_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var tint := Color(0.95, 0.45, 0.42, 1.0) if _danger else _accent_color
		UiIconHelper.set_frame_tint(_icon_frame, tint, selected)
	_apply_icon()


func _on_pressed() -> void:
	if page_id != "":
		nav_selected.emit(page_id)


func _on_toggled(_on: bool) -> void:
	_sync_style()
