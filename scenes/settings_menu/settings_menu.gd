# scenes/settings_menu/settings_menu.gd
extends BaseScreen

const _UiListSlideTransition = preload("res://logic/ui/ui_list_slide_transition.gd")
const _SettingsDialogUtils = preload("res://logic/ui/settings_dialog_utils.gd")
const _Overlay = preload("res://logic/ui/app_overlay_helpers.gd")

const PAGE_SOUND := "sound"
const PAGE_GRAPHICS := "graphics"
const PAGE_CONTROLS := "controls"
const PAGE_SYSTEM := "system"
const PAGE_GENERATION := "generation"
const PAGE_EXPERIMENTAL := "experimental"
const PAGE_LIBRARY := "library"
const PAGE_DATA := "data"
const PAGE_DANGER := "danger"

const PAGE_ORDER: Array[String] = [
	PAGE_SOUND,
	PAGE_GRAPHICS,
	PAGE_CONTROLS,
	PAGE_SYSTEM,
	PAGE_GENERATION,
	PAGE_LIBRARY,
	PAGE_DATA,
	PAGE_EXPERIMENTAL,
	PAGE_DANGER,
]

const PAGE_TAB_INDEX := {
	PAGE_SOUND: 0,
	PAGE_GRAPHICS: 1,
	PAGE_CONTROLS: 2,
	PAGE_SYSTEM: 3,
	PAGE_GENERATION: 4,
	PAGE_LIBRARY: 5,
	PAGE_DATA: 6,
	PAGE_EXPERIMENTAL: 7,
	PAGE_DANGER: 8,
}

const PAGE_ACCENT: Dictionary = {
	PAGE_SOUND: Color(0.38, 0.78, 0.74, 1.0),
	PAGE_GRAPHICS: Color(0.42, 0.57, 0.82, 1.0),
	PAGE_CONTROLS: Color(0.86, 0.52, 0.72, 1.0),
	PAGE_SYSTEM: Color(0.66, 0.58, 0.86, 1.0),
	PAGE_GENERATION: Color(0.62, 0.86, 0.72, 1.0),
	PAGE_EXPERIMENTAL: Color(0.52, 0.76, 0.92, 1.0),
	PAGE_LIBRARY: Color(0.92, 0.78, 0.45, 1.0),
	PAGE_DATA: Color(0.80, 0.86, 0.94, 1.0),
	PAGE_DANGER: Color(0.95, 0.45, 0.42, 1.0),
}

## Primary action buttons → lucide icon (optional). Danger / reset-all stay red via FlatExitButton.
const PAGE_ACTION_ICONS := {
	"StartCalibrationButton": "metronome.svg",
	"ResetCalibrationButton": "rotate-ccw.svg",
	"ScanSongsButton": "folder-search.svg",
	"ChooseSongsFolderButton": "folder.svg",
	"OpenSongsFolderButton": "folder-open.svg",
	"ChooseNotesFolderButton": "folder.svg",
	"OpenNotesFolderButton": "folder-open.svg",
}

var game_screen = null
var achievement_manager = null

@onready var back_button: Button = $MainHBox/SidebarCard/SidebarMargin/SidebarVBox/BackButton
@onready var nav_list: VBoxContainer = $MainHBox/SidebarCard/SidebarMargin/SidebarVBox/NavScroll/NavVBox
@onready var reset_all_button: Button = $MainHBox/SidebarCard/SidebarMargin/SidebarVBox/ResetAllButton
@onready var version_label: Label = $MainHBox/SidebarCard/SidebarMargin/SidebarVBox/VersionLabel
@onready var footer_label: Label = $FooterLabel
@onready var page_title_label: Label = $MainHBox/ContentColumn/ContentHeader/PageTitleLabel
@onready var page_subtitle_label: Label = $MainHBox/ContentColumn/ContentHeader/PageSubtitleLabel
@onready var tab_container: TabContainer = $MainHBox/ContentColumn/ContentContainer/ContentCard/ContentCardMargin/SettingsTabContainer
@onready var content_card: PanelContainer = $MainHBox/ContentColumn/ContentContainer/ContentCard
@onready var main_hbox: HBoxContainer = $MainHBox
@onready var _choice_overlay: AppChoiceOverlay = %ChoiceOverlay

