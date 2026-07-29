# scenes/profile/share/profile_share_card_base.gd
class_name ProfileShareCardBase
extends PanelContainer

signal card_pressed(card_id: String)

const _Snapshot = preload("res://scenes/profile/share/profile_share_snapshot.gd")
const _Wrapped  = preload("res://scenes/profile/share/profile_share_wrapped_style.gd")
const _GenrePortrait = preload("res://logic/domain/profile/profile_genre_portrait.gd")
const GradeDisplay = preload("res://logic/ui/grade_display.gd")
const ChartDifficultyAnalyzer = preload("res://logic/domain/charts/chart_difficulty_analyzer.gd")

const EXPORT_SIZE := Vector2i(1080, 1920)
const DEFAULT_PREVIEW_SCALE := 0.19

const _SEL_BORDER := Color(0.98, 0.86, 0.52, 0.95)
const _MUTED  := Color(0.58, 0.64, 0.74, 0.95)
const _TEXT   := Color(0.94, 0.95, 0.98, 1.0)

var card_id: String = ""
var hotkey_index: int = 0
var _selected := false
var _for_export := false
var _scale  := 1.0
var _preview_scale := DEFAULT_PREVIEW_SCALE

@onready var _hotkey_label:        Label         = %HotkeyLabel
@onready var _card_index_label:    Label         = %CardIndexLabel
@onready var _wrapped_brand_label: Label         = %WrappedBrandLabel
@onready var _hero_title:          Label         = %HeroTitle
@onready var _hero_accent_line:    ColorRect     = %HeroAccentLine
@onready var _content_vbox:        VBoxContainer = %ContentVBox
@onready var _logo_rect:           TextureRect   = %LogoRect
@onready var _footer_site_label:   Label         = %FooterSiteLabel
@onready var _footer_date_label:   Label         = %FooterDateLabel
@onready var _click_button:        Button        = %ClickButton
@onready var _bg_fill:             ColorRect     = %BgFill
@onready var _glow_a:              ColorRect     = %GlowA
@onready var _glow_b:              ColorRect     = %GlowB
@onready var _main_margin:         MarginContainer = %MainMargin
@onready var _main_vbox:           VBoxContainer   = %MainVBox


func _ready() -> void:
	clip_contents = true
	if not _click_button.pressed.is_connected(_on_click_button_pressed):
		_click_button.pressed.connect(_on_click_button_pressed)
	_load_logo()
	_apply_panel_style()
	_apply_wrapped_shell()


func setup(p_hotkey_index: int) -> void:
	hotkey_index = p_hotkey_index
	if is_node_ready():
		_apply_hotkey_label()
		_apply_panel_style()
		_apply_wrapped_shell()


func apply_data(data: Dictionary, for_export: bool = false, preview_scale: float = -1.0) -> void:
	_for_export = for_export
	_preview_scale = preview_scale if preview_scale > 0.0 else DEFAULT_PREVIEW_SCALE
	_scale = 1.0 if for_export else _preview_scale

	var card_size := _card_size()
	custom_minimum_size = card_size
	size = card_size

	if for_export:
		size_flags_horizontal = Control.SIZE_FILL
		size_flags_vertical   = Control.SIZE_FILL
	else:
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		size_flags_vertical   = Control.SIZE_SHRINK_BEGIN

	_apply_layout_overrides()
	_apply_hotkey_label()
	_apply_panel_style()
	_apply_wrapped_shell()
	_apply_footer(data)
	_apply_card_content(data)


func set_selected(selected: bool) -> void:
	_selected = selected
	_apply_panel_style()


func get_export_size() -> Vector2i:
	return EXPORT_SIZE


func apply_locale() -> void:
	if card_id == "":
		return
	_apply_wrapped_shell()
	_apply_card_content(_Snapshot.build_card(card_id))


func _get_minimum_size() -> Vector2:
	return _card_size()


func _apply_card_content(_data: Dictionary) -> void:
	pass


# ---------- helpers ----------

func _card_size() -> Vector2:
	return Vector2(EXPORT_SIZE) * _scale


func _accent() -> Color:
	return _Snapshot.CARD_ACCENT_COLORS.get(card_id, Color.WHITE)


## Integer dimension/size at current scale (floor 1)
func _fs(base: int) -> int:
	return maxi(1, int(round(float(base) * _scale)))


## Font size at current scale (floor 8)
func _fnt(base: int) -> int:
	return maxi(8, int(round(float(base) * _scale)))


