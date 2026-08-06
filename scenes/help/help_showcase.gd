# scenes/help/help_showcase.gd
class_name HelpShowcase
extends PanelContainer

const _TrackMedals = preload("res://logic/domain/library/track_medals.gd")
const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const _RunModifierSections = preload("res://scenes/song_select/run_modifiers/run_modifier_sections.gd")
const _ChartDifficultyAnalyzer = preload("res://logic/domain/charts/chart_difficulty_analyzer.gd")
const _ChartDifficultyMeter = preload("res://logic/ui/chart_difficulty_meter.gd")
const _ProfileGenrePortrait = preload("res://logic/domain/profile/profile_genre_portrait.gd")
const _ProfileGenreMastery = preload("res://logic/domain/profile/profile_genre_mastery.gd")
const _GenreGroupIcons = preload("res://logic/domain/library/genre_group_icons.gd")

const _HelpTypography = preload("res://scenes/help/lib/help_typography.gd")
const _HealthBar = preload("res://scenes/game_screen/components/health_bar.gd")

const MEDAL_CELL_W := 132.0
const MEDAL_CELL_H := 104.0
const MOD_CELL_W := 132.0
const MOD_CELL_H := 104.0
const ICON_CELL_W := 148.0
const ICON_CELL_H := 108.0
const ICON_LABEL_H := 44.0
const SHOWCASE_ICON := 28.0
const SHOWCASE_ICON_FRAME := 44.0

const _GEN_PARAMS := [
	{"icon": "between-horizontal-start.svg", "color": Color(0.58, 0.78, 0.98, 1.0), "label": "GEN_FILL", "tip": "GEN_FILL_TOOLTIP"},
	{"icon": "heart-pulse.svg", "color": Color(0.95, 0.55, 0.62, 1.0), "label": "GEN_GROOVE", "tip": "GEN_GROOVE_TOOLTIP"},
	{"icon": "text-align-justify.svg", "color": Color(0.62, 0.72, 0.92, 1.0), "label": "GEN_DENSITY", "tip": "GEN_DENSITY_TOOLTIP"},
	{"icon": "magnet.svg", "color": Color(0.72, 0.62, 0.95, 1.0), "label": "GEN_GRID_SNAP", "tip": "GEN_GRID_SNAP_TOOLTIP"},
	{"icon": "tags.svg", "color": Color(0.55, 0.88, 0.72, 1.0), "label": "GEN_GENRE_TEMPLATE", "tip": "GEN_GENRE_TEMPLATE_TOOLTIP"},
	{"icon": "eraser.svg", "color": Color(0.88, 0.62, 0.58, 1.0), "label": "GEN_CRITIC_STRENGTH", "tip": "GEN_CRITIC_STRENGTH_TOOLTIP"},
	{"icon": "metronome.svg", "color": Color(0.98, 0.72, 0.42, 1.0), "label": "GEN_ACCENT_STRONG", "tip": "GEN_ACCENT_STRONG_TOOLTIP"},
	{"icon": "fingerprint-pattern.svg", "color": Color(0.58, 0.82, 0.96, 1.0), "label": "GEN_ENABLE_GENRE", "tip": "GEN_ENABLE_GENRE_TOOLTIP"},
	{"icon": "split.svg", "color": Color(0.68, 0.76, 0.98, 1.0), "label": "GEN_ENABLE_STEMS", "tip": "GEN_ENABLE_STEMS_TOOLTIP"},
	{"icon": "audio-lines.svg", "color": Color(0.72, 0.68, 0.95, 1.0), "label": "GEN_INCLUDE_HI_HATS", "tip": "GEN_INCLUDE_HI_HATS_TOOLTIP"},
	{"icon": "repeat.svg", "color": Color(0.95, 0.55, 0.62, 1.0), "label": "GEN_GROOVE_COMPLETION", "tip": "GEN_GROOVE_COMPLETION_TOOLTIP"},
	{"icon": "activity.svg", "color": Color(0.52, 0.88, 0.72, 1.0), "label": "GEN_RAW_ADTOF", "tip": "GEN_RAW_ADTOF_TOOLTIP"},
]

const _SHOP_ITEMS := [
	{"icon": "audio-lines.svg", "color": Color(0.52, 0.76, 0.92, 1.0), "label": "HELP_SHOWCASE_SHOP_SKINS", "tip": "HELP_SHOWCASE_SHOP_SKINS_TIP"},
	{"icon": "drum.svg", "color": Color(0.38, 0.78, 0.74, 1.0), "label": "HELP_SHOWCASE_SHOP_KICK", "tip": "HELP_SHOWCASE_SHOP_KICK_TIP"},
	{"icon": "between-horizontal-start.svg", "color": Color(0.62, 0.86, 0.72, 1.0), "label": "HELP_SHOWCASE_SHOP_LANE", "tip": "HELP_SHOWCASE_SHOP_LANE_TIP"},
	{"icon": "sparkles.svg", "color": Color(0.98, 0.64, 0.31, 1.0), "label": "HELP_SHOWCASE_SHOP_PARTICLES", "tip": "HELP_SHOWCASE_SHOP_PARTICLES_TIP"},
]

const _UNLOCK_METHODS := [
	{"icon": "diamond.svg", "color": Color(0.62, 0.86, 0.72, 1.0), "label": "HELP_SHOWCASE_UNLOCK_CURRENCY", "tip": "HELP_SHOWCASE_UNLOCK_CURRENCY_TIP"},
	{"icon": "trophy.svg", "color": Color(0.98, 0.64, 0.31, 1.0), "label": "HELP_SHOWCASE_UNLOCK_ACH", "tip": "HELP_SHOWCASE_UNLOCK_ACH_TIP"},
	{"icon": "gauge.svg", "color": Color(0.66, 0.58, 0.86, 1.0), "label": "HELP_SHOWCASE_UNLOCK_LEVEL", "tip": "HELP_SHOWCASE_UNLOCK_LEVEL_TIP"},
	{"icon": "list-checks.svg", "color": Color(0.8, 0.86, 0.94, 1.0), "label": "HELP_SHOWCASE_UNLOCK_DAILY", "tip": "HELP_SHOWCASE_UNLOCK_DAILY_TIP"},
	{"icon": "flag.svg", "color": Color(0.38, 0.78, 0.74, 1.0), "label": "HELP_SHOWCASE_UNLOCK_MEDALS", "tip": "HELP_SHOWCASE_UNLOCK_MEDALS_TIP"},
]

const _PROGRESS_XP := [
	{"icon": "circle-play.svg", "color": Color(0.38, 0.78, 0.74, 1.0), "label": "HELP_SHOWCASE_XP_PLAY", "tip": "HELP_SHOWCASE_XP_PLAY_TIP"},
	{"icon": "sparkles.svg", "color": Color(0.66, 0.58, 0.86, 1.0), "label": "HELP_SHOWCASE_XP_GAIN", "tip": "HELP_SHOWCASE_XP_GAIN_TIP"},
	{"icon": "gauge.svg", "color": Color(0.66, 0.58, 0.86, 1.0), "label": "HELP_SHOWCASE_XP_LEVEL", "tip": "HELP_SHOWCASE_XP_LEVEL_TIP"},
]

const _PROGRESS_CURRENCY := [
	{"icon": "music.svg", "color": Color(0.42, 0.57, 0.82, 1.0), "label": "HELP_SHOWCASE_CUR_SONGS", "tip": "HELP_SHOWCASE_CUR_SONGS_TIP"},
	{"icon": "list-checks.svg", "color": Color(0.8, 0.86, 0.94, 1.0), "label": "HELP_SHOWCASE_CUR_DAILY", "tip": "HELP_SHOWCASE_CUR_DAILY_TIP"},
	{"icon": "diamond.svg", "color": Color(0.62, 0.86, 0.72, 1.0), "label": "HELP_SHOWCASE_CUR_SPEND", "tip": "HELP_SHOWCASE_CUR_SPEND_TIP"},
]

const _MOD_SIDEBAR_TABS := [
	{"icon": "layout-dashboard.svg", "color": Color(0.95, 0.82, 0.45, 1.0), "label": "MOD_TAB_OVERVIEW", "tip": "HELP_SHOWCASE_MOD_TAB_OVERVIEW_TIP"},
	{"icon": "feather.svg", "color": Color(0.42, 0.88, 0.58, 1.0), "label": "MOD_CAT_EASING", "tip": "HELP_SHOWCASE_MOD_TAB_EASING_TIP"},
	{"icon": "flame_gen.svg", "color": Color(0.95, 0.45, 0.42, 1.0), "label": "MOD_CAT_HARDENING", "tip": "HELP_SHOWCASE_MOD_TAB_HARDENING_TIP"},
	{"icon": "wrench.svg", "color": Color(0.42, 0.72, 0.96, 1.0), "label": "MOD_CAT_SPECIAL", "tip": "HELP_SHOWCASE_MOD_TAB_SPECIAL_TIP"},
	{"icon": "rhythmdna.svg", "color": UiIconHelper.ACCENT_DNA, "label": "MOD_CAT_DNA", "tip": "HELP_SHOWCASE_MOD_TAB_DNA_TIP"},
]

