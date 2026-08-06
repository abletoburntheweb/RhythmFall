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
	return false


func apply_locale() -> void:
	if _back_button:
		_back_button.text = tr("BTN_BACK")
		_UiIconHelper.apply_standard_back_button(_back_button)
	if _title_label:
		_title_label.text = tr("MISC_GEN_SCOPE")
	if _hint_label:
		_hint_label.text = tr("MISC_GEN_SCOPE_TOOLTIP")
	if _footer_label:
		_footer_label.text = tr("PROFILE_ACTIVITY_MODAL_FOOTER")
	_apply_ready_axes_labels()


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
	_add_ready_axis_icons("instruments", "MISC_GEN_SCOPE_AXIS_INSTRUMENTS", _GoalDiff.READY_INSTRUMENTS)
	_add_ready_axis_icons("goals", "MISC_GEN_SCOPE_AXIS_GOALS", _GoalDiff.GOALS)
	_add_ready_axis_icons("diffs", "MISC_GEN_SCOPE_AXIS_DIFFS", _GoalDiff.DIFFICULTIES)
	_ready_presets_state = _GenReadyPresetsUi.attach(_axes_host, _ACCENT)
	_GenReadyPresetsUi.apply_labels(_ready_presets_state)
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
	var selected := _GoalDiff.sanitize_ready_string_list(selected_raw, allowed, fallback)
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


func _on_ready_icon_toggled(value_id: String, pressed: bool, axis_id: String) -> void:
	if _ready_axes_syncing:
		return
	if not pressed and _count_axis_selected(axis_id) <= 0:
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
	_UiModifierSounds.play_toggle(pressed)
	NotesUtils.invalidate_notes_cache()
	_refresh_song_select_notes_highlights()


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
