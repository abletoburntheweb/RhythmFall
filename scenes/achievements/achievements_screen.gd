# scenes/achievements/achievements_screen.gd
extends BaseScreen

const ACHIEVEMENT_CARD_SCENE := preload("res://scenes/achievements/achievement_card.tscn")
const ACHIEVEMENT_SHELF_CARD_SCENE := preload("res://scenes/achievements/achievement_shelf_card.tscn")
const ACHIEVEMENTS_JSON_PATH := "res://data/achievements_data.json"
const _AchievementLocale = preload("res://logic/i18n/achievement_locale.gd")
const _UiListSlideTransition = preload("res://logic/ui/ui_list_slide_transition.gd")
const _UiCategoryButton = preload("res://logic/ui/ui_category_button.gd")
const _UiModifierSounds = preload("res://logic/ui/ui_modifier_sounds.gd")
var AchievementsUtils = preload("res://logic/domain/profile/achievements_utils.gd").new()

enum ViewMode { OVERVIEW, LIST }
enum ListKind { CATEGORY, FULL, SEARCH }

const _STATUS_SPECS: Array = [
	["all", "ACH_FILTER_ALL", "layers-2.svg", Color(0.92, 0.76, 0.42, 1.0)],
	["unlocked", "ACH_FILTER_UNLOCKED", "circle-check.svg", Color(0.55, 0.92, 0.65, 1.0)],
	["locked", "ACH_FILTER_LOCKED", "lock_keyhole.svg", Color(0.68, 0.72, 0.82, 1.0)],
]

const _VIEW_SPECS: Array = [
	["overview", "ACH_VIEW_OVERVIEW", "layout-dashboard.svg", Color(0.66, 0.58, 0.86, 1.0)],
	["full", "ACH_VIEW_FULL_LIST", "list-checks.svg", Color(0.52, 0.76, 0.92, 1.0)],
]

const _CATEGORY_SPECS: Array = [
	["mastery", "ACH_CAT_MASTERY"],
	["drums", "ACH_CAT_DRUMS"],
	["bass", "ACH_CAT_BASS"],
	["genres", "ACH_CAT_GENRES"],
	["system", "ACH_CAT_SYSTEM"],
	["shop", "ACH_CAT_SHOP"],
	["economy", "ACH_CAT_ECONOMY"],
	["daily", "ACH_CAT_DAILY"],
	["playtime", "ACH_CAT_PLAYTIME"],
	["events", "ACH_CAT_EVENTS"],
	["level", "ACH_CAT_LEVEL"],
	["modifiers", "ACH_CAT_MODIFIERS"],
	["play_modes", "ACH_CAT_PLAY_MODES"],
]

const _ACCENT_BY_CATEGORY := {
	"mastery": Color(0.66, 0.58, 0.86),
	"drums": Color(0.38, 0.78, 0.74),
	"bass": Color(0.45, 0.62, 0.92),
	"genres": Color(0.86, 0.52, 0.72),
	"system": Color(0.8, 0.86, 0.94),
	"shop": Color(0.52, 0.76, 0.92),
	"economy": Color(0.95, 0.78, 0.35),
	"daily": Color(0.62, 0.86, 0.72),
	"playtime": Color(0.42, 0.57, 0.82),
	"events": Color(0.95, 0.55, 0.45),
	"level": Color(0.55, 0.92, 0.65),
	"modifiers": Color(0.52, 0.76, 0.94),
	"play_modes": Color(0.62, 0.48, 0.95),
	"default": Color(0.42, 0.57, 0.82),
}

const _CHIP_MIN_HEIGHT := 42
const _CHIP_FONT_SIZE := 16
const _OVERVIEW_PREVIEW_COUNT := 4

const _UI_FALLBACK_RU := {
	"ACH_SUBTITLE": "Ваш прогресс и коллекция достижений",
	"ACH_SHOW_ALL": "Показать все",
	"ACH_BACK_TO_OVERVIEW": "← К обзору",
	"ACH_VIEW_FULL_LIST": "Полный список",
	"ACH_VIEW_OVERVIEW": "Обзор",
	"ACH_SEARCH_RESULTS": "Результаты поиска",
	"ACH_SECTION_PROGRESS": "%d / %d открыто",
	"ACH_CAT_BASS": "Бас",
}

