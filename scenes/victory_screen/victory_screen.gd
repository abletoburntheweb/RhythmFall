# scenes/victory_screen/victory_screen.gd
extends Control

const GradeDisplay = preload("res://logic/ui/grade_display.gd")
const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const _TrackMedals = preload("res://logic/domain/library/track_medals.gd")
const _TimeUtils = preload("res://logic/platform/time_utils.gd")
const _RhythmRating = preload("res://logic/domain/rhythm/rhythm_rating.gd")
const _VictoryTrackRecommender = preload("res://scenes/victory_screen/lib/victory_track_recommender.gd")
const _CoverLoader = preload("res://scenes/song_select/rhythm_dna/lib/rhythm_dna_cover_loader.gd")
const _IconStrip = preload("res://logic/ui/modifier_icon_strip.gd")
const _UiMotionEffects = preload("res://logic/ui/ui_motion_effects.gd")
const _GenPresetUi = preload("res://logic/ui/generation_preset_ui.gd")
const _SpotlightTutorialScene = preload("res://ui/spotlight_tutorial.tscn")
const ResultsHistoryService = preload("res://logic/data/results_history_service.gd")
const _ReplayLauncher = preload("res://logic/domain/replay/replay_launcher.gd")
const _RfrCodec = preload("res://logic/platform/rfr_replay_codec.gd")
const _ReplayStore = preload("res://logic/domain/replay/replay_store.gd")
const _StatusToast = preload("res://logic/ui/status_toast.gd")
const MEDAL_ICON_SLOT_SCENE := preload("res://scenes/ui/medal_icon_slot.tscn")

signal song_select_requested
signal replay_requested

var score: int
var combo: int
var max_combo: int
var accuracy: float
var song_info: Dictionary = {}
var earned_currency: int = 0
var earned_xp: int = 0 

var calculated_combo_multiplier: float = 1.0 
var calculated_total_notes: int = 0
var calculated_missed_notes: int = 0
var perfect_hits_this_level: int = 0
var hit_notes_this_level: int = 0
var run_rr: int = 0
var run_rr_is_repeat: bool = false
var _recommendation: Dictionary = {}
var _first_clear_this_run: bool = false
var _medals_new_run: Array = []
var _chart_baseline: Dictionary = {}
var _run_highlights: Dictionary = {}

const COLOR_RR_FIRST := Color("#F2B35A")
const COLOR_RR_REPEAT := Color("#C8D2E6")
const COLOR_DELTA_POS := Color(0.42, 0.88, 0.62, 0.95)
const COLOR_DELTA_NEG := Color(0.94, 0.48, 0.52, 0.95)

var results_manager = null
var _score_tween: Tween = null
var _score_display_value_internal: float = 0.0
var score_display_value: float:
	set(value):
		_score_display_value_internal = value
		if is_instance_valid(score_label):
			score_label.text = _format_score_text(int(round(_score_display_value_internal)))
	get:
		return _score_display_value_internal
var _victory_anim_tween: Tween = null
var _combo_display_value_internal: float = 0.0
var combo_display_value: float:
	set(value):
		_combo_display_value_internal = value
		if is_instance_valid(combo_label):
			combo_label.text = _format_combo_text(int(round(_combo_display_value_internal)))
	get:
		return _combo_display_value_internal
var _max_combo_display_value_internal: float = 0.0
var max_combo_display_value: float:
	set(value):
		_max_combo_display_value_internal = value
		if is_instance_valid(max_combo_label):
			max_combo_label.text = _format_max_combo_text(int(round(_max_combo_display_value_internal)))
	get:
		return _max_combo_display_value_internal
var _accuracy_display_value_internal: float = 0.0
var accuracy_display_value: float:
	set(value):
		_accuracy_display_value_internal = value
		if is_instance_valid(accuracy_label):
			accuracy_label.text = _format_accuracy_text(_accuracy_display_value_internal)
	get:
		return _accuracy_display_value_internal
var _currency_display_value_internal: float = 0.0
var currency_display_value: float:
	set(value):
		_currency_display_value_internal = value
		if is_instance_valid(currency_label):
			currency_label.text = _format_currency_text(int(round(_currency_display_value_internal)))
	get:
		return _currency_display_value_internal
var _xp_display_value_internal: float = 0.0
var xp_display_value: float:
	set(value):
		_xp_display_value_internal = value
		if is_instance_valid(xp_label):
			xp_label.text = _format_xp_text(int(round(_xp_display_value_internal)))
	get:
		return _xp_display_value_internal
var _perfect_display_value_internal: float = 0.0
var perfect_display_value: float:
	set(value):
		_perfect_display_value_internal = value
		if is_instance_valid(perfect_label):
			perfect_label.text = _format_perfect_text(int(round(_perfect_display_value_internal)))
	get:
		return _perfect_display_value_internal
var _good_display_value_internal: float = 0.0
var good_display_value: float:
	set(value):
		_good_display_value_internal = value
		if is_instance_valid(good_label):
			good_label.text = _format_good_text(int(round(_good_display_value_internal)))
	get:
		return _good_display_value_internal
var _missed_notes_display_value_internal: float = 0.0
var missed_notes_display_value: float:
	set(value):
		_missed_notes_display_value_internal = value
		if is_instance_valid(miss_label):
			miss_label.text = _format_miss_text(int(round(_missed_notes_display_value_internal)))
	get:
		return _missed_notes_display_value_internal
var _count_progress_internal: float = 0.0
var count_kind: String = ""
var count_start: float = 0.0
var count_target: float = 0.0
var _progress_owner_kind: String = ""
var _prev_count_kind: String = ""
var _last_tick_ms: int = 0
var _last_int_score: int = -1
var _last_int_currency: int = -1
var _last_int_xp: int = -1
var _last_int_combo: int = -1
var _last_int_max_combo: int = -1
var _last_int_perfect: int = -1
var _last_int_good: int = -1
var _last_int_miss: int = -1
var _last_acc_tenths: int = -1
var _rewards_detail_clickable: bool = false
var _grade_revealed: bool = false
var _countups_skipped: bool = false
@export var count_progress: float:
	set(value):
		if count_kind != _progress_owner_kind:
			_progress_owner_kind = count_kind
			_count_progress_internal = value
		else:
			if value < _count_progress_internal:
				value = _count_progress_internal
			_count_progress_internal = value
		var t = clamp(_count_progress_internal, 0.0, 1.0)
		var v = lerp(count_start, count_target, t)
		if t >= 0.999:
			v = count_target
		match count_kind:
			"score":
				score_display_value = v
				var vi = int(round(v))
				if vi > _last_int_score and (Time.get_ticks_msec() - _last_tick_ms) >= 50:
					_last_int_score = vi
					_last_tick_ms = Time.get_ticks_msec()
					if MusicManager and MusicManager.has_method("play_score_tick"):
						MusicManager.play_score_tick()
			"combo":
				combo_display_value = v
				var vc = int(round(v))
				if vc > _last_int_combo and (Time.get_ticks_msec() - _last_tick_ms) >= 50:
					_last_int_combo = vc
					_last_tick_ms = Time.get_ticks_msec()
					if MusicManager and MusicManager.has_method("play_score_tick"):
						MusicManager.play_score_tick()
			"max_combo":
				max_combo_display_value = v
				var vm = int(round(v))
				if vm > _last_int_max_combo and (Time.get_ticks_msec() - _last_tick_ms) >= 50:
					_last_int_max_combo = vm
					_last_tick_ms = Time.get_ticks_msec()
					if MusicManager and MusicManager.has_method("play_score_tick"):
						MusicManager.play_score_tick()
			"accuracy":
				accuracy_display_value = v
				var at = int(round(v * 10.0))
				if at > _last_acc_tenths and (Time.get_ticks_msec() - _last_tick_ms) >= 50:
					_last_acc_tenths = at
					_last_tick_ms = Time.get_ticks_msec()
					if MusicManager and MusicManager.has_method("play_score_tick"):
						MusicManager.play_score_tick()
			"perfect":
				perfect_display_value = v
				var vp = int(round(v))
				if vp > _last_int_perfect and (Time.get_ticks_msec() - _last_tick_ms) >= 50:
					_last_int_perfect = vp
					_last_tick_ms = Time.get_ticks_msec()
					if MusicManager and MusicManager.has_method("play_score_tick"):
						MusicManager.play_score_tick()
			"good":
				good_display_value = v
				var vg = int(round(v))
				if vg > _last_int_good and (Time.get_ticks_msec() - _last_tick_ms) >= 50:
					_last_int_good = vg
					_last_tick_ms = Time.get_ticks_msec()
					if MusicManager and MusicManager.has_method("play_score_tick"):
						MusicManager.play_score_tick()
			"miss":
				missed_notes_display_value = v
				var vm2 = int(round(v))
				if vm2 > _last_int_miss and (Time.get_ticks_msec() - _last_tick_ms) >= 50:
					_last_int_miss = vm2
					_last_tick_ms = Time.get_ticks_msec()
					if MusicManager and MusicManager.has_method("play_score_tick"):
						MusicManager.play_score_tick()
			"currency":
				currency_display_value = v
				var vi2 = int(round(v))
				if vi2 > _last_int_currency and (Time.get_ticks_msec() - _last_tick_ms) >= 50:
					_last_int_currency = vi2
					_last_tick_ms = Time.get_ticks_msec()
					if MusicManager and MusicManager.has_method("play_score_tick"):
						MusicManager.play_score_tick()
			"xp":
				xp_display_value = v
				var vi3 = int(round(v))
				if vi3 > _last_int_xp and (Time.get_ticks_msec() - _last_tick_ms) >= 50:
					_last_int_xp = vi3
					_last_tick_ms = Time.get_ticks_msec()
					if MusicManager and MusicManager.has_method("play_score_tick"):
						MusicManager.play_score_tick()
	get:
		return _count_progress_internal
func set_count_kind(kind: String) -> void:
	if _prev_count_kind != "":
		var prev_target := 0.0
		match _prev_count_kind:
			"score":
				prev_target = float(score)
				score_display_value = prev_target
			"combo":
				prev_target = float(combo)
				combo_display_value = prev_target
			"max_combo":
				prev_target = float(max_combo)
				max_combo_display_value = prev_target
			"accuracy":
				prev_target = float(accuracy)
				accuracy_display_value = prev_target
			"perfect":
				prev_target = float(perfect_hits_this_level)
				perfect_display_value = prev_target
			"good":
				prev_target = float(_good_hits_this_level())
				good_display_value = prev_target
			"miss":
				prev_target = float(calculated_missed_notes)
				missed_notes_display_value = prev_target
			"currency":
				prev_target = float(earned_currency)
				currency_display_value = prev_target
			"xp":
				prev_target = float(earned_xp)
				xp_display_value = prev_target
	count_kind = kind
	match kind:
		"score":
			count_start = score_display_value
			count_target = float(score)
		"combo":
			count_start = combo_display_value
			count_target = float(combo)
		"max_combo":
			count_start = max_combo_display_value
			count_target = float(max_combo)
		"accuracy":
			count_start = accuracy_display_value
			count_target = float(accuracy)
		"perfect":
			count_start = perfect_display_value
			count_target = float(perfect_hits_this_level)
		"good":
			count_start = good_display_value
			count_target = float(_good_hits_this_level())
		"miss":
			count_start = missed_notes_display_value
			count_target = float(calculated_missed_notes)
		"currency":
			count_start = currency_display_value
			count_target = float(earned_currency)
		"xp":
			count_start = xp_display_value
			count_target = float(earned_xp)
	_prev_count_kind = kind

var victory_animation_player: AnimationPlayer = null

@export var grade_color_SS: Color = Color("#F2B35A")
@export var grade_color_S: Color = Color("#C8D2E6")
@export var grade_color_A: Color = Color("#6B91D2")
@export var grade_color_B: Color = Color("#59D1BE")
@export var grade_color_C: Color = Color("#A58EDB")
@export var grade_color_D: Color = Color("#D56B87")
@export var grade_color_F: Color = Color("#8A2F39")
@export var grade_color_SS_repeat: Color = Color("#2EE59D")

