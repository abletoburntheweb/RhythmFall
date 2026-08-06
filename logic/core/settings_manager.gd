# logic/core/settings_manager.gd
extends Node

const _LocaleDetect = preload("res://logic/platform/locale_detect.gd")
const _GuitarHeroBindings = preload("res://logic/domain/controls/guitar_hero_bindings.gd")
const _GoalDiff = preload("res://logic/domain/generation/generation_goal_difficulty.gd")

const SETTINGS_PATH = "user://settings.json"
const MAX_LANES = 5
const DEFAULT_WINDOW_SIZE := Vector2i(1920, 1080)

var default_settings = {
	"music_volume": 30.0,
	"menu_music_volume": 30.0,
	"effects_volume": 30.0,
	"hit_sounds_volume": 30.0,
	"metronome_volume": 30.0, 
	"preview_volume": 30.0,
	"song_preview_mode": "snippet",
	"timing_offset_ms": 0,
	"fps_mode": 0,
	"window_mode": 1,
	"window_resolution": 2,
	"graphics_quality": 1,
	"enable_debug_menu": true,
	"enable_genre_detection": true,
	"user_songs_path": "",
	"replay_save_folder": "",
	"replay_auto_save": true,
	"lane_highlight_brightness": 100.0,
	"note_brightness": 100.0,
	"note_approach_hint": 3,
	"duo_partner_note_style": "warm_cool",
	"controls_keymap": {
		"lane_0_key": KEY_A,
		"lane_1_key": KEY_S,
		"lane_2_key": KEY_D,
		"lane_3_key": KEY_F,
		"lane_4_key": KEY_G
	},
	"controls_keymap_alt": {
		"lane_0_key": KEY_J,
		"lane_1_key": KEY_K,
		"lane_2_key": KEY_L,
		"lane_3_key": KEY_SEMICOLON,
		"lane_4_key": KEY_APOSTROPHE
	},
	"controls_mediator_up_key": KEY_UP,
	"controls_mediator_down_key": KEY_DOWN,
	"controls_mediator_up_key_alt": KEY_Q,
	"controls_mediator_down_key_alt": KEY_E,
	"controls_layout_mode": "primary",
	"controls_gh_enabled": false,
	"controls_gh_auto_detect": true,
	"controls_gh_device_id": -1,
	"controls_gh_lane_buttons": [0, 1, 3, 2, 9],
	"controls_gh_strum_up_button": 11,
	"controls_gh_strum_down_button": 12,
	"controls_gh_pause_button": 6,
	"controls_gh_skip_button": 4,
	"last_generation_instrument": "drums",
	"last_generation_mode": "basic",
	"last_generation_intent": "original",
	"generation_goal": "original",
	"generation_difficulty": "medium",
	"last_generation_lanes": 4,
	"use_stems_in_generation": true,
	"scroll_speed": 10.0,
	"generation_fill": 50,
	"generation_groove": 50,
	"generation_density": 50,
	"generation_grid_snap_strength": 80,
	"generation_accent_strong_beats": true,
	"generation_genre_template_strength": 60,
	"generation_include_hi_hats": true,
	"generation_critic_strength": 50,
	"generation_groove_completion": true,
	"generation_raw_adtof": false,
	"generation_custom_fill": 50,
	"generation_custom_groove": 50,
	"generation_custom_density": 50,
	"generation_custom_grid_snap_strength": 50,
	"generation_custom_accent_strong_beats": false,
	"generation_custom_genre_template_strength": 50,
	"generation_custom_enable_genre_detection": false,
	"generation_custom_use_stems_in_generation": false,
	"generation_custom_include_hi_hats": true,
	"generation_custom_critic_strength": 50,
	"generation_custom_groove_completion": true,
	"generation_custom_raw_adtof": false,
	"generation_notes_ready_scope": 0,
	"generation_ready_goals": ["original"],
	"generation_ready_diffs": ["medium"],
	"generation_ready_instruments": ["drums"],
	"generation_ready_preset_slots": [],
	"generation_confirm_before_rerun": true,
	"generation_bulk_force_regen": true,
	"generation_stem_retention_mode": "after_job",
	"generation_stem_keep_all": true,
	"generation_status_mode": "full",
	"show_generation_notifications": true,
	"notify_generation_done_when_minimized": true,
	"reduce_resources_when_minimized": true,
	"generation_server_use_lan_host": false,
	"generation_server_lan_host": "",
	"generation_server_port": 5000,
	"generation_auto_worker": true,
	"generation_worker_path": "",
	"generation_gpu_stack": "auto",
	"generation_gpu_scan": {},
	"seen_server_setup_notice": false,
	"tutorial_song_select_done": false,
	"tutorial_shop_done": false,
	"tutorial_gameplay_done": false,
	"tutorial_victory_done": false,
	"tutorial_profile_done": false,
	"tutorial_calibration_done": false,
	"tutorial_generation_settings_done": false,
	"tutorial_rhythm_dna_setting_done": false,
	"tutorial_rhythm_dna_usage_done": false,
	"tutorial_modifiers_done": false,
	"help_nudge_first_chart_done": false,
	"endless_setup_hint_seen": false,
	"check_updates_on_startup": true,
	"update_notice_dismissed_version": "",
	"language": "en",
	"last_shop_category": "Все",
	"song_select_filter_mode": "title",
	"song_select_search_query": "",
	"run_modifiers": [],
	"run_modifier_params": {
		"song_speed": 100.0,
		"scroll_speed_mode": "settings",
		"scroll_speed_value": 20.0,
		"scroll_speed_mult_pct": 100.0,
		"timing_window_pct": 100.0,
		"easy_timing_window_pct": 100.0,
		"strict_timing_window_pct": 100.0,
		"visibility_band_px": 220.0,
		"memory_reveal_ms": 500.0,
		"combo_escalation_pick_mode": "no_repeat",
		"combo_escalation_order": [
			"fast_150",
			"strict_timing",
			"no_miss_forgiveness",
			"sudden_death",
			"hidden",
			"sudden",
			"memory_mode",
		],
	},
	"mute_when_unfocused": true,
	"show_error_meter": true,
	"show_health_bar": true,
	"pause_resume_rewind_enabled": true,
	"reduce_bg_effects": false,
	"ambient_particles_enabled": true,
	"audio_reactive_background": true,
	"shop_kick_waveform_preview": false,
	"series_inter_track_countdown_enabled": false,
	"user_notes_path": "",
	"show_chart_id": false,
	"diary_history_open_day": false,
	"diary_history_open_track": false,
	"diary_open_track_museum": false,
	"library_last_scan_unix": 0,
	"playfield_width_3_lanes": 100.0,
	"playfield_width_4_lanes": 100.0,
	"playfield_width_5_lanes": 100.0,
	"split_compare_enabled": false,
	"chart_compare_enabled": false,
	"chart_compare_mode": "hotkey",
	"split_compare_variant_tag": "exp",
	"generation_save_experimental_chart": false,
	"show_rhythm_dna_button": false,
	"timing_debug_log_hits": false,
	"timing_debug_overlay": false,
	"timing_debug_autoplay_windows": false,
	"show_drum_class_colors": false,
}

