# scenes/play_modes/mode_card.gd
extends PanelContainer
class_name PlayModeCard

signal action_pressed(mode_id: String)
signal zone_action_requested(action: String, payload: Dictionary)

@export var mode_id: String = ""

const _PlayModeIds = preload("res://logic/domain/session/play_mode_ids.gd")
const _RhythmDnaCoverLoader = preload("res://scenes/song_select/rhythm_dna/lib/rhythm_dna_cover_loader.gd")
const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")
const _UiMotionEffects = preload("res://logic/ui/ui_motion_effects.gd")
const _UiRoundedClip = preload("res://logic/ui/ui_rounded_clip.gd")
const _ACHIEVEMENT_COVER_SHADER = preload("res://shaders/achievement_card.gdshader")
const UNLOCK_BORDER_COLOR := Color("#F2B35A")
const _CARD_BORDER_PX := 2
# Must keep child AABB inside the rounded fill: ≈ R*(1 - 1/√2) + border.
const _CARD_CONTENT_INSET := 8
const _CARD_CORNER_RADIUS := 18

var _is_locked: bool = false
var _unlock_ready: bool = false
var _accent: Color = Color.WHITE
var _accent_hints: Array = []
var _countdown_caption_label: Label = null
var _hero_streak_badge: PanelContainer = null
var _hero_streak_label: Label = null

@onready var _hero: Control = %HeroDraw
@onready var _hero_icon_badge: PanelContainer = %HeroIconBadge
@onready var _hero_icon: TextureRect = %HeroIcon
@onready var _root_vbox: VBoxContainer = $RootVBox
@onready var _content_panel: PanelContainer = %ContentPanel
@onready var _badge_panel: PanelContainer = %BadgePanel
@onready var _badge_label: Label = %BadgeLabel
@onready var _lock_icon: TextureRect = %LockIcon
@onready var _title_row: HBoxContainer = %TitleRow
@onready var _icon_texture: TextureRect = %IconTexture
@onready var _title_label: Label = %TitleLabel
@onready var _desc_label: Label = %DescLabel
@onready var _accent_hints_flow: FlowContainer = %AccentHintsFlow
@onready var _zones_vbox: VBoxContainer = %ZonesVBox
@onready var _unlock_rows: VBoxContainer = %UnlockRows
@onready var _action_button: Button = %ActionButton