@onready var background: ColorRect = $Background
@onready var cover_panel: PanelContainer = $MainMargin/MainVBox/TopRowHBox/CoverPanel
@onready var cover_texture_rect: TextureRect = (
	$MainMargin/MainVBox/TopRowHBox/CoverPanel/CoverMargin/CoverTextureRect
)
@onready var title_label: Label = $MainMargin/MainVBox/TopRowHBox/HeroVBox/TitleLabel
@onready var song_label: Label = $MainMargin/MainVBox/TopRowHBox/HeroVBox/SongLabel
@onready var song_meta_label: Label = $MainMargin/MainVBox/TopRowHBox/HeroVBox/SongMetaLabel
@onready var chart_difficulty_row: HBoxContainer = (
	$MainMargin/MainVBox/TopRowHBox/HeroVBox/ChartDifficultyRow
)
@onready var chart_difficulty_label: Label = (
	$MainMargin/MainVBox/TopRowHBox/HeroVBox/ChartDifficultyRow/ChartDifficultyLabel
)
@onready var chart_difficulty_icons_row: HBoxContainer = (
	$MainMargin/MainVBox/TopRowHBox/HeroVBox/ChartDifficultyRow/ChartDifficultyIcons
)
@onready var chart_difficulty_meter: ChartDifficultyMeter = (
	$MainMargin/MainVBox/TopRowHBox/HeroVBox/ChartDifficultyRow/ChartDifficultyMeter
)
@onready var chart_difficulty_value_label: Label = (
	$MainMargin/MainVBox/TopRowHBox/HeroVBox/ChartDifficultyRow/ChartDifficultyValueLabel
)
@onready var modifiers_row: HBoxContainer = $MainMargin/MainVBox/TopRowHBox/HeroVBox/ModifiersRow
@onready var modifiers_chips: HBoxContainer = (
	$MainMargin/MainVBox/TopRowHBox/HeroVBox/ModifiersRow/ModifiersChips
)
@onready var modifiers_mult_label: Label = (
	$MainMargin/MainVBox/TopRowHBox/HeroVBox/ModifiersRow/ModifiersMultLabel
)
@onready var modifiers_label: Label = $MainMargin/MainVBox/TopRowHBox/HeroVBox/ModifiersLabel
@onready var grade_card: PanelContainer = $MainMargin/MainVBox/TopRowHBox/HeroVBox/GradeCard
@onready var grade_label: Label = (
	$MainMargin/MainVBox/TopRowHBox/HeroVBox/GradeCard/GradeCardMargin/GradeCardVBox/GradeLabel
)
@onready var first_clear_label: Label = (
	$MainMargin/MainVBox/TopRowHBox/HeroVBox/GradeCard/GradeCardMargin/GradeCardVBox/FirstClearLabel
)
@onready var rr_label: Label = (
	$MainMargin/MainVBox/TopRowHBox/HeroVBox/GradeCard/GradeCardMargin/GradeCardVBox/RrLabel
)
@onready var run_medals_row: HBoxContainer = (
	$MainMargin/MainVBox/TopRowHBox/HeroVBox/GradeCard/GradeCardMargin/GradeCardVBox/RunMedalsRow
)
@onready var pb_banner: PanelContainer = $MainMargin/MainVBox/PbBanner
@onready var pb_banner_label: Label = $MainMargin/MainVBox/PbBanner/PbBannerMargin/PbBannerLabel
@onready var rewards_title_label: Label = (
	$MainMargin/MainVBox/TopRowHBox/RightColVBox/RewardsPanel/RewardsMargin/RewardsVBox/RewardsTitleLabel
)
@onready var score_label: Label = (
	$MainMargin/MainVBox/BottomRowHBox/StatsPanel/StatsMargin/StatsGrid/ScoreTile/StatVBox/ScoreLabel
)
@onready var score_delta_label: Label = (
	$MainMargin/MainVBox/BottomRowHBox/StatsPanel/StatsMargin/StatsGrid/ScoreTile/StatVBox/ScoreDeltaLabel
)
@onready var combo_label: Label = (
	$MainMargin/MainVBox/BottomRowHBox/StatsPanel/StatsMargin/StatsGrid/ComboTile/StatVBox/ComboLabel
)
@onready var combo_delta_label: Label = (
	$MainMargin/MainVBox/BottomRowHBox/StatsPanel/StatsMargin/StatsGrid/ComboTile/StatVBox/ComboDeltaLabel
)
@onready var max_combo_label: Label = (
	$MainMargin/MainVBox/BottomRowHBox/StatsPanel/StatsMargin/StatsGrid/MaxComboTile/StatVBox/MaxComboLabel
)
@onready var max_combo_delta_label: Label = (
	$MainMargin/MainVBox/BottomRowHBox/StatsPanel/StatsMargin/StatsGrid/MaxComboTile/StatVBox/MaxComboDeltaLabel
)
@onready var accuracy_label: Label = (
	$MainMargin/MainVBox/BottomRowHBox/StatsPanel/StatsMargin/StatsGrid/AccuracyTile/StatVBox/AccuracyLabel
)
@onready var accuracy_delta_label: Label = (
	$MainMargin/MainVBox/BottomRowHBox/StatsPanel/StatsMargin/StatsGrid/AccuracyTile/StatVBox/AccuracyDeltaLabel
)
@onready var perfect_label: Label = (
	$MainMargin/MainVBox/BottomRowHBox/StatsPanel/StatsMargin/StatsGrid/PerfectTile/StatVBox/PerfectLabel
)
@onready var good_label: Label = (
	$MainMargin/MainVBox/BottomRowHBox/StatsPanel/StatsMargin/StatsGrid/GoodTile/StatVBox/GoodLabel
)
@onready var miss_label: Label = (
	$MainMargin/MainVBox/BottomRowHBox/StatsPanel/StatsMargin/StatsGrid/MissTile/StatVBox/MissLabel
)
@onready var currency_label: Label = (
	$MainMargin/MainVBox/TopRowHBox/RightColVBox/RewardsPanel/RewardsMargin/RewardsVBox/RewardsBodyHBox/CurrencyCol/CurrencyTop/CurrencyLabel
)
@onready var currency_caption_label: Label = (
	$MainMargin/MainVBox/TopRowHBox/RightColVBox/RewardsPanel/RewardsMargin/RewardsVBox/RewardsBodyHBox/CurrencyCol/CurrencyCaption
)
@onready var _currency_row: Control = (
	$MainMargin/MainVBox/TopRowHBox/RightColVBox/RewardsPanel/RewardsMargin/RewardsVBox/RewardsBodyHBox/CurrencyCol
)
@onready var xp_label: Label = (
	$MainMargin/MainVBox/TopRowHBox/RightColVBox/RewardsPanel/RewardsMargin/RewardsVBox/RewardsBodyHBox/XPCol/XPTop/XPLabel
)
@onready var xp_caption_label: Label = (
	$MainMargin/MainVBox/TopRowHBox/RightColVBox/RewardsPanel/RewardsMargin/RewardsVBox/RewardsBodyHBox/XPCol/XPCaption
)
@onready var _xp_row: Control = (
	$MainMargin/MainVBox/TopRowHBox/RightColVBox/RewardsPanel/RewardsMargin/RewardsVBox/RewardsBodyHBox/XPCol
)
@onready var rewards_hint_label: Label = (
	$MainMargin/MainVBox/TopRowHBox/RightColVBox/RewardsPanel/RewardsMargin/RewardsVBox/RewardsHintLabel
)
@onready var xp_progress_bar: ProgressBar = (
	$MainMargin/MainVBox/TopRowHBox/RightColVBox/RewardsPanel/RewardsMargin/RewardsVBox/XpProgressRow/XpProgressBar
)
@onready var xp_level_hint_label: Label = (
	$MainMargin/MainVBox/TopRowHBox/RightColVBox/RewardsPanel/RewardsMargin/RewardsVBox/XpProgressRow/XpLevelHintLabel
)
@onready var accuracy_chart_title: Label = (
	$MainMargin/MainVBox/TopRowHBox/RightColVBox/ChartPanel/ChartMargin/ChartVBox/AccuracyChartTitle
)
@onready var accuracy_chart: Control = (
	$MainMargin/MainVBox/TopRowHBox/RightColVBox/ChartPanel/ChartMargin/ChartVBox/VictoryAccuracyChart
)
@onready var lane_stats_panel: PanelContainer = $MainMargin/MainVBox/LaneStatsPanel
@onready var lane_stats_title: Label = (
	$MainMargin/MainVBox/LaneStatsPanel/LaneStatsMargin/LaneStatsVBox/LaneStatsTitle
)
@onready var lane_stats_chart: Control = (
	$MainMargin/MainVBox/LaneStatsPanel/LaneStatsMargin/LaneStatsVBox/VictoryLaneStats
)
@onready var recommend_panel: PanelContainer = $MainMargin/MainVBox/BottomRowHBox/RecommendPanel
@onready var recommend_icon_rect: TextureRect = (
	$MainMargin/MainVBox/BottomRowHBox/RecommendPanel/RecommendMargin/RecommendVBox/RecommendHBox/RecommendIconPanel/RecommendIconMargin/RecommendIconRect
)
@onready var recommend_icon_panel: PanelContainer = (
	$MainMargin/MainVBox/BottomRowHBox/RecommendPanel/RecommendMargin/RecommendVBox/RecommendHBox/RecommendIconPanel
)
@onready var recommend_title_label: Label = (
	$MainMargin/MainVBox/BottomRowHBox/RecommendPanel/RecommendMargin/RecommendVBox/RecommendTitleLabel
)
@onready var recommend_next_label: Label = (
	$MainMargin/MainVBox/BottomRowHBox/RecommendPanel/RecommendMargin/RecommendVBox/RecommendHBox/RecommendTextVBox/RecommendNextLabel
)
@onready var recommend_song_label: Label = (
	$MainMargin/MainVBox/BottomRowHBox/RecommendPanel/RecommendMargin/RecommendVBox/RecommendHBox/RecommendTextVBox/RecommendSongLabel
)
@onready var recommend_reason_label: Label = (
	$MainMargin/MainVBox/BottomRowHBox/RecommendPanel/RecommendMargin/RecommendVBox/RecommendHBox/RecommendTextVBox/RecommendReasonLabel
)
@onready var recommend_difficulty_row: HBoxContainer = (
	$MainMargin/MainVBox/BottomRowHBox/RecommendPanel/RecommendMargin/RecommendVBox/RecommendHBox/RecommendTextVBox/RecommendDifficultyRow
)
@onready var recommend_difficulty_meter: ChartDifficultyMeter = (
	$MainMargin/MainVBox/BottomRowHBox/RecommendPanel/RecommendMargin/RecommendVBox/RecommendHBox/RecommendTextVBox/RecommendDifficultyRow/RecommendDifficultyMeter
)
@onready var recommend_difficulty_value_label: Label = (
	$MainMargin/MainVBox/BottomRowHBox/RecommendPanel/RecommendMargin/RecommendVBox/RecommendHBox/RecommendTextVBox/RecommendDifficultyRow/RecommendDifficultyValueLabel
)
@onready var replay_button: Button = $MainMargin/MainVBox/ButtonsContainer/ReplayButton
@onready var save_run_replay_button: Button = $MainMargin/MainVBox/ButtonsContainer/SaveRunReplayButton
@onready var song_select_button: Button = $MainMargin/MainVBox/ButtonsContainer/SongSelectButton
@onready var next_track_button: Button = $MainMargin/MainVBox/ButtonsContainer/NextTrackButton
@onready var countups_delay_timer: Timer = $CountupsDelayTimer
@onready var hint_label: Label = $MainMargin/MainVBox/HintLabel

var _spotlight_tutorial: CanvasLayer = null

const _MOCKUP_CONTENT_WIDTH := 1140
const _ACCENT_CYAN := Color(0.34902, 0.819608, 0.745098, 1.0)
const _ACCENT_CHART := Color(0.45, 0.68, 0.95, 0.38)
const _ACCENT_RECOMMEND := Color(0.42, 0.88, 0.64, 0.4)
const _CHART_DIFFICULTY_ICON_SIZE := Vector2(16, 16)
const _ICON_MUSIC := Color(0.55, 0.78, 0.98, 1.0)
const _ICON_NEXT_TRACK := Color(0.34902, 0.819608, 0.745098, 1.0)
const _ICON_RECOMMEND := Color(0.42, 0.72, 0.68, 0.95)
const _RECOMMEND_ICON_SIZE := 92
var _chart_difficulty_icon_texture: Texture2D = null


func _ready():
	add_to_group("locale_refresh")
	replay_button.pressed.connect(_on_replay_button_pressed)
	if save_run_replay_button:
		save_run_replay_button.pressed.connect(_on_save_run_replay_pressed)
	song_select_button.pressed.connect(_on_song_select_button_pressed)
	if next_track_button:
		next_track_button.pressed.connect(_on_next_track_button_pressed)
	_wire_recommend_panel()
	
	victory_animation_player = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if victory_animation_player:
		victory_animation_player.animation_finished.connect(_on_victory_anim_finished)
	
	if currency_label:
		currency_label.gui_input.connect(_on_currency_label_clicked)
	
	if xp_label:
		xp_label.gui_input.connect(_on_xp_label_clicked)
	
	_set_rewards_detail_clickable(false)
	
	if countups_delay_timer:
		countups_delay_timer.timeout.connect(_on_countups_delay_timer_timeout)
	if hint_label:
		hint_label.visible = false
	call_deferred("_setup_ui_icons")
	call_deferred("_apply_victory_chrome")
	call_deferred("apply_locale")


func _exit_tree() -> void:
	if cover_panel:
		_UiMotionEffects.stop_panel_border_pulse(cover_panel)
	if recommend_icon_panel:
		_UiMotionEffects.stop_panel_border_pulse(recommend_icon_panel)
	if recommend_panel:
		_UiMotionEffects.stop_panel_border_pulse(recommend_panel)


