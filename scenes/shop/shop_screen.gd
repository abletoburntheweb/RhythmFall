# scenes/shop/shop_screen.gd
extends Control

var currency: int = 0
var shop_data: Dictionary = {}
var item_cards: Array[Node] = []

var current_cover_gallery: Node = null
var current_cover_item_data: Dictionary = {}

var player_data_manager: PlayerDataManager = null
var music_manager = null
var transitions = null


func _ready():
	print("ShopScreen.gd: _ready вызван.")

	player_data_manager = PlayerDataManager.new()
	var game_engine = get_parent()
	if game_engine and game_engine.has_method("get_music_manager"):
		music_manager = game_engine.get_music_manager()
		print("ShopScreen.gd: MusicManager получен через GameEngine.")
	else:
		printerr("ShopScreen.gd: MusicManager не найден через GameEngine.")

	if game_engine and game_engine.has_method("get_transitions"):
		transitions = game_engine.get_transitions()
		print("ShopScreen.gd: Transitions получен через GameEngine.")
	else:
		printerr("ShopScreen.gd: Transitions не найден через GameEngine.")

	var file_path = "res://data/shop_data.json"
	var file_access = FileAccess.open(file_path, FileAccess.READ)
	if file_access:
		var json_text = file_access.get_as_text()
		file_access.close()
		var json_result = JSON.parse_string(json_text)
		if json_result is Dictionary:
			shop_data = json_result
			print("ShopScreen.gd: Данные магазина загружены успешно.")
		else:
			print("ShopScreen.gd: Ошибка парсинга JSON или данные не являются словарём.")
	else:
		print("ShopScreen.gd: Файл shop_data.json не найден: ", file_path)

	currency = player_data_manager.get_currency()
	_update_currency_label()

	_connect_category_buttons()
	_connect_back_button()

	var items_scroll = $MainContent/MainVBox/ContentMargin/ContentHBox/ItemListVBox/ItemsScroll
	if items_scroll:
		print("ShopScreen.gd: ItemsScroll найден.")
		items_scroll.clip_contents = true

		var items_list_container = items_scroll.get_node("ItemsListContainer")
		if items_list_container:
			print("ShopScreen.gd: ItemsListContainer найден.")

			var grid_container = items_list_container.get_node("ItemsGridCenter/ItemsGridBottomMargin/ItemsGrid")
			if grid_container:
				print("ShopScreen.gd: ItemsGrid найден по новому пути $MainContent/MainVBox/ContentMargin/ContentHBox/ItemListVBox/ItemsScroll/ItemsListContainer/ItemsGridCenter/ItemsGridBottomMargin/ItemsGrid")

				grid_container.add_theme_constant_override("v_separation", 30)
				grid_container.add_theme_constant_override("h_separation", 30)

				items_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				items_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

				var item_list_vbox = items_scroll.get_parent()
				if item_list_vbox:
					print("ShopScreen.gd: Устанавливаю size_flags_vertical для ItemListVBox")
					item_list_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
				else:
					print("ShopScreen.gd: ОШИБКА: ItemListVBox не найден как родитель ItemsScroll.")

				var content_hbox = item_list_vbox.get_parent()
				if content_hbox:
					print("ShopScreen.gd: Устанавливаю size_flags_vertical для ContentHBox")
					content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
				else:
					print("ShopScreen.gd: ОШИБКА: ContentHBox не найден как родитель ItemListVBox.")

				var content_margin = content_hbox.get_parent()
				if content_margin:
					print("ShopScreen.gd: Устанавливаю size_flags_vertical для ContentMargin")
					content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
				else:
					print("ShopScreen.gd: ОШИБКА: ContentMargin не найден как родитель ContentHBox.")

			else:
				print("ShopScreen.gd: ОШИБКА: ItemsGrid НЕ найден внутри ItemsGridBottomMargin.")
		else:
			print("ShopScreen.gd: ОШИБКА: ItemsListContainer не найден внутри ItemsScroll.")
	else:
		print("ShopScreen.gd: ОШИБКА: ItemsScroll не найден.")

	_create_item_cards()

