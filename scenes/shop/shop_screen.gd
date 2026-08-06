# scenes/shop/shop_screen.gd
extends BaseScreen

const ITEM_CARD_SCENE := preload("res://scenes/shop/components/item_card.tscn")
const COLLECTION_CARD_SCENE := preload("res://scenes/shop/components/shop_collection_card.tscn")
const _ShopItemLocale = preload("res://logic/i18n/shop_item_locale.gd")
const _ShopCollectionLocale = preload("res://logic/i18n/shop_collection_locale.gd")
const _AchievementLocale = preload("res://logic/i18n/achievement_locale.gd")
const SHOP_DATA_USER_PATH := "user://shop_data.json"
const SHOP_DATA_RES_PATH := "res://data/shop_data.json"
const _SpotlightTutorialScene := preload("res://ui/spotlight_tutorial.tscn")
const _UiMotionEffects = preload("res://logic/ui/ui_motion_effects.gd")
const _UiListSlideTransition = preload("res://logic/ui/ui_list_slide_transition.gd")
const _UiCategoryButton = preload("res://logic/ui/ui_category_button.gd")
const _SHOP_ITEM_CELL_HEIGHT := 350

var currency: int = 0
var shop_data: Dictionary = {}
var item_cards: Array[Node] = []
var achievements_data: Dictionary = {} 
var current_category: String = "Все"
var current_collection_filter: String = ""
var _focus_card_index := -1
var _keyboard_nav_active := false

var _scroll_step := 60
var _page_step := 480

const _CATEGORIES_HBOX_PATH := "MainContent/MainVBox/VBoxContainer/CategoryBarPanel/CategoriesHBox"
var _categories_hbox: HBoxContainer = null
const _CATEGORY_BUTTON_SPECS: Array = [
	["Все", "CategoryButtonAll"],
	["Кик", "CategoryButtonKick"],
	["Ноты", "CategoryButtonNotes"],
	["Подсветка линий", "CategoryButtonLaneHighlight"],
	["Частицы хита", "CategoryButtonParticles"],
]
const _CATEGORY_LOCALE_KEYS := {
	"Все": "SHOP_CAT_ALL",
	"Кик": "SHOP_CAT_KICK",
	"Ноты": "SHOP_CAT_NOTES",
	"Подсветка линий": "SHOP_CAT_LANE",
	"Частицы хита": "SHOP_CAT_PARTICLES",
}

const _CATEGORY_DISPLAY_ORDER: Array[String] = [
	"Кик",
	"Ноты",
	"Подсветка линий",
	"Частицы хита",
]

const _CATEGORY_ICON_PAD := 26.0
var _category_badges: Dictionary = {}
var _unseen_reward_stats: Dictionary = {}
var _achievement_title_cache: Dictionary = {}
var _preview_warm_queue: Array = []
var _preview_warming := false
var _kick_waveform_prewarm: AudioWaveformSampler = null
var _sorted_shop_items: Array = []
var _cards_by_item_id: Dictionary = {}
const _INITIAL_CARD_BATCH := 12
const _CARD_SPAWN_PER_FRAME := 4
const _CARD_SPAWN_PER_FRAME_BG := 2
const _PREVIEW_WARM_BATCH := 8
const _KICK_WAVEFORM_BAR_COUNT := 56
var _bg_spawn_generation := 0
var _shop_initializing := false
var _badge_update_queued := false
var _spotlight_tutorial: CanvasLayer = null
var _collection_cards: Array = []

@onready var _items_scroll: ScrollContainer = $MainContent/MainVBox/ContentMargin/ContentHBox/ItemListVBox/ItemsScroll
@onready var _category_bar: PanelContainer = $MainContent/MainVBox/VBoxContainer/CategoryBarPanel

@onready var _back_button: Button = $MainContent/MainVBox/BackButton
@onready var _title_label: Label = $MainContent/MainVBox/TitleLabel
@onready var _unlock_progress_bar: ProgressBar = $MainContent/MainVBox/UnlockProgressBar
@onready var _counter_label: Label = $MainContent/MainVBox/CounterLabel
@onready var _collections_title: Label = $MainContent/MainVBox/CollectionsPanel/CollectionsTitleLabel
@onready var _collections_row: HBoxContainer = $MainContent/MainVBox/CollectionsPanel/CollectionsRow
@onready var _footer_label: Label = $MainContent/MainVBox/FooterLabel


func apply_locale() -> void:
	if _back_button:
		_back_button.text = tr("BTN_BACK")
	if _title_label:
		_title_label.text = tr("SHOP_TITLE")
	if _footer_label:
		_footer_label.text = tr("SHOP_FOOTER_HINT")
	if _collections_title:
		_collections_title.text = tr("SHOP_COLLECTIONS_TITLE")
	_apply_category_button_labels()
	_update_shop_progress_label()
	_update_category_buttons(current_category)
	_sync_all_category_button_layouts()
	for card in item_cards:
		if card and card.has_method("apply_locale"):
			card.apply_locale()
	_refresh_collection_cards_locale()


func _get_categories_hbox() -> HBoxContainer:
	if _categories_hbox and is_instance_valid(_categories_hbox):
		return _categories_hbox
	_categories_hbox = find_child("CategoriesHBox", true, false) as HBoxContainer
	if _categories_hbox == null:
		_categories_hbox = get_node_or_null(_CATEGORIES_HBOX_PATH) as HBoxContainer
	return _categories_hbox

func _load_shop_data() -> Dictionary:
	var data := JsonUtils.read_json_dict(SHOP_DATA_USER_PATH)
	if data.is_empty():
		data = JsonUtils.read_json_dict(SHOP_DATA_RES_PATH)
	else:
		var bundled := JsonUtils.read_json_dict(SHOP_DATA_RES_PATH)
		if not bundled.is_empty():
			var before := JSON.stringify(data)
			data = CatalogDataSync.merge_shop_items(data, bundled)
			# Persist purge of removed covers so stale user:// rows don't linger.
			if before != JSON.stringify(data):
				JsonUtils.write_json(SHOP_DATA_USER_PATH, data, false, true)
	if data.is_empty():
		return {}
	_ensure_collections_in_shop_data(data)
	return data


func _ensure_collections_in_shop_data(data: Dictionary) -> void:
	var bundled := JsonUtils.read_json_dict(SHOP_DATA_RES_PATH)
	var bundled_collections: Variant = bundled.get("collections", [])
	if bundled_collections is Array and not (bundled_collections as Array).is_empty():
		data["collections"] = (bundled_collections as Array).duplicate(true)
	if current_collection_filter == "mushroom":
		current_collection_filter = "sunset"

func _apply_category_button_labels() -> void:
	var hbox := _get_categories_hbox()
	if not hbox:
		return
	for spec in _CATEGORY_BUTTON_SPECS:
		var category := String(spec[0])
		var btn := hbox.get_node_or_null(String(spec[1])) as Button
		if btn and _CATEGORY_LOCALE_KEYS.has(category):
			var locale_key: String = _CATEGORY_LOCALE_KEYS[category]
			var label := tr(locale_key)
			btn.text = category if label == locale_key else label
	_sync_all_category_button_layouts()

