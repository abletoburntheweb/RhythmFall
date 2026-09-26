# scenes/victory_screen/victory_rr_whatif.gd
extends Control

const _RhythmRating = preload("res://logic/domain/rhythm/rhythm_rating.gd")
const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const _RunRewards = preload("res://logic/domain/rewards/run_rewards.gd")
const _GradeDisplay = preload("res://logic/ui/grade_display.gd")

const ACCENT := Color(0.94902, 0.701961, 0.352941, 1.0)
const COLOR_TEXT := Color(0.85, 0.9, 0.97, 1.0)
const COLOR_MUTED := Color(0.58, 0.64, 0.74, 0.92)
const COLOR_FAINT := Color(0.45, 0.52, 0.62, 0.85)
const COLOR_CAPTION := Color(0.72, 0.78, 0.88, 0.9)
const COLOR_ACCURACY := Color(0.47451, 0.890196, 0.835294, 1.0)
const COLOR_MULTIPLIER := Color(0.584314, 0.717647, 0.921569, 1.0)
const COLOR_GRADE := Color(0.929412, 0.784314, 0.435294, 1.0)
const COLOR_FULL_COMBO := Color(0.556863, 0.831373, 0.615686, 1.0)
const COLOR_CHART_RATING := Color(0.52549, 0.72549, 0.952941, 1.0)
const COLOR_DELTA_POS := Color(0.42, 0.88, 0.62, 0.95)
const COLOR_DELTA_NEG := Color(0.94, 0.48, 0.52, 0.95)
const COLOR_DELTA_ZERO := Color(0.78, 0.84, 0.94, 0.9)

const ICON_ACCURACY := "crosshair.svg"
const ICON_GRADE := "trophy.svg"
const ICON_FULL_COMBO := "star.svg"
const ICON_MULTIPLIER := "sparkles.svg"
const ICON_CHART_RATING := "gauge.svg"

@onready var title_label: Label = $CenterWrap/DialogPanel/Margin/DialogVBox/HeaderHBox/HeaderText/TitleLabel
@onready var subtitle_label: Label = $CenterWrap/DialogPanel/Margin/DialogVBox/HeaderHBox/HeaderText/SubtitleLabel
@onready var hero_icon: TextureRect = $CenterWrap/DialogPanel/Margin/DialogVBox/HeaderHBox/HeroIcon
@onready var content_vbox: VBoxContainer = $CenterWrap/DialogPanel/Margin/DialogVBox/ContentVBox
@onready var close_button: Button = $CenterWrap/DialogPanel/Margin/DialogVBox/CloseButton
@onready var background_rect: ColorRect = $Background

var _base_accuracy := 0.0
var _sim_accuracy := 0.0
var _chart_rating := 0
var _base_grade := ""
var _base_full_combo := false
var _sim_full_combo := false
var _base_multiplier := 1.0
var _sim_multiplier := 1.0
var _run_rr := 0

var _acc_slider: HSlider
var _acc_value_label: Label
var _grade_label: Label
var _mult_slider: HSlider
var _mult_value_label: Label
var _mult_current_label: Label
var _result_current_label: Label
var _result_simulated_label: Label
var _change_label: Label
var _breakdown_rows_vbox: VBoxContainer

var _section_style: StyleBoxFlat
var _sim_full_combo_buttons: Array = []


func _ready() -> void:
	add_to_group("app_modal_overlays")
	add_to_group("locale_refresh")
	_section_style = _make_section_style()
	_apply_tinted_icon(hero_icon, "zap.svg", ACCENT, 56)
	close_button.pressed.connect(_on_close_pressed)
	UiIconHelper.configure_button_icon(close_button, "arrow-left.svg", Color(0.85, 0.9, 0.97, 1.0), 16)
	_stabilize_close_button(close_button)
	_background_click_guard()
	call_deferred("apply_locale")