func _update_currency_label():
	print("ShopScreen.gd: Попытка найти CurrencyLabel по пути: $MainContent/MainVBox/VBoxContainer/CurrencyLabel")
	var main_vbox = $MainContent/MainVBox
	if main_vbox:
		print("ShopScreen.gd: MainVBox найден.")
		var v_box_container = main_vbox.get_node("VBoxContainer")
		if v_box_container:
			print("ShopScreen.gd: VBoxContainer найден.")
			var currency_label = v_box_container.get_node("CurrencyLabel")
			if currency_label:
				print("ShopScreen.gd: CurrencyLabel найден по пути $MainContent/MainVBox/VBoxContainer/CurrencyLabel")
				currency_label.text = "💰 Валюта: %d" % player_data_manager.get_currency()
				currency_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
				currency_label.add_theme_font_size_override("font_size", 32)
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
	var misc_btn = $MainContent/MainVBox/VBoxContainer/CategoriesHBox/CategoryButtonMisc

	if all_btn:
		all_btn.pressed.connect(_on_category_selected.bind("Все"))
		_set_category_button_style(all_btn, true)
	if kick_btn:
		kick_btn.pressed.connect(_on_category_selected.bind("Кик"))
		_set_category_button_style(kick_btn, false)
	if snare_btn:
		snare_btn.pressed.connect(_on_category_selected.bind("Снейр"))
		_set_category_button_style(snare_btn, false)
	if cover_btn:
		cover_btn.pressed.connect(_on_category_selected.bind("Обложки"))
		_set_category_button_style(cover_btn, false)
	if misc_btn:
		misc_btn.pressed.connect(_on_category_selected.bind("Прочее"))
		_set_category_button_style(misc_btn, false)
func _connect_back_button():
	var back_button = $MainContent/MainVBox/BackButton
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
		print("ShopScreen.gd: Подключён сигнал pressed кнопки Назад.")
	else:
		printerr("ShopScreen.gd: Кнопка BackButton не найдена по пути $MainContent/MainVBox/BackButton!")

func _set_category_button_style(button: Button, is_all: bool):
	if is_all:
		button.self_modulate = Color(1.0, 0.84, 0.0)
		button.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0))
	else:
		button.self_modulate = Color(0.0, 0.0, 0.0, 0.3)
		button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))

func _create_item_cards():
	for card in item_cards:
		card.queue_free()
	item_cards.clear()

	var items = shop_data.get("items", [])
	print("ShopScreen.gd: Найдено предметов: ", items.size())

	var item_card_scene = preload("res://scenes/shop/item_card.tscn")

	var main_content = $MainContent
	if main_content:
		var main_vbox = main_content.get_node("MainVBox")
		if main_vbox:
			var content_margin = main_vbox.get_node("ContentMargin")
			if content_margin:
				var content_hbox = content_margin.get_node("ContentHBox")
				if content_hbox:
					var item_list_vbox = content_hbox.get_node("ItemListVBox")
					if item_list_vbox:
						var items_scroll = item_list_vbox.get_node("ItemsScroll")
						if items_scroll:
							var items_list_container = items_scroll.get_node("ItemsListContainer")
							if items_list_container:
								print("ShopScreen.gd: ItemsListContainer найден.")
								var grid_container = items_list_container.get_node("ItemsGridCenter/ItemsGridBottomMargin/ItemsGrid")
								if grid_container:
									print("ShopScreen.gd: ItemsGrid найден по новому пути $MainContent/MainVBox/ContentMargin/ContentHBox/ItemListVBox/ItemsScroll/ItemsListContainer/ItemsGridCenter/ItemsGridBottomMargin/ItemsGrid")

									grid_container.add_theme_constant_override("v_separation", 30)
									grid_container.add_theme_constant_override("h_separation", 30)

									for i in range(items.size()):
										var item_data = items[i]

										var new_card = item_card_scene.instantiate()

										new_card.item_data = item_data

										var is_purchased = player_data_manager.is_item_unlocked(item_data.item_id)
										var is_active = false
										var category_map = _get_category_map()
										var internal_category = category_map.get(item_data.category, "")
										if internal_category:
											is_active = (player_data_manager.get_active_item(internal_category) == item_data.item_id)

										new_card.update_state(is_purchased, is_active)

										new_card.buy_pressed.connect(_on_item_buy_pressed)
										new_card.use_pressed.connect(_on_item_use_pressed)
										new_card.preview_pressed.connect(_on_item_preview_pressed)
										new_card.cover_click_pressed.connect(_on_cover_click_pressed)

										grid_container.add_child(new_card)
										item_cards.append(new_card)

									print("ShopScreen.gd: Создано карточек: ", item_cards.size())
									items_scroll.scroll_vertical = 0
									items_scroll.scroll_horizontal = 0
								else:
									print("ShopScreen.gd: ОШИБКА: ItemsGrid НЕ найден внутри ItemsGridBottomMargin.")
							else:
								print("ShopScreen.gd: ОШИБКА: ItemsListContainer НЕ найден внутри ItemsScroll.")
						else:
							print("ShopScreen.gd: ОШИБКА: ItemsScroll НЕ найден внутри ItemListVBox.")
					else:
						print("ShopScreen.gd: ОШИБКА: ItemListVBox НЕ найден внутри ContentHBox.")
				else:
					print("ShopScreen.gd: ОШИБКА: ContentHBox НЕ найден внутри ContentMargin.")
			else:
				print("ShopScreen.gd: ОШИБКА: ContentMargin НЕ найден внутри MainVBox.")
		else:
			print("ShopScreen.gd: ОШИБКА: MainVBox НЕ найден внутри MainContent.")
	else:
		print("ShopScreen.gd: ОШИБКА: MainContent НЕ найден по пути $MainContent.")


