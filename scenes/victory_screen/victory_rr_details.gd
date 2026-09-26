extends Control

const _RhythmRating = preload("res://logic/domain/rhythm/rhythm_rating.gd")
const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const _ChartDifficultyAnalyzer = preload("res://logic/domain/charts/chart_difficulty_analyzer.gd")
const _FormulaScene = preload("res://scenes/victory_screen/victory_rr_formula.tscn")
const _WhatIfScene = preload("res://scenes/victory_screen/victory_rr_whatif.tscn")

const ACCENT := Color(0.94902, 0.701961, 0.352941, 1.0)

const ICON_ACCURACY := "crosshair.svg"
const ICON_RATING := "zap.svg"
const ICON_GRADE := "trophy.svg"
const ICON_FULL_COMBO := "star.svg"
const ICON_MULTIPLIER := "sparkles.svg"

const COLOR_ACCURACY := Color(0.47451, 0.890196, 0.835294, 1.0)
const COLOR_RATING := Color(0.52549, 0.72549, 0.952941, 1.0)
const COLOR_GRADE := Color(0.929412, 0.784314, 0.435294, 1.0)
const COLOR_FULL_COMBO := Color(0.556863, 0.831373, 0.615686, 1.0)
const COLOR_MULTIPLIER := Color(0.584314, 0.717647, 0.921569, 1.0)

const HERO_ICON_FILE := "zap.svg"
const BEST_ICON_FILE := "trophy.svg"

const COLOR_DELTA_POS := Color(0.42, 0.88, 0.62, 0.95)
const COLOR_DELTA_NEG := Color(0.94, 0.48, 0.52, 0.95)
const COLOR_MUTED := Color(0.58, 0.64, 0.74, 0.5)

@onready var hero_icon: TextureRect = $CenterWrap/DialogPanel/Margin/DialogVBox/HeaderHBox/HeroIcon
@onready var title_label: Label = $CenterWrap/DialogPanel/Margin/DialogVBox/HeaderHBox/HeaderText/TitleLabel
@onready var subtitle_label: Label = $CenterWrap/DialogPanel/Margin/DialogVBox/HeaderHBox/HeaderText/SubtitleLabel
@onready var hero_total_label: Label = $CenterWrap/DialogPanel/Margin/DialogVBox/ContentHBox/LeftHero/TotalHBox/HeroTotalLabel
@onready var hero_total_icon: TextureRect = $CenterWrap/DialogPanel/Margin/DialogVBox/ContentHBox/LeftHero/TotalHBox/HeroTotalIcon
@onready var hero_caption_label: Label = $CenterWrap/DialogPanel/Margin/DialogVBox/ContentHBox/LeftHero/HeroCaptionLabel
@onready var best_icon: TextureRect = $CenterWrap/DialogPanel/Margin/DialogVBox/ContentHBox/LeftHero/BestHBox/BestIcon
@onready var best_value_label: Label = $CenterWrap/DialogPanel/Margin/DialogVBox/ContentHBox/LeftHero/BestHBox/BestValueLabel
@onready var best_caption_label: Label = $CenterWrap/DialogPanel/Margin/DialogVBox/ContentHBox/LeftHero/BestHBox/BestCaptionLabel
@onready var cards_title_label: Label = $CenterWrap/DialogPanel/Margin/DialogVBox/ContentHBox/RightContent/CardsTitleLabel
@onready var cards_hbox: HBoxContainer = $CenterWrap/DialogPanel/Margin/DialogVBox/ContentHBox/RightContent/CardsHBox
@onready var delta_value_label: Label = $CenterWrap/DialogPanel/Margin/DialogVBox/BottomHBox/DeltaBox/DeltaValueLabel
@onready var delta_num_label: Label = $CenterWrap/DialogPanel/Margin/DialogVBox/BottomHBox/DeltaBox/DeltaNumLabel
@onready var delta_caption_label: Label = $CenterWrap/DialogPanel/Margin/DialogVBox/BottomHBox/DeltaBox/DeltaCaptionLabel
@onready var delta_box: VBoxContainer = $CenterWrap/DialogPanel/Margin/DialogVBox/BottomHBox/DeltaBox
@onready var summary_value_label: Label = $CenterWrap/DialogPanel/Margin/DialogVBox/BottomHBox/SummaryHBox/SummaryValueLabel
@onready var summary_delta_label: Label = $CenterWrap/DialogPanel/Margin/DialogVBox/BottomHBox/SummaryHBox/SummaryDeltaLabel
@onready var summary_best_icon: TextureRect = $CenterWrap/DialogPanel/Margin/DialogVBox/BottomHBox/SummaryHBox/SummaryBestHBox/SummaryBestIcon
@onready var summary_best_label: Label = $CenterWrap/DialogPanel/Margin/DialogVBox/BottomHBox/SummaryHBox/SummaryBestHBox/SummaryBestLabel
@onready var summary_best_value_label: Label = $CenterWrap/DialogPanel/Margin/DialogVBox/BottomHBox/SummaryHBox/SummaryBestHBox/SummaryBestValueLabel
@onready var formula_toggle_button: Button = $CenterWrap/DialogPanel/Margin/DialogVBox/TopButtonsHBox/FormulaButton
@onready var what_if_button: Button = $CenterWrap/DialogPanel/Margin/DialogVBox/TopButtonsHBox/WhatIfButton
@onready var close_button: Button = $CenterWrap/DialogPanel/Margin/DialogVBox/CloseButton
@onready var takeaway_label: Label = $CenterWrap/DialogPanel/Margin/DialogVBox/ContentHBox/RightContent/TakeawayLabel
@onready var base_rating_note_label: Label = $CenterWrap/DialogPanel/Margin/DialogVBox/ContentHBox/RightContent/BaseRatingNoteLabel

