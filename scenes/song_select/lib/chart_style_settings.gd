# scenes/song_select/lib/chart_style_settings.gd
extends VBoxContainer
class_name ChartStyleSettings

signal settings_changed(config_fragment: Dictionary)

const _EndlessSessionConfig = preload("res://logic/domain/session/endless_session_config.gd")
const _SongSelectUiStyles = preload("res://scenes/song_select/lib/song_select_ui_styles.gd")
const _GenPresetUi = preload("res://logic/ui/generation_preset_ui.gd")
const _ToggleIconScript = preload("res://scenes/song_select/endless/session_toggle_icon.gd")
const _SettingsSectionUi = preload("res://logic/ui/settings_section_ui.gd")

const TIER_ICONS := {
	"easy": "feather.svg",
	"medium": "circle-check.svg",
	"hard": "flame_gen.svg",
}

const TIER_COLORS := {
	"easy": Color(0.62, 0.82, 0.96, 1.0),
	"medium": Color(0.55, 0.78, 0.98, 1.0),
	"hard": Color(1.0, 0.58, 0.32, 1.0),
}

var _accent := Color(0.62, 0.48, 0.95, 1.0)
var _style_checks: Dictionary = {}
var _checks_panel: PanelContainer = null
var _difficulty_tier_checks: Dictionary = {}
var _difficulty_tiers_panel: PanelContainer = null
var _difficulty_tier_caption: Label = null
var _difficulty_section_nodes: Array[Control] = []
var _title_label: Label = null


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_build_ui()
	_apply_config(_default_fragment())


func set_accent_color(color: Color) -> void:
	_accent = color


func set_difficulty_section_visible(visible: bool) -> void:
	for node in _difficulty_section_nodes:
		if node:
			node.visible = visible


func set_config(config: Dictionary) -> void:
	_apply_config(_fragment_from_config(config))


func get_config_fragment() -> Dictionary:
	var allowed: Array[String] = []
	for intent_id in _style_checks.keys():
		var icon: SessionToggleIcon = _style_checks[intent_id]
		if icon and icon.button_pressed:
			allowed.append(str(intent_id))
	if allowed.is_empty():
		allowed = ["original"]
	var all_styles := allowed.size() >= _EndlessSessionConfig.UI_CHART_STYLE_GOALS.size()
	var tiers_allowed: Array[String] = []
	for tier_id in _difficulty_tier_checks.keys():
		var icon: SessionToggleIcon = _difficulty_tier_checks[tier_id]
		if icon and icon.button_pressed:
			tiers_allowed.append(str(tier_id))
	if tiers_allowed.is_empty():
		tiers_allowed = [_EndlessSessionConfig.CHART_DIFFICULTY_TIER_MEDIUM]
	var all_tiers := tiers_allowed.size() >= _EndlessSessionConfig.ALL_CHART_DIFFICULTY_TIERS.size()
	return {
		"generation_mode_policy": (
			_EndlessSessionConfig.GEN_MODE_POLICY_ALL if all_styles
			else _EndlessSessionConfig.GEN_MODE_POLICY_SELECTED
		),
		"generation_modes_allowed": [] if all_styles else allowed,
		"chart_difficulty_policy": (
			_EndlessSessionConfig.CHART_DIFFICULTY_POLICY_ALL if all_tiers
			else _EndlessSessionConfig.CHART_DIFFICULTY_POLICY_SELECTED
		),
		"chart_difficulty_tiers_allowed": (
			[] if all_tiers else tiers_allowed
		),
		"chart_difficulty_tier": tiers_allowed[0],
	}


func apply_locale() -> void:
	if _title_label:
		_title_label.text = tr("SESSION_CHART_STYLE_TITLE")
	if _help_link:
		_help_link.tooltip_text = tr("HELP_LINK_CHART_STYLE")
	if _difficulty_tier_caption:
		_difficulty_tier_caption.text = tr("SESSION_CHART_DIFFICULTY_TIER_CAPTION")
	for intent_id in _style_checks.keys():
		var icon: SessionToggleIcon = _style_checks[intent_id]
		if icon:
			icon.set_tooltip_text_value(tr(_EndlessSessionConfig.generation_mode_label_key(intent_id)))
	for tier_id in _difficulty_tier_checks.keys():
		var icon: SessionToggleIcon = _difficulty_tier_checks[tier_id]
		if icon:
			icon.set_tooltip_text_value(tr(_EndlessSessionConfig.chart_difficulty_tier_label_key(tier_id)))
	_apply_config(_fragment_from_config(get_config_fragment()))


