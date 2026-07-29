# scenes/song_select/run_modifiers/modifier_presets_dialog.gd
extends Control
class_name ModifierPresetsDialog

signal closed(preset_loaded: bool)

const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const _UserPresets = preload("res://logic/domain/modifiers/user_presets.gd")
const _IconStrip = preload("res://logic/ui/modifier_icon_strip.gd")
const _Overlay = preload("res://logic/ui/app_overlay_helpers.gd")
const _UiModifierSounds = preload("res://logic/ui/ui_modifier_sounds.gd")
const _GenPresetUi = preload("res://logic/ui/generation_preset_ui.gd")
const _PresetActiveHeader = preload("res://logic/ui/preset_active_header.gd")
const _StatusToast = preload("res://logic/ui/status_toast.gd")
const SLOT_ROW_SCENE := preload("res://scenes/song_select/run_modifiers/modifier_preset_slot_row.tscn")
const CHOICE_OVERLAY_SCENE := preload("res://ui/overlays/app_choice_overlay.tscn")

const TAB_MINE := "mine"
const TAB_FAVORITES := "favorites"
const PRESETS_OVERLAY_Z := 200

const _TAB_MINE_ACCENT := Color(0.45, 0.78, 0.98, 1.0)
const _TAB_FAV_ACCENT := Color(0.95, 0.78, 0.38, 1.0)
const _LOAD_ACCENT := Color(0.45, 0.78, 0.98, 1.0)
const _SAVE_ACCENT := Color(0.42, 0.88, 0.58, 1.0)
const _SAVE_AS_ACCENT := Color(0.55, 0.78, 0.98, 1.0)
const _CLEAR_ACCENT := Color(0.58, 0.66, 0.78, 1.0)
const _FAV_BTN_ACCENT := Color(0.95, 0.78, 0.38, 1.0)
const _SettingsSectionUi = preload("res://logic/ui/settings_section_ui.gd")

@onready var _back_button: Button = $BackButton
@onready var _title_label: Label = $Container/TitleLabel
@onready var _active_label: Label = $Container/ActivePresetLabel
@onready var _footer_hint: Label = $Container/FooterHintLabel
@onready var _tab_mine_btn: Button = $Container/TabsRow/TabMineBtn
@onready var _tab_fav_btn: Button = $Container/TabsRow/TabFavBtn
@onready var _list_vbox: VBoxContainer = $Container/BodyCenter/CardPanel/CardMargin/BodyHBox/LeftVBox/ListScroll/ListVBox
@onready var _detail_caption: Label = $Container/BodyCenter/CardPanel/CardMargin/BodyHBox/RightVBox/DetailPanel/DetailMargin/DetailVBox/DetailCaption
@onready var _save_as_hint_label: Label = $Container/BodyCenter/CardPanel/CardMargin/BodyHBox/RightVBox/DetailPanel/DetailMargin/DetailVBox/SaveAsHintLabel
@onready var _detail_name_edit: LineEdit = $Container/BodyCenter/CardPanel/CardMargin/BodyHBox/RightVBox/DetailPanel/DetailMargin/DetailVBox/DetailNameEdit
@onready var _detail_mult: Label = $Container/BodyCenter/CardPanel/CardMargin/BodyHBox/RightVBox/DetailPanel/DetailMargin/DetailVBox/DetailHeroPanel/HeroVBox/DetailMult
@onready var _detail_mult_caption: Label = $Container/BodyCenter/CardPanel/CardMargin/BodyHBox/RightVBox/DetailPanel/DetailMargin/DetailVBox/DetailHeroPanel/HeroVBox/DetailMultCaption
@onready var _detail_mod_count: Label = $Container/BodyCenter/CardPanel/CardMargin/BodyHBox/RightVBox/DetailPanel/DetailMargin/DetailVBox/DetailHeroPanel/HeroVBox/DetailModCount
@onready var _detail_ease_stat: Label = $Container/BodyCenter/CardPanel/CardMargin/BodyHBox/RightVBox/DetailPanel/DetailMargin/DetailVBox/DetailStatsRow/DetailEaseStat
@onready var _detail_hard_stat: Label = $Container/BodyCenter/CardPanel/CardMargin/BodyHBox/RightVBox/DetailPanel/DetailMargin/DetailVBox/DetailStatsRow/DetailHardStat
@onready var _detail_special_stat: Label = $Container/BodyCenter/CardPanel/CardMargin/BodyHBox/RightVBox/DetailPanel/DetailMargin/DetailVBox/DetailStatsRow/DetailSpecialStat
@onready var _detail_mods_header: Label = $Container/BodyCenter/CardPanel/CardMargin/BodyHBox/RightVBox/DetailPanel/DetailMargin/DetailVBox/DetailModsHeader
@onready var _detail_mods_vbox: VBoxContainer = $Container/BodyCenter/CardPanel/CardMargin/BodyHBox/RightVBox/DetailPanel/DetailMargin/DetailVBox/DetailModsArea/DetailModsScroll/DetailModsVBox
@onready var _detail_meta: Label = $Container/BodyCenter/CardPanel/CardMargin/BodyHBox/RightVBox/DetailPanel/DetailMargin/DetailVBox/DetailMeta
@onready var _load_button: Button = $Container/BodyCenter/CardPanel/CardMargin/BodyHBox/RightVBox/ActionsVBox/LoadButton
@onready var _clear_active_button: Button = $Container/BodyCenter/CardPanel/CardMargin/BodyHBox/RightVBox/ActionsVBox/ClearActiveButton
@onready var _save_button: Button = $Container/BodyCenter/CardPanel/CardMargin/BodyHBox/RightVBox/ActionsVBox/EditButton
@onready var _save_as_button: Button = $Container/BodyCenter/CardPanel/CardMargin/BodyHBox/RightVBox/ActionsVBox/SaveAsButton
@onready var _delete_button: Button = $Container/BodyCenter/CardPanel/CardMargin/BodyHBox/RightVBox/ActionsVBox/DeleteButton
@onready var _favorite_button: Button = $Container/BodyCenter/CardPanel/CardMargin/BodyHBox/RightVBox/ActionsVBox/FavoriteButton

