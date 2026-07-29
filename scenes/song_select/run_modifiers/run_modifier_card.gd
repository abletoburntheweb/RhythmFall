# scenes/song_select/run_modifiers/run_modifier_card.gd
extends Button

signal card_toggled(modifier_id: String, pressed: bool)
signal card_hovered(modifier_id: String)
signal card_unhovered(modifier_id: String)
signal card_info_requested(modifier_id: String)
signal card_dna_enable_blocked(modifier_id: String)

const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const _UiMotionEffects = preload("res://logic/ui/ui_motion_effects.gd")
const _DEFAULT_SIZE := Vector2(124, 124)
const _LARGE_SIZE := Vector2(140, 140)

var modifier_id: String = ""
var _abbr_key: String = ""
var _show_reward: bool = true
var _locked_disabled: bool = false
var _locked_tooltip: String = ""
var _dna_gated: bool = false
var _dna_gated_tooltip: String = ""
var _preview_focused: bool = false
var _info_locked: bool = false
var _conflict_active: bool = false
var _run_params: Dictionary = {}
var _selection_pulse_active: bool = false
var _empty_button_style: StyleBoxEmpty
var _symbol_texture_key: String = ""
var _gear_texture_key: String = ""

@onready var _icon_bg: TextureRect = $IconBg
@onready var _symbol_icon: TextureRect = $SymbolIcon
@onready var _gear_icon: TextureRect = $GearIcon
@onready var _abbr_shadow: Label = $AbbrShadow
@onready var _abbr_label: Label = $AbbrLabel
@onready var _reward_label: Label = $RewardLabel
@onready var _conflict_ring: Panel = $ConflictRing
@onready var _focus_ring: Panel = $FocusRing
@onready var _sel_ring: Panel = $SelRing


func setup(
	p_modifier_id: String,
	abbr_locale_key: String,
	card_size: Vector2 = _DEFAULT_SIZE,
	show_reward: bool = true
) -> void:
	modifier_id = p_modifier_id
	_abbr_key = abbr_locale_key
	_show_reward = show_reward
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	flat = true
	custom_minimum_size = card_size
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text = ""
	pivot_offset = card_size * 0.5
	if is_node_ready():
		_refresh_visuals()
	else:
		apply_locale()


func apply_locale() -> void:
	var abbr_text := _RunModifiers.translate_abbr(modifier_id, _abbr_key)
	if _abbr_label:
		_abbr_label.text = abbr_text
	if _abbr_shadow:
		_abbr_shadow.text = abbr_text
	_refresh_reward_label()
	_refresh_card_tooltip()
	if _locked_disabled and _locked_tooltip.strip_edges() != "":
		tooltip_text = _locked_tooltip


func apply_params_state(params: Dictionary) -> void:
	_run_params = params
	_refresh_reward_label()
	_refresh_gear_icon()
	_refresh_card_tooltip()


func set_modifier_active(active: bool) -> void:
	if (_locked_disabled or _dna_gated) and active:
		return
	set_block_signals(true)
	set_pressed_no_signal(active)
	_apply_visual_state()
	set_block_signals(false)


func set_preview_focused(on: bool) -> void:
	if _preview_focused == on:
		return
	_preview_focused = on
	_apply_hover_visuals()


func set_info_locked(on: bool) -> void:
	if _info_locked == on:
		return
	_info_locked = on
	_apply_visual_state()


func set_conflict_active(on: bool) -> void:
	if _conflict_active == on:
		return
	_conflict_active = on
	_apply_visual_state()


func set_conflict_preview(on: bool) -> void:
	set_conflict_active(on)


func set_modifier_disabled(is_disabled: bool, tooltip: String = "") -> void:
	_locked_disabled = is_disabled
	_locked_tooltip = tooltip
	disabled = is_disabled
	if is_disabled:
		_dna_gated = false
		_dna_gated_tooltip = ""
	modulate = Color(0.58, 0.62, 0.7, 0.78) if is_disabled else Color(1, 1, 1, 1)
	tooltip_text = tooltip if is_disabled else ""
	if is_disabled:
		_preview_focused = false
		_info_locked = false
		_conflict_active = false
	if is_disabled and button_pressed:
		set_modifier_active(false)
	_apply_visual_state()


func set_dna_gated(is_gated: bool, tooltip: String = "") -> void:
	_dna_gated = is_gated
	_dna_gated_tooltip = tooltip
	disabled = false
	if is_gated and button_pressed:
		set_modifier_active(false)
	_refresh_dna_gated_visuals()
	_refresh_card_tooltip()


func _refresh_dna_gated_visuals() -> void:
	if _locked_disabled:
		return
	if _dna_gated:
		modulate = Color(0.68, 0.72, 0.78, 0.9)
	else:
		modulate = Color(1, 1, 1, 1)
	_apply_visual_state()


