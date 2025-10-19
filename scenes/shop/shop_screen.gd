# scenes/shop/shop_screen.gd
extends Control

var currency: int = 0

var shop_data: Dictionary = {}

var item_cards: Array[Node] = []

func _ready():
	print("ShopScreen.gd: _ready вызван.")

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

	currency = 422120
	_update_currency_label()

	_connect_category_buttons()

	var items_scroll = $MainContent/MainVBox/ContentHBox/ItemListVBox/ItemsScroll
	if items_scroll:
		print("ShopScreen.gd: ItemsScroll найден.")

		var items_list_container = items_scroll.get_node("ItemsListContainer")
		if items_list_container:
			print("ShopScreen.gd: ItemsListContainer найден.")

			var grid_container = items_list_container.get_node("ItemsGrid")
			if grid_container:
				print("ShopScreen.gd: ItemsGrid найден.")

				grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				grid_container.size_flags_vertical = Control.SIZE_EXPAND_FILL

				var num_rows_estimate = 10
				var row_spacing = 30 
				var estimated_height = (350 * num_rows_estimate) + (row_spacing * (num_rows_estimate - 1))
				grid_container.custom_minimum_size = Vector2(280 * 5, estimated_height)
				print("ShopScreen.gd: Установлен custom_minimum_size для ItemsGrid: ", grid_container.custom_minimum_size)

				items_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				items_list_container.size_flags_vertical = Control.SIZE_EXPAND_FILL

				items_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				items_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
			else:
				print("ShopScreen.gd: ОШИБКА: ItemsGrid не найден внутри ItemsListContainer.")
		else:
			print("ShopScreen.gd: ОШИБКА: ItemsListContainer не найден внутри ItemsScroll.")
	else:
		print("ShopScreen.gd: ОШИБКА: ItemsScroll не найден.")

	_create_item_cards()

func _update_currency_label():
	print("ShopScreen.gd: Попытка найти CurrencyLabel по пути: $MainContent/MainVBox/HBoxContainer/VBoxContainer/CurrencyLabel")
	var main_vbox = $MainContent/MainVBox
	if main_vbox:
		print("ShopScreen.gd: MainVBox найден.")
		var h_box_container = main_vbox.get_node("HBoxContainer")
		if h_box_container:
			print("ShopScreen.gd: HBoxContainer найден.")
			var v_box_container = h_box_container.get_node("VBoxContainer")
			if v_box_container:
				print("ShopScreen.gd: VBoxContainer найден.")
				var currency_label = v_box_container.get_node("CurrencyLabel")
				if currency_label:
					print("ShopScreen.gd: CurrencyLabel найден по пути $MainContent/MainVBox/HBoxContainer/VBoxContainer/CurrencyLabel")
					currency_label.text = "💰 Валюта: %d" % currency
					currency_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
					currency_label.add_theme_font_size_override("font_size", 32)
				else:
					print("ShopScreen.gd: ОШИБКА: CurrencyLabel НЕ найден внутри VBoxContainer.")
			else:
				print("ShopScreen.gd: ОШИБКА: VBoxContainer НЕ найден внутри HBoxContainer.")
		else:
			print("ShopScreen.gd: ОШИБКА: HBoxContainer НЕ найден внутри MainVBox.")
	else:
		print("ShopScreen.gd: ОШИБКА: MainVBox НЕ найден по пути $MainContent/MainVBox.")


