# scenes/shop/shop_screen.gd
extends BaseScreen

var currency: int = 0
var shop_data: Dictionary = {}
var item_cards: Array[Node] = []
var achievements_data: Dictionary = {} 

var current_cover_gallery: Node = null
var current_cover_item_data: Dictionary = {}

func _ready():
	var game_engine = get_parent()
	if game_engine and game_engine.has_method("get_transitions"):
		var trans = game_engine.get_transitions()
		setup_managers(trans)  
	else:
		printerr("ShopScreen.gd: Не удалось получить transitions через GameEngine.")

	var file_path = "res://data/shop_data.json"
	var file_access = FileAccess.open(file_path, FileAccess.READ)
	if file_access:
		var json_text = file_access.get_as_text()
		file_access.close()
		var json_result = JSON.parse_string(json_text)
		if json_result is Dictionary:
			shop_data = json_result
		else:
			print("ShopScreen.gd: Ошибка парсинга JSON или данные не являются словарём.")
	else:
		print("ShopScreen.gd: Файл shop_data.json не найден: ", file_path)

	var achievements_file_path = "res://data/achievements_data.json"
	var achievements_file_access = FileAccess.open(achievements_file_path, FileAccess.READ)
	if achievements_file_access:
		var json_text = achievements_file_access.get_as_text()
		achievements_file_access.close()
		var json_result = JSON.parse_string(json_text)
		if json_result is Dictionary:
			achievements_data = json_result
		else:
			print("ShopScreen.gd: Ошибка парсинга achievements_data.json или данные не являются словарём.")
	else:
		print("ShopScreen.gd: Файл achievements_data.json не найден: ", achievements_file_path)

	currency = PlayerDataManager.get_currency()  
	_update_currency_label()

	_connect_category_buttons()
	_connect_back_button()

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
				print("ShopScreen.gd: ОШИБКА: ItemsGrid НЕ найден внутри ItemsGridBottomMargin.")
		else:
			print("ShopScreen.gd: ОШИБКА: ItemsListContainer не найден внутри ItemsScroll.")
	else:
		print("ShopScreen.gd: ОШИБКА: ItemsScroll не найден.")

	_create_item_cards()

func _update_currency_label():
	var main_vbox = $MainContent/MainVBox
	if main_vbox:
		var v_box_container = main_vbox.get_node("VBoxContainer")
		if v_box_container:
			var currency_label = v_box_container.get_node("CurrencyLabel")
			if currency_label:
				currency_label.text = "💰 Валюта: %d" % PlayerDataManager.get_currency() 
			else:
				print("ShopScreen.gd: ОШИБКА: CurrencyLabel НЕ найден внутри VBoxContainer.")
		else:
			print("ShopScreen.gd: ОШИБКА: VBoxContainer НЕ найден внутри MainVBox.")
	else:
		print("ShopScreen.gd: ОШИБКА: MainVBox НЕ найден по пути $MainContent/MainVBox.")

func _connect_category_buttons():
	var all_btn = $MainContent/MainVBox/VBoxContainer/CategoriesHBox/CategoryButtonAll
	var kick_btn = $MainContent/MainVBox/VBoxContainer/CategoriesHBox/CategoryButtonKick
	var snare_btn = $MainContent/MainVBox/VBoxContainer/CategoriesHBox/CategoryButtonSnare
	var cover_btn = $MainContent/MainVBox/VBoxContainer/CategoriesHBox/CategoryButtonCover
	var lane_highlight_btn = $MainContent/MainVBox/VBoxContainer/CategoriesHBox/CategoryButtonLaneHighlight  
	var notes_btn = $MainContent/MainVBox/VBoxContainer/CategoriesHBox/CategoryButtonNotes
	var misc_btn = $MainContent/MainVBox/VBoxContainer/CategoriesHBox/CategoryButtonMisc

	if all_btn:
		all_btn.pressed.connect(_on_category_selected.bind("Все"))
	if kick_btn:
		kick_btn.pressed.connect(_on_category_selected.bind("Кик"))
	if snare_btn:
		snare_btn.pressed.connect(_on_category_selected.bind("Снейр"))
	if cover_btn:
		cover_btn.pressed.connect(_on_category_selected.bind("Обложки"))
	if lane_highlight_btn:  
		lane_highlight_btn.pressed.connect(_on_category_selected.bind("Подсветка линий"))
	if notes_btn:
		notes_btn.pressed.connect(_on_category_selected.bind("Ноты"))
	if misc_btn:
		misc_btn.pressed.connect(_on_category_selected.bind("Прочее"))
	_update_category_buttons("Все")
		
