# scenes/marathon/marathon_course_settings.gd
extends VBoxContainer
class_name MarathonCourseSettings

signal config_changed(config: Dictionary)

const _EndlessSessionConfig = preload("res://logic/domain/session/endless_session_config.gd")
const _MarathonSessionConfig = preload("res://logic/domain/session/marathon_session_config.gd")
const _SongSelectUiStyles = preload("res://scenes/song_select/lib/song_select_ui_styles.gd")
const _ModPoolIconScript = preload("res://scenes/song_select/endless/session_mod_pool_icon.gd")
const _InstrumentIconScript = preload("res://scenes/song_select/endless/session_instrument_icon.gd")
const _ToggleIconScript = preload("res://scenes/song_select/endless/session_toggle_icon.gd")
const _ChartStyleSettings = preload("res://scenes/song_select/lib/chart_style_settings.gd")
const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const _GenPresetUi = preload("res://logic/ui/generation_preset_ui.gd")
const _ChartDifficultyAnalyzer = preload("res://logic/domain/charts/chart_difficulty_analyzer.gd")
const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")

const _SETUP_BTN_HEIGHT := 46
const _SETUP_BTN_FONT := 16
## Reserved height for mod pool / count / hint so toggling Random mods doesn't reflow the card.
const _MOD_DETAILS_MIN_HEIGHT := 196

var _config: Dictionary = {}
var _accent := Color(0.79, 0.57, 0.35, 1.0)
var _chart_style_settings: ChartStyleSettings = null
var _mod_policy_group: ButtonGroup = null
var _mod_count_group: ButtonGroup = null
var _track_order_group: ButtonGroup = null
var _lanes_group: ButtonGroup = null
var _mod_policy_buttons: Dictionary = {}
var _mod_count_buttons: Dictionary = {}
var _track_order_buttons: Dictionary = {}
var _lanes_buttons: Dictionary = {}
var _mod_pool_cards: Dictionary = {}
var _mod_pool_panel: PanelContainer = null
var _mod_pool_count_label: Label = null
var _mod_count_row: HBoxContainer = null
var _mod_count_caption: Label = null
var _mod_reward_hint: Label = null
var _mod_details_slot: VBoxContainer = null
var _mod_details_placeholder: Label = null
var _mod_locked_hint: Label = null
var _chart_difficulty_caption: Label = null
var _chart_difficulty_row: HBoxContainer = null
var _chart_style_locked_hint: Label = null
var _chart_style_locked_icons_row: HBoxContainer = null
var _chart_style_hint: Label = null
var _track_order_locked_hint: Label = null
var _lanes_locked_hint: Label = null
var _mod_locked_icons_row: HBoxContainer = null
var _instrument_caption: Label = null
var _instrument_icons_row: HBoxContainer = null
var _resolved_instrument: String = _EndlessSessionConfig.DEFAULT_INSTRUMENT
var _title_label: Label = null
var _editable_hint: Label = null
var _route_template: Dictionary = {}
var _route_preview: Dictionary = {}
var _body_hbox: HBoxContainer = null
var _settings_col: VBoxContainer = null
var _tracks_caption: Label = null
var _tracks_list: VBoxContainer = null
var _tracks_scroll: ScrollContainer = null
var _tracks_empty_label: Label = null
var _mods_section_nodes: Array[Control] = []
var _track_order_section_nodes: Array[Control] = []
var _lanes_section_nodes: Array[Control] = []


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	_build_ui()
	_ensure_body_layout()
	set_config(_MarathonSessionConfig.default_config())
	call_deferred("_sync_button_styles")


func set_accent_color(color: Color) -> void:
	_accent = color
	_sync_button_styles()


func set_config(config: Dictionary) -> void:
	_config = _MarathonSessionConfig.sanitize(config)
	if not _route_template.is_empty():
		_config = _MarathonSessionConfig.resolve_effective_run_config(_config, _route_template)
	_sync_from_config()


func set_route_template(template: Dictionary) -> void:
	_route_template = template if template is Dictionary else {}
	if not _config.is_empty():
		_config = _MarathonSessionConfig.resolve_effective_run_config(_config, _route_template)
	_sync_from_config()


func set_resolved_instrument(instrument: String) -> void:
	var inst := str(instrument).strip_edges()
	if not _EndlessSessionConfig.is_valid_instrument(inst):
		inst = _EndlessSessionConfig.DEFAULT_INSTRUMENT
	_resolved_instrument = inst
	_config["instrument"] = inst
	_config["instruments"] = [inst]
	_config["instrument_locked"] = true
	_sync_instrument_icon()


func set_route_preview(preview: Dictionary) -> void:
	_route_preview = preview if preview is Dictionary else {}
	_sync_route_tracks_panel()


func get_config() -> Dictionary:
	return _config.duplicate(true)


