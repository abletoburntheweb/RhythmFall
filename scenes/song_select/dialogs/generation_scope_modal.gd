# scenes/song_select/dialogs/generation_scope_modal.gd
class_name GenerationScopeModal
extends Control
## Compact chart-readiness axes editor (synced with Settings → Generation → Parameters).

signal closed()

const _GoalDiff = preload("res://logic/domain/generation/generation_goal_difficulty.gd")
const _GenPresetUi = preload("res://logic/ui/generation_preset_ui.gd")
const _SongSelectUiStyles = preload("res://scenes/song_select/lib/song_select_ui_styles.gd")
const _ToggleIconScript = preload("res://scenes/song_select/endless/session_toggle_icon.gd")
const _GenReadyPresetsUi = preload("res://logic/ui/generation_ready_presets_ui.gd")
const _QuickGen = preload("res://logic/domain/generation/quick_generation_presets.gd")
const _SegmentedOptionUtils = preload("res://logic/ui/segmented_option_utils.gd")
const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")
const _UiModifierSounds = preload("res://logic/ui/ui_modifier_sounds.gd")

const _READY_DIFF_ICONS := {
	"easy": "feather.svg",
	"medium": "circle-check.svg",
	"hard": "flame_gen.svg",
}
const _READY_DIFF_COLORS := {
	"easy": Color(0.62, 0.82, 0.96, 1.0),
	"medium": Color(0.55, 0.78, 0.98, 1.0),
	"hard": Color(1.0, 0.58, 0.32, 1.0),
}

const _ACCENT := Color(0.55, 0.78, 0.98, 1.0)

# Hotkey scheme for this modal (per footer). Mirrors the player-facing binding hints.
const _HOTKEY_INSTRUMENTS := ["drums", "bass"]            # 1 / 2
const _HOTKEY_GOALS := ["original", "arcade"]             # Q / W
const _HOTKEY_DIFFS := ["easy", "medium", "hard"]         # A / S / D
const _HOTKEY_USER_SLOTS := [
	KEY_Z, KEY_X, KEY_C, KEY_V, KEY_B,
	KEY_N, KEY_M, KEY_COMMA, KEY_PERIOD, KEY_SLASH,
]

@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %TitleLabel
@onready var _hint_label: Label = %HintLabel
@onready var _axes_host: VBoxContainer = %AxesHost
@onready var _footer_label: Label = %FooterHintLabel

var _ready_axis_captions: Dictionary = {}
var _ready_axis_sections: Dictionary = {}
var _ready_value_icons: Dictionary = {}
var _ready_axes_built := false
var _ready_axes_syncing := false
var _ready_presets_state: Dictionary = {}
var _quick_gen_built := false
var _quick_preset_seg: Dictionary = {}
var _quick_gen_preset_option: OptionButton = null
var _quick_gen_caption: Label = null
var _glow_layer_prev_visible := true
var _glow_layer_hidden := false


func _ready() -> void:
	visible = false
	add_to_group("locale_refresh")
	_UiIconHelper.configure_modal_overlay(self, 160)
	# Soft dim (override configure_modal_overlay's ≥0.94 alpha). Hide GlowLayer while open
	# so radial_glow doesn't paint wash rings over this modal.
	var bg := get_node_or_null("Background") as ColorRect
	if bg:
		bg.color = Color(0.02, 0.03, 0.06, 0.72)
		bg.material = null
	if _back_button and not _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.connect(_on_back_pressed)
	_ensure_ready_axes_ui()
	apply_locale()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return visible