func _background_click_guard() -> void:
	UiClick.connect_clicked(background_rect, _on_close_pressed)


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
	_base_accuracy = clampf(p_accuracy, 0.0, 100.0)
	_sim_accuracy = _base_accuracy
	_chart_rating = maxi(p_chart_rating, 0)
	_base_grade = str(p_grade)
	_base_full_combo = bool(p_full_combo)
	_sim_full_combo = _base_full_combo
	_base_multiplier = p_multiplier
	_sim_multiplier = clampf(
		p_multiplier,
		_RunModifiers.theoretical_multiplier_min(),
		_RunModifiers.theoretical_multiplier_max()
	)
	_run_rr = maxi(p_run_rr, 0)
	_build_content()
	visible = true
	grab_focus()


func _build_content() -> void:
	for child in content_vbox.get_children():
		child.queue_free()
	_breakdown_rows_vbox = null

	# Two-column layout: left = params, right = result
	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.add_theme_constant_override("separation", 12)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_child(columns)

	# Left column: parameters
	var left_vbox := VBoxContainer.new()
	left_vbox.name = "ParamsColumn"
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_stretch_ratio = 1.0
	left_vbox.add_theme_constant_override("separation", 8)
	columns.add_child(left_vbox)

	var params_caption := Label.new()
	params_caption.text = tr("VICTORY_RR_WHATIF_PARAMS_TITLE").to_upper()
	params_caption.add_theme_font_size_override("font_size", 12)
	params_caption.add_theme_color_override("font_color", COLOR_CAPTION)
	left_vbox.add_child(params_caption)

	left_vbox.add_child(_build_accuracy_section())
	left_vbox.add_child(_build_full_combo_section())
	left_vbox.add_child(_build_multiplier_section())

	# Right column: result
	var right_vbox := VBoxContainer.new()
	right_vbox.name = "ResultColumn"
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_stretch_ratio = 1.0
	right_vbox.add_theme_constant_override("separation", 8)
	columns.add_child(right_vbox)

	var result_caption := Label.new()
	result_caption.text = tr("VICTORY_RR_WHATIF_RESULT_TITLE").to_upper()
	result_caption.add_theme_font_size_override("font_size", 12)
	result_caption.add_theme_color_override("font_color", COLOR_CAPTION)
	right_vbox.add_child(result_caption)

	right_vbox.add_child(_build_result_section())

	_recompute()



func _build_accuracy_section() -> PanelContainer:
	var section := _make_section()
	var vbox := _section_vbox(section)

	var title_row := _make_title_row(ICON_ACCURACY, COLOR_ACCURACY, tr("VICTORY_RR_WHATIF_ACCURACY").to_upper())
	vbox.add_child(title_row)

	var slider_row := HBoxContainer.new()
	slider_row.add_theme_constant_override("separation", 8)
	vbox.add_child(slider_row)

	_acc_slider = HSlider.new()
	_acc_slider.custom_minimum_size = Vector2(0, 24)
	_acc_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_acc_slider.min_value = 0.0
	_acc_slider.max_value = 100.0
	_acc_slider.step = 0.1
	_acc_slider.value = _sim_accuracy
	_acc_slider.value_changed.connect(_on_accuracy_changed)
	_acc_slider.gui_input.connect(_on_acc_slider_gui_input)
	_acc_slider.tooltip_text = tr("VICTORY_RR_WHATIF_DBLCLICK_HINT")
	slider_row.add_child(_acc_slider)

	var suffix := Label.new()
	suffix.custom_minimum_size = Vector2(108, 0)
	suffix.add_theme_font_size_override("font_size", 14)
	suffix.add_theme_color_override("font_color", COLOR_ACCURACY)
	suffix.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	suffix.clip_text = true
	slider_row.add_child(suffix)
	_acc_value_label = suffix

	vbox.add_child(_make_range_row(tr("VICTORY_RR_WHATIF_MIN"), "0%", tr("VICTORY_RR_WHATIF_MAX"), "100%"))

	var grade_row := HBoxContainer.new()
	grade_row.add_theme_constant_override("separation", 10)
	vbox.add_child(grade_row)

	var grade_icon := TextureRect.new()
	grade_icon.custom_minimum_size = Vector2(18, 18)
	grade_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grade_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_apply_tinted_icon(grade_icon, ICON_GRADE, COLOR_GRADE, 18)
	grade_row.add_child(grade_icon)

	var grade_name := Label.new()
	grade_name.text = tr("VICTORY_RR_WHATIF_GRADE")
	grade_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grade_name.add_theme_font_size_override("font_size", 13)
	grade_name.add_theme_color_override("font_color", COLOR_MUTED)
	grade_row.add_child(grade_name)

	_grade_label = Label.new()
	_grade_label.add_theme_font_size_override("font_size", 16)
	_grade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grade_row.add_child(_grade_label)
	return section


