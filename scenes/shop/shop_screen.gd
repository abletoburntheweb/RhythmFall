# scenes/shop/shop_screen.gd
extends Control

var currency: int = 0
var shop_data: Dictionary = {}
var item_cards: Array[Node] = []

var current_cover_gallery: Node = null
var current_cover_item_data: Dictionary = {}

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

	var items_scroll = $MainContent/MainVBox/ContentMargin/ContentHBox/ItemListVBox/ItemsScroll
	if items_scroll:
		print("ShopScreen.gd: ItemsScroll найден.")

		var items_list_container = items_scroll.get_node("ItemsListContainer")
		if items_list_container:
			print("ShopScreen.gd: ItemsListContainer найден.")

			var grid_container = items_list_container.get_node("ItemsGrid")
			if grid_container:
				print("ShopScreen.gd: ItemsGrid найден.")

				grid_container.custom_minimum_size = Vector2.ZERO

				grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				grid_container.size_flags_vertical = Control.SIZE_EXPAND_FILL

				grid_container.add_theme_constant_override("v_separation", 30)
				grid_container.add_theme_constant_override("h_separation", 30)

				items_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				items_list_container.size_flags_vertical = Control.SIZE_EXPAND_FILL

				items_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				items_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

				var content_hbox = $MainContent/MainVBox/ContentMargin/ContentHBox
				if content_hbox:
					print("ShopScreen.gd: Устанавливаю size_flags_vertical для ContentHBox")
					content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
				else:
					print("ShopScreen.gd: ОШИБКА: ContentHBox не найден.")
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

	print("ShopScreen.gd: Попытка найти ItemsGrid по новому пути: $MainContent/MainVBox/ContentMargin/ContentHBox/ItemListVBox/ItemsScroll/ItemsListContainer/ItemsGrid")
	var main_content = $MainContent
	if main_content:
		print("ShopScreen.gd: MainContent найден.")
		var main_vbox = main_content.get_node("MainVBox")
		if main_vbox:
			print("ShopScreen.gd: MainVBox найден.")
			var content_margin = main_vbox.get_node("ContentMargin")
			if content_margin:
				print("ShopScreen.gd: ContentMargin найден.")
				var content_hbox = content_margin.get_node("ContentHBox")
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
									print("ShopScreen.gd: ItemsGrid найден по новому пути $MainContent/MainVBox/ContentMargin/ContentHBox/ItemListVBox/ItemsScroll/ItemsListContainer/ItemsGrid")
									for i in range(items.size()):
										var item_data = items[i]

										var new_card = item_card_scene.instantiate()

										new_card.item_data = item_data

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
									print("ShopScreen.gd: ОШИБКА: ItemsGrid НЕ найден внутри ItemsListContainer.")
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

		new_card.cover_click_pressed.connect(_on_cover_click_pressed)

		var grid_container = $MainContent/MainVBox/ContentMargin/ContentHBox/ItemListVBox/ItemsScroll/ItemsListContainer/ItemsGrid
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
