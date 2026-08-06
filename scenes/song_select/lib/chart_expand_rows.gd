# scenes/song_select/lib/chart_expand_rows.gd
# Shared expand-for-charts rows (playlist editor + endless track picker).
extends RefCounted
class_name ChartExpandRows

const _GoalDiff = preload("res://logic/domain/generation/generation_goal_difficulty.gd")
const _ChartDifficultyAnalyzer = preload("res://logic/domain/charts/chart_difficulty_analyzer.gd")
const _NotesUtils = preload("res://logic/domain/rhythm/notes_utils.gd")
const _GenPresetUi = preload("res://logic/ui/generation_preset_ui.gd")
const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")
const _SongSelectUiStyles = preload("res://scenes/song_select/lib/song_select_ui_styles.gd")

const CHECKBOX_SIZE := 28


static func make_picker_panel(title_text: String) -> Dictionary:
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
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	panel.add_child(outer)
	if title_text.strip_edges() != "":
		var title := Label.new()
		title.text = title_text
		title.add_theme_font_size_override("font_size", 12)
		title.add_theme_color_override("font_color", Color(0.72, 0.8, 0.9, 1.0))
		outer.add_child(title)
	return {"panel": panel, "outer": outer}


static func stem_title(stem_id: String) -> String:
	var pair := _GoalDiff.pair_from_stem(stem_id)
	var goal := str(pair.get("goal", _GoalDiff.DEFAULT_GOAL))
	var diff := str(pair.get("difficulty", _GoalDiff.DEFAULT_DIFFICULTY))
	var goal_label := TranslationServer.translate("GEN_GOAL_%s" % goal.to_upper())
	if _GoalDiff.sanitize_goal(goal) == "original":
		return goal_label
	var diff_label := TranslationServer.translate(_GoalDiff.difficulty_label_key(goal, diff))
	return "%s · %s" % [goal_label, diff_label]


static func make_chart_row(
	song_path: String,
	stem_id: String,
	instrument: String,
	lanes: int,
	selected: bool,
	show_checkbox: bool,
	on_pressed: Callable,
	song_level_selected: bool = false,
) -> PanelContainer:
	var exists := _NotesUtils.notes_exist(song_path, instrument, stem_id, lanes)
	var pair := _GoalDiff.pair_from_stem(stem_id)
	var goal := str(pair.get("goal", _GoalDiff.DEFAULT_GOAL))
	var stats := (
		SongLibrary.get_chart_difficulty_variant(song_path, instrument, stem_id, lanes)
		if exists
		else {}
	)
	var rating := _ChartDifficultyAnalyzer.decimal_rating_from_stats(stats) if exists else 0.0
	var row_panel := PanelContainer.new()
	row_panel.add_theme_stylebox_override("panel", _SongSelectUiStyles.row_panel_style(selected and exists))
	if on_pressed.is_valid():
		row_panel.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton:
				var mb := event as InputEventMouseButton
				if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and exists:
					on_pressed.call()
		)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row_panel.add_child(row)
	if show_checkbox:
		var check := CheckBox.new()
		check.button_pressed = selected and exists
		check.disabled = not exists
		check.custom_minimum_size = Vector2(CHECKBOX_SIZE, CHECKBOX_SIZE)
		check.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(check)
	var goal_tint: Color = _GenPresetUi.INTENT_ICON_COLORS.get(goal, _UiIconHelper.ACCENT) as Color
	row.add_child(_UiIconHelper.make_icon_frame(
		str(_GenPresetUi.INTENT_ICONS.get(goal, "layers.svg")),
		22,
		14,
		goal_tint if exists else Color(0.55, 0.6, 0.68, 0.85)
	))
	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 1)
	row.add_child(text_col)
	var line1 := Label.new()
	line1.text = stem_title(stem_id)
	line1.add_theme_font_size_override("font_size", 14)
	line1.add_theme_color_override(
		"font_color",
		Color(0.92, 0.95, 0.99, 1.0) if exists else Color(0.55, 0.6, 0.68, 0.9)
	)
	text_col.add_child(line1)
	var line2 := HBoxContainer.new()
	line2.add_theme_constant_override("separation", 6)
	line2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.add_child(line2)
	var inst := Label.new()
	inst.text = _GenPresetUi.localized_instrument(instrument)
	inst.add_theme_font_size_override("font_size", 12)
	inst.add_theme_color_override("font_color", Color(0.62, 0.7, 0.82, 0.95))
	inst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line2.add_child(inst)
	var sep := Label.new()
	sep.text = "·"
	sep.add_theme_font_size_override("font_size", 12)
	sep.add_theme_color_override("font_color", Color(0.62, 0.7, 0.82, 0.95))
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line2.add_child(sep)
	var rating_tint := (
		_ChartDifficultyAnalyzer.rating_color_for_decimal(rating)
		if rating > 0.0
		else Color(0.5, 0.56, 0.66, 0.9)
	)
	if exists and rating > 0.0:
		line2.add_child(_UiIconHelper.make_icon_frame("zap.svg", 18, 12, rating_tint))
	var rating_lbl := Label.new()
	rating_lbl.text = (
		_ChartDifficultyAnalyzer.format_decimal_rating(rating, false) if rating > 0.0 else "—"
	)
	rating_lbl.add_theme_font_size_override("font_size", 12)
	rating_lbl.add_theme_color_override("font_color", rating_tint)
	rating_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line2.add_child(rating_lbl)
	if not exists:
		row_panel.modulate = Color(1, 1, 1, 0.55)
		row_panel.tooltip_text = TranslationServer.translate("PLAYLIST_EDITOR_CHART_NOT_READY")
	elif song_level_selected:
		row_panel.tooltip_text = TranslationServer.translate("PLAYLIST_EDITOR_CHART_VIA_SONG")
	return row_panel


