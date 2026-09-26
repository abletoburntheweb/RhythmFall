# scenes/victory_screen/victory_rr_formula.gd
extends Control

const _RhythmRating = preload("res://logic/domain/rhythm/rhythm_rating.gd")
const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const _GradeDisplay = preload("res://logic/ui/grade_display.gd")
const _ChartDifficultyAnalyzer = preload("res://logic/domain/charts/chart_difficulty_analyzer.gd")

const ACCENT := Color(0.94902, 0.701961, 0.352941, 1.0)
const MUTED_TEXT := Color(0.58, 0.64, 0.74, 0.92)
const BRIGHT_TEXT := Color(0.85, 0.9, 0.97, 1.0)
const HEADER_TEXT := Color(0.72, 0.78, 0.88, 0.9)
const ROW_BORDER := Color(0.94902, 0.701961, 0.352941, 0.08)
const HEADER_BG := Color(0.06, 0.07, 0.10, 0.97)
const TABLE_BORDER := Color(0.94902, 0.701961, 0.352941, 0.12)

const ICON_ACCURACY := "crosshair.svg"
const ICON_RATING := "zap.svg"
const ICON_GRADE := "trophy.svg"
const ICON_FULL_COMBO := "star.svg"
const ICON_MULTIPLIER := "sparkles.svg"
const ICON_SCALE := "hash.svg"

const COLOR_ACCURACY := Color(0.47451, 0.890196, 0.835294, 1.0)
const COLOR_GRADE := Color(0.929412, 0.784314, 0.435294, 1.0)
const COLOR_FULL_COMBO := Color(0.556863, 0.831373, 0.615686, 1.0)
const COLOR_MULTIPLIER := Color(0.584314, 0.717647, 0.921569, 1.0)
const COLOR_SCALE := Color(0.85, 0.88, 0.96, 1.0)

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var table_vbox: VBoxContainer = %TableVBox
@onready var final_formula_label: Label = %FinalFormulaLabel
@onready var final_rr_value: Label = %FinalRrValue
@onready var scale_note_label: Label = %ScaleNoteLabel
@onready var close_button: Button = %CloseButton

var _detail_data: Dictionary = {}


func _ready() -> void:
	add_to_group("locale_refresh")
	visible = false
	_apply_hero_icon()
	close_button.pressed.connect(_on_back_pressed)
	UiClick.connect_clicked(self, _on_back_pressed)
	UiIconHelper.configure_button_icon(close_button, "arrow-left.svg", Color(0.85, 0.9, 0.97, 1.0), 16)
	_stabilize_close_button(close_button)
	call_deferred("apply_locale")



func _apply_hero_icon() -> void:
	var hero_icon: TextureRect = %HeroIcon
	var tex := UiIconHelper.load_tinted_icon("zap.svg", ACCENT, UiIconHelper.raster_size_for_display(56))
	if tex:
		hero_icon.texture = tex
		hero_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func apply_locale() -> void:
	if title_label:
		title_label.text = tr("VICTORY_RR_DETAIL_FORMULA_TITLE").to_upper()
	if subtitle_label:
		subtitle_label.text = tr("VICTORY_RR_DETAIL_SUBTITLE")
	if close_button:
		close_button.text = tr("VICTORY_REWARD_BTN_CLOSE").to_upper()
	if scale_note_label:
		var base_note := tr("VICTORY_RR_FORMULA_SCALE_NOTE")
		var desc_key := "VICTORY_RR_FORMULA_SCALE_DESC"
		var desc := tr(desc_key)
		if desc == desc_key or desc.strip_edges() == "":
			desc = "Применяется к итоговой сумме перед округлением." if TranslationServer.get_locale().begins_with("ru") else "Applied to the total before rounding."
		scale_note_label.text = base_note + "\n" + desc
	if not _detail_data.is_empty():
		_apply_detail_texts()


func show_details(
	p_accuracy: float,
	p_chart_rating: int,
	p_grade: String,
	p_full_combo: bool,
	p_modifiers: Array,
	p_modifier_params: Dictionary,
	p_multiplier: float,
	p_run_rr: int
) -> void:
	_detail_data = {
		"accuracy": p_accuracy,
		"chart_rating": p_chart_rating,
		"grade": p_grade,
		"full_combo": p_full_combo,
		"modifiers": p_modifiers,
		"modifier_params": p_modifier_params,
		"multiplier": p_multiplier,
		"run_rr": p_run_rr,
	}
	_apply_detail_texts()
	visible = true
	grab_focus()


