# scenes/song_select/controllers/song_museum_panel.gd
# Left passport column — varied blocks like mockup V3.
extends PanelContainer
class_name SongMuseumPanel

const _ModifierIconStrip = preload("res://logic/ui/modifier_icon_strip.gd")
const _SS = preload("res://logic/domain/library/song_select_strings.gd")
const _ActivityCalendar = preload("res://logic/domain/profile/activity_calendar.gd")
const _TrackMedals = preload("res://logic/domain/library/track_medals.gd")
const _UiStyles = preload("res://scenes/song_select/lib/song_select_ui_styles.gd")
const _GenPresetUi = preload("res://logic/ui/generation_preset_ui.gd")
const _GoalDiff = preload("res://logic/domain/generation/generation_goal_difficulty.gd")

const PANEL_WIDTH := 288
const COLOR_RR := Color(0.949, 0.702, 0.353, 1.0)
const COLOR_MUTED := Color(0.58, 0.62, 0.70, 1.0)
const COLOR_VALUE := Color(0.94, 0.95, 0.98, 1.0)
const MEDAL_SLOT := 44
const MEDAL_ICON := 24
const MOD_ICON := 22
const MOD_FRAME_PAD := 14
const VALUE_ICON := 26
const VALUE_ICON_INNER := 16

var _title: Label
var _hero_first: Label
var _hero_first_cap: Label
var _hero_runs: Label
var _note_label: Label
var _grid: GridContainer
var _avg_cell: PanelContainer
var _time_cell: PanelContainer
var _rr_cell: PanelContainer
var _fc_cell: PanelContainer
var _ss_cell: PanelContainer
var _avg_value: Label
var _time_value: Label
var _rr_value: Label
var _rr_cap: Label
var _fc_value: Label
var _ss_value: Label
var _style_card: PanelContainer
var _style_icon_host: Control
var _style_value: Label
var _inst_card: PanelContainer
var _inst_icon_host: Control
var _inst_value: Label
var _last_block: VBoxContainer
var _last_value: Label
var _medals_block: VBoxContainer
var _medals_count: Label
var _medals_grid: GridContainer
var _mods_block: VBoxContainer
var _mods_row: HBoxContainer
var _medal_slots: Array = []


func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_if_needed()