func apply_locale() -> void:
	if _title_label:
		_title_label.text = tr("MARATHON_CATALOG_SETTINGS_TITLE")
	if _editable_hint:
		_editable_hint.text = tr("MARATHON_CATALOG_EDITABLE_HINT")
	if _chart_style_hint:
		_chart_style_hint.text = tr("MARATHON_CATALOG_CHART_STYLE_HINT")
	if _mod_details_placeholder:
		_mod_details_placeholder.text = tr("MARATHON_CATALOG_MOD_DETAILS_PLACEHOLDER")
	if _instrument_caption:
		_instrument_caption.text = tr("MARATHON_CATALOG_INSTRUMENT_CAPTION")
	if _chart_difficulty_caption:
		_chart_difficulty_caption.text = tr("MARATHON_CATALOG_DIFFICULTY_CAPTION")
	if _tracks_caption:
		_tracks_caption.text = tr("MARATHON_CATALOG_ROUTE_TRACKS_CAPTION")
	if _tracks_empty_label:
		_tracks_empty_label.text = tr("MARATHON_CATALOG_ROUTE_TRACKS_EMPTY")
	if _chart_style_settings:
		_chart_style_settings.apply_locale()
	for policy_id in _mod_policy_buttons.keys():
		var btn: Button = _mod_policy_buttons[policy_id]
		if btn:
			btn.text = tr(_EndlessSessionConfig.mod_policy_label_key(policy_id))
	for order_id in _track_order_buttons.keys():
		var btn: Button = _track_order_buttons[order_id]
		if btn:
			btn.text = tr(_track_order_label_key(order_id))
	for lane_count in _lanes_buttons.keys():
		var btn: Button = _lanes_buttons[lane_count]
		if btn:
			btn.text = tr("MARATHON_CATALOG_LANES_FMT") % lane_count
	for icon in _mod_pool_cards.values():
		if icon and icon.has_method("refresh_locale"):
			icon.refresh_locale()
	if _mod_reward_hint:
		_mod_reward_hint.text = tr("MARATHON_CATALOG_MOD_REWARD_HINT")
	_sync_locked_hint_texts()
	_sync_from_config()


func set_interactive(enabled: bool) -> void:
	for btn in _mod_policy_buttons.values():
		if btn:
			btn.disabled = not enabled
	for btn in _mod_count_buttons.values():
		if btn:
			btn.disabled = not enabled
	for btn in _track_order_buttons.values():
		if btn:
			btn.disabled = not enabled
	for btn in _lanes_buttons.values():
		if btn:
			btn.disabled = not enabled
	for icon in _mod_pool_cards.values():
		if icon:
			icon.disabled = not enabled
	if _chart_style_settings and _chart_style_settings.has_method("set_interactive"):
		_chart_style_settings.set_interactive(enabled)


func _sync_locked_hint_texts() -> void:
	if _chart_style_locked_hint and _chart_style_locked_hint.visible:
		_chart_style_locked_hint.text = tr("MARATHON_CATALOG_CHART_STYLE_LOCKED_HINT")
	if _track_order_locked_hint and _track_order_locked_hint.visible:
		_track_order_locked_hint.text = _track_order_locked_text()
	if _lanes_locked_hint and _lanes_locked_hint.visible:
		_lanes_locked_hint.text = _lanes_locked_text()
	if _mod_locked_hint and _mod_locked_hint.visible:
		_mod_locked_hint.text = _mod_locked_hint_text()
	_sync_difficulty_range_row()