var _presets: Dictionary = {}
var _domain: String = _UserPresets.DOMAIN_MODIFIER
var _host: Node = null
var _current_tab: String = TAB_MINE
var _highlight_slot: int = 1
var _slot_rows: Dictionary = {}
var _choice_overlay: AppChoiceOverlay = null
var _favorites_empty_label: Label = null
var _prompt_active := false
var _active_preset_row: HBoxContainer = null
var _help_link: Button = null
var _name_field_dirty := false
var _save_as_mode := false
var _save_as_target: int = 0


func configure(domain: String) -> void:
	if domain == _UserPresets.DOMAIN_GENERATION:
		_domain = _UserPresets.DOMAIN_GENERATION
	else:
		_domain = _UserPresets.DOMAIN_MODIFIER


func set_preset_host(host: Node) -> void:
	_host = host


func _is_generation() -> bool:
	return _domain == _UserPresets.DOMAIN_GENERATION


func _ready() -> void:
	UiIconHelper.configure_modal_overlay(self, PRESETS_OVERLAY_Z)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_ui_icons()
	_reload_presets()
	_highlight_slot = _active_slot()
	if _highlight_slot <= 0:
		_highlight_slot = clampi(int(_presets.get("active_slot", 1)), 1, _UserPresets.MAX_SLOTS)
	_build_list()
	_favorites_empty_label = Label.new()
	_favorites_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_favorites_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_favorites_empty_label.add_theme_font_size_override("font_size", 14)
	_favorites_empty_label.add_theme_color_override("font_color", Color(0.5, 0.58, 0.68, 0.9))
	_favorites_empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_favorites_empty_label.visible = false
	_favorites_empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _list_vbox:
		_list_vbox.add_child(_favorites_empty_label)
	_choice_overlay = _ensure_choice_overlay()
	if _back_button:
		_back_button.pressed.connect(_on_back_pressed)
	if _tab_mine_btn:
		_tab_mine_btn.pressed.connect(func(): _select_tab(TAB_MINE))
	if _tab_fav_btn:
		_tab_fav_btn.pressed.connect(func(): _select_tab(TAB_FAVORITES))
	if _load_button:
		_load_button.pressed.connect(_on_load_pressed)
	if _clear_active_button:
		_clear_active_button.pressed.connect(_on_clear_active_pressed)
	if _save_button:
		_save_button.pressed.connect(_queue_save_pressed)
	if _save_as_button:
		_save_as_button.pressed.connect(_queue_save_as_pressed)
	if _delete_button:
		_delete_button.pressed.connect(_on_delete_pressed)
	if _favorite_button:
		_favorite_button.pressed.connect(_on_toggle_favorite)
	if _detail_name_edit and not _detail_name_edit.text_changed.is_connected(_on_name_field_changed):
		_detail_name_edit.text_changed.connect(_on_name_field_changed)
	if _active_label:
		var container := _active_label.get_parent()
		_active_preset_row = _PresetActiveHeader.attach(container, -1, true, _active_label)
		_active_label = null
	_ensure_generation_help_link()
	apply_locale()
	_select_tab(TAB_MINE, false)
	_refresh_all()


func _ensure_generation_help_link() -> void:
	if not _is_generation() or _title_label == null:
		if _help_link:
			_help_link.visible = false
		return
	if _help_link == null:
		_help_link = _SettingsSectionUi.make_help_icon_button(tr("HELP_LINK_GEN_PRESETS"))
		_help_link.pressed.connect(_on_generation_help_link_pressed)
		var parent := _title_label.get_parent()
		if parent:
			# Keep icon beside the title without adding a tall text link row.
			if parent is BoxContainer and (parent as BoxContainer).vertical:
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 8)
				row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				var title_idx := _title_label.get_index()
				parent.add_child(row)
				parent.move_child(row, title_idx)
				parent.remove_child(_title_label)
				row.add_child(_title_label)
				_title_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				_title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				row.add_child(_help_link)
			else:
				parent.add_child(_help_link)
				parent.move_child(_help_link, _title_label.get_index() + 1)
				_title_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_help_link.visible = true


func _on_generation_help_link_pressed() -> void:
	_open_help_item("gen_presets")


func _open_help_item(item_id: String) -> void:
	if _host and _host.has_method("open_help_item"):
		_host.open_help_item(item_id)
		return
	var tree := get_tree()
	if tree == null:
		return
	var parent := get_parent()
	while parent:
		if parent.has_method("get_transitions"):
			var trans = parent.get_transitions()
			if trans and trans.has_method("open_help_item"):
				trans.open_help_item(item_id)
				return
		if parent.has_method("open_help_item"):
			parent.open_help_item(item_id)
			return
		parent = parent.get_parent()
	for child in tree.root.get_children():
		if child.has_method("get_transitions"):
			var root_trans = child.get_transitions()
			if root_trans and root_trans.has_method("open_help_item"):
				root_trans.open_help_item(item_id)
				return


func _on_name_field_changed(_new_text: String) -> void:
	_name_field_dirty = true


func _enter_save_as_mode() -> void:
	_save_as_mode = true
	_save_as_target = 0
	_name_field_dirty = false