@onready var back_button: Button = $MainVBox/BackButton
@onready var title_label: Label = $MainVBox/TitleLabel
@onready var subtitle_label: Label = $MainVBox/SubtitleLabel
@onready var counter_label: Label = $MainVBox/CounterLabel
@onready var unlock_progress_bar: ProgressBar = $MainVBox/UnlockProgressBar
@onready var search_bar: LineEdit = $MainVBox/FilterBarPanel/FilterVBox/SearchBar
@onready var filter_bar_panel: PanelContainer = $MainVBox/FilterBarPanel
@onready var status_chips_hbox: HBoxContainer = $MainVBox/FilterBarPanel/FilterVBox/ToolbarHBox/StatusChipsHBox
@onready var view_mode_hbox: HBoxContainer = $MainVBox/FilterBarPanel/FilterVBox/ToolbarHBox/ViewModeHBox
@onready var list_nav_bar: HBoxContainer = $MainVBox/FilterBarPanel/FilterVBox/ListNavBar
@onready var list_nav_back_button: Button = $MainVBox/FilterBarPanel/FilterVBox/ListNavBar/ListNavBackButton
@onready var list_nav_title_label: Label = $MainVBox/FilterBarPanel/FilterVBox/ListNavBar/ListNavTitleLabel
@onready var achievements_scroll: ScrollContainer = $MainVBox/ContentContainer/AchievementsScroll
@onready var overview_root: VBoxContainer = $MainVBox/ContentContainer/AchievementsScroll/BottomMargin/ContentVBox/OverviewRoot
@onready var list_root: VBoxContainer = $MainVBox/ContentContainer/AchievementsScroll/BottomMargin/ContentVBox/ListRoot
@onready var achievements_list: VBoxContainer = $MainVBox/ContentContainer/AchievementsScroll/BottomMargin/ContentVBox/ListRoot/AchievementsList
@onready var footer_label: Label = $MainVBox/FooterLabel

var achievements: Array[Dictionary] = []
var filtered_achievements: Array[Dictionary] = []
var current_status_filter: String = "all"
var achievement_manager: AchievementManager = null
var _view_mode: ViewMode = ViewMode.OVERVIEW
var _list_kind: ListKind = ListKind.FULL
var _active_category_id: String = ""
var _render_generation := 0
var _overview_generation := 0
var _search_revision := 0
const _SEARCH_DEBOUNCE_SEC := 0.12

const _CARD_BATCH_FIRST := 8
const _CARD_BATCH := 16
var _achievements_skip_transition := true
var _render_in_progress := false
var _filter_task_token := 0

var _status_chips: Dictionary = {}
var _view_chips: Dictionary = {}
var _filter_chips_built := false


func _tr_ui(key: String) -> String:
	var translated := tr(key)
	if translated == key and _UI_FALLBACK_RU.has(key):
		return String(_UI_FALLBACK_RU[key])
	return translated


func apply_locale() -> void:
	if back_button:
		back_button.text = tr("BTN_BACK")
	if title_label:
		title_label.text = tr("ACH_TITLE")
	if subtitle_label:
		subtitle_label.text = _tr_ui("ACH_SUBTITLE")
	if search_bar:
		search_bar.placeholder_text = tr("ACH_SEARCH_PLACEHOLDER")
	if list_nav_back_button:
		list_nav_back_button.text = _tr_ui("ACH_BACK_TO_OVERVIEW")
	if footer_label:
		footer_label.text = tr("ACHIEVEMENTS_FOOTER_HINT")
	_refresh_filter_chips_locale()
	_update_list_nav_title()
	_update_counter()
	_refresh_visible_cards_locale()
	_refresh_display("", "none")


func _refresh_visible_cards_locale() -> void:
	for root in [overview_root, achievements_list]:
		if root == null:
			continue
		for child in root.get_children():
			_refresh_card_locale_recursive(child)


func _refresh_card_locale_recursive(node: Node) -> void:
	if node.has_method("apply_locale"):
		node.apply_locale()
	for child in node.get_children():
		_refresh_card_locale_recursive(child)