const _CHART_FILES := [
	{
		"raster_path": "res://assets/app_icons/rf_128.png",
		"color": Color(0.55, 0.78, 0.98, 1.0),
		"label": "HELP_SHOWCASE_CHART_RF",
		"tip": "HELP_SHOWCASE_CHART_RF_TIP",
		"icon_px": 48.0,
	},
	{
		"raster_path": "res://assets/app_icons/rfd_128.png",
		"color": UiIconHelper.ACCENT_DNA,
		"label": "HELP_SHOWCASE_CHART_RFD",
		"tip": "HELP_SHOWCASE_CHART_RFD_TIP",
		"icon_px": 48.0,
	},
	{
		"raster_path": "res://assets/app_icons/rfr_128.png",
		"color": Color(0.45, 0.78, 0.98, 1.0),
		"label": "HELP_SHOWCASE_CHART_RFR",
		"tip": "HELP_SHOWCASE_CHART_RFR_TIP",
		"icon_px": 48.0,
	},
	{
		"icon": "music.svg",
		"color": Color(0.62, 0.86, 0.72, 1.0),
		"label": "HELP_SHOWCASE_CHART_AUDIO",
		"tip": "HELP_SHOWCASE_CHART_AUDIO_TIP",
	},
]

const GENRE_DEMO_CELL_W := 216.0
const GENRE_DEMO_CELL_H := 118.0

const _GENRE_DEMO := [
	{"group_id": "electronic", "plays": 31, "discovered": 12, "catalog": 18},
	{"group_id": "rock", "plays": 0, "discovered": 0, "catalog": 22},
]

const _MOD_DNA_GROUPS := [
	{"icon": "layers.svg", "color": UiIconHelper.ACCENT_DNA, "label": "MOD_SUBCAT_DNA_STRUCTURE", "tip": "HELP_SHOWCASE_MOD_DNA_STRUCTURE_TIP"},
	{"icon": "activity.svg", "color": UiIconHelper.ACCENT_DNA, "label": "MOD_SUBCAT_DNA_PULSE", "tip": "HELP_SHOWCASE_MOD_DNA_PULSE_TIP"},
	{"icon": "target.svg", "color": UiIconHelper.ACCENT_DNA, "label": "MOD_SUBCAT_DNA_FOCUS", "tip": "HELP_SHOWCASE_MOD_DNA_FOCUS_TIP"},
	{"icon": "repeat.svg", "color": UiIconHelper.ACCENT_DNA, "label": "MOD_SUBCAT_DNA_BEHAVIOR", "tip": "HELP_SHOWCASE_MOD_DNA_BEHAVIOR_TIP"},
]

const _GEN_GOALS := [
	{"icon": "audio-lines.svg", "color": Color(0.52, 0.88, 0.72, 1.0), "label": "GEN_GOAL_ORIGINAL", "tip": "GEN_GOAL_DESC_ORIGINAL"},
	{"icon": "gamepad-2.svg", "color": Color(0.45, 0.62, 0.92, 1.0), "label": "GEN_GOAL_ARCADE", "tip": "GEN_GOAL_DESC_ARCADE"},
]

const _PROFILE_TABS := [
	{"icon": "layout-dashboard.svg", "color": Color(0.66, 0.58, 0.86, 1.0), "label": "HELP_SHOWCASE_PTAB_OVERVIEW", "tip": "HELP_SHOWCASE_PTAB_OVERVIEW_TIP"},
	{"icon": "chart-column.svg", "color": Color(0.52, 0.76, 0.92, 1.0), "label": "HELP_SHOWCASE_PTAB_STATS", "tip": "HELP_SHOWCASE_PTAB_STATS_TIP"},
	{"icon": "music.svg", "color": Color(0.62, 0.86, 0.72, 1.0), "label": "HELP_SHOWCASE_PTAB_GENRES", "tip": "HELP_SHOWCASE_PTAB_GENRES_TIP"},
	{"icon": "trophy.svg", "color": Color(0.98, 0.64, 0.31, 1.0), "label": "HELP_SHOWCASE_PTAB_RECORDS", "tip": "HELP_SHOWCASE_PTAB_RECORDS_TIP"},
]

const _ACH_CATS := [
	{"icon": "list-checks.svg", "color": Color(0.62, 0.86, 0.72, 1.0), "label": "HELP_SHOWCASE_ACH_MODS", "tip": "HELP_SHOWCASE_ACH_MODS_TIP"},
	{"icon": "flag.svg", "color": Color(0.38, 0.78, 0.74, 1.0), "label": "HELP_SHOWCASE_ACH_MEDALS", "tip": "HELP_SHOWCASE_ACH_MEDALS_TIP"},
	{"icon": "flame_gen.svg", "color": Color(0.95, 0.45, 0.42, 1.0), "label": "HELP_SHOWCASE_ACH_HARD", "tip": "HELP_SHOWCASE_ACH_HARD_TIP"},
	{"icon": "music.svg", "color": Color(0.66, 0.58, 0.86, 1.0), "label": "HELP_SHOWCASE_ACH_GENRES", "tip": "HELP_SHOWCASE_ACH_GENRES_TIP"},
	{"icon": "gauge.svg", "color": Color(0.98, 0.64, 0.31, 1.0), "label": "HELP_SHOWCASE_ACH_RR", "tip": "HELP_SHOWCASE_ACH_RR_TIP"},
]

const _DAILY_QUESTS := [
	{"icon": "target.svg", "color": Color(0.52, 0.76, 0.92, 1.0), "label": "HELP_SHOWCASE_DAILY_COMBO", "tip": "HELP_SHOWCASE_DAILY_COMBO_TIP"},
	{"icon": "music.svg", "color": Color(0.62, 0.86, 0.72, 1.0), "label": "HELP_SHOWCASE_DAILY_PLAY", "tip": "HELP_SHOWCASE_DAILY_PLAY_TIP"},
	{"icon": "diamond.svg", "color": Color(0.98, 0.64, 0.31, 1.0), "label": "HELP_SHOWCASE_DAILY_REWARD", "tip": "HELP_SHOWCASE_DAILY_REWARD_TIP"},
]

const _STEMS := [
	{"icon": "audio-lines.svg", "color": Color(0.72, 0.68, 0.95, 1.0), "label": "HELP_SHOWCASE_STEM_MIX", "tip": "HELP_SHOWCASE_STEM_MIX_TIP"},
	{"icon": "split.svg", "color": Color(0.52, 0.76, 0.92, 1.0), "label": "HELP_SHOWCASE_STEM_SPLIT", "tip": "HELP_SHOWCASE_STEM_SPLIT_TIP"},
	{"icon": "drum.svg", "color": Color(0.38, 0.78, 0.74, 1.0), "label": "HELP_SHOWCASE_STEM_DRUMS", "tip": "HELP_SHOWCASE_STEM_DRUMS_TIP"},
]

const _COLOR_PERFECT := Color(1.0, 1.0, 0.0, 1.0)
const _COLOR_GOOD := Color(0.0, 0.85, 0.9, 1.0)
const _COLOR_MISS := Color(0.85, 0.3, 0.34, 1.0)
const _COLOR_RR := Color(0.9490196, 0.7019608, 0.3529412, 1.0)

const _HEIGHT_BY_KIND := {
	"chart_difficulty": 390.0,
	"track_medals": 300.0,
	"modifiers": 680.0,
	"mod_screen": 220.0,
	"mod_conflicts": 340.0,
	"chart_files": 240.0,
	"genre_mastery": 260.0,
	"gen_advanced": 430.0,
	"shop_categories": 260.0,
	"progress_unlocks": 220.0,
	"progress_xp": 200.0,
	"progress_currency": 200.0,
	"gen_modes": 360.0,
	"profile_tabs": 280.0,
	"achievement_categories": 300.0,
	"daily_quests": 200.0,
	"stems": 200.0,
	"scoring": 320.0,
	"rhythm_rating": 230.0,
	"health_bar": 300.0,
	"hit_window": 300.0,
	"keyboard_nav": 400.0,
	"note_speed": 200.0,
}

var _wrap_labels: Array[Label] = []
var _kind := ""
var _layout_width := 0.0
var _setup_params: Dictionary = {}
static var _tint_icon_cache: Dictionary = {}


func _ty(label: Label, size: int, color: Color = _HelpTypography.COLOR_BODY) -> void:
	_HelpTypography.apply_label(label, size, color)