func _build_full_combo_section() -> PanelContainer:
	var section := _make_section()
	var vbox := _section_vbox(section)

	var title_row := _make_title_row(ICON_FULL_COMBO, COLOR_FULL_COMBO, tr("VICTORY_RR_WHATIF_FULL_COMBO").to_upper())
	vbox.add_child(title_row)

	var toggle_row := HBoxContainer.new()
	toggle_row.add_theme_constant_override("separation", 8)
	vbox.add_child(toggle_row)

	var group := ButtonGroup.new()
	group.allow_unpress = false
	var on_btn := _make_toggle_button(tr("VICTORY_RR_WHATIF_ON"), group)
	var off_btn := _make_toggle_button(tr("VICTORY_RR_WHATIF_OFF"), group)
	on_btn.toggled.connect(_on_fc_toggled.bind(true))
	off_btn.toggled.connect(_on_fc_toggled.bind(false))
	toggle_row.add_child(on_btn)
	toggle_row.add_child(off_btn)
	if _sim_full_combo:
		on_btn.button_pressed = true
	else:
		off_btn.button_pressed = true
	_refresh_toggle_styles(on_btn, off_btn)
	_sim_full_combo_buttons = [on_btn, off_btn]
	return section


func _build_multiplier_section() -> PanelContainer:
	var section := _make_section()
	var vbox := _section_vbox(section)

	var title_row := _make_title_row(ICON_MULTIPLIER, COLOR_MULTIPLIER, tr("VICTORY_RR_WHATIF_MULTIPLIER").to_upper())
	vbox.add_child(title_row)

	var slider_row := HBoxContainer.new()
	slider_row.add_theme_constant_override("separation", 8)
	vbox.add_child(slider_row)

	var mult_min := _RunModifiers.theoretical_multiplier_min()
	var mult_max := _RunModifiers.theoretical_multiplier_max()
	_mult_slider = HSlider.new()
	_mult_slider.custom_minimum_size = Vector2(0, 24)
	_mult_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mult_slider.min_value = mult_min
	_mult_slider.max_value = mult_max
	_mult_slider.step = 0.01
	_mult_slider.value = _sim_multiplier
	_mult_slider.value_changed.connect(_on_multiplier_changed)
	_mult_slider.gui_input.connect(_on_mult_slider_gui_input)
	_mult_slider.tooltip_text = tr("VICTORY_RR_WHATIF_DBLCLICK_HINT")
	slider_row.add_child(_mult_slider)

	var suffix := Label.new()
	suffix.custom_minimum_size = Vector2(108, 0)
	suffix.add_theme_font_size_override("font_size", 14)
	suffix.add_theme_color_override("font_color", COLOR_MULTIPLIER)
	suffix.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	suffix.clip_text = true
	slider_row.add_child(suffix)
	_mult_value_label = suffix

	vbox.add_child(_make_range_row(
		tr("VICTORY_RR_WHATIF_MIN"),
		"×%.2f" % mult_min,
		tr("VICTORY_RR_WHATIF_MAX"),
		"×%.2f" % mult_max
	))

	_mult_current_label = Label.new()
	_mult_current_label.add_theme_font_size_override("font_size", 11)
	_mult_current_label.add_theme_color_override("font_color", COLOR_FAINT)
	vbox.add_child(_mult_current_label)
	return section


func _build_chart_section() -> PanelContainer:
	var section := _make_section()
	var vbox := _section_vbox(section)

	var title_row := _make_title_row(ICON_CHART_RATING, COLOR_CHART_RATING, tr("VICTORY_RR_WHATIF_CHART_RATING").to_upper())
	var value := _make_title_value("%d/10" % _chart_rating)
	value.add_theme_color_override("font_color", COLOR_CHART_RATING)
	title_row.add_child(value)
	vbox.add_child(title_row)

	var note := Label.new()
	note.text = tr("VICTORY_RR_WHATIF_CHART_NOTE")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", COLOR_FAINT)
	vbox.add_child(note)
	return section