var settings: Dictionary = default_settings.duplicate(true)

func _init():
	_load_settings()


func _load_settings():
	var json_result: Dictionary = JsonUtils.read_json_dict(SETTINGS_PATH)
	if not json_result.is_empty():
		var loaded_settings = _merge_defaults_with_loaded(default_settings, json_result)
		var controls_loaded = loaded_settings.get("controls_keymap", {})
		var controls_updated = false
		for i in range(MAX_LANES):
			var lane_key = "lane_%d_key" % i
			if not controls_loaded.has(lane_key):
				controls_loaded[lane_key] = default_settings["controls_keymap"][lane_key]
				controls_updated = true
			else:
				var value = controls_loaded.get(lane_key)
				if value is float:
					controls_loaded[lane_key] = int(value)
					controls_updated = true
				elif value is String:
					var scancode = KeyInputUtils.string_to_scancode(value)
					if scancode != 0:
						controls_loaded[lane_key] = scancode
					else:
						controls_loaded[lane_key] = default_settings["controls_keymap"][lane_key]
					controls_updated = true

		if controls_updated:
			pass
		if loaded_settings.has("show_manual_track_input_on_generation"):
			loaded_settings.erase("show_manual_track_input_on_generation")
		if loaded_settings.get("split_compare_enabled", false) and not loaded_settings.get("chart_compare_enabled", false):
			loaded_settings["chart_compare_enabled"] = true
		if loaded_settings.has("autoplay_respects_hit_windows") and not loaded_settings.has("timing_debug_autoplay_windows"):
			loaded_settings["timing_debug_autoplay_windows"] = loaded_settings.pop("autoplay_respects_hit_windows")
		if loaded_settings.has("controls_strum_up_key") and not loaded_settings.has("controls_mediator_up_key"):
			loaded_settings["controls_mediator_up_key"] = loaded_settings["controls_strum_up_key"]
		if loaded_settings.has("controls_strum_down_key") and not loaded_settings.has("controls_mediator_down_key"):
			loaded_settings["controls_mediator_down_key"] = loaded_settings["controls_strum_down_key"]
		if not loaded_settings.has("generation_scope_goal_diff_v2"):
			var legacy_scope := int(loaded_settings.get("generation_notes_ready_scope", 0))
			# Pre goal×difficulty matrix: 1 (and legacy 2/3) meant all chart styles (6).
			# New 1 = current goal × all difficulties (3) — remap once on upgrade.
			if legacy_scope in [1, 2, 3]:
				loaded_settings["generation_notes_ready_scope"] = 3
			loaded_settings["generation_scope_goal_diff_v2"] = true
		if not loaded_settings.has("generation_ready_axes_v1"):
			var scope_for_axes := int(loaded_settings.get("generation_notes_ready_scope", 0))
			var axes := _GoalDiff.ready_axes_from_legacy_scope(scope_for_axes)
			for key in axes.keys():
				loaded_settings[key] = axes[key]
			loaded_settings["generation_ready_axes_v1"] = true
		if not loaded_settings.has("generation_ready_icons_v1"):
			# Only remap when the previous expand-flag model is present.
			var had_expand := (
				loaded_settings.has("generation_ready_expand_goals")
				or loaded_settings.has("generation_ready_expand_diffs")
				or loaded_settings.has("generation_ready_expand_instruments")
			)
			if had_expand:
				var cur_goal := _GoalDiff.sanitize_goal(str(loaded_settings.get("generation_goal", "original")))
				var cur_diff := _GoalDiff.sanitize_difficulty(str(loaded_settings.get("generation_difficulty", "medium")))
				var cur_inst := _GoalDiff.sanitize_ready_instrument(
					str(loaded_settings.get("last_generation_instrument", "drums"))
				)
				if not bool(loaded_settings.get("generation_ready_expand_goals", false)):
					loaded_settings["generation_ready_goals"] = [cur_goal]
				else:
					loaded_settings["generation_ready_goals"] = _GoalDiff.sanitize_ready_string_list(
						loaded_settings.get("generation_ready_goals", []), _GoalDiff.GOALS, cur_goal
					)
				if not bool(loaded_settings.get("generation_ready_expand_diffs", false)):
					loaded_settings["generation_ready_diffs"] = [cur_diff]
				else:
					loaded_settings["generation_ready_diffs"] = _GoalDiff.sanitize_ready_string_list(
						loaded_settings.get("generation_ready_diffs", []), _GoalDiff.DIFFICULTIES, cur_diff
					)
				if not bool(loaded_settings.get("generation_ready_expand_instruments", false)):
					loaded_settings["generation_ready_instruments"] = [cur_inst]
				else:
					loaded_settings["generation_ready_instruments"] = _GoalDiff.sanitize_ready_string_list(
						loaded_settings.get("generation_ready_instruments", []),
						_GoalDiff.READY_INSTRUMENTS,
						cur_inst
					)
			loaded_settings.erase("generation_ready_expand_goals")
			loaded_settings.erase("generation_ready_expand_diffs")
			loaded_settings.erase("generation_ready_expand_instruments")
			loaded_settings["generation_ready_icons_v1"] = true
		settings = loaded_settings
		# Map legacy difficulty ids (relaxed/standard/dense) → easy/medium/hard.
		settings["generation_difficulty"] = _GoalDiff.sanitize_difficulty(
			str(settings.get("generation_difficulty", _GoalDiff.DEFAULT_DIFFICULTY))
		)
		settings["generation_ready_diffs"] = _GoalDiff.sanitize_ready_string_list(
			settings.get("generation_ready_diffs", []),
			_GoalDiff.DIFFICULTIES,
			str(settings.get("generation_difficulty", _GoalDiff.DEFAULT_DIFFICULTY))
		)
		settings["controls_keymap_alt"] = ControlsBindings.sanitize_lane_keymap(
			settings.get("controls_keymap_alt", {}),
			default_settings["controls_keymap_alt"]
		)
		settings["controls_layout_mode"] = ControlsBindings.sanitize_layout_mode(
			settings.get("controls_layout_mode", default_settings["controls_layout_mode"])
		)
		_migrate_gh_controls_settings()
		if not settings.has("generation_status_mode"):
			if settings.get("show_generation_notifications", true) == false:
				settings["generation_status_mode"] = "off"
			else:
				settings["generation_status_mode"] = "full"
		_migrate_run_modifier_presets_from_settings()
		restore_active_run_modifier_preset()
		# Window APIs are unreliable during autoload _init; apply once the main loop exists.
		call_deferred("apply_window_mode")
	else:
		settings = default_settings.duplicate(true)
		settings["language"] = _LocaleDetect.detect_initial_language()
		_migrate_gh_controls_settings()
		_save_settings()
		call_deferred("apply_window_mode")


