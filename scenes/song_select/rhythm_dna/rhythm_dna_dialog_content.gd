# scenes/song_select/rhythm_dna_dialog_content.gd
extends RefCounted
class_name RhythmDnaDialogContent

const _View = preload("res://logic/data/rhythm_dna_view.gd")
const _TimelinePanelScene = preload("res://scenes/song_select/rhythm_dna/rhythm_dna_timeline_panel.gd")

const COLOR_SECTION := Color(0.42, 0.58, 0.82, 1)
const COLOR_BODY := Color(0.86, 0.9, 0.96, 0.96)
const COLOR_MUTED := Color(0.62, 0.68, 0.76, 0.92)
const COLOR_REMOVE := Color(0.91, 0.45, 0.38, 1)
const COLOR_ADD := Color(0.38, 0.78, 0.74, 1)
const COLOR_SAVE := Color(0.45, 0.68, 0.95, 1)
const COLOR_WARN := Color(0.95, 0.78, 0.35, 1)
const COLOR_CONFIDENCE := Color(0.75, 0.55, 0.95, 1)
const NARROW_VIEWPORT_WIDTH := 1040.0
const LIST_ICON_SLOT := 22

const DECISION_ICON_SPECS := {
	"DNA_DEC_SECTION_PASS": ["eraser.svg", COLOR_REMOVE],
	"DNA_DEC_SALIENCE": ["arrow-down-narrow-wide.svg", COLOR_REMOVE],
	"DNA_DEC_FILL_ZONE": ["sparkles.svg", COLOR_ADD],
	"DNA_DEC_DRUM_ENTRY": ["circle-play.svg", COLOR_ADD],
	"DNA_DEC_PLAYABILITY": ["ban.svg", COLOR_REMOVE],
	"DNA_DEC_CLUSTER": ["layers.svg", COLOR_REMOVE],
	"DNA_DEC_MINIMAL": ["check.svg", UiIconHelper.MUTED],
}

const DECISION_HINT_FALLBACK := {
	"DNA_DEC_SECTION_PASS": "DNA_HINT_REMOVED_SECTION",
	"DNA_DEC_SALIENCE": "DNA_HINT_REMOVED_SALIENCE",
	"DNA_DEC_FILL_ZONE": "DNA_HINT_ADDED_FILL",
	"DNA_DEC_DRUM_ENTRY": "DNA_HINT_ADDED_ENTRY",
	"DNA_DEC_PLAYABILITY": "DNA_HINT_REMOVED_PLAYABILITY",
	"DNA_DEC_CLUSTER": "DNA_HINT_REMOVED_CLUSTER",
}


static func _tr(key: String) -> String:
	return TranslationServer.translate(key)


static func _shrink_vertical(control: Control) -> void:
	control.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


static func _apply_tooltip(control: Control, text: String) -> void:
	var tip := text.strip_edges()
	if tip == "":
		return
	control.tooltip_text = tip
	control.mouse_filter = Control.MOUSE_FILTER_STOP


static func build(dna: Dictionary, cover: Texture2D = null, viewport_width: float = 1280.0) -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shrink_vertical(root)
	if dna.is_empty():
		root.add_child(_body_label(_tr("DNA_EMPTY"), COLOR_MUTED, 15))
		return root
	root.add_child(_build_summary_card(dna, cover))
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.0
	_shrink_vertical(left)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	_shrink_vertical(right)
	_build_left_column(left, dna)
	_build_right_column(right, dna)
	if viewport_width < NARROW_VIEWPORT_WIDTH:
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 12)
		stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_shrink_vertical(stack)
		stack.add_child(left)
		stack.add_child(right)
		root.add_child(stack)
	else:
		var columns := HBoxContainer.new()
		columns.add_theme_constant_override("separation", 14)
		columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_shrink_vertical(columns)
		columns.alignment = BoxContainer.ALIGNMENT_BEGIN
		columns.add_child(left)
		columns.add_child(right)
		root.add_child(columns)
	root.add_child(_build_footer_card())
	return root


