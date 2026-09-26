# scenes/pause_menu/pause_menu.gd
extends Control

signal resume_requested
signal restart_requested
signal practice_restart_requested
signal song_select_requested
signal settings_requested
signal exit_to_menu_requested
signal end_series_requested
signal practice_requested(start_idx: int, end_idx: int)

const _CoverLoader = preload("res://scenes/song_select/rhythm_dna/lib/rhythm_dna_cover_loader.gd")
const _GoalDiff = preload("res://logic/domain/generation/generation_goal_difficulty.gd")
const _UiFramedCover = preload("res://logic/ui/ui_framed_cover.gd")
const RhythmDnaView = preload("res://logic/data/rhythm_dna_view.gd")
const _SpotlightTutorialScene = preload("res://ui/spotlight_tutorial.tscn")

var transitions = null
var _endless_mode: bool = false
var _endless_stats: Dictionary = {}
var _run_stats: Dictionary = {}
var _layout_ready: bool = false
var _cover_token: int = 0

var _practice_available: bool = false
var _practice_run_active: bool = false
var _exit_practice_button: Button = null
var _practice_sections: Array = []
var _practice_first: int = -1
var _practice_last: int = -1
var _practice_panel: VBoxContainer = null
var _practice_panel_built: bool = false
var _practice_seg_buttons: Array = []
var _practice_range_label: Label = null
var _practice_start_button: Button = null
var _practice_preview_button: Button = null
var _practice_overlay: Control = null
var _practice_overlay_row: HBoxContainer = null
var _practice_range_fill: Panel = null
var _practice_fill_start_marker: ColorRect = null
var _practice_fill_end_marker: ColorRect = null

# Контекстная подсказка панели практики (First Steps, шаг «Практика»).
var _practice_flow_tutorial_shown: bool = false
var _spotlight_tutorial: CanvasLayer = null

# Section preview (Iteration 2): middle-click a section marker while Practice is
# open to hear that section without starting practice or touching the range.
var _preview_stop_timer: Timer = null
var _preview_active: bool = false
var _preview_end_s: float = 0.0
var _preview_start_s: float = 0.0
const _PREVIEW_FADE_SEC := 0.6

const _MAIN := "SafeMargin/RootVBox/MainRow"
const _STATS := "SafeMargin/RootVBox/MainRow/LeftStats/LeftMargin/LeftVBox"
const _ACTIONS := "SafeMargin/RootVBox/MainRow/RightActions"
const _FOOTER := "SafeMargin/RootVBox/Footer"

@onready var _main_row: HBoxContainer = get_node_or_null(_MAIN)
@onready var _stats_panel: PanelContainer = get_node_or_null(_MAIN + "/LeftStats")
@onready var _stats_vbox: VBoxContainer = get_node_or_null(_STATS)
@onready var _actions_col: VBoxContainer = get_node_or_null(_ACTIONS)
@onready var _title_label: Label = get_node_or_null(_STATS + "/TitleLabel")
@onready var _score_caption: Label = get_node_or_null(_STATS + "/RunStatsPanel/ScoreCaption")
@onready var _score_value: Label = get_node_or_null(_STATS + "/RunStatsPanel/ScoreValue")
@onready var _accuracy_caption: Label = get_node_or_null(_STATS + "/RunStatsPanel/AccuracyCaption")
@onready var _accuracy_value: Label = get_node_or_null(_STATS + "/RunStatsPanel/AccuracyValue")
@onready var _combo_caption: Label = get_node_or_null(_STATS + "/RunStatsPanel/ComboCaption")
@onready var _combo_value: Label = get_node_or_null(_STATS + "/RunStatsPanel/ComboValue")
@onready var _multiplier_caption: Label = get_node_or_null(_STATS + "/RunStatsPanel/MultiplierCaption")
@onready var _multiplier_value: Label = get_node_or_null(_STATS + "/RunStatsPanel/MultiplierValue")
@onready var _endless_stats_panel: VBoxContainer = get_node_or_null(_STATS + "/EndlessStatsPanel")
@onready var _endless_streak_label: Label = get_node_or_null(_STATS + "/EndlessStatsPanel/EndlessStreakLabel")
@onready var _endless_xp_label: Label = get_node_or_null(_STATS + "/EndlessStatsPanel/EndlessXpLabel")
@onready var _endless_rr_label: Label = get_node_or_null(_STATS + "/EndlessStatsPanel/EndlessRrLabel")
@onready var _endless_selected_label: Label = get_node_or_null(_STATS + "/EndlessStatsPanel/EndlessSelectedLabel")
@onready var _resume_button: Button = get_node_or_null(_ACTIONS + "/ResumeButton")
@onready var _restart_button: Button = get_node_or_null(_ACTIONS + "/RestartButton")
@onready var _song_select_button: Button = get_node_or_null(_ACTIONS + "/SongSelectButton")
@onready var _practice_button: Button = get_node_or_null(_ACTIONS + "/PracticeButton")
@onready var _exit_practice_placeholder: Control = get_node_or_null(_ACTIONS + "/ExitPracticePlaceholder")
@onready var _settings_button: Button = get_node_or_null(_ACTIONS + "/SettingsButton")
@onready var _end_series_button: Button = get_node_or_null(_ACTIONS + "/EndSeriesButton")
@onready var _exit_button: Button = get_node_or_null(_ACTIONS + "/ExitToMenuButton")
@onready var _track_progress: ProgressBar = get_node_or_null(_FOOTER + "/TrackProgress")
@onready var _song_meta_label: Label = get_node_or_null(_FOOTER + "/FooterMeta/SongMetaLabel")
@onready var _time_label: Label = get_node_or_null(_FOOTER + "/FooterMeta/TimeLabel")

var _cover_wrap: PanelContainer
var _cover_rect: TextureRect
var _now_title_label: Label
var _chart_meta_label: Label

