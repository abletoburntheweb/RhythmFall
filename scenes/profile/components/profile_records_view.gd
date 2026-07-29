# scenes/profile/components/profile_records_view.gd
class_name ProfileRecordsView
extends RefCounted

const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const _ProfileGenrePortrait = preload("res://logic/domain/profile/profile_genre_portrait.gd")
const _RhythmRating = preload("res://logic/domain/rhythm/rhythm_rating.gd")
const _ProfilePlayModesStats = preload("res://logic/domain/profile/profile_play_modes_stats.gd")
const _MarathonRouteCatalog = preload("res://logic/domain/session/marathon_route_catalog.gd")
const _ModifierIconStrip = preload("res://logic/ui/modifier_icon_strip.gd")
const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")

const RECORD_SECTION_SCENE := preload("res://scenes/profile/components/profile_record_section.tscn")
const RECORD_HIGHLIGHT_SCENE := preload("res://scenes/profile/components/profile_record_highlight_entry.tscn")
const RECORD_DETAIL_ROW_SCENE := preload("res://scenes/profile/components/profile_record_detail_row.tscn")
const RECORD_RR_ROW_SCENE := preload("res://scenes/profile/components/profile_record_rr_row.tscn")
const STAT_TILE_SCENE := preload("res://scenes/profile/components/profile_stat_tile.tscn")

const COLOR_CAPTION := Color(0.654902, 0.654902, 0.678431, 1)
const COLOR_VALUE := Color(0.784314, 0.823529, 0.901961, 1)
const COLOR_RR := Color(0.9490196, 0.7019608, 0.3529412, 1)
const COLOR_MUTED := Color(0.55, 0.58, 0.65, 0.92)
const COLOR_ACCENT_GREEN := Color(0.38039216, 0.78039217, 0.7411765, 1)

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
}

const MILESTONE_SPECS: Array = [
	["first_track_played", "PROFILE_RECORD_MILESTONE_FIRST_TRACK", "", "circle-play.svg"],
	["first_ss", "PROFILE_RECORD_MILESTONE_FIRST_SS", "", "trophy.svg"],
	["first_s", "PROFILE_RECORD_MILESTONE_FIRST_S", "", "star.svg"],
	["first_hidden_clear", "PROFILE_RECORD_MILESTONE_FIRST_HIDDEN", "", "eye-off.svg"],
	["first_fc", "PROFILE_RECORD_MILESTONE_FIRST_FC", "", "clock.svg"],
	["unique_100_tracks", "PROFILE_RECORD_MILESTONE_UNIQUE_100", "100", "hash.svg"],
	["clears_1000", "PROFILE_RECORD_MILESTONE_CLEARS_1000", "1000", "target.svg"],
]

const EXTREME_SPECS: Array = [
	["highest_accuracy", "PROFILE_RECORD_EXTREME_ACCURACY", "percent", "zap.svg"],
	["hardest_chart_cleared", "PROFILE_RECORD_EXTREME_CHART", "rating", "chart-column.svg"],
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


static func rebuild_async(content_vbox: VBoxContainer, card_style: StyleBox) -> void:
	if content_vbox == null or _rebuild_busy:
		return
	_rebuild_busy = true
	_clear_content(content_vbox)
	if not ProfileMilestonesManager:
		_rebuild_busy = false
		return
	var tree := content_vbox.get_tree()
	if tree:
		await tree.process_frame
	var data := ProfileMilestonesManager.get_data()
	content_vbox.add_theme_constant_override("separation", 10)

	_add_rr_top10_section(content_vbox, data.get("rhythm_rating_top10", []), card_style)
	if tree:
		await tree.process_frame
	_add_milestones_section(content_vbox, data.get("milestones", {}), card_style)
	if tree:
		await tree.process_frame
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


static func _add_section_card(
	parent: VBoxContainer,
	title: String,
	style: StyleBox,
	section_id: String = "",
	icon_file: String = "",
	icon_tint: Color = Color(0.419608, 0.568627, 0.823529, 1)
) -> VBoxContainer:
	var section := RECORD_SECTION_SCENE.instantiate()
	section.set_section_title(title, icon_file, icon_tint)
	section.set_panel_style(style)
	if section.has_method("set_section_id") and str(section_id).strip_edges() != "":
		section.set_section_id(str(section_id).strip_edges())
	parent.add_child(section)
	return section.get_body()


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
	parent: VBoxContainer,
	caption: String,
	primary: String,
	secondary: String = "",
	value_text: String = "",
	value_color: Color = COLOR_RR,
	modifiers: Array = [],
	caption_icon_file: String = "",
	caption_icon_tint: Color = COLOR_CAPTION
) -> Node:
	var entry := RECORD_HIGHLIGHT_SCENE.instantiate()
	parent.add_child(entry)
	entry.apply_entry(
		caption,
		primary,
		secondary,
		value_text,
		value_color,
		modifiers,
		caption_icon_file,
		caption_icon_tint
	)
	return entry


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
		"fullmix", "микс":
			return _tr("GEN_INST_MIX")
		"standard", "стандарт", "":
			return _tr("GEN_INST_STANDARD")
		_:
			return instrument_raw if instrument_raw != "" else ""


