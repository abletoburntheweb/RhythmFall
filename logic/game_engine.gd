# logic/game_engine.gd
extends Control

var transitions = null
var main_menu_instance = null
var intro_instance = null
var current_screen = null

var achievement_manager: AchievementManager = null
var achievement_system: AchievementSystem = null
var achievement_queue_manager: AchievementQueueManager = null

var results_history_service: ResultsHistoryService = null

var _session_start_time_ticks: int = 0
var _play_time_timer: SceneTreeTimer = null
const PLAY_TIME_UPDATE_INTERVAL: float = 1.0 

@onready var fps_label: Label = $FPSLayer/FPSLabel
@onready var fps_background: ColorRect = $FPSLayer/FPSBackground

@onready var level_label: Label = $XPContainer/LevelLabel
@onready var xp_progress_bar: ProgressBar = $XPContainer/XPProgressBar
@onready var xp_amount_label: Label = $XPContainer/XPAmountLabel
@onready var currency_label: Label = $XPContainer/CurrencyContainer/CurrencyLabel
@onready var xp_anim_player: AnimationPlayer = $XPContainer/XpAnimationPlayer
@onready var currency_anim_player: AnimationPlayer = $XPContainer/CurrencyAnimationPlayer
@onready var level_layer: Control = $XPContainer

var _currency_anim_progress_internal: float = 0.0
var currency_anim_start: float = 0.0
var currency_anim_target: float = 0.0
var _last_int_currency_ui: int = -1
var _last_tick_ms_currency: int = 0
@export var currency_anim_progress: float:
	set(value):
		_currency_anim_progress_internal = value
		var t = clamp(value, 0.0, 1.0)
		var v = lerp(currency_anim_start, currency_anim_target, t)
		if currency_label:
			currency_label.text = str(int(round(v)))
		var vi = int(round(v))
		if vi > _last_int_currency_ui and (Time.get_ticks_msec() - _last_tick_ms_currency) >= 50:
			_last_int_currency_ui = vi
			_last_tick_ms_currency = Time.get_ticks_msec()
			if MusicManager and MusicManager.has_method("play_score_tick"):
				MusicManager.play_score_tick()
	get:
		return _currency_anim_progress_internal

var _xp_anim_progress_internal: float = 0.0
var xp_anim_start: float = 0.0
var xp_anim_target: float = 0.0
var xp_anim_max: int = 0
var _xp_pending_remainder: int = -1
var _xp_pending_next_max: int = 0
var _xp_two_phase: bool = false
var _cached_level: int = 0
var _pending_currency_target: int = -1
var _pending_level_up: bool = false
@export var xp_anim_progress: float:
	set(value):
		_xp_anim_progress_internal = value
		var t = clamp(value, 0.0, 1.0)
		var v = lerp(xp_anim_start, xp_anim_target, t)
		if xp_progress_bar:
			xp_progress_bar.value = v
		if xp_amount_label:
			xp_amount_label.text = "%d / %d" % [int(round(v)), xp_anim_max]
	get:
		return _xp_anim_progress_internal

var background_service: GenerationService = null
@onready var notif_ui: Node = $NotificationsLayer/NotifHBox

func _ready():
	initialize_logic()
	initialize_screens()
	show_intro()
	_session_start_time_ticks = Time.get_ticks_msec() 
	_start_play_time_timer()
	
	_initialize_display_settings()
	_connect_level_signals()
	_initialize_theme()
	_update_currency_ui()
	if level_layer:
		level_layer.visibility_changed.connect(_on_level_layer_visibility_changed)
	if xp_anim_player:
		xp_anim_player.animation_finished.connect(_on_xp_anim_finished)

func _connect_level_signals():
	if PlayerDataManager.has_signal("level_changed"):
		PlayerDataManager.level_changed.connect(_on_level_changed)
	_update_level_ui()

