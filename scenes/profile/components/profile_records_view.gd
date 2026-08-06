# scenes/profile/components/profile_records_view.gd
class_name ProfileRecordsView
extends RefCounted

const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const _ProfileGenrePortrait = preload("res://logic/domain/profile/profile_genre_portrait.gd")
const _RhythmRating = preload("res://logic/domain/rhythm/rhythm_rating.gd")
const _ProfilePlayModesStats = preload("res://logic/domain/profile/profile_play_modes_stats.gd")
const _GenreGroupIcons = preload("res://logic/domain/library/genre_group_icons.gd")
const _MarathonRouteCatalog = preload("res://logic/domain/session/marathon_route_catalog.gd")
const _MarathonRouteBadges = preload("res://logic/domain/session/marathon_route_badges.gd")
const _ModifierIconStrip = preload("res://logic/ui/modifier_icon_strip.gd")
const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")
const _SS = preload("res://logic/domain/library/song_select_strings.gd")

const RECORD_SECTION_SCENE := preload("res://scenes/profile/components/profile_record_section.tscn")
const RECORD_HIGHLIGHT_SCENE := preload("res://scenes/profile/components/profile_record_highlight_entry.tscn")
const RECORD_DETAIL_ROW_SCENE := preload("res://scenes/profile/components/profile_record_detail_row.tscn")
const RECORD_RR_ROW_SCENE := preload("res://scenes/profile/components/profile_record_rr_row.tscn")
const STAT_TILE_SCENE := preload("res://scenes/profile/components/profile_stat_tile.tscn")
const _SongSelectUiStyles = preload("res://scenes/song_select/lib/song_select_ui_styles.gd")
const _ActivityCalendar = preload("res://logic/domain/profile/activity_calendar.gd")
const _UiModifierSounds = preload("res://logic/ui/ui_modifier_sounds.gd")
const _ChartDifficultyAnalyzer = preload("res://logic/domain/charts/chart_difficulty_analyzer.gd")

const COLOR_CAPTION := Color(0.654902, 0.654902, 0.678431, 1)
const COLOR_VALUE := Color(0.784314, 0.823529, 0.901961, 1)
const COLOR_SCORE := Color(0.55, 0.78, 0.98, 1.0)
const COLOR_RR := Color(0.9490196, 0.7019608, 0.3529412, 1)
const COLOR_MUTED := Color(0.55, 0.58, 0.65, 0.92)
const COLOR_ACCENT_GREEN := Color(0.38039216, 0.78039217, 0.7411765, 1)
const COLOR_MOD_STACK := Color(0.72, 0.58, 0.95, 1.0)

const RECORD_ICON_TINTS: Dictionary = {
	"circle-play.svg": Color(0.55, 0.78, 0.98, 1.0),
	"trophy.svg": Color(0.96, 0.78, 0.34, 1.0),
	"star.svg": Color(0.92, 0.78, 0.42, 1.0),
	"eye-off.svg": Color(0.72, 0.58, 0.95, 1.0),
	"clock.svg": Color(0.55, 0.82, 0.95, 1.0),
	"hash.svg": Color(0.42, 0.88, 0.82, 1.0),
	"target.svg": Color(0.95, 0.55, 0.42, 1.0),
	"zap.svg": Color(0.96, 0.78, 0.34, 1.0),
	"chart-column.svg": Color(0.72, 0.58, 0.95, 1.0),
	"flame.svg": Color(0.95, 0.55, 0.42, 1.0),
	"fingerprint-pattern.svg": Color(0.75, 0.52, 0.98, 1.0),
	"repeat.svg": Color(0.72, 0.58, 0.95, 1.0),
	"layers.svg": Color(0.55, 0.72, 0.98, 1.0),
	"tags.svg": Color(0.62, 0.86, 0.72, 1.0),
}

# Shelf order = prestige ladder (easy → hard), same as Recap pick order.
const MILESTONE_SPECS: Array = [
	["first_track_played", "PROFILE_RECORD_MILESTONE_FIRST_TRACK", "", "circle-play.svg"],
	["first_ss", "PROFILE_RECORD_MILESTONE_FIRST_SS", "", "trophy.svg"],
	["first_fc", "PROFILE_RECORD_MILESTONE_FIRST_FC", "", "clock.svg"],
	["first_mod_clear", "PROFILE_RECORD_MILESTONE_FIRST_MOD", "", "eye-off.svg"],
	["endless_unlocked", "PROFILE_RECORD_MILESTONE_ENDLESS", "", "repeat.svg"],
	["marathon_unlocked", "PROFILE_RECORD_MILESTONE_MARATHON", "", "layers.svg"],
	["unique_100_tracks", "PROFILE_RECORD_MILESTONE_UNIQUE_100", "100", "hash.svg"],
	["clears_250", "PROFILE_RECORD_MILESTONE_CLEARS_250", "250", "target.svg"],
	["total_rr_10000", "PROFILE_RECORD_MILESTONE_RR_10K", "10K", "fingerprint-pattern.svg"],
	["genre_group_level_10", "PROFILE_RECORD_MILESTONE_GENRE_L10", "10", "tags.svg"],
]

const EXTREME_SPECS: Array = [
	["highest_accuracy", "PROFILE_RECORD_EXTREME_ACCURACY", "percent", "target.svg"],
	["hardest_chart_cleared", "PROFILE_RECORD_EXTREME_CHART", "rating", "zap.svg"],
	["longest_fc", "PROFILE_RECORD_EXTREME_FC", "int", "clock.svg"],
	["longest_track_duration_sec", "PROFILE_RECORD_EXTREME_DURATION", "duration", "clock.svg"],
	["highest_bpm_cleared", "PROFILE_RECORD_EXTREME_BPM", "bpm", "flame.svg"],
]


static func _tr(key: String) -> String:
	return TranslationServer.translate(key)


static func is_built(content_vbox: VBoxContainer) -> bool:
	return content_vbox != null and content_vbox.get_child_count() > 0


static var _rebuild_busy := false


static func _clear_content(content_vbox: VBoxContainer) -> void:
	if content_vbox == null:
		return
	for child in content_vbox.get_children():
		content_vbox.remove_child(child)
		child.queue_free()