func _ready() -> void:
	# Keep square hero/media inside the rounded accent frame (see UiRoundedClip).
	_UiRoundedClip.clip_to_frame(self)
	pivot_offset = size * 0.5
	resized.connect(_on_resized)
	_ensure_hero_streak_badge()
	if _action_button:
		_action_button.pressed.connect(_on_action_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _on_resized() -> void:
	pivot_offset = size * 0.5


func _ensure_hero_streak_badge() -> void:
	if _hero_streak_badge != null:
		return
	_hero_streak_badge = PanelContainer.new()
	_hero_streak_badge.name = "HeroStreakBadge"
	_hero_streak_badge.mouse_filter = Control.MOUSE_FILTER_STOP
	_hero_streak_badge.visible = false
	_hero_streak_badge.size_flags_horizontal = Control.SIZE_SHRINK_END
	_hero_streak_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	var icon := TextureRect.new()
	icon.name = "StreakIcon"
	icon.custom_minimum_size = Vector2(18, 18)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	_hero_streak_label = Label.new()
	_hero_streak_label.name = "StreakLabel"
	_hero_streak_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_streak_label.add_theme_font_size_override("font_size", 15)
	row.add_child(_hero_streak_label)
	_hero_streak_badge.add_child(row)


func setup(
	p_mode_id: String,
	title_text: String,
	desc_text: String,
	action_text: String,
	locked: bool,
	badge_text: String = "",
	zones: Array = [],
	unlock_rows: Array = [],
	unlock_ready: bool = false,
	accent_hints: Array = []
) -> void:
	mode_id = p_mode_id
	_is_locked = locked
	_unlock_ready = unlock_ready and locked
	_accent_hints = accent_hints
	_accent = _PlayModeIds.accent_for(mode_id)
	if _title_label:
		_title_label.text = title_text
	if _desc_label:
		_desc_label.text = desc_text
	if _action_button:
		_action_button.text = action_text
		_action_button.disabled = false
	if _badge_label:
		_badge_label.text = badge_text
	if _badge_panel:
		_badge_panel.visible = badge_text.strip_edges() != ""
	_set_zones(zones)
	_set_unlock_rows(unlock_rows)
	_set_accent_hints(_accent_hints)
	if is_node_ready():
		_apply_visuals()
	else:
		call_deferred("_apply_visuals")


func set_focused(on: bool) -> void:
	var base := Color(0.88, 0.9, 0.94, 1.0) if _is_locked else Color.WHITE
	var target := base
	if on and not _is_locked:
		target = Color(1.04, 1.05, 1.07, 1.0).lerp(_accent, 0.06)
	elif on and _is_locked:
		target = base.lightened(0.02)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate", target, 0.12)
	# Same border for all modes — no focus glow/shadow.


func update_countdown_caption(text: String) -> void:
	if _countdown_caption_label:
		_countdown_caption_label.text = text


func _set_zones(zones: Array) -> void:
	if _zones_vbox == null:
		return
	_countdown_caption_label = null
	for child in _zones_vbox.get_children():
		child.queue_free()
	var has_zones := false
	for zone in zones:
		if not zone is Dictionary:
			continue
		var block: VBoxContainer = null
		var zone_type := str((zone as Dictionary).get("type", ""))
		if zone_type == "last_track":
			block = _make_last_track_zone(zone as Dictionary)
		elif zone_type == "replay_run":
			block = _make_replay_run_zone(zone as Dictionary)
		elif zone_type == "daily_marathon":
			block = _make_daily_marathon_zone(zone as Dictionary)
		elif zone_type == "bullets":
			block = _make_bullets_zone(zone as Dictionary)
		elif zone_type == "countdown":
			block = _make_countdown_zone(zone as Dictionary)
		else:
			block = _make_zone_block(zone as Dictionary)
		if block:
			_zones_vbox.add_child(block)
			has_zones = true
	_zones_vbox.visible = has_zones


func _make_last_track_zone(zone: Dictionary) -> VBoxContainer:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	root.add_child(_make_divider())
	var caption := str(zone.get("caption", "")).strip_edges()
	if caption != "":
		var cap := Label.new()
		cap.text = caption
		cap.add_theme_font_size_override("font_size", 14)
		cap.add_theme_color_override("font_color", _accent.lerp(Color.WHITE, 0.35))
		root.add_child(cap)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	var cover_tex: Texture2D = zone.get("cover", null) as Texture2D
	var cover_path := str(zone.get("cover_path", "")).strip_edges()
	if cover_tex == null and cover_path != "":
		call_deferred("_load_last_track_cover", root, cover_path)
	if cover_tex:
		row.add_child(_make_cover_wrap(cover_tex))
	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 4)
	var title := str(zone.get("title", "")).strip_edges()
	if title != "":
		var title_lbl := Label.new()
		title_lbl.text = title
		title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title_lbl.add_theme_font_size_override("font_size", 15)
		title_lbl.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0, 1.0))
		text_col.add_child(title_lbl)
	var meta_row := HBoxContainer.new()
	meta_row.add_theme_constant_override("separation", 6)
	var grade := str(zone.get("grade", "")).strip_edges()
	if grade != "":
		var grade_lbl := Label.new()
		grade_lbl.text = grade
		grade_lbl.add_theme_font_size_override("font_size", 22)
		var grade_color: Color = zone.get("grade_color", Color.WHITE)
		grade_lbl.add_theme_color_override("font_color", grade_color.lightened(0.12))
		meta_row.add_child(grade_lbl)
	var when := str(zone.get("when", "")).strip_edges()
	if when != "":
		var when_lbl := Label.new()
		when_lbl.text = when
		when_lbl.add_theme_font_size_override("font_size", 15)
		when_lbl.add_theme_color_override("font_color", Color(0.72, 0.78, 0.88, 1.0))
		meta_row.add_child(when_lbl)
	if meta_row.get_child_count() > 0:
		text_col.add_child(meta_row)
	if bool(zone.get("replay_enabled", false)):
		var replay_text := str(zone.get("replay_text", tr("PLAY_MODE_REPLAY_LAST")))
		text_col.add_child(_make_play_style_button(replay_text, func() -> void:
			zone_action_requested.emit("replay_library", zone.duplicate(true))
		))
	if text_col.get_child_count() > 0:
		row.add_child(text_col)
	if row.get_child_count() > 0:
		root.add_child(row)
	return root if root.get_child_count() > 1 else null


