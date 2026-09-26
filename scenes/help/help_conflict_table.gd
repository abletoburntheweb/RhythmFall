class_name HelpConflictTable
extends VBoxContainer

const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const _HelpTypography = preload("res://scenes/help/lib/help_typography.gd")

const _ANCHOR_IDS := [
	"slow_75", "fast_150", "easy_windows", "strict_timing", "no_fail", "sudden_death",
	"last_chance", "energy_pulse", "time_warp", "hidden", "sudden", "memory_mode",
	"spotlight", "density_focus", "dynamic_lanes", "single_lane", "mirror_mode",
	"shuffle_mode", "random_mode", "phrase_shift", "groove_lock", "groove_addiction",
	"adaptive", "heat", "rush", "reverse_scroll", "combo_escalation",
]

const _HEADER_FRAME := 26
const _HEADER_ICON := 14
const _CHIP_FRAME := 26
const _CHIP_ICON := 14


func _ready() -> void:
	_build()


func _build() -> void:
	add_theme_constant_override("separation", 8)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var any := false
	for mid in _ANCHOR_IDS:
		var conflicts := _RunModifiers.ui_conflict_ids(mid)
		if conflicts.is_empty():
			continue
		any = true
		add_child(_make_expandable_row(mid, conflicts))
	if not any:
		var empty := Label.new()
		empty.text = tr("HELP_CONFLICTS_NONE")
		_HelpTypography.apply_label(empty, _HelpTypography.SIZE_MICRO, Color(0.55, 0.64, 0.76, 0.9))
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(empty)


func _make_expandable_row(mod_id: String, conflicts: Array) -> Control:
	var wrapper := VBoxContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_constant_override("separation", 4)
	var header_btn := Button.new()
	header_btn.toggle_mode = true
	header_btn.flat = true
	header_btn.focus_mode = Control.FOCUS_NONE
	header_btn.custom_minimum_size = Vector2(0, 44)
	header_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var header_panel := PanelContainer.new()
	header_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	header_btn.add_child(header_panel)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	header_panel.add_child(hbox)
	var icon_file := _RunModifiers.icon_file(mod_id)
	var base_accent := _RunModifiers.category_tint(mod_id, true)
	var chip: Control = null
	if icon_file.strip_edges() != "":
		chip = UiIconHelper.make_icon_frame(icon_file, _HEADER_FRAME, _HEADER_ICON, _RunModifiers.category_tint(mod_id, false))
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(chip)
	else:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(_HEADER_FRAME, _HEADER_FRAME)
		hbox.add_child(spacer)
	var title := Label.new()
	title.text = TranslationServer.translate(_RunModifiers.title_i18n_key(mod_id))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_HelpTypography.apply_label(title, _HelpTypography.SIZE_SMALL, Color(0.9, 0.93, 0.97, 1.0))
	hbox.add_child(title)
	var chevron := Label.new()
	chevron.text = ">"
	chevron.custom_minimum_size = Vector2(16, 0)
	chevron.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_HelpTypography.apply_label(chevron, 18, Color(0.5, 0.56, 0.66, 0.85))
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(chevron)
	wrapper.add_child(header_btn)
	var wrap := MarginContainer.new()
	wrap.visible = false
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("margin_left", 8)
	wrap.add_theme_constant_override("margin_top", 4)
	wrap.add_theme_constant_override("margin_right", 4)
	wrap.add_theme_constant_override("margin_bottom", 6)
	wrapper.add_child(wrap)
	var content_vbox := VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 8)
	wrap.add_child(content_vbox)
	var subtitle := Label.new()
	subtitle.text = _conflicts_prefix()
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_HelpTypography.apply_label(subtitle, _HelpTypography.SIZE_MICRO, Color(0.58, 0.64, 0.74, 0.95))
	content_vbox.add_child(subtitle)
	var flow := FlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	content_vbox.add_child(flow)
	var row_state := {
		"expanded": false,
		"built": false,
		"flow": flow,
		"chip": chip,
		"chevron": chevron,
		"title": title,
		"wrap": wrap,
		"header": header_btn,
		"accent": base_accent,
		"mod_id": mod_id,
		"conflicts": conflicts,
	}
	_sync_row_header_style(row_state, false)
	header_btn.toggled.connect(func(pressed: bool):
		row_state["expanded"] = pressed
		wrap.visible = pressed
		_sync_row_header_style(row_state, pressed)
		if pressed and not row_state["built"]:
			row_state["built"] = true
			_populate_conflicts_flow(flow, conflicts)
	)
	return wrapper


