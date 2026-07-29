# scenes/song_select/lib/chart_stem_chips.gd
class_name ChartStemChips
extends RefCounted

const _GoalDiff = preload("res://logic/domain/generation/generation_goal_difficulty.gd")
const _NotesUtils = preload("res://logic/domain/rhythm/notes_utils.gd")
const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")

const CHIP_FONT_SIZE := 13
const CHIP_SEPARATION := 10


static func build_panel(
	song_path: String,
	instrument: String,
	lanes: int,
	selected_stems: Array = [],
	on_stem_pressed: Callable = Callable(),
	title_text: String = ""
) -> PanelContainer:
	var panel := _new_row_panel()
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	panel.add_child(outer)
	if title_text.strip_edges() != "":
		var title := Label.new()
		title.text = title_text
		title.add_theme_font_size_override("font_size", 12)
		title.add_theme_color_override("font_color", Color(0.72, 0.8, 0.9, 1.0))
		outer.add_child(title)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", CHIP_SEPARATION)
	outer.add_child(chips)
	var ready := _NotesUtils.chart_intents_exist(song_path, instrument, lanes)
	for stem_id in _NotesUtils.generation_chart_stems():
		var chip := make_chip(
			song_path,
			instrument,
			stem_id,
			lanes,
			ready,
			selected_stems.has(stem_id),
		)
		if on_stem_pressed.is_valid():
			chip.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton:
					var mb := event as InputEventMouseButton
					if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
						on_stem_pressed.call(stem_id)
			)
			chip.mouse_filter = Control.MOUSE_FILTER_STOP
		chips.add_child(chip)
	return panel


static func make_chip(
	song_path: String,
	instrument: String,
	stem_id: String,
	lanes: int,
	ready: Dictionary = {},
	selected: bool = false,
) -> Label:
	if ready.is_empty():
		ready = _NotesUtils.chart_intents_exist(song_path, instrument, lanes)
	var exists := bool(ready.get(stem_id, false))
	var abbrev := _GoalDiff.abbrev_for_stem(stem_id)
	var chip := Label.new()
	var suffix := "✓" if exists else "—"
	if selected:
		suffix = "●"
	chip.text = "%s %s" % [abbrev, suffix]
	chip.add_theme_font_size_override("font_size", CHIP_FONT_SIZE)
	var color := Color(0.58, 0.64, 0.74, 0.95)
	if exists:
		color = Color(0.52, 0.9, 0.68, 1.0)
	if selected:
		color = _UiIconHelper.ACCENT
	chip.add_theme_color_override("font_color", color)
	var pair := _GoalDiff.pair_from_stem(stem_id)
	var goal := str(pair.get("goal", _GoalDiff.DEFAULT_GOAL))
	var goal_key := "GEN_GOAL_%s" % goal.to_upper()
	if _GoalDiff.sanitize_goal(goal) == "original":
		chip.tooltip_text = TranslationServer.translate(goal_key)
	else:
		var diff_key := _GoalDiff.difficulty_label_key(
			goal,
			str(pair.get("difficulty", _GoalDiff.DEFAULT_DIFFICULTY)),
		)
		chip.tooltip_text = "%s · %s" % [
			TranslationServer.translate(goal_key),
			TranslationServer.translate(diff_key),
		]
	return chip


static func _new_row_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.09, 0.13, 0.96)
	box.border_color = Color(0.42, 0.68, 0.92, 0.35)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", box)
	return panel