func _make_play_style_button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.theme_type_variation = &"FlatPlayButton"
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 40)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 16)
	_UiIconHelper.configure_button_icon(btn, "circle-play.svg", _UiIconHelper.ACCENT_MINT, 18)
	btn.pressed.connect(callback)
	return btn


func _make_daily_marathon_zone(zone: Dictionary) -> VBoxContainer:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	root.add_child(_make_divider())
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	var caption := str(zone.get("caption", "")).strip_edges()
	if caption != "":
		var cap := Label.new()
		cap.text = caption
		cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cap.add_theme_font_size_override("font_size", 14)
		cap.add_theme_color_override("font_color", _accent.lerp(Color.WHITE, 0.35))
		header.add_child(cap)
	var date := str(zone.get("date", "")).strip_edges()
	if date != "":
		var date_lbl := Label.new()
		date_lbl.text = date
		date_lbl.add_theme_font_size_override("font_size", 12)
		date_lbl.add_theme_color_override("font_color", Color(0.68, 0.72, 0.82, 0.92))
		header.add_child(date_lbl)
	if header.get_child_count() > 0:
		root.add_child(header)
	var summary := str(zone.get("summary", "")).strip_edges()
	if summary != "":
		var summary_lbl := Label.new()
		summary_lbl.text = summary
		summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary_lbl.add_theme_font_size_override("font_size", 14)
		summary_lbl.add_theme_color_override("font_color", Color(0.84, 0.88, 0.96, 0.96))
		root.add_child(summary_lbl)
	var status := str(zone.get("status", "")).strip_edges()
	var emphasized := bool(zone.get("emphasis", false))
	if status != "":
		var status_lbl := Label.new()
		status_lbl.text = status
		status_lbl.add_theme_font_size_override("font_size", 12)
		if emphasized:
			status_lbl.add_theme_color_override("font_color", _accent.lightened(0.12))
		else:
			status_lbl.add_theme_color_override("font_color", Color(0.62, 0.82, 0.72, 0.95))
		root.add_child(status_lbl)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	var play_text := str(zone.get("play_text", tr("MAIN_DAILY_MARATHON_PLAY")))
	var details_text := str(zone.get("details_text", tr("MAIN_DAILY_MARATHON_DETAILS")))
	var play_btn := _make_play_style_button(play_text, func() -> void:
		zone_action_requested.emit("daily_marathon_play", zone.duplicate(true))
	)
	play_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(play_btn)
	var details_btn := Button.new()
	details_btn.theme_type_variation = &"FlatButton"
	details_btn.text = details_text
	details_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_btn.custom_minimum_size = Vector2(0, 40)
	details_btn.add_theme_font_size_override("font_size", 14)
	details_btn.pressed.connect(func() -> void:
		zone_action_requested.emit("daily_marathon_details", zone.duplicate(true))
	)
	buttons.add_child(details_btn)
	root.add_child(buttons)
	if emphasized:
		_start_daily_emphasis_pulse(root)
	return root if root.get_child_count() > 1 else null