func _refresh_filter_chips_locale() -> void:
	if not _filter_chips_built:
		return
	for spec in _STATUS_SPECS:
		var filter_id := String(spec[0])
		var chip: Button = _status_chips.get(filter_id)
		if chip:
			chip.text = tr(String(spec[1]))
	for spec in _VIEW_SPECS:
		var view_id := String(spec[0])
		var chip: Button = _view_chips.get(view_id)
		if chip:
			chip.text = _tr_ui(String(spec[1]))
	_apply_filter_chip_selection()


func _ready():
	var overlay := _get_loading_overlay()
	if overlay:
		overlay.show_loading(tr("UI_LOADING_ACHIEVEMENTS"), true)
	var game_engine = get_parent()
	if game_engine:
		var trans = null
		var ach_mgr = null
		if game_engine.has_method("get_transitions"):
			trans = game_engine.get_transitions()
		if game_engine.has_method("get_achievement_manager"):
			ach_mgr = game_engine.get_achievement_manager()
		setup_managers(trans)
		achievement_manager = ach_mgr
		if not trans:
			printerr("AchievementsScreen: Не удалось получить Transitions через GameEngine!")
		if not ach_mgr:
			printerr("AchievementsScreen: Не удалось получить AchievementManager через GameEngine!")
	else:
		printerr("AchievementsScreen: GameEngine (get_parent()) не найден!")

	_load_achievements_data()
	_build_filter_chips()
	if list_root:
		list_root.visible = false
	call_deferred("_deferred_initial_display")
	_setup_ui_icons()


func _setup_ui_icons() -> void:
	if search_bar:
		UiIconHelper.setup_search_field(search_bar)


func _build_filter_chips() -> void:
	if _filter_chips_built:
		return
	_clear_chip_row(status_chips_hbox, _status_chips)
	_clear_chip_row(view_mode_hbox, _view_chips)

	for spec in _STATUS_SPECS:
		var filter_id := String(spec[0])
		var chip := _create_filter_chip(tr(String(spec[1])), String(spec[2]), spec[3] as Color)
		chip.pressed.connect(_on_status_chip_pressed.bind(filter_id))
		status_chips_hbox.add_child(chip)
		_status_chips[filter_id] = chip

	for spec in _VIEW_SPECS:
		var view_id := String(spec[0])
		var chip := _create_filter_chip(_tr_ui(String(spec[1])), String(spec[2]), spec[3] as Color)
		chip.pressed.connect(_on_view_chip_pressed.bind(view_id))
		view_mode_hbox.add_child(chip)
		_view_chips[view_id] = chip

	_apply_filter_chip_selection()
	_filter_chips_built = true


func _clear_chip_row(row: BoxContainer, registry: Dictionary) -> void:
	if row == null:
		return
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()
	registry.clear()


func _create_filter_chip(label: String, icon_file: String, accent: Color) -> Button:
	var chip := Button.new()
	chip.text = label
	chip.set_meta("ui_icon_file", icon_file)
	chip.set_meta("ui_accent_color", accent)
	chip.custom_minimum_size = Vector2(0, _CHIP_MIN_HEIGHT)
	chip.add_theme_font_size_override("font_size", _CHIP_FONT_SIZE)
	chip.clip_text = false
	chip.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	chip.focus_mode = Control.FOCUS_NONE
	return chip


func _apply_filter_chip_selection() -> void:
	_reset_filter_chip_hover()
	_apply_filter_chip_selection_impl()
	var tree := get_tree()
	if tree and _filter_chips_built:
		tree.create_timer(0.05).timeout.connect(
			func() -> void:
				_reset_filter_chip_hover()
				_apply_filter_chip_selection_impl(),
			CONNECT_ONE_SHOT
		)


func _reset_filter_chip_hover() -> void:
	for chip in _status_chips.values():
		if chip is Button:
			_UiCategoryButton.reset_hover_state(chip)
	for chip in _view_chips.values():
		if chip is Button:
			_UiCategoryButton.reset_hover_state(chip)


