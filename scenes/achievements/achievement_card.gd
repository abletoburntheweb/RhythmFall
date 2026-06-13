# scenes/achievements/achievement_card.gd
@tool
extends PanelContainer

@export var title: String = "Название Ачивки"
@export var description: String = "Описание ачивки"
@export var progress_text: String = "0 / 10"
@export var is_unlocked: bool = false
@export var unlock_date_text: String = ""
@export var icon_texture: Texture2D = null

var achievement_category: String = ""

const _ACCENT_BY_CATEGORY := {
	"mastery": Color(0.66, 0.58, 0.86),
	"drums": Color(0.38, 0.78, 0.74),
	"genres": Color(0.86, 0.52, 0.72),
	"system": Color(0.8, 0.86, 0.94),
	"shop": Color(0.52, 0.76, 0.92),
	"economy": Color(0.95, 0.78, 0.35),
	"daily": Color(0.62, 0.86, 0.72),
	"playtime": Color(0.42, 0.57, 0.82),
	"events": Color(0.95, 0.55, 0.45),
	"level": Color(0.55, 0.92, 0.65),
	"default": Color(0.42, 0.57, 0.82),
}

var AchievementsUtils = preload("res://logic/utils/achievements_utils.gd").new()
var TimeUtils = preload("res://logic/utils/time_utils.gd")

@onready var icon_frame: PanelContainer = get_node_or_null("MarginContainer/ContentContainer/TopRowContainer/IconFrame")
@onready var icon_texture_rect: TextureRect = get_node_or_null("MarginContainer/ContentContainer/TopRowContainer/IconFrame/IconTexture")
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
		icon_texture_rect = find_child("IconTexture", true, false) as TextureRect
	if icon_frame == null:
		icon_frame = get_node_or_null("MarginContainer/ContentContainer/TopRowContainer/IconFrame") as PanelContainer

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
	_apply_card_style()


func _category_accent() -> Color:
	return _ACCENT_BY_CATEGORY.get(achievement_category, _ACCENT_BY_CATEGORY["default"])


func _apply_card_style() -> void:
	var accent := _category_accent()
	if is_unlocked:
		theme_type_variation = &"CardDefault"
		add_theme_stylebox_override("panel", _build_card_shell_style(accent, true))
	else:
		theme_type_variation = &"CardLocked"
		remove_theme_stylebox_override("panel")
	_apply_icon_frame(accent)
	if progress_label and is_unlocked:
		progress_label.add_theme_constant_override("outline_size", 3)
		progress_label.add_theme_color_override("font_outline_color", Color(0.12, 0.28, 0.24))


func _build_card_shell_style(accent: Color, unlocked: bool) -> StyleBoxFlat:
	var shell := StyleBoxFlat.new()
	shell.bg_color = Color(0.13, 0.15, 0.19) if unlocked else Color(0.11, 0.12, 0.16)
	shell.border_color = accent.lightened(0.12 if unlocked else 0.0)
	shell.set_border_width_all(2 if unlocked else 1)
	shell.set_corner_radius_all(12)
	shell.shadow_color = Color(accent.r, accent.g, accent.b, 0.24 if unlocked else 0.0)
	shell.shadow_size = 8 if unlocked else 0
	shell.shadow_offset = Vector2(0, 3)
	return shell


func _apply_icon_frame(accent: Color) -> void:
	_ensure_nodes()
	if icon_frame == null:
		return
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.05, 0.06, 0.09)
	frame.border_color = Color(accent.r, accent.g, accent.b, 0.5)
	frame.border_width_top = 3
	frame.border_width_left = 1
	frame.border_width_right = 1
	frame.border_width_bottom = 1
	frame.set_corner_radius_all(10)
	frame.content_margin_left = 6.0
	frame.content_margin_top = 6.0
	frame.content_margin_right = 6.0
	frame.content_margin_bottom = 6.0
	icon_frame.add_theme_stylebox_override("panel", frame)
	if icon_texture_rect:
		icon_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

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
	achievement_category = str(ach.get("category", ""))
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