static func _mode_label(mode_raw: String) -> String:
	var mode := mode_raw.strip_edges().to_lower()
	if mode == "":
		return ""
	var mode_key := "GEN_MODE_%s" % mode.to_upper()
	var label := _tr(mode_key)
	if label == mode_key:
		return mode_raw
	return label


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
	var rank := 1
	var valid_count := 0
	for entry in top10:
		if entry is Dictionary:
			valid_count += 1
	for entry in top10:
		if not entry is Dictionary:
			continue
		var rr := int(entry.get("best_rr", 0))
		var row := RECORD_RR_ROW_SCENE.instantiate()
		body.add_child(row)
		row.apply_row(
			rank,
			rr,
			_track_line(entry),
			_entry_meta_line(entry, false),
			rank < valid_count,
			_entry_modifiers(entry)
		)
		rank += 1


static func _add_milestones_section(parent: VBoxContainer, milestones: Variant, style: StyleBox) -> void:
	var body := _add_section_card(parent, _tr("PROFILE_RECORDS_MILESTONES"), style)
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


static func _add_extremes_section(parent: VBoxContainer, extremes: Variant, style: StyleBox) -> void:
	var body := _add_section_card(parent, _tr("PROFILE_RECORDS_EXTREMES"), style)
	var has_any := false
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
			_add_highlight_entry(
				body,
				_tr(String(spec[1])),
				track,
				" · ".join(secondary_parts),
				value_text,
				COLOR_ACCENT_GREEN,
				[],
				_spec_icon_file(spec),
				_icon_tint_for_file(_spec_icon_file(spec), COLOR_ACCENT_GREEN)
			)
		var last_rec: Variant = extremes.get("last_personal_record")
		if last_rec is Dictionary and int(last_rec.get("best_rr", 0)) > 0:
			has_any = true
			_add_highlight_entry(
				body,
				_tr("PROFILE_RECORD_EXTREME_LAST_RECORD"),
				_track_line(last_rec),
				_entry_meta_line(last_rec, true),
				"%d RR" % int(last_rec.get("best_rr", 0)),
				COLOR_RR,
				[],
				"fingerprint-pattern.svg",
				_icon_tint_for_file("fingerprint-pattern.svg", COLOR_RR)
			)
	if not has_any:
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
			return "%.0f/10" % value
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
	var has_any := false
	if mod_records is Dictionary:
		var max_rec: Variant = mod_records.get("max_mod_count")
		if max_rec is Dictionary and int(max_rec.get("count", 0)) > 0:
			has_any = true
			var mods := _entry_modifiers(max_rec)
			var secondary := _entry_meta_line(max_rec, false)
			var value_line := _tr("PROFILE_RECORDS_MOD_COUNT_SHORT") % int(max_rec.get("count", 0))
			_add_highlight_entry(
				body,
				_tr("PROFILE_RECORD_MOD_MAX_COUNT"),
				_track_line(max_rec),
				secondary,
				value_line,
				COLOR_VALUE,
				mods
			)
		var hard_rec: Variant = mod_records.get("hardest_mod_combo")
		if hard_rec is Dictionary and float(hard_rec.get("hardness", 0.0)) > 0.0:
			has_any = true
			var mods := _entry_modifiers(hard_rec)
			var bonus_pct := int(round(float(hard_rec.get("hardness", 0.0)) * 100.0))
			var value_line := _tr("PROFILE_RECORD_MOD_HARD_BONUS") % bonus_pct
			var secondary := _entry_meta_line(hard_rec, false)
			if secondary != "":
				secondary += "\n" + _tr("PROFILE_RECORD_MOD_HARD_HINT")
			else:
				secondary = _tr("PROFILE_RECORD_MOD_HARD_HINT")
			_add_highlight_entry(
				body,
				_tr("PROFILE_RECORD_MOD_HARDEST"),
				_track_line(hard_rec),
				secondary,
				value_line,
				COLOR_RR,
				mods
			)
	if not has_any:
		_add_empty(body)