func _apply_filter_chip_selection_impl() -> void:
	for filter_id in _status_chips.keys():
		var chip: Button = _status_chips[filter_id]
		if chip:
			_UiCategoryButton.apply_selection(chip, String(filter_id) == current_status_filter, 14, true)
	var active_view := ""
	if _view_mode == ViewMode.OVERVIEW:
		active_view = "overview"
	elif _view_mode == ViewMode.LIST and _list_kind == ListKind.FULL:
		active_view = "full"
	for view_id in _view_chips.keys():
		var chip: Button = _view_chips[view_id]
		if chip:
			_UiCategoryButton.apply_selection(chip, String(view_id) == active_view, 14, true)


func _deferred_initial_display() -> void:
	await _refresh_display_await("", "none")
	_achievements_skip_transition = false


func _load_achievements_data() -> void:
	achievements.clear()
	if achievement_manager and achievement_manager.achievements.size() > 0:
		for item in achievement_manager.achievements:
			if item is Dictionary:
				achievements.append(item.duplicate(true))
	else:
		var ach_list = _get_achievements_data()
		if ach_list != null:
			for item in ach_list:
				if item is Dictionary:
					achievements.append(item)
				else:
					printerr("AchievementsScreen: Найден элемент не типа Dictionary в списке достижений: ", item)
	_update_counter()
	if _filter_chips_built:
		_refresh_filter_chips_locale()


func _sort_by_title(a: Dictionary, b: Dictionary) -> bool:
	var title_a = _AchievementLocale.localized_title(a).to_lower()
	var title_b = _AchievementLocale.localized_title(b).to_lower()
	if title_a == title_b:
		return int(a.get("id", 0)) < int(b.get("id", 0))
	return title_a < title_b


func _achievement_progress_ratio(ach: Dictionary) -> float:
	if ach.get("unlocked", false):
		return 1.0
	var total := maxf(float(ach.get("total", 1)), 1.0)
	return clampf(float(ach.get("current", 0)) / total, 0.0, 1.0)


func _sort_by_nearest_unlock(a: Dictionary, b: Dictionary) -> bool:
	var ratio_a := _achievement_progress_ratio(a)
	var ratio_b := _achievement_progress_ratio(b)
	var a_started: bool = ratio_a > 0.0 or bool(a.get("unlocked", false))
	var b_started: bool = ratio_b > 0.0 or bool(b.get("unlocked", false))
	if a_started != b_started:
		return a_started
	if ratio_a != ratio_b:
		return ratio_a > ratio_b
	return _sort_by_title(a, b)


func _pick_overview_preview(items: Array) -> Array:
	var locked: Array = []
	var unlocked: Array = []
	for ach in items:
		if not (ach is Dictionary):
			continue
		if ach.get("unlocked", false):
			unlocked.append(ach)
		else:
			locked.append(ach)
	locked.sort_custom(Callable(self, "_sort_by_nearest_unlock"))
	var result: Array = []
	for ach in locked:
		if result.size() >= _OVERVIEW_PREVIEW_COUNT:
			break
		result.append(ach)
	if result.size() < _OVERVIEW_PREVIEW_COUNT:
		unlocked.sort_custom(Callable(self, "_sort_by_nearest_unlock"))
		for ach in unlocked:
			if result.size() >= _OVERVIEW_PREVIEW_COUNT:
				break
			result.append(ach)
	return result


func _is_catalog_visible(ach: Dictionary) -> bool:
	# Deprecated achievements are fully retired from the catalog.
	return not bool(ach.get("deprecated", false))


func _is_active_achievement(ach: Dictionary) -> bool:
	return not bool(ach.get("deprecated", false))


func _update_counter() -> void:
	var scope := _counter_scope_achievements()
	var unlocked_count := 0
	var total_active := 0
	for a in scope:
		if not (a is Dictionary):
			continue
		if _is_active_achievement(a):
			total_active += 1
			if a.get("unlocked", false):
				unlocked_count += 1
	if counter_label:
		counter_label.text = tr("ACH_UNLOCKED") % [unlocked_count, total_active]
	if unlock_progress_bar:
		unlock_progress_bar.max_value = maxf(float(total_active), 1.0)
		unlock_progress_bar.value = float(unlocked_count)


