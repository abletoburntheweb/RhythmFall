# ui/overlays/app_notice_overlay.gd
class_name AppNoticeOverlay
extends AppOverlayBase

signal dismissed
signal action_chosen(action: String)

@onready var _title_label: Label = %TitleLabel
@onready var _message_label: RichTextLabel = %MessageLabel
@onready var _buttons_row: HBoxContainer = %ButtonsRow
@onready var _ok_button: Button = %OkButton
@onready var _secondary_button: Button = %SecondaryButton
@onready var _card: PanelContainer = %Card


func _ready() -> void:
	super._ready()
	if _card:
		_card.add_theme_stylebox_override("panel", AppOverlayStyles.notice_panel())
	if _ok_button:
		_ok_button.pressed.connect(_on_ok_pressed)
	if _secondary_button:
		_secondary_button.pressed.connect(_on_secondary_pressed)
	apply_locale()


func apply_locale() -> void:
	if _ok_button:
		_ok_button.text = tr("BTN_OK")


func show_message(text: String) -> void:
	show_with_actions("", text)


func show_with_actions(
	title: String,
	message: String,
	primary_text: String = "",
	secondary_text: String = "",
) -> void:
	if _title_label:
		_title_label.text = str(title)
		_title_label.visible = str(title).strip_edges() != ""
	if _message_label:
		_message_label.bbcode_enabled = true
		_message_label.text = str(message)
	if _ok_button:
		_ok_button.text = primary_text if primary_text != "" else tr("BTN_OK")
	if _secondary_button:
		var secondary := str(secondary_text).strip_edges()
		_secondary_button.text = secondary
		_secondary_button.visible = secondary != ""
	if _buttons_row:
		_buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER if _secondary_button and not _secondary_button.visible else BoxContainer.ALIGNMENT_END
	present()
	if _ok_button:
		_ok_button.grab_focus()


func present() -> void:
	super.present()


func dismiss() -> void:
	super.dismiss()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F1:
			_finish("primary")
			get_viewport().set_input_as_handled()
			return
	super._input(event)


func _on_escape_pressed() -> void:
	if _secondary_button and _secondary_button.visible:
		_on_secondary_pressed()
	else:
		_on_ok_pressed()


func dismiss_primary() -> void:
	if visible:
		_finish("primary")


func _finish(action: String) -> void:
	if not visible:
		return
	dismiss()
	action_chosen.emit(action)
	if action == "primary":
		dismissed.emit()


func _on_ok_pressed() -> void:
	_finish("primary")


func _on_secondary_pressed() -> void:
	_finish("secondary")


func _on_backdrop_pressed() -> void:
	_on_ok_pressed()