func _on_level_changed(new_level: int, new_xp: int, xp_for_next_level: int):
	level_label.text = "Уровень %d" % new_level
	var level_up = new_level > _cached_level
	if not level_layer or not level_layer.is_visible_in_tree():
		_cached_level = new_level
		_pending_level_up = level_up
		if level_up:
			_xp_pending_remainder = new_xp
			_xp_pending_next_max = xp_for_next_level
			_xp_two_phase = true
		else:
			_xp_pending_remainder = -1
			_xp_pending_next_max = xp_for_next_level
			_xp_two_phase = false
		return
	if xp_progress_bar:
		var was_max = int(xp_progress_bar.max_value)
		var current_val = float(xp_progress_bar.value)
		if level_up and xp_anim_player and xp_anim_player.has_animation("XPGain"):
			xp_anim_max = was_max
			xp_anim_start = current_val
			xp_anim_target = float(was_max)
			xp_anim_progress = 0.0
			_xp_pending_remainder = new_xp
			_xp_pending_next_max = xp_for_next_level
			_xp_two_phase = true
			xp_anim_player.play("XPGain")
		else:
			if level_up and MusicManager and MusicManager.has_method("play_level_up_sound"):
				MusicManager.play_level_up_sound()
			xp_progress_bar.max_value = xp_for_next_level
			xp_anim_max = xp_for_next_level
			xp_anim_start = current_val
			xp_anim_target = float(new_xp)
			xp_anim_progress = 0.0
			if xp_anim_player and xp_anim_player.has_animation("XPGain"):
				xp_anim_player.play("XPGain")
			else:
				xp_progress_bar.value = new_xp
				if xp_amount_label:
					xp_amount_label.text = "%d / %d" % [new_xp, xp_for_next_level]
	_cached_level = new_level
	_update_currency_ui()

func _update_level_ui():
	var level = PlayerDataManager.get_current_level()
	var total_xp = PlayerDataManager.get_total_xp()
	var xp_for_next = PlayerDataManager.get_xp_for_next_level()

	level_label.text = "Уровень %d" % level
	xp_progress_bar.max_value = xp_for_next
	xp_progress_bar.value = total_xp
	xp_amount_label.text = "%d / %d" % [total_xp, xp_for_next]
	_cached_level = level
	_update_currency_ui()

func _update_currency_ui():
	if currency_label:
		currency_label.text = str(PlayerDataManager.get_currency())

func on_currency_changed():
	if not level_layer or not level_layer.is_visible_in_tree():
		_pending_currency_target = PlayerDataManager.get_currency()
		return
	var target = PlayerDataManager.get_currency()
	var current_val = 0
	if currency_label:
		var txt = String(currency_label.text)
		if txt.is_valid_int():
			current_val = int(txt)
	currency_anim_start = float(current_val)
	currency_anim_target = float(target)
	currency_anim_progress = 0.0
	_last_int_currency_ui = int(round(currency_anim_start))
	_last_tick_ms_currency = Time.get_ticks_msec()
	if currency_anim_player and currency_anim_player.has_animation("CurrencyGain"):
		currency_anim_player.play("CurrencyGain")
	else:
		_update_currency_ui()

func _on_xp_anim_finished(anim_name: String):
	if anim_name == "XPGain" and _xp_two_phase and _xp_pending_remainder >= 0:
		if MusicManager and MusicManager.has_method("play_level_up_sound"):
			MusicManager.play_level_up_sound()
		if xp_progress_bar:
			xp_progress_bar.max_value = _xp_pending_next_max
			xp_anim_max = _xp_pending_next_max
			xp_anim_start = 0.0
			xp_anim_target = float(_xp_pending_remainder)
			xp_anim_progress = 0.0
		_xp_two_phase = false
		_xp_pending_remainder = -1
		if xp_anim_player and xp_anim_player.has_animation("XPGain"):
			xp_anim_player.play("XPGain")