const _ICON_PLAY := Color(0.38, 0.78, 0.74, 1.0)
const _ICON_RESTART := Color(0.62, 0.86, 0.72, 1.0)
const _ICON_MUSIC := Color(0.55, 0.78, 0.98, 1.0)
const _ICON_PRACTICE := Color(0.98, 0.64, 0.30, 1.0)
const _ICON_SETTINGS := Color(0.52, 0.76, 0.92, 1.0)
const _ICON_EXIT := Color(0.72, 0.78, 0.88, 1.0)
const _ICON_END_SERIES := Color(0.92, 0.48, 0.62, 1.0)
const _COVER_PX := 140

# Practice accent: reuses the canonical reward/shop orange (accent_orange).
const _PRACTICE_ACCENT := Color(0.98, 0.64, 0.30, 1.0)
const _COVER_ACCENT := Color(0.62, 0.86, 0.72, 0.85)


func _ready():
	add_to_group("locale_refresh")
	_ensure_layout()
	if _end_series_button and not _end_series_button.pressed.is_connected(_on_end_series_pressed):
		_end_series_button.pressed.connect(_on_end_series_pressed)
	call_deferred("_apply_pause_ui_interactions")
	call_deferred("_setup_ui_icons")
	call_deferred("apply_locale")
	_refresh_run_stats_panel()
	_refresh_footer()


func _ensure_layout() -> void:
	if _layout_ready:
		return
	_layout_ready = true
	# Actions left (like main menu), Now Playing right.
	if _main_row and _actions_col and _stats_panel:
		var spacer := _main_row.get_node_or_null("Spacer")
		_main_row.move_child(_actions_col, 0)
		if spacer:
			_main_row.move_child(spacer, 1)
		_main_row.move_child(_stats_panel, _main_row.get_child_count() - 1)
	if _title_label and _actions_col and _title_label.get_parent() != _actions_col:
		var old_parent := _title_label.get_parent()
		if old_parent:
			old_parent.remove_child(_title_label)
		_actions_col.add_child(_title_label)
		_actions_col.move_child(_title_label, 0)
		_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _stats_panel:
		_stats_panel.custom_minimum_size = Vector2(320, 0)
		_stats_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
		_stats_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if _actions_col:
		_actions_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_actions_col.alignment = BoxContainer.ALIGNMENT_BEGIN
		_actions_col.add_theme_constant_override("separation", 10)
	_ensure_now_playing_widgets()


func _ensure_now_playing_widgets() -> void:
	if _stats_vbox == null:
		return
	if _cover_wrap == null:
		_cover_wrap = PanelContainer.new()
		_cover_wrap.name = "CoverWrap"
		_cover_wrap.custom_minimum_size = Vector2(_COVER_PX + 8, _COVER_PX + 8)
		_cover_wrap.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_cover_rect = TextureRect.new()
		_cover_rect.custom_minimum_size = Vector2(_COVER_PX, _COVER_PX)
		_cover_wrap.add_child(_cover_rect)
		# Reuse the exact framed-cover mechanism from the main menu "Last Track"
		# card: frame style, clip host, soft-mask shader, border overlay.
		_UiFramedCover.apply(_cover_wrap, _cover_rect, 12, 2, _COVER_ACCENT, Color(0.05, 0.06, 0.09, 1.0), float(_COVER_PX))
		_cover_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_stats_vbox.add_child(_cover_wrap)
		_stats_vbox.move_child(_cover_wrap, 0)
	if _now_title_label == null:
		_now_title_label = Label.new()
		_now_title_label.name = "NowPlayingTitle"
		_now_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_now_title_label.add_theme_font_size_override("font_size", 18)
		_now_title_label.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 1.0))
		_now_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
		_now_title_label.add_theme_constant_override("shadow_offset_y", 1)
		_stats_vbox.add_child(_now_title_label)
		_stats_vbox.move_child(_now_title_label, 1)
	if _chart_meta_label == null:
		_chart_meta_label = Label.new()
		_chart_meta_label.name = "ChartMetaLabel"
		_chart_meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_chart_meta_label.add_theme_font_size_override("font_size", 13)
		_chart_meta_label.add_theme_color_override("font_color", Color(0.72, 0.78, 0.88, 0.95))
		_chart_meta_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
		_chart_meta_label.add_theme_constant_override("shadow_offset_y", 1)
		_stats_vbox.add_child(_chart_meta_label)
		_stats_vbox.move_child(_chart_meta_label, 2)


func apply_locale() -> void:
	if _title_label:
		_title_label.text = tr("PAUSE_TITLE")
	if _score_caption:
		_score_caption.text = tr("PAUSE_STAT_SCORE")
	if _accuracy_caption:
		_accuracy_caption.text = tr("PAUSE_STAT_ACCURACY")
	if _combo_caption:
		_combo_caption.text = tr("PAUSE_STAT_COMBO")
	if _multiplier_caption:
		_multiplier_caption.text = tr("PAUSE_STAT_MULTIPLIER")
	if _resume_button:
		_resume_button.text = tr("PAUSE_RESUME")
	if _restart_button:
		_refresh_restart_button_label()
	if _exit_practice_button:
		_exit_practice_button.text = tr("PAUSE_EXIT_PRACTICE")
	if _song_select_button:
		_song_select_button.text = tr("PAUSE_SONG_SELECT")
	if _practice_button:
		_practice_button.text = tr("PAUSE_PRACTICE")
		# Ensure same readable size as other pause actions (was tiny 11px)
		_practice_button.add_theme_font_size_override("font_size", 16)
	if _settings_button:
		_settings_button.text = tr("MAIN_SETTINGS")
	if _end_series_button:
		_end_series_button.text = tr("ENDLESS_PAUSE_END_SERIES")
		_end_series_button.add_theme_font_size_override("font_size", 13)
		_end_series_button.clip_text = true
		_end_series_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if _exit_button:
		_exit_button.text = tr("PAUSE_EXIT_MENU")
	_refresh_endless_stats_panel()
	_refresh_run_stats_panel()
	_refresh_footer()


