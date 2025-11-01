# scenes/achievements/achievement_card.gd
@tool
extends Control


@export var title: String = "Название Ачивки"
@export var description: String = "Описание ачивки"
@export var progress_text: String = "0 / 10"
@export var is_unlocked: bool = false
@export var unlock_date_text: String = ""
@export var icon_path: String = "res://assets/achievements/default.png"

@onready var icon_texture: TextureRect = $MarginContainer/ContentContainer/TopRowContainer/IconTexture
@onready var title_label: Label = $MarginContainer/ContentContainer/TopRowContainer/IconTexture/InfoVBox/TitleLabel
@onready var description_label: Label = $MarginContainer/ContentContainer/TopRowContainer/IconTexture/InfoVBox/DescriptionLabel
@onready var unlock_date_label: Label = $MarginContainer/ContentContainer/TopRowContainer/IconTexture/InfoVBox/UnlockDateLabel
@onready var progress_label: Label = $MarginContainer/ContentContainer/TopRowContainer/ProgressLabel

func _ready():
	_update_display()

func _update_display():
	title_label.text = title
	description_label.text = description
	progress_label.text = progress_text

	if unlock_date_text and unlock_date_text != "":
		unlock_date_label.text = "Открыто: %s" % unlock_date_text
		unlock_date_label.visible = true
	else:
		unlock_date_label.text = ""
		unlock_date_label.visible = false

	if icon_path and ResourceLoader.exists(icon_path):
		icon_texture.texture = load(icon_path)
	else:
		if not Engine.is_editor_hint():
			printerr("AchievementCard: Не удалось загрузить иконку ", icon_path)
		var default_texture_path = "res://assets/achievements/default.png"
		if ResourceLoader.exists(default_texture_path):
			icon_texture.texture = load(default_texture_path)
		else:
			printerr("AchievementCard: Иконка по умолчанию также не найдена!")

	if is_unlocked:
		title_label.add_theme_color_override("font_color", Color.YELLOW) 
		description_label.add_theme_color_override("font_color", Color.WHITE) 
		unlock_date_label.add_theme_color_override("font_color", Color.LIGHT_GRAY) 
		progress_label.add_theme_color_override("font_color", Color.LIME_GREEN)
	else:
		title_label.add_theme_color_override("font_color", Color.GRAY) 
		description_label.add_theme_color_override("font_color", Color.LIGHT_GRAY) 
		unlock_date_label.add_theme_color_override("font_color", Color.GRAY)
		progress_label.add_theme_color_override("font_color", Color.SILVER) 