func _save_settings():
	JsonUtils.write_json(SETTINGS_PATH, settings, true, true)


func apply_window_mode() -> void:
	var mode_id := get_window_mode()
	var sz := get_window_resolution_pixels()
	var tree := Engine.get_main_loop() as SceneTree
	var root_window: Window = tree.root if tree else null

	# project.godot used to boot as Minimized (mode=1); leave that state before FS/windowed.
	_ensure_window_not_minimized()

	match mode_id:
		2:
			_apply_display_mode_fullscreen(sz, root_window)
		1:
			_apply_display_mode_exclusive_fullscreen(sz, root_window)
		0:
			_apply_display_mode_windowed(sz, root_window)

	_apply_window_taskbar_icon_deferred()


func _ensure_window_not_minimized() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var tree := Engine.get_main_loop() as SceneTree
	var root_window: Window = tree.root if tree else null
	if root_window and root_window.mode == Window.MODE_MINIMIZED:
		root_window.mode = Window.MODE_WINDOWED


func _apply_display_mode_fullscreen(sz: Vector2i, root_window: Window) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	DisplayServer.window_set_size(sz)
	if root_window:
		root_window.mode = Window.MODE_FULLSCREEN
		root_window.size = sz


func _apply_display_mode_exclusive_fullscreen(sz: Vector2i, root_window: Window) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	DisplayServer.window_set_size(sz)
	if root_window:
		root_window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		root_window.size = sz


func _apply_display_mode_windowed(sz: Vector2i, root_window: Window) -> void:
	var prev := DisplayServer.window_get_mode()
	if prev == DisplayServer.WINDOW_MODE_FULLSCREEN or prev == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		call_deferred("_finish_display_mode_windowed_transition", sz)
		return
	_finish_display_mode_windowed_transition(sz)


func _finish_display_mode_windowed_transition(sz: Vector2i) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var root_window: Window = tree.root if tree else null
	DisplayServer.window_set_title("RhythmFall")
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var usable := DisplayServer.screen_get_usable_rect()
	var fit := Vector2i(
		mini(sz.x, usable.size.x),
		mini(sz.y, usable.size.y)
	)
	fit.x = maxi(fit.x, 64)
	fit.y = maxi(fit.y, 64)
	DisplayServer.window_set_size(fit)
	var pos := usable.position + (usable.size - fit) / 2
	pos.x = clampi(pos.x, usable.position.x, usable.position.x + maxi(0, usable.size.x - fit.x))
	pos.y = clampi(pos.y, usable.position.y, usable.position.y + maxi(0, usable.size.y - fit.y))
	DisplayServer.window_set_position(pos)
	if root_window:
		root_window.mode = Window.MODE_WINDOWED
		root_window.size = fit
		root_window.borderless = false
		root_window.unresizable = true
		root_window.title = "RhythmFall"
	_apply_window_taskbar_icon_deferred()


func _apply_window_taskbar_icon_deferred() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	WindowIconApplier.apply_deferred(tree)


func get_window_mode() -> int:
	var v = settings.get("window_mode", default_settings["window_mode"])
	if v is int:
		return clampi(v, 0, 2)
	if v is float:
		return clampi(int(v), 0, 2)
	return int(default_settings["window_mode"])


func set_window_mode(mode_id: int) -> void:
	settings["window_mode"] = clampi(mode_id, 0, 2)
	apply_window_mode()


func get_window_resolution() -> int:
	var v = settings.get("window_resolution", default_settings["window_resolution"])
	if v is int:
		return clampi(v, 0, 2)
	if v is float:
		return clampi(int(v), 0, 2)
	return int(default_settings["window_resolution"])


func get_window_resolution_pixels() -> Vector2i:
	match get_window_resolution():
		0:
			return Vector2i(1280, 720)
		1:
			return Vector2i(1600, 900)
		2:
			return Vector2i(1920, 1080)
		_:
			return Vector2i(1920, 1080)


func set_window_resolution(res_id: int) -> void:
	settings["window_resolution"] = clampi(res_id, 0, 2)
	apply_window_mode()


func reload_from_disk() -> void:
	_load_settings()
	apply_window_mode()


func _merge_defaults_with_loaded(defaults: Dictionary, loaded: Dictionary) -> Dictionary:
	var merged = defaults.duplicate(true)
	for key in loaded:
		if defaults.has(key):
			if defaults[key] is Dictionary and loaded[key] is Dictionary:
				merged[key] = _merge_defaults_with_loaded(defaults[key], loaded[key])
			else:
				merged[key] = loaded[key]
		else:
			merged[key] = loaded[key]
	return merged


const DEFAULT_REPLAYS_DIR := "user://replays/"


func get_replay_save_folder() -> String:
	var stored := String(settings.get("replay_save_folder", "")).strip_edges()
	if stored == "":
		return DEFAULT_REPLAYS_DIR
	if not stored.ends_with("/"):
		stored += "/"
	return stored


func set_replay_save_folder(path: String) -> void:
	var normalized := String(path).strip_edges().replace("\\", "/")
	if normalized == "" or normalized == DEFAULT_REPLAYS_DIR:
		settings["replay_save_folder"] = ""
		return
	if not normalized.ends_with("/"):
		normalized += "/"
	settings["replay_save_folder"] = normalized


func get_replay_auto_save() -> bool:
	return bool(settings.get("replay_auto_save", default_settings.get("replay_auto_save", true)))


func set_replay_auto_save(enabled: bool) -> void:
	settings["replay_auto_save"] = enabled


func get_setting(setting_name: String, default_value=null):
	return settings.get(setting_name, default_value)

func set_setting(setting_name: String, value):
	settings[setting_name] = value

