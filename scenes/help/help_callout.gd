# scenes/help/help_callout.gd
class_name HelpCallout
extends PanelContainer

const _HelpTypography = preload("res://scenes/help/lib/help_typography.gd")

const _STYLES := {
	"tip": {"icon": "sparkles.svg", "color": Color(0.66, 0.58, 0.86, 1.0)},
	"info": {"icon": "info.svg", "color": Color(0.38, 0.78, 0.74, 1.0)},
	"warning": {"icon": "triangle-alert.svg", "color": Color(0.98, 0.64, 0.31, 1.0)},
}
const _GEAR_INLINE_TINT := Color(0.48, 0.72, 0.98, 0.95)
const _GEAR_INLINE_SIZE := 15

@onready var _title_label: Label = $Margin/HBox/TextVBox/TitleLabel
@onready var _body_label: RichTextLabel = $Margin/HBox/TextVBox/BodyLabel
@onready var _icon_rect: TextureRect = $Margin/HBox/IconFrame/IconTexture

var _pending_setup: Dictionary = {}


func _ready() -> void:
	_flush_pending_setup()


func setup(callout_type: String, body_bbcode: String, show_title: bool = true, title_text: String = "") -> void:
	if _body_label == null:
		_pending_setup = {
			"type": callout_type,
			"body": body_bbcode,
			"show_title": show_title,
			"title": title_text,
		}
		return
	_apply_setup(callout_type, body_bbcode, show_title, title_text)


func _flush_pending_setup() -> void:
	if _pending_setup.is_empty():
		return
	var pending := _pending_setup
	_pending_setup.clear()
	_apply_setup(
		str(pending.get("type", "info")),
		str(pending.get("body", "")),
		bool(pending.get("show_title", true)),
		str(pending.get("title", ""))
	)


func _apply_setup(callout_type: String, body_bbcode: String, show_title: bool, title_text: String) -> void:
	var style: Dictionary = _STYLES.get(callout_type, _STYLES.info)
	var accent: Color = style.color
	var title_key := "HELP_CALLOUT_%s" % callout_type.to_upper()
	if _title_label:
		_title_label.visible = show_title
		if show_title:
			_title_label.text = title_text if title_text.strip_edges() != "" else tr(title_key)
			_HelpTypography.apply_label(
				_title_label,
				_HelpTypography.SIZE_BODY,
				accent.lightened(0.08),
			)
	if _body_label:
		_body_label.visible = body_bbcode.strip_edges() != ""
		_HelpTypography.apply_richtext(_body_label, _HelpTypography.SIZE_BODY)
		_set_body_text(body_bbcode)
		_body_label.fit_content = true
		_body_label.scroll_active = false
		call_deferred("_sync_body_height")
	if _icon_rect:
		_icon_rect.texture = UiIconHelper.load_tinted_icon(style.icon, accent)
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(10)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	box.bg_color = Color(accent.r, accent.g, accent.b, 0.12)
	box.set_border_width_all(1)
	box.border_color = Color(accent.r, accent.g, accent.b, 0.42)
	add_theme_stylebox_override("panel", box)
	custom_minimum_size = Vector2(0, 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func _set_body_text(body: String) -> void:
	if _body_label == null:
		return
	_body_label.clear()
	if not "{gear}" in body:
		_body_label.bbcode_enabled = false
		_body_label.append_text(body)
		return
	_body_label.bbcode_enabled = false
	var gear_tex := UiIconHelper.load_tinted_icon("settings.svg", _GEAR_INLINE_TINT)
	var parts := body.split("{gear}")
	_body_label.append_text(parts[0])
	for i in range(1, parts.size()):
		if gear_tex:
			_body_label.add_image(gear_tex, _GEAR_INLINE_SIZE, _GEAR_INLINE_SIZE, Color.WHITE)
		_body_label.append_text(parts[i])


func _sync_body_height() -> void:
	if _body_label == null or not _body_label.visible:
		return
	var content_h := _body_label.get_content_height()
	if content_h > 0.0:
		_body_label.custom_minimum_size.y = content_h