func _build_result_section() -> PanelContainer:
	var section := _make_section()
	var vbox := _section_vbox(section)

	# Current -> Simulated row
	var comparison_row := HBoxContainer.new()
	comparison_row.add_theme_constant_override("separation", 12)
	comparison_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(comparison_row)

	# Current RR box
	var current_box := VBoxContainer.new()
	current_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	current_box.size_flags_stretch_ratio = 1.0
	current_box.add_theme_constant_override("separation", 2)
	comparison_row.add_child(current_box)

	var current_caption := Label.new()
	current_caption.text = tr("VICTORY_RR_WHATIF_CURRENT_CAPTION").to_upper()
	current_caption.add_theme_font_size_override("font_size", 10)
	current_caption.add_theme_color_override("font_color", COLOR_CAPTION)
	current_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current_box.add_child(current_caption)

	_result_current_label = Label.new()
	_result_current_label.add_theme_font_size_override("font_size", 28)
	_result_current_label.add_theme_color_override("font_color", COLOR_TEXT)
	_result_current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current_box.add_child(_result_current_label)

	# Arrow
	var arrow := Label.new()
	arrow.text = "→"
	arrow.add_theme_font_size_override("font_size", 20)
	arrow.add_theme_color_override("font_color", COLOR_FAINT)
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	comparison_row.add_child(arrow)

	# Simulated RR box
	var simulated_box := VBoxContainer.new()
	simulated_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	simulated_box.size_flags_stretch_ratio = 1.0
	simulated_box.add_theme_constant_override("separation", 2)
	comparison_row.add_child(simulated_box)

	var simulated_caption := Label.new()
	simulated_caption.text = tr("VICTORY_RR_WHATIF_SIMULATED_CAPTION").to_upper()
	simulated_caption.add_theme_font_size_override("font_size", 10)
	simulated_caption.add_theme_color_override("font_color", COLOR_CAPTION)
	simulated_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	simulated_box.add_child(simulated_caption)

	_result_simulated_label = Label.new()
	_result_simulated_label.add_theme_font_size_override("font_size", 28)
	_result_simulated_label.add_theme_color_override("font_color", ACCENT)
	_result_simulated_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	simulated_box.add_child(_result_simulated_label)

	# Delta label
	_change_label = Label.new()
	_change_label.add_theme_font_size_override("font_size", 14)
	_change_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_change_label)

	# Breakdown section
	var breakdown_caption := Label.new()
	breakdown_caption.text = tr("VICTORY_RR_WHATIF_BREAKDOWN_TITLE").to_upper()
	breakdown_caption.add_theme_font_size_override("font_size", 11)
	breakdown_caption.add_theme_color_override("font_color", COLOR_CAPTION)
	vbox.add_child(breakdown_caption)

	_breakdown_rows_vbox = VBoxContainer.new()
	_breakdown_rows_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(_breakdown_rows_vbox)
	return section


func _recompute() -> void:
	var sim_grade := _RunRewards.compute_grade(_sim_accuracy)
	var simulated := _RhythmRating.compute_from_parts(
		_sim_accuracy, _chart_rating, sim_grade, _sim_full_combo, _sim_multiplier
	)
	if _grade_label:
		_grade_label.text = sim_grade
		_grade_label.add_theme_color_override("font_color", _GradeDisplay.grade_color(sim_grade))
	if _acc_value_label:
		_acc_value_label.text = "%.1f%%" % _sim_accuracy
	if _mult_value_label:
		_mult_value_label.text = "×%.2f" % _sim_multiplier
	if _mult_current_label:
		_mult_current_label.text = tr("VICTORY_RR_WHATIF_MULT_CURRENT_FMT") % _base_multiplier
	if _result_current_label:
		_result_current_label.text = str(_run_rr)
	if _result_simulated_label:
		_result_simulated_label.text = str(simulated)
	if _change_label:
		var delta := simulated - _run_rr
		if delta == 0:
			_change_label.text = tr("VICTORY_RR_WHATIF_CHANGE_ZERO")
			_change_label.add_theme_color_override("font_color", COLOR_DELTA_ZERO)
		else:
			_change_label.text = tr("VICTORY_RR_WHATIF_CHANGE_FMT") % delta
			_change_label.add_theme_color_override(
				"font_color", COLOR_DELTA_POS if delta > 0 else COLOR_DELTA_NEG
			)
	_refresh_breakdown(simulated)


