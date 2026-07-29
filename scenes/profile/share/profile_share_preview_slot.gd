# scenes/profile/share/profile_share_preview_slot.gd
class_name ProfileSharePreviewSlot
extends PanelContainer

signal slot_pressed(card_id: String)

const _SEL_BORDER := Color(0.98, 0.86, 0.52, 0.95)
const _DEFAULT_BORDER := Color(1, 1, 1, 0.12)

var card_id: String = ""
var hotkey_index: int = 0

@onready var _hotkey_label: Label = %HotkeyLabel
@onready var _preview: TextureRect = %PreviewTexture
@onready var _click_button: Button = %ClickButton
@onready var _loading_label: Label = %LoadingLabel


func _ready() -> void:
	if _click_button and not _click_button.pressed.is_connected(_on_click_pressed):
		_click_button.pressed.connect(_on_click_pressed)
	_update_hotkey()


func setup(index: int, id: String) -> void:
	hotkey_index = index
	card_id = id
	_update_hotkey()


func set_texture(tex: Texture2D) -> void:
	if _preview:
		_preview.texture = tex
	if _loading_label:
		_loading_label.visible = tex == null


func set_loading(loading: bool, message: String = "") -> void:
	if _loading_label:
		_loading_label.visible = loading or message != ""
		if message != "":
			_loading_label.text = message
		elif loading:
			_loading_label.text = tr("PROFILE_SHARE_PREVIEW_LOADING")
		else:
			_loading_label.text = ""


func set_selected(selected: bool) -> void:
	var box := get_theme_stylebox("panel") as StyleBoxFlat
	if box == null:
		box = StyleBoxFlat.new()
	box.border_color = _SEL_BORDER if selected else _DEFAULT_BORDER
	box.set_border_width_all(3 if selected else 1)
	box.bg_color = Color(0.06, 0.07, 0.1, 0.92)
	box.corner_radius_top_left = 10
	box.corner_radius_top_right = 10
	box.corner_radius_bottom_left = 10
	box.corner_radius_bottom_right = 10
	add_theme_stylebox_override("panel", box)


func set_preview_size(card_size: Vector2) -> void:
	custom_minimum_size = card_size
	size = card_size
	if _preview:
		_preview.custom_minimum_size = card_size


func _update_hotkey() -> void:
	if _hotkey_label:
		_hotkey_label.text = str(hotkey_index + 1)


func _on_click_pressed() -> void:
	if card_id != "":
		slot_pressed.emit(card_id)
