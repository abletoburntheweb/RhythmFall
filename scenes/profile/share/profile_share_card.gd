# scenes/profile/share/profile_share_card.gd
extends PanelContainer

signal card_pressed(card_id: String)

const _Snapshot = preload("res://scenes/profile/share/profile_share_snapshot.gd")
const _GenrePortrait = preload("res://logic/domain/profile/profile_genre_portrait.gd")
const GradeDisplay = preload("res://logic/ui/grade_display.gd")
const ChartDifficultyAnalyzer = preload("res://logic/domain/charts/chart_difficulty_analyzer.gd")

const PREVIEW_MIN_SIZE := Vector2(190, 340)
const EXPORT_SIZE := Vector2i(380, 680)

const _SEL_BORDER := Color(0.98, 0.86, 0.52, 0.95)
const _BG_COLOR := Color(0.06, 0.07, 0.1, 0.98)
const _MUTED := Color(0.58, 0.64, 0.74, 0.95)
const _TEXT := Color(0.9, 0.92, 0.96, 1.0)

var card_id: String = ""
var hotkey_index: int = 0
var _selected := false
var _for_export := false
var _scale := 1.0

@onready var _hotkey_label: Label = %HotkeyLabel
@onready var _content_vbox: VBoxContainer = %ContentVBox
@onready var _logo_rect: TextureRect = %LogoRect
@onready var _footer_site_label: Label = %FooterSiteLabel
@onready var _footer_date_label: Label = %FooterDateLabel
@onready var _click_button: Button = %ClickButton


func _ready() -> void:
	if not _click_button.pressed.is_connected(_on_click_button_pressed):
		_click_button.pressed.connect(_on_click_button_pressed)
	_load_logo()
	_apply_panel_style()


func setup(p_card_id: String, p_hotkey_index: int) -> void:
	card_id = p_card_id
	hotkey_index = p_hotkey_index
	if is_node_ready():
		_apply_hotkey_label()
		_apply_panel_style()


func apply_data(p_card_id: String, data: Dictionary, for_export: bool = false) -> void:
	card_id = p_card_id
	_for_export = for_export
	_scale = 1.0 if for_export else 0.5
	var size := Vector2(EXPORT_SIZE) if for_export else PREVIEW_MIN_SIZE
	custom_minimum_size = size
	if for_export:
		size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_apply_hotkey_label()
	_apply_panel_style()
	_apply_footer(data)
	_rebuild_content(data)


func set_selected(selected: bool) -> void:
	_selected = selected
	_apply_panel_style()


func get_export_size() -> Vector2i:
	return EXPORT_SIZE


func apply_locale() -> void:
	if card_id != "":
		_apply_content_locale()
		_rebuild_content(_Snapshot.build_card(card_id))


func _accent() -> Color:
	return _Snapshot.CARD_ACCENT_COLORS.get(card_id, Color.WHITE)


func _fs(base: int) -> int:
	return maxi(8, int(round(float(base) * _scale)))


func _apply_hotkey_label() -> void:
	if _hotkey_label == null:
		return
	_hotkey_label.visible = not _for_export
	if not _for_export:
		_hotkey_label.text = "[%d]" % (hotkey_index + 1)
		_hotkey_label.add_theme_font_size_override("font_size", _fs(18))


func _apply_footer(data: Dictionary) -> void:
	if _footer_site_label:
		_footer_site_label.text = tr("PROFILE_SHARE_FOOTER_SITE")
		_footer_site_label.add_theme_font_size_override("font_size", _fs(16))
	if _footer_date_label:
		_footer_date_label.text = str(data.get("footer_date", ""))
		_footer_date_label.add_theme_font_size_override("font_size", _fs(16))
	if _logo_rect:
		_logo_rect.custom_minimum_size = Vector2(_fs(24), _fs(24))