static func _build_summary_card(dna: Dictionary, cover: Texture2D) -> Control:
	var track: Dictionary = dna.get("track", {}) if dna.get("track", {}) is Dictionary else {}
	var pipeline: Dictionary = dna.get("pipeline", {}) if dna.get("pipeline", {}) is Dictionary else {}
	var genes: Dictionary = dna.get("genes", {}) if dna.get("genes", {}) is Dictionary else {}
	var confidence: Dictionary = genes.get("confidence", {}) if genes.get("confidence", {}) is Dictionary else {}
	var panel := _inner_panel()
	_shrink_vertical(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shrink_vertical(row)
	panel.add_child(row)
	if cover:
		row.add_child(_cover_frame(cover))
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shrink_vertical(info)
	var title := String(track.get("title", "")).strip_edges()
	var artist := String(track.get("artist", "")).strip_edges()
	if artist != "" and title != "":
		info.add_child(_body_label(_tr("DNA_TRACK_FMT") % [artist, title], COLOR_BODY, 21))
	elif title != "":
		info.add_child(_body_label(title, COLOR_BODY, 21))
	elif artist != "":
		info.add_child(_body_label(artist, COLOR_BODY, 21))
	var meta_bits: PackedStringArray = []
	var genre := String(track.get("genre", "")).strip_edges()
	if genre != "":
		meta_bits.append(_tr("DNA_META_GENRE_FMT") % genre)
	var preset := _View.format_chart_preset(track)
	if preset != "":
		meta_bits.append(preset)
	var lanes := int(track.get("lanes", 0))
	if lanes >= 3:
		meta_bits.append(_tr("DNA_UI_LANES_FMT") % lanes)
	var bpm := float(track.get("bpm", 0.0))
	if bpm > 0.0:
		meta_bits.append(_tr("DNA_META_BPM_FMT") % int(round(bpm)))
	var final_notes := int(pipeline.get("final_notes", 0))
	if final_notes > 0:
		meta_bits.append(_tr("DNA_UI_NOTES_FMT") % final_notes)
	if meta_bits.size() > 0:
		info.add_child(_body_label(" · ".join(meta_bits), COLOR_MUTED, 14))
	row.add_child(info)
	var overall := int(confidence.get("overall", 0))
	if overall > 0:
		row.add_child(_build_confidence_badge(overall))
	return panel


static func _cover_frame(texture: Texture2D) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(76, 76)
	_shrink_vertical(frame)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.08, 1)
	style.border_color = Color(1, 1, 1, 0.12)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 3.0
	style.content_margin_top = 3.0
	style.content_margin_right = 3.0
	style.content_margin_bottom = 3.0
	frame.add_theme_stylebox_override("panel", style)
	var tex_rect := TextureRect.new()
	tex_rect.texture = texture
	tex_rect.custom_minimum_size = Vector2(70, 70)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	frame.add_child(tex_rect)
	return frame


static func _build_confidence_badge(overall: int) -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 2)
	wrap.size_flags_horizontal = Control.SIZE_SHRINK_END
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	_shrink_vertical(wrap)
	wrap.add_child(_fixed_label("%d%%" % overall, COLOR_CONFIDENCE, 32, HORIZONTAL_ALIGNMENT_CENTER))
	var cap := _fixed_label(_tr("DNA_UI_ANALYSIS_CONFIDENCE"), COLOR_MUTED, 12, HORIZONTAL_ALIGNMENT_CENTER)
	_apply_tooltip(cap, _tr("DNA_CONFIDENCE_OVERALL_TIP"))
	wrap.add_child(cap)
	return wrap