func handle_hotkey(event: InputEvent) -> bool:
	if not visible:
		return false
	if event.is_action_pressed("ui_cancel"):
		_close()
		return true
	if not (event is InputEventKey):
		return false
	var ke := event as InputEventKey
	if not ke.pressed or ke.echo:
		return false
	if ke.keycode == KEY_F1:
		_on_quick_gen_preset_pressed(1)
		return true
	if ke.keycode == KEY_F2:
		_on_quick_gen_preset_pressed(2)
		return true
	if ke.keycode == KEY_F3:
		_on_quick_gen_preset_pressed(3)
		return true
	if ke.keycode == KEY_1:
		_toggle_axis_value("instruments", _HOTKEY_INSTRUMENTS[0])
		return true
	if ke.keycode == KEY_2:
		_toggle_axis_value("instruments", _HOTKEY_INSTRUMENTS[1])
		return true
	if ke.keycode == KEY_Q:
		_toggle_axis_value("goals", _HOTKEY_GOALS[0])
		return true
	if ke.keycode == KEY_W:
		_toggle_axis_value("goals", _HOTKEY_GOALS[1])
		return true
	if ke.keycode == KEY_A:
		_toggle_axis_value("diffs", _HOTKEY_DIFFS[0])
		return true
	if ke.keycode == KEY_S:
		_toggle_axis_value("diffs", _HOTKEY_DIFFS[1])
		return true
	if ke.keycode == KEY_D:
		_toggle_axis_value("diffs", _HOTKEY_DIFFS[2])
		return true
	for i in range(_HOTKEY_USER_SLOTS.size()):
		if ke.keycode == _HOTKEY_USER_SLOTS[i]:
			_toggle_user_preset_slot(i + 1)
			return true
	if ke.keycode == KEY_ENTER or ke.keycode == KEY_KP_ENTER:
		_close()
		return true
	return false


func _toggle_axis_value(axis_id: String, value_id: String) -> void:
	if axis_id == "diffs":
		var section: Control = _ready_axis_sections.get("diffs")
		if section == null or not section.visible:
			return
	var icons: Dictionary = _ready_value_icons.get(axis_id, {})
	var icon: SessionToggleIcon = icons.get(str(value_id))
	if icon == null:
		return
	icon.button_pressed = not icon.button_pressed


func _toggle_user_preset_slot(slot: int) -> void:
	var chips: Dictionary = _ready_presets_state.get("chips", {})
	var chip = chips.get(str(slot))
	if chip == null:
		return
	chip.button_pressed = not chip.button_pressed


func apply_locale() -> void:
	if _back_button:
		_back_button.text = tr("BTN_BACK")
		_UiIconHelper.apply_standard_back_button(_back_button)
	if _title_label:
		_title_label.text = tr("MISC_GEN_SCOPE")
	if _hint_label:
		_hint_label.text = tr("MISC_GEN_SCOPE_TOOLTIP")
	if _footer_label:
		_footer_label.text = tr("GEN_SCOPE_FOOTER_HINT")
	if _quick_gen_caption != null:
		_quick_gen_caption.text = tr("SETTINGS_QUICK_GEN_TITLE")
	_apply_ready_axes_labels()
	_refresh_quick_gen_preset_ui()


func open() -> void:
	_ensure_ready_axes_ui()
	_sync_ready_axes_ui_from_settings()
	apply_locale()
	_hide_engine_glow()
	visible = true
	if _back_button:
		_back_button.grab_focus()
	# Select sound already played by make_settings_icon_button on press.


func _on_back_pressed() -> void:
	_close()


func _close() -> void:
	if not visible:
		return
	_UiModifierSounds.play_deselect()
	visible = false
	_restore_engine_glow()
	closed.emit()


func _hide_engine_glow() -> void:
	var glow := _engine_glow_layer()
	if glow == null or _glow_layer_hidden:
		return
	_glow_layer_prev_visible = glow.visible
	glow.visible = false
	_glow_layer_hidden = true


func _restore_engine_glow() -> void:
	if not _glow_layer_hidden:
		return
	var glow := _engine_glow_layer()
	if glow:
		glow.visible = _glow_layer_prev_visible
	_glow_layer_hidden = false


func _engine_glow_layer() -> CanvasLayer:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("GameEngine/GlowLayer") as CanvasLayer


func _exit_tree() -> void:
	_restore_engine_glow()