func _exit_save_as_mode() -> void:
	_save_as_mode = false
	_save_as_target = 0


func _update_save_as_hint() -> void:
	if _save_as_hint_label == null:
		return
	if not _save_as_mode:
		_save_as_hint_label.visible = false
		_save_as_hint_label.text = ""
		return
	_save_as_hint_label.visible = true
	if _save_as_target > 0:
		_save_as_hint_label.text = tr("MOD_PRESET_SAVE_AS_MODE_HINT") % _save_as_target
	else:
		_save_as_hint_label.text = tr("MOD_PRESET_SAVE_AS_PICK_TARGET")


func _ensure_choice_overlay() -> AppChoiceOverlay:
	if _choice_overlay != null and is_instance_valid(_choice_overlay):
		return _choice_overlay
	var overlay := CHOICE_OVERLAY_SCENE.instantiate() as AppChoiceOverlay
	if overlay == null:
		push_error("ModifierPresetsDialog: failed to create choice overlay")
		return null
	add_child(overlay)
	overlay.z_as_relative = false
	overlay.z_index = PRESETS_OVERLAY_Z + 10
	_choice_overlay = overlay
	return overlay


func _raise_choice_overlay() -> void:
	if _choice_overlay == null:
		return
	_choice_overlay.z_as_relative = false
	_choice_overlay.z_index = PRESETS_OVERLAY_Z + 10
	_choice_overlay.move_to_front()


func _queue_save_pressed() -> void:
	call_deferred("_on_save_pressed")


func _queue_save_as_pressed() -> void:
	call_deferred("_on_save_as_pressed")


func _setup_ui_icons() -> void:
	UiIconHelper.apply_standard_back_button(_back_button)
	UiIconHelper.configure_button_icon(_tab_mine_btn, "layers.svg", _TAB_MINE_ACCENT, 20)
	UiIconHelper.configure_button_icon(_tab_fav_btn, "star.svg", _TAB_FAV_ACCENT, 20)
	UiIconHelper.setup_modal_accent_button(_load_button, "download.svg", _LOAD_ACCENT)
	if _clear_active_button:
		UiIconHelper.setup_modal_accent_button(_clear_active_button, "ban.svg", _CLEAR_ACCENT)
	UiIconHelper.setup_modal_accent_button(_save_button, "check.svg", _SAVE_ACCENT)
	if _save_as_button:
		UiIconHelper.setup_modal_accent_button(_save_as_button, "layers-2.svg", _SAVE_AS_ACCENT)
	_delete_button.theme_type_variation = &"FlatModalDangerButton"
	UiIconHelper.configure_button_icon(_delete_button, "trash-2.svg", Color(0.95, 0.42, 0.38, 1.0), 16)
	UiIconHelper.setup_modal_accent_button(_favorite_button, "star.svg", _FAV_BTN_ACCENT)


func apply_locale() -> void:
	if _title_label:
		_title_label.text = tr("GEN_PRESETS_TITLE" if _is_generation() else "MOD_PRESETS_TITLE")
	if _help_link:
		_help_link.tooltip_text = tr("HELP_LINK_GEN_PRESETS")
		_help_link.visible = _is_generation()
	if _back_button:
		_back_button.text = tr("BTN_BACK")
	if _footer_hint:
		_footer_hint.text = tr("MOD_PRESETS_FOOTER_HINT")
	if _tab_mine_btn:
		_tab_mine_btn.text = tr("MOD_PRESETS_TAB_MINE")
	if _tab_fav_btn:
		_tab_fav_btn.text = tr("MOD_PRESETS_TAB_FAVORITES")
	if _detail_caption:
		_detail_caption.text = _detail_caption_text()
	if _detail_mult_caption:
		_detail_mult_caption.text = (
			tr("GEN_PRESET_MODE_CAPTION") if _is_generation() else tr("MOD_SUMMARY_MULT_CAPTION")
		)
	if _detail_mods_header:
		_detail_mods_header.text = (
			tr("GEN_PRESET_PARAMS_HEADER") if _is_generation() else tr("MOD_SUMMARY_ACTIVE_HEADER")
		)
	if _load_button:
		_load_button.text = tr("MOD_PRESETS_LOAD")
	if _clear_active_button:
		_clear_active_button.text = tr("MOD_PRESETS_CLEAR_ACTIVE")
	if _save_button:
		_save_button.text = tr("MOD_PRESETS_SAVE")
	if _save_as_button:
		_save_as_button.text = tr("MOD_PRESETS_SAVE_AS")
	if _delete_button:
		_delete_button.text = tr("MOD_PRESETS_DELETE")
	if _detail_name_edit:
		_detail_name_edit.placeholder_text = tr("MOD_PRESET_NAME_PLACEHOLDER")
	_style_tabs()
	_refresh_ui()


func _build_list() -> void:
	if _list_vbox == null:
		return
	for child in _list_vbox.get_children():
		if child == _favorites_empty_label:
			continue
		child.queue_free()
	_slot_rows.clear()
	for slot in range(1, _UserPresets.MAX_SLOTS + 1):
		var row := SLOT_ROW_SCENE.instantiate()
		_list_vbox.add_child(row)
		row.slot_pressed.connect(_on_slot_pressed)
		row.slot_preview_requested.connect(_on_slot_preview_requested)
		row.slot_double_clicked.connect(_on_slot_double_clicked)
		_slot_rows[slot] = row


