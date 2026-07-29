# scenes/achievements/achievement_pop_up.gd
extends PanelContainer

signal popup_finished

const DEFAULT_ICON_PATH := "res://assets/achievements/default.png"
const _AchievementLocale = preload("res://logic/i18n/achievement_locale.gd")
var AchievementsUtils = preload("res://logic/domain/profile/achievements_utils.gd").new()

@onready var animation_player: AnimationPlayer = $PopupAnimator
@onready var header_label: Label = $ContentContainer/TopRowContainer/InfoVBox/TitleLabel
@onready var title_label: Label = $ContentContainer/TopRowContainer/InfoVBox/AchievementTitleLabel
@onready var description_label: Label = $ContentContainer/TopRowContainer/InfoVBox/DescriptionLabel
@onready var icon_texture_rect: TextureRect = $ContentContainer/TopRowContainer/IconTexture

var achievement_data: Dictionary = {}


func _ready() -> void:
	z_index = 100
	if not achievement_data.is_empty():
		_apply_data()
	if animation_player:
		animation_player.animation_finished.connect(_on_animation_player_animation_finished)


func set_achievement_data(ach_data: Dictionary) -> void:
	achievement_data = ach_data.duplicate()
	if is_inside_tree():
		_apply_data()


func _load_achievement_icon(ach_data: Dictionary) -> void:
	var fallback_path := _get_fallback_icon_path(str(ach_data.get("category", "")))
	var loaded_tex: Texture2D = _load_texture_any(fallback_path)
	if loaded_tex == null:
		loaded_tex = _load_texture_any(DEFAULT_ICON_PATH)
	if loaded_tex and icon_texture_rect:
		icon_texture_rect.texture = loaded_tex
		icon_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_texture_rect.visible = true


func _load_texture_any(path: String) -> Texture2D:
	if path.strip_edges() == "":
		return null
	if FileAccess.file_exists(path):
		var res = ResourceLoader.load(path, "ImageTexture", ResourceLoader.CACHE_MODE_IGNORE)
		if res is Texture2D:
			return res
		var img := Image.new()
		if img.load(path) == OK:
			return ImageTexture.create_from_image(img)
	return null


func _ensure_nodes() -> void:
	if header_label == null:
		header_label = get_node_or_null("ContentContainer/TopRowContainer/InfoVBox/TitleLabel")
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
	return AchievementsUtils.icon_path_for_category(category)


func _apply_data() -> void:
	_ensure_nodes()
	if title_label == null or description_label == null or icon_texture_rect == null:
		call_deferred("_apply_data")
		return
	if header_label:
		header_label.text = tr("ACH_POPUP_UNLOCKED")
	if title_label:
		title_label.text = _AchievementLocale.localized_title(achievement_data)
	if description_label:
		description_label.text = _AchievementLocale.localized_description(achievement_data)
	_load_achievement_icon(achievement_data)
	show_popup()


func show_popup() -> void:
	_ensure_nodes()
	if animation_player == null:
		return
	animation_player.play("popup_show")


func _on_animation_player_animation_finished(_anim_name: String) -> void:
	popup_finished.emit()
	call_deferred("queue_free")