func _make_chip_for_conflict(mod_id: String) -> Control:
	var icon_file := _RunModifiers.icon_file(mod_id)
	if icon_file.strip_edges() == "":
		return Control.new()
	var tint := _RunModifiers.category_tint(mod_id, true)
	var chip := UiIconHelper.make_icon_frame(icon_file, _CHIP_FRAME, _CHIP_ICON, tint)
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.tooltip_text = _RunModifiers.format_tooltip(mod_id)
	return chip


func _populate_conflicts_flow(flow: FlowContainer, conflicts: Array) -> void:
	if flow == null:
		return
	for cid in conflicts:
		var cid_str := str(cid)
		var entry := HBoxContainer.new()
		entry.add_theme_constant_override("separation", 6)
		entry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		entry.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		flow.add_child(entry)
		var chip := _make_chip_for_conflict(cid_str)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		entry.add_child(chip)
		var lbl := Label.new()
		lbl.text = TranslationServer.translate(_RunModifiers.title_i18n_key(cid_str))
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl.clip_text = false
		lbl.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_HelpTypography.apply_label(lbl, _HelpTypography.SIZE_MICRO, Color(0.72, 0.78, 0.88, 0.95))
		entry.add_child(lbl)


func _sync_row_header_style(state: Dictionary, expanded: bool) -> void:
	var header: Button = state.get("header", null) as Button
	var title: Label = state.get("title", null) as Label
	var chevron: Label = state.get("chevron", null) as Label
	var chip: Control = state.get("chip", null) as Control
	var accent: Color = state.get("accent", Color(0.38, 0.78, 0.74, 1.0)) as Color
	if header == null:
		return
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(10)
	box.content_margin_left = 8.0
	box.content_margin_right = 10.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	if expanded:
		box.bg_color = Color(accent.r, accent.g, accent.b, 0.14).lerp(Color(0.10, 0.11, 0.15, 0.95), 0.35)
		box.set_border_width_all(2)
		box.border_color = accent.lightened(0.08)
	else:
		box.bg_color = Color(0.09, 0.10, 0.14, 0.55)
		box.set_border_width_all(1)
		box.border_color = Color(1, 1, 1, 0.07)
	for s in ["normal", "hover", "pressed", "focus"]:
		header.add_theme_stylebox_override(s, box)
	if title:
		title.add_theme_color_override("font_color", accent if expanded else Color(0.9, 0.93, 0.97, 1.0))
	if chevron:
		chevron.text = "v" if expanded else ">"
		chevron.add_theme_color_override("font_color", accent if expanded else Color(0.5, 0.56, 0.66, 0.85))
	if chip and chip is PanelContainer:
		var use_tint := _RunModifiers.category_tint(str(state.get("mod_id", "")), expanded)
		UiIconHelper.set_frame_tint(chip as PanelContainer, use_tint, expanded)


func _conflicts_prefix() -> String:
	var locale := TranslationServer.get_locale().to_lower()
	if locale.begins_with("ru"):
		return "Несовместим с:"
	if locale.begins_with("en"):
		return "Incompatible with:"
	var tr_text := tr("HELP_CONFLICTS_CONFLICTS_WITH")
	if tr_text != "HELP_CONFLICTS_CONFLICTS_WITH" and tr_text.strip_edges() != "":
		if not tr_text.ends_with(":"):
			tr_text += ":"
		return tr_text
	return "Incompatible with:"
