# scenes/achievements/achievement_card.gd
@tool
extends Control

@export var title: String = "Название Ачивки"
@export var description: String = "Описание ачивки"
@export var progress_text: String = "0 / 10"
@export var is_unlocked: bool = false
@export var unlock_date_text: String = ""
@export var icon_texture: ImageTexture = null

@onready var icon_texture_rect: TextureRect = $MarginContainer/ContentContainer/TopRowContainer/IconTexture
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

	print("AchievementCard: Устанавливаю текстуру в TextureRect, которая ", "существует" if self.icon_texture else "ПУСТАЯ")
	if self.icon_texture:
		print("AchievementCard: Размеры текстуры: ", self.icon_texture.get_width(), "x", self.icon_texture.get_height())

		icon_texture_rect.texture = self.icon_texture
		icon_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icon_texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		var placeholder_image = Image.create(100, 100, false, Image.FORMAT_RGBA8)
		placeholder_image.fill(Color.WHITE)
		var placeholder_texture = ImageTexture.create_from_image(placeholder_image)
		icon_texture_rect.texture = placeholder_texture
		icon_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icon_texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL

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
