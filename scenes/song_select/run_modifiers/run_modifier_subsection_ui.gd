# scenes/song_select/run_modifiers/run_modifier_subsection_ui.gd
extends RefCounted
class_name RunModifierSubsectionUi

const SUBSECTION_COLUMNS := 2


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

	for spec in subsection.get("specs", []):
		if spec.size() < 2:
			continue
		var mod_id := str(spec[0])
		var card := card_scene.instantiate()
		flow.add_child(card)
		card.setup(mod_id, str(spec[1]), card_size)
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
	var grid := GridContainer.new()
	grid.columns = SUBSECTION_COLUMNS
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 14)
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