func _default_fragment() -> Dictionary:
	return {
		"generation_mode_policy": _EndlessSessionConfig.GEN_MODE_POLICY_ALL,
		"generation_modes_allowed": ["original", "arcade"],
		"chart_difficulty_policy": _EndlessSessionConfig.CHART_DIFFICULTY_POLICY_ALL,
		"chart_difficulty_tiers_allowed": _EndlessSessionConfig.ALL_CHART_DIFFICULTY_TIERS.duplicate(),
		"chart_difficulty_tier": _EndlessSessionConfig.CHART_DIFFICULTY_TIER_MEDIUM,
	}


func _fragment_from_config(config: Dictionary) -> Dictionary:
	var sanitized := _EndlessSessionConfig.sanitize(config)
	var policy := str(sanitized.get("generation_mode_policy", _EndlessSessionConfig.GEN_MODE_POLICY_ALL))
	var allowed: Array = sanitized.get("generation_modes_allowed", [])
	var ui_allowed: Array[String] = []
	if policy == _EndlessSessionConfig.GEN_MODE_POLICY_ALL or allowed.is_empty():
		ui_allowed = _EndlessSessionConfig.UI_CHART_STYLE_GOALS.duplicate()
	else:
		for intent_id in _EndlessSessionConfig.UI_CHART_STYLE_INTENTS:
			if allowed.has(intent_id):
				ui_allowed.append(intent_id)
		if ui_allowed.is_empty():
			ui_allowed = ["original"]
	var diff_policy := str(
		sanitized.get("chart_difficulty_policy", _EndlessSessionConfig.CHART_DIFFICULTY_POLICY_ALL)
	)
	var tiers_allowed: Array = sanitized.get("chart_difficulty_tiers_allowed", [])
	var ui_tiers: Array[String] = []
	if diff_policy == _EndlessSessionConfig.CHART_DIFFICULTY_POLICY_ALL or tiers_allowed.is_empty():
		ui_tiers = _EndlessSessionConfig.ALL_CHART_DIFFICULTY_TIERS.duplicate()
	else:
		for tier_id in _EndlessSessionConfig.ALL_CHART_DIFFICULTY_TIERS:
			if tiers_allowed.has(tier_id):
				ui_tiers.append(tier_id)
		if ui_tiers.is_empty():
			ui_tiers = _EndlessSessionConfig.ALL_CHART_DIFFICULTY_TIERS.duplicate()
	return {
		"generation_mode_policy": policy,
		"generation_modes_allowed": ui_allowed,
		"chart_difficulty_policy": diff_policy,
		"chart_difficulty_tiers_allowed": ui_tiers,
		"chart_difficulty_tier": str(sanitized.get("chart_difficulty_tier", _EndlessSessionConfig.CHART_DIFFICULTY_TIER_MEDIUM)),
	}


var _help_link: Button = null
var _help_article_id := "modes"


func set_help_article_id(item_id: String) -> void:
	_help_article_id = item_id.strip_edges()
	if _help_link:
		_help_link.visible = _help_article_id != ""


