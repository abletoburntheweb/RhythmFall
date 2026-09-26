extends PanelContainer
class_name TriedRecommendationCard

const TEXT_MUTED := Color(0.58, 0.64, 0.74, 0.92)
const TEXT_VALUE := Color(0.88, 0.92, 0.97, 1.0)

var _mod_id: String = ""
var _attempts: int = 0
var _avg_accuracy: float = -1.0
var _best_rating: int = 0

func setup(mod_id: String, attempts: int, avg_accuracy: float, best_rating: int = 0) -> void:
	_mod_id = mod_id
	_attempts = attempts
	_avg_accuracy = _normalize_accuracy(avg_accuracy)
	_best_rating = best_rating
	_update_ui()


func _update_ui() -> void:
	if get_child_count() == 0:
		_build()

	var icon_frame: PanelContainer = get_node_or_null("Margin/VBox/HeaderRow/IconFrame") as PanelContainer
	if icon_frame:
		for c in icon_frame.get_children():
			c.queue_free()
		var icon_file := RunModifiers.icon_file(_mod_id)
		var tint := RunModifiers.category_tint(_mod_id)
		var icon_tex := UiIconHelper.load_tinted_icon(icon_file, tint, 20)
		if icon_tex:
			var center := CenterContainer.new()
			center.custom_minimum_size = Vector2(24, 24)
			var tex_rect := TextureRect.new()
			tex_rect.texture = icon_tex
			tex_rect.custom_minimum_size = Vector2(16, 16)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			center.add_child(tex_rect)
			icon_frame.add_child(center)
		var frame_style := StyleBoxFlat.new()
		frame_style.bg_color = Color(tint.r, tint.g, tint.b, 0.15)
		frame_style.set_corner_radius_all(12)
		frame_style.content_margin_left = 3
		frame_style.content_margin_right = 3
		frame_style.content_margin_top = 3
		frame_style.content_margin_bottom = 3
		icon_frame.add_theme_stylebox_override("panel", frame_style)

	var name_label: Label = get_node_or_null("Margin/VBox/HeaderRow/NameLabel") as Label
	if name_label:
		var key := RunModifiers.title_i18n_key(_mod_id)
		var name_text := tr(key)
		if name_text == key or name_text.strip_edges() == "":
			name_text = RunModifiers.translate_abbr(_mod_id)
		name_label.text = name_text
		name_label.add_theme_color_override("font_color", TEXT_VALUE)

	var attempts_label: Label = get_node_or_null("Margin/VBox/AttemptsLabel") as Label
	if attempts_label:
		attempts_label.text = tr("MODREC_TRIED_ATTEMPTS") % _attempts
		attempts_label.add_theme_color_override("font_color", TEXT_MUTED)

	var stats_row: HBoxContainer = get_node_or_null("Margin/VBox/StatsRow") as HBoxContainer
	if stats_row:
		for c in stats_row.get_children():
			c.queue_free()
		if _best_rating > 0:
			var rat_col := VBoxContainer.new()
			rat_col.add_theme_constant_override("separation", 1)
			var rat_title := Label.new()
			rat_title.text = tr("MODREC_TRIED_BEST_RATING")
			rat_title.add_theme_color_override("font_color", TEXT_MUTED)
			rat_title.add_theme_font_size_override("font_size", 9)
			rat_col.add_child(rat_title)
			var rat_widget := _make_difficulty_widget(_best_rating)
			rat_col.add_child(rat_widget)
			stats_row.add_child(rat_col)
		if _avg_accuracy >= 0.0:
			var acc_col := VBoxContainer.new()
			acc_col.add_theme_constant_override("separation", 1)
			var acc_title := Label.new()
			acc_title.text = tr("MODREC_TRIED_AVG_ACC")
			acc_title.add_theme_color_override("font_color", TEXT_MUTED)
			acc_title.add_theme_font_size_override("font_size", 9)
			acc_col.add_child(acc_title)
			var acc_val := Label.new()
			acc_val.text = "%.1f%%" % _avg_accuracy
			acc_val.add_theme_color_override("font_color", TEXT_VALUE)
			acc_val.add_theme_font_size_override("font_size", 13)
			acc_col.add_child(acc_val)
			stats_row.add_child(acc_col)


static func _normalize_accuracy(raw: float) -> float:
	if raw < 0.0:
		return raw
	if raw >= 0.0 and raw <= 1.5:
		return clampf(raw * 100.0, 0.0, 100.0)
	if raw > 1000.0:
		return clampf(raw / 100.0, 0.0, 100.0)
	return clampf(raw, 0.0, 100.0)


func _make_difficulty_widget(rating: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tint := ChartDifficultyAnalyzer.rating_color_for_decimal(float(rating))
	row.add_child(UiIconHelper.make_icon_frame("zap.svg", 14, 9, tint))
	var lbl := Label.new()
	lbl.text = ChartDifficultyAnalyzer.format_decimal_rating(float(rating), false)
	lbl.add_theme_color_override("font_color", tint)
	lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(lbl)
	return row


func _build() -> void:
	custom_minimum_size = Vector2(0, 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_stretch_ratio = 1.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.108, 0.118, 0.158, 0.96)
	style.border_color = Color(1, 1, 1, 0.08)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(0, 0, 0, 0.22)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 1)
	add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)
	# Header row: icon + name
	var header_row := HBoxContainer.new()
	header_row.name = "HeaderRow"
	header_row.add_theme_constant_override("separation", 6)
	vbox.add_child(header_row)
	var icon_frame := PanelContainer.new()
	icon_frame.name = "IconFrame"
	icon_frame.custom_minimum_size = Vector2(24, 24)
	header_row.add_child(icon_frame)
	var name_lbl := Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", TEXT_VALUE)
	header_row.add_child(name_lbl)
	# Attempts label
	var attempts_lbl := Label.new()
	attempts_lbl.name = "AttemptsLabel"
	attempts_lbl.add_theme_font_size_override("font_size", 10)
	attempts_lbl.add_theme_color_override("font_color", TEXT_MUTED)
	vbox.add_child(attempts_lbl)
	# Stats row: best rating + accuracy
	var stats_row := HBoxContainer.new()
	stats_row.name = "StatsRow"
	stats_row.add_theme_constant_override("separation", 12)
	vbox.add_child(stats_row)
