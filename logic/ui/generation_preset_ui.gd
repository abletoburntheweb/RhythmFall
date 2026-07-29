# logic/ui/generation_preset_ui.gd
extends RefCounted
class_name GenerationPresetUi

const _GoalDiff = preload("res://logic/domain/generation/generation_goal_difficulty.gd")

const INSTRUMENT_ICONS := {
	"drums": "drum.svg",
	"fullmix": "blend.svg",
	"bass": "guitar.svg",
	"guitar": "guitar.svg",
	"keys": "piano.svg",
	"vocals": "mic-vocal.svg",
}

const MODE_ICONS := {
	"minimal": "feather.svg",
	"basic": "circle-check.svg",
	"enhanced": "flame_gen.svg",
	"natural": "audio-lines.svg",
	"custom": "settings-2.svg",
}

# Phase B — generation intents (see docs/generation_intents.md).
const INTENT_ICONS := {
	"original": "audio-lines.svg",
	"groove": "heart-pulse.svg",
	"arcade": "gamepad-2.svg",
	"sparse": "feather.svg",
}

const INTENT_ICON_COLORS := {
	"original": Color(0.52, 0.88, 0.72, 1.0),
	"groove": Color(0.95, 0.55, 0.62, 1.0),
	"arcade": Color(1.0, 0.58, 0.32, 1.0),
	"sparse": Color(0.62, 0.82, 0.96, 1.0),
}

const INTENT_ICON_ALTERNATES := {
	"original": ["headphones.svg", "circle-check.svg"],
	"groove": ["activity.svg", "metronome.svg"],
	"arcade": ["zap.svg", "flame_gen.svg", "sparkles.svg"],
	"sparse": ["between-horizontal-start.svg", "eraser.svg"],
}

const MODE_ICON_COLORS := {
	"minimal": Color(0.62, 0.82, 0.96, 1.0),
	"basic": Color(0.55, 0.78, 0.98, 1.0),
	"enhanced": Color(1.0, 0.58, 0.32, 1.0),
	"natural": Color(0.48, 0.9, 0.68, 1.0),
	"custom": Color(0.72, 0.66, 0.98, 1.0),
}

const INSTRUMENT_ICON_COLORS := {
	"drums": Color(0.38, 0.78, 0.74, 1.0),
	"bass": Color(0.4509804, 0.61960787, 0.92156863, 1.0),
	"guitar": Color(0.86, 0.52, 0.72, 1.0),
	"keys": Color(0.52, 0.76, 0.92, 1.0),
	"vocals": Color(0.66, 0.58, 0.86, 1.0),
	"fullmix": Color(0.42, 0.57, 0.82, 1.0),
}

const PARAM_ICON_COLORS := {
	"fill": Color(0.58, 0.78, 0.98, 1.0),
	"groove": Color(0.95, 0.55, 0.62, 1.0),
	"density": Color(0.62, 0.72, 0.92, 1.0),
	"grid_snap": Color(0.72, 0.62, 0.95, 1.0),
	"genre_template": Color(0.55, 0.88, 0.72, 1.0),
	"accent": Color(0.98, 0.72, 0.42, 1.0),
	"genre_detect": Color(0.58, 0.82, 0.96, 1.0),
	"stems": Color(0.68, 0.76, 0.98, 1.0),
	"hi_hats": Color(0.72, 0.68, 0.95, 1.0),
	"critic_strength": Color(0.88, 0.62, 0.58, 1.0),
	"groove_completion": Color(0.95, 0.55, 0.62, 1.0),
	"raw_adtof": Color(0.52, 0.88, 0.72, 1.0),
}

const PARAM_ICONS := {
	"fill": "between-horizontal-start.svg",
	"groove": "heart-pulse.svg",
	"density": "text-align-justify.svg",
	"grid_snap": "magnet.svg",
	"genre_template": "tags.svg",
	"accent": "metronome.svg",
	"genre_detect": "fingerprint-pattern.svg",
	"stems": "split.svg",
	"hi_hats": "audio-lines.svg",
	"critic_strength": "eraser.svg",
	"groove_completion": "repeat.svg",
	"raw_adtof": "activity.svg",
}

const _CUSTOM_SLOT_PARAMS := ["fill", "groove", "density", "grid_snap"]