func _ready():
	var overlay := _get_loading_overlay()
	if overlay:
		overlay.show_loading(tr("UI_LOADING_SHOP"), true)
	var started_ms := Time.get_ticks_msec()
	var game_engine = get_parent()
	if game_engine and game_engine.has_method("get_transitions"):
		var trans = game_engine.get_transitions()
		setup_managers(trans)  
	else:
		printerr("ShopScreen.gd: Не удалось получить transitions через GameEngine.")

	var user_shop = "user://shop_data.json"
	shop_data = _load_shop_data()
	if shop_data.is_empty():
		printerr("ShopScreen.gd: Файл shop_data.json не найден: ", user_shop)

	currency = PlayerDataManager.get_currency()  
	_update_shop_progress_label()

	var items_scroll = $MainContent/MainVBox/ContentMargin/ContentHBox/ItemListVBox/ItemsScroll
	if items_scroll:
		items_scroll.clip_contents = true

		var items_list_container = items_scroll.get_node("ItemsListContainer")
		if items_list_container:
			var grid_container = items_list_container.get_node("ItemsGridCenter/ItemsGridBottomMargin/ItemsGrid")
			if grid_container:
				grid_container.add_theme_constant_override("v_separation", 30)
				grid_container.add_theme_constant_override("h_separation", 30)

				items_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				items_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

				var item_list_vbox = items_scroll.get_parent()
				if item_list_vbox:
					item_list_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
				var content_hbox = item_list_vbox.get_parent()
				if content_hbox:
					content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
				var content_margin = content_hbox.get_parent()
				if content_margin:
					content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
			else:
				printerr("ShopScreen.gd: ОШИБКА: ItemsGrid НЕ найден внутри ItemsGridBottomMargin.")
		else:
			printerr("ShopScreen.gd: ОШИБКА: ItemsListContainer не найден внутри ItemsScroll.")
	else:
		printerr("ShopScreen.gd: ОШИБКА: ItemsScroll не найден.")

	_sync_achievement_rewards_deferred()
	_apply_category_button_labels()
	_ensure_category_badges()
	_sync_all_category_button_layouts()
	_prepare_shop_badge_stats()
	_build_collection_cards()
	call_deferred("_build_achievement_title_cache")
	if PlayerDataManager.has_signal("shop_new_rewards_changed"):
		PlayerDataManager.shop_new_rewards_changed.connect(_on_shop_new_rewards_changed)
	_restore_shop_category_from_settings()
	_shop_initializing = true
	call_deferred("_preload_shop_category_textures")
	_start_shop_card_build()
	call_deferred("_maybe_show_shop_tutorial")
	print("[Perf] ShopScreen shell ready: %d ms, category=%s" % [Time.get_ticks_msec() - started_ms, current_category])


func _maybe_show_shop_tutorial(force: bool = false) -> void:
	if not SettingsManager or not SettingsManager.has_method("get_tutorial_shop_done"):
		return
	if not force and SettingsManager.get_tutorial_shop_done():
		return
	if _spotlight_tutorial == null:
		_spotlight_tutorial = _SpotlightTutorialScene.instantiate() as CanvasLayer
		if _spotlight_tutorial == null:
			return
		add_child(_spotlight_tutorial)
		if not _spotlight_tutorial.finished.is_connected(_on_shop_tutorial_closed):
			_spotlight_tutorial.finished.connect(_on_shop_tutorial_closed)
		if not _spotlight_tutorial.skipped.is_connected(_on_shop_tutorial_closed):
			_spotlight_tutorial.skipped.connect(_on_shop_tutorial_closed)
	var steps: Array = [
		{
			"title_key": "TUTORIAL_SHOP_1_TITLE",
			"body_key": "TUTORIAL_SHOP_1_BODY",
			"target": _category_bar,
		},
		{
			"title_key": "TUTORIAL_SHOP_2_TITLE",
			"body_key": "TUTORIAL_SHOP_2_BODY",
			"target": _items_scroll,
		},
		{
			"title_key": "TUTORIAL_SHOP_3_TITLE",
			"body_key": "TUTORIAL_SHOP_3_BODY",
			"target": _unlock_progress_bar,
		},
	]
	if _spotlight_tutorial.has_method("start"):
		_spotlight_tutorial.start(steps)


func _on_shop_tutorial_closed() -> void:
	if SettingsManager and SettingsManager.has_method("set_tutorial_shop_done"):
		SettingsManager.set_tutorial_shop_done(true)


func debug_show_tutorial() -> void:
	_maybe_show_shop_tutorial(true)


func _restore_shop_category_from_settings() -> void:
	var saved := String(SettingsManager.get_setting("last_shop_category", "Все"))
	if saved == "Обложки":
		saved = "Все"
	if _is_valid_shop_category(saved):
		current_category = saved
	else:
		current_category = "Все"
	_update_category_buttons(current_category)


func _is_valid_shop_category(category: String) -> bool:
	for spec in _CATEGORY_BUTTON_SPECS:
		if String(spec[0]) == category:
			return true
	return false


func _item_in_shop_category(item: Dictionary, category: String) -> bool:
	if category == "Все":
		return true
	return String(item.get("category", "")) == category


func _item_in_collection_filter(item: Dictionary) -> bool:
	if current_collection_filter == "":
		return true
	return str(item.get("collection_id", "")) == current_collection_filter


func _is_shop_item_unlocked(item: Dictionary) -> bool:
	var item_id := str(item.get("item_id", ""))
	if item_id == "":
		return false
	if PlayerDataManager.is_item_unlocked(item_id):
		return true
	if bool(item.get("is_default", false)):
		return true
	if bool(item.get("is_level_reward", false)):
		var req_level := int(item.get("required_level", 0))
		if PlayerDataManager.get_current_level() >= req_level:
			return true
	if bool(item.get("is_achievement_reward", false)):
		var ach_req_str := str(item.get("achievement_required", ""))
		if ach_req_str != "" and ach_req_str.is_valid_int():
			if PlayerDataManager.is_achievement_unlocked(int(ach_req_str)):
				return true
	if bool(item.get("is_daily_reward", false)):
		var req_daily := int(item.get("required_daily_completed", 0))
		if PlayerDataManager.get_daily_quests_completed_total() >= req_daily:
			return true
	return false


func _visible_item_count_for_category(category: String) -> int:
	var count := 0
	for item_data in _items_for_category(category):
		if item_data is Dictionary and _item_in_collection_filter(item_data):
			count += 1
	return count


func _compute_collection_progress(collection_id: String) -> Dictionary:
	var unlocked := 0
	var total := 0
	var items: Array = shop_data.get("items", [])
	for item_data in items:
		if not (item_data is Dictionary):
			continue
		if str(item_data.get("collection_id", "")) != collection_id:
			continue
		total += 1
		if _is_shop_item_unlocked(item_data):
			unlocked += 1
	return {"unlocked": unlocked, "total": total}


func _build_collection_cards() -> void:
	if _collections_row == null:
		return
	_ensure_collections_in_shop_data(shop_data)
	for child in _collections_row.get_children():
		child.queue_free()
	_collection_cards.clear()
	var collections: Array = _ShopCollectionLocale.collections_from_shop_data(shop_data)
	for entry in collections:
		if not (entry is Dictionary):
			continue
		var card = COLLECTION_CARD_SCENE.instantiate()
		_collections_row.add_child(card)
		var collection_id := str(entry.get("collection_id", ""))
		var stats := _compute_collection_progress(collection_id)
		if card.has_method("setup"):
			card.setup(entry, stats.unlocked, stats.total)
		if card.has_signal("pressed") and not card.pressed.is_connected(_on_collection_pressed):
			card.pressed.connect(_on_collection_pressed)
		if card is Control:
			var ctrl := card as Control
			ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ctrl.size_flags_stretch_ratio = 1.0
		_collection_cards.append(card)
	_update_collection_selection()


func _refresh_collection_cards() -> void:
	for card in _collection_cards:
		if not is_instance_valid(card):
			continue
		var collection_id := ""
		if card.has_method("get_collection_id"):
			collection_id = card.get_collection_id()
		var stats := _compute_collection_progress(collection_id)
		if card.has_method("refresh_progress"):
			card.refresh_progress(stats.unlocked, stats.total)


func _refresh_collection_cards_locale() -> void:
	for card in _collection_cards:
		if is_instance_valid(card) and card.has_method("apply_locale"):
			card.apply_locale()


