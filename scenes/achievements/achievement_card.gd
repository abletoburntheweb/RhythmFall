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
	"bass": Color(0.45, 0.62, 0.92),
	"genres": Color(0.86, 0.52, 0.72),
	"system": Color(0.8, 0.86, 0.94),
	"shop": Color(0.52, 0.76, 0.92),
	"economy": Color(0.95, 0.78, 0.35),
	"daily": Color(0.62, 0.86, 0.72),
	"playtime": Color(0.42, 0.57, 0.82),
	"events": Color(0.95, 0.55, 0.45),
	"level": Color(0.55, 0.92, 0.65),
	"modifiers": Color(0.52, 0.76, 0.94),
	"play_modes": Color(0.62, 0.48, 0.95),
	"default": Color(0.42, 0.57, 0.82),
}

var AchievementsUtils = preload("res://logic/domain/profile/achievements_utils.gd").new()
const _AchievementLocale = preload("res://logic/i18n/achievement_locale.gd")
const _LabelFitUtils = preload("res://logic/ui/label_fit_utils.gd")
const _UiFramedCover = preload("res://logic/ui/ui_framed_cover.gd")
var TimeUtils = preload("res://logic/platform/time_utils.gd")

var _achievement_data_cache: Dictionary = {}
var _achievement_manager_cache: AchievementManager = null
var _title_base_font: int = 32
var _description_base_font: int = 24
var _unlock_date_base_font: int = 18
var _fit_connected: bool = false

@onready var icon_frame: PanelContainer = get_node_or_null("MarginContainer/ContentContainer/TopRowContainer/IconFrame")
@onready var icon_texture_rect: TextureRect = get_node_or_null("MarginContainer/ContentContainer/TopRowContainer/IconFrame/IconTexture")
@onready var title_label: Label = $MarginContainer/ContentContainer/TopRowContainer/InfoVBox/TitleLabel
@onready var description_label: Label = $MarginContainer/ContentContainer/TopRowContainer/InfoVBox/DescriptionLabel
@onready var unlock_date_label: Label = $MarginContainer/ContentContainer/TopRowContainer/InfoVBox/UnlockDateLabel
@onready var progress_label: Label = $MarginContainer/ContentContainer/TopRowContainer/ProgressLabel

func _ready():
	# Do not clip the card shell: clip_contents cuts StyleBoxFlat border AA
	# and makes left corners look jagged against the scroll edge.
	clip_contents = false
	_prepare_for_list_layout()
	_capture_base_fonts()
	if is_unlocked:
		theme_type_variation = "CardDefault"
	else:
		theme_type_variation = "CardLocked"
	_update_display()
	if not _fit_connected:
		resized.connect(_on_card_resized_for_fit)
		_fit_connected = true


func _capture_base_fonts() -> void:
	_ensure_nodes()
	if title_label:
		_title_base_font = title_label.get_theme_font_size("font_size")
	if description_label:
		_description_base_font = description_label.get_theme_font_size("font_size")
	if unlock_date_label:
		_unlock_date_base_font = unlock_date_label.get_theme_font_size("font_size")


