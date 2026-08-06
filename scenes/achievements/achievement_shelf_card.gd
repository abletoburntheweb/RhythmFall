# scenes/achievements/achievement_shelf_card.gd
extends PanelContainer

const _AchievementLocale = preload("res://logic/i18n/achievement_locale.gd")
const _AchievementsUtils = preload("res://logic/domain/profile/achievements_utils.gd")
const _UiFramedCover = preload("res://logic/ui/ui_framed_cover.gd")

var _achievement_data: Dictionary = {}
var _accent: Color = Color(0.42, 0.57, 0.82)
var _achievement_manager_cache: AchievementManager = null

var icon_texture_rect: TextureRect = null
var title_label: Label = null
var description_label: Label = null
var progress_label: Label = null
var progress_bar: ProgressBar = null


func apply_achievement(ach: Dictionary, accent: Color, achievement_manager: AchievementManager = null) -> void:
	_achievement_data = ach.duplicate()
	_accent = accent
	_achievement_manager_cache = achievement_manager
	_update_display()


func apply_locale() -> void:
	if _achievement_data.is_empty():
		return
	_update_display()


func _ensure_nodes() -> void:
	if title_label == null:
		title_label = get_node_or_null("MarginContainer/HBox/ContentVBox/TitleLabel") as Label
	if description_label == null:
		description_label = get_node_or_null("MarginContainer/HBox/ContentVBox/DescriptionLabel") as Label
	if progress_label == null:
		progress_label = get_node_or_null("MarginContainer/HBox/ContentVBox/ProgressRow/ProgressLabel") as Label
	if progress_bar == null:
		progress_bar = get_node_or_null("MarginContainer/HBox/ContentVBox/ProgressRow/ProgressBar") as ProgressBar
	if icon_texture_rect == null:
		icon_texture_rect = get_node_or_null("MarginContainer/HBox/IconFrame/IconTexture") as TextureRect
		if icon_texture_rect == null:
			icon_texture_rect = find_child("IconTexture", true, false) as TextureRect


func _update_display() -> void:
	_ensure_nodes()
	if title_label == null or description_label == null or progress_label == null or progress_bar == null or icon_texture_rect == null:
		call_deferred("_update_display")
		return

	var ach := _achievement_data
	var unlocked := bool(ach.get("unlocked", false))
	var category := str(ach.get("category", ""))
	var total := maxf(float(ach.get("total", 1)), 1.0)
	var current := float(ach.get("current", 0))
	if unlocked:
		current = total

	title_label.text = _AchievementLocale.localized_title(ach)
	description_label.text = _AchievementLocale.localized_description(ach)
	progress_label.text = _format_progress(ach, _achievement_manager_cache, unlocked)
	progress_bar.max_value = total
	progress_bar.value = current
	icon_texture_rect.texture = _AchievementsUtils.load_icon_texture_for_category(category)
	icon_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	if unlocked:
		title_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.38, 1.0))
		description_label.add_theme_color_override("font_color", Color(0.74, 0.78, 0.86, 1.0))
		progress_label.add_theme_color_override("font_color", Color(0.55, 0.82, 0.76, 1.0))
	else:
		title_label.add_theme_color_override("font_color", Color(0.88, 0.91, 0.96, 1.0))
		description_label.add_theme_color_override("font_color", Color(0.58, 0.64, 0.72, 1.0))
		progress_label.add_theme_color_override("font_color", Color(0.58, 0.64, 0.72, 1.0))

	_apply_shell_style(_accent, unlocked)


func _format_progress(ach: Dictionary, achievement_manager: AchievementManager, unlocked: bool) -> String:
	var category := str(ach.get("category", ""))
	if category == "playtime" and achievement_manager != null:
		var formatted = achievement_manager.get_formatted_achievement_progress(int(ach.get("id", -1)))
		if formatted:
			var raw_total = ach.get("total", 1.0)
			var display_total: String = str(int(raw_total)) if raw_total == floor(raw_total) else "%0.2f" % [raw_total]
			if unlocked:
				return "%s / %s" % [display_total, display_total]
			return "%s / %s" % [formatted.current, display_total]
	var current = ach.get("current", 0)
	var total = ach.get("total", 1)
	if unlocked:
		return "%s / %s" % [str(total), str(total)]
	return "%s / %s" % [str(current), str(total)]


func _apply_shell_style(accent: Color, unlocked: bool) -> void:
	var shell := StyleBoxFlat.new()
	shell.bg_color = Color(0.11, 0.12, 0.16, 0.95) if unlocked else Color(0.09, 0.1, 0.13, 0.92)
	shell.border_color = Color(accent.r, accent.g, accent.b, 0.72 if unlocked else 0.35)
	shell.set_border_width_all(2 if unlocked else 1)
	shell.set_corner_radius_all(10)
	shell.content_margin_left = 8.0
	shell.content_margin_top = 8.0
	shell.content_margin_right = 10.0
	shell.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", shell)

	var icon_frame := get_node_or_null("MarginContainer/HBox/IconFrame") as PanelContainer
	if icon_frame and icon_texture_rect:
		icon_texture_rect.custom_minimum_size = Vector2(72, 72)
		var icon_accent := Color(accent.r, accent.g, accent.b, 0.72 if unlocked else 0.48)
		_UiFramedCover.apply(
			icon_frame,
			icon_texture_rect,
			8,
			2,
			icon_accent,
			Color(0.05, 0.06, 0.09, 1.0),
			0.0
		)
		icon_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	if progress_bar == null:
		return
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(accent.r, accent.g, accent.b, 0.85)
	fill.set_corner_radius_all(3)
	progress_bar.add_theme_stylebox_override("fill", fill)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.16, 0.18, 0.22)
	track.set_corner_radius_all(3)
	progress_bar.add_theme_stylebox_override("background", track)