func save_settings():
	_save_settings()


func export_settings_json() -> String:
	return JSON.stringify(settings)


func reset_settings():
	var prev_wm := get_window_mode()
	var prev_wr := get_window_resolution()
	settings = default_settings.duplicate(true)
	settings["window_mode"] = prev_wm
	settings["window_resolution"] = prev_wr
	_save_settings()

func get_music_volume() -> float:
	return float(settings.get("music_volume", default_settings["music_volume"]))

func get_menu_music_volume() -> float:
	return float(settings.get("menu_music_volume", default_settings["menu_music_volume"]))

func get_effects_volume() -> float:
	return float(settings.get("effects_volume", default_settings["effects_volume"])) 

func get_hit_sounds_volume() -> float:
	return float(settings.get("hit_sounds_volume", default_settings["hit_sounds_volume"])) 

func get_metronome_volume() -> float: 
	return float(settings.get("metronome_volume", default_settings["metronome_volume"]))

func get_preview_volume() -> float:
	return float(settings.get("preview_volume", default_settings["preview_volume"]))

func set_music_volume(volume: float): 
	settings["music_volume"] = clampf(volume, 0.0, 100.0) 

func set_menu_music_volume(volume: float):
	settings["menu_music_volume"] = clampf(volume, 0.0, 100.0)

func set_effects_volume(volume: float): 
	settings["effects_volume"] = clampf(volume, 0.0, 100.0) 

func set_hit_sounds_volume(volume: float):
	settings["hit_sounds_volume"] = clampf(volume, 0.0, 100.0)

func set_metronome_volume(volume: float):
	settings["metronome_volume"] = clampf(volume, 0.0, 100.0) 

func set_preview_volume(volume: float):
	settings["preview_volume"] = clampf(volume, 0.0, 100.0) 

func get_song_preview_mode() -> String:
	var mode := str(settings.get("song_preview_mode", default_settings["song_preview_mode"])).strip_edges()
	return mode if mode in ["snippet", "full"] else "snippet"


func set_song_preview_mode(mode: String) -> void:
	var normalized := str(mode).strip_edges()
	if normalized not in ["snippet", "full"]:
		normalized = "snippet"
	settings["song_preview_mode"] = normalized


func get_scroll_speed() -> float:
	var v = float(settings.get("scroll_speed", default_settings["scroll_speed"]))
	return clampf(v, 6.0, 20.0)

func set_scroll_speed(value: float):
	settings["scroll_speed"] = clampf(value, 6.0, 20.0)


func get_run_modifiers() -> Array[String]:
	return RunModifiers.sanitize(settings.get("run_modifiers", []))


func set_run_modifiers(modifiers: Array) -> void:
	settings["run_modifiers"] = RunModifiers.sanitize(modifiers)
	_save_settings()


func get_run_modifier_params() -> Dictionary:
	return RunModifiers.sanitize_params(settings.get("run_modifier_params", {}))


func set_run_modifier_params(params: Dictionary) -> void:
	settings["run_modifier_params"] = RunModifiers.sanitize_params(params)
	_save_settings()


func get_run_modifier_presets() -> Dictionary:
	return UserPresets.load_modifier_presets()


func set_run_modifier_presets(presets: Dictionary) -> void:
	UserPresets.save_modifier_presets(presets)


func get_generation_presets() -> Dictionary:
	return UserPresets.load_generation_presets()


func set_generation_presets(presets: Dictionary) -> void:
	UserPresets.save_generation_presets(presets)


func sync_active_run_modifier_preset(modifiers: Array, params: Dictionary) -> void:
	var presets := UserPresets.sync_active_slot_for_run(
		get_run_modifier_presets(),
		modifiers,
		params,
	)
	set_run_modifier_presets(presets)


func record_run_modifier_preset_clear(modifiers: Array, params: Dictionary) -> void:
	var presets := UserPresets.record_modifier_slot_clear(
		get_run_modifier_presets(),
		modifiers,
		params,
	)
	set_run_modifier_presets(presets)


func restore_active_run_modifier_preset() -> void:
	var presets := get_run_modifier_presets()
	var slot := int(presets.get("active_slot", 0))
	if slot <= 0 or slot > UserPresets.MAX_SLOTS:
		return
	if not UserPresets.is_slot_filled(presets, slot):
		var current_mods := RunModifiers.sanitize(settings.get("run_modifiers", []))
		if not current_mods.is_empty():
			set_run_modifier_params(RunModifiers.default_params())
			set_run_modifiers([])
		return
	var entry := UserPresets.get_slot(presets, slot)
	var preset_mods := RunModifiers.sanitize(entry.get("modifiers", []))
	var preset_params := RunModifiers.sanitize_params(entry.get("params", {}))
	var current_mods := RunModifiers.sanitize(settings.get("run_modifiers", []))
	var current_params := RunModifiers.sanitize_params(settings.get("run_modifier_params", {}))
	if preset_mods == current_mods and preset_params == current_params:
		return
	set_run_modifier_params(preset_params)
	set_run_modifiers(preset_mods)


func _migrate_run_modifier_presets_from_settings() -> void:
	if not settings.has("run_modifier_presets"):
		return
	var legacy: Variant = settings["run_modifier_presets"]
	settings.erase("run_modifier_presets")
	UserPresets.migrate_modifier_presets_from_settings(legacy)
	_save_settings()

func get_timing_offset_ms() -> int:
	return int(settings.get("timing_offset_ms", default_settings["timing_offset_ms"]))

func get_seen_server_setup_notice() -> bool:
	return bool(settings.get("seen_server_setup_notice", default_settings["seen_server_setup_notice"]))

func set_seen_server_setup_notice(seen: bool) -> void:
	settings["seen_server_setup_notice"] = seen
	_save_settings()

func get_tutorial_song_select_done() -> bool:
	return bool(settings.get("tutorial_song_select_done", default_settings["tutorial_song_select_done"]))

func set_tutorial_song_select_done(done: bool) -> void:
	settings["tutorial_song_select_done"] = done
	_save_settings()

func get_tutorial_shop_done() -> bool:
	return bool(settings.get("tutorial_shop_done", default_settings["tutorial_shop_done"]))

func set_tutorial_shop_done(done: bool) -> void:
	settings["tutorial_shop_done"] = done
	_save_settings()

func get_tutorial_gameplay_done() -> bool:
	return bool(settings.get("tutorial_gameplay_done", default_settings["tutorial_gameplay_done"]))

