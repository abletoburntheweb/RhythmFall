extends PanelContainer
class_name DiscoveryCard

signal try_pressed(mods: Array, params: Dictionary)

const ACCENT_GREEN := Color(0.55, 0.92, 0.62, 1.0)
const ACCENT_BLUE := Color(0.72, 0.78, 0.98, 1.0)
const ACCENT_PURPLE := Color(0.72, 0.62, 0.95, 1.0)
const ACCENT_ORANGE := Color(0.95, 0.70, 0.35, 1.0)
const TEXT_MUTED := Color(0.58, 0.64, 0.74, 0.92)
const TEXT_VALUE := Color(0.88, 0.92, 0.97, 1.0)
const DIFF_MARKER := "[DIFF]"

var _mods: Array = []
var _params: Dictionary = {}
var _category: String = ""
var _candidate: Dictionary = {}

func setup(candidate: Dictionary) -> void:
	_candidate = candidate
	_mods = candidate.get("mods", [])
	_params = candidate.get("params", {})
	_category = str(candidate.get("category", ""))
	var reason_key: String = str(candidate.get("reason_key", ""))
	var reason_args: Array = candidate.get("reason_args", [])

	if get_child_count() == 0:
		_build()

	_apply_border_color()

	var cat_label: Label = get_node_or_null("Margin/VBox/HeaderHBox/CategoryLabel") as Label
	var cat_icon: TextureRect = get_node_or_null("Margin/VBox/HeaderHBox/CategoryIcon") as TextureRect
	if cat_label:
		cat_label.text = _category_text(_category).to_upper()
		cat_label.add_theme_color_override("font_color", _category_color(_category))
	if cat_icon:
		var icon_file := _category_icon(_category)
		var tint := _category_color(_category)
		var tex := UiIconHelper.load_tinted_icon(icon_file, tint, 32)
		if tex:
			cat_icon.texture = tex

	var title_label: Label = get_node_or_null("Margin/VBox/TitleLabel") as Label
	if title_label:
		title_label.text = _build_title_text()
		title_label.add_theme_color_override("font_color", TEXT_VALUE)

	# Reason text
	var reason_label: Label = get_node_or_null("Margin/VBox/ReasonLabel") as Label
	var diff_slot: HBoxContainer = get_node_or_null("Margin/VBox/DiffSlot") as HBoxContainer
	if reason_label:
		var txt := tr(reason_key)
		if reason_args.size() > 0:
			txt = txt % reason_args
		var diff_rating: int = int(candidate.get("reason_difficulty", 0))
		# Clear old widget from diff_slot
		if diff_slot:
			for c in diff_slot.get_children():
				c.queue_free()
		if diff_rating > 0 and txt.contains(DIFF_MARKER):
			var parts := txt.split(DIFF_MARKER)
			reason_label.text = parts[0].strip_edges()
			if diff_slot:
				diff_slot.add_child(_make_difficulty_widget(diff_rating))
				diff_slot.visible = true
			if parts.size() > 1 and parts[1].strip_edges() != "":
				# Append rest of text after diff slot
				var after_lbl := Label.new()
				after_lbl.text = parts[1].strip_edges()
				after_lbl.add_theme_color_override("font_color", TEXT_MUTED)
				after_lbl.add_theme_font_size_override("font_size", 13)
				if diff_slot:
					diff_slot.add_child(after_lbl)
		else:
			reason_label.text = txt
			if diff_slot:
				diff_slot.visible = false

	var tags_row: HBoxContainer = get_node_or_null("Margin/VBox/TagsRow") as HBoxContainer
	if tags_row:
		for c in tags_row.get_children():
			c.queue_free()
		var tags := _get_tags_for_candidate(candidate)
		for tag_key in tags:
			var chip := _make_tag_chip(tr(tag_key))
			tags_row.add_child(chip)
		tags_row.visible = tags.size() > 0

	var btn: Button = get_node_or_null("Margin/VBox/TryButton") as Button
	if btn:
		btn.text = tr("MODREC_TRY_BUTTON")
		if not btn.pressed.is_connected(_on_try):
			btn.pressed.connect(_on_try)


func _build_title_text() -> String:
	if _mods.is_empty():
		return ""
	var names: Array[String] = []
	for mod_id in _mods:
		var key := RunModifiers.title_i18n_key(str(mod_id))
		var name := tr(key)
		if name == key or name.strip_edges() == "":
			name = RunModifiers.translate_abbr(str(mod_id))
		names.append(name)
	return " + ".join(names)


func _apply_border_color() -> void:
	var style: StyleBoxFlat = get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		return
	var cat_color := _category_color(_category)
	var new_style := style.duplicate() as StyleBoxFlat
	new_style.border_color = Color(cat_color.r, cat_color.g, cat_color.b, 0.5)
	new_style.set_border_width_all(2)
	add_theme_stylebox_override("panel", new_style)