func _build_if_needed() -> void:
	if _title != null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.11, 0.15, 0.97)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.36, 0.38, 0.46, 0.95)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	add_theme_stylebox_override("panel", sb)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.custom_minimum_size = Vector2(PANEL_WIDTH - 24, 0)
	add_child(outer)

	_title = Label.new()
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0, 1.0))
	outer.add_child(_title)

	# Hero: first + runs (larger, stacked)
	var hero := _make_inner_card(Color(0.14, 0.16, 0.22, 0.95), Color(0.42, 0.55, 0.78, 0.55))
	outer.add_child(hero)
	var hero_box := VBoxContainer.new()
	hero_box.add_theme_constant_override("separation", 8)
	hero.add_child(hero_box)
	_hero_first = _add_hero_line(hero_box, "calendar.svg", Color(0.55, 0.78, 0.98, 1.0), _SS._translate("SONG_MUSEUM_FIRST_CAPTION"), true)
	_hero_runs = _add_hero_line(hero_box, "circle-play.svg", Color(0.42, 0.88, 0.58, 1.0), _SS._translate("SONG_MUSEUM_RUNS_CAPTION"), false)
	_note_label = Label.new()
	_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_label.add_theme_font_size_override("font_size", 12)
	_note_label.add_theme_color_override("font_color", COLOR_MUTED)
	_note_label.visible = false
	hero_box.add_child(_note_label)

	# Metric tiles (mockup-3 containers): avg/RR/time/FC/SS
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	outer.add_child(_grid)

	var avg_pack := _make_metric_tile("target.svg", Color(0.55, 0.86, 0.92, 1.0), _SS._translate("SONG_MUSEUM_AVG_ACC_CAPTION"))
	_avg_cell = avg_pack.cell
	_avg_value = avg_pack.value
	_avg_value.add_theme_font_size_override("font_size", 22)
	_grid.add_child(_avg_cell)

	var rr_pack := _make_metric_tile("flame_gen.svg", COLOR_RR, _SS._translate("SONG_MUSEUM_BEST_RR_CAPTION"))
	_rr_cell = rr_pack.cell
	_rr_value = rr_pack.value
	_rr_cap = rr_pack.caption
	_rr_value.add_theme_color_override("font_color", COLOR_RR)
	_rr_value.clip_text = true
	_rr_value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_grid.add_child(_rr_cell)

	var time_pack := _make_metric_tile("clock.svg", Color(0.72, 0.78, 0.92, 1.0), _SS._translate("SONG_MUSEUM_TIME_CAPTION"))
	_time_cell = time_pack.cell
	_time_value = time_pack.value
	_grid.add_child(_time_cell)

	var fc_pack := _make_metric_tile("circle-check.svg", Color(0.55, 0.86, 0.72, 1.0), _SS._translate("SONG_MUSEUM_FC_CAPTION"))
	_fc_cell = fc_pack.cell
	_fc_value = fc_pack.value
	_grid.add_child(_fc_cell)

	var ss_pack := _make_metric_tile("trophy.svg", Color(0.95, 0.82, 0.45, 1.0), _SS._translate("SONG_MUSEUM_SS_CAPTION"))
	_ss_cell = ss_pack.cell
	_ss_value = ss_pack.value
	_grid.add_child(_ss_cell)

	# Favorite chart style — full-width container with style icon + label
	var style_pack := _make_fav_card(
		_SS._translate("SONG_MUSEUM_FAV_STYLE_CAPTION"),
		"layers.svg",
		Color(0.72, 0.62, 0.95, 1.0)
	)
	_style_card = style_pack.card
	_style_icon_host = style_pack.icon_host
	_style_value = style_pack.value
	outer.add_child(_style_card)

	# Favorite instrument — same card pattern
	var inst_pack := _make_fav_card(
		_SS._translate("SONG_MUSEUM_FAV_INST_CAPTION"),
		"music.svg",
		Color(0.38, 0.78, 0.74, 1.0)
	)
	_inst_card = inst_pack.card
	_inst_icon_host = inst_pack.icon_host
	_inst_value = inst_pack.value
	outer.add_child(_inst_card)

	# Last play
	_last_block = _make_section(outer, "rotate-ccw.svg", Color(0.70, 0.76, 0.88, 1.0), _SS._translate("SONG_MUSEUM_LAST_CAPTION"))
	_last_value = Label.new()
	_last_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_last_value.add_theme_font_size_override("font_size", 15)
	_last_value.add_theme_color_override("font_color", COLOR_VALUE)
	_last_block.add_child(_last_value)

	# Medals 2×4 circles
	_medals_block = VBoxContainer.new()
	_medals_block.add_theme_constant_override("separation", 6)
	outer.add_child(_medals_block)
	var medals_head := HBoxContainer.new()
	medals_head.add_theme_constant_override("separation", 6)
	_medals_block.add_child(medals_head)
	medals_head.add_child(UiIconHelper.make_icon_frame("star.svg", 22, 13, Color(0.95, 0.75, 0.40, 1.0)))
	var medals_cap := Label.new()
	medals_cap.text = _SS._translate("SONG_MUSEUM_MEDALS_CAPTION")
	medals_cap.add_theme_font_size_override("font_size", 13)
	medals_cap.add_theme_color_override("font_color", COLOR_MUTED)
	medals_head.add_child(medals_cap)
	_medals_count = Label.new()
	_medals_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_medals_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_medals_count.add_theme_font_size_override("font_size", 13)
	_medals_count.add_theme_color_override("font_color", COLOR_VALUE)
	medals_head.add_child(_medals_count)
	var medals_center := CenterContainer.new()
	medals_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_medals_block.add_child(medals_center)
	_medals_grid = GridContainer.new()
	_medals_grid.columns = 4
	_medals_grid.add_theme_constant_override("h_separation", 10)
	_medals_grid.add_theme_constant_override("v_separation", 10)
	medals_center.add_child(_medals_grid)
	_medal_slots.clear()
	for medal_id in _TrackMedals.ALL_IDS:
		var slot := _make_medal_circle(str(medal_id))
		_medals_grid.add_child(slot)
		_medal_slots.append(slot)

	# Favorite mods — top 3 (medal-sized chips)
	_mods_block = VBoxContainer.new()
	_mods_block.add_theme_constant_override("separation", 6)
	_mods_block.visible = false
	outer.add_child(_mods_block)
	var mods_head := HBoxContainer.new()
	mods_head.add_theme_constant_override("separation", 6)
	_mods_block.add_child(mods_head)
	mods_head.add_child(UiIconHelper.make_icon_frame("wrench.svg", 22, 13, Color(0.72, 0.58, 0.92, 1.0)))
	var mods_cap := Label.new()
	mods_cap.text = _SS._translate("SONG_MUSEUM_MODS")
	mods_cap.add_theme_font_size_override("font_size", 13)
	mods_cap.add_theme_color_override("font_color", COLOR_MUTED)
	mods_head.add_child(mods_cap)
	_mods_row = HBoxContainer.new()
	_mods_row.add_theme_constant_override("separation", 6)
	_mods_block.add_child(_mods_row)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(spacer)