func configure_run_stats(stats: Dictionary = {}) -> void:
	_run_stats = stats if stats is Dictionary else {}
	_ensure_layout()
	_refresh_run_stats_panel()
	_refresh_footer()
	_kick_cover_load()


func configure_for_endless(enabled: bool, stats: Dictionary = {}) -> void:
	_endless_mode = enabled
	_endless_stats = stats if stats is Dictionary else {}
	if _end_series_button:
		_end_series_button.visible = enabled
	if _song_select_button:
		_song_select_button.visible = not enabled
	if _exit_button:
		_exit_button.text = tr("PAUSE_EXIT_MENU")
	if _endless_stats_panel:
		_endless_stats_panel.visible = enabled
	_refresh_endless_stats_panel()


func _refresh_run_stats_panel() -> void:
	_ensure_now_playing_widgets()
	var score := int(_run_stats.get("score", 0))
	var accuracy := float(_run_stats.get("accuracy", 100.0))
	var combo := int(_run_stats.get("combo", 0))
	var mult := float(_run_stats.get("multiplier", 0.0))
	if _score_value:
		_score_value.text = _format_score(score)
	if _accuracy_value:
		_accuracy_value.text = "%.1f%%" % accuracy
	if _combo_value:
		_combo_value.text = str(combo)
	var show_mult := mult > 0.0 and not is_equal_approx(mult, 1.0)
	if _multiplier_caption:
		_multiplier_caption.visible = show_mult
	if _multiplier_value:
		_multiplier_value.visible = show_mult
		if show_mult:
			_multiplier_value.text = "x%.2f" % mult
	if _now_title_label:
		_now_title_label.text = _song_meta_text()
	if _chart_meta_label:
		_chart_meta_label.text = _chart_meta_text()
		_chart_meta_label.visible = _chart_meta_label.text.strip_edges() != ""


func _song_meta_text() -> String:
	var artist := str(_run_stats.get("artist", "")).strip_edges()
	var title := str(_run_stats.get("title", "")).strip_edges()
	if title == "":
		title = "—"
	if artist != "" and artist != "Неизвестен" and artist.to_lower() != "unknown":
		return "%s — %s" % [artist, title]
	return title


func _chart_meta_text() -> String:
	var parts: PackedStringArray = []
	var mode_stem := str(_run_stats.get("mode_stem", "")).strip_edges()
	if mode_stem != "":
		var pair: Dictionary = _GoalDiff.pair_from_stem(mode_stem)
		var goal := str(pair.get("goal", ""))
		var difficulty := str(pair.get("difficulty", ""))
		var goal_key := "GEN_GOAL_%s" % goal.to_upper()
		var goal_txt := tr(goal_key)
		if goal_txt == goal_key:
			goal_txt = goal.capitalize()
		if goal == "original":
			parts.append(goal_txt)
		else:
			var diff_key := _GoalDiff.difficulty_label_key(goal, difficulty)
			var diff_txt := tr(diff_key)
			if diff_txt == diff_key:
				diff_txt = difficulty.capitalize()
			parts.append("%s · %s" % [goal_txt, diff_txt])
	var instrument := str(_run_stats.get("instrument", "")).strip_edges().to_lower()
	if instrument != "":
		var inst_key := "GEN_INST_%s" % instrument.to_upper()
		if instrument == "drums":
			inst_key = "GEN_INST_DRUMS"
		elif instrument == "standard":
			inst_key = "GEN_INST_STANDARD"
		var inst_txt := tr(inst_key)
		if inst_txt == inst_key:
			inst_txt = instrument.capitalize()
		parts.append(inst_txt)
	var bpm := float(_run_stats.get("bpm", 0.0))
	if bpm > 0.0:
		parts.append("%d BPM" % int(round(bpm)))
	return " · ".join(parts)


func _kick_cover_load() -> void:
	_cover_token += 1
	var token := _cover_token
	var path := str(_run_stats.get("song_path", "")).strip_edges()
	if path == "" or _cover_rect == null:
		return
	call_deferred("_load_cover_deferred", token, path)


func _load_cover_deferred(token: int, path: String) -> void:
	if token != _cover_token or not is_inside_tree():
		return
	var tex := _CoverLoader.load_cover_for_display(path, _COVER_PX * 2)
	if token != _cover_token or _cover_rect == null:
		return
	_cover_rect.texture = tex


func _refresh_footer() -> void:
	if _song_meta_label:
		_song_meta_label.text = _song_meta_text()
	var time_sec := maxf(0.0, float(_run_stats.get("time_sec", 0.0)))
	var duration_sec := maxf(0.0, float(_run_stats.get("duration_sec", 0.0)))
	if _time_label:
		if duration_sec > 0.0:
			_time_label.text = "%s / %s" % [_format_clock(time_sec), _format_clock(duration_sec)]
		else:
			_time_label.text = _format_clock(time_sec)
	if _track_progress:
		if duration_sec > 0.0:
			_track_progress.value = clampf(time_sec / duration_sec, 0.0, 1.0)
		else:
			_track_progress.value = 0.0


func _format_score(score: int) -> String:
	var s := str(maxi(0, score))
	var out := ""
	var i := 0
	for c_i in range(s.length() - 1, -1, -1):
		if i > 0 and i % 3 == 0:
			out = " " + out
		out = s[c_i] + out
		i += 1
	return out


func _format_clock(seconds: float) -> String:
	var total := int(floor(maxf(0.0, seconds)))
	var m := int(total / 60.0)
	var s := total % 60
	return "%d:%02d" % [m, s]


