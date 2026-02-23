# scenes/achievements/achievement_card.gd
@tool
extends Control

@export var title: String = "Название Ачивки"
@export var description: String = "Описание ачивки"
@export var progress_text: String = "0 / 10"
@export var is_unlocked: bool = false
@export var unlock_date_text: String = ""
@export var icon_texture: ImageTexture = null

var AchievementsUtils = preload("res://logic/utils/achievements_utils.gd").new()
var TimeUtils = preload("res://logic/utils/time_utils.gd")

@onready var icon_texture_rect: TextureRect = $MarginContainer/ContentContainer/TopRowContainer/IconTexture
@onready var title_label: Label = $MarginContainer/ContentContainer/TopRowContainer/InfoVBox/TitleLabel
@onready var description_label: Label = $MarginContainer/ContentContainer/TopRowContainer/InfoVBox/DescriptionLabel
@onready var unlock_date_label: Label = $MarginContainer/ContentContainer/TopRowContainer/InfoVBox/UnlockDateLabel
@onready var progress_label: Label = $MarginContainer/ContentContainer/TopRowContainer/ProgressLabel

func _ready():
	clip_contents = true
	if is_unlocked:
		theme_type_variation = "CardDefault"
	else:
		theme_type_variation = "CardLocked"
	_update_display()

func _ensure_nodes():
	if title_label == null:
		title_label = get_node_or_null("MarginContainer/ContentContainer/TopRowContainer/InfoVBox/TitleLabel")
	if description_label == null:
		description_label = get_node_or_null("MarginContainer/ContentContainer/TopRowContainer/InfoVBox/DescriptionLabel")
	if unlock_date_label == null:
		unlock_date_label = get_node_or_null("MarginContainer/ContentContainer/TopRowContainer/InfoVBox/UnlockDateLabel")
	if progress_label == null:
		progress_label = get_node_or_null("MarginContainer/ContentContainer/TopRowContainer/ProgressLabel")
	if icon_texture_rect == null:
		icon_texture_rect = get_node_or_null("MarginContainer/ContentContainer/TopRowContainer/IconTexture")

func _update_display():
	_ensure_nodes()
	if title_label == null or description_label == null or unlock_date_label == null or progress_label == null:
		call_deferred("_update_display")
		return
	title_label.text = title
	description_label.text = description
	progress_label.text = progress_text
	
	if is_unlocked:
		progress_label.add_theme_color_override("font_color", Color("#61C7BD"))
	else:
		progress_label.add_theme_color_override("font_color", Color("#D1D1D1"))

	if unlock_date_text and unlock_date_text != "":
		unlock_date_label.text = "Открыто: %s" % unlock_date_text
		unlock_date_label.visible = true
	else:
		unlock_date_label.text = ""
		unlock_date_label.visible = false

	if self.icon_texture:
		icon_texture_rect.texture = self.icon_texture
		icon_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL

	if is_unlocked:
		title_label.add_theme_color_override("font_color", Color(0.95, 0.70, 0.30, 1.0))
		description_label.add_theme_color_override("font_color", Color.WHITE)
		unlock_date_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	else:
		title_label.add_theme_color_override("font_color", Color.GRAY)
		description_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
		unlock_date_label.add_theme_color_override("font_color", Color.GRAY)

func apply_achievement(ach: Dictionary, achievement_manager: AchievementManager = null) -> void:
	title = str(ach.get("title", ""))
	description = str(ach.get("description", ""))
	is_unlocked = bool(ach.get("unlocked", false))
	var unlock_val = ach.get("unlock_date", null)
	if is_unlocked and unlock_val != null and str(unlock_val) != "" and str(unlock_val).to_lower() != "<null>":
		unlock_date_text = TimeUtils.format_unlock_display(str(unlock_val))
	else:
		unlock_date_text = ""
	icon_texture = AchievementsUtils.load_icon_texture_for_category(str(ach.get("category", "")))
	progress_text = _compute_progress_text(ach, achievement_manager)
	_update_display()

func _compute_progress_text(ach: Dictionary, achievement_manager: AchievementManager = null) -> String:
	var current = ach.get("current", 0)
	var total = ach.get("total", 1)
	var unlocked = ach.get("unlocked", false)
	var category = str(ach.get("category", ""))

	if category == "playtime" and achievement_manager != null:
		var formatted = achievement_manager.get_formatted_achievement_progress(int(ach.get("id", -1)))
		if formatted:
			var raw_total = ach.get("total", 1.0)
			var display_total: String = str(int(raw_total)) if raw_total == floor(raw_total) else "%0.2f" % [raw_total]
			if unlocked:
				return "%s / %s" % [display_total, display_total]
			else:
				return "%s / %s" % [formatted.current, display_total]

	if category == "level":
		if unlocked:
			return "%d / %d" % [int(total), int(total)]
		else:
			return "%d / %d" % [int(current), int(total)]

	if typeof(current) == TYPE_BOOL:
		return "%d / %d" % [int(current), 1]
	var display_current = current
	if unlocked and typeof(current) != TYPE_FLOAT:
		display_current = min(current, total)
	if typeof(display_current) == TYPE_FLOAT:
		return "%d / %d" % [int(display_current), int(total)]
	return "%d / %d" % [int(display_current), int(total)]
