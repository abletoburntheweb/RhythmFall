# scenes/profile/components/instrument_stats_card.gd
extends PanelContainer
class_name InstrumentStatsCard

const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")
const _HERO_H := 108.0
const _FEATURED_KEYS := ["levels", "score"]
const _SECONDARY_KEYS := ["avg_acc", "sessions"]
const _ROW_KEYS := ["perfect", "combo", "hits", "misses"]

@onready var _hero_stack: Control = $RootVBox/HeroStack
@onready var _hero: Control = %HeroDraw
@onready var _hero_icon_badge: PanelContainer = %HeroIconBadge
@onready var _hero_icon: TextureRect = %HeroIcon
@onready var _title_label: Label = %TitleLabel
@onready var _desc_label: Label = %DescLabel
@onready var _featured_row: HBoxContainer = %FeaturedRow
@onready var _secondary_row: HBoxContainer = %SecondaryRow
@onready var _divider: ColorRect = %AccentDivider
@onready var _stats_caption: Label = %StatsCaptionLabel
@onready var _stats_rows: VBoxContainer = %StatsRowsVBox
@onready var _content_panel: PanelContainer = %ContentPanel

var instrument_id: String = ""
var _accent: Color = Color.WHITE


func setup(
	p_instrument_id: String,
	title_text: String,
	subtitle_text: String,
	icon_file: String,
	accent: Color,
	stats_rows: Array,
	stats_caption: String = ""
) -> void:
	instrument_id = p_instrument_id
	_accent = accent
	if _hero_stack:
		_hero_stack.custom_minimum_size = Vector2(0, _HERO_H)
	if _hero:
		_hero.offset_bottom = 100.0
	if _title_label:
		_title_label.text = title_text
		_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if _desc_label:
		_desc_label.text = subtitle_text
		_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if _stats_caption:
		_stats_caption.text = stats_caption if stats_caption != "" else tr("PROFILE_STAT_INSTR_PROGRESS_CAPTION")
		_stats_caption.add_theme_color_override("font_color", Color(0.62, 0.72, 0.84, 1.0))
	if _divider:
		_divider.color = Color(accent.r, accent.g, accent.b, 0.28)
	if _hero and _hero.has_method("configure"):
		var wash := accent.darkened(0.35)
		wash.a = 0.35
		_hero.configure(instrument_id, accent.darkened(0.12), wash, false)
	_apply_hero_icon(icon_file, accent)
	_populate_stats(stats_rows)
	if is_node_ready():
		_apply_card_style(accent)
	else:
		call_deferred("_apply_card_style", accent)


func _apply_hero_icon(icon_file: String, accent: Color) -> void:
	if _hero_icon == null:
		return
	_hero_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hero_icon.custom_minimum_size = Vector2(28, 28)
	_hero_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_hero_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hero_icon.texture = _UiIconHelper.load_tinted_icon(
		icon_file,
		accent.lightened(0.14),
		_UiIconHelper.raster_size_for_display(28)
	)


func _populate_stats(rows: Array) -> void:
	var by_key: Dictionary = {}
	for row in rows:
		if row is Dictionary:
			by_key[str((row as Dictionary).get("key", ""))] = row

	_refill_hbox(_featured_row, _FEATURED_KEYS, by_key, true)
	_refill_hbox(_secondary_row, _SECONDARY_KEYS, by_key, false)

	if _stats_rows == null:
		return
	for child in _stats_rows.get_children():
		child.queue_free()
	for key in _ROW_KEYS:
		if by_key.has(key):
			_stats_rows.add_child(_make_stat_row(by_key[key] as Dictionary))


func _refill_hbox(row: HBoxContainer, keys: Array, by_key: Dictionary, featured: bool) -> void:
	if row == null:
		return
	for child in row.get_children():
		child.queue_free()
	var added := 0
	for key in keys:
		if by_key.has(key):
			row.add_child(_make_stat_tile(by_key[key] as Dictionary, featured))
			added += 1
	row.visible = added > 0


func _make_stat_tile(row: Dictionary, featured: bool) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.custom_minimum_size = Vector2(0, 64 if featured else 56)

	var value_color: Color = row.get("value_color", _accent)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.09, 0.13, 1.0)
	box.border_color = Color(value_color.r, value_color.g, value_color.b, 0.34 if featured else 0.22)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	if featured:
		box.bg_color = Color(value_color.r, value_color.g, value_color.b, 0.08).lerp(
			Color(0.06, 0.08, 0.12, 1.0), 0.72
		)
	tile.add_theme_stylebox_override("panel", box)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	tile.add_child(vbox)

	var value := Label.new()
	value.text = _format_display(str(row.get("value", "0")), str(row.get("key", "")))
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	value.add_theme_font_size_override("font_size", 22 if featured else 18)
	value.add_theme_color_override("font_color", value_color)
	value.clip_text = true
	vbox.add_child(value)

	var caption := Label.new()
	caption.text = str(row.get("label", ""))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	caption.add_theme_font_size_override("font_size", 11)
	caption.add_theme_color_override("font_color", Color(0.62, 0.7, 0.82, 0.95))
	vbox.add_child(caption)
	return tile


func _make_stat_row(row: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_color: Color = row.get("value_color", Color.WHITE)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.09, 0.13, 0.92)
	box.border_color = Color(1, 1, 1, 0.06)
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", box)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	var label := Label.new()
	label.text = str(row.get("label", ""))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.68, 0.74, 0.84, 1.0))
	hbox.add_child(label)

	var value := Label.new()
	value.text = _format_display(str(row.get("value", "0")), str(row.get("key", "")))
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_size_override("font_size", 16)
	value.add_theme_color_override("font_color", value_color)
	hbox.add_child(value)
	return panel


func _format_display(raw: String, key: String) -> String:
	if key == "avg_acc":
		return raw if raw.contains("%") else raw + "%"
	if not raw.is_valid_int():
		return raw
	var n := int(raw)
	var negative := n < 0
	var s := str(absi(n))
	var out := ""
	var i := s.length()
	while i > 0:
		var start := maxi(0, i - 3)
		if out == "":
			out = s.substr(start, i - start)
		else:
			out = s.substr(start, i - start) + " " + out
		i = start
	return ("-" if negative else "") + out


func _apply_card_style(accent: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.07, 0.11, 0.98)
	box.border_color = accent.lerp(Color.WHITE, 0.12)
	box.set_border_width_all(2)
	box.set_corner_radius_all(14)
	box.content_margin_left = 0.0
	box.content_margin_right = 0.0
	box.content_margin_top = 0.0
	box.content_margin_bottom = 0.0
	box.shadow_color = Color(0, 0, 0, 0.32)
	box.shadow_size = 12
	box.shadow_offset = Vector2(0, 4)
	add_theme_stylebox_override("panel", box)

	if _content_panel:
		var content := StyleBoxFlat.new()
		content.bg_color = Color(0.06, 0.08, 0.12, 1.0)
		content.border_width_top = 1
		content.border_color = accent.lerp(Color.WHITE, 0.1)
		_content_panel.add_theme_stylebox_override("panel", content)

	if _hero_icon_badge:
		var badge := StyleBoxFlat.new()
		badge.bg_color = Color(0.06, 0.08, 0.12, 0.96)
		badge.set_border_width_all(0)
		badge.set_corner_radius_all(999)
		badge.set_content_margin_all(0)
		_hero_icon_badge.add_theme_stylebox_override("panel", badge)
		_hero_icon_badge.custom_minimum_size = Vector2(56, 56)
