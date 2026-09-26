# scenes/game_screen/components/practice_hud.gd
class_name PracticeHud
extends PanelContainer

const _RhythmDnaView = preload("res://logic/data/rhythm_dna_view.gd")

## In-game Practice stats block shown top-left while a Practice session is
## active. Follows the RhythmFall HUD look (dark rounded panel + muted labels).
## All user-facing strings go through tr() with keys from translations/ui.csv.

var _title_label: Label
var _range_label: Label
var _accuracy_value: Label
var _combo_value: Label
var _misses_value: Label
var _attempts_value: Label
var _best_label: Label
var _best_value: Label
var _stat_caption_keys: Array = []
var _stat_caption_labels: Array = []
var _range_start_label: String = ""
var _range_end_label: String = ""


func _init() -> void:
	name = "PracticeHud"
	_ensure_style()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", Color(0.98, 0.86, 0.45, 1.0))
	_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_title_label.add_theme_constant_override("shadow_offset_y", 1)
	vbox.add_child(_title_label)

	_range_label = Label.new()
	_range_label.add_theme_font_size_override("font_size", 13)
	_range_label.add_theme_color_override("font_color", Color(0.62, 0.86, 0.72, 1.0))
	vbox.add_child(_range_label)

	_accuracy_value = Label.new()
	_combo_value = Label.new()
	_misses_value = Label.new()
	_attempts_value = Label.new()
	vbox.add_child(_stat_row("PRACTICE_HUD_ACCURACY", _accuracy_value))
	vbox.add_child(_stat_row("PRACTICE_HUD_MAX_COMBO", _combo_value))
	vbox.add_child(_stat_row("PRACTICE_HUD_MISSES", _misses_value))
	vbox.add_child(_stat_row("PRACTICE_HUD_ATTEMPTS", _attempts_value))

	var sep := HSeparator.new()
	sep.add_theme_stylebox_override("separator", _sep_style())
	vbox.add_child(sep)

	_best_label = Label.new()
	_best_label.add_theme_font_size_override("font_size", 14)
	_best_label.add_theme_color_override("font_color", Color(0.98, 0.86, 0.45, 1.0))
	vbox.add_child(_best_label)

	_best_value = Label.new()
	_best_value.add_theme_font_size_override("font_size", 20)
	_best_value.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82, 1.0))
	vbox.add_child(_best_value)

	_apply_ui_strings()
	setup(null)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_apply_ui_strings()
		if visible:
			_update_range_text()


func _apply_ui_strings() -> void:
	if _title_label:
		_title_label.text = tr("PRACTICE_HUD_TITLE")
	if _best_label:
		_best_label.text = tr("PRACTICE_HUD_BEST")
	for i in range(_stat_caption_keys.size()):
		if i < _stat_caption_labels.size():
			var cap: Label = _stat_caption_labels[i]
			if cap:
				cap.text = tr(str(_stat_caption_keys[i]))


func _update_range_text() -> void:
	if _range_label:
		_range_label.text = tr("PRACTICE_HUD_RANGE_FMT") % [_range_start_label, _range_end_label]


func _ensure_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.11, 0.82)
	style.border_color = Color(0.98, 0.86, 0.45, 0.45)
	style.set_border_width_all(1)
	style.border_width_left = 3
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)


func _sep_style() -> StyleBoxLine:
	var s := StyleBoxLine.new()
	s.color = Color(1, 1, 1, 0.08)
	s.thickness = 1
	return s


func _stat_row(caption_key: String, value_label: Label) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var cap := Label.new()
	cap.text = tr(caption_key)
	cap.add_theme_font_size_override("font_size", 15)
	cap.add_theme_color_override("font_color", Color(0.72, 0.78, 0.88, 0.95))
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.add_theme_font_size_override("font_size", 16)
	value_label.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1.0))
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(70, 0)
	row.add_child(cap)
	row.add_child(value_label)
	_stat_caption_keys.append(caption_key)
	_stat_caption_labels.append(cap)
	return row


func setup(practice_session) -> void:
	if practice_session == null:
		visible = false
		return
	update_range(practice_session)
	update_stats(practice_session)
	visible = true


## Keeps the displayed range in sync with the ACTIVE session. Called on every
## practice entry / loop refresh so re-entering practice with a new range (from
## the pause) never leaves the HUD showing the previous session's section range.
func update_range(practice_session) -> void:
	if practice_session == null:
		return
	# Compact short labels for HUD: I / V1 / C etc. via existing RhythmDnaView.format_section_short
	var start_lbl := ""
	var end_lbl := ""
	var sections: Array = []
	if practice_session.sections is Array:
		sections = practice_session.sections
	if sections is Array and not sections.is_empty():
		if practice_session.section_start >= 0 and practice_session.section_start < sections.size():
			var seg_s: Dictionary = sections[practice_session.section_start] if sections[practice_session.section_start] is Dictionary else {}
			start_lbl = _RhythmDnaView.format_section_short(seg_s)
		if practice_session.section_end >= 0 and practice_session.section_end < sections.size():
			var seg_e: Dictionary = sections[practice_session.section_end] if sections[practice_session.section_end] is Dictionary else {}
			end_lbl = _RhythmDnaView.format_section_short(seg_e)
	if start_lbl.strip_edges() == "":
		if practice_session.has_method("section_label"):
			start_lbl = str(practice_session.section_label(practice_session.section_start))
		if start_lbl.strip_edges() == "":
			start_lbl = str(practice_session.section_start + 1)
	if end_lbl.strip_edges() == "":
		if practice_session.has_method("section_label"):
			end_lbl = str(practice_session.section_label(practice_session.section_end))
		if end_lbl.strip_edges() == "":
			end_lbl = str(practice_session.section_end + 1)
	_range_start_label = start_lbl
	_range_end_label = end_lbl
	_update_range_text()


func update_stats(practice_session) -> void:
	if practice_session == null:
		return
	_accuracy_value.text = "%.1f%%" % practice_session.session_accuracy()
	_combo_value.text = str(practice_session.session_max_combo_display())
	_misses_value.text = str(practice_session.session_total_misses())
	_attempts_value.text = str(practice_session.attempts)


func update_best(best_accuracy: float) -> void:
	if _best_value:
		_best_value.text = "%.1f%%" % best_accuracy