func _build_ui() -> void:
	_title_label = Label.new()
	_title_label.text = tr("MARATHON_CATALOG_SETTINGS_TITLE")
	_title_label.add_theme_font_size_override("font_size", 15)
	_title_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.98, 1.0))
	add_child(_title_label)

	_editable_hint = Label.new()
	_editable_hint.text = tr("MARATHON_CATALOG_EDITABLE_HINT")
	_editable_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_editable_hint.add_theme_font_size_override("font_size", 12)
	_editable_hint.add_theme_color_override("font_color", Color(0.62, 0.7, 0.82, 0.92))
	add_child(_editable_hint)

	_instrument_caption = _make_caption(tr("MARATHON_CATALOG_INSTRUMENT_CAPTION"))
	add_child(_instrument_caption)
	_instrument_icons_row = HBoxContainer.new()
	_instrument_icons_row.add_theme_constant_override("separation", 8)
	add_child(_instrument_icons_row)

	_chart_style_settings = _ChartStyleSettings.new()
	_chart_style_settings.settings_changed.connect(_on_chart_style_settings_changed)
	add_child(_chart_style_settings)

	_chart_style_hint = Label.new()
	_chart_style_hint.text = tr("MARATHON_CATALOG_CHART_STYLE_HINT")
	_chart_style_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chart_style_hint.add_theme_font_size_override("font_size", 12)
	_chart_style_hint.add_theme_color_override("font_color", Color(0.58, 0.66, 0.78, 0.95))
	add_child(_chart_style_hint)

	_chart_style_locked_hint = Label.new()
	_chart_style_locked_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chart_style_locked_hint.add_theme_font_size_override("font_size", 13)
	_chart_style_locked_hint.add_theme_color_override("font_color", Color(0.82, 0.68, 0.42, 0.95))
	_chart_style_locked_hint.visible = false
	add_child(_chart_style_locked_hint)

	_chart_style_locked_icons_row = HBoxContainer.new()
	_chart_style_locked_icons_row.add_theme_constant_override("separation", 8)
	_chart_style_locked_icons_row.visible = false
	add_child(_chart_style_locked_icons_row)

	_chart_difficulty_caption = _make_caption(tr("MARATHON_CATALOG_DIFFICULTY_CAPTION"))
	add_child(_chart_difficulty_caption)
	_chart_difficulty_row = HBoxContainer.new()
	_chart_difficulty_row.add_theme_constant_override("separation", 6)
	add_child(_chart_difficulty_row)

	var mods_caption := _make_caption(tr("MARATHON_CATALOG_SETTINGS_MODS"))
	add_child(mods_caption)
	_mods_section_nodes.append(mods_caption)
	_mod_policy_group = ButtonGroup.new()
	_mod_policy_group.allow_unpress = false
	var mod_row := HBoxContainer.new()
	mod_row.add_theme_constant_override("separation", 10)
	add_child(mod_row)
	_mods_section_nodes.append(mod_row)
	for policy_id in [
		_EndlessSessionConfig.MOD_POLICY_NONE,
		_EndlessSessionConfig.MOD_POLICY_RANDOM_POOL,
	]:
		var btn := _make_option_button(_EndlessSessionConfig.mod_policy_label_key(policy_id))
		btn.button_group = _mod_policy_group
		btn.toggled.connect(_on_mod_policy_toggled.bind(policy_id))
		mod_row.add_child(btn)
		_mod_policy_buttons[policy_id] = btn

	_mod_details_slot = VBoxContainer.new()
	_mod_details_slot.add_theme_constant_override("separation", 8)
	_mod_details_slot.custom_minimum_size = Vector2(0, _MOD_DETAILS_MIN_HEIGHT)
	_mod_details_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_mod_details_slot)
	_mods_section_nodes.append(_mod_details_slot)

	_mod_details_placeholder = Label.new()
	_mod_details_placeholder.text = tr("MARATHON_CATALOG_MOD_DETAILS_PLACEHOLDER")
	_mod_details_placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mod_details_placeholder.add_theme_font_size_override("font_size", 13)
	_mod_details_placeholder.add_theme_color_override("font_color", Color(0.58, 0.66, 0.78, 0.9))
	_mod_details_placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_mod_details_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mod_details_slot.add_child(_mod_details_placeholder)

	_mod_pool_panel = PanelContainer.new()
	_mod_pool_panel.add_theme_stylebox_override("panel", _SongSelectUiStyles.card_panel_style())
	var mod_pool_vbox := VBoxContainer.new()
	mod_pool_vbox.add_theme_constant_override("separation", 8)
	_mod_pool_panel.add_child(mod_pool_vbox)

	var mod_pool_header := HBoxContainer.new()
	mod_pool_header.add_theme_constant_override("separation", 10)
	mod_pool_vbox.add_child(mod_pool_header)

	var mod_pool_caption := Label.new()
	mod_pool_caption.text = tr("MARATHON_CATALOG_MOD_POOL_CAPTION")
	mod_pool_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mod_pool_caption.add_theme_font_size_override("font_size", 14)
	mod_pool_caption.add_theme_color_override("font_color", Color(0.62, 0.7, 0.82, 0.95))
	mod_pool_header.add_child(mod_pool_caption)

	_mod_pool_count_label = Label.new()
	_mod_pool_count_label.add_theme_font_size_override("font_size", 13)
	_mod_pool_count_label.add_theme_color_override("font_color", Color(0.72, 0.8, 0.92, 0.95))
	mod_pool_header.add_child(_mod_pool_count_label)

	var mod_pool_scroll := ScrollContainer.new()
	mod_pool_scroll.custom_minimum_size = Vector2(0, 96)
	mod_pool_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mod_pool_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mod_pool_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	mod_pool_vbox.add_child(mod_pool_scroll)

	var mod_pool_flow := FlowContainer.new()
	mod_pool_flow.add_theme_constant_override("h_separation", 8)
	mod_pool_flow.add_theme_constant_override("v_separation", 8)
	mod_pool_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mod_pool_scroll.add_child(mod_pool_flow)
	for mod_id in _MarathonSessionConfig.marathon_mod_pool_candidates():
		var icon := _ModPoolIconScript.new() as SessionModPoolIcon
		if icon == null:
			continue
		icon.setup(mod_id)
		icon.pool_toggled.connect(_on_mod_pool_icon_toggled)
		mod_pool_flow.add_child(icon)
		_mod_pool_cards[mod_id] = icon

	_mod_details_slot.add_child(_mod_pool_panel)

	_mod_count_caption = _make_caption(tr("MARATHON_CATALOG_MOD_COUNT_CAPTION"))
	_mod_details_slot.add_child(_mod_count_caption)
	_mod_count_group = ButtonGroup.new()
	_mod_count_group.allow_unpress = false
	_mod_count_row = HBoxContainer.new()
	_mod_count_row.add_theme_constant_override("separation", 10)
	_mod_details_slot.add_child(_mod_count_row)
	for count in range(
		_EndlessSessionConfig.MOD_RANDOM_COUNT_MIN,
		_EndlessSessionConfig.MOD_RANDOM_COUNT_MAX + 1
	):
		var btn := _make_option_button("MARATHON_CATALOG_MOD_COUNT_FMT")
		btn.text = tr("MARATHON_CATALOG_MOD_COUNT_FMT") % count
		btn.button_group = _mod_count_group
		btn.toggled.connect(_on_mod_count_toggled.bind(count))
		_mod_count_row.add_child(btn)
		_mod_count_buttons[count] = btn

	_mod_reward_hint = Label.new()
	_mod_reward_hint.text = tr("MARATHON_CATALOG_MOD_REWARD_HINT")
	_mod_reward_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mod_reward_hint.add_theme_font_size_override("font_size", 13)
	_mod_reward_hint.add_theme_color_override("font_color", Color(0.68, 0.76, 0.88, 0.92))
	_mod_details_slot.add_child(_mod_reward_hint)

	_mod_locked_hint = Label.new()
	_mod_locked_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mod_locked_hint.add_theme_font_size_override("font_size", 13)
	_mod_locked_hint.add_theme_color_override("font_color", Color(0.82, 0.68, 0.42, 0.95))
	_mod_locked_hint.visible = false
	add_child(_mod_locked_hint)

	_mod_locked_icons_row = HBoxContainer.new()
	_mod_locked_icons_row.add_theme_constant_override("separation", 8)
	_mod_locked_icons_row.visible = false
	add_child(_mod_locked_icons_row)

	var track_order_caption := _make_caption(tr("MARATHON_CATALOG_SETTINGS_TRACK_ORDER"))
	add_child(track_order_caption)
	_track_order_section_nodes.append(track_order_caption)
	_track_order_group = ButtonGroup.new()
	_track_order_group.allow_unpress = false
	var order_row := HBoxContainer.new()
	order_row.add_theme_constant_override("separation", 10)
	add_child(order_row)
	_track_order_section_nodes.append(order_row)
	for order_id in [
		_MarathonSessionConfig.TRACK_ORDER_COURSE,
		_MarathonSessionConfig.TRACK_ORDER_RANDOM,
	]:
		var btn := _make_option_button(_track_order_label_key(order_id))
		btn.button_group = _track_order_group
		btn.toggled.connect(_on_track_order_toggled.bind(order_id))
		order_row.add_child(btn)
		_track_order_buttons[order_id] = btn

	_track_order_locked_hint = Label.new()
	_track_order_locked_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_track_order_locked_hint.add_theme_font_size_override("font_size", 13)
	_track_order_locked_hint.add_theme_color_override("font_color", Color(0.82, 0.68, 0.42, 0.95))
	_track_order_locked_hint.visible = false
	add_child(_track_order_locked_hint)

	var lanes_caption := _make_caption(tr("MARATHON_CATALOG_SETTINGS_LANES"))
	add_child(lanes_caption)
	_lanes_section_nodes.append(lanes_caption)
	_lanes_group = ButtonGroup.new()
	_lanes_group.allow_unpress = false
	var lanes_row := HBoxContainer.new()
	lanes_row.add_theme_constant_override("separation", 10)
	add_child(lanes_row)
	_lanes_section_nodes.append(lanes_row)
	for lane_count in [3, 4, 5]:
		var btn := _make_option_button("MARATHON_CATALOG_LANES_FMT")
		btn.text = tr("MARATHON_CATALOG_LANES_FMT") % lane_count
		btn.button_group = _lanes_group
		btn.toggled.connect(_on_lanes_toggled.bind(lane_count))
		lanes_row.add_child(btn)
		_lanes_buttons[lane_count] = btn

	_lanes_locked_hint = Label.new()
	_lanes_locked_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lanes_locked_hint.add_theme_font_size_override("font_size", 13)
	_lanes_locked_hint.add_theme_color_override("font_color", Color(0.82, 0.68, 0.42, 0.95))
	_lanes_locked_hint.visible = false
	add_child(_lanes_locked_hint)


