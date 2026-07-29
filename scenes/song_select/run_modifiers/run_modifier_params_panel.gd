# scenes/song_select/run_modifiers/run_modifier_params_panel.gd
extends VBoxContainer
class_name RunModifierParamsPanel

const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")

signal param_changed(param_id: String, value: Variant)

var _current_id: String = ""

@onready var _title_label: Label = $TitleLabel
@onready var _hint_label: Label = $HintLabel
@onready var _scroll: ScrollContainer = $Scroll
@onready var _mod_params_section: VBoxContainer = $Scroll/ModParamsSection


func _ready() -> void:
	apply_locale()
	if _scroll:
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	if _mod_params_section and _mod_params_section.has_signal("param_changed"):
		_mod_params_section.param_changed.connect(_on_mod_param_changed)
	clear()


func _on_mod_param_changed(param_id: String, value: Variant) -> void:
	param_changed.emit(param_id, value)


func apply_locale() -> void:
	if _hint_label:
		_hint_label.text = tr("MOD_PARAMS_SELECT_HINT")


func apply_params(params: Dictionary) -> void:
	if _mod_params_section and _mod_params_section.has_method("apply_params"):
		_mod_params_section.apply_params(params)


func clear() -> void:
	_current_id = ""
	if _title_label:
		_title_label.text = "—"
	if _hint_label:
		_hint_label.visible = true
	if _scroll:
		_scroll.visible = false
	if _mod_params_section and _mod_params_section.has_method("rebuild"):
		_mod_params_section.rebuild("", {})


func show_modifier(modifier_id: String, _active_modifiers: Array = [], params: Dictionary = {}) -> void:
	if modifier_id == "" or not _RunModifiers.modifier_has_detail_params(modifier_id):
		clear()
		return
	var same_mod := modifier_id == _current_id
	_current_id = modifier_id
	var title_key := "MOD_TITLE_%s" % modifier_id.to_upper()
	if _title_label:
		_title_label.text = tr(title_key)
	if _hint_label:
		_hint_label.visible = false
	if _scroll:
		_scroll.visible = true
	if _mod_params_section:
		if not same_mod:
			_mod_params_section.rebuild(modifier_id, params)
		else:
			_mod_params_section.apply_params(params)