func _setup_ui_icons() -> void:
	_setup_recommend_icon()
	_refresh_next_track_button_chrome()
	UiIconHelper.configure_button_icon(replay_button, "repeat.svg", UiIconHelper.ICON_NEUTRAL_BTN)
	if save_run_replay_button:
		UiIconHelper.configure_button_icon(save_run_replay_button, "rotate-ccw.svg", Color(0.45, 0.78, 0.98, 1.0))
	UiIconHelper.configure_button_icon(song_select_button, "music.svg", _ICON_MUSIC)


func _refresh_next_track_button_chrome() -> void:
	if next_track_button == null:
		return
	UiIconHelper.apply_button_icon(next_track_button, "chevron-right.svg", _ICON_NEXT_TRACK, 20)
	next_track_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	next_track_button.add_theme_constant_override("icon_max_width", 22)
	next_track_button.add_theme_constant_override("h_separation", 12)


func _apply_victory_chrome() -> void:
	_apply_mockup_card_style()
	_apply_poster_frame(cover_panel, true)
	_apply_poster_frame(recommend_icon_panel, false)
	_apply_grade_card_style()
	_apply_pb_banner_style()
	_apply_xp_progress_style()
	_ensure_grade_glow()


func _make_poster_frame_stylebox() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.108, 0.118, 0.158, 0.96)
	box.border_color = Color(_ACCENT_CYAN.r, _ACCENT_CYAN.g, _ACCENT_CYAN.b, 0.55)
	box.set_border_width_all(1)
	box.set_corner_radius_all(14)
	box.set_content_margin_all(6)
	box.shadow_color = Color(_ACCENT_CYAN.r, _ACCENT_CYAN.g, _ACCENT_CYAN.b, 0.18)
	box.shadow_size = 10
	return box


func _apply_poster_frame(panel: PanelContainer, pulse: bool) -> void:
	if panel == null:
		return
	_UiMotionEffects.stop_panel_border_pulse(panel)
	panel.add_theme_stylebox_override("panel", _make_poster_frame_stylebox())
	if pulse:
		_UiMotionEffects.pulse_panel_border(panel, _ACCENT_CYAN, 0.36, 0.86, 1.05)


func _apply_grade_card_style() -> void:
	if grade_card == null:
		return
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.1, 0.14, 0.74)
	box.border_color = Color(_ACCENT_CYAN.r, _ACCENT_CYAN.g, _ACCENT_CYAN.b, 0.3)
	box.set_border_width_all(1)
	box.set_corner_radius_all(16)
	box.shadow_color = Color(_ACCENT_CYAN.r, _ACCENT_CYAN.g, _ACCENT_CYAN.b, 0.12)
	box.shadow_size = 12
	grade_card.add_theme_stylebox_override("panel", box)


func _apply_pb_banner_style() -> void:
	if pb_banner == null:
		return
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.16, 0.14, 0.92)
	box.border_color = Color(0.42, 0.88, 0.64, 0.55)
	box.set_border_width_all(1)
	box.set_corner_radius_all(12)
	pb_banner.add_theme_stylebox_override("panel", box)


func _apply_xp_progress_style() -> void:
	if xp_progress_bar == null:
		return
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.08, 0.12, 0.9)
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(_ACCENT_CYAN.r, _ACCENT_CYAN.g, _ACCENT_CYAN.b, 0.85)
	fill.set_corner_radius_all(4)
	xp_progress_bar.add_theme_stylebox_override("background", bg)
	xp_progress_bar.add_theme_stylebox_override("fill", fill)


func _ensure_grade_glow() -> void:
	if grade_label == null or grade_label.has_meta("_grade_breathe_tween"):
		return
	var tw := grade_label.create_tween()
	grade_label.set_meta("_grade_breathe_tween", tw)
	tw.set_loops()
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_IN_OUT)
	var bright := Color(1.06, 1.1, 1.08, 1.0)
	tw.tween_property(grade_label, "self_modulate", bright, 1.45)
	tw.tween_property(grade_label, "self_modulate", Color.WHITE, 1.45)


func _apply_mockup_card_style() -> void:
	var specs: Array = [
		["MainMargin/MainVBox/TopRowHBox/RightColVBox/RewardsPanel", _ACCENT_CYAN, 0.42],
		["MainMargin/MainVBox/TopRowHBox/RightColVBox/ChartPanel", _ACCENT_CHART, 0.38],
		["MainMargin/MainVBox/BottomRowHBox/StatsPanel", Color(1, 1, 1, 0.14), 0.14],
		["MainMargin/MainVBox/BottomRowHBox/RecommendPanel", _ACCENT_RECOMMEND, 0.4],
		["MainMargin/MainVBox/LaneStatsPanel", _ACCENT_CHART, 0.32],
	]
	for spec in specs:
		var panel := get_node_or_null(String(spec[0])) as PanelContainer
		if panel:
			panel.add_theme_stylebox_override("panel", _make_accent_card_stylebox(spec[1], float(spec[2])))


func _make_accent_card_stylebox(accent: Color, border_alpha: float) -> StyleBoxFlat:
	var card := StyleBoxFlat.new()
	card.bg_color = Color(0.108, 0.118, 0.158, 0.96)
	card.border_color = Color(accent.r, accent.g, accent.b, border_alpha)
	card.set_border_width_all(1)
	card.set_corner_radius_all(14)
	card.set_content_margin_all(12)
	card.shadow_color = Color(0, 0, 0, 0.28)
	card.shadow_size = 6
	card.shadow_offset = Vector2(0, 2)
	return card


func _setup_recommend_icon() -> void:
	if recommend_icon_rect == null:
		return
	recommend_icon_rect.custom_minimum_size = Vector2(_RECOMMEND_ICON_SIZE, _RECOMMEND_ICON_SIZE)
	recommend_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	recommend_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	recommend_icon_rect.modulate = Color.WHITE


func _refresh_recommend_cover(song: Dictionary) -> void:
	if recommend_icon_rect == null:
		return
	var song_path := str(song.get("path", ""))
	var tex := _CoverLoader.load_cover(song_path)
	if tex == null:
		tex = _CoverLoader.fallback_cover(song_path)
	if tex != null:
		recommend_icon_rect.texture = tex
		return
	recommend_icon_rect.texture = UiIconHelper.load_tinted_icon("disc-3.svg", _ICON_RECOMMEND)


func _wire_recommend_panel() -> void:
	if recommend_panel == null:
		return
	if not recommend_panel.gui_input.is_connected(_on_recommend_panel_gui_input):
		recommend_panel.gui_input.connect(_on_recommend_panel_gui_input)


func _on_recommend_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_next_track_button_pressed()


func apply_locale() -> void:
	if title_label:
		title_label.text = tr("VICTORY_TITLE")
	if replay_button:
		replay_button.text = tr("VICTORY_REPLAY").to_upper()
	if save_run_replay_button:
		save_run_replay_button.text = tr("REPLAY_SAVE_BUTTON").to_upper()
		_refresh_save_run_replay_button()
	if song_select_button:
		song_select_button.text = tr("VICTORY_SONG_SELECT").to_upper()
	if next_track_button:
		next_track_button.text = tr("VICTORY_CONTINUE").to_upper()
		_refresh_next_track_button_chrome()
	_refresh_recommendation_display()
	if accuracy_chart_title:
		accuracy_chart_title.text = tr("VICTORY_ACCURACY_CHART_TITLE")
	if lane_stats_title:
		lane_stats_title.text = tr("VICTORY_LANE_STATS_TITLE")
	if rewards_title_label:
		rewards_title_label.text = tr("VICTORY_REWARDS_TITLE")
	if currency_caption_label:
		currency_caption_label.text = tr("VICTORY_REWARD_CURRENCY")
	if xp_caption_label:
		xp_caption_label.text = tr("VICTORY_REWARD_XP")
	if hint_label and hint_label.visible:
		hint_label.text = tr("VICTORY_HINT_DETAILS")
	_refresh_song_label()
	_refresh_song_meta_label()
	_refresh_cover_texture()
	_refresh_chart_difficulty_display()
	_refresh_modifiers_display()
	_refresh_stat_captions()
	_refresh_stat_labels()
	if is_instance_valid(grade_label) and grade_label.visible:
		grade_label.text = _calculate_grade()
	_refresh_rr_label()
	_refresh_first_clear_label()
	_refresh_run_medals_row()
	_refresh_stat_deltas()
	_refresh_xp_progress()


func _refresh_song_meta_label() -> void:
	if song_meta_label == null:
		return
	if song_info.is_empty():
		song_meta_label.visible = false
		return
	song_meta_label.text = _format_song_meta_line()
	song_meta_label.visible = song_meta_label.text.strip_edges() != ""


func _format_song_meta_line() -> String:
	var duration_text := _song_duration_display()
	var lanes := int(song_info.get("lanes", 4))
	var lanes_text := tr("GEN_PRESET_LANES_FMT") % lanes
	var instrument := _GenPresetUi.localized_instrument(str(song_info.get("instrument", "drums")))
	var mode := _GenPresetUi.localized_mode(str(song_info.get("mode", "basic")))
	return tr("VICTORY_META_FMT") % [duration_text, lanes_text, instrument, mode]


func _song_duration_display() -> String:
	var song_path := str(song_info.get("path", ""))
	if song_path != "" and SongLibrary:
		var md: Variant = SongLibrary.get_metadata_for_song(song_path)
		if md is Dictionary:
			var duration_text := str(md.get("duration", "")).strip_edges()
			if duration_text != "":
				return duration_text
	return "—"


func _normalize_instrument_key(raw: String) -> String:
	var key := raw.strip_edges().to_lower()
	match key:
		"drums", "перкуссия":
			return "drums"
		"standard", "стандарт":
			return "standard"
		"fullmix", "микс":
			return "fullmix"
		_:
			return key


func _result_matches_chart_scope(result: Dictionary, instrument: String, mode: String, lanes: int) -> bool:
	var result_mode := str(result.get("mode", "")).strip_edges().to_lower()
	var run_mode := mode.strip_edges().to_lower()
	if result_mode != "" and run_mode != "" and result_mode != run_mode:
		return false
	var result_lanes := int(result.get("lanes", 0))
	if result_lanes > 0 and lanes > 0 and result_lanes != lanes:
		return false
	var result_inst := _normalize_instrument_key(str(result.get("instrument", "")))
	var run_inst := _normalize_instrument_key(instrument)
	if result_inst != "" and run_inst != "" and result_inst != run_inst:
		return false
	return true


func _result_matches_run_scope(
	result: Dictionary,
	instrument: String,
	mode: String,
	lanes: int,
	modifiers: Array
) -> bool:
	if not _result_matches_chart_scope(result, instrument, mode, lanes):
		return false
	var result_mods: Array = _RunModifiers.sanitize(result.get("modifiers", []))
	var run_mods: Array = _RunModifiers.sanitize(modifiers)
	return result_mods == run_mods


func _capture_chart_baseline(p_song_path: String) -> Dictionary:
	var instrument := str(song_info.get("instrument", "standard"))
	var mode := str(song_info.get("mode", "basic"))
	var lanes := int(song_info.get("lanes", 4))
	var modifiers: Array = song_info.get("modifiers", [])
	if not modifiers is Array:
		modifiers = []
	var previous_rr := 0
	if ProfileMilestonesManager:
		previous_rr = ProfileMilestonesManager.get_best_rr_for_chart(
			p_song_path, instrument, mode, lanes, modifiers
		)
	var best_score := 0
	var best_accuracy := 0.0
	var best_combo := 0
	var had_prior := false
	var last_run_score := 0
	var last_run_accuracy := 0.0
	var last_run_max_combo := 0
	var had_last_run := false
	var results_service := ResultsHistoryService.resolve_backend(results_manager)
	if results_service:
		for raw in results_service.load_results_for_song(p_song_path):
			if not raw is Dictionary:
				continue
			var result: Dictionary = raw
			if not _result_matches_run_scope(result, instrument, mode, lanes, modifiers):
				continue
			if not had_last_run:
				had_last_run = true
				last_run_score = int(result.get("score", 0))
				last_run_accuracy = float(result.get("accuracy", 0.0))
				last_run_max_combo = int(result.get("max_combo", 0))
			had_prior = true
			best_score = maxi(best_score, int(result.get("score", 0)))
			best_accuracy = maxf(best_accuracy, float(result.get("accuracy", 0.0)))
			best_combo = maxi(best_combo, int(result.get("max_combo", 0)))
	return {
		"previous_rr": previous_rr,
		"best_score": best_score,
		"best_accuracy": best_accuracy,
		"best_combo": best_combo,
		"had_prior": had_prior,
		"last_run_score": last_run_score,
		"last_run_accuracy": last_run_accuracy,
		"last_run_max_combo": last_run_max_combo,
		"had_last_run": had_last_run,
	}


