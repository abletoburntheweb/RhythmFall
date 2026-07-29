# logic/game_engine.gd
extends Control

const CatalogDataSyncLib = preload("res://logic/domain/library/catalog_data_sync.gd")
const _Overlay = preload("res://logic/ui/app_overlay_helpers.gd")
const _ConfirmOverlayScene = preload("res://ui/overlays/app_confirm_overlay.tscn")
const _ChoiceOverlayScene = preload("res://ui/overlays/app_choice_overlay.tscn")

var _exit_confirm_overlay: AppConfirmOverlay = null
var _exit_choice_overlay: AppChoiceOverlay = null
var _exit_flow_running := false

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
@onready var version_label: Label = $FPSLayer/VersionLabel

@onready var level_label: Label = $XPContainer/LevelRow/LevelLabel
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
@onready var status_dock: StatusDock = $NotificationsLayer/StatusDock
@onready var loading_overlay: LoadingOverlay = $LoadingLayer/LoadingOverlay
@onready var ambient_background: AmbientBackground = $AmbientBackground

func _ready():
	var started_ms := Time.get_ticks_msec()
	WindowIconApplier.apply_deferred(get_tree())
	initialize_logic()
	initialize_screens()
	call_deferred("show_intro")
	_session_start_time_ticks = Time.get_ticks_msec() 
	_start_play_time_timer()
	
	_initialize_display_settings()
	_connect_level_signals()
	_initialize_theme()
	_apply_console_state()
	_update_currency_ui()
	_apply_version_label()
	add_to_group("locale_refresh")
	if LocaleManager and not LocaleManager.locale_changed.is_connected(_on_locale_changed_hud):
		LocaleManager.locale_changed.connect(_on_locale_changed_hud)
	if level_layer:
		level_layer.visibility_changed.connect(_on_level_layer_visibility_changed)
	if xp_anim_player:
		xp_anim_player.animation_finished.connect(_on_xp_anim_finished)
	print("[Perf] GameEngine ready: %d ms" % [Time.get_ticks_msec() - started_ms])
	call_deferred("set_ambient_motion_active", true)
	call_deferred("_apply_ambient_particles_setting")


func _apply_ambient_particles_setting() -> void:
	if ambient_background:
		ambient_background.set_particles_enabled(SettingsManager.get_ambient_particles_enabled())


func apply_ambient_settings() -> void:
	_apply_ambient_particles_setting()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not _exit_flow_running:
			_exit_flow_running = true
			call_deferred("_run_wm_close_exit_flow")


func _run_wm_close_exit_flow() -> void:
	await request_application_exit()
	_exit_flow_running = false


func _ensure_exit_confirm_overlay() -> AppConfirmOverlay:
	if _exit_confirm_overlay == null or not is_instance_valid(_exit_confirm_overlay):
		_exit_confirm_overlay = _ConfirmOverlayScene.instantiate() as AppConfirmOverlay
		if _exit_confirm_overlay:
			add_child(_exit_confirm_overlay)
	return _exit_confirm_overlay


func _ensure_exit_choice_overlay() -> AppChoiceOverlay:
	if _exit_choice_overlay == null or not is_instance_valid(_exit_choice_overlay):
		_exit_choice_overlay = _ChoiceOverlayScene.instantiate() as AppChoiceOverlay
		if _exit_choice_overlay:
			add_child(_exit_choice_overlay)
	return _exit_choice_overlay


func request_application_exit() -> void:
	if background_service and background_service.has_queue_work():
		var choice_overlay := _ensure_exit_choice_overlay()
		if choice_overlay == null:
			return
		var choice := await _Overlay.choose(
			choice_overlay,
			tr("GEN_QUEUE_EXIT_MSG"),
			"warning",
			tr("GEN_QUEUE_EXIT_TITLE"),
			tr("GEN_QUEUE_EXIT_CLEAR_AND_QUIT"),
			tr("BTN_CANCEL"),
		)
		if choice != "confirm":
			return
		background_service.clear_all_queue_work(true)
		_finish_application_exit()
		return
	var confirm := _ensure_exit_confirm_overlay()
	if confirm == null:
		_finish_application_exit()
		return
	if await _Overlay.ask(
		confirm,
		tr("MAIN_EXIT_TEXT"),
		"warning",
		tr("MAIN_EXIT_TITLE"),
		tr("BTN_OK"),
		tr("BTN_CANCEL"),
	):
		_finish_application_exit()


