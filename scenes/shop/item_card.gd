# scenes/shop/item_card.gd
extends Control
signal cover_click_pressed(item_data: Dictionary)
signal buy_pressed(item_id: String)
signal use_pressed(item_id: String)
signal preview_pressed(item_id: String)

@export var item_data: Dictionary = {}

var is_purchased: bool = false
var is_active: bool = false
var is_default: bool = false

func _ready():
	if not item_data.has("item_id"):
		printerr("ItemCard.gd: item_data не содержит 'item_id'!")
		return # Выходим из _ready, чтобы не продолжать с неполными данными

	print("ItemCard.gd: _ready вызван для карточки: ", item_data.get("name", "Без названия"))
	var buy_button = $MarginContainer/ContentContainer/BuyButton
	if buy_button:
		buy_button.pressed.connect(_on_buy_pressed)

	var use_button = $MarginContainer/ContentContainer/UseButton
	if use_button:
		use_button.pressed.connect(_on_use_pressed)

	var preview_button = $MarginContainer/ContentContainer/PreviewButton
	if preview_button:
		preview_button.pressed.connect(_on_preview_pressed)

	var image_rect = $MarginContainer/ContentContainer/ImageRect
	if image_rect:
		image_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		image_rect.gui_input.connect(_on_image_rect_gui_input)

	_setup_item()

	custom_minimum_size = Vector2(280, 350)
	print("ItemCard.gd: Установлен custom_minimum_size: ", custom_minimum_size)


func _on_image_rect_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if item_data.get("category", "") == "Обложки":
			emit_signal("cover_click_pressed", item_data)


func _setup_item():
	if not item_data.has("item_id"):
		printerr("ItemCard.gd: _setup_item: item_data не содержит 'item_id'!")
		return # Выходим, если нет ключа

	var item_id_str = item_data.get("item_id", "") # Даже если null в JSON, .get() вернет ""
	is_default = item_id_str.ends_with("_default") # Теперь вызов .ends_with безопасен

	var image_rect = $MarginContainer/ContentContainer/ImageRect
	var name_label = $MarginContainer/ContentContainer/NameLabel
	var status_label = $MarginContainer/ContentContainer/StatusLabel

	if name_label:
		name_label.visible = false
	if status_label:
		status_label.visible = false

	var image_path = item_data.get("image", "") # .get() возвращает "", если ключа нет или значение null
	var images_folder = item_data.get("images_folder", "")
	var texture = null
	var image_loaded_successfully = false

	if image_path != "":
		if FileAccess.file_exists(image_path):
			texture = ResourceLoader.load(image_path, "ImageTexture")
			if texture and texture is ImageTexture:
				image_rect.texture = texture
<<<<<<< HEAD
				image_loaded_successfully = true
				print("ItemCard.gd: Текстура загружена по прямому пути: ", image_path)
			else:
				print("ItemCard.gd: Ошибка загрузки текстуры: ", image_path)
		else:
			print("ItemCard.gd: Файл изображения не найден: ", image_path)
	elif images_folder != "":
		var cover_path = images_folder + "/cover1.png"
		print("ItemCard.gd: Попытка загрузить обложку: ", cover_path)
=======
				image_rect.visible = true # Убедитесь, что ImageRect видим
				name_label.visible = false # Скрываем имя, если есть изображение
				print("ItemCard.gd: Текстура загружена по прямому пути: ", image_path)
			else:
				print("ItemCard.gd: Ошибка загрузки текстуры: ", image_path)
				_create_placeholder_with_text()
				name_label.visible = false # Скрываем имя, если используется плейсхолдер
		elif images_folder != "":
			var cover_path = images_folder + "/cover1.png"
			print("ItemCard.gd: Попытка загрузить обложку: ", cover_path)

			var image = Image.new()
			var error = image.load(cover_path)
			if error == OK and image:
				texture = ImageTexture.create_from_image(image)
				if texture:
					image_rect.texture = texture
					image_rect.visible = true
					name_label.visible = false
					print("ItemCard.gd: Текстура обложки создана вручную из файла: ", cover_path)
				else:
					print("ItemCard.gd: Не удалось создать ImageTexture из Image: ", cover_path)
					_create_placeholder_with_text()
					name_label.visible = false
			else:
				print("ItemCard.gd: Ошибка загрузки изображения (Image.load): ", error, " Путь: ", cover_path)
				_create_placeholder_with_text()
				name_label.visible = false
		else:
			print("ItemCard.gd: Путь к изображению пустой")
			_create_placeholder_with_text()
			name_label.visible = false # Скрываем имя, если используется плейсхолдер

		if image_rect.texture:
			image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		else:
			image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