func set_tutorial_gameplay_done(done: bool) -> void:
	settings["tutorial_gameplay_done"] = done
	_save_settings()

func get_tutorial_victory_done() -> bool:
	return bool(settings.get("tutorial_victory_done", default_settings["tutorial_victory_done"]))

func set_tutorial_victory_done(done: bool) -> void:
	settings["tutorial_victory_done"] = done
	_save_settings()

func get_tutorial_profile_done() -> bool:
	return bool(settings.get("tutorial_profile_done", default_settings["tutorial_profile_done"]))

func set_tutorial_profile_done(done: bool) -> void:
	settings["tutorial_profile_done"] = done
	_save_settings()

func get_tutorial_calibration_done() -> bool:
	return bool(settings.get("tutorial_calibration_done", default_settings["tutorial_calibration_done"]))

func set_tutorial_calibration_done(done: bool) -> void:
	settings["tutorial_calibration_done"] = done
	_save_settings()

func get_tutorial_generation_settings_done() -> bool:
	return bool(settings.get("tutorial_generation_settings_done", default_settings["tutorial_generation_settings_done"]))

func set_tutorial_generation_settings_done(done: bool) -> void:
	settings["tutorial_generation_settings_done"] = done
	_save_settings()

func get_tutorial_rhythm_dna_setting_done() -> bool:
	return bool(settings.get("tutorial_rhythm_dna_setting_done", default_settings["tutorial_rhythm_dna_setting_done"]))

func set_tutorial_rhythm_dna_setting_done(done: bool) -> void:
	settings["tutorial_rhythm_dna_setting_done"] = done
	_save_settings()

func get_tutorial_rhythm_dna_usage_done() -> bool:
	return bool(settings.get("tutorial_rhythm_dna_usage_done", default_settings["tutorial_rhythm_dna_usage_done"]))

func set_tutorial_rhythm_dna_usage_done(done: bool) -> void:
	settings["tutorial_rhythm_dna_usage_done"] = done
	_save_settings()

func get_tutorial_modifiers_done() -> bool:
	return bool(settings.get("tutorial_modifiers_done", default_settings["tutorial_modifiers_done"]))

func set_tutorial_modifiers_done(done: bool) -> void:
	settings["tutorial_modifiers_done"] = done
	_save_settings()


func get_help_nudge_first_chart_done() -> bool:
	return bool(settings.get("help_nudge_first_chart_done", default_settings["help_nudge_first_chart_done"]))


func set_help_nudge_first_chart_done(done: bool) -> void:
	settings["help_nudge_first_chart_done"] = done
	_save_settings()

func get_endless_setup_hint_seen() -> bool:
	return bool(settings.get("endless_setup_hint_seen", default_settings["endless_setup_hint_seen"]))

func set_endless_setup_hint_seen(seen: bool) -> void:
	settings["endless_setup_hint_seen"] = seen
	_save_settings()

func set_timing_offset_ms(value: int):
	settings["timing_offset_ms"] = clamp(value, -500, 500)


func get_timing_debug_log_hits() -> bool:
	return bool(settings.get("timing_debug_log_hits", false))

func set_timing_debug_log_hits(enabled: bool):
	settings["timing_debug_log_hits"] = enabled

func get_timing_debug_overlay() -> bool:
	return bool(settings.get("timing_debug_overlay", false))

func set_timing_debug_overlay(enabled: bool):
	settings["timing_debug_overlay"] = enabled

func get_autoplay_respects_hit_windows() -> bool:
	return bool(settings.get("timing_debug_autoplay_windows", false))

func set_autoplay_respects_hit_windows(enabled: bool):
	settings["timing_debug_autoplay_windows"] = enabled

func get_chart_compare_enabled() -> bool:
	if bool(settings.get("chart_compare_enabled", false)):
		return true
	return bool(settings.get("split_compare_enabled", false))

func set_chart_compare_enabled(enabled: bool) -> void:
	settings["chart_compare_enabled"] = enabled
	settings["split_compare_enabled"] = enabled

func get_chart_compare_mode() -> String:
	var mode := String(settings.get("chart_compare_mode", "hotkey")).strip_edges().to_lower()
	return "split" if mode == "split" else "hotkey"

func set_chart_compare_mode(mode: String) -> void:
	var m := String(mode).strip_edges().to_lower()
	settings["chart_compare_mode"] = "split" if m == "split" else "hotkey"

func get_show_drum_class_colors() -> bool:
	return bool(settings.get("show_drum_class_colors", false))

func set_show_drum_class_colors(enabled: bool) -> void:
	settings["show_drum_class_colors"] = enabled

func get_fps_mode() -> int:
	return settings.get("fps_mode", default_settings["fps_mode"])

func set_fps_mode(mode: int):
	settings["fps_mode"] = mode


func get_show_fps() -> bool:
	return settings.get("fps_mode", default_settings["fps_mode"]) != 0

func set_show_fps(enabled: bool):
	settings["fps_mode"] = 1 if enabled else 0


func get_window_size() -> Vector2i:
	var usable_rect := DisplayServer.screen_get_usable_rect()
	var usable_size := usable_rect.size
	if usable_size.x <= 0 or usable_size.y <= 0:
		usable_size = DisplayServer.screen_get_size()
	var target := usable_size - Vector2i(160, 120)
	target.x = clampi(target.x, 960, DEFAULT_WINDOW_SIZE.x)
	target.y = clampi(target.y, 540, DEFAULT_WINDOW_SIZE.y)
	return target

func get_graphics_quality() -> int:
	var quality := int(settings.get("graphics_quality", default_settings["graphics_quality"]))
	return int(clamp(quality, 0, 2))

func set_graphics_quality(quality: int):
	settings["graphics_quality"] = int(clamp(quality, 0, 2))


func get_lane_highlight_brightness() -> float:
	return float(settings.get("lane_highlight_brightness", default_settings["lane_highlight_brightness"]))

func set_lane_highlight_brightness(value: float):
	settings["lane_highlight_brightness"] = clampf(value, 0.0, 100.0)


func get_note_brightness() -> float:
	return float(settings.get("note_brightness", default_settings["note_brightness"]))

func set_note_brightness(value: float):
	settings["note_brightness"] = clampf(value, 0.0, 100.0)


func get_playfield_width_percent(lane_count: int) -> float:
	var lanes := clampi(lane_count, 3, 5)
	var key := "playfield_width_%d_lanes" % lanes
	return clampf(float(settings.get(key, default_settings.get(key, 100.0))), 70.0, 150.0)