## Exact sequential decomposition in fixed order (accuracy → full combo →
## multiplier): each step recomputes with the real formula, so the row deltas
## always sum to the total change even though the multiplier interacts
## multiplicatively with the base. Rows are shown only for changed parameters.
## Новый формат — каждая строка показывает что было → что стало → изменение RR,
## и внизу ИТОГО. Использует существующие tr-ключи для Yes/No, чтобы в RU
## показывать "Да/Нет", а не "Yes/No".
func _refresh_breakdown(simulated: int) -> void:
	if _breakdown_rows_vbox == null:
		return
	for child in _breakdown_rows_vbox.get_children():
		child.queue_free()

	var sim_grade := _RunRewards.compute_grade(_sim_accuracy)
	var base_grade := _RunRewards.compute_grade(_base_accuracy)
	var base_rr := _RhythmRating.compute_from_parts(
		_base_accuracy, _chart_rating, base_grade, _base_full_combo, _base_multiplier
	)
	var acc_changed := not is_equal_approx(_sim_accuracy, _base_accuracy)
	var fc_changed := _sim_full_combo != _base_full_combo
	var mult_changed := not is_equal_approx(_sim_multiplier, _base_multiplier)

	var cursor := base_rr
	var rows_added := 0
	if acc_changed:
		var after_acc := _RhythmRating.compute_from_parts(
			_sim_accuracy, _chart_rating, sim_grade, _base_full_combo, _base_multiplier
		)
		var delta := after_acc - cursor
		cursor = after_acc
		var old_s := "%.1f%%" % _base_accuracy
		var new_s := "%.1f%%" % _sim_accuracy
		_add_breakdown_change_row(ICON_ACCURACY, COLOR_ACCURACY,
			tr("VICTORY_RR_WHATIF_ACCURACY").to_upper(), old_s, new_s, delta)
		rows_added += 1
	if fc_changed:
		var after_fc := _RhythmRating.compute_from_parts(
			_sim_accuracy, _chart_rating, sim_grade, _sim_full_combo, _base_multiplier
		)
		var delta := after_fc - cursor
		cursor = after_fc
		var old_s := tr("VICTORY_RR_COMPARE_YES") if _base_full_combo else tr("VICTORY_RR_COMPARE_NO")
		var new_s := tr("VICTORY_RR_COMPARE_YES") if _sim_full_combo else tr("VICTORY_RR_COMPARE_NO")
		_add_breakdown_change_row(ICON_FULL_COMBO, COLOR_FULL_COMBO,
			tr("VICTORY_RR_WHATIF_FULL_COMBO").to_upper(), old_s, new_s, delta)
		rows_added += 1
	if mult_changed:
		var delta := simulated - cursor
		var old_s := "×%.2f" % _base_multiplier
		var new_s := "×%.2f" % _sim_multiplier
		_add_breakdown_change_row(ICON_MULTIPLIER, COLOR_MULTIPLIER,
			tr("VICTORY_RR_WHATIF_MULTIPLIER").to_upper(), old_s, new_s, delta)
		rows_added += 1

	if rows_added > 0:
		var sep := HSeparator.new()
		sep.add_theme_stylebox_override("separator", _make_breakdown_separator_style())
		_breakdown_rows_vbox.add_child(sep)

	var total_delta := simulated - base_rr
	_add_breakdown_total_row(total_delta)


func _make_breakdown_separator_style() -> StyleBoxLine:
	var s := StyleBoxLine.new()
	s.color = Color(1, 1, 1, 0.08)
	s.thickness = 1
	return s


