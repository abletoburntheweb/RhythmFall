# scenes/shop/item_card.gd
extends PanelContainer

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
var is_new_reward: bool = false
const NEW_REWARD_BORDER_COLOR := Color("#F2B35A")

const _ACCENT_BY_CATEGORY := {
	"Кик": Color(0.38, 0.78, 0.74),
	"Обложки": Color(0.86, 0.52, 0.72),
	"Ноты": Color(0.52, 0.76, 0.92),
	"Подсветка линий": Color(0.62, 0.86, 0.72),
	"Все": Color(0.42, 0.57, 0.82),
}
var _achievements_data_cache = null
var _loader: ThreadedTextureLoader = null
var _loader_connected: bool = false
var _current_image_path: String = ""

@onready var _card_anim: AnimationPlayer = get_node_or_null("CardAnim")

func _ready():
	if not item_data.has("item_id"):
		visible = false
		queue_free()
		return

	_setup_item()

	custom_minimum_size = Vector2(280, 350)

	_update_card_pivot()
	if not resized.is_connected(_update_card_pivot):
		resized.connect(_update_card_pivot)
	_update_new_reward_visuals()


func set_new_reward_highlight(enabled: bool) -> void:
	is_new_reward = enabled
	if is_node_ready():
		_update_new_reward_visuals()

func _get_use_button() -> Button:
	return get_node_or_null("MarginContainer/ContentContainer/ButtonsContainer/TopButtonContainer/UseButton") as Button

func _get_open_reward_button() -> Button:
	return get_node_or_null("MarginContainer/ContentContainer/ButtonsContainer/TopButtonContainer/OpenRewardButton") as Button

func _is_reward_type_item() -> bool:
	return is_achievement_reward or is_level_reward or is_daily_reward

func _is_reward_unlocked_and_usable() -> bool:
	if is_level_reward:
		return level_unlocked
	if is_achievement_reward:
		return achievement_unlocked
	if is_daily_reward:
		return daily_unlocked
	return false

func _should_show_open_button() -> bool:
	return is_new_reward and _is_reward_type_item() and _is_reward_unlocked_and_usable() and not is_active

func _update_new_reward_visuals() -> void:
	if is_new_reward:
		var outline := StyleBoxFlat.new()
		outline.bg_color = Color(1.0, 0.97, 0.88, 0.08)
		outline.border_color = NEW_REWARD_BORDER_COLOR
		outline.set_border_width_all(3)
		outline.set_corner_radius_all(12)
		add_theme_stylebox_override("panel", outline)
	else:
		remove_theme_stylebox_override("panel")
	_apply_open_reward_button_state()
	if is_node_ready():
		_apply_card_style()

func _apply_open_reward_button_state() -> void:
	var use_button := _get_use_button()
	var open_button := _get_open_reward_button()
	if open_button == null:
		return
	if _should_show_open_button():
		open_button.visible = true
		if use_button:
			use_button.visible = false
	else:
		open_button.visible = false

func _maybe_mark_new_reward_seen() -> void:
	if not is_new_reward:
		return
	var item_id := str(item_data.get("item_id", ""))
	if item_id == "":
		return
	PlayerDataManager.mark_shop_reward_seen(item_id)
	set_new_reward_highlight(false)
	_update_buttons_and_status()

func _update_card_pivot() -> void:
	pivot_offset = size * 0.5

func _play_card_anim(anim_name: String) -> void:
	if _card_anim and _card_anim.has_animation(anim_name):
		_update_card_pivot()
		_card_anim.stop()
		_card_anim.play(anim_name)


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
		if item_data.get("category", "") == "Обложки":
			image_rect.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		else:
			image_rect.mouse_default_cursor_shape = Control.CURSOR_ARROW

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
	var user_path = "user://achievements_data.json"
	var path = user_path if FileAccess.file_exists(user_path) else "res://data/achievements_data.json"
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

	_apply_open_reward_button_state()
	_update_new_reward_visuals()
	_apply_card_style()


func _is_locked_reward_state() -> bool:
	if is_level_reward:
		return not level_unlocked
	if is_achievement_reward:
		return not achievement_unlocked
	if is_daily_reward:
		return not daily_unlocked
	return false