func _start_daily_emphasis_pulse(target: Control) -> void:
	if target == null:
		return
	var tw := target.create_tween()
	tw.set_loops()
	tw.tween_property(target, "modulate", Color(1.06, 1.04, 1.0, 1.0), 0.85).set_trans(Tween.TRANS_SINE)
	tw.tween_property(target, "modulate", Color.WHITE, 0.85).set_trans(Tween.TRANS_SINE)


func set_hero_overlay(_text: String) -> void:
	pass


func set_hero_streak(streak: int) -> void:
	_ensure_hero_streak_badge()
	if _hero and _hero.has_method("set_overlay_text"):
		_hero.set_overlay_text("")
	if _hero_streak_badge == null:
		return
	var show := not _is_locked and mode_id == _PlayModeIds.ENDLESS and streak > 0
	if not show:
		if _hero_streak_badge.get_parent():
			_hero_streak_badge.get_parent().remove_child(_hero_streak_badge)
		_hero_streak_badge.visible = false
		return
	if _title_row and _hero_streak_badge.get_parent() != _title_row:
		if _hero_streak_badge.get_parent():
			_hero_streak_badge.get_parent().remove_child(_hero_streak_badge)
		_title_row.add_child(_hero_streak_badge)
	_hero_streak_badge.visible = true
	var accent: Color = _accent if _accent != Color.WHITE else _PlayModeIds.accent_for(mode_id)
	var row := _hero_streak_badge.get_child(0) as HBoxContainer
	if row:
		var icon := row.get_node_or_null("StreakIcon") as TextureRect
		if icon:
			icon.texture = UiIconHelper.load_tinted_icon(
				"flame.svg",
				accent.lightened(0.2),
				UiIconHelper.raster_size_for_display(18)
			)
	if _hero_streak_label:
		_hero_streak_label.text = str(streak)
		_hero_streak_label.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 1.0))
	_hero_streak_badge.tooltip_text = tr("PLAY_MODE_ENDLESS_STREAK_BADGE_HINT") % streak
	var badge_box := StyleBoxFlat.new()
	badge_box.bg_color = Color(0.06, 0.08, 0.12, 0.9)
	badge_box.border_color = accent.lerp(Color.WHITE, 0.1)
	badge_box.set_border_width_all(1)
	badge_box.set_corner_radius_all(10)
	badge_box.content_margin_left = 8
	badge_box.content_margin_right = 10
	badge_box.content_margin_top = 4
	badge_box.content_margin_bottom = 4
	_hero_streak_badge.add_theme_stylebox_override("panel", badge_box)


func _make_replay_run_zone(zone: Dictionary) -> VBoxContainer:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	root.add_child(_make_divider())
	var caption := str(zone.get("caption", "")).strip_edges()
	if caption != "":
		var cap := Label.new()
		cap.text = caption
		cap.add_theme_font_size_override("font_size", 14)
		cap.add_theme_color_override("font_color", _accent.lerp(Color.WHITE, 0.35))
		root.add_child(cap)
	var summary := str(zone.get("summary", "")).strip_edges()
	if summary != "":
		var summary_lbl := Label.new()
		summary_lbl.text = summary
		summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		summary_lbl.add_theme_font_size_override("font_size", 15)
		summary_lbl.add_theme_color_override("font_color", Color(0.84, 0.88, 0.96, 1.0))
		root.add_child(summary_lbl)
	var replay_text := str(zone.get("button_text", tr("PLAY_MODE_REPLAY_RUN")))
	var action := str(zone.get("action", "replay_endless")).strip_edges()
	if action == "":
		action = "replay_endless"
	root.add_child(_make_play_style_button(replay_text, func() -> void:
		zone_action_requested.emit(action, zone.duplicate(true))
	))
	return root if root.get_child_count() > 1 else null