var _nav_items: Dictionary = {}
var _current_page: String = PAGE_SOUND
var _settings_skip_transition := true
var _deferred_page_id := ""
var _sound_tab: Control
var _graphics_tab: Control
var _controls_tab: Control
var _system_tab: Control
var _generation_tab: Control
var _experimental_tab: Control
var _library_tab: Control
var _data_tab: Control
var _danger_tab: Control
var _settings_initializing := true
var _settings_snapshot_json: String = ""
var _content_shell_default: StyleBoxFlat = null
var _back_prompt_active := false


func apply_locale() -> void:
	if back_button:
		back_button.text = tr("BTN_BACK")
		apply_back_button_style()
	if reset_all_button:
		reset_all_button.text = tr("MISC_RESET_ALL_SETTINGS")
		reset_all_button.tooltip_text = tr("MISC_RESET_ALL_SETTINGS_TOOLTIP")
		reset_all_button.theme_type_variation = &"FlatExitButton"
	if version_label:
		version_label.text = tr("UPDATE_VERSION_LABEL") % AppVersion.get_display_version()
	_update_footer_hint()
	if _choice_overlay:
		_choice_overlay.apply_locale()
	for page_id in PAGE_ORDER:
		var item: SettingsNavItem = _nav_items.get(page_id)
		if item:
			item.refresh_locale()
	_update_page_header()
	_apply_tab_locales(false)


func _apply_tab_locales(stagger: bool) -> void:
	if tab_container == null:
		return
	for i in range(tab_container.get_tab_count()):
		var child = tab_container.get_child(i)
		if child and child.has_method("apply_locale"):
			child.apply_locale()
		if stagger and i < tab_container.get_tab_count() - 1:
			await get_tree().process_frame


func _apply_tab_locales_staggered() -> void:
	await _apply_tab_locales(true)


func _ready() -> void:
	set_process_input(true)
	var parent_node = get_parent()
	var trans = null
	if parent_node and parent_node.has_method("get_transitions"):
		trans = parent_node.get_transitions()
	if trans:
		setup_managers(trans)

	var game_engine_node = null
	if parent_node and parent_node.has_method("get_achievement_manager"):
		game_engine_node = parent_node
	else:
		if get_tree().root.has_node("GameEngine"):
			game_engine_node = get_tree().root.get_node("GameEngine")
		else:
			for child in get_tree().root.get_children():
				if child.has_method("get_achievement_manager"):
					game_engine_node = child
					break
	if game_engine_node and game_engine_node.has_method("get_achievement_manager"):
		achievement_manager = game_engine_node.get_achievement_manager()

	tab_container.tabs_visible = false
	_cache_tabs()
	_cache_content_shell_style()
	_bind_nav_items()
	_connect_signals()
	_set_content_busy(true)
	call_deferred("_apply_dialog_styles")
	call_deferred("_deferred_initial_setup")


func open_help_topic(search_key: String) -> void:
	if transitions:
		transitions.open_help_with_search(tr(search_key))


func open_help_item(item_id: String) -> void:
	if transitions:
		transitions.open_help_item(item_id)


func _cache_tabs() -> void:
	_sound_tab = tab_container.get_node_or_null("SoundTab")
	_graphics_tab = tab_container.get_node_or_null("GraphicsTab")
	_controls_tab = tab_container.get_node_or_null("ControlsTab")
	_system_tab = tab_container.get_node_or_null("SystemTab")
	_generation_tab = tab_container.get_node_or_null("GenerationTab")
	_experimental_tab = tab_container.get_node_or_null("ExperimentalTab")
	_library_tab = tab_container.get_node_or_null("LibraryTab")
	_data_tab = tab_container.get_node_or_null("DataTab")
	_danger_tab = tab_container.get_node_or_null("DangerTab")


func _cache_content_shell_style() -> void:
	if content_card == null:
		return
	var sb := content_card.get_theme_stylebox("panel")
	if sb is StyleBoxFlat:
		_content_shell_default = (sb as StyleBoxFlat).duplicate()


func _bind_nav_items() -> void:
	_nav_items.clear()
	if nav_list == null:
		return
	for child in nav_list.get_children():
		if child is SettingsNavItem:
			var item := child as SettingsNavItem
			if item.page_id.strip_edges() == "":
				continue
			_nav_items[item.page_id] = item
			if not item.nav_selected.is_connected(_on_nav_selected):
				item.nav_selected.connect(_on_nav_selected)


