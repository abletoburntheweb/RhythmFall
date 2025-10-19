# scenes/shop/item_card.gd
extends Control

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

	_setup_item()

	custom_minimum_size = Vector2(280, 350)
	print("ItemCard.gd: Установлен custom_minimum_size: ", custom_minimum_size)


func _setup_item():
	if not item_data:
		print("ItemCard.gd: Ошибка: item_data не установлен.")
		return

	var image_rect = $MarginContainer/ContentContainer/ImageRect
	var name_label = $MarginContainer/ContentContainer/NameLabel
	var status_label = $MarginContainer/ContentContainer/StatusLabel

	if image_rect:
		var image_path = item_data.get("image", "")
		var texture = null

		if image_path != "":
			texture = load(image_path)
			if texture and texture is ImageTexture:
				image_rect.texture = texture
				image_rect.visible = true
				name_label.visible = true
			else:
				print("ItemCard.gd: Ошибка загрузки текстуры: ", image_path)
				_create_placeholder_with_text()
		else:
			print("ItemCard.gd: Путь к изображению пустой")
			_create_placeholder_with_text()
	else:
		print("ItemCard.gd: ImageRect не найден")

	if status_label:
		status_label.visible = false

	is_default = item_data.get("item_id", "").ends_with("_default")
	if is_default:
		status_label.text = "✔️ Дефолтный"
		status_label.visible = true

	is_active = item_data.get("is_active", false)  
	if is_active and not is_default:
		status_label.text = "✅ Используется"
		status_label.visible = true

	is_purchased = item_data.get("is_purchased", false)
	if is_purchased and not is_default:
		status_label.visible = false

	_update_buttons_and_status()

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
