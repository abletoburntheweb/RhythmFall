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
var is_daily_reward: bool = false
var required_daily_completed: int = 0
var daily_unlocked: bool = false
var _achievements_data_cache = null

func _ready():
	if not item_data.has("item_id"):
		return

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
	is_daily_reward = item_data.get("is_daily_reward", false)
	required_daily_completed = item_data.get("required_daily_completed", 0)

	var image_rect = $MarginContainer/ContentContainer/ImageRect
	var name_label = $MarginContainer/ContentContainer/NameLabel
	var status_hbox = get_node_or_null("MarginContainer/ContentContainer/StatusDefaultHBox")
	var status_label = get_node_or_null("MarginContainer/ContentContainer/StatusDefaultHBox/StatusLabel")

	if status_hbox:
		status_hbox.visible = false

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

func _update_preview_button(preview_button):
	var audio_path = item_data.get("audio", "")
	preview_button.visible = audio_path != ""
	if preview_button.visible:
		preview_button.text = "Прослушать"

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

func _get_achievements_data():
	var path = "res://data/achievements_data.json"
	if _achievements_data_cache != null:
		return _achievements_data_cache
	if not FileAccess.file_exists(path):
		return null
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if not (parsed and parsed.has("achievements")):
		return null
	_achievements_data_cache = parsed.achievements
	return _achievements_data_cache

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
	var daily_reward_button = $MarginContainer/ContentContainer/ButtonsContainer/TopButtonContainer/DailyRewardButton
	var use_button = $MarginContainer/ContentContainer/ButtonsContainer/TopButtonContainer/UseButton
	var preview_button = $MarginContainer/ContentContainer/ButtonsContainer/PreviewButton
	var status_hbox = get_node_or_null("MarginContainer/ContentContainer/StatusDefaultHBox")
	var status_label = get_node_or_null("MarginContainer/ContentContainer/StatusDefaultHBox/StatusLabel")
	
	if achievement_button:
		achievement_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		achievement_button.size_flags_stretch_ratio = 1
	if level_reward_button:
		level_reward_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		level_reward_button.size_flags_stretch_ratio = 1
	if daily_reward_button:
		daily_reward_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		daily_reward_button.size_flags_stretch_ratio = 1

	if is_level_reward:
		buy_button.visible = false
		achievement_button.visible = false
		if daily_reward_button:
			daily_reward_button.visible = false
		_update_preview_button(preview_button)

		if level_unlocked:
			level_reward_button.visible = false
			use_button.visible = not is_active
			if use_button.visible:
				use_button.text = "Использовать"
			if status_hbox:
				status_hbox.visible = is_active
			if is_active and status_label:
				status_label.text = "Используется"
		else:
			level_reward_button.visible = true
			level_reward_button.text = "Уровень %d" % required_level
			level_reward_button.disabled = true 
			if level_reward_button:
				var current_level = PlayerDataManager.get_current_level()
				level_reward_button.tooltip_text = "Достигните %d/%d уровня" % [current_level, required_level]
			use_button.visible = false
			if status_hbox:
				status_hbox.visible = false

	elif is_achievement_reward:
		buy_button.visible = false
		level_reward_button.visible = false  
		if daily_reward_button:
			daily_reward_button.visible = false
		_update_preview_button(preview_button)

		if achievement_unlocked:
			achievement_button.visible = false
			if achievement_button:
				achievement_button.tooltip_text = ""
			use_button.visible = not is_active
			if use_button.visible:
				use_button.text = "Использовать"
			if status_hbox:
				status_hbox.visible = is_active
			if is_active and status_label:
				status_label.text = "Используется"
		else:
			achievement_button.visible = true
			var display_name = achievement_name if achievement_name != "" else "Награда за ачивку"
			achievement_button.text = display_name 
			achievement_button.disabled = true 
			if achievement_button:
				var ach_desc = _get_achievement_description_by_id(achievement_required)
				var prog = _get_achievement_progress_by_id(achievement_required)
				var cur = int(prog.get("current", 0))
				var tot = int(prog.get("total", 0))
				if ach_desc == "":
					ach_desc = "Выполните достижение"
				if tot > 0:
					achievement_button.tooltip_text = "%s (%d/%d)" % [ach_desc, cur, tot]
				else:
					achievement_button.tooltip_text = ach_desc
			use_button.visible = false
			if status_hbox:
				status_hbox.visible = false
	elif is_daily_reward:
		buy_button.visible = false
		level_reward_button.visible = false
		achievement_button.visible = false
		_update_preview_button(preview_button)
		if daily_unlocked:
			if daily_reward_button:
				daily_reward_button.visible = false
				daily_reward_button.tooltip_text = ""
			use_button.visible = not is_active
			if use_button.visible:
				use_button.text = "Использовать"
			if status_hbox:
				status_hbox.visible = is_active
			if is_active and status_label:
				status_label.text = "Используется"
		else:
			if daily_reward_button:
				daily_reward_button.visible = true
				daily_reward_button.text = "Ежедневки: %d" % required_daily_completed
				daily_reward_button.disabled = true
				var completed = 0
				completed = PlayerDataManager.get_daily_quests_completed_total()
				daily_reward_button.tooltip_text = "Завершите %d/%d ежедневных заданий" % [completed, required_daily_completed]
			use_button.visible = false
			if status_hbox:
				status_hbox.visible = false

	else:
		achievement_button.visible = false
		level_reward_button.visible = false
		if daily_reward_button:
			daily_reward_button.visible = false
		
		buy_button.visible = not is_purchased and not is_default
		if buy_button.visible:
			var price = item_data.get("price", 0)
			buy_button.text = "Купить за %d" % price

		var show_use_button = (is_purchased and not is_active) or (is_default and not is_active)
		use_button.visible = show_use_button
		if use_button.visible:
			use_button.text = "Использовать"

		_update_preview_button(preview_button)

		if status_hbox:
			status_hbox.visible = false
		if is_active and status_label and status_hbox:
			status_label.text = "Используется"
			status_hbox.visible = true
		elif is_default and status_label and status_hbox:
			status_label.text = "Стандартный"
			status_hbox.visible = true