func setup(kind: String, params: Dictionary = {}) -> void:
	_kind = kind.strip_edges()
	_setup_params = params if params is Dictionary else {}
	_layout_width = 0.0
	custom_minimum_size = Vector2.ZERO
	_clear_body()
	_wrap_labels.clear()
	match _kind:
		"chart_difficulty":
			var base_decimal := float(str(params.get("base", "7.3")))
			var mods_decimal := float(str(params.get("mods", "11.2")))
			if base_decimal <= 0.0:
				base_decimal = 7.3
			if mods_decimal <= base_decimal:
				mods_decimal = 11.2
			_build_chart_difficulty(base_decimal, mods_decimal)
		"track_medals":
			_build_track_medals()
		"modifiers":
			_build_modifiers()
		"mod_screen":
			_build_mod_screen()
		"mod_conflicts":
			_build_mod_conflicts()
		"chart_files":
			_build_chart_files()
		"genre_mastery":
			_build_genre_mastery()
		"gen_advanced":
			_build_gen_advanced()
		"shop_categories":
			_build_shop_categories()
		"progress_unlocks":
			_build_progress_unlocks()
		"progress_xp":
			_build_icon_row_showcase("HELP_SHOWCASE_XP_TITLE", "HELP_SHOWCASE_XP_CAPTION", _PROGRESS_XP)
		"progress_currency":
			_build_icon_row_showcase("HELP_SHOWCASE_CURRENCY_TITLE", "HELP_SHOWCASE_CURRENCY_CAPTION", _PROGRESS_CURRENCY)
		"gen_modes":
			_build_gen_modes()
		"profile_tabs":
			_build_icon_row_showcase("HELP_SHOWCASE_PTABS_TITLE", "HELP_SHOWCASE_PTABS_CAPTION", _PROFILE_TABS)
		"achievement_categories":
			_build_icon_row_showcase("HELP_SHOWCASE_ACH_TITLE", "HELP_SHOWCASE_ACH_CAPTION", _ACH_CATS)
		"daily_quests":
			_build_icon_row_showcase("HELP_SHOWCASE_DAILY_TITLE", "HELP_SHOWCASE_DAILY_CAPTION", _DAILY_QUESTS)
		"stems":
			_build_icon_row_showcase("HELP_SHOWCASE_STEMS_TITLE", "HELP_SHOWCASE_STEMS_CAPTION", _STEMS)
		"scoring":
			_build_scoring()
		"rhythm_rating":
			_build_rhythm_rating()
		"health_bar":
			_build_health_bar()
		"hit_window":
			_build_hit_window()
		"keyboard_nav":
			_build_keyboard_nav()
		"note_speed":
			_build_note_speed()
		_:
			visible = false
	call_deferred("_finish_layout_lock", 0.0)


func _apply_layout_lock(width: float) -> void:
	_lock_bounds(_measure_content_height())
	var wrap_w := width if width > 0.0 else _layout_width
	if wrap_w > 0.0:
		for label in _wrap_labels:
			if is_instance_valid(label):
				label.custom_minimum_size.x = 0.0
				label.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _finish_layout_lock(width: float) -> void:
	if not is_instance_valid(self):
		return
	_apply_layout_lock(width)


func apply_content_width(width: float) -> void:
	_layout_width = clampf(width, 280.0, 640.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size.x = 0.0
	_sync_flow_container_widths(self, _layout_width)
	call_deferred("_finish_layout_lock", _layout_width)


func _sync_flow_container_widths(node: Node, width: float) -> void:
	if node is FlowContainer:
		(node as FlowContainer).custom_minimum_size.x = width
	for child in node.get_children():
		_sync_flow_container_widths(child, width)


func _measure_content_height() -> float:
	var fallback := float(_HEIGHT_BY_KIND.get(_kind, 120.0))
	if get_child_count() == 0:
		return fallback
	_refresh_minimum_sizes(self)
	var measured := get_combined_minimum_size().y
	if measured <= 1.0:
		for child in get_children():
			if child is Control:
				measured = maxf(measured, (child as Control).get_combined_minimum_size().y)
	if measured <= 1.0:
		return fallback
	return maxf(measured + 6.0, 80.0)


func _refresh_minimum_sizes(node: Node) -> void:
	if node is Control:
		(node as Control).update_minimum_size()
	for child in node.get_children():
		_refresh_minimum_sizes(child)


func _lock_bounds(height: float) -> void:
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	size_flags_stretch_ratio = 0.0
	clip_contents = false
	custom_minimum_size = Vector2(0.0, maxf(height, 1.0))
	update_minimum_size()


func _clear_body() -> void:
	custom_minimum_size = Vector2.ZERO
	update_minimum_size()
	for child in get_children():
		remove_child(child)
		child.queue_free()


func _apply_shell_style() -> void:
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(12)
	box.content_margin_left = 4.0
	box.content_margin_right = 4.0
	box.content_margin_top = 4.0
	box.content_margin_bottom = 4.0
	box.bg_color = Color(0.08, 0.09, 0.13, 0.72)
	box.set_border_width_all(1)
	box.border_color = Color(1, 1, 1, 0.08)
	add_theme_stylebox_override("panel", box)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	clip_contents = true


func _content_root() -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(box)
	return box


func _track_wrap_label(label: Label) -> Label:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_wrap_labels.append(label)
	return label


func _shrink(control: Control) -> Control:
	control.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return control


func _tinted_icon(file_name: String, accent: Color) -> Texture2D:
	if file_name.strip_edges() == "":
		return null
	var cache_key := "%s|%.3f|%.3f|%.3f" % [file_name, accent.r, accent.g, accent.b]
	if _tint_icon_cache.has(cache_key):
		return _tint_icon_cache[cache_key]
	var tex := UiIconHelper.load_tinted_icon(file_name, accent)
	if tex:
		_tint_icon_cache[cache_key] = tex
	return tex


func _build_chart_difficulty(base_decimal: float, mods_decimal: float) -> void:
	_apply_shell_style()
	var root := _content_root()
	var vbox := _shrink(VBoxContainer.new()) as VBoxContainer
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	root.add_child(vbox)

	var title := _shrink(Label.new()) as Label
	title.text = tr("HELP_SHOWCASE_CHART_DIFFICULTY_TITLE")
	_ty(title, _HelpTypography.SIZE_SUBTITLE, _HelpTypography.COLOR_DIM)
	vbox.add_child(title)

	vbox.add_child(_make_chart_difficulty_example(
		"HELP_SHOWCASE_CHART_DIFFICULTY_BASE_LABEL",
		base_decimal,
		false,
	))
	vbox.add_child(_make_chart_difficulty_example(
		"HELP_SHOWCASE_CHART_DIFFICULTY_MODS_LABEL",
		mods_decimal,
		true,
	))

	var caption := _track_wrap_label(Label.new())
	caption.text = tr("HELP_SHOWCASE_CHART_DIFFICULTY_CAPTION")
	_ty(caption, _HelpTypography.SIZE_CAPTION, _HelpTypography.COLOR_MUTED)
	vbox.add_child(caption)

	var tiers := _shrink(HBoxContainer.new()) as HBoxContainer
	tiers.alignment = BoxContainer.ALIGNMENT_CENTER
	tiers.add_theme_constant_override("separation", 6)
	vbox.add_child(tiers)
	for sample in [2, 4, 6, 8, 10]:
		tiers.add_child(_make_tier_chip(sample))


func _make_chart_difficulty_example(label_key: String, decimal: float, is_mod_boost: bool) -> VBoxContainer:
	var block := _shrink(VBoxContainer.new()) as VBoxContainer
	block.add_theme_constant_override("separation", 6)

	var row_label := _shrink(Label.new()) as Label
	row_label.text = tr(label_key)
	row_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ty(row_label, _HelpTypography.SIZE_SMALL, _HelpTypography.COLOR_MUTED)
	block.add_child(row_label)

	var row := _shrink(HBoxContainer.new()) as HBoxContainer
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	block.add_child(row)

	var tier_color := _ChartDifficultyAnalyzer.rating_color_for_decimal(decimal)
	var meter := _ChartDifficultyMeter.new()
	meter.set_decimal_rating(
		minf(decimal, float(_ChartDifficultyAnalyzer.MAX_RATING)),
		tier_color,
	)
	row.add_child(meter)

	var rating_label := _shrink(Label.new()) as Label
	rating_label.text = _ChartDifficultyAnalyzer.format_decimal_rating(decimal, true)
	_ty(rating_label, _HelpTypography.SIZE_DISPLAY if is_mod_boost else 26)
	rating_label.add_theme_color_override("font_color", tier_color)
	row.add_child(rating_label)

	if is_mod_boost:
		var overflow := maxf(0.0, decimal - float(_ChartDifficultyAnalyzer.MAX_RATING))
		if overflow > 0.05:
			var overflow_label := _shrink(Label.new()) as Label
			overflow_label.text = tr("SONG_TOOLTIP_CHART_DIFFICULTY_OVERFLOW_FMT") % snappedf(overflow, 0.1)
			_ty(overflow_label, _HelpTypography.SIZE_SUBTITLE)
			overflow_label.add_theme_color_override("font_color", Color(0.98, 0.72, 0.42, 1.0))
			row.add_child(overflow_label)

	return block


func _make_tier_chip(rating: int) -> PanelContainer:
	var color := _ChartDifficultyAnalyzer.rating_color(rating)
	var chip := _shrink(PanelContainer.new()) as PanelContainer
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(8)
	box.bg_color = Color(color.r, color.g, color.b, 0.14)
	box.set_border_width_all(1)
	box.border_color = Color(color.r, color.g, color.b, 0.38)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	chip.add_theme_stylebox_override("panel", box)
	var label := _shrink(Label.new()) as Label
	label.text = str(rating)
	_ty(label, _HelpTypography.SIZE_SMALL, color)
	chip.add_child(label)
	chip.tooltip_text = _ChartDifficultyAnalyzer.format_rating(rating)
	return chip


func _build_track_medals() -> void:
	_apply_shell_style()
	var root := _content_root()
	var vbox := _shrink(VBoxContainer.new()) as VBoxContainer
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	root.add_child(vbox)

	var title := _shrink(Label.new()) as Label
	title.text = tr("HELP_SHOWCASE_TRACK_MEDALS_TITLE")
	_ty(title, _HelpTypography.SIZE_SUBTITLE, _HelpTypography.COLOR_DIM)
	vbox.add_child(title)

	var rows := _shrink(VBoxContainer.new()) as VBoxContainer
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.add_theme_constant_override("separation", 8)
	vbox.add_child(rows)

	for row_start in [0, 4]:
		var row := _shrink(HBoxContainer.new()) as HBoxContainer
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		rows.add_child(row)
		for i in range(4):
			row.add_child(_make_medal_cell(_TrackMedals.ALL_IDS[row_start + i]))

	var caption := _track_wrap_label(Label.new())
	caption.text = tr("HELP_SHOWCASE_TRACK_MEDALS_CAPTION")
	_ty(caption, _HelpTypography.SIZE_CAPTION, _HelpTypography.COLOR_MUTED)
	vbox.add_child(caption)


func _make_medal_cell(medal_id: String) -> PanelContainer:
	var accent := Color(0.38, 0.78, 0.74, 1.0)
	var card := _shrink(PanelContainer.new()) as PanelContainer
	card.custom_minimum_size = Vector2(MEDAL_CELL_W, MEDAL_CELL_H)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(10)
	box.bg_color = Color(accent.r, accent.g, accent.b, 0.1)
	box.set_border_width_all(1)
	box.border_color = Color(accent.r, accent.g, accent.b, 0.28)
	box.content_margin_left = 4.0
	box.content_margin_right = 4.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 4.0
	card.add_theme_stylebox_override("panel", box)

	var vbox := _shrink(VBoxContainer.new()) as VBoxContainer
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var icon := _shrink(TextureRect.new()) as TextureRect
	icon.custom_minimum_size = Vector2(SHOWCASE_ICON, SHOWCASE_ICON)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _tinted_icon(_TrackMedals.icon_path(medal_id).get_file(), accent)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon)

	var label := _shrink(Label.new()) as Label
	label.text = tr(_TrackMedals.abbr_i18n_key(medal_id))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ty(label, _HelpTypography.SIZE_SMALL, Color(0.88, 0.91, 0.96, 1.0))
	vbox.add_child(label)

	card.tooltip_text = "%s — %s" % [
		tr(_TrackMedals.title_i18n_key(medal_id)),
		tr(_TrackMedals.desc_i18n_key(medal_id)),
	]
	return card