## group: "timeline" | "records" | "all"
## clear_first: when false, append into an empty staging container (caller shows spinner).
static func rebuild_async(
	content_vbox: VBoxContainer,
	card_style: StyleBox,
	group: String = "all",
	clear_first: bool = true
) -> void:
	if content_vbox == null:
		return
	var tree := content_vbox.get_tree()
	while _rebuild_busy:
		if tree == null:
			return
		await tree.process_frame
	_rebuild_busy = true
	if clear_first:
		_clear_content(content_vbox)
	if not ProfileMilestonesManager:
		_rebuild_busy = false
		return
	if tree:
		await tree.process_frame
	var data := ProfileMilestonesManager.get_data()
	content_vbox.add_theme_constant_override("separation", 10)
	var g := str(group).strip_edges().to_lower()
	if g == "":
		g = "all"
	var want_timeline := g == "all" or g == "timeline"
	var want_records := g == "all" or g == "records"

	if want_records:
		_add_rr_top10_section(content_vbox, data.get("rhythm_rating_top10", []), card_style)
		if tree:
			await tree.process_frame
	if want_timeline:
		_add_milestones_section(content_vbox, data.get("milestones", {}), card_style)
		if tree:
			await tree.process_frame
	if want_records:
		_add_extremes_section(content_vbox, data.get("extremes", {}), card_style)
		if tree:
			await tree.process_frame
		_add_mod_records_section(content_vbox, data.get("mod_records", {}), card_style)
		if tree:
			await tree.process_frame
		_add_mod_clears_section(content_vbox, card_style)
		if tree:
			await tree.process_frame
		_add_marathon_section(content_vbox, card_style)
		if tree:
			await tree.process_frame
		_add_endless_section(content_vbox, card_style)
		if tree:
			await tree.process_frame
		_add_streaks_section(content_vbox, data.get("streaks", {}), card_style)
		if tree:
			await tree.process_frame
		_add_genre_section(content_vbox, data.get("genre_highlights", {}), card_style)
	_rebuild_busy = false


## Map a records section_id to History dialog group (timeline vs records).
static func group_for_section_id(section_id: String) -> String:
	var sid := str(section_id).strip_edges().to_lower()
	if sid == "" or sid == "milestones":
		return "timeline"
	return "records"


## Shelf entries for History Timeline. Includes locked (not yet achieved) milestones.
static func list_milestone_entries(milestones_raw = null) -> Array:
	var milestones: Dictionary = {}
	if milestones_raw is Dictionary:
		milestones = milestones_raw
	elif ProfileMilestonesManager:
		var data := ProfileMilestonesManager.get_data()
		var raw = data.get("milestones", {})
		if raw is Dictionary:
			milestones = raw
	var out: Array = []
	for spec in MILESTONE_SPECS:
		var key := String(spec[0])
		var entry: Dictionary = {}
		var raw_entry: Variant = milestones.get(key, {})
		if raw_entry is Dictionary:
			entry = raw_entry
		var achieved := raw_entry is Dictionary and not (raw_entry as Dictionary).is_empty()
		out.append({
			"id": key,
			"title_key": String(spec[1]),
			"icon": _spec_icon_file(spec),
			"tint": _icon_tint_for_file(_spec_icon_file(spec)),
			"achieved": achieved,
			"date": _format_date(str(entry.get("date", ""))) if achieved else "",
			"value_text": _spec_value_text(spec),
		})
	return out


static func _add_section_card(
	parent: VBoxContainer,
	title: String,
	style: StyleBox,
	section_id: String = "",
	icon_file: String = "",
	icon_tint: Color = Color(0.419608, 0.568627, 0.823529, 1)
) -> VBoxContainer:
	var section := RECORD_SECTION_SCENE.instantiate()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.set_section_title(title, icon_file, icon_tint)
	section.set_panel_style(style)
	if section.has_method("set_section_id") and str(section_id).strip_edges() != "":
		section.set_section_id(str(section_id).strip_edges())
	parent.add_child(section)
	var card := section.get_node_or_null("CardPanel") as PanelContainer
	if card:
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body: VBoxContainer = section.get_body() as VBoxContainer
	if body:
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return body


static func _add_subheading(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", COLOR_CAPTION)
	label.add_theme_font_size_override("font_size", 13)
	parent.add_child(label)


static func _add_empty(parent: VBoxContainer) -> void:
	var label := Label.new()
	label.text = _tr("PROFILE_RECORDS_EMPTY")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", COLOR_MUTED)
	label.add_theme_font_size_override("font_size", 13)
	parent.add_child(label)


static func _icon_tint_for_file(icon_file: String, fallback: Color = COLOR_CAPTION) -> Color:
	return RECORD_ICON_TINTS.get(icon_file, fallback) as Color


static func _make_mod_clear_row(mod_id: String, count: int) -> PanelContainer:
	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.1, 0.14, 0.92)
	box.border_color = Color(1, 1, 1, 0.06)
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	row.add_theme_stylebox_override("panel", box)
	row.tooltip_text = _RunModifiers.format_tooltip(mod_id)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row.add_child(hbox)

	var tint := _RunModifiers.category_tint(mod_id, true)
	var icon_file := _RunModifiers.icon_file(mod_id)
	if icon_file.strip_edges() != "":
		hbox.add_child(_UiIconHelper.make_icon_frame(icon_file, 32, 18, tint))

	var title := Label.new()
	title.text = _tr(_RunModifiers.title_i18n_key(mod_id))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.82, 0.88, 0.96, 0.96))
	hbox.add_child(title)

	var count_label := Label.new()
	count_label.text = str(count)
	count_label.add_theme_font_size_override("font_size", 20)
	count_label.add_theme_color_override("font_color", COLOR_ACCENT_GREEN)
	hbox.add_child(count_label)
	return row


static func _make_mod_icon_tile(mod_id: String, count: int) -> PanelContainer:
	return _make_mod_clear_row(mod_id, count)


static func _make_stat_tile(caption: String, value: String, value_color: Color) -> PanelContainer:
	var tile := STAT_TILE_SCENE.instantiate() as PanelContainer
	tile.apply_stat(caption, value, value_color, 22)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return tile


static func _add_detail_row(parent: VBoxContainer, caption: String, value: String, value_color: Color = COLOR_VALUE) -> void:
	var row := RECORD_DETAIL_ROW_SCENE.instantiate()
	parent.add_child(row)
	row.apply_row(caption, value, value_color)


static func _spec_icon_file(spec: Array, default: String = "") -> String:
	if spec.size() > 3:
		return str(spec[3])
	return default


static func _spec_value_text(spec: Array) -> String:
	if spec.size() > 2:
		return str(spec[2])
	return ""


static func _add_highlight_entry(
	parent: Node,
	caption: String,
	primary: String,
	secondary: String = "",
	value_text: String = "",
	value_color: Color = COLOR_RR,
	modifiers: Array = [],
	caption_icon_file: String = "",
	caption_icon_tint: Color = COLOR_CAPTION,
	expand_fill: bool = false,
	value_as_zap_rating: bool = false
) -> Node:
	var entry := RECORD_HIGHLIGHT_SCENE.instantiate()
	if expand_fill:
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(entry)
	entry.apply_entry(
		caption,
		primary,
		secondary,
		value_text,
		value_color,
		modifiers,
		caption_icon_file,
		caption_icon_tint,
		value_as_zap_rating
	)
	return entry


