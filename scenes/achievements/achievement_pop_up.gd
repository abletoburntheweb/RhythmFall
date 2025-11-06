# scenes/achievements/achievement_pop_up.gd
extends PanelContainer

@onready var animation_player = $AnimationPlayer
var achievement_data: Dictionary = {}

func set_achievement_data(ach_data: Dictionary):
	print("=== set_achievement_data called ===")
	print("Achievement data: ", ach_data)
	
	achievement_data = ach_data.duplicate()
	
	var title_label = get_node("ContentContainer/TopRowContainer/InfoVBox/AchievementTitleLabel")
	var description_label = get_node("ContentContainer/TopRowContainer/InfoVBox/DescriptionLabel")
	var icon_texture = get_node("ContentContainer/TopRowContainer/IconTexture")
	
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
	
	if icon_texture and ach_data.has("image"):
		var icon_path = ach_data.image
		print("Loading icon from: ", icon_path)
		
		if ResourceLoader.exists(icon_path):
			var texture = ResourceLoader.load(icon_path)
			if texture:
				icon_texture.texture = texture
				print("Icon texture loaded successfully")
			else:
				printerr("ERROR: Failed to load texture from: ", icon_path)
				_load_default_icon()
		else:
			printerr("ERROR: Icon path doesn't exist: ", icon_path)
			_load_default_icon()
	else:
		print("No image in achievement data or icon_texture is null")
		_load_default_icon()

func _load_default_icon():
	var icon_texture = get_node("ContentContainer/TopRowContainer/IconTexture")
	if icon_texture:
		var default_path = "res://assets/achievements/default2.png"
		if ResourceLoader.exists(default_path):
			var texture = ResourceLoader.load(default_path)
			if texture:
				icon_texture.texture = texture
				print("Default icon loaded successfully")
			else:
				printerr("ERROR: Failed to load default icon: ", default_path)
		else:
			printerr("ERROR: Default icon path doesn't exist: ", default_path)

func show_popup():
	print("=== show_popup called ===")
	print("Animation player: ", animation_player)
	print("Has animation 'popup_show': ", animation_player and animation_player.has_animation("popup_show"))
	
	if animation_player and animation_player.has_animation("popup_show"):
		animation_player.play("popup_show")
	else:
		printerr("[AchievementPopUp] ERROR: Animation 'popup_show' not found!")
		visible = true

func _on_animation_player_animation_finished(anim_name: String):
	print("=== Animation finished: ", anim_name, " ===")
	queue_free()