func _build_modifiers() -> void:
	_apply_shell_style()
	var root := _content_root()
	var vbox := _shrink(VBoxContainer.new()) as VBoxContainer
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	root.add_child(vbox)

	var title := _shrink(Label.new()) as Label
	title.text = tr("HELP_SHOWCASE_MODIFIERS_TITLE")
	_ty(title, _HelpTypography.SIZE_SUBTITLE, _HelpTypography.COLOR_DIM)
	vbox.add_child(title)

	for group in _modifier_showcase_groups(_setup_params):
		var ids: Array = group.get("ids", [])
		if ids.is_empty():
			continue
		var section_title := str(group.get("title", ""))
		if section_title.strip_edges() != "":
			_add_modifier_group(
				vbox,
				section_title,
				group.get("accent", UiIconHelper.ACCENT) as Color,
				ids,
			)
		else:
			_add_modifier_flow(
				vbox,
				group.get("accent", UiIconHelper.ACCENT) as Color,
				ids,
			)

	var caption := _track_wrap_label(Label.new())
	caption.text = tr("HELP_SHOWCASE_MODIFIERS_CAPTION")
	_ty(caption, _HelpTypography.SIZE_CAPTION, _HelpTypography.COLOR_MUTED)
	vbox.add_child(caption)


func _build_chart_files() -> void:
	_apply_shell_style()
	var root := _content_root()
	var vbox := _shrink(VBoxContainer.new()) as VBoxContainer
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	root.add_child(vbox)
	_add_showcase_header(vbox, "HELP_SHOWCASE_CHART_FILES_TITLE", "HELP_SHOWCASE_CHART_FILES_CAPTION")
	_add_icon_row(vbox, _CHART_FILES, 128.0)


func _build_genre_mastery() -> void:
	_apply_shell_style()
	var root := _content_root()
	var vbox := _shrink(VBoxContainer.new()) as VBoxContainer
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	root.add_child(vbox)
	_add_showcase_header(vbox, "HELP_SHOWCASE_GENRE_TITLE", "")

	var flow := _shrink(FlowContainer.new()) as FlowContainer
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	if _layout_width > 0.0:
		flow.custom_minimum_size.x = _layout_width
	vbox.add_child(flow)
	for demo in _GENRE_DEMO:
		flow.add_child(_make_genre_demo_cell(demo))

	var caption := _track_wrap_label(Label.new())
	caption.text = tr("HELP_SHOWCASE_GENRE_CAPTION")
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ty(caption, _HelpTypography.SIZE_CAPTION, _HelpTypography.COLOR_MUTED)
	vbox.add_child(caption)


func _make_genre_demo_cell(demo: Dictionary) -> PanelContainer:
	var group_id := str(demo.get("group_id", ""))
	var plays := int(demo.get("plays", 0))
	var discovered := int(demo.get("discovered", 0))
	var catalog := int(demo.get("catalog", 0))
	var level := _ProfileGenreMastery.level_from_plays(plays)
	var locked := level <= 0
	var accent: Color = _ProfileGenreMastery.level_accent_color(level)
	var progress: Dictionary = _ProfileGenreMastery.progress_to_next_level(plays)

	var card := _shrink(PanelContainer.new()) as PanelContainer
	card.custom_minimum_size = Vector2(GENRE_DEMO_CELL_W, GENRE_DEMO_CELL_H)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(10)
	box.bg_color = Color(accent.r, accent.g, accent.b, 0.08 if locked else 0.12)
	box.set_border_width_all(1)
	box.border_color = Color(accent.r, accent.g, accent.b, 0.24 if locked else 0.4)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	card.add_theme_stylebox_override("panel", box)

	var vbox := _shrink(VBoxContainer.new()) as VBoxContainer
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	var header := _shrink(HBoxContainer.new()) as HBoxContainer
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)
	var icon_tint := accent if not locked else Color(0.42, 0.44, 0.5, 0.9)
	header.add_child(_GenreGroupIcons.make_icon_frame_for_group(group_id, icon_tint, 32, 17, false))

	var name_label := _shrink(Label.new()) as Label
	name_label.text = tr(_ProfileGenrePortrait.group_locale_key(group_id))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ty(
		name_label,
		_HelpTypography.SIZE_SMALL,
		Color(0.88, 0.91, 0.96, 1.0) if not locked else Color(0.6, 0.63, 0.7, 0.95),
	)
	header.add_child(name_label)

	var level_label := _shrink(Label.new()) as Label
	if level >= _ProfileGenreMastery.MAX_LEVEL:
		level_label.text = tr("PROFILE_GENRE_LEVEL_MAX")
	elif locked:
		level_label.text = tr("HELP_SHOWCASE_GENRE_LOCKED")
	else:
		level_label.text = tr("PROFILE_GENRE_LEVEL_FMT") % level
	_ty(level_label, _HelpTypography.SIZE_SMALL, accent)
	header.add_child(level_label)

	var bar := _shrink(ProgressBar.new()) as ProgressBar
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0.0, 8.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = float(progress.get("ratio", 0.0))
	var bar_bg := StyleBoxFlat.new()
	bar_bg.set_corner_radius_all(4)
	bar_bg.bg_color = Color(1, 1, 1, 0.08)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.set_corner_radius_all(4)
	bar_fill.bg_color = accent
	bar.add_theme_stylebox_override("background", bar_bg)
	bar.add_theme_stylebox_override("fill", bar_fill)
	vbox.add_child(bar)

	var meta := _shrink(Label.new()) as Label
	meta.text = tr("PROFILE_GENRE_GROUP_COUNT_FMT") % [discovered, catalog]
	_ty(meta, _HelpTypography.SIZE_MICRO, Color(0.7, 0.75, 0.84, 0.95))
	vbox.add_child(meta)

	card.tooltip_text = tr("HELP_SHOWCASE_GENRE_CELL_TIP")
	return card


func _modifier_showcase_groups(params: Dictionary) -> Array:
	var ids_param := str(params.get("ids", "")).strip_edges()
	if ids_param != "":
		var ids: Array = []
		for raw_id in ids_param.split(",", false):
			var sid := str(raw_id).strip_edges()
			if sid != "" and sid in _RunModifiers.ALL_IDS:
				ids.append(sid)
		return [{"title": "", "accent": UiIconHelper.ACCENT, "ids": ids}]
	var category := str(params.get("category", "")).strip_edges()
	if category != "":
		return _modifier_groups_for_category(category, str(params.get("subsection", "")).strip_edges())
	return [
		{
			"title": tr("MOD_CAT_EASING"),
			"accent": Color(0.62, 0.86, 0.72, 1.0),
			"ids": _RunModifiers.EASING_IDS,
		},
		{
			"title": tr("MOD_CAT_HARDENING"),
			"accent": Color(0.98, 0.5, 0.48, 1.0),
			"ids": _RunModifiers.HARDENING_IDS,
		},
		{
			"title": tr("MOD_CAT_SPECIAL"),
			"accent": Color(0.66, 0.58, 0.86, 1.0),
			"ids": _RunModifiers.SPECIAL_IDS,
		},
		{
			"title": tr("MOD_CAT_DNA"),
			"accent": UiIconHelper.ACCENT_DNA,
			"ids": _RunModifiers.DNA_IDS,
		},
	]


