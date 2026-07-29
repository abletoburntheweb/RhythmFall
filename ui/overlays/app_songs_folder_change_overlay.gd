# ui/overlays/app_songs_folder_change_overlay.gd
class_name AppSongsFolderChangeOverlay
extends AppOverlayBase

signal finished(action: String, delete_notes: bool)

@onready var _message_label: Label = %MessageLabel
@onready var _delete_notes_checkbox: CheckBox = %DeleteNotesCheckBox
@onready var _cancel_button: Button = %CancelButton
@onready var _prune_button: Button = %PruneButton
@onready var _save_button: Button = %SaveButton
@onready var _card: PanelContainer = %Card
@onready var _accent_bar: ColorRect = %AccentBar


func _ready() -> void:
	super._ready()
	if _card:
		_card.add_theme_stylebox_override("panel", AppOverlayStyles.confirm_panel("warning"))
	if _accent_bar:
		_accent_bar.color = AppOverlayStyles.accent_color("warning")
	if _cancel_button:
		_cancel_button.pressed.connect(_on_cancel_pressed)
	if _prune_button:
		_prune_button.pressed.connect(_on_prune_pressed)
	if _save_button:
		_save_button.pressed.connect(_on_save_pressed)
	apply_locale()


func apply_locale() -> void:
	if _cancel_button:
		_cancel_button.text = tr("BTN_CANCEL")
	if _save_button:
		_save_button.text = tr("BTN_SAVE")
	if _prune_button:
		_prune_button.text = tr("MISC_PRUNE_METADATA")
	if _delete_notes_checkbox:
		_delete_notes_checkbox.text = tr("DLG_DELETE_NOTES_CHECKBOX")


func show_change_folder(message: String) -> void:
	if _message_label:
		_message_label.text = str(message)
	if _delete_notes_checkbox:
		_delete_notes_checkbox.button_pressed = false
	present()
	if _save_button:
		_save_button.grab_focus()


func _finish(action: String) -> void:
	var delete_notes := _delete_notes_checkbox.button_pressed if _delete_notes_checkbox else false
	dismiss()
	finished.emit(action, delete_notes)


func _on_save_pressed() -> void:
	_finish("save")


func _on_cancel_pressed() -> void:
	_finish("cancel")


func _on_prune_pressed() -> void:
	_finish("prune")


func _on_backdrop_pressed() -> void:
	_on_cancel_pressed()