func _ensure_ready_axes_ui() -> void:
	if _axes_host == null or _ready_axes_built:
		return
	_ready_axes_built = true
	# Prevent window from collapsing when last chips removed (empty Instrument/Goal allowed)
	if _axes_host:
		_axes_host.custom_minimum_size.y = 280
		_axes_host.get_parent().custom_minimum_size.y = 320 if _axes_host.get_parent() else 320
		print("DEBUG_LAYOUT_MODAL: host min y=280, parent 320, preset=%s" % str(SettingsManager.get_setting("generation_ready_preset_slots", [])))
	_ensure_quick_gen_ui()
	_add_ready_axis_icons("instruments", "MISC_GEN_SCOPE_AXIS_INSTRUMENTS", _GoalDiff.READY_INSTRUMENTS)
	_add_ready_axis_icons("goals", "MISC_GEN_SCOPE_AXIS_GOALS", _GoalDiff.GOALS)
	_add_ready_axis_icons("diffs", "MISC_GEN_SCOPE_AXIS_DIFFS", _GoalDiff.DIFFICULTIES)
	_ready_presets_state = _GenReadyPresetsUi.attach(_axes_host, _ACCENT)
	_GenReadyPresetsUi.apply_labels(_ready_presets_state)
	_ready_presets_state["quick_preset_slot"] = _QuickGen.active_index()
	_ready_presets_state["on_presets_changed"] = _refresh_quick_gen_preset_ui
	_sync_ready_axes_ui_from_settings()


func _ready_value_label_key(axis_id: String, value_id: String) -> String:
	match axis_id:
		"goals":
			return "GEN_GOAL_%s" % value_id.to_upper()
		"diffs":
			return "GEN_DIFF_%s" % value_id.to_upper()
		_:
			return "GEN_INST_%s" % value_id.to_upper()


func _ready_value_tooltip(axis_id: String, value_id: String) -> String:
	if axis_id == "diffs":
		return tr("GEN_DIFF_%s" % value_id.to_upper())
	return tr(_ready_value_label_key(axis_id, value_id))


func _ready_icon_spec(axis_id: String, value_id: String) -> Dictionary:
	match axis_id:
		"goals":
			return {
				"icon": str(_GenPresetUi.INTENT_ICONS.get(value_id, "audio-lines.svg")),
				"tint": _GenPresetUi.INTENT_ICON_COLORS.get(value_id, _ACCENT),
			}
		"diffs":
			return {
				"icon": str(_READY_DIFF_ICONS.get(value_id, "circle-check.svg")),
				"tint": _READY_DIFF_COLORS.get(value_id, _ACCENT),
			}
		_:
			return {
				"icon": str(_GenPresetUi.INSTRUMENT_ICONS.get(value_id, "drum.svg")),
				"tint": _GenPresetUi.INSTRUMENT_ICON_COLORS.get(value_id, _ACCENT),
			}


func _add_ready_axis_icons(axis_id: String, caption_key: String, values: Array) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	_axes_host.add_child(section)
	_ready_axis_sections[axis_id] = section
	var caption := Label.new()
	caption.text = tr(caption_key)
	caption.add_theme_font_size_override("font_size", 14)
	caption.add_theme_color_override("font_color", Color(0.62, 0.7, 0.82, 0.95))
	section.add_child(caption)
	_ready_axis_captions[axis_id] = caption
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _SongSelectUiStyles.card_panel_style())
	section.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	_ready_value_icons[axis_id] = {}
	for value_id in values:
		var vid := str(value_id)
		var spec := _ready_icon_spec(axis_id, vid)
		var icon := _ToggleIconScript.new() as SessionToggleIcon
		icon.setup(
			vid,
			str(spec.get("icon", "")),
			spec.get("tint", _ACCENT) as Color,
			_ready_value_tooltip(axis_id, vid)
		)
		icon.option_toggled.connect(_on_ready_icon_toggled.bind(axis_id))
		row.add_child(icon)
		_ready_value_icons[axis_id][vid] = icon