func _select_tab(tab_id: String, refresh: bool = true) -> void:
	if tab_id == _current_tab and refresh:
		return
	var prev_tab := _current_tab
	_current_tab = tab_id
	_style_tabs()
	_reconcile_favorites_selection()
	if refresh and prev_tab != tab_id:
		_UiModifierSounds.play_select()
	if refresh:
		_refresh_all()
	else:
		_update_list_visibility()
		_refresh_ui()


func _style_tabs() -> void:
	_apply_tab_style(_tab_mine_btn, _current_tab == TAB_MINE, _TAB_MINE_ACCENT)
	_apply_tab_style(_tab_fav_btn, _current_tab == TAB_FAVORITES, _TAB_FAV_ACCENT)


func _apply_tab_style(btn: Button, active: bool, accent: Color) -> void:
	if btn == null:
		return
	btn.flat = false
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(accent.r, accent.g, accent.b, 0.16 if active else 0.04)
	normal.border_color = Color(accent.r, accent.g, accent.b, 0.62 if active else 0.12)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 14.0
	normal.content_margin_right = 14.0
	normal.content_margin_top = 8.0
	normal.content_margin_bottom = 8.0
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", normal.duplicate())
	btn.add_theme_stylebox_override("pressed", normal.duplicate())
	btn.add_theme_stylebox_override("focus", normal.duplicate())
	btn.add_theme_color_override(
		"font_color",
		accent if active else Color(0.58, 0.66, 0.78, 0.92)
	)


func _reconcile_favorites_selection() -> void:
	if _current_tab != TAB_FAVORITES:
		return
	var visible_slots := _slots_for_tab(true)
	if visible_slots.is_empty():
		_highlight_slot = 0
	elif not visible_slots.has(_highlight_slot):
		_highlight_slot = visible_slots[0]


func _update_list_visibility() -> void:
	var visible_slots := _slots_for_tab(_current_tab == TAB_FAVORITES)
	for slot in _slot_rows.keys():
		var row = _slot_rows[slot]
		if row is CanvasItem:
			(row as CanvasItem).visible = visible_slots.has(slot)
	if _favorites_empty_label:
		_favorites_empty_label.text = tr("MOD_PRESETS_FAVORITES_EMPTY")
		_favorites_empty_label.visible = (
			_current_tab == TAB_FAVORITES and visible_slots.is_empty()
		)


func _refresh_all(reload_from_disk: bool = true) -> void:
	if reload_from_disk:
		_reload_presets()
	_reconcile_favorites_selection()
	_refresh_slot_list()
	_update_list_visibility()
	_refresh_ui()


func _refresh_slot_list() -> void:
	var active := _active_slot()
	var song_path := _generation_song_path()
	var instrument := _generation_instrument()
	for slot in _slot_rows.keys():
		var row = _slot_rows[slot]
		if row and row.has_method("setup"):
			row.setup(
				slot,
				_presets,
				slot == _highlight_slot,
				_domain,
				slot == active,
				song_path,
				instrument,
			)


func _generation_song_path() -> String:
	if not _is_generation() or _host == null:
		return ""
	if _host.has_method("preset_host_get_song_path"):
		return str(_host.call("preset_host_get_song_path")).strip_edges()
	return ""


func _generation_instrument() -> String:
	if not _is_generation():
		return "drums"
	var state := _host_current_state()
	return str(state.get("instrument", "drums")).strip_edges()


func _reload_presets() -> void:
	if _is_generation():
		_presets = SettingsManager.get_generation_presets()
	else:
		_presets = SettingsManager.get_run_modifier_presets()


func _persist_presets() -> void:
	if _is_generation():
		SettingsManager.set_generation_presets(_presets)
	else:
		SettingsManager.set_run_modifier_presets(_presets)


func _notify(text: String, kind: String = "success") -> void:
	_StatusToast.show_from_node(self, "preset", text, kind)


func _slots_for_tab(favorites_only: bool) -> Array[int]:
	if _is_generation():
		return _UserPresets.generation_slots_for_tab(_presets, favorites_only)
	return _UserPresets.slots_for_tab(_presets, favorites_only)


func _slot_is_filled(slot: int) -> bool:
	if _is_generation():
		return _UserPresets.is_generation_slot_filled(_presets, slot)
	return _UserPresets.is_slot_filled(_presets, slot)


func _slot_display_name(slot: int) -> String:
	if _is_generation():
		return _UserPresets.generation_display_name(_presets, slot)
	return _UserPresets.display_name(_presets, slot)


func _default_name_for_slot(slot: int) -> String:
	if _is_generation():
		return _UserPresets.default_generation_slot_name(slot)
	return _UserPresets.default_slot_name(slot)


func _active_slot() -> int:
	if _host and _host.has_method("preset_host_get_active_slot"):
		return int(_host.call("preset_host_get_active_slot"))
	return int(_presets.get("active_slot", 0))


func _host_is_dirty() -> bool:
	return _host != null and _host.has_method("preset_host_is_dirty") and bool(_host.call("preset_host_is_dirty"))


func _host_current_state() -> Dictionary:
	if _host and _host.has_method("preset_host_get_current_state"):
		return (_host.call("preset_host_get_current_state") as Dictionary).duplicate(true)
	return {}