func _on_buy_pressed():
	var item_id_str = item_data.get("item_id", "")
	emit_signal("buy_pressed", item_id_str)

func _on_use_pressed():
	var item_id_str = item_data.get("item_id", "")
	emit_signal("use_pressed", item_id_str)

func _on_preview_pressed():
	var item_id_str = item_data.get("item_id", "") 
	emit_signal("preview_pressed", item_id_str)
	
func update_state(purchased: bool, active: bool, file_available: bool = true, achievement_unlocked_param: bool = false, achievement_name_param: String = "", level_unlocked_param: bool = false, daily_unlocked_param: bool = false):
	is_purchased = purchased
	is_active = active
	self.achievement_unlocked = achievement_unlocked_param
	self.achievement_name = achievement_name_param
	self.is_achievement_reward = item_data.get("is_achievement_reward", false)
	self.level_unlocked = level_unlocked_param
	self.is_level_reward = item_data.get("is_level_reward", false)
	self.daily_unlocked = daily_unlocked_param
	self.is_daily_reward = item_data.get("is_daily_reward", false)
	
	if is_level_reward and level_unlocked_param:
		is_purchased = true 
	elif is_achievement_reward and achievement_unlocked_param:
		is_purchased = true 
	elif is_daily_reward and daily_unlocked_param:
		is_purchased = true 
	
	_setup_item() 
	
func _get_achievement_description_by_id(achievement_id_str: String) -> String:
	if achievement_id_str == "" or not achievement_id_str.is_valid_int():
		return ""
	var achievements = _get_achievements_data()
	if not achievements:
		return ""
	var id_val = int(achievement_id_str)
	for a in achievements:
		if a is Dictionary:
			var aid = int(a.get("id", -1))
			if aid == id_val:
				return String(a.get("description", ""))
	return ""

func _get_achievement_progress_by_id(achievement_id_str: String) -> Dictionary:
	if achievement_id_str == "" or not achievement_id_str.is_valid_int():
		return {"current": 0, "total": 0}
	var achievements = _get_achievements_data()
	if not achievements:
		return {"current": 0, "total": 0}
	var id_val = int(achievement_id_str)
	for a in achievements:
		if a is Dictionary:
			var aid = int(a.get("id", -1))
			if aid == id_val:
				return {"current": int(a.get("current", 0)), "total": int(a.get("total", 0))}
	return {"current": 0, "total": 0}