func _finish_application_exit() -> void:
	if MusicManager and MusicManager.has_method("stop_music"):
		MusicManager.stop_music()
	if transitions and transitions.has_method("exit_game"):
		transitions.exit_game()
	else:
		get_tree().quit()


func set_ambient_motion_active(active: bool) -> void:
	if ambient_background:
		ambient_background.set_motion_active(active)


func set_ambient_screen_profile(profile: StringName) -> void:
	if ambient_background:
		ambient_background.set_screen_profile(profile)

func _on_locale_changed_hud(_locale: String) -> void:
	apply_locale()


func apply_locale() -> void:
	_update_level_ui()
	if status_dock and status_dock.has_method("apply_locale"):
		status_dock.apply_locale()

func _connect_level_signals():
	if PlayerDataManager.has_signal("level_changed"):
		PlayerDataManager.level_changed.connect(_on_level_changed)
	_update_level_ui()

func _on_level_changed(new_level: int, new_xp: int, xp_for_next_level: int):
	level_label.text = "%s %d" % [tr("HUD_LEVEL"), new_level]
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

	level_label.text = "%s %d" % [tr("HUD_LEVEL"), level]
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
	_apply_runtime_render_settings()
	_apply_window_settings()
	_update_fps_visibility()

func _initialize_theme():
	var started_ms := Time.get_ticks_msec()
	var app_theme = preload("res://ui/theme/app_theme.gd").build_theme()
	theme = app_theme
	print("[Perf] GameEngine theme build: %d ms" % [Time.get_ticks_msec() - started_ms])
	call_deferred("_apply_ui_interactions_to_tree", self)


func _apply_ui_interactions_to_tree(root: Node) -> void:
	UiInteractionApplier.apply_from_engine(root)

func _apply_runtime_render_settings() -> void:
	var quality := 0
	if SettingsManager.has_method("get_graphics_quality"):
		quality = SettingsManager.get_graphics_quality()
	var msaa_2d := Viewport.MSAA_DISABLED
	var screen_space_aa := Viewport.SCREEN_SPACE_AA_DISABLED
	var anisotropic_level := 0
	match quality:
		2:
			msaa_2d = Viewport.MSAA_8X
			screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			anisotropic_level = 4
		1:
			msaa_2d = Viewport.MSAA_2X
			screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			anisotropic_level = 2
		_:
			msaa_2d = Viewport.MSAA_DISABLED
			screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			anisotropic_level = 0
	ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_2d", int(msaa_2d))
	ProjectSettings.set_setting("rendering/anti_aliasing/quality/screen_space_aa", int(screen_space_aa))
	ProjectSettings.set_setting("rendering/textures/default_filters/anisotropic_filtering_level", anisotropic_level)
	var viewport := get_viewport()
	if viewport:
		viewport.msaa_2d = msaa_2d
		viewport.screen_space_aa = screen_space_aa
	print("[Graphics] applied quality=%d msaa_2d=%d screen_space_aa=%d anisotropic=%d" % [quality, int(msaa_2d), int(screen_space_aa), anisotropic_level])

func _apply_console_state():
	var console_node = get_tree().root.get_node_or_null("Console")
	if console_node:
		if SettingsManager.get_enable_debug_menu():
			if console_node.has_method("enable"):
				console_node.enable()
		else:
			if console_node.has_method("disable"):
				console_node.disable()

func _apply_version_label() -> void:
	if version_label:
		version_label.visible = false


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
	_apply_runtime_render_settings()
	_apply_window_settings()
	_update_fps_visibility()
	_apply_ambient_particles_setting()
	if current_screen and current_screen.has_method("refresh_playfield_layout"):
		current_screen.refresh_playfield_layout()