func _refresh_ui() -> void:
	_update_active_header()
	_sync_name_field_for_highlight()
	_refresh_current_detail()
	_update_save_as_hint()
	if _load_button:
		_load_button.disabled = _highlight_slot <= 0 or _save_as_mode
	if _clear_active_button:
		_clear_active_button.disabled = _active_slot() <= 0 or _save_as_mode
	if _save_button:
		_save_button.disabled = _highlight_slot <= 0 or _save_as_mode
	if _save_as_button:
		if _save_as_mode:
			_save_as_button.text = tr("MOD_PRESETS_SAVE_AS_CONFIRM")
			_save_as_button.disabled = _save_as_target <= 0
		else:
			_save_as_button.text = tr("MOD_PRESETS_SAVE_AS")
			_save_as_button.disabled = false
	var highlight_saved := _highlight_slot > 0 and _slot_is_filled(_highlight_slot)
	if _delete_button:
		_delete_button.disabled = not highlight_saved or _save_as_mode
	if _favorite_button:
		_favorite_button.disabled = not highlight_saved or _save_as_mode
		if highlight_saved:
			var fav := _slot_favorite(_highlight_slot)
			_favorite_button.text = (
				tr("MOD_PRESET_UNFAVORITE") if fav else tr("MOD_PRESET_TOGGLE_FAVORITE")
			)
			UiIconHelper.configure_button_icon(_favorite_button, "star.svg", _FAV_BTN_ACCENT, 16)


func _update_active_header() -> void:
	if _active_preset_row == null:
		return
	var slot := _active_slot()
	_PresetActiveHeader.update(
		_active_preset_row,
		slot,
		_resolve_active_display_name(slot),
		_host_is_dirty(),
	)


func _resolve_active_display_name(slot: int) -> String:
	if slot <= 0:
		return ""
	var name := ""
	if _host and _host.has_method("preset_host_get_active_name"):
		name = str(_host.call("preset_host_get_active_name")).strip_edges()
	if name == "":
		name = _slot_display_name(slot)
	if name == "":
		name = tr("MOD_PRESET_SLOT_EMPTY")
	return name


func _save_target_slot() -> int:
	if _highlight_slot > 0:
		return _highlight_slot
	return _active_slot()


func _name_for_save(slot: int) -> String:
	if _detail_name_edit and (_highlight_slot == slot or (_name_field_dirty and slot == _save_target_slot())):
		return _read_save_as_name(slot)
	var name := _slot_display_name(slot)
	if name == tr("MOD_PRESET_SLOT_EMPTY"):
		name = _default_name_for_slot(slot)
	return name


func _sync_name_field_for_highlight() -> void:
	if _detail_name_edit == null:
		return
	if _detail_name_edit.has_focus() or _name_field_dirty:
		return
	if _highlight_slot <= 0:
		_detail_name_edit.text = ""
		_detail_name_edit.editable = false
		return
	_detail_name_edit.editable = true
	var slot_for_name := _save_as_target if _save_as_mode and _save_as_target > 0 else _highlight_slot
	if _slot_is_filled(slot_for_name):
		var entry_name := _slot_display_name(slot_for_name)
		if entry_name != tr("MOD_PRESET_SLOT_EMPTY"):
			_detail_name_edit.text = entry_name
			return
	_detail_name_edit.text = _default_name_for_slot(slot_for_name)


func _slot_favorite(slot: int) -> bool:
	if not _slot_is_filled(slot):
		return false
	if _is_generation():
		return bool(_UserPresets.get_generation_slot(_presets, slot).get("favorite", false))
	return bool(_UserPresets.get_slot(_presets, slot).get("favorite", false))


func _detail_caption_text() -> String:
	if _highlight_slot > 0 and _slot_is_filled(_highlight_slot):
		return tr("MOD_PRESET_SLOT_PREVIEW")
	return tr("MOD_PRESET_CURRENT_SETTINGS")


func _preview_slot_entry() -> Dictionary:
	if _highlight_slot > 0 and _slot_is_filled(_highlight_slot):
		if _is_generation():
			return _UserPresets.get_generation_slot(_presets, _highlight_slot)
		return _UserPresets.get_slot(_presets, _highlight_slot)
	return {}


func _refresh_current_detail() -> void:
	if _is_generation():
		_refresh_current_detail_generation()
		return
	var mods: Array[String] = []
	var params: Dictionary = _RunModifiers.default_params()
	var preview_entry := _preview_slot_entry()
	if not preview_entry.is_empty():
		mods = _RunModifiers.sanitize(preview_entry.get("modifiers", []))
		params = _RunModifiers.sanitize_params(preview_entry.get("params", {}))
	else:
		var state := _host_current_state()
		mods = _RunModifiers.sanitize(state.get("modifiers", []))
		params = _RunModifiers.sanitize_params(state.get("params", {}))
	var counts := _count_categories(mods)
	var mult := 1.0
	if not mods.is_empty():
		mult = _RunModifiers.reward_multiplier(mods, params)
	if _detail_mult:
		if mods.is_empty():
			_detail_mult.text = "1.00×"
		elif (
			_RunModifiers.has_modifier(mods, _RunModifiers.ID_AUTOPLAY)
			or _RunModifiers.has_modifier(mods, _RunModifiers.ID_COMBO_ESCALATION)
		) and is_equal_approx(mult, 0.0):
			_detail_mult.text = "0×"
		else:
			_detail_mult.text = "%.2f×" % mult
	if _detail_mod_count:
		_detail_mod_count.text = tr("MOD_SUMMARY_MOD_COUNT") % counts.x
	if _detail_ease_stat:
		_detail_ease_stat.text = tr("MOD_SUMMARY_EASE_STAT") % counts.y
	if _detail_hard_stat:
		_detail_hard_stat.text = tr("MOD_SUMMARY_HARD_STAT") % counts.z
	if _detail_special_stat:
		_detail_special_stat.text = tr("MOD_SUMMARY_SPECIAL_STAT") % counts.w
	if _detail_mods_vbox:
		_IconStrip.fill_mod_rows(_detail_mods_vbox, mods, tr("MOD_SUMMARY_EMPTY_TITLE"))
	if _detail_meta:
		if _highlight_slot > 0 and _slot_is_filled(_highlight_slot):
			var entry := _preview_slot_entry()
			_detail_meta.text = tr("MOD_PRESET_META") % [
				_UserPresets.format_slot_date(int(entry.get("updated_at", 0))),
				int(entry.get("use_count", 0)),
			]
		elif _active_slot() > 0 and _slot_is_filled(_active_slot()):
			var entry := _UserPresets.get_slot(_presets, _active_slot())
			_detail_meta.text = tr("MOD_PRESET_META") % [
				_UserPresets.format_slot_date(int(entry.get("updated_at", 0))),
				int(entry.get("use_count", 0)),
			]
		else:
			_detail_meta.text = tr("MOD_PRESET_SAVE_AS_HINT")