signal details_closed

var _detail_data: Dictionary = {}


func _ready() -> void:
	add_to_group("locale_refresh")
	visible = false
	_apply_hero_icons()
	close_button.pressed.connect(_on_back_pressed)
	formula_toggle_button.pressed.connect(_open_formula_details)
	what_if_button.pressed.connect(_open_what_if_details)
	UiIconHelper.configure_button_icon(close_button, "arrow-left.svg", Color(0.85, 0.9, 0.97, 1.0), 16)
	_stabilize_close_button(close_button)
	UiIconHelper.configure_button_icon(formula_toggle_button, "scroll-text.svg", ACCENT)
	UiIconHelper.configure_button_icon(what_if_button, "sparkles.svg", COLOR_MULTIPLIER)
	UiClick.connect_clicked(self, _on_back_pressed)
	call_deferred("apply_locale")
	call_deferred("_warm_whatif_icon_cache")


func _apply_hero_icons() -> void:
	_apply_tinted_icon(hero_icon, HERO_ICON_FILE, 64)
	_apply_tinted_icon(hero_total_icon, HERO_ICON_FILE, 28)
	_apply_tinted_icon(summary_best_icon, BEST_ICON_FILE, 20)


func _apply_tinted_icon(icon: TextureRect, file_name: String, display_size: int) -> void:
	if icon == null:
		return
	var tex := UiIconHelper.load_tinted_icon(file_name, ACCENT, UiIconHelper.raster_size_for_display(display_size))
	if tex:
		icon.texture = tex
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _open_formula_details() -> void:
	MusicManager.play_modifier_select_sound()
	var modal: Control = _FormulaScene.instantiate()
	add_child(modal)
	UiInteractionApplier.apply_from_engine(modal)
	modal.add_to_group("app_modal_overlays")
	modal.show_details(
		float(_detail_data.get("accuracy", 0.0)),
		int(_detail_data.get("chart_rating", 0)),
		str(_detail_data.get("grade", "")),
		bool(_detail_data.get("full_combo", false)),
		_detail_data.get("modifiers", []),
		_detail_data.get("modifier_params", {}),
		float(_detail_data.get("multiplier", 1.0)),
		int(_detail_data.get("run_rr", 0))
	)


