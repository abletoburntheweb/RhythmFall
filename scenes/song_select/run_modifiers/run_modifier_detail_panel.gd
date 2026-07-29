# scenes/song_select/run_modifiers/run_modifier_detail_panel.gd
extends VBoxContainer
class_name RunModifierDetailPanel

const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const _UiMotionEffects = preload("res://logic/ui/ui_motion_effects.gd")
const _UiRoundedClip = preload("res://logic/ui/ui_rounded_clip.gd")

const DESC_FONT_SIZE := 14
const CONFLICT_MAX_VISIBLE := 8
const CONFLICT_COLOR_BODY := Color(0.78, 0.86, 0.98, 0.92)
const CONFLICT_COLOR_EMPTY := Color(0.5, 0.58, 0.68, 0.85)
const PREVIEW_CORNER_RADIUS := 12.0

signal preview_requested(modifier_id: String)

var _current_id: String = ""
var _preview_loop: bool = false
var _last_params: Dictionary = {}
var _active_modifiers: Array = []

@onready var _preview_panel: PanelContainer = $DetailScroll/DetailBody/PreviewPanel
@onready var _preview_image: TextureRect = $DetailScroll/DetailBody/PreviewPanel/PreviewStack/PreviewImage
@onready var _preview_video: VideoStreamPlayer = $DetailScroll/DetailBody/PreviewPanel/PreviewStack/PreviewVideo
@onready var _title_label: Label = $DetailScroll/DetailBody/TitleLabel
@onready var _subtitle_label: Label = $DetailScroll/DetailBody/SubtitleLabel
@onready var _description_label: Label = $DetailScroll/DetailBody/DescriptionLabel
@onready var _stars_row: HBoxContainer = $DetailScroll/DetailBody/DifficultyRow/StarsRow
@onready var _reward_value_label: Label = $DetailScroll/DetailBody/RewardRow/RewardValueLabel
@onready var _conflicts_body: Label = $DetailScroll/DetailBody/ConflictsSection/ConflictsBodyLabel
@onready var _conflicts_header: Label = $DetailScroll/DetailBody/ConflictsSection/ConflictsHeader
@onready var _detail_scroll: ScrollContainer = $DetailScroll
@onready var _difficulty_caption: Label = $DetailScroll/DetailBody/DifficultyRow/DifficultyCaption
@onready var _reward_caption: Label = $DetailScroll/DetailBody/RewardRow/RewardCaption


func _ready() -> void:
	apply_locale()
	_setup_preview_rounded_clip()
	if _detail_scroll:
		_detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	if _preview_video and not _preview_video.finished.is_connected(_on_preview_video_finished):
		_preview_video.finished.connect(_on_preview_video_finished)
	clear()


func _setup_preview_rounded_clip() -> void:
	if _preview_panel == null:
		return
	var style := _preview_panel.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		var flat := (style as StyleBoxFlat).duplicate() as StyleBoxFlat
		# Opaque fill for clip_children; border is redrawn on top of media.
		flat.bg_color = Color(flat.bg_color.r, flat.bg_color.g, flat.bg_color.b, 1.0)
		_preview_panel.add_theme_stylebox_override("panel", flat)
	_UiRoundedClip.clip_to_frame(_preview_panel)
	_UiRoundedClip.apply_to_canvas_item(_preview_image, maxf(0.0, PREVIEW_CORNER_RADIUS - 1.0))
	if _preview_video:
		_preview_video.expand = true
	# Border must sit above image/video — otherwise square media covers the curve.
	_UiRoundedClip.ensure_border_on_top(_preview_panel)
	# Keep overlay above stack if anything reorders children later.
	call_deferred("_ensure_preview_border_on_top")


func _ensure_preview_border_on_top() -> void:
	if _preview_panel == null:
		return
	_UiRoundedClip.ensure_border_on_top(_preview_panel)


func apply_params(params: Dictionary) -> void:
	_last_params = params
	if _current_id == "":
		return
	if _description_label:
		_description_label.text = _RunModifiers.format_modifier_description(_current_id, params)
		_sync_description_layout()
	_refresh_reward(_current_id, params, _active_modifiers)
	_set_stars(_RunModifiers.modifier_difficulty_stars(_current_id, params))


func clear() -> void:
	_current_id = ""
	_last_params = {}
	if _title_label:
		_title_label.text = "—"
	if _subtitle_label:
		_subtitle_label.text = ""
	if _description_label:
		_description_label.text = tr("MOD_DETAIL_SELECT_HINT")
		_sync_description_layout()
	if _reward_value_label:
		_reward_value_label.text = "—"
	_set_stars(0)
	_clear_conflicts()
	_show_preview_image("")
	_sync_preview_border_pulse(false)