func _load_last_track_cover(root: VBoxContainer, cover_path: String) -> void:
	if not is_instance_valid(root):
		return
	var cover_tex := _RhythmDnaCoverLoader.load_cover_for_display(cover_path, 72)
	if cover_tex == null:
		return
	for child in root.get_children():
		if child is HBoxContainer:
			var row := child as HBoxContainer
			for existing in row.get_children():
				if existing is PanelContainer:
					return
			var cover_wrap := _make_cover_wrap(cover_tex)
			row.add_child(cover_wrap)
			row.move_child(cover_wrap, 0)
			return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_child(_make_cover_wrap(cover_tex))
	root.add_child(row)


func _make_cover_wrap(cover_tex: Texture2D) -> PanelContainer:
	const COVER_PX := 72
	var cover_wrap := PanelContainer.new()
	cover_wrap.custom_minimum_size = Vector2(COVER_PX + 8, COVER_PX + 8)
	cover_wrap.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cover_wrap.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var cover_style := StyleBoxFlat.new()
	cover_style.bg_color = Color(0.05, 0.06, 0.09, 1.0)
	cover_style.border_color = Color(_accent.r, _accent.g, _accent.b, 0.5)
	cover_style.border_width_top = 3
	cover_style.border_width_left = 1
	cover_style.border_width_right = 1
	cover_style.border_width_bottom = 1
	cover_style.set_corner_radius_all(10)
	cover_style.corner_detail = 12
	cover_style.content_margin_left = 4
	cover_style.content_margin_right = 4
	cover_style.content_margin_top = 4
	cover_style.content_margin_bottom = 4
	cover_wrap.add_theme_stylebox_override("panel", cover_style)
	var cover := TextureRect.new()
	cover.texture = cover_tex
	cover.custom_minimum_size = Vector2(COVER_PX, COVER_PX)
	cover.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cover.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cover.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cover.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var mat := ShaderMaterial.new()
	mat.shader = _ACHIEVEMENT_COVER_SHADER
	mat.set_shader_parameter("corner_radius_px", 14.0)
	cover.material = mat
	cover_wrap.add_child(cover)
	return cover_wrap


func _make_bullets_zone(zone: Dictionary) -> VBoxContainer:
	var bullets: Array = zone.get("bullets", [])
	if bullets.is_empty():
		return null
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 3)
	root.add_child(_make_divider())
	var caption := str(zone.get("caption", "")).strip_edges()
	if caption != "":
		var cap := Label.new()
		cap.text = caption
		cap.add_theme_font_size_override("font_size", 13)
		cap.add_theme_color_override("font_color", _accent.lerp(Color.WHITE, 0.35))
		root.add_child(cap)
	for item in bullets:
		var line := ""
		var icon_file := ""
		if item is Dictionary:
			line = str(item.get("text", "")).strip_edges()
			icon_file = str(item.get("icon", "")).strip_edges()
		else:
			line = str(item).strip_edges()
		if line == "":
			continue
		if icon_file != "":
			root.add_child(_make_icon_row(icon_file, line, 15))
		else:
			root.add_child(_make_bullet_label(line))
	return root


func _make_bullet_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = "• %s" % text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.86, 0.93, 1.0))
	return lbl


func _make_icon_row(icon_file: String, text: String, font_size: int = 15) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(16, 16)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = UiIconHelper.load_tinted_icon(icon_file, _accent.lerp(Color.WHITE, 0.25), 16)
	row.add_child(icon)
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.94, 1.0))
	row.add_child(label)
	return row


func _make_countdown_zone(zone: Dictionary) -> VBoxContainer:
	return _make_zone_block(zone, true)