func _hero_locale_key() -> String:
	match card_id:
		"overview":   return "PROFILE_SHARE_WRAPPED_OVERVIEW"
		"statistics": return "PROFILE_SHARE_WRAPPED_STATISTICS"
		"music":      return "PROFILE_SHARE_WRAPPED_MUSIC"
		"records":    return "PROFILE_SHARE_WRAPPED_RECORDS"
	return "PROFILE_SHARE_WRAPPED_OVERVIEW"


# ---------- layout overrides ----------

func _apply_layout_overrides() -> void:
	if _main_margin:
		_main_margin.add_theme_constant_override("margin_left",   _fs(36))
		_main_margin.add_theme_constant_override("margin_top",    _fs(32))
		_main_margin.add_theme_constant_override("margin_right",  _fs(36))
		_main_margin.add_theme_constant_override("margin_bottom", _fs(28))
	if _main_vbox:
		_main_vbox.add_theme_constant_override("separation", _fs(14))
	if _content_vbox:
		_content_vbox.add_theme_constant_override("separation", _fs(12))


func _apply_wrapped_shell() -> void:
	if _card_index_label:
		_card_index_label.text = _Wrapped.card_index_label(hotkey_index)
		_card_index_label.add_theme_font_size_override("font_size", _fnt(20))
	if _wrapped_brand_label:
		_wrapped_brand_label.text = tr("PROFILE_SHARE_RECAP_BRAND")
		_wrapped_brand_label.add_theme_font_size_override("font_size", _fnt(18))
	if _hero_title:
		_set_label(_hero_title, tr(_hero_locale_key()).to_upper(), 52, _accent())
	if _hero_accent_line:
		_hero_accent_line.color = Color(_accent().r, _accent().g, _accent().b, 0.85)
		_hero_accent_line.custom_minimum_size = Vector2(_fs(120), maxf(1.0, _fs(4)))

	var palette: Dictionary = _Wrapped.CARD_GRADIENTS.get(card_id, _Wrapped.CARD_GRADIENTS["overview"])
	if _bg_fill:
		_bg_fill.color = palette.get("bg", Color(0.04, 0.03, 0.08))
	_apply_glow_layout(palette)


func _apply_glow_layout(palette: Dictionary) -> void:
	var cs := _card_size()   # actual card size at current scale
	if _glow_a:
		_glow_a.color = palette.get("glow_a", Color(1, 1, 1, 0.25))
		_glow_a.size     = Vector2(_fs(420), _fs(420))
		_glow_a.position = Vector2(cs.x * 0.52, -_fs(80))
	if _glow_b:
		_glow_b.color = palette.get("glow_b", Color(1, 1, 1, 0.15))
		_glow_b.size     = Vector2(_fs(360), _fs(360))
		_glow_b.position = Vector2(-_fs(100), cs.y * 0.58)


func _apply_hotkey_label() -> void:
	if _hotkey_label == null:
		return
	_hotkey_label.visible = not _for_export
	if not _for_export:
		_hotkey_label.text = "[%d]" % (hotkey_index + 1)
		_hotkey_label.add_theme_font_size_override("font_size", _fnt(18))


func _apply_footer(data: Dictionary) -> void:
	if _footer_site_label:
		_footer_site_label.text = tr("PROFILE_SHARE_FOOTER_SITE")
		_footer_site_label.add_theme_font_size_override("font_size", _fnt(16))
	if _footer_date_label:
		_footer_date_label.text = str(data.get("footer_date", ""))
		_footer_date_label.add_theme_font_size_override("font_size", _fnt(16))
	if _logo_rect:
		_logo_rect.custom_minimum_size = Vector2(_fs(22), _fs(22))


func _apply_panel_style() -> void:
	var accent := _accent()
	var box    := StyleBoxFlat.new()
	box.bg_color     = Color(0, 0, 0, 0)
	box.border_color = _SEL_BORDER if _selected and not _for_export \
	                   else Color(accent.r, accent.g, accent.b, 0.55)
	box.set_border_width_all(maxi(1, _fs(4)) if _selected and not _for_export \
	                         else maxi(1, _fs(2)))
	box.set_corner_radius_all(_fs(22))
	box.content_margin_left   = 0
	box.content_margin_right  = 0
	box.content_margin_top    = 0
	box.content_margin_bottom = 0
	add_theme_stylebox_override("panel", box)


func _load_logo() -> void:
	if _logo_rect == null:
		return
	var path := "res://assets/app_icons/rf.png"
	if ResourceLoader.exists(path):
		_logo_rect.texture = load(path)
	_logo_rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	_logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func _glass_style() -> StyleBoxFlat:
	return _Wrapped.glass_style(_accent(), _scale)


func _hero_glass_style() -> StyleBoxFlat:
	return _Wrapped.hero_chip_style(_accent(), _scale)