func show_modifier(
	modifier_id: String,
	active_modifiers: Array = [],
	params: Dictionary = {},
	dna_unavailable: bool = false
) -> void:
	if modifier_id == "":
		clear()
		return
	var same_mod := modifier_id == _current_id
	_current_id = modifier_id
	_last_params = params
	_active_modifiers = active_modifiers.duplicate()
	var title_key := _title_key_for(modifier_id)
	if _title_label:
		_title_label.text = tr(title_key) if title_key != "" else modifier_id
	if _subtitle_label:
		_subtitle_label.text = tr("MOD_DNA_REQUIRED") if dna_unavailable else ""
	if _description_label:
		_description_label.text = _RunModifiers.format_modifier_description(modifier_id, params)
		_sync_description_layout()
	_refresh_reward(modifier_id, params, active_modifiers)
	_set_stars(_RunModifiers.modifier_difficulty_stars(modifier_id, params))
	_refresh_conflicts(modifier_id, active_modifiers)
	call_deferred("_reset_detail_scroll")
	if same_mod:
		return
	_load_preview(modifier_id)
	_sync_preview_border_pulse(true)


func _sync_preview_border_pulse(on: bool) -> void:
	if _preview_panel == null:
		return
	_UiMotionEffects.stop_panel_border_pulse(_preview_panel)
	if on and _current_id != "":
		_UiMotionEffects.pulse_panel_border(
			_preview_panel,
			Color(0.55, 0.72, 0.98),
			0.28,
			0.72,
			0.8
		)


func _title_key_for(modifier_id: String) -> String:
	return _RunModifiers.title_i18n_key(modifier_id)


func _desc_key_for(modifier_id: String) -> String:
	return "MOD_DESC_%s" % modifier_id.to_upper()


func _refresh_reward(modifier_id: String, params: Dictionary = {}, active_modifiers: Array = []) -> void:
	if _reward_value_label == null:
		return
	if modifier_id == _RunModifiers.ID_AUTOPLAY:
		_reward_value_label.text = "0×"
		return
	if modifier_id in [_RunModifiers.ID_SLOW_75, _RunModifiers.ID_FAST_150]:
		var delta := _RunModifiers.card_reward_delta(modifier_id, params)
		if is_equal_approx(delta, 0.0):
			_reward_value_label.text = "0%"
		elif delta > 0.0:
			_reward_value_label.text = "+%d%%" % int(round(delta * 100.0))
		else:
			_reward_value_label.text = "%d%%" % int(round(delta * 100.0))
		return
	if modifier_id == _RunModifiers.ID_COMBO_ESCALATION:
		_reward_value_label.text = "0×"
		return
	if modifier_id == _RunModifiers.ID_SINGLE_LANE:
		_reward_value_label.text = "0×"
		return
	var delta: float = _RunModifiers.card_reward_delta(modifier_id, params)
	if delta == 0.0:
		_reward_value_label.text = "0%"
	elif delta > 0.0:
		_reward_value_label.text = "+%d%%" % int(round(delta * 100.0))
	else:
		_reward_value_label.text = "%d%%" % int(round(delta * 100.0))


func _set_stars(count: int) -> void:
	if _difficulty_caption:
		if count <= 0 and _current_id == _RunModifiers.ID_AUTOPLAY:
			_difficulty_caption.text = "%s: 0" % tr("MOD_DETAIL_DIFFICULTY")
		else:
			_difficulty_caption.text = tr("MOD_DETAIL_DIFFICULTY")
	if _stars_row == null:
		return
	for child in _stars_row.get_children():
		if child is Label:
			var idx: int = int(child.get_meta("star_index", 0))
			if count <= 0:
				(child as Label).modulate = Color(0.35, 0.4, 0.5, 0.35)
			else:
				(child as Label).modulate = (
					Color(0.95, 0.82, 0.45, 1.0) if idx <= count else Color(0.35, 0.4, 0.5, 0.55)
				)


func _sync_description_layout() -> void:
	if _description_label == null:
		return
	_description_label.add_theme_font_size_override("font_size", DESC_FONT_SIZE)
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.clip_text = false
	_description_label.max_lines_visible = -1
	_description_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_description_label.visible = true
	_fit_description_height_deferred()


func _fit_description_height_deferred() -> void:
	call_deferred("_fit_description_height")


func _label_layout_width(label: Label) -> int:
	var width := int(label.size.x)
	if width < 8 and _detail_scroll:
		width = maxi(8, int(_detail_scroll.size.x) - 8)
	return width


func _measure_label_text_height(label: Label, width: int) -> float:
	if label.text.is_empty():
		return 18.0
	var font: Font = label.get_theme_font("font")
	if font == null:
		return 18.0
	var font_size: int = label.get_theme_font_size("font_size")
	var text_size: Vector2 = font.get_multiline_string_size(
		label.text,
		label.horizontal_alignment,
		float(width),
		font_size
	)
	return maxf(18.0, text_size.y)


