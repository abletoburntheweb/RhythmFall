# scenes/song_select/playlists/playlist_filter_dialog.gd
extends Control
class_name PlaylistFilterDialog

signal applied(view_filter: Dictionary)
signal cancelled()

const _PlaylistCatalog = preload("res://logic/domain/library/playlist_catalog.gd")
const _GoalDiff = preload("res://logic/domain/generation/generation_goal_difficulty.gd")
const _GenPresetUi = preload("res://logic/ui/generation_preset_ui.gd")
const _InstrumentIconScript = preload("res://scenes/song_select/endless/session_instrument_icon.gd")
const _SegmentedOptionUtils = preload("res://logic/ui/segmented_option_utils.gd")
const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")

const BUTTON_VARIATION := &"FlatModalPrimaryButton"
const ACTIVE_MODULATE := SegmentedOptionUtils.ACTIVE_COLOR
const INACTIVE_MODULATE := SegmentedOptionUtils.DEFAULT_COLOR

const DIFFICULTY_ICONS := {
	"relaxed": "feather.svg",
	"standard": "circle-check.svg",
	"dense": "flame_gen.svg",
}

const DIFFICULTY_COLORS := {
	"relaxed": Color(0.62, 0.82, 0.96, 1.0),
	"standard": Color(0.55, 0.78, 0.98, 1.0),
	"dense": Color(1.0, 0.58, 0.32, 1.0),
}

var _view_filter: Dictionary = {}
var _instrument_icons: Dictionary = {}
var _display_buttons: Array[Button] = []
var _goal_buttons: Dictionary = {}
var _diff_buttons: Dictionary = {}
var _selected_goal := _GoalDiff.DEFAULT_GOAL
var _selected_diffs: Array[String] = []
var _display_filtered := true

@onready var _display_mode_row: HBoxContainer = %DisplayModeRow
@onready var _goal_row: HBoxContainer = %GoalRow
@onready var _diff_row: HBoxContainer = %DiffRow
@onready var _notes_ready: CheckBox = %NotesReadyCheck
@onready var _apply_button: Button = %ApplyButton
@onready var _cancel_button: Button = %CancelButton
@onready var _title_label: Label = %TitleLabel
@onready var _display_mode_caption: Label = %DisplayModeCaption
@onready var _goal_caption: Label = %GoalCaption
@onready var _diff_caption: Label = %DiffCaption
@onready var _instrument_caption: Label = %InstrumentCaption
@onready var _instrument_row: HBoxContainer = %InstrumentRow


func _ready() -> void:
	UiIconHelper.configure_modal_overlay(self, 100)
	_build_option_rows()
	if _apply_button and not _apply_button.pressed.is_connected(_on_apply_pressed):
		_apply_button.pressed.connect(_on_apply_pressed)
	if _cancel_button and not _cancel_button.pressed.is_connected(_on_cancel_pressed):
		_cancel_button.pressed.connect(_on_cancel_pressed)
	_setup_instrument_icons()
	apply_locale()


func open_with_filter(view_filter: Dictionary) -> void:
	_view_filter = _PlaylistCatalog.normalize_view_filter(view_filter)
	_sync_ui_from_filter()
	show()


func apply_locale() -> void:
	if _title_label:
		_title_label.text = tr("PLAYLIST_FILTER_TITLE")
	if _display_mode_caption:
		_display_mode_caption.text = tr("PLAYLIST_FILTER_DISPLAY_MODE")
	if _goal_caption:
		_goal_caption.text = tr("PLAYLIST_FILTER_GOALS")
	if _diff_caption:
		_diff_caption.text = tr("PLAYLIST_FILTER_DIFFICULTY")
	if _instrument_caption:
		_instrument_caption.text = tr("PLAYLIST_FILTER_INSTRUMENT")
	for inst_id in _instrument_icons.keys():
		var icon: SessionInstrumentIcon = _instrument_icons[inst_id]
		if icon:
			icon.refresh_locale()
	_refresh_option_button_labels()
	if _notes_ready:
		_notes_ready.text = tr("PLAYLIST_FILTER_NOTES_READY")
	if _apply_button:
		_apply_button.text = tr("PLAYLIST_FILTER_APPLY")
	if _cancel_button:
		_cancel_button.text = tr("BTN_CANCEL")


func _build_option_rows() -> void:
	_build_display_mode_row()
	_build_goal_row()
	_build_difficulty_row()


func _build_display_mode_row() -> void:
	if _display_mode_row == null:
		return
	for child in _display_mode_row.get_children():
		child.queue_free()
	_display_buttons.clear()
	for spec in [
		{"id": _PlaylistCatalog.DISPLAY_MODE_FILTERED, "label_key": "PLAYLIST_FILTER_MODE_FILTERED"},
		{"id": _PlaylistCatalog.DISPLAY_MODE_ALL_CHARTS, "label_key": "PLAYLIST_FILTER_MODE_ALL"},
	]:
		var btn := _make_option_button(tr(str(spec.get("label_key", ""))))
		btn.set_meta("option_id", str(spec.get("id", "")))
		btn.pressed.connect(_on_display_mode_pressed.bind(btn))
		_display_mode_row.add_child(btn)
		_display_buttons.append(btn)