func _update_collection_selection() -> void:
	for card in _collection_cards:
		if not is_instance_valid(card):
			continue
		var selected := false
		if card.has_method("get_collection_id"):
			selected = card.get_collection_id() == current_collection_filter
		if card.has_method("set_selected"):
			card.set_selected(selected)


func _on_collection_pressed(collection_id: String) -> void:
	if collection_id == "":
		return
	if current_collection_filter == collection_id:
		current_collection_filter = ""
		UiModifierSounds.play_deselect()
	else:
		current_collection_filter = collection_id
		UiScreenHotkeys.play_section_switch_sound()
	_update_collection_selection()
	_apply_category_visibility(current_category)
	var grid_container := _get_items_grid()
	if grid_container:
		_update_grid_min_height(grid_container, _visible_item_count_for_category(current_category))
	_reset_shop_scroll()


func _preload_shop_category_textures() -> void:
	ScreenTexturePreload.warmup_shop_category(current_category, _INITIAL_CARD_BATCH * 2)

func _get_items_grid() -> GridContainer:
	var main_vbox = $MainContent/MainVBox
	if main_vbox:
		return main_vbox.find_child("ItemsGrid", true, false) as GridContainer
	return null

func _sorted_global_index(item_id: String) -> int:
	for i in range(_sorted_shop_items.size()):
		var item = _sorted_shop_items[i]
		if item is Dictionary and String(item.get("item_id", "")) == item_id:
			return i
	return _sorted_shop_items.size()


func _items_for_category(category: String) -> Array:
	var result: Array = []
	for item_data in _sorted_shop_items:
		if item_data is Dictionary and item_data.has("item_id") and _item_in_shop_category(item_data, category):
			result.append(item_data)
	return result

func _pending_items_for_category(category: String) -> Array:
	var result: Array = []
	for item_data in _items_for_category(category):
		var item_id_str := String(item_data.get("item_id", ""))
		if item_id_str != "" and not _cards_by_item_id.has(item_id_str):
			result.append(item_data)
	return result

func _apply_category_visibility(category: String) -> void:
	for card in item_cards:
		if not is_instance_valid(card):
			continue
		var card_category := ""
		var item_dict: Dictionary = {}
		if card.item_data and card.item_data is Dictionary:
			item_dict = card.item_data
			card_category = String(item_dict.get("category", ""))
		var category_match: bool = category == "Все" or card_category == category
		var collection_match: bool = _item_in_collection_filter(item_dict)
		card.visible = category_match and collection_match

func _update_grid_min_height(grid_container: GridContainer, item_count: int) -> void:
	var cols: int = int(grid_container.columns)
	if cols < 1:
		cols = 5
	var rows: int = int(ceil(float(item_count) / float(cols))) if item_count > 0 else 0
	var vs: int = int(grid_container.get_theme_constant("v_separation", "GridContainer"))
	if vs < 0:
		vs = 30
	var scroll_pos := _capture_shop_scroll()
	if rows > 0:
		grid_container.custom_minimum_size.y = float(rows * _SHOP_ITEM_CELL_HEIGHT + max(0, rows - 1) * vs)
	else:
		grid_container.custom_minimum_size.y = 0.0
	call_deferred("_restore_shop_scroll", scroll_pos)

func _reset_shop_scroll() -> void:
	var items_scroll = _get_items_scroll()
	if items_scroll:
		items_scroll.scroll_vertical = 0
		items_scroll.scroll_horizontal = 0

func _get_items_scroll() -> ScrollContainer:
	if _items_scroll and is_instance_valid(_items_scroll):
		return _items_scroll
	return $MainContent/MainVBox/ContentMargin/ContentHBox/ItemListVBox/ItemsScroll as ScrollContainer

func _capture_shop_scroll() -> Vector2i:
	var sc := _get_items_scroll()
	if sc == null:
		return Vector2i.ZERO
	return Vector2i(sc.scroll_horizontal, sc.scroll_vertical)

func _restore_shop_scroll(pos: Vector2i) -> void:
	var sc := _get_items_scroll()
	if sc == null:
		return
	sc.scroll_horizontal = pos.x
	sc.scroll_vertical = pos.y

func _prepare_shop_badge_stats() -> void:
	if _sorted_shop_items.is_empty():
		_sorted_shop_items = _sort_shop_items_for_display(shop_data.get("items", []))
	_unseen_reward_stats = _compute_unseen_reward_stats(_sorted_shop_items)
	_apply_category_badge_counts()

func _on_shop_new_rewards_changed() -> void:
	if _shop_initializing:
		_queue_category_badge_update()
		return
	_update_category_badges()

func _queue_category_badge_update() -> void:
	if _badge_update_queued:
		return
	_badge_update_queued = true
	call_deferred("_flush_queued_category_badge_update")

func _flush_queued_category_badge_update() -> void:
	_badge_update_queued = false
	if not is_inside_tree():
		return
	_update_category_badges()

func _start_shop_card_build() -> void:
	var started_ms := Time.get_ticks_msec()
	var overlay := _get_loading_overlay()
	if overlay and not overlay.is_active():
		overlay.show_loading(tr("UI_LOADING_SHOP"), true)
	await _create_item_cards()
	if overlay:
		overlay.hide_loading()
	_shop_initializing = false
	_flush_queued_category_badge_update()
	_set_buttons_focus_to_none()
	print("[Perf] ShopScreen cards ready: %d ms, cards=%d, category=%s" % [
		Time.get_ticks_msec() - started_ms, item_cards.size(), current_category
	])


func _get_shop_items_container() -> Control:
	if _items_scroll == null:
		return null
	return _items_scroll.get_node_or_null("ItemsListContainer") as Control


func _set_shop_grid_busy(busy: bool) -> void:
	var container := _get_shop_items_container()
	if container:
		container.modulate.a = 0.0 if busy else 1.0
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE if busy else Control.MOUSE_FILTER_PASS


func _sync_achievement_rewards_deferred() -> void:
	call_deferred("_sync_achievement_rewards")


func _sync_achievement_rewards() -> void:
	var game_engine = get_parent()
	if not game_engine or not game_engine.has_method("get_achievement_system"):
		return
	var ach_sys = game_engine.get_achievement_system()
	if not ach_sys or not ach_sys.achievement_manager:
		return
	var am = ach_sys.achievement_manager
	am.check_playtime_achievements(PlayerDataManager)
	am.sync_unlocked_achievements_to_player_data(true)

func _get_currency_label() -> Label:
	var main_vbox = $MainContent/MainVBox
	if main_vbox:
		var v_box_container = main_vbox.get_node_or_null("VBoxContainer")
		if v_box_container:
			var lbl = v_box_container.find_child("CurrencyLabel", true, false)
			if lbl and lbl is Label:
				return lbl
	return null

