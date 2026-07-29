# logic/core/transitions.gd
var game_engine = null
var parent = null

var main_menu_instance = null
var _scene_cache: Dictionary = {}
var _pending_scene: Dictionary = {}
var _song_select_return_to_play_modes := false
var _session_setup_return_to_play_modes := false
var _track_picker_return_to_setup := false
var _track_picker_playlist_id := ""
var _playlist_hub_return_to_setup := false
var _playlist_hub_return_to_song_select := false
var _playlist_hub_pick_for_run := false
var _playlist_hub_browse_library := false
var _song_select_browse_playlist_id := ""
var _playlist_editor_playlist_id := ""
var _staged_endless_session_config: Dictionary = {}
var _endless_run = null
var _endless_summary_return_to_play_modes := false
var _marathon_run = null
var _marathon_finish_return_to_catalog := false
var _marathon_catalog_return_to_play_modes := false
var _marathon_catalog_open_daily_tab := false
var _screen_nav_serial: int = 0

const _EndlessRun = preload("res://logic/domain/session/endless_run.gd")
const _MarathonRun = preload("res://logic/domain/session/marathon_run.gd")
const _EndlessSessionConfig = preload("res://logic/domain/session/endless_session_config.gd")
const _PlayModeIds = preload("res://logic/domain/session/play_mode_ids.gd")
const ENDLESS_SUMMARY_SCENE := "res://scenes/series_finish/series_finish_screen.tscn"
const MARATHON_CATALOG_SCENE := "res://scenes/marathon/marathon_catalog_screen.tscn"
const MARATHON_FINISH_SCENE := "res://scenes/series_finish/series_finish_screen.tscn"
const _EndlessSummaryScreen = preload("res://scenes/endless/endless_summary_screen.gd")
const _MarathonFinishScreen = preload("res://scenes/marathon/marathon_finish_screen.gd")

const SESSION_SETUP_SCENE := "res://scenes/song_select/endless/session_setup_screen.tscn"
const TRACK_PICKER_SCENE := "res://scenes/song_select/endless/track_picker_screen.tscn"
const PLAYLIST_HUB_SCENE := "res://scenes/song_select/playlists/playlist_hub_screen.tscn"
const PLAYLIST_EDITOR_SCENE := "res://scenes/song_select/playlists/playlist_editor_screen.tscn"

func _init(p_game_engine):
	game_engine = p_game_engine
	parent = p_game_engine
	
	call_deferred("_warmup_heavy_scenes")

func set_main_menu_instance(instance):
	main_menu_instance = instance

func _get_cached_packed(scene_path: String) -> PackedScene:
	if _scene_cache.has(scene_path):
		var cached: Variant = _scene_cache[scene_path]
		if cached is PackedScene:
			return cached as PackedScene
	return null


func _preload_scene(scene_path: String) -> PackedScene:
	var existing = _get_cached_packed(scene_path)
	if existing:
		return existing
	if not ResourceLoader.exists(scene_path):
		return null
	var scene_resource = load(scene_path)
	if scene_resource and scene_resource is PackedScene:
		_scene_cache[scene_path] = scene_resource
		return scene_resource
	return null

func _preload_scene_threaded(scene_path: String):
	var existing = _get_cached_packed(scene_path)
	if existing:
		return existing
	if _pending_scene.has(scene_path):
		return null
	if not ResourceLoader.exists(scene_path):
		return null
	var ok = ResourceLoader.load_threaded_request(scene_path, "PackedScene")
	if ok == OK:
		_pending_scene[scene_path] = true
		call_deferred("_poll_threaded_scene", scene_path)
	return null

func _poll_threaded_scene(scene_path: String):
	var st = ResourceLoader.load_threaded_get_status(scene_path)
	if st == ResourceLoader.THREAD_LOAD_LOADED:
		var res = ResourceLoader.load_threaded_get(scene_path)
		if res and (res is PackedScene):
			_scene_cache[scene_path] = res
		_pending_scene.erase(scene_path)
	elif st == ResourceLoader.THREAD_LOAD_FAILED:
		_pending_scene.erase(scene_path)
	else:
		if game_engine and game_engine.has_method("get_tree"):
			await game_engine.get_tree().process_frame
		call_deferred("_poll_threaded_scene", scene_path)

func _warmup_heavy_scenes():
	var to_prewarm := [
		"res://scenes/main_menu/main_menu.tscn",
		"res://scenes/song_select/song_select.tscn",
		"res://scenes/shop/shop_screen.tscn",
		"res://scenes/achievements/achievements_screen.tscn",
		"res://scenes/play_modes/play_modes_screen.tscn",
		SESSION_SETUP_SCENE,
		TRACK_PICKER_SCENE,
		PLAYLIST_HUB_SCENE,
		PLAYLIST_EDITOR_SCENE,
		MARATHON_CATALOG_SCENE,
		MARATHON_FINISH_SCENE,
		"res://scenes/song_select/run_modifiers/run_modifiers_screen.tscn",
		"res://scenes/profile/profile_screen.tscn",
		"res://scenes/settings_menu/settings_menu.tscn",
		"res://scenes/victory_screen/victory_screen.tscn",
		"res://scenes/defeat_screen/defeat_screen.tscn",
		"res://scenes/game_screen/game_screen.tscn",
		"res://scenes/help/help_screen.tscn"
	]
	call_deferred("_prewarm_step", to_prewarm, 0)

func _warmup_screen_textures():
	ScreenTexturePreload.warmup_startup_light()

func _prewarm_step(list: Array, index: int):
	if index >= list.size():
		call_deferred("_warmup_screen_textures")
		return
	var started_ms := Time.get_ticks_msec()
	var path = String(list[index])
	_preload_scene_threaded(path)
	var elapsed := Time.get_ticks_msec() - started_ms
	if elapsed >= 10:
		print("[Perf] Transitions warmup request %s: %d ms" % [path, elapsed])
	if game_engine and game_engine.has_method("get_tree"):
		await game_engine.get_tree().process_frame
	call_deferred("_prewarm_step", list, index + 1)


func is_scene_cached(scene_path: String) -> bool:
	return _get_cached_packed(scene_path) != null


func _get_loading_overlay() -> LoadingOverlay:
	if game_engine == null or not is_instance_valid(game_engine):
		return null
	if game_engine.has_method("get_loading_overlay"):
		return game_engine.get_loading_overlay()
	return null


func _spawn_async(task: Callable) -> void:
	if game_engine == null or not is_instance_valid(game_engine):
		return
	if game_engine.has_method("run_async"):
		game_engine.run_async(task)


func _ensure_packed_scene(scene_path: String) -> PackedScene:
	var cached: PackedScene = _get_cached_packed(scene_path)
	if cached:
		return cached
	while _pending_scene.has(scene_path):
		if game_engine and is_instance_valid(game_engine) and game_engine.get_tree():
			await game_engine.get_tree().process_frame
		else:
			break
	cached = _get_cached_packed(scene_path)
	if cached:
		return cached
	if game_engine and is_instance_valid(game_engine) and game_engine.get_tree():
		await game_engine.get_tree().process_frame
	return _preload_scene(scene_path)