static func _make_extreme_cell() -> PanelContainer:
	var holder := PanelContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.09, 0.13, 0.98)
	box.border_color = Color(1, 1, 1, 0.07)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	holder.add_theme_stylebox_override("panel", box)
	return holder


static func _add_extremes_section(parent: VBoxContainer, extremes: Variant, style: StyleBox) -> void:
	var body := _add_section_card(parent, _tr("PROFILE_RECORDS_EXTREMES"), style)
	var has_any := false
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	body.add_child(grid)
	if extremes is Dictionary:
		for spec in EXTREME_SPECS:
			var key := String(spec[0])
			var entry: Variant = extremes.get(key)
			if not entry is Dictionary:
				continue
			has_any = true
			var value_text := _format_extreme_value(entry, String(spec[2]))
			var track := _track_line(entry)
			var secondary_parts: PackedStringArray = []
			var settings := _play_settings_text(entry)
			if settings != "":
				secondary_parts.append(settings)
			var date_text := _format_date(str(entry.get("date", "")))
			if date_text != "":
				secondary_parts.append(date_text)
			var holder := _make_extreme_cell()
			grid.add_child(holder)
			var is_rating := String(spec[2]) == "rating"
			var rating_val := float(entry.get("value", 0.0)) if is_rating else 0.0
			if is_rating and rating_val <= 0.0:
				var song_path := str(entry.get("song_path", ""))
				if song_path != "":
					rating_val = float(_RhythmRating.resolve_chart_rating(song_path, "drums", "basic", 4))
			var value_color := (
				_ChartDifficultyAnalyzer.rating_color_for_decimal(rating_val)
				if is_rating and rating_val > 0.0
				else COLOR_ACCENT_GREEN
			)
			_add_highlight_entry(
				holder,
				_tr(String(spec[1])),
				track,
				" · ".join(secondary_parts),
				value_text,
				value_color,
				_entry_modifiers(entry),
				_spec_icon_file(spec),
				_icon_tint_for_file(_spec_icon_file(spec), value_color if is_rating else COLOR_ACCENT_GREEN),
				true,
				is_rating
			)
		var last_rec: Variant = extremes.get("last_personal_record")
		if last_rec is Dictionary and int(last_rec.get("best_rr", 0)) > 0:
			has_any = true
			var holder_last := _make_extreme_cell()
			grid.add_child(holder_last)
			var last_secondary: PackedStringArray = []
			var last_settings := _play_settings_text(last_rec)
			if last_settings != "":
				last_secondary.append(last_settings)
			var last_date := _format_date(str(last_rec.get("date", "")))
			if last_date != "":
				last_secondary.append(last_date)
			_add_highlight_entry(
				holder_last,
				_tr("PROFILE_RECORD_EXTREME_LAST_RECORD"),
				_track_line(last_rec),
				" · ".join(last_secondary),
				"%d RR" % int(last_rec.get("best_rr", 0)),
				COLOR_RR,
				_entry_modifiers(last_rec),
				"fingerprint-pattern.svg",
				_icon_tint_for_file("fingerprint-pattern.svg", COLOR_RR),
				true
			)
	if not has_any:
		grid.queue_free()
		_add_empty(body)


static func _track_line(entry: Dictionary) -> String:
	var title := str(entry.get("title", "")).strip_edges()
	var artist := str(entry.get("artist", "")).strip_edges()
	if title == "" and artist == "":
		return _tr("VALUE_NA")
	if artist == "":
		return title
	if title == "":
		return artist
	return "%s — %s" % [artist, title]


static func _format_date(date_str: String) -> String:
	if date_str == "":
		return ""
	return TimeUtils.format_iso_to_ddmmyyyy_hhmmss(date_str)


static func _mods_text(modifiers: Variant) -> String:
	if not modifiers is Array:
		return ""
	return _RunModifiers.format_abbr_list(modifiers, func(key: String) -> String: return _tr(key))


static func _instrument_label(instrument_raw: String) -> String:
	var key := instrument_raw.strip_edges().to_lower()
	match key:
		"drums", "перкуссия":
			return _tr("GEN_INST_DRUMS")
		"bass", "бас":
			return _tr("GEN_INST_BASS")
		"fullmix", "микс":
			return _tr("GEN_INST_MIX")
		"standard", "стандарт", "":
			return _tr("GEN_INST_STANDARD")
		_:
			return instrument_raw if instrument_raw != "" else ""


static func _mode_label(mode_raw: String) -> String:
	return _SS.format_chart_mode_label(mode_raw)


static func _play_settings_text(entry: Dictionary) -> String:
	var instrument_label := _instrument_label(str(entry.get("instrument", "")))
	var mode_label := _mode_label(str(entry.get("mode", "")))
	var lanes := int(entry.get("lanes", 0))
	var parts: PackedStringArray = []
	if instrument_label != "":
		parts.append(instrument_label)
	if mode_label != "":
		parts.append(mode_label)
	if lanes >= 3 and lanes <= 5:
		parts.append(_tr("PROFILE_RECORDS_LANES_FMT") % lanes)
	return ", ".join(parts)


static func _entry_modifiers(entry: Dictionary) -> Array:
	var raw: Variant = entry.get("modifiers", [])
	return raw if raw is Array else []


static func _entry_meta_line(entry: Dictionary, include_mods: bool = false) -> String:
	var meta_parts: PackedStringArray = []
	var settings := _play_settings_text(entry)
	if settings != "":
		meta_parts.append(settings)
	if include_mods:
		var mods := _mods_text(entry.get("modifiers", []))
		if mods != "":
			meta_parts.append(mods)
	var date_text := _format_date(str(entry.get("date", "")))
	if date_text != "":
		meta_parts.append(date_text)
	return " · ".join(meta_parts)