func _make_inner_card(bg: Color, border: Color) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", style)
	return card


func _add_hero_line(
	parent: VBoxContainer,
	icon_file: String,
	tint: Color,
	caption: String,
	store_first_cap: bool = false
) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	row.add_child(UiIconHelper.make_icon_frame(icon_file, 28, 16, tint))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 1)
	row.add_child(col)
	var cap := Label.new()
	cap.text = caption
	cap.add_theme_font_size_override("font_size", 12)
	cap.add_theme_color_override("font_color", COLOR_MUTED)
	col.add_child(cap)
	if store_first_cap:
		_hero_first_cap = cap
	var value := Label.new()
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.add_theme_font_size_override("font_size", 17)
	value.add_theme_color_override("font_color", COLOR_VALUE)
	col.add_child(value)
	return value


func _make_metric_tile(icon_file: String, tint: Color, caption: String) -> Dictionary:
	var cell := _make_inner_card(Color(0.13, 0.14, 0.19, 0.95), Color(0.30, 0.33, 0.40, 0.8))
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.custom_minimum_size = Vector2(0, 72)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	cell.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	box.add_child(head)
	head.add_child(UiIconHelper.make_icon_frame(icon_file, 18, 11, tint))
	var cap := Label.new()
	cap.text = caption
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.clip_text = false
	cap.add_theme_font_size_override("font_size", 10)
	cap.add_theme_color_override("font_color", COLOR_MUTED)
	head.add_child(cap)
	var value := Label.new()
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.add_theme_font_size_override("font_size", 16)
	value.add_theme_color_override("font_color", COLOR_VALUE)
	box.add_child(value)
	return {"cell": cell, "value": value, "caption": cap}


func _make_fav_card(caption: String, fallback_icon: String, tint: Color) -> Dictionary:
	var card := _make_inner_card(Color(0.13, 0.14, 0.19, 0.95), Color(0.30, 0.33, 0.40, 0.8))
	card.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var cap := Label.new()
	cap.text = caption
	cap.add_theme_font_size_override("font_size", 11)
	cap.add_theme_color_override("font_color", COLOR_MUTED)
	box.add_child(cap)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var icon_host := Control.new()
	icon_host.custom_minimum_size = Vector2(VALUE_ICON, VALUE_ICON)
	icon_host.set_meta("fallback_icon", fallback_icon)
	icon_host.set_meta("tint", tint)
	row.add_child(icon_host)
	icon_host.add_child(UiIconHelper.make_icon_frame(fallback_icon, VALUE_ICON, VALUE_ICON_INNER, tint))
	var value := Label.new()
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.add_theme_font_size_override("font_size", 16)
	value.add_theme_color_override("font_color", COLOR_VALUE)
	row.add_child(value)
	return {"card": card, "icon_host": icon_host, "value": value}


func _set_fav_icon(host: Control, icon_file: String, tint: Color) -> void:
	if host == null:
		return
	for child in host.get_children():
		child.queue_free()
	var file := icon_file.strip_edges()
	if file == "":
		file = str(host.get_meta("fallback_icon", "circle-check.svg"))
	host.add_child(UiIconHelper.make_icon_frame(file, VALUE_ICON, VALUE_ICON_INNER, tint))


func _instrument_icon_pack(instrument_id: String) -> Dictionary:
	var id := instrument_id.strip_edges().to_lower()
	var key := _GenPresetUi.entry_instrument_icon_key(id)
	return {
		"icon": str(_GenPresetUi.INSTRUMENT_ICONS.get(key, "drum.svg")),
		"tint": _GenPresetUi.INSTRUMENT_ICON_COLORS.get(id, Color(0.38, 0.78, 0.74, 1.0)),
	}