func _make_zone_block(zone: Dictionary, bind_countdown: bool = false) -> VBoxContainer:
	var rows: Array = zone.get("rows", [])
	var caption := str(zone.get("caption", "")).strip_edges()
	if rows.is_empty() and caption == "":
		return null
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 3)
	root.add_child(_make_divider())
	if caption != "":
		var cap := Label.new()
		cap.text = caption
		cap.add_theme_font_size_override("font_size", 13)
		cap.add_theme_color_override("font_color", _accent.lerp(Color.WHITE, 0.35))
		root.add_child(cap)
		if bind_countdown:
			_countdown_caption_label = cap
	for row in rows:
		var line := ""
		var icon_file := ""
		if row is Dictionary:
			line = str(row.get("text", "")).strip_edges()
			icon_file = str(row.get("icon", "")).strip_edges()
		else:
			line = str(row).strip_edges()
		if line == "":
			continue
		var highlight := str(zone.get("highlight", "")).strip_edges()
		if icon_file != "":
			var icon_row := _make_icon_row(icon_file, line, 15 if line != highlight else 20)
			if line == highlight:
				for child in icon_row.get_children():
					if child is Label:
						(child as Label).add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1.0))
			root.add_child(icon_row)
			continue
		var lbl := Label.new()
		lbl.text = line
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 15)
		if line == highlight:
			lbl.add_theme_font_size_override("font_size", 20)
			lbl.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1.0))
		else:
			lbl.add_theme_color_override("font_color", Color(0.82, 0.88, 0.94, 1.0))
		root.add_child(lbl)
	return root


func _make_divider() -> Control:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 1)
	line.color = Color(1, 1, 1, 0.08)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return line


func _set_accent_hints(hints: Array) -> void:
	if _accent_hints_flow == null:
		return
	for child in _accent_hints_flow.get_children():
		child.queue_free()
	var has_hints := false
	for hint in hints:
		if not hint is Dictionary:
			continue
		var text := str((hint as Dictionary).get("text", "")).strip_edges()
		if text == "":
			continue
		var icon_file := str((hint as Dictionary).get("icon", "")).strip_edges()
		var accent_hint: Color = (hint as Dictionary).get("accent", _accent) as Color
		_accent_hints_flow.add_child(_make_hint_pill(icon_file, text, accent_hint))
		has_hints = true
	_accent_hints_flow.visible = has_hints


func _make_hint_pill(icon_file: String, text: String, accent_hint: Color) -> PanelContainer:
	var pill := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(accent_hint.r, accent_hint.g, accent_hint.b, 0.14)
	box.border_color = accent_hint.lerp(Color.WHITE, 0.22)
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	pill.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	if icon_file != "":
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(12, 12)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = UiIconHelper.load_tinted_icon(icon_file, accent_hint.lightened(0.15), 12)
		row.add_child(icon)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", accent_hint.lerp(Color.WHITE, 0.42))
	row.add_child(lbl)
	pill.add_child(row)
	return pill


func _set_unlock_rows(rows: Array) -> void:
	if _unlock_rows == null:
		return
	for child in _unlock_rows.get_children():
		child.queue_free()
	if _is_locked:
		var cap := Label.new()
		cap.text = tr("PLAY_MODE_UNLOCK_ALL_REQUIRED")
		cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cap.add_theme_font_size_override("font_size", 14)
		cap.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92, 1.0))
		_unlock_rows.add_child(cap)
		_unlock_rows.add_child(_make_divider())
	for entry in rows:
		if not entry is Dictionary:
			continue
		var label_text := str(entry.get("label", "")).strip_edges()
		if label_text == "":
			continue
		_unlock_rows.add_child(_make_unlock_row(label_text, bool(entry.get("met", false))))
	_unlock_rows.visible = _is_locked


