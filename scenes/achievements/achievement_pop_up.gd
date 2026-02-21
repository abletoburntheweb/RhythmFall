# scenes/achievements/achievement_pop_up.gd
extends PanelContainer

signal popup_finished

@onready var animation_player: AnimationPlayer = $PopupAnimator
@onready var title_label: Label = $ContentContainer/TopRowContainer/InfoVBox/AchievementTitleLabel
@onready var description_label: Label = $ContentContainer/TopRowContainer/InfoVBox/DescriptionLabel
@onready var icon_texture_rect: TextureRect = $ContentContainer/TopRowContainer/IconTexture
var achievement_data: Dictionary = {}

func _ready():
	if not achievement_data.is_empty():
		_apply_data()

func set_achievement_data(ach_data: Dictionary):
	achievement_data = ach_data.duplicate()
	if is_inside_tree():
		_apply_data()

func _load_achievement_icon(ach_data: Dictionary):
	var image_path = ach_data.get("image", "")
	if image_path == "":
		var fallback_path = _get_fallback_icon_path(ach_data.get("category", ""))
		if fallback_path != "":
			var tex_fb = ResourceLoader.load(fallback_path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE)
			if tex_fb and tex_fb is Texture2D:
				icon_texture_rect.texture = tex_fb
		return
	var texture = ResourceLoader.load(image_path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE)
	if texture and texture is Texture2D:
		icon_texture_rect.texture = texture
	else:
		var fallback_path = _get_fallback_icon_path(ach_data.get("category", ""))
		if fallback_path != "":
			var tex_fb = ResourceLoader.load(fallback_path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE)
			if tex_fb and tex_fb is Texture2D:
				icon_texture_rect.texture = tex_fb
 
func _ensure_nodes():
	if title_label == null:
		title_label = get_node_or_null("ContentContainer/TopRowContainer/InfoVBox/AchievementTitleLabel")
	if description_label == null:
		description_label = get_node_or_null("ContentContainer/TopRowContainer/InfoVBox/DescriptionLabel")
	if icon_texture_rect == null:
		icon_texture_rect = get_node_or_null("ContentContainer/TopRowContainer/IconTexture")
	if animation_player == null:
		animation_player = get_node_or_null("PopupAnimator")
 
func _get_fallback_icon_path(category: String) -> String:
	match category:
		"mastery": return "res://assets/achievements/mastery.png"
		"drums": return "res://assets/achievements/drums.png"
		"system": return "res://assets/achievements/system.png"
		"shop": return "res://assets/achievements/shop.png"
		"economy": return "res://assets/achievements/economy.png"
		"daily": return "res://assets/achievements/daily.png"
		"playtime": return "res://assets/achievements/playtime.png"
		"events": return "res://assets/achievements/events.png"
		"level": return "res://assets/achievements/level.png"
		_: return "res://assets/achievements/default.png"
 
func _apply_data():
	_ensure_nodes()
	if title_label == null or description_label == null:
		call_deferred("_apply_data")
		return
	title_label.text = achievement_data.get("title", "Название отсутствует")
	description_label.text = achievement_data.get("description", "Описание отсутствует")
	_load_achievement_icon(achievement_data)
	show_popup()
 
func show_popup():
	_ensure_nodes()
	if animation_player == null:
		return
	animation_player.play("popup_show")

func _on_animation_player_animation_finished(anim_name: String):
	popup_finished.emit()
	call_deferred("queue_free")

 