static func _add_rr_top10_section(parent: VBoxContainer, top10: Variant, style: StyleBox) -> void:
	var body := _add_section_card(parent, _tr("PROFILE_RECORDS_RR_TOP10"), style)
	if not top10 is Array or top10.is_empty():
		_add_empty(body)
		return
	var entries: Array = []
	for entry in top10:
		if entry is Dictionary:
			entries.append(entry)
	if entries.is_empty():
		_add_empty(body)
		return

	var row1 := HBoxContainer.new()
	row1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_theme_constant_override("separation", 8)
	body.add_child(row1)
	var preview_n := mini(5, entries.size())
	for i in range(preview_n):
		row1.add_child(_make_rr_cover_card(i + 1, entries[i] as Dictionary))

	var more_wrap := HBoxContainer.new()
	more_wrap.visible = false
	more_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	more_wrap.add_theme_constant_override("separation", 8)
	body.add_child(more_wrap)
	if entries.size() > 5:
		var rest_n := mini(10, entries.size())
		for i in range(5, rest_n):
			more_wrap.add_child(_make_rr_cover_card(i + 1, entries[i] as Dictionary))
		var toggle := Button.new()
		toggle.text = _tr("PROFILE_HISTORY_SHOW_MORE")
		toggle.focus_mode = Control.FOCUS_NONE
		toggle.theme_type_variation = &"FlatBackButton"
		toggle.custom_minimum_size = Vector2(0, 34)
		toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toggle.pressed.connect(func() -> void:
			more_wrap.visible = not more_wrap.visible
			if more_wrap.visible:
				_UiModifierSounds.play_select()
			else:
				_UiModifierSounds.play_deselect()
			toggle.text = _tr("PROFILE_HISTORY_SHOW_LESS" if more_wrap.visible else "PROFILE_HISTORY_SHOW_MORE")
		)
		body.add_child(toggle)


static func _rr_rank_accent(rank: int) -> Color:
	match rank:
		1:
			return Color(0.96, 0.78, 0.34, 1.0) # gold
		2:
			return Color(0.78, 0.82, 0.88, 1.0) # silver
		3:
			return Color(0.86, 0.55, 0.32, 1.0) # bronze
		_:
			return COLOR_CAPTION


static func _make_rr_cover_card(rank: int, entry: Dictionary, _compact: bool = false) -> PanelContainer:
	var accent := _rr_rank_accent(rank)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 0)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.09, 0.13, 0.98)
	box.border_color = Color(accent.r, accent.g, accent.b, 0.65 if rank <= 3 else 0.12)
	box.set_border_width_all(2 if rank <= 3 else 1)
	box.set_corner_radius_all(10)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	card.add_theme_stylebox_override("panel", box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)

	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 4)
	col.add_child(head)
	if rank <= 3:
		head.add_child(_UiIconHelper.make_icon_frame("crown.svg", 22, 12, accent))
	var rank_lbl := Label.new()
	rank_lbl.text = "#%d" % rank
	rank_lbl.add_theme_font_size_override("font_size", 12)
	rank_lbl.add_theme_color_override("font_color", accent)
	head.add_child(rank_lbl)

	var cover_bits: Dictionary = _SongSelectUiStyles.make_row_cover_thumbnail(72)
	var frame: Control = cover_bits.get("frame") as Control
	var cover: TextureRect = cover_bits.get("cover") as TextureRect
	if frame:
		var center := CenterContainer.new()
		center.add_child(frame)
		col.add_child(center)
	if cover:
		_SongSelectUiStyles.apply_row_cover_texture(cover, str(entry.get("song_path", "")), 72)

	var rr_lbl := Label.new()
	rr_lbl.text = "%d RR" % int(entry.get("best_rr", 0))
	rr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rr_lbl.add_theme_font_size_override("font_size", 14)
	rr_lbl.add_theme_color_override("font_color", COLOR_RR)
	col.add_child(rr_lbl)

	var track := Label.new()
	track.text = _track_line(entry)
	track.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	track.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	track.add_theme_font_size_override("font_size", 10)
	track.add_theme_color_override("font_color", COLOR_VALUE)
	col.add_child(track)

	var settings := _play_settings_text(entry)
	if settings != "":
		var meta := Label.new()
		meta.text = settings
		meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		meta.add_theme_font_size_override("font_size", 9)
		meta.add_theme_color_override("font_color", COLOR_MUTED)
		col.add_child(meta)

	var mods := _entry_modifiers(entry)
	if not mods.is_empty():
		var mods_row := HBoxContainer.new()
		mods_row.alignment = BoxContainer.ALIGNMENT_CENTER
		mods_row.add_theme_constant_override("separation", 2)
		col.add_child(mods_row)
		_ModifierIconStrip.fill_slot_chips(mods_row, mods, {}, maxi(mods.size(), 1), true, 14, 8, 3, false)

	var date := Label.new()
	date.text = _format_date(str(entry.get("date", "")))
	date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	date.add_theme_font_size_override("font_size", 9)
	date.add_theme_color_override("font_color", COLOR_MUTED)
	col.add_child(date)
	return card


static func _add_milestones_section(parent: VBoxContainer, milestones: Variant, style: StyleBox) -> void:
	var body := _add_section_card(parent, _tr("PROFILE_RECORDS_MILESTONES"), style, "milestones")
	var has_firsts := false
	if milestones is Dictionary:
		for spec in MILESTONE_SPECS:
			var key := String(spec[0])
			var entry: Variant = milestones.get(key)
			if not entry is Dictionary:
				continue
			has_firsts = true
			var date_text := _format_date(str(entry.get("date", "")))
			var track := _track_line(entry)
			var value_text := _spec_value_text(spec)
			var secondary_parts: PackedStringArray = []
			var settings := _play_settings_text(entry)
			if settings != "":
				secondary_parts.append(settings)
			if date_text != "":
				secondary_parts.append(date_text)
			_add_highlight_entry(
				body,
				_tr(String(spec[1])),
				track if track != _tr("VALUE_NA") else "",
				" · ".join(secondary_parts),
				value_text,
				COLOR_RR,
				[],
				_spec_icon_file(spec),
				_icon_tint_for_file(_spec_icon_file(spec))
			)
	if not has_firsts:
		_add_empty(body)


static func _format_extreme_value(entry: Dictionary, kind: String) -> String:
	var value := float(entry.get("value", 0.0))
	if kind == "rating" and value <= 0.0:
		var song_path := str(entry.get("song_path", ""))
		if song_path != "":
			value = float(_RhythmRating.resolve_chart_rating(song_path, "drums", "basic", 4))
	match kind:
		"percent":
			return "%.1f%%" % value
		"rating":
			if value <= 0.0:
				return _tr("VALUE_NA")
			# Same as song select: zap + decimal rating (may exceed 10 with mods).
			return _ChartDifficultyAnalyzer.format_decimal_rating(value, false)
		"duration":
			var total := int(value)
			var minutes := total / 60
			var seconds := total % 60
			return "%d:%02d" % [minutes, seconds]
		"bpm":
			return "%.0f BPM" % value
		_:
			return str(int(value))