func _counter_scope_achievements() -> Array:
	if _view_mode == ViewMode.LIST and _list_kind == ListKind.CATEGORY and _active_category_id != "":
		return _achievements_for_category(_active_category_id, false)
	var all_visible: Array = []
	for ach in achievements:
		if ach is Dictionary and _is_catalog_visible(ach):
			all_visible.append(ach)
	return all_visible


func _category_unlock_counts(category_id: String) -> Dictionary:
	var unlocked := 0
	var total := 0
	var target := category_id.to_lower()
	for ach in achievements:
		if not (ach is Dictionary):
			continue
		if str(ach.get("category", "")).to_lower() != target:
			continue
		if not _is_active_achievement(ach):
			continue
		total += 1
		if ach.get("unlocked", false):
			unlocked += 1
	return {"unlocked": unlocked, "total": total}


func _achievements_for_category(category_id: String, apply_status: bool) -> Array[Dictionary]:
	var target := category_id.to_lower()
	var scoped: Array[Dictionary] = []
	for ach in achievements:
		if not (ach is Dictionary):
			continue
		if str(ach.get("category", "")).to_lower() != target:
			continue
		if not _is_catalog_visible(ach):
			continue
		scoped.append(ach)
	if apply_status:
		scoped = _apply_status_filter(scoped, current_status_filter)
	scoped.sort_custom(Callable(self, "_sort_by_title"))
	return scoped


func _apply_status_filter(achievements_to_filter: Array, filter_type: String) -> Array:
	if filter_type == "all":
		return achievements_to_filter.filter(func(ach):
			return ach is Dictionary and _is_catalog_visible(ach)
		)
	if filter_type == "unlocked":
		return achievements_to_filter.filter(func(ach):
			return ach is Dictionary and ach.get("unlocked", false) and _is_catalog_visible(ach)
		)
	if filter_type == "locked":
		return achievements_to_filter.filter(func(ach):
			return (
				ach is Dictionary
				and not ach.get("unlocked", false)
				and _is_active_achievement(ach)
			)
		)
	return achievements_to_filter.duplicate()


func _on_search_text_changed(new_text: String) -> void:
	_search_revision += 1
	var revision := _search_revision
	await get_tree().create_timer(_SEARCH_DEBOUNCE_SEC).timeout
	if revision != _search_revision:
		return
	_refresh_display(new_text, "crossfade")


func _on_status_chip_pressed(filter_id: String) -> void:
	if current_status_filter != filter_id:
		UiScreenHotkeys.play_section_switch_sound()
	current_status_filter = filter_id
	_apply_filter_chip_selection()
	_refresh_display(search_bar.text if search_bar else "", "slide")


func _on_view_chip_pressed(view_id: String) -> void:
	if view_id == "overview":
		_go_to_overview(false)
	else:
		_open_full_list(false)
	UiScreenHotkeys.play_section_switch_sound()


func _on_list_nav_back_pressed() -> void:
	_go_to_overview(true)


func _go_to_overview(play_sound: bool) -> void:
	if search_bar:
		search_bar.text = ""
	_view_mode = ViewMode.OVERVIEW
	_list_kind = ListKind.FULL
	_active_category_id = ""
	_apply_filter_chip_selection()
	_update_nav_visibility()
	_update_counter()
	if play_sound:
		_UiModifierSounds.play_deselect()
	_refresh_display("", "slide")


func _open_category_list(category_id: String) -> void:
	if search_bar:
		search_bar.text = ""
	_view_mode = ViewMode.LIST
	_list_kind = ListKind.CATEGORY
	_active_category_id = category_id
	_apply_filter_chip_selection()
	_update_nav_visibility()
	_update_list_nav_title()
	_update_counter()
	UiScreenHotkeys.play_section_switch_sound()
	_refresh_display("", "slide")


func _open_full_list(play_sound: bool) -> void:
	if search_bar:
		search_bar.text = ""
	_view_mode = ViewMode.LIST
	_list_kind = ListKind.FULL
	_active_category_id = ""
	_apply_filter_chip_selection()
	_update_nav_visibility()
	_update_list_nav_title()
	_update_counter()
	if play_sound:
		UiScreenHotkeys.play_section_switch_sound()
	_refresh_display("", "slide")


