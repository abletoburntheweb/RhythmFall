# scenes/song_select/run_modifiers/modifier_preset_slot_row.gd
extends PanelContainer

signal slot_pressed(slot: int)
signal slot_preview_requested(slot: int)
signal slot_double_clicked(slot: int)

const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const _UserPresets = preload("res://logic/domain/modifiers/user_presets.gd")
const _IconStrip = preload("res://logic/ui/modifier_icon_strip.gd")
const _GenPresetUi = preload("res://logic/ui/generation_preset_ui.gd")
const _NotesUtils = preload("res://logic/domain/rhythm/notes_utils.gd")

const _ACTIVE_ICON_FILE := "disc-3.svg"
const _FAVORITE_ICON_FILE := "star.svg"
const _ACTIVE_ICON_COLOR := Color(0.45, 0.78, 0.98, 1.0)
const _FAVORITE_ICON_COLOR := Color(0.95, 0.78, 0.38, 1.0)
const _BADGE_ICON_SIZE := 16
const _MULT_COLOR_DEFAULT := Color(0.42, 0.92, 0.78, 1.0)
const _CHART_READY_COLOR := Color(0.42, 0.92, 0.78, 1.0)
const _CHART_MISSING_COLOR := Color(0.96, 0.74, 0.36, 1.0)

var slot_index: int = 0

@onready var _index_label: Label = $RowMargin/RowHBox/IndexLabel
@onready var _badge_row: HBoxContainer = $RowMargin/RowHBox/BadgeHBox
@onready var _active_icon: TextureRect = $RowMargin/RowHBox/BadgeHBox/ActiveIcon
@onready var _favorite_icon: TextureRect = $RowMargin/RowHBox/BadgeHBox/FavoriteIcon
@onready var _name_label: Label = $RowMargin/RowHBox/NameLabel
@onready var _icons_row: HBoxContainer = $RowMargin/RowHBox/IconsRow
@onready var _mult_label: Label = $RowMargin/RowHBox/MultLabel

var _row_is_active := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	gui_input.connect(_on_gui_input)
	_set_ignore_mouse_deep(self)
	_setup_badge_icons()
	# Tooltip-bearing badges need PASS (not IGNORE) to actually show their tooltip on
	# hover, while still letting the click bubble up to the row's own gui_input.
	for control in [_active_icon, _favorite_icon, _mult_label]:
		if control:
			control.mouse_filter = Control.MOUSE_FILTER_PASS


func _setup_badge_icons() -> void:
	if _active_icon:
		_active_icon.texture = UiIconHelper.load_tinted_icon(
			_ACTIVE_ICON_FILE, _ACTIVE_ICON_COLOR, UiIconHelper.raster_size_for_display(_BADGE_ICON_SIZE)
		)
		_active_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_active_icon.tooltip_text = tr("MOD_PRESET_ACTIVE_BADGE_TIP")
	if _favorite_icon:
		_favorite_icon.texture = UiIconHelper.load_tinted_icon(
			_FAVORITE_ICON_FILE, _FAVORITE_ICON_COLOR, UiIconHelper.raster_size_for_display(_BADGE_ICON_SIZE)
		)
		_favorite_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_favorite_icon.tooltip_text = tr("MOD_PRESET_FAVORITE_BADGE_TIP")


func _set_ignore_mouse_deep(node: Node) -> void:
	if node is Control and node != self:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_ignore_mouse_deep(child)


