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
	if not item_data:
		print("ItemCard.gd: Ошибка: item_data не установлен.")
		return

	var image_rect = $MarginContainer/ContentContainer/ImageRect
	var name_label = $MarginContainer/ContentContainer/NameLabel
	var status_label = $MarginContainer/ContentContainer/StatusLabel

	if image_rect:
		var image_path = item_data.get("image", "")
		var images_folder = item_data.get("images_folder", "")
		var texture = null

		if image_path != "":
			texture = ResourceLoader.load(image_path)
			if texture and texture is ImageTexture:
				image_rect.texture = texture
				image_rect.visible = true
				name_label.visible = true
				name_label.visible = false
				print("ItemCard.gd: Текстура загружена по прямому пути: ", image_path)
			else:
				print("ItemCard.gd: Ошибка загрузки текстуры: ", image_path)
				name_label.visible = true
				name_label.text = item_data.get("name", "Без названия")

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
			else:
				print("ItemCard.gd: Ошибка загрузки изображения (Image.load): ", error, " Путь: ", cover_path)
				_create_placeholder_with_text()

		else:
			print("ItemCard.gd: Путь к изображению пустой")
			_create_placeholder_with_text()

	else:
		print("ItemCard.gd: ImageRect не найден")

func _create_placeholder_with_text():
	var image_rect = $MarginContainer/ContentContainer/ImageRect
	var name_label = $MarginContainer/ContentContainer/NameLabel

	if image_rect and name_label:
		var placeholder_image = Image.create(240, 180, false, Image.FORMAT_RGBA8)
		placeholder_image.fill(Color(0.5, 0.5, 0.5, 1.0))
		var placeholder_texture = ImageTexture.create_from_image(placeholder_image)
		image_rect.texture = placeholder_texture
		image_rect.visible = true

		name_label.text = item_data.get("name", "Без названия")
		name_label.visible = true
		name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0)) 
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VerticalAlignment.VERTICAL_ALIGNMENT_CENTER
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL



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
		if is_default:
			status_label.text = "✔️ Дефолтный"
			status_label.visible = true
		elif is_active:
			status_label.text = "✅ Используется"
			status_label.visible = true
		else:
			status_label.visible = false

func _on_buy_pressed():
	emit_signal("buy_pressed", item_data.get("item_id", ""))

func _on_use_pressed():
	emit_signal("use_pressed", item_data.get("item_id", ""))

func _on_preview_pressed():
	emit_signal("preview_pressed", item_data.get("item_id", ""))

func update_state(purchased: bool, active: bool):
	is_purchased = purchased
	is_active = active
	_setup_item()