func _compute_run_highlights(baseline: Dictionary) -> Dictionary:
	var highlights := {
		"is_any_pb": false,
		"banner_lines": PackedStringArray(),
		"score_pb": false,
		"score_delta": 0,
		"accuracy_delta": 0.0,
		"combo_delta": 0,
		"max_combo_delta": 0,
		"rr_delta": 0,
		"score_vs_last": 0,
		"accuracy_vs_last": 0.0,
		"max_combo_vs_last": 0,
	}
	if not baseline.is_empty() and bool(baseline.get("had_last_run", false)):
		highlights["score_vs_last"] = score - int(baseline.get("last_run_score", 0))
		highlights["accuracy_vs_last"] = accuracy - float(baseline.get("last_run_accuracy", 0.0))
		highlights["max_combo_vs_last"] = max_combo - int(baseline.get("last_run_max_combo", 0))
	var can_compare_pb := (
		not baseline.is_empty()
		and not _modifiers_block_rewards()
		and not _is_repeat_run_vs_baseline(baseline)
		and bool(baseline.get("had_prior", false))
	)
	if can_compare_pb:
		var prev_score := int(baseline.get("best_score", 0))
		var prev_accuracy := float(baseline.get("best_accuracy", 0.0))
		var prev_combo := int(baseline.get("best_combo", 0))
		var prev_rr := int(baseline.get("previous_rr", 0))
		if score > prev_score:
			highlights["score_pb"] = true
			highlights["score_delta"] = score - prev_score
		if accuracy > prev_accuracy + 0.001:
			highlights["accuracy_delta"] = accuracy - prev_accuracy
		if combo > prev_combo:
			highlights["combo_delta"] = combo - prev_combo
		if max_combo > prev_combo:
			highlights["max_combo_delta"] = max_combo - prev_combo
		if run_rr > prev_rr and run_rr > 0 and not run_rr_is_repeat:
			highlights["rr_delta"] = run_rr - prev_rr
		highlights["is_any_pb"] = (
			bool(highlights["score_pb"])
			or float(highlights["accuracy_delta"]) > 0.001
			or int(highlights["max_combo_delta"]) > 0
			or int(highlights["rr_delta"]) > 0
		)
	var lines := PackedStringArray()
	if bool(highlights["is_any_pb"]):
		lines.append(tr("VICTORY_NEW_BEST"))
	if int(highlights["rr_delta"]) > 0:
		lines.append(tr("VICTORY_DELTA_RR_FMT") % int(highlights["rr_delta"]))
	if float(highlights["accuracy_delta"]) > 0.001:
		lines.append(tr("VICTORY_DELTA_ACCURACY_BANNER") % float(highlights["accuracy_delta"]))
	if int(highlights["max_combo_delta"]) > 0:
		lines.append(tr("VICTORY_DELTA_COMBO_BANNER") % int(highlights["max_combo_delta"]))
	if bool(baseline.get("had_last_run", false)) and not bool(highlights["is_any_pb"]):
		var score_vs_last := int(highlights.get("score_vs_last", 0))
		var acc_vs_last := float(highlights.get("accuracy_vs_last", 0.0))
		var combo_vs_last := int(highlights.get("max_combo_vs_last", 0))
		if score_vs_last != 0:
			lines.append(tr("VICTORY_VS_LAST_SCORE_FMT") % score_vs_last)
		if absf(acc_vs_last) > 0.001:
			lines.append(tr("VICTORY_VS_LAST_ACCURACY_FMT") % acc_vs_last)
		if combo_vs_last != 0:
			lines.append(tr("VICTORY_VS_LAST_COMBO_FMT") % combo_vs_last)
	highlights["banner_lines"] = lines
	return highlights


func _refresh_run_medals_row() -> void:
	if run_medals_row == null:
		return
	for child in run_medals_row.get_children():
		run_medals_row.remove_child(child)
		child.queue_free()
	if _medals_new_run.is_empty():
		run_medals_row.visible = false
		run_medals_row.tooltip_text = ""
		return
	run_medals_row.visible = grade_label != null and grade_label.visible
	var medal_ids: Array[String] = []
	for raw in _medals_new_run:
		var medal_id := str(raw)
		if medal_id.strip_edges() != "":
			medal_ids.append(medal_id)
	for medal_id in medal_ids:
		var slot := MEDAL_ICON_SLOT_SCENE.instantiate()
		var icon_path := _TrackMedals.icon_path(medal_id)
		var tex := load(icon_path) as Texture2D if icon_path != "" else null
		if slot.has_method("apply_icon") and tex != null:
			slot.apply_icon(tex, Color(0.95, 0.82, 0.42, 1.0), Vector2(28, 28))
		slot.tooltip_text = tr(_TrackMedals.title_i18n_key(medal_id))
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		run_medals_row.add_child(slot)
	run_medals_row.tooltip_text = _TrackMedals.tooltip_for_medals(medal_ids)


func _refresh_stat_deltas() -> void:
	var show := not _chart_baseline.is_empty() and bool(_chart_baseline.get("had_prior", false))
	var show_last := bool(_chart_baseline.get("had_last_run", false))
	var max_delta := int(_run_highlights.get("max_combo_delta", 0))
	if score_delta_label:
		if show and bool(_run_highlights.get("score_pb", false)):
			var score_delta := int(_run_highlights.get("score_delta", 0))
			if score_delta > 0:
				score_delta_label.text = tr("VICTORY_NEW_BEST_SCORE_FMT") % str(score_delta)
			else:
				score_delta_label.text = tr("VICTORY_NEW_BEST_SCORE")
			score_delta_label.add_theme_color_override("font_color", COLOR_DELTA_POS)
			score_delta_label.visible = true
		elif show_last:
			var score_vs_last := int(_run_highlights.get("score_vs_last", 0))
			if score_vs_last != 0:
				score_delta_label.text = tr("VICTORY_VS_LAST_SCORE_FMT") % score_vs_last
				score_delta_label.add_theme_color_override(
					"font_color", COLOR_DELTA_POS if score_vs_last > 0 else COLOR_DELTA_NEG
				)
				score_delta_label.visible = true
			else:
				score_delta_label.visible = false
		else:
			score_delta_label.visible = false
	if combo_delta_label:
		var combo_delta := int(_run_highlights.get("combo_delta", 0))
		if show and combo_delta > 0 and combo_delta != max_delta:
			combo_delta_label.text = tr("VICTORY_DELTA_COMBO_FMT") % combo_delta
			combo_delta_label.visible = true
		else:
			combo_delta_label.visible = false
	if max_combo_delta_label:
		if show and max_delta > 0:
			max_combo_delta_label.text = tr("VICTORY_DELTA_COMBO_FMT") % max_delta
			max_combo_delta_label.visible = true
		else:
			max_combo_delta_label.visible = false
	if accuracy_delta_label:
		var acc_delta := float(_run_highlights.get("accuracy_delta", 0.0))
		if show and acc_delta > 0.001:
			accuracy_delta_label.text = tr("VICTORY_DELTA_ACCURACY_FMT") % acc_delta
			accuracy_delta_label.add_theme_color_override("font_color", COLOR_DELTA_POS)
			accuracy_delta_label.visible = true
		elif show_last:
			var acc_vs_last := float(_run_highlights.get("accuracy_vs_last", 0.0))
			if absf(acc_vs_last) > 0.001:
				accuracy_delta_label.text = tr("VICTORY_VS_LAST_ACCURACY_FMT") % acc_vs_last
				accuracy_delta_label.add_theme_color_override(
					"font_color", COLOR_DELTA_POS if acc_vs_last > 0.0 else COLOR_DELTA_NEG
				)
				accuracy_delta_label.visible = true
			else:
				accuracy_delta_label.visible = false
		else:
			accuracy_delta_label.visible = false


func _refresh_xp_progress() -> void:
	if xp_progress_bar == null or xp_level_hint_label == null or not PlayerDataManager:
		return
	var xp_for_next := maxi(1, PlayerDataManager.get_xp_for_next_level())
	var total_xp := PlayerDataManager.get_total_xp()
	var progress := clampf(float(total_xp) / float(xp_for_next), 0.0, 1.0)
	xp_progress_bar.max_value = 100.0
	xp_progress_bar.value = progress * 100.0
	var remaining := maxi(0, xp_for_next - total_xp)
	xp_level_hint_label.text = tr("VICTORY_XP_PROGRESS_FMT") % [
		int(round(progress * 100.0)),
		remaining,
	]


func _refresh_pb_banner() -> void:
	if pb_banner == null or pb_banner_label == null:
		return
	var lines: Variant = _run_highlights.get("banner_lines", PackedStringArray())
	if not lines is PackedStringArray or lines.is_empty():
		pb_banner.visible = false
		return
	pb_banner_label.text = "\n".join(lines)
	pb_banner.visible = false


func _play_pb_banner_reveal() -> void:
	if pb_banner == null or pb_banner_label == null:
		return
	var lines: Variant = _run_highlights.get("banner_lines", PackedStringArray())
	if not lines is PackedStringArray or lines.is_empty():
		pb_banner.visible = false
		return
	pb_banner_label.text = "\n".join(lines)
	pb_banner.visible = true
	pb_banner.modulate = Color(1, 1, 1, 0)
	pb_banner.scale = Vector2(0.98, 0.98)
	pb_banner.pivot_offset = pb_banner.size * 0.5
	var tw := pb_banner.create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(pb_banner, "modulate:a", 1.0, 0.42)
	tw.parallel().tween_property(pb_banner, "scale", Vector2.ONE, 0.48)


func _format_rr_text(v: int) -> String:
	# Repeat runs keep the same chart-best RR — never show a fake "+gain".
	if run_rr_is_repeat:
		return tr("VICTORY_RR_REPEAT_PLUS_FMT") % v
	var prev_rr := int(_chart_baseline.get("previous_rr", 0)) if not _chart_baseline.is_empty() else 0
	if prev_rr > 0 and v > prev_rr:
		return tr("VICTORY_RR_PLUS_FMT") % (v - prev_rr)
	return tr("VICTORY_RR_PLUS_FMT") % v


func _is_repeat_run_vs_baseline(baseline: Dictionary) -> bool:
	if baseline.is_empty() or not bool(baseline.get("had_prior", false)):
		return false
	var prev_score := int(baseline.get("best_score", 0))
	if prev_score <= 0:
		return false
	var prev_accuracy := float(baseline.get("best_accuracy", 0.0))
	var prev_combo := int(baseline.get("best_combo", 0))
	var prev_rr := int(baseline.get("previous_rr", 0))
	var same_run := (
		score == prev_score
		and absf(accuracy - prev_accuracy) < 0.05
		and max_combo == prev_combo
	)
	if same_run:
		return true
	if (
		score <= prev_score
		and accuracy <= prev_accuracy + 0.001
		and max_combo <= prev_combo
	):
		return true
	if prev_rr > 0 and run_rr > 0 and run_rr <= prev_rr:
		return true
	return false


func _resolve_rr_repeat_state() -> void:
	run_rr_is_repeat = false
	if run_rr <= 0:
		return
	if _is_repeat_run_vs_baseline(_chart_baseline):
		run_rr_is_repeat = true
		return
	var song_path := str(song_info.get("path", ""))
	var instrument := str(song_info.get("instrument", "standard"))
	var mode := str(song_info.get("mode", "basic"))
	var lanes := int(song_info.get("lanes", 4))
	var modifiers: Array = song_info.get("modifiers", [])
	if not modifiers is Array:
		modifiers = []
	var previous_rr := 0
	if ProfileMilestonesManager:
		previous_rr = ProfileMilestonesManager.get_best_rr_for_chart(
			song_path, instrument, mode, lanes, modifiers
		)
	if previous_rr > 0 and run_rr <= previous_rr:
		run_rr_is_repeat = true
		return
	var grade := _calculate_grade()
	if (
		grade == "SS"
		and modifiers.is_empty()
		and not _modifiers_block_rewards()
		and GradeDisplay.is_repeat_ss_on_track(song_path)
	):
		run_rr_is_repeat = true


func _calculate_run_rr() -> int:
	if _modifiers_block_rewards():
		return 0
	var song_path := str(song_info.get("path", ""))
	var instrument := str(song_info.get("instrument", "standard"))
	var mode := str(song_info.get("mode", "basic"))
	var lanes := int(song_info.get("lanes", 4))
	var modifiers: Array = song_info.get("modifiers", [])
	if not modifiers is Array:
		modifiers = []
	var modifier_params: Dictionary = song_info.get("modifier_params", {})
	if modifier_params is Dictionary:
		modifier_params = _RunModifiers.sync_params_from_modifiers(modifiers, modifier_params)
	else:
		modifier_params = _RunModifiers.sync_params_from_modifiers(modifiers, {})
	var grade := _calculate_grade()
	var full_combo := calculated_missed_notes == 0 and calculated_total_notes > 0
	var chart_rating := ChartDifficultyAnalyzer.get_run_rating(song_path, instrument, mode, lanes)
	return _RhythmRating.compute(accuracy, chart_rating, grade, full_combo, modifiers, modifier_params)


func _refresh_rr_label() -> void:
	if rr_label == null:
		return
	if run_rr <= 0:
		rr_label.visible = false
		return
	rr_label.text = _format_rr_text(run_rr)
	var rr_color := COLOR_RR_REPEAT if run_rr_is_repeat else COLOR_RR_FIRST
	rr_label.add_theme_color_override("font_color", rr_color)
	if not rr_label.visible:
		rr_label.modulate = Color(1, 1, 1, 1)


