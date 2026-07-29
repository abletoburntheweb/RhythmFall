# scenes/song_select/generation_select_card.gd
extends Button
class_name GenerationSelectCard

const _UiMotionEffects = preload("res://logic/ui/ui_motion_effects.gd")

signal card_selected(card_id: String)

@export var card_id: String = ""

const _SEL_BORDER_WIDTH := 2
const _BG_NORMAL := Color(0.1, 0.12, 0.17, 0.95)
const _BG_SELECTED := Color(0.14, 0.18, 0.26, 0.98)
const _BG_LOCKED := Color(0.08, 0.09, 0.12, 0.92)
const _TEXT_TITLE := Color(0.88, 0.92, 0.98, 1.0)
const _TEXT_DESC := Color(0.62, 0.7, 0.82, 0.92)
const _TEXT_BADGE := Color(0.55, 0.78, 0.98, 1.0)
const _FRAME_NORMAL_ALPHA := 0.14
const _FRAME_SELECTED_ALPHA := 0.24

var _title_label: Label
var _subtitle_label: Label
var _desc_label: Label
var _badge_label: Label
var _icon_rect: TextureRect
var _icon_frame: PanelContainer
var _icon_frame_box: StyleBoxFlat
var _panel: PanelContainer
var _is_locked: bool = false
var _icon_file: String = ""
var _accent_color: Color = UiIconHelper.ACCENT
var _recommended: bool = false
var _badge_base_text: String = ""
var _params_tuned: bool = false
const _RECOMMENDED_COLOR := Color(0.95, 0.82, 0.45, 1.0)
const _TUNED_COLOR := Color(0.62, 0.78, 0.98, 1.0)
var _panel_style: StyleBoxFlat = null
var _style_sync_queued: bool = false
var _suppress_toggle_feedback: bool = false


func _ready() -> void:
	text = ""
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	flat = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_transparent_button_styles()
	_bind_nodes()
	_set_pass_through_mouse()
	pressed.connect(_on_pressed)
	toggled.connect(_on_toggled)
	_sync_style()


func _apply_transparent_button_styles() -> void:
	var empty := StyleBoxFlat.new()
	empty.bg_color = Color(0, 0, 0, 0)
	empty.set_border_width_all(0)
	empty.set_content_margin_all(0)
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(StringName(state_name), empty)


func _queue_sync_style() -> void:
	if _style_sync_queued:
		return
	_style_sync_queued = true
	call_deferred("_deferred_sync_style")


func _deferred_sync_style() -> void:
	_style_sync_queued = false
	if not is_instance_valid(self):
		return
	_sync_style()


func _bind_nodes() -> void:
	if _panel != null:
		return
	_panel = get_node_or_null("Panel") as PanelContainer
	_icon_frame = get_node_or_null("Panel/VBox/IconCenter/IconFrame") as PanelContainer
	if _panel:
		_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		_panel.offset_left = 1
		_panel.offset_top = 1
		_panel.offset_right = -1
		_panel.offset_bottom = -1
	_icon_rect = get_node_or_null("Panel/VBox/IconCenter/IconFrame/IconTexture") as TextureRect
	_title_label = get_node_or_null("Panel/VBox/TitleLabel") as Label
	_subtitle_label = get_node_or_null("Panel/VBox/SubtitleLabel") as Label
	_desc_label = get_node_or_null("Panel/VBox/DescLabel") as Label
	_badge_label = get_node_or_null("Panel/VBox/BadgeLabel") as Label
	if _icon_frame:
		var existing := _icon_frame.get_theme_stylebox("panel")
		if existing is StyleBoxFlat:
			_icon_frame_box = existing.duplicate() as StyleBoxFlat
		elif _icon_frame_box == null:
			_icon_frame_box = StyleBoxFlat.new()
			_icon_frame_box.set_corner_radius_all(18)
			_icon_frame_box.set_content_margin_all(8)