func set_playfield_width_percent(lane_count: int, percent: float) -> void:
	var lanes := clampi(lane_count, 3, 5)
	var key := "playfield_width_%d_lanes" % lanes
	settings[key] = clampf(percent, 70.0, 150.0)


func get_note_approach_hint() -> int:
	return int(clamp(int(settings.get("note_approach_hint", default_settings["note_approach_hint"])), 0, 3))


func set_note_approach_hint(mode: int):
	settings["note_approach_hint"] = int(clamp(mode, 0, 3))


func get_duo_partner_note_style() -> String:
	return DuoMode.sanitize_style(
		str(settings.get("duo_partner_note_style", default_settings["duo_partner_note_style"]))
	)


func set_duo_partner_note_style(style: String) -> void:
	settings["duo_partner_note_style"] = DuoMode.sanitize_style(style)


func get_mute_when_unfocused() -> bool:
	return bool(settings.get("mute_when_unfocused", default_settings["mute_when_unfocused"]))


func set_mute_when_unfocused(enabled: bool) -> void:
	settings["mute_when_unfocused"] = enabled


func get_show_error_meter() -> bool:
	return bool(settings.get("show_error_meter", default_settings["show_error_meter"]))


func set_show_error_meter(enabled: bool) -> void:
	settings["show_error_meter"] = enabled


func get_show_health_bar() -> bool:
	return bool(settings.get("show_health_bar", default_settings["show_health_bar"]))


func set_show_health_bar(enabled: bool) -> void:
	settings["show_health_bar"] = enabled


func get_series_inter_track_countdown_enabled() -> bool:
	return bool(settings.get(
		"series_inter_track_countdown_enabled",
		default_settings["series_inter_track_countdown_enabled"]
	))


func set_series_inter_track_countdown_enabled(enabled: bool) -> void:
	settings["series_inter_track_countdown_enabled"] = enabled


func get_pause_resume_rewind_enabled() -> bool:
	return bool(settings.get("pause_resume_rewind_enabled", default_settings["pause_resume_rewind_enabled"]))


func set_pause_resume_rewind_enabled(enabled: bool) -> void:
	settings["pause_resume_rewind_enabled"] = enabled


func get_reduce_bg_effects() -> bool:
	return bool(settings.get("reduce_bg_effects", default_settings["reduce_bg_effects"]))


func set_reduce_bg_effects(enabled: bool) -> void:
	settings["reduce_bg_effects"] = enabled


func get_ambient_particles_enabled() -> bool:
	return bool(settings.get("ambient_particles_enabled", default_settings["ambient_particles_enabled"]))


func set_ambient_particles_enabled(enabled: bool) -> void:
	settings["ambient_particles_enabled"] = enabled


func get_audio_reactive_background() -> bool:
	return bool(settings.get("audio_reactive_background", default_settings["audio_reactive_background"]))


func set_audio_reactive_background(enabled: bool) -> void:
	settings["audio_reactive_background"] = enabled


func get_shop_kick_waveform_preview() -> bool:
	return bool(settings.get("shop_kick_waveform_preview", default_settings["shop_kick_waveform_preview"]))


func set_shop_kick_waveform_preview(enabled: bool) -> void:
	settings["shop_kick_waveform_preview"] = enabled


func get_enable_debug_menu() -> bool:
	return settings.get("enable_debug_menu", default_settings["enable_debug_menu"])

func set_enable_debug_menu(enabled: bool):
	settings["enable_debug_menu"] = enabled

func get_controls_keymap() -> Dictionary:
	var current_keymap = settings.get("controls_keymap", default_settings["controls_keymap"].duplicate(true))
	var display_keymap = {}
	for i in range(MAX_LANES):  
		var lane_key = "lane_%d_key" % i
		var scancode = current_keymap.get(lane_key, default_settings["controls_keymap"][lane_key])
		if scancode is int:
			display_keymap[lane_key] = _get_key_string_from_scancode(scancode)
		else:
			printerr("SettingsManager: get_controls_keymap: Некорректное значение для ", lane_key)
			display_keymap[lane_key] = _get_key_string_from_scancode(default_settings["controls_keymap"][lane_key])
	return display_keymap

func get_controls_keymap_scancode() -> Dictionary:
	return settings.get("controls_keymap", default_settings["controls_keymap"].duplicate(true)).duplicate(true)

func set_controls_keymap_scancode(new_keymap_scancode: Dictionary):
	settings["controls_keymap"] = new_keymap_scancode.duplicate(true)

func set_key_scancode_for_lane(lane_index: int, new_scancode: int, alt: bool = false) -> void:
	var lane_key := "lane_%d_key" % lane_index
	var map_key := "controls_keymap_alt" if alt else "controls_keymap"
	if not settings.has(map_key):
		settings[map_key] = (
			default_settings["controls_keymap_alt"] if alt else default_settings["controls_keymap"]
		).duplicate(true)
	settings[map_key][lane_key] = new_scancode


func get_key_scancode_for_lane(lane_index: int, alt: bool = false) -> int:
	if lane_index < 0 or lane_index >= MAX_LANES:
		return KEY_X
	var map_key := "controls_keymap_alt" if alt else "controls_keymap"
	var defaults: Dictionary = (
		default_settings["controls_keymap_alt"] if alt else default_settings["controls_keymap"]
	)
	var keymap: Dictionary = settings.get(map_key, defaults.duplicate(true))
	var lane_key := "lane_%d_key" % lane_index
	return int(keymap.get(lane_key, defaults.get(lane_key, KEY_X)))


func get_controls_keymap_alt_scancode() -> Dictionary:
	return ControlsBindings.sanitize_lane_keymap(
		settings.get("controls_keymap_alt", {}),
		default_settings["controls_keymap_alt"]
	).duplicate(true)


func set_controls_keymap_alt_scancode(new_keymap_scancode: Dictionary) -> void:
	settings["controls_keymap_alt"] = ControlsBindings.sanitize_lane_keymap(
		new_keymap_scancode,
		default_settings["controls_keymap_alt"]
	)


func get_key_text_for_lane(lane_index: int, alt: bool = false) -> String:
	return KeyInputUtils.get_key_string_from_scancode(get_key_scancode_for_lane(lane_index, alt))


func get_mediator_up_scancode(alt: bool = false) -> int:
	if alt:
		return int(settings.get(
			"controls_mediator_up_key_alt",
			default_settings["controls_mediator_up_key_alt"]
		))
	var legacy: Variant = settings.get("controls_strum_up_key", null)
	if legacy != null and not settings.has("controls_mediator_up_key"):
		return int(legacy)
	return int(settings.get(
		"controls_mediator_up_key",
		default_settings["controls_mediator_up_key"]
	))


