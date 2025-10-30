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
		return

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


func _on_image_rect_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if item_data.get("category", "") == "Обложки":
			emit_signal("cover_click_pressed", item_data)


func _setup_item():
	if not item_data.has("item_id"):
		return

	var item_id_str = item_data.get("item_id", "") 
	is_default = item_id_str.ends_with("_default")

	var image_rect = $MarginContainer/ContentContainer/ImageRect
	var name_label = $MarginContainer/ContentContainer/NameLabel
	var status_label = $MarginContainer/ContentContainer/StatusLabel

	if status_label:
		status_label.visible = false

	var image_path = item_data.get("image", "") 
	var images_folder = item_data.get("images_folder", "")
	var texture = null
	var image_loaded_successfully = false

	if image_path != "":
		if FileAccess.file_exists(image_path):
			texture = ResourceLoader.load(image_path, "ImageTexture")
			if texture and texture is ImageTexture:
				image_rect.texture = texture
				image_loaded_successfully = true
			else:
				pass
		else:
			pass
	elif images_folder != "":
		var cover_path = images_folder + "/cover1.png"

		var image = Image.new()
		var error = image.load(cover_path)
		if error == OK and image:
			texture = ImageTexture.create_from_image(image)
			if texture:
				image_rect.texture = texture
				image_loaded_successfully = true
			else:
				pass
		else:
			pass
	else:
		pass

	if image_rect:
		if image_loaded_successfully:
			image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			image_rect.visible = true 
		else:
			_create_placeholder_with_text()
			image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			image_rect.visible = true 

	if name_label:
		var item_name = item_data.get("name", "Без названия")
		name_label.text = item_name
		name_label.visible = true

	_update_buttons_and_status()


func _create_placeholder_with_text():
	var image_rect = $MarginContainer/ContentContainer/ImageRect
	if image_rect:
		var placeholder_width = 240 
		var placeholder_height = 180 

		var placeholder_image = Image.create(placeholder_width, placeholder_height, false, Image.FORMAT_RGBA8)
		placeholder_image.fill(Color(0.5, 0.5, 0.5, 1.0))
		var placeholder_texture = ImageTexture.create_from_image(placeholder_image)

		image_rect.texture = placeholder_texture


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
		use_button.visible = is_purchased and not is_active
		if use_button.visible:
			use_button.text = "✅ Использовать"
	if preview_button:
		var audio_path = item_data.get("audio", "")
		preview_button.visible = audio_path != ""
		if preview_button.visible:
			preview_button.text = "🔊 Прослушать"

	if status_label:
		status_label.visible = false
		if is_active:
			status_label.text = "✅ Используется"
			status_label.visible = true
		elif is_default:
			status_label.text = "✔️ Дефолтный"
			status_label.visible = true


func _on_buy_pressed():
	var item_id_str = item_data.get("item_id", "")
	emit_signal("buy_pressed", item_id_str)

func _on_use_pressed():
	var item_id_str = item_data.get("item_id", "")
	emit_signal("use_pressed", item_id_str)

func _on_preview_pressed():
	var item_id_str = item_data.get("item_id", "") 
	emit_signal("preview_pressed", item_id_str)

func update_state(purchased: bool, active: bool, file_available: bool = true):
	is_purchased = purchased
	is_active = active
	_setup_item()