func _get_loading_overlay():
	var ge = get_tree().root.get_node_or_null("GameEngine")
	if ge != null and ge.has_method("get_loading_overlay"):
		return ge.get_loading_overlay()
	return null


func _open_what_if_details() -> void:
	MusicManager.play_modifier_select_sound()
	var overlay = _get_loading_overlay()
	if overlay:
		overlay.show_loading(tr("UI_LOADING_WAIT"), true)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	var modal: Control = _WhatIfScene.instantiate()
	add_child(modal)
	UiInteractionApplier.apply_from_engine(modal)
	modal.add_to_group("app_modal_overlays")
	modal.show_details(
		float(_detail_data.get("accuracy", 0.0)),
		int(_detail_data.get("chart_rating", 0)),
		str(_detail_data.get("grade", "")),
		bool(_detail_data.get("full_combo", false)),
		_detail_data.get("modifiers", []),
		_detail_data.get("modifier_params", {}),
		float(_detail_data.get("multiplier", 1.0)),
		int(_detail_data.get("run_rr", 0))
	)
	if overlay:
		overlay.hide_loading()


func apply_locale() -> void:
	if title_label:
		title_label.text = tr("VICTORY_RR_DETAIL_TITLE").to_upper()
	if subtitle_label:
		subtitle_label.text = tr("VICTORY_RR_DETAIL_SUBTITLE")
	if hero_caption_label:
		hero_caption_label.text = tr("VICTORY_RR_DETAIL_HERO_CAPTION").to_upper()
	if cards_title_label:
		cards_title_label.text = tr("VICTORY_RR_DETAIL_CONTRIBUTION_TITLE").to_upper()
	if takeaway_label:
		takeaway_label.text = tr("VICTORY_RR_DETAIL_TAKEAWAY")
	if base_rating_note_label:
		base_rating_note_label.text = tr("VICTORY_RR_DETAIL_BASE_NOTE")
	if delta_caption_label:
		delta_caption_label.text = tr("VICTORY_RR_DETAIL_TO_BEST")
	if formula_toggle_button:
		formula_toggle_button.text = tr("VICTORY_RR_DETAIL_FORMULA_TITLE").to_upper()
	if what_if_button:
		what_if_button.text = tr("VICTORY_RR_WHATIF_BUTTON").to_upper()
	if close_button:
		close_button.text = tr("VICTORY_REWARD_BTN_CLOSE").to_upper()
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
	p_run_rr: int,
	p_best_rr: int = 0,
	p_is_repeat: bool = false,
	p_best_run: Dictionary = {}
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
		"best_rr": p_best_rr,
		"is_repeat": p_is_repeat,
		"best_run": p_best_run,
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
	var best_rr := int(_detail_data.get("best_rr", 0))
	var is_repeat := bool(_detail_data.get("is_repeat", false))
	var best_run: Dictionary = _detail_data.get("best_run", {})
	var has_best := not best_run.is_empty() and best_rr > 0
	var cur_mods: Array = _detail_data.get("modifiers", [])

	var acc_pts := p_accuracy * _RhythmRating.ACCURACY_WEIGHT
	var rating_pts := float(maxi(p_chart_rating, 0)) * _RhythmRating.CHART_RATING_WEIGHT
	var grade_pts := _RhythmRating.grade_bonus(p_grade)
	var fc_pts := _RhythmRating.FULL_COMBO_BONUS if p_full_combo else 0.0

	var best_accuracy := float(best_run.get("accuracy", 0.0)) if has_best else 0.0
	var best_rating := int(best_run.get("chart_rating", 0)) if has_best else 0
	var best_grade := str(best_run.get("grade", "")) if has_best else ""
	var best_fc := bool(best_run.get("full_combo", false)) if has_best else false
	var best_multiplier := float(best_run.get("multiplier", 1.0)) if has_best else 1.0
	var best_mods: Array = best_run.get("modifiers", []) if has_best else []
	if not best_mods is Array:
		best_mods = []

	var best_acc_pts := best_accuracy * _RhythmRating.ACCURACY_WEIGHT if has_best else 0.0
	var best_rating_pts := float(maxi(best_rating, 0)) * _RhythmRating.CHART_RATING_WEIGHT if has_best else 0.0
	var best_grade_pts := _RhythmRating.grade_bonus(best_grade) if has_best else 0.0
	var best_fc_pts := _RhythmRating.FULL_COMBO_BONUS if best_fc else 0.0

	if hero_total_label:
		hero_total_label.text = str(run_rr)

	if best_rr > 0 and best_value_label:
		best_value_label.text = str(best_rr)
		best_value_label.add_theme_color_override(
			"font_color",
			ACCENT if run_rr >= best_rr else Color(0.72, 0.78, 0.88, 1.0)
		)
		best_value_label.visible = true
		best_icon.visible = true
		_apply_tinted_icon(best_icon, BEST_ICON_FILE, 20)
		if best_caption_label:
			best_caption_label.visible = true
			if is_repeat:
				best_caption_label.text = tr("VICTORY_RR_DETAIL_REPEAT_CAPTION").to_upper()
			else:
				best_caption_label.text = (
					tr("VICTORY_RR_DETAIL_NEW_BEST").to_upper() if run_rr > best_rr
					else tr("VICTORY_RR_DETAIL_BEST_CAPTION").to_upper()
				)
	else:
		if best_value_label:
			best_value_label.visible = false
		if best_icon:
			best_icon.visible = false
		if best_caption_label:
			best_caption_label.visible = false

	for child in cards_hbox.get_children():
		child.queue_free()

	var card_data := [
		{
			"icon": ICON_ACCURACY,
			"color": COLOR_ACCURACY,
			"title": tr("VICTORY_RR_DETAIL_ROW_ACCURACY_TITLE"),
			"value": "%.1f%%" % p_accuracy,
			"cur_pts": acc_pts,
			"best_pts": best_acc_pts,
		},
		{
			"icon": ICON_RATING,
			"color": _ChartDifficultyAnalyzer.rating_color_for_decimal(float(p_chart_rating)),
			"title": tr("VICTORY_RR_DETAIL_ROW_RATING_TITLE"),
			"value": "%d/10" % p_chart_rating,
			"cur_pts": rating_pts,
			"best_pts": best_rating_pts,
		},
		{
			"icon": ICON_GRADE,
			"color": COLOR_GRADE,
			"title": tr("VICTORY_RR_DETAIL_ROW_GRADE_TITLE"),
			"value": p_grade if p_grade != "" else "—",
			"cur_pts": grade_pts,
			"best_pts": best_grade_pts,
		},
		{
			"icon": ICON_FULL_COMBO,
			"color": COLOR_FULL_COMBO,
			"title": tr("VICTORY_RR_DETAIL_ROW_FULL_COMBO_TITLE"),
			"value": tr("VICTORY_RR_COMPARE_YES") if p_full_combo else tr("VICTORY_RR_COMPARE_NO"),
			"cur_pts": fc_pts,
			"best_pts": best_fc_pts,
		},
		{
			"icon": ICON_MULTIPLIER,
			"color": COLOR_MULTIPLIER,
			"title": tr("VICTORY_RR_DETAIL_ROW_MULT_TITLE"),
			"value": "×%.2f" % p_multiplier,
			"cur_pts": p_multiplier,
			"best_pts": best_multiplier,
		},
	]

	for i in card_data.size():
		var cd: Dictionary = card_data[i]
		var card := _build_card(cd.icon, cd.color, cd.title, cd.value, cd.cur_pts, cd.best_pts, has_best, i == 4)
		cards_hbox.add_child(card)

	if delta_box:
		var delta_rr := run_rr - best_rr
		delta_box.visible = has_best and not is_repeat and delta_rr != 0
	if has_best and not is_repeat and delta_value_label and delta_num_label:
		var delta_rr := run_rr - best_rr
		if delta_rr >= 0:
			delta_value_label.text = "+%d RR" % delta_rr
			delta_num_label.text = "+%d" % delta_rr
			delta_value_label.add_theme_color_override("font_color", COLOR_DELTA_POS)
			delta_num_label.add_theme_color_override("font_color", COLOR_DELTA_POS)
		else:
			delta_value_label.text = "%d RR" % delta_rr
			delta_num_label.text = "%d" % delta_rr
			delta_value_label.add_theme_color_override("font_color", COLOR_DELTA_NEG)
			delta_num_label.add_theme_color_override("font_color", COLOR_DELTA_NEG)

	if summary_value_label:
		summary_value_label.text = str(run_rr)
	if summary_delta_label:
		if has_best:
			var delta_rr := run_rr - best_rr
			if is_repeat:
				summary_delta_label.text = tr("VICTORY_RR_DETAIL_REPEAT_LINE")
				summary_delta_label.add_theme_color_override("font_color", Color(0.78, 0.84, 0.94, 0.95))
			elif delta_rr > 0:
				summary_delta_label.text = "+%d RR" % delta_rr
				summary_delta_label.add_theme_color_override("font_color", COLOR_DELTA_POS)
			elif delta_rr == 0:
				summary_delta_label.text = "0 RR"
				summary_delta_label.add_theme_color_override("font_color", Color(0.72, 0.78, 0.88, 0.9))
			else:
				summary_delta_label.text = "%d RR" % delta_rr
				summary_delta_label.add_theme_color_override("font_color", COLOR_DELTA_NEG)
		else:
			summary_delta_label.text = ""
	if summary_best_value_label:
		summary_best_value_label.text = str(best_rr) if has_best else "—"

	if base_rating_note_label:
		base_rating_note_label.visible = (cur_mods.size() > 0)