func _get_category_map() -> Dictionary:
	return {
		"Кик": "Kick",
		"Снейр": "Snare",
		"Обложки": "Covers",
		"Прочее": "Misc"
	}

func _on_category_selected(category: String):
	print("ShopScreen.gd: Выбрана категория: ", category)
	for card in item_cards:
		card.queue_free()
	item_cards.clear()

	var filtered_items = []
	for item in shop_data.get("items", []):
		if category == "Все" or item.category == category:
			filtered_items.append(item)

	var grid_container = $MainContent/MainVBox/ContentMargin/ContentHBox/ItemListVBox/ItemsScroll/ItemsListContainer/ItemsGridCenter/ItemsGridBottomMargin/ItemsGrid
	if grid_container:
		for i in range(filtered_items.size()):
			var item_data = filtered_items[i]
			var new_card = preload("res://scenes/shop/item_card.tscn").instantiate()
			new_card.item_data = item_data

			var is_purchased = player_data_manager.is_item_unlocked(item_data.item_id)
			var is_active = false
			var category_map = _get_category_map()
			var internal_category = category_map.get(item_data.category, "")
			if internal_category:
				is_active = (player_data_manager.get_active_item(internal_category) == item_data.item_id)

			new_card.update_state(is_purchased, is_active)

			new_card.buy_pressed.connect(_on_item_buy_pressed)
			new_card.use_pressed.connect(_on_item_use_pressed)
			new_card.preview_pressed.connect(_on_item_preview_pressed)
			new_card.cover_click_pressed.connect(_on_cover_click_pressed)

			grid_container.add_child(new_card)
			item_cards.append(new_card)
	else:
		print("ShopScreen.gd: ОШИБКА: ItemsGrid не найден в _on_category_selected по новому пути")

	print("ShopScreen.gd: Отфильтровано предметов: ", filtered_items.size())

func _on_item_buy_pressed(item_id: String):
	print("ShopScreen.gd: Запрос на покупку предмета: ", item_id)

	var item_data = _find_item_by_id(item_id)
	if item_data:
		var price = item_data.get("price", 0)
		var current_currency = player_data_manager.get_currency()

		if current_currency >= price:
			player_data_manager.add_currency(-price)
			player_data_manager.unlock_item(item_id)
			_update_currency_label()
			_update_item_card_state(item_id, true, false)
			print("ShopScreen.gd: Предмет куплен: ", item_id)
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
			print("ShopScreen.gd: Аудио файл не найден для ", item_data.get("name", "Без названия"), ": ", full_audio_path)
			return false
	if image_path != "":
		if not FileAccess.file_exists(image_path):
			print("ShopScreen.gd: Изображение не найдено для ", item_data.get("name", "Без названия"), ": ", image_path)
			return false
	if images_folder != "" and images_count > 0:
		var cover_exists = false
		for i in range(1, images_count + 1):
			var cover_path = images_folder + "/cover%d.png" % i
			if FileAccess.file_exists(cover_path):
				cover_exists = true
				break
		if not cover_exists:
			print("ShopScreen.gd: Ни одной обложки не найдено для ", item_data.get("name", "Без названия"), " в папке: ", images_folder)
			return false
	return true