func _connect_back_button():
	var back_button = $MainContent/MainVBox/BackButton
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	else:
		printerr("ShopScreen.gd: Кнопка BackButton не найдена по пути $MainContent/MainVBox/BackButton!")

func _update_category_buttons(selected: String):
	var hbox = $MainContent/MainVBox/VBoxContainer/CategoriesHBox
	if not hbox:
		return
	var all_btn: Button = hbox.get_node("CategoryButtonAll")
	var kick_btn: Button = hbox.get_node("CategoryButtonKick")
	var snare_btn: Button = hbox.get_node("CategoryButtonSnare")
	var cover_btn: Button = hbox.get_node("CategoryButtonCover")
	var notes_btn: Button = hbox.get_node("CategoryButtonNotes")
	var lane_btn: Button = hbox.get_node("CategoryButtonLaneHighlight")
	var misc_btn: Button = hbox.get_node("CategoryButtonMisc")
	if all_btn: all_btn.theme_type_variation = "ActiveAll" if selected == "Все" else "CategoryAll"
	if kick_btn: kick_btn.theme_type_variation = "ActiveKick" if selected == "Кик" else "CategoryKick"
	if snare_btn: snare_btn.theme_type_variation = "ActiveSnare" if selected == "Снейр" else "CategorySnare"
	if cover_btn: cover_btn.theme_type_variation = "ActiveCover" if selected == "Обложки" else "CategoryCover"
	if notes_btn: notes_btn.theme_type_variation = "ActiveNotes" if selected == "Ноты" else "CategoryNotes"
	if lane_btn: lane_btn.theme_type_variation = "ActiveLane" if selected == "Подсветка линий" else "CategoryLane"
	if misc_btn: misc_btn.theme_type_variation = "ActiveMisc" if selected == "Прочее" else "CategoryMisc"

func _create_item_cards():
	for card in item_cards:
		card.queue_free()
	item_cards.clear()

	var items = shop_data.get("items", [])
	var item_card_scene = preload("res://scenes/shop/item_card.tscn")

	var grid_container = $MainContent/MainVBox/ContentMargin/ContentHBox/ItemListVBox/ItemsScroll/ItemsListContainer/ItemsGridCenter/ItemsGridBottomMargin/ItemsGrid
	if not grid_container:
		print("ShopScreen.gd: ОШИБКА: ItemsGrid не найден в _create_item_cards")
		return

	for i in range(items.size()):
		var item_data = items[i]
		var new_card = item_card_scene.instantiate()
		new_card.item_data = item_data

		var is_purchased = PlayerDataManager.is_item_unlocked(item_data.item_id)  
		var is_active = false
		var category_map = _get_category_map()
		var internal_category = category_map.get(item_data.category, "")
		if internal_category:
			is_active = (PlayerDataManager.get_active_item(internal_category) == item_data.item_id)  

		var achievement_name = ""
		var achievement_unlocked = false
		var level_unlocked = false

		if item_data.get("is_level_reward", false):
			var required_level = item_data.get("required_level", 0)
			var current_level = PlayerDataManager.get_current_level()  
			level_unlocked = current_level >= required_level
		elif item_data.get("is_achievement_reward", false):
			var achievement_id = item_data.get("achievement_required", "")
			achievement_name = _get_achievement_name_by_id(achievement_id)
			if achievement_id != "" and achievement_id.is_valid_int():
				achievement_unlocked = PlayerDataManager.is_achievement_unlocked(int(achievement_id)) 

		new_card.update_state(is_purchased, is_active, true, achievement_unlocked, achievement_name, level_unlocked)

		new_card.buy_pressed.connect(_on_item_buy_pressed)
		new_card.use_pressed.connect(_on_item_use_pressed)
		new_card.preview_pressed.connect(_on_item_preview_pressed)
		new_card.cover_click_pressed.connect(_on_cover_click_pressed)

		grid_container.add_child(new_card)
		item_cards.append(new_card)

	var items_scroll = $MainContent/MainVBox/ContentMargin/ContentHBox/ItemListVBox/ItemsScroll
	if items_scroll:
		items_scroll.scroll_vertical = 0
		items_scroll.scroll_horizontal = 0

func _get_category_map() -> Dictionary:
	return {
		"Кик": "Kick",
		"Снейр": "Snare",
		"Обложки": "Covers",
		"Подсветка линий": "LaneHighlight",
		"Ноты": "Notes",
		"Прочее": "Misc"
	}