func _apply_abbr_scale(card_size: Vector2) -> void:
	if _abbr_label == null or _abbr_shadow == null:
		return
	var font_size := int(clampf(card_size.y * 0.19, 13, 21))
	var band_h := maxf(22.0, card_size.y * 0.26)
	if _abbr_label:
		_abbr_label.add_theme_font_size_override("font_size", font_size)
		_abbr_label.offset_top = -band_h
		_abbr_label.offset_bottom = -3.0
	if _abbr_shadow:
		_abbr_shadow.add_theme_font_size_override("font_size", font_size)
		_abbr_shadow.offset_top = -band_h
		_abbr_shadow.offset_bottom = -3.0


func _ready() -> void:
	text = ""
	clip_contents = true
	_setup_sel_ring()
	resized.connect(_sync_pivot)
	call_deferred("_sync_pivot")
	toggled.connect(_on_card_toggled)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_refresh_visuals()


func _on_card_toggled(pressed: bool) -> void:
	if _locked_disabled or modifier_id == "":
		if pressed:
			set_modifier_active(false)
		return
	if _dna_gated:
		set_modifier_active(false)
		card_toggled.emit(modifier_id, false)
		return
	if pressed:
		play_select_pop()
	card_toggled.emit(modifier_id, pressed)


func play_select_pop() -> void:
	_UiMotionEffects.pop_scale(self, 1.12, 0.12, 0.2)


func _on_mouse_entered() -> void:
	if modifier_id == "" or _locked_disabled:
		return
	card_hovered.emit(modifier_id)


func _on_mouse_exited() -> void:
	if modifier_id == "":
		return
	card_unhovered.emit(modifier_id)


func _refresh_visuals() -> void:
	if modifier_id == "":
		return
	_load_cover_texture()
	_load_symbol_icon()
	_refresh_reward_label()
	_refresh_gear_icon()
	_refresh_card_tooltip()
	apply_locale()
	_apply_abbr_scale(custom_minimum_size)
	_apply_visual_state()


func _sync_pivot() -> void:
	pivot_offset = size * 0.5
	_apply_abbr_scale(size)


func _setup_sel_ring() -> void:
	if _sel_ring == null:
		return
	_sel_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_sel_ring_style()
	if _conflict_ring:
		_conflict_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_update_conflict_ring_style()


func _update_conflict_ring_style() -> void:
	if _conflict_ring == null:
		return
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = _RunModifiers.card_active_conflict_border_color()
	box.set_border_width_all(2)
	box.set_corner_radius_all(10)
	_conflict_ring.add_theme_stylebox_override("panel", box)


func _update_sel_ring_style() -> void:
	if _sel_ring == null or modifier_id == "":
		return
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = _RunModifiers.card_selection_border_color(modifier_id)
	box.set_border_width_all(2)
	box.set_corner_radius_all(10)
	_sel_ring.add_theme_stylebox_override("panel", box)


func _load_cover_texture() -> void:
	if _icon_bg == null or modifier_id == "":
		return
	var path := _RunModifiers.cover_path(modifier_id)
	if not ResourceLoader.exists(path):
		path = "res://assets/modifiers/default.png"
	if ResourceLoader.exists(path):
		_icon_bg.texture = load(path)
	_icon_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED


func _load_symbol_icon() -> void:
	if _symbol_icon == null or modifier_id == "":
		return
	var file_name := _RunModifiers.icon_file(modifier_id)
	if file_name == "":
		_symbol_icon.visible = false
		return
	var tint := _RunModifiers.category_tint(modifier_id, button_pressed)
	_symbol_icon.texture = UiIconHelper.load_tinted_icon(file_name, tint)
	_symbol_icon.visible = _symbol_icon.texture != null


func _refresh_reward_label() -> void:
	if _reward_label == null or modifier_id == "":
		return
	_reward_label.visible = _show_reward
	if not _show_reward:
		return
	var delta: float = _RunModifiers.card_reward_delta(modifier_id, _run_params)
	if delta == 0.0 and modifier_id == _RunModifiers.ID_AUTOPLAY:
		_reward_label.text = "0×"
	elif delta == 0.0 and modifier_id == _RunModifiers.ID_COMBO_ESCALATION:
		_reward_label.text = "0×"
	elif delta == 0.0 and modifier_id == _RunModifiers.ID_SINGLE_LANE:
		_reward_label.text = "0×"
	elif delta == 0.0:
		_reward_label.text = "0%"
	elif delta > 0.0:
		_reward_label.text = "+%d%%" % int(round(delta * 100.0))
	else:
		_reward_label.text = "%d%%" % int(round(delta * 100.0))