func _refresh_current_detail_generation() -> void:
	var preview_entry := _preview_slot_entry()
	var has_data := not preview_entry.is_empty()
	var state := preview_entry if has_data else _host_current_state()
	has_data = not state.is_empty()
	var mode := str(state.get("mode", "basic")) if has_data else "—"
	var lanes := int(state.get("lanes", 4)) if has_data else 0
	if _detail_mult:
		_detail_mult.text = _GenPresetUi.localized_mode(mode) if has_data else "—"
	if _detail_mod_count:
		_detail_mod_count.text = tr("GEN_PRESET_LANES_FMT") % lanes if has_data else "—"
	if _detail_ease_stat:
		_detail_ease_stat.text = tr("GEN_PRESET_STAT_FILL") % (int(state.get("fill", 0)) if has_data else "—")
	if _detail_hard_stat:
		_detail_hard_stat.text = tr("GEN_PRESET_STAT_DENSITY") % (int(state.get("density", 0)) if has_data else "—")
	if _detail_special_stat:
		_detail_special_stat.text = tr("GEN_PRESET_STAT_GROOVE") % (int(state.get("groove", 0)) if has_data else "—")
	if _detail_mods_vbox:
		_fill_generation_detail_rows(has_data, state)
	if _detail_meta:
		var slot_for_meta := _highlight_slot if _highlight_slot > 0 else _active_slot()
		if slot_for_meta > 0 and _slot_is_filled(slot_for_meta):
			var entry := _UserPresets.get_generation_slot(_presets, slot_for_meta)
			var chart_line := _generation_chart_status_line(slot_for_meta)
			_detail_meta.text = "%s\n%s" % [
				tr("GEN_PRESET_META") % [
					_UserPresets.format_slot_date(int(entry.get("updated_at", 0))),
					int(entry.get("use_count", 0)),
				],
				chart_line,
			]
		else:
			_detail_meta.text = tr("MOD_PRESET_SAVE_AS_HINT")


func _generation_chart_status_line(slot: int) -> String:
	var song_path := _generation_song_path()
	if song_path == "":
		return ""
	var instrument := _generation_instrument()
	if NotesUtils.preset_chart_exists(song_path, instrument, slot):
		return tr("GEN_PRESET_CHART_READY")
	return tr("GEN_PRESET_CHART_MISSING")


func _fill_generation_detail_rows(has_data: bool, entry: Dictionary) -> void:
	if _detail_mods_vbox == null:
		return
	for child in _detail_mods_vbox.get_children():
		child.queue_free()
	if not has_data:
		var empty := Label.new()
		empty.text = tr("MOD_PRESET_SAVE_AS_HINT")
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", Color(0.5, 0.58, 0.68, 0.9))
		_detail_mods_vbox.add_child(empty)
		return
	_GenPresetUi.fill_detail_rows(_detail_mods_vbox, entry)


func _count_categories(modifiers: Array) -> Vector4i:
	var total := 0
	var ease := 0
	var hard := 0
	var special := 0
	for raw_id in _RunModifiers.sanitize(modifiers):
		var mod_id := str(raw_id)
		total += 1
		if _RunModifiers.EASING_IDS.has(mod_id):
			ease += 1
		elif _RunModifiers.HARDENING_IDS.has(mod_id):
			hard += 1
		elif _RunModifiers.SPECIAL_IDS.has(mod_id):
			special += 1
	return Vector4i(total, ease, hard, special)


func _read_save_as_name(slot: int) -> String:
	var name := ""
	if _detail_name_edit:
		name = _UserPresets.sanitize_name(_detail_name_edit.text)
	if name == "":
		name = _default_name_for_slot(slot)
	return name


func _on_slot_pressed(slot: int) -> void:
	if slot <= 0:
		return
	if _save_as_mode:
		_save_as_target = slot
		_select_slot(slot)
		return
	if slot != _highlight_slot:
		_name_field_dirty = false
	_select_slot(slot)


func _on_slot_preview_requested(slot: int) -> void:
	if slot <= 0:
		return
	if _save_as_mode:
		_on_slot_pressed(slot)
		return
	_name_field_dirty = false
	_select_slot(slot)


func _on_slot_double_clicked(slot: int) -> void:
	if slot <= 0:
		return
	if _save_as_mode:
		_on_slot_pressed(slot)
		return
	if slot != _highlight_slot:
		_name_field_dirty = false
		_select_slot(slot)
	await _commit_load_slot(slot)


func _on_load_pressed() -> void:
	if _highlight_slot <= 0:
		return
	await _commit_load_slot(_highlight_slot)


