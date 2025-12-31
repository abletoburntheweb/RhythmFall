# scenes/achievements/achievement_pop_up.gd
extends PanelContainer

signal popup_finished

@onready var animation_player: AnimationPlayer = $AnimationPlayer
var achievement_data: Dictionary = {}
var _is_ready: bool = false

func _ready():
	_is_ready = true
	print("🎯 AchievementPopUp готов, animation_player: ", animation_player)
	
	if not achievement_data.is_empty():
		call_deferred("show_popup")

func set_achievement_data(ach_data: Dictionary):
	print("=== set_achievement_data called ===")
	print("Achievement data: ", ach_data)
	
	achievement_data = ach_data.duplicate()
	
	var title_label = get_node_or_null("ContentContainer/TopRowContainer/InfoVBox/AchievementTitleLabel")
	var description_label = get_node_or_null("ContentContainer/TopRowContainer/InfoVBox/DescriptionLabel")
	var icon_texture = get_node_or_null("ContentContainer/TopRowContainer/IconTexture")
	
	print("Looking for title_label: ", title_label)
	print("Looking for description_label: ", description_label)
	print("Looking for icon_texture: ", icon_texture)
	
	if title_label:
		var new_title = ach_data.get("title", "Название отсутствует")
		print("Setting title to: ", new_title)
		title_label.text = new_title
		print("Title after setting: ", title_label.text)
	else:
		printerr("[AchievementPopUp] ERROR: title_label is NULL!")
	
	if description_label:
		var new_desc = ach_data.get("description", "Описание отсутствует")
		print("Setting description to: ", new_desc)
		description_label.text = new_desc
		print("Description after setting: ", description_label.text)
	else:
		printerr("[AchievementPopUp] ERROR: description_label is NULL!")
	
	_load_achievement_icon(ach_data)
	
	if _is_ready:
		call_deferred("show_popup")

func _load_achievement_icon(ach_data: Dictionary):
	var icon_texture = get_node_or_null("ContentContainer/TopRowContainer/IconTexture")
	if not icon_texture:
		printerr("[AchievementPopUp] ERROR: icon_texture is NULL!")
		return
	
	var image_path = ach_data.get("image", "")
	var category = ach_data.get("category", "")
	
	print("🖼️ Загрузка иконки: путь='", image_path, "', категория='", category, "'")

	if image_path and image_path != "" and FileAccess.file_exists(image_path):
		var texture = ResourceLoader.load(image_path)
		if texture and texture is Texture2D:
			icon_texture.texture = texture
			print("✅ Иконка загружена успешно по указанному пути: ", image_path)
			return
		else:
			print("❌ Не удалось загрузить текстуру из указанного пути: ", image_path, " Тип: ", typeof(texture), " Успешно загружено: ", texture != null)
	else:
		print("🖼️ Файл иконки по указанному пути не найден: ", image_path)

	var fallback_path = ""
	
	match category:
		"gameplay": fallback_path = "res://assets/achievements/gameplay.png"
		"system": fallback_path = "res://assets/achievements/system.png"
		"shop": fallback_path = "res://assets/achievements/shop.png"
		"economy": fallback_path = "res://assets/achievements/economy.png"
		"daily": fallback_path = "res://assets/achievements/daily.png"
		"playtime": fallback_path = "res://assets/achievements/playtime.png"
		"events": fallback_path = "res://assets/achievements/events.png" 
		_: fallback_path = "res://assets/achievements/default.png" 
	
	print("🖼️ Пробуем загрузить fallback иконку по категории: ", fallback_path)
	
	if FileAccess.file_exists(fallback_path):
		var texture = ResourceLoader.load(fallback_path)
		if texture and texture is Texture2D:
			icon_texture.texture = texture
			print("✅ Fallback иконка по категории загружена: ", fallback_path)
			return
		else:
			print("❌ Не удалось загрузить fallback текстуру: ", fallback_path, " Тип: ", typeof(texture), " Успешно загружено: ", texture != null)
	else:
		print("❌ Fallback файл не существует: ", fallback_path)
	
	print("⚠️ Все пути к иконкам недоступны, устанавливаем null")
	icon_texture.texture = null

func _load_default_icon():
	var icon_texture = get_node_or_null("ContentContainer/TopRowContainer/IconTexture")
	if not icon_texture:
		return
	
	var default_paths = [
		"res://assets/achievements/default.png",
		"res://assets/achievements/login_1_day.png" 
	]
	
	for path in default_paths:
		print("🖼️ Пробуем загрузить дефолтную иконку: ", path)
		if FileAccess.file_exists(path):
			var texture = ResourceLoader.load(path)
			if texture and texture is Texture2D:
				icon_texture.texture = texture
				print("✅ Дефолтная иконка загружена: ", path)
				return
			else:
				print("❌ Не удалось загрузить текстуру: ", path, " Тип: ", typeof(texture), " Успешно загружено: ", texture != null)
		else:
			print("❌ Путь не существует (FileAccess): ", path)
	
	print("⚠️ Все пути к иконкам недоступны, устанавливаем null")
	icon_texture.texture = null

func show_popup():
	print("=== show_popup called ===")
	print("Is ready: ", _is_ready)
	print("Animation player: ", animation_player)
	
	if not is_inside_tree() or not _is_ready:
		printerr("[AchievementPopUp] ERROR: Not ready or not in scene tree!")
		return
	
	var has_popup_animation = false
	if animation_player:
		print("Animation libraries: ", animation_player.get_animation_list())
		has_popup_animation = animation_player.has_animation("popup_show")
		print("Has animation 'popup_show': ", has_popup_animation)
	
	if animation_player and has_popup_animation:
		print("🎯 Запускаем анимацию popup_show")
		animation_player.play("popup_show")
		if not animation_player.animation_finished.is_connected(_on_animation_player_animation_finished):
			animation_player.animation_finished.connect(_on_animation_player_animation_finished)
	else:
		print("🎯 Анимация не найдена, используем fallback")
		visible = true
		if get_tree():
			get_tree().create_timer(3.0).timeout.connect(_on_timer_timeout, CONNECT_ONE_SHOT)
		else:
			printerr("[AchievementPopUp] ERROR: No scene tree available!")

func _on_animation_player_animation_finished(anim_name: String):
	print("=== Animation finished: ", anim_name, " ===")
	if anim_name == "popup_show":
		if get_tree():
			get_tree().create_timer(2.0).timeout.connect(_on_display_timeout, CONNECT_ONE_SHOT)
		else:
			_on_display_timeout()

func _on_display_timeout():
	print("=== Emitting popup_finished signal ===")
	popup_finished.emit()
	
	call_deferred("queue_free")

func _on_timer_timeout():
	print("=== Timer timeout, emitting popup_finished ===")
	popup_finished.emit()
	
	call_deferred("queue_free")