const _DETAIL_ROWS := [
	{"param": "instrument", "label_key": "GEN_PRESET_ROW_INSTRUMENT"},
	{"param": "mode", "label_key": "GEN_PRESET_ROW_MODE"},
	{"param": "lanes", "label_key": "GEN_PRESET_ROW_LANES"},
	{"param": "fill", "label_key": "GEN_PRESET_ROW_FILL"},
	{"param": "groove", "label_key": "GEN_PRESET_ROW_GROOVE"},
	{"param": "density", "label_key": "GEN_PRESET_ROW_DENSITY"},
	{"param": "grid_snap_strength", "label_key": "GEN_PRESET_ROW_GRID", "icon": "grid_snap"},
	{"param": "genre_template_strength", "label_key": "GEN_PRESET_ROW_GENRE_TEMPLATE", "icon": "genre_template"},
	{"param": "accent_strong_beats", "label_key": "GEN_PRESET_ROW_ACCENT", "icon": "accent"},
	{"param": "enable_genre_detection", "label_key": "GEN_PRESET_ROW_GENRE_DETECT", "icon": "genre_detect"},
	{"param": "use_stems_in_generation", "label_key": "GEN_PRESET_ROW_STEMS", "icon": "stems"},
	{"param": "include_hi_hats", "label_key": "GEN_PRESET_ROW_HI_HATS", "icon": "hi_hats"},
	{"param": "critic_strength", "label_key": "GEN_PRESET_ROW_CRITIC", "icon": "critic_strength"},
	{"param": "groove_completion", "label_key": "GEN_PRESET_ROW_GROOVE_COMPLETION", "icon": "groove_completion"},
	{"param": "raw_adtof", "label_key": "GEN_PRESET_ROW_RAW_ADTOF", "icon": "raw_adtof"},
]

const _INSTRUMENT_TITLE_KEYS := {
	"drums": "GEN_INST_DRUMS",
	"fullmix": "GEN_INST_FULLMIX",
	"bass": "GEN_INST_BASS",
	"guitar": "GEN_INST_GUITAR",
	"keys": "GEN_INST_KEYS",
	"vocals": "GEN_INST_VOCALS",
}


static func localized_intent(intent_id: String) -> String:
	var intent := intent_id.strip_edges().to_lower()
	if intent in INTENT_ICONS:
		return TranslationServer.translate("GEN_INTENT_%s" % intent.to_upper())
	return localized_mode(intent_id)


static func localized_mode(mode_id: String) -> String:
	var mode := mode_id.strip_edges().to_lower()
	if _GoalDiff.is_chart_stem(mode):
		return localized_chart_stem(mode)
	if mode in MODE_ICONS:
		return TranslationServer.translate("GEN_MODE_%s" % mode.to_upper())
	return mode_id


static func localized_chart_stem(stem: String) -> String:
	var pair := _GoalDiff.pair_from_stem(stem)
	var goal := str(pair.get("goal", _GoalDiff.DEFAULT_GOAL))
	var difficulty := str(pair.get("difficulty", _GoalDiff.DEFAULT_DIFFICULTY))
	var goal_label := TranslationServer.translate("GEN_GOAL_%s" % goal.to_upper())
	if _GoalDiff.sanitize_goal(goal) == "original":
		return goal_label
	var diff_label := TranslationServer.translate(_GoalDiff.difficulty_label_key(goal, difficulty))
	return "%s · %s" % [goal_label, diff_label]


static func localized_instrument(instrument_id: String) -> String:
	var inst := instrument_id.strip_edges().to_lower()
	var key: String = _INSTRUMENT_TITLE_KEYS.get(inst, "")
	if key != "":
		return TranslationServer.translate(key)
	return instrument_id


static func localized_bool(value: Variant) -> String:
	return TranslationServer.translate("GEN_PRESET_BOOL_YES" if bool(value) else "GEN_PRESET_BOOL_NO")


static func localized_param_value(param_key: String, entry: Dictionary) -> String:
	match param_key:
		"instrument":
			return localized_instrument(str(entry.get("instrument", "drums")))
		"mode":
			var intent := str(entry.get("intent", "")).strip_edges().to_lower()
			if intent in INTENT_ICONS:
				return localized_intent(intent)
			return localized_mode(str(entry.get("mode", "basic")))
		"lanes":
			return str(int(entry.get("lanes", 4)))
		"fill", "groove", "density", "grid_snap_strength", "genre_template_strength", "critic_strength":
			return str(int(entry.get(param_key, 0)))
		"accent_strong_beats", "enable_genre_detection", "use_stems_in_generation", "include_hi_hats", "groove_completion", "raw_adtof":
			return localized_bool(entry.get(param_key, false))
		_:
			return str(entry.get(param_key, ""))


static func entry_instrument_icon_key(instrument_id: String) -> String:
	return instrument_id if instrument_id in INSTRUMENT_ICONS else "drums"