static func _add_mod_records_section(parent: VBoxContainer, mod_records: Variant, style: StyleBox) -> void:
	var body := _add_section_card(parent, _tr("PROFILE_RECORDS_MODS"), style)
	var cards: Array = []
	if mod_records is Dictionary:
		var score_rec: Variant = mod_records.get("best_score_with_mods")
		if score_rec is Dictionary and int(score_rec.get("score", 0)) > 0:
			cards.append({
				"caption": _tr("PROFILE_RECORD_MOD_BEST_SCORE"),
				"value": _ActivityCalendar.format_score(int(score_rec.get("score", 0))),
				"entry": score_rec,
				"accent": COLOR_SCORE,
			})
		var rr_rec: Variant = mod_records.get("best_rr_with_mods")
		if rr_rec is Dictionary and int(rr_rec.get("best_rr", 0)) > 0:
			cards.append({
				"caption": _tr("PROFILE_RECORD_MOD_BEST_RR"),
				"value": "%d RR" % int(rr_rec.get("best_rr", 0)),
				"entry": rr_rec,
				"accent": COLOR_RR,
			})
		var hard_rec: Variant = mod_records.get("hardest_mod_combo")
		if hard_rec is Dictionary and float(hard_rec.get("hardness", 0.0)) > 0.0:
			var bonus_pct := int(round(float(hard_rec.get("hardness", 0.0)) * 100.0))
			cards.append({
				"caption": _tr("PROFILE_RECORD_MOD_HARDEST"),
				"value": _tr("PROFILE_RECORD_MOD_HARD_BONUS") % bonus_pct,
				"entry": hard_rec,
				"accent": COLOR_MOD_STACK,
			})
		var max_rec: Variant = mod_records.get("max_mod_count")
		if max_rec is Dictionary and int(max_rec.get("count", 0)) > 0:
			cards.append({
				"caption": _tr("PROFILE_RECORD_MOD_MAX_COUNT"),
				"value": _tr("PROFILE_RECORDS_MOD_COUNT_SHORT") % int(max_rec.get("count", 0)),
				"entry": max_rec,
				"accent": COLOR_VALUE,
			})
		var acc_rec: Variant = mod_records.get("best_accuracy_with_mods")
		if acc_rec is Dictionary and float(acc_rec.get("accuracy", 0.0)) > 0.0:
			cards.append({
				"caption": _tr("PROFILE_RECORD_MOD_BEST_ACCURACY"),
				"value": "%.1f%%" % float(acc_rec.get("accuracy", 0.0)),
				"entry": acc_rec,
				"accent": COLOR_ACCENT_GREEN,
			})
	if cards.is_empty():
		_add_empty(body)
		return

	var row1 := HBoxContainer.new()
	row1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_theme_constant_override("separation", 8)
	body.add_child(row1)
	var preview_n := mini(5, cards.size())
	for i in range(preview_n):
		row1.add_child(_make_mod_record_card(cards[i] as Dictionary))


static func _make_mod_record_card(spec: Dictionary) -> PanelContainer:
	var entry: Dictionary = spec.get("entry", {}) if spec.get("entry", {}) is Dictionary else {}
	var accent: Color = spec.get("accent", COLOR_VALUE)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 0)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.09, 0.13, 0.98)
	box.border_color = Color(accent.r, accent.g, accent.b, 0.35)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	card.add_theme_stylebox_override("panel", box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)

	var cap := Label.new()
	cap.text = str(spec.get("caption", ""))
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.add_theme_font_size_override("font_size", 11)
	cap.add_theme_color_override("font_color", COLOR_CAPTION)
	col.add_child(cap)

	var cover_bits: Dictionary = _SongSelectUiStyles.make_row_cover_thumbnail(64)
	var frame: Control = cover_bits.get("frame") as Control
	var cover: TextureRect = cover_bits.get("cover") as TextureRect
	if frame:
		var center := CenterContainer.new()
		center.add_child(frame)
		col.add_child(center)
	if cover:
		_SongSelectUiStyles.apply_row_cover_texture(cover, str(entry.get("song_path", "")), 64)

	var val := Label.new()
	val.text = str(spec.get("value", ""))
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	val.add_theme_font_size_override("font_size", 15)
	val.add_theme_color_override("font_color", accent)
	col.add_child(val)

	var track := Label.new()
	track.text = _track_line(entry)
	track.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	track.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	track.add_theme_font_size_override("font_size", 10)
	track.add_theme_color_override("font_color", COLOR_VALUE)
	col.add_child(track)

	var settings := _play_settings_text(entry)
	if settings != "":
		var meta := Label.new()
		meta.text = settings
		meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		meta.add_theme_font_size_override("font_size", 9)
		meta.add_theme_color_override("font_color", COLOR_MUTED)
		col.add_child(meta)

	var mods := _entry_modifiers(entry)
	if not mods.is_empty():
		var mods_row := HBoxContainer.new()
		mods_row.alignment = BoxContainer.ALIGNMENT_CENTER
		mods_row.add_theme_constant_override("separation", 2)
		col.add_child(mods_row)
		_ModifierIconStrip.fill_slot_chips(mods_row, mods, {}, maxi(mods.size(), 1), true, 14, 8, 3, false)

	var date := Label.new()
	date.text = _format_date(str(entry.get("date", "")))
	date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	date.add_theme_font_size_override("font_size", 9)
	date.add_theme_color_override("font_color", COLOR_MUTED)
	if date.text != "":
		col.add_child(date)
	return card


static func _make_mod_clear_tile(mod_id: String, count: int) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tile.tooltip_text = _RunModifiers.format_tooltip(mod_id)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.1, 0.14, 0.95)
	box.border_color = Color(1, 1, 1, 0.06)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	tile.add_theme_stylebox_override("panel", box)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	tile.add_child(col)
	var tint := _RunModifiers.category_tint(mod_id, true)
	var icon_file := _RunModifiers.icon_file(mod_id)
	if icon_file.strip_edges() != "":
		var icon_wrap := CenterContainer.new()
		icon_wrap.add_child(_UiIconHelper.make_icon_frame(icon_file, 40, 22, tint))
		col.add_child(icon_wrap)
	var title := Label.new()
	title.text = _tr(_RunModifiers.title_i18n_key(mod_id))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(0.82, 0.88, 0.96, 0.96))
	col.add_child(title)
	var count_label := Label.new()
	count_label.text = str(count)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 20)
	count_label.add_theme_color_override("font_color", COLOR_ACCENT_GREEN)
	col.add_child(count_label)
	return tile


