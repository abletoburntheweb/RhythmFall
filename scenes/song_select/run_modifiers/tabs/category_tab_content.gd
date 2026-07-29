# scenes/song_select/run_modifiers/tabs/category_tab_content.gd
extends VBoxContainer

const CARD_SCENE := preload("res://scenes/song_select/run_modifiers/run_modifier_card.tscn")
const _Sections = preload("res://scenes/song_select/run_modifiers/run_modifier_sections.gd")
const _SubUi = preload("res://scenes/song_select/run_modifiers/run_modifier_subsection_ui.gd")

signal card_toggled(modifier_id: String, pressed: bool)
signal card_hovered(modifier_id: String)
signal card_unhovered(modifier_id: String)
signal card_info_requested(modifier_id: String)
signal card_dna_enable_blocked(modifier_id: String)

@onready var _content: VBoxContainer = $Scroll/Content

var _cards: Dictionary = {}


func build_sections(subsections: Array, _columns: int = 2) -> void:
	_cards.clear()
	if _content == null:
		return
	for child in _content.get_children():
		child.queue_free()
	var grid := _SubUi.make_subsection_grid(
		subsections,
		_Sections.CARD_CATEGORY,
		CARD_SCENE,
		_cards,
		func(mod_id: String, pressed: bool): card_toggled.emit(mod_id, pressed),
		15,
		func(mod_id: String): card_hovered.emit(mod_id),
		func(_mod_id: String): card_unhovered.emit(_mod_id),
		func(mod_id: String): card_info_requested.emit(mod_id),
		func(mod_id: String): card_dna_enable_blocked.emit(mod_id)
	)
	_content.add_child(grid)
	call_deferred("apply_locale")


func apply_locale() -> void:
	if _content:
		_SubUi.apply_locale_tree(_content)
	for card in _cards.values():
		if card and card.has_method("apply_locale"):
			card.apply_locale()


func set_modifier_active(modifier_id: String, active: bool) -> void:
	var card = _cards.get(modifier_id, null)
	if card and card.has_method("set_modifier_active"):
		card.set_modifier_active(active)


func get_card(modifier_id: String):
	return _cards.get(modifier_id, null)


func set_card_visible(modifier_id: String, visible: bool) -> void:
	var card = _cards.get(modifier_id, null)
	if card is Control:
		(card as Control).visible = visible


func set_card_disabled(modifier_id: String, is_disabled: bool, tooltip: String = "") -> void:
	var card = _cards.get(modifier_id, null)
	if card and card.has_method("set_modifier_disabled"):
		card.set_modifier_disabled(is_disabled, tooltip)


func set_card_dna_gated(modifier_id: String, is_gated: bool, tooltip: String = "") -> void:
	var card = _cards.get(modifier_id, null)
	if card and card.has_method("set_dna_gated"):
		card.set_dna_gated(is_gated, tooltip)


func set_card_preview_focus(modifier_id: String) -> void:
	for mod_id in _cards.keys():
		var card = _cards.get(mod_id, null)
		if card and card.has_method("set_preview_focused"):
			card.set_preview_focused(str(mod_id) == modifier_id)


func set_card_info_locked(modifier_id: String) -> void:
	for mod_id in _cards.keys():
		var card = _cards.get(mod_id, null)
		if card and card.has_method("set_info_locked"):
			card.set_info_locked(str(mod_id) == modifier_id)


func set_conflict_previews(conflict_ids: Array) -> void:
	var conflict_set: Dictionary = {}
	for cid in conflict_ids:
		conflict_set[str(cid)] = true
	for mod_id in _cards.keys():
		var card = _cards.get(mod_id, null)
		if card == null or not card.has_method("set_conflict_preview"):
			continue
		card.set_conflict_preview(conflict_set.has(str(mod_id)))


func refresh_card_params(params: Dictionary) -> void:
	for card in _cards.values():
		if card and card.has_method("apply_params_state"):
			card.apply_params_state(params)


func focus_first() -> void:
	for card in _cards.values():
		if card is Control:
			(card as Control).grab_focus()
			if card.has_signal("card_toggled"):
				card.card_toggled.emit(card.modifier_id, not card.button_pressed)
			return