func auto_pause_on_unfocus() -> void:
	if current_screen and current_screen.has_method("auto_pause_on_unfocus"):
		current_screen.auto_pause_on_unfocus()


func _apply_window_settings():
	SettingsManager.apply_window_mode()

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
	if GenerationProcessManager and GenerationProcessManager.has_method("shutdown_managed_worker"):
		GenerationProcessManager.shutdown_managed_worker()

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
	_ensure_user_data_seed()

	achievement_manager = AchievementManager.new()
	
	achievement_system = AchievementSystem.new(achievement_manager, TrackStatsManager)
	achievement_manager.notification_mgr = self
	
	achievement_queue_manager = preload("res://logic/data/achievement_queue_manager.gd").new()
	add_child(achievement_queue_manager)
	
	PlayerDataManager.set_game_engine_reference(self)
	if achievement_system:
		call_deferred("_deferred_resync_achievements")

	results_history_service = preload("res://logic/data/results_history_service.gd").new()
	print("GameEngine.gd: ResultsHistoryService инициализирован.")

	transitions = preload("res://logic/core/transitions.gd").new(self)

	call_deferred("_handle_player_login")
	
	background_service = preload("res://logic/services/generation_service.gd").new(self)
	add_child(background_service)


func _deferred_resync_achievements() -> void:
	if achievement_system:
		achievement_system.resync_all()
	

func _ensure_user_notes_seed():
	var src = "res://data/notes_template"
	var dst = NotesUtils.get_notes_root()
	var src_dir = DirAccess.open(src)
	if src_dir == null:
		var exe_dir = OS.get_executable_path().get_base_dir()
		var ext_src = exe_dir.path_join("data/notes_template").replace("\\", "/")
		src_dir = DirAccess.open(ext_src)
		if src_dir == null:
			return
		else:
			src = ext_src
	var dst_dir = DirAccess.open(dst)
	if dst_dir != null:
		return
	DirAccess.make_dir_recursive_absolute(dst)
	_copy_dir_recursive(src, dst)

func _ensure_user_data_seed():
	var files := [
		"genre_groups.json",
		"shop_data.json",
		"achievements_data.json",
		"song_metadata.json"
	]
	for f in files:
		_seed_json_if_missing(f)
	call_deferred("_deferred_catalog_sync")


func _deferred_catalog_sync() -> void:
	CatalogDataSyncLib.sync_catalogs_from_bundled()


func _seed_json_if_missing(file_name: String):
	var user_path = "user://" + file_name
	var need_copy := true
	if FileAccess.file_exists(user_path):
		var text := FileAccess.open(user_path, FileAccess.READ).get_as_text().strip_edges()
		var parsed = null
		if not text.is_empty():
			var json := JSON.new()
			if json.parse(text) == OK:
				parsed = json.get_data()
		need_copy = _is_json_effectively_empty(file_name, parsed)
	if not need_copy:
		return
	var candidates := []
	candidates.append("res://data/" + file_name)
	var exe_dir = OS.get_executable_path().get_base_dir()
	candidates.append(exe_dir.path_join("data/" + file_name).replace("\\", "/"))
	for src in candidates:
		if FileAccess.file_exists(src):
			var fa = FileAccess.open(src, FileAccess.READ)
			if fa:
				var data = fa.get_buffer(fa.get_length())
				fa.close()
				DirectoryUtils.ensure_dir_for_file(user_path)
				var out = FileAccess.open(user_path, FileAccess.WRITE)
				if out:
					out.store_buffer(data)
					out.close()
			break

func _is_json_effectively_empty(file_name: String, parsed) -> bool:
	if parsed == null:
		return true
	if parsed is Dictionary:
		if parsed.is_empty():
			return true
		if file_name == "achievements_data.json":
			var arr = parsed.get("achievements", [])
			if arr is Array:
				return arr.size() == 0
			return true
		if file_name == "shop_data.json":
			var arr2 = parsed.get("items", [])
			if arr2 is Array:
				return arr2.size() == 0
			return true
		return false
	elif parsed is Array:
		return parsed.size() == 0
	return true

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

