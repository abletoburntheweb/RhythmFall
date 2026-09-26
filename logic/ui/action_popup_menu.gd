# logic/ui/action_popup_menu.gd
# Compact "⋯" button + PopupMenu under the button.
extends Button
class_name ActionPopupMenu

signal action_id_pressed(id: int)

var _popup: PopupMenu


func _ready() -> void:
	text = "⋯"
	flat = true
	focus_mode = Control.FOCUS_ALL
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(44, 44)
	_ensure_popup()
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)


func setup_items(items: Array) -> void:
	_ensure_popup()
	_popup.clear()
	for item in items:
		if item is not Dictionary:
			continue
		var label := str((item as Dictionary).get("label", "")).strip_edges()
		var id := int((item as Dictionary).get("id", -1))
		if label == "" or id < 0:
			continue
		_popup.add_item(label, id)


func set_menu_tooltip(tip: String) -> void:
	tooltip_text = tip


func _ensure_popup() -> void:
	if _popup != null and is_instance_valid(_popup):
		return
	_popup = PopupMenu.new()
	_popup.name = "ActionPopup"
	add_child(_popup)
	if not _popup.id_pressed.is_connected(_on_id_pressed):
		_popup.id_pressed.connect(_on_id_pressed)


func _on_pressed() -> void:
	_ensure_popup()
	if _popup.item_count <= 0:
		return
	var origin := global_position + Vector2(0.0, size.y)
	_popup.position = Vector2i(int(origin.x), int(origin.y))
	_popup.popup()


func _on_id_pressed(id: int) -> void:
	action_id_pressed.emit(id)
