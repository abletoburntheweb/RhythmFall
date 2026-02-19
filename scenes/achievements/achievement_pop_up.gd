# scenes/achievements/achievement_pop_up.gd
extends PanelContainer

signal popup_finished

@onready var animation_player: AnimationPlayer = $AnimationPlayer
var achievement_data: Dictionary = {}
var _is_ready: bool = false

func _ready():
	_is_ready = true
	
	if not achievement_data.is_empty():
		call_deferred("show_popup")

func set_achievement_data(ach_data: Dictionary):
	
	achievement_data = ach_data.duplicate()
	
	var title_label = get_node_or_null("ContentContainer/TopRowContainer/InfoVBox/AchievementTitleLabel")
	var description_label = get_node_or_null("ContentContainer/TopRowContainer/InfoVBox/DescriptionLabel")
	var icon_texture = get_node_or_null("ContentContainer/TopRowContainer/IconTexture")
	
	if title_label:
		var new_title = ach_data.get("title", "Название отсутствует")
		title_label.text = new_title
	else:
		printerr("[AchievementPopUp] ERROR: title_label is NULL!")
	
	if description_label:
		var new_desc = ach_data.get("description", "Описание отсутствует")
		description_label.text = new_desc
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
	
	if image_path and image_path != "" and FileAccess.file_exists(image_path):
		var texture = ResourceLoader.load(image_path)
		if texture and texture is Texture2D:
			icon_texture.texture = texture
			return

	var fallback_path = ""
	
	match category:
		"mastery": fallback_path = "res://assets/achievements/mastery.png"
		"drums": fallback_path = "res://assets/achievements/drums.png"
		"genres":  fallback_path = "res://assets/achievements/genres.png"  
		"system": fallback_path = "res://assets/achievements/system.png"
		"shop": fallback_path = "res://assets/achievements/shop.png"
		"economy": fallback_path = "res://assets/achievements/economy.png"
		"daily": fallback_path = "res://assets/achievements/daily.png"
		"playtime": fallback_path = "res://assets/achievements/playtime.png"
		"events": fallback_path = "res://assets/achievements/events.png"
		_: fallback_path = "res://assets/achievements/default.png" 
	
	if FileAccess.file_exists(fallback_path):
		var texture = ResourceLoader.load(fallback_path)
		if texture and texture is Texture2D:
			icon_texture.texture = texture
			return
	
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
		if FileAccess.file_exists(path):
			var texture = ResourceLoader.load(path)
			if texture and texture is Texture2D:
				icon_texture.texture = texture
				return
	
	icon_texture.texture = null

func show_popup():
	
	if not is_inside_tree() or not _is_ready:
		printerr("[AchievementPopUp] ERROR: Not ready or not in scene tree!")
		return
	
	var has_popup_animation = false
	if animation_player:
		has_popup_animation = animation_player.has_animation("popup_show")
	
	if animation_player and has_popup_animation:
		animation_player.play("popup_show")
		if not animation_player.animation_finished.is_connected(_on_animation_player_animation_finished):
			animation_player.animation_finished.connect(_on_animation_player_animation_finished)
	else:
		visible = true
		if get_tree():
			get_tree().create_timer(3.0).timeout.connect(_on_timer_timeout, CONNECT_ONE_SHOT)
		else:
			printerr("[AchievementPopUp] ERROR: No scene tree available!")

func _on_animation_player_animation_finished(anim_name: String):
	if anim_name == "popup_show":
		if get_tree():
			get_tree().create_timer(2.0).timeout.connect(_on_display_timeout, CONNECT_ONE_SHOT)
		else:
			_on_display_timeout()

func _on_display_timeout():
	popup_finished.emit()
	
	call_deferred("queue_free")

func _on_timer_timeout():
	popup_finished.emit()
	
	call_deferred("queue_free")