func _refresh_endless_stats_panel() -> void:
	if _endless_stats_panel == null:
		return
	if not _endless_mode:
		_endless_stats_panel.visible = false
		return
	_endless_stats_panel.visible = true
	if _endless_xp_label:
		_endless_xp_label.visible = false
	if _endless_rr_label:
		_endless_rr_label.visible = false
	var total_tracks := int(_endless_stats.get("total_tracks", 0))
	if total_tracks > 0:
		if _endless_streak_label:
			_endless_streak_label.text = tr("MARATHON_PAUSE_PROGRESS_FMT") % [
				int(_endless_stats.get("track_index", 0)),
				total_tracks,
			]
		if _endless_selected_label:
			_endless_selected_label.visible = false
		return
	var streak := int(_endless_stats.get("streak", 0))
	if _endless_streak_label:
		_endless_streak_label.text = tr("ENDLESS_PAUSE_STREAK_FMT") % streak
	if _endless_selected_label:
		var track_source := str(_endless_stats.get("track_source", ""))
		var remaining := int(_endless_stats.get("selected_remaining", -1))
		var total := int(_endless_stats.get("selected_total", 0))
		var expanded := bool(_endless_stats.get("expanded_random", false))
		if (track_source == "selected" or track_source == "playlist") and remaining >= 0 and not expanded:
			_endless_selected_label.text = tr("ENDLESS_PAUSE_SELECTED_REMAINING_FMT") % [remaining, total]
			var pool_lap := int(_endless_stats.get("pool_lap", 1))
			if pool_lap > 1:
				_endless_selected_label.text += "\n" + (tr("ENDLESS_PAUSE_POOL_LAP_FMT") % pool_lap)
			_endless_selected_label.visible = true
		elif expanded:
			_endless_selected_label.text = tr("ENDLESS_PAUSE_SELECTED_EXPANDED")
			_endless_selected_label.visible = true
		else:
			_endless_selected_label.visible = false


func _apply_pause_ui_interactions() -> void:
	UiInteractionApplier.apply_from_engine(self)


func _setup_ui_icons() -> void:
	UiIconHelper.configure_button_icon(_resume_button, "circle-play.svg", _ICON_PLAY)
	UiIconHelper.configure_button_icon(_restart_button, "repeat.svg", _ICON_RESTART)
	UiIconHelper.configure_button_icon(_song_select_button, "music.svg", _ICON_MUSIC)
	UiIconHelper.configure_button_icon(_practice_button, "target.svg", _ICON_PRACTICE)
	UiIconHelper.configure_button_icon(_settings_button, "settings.svg", _ICON_SETTINGS)
	UiIconHelper.configure_button_icon(_end_series_button, "flag.svg", _ICON_END_SERIES)
	UiIconHelper.configure_button_icon(_exit_button, "log-out.svg", _ICON_EXIT)


func set_transitions(transitions_instance):
	transitions = transitions_instance


func configure_practice(available: bool, sections: Array, is_replay_watch: bool = false) -> void:
	_practice_available = bool(available)
	_practice_sections = sections.duplicate(true) if sections is Array else []
	_practice_panel_built = false
	_reset_practice_selection()
	if _practice_button:
		_practice_button.disabled = not _practice_available
		_practice_button.visible = true
		if not _practice_available:
			if is_replay_watch or _is_replay_watch():
				_practice_button.tooltip_text = tr("PRACTICE_UNAVAILABLE_IN_REPLAY")
			elif _practice_sections.is_empty():
				_practice_button.tooltip_text = tr("PRACTICE_NO_SECTIONS_TOOLTIP")
			else:
				_practice_button.tooltip_text = tr("PAUSE_PRACTICE_HINT")
		else:
			_practice_button.tooltip_text = ""
	if _practice_panel:
		_practice_panel.visible = false
	# Pre-build the section overlay while the pause opens so the first click on
	# ПРАКТИКА reveals an already-built, already-laid-out timeline instead of an
	# intermediate "expanding bar" state (one click = fully ready panel).
	if _practice_available:
		_build_practice_overlay()
		_refresh_practice_panel_visuals()
	_sync_practice_overlay_visibility()


func _is_replay_watch() -> bool:
	var p := get_parent()
	if p and p.has_method("_replay_watch_active"):
		var v: Variant = p.call("_replay_watch_active")
		if v is bool and bool(v):
			return true
	if p and p.has_method("is_replay_watch_mode"):
		var v2: Variant = p.call("is_replay_watch_mode")
		if v2 is bool and bool(v2):
			return true
	return false


func _reset_practice_selection() -> void:
	_practice_first = -1
	_practice_last = -1
	_refresh_practice_panel_visuals()


## While a Practice run is active the pause's ПЕРЕЗАПУСТИТЬ button restarts the
## current range (emitting practice_restart_requested) instead of restarting the
## full song, and a separate ВЫЙТИ ИЗ ПРАКТИКИ button appears to end the session.
## Toggled by game_screen on every pause via configure_pause_menu_for_mode.
func set_practice_run_active(active: bool) -> void:
	_practice_run_active = bool(active)
	if _practice_run_active:
		_ensure_exit_practice_button()
	if _exit_practice_placeholder:
		_exit_practice_placeholder.visible = _practice_run_active
	if _exit_practice_button:
		_exit_practice_button.visible = _practice_run_active
	_refresh_restart_button_label()


func _ensure_exit_practice_button() -> void:
	if _exit_practice_button != null:
		return
	if _exit_practice_placeholder == null:
		return
	_exit_practice_button = Button.new()
	_exit_practice_button.name = "ExitPracticeButton"
	_exit_practice_button.text = tr("PAUSE_EXIT_PRACTICE")
	_exit_practice_button.theme_type_variation = &"FlatButtonOrange"
	_exit_practice_button.custom_minimum_size = Vector2(260, 56)
	_exit_practice_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiIconHelper.configure_button_icon(_exit_practice_button, "log-out.svg", _ICON_PRACTICE, 18)
	_exit_practice_button.pressed.connect(_on_exit_practice_pressed)
	_exit_practice_placeholder.add_child(_exit_practice_button)
	_exit_practice_button.visible = false