static func _add_mod_clears_section(parent: VBoxContainer, style: StyleBox) -> void:
	var entries := _ProfilePlayModesStats.mod_clear_entries()
	var body := _add_section_card(parent, _tr("PROFILE_RECORDS_MOD_CLEARS"), style, "mod_clears")
	var valid: Array = []
	for entry in entries:
		var mod_id := str(entry.get("mod_id", ""))
		var count := int(entry.get("count", 0))
		if mod_id != "" and count > 0:
			valid.append(entry)
	if valid.is_empty():
		_add_empty(body)
		return

	var row1 := HBoxContainer.new()
	row1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_theme_constant_override("separation", 8)
	body.add_child(row1)
	var preview_n := mini(5, valid.size())
	for i in range(preview_n):
		var e: Dictionary = valid[i]
		row1.add_child(_make_mod_clear_tile(str(e.get("mod_id", "")), int(e.get("count", 0))))

	if valid.size() <= 5:
		return
	var more_wrap := HBoxContainer.new()
	more_wrap.visible = false
	more_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	more_wrap.add_theme_constant_override("separation", 8)
	body.add_child(more_wrap)
	var rest_n := mini(10, valid.size())
	for i in range(5, rest_n):
		var e2: Dictionary = valid[i]
		more_wrap.add_child(_make_mod_clear_tile(str(e2.get("mod_id", "")), int(e2.get("count", 0))))
	var toggle := Button.new()
	toggle.text = _tr("PROFILE_HISTORY_SHOW_MORE")
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.theme_type_variation = &"FlatBackButton"
	toggle.custom_minimum_size = Vector2(0, 34)
	toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle.pressed.connect(func() -> void:
		more_wrap.visible = not more_wrap.visible
		if more_wrap.visible:
			_UiModifierSounds.play_select()
		else:
			_UiModifierSounds.play_deselect()
		toggle.text = _tr("PROFILE_HISTORY_SHOW_LESS" if more_wrap.visible else "PROFILE_HISTORY_SHOW_MORE")
	)
	body.add_child(toggle)


static func _add_marathon_section(parent: VBoxContainer, style: StyleBox) -> void:
	var entries := _ProfilePlayModesStats.marathon_record_entries()
	var body := _add_section_card(parent, _tr("PROFILE_RECORDS_MARATHON"), style, "marathon")
	if entries.is_empty():
		_add_empty(body)
		return
	var row1 := HBoxContainer.new()
	row1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_theme_constant_override("separation", 8)
	body.add_child(row1)
	var preview_n := mini(5, entries.size())
	for i in range(preview_n):
		row1.add_child(_make_marathon_route_card(entries[i] as Dictionary))

	var more_wrap := HBoxContainer.new()
	more_wrap.visible = false
	more_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	more_wrap.add_theme_constant_override("separation", 8)
	body.add_child(more_wrap)
	if entries.size() > 5:
		var rest_n := mini(10, entries.size())
		for i in range(5, rest_n):
			more_wrap.add_child(_make_marathon_route_card(entries[i] as Dictionary))
		var toggle := Button.new()
		toggle.text = _tr("PROFILE_HISTORY_SHOW_MORE")
		toggle.focus_mode = Control.FOCUS_NONE
		toggle.theme_type_variation = &"FlatBackButton"
		toggle.custom_minimum_size = Vector2(0, 34)
		toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toggle.pressed.connect(func() -> void:
			more_wrap.visible = not more_wrap.visible
			if more_wrap.visible:
				_UiModifierSounds.play_select()
			else:
				_UiModifierSounds.play_deselect()
			toggle.text = _tr("PROFILE_HISTORY_SHOW_LESS" if more_wrap.visible else "PROFILE_HISTORY_SHOW_MORE")
		)
		body.add_child(toggle)


static func _make_marathon_route_card(entry: Dictionary) -> PanelContainer:
	var route_id := str(entry.get("route_id", ""))
	var ratio := float(entry.get("best_ratio", 0.0))
	var acc := float(entry.get("best_acc", 0.0))
	var done := ratio >= 0.999
	var accent := COLOR_RR if done else COLOR_ACCENT_GREEN
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.09, 0.13, 0.98)
	box.border_color = Color(accent.r, accent.g, accent.b, 0.45 if done else 0.22)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	card.add_theme_stylebox_override("panel", box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)

	var title := Label.new()
	title.text = str(entry.get("title", route_id))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", COLOR_VALUE)
	col.add_child(title)

	var status := Label.new()
	status.text = _tr("PROFILE_RECORD_MARATHON_COMPLETED") if done else (
		_tr("PROFILE_RECORD_MARATHON_PROGRESS_FMT") % [int(round(ratio * 100.0)), acc]
	)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 12)
	status.add_theme_color_override("font_color", accent)
	col.add_child(status)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = clampf(ratio, 0.0, 1.0)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.12, 0.14, 0.18, 1.0)
	bar_bg.set_corner_radius_all(4)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = accent
	bar_fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bar_bg)
	bar.add_theme_stylebox_override("fill", bar_fill)
	col.add_child(bar)

	var badges: Array = []
	var badges_raw: Variant = entry.get("badges", [])
	if badges_raw is Array:
		badges = badges_raw as Array
	if not badges.is_empty():
		var template := _MarathonRouteCatalog.template_for_route(route_id)
		var badges_row := HBoxContainer.new()
		badges_row.alignment = BoxContainer.ALIGNMENT_CENTER
		badges_row.add_theme_constant_override("separation", 4)
		col.add_child(badges_row)
		for tier in _MarathonRouteBadges.TIER_ORDER:
			if str(tier) not in badges:
				continue
			var tint := _MarathonRouteBadges.tier_accent(str(tier))
			var frame := _UiIconHelper.make_icon_frame(
				_MarathonRouteBadges.tier_icon_file(str(tier)),
				26,
				14,
				tint
			)
			frame.tooltip_text = _MarathonRouteBadges.medal_tooltip(route_id, str(tier), template)
			badges_row.add_child(frame)
	return card


static func _add_endless_section(parent: VBoxContainer, style: StyleBox) -> void:
	if PlayerDataManager == null or not PlayerDataManager.is_play_mode_unlocked(PlayModeIds.ENDLESS):
		return
	if not PlayerDataManager.has_method("get_endless_stats"):
		return
	var stats: Dictionary = PlayerDataManager.get_endless_stats()
	var body := _add_section_card(
		parent,
		_tr("PROFILE_RECORDS_ENDLESS"),
		style,
		"",
		"repeat.svg",
		Color(0.72, 0.58, 0.95, 1.0)
	)
	var best_streak: int = int(PlayerDataManager.get_endless_best_streak())
	var best_rr: int = int(stats.get("best_series_rr", 0))
	var total_runs := int(stats.get("total_runs", 0))
	if best_streak <= 0 and best_rr <= 0 and total_runs <= 0:
		_add_empty(body)
		return

	var hero := HBoxContainer.new()
	hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.add_theme_constant_override("separation", 12)
	body.add_child(hero)
	hero.add_child(_make_endless_hero_stat(
		_tr("PROFILE_RECORD_ENDLESS_BEST_STREAK"),
		str(best_streak),
		COLOR_RR
	))
	hero.add_child(_make_endless_hero_stat(
		_tr("PROFILE_RECORD_ENDLESS_BEST_RR"),
		str(best_rr) if best_rr > 0 else _tr("VALUE_NA"),
		COLOR_RR
	))

	var chips := HBoxContainer.new()
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chips.add_theme_constant_override("separation", 8)
	body.add_child(chips)
	var avg_acc := float(stats.get("best_avg_accuracy", 0.0))
	var avg_text := "%.1f%%" % avg_acc if avg_acc > 0.0 else _tr("VALUE_NA")
	chips.add_child(_make_endless_chip(_tr("PROFILE_RECORD_ENDLESS_BEST_ACCURACY"), avg_text, COLOR_ACCENT_GREEN))
	chips.add_child(_make_endless_chip(
		_tr("PROFILE_RECORD_ENDLESS_TOTAL_NOTES"),
		str(int(stats.get("total_notes_hit", 0))),
		COLOR_VALUE
	))
	chips.add_child(_make_endless_chip(
		_tr("PROFILE_RECORD_ENDLESS_TOTAL_RUNS"),
		str(total_runs),
		COLOR_VALUE
	))