func _category_text(cat: String) -> String:
	match cat:
		"fit": return tr("MODREC_CAT_FIT")
		"next": return tr("MODREC_CAT_NEXT")
		"combo": return tr("MODREC_CAT_COMBO")
		"challenge": return tr("MODREC_CAT_CHALLENGE")
		_: return cat


func _category_color(cat: String) -> Color:
	match cat:
		"fit": return ACCENT_GREEN
		"next": return ACCENT_BLUE
		"combo": return ACCENT_PURPLE
		"challenge": return ACCENT_ORANGE
		_: return TEXT_MUTED


func _category_icon(cat: String) -> String:
	match cat:
		"fit": return "circle-check.svg"
		"next": return "trending-up.svg"
		"combo": return "layers.svg"
		"challenge": return "flame.svg"
		_: return "sparkles.svg"


func _get_tags_for_candidate(cand: Dictionary) -> Array[String]:
	var cat: String = str(cand.get("category", ""))
	var tags: Array[String] = []
	match cat:
		"fit":
			tags.append("MODREC_TAG_ACCURACY")
			tags.append("MODREC_TAG_STABILITY")
		"next":
			tags.append("MODREC_TAG_PROGRESS")
			tags.append("MODREC_TAG_DIFFICULTY")
		"combo":
			tags.append("MODREC_TAG_COMBO")
			var mod_ids: Array = cand.get("mods", [])
			for m in mod_ids:
				var sid := str(m)
				if sid == "hidden" or sid == "sudden" or sid == "memory_mode" or sid == "spotlight":
					tags.append("MODREC_TAG_HIDDEN")
					break
		"challenge":
			tags.append("MODREC_TAG_DIFFICULTY")
	return tags


func _make_tag_chip(text: String) -> Control:
	var lbl := Label.new()
	lbl.text = text.to_lower()
	lbl.add_theme_color_override("font_color", TEXT_MUTED)
	lbl.add_theme_font_size_override("font_size", 12)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.14, 0.18, 0.24, 0.9)
	bg.border_color = Color(0.4, 0.44, 0.52, 0.3)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(4)
	bg.content_margin_left = 8
	bg.content_margin_right = 8
	bg.content_margin_top = 3
	bg.content_margin_bottom = 3
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", bg)
	panel.add_child(lbl)
	return panel


func _build() -> void:
	custom_minimum_size = Vector2(0, 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.108, 0.118, 0.158, 0.96)
	style.border_color = Color(1, 1, 1, 0.08)
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.shadow_color = Color(0, 0, 0, 0.28)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)
	# Header: category icon + category label
	var header := HBoxContainer.new()
	header.name = "HeaderHBox"
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)
	var icon := TextureRect.new()
	icon.name = "CategoryIcon"
	icon.custom_minimum_size = Vector2(22, 22)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(icon)
	var cat_lbl := Label.new()
	cat_lbl.name = "CategoryLabel"
	cat_lbl.add_theme_font_size_override("font_size", 12)
	cat_lbl.add_theme_color_override("font_color", ACCENT_GREEN)
	header.add_child(cat_lbl)
	# Title label
	var title_lbl := Label.new()
	title_lbl.name = "TitleLabel"
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", TEXT_VALUE)
	vbox.add_child(title_lbl)
	# Reason label (text only, widget goes in DiffSlot)
	var reason_lbl := Label.new()
	reason_lbl.name = "ReasonLabel"
	reason_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason_lbl.add_theme_font_size_override("font_size", 13)
	reason_lbl.add_theme_color_override("font_color", TEXT_MUTED)
	vbox.add_child(reason_lbl)
	# Diff slot (inline with reason text - separate row)
	var diff_slot := HBoxContainer.new()
	diff_slot.name = "DiffSlot"
	diff_slot.add_theme_constant_override("separation", 4)
	diff_slot.visible = false
	vbox.add_child(diff_slot)
	# Tags row
	var tags_row := HBoxContainer.new()
	tags_row.name = "TagsRow"
	tags_row.add_theme_constant_override("separation", 6)
	vbox.add_child(tags_row)
	# Try button
	var btn := Button.new()
	btn.name = "TryButton"
	btn.custom_minimum_size = Vector2(0, 34)
	btn.theme_type_variation = &"FlatButton"
	btn.add_theme_font_size_override("font_size", 13)
	vbox.add_child(btn)


func _on_try() -> void:
	if _mods.is_empty() and _candidate.has("difficulty"):
		var p := _params.duplicate()
		p["_difficulty_only"] = int(_candidate["difficulty"])
		try_pressed.emit(_mods, p)
	else:
		try_pressed.emit(_mods, _params)


func _make_difficulty_widget(rating: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tint := ChartDifficultyAnalyzer.rating_color_for_decimal(float(rating))
	row.add_child(UiIconHelper.make_icon_frame("zap.svg", 18, 12, tint))
	var lbl := Label.new()
	lbl.text = ChartDifficultyAnalyzer.format_decimal_rating(float(rating), false)
	lbl.add_theme_color_override("font_color", tint)
	lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(lbl)
	return row
