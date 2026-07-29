# scenes/song_select/run_modifiers/run_modifier_sidebar_tab.gd
extends Button
class_name RunModifierSidebarTab

signal tab_selected(tab_id: String)

@export var tab_id: String = ""
@export var icon_file: String = ""
@export var accent_color: Color = Color(0.55, 0.78, 0.98, 1.0)

var _panel: PanelContainer
var _title_label: Label
var _badge_label: Label
var _icon_frame: PanelContainer


func _ready() -> void:
	text = ""
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	flat = true
	custom_minimum_size = Vector2(0, 52)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bind_nodes()
	pressed.connect(_on_pressed)
	toggled.connect(_on_toggled)
	resized.connect(_sync_style)
	_sync_style()


func _bind_nodes() -> void:
	if _panel != null:
		return
	_panel = get_node_or_null("Panel") as PanelContainer
	_icon_frame = get_node_or_null("Panel/HBox/IconFrame") as PanelContainer
	_title_label = get_node_or_null("Panel/HBox/TitleLabel") as Label
	_badge_label = get_node_or_null("Panel/HBox/BadgeLabel") as Label


func setup(
	p_tab_id: String,
	title_text: String,
	p_icon_file: String = "",
	p_accent: Color = UiIconHelper.ACCENT
) -> void:
	_bind_nodes()
	tab_id = p_tab_id
	icon_file = p_icon_file
	accent_color = p_accent
	if _title_label:
		_title_label.text = title_text
	_apply_icon()
	_sync_style()


func set_selected(on: bool) -> void:
	set_pressed_no_signal(on)
	_sync_style()


func set_active_count(count: int) -> void:
	_bind_nodes()
	if _badge_label == null:
		return
	if count > 0:
		_badge_label.text = str(count)
		_badge_label.visible = true
	else:
		_badge_label.text = ""
		_badge_label.visible = false


func _apply_icon() -> void:
	if _icon_frame == null or icon_file.strip_edges() == "":
		return
	var icon_rect := _icon_frame.get_node_or_null("IconTexture") as TextureRect
	if icon_rect == null:
		return
	_icon_frame.set_meta("ui_icon_rect", icon_rect)
	var raster_path := _resolve_raster_icon_path(icon_file)
	if raster_path != "":
		_icon_frame.set_meta("ui_icon_is_raster", true)
		_icon_frame.set_meta("ui_icon_raster_path", raster_path)
		if ResourceLoader.exists(raster_path):
			icon_rect.texture = load(raster_path) as Texture2D
	else:
		_icon_frame.set_meta("ui_icon_is_raster", false)
		_icon_frame.set_meta("ui_icon_file", icon_file)
		UiIconHelper.set_frame_tint(_icon_frame, accent_color, button_pressed)


func _resolve_raster_icon_path(file_name: String) -> String:
	var trimmed := file_name.strip_edges()
	if trimmed == "":
		return ""
	if trimmed.begins_with("res://") and trimmed.ends_with(".png"):
		return trimmed
	if trimmed.ends_with(".png"):
		return "res://assets/modifiers/%s" % trimmed
	return ""


func _sync_style() -> void:
	if _panel == null:
		return
	var selected := button_pressed
	_panel.add_theme_stylebox_override("panel", _make_tab_panel_style(selected))
	if _title_label:
		var title_color := accent_color if selected else Color(0.9, 0.94, 0.98, 1.0)
		_title_label.add_theme_color_override("font_color", title_color)
	if _icon_frame:
		_sync_icon_frame_style(selected)


func _make_tab_panel_style(selected: bool) -> StyleBoxFlat:
	var panel_box := StyleBoxFlat.new()
	panel_box.set_corner_radius_all(10)
	panel_box.border_width_left = 2
	panel_box.border_width_top = 2
	panel_box.border_width_right = 2
	panel_box.border_width_bottom = 2
	panel_box.content_margin_left = 10
	panel_box.content_margin_top = 8
	panel_box.content_margin_right = 10
	panel_box.content_margin_bottom = 8
	if selected:
		panel_box.bg_color = Color(0.11, 0.14, 0.2, 0.92)
		panel_box.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.92)
	else:
		panel_box.bg_color = Color(0.09, 0.11, 0.16, 0.55)
		panel_box.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.28)
	return panel_box


func _sync_icon_frame_style(selected: bool) -> void:
	if _icon_frame.get_meta("ui_icon_is_raster", false):
		var frame_box: StyleBoxFlat = null
		if _icon_frame.has_meta("ui_icon_frame_box"):
			frame_box = _icon_frame.get_meta("ui_icon_frame_box") as StyleBoxFlat
		else:
			var panel_style := _icon_frame.get_theme_stylebox("panel")
			if panel_style is StyleBoxFlat:
				frame_box = (panel_style as StyleBoxFlat).duplicate() as StyleBoxFlat
			else:
				frame_box = StyleBoxFlat.new()
				var radius := int(_icon_frame.custom_minimum_size.x * 0.5) if _icon_frame.custom_minimum_size.x > 0.0 else 16
				frame_box.set_corner_radius_all(radius)
			_icon_frame.set_meta("ui_icon_frame_box", frame_box)
		frame_box.bg_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.22 if selected else 0.14)
		_icon_frame.add_theme_stylebox_override("panel", frame_box)
	else:
		UiIconHelper.set_frame_tint(_icon_frame, accent_color, selected)


func _on_pressed() -> void:
	if tab_id != "":
		tab_selected.emit(tab_id)


func _on_toggled(_on: bool) -> void:
	_sync_style()
