# scenes/song_select/run_modifiers/run_modifier_ce_pool_row.gd
extends HBoxContainer

signal toggled(mod_id: String, on: bool)

const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")

@onready var _icon: TextureRect = $Icon
@onready var _check: CheckButton = $Check

var modifier_id: String = ""


func setup(p_mod_id: String, title_text: String, enabled: bool) -> void:
	modifier_id = p_mod_id
	if _check:
		_check.text = title_text
		_check.set_pressed_no_signal(enabled)
		if not _check.toggled.is_connected(_on_check_toggled):
			_check.toggled.connect(_on_check_toggled)
	_refresh_icon()


func set_enabled(on: bool) -> void:
	if _check:
		_check.set_pressed_no_signal(on)


func is_enabled() -> bool:
	return _check.button_pressed if _check else false


func _refresh_icon() -> void:
	if _icon == null or modifier_id == "":
		return
	var file_name := _RunModifiers.icon_file(modifier_id)
	if file_name == "":
		_icon.visible = false
		return
	_icon.texture = UiIconHelper.load_tinted_icon(
		file_name,
		_RunModifiers.category_tint(modifier_id, true)
	)
	_icon.visible = _icon.texture != null


func _on_check_toggled(on: bool) -> void:
	toggled.emit(modifier_id, on)