func _modifier_groups_for_category(category: String, subsection: String) -> Array:
	match category:
		"easing":
			return [_modifier_group_entry(tr("MOD_CAT_EASING"), Color(0.62, 0.86, 0.72, 1.0), _RunModifiers.EASING_IDS)]
		"hardening":
			if subsection != "":
				var hard_ids := _modifier_ids_from_specs(_hard_subsection_specs(subsection))
				return [_modifier_group_entry(_hard_subsection_title(subsection), Color(0.98, 0.5, 0.48, 1.0), hard_ids)]
			return [_modifier_group_entry(tr("MOD_CAT_HARDENING"), Color(0.98, 0.5, 0.48, 1.0), _RunModifiers.HARDENING_IDS)]
		"special":
			if subsection != "":
				var spec_ids := _modifier_ids_from_specs(_special_subsection_specs(subsection))
				return [_modifier_group_entry(_special_subsection_title(subsection), Color(0.66, 0.58, 0.86, 1.0), spec_ids)]
			return [_modifier_group_entry(tr("MOD_CAT_SPECIAL"), Color(0.42, 0.72, 0.96, 1.0), _RunModifiers.SPECIAL_IDS)]
		"dna":
			if subsection != "":
				var dna_ids := _modifier_ids_from_specs(_dna_subsection_specs(subsection))
				return [_modifier_group_entry(_dna_subsection_title(subsection), UiIconHelper.ACCENT_DNA, dna_ids)]
			return [_modifier_group_entry(tr("MOD_CAT_DNA"), UiIconHelper.ACCENT_DNA, _RunModifiers.DNA_IDS)]
		_:
			return []


func _modifier_group_entry(title: String, accent: Color, ids: Array) -> Dictionary:
	return {"title": title, "accent": accent, "ids": ids}


func _modifier_ids_from_specs(specs: Array) -> Array:
	var out: Array = []
	for spec in specs:
		if spec is Array and spec.size() > 0:
			out.append(str(spec[0]))
	return out


func _hard_subsection_specs(key: String) -> Array:
	match key:
		"speed":
			return _RunModifierSections.HARD_SPEED
		"timing":
			return _RunModifierSections.HARD_TIMING
		"visibility":
			return _RunModifierSections.HARD_VISIBILITY
		"lanes":
			return _RunModifierSections.HARD_LANES
		"audio":
			return _RunModifierSections.HARD_AUDIO
		_:
			return []


func _hard_subsection_title(key: String) -> String:
	match key:
		"speed":
			return tr("MOD_SUBCAT_HARD_SPEED")
		"timing":
			return tr("MOD_SUBCAT_HARD_TIMING")
		"visibility":
			return tr("MOD_SUBCAT_HARD_VISIBILITY")
		"lanes":
			return tr("MOD_SUBCAT_HARD_LANES")
		"audio":
			return tr("MOD_SUBCAT_HARD_AUDIO")
		_:
			return tr("MOD_CAT_HARDENING")


func _special_subsection_specs(key: String) -> Array:
	match key:
		"lanes":
			return _RunModifierSections.SPECIAL_LANES
		"scroll":
			return _RunModifierSections.SPECIAL_SCROLL
		"input":
			return _RunModifierSections.SPECIAL_INPUT
		"chaos":
			return _RunModifierSections.SPECIAL_CHAOS
		"audio":
			return _RunModifierSections.SPECIAL_AUDIO
		_:
			return []


func _special_subsection_title(key: String) -> String:
	match key:
		"lanes":
			return tr("MOD_SUBCAT_SPECIAL_LANES")
		"scroll":
			return tr("MOD_SUBCAT_SPECIAL_SCROLL")
		"input":
			return tr("MOD_SUBCAT_SPECIAL_INPUT")
		"chaos":
			return tr("MOD_SUBCAT_SPECIAL_CHAOS")
		"audio":
			return tr("MOD_SUBCAT_SPECIAL_AUDIO")
		_:
			return tr("MOD_CAT_SPECIAL")


func _dna_subsection_specs(key: String) -> Array:
	match key:
		"structure":
			return _RunModifierSections.DNA_STRUCTURE
		"pulse":
			return _RunModifierSections.DNA_PULSE
		"focus":
			return _RunModifierSections.DNA_FOCUS
		"behavior":
			return _RunModifierSections.DNA_BEHAVIOR
		_:
			return []


func _dna_subsection_title(key: String) -> String:
	match key:
		"structure":
			return tr("MOD_SUBCAT_DNA_STRUCTURE")
		"pulse":
			return tr("MOD_SUBCAT_DNA_PULSE")
		"focus":
			return tr("MOD_SUBCAT_DNA_FOCUS")
		"behavior":
			return tr("MOD_SUBCAT_DNA_BEHAVIOR")
		_:
			return tr("MOD_CAT_DNA")


func _build_mod_screen() -> void:
	_apply_shell_style()
	var root := _content_root()
	var vbox := _shrink(VBoxContainer.new()) as VBoxContainer
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	root.add_child(vbox)
	_add_showcase_header(vbox, "HELP_SHOWCASE_MOD_SCREEN_TITLE", "HELP_SHOWCASE_MOD_SCREEN_CAPTION")
	_add_icon_row(vbox, _MOD_SIDEBAR_TABS, ICON_CELL_W)


func _build_mod_conflicts() -> void:
	_apply_shell_style()
	var root := _content_root()
	var vbox := _shrink(VBoxContainer.new()) as VBoxContainer
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)
	root.add_child(vbox)

	_add_showcase_header(vbox, "HELP_SHOWCASE_MOD_CONFLICTS_TITLE", "HELP_SHOWCASE_MOD_CONFLICTS_CAPTION")

	var states_title := _shrink(Label.new()) as Label
	states_title.text = tr("HELP_SHOWCASE_MOD_CONFLICT_STATES_TITLE")
	_ty(states_title, _HelpTypography.SIZE_CAPTION, _HelpTypography.COLOR_DIM)
	vbox.add_child(states_title)

	var demo_id := "slow_75"
	var demo_accent := _RunModifiers.category_tint(demo_id, true)
	var states_row := _shrink(HBoxContainer.new()) as HBoxContainer
	states_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	states_row.alignment = BoxContainer.ALIGNMENT_CENTER
	states_row.add_theme_constant_override("separation", 10)
	vbox.add_child(states_row)
	for state in ["off", "on", "conflict"]:
		var label_key := "HELP_SHOWCASE_MOD_CONFLICT_STATE_OFF"
		match state:
			"on":
				label_key = "HELP_SHOWCASE_MOD_CONFLICT_STATE_ON"
			"conflict":
				label_key = "HELP_SHOWCASE_MOD_CONFLICT_STATE_CONFLICT"
		states_row.add_child(
			_make_modifier_state_column(demo_id, demo_accent, state, label_key),
		)

	var example_title := _shrink(Label.new()) as Label
	example_title.text = tr("HELP_SHOWCASE_MOD_CONFLICT_EXAMPLE_TITLE")
	_ty(example_title, _HelpTypography.SIZE_CAPTION, _HelpTypography.COLOR_DIM)
	vbox.add_child(example_title)

	var ids := _conflict_showcase_ids()
	var example_row := _shrink(HBoxContainer.new()) as HBoxContainer
	example_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	example_row.alignment = BoxContainer.ALIGNMENT_CENTER
	example_row.add_theme_constant_override("separation", 12)
	vbox.add_child(example_row)
	if ids.size() >= 2:
		var first_id := str(ids[0])
		var second_id := str(ids[1])
		example_row.add_child(
			_make_modifier_state_column(
				first_id,
				_RunModifiers.category_tint(first_id, true),
				"on",
				"HELP_SHOWCASE_MOD_CONFLICT_STATE_ON",
			),
		)
		var arrow := _shrink(Label.new()) as Label
		arrow.text = "↔"
		_ty(arrow, _HelpTypography.SIZE_ARROW, Color(0.72, 0.78, 0.88, 0.9))
		example_row.add_child(arrow)
		example_row.add_child(
			_make_modifier_state_column(
				second_id,
				_RunModifiers.category_tint(second_id, true),
				"conflict",
				"HELP_SHOWCASE_MOD_CONFLICT_STATE_CONFLICT",
			),
		)

	var footer := _track_wrap_label(Label.new())
	footer.text = tr("HELP_SHOWCASE_MOD_CONFLICT_FOOTER")
	_ty(footer, _HelpTypography.SIZE_CAPTION, _HelpTypography.COLOR_MUTED)
	vbox.add_child(footer)


