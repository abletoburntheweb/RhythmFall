# scenes/pause_menu/pause_menu.gd
extends Control

signal resume_requested
signal restart_requested
signal song_select_requested
signal settings_requested
signal exit_to_menu_requested
signal end_series_requested

const _CoverLoader = preload("res://scenes/song_select/rhythm_dna/lib/rhythm_dna_cover_loader.gd")
const _GoalDiff = preload("res://logic/domain/generation/generation_goal_difficulty.gd")
const _COVER_SHADER = preload("res://shaders/achievement_card.gdshader")

var transitions = null
var _endless_mode: bool = false
var _endless_stats: Dictionary = {}
var _run_stats: Dictionary = {}
var _layout_ready: bool = false
var _cover_token: int = 0

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
const _ICON_SETTINGS := Color(0.52, 0.76, 0.92, 1.0)
const _ICON_EXIT := Color(0.72, 0.78, 0.88, 1.0)
const _ICON_END_SERIES := Color(0.92, 0.48, 0.62, 1.0)
const _COVER_PX := 140


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
		var cover_style := StyleBoxFlat.new()
		cover_style.bg_color = Color(0.05, 0.06, 0.09, 1.0)
		cover_style.border_color = Color(0.38, 0.78, 0.74, 0.45)
		cover_style.set_border_width_all(1)
		cover_style.border_width_top = 3
		cover_style.set_corner_radius_all(12)
		cover_style.set_content_margin_all(4)
		_cover_wrap.add_theme_stylebox_override("panel", cover_style)
		_cover_rect = TextureRect.new()
		_cover_rect.custom_minimum_size = Vector2(_COVER_PX, _COVER_PX)
		_cover_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_cover_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_cover_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var mat := ShaderMaterial.new()
		mat.shader = _COVER_SHADER
		mat.set_shader_parameter("corner_radius_px", 14.0)
		_cover_rect.material = mat
		_cover_wrap.add_child(_cover_rect)
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
		_restart_button.text = tr("PAUSE_RESTART")
	if _song_select_button:
		_song_select_button.text = tr("PAUSE_SONG_SELECT")
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
	UiIconHelper.configure_button_icon(_settings_button, "settings.svg", _ICON_SETTINGS)
	UiIconHelper.configure_button_icon(_end_series_button, "flag.svg", _ICON_END_SERIES)
	UiIconHelper.configure_button_icon(_exit_button, "log-out.svg", _ICON_EXIT)


func set_transitions(transitions_instance):
	transitions = transitions_instance


func _on_resume_pressed():
	MusicManager.play_select_sound()
	resume_requested.emit()


func _on_restart_pressed():
	restart_requested.emit()


func _on_song_select_pressed():
	MusicManager.play_select_sound()
	if transitions:
		transitions.open_song_select()
	else:
		printerr("PauseMenu.gd: transitions не установлен!")


func _on_settings_pressed():
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
	MusicManager.play_cancel_sound()
	exit_to_menu_requested.emit()


func _on_end_series_pressed() -> void:
	MusicManager.play_cancel_sound()
	end_series_requested.emit()


func _visible_action_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for b in [_resume_button, _restart_button, _song_select_button, _settings_button, _end_series_button, _exit_button]:
		if b and b.visible:
			buttons.append(b)
	return buttons


func _unhandled_input(event: InputEvent) -> void:
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