func _build_ui() -> void:
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 6)
	add_child(title_row)

	_title_label = Label.new()
	_title_label.text = tr("SESSION_CHART_STYLE_TITLE")
	_title_label.add_theme_font_size_override("font_size", 15)
	_title_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.98, 1.0))
	_title_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(_title_label)

	_help_link = _SettingsSectionUi.make_help_icon_button(tr("HELP_LINK_CHART_STYLE"))
	_help_link.pressed.connect(_on_help_link_pressed)
	title_row.add_child(_help_link)
	title_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	_checks_panel = PanelContainer.new()
	_checks_panel.add_theme_stylebox_override("panel", _SongSelectUiStyles.card_panel_style())
	var checks_flow := HBoxContainer.new()
	checks_flow.add_theme_constant_override("separation", 10)
	_checks_panel.add_child(checks_flow)
	for intent_id in _EndlessSessionConfig.UI_CHART_STYLE_INTENTS:
		var icon_file := str(_GenPresetUi.INTENT_ICONS.get(intent_id, "audio-lines.svg"))
		var tint: Color = _GenPresetUi.INTENT_ICON_COLORS.get(intent_id, _accent) as Color
		var icon := _ToggleIconScript.new() as SessionToggleIcon
		icon.setup(
			intent_id,
			icon_file,
			tint,
			tr(_EndlessSessionConfig.generation_mode_label_key(intent_id))
		)
		icon.option_toggled.connect(_on_style_check_toggled)
		checks_flow.add_child(icon)
		_style_checks[intent_id] = icon
	add_child(_checks_panel)

	_difficulty_tier_caption = Label.new()
	_difficulty_tier_caption.text = tr("SESSION_CHART_DIFFICULTY_TIER_CAPTION")
	_difficulty_tier_caption.add_theme_font_size_override("font_size", 14)
	_difficulty_tier_caption.add_theme_color_override("font_color", Color(0.62, 0.7, 0.82, 0.95))
	add_child(_difficulty_tier_caption)
	_difficulty_section_nodes.append(_difficulty_tier_caption)

	_difficulty_tiers_panel = PanelContainer.new()
	_difficulty_tiers_panel.add_theme_stylebox_override("panel", _SongSelectUiStyles.card_panel_style())
	var tiers_flow := HBoxContainer.new()
	tiers_flow.add_theme_constant_override("separation", 10)
	_difficulty_tiers_panel.add_child(tiers_flow)
	for tier_id in _EndlessSessionConfig.ALL_CHART_DIFFICULTY_TIERS:
		var icon_file := str(TIER_ICONS.get(tier_id, "layers.svg"))
		var tint: Color = TIER_COLORS.get(tier_id, _accent)
		var icon := _ToggleIconScript.new() as SessionToggleIcon
		icon.setup(
			tier_id,
			icon_file,
			tint,
			tr(_EndlessSessionConfig.chart_difficulty_tier_label_key(tier_id))
		)
		icon.option_toggled.connect(_on_difficulty_tier_check_toggled)
		tiers_flow.add_child(icon)
		_difficulty_tier_checks[tier_id] = icon
	add_child(_difficulty_tiers_panel)
	_difficulty_section_nodes.append(_difficulty_tiers_panel)


func _apply_config(fragment: Dictionary) -> void:
	var allowed: Array = fragment.get("generation_modes_allowed", [])
	for intent_id in _style_checks.keys():
		var icon: SessionToggleIcon = _style_checks[intent_id]
		if icon:
			icon.set_selected(allowed.has(intent_id))
	if _checks_panel:
		_checks_panel.visible = true
	var tiers_allowed: Array = fragment.get("chart_difficulty_tiers_allowed", [])
	for tier_id in _difficulty_tier_checks.keys():
		var icon: SessionToggleIcon = _difficulty_tier_checks[tier_id]
		if icon:
			icon.set_selected(tiers_allowed.has(tier_id))
	_sync_difficulty_section_visibility()


func _has_arcade_style() -> bool:
	var arcade: SessionToggleIcon = _style_checks.get("arcade", null)
	return arcade != null and arcade.button_pressed


func _sync_difficulty_section_visibility() -> void:
	set_difficulty_section_visible(_has_arcade_style())


func _emit_changed() -> void:
	settings_changed.emit(get_config_fragment())


func _on_style_check_toggled(_intent_id: String, _on: bool) -> void:
	var allowed: Array[String] = []
	for id in _style_checks.keys():
		var icon: SessionToggleIcon = _style_checks[id]
		if icon and icon.button_pressed:
			allowed.append(str(id))
	if allowed.is_empty():
		var fallback: SessionToggleIcon = _style_checks.get("original", null)
		if fallback:
			fallback.set_selected(true)
	_sync_difficulty_section_visibility()
	_emit_changed()


func _on_difficulty_tier_check_toggled(_tier_id: String, _on: bool) -> void:
	var allowed: Array[String] = []
	for id in _difficulty_tier_checks.keys():
		var icon: SessionToggleIcon = _difficulty_tier_checks[id]
		if icon and icon.button_pressed:
			allowed.append(str(id))
	if allowed.is_empty():
		var fallback: SessionToggleIcon = _difficulty_tier_checks.get(
			_EndlessSessionConfig.CHART_DIFFICULTY_TIER_MEDIUM, null
		)
		if fallback:
			fallback.set_selected(true)
	_emit_changed()


func _on_help_link_pressed() -> void:
	if _help_article_id == "":
		return
	var tree := get_tree()
	if tree == null:
		return
	var root := tree.root
	# Prefer Transitions via GameEngine if present.
	for child in root.get_children():
		if child.has_method("get_transitions"):
			var trans = child.get_transitions()
			if trans and trans.has_method("open_help_item"):
				trans.open_help_item(_help_article_id)
				return
		if child.has_method("open_help_item"):
			child.open_help_item(_help_article_id)
			return