func _make_caption(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.62, 0.7, 0.82, 0.95))
	return lbl


func _make_option_button(label_key: String) -> Button:
	var btn := Button.new()
	btn.toggle_mode = true
	btn.text = tr(label_key)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.theme_type_variation = &"FlatButton"
	_SongSelectUiStyles.style_setup_button(btn, _SETUP_BTN_HEIGHT, _SETUP_BTN_FONT)
	return btn


func _track_order_label_key(order_id: String) -> String:
	match order_id:
		_MarathonSessionConfig.TRACK_ORDER_RANDOM:
			return "MARATHON_CATALOG_TRACK_ORDER_RANDOM"
	return "MARATHON_CATALOG_TRACK_ORDER_COURSE"


func _sync_button_styles() -> void:
	if _chart_style_settings:
		_chart_style_settings.set_accent_color(_accent)
	for btn in _mod_policy_buttons.values():
		_apply_option_style(btn as Button)
	for btn in _mod_count_buttons.values():
		_apply_option_style(btn as Button)
	for btn in _track_order_buttons.values():
		_apply_option_style(btn as Button)
	for btn in _lanes_buttons.values():
		_apply_option_style(btn as Button)


func _apply_option_style(btn: Button) -> void:
	if btn == null:
		return
	_SongSelectUiStyles.apply_option_button_style(btn, btn.button_pressed, _accent)