func _conflict_showcase_ids() -> Array:
	var raw := str(_setup_params.get("ids", "slow_75,fast_150")).strip_edges()
	if raw == "":
		return ["slow_75", "fast_150"]
	var parts := raw.split(",")
	var out: Array = []
	for part in parts:
		var id := str(part).strip_edges()
		if id != "":
			out.append(id)
	return out if out.size() >= 2 else ["slow_75", "fast_150"]


func _make_modifier_state_column(
	modifier_id: String,
	accent: Color,
	visual_state: String,
	caption_key: String,
) -> VBoxContainer:
	var column := _shrink(VBoxContainer.new()) as VBoxContainer
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 6)
	column.add_child(_make_modifier_cell(modifier_id, accent, visual_state))
	var caption := _shrink(Label.new()) as Label
	caption.text = tr(caption_key)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.custom_minimum_size = Vector2(MOD_CELL_W, 0.0)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ty(caption, _HelpTypography.SIZE_SMALL, _HelpTypography.COLOR_MUTED)
	column.add_child(caption)
	return column


func _add_modifier_group(parent: VBoxContainer, section_title: String, accent: Color, mod_ids: Array) -> void:
	var header := _shrink(Label.new()) as Label
	header.text = section_title
	_ty(header, _HelpTypography.SIZE_SMALL, accent.lightened(0.05))
	parent.add_child(header)
	_add_modifier_flow(parent, accent, mod_ids)


func _add_modifier_flow(parent: VBoxContainer, accent: Color, mod_ids: Array) -> void:
	var flow := _shrink(FlowContainer.new()) as FlowContainer
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	if _layout_width > 0.0:
		flow.custom_minimum_size.x = _layout_width
	parent.add_child(flow)
	for mod_id in mod_ids:
		flow.add_child(_make_modifier_cell(str(mod_id), accent))


func _make_modifier_cell(
	modifier_id: String,
	accent: Color,
	visual_state: String = "off",
) -> PanelContainer:
	var card := _shrink(PanelContainer.new()) as PanelContainer
	card.custom_minimum_size = Vector2(MOD_CELL_W, MOD_CELL_H)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(10)
	box.bg_color = Color(accent.r, accent.g, accent.b, 0.1)
	match visual_state:
		"on":
			box.set_border_width_all(2)
			box.border_color = _RunModifiers.card_selection_border_color(modifier_id)
		"conflict":
			box.set_border_width_all(2)
			box.border_color = _RunModifiers.card_active_conflict_border_color()
		_:
			box.set_border_width_all(1)
			box.border_color = Color(1, 1, 1, 0.12)
	box.content_margin_left = 4.0
	box.content_margin_right = 4.0
	box.content_margin_top = 5.0
	box.content_margin_bottom = 4.0
	card.add_theme_stylebox_override("panel", box)

	var vbox := _shrink(VBoxContainer.new()) as VBoxContainer
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 3)
	card.add_child(vbox)

	var icon := _shrink(TextureRect.new()) as TextureRect
	icon.custom_minimum_size = Vector2(SHOWCASE_ICON, SHOWCASE_ICON)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _tinted_icon(_RunModifiers.icon_file(modifier_id), accent)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon)

	var label := _shrink(Label.new()) as Label
	label.text = tr(_RunModifiers.title_i18n_key(modifier_id))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size = Vector2(MOD_CELL_W - 10.0, 0.0)
	_ty(label, _HelpTypography.SIZE_SMALL, Color(0.88, 0.91, 0.96, 1.0))
	vbox.add_child(label)

	card.tooltip_text = "%s — %s" % [
		tr(_RunModifiers.title_i18n_key(modifier_id)),
		tr(_RunModifiers.desc_i18n_key(modifier_id)),
	]
	return card


func _build_gen_advanced() -> void:
	_apply_shell_style()
	var root := _content_root()
	var vbox := _shrink(VBoxContainer.new()) as VBoxContainer
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	root.add_child(vbox)
	_add_showcase_header(vbox, "HELP_SHOWCASE_GEN_ADVANCED_TITLE", "HELP_SHOWCASE_GEN_ADVANCED_CAPTION")
	_add_icon_grid(vbox, _GEN_PARAMS, 4)
	var caption := _track_wrap_label(Label.new())
	caption.text = tr("HELP_SHOWCASE_GEN_ADVANCED_FOOTER")
	_ty(caption, _HelpTypography.SIZE_CAPTION, _HelpTypography.COLOR_MUTED)
	vbox.add_child(caption)


func _build_shop_categories() -> void:
	_apply_shell_style()
	var root := _content_root()
	var vbox := _shrink(VBoxContainer.new()) as VBoxContainer
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	root.add_child(vbox)
	_add_showcase_header(vbox, "HELP_SHOWCASE_SHOP_TITLE", "HELP_SHOWCASE_SHOP_CAPTION")
	_add_icon_row(vbox, _SHOP_ITEMS)


func _build_progress_unlocks() -> void:
	_apply_shell_style()
	var root := _content_root()
	var vbox := _shrink(VBoxContainer.new()) as VBoxContainer
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	root.add_child(vbox)
	_add_showcase_header(vbox, "HELP_SHOWCASE_UNLOCK_TITLE", "HELP_SHOWCASE_UNLOCK_CAPTION")
	_add_icon_row(vbox, _UNLOCK_METHODS)


func _build_gen_modes() -> void:
	_apply_shell_style()
	var root := _content_root()
	var vbox := _shrink(VBoxContainer.new()) as VBoxContainer
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	root.add_child(vbox)
	_add_showcase_header(vbox, "HELP_SHOWCASE_MODES_TITLE", "HELP_SHOWCASE_MODES_CAPTION")
	var goals_hdr := _shrink(Label.new()) as Label
	goals_hdr.text = tr("GEN_GOAL_SECTION_TITLE")
	goals_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ty(goals_hdr, _HelpTypography.SIZE_SMALL, Color(0.52, 0.88, 0.72, 1.0))
	vbox.add_child(goals_hdr)
	_add_icon_row(vbox, _GEN_GOALS)


func _build_icon_row_showcase(title_key: String, caption_key: String, items: Array) -> void:
	_apply_shell_style()
	var root := _content_root()
	var vbox := _shrink(VBoxContainer.new()) as VBoxContainer
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	root.add_child(vbox)
	_add_showcase_header(vbox, title_key, caption_key)
	_add_icon_row(vbox, items)


func _add_showcase_header(parent: VBoxContainer, title_key: String, caption_key: String) -> void:
	var title := _shrink(Label.new()) as Label
	title.text = tr(title_key)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ty(title, _HelpTypography.SIZE_SUBTITLE, _HelpTypography.COLOR_DIM)
	parent.add_child(title)
	var caption_key_stripped := caption_key.strip_edges()
	if caption_key_stripped != "":
		var caption := _track_wrap_label(Label.new())
		caption.text = tr(caption_key)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_ty(caption, _HelpTypography.SIZE_CAPTION, _HelpTypography.COLOR_MUTED)
		parent.add_child(caption)


func _wrap_centered(parent: VBoxContainer, node: Control) -> void:
	var center := _shrink(CenterContainer.new()) as CenterContainer
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(node)
	parent.add_child(center)


func _add_icon_row(parent: VBoxContainer, items: Array, _cell_w: float = ICON_CELL_W) -> void:
	var cols := items.size()
	if cols > 3:
		cols = 3
	_add_icon_grid(parent, items, cols)


func _add_icon_grid(parent: VBoxContainer, items: Array, columns: int) -> void:
	var cols := maxi(columns, 1)
	var rows := _shrink(VBoxContainer.new()) as VBoxContainer
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.add_theme_constant_override("separation", 8)
	var row: HBoxContainer = null
	for i in range(items.size()):
		if i % cols == 0:
			row = _shrink(HBoxContainer.new()) as HBoxContainer
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 6)
			rows.add_child(row)
		var item: Dictionary = items[i]
		if row != null:
			row.add_child(_make_icon_cell(item))
	_wrap_centered(parent, rows)


func _make_icon_cell(item: Dictionary, cell_w: float = ICON_CELL_W) -> PanelContainer:
	var accent: Color = item.get("color", Color(0.42, 0.57, 0.82, 1.0))
	var cell_width := float(item.get("cell_w", cell_w))
	var card := _shrink(PanelContainer.new()) as PanelContainer
	card.custom_minimum_size = Vector2(cell_width, ICON_CELL_H)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(10)
	box.bg_color = Color(accent.r, accent.g, accent.b, 0.1)
	box.set_border_width_all(1)
	box.border_color = Color(accent.r, accent.g, accent.b, 0.3)
	box.content_margin_left = 4.0
	box.content_margin_right = 4.0
	box.content_margin_top = 5.0
	box.content_margin_bottom = 4.0
	card.add_theme_stylebox_override("panel", box)
	var vbox := _shrink(VBoxContainer.new()) as VBoxContainer
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 3)
	card.add_child(vbox)
	var icon_px := float(item.get("icon_px", SHOWCASE_ICON))
	var icon := _shrink(TextureRect.new()) as TextureRect
	icon.custom_minimum_size = Vector2(icon_px, icon_px)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.texture = _icon_texture_for_cell(item, accent)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon)
	var label := Label.new()
	label.text = tr(str(item.get("label", "")))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.custom_minimum_size = Vector2(cell_width - 10.0, ICON_LABEL_H)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_FILL
	_ty(label, _HelpTypography.SIZE_SMALL, Color(0.88, 0.91, 0.96, 1.0))
	vbox.add_child(label)
	var tip_key := str(item.get("tip", "")).strip_edges()
	if tip_key != "":
		card.tooltip_text = "%s — %s" % [label.text, tr(tip_key)]
	return card