func _apply_panel_style() -> void:
	var accent := _accent()
	var box := StyleBoxFlat.new()
	box.bg_color = _BG_COLOR
	box.set_corner_radius_all(_fs(20))
	box.border_color = _SEL_BORDER if _selected and not _for_export else accent.darkened(0.28)
	box.set_border_width_all(4 if _selected and not _for_export else 2)
	box.content_margin_left = _fs(16)
	box.content_margin_right = _fs(16)
	box.content_margin_top = _fs(14)
	box.content_margin_bottom = _fs(12)
	add_theme_stylebox_override("panel", box)


func _load_logo() -> void:
	if _logo_rect == null:
		return
	var path := "res://assets/app_icons/rf.png"
	if ResourceLoader.exists(path):
		_logo_rect.texture = load(path)
	_logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func _clear_content() -> void:
	if _content_vbox == null:
		return
	for child in _content_vbox.get_children():
		child.queue_free()


func _rebuild_content(data: Dictionary) -> void:
	_clear_content()
	_add_header()
	match card_id:
		"overview":
			_build_overview(data)
		"statistics":
			_build_statistics(data)
		"music":
			_build_music(data)
		"records":
			_build_records(data)


func _add_header() -> void:
	var brand := _make_label("RHYTHMFALL", _fs(14), _MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	brand.add_theme_constant_override("outline_size", 0)
	_content_vbox.add_child(brand)
	var title := _make_label(tr(_section_locale_key()), _fs(26), _accent(), HORIZONTAL_ALIGNMENT_LEFT)
	title.add_theme_font_size_override("font_size", _fs(26))
	_content_vbox.add_child(title)
	_content_vbox.add_child(_make_spacer(_fs(4)))


func _section_locale_key() -> String:
	match card_id:
		"overview":
			return "PROFILE_SHARE_CARD_OVERVIEW"
		"statistics":
			return "PROFILE_SHARE_CARD_STATISTICS"
		"music":
			return "PROFILE_SHARE_CARD_MUSIC"
		"records":
			return "PROFILE_SHARE_CARD_RECORDS"
	return ""


func _build_overview(data: Dictionary) -> void:
	_add_caption(tr("PROFILE_LEVEL_TITLE"))
	_add_value(tr("PROFILE_LEVEL") % int(data.get("level", 1)), _accent())
	_add_progress_bar(float(data.get("xp_ratio", 0.0)))
	_add_caption(str(data.get("xp_text", "")))
	_content_vbox.add_child(_make_spacer(_fs(6)))
	_add_value(tr("PROFILE_SHARE_RR_LINE") % int(data.get("rr_earned", 0)), Color(0.95, 0.72, 0.35))
	_add_stat_row([
		[tr("PROFILE_ACCURACY"), "%.2f%%" % float(data.get("accuracy", 0.0))],
		[tr("PROFILE_PLAY_TIME"), _format_play_time(str(data.get("play_time", "0:00")))],
	])
	_add_stat_row([
		[tr("PROFILE_LEVELS_COMPLETED"), str(int(data.get("unique_tracks", 0)))],
		[tr("PROFILE_SHARE_DAYS_IN_GAME"), str(int(data.get("days_in_game", 0)))],
	])
	_content_vbox.add_child(_make_spacer(_fs(8)))
	_add_caption(tr("PROFILE_FAVORITE_TRACK"))
	_add_favorite_block(data)
	_content_vbox.add_child(_make_spacer(_fs(6)))
	var group_id := str(data.get("favorite_group_id", ""))
	if group_id != "":
		_add_caption(tr("PROFILE_SHARE_FAVORITE_GENRE"))
		var group_label := _group_label(group_id)
		var pct := float(data.get("favorite_group_percent", 0.0))
		_add_value("%s (%.0f%%)" % [group_label, pct], _accent())


func _build_statistics(data: Dictionary) -> void:
	_add_caption(tr("PROFILE_GENERAL_STATS"))
	_add_stat_row([
		[tr("PROFILE_STAT_UNIQUE_TRACKS"), str(int(data.get("unique_tracks", 0)))],
		[tr("PROFILE_STAT_TOTAL_SCORE"), _fmt_int(int(data.get("total_score", 0)))],
	])
	_add_stat_row([
		[tr("PROFILE_STAT_NOTES_HIT"), _fmt_int(int(data.get("notes_hit", 0)))],
		[tr("PROFILE_STAT_NOTES_MISS"), _fmt_int(int(data.get("notes_miss", 0)))],
	])
	_add_stat_row([
		[tr("PROFILE_STAT_MAX_STREAK"), str(int(data.get("max_combo", 0)))],
		[tr("PROFILE_STAT_TOTAL_RR"), str(int(data.get("rr_earned", 0)))],
	])
	_add_stat_row([
		[tr("PROFILE_STAT_MEDALS_TOTAL"), str(int(data.get("medals_total", 0)))],
		[tr("PROFILE_STAT_DAILY_QUESTS"), str(int(data.get("daily_quests", 0)))],
	])
	_content_vbox.add_child(_make_spacer(_fs(8)))
	_add_caption(tr("PROFILE_GRADES"))
	_add_grades_row(data)
	_content_vbox.add_child(_make_spacer(_fs(8)))
	var avg := float(data.get("avg_difficulty", 0.0))
	if avg > 0.0:
		_add_caption(tr("PROFILE_AVG_DIFFICULTY"))
		_add_value(ChartDifficultyAnalyzer.format_average_rating(avg), ChartDifficultyAnalyzer.rating_color(clampi(int(round(avg)), 1, 10)))


func _build_music(data: Dictionary) -> void:
	_add_caption(tr("PROFILE_SHARE_TOP_GENRES"))
	var genres: Array = data.get("top_genres", [])
	if genres.is_empty():
		_add_muted(tr("PROFILE_GENRE_PORTRAIT_EMPTY"))
	else:
		for row in genres:
			if row is Dictionary:
				_add_genre_bar(str(row.get("group_id", "")), float(row.get("percent", 0.0)))
	_content_vbox.add_child(_make_spacer(_fs(8)))
	var unlocked := int(data.get("groups_unlocked", 0))
	var total := int(data.get("groups_total", 0))
	_add_value(tr("PROFILE_SHARE_MASTERY_SUMMARY") % [unlocked, total], _accent())
	_add_caption(tr("PROFILE_SHARE_COLLECTION_LEADERS"))
	var leaders: Array = data.get("mastery_leaders", [])
	if leaders.is_empty():
		_add_muted(tr("PROFILE_RECORDS_EMPTY"))
	else:
		for row in leaders:
			if row is Dictionary:
				var gid := str(row.get("group_id", ""))
				_add_line("%s · Lv.%d" % [_group_label(gid), int(row.get("level", 0))], _TEXT)


func _build_records(data: Dictionary) -> void:
	_add_caption(tr("PROFILE_RECORDS_EXTREMES"))
	var extremes: Dictionary = data.get("extremes", {}) if data.get("extremes") is Dictionary else {}
	_add_extreme_line(extremes, "highest_accuracy", tr("PROFILE_RECORD_EXTREME_ACCURACY"), "percent")
	_add_extreme_line(extremes, "hardest_chart_cleared", tr("PROFILE_RECORD_EXTREME_CHART"), "rating")
	_add_extreme_line(extremes, "longest_fc", tr("PROFILE_RECORD_EXTREME_FC"), "int")
	_add_extreme_line(extremes, "highest_bpm_cleared", tr("PROFILE_RECORD_EXTREME_BPM"), "bpm")
	_add_extreme_line(extremes, "longest_track_duration_sec", tr("PROFILE_RECORD_EXTREME_DURATION"), "duration")
	_content_vbox.add_child(_make_spacer(_fs(8)))
	_add_caption(tr("PROFILE_RECORDS_STREAKS"))
	var streaks: Dictionary = data.get("streaks", {}) if data.get("streaks") is Dictionary else {}
	_add_line(tr("PROFILE_SHARE_STREAK_CLEAR") % int(streaks.get("best_clear_streak_days", 0)), _TEXT)
	_add_line(tr("PROFILE_LOGIN_STREAK_CAPTION") % int(data.get("login_streak_best", 0)), _TEXT)
	_content_vbox.add_child(_make_spacer(_fs(8)))
	_add_caption(tr("PROFILE_RECORDS_MILESTONES"))
	var milestones: Dictionary = data.get("milestones", {}) if data.get("milestones") is Dictionary else {}
	var shown := 0
	for key in ["first_ss", "first_fc", "unique_100_tracks"]:
		if milestones.has(key):
			_add_line(tr("PROFILE_RECORD_MILESTONE_%s" % key.to_upper()), _accent())
			shown += 1
	if shown == 0:
		_add_muted(tr("PROFILE_NO_RECENT_ACHIEVEMENTS"))


func _add_favorite_block(data: Dictionary) -> void:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.11, 0.15, 0.95)
	box.set_corner_radius_all(_fs(12))
	box.set_border_width_all(1)
	box.border_color = _accent().darkened(0.35)
	box.content_margin_left = _fs(10)
	box.content_margin_right = _fs(10)
	box.content_margin_top = _fs(10)
	box.content_margin_bottom = _fs(10)
	panel.add_theme_stylebox_override("panel", box)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", _fs(4))
	panel.add_child(vbox)
	var cover := TextureRect.new()
	cover.custom_minimum_size = Vector2(0, _fs(120))
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var cover_tex: Texture2D = data.get("cover") as Texture2D
	if cover_tex:
		cover.texture = cover_tex
	vbox.add_child(cover)
	vbox.add_child(_make_label(str(data.get("title", "")), _fs(20), _TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	vbox.add_child(_make_label(str(data.get("artist", "")), _fs(16), _MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	var genre := str(data.get("genre", ""))
	var plays := int(data.get("play_count", 0))
	vbox.add_child(_make_label(tr("PROFILE_SHARE_OVERVIEW_META") % [genre, plays], _fs(14), _MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	var best := str(data.get("best_grade", ""))
	if best != "":
		vbox.add_child(_make_label(tr("PROFILE_SHARE_BEST_GRADE") % best, _fs(14), GradeDisplay.grade_color(best), HORIZONTAL_ALIGNMENT_LEFT))
	_content_vbox.add_child(panel)


func _add_grades_row(data: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", _fs(6))
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for grade in ["SS", "S", "A", "B"]:
		var chip := VBoxContainer.new()
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.alignment = BoxContainer.ALIGNMENT_CENTER
		var color := GradeDisplay.grade_color(grade)
		chip.add_child(_make_label(grade, _fs(14), color, HORIZONTAL_ALIGNMENT_CENTER))
		chip.add_child(_make_label(str(int(data.get(grade.to_lower(), 0))), _fs(22), color, HORIZONTAL_ALIGNMENT_CENTER))
		row.add_child(chip)
	_content_vbox.add_child(row)


func _add_genre_bar(group_id: String, percent: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", _fs(6))
	var name_lbl := _make_label(_group_label(group_id), _fs(14), _TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	name_lbl.custom_minimum_size.x = _fs(90)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)
	var bar_bg := PanelContainer.new()
	bar_bg.custom_minimum_size = Vector2(_fs(80), _fs(10))
	bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(1, 1, 1, 0.08)
	bg_style.set_corner_radius_all(_fs(4))
	bar_bg.add_theme_stylebox_override("panel", bg_style)
	var fill := ColorRect.new()
	fill.color = _accent()
	fill.anchor_right = clampf(percent / 100.0, 0.02, 1.0)
	fill.offset_right = 0
	bar_bg.add_child(fill)
	row.add_child(bar_bg)
	row.add_child(_make_label("%.0f%%" % percent, _fs(14), _MUTED, HORIZONTAL_ALIGNMENT_RIGHT))
	_content_vbox.add_child(row)


func _add_extreme_line(extremes: Dictionary, key: String, caption: String, kind: String) -> void:
	if not extremes.has(key) or not extremes[key] is Dictionary:
		return
	var entry: Dictionary = extremes[key]
	var value := _format_extreme(entry, kind)
	if value == "":
		return
	_add_line("%s: %s" % [caption, value], _TEXT)


func _format_extreme(entry: Dictionary, kind: String) -> String:
	match kind:
		"percent":
			return "%.2f%%" % float(entry.get("value", 0.0))
		"rating":
			return ChartDifficultyAnalyzer.format_average_rating(float(entry.get("value", 0.0)))
		"int":
			return str(int(entry.get("value", 0)))
		"bpm":
			return "%d BPM" % int(entry.get("value", 0))
		"duration":
			var sec := int(entry.get("value", 0))
			return "%02d:%02d" % [sec / 60, sec % 60]
	return ""


func _group_label(group_id: String) -> String:
	if group_id == "" or group_id == "_other":
		return tr("PROFILE_GENRE_GRP_OTHER")
	var key := _GenrePortrait.group_locale_key(group_id)
	var label := tr(key)
	if label == key:
		return group_id.replace("_", " ")
	return label


func _format_play_time(time_str: String) -> String:
	var parts := time_str.split(":")
	var hours := 0
	var minutes := 0
	if parts.size() >= 2:
		hours = int(parts[0])
		minutes = int(parts[1])
	return tr("PROFILE_PLAY_TIME_FMT") % [hours, minutes]


func _fmt_int(value: int) -> String:
	if value >= 1_000_000:
		return "%.1fM" % (float(value) / 1_000_000.0)
	if value >= 10_000:
		return "%.1fk" % (float(value) / 1_000.0)
	return str(value)


func _make_label(text: String, size: int, color: Color, align: HorizontalAlignment) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = align
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func _make_spacer(h: int) -> Control:
	var sp := Control.new()
	sp.custom_minimum_size.y = h
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sp


func _add_caption(text: String) -> void:
	_content_vbox.add_child(_make_label(text, _fs(14), _MUTED, HORIZONTAL_ALIGNMENT_LEFT))


func _add_value(text: String, color: Color) -> void:
	_content_vbox.add_child(_make_label(text, _fs(24), color, HORIZONTAL_ALIGNMENT_LEFT))


func _add_line(text: String, color: Color) -> void:
	_content_vbox.add_child(_make_label(text, _fs(15), color, HORIZONTAL_ALIGNMENT_LEFT))


func _add_muted(text: String) -> void:
	_content_vbox.add_child(_make_label(text, _fs(14), _MUTED, HORIZONTAL_ALIGNMENT_LEFT))


func _add_stat_row(pairs: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", _fs(8))
	for pair in pairs:
		if pair is Array and pair.size() >= 2:
			var col := VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_child(_make_label(str(pair[0]), _fs(12), _MUTED, HORIZONTAL_ALIGNMENT_LEFT))
			col.add_child(_make_label(str(pair[1]), _fs(16), _TEXT, HORIZONTAL_ALIGNMENT_LEFT))
			row.add_child(col)
	_content_vbox.add_child(row)


func _add_progress_bar(ratio: float) -> void:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = _fs(12)
	bar.show_percentage = false
	bar.value = clampf(ratio, 0.0, 1.0) * 100.0
	bar.max_value = 100.0
	_content_vbox.add_child(bar)


func _apply_content_locale() -> void:
	pass


func _on_click_button_pressed() -> void:
	if card_id == "":
		return
	card_pressed.emit(card_id)
