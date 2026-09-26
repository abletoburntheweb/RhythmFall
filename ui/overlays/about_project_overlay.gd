# ui/overlays/about_project_overlay.gd
class_name AboutProjectOverlay
extends AppOverlayBase

signal dismissed

const _MarkdownLabelScript = preload("res://addons/markdownlabel/markdownlabel.gd")

const GITHUB_URL := "https://github.com/abletoburntheweb/RhythmFall"
const SERVER_URL := "https://github.com/abletoburntheweb/RhythmFallServer"

@onready var _card: PanelContainer = %Card
@onready var _title_label: Label = %TitleLabel
@onready var _version_label: Label = %VersionLabel
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
		_title_label.text = tr("ABOUT_TITLE")
	if _close_button:
		_close_button.text = tr("ABOUT_CLOSE")
	if visible:
		_rebuild_sections()


func show_about() -> void:
	apply_locale()
	if _version_label:
		_version_label.text = AppVersion.get_release_label()
	_rebuild_sections()
	if _scroll:
		_scroll.scroll_vertical = 0
	present()
	if _close_button:
		_close_button.grab_focus()


func _rebuild_sections() -> void:
	_clear_sections()
	_add_section(
		tr("ABOUT_SECTION_PROJECT_TITLE"),
		"info.svg",
		Color(0.55, 0.78, 0.98, 1.0),
		tr("ABOUT_SECTION_PROJECT_BODY"),
		true
	)
	_add_section(
		tr("ABOUT_SECTION_CREDITS_TITLE"),
		"scroll-text.svg",
		Color(0.72, 0.84, 0.98, 1.0),
		tr("ABOUT_SECTION_CREDITS_BODY"),
		false
	)
	_add_section(
		tr("ABOUT_SECTION_THANKS_TITLE"),
		"sparkles.svg",
		Color(0.96, 0.82, 0.42, 1.0),
		tr("ABOUT_SECTION_THANKS_BODY"),
		false
	)


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


func _add_section(
	title_text: String,
	icon_name: String,
	tint: Color,
	body_text: String,
	with_links: bool
) -> void:
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

	var icon_tex := UiIconHelper.load_tinted_icon(icon_name, tint, 96)
	if icon_tex:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		header.add_child(icon)

	var title := Label.new()
	title.text = title_text
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
	_apply_markdown_fonts(body_md)
	body_md.set("markdown_text", body_text)
	vbox.add_child(body_md)

	if with_links:
		var links := HBoxContainer.new()
		links.add_theme_constant_override("separation", 10)
		vbox.add_child(links)
		_add_link_button(links, tr("ABOUT_LINK_GITHUB"), GITHUB_URL)
		_add_link_button(links, tr("ABOUT_LINK_RELEASES"), AppVersion.get_releases_url())
		_add_link_button(links, tr("ABOUT_LINK_SERVER"), SERVER_URL)

	_sections_box.add_child(block)


func _apply_markdown_fonts(body_md: RichTextLabel) -> void:
	# Markdown `_underscores_` (e.g. THIRD_PARTY_…) and headings need the app face,
	# otherwise RichTextLabel falls back to a broken default/italic.
	var face: Font = null
	if theme:
		face = theme.get_font("font", "Label")
	if face == null:
		face = body_md.get_theme_font("normal_font")
	if face == null:
		face = ThemeDB.fallback_font
	if face == null:
		return
	body_md.add_theme_font_override("normal_font", face)
	body_md.add_theme_font_override("bold_font", face)
	body_md.add_theme_font_override("italics_font", face)
	body_md.add_theme_font_override("bold_italics_font", face)
	body_md.add_theme_font_override("mono_font", face)


func _add_link_button(parent: HBoxContainer, label: String, url: String) -> void:
	var btn := Button.new()
	btn.text = label
	btn.theme_type_variation = &"FlatButton"
	btn.custom_minimum_size = Vector2(0, 40)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(func() -> void:
		if url.strip_edges() != "":
			OS.shell_open(url)
	)
	parent.add_child(btn)