func _build_card(
	icon_file: String,
	icon_color: Color,
	title: String,
	value_text: String,
	cur_pts: float,
	best_pts: float,
	has_best: bool,
	is_multiplier: bool
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(128, 0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.09, 0.97)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.94902, 0.701961, 0.352941, 0.18)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 10.0
	style.content_margin_top = 10.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var tex := UiIconHelper.load_tinted_icon(icon_file, icon_color, UiIconHelper.raster_size_for_display(28))
	if tex:
		icon.texture = tex
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	vbox.add_child(icon)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_color_override("font_color", Color(0.58, 0.64, 0.74, 0.92))
	title_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(title_lbl)

	var value_lbl := Label.new()
	value_lbl.text = value_text
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_lbl.add_theme_color_override("font_color", icon_color.lightened(0.08))
	value_lbl.add_theme_font_size_override("font_size", 18)
	vbox.add_child(value_lbl)

	var cur_val_lbl := Label.new()
	if is_multiplier:
		cur_val_lbl.text = "×%.2f" % cur_pts
	else:
		cur_val_lbl.text = "+%.1f" % cur_pts if cur_pts >= 0 else "%.1f" % cur_pts
	cur_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cur_val_lbl.add_theme_color_override("font_color", COLOR_DELTA_POS if cur_pts > 0 else Color(0.72, 0.78, 0.88, 0.9))
	cur_val_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(cur_val_lbl)

	var cur_cap_lbl := Label.new()
	cur_cap_lbl.text = tr("VICTORY_RR_DETAIL_CURRENT")
	cur_cap_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cur_cap_lbl.add_theme_color_override("font_color", COLOR_MUTED)
	cur_cap_lbl.add_theme_font_size_override("font_size", 10)
	vbox.add_child(cur_cap_lbl)

	var best_val_lbl := Label.new()
	if has_best:
		if is_multiplier:
			best_val_lbl.text = "×%.2f" % best_pts
		else:
			best_val_lbl.text = "+%.1f" % best_pts if best_pts >= 0 else "%.1f" % best_pts
		best_val_lbl.add_theme_color_override("font_color", COLOR_DELTA_POS if best_pts > 0 else Color(0.72, 0.78, 0.88, 0.9))
	else:
		best_val_lbl.text = "—"
		best_val_lbl.add_theme_color_override("font_color", COLOR_MUTED)
	best_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_val_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(best_val_lbl)

	var best_cap_lbl := Label.new()
	best_cap_lbl.text = tr("VICTORY_RR_DETAIL_BEST_LABEL")
	best_cap_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_cap_lbl.add_theme_color_override("font_color", COLOR_MUTED)
	best_cap_lbl.add_theme_font_size_override("font_size", 10)
	vbox.add_child(best_cap_lbl)

	var delta_lbl := Label.new()
	delta_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	delta_lbl.add_theme_font_size_override("font_size", 13)
	if has_best:
		if is_multiplier:
			var d := cur_pts - best_pts
			if absf(d) < 0.005:
				delta_lbl.text = "—"
				delta_lbl.add_theme_color_override("font_color", COLOR_MUTED)
			elif d > 0:
				delta_lbl.text = "+%.2f" % d
				delta_lbl.add_theme_color_override("font_color", COLOR_DELTA_POS)
			else:
				delta_lbl.text = "%.2f" % d
				delta_lbl.add_theme_color_override("font_color", COLOR_DELTA_NEG)
		else:
			var d := cur_pts - best_pts
			if absf(d) < 0.05:
				delta_lbl.text = "+0"
				delta_lbl.add_theme_color_override("font_color", COLOR_DELTA_POS)
			elif d > 0:
				delta_lbl.text = "+%.0f" % d
				delta_lbl.add_theme_color_override("font_color", COLOR_DELTA_POS)
			else:
				delta_lbl.text = "%.0f" % d
				delta_lbl.add_theme_color_override("font_color", COLOR_DELTA_NEG)
	else:
		delta_lbl.text = "—"
		delta_lbl.add_theme_color_override("font_color", COLOR_MUTED)
	vbox.add_child(delta_lbl)

	return panel