func _build_goal_row() -> void:
	if _goal_row == null:
		return
	for child in _goal_row.get_children():
		child.queue_free()
	_goal_buttons.clear()
	for goal_id in _GoalDiff.GOALS:
		var icon_file := str(_GenPresetUi.INTENT_ICONS.get(goal_id, "audio-lines.svg"))
		var accent: Color = _GenPresetUi.INTENT_ICON_COLORS.get(goal_id, _UiIconHelper.ACCENT) as Color
		var btn := _make_option_button(tr("GEN_GOAL_%s" % goal_id.to_upper()), icon_file, accent)
		btn.set_meta("option_id", goal_id)
		btn.pressed.connect(_on_goal_pressed.bind(goal_id))
		_goal_row.add_child(btn)
		_goal_buttons[goal_id] = btn


func _build_difficulty_row() -> void:
	if _diff_row == null:
		return
	for child in _diff_row.get_children():
		child.queue_free()
	_diff_buttons.clear()
	for diff_id in _GoalDiff.DIFFICULTIES:
		var icon_file := str(DIFFICULTY_ICONS.get(diff_id, "layers.svg"))
		var accent: Color = DIFFICULTY_COLORS.get(diff_id, _UiIconHelper.ACCENT) as Color
		var btn := _make_option_button(
			tr(_GoalDiff.difficulty_label_key(_selected_goal, diff_id)),
			icon_file,
			accent,
		)
		btn.set_meta("option_id", diff_id)
		btn.toggle_mode = true
		btn.pressed.connect(_on_difficulty_pressed.bind(diff_id))
		_diff_row.add_child(btn)
		_diff_buttons[diff_id] = btn


func _make_option_button(text: String, icon_file: String = "", accent: Color = _UiIconHelper.ACCENT) -> Button:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 44)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.theme_type_variation = BUTTON_VARIATION
	btn.add_theme_font_size_override("font_size", 15)
	if icon_file.strip_edges() != "":
		_UiIconHelper.configure_button_icon(btn, icon_file, accent.lightened(0.08), 16)
	btn.self_modulate = INACTIVE_MODULATE
	return btn


func _refresh_option_button_labels() -> void:
	for btn in _display_buttons:
		var mode_id := str(btn.get_meta("option_id", ""))
		var key := (
			"PLAYLIST_FILTER_MODE_FILTERED"
			if mode_id == _PlaylistCatalog.DISPLAY_MODE_FILTERED
			else "PLAYLIST_FILTER_MODE_ALL"
		)
		btn.text = tr(key)
	for goal_id in _goal_buttons.keys():
		var btn: Button = _goal_buttons[goal_id]
		if btn:
			btn.text = tr("GEN_GOAL_%s" % str(goal_id).to_upper())
	for diff_id in _diff_buttons.keys():
		var btn: Button = _diff_buttons[diff_id]
		if btn:
			btn.text = tr(_GoalDiff.difficulty_label_key(_selected_goal, str(diff_id)))


func _sync_ui_from_filter() -> void:
	_display_filtered = (
		str(_view_filter.get("display_mode", _PlaylistCatalog.DISPLAY_MODE_FILTERED))
		== _PlaylistCatalog.DISPLAY_MODE_FILTERED
	)
	_sync_display_mode_buttons(_display_filtered)
	var goals: Array = _view_filter.get("goals", [])
	_selected_goal = str(goals[0] if not goals.is_empty() else _GoalDiff.DEFAULT_GOAL)
	if _selected_goal not in _GoalDiff.GOALS:
		_selected_goal = _GoalDiff.DEFAULT_GOAL
	_sync_goal_buttons()
	_selected_diffs.clear()
	for diff_raw in _view_filter.get("difficulties", []):
		var diff_id := str(diff_raw).strip_edges().to_lower()
		if diff_id in _GoalDiff.DIFFICULTIES and not _selected_diffs.has(diff_id):
			_selected_diffs.append(diff_id)
	if _selected_diffs.is_empty():
		_selected_diffs = _GoalDiff.DIFFICULTIES.duplicate()
	_sync_difficulty_buttons()
	if _notes_ready:
		_notes_ready.button_pressed = bool(_view_filter.get("notes_ready_only", true))
	_sync_instrument_icons()