func _add_breakdown_change_row(icon_file: String, icon_color: Color, title: String, old_text: String, new_text: String, delta: int) -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	_breakdown_rows_vbox.add_child(vbox)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 6)
	vbox.add_child(title_row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(16, 16)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_apply_tinted_icon(icon, icon_file, icon_color, 16)
	title_row.add_child(icon)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 11)
	title_lbl.add_theme_color_override("font_color", COLOR_CAPTION)
	title_row.add_child(title_lbl)

	var trans_row := HBoxContainer.new()
	trans_row.add_theme_constant_override("separation", 8)
	vbox.add_child(trans_row)

	var trans_lbl := Label.new()
	trans_lbl.text = "%s → %s" % [old_text, new_text]
	trans_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trans_lbl.add_theme_font_size_override("font_size", 13)
	trans_lbl.add_theme_color_override("font_color", COLOR_MUTED)
	trans_row.add_child(trans_lbl)

	var delta_lbl := Label.new()
	delta_lbl.text = ("%+d RR" % delta) if delta != 0 else "0 RR"
	delta_lbl.add_theme_font_size_override("font_size", 13)
	delta_lbl.add_theme_color_override(
		"font_color", COLOR_DELTA_POS if delta > 0 else (COLOR_DELTA_NEG if delta < 0 else COLOR_DELTA_ZERO)
	)
	delta_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	trans_row.add_child(delta_lbl)


func _add_breakdown_total_row(total_delta: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_breakdown_rows_vbox.add_child(row)

	var title := Label.new()
	var total_key := "VICTORY_RR_WHATIF_TOTAL"
	var total_text := tr(total_key)
	if total_text == total_key or total_text.strip_edges() == "":
		total_text = tr("VICTORY_RR_DETAIL_TOTAL")
		# "Итого RR" -> "ИТОГО"
		if total_text.ends_with(" RR"):
			total_text = total_text.trim_suffix(" RR")
		total_text = total_text.to_upper()
	else:
		total_text = total_text.to_upper()
	title.text = total_text
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", COLOR_CAPTION)
	row.add_child(title)

	var value := Label.new()
	value.text = ("%+d RR" % total_delta) if total_delta != 0 else "0 RR"
	value.add_theme_font_size_override("font_size", 13)
	value.add_theme_color_override(
		"font_color", COLOR_DELTA_POS if total_delta > 0 else (COLOR_DELTA_NEG if total_delta < 0 else COLOR_DELTA_ZERO)
	)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)


## Legacy single-row helper сохранён для совместимости, но новый формат использует _add_breakdown_change_row.
func _add_breakdown_row(icon_file: String, icon_color: Color, name_text: String, delta: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_breakdown_rows_vbox.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(16, 16)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_apply_tinted_icon(icon, icon_file, icon_color, 16)
	row.add_child(icon)

	var name := Label.new()
	name.text = name_text
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.add_theme_font_size_override("font_size", 12)
	name.add_theme_color_override("font_color", COLOR_MUTED)
	row.add_child(name)

	var value := Label.new()
	value.text = ("%+d RR" % delta) if delta != 0 else "0 RR"
	value.add_theme_font_size_override("font_size", 12)
	value.add_theme_color_override(
		"font_color", COLOR_DELTA_POS if delta > 0 else (COLOR_DELTA_NEG if delta < 0 else COLOR_DELTA_ZERO)
	)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)



func _on_accuracy_changed(value: float) -> void:
	_sim_accuracy = clampf(value, 0.0, 100.0)
	_recompute()


func _on_multiplier_changed(value: float) -> void:
	_sim_multiplier = value
	_recompute()


func _on_acc_slider_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click and event.pressed:
		# Сброс к исходному значению забега, триггерит _on_accuracy_changed -> _recompute
		if _acc_slider:
			_acc_slider.value = _base_accuracy
		get_viewport().set_input_as_handled()


func _on_mult_slider_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click and event.pressed:
		if _mult_slider:
			_mult_slider.value = _base_multiplier
		get_viewport().set_input_as_handled()


func _on_fc_toggled(pressed: bool, target: bool) -> void:
	if pressed:
		_sim_full_combo = target
		_recompute()