func _connect_category_buttons():
	var all_btn = $MainContent/MainVBox/HBoxContainer/VBoxContainer/CategoriesHBox/CategoryButtonAll
	var kick_btn = $MainContent/MainVBox/HBoxContainer/VBoxContainer/CategoriesHBox/CategoryButtonKick
	var snare_btn = $MainContent/MainVBox/HBoxContainer/VBoxContainer/CategoriesHBox/CategoryButtonSnare
	var cover_btn = $MainContent/MainVBox/HBoxContainer/VBoxContainer/CategoriesHBox/CategoryButtonCover
	var misc_btn = $MainContent/MainVBox/HBoxContainer/VBoxContainer/CategoriesHBox/CategoryButtonMisc

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

	print("ShopScreen.gd: Попытка найти ItemsGrid по новому пути: $MainContent/MainVBox/ContentHBox/ItemListVBox/ItemsScroll/ItemsListContainer/ItemsGrid")
	var main_content = $MainContent
	if main_content:
		print("ShopScreen.gd: MainContent найден.")
		var main_vbox = main_content.get_node("MainVBox")
		if main_vbox:
			print("ShopScreen.gd: MainVBox найден.")
			var content_hbox = main_vbox.get_node("ContentHBox")
			if content_hbox:
				print("ShopScreen.gd: ContentHBox найден.")
				var item_list_vbox = content_hbox.get_node("ItemListVBox")
				if item_list_vbox:
					print("ShopScreen.gd: ItemListVBox найден.")
					var items_scroll = item_list_vbox.get_node("ItemsScroll")
					if items_scroll:
						print("ShopScreen.gd: ItemsScroll найден.")
						var items_list_container = items_scroll.get_node("ItemsListContainer")
						if items_list_container:
							print("ShopScreen.gd: ItemsListContainer найден.")
							var grid_container = items_list_container.get_node("ItemsGrid") 
							if grid_container:
								print("ShopScreen.gd: ItemsGrid найден по новому пути $MainContent/MainVBox/ContentHBox/ItemListVBox/ItemsScroll/ItemsListContainer/ItemsGrid")
								for i in range(items.size()):
									var item_data = items[i]

									var new_card = item_card_scene.instantiate()

									new_card.item_data = item_data

									new_card.buy_pressed.connect(_on_item_buy_pressed)
									new_card.use_pressed.connect(_on_item_use_pressed)
									new_card.preview_pressed.connect(_on_item_preview_pressed)

									grid_container.add_child(new_card)
									item_cards.append(new_card)

								print("ShopScreen.gd: Создано карточек: ", item_cards.size())
							else:
								print("ShopScreen.gd: ОШИБКА: ItemsGrid НЕ найден внутри ItemsListContainer.")
						else:
							print("ShopScreen.gd: ОШИБКА: ItemsListContainer НЕ найден внутри ItemsScroll.")
					else:
						print("ShopScreen.gd: ОШИБКА: ItemsScroll НЕ найден внутри ItemListVBox.")
				else:
					print("ShopScreen.gd: ОШИБКА: ItemListVBox НЕ найден внутри ContentHBox.")
			else:
				print("ShopScreen.gd: ОШИБКА: ContentHBox НЕ найден внутри MainVBox.")
		else:
			print("ShopScreen.gd: ОШИБКА: MainVBox НЕ найден внутри MainContent.")
	else:
		print("ShopScreen.gd: ОШИБКА: MainContent НЕ найден по пути $MainContent.")


func _on_category_selected(category: String):
	print("ShopScreen.gd: Выбрана категория: ", category)
	for card in item_cards:
		card.queue_free()
	item_cards.clear()

	var filtered_items = []
	for item in shop_data.get("items", []):
		if category == "Все" or item.category == category:
			filtered_items.append(item)

	for i in range(filtered_items.size()):
		var item_data = filtered_items[i]
		var new_card = preload("res://scenes/shop/item_card.tscn").instantiate()
		new_card.item_data = item_data
		new_card.buy_pressed.connect(_on_item_buy_pressed)
		new_card.use_pressed.connect(_on_item_use_pressed)
		new_card.preview_pressed.connect(_on_item_preview_pressed)

		var grid_container = $MainContent/MainVBox/ContentHBox/ItemListVBox/ItemsScroll/ItemsListContainer/ItemsGrid
		if grid_container:
			grid_container.add_child(new_card)
			item_cards.append(new_card)
		else:
			print("ShopScreen.gd: ОШИБКА: ItemsGrid не найден в _on_category_selected")

	print("ShopScreen.gd: Отфильтровано предметов: ", filtered_items.size())

func _on_item_buy_pressed(item_id: String):
	print("ShopScreen.gd: Запрос на покупку предмета: ", item_id)

func _on_item_use_pressed(item_id: String):
	print("ShopScreen.gd: Запрос на использование предмета: ", item_id)

func _on_item_preview_pressed(item_id: String):
	print("ShopScreen.gd: Запрос на предпросмотр аудио для предмета: ", item_id)