func _sync_from_config() -> void:
	if _chart_style_settings:
		_chart_style_settings.set_config(_config)
		_chart_style_settings.set_difficulty_section_visible(false)

	var has_route := not _route_template.is_empty()
	if _chart_difficulty_caption:
		_chart_difficulty_caption.visible = has_route
	if _chart_difficulty_row:
		_chart_difficulty_row.visible = has_route
	_sync_difficulty_range_row()

	var mods_locked := _MarathonSessionConfig.is_mod_policy_locked(_route_template)
	for node in _mods_section_nodes:
		if node:
			node.visible = not mods_locked
	if _mod_locked_hint:
		_mod_locked_hint.visible = mods_locked
		if mods_locked:
			_mod_locked_hint.text = _mod_locked_hint_text()
	_sync_mod_locked_icons(mods_locked)

	var chart_locked := _MarathonSessionConfig.is_setup_field_locked(_route_template, "chart_style")
	if _chart_style_settings:
		_chart_style_settings.visible = not chart_locked
	if _chart_style_hint:
		_chart_style_hint.visible = not chart_locked
	if _chart_style_locked_hint:
		_chart_style_locked_hint.visible = chart_locked
		if chart_locked:
			_chart_style_locked_hint.text = tr("MARATHON_CATALOG_CHART_STYLE_LOCKED_HINT")
	_sync_chart_style_locked_icons(chart_locked)

	if _config.has("instrument"):
		_resolved_instrument = str(_config.get("instrument", _EndlessSessionConfig.DEFAULT_INSTRUMENT))
	_sync_instrument_icon()
	_sync_route_tracks_panel()

	var track_locked := _MarathonSessionConfig.is_setup_field_locked(_route_template, "track_order")
	for node in _track_order_section_nodes:
		if node:
			node.visible = not track_locked
	if _track_order_locked_hint:
		_track_order_locked_hint.visible = track_locked

	var lanes_locked := _MarathonSessionConfig.is_setup_field_locked(_route_template, "lanes")
	for node in _lanes_section_nodes:
		if node:
			node.visible = not lanes_locked
	if _lanes_locked_hint:
		_lanes_locked_hint.visible = lanes_locked

	_sync_locked_hint_texts()

	var mod_policy := str(_config.get("mod_policy", _EndlessSessionConfig.MOD_POLICY_NONE))
	for policy_id in _mod_policy_buttons.keys():
		var btn: Button = _mod_policy_buttons[policy_id]
		if btn:
			btn.set_pressed_no_signal(policy_id == mod_policy)

	var pool_visible := mod_policy == _EndlessSessionConfig.MOD_POLICY_RANDOM_POOL
	if _mod_details_placeholder:
		_mod_details_placeholder.visible = not pool_visible
	if _mod_pool_panel:
		_mod_pool_panel.visible = pool_visible
	if _mod_count_row:
		_mod_count_row.visible = pool_visible
	if _mod_count_caption:
		_mod_count_caption.visible = pool_visible
	if _mod_reward_hint:
		_mod_reward_hint.visible = pool_visible
	_sync_mod_pool_selection()
	_sync_mod_pool_count_label()

	var mod_count := int(_config.get("mod_random_count", _EndlessSessionConfig.DEFAULT_MOD_RANDOM_COUNT))
	for count in _mod_count_buttons.keys():
		var count_btn: Button = _mod_count_buttons[count]
		if count_btn:
			count_btn.set_pressed_no_signal(int(count) == mod_count)

	var track_order := str(_config.get("track_order", _MarathonSessionConfig.TRACK_ORDER_COURSE))
	for order_id in _track_order_buttons.keys():
		var btn: Button = _track_order_buttons[order_id]
		if btn:
			btn.set_pressed_no_signal(order_id == track_order)

	var lanes := int(_config.get("lanes", 4))
	for lane_count in _lanes_buttons.keys():
		var btn: Button = _lanes_buttons[lane_count]
		if btn:
			btn.set_pressed_no_signal(lane_count == lanes)
	_sync_button_styles()


func _sync_mod_pool_selection() -> void:
	var pool_set: Dictionary = {}
	for mod_id in _config.get("mod_pool", []):
		pool_set[str(mod_id)] = true
	for mod_id in _mod_pool_cards.keys():
		var icon: SessionModPoolIcon = _mod_pool_cards[mod_id]
		if icon:
			icon.set_pool_selected(pool_set.has(str(mod_id)))