func _style_icon_pack(mode_raw: String) -> Dictionary:
	var mode := mode_raw.strip_edges().to_lower()
	var goal := ""
	if mode != "" and _GoalDiff.is_chart_stem(mode):
		var pair: Dictionary = _GoalDiff.pair_from_stem(mode)
		goal = str(pair.get("goal", ""))
	elif mode in _GenPresetUi.INTENT_ICONS:
		goal = mode
	elif mode != "":
		var pair2: Dictionary = _GoalDiff.from_intent(mode)
		goal = str(pair2.get("goal", mode))
	if goal in _GenPresetUi.INTENT_ICONS:
		return {
			"icon": str(_GenPresetUi.INTENT_ICONS[goal]),
			"tint": _GenPresetUi.INTENT_ICON_COLORS.get(goal, Color(0.72, 0.62, 0.95, 1.0)),
		}
	if mode in _GenPresetUi.MODE_ICONS:
		return {
			"icon": str(_GenPresetUi.MODE_ICONS[mode]),
			"tint": _GenPresetUi.MODE_ICON_COLORS.get(mode, Color(0.72, 0.62, 0.95, 1.0)),
		}
	return {
		"icon": "layers.svg",
		"tint": Color(0.72, 0.62, 0.95, 1.0),
	}


func _format_rr(rr: int) -> String:
	var n := absi(rr)
	var body := str(n)
	if n >= 1_000_000:
		body = "%.1fM" % (float(n) / 1_000_000.0)
	elif n >= 100_000:
		body = "%dk" % int(round(float(n) / 1000.0))
	elif n >= 10_000:
		body = "%.1fk" % (float(n) / 1000.0)
	return _SS._translate("SONG_MUSEUM_RR_FMT") % body


func _make_section(parent: VBoxContainer, icon_file: String, tint: Color, caption: String) -> VBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 4)
	block.visible = false
	parent.add_child(block)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	block.add_child(head)
	head.add_child(UiIconHelper.make_icon_frame(icon_file, 22, 13, tint))
	var cap := Label.new()
	cap.text = caption
	cap.add_theme_font_size_override("font_size", 13)
	cap.add_theme_color_override("font_color", COLOR_MUTED)
	head.add_child(cap)
	return block


func _make_medal_circle(medal_id: String) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(MEDAL_SLOT, MEDAL_SLOT)
	slot.set_meta("medal_id", medal_id)
	slot.tooltip_text = "%s\n%s" % [
		TranslationServer.translate(_TrackMedals.title_i18n_key(medal_id)),
		TranslationServer.translate(_TrackMedals.desc_i18n_key(medal_id)),
	]
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(center)
	var path := _TrackMedals.icon_path(medal_id)
	if path != "":
		var tex := load(path) as Texture2D
		if tex:
			var icon := UiIconHelper.make_texture_rect(tex, MEDAL_ICON)
			center.add_child(icon)
			slot.set_meta("medal_icon", icon)
	_set_medal_unlocked(slot, false)
	return slot


func _set_medal_unlocked(slot: PanelContainer, unlocked: bool) -> void:
	var style: StyleBoxFlat
	if unlocked:
		style = _UiStyles.medal_slot_earned_style().duplicate() as StyleBoxFlat
	else:
		style = _UiStyles.medal_slot_locked_style().duplicate() as StyleBoxFlat
	style.set_corner_radius_all(int(MEDAL_SLOT / 2.0))
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	slot.add_theme_stylebox_override("panel", style)
	slot.modulate = Color.WHITE if unlocked else Color(0.72, 0.76, 0.84, 0.85)
	var icon := slot.get_meta("medal_icon", null) as TextureRect
	if icon:
		# Earned: white glyph + gold frame (same as track medals strip). Locked: gray.
		icon.modulate = Color.WHITE if unlocked else Color(0.72, 0.76, 0.84, 0.95)


func clear_passport() -> void:
	_build_if_needed()
	visible = false
	_hero_first.text = "—"
	_hero_runs.text = "—"
	if _note_label:
		_note_label.text = ""
		_note_label.visible = false
	_avg_value.text = "—"
	_time_value.text = "—"
	_rr_value.text = "—"
	_rr_value.tooltip_text = ""
	_fc_value.text = "—"
	_ss_value.text = "—"
	_avg_cell.visible = false
	_time_cell.visible = false
	_rr_cell.visible = false
	_fc_cell.visible = false
	_ss_cell.visible = false
	_style_card.visible = false
	_inst_card.visible = false
	_last_block.visible = false
	_mods_block.visible = false
	_medals_count.text = "0/%d" % _TrackMedals.COUNT
	for slot in _medal_slots:
		if slot is PanelContainer:
			_set_medal_unlocked(slot, false)
	for child in _mods_row.get_children():
		child.queue_free()