func setup(
	slot: int,
	presets: Dictionary,
	selected: bool,
	domain: String = _UserPresets.DOMAIN_MODIFIER,
	is_active: bool = false,
	song_path: String = "",
	instrument: String = "drums",
) -> void:
	slot_index = slot
	if _index_label:
		_index_label.text = "%02d" % slot
	var filled := _is_slot_filled(presets, slot, domain)
	var display := _display_name(presets, slot, domain)
	_row_is_active = is_active
	_set_name_text(display)
	_apply_badges(presets, slot, domain, filled)
	if _icons_row:
		if domain == _UserPresets.DOMAIN_GENERATION:
			if filled:
				var gen_entry := _UserPresets.get_generation_slot(presets, slot)
				_GenPresetUi.fill_slot_chips(_icons_row, gen_entry)
			else:
				_IconStrip.fill_slot_chips(_icons_row, [], {})
		elif filled:
			var entry := _UserPresets.get_slot(presets, slot)
			_IconStrip.fill_row_chips(
				_icons_row,
				entry.get("modifiers", []),
				entry.get("params", {}),
			)
		else:
			_IconStrip.fill_slot_chips(_icons_row, [], {})
	if _mult_label:
		if domain == _UserPresets.DOMAIN_GENERATION:
			if filled and song_path.strip_edges() != "":
				var has_chart := _NotesUtils.preset_chart_exists(song_path, instrument, slot)
				_mult_label.text = "✓" if has_chart else "⚠"
				_mult_label.tooltip_text = (
					tr("GEN_PRESET_CHART_READY_TIP") if has_chart else tr("GEN_PRESET_CHART_MISSING_TIP")
				)
				_mult_label.add_theme_color_override(
					"font_color", _CHART_READY_COLOR if has_chart else _CHART_MISSING_COLOR
				)
			else:
				_mult_label.text = ""
				_mult_label.tooltip_text = ""
				_mult_label.add_theme_color_override("font_color", _MULT_COLOR_DEFAULT)
		elif filled:
			var entry := _UserPresets.get_slot(presets, slot)
			_mult_label.text = _RunModifiers.format_preset_multiplier_label(
				entry.get("modifiers", []), entry.get("params", {})
			)
			_mult_label.tooltip_text = ""
			_mult_label.add_theme_color_override("font_color", _MULT_COLOR_DEFAULT)
		else:
			_mult_label.text = ""
			_mult_label.tooltip_text = ""
			_mult_label.add_theme_color_override("font_color", _MULT_COLOR_DEFAULT)
	_apply_selected(selected, filled)


func _apply_badges(presets: Dictionary, slot: int, domain: String, filled: bool) -> void:
	var is_favorite := false
	if filled:
		if domain == _UserPresets.DOMAIN_GENERATION:
			is_favorite = bool(_UserPresets.get_generation_slot(presets, slot).get("favorite", false))
		else:
			is_favorite = bool(_UserPresets.get_slot(presets, slot).get("favorite", false))
	if _badge_row:
		_badge_row.visible = _row_is_active or is_favorite
	if _active_icon:
		_active_icon.visible = _row_is_active
	if _favorite_icon:
		_favorite_icon.visible = is_favorite


func _is_slot_filled(presets: Dictionary, slot: int, domain: String) -> bool:
	if domain == _UserPresets.DOMAIN_GENERATION:
		return _UserPresets.is_generation_slot_filled(presets, slot)
	return _UserPresets.is_slot_filled(presets, slot)


func _display_name(presets: Dictionary, slot: int, domain: String) -> String:
	if domain == _UserPresets.DOMAIN_GENERATION:
		return _UserPresets.generation_display_name(presets, slot)
	return _UserPresets.display_name(presets, slot)


func set_name_text(text: String) -> void:
	_set_name_text(text)


func _set_name_text(text: String) -> void:
	if _name_label:
		_name_label.text = text
		_name_label.tooltip_text = text


func _apply_selected(selected: bool, filled: bool) -> void:
	var box := StyleBoxFlat.new()
	if selected:
		box.bg_color = Color(0.12, 0.17, 0.24, 0.96)
		box.border_color = Color(0.45, 0.78, 0.98, 0.45)
	elif _row_is_active:
		box.bg_color = Color(0.09, 0.12, 0.18, 0.82)
		box.border_color = Color(0.45, 0.78, 0.98, 0.22)
	else:
		box.bg_color = Color(0.07, 0.08, 0.12, 0.72)
		box.border_color = Color(1, 1, 1, 0.05)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.content_margin_left = 12.0
	box.content_margin_top = 12.0
	box.content_margin_right = 12.0
	box.content_margin_bottom = 12.0
	add_theme_stylebox_override("panel", box)
	if _name_label:
		_name_label.add_theme_color_override(
			"font_color",
			Color(0.9, 0.95, 1.0, 1.0) if filled else Color(0.5, 0.56, 0.66, 0.82)
		)
	if _index_label:
		_index_label.add_theme_color_override(
			"font_color",
			Color(0.55, 0.72, 0.88, 1.0) if selected or _row_is_active else Color(0.42, 0.5, 0.62, 0.9)
		)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			slot_preview_requested.emit(slot_index)
			accept_event()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.double_click:
			slot_double_clicked.emit(slot_index)
		else:
			slot_pressed.emit(slot_index)
		accept_event()