func _prepare_for_list_layout() -> void:
	## Scene was authored fullscreen (anchor_right=1, offset_bottom=-978).
	## That makes list rows uneven width ("разъезжаются"). Force container layout.
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_ensure_nodes()
	if title_label and title_label.get_parent() is Control:
		(title_label.get_parent() as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if progress_label:
		progress_label.size_flags_horizontal = Control.SIZE_SHRINK_END
		progress_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER


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
		if icon_frame == null:
			icon_frame = find_child("IconFrame", true, false) as PanelContainer


func _ensure_icon_frame() -> void:
	## Profile template has bare IconTexture (no IconFrame) — wrap so UiFramedCover can run.
	_ensure_nodes()
	if icon_texture_rect == null:
		return
	if icon_frame != null and is_instance_valid(icon_frame):
		return
	var parent := icon_texture_rect.get_parent() as Control
	if parent == null:
		return
	if parent.name == "CoverClipHost" and parent.get_parent() is PanelContainer:
		icon_frame = parent.get_parent() as PanelContainer
		return
	var frame := PanelContainer.new()
	frame.name = "IconFrame"
	var idx := icon_texture_rect.get_index()
	parent.remove_child(icon_texture_rect)
	frame.add_child(icon_texture_rect)
	parent.add_child(frame)
	parent.move_child(frame, idx)
	icon_frame = frame

func _update_display():
	_ensure_nodes()
	if title_label == null or description_label == null or unlock_date_label == null:
		call_deferred("_update_display")
		return
	# ProgressLabel is optional (hidden on profile recent list).
	if progress_label == null:
		progress_label = find_child("ProgressLabel", true, false) as Label
	title_label.text = title
	description_label.text = description
	if progress_label:
		progress_label.text = progress_text
	
	if progress_label:
		if is_unlocked:
			progress_label.add_theme_color_override("font_color", Color("#61C7BD"))
		else:
			progress_label.add_theme_color_override("font_color", Color("#D1D1D1"))

	if unlock_date_text and unlock_date_text != "":
		unlock_date_label.text = tr("ACH_UNLOCKED_ON") % unlock_date_text
		unlock_date_label.visible = true
	else:
		unlock_date_label.text = ""
		unlock_date_label.visible = false

	if self.icon_texture and icon_texture_rect:
		icon_texture_rect.texture = self.icon_texture
		icon_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		icon_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

	if is_unlocked:
		title_label.add_theme_color_override("font_color", Color(0.95, 0.70, 0.30, 1.0))
		description_label.add_theme_color_override("font_color", Color.WHITE)
		unlock_date_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	else:
		title_label.add_theme_color_override("font_color", Color.GRAY)
		description_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
		unlock_date_label.add_theme_color_override("font_color", Color.GRAY)
	_apply_card_style()
	call_deferred("_fit_text_labels")


func _on_card_resized_for_fit() -> void:
	call_deferred("_fit_text_labels")


func _fit_text_labels() -> void:
	_ensure_nodes()
	if title_label == null:
		return
	var width := 0.0
	var info := title_label.get_parent() as Control
	if info and info.size.x > 1.0:
		width = info.size.x
	elif title_label.size.x > 1.0:
		width = title_label.size.x
	if width <= 1.0:
		return
	# Progress stays fixed; only title/desc/date adapt.
	_LabelFitUtils.fit_label(title_label, width, _title_base_font, 18, true, 2)
	if description_label and description_label.visible:
		_LabelFitUtils.fit_label(description_label, width, _description_base_font, 14, true, 2)
	if unlock_date_label and unlock_date_label.visible:
		_LabelFitUtils.fit_label(unlock_date_label, width, _unlock_date_base_font, 12, true, 1)


func _category_accent() -> Color:
	return _ACCENT_BY_CATEGORY.get(achievement_category, _ACCENT_BY_CATEGORY["default"])


func _apply_card_style() -> void:
	_prepare_for_list_layout()
	var accent := _category_accent()
	if is_unlocked:
		theme_type_variation = &"CardDefault"
		add_theme_stylebox_override("panel", _build_card_shell_style(accent, true))
	else:
		theme_type_variation = &"CardLocked"
		# Same geometry as unlocked so locked/unlocked rows share one width.
		add_theme_stylebox_override("panel", _build_card_shell_style(accent, false))
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
	shell.corner_detail = 12
	# Pad inside one frame (MarginContainer is 0). No glow shadow — it looked like gaps.
	shell.content_margin_left = 12.0
	shell.content_margin_top = 8.0
	shell.content_margin_right = 12.0
	shell.content_margin_bottom = 8.0
	shell.shadow_size = 0
	return shell


func _apply_icon_frame(accent: Color) -> void:
	_ensure_icon_frame()
	if icon_frame == null or icon_texture_rect == null:
		return
	icon_texture_rect.custom_minimum_size = Vector2(100, 100)
	# Legacy StyleBox used alpha 0.5; 0.85 was too loud — settle in between.
	var icon_accent := Color(accent.r, accent.g, accent.b, 0.72 if is_unlocked else 0.48)
	_UiFramedCover.apply(
		icon_frame,
		icon_texture_rect,
		10,
		2,
		icon_accent,
		Color(0.05, 0.06, 0.09, 1.0),
		0.0
	)
	icon_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

func apply_locale() -> void:
	if _achievement_data_cache.is_empty():
		return
	apply_achievement(_achievement_data_cache, _achievement_manager_cache)


func apply_achievement(ach: Dictionary, achievement_manager: AchievementManager = null) -> void:
	_achievement_data_cache = ach.duplicate()
	_achievement_manager_cache = achievement_manager
	title = _AchievementLocale.localized_title(ach)
	description = _AchievementLocale.localized_description(ach)
	is_unlocked = bool(ach.get("unlocked", false))
	var unlock_val = ach.get("unlock_date", null)
	if is_unlocked and unlock_val != null and str(unlock_val).strip_edges() != "" and str(unlock_val).to_lower() != "<null>":
		unlock_date_text = TimeUtils.format_unlock_display(str(unlock_val))
	elif is_unlocked:
		# Restored / legacy unlocks without a stored date.
		unlock_date_text = TranslationServer.translate("ACH_DATE_EARLIER")
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