func _on_level_layer_visibility_changed():
	if not level_layer or not level_layer.is_visible_in_tree():
		return
	if _pending_level_up:
		_pending_level_up = false
	if _pending_currency_target >= 0:
		var current_val = 0
		if currency_label:
			var txt = String(currency_label.text)
			if txt.is_valid_int():
				current_val = int(txt)
		currency_anim_start = float(current_val)
		currency_anim_target = float(_pending_currency_target)
		currency_anim_progress = 0.0
		_last_int_currency_ui = int(round(currency_anim_start))
		_last_tick_ms_currency = Time.get_ticks_msec()
		if currency_anim_player and currency_anim_player.has_animation("CurrencyGain"):
			currency_anim_player.play("CurrencyGain")
		else:
			_update_currency_ui()
		_pending_currency_target = -1
	if _xp_pending_remainder >= 0:
		var new_xp = _xp_pending_remainder
		var next_max = _xp_pending_next_max
		_xp_pending_remainder = -1
		_xp_two_phase = false
		if xp_progress_bar:
			var was_max = int(xp_progress_bar.max_value)
			var current_val = float(xp_progress_bar.value)
			if xp_anim_player and xp_anim_player.has_animation("XPGain"):
				xp_anim_max = was_max
				xp_anim_start = current_val
				xp_anim_target = float(was_max)
				xp_anim_progress = 0.0
				_xp_pending_remainder = new_xp
				_xp_pending_next_max = next_max
				_xp_two_phase = true
				xp_anim_player.play("XPGain")
			else:
				xp_progress_bar.max_value = next_max
				xp_progress_bar.value = new_xp
				if xp_amount_label:
					xp_amount_label.text = "%d / %d" % [new_xp, next_max]
	else:
		var cur_xp = PlayerDataManager.get_total_xp()
		var next_max = PlayerDataManager.get_xp_for_next_level()
		if xp_progress_bar:
			var current_val = float(xp_progress_bar.value)
			xp_progress_bar.max_value = next_max
			xp_anim_max = next_max
			xp_anim_start = current_val
			xp_anim_target = float(cur_xp)
			xp_anim_progress = 0.0
		if xp_anim_player and xp_anim_player.has_animation("XPGain"):
			xp_anim_player.play("XPGain")
		else:
			xp_progress_bar.value = cur_xp
			if xp_amount_label:
				xp_amount_label.text = "%d / %d" % [cur_xp, next_max]

func _initialize_display_settings():
	_apply_window_settings()
	_update_fps_visibility()

func _initialize_theme():
	var theme_path = "res://ui/theme/app_theme.tres"
	var app_theme = preload("res://ui/theme/app_theme.gd").build_theme()
	theme = app_theme
	ResourceSaver.save(app_theme, theme_path)

func _update_fps_visibility():
	match SettingsManager.get_fps_mode():
		0:
			fps_label.visible = false
			fps_background.visible = false
		1: 
			fps_label.visible = true
			fps_background.visible = false
			fps_label.add_theme_color_override("font_color", Color.WHITE)
		2: 
			fps_label.visible = true
			fps_background.visible = true
			fps_label.add_theme_color_override("font_color", Color.GREEN)

func _process(delta):
	var fps_mode = SettingsManager.get_fps_mode()
	if fps_mode > 0:
		if Engine.get_process_frames() % 30 == 0: 
			fps_label.text = "FPS %d" % Engine.get_frames_per_second()

func update_display_settings():
	_apply_window_settings()
	_update_fps_visibility()

func _apply_window_settings():
	if SettingsManager.get_fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, true)
		var screen_size = DisplayServer.screen_get_size()
		var window_size = Vector2i(1920, 1080)
		DisplayServer.window_set_position((screen_size - window_size) / 2)

func _start_play_time_timer():
	_play_time_timer = get_tree().create_timer(PLAY_TIME_UPDATE_INTERVAL)
	if _play_time_timer:
		_play_time_timer.timeout.connect(_on_play_time_update_timeout)

func _on_play_time_update_timeout():
	var elapsed_ms = Time.get_ticks_msec() - _session_start_time_ticks
	var elapsed_seconds = int(elapsed_ms / 1000.0)
	PlayerDataManager.add_play_time_seconds(elapsed_seconds)
	_session_start_time_ticks = Time.get_ticks_msec()
	_start_play_time_timer()

func _exit_tree():
	_finalize_session_time()

func _finalize_session_time():
	var elapsed_ms = Time.get_ticks_msec() - _session_start_time_ticks
	var elapsed_seconds = int(elapsed_ms / 1000.0)
	PlayerDataManager.add_play_time_seconds(elapsed_seconds)
	_session_start_time_ticks = 0