func _apply_ready_axes_labels() -> void:
	var caption_keys := {
		"goals": "MISC_GEN_SCOPE_AXIS_GOALS",
		"diffs": "MISC_GEN_SCOPE_AXIS_DIFFS",
		"instruments": "MISC_GEN_SCOPE_AXIS_INSTRUMENTS",
	}
	for axis_id in _ready_axis_captions.keys():
		var caption: Label = _ready_axis_captions[axis_id]
		if caption:
			caption.text = tr(str(caption_keys.get(axis_id, "")))
		var icons: Dictionary = _ready_value_icons.get(axis_id, {})
		for value_id in icons.keys():
			var icon: SessionToggleIcon = icons[value_id]
			if icon:
				icon.set_tooltip_text_value(_ready_value_tooltip(str(axis_id), str(value_id)))
	_GenReadyPresetsUi.apply_labels(_ready_presets_state)


func _sync_ready_axes_ui_from_settings() -> void:
	if not _ready_axes_built:
		return
	_ready_axes_syncing = true
	_set_ready_axis_icons(
		"goals",
		SettingsManager.get_setting("generation_ready_goals", [_GoalDiff.DEFAULT_GOAL]),
		_GoalDiff.GOALS,
		str(SettingsManager.get_setting("generation_goal", _GoalDiff.DEFAULT_GOAL))
	)
	_set_ready_axis_icons(
		"diffs",
		SettingsManager.get_setting("generation_ready_diffs", [_GoalDiff.DEFAULT_DIFFICULTY]),
		_GoalDiff.DIFFICULTIES,
		str(SettingsManager.get_setting("generation_difficulty", _GoalDiff.DEFAULT_DIFFICULTY))
	)
	_set_ready_axis_icons(
		"instruments",
		SettingsManager.get_setting("generation_ready_instruments", [_GoalDiff.DEFAULT_READY_INSTRUMENT]),
		_GoalDiff.READY_INSTRUMENTS,
		str(SettingsManager.get_setting("last_generation_instrument", _GoalDiff.DEFAULT_READY_INSTRUMENT))
	)
	_sync_ready_diffs_row_visibility()
	_GenReadyPresetsUi.sync_from_settings(_ready_presets_state)
	_ready_axes_syncing = false


func _set_ready_axis_icons(axis_id: String, selected_raw: Variant, allowed: Array, fallback: String) -> void:
	var allow_empty := _has_custom_generation_preset() and axis_id in ["instruments", "goals"]
	var selected := _GoalDiff.sanitize_ready_string_list(selected_raw, allowed, fallback, allow_empty)
	var icons: Dictionary = _ready_value_icons.get(axis_id, {})
	for value_id in icons.keys():
		var icon: SessionToggleIcon = icons[value_id]
		if icon:
			icon.set_selected(selected.has(str(value_id)))


func _ready_goals_include_arcade() -> bool:
	var icons: Dictionary = _ready_value_icons.get("goals", {})
	var arcade: SessionToggleIcon = icons.get("arcade")
	if arcade:
		return arcade.button_pressed
	return false


func _sync_ready_diffs_row_visibility() -> void:
	var section: Control = _ready_axis_sections.get("diffs")
	if section:
		section.visible = _ready_goals_include_arcade()


func _reset_diffs_for_non_arcade() -> void:
	if _ready_goals_include_arcade():
		return
	_ready_axes_syncing = true
	_set_ready_axis_icons(
		"diffs",
		[],
		_GoalDiff.DIFFICULTIES,
		str(_GoalDiff.DEFAULT_DIFFICULTY)
	)
	_ready_axes_syncing = false
	SettingsManager.set_setting("generation_ready_diffs", [])


func _has_custom_generation_preset() -> bool:
	var slots: Variant = SettingsManager.get_setting("generation_ready_preset_slots", [])
	if slots is Array and slots.size() > 0:
		return true
	var gen_presets: Variant = SettingsManager.get_generation_presets()
	if gen_presets is Dictionary and int(gen_presets.get("active_slot", 0)) > 0:
		return true
	return false

