# scenes/song_select/run_modifiers/run_modifier_ce_setup_dialog.gd
extends Control
class_name RunModifierCeSetupDialog

signal setup_confirmed(order: Array, pool_enabled: Array)
signal cancelled()

const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const POOL_ROW_SCENE := preload("res://scenes/song_select/run_modifiers/run_modifier_ce_pool_row.tscn")
const ORDER_ROW_SCENE := preload("res://scenes/song_select/run_modifiers/run_modifier_ce_order_row.tscn")

@onready var _pool_hint: Label = %PoolHintLabel
@onready var _pool_list: VBoxContainer = %PoolList
@onready var _order_section: PanelContainer = %OrderSection
@onready var _order_hint: Label = %OrderHintLabel
@onready var _order_list: VBoxContainer = %OrderList
@onready var _order_buttons: HBoxContainer = %OrderButtons
@onready var _back_button: Button = %BackButton
@onready var _confirm_button: Button = %ConfirmButton
@onready var _title_label: Label = %TitleLabel
@onready var _body_hbox: HBoxContainer = %BodyHBox

var _order_ids: Array[String] = []
var _pool_enabled: Array[String] = []
var _pool_rows: Dictionary = {}
var _selected_index: int = -1


func _ready() -> void:
	visible = false
	UiIconHelper.configure_modal_overlay(self, 120)
	apply_locale()
	if _back_button and not _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.connect(_on_back_pressed)
	if _confirm_button and not _confirm_button.pressed.is_connected(_on_confirm_pressed):
		_confirm_button.pressed.connect(_on_confirm_pressed)
	%UpButton.pressed.connect(_on_move_up)
	%DownButton.pressed.connect(_on_move_down)
	_build_pool_rows()


func apply_locale() -> void:
	if _title_label:
		_title_label.text = tr("MOD_PARAM_CE_SETUP_TITLE")
	if _pool_hint:
		_pool_hint.text = tr("MOD_PARAM_CE_POOL_HINT")
	if _order_hint:
		_order_hint.text = tr("MOD_PARAM_CE_ORDER_HINT")
	if _back_button:
		_back_button.text = tr("BTN_BACK")
		UiIconHelper.setup_back_button(_back_button)
	if _confirm_button:
		_confirm_button.text = tr("MOD_CONFIRM")
		UiIconHelper.setup_confirm_button(_confirm_button)
	%UpButton.text = tr("MOD_PARAM_CE_ORDER_UP")
	%DownButton.text = tr("MOD_PARAM_CE_ORDER_DOWN")


func open_with(
	order: Variant,
	pool_enabled: Variant,
	pick_mode: String = _RunModifiers.CE_PICK_MODE_DEFAULT
) -> void:
	_order_ids = _RunModifiers.sanitize_combo_escalation_order(order)
	_pool_enabled = _RunModifiers.sanitize_combo_escalation_pool_enabled(pool_enabled)
	_selected_index = -1
	_apply_pool_state()
	_rebuild_order_list()
	var show_order := pick_mode == _RunModifiers.CE_PICK_CUSTOM_ORDER
	if _order_section:
		_order_section.visible = show_order
	if _body_hbox:
		_body_hbox.add_theme_constant_override("separation", 18 if show_order else 0)
	visible = true
	move_to_front()
	if _confirm_button:
		_confirm_button.grab_focus()


func dismiss() -> void:
	visible = false


func _on_back_pressed() -> void:
	cancelled.emit()
	dismiss()


func _on_confirm_pressed() -> void:
	var pool := _current_pool_enabled()
	var order := _RunModifiers.sanitize_combo_escalation_order(_order_ids)
	setup_confirmed.emit(order, pool)
	dismiss()


func _build_pool_rows() -> void:
	if _pool_list == null:
		return
	for child in _pool_list.get_children():
		child.queue_free()
	_pool_rows.clear()
	for mod_id in _RunModifiers.ESCALATION_POOL:
		var row := POOL_ROW_SCENE.instantiate()
		_pool_list.add_child(row)
		row.setup(mod_id, tr(_RunModifiers.title_i18n_key(mod_id)), true)
		row.toggled.connect(_on_pool_row_toggled)
		_pool_rows[mod_id] = row


func _apply_pool_state() -> void:
	var enabled := _pool_enabled.duplicate()
	if enabled.is_empty():
		for mod_id in _RunModifiers.ESCALATION_POOL:
			enabled.append(mod_id)
	for mod_id in _pool_rows:
		var row = _pool_rows[mod_id]
		if row:
			row.set_enabled(enabled.has(mod_id) or enabled.is_empty())


func _on_pool_row_toggled(mod_id: String, on: bool) -> void:
	if on:
		if not _pool_enabled.has(mod_id):
			_pool_enabled.append(mod_id)
	else:
		_pool_enabled.erase(mod_id)
		if _pool_enabled.is_empty() and not _RunModifiers.ESCALATION_POOL.is_empty():
			_pool_enabled.append(_RunModifiers.ESCALATION_POOL[0])
			var row = _pool_rows.get(_RunModifiers.ESCALATION_POOL[0], null)
			if row:
				row.set_enabled(true)
	_order_ids = _RunModifiers.sanitize_combo_escalation_order(_order_ids)
	_rebuild_order_list()


func _rebuild_order_list() -> void:
	if _order_list == null:
		return
	for child in _order_list.get_children():
		child.queue_free()
	var visible_order := _visible_order_ids()
	for i in visible_order.size():
		var mod_id := visible_order[i]
		var row := ORDER_ROW_SCENE.instantiate()
		_order_list.add_child(row)
		row.setup(i + 1, mod_id, tr(_RunModifiers.title_i18n_key(mod_id)), i == _selected_index)
		var idx := i
		row.pressed.connect(func(): _select_index(idx))


func _visible_order_ids() -> Array[String]:
	var enabled := _current_pool_enabled()
	var out: Array[String] = []
	for mod_id in _order_ids:
		if enabled.has(mod_id):
			out.append(mod_id)
	for mod_id in enabled:
		if not out.has(mod_id):
			out.append(mod_id)
	return out


func _current_pool_enabled() -> Array[String]:
	var out: Array[String] = []
	for mod_id in _RunModifiers.ESCALATION_POOL:
		var row = _pool_rows.get(mod_id, null)
		if row and row.is_enabled():
			out.append(mod_id)
	if out.is_empty() and not _RunModifiers.ESCALATION_POOL.is_empty():
		out.append(_RunModifiers.ESCALATION_POOL[0])
	return out


func _select_index(idx: int) -> void:
	_selected_index = idx
	_rebuild_order_list()


func _on_move_up() -> void:
	var visible := _visible_order_ids()
	if _selected_index <= 0 or _selected_index >= visible.size():
		return
	var mod_id := visible[_selected_index]
	var to_mod := visible[_selected_index - 1]
	_swap_order_ids(mod_id, to_mod)
	_selected_index -= 1
	_rebuild_order_list()


func _on_move_down() -> void:
	var visible := _visible_order_ids()
	if _selected_index < 0 or _selected_index >= visible.size() - 1:
		return
	var mod_id := visible[_selected_index]
	var to_mod := visible[_selected_index + 1]
	_swap_order_ids(mod_id, to_mod)
	_selected_index += 1
	_rebuild_order_list()


func _swap_order_ids(a: String, b: String) -> void:
	var ia := _order_ids.find(a)
	var ib := _order_ids.find(b)
	if ia < 0 or ib < 0:
		return
	var tmp := _order_ids[ia]
	_order_ids[ia] = _order_ids[ib]
	_order_ids[ib] = tmp


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