static func _make_endless_hero_stat(caption: String, value: String, accent: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.09, 0.13, 0.98)
	box.border_color = Color(accent.r, accent.g, accent.b, 0.4)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.content_margin_left = 14.0
	box.content_margin_right = 14.0
	box.content_margin_top = 12.0
	box.content_margin_bottom = 12.0
	card.add_theme_stylebox_override("panel", box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)
	var cap := Label.new()
	cap.text = caption
	cap.add_theme_font_size_override("font_size", 12)
	cap.add_theme_color_override("font_color", COLOR_CAPTION)
	col.add_child(cap)
	var val := Label.new()
	val.text = value
	val.add_theme_font_size_override("font_size", 32)
	val.add_theme_color_override("font_color", accent)
	col.add_child(val)
	return card


static func _make_endless_chip(caption: String, value: String, accent: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.1, 0.14, 0.95)
	box.border_color = Color(1, 1, 1, 0.06)
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	chip.add_theme_stylebox_override("panel", box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	chip.add_child(col)
	var val := Label.new()
	val.text = value
	val.add_theme_font_size_override("font_size", 16)
	val.add_theme_color_override("font_color", accent)
	col.add_child(val)
	var cap := Label.new()
	cap.text = caption
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.add_theme_font_size_override("font_size", 10)
	cap.add_theme_color_override("font_color", COLOR_MUTED)
	col.add_child(cap)
	return chip


static func _add_streaks_section(parent: VBoxContainer, streaks: Variant, style: StyleBox) -> void:
	var body := _add_section_card(parent, _tr("PROFILE_RECORDS_STREAKS"), style)
	var clear_best := 0
	var clear_current := 0
	if streaks is Dictionary:
		clear_best = int(streaks.get("best_clear_streak_days", 0))
		clear_current = int(streaks.get("current_clear_streak_days", 0))
	var login_current := 0
	var login_best := 0
	if PlayerDataManager:
		login_current = int(PlayerDataManager.get_login_streak())
		login_best = int(PlayerDataManager.get_best_login_streak())

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)
	row.add_child(_make_streak_pulse_card(
		_tr("PROFILE_RECORD_STREAK_CLEARS_GROUP"),
		clear_current,
		clear_best,
		COLOR_RR
	))
	row.add_child(_make_streak_pulse_card(
		_tr("PROFILE_RECORD_STREAK_LOGIN_GROUP"),
		login_current,
		login_best,
		COLOR_ACCENT_GREEN
	))


static func _make_streak_pulse_card(
	title: String,
	current: int,
	best: int,
	accent: Color
) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.09, 0.13, 0.98)
	box.border_color = Color(accent.r, accent.g, accent.b, 0.35)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.content_margin_left = 14.0
	box.content_margin_right = 14.0
	box.content_margin_top = 12.0
	box.content_margin_bottom = 12.0
	card.add_theme_stylebox_override("panel", box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.add_theme_color_override("font_color", COLOR_CAPTION)
	col.add_child(title_lbl)

	var numbers := HBoxContainer.new()
	numbers.add_theme_constant_override("separation", 12)
	col.add_child(numbers)

	var cur_col := VBoxContainer.new()
	cur_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cur_col.add_theme_constant_override("separation", 2)
	numbers.add_child(cur_col)
	var cur_val := Label.new()
	cur_val.text = str(current)
	cur_val.add_theme_font_size_override("font_size", 28)
	cur_val.add_theme_color_override("font_color", accent)
	cur_col.add_child(cur_val)
	var cur_cap := Label.new()
	cur_cap.text = _tr("PROFILE_RECORD_STREAK_CURRENT_LABEL")
	cur_cap.add_theme_font_size_override("font_size", 11)
	cur_cap.add_theme_color_override("font_color", COLOR_MUTED)
	cur_col.add_child(cur_cap)

	var best_col := VBoxContainer.new()
	best_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	best_col.add_theme_constant_override("separation", 2)
	numbers.add_child(best_col)
	var best_val := Label.new()
	best_val.text = str(best)
	best_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	best_val.add_theme_font_size_override("font_size", 28)
	best_val.add_theme_color_override("font_color", COLOR_VALUE)
	best_col.add_child(best_val)
	var best_cap := Label.new()
	best_cap.text = _tr("PROFILE_RECORD_STREAK_BEST_LABEL")
	best_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	best_cap.add_theme_font_size_override("font_size", 11)
	best_cap.add_theme_color_override("font_color", COLOR_MUTED)
	best_col.add_child(best_cap)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = (float(current) / float(best)) if best > 0 else 0.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.12, 0.14, 0.18, 1.0)
	bar_bg.set_corner_radius_all(5)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = accent
	bar_fill.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("background", bar_bg)
	bar.add_theme_stylebox_override("fill", bar_fill)
	col.add_child(bar)

	var of_lbl := Label.new()
	of_lbl.text = _tr("PROFILE_RECORD_STREAK_OF_FMT") % [current, best]
	of_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	of_lbl.add_theme_font_size_override("font_size", 11)
	of_lbl.add_theme_color_override("font_color", COLOR_MUTED)
	col.add_child(of_lbl)
	return card