func _on_ready_icon_toggled(value_id: String, pressed: bool, axis_id: String) -> void:
	if _ready_axes_syncing:
		return
	if not pressed and _count_axis_selected(axis_id) <= 0:
		if _has_custom_generation_preset() and axis_id in ["instruments", "goals"]:
			pass
		else:
			var icon: SessionToggleIcon = _ready_value_icons.get(axis_id, {}).get(value_id)
			if icon:
				icon.set_selected(true)
			if MusicManager and MusicManager.has_method("play_cancel_sound"):
				MusicManager.play_cancel_sound()
			else:
				_UiModifierSounds.play_deselect()
			return
	_persist_ready_axis_values(axis_id)
	if axis_id == "goals":
		_sync_ready_diffs_row_visibility()
		_reset_diffs_for_non_arcade()
	_UiModifierSounds.play_toggle(pressed)
	NotesUtils.invalidate_notes_cache()
	_refresh_song_select_notes_highlights()
	_quick_gen_sync_active_preset_from_settings()
	_refresh_quick_gen_preset_ui()


func _count_axis_selected(axis_id: String) -> int:
	var count := 0
	var icons: Dictionary = _ready_value_icons.get(axis_id, {})
	for icon in icons.values():
		if icon and (icon as SessionToggleIcon).button_pressed:
			count += 1
	return count


func _ensure_axis_has_selection(axis_id: String) -> void:
	if _count_axis_selected(axis_id) > 0:
		return
	var fallback := ""
	match axis_id:
		"goals":
			fallback = str(SettingsManager.get_setting("generation_goal", _GoalDiff.DEFAULT_GOAL))
		"diffs":
			fallback = str(SettingsManager.get_setting("generation_difficulty", _GoalDiff.DEFAULT_DIFFICULTY))
		_:
			fallback = str(SettingsManager.get_setting("last_generation_instrument", _GoalDiff.DEFAULT_READY_INSTRUMENT))
	var icons: Dictionary = _ready_value_icons.get(axis_id, {})
	var icon: SessionToggleIcon = icons.get(fallback)
	if icon == null and not icons.is_empty():
		icon = icons.values()[0]
	if icon:
		icon.set_selected(true)


func _persist_ready_axis_values(axis_id: String) -> void:
	var selected: Array[String] = []
	var icons: Dictionary = _ready_value_icons.get(axis_id, {})
	for value_id in icons.keys():
		var icon: SessionToggleIcon = icons[value_id]
		if icon and icon.button_pressed:
			selected.append(str(value_id))
	if selected.is_empty():
		if _has_custom_generation_preset() and axis_id in ["instruments", "goals"]:
			pass
		else:
			_ensure_axis_has_selection(axis_id)
			for value_id in icons.keys():
				var icon2: SessionToggleIcon = icons[value_id]
				if icon2 and icon2.button_pressed:
					selected.append(str(value_id))
	SettingsManager.set_setting("generation_ready_%s" % axis_id, selected)


func _refresh_song_select_notes_highlights() -> void:
	var tree := get_tree()
	if tree == null:
		return
	_call_refresh_notes_highlights_recursive(tree.root)


func _call_refresh_notes_highlights_recursive(node: Node) -> void:
	if node == null:
		return
	if node.has_method("refresh_generation_notes_highlights"):
		node.refresh_generation_notes_highlights()
	for child in node.get_children():
		_call_refresh_notes_highlights_recursive(child)