func _make_unlock_row(label_text: String, met: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(16, 16)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_name := "circle-check.svg" if met else "info.svg"
	var tint := _accent if met else UiIconHelper.MUTED
	icon.texture = UiIconHelper.load_tinted_icon(icon_name, tint)
	row.add_child(icon)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override(
		"font_color",
		Color(0.9, 0.95, 0.99, 1.0) if met else Color(0.72, 0.78, 0.86, 1.0)
	)
	row.add_child(label)
	return row


func _apply_visuals() -> void:
	var accent: Color = _PlayModeIds.accent_for(mode_id)
	var wash: Color = _PlayModeIds.illustration_tint_for(mode_id)
	_accent = accent
	if _hero and _hero.has_method("configure"):
		_hero.configure(mode_id, accent, wash, _is_locked)
	var icon_file: String = _PlayModeIds.icon_for(mode_id)
	if _hero_icon:
		var icon_tint := accent.lightened(0.18) if not _is_locked else UiIconHelper.MUTED
		_hero_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_hero_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_hero_icon.custom_minimum_size = Vector2(28, 28)
		_hero_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_hero_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_hero_icon.texture = UiIconHelper.load_tinted_icon(
			icon_file, icon_tint, UiIconHelper.raster_size_for_display(28)
		)
	if _hero_icon_badge:
		var badge_box := StyleBoxFlat.new()
		badge_box.bg_color = Color(0.06, 0.08, 0.12, 0.96)
		# No border on full-circle StyleBoxFlat — it draws a center seam.
		badge_box.set_border_width_all(0)
		badge_box.set_corner_radius_all(999)
		badge_box.set_content_margin_all(0)
		_hero_icon_badge.add_theme_stylebox_override("panel", badge_box)
		_hero_icon_badge.custom_minimum_size = Vector2(56, 56)
		_hero_icon_badge.visible = true
	if _icon_texture:
		_icon_texture.visible = false
	if _lock_icon:
		_lock_icon.visible = _is_locked
		if _is_locked:
			_lock_icon.texture = UiIconHelper.load_tinted_icon("lock_keyhole.svg", Color(0.92, 0.78, 0.42, 1.0))
	if _title_label:
		_title_label.add_theme_font_size_override("font_size", 24)
		_title_label.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 1.0))
	if _desc_label:
		_desc_label.add_theme_font_size_override("font_size", 14)
		_desc_label.add_theme_color_override("font_color", Color(0.74, 0.8, 0.9, 1.0))
	var badge_color := badge_color_for_panel(accent)
	if _badge_label:
		_badge_label.add_theme_color_override("font_color", badge_color.lightened(0.08))
	if _badge_panel:
		var badge_box := StyleBoxFlat.new()
		badge_box.bg_color = Color(0.06, 0.08, 0.12, 0.88)
		badge_box.border_color = badge_color
		badge_box.set_border_width_all(1)
		badge_box.set_corner_radius_all(10)
		badge_box.content_margin_left = 10
		badge_box.content_margin_right = 10
		badge_box.content_margin_top = 4
		badge_box.content_margin_bottom = 4
		_badge_panel.add_theme_stylebox_override("panel", badge_box)
	if _content_panel:
		var content_box := StyleBoxFlat.new()
		content_box.bg_color = Color(0.06, 0.08, 0.12, 1.0)
		content_box.border_width_top = 1
		content_box.border_color = accent.lerp(Color(1, 1, 1, 1), 0.1)
		_content_panel.add_theme_stylebox_override("panel", content_box)
	_apply_action_button_visuals(accent)
	modulate = Color(0.88, 0.9, 0.94, 1.0) if _is_locked else Color.WHITE
	_sync_panel_border(accent)
	_apply_unlock_motion()


func _apply_action_button_visuals(accent: Color) -> void:
	if _action_button == null:
		return
	_action_button.custom_minimum_size.y = 50
	if _is_locked and _unlock_ready:
		_action_button.theme_type_variation = &"FlatButtonYellow"
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			_action_button.remove_theme_stylebox_override(state)
		_action_button.add_theme_font_size_override("font_size", 15)
		_action_button.icon = null
		return
	if mode_id == _PlayModeIds.LIBRARY:
		_action_button.theme_type_variation = &"FlatPlayButton"
	else:
		_action_button.theme_type_variation = &"FlatGenerateButton"
	_apply_action_button_style(accent)
	_apply_action_button_icon(accent)