func _sync_display_mode_buttons(filtered: bool) -> void:
	_display_filtered = filtered
	for btn in _display_buttons:
		var mode_id := str(btn.get_meta("option_id", ""))
		var active := (
			filtered and mode_id == _PlaylistCatalog.DISPLAY_MODE_FILTERED
		) or (
			not filtered and mode_id == _PlaylistCatalog.DISPLAY_MODE_ALL_CHARTS
		)
		btn.self_modulate = ACTIVE_MODULATE if active else INACTIVE_MODULATE


func _sync_goal_buttons() -> void:
	for goal_id in _goal_buttons.keys():
		var btn: Button = _goal_buttons[goal_id]
		if btn:
			btn.self_modulate = ACTIVE_MODULATE if goal_id == _selected_goal else INACTIVE_MODULATE


func _sync_difficulty_buttons() -> void:
	for diff_id in _diff_buttons.keys():
		var btn: Button = _diff_buttons[diff_id]
		if btn:
			var active := _selected_diffs.has(diff_id)
			btn.button_pressed = active
			btn.self_modulate = ACTIVE_MODULATE if active else INACTIVE_MODULATE


func _on_display_mode_pressed(btn: Button) -> void:
	var mode_id := str(btn.get_meta("option_id", ""))
	_display_filtered = mode_id == _PlaylistCatalog.DISPLAY_MODE_FILTERED
	_sync_display_mode_buttons(_display_filtered)
	if MusicManager:
		MusicManager.play_modifier_select_sound()


func _on_goal_pressed(goal_id: String) -> void:
	if goal_id not in _GoalDiff.GOALS:
		return
	_selected_goal = goal_id
	_sync_goal_buttons()
	for diff_id in _diff_buttons.keys():
		var btn: Button = _diff_buttons[diff_id]
		if btn:
			btn.text = tr(_GoalDiff.difficulty_label_key(_selected_goal, str(diff_id)))
	if MusicManager:
		MusicManager.play_modifier_select_sound()


func _on_difficulty_pressed(diff_id: String) -> void:
	if diff_id not in _GoalDiff.DIFFICULTIES:
		return
	if _selected_diffs.has(diff_id):
		if _selected_diffs.size() <= 1:
			_sync_difficulty_buttons()
			return
		_selected_diffs.erase(diff_id)
	else:
		_selected_diffs.append(diff_id)
	_selected_diffs.sort_custom(func(a: String, b: String) -> bool:
		return _GoalDiff.DIFFICULTIES.find(a) < _GoalDiff.DIFFICULTIES.find(b)
	)
	_sync_difficulty_buttons()
	if MusicManager:
		MusicManager.play_modifier_select_sound()


func _setup_instrument_icons() -> void:
	if _instrument_row == null:
		return
	for child in _instrument_row.get_children():
		child.queue_free()
	_instrument_icons.clear()
	for spec in [
		{"id": "drums", "locked": false},
		{"id": "bass", "locked": true},
	]:
		var icon := _InstrumentIconScript.new() as SessionInstrumentIcon
		var inst_id := str(spec.get("id", "drums"))
		icon.setup(inst_id, bool(spec.get("locked", false)))
		if not bool(spec.get("locked", false)):
			if not icon.instrument_selected.is_connected(_on_instrument_selected):
				icon.instrument_selected.connect(_on_instrument_selected)
		_instrument_row.add_child(icon)
		_instrument_icons[inst_id] = icon
	_sync_instrument_icons()


func _sync_instrument_icons() -> void:
	var inst := str(_view_filter.get("instrument", "drums")).strip_edges()
	if inst != "drums":
		inst = "drums"
		_view_filter["instrument"] = inst
	for inst_id in _instrument_icons.keys():
		var icon: SessionInstrumentIcon = _instrument_icons[inst_id]
		if icon:
			icon.set_instrument_selected(str(inst_id) == inst)


func _on_instrument_selected(instrument_id: String) -> void:
	if str(instrument_id).strip_edges() != "drums":
		return
	_view_filter["instrument"] = "drums"
	_sync_instrument_icons()
	if MusicManager:
		MusicManager.play_modifier_select_sound()


func _collect_filter() -> Dictionary:
	var mode := (
		_PlaylistCatalog.DISPLAY_MODE_FILTERED
		if _display_filtered
		else _PlaylistCatalog.DISPLAY_MODE_ALL_CHARTS
	)
	return _PlaylistCatalog.normalize_view_filter({
		"display_mode": mode,
		"goals": [_selected_goal],
		"difficulties": _selected_diffs.duplicate(),
		"instrument": _view_filter.get("instrument", "drums"),
		"lanes": _view_filter.get("lanes", 4),
		"notes_ready_only": _notes_ready.button_pressed if _notes_ready else true,
	})


func _on_apply_pressed() -> void:
	if MusicManager:
		MusicManager.play_modifier_select_sound()
	applied.emit(_collect_filter())
	hide()


func _on_cancel_pressed() -> void:
	if MusicManager:
		MusicManager.play_modifier_deselect_sound()
	cancelled.emit()
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()
