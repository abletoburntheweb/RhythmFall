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
var is_daily_reward: bool = false
var required_daily_completed: int = 0
var daily_unlocked: bool = false
var _achievements_data_cache = null
var _loader: ThreadedTextureLoader = null
var _loader_connected: bool = false
var _current_image_path: String = ""

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

	var image_rect = $MarginContainer/ContentContainer/ImageWrapper/ImageRect
	var name_label = $MarginContainer/ContentContainer/NameLabel
	var status_hbox = get_node_or_null("MarginContainer/ContentContainer/StatusDefaultHBox")
	var status_label = get_node_or_null("MarginContainer/ContentContainer/StatusDefaultHBox/StatusLabel")

	if status_hbox:
		status_hbox.visible = false

	_apply_initial_image()

	if image_rect:
		image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image_rect.visible = true 

	if name_label:
		_set_name_label(name_label)

	_update_buttons_and_status()

func _update_preview_button(preview_button):
	var audio_path = item_data.get("audio", "")
	preview_button.visible = audio_path != ""
	if preview_button.visible:
		preview_button.text = "Прослушать"

func _request_threaded_load(path: String) -> void:
	_current_image_path = path
	if _loader == null:
		var loader_script = preload("res://logic/utils/threaded_texture_loader.gd")
		_loader = loader_script.get_instance()
	if _loader and not _loader_connected:
		_loader.loaded.connect(_on_loader_loaded)
		_loader_connected = true
	if _loader:
		_loader.request(path)

func _process(delta):
	pass

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
	var image_rect = $MarginContainer/ContentContainer/ImageWrapper/ImageRect
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
			pass


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
			_set_use_button(use_button, not is_active)
			_set_status(status_hbox, status_label, is_active, "Используется")
		else:
			level_reward_button.visible = true
			level_reward_button.text = "Уровень %d" % required_level
			level_reward_button.disabled = true 
			if level_reward_button:
				var current_level = PlayerDataManager.get_current_level()
				level_reward_button.tooltip_text = "Достигните %d/%d уровня" % [current_level, required_level]
			_set_use_button(use_button, false)
			_set_status(status_hbox, status_label, false, "")

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
			_set_use_button(use_button, not is_active)
			_set_status(status_hbox, status_label, is_active, "Используется")
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
			_set_use_button(use_button, false)
			_set_status(status_hbox, status_label, false, "")
	elif is_daily_reward:
		buy_button.visible = false
		level_reward_button.visible = false
		achievement_button.visible = false
		_update_preview_button(preview_button)
		if daily_unlocked:
			if daily_reward_button:
				daily_reward_button.visible = false
				daily_reward_button.tooltip_text = ""
			_set_use_button(use_button, not is_active)
			_set_status(status_hbox, status_label, is_active, "Используется")
		else:
			if daily_reward_button:
				daily_reward_button.visible = true
				daily_reward_button.text = "Ежедневки: %d" % required_daily_completed
				daily_reward_button.disabled = true
				var completed = PlayerDataManager.get_daily_quests_completed_total()
				daily_reward_button.tooltip_text = "Завершите %d/%d ежедневных заданий" % [completed, required_daily_completed]
			_set_use_button(use_button, false)
			_set_status(status_hbox, status_label, false, "")
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
		_set_use_button(use_button, show_use_button)
		_update_preview_button(preview_button)

		if is_active:
			_set_status(status_hbox, status_label, true, "Используется")
		elif is_default:
			_set_status(status_hbox, status_label, true, "Стандартный")
		else:
			_set_status(status_hbox, status_label, false, "")


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

func _apply_initial_image() -> void:
	var image_rect = $MarginContainer/ContentContainer/ImageWrapper/ImageRect
	if image_rect == null:
		return
	var image_path = item_data.get("image", "") 
	var images_folder = item_data.get("images_folder", "")
	var category = item_data.get("category", "")
	var color_hex = item_data.get("color_hex", "")
	var note_colors = item_data.get("note_colors", [])
	if category == "Подсветка линий" and color_hex != "":
		var hex_color = Color(color_hex)
		var texture = _create_color_texture(hex_color)
		if texture:
			image_rect.texture = texture
			return
	if category == "Ноты" and not note_colors.is_empty():
		var texture2 = _create_note_preview_texture(note_colors)
		if texture2:
			image_rect.texture = texture2
			return
	if image_path != "" and FileAccess.file_exists(image_path):
		_create_placeholder_with_text()
		_request_threaded_load(image_path)
		return
	if images_folder != "":
		var cover_path = images_folder + "/cover1.png"
		if FileAccess.file_exists(cover_path):
			_create_placeholder_with_text()
			_request_threaded_load(cover_path)
			return
	_create_placeholder_with_text()

func _on_loader_loaded(p: String, tex: Texture2D) -> void:
	if p != _current_image_path:
		return
	var image_rect = get_node_or_null("MarginContainer/ContentContainer/ImageWrapper/ImageRect")
	if image_rect and tex:
		image_rect.texture = tex
		image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image_rect.visible = true
	_current_image_path = ""

func _exit_tree():
	if _loader and _loader_connected:
		_loader.loaded.disconnect(_on_loader_loaded)
		_loader_connected = false
func _set_name_label(lbl: Label) -> void:
	var item_name = item_data.get("name", "Без названия")
	lbl.text = item_name
	lbl.visible = true

func _set_use_button(btn: Button, visible: bool) -> void:
	if btn:
		btn.visible = visible
		if visible:
			btn.text = "Использовать"

func _set_status(hbox: HBoxContainer, lbl: Label, visible: bool, text: String) -> void:
	if hbox:
		hbox.visible = visible
	if visible and lbl:
		lbl.text = text