## During an active Practice run a separate ВЫЙТИ ИЗ ПРАКТИКИ button appears
## in its fixed placeholder. No layout shift.
func _place_exit_practice_button() -> void:
	return


func _on_exit_practice_pressed():
	stop_practice_preview()
	MusicManager.play_restart_sound()
	# Reuse the NORMAL restart path (restart_level) — same as the ordinary
	# ПЕРЕЗАПУСТИТЬ button. restart_level() ends the Practice session first
	# (_practice_stop) without counting the unfinished attempt, so no separate
	# practice-exit restart implementation is needed here.
	restart_requested.emit()


func _refresh_restart_button_label() -> void:
	if _restart_button:
		if _practice_run_active:
			_restart_button.text = tr("PAUSE_RESTART_PRACTICE")
		else:
			_restart_button.text = tr("PAUSE_RESTART")


func _on_practice_pressed():
	MusicManager.play_select_sound()
	if not _practice_available:
		return
	_toggle_practice_panel()


func _toggle_practice_panel() -> void:
	_ensure_practice_panel()
	if _practice_panel == null:
		return
	_practice_panel.visible = not _practice_panel.visible
	if _practice_panel.visible and not _practice_panel_built:
		_build_practice_panel_body()
	_sync_practice_overlay_visibility()
	if _practice_panel.visible:
		_maybe_show_practice_flow_tutorial()
	else:
		_hide_practice_flow_tutorial()


func _ensure_practice_panel() -> void:
	if _practice_panel != null:
		return
	if _actions_col == null:
		return
	_practice_panel = VBoxContainer.new()
	_practice_panel.name = "PracticePanel"
	_practice_panel.custom_minimum_size = Vector2(260, 0)
	_practice_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_practice_panel.add_theme_constant_override("separation", 8)
	# A fresh Control defaults to visible=true, which would make the FIRST
	# toggle flip it to hidden and skip the body build (two-click reveal).
	# Start hidden so the first _toggle_practice_panel opens a fully built panel.
	_practice_panel.visible = false
	if _exit_practice_placeholder and _exit_practice_placeholder.get_parent() == _actions_col:
		_actions_col.add_child(_practice_panel)
		_actions_col.move_child(_practice_panel, _exit_practice_placeholder.get_index())
	else:
		_actions_col.add_child(_practice_panel)
	_ensure_practice_overlay()


func _build_practice_panel_body() -> void:
	for child in _practice_panel.get_children():
		child.queue_free()
	_practice_seg_buttons = []

	var heading := Label.new()
	heading.text = tr("PAUSE_PRACTICE_SELECT")
	heading.add_theme_font_size_override("font_size", 14)
	heading.add_theme_color_override("font_color", _PRACTICE_ACCENT)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_practice_panel.add_child(heading)

	# Sections are overlaid directly on the existing footer TrackProgress (no
	# second progress bar / timeline is created). See _build_practice_overlay.
	_build_practice_overlay()

	_practice_range_label = Label.new()
	_practice_range_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_practice_range_label.add_theme_font_size_override("font_size", 13)
	_practice_range_label.add_theme_color_override("font_color", _PRACTICE_ACCENT.lightened(0.15))
	_practice_panel.add_child(_practice_range_label)

	var start_btn := Button.new()
	start_btn.text = tr("PAUSE_PRACTICE_START")
	start_btn.theme_type_variation = &"FlatButtonOrange"
	start_btn.custom_minimum_size = Vector2(260, 56)
	start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiIconHelper.configure_button_icon(start_btn, "circle-play.svg", _ICON_PRACTICE, 20)
	start_btn.pressed.connect(_on_practice_start_pressed)
	_practice_panel.add_child(start_btn)
	_practice_start_button = start_btn

	_practice_panel_built = true
	_refresh_practice_panel_visuals()


## Отдельный спотлайт практики (вне «Первых шагов»): показывается один раз при
## открытии панели практики и объясняет, как выбрать секцию на шкале и начать.
## Ничего не принуждает — практика доступна обычным путём в любой момент.
func _maybe_show_practice_flow_tutorial() -> void:
	if _practice_flow_tutorial_shown:
		return
	if SettingsManager == null or not SettingsManager.has_method("get_tutorial_practice_done"):
		return
	if SettingsManager.get_tutorial_practice_done():
		return
	_practice_flow_tutorial_shown = true
	var tut := _ensure_practice_tutorial()
	if tut == null:
		return
	tut.start([
		{
			"title_key": "FIRST_STEPS_PRACTICE_PANEL_TITLE",
			"body_key": "FIRST_STEPS_PRACTICE_PANEL_BODY",
			"targets": [_practice_overlay_row, _practice_start_button],
			"next_key": "FIRST_STEPS_CONTINUE",
			"hide_nav_hint": true,
		},
	])
	tut.finished.connect(_on_practice_flow_tutorial_closed, CONNECT_ONE_SHOT)
	tut.skipped.connect(_on_practice_flow_tutorial_closed, CONNECT_ONE_SHOT)


func _on_practice_flow_tutorial_closed() -> void:
	if SettingsManager and SettingsManager.has_method("set_tutorial_practice_done"):
		SettingsManager.set_tutorial_practice_done(true)
	if _spotlight_tutorial != null and is_instance_valid(_spotlight_tutorial):
		if _spotlight_tutorial.visible:
			_spotlight_tutorial.hide()


func _hide_practice_flow_tutorial() -> void:
	if _spotlight_tutorial != null and is_instance_valid(_spotlight_tutorial):
		if _spotlight_tutorial.visible:
			_spotlight_tutorial.hide()