func _update_nav_visibility() -> void:
	var in_list := _view_mode == ViewMode.LIST
	if list_nav_bar:
		list_nav_bar.visible = in_list
	if view_mode_hbox:
		view_mode_hbox.visible = not in_list or _list_kind == ListKind.SEARCH


func _update_list_nav_title() -> void:
	if list_nav_title_label == null:
		return
	match _list_kind:
		ListKind.CATEGORY:
			list_nav_title_label.text = _category_title(_active_category_id)
		ListKind.FULL:
			list_nav_title_label.text = _tr_ui("ACH_VIEW_FULL_LIST")
		ListKind.SEARCH:
			list_nav_title_label.text = _tr_ui("ACH_SEARCH_RESULTS")
		_:
			list_nav_title_label.text = ""


func _category_title(category_id: String) -> String:
	for spec in _CATEGORY_SPECS:
		if String(spec[0]) == category_id:
			return _tr_ui(String(spec[1]))
	return category_id


func _category_accent(category_id: String) -> Color:
	return _ACCENT_BY_CATEGORY.get(category_id, _ACCENT_BY_CATEGORY["default"])


func _refresh_display(query: String, transition: String = "none") -> void:
	var engine := get_parent()
	if engine and engine.has_method("run_async"):
		engine.run_async(_refresh_display_task.bind(query, transition))
	else:
		_refresh_display_task(query, transition)


func _refresh_display_await(query: String, transition: String = "none") -> void:
	await _refresh_display_task(query, transition)


func _refresh_display_task(query: String, transition: String = "none") -> void:
	_filter_task_token += 1
	var task_token := _filter_task_token
	var overlay := _get_loading_overlay()
	var owns_overlay := false
	if overlay and not overlay.is_active():
		overlay.show_loading(tr("UI_LOADING_ACHIEVEMENTS"), true)
		owns_overlay = true
	await get_tree().process_frame
	if task_token != _filter_task_token:
		if owns_overlay and overlay:
			overlay.hide_loading()
		return

	var query_lower := query.strip_edges().to_lower()
	if query_lower != "":
		_view_mode = ViewMode.LIST
		_list_kind = ListKind.SEARCH
		_active_category_id = ""
		_update_nav_visibility()
		_update_list_nav_title()
		var search_results: Array[Dictionary] = []
		var status_filtered := _apply_status_filter(achievements, current_status_filter)
		for ach in status_filtered:
			if not (ach is Dictionary):
				continue
			var title_text := _AchievementLocale.localized_title_strict(ach)
			var desc_text := _AchievementLocale.localized_description_strict(ach)
			if title_text.to_lower().contains(query_lower) or desc_text.to_lower().contains(query_lower):
				search_results.append(ach)
		search_results.sort_custom(Callable(self, "_sort_by_title"))
		_show_list_view(search_results, transition)
	else:
		if _list_kind == ListKind.SEARCH:
			_view_mode = ViewMode.OVERVIEW
			_list_kind = ListKind.FULL
			_active_category_id = ""
			_apply_filter_chip_selection()
		if _view_mode == ViewMode.OVERVIEW:
			_update_nav_visibility()
			_rebuild_overview(transition)
		else:
			_update_nav_visibility()
			_update_list_nav_title()
			var list_items := _build_list_items()
			_show_list_view(list_items, transition)

	await _wait_for_render_idle()
	if task_token != _filter_task_token:
		return
	if owns_overlay and overlay:
		overlay.hide_loading()
	elif overlay and overlay.is_active() and _filter_task_token == task_token:
		overlay.hide_loading()


func _build_list_items() -> Array[Dictionary]:
	match _list_kind:
		ListKind.CATEGORY:
			return _achievements_for_category(_active_category_id, true)
		ListKind.FULL:
			var all_items: Array[Dictionary] = _apply_status_filter(achievements, current_status_filter)
			all_items.sort_custom(Callable(self, "_sort_by_title"))
			return all_items
		_:
			return []