func _play_time_seconds_to_string(total_seconds: int) -> String:
	var hours = total_seconds / 3600
	var minutes = (total_seconds % 3600) / 60
	return str(hours).pad_zeros(2) + ":" + str(minutes).pad_zeros(2)

func initialize_logic():
	if MusicManager.has_method("update_volumes_from_settings"):
		MusicManager.update_volumes_from_settings()
	_ensure_user_notes_seed()

	achievement_manager = AchievementManager.new()
	
	achievement_system = AchievementSystem.new(achievement_manager, TrackStatsManager)
	achievement_manager.notification_mgr = self
	
	achievement_queue_manager = preload("res://logic/achievement_queue_manager.gd").new()
	add_child(achievement_queue_manager)
	
	PlayerDataManager.set_game_engine_reference(self)
	if achievement_system:
		achievement_system.resync_all()

	results_history_service = preload("res://logic/results_history_service.gd").new()
	print("GameEngine.gd: ResultsHistoryService инициализирован.")

	transitions = preload("res://logic/transitions.gd").new(self)

	call_deferred("_handle_player_login")
	
	background_service = preload("res://logic/generation_service.gd").new(self)
	add_child(background_service)
	

func _ensure_user_notes_seed():
	var src = "res://data/notes_template"
	var dst = "user://notes"
	var src_dir = DirAccess.open(src)
	if src_dir == null:
		return
	var dst_dir = DirAccess.open(dst)
	if dst_dir != null:
		return
	DirAccess.make_dir_recursive_absolute(dst)
	_copy_dir_recursive(src, dst)

func _copy_dir_recursive(src: String, dst: String):
	var da = DirAccess.open(src)
	if da == null:
		return
	DirAccess.make_dir_recursive_absolute(dst)
	da.list_dir_begin()
	var name = da.get_next()
	while name != "":
		if name != "." and name != "..":
			var src_path = src + "/" + name
			var dst_path = dst + "/" + name
			if da.current_is_dir():
				_copy_dir_recursive(src_path, dst_path)
			else:
				var f = FileAccess.open(src_path, FileAccess.READ)
				if f:
					var data = f.get_buffer(f.get_length())
					f.close()
					var out = FileAccess.open(dst_path, FileAccess.WRITE)
					if out:
						out.store_buffer(data)
						out.close()
		name = da.get_next()
	da.list_dir_end()
func _date_dict_to_string(date_dict: Dictionary) -> String:
	if date_dict.has("year") and date_dict.has("month") and date_dict.has("day"):
		return "%04d-%02d-%02d" % [date_dict.year, date_dict.month, date_dict.day]
	return ""

func _string_to_date_dict(date_str: String) -> Dictionary:
	var parts = date_str.split("-")
	if parts.size() == 3:
		return {
			"year": parts[0].to_int(),
			"month": parts[1].to_int(),
			"day": parts[2].to_int()
		}
	return {}

func _is_yesterday(date_dict: Dictionary, today_str: String) -> bool:
	var today_parts = today_str.split("-")
	if today_parts.size() != 3:
		return false
	var today_year = today_parts[0].to_int()
	var today_month = today_parts[1].to_int()
	var today_day = today_parts[2].to_int()
	
	if date_dict.year == today_year and date_dict.month == today_month and date_dict.day == (today_day - 1):
		return true
	return false

func _handle_player_login():
	var today_dict = Time.get_date_dict_from_system()
	var today_str = _date_dict_to_string(today_dict) 
	
	var last_login_str = PlayerDataManager.data.get("last_login_date", "")
	var last_login_dict = {} 
	if last_login_str != "":
		last_login_dict = _string_to_date_dict(last_login_str) 
	
	var login_streak = PlayerDataManager.data.get("login_streak", 0)
	var new_streak = 1

	if not last_login_dict.is_empty():
		if last_login_str == today_str:
			print("[GameEngine] Игрок уже заходил сегодня.")
			new_streak = login_streak 
		elif _is_yesterday(last_login_dict, today_str):
			new_streak = login_streak + 1
			print("[GameEngine] Вход подряд. Streak: ", new_streak)
		else:
			new_streak = 1
			print("[GameEngine] Разрыв серии входов. Новый streak: ", new_streak)
	else:
		new_streak = 1
		print("[GameEngine] Первый вход или нет данных о входах. Streak: ", new_streak)

	PlayerDataManager.set_login_streak(new_streak)
	
	if achievement_system:
		achievement_system.on_daily_login()
	
