# scenes/game_screen/generation_quality_report_dialog.gd
extends Control

signal saved(report: Dictionary)
signal cancelled

const _GQR = preload("res://logic/data/generation_quality_reports.gd")

@onready var _title_label: Label = $Center/Card/CardMargin/VBox/TitleLabel
@onready var _meta_label: Label = $Center/Card/CardMargin/VBox/MetaLabel
@onready var _density_label: Label = $Center/Card/CardMargin/VBox/DensityLabel
@onready var _issue_box: VBoxContainer = $Center/Card/CardMargin/VBox/IssueBox
@onready var _until_end_check: CheckBox = $Center/Card/CardMargin/VBox/OptionsVBox/UntilEndCheck
@onready var _late_check: CheckBox = $Center/Card/CardMargin/VBox/OptionsVBox/LateCheck
@onready var _issue_measure_row: HBoxContainer = $Center/Card/CardMargin/VBox/OptionsVBox/IssueMeasureRow
@onready var _issue_measure_label: Label = $Center/Card/CardMargin/VBox/OptionsVBox/IssueMeasureRow/IssueMeasureLabel
@onready var _issue_measure_spin: SpinBox = $Center/Card/CardMargin/VBox/OptionsVBox/IssueMeasureRow/IssueMeasureSpin
@onready var _comment_edit: LineEdit = $Center/Card/CardMargin/VBox/CommentRow/CommentEdit
@onready var _save_button: Button = $Center/Card/CardMargin/VBox/ButtonsHBox/SaveButton
@onready var _cancel_button: Button = $Center/Card/CardMargin/VBox/ButtonsHBox/CancelButton
@onready var _hint_label: Label = $Center/Card/CardMargin/VBox/HintLabel

var _context: Dictionary = {}
var _issue_buttons: Array[Button] = []
var _selected_issue: String = _GQR.ISSUE_WRONG_DENSITY
var _button_group: ButtonGroup


func _ready() -> void:
	_button_group = ButtonGroup.new()
	_button_group.allow_unpress = false
	_build_issue_radios()
	if _save_button:
		_save_button.pressed.connect(_on_save_pressed)
	if _cancel_button:
		_cancel_button.pressed.connect(_on_cancel_pressed)
	if _late_check:
		_late_check.toggled.connect(_on_late_toggled)
	set_process_input(true)
	set_process_unhandled_input(true)
	call_deferred("apply_locale")


func setup(context: Dictionary) -> void:
	_context = context.duplicate(true)
	_refresh_meta()
	_refresh_density()
	_select_issue(_GQR.ISSUE_WRONG_DENSITY)
	if _issue_measure_spin:
		_issue_measure_spin.value = 0


func apply_locale() -> void:
	if _title_label:
		_title_label.text = tr("GENQA_DIALOG_TITLE")
	if _hint_label:
		_hint_label.text = tr("GENQA_DIALOG_HINT")
	if _save_button:
		_save_button.text = tr("GENQA_SAVE")
	if _cancel_button:
		_cancel_button.text = tr("BTN_CANCEL")
	if _until_end_check:
		_until_end_check.text = tr("GENQA_UNTIL_END")
	if _late_check:
		_late_check.text = tr("GENQA_NOTICED_LATE")
	if _issue_measure_label:
		_issue_measure_label.text = tr("GENQA_ISSUE_MEASURE_LABEL")
	var comment_lbl := get_node_or_null("Center/Card/CardMargin/VBox/CommentRow/CommentLabel") as Label
	if comment_lbl:
		comment_lbl.text = tr("GENQA_COMMENT_LABEL")
	if _comment_edit:
		_comment_edit.placeholder_text = tr("GENQA_COMMENT_PLACEHOLDER")
	for i in range(mini(_issue_buttons.size(), _GQR.ISSUE_ORDER.size())):
		var key: String = _GQR.ISSUE_ORDER[i]
		var loc_key: String = str(_GQR.ISSUE_LOCALE_KEYS.get(key, ""))
		if loc_key != "":
			_issue_buttons[i].text = tr(loc_key)
	_refresh_meta()
	_refresh_density()


func _build_issue_radios() -> void:
	if _issue_box == null:
		return
	for child in _issue_box.get_children():
		child.queue_free()
	_issue_buttons.clear()
	for issue_id in _GQR.ISSUE_ORDER:
		var btn := Button.new()
		btn.toggle_mode = true
		btn.button_group = _button_group
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.theme_type_variation = &"FlatButton"
		btn.add_theme_font_size_override("font_size", 16)
		var captured := issue_id
		btn.toggled.connect(func(pressed: bool) -> void:
			if pressed:
				_selected_issue = captured
		)
		_issue_box.add_child(btn)
		_issue_buttons.append(btn)


func _select_issue(issue_id: String) -> void:
	_selected_issue = issue_id
	for i in range(_issue_buttons.size()):
		_issue_buttons[i].set_pressed_no_signal(_GQR.ISSUE_ORDER[i] == issue_id)


func _on_late_toggled(pressed: bool) -> void:
	if _issue_measure_row:
		_issue_measure_row.visible = pressed


func _refresh_meta() -> void:
	if _meta_label == null or _context.is_empty():
		return
	_meta_label.text = tr("GENQA_META_FMT") % [
		str(_context.get("song", "?")),
		str(_context.get("preset", "?")),
		float(_context.get("time", 0.0)),
		int(_context.get("measure", 0)),
		float(_context.get("beat", 0.0)),
		int(_context.get("chart_difficulty", 0)),
		str(_context.get("genre", "?")),
	]


func _refresh_density() -> void:
	if _density_label == null or _context.is_empty():
		return
	var dens: Variant = _context.get("density", {})
	if not dens is Dictionary or dens.is_empty():
		_density_label.visible = false
		return
	_density_label.visible = true
	_density_label.text = tr("GENQA_DENSITY_FMT") % [
		int(dens.get("notes_prev_measure", 0)),
		int(dens.get("notes_this_measure", 0)),
		int(dens.get("notes_next_measure", 0)),
		float(dens.get("avg_notes_per_measure", 0.0)),
	]


func _build_extras() -> Dictionary:
	var extras := {}
	if _until_end_check and _until_end_check.button_pressed:
		extras["range_end"] = "eof"
	if _late_check and _late_check.button_pressed:
		extras["reaction_lag"] = "late"
		if _issue_measure_spin and int(_issue_measure_spin.value) > 0:
			extras["issue_measure"] = int(_issue_measure_spin.value)
	return extras


func _on_save_pressed() -> void:
	var comment := _comment_edit.text if _comment_edit else ""
	var entry := _GQR.append_report(_selected_issue, comment, _context, _build_extras())
	saved.emit(entry)
	queue_free()


func _on_cancel_pressed() -> void:
	cancelled.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		accept_event()
		_on_cancel_pressed()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			if _comment_edit and _comment_edit.has_focus():
				return
			accept_event()
			_on_save_pressed()