func _apply_unlock_motion() -> void:
	_UiMotionEffects.stop_control_border_pulse(self)
	if _action_button:
		_UiMotionEffects.stop_control_border_pulse(_action_button)
	if _is_locked and _unlock_ready and _action_button:
		_UiMotionEffects.pulse_button_outline(_action_button, UNLOCK_BORDER_COLOR, 0.45, 0.95, 0.72)


func _apply_action_button_icon(accent: Color) -> void:
	if _action_button == null or _is_locked:
		return
	match mode_id:
		_PlayModeIds.LIBRARY:
			_UiIconHelper.configure_button_icon(_action_button, "book-open.svg", accent.lightened(0.08), 18)
		_PlayModeIds.ENDLESS:
			_UiIconHelper.configure_button_icon(_action_button, "circle-play.svg", accent.lightened(0.08), 18)
		_PlayModeIds.MARATHON:
			_UiIconHelper.configure_button_icon(_action_button, "layers.svg", accent.lightened(0.08), 18)
		_:
			_action_button.icon = null


func _apply_action_button_style(accent: Color) -> void:
	if _action_button == null:
		return
	var border_col := accent if not _is_locked else Color(0.92, 0.78, 0.42, 0.55)
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.08, 0.1, 0.14, 0.95) if state != "hover" else Color(0.1, 0.12, 0.17, 0.98)
		if state == "pressed":
			box.bg_color = Color(0.06, 0.08, 0.12, 1.0)
		box.border_color = border_col.lerp(Color.WHITE, 0.12 if state == "hover" else 0.0)
		box.set_border_width_all(2)
		box.set_corner_radius_all(10)
		box.content_margin_top = 10
		box.content_margin_bottom = 10
		box.content_margin_left = 14
		box.content_margin_right = 14
		_action_button.add_theme_stylebox_override(state, box)
	_action_button.add_theme_font_size_override("font_size", 15)


func badge_color_for_panel(accent: Color) -> Color:
	if _is_locked:
		return Color(0.92, 0.78, 0.42, 0.9)
	return accent


func _sync_panel_border(accent: Color, _focused: bool = false) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.04, 0.06, 0.09, 1.0)
	var border_col := accent.lerp(Color.WHITE, 0.14)
	if _is_locked:
		border_col = accent.lerp(Color(0.45, 0.48, 0.56), 0.35)
		border_col.a = 0.45
	else:
		border_col.a = 0.72
	box.border_color = border_col
	box.set_border_width_all(_CARD_BORDER_PX)
	box.set_corner_radius_all(_CARD_CORNER_RADIUS)
	box.corner_detail = 16
	box.shadow_size = 0
	# Inset children under the stroke so hero/actions never sit on the frame.
	box.set_content_margin_all(float(_CARD_CONTENT_INSET))
	add_theme_stylebox_override("panel", box)
	_UiRoundedClip.clip_to_frame(self)
	_UiRoundedClip.ensure_border_on_top(self)


func _exit_tree() -> void:
	_UiMotionEffects.stop_control_border_pulse(self)
	if _action_button:
		_UiMotionEffects.stop_control_border_pulse(_action_button)


func _on_mouse_entered() -> void:
	if _is_locked:
		return
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate", Color(1.03, 1.04, 1.06, 1.0), 0.14)


func _on_mouse_exited() -> void:
	var target := Color.WHITE
	if _is_locked:
		target = Color(0.88, 0.9, 0.94, 1.0)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate", target, 0.14)


func _on_action_pressed() -> void:
	if mode_id == "":
		return
	action_pressed.emit(mode_id)
