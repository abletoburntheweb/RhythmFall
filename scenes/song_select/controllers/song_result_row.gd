# scenes/song_select/controllers/song_result_row.gd
# Run card — hero (best) or large history row; mockup V1/V3 style.
extends PanelContainer
class_name SongResultRow

const GradeDisplay = preload("res://logic/ui/grade_display.gd")
const _ModifierIconStrip = preload("res://logic/ui/modifier_icon_strip.gd")
const _GenPresetUi = preload("res://logic/ui/generation_preset_ui.gd")
const _GoalDiff = preload("res://logic/domain/generation/generation_goal_difficulty.gd")
const _SS = preload("res://logic/domain/library/song_select_strings.gd")

const COLOR_MUTED := Color(0.55, 0.58, 0.65, 0.92)
const COLOR_VALUE := Color(0.90, 0.92, 0.96, 1.0)
const COLOR_RR := Color(0.949, 0.702, 0.353, 1.0)
const COLOR_COMBO := Color(0.58, 0.78, 0.98, 1.0)

var _grade: Label
var _rr: Label
var _score: Label
var _acc: Label
var _combo: Label
var _date: Label
var _meta: RichTextLabel
var _inst_slot: Control
var _mods_row: HBoxContainer
var _is_best := false


func _init(as_best: bool = false) -> void:
	_is_best = as_best


func _ready() -> void:
	_build()


func _build() -> void:
	if _grade != null:
		return
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	if _is_best:
		sb.bg_color = Color(0.18, 0.16, 0.10, 0.98)
		sb.border_color = Color(0.72, 0.58, 0.22, 0.95)
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 14
		sb.content_margin_bottom = 14
		sb.set_corner_radius_all(12)
	else:
		sb.bg_color = Color(0.11, 0.12, 0.16, 0.94)
		sb.border_color = Color(0.30, 0.33, 0.40, 0.8)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 12
		sb.content_margin_bottom = 12
		sb.set_corner_radius_all(10)
	sb.set_border_width_all(1)
	add_theme_stylebox_override("panel", sb)

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 16 if _is_best else 14)
	add_child(root)

	_grade = Label.new()
	_grade.custom_minimum_size = Vector2(72 if _is_best else 52, 0)
	_grade.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_grade.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_grade.add_theme_font_size_override("font_size", 48 if _is_best else 28)
	root.add_child(_grade)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 4 if _is_best else 3)
	root.add_child(mid)

	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 14)
	mid.add_child(title)

	_rr = Label.new()
	_rr.add_theme_font_size_override("font_size", 22 if _is_best else 17)
	_rr.add_theme_color_override("font_color", COLOR_RR)
	title.add_child(_rr)

	_score = Label.new()
	_score.add_theme_font_size_override("font_size", 22 if _is_best else 18)
	_score.add_theme_color_override("font_color", COLOR_VALUE)
	title.add_child(_score)

	_acc = Label.new()
	_acc.add_theme_font_size_override("font_size", 18 if _is_best else 16)
	_acc.add_theme_color_override("font_color", Color(0.55, 0.82, 0.72, 1.0))
	title.add_child(_acc)

	_combo = Label.new()
	_combo.add_theme_font_size_override("font_size", 16 if _is_best else 15)
	_combo.add_theme_color_override("font_color", COLOR_COMBO)
	title.add_child(_combo)

	var meta_row := HBoxContainer.new()
	meta_row.add_theme_constant_override("separation", 10)
	mid.add_child(meta_row)

	_inst_slot = Control.new()
	_inst_slot.custom_minimum_size = Vector2(26 if _is_best else 22, 26 if _is_best else 22)
	meta_row.add_child(_inst_slot)

	_date = Label.new()
	_date.add_theme_font_size_override("font_size", 14 if _is_best else 13)
	_date.add_theme_color_override("font_color", COLOR_MUTED)
	meta_row.add_child(_date)

	_meta = RichTextLabel.new()
	_meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_meta.fit_content = true
	_meta.scroll_active = false
	_meta.bbcode_enabled = true
	_meta.autowrap_mode = TextServer.AUTOWRAP_OFF
	_meta.add_theme_font_size_override("normal_font_size", 14 if _is_best else 13)
	meta_row.add_child(_meta)

	_mods_row = HBoxContainer.new()
	_mods_row.add_theme_constant_override("separation", 5)
	_mods_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	root.add_child(_mods_row)