func _on_back_pressed() -> void:
	if not visible:
		return
	MusicManager.play_modifier_deselect_sound()
	visible = false
	_detail_data.clear()
	emit_signal("details_closed")


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _child_modal_open():
			return
		_on_back_pressed()


func _child_modal_open() -> bool:
	for child in get_children():
		if child is Control and child.visible and child.has_method("show_details"):
			return true
	return false


## Прогрев кэша иконок What-if, чтобы первое открытие не лагало на растеризации SVG.
## Использует тот же паттерн кэширования UiIconHelper, что и остальные экраны.
func _warm_whatif_icon_cache() -> void:
	# Размеры как в victory_rr_whatif.gd: title icon 18, breakdown icon 16, hero 56
	var pairs: Array = [
		["crosshair.svg", COLOR_ACCURACY, 18],
		["crosshair.svg", COLOR_ACCURACY, 16],
		["trophy.svg", COLOR_GRADE, 18],
		["star.svg", COLOR_FULL_COMBO, 18],
		["star.svg", COLOR_FULL_COMBO, 16],
		["sparkles.svg", COLOR_MULTIPLIER, 18],
		["sparkles.svg", COLOR_MULTIPLIER, 16],
		["gauge.svg", COLOR_RATING, 18],
		["zap.svg", ACCENT, 56],
		["zap.svg", ACCENT, 18],
		["zap.svg", ACCENT, 16],
	]
	for p in pairs:
		var file: String = str(p[0])
		var tint: Color = p[1] as Color
		var sz: int = int(p[2])
		UiIconHelper.load_tinted_icon(file, tint, UiIconHelper.raster_size_for_display(sz))
	UiIconHelper.load_tinted_icon("arrow-left.svg", Color(0.85, 0.9, 0.97, 1.0), UiIconHelper.raster_size_for_display(16))
	UiIconHelper.load_tinted_icon("sparkles.svg", COLOR_MULTIPLIER, UiIconHelper.raster_size_for_display(18))
	UiIconHelper.load_tinted_icon("scroll-text.svg", ACCENT, UiIconHelper.raster_size_for_display(18))


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