func _handle_player_login():
	PlayerDataManager.apply_daily_login_for_today()

func initialize_screens():
	intro_instance = preload("res://scenes/intro/intro_screen.tscn").instantiate()
	if intro_instance:
		if intro_instance.has_method("set_game_engine_reference"):
			intro_instance.set_game_engine_reference(self)
	call_deferred("_deferred_prepare_main_menu")


func _deferred_prepare_main_menu() -> void:
	if main_menu_instance != null and is_instance_valid(main_menu_instance):
		return
	main_menu_instance = preload("res://scenes/main_menu/main_menu.tscn").instantiate()
	if main_menu_instance == null:
		return
	if main_menu_instance.has_method("set_transitions"):
		if transitions:
			main_menu_instance.set_transitions(transitions)
		else:
			printerr("GameEngine.gd: Экземпляр Transitions равен null!")
	if transitions and transitions.has_method("set_main_menu_instance"):
		transitions.set_main_menu_instance(main_menu_instance)

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


func show_level_ui_instant() -> void:
	_pending_currency_target = -1
	_xp_pending_remainder = -1
	_pending_level_up = false
	_xp_two_phase = false
	if xp_anim_player and xp_anim_player.is_playing():
		xp_anim_player.stop()
	if currency_anim_player and currency_anim_player.is_playing():
		currency_anim_player.stop()
	if level_layer:
		level_layer.visible = true
	_update_level_ui()


func get_currency_hud_global_center() -> Vector2:
	if level_layer and not level_layer.visible:
		level_layer.visible = true
	var container := get_node_or_null("XPContainer/CurrencyContainer") as Control
	if container and is_instance_valid(container):
		return container.get_global_rect().get_center()
	if currency_label and is_instance_valid(currency_label):
		return currency_label.get_global_rect().get_center()
	return Vector2.ZERO

func get_background_service() -> GenerationService:
	return background_service

func get_results_history_service() -> ResultsHistoryService:
	return results_history_service

func get_loading_overlay() -> LoadingOverlay:
	return loading_overlay


## Запуск async Callable с Node (RefCounted не может сам стартовать корутину).
func run_async(task: Callable) -> void:
	_run_async_task(task)


func _run_async_task(task: Callable) -> void:
	if task.is_valid():
		await task.call()

func get_status_dock() -> StatusDock:
	return status_dock


func open_generation_queue_dialog() -> void:
	const _GenerationQueueUi = preload("res://logic/ui/generation_queue_ui.gd")
	_GenerationQueueUi.show_dialog(self)


func notifications_add_or_update(id: String, text: String, cancellable: bool, cancel_method: String):
	if status_dock == null:
		return
	var cancel_callable: Callable = Callable()
	if cancellable and background_service:
		cancel_callable = func(): background_service.call(cancel_method)
	status_dock.show_operation({
		"id": id,
		"title": text,
		"subtitle": "",
		"progress": 0.0,
		"compact": true,
		"cancel": cancel_callable,
		"icon_kind": "bpm" if id == "bpm" else "music",
	})


func notifications_error(id: String, text: String, retry_method: String, cancel_method: String):
	if status_dock == null:
		return
	var retry_callable: Callable = Callable()
	var cancel_callable: Callable = Callable()
	if background_service:
		retry_callable = func(): background_service.call(retry_method)
		cancel_callable = func(): background_service.call(cancel_method)
	status_dock.show_operation_message({
		"id": id,
		"text": text,
		"kind": "error",
		"duration_sec": 0.0,
		"retry": retry_callable,
		"cancel": cancel_callable,
	})


func notifications_complete(id: String, text: String):
	if status_dock == null:
		return
	status_dock.show_operation_message({
		"id": id,
		"text": text,
		"kind": "success",
		"duration_sec": 5.0,
	})