static func _add_genre_section(parent: VBoxContainer, highlights: Variant, style: StyleBox) -> void:
	var body := _add_section_card(parent, _tr("PROFILE_RECORDS_GENRES"), style)
	var hl: Dictionary = highlights if highlights is Dictionary else {}
	var shelf := HBoxContainer.new()
	shelf.add_theme_constant_override("separation", 10)
	shelf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(shelf)

	var play_counts: Dictionary = TrackStatsManager.genre_play_counts if TrackStatsManager else {}
	var most_rows := _ProfileGenrePortrait.top_groups(play_counts, 5)
	var acc_rows := _genre_metric_tops(hl, "group_accuracy_", 5)
	var hard_rows := _genre_metric_tops(hl, "group_difficulty_", 5)
	var expand_panels: Array = []

	if not most_rows.is_empty():
		shelf.add_child(_make_genre_rank_card(
			_tr("PROFILE_RECORD_GENRE_MOST_PLAYED"),
			most_rows,
			"plays",
			Color(0.72, 0.58, 0.95, 1.0),
			expand_panels
		))
	if not acc_rows.is_empty():
		shelf.add_child(_make_genre_rank_card(
			_tr("PROFILE_RECORD_GENRE_BEST_ACCURACY"),
			acc_rows,
			"accuracy",
			COLOR_ACCENT_GREEN,
			expand_panels
		))
	if not hard_rows.is_empty():
		shelf.add_child(_make_genre_rank_card(
			_tr("PROFILE_RECORD_GENRE_HARDEST"),
			hard_rows,
			"rating",
			COLOR_RR,
			expand_panels
		))
	if shelf.get_child_count() == 0:
		shelf.queue_free()
		_add_empty(body)
		return
	if expand_panels.is_empty():
		return
	var toggle := Button.new()
	toggle.text = _tr("PROFILE_HISTORY_SHOW_MORE")
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.theme_type_variation = &"FlatBackButton"
	toggle.custom_minimum_size = Vector2(0, 34)
	toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle.pressed.connect(func() -> void:
		var open := true
		for panel in expand_panels:
			if panel is Control and (panel as Control).visible:
				open = false
				break
		for panel2 in expand_panels:
			if panel2 is Control:
				(panel2 as Control).visible = open
		if open:
			_UiModifierSounds.play_select()
		else:
			_UiModifierSounds.play_deselect()
		toggle.text = _tr("PROFILE_HISTORY_SHOW_LESS" if open else "PROFILE_HISTORY_SHOW_MORE")
	)
	body.add_child(toggle)


static func _genre_metric_tops(highlights: Dictionary, prefix: String, limit: int = 5) -> Array:
	var rows: Array = []
	for k in highlights.keys():
		var key := str(k)
		if not key.begins_with(prefix):
			continue
		var group := key.substr(prefix.length())
		if group == "" or group == "_other":
			continue
		rows.append({"group": group, "value": float(highlights[k])})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var va := float(a.get("value", 0.0))
		var vb := float(b.get("value", 0.0))
		if not is_equal_approx(va, vb):
			return va > vb
		return str(a.get("group", "")) < str(b.get("group", ""))
	)
	if rows.size() > limit:
		return rows.slice(0, limit)
	return rows


static func _make_genre_rank_card(
	caption: String,
	rows: Array,
	kind: String,
	accent: Color,
	expand_panels: Array = []
) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(140, 0)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.09, 0.13, 0.98)
	box.border_color = Color(accent.r, accent.g, accent.b, 0.4)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 12.0
	box.content_margin_bottom = 12.0
	card.add_theme_stylebox_override("panel", box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)

	var cap := Label.new()
	cap.text = caption
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.add_theme_font_size_override("font_size", 11)
	cap.add_theme_color_override("font_color", COLOR_CAPTION)
	col.add_child(cap)

	if rows.is_empty():
		return card
	col.add_child(_make_genre_rank_row(rows[0] as Dictionary, kind, accent, true))

	var extra := VBoxContainer.new()
	extra.visible = false
	extra.add_theme_constant_override("separation", 4)
	col.add_child(extra)
	var rest_n := mini(5, rows.size())
	for i in range(1, rest_n):
		extra.add_child(_make_genre_rank_row(rows[i] as Dictionary, kind, accent, false))
	if rest_n > 1:
		expand_panels.append(extra)
	return card


static func _make_genre_rank_row(
	row: Dictionary,
	kind: String,
	accent: Color,
	primary: bool
) -> Control:
	var group := str(row.get("group", ""))
	var value := float(row.get("value", 0.0))
	var count := int(row.get("count", 0))
	var wrap := HBoxContainer.new()
	wrap.add_theme_constant_override("separation", 6)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var group_tint := _GenreGroupIcons.tint_for_group(group)
	wrap.add_child(_GenreGroupIcons.make_icon_frame_for_group(
		group,
		group_tint,
		22 if primary else 18,
		12 if primary else 10
	))

	var name_lbl := Label.new()
	name_lbl.text = _group_label(group)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", 15 if primary else 12)
	name_lbl.add_theme_color_override("font_color", accent if primary else COLOR_VALUE)
	wrap.add_child(name_lbl)

	match kind:
		"plays":
			var plays := Label.new()
			plays.text = str(count if count > 0 else int(value))
			plays.add_theme_font_size_override("font_size", 14 if primary else 12)
			plays.add_theme_color_override("font_color", accent if primary else COLOR_MUTED)
			wrap.add_child(plays)
		"accuracy":
			var acc := Label.new()
			acc.text = "%.1f%%" % value
			acc.add_theme_font_size_override("font_size", 14 if primary else 12)
			acc.add_theme_color_override("font_color", accent if primary else COLOR_MUTED)
			wrap.add_child(acc)
		"rating":
			var tint := (
				_ChartDifficultyAnalyzer.rating_color_for_decimal(value)
				if value > 0.0
				else accent
			)
			wrap.add_child(_UiIconHelper.make_icon_frame("zap.svg", 18 if primary else 14, 11 if primary else 9, tint))
			var rating := Label.new()
			rating.text = _ChartDifficultyAnalyzer.format_decimal_rating(value, false)
			rating.add_theme_font_size_override("font_size", 14 if primary else 12)
			rating.add_theme_color_override("font_color", tint)
			wrap.add_child(rating)
		_:
			pass
	return wrap


static func _make_genre_card(caption: String, value: String, accent: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(140, 0)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.09, 0.13, 0.98)
	box.border_color = Color(accent.r, accent.g, accent.b, 0.4)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 12.0
	box.content_margin_bottom = 12.0
	card.add_theme_stylebox_override("panel", box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)
	var cap := Label.new()
	cap.text = caption
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.add_theme_font_size_override("font_size", 11)
	cap.add_theme_color_override("font_color", COLOR_CAPTION)
	col.add_child(cap)
	var val := Label.new()
	val.text = value
	val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	val.add_theme_font_size_override("font_size", 15)
	val.add_theme_color_override("font_color", accent)
	col.add_child(val)
	return card


static func _group_label(group_id: String) -> String:
	var key := _ProfileGenrePortrait.group_locale_key(group_id)
	var label := _tr(key)
	if label == key:
		return group_id.replace("_", " ").capitalize()
	return label
