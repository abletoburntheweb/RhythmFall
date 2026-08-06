extends VBoxContainer

const _ModifierIconStrip = preload("res://logic/ui/modifier_icon_strip.gd")
const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")
const _MarathonRouteBadges = preload("res://logic/domain/session/marathon_route_badges.gd")

const COLOR_CAPTION := Color(0.654902, 0.654902, 0.678431, 1)
const COLOR_VALUE := Color(0.784314, 0.823529, 0.901961, 1)
const COLOR_MUTED := Color(0.55, 0.58, 0.65, 0.92)
const COLOR_RR := Color(0.9490196, 0.7019608, 0.3529412, 1)


func apply_entry(
	caption: String,
	primary: String,
	secondary: String = "",
	value_text: String = "",
	value_color: Color = COLOR_RR,
	modifiers: Array = [],
	caption_icon_file: String = "",
	caption_icon_tint: Color = COLOR_CAPTION,
	value_as_zap_rating: bool = false
) -> void:
	_apply_caption_icon(caption_icon_file, caption_icon_tint)
	var cap := get_node_or_null("TopRow/CaptionLabel") as Label
	var val := get_node_or_null("TopRow/ValueLabel") as Label
	var primary_label := get_node_or_null("PrimaryLabel") as Label
	var secondary_label := get_node_or_null("SecondaryLabel") as Label
	var mods_row := get_node_or_null("ModsRow") as HBoxContainer
	var separator := get_node_or_null("Separator") as ColorRect
	var top := get_node_or_null("TopRow") as HBoxContainer
	var old_zap := get_node_or_null("TopRow/ValueZapRow")
	if old_zap:
		old_zap.queue_free()
	if cap:
		cap.text = caption
	if val:
		if value_as_zap_rating and value_text != "" and top:
			val.visible = false
			var zap_row := HBoxContainer.new()
			zap_row.name = "ValueZapRow"
			zap_row.alignment = BoxContainer.ALIGNMENT_END
			zap_row.add_theme_constant_override("separation", 4)
			zap_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			top.add_child(zap_row)
			zap_row.add_child(_UiIconHelper.make_icon_frame("zap.svg", 22, 13, value_color))
			var num := Label.new()
			num.text = value_text
			num.add_theme_font_size_override("font_size", 17)
			num.add_theme_color_override("font_color", value_color)
			zap_row.add_child(num)
		elif value_text != "":
			val.text = value_text
			val.add_theme_color_override("font_color", value_color)
			val.visible = true
		else:
			val.visible = false
	if primary_label:
		primary_label.text = primary
		primary_label.visible = primary != ""
	if secondary_label:
		secondary_label.text = secondary
		secondary_label.visible = secondary != ""
	if mods_row:
		# Keep chips readable: avoid sub-14px NEAREST downscale mush.
		_ModifierIconStrip.fill_slot_chips(mods_row, modifiers, {}, maxi(modifiers.size(), 1), true, 14, 8, 3, false)
		mods_row.visible = modifiers.size() > 0
	if separator:
		# Compact grid cells sit in PanelContainer — no trailing rule needed.
		separator.visible = not (get_parent() is PanelContainer)


func set_marathon_badge_chips(route_id: String, badges: Array, template: Dictionary) -> void:
	_clear_badges_row()
	if badges.is_empty():
		return
	var row := HBoxContainer.new()
	row.name = "BadgesRow"
	row.add_theme_constant_override("separation", 6)
	for tier in _MarathonRouteBadges.TIER_ORDER:
		if str(tier) not in badges:
			continue
		var tint := _MarathonRouteBadges.tier_accent(str(tier))
		var frame := _UiIconHelper.make_icon_frame(
			_MarathonRouteBadges.tier_icon_file(str(tier)),
			24,
			13,
			tint
		)
		frame.tooltip_text = _MarathonRouteBadges.medal_tooltip(route_id, str(tier), template)
		row.add_child(frame)
	if row.get_child_count() == 0:
		row.queue_free()
		return
	var secondary_label := get_node_or_null("SecondaryLabel") as Label
	var insert_idx := get_child_count()
	if secondary_label and secondary_label.get_index() >= 0:
		insert_idx = secondary_label.get_index() + 1
	add_child(row)
	move_child(row, insert_idx)


func _apply_caption_icon(icon_file: String, tint: Color) -> void:
	var top_row := get_node_or_null("TopRow") as HBoxContainer
	if top_row == null:
		return
	var existing := top_row.get_node_or_null("CaptionIcon") as Control
	if existing:
		top_row.remove_child(existing)
		existing.queue_free()
	# Legacy wrapper from older builds — remove if present.
	var legacy_host := top_row.get_node_or_null("CaptionIconHost") as Control
	if legacy_host:
		top_row.remove_child(legacy_host)
		legacy_host.queue_free()
	if icon_file.strip_edges() == "":
		return
	# Add the framed icon directly to the HBox so layout keeps it square.
	var frame := _UiIconHelper.make_icon_frame(icon_file, 26, 14, tint)
	frame.name = "CaptionIcon"
	top_row.add_child(frame)
	top_row.move_child(frame, 0)


func _clear_badges_row() -> void:
	var existing := get_node_or_null("BadgesRow")
	if existing:
		remove_child(existing)
		existing.queue_free()