func _refresh_first_clear_label() -> void:
	if first_clear_label == null:
		return
	first_clear_label.text = tr("VICTORY_FIRST_CLEAR")
	first_clear_label.visible = _first_clear_this_run and grade_label != null and grade_label.visible


func _format_score_text(v: int) -> String:
	return str(v)


func _format_combo_text(v: int) -> String:
	return str(v)


func _format_max_combo_text(v: int) -> String:
	return str(v)


func _format_accuracy_text(v: float) -> String:
	return "%.1f%%" % v


func _format_perfect_text(v: int) -> String:
	return str(v)


func _format_good_text(v: int) -> String:
	return str(v)


func _format_miss_text(v: int) -> String:
	return str(v)


func _good_hits_this_level() -> int:
	return maxi(0, hit_notes_this_level - perfect_hits_this_level)


func _format_currency_text(v: int) -> String:
	return str(v)


func _format_xp_text(v: int) -> String:
	return str(v)


func _format_hits_text(v: int) -> String:
	return str(v)


func _format_misses_text(v: int) -> String:
	return str(v)


func _get_modifiers_label() -> Label:
	if is_instance_valid(modifiers_label):
		return modifiers_label
	return find_child("ModifiersLabel", true, false) as Label


func _refresh_song_label() -> void:
	if not is_instance_valid(song_label) or song_info.is_empty():
		return
	var artist := String(song_info.get("artist", tr("VALUE_UNKNOWN_ARTIST")))
	var title := String(song_info.get("title", tr("VALUE_NO_TITLE")))
	if artist == "Неизвестен" or artist == "Unknown":
		artist = tr("VALUE_UNKNOWN_ARTIST")
	if title == "Без названия":
		title = tr("VALUE_NO_TITLE")
	artist = artist.strip_edges().replace("\r", " ").replace("\n", " ").replace("\t", " ").replace("\u200B", "").replace("\u2028", " ").replace("\u2029", " ")
	title = title.strip_edges().replace("\r", " ").replace("\n", " ").replace("\t", " ").replace("\u200B", "").replace("\u2028", " ").replace("\u2029", " ")
	artist = " ".join(artist.split(" ", false))
	title = " ".join(title.split(" ", false))
	song_label.text = "%s\u00A0—\u00A0%s" % [artist, title]
	song_label.text = song_label.text.to_upper()
	song_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	song_label.clip_text = false


func _refresh_cover_texture() -> void:
	if cover_texture_rect == null:
		return
	var embedded: Variant = song_info.get("cover", null)
	if embedded is Texture2D:
		cover_texture_rect.texture = embedded
		return
	var song_path := str(song_info.get("path", ""))
	var tex := _CoverLoader.load_cover(song_path)
	if tex == null:
		tex = _CoverLoader.fallback_cover(song_path)
	cover_texture_rect.texture = tex


func _refresh_modifiers_display() -> void:
	var label := _get_modifiers_label()
	if label:
		label.visible = false
	if modifiers_row == null:
		return
	var mods: Array = song_info.get("modifiers", [])
	if not mods is Array:
		mods = []
	var params: Dictionary = song_info.get("modifier_params", {})
	if not params is Dictionary:
		params = {}
	params = _RunModifiers.sync_params_from_modifiers(mods, params)
	if modifiers_chips:
		_IconStrip.fill_slot_chips(modifiers_chips, mods, params, _IconStrip.MAX_SLOT_LIST_ICONS)
	if modifiers_mult_label:
		if mods.is_empty():
			modifiers_mult_label.text = ""
		else:
			modifiers_mult_label.text = _RunModifiers.format_preset_multiplier_label(mods, params)
	modifiers_row.visible = not mods.is_empty()


func _clear_chart_difficulty_icons() -> void:
	if chart_difficulty_icons_row == null:
		return
	for child in chart_difficulty_icons_row.get_children():
		chart_difficulty_icons_row.remove_child(child)
		child.queue_free()


func _set_chart_difficulty_icon_count(rating: int, tier_color: Color) -> void:
	if chart_difficulty_icons_row == null:
		return
	_clear_chart_difficulty_icons()
	if _chart_difficulty_icon_texture == null:
		_chart_difficulty_icon_texture = load(ChartDifficultyAnalyzer.ICON_PATH) as Texture2D
	var count := clampi(rating, 0, ChartDifficultyAnalyzer.MAX_RATING)
	for i in count:
		var icon := MEDAL_ICON_SLOT_SCENE.instantiate()
		icon.apply_icon(_chart_difficulty_icon_texture, tier_color, _CHART_DIFFICULTY_ICON_SIZE)
		chart_difficulty_icons_row.add_child(icon)


func _refresh_chart_difficulty_display() -> void:
	if chart_difficulty_row == null:
		return
	if song_info.is_empty():
		chart_difficulty_row.visible = false
		return
	var song_path := str(song_info.get("path", ""))
	var instrument := str(song_info.get("instrument", "standard"))
	var mode := str(song_info.get("mode", "basic"))
	var lanes := int(song_info.get("lanes", 4))
	var base := SongLibrary.get_chart_difficulty_variant(song_path, instrument, mode)
	if base.is_empty() or ChartDifficultyAnalyzer.decimal_rating_from_stats(base) <= 0.0:
		chart_difficulty_row.visible = false
		call_deferred("_ensure_chart_difficulty_display_async")
		return
	_apply_chart_difficulty_display(base)


func _ensure_chart_difficulty_display_async() -> void:
	if chart_difficulty_row == null or song_info.is_empty():
		return
	var song_path := str(song_info.get("path", ""))
	var instrument := str(song_info.get("instrument", "standard"))
	var mode := str(song_info.get("mode", "basic"))
	var lanes := int(song_info.get("lanes", 4))
	var base := ChartDifficultyAnalyzer.ensure_persisted(song_path, instrument, mode, lanes)
	if base.is_empty() or ChartDifficultyAnalyzer.decimal_rating_from_stats(base) <= 0.0:
		chart_difficulty_row.visible = false
		return
	_apply_chart_difficulty_display(base)


func _apply_chart_difficulty_display(base: Dictionary) -> void:
	if chart_difficulty_row == null:
		return
	var mods: Array = song_info.get("modifiers", [])
	if not mods is Array:
		mods = []
	var params: Dictionary = song_info.get("modifier_params", {})
	if not params is Dictionary:
		params = {}
	params = _RunModifiers.sync_params_from_modifiers(mods, params)
	var snapshot := ChartDifficultyAnalyzer.build_rating_snapshot(base, mods, params)
	var display_decimal := float(
		snapshot.get("effective_decimal", 0.0)
		if bool(snapshot.get("has_mods", false))
		else snapshot.get("base_decimal", 0.0)
	)
	if display_decimal <= 0.0:
		chart_difficulty_row.visible = false
		return
	var tier_color := ChartDifficultyAnalyzer.rating_color_for_decimal(display_decimal)
	chart_difficulty_row.visible = true
	if chart_difficulty_label:
		chart_difficulty_label.text = tr("SONG_DIFFICULTY_PREFIX")
		chart_difficulty_label.add_theme_color_override("font_color", Color.WHITE)
		chart_difficulty_label.modulate = tier_color
	if chart_difficulty_meter:
		chart_difficulty_meter.set_decimal_rating(
			minf(display_decimal, float(ChartDifficultyAnalyzer.MAX_RATING)),
			tier_color
		)
		chart_difficulty_meter.tooltip_text = ChartDifficultyAnalyzer.format_effective_tooltip(snapshot)
	if chart_difficulty_value_label:
		chart_difficulty_value_label.text = ChartDifficultyAnalyzer.format_decimal_rating(display_decimal, true)
		chart_difficulty_value_label.add_theme_color_override("font_color", Color.WHITE)
		chart_difficulty_value_label.modulate = tier_color
		chart_difficulty_value_label.tooltip_text = ChartDifficultyAnalyzer.format_effective_tooltip(snapshot)


func _refresh_stat_captions() -> void:
	var specs := [
		["ScoreTile", "VICTORY_STAT_SCORE"],
		["ComboTile", "VICTORY_STAT_COMBO"],
		["MaxComboTile", "VICTORY_STAT_MAX_COMBO"],
		["AccuracyTile", "VICTORY_STAT_ACCURACY"],
		["PerfectTile", "VICTORY_STAT_PERFECT"],
		["GoodTile", "VICTORY_STAT_GOOD"],
		["MissTile", "VICTORY_STAT_MISS"],
	]
	var grid := get_node_or_null(
		"MainMargin/MainVBox/BottomRowHBox/StatsPanel/StatsMargin/StatsGrid"
	)
	if grid == null:
		return
	for spec in specs:
		var tile := grid.get_node_or_null(String(spec[0]))
		if tile == null:
			continue
		var caption := tile.get_node_or_null("StatVBox/CaptionLabel") as Label
		if caption:
			caption.text = tr(String(spec[1]))


func _refresh_stat_labels() -> void:
	if is_instance_valid(score_label):
		score_label.text = _format_score_text(int(round(score_display_value)))
	if is_instance_valid(combo_label):
		combo_label.text = _format_combo_text(int(round(combo_display_value)))
	if is_instance_valid(max_combo_label):
		max_combo_label.text = _format_max_combo_text(int(round(max_combo_display_value)))
	if is_instance_valid(accuracy_label):
		accuracy_label.text = _format_accuracy_text(accuracy_display_value)
	if is_instance_valid(currency_label):
		currency_label.text = _format_currency_text(int(round(currency_display_value)))
	if is_instance_valid(xp_label):
		xp_label.text = _format_xp_text(int(round(xp_display_value)))
	if is_instance_valid(perfect_label):
		perfect_label.text = _format_perfect_text(int(round(perfect_display_value)))
	if is_instance_valid(good_label):
		good_label.text = _format_good_text(int(round(good_display_value)))
	if is_instance_valid(miss_label):
		miss_label.text = _format_miss_text(int(round(missed_notes_display_value)))


func _set_rewards_detail_clickable(enabled: bool) -> void:
	_rewards_detail_clickable = enabled
	var filter := Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	var cursor := Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
	if currency_label:
		currency_label.mouse_filter = filter
		currency_label.mouse_default_cursor_shape = cursor
	if xp_label:
		xp_label.mouse_filter = filter
		xp_label.mouse_default_cursor_shape = cursor

func _calculate_grade() -> String:
	if accuracy == 100.0: 
		return "SS"
	elif accuracy >= 95.0: 
		return "S"
	elif accuracy >= 90.0:
		return "A"
	elif accuracy >= 80.0: 
		return "B"
	elif accuracy >= 70.0:
		return "C"
	elif accuracy >= 60.0:
		return "D"
	else: 
		return "F"
		
func _get_grade_color(grade: String, is_repeat_ss: bool = false) -> Color:
	if grade == "SS":
		return GradeDisplay.ss_display_color(is_repeat_ss)
	match grade:
		"S": return grade_color_S
		"A": return grade_color_A
		"B": return grade_color_B
		"C": return grade_color_C
		"D": return grade_color_D
		"F": return grade_color_F
		_: return Color.WHITE

func _calculate_xp_new() -> int:
	var base_xp = sqrt(float(score)) * 1.2 

	var accuracy_bonus = 0.0
	if accuracy >= 100.0:
		accuracy_bonus = 20.0
	elif accuracy >= 98.0:
		accuracy_bonus = 12.0
	elif accuracy >= 95.0:
		accuracy_bonus = 7.0
	elif accuracy >= 90.0:
		accuracy_bonus = 2.0

	var combo_bonus = 0.0
	if max_combo > 0:
		combo_bonus = log(float(max_combo) + 1.0) * 6.0 

	var grade_bonus = 0.0
	var grade = _calculate_grade()
	match grade:
		"SS": grade_bonus = 50.0
		"S":  grade_bonus = 25.0
		"A":  grade_bonus = 10.0
		"B":  grade_bonus = 3.0
	var full_combo_bonus = 0.0
	if calculated_missed_notes == 0 and calculated_total_notes > 0:
		full_combo_bonus = 15.0

	var total_xp = int(base_xp + accuracy_bonus + combo_bonus + grade_bonus + full_combo_bonus)
	if _modifiers_block_rewards():
		return 0
	return max(1, total_xp)

func _modifiers_block_rewards() -> bool:
	return _RunModifiers.blocks_track_result_save(song_info.get("modifiers", []))