func _ensure_quick_gen_ui() -> void:
	if _quick_gen_built:
		return
	if _axes_host == null:
		return
	_quick_gen_built = true
	var section := VBoxContainer.new()
	section.name = "QuickGenSection"
	section.add_theme_constant_override("separation", 6)
	_axes_host.add_child(section)
	_quick_gen_caption = Label.new()
	_quick_gen_caption.add_theme_font_size_override("font_size", 14)
	_quick_gen_caption.add_theme_color_override("font_color", Color(0.62, 0.7, 0.82, 0.95))
	_quick_gen_caption.text = tr("SETTINGS_QUICK_GEN_TITLE")
	section.add_child(_quick_gen_caption)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _SongSelectUiStyles.card_panel_style())
	section.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	_quick_gen_preset_option = OptionButton.new()
	row.add_child(_quick_gen_preset_option)
	_quick_gen_preset_option.add_item(tr("GEN_PRESET_DEFAULT"), 0)
	for slot in range(1, _QuickGen.COUNT + 1):
		_quick_gen_preset_option.add_item(_QuickGen.display_name(slot), slot)
	_quick_preset_seg = _SegmentedOptionUtils.build_from_option_button(_quick_gen_preset_option, 18, 40, 0.0)
	var seg_container = _quick_preset_seg.get("container")
	if seg_container:
		seg_container.size_flags_horizontal = Control.SIZE_SHRINK_END
		seg_container.custom_minimum_size.x = 0.0
		seg_container.add_theme_constant_override("separation", 6)
		seg_container.alignment = BoxContainer.ALIGNMENT_END
	for btn in _quick_preset_seg.get("buttons", []):
		if btn is Button:
			var b := btn as Button
			b.custom_minimum_size = Vector2(0, 40)
			b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			b.pressed.connect(_on_quick_gen_preset_segment_pressed.bind(b))
	_refresh_quick_gen_preset_ui()


func _refresh_quick_gen_preset_ui() -> void:
	if _quick_preset_seg.is_empty():
		return
	var buttons: Array = _quick_preset_seg.get("buttons", [])
	if buttons.is_empty():
		return
	var default_btn: Button = null
	var slot_buttons := {}
	for raw_btn in buttons:
		var b := raw_btn as Button
		if b == null:
			continue
		var oid := _SegmentedOptionUtils.id_from_button(b)
		if oid <= 0:
			default_btn = b
		else:
			slot_buttons[oid] = b
	for slot in range(1, _QuickGen.COUNT + 1):
		var name_label := _QuickGen.display_name(slot)
		var label := _quick_gen_compact_label(slot)
		var b: Button = slot_buttons.get(slot)
		if b != null:
			b.text = label
			b.tooltip_text = tr("SETTINGS_QUICK_GEN_PRESET_TOOLTIP_FMT") % name_label
	if default_btn != null:
		default_btn.text = tr("GEN_PRESET_DEFAULT")
		default_btn.tooltip_text = tr("SETTINGS_QUICK_GEN_DEFAULT_TOOLTIP")
	_SegmentedOptionUtils.select_id(buttons, _QuickGen.active_index())