func _on_category_selected(category: String):
	for card in item_cards:
		card.queue_free()
	item_cards.clear()

	var filtered_items = []
	for item in shop_data.get("items", []):
		if category == "Все" or item.category == category:
			filtered_items.append(item)

	var grid_container = $MainContent/MainVBox/ContentMargin/ContentHBox/ItemListVBox/ItemsScroll/ItemsListContainer/ItemsGridCenter/ItemsGridBottomMargin/ItemsGrid
	if not grid_container:
		print("ShopScreen.gd: ОШИБКА: ItemsGrid не найден в _on_category_selected")
		return

	for i in range(filtered_items.size()):
		var item_data = filtered_items[i]
		var new_card = preload("res://scenes/shop/item_card.tscn").instantiate()
		new_card.item_data = item_data

		var is_purchased = PlayerDataManager.is_item_unlocked(item_data.item_id)
		var is_active = false
		var category_map = _get_category_map()
		var internal_category = category_map.get(item_data.category, "")
		if internal_category:
			is_active = (PlayerDataManager.get_active_item(internal_category) == item_data.item_id)

		var achievement_name = ""
		var achievement_unlocked = false
		var level_unlocked = false

		if item_data.get("is_level_reward", false):
			var required_level = item_data.get("required_level", 0)
			var current_level = PlayerDataManager.get_current_level()
			level_unlocked = current_level >= required_level
		elif item_data.get("is_achievement_reward", false):
			var achievement_id = item_data.get("achievement_required", "")
			achievement_name = _get_achievement_name_by_id(achievement_id)
			if achievement_id != "" and achievement_id.is_valid_int():
				achievement_unlocked = PlayerDataManager.is_achievement_unlocked(int(achievement_id))

		new_card.update_state(is_purchased, is_active, true, achievement_unlocked, achievement_name, level_unlocked)

		new_card.buy_pressed.connect(_on_item_buy_pressed)
		new_card.use_pressed.connect(_on_item_use_pressed)
		new_card.preview_pressed.connect(_on_item_preview_pressed)
		new_card.cover_click_pressed.connect(_on_cover_click_pressed)

		grid_container.add_child(new_card)
		item_cards.append(new_card)

	_update_category_buttons(category)

	var items_scroll = $MainContent/MainVBox/ContentMargin/ContentHBox/ItemListVBox/ItemsScroll
	if items_scroll:
		items_scroll.scroll_vertical = 0
		items_scroll.scroll_horizontal = 0

func _get_achievement_name_by_id(achievement_id: String) -> String:
	if not achievement_id.is_valid_int():
		return "Неизвестная ачивка"
	var target_id = float(achievement_id)

	var achievements_list = achievements_data.get("achievements", [])
	for achievement in achievements_list:
		var ach_id_float = achievement.get("id", -1.0)
		if ach_id_float == target_id:
			var title = achievement.get("title", "Неизвестная ачивка")
			return title
	return "Неизвестная ачивка"

func _on_item_buy_pressed(item_id: String):
	var item_data = _find_item_by_id(item_id)
	if item_data:
		var price = item_data.get("price", 0)
		var current_currency = PlayerDataManager.get_currency()

		if current_currency >= price:
			PlayerDataManager.add_currency(-price)
			PlayerDataManager.unlock_item(item_id)
			
			MusicManager.play_shop_purchase()  
			
			_update_currency_label()
			_update_item_card_state(item_id, true, false)
		else:
			print("ShopScreen.gd: Недостаточно валюты для покупки: ", item_id)
	else:
		print("ShopScreen.gd: Предмет с ID ", item_id, " не найден в данных магазина.")

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
	if images_folder != "" and images_count > 0:
		var cover_exists = false
		for i in range(1, images_count + 1):
			var cover_path = images_folder + "/cover%d.png" % i
			if FileAccess.file_exists(cover_path):
				cover_exists = true
				break
		if not cover_exists:
			return false
	return true

func _on_item_use_pressed(item_id: String):
	var item_data = _find_item_by_id(item_id)
	if item_data:
		var category_map = _get_category_map()
		var internal_category = category_map.get(item_data.category, "")
		if internal_category:
			PlayerDataManager.set_active_item(internal_category, item_id)
			
			MusicManager.play_shop_apply() 
			
			_update_all_item_cards_in_category(internal_category, item_id)
		else:
			print("ShopScreen.gd: Неизвестная категория для предмета: ", item_id)
	else:
		print("ShopScreen.gd: Предмет с ID ", item_id, " не найден в данных магазина.")

func _on_item_preview_pressed(item_id: String):
	var item_data = _find_item_by_id(item_id)
	if item_data:
		_preview_sound(item_data)
	else:
		print("ShopScreen.gd: Предмет с ID ", item_id, " не найден в данных магазина для предпросмотра.")