func _apply_detail_texts() -> void:
	if _detail_data.is_empty():
		return
	var p_accuracy := float(_detail_data.get("accuracy", 0.0))
	var p_chart_rating := int(_detail_data.get("chart_rating", 0))
	var p_grade := str(_detail_data.get("grade", ""))
	var p_full_combo := bool(_detail_data.get("full_combo", false))
	var p_multiplier := float(_detail_data.get("multiplier", 1.0))
	var run_rr := int(_detail_data.get("run_rr", 0))
	var mods: Array = _detail_data.get("modifiers", [])
	if not mods is Array:
		mods = []
	var params: Dictionary = _detail_data.get("modifier_params", {})
	if not params is Dictionary:
		params = {}
	params = _RunModifiers.sync_params_from_modifiers(mods, params)

	# Точность: p_accuracy уже в процентах (0-100)
	var acc_pts := p_accuracy * _RhythmRating.ACCURACY_WEIGHT
	var rating_pts := float(maxi(p_chart_rating, 0)) * _RhythmRating.CHART_RATING_WEIGHT
	var grade_pts := _RhythmRating.grade_bonus(p_grade)
	var fc_pts := _RhythmRating.FULL_COMBO_BONUS if p_full_combo else 0.0
	var base := acc_pts + rating_pts + grade_pts + fc_pts
	var base_times_mult := base * p_multiplier

	# Цвет сложности по значению
	var diff_color := ChartDifficultyAnalyzer.rating_color(p_chart_rating)
	# Цвет accuracy — переиспользуем палитру из Victory Accuracy Details
	var acc_color := _accuracy_color(p_accuracy)

	# Собираем таблицу
	_clear_table()
	_add_header_row()

	var running := 0.0
	running = _add_data_row(ICON_ACCURACY, acc_color,
		tr("VICTORY_RR_FORMULA_ACCURACY"),
		"%.1f%%" % p_accuracy,
		"%d" % int(round(acc_pts)),
		running + acc_pts, running,
		acc_color)

	running = _add_data_row(ICON_RATING, diff_color,
		tr("VICTORY_RR_FORMULA_RATING"),
		"%d/10" % p_chart_rating,
		"%d" % int(round(rating_pts)),
		running + rating_pts, running,
		diff_color)

	running = _add_data_row(ICON_GRADE, COLOR_GRADE,
		tr("VICTORY_RR_FORMULA_GRADE"),
		p_grade,
		"+ %d" % int(round(grade_pts)),
		running + grade_pts, running,
		_GradeDisplay.grade_color(p_grade))

	if p_full_combo:
		running = _add_data_row(ICON_FULL_COMBO, COLOR_FULL_COMBO,
			tr("VICTORY_RR_FORMULA_FULL_COMBO"),
			tr("VICTORY_RR_FORMULA_YES"),
			"+ %d" % int(round(fc_pts)),
			running + fc_pts, running,
			COLOR_FULL_COMBO)

	# Модификаторы — последняя строка таблицы: показываем количество,
	# чтобы не растягивать строку длинными названиями модификаторов.
	var mod_text := str(mods.size())
	var mod_contrib := base_times_mult - base
	_add_data_row(ICON_MULTIPLIER, COLOR_MULTIPLIER,
		tr("VICTORY_RR_FORMULA_MODS"),
		mod_text,
		"%.2f×" % p_multiplier,
		base_times_mult, running,
		COLOR_MULTIPLIER)

	# Итоговый коэффициент ×0.92 — отдельная строка, чтобы ответить на "почему ×0.92?"
	var scale := _RhythmRating.GLOBAL_OUTPUT_SCALE
	var scale_title := tr("VICTORY_RR_FORMULA_SCALE_TITLE")
	if scale_title == "VICTORY_RR_FORMULA_SCALE_TITLE" or scale_title.strip_edges() == "":
		scale_title = "Итоговый коэффициент" if TranslationServer.get_locale().begins_with("ru") else "Final scale"
	_add_data_row(ICON_SCALE, COLOR_SCALE,
		scale_title,
		"×%.2f" % scale,
		"× %.2f" % scale,
		float(run_rr), base_times_mult,
		COLOR_SCALE)

	# Финальный расчёт: (base × multiplier) × 0.92 = RR
	_set_final_calc(base, p_multiplier, run_rr)