func get_mediator_down_scancode(alt: bool = false) -> int:
	if alt:
		return int(settings.get(
			"controls_mediator_down_key_alt",
			default_settings["controls_mediator_down_key_alt"]
		))
	var legacy: Variant = settings.get("controls_strum_down_key", null)
	if legacy != null and not settings.has("controls_mediator_down_key"):
		return int(legacy)
	return int(settings.get(
		"controls_mediator_down_key",
		default_settings["controls_mediator_down_key"]
	))


func get_mediator_up_key_text(alt: bool = false) -> String:
	return KeyInputUtils.get_key_string_from_scancode(get_mediator_up_scancode(alt))


func get_mediator_down_key_text(alt: bool = false) -> String:
	return KeyInputUtils.get_key_string_from_scancode(get_mediator_down_scancode(alt))


func set_mediator_up_scancode(scancode: int, alt: bool = false) -> void:
	var key := "controls_mediator_up_key_alt" if alt else "controls_mediator_up_key"
	settings[key] = scancode


func set_mediator_down_scancode(scancode: int, alt: bool = false) -> void:
	var key := "controls_mediator_down_key_alt" if alt else "controls_mediator_down_key"
	settings[key] = scancode


func get_controls_layout_mode() -> String:
	return ControlsBindings.sanitize_layout_mode(
		settings.get("controls_layout_mode", default_settings["controls_layout_mode"])
	)


func set_controls_layout_mode(mode: String) -> void:
	settings["controls_layout_mode"] = ControlsBindings.sanitize_layout_mode(mode)


func build_layout_lane_keymap(layout_id: String, max_lanes: int = MAX_LANES) -> Dictionary:
	var scancodes := (
		get_controls_keymap_alt_scancode()
		if layout_id == ControlsBindings.LAYOUT_ALT
		else get_controls_keymap_scancode()
	)
	var full := ControlsBindings.build_lane_keymap(scancodes)
	var cap := clampi(max_lanes, 1, MAX_LANES)
	var out := {}
	for key in full:
		var lane := int(full[key])
		if lane < cap:
			out[key] = lane
	return out


func format_layout_lane_keys(layout_id: String, max_lanes: int = MAX_LANES) -> String:
	var scancodes := (
		get_controls_keymap_alt_scancode()
		if layout_id == ControlsBindings.LAYOUT_ALT
		else get_controls_keymap_scancode()
	)
	var parts: PackedStringArray = []
	for i in range(mini(max_lanes, MAX_LANES)):
		parts.append(_get_key_string_from_scancode(int(scancodes.get("lane_%d_key" % i, 0))))
	return " ".join(parts)


func build_active_lane_keymap(layout_mode: String = "") -> Dictionary:
	var mode := ControlsBindings.sanitize_layout_mode(
		layout_mode if layout_mode != "" else get_controls_layout_mode()
	)
	var out := {}
	if mode == ControlsBindings.LAYOUT_PRIMARY or mode == ControlsBindings.LAYOUT_BOTH:
		out = ControlsBindings.merge_lane_keymaps(
			out,
			ControlsBindings.build_lane_keymap(get_controls_keymap_scancode())
		)
	if mode == ControlsBindings.LAYOUT_ALT or mode == ControlsBindings.LAYOUT_BOTH:
		out = ControlsBindings.merge_lane_keymaps(
			out,
			ControlsBindings.build_lane_keymap(get_controls_keymap_alt_scancode())
		)
	return out


func get_active_mediator_up_scancodes(layout_mode: String = "") -> Array[int]:
	var mode := ControlsBindings.sanitize_layout_mode(
		layout_mode if layout_mode != "" else get_controls_layout_mode()
	)
	var values: Array = []
	if mode == ControlsBindings.LAYOUT_PRIMARY or mode == ControlsBindings.LAYOUT_BOTH:
		values.append(get_mediator_up_scancode(false))
	if mode == ControlsBindings.LAYOUT_ALT or mode == ControlsBindings.LAYOUT_BOTH:
		values.append(get_mediator_up_scancode(true))
	return ControlsBindings.dedupe_scancodes(values)


func get_active_mediator_down_scancodes(layout_mode: String = "") -> Array[int]:
	var mode := ControlsBindings.sanitize_layout_mode(
		layout_mode if layout_mode != "" else get_controls_layout_mode()
	)
	var values: Array = []
	if mode == ControlsBindings.LAYOUT_PRIMARY or mode == ControlsBindings.LAYOUT_BOTH:
		values.append(get_mediator_down_scancode(false))
	if mode == ControlsBindings.LAYOUT_ALT or mode == ControlsBindings.LAYOUT_BOTH:
		values.append(get_mediator_down_scancode(true))
	return ControlsBindings.dedupe_scancodes(values)


func get_strum_up_scancode() -> int:
	return get_mediator_up_scancode(false)


func get_strum_down_scancode() -> int:
	return get_mediator_down_scancode(false)


func get_strum_up_key_text() -> String:
	return get_mediator_up_key_text(false)


func get_strum_down_key_text() -> String:
	return get_mediator_down_key_text(false)


func set_strum_up_scancode(scancode: int) -> void:
	set_mediator_up_scancode(scancode, false)


func set_strum_down_scancode(scancode: int) -> void:
	set_mediator_down_scancode(scancode, false)

func _string_to_scancode(key_string: String) -> int:
	return KeyInputUtils.string_to_scancode(key_string)

func _get_key_string_from_scancode(scancode: int) -> String:
	return KeyInputUtils.get_key_string_from_scancode(scancode)
 
static func is_service_key(scancode: int) -> bool:
	return KeyInputUtils.is_service_key(scancode)