func _setup_tabs() -> void:
	var song_metadata_mgr = null
	if get_parent() and get_parent().has_method("get_song_metadata_manager"):
		song_metadata_mgr = get_parent().get_song_metadata_manager()

	for i in range(tab_container.get_child_count()):
		var child = tab_container.get_child(i)
		var tab_title = child.name.replace("Tab", "")
		tab_container.set_tab_title(i, tab_title)
		if not child.has_method("setup_ui_and_manager"):
			continue
		if child.name == "LibraryTab" or child.name == "DataTab":
			child.setup_ui_and_manager(game_screen, song_metadata_mgr, achievement_manager)
		elif child.name == "GraphicsTab":
			var game_engine = null
			if get_parent() and get_parent().has_method("get_settings_manager"):
				game_engine = get_parent()
			elif get_tree().root.has_node("GameEngine"):
				game_engine = get_tree().root.get_node("GameEngine")
			child.setup_ui_and_manager(game_engine)
		else:
			child.setup_ui_and_manager(game_screen)
		if child.has_signal("settings_changed"):
			if not child.is_connected("settings_changed", Callable(self, "_on_tab_settings_changed")):
				child.connect("settings_changed", Callable(self, "_on_tab_settings_changed"))


func _connect_signals() -> void:
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
		back_button.focus_mode = Control.FOCUS_NONE
	if reset_all_button:
		reset_all_button.pressed.connect(_on_reset_all_pressed)
	apply_back_button_style()


func _is_overlay_mode() -> bool:
	if transitions == null or transitions.game_engine == null:
		return false
	return self != transitions.game_engine.current_screen


func apply_back_button_style() -> void:
	if back_button == null:
		return
	# Full-width sidebar row (match nav items). FlatBackButton fill, not hub outline chip.
	UiIconHelper.apply_standard_back_button(back_button)
	back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_button.custom_minimum_size = Vector2(0, maxf(back_button.custom_minimum_size.y, 40.0))


func _apply_dialog_styles() -> void:
	_SettingsDialogUtils.apply_to_descendants(self)
	if _choice_overlay:
		_choice_overlay.apply_locale()


func _on_nav_selected(page_id: String) -> void:
	_switch_page(page_id)


func switch_to_page(page_id: String) -> void:
	if _settings_skip_transition:
		_deferred_page_id = page_id
		return
	_switch_page(page_id)


func _deferred_initial_setup() -> void:
	var overlay := _get_loading_overlay()
	if overlay:
		overlay.show_loading(tr("UI_LOADING_SETTINGS"), true)
	_set_content_busy(true)
	await get_tree().process_frame
	_setup_tabs()
	await get_tree().process_frame
	var target_page := _deferred_page_id if _deferred_page_id != "" else PAGE_SOUND
	_deferred_page_id = ""
	_switch_page(target_page)
	if back_button:
		back_button.text = tr("BTN_BACK")
	if reset_all_button:
		reset_all_button.text = tr("MISC_RESET_ALL_SETTINGS")
		reset_all_button.tooltip_text = tr("MISC_RESET_ALL_SETTINGS_TOOLTIP")
		reset_all_button.theme_type_variation = &"FlatExitButton"
	if version_label:
		version_label.text = tr("UPDATE_VERSION_LABEL") % AppVersion.get_display_version()
	_update_footer_hint()
	if _choice_overlay:
		_choice_overlay.apply_locale()
	for page_id in PAGE_ORDER:
		var item: SettingsNavItem = _nav_items.get(page_id)
		if item:
			item.refresh_locale()
	_update_page_header()
	await _apply_tab_locales_staggered()
	_set_content_busy(false)
	if overlay:
		overlay.hide_loading()
	_settings_skip_transition = false
	await get_tree().process_frame
	await get_tree().process_frame
	_capture_settings_snapshot()
	_settings_initializing = false
	_update_footer_hint()


func _set_content_busy(busy: bool) -> void:
	if main_hbox == null:
		return
	main_hbox.modulate.a = 0.0 if busy else 1.0
	main_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE if busy else Control.MOUSE_FILTER_PASS