func _accuracy_color(pct: float) -> Color:
	# Переиспользует палитру из victory_accuracy_details.gd: 95/85/70
	if pct >= 95.0:
		return Color(0.42, 0.9, 0.78, 1.0)
	if pct >= 85.0:
		return Color(0.55, 0.78, 0.98, 1.0)
	if pct >= 70.0:
		return Color(0.95, 0.82, 0.42, 1.0)
	return Color(0.94, 0.44, 0.5, 1.0)


func _clear_table() -> void:
	if not table_vbox:
		return
	for child in table_vbox.get_children():
		child.queue_free()


func _add_header_row() -> void:
	var row := PanelContainer.new()
	row.custom_minimum_size.y = 40

	var style := StyleBoxFlat.new()
	style.bg_color = HEADER_BG
	style.border_width_bottom = 1
	style.border_color = TABLE_BORDER
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	row.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	row.add_child(hbox)

	hbox.add_child(_make_header_cell(tr("VICTORY_RR_FORMULA_COL_FACTOR"), 0.35))
	hbox.add_child(_make_header_cell(tr("VICTORY_RR_FORMULA_COL_VALUE"), 0.20))
	hbox.add_child(_make_header_cell(tr("VICTORY_RR_FORMULA_COL_CONTRIBUTION"), 0.20))
	hbox.add_child(_make_header_cell(tr("VICTORY_RR_FORMULA_COL_INTERMEDIATE"), 0.25))

	table_vbox.add_child(row)


func _add_data_row(
	icon_name: String, icon_color: Color,
	factor: String, value: String, contribution: String,
	intermediate: float, _prev_running: float,
	value_color: Color = BRIGHT_TEXT
) -> float:
	var row := PanelContainer.new()
	row.custom_minimum_size.y = 44

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_width_bottom = 1
	style.border_color = ROW_BORDER
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	row.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	row.add_child(hbox)

	# Иконка
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(20, 20)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_tex := UiIconHelper.load_tinted_icon(icon_name, icon_color, 20)
	if icon_tex:
		icon_rect.texture = icon_tex
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	icon_rect.size_flags_stretch_ratio = 0.05
	hbox.add_child(icon_rect)

	# Фактор
	hbox.add_child(_make_data_cell(factor, 0.30, MUTED_TEXT, 15, false))
	# Значение
	hbox.add_child(_make_data_cell(value, 0.20, value_color, 15, false))
	# Вклад
	hbox.add_child(_make_data_cell(contribution, 0.20, ACCENT, 15, false))
	# Промежуточный
	hbox.add_child(_make_data_cell("%d" % int(round(intermediate)), 0.25, BRIGHT_TEXT, 15, false))

	table_vbox.add_child(row)
	return intermediate


func _make_header_cell(text: String, stretch: float) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_stretch_ratio = stretch
	label.add_theme_color_override("font_color", HEADER_TEXT)
	label.add_theme_font_size_override("font_size", 12)
	return label


func _make_data_cell(text: String, stretch: float, color: Color, font_size: int, _bold: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_stretch_ratio = stretch
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _stabilize_close_button(btn: Button) -> void:
	if btn == null:
		return
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.expand_icon = false
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	if btn.has_meta("_ui_hover_enabled"):
		btn.remove_meta("_ui_hover_enabled")
	var base_style := btn.get_theme_stylebox("normal")
	if base_style is StyleBoxFlat:
		var dup := (base_style as StyleBoxFlat).duplicate() as StyleBoxFlat
		for state in ["hover", "pressed", "focus", "disabled"]:
			btn.add_theme_stylebox_override(state, dup)
	btn.pivot_offset = Vector2.ZERO
	btn.scale = Vector2.ONE


func _set_final_calc(base: float, multiplier: float, run_rr: int) -> void:
	var scale := _RhythmRating.GLOBAL_OUTPUT_SCALE
	if final_formula_label:
		if is_equal_approx(multiplier, 1.0):
			final_formula_label.text = "%d × %.2f = %d" % [int(round(base)), scale, run_rr]
		else:
			final_formula_label.text = "%d × %.2f × %.2f = %d" % [int(round(base)), multiplier, scale, run_rr]
	if final_rr_value:
		final_rr_value.text = "%d" % run_rr



func _on_back_pressed() -> void:
	if not visible:
		return
	MusicManager.play_modifier_deselect_sound()
	visible = false
	_detail_data.clear()
	queue_free()


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_back_pressed()
		get_viewport().set_input_as_handled()