func _pulse_currency_label() -> void:
	var lbl := _get_currency_label()
	if not lbl:
		return
	lbl.pivot_offset = lbl.size * 0.5
	lbl.scale = Vector2(1.25, 1.25)
	lbl.modulate = Color(1.4, 1.4, 1.4, 1.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate", Color(1, 1, 1, 1), 0.25)


func _hud_currency_global_center() -> Vector2:
	var ge := get_parent()
	while ge and ge.name != "GameEngine":
		ge = ge.get_parent()
	if ge == null:
		ge = get_tree().root.find_child("GameEngine", true, false)
	if ge and ge.has_method("get_currency_hud_global_center"):
		return ge.get_currency_hud_global_center()
	return Vector2.ZERO


func _fly_diamond_after_buy(origin: Vector2) -> void:
	await get_tree().process_frame
	var target := _hud_currency_global_center()
	if origin != Vector2.ZERO:
		_UiMotionEffects.fly_diamond(get_tree(), origin, target)

func _update_shop_progress_label():
	var items = shop_data.get("items", [])
	var total_items = items.size()
	var unlocked = 0
	for item in items:
		var item_id = item.get("item_id", "")
		if item_id == "":
			continue
		var is_unlocked_purchase = PlayerDataManager.is_item_unlocked(item_id)
		var is_default_item = bool(item.get("is_default", false))
		var is_level_reward_item = bool(item.get("is_level_reward", false))
		var is_achievement_reward_item = bool(item.get("is_achievement_reward", false))
		var is_daily_reward_item = bool(item.get("is_daily_reward", false))
		var available_by_level = false
		var available_by_achievement = false
		var available_by_daily = false
		if is_level_reward_item:
			var req_level = int(item.get("required_level", 0))
			available_by_level = PlayerDataManager.get_current_level() >= req_level
		if is_achievement_reward_item:
			var ach_req_str = String(item.get("achievement_required", ""))
			if ach_req_str != "" and ach_req_str.is_valid_int():
				var ach_id = int(ach_req_str)
				available_by_achievement = PlayerDataManager.is_achievement_unlocked(ach_id)
		if is_daily_reward_item:
			var req_daily = int(item.get("required_daily_completed", 0))
			available_by_daily = PlayerDataManager.get_daily_quests_completed_total() >= req_daily
		if is_unlocked_purchase or is_default_item or available_by_level or available_by_achievement or available_by_daily:
			unlocked += 1
	if _counter_label:
		_counter_label.text = tr("SHOP_UNLOCKED") % [unlocked, total_items]
	if _footer_label:
		_footer_label.text = tr("SHOP_FOOTER_HINT")
	if _unlock_progress_bar:
		_unlock_progress_bar.max_value = maxf(float(total_items), 1.0)
		_unlock_progress_bar.value = float(unlocked)
	_refresh_collection_cards()
func _initialize_categories_default():
	_update_category_buttons("Все")
	current_category = "Все"

func _update_category_buttons(selected: String):
	_apply_category_buttons(selected)
	var tree := get_tree()
	if tree:
		tree.create_timer(0.05).timeout.connect(
			func() -> void: _apply_category_buttons(selected),
			CONNECT_ONE_SHOT
		)


func _apply_category_buttons(selected: String) -> void:
	var hbox = _get_categories_hbox()
	if not hbox:
		return
	for spec in _CATEGORY_BUTTON_SPECS:
		var category := String(spec[0])
		var btn := hbox.get_node_or_null(String(spec[1])) as Button
		if btn:
			_UiCategoryButton.apply_selection(btn, selected == category, 14)


func _reset_shop_hover(previous_category: String) -> void:
	var hbox := _get_categories_hbox()
	if hbox:
		for spec in _CATEGORY_BUTTON_SPECS:
			var btn := hbox.get_node_or_null(String(spec[1])) as Button
			_UiCategoryButton.reset_hover_state(btn)
	for card in item_cards:
		if not is_instance_valid(card):
			continue
		var card_category := ""
		if card.item_data and card.item_data is Dictionary:
			card_category = String((card.item_data as Dictionary).get("category", ""))
		if previous_category == "Все" or card_category == previous_category:
			_UiCategoryButton.reset_hover_in_subtree(card)


const _CATEGORY_BTN_HORIZONTAL_PAD := 36.0
const _CATEGORY_BTN_MIN_HEIGHT := 42.0

func _measure_category_button_min_width(btn: Button) -> float:
	var font := btn.get_theme_font("font")
	var font_size := btn.get_theme_font_size("font_size")
	if font == null:
		return 96.0
	var text_size := font.get_string_size(btn.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	return text_size.x + _CATEGORY_BADGE_RESERVE + _CATEGORY_BTN_HORIZONTAL_PAD + _CATEGORY_ICON_PAD

func _sync_category_button_layout(btn: Button) -> void:
	btn.clip_text = false
	btn.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	if not btn.has_meta("_badge_space_reserved"):
		_reserve_category_badge_space(btn)
		btn.set_meta("_badge_space_reserved", true)
	btn.custom_minimum_size = Vector2(_measure_category_button_min_width(btn), _CATEGORY_BTN_MIN_HEIGHT)

func _sync_all_category_button_layouts() -> void:
	var hbox := _get_categories_hbox()
	if not hbox:
		return
	for spec in _CATEGORY_BUTTON_SPECS:
		var btn := hbox.get_node_or_null(String(spec[1])) as Button
		if btn:
			_sync_category_button_layout(btn)

func _compute_unseen_reward_stats(items: Array) -> Dictionary:
	var unseen_ids := PlayerDataManager.get_unseen_shop_reward_ids(items)
	var unseen_set: Dictionary = {}
	for id in unseen_ids:
		unseen_set[id] = true
	var counts: Dictionary = {}
	for spec in _CATEGORY_BUTTON_SPECS:
		counts[spec[0]] = 0
	counts["Все"] = unseen_ids.size()
	for item in items:
		if not item is Dictionary:
			continue
		var item_id := str(item.get("item_id", ""))
		if item_id == "" or not unseen_set.has(item_id):
			continue
		var category := str(item.get("category", ""))
		if counts.has(category):
			counts[category] = int(counts[category]) + 1
	return {"unseen_set": unseen_set, "counts": counts}

const _CATEGORY_BADGE_RESERVE := 32.0

func _reserve_category_badge_space(btn: Button) -> void:
	var hover_override: StyleBox = null
	for style_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var stylebox := btn.get_theme_stylebox(style_name)
		if stylebox == null:
			continue
		var dup := stylebox.duplicate()
		if dup is StyleBoxFlat:
			dup.content_margin_right = maxf(dup.content_margin_right, _CATEGORY_BADGE_RESERVE)
		if style_name == "hover":
			hover_override = dup
		btn.add_theme_stylebox_override(style_name, dup)
	if hover_override:
		btn.add_theme_stylebox_override("focus", hover_override.duplicate())


func _ensure_category_badges() -> void:
	if not _category_badges.is_empty():
		return
	var hbox := _get_categories_hbox()
	if not hbox:
		return
	for spec in _CATEGORY_BUTTON_SPECS:
		var category := String(spec[0])
		var btn := hbox.get_node_or_null(String(spec[1])) as Button
		if not btn:
			continue
		btn.focus_mode = Control.FOCUS_NONE
		if not btn.has_meta("_badge_space_reserved"):
			_reserve_category_badge_space(btn)
			btn.set_meta("_badge_space_reserved", true)
		var badge := btn.get_node_or_null("NewRewardsBadge") as PanelContainer
		var count_label := badge.get_node_or_null("CountLabel") as Label if badge else null
		if badge == null or count_label == null:
			continue
		badge.modulate = Color(1, 1, 1, 0)
		_category_badges[category] = {"panel": badge, "label": count_label}

func _update_category_badges(recompute: bool = true) -> void:
	if _category_badges.is_empty():
		return
	if recompute or _unseen_reward_stats.is_empty():
		var items: Array = _sorted_shop_items if not _sorted_shop_items.is_empty() else shop_data.get("items", [])
		_unseen_reward_stats = _compute_unseen_reward_stats(items)
	_apply_category_badge_counts()

func _apply_category_badge_counts() -> void:
	if _category_badges.is_empty():
		return
	var counts: Dictionary = _unseen_reward_stats.get("counts", {})
	for category in _category_badges.keys():
		var entry: Dictionary = _category_badges[category]
		var badge := entry.get("panel") as PanelContainer
		var count_label := entry.get("label") as Label
		if not badge or not count_label:
			continue
		var count := int(counts.get(category, 0))
		var next_text: String = "99+" if count > 99 else str(count)
		if count <= 0:
			if badge.modulate.a > 0.01:
				badge.modulate = Color(1, 1, 1, 0)
			count_label.text = "0"
		else:
			if badge.modulate.a < 0.99:
				badge.modulate = Color(1, 1, 1, 1)
			if count_label.text != next_text:
				count_label.text = next_text

func _shop_item_category_rank(category: String) -> int:
	var idx := _CATEGORY_DISPLAY_ORDER.find(category)
	return idx if idx >= 0 else _CATEGORY_DISPLAY_ORDER.size()


func _shop_item_is_standard(item: Dictionary) -> bool:
	if bool(item.get("is_default", false)):
		return true
	var item_id := str(item.get("item_id", ""))
	return PlayerDataManager.DEFAULT_UNLOCKED_ITEMS.has(item_id)


## Internal unlock-source order (not a user-facing filter):
## currency → achievements → level → daily → medals.
func _shop_item_unlock_rank(item: Dictionary) -> int:
	if _shop_item_is_standard(item):
		return -1
	if int(item.get("price", 0)) > 0:
		return 0
	if bool(item.get("is_achievement_reward", false)):
		return 1
	if bool(item.get("is_level_reward", false)):
		return 2
	if bool(item.get("is_daily_reward", false)):
		return 3
	if int(item.get("medal_price", 0)) > 0:
		return 4
	return 5


func _sort_shop_items_for_display(items: Array) -> Array:
	var ranked: Array = []
	for orig_idx in items.size():
		var item = items[orig_idx]
		if not (item is Dictionary) or not item.has("item_id"):
			continue
		var category := String(item.get("category", ""))
		ranked.append({
			"standard_block": 0 if _shop_item_is_standard(item) else 1,
			# Keep category sections in «Все» (Kick → Notes → Lane → Particles),
			# then order by unlock source inside each section.
			"rank": _shop_item_category_rank(category),
			"unlock_rank": _shop_item_unlock_rank(item),
			"orig": orig_idx,
			"item": item,
		})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var std_a: int = int(a.get("standard_block", 1))
		var std_b: int = int(b.get("standard_block", 1))
		if std_a != std_b:
			return std_a < std_b
		var rank_a: int = int(a.get("rank", 999))
		var rank_b: int = int(b.get("rank", 999))
		if rank_a != rank_b:
			return rank_a < rank_b
		var unlock_a: int = int(a.get("unlock_rank", 5))
		var unlock_b: int = int(b.get("unlock_rank", 5))
		if unlock_a != unlock_b:
			return unlock_a < unlock_b
		return int(a.get("orig", 0)) < int(b.get("orig", 0))
	)
	var sorted: Array = []
	for entry in ranked:
		sorted.append(entry.get("item"))
	return sorted


func _create_item_cards() -> void:
	var started_ms := Time.get_ticks_msec()
	_bg_spawn_generation += 1
	for card in item_cards:
		card.queue_free()
	item_cards.clear()
	_cards_by_item_id.clear()
	_sorted_shop_items = _sort_shop_items_for_display(shop_data.get("items", []))
	if _unseen_reward_stats.is_empty():
		_unseen_reward_stats = _compute_unseen_reward_stats(_sorted_shop_items)
	else:
		_apply_category_badge_counts()
	var grid_container := _get_items_grid()
	if grid_container == null:
		printerr("ShopScreen.gd: ОШИБКА: ItemsGrid не найден в _create_item_cards")
		return

	var pending := _items_for_category(current_category)
	_update_grid_min_height(grid_container, pending.size())
	var unseen_set: Dictionary = _unseen_reward_stats.get("unseen_set", {})
	if current_category == "Кик" or current_category == "Все":
		await _prewarm_kick_waveforms_async(_kick_items_from_pending(pending))
	await _spawn_cards_progressive(pending, unseen_set, grid_container, _bg_spawn_generation)

	call_deferred("_shop_grid_clear_min_height")
	call_deferred("_apply_shop_ui_interactions")
	print("[Perf] ShopScreen create cards: %d ms, items=%d, category=%s" % [
		Time.get_ticks_msec() - started_ms, item_cards.size(), current_category
	])


func _spawn_cards_progressive(pending: Array, unseen_set: Dictionary, grid_container: GridContainer, generation: int) -> void:
	if pending.is_empty():
		_set_shop_grid_busy(false)
		return
	var hide_until_batch := true
	for card in item_cards:
		if is_instance_valid(card) and card.visible:
			hide_until_batch = false
			break
	if hide_until_batch:
		_set_shop_grid_busy(true)
	var spawned := 0
	var first_batch_cards: Array = []
	for item_data in pending:
		if generation != _bg_spawn_generation:
			return
		if not (item_data is Dictionary) or not item_data.has("item_id"):
			continue
		var before_count := item_cards.size()
		_spawn_shop_card(item_data, unseen_set, grid_container)
		spawned += 1
		if spawned <= _INITIAL_CARD_BATCH:
			first_batch_cards.append(item_cards[before_count])
		if hide_until_batch and spawned == _INITIAL_CARD_BATCH:
			_set_shop_grid_busy(false)
			for card in first_batch_cards:
				_queue_preview_warm(card)
		var frame_budget: int = _CARD_SPAWN_PER_FRAME if spawned <= _INITIAL_CARD_BATCH else _CARD_SPAWN_PER_FRAME_BG
		if spawned % frame_budget == 0:
			var scroll_pos := _capture_shop_scroll()
			await get_tree().process_frame
			if spawned > _INITIAL_CARD_BATCH and scroll_pos.y > 0:
				_restore_shop_scroll(scroll_pos)
	if hide_until_batch and spawned <= _INITIAL_CARD_BATCH:
		_set_shop_grid_busy(false)
		for card in first_batch_cards:
			_queue_preview_warm(card)
	_reorder_shop_grid_to_sorted(grid_container)
	for item_data in pending:
		if generation != _bg_spawn_generation:
			return
		var item_id_str := String(item_data.get("item_id", ""))
		var card: Node = _cards_by_item_id.get(item_id_str)
		if card and not first_batch_cards.has(card):
			_queue_preview_warm(card)
	await _finish_kick_preview_warm(pending, generation)


func _reorder_shop_grid_to_sorted(grid_container: GridContainer) -> void:
	if grid_container == null or _sorted_shop_items.is_empty():
		return
	var desired: Array = []
	for item_data in _sorted_shop_items:
		if not (item_data is Dictionary):
			continue
		var item_id := String(item_data.get("item_id", ""))
		if item_id == "":
			continue
		var card: Node = _cards_by_item_id.get(item_id)
		if card != null and is_instance_valid(card) and card.get_parent() == grid_container:
			desired.append(card)
	for i in desired.size():
		var card: Node = desired[i]
		if grid_container.get_child(i) != card:
			grid_container.move_child(card, i)


func _spawn_card_insert_index(grid_container: GridContainer, item_id_str: String) -> int:
	var insert_idx := 0
	for child in grid_container.get_children():
		if not ("item_data" in child) or not (child.item_data is Dictionary):
			continue
		var child_id := String(child.item_data.get("item_id", ""))
		if _sorted_global_index(child_id) < _sorted_global_index(item_id_str):
			insert_idx += 1
	return insert_idx


func _spawn_shop_card(item_data: Dictionary, unseen_set: Dictionary, grid_container: Node) -> void:
	var new_card = ITEM_CARD_SCENE.instantiate()
	new_card.item_data = item_data
	var item_id_str := String(item_data.get("item_id", ""))
	var is_purchased = PlayerDataManager.is_item_unlocked(item_id_str)
	var is_active = false
	var category_map = _get_category_map()
	var internal_category = category_map.get(String(item_data.get("category", "")), "")
	if internal_category:
		is_active = (PlayerDataManager.get_active_item(internal_category) == item_id_str)
	var achievement_name = ""
	var achievement_unlocked = false
	var level_unlocked = false
	var daily_unlocked = false
	if item_data.get("is_level_reward", false):
		var required_level = item_data.get("required_level", 0)
		level_unlocked = PlayerDataManager.get_current_level() >= int(required_level)
	elif item_data.get("is_achievement_reward", false):
		var achievement_id = item_data.get("achievement_required", "")
		achievement_name = _get_achievement_name_by_id(achievement_id)
		if achievement_id != "" and achievement_id.is_valid_int():
			achievement_unlocked = PlayerDataManager.is_achievement_unlocked(int(achievement_id))
	elif item_data.get("is_daily_reward", false):
		var required_daily = int(item_data.get("required_daily_completed", 0))
		daily_unlocked = PlayerDataManager.get_daily_quests_completed_total() >= required_daily
	new_card.update_state(is_purchased, is_active, true, achievement_unlocked, achievement_name, level_unlocked, daily_unlocked)
	var item_category := String(item_data.get("category", ""))
	var category_match: bool = current_category == "Все" or item_category == current_category
	var collection_match: bool = _item_in_collection_filter(item_data)
	new_card.visible = category_match and collection_match
	var insert_idx := _spawn_card_insert_index(grid_container, item_id_str)
	grid_container.add_child(new_card)
	if insert_idx < grid_container.get_child_count() - 1:
		grid_container.move_child(new_card, insert_idx)
	if new_card.has_method("set_new_reward_highlight"):
		new_card.set_new_reward_highlight(unseen_set.has(item_id_str))
	new_card.buy_pressed.connect(_on_item_buy_pressed)
	if new_card.has_signal("medal_buy_pressed"):
		new_card.medal_buy_pressed.connect(_on_item_medal_buy_pressed)
	new_card.use_pressed.connect(_on_item_use_pressed)
	new_card.preview_pressed.connect(_on_item_preview_pressed)
	item_cards.append(new_card)
	_cards_by_item_id[item_id_str] = new_card


func _ensure_cards_for_category(category: String) -> void:
	if _sorted_shop_items.is_empty():
		return
	var grid_container := _get_items_grid()
	if grid_container == null:
		return
	var pending := _pending_items_for_category(category)
	if pending.is_empty():
		return
	var unseen_set: Dictionary = _unseen_reward_stats.get("unseen_set", {})
	var generation := _bg_spawn_generation
	_update_grid_min_height(grid_container, _visible_item_count_for_category(category))
	if category == "Кик":
		await _prewarm_kick_waveforms_async(_items_for_category(category))
	await _spawn_cards_progressive(pending, unseen_set, grid_container, generation)


func _build_achievement_title_cache() -> void:
	_achievement_title_cache.clear()
	_ensure_achievements_data_loaded()
	var achievements_list = achievements_data.get("achievements", [])
	if not (achievements_list is Array):
		return
	for achievement in achievements_list:
		if not (achievement is Dictionary):
			continue
		var ach_id := str(int(achievement.get("id", -1)))
		if ach_id == "-1":
			continue
		_achievement_title_cache[ach_id] = _AchievementLocale.localized_title(achievement)


func _ensure_achievements_data_loaded() -> void:
	if achievements_data.get("achievements") is Array:
		return
	var game_engine = get_parent()
	if game_engine and game_engine.has_method("get_achievement_system"):
		var ach_sys = game_engine.get_achievement_system()
		if ach_sys and ach_sys.achievement_manager and ach_sys.achievement_manager.achievements.size() > 0:
			achievements_data = {"achievements": ach_sys.achievement_manager.achievements}
			return
	var user_ach := "user://achievements_data.json"
	if not FileAccess.file_exists(user_ach):
		return
	var file_access := FileAccess.open(user_ach, FileAccess.READ)
	if file_access == null:
		return
	var json_result: Variant = JSON.parse_string(file_access.get_as_text())
	file_access.close()
	if json_result is Dictionary:
		achievements_data = json_result


func _queue_preview_warm(card: Node) -> void:
	if card == null or not card.has_method("ensure_preview_fx"):
		return
	var category := ""
	if card.item_data is Dictionary:
		category = str(card.item_data.get("category", ""))
	if category == "Кик":
		if SettingsManager and not SettingsManager.get_shop_kick_waveform_preview():
			return
	elif category != "Частицы хита":
		return
	_preview_warm_queue.append(card)
	if not _preview_warming:
		_preview_warming = true
		call_deferred("_warm_previews_step")


func _warm_previews_step() -> void:
	if _preview_warm_queue.size() == 0:
		_preview_warming = false
		return
	var batch := mini(_PREVIEW_WARM_BATCH, _preview_warm_queue.size())
	for _i in batch:
		var card: Node = _preview_warm_queue.pop_front()
		if is_instance_valid(card) and card.has_method("ensure_preview_fx"):
			card.ensure_preview_fx()
	if _preview_warm_queue.size() > 0:
		await get_tree().process_frame
		_warm_previews_step()
	else:
		_preview_warming = false


func _prewarm_kick_waveforms_async(items: Array) -> void:
	if SettingsManager == null or not SettingsManager.get_shop_kick_waveform_preview():
		return
	if _kick_waveform_prewarm == null:
		_kick_waveform_prewarm = AudioWaveformSampler.new()
	var warmed := 0
	for item in items:
		if not item is Dictionary:
			continue
		if str(item.get("category", "")) != "Кик":
			continue
		var audio_path := str(item.get("audio", ""))
		if audio_path != "" and FileAccess.file_exists(audio_path):
			_kick_waveform_prewarm.analyze_hit_envelope(audio_path, _KICK_WAVEFORM_BAR_COUNT)
			warmed += 1
			if warmed % _PREVIEW_WARM_BATCH == 0:
				await get_tree().process_frame


func _kick_items_from_pending(pending: Array) -> Array:
	var kicks: Array = []
	for item in pending:
		if item is Dictionary and str(item.get("category", "")) == "Кик":
			kicks.append(item)
	return kicks


func _finish_kick_preview_warm(pending: Array, generation: int) -> void:
	if generation != _bg_spawn_generation:
		return
	if SettingsManager == null or not SettingsManager.get_shop_kick_waveform_preview():
		return
	if current_category != "Кик" and current_category != "Все":
		return
	for item_data in pending:
		if generation != _bg_spawn_generation:
			return
		if not item_data is Dictionary or str(item_data.get("category", "")) != "Кик":
			continue
		var card: Node = _cards_by_item_id.get(String(item_data.get("item_id", "")))
		if card and is_instance_valid(card) and card.has_method("ensure_preview_fx"):
			card.ensure_preview_fx()
		await get_tree().process_frame


func _apply_shop_ui_interactions() -> void:
	UiInteractionApplier.apply_from_engine(self)


func _shop_grid_clear_min_height() -> void:
	var main_vbox = $MainContent/MainVBox
	if not main_vbox:
		return
	var grid_container = main_vbox.find_child("ItemsGrid", true, false)
	if grid_container and is_instance_valid(grid_container):
		var scroll_pos := _capture_shop_scroll()
		grid_container.custom_minimum_size.y = 0.0
		call_deferred("_restore_shop_scroll", scroll_pos)


func _get_category_map() -> Dictionary:
	return {
		"Кик": "Kick",
		"Подсветка линий": "LaneHighlight",
		"Ноты": "Notes",
		"Частицы хита": "HitParticles",
	}

func _on_category_selected(category: String):
	if category == current_category:
		_update_category_buttons(category)
		return
	var previous_category := current_category
	_reset_shop_hover(previous_category)
	UiScreenHotkeys.play_section_switch_sound()
	_bg_spawn_generation += 1
	SettingsManager.set_setting("last_shop_category", category)
	SettingsManager.save_settings()
	var container := _get_shop_items_container()
	var apply := func() -> void:
		current_category = category
		_update_category_buttons(category)
		_apply_category_visibility(category)
		_focus_card_index = -1
		_keyboard_nav_active = false
		for card in item_cards:
			if card and card.has_method("set_keyboard_selected"):
				card.set_keyboard_selected(false)
		var grid_container := _get_items_grid()
		if grid_container:
			_update_grid_min_height(grid_container, _visible_item_count_for_category(category))
		_reset_shop_scroll()
	_UiListSlideTransition.crossfade(container, apply, _shop_initializing)
	ScreenTexturePreload.warmup_shop_category(category, _INITIAL_CARD_BATCH * 2)
	var pending := _pending_items_for_category(category)
	if not pending.is_empty():
		var overlay := _get_loading_overlay()
		if overlay:
			overlay.show_loading(tr("UI_LOADING_SHOP"), true)
		await _ensure_cards_for_category(category)
		if overlay:
			overlay.hide_loading()
		_apply_category_visibility(category)
	_reset_shop_scroll()
	call_deferred("_finalize_category_switch")

func _finalize_category_switch() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	_shop_grid_clear_min_height()
	_invalidate_shop_scroll_layout()
	_refresh_visible_shop_previews()

func _invalidate_shop_scroll_layout() -> void:
	var grid_container := _get_items_grid()
	if grid_container:
		grid_container.queue_sort()
		grid_container.update_minimum_size()
	var items_scroll := _get_items_scroll()
	if items_scroll:
		items_scroll.queue_sort()
		call_deferred("_nudge_shop_scroll")

func _nudge_shop_scroll() -> void:
	var items_scroll := _get_items_scroll()
	if items_scroll == null:
		return
	var v := items_scroll.scroll_vertical
	items_scroll.scroll_vertical = v + 1
	items_scroll.scroll_vertical = v

func _refresh_visible_shop_previews() -> void:
	for card in item_cards:
		if not is_instance_valid(card) or not card.visible:
			continue
		if card.has_method("refresh_shop_preview"):
			card.refresh_shop_preview()

func _get_achievement_name_by_id(achievement_id: String) -> String:
	if not achievement_id.is_valid_int():
		return tr("SHOP_UNKNOWN_ACH")
	if _achievement_title_cache.is_empty():
		_build_achievement_title_cache()
	if _achievement_title_cache.has(achievement_id):
		return str(_achievement_title_cache[achievement_id])
	var target_id = float(achievement_id)

	var achievements_list = achievements_data.get("achievements", [])
	for achievement in achievements_list:
		var ach_id_float = achievement.get("id", -1.0)
		if ach_id_float == target_id:
			return _AchievementLocale.localized_title(achievement)
	return tr("SHOP_UNKNOWN_ACH")

func _on_item_buy_pressed(item_id: String):
	var item_data = _find_item_by_id(item_id)
	if item_data:
		if PlayerDataManager.is_item_unlocked(item_id):
			_update_item_card_state(item_id, true, false)
			return

		var price = item_data.get("price", 0)
		var current_currency = PlayerDataManager.get_currency()

		if current_currency >= price:
			var origin := Vector2.ZERO
			if _cards_by_item_id.has(item_id):
				var card = _cards_by_item_id[item_id]
				if card.has_method("get_purchase_fx_origin_global"):
					origin = card.get_purchase_fx_origin_global()
			PlayerDataManager.add_currency(-price)
			PlayerDataManager.unlock_item(item_id)
			
			MusicManager.play_shop_purchase()  
			
			_pulse_currency_label()
			_fly_diamond_after_buy(origin)
			_update_shop_progress_label()
			_update_item_card_state(item_id, true, false)
		else:
			MusicManager.play_default_shop_sound()
			printerr("ShopScreen.gd: Недостаточно валюты для покупки: ", item_id)
	else:
		printerr("ShopScreen.gd: Предмет с ID ", item_id, " не найден в данных магазина.")


func _on_item_medal_buy_pressed(item_id: String) -> void:
	var item_data := _find_item_by_id(item_id)
	if item_data.is_empty():
		printerr("ShopScreen.gd: Предмет с ID ", item_id, " не найден в данных магазина.")
		return
	if PlayerDataManager.is_item_unlocked(item_id):
		_update_item_card_state(item_id, true, false)
		return
	var medal_price := int(item_data.get("medal_price", 0))
	if medal_price <= 0:
		return
	if PlayerDataManager.get_total_medals_earned() >= medal_price:
		PlayerDataManager.unlock_item(item_id)
		PlayerDataManager.mark_shop_reward_seen(item_id)
		_update_shop_progress_label()
		_update_category_badges()
		_update_item_card_state(item_id, true, false)
		for card in item_cards:
			if card.item_data.get("item_id", "") == item_id and card.has_method("set_new_reward_highlight"):
				card.set_new_reward_highlight(false)
				break
	else:
		MusicManager.play_default_shop_sound()
		printerr("ShopScreen.gd: Недостаточно медалей для открытия: ", item_id)


func _is_item_file_available(item_data: Dictionary) -> bool:
	var audio_path = item_data.get("audio", "")
	var image_path = item_data.get("image", "")
	var images_folder = item_data.get("images_folder", "")
	var images_count = item_data.get("images_count", 0)
	if audio_path != "":
		var full_audio_path = audio_path
		if not full_audio_path.begins_with("res://"):
			pass
		if not FileAccess.file_exists(full_audio_path):
			return false
	if image_path != "":
		if not FileAccess.file_exists(image_path):
			return false
	return true

func _on_item_use_pressed(item_id: String):
	var item_data = _find_item_by_id(item_id)
	if item_data:
		var category_map = _get_category_map()
		var internal_category = category_map.get(String(item_data.get("category", "")), "")
		if internal_category:
			PlayerDataManager.set_active_item(internal_category, item_id)
			
			MusicManager.play_shop_apply() 
			
			_update_all_item_cards_in_category(internal_category, item_id)
		else:
			printerr("ShopScreen.gd: Неизвестная категория для предмета: ", item_id)
	else:
		printerr("ShopScreen.gd: Предмет с ID ", item_id, " не найден в данных магазина.")

func _on_item_preview_pressed(item_id: String):
	var item_data = _find_item_by_id(item_id)
	if item_data:
		_preview_sound(item_data)
	else:
		printerr("ShopScreen.gd: Предмет с ID ", item_id, " не найден в данных магазина для предпросмотра.")

func _preview_sound(item: Dictionary):
	var started_ms := Time.get_ticks_msec()
	var audio_path = item.get("audio", "")
	if audio_path != "" and FileAccess.file_exists(audio_path):
		print("ShopScreen.gd: Загрузка предпросмотра звука...")
		MusicManager.play_custom_hit_sound(audio_path)
	else:
		MusicManager.play_default_shop_sound()
	print("[Perf] ShopScreen preview_sound request: %d ms" % [Time.get_ticks_msec() - started_ms])

func cleanup_before_exit():
	var overlay := _get_loading_overlay()
	if overlay:
		overlay.reset_loading()

func _execute_close_transition():
	if transitions:
		transitions.close_shop()
	else:
		printerr("ShopScreen.gd: transitions не установлен, невозможно закрыть магазин через Transitions.")

func _set_buttons_focus_to_none():
	var stack: Array = [self]
	while stack.size() > 0:
		var cur = stack.pop_back()
		for ch in cur.get_children():
			stack.append(ch)
			if ch is Button:
				ch.focus_mode = Control.FOCUS_NONE

func _scroll_to(pos: int):
	var sc = _get_items_scroll()
	if sc:
		var max_val = 0
		if sc.has_method("get_v_scroll_bar"):
			var vbar = sc.get_v_scroll_bar()
			if vbar:
				max_val = int(vbar.max_value)
		sc.scroll_vertical = clamp(pos, 0, max_val if max_val > 0 else pos)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_clear_keyboard_item_focus()


func _unhandled_input(event):
	if UiScreenHotkeys.is_global_loading_active(get_viewport()):
		get_viewport().set_input_as_handled()
		return
	if ((event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE) or event.is_action_pressed("ui_cancel")):
		accept_event()
		_on_back_pressed()
		return
	if not (event is InputEventKey) or not event.pressed:
		return
	var key_event := event as InputEventKey
	var is_nav_key := key_event.keycode in [
		KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_PAGEUP, KEY_PAGEDOWN, KEY_HOME, KEY_END
	]
	if key_event.echo and not is_nav_key:
		return
	if UiScreenHotkeys.should_block_hotkeys(get_viewport()):
		return
	if not key_event.echo and key_event.keycode >= KEY_1 and key_event.keycode <= KEY_5:
		var index := int(key_event.keycode - KEY_1)
		if index < _CATEGORY_BUTTON_SPECS.size():
			_on_category_selected(String(_CATEGORY_BUTTON_SPECS[index][0]))
			accept_event()
			return
	var owner = get_viewport().gui_get_focus_owner()
	if owner and (owner is LineEdit or owner is OptionButton):
		return
	match key_event.keycode:
		KEY_LEFT:
			_move_item_focus(-1)
			accept_event()
			return
		KEY_RIGHT:
			_move_item_focus(1)
			accept_event()
			return
		KEY_SPACE:
			if not key_event.echo:
				_preview_focused_item()
				accept_event()
			return
		KEY_ENTER, KEY_KP_ENTER:
			if not key_event.echo:
				_activate_focused_item()
				accept_event()
			return
	var sc = _get_items_scroll()
	if not sc:
		return
	match key_event.keycode:
		KEY_UP:
			_scroll_to(sc.scroll_vertical - _scroll_step)
			accept_event()
		KEY_DOWN:
			_scroll_to(sc.scroll_vertical + _scroll_step)
			accept_event()
		KEY_PAGEUP:
			_scroll_to(sc.scroll_vertical - _page_step)
			accept_event()
		KEY_PAGEDOWN:
			_scroll_to(sc.scroll_vertical + _page_step)
			accept_event()
		KEY_HOME:
			_scroll_to(0)
			accept_event()
		KEY_END:
			if sc.has_method("get_v_scroll_bar"):
				var vbar = sc.get_v_scroll_bar()
				if vbar:
					_scroll_to(int(vbar.max_value))
					accept_event()
			else:
				_scroll_to(sc.scroll_vertical + 999999)
				accept_event()


func _visible_item_cards() -> Array[Node]:
	var out: Array[Node] = []
	for card in item_cards:
		if card and is_instance_valid(card) and card.visible:
			out.append(card)
	return out


func _clear_keyboard_item_focus() -> void:
	if not _keyboard_nav_active and _focus_card_index < 0:
		return
	_keyboard_nav_active = false
	_focus_card_index = -1
	for card in _visible_item_cards():
		if card and card.has_method("set_keyboard_selected"):
			card.set_keyboard_selected(false)


func _move_item_focus(delta: int) -> void:
	var visible_cards := _visible_item_cards()
	if visible_cards.is_empty():
		_focus_card_index = -1
		_keyboard_nav_active = false
		return
	_keyboard_nav_active = true
	var next := _focus_card_index
	if next < 0 or next >= visible_cards.size():
		next = 0 if delta > 0 else visible_cards.size() - 1
	else:
		next = clampi(next + delta, 0, visible_cards.size() - 1)
	_set_item_focus_index(next, visible_cards, true)


func _set_item_focus_index(index: int, visible_cards: Array[Node] = [], play_sound: bool = false) -> void:
	if visible_cards.is_empty():
		visible_cards = _visible_item_cards()
	if visible_cards.is_empty():
		_focus_card_index = -1
		_keyboard_nav_active = false
		return
	index = clampi(index, 0, visible_cards.size() - 1)
	if play_sound and index != _focus_card_index:
		UiScreenHotkeys.play_section_switch_sound()
	_focus_card_index = index
	_keyboard_nav_active = true
	for i in range(visible_cards.size()):
		var card = visible_cards[i]
		if card and card.has_method("set_keyboard_selected"):
			card.set_keyboard_selected(_keyboard_nav_active and i == _focus_card_index)
	var focused = visible_cards[_focus_card_index]
	var sc = _get_items_scroll()
	if focused is Control and sc:
		sc.ensure_control_visible(focused as Control)


func _preview_focused_item() -> void:
	var visible_cards := _visible_item_cards()
	if _focus_card_index < 0 or _focus_card_index >= visible_cards.size():
		_move_item_focus(1)
		visible_cards = _visible_item_cards()
	if _focus_card_index < 0 or _focus_card_index >= visible_cards.size():
		return
	var card = visible_cards[_focus_card_index]
	if card and card.has_method("activate_preview"):
		card.activate_preview()


func _activate_focused_item() -> void:
	var visible_cards := _visible_item_cards()
	if _focus_card_index < 0 or _focus_card_index >= visible_cards.size():
		_move_item_focus(1)
		visible_cards = _visible_item_cards()
	if _focus_card_index < 0 or _focus_card_index >= visible_cards.size():
		return
	var card = visible_cards[_focus_card_index]
	if card and card.has_method("activate_primary_action"):
		card.activate_primary_action()

func _find_item_by_id(item_id: String) -> Dictionary:
	for item in shop_data.get("items", []):
		if item.get("item_id", "") == item_id:
			return item
	return {}

func _compute_unlock_state(item_data: Dictionary) -> Dictionary:
	var achievement_unlocked = false
	var achievement_name = ""
	var level_unlocked = false
	var daily_unlocked = false
	if item_data.get("is_level_reward", false):
		var required_level = item_data.get("required_level", 0)
		var current_level = PlayerDataManager.get_current_level()
		level_unlocked = current_level >= required_level
	elif item_data.get("is_achievement_reward", false):
		var achievement_id_str = item_data.get("achievement_required", "")
		if achievement_id_str != "" and achievement_id_str.is_valid_int():
			var achievement_id = int(achievement_id_str)
			achievement_unlocked = PlayerDataManager.is_achievement_unlocked(achievement_id)
			achievement_name = _get_achievement_name_by_id(achievement_id_str)
	elif item_data.get("is_daily_reward", false):
		var required_daily = int(item_data.get("required_daily_completed", 0))
		var total_completed = PlayerDataManager.get_daily_quests_completed_total()
		daily_unlocked = total_completed >= required_daily
	return {
		"achievement_unlocked": achievement_unlocked,
		"achievement_name": achievement_name,
		"level_unlocked": level_unlocked,
		"daily_unlocked": daily_unlocked
	}

func _update_item_card_state(item_id: String, purchased: bool, active: bool):
	for card in item_cards:
		if card.item_data.get("item_id", "") == item_id:
			var st = _compute_unlock_state(card.item_data)
			card.update_state(purchased, active, true, st.achievement_unlocked, st.achievement_name, st.level_unlocked, st.daily_unlocked)
			break

func _update_all_item_cards_in_category(category: String, active_item_id: String):
	for card in item_cards:
		var category_map = _get_category_map()
		var internal_category = category_map.get(String(card.item_data.get("category", "")), "")
		if internal_category == category:
			var is_purchased = PlayerDataManager.is_item_unlocked(String(card.item_data.get("item_id", "")))
			var is_active = (String(card.item_data.get("item_id", "")) == active_item_id)
			var st = _compute_unlock_state(card.item_data)
			card.update_state(is_purchased, is_active, true, st.achievement_unlocked, st.achievement_name, st.level_unlocked, st.daily_unlocked)

func _exit_tree():
	pass