static func _add_mod_clears_section(parent: VBoxContainer, style: StyleBox) -> void:
	var entries := _ProfilePlayModesStats.mod_clear_entries()
	var body := _add_section_card(parent, _tr("PROFILE_RECORDS_MOD_CLEARS"), style, "mod_clears")
	if entries.is_empty():
		_add_empty(body)
		return
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	body.add_child(list)
	for entry in entries:
		var mod_id := str(entry.get("mod_id", ""))
		var count := int(entry.get("count", 0))
		if mod_id == "" or count <= 0:
			continue
		list.add_child(_make_mod_clear_row(mod_id, count))


static func _add_marathon_section(parent: VBoxContainer, style: StyleBox) -> void:
	var entries := _ProfilePlayModesStats.marathon_record_entries()
	var body := _add_section_card(parent, _tr("PROFILE_RECORDS_MARATHON"), style, "marathon")
	if entries.is_empty():
		_add_empty(body)
		return
	for entry in entries:
		var route_id := str(entry.get("route_id", ""))
		var title := str(entry.get("title", route_id))
		var ratio := float(entry.get("best_ratio", 0.0))
		var acc := float(entry.get("best_acc", 0.0))
		var progress_text := _tr("PROFILE_RECORD_MARATHON_COMPLETED") if ratio >= 0.999 else (
			_tr("PROFILE_RECORD_MARATHON_PROGRESS_FMT") % [int(round(ratio * 100.0)), acc]
		)
		var badges: Array = []
		var badges_raw: Variant = entry.get("badges", [])
		if badges_raw is Array:
			badges = badges_raw as Array
		var template := _MarathonRouteCatalog.template_for_route(route_id)
		var highlight := _add_highlight_entry(
			body,
			_tr("PROFILE_RECORD_MARATHON_ROUTE"),
			title,
			progress_text,
			"",
			COLOR_RR
		)
		if highlight and highlight.has_method("set_marathon_badge_chips"):
			highlight.set_marathon_badge_chips(route_id, badges, template)


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
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)

	var best_streak := PlayerDataManager.get_endless_best_streak()
	grid.add_child(_make_stat_tile(_tr("PROFILE_RECORD_ENDLESS_BEST_STREAK"), str(best_streak), COLOR_RR))
	var avg_acc := float(stats.get("best_avg_accuracy", 0.0))
	var avg_text := "%.1f%%" % avg_acc if avg_acc > 0.0 else _tr("VALUE_NA")
	grid.add_child(_make_stat_tile(_tr("PROFILE_RECORD_ENDLESS_BEST_ACCURACY"), avg_text, COLOR_ACCENT_GREEN))
	var total_notes := int(stats.get("total_notes_hit", 0))
	grid.add_child(_make_stat_tile(_tr("PROFILE_RECORD_ENDLESS_TOTAL_NOTES"), str(total_notes), COLOR_VALUE))
	var total_runs := int(stats.get("total_runs", 0))
	grid.add_child(_make_stat_tile(_tr("PROFILE_RECORD_ENDLESS_TOTAL_RUNS"), str(total_runs), COLOR_VALUE))

	var history: Variant = stats.get("history", [])
	if history is Array and not history.is_empty():
		_add_subheading(body, _tr("PROFILE_RECORD_ENDLESS_HISTORY"))
		var shown := 0
		for entry in history:
			if not entry is Dictionary:
				continue
			shown += 1
			if shown > 5:
				break
			var streak := int(entry.get("streak", 0))
			var acc := float(entry.get("average_accuracy", 0.0))
			var date_text := _format_date(str(entry.get("date", "")))
			var secondary_parts: PackedStringArray = []
			if date_text != "":
				secondary_parts.append(date_text)
			_add_highlight_entry(
				body,
				_tr("PROFILE_RECORD_ENDLESS_RUN_FMT") % streak,
				"",
				" · ".join(secondary_parts),
				_tr("PROFILE_RECORD_ENDLESS_RUN_ACCURACY_FMT") % acc,
				COLOR_ACCENT_GREEN
			)
	elif int(stats.get("total_runs", 0)) == 0:
		_add_empty(body)