func _notify_profile_milestones(
	p_song_path: String,
	instrument: String,
	mode: String,
	lanes: int,
	modifiers: Array,
	p_accuracy: float,
	grade: String,
	chart_rating: int,
	full_combo: bool,
	p_max_combo: int,
	p_score: int,
	title: String,
	artist: String,
	date_str: String,
	medals_new: Array
) -> void:
	if p_song_path == "" or not ProfileMilestonesManager:
		return
	var duration_sec := 0.0
	var bpm := 0.0
	var primary_genre := ""
	if SongLibrary:
		var md := SongLibrary.get_metadata_for_song(p_song_path)
		if md is Dictionary:
			primary_genre = str(md.get("primary_genre", ""))
			bpm = ChartDifficultyAnalyzer.parse_bpm(md.get("bpm", 0))
			var duration_text := str(md.get("duration", ""))
			if duration_text.contains(":"):
				var parts := duration_text.split(":")
				if parts.size() >= 2:
					duration_sec = float(parts[0].to_int() * 60 + parts[1].to_int())
	ProfileMilestonesManager.on_run_completed({
		"song_path": p_song_path,
		"instrument": instrument,
		"mode": mode,
		"lanes": lanes,
		"modifiers": modifiers,
		"accuracy": p_accuracy,
		"grade": grade,
		"chart_rating": chart_rating,
		"full_combo": full_combo,
		"max_combo": p_max_combo,
		"score": p_score,
		"title": title,
		"artist": artist,
		"date": date_str,
		"duration_sec": duration_sec,
		"bpm": bpm,
		"primary_genre": primary_genre,
		"medals_new": medals_new,
	})
	var _DiaryCelebration = preload("res://logic/ui/diary_celebration.gd")
	_DiaryCelebration.flush_from_node(self)

func _setup_recommendation() -> void:
	_recommendation = {}
	if song_info.is_empty() or str(song_info.get("path", "")).strip_edges() == "":
		_refresh_recommendation_display()
		return
	var engine := get_parent()
	if engine and engine.has_method("run_async"):
		engine.run_async(_pick_recommendation_async)
	else:
		_recommendation = _VictoryTrackRecommender.pick_next(song_info, _calculate_grade())
		_refresh_recommendation_display()


func _pick_recommendation_async() -> void:
	var pick := _VictoryTrackRecommender.pick_next(song_info, _calculate_grade())
	call_deferred("_apply_recommendation_pick", pick)


func _apply_recommendation_pick(pick: Dictionary) -> void:
	if not is_inside_tree():
		return
	_recommendation = pick if pick is Dictionary else {}
	_refresh_recommendation_display()


func _refresh_recommendation_display() -> void:
	var has_pick := not _recommendation.is_empty() and _recommendation.get("song") is Dictionary
	if recommend_panel:
		recommend_panel.visible = has_pick
		_refresh_recommendation_chrome(has_pick)
	if next_track_button:
		next_track_button.visible = has_pick
		if has_pick:
			call_deferred("_refresh_next_track_button_chrome")
	if not has_pick:
		return
	var song: Dictionary = _recommendation.get("song", {})
	if recommend_title_label:
		recommend_title_label.text = tr("VICTORY_RECOMMEND_SECTION")
	if recommend_next_label:
		recommend_next_label.text = tr("VICTORY_RECOMMEND_NEXT_LABEL")
	_refresh_recommend_cover(song)
	if recommend_song_label:
		var names := _VictoryTrackRecommender.get_display_names(song)
		var artist := String(names.get("artist", ""))
		var title := String(names.get("title", ""))
		if artist == "" or artist == "Неизвестен" or artist == "Unknown":
			artist = tr("VALUE_UNKNOWN_ARTIST")
		if title == "" or title == "Без названия":
			title = tr("VALUE_NO_TITLE")
		recommend_song_label.text = "%s\u00A0—\u00A0%s" % [artist, title]
		recommend_song_label.clip_text = false
	if recommend_reason_label:
		recommend_reason_label.text = _format_recommendation_reason(_recommendation, song)
	_refresh_recommend_difficulty_display(song)


func _refresh_recommendation_chrome(active: bool) -> void:
	if recommend_icon_panel:
		_apply_poster_frame(recommend_icon_panel, active)
	if recommend_panel == null:
		return
	_UiMotionEffects.stop_panel_border_pulse(recommend_panel)
	if active:
		_UiMotionEffects.pulse_panel_border(recommend_panel, _ACCENT_CYAN, 0.22, 0.48, 1.35)


func _run_scope() -> Dictionary:
	return {
		"instrument": str(song_info.get("instrument", "standard")),
		"mode": str(song_info.get("mode", "basic")),
		"lanes": int(song_info.get("lanes", 4)),
		"modifiers": _normalized_run_modifiers(),
		"modifier_params": _normalized_run_modifier_params(),
	}


func _normalized_run_modifiers() -> Array:
	var mods: Array = song_info.get("modifiers", [])
	if not mods is Array:
		return []
	return mods.duplicate()


func _normalized_run_modifier_params() -> Dictionary:
	var params: Dictionary = song_info.get("modifier_params", {})
	if not params is Dictionary:
		params = {}
	return _RunModifiers.sync_params_from_modifiers(_normalized_run_modifiers(), params)


func _difficulty_snapshot_for_chart(song_path: String, scope: Dictionary) -> Dictionary:
	if song_path.strip_edges() == "":
		return {}
	var base := ChartDifficultyAnalyzer.ensure_persisted(
		song_path,
		str(scope.get("instrument", "standard")),
		str(scope.get("mode", "basic")),
		int(scope.get("lanes", 4))
	)
	if base.is_empty():
		return {}
	var mods: Array = scope.get("modifiers", [])
	if not mods is Array:
		mods = []
	var params: Dictionary = scope.get("modifier_params", {})
	if not params is Dictionary:
		params = {}
	params = _RunModifiers.sync_params_from_modifiers(mods, params)
	var snapshot := ChartDifficultyAnalyzer.build_rating_snapshot(base, mods, params)
	var display_decimal := float(
		snapshot.get("effective_decimal", 0.0)
		if bool(snapshot.get("has_mods", false))
		else snapshot.get("base_decimal", 0.0)
	)
	if display_decimal <= 0.0:
		return {}
	var tier_color := ChartDifficultyAnalyzer.rating_color_for_decimal(display_decimal)
	return {
		"snapshot": snapshot,
		"display_decimal": display_decimal,
		"tier_color": tier_color,
	}


func _refresh_recommend_difficulty_display(song: Dictionary) -> void:
	var row_visible := false
	if recommend_difficulty_row:
		recommend_difficulty_row.visible = false
	var song_path := str(song.get("path", "")).replace("\\", "/")
	var scope := _run_scope()
	var data := _difficulty_snapshot_for_chart(song_path, scope)
	if data.is_empty():
		return
	var display_decimal := float(data.get("display_decimal", 0.0))
	var tier_color: Color = data.get("tier_color", Color.WHITE)
	var snapshot: Dictionary = data.get("snapshot", {})
	if recommend_difficulty_meter:
		recommend_difficulty_meter.set_decimal_rating(
			minf(display_decimal, float(ChartDifficultyAnalyzer.MAX_RATING)),
			tier_color
		)
		recommend_difficulty_meter.tooltip_text = ChartDifficultyAnalyzer.format_effective_tooltip(snapshot)
	if recommend_difficulty_value_label:
		recommend_difficulty_value_label.text = ChartDifficultyAnalyzer.format_decimal_rating(
			display_decimal,
			true
		)
		recommend_difficulty_value_label.add_theme_color_override("font_color", Color.WHITE)
		recommend_difficulty_value_label.modulate = tier_color
		recommend_difficulty_value_label.tooltip_text = ChartDifficultyAnalyzer.format_effective_tooltip(snapshot)
	row_visible = true
	if recommend_difficulty_row:
		recommend_difficulty_row.visible = row_visible


func _format_recommendation_reason(recommendation: Dictionary, song: Dictionary) -> String:
	var criterion: int = int(recommendation.get("criterion", _VictoryTrackRecommender.Criterion.RANDOM))
	var detail := str(recommendation.get("detail", ""))
	if _recommendation_has_similar_difficulty(song):
		return tr("VICTORY_RECOMMEND_REASON_SIMILAR")
	match criterion:
		_VictoryTrackRecommender.Criterion.SIMILAR_BPM:
			var bpm := int(detail) if detail.is_valid_int() else 0
			return tr("VICTORY_RECOMMEND_REASON_BPM") % bpm
		_VictoryTrackRecommender.Criterion.SIMILAR_GENRE:
			if detail == "":
				return tr("VICTORY_RECOMMEND_REASON_RANDOM")
			return tr("VICTORY_RECOMMEND_REASON_GENRE") % detail
		_VictoryTrackRecommender.Criterion.HARDER:
			if detail == "":
				return tr("VICTORY_RECOMMEND_REASON_RANDOM")
			return tr("VICTORY_RECOMMEND_REASON_HARDER") % detail
		_:
			return tr("VICTORY_RECOMMEND_REASON_RANDOM")


func _recommendation_has_similar_difficulty(song: Dictionary) -> bool:
	var current_path := str(song_info.get("path", "")).replace("\\", "/")
	var pick_path := str(song.get("path", "")).replace("\\", "/")
	if current_path == "" or pick_path == "":
		return false
	var scope := _run_scope()
	var current_data := _difficulty_snapshot_for_chart(current_path, scope)
	var pick_data := _difficulty_snapshot_for_chart(pick_path, scope)
	if current_data.is_empty() or pick_data.is_empty():
		return false
	return absf(
		float(current_data.get("display_decimal", 0.0)) - float(pick_data.get("display_decimal", 0.0))
	) <= 0.75


func _launch_recommended_track() -> void:
	if _recommendation.is_empty() or not (_recommendation.get("song") is Dictionary):
		return
	MusicManager.stop_game_music()
	MusicManager.stop_screen_ambient_music()
	MusicManager.play_select_sound()
	var launch_data := _VictoryTrackRecommender.build_launch_song_data(
		_recommendation.get("song", {}),
		song_info
	)
	var game_engine = get_parent()
	if game_engine and game_engine.has_method("get_transitions"):
		var transitions = game_engine.get_transitions()
		if transitions and transitions.has_method("open_game_with_song"):
			transitions.open_game_with_song(
				launch_data,
				str(launch_data.get("instrument", "standard")),
				results_manager,
				str(launch_data.get("mode", "basic")),
				int(launch_data.get("lanes", 4)),
				launch_data.get("modifiers", [])
			)
	queue_free()


func _on_next_track_button_pressed() -> void:
	_launch_recommended_track()


func _on_replay_button_pressed():
	MusicManager.stop_game_music()
	MusicManager.stop_screen_ambient_music()
	MusicManager.play_select_sound()
	
	var game_engine = get_parent()
	if game_engine and game_engine.has_method("get_transitions"):
		var transitions = game_engine.get_transitions()
		if transitions and transitions.has_method("open_game_with_song"):
			var instrument_to_use = song_info.get("instrument", "drums")
			# Never replay legacy "basic" as-is — resolve to current chart stem (original / arcade_*).
			var mode_to_use := _RhythmRating.normalize_mode(str(song_info.get("mode", "original")))
			var lanes_to_use = int(song_info.get("lanes", 4))
			var mods: Array = song_info.get("modifiers", [])
			song_info["mode"] = mode_to_use
			transitions.open_game_with_song(song_info, instrument_to_use, results_manager, mode_to_use, lanes_to_use, mods)
	
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE and not _grade_revealed:
			_skip_countups_to_results()
			get_viewport().set_input_as_handled()
			return
	var bindings := {
		KEY_R: _on_replay_button_pressed,
		KEY_M: _on_song_select_button_pressed,
		KEY_C: _hotkey_currency_details,
		KEY_X: _hotkey_xp_details,
	}
	if next_track_button and next_track_button.visible:
		bindings[KEY_N] = _on_next_track_button_pressed
		bindings[KEY_ENTER] = _on_next_track_button_pressed
		bindings[KEY_KP_ENTER] = _on_next_track_button_pressed
	if UiScreenHotkeys.try_handle(bindings, event, get_viewport()):
		get_viewport().set_input_as_handled()


func _hotkey_currency_details() -> void:
	if _rewards_detail_clickable:
		_show_currency_details()


func _hotkey_xp_details() -> void:
	if _rewards_detail_clickable:
		_show_xp_details()


func _on_song_select_button_pressed():
	MusicManager.stop_game_music()
	MusicManager.stop_screen_ambient_music()
	MusicManager.play_select_sound()
	
	var game_engine = get_parent()
	if game_engine and game_engine.has_method("get_transitions"):
		var transitions = game_engine.get_transitions()
		if transitions and transitions.has_method("open_song_select"):
			transitions.open_song_select()

	queue_free()

func _on_currency_label_clicked(event):
	if not _rewards_detail_clickable:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		MusicManager.play_modifier_select_sound()
		_show_currency_details()

func _show_currency_details():
	var currency_details_scene = load("res://scenes/victory_screen/victory_currency_details.tscn")
	var currency_details = currency_details_scene.instantiate()
	
	currency_details.details_closed.connect(_on_currency_details_closed)
	
	add_child(currency_details)
	UiInteractionApplier.apply_from_engine(currency_details)
	
	currency_details.show_details(
		score, 
		max_combo, 
		accuracy, 
		calculated_total_notes, 
		calculated_missed_notes, 
		calculated_combo_multiplier, 
		earned_currency
	)

func _on_currency_details_closed():
	pass

func _on_xp_label_clicked(event):
	if not _rewards_detail_clickable:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		MusicManager.play_modifier_select_sound()
		_show_xp_details()