func _on_clear_active_pressed() -> void:
	if _active_slot() <= 0:
		return
	if _host_is_dirty():
		var overlay := _ensure_choice_overlay()
		if overlay == null:
			return
		_prompt_active = true
		_raise_choice_overlay()
		var dirty_key := (
			"GEN_PRESET_CLEAR_CONFIRM_DIRTY"
			if _is_generation()
			else "MOD_PRESET_CLEAR_CONFIRM_DIRTY"
		)
		var choice := await _Overlay.choose(
			overlay,
			tr(dirty_key),
			"warning",
			"",
			tr("MOD_PRESETS_CLEAR_ACTIVE"),
			tr("BTN_CANCEL"),
		)
		_prompt_active = false
		if choice != "confirm":
			return
	elif not _is_generation():
		var overlay := _ensure_choice_overlay()
		if overlay == null:
			return
		_prompt_active = true
		_raise_choice_overlay()
		var choice := await _Overlay.choose(
			overlay,
			tr("MOD_PRESET_CLEAR_CONFIRM"),
			"warning",
			"",
			tr("MOD_PRESETS_CLEAR_ACTIVE"),
			tr("BTN_CANCEL"),
		)
		_prompt_active = false
		if choice != "confirm":
			return
	await _commit_clear_active_preset()


func _commit_clear_active_preset() -> void:
	if _host == null:
		return
	if _is_generation():
		_presets = _UserPresets.clear_active_generation_slot(_presets)
		if _host.has_method("preset_host_clear_active"):
			_host.call("preset_host_clear_active")
	else:
		_presets = _UserPresets.clear_active_modifier_slot(_presets)
		if _host.has_method("preset_host_clear_preset"):
			_host.call("preset_host_clear_preset")
		elif _host.has_method("preset_host_clear_active"):
			_host.call("preset_host_clear_active")
	_persist_presets()
	_highlight_slot = 0
	_name_field_dirty = false
	_exit_save_as_mode()
	_UiModifierSounds.play_deselect()
	_refresh_all(false)
	_notify(tr("PRESET_TOAST_CLEARED"), "info")
	_close(true)


func _select_slot(slot: int) -> void:
	if slot <= 0:
		return
	_highlight_slot = slot
	_refresh_slot_list()
	_refresh_ui()
	if _detail_caption:
		_detail_caption.text = _detail_caption_text()


func _commit_load_slot(slot: int) -> void:
	if slot <= 0:
		return
	if _host_is_dirty():
		var choice := await _prompt_dirty_changes()
		if choice == "cancel":
			return
		if choice == "confirm":
			if not await _save_active_slot():
				return
	var loaded_name := _slot_display_name(slot)
	var was_filled := _slot_is_filled(slot)
	if not _apply_load_slot(slot):
		return
	_UiModifierSounds.play_select()
	_highlight_slot = slot
	_refresh_all(false)
	if was_filled:
		_notify(tr("PRESET_TOAST_LOADED") % loaded_name)
	_close(true)


func _apply_load_slot(slot: int) -> bool:
	if _host == null:
		return false
	if _is_generation():
		var snapshot: Dictionary = {}
		if _slot_is_filled(slot):
			snapshot = _UserPresets.get_generation_slot(_presets, slot).duplicate(true)
		else:
			snapshot = _UserPresets.sanitize_generation_slot(_host_current_state())
		if _host.has_method("preset_host_apply_preset"):
			_host.call("preset_host_apply_preset", slot, snapshot)
		_presets = _UserPresets.set_active_generation_slot(_presets, slot)
	else:
		var mods: Array = []
		var params: Dictionary = _RunModifiers.default_params()
		if _slot_is_filled(slot):
			var entry := _UserPresets.get_slot(_presets, slot)
			mods = entry.get("modifiers", [])
			params = entry.get("params", {})
		if _host.has_method("preset_host_apply_preset"):
			_host.call("preset_host_apply_preset", slot, {"modifiers": mods, "params": params})
		_presets = _UserPresets.set_active_modifier_slot(_presets, slot)
	_persist_presets()
	return true


func _on_save_pressed() -> void:
	var slot := _save_target_slot()
	if slot <= 0:
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	if await _write_slot(slot, _name_for_save(slot), true):
		_name_field_dirty = false
		_UiModifierSounds.play_select()
		_refresh_all(false)
		_notify(tr("PRESET_TOAST_SAVED") % _slot_display_name(slot))


func _save_active_slot() -> bool:
	var slot := _active_slot()
	if slot <= 0:
		return false
	return _write_slot(slot, _name_for_save(slot), true)


func _on_save_as_pressed() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	if not _save_as_mode:
		_enter_save_as_mode()
		_refresh_ui()
		return
	if _save_as_target <= 0:
		return
	var slot := _save_as_target
	var name := _read_save_as_name(slot)
	if _slot_is_filled(slot):
		var overlay := _ensure_choice_overlay()
		if overlay == null:
			return
		_prompt_active = true
		_raise_choice_overlay()
		var confirm_key := "GEN_PRESET_OVERWRITE_CONFIRM" if _is_generation() else "MOD_PRESET_OVERWRITE_CONFIRM"
		var choice := await _Overlay.choose(
			overlay,
			tr(confirm_key) % _slot_display_name(slot),
			"warning",
			"",
			tr("MOD_PRESETS_SAVE"),
			tr("BTN_CANCEL"),
		)
		_prompt_active = false
		if choice != "confirm":
			return
	if await _write_slot(slot, name, true):
		_name_field_dirty = false
		_exit_save_as_mode()
		_UiModifierSounds.play_select()
		_refresh_all(false)
		_notify(tr("PRESET_TOAST_SAVED") % _slot_display_name(slot))