func _sync_mod_pool_count_label() -> void:
	if _mod_pool_count_label == null:
		return
	var pool: Array = _config.get("mod_pool", [])
	var total := _MarathonSessionConfig.marathon_mod_pool_candidates().size()
	var min_need := _MarathonSessionConfig.MOD_POOL_MIN_COUNT
	_mod_pool_count_label.text = tr("MARATHON_CATALOG_MOD_POOL_COUNT_FMT") % [pool.size(), total, min_need]


func _mod_pool_min_size() -> int:
	return _MarathonSessionConfig.MOD_POOL_MIN_COUNT


func _emit_config() -> void:
	_config = _MarathonSessionConfig.sanitize(_config)
	var out := _config
	if not _route_template.is_empty():
		out = _MarathonSessionConfig.resolve_effective_run_config(_config, _route_template)
	config_changed.emit(out)


func _on_chart_style_settings_changed(fragment: Dictionary) -> void:
	for key in fragment.keys():
		_config[key] = fragment[key]
	_emit_config()


func _on_mod_policy_toggled(on: bool, policy_id: String) -> void:
	if not on:
		return
	_config["mod_policy"] = policy_id
	if policy_id == _EndlessSessionConfig.MOD_POLICY_RANDOM_POOL:
		var pool: Variant = _config.get("mod_pool", [])
		if pool is Array and (pool as Array).is_empty():
			_config["mod_pool"] = _MarathonSessionConfig.default_mod_pool()
	_sync_from_config()
	_emit_config()


func _on_mod_count_toggled(on: bool, count: int) -> void:
	if not on:
		return
	_config["mod_random_count"] = count
	_sync_button_styles()
	_emit_config()


func _on_mod_pool_icon_toggled(modifier_id: String, pressed: bool) -> void:
	var pool: Array = (_config.get("mod_pool", []) as Array).duplicate()
	var sid := str(modifier_id)
	if pressed:
		if not pool.has(sid):
			pool.append(sid)
	else:
		if pool.size() <= _mod_pool_min_size():
			_sync_mod_pool_selection()
			return
		pool.erase(sid)
	_config["mod_pool"] = pool
	_sync_mod_pool_selection()
	_sync_mod_pool_count_label()
	_emit_config()


func _on_track_order_toggled(on: bool, order_id: String) -> void:
	if not on:
		return
	_config["track_order"] = order_id
	_sync_button_styles()
	_emit_config()


func _on_lanes_toggled(on: bool, lane_count: int) -> void:
	if not on:
		return
	_config["lanes"] = lane_count
	_sync_button_styles()
	_emit_config()


func _on_locked_mod_icon_pressed(icon: SessionModPoolIcon) -> void:
	if icon:
		icon.set_pool_selected(true)


func _mod_locked_hint_text() -> String:
	var cfg := _MarathonSessionConfig.resolve_effective_run_config(_config, _route_template)
	var policy := str(cfg.get("mod_policy", _EndlessSessionConfig.MOD_POLICY_NONE))
	if policy == _EndlessSessionConfig.MOD_POLICY_NONE:
		return tr("MARATHON_CATALOG_MOD_LOCKED_NONE")
	if policy == _EndlessSessionConfig.MOD_POLICY_RANDOM_POOL:
		var count := int(cfg.get("mod_random_count", _EndlessSessionConfig.DEFAULT_MOD_RANDOM_COUNT))
		return tr("MARATHON_CATALOG_MOD_LOCKED_RANDOM_FMT") % count
	var fixed: Array = cfg.get("mod_pool", [])
	if fixed.is_empty():
		return tr("MARATHON_CATALOG_MOD_LOCKED_HINT")
	return tr("MARATHON_CATALOG_MOD_LOCKED_HINT")


func _sync_mod_locked_icons(mods_locked: bool) -> void:
	if _mod_locked_icons_row == null:
		return
	for child in _mod_locked_icons_row.get_children():
		child.queue_free()
	_mod_locked_icons_row.visible = mods_locked
	if not mods_locked:
		return
	var fixed: Array = _MarathonSessionConfig.resolve_effective_run_config(_config, _route_template).get("mod_pool", [])
	for mod_id in fixed:
		var sid := str(mod_id).strip_edges()
		if sid == "":
			continue
		var icon := _ModPoolIconScript.new() as SessionModPoolIcon
		if icon == null:
			continue
		icon.setup(sid)
		icon.set_pool_selected(true)
		icon.disabled = false
		icon.focus_mode = Control.FOCUS_NONE
		if not icon.pressed.is_connected(_on_locked_mod_icon_pressed):
			icon.pressed.connect(_on_locked_mod_icon_pressed.bind(icon))
		var title := tr(_RunModifiers.title_i18n_key(sid))
		var desc := _RunModifiers.format_modifier_description(sid, {}).strip_edges()
		if desc != "":
			icon.tooltip_text = "%s\n%s" % [title, desc]
		else:
			icon.tooltip_text = title
		_mod_locked_icons_row.add_child(icon)