func _ensure_practice_tutorial() -> CanvasLayer:
	if _spotlight_tutorial != null and is_instance_valid(_spotlight_tutorial):
		return _spotlight_tutorial
	_spotlight_tutorial = _SpotlightTutorialScene.instantiate() as CanvasLayer
	if _spotlight_tutorial == null:
		return null
	add_child(_spotlight_tutorial)
	return _spotlight_tutorial


func _on_section_pressed(index: int) -> void:
	_practice_first = index
	if _practice_last < 0:
		_practice_last = index
	_normalize_practice_range()
	UiModifierSounds.play_select()
	_refresh_practice_panel_visuals()


func _on_section_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_practice_last = index
			if _practice_first < 0:
				_practice_first = index
			_normalize_practice_range()
			UiModifierSounds.play_select()
			_refresh_practice_panel_visuals()
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			UiModifierSounds.play_select()
			_start_section_preview(index)
			get_viewport().set_input_as_handled()


func _on_practice_overlay_gui_input(event: InputEvent) -> void:
	# LMB-drag selection intentionally removed (QoL audit 2026-09-03)
	pass


func _ensure_preview_stop_timer() -> void:
	if _preview_stop_timer != null and is_instance_valid(_preview_stop_timer):
		return
	_preview_stop_timer = Timer.new()
	_preview_stop_timer.one_shot = true
	_preview_stop_timer.timeout.connect(_stop_section_preview)
	add_child(_preview_stop_timer)


## Middle-clicking a section marker plays that section without starting a
## Practice run and without touching the selected range. Duration follows the
## Practice Preview setting: fixed 15 seconds, or the end of the currently
## selected range (falling back to the clicked section's end when no range is
## selected).
func _start_section_preview(index: int) -> void:
	if index < 0 or index >= _practice_sections.size():
		return
	var seg: Dictionary = _practice_sections[index] if _practice_sections[index] is Dictionary else {}
	var start_s := maxf(0.0, float(seg.get("start_s", 0.0)))
	var song_path := str(_run_stats.get("song_path", "")).strip_edges()
	if song_path == "":
		return
	var mode := "short"
	if SettingsManager and SettingsManager.has_method("get_practice_preview_mode"):
		mode = SettingsManager.get_practice_preview_mode()
	var end_s := _preview_end_for(seg, start_s, mode)
	var dur := maxf(0.05, end_s - start_s)
	if _preview_stop_timer and is_instance_valid(_preview_stop_timer):
		_preview_stop_timer.stop()
	_preview_active = true
	_preview_start_s = start_s
	_preview_end_s = end_s
	MusicManager.play_game_music_at_position(song_path, start_s)
	_ensure_preview_stop_timer()
	_preview_stop_timer.wait_time = dur
	_preview_stop_timer.start()


func _preview_end_for(seg: Dictionary, start_s: float, mode: String) -> float:
	var seg_end := maxf(start_s, float(seg.get("end_s", start_s)))
	if mode == "range_end" and _practice_first >= 0 and _practice_last >= 0:
		var b := maxi(_practice_first, _practice_last)
		var last_seg: Dictionary = _practice_sections[b] if b >= 0 and b < _practice_sections.size() and _practice_sections[b] is Dictionary else {}
		var range_end := float(last_seg.get("end_s", 0.0))
		if range_end > start_s:
			return range_end
	if seg_end > start_s:
		return seg_end
	return start_s + 15.0


func _stop_section_preview() -> void:
	if _preview_active:
		MusicManager.fade_out_game_music(_PREVIEW_FADE_SEC)
	else:
		MusicManager.cancel_game_music_fade()
	_preview_active = false
	_preview_start_s = 0.0
	_preview_end_s = 0.0
	if _preview_stop_timer and is_instance_valid(_preview_stop_timer):
		_preview_stop_timer.stop()


## Public hook used by the pauser before freeing the menu on resume/restart/exit
## so the preview fades out cleanly and never leaks into the next state.
func stop_practice_preview() -> void:
	_stop_section_preview()


func _normalize_practice_range() -> void:
	if _practice_first < 0 or _practice_last < 0:
		return
	var a := mini(_practice_first, _practice_last)
	var b := maxi(_practice_first, _practice_last)
	_practice_first = a
	_practice_last = b


func _on_practice_start_pressed() -> void:
	stop_practice_preview()
	if _practice_first < 0:
		StatusToast.show_from_node(self, "practice_need_range", tr("PAUSE_PRACTICE_NEED_RANGE"), "warn", 2.0)
		return
	MusicManager.play_restart_sound()
	practice_requested.emit(_practice_first, _practice_last)


func _on_practice_preview_button_pressed() -> void:
	if _preview_active:
		_stop_section_preview()
		return
	var idx := _practice_first
	if idx < 0:
		idx = _practice_last
	if idx < 0 and _practice_sections.size() > 0:
		idx = 0
	if idx < 0 or idx >= _practice_sections.size():
		return
	_start_section_preview(idx)


func _on_practice_reset_pressed() -> void:
	_reset_practice_selection()


