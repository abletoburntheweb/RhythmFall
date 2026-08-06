# scenes/defeat_screen/defeat_screen.gd
extends Control

signal song_select_requested
signal replay_requested

var score: int = 0
var max_combo: int = 0
var accuracy: float = 0.0
var song_info: Dictionary = {}

var results_manager = null

var _count_progress_internal: float = 0.0
var count_kind: String = ""
var count_start: float = 0.0
var count_target: float = 0.0
var _progress_owner_kind: String = ""
var _prev_count_kind: String = ""
var _last_tick_ms: int = 0
var _last_int_score: int = -1
var _last_int_max_combo: int = -1
var _last_acc_tenths: int = -1

var _score_display: float = 0.0
var _max_combo_display: float = 0.0
var _accuracy_display: float = 0.0

@export var count_progress: float:
	set(value):
		if count_kind != _progress_owner_kind:
			_progress_owner_kind = count_kind
			_count_progress_internal = value
		else:
			if value < _count_progress_internal:
				value = _count_progress_internal
			_count_progress_internal = value
		var t := clampf(_count_progress_internal, 0.0, 1.0)
		var v := lerpf(count_start, count_target, t)
		if t >= 0.999:
			v = count_target
		match count_kind:
			"score":
				_score_display = v
				_sync_score_label()
				var vi := int(round(v))
				if vi > _last_int_score and (Time.get_ticks_msec() - _last_tick_ms) >= 50:
					_last_int_score = vi
					_last_tick_ms = Time.get_ticks_msec()
					if MusicManager and MusicManager.has_method("play_score_tick"):
						MusicManager.play_score_tick()
			"max_combo":
				_max_combo_display = v
				_sync_max_combo_label()
				var vm := int(round(v))
				if vm > _last_int_max_combo and (Time.get_ticks_msec() - _last_tick_ms) >= 50:
					_last_int_max_combo = vm
					_last_tick_ms = Time.get_ticks_msec()
					if MusicManager and MusicManager.has_method("play_score_tick"):
						MusicManager.play_score_tick()
			"accuracy":
				_accuracy_display = v
				_sync_accuracy_label()
				var at := int(round(v * 10.0))
				if at > _last_acc_tenths and (Time.get_ticks_msec() - _last_tick_ms) >= 50:
					_last_acc_tenths = at
					_last_tick_ms = Time.get_ticks_msec()
					if MusicManager and MusicManager.has_method("play_score_tick"):
						MusicManager.play_score_tick()
	get:
		return _count_progress_internal

@onready var title_label: Label = $MainMargin/MainVBox/HeaderVBox/TitleLabel
@onready var song_label: Label = $MainMargin/MainVBox/HeaderVBox/SongLabel
@onready var score_label: Label = $MainMargin/MainVBox/StatsFrame/MarginContainer/ContentVBox/StatsGrid/ScoreLabel
@onready var max_combo_label: Label = $MainMargin/MainVBox/StatsFrame/MarginContainer/ContentVBox/StatsGrid/MaxComboLabel
@onready var accuracy_label: Label = $MainMargin/MainVBox/StatsFrame/MarginContainer/ContentVBox/StatsGrid/AccuracyLabel
@onready var replay_button: Button = $MainMargin/MainVBox/ButtonsContainer/ReplayButton
@onready var song_select_button: Button = $MainMargin/MainVBox/ButtonsContainer/SongSelectButton

var defeat_animation_player: AnimationPlayer = null
var _stats_finalized: bool = false

const _ICON_MUSIC := Color(0.55, 0.78, 0.98, 1.0)


func _ready() -> void:
	add_to_group("locale_refresh")
	replay_button.pressed.connect(_on_replay_button_pressed)
	song_select_button.pressed.connect(_on_song_select_button_pressed)
	defeat_animation_player = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if defeat_animation_player and not defeat_animation_player.animation_finished.is_connected(_on_defeat_anim_finished):
		defeat_animation_player.animation_finished.connect(_on_defeat_anim_finished)
	call_deferred("_setup_ui_icons")
	call_deferred("apply_locale")


func _setup_ui_icons() -> void:
	UiIconHelper.configure_button_icon(replay_button, "repeat.svg", UiIconHelper.ICON_NEUTRAL_BTN)
	UiIconHelper.configure_button_icon(song_select_button, "music.svg", _ICON_MUSIC)


func apply_locale() -> void:
	if title_label:
		title_label.text = tr("DEFEAT_TITLE")
	if replay_button:
		replay_button.text = tr("VICTORY_REPLAY")
	if song_select_button:
		song_select_button.text = tr("VICTORY_SONG_SELECT")
	_refresh_song_label()
	_refresh_stat_labels()


func set_results_manager(results_mgr) -> void:
	results_manager = results_mgr


func set_defeat_data(
	p_score: int,
	_combo: int,
	p_max_combo: int,
	p_accuracy: float,
	p_song_info: Dictionary = {}
) -> void:
	score = p_score
	max_combo = p_max_combo
	accuracy = p_accuracy
	song_info = p_song_info.duplicate()
	_start_defeat_screen_music()
	call_deferred("_deferred_update_ui")