static func _build_left_column(parent: VBoxContainer, dna: Dictionary) -> void:
	var found: Array = dna.get("found", []) if dna.get("found", []) is Array else []
	if found.size() > 0:
		_add_section_block(
			parent,
			"1",
			_tr("DNA_SECTION_FOUND"),
			"sparkles.svg",
			UiIconHelper.ACCENT,
			_found_list_card(found)
		)
	_add_section_block(
		parent,
		"2",
		_tr("DNA_UI_TRACK_STRUCTURE"),
		"layers-2.svg",
		UiIconHelper.ACCENT,
		_structure_section_card(dna)
	)
	var pipeline: Dictionary = dna.get("pipeline", {}) if dna.get("pipeline", {}) is Dictionary else {}
	var decisions: Array = dna.get("decisions", []) if dna.get("decisions", []) is Array else []
	if not pipeline.is_empty():
		_add_section_block(parent, "3", _tr("DNA_SECTION_PIPELINE"), "activity.svg", UiIconHelper.ACCENT, _pipeline_card(pipeline))
		_add_section_block(
			parent,
			"4",
			_tr("DNA_UI_WHAT_I_DID"),
			"blend.svg",
			UiIconHelper.ACCENT,
			_action_cards_row(pipeline, decisions)
		)
	if decisions.size() > 0:
		_add_section_block(
			parent,
			"5",
			_tr("DNA_SECTION_DECISIONS"),
			"list-checks.svg",
			UiIconHelper.ACCENT,
			_decision_list_card(decisions)
		)


static func _build_right_column(parent: VBoxContainer, dna: Dictionary) -> void:
	var genes: Dictionary = dna.get("genes", {}) if dna.get("genes", {}) is Dictionary else {}
	var rhythm: Dictionary = genes.get("rhythm", {}) if genes.get("rhythm", {}) is Dictionary else {}
	var structure: Dictionary = genes.get("structure", {}) if genes.get("structure", {}) is Dictionary else {}
	var measure_map: Dictionary = dna.get("measure_map", {}) if dna.get("measure_map", {}) is Dictionary else {}
	if not rhythm.is_empty() or not structure.is_empty() or not measure_map.is_empty():
		_add_section_block(
			parent,
			"",
			_tr("DNA_UI_TRACK_GENES"),
			"fingerprint-pattern.svg",
			COLOR_CONFIDENCE,
			_genes_card(rhythm, structure, measure_map, dna)
		)
	var confidence: Dictionary = genes.get("confidence", {}) if genes.get("confidence", {}) is Dictionary else {}
	if not confidence.is_empty():
		_add_section_block(
			parent,
			"",
			_tr("DNA_SECTION_CONFIDENCE"),
			"gauge.svg",
			COLOR_CONFIDENCE,
			_confidence_card(confidence)
		)
	var warnings: Array = dna.get("warnings", []) if dna.get("warnings", []) is Array else []
	if warnings.size() > 0:
		_add_section_block(
			parent,
			"",
			_tr("DNA_SECTION_WARNINGS"),
			"triangle-alert.svg",
			COLOR_WARN,
			_warnings_card(warnings)
		)


static func _add_section_block(
	parent: VBoxContainer,
	number: String,
	title: String,
	icon_file: String,
	tint: Color,
	content: Control
) -> void:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 6)
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shrink_vertical(block)
	block.add_child(_section_header(number, title, icon_file, tint))
	block.add_child(content)
	parent.add_child(block)


static func _build_footer_card() -> Control:
	var panel := _inner_panel(Color(0.07, 0.09, 0.13, 0.92))
	_shrink_vertical(panel)
	panel.add_child(_icon_text_row("info.svg", UiIconHelper.ACCENT, _tr("DNA_FOOTER"), COLOR_MUTED, 13))
	return panel