func _fit_label_height(label: Label) -> void:
	if label == null:
		return
	var width := _label_layout_width(label)
	label.custom_minimum_size = Vector2(width, _measure_label_text_height(label, width))


func _fit_description_height() -> void:
	_fit_label_height(_description_label)


func _reset_detail_scroll() -> void:
	if _detail_scroll:
		_detail_scroll.scroll_vertical = 0


func _clear_conflicts() -> void:
	_set_conflicts_text(tr("MOD_CONFLICTS_NONE"), true)


func _refresh_conflicts(modifier_id: String, _active_modifiers: Array) -> void:
	if _conflicts_body == null:
		return
	var conflict_lines: Array = _RunModifiers.ui_conflict_display_lines(modifier_id)
	if conflict_lines.is_empty():
		_set_conflicts_text(tr("MOD_CONFLICTS_NONE"), true)
		return
	var parts: PackedStringArray = []
	var total := conflict_lines.size()
	var visible_count := mini(total, CONFLICT_MAX_VISIBLE)
	for i in visible_count:
		var line_text := str(conflict_lines[i]).strip_edges()
		if line_text != "":
			parts.append("• %s" % line_text)
	if total > CONFLICT_MAX_VISIBLE:
		parts.append(tr("MOD_CONFLICTS_MORE_FMT") % (total - CONFLICT_MAX_VISIBLE))
	if parts.is_empty():
		_set_conflicts_text(tr("MOD_CONFLICTS_NONE"), true)
	else:
		_set_conflicts_text("\n".join(parts), false)


func _set_conflicts_text(text: String, is_empty: bool) -> void:
	if _conflicts_body == null:
		return
	_conflicts_body.text = text
	_conflicts_body.add_theme_color_override(
		"font_color",
		CONFLICT_COLOR_EMPTY if is_empty else CONFLICT_COLOR_BODY
	)
	call_deferred("_fit_conflicts_height")


func _fit_conflicts_height() -> void:
	_fit_label_height(_conflicts_body)


func apply_locale() -> void:
	if _difficulty_caption:
		_difficulty_caption.text = tr("MOD_DETAIL_DIFFICULTY")
	if _reward_caption:
		_reward_caption.text = tr("MOD_DETAIL_REWARD")
	if _conflicts_header:
		_conflicts_header.text = tr("MOD_CONFLICTS_CAPTION")
	if _conflicts_body and _current_id != "":
		_refresh_conflicts(_current_id, _active_modifiers)
	elif _conflicts_body:
		_set_conflicts_text(tr("MOD_CONFLICTS_NONE"), true)


func _load_preview(modifier_id: String) -> void:
	var base_path := "res://assets/modifiers/previews/%s" % modifier_id
	for ext in ["ogv", "webm"]:
		var video_path := "%s.%s" % [base_path, ext]
		if _try_show_preview_video(video_path):
			return
	var png_path := _RunModifiers.cover_path(modifier_id)
	if ResourceLoader.exists(png_path):
		_show_preview_image(png_path)
		return
	_show_preview_image("res://assets/modifiers/default.png")


func _res_file_exists(res_path: String) -> bool:
	if ResourceLoader.exists(res_path):
		return true
	var global_path := ProjectSettings.globalize_path(res_path)
	return FileAccess.file_exists(global_path)


func _try_show_preview_video(path: String) -> bool:
	if not _res_file_exists(path):
		return false
	var stream: Resource = ResourceLoader.load(path, "VideoStream", ResourceLoader.CACHE_MODE_REUSE)
	if stream == null:
		stream = load(path)
	if stream == null or not (stream is VideoStream):
		push_warning("RunModifierDetailPanel: video not loaded (Godot 4 needs .ogv): %s" % path)
		return false
	_show_preview_video_stream(stream as VideoStream)
	return true


func _show_preview_image(path: String) -> void:
	_preview_loop = false
	if _preview_video:
		_preview_video.stop()
		_preview_video.visible = false
	if _preview_image:
		_preview_image.visible = true
		if path != "" and ResourceLoader.exists(path):
			_preview_image.texture = load(path)
		else:
			_preview_image.texture = null
	_ensure_preview_border_on_top()


func _show_preview_video_stream(stream: VideoStream) -> void:
	if _preview_image:
		_preview_image.visible = false
	if _preview_video == null:
		_show_preview_image(_RunModifiers.cover_path(_current_id))
		return
	_preview_loop = true
	_preview_video.stream = stream
	_preview_video.visible = true
	_preview_video.play()
	_ensure_preview_border_on_top()


func _on_preview_video_finished() -> void:
	if not _preview_loop or _preview_video == null or not _preview_video.visible:
		return
	if _preview_video.stream == null:
		return
	_preview_video.play()


func _exit_tree() -> void:
	_preview_loop = false
	_sync_preview_border_pulse(false)
	if _preview_video and _preview_video.is_playing():
		_preview_video.stop()
