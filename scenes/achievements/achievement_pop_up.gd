# scenes/achievements/achievement_pop_up.gd
extends PanelContainer

signal popup_finished

@onready var animation_player: AnimationPlayer = $PopupAnimator
var achievement_data: Dictionary = {}

func _ready():
	if not achievement_data.is_empty():
		show_popup()

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
	
	if is_inside_tree():
		show_popup()

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


func show_popup():
	if animation_player:
		animation_player.play("popup_show")
		if not animation_player.animation_finished.is_connected(_on_animation_player_animation_finished):
			animation_player.animation_finished.connect(_on_animation_player_animation_finished)

func _on_animation_player_animation_finished(anim_name: String):
	if anim_name == "popup_show":
		_on_display_timeout()

func _on_display_timeout():
	popup_finished.emit()
	
	call_deferred("queue_free")