func _switch_page(page_id: String) -> void:
	if page_id not in PAGE_ORDER:
		return
	var changed := page_id != _current_page
	if changed:
		UiScreenHotkeys.play_section_switch_sound()
	var apply := func() -> void:
		_current_page = page_id
		for id in _nav_items:
			var item: SettingsNavItem = _nav_items[id]
			if item:
				item.set_selected(id == page_id)
		if tab_container:
			tab_container.current_tab = int(PAGE_TAB_INDEX.get(page_id, 0))
		_update_page_header()
		_notify_page_shown(page_id)
	var skip := _settings_skip_transition or not changed
	_UiListSlideTransition.crossfade(content_card, apply, skip, false)


func _notify_page_shown(page_id: String) -> void:
	var tab: Control = null
	match page_id:
		PAGE_DATA:
			tab = _data_tab
		PAGE_SYSTEM:
			tab = _system_tab
		_:
			return
	if tab and tab.has_method("on_settings_page_shown"):
		tab.on_settings_page_shown()


func _update_page_header() -> void:
	var accent: Color = PAGE_ACCENT.get(_current_page, Color(0.42, 0.57, 0.82, 1.0))
	if page_title_label:
		page_title_label.text = tr("SETTINGS_NAV_%s" % _current_page.to_upper())
		page_title_label.add_theme_color_override("font_color", accent)
	if page_subtitle_label:
		page_subtitle_label.text = tr("SETTINGS_NAV_%s_DESC" % _current_page.to_upper())
		page_subtitle_label.add_theme_color_override(
			"font_color",
			Color(accent.r, accent.g, accent.b, 0.78)
		)
	_apply_content_shell_accent(accent)


func _apply_content_shell_accent(accent: Color) -> void:
	if content_card == null or _content_shell_default == null:
		return
	var box := _content_shell_default.duplicate() as StyleBoxFlat
	if box:
		box.border_color = Color(accent.r, accent.g, accent.b, 0.45)
		content_card.add_theme_stylebox_override("panel", box)
	_tint_page_action_buttons(accent)


func _tint_page_action_buttons(accent: Color) -> void:
	if tab_container == null:
		return
	var tab := tab_container.get_current_tab_control()
	if tab == null:
		return
	var targets: Array[Button] = []
	_collect_tintable_buttons(tab, targets)
	var n := targets.size()
	for i in range(n):
		var btn := targets[i]
		var shade := _page_accent_shade(accent, i, n, btn.name)
		var variation := btn.theme_type_variation
		UiIconHelper.apply_outline_accent(btn, shade, variation if variation != &"" else &"FlatButton")
		var icon_file := str(PAGE_ACTION_ICONS.get(btn.name, ""))
		if icon_file != "":
			UiIconHelper.configure_button_icon(btn, icon_file, shade, 16)
		_wire_settings_button_sfx(btn)
	# Also wire sounds on non-tinted action buttons (segmented stay silent — they already play).
	_wire_settings_button_sfx_under(tab)


func _wire_settings_button_sfx_under(node: Node) -> void:
	if node == null:
		return
	if node is Button and not (node is CheckButton) and not (node is OptionButton):
		var btn := node as Button
		if not btn.has_meta("option_id"):
			_wire_settings_button_sfx(btn)
	for child in node.get_children():
		_wire_settings_button_sfx_under(child)


func _wire_settings_button_sfx(btn: Button) -> void:
	if btn == null or btn.get_meta("ui_mod_sfx_wired", false):
		return
	if UiIconHelper.is_danger_button_variation(btn.theme_type_variation):
		# Danger keeps cancel-like feedback on press via existing patterns; still soft select.
		pass
	btn.set_meta("ui_mod_sfx_wired", true)
	btn.pressed.connect(func() -> void:
		UiModifierSounds.play_select()
	)


func _collect_tintable_buttons(node: Node, out: Array[Button]) -> void:
	if node == null:
		return
	if node is Button and not (node is CheckButton) and not (node is OptionButton):
		var btn := node as Button
		if _should_tint_settings_button(btn):
			out.append(btn)
	for child in node.get_children():
		_collect_tintable_buttons(child, out)