func _refresh_gear_icon() -> void:
	if _gear_icon == null or modifier_id == "":
		return
	var has_params := _RunModifiers.modifier_has_detail_params(modifier_id)
	_gear_icon.visible = has_params
	if not has_params:
		return
	var customized := _RunModifiers.modifier_params_customized(modifier_id, _run_params)
	var tint := Color(0.48, 0.72, 0.98, 0.95) if customized else Color(0.58, 0.62, 0.7, 0.72)
	var cache_key := "settings|%s" % tint
	if cache_key != _gear_texture_key:
		_gear_texture_key = cache_key
		_gear_icon.texture = UiIconHelper.load_tinted_icon("settings.svg", tint)


func _refresh_card_tooltip() -> void:
	if _locked_disabled:
		if _locked_tooltip.strip_edges() != "":
			tooltip_text = _locked_tooltip
		return
	if _dna_gated and _dna_gated_tooltip.strip_edges() != "":
		tooltip_text = _dna_gated_tooltip
		return
	if modifier_id == "":
		tooltip_text = ""
		return
	if _RunModifiers.modifier_has_detail_params(modifier_id):
		tooltip_text = tr("MOD_CARD_TOOLTIP_PARAMS")
	else:
		tooltip_text = ""


func _get_empty_button_style() -> StyleBoxEmpty:
	if _empty_button_style == null:
		_empty_button_style = StyleBoxEmpty.new()
	return _empty_button_style


func _apply_visual_state() -> void:
	var empty := _get_empty_button_style()
	for state in ["normal", "hover", "focus", "pressed", "disabled"]:
		add_theme_stylebox_override(state, empty)
	if _focus_ring:
		_focus_ring.visible = _info_locked and not _conflict_active
	var show_conflict := _conflict_active
	var show_selection := button_pressed and not _conflict_active
	if _conflict_ring:
		_update_conflict_ring_style()
		_conflict_ring.visible = show_conflict
	if _sel_ring:
		_update_sel_ring_style()
		_sel_ring.visible = show_selection
	_sync_selection_pulse(show_selection)
	_apply_hover_visuals()
	if _icon_bg:
		var bg_alpha := 0.85 if button_pressed else 0.68
		_icon_bg.modulate = Color(0.82, 0.86, 0.94, bg_alpha)
		_icon_bg.visible = _icon_bg.texture != null
	if _symbol_icon and modifier_id != "":
		var sym_tint := _RunModifiers.category_tint(modifier_id, button_pressed)
		var file_name := _RunModifiers.icon_file(modifier_id)
		if file_name != "":
			var cache_key := "%s|%s|%s" % [
				modifier_id,
				file_name,
				sym_tint.lightened(0.08 if button_pressed else 0.0)
			]
			if cache_key != _symbol_texture_key:
				_symbol_texture_key = cache_key
				_symbol_icon.texture = UiIconHelper.load_tinted_icon(
					file_name,
					sym_tint.lightened(0.08 if button_pressed else 0.0)
				)
	if _abbr_label:
		_abbr_label.add_theme_color_override(
			"font_color",
			Color(1.0, 1.0, 1.0, 1.0) if button_pressed else Color(0.82, 0.86, 0.94, 1.0)
		)


func _apply_hover_visuals() -> void:
	var hover_lift := _preview_focused and not button_pressed and not _locked_disabled
	if hover_lift:
		modulate = Color(1.06, 1.06, 1.06, 1.0)
	elif _locked_disabled:
		modulate = Color(0.58, 0.62, 0.7, 0.78)
	elif _dna_gated:
		modulate = Color(0.68, 0.72, 0.78, 0.9)
	else:
		modulate = Color(1, 1, 1, 1)


func _sync_selection_pulse(show_selection: bool) -> void:
	if _sel_ring == null:
		return
	if show_selection == _selection_pulse_active:
		return
	_selection_pulse_active = show_selection
	_UiMotionEffects.stop_panel_border_pulse(_sel_ring)
	if not show_selection:
		return
	_UiMotionEffects.pulse_panel_border(
		_sel_ring,
		_RunModifiers.card_selection_border_color(modifier_id),
		0.38,
		0.92,
		0.85
	)


func _exit_tree() -> void:
	_selection_pulse_active = false
	if _sel_ring:
		_UiMotionEffects.stop_panel_border_pulse(_sel_ring)


func _gui_input(event: InputEvent) -> void:
	if modifier_id == "":
		return
	if _locked_disabled:
		return
	if (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_RIGHT
	):
		card_info_requested.emit(modifier_id)
		accept_event()
		return
	if event.is_action_pressed("ui_accept"):
		if _dna_gated:
			if not button_pressed:
				card_dna_enable_blocked.emit(modifier_id)
			accept_event()
			return
		set_modifier_active(not button_pressed)
		card_toggled.emit(modifier_id, button_pressed)
		accept_event()