func _quick_gen_compact_label(slot: int) -> String:
	var g_preset: Array = SettingsManager.get_setting("generation_ready_preset_slots", [])
	var g_instr: Array = SettingsManager.get_setting("generation_ready_instruments", [])
	var g_goals: Array = SettingsManager.get_setting("generation_ready_goals", [])
	var g_diffs: Array = SettingsManager.get_setting("generation_ready_diffs", [])
	print("DEBUG_PRESET_MODAL: slot=%d g_preset=%s g_instr=%s g_goals=%s" % [slot, str(g_preset), str(g_instr), str(g_goals)])
	if g_preset.size()==1 and g_instr.is_empty() and g_goals.is_empty() and g_preset.has(slot):
		print("DEBUG_PRESET_MODAL: early +1 for slot %d" % slot)
		var key_label_fix := _QuickGen.hotkey_label(slot)
		var p_fix := PackedStringArray()
		if key_label_fix.strip_edges() != "":
			p_fix.append(key_label_fix)
		p_fix.append("+1")
		return " · ".join(p_fix)
	if not g_preset.is_empty() and g_preset.has(slot):
		var stems := _GoalDiff.stems_for_ready_axes(g_goals, g_diffs)
		var prod_variants := g_instr.size() * stems.size() if not g_instr.is_empty() and not stems.is_empty() else 0
		var preset_variants := g_preset.size() if g_instr.is_empty() else g_instr.size() * g_preset.size()
		var total_variants := prod_variants + preset_variants
		if total_variants == 4 and g_instr.size()==2 and stems.size()==1:
			var key_label2 := _QuickGen.hotkey_label(slot)
			var primary2 := ""
			if not g_instr.is_empty():
				primary2 = _GenPresetUi.localized_instrument(str(g_instr[0]))
			elif not g_goals.is_empty():
				primary2 = _GenPresetUi.localized_goal(str(g_goals[0]).strip_edges().to_lower())
			var p2 := PackedStringArray()
			if key_label2.strip_edges() != "":
				p2.append(key_label2)
			if primary2 != "":
				p2.append(primary2)
			p2.append("+%d" % (total_variants - 1))
			return " · ".join(p2)
	var body := _QuickGen.get_preset(slot)
	var instruments: Array = body.get("ready_instruments", [])
	var goals: Array = body.get("ready_goals", [])
	var diffs: Array = body.get("ready_diffs", [])
	var key_label := _QuickGen.hotkey_label(slot)
	var preset_cnt := _QuickGen.ready_user_preset_count(slot)
	var primary := ""
	if not instruments.is_empty():
		primary = _GenPresetUi.localized_instrument(str(instruments[0]))
	elif not goals.is_empty():
		primary = _GenPresetUi.localized_goal(str(goals[0]).strip_edges().to_lower())
	if primary == "":
		if preset_cnt > 0:
			var parts2 := PackedStringArray()
			if key_label.strip_edges() != "":
				parts2.append(key_label)
			var full_p := _QuickGen.display_name(slot)
			if full_p.strip_edges() != "" and full_p != str(slot):
				parts2.append(full_p)
			parts2.append("+%d" % preset_cnt)
			return " · ".join(parts2)
		var full_q := _QuickGen.display_name(slot)
		return "%s · %s" % [key_label, full_q] if key_label.strip_edges() != "" else full_q
	var total := instruments.size() + goals.size() + diffs.size()
	var extra := maxi(total - 1, 0)
	extra += preset_cnt
	var parts := PackedStringArray()
	if key_label.strip_edges() != "":
		parts.append(key_label)
	parts.append(primary)
	if extra > 0:
		parts.append("+%d" % extra)
	return " · ".join(parts)


func _on_quick_gen_preset_segment_pressed(btn: Button) -> void:
	if btn == null:
		return
	_on_quick_gen_preset_pressed(_SegmentedOptionUtils.id_from_button(btn))


func _on_quick_gen_preset_pressed(slot: int) -> void:
	if _QuickGen == null:
		return
	if _QuickGen.active_index() > 0:
		_QuickGen.sync_active_from_settings()
	_UiModifierSounds.play_select()
	_QuickGen.set_active(slot)
	_sync_ready_axes_ui_from_preset(slot)
	_ready_presets_state["quick_preset_slot"] = slot
	_refresh_quick_gen_preset_ui()
	_GenReadyPresetsUi.sync_from_settings(_ready_presets_state)


func _quick_gen_sync_active_preset_from_settings() -> void:
	if _QuickGen != null:
		_QuickGen.sync_active_from_settings()


func _sync_ready_axes_ui_from_preset(slot: int) -> void:
	if _axes_host == null or not _ready_axes_built:
		return
	_ready_axes_syncing = true
	var body := _QuickGen.get_preset(slot)
	_set_ready_axis_icons(
		"goals",
		body.get("ready_goals", []),
		_GoalDiff.GOALS,
		str(_GoalDiff.DEFAULT_GOAL)
	)
	_set_ready_axis_icons(
		"diffs",
		body.get("ready_diffs", []),
		_GoalDiff.DIFFICULTIES,
		str(_GoalDiff.DEFAULT_DIFFICULTY)
	)
	_set_ready_axis_icons(
		"instruments",
		body.get("ready_instruments", []),
		_GoalDiff.READY_INSTRUMENTS,
		str(_GoalDiff.DEFAULT_READY_INSTRUMENT)
	)
	_QuickGen.apply_to_settings(body)
	_sync_ready_diffs_row_visibility()
	_ready_axes_syncing = false