func _rebuild_overview(transition: String) -> void:
	_overview_generation += 1
	var generation := _overview_generation
	if overview_root:
		overview_root.visible = true
	if list_root:
		list_root.visible = false
	_scroll_to_top()

	var rebuild := func() -> void:
		_clear_container(overview_root)
		for spec in _CATEGORY_SPECS:
			if generation != _overview_generation:
				return
			var category_id := String(spec[0])
			var locale_key := String(spec[1])
			var items := _achievements_for_category(category_id, true)
			if items.is_empty():
				continue
			var section := _make_overview_section(category_id, locale_key, items)
			overview_root.add_child(section)

	var skip := _achievements_skip_transition or transition == "none"
	if transition == "crossfade" and achievements_scroll:
		_UiListSlideTransition.crossfade(achievements_scroll, rebuild, skip)
	else:
		rebuild.call()


func _make_overview_section(category_id: String, locale_key: String, items: Array) -> Control:
	var accent := _category_accent(category_id)
	var counts := _category_unlock_counts(category_id)

	var shell := PanelContainer.new()
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var shell_style := StyleBoxFlat.new()
	shell_style.bg_color = Color(0.08, 0.085, 0.12, 0.55)
	shell_style.border_color = Color(accent.r, accent.g, accent.b, 0.35)
	shell_style.set_border_width_all(1)
	shell_style.set_corner_radius_all(14)
	shell_style.content_margin_left = 14.0
	shell_style.content_margin_top = 12.0
	shell_style.content_margin_right = 14.0
	shell_style.content_margin_bottom = 12.0
	shell.add_theme_stylebox_override("panel", shell_style)

	var section_vbox := VBoxContainer.new()
	section_vbox.add_theme_constant_override("separation", 10)
	shell.add_child(section_vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	section_vbox.add_child(header)

	var accent_bar := ColorRect.new()
	accent_bar.custom_minimum_size = Vector2(4, 28)
	accent_bar.color = accent
	header.add_child(accent_bar)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)

	var title := Label.new()
	title.text = _category_title(category_id)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1))
	title_box.add_child(title)

	var progress := Label.new()
	progress.text = _tr_ui("ACH_SECTION_PROGRESS") % [counts.unlocked, counts.total]
	progress.add_theme_font_size_override("font_size", 14)
	progress.add_theme_color_override("font_color", Color(accent.r, accent.g, accent.b, 0.95))
	title_box.add_child(progress)

	var show_all_btn := _create_show_all_button(category_id, accent)
	header.add_child(show_all_btn)
	_UiCategoryButton.apply_selection(show_all_btn, true, 14, true)

	var cards_row := HBoxContainer.new()
	cards_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_row.add_theme_constant_override("separation", 10)
	section_vbox.add_child(cards_row)

	var preview_items := _pick_overview_preview(items)
	for ach in preview_items:
		var card = ACHIEVEMENT_SHELF_CARD_SCENE.instantiate()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_stretch_ratio = 1.0
		cards_row.add_child(card)
		if card.has_method("apply_achievement"):
			card.call_deferred("apply_achievement", ach, accent, achievement_manager)

	return shell


func _create_show_all_button(category_id: String, accent: Color) -> Button:
	var btn := _create_filter_chip(_tr_ui("ACH_SHOW_ALL"), "chevron-right.svg", accent)
	btn.pressed.connect(_open_category_list.bind(category_id))
	return btn


func _show_list_view(items: Array[Dictionary], transition: String) -> void:
	if overview_root:
		overview_root.visible = false
	if list_root:
		list_root.visible = true
	filtered_achievements = items
	_scroll_to_top()

	var rebuild := func() -> void:
		_render_generation += 1
		var generation := _render_generation
		_clear_container(achievements_list)
		if achievements_list:
			achievements_list.visible = false
		_render_cards_chunked(items, generation)

	var skip := _achievements_skip_transition or transition == "none"
	if transition == "slide" and achievements_scroll:
		_UiListSlideTransition.run(achievements_scroll, rebuild, skip)
	elif transition == "crossfade" and achievements_scroll:
		_UiListSlideTransition.crossfade(achievements_scroll, rebuild, skip)
	else:
		rebuild.call()