func show_passport(data: Dictionary) -> void:
	_build_if_needed()
	custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_title.text = _SS._translate("SONG_MUSEUM_TITLE")

	var song_path := str(data.get("song_path", "")).replace("\\", "/").strip_edges()
	const _VoiceLibrary = preload("res://logic/ui/voice_library.gd")
	if _hero_first_cap:
		_hero_first_cap.text = _VoiceLibrary.museum_first_caption(song_path if song_path != "" else "museum")
	if _rr_cap:
		_rr_cap.text = _VoiceLibrary.best_rr_caption(song_path if song_path != "" else "museum")

	var first_iso := str(data.get("first_played", "")).strip_edges()
	var first_text := TimeUtils.format_session_datetime_localized(first_iso)
	_hero_first.text = first_text if first_text != "" else "—"

	var play_count := int(data.get("play_count", 0))
	_hero_runs.text = str(play_count) if play_count > 0 else "—"

	const _DiaryVoice = preload("res://logic/domain/profile/diary_voice.gd")
	var note := _DiaryVoice.museum_line(data)
	if _note_label:
		_note_label.text = note
		_note_label.visible = note != ""

	var avg_acc := float(data.get("avg_accuracy", -1.0))
	if avg_acc >= 0.0:
		_avg_value.text = "%.1f%%" % avg_acc
		_avg_cell.visible = true
	else:
		_avg_cell.visible = false

	var play_seconds := int(data.get("play_seconds", 0))
	if play_seconds > 0:
		_time_value.text = _ActivityCalendar.format_play_hms(play_seconds)
		_time_cell.visible = true
	else:
		_time_cell.visible = false

	var best_rr := int(data.get("best_rr", 0))
	if best_rr > 0:
		_rr_value.text = _format_rr(best_rr)
		_rr_value.tooltip_text = _SS._translate("SONG_MUSEUM_RR_FMT") % str(best_rr)
		_rr_cell.visible = true
	else:
		_rr_value.tooltip_text = ""
		_rr_cell.visible = false

	var fc_count := int(data.get("fc_count", 0))
	if fc_count > 0:
		_fc_value.text = str(fc_count)
		_fc_cell.visible = true
	else:
		_fc_cell.visible = false

	var ss_count := int(data.get("ss_count", 0))
	if ss_count > 0:
		_ss_value.text = str(ss_count)
		_ss_cell.visible = true
	else:
		_ss_cell.visible = false

	var fav_style := str(data.get("favorite_style", "")).strip_edges()
	if fav_style != "":
		var style_pack: Dictionary = _style_icon_pack(str(data.get("favorite_mode", "")))
		var style_tint: Color = style_pack.get("tint", Color(0.72, 0.62, 0.95, 1.0))
		_set_fav_icon(_style_icon_host, str(style_pack.get("icon", "")), style_tint)
		_style_value.text = fav_style
		_style_value.add_theme_color_override("font_color", style_tint)
		_style_card.visible = true
	else:
		_style_card.visible = false

	var last_iso := str(data.get("last_played", "")).strip_edges()
	var last_text := TimeUtils.format_session_datetime_localized(last_iso)
	if last_text != "":
		_last_value.text = last_text
		_last_block.visible = true
	else:
		_last_block.visible = false

	var fav_inst := str(data.get("favorite_instrument", "")).strip_edges()
	if fav_inst != "":
		var inst_pack: Dictionary = _instrument_icon_pack(str(data.get("favorite_instrument_id", "")))
		var inst_tint: Color = inst_pack.get("tint", Color(0.38, 0.78, 0.74, 1.0))
		_set_fav_icon(_inst_icon_host, str(inst_pack.get("icon", "")), inst_tint)
		_inst_value.text = fav_inst
		_inst_value.add_theme_color_override("font_color", inst_tint)
		_inst_card.visible = true
	else:
		_inst_card.visible = false

	var unlocked: Array = data.get("medals_unlocked", [])
	var unlocked_set := {}
	for mid in _TrackMedals.sanitize_unlocked(unlocked):
		unlocked_set[str(mid)] = true
	var earned := unlocked_set.size()
	_medals_count.text = "%d/%d" % [earned, _TrackMedals.COUNT]
	for slot in _medal_slots:
		if slot is PanelContainer:
			var mid := str(slot.get_meta("medal_id", ""))
			_set_medal_unlocked(slot, unlocked_set.has(mid))

	var top_mods: Array = data.get("top_mods", [])
	for child in _mods_row.get_children():
		child.queue_free()
	if top_mods.is_empty():
		_mods_block.visible = false
	else:
		_ModifierIconStrip.fill_slot_chips(
			_mods_row,
			top_mods,
			{},
			3,
			true,
			MOD_ICON,
			MOD_FRAME_PAD,
			6,
			false
		)
		_mods_block.visible = _mods_row.get_child_count() > 0

	visible = true
