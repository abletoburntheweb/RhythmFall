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
var _pending_title: String = ""
var _pending_message: String = ""
var _pending_confirm: String = ""
var _pending_cancel: String = ""
var _pending_extra: String = ""
var _has_pending: bool = false


func _ready() -> void:
	super._ready()
	if _cancel_button:
		_cancel_button.pressed.connect(_on_cancel_pressed)
	if _extra_button:
		_extra_button.pressed.connect(_on_extra_pressed)
	if _confirm_button:
		_confirm_button.pressed.connect(_on_confirm_pressed)
	apply_locale()
	# If show_choice was called before _ready (pending), apply now.
	if _has_pending:
		_apply_pending_choice()


func apply_locale() -> void:
	if _cancel_button:
		_cancel_button.text = tr("BTN_CANCEL")
	if _confirm_button:
		_confirm_button.text = tr("BTN_OK")


func _apply_pending_choice() -> void:
	if not _has_pending:
		return
	_has_pending = false
	show_choice(_pending_title, _pending_message, _variant, _pending_confirm, _pending_cancel, _pending_extra)

func show_choice(
	title: String,
	message: String,
	variant: String = "warning",
	confirm_text: String = "",
	cancel_text: String = "",
	extra_text: String = "",
) -> void:
	_variant = variant
	# If nodes not yet ready (called before _ready), defer.
	if _title_label == null or _message_label == null or _cancel_button == null:
		_pending_title = str(title)
		_pending_message = str(message)
		_pending_confirm = str(confirm_text)
		_pending_cancel = str(cancel_text)
		_pending_extra = str(extra_text)
		_has_pending = true
		# Also ensure we will present once ready — _ready will call _apply_pending_choice
		if is_inside_tree() and get_parent() != null:
			# If already in tree but onready not yet, will be handled in _ready
			pass
		else:
			# Not yet in tree — will be handled when added
			pass
		# Try to apply variant still if possible (card may also be null)
		_apply_variant()
		# Defer present until ready
		return
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
