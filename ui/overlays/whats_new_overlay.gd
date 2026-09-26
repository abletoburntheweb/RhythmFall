# ui/overlays/whats_new_overlay.gd
class_name WhatsNewOverlay
extends AppOverlayBase

signal dismissed

const _Catalog = preload("res://logic/ui/whats_new_catalog.gd")
const _MarkdownLabelScript = preload("res://addons/markdownlabel/markdownlabel.gd")

@onready var _card: PanelContainer = %Card
@onready var _title_label: Label = %TitleLabel
@onready var _version_label: Label = %VersionLabel
@onready var _tagline_label: Label = %TaglineLabel
@onready var _sections_box: VBoxContainer = %SectionsBox
@onready var _close_button: Button = %CloseButton
@onready var _scroll: ScrollContainer = %Scroll


func _ready() -> void:
	super._ready()
	if _card:
		_card.add_theme_stylebox_override("panel", AppOverlayStyles.notice_panel())
	if _close_button:
		_close_button.pressed.connect(_on_close_pressed)
	apply_locale()


func apply_locale() -> void:
	if _title_label:
		_title_label.text = tr("WHATS_NEW_TITLE")
	if _close_button:
		_close_button.text = tr("WHATS_NEW_CLOSE")


func show_latest() -> void:
	var locale := LocaleManager.get_locale() if LocaleManager else "en"
	show_release(_Catalog.load_latest(locale))


func show_release(data: Dictionary) -> void:
	apply_locale()
	_clear_sections()
	var version := str(data.get("version", "")).strip_edges()
	if _version_label:
		_version_label.text = ("v%s" % version) if version != "" else ""
		_version_label.visible = version != ""
	if _tagline_label:
		var tagline := str(data.get("tagline", "")).strip_edges()
		_tagline_label.text = tagline
		_tagline_label.visible = tagline != ""
	var sections: Variant = data.get("sections", [])
	if sections is Array:
		for item in sections:
			if item is Dictionary:
				_add_section(item)
	if _scroll:
		_scroll.scroll_vertical = 0
	present()
	if _close_button:
		_close_button.grab_focus()


func present() -> void:
	super.present()


func _on_confirm_key_pressed() -> void:
	_finish()


func _on_backdrop_pressed() -> void:
	_finish()


func _on_close_pressed() -> void:
	_finish()


func _finish() -> void:
	if not visible:
		return
	UiModifierSounds.play_deselect()
	dismiss()
	dismissed.emit()


func _clear_sections() -> void:
	if _sections_box == null:
		return
	for child in _sections_box.get_children():
		_sections_box.remove_child(child)
		child.queue_free()


func _add_section(sec: Dictionary) -> void:
	var block := PanelContainer.new()
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.10, 0.13, 0.20, 0.72)
	panel.set_corner_radius_all(12)
	panel.content_margin_left = 14
	panel.content_margin_top = 12
	panel.content_margin_right = 14
	panel.content_margin_bottom = 12
	block.add_theme_stylebox_override("panel", panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	block.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	vbox.add_child(header)

	var tint := _parse_tint(str(sec.get("tint", "")))
	var icon_tex := UiIconHelper.load_tinted_icon(str(sec.get("icon", "sparkles.svg")), tint, 96)
	if icon_tex:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		header.add_child(icon)

	var title := Label.new()
	title.text = str(sec.get("title", ""))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", tint.lightened(0.12))
	header.add_child(title)

	var body_md: RichTextLabel = _MarkdownLabelScript.new() as RichTextLabel
	body_md.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_md.fit_content = true
	body_md.scroll_active = false
	body_md.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_md.add_theme_font_size_override("normal_font_size", 17)
	body_md.add_theme_font_size_override("bold_font_size", 17)
	body_md.add_theme_color_override("default_color", Color(0.86, 0.90, 0.96, 1.0))
	# Soft emphasis: reuse regular face so **…** does not go heavy on dark UI.
	var face: Font = body_md.get_theme_font("normal_font")
	if face == null and theme:
		face = theme.get_font("font", "Label")
	if face == null:
		face = ThemeDB.fallback_font
	if face:
		body_md.add_theme_font_override("bold_font", face)
		body_md.add_theme_font_override("bold_italics_font", face)
	body_md.set("markdown_text", str(sec.get("body", "")))
	vbox.add_child(body_md)

	_sections_box.add_child(block)


func _parse_tint(raw: String) -> Color:
	var s := raw.strip_edges()
	if s.begins_with("#") and (s.length() == 7 or s.length() == 9):
		return Color.html(s)
	return Color(0.72, 0.84, 0.98, 1.0)