>>>>>>> 6d2afbc5851a4fe73bcce7a9ff021381d72be28c

		var image = Image.new()
		var error = image.load(cover_path)
		if error == OK and image:
			texture = ImageTexture.create_from_image(image)
			if texture:
				image_rect.texture = texture
				image_loaded_successfully = true
				print("ItemCard.gd: Текстура обложки создана вручную из файла: ", cover_path)
			else:
				print("ItemCard.gd: Не удалось создать ImageTexture из Image: ", cover_path)
		else:
			print("ItemCard.gd: Ошибка загрузки изображения (Image.load): ", error, " Путь: ", cover_path)
	else:
		print("ItemCard.gd: Пути к изображению (image и images_folder) пусты для предмета: ", item_data.get("name", "Без названия"))

	if image_rect:
		if image_loaded_successfully:
			image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			image_rect.visible = true # Показываем ImageRect, если изображение есть
		else:
			_create_placeholder_with_text() # Создает плейсхолдер и присваивает его image_rect.texture
			image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			image_rect.visible = true # Показываем ImageRect с плейсхолдером
			if name_label:
				var item_name = item_data.get("name", "Без названия") # .get() возвращает "Без названия", если ключа нет или значение null
				name_label.text = item_name
				name_label.visible = true # Показываем NameLabel

	_update_buttons_and_status()


func _create_placeholder_with_text():
	var image_rect = $MarginContainer/ContentContainer/ImageRect

<<<<<<< HEAD
	if image_rect:
=======
	if image_rect and name_label:
>>>>>>> 6d2afbc5851a4fe73bcce7a9ff021381d72be28c
		var placeholder_width = 240 # Установите нужный размер
		var placeholder_height = 180 # Установите нужный размер

		var placeholder_image = Image.create(placeholder_width, placeholder_height, false, Image.FORMAT_RGBA8)
		placeholder_image.fill(Color(0.5, 0.5, 0.5, 1.0)) # Серый цвет
		var placeholder_texture = ImageTexture.create_from_image(placeholder_image)

		image_rect.texture = placeholder_texture
<<<<<<< HEAD
		print("ItemCard.gd: Плейсхолдер создан и присвоен ImageRect")
=======
		image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED # Или STRETCH_SCALE_ON_EXPAND
		image_rect.visible = true # Убедитесь, что ImageRect видим


>>>>>>> 6d2afbc5851a4fe73bcce7a9ff021381d72be28c


func _update_buttons_and_status():
	var buy_button = $MarginContainer/ContentContainer/BuyButton
	var use_button = $MarginContainer/ContentContainer/UseButton
	var preview_button = $MarginContainer/ContentContainer/PreviewButton
	var status_label = $MarginContainer/ContentContainer/StatusLabel

	if buy_button:
		buy_button.visible = not is_purchased and not is_default
		if buy_button.visible:
			var price = item_data.get("price", 0)
			buy_button.text = "Купить за %d 💰" % price

	if use_button:
		use_button.visible = is_purchased and not is_default and not is_active
		if use_button.visible:
			use_button.text = "✅ Использовать"

	if preview_button:
		var audio_path = item_data.get("audio", "")
		preview_button.visible = audio_path != ""
		if preview_button.visible:
			preview_button.text = "🔊 Прослушать"

	if status_label:
		if is_active:
			status_label.text = "✅ Используется"
			status_label.visible = true
		elif is_default:
			status_label.text = "✔️ Дефолтный"
			status_label.visible = true
		else:
			status_label.visible = false


func _on_buy_pressed():
	var item_id_str = item_data.get("item_id", "") # .get() возвращает "", если ключа нет или значение null
	emit_signal("buy_pressed", item_id_str)

func _on_use_pressed():
	var item_id_str = item_data.get("item_id", "") # .get() возвращает "", если ключа нет или значение null
	emit_signal("use_pressed", item_id_str)

func _on_preview_pressed():
	var item_id_str = item_data.get("item_id", "") # .get() возвращает "", если ключа нет или значение null
	emit_signal("preview_pressed", item_id_str)

func update_state(purchased: bool, active: bool):
	is_purchased = purchased
	is_active = active
	_setup_item() # Пересобираем карточку с новым состоянием (изображение, кнопки, статусы)