func _show_xp_details():
	var xp_details_scene = load("res://scenes/victory_screen/victory_xp_details.tscn")
	var xp_details = xp_details_scene.instantiate()
	
	add_child(xp_details)
	UiInteractionApplier.apply_from_engine(xp_details)
	
	var grade = _calculate_grade()
	xp_details.show_details(
		score,
		max_combo,
		accuracy,
		calculated_missed_notes,
		grade,
		earned_xp
	)

func set_results_manager(results_mgr):
	results_manager = results_mgr

func set_achievement_system(ach_sys):
	if results_manager and results_manager.has_method("set_achievement_system"):
		results_manager.set_achievement_system(ach_sys)

func set_victory_data(p_score: int, p_combo: int, p_max_combo: int, p_accuracy: float, p_song_info: Dictionary = {}, p_combo_multiplier: float = 1.0, p_total_notes: int = 0, p_missed_notes: int = 0, p_perfect_hits: int = 0, p_hit_notes: int = 0):
	score = p_score
	combo = p_combo
	max_combo = p_max_combo
	accuracy = p_accuracy
	song_info = p_song_info.duplicate(true)
	
	calculated_combo_multiplier = min(4.0, 1.0 + floor(float(max_combo) / 10.0))
	
	if p_total_notes <= 0:
		calculated_total_notes = p_hit_notes + p_missed_notes
	else:
		calculated_total_notes = p_total_notes
	calculated_missed_notes = p_missed_notes
	perfect_hits_this_level = p_perfect_hits
	hit_notes_this_level = p_hit_notes 
	
	earned_currency = _calculate_currency_new()
	earned_xp = _calculate_xp_new() 

	_start_victory_screen_music()
	call_deferred("_deferred_update_ui")


func _start_victory_screen_music() -> void:
	if MusicManager == null:
		return
	if MusicManager.has_method("stop_game_music"):
		MusicManager.stop_game_music()
	if MusicManager.has_method("play_victory_screen_music"):
		MusicManager.play_victory_screen_music()

func _calculate_currency_new() -> int:
	var base_currency = sqrt(float(score)) * 0.9  

	var combo_bonus = 0.0
	if max_combo > 0:
		combo_bonus = log(float(max_combo) + 1.0) * 3.0 

	var accuracy_bonus = 0.0
	if accuracy >= 100.0:
		accuracy_bonus = 20.0
	elif accuracy >= 95.0:
		accuracy_bonus = (accuracy - 90.0) * 0.5 

	var full_combo_bonus = 0.0
	if calculated_missed_notes == 0 and calculated_total_notes > 0:
		full_combo_bonus = 10.0

	var multiplier_bonus = (calculated_combo_multiplier - 1.0) * 2.0 

	var total_currency = base_currency + combo_bonus + accuracy_bonus + full_combo_bonus + multiplier_bonus
	if _modifiers_block_rewards():
		return 0
	return max(1, int(round(total_currency)))

func _deferred_update_ui():
	_set_rewards_detail_clickable(false)
	_grade_revealed = false
	_countups_skipped = false
	if hint_label:
		hint_label.text = tr("VICTORY_SKIP_COUNTUPS_HINT")
		hint_label.visible = true
	if is_instance_valid(song_label):
		_refresh_song_label()
	_refresh_song_meta_label()
	_refresh_modifiers_display()
	if is_instance_valid(score_label):
		score_display_value = 0.0
		_last_int_score = 0

	if is_instance_valid(combo_label):
		combo_display_value = 0.0
		_last_int_combo = 0

	if is_instance_valid(max_combo_label):
		max_combo_display_value = 0.0
		_last_int_max_combo = 0
	
	if is_instance_valid(accuracy_label):
		accuracy_display_value = 0.0
		_last_acc_tenths = 0

	if is_instance_valid(grade_label):
		var grade = _calculate_grade()
		var song_path_for_color = song_info.get("path", "")
		var is_repeat_ss := grade == "SS" and GradeDisplay.is_repeat_ss_on_track(song_path_for_color)
		var grade_color = _get_grade_color(grade, is_repeat_ss)
		grade_label.text = grade
		grade_label.modulate = grade_color
		grade_label.visible = false

	run_rr = _calculate_run_rr()
	_resolve_rr_repeat_state()
	if is_instance_valid(rr_label):
		if run_rr > 0:
			rr_label.text = _format_rr_text(run_rr)
			rr_label.visible = false
		else:
			rr_label.visible = false
	
	if is_instance_valid(currency_label):
		currency_display_value = 0.0
		_last_int_currency = 0
		currency_label.modulate = Color.GOLD

	if is_instance_valid(xp_label):
		xp_display_value = 0.0
		_last_int_xp = 0
		xp_label.modulate = Color.CYAN  

	if is_instance_valid(perfect_label):
		perfect_display_value = 0.0
		_last_int_perfect = 0
	if is_instance_valid(good_label):
		good_display_value = 0.0
		_last_int_good = 0
	if is_instance_valid(miss_label):
		missed_notes_display_value = 0.0
		_last_int_miss = 0

	_setup_lane_stats()

	_ensure_chart_highlights()

	# Сначала лёгкий UI + интро; тяжёлые ассеты и диск — по кадрам, чтобы не ронять FPS.
	_start_all_countups_and_grade_reveal()
	call_deferred("_finish_deferred_update_ui")


func _ensure_chart_highlights() -> void:
	var song_path := str(song_info.get("path", ""))
	if song_path == "":
		return
	if _chart_baseline.is_empty():
		_chart_baseline = _capture_chart_baseline(song_path)
	if _run_highlights.is_empty():
		_run_highlights = _compute_run_highlights(_chart_baseline)
	_refresh_pb_banner()


func _finish_deferred_update_ui() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_refresh_cover_texture()
	_refresh_chart_difficulty_display()
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_setup_accuracy_chart()
	var song_path_early := str(song_info.get("path", ""))
	if song_path_early != "" and _chart_baseline.is_empty():
		_chart_baseline = _capture_chart_baseline(song_path_early)
	await get_tree().process_frame
	if is_inside_tree():
		_persist_run_results()
		_notify_auto_saved_replay()


func _refresh_save_run_replay_button() -> void:
	if save_run_replay_button == null:
		return
	save_run_replay_button.visible = _has_replay_export_source()


func _has_replay_export_source() -> bool:
	var replay_path := str(song_info.get("replay_path", "")).strip_edges()
	if replay_path != "":
		return true
	var payload: Variant = song_info.get("replay_payload", {})
	return payload is Dictionary and not (payload as Dictionary).is_empty()


func _replay_export_payload() -> Dictionary:
	var replay_path := str(song_info.get("replay_path", "")).strip_edges()
	if replay_path != "":
		var abs := ProjectSettings.globalize_path(replay_path)
		return _RfrCodec.read_file(abs)
	var payload: Variant = song_info.get("replay_payload", {})
	if payload is Dictionary:
		return (payload as Dictionary).duplicate(true)
	return {}


func _notify_auto_saved_replay() -> void:
	var replay_path := str(song_info.get("replay_path", "")).strip_edges()
	if replay_path == "":
		return
	_refresh_save_run_replay_button()
	_StatusToast.show_from_node(self, "replay", tr("REPLAY_SAVED_AUTO_TOAST"), "success")


func _on_save_run_replay_pressed() -> void:
	var payload := _replay_export_payload()
	if payload.is_empty():
		return
	var default_name := str(song_info.get("replay_path", "")).get_file()
	if default_name == "":
		default_name = _ReplayStore.default_filename(payload)
	_ReplayLauncher.save_file_dialog(self, default_name, payload)


func _persist_run_results() -> void:
	PlayerDataManager.add_hit_notes(hit_notes_this_level)
	PlayerDataManager.add_missed_notes(calculated_missed_notes)
	PlayerDataManager.add_currency(earned_currency)
	PlayerDataManager.add_perfect_hits(perfect_hits_this_level)
	
	var current_max_combo = PlayerDataManager.data.get("max_combo_ever", 0)
	if max_combo > current_max_combo:
		PlayerDataManager.data["max_combo_ever"] = max_combo

	var instrument_used_for_combo_check = song_info.get("instrument", "standard")
	var current_max_drum_combo = PlayerDataManager.data.get("max_drum_combo_ever", 0)
	if instrument_used_for_combo_check == "drums" and max_combo > current_max_drum_combo:
		PlayerDataManager.data["max_drum_combo_ever"] = max_combo

	var current_max_bass_combo = PlayerDataManager.data.get("max_bass_combo_ever", 0)
	if instrument_used_for_combo_check == "bass" and max_combo > current_max_bass_combo:
		PlayerDataManager.data["max_bass_combo_ever"] = max_combo

	if instrument_used_for_combo_check == "drums":
		var current_drum_hits = PlayerDataManager.data.get("total_drum_hits", 0)
		var new_drum_hits = current_drum_hits + hit_notes_this_level
		PlayerDataManager.data["total_drum_hits"] = new_drum_hits
		
		var current_drum_misses = PlayerDataManager.data.get("total_drum_misses", 0)
		var new_drum_misses = current_drum_misses + calculated_missed_notes
		PlayerDataManager.data["total_drum_misses"] = new_drum_misses

	var is_drum_mode = (instrument_used_for_combo_check == "drums")
	var is_bass_mode = (instrument_used_for_combo_check == "bass")
	PlayerDataManager.add_score_to_total(score, is_drum_mode)

	var should_save_result_later = (
		results_manager
		and song_info
		and song_info.get("path")
		and not _modifiers_block_rewards()
	)
	var song_path = song_info.get("path", "")
	var final_grade = _calculate_grade()
	var is_repeat_ss := final_grade == "SS" and GradeDisplay.is_repeat_ss_on_track(song_path)
	var grade_color_for_result = _get_grade_color(final_grade, is_repeat_ss)
	var chart_rating_for_run := 0
	if song_path != "":
		chart_rating_for_run = ChartDifficultyAnalyzer.get_run_rating(
			song_path,
			str(song_info.get("instrument", "standard")),
			str(song_info.get("mode", "basic")),
			int(song_info.get("lanes", 4))
		)
		if chart_rating_for_run > 0:
			PlayerDataManager.record_chart_difficulty_clear(chart_rating_for_run)
	if song_path != "" and _chart_baseline.is_empty():
		_chart_baseline = _capture_chart_baseline(song_path)
	if should_save_result_later:
		var instrument_for_result := str(song_info.get("instrument", "drums")).strip_edges().to_lower()
		if instrument_for_result in ["", "standard", "стандарт", "перкуссия", "percussion"]:
			instrument_for_result = "drums"
		elif instrument_for_result == "бас":
			instrument_for_result = "bass"
		# Defense-in-depth: series modes skip victory, but never write museum rows if tagged.
		var play_mode := str(song_info.get("play_mode", "")).strip_edges().to_lower()
		var save_to_museum := play_mode not in ["endless", "marathon"]
		var result_datetime_for_result = _TimeUtils.now_local_datetime_string()
		var mode_for_result := _RhythmRating.normalize_mode(str(song_info.get("mode", "basic")))
		var run_modifiers: Array = song_info.get("modifiers", [])
		if not run_modifiers is Array:
			run_modifiers = []
		var medals_earned := _TrackMedals.evaluate_run_medals(
			final_grade,
			accuracy,
			calculated_missed_notes,
			calculated_total_notes,
			run_modifiers
		)
		var full_combo_for_result := calculated_missed_notes == 0 and calculated_total_notes > 0
		var title_for_result := str(song_info.get("title", ""))
		var artist_for_result := str(song_info.get("artist", ""))
		var lanes_for_result := int(song_info.get("lanes", 4))
		var play_sec_for_result := int(song_info.get("duration_sec", song_info.get("duration", 0)))
		if play_sec_for_result <= 0:
			play_sec_for_result = int(round(float(song_info.get("length", 0))))
		if play_sec_for_result <= 0 and SongLibrary:
			var md := SongLibrary.get_metadata_for_song(str(song_info.get("path", "")))
			if md is Dictionary:
				play_sec_for_result = int(round(ChartDifficultyAnalyzer.parse_duration_seconds(md.get("duration", "00:00"))))
		var medals_new: Array = []
		if save_to_museum:
			medals_new = results_manager.save_result_for_song(
				song_info.get("path", ""),
				instrument_for_result,
				score,
				accuracy,
				final_grade,
				grade_color_for_result,
				result_datetime_for_result,
				mode_for_result,
				is_repeat_ss,
				medals_earned,
				run_modifiers,
				full_combo_for_result,
				max_combo,
				chart_rating_for_run,
				title_for_result,
				artist_for_result,
				lanes_for_result,
				run_rr,
				play_sec_for_result
			)
		_first_clear_this_run = false
		for medal_id in medals_new:
			if str(medal_id) == _TrackMedals.ID_FIRST_CLEAR:
				_first_clear_this_run = true
				break
		_medals_new_run = medals_new.duplicate()
		if _run_highlights.is_empty():
			_run_highlights = _compute_run_highlights(_chart_baseline)
		if save_to_museum:
			_notify_profile_milestones(
				song_path,
				instrument_for_result,
				mode_for_result,
				lanes_for_result,
				run_modifiers,
				accuracy,
				final_grade,
				chart_rating_for_run,
				full_combo_for_result,
				max_combo,
				score,
				title_for_result,
				artist_for_result,
				result_datetime_for_result,
				medals_new
			)

	else:
		_medals_new_run = []
		if _run_highlights.is_empty():
			_run_highlights = _compute_run_highlights(_chart_baseline)

	if !song_path.is_empty():
		PlayerDataManager.update_best_grade_for_track(song_path, final_grade)
		if final_grade == "SS" and TrackStatsManager:
			TrackStatsManager.record_ss_clear(song_path)

	var achievement_system = null
	var achievement_manager = null
	
	var game_engine = get_parent()
	if game_engine:
		if game_engine.has_method("get_achievement_system"):
			achievement_system = game_engine.get_achievement_system()
		if game_engine.has_method("get_achievement_manager"):
			achievement_manager = game_engine.get_achievement_manager()
			if achievement_manager:
				achievement_manager.notification_mgr = game_engine

	if game_engine and game_engine.has_method("get_results_history_service"):
		var results_service = game_engine.get_results_history_service()
		if results_service:
			var instrument_type_for_history = song_info.get("instrument", "standard")
			if instrument_type_for_history == "drums":
				instrument_type_for_history = "Перкуссия"
			var grade_for_history = final_grade
			var grade_color_for_history = grade_color_for_result
			var current_time_string = _TimeUtils.now_local_datetime_string()
			var artist := str(song_info.get("artist", ""))
			var title := str(song_info.get("title", ""))
			var resolved := _resolve_session_track_labels(song_path, title, artist)
			results_service.add_session_result(
				accuracy,
				current_time_string,
				grade_for_history,
				grade_color_for_history,
				instrument_type_for_history,
				score,
				resolved.artist,
				resolved.title,
				is_repeat_ss,
				run_rr,
				song_path,
			)

	if achievement_system:
		achievement_system.on_level_completed(
			accuracy,
			song_path,
			is_drum_mode,
			_calculate_grade(),
			song_info.get("modifiers", []),
			is_bass_mode
		)
	else:
		if achievement_manager:
			achievement_manager.check_first_level_achievement()
			achievement_manager.check_perfect_accuracy_achievement(accuracy)

			if is_drum_mode:
				var total_drum_levels = PlayerDataManager.get_drum_levels_completed()
				achievement_manager.check_drum_level_achievements(PlayerDataManager, accuracy, total_drum_levels)
			if is_bass_mode:
				var total_bass_levels = PlayerDataManager.get_bass_levels_completed()
				achievement_manager.check_bass_level_achievements(PlayerDataManager, accuracy, total_bass_levels, is_bass_mode)

			achievement_manager.check_score_achievements(PlayerDataManager)
			if _calculate_grade() == "SS":
				achievement_manager.check_ss_achievements(PlayerDataManager)

			achievement_manager.check_modifier_achievements(PlayerDataManager)
			achievement_manager.check_generation_achievements(PlayerDataManager)
			achievement_manager.check_medal_achievements()
			achievement_manager.check_chart_difficulty_achievements(PlayerDataManager)
			achievement_manager.check_rr_mastery_achievements()

	if achievement_manager and achievement_manager.has_method("show_all_delayed_mastery_achievements"):
		achievement_manager.show_all_delayed_mastery_achievements()
		achievement_manager.clear_new_mastery_achievements()

	PlayerDataManager.add_xp(earned_xp)
	var activity_mode := _RhythmRating.normalize_mode(str(song_info.get("mode", "basic")))
	var play_sec := int(song_info.get("duration_sec", song_info.get("duration", 0)))
	if play_sec <= 0:
		play_sec = int(round(float(song_info.get("length", 0))))
	PlayerDataManager.record_activity_run({
		"grade": final_grade,
		"mode": activity_mode,
		"instrument": str(song_info.get("instrument", "drums")),
		"play_seconds": maxi(0, play_sec),
		"currency_earned": maxi(0, int(earned_currency)),
		"cleared": true,
		"score": int(score),
		"max_combo": int(max_combo),
	})
	# Единственная немедленная запись на диск за весь блок: остальные мутации данных
	# планируют отложенный дебаунс-сейв, а здесь мы форсируем их разом.
	PlayerDataManager.flush_save()

