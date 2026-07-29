# ui/overlays/app_choice_overlay.gd
class_name AppChoiceOverlay
extends AppOverlayBase

signal finished(choice: String)

@onready var _title_label: Label = %TitleLabel
@onready var _message_label: Label = %MessageLabel
@onready var _cancel_button: Button = %CancelButton
@onready var _extra_button: Button = %ExtraButton
@onready var _confirm_button: Button = %ConfirmButton
@onready var _card: PanelContainer = %Card
@onready var _accent_bar: ColorRect = %AccentBar

var _variant := "warning"


func _ready() -> void:
	super._ready()
	if _cancel_button:
		_cancel_button.pressed.connect(_on_cancel_pressed)
	if _extra_button:
		_extra_button.pressed.connect(_on_extra_pressed)
	if _confirm_button:
		_confirm_button.pressed.connect(_on_confirm_pressed)
	apply_locale()


func apply_locale() -> void:
	if _cancel_button:
		_cancel_button.text = tr("BTN_CANCEL")
	if _confirm_button:
		_confirm_button.text = tr("BTN_OK")


func show_choice(
	title: String,
	message: String,
	variant: String = "warning",
	confirm_text: String = "",
	cancel_text: String = "",
	extra_text: String = "",
) -> void:
	_variant = variant
	_apply_variant()
	if _title_label:
		_title_label.text = str(title)
		_title_label.visible = str(title).strip_edges() != ""
	if _message_label:
		_message_label.text = str(message)
	if _confirm_button:
		_confirm_button.text = confirm_text if confirm_text != "" else tr("BTN_OK")
	if _cancel_button:
		_cancel_button.text = cancel_text if cancel_text != "" else tr("BTN_CANCEL")
	if _extra_button:
		var extra := str(extra_text).strip_edges()
		_extra_button.text = extra
		_extra_button.visible = extra != ""
	present()
	if _confirm_button:
		_confirm_button.grab_focus()


func _apply_variant() -> void:
	if _card:
		_card.add_theme_stylebox_override("panel", AppOverlayStyles.confirm_panel(_variant))
	if _accent_bar:
		_accent_bar.color = AppOverlayStyles.accent_color(_variant)
	if _title_label:
		_title_label.add_theme_color_override("font_color", AppOverlayStyles.title_color(_variant))


func _finish(choice: String) -> void:
	if not try_dismiss():
		return
	finished.emit(choice)


func _on_confirm_pressed() -> void:
	_finish("confirm")


func _on_cancel_pressed() -> void:
	_finish("cancel")


func _on_extra_pressed() -> void:
	_finish("extra")


func _on_backdrop_pressed() -> void:
	_on_cancel_pressed()


func _on_confirm_key_pressed() -> void:
	_on_confirm_pressed()
