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
@onready var _selection_ring: Panel = %SelectionRing


func _ready() -> void:
	if _click_button and not _click_button.pressed.is_connected(_on_click_pressed):
		_click_button.pressed.connect(_on_click_pressed)
	_update_hotkey()
	_apply_base_style()
	set_selected(false)


func setup(index: int, id: String) -> void:
	hotkey_index = index
	card_id = id
	_update_hotkey()


func set_texture(tex: Texture2D) -> void:
	if _preview:
		_preview.texture = tex
	if _loading_label:
		_loading_label.visible = tex == null


func get_preview_image() -> Image:
	if _preview == null or _preview.texture == null:
		return null
	var tex := _preview.texture
	if tex is ImageTexture:
		var img := (tex as ImageTexture).get_image()
		if img != null:
			return img.duplicate()
	if tex.has_method("get_image"):
		var from_tex: Variant = tex.get_image()
		if from_tex is Image:
			return (from_tex as Image).duplicate()
	return null


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
	if _selection_ring:
		_selection_ring.visible = selected
		if selected:
			var ring := StyleBoxFlat.new()
			ring.bg_color = Color(0, 0, 0, 0)
			ring.border_color = _SEL_BORDER
			ring.set_border_width_all(3)
			ring.set_corner_radius_all(10)
			ring.draw_center = false
			_selection_ring.add_theme_stylebox_override("panel", ring)


func set_preview_size(card_size: Vector2) -> void:
	custom_minimum_size = card_size
	size = card_size
	if _preview:
		_preview.custom_minimum_size = Vector2.ZERO


func _apply_base_style() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.07, 0.1, 0.92)
	box.border_color = _DEFAULT_BORDER
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.content_margin_left = 3
	box.content_margin_right = 3
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	add_theme_stylebox_override("panel", box)


func _update_hotkey() -> void:
	if _hotkey_label:
		_hotkey_label.text = str(hotkey_index + 1)


func _on_click_pressed() -> void:
	if card_id != "":
		slot_pressed.emit(card_id)
