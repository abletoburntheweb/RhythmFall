# scenes/song_select/run_modifiers/run_modifier_subsection_ui.gd
extends RefCounted
class_name RunModifierSubsectionUi

const PerfTrace = preload("res://logic/utils/perf_trace.gd")

const SUBSECTION_COLUMNS := 2

const _MOD_CHECK_ACCENT := Color(0.42, 0.57, 0.82, 1.0)

## Mirrors SettingsSectionUi._apply_stable_check_frame, but typed for CheckButton
## (a sibling of CheckBox, not a subclass) so the focus border survives hover.
## Fixes the outline-disappears-on-hover bug on modifier-screen toggles
## (e.g. the Combo Escalation pool list).
static func apply_modifier_checkbox(check: Button, font_size: int = 16, compact: bool = true, accent: Color = _MOD_CHECK_ACCENT) -> void:
	if check == null:
		return
	check.add_theme_font_size_override("font_size", font_size)
	check.add_theme_constant_override("h_separation", 10 if compact else 12)
	if not compact:
		check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var border := Color(accent.r, accent.g, accent.b, 0.38)
	var focus_border := accent.lightened(0.08)
	var pad_h := 8.0 if compact else 12.0
	var pad_v := 4.0 if compact else 10.0
	var wash := Color(accent.r, accent.g, accent.b, 0.06).lerp(Color(1, 1, 1, 0.04), 0.35)
	var normal := StyleBoxFlat.new()
	normal.bg_color = wash
	normal.border_color = border
	normal.set_border_width_all(1)
	normal.shadow_size = 0
	normal.content_margin_left = pad_h
	normal.content_margin_right = pad_h
	normal.content_margin_top = pad_v
	normal.content_margin_bottom = pad_v
	normal.set_corner_radius_all(10)
	var hover := normal.duplicate()
	hover.bg_color = Color(accent.r, accent.g, accent.b, 0.12).lerp(Color(1, 1, 1, 0.06), 0.3)
	hover.border_color = Color(accent.r, accent.g, accent.b, 0.55)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(accent.r, accent.g, accent.b, 0.16)
	pressed.border_color = Color(accent.r, accent.g, accent.b, 0.7)
	var hover_pressed := pressed.duplicate()
	hover_pressed.bg_color = hover.bg_color
	hover_pressed.border_color = hover.border_color
	var disabled := normal.duplicate()
	disabled.bg_color = Color(1, 1, 1, 0.02)
	disabled.border_color = border.darkened(0.25)
	var focus := normal.duplicate()
	focus.border_color = focus_border
	focus.set_border_width_all(1)
	check.add_theme_stylebox_override("normal", normal)
	check.add_theme_stylebox_override("hover", hover)
	check.add_theme_stylebox_override("pressed", pressed)
	check.add_theme_stylebox_override("hover_pressed", hover_pressed)
	check.add_theme_stylebox_override("disabled", disabled)
	check.add_theme_stylebox_override("focus", focus)
	check.add_theme_color_override("checkbox_checked_color", accent.lightened(0.05))
	check.add_theme_color_override("checkbox_unchecked_color", Color(accent.r, accent.g, accent.b, 0.55).lerp(Color(0.75, 0.80, 0.90, 1.0), 0.45))


static func apply_locale_tree(root: Node) -> void:
	if root is Label:
		var lk: Variant = (root as Label).get_meta("locale_key", "")
		if str(lk) != "":
			(root as Label).text = TranslationServer.translate(str(lk))
	for child in root.get_children():
		apply_locale_tree(child)


static func make_subsection_cell(
	subsection: Dictionary,
	card_size: Vector2,
	card_scene: PackedScene,
	cards_out: Dictionary,
	on_pressed: Callable,
	subheader_size: int = 14,
	on_hovered: Callable = Callable(),
	on_unhovered: Callable = Callable(),
	on_info: Callable = Callable(),
	on_dna_blocked: Callable = Callable()
) -> VBoxContainer:
	var _perf_struct := PerfTrace.begin("perf.detail.song_select.run_modifiers.ready.overview.subsection.structure")
	var cell := VBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_theme_constant_override("separation", 8)

	var sub := Label.new()
	sub.text = TranslationServer.translate(str(subsection.get("key", "")))
	sub.add_theme_font_size_override("font_size", subheader_size)
	sub.add_theme_color_override("font_color", Color(0.62, 0.7, 0.82, 0.92))
	sub.set_meta("locale_key", str(subsection.get("key", "")))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cell.add_child(sub)

	var flow := FlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 12)
	cell.add_child(flow)
	PerfTrace.end("perf.detail.song_select.run_modifiers.ready.overview.subsection.structure", _perf_struct)

	for spec in subsection.get("specs", []):
		if spec.size() < 2:
			continue
		var mod_id := str(spec[0])
		var _perf_inst := PerfTrace.begin("perf.detail.song_select.run_modifiers.ready.overview.subsection.card_instantiate")
		var card := card_scene.instantiate()
		PerfTrace.end("perf.detail.song_select.run_modifiers.ready.overview.subsection.card_instantiate", _perf_inst)
		var _perf_setup := PerfTrace.begin("perf.detail.song_select.run_modifiers.ready.overview.card.setup")
		card.setup(mod_id, str(spec[1]), card_size)
		PerfTrace.end("perf.detail.song_select.run_modifiers.ready.overview.card.setup", _perf_setup)
		var _perf_add := PerfTrace.begin("perf.detail.song_select.run_modifiers.ready.overview.subsection.card_add_child")
		flow.add_child(card)
		PerfTrace.end("perf.detail.song_select.run_modifiers.ready.overview.subsection.card_add_child", _perf_add)
		if on_pressed.is_valid():
			card.card_toggled.connect(func(id: String, pressed: bool): on_pressed.call(id, pressed))
		if on_hovered.is_valid():
			card.card_hovered.connect(func(id: String): on_hovered.call(id))
		if on_unhovered.is_valid():
			card.card_unhovered.connect(func(id: String): on_unhovered.call(id))
		if on_info.is_valid():
			card.card_info_requested.connect(func(id: String): on_info.call(id))
		if on_dna_blocked.is_valid() and card.has_signal("card_dna_enable_blocked"):
			card.card_dna_enable_blocked.connect(func(id: String): on_dna_blocked.call(id))
		cards_out[mod_id] = card

	return cell


static func make_subsection_grid(
	subsections: Array,
	card_size: Vector2,
	card_scene: PackedScene,
	cards_out: Dictionary,
	on_pressed: Callable,
	subheader_size: int = 14,
	on_hovered: Callable = Callable(),
	on_unhovered: Callable = Callable(),
	on_info: Callable = Callable(),
	on_dna_blocked: Callable = Callable()
) -> GridContainer:
	var _perf_grid_struct := PerfTrace.begin("perf.detail.song_select.run_modifiers.ready.overview.subsection.structure")
	var grid := GridContainer.new()
	grid.columns = SUBSECTION_COLUMNS
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 14)
	PerfTrace.end("perf.detail.song_select.run_modifiers.ready.overview.subsection.structure", _perf_grid_struct)
	for subsection in subsections:
		grid.add_child(
			make_subsection_cell(
				subsection,
				card_size,
				card_scene,
				cards_out,
				on_pressed,
				subheader_size,
				on_hovered,
				on_unhovered,
				on_info,
				on_dna_blocked
			)
		)
	return grid