func _instantiate_when_ready(scene_path: String) -> Node:
	var overlay := _get_loading_overlay()
	var needs_overlay := _get_cached_packed(scene_path) == null
	if needs_overlay and overlay:
		overlay.show_loading("", true)
	var packed: PackedScene = await _ensure_packed_scene(scene_path)
	if needs_overlay and overlay:
		overlay.hide_loading()
	if packed and packed is PackedScene:
		return packed.instantiate()
	printerr("Transitions: Сцена не найдена: ", scene_path)
	return null


func _loading_message(loading_key: String) -> String:
	var key := loading_key.strip_edges()
	if key == "":
		return ""
	return TranslationServer.translate(key)


func _open_screen_async(scene_path: String, setup: Callable, loading_key: String = "") -> void:
	_screen_nav_serial += 1
	var nav_serial := _screen_nav_serial
	_spawn_async(_open_screen_task.bind(scene_path, setup, loading_key, nav_serial))


func _open_screen_task(scene_path: String, setup: Callable, loading_key: String = "", nav_serial: int = 0) -> void:
	var overlay := _get_loading_overlay()
	var loading_msg := _loading_message(loading_key)
	var force_overlay := loading_msg != ""
	if force_overlay and overlay:
		overlay.show_loading(loading_msg, true)
		if game_engine and is_instance_valid(game_engine) and game_engine.get_tree():
			await game_engine.get_tree().process_frame
			await RenderingServer.frame_post_draw

	var needs_preload_overlay := _get_cached_packed(scene_path) == null
	if needs_preload_overlay and not force_overlay and overlay:
		overlay.show_loading("", true)
	var packed: PackedScene = await _ensure_packed_scene(scene_path)
	if needs_preload_overlay and not force_overlay and overlay:
		overlay.hide_loading()
	if packed == null or not (packed is PackedScene):
		if force_overlay and overlay:
			overlay.hide_loading()
		printerr("Transitions: Сцена не найдена: ", scene_path)
		return

	var instance: Node = packed.instantiate()
	if nav_serial > 0 and nav_serial != _screen_nav_serial:
		instance.queue_free()
		if force_overlay and overlay:
			overlay.hide_loading()
		return
	if setup.is_valid():
		setup.call(instance)
	_switch_to_screen_instance(instance)
	if force_overlay and overlay:
		if game_engine and is_instance_valid(game_engine) and game_engine.get_tree():
			await game_engine.get_tree().process_frame
			await RenderingServer.frame_post_draw
		overlay.hide_loading()


func _instantiate_if_exists(scene_path):
	var scene_resource = _get_cached_packed(scene_path)
	if not scene_resource:
		scene_resource = _preload_scene(scene_path)
	if scene_resource and scene_resource is PackedScene:
		return scene_resource.instantiate()
	else:
		printerr("Transitions: Сцена не найдена: ", scene_path)
		return null

const SCREEN_FADE_OUT := 0.06
const SCREEN_FADE_IN := 0.08


func _finalize_pending_screen_dispose() -> void:
	if game_engine == null or not is_instance_valid(game_engine):
		return
	if not game_engine.has_meta("_screen_transition_dispose_id"):
		return
	var prev_id: int = int(game_engine.get_meta("_screen_transition_dispose_id"))
	game_engine.remove_meta("_screen_transition_dispose_id")
	_dispose_previous_screen_by_id(prev_id)


func _cancel_screen_transition_tween() -> void:
	_finalize_pending_screen_dispose()
	if game_engine == null or not is_instance_valid(game_engine):
		return
	if not game_engine.has_meta("_screen_transition_tween"):
		return
	var tw_v: Variant = game_engine.get_meta("_screen_transition_tween")
	if tw_v is Tween and (tw_v as Tween).is_valid():
		(tw_v as Tween).kill()
	game_engine.remove_meta("_screen_transition_tween")


func _free_node_by_id(node_id: int) -> void:
	var node := instance_from_id(node_id)
	if node:
		node.queue_free()