func _apply_glass_panel(panel: PanelContainer, use_hero: bool = false) -> void:
	if panel == null:
		return
	panel.add_theme_stylebox_override("panel",
		_hero_glass_style() if use_hero else _glass_style())


func _set_section_header(label: Label, text: String) -> void:
	if label == null:
		return
	_set_label(label, text.to_upper(), 20, _accent())


func _apply_chip(panel: PanelContainer, caption: String, value: String,
		value_color: Color = _TEXT, value_size: int = 28, caption_size: int = 16) -> void:
	if panel == null:
		return
	_apply_glass_panel(panel)
	var val_lbl := panel.get_node_or_null("VBox/ValueLabel")   as Label
	var cap_lbl := panel.get_node_or_null("VBox/CaptionLabel") as Label
	if val_lbl:
		_set_label(val_lbl, value,   value_size,   value_color)
	if cap_lbl:
		_set_label(cap_lbl, caption, caption_size, _MUTED)


func _apply_record_row(panel: PanelContainer, caption: String, value: String,
		value_color: Color = _TEXT) -> void:
	if panel == null:
		return
	_apply_glass_panel(panel)
	var cap_lbl := panel.get_node_or_null("HBox/CaptionLabel") as Label
	var val_lbl := panel.get_node_or_null("HBox/ValueLabel")   as Label
	if cap_lbl:
		_set_label(cap_lbl, caption, 18, _MUTED)
	if val_lbl:
		_set_label(val_lbl, value,   24, value_color)


func _apply_milestone_chip(panel: PanelContainer, caption: String, unlocked: bool) -> void:
	if panel == null:
		return
	panel.add_theme_stylebox_override("panel",
		_Wrapped.milestone_style(_accent(), unlocked, _scale))
	panel.modulate = Color(1, 1, 1, 1) if unlocked else Color(1, 1, 1, 0.42)
	var title_lbl := panel.get_node_or_null("VBox/TitleLabel") as Label
	var mark_lbl  := panel.get_node_or_null("VBox/MarkLabel")  as Label
	if title_lbl:
		_set_label(title_lbl, caption, 14,
			_accent() if unlocked else _MUTED)
	if mark_lbl:
		_set_label(mark_lbl, "★" if unlocked else "·", 26,
			_accent() if unlocked else _MUTED)


func _set_label(label: Label, text: String, base_size: int,
		color: Color = _TEXT) -> void:
	if label == null:
		return
	label.text = text
	label.add_theme_font_size_override("font_size", _fnt(base_size))
	label.add_theme_color_override("font_color", color)


func _scale_label(label: Label, base_size: int) -> void:
	if label == null:
		return
	label.add_theme_font_size_override("font_size", _fnt(base_size))


func _group_label(group_id: String) -> String:
	if group_id == "" or group_id == "_other":
		return tr("PROFILE_GENRE_GRP_OTHER")
	var key   := _GenrePortrait.group_locale_key(group_id)
	var label := tr(key)
	if label == key:
		return group_id.replace("_", " ")
	return label


func _format_play_time(time_str: String) -> String:
	var parts   := time_str.split(":")
	var hours   := 0
	var minutes := 0
	if parts.size() >= 2:
		hours   = int(parts[0])
		minutes = int(parts[1])
	return tr("PROFILE_PLAY_TIME_FMT") % [hours, minutes]


func _fmt_int(value: int) -> String:
	if value >= 1_000_000:
		return "%.1fM" % (float(value) / 1_000_000.0)
	if value >= 10_000:
		return "%.1fk" % (float(value) / 1_000.0)
	return str(value)


func _format_extreme(entry: Dictionary, kind: String) -> String:
	match kind:
		"percent":  return "%.2f%%" % float(entry.get("value", 0.0))
		"rating":   return ChartDifficultyAnalyzer.format_average_rating(
		                       float(entry.get("value", 0.0)))
		"int":      return str(int(entry.get("value", 0)))
		"bpm":      return "%d BPM" % int(entry.get("value", 0))
		"duration":
			var sec := int(entry.get("value", 0))
			return "%02d:%02d" % [sec / 60, sec % 60]
	return ""


func _style_progress(bar: ProgressBar, accent: Color = Color()) -> void:
	if bar == null:
		return
	bar.custom_minimum_size.y = _fs(14)
	bar.show_percentage = false
	var fill_color := accent if accent != Color() else _accent()
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(_fs(6))
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.12)
	bg.set_corner_radius_all(_fs(6))
	bar.add_theme_stylebox_override("background", bg)


func _on_click_button_pressed() -> void:
	if card_id == "":
		return
	card_pressed.emit(card_id)