func _refresh_toggle_styles(on_btn: Button, off_btn: Button) -> void:
	for btn in [on_btn, off_btn]:
		btn.add_theme_color_override(
			"font_color", ACCENT if btn.button_pressed else Color(0.72, 0.78, 0.88, 1.0)
		)


func _make_toggle_button(text: String, group: ButtonGroup) -> Button:
	var btn := Button.new()
	btn.toggle_mode = true
	btn.button_group = group
	btn.text = text
	btn.custom_minimum_size = Vector2(96, 34)
	btn.theme_type_variation = &"FlatButton"
	btn.toggled.connect(_refresh_toggle_styles_on_pressed)
	return btn


func _refresh_toggle_styles_on_pressed(_pressed: bool = false) -> void:
	for btn in _sim_full_combo_buttons:
		if btn is Button:
			btn.add_theme_color_override(
				"font_color", ACCENT if btn.button_pressed else Color(0.72, 0.78, 0.88, 1.0)
			)


func _make_section() -> PanelContainer:
	var section := PanelContainer.new()
	section.add_theme_stylebox_override("panel", _section_style)
	return section


func _section_vbox(section: PanelContainer) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 2)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	section.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)
	return vbox


func _make_title_row(icon_file: String, icon_color: Color, caption: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(18, 18)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_apply_tinted_icon(icon, icon_file, icon_color, 18)
	row.add_child(icon)

	var label := Label.new()
	label.text = caption
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", COLOR_CAPTION)
	row.add_child(label)
	return row


func _make_title_value(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", COLOR_TEXT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return label


func _make_range_row(min_caption: String, min_text: String, max_caption: String, max_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var min_label := Label.new()
	min_label.text = "%s · %s" % [min_caption, min_text]
	min_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	min_label.add_theme_font_size_override("font_size", 11)
	min_label.add_theme_color_override("font_color", COLOR_FAINT)
	row.add_child(min_label)

	var max_label := Label.new()
	max_label.text = "%s · %s" % [max_caption, max_text]
	max_label.add_theme_font_size_override("font_size", 11)
	max_label.add_theme_color_override("font_color", COLOR_FAINT)
	max_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(max_label)
	return row


func _make_section_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.content_margin_left = 14.0
	style.content_margin_top = 12.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 12.0
	style.bg_color = Color(0.05, 0.06, 0.09, 0.97)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.94902, 0.701961, 0.352941, 0.18)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	return style


func _apply_tinted_icon(icon: TextureRect, file_name: String, tint: Color, display_size: int) -> void:
	if icon == null:
		return
	var tex := UiIconHelper.load_tinted_icon(file_name, tint, UiIconHelper.raster_size_for_display(display_size))
	if tex:
		icon.texture = tex
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _stabilize_close_button(btn: Button) -> void:
	if btn == null:
		return
	# Переиспользуем тот же паттерн что и в RR Breakdown (где иконка уже не двигается):
	# фиксируем выравнивание, отключаем hover-tween, выравниваем stylebox'ы.
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.expand_icon = false
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	if btn.has_meta("_ui_hover_enabled"):
		btn.remove_meta("_ui_hover_enabled")
	# Убедиться что focus/hover/pressed не дают смещения за счёт разных content_margin.
	var base_style := btn.get_theme_stylebox("normal")
	if base_style is StyleBoxFlat:
		var dup := (base_style as StyleBoxFlat).duplicate() as StyleBoxFlat
		for state in ["hover", "pressed", "focus", "disabled"]:
			btn.add_theme_stylebox_override(state, dup)
	btn.pivot_offset = Vector2.ZERO
	btn.scale = Vector2.ONE


func apply_locale() -> void:
	if title_label:
		title_label.text = tr("VICTORY_RR_WHATIF_TITLE").to_upper()
	if subtitle_label:
		subtitle_label.text = tr("VICTORY_RR_WHATIF_SUBTITLE")
	if close_button:
		close_button.text = tr("VICTORY_REWARD_BTN_CLOSE").to_upper()


func _on_close_pressed() -> void:
	if not visible:
		return
	MusicManager.play_modifier_deselect_sound()
	visible = false
	queue_free()


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		accept_event()
		_on_close_pressed()