func _write_slot(slot: int, name: String, make_active: bool) -> bool:
	if _host == null:
		return false
	var state := _host_current_state()
	var keep := {}
	if _slot_is_filled(slot):
		if _is_generation():
			var prev_gen := _UserPresets.get_generation_slot(_presets, slot)
			keep["favorite"] = prev_gen.get("favorite", false)
			keep["use_count"] = prev_gen.get("use_count", 0)
		else:
			var prev := _UserPresets.get_slot(_presets, slot)
			keep["favorite"] = prev.get("favorite", false)
			keep["use_count"] = prev.get("use_count", 0)
	var slot_name := _UserPresets.sanitize_name(name)
	if slot_name == "":
		slot_name = _default_name_for_slot(slot)
	if _is_generation():
		_presets = _UserPresets.save_generation_slot(
			_presets,
			slot,
			slot_name,
			state,
			keep,
		)
	else:
		_presets = _UserPresets.save_modifier_slot(
			_presets,
			slot,
			slot_name,
			state.get("modifiers", []),
			state.get("params", {}),
			keep,
		)
	if make_active:
		if _is_generation():
			_presets = _UserPresets.set_active_generation_slot(_presets, slot)
		else:
			_presets = _UserPresets.set_active_modifier_slot(_presets, slot)
	_persist_presets()
	if _host.has_method("preset_host_mark_saved"):
		_host.call("preset_host_mark_saved", slot)
	_name_field_dirty = false
	return true


func _prompt_dirty_changes() -> String:
	var active := _active_slot()
	var name := _slot_display_name(active) if active > 0 else ""
	var overlay := _ensure_choice_overlay()
	if overlay == null:
		return "extra"
	_prompt_active = true
	_raise_choice_overlay()
	var choice := await _Overlay.choose(
		overlay,
		tr("MOD_PRESET_UNSAVED_CHANGES") % name,
		"warning",
		"",
		tr("MOD_PRESETS_SAVE"),
		tr("BTN_CANCEL"),
		tr("BTN_DISCARD_CHANGES"),
	)
	_prompt_active = false
	return choice


func _on_delete_pressed() -> void:
	if _highlight_slot <= 0 or not _slot_is_filled(_highlight_slot):
		return
	var slot := _highlight_slot
	var name := _slot_display_name(slot)
	var confirm_key := "GEN_PRESET_DELETE_CONFIRM" if _is_generation() else "MOD_PRESET_DELETE_CONFIRM"
	var overlay := _ensure_choice_overlay()
	if overlay == null:
		return
	_prompt_active = true
	_raise_choice_overlay()
	var choice := await _Overlay.choose(
		overlay,
		tr(confirm_key) % name,
		"warning",
		"",
		tr("MOD_PRESETS_DELETE"),
		tr("BTN_CANCEL"),
	)
	_prompt_active = false
	if choice != "confirm":
		return
	if _is_generation():
		_presets = _UserPresets.delete_generation_slot(_presets, slot)
	else:
		_presets = _UserPresets.delete_modifier_slot(_presets, slot)
	_persist_presets()
	if slot == _active_slot() and _host and _host.has_method("preset_host_clear_active"):
		_host.call("preset_host_clear_active")
	_UiModifierSounds.play_deselect()
	_refresh_all(false)
	_notify(tr("PRESET_TOAST_DELETED") % name, "info")


func _on_toggle_favorite() -> void:
	if _highlight_slot <= 0 or not _slot_is_filled(_highlight_slot):
		return
	var slot := _highlight_slot
	var fav := not _slot_favorite(slot)
	if _is_generation():
		_presets = _UserPresets.set_generation_slot_favorite(_presets, slot, fav)
	else:
		_presets = _UserPresets.set_modifier_slot_favorite(_presets, slot, fav)
	_persist_presets()
	_UiModifierSounds.play_toggle(fav)
	_refresh_all(false)


func _on_back_pressed() -> void:
	if _prompt_active:
		return
	if _save_as_mode:
		_exit_save_as_mode()
		_refresh_ui()
		return
	if _host_is_dirty():
		var choice := await _prompt_dirty_changes()
		if choice == "cancel":
			return
		if choice == "confirm":
			if not await _save_active_slot():
				return
	_close()


func _close(preset_loaded: bool = false) -> void:
	closed.emit(preset_loaded)
	queue_free()


func _hotkey_select_visible_index(index: int) -> void:
	var visible := _slots_for_tab(_current_tab == TAB_FAVORITES)
	if index < 0 or index >= visible.size():
		return
	var slot := visible[index]
	if _save_as_mode:
		_on_slot_pressed(slot)
	else:
		_select_slot(slot)


func _hotkey_select_tab(tab_id: String) -> void:
	if tab_id == _current_tab:
		return
	_select_tab(tab_id)


func _is_input_blocked() -> bool:
	if _prompt_active:
		return true
	if _choice_overlay != null and _choice_overlay.visible:
		return true
	return UiScreenHotkeys.should_block_hotkeys(get_viewport())


func _unhandled_input(event: InputEvent) -> void:
	if _is_input_blocked():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key_event := event as InputEventKey
	match key_event.keycode:
		KEY_ESCAPE:
			accept_event()
			if _save_as_mode:
				_exit_save_as_mode()
				_refresh_ui()
			else:
				_on_back_pressed()
		KEY_Q:
			accept_event()
			_hotkey_select_tab(TAB_MINE)
		KEY_W:
			accept_event()
			_hotkey_select_tab(TAB_FAVORITES)
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
			accept_event()
			_hotkey_select_visible_index(int(key_event.keycode - KEY_1))
		KEY_0:
			accept_event()
			_hotkey_select_visible_index(9)
		KEY_ENTER, KEY_KP_ENTER:
			accept_event()
			if _save_as_mode:
				if _save_as_target > 0:
					await _on_save_as_pressed()
			else:
				await _commit_load_slot(_highlight_slot)