func _sync_instrument_icon() -> void:
	if _instrument_icons_row == null:
		return
	for child in _instrument_icons_row.get_children():
		child.queue_free()
	var inst := _resolved_instrument
	if not _EndlessSessionConfig.is_valid_instrument(inst):
		inst = _EndlessSessionConfig.DEFAULT_INSTRUMENT
	var icon := _InstrumentIconScript.new() as SessionInstrumentIcon
	if icon == null:
		return
	icon.setup(inst, false)
	icon.set_pool_selected(true)
	icon.focus_mode = Control.FOCUS_NONE
	if not icon.pressed.is_connected(_on_locked_instrument_icon_pressed):
		icon.pressed.connect(_on_locked_instrument_icon_pressed.bind(icon))
	_instrument_icons_row.add_child(icon)


func _on_locked_instrument_icon_pressed(icon: SessionInstrumentIcon) -> void:
	if icon:
		icon.set_pool_selected(true)


func _sync_chart_style_locked_icons(chart_locked: bool) -> void:
	if _chart_style_locked_icons_row == null:
		return
	for child in _chart_style_locked_icons_row.get_children():
		child.queue_free()
	_chart_style_locked_icons_row.visible = chart_locked
	if not chart_locked:
		return
	var cfg := _MarathonSessionConfig.resolve_effective_run_config(_config, _route_template)
	var policy := str(cfg.get("generation_mode_policy", _EndlessSessionConfig.GEN_MODE_POLICY_ALL))
	var modes: Array = []
	if policy == _EndlessSessionConfig.GEN_MODE_POLICY_ALL:
		modes = _EndlessSessionConfig.UI_CHART_STYLE_INTENTS.duplicate()
	else:
		modes = cfg.get("generation_modes_allowed", [])
	for mode_id in modes:
		var sid := str(mode_id).strip_edges()
		if sid == "":
			continue
		var icon_file := str(_GenPresetUi.INTENT_ICONS.get(sid, "audio-lines.svg"))
		var tint: Color = _GenPresetUi.INTENT_ICON_COLORS.get(sid, _accent) as Color
		var icon := _ToggleIconScript.new() as SessionToggleIcon
		if icon == null:
			continue
		icon.setup(sid, icon_file, tint, _GenPresetUi.localized_intent(sid))
		icon.set_selected(true)
		icon.focus_mode = Control.FOCUS_NONE
		if not icon.pressed.is_connected(_on_locked_style_icon_pressed):
			icon.pressed.connect(_on_locked_style_icon_pressed.bind(icon))
		_chart_style_locked_icons_row.add_child(icon)


func _on_locked_style_icon_pressed(icon: SessionToggleIcon) -> void:
	if icon:
		icon.set_selected(true)


func _ensure_body_layout() -> void:
	if _body_hbox != null:
		return
	_body_hbox = HBoxContainer.new()
	_body_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_hbox.add_theme_constant_override("separation", 12)

	_settings_col = VBoxContainer.new()
	_settings_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_col.size_flags_stretch_ratio = 0.78
	_settings_col.add_theme_constant_override("separation", 10)
	_body_hbox.add_child(_settings_col)

	var tracks_col := VBoxContainer.new()
	tracks_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tracks_col.size_flags_stretch_ratio = 1.22
	tracks_col.add_theme_constant_override("separation", 6)
	_body_hbox.add_child(tracks_col)

	_tracks_caption = _make_caption(tr("MARATHON_CATALOG_ROUTE_TRACKS_CAPTION"))
	tracks_col.add_child(_tracks_caption)

	_tracks_scroll = ScrollContainer.new()
	_tracks_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tracks_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tracks_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	tracks_col.add_child(_tracks_scroll)

	_tracks_list = VBoxContainer.new()
	_tracks_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tracks_list.add_theme_constant_override("separation", 4)
	_tracks_scroll.add_child(_tracks_list)

	_tracks_empty_label = Label.new()
	_tracks_empty_label.text = tr("MARATHON_CATALOG_ROUTE_TRACKS_EMPTY")
	_tracks_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tracks_empty_label.add_theme_font_size_override("font_size", 13)
	_tracks_empty_label.add_theme_color_override("font_color", Color(0.62, 0.7, 0.82, 0.85))
	tracks_col.add_child(_tracks_empty_label)

	var to_move: Array[Node] = []
	for child in get_children():
		if child == _title_label or child == _editable_hint:
			continue
		to_move.append(child)
	for child in to_move:
		remove_child(child)
		_settings_col.add_child(child)
	add_child(_body_hbox)
	var header_anchor: Node = _editable_hint if _editable_hint else _title_label
	if header_anchor:
		move_child(_body_hbox, header_anchor.get_index() + 1)
	_sync_route_tracks_panel()