func _ensure_practice_overlay() -> void:
	if _practice_overlay != null and is_instance_valid(_practice_overlay):
		return
	if _track_progress == null:
		return
	_track_progress.custom_minimum_size = Vector2(0, 26)
	_practice_overlay = Control.new()
	_practice_overlay.name = "PracticeSectionOverlay"
	_practice_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_practice_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_practice_overlay.gui_input.connect(_on_practice_overlay_gui_input)
	_track_progress.add_child(_practice_overlay)

	# Solid orange range fill rendered as its own element BEHIND the (flat)
	# section buttons. Button stylebox backgrounds are suppressed by `flat`,
	# so the fill cannot be drawn through them — this Panel carries it instead.
	_practice_range_fill = Panel.new()
	_practice_range_fill.name = "PracticeRangeFill"
	_practice_range_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_practice_range_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_practice_range_fill.visible = false
	_practice_overlay.add_child(_practice_range_fill)

	_practice_fill_start_marker = ColorRect.new()
	_practice_fill_start_marker.color = Color(1, 1, 1, 0.95)
	_practice_fill_start_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_practice_fill_start_marker.anchor_left = 0.0
	_practice_fill_start_marker.anchor_right = 0.0
	_practice_fill_start_marker.offset_left = 0.0
	_practice_fill_start_marker.offset_right = 3.0
	_practice_fill_start_marker.offset_top = 2.0
	_practice_fill_start_marker.offset_bottom = -2.0
	_practice_range_fill.add_child(_practice_fill_start_marker)

	_practice_fill_end_marker = ColorRect.new()
	_practice_fill_end_marker.color = Color(1.0, 0.85, 0.5, 0.95)
	_practice_fill_end_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_practice_fill_end_marker.anchor_left = 1.0
	_practice_fill_end_marker.anchor_right = 1.0
	_practice_fill_end_marker.offset_left = -3.0
	_practice_fill_end_marker.offset_right = 0.0
	_practice_fill_end_marker.offset_top = 2.0
	_practice_fill_end_marker.offset_bottom = -2.0
	_practice_range_fill.add_child(_practice_fill_end_marker)

	_practice_overlay_row = HBoxContainer.new()
	_practice_overlay_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_practice_overlay_row.offset_left = 2.0
	_practice_overlay_row.offset_right = -2.0
	_practice_overlay_row.add_theme_constant_override("separation", 4)
	_practice_overlay_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_practice_overlay.add_child(_practice_overlay_row)


func _build_practice_overlay() -> void:
	_ensure_practice_overlay()
	if _practice_overlay_row == null:
		return
	if not _practice_seg_buttons.is_empty() and _practice_seg_buttons.size() == _practice_sections.size():
		return
	for child in _practice_overlay_row.get_children():
		child.queue_free()
	_practice_seg_buttons = []
	var total_duration := 0.0
	for seg in _practice_sections:
		if seg is Dictionary:
			total_duration = maxf(total_duration, float(seg.get("end_s", 0.0)))
	total_duration = maxf(total_duration, 1.0)
	for i in range(_practice_sections.size()):
		var seg: Dictionary = _practice_sections[i] if _practice_sections[i] is Dictionary else {}
		var start_s := float(seg.get("start_s", 0.0))
		var end_s := float(seg.get("end_s", start_s))
		var span := maxf(0.05, end_s - start_s)
		var btn := Button.new()
		btn.text = _section_label(i)
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_stretch_ratio = span / total_duration
		btn.custom_minimum_size.x = 12
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 0.95))
		btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
		btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
		btn.add_theme_constant_override("shadow_offset_y", 1)
		btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
		btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		btn.add_theme_constant_override("outline_size", 2)
		btn.tooltip_text = "%s  %s – %s\n%s" % [
			RhythmDnaView.format_section_headline(seg),
			_fmt_clock(start_s),
			_fmt_clock(end_s),
			tr("PAUSE_PRACTICE_PREVIEW_HINT"),
		]
		btn.pressed.connect(_on_section_pressed.bind(i))
		btn.gui_input.connect(_on_section_gui_input.bind(i))
		_practice_overlay_row.add_child(btn)
		_practice_seg_buttons.append(btn)


func _sync_practice_overlay_visibility() -> void:
	if _practice_overlay:
		_practice_overlay.visible = _practice_panel != null and _practice_panel.visible


func _refresh_practice_panel_visuals() -> void:
	var total_duration := 0.0
	for seg in _practice_sections:
		if seg is Dictionary:
			total_duration = maxf(total_duration, float(seg.get("end_s", 0.0)))
	total_duration = maxf(total_duration, 1.0)
	if _practice_range_label:
		if _practice_first < 0:
			_practice_range_label.text = tr("PAUSE_PRACTICE_HINT")
		else:
			var start_lbl := _section_label(_practice_first)
			var end_lbl := _section_label(_practice_last)
			_practice_range_label.text = tr("PAUSE_PRACTICE_RANGE_FMT") % [start_lbl, end_lbl]
	if _practice_range_fill:
		var has_range := _practice_first >= 0 and _practice_last >= 0
		_practice_range_fill.visible = has_range
		if has_range:
			var a := mini(_practice_first, _practice_last)
			var b := maxi(_practice_first, _practice_last)
			var first_seg: Dictionary = _practice_sections[a] if a >= 0 and a < _practice_sections.size() and _practice_sections[a] is Dictionary else {}
			var last_seg: Dictionary = _practice_sections[b] if b >= 0 and b < _practice_sections.size() and _practice_sections[b] is Dictionary else {}
			var left_t := clampf(float(first_seg.get("start_s", 0.0)) / total_duration, 0.0, 1.0)
			var right_t := clampf(
				float(last_seg.get("end_s", first_seg.get("start_s", 0.0))) / total_duration,
				left_t,
				1.0
			)
			_practice_range_fill.anchor_left = left_t
			_practice_range_fill.anchor_right = right_t
			_practice_range_fill.offset_left = 2.0
			_practice_range_fill.offset_right = -2.0
			var box := StyleBoxFlat.new()
			box.bg_color = Color(_PRACTICE_ACCENT.r, _PRACTICE_ACCENT.g, _PRACTICE_ACCENT.b, 0.85)
			box.set_corner_radius_all(4)
			box.set_border_width_all(1)
			box.border_color = _PRACTICE_ACCENT.darkened(0.15)
			_practice_range_fill.add_theme_stylebox_override("panel", box)
	for i in range(_practice_seg_buttons.size()):
		var btn: Button = _practice_seg_buttons[i]
		if btn == null:
			continue
		var in_range := _practice_first >= 0 and _practice_last >= 0 \
			and i >= mini(_practice_first, _practice_last) \
			and i <= maxi(_practice_first, _practice_last)
		var seg: Dictionary = _practice_sections[i] if i < _practice_sections.size() and _practice_sections[i] is Dictionary else {}
		var base := _segment_display_color(seg)
		if in_range:
			# Buttons stay transparent inside the range so the orange fill
			# shows through; only the letter is highlighted.
			btn.add_theme_stylebox_override("normal", _seg_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), base))
			btn.add_theme_stylebox_override("hover", _seg_style(Color(1, 1, 1, 0.10), Color(1, 1, 1, 0.35), base))
			btn.add_theme_stylebox_override("pressed", _seg_style(Color(1, 1, 1, 0.14), Color(1, 1, 1, 0.40), base))
			btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
			btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
		else:
			# Transparent so the underlying TrackProgress bar shows through; the
			# section letter stays readable via its outline/shadow.
			btn.add_theme_stylebox_override("normal", _seg_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), base))
			btn.add_theme_stylebox_override("hover", _seg_style(Color(base.r, base.g, base.b, 0.18), Color(base.r, base.g, base.b, 0.45), base))
			btn.add_theme_stylebox_override("pressed", _seg_style(Color(base.r, base.g, base.b, 0.24), Color(base.r, base.g, base.b, 0.55), base))
			btn.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 0.95))
			btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))


