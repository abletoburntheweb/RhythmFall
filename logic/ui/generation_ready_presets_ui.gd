# logic/ui/generation_ready_presets_ui.gd
extends RefCounted
class_name GenerationReadyPresetsUi

const _GenReadyPresets = preload("res://logic/domain/generation/generation_ready_presets.gd")
const _UserPresets = preload("res://logic/domain/modifiers/user_presets.gd")
const _GenPresetUi = preload("res://logic/ui/generation_preset_ui.gd")
const _SongSelectUiStyles = preload("res://scenes/song_select/lib/song_select_ui_styles.gd")
const _ChipScript = preload("res://scenes/song_select/endless/session_preset_ready_chip.gd")
const _UiModifierSounds = preload("res://logic/ui/ui_modifier_sounds.gd")

const SECTION_ID := "presets"


static func attach(host: VBoxContainer, accent: Color = Color(0.55, 0.78, 0.98, 1.0)) -> Dictionary:
	var state := {
		"host": host,
		"accent": accent,
		"section": null,
		"caption": null,
		"panel": null,
		"flow": null,
		"empty_label": null,
		"chips": {},
		"syncing": false,
	}
	if host == null:
		return state
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	host.add_child(section)
	state["section"] = section
	var caption := Label.new()
	caption.add_theme_font_size_override("font_size", 14)
	caption.add_theme_color_override("font_color", Color(0.62, 0.7, 0.82, 0.95))
	section.add_child(caption)
	state["caption"] = caption
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _SongSelectUiStyles.card_panel_style())
	section.add_child(panel)
	state["panel"] = panel
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	panel.add_child(inner)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	inner.add_child(flow)
	state["flow"] = flow
	var empty := Label.new()
	empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty.add_theme_font_size_override("font_size", 13)
	empty.add_theme_color_override("font_color", Color(0.58, 0.66, 0.78, 0.92))
	empty.visible = false
	inner.add_child(empty)
	state["empty_label"] = empty
	return state


static func apply_labels(state: Dictionary) -> void:
	var caption: Label = state.get("caption")
	if caption:
		caption.text = TranslationServer.translate("MISC_GEN_SCOPE_AXIS_PRESETS")
	var empty: Label = state.get("empty_label")
	if empty:
		empty.text = TranslationServer.translate("MISC_GEN_SCOPE_PRESETS_EMPTY")


static func sync_from_settings(state: Dictionary) -> void:
	if state.is_empty() or state.get("flow") == null:
		return
	state["syncing"] = true
	_rebuild_chips(state)
	var selected := _GenReadyPresets.resolve_ready_slots()
	var chips: Dictionary = state.get("chips", {})
	for slot_key in chips.keys():
		var chip = chips[slot_key]
		if chip:
			chip.set_selected(selected.has(int(slot_key)))
	state["syncing"] = false
	_update_empty_visibility(state)


static func persist_selection(state: Dictionary) -> void:
	var selected: Array[int] = []
	var chips: Dictionary = state.get("chips", {})
	for slot_key in chips.keys():
		var chip = chips[slot_key]
		if chip and chip.button_pressed:
			selected.append(int(slot_key))
	selected.sort()
	SettingsManager.set_setting("generation_ready_preset_slots", selected)
	SettingsManager.save_settings()


static func on_chip_toggled(state: Dictionary, slot_id: String, pressed: bool) -> void:
	if bool(state.get("syncing", false)):
		return
	persist_selection(state)
	_UiModifierSounds.play_toggle(pressed)
	NotesUtils.invalidate_notes_cache()
	_refresh_song_select_notes_highlights()


static func _rebuild_chips(state: Dictionary) -> void:
	var flow: HFlowContainer = state.get("flow")
	if flow == null:
		return
	for child in flow.get_children():
		child.queue_free()
	state["chips"] = {}
	var presets := SettingsManager.get_generation_presets()
	var filled := _GenReadyPresets.filled_slots(presets)
	var selected := _GenReadyPresets.resolve_ready_slots()
	for slot in filled:
		var entry := _UserPresets.get_generation_slot(presets, slot)
		var inst := str(entry.get("instrument", "drums")).to_lower()
		var icon_key := _GenPresetUi.entry_instrument_icon_key(inst)
		var icon_file := str(_GenPresetUi.INSTRUMENT_ICONS.get(icon_key, "drum.svg"))
		var tint: Color = _GenPresetUi.INSTRUMENT_ICON_COLORS.get(inst, state.get("accent", Color.WHITE))
		var name := _GenReadyPresets.slot_display_name(presets, slot)
		var chip = _ChipScript.new()
		chip.setup(
			str(slot),
			icon_file,
			tint,
			name,
			_GenReadyPresets.slot_tooltip(presets, slot),
		)
		chip.set_selected(selected.has(slot))
		chip.option_toggled.connect(func(id: String, on: bool): on_chip_toggled(state, id, on))
		flow.add_child(chip)
		state["chips"][str(slot)] = chip


static func _update_empty_visibility(state: Dictionary) -> void:
	var filled_count: int = int(state.get("chips", {}).size())
	var empty: Label = state.get("empty_label")
	var flow: HFlowContainer = state.get("flow")
	if empty:
		empty.visible = filled_count <= 0
	if flow:
		flow.visible = filled_count > 0


static func _refresh_song_select_notes_highlights() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_call_refresh_notes_highlights_recursive(tree.root)


static func _call_refresh_notes_highlights_recursive(node: Node) -> void:
	if node == null:
		return
	if node.has_method("refresh_generation_notes_highlights"):
		node.refresh_generation_notes_highlights()
	for child in node.get_children():
		_call_refresh_notes_highlights_recursive(child)