func _on_item_use_pressed(item_id: String):
	print("ShopScreen.gd: Запрос на использование предмета: ", item_id)

	var item_data = _find_item_by_id(item_id)
	if item_data:
		var category_map = _get_category_map()
		var internal_category = category_map.get(item_data.category, "")
		if internal_category:
			player_data_manager.set_active_item(internal_category, item_id)
			_update_all_item_cards_in_category(internal_category, item_id)
			print("ShopScreen.gd: Предмет активирован: ", item_id)
		else:
			print("ShopScreen.gd: Неизвестная категория для предмета: ", item_id)
	else:
		print("ShopScreen.gd: Предмет с ID ", item_id, " не найден в данных магазина.")
func _on_item_preview_pressed(item_id: String):
	print("ShopScreen.gd: Запрос на предпросмотр аудио для предмета: ", item_id)
	var item_data = _find_item_by_id(item_id)
	if item_data:
		_preview_sound(item_data)
	else:
		print("ShopScreen.gd: Предмет с ID ", item_id, " не найден в данных магазина для предпросмотра.")
func _preview_sound(item: Dictionary):
	var audio_path = item.get("audio", "")
	if audio_path and music_manager:
		print("ShopScreen.gd: Предпросмотр: %s" % audio_path)
		if audio_path.begins_with("res://"):
			music_manager.play_custom_hit_sound(audio_path)
		else:
			music_manager.play_custom_hit_sound(audio_path)
		var path_for_manager = audio_path
		if audio_path.begins_with("res://assets/shop/sounds/"):
			path_for_manager = audio_path.replace("res://assets/shop/sounds/", "")
		if FileAccess.file_exists(audio_path):
			music_manager.play_custom_hit_sound(path_for_manager)
		else:
			print("ShopScreen.gd: Звук не найден по абсолютному пути: %s, используем стандартный" % audio_path)
			music_manager.play_default_shop_sound()
	else:
		print("ShopScreen.gd: Нет аудио у %s или MusicManager не установлен" % item.get("item_id", "Без ID"))
		if music_manager:
			music_manager.play_default_shop_sound()

func _on_cover_click_pressed(item_data: Dictionary):
	print("ShopScreen.gd: Клик по обложке: ", item_data.get("name", "Без названия"))
	_open_cover_gallery(item_data)

func _open_cover_gallery(item_data: Dictionary):
	if current_cover_gallery:
		if is_instance_valid(current_cover_gallery):
			current_cover_gallery.queue_free()
		current_cover_item_data = {}

	current_cover_item_data = item_data

	var gallery_scene = preload("res://scenes/shop/cover_gallery.tscn")
	print("ShopScreen.gd: Загруженная сцена: ", gallery_scene)
	current_cover_gallery = gallery_scene.instantiate()
	print("ShopScreen.gd: Созданный узел: ", current_cover_gallery)
	print("ShopScreen.gd: Класс созданного узла: ", current_cover_gallery.get_class())
	print("ShopScreen.gd: Скрипт созданного узла: ", current_cover_gallery.get_script())

	current_cover_gallery.images_folder = item_data.get("images_folder", "")
	current_cover_gallery.images_count = item_data.get("images_count", 0)

	current_cover_gallery.connect("gallery_closed", _on_gallery_closed, CONNECT_ONE_SHOT)
	current_cover_gallery.connect("cover_selected", _on_cover_selected_stub, CONNECT_ONE_SHOT)

	var self_is_valid = is_instance_valid(self)
	var self_queued_for_deletion = is_queued_for_deletion()
	var self_is_inside_tree = is_inside_tree()
	var gallery_is_valid = is_instance_valid(current_cover_gallery)

	print("ShopScreen.gd: Проверка перед отложенным add_child:")
	print(" - is_instance_valid(self): ", self_is_valid)
	print(" - is_queued_for_deletion(): ", self_queued_for_deletion)
	print(" - is_inside_tree(): ", self_is_inside_tree)
	print(" - is_instance_valid(current_cover_gallery): ", gallery_is_valid)

	if self_is_valid and not self_queued_for_deletion and self_is_inside_tree and gallery_is_valid:
		print("ShopScreen.gd: Планирую отложенное добавление галереи как дочернего узла.")
		call_deferred("_deferred_add_child", current_cover_gallery)
		print("ShopScreen.gd: Отложенное добавление запланировано.")
	else:
		print("ShopScreen.gd: ShopScreen или галерея недействительны, галерея не будет добавлена.")
		if is_instance_valid(current_cover_gallery):
			current_cover_gallery.queue_free()
		current_cover_item_data = {}