func _category_accent() -> Color:
	var category := str(item_data.get("category", ""))
	return _ACCENT_BY_CATEGORY.get(category, _ACCENT_BY_CATEGORY["Все"])


func _apply_card_style() -> void:
	if is_new_reward:
		_apply_preview_frame(_category_accent())
		return
	var accent := _category_accent()
	if is_active:
		theme_type_variation = &"CardActive"
		add_theme_stylebox_override("panel", _build_card_shell_style(accent, true))
	elif _is_locked_reward_state() and not is_purchased and not is_default:
		theme_type_variation = &"CardLocked"
		remove_theme_stylebox_override("panel")
	else:
		theme_type_variation = &"CardDefault"
		remove_theme_stylebox_override("panel")
	_apply_preview_frame(accent)
	_apply_status_label_style()


func _build_card_shell_style(accent: Color, active: bool) -> StyleBoxFlat:
	var shell := StyleBoxFlat.new()
	shell.bg_color = Color(0.13, 0.15, 0.19) if active else Color(0.11, 0.12, 0.16)
	shell.border_color = accent.lightened(0.08 if active else 0.0)
	shell.set_border_width_all(2 if active else 1)
	shell.set_corner_radius_all(12)
	shell.shadow_color = Color(accent.r, accent.g, accent.b, 0.22 if active else 0.0)
	shell.shadow_size = 8 if active else 0
	shell.shadow_offset = Vector2(0, 3)
	return shell


func _apply_preview_frame(accent: Color) -> void:
	var wrapper := get_node_or_null("MarginContainer/ContentContainer/ImageWrapper") as PanelContainer
	if wrapper == null:
		return
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.05, 0.06, 0.09)
	frame.border_color = Color(accent.r, accent.g, accent.b, 0.45)
	frame.border_width_top = 3
	frame.border_width_left = 1
	frame.border_width_right = 1
	frame.border_width_bottom = 1
	frame.set_corner_radius_all(10)
	frame.content_margin_left = 4.0
	frame.content_margin_top = 4.0
	frame.content_margin_right = 4.0
	frame.content_margin_bottom = 4.0
	wrapper.add_theme_stylebox_override("panel", frame)
	var image := wrapper.get_node_or_null("ImageRect") as TextureRect
	if image:
		image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _apply_status_label_style() -> void:
	var label := get_node_or_null("MarginContainer/ContentContainer/StatusDefaultHBox/StatusLabel") as Label
	var hbox := get_node_or_null("MarginContainer/ContentContainer/StatusDefaultHBox") as HBoxContainer
	if label == null or hbox == null or not hbox.visible:
		return
	if is_active:
		label.add_theme_color_override("font_color", Color(0.55, 0.92, 0.86))
		label.add_theme_color_override("font_outline_color", Color(0.12, 0.28, 0.24))
		label.add_theme_constant_override("outline_size", 4)
	elif is_default:
		label.add_theme_color_override("font_color", Color(0.72, 0.82, 0.96))
		label.add_theme_color_override("font_outline_color", Color(0.14, 0.2, 0.32))
		label.add_theme_constant_override("outline_size", 4)


func _on_buy_pressed():
	var item_id_str = item_data.get("item_id", "")
	_play_card_anim("buy_pop")
	emit_signal("buy_pressed", item_id_str)

func _on_use_pressed():
	var item_id_str = item_data.get("item_id", "")
	_play_card_anim("buy_pop")
	emit_signal("use_pressed", item_id_str)

func _on_open_reward_pressed():
	if MusicManager and MusicManager.has_method("play_shop_apply"):
		MusicManager.play_shop_apply()
	_play_card_anim("buy_pop")
	_maybe_mark_new_reward_seen()

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
		if _should_show_open_button():
			btn.visible = false
		else:
			btn.visible = visible
			if visible:
				btn.text = "Использовать"

func _set_status(hbox: HBoxContainer, lbl: Label, visible: bool, text: String) -> void:
	if hbox:
		hbox.visible = visible
	if visible and lbl:
		lbl.text = text
