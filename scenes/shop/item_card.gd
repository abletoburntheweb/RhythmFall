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

var is_achievement_reward: bool = false
var achievement_required: String = ""
var achievement_name: String = "" 
var achievement_unlocked: bool = false

var is_level_reward: bool = false
var required_level: int = 0
var level_unlocked: bool = false
var _pending_load_path: String = ""

func _ready():
	if not item_data.has("item_id"):
		return

	var buy_button = $MarginContainer/ContentContainer/ButtonsContainer/TopButtonContainer/BuyButton
	if buy_button:
		buy_button.pressed.connect(_on_buy_pressed)

	var use_button = $MarginContainer/ContentContainer/ButtonsContainer/TopButtonContainer/UseButton
	if use_button:
		use_button.pressed.connect(_on_use_pressed)

	var preview_button = $MarginContainer/ContentContainer/ButtonsContainer/PreviewButton
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
	is_default = item_data.get("is_default", false)

	is_achievement_reward = item_data.get("is_achievement_reward", false)
	achievement_required = item_data.get("achievement_required", "")
	
	is_level_reward = item_data.get("is_level_reward", false)
	required_level = item_data.get("required_level", 0)

	var image_rect = $MarginContainer/ContentContainer/ImageRect
	var name_label = $MarginContainer/ContentContainer/NameLabel
	var status_label = $MarginContainer/ContentContainer/StatusLabel

	if status_label:
		status_label.visible = false

	var image_path = item_data.get("image", "") 
	var images_folder = item_data.get("images_folder", "")
	var category = item_data.get("category", "")
	var color_hex = item_data.get("color_hex", "")
	var note_colors = item_data.get("note_colors", [])
	var texture = null
	var image_loaded_successfully = false

	if category == "Подсветка линий" and color_hex != "":
		var hex_color = Color(color_hex)
		texture = _create_color_texture(hex_color)
		if texture:
			image_rect.texture = texture
			image_loaded_successfully = true
	elif category == "Ноты" and not note_colors.is_empty():
		texture = _create_note_preview_texture(note_colors)
		if texture:
			image_rect.texture = texture
			image_loaded_successfully = true
	elif image_path != "":
		if FileAccess.file_exists(image_path):
			_pending_load_path = image_path
			_create_placeholder_with_text()
			_request_threaded_load(image_path)
	elif images_folder != "":
		var cover_path = images_folder + "/cover1.png"

		if FileAccess.file_exists(cover_path):
			_pending_load_path = cover_path
			_create_placeholder_with_text()
			_request_threaded_load(cover_path)
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

func _request_threaded_load(path: String) -> void:
	var req_ok = ResourceLoader.load_threaded_request(path, "Texture2D")
	if req_ok == OK:
		set_process(true)
	else:
		var tex = ResourceLoader.load(path, "Texture2D")
		if tex and tex is Texture2D:
			var image_rect = $MarginContainer/ContentContainer/ImageRect
			if image_rect:
				image_rect.texture = tex
				image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
				image_rect.visible = true
		_pending_load_path = ""