func _preview_sound(item: Dictionary):
	var audio_path = item.get("audio", "")
	if audio_path != "" and FileAccess.file_exists(audio_path):
		MusicManager.play_custom_hit_sound(audio_path)
	else:
		MusicManager.play_default_shop_sound()

func _on_cover_click_pressed(item_data: Dictionary):
	MusicManager.play_cover_click_sound()
	_open_cover_gallery(item_data)

func _open_cover_gallery(item_data: Dictionary):
	if current_cover_gallery:
		if is_instance_valid(current_cover_gallery):
			current_cover_gallery.queue_free()
		current_cover_item_data = {}

	current_cover_item_data = item_data

	var gallery_scene = preload("res://scenes/shop/cover_gallery.tscn")
	current_cover_gallery = gallery_scene.instantiate()

	current_cover_gallery.images_folder = item_data.get("images_folder", "")
	current_cover_gallery.images_count = item_data.get("images_count", 0)

	current_cover_gallery.connect("gallery_closed", _on_gallery_closed, CONNECT_ONE_SHOT)
	current_cover_gallery.connect("cover_selected", _on_cover_selected_stub, CONNECT_ONE_SHOT)

	if is_instance_valid(self) and not is_queued_for_deletion() and is_inside_tree() and is_instance_valid(current_cover_gallery):
		call_deferred("_deferred_add_child", current_cover_gallery)
	else:
		if is_instance_valid(current_cover_gallery):
			current_cover_gallery.queue_free()
		current_cover_item_data = {}

func _deferred_add_child(gallery_node: Node):
	if is_instance_valid(self) and not is_queued_for_deletion() and is_inside_tree() and is_instance_valid(gallery_node):
		add_child(gallery_node)
		gallery_node.grab_focus()
	else:
		if is_instance_valid(gallery_node):
			gallery_node.queue_free()
		if current_cover_gallery == gallery_node:
			current_cover_gallery = null
		current_cover_item_data = {}

func _on_cover_selected_stub(index: int):
	pass

func _on_gallery_closed():
	if is_instance_valid(current_cover_gallery):
		if current_cover_gallery.is_connected("gallery_closed", _on_gallery_closed):
			current_cover_gallery.disconnect("gallery_closed", _on_gallery_closed)
		if current_cover_gallery.is_connected("cover_selected", _on_cover_selected_stub):
			current_cover_gallery.disconnect("cover_selected", _on_cover_selected_stub)
		current_cover_gallery = null
	current_cover_item_data = {}

func _on_cover_selected(index: int):
	print("ShopScreen.gd: Выбрана обложка %d из пака '%s'." % [index, current_cover_item_data.get("name", "Без названия")])

func cleanup_before_exit():
	_cleanup_gallery_internal()

func _execute_close_transition():
	if transitions:
		transitions.close_shop()
	else:
		printerr("ShopScreen.gd: transitions не установлен, невозможно закрыть магазин через Transitions.")

func _find_item_by_id(item_id: String) -> Dictionary:
	for item in shop_data.get("items", []):
		if item.get("item_id", "") == item_id:
			return item
	return {}

func _update_item_card_state(item_id: String, purchased: bool, active: bool):
	for card in item_cards:
		if card.item_data.get("item_id", "") == item_id:
			var achievement_unlocked = false
			var achievement_name = ""
			var level_unlocked = false
			var item_data = card.item_data 
			
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
			
			card.update_state(purchased, active, true, achievement_unlocked, achievement_name, level_unlocked)
			break

func _update_all_item_cards_in_category(category: String, active_item_id: String):
	for card in item_cards:
		var category_map = _get_category_map()
		var internal_category = category_map.get(card.item_data.category, "")
		if internal_category == category:
			var is_purchased = PlayerDataManager.is_item_unlocked(card.item_data.item_id)
			var is_active = (card.item_data.item_id == active_item_id)
			
			var achievement_unlocked = false
			var achievement_name = ""
			var level_unlocked = false
			var item_data = card.item_data
			
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
			
			card.update_state(is_purchased, is_active, true, achievement_unlocked, achievement_name, level_unlocked)

func _cleanup_gallery_internal():
	if current_cover_gallery:
		if is_instance_valid(current_cover_gallery):
			if current_cover_gallery.is_connected("gallery_closed", _on_gallery_closed):
				current_cover_gallery.disconnect("gallery_closed", _on_gallery_closed)
			if current_cover_gallery.is_connected("cover_selected", _on_cover_selected_stub):
				current_cover_gallery.disconnect("cover_selected", _on_cover_selected_stub)
		if is_instance_valid(current_cover_gallery):
			current_cover_gallery.queue_free()
		current_cover_gallery = null
		current_cover_item_data = {}

func _exit_tree():
	_cleanup_gallery_internal()