func _icon_texture_for_cell(item: Dictionary, accent: Color) -> Texture2D:
	var raster_path := str(item.get("raster_path", "")).strip_edges()
	if raster_path != "" and ResourceLoader.exists(raster_path):
		return load(raster_path) as Texture2D
	return _tinted_icon(str(item.get("icon", "")), accent)


func _build_scoring() -> void:
	_apply_shell_style()
	var root := _content_root()
	var vbox := _shrink(VBoxContainer.new()) as VBoxContainer
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)
	root.add_child(vbox)
	_add_showcase_header(vbox, "HELP_SHOWCASE_SCORING_TITLE", "HELP_SHOWCASE_SCORING_CAPTION")

	var grades_row := _shrink(HBoxContainer.new()) as HBoxContainer
	grades_row.alignment = BoxContainer.ALIGNMENT_CENTER
	grades_row.add_theme_constant_override("separation", 10)
	vbox.add_child(grades_row)
	for grade in [
		{"label": "HELP_SHOWCASE_SCORE_PERFECT", "pts": "100", "color": _COLOR_PERFECT},
		{"label": "HELP_SHOWCASE_SCORE_GOOD", "pts": "50", "color": _COLOR_GOOD},
		{"label": "HELP_SHOWCASE_SCORE_MISS", "pts": "0", "color": _COLOR_MISS},
	]:
		grades_row.add_child(_make_score_chip(tr(grade.label), grade.pts, grade.color))

	var combo_title := _shrink(Label.new()) as Label
	combo_title.text = tr("HELP_SHOWCASE_SCORING_COMBO_TITLE")
	combo_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ty(combo_title, _HelpTypography.SIZE_CAPTION, _HelpTypography.COLOR_DIM)
	vbox.add_child(combo_title)

	var combo_row := _shrink(HBoxContainer.new()) as HBoxContainer
	combo_row.alignment = BoxContainer.ALIGNMENT_CENTER
	combo_row.add_theme_constant_override("separation", 8)
	vbox.add_child(combo_row)
	for mult in ["×1.0", "×2.0", "×3.0", "×4.0"]:
		combo_row.add_child(_make_combo_chip(mult))


func _make_score_chip(title: String, pts: String, accent: Color) -> PanelContainer:
	var card := _shrink(PanelContainer.new()) as PanelContainer
	card.custom_minimum_size = Vector2(108.0, 72.0)
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(10)
	box.bg_color = Color(accent.r, accent.g, accent.b, 0.12)
	box.set_border_width_all(2)
	box.border_color = Color(accent.r, accent.g, accent.b, 0.55)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	card.add_theme_stylebox_override("panel", box)
	var vbox := _shrink(VBoxContainer.new()) as VBoxContainer
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)
	var title_lbl := _shrink(Label.new()) as Label
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ty(title_lbl, _HelpTypography.SIZE_SMALL, accent)
	vbox.add_child(title_lbl)
	var pts_lbl := _shrink(Label.new()) as Label
	pts_lbl.text = pts
	pts_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ty(pts_lbl, _HelpTypography.SIZE_SUBTITLE, Color(0.88, 0.91, 0.96, 1.0))
	vbox.add_child(pts_lbl)
	return card


func _make_combo_chip(mult: String) -> PanelContainer:
	var card := _shrink(PanelContainer.new()) as PanelContainer
	card.custom_minimum_size = Vector2(72.0, 44.0)
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(8)
	box.bg_color = Color(0.42, 0.57, 0.82, 0.15)
	box.set_border_width_all(1)
	box.border_color = Color(0.42, 0.57, 0.82, 0.45)
	box.content_margin_left = 6.0
	box.content_margin_right = 6.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	card.add_theme_stylebox_override("panel", box)
	var lbl := _shrink(Label.new()) as Label
	lbl.text = mult
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ty(lbl, _HelpTypography.SIZE_CAPTION, Color(0.45, 0.72, 0.98, 1.0))
	card.add_child(lbl)
	return card


func _build_rhythm_rating() -> void:
	_apply_shell_style()
	var root := _content_root()
	var vbox := _shrink(VBoxContainer.new()) as VBoxContainer
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	root.add_child(vbox)
	_add_showcase_header(vbox, "HELP_SHOWCASE_RR_TITLE", "HELP_SHOWCASE_RR_CAPTION")

	var row := _shrink(HBoxContainer.new()) as HBoxContainer
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	vbox.add_child(row)
	for demo in [
		{"rr": "420", "color": Color(0.62, 0.7, 0.82, 0.95)},
		{"rr": "1280", "color": _COLOR_RR},
	]:
		row.add_child(_make_rr_cell(str(demo["rr"]), demo["color"] as Color))

	var footer := _track_wrap_label(Label.new())
	footer.text = tr("HELP_SHOWCASE_RR_FOOTER")
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ty(footer, _HelpTypography.SIZE_CAPTION, _HelpTypography.COLOR_MUTED)
	vbox.add_child(footer)


func _make_rr_cell(rr_value: String, accent: Color) -> PanelContainer:
	var card := _shrink(PanelContainer.new()) as PanelContainer
	card.custom_minimum_size = Vector2(120.0, 88.0)
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(10)
	box.bg_color = Color(accent.r, accent.g, accent.b, 0.1)
	box.set_border_width_all(2)
	box.border_color = Color(accent.r, accent.g, accent.b, 0.45)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	card.add_theme_stylebox_override("panel", box)
	var vbox := _shrink(VBoxContainer.new()) as VBoxContainer
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)
	var badge := _shrink(Label.new()) as Label
	badge.text = "RR"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ty(badge, _HelpTypography.SIZE_SMALL, accent)
	vbox.add_child(badge)
	var val := _shrink(Label.new()) as Label
	val.text = "%s RR" % rr_value
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ty(val, _HelpTypography.SIZE_SUBTITLE, Color(0.88, 0.91, 0.96, 1.0))
	vbox.add_child(val)
	return card


func _build_health_bar() -> void:
	_apply_shell_style()
	var root := _content_root()
	var vbox := _shrink(VBoxContainer.new()) as VBoxContainer
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	root.add_child(vbox)
	_add_showcase_header(vbox, "HELP_SHOWCASE_HP_TITLE", "HELP_SHOWCASE_HP_CAPTION")

	for state in [
		{"label": "HELP_SHOWCASE_HP_FULL", "fill": 1.0, "color": _HealthBar.COLOR_HIGH},
		{"label": "HELP_SHOWCASE_HP_HIT", "fill": 0.35, "color": _HealthBar.COLOR_LOW},
		{"label": "HELP_SHOWCASE_HP_ZERO", "fill": 0.0, "color": _HealthBar.COLOR_CRITICAL},
	]:
		vbox.add_child(_make_hp_row(tr(state.label), state.fill, state.color))


func _make_hp_row(caption: String, fill: float, fill_color: Color) -> HBoxContainer:
	var row := _shrink(HBoxContainer.new()) as HBoxContainer
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var bar_w := 200.0
	var bar_h := 14.0
	var track := _shrink(PanelContainer.new()) as PanelContainer
	track.custom_minimum_size = Vector2(bar_w, bar_h)
	var track_box := StyleBoxFlat.new()
	track_box.set_corner_radius_all(4)
	track_box.bg_color = Color(0.12, 0.13, 0.18, 1.0)
	track_box.set_border_width_all(1)
	track_box.border_color = Color(1, 1, 1, 0.1)
	track.add_theme_stylebox_override("panel", track_box)
	if fill > 0.01:
		var fill_panel := _shrink(PanelContainer.new()) as PanelContainer
		fill_panel.custom_minimum_size = Vector2(bar_w * fill, bar_h - 2.0)
		fill_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var fill_box := StyleBoxFlat.new()
		fill_box.set_corner_radius_all(3)
		fill_box.bg_color = fill_color
		fill_panel.add_theme_stylebox_override("panel", fill_box)
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 1)
		margin.add_theme_constant_override("margin_top", 1)
		margin.add_theme_constant_override("margin_bottom", 1)
		margin.add_child(fill_panel)
		track.add_child(margin)
	row.add_child(track)
	var lbl := _shrink(Label.new()) as Label
	lbl.text = caption
	lbl.custom_minimum_size = Vector2(110.0, 0.0)
	_ty(lbl, _HelpTypography.SIZE_SMALL, _HelpTypography.COLOR_MUTED)
	row.add_child(lbl)
	return row