func _deferred_add_child(gallery_node: Node):
	if is_instance_valid(self) and not is_queued_for_deletion() and is_inside_tree() and is_instance_valid(gallery_node):
		print("ShopScreen.gd: (DEFERRED) Добавляю галерею как дочерний узел.")
		add_child(gallery_node)
		gallery_node.grab_focus()
		print("ShopScreen.gd: (DEFERRED) Галерея добавлена и фокус установлен.")
	else:
		print("ShopScreen.gd: (DEFERRED) ShopScreen или галерея недействительны при отложенном добавлении.")
		if is_instance_valid(gallery_node):
			gallery_node.queue_free()
		if current_cover_gallery == gallery_node:
			current_cover_gallery = null
		current_cover_item_data = {}


func _on_cover_selected_stub(index: int):
	pass

func _on_gallery_closed():
	print("ShopScreen.gd: Галерея обложек закрыта.")
	if is_instance_valid(current_cover_gallery):
		if current_cover_gallery.is_connected("gallery_closed", _on_gallery_closed):
			current_cover_gallery.disconnect("gallery_closed", _on_gallery_closed)
		if current_cover_gallery.is_connected("cover_selected", _on_cover_selected_stub):
			current_cover_gallery.disconnect("cover_selected", _on_cover_selected_stub)
		current_cover_gallery = null
	current_cover_item_data = {}

func _on_cover_selected(index: int):
	print("ShopScreen.gd: Выбрана обложка %d из пака '%s'." % [index, current_cover_item_data.get("name", "Без названия")])

func _exit_tree():
	print("ShopScreen.gd: _exit_tree вызван. Экран удаляется из дерева сцен.")
	cleanup_gallery()

func cleanup_gallery():
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
		print("ShopScreen.gd: Галерея очищена в _exit_tree или cleanup_gallery.")


func _find_item_by_id(item_id: String) -> Dictionary:
	for item in shop_data.get("items", []):
		if item.get("item_id", "") == item_id:
			return item
	return {}

func _update_item_card_state(item_id: String, purchased: bool, active: bool):
	for card in item_cards:
		if card.item_data.get("item_id", "") == item_id:
			card.update_state(purchased, active)
			break

func _update_all_item_cards_in_category(category: String, active_item_id: String):
	for card in item_cards:
		var category_map = _get_category_map()
		var internal_category = category_map.get(card.item_data.category, "")
		if internal_category == category:
			var is_purchased = player_data_manager.is_item_unlocked(card.item_data.item_id)
			var is_active = (card.item_data.item_id == active_item_id)
			card.update_state(is_purchased, is_active)
func _on_back_pressed():
	print("ShopScreen.gd: Нажата кнопка Назад или Escape.")
	var game_engine = get_parent()
	if game_engine and game_engine.has_method("prepare_screen_exit"):
		if game_engine.prepare_screen_exit(self):
			print("ShopScreen.gd: Экран подготовлен к выходу через GameEngine.")
		else:
			print("ShopScreen.gd: ОШИБКА подготовки экрана к выходу через GameEngine.")
	else:
		printerr("ShopScreen.gd: Не удалось получить GameEngine или метод prepare_screen_exit!")
	if music_manager:
		music_manager.play_cancel_sound()
		print("ShopScreen.gd: play_cancel_sound вызван.")
	else:
		printerr("ShopScreen.gd: music_manager не установлен!")
	if player_data_manager:
		print("ShopScreen.gd: Данные игрока (локально) сохранены бы (если реализован метод save_player_data в PlayerDataManager).")
	else:
		printerr("ShopScreen.gd: player_data_manager не установлен!")
	if transitions:
		transitions.close_shop()
		print("ShopScreen.gd: Закрываю магазин через Transitions.")
	else:
		printerr("ShopScreen.gd: transitions не установлен, невозможно закрыть магазин через Transitions.")
func _unhandled_input(event):
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		print("ShopScreen.gd: Обнаружено нажатие Escape, вызываю _on_back_pressed.")
		accept_event()
		_on_back_pressed()
func cleanup_before_exit():
	print("ShopScreen.gd: cleanup_before_exit вызван. Очищаем ресурсы.")
	if current_cover_gallery:
		if is_instance_valid(current_cover_gallery):
			current_cover_gallery.queue_free()
		current_cover_gallery = null
		current_cover_item_data = {}
		print("ShopScreen.gd: Галерея обложек очищена в cleanup_before_exit.")