func _process(delta):
	if _pending_load_path != "":
		var status = ResourceLoader.load_threaded_get_status(_pending_load_path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var res = ResourceLoader.load_threaded_get(_pending_load_path)
			if res and res is Texture2D:
				var image_rect = $MarginContainer/ContentContainer/ImageRect
				if image_rect:
					image_rect.texture = res
					image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
					image_rect.visible = true
			_pending_load_path = ""
			set_process(false)
		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			_pending_load_path = ""
			set_process(false)


func _create_color_texture(color: Color) -> Texture2D:
	var image = Image.create(240, 180, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _create_note_preview_texture(colors: Array) -> Texture2D:
	var width = 240
	var height = 180
	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	
	if colors.size() == 1:
		var color = Color(colors[0])
		image.fill(color)
	elif colors.size() == 5:
		var stripe_width = width / 5
		for i in range(5):
			var color = Color(colors[i])
			var rect = Rect2i(i * stripe_width, 0, stripe_width, height)
			image.fill_rect(rect, color)
	else:
		image.fill(Color(0.5, 0.5, 0.5, 1.0)) 
		
	return ImageTexture.create_from_image(image)



func _create_placeholder_with_text():
	var image_rect = $MarginContainer/ContentContainer/ImageRect
	if image_rect:
		var category = item_data.get("category", "")
		var color_hex = item_data.get("color_hex", "")
		var note_colors = item_data.get("note_colors", [])
		
		if category == "Подсветка линий" and color_hex != "":
			var hex_color = Color(color_hex)
			var color_texture = _create_color_texture(hex_color)
			image_rect.texture = color_texture
		elif category == "Ноты" and not note_colors.is_empty():
			var texture = _create_note_preview_texture(note_colors)
			image_rect.texture = texture
		else:
			var placeholder_width = 240 
			var placeholder_height = 180 

			var placeholder_image = Image.create(placeholder_width, placeholder_height, false, Image.FORMAT_RGBA8)
			placeholder_image.fill(Color(0.5, 0.5, 0.5, 1.0)) 
			var placeholder_texture = ImageTexture.create_from_image(placeholder_image)

			image_rect.texture = placeholder_texture


func _update_buttons_and_status():
	var buy_button = $MarginContainer/ContentContainer/ButtonsContainer/TopButtonContainer/BuyButton
	var achievement_button = $MarginContainer/ContentContainer/ButtonsContainer/TopButtonContainer/AchievementRewardButton 
	var level_reward_button = $MarginContainer/ContentContainer/ButtonsContainer/TopButtonContainer/LevelRewardButton 
	var use_button = $MarginContainer/ContentContainer/ButtonsContainer/TopButtonContainer/UseButton
	var preview_button = $MarginContainer/ContentContainer/ButtonsContainer/PreviewButton
	var status_label = $MarginContainer/ContentContainer/StatusLabel

	if is_level_reward:
		buy_button.visible = false
		achievement_button.visible = false
		
		var audio_path = item_data.get("audio", "")
		preview_button.visible = audio_path != ""
		if preview_button.visible:
			preview_button.text = "🔊 Прослушать"

		if level_unlocked:
			level_reward_button.visible = false
			use_button.visible = not is_active
			if use_button.visible:
				use_button.text = "✅ Использовать"
			status_label.visible = is_active
			if is_active:
				status_label.text = "✅ Используется"
		else:
			level_reward_button.visible = true
			level_reward_button.text = "Уровень %d 🔒" % required_level
			level_reward_button.disabled = true 
			use_button.visible = false
			status_label.visible = false

	elif is_achievement_reward:
		buy_button.visible = false
		level_reward_button.visible = false  
		
		var audio_path = item_data.get("audio", "")
		preview_button.visible = audio_path != ""
		if preview_button.visible:
			preview_button.text = "🔊 Прослушать"

		if achievement_unlocked:
			achievement_button.visible = false
			use_button.visible = not is_active
			if use_button.visible:
				use_button.text = "✅ Использовать"
			status_label.visible = is_active
			if is_active:
				status_label.text = "✅ Используется"
		else:
			achievement_button.visible = true
			var display_name = achievement_name if achievement_name != "" else "Награда за ачивку"
			achievement_button.text = display_name + " 🔒"  
			achievement_button.disabled = true 
			use_button.visible = false
			status_label.visible = false

	else:
		achievement_button.visible = false
		level_reward_button.visible = false
		
		buy_button.visible = not is_purchased and not is_default
		if buy_button.visible:
			var price = item_data.get("price", 0)
			buy_button.text = "Купить за %d 💰" % price

		var show_use_button = (is_purchased and not is_active) or (is_default and not is_active)
		use_button.visible = show_use_button
		if use_button.visible:
			use_button.text = "✅ Использовать"

		var audio_path = item_data.get("audio", "")
		preview_button.visible = audio_path != ""
		if preview_button.visible:
			preview_button.text = "🔊 Прослушать"

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

func update_state(purchased: bool, active: bool, file_available: bool = true, achievement_unlocked_param: bool = false, achievement_name_param: String = "", level_unlocked_param: bool = false):
	is_purchased = purchased
	is_active = active
	self.achievement_unlocked = achievement_unlocked_param
	self.achievement_name = achievement_name_param
	self.is_achievement_reward = item_data.get("is_achievement_reward", false)
	self.level_unlocked = level_unlocked_param
	self.is_level_reward = item_data.get("is_level_reward", false)
	
	if is_level_reward and level_unlocked_param:
		is_purchased = true 
	elif is_achievement_reward and achievement_unlocked_param:
		is_purchased = true 
	
	_setup_item() 