func _build_hit_window() -> void:
	_apply_shell_style()
	var root := _content_root()
	var vbox := _shrink(VBoxContainer.new()) as VBoxContainer
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	root.add_child(vbox)
	_add_showcase_header(vbox, "HELP_SHOWCASE_HIT_TITLE", "HELP_SHOWCASE_HIT_CAPTION")

	var timeline_w := 360.0
	var timeline_h := 56.0
	var timeline := _shrink(PanelContainer.new()) as PanelContainer
	timeline.custom_minimum_size = Vector2(timeline_w, timeline_h)
	var tl_box := StyleBoxFlat.new()
	tl_box.set_corner_radius_all(8)
	tl_box.bg_color = Color(0.1, 0.11, 0.15, 1.0)
	tl_box.set_border_width_all(1)
	tl_box.border_color = Color(1, 1, 1, 0.08)
	timeline.add_theme_stylebox_override("panel", tl_box)

	var center_x := timeline_w * 0.5
	var ms_scale := 600.0
	_add_hit_zone(timeline, center_x - 0.05 * ms_scale, 0.10 * ms_scale, _COLOR_PERFECT, 0.35)
	_add_hit_zone(timeline, center_x - 0.15 * ms_scale, 0.30 * ms_scale, _COLOR_GOOD, 0.2)
	var line := _shrink(ColorRect.new()) as ColorRect
	line.custom_minimum_size = Vector2(2.0, timeline_h - 8.0)
	line.color = Color(1, 1, 1, 0.85)
	line.position = Vector2(center_x - 1.0, 4.0)
	timeline.add_child(line)
	_wrap_centered(vbox, timeline)

	var legend := _shrink(HBoxContainer.new()) as HBoxContainer
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	legend.add_theme_constant_override("separation", 16)
	vbox.add_child(legend)
	for item in [
		{"label": "HELP_SHOWCASE_HIT_PERFECT", "color": _COLOR_PERFECT, "ms": "±0,05 с"},
		{"label": "HELP_SHOWCASE_HIT_GOOD", "color": _COLOR_GOOD, "ms": "±0,15 с"},
	]:
		var col := _shrink(HBoxContainer.new()) as HBoxContainer
		col.add_theme_constant_override("separation", 6)
		var dot := _shrink(ColorRect.new()) as ColorRect
		dot.custom_minimum_size = Vector2(10.0, 10.0)
		dot.color = item.color
		col.add_child(dot)
		var lbl := _shrink(Label.new()) as Label
		lbl.text = "%s %s" % [tr(item.label), item.ms]
		_ty(lbl, _HelpTypography.SIZE_SMALL, _HelpTypography.COLOR_MUTED)
		col.add_child(lbl)
		legend.add_child(col)


func _add_hit_zone(parent: Control, x: float, w: float, color: Color, alpha: float) -> void:
	var zone := _shrink(ColorRect.new()) as ColorRect
	zone.color = Color(color.r, color.g, color.b, alpha)
	zone.custom_minimum_size = Vector2(w, parent.custom_minimum_size.y - 8.0)
	zone.position = Vector2(x, 4.0)
	parent.add_child(zone)


func _build_keyboard_nav() -> void:
	_apply_shell_style()
	var root := _content_root()
	var vbox := _shrink(VBoxContainer.new()) as VBoxContainer
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	root.add_child(vbox)
	_add_showcase_header(vbox, "HELP_SHOWCASE_KEYS_TITLE", "HELP_SHOWCASE_KEYS_CAPTION")

	for screen in [
		{"icon": "music.svg", "color": Color(0.42, 0.57, 0.82, 1.0), "label": "HELP_SHOWCASE_KEYS_LIBRARY", "keys": ["2×click"]},
		{"icon": "settings-2.svg", "color": Color(0.66, 0.58, 0.86, 1.0), "label": "HELP_SHOWCASE_KEYS_GEN", "keys": ["1", "2", "Q/W", "E/R/T", "A/S/D", "Z"]},
		{"icon": "wrench.svg", "color": Color(0.62, 0.86, 0.72, 1.0), "label": "HELP_SHOWCASE_KEYS_MODS", "keys": ["grid"]},
		{"icon": "layout-dashboard.svg", "color": Color(0.98, 0.64, 0.31, 1.0), "label": "HELP_SHOWCASE_KEYS_MENU", "keys": ["1", "2", "3", "4", "5", "6"]},
		{"icon": "settings-2.svg", "color": Color(0.52, 0.76, 0.92, 1.0), "label": "HELP_SHOWCASE_KEYS_SETTINGS", "keys": ["1", "2", "3", "4"]},
		{"icon": "layout-dashboard.svg", "color": Color(0.66, 0.58, 0.86, 1.0), "label": "HELP_SHOWCASE_KEYS_PROFILE", "keys": ["1", "2", "3", "4"]},
		{"icon": "gamepad-2.svg", "color": Color(0.52, 0.76, 0.92, 1.0), "label": "HELP_SHOWCASE_KEYS_PAUSE", "keys": ["1-5", "Esc", "R", "M"]},
	]:
		vbox.add_child(_make_key_row(screen))

	var footer := _track_wrap_label(Label.new())
	footer.text = tr("HELP_SHOWCASE_KEYS_FOOTER")
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ty(footer, _HelpTypography.SIZE_CAPTION, _HelpTypography.COLOR_MUTED)
	vbox.add_child(footer)


func _make_key_row(screen: Dictionary) -> HBoxContainer:
	var accent: Color = screen.get("color", Color(0.42, 0.57, 0.82, 1.0)) as Color
	var row := _shrink(HBoxContainer.new()) as HBoxContainer
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0.0, 36.0)

	var icon_frame := _shrink(PanelContainer.new()) as PanelContainer
	icon_frame.custom_minimum_size = Vector2(30.0, 30.0)
	var icon_box := StyleBoxFlat.new()
	icon_box.set_corner_radius_all(6)
	icon_box.bg_color = Color(accent.r, accent.g, accent.b, 0.15)
	icon_frame.add_theme_stylebox_override("panel", icon_box)
	var icon := _shrink(TextureRect.new()) as TextureRect
	icon.custom_minimum_size = Vector2(16.0, 16.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _tinted_icon(str(screen.get("icon", "")), accent)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_child(icon)
	row.add_child(icon_frame)

	var name_lbl := _shrink(Label.new()) as Label
	name_lbl.text = tr(str(screen.label))
	name_lbl.custom_minimum_size = Vector2(148.0, 0.0)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ty(name_lbl, _HelpTypography.SIZE_CAPTION, _HelpTypography.COLOR_BODY)
	row.add_child(name_lbl)

	var keys: Array = screen.get("keys", [])
	var keys_row := _shrink(HBoxContainer.new()) as HBoxContainer
	keys_row.add_theme_constant_override("separation", 4)
	for key_text in keys:
		keys_row.add_child(_make_key_chip(str(key_text)))
	row.add_child(keys_row)
	return row


func _make_key_chip(key_text: String) -> PanelContainer:
	var chip := _shrink(PanelContainer.new()) as PanelContainer
	chip.custom_minimum_size = Vector2(0.0, 24.0)
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(5)
	box.bg_color = Color(0.14, 0.16, 0.22, 1.0)
	box.set_border_width_all(1)
	box.border_color = Color(1, 1, 1, 0.14)
	box.content_margin_left = 6.0
	box.content_margin_right = 6.0
	box.content_margin_top = 2.0
	box.content_margin_bottom = 2.0
	chip.add_theme_stylebox_override("panel", box)
	var lbl := _shrink(Label.new()) as Label
	lbl.text = key_text
	_ty(lbl, _HelpTypography.SIZE_SMALL, Color(0.72, 0.78, 0.88, 1.0))
	chip.add_child(lbl)
	return chip


func _build_note_speed() -> void:
	_apply_shell_style()
	var root := _content_root()
	var vbox := _shrink(VBoxContainer.new()) as VBoxContainer
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	root.add_child(vbox)
	_add_showcase_header(vbox, "HELP_SHOWCASE_SPEED_TITLE", "HELP_SHOWCASE_SPEED_CAPTION")

	var row := _shrink(HBoxContainer.new()) as HBoxContainer
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	vbox.add_child(row)
	for demo in [
		{"speed": "6", "label": "HELP_SHOWCASE_SPEED_SLOW", "gap": 18.0},
		{"speed": "20", "label": "HELP_SHOWCASE_SPEED_FAST", "gap": 6.0},
	]:
		row.add_child(_make_speed_column(str(demo["speed"]), tr(str(demo["label"])), float(demo["gap"])))


func _make_speed_column(speed: String, caption: String, arrow_gap: float) -> VBoxContainer:
	var col := _shrink(VBoxContainer.new()) as VBoxContainer
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", int(arrow_gap))
	var speed_lbl := _shrink(Label.new()) as Label
	speed_lbl.text = speed
	speed_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ty(speed_lbl, _HelpTypography.SIZE_SUBTITLE, Color(0.45, 0.72, 0.98, 1.0))
	col.add_child(speed_lbl)
	for _i in 3:
		var arrow := _shrink(Label.new()) as Label
		arrow.text = "↓"
		arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_ty(arrow, _HelpTypography.SIZE_CAPTION, Color(0.62, 0.7, 0.82, 0.9))
		col.add_child(arrow)
	var cap := _shrink(Label.new()) as Label
	cap.text = caption
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ty(cap, _HelpTypography.SIZE_SMALL, _HelpTypography.COLOR_MUTED)
	col.add_child(cap)
	return col