func _seg_style(bg: Color, border: Color, _tint: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.content_margin_left = 2.0
	s.content_margin_right = 2.0
	return s


func _segment_display_color(seg: Dictionary) -> Color:
	var letter := RhythmDnaView.section_letter(seg)
	if letter != "":
		return _section_letter_color(letter)
	var kind := String(seg.get("kind", "steady"))
	match kind:
		"quiet":
			return Color(0.32, 0.38, 0.48, 0.95)
		"sparse":
			return Color(0.28, 0.52, 0.58, 0.95)
		"dense":
			return Color(0.62, 0.42, 0.88, 0.95)
		"loud_quiet":
			return Color(0.82, 0.62, 0.28, 0.95)
		_:
			return Color(0.38, 0.58, 0.82, 0.95)


func _section_letter_color(letter: String) -> Color:
	var palette := [
		Color(0.38, 0.58, 0.82, 0.95),
		Color(0.42, 0.78, 0.62, 0.95),
		Color(0.62, 0.42, 0.88, 0.95),
		Color(0.95, 0.58, 0.42, 0.95),
		Color(0.55, 0.72, 0.88, 0.95),
		Color(0.82, 0.62, 0.28, 0.95),
	]
	var code := 0
	for i in letter.length():
		code = (code * 31 + letter.unicode_at(i)) & 0x7FFFFFFF
	return palette[code % palette.size()]


func _section_label(index: int) -> String:
	if index < 0 or index >= _practice_sections.size():
		return "—"
	var seg: Dictionary = _practice_sections[index] if _practice_sections[index] is Dictionary else {}
	# Compact short labels for pause timeline/range: I / V1 / C etc. via existing short formatter
	var short := RhythmDnaView.format_section_short(seg)
	if short.strip_edges() != "":
		return short
	var headline := RhythmDnaView.format_section_headline(seg)
	if headline.strip_edges() != "":
		return headline
	var letter := RhythmDnaView.section_letter(seg)
	if letter != "":
		return letter
	return str(index + 1)


func _fmt_clock(seconds: float) -> String:
	var total := int(floor(maxf(0.0, seconds)))
	var m := int(total / 60.0)
	var s := total % 60
	return "%d:%02d" % [m, s]


func _on_resume_pressed():
	stop_practice_preview()
	resume_requested.emit()


func _on_restart_pressed():
	stop_practice_preview()
	if _practice_run_active:
		practice_restart_requested.emit()
	else:
		restart_requested.emit()


func _on_song_select_pressed():
	stop_practice_preview()
	MusicManager.play_select_sound()
	if transitions:
		transitions.open_song_select(true)
	else:
		printerr("PauseMenu.gd: transitions не установлен!")


func _on_settings_pressed():
	stop_practice_preview()
	MusicManager.play_select_sound()
	if transitions:
		transitions.open_settings(true)
	else:
		printerr("PauseMenu.gd: transitions не установлен!")


func _on_help_pressed() -> void:
	MusicManager.play_select_sound()
	if transitions:
		transitions.open_help(true)
	else:
		printerr("PauseMenu.gd: transitions не установлен!")


func _on_exit_to_menu_pressed():
	stop_practice_preview()
	MusicManager.play_cancel_sound()
	exit_to_menu_requested.emit()


func _on_end_series_pressed() -> void:
	stop_practice_preview()
	MusicManager.play_cancel_sound()
	end_series_requested.emit()


func _visible_action_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for b in [_resume_button, _restart_button, _exit_practice_button, _song_select_button, _practice_button, _settings_button, _end_series_button, _exit_button]:
		if b and b.visible:
			buttons.append(b)
	return buttons


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _practice_panel != null and _practice_panel.visible:
			if _practice_first >= 0 or _practice_last >= 0:
				_reset_practice_selection()
				get_viewport().set_input_as_handled()
				return
			_practice_panel.visible = false
			_sync_practice_overlay_visibility()
			_hide_practice_flow_tutorial()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		_on_help_pressed()
		get_viewport().set_input_as_handled()
		return
	var buttons := _visible_action_buttons()
	var bindings := {}
	for i in range(buttons.size()):
		bindings[KEY_1 + i] = _hotkey_press_pause_button.bind(i)
	if UiScreenHotkeys.try_handle(bindings, event, get_viewport()):
		get_viewport().set_input_as_handled()


func _hotkey_press_pause_button(index: int) -> void:
	var buttons := _visible_action_buttons()
	if index < 0 or index >= buttons.size():
		return
	UiScreenHotkeys.press_button(buttons[index])
