# scenes/achievements/achievement_pop_up.gd
extends PanelContainer

signal popup_finished

@onready var animation_player: AnimationPlayer = $PopupAnimator
@onready var title_label: Label = $ContentContainer/TopRowContainer/InfoVBox/AchievementTitleLabel
@onready var description_label: Label = $ContentContainer/TopRowContainer/InfoVBox/DescriptionLabel
@onready var icon_texture_rect: TextureRect = $ContentContainer/TopRowContainer/IconTexture
var achievement_data: Dictionary = {}
const DEFAULT_ICON_PATH := "res://assets/achievements/default.png"

func _ready():
	z_index = 100
	if not achievement_data.is_empty():
		_apply_data()
	if animation_player:
		animation_player.animation_finished.connect(_on_animation_player_animation_finished)

func set_achievement_data(ach_data: Dictionary):
	achievement_data = ach_data.duplicate()
	if is_inside_tree():
		_apply_data()

func _load_achievement_icon(ach_data: Dictionary):
	var image_path = str(ach_data.get("image", ""))
	var loaded_tex: Texture2D = _load_texture_any(image_path)
	if loaded_tex == null:
		var fallback_path = _get_fallback_icon_path(ach_data.get("category", ""))
		loaded_tex = _load_texture_any(fallback_path)
	if loaded_tex == null:
		loaded_tex = _load_texture_any(DEFAULT_ICON_PATH)
	if loaded_tex and icon_texture_rect:
		icon_texture_rect.texture = loaded_tex
		icon_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_texture_rect.visible = true
 
func _load_texture_any(path: String) -> Texture2D:
	if path == "" or path == null:
		return null
	if FileAccess.file_exists(path):
		var res = ResourceLoader.load(path, "ImageTexture", ResourceLoader.CACHE_MODE_IGNORE)
		if res and res is ImageTexture:
			return res
		var img = Image.new()
		var err = img.load(path)
		if err == OK:
			return ImageTexture.create_from_image(img)
	return null
 
func _ensure_nodes():
	if title_label == null:
		title_label = get_node_or_null("ContentContainer/TopRowContainer/InfoVBox/AchievementTitleLabel")
	if description_label == null:
		description_label = get_node_or_null("ContentContainer/TopRowContainer/InfoVBox/DescriptionLabel")
	if icon_texture_rect == null:
		icon_texture_rect = get_node_or_null("ContentContainer/TopRowContainer/IconTexture")
	if icon_texture_rect:
		icon_texture_rect.z_as_relative = true
		icon_texture_rect.z_index = 1
	if animation_player == null:
		animation_player = get_node_or_null("PopupAnimator")
 
func _get_fallback_icon_path(category: String) -> String:
	match category:
		"mastery": return "res://assets/achievements/mastery.png"
		"drums": return "res://assets/achievements/drums.png"
		"genres": return "res://assets/achievements/genres.png"
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
	if title_label == null or description_label == null or icon_texture_rect == null:
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

 
