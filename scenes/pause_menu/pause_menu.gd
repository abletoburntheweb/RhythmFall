# scenes/pause_menu/pause_menu.gd
extends Control

signal resume_requested
signal restart_requested
signal song_select_requested
signal settings_requested
signal exit_to_menu_requested
signal end_series_requested

var transitions = null
var _endless_mode: bool = false
var _endless_stats: Dictionary = {}

@onready var _title_label: Label = $MenuContainer/TitleLabel
@onready var _endless_stats_panel: VBoxContainer = $MenuContainer/EndlessStatsPanel
@onready var _endless_streak_label: Label = $MenuContainer/EndlessStatsPanel/EndlessStreakLabel
@onready var _endless_xp_label: Label = $MenuContainer/EndlessStatsPanel/EndlessXpLabel
@onready var _endless_rr_label: Label = $MenuContainer/EndlessStatsPanel/EndlessRrLabel
@onready var _endless_selected_label: Label = $MenuContainer/EndlessStatsPanel/EndlessSelectedLabel
@onready var _resume_button: Button = $MenuContainer/ResumeButton
@onready var _restart_button: Button = $MenuContainer/RestartButton
@onready var _song_select_button: Button = $MenuContainer/SongSelectButton
@onready var _settings_button: Button = $MenuContainer/SettingsButton
@onready var _end_series_button: Button = $MenuContainer/EndSeriesButton
@onready var _exit_button: Button = $MenuContainer/ExitToMenuButton


const _ICON_PLAY := Color(0.38, 0.78, 0.74, 1.0)
const _ICON_RESTART := Color(0.62, 0.86, 0.72, 1.0)
const _ICON_MUSIC := Color(0.55, 0.78, 0.98, 1.0)
const _ICON_SETTINGS := Color(0.52, 0.76, 0.92, 1.0)
const _ICON_EXIT := Color(0.86, 0.52, 0.72, 1.0)
const _ICON_END_SERIES := Color(0.86, 0.52, 0.72, 1.0)


func _ready():
	add_to_group("locale_refresh")
	if _end_series_button and not _end_series_button.pressed.is_connected(_on_end_series_pressed):
		_end_series_button.pressed.connect(_on_end_series_pressed)
	call_deferred("_apply_pause_ui_interactions")
	call_deferred("_setup_ui_icons")
	call_deferred("apply_locale")


func apply_locale() -> void:
	if _title_label:
		_title_label.text = tr("PAUSE_TITLE")
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


func _refresh_endless_stats_panel() -> void:
	if _endless_stats_panel == null:
		return
	if not _endless_mode:
		_endless_stats_panel.visible = false
		return
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
	print("PauseMenu.gd: Transitions установлен")

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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		_on_help_pressed()
		get_viewport().set_input_as_handled()
		return
	var buttons: Array[Button] = [
		_resume_button,
		_restart_button,
		_song_select_button,
		_settings_button,
		_exit_button,
	]
	if _end_series_button and _end_series_button.visible:
		buttons.insert(buttons.size() - 1, _end_series_button)
	var bindings := {}
	for i in range(buttons.size()):
		bindings[KEY_1 + i] = _hotkey_press_pause_button.bind(i)
	if UiScreenHotkeys.try_handle(bindings, event, get_viewport()):
		get_viewport().set_input_as_handled()


func _hotkey_press_pause_button(index: int) -> void:
	var buttons: Array[Button] = [
		_resume_button,
		_restart_button,
		_song_select_button,
		_settings_button,
		_exit_button,
	]
	if _end_series_button and _end_series_button.visible:
		buttons.insert(buttons.size() - 1, _end_series_button)
	if index < 0 or index >= buttons.size():
		return
	UiScreenHotkeys.press_button(buttons[index])
