# scenes/song_select/run_modifiers/modifier_preset_edit_dialog.gd
extends Control

signal saved(slot: int, name: String)
signal cancelled

const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const _UserPresets = preload("res://logic/domain/modifiers/user_presets.gd")

var _slot: int = 1
var _draft_modifiers: Array = []
var _draft_params: Dictionary = {}

@onready var _title_label: Label = $EditCard/EditMargin/EditVBox/TitleLabel
@onready var _name_edit: LineEdit = $EditCard/EditMargin/EditVBox/NameEdit
@onready var _hint_label: Label = $EditCard/EditMargin/EditVBox/HintLabel
@onready var _mods_label: Label = $EditCard/EditMargin/EditVBox/ModsLabel
@onready var _cancel_button: Button = $EditCard/EditMargin/EditVBox/ActionsRow/CancelButton
@onready var _save_button: Button = $EditCard/EditMargin/EditVBox/ActionsRow/SaveButton


func _ready() -> void:
	UiIconHelper.configure_modal_overlay(self, 120)
	visible = false
	if _cancel_button:
		_cancel_button.pressed.connect(_on_cancel_pressed)
	if _save_button:
		_save_button.pressed.connect(_on_save_pressed)
	if _name_edit:
		_name_edit.text_submitted.connect(func(_t: String): _on_save_pressed())
	apply_locale()


func apply_locale() -> void:
	if _title_label:
		_title_label.text = tr("MOD_PRESET_EDIT_TITLE")
	if _hint_label:
		_hint_label.text = tr("MOD_PRESET_EDIT_HINT")
	if _cancel_button:
		_cancel_button.text = tr("BTN_CANCEL")
	if _save_button:
		_save_button.text = tr("MOD_PRESET_EDIT_SAVE")


func open_for_slot(
	slot: int,
	initial_name: String,
	modifiers: Array,
	params: Dictionary
) -> void:
	_slot = slot
	_draft_modifiers = modifiers.duplicate()
	_draft_params = params.duplicate()
	if _name_edit:
		_name_edit.text = initial_name
		_name_edit.caret_column = initial_name.length()
	_refresh_mods_preview()
	visible = true
	if _name_edit:
		_name_edit.grab_focus()


func _refresh_mods_preview() -> void:
	if _mods_label == null:
		return
	var summary := _RunModifiers.format_preset_summary(_draft_modifiers, _draft_params)
	if summary.strip_edges() == "" or summary.begins_with("×"):
		_mods_label.text = tr("MOD_PRESET_EDIT_NO_MODS")
	else:
		_mods_label.text = summary


func _on_cancel_pressed() -> void:
	visible = false
	cancelled.emit()


func _on_save_pressed() -> void:
	var name := _name_edit.text.strip_edges() if _name_edit else ""
	if name == "":
		name = _UserPresets.default_slot_name(_slot)
	saved.emit(_slot, name)
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		accept_event()
		_on_cancel_pressed()