func apply_result(
	result: Dictionary,
	instrument_id: String,
	instrument_label: String,
	mode_label: String,
	_is_score_record: bool = false,
	_is_combo_record: bool = false
) -> void:
	_build()
	var grade := str(result.get("grade", "—"))
	_grade.text = grade
	_grade.add_theme_color_override("font_color", GradeDisplay.color_from_saved_result(result))

	var rr := int(result.get("run_rr", 0))
	if rr > 0:
		_rr.text = _SS._translate("SONG_MUSEUM_RR_FMT") % str(rr)
		_rr.visible = true
	else:
		_rr.text = ""
		_rr.visible = false

	_score.text = _format_score(int(result.get("score", 0)))
	_score.add_theme_color_override("font_color", COLOR_VALUE)

	_acc.text = "%.1f%%" % float(result.get("accuracy", 0.0))
	var max_combo := int(result.get("max_combo", 0))
	if max_combo > 0:
		_combo.text = _SS._translate("SONG_MUSEUM_COMBO_FMT") % max_combo
		_combo.add_theme_color_override("font_color", COLOR_COMBO)
		_combo.visible = true
	else:
		_combo.text = ""
		_combo.visible = false

	var date_raw := str(result.get("date", "")).strip_edges()
	var date_text := TimeUtils.format_session_datetime_localized(date_raw)
	if date_text == "" and date_raw != "":
		date_text = TimeUtils.format_iso_to_ddmmyyyy_hhmmss(date_raw)
	_date.text = date_text

	var inst_id := instrument_id.strip_edges().to_lower()
	if inst_id == "" and instrument_label.strip_edges() != "" and instrument_label != "—":
		# Recover id from localized/legacy label when bind missed it.
		inst_id = _instrument_id_from_label(instrument_label)
	var inst_label := instrument_label.strip_edges()
	if inst_label == "" or inst_label == "—":
		var raw_inst := str(result.get("instrument", "")).strip_edges()
		if inst_id == "" and raw_inst != "":
			inst_id = _instrument_id_from_label(raw_inst)
		if inst_id != "":
			inst_label = _GenPresetUi.localized_instrument(inst_id)
		elif raw_inst != "":
			inst_label = raw_inst
	elif inst_id == "":
		inst_id = _instrument_id_from_label(inst_label)
	var mode_text := mode_label.strip_edges()
	var inst_tint: Color = _GenPresetUi.INSTRUMENT_ICON_COLORS.get(inst_id, COLOR_MUTED)
	var mode_raw := str(result.get("mode", "")).strip_edges()
	var mode_tint: Color = _style_tint_for_mode(mode_raw)
	_meta.clear()
	var wrote := false
	if inst_label != "" and inst_label != "—":
		_meta.push_color(inst_tint)
		_meta.add_text(inst_label)
		_meta.pop()
		wrote = true
	if mode_text != "" and mode_text != "—":
		if wrote:
			_meta.push_color(COLOR_MUTED)
			_meta.add_text(" · ")
			_meta.pop()
		_meta.push_color(mode_tint)
		_meta.add_text(mode_text)
		_meta.pop()
		wrote = true
	_meta.visible = wrote

	for child in _inst_slot.get_children():
		child.queue_free()
	if inst_id != "" and inst_id in _GenPresetUi.INSTRUMENT_ICONS:
		var icon_file := str(_GenPresetUi.INSTRUMENT_ICONS[inst_id])
		var frame_sz := 26 if _is_best else 22
		var icon_sz := 16 if _is_best else 14
		var frame := UiIconHelper.make_icon_frame(icon_file, frame_sz, icon_sz, inst_tint)
		_inst_slot.add_child(frame)
	_inst_slot.visible = _inst_slot.get_child_count() > 0

	var raw_mods: Variant = result.get("modifiers", [])
	var mods: Array = raw_mods if raw_mods is Array else []
	_ModifierIconStrip.fill_row_chips(_mods_row, mods, {}, 10, true, false)
	_mods_row.visible = _mods_row.get_child_count() > 0


func _instrument_id_from_label(label: String) -> String:
	var key := label.strip_edges().to_lower()
	match key:
		"drums", "перкуссия", "percussion":
			return "drums"
		"bass", "бас":
			return "bass"
		"fullmix", "микс", "mix":
			return "fullmix"
		"guitar", "гитара":
			return "guitar"
		"keys", "vocals":
			return key
		_:
			return key if key in _GenPresetUi.INSTRUMENT_ICONS else ""


func _style_tint_for_mode(mode_raw: String) -> Color:
	var mode := mode_raw.strip_edges().to_lower()
	if mode == "":
		return COLOR_MUTED
	var goal := ""
	if _GoalDiff.is_chart_stem(mode):
		goal = str(_GoalDiff.pair_from_stem(mode).get("goal", ""))
	elif mode in _GenPresetUi.INTENT_ICONS:
		goal = mode
	else:
		goal = str(_GoalDiff.from_intent(mode).get("goal", mode))
	if goal in _GenPresetUi.INTENT_ICON_COLORS:
		return _GenPresetUi.INTENT_ICON_COLORS[goal]
	if mode in _GenPresetUi.MODE_ICON_COLORS:
		return _GenPresetUi.MODE_ICON_COLORS[mode]
	return COLOR_MUTED


func _format_score(score: int) -> String:
	var s := str(score)
	var out := ""
	var n := s.length()
	for i in range(n):
		if i > 0 and (n - i) % 3 == 0:
			out += " "
		out += s[i]
	return out