func _start_all_countups_and_grade_reveal():
	if MusicManager and MusicManager.has_method("play_level_complete_sound"):
		MusicManager.play_level_complete_sound()
	if victory_animation_player and victory_animation_player.has_animation("VictoryIntro"):
		victory_animation_player.play("VictoryIntro")
	if countups_delay_timer:
		countups_delay_timer.start()
	else:
		_on_countups_delay_timer_timeout()


func _snap_countup_values() -> void:
	score_display_value = float(score)
	combo_display_value = float(combo)
	max_combo_display_value = float(max_combo)
	accuracy_display_value = float(accuracy)
	perfect_display_value = float(perfect_hits_this_level)
	good_display_value = float(_good_hits_this_level())
	missed_notes_display_value = float(calculated_missed_notes)
	currency_display_value = float(earned_currency)
	xp_display_value = float(earned_xp)


func _skip_countups_to_results() -> void:
	if _grade_revealed:
		return
	_countups_skipped = true
	if countups_delay_timer and not countups_delay_timer.is_stopped():
		countups_delay_timer.stop()
	if victory_animation_player:
		var anim := str(victory_animation_player.current_animation)
		if victory_animation_player.is_playing() and anim == "AllCountupsSeq":
			victory_animation_player.stop()
	_snap_countup_values()
	_reveal_grade()


func _on_countups_delay_timer_timeout():
	if victory_animation_player and victory_animation_player.has_animation("AllCountupsSeq"):
		victory_animation_player.play("AllCountupsSeq")
	else:
		score_display_value = float(score)
		combo_display_value = float(combo)
		max_combo_display_value = float(max_combo)
		accuracy_display_value = float(accuracy)
		perfect_display_value = float(perfect_hits_this_level)
		good_display_value = float(_good_hits_this_level())
		missed_notes_display_value = float(calculated_missed_notes)
		currency_display_value = float(earned_currency)
		xp_display_value = float(earned_xp)
		_reveal_grade()

func _setup_accuracy_chart() -> void:
	if accuracy_chart == null or not accuracy_chart.has_method("setup_and_cache"):
		return
	var samples: Array = []
	var raw_samples: Variant = song_info.get("accuracy_timeline", [])
	if raw_samples is Array:
		samples = raw_samples.duplicate(true)
	var duration := float(song_info.get("accuracy_timeline_duration", 0.0))
	if duration <= 0.0 and samples.size() > 0:
		var last_entry: Variant = samples[samples.size() - 1]
		if last_entry is Dictionary:
			duration = float(last_entry.get("t", 0.0))
	if duration <= 0.0:
		duration = 1.0
	accuracy_chart.setup_and_cache(samples, duration, float(accuracy))
	if accuracy_chart_title:
		accuracy_chart_title.visible = accuracy_chart.visible


func _setup_lane_stats() -> void:
	if lane_stats_chart == null or not lane_stats_chart.has_method("setup"):
		return
	var raw: Variant = song_info.get("lane_stats", [])
	var stats: Array = raw.duplicate(true) if raw is Array else []
	lane_stats_chart.setup(stats)
	var has_stats: bool = lane_stats_chart.has_method("has_data") and bool(lane_stats_chart.has_data())
	if lane_stats_panel:
		lane_stats_panel.visible = has_stats
	if lane_stats_title:
		lane_stats_title.text = tr("VICTORY_LANE_STATS_TITLE")


func _reveal_grade():
	if _grade_revealed:
		return
	_grade_revealed = true
	if hint_label:
		hint_label.visible = false
	if rewards_hint_label:
		rewards_hint_label.visible = false
	_set_rewards_detail_clickable(true)
	if not is_instance_valid(grade_label):
		return
	grade_label.visible = true
	if first_clear_label:
		first_clear_label.visible = _first_clear_this_run
	if is_instance_valid(rr_label) and run_rr > 0:
		_refresh_rr_label()
		rr_label.visible = true
	if MusicManager:
		if MusicManager.has_method("set_game_pitch_scale"):
			MusicManager.set_game_pitch_scale(1.0)
		if MusicManager.has_method("play_grade_pop_sound"):
			MusicManager.play_grade_pop_sound()
	if victory_animation_player and victory_animation_player.has_animation("GradePop"):
		grade_label.scale = Vector2(1.0, 1.0)
		victory_animation_player.play("GradePop")
	else:
		grade_label.scale = Vector2(1.0, 1.0)
	if accuracy_chart and accuracy_chart.has_method("play_reveal"):
		accuracy_chart.play_reveal()
	_refresh_run_medals_row()
	_refresh_stat_deltas()
	_refresh_xp_progress()
	_setup_lane_stats()
	_play_pb_banner_reveal()
	_setup_recommendation()
	call_deferred("_maybe_show_victory_tutorial")


func _maybe_show_victory_tutorial(force: bool = false) -> void:
	if not SettingsManager or not SettingsManager.has_method("get_tutorial_victory_done"):
		return
	if not force and SettingsManager.get_tutorial_victory_done():
		return
	if _spotlight_tutorial == null:
		_spotlight_tutorial = _SpotlightTutorialScene.instantiate() as CanvasLayer
		if _spotlight_tutorial == null:
			return
		add_child(_spotlight_tutorial)
		if not _spotlight_tutorial.finished.is_connected(_on_victory_tutorial_closed):
			_spotlight_tutorial.finished.connect(_on_victory_tutorial_closed)
		if not _spotlight_tutorial.skipped.is_connected(_on_victory_tutorial_closed):
			_spotlight_tutorial.skipped.connect(_on_victory_tutorial_closed)
	var steps: Array = [
		{
			"title_key": "TUTORIAL_VIC_1_TITLE",
			"body_key": "TUTORIAL_VIC_1_BODY",
			"target": rr_label if is_instance_valid(rr_label) and rr_label.visible else grade_label,
		},
		{
			"title_key": "TUTORIAL_VIC_2_TITLE",
			"body_key": "TUTORIAL_VIC_2_BODY",
			"targets": [_currency_row, _xp_row],
		},
		{
			"title_key": "TUTORIAL_VIC_3_TITLE",
			"body_key": "TUTORIAL_VIC_3_BODY",
			"target": accuracy_chart,
		},
		{
			"title_key": "TUTORIAL_VIC_4_TITLE",
			"body_key": "TUTORIAL_VIC_4_BODY",
			"target": replay_button,
		},
	]
	if _spotlight_tutorial.has_method("start"):
		_spotlight_tutorial.start(steps)


func _on_victory_tutorial_closed() -> void:
	if SettingsManager and SettingsManager.has_method("set_tutorial_victory_done"):
		SettingsManager.set_tutorial_victory_done(true)


func debug_show_tutorial() -> void:
	_maybe_show_victory_tutorial(true)


func _on_victory_anim_finished(anim_name: String):
	if anim_name == "AllCountupsSeq":
		score_display_value = float(score)
		combo_display_value = float(combo)
		max_combo_display_value = float(max_combo)
		accuracy_display_value = float(accuracy)
		perfect_display_value = float(perfect_hits_this_level)
		good_display_value = float(_good_hits_this_level())
		missed_notes_display_value = float(calculated_missed_notes)
		currency_display_value = float(earned_currency)
		xp_display_value = float(earned_xp)


func _resolve_session_track_labels(song_path: String, title: String, artist: String) -> Dictionary:
	var out_title := title.strip_edges()
	var out_artist := artist.strip_edges()
	if out_title == "N/A" or out_title == tr("VALUE_NO_TITLE") or out_title == "Без названия":
		out_title = ""
	if out_artist == "N/A" or out_artist == tr("VALUE_UNKNOWN_ARTIST") or out_artist in ["Неизвестен", "Unknown"]:
		out_artist = ""
	if song_path != "" and SongLibrary:
		var meta := SongLibrary.get_metadata_for_song(song_path)
		if meta.is_empty():
			for song in SongLibrary.get_songs_list():
				if typeof(song) != TYPE_DICTIONARY:
					continue
				var candidate := str(song.get("path", "")).replace("\\", "/").trim_suffix("/")
				if candidate == song_path.replace("\\", "/").trim_suffix("/"):
					meta = song
					break
		if not meta.is_empty():
			var meta_title := str(meta.get("title", "")).strip_edges()
			var meta_artist := str(meta.get("artist", "")).strip_edges()
			if meta_title != "" and meta_title != "N/A" and meta_title != "Без названия":
				out_title = meta_title
			if meta_artist != "" and meta_artist != "N/A" and meta_artist not in ["Неизвестен", "Unknown"]:
				out_artist = meta_artist
	if out_title == "" and song_path != "":
		out_title = song_path.get_file().get_basename()
	if out_title == "":
		out_title = "N/A"
	if out_artist == "":
		out_artist = "N/A"
	return {"title": out_title, "artist": out_artist}