func setup(
	p_id: String,
	title_text: String,
	desc_text: String = "",
	badge_text: String = "",
	locked: bool = false,
	icon_file: String = "",
	accent_color: Color = UiIconHelper.ACCENT,
	subtitle_text: String = ""
) -> void:
	_bind_nodes()
	_reset_custom_title_display()
	card_id = p_id
	_is_locked = locked
	disabled = false
	focus_mode = Control.FOCUS_NONE
	_icon_file = icon_file
	_accent_color = accent_color
	if _title_label:
		_title_label.text = title_text
	if _subtitle_label:
		var show_subtitle := subtitle_text.strip_edges() != ""
		_subtitle_label.text = subtitle_text
		_subtitle_label.visible = show_subtitle
		if show_subtitle:
			_subtitle_label.add_theme_color_override("font_color", UiIconHelper.MUTED)
	if _desc_label:
		_desc_label.text = desc_text
		_desc_label.visible = desc_text.strip_edges() != ""
	_badge_base_text = badge_text
	_apply_badge_text()
	_apply_locked_visual()
	_sync_style()
	_queue_sync_style()


func set_recommended(on: bool) -> void:
	_recommended = on and not _is_locked
	_apply_badge_text()
	_sync_style()


func set_params_tuned(on: bool) -> void:
	_params_tuned = on and not _is_locked
	_apply_badge_text()
	_sync_style()


func _apply_badge_text() -> void:
	if _badge_label == null:
		return
	if _is_locked and _badge_base_text.strip_edges() != "":
		_badge_label.text = _badge_base_text
		_badge_label.visible = true
		_badge_label.add_theme_color_override("font_color", UiIconHelper.MUTED)
		return
	if _recommended:
		_badge_label.text = TranslationServer.translate("GEN_SMART_RECOMMENDED")
		_badge_label.visible = true
		_badge_label.add_theme_color_override("font_color", _RECOMMENDED_COLOR)
		return
	if _params_tuned and button_pressed and not _is_locked:
		_badge_label.text = TranslationServer.translate("GEN_INTENT_TUNED_BADGE")
		_badge_label.visible = true
		_badge_label.add_theme_color_override("font_color", _TUNED_COLOR)
		return
	if _badge_base_text.strip_edges() != "":
		_badge_label.text = _badge_base_text
		_badge_label.visible = true
		_badge_label.add_theme_color_override("font_color", _TEXT_BADGE)
		return
	_badge_label.visible = false


func _set_pass_through_mouse() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _panel:
		_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for lbl in [_title_label, _subtitle_label, _desc_label, _badge_label]:
		if lbl:
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _icon_rect:
		_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _icon_frame:
		_icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := get_node_or_null("Panel/VBox/IconCenter") as Control
	if center:
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vbox := get_node_or_null("Panel/VBox") as Control
	if vbox:
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_card_selected(on: bool) -> void:
	# Never assign button_pressed from inside toggled — that recurses with ButtonGroup.
	_suppress_toggle_feedback = true
	set_pressed_no_signal(on and not _is_locked)
	_sync_style()
	_suppress_toggle_feedback = false


func _on_pressed() -> void:
	if _is_locked:
		# Locked cards stay in the group for layout; ignore press (no re-toggle fight).
		set_pressed_no_signal(false)
		return
	# Selection is announced from toggled(true) only — avoid double card_selected.


func _on_toggled(on: bool) -> void:
	if _suppress_toggle_feedback:
		return
	if _is_locked:
		set_pressed_no_signal(false)
		_sync_style()
		return
	# Exclusivity is ButtonGroup's job — do not force-repress here (stack overflow).
	_sync_style()
	if on:
		emit_signal("card_selected", card_id)


func _apply_locked_visual() -> void:
	modulate = Color(0.72, 0.76, 0.84, 1.0) if _is_locked else Color.WHITE


func _sync_style() -> void:
	_bind_nodes()
	var selected := button_pressed and not _is_locked
	if _panel:
		_UiMotionEffects.stop_panel_border_pulse(_panel)
		if _panel_style == null:
			_panel_style = StyleBoxFlat.new()
			_panel_style.set_corner_radius_all(10)
			_panel_style.set_content_margin_all(8)
		var box := _panel_style.duplicate() as StyleBoxFlat
		if selected:
			var accent := _accent_color.lightened(0.12)
			box.bg_color = Color(_accent_color.r, _accent_color.g, _accent_color.b, 0.16).lerp(_BG_SELECTED, 0.45)
			box.border_color = accent
			box.set_border_width_all(_SEL_BORDER_WIDTH)
		elif _is_locked:
			box.bg_color = _BG_LOCKED
			box.border_color = Color(1, 1, 1, 0.08)
			box.set_border_width_all(1)
		else:
			box.bg_color = _BG_NORMAL
			box.border_color = Color(1, 1, 1, 0.1)
			box.set_border_width_all(1)
		_panel.add_theme_stylebox_override("panel", box)
	if selected and _panel:
		var pulse_accent := _accent_color.lightened(0.12)
		_UiMotionEffects.pulse_panel_border(_panel, pulse_accent, 0.38, 0.94, 0.82)
	if _title_label:
		_title_label.add_theme_color_override("font_color", UiIconHelper.MUTED if _is_locked else _TEXT_TITLE)
	if _subtitle_label and _subtitle_label.visible:
		_subtitle_label.add_theme_color_override("font_color", UiIconHelper.MUTED)
	if _desc_label and _desc_label.visible:
		_desc_label.add_theme_color_override("font_color", UiIconHelper.MUTED if _is_locked else _TEXT_DESC)
	_apply_badge_text()
	_sync_icon_visual(selected)