func _start_defeat_screen_music() -> void:
	if MusicManager == null:
		return
	if MusicManager.has_method("stop_game_music"):
		MusicManager.stop_game_music()
	if MusicManager.has_method("play_defeat_screen_music"):
		MusicManager.play_defeat_screen_music()


func set_count_kind(kind: String) -> void:
	if _prev_count_kind != "":
		match _prev_count_kind:
			"score":
				_score_display = float(score)
			"max_combo":
				_max_combo_display = float(max_combo)
			"accuracy":
				_accuracy_display = float(accuracy)
	count_kind = kind
	match kind:
		"score":
			count_start = _score_display
			count_target = float(score)
		"max_combo":
			count_start = _max_combo_display
			count_target = float(max_combo)
		"accuracy":
			count_start = _accuracy_display
			count_target = float(accuracy)
	_prev_count_kind = kind


func _deferred_update_ui() -> void:
	_stats_finalized = false
	_score_display = 0.0
	_max_combo_display = 0.0
	_accuracy_display = 0.0
	_last_int_score = 0
	_last_int_max_combo = 0
	_last_acc_tenths = 0
	_refresh_song_label()
	_refresh_stat_labels()

	var is_drum_mode: bool = String(song_info.get("instrument", "standard")) == "drums"
	PlayerDataManager.add_score_to_total(score, is_drum_mode)
	var defeat_mode := str(song_info.get("mode", "basic"))
	var play_sec := int(song_info.get("duration_sec", song_info.get("duration", 0)))
	if play_sec <= 0:
		play_sec = int(round(float(song_info.get("length", 0))))
	PlayerDataManager.record_activity_run({
		"grade": "F",
		"mode": defeat_mode,
		"instrument": str(song_info.get("instrument", "drums")),
		"play_seconds": maxi(0, play_sec),
		"currency_earned": 0,
		"cleared": false,
		"score": int(score),
		"max_combo": int(max_combo),
	})

	if defeat_animation_player:
		modulate = Color(1.0, 1.0, 1.0, 0.0)
		defeat_animation_player.play("DefeatIntro")
		await defeat_animation_player.animation_finished
		if not _stats_finalized:
			defeat_animation_player.play("StatsCountupsSeq")
	else:
		modulate = Color(1.0, 1.0, 1.0, 1.0)
		_finalize_stats_display()


func _finalize_stats_display() -> void:
	if _stats_finalized:
		return
	_stats_finalized = true
	_score_display = float(score)
	_max_combo_display = float(max_combo)
	_accuracy_display = float(accuracy)
	_refresh_stat_labels()


func _skip_countups_to_results() -> void:
	if _stats_finalized:
		return
	if defeat_animation_player and defeat_animation_player.is_playing():
		defeat_animation_player.stop()
	_finalize_stats_display()


func _on_defeat_anim_finished(anim_name: StringName) -> void:
	if str(anim_name) == "StatsCountupsSeq":
		_finalize_stats_display()


func _refresh_song_label() -> void:
	if not is_instance_valid(song_label) or song_info.is_empty():
		return
	var artist := String(song_info.get("artist", tr("VALUE_UNKNOWN_ARTIST")))
	var title := String(song_info.get("title", tr("VALUE_NO_TITLE")))
	if artist == "Неизвестен" or artist == "Unknown":
		artist = tr("VALUE_UNKNOWN_ARTIST")
	if title == "Без названия":
		title = tr("VALUE_NO_TITLE")
	song_label.text = "%s\u00A0—\u00A0%s" % [artist.strip_edges(), title.strip_edges()]


func _refresh_stat_labels() -> void:
	_sync_score_label()
	_sync_max_combo_label()
	_sync_accuracy_label()


func _sync_score_label() -> void:
	if score_label:
		score_label.text = tr("GAME_SCORE_FMT") % int(round(_score_display))


func _sync_max_combo_label() -> void:
	if max_combo_label:
		max_combo_label.text = tr("VICTORY_MAX_COMBO_FMT") % int(round(_max_combo_display))


func _sync_accuracy_label() -> void:
	if accuracy_label:
		accuracy_label.text = tr("VICTORY_ACCURACY_FMT") % _accuracy_display


func _on_replay_button_pressed() -> void:
	MusicManager.stop_screen_ambient_music()
	MusicManager.play_restart_sound()
	replay_requested.emit()


func _on_song_select_button_pressed() -> void:
	MusicManager.stop_screen_ambient_music()
	MusicManager.play_select_sound()
	song_select_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE and not _stats_finalized:
			_skip_countups_to_results()
			get_viewport().set_input_as_handled()
			return
	var bindings := {
		KEY_R: _on_replay_button_pressed,
		KEY_M: _on_song_select_button_pressed,
	}
	if UiScreenHotkeys.try_handle(bindings, event, get_viewport()):
		get_viewport().set_input_as_handled()