func _should_tint_settings_button(btn: Button) -> bool:
	if btn == null:
		return false
	# Segmented one-of-many (FPS / quality / …) — keep shared FlatModal look.
	if btn.has_meta("option_id"):
		return false
	var parent := btn.get_parent()
	if parent and str(parent.name).ends_with("Segmented"):
		return false
	if btn.button_group != null:
		return false
	var variation := btn.theme_type_variation
	if UiIconHelper.is_danger_button_variation(variation):
		return false
	return (
		variation == &"FlatButton"
		or variation == &"FlatGenerateButton"
		or variation == &"FlatModalPrimaryButton"
		or variation == &"FlatButtonAmber"
		or variation == &"FlatButtonGreen"
		or variation == &"FlatButtonOrange"
		or variation == &"FlatButtonYellow"
		or variation == &""
	)


func _page_accent_shade(base: Color, index: int, total: int, seed_name: String = "") -> Color:
	## Same hue family, different tone — not one flat accent for every button.
	if total <= 1:
		return base
	var h := base.h
	var s := base.s
	var v := base.v
	# Stable-ish offset from name so order reshuffles less across locale refreshes.
	var name_hash := int(hash(seed_name))
	var step := index + (absi(name_hash) % 5)
	var hue_nudge := ((step % 7) - 3) * 0.012  # ~±4° within blue/teal/…
	var sat_nudge := ((step % 5) - 2) * 0.07
	var val_nudge := ((step % 4) - 1) * 0.05
	# Primary action (Generate / Start…) slightly brighter; later buttons cooler/dimmer.
	if index == 0:
		val_nudge += 0.04
		sat_nudge += 0.04
	elif index >= total - 1 and total > 2:
		val_nudge -= 0.03
		sat_nudge -= 0.05
	return Color.from_hsv(
		fposmod(h + hue_nudge, 1.0),
		clampf(s + sat_nudge, 0.28, 0.92),
		clampf(v + val_nudge, 0.48, 0.96),
		base.a
	)


func _on_reset_all_pressed() -> void:
	if _danger_tab and _danger_tab.has_method("request_reset_all_settings"):
		_danger_tab.request_reset_all_settings()


func _execute_close_transition() -> void:
	if transitions:
		# Overlay when Settings is not the GameEngine current_screen (pause / contextual).
		var from_pause := false
		if transitions.game_engine:
			from_pause = self != transitions.game_engine.current_screen
		transitions.close_settings(from_pause)


func _on_back_pressed() -> void:
	if _back_prompt_active:
		return
	if _is_settings_dirty():
		_back_prompt_active = true
		var choice := await _Overlay.choose(
			_choice_overlay,
			tr("DLG_SETTINGS_UNSAVED_TEXT"),
			"warning",
			"",
			tr("BTN_SAVE"),
			tr("BTN_CANCEL"),
			tr("BTN_DISCARD_CHANGES"),
		)
		_back_prompt_active = false
		match choice:
			"confirm":
				_on_unsaved_save_and_close()
			"extra":
				_on_unsaved_discard_pressed()
		return
	_perform_close()


func _on_unsaved_save_and_close() -> void:
	if _is_settings_dirty():
		_apply_settings_with_feedback()
	_perform_close()


func _on_unsaved_discard_pressed() -> void:
	_revert_pending_settings()
	_perform_close()


func _perform_close() -> void:
	var parent_node = get_parent()
	var game_engine = null
	if parent_node and parent_node.has_method("prepare_screen_exit"):
		game_engine = parent_node
	elif get_tree().root.has_node("GameEngine"):
		game_engine = get_tree().root.get_node("GameEngine")

	if game_engine and game_engine.has_method("prepare_screen_exit") and game_engine.current_screen == self:
		if game_engine.prepare_screen_exit(self):
			pass
		else:
			printerr("SettingsMenu: ОШИБКА подготовки экрана к выходу через GameEngine.")

	cleanup_before_exit()
	MusicManager.play_cancel_sound()
	_execute_close_transition()


func cleanup_before_exit() -> void:
	var overlay := _get_loading_overlay()
	if overlay:
		overlay.reset_loading()


func _revert_pending_settings() -> void:
	SettingsManager.reload_from_disk()
	if LocaleManager:
		LocaleManager.set_locale(String(SettingsManager.get_setting("language", "ru")), true, false)
	if MusicManager and MusicManager.has_method("update_volumes_from_settings"):
		MusicManager.update_volumes_from_settings()
	var engine := _find_game_engine()
	if engine and engine.has_method("update_display_settings"):
		engine.update_display_settings()
	_refresh_all_tabs()
	_capture_settings_snapshot()
	_update_footer_hint()