func configure_custom_preset_display(preset_line: String, icon_file: String, accent_color: Color) -> void:
	_bind_nodes()
	_reset_custom_title_display()
	card_id = "custom"
	_is_locked = false
	disabled = false
	_icon_file = icon_file
	_accent_color = accent_color
	_badge_base_text = ""
	if _desc_label:
		_desc_label.visible = false
	if _subtitle_label:
		_subtitle_label.visible = false
	if _badge_label:
		_badge_label.visible = false
	var icon_frame := get_node_or_null("Panel/VBox/IconCenter/IconFrame") as Control
	if icon_frame:
		icon_frame.custom_minimum_size = Vector2(28, 28)
	if _icon_rect:
		_icon_rect.custom_minimum_size = Vector2(16, 16)
	var main_title := TranslationServer.translate("GEN_MODE_CUSTOM")
	if _title_label:
		_title_label.visible = false
	var rich := _ensure_custom_title_rich()
	if rich:
		var muted := UiIconHelper.MUTED.to_html(false)
		rich.text = "%s\n[color=#%s]%s[/color]" % [main_title, muted, preset_line]
		rich.visible = true
	custom_minimum_size.y = maxf(custom_minimum_size.y, 136.0)
	_apply_locked_visual()
	_sync_style()


func _reset_custom_title_display() -> void:
	if _title_label:
		_title_label.visible = true
	var rich := get_node_or_null("Panel/VBox/CustomTitleRich") as RichTextLabel
	if rich:
		rich.visible = false
	var icon_frame := get_node_or_null("Panel/VBox/IconCenter/IconFrame") as Control
	if icon_frame:
		icon_frame.custom_minimum_size = Vector2(36, 36)
	if _icon_rect:
		_icon_rect.custom_minimum_size = Vector2(20, 20)


func _ensure_custom_title_rich() -> RichTextLabel:
	var vbox := get_node_or_null("Panel/VBox") as VBoxContainer
	if vbox == null:
		return null
	var rich := vbox.get_node_or_null("CustomTitleRich") as RichTextLabel
	if rich == null:
		rich = RichTextLabel.new()
		rich.name = &"CustomTitleRich"
		rich.bbcode_enabled = true
		rich.fit_content = true
		rich.scroll_active = false
		rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rich.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rich.custom_minimum_size = Vector2(0, 34)
		rich.add_theme_font_size_override("normal_font_size", 13)
		rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var title := vbox.get_node_or_null("TitleLabel") as Control
		var insert_idx := title.get_index() + 1 if title else 1
		vbox.add_child(rich)
		vbox.move_child(rich, insert_idx)
	return rich


func _sync_icon_visual(selected: bool) -> void:
	if _icon_rect == null or _icon_file.strip_edges() == "":
		if _icon_rect:
			_icon_rect.visible = false
		return
	var tint := UiIconHelper.MUTED if _is_locked else (_accent_color.lightened(0.12) if selected else _accent_color)
	_icon_rect.texture = UiIconHelper.load_tinted_icon(_icon_file, tint)
	_icon_rect.modulate = Color.WHITE
	_icon_rect.visible = true
	if _icon_frame_box and _icon_frame:
		var alpha := _FRAME_SELECTED_ALPHA if selected and not _is_locked else _FRAME_NORMAL_ALPHA
		_icon_frame_box.bg_color = Color(tint.r, tint.g, tint.b, alpha)
		_icon_frame.add_theme_stylebox_override("panel", _icon_frame_box)