static func stems_for_filter(
	song_path: String,
	instrument: String,
	lanes: int,
	goals: Array,
	diffs: Array,
	notes_only: bool,
	all_charts_mode: bool
) -> Array[String]:
	var stems: Array[String] = (
		_NotesUtils.generation_chart_stems()
		if all_charts_mode
		else _GoalDiff.stems_for_ready_axes(goals, diffs)
	)
	var out: Array[String] = []
	for stem in stems:
		var exists := _NotesUtils.notes_exist(song_path, instrument, str(stem), lanes)
		if notes_only and not exists and not all_charts_mode:
			continue
		var sid := str(stem)
		if not out.has(sid):
			out.append(sid)
	return out


static func make_title_artist_column(
	title_text: String,
	artist_text: String,
	subtitle_extra: String = ""
) -> VBoxContainer:
	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 1)
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.86, 0.9, 0.97, 1.0))
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.add_child(title)
	var artist_line := artist_text.strip_edges()
	if subtitle_extra.strip_edges() != "":
		artist_line = (
			"%s · %s" % [artist_line, subtitle_extra]
			if artist_line != ""
			else subtitle_extra
		)
	var artist := Label.new()
	artist.text = artist_line if artist_line != "" else "—"
	artist.add_theme_font_size_override("font_size", 13)
	artist.add_theme_color_override("font_color", Color(0.62, 0.7, 0.82, 0.95))
	artist.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	artist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.add_child(artist)
	return text_col


static func make_bpm_duration_stats(
	bpm_text: String,
	duration_text: String,
	font_size: int = 16
) -> HBoxContainer:
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 16)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bpm := bpm_text.strip_edges()
	stats.add_child(_make_stat_label(
		"BPM %s" % bpm if bpm != "" else "BPM —",
		Color(0.62, 0.7, 0.82, 0.95),
		font_size
	))
	var dur := duration_text.strip_edges()
	stats.add_child(_make_stat_label(
		dur if dur != "" else "—",
		Color(0.62, 0.7, 0.82, 0.95),
		font_size
	))
	return stats


static func _make_stat_label(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