func _detach_screen_from_tree(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var parent := node.get_parent()
	if parent:
		parent.remove_child(node)


func _dispose_previous_screen_by_id(prev_id: int) -> void:
	var prev: Node = instance_from_id(prev_id) as Node
	_dispose_previous_screen(prev)


func _dispose_previous_screen(prev: Node) -> void:
	if prev == null or not is_instance_valid(prev):
		return
	if is_instance_valid(main_menu_instance) and prev.get_instance_id() == main_menu_instance.get_instance_id():
		_detach_screen_from_tree(prev)
		return
	var prev_id: int = prev.get_instance_id()
	if game_engine and is_instance_valid(game_engine) and game_engine.get_tree():
		game_engine.get_tree().process_frame.connect(
			func() -> void: _free_node_by_id(prev_id),
			CONNECT_ONE_SHOT
		)
	else:
		_free_node_by_id(prev_id)


func _switch_to_screen_instance(instance):
	if not instance:
		return
	_cleanup_settings_overlays()
	_cancel_screen_transition_tween()
	var prev = game_engine.current_screen
	game_engine.add_child(instance)
	game_engine.current_screen = instance
	var skip_ui_apply: bool = is_instance_valid(main_menu_instance) \
		and instance.get_instance_id() == main_menu_instance.get_instance_id() \
		and instance.has_meta("_ui_interactions_ready")
	if not skip_ui_apply:
		var screen_path := str(instance.scene_file_path)
		if screen_path.contains("victory_screen") or screen_path.contains("defeat_screen"):
			call_deferred("_apply_ui_interactions_to_screen", instance)
		else:
			UiInteractionApplier.apply_to_tree(instance, game_engine.theme)
		if is_instance_valid(main_menu_instance) and instance.get_instance_id() == main_menu_instance.get_instance_id():
			instance.set_meta("_ui_interactions_ready", true)
	if prev and is_instance_valid(prev):
		instance.modulate.a = 0.0
		prev.modulate.a = 1.0
		var prev_id: int = prev.get_instance_id()
		game_engine.set_meta("_screen_transition_dispose_id", prev_id)
		var tw: Tween = game_engine.create_tween()
		game_engine.set_meta("_screen_transition_tween", tw)
		tw.set_parallel(true)
		tw.tween_property(prev, "modulate:a", 0.0, SCREEN_FADE_OUT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(instance, "modulate:a", 1.0, SCREEN_FADE_IN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.chain().tween_callback(_finalize_pending_screen_dispose)
		tw.tween_callback(_clear_screen_transition_tween_meta)
	else:
		instance.modulate.a = 0.0
		var tw: Tween = game_engine.create_tween()
		tw.tween_property(instance, "modulate:a", 1.0, SCREEN_FADE_IN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_sync_ambient_motion(instance)


func _apply_ui_interactions_to_screen(instance: Node) -> void:
	if not is_instance_valid(instance) or game_engine == null:
		return
	UiInteractionApplier.apply_to_tree(instance, game_engine.theme)


func _sync_ambient_motion(instance: Node) -> void:
	if game_engine == null or not game_engine.has_method("set_ambient_motion_active"):
		return
	var active := true
	if instance:
		var path := str(instance.scene_file_path)
		if path.contains("game_screen"):
			active = false
	game_engine.set_ambient_motion_active(active)
	if active and instance and game_engine.has_method("set_ambient_screen_profile"):
		game_engine.set_ambient_screen_profile(_ambient_profile_for(instance))


func _ambient_profile_for(instance: Node) -> StringName:
	if instance != null and instance.has_method("get_ambient_screen_profile"):
		var custom: Variant = instance.call("get_ambient_screen_profile")
		if custom is StringName:
			var named_sn := custom as StringName
			if named_sn != StringName():
				return named_sn
		elif custom is String:
			var named := StringName(str(custom).strip_edges())
			if named != StringName():
				return named
	var path := str(instance.scene_file_path) if instance else ""
	if path.contains("main_menu"):
		return &"menu"
	if path.contains("song_select"):
		return &"song_select"
	if path.contains("play_modes"):
		return &"play_modes"
	if path.contains("session_setup_screen"):
		return &"play_modes_endless"
	if path.contains("track_picker_screen"):
		return &"play_modes_endless"
	if path.contains("marathon_catalog"):
		return &"play_modes_marathon"
	if path.contains("series_finish"):
		return &"victory"
	if path.contains("marathon_finish"):
		return &"play_modes_marathon"
	if path.contains("endless_summary"):
		return &"play_modes_endless"
	if path.contains("victory_screen"):
		return &"victory"
	if path.contains("defeat_screen"):
		return &"defeat"
	if path.contains("profile_screen"):
		return &"profile"
	if path.contains("shop_screen"):
		return &"shop"
	if path.contains("achievements"):
		return &"achievements"
	if path.contains("help_screen"):
		return &"help"
	if path.contains("settings_menu") or path.contains("run_modifiers"):
		return &"help"
	return &"menu"


func _clear_screen_transition_tween_meta() -> void:
	if game_engine and is_instance_valid(game_engine) and game_engine.has_meta("_screen_transition_tween"):
		game_engine.remove_meta("_screen_transition_tween")

func _return_to_main_menu():
	transition_open_main_menu()

func hide_level_ui():
	if game_engine and game_engine.has_method("get_level_layer"):
		var level_layer = game_engine.get_level_layer()
		if level_layer:
			level_layer.visible = false

func show_level_ui():
	if game_engine and game_engine.has_method("get_level_layer"):
		var level_layer = game_engine.get_level_layer()
		if level_layer:
			level_layer.visible = true


func show_level_ui_instant() -> void:
	if game_engine and game_engine.has_method("show_level_ui_instant"):
		game_engine.show_level_ui_instant()
	else:
		show_level_ui()

func _clear_game_open_flag() -> void:
	if is_instance_valid(main_menu_instance):
		main_menu_instance.is_game_open = false


func transition_open_game(
	start_level=null, 
	selected_song=null, 
	instrument="standard", 
	results_mgr = null, 
	generation_mode: String = "basic",
	lane_count: int = 4,
	run_modifiers: Array = [],
	chart_tag: String = "",
	play_mode: String = "",
):
	hide_level_ui()
	# Stale flag after song select / victory / defeat used to abort launch and open main menu.
	_clear_game_open_flag()

	var new_game_screen = _instantiate_if_exists("res://scenes/game_screen/game_screen.tscn")
	if new_game_screen:
		if new_game_screen.has_method("_set_instrument"):
			new_game_screen._set_instrument(instrument)

		if new_game_screen.has_method("_set_start_level"):
			new_game_screen._set_start_level(start_level)
		if new_game_screen.has_method("_set_selected_song"):
			new_game_screen._set_selected_song(selected_song)

		if new_game_screen.has_method("set_results_manager") and results_mgr:
			new_game_screen.set_results_manager(results_mgr)

		if new_game_screen.has_method("_set_generation_mode"):
			new_game_screen._set_generation_mode(generation_mode)

		if new_game_screen.has_method("_set_lanes"):
			new_game_screen._set_lanes(lane_count)

		if new_game_screen.has_method("_set_run_modifiers"):
			new_game_screen._set_run_modifiers(run_modifiers)

		if new_game_screen.has_method("_set_chart_tag"):
			new_game_screen._set_chart_tag(chart_tag)

		if new_game_screen.has_method("_set_play_mode"):
			new_game_screen._set_play_mode(play_mode)

		if play_mode == _PlayModeIds.ENDLESS and _endless_run != null:
			if new_game_screen.has_method("configure_endless_run"):
				new_game_screen.configure_endless_run(_endless_run)

		if play_mode == _PlayModeIds.MARATHON and _marathon_run != null:
			if new_game_screen.has_method("configure_marathon_run"):
				new_game_screen.configure_marathon_run(_marathon_run)

		if new_game_screen.has_method("start_game"):
			new_game_screen.start_game()
		_switch_to_screen_instance(new_game_screen)

		if main_menu_instance:
			main_menu_instance.is_game_open = true
	else:
		printerr("Transitions: GameScreen.tscn не найден, переход отменён.")

func transition_close_game():
	if not is_instance_valid(main_menu_instance) or not main_menu_instance.is_game_open:
		return
	
	transition_open_main_menu()
	
	if main_menu_instance:
		main_menu_instance.is_game_open = false

func transition_open_song_select():
	_clear_game_open_flag()
	show_level_ui()
	_open_screen_async("res://scenes/song_select/song_select.tscn", _setup_song_select_screen)


func _setup_song_select_screen(new_screen: Node) -> void:
	if new_screen.has_method("set_transitions"):
		new_screen.set_transitions(self)
	elif new_screen.has_method("setup_managers"):
		new_screen.setup_managers(self)
	else:
		printerr("Transitions.gd: Новый экземпляр SongSelect не имеет метода set_transitions!")
	if MusicManager:
		MusicManager.fade_out_menu_music(2.0)
	if new_screen.has_method("apply_playlist_browse"):
		new_screen.apply_playlist_browse(_song_select_browse_playlist_id)

func transition_close_song_select():
	if _song_select_return_to_play_modes:
		_song_select_return_to_play_modes = false
		transition_open_play_modes()
		return
	_return_to_main_menu()

func transition_open_play_modes():
	_clear_game_open_flag()
	show_level_ui()
	_open_screen_async(
		"res://scenes/play_modes/play_modes_screen.tscn",
		_setup_play_modes_screen,
		"UI_LOADING_PLAY_MODES",
	)


func _setup_play_modes_screen(new_screen: Node) -> void:
	if new_screen.has_method("setup_managers"):
		new_screen.setup_managers(self)
	if MusicManager:
		MusicManager.stop_game_music()
		if MusicManager.has_method("stop_screen_ambient_music"):
			MusicManager.stop_screen_ambient_music()
		MusicManager.cancel_menu_music_fade()
		var mp := MusicManager.music_player
		var menu_audible := (
			mp != null
			and mp.playing
			and (
				MusicManager.current_menu_music_file != ""
				or MusicManager.current_screen_ambient_file != ""
			)
			and mp.volume_db > -30.0
		)
		if menu_audible:
			# С главного меню: музыка ещё слышна — только подтянуть громкость.
			if MusicManager.has_method("update_volumes_from_settings"):
				MusicManager.update_volumes_from_settings()
		else:
			# Возврат из библиотеки / настройки endless — там музыка затухла или уже остановлена.
			MusicManager.fade_in_menu_music(2.0)


func transition_close_play_modes():
	_return_to_main_menu()


func transition_open_endless_session_setup():
	_clear_game_open_flag()
	show_level_ui()
	_open_screen_async(
		SESSION_SETUP_SCENE,
		_setup_session_setup_screen,
		"UI_LOADING_SESSION_SETUP",
	)


func _setup_session_setup_screen(new_screen: Node) -> void:
	if new_screen.has_method("setup_managers"):
		new_screen.setup_managers(self)
	if MusicManager:
		MusicManager.fade_out_menu_music(2.0)


func transition_close_endless_session_setup():
	if _session_setup_return_to_play_modes:
		_session_setup_return_to_play_modes = false
		transition_open_play_modes()
		return
	_return_to_main_menu()


func open_endless_session_setup_from_play_modes() -> void:
	_session_setup_return_to_play_modes = true
	var saved: Dictionary = {}
	if PlayerDataManager:
		saved = PlayerDataManager.get_endless_session_last()
	if saved.is_empty():
		clear_staged_endless_session_config()
	else:
		stage_endless_session_config(saved)
	transition_open_endless_session_setup()


func open_track_picker_from_session_setup(config: Dictionary) -> void:
	_track_picker_playlist_id = ""
	_open_track_picker(config)


func open_track_picker_for_playlist(config: Dictionary, playlist_id: String) -> void:
	var pid := str(playlist_id).strip_edges()
	if pid == "" or pid == "favorites":
		return
	_track_picker_playlist_id = pid
	_open_track_picker(config)


func _open_track_picker(config: Dictionary) -> void:
	_track_picker_return_to_setup = true
	stage_endless_session_config(_EndlessSessionConfig.sanitize(config))
	if MusicManager:
		MusicManager.play_modifier_select_sound()
	_open_screen_async(
		TRACK_PICKER_SCENE,
		_setup_track_picker_screen,
		"UI_LOADING_TRACK_PICKER",
	)


func _setup_track_picker_screen(new_screen: Node) -> void:
	if new_screen.has_method("setup_managers"):
		new_screen.setup_managers(self)
	if new_screen.has_method("load_config"):
		var cfg := get_staged_endless_session_config().duplicate(true)
		if _track_picker_playlist_id != "":
			cfg["_picker_playlist_id"] = _track_picker_playlist_id
		new_screen.load_config(cfg)


func close_track_picker_to_session_setup(selected_paths: Array, apply_selection: bool) -> void:
	var cfg := get_staged_endless_session_config()
	var playlist_id := str(_track_picker_playlist_id).strip_edges()
	if playlist_id != "":
		if apply_selection:
			const PlaylistCatalog = preload("res://logic/domain/library/playlist_catalog.gd")
			PlaylistCatalog.save_song_paths(playlist_id, selected_paths)
			cfg["playlist_id"] = playlist_id
			cfg["track_source"] = _EndlessSessionConfig.TRACK_SOURCE_PLAYLIST
		_track_picker_playlist_id = ""
	elif apply_selection:
		cfg["selected_song_paths"] = selected_paths
		cfg["track_source"] = _EndlessSessionConfig.TRACK_SOURCE_SELECTED
	stage_endless_session_config(_EndlessSessionConfig.sanitize(cfg))
	_track_picker_return_to_setup = false
	if MusicManager:
		if apply_selection:
			MusicManager.play_modifier_select_sound()
		else:
			MusicManager.play_modifier_deselect_sound()
	transition_open_endless_session_setup()


func open_playlist_hub_from_session_setup(config: Dictionary, pick_for_run: bool = false) -> void:
	_playlist_hub_return_to_setup = true
	_playlist_hub_return_to_song_select = false
	_playlist_hub_browse_library = false
	_playlist_hub_pick_for_run = pick_for_run
	stage_endless_session_config(_EndlessSessionConfig.sanitize(config))
	if MusicManager:
		MusicManager.play_modifier_select_sound()
	_open_playlist_hub_screen_async()


func open_playlist_hub_from_song_select() -> void:
	_playlist_hub_return_to_setup = false
	_playlist_hub_return_to_song_select = true
	_playlist_hub_pick_for_run = false
	_playlist_hub_browse_library = true
	if MusicManager:
		MusicManager.play_modifier_select_sound()
	_open_playlist_hub_screen_async()


func _open_playlist_hub_screen_async() -> void:
	_open_screen_async(
		PLAYLIST_HUB_SCENE,
		_setup_playlist_hub_screen,
		"UI_LOADING_PLAYLIST_HUB",
	)


func _setup_playlist_hub_screen(new_screen: Node) -> void:
	if new_screen.has_method("setup_managers"):
		new_screen.setup_managers(self)
	if new_screen.has_method("setup_hub"):
		var cfg := get_staged_endless_session_config()
		var selected := (
			_song_select_browse_playlist_id
			if _playlist_hub_browse_library
			else str(cfg.get("playlist_id", "")).strip_edges()
		)
		new_screen.setup_hub(_playlist_hub_pick_for_run, selected, _playlist_hub_browse_library)


func set_song_select_browse_playlist(playlist_id: String) -> void:
	_song_select_browse_playlist_id = str(playlist_id).strip_edges()


func close_playlist_hub_to_session_setup(playlist_id: String, apply_selection: bool) -> void:
	if _playlist_hub_return_to_song_select:
		_playlist_hub_return_to_song_select = false
		_playlist_hub_pick_for_run = false
		_playlist_hub_browse_library = false
		if apply_selection:
			_song_select_browse_playlist_id = str(playlist_id).strip_edges()
		if MusicManager:
			if apply_selection:
				MusicManager.play_modifier_select_sound()
			else:
				MusicManager.play_modifier_deselect_sound()
		transition_open_song_select()
		return
	var cfg := get_staged_endless_session_config()
	if apply_selection:
		var pid := str(playlist_id).strip_edges()
		if pid != "":
			cfg["playlist_id"] = pid
			cfg["track_source"] = _EndlessSessionConfig.TRACK_SOURCE_PLAYLIST
	stage_endless_session_config(_EndlessSessionConfig.sanitize(cfg))
	_playlist_hub_return_to_setup = false
	_playlist_hub_pick_for_run = false
	if MusicManager:
		if apply_selection:
			MusicManager.play_modifier_select_sound()
		else:
			MusicManager.play_modifier_deselect_sound()
	transition_open_endless_session_setup()


func open_playlist_editor(playlist_id: String, _is_new: bool = false) -> void:
	var pid := str(playlist_id).strip_edges()
	if pid == "":
		return
	_playlist_editor_playlist_id = pid
	if MusicManager:
		MusicManager.play_modifier_select_sound()
	_open_screen_async(
		PLAYLIST_EDITOR_SCENE,
		_setup_playlist_editor_screen,
		"UI_LOADING_PLAYLIST_EDITOR",
	)


func _setup_playlist_editor_screen(new_screen: Node) -> void:
	if new_screen.has_method("setup_managers"):
		new_screen.setup_managers(self)
	if new_screen.has_method("setup_editor"):
		new_screen.setup_editor(_playlist_editor_playlist_id)


func close_playlist_editor_to_hub() -> void:
	_playlist_editor_playlist_id = ""
	if MusicManager:
		MusicManager.play_modifier_deselect_sound()
	_open_playlist_hub_screen_async()


func close_endless_session_setup() -> void:
	transition_close_endless_session_setup()


func stage_endless_session_config(config: Dictionary) -> void:
	_staged_endless_session_config = config.duplicate(true)


func get_staged_endless_session_config() -> Dictionary:
	return _staged_endless_session_config.duplicate(true)


func clear_staged_endless_session_config() -> void:
	_staged_endless_session_config.clear()


func open_endless_run(config: Dictionary) -> void:
	_endless_summary_return_to_play_modes = true
	_endless_run = _EndlessRun.new()
	var sanitized := _EndlessSessionConfig.sanitize(config)
	if not _endless_run.start(sanitized):
		_endless_run = null
		printerr("Transitions: Endless run could not start — empty track scope.")
		return
	stage_endless_session_config(sanitized)
	_launch_endless_track(null)


func get_endless_run():
	return _endless_run


func continue_endless_on_game_screen(game_screen: Node) -> void:
	if _endless_run == null or game_screen == null:
		return
	var launch: Dictionary = _endless_run.get_launch_params()
	if launch.is_empty():
		finish_endless_run("empty_scope")
		return
	if game_screen.has_method("load_next_endless_track"):
		game_screen.load_next_endless_track(launch)


func finish_endless_run(reason: String) -> void:
	var summary: Dictionary = {}
	if _endless_run != null:
		summary = _endless_run.build_summary(reason)
	_endless_run = null
	if summary.is_empty():
		if _endless_summary_return_to_play_modes:
			_endless_summary_return_to_play_modes = false
			transition_open_play_modes()
		else:
			transition_open_main_menu()
		return
	transition_open_endless_summary(summary)


func finish_endless_run_to_main_menu(reason: String) -> void:
	var summary: Dictionary = {}
	if _endless_run != null:
		summary = _endless_run.build_summary(reason)
	_endless_run = null
	_endless_summary_return_to_play_modes = false
	if not summary.is_empty():
		_EndlessSummaryScreen.persist_summary(summary)
	_clear_game_open_flag()
	hide_level_ui()
	transition_open_main_menu()


func transition_open_endless_summary(summary: Dictionary) -> void:
	_clear_game_open_flag()
	hide_level_ui()
	var new_screen = _instantiate_if_exists(ENDLESS_SUMMARY_SCENE)
	if new_screen == null:
		printerr("Transitions: series_finish_screen.tscn not found (endless).")
		if _endless_summary_return_to_play_modes:
			transition_open_play_modes()
		else:
			transition_open_main_menu()
		return
	if new_screen.has_method("setup_managers"):
		new_screen.setup_managers(self)
	if new_screen.has_method("set_summary_data"):
		new_screen.set_summary_data(summary, _endless_summary_return_to_play_modes)
	_endless_summary_return_to_play_modes = false
	_switch_to_screen_instance(new_screen)
	if MusicManager and MusicManager.has_method("play_victory_screen_music"):
		MusicManager.play_victory_screen_music()


func _launch_endless_track(results_mgr) -> void:
	if _endless_run == null:
		return
	var launch: Dictionary = _endless_run.get_launch_params()
	if launch.is_empty():
		finish_endless_run("empty_scope")
		return
	transition_open_game(
		null,
		launch.get("song_info", {}),
		str(launch.get("instrument", _EndlessSessionConfig.DEFAULT_INSTRUMENT)),
		results_mgr,
		str(launch.get("generation_mode", "basic")),
		int(launch.get("lane_count", 4)),
		launch.get("run_modifiers", []),
		str(launch.get("chart_tag", "")),
		_PlayModeIds.ENDLESS,
	)


func open_marathon_catalog_from_play_modes() -> void:
	_marathon_catalog_return_to_play_modes = true
	_marathon_catalog_open_daily_tab = false
	transition_open_marathon_catalog()


func open_marathon_catalog_daily() -> void:
	_marathon_catalog_return_to_play_modes = false
	_marathon_catalog_open_daily_tab = true
	transition_open_marathon_catalog()


func open_marathon_daily_run() -> bool:
	const MarathonDailyRoute = preload("res://logic/domain/session/marathon_daily_route.gd")
	return open_marathon_run(MarathonDailyRoute.today_route_id(), {})


func transition_open_marathon_catalog() -> void:
	_clear_game_open_flag()
	show_level_ui()
	_open_screen_async(
		MARATHON_CATALOG_SCENE,
		_setup_marathon_catalog_screen,
		"UI_LOADING_MARATHON_CATALOG",
	)


func _setup_marathon_catalog_screen(new_screen: Node) -> void:
	if new_screen.has_method("setup_managers"):
		new_screen.setup_managers(self)
	if _marathon_catalog_open_daily_tab and new_screen.has_method("set_initial_tab_daily"):
		new_screen.set_initial_tab_daily()
	_marathon_catalog_open_daily_tab = false
	if MusicManager:
		MusicManager.fade_out_menu_music(2.0)


func close_marathon_catalog() -> void:
	if _marathon_catalog_return_to_play_modes:
		_marathon_catalog_return_to_play_modes = false
		transition_open_play_modes()
		return
	_return_to_main_menu()


func open_marathon_run(route_id: String, run_config: Dictionary = {}) -> bool:
	_marathon_finish_return_to_catalog = true
	var rid := str(route_id).strip_edges()
	var cfg := run_config.duplicate(true) if run_config is Dictionary else {}
	if cfg.is_empty() and PlayerDataManager:
		cfg = PlayerDataManager.get_marathon_session_last(rid)
	_marathon_run = _MarathonRun.new()
	if not _marathon_run.start_for_route(rid, cfg):
		_marathon_run = null
		printerr("Transitions: Marathon run could not start for route %s" % route_id)
		return false
	if PlayerDataManager and not cfg.is_empty():
		PlayerDataManager.save_marathon_session_last(rid, cfg)
	_launch_marathon_track(null)
	return true


func get_marathon_run():
	return _marathon_run


func continue_marathon_on_game_screen(game_screen: Node) -> void:
	if _marathon_run == null or game_screen == null:
		return
	var launch: Dictionary = _marathon_run.get_launch_params()
	if launch.is_empty():
		finish_marathon_run("empty_scope")
		return
	if game_screen.has_method("load_next_series_track"):
		game_screen.load_next_series_track(launch)


func finish_marathon_run(reason: String) -> void:
	var summary: Dictionary = {}
	if _marathon_run != null:
		summary = _marathon_run.build_summary(reason)
	_marathon_run = null
	if summary.is_empty():
		if _marathon_finish_return_to_catalog:
			_marathon_finish_return_to_catalog = false
			transition_open_marathon_catalog()
		else:
			transition_open_play_modes()
		return
	transition_open_marathon_finish(summary)


func finish_marathon_run_to_main_menu(reason: String) -> void:
	var summary: Dictionary = {}
	if _marathon_run != null:
		summary = _marathon_run.build_summary(reason)
	_marathon_run = null
	_marathon_finish_return_to_catalog = false
	if not summary.is_empty():
		_MarathonFinishScreen.persist_summary(summary)
	_clear_game_open_flag()
	hide_level_ui()
	transition_open_main_menu()


func transition_open_marathon_finish(summary: Dictionary) -> void:
	_clear_game_open_flag()
	hide_level_ui()
	var new_screen = _instantiate_if_exists(MARATHON_FINISH_SCENE)
	if new_screen == null:
		printerr("Transitions: series_finish_screen.tscn not found (marathon).")
		if _marathon_finish_return_to_catalog:
			transition_open_marathon_catalog()
		else:
			transition_open_play_modes()
		return
	if new_screen.has_method("setup_managers"):
		new_screen.setup_managers(self)
	if new_screen.has_method("set_summary_data"):
		new_screen.set_summary_data(summary, _marathon_finish_return_to_catalog)
	_marathon_finish_return_to_catalog = false
	_switch_to_screen_instance(new_screen)
	if MusicManager and MusicManager.has_method("play_victory_screen_music"):
		MusicManager.play_victory_screen_music()


func _launch_marathon_track(results_mgr) -> void:
	if _marathon_run == null:
		return
	var launch: Dictionary = _marathon_run.get_launch_params()
	if launch.is_empty():
		finish_marathon_run("empty_scope")
		return
	transition_open_game(
		null,
		launch.get("song_info", {}),
		str(launch.get("instrument", _EndlessSessionConfig.DEFAULT_INSTRUMENT)),
		results_mgr,
		str(launch.get("generation_mode", "basic")),
		int(launch.get("lane_count", 4)),
		launch.get("run_modifiers", []),
		str(launch.get("chart_tag", "")),
		_PlayModeIds.MARATHON,
	)


func transition_open_main_menu():
	show_level_ui_instant()
	if not is_instance_valid(main_menu_instance):
		var new_main_menu_instance = _instantiate_if_exists("res://scenes/main_menu/main_menu.tscn")
		if new_main_menu_instance:
			if new_main_menu_instance.has_method("set_transitions"):
				new_main_menu_instance.set_transitions(self)
			else:
				printerr("Transitions.gd: Новый экземпляр MainMenu не имеет метода set_transitions!")
			main_menu_instance = new_main_menu_instance
			if game_engine:
				game_engine.main_menu_instance = new_main_menu_instance
			_switch_to_screen_instance(main_menu_instance)
		else:
			printerr("Transitions.gd: ОШИБКА! Не удалось создать новый экземпляр MainMenu!")
			return
	elif not main_menu_instance.is_inside_tree() or (game_engine and game_engine.current_screen != main_menu_instance):
		_switch_to_screen_instance(main_menu_instance)
	if MusicManager:
		MusicManager.stop_game_music()
		var menu_playing := (
			MusicManager.music_player != null
			and MusicManager.music_player.playing
			and MusicManager.current_menu_music_file != ""
		)
		if menu_playing:
			if MusicManager.has_method("update_volumes_from_settings"):
				MusicManager.update_volumes_from_settings()
		else:
			MusicManager.fade_in_menu_music(2.0)
	if main_menu_instance and main_menu_instance.has_method("apply_locale"):
		main_menu_instance.apply_locale()
	elif main_menu_instance and main_menu_instance.has_method("queue_refresh_on_show"):
		main_menu_instance.queue_refresh_on_show()

func transition_open_achievements():
	_open_screen_async("res://scenes/achievements/achievements_screen.tscn", Callable(), "UI_LOADING_ACHIEVEMENTS")

func transition_close_achievements():
	_return_to_main_menu()

func transition_open_profile():
	_open_screen_async("res://scenes/profile/profile_screen.tscn", _setup_profile_screen)


func _setup_profile_screen(new_screen: Node) -> void:
	if new_screen.has_method("setup_managers"):
		new_screen.setup_managers(self)
	else:
		printerr("Transitions.gd: Экземпляр ProfileScreen не имеет метода setup_managers!")

func transition_close_profile():
	_return_to_main_menu()

func transition_open_help(from_pause: bool = false):
	if from_pause:
		_spawn_async(_open_help_from_pause_task)
	else:
		var host := _find_help_overlay_host()
		if host:
			_spawn_async(_open_help_over_overlay_task.bind(host, true))
		else:
			_open_screen_async("res://scenes/help/help_screen.tscn", _setup_help_screen)


func _open_help_from_pause_task() -> void:
	var new_screen: Node = await _instantiate_when_ready("res://scenes/help/help_screen.tscn")
	if not new_screen:
		printerr("Transitions: HelpScreen.tscn не найден, переход отменён.")
		return
	_setup_help_screen(new_screen)
	if game_engine and game_engine.current_screen:
		game_engine.current_screen.add_child(new_screen)
		if new_screen is Control:
			(new_screen as Control).set_anchors_preset(Control.PRESET_FULL_RECT)
			(new_screen as Control).set_offsets_preset(Control.PRESET_FULL_RECT)
			(new_screen as Control).z_index = 20
		if new_screen.has_method("apply_contextual_overlay_layout"):
			new_screen.apply_contextual_overlay_layout()
	else:
		new_screen.queue_free()
		printerr("Transitions.gd: Нет активного экрана для справки из паузы!")
		return
	UiInteractionApplier.apply_to_tree(new_screen, game_engine.theme)


func open_help_with_search(query: String = "") -> void:
	_pending_help_search = query.strip_edges()
	_pending_help_item_id = ""
	_open_help_contextual()


func open_help_item(item_id: String = "") -> void:
	_pending_help_item_id = item_id.strip_edges()
	_pending_help_search = ""
	_open_help_contextual()


func _open_help_contextual() -> void:
	var existing := _find_open_help_overlay()
	if existing:
		_setup_help_screen(existing)
		return
	var host := _find_help_overlay_host()
	if host:
		_spawn_async(_open_help_over_overlay_task.bind(host, true))
	else:
		transition_open_help()


var _pending_help_search: String = ""
var _pending_help_item_id: String = ""
var _pending_settings_page: String = ""


func _setup_help_screen(new_screen: Node) -> void:
	if new_screen.has_method("setup_managers"):
		new_screen.setup_managers(self)
	if _pending_help_item_id != "" and new_screen.has_method("open_item_by_id"):
		new_screen.call_deferred("open_item_by_id", _pending_help_item_id)
	elif _pending_help_search != "" and new_screen.has_method("set_initial_search"):
		new_screen.call_deferred("set_initial_search", _pending_help_search)
	_pending_help_search = ""
	_pending_help_item_id = ""

func transition_close_help(from_pause: bool = false):
	if _remove_help_overlay():
		return
	if from_pause:
		return
	_return_to_main_menu()


func _is_help_screen_node(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	var scr: Script = node.get_script() as Script
	return scr != null and str(scr.resource_path).ends_with("help_screen.gd")


func _find_settings_overlay() -> Control:
	if game_engine == null or not is_instance_valid(game_engine):
		return null
	for child in game_engine.get_children():
		if child is Control and child.has_method("open_help_topic") and child.has_method("cleanup_before_exit"):
			return child as Control
	if game_engine.current_screen:
		for child in game_engine.current_screen.get_children():
			if child is Control and child.has_method("open_help_topic") and child.has_method("cleanup_before_exit"):
				return child as Control
	return null


func _find_help_overlay_host() -> Control:
	var settings := _find_settings_overlay()
	if settings:
		return settings
	if game_engine == null or not is_instance_valid(game_engine):
		return null
	# Prefer the topmost full-screen UI sibling (gen settings / modifiers / endless)
	# so help sits above the screen the player is actually looking at.
	for i in range(game_engine.get_child_count() - 1, -1, -1):
		var child: Node = game_engine.get_child(i)
		if not (child is Control) or not (child as Control).visible:
			continue
		if _is_help_screen_node(child):
			continue
		if child == game_engine.current_screen:
			return child as Control
		if child.has_method("cleanup_before_exit"):
			return child as Control
		if child.has_method("set_active_modifiers") or child.has_method("set_current_song_data"):
			return child as Control
		if child.has_signal("selector_closed") or child.has_signal("screen_closed"):
			return child as Control
	if game_engine.current_screen is Control:
		return game_engine.current_screen as Control
	return game_engine as Control


func _find_open_help_overlay() -> Node:
	if game_engine == null or not is_instance_valid(game_engine):
		return null
	for child in game_engine.get_children():
		if _is_help_screen_node(child):
			return child
		if child is Control and child.has_method("open_help_topic"):
			for sub in child.get_children():
				if _is_help_screen_node(sub):
					return sub
		if child == game_engine.current_screen or (child is Control):
			for sub in child.get_children():
				if _is_help_screen_node(sub):
					return sub
	if game_engine.current_screen:
		for child in game_engine.current_screen.get_children():
			if _is_help_screen_node(child):
				return child
	return null


func _open_help_over_overlay_task(host: Control, side_panel: bool = false) -> void:
	if host == null or not is_instance_valid(host):
		printerr("Transitions: нет хоста для оверлея справки.")
		return
	var existing := _find_open_help_overlay()
	if existing:
		_setup_help_screen(existing)
		return
	var new_screen: Node = await _instantiate_when_ready("res://scenes/help/help_screen.tscn")
	if not new_screen:
		printerr("Transitions: HelpScreen.tscn не найден, переход отменён.")
		return
	_setup_help_screen(new_screen)
	host.add_child(new_screen)
	host.move_child(new_screen, -1)
	if new_screen is Control:
		(new_screen as Control).set_anchors_preset(Control.PRESET_FULL_RECT)
		(new_screen as Control).set_offsets_preset(Control.PRESET_FULL_RECT)
		(new_screen as Control).z_index = 220
		(new_screen as Control).mouse_filter = Control.MOUSE_FILTER_STOP
	if side_panel and new_screen.has_method("apply_contextual_overlay_layout"):
		new_screen.apply_contextual_overlay_layout()
	if game_engine:
		UiInteractionApplier.apply_to_tree(new_screen, game_engine.theme)


func _remove_help_overlay() -> bool:
	var overlay := _find_open_help_overlay()
	if overlay and is_instance_valid(overlay):
		overlay.queue_free()
		return true
	return false


func _cleanup_settings_overlays() -> void:
	if game_engine == null or not is_instance_valid(game_engine):
		return
	for child in game_engine.get_children():
		if child is Control and child.has_method("cleanup_before_exit") and child.has_method("open_help_topic"):
			child.cleanup_before_exit()
			child.queue_free()
func transition_open_shop():
	show_level_ui()
	ScreenTexturePreload.warmup_shop_textures(24)
	_open_screen_async("res://scenes/shop/shop_screen.tscn", _setup_shop_screen, "UI_LOADING_SHOP")


func _setup_shop_screen(_new_screen: Node) -> void:
	if MusicManager:
		MusicManager.fade_out_menu_music(2.0)

func transition_close_shop():
	_return_to_main_menu()

func transition_open_settings(from_pause: bool = false) -> void:
	if from_pause:
		if _find_settings_overlay():
			return
		_spawn_async(_open_settings_overlay_task.bind(true))
		return
	if _find_settings_overlay():
		return
	show_level_ui()
	_open_screen_async(
		"res://scenes/settings_menu/settings_menu.tscn",
		_setup_settings_fullscreen,
		"UI_LOADING_SETTINGS",
	)


func _setup_settings_fullscreen(new_screen: Node) -> void:
	if MusicManager:
		MusicManager.fade_out_menu_music(2.0)
	if new_screen.has_method("setup_managers"):
		new_screen.setup_managers(self)
	if _pending_settings_page != "" and new_screen.has_method("switch_to_page"):
		new_screen.call_deferred("switch_to_page", _pending_settings_page)
	_pending_settings_page = ""


func _open_settings_overlay_task(from_pause: bool) -> void:
	var new_screen: Node = await _instantiate_when_ready("res://scenes/settings_menu/settings_menu.tscn")
	if not new_screen:
		printerr("Transitions: SettingsMenu.tscn не найден, переход отменён.")
		return
	if new_screen.has_method("setup_managers"):
		new_screen.setup_managers(self)
	if from_pause:
		if game_engine.current_screen:
			game_engine.current_screen.add_child(new_screen)
		else:
			printerr("Transitions.gd: Нет активного экрана для паузы!")
			new_screen.queue_free()
			return
		new_screen.z_index = 150
		new_screen.mouse_filter = Control.MOUSE_FILTER_STOP
		game_engine.current_screen.move_child(new_screen, -1)
	UiInteractionApplier.apply_to_tree(new_screen, game_engine.theme)
	if _pending_settings_page != "" and new_screen.has_method("switch_to_page"):
		new_screen.call_deferred("switch_to_page", _pending_settings_page)
	_pending_settings_page = ""


func open_settings_with_page(page_id: String, from_pause: bool = false) -> void:
	_pending_settings_page = page_id.strip_edges()
	if not from_pause and game_engine and game_engine.current_screen:
		var scr: Script = game_engine.current_screen.get_script() as Script
		if scr and str(scr.resource_path).ends_with("help_screen.gd"):
			from_pause = true
	transition_open_settings(from_pause)


func transition_close_settings(from_pause: bool = false) -> void:
	if from_pause:
		if game_engine.current_screen:
			for child in game_engine.current_screen.get_children():
				if child is Control and child.has_method("cleanup_before_exit"):
					child.cleanup_before_exit()
					child.queue_free()
					break
			if game_engine.current_screen.has_method("restore_pause_menu_after_settings"):
				game_engine.current_screen.call_deferred("restore_pause_menu_after_settings")
	else:
		_return_to_main_menu()


func transition_open_victory_screen(score: int, combo: int, max_combo: int, accuracy: float, song_info: Dictionary = {}, results_mgr = null, missed_notes: int = 0, perfect_hits: int = 0, hit_notes: int = 0):
	_clear_game_open_flag()
	hide_level_ui()
	var new_screen = _instantiate_if_exists("res://scenes/victory_screen/victory_screen.tscn")
	if new_screen:
		if new_screen.has_method("set_victory_data"):
			new_screen.set_victory_data(score, combo, max_combo, accuracy, song_info, 1.0, 0, missed_notes, perfect_hits, hit_notes)
		
		if new_screen.has_method("set_results_manager") and results_mgr:
			new_screen.set_results_manager(results_mgr)
			print("Transitions.gd: ResultsManager передан в VictoryScreen.")
		elif results_mgr:
			printerr("Transitions.gd: VictoryScreen не имеет метода set_results_manager, но ResultsManager передан.")
		if new_screen.has_method("set_achievement_system") and game_engine and game_engine.has_method("get_achievement_system"):
			new_screen.set_achievement_system(game_engine.get_achievement_system())
		
		if new_screen.has_signal("song_select_requested"):
			new_screen.song_select_requested.connect(transition_open_song_select)
		if new_screen.has_signal("replay_requested"):
			new_screen.replay_requested.connect(_on_replay_requested.bind(song_info))
		_switch_to_screen_instance(new_screen)
	else:
		printerr("Transitions: victory_screen.tscn не найден, переход отменён.")

func _on_replay_requested(song_info: Dictionary):
	transition_open_game(null, song_info, "standard")

func open_victory_screen(score: int, combo: int, max_combo: int, accuracy: float, song_info: Dictionary = {}, results_mgr = null, missed_notes: int = 0, perfect_hits: int = 0, hit_notes: int = 0):
	transition_open_victory_screen(score, combo, max_combo, accuracy, song_info, results_mgr, missed_notes, perfect_hits, hit_notes)

func transition_open_defeat_screen(
	score: int,
	combo: int,
	max_combo: int,
	accuracy: float,
	song_info: Dictionary = {},
	results_mgr = null
):
	_clear_game_open_flag()
	hide_level_ui()
	var new_screen = _instantiate_if_exists("res://scenes/defeat_screen/defeat_screen.tscn")
	if new_screen:
		if new_screen.has_method("set_defeat_data"):
			new_screen.set_defeat_data(score, combo, max_combo, accuracy, song_info)
		if new_screen.has_method("set_results_manager") and results_mgr:
			new_screen.set_results_manager(results_mgr)
		new_screen.song_select_requested.connect(transition_open_song_select)
		new_screen.replay_requested.connect(_on_replay_requested.bind(song_info))
		_switch_to_screen_instance(new_screen)
	else:
		printerr("Transitions: defeat_screen.tscn не найден, переход отменён.")

func open_defeat_screen(
	score: int,
	combo: int,
	max_combo: int,
	accuracy: float,
	song_info: Dictionary = {},
	results_mgr = null
):
	transition_open_defeat_screen(score, combo, max_combo, accuracy, song_info, results_mgr)

func transition_exit_to_main_menu():
	if is_instance_valid(main_menu_instance):
		main_menu_instance.is_game_open = false
	transition_open_main_menu()

func transition_exit_game():
	if game_engine.has_method("request_quit"):
		game_engine.request_quit()
	else:
		printerr("Transitions.gd: ОШИБКА! GameEngine не имеет метода request_quит!")

func open_game_with_instrument(
	song_path_or_instrument: String = "",
	instrument_if_path_provided: String = "standard",
	results_mgr = null,
	generation_mode: String = "basic"
):
	var current_screen = game_engine.current_screen
	var selected_song_data = {}
	var instrument = instrument_if_path_provided
	var results_manager = results_mgr
	
	var is_instrument_call = (
		song_path_or_instrument in ["standard", "drums", "bass"]
		and instrument_if_path_provided == "standard"
	)
	
	if is_instrument_call:
		instrument = song_path_or_instrument
		if current_screen and current_screen.has_method("get_current_selected_song"):
			selected_song_data = current_screen.get_current_selected_song()
			var song_path = selected_song_data.get("path", "")
			if current_screen.has_method("get_results_manager"):
				results_manager = current_screen.get_results_manager()
		else:
			printerr("Transitions.gd: Не удалось получить выбранную песню из текущего экрана, запуск игры с инструментом: ", instrument)
			selected_song_data = {}
			return 
	
	else:
		var song_path = song_path_or_instrument
		if song_path.is_empty() and current_screen and current_screen.has_method("get_current_selected_song"):
			selected_song_data = current_screen.get_current_selected_song()
			song_path = selected_song_data.get("path", "")
		else:
			selected_song_data = {"path": song_path}

		if song_path.is_empty():
			printerr("Transitions.gd: Невозможно открыть игру - путь к песне пуст!")
			return

	open_game_with_song(selected_song_data, instrument, results_manager, generation_mode) 

func open_song_select():
	transition_open_song_select()

func open_song_select_from_play_modes():
	_song_select_return_to_play_modes = true
	_song_select_browse_playlist_id = ""
	transition_open_song_select()

func close_song_select():
	transition_close_song_select()

func open_play_modes():
	transition_open_play_modes()

func close_play_modes():
	transition_close_play_modes()

func open_game_with_song(
	selected_song, 
	instrument="standard", 
	results_mgr = null, 
	generation_mode: String = "basic",
	lane_count: int = 4,
	run_modifiers: Array = [],
	chart_tag: String = "",
): 
	transition_open_game(null, selected_song, instrument, results_mgr, generation_mode, lane_count, run_modifiers, chart_tag) 

func resume_game():
	pass
func exit_to_main_menu():
	transition_exit_to_main_menu()

func open_achievements():
	transition_open_achievements()

func close_achievements():
	transition_close_achievements()

func open_profile():
	transition_open_profile()

func close_profile():
	transition_close_profile()

func open_help(from_pause: bool = false):
	transition_open_help(from_pause)

func close_help(from_pause: bool = false):
	transition_close_help(from_pause)

func open_shop():
	transition_open_shop()

func close_shop():
	transition_close_shop()

func open_settings(from_pause=false):
	transition_open_settings(from_pause)

func close_settings(from_pause=false):
	transition_close_settings(from_pause)

func open_main_menu():
	transition_open_main_menu()

func exit_game(): 
	transition_exit_game()