func initialize_screens():
	intro_instance = preload("res://scenes/intro/intro_screen.tscn").instantiate()
	if intro_instance:
		if intro_instance.has_method("set_game_engine_reference"):
			intro_instance.set_game_engine_reference(self)

	main_menu_instance = preload("res://scenes/main_menu/main_menu.tscn").instantiate()
	if main_menu_instance:
		if main_menu_instance.has_method("set_transitions"):
			if transitions:
				main_menu_instance.set_transitions(transitions)
			else:
				printerr("GameEngine.gd: Экземпляр Transitions равен null!")

func show_intro():
	if intro_instance:
		_switch_to_screen(intro_instance)
	else:
		show_main_menu() 

func show_main_menu():
	if transitions:
		transitions.open_main_menu()
	else:
		print("GameEngine.gd: ОШИБКА! transitions не установлен!")


func _switch_to_screen(new_screen_instance):
	if current_screen and current_screen != new_screen_instance:
		current_screen.queue_free()
		current_screen = null
	if new_screen_instance:
		add_child(new_screen_instance)
		current_screen = new_screen_instance

func request_quit():
	_finalize_session_time()
	PlayerDataManager.flush_save()
	SettingsManager.save_settings()
	get_tree().quit()

func prepare_screen_exit(screen_to_exit: Node) -> bool:
	if current_screen != screen_to_exit:
		printerr("GameEngine.gd: prepare_screen_exit - переданный узел не является current_screen.")
		return false

	if screen_to_exit.has_method("cleanup_before_exit"):
		screen_to_exit.cleanup_before_exit()

	PlayerDataManager.flush_save()
	SettingsManager.save_settings()

	return true

func show_achievement_popup(achievement: Dictionary):
	print("GameEngine: Запрос на показ ачивки: ", achievement.get("title", "Unknown"))
	if achievement_queue_manager and achievement_queue_manager.is_inside_tree():
		achievement_queue_manager.add_achievement_to_queue(achievement)
	else:
		print("GameEngine: AchievementQueueManager не готов, откладываем показ ачивки")
		if not achievement_queue_manager.has_method("_delayed_achievements"):
			achievement_queue_manager._delayed_achievements = []
		achievement_queue_manager._delayed_achievements.append(achievement)
	
func get_main_menu_instance():
	return main_menu_instance

func get_transitions():
	return transitions


func get_achievement_manager() -> AchievementManager:
	return achievement_manager

func get_achievement_system() -> AchievementSystem:
	return achievement_system

func get_achievement_queue_manager() -> AchievementQueueManager:
	return achievement_queue_manager

func get_session_history_manager():
	return null

func get_level_layer() -> Control:
	return $XPContainer 

func get_background_service() -> GenerationService:
	return background_service

func get_results_history_service() -> ResultsHistoryService:
	return results_history_service

func notifications_add_or_update(id: String, text: String, cancellable: bool, cancel_method: String):
	if notif_ui and notif_ui.has_method("show_progress"):
		var cancel_callable: Callable = Callable()
		if cancellable and background_service:
			cancel_callable = func(): background_service.call(cancel_method)
		notif_ui.show_progress(text, cancel_callable)
		return

func notifications_error(id: String, text: String, retry_method: String, cancel_method: String):
	if notif_ui and notif_ui.has_method("show_error"):
		var retry_callable: Callable = Callable()
		var cancel_callable: Callable = Callable()
		if background_service:
			retry_callable = func(): background_service.call(retry_method)
			cancel_callable = func(): background_service.call(cancel_method)
		notif_ui.show_error(text, retry_callable, cancel_callable)
		return

func notifications_complete(id: String, text: String):
	if notif_ui and notif_ui.has_method("show_complete"):
		notif_ui.show_complete(text)
		return