func _migrate_gh_controls_settings() -> void:
	for key in [
		"controls_gh_enabled",
		"controls_gh_auto_detect",
		"controls_gh_device_id",
		"controls_gh_lane_buttons",
		"controls_gh_strum_up_button",
		"controls_gh_strum_down_button",
		"controls_gh_pause_button",
		"controls_gh_skip_button",
	]:
		if not settings.has(key):
			settings[key] = default_settings[key]
	settings["controls_gh_lane_buttons"] = _GuitarHeroBindings.sanitize_lane_buttons(
		settings.get("controls_gh_lane_buttons", default_settings["controls_gh_lane_buttons"])
	)
	settings["controls_gh_strum_up_button"] = _GuitarHeroBindings.sanitize_button(
		settings.get("controls_gh_strum_up_button"),
		_GuitarHeroBindings.DEFAULT_STRUM_UP
	)
	settings["controls_gh_strum_down_button"] = _GuitarHeroBindings.sanitize_button(
		settings.get("controls_gh_strum_down_button"),
		_GuitarHeroBindings.DEFAULT_STRUM_DOWN
	)
	settings["controls_gh_pause_button"] = _GuitarHeroBindings.sanitize_button(
		settings.get("controls_gh_pause_button"),
		_GuitarHeroBindings.DEFAULT_PAUSE_BUTTON
	)
	settings["controls_gh_skip_button"] = _GuitarHeroBindings.sanitize_button(
		settings.get("controls_gh_skip_button"),
		_GuitarHeroBindings.DEFAULT_SKIP_BUTTON
	)


func get_controls_gh_enabled() -> bool:
	return bool(settings.get("controls_gh_enabled", default_settings["controls_gh_enabled"]))


func set_controls_gh_enabled(enabled: bool) -> void:
	settings["controls_gh_enabled"] = enabled
	_save_settings()


func get_controls_gh_auto_detect() -> bool:
	return bool(settings.get("controls_gh_auto_detect", default_settings["controls_gh_auto_detect"]))


func set_controls_gh_auto_detect(enabled: bool) -> void:
	settings["controls_gh_auto_detect"] = enabled
	_save_settings()


func get_controls_gh_device_id() -> int:
	return int(settings.get("controls_gh_device_id", default_settings["controls_gh_device_id"]))


func set_controls_gh_device_id(device_id: int) -> void:
	settings["controls_gh_device_id"] = device_id
	_save_settings()


func get_controls_gh_lane_buttons() -> Array[int]:
	return _GuitarHeroBindings.sanitize_lane_buttons(
		settings.get("controls_gh_lane_buttons", default_settings["controls_gh_lane_buttons"])
	)


func get_controls_gh_lane_button(lane: int) -> int:
	var buttons := get_controls_gh_lane_buttons()
	if lane < 0 or lane >= buttons.size():
		return -1
	return buttons[lane]


func set_controls_gh_lane_button(lane: int, button_index: int) -> void:
	var buttons := get_controls_gh_lane_buttons()
	if lane < 0 or lane >= buttons.size():
		return
	buttons[lane] = button_index
	settings["controls_gh_lane_buttons"] = buttons
	_save_settings()


func get_controls_gh_strum_up_button() -> int:
	return _GuitarHeroBindings.sanitize_button(
		settings.get("controls_gh_strum_up_button"),
		_GuitarHeroBindings.DEFAULT_STRUM_UP
	)


func get_controls_gh_strum_down_button() -> int:
	return _GuitarHeroBindings.sanitize_button(
		settings.get("controls_gh_strum_down_button"),
		_GuitarHeroBindings.DEFAULT_STRUM_DOWN
	)


func set_controls_gh_strum_up_button(button_index: int) -> void:
	settings["controls_gh_strum_up_button"] = button_index
	_save_settings()


func set_controls_gh_strum_down_button(button_index: int) -> void:
	settings["controls_gh_strum_down_button"] = button_index
	_save_settings()


func get_controls_gh_lane_button_text(lane: int) -> String:
	var button_index := get_controls_gh_lane_button(lane)
	if button_index < 0:
		return "?"
	return _GuitarHeroBindings.lane_button_label(lane, button_index)


func get_controls_gh_strum_up_text() -> String:
	return _GuitarHeroBindings.button_display_name(get_controls_gh_strum_up_button())


func get_controls_gh_strum_down_text() -> String:
	return _GuitarHeroBindings.button_display_name(get_controls_gh_strum_down_button())


func get_controls_gh_pause_button() -> int:
	return _GuitarHeroBindings.sanitize_button(
		settings.get("controls_gh_pause_button"),
		_GuitarHeroBindings.DEFAULT_PAUSE_BUTTON
	)


func get_controls_gh_skip_button() -> int:
	return _GuitarHeroBindings.sanitize_button(
		settings.get("controls_gh_skip_button"),
		_GuitarHeroBindings.DEFAULT_SKIP_BUTTON
	)


func set_controls_gh_pause_button(button_index: int) -> void:
	settings["controls_gh_pause_button"] = button_index
	_save_settings()


func set_controls_gh_skip_button(button_index: int) -> void:
	settings["controls_gh_skip_button"] = button_index
	_save_settings()


func get_controls_gh_pause_text() -> String:
	return _GuitarHeroBindings.button_display_name(get_controls_gh_pause_button())


func get_controls_gh_skip_text() -> String:
	return _GuitarHeroBindings.button_display_name(get_controls_gh_skip_button())


func resolve_gh_device_id() -> int:
	var configured := get_controls_gh_device_id()
	var connected := Input.get_connected_joypads()
	if configured >= 0 and connected.has(configured):
		return configured
	if configured < 0 or get_controls_gh_auto_detect():
		return _GuitarHeroBindings.resolve_auto_device_id()
	if configured >= 0:
		return configured
	return -1


func reset_gh_controls_to_default() -> void:
	settings["controls_gh_lane_buttons"] = _GuitarHeroBindings.DEFAULT_LANE_BUTTONS.duplicate()
	settings["controls_gh_strum_up_button"] = _GuitarHeroBindings.DEFAULT_STRUM_UP
	settings["controls_gh_strum_down_button"] = _GuitarHeroBindings.DEFAULT_STRUM_DOWN
	settings["controls_gh_pause_button"] = _GuitarHeroBindings.DEFAULT_PAUSE_BUTTON
	settings["controls_gh_skip_button"] = _GuitarHeroBindings.DEFAULT_SKIP_BUTTON
	settings["controls_gh_auto_detect"] = default_settings["controls_gh_auto_detect"]
	settings["controls_gh_device_id"] = default_settings["controls_gh_device_id"]
	_save_settings()


func reset_all_settings():
	var current_controls = settings.get("controls_keymap", {}).duplicate(true)
	var prev_window_mode := get_window_mode()
	var prev_resolution := get_window_resolution()
	var prev_language := String(settings.get("language", default_settings["language"]))

	settings = default_settings.duplicate(true)

	if not current_controls.is_empty():
		settings["controls_keymap"] = current_controls
	settings["window_mode"] = prev_window_mode
	settings["window_resolution"] = prev_resolution
	settings["language"] = prev_language

	_apply_reset_settings()
	_save_settings()

func _apply_reset_settings():
	apply_window_mode()