static func _section_header(number: String, title: String, icon_file: String, tint: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shrink_vertical(row)
	if number != "":
		row.add_child(_fixed_label(number + ".", COLOR_SECTION, 13, HORIZONTAL_ALIGNMENT_LEFT, 18.0))
	var icon := UiIconHelper.make_texture_rect(UiIconHelper.load_tinted_icon(icon_file, tint), 16)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var clean_title := title.strip_edges().trim_suffix(":").strip_edges()
	row.add_child(_body_label(clean_title.to_upper(), COLOR_SECTION, 13))
	return row


static func _found_list_card(items: Array) -> Control:
	var panel := _inner_panel()
	_shrink_vertical(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_shrink_vertical(vbox)
	panel.add_child(vbox)
	for item in items:
		var line := _View.format_item(item)
		if line == "":
			continue
		vbox.add_child(_icon_text_row("circle-check.svg", UiIconHelper.ACCENT, line, COLOR_BODY, 14))
	return panel


static func _decision_list_card(items: Array) -> Control:
	var panel := _inner_panel()
	_shrink_vertical(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_shrink_vertical(vbox)
	panel.add_child(vbox)
	for item in items:
		var line := _View.format_item(item)
		if line == "":
			continue
		var key := String(item.get("key", "")) if item is Dictionary else ""
		var spec: Array = DECISION_ICON_SPECS.get(key, ["list-checks.svg", UiIconHelper.ACCENT])
		vbox.add_child(_icon_text_row(String(spec[0]), spec[1], line, COLOR_BODY, 14))
	return panel


static func _icon_text_row(icon_file: String, tint: Color, text: String, color: Color, font_size: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shrink_vertical(row)
	var slot := CenterContainer.new()
	slot.custom_minimum_size = Vector2(LIST_ICON_SLOT, LIST_ICON_SLOT)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon := UiIconHelper.make_texture_rect(UiIconHelper.load_tinted_icon(icon_file, tint), 15)
	slot.add_child(icon)
	row.add_child(slot)
	row.add_child(_body_label(text, color, font_size))
	return row


static func _structure_section_card(dna: Dictionary) -> Control:
	var timeline: Array = dna.get("structure_timeline", []) if dna.get("structure_timeline", []) is Array else []
	if timeline.is_empty():
		return _structure_placeholder_card()
	var track: Dictionary = dna.get("track", {}) if dna.get("track", {}) is Dictionary else {}
	return _structure_timeline_card(timeline, float(track.get("bpm", 0.0)))


static func _structure_timeline_card(timeline: Array, bpm: float) -> Control:
	var panel := _inner_panel()
	_shrink_vertical(panel)
	var total_duration := 0.0
	for seg in timeline:
		if seg is Dictionary:
			total_duration = maxf(total_duration, float(seg.get("end_s", 0.0)))
	if total_duration <= 0.0 and bpm > 0.0:
		total_duration = float(timeline.size()) * (60.0 / bpm) * 4.0
	total_duration = maxf(total_duration, 1.0)
	var host := _TimelinePanelScene.new() as RhythmDnaTimelinePanel
	host.setup(timeline, total_duration)
	panel.add_child(host)
	return panel


static func build_timeline_bar(timeline: Array, total_duration: float) -> Control:
	var wrap := PanelContainer.new()
	_shrink_vertical(wrap)
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.04, 0.05, 0.08, 1)
	bar_style.set_corner_radius_all(6)
	bar_style.content_margin_left = 2.0
	bar_style.content_margin_top = 2.0
	bar_style.content_margin_right = 2.0
	bar_style.content_margin_bottom = 2.0
	wrap.add_theme_stylebox_override("panel", bar_style)
	wrap.custom_minimum_size = Vector2(0, 18)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shrink_vertical(row)
	wrap.add_child(row)
	for seg in timeline:
		if not seg is Dictionary:
			continue
		var start_s := float(seg.get("start_s", 0.0))
		var end_s := float(seg.get("end_s", start_s))
		var span: float = maxf(0.05, end_s - start_s)
		var block := ColorRect.new()
		block.color = _segment_color(String(seg.get("kind", "steady")))
		block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		block.size_flags_stretch_ratio = span / total_duration
		block.custom_minimum_size = Vector2(4, 14)
		row.add_child(block)
	return wrap


static func build_timeline_row(seg: Dictionary) -> Control:
	var kind := String(seg.get("kind", "steady"))
	var row_panel := PanelContainer.new()
	row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shrink_vertical(row_panel)
	if kind == "loud_quiet":
		row_panel.add_theme_stylebox_override("panel", _warn_row_style())
	else:
		row_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shrink_vertical(row)
	row_panel.add_child(row)
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(8, 8)
	dot.color = _segment_color(kind)
	row.add_child(dot)
	var start_s := float(seg.get("start_s", 0.0))
	var end_s := float(seg.get("end_s", start_s))
	var label_key := String(seg.get("label_key", "DNA_SEG_STEADY"))
	var notes := int(seg.get("notes", 0))
	var time_text := "%s – %s" % [_format_time(start_s), _format_time(end_s)]
	var detail := _tr(label_key)
	var role := String(seg.get("role", ""))
	if role != "":
		var role_key := "DNA_ROLE_%s" % role.to_upper()
		detail += " · " + _tr(role_key)
	if notes > 0:
		detail += " · " + (_tr("DNA_UI_TIMELINE_NOTES_FMT") % notes)
	var label := _body_label("%s  %s" % [time_text, detail], COLOR_BODY, 13)
	if kind == "loud_quiet":
		_apply_tooltip(row_panel, _tr("DNA_UI_TIMELINE_LOUD_QUIET_TIP"))
	row.add_child(label)
	return row_panel


static func _warn_row_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.11, 0.06, 0.55)
	style.border_color = Color(0.95, 0.78, 0.35, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8.0
	style.content_margin_top = 6.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 6.0
	return style


static func _timeline_row(seg: Dictionary) -> Control:
	return build_timeline_row(seg)


static func _segment_color(kind: String) -> Color:
	match kind:
		"quiet":
			return Color(0.32, 0.38, 0.48, 0.95)
		"sparse":
			return Color(0.28, 0.52, 0.58, 0.95)
		"dense":
			return Color(0.62, 0.42, 0.88, 0.95)
		"loud_quiet":
			return Color(0.82, 0.62, 0.28, 0.95)
		_:
			return Color(0.38, 0.58, 0.82, 0.95)


static func _format_time(seconds: float) -> String:
	var total: int = maxi(0, int(round(seconds)))
	var minutes: int = int(total / 60)
	var secs: int = total % 60
	return "%d:%02d" % [minutes, secs]


static func _structure_placeholder_card() -> Control:
	var panel := _inner_panel()
	_shrink_vertical(panel)
	panel.add_child(_body_label(_tr("DNA_UI_STRUCTURE_PLACEHOLDER"), COLOR_MUTED, 14))
	return panel


static func _pipeline_card(pipeline: Dictionary) -> Control:
	var panel := _inner_panel()
	_shrink_vertical(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_shrink_vertical(vbox)
	panel.add_child(vbox)
	var source := int(pipeline.get("source", 0))
	var pre_section := int(pipeline.get("pre_section", 0))
	var post_section := int(pipeline.get("post_section", 0))
	var final_events := int(pipeline.get("final_events", 0))
	var final_notes := int(pipeline.get("final_notes", 0))
	if source > 0:
		vbox.add_child(_metric_line(_tr("DNA_PIPELINE_LINE_FMT") % source))
		vbox.add_child(_metric_line(_tr("DNA_PIPELINE_LINE2_FMT") % [pre_section, post_section]))
		vbox.add_child(_metric_line(_tr("DNA_PIPELINE_LINE3_FMT") % [final_events, final_notes]))
	else:
		vbox.add_child(_metric_line(_tr("DNA_PIPELINE_SIMPLE_FMT") % final_notes))
	return panel


static func _action_cards_row(pipeline: Dictionary, decisions: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shrink_vertical(row)
	var hints := _collect_action_hints(pipeline, decisions)
	var removed := int(pipeline.get("removed_total", 0))
	var added := int(pipeline.get("added_net", 0))
	var saved := int(pipeline.get("final_notes", 0))
	row.add_child(_stat_card(str(removed), _tr("DNA_UI_REMOVED"), COLOR_REMOVE, "trash-2.svg", hints.removed))
	row.add_child(_stat_card(str(added), _tr("DNA_UI_ADDED"), COLOR_ADD, "circle-check.svg", hints.added))
	row.add_child(_stat_card(str(saved), _tr("DNA_UI_SAVED"), COLOR_SAVE, "archive.svg", hints.saved))
	var hint := _body_label(_tr("DNA_UI_WHAT_I_DID_HINT"), COLOR_MUTED, 11)
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 6)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shrink_vertical(wrap)
	wrap.add_child(row)
	wrap.add_child(hint)
	return wrap


static func _collect_action_hints(pipeline: Dictionary, decisions: Array) -> Dictionary:
	var removed: PackedStringArray = _read_hint_array(pipeline.get("removed_hints", []))
	var added: PackedStringArray = _read_hint_array(pipeline.get("added_hints", []))
	var saved: PackedStringArray = _read_hint_array(pipeline.get("saved_hints", []))
	if removed.is_empty() or added.is_empty() or saved.is_empty():
		var derived := _derive_hints_from_decisions(decisions)
		if removed.is_empty():
			removed = derived.removed
		if added.is_empty():
			added = derived.added
		if saved.is_empty():
			saved = derived.saved
	return {"removed": removed, "added": added, "saved": saved}


static func _read_hint_array(raw: Variant) -> PackedStringArray:
	var out: PackedStringArray = []
	if not raw is Array:
		return out
	for item in raw:
		var line := ""
		if item is Dictionary:
			line = _View.format_item(item)
		elif item is String:
			line = item.strip_edges()
		if line != "":
			out.append(line)
	return out


static func _derive_hints_from_decisions(decisions: Array) -> Dictionary:
	var removed: PackedStringArray = []
	var added: PackedStringArray = []
	var saved: PackedStringArray = [_tr("DNA_HINT_SAVED_PATTERN")]
	for item in decisions:
		if not item is Dictionary:
			continue
		var key := String(item.get("key", ""))
		var hint_key: String = DECISION_HINT_FALLBACK.get(key, "")
		if hint_key == "":
			continue
		var line := _tr(hint_key)
		match key:
			"DNA_DEC_DRUM_ENTRY", "DNA_DEC_FILL_ZONE":
				if not added.has(line):
					added.append(line)
			_:
				if not removed.has(line):
					removed.append(line)
	return {
		"removed": removed.slice(0, 2),
		"added": added.slice(0, 2),
		"saved": saved.slice(0, 2),
	}


static func _stat_card(
	value_text: String,
	caption: String,
	accent: Color,
	icon_file: String,
	hints: PackedStringArray
) -> Control:
	var panel := _inner_panel()
	panel.custom_minimum_size = Vector2(104, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	_shrink_vertical(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shrink_vertical(vbox)
	panel.add_child(vbox)
	vbox.add_child(UiIconHelper.make_texture_rect(UiIconHelper.load_tinted_icon(icon_file, accent), 18))
	vbox.add_child(_centered_label(value_text, accent, 24))
	vbox.add_child(_centered_label(caption, COLOR_MUTED, 12))
	for hint in hints:
		var hint_label := _centered_label(hint, COLOR_MUTED, 10)
		hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(hint_label)
	return panel


static func _genes_card(
	rhythm: Dictionary,
	structure: Dictionary,
	measure_map: Dictionary,
	dna: Dictionary
) -> Control:
	var panel := _inner_panel()
	_shrink_vertical(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_shrink_vertical(vbox)
	panel.add_child(vbox)
	if not rhythm.is_empty():
		vbox.add_child(_fixed_label(_tr("DNA_SECTION_RHYTHM").trim_suffix(":"), COLOR_BODY, 15))
		var viable := String(rhythm.get("percussion_viable", "")).strip_edges().to_lower()
		if viable == "low":
			vbox.add_child(_icon_text_row("triangle-alert.svg", COLOR_WARN, _tr("DNA_UI_PERCUSSION_LOW"), COLOR_MUTED, 13))
		elif bool(rhythm.get("kit_detected", false)):
			vbox.add_child(_icon_text_row("drum.svg", UiIconHelper.ACCENT, _tr("DNA_GENE_KIT_DETECTED"), COLOR_BODY, 14))
		vbox.add_child(_metric_line(_tr("DNA_GENE_GROOVE_FMT") % _View.format_level(String(rhythm.get("groove_stability", "medium")))))
		vbox.add_child(_metric_line(_tr("DNA_GENE_FILL_FMT") % _View.format_level(String(rhythm.get("fill_density", "medium")))))
	var adtof: Dictionary = dna.get("adtof", {}) if dna.get("adtof", {}) is Dictionary else {}
	if not adtof.is_empty():
		vbox.add_child(_fixed_label(_tr("DNA_UI_ADTOF"), COLOR_MUTED, 13))
		vbox.add_child(_metric_line(_tr("DNA_UI_ADTOF_KICK_SNARE_FMT") % [
			int(adtof.get("kick", 0)), int(adtof.get("snare", 0)),
		]))
	if not structure.is_empty() or not measure_map.is_empty():
		vbox.add_child(_fixed_label(_tr("DNA_UI_STRUCTURE_GENE"), COLOR_BODY, 15))
		var measures := int(structure.get("measures", measure_map.get("measures", 0)))
		if measures > 0:
			vbox.add_child(_metric_line(_tr("DNA_UI_MEASURES_FMT") % measures))
		var ratio := float(structure.get("mix_drum_ratio", measure_map.get("mix_drum_ratio", 0.0)))
		if ratio > 0.0:
			vbox.add_child(_metric_line(_tr("DNA_UI_MIX_DRUM_RATIO_FMT") % ratio))
		var quiet := int(structure.get("quiet_drum_windows", measure_map.get("loud_mix_quiet_drum", 0)))
		if quiet > 0:
			vbox.add_child(_metric_line(_tr("DNA_UI_QUIET_DRUM_FMT") % quiet))
	return panel


static func _confidence_card(confidence: Dictionary) -> Control:
	var panel := _inner_panel()
	_shrink_vertical(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_shrink_vertical(vbox)
	panel.add_child(vbox)
	for spec in [
		["DNA_CONFIDENCE_OVERALL", "DNA_CONFIDENCE_OVERALL_TIP", "overall", COLOR_CONFIDENCE],
		["DNA_CONFIDENCE_DRUM", "DNA_CONFIDENCE_DRUM_TIP", "drum_detection", COLOR_SAVE],
		["DNA_CONFIDENCE_BEAT", "DNA_CONFIDENCE_BEAT_TIP", "beat_tracking", UiIconHelper.ACCENT],
		["DNA_CONFIDENCE_GENRE", "DNA_CONFIDENCE_GENRE_TIP", "genre", COLOR_ADD],
		["DNA_CONFIDENCE_PATTERN", "DNA_CONFIDENCE_PATTERN_TIP", "pattern", COLOR_REMOVE],
	]:
		var val := int(confidence.get(spec[2], 0))
		if val <= 0:
			continue
		vbox.add_child(_confidence_bar(_tr(spec[0]), _tr(spec[1]), val, spec[3]))
	return panel


static func _confidence_bar(caption_key: String, tooltip_key: String, value: int, fill_color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shrink_vertical(row)
	var label_col := VBoxContainer.new()
	label_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_col.size_flags_stretch_ratio = 1.0
	_shrink_vertical(label_col)
	var caption := _fixed_label(caption_key, COLOR_MUTED, 12)
	_apply_tooltip(caption, tooltip_key)
	label_col.add_child(caption)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.max_value = 100.0
	bar.value = float(value)
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.07, 0.1, 1)
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	label_col.add_child(bar)
	row.add_child(label_col)
	var pct := _fixed_label("%d%%" % value, COLOR_BODY, 12, HORIZONTAL_ALIGNMENT_RIGHT, 42.0)
	_apply_tooltip(pct, tooltip_key)
	_apply_tooltip(row, tooltip_key)
	row.add_child(pct)
	return row


static func _warnings_card(warnings: Array) -> Control:
	var panel := _inner_panel(Color(0.14, 0.11, 0.06, 0.55))
	_shrink_vertical(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_shrink_vertical(vbox)
	panel.add_child(vbox)
	for item in warnings:
		var line := _View.format_item(item)
		if line == "":
			continue
		vbox.add_child(_icon_text_row("triangle-alert.svg", COLOR_WARN, line, COLOR_BODY, 14))
	return panel


static func _inner_panel(bg: Color = Color(0.06, 0.07, 0.11, 0.92)) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shrink_vertical(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = Color(1, 1, 1, 0.08)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 12.0
	style.content_margin_top = 10.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)
	return panel


static func _body_label(
	text: String,
	color: Color,
	font_size: int,
	align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = align
	return label


static func _fixed_label(
	text: String,
	color: Color,
	font_size: int,
	align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT,
	min_width: float = 0.0
) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if min_width > 0.0:
		label.custom_minimum_size.x = min_width
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = align
	return label


static func _centered_label(text: String, color: Color, font_size: int) -> Label:
	var label := _body_label(text, color, font_size, HORIZONTAL_ALIGNMENT_CENTER)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label


static func _metric_line(text: String) -> Label:
	return _body_label(text, COLOR_BODY, 14)