func _refresh_all_tabs() -> void:
	if tab_container == null:
		return
	for i in range(tab_container.get_child_count()):
		var child = tab_container.get_child(i)
		if child == null:
			continue
		if child.has_method("refresh_ui"):
			child.refresh_ui()
		elif child.has_method("_apply_initial_settings"):
			child._apply_initial_settings()


func _find_game_engine() -> Node:
	var parent_node = get_parent()
	if parent_node and parent_node.has_method("update_display_settings"):
		return parent_node
	if get_tree().root.has_node("GameEngine"):
		return get_tree().root.get_node("GameEngine")
	return null


func sync_persisted_settings_snapshot() -> void:
	_capture_settings_snapshot()
	_update_footer_hint()


func _on_tab_settings_changed() -> void:
	if _settings_initializing:
		return
	_update_footer_hint()


func _capture_settings_snapshot() -> void:
	_settings_snapshot_json = SettingsManager.export_settings_json()


func _parse_settings_json(json_text: String) -> Dictionary:
	if json_text.strip_edges() == "":
		return {}
	var parsed = JSON.parse_string(json_text)
	return parsed if parsed is Dictionary else {}


func _normalize_settings_value(value: Variant) -> Variant:
	if value is float:
		var rounded := roundf(value)
		if absf(value - rounded) < 0.0001:
			return int(rounded)
		return snappedf(value, 0.0001)
	if value is Dictionary:
		var out := {}
		var keys := (value as Dictionary).keys()
		keys.sort()
		for key in keys:
			out[key] = _normalize_settings_value(value[key])
		return out
	if value is Array:
		var out: Array = []
		for item in value:
			out.append(_normalize_settings_value(item))
		return out
	return value


func _settings_json_equal(a: String, b: String) -> bool:
	var left: Variant = _normalize_settings_value(_parse_settings_json(a))
	var right: Variant = _normalize_settings_value(_parse_settings_json(b))
	return JSON.stringify(left) == JSON.stringify(right)


func _is_settings_dirty() -> bool:
	if _settings_snapshot_json == "":
		return false
	return not _settings_json_equal(SettingsManager.export_settings_json(), _settings_snapshot_json)


func _update_footer_hint() -> void:
	if footer_label == null:
		return
	if _is_settings_dirty():
		footer_label.text = tr("SETTINGS_FOOTER_APPLY_HINT")
	else:
		footer_label.text = tr("SETTINGS_FOOTER_HINT")


func _apply_settings_with_feedback() -> void:
	if not _is_settings_dirty():
		return
	var dock := _find_status_dock()
	if dock:
		dock.show_transient("settings", tr("STATUS_SAVING"), "save", 0.0)
	SettingsManager.save_settings()
	_capture_settings_snapshot()
	_update_footer_hint()
	if dock:
		dock.show_transient("settings", tr("STATUS_SAVED"), "success", 2.5)


func save_settings() -> void:
	_apply_settings_with_feedback()


func _find_status_dock() -> StatusDock:
	var node: Node = self
	while node:
		if node.has_method("get_status_dock"):
			return node.get_status_dock()
		node = node.get_parent()
	if get_tree().root.has_node("GameEngine"):
		var ge = get_tree().root.get_node("GameEngine")
		if ge and ge.has_method("get_status_dock"):
			return ge.get_status_dock()
	return null


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if _is_modal_overlay_visible():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE and not _is_text_input_focused():
			if _is_settings_dirty():
				_apply_settings_with_feedback()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if UiScreenHotkeys.is_global_loading_active(get_viewport()):
		get_viewport().set_input_as_handled()
		return
	if _is_modal_overlay_visible():
		return
	var bindings := {}
	for i in range(mini(PAGE_ORDER.size(), 9)):
		bindings[KEY_1 + i] = _switch_page.bind(PAGE_ORDER[i])
	if UiScreenHotkeys.try_handle(bindings, event, get_viewport()):
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


func _is_text_input_focused() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit or focus is CodeEdit


func _is_modal_overlay_visible() -> bool:
	return _choice_overlay != null and _choice_overlay.visible