static func _add_streaks_section(parent: VBoxContainer, streaks: Variant, style: StyleBox) -> void:
	var body := _add_section_card(parent, _tr("PROFILE_RECORDS_STREAKS"), style)
	var clear_best := 0
	var clear_current := 0
	if streaks is Dictionary:
		clear_best = int(streaks.get("best_clear_streak_days", 0))
		clear_current = int(streaks.get("current_clear_streak_days", 0))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)

	grid.add_child(_make_stat_tile(_tr("PROFILE_RECORD_STREAK_CLEAR_BEST"), str(clear_best), COLOR_RR))
	grid.add_child(_make_stat_tile(_tr("PROFILE_RECORD_STREAK_CLEAR_CURRENT"), str(clear_current), COLOR_VALUE))
	if PlayerDataManager:
		grid.add_child(_make_stat_tile(_tr("PROFILE_LOGIN_STREAK_TITLE"), str(PlayerDataManager.get_login_streak()), COLOR_RR))
		grid.add_child(_make_stat_tile(_tr("PROFILE_LOGIN_STREAK_BEST"), str(PlayerDataManager.get_best_login_streak()), COLOR_VALUE))


static func _add_genre_section(parent: VBoxContainer, highlights: Variant, style: StyleBox) -> void:
	var body := _add_section_card(parent, _tr("PROFILE_RECORDS_GENRES"), style)
	if not highlights is Dictionary or highlights.is_empty():
		_add_empty(body)
		return
	var most := str(highlights.get("most_played_group", ""))
	if most != "":
		_add_detail_row(body, _tr("PROFILE_RECORD_GENRE_MOST_PLAYED"), _group_label(most))
	var best_group := str(highlights.get("best_accuracy_group", ""))
	if best_group != "":
		_add_detail_row(
			body,
			_tr("PROFILE_RECORD_GENRE_BEST_ACCURACY"),
			_tr("PROFILE_RECORD_GENRE_VALUE_FMT") % [
				_group_label(best_group),
				float(highlights.get("best_accuracy_value", 0.0)),
			]
		)
	var hard_group := str(highlights.get("hardest_avg_group", ""))
	if hard_group != "":
		_add_detail_row(
			body,
			_tr("PROFILE_RECORD_GENRE_HARDEST"),
			_tr("PROFILE_RECORD_GENRE_RATING_FMT") % [
				_group_label(hard_group),
				float(highlights.get("hardest_avg_group_value", 0.0)),
			]
		)


static func _group_label(group_id: String) -> String:
	var key := _ProfileGenrePortrait.group_locale_key(group_id)
	var label := _tr(key)
	if label == key:
		return group_id.replace("_", " ").capitalize()
	return label