func _sync_difficulty_range_row() -> void:
	if _chart_difficulty_row == null:
		return
	for child in _chart_difficulty_row.get_children():
		child.queue_free()
	if _route_template.is_empty():
		return
	var dmin := float(_route_template.get("difficulty_min", 2.0))
	var dmax := float(_route_template.get("difficulty_max", 7.0))
	_chart_difficulty_row.add_child(_make_difficulty_value_chip(dmin))
	var arrow := _UiIconHelper.make_texture_rect(
		_UiIconHelper.load_tinted_icon("chevron-right.svg", Color(0.78, 0.82, 0.9, 0.95), 64),
		14
	)
	_chart_difficulty_row.add_child(arrow)
	_chart_difficulty_row.add_child(_make_difficulty_value_chip(dmax))
	_chart_difficulty_row.tooltip_text = tr("MARATHON_CATALOG_DIFFICULTY_LOCKED_FMT") % [dmin, dmax]


func _make_difficulty_value_chip(rating: float, compact: bool = false) -> PanelContainer:
	var color := _ChartDifficultyAnalyzer.rating_color_for_decimal(rating)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.08, 0.11, 0.94)
	box.border_color = Color(color.r, color.g, color.b, 0.45)
	box.set_border_width_all(1)
	box.set_corner_radius_all(8 if compact else 10)
	var pad_h := 8.0 if compact else 10.0
	var pad_v := 4.0 if compact else 6.0
	box.content_margin_left = pad_h
	box.content_margin_right = pad_h + 2.0
	box.content_margin_top = pad_v
	box.content_margin_bottom = pad_v
	panel.add_theme_stylebox_override("panel", box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)

	var icon_px := 14 if compact else 18
	var icon := _UiIconHelper.make_texture_rect(
		_UiIconHelper.load_tinted_icon("zap.svg", color, _UiIconHelper.raster_size_for_display(icon_px)),
		icon_px
	)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var label := Label.new()
	label.text = _ChartDifficultyAnalyzer.format_decimal_rating(rating, false)
	label.add_theme_font_size_override("font_size", 13 if compact else 16)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	return panel


func _sync_route_tracks_panel() -> void:
	if _tracks_list == null:
		return
	for child in _tracks_list.get_children():
		child.queue_free()
	var show_panel := not _route_template.is_empty()
	var entries: Variant = _route_preview.get("entries", [])
	var has_entries := entries is Array and not (entries as Array).is_empty()
	if _tracks_caption:
		_tracks_caption.visible = show_panel
	if _tracks_scroll:
		_tracks_scroll.visible = show_panel and has_entries
	if _tracks_empty_label:
		_tracks_empty_label.visible = show_panel and not has_entries
	if not show_panel or not has_entries:
		return
	var idx := 1
	for raw in entries as Array:
		if raw is not Dictionary:
			continue
		_tracks_list.add_child(_make_route_track_row(raw as Dictionary, idx))
		idx += 1


func _make_route_track_row(entry: Dictionary, index: int) -> PanelContainer:
	var song_path := str(entry.get("song_path", "")).strip_edges()
	var rating := float(entry.get("decimal_rating", 0.0))
	var title := _song_title_for_path(song_path)
	var role := str(entry.get("slot_role", ""))
	if role == "finale":
		title = "%s · %s" % [title, tr("MARATHON_CATALOG_TRACK_FINALE")]

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.09, 0.13, 0.72)
	box.border_color = Color(1, 1, 1, 0.06)
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 4.0
	box.content_margin_bottom = 4.0
	panel.add_theme_stylebox_override("panel", box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var index_label := Label.new()
	index_label.text = "%d." % index
	index_label.custom_minimum_size = Vector2(20, 0)
	index_label.add_theme_font_size_override("font_size", 12)
	index_label.add_theme_color_override("font_color", Color(0.62, 0.7, 0.82, 0.9))
	row.add_child(index_label)

	var title_label := Label.new()
	title_label.text = title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_font_size_override("font_size", 12)
	title_label.add_theme_color_override("font_color", Color(0.86, 0.9, 0.96, 1.0))
	row.add_child(title_label)

	if rating > 0.0:
		row.add_child(_make_difficulty_value_chip(rating, true))
	return panel


func _song_title_for_path(song_path: String) -> String:
	var path := song_path.strip_edges()
	if path == "":
		return tr("MARATHON_CATALOG_TRACK_UNKNOWN")
	if SongLibrary:
		var meta: Dictionary = SongLibrary.get_metadata_for_song(path)
		var title := str(meta.get("title", "")).strip_edges()
		if title != "":
			return title
	return path.get_file().get_basename()


func _track_order_locked_text() -> String:
	var cfg := _MarathonSessionConfig.resolve_effective_run_config(_config, _route_template)
	var order := str(cfg.get("track_order", _MarathonSessionConfig.TRACK_ORDER_COURSE))
	return tr(_track_order_label_key(order))


func _lanes_locked_text() -> String:
	var cfg := _MarathonSessionConfig.resolve_effective_run_config(_config, _route_template)
	return tr("MARATHON_CATALOG_LANES_FMT") % int(cfg.get("lanes", 4))