static func fill_slot_chips(container: BoxContainer, entry: Dictionary) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
	if entry.is_empty():
		return
	container.add_theme_constant_override("separation", 12)
	var instrument_id := str(entry.get("instrument", "drums")).to_lower()
	var intent := str(entry.get("intent", "")).strip_edges().to_lower()
	var mode := str(entry.get("mode", "basic")).to_lower()
	var display_key := intent if intent in INTENT_ICONS else mode
	var lanes := int(entry.get("lanes", 4))
	var inst_icon_key := entry_instrument_icon_key(instrument_id)
	var inst_tint: Color = INSTRUMENT_ICON_COLORS.get(instrument_id, Color(0.38, 0.78, 0.74, 1.0))
	var tag_icon: String = INTENT_ICONS.get(display_key, MODE_ICONS.get(mode, "circle-check.svg"))
	var tag_tint: Color = INTENT_ICON_COLORS.get(display_key, MODE_ICON_COLORS.get(mode, Color(0.55, 0.78, 0.98, 1.0)))
	var tag_label := localized_intent(display_key) if display_key in INTENT_ICONS else localized_mode(mode)
	container.add_child(_make_slot_tag(
		_slot_label_letter(localized_instrument(instrument_id)),
		INSTRUMENT_ICONS.get(inst_icon_key, "drum.svg"),
		inst_tint,
	))
	container.add_child(_make_slot_tag(
		_slot_label_letter(tag_label),
		tag_icon,
		tag_tint,
	))
	container.add_child(_make_slot_tag(
		str(lanes),
		"layers.svg",
		Color(0.55, 0.72, 0.88, 1.0),
	))
	if mode == "custom":
		for param in _CUSTOM_SLOT_PARAMS:
			var entry_key: String = "grid_snap_strength" if param == "grid_snap" else param
			container.add_child(_make_value_chip(param, int(entry.get(entry_key, 0))))


static func fill_detail_rows(container: VBoxContainer, entry: Dictionary) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
	if entry.is_empty():
		return
	for row_spec in _DETAIL_ROWS:
		var param_key := str(row_spec.get("param", ""))
		var icon_key := str(row_spec.get("icon", param_key))
		if param_key == "instrument":
			icon_key = entry_instrument_icon_key(str(entry.get("instrument", "drums")))
		elif param_key == "mode":
			var intent := str(entry.get("intent", "")).strip_edges().to_lower()
			if intent in INTENT_ICONS:
				icon_key = intent
			else:
				icon_key = str(entry.get("mode", "basic")).to_lower()
		elif param_key == "lanes":
			icon_key = "lanes"
		container.add_child(_make_detail_row(
			str(row_spec.get("label_key", "")),
			localized_param_value(param_key, entry),
			icon_key,
		))


static func _slot_label_letter(localized: String) -> String:
	var text := localized.strip_edges()
	if text == "":
		return "?"
	return text.substr(0, 1).to_upper()


static func _make_slot_tag(text: String, icon_file: String, tint: Color, icon_px: int = 20) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", tint.lightened(0.08))
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)
	if icon_file.strip_edges() != "":
		row.add_child(UiIconHelper.make_texture_rect(
			UiIconHelper.load_tinted_icon(icon_file, tint, UiIconHelper.raster_size_for_display(icon_px)),
			icon_px,
		))
	return row


static func _make_value_chip(param_key: String, value: int) -> HBoxContainer:
	var icon_file: String = PARAM_ICONS.get(param_key, "")
	var tint: Color = PARAM_ICON_COLORS.get(param_key, Color(0.7, 0.8, 0.95, 1.0))
	return _make_slot_tag(str(value), icon_file, tint, 18)


static func _make_detail_row(label_key: String, value_text: String, icon_key: String) -> PanelContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 40)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.12, 0.17, 0.95)
	box.border_color = Color(1, 1, 1, 0.08)
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_left = 8.0
	box.content_margin_top = 6.0
	box.content_margin_right = 8.0
	box.content_margin_bottom = 6.0
	row.add_theme_stylebox_override("panel", box)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hbox)
	var icon_file := _resolve_icon_file(icon_key)
	var tint := _resolve_icon_tint(icon_key)
	if icon_file != "":
		hbox.add_child(UiIconHelper.make_icon_frame(icon_file, 36, 22, tint))
	var title := Label.new()
	title.text = TranslationServer.translate(label_key)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.62, 0.7, 0.82, 0.92))
	hbox.add_child(title)
	var value := Label.new()
	value.text = value_text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_size_override("font_size", 14)
	value.add_theme_color_override("font_color", Color(0.86, 0.92, 0.98, 0.98))
	hbox.add_child(value)
	return row


static func _resolve_icon_file(icon_key: String) -> String:
	var key := icon_key.strip_edges().to_lower()
	if key in INTENT_ICONS:
		return INTENT_ICONS[key]
	if key in MODE_ICONS:
		return MODE_ICONS[key]
	if key in INSTRUMENT_ICONS:
		return INSTRUMENT_ICONS[key]
	if key in PARAM_ICONS:
		return PARAM_ICONS[key]
	if key == "lanes":
		return "layers.svg"
	return ""


static func _resolve_icon_tint(icon_key: String) -> Color:
	var key := icon_key.strip_edges().to_lower()
	if key in INTENT_ICON_COLORS:
		return INTENT_ICON_COLORS[key]
	if key in MODE_ICON_COLORS:
		return MODE_ICON_COLORS[key]
	if key in INSTRUMENT_ICON_COLORS:
		return INSTRUMENT_ICON_COLORS[key]
	if key in PARAM_ICON_COLORS:
		return PARAM_ICON_COLORS[key]
	if key == "lanes":
		return Color(0.55, 0.72, 0.88, 1.0)
	return UiIconHelper.ACCENT