func _scroll_to_top() -> void:
	if achievements_scroll:
		achievements_scroll.scroll_vertical = 0


func _clear_container(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _wait_for_render_idle() -> void:
	while _render_in_progress:
		await get_tree().process_frame


func _on_back_pressed() -> void:
	if _view_mode != ViewMode.OVERVIEW:
		_go_to_overview(true)
		return
	var parent_node = get_parent()
	var game_engine = null
	if parent_node and parent_node.has_method("prepare_screen_exit"):
		game_engine = parent_node
	elif get_tree().root.has_node("GameEngine"):
		game_engine = get_tree().root.get_node("GameEngine")
	if game_engine and game_engine.has_method("prepare_screen_exit") and game_engine.current_screen == self:
		game_engine.prepare_screen_exit(self)
	cleanup_before_exit()
	MusicManager.play_cancel_sound()
	_execute_close_transition()


func _unhandled_input(event: InputEvent) -> void:
	if UiScreenHotkeys.is_global_loading_active(get_viewport()):
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		if (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo) \
				or event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_on_back_pressed()
		return
	var key_event := event as InputEventKey
	if key_event.keycode == KEY_SLASH and search_bar:
		if not search_bar.has_focus():
			search_bar.grab_focus()
		get_viewport().set_input_as_handled()
		return
	if UiScreenHotkeys.should_block_hotkeys(get_viewport()):
		if key_event.keycode == KEY_ESCAPE or event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_on_back_pressed()
		return
	# Q / W / E — status filters (all / unlocked / locked).
	if key_event.keycode == KEY_Q:
		_on_status_chip_pressed("all")
		get_viewport().set_input_as_handled()
		return
	if key_event.keycode == KEY_W:
		_on_status_chip_pressed("unlocked")
		get_viewport().set_input_as_handled()
		return
	if key_event.keycode == KEY_E:
		_on_status_chip_pressed("locked")
		get_viewport().set_input_as_handled()
		return
	# 1 / 2 — overview / full list.
	if key_event.keycode == KEY_1:
		_on_view_chip_pressed("overview")
		get_viewport().set_input_as_handled()
		return
	if key_event.keycode == KEY_2:
		_on_view_chip_pressed("full")
		get_viewport().set_input_as_handled()
		return
	if key_event.keycode == KEY_ESCAPE or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func cleanup_before_exit() -> void:
	var overlay := _get_loading_overlay()
	if overlay:
		overlay.reset_loading()


func _execute_close_transition() -> void:
	if is_instance_valid(transitions):
		transitions.close_achievements()
	else:
		printerr("AchievementsScreen: transitions (из BaseScreen) не установлен, невозможно закрыть экран достижений.")
	if is_instance_valid(self):
		queue_free()


var _achievements_data_cache = null


func _get_achievements_data():
	if _achievements_data_cache != null:
		return _achievements_data_cache
	var user_path = "user://achievements_data.json"
	var file = FileAccess.open(user_path, FileAccess.READ)
	if not file:
		return null
	var text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if not parsed or not parsed.has("achievements") or not (parsed.achievements is Array):
		return null
	_achievements_data_cache = parsed.achievements
	return _achievements_data_cache


func _render_cards_chunked(achievements_to_display: Array[Dictionary], generation: int) -> void:
	_render_in_progress = true
	var batch_size := _CARD_BATCH_FIRST
	var i := 0
	while i < achievements_to_display.size():
		if generation != _render_generation:
			_render_in_progress = false
			return
		var end := mini(i + batch_size, achievements_to_display.size())
		for j in range(i, end):
			var ach = achievements_to_display[j]
			if not (ach is Dictionary):
				continue
			if not ach.has("title") or ach.title == null:
				continue
			var card = ACHIEVEMENT_CARD_SCENE.instantiate()
			if card is Control:
				(card as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
				(card as Control).size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			achievements_list.add_child(card)
			card.apply_achievement(ach, achievement_manager)
		if achievements_list and not achievements_list.visible:
			achievements_list.visible = true
		if end >= achievements_to_display.size():
			break
		await get_tree().process_frame
		batch_size = _CARD_BATCH
		i = end
	_render_in_progress = false
