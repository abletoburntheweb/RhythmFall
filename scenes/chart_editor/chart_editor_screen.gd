# scenes/chart_editor/chart_editor_screen.gd
extends Control
# P0 Chart Editor screen — BaseScreen compatible.

const ChartEditorStateClass = preload("res://logic/domain/editor/chart_editor_state.gd")
const ChartEditorCommands = preload("res://logic/domain/editor/chart_editor_commands.gd")
const EditorNoteUtilsClass = preload("res://logic/domain/editor/editor_note_utils.gd")
const ChartEditorCorrectionsClass = preload("res://logic/domain/editor/chart_editor_corrections.gd")
const ChartStemManagerClass = preload("res://logic/domain/editor/chart_stem_manager.gd")
const ChartGridClass = preload("res://logic/domain/editor/chart_grid.gd")
const ChartEditorPlayerClass = preload("res://logic/domain/editor/chart_editor_player.gd")
const ChartEditorBindings = preload("res://logic/domain/controls/chart_editor_bindings.gd")
const RfcCorrectionsCodec = preload("res://logic/domain/editor/rfc_corrections_codec.gd")
const RfTempCodec = preload("res://logic/domain/editor/rf_temp_codec.gd")
const _StatusToast = preload("res://logic/ui/status_toast.gd")
const _UiModifierSounds = preload("res://logic/ui/ui_modifier_sounds.gd")
const PerfTrace = preload("res://logic/utils/perf_trace.gd")

const MIDI_BROWSER_DIAGNOSTICS := true
var _diag_last_motion_ms: int = 0
var _fps_trace_active: bool = false
var _fps_trace_start_ms: int = 0
var _fps_trace_next_ms: int = 0
var _fps_trace_samples: int = 0
var _fps_trace_min_fps: float = 1e9
var _fps_trace_max_fps: float = 0.0
var _fps_trace_sum_fps: float = 0.0
const FPS_TRACE_DURATION_MS := 3000
const FPS_TRACE_INTERVAL_MS := 100
var _frame_diag_samples: int = 0
var _frame_diag_process_time: int = 0
var _frame_diag_process_count: int = 0
var _diag_last_input_ms: int = 0
var _diag_last_ghost_bar: float = -1.0
var _diag_last_split_offset: int = -9999
var _diag_was_inside_playfield: bool = false
var _diag_last_drag_inside: bool = false

# Deterministic gesture ownership state machine — one LMB gesture = one owner
var _gesture_owner: String = "" # "" = IDLE, "midi", "resize", "pencil", "select", "move", "box"
var _midi_drag_state: String = "" # "" / "outside" / "over_playfield"
var _midi_drag_preview: Control = null

var state: ChartEditorState = null
var undo_stack: ChartEditorCommands.UndoStack = null
var player: ChartEditorPlayer = null

# Injected via transitions payload or direct setup call.
var _pending_song_path: String = ""
var _pending_chart_stem: String = "arcade_medium"
var _pending_lanes: int = 5
var _pending_chart_path: String = ""

# Nodes (created in _ready if not in tscn).
var _playfield = null
var _overlay = null
var _inspector: Control = null
var _top_label: Label = null
var _canonical_label: Label = null
var _play_btn: Button = null
var _save_btn: Button = null
var _save_as_btn: Button = null
var _undo_btn: Button = null
var _redo_btn: Button = null
var _revert_btn: Button = null
var _back_btn: Button = null
var _snap_check: CheckBox = null
var _snap_option: OptionButton = null
var _audio_source_option: OptionButton = null
var _zoom_slider: HSlider = null
var _scroll: ScrollContainer = null
var _scroll_bar: VScrollBar = null
var _ruler: Control = null
var _status_label: Label = null
var _confirm_overlay = null
var _notice_overlay = null
var _zoom_minus: Button = null
var _zoom_plus: Button = null
var _zoom_value: Label = null
var _time_label: Label = null
var _bpm_label: Label = null
var _more_btn: Button = null
var _drum_palette_buttons: Dictionary = {} # drum -> Button
var _active_drum: String = "kick"
var _current_tool: String = "pencil" # "select" or "pencil" — default Pencil per spec 0
var _select_button: Button = null
var _pencil_button: Button = null
var _notes_mode_button: Button = null
var _midi_mode_button: Button = null
var _midi_pattern_container: Control = null
var _midi_pattern_list: ItemList = null
var _midi_pattern_info_label: Label = null
var _import_midi_button: Button = null
var _midi_import_dialog: FileDialog = null
var _midi_browser_tree: Tree = null
var _midi_browser_refresh_button: Button = null
var _midi_browser_root_path: String = ""
var _midi_scan_cache_root: String = ""
var _midi_scan_cache: Dictionary = {} # abs_dir -> {folders:Array, files:Array}
var _midi_folder_icon_cache: Texture2D = null
var _midi_folder_open_icon_cache: Texture2D = null
var _midi_file_icon_cache: Texture2D = null
var _palette_mode: String = "notes"
var _selected_pattern_id: String = ""
var _pattern_drag_active: bool = false
var _main_split: Control = null
var _inspector_pane: PanelContainer = null
var _pattern_drag_pattern: MidiPattern = null
var _pattern_drag_start_time: float = 0.0
var _pattern_drag_ghost_notes: Array = []

var _drag_scroll_accum: float = 0.0
var _sfx_player: AudioStreamPlayer = null
var _hit_sound_cooldown: Dictionary = {}
var _hit_hidden_keys: Dictionary = {} # visual hide after hit, seek-aware
var _hit_effect_cooldown: Dictionary = {}
var _prev_song_time: float = 0.0
var _timeline_scrubbing: bool = false
var _autosave_timer: float = 0.0
var _last_autosave_hash: String = ""
const AUTOSAVE_INTERVAL: float = 30.0
var _recovery_handled: bool = false
# Undo/Redo repeat (spec 5)
var _undo_held: bool = false
var _redo_held: bool = false
var _undo_hold_time: float = 0.0
var _redo_hold_time: float = 0.0
var _undo_next_repeat: float = 0.35
var _redo_next_repeat: float = 0.35
const REPEAT_INITIAL_DELAY: float = 0.35
const REPEAT_INTERVAL: float = 0.12
# DIAG hold — throttling without Time.get_ticks_msec
var _undo_diag_last_log_t: float = -100.0
var _redo_diag_last_log_t: float = -100.0
# Delete sound single-play guard (spec 4) + debug logging
var _delete_sound_frame_guard: int = -1
var _delete_sound_debug_counter: int = 0
# Mouse hold guard (spec 6) — track last LMB press to prevent paint spam
var _last_lmb_press_msec: int = -999999
# Gesture transfer UI -> Playfield (spec 4) — track if LMB/RMB was pressed outside playfield and not yet transferred
var _gesture_lmb_armed_outside: bool = false
var _gesture_rmb_armed_outside: bool = false
# Focus helper (spec 7)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		# Never auto-play on focus restore — preserve pause state (spec 9, 18)
		pass
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if MIDI_BROWSER_DIAGNOSTICS and (_pattern_drag_active or _gesture_owner != "" or _left_split_dragging):
			print("[RF_DIAG] GLOBAL SAFETY focus loss what=%d clearing gesture_owner=%s pattern_drag=%s split_drag=%s" % [what, _gesture_owner, str(_pattern_drag_active), str(_left_split_dragging)])
		if _pattern_drag_active or _gesture_owner == "midi":
			_clear_pattern_ghost()
			_clear_midi_drag_preview()
			_pattern_drag_pattern = null
			_pattern_drag_active = false
			_gesture_owner = ""
			_midi_drag_state = ""
		_left_split_dragging = false
		_gesture_lmb_armed_outside = false
		_gesture_rmb_armed_outside = false
		_set_ui_capture_during_gesture(false)

func _setup_sfx() -> void:
	if _sfx_player == null:
		_sfx_player = AudioStreamPlayer.new()
		_sfx_player.name = "EditorSfxPlayer"
		_sfx_player.bus = "Master"
		add_child(_sfx_player)

func _play_sfx(path: String, volume_db: float = 0.0) -> void:
	if path == "":
		return
	_setup_sfx()
	var stream := load(path) as AudioStream
	if stream == null:
		return
	_sfx_player.stream = stream
	_sfx_player.volume_db = volume_db
	_sfx_player.play()

func _play_hit_feedback(drum: String = "kick") -> void:
	# Use game hit sound via MusicManager if available, else fallback to select_click
	if MusicManager and MusicManager.has_method("play_hit_sound"):
		var is_kick := drum.to_lower() == "kick"
		MusicManager.play_hit_sound(is_kick)
	else:
		_play_sfx("res://assets/audio/sfx/select_click.wav", -4.0)

var _last_delete_sound_ms: int = -999999
func _play_delete_feedback(logical_action: String = "delete") -> void:
	# Authoritative delete sound — ONE play per logical action (spec 4)
	# Debug logging: logical action + call site
	var frame := Engine.get_frames_drawn()
	if _delete_sound_frame_guard == frame:
		# Duplicate play in same frame → suppress but log for diagnosis
		print("[ChartEditor][DeleteSound] SUPPRESSED duplicate in frame %d for action '%s' callSite=%s" % [frame, logical_action, str(get_stack()[1].get("function", "?"))])
		return
	_delete_sound_frame_guard = frame
	_delete_sound_debug_counter += 1
	# Actual play via MusicManager (respects SFX volume, not independent Master bus)
	# Log logical action and actual play
	print("[ChartEditor][DeleteSound] #%d action='%s' frame=%d call=%s" % [_delete_sound_debug_counter, logical_action, frame, str(get_stack()[1].get("function", "?"))])
	if MusicManager and MusicManager.has_method("play_modifier_deselect_sound"):
		MusicManager.play_modifier_deselect_sound()
		print("[ChartEditor][DeleteSound] actual play() via MusicManager frame=%d" % frame)
	else:
		# Fallback only if MusicManager missing (should not happen)
		_play_sfx("res://assets/audio/sfx/modifier_deselect.wav", -2.0)
		print("[ChartEditor][DeleteSound] actual play() via fallback _sfx_player frame=%d" % frame)

func _return_focus_to_editor() -> void:
	# Spec 5/7: real focus lifecycle — after non-text control action, control must not retain Space
	var vp := get_viewport()
	if vp == null:
		return
	var fo := vp.gui_get_focus_owner()
	if fo is TextEdit or fo is LineEdit:
		return
	if fo is OptionButton and (fo as OptionButton).get_popup() and (fo as OptionButton).get_popup().visible:
		return
	if fo is MenuButton and (fo as MenuButton).get_popup() and (fo as MenuButton).get_popup().visible:
		return
	# Immediate release — deferred alone left a frame where Space was still captured
	if fo and fo.has_method("release_focus"):
		fo.release_focus()
	if vp.has_method("gui_release_focus"):
		# Fallback: clear any focus
		pass
	# Grab focus to editor screen itself (FOCUS_ALL) so Space reaches _unhandled_input
	if has_method("grab_focus"):
		grab_focus()
	# Also deferred as safety for cases where focus was just set
	call_deferred("grab_focus")

func _is_action_physically_held(action: String) -> bool:
	if SettingsManager != null:
		var km := SettingsManager.get_chart_editor_keymap() if SettingsManager.has_method("get_chart_editor_keymap") else {}
		var bindings = km.get(action, [])
		if bindings is Array:
			for b in bindings:
				if b is Dictionary:
					var key := int(b.get("key", 0))
					var need_ctrl := bool(b.get("ctrl", false))
					var need_shift := bool(b.get("shift", false))
					var need_alt := bool(b.get("alt", false))
					if key == 0:
						continue
					var key_held := Input.is_physical_key_pressed(key) or Input.is_key_pressed(key)
					if not key_held:
						continue
					var ctrl_held := Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)
					var shift_held := Input.is_key_pressed(KEY_SHIFT)
					var alt_held := Input.is_key_pressed(KEY_ALT)
					if need_ctrl != ctrl_held:
						continue
					if need_shift != shift_held:
						continue
					if need_alt != alt_held:
						continue
					return true
	# Fallback for default bindings when SettingsManager not ready or keymap empty (ensures hold works)
	if action == "undo":
		return (Input.is_physical_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_Z)) and (Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)) and not Input.is_key_pressed(KEY_SHIFT) and not Input.is_key_pressed(KEY_ALT)
	if action == "redo":
		var ctrl_held := Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)
		var y_held := Input.is_physical_key_pressed(KEY_Y) or Input.is_key_pressed(KEY_Y)
		var z_held := Input.is_physical_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_Z)
		var shift_held := Input.is_key_pressed(KEY_SHIFT)
		if y_held and ctrl_held and not shift_held and not Input.is_key_pressed(KEY_ALT):
			return true
		if z_held and ctrl_held and shift_held and not Input.is_key_pressed(KEY_ALT):
			return true
	return false

func _get_note_display_color(note: Dictionary) -> Color:
	var mode := 0
	if SettingsManager:
		mode = SettingsManager.get_chart_editor_note_color_mode()
	var lane := int(note.get("lane", 0))
	if mode == 1:
		# lane-based: reuse shop Notes palette via lane index
		if _playfield and _playfield is GamePlayfield and _playfield.lane_colors_cache.size() > lane:
			return _playfield.lane_colors_cache[lane]
		# fallback to drum
	return EditorNoteUtils.color_for_drum(String(note.get("drum", "kick")).to_lower())

func _trigger_hit_visual(note: Dictionary, key: String) -> void:
	if state == null or _playfield == null:
		return
	var lane := int(note.get("lane", 0))
	# hide after hit (visual only)
	if SettingsManager and SettingsManager.get_chart_editor_hide_notes_after_hit():
		if not _hit_hidden_keys.has(key):
			_hit_hidden_keys[key] = true
			if _playfield.has_method("set_hidden_keys"):
				_playfield.set_hidden_keys(_hit_hidden_keys)
	# hit effects toggle
	if SettingsManager and not SettingsManager.get_chart_editor_hit_effects_enabled():
		return
	# debounce visual per lane+key
	var now := Time.get_ticks_msec() / 1000.0
	var last_v := float(_hit_effect_cooldown.get(key, -999.0))
	if now - last_v < 0.08:
		return
	_hit_effect_cooldown[key] = now
	# lane highlight flash (reuse GamePlayfield highlight)
	if _playfield.has_method("flash_lane"):
		_playfield.flash_lane(lane, 0.12)
	# particles — reuse HitParticlePresets with shop-selected preset
	var base_col := _get_note_display_color(note)
	var preset := {}
	if HitParticlePresets:
		preset = HitParticlePresets.resolve_active_preset()
	var pos := Vector2.ZERO
	if _playfield and _playfield.has_method("get_lane_left_x") and _playfield.has_method("get_lane_width_at") and _playfield.has_method("get_hit_y"):
		var lx: float = _playfield.get_lane_left_x(lane)
		var lw: float = _playfield.get_lane_width_at(lane)
		var hy: float = float(_playfield.get_hit_y())
		pos = Vector2(lx + lw * 0.5, hy)
		# convert playfield local to global then to notes_container? spawn parent is playfield or its NotesContainer
		var parent = _playfield.get_notes_container() if _playfield.has_method("get_notes_container") else _playfield
		if parent == null or not is_instance_valid(parent):
			parent = _playfield
		HitParticlePresets.spawn(parent, pos, base_col, true, preset)

func _on_ruler_seek(time: float) -> void:
	# Timeline scrub — seek without changing play/pause (spec 23, 17)
	_go_to_time(time)
	# Ensure focus returns to editor so Space still works (spec 10)
	_return_focus_to_editor()

# --- .rf.temp autosave / recovery (Stage C) ---
func _get_temp_path_for_current() -> String:
	if state == null:
		return ""
	return RfTempCodec.temp_path_for_versioned(state.song_path, state.instrument, state.base_stem, state.version)

func _get_document_hash() -> String:
	if state == null or state.document == null:
		return ""
	return RfcCorrectionsCodec._hash_notes(state.document.notes)

func _should_autosave() -> bool:
	if state == null or state.document == null:
		return false
	if not state.is_dirty:
		return false
	var cur_hash := _get_document_hash()
	if cur_hash == _last_autosave_hash:
		return false
	return true

func _do_autosave() -> bool:
	if state == null:
		return false
	if not _should_autosave():
		return false
	var temp_path := _get_temp_path_for_current()
	if temp_path == "":
		return false
	var source_notes := _get_source_notes_for_diff()
	var source_hash := RfcCorrectionsCodec._hash_notes(source_notes) if not source_notes.is_empty() else state.source_hash_cache
	var payload := RfTempCodec.build_payload(
		state.song_path, state.instrument, state.base_stem, state.version,
		state.document.notes, state.bpm, state.lanes,
		source_notes, temp_path.replace(".temp", ""), source_hash,
		state.parent_version_cache, state.parent_hash_cache
	)
	# Use versioned source path as source_path
	var src_path := RfcCorrectionsCodec.versioned_path_for(state.song_path, state.instrument, state.base_stem, 0, "rf")
	payload["source"]["path"] = src_path
	var ok := RfTempCodec.write_file(temp_path, payload)
	if ok:
		_last_autosave_hash = _get_document_hash()
		_autosave_timer = 0.0
		print("[ChartEditor] autosave temp", temp_path)
	return ok

func _delete_temp_for_current() -> void:
	var tp := _get_temp_path_for_current()
	if tp != "" and FileAccess.file_exists(DirectoryUtils.to_absolute(tp)):
		RfTempCodec.delete_temp(tp)
		print("[ChartEditor] deleted temp", tp)
	_last_autosave_hash = _get_document_hash()

func _delete_temp_for_version(version: int) -> void:
	if state == null:
		return
	var tp := RfTempCodec.temp_path_for_versioned(state.song_path, state.instrument, state.base_stem, version)
	if FileAccess.file_exists(DirectoryUtils.to_absolute(tp)):
		RfTempCodec.delete_temp(tp)

func _maybe_autosave(delta: float) -> void:
	if state == null or not state.is_dirty:
		_autosave_timer = 0.0
		return
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		if _should_autosave():
			_do_autosave()
		_autosave_timer = 0.0

func _ready() -> void:
	var _t_total := PerfTrace.begin("perf.load.chart_editor.total")
	add_to_group("locale_refresh")
	focus_mode = Control.FOCUS_ALL
	var _t_ui := PerfTrace.begin("perf.load.chart_editor.ui")
	_setup_ui()
	PerfTrace.end("perf.load.chart_editor.ui", _t_ui)
	_fps_print("[PERF][FPS] chart_editor ready_probe")
	_connect_signals()
	# Чтобы Space/Esc стабильно ловились без клика по playfield
	call_deferred("grab_focus")
	if _pending_song_path != "":
		var _t_tr := PerfTrace.begin("perf.load.chart_editor.transition")
		PerfTrace.end("perf.load.chart_editor.transition", _t_tr)
		call_deferred("_open_chart", _pending_song_path, _pending_chart_stem, _pending_lanes, _pending_chart_path)
	PerfTrace.end("perf.load.chart_editor.total", _t_total)
	_start_fps_trace()
	if MIDI_BROWSER_DIAGNOSTICS:
		call_deferred("_diag_log_ready")

func _diag_log_ready() -> void:
	if not MIDI_BROWSER_DIAGNOSTICS:
		return
	var scene_path: String = str(get_tree().current_scene.scene_file_path) if get_tree().current_scene and get_tree().current_scene.has_method("get") else str(get_path())
	if get_tree().current_scene and (get_tree().current_scene as Node).has_method("get_scene_file_path"):
		scene_path = (get_tree().current_scene as Node).scene_file_path
	var script_path: String = "unknown"
	if get_script():
		script_path = String((get_script() as Script).resource_path)
	var midi_path := _get_midi_samples_root()
	var midi_browser := get_node_or_null("ContentRow/DrumPalettePane/DrumPaletteVBox/MidiPatternContainer/MidiBrowserTree")
	var content_row := get_node_or_null("ContentRow")
	var main_split := get_node_or_null("ContentRow/MainSplit")
	var inspector := get_node_or_null("ContentRow/MainSplit/InspectorPane")
	var playfield_pane := get_node_or_null("ContentRow/MainSplit/PlayfieldPane")
	print("[RF_DIAG] ChartEditorScreen READY")
	print("[RF_DIAG] scene=%s" % scene_path)
	print("[RF_DIAG] script=%s" % script_path)
	print("[RF_DIAG] midi_samples_path=%s" % midi_path)
	print("[RF_DIAG] midi_browser_exists=%s" % str(midi_browser != null))
	print("[RF_DIAG] midi_browser_type=%s" % (str(midi_browser.get_class()) if midi_browser else "null"))
	print("[RF_DIAG] content_row_type=%s" % (str(content_row.get_class()) if content_row else "null"))
	print("[RF_DIAG] content_row_split_offset=%s" % str((content_row as HSplitContainer).split_offset if content_row is HSplitContainer else "n/a"))
	print("[RF_DIAG] inspector_type=%s" % (str(inspector.get_class()) if inspector else "null"))
	print("[RF_DIAG] inspector_min_width=%s" % str((inspector as Control).custom_minimum_size.x if inspector is Control else "n/a"))
	print("[RF_DIAG] nodes ContentRow=%s MidiBrowserTree=%s MainSplit=%s InspectorPane=%s PlayfieldPane=%s" % [str(content_row != null), str(midi_browser != null), str(main_split != null), str(inspector != null), str(playfield_pane != null)])
	# Signals audit
	var midi_tree_gui := false
	var item_act := false
	var item_coll := false
	var left_drag := false
	if midi_browser is Tree:
		midi_tree_gui = (midi_browser as Tree).gui_input.is_connected(_on_midi_browser_tree_gui_input) if midi_browser.has_signal("gui_input") else false
		item_act = (midi_browser as Tree).item_activated.is_connected(_on_midi_browser_item_activated)
		item_coll = (midi_browser as Tree).item_collapsed.is_connected(_on_midi_browser_item_collapsed)
	var left_split := get_node_or_null("ContentRow") as HSplitContainer
	if left_split:
		left_drag = left_split.dragged.is_connected(_on_left_split_dragged)
	print("[RF_DIAG] SIGNALS CONNECTED midi_tree_gui_input=%s item_activated=%s item_collapsed=%s left_split_dragged=%s" % [str(midi_tree_gui), str(item_act), str(item_coll), str(left_drag)])

func _fps_print(msg: String) -> void:
	var c := get_tree().root.get_node_or_null("Console") if get_tree() and get_tree().root else null
	if c and c.has_method("print_line"):
		c.call("print_line", msg)
	elif c and c.has_method("print_info"):
		c.call("print_info", msg)

func _start_fps_trace() -> void:
	_fps_print("[PERF][FPS] chart_editor trace_start called is_detail=%s level=%s" % [str(PerfTrace.is_enabled(PerfTrace.Level.DETAIL)), PerfTrace.level_name()])
	if not PerfTrace.is_enabled(PerfTrace.Level.DETAIL):
		_fps_print("[PERF][FPS] chart_editor trace_start skipped (DETAIL OFF)")
		return
	_fps_trace_active = true
	_fps_trace_start_ms = Time.get_ticks_msec()
	_fps_trace_next_ms = _fps_trace_start_ms
	_fps_trace_samples = 0
	_fps_trace_min_fps = 1e9
	_fps_trace_max_fps = 0.0
	_fps_trace_sum_fps = 0.0
	_fps_trace_process_logged = false
	set_process(true)
	_fps_print("[PERF][FPS] chart_editor trace started active=%s process=%s" % [str(_fps_trace_active), str(is_processing())])

var _fps_trace_process_logged: bool = false

func _update_fps_trace() -> void:
	if not _fps_trace_process_logged:
		_fps_trace_process_logged = true
		_fps_print("[PERF][FPS] chart_editor process_started active=%s" % str(_fps_trace_active))
	if not _fps_trace_active:
		return
	var now := Time.get_ticks_msec()
	if now < _fps_trace_next_ms:
		return
	var elapsed_s := float(now - _fps_trace_start_ms) / 1000.0
	var fps := float(Engine.get_frames_per_second())
	if fps < 1.0:
		fps = 1.0 / maxf(get_process_delta_time(), 0.001)
	var frame_ms := 1000.0 / maxf(fps, 1.0)
	_fps_trace_samples += 1
	_fps_trace_sum_fps += fps
	_fps_trace_min_fps = minf(_fps_trace_min_fps, fps)
	_fps_trace_max_fps = maxf(_fps_trace_max_fps, fps)
	_fps_print("[PERF][FPS] chart_editor t=%.2fs fps=%d frame=%.1fms" % [elapsed_s, int(round(fps)), frame_ms])
	var avg_proc := float(_frame_diag_process_time) / float(maxi(_frame_diag_process_count,1)) / 1000.0 if _frame_diag_process_count>0 else 0.0
	_fps_print("[PERF][FRAME] chart_editor t=%.2f process=%.2fms count=%d" % [elapsed_s, avg_proc, _frame_diag_process_count])
	_fps_trace_next_ms = now + FPS_TRACE_INTERVAL_MS
	if now - _fps_trace_start_ms >= FPS_TRACE_DURATION_MS:
		var avg := _fps_trace_sum_fps / float(maxi(_fps_trace_samples, 1))
		_fps_print("[PERF][FPS] chart_editor summary samples=%d min=%d avg=%d max=%d" % [_fps_trace_samples, int(round(_fps_trace_min_fps)), int(round(avg)), int(round(_fps_trace_max_fps))])
		var avg_proc2 := float(_frame_diag_process_time) / float(maxi(_frame_diag_process_count,1)) / 1000.0 if _frame_diag_process_count>0 else 0.0
		_fps_print("[PERF][FRAME] chart_editor summary process_avg=%.2fms count=%d" % [avg_proc2, _frame_diag_process_count])
		_fps_trace_active = false

func setup_with_song(song_path: String, chart_stem: String = "arcade_medium", lanes: int = 5, chart_path: String = "") -> void:
	_pending_song_path = song_path
	_pending_chart_stem = chart_stem
	_pending_lanes = lanes
	_pending_chart_path = chart_path.strip_edges().replace("\\", "/")
	if is_inside_tree():
		_open_chart(song_path, chart_stem, lanes, _pending_chart_path)

# For Transitions API: generic payload.
func setup(payload: Dictionary) -> void:
	var sp := String(payload.get("song_path", payload.get("path", "")))
	var stem := String(payload.get("chart_stem", payload.get("chart_mode", "arcade_medium")))
	var lanes := int(payload.get("lanes", 5))
	var cpath := String(payload.get("chart_path", ""))
	if cpath.strip_edges() != "":
		setup_with_song(sp, stem, lanes, cpath)
	else:
		setup_with_song(sp, stem, lanes)

func _find_node_any(paths: Array) -> Node:
	for p in paths:
		var n := get_node_or_null(String(p))
		if n:
			return n
	return null

func _setup_ui() -> void:
	# TopBar already in tscn if present; otherwise create minimal.
	if has_node("TopBar/BackButton") or has_node("TopBar/TopBarHBox/BackButton"):
		var _t_find := PerfTrace.begin("perf.detail.chart_editor.setup_ui.find_node")
		if has_node("TopBar/TopBarHBox/BackButton"):
			_back_btn = get_node("TopBar/TopBarHBox/BackButton") as Button
			_top_label = get_node("TopBar/TopBarHBox/TitleLabel") as Label
			_canonical_label = get_node_or_null("TopBar/TopBarHBox/CanonicalLabel") as Label
			_play_btn = get_node_or_null("TopBar/TopBarHBox/PlayButton") as Button
			_save_btn = get_node_or_null("TopBar/TopBarHBox/SaveButton") as Button
			_save_as_btn = get_node_or_null("TopBar/TopBarHBox/SaveAsButton") as Button
			_undo_btn = get_node_or_null("TopBar/TopBarHBox/UndoButton") as Button
			_redo_btn = get_node_or_null("TopBar/TopBarHBox/RedoButton") as Button
			_revert_btn = get_node_or_null("TopBar/TopBarHBox/RevertButton") as Button
		else:
			_back_btn = get_node("TopBar/BackButton") as Button
			_top_label = get_node("TopBar/TitleLabel") as Label
			_canonical_label = get_node_or_null("TopBar/CanonicalLabel") as Label
			_play_btn = get_node_or_null("TopBar/PlayButton") as Button
			_save_btn = get_node_or_null("TopBar/SaveButton") as Button
			_undo_btn = get_node_or_null("TopBar/UndoButton") as Button
			_redo_btn = get_node_or_null("TopBar/RedoButton") as Button
			_revert_btn = get_node_or_null("TopBar/RevertButton") as Button
		_more_btn = get_node_or_null("TopBar/TopBarHBox/MoreButton") as Button
		if _save_as_btn == null:
			_save_as_btn = get_node_or_null("TopBar/SaveAsButton") as Button
		_select_button = get_node_or_null("ContentRow/DrumPalettePane/DrumPaletteVBox/SelectButton") as Button
		_pencil_button = get_node_or_null("ContentRow/DrumPalettePane/DrumPaletteVBox/PencilButton") as Button
		if _select_button and not _select_button.pressed.is_connected(_on_select_tool_pressed):
			_select_button.pressed.connect(_on_select_tool_pressed)
		if _pencil_button and not _pencil_button.pressed.is_connected(_on_pencil_tool_pressed):
			_pencil_button.pressed.connect(_on_pencil_tool_pressed)
		_update_tool_buttons()
		# Snap moved to BottomBar per UX spec (Snap = where new/moved notes land)
		_snap_check = get_node_or_null("TopBar/TopBarHBox/SnapCheck")
		if _snap_check == null:
			_snap_check = get_node_or_null("TopBar/SnapCheck")
		if _snap_check == null:
			_snap_check = get_node_or_null("BottomBar/BottomHBox/SnapCheck")
		if _snap_check == null:
			_snap_check = _find_node_any(["BottomBar/BottomHBox/SnapCheck", "BottomBar/SnapCheck"]) as CheckBox
		_snap_option = get_node_or_null("TopBar/TopBarHBox/SnapOption")
		if _snap_option == null:
			_snap_option = get_node_or_null("TopBar/SnapOption")
		if _snap_option == null:
			_snap_option = get_node_or_null("BottomBar/BottomHBox/SnapOption")
		if _snap_option == null:
			_snap_option = _find_node_any(["BottomBar/BottomHBox/SnapOption", "BottomBar/SnapOption"]) as OptionButton
		_audio_source_option = get_node_or_null("BottomBar/BottomHBox/AudioSourceOption") as OptionButton
		if _audio_source_option == null:
			_audio_source_option = _find_node_any(["BottomBar/BottomHBox/AudioSourceOption", "TopBar/AudioSourceOption"]) as OptionButton
		# ContentRow/MainSplit variants (mockup) + legacy MainSplit
		_scroll = _find_node_any([
			"ContentRow/MainSplit/PlayfieldPane/Scroll",
			"MainSplit/PlayfieldPane/Scroll",
			"ContentRow/MainSplit/PlayfieldPane/PlayfieldVBox/Scroll",
			"MainSplit/PlayfieldPane/PlayfieldVBox/Scroll"
		]) as ScrollContainer
		_ruler = _find_node_any([
			"ContentRow/MainSplit/PlayfieldPane/PlayfieldVBox/Ruler",
			"MainSplit/PlayfieldPane/PlayfieldVBox/Ruler",
			"ContentRow/MainSplit/PlayfieldPane/Ruler",
			"MainSplit/PlayfieldPane/Ruler"
		]) as Control
		_status_label = _find_node_any([
			"BottomBar/BottomHBox/StatusLabel",
			"BottomBar/StatusLabel"
		]) as Label
		_zoom_slider = _find_node_any([
			"BottomBar/BottomHBox/ZoomSlider",
			"BottomBar/ZoomSlider"
		]) as HSlider
		_zoom_minus = get_node_or_null("BottomBar/BottomHBox/ZoomMinus") as Button
		_zoom_plus = get_node_or_null("BottomBar/BottomHBox/ZoomPlus") as Button
		_zoom_value = get_node_or_null("BottomBar/BottomHBox/ZoomValue") as Label
		# Double-click on Zoom slider resets to default (spec 6.1) — same as Modifier sliders
		if _zoom_slider and not _zoom_slider.gui_input.is_connected(_on_zoom_slider_gui_input):
			_zoom_slider.gui_input.connect(_on_zoom_slider_gui_input)
		_time_label = get_node_or_null("BottomBar/BottomHBox/TimeLabel") as Label
		_bpm_label = get_node_or_null("BottomBar/BottomHBox/BPMLabel") as Label
		# Audio source dropdown — set localized items
		if _audio_source_option:
			_audio_source_option.clear()
			var orig_txt := tr("CHART_EDITOR_AUDIO_SOURCE_ORIGINAL")
			if orig_txt == "CHART_EDITOR_AUDIO_SOURCE_ORIGINAL" or orig_txt == "":
				orig_txt = "Оригинал"
			var drums_txt := tr("CHART_EDITOR_AUDIO_SOURCE_DRUMS")
			if drums_txt == "CHART_EDITOR_AUDIO_SOURCE_DRUMS" or drums_txt == "":
				drums_txt = "Drums Stem"
			_audio_source_option.add_item(orig_txt, 0)
			_audio_source_option.add_item(drums_txt, 1)
			_audio_source_option.select(0)
		# Snap localization: Off -> ВЫКЛ for RU (spec 14)
		if _snap_option and _snap_option.item_count > 0:
			var snap_off_txt := tr("CHART_EDITOR_SNAP_OFF")
			if snap_off_txt == "CHART_EDITOR_SNAP_OFF" or snap_off_txt == "":
				snap_off_txt = "ВЫКЛ"
			_snap_option.set_item_text(0, snap_off_txt)
		var pf := _find_node_any([
			"ContentRow/MainSplit/PlayfieldPane/PlayfieldVBox/Playfield",
			"ContentRow/MainSplit/PlayfieldPane/PlayfieldVBox/Scroll/Playfield",
			"MainSplit/PlayfieldPane/PlayfieldVBox/Scroll/Playfield",
			"ContentRow/MainSplit/PlayfieldPane/Scroll/Playfield",
			"MainSplit/PlayfieldPane/Scroll/Playfield"
		]) as Control
		if pf:
			_playfield = pf
		var insp := _find_node_any([
			"ContentRow/MainSplit/InspectorPane/InspectorRoot/InspectorScroll/Inspector",
			"ContentRow/MainSplit/InspectorPane/Inspector",
			"ContentRow/MainSplit/InspectorPane/InspectorScroll/Inspector",
			"MainSplit/InspectorPane/InspectorRoot/InspectorScroll/Inspector",
			"MainSplit/InspectorPane/Inspector",
			"MainSplit/InspectorPane/InspectorScroll/Inspector"
		]) as Control
		if insp:
			_inspector = insp
		PerfTrace.end("perf.detail.chart_editor.setup_ui.find_node", _t_find)
		var _t_drum2 := PerfTrace.begin("perf.detail.chart_editor.setup_drum_palette2")
		_setup_drum_palette()
		PerfTrace.end("perf.detail.chart_editor.setup_drum_palette2", _t_drum2)
		var _t_midi2 := PerfTrace.begin("perf.detail.chart_editor.setup_midi_palette2")
		_setup_midi_palette()
		PerfTrace.end("perf.detail.chart_editor.setup_midi_palette2", _t_midi2)
		var _t_inspec2 := PerfTrace.begin("perf.detail.chart_editor.setup_inspector2")
		_setup_inspector_resizable()
		PerfTrace.end("perf.detail.chart_editor.setup_inspector2", _t_inspec2)
		var _t_bottom := PerfTrace.begin("perf.detail.chart_editor.setup_ui.bottom_extra")
		_setup_bottom_extra()
		PerfTrace.end("perf.detail.chart_editor.setup_ui.bottom_extra", _t_bottom)
		_connect_scroll_sync()
		_setup_sfx()
		_setup_top_menu()
		_update_tool_buttons()
		var _t_focus := PerfTrace.begin("perf.detail.chart_editor.setup_ui.focus_policy")
		_apply_focus_policy()
		PerfTrace.end("perf.detail.chart_editor.setup_ui.focus_policy", _t_focus)
	else:
		# Fallback minimal UI (for tests without tscn)
		_build_fallback_ui()

func _apply_focus_policy() -> void:
	# Spec 6: non-text controls must not retain Space — make them FOCUS_NONE so Space always reaches editor
	# Keep TextEdit/LineEdit/OptionButton popup navigation intact
	var no_focus_nodes: Array[Node] = []
	for n in [_snap_check, _snap_option, _audio_source_option, _zoom_slider, _zoom_minus, _zoom_plus, _select_button, _pencil_button, _play_btn, _save_btn, _save_as_btn, _undo_btn, _redo_btn, _back_btn, _more_btn, _revert_btn]:
		if n is Control:
			no_focus_nodes.append(n as Node)
	# Also drum palette buttons
	for drum in _drum_palette_buttons.keys():
		var btn: Button = _drum_palette_buttons[drum] as Button
		if btn:
			no_focus_nodes.append(btn)
	# TopBar MenuButtons should not keep focus after click (Menu popup handles its own)
	for path in ["MenuBar/FileMenu", "MenuBar/EditMenu", "MenuBar/ViewMenu", "MenuBar/ChartMenu", "MenuBar/PlaybackMenu", "MenuBar/ToolsMenu", "MenuBar/HelpMenu"]:
		var mb := get_node_or_null(path) as Control
		if mb:
			no_focus_nodes.append(mb)
	for node in no_focus_nodes:
		if node is Control:
			(node as Control).focus_mode = Control.FOCUS_NONE

func _set_ui_capture_during_gesture(active: bool) -> void:
	# Spec 3: active gesture should not break when cursor moves between UI and Playfield
	var filter := Control.MOUSE_FILTER_IGNORE if active else Control.MOUSE_FILTER_STOP
	for path in ["ContentRow/DrumPalettePane", "ContentRow/MainSplit/InspectorPane", "TopBar", "BottomBar", "MenuBar"]:
		var n := get_node_or_null(path) as Control
		if n:
			n.mouse_filter = filter
	# Also for Inspector's ScrollContainer if exists
	var insp_scroll := get_node_or_null("ContentRow/MainSplit/InspectorPane/InspectorRoot/InspectorScroll") as Control
	if insp_scroll == null:
		insp_scroll = get_node_or_null("ContentRow/MainSplit/InspectorPane/InspectorScroll") as Control
	if insp_scroll:
		insp_scroll.mouse_filter = filter

func _is_mouse_inside_playfield(global_pos: Vector2) -> bool:
	if _playfield == null or not is_instance_valid(_playfield):
		return false
	var rect := (_playfield as Control).get_global_rect()
	return rect.has_point(global_pos)

func _get_overlay_local_for_global(global_pos: Vector2) -> Vector2:
	if _playfield == null or not is_instance_valid(_playfield):
		return Vector2.ZERO
	var rect := (_playfield as Control).get_global_rect()
	return global_pos - rect.position

func _is_overlay_gesture_active() -> bool:
	if _overlay == null or not is_instance_valid(_overlay):
		return false
	# Match _process check: any active drag/box/paint/pending
	return _overlay._is_dragging or _overlay._is_boxing or _overlay._is_pencil_painting or _overlay._rmb_hold_active or _overlay._pencil_pending_action == "delete"

func _is_mouse_inside_inspector(global_pos: Vector2) -> bool:
	var pane := get_node_or_null("ContentRow/MainSplit/InspectorPane") as Control
	if pane == null:
		pane = _find_node_any(["ContentRow/MainSplit/InspectorPane", "MainSplit/InspectorPane"]) as Control
	if pane and is_instance_valid(pane):
		if pane.get_global_rect().has_point(global_pos):
			return true
	var scroll := get_node_or_null("ContentRow/MainSplit/InspectorPane/InspectorRoot/InspectorScroll") as Control
	if scroll == null:
		scroll = get_node_or_null("ContentRow/MainSplit/InspectorPane/InspectorScroll") as Control
	if scroll == null:
		scroll = _find_node_any(["ContentRow/MainSplit/InspectorPane/InspectorRoot/InspectorScroll", "ContentRow/MainSplit/InspectorPane/InspectorScroll", "MainSplit/InspectorPane/InspectorRoot/InspectorScroll", "MainSplit/InspectorPane/InspectorScroll"]) as Control
	if scroll and is_instance_valid(scroll) and scroll.get_global_rect().has_point(global_pos):
		return true
	return false

func _input(event: InputEvent) -> void:
	# DIAG: throttled input routing log
	if MIDI_BROWSER_DIAGNOSTICS and event is InputEventMouseButton:
		var _diag_mb := event as InputEventMouseButton
		if _diag_mb.button_index == MOUSE_BUTTON_LEFT:
			var _now_ms2 := Time.get_ticks_msec()
			if _now_ms2 - _diag_last_input_ms > 300 or _diag_mb.pressed != _diag_last_drag_inside:
				_diag_last_input_ms = _now_ms2
				_diag_last_drag_inside = _diag_mb.pressed
				print("[RF_DIAG] SCREEN INPUT event=%s global=%s pattern_drag=%s split_drag=%s inside_playfield=%s is_midi=%s gesture_owner=%s" % [str("press" if _diag_mb.pressed else "release"), str(_diag_mb.global_position), str(_pattern_drag_active), str(_left_split_dragging), str(_is_mouse_inside_playfield(_diag_mb.global_position)), str(_midi_browser_tree != null and _is_mouse_inside_midi_browser(_diag_mb.global_position)), _gesture_owner])
	# Ownership: MIDI drag has priority over normal gesture
	if _gesture_owner == "midi" and _pattern_drag_active:
		if event is InputEventMouseMotion and _midi_drag_preview and is_instance_valid(_midi_drag_preview):
			_midi_drag_preview.global_position = get_global_mouse_position() + Vector2(16, 16)
		# Block pencil/normal gesture while MIDI drag owns the gesture (except release handling below)
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if MIDI_BROWSER_DIAGNOSTICS:
				print("[RF_DIAG] INPUT BLOCKED reason=midi_drag_active blocks pencil global=%s" % str((event as InputEventMouseButton).global_position))
			if _is_mouse_inside_playfield((event as InputEventMouseButton).global_position):
				get_viewport().set_input_as_handled()
				return
	# If resizing left MIDI Browser panel, don't spawn notes on Playfield
	if _left_split_dragging:
		if MIDI_BROWSER_DIAGNOSTICS:
			print("[RF_DIAG] INPUT BLOCKED reason=left_split_dragging")
		return
	# Global mouse tracking for UI->Playfield gesture transfer + wheel outside playfield
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		# Wheel handling outside playfield (inspector + MIDI browser scroll preserved)
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _is_mouse_inside_inspector(mb.position):
				return
			if _is_mouse_inside_midi_browser(mb.position):
				return
			if _is_mouse_inside_playfield(mb.position):
				return
			if state == null or _playfield == null:
				return
			if mb.ctrl_pressed or mb.meta_pressed:
				var delta: float = 20.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -20.0
				var new_val: float = clampf(state.px_per_sec + delta, 180.0, 720.0)
				_on_zoom_changed(new_val)
				get_viewport().set_input_as_handled()
				return
			else:
				var scroll_delta: float = 0.5 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -0.5
				var new_t: float = clampf(state.song_time + scroll_delta, 0.0, state.duration_s)
				_go_to_time(new_t)
				get_viewport().set_input_as_handled()
				return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if _gesture_owner == "midi" and _pattern_drag_active:
					if MIDI_BROWSER_DIAGNOSTICS:
						print("[RF_DIAG] INPUT BLOCKED reason=midi_drag_active owns press, skip arming outside")
				else:
					var inside := _is_mouse_inside_playfield(mb.position)
					_gesture_lmb_armed_outside = not inside
					if MIDI_BROWSER_DIAGNOSTICS and _gesture_owner == "":
						print("[RF_DIAG] GESTURE ARMED outside=%s" % str(_gesture_lmb_armed_outside))
			else:
				# LMB release — global safety: always clear transient state, handle MIDI first
				# FIX: use global_position for is_inside_playfield (was mb.position local — mismatch)
				if MIDI_BROWSER_DIAGNOSTICS:
					print("[RF_DIAG] LMB RELEASE GLOBAL global=%s pattern_drag=%s split_drag=%s inside_playfield=%s gesture_owner=%s" % [str(mb.global_position), str(_pattern_drag_active), str(_left_split_dragging), str(_is_mouse_inside_playfield(mb.global_position)), _gesture_owner])
				if _pattern_drag_active or _gesture_owner == "midi":
					var was_inside := _is_mouse_inside_playfield(mb.global_position)
					if MIDI_BROWSER_DIAGNOSTICS:
						print("[RF_DIAG] MIDI RELEASE %s inside=%s" % ["DROP" if was_inside else "CANCEL", str(was_inside)])
					if was_inside:
						var drop_local := _get_overlay_local_for_global(mb.global_position)
						var drop_t: float = _playfield.world_to_time(drop_local.y, state.song_time) if _playfield and state else _pattern_drag_start_time
						var bar_start := _get_nearest_bar_start(drop_t)
						_pattern_drag_start_time = bar_start
						_update_pattern_ghost(bar_start)
						if _midi_drag_state == "over_playfield" or was_inside:
							_insert_pattern_at(_pattern_drag_pattern.id if _pattern_drag_pattern else _selected_pattern_id, bar_start)
							if MIDI_BROWSER_DIAGNOSTICS:
								print("[RF_DIAG] MIDI RELEASE DROP pattern_id=%s bar_start=%s" % [str(_pattern_drag_pattern.id if _pattern_drag_pattern else _selected_pattern_id), str(bar_start)])
						else:
							if MIDI_BROWSER_DIAGNOSTICS:
								print("[RF_DIAG] MIDI RELEASE CANCEL outside playfield")
					else:
						if MIDI_BROWSER_DIAGNOSTICS:
							print("[RF_DIAG] MIDI RELEASE CANCEL outside playfield")
					_clear_pattern_ghost()
					_clear_midi_drag_preview()
					_pattern_drag_pattern = null
					_pattern_drag_active = false
					_gesture_owner = ""
					_midi_drag_state = ""
					_set_ui_capture_during_gesture(false)
					_gesture_lmb_armed_outside = false
					# Ensure overlay drag is cleared and viewport doesn't think LMB still held
					if _overlay:
						_overlay._is_dragging = false
						_overlay._ghost_visible = false
						_overlay.queue_redraw()
					if _playfield:
						_playfield.queue_redraw()
					get_viewport().set_input_as_handled()
					return
				if _overlay and _is_overlay_gesture_active():
					var synth := InputEventMouseButton.new()
					synth.button_index = MOUSE_BUTTON_LEFT
					synth.pressed = false
					synth.position = _get_overlay_local_for_global(mb.position)
					synth.ctrl_pressed = mb.ctrl_pressed
					synth.shift_pressed = mb.shift_pressed
					synth.alt_pressed = mb.alt_pressed
					synth.meta_pressed = mb.meta_pressed
					_overlay._gui_input(synth)
				_gesture_lmb_armed_outside = false
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				var inside2 := _is_mouse_inside_playfield(mb.position)
				_gesture_rmb_armed_outside = not inside2
			else:
				if _overlay and _overlay._rmb_hold_active:
					var synth2 := InputEventMouseButton.new()
					synth2.button_index = MOUSE_BUTTON_RIGHT
					synth2.pressed = false
					synth2.position = _get_overlay_local_for_global(mb.position)
					_overlay._gui_input(synth2)
				_gesture_rmb_armed_outside = false
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _pattern_drag_active:
			var mp2 := get_global_mouse_position()
			if _is_mouse_inside_playfield(mp2):
				var local2 := _get_overlay_local_for_global(mp2)
				var t_at2: float = _playfield.world_to_time(local2.y, state.song_time) if _playfield and state else 0.0
				var bar_start2 := _get_nearest_bar_start(t_at2)
				if bar_start2 != _pattern_drag_start_time:
					_pattern_drag_start_time = bar_start2
					_update_pattern_ghost(bar_start2)
			get_viewport().set_input_as_handled()
			return
		if _is_overlay_gesture_active():
			# Continue gesture even when cursor leaves Playfield (drag/box/paint must follow)
			var synth_motion := InputEventMouseMotion.new()
			synth_motion.position = _get_overlay_local_for_global(mm.position)
			synth_motion.global_position = mm.global_position
			synth_motion.pressure = mm.pressure
			synth_motion.tilt = mm.tilt
			synth_motion.velocity = mm.velocity
			_overlay._gui_input(synth_motion)
			get_viewport().set_input_as_handled()
			return
		if _gesture_lmb_armed_outside and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _is_mouse_inside_playfield(mm.position):
			if _overlay and not _is_overlay_gesture_active():
				var local := _get_overlay_local_for_global(mm.position)
				var synth_press := InputEventMouseButton.new()
				synth_press.button_index = MOUSE_BUTTON_LEFT
				synth_press.pressed = true
				synth_press.position = local
				synth_press.ctrl_pressed = Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)
				synth_press.shift_pressed = Input.is_key_pressed(KEY_SHIFT)
				synth_press.alt_pressed = Input.is_key_pressed(KEY_ALT)
				synth_press.meta_pressed = Input.is_key_pressed(KEY_META)
				_overlay._gui_input(synth_press)
				_gesture_lmb_armed_outside = false
				get_viewport().set_input_as_handled()
				return
		if _gesture_rmb_armed_outside and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and _is_mouse_inside_playfield(mm.position):
			if _overlay and _overlay.current_tool == "pencil" and not _overlay._rmb_hold_active and not _is_overlay_gesture_active():
				var local2 := _get_overlay_local_for_global(mm.position)
				var synth2 := InputEventMouseButton.new()
				synth2.button_index = MOUSE_BUTTON_RIGHT
				synth2.pressed = true
				synth2.position = local2
				_overlay._gui_input(synth2)
				_gesture_rmb_armed_outside = false
				get_viewport().set_input_as_handled()
				return

func _setup_drum_palette() -> void:
	var _t_drum := PerfTrace.begin("perf.detail.chart_editor.drum_palette")
	_drum_palette_buttons.clear()
	var drums := ["kick", "snare", "hat", "tom", "cymbal", "perc"]
	var cap_map := {"kick":"Kick","snare":"Snare","hat":"Hat","tom":"Tom","cymbal":"Cymbal","perc":"Perc"}
	var tr_map := {"kick": tr("DRUM_KICK"), "snare": tr("DRUM_SNARE"), "hat": tr("DRUM_HAT"), "tom": tr("DRUM_TOM"), "cymbal": tr("DRUM_CYMBAL"), "perc": tr("DRUM_PERC")}
	var hint_map := {"kick": tr("CHART_EDITOR_DRUM_KICK_HINT"), "snare": tr("CHART_EDITOR_DRUM_SNARE_HINT"), "hat": tr("CHART_EDITOR_DRUM_HAT_HINT"), "tom": tr("CHART_EDITOR_DRUM_TOM_HINT"), "cymbal": tr("CHART_EDITOR_DRUM_CYMBAL_HINT"), "perc": tr("CHART_EDITOR_DRUM_PERC_HINT")}
	var icon_map := {"kick":"drum.svg","snare":"drum.svg","hat":"disc-3.svg","tom":"drum.svg","cymbal":"disc-3.svg","perc":"audio-lines.svg"}
	for drum in drums:
		var btn: Button = null
		# Try ContentRow/DrumPaletteVBox path
		btn = get_node_or_null("ContentRow/DrumPalettePane/DrumPaletteVBox/%sButton" % cap_map[drum]) as Button
		if btn == null:
			btn = get_node_or_null("DrumPalettePane/DrumPaletteVBox/%sButton" % cap_map[drum]) as Button
		if btn:
			btn.toggle_mode = true
			# Локализация + иконка вместо эмодзи
			var loc := String(tr_map.get(drum, cap_map[drum]))
			if loc == "" or loc.begins_with("DRUM_"):
				loc = cap_map[drum]
			btn.text = loc
			var hint := String(hint_map.get(drum, ""))
			if hint != "" and not hint.begins_with("CHART_EDITOR"):
				btn.tooltip_text = hint
			# Иконка — tinted по цвету барабана
			var _t_icon := PerfTrace.begin("perf.detail.chart_editor.drum_icon")
			var icon_file := String(icon_map.get(drum, "drum.svg"))
			var col: Color = EditorNoteUtilsClass.color_for_drum(drum)
			UiIconHelper.configure_button_icon(btn, icon_file, col, 16)
			PerfTrace.end("perf.detail.chart_editor.drum_icon", _t_icon)
			_drum_palette_buttons[drum] = btn
			# Connect once — use bind to avoid closure capture issue
			var already := false
			for c in btn.pressed.get_connections():
				if c["callable"].get_method() == "_on_drum_palette_pressed":
					already = true
					break
			if not already:
				btn.pressed.connect(_on_drum_palette_pressed.bind(drum))
	_refresh_drum_palette()
	PerfTrace.end("perf.detail.chart_editor.drum_palette", _t_drum)

func _setup_midi_palette() -> void:
	_notes_mode_button = get_node_or_null("ContentRow/DrumPalettePane/DrumPaletteVBox/PaletteModeRow/NotesModeButton") as Button
	_midi_mode_button = get_node_or_null("ContentRow/DrumPalettePane/DrumPaletteVBox/PaletteModeRow/MidiPatternsModeButton") as Button
	_midi_pattern_container = get_node_or_null("ContentRow/DrumPalettePane/DrumPaletteVBox/MidiPatternContainer") as Control
	# New Tree browser
	_midi_browser_tree = get_node_or_null("ContentRow/DrumPalettePane/DrumPaletteVBox/MidiPatternContainer/MidiBrowserTree") as Tree
	if _midi_browser_tree == null:
		_midi_browser_tree = get_node_or_null("ContentRow/DrumPalettePane/DrumPaletteVBox/MidiPatternContainer/MidiBrowserTreeScroll/MidiBrowserTree") as Tree
	_midi_browser_refresh_button = get_node_or_null("ContentRow/DrumPalettePane/DrumPaletteVBox/MidiPatternContainer/MidiBrowserHeaderRow/MidiBrowserRefreshButton") as Button
	_midi_pattern_info_label = get_node_or_null("ContentRow/DrumPalettePane/DrumPaletteVBox/MidiPatternContainer/MidiPatternInfoLabel") as Label
	# Legacy ItemList kept for compatibility but hidden
	_midi_pattern_list = get_node_or_null("ContentRow/DrumPalettePane/DrumPaletteVBox/MidiPatternContainer/MidiPatternListScroll/MidiPatternList") as ItemList
	_import_midi_button = get_node_or_null("ContentRow/DrumPalettePane/DrumPaletteVBox/MidiPatternContainer/ImportMidiButton") as Button
	if _import_midi_button:
		_import_midi_button.visible = false
	if _notes_mode_button and not _notes_mode_button.pressed.is_connected(_on_notes_mode_pressed):
		_notes_mode_button.pressed.connect(_on_notes_mode_pressed)
	if _midi_mode_button and not _midi_mode_button.pressed.is_connected(_on_midi_mode_pressed):
		_midi_mode_button.pressed.connect(_on_midi_mode_pressed)
	if _midi_browser_refresh_button and not _midi_browser_refresh_button.pressed.is_connected(_on_midi_browser_refresh_pressed):
		_midi_browser_refresh_button.pressed.connect(_on_midi_browser_refresh_pressed)
	if _midi_browser_tree:
		if not _midi_browser_tree.item_selected.is_connected(_on_midi_browser_item_selected):
			_midi_browser_tree.item_selected.connect(_on_midi_browser_item_selected)
		if not _midi_browser_tree.gui_input.is_connected(_on_midi_browser_tree_gui_input):
			_midi_browser_tree.gui_input.connect(_on_midi_browser_tree_gui_input)
		if not _midi_browser_tree.item_activated.is_connected(_on_midi_browser_item_activated):
			_midi_browser_tree.item_activated.connect(_on_midi_browser_item_activated)
		if not _midi_browser_tree.item_collapsed.is_connected(_on_midi_browser_item_collapsed):
			_midi_browser_tree.item_collapsed.connect(_on_midi_browser_item_collapsed)
		# Enable drag forwarding - we handle via gui_input, but also ensure Tree allows select
		_midi_browser_tree.allow_reselect = true
	# FileDialog kept for backend reuse but not shown in browser UI
	if _midi_import_dialog == null:
		_midi_import_dialog = get_node_or_null("MidiImportDialog") as FileDialog
		if _midi_import_dialog == null:
			_midi_import_dialog = FileDialog.new()
			_midi_import_dialog.name = "MidiImportDialog"
			_midi_import_dialog.title = "Импорт MIDI Pattern"
			_midi_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			_midi_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
			_midi_import_dialog.filters = PackedStringArray(["*.mid ; MIDI Files", "*.midi ; MIDI Files"])
			_midi_import_dialog.unresizable = false
			_midi_import_dialog.min_size = Vector2(600, 400)
			add_child(_midi_import_dialog)
			if not _midi_import_dialog.file_selected.is_connected(_on_midi_file_selected):
				_midi_import_dialog.file_selected.connect(_on_midi_file_selected)
	_update_palette_mode()

func _on_notes_mode_pressed() -> void:
	if _palette_mode == "notes":
		return
	_UiModifierSounds.play_select()
	_palette_mode = "notes"
	_update_palette_mode()
	_return_focus_to_editor()

func _on_midi_mode_pressed() -> void:
	if _palette_mode == "midi":
		return
	_UiModifierSounds.play_select()
	_palette_mode = "midi"
	_update_palette_mode()
	_refresh_midi_browser_tree()
	_return_focus_to_editor()

func _update_palette_mode() -> void:
	var is_midi := _palette_mode == "midi"
	if _notes_mode_button:
		_notes_mode_button.button_pressed = not is_midi
	if _midi_mode_button:
		_midi_mode_button.button_pressed = is_midi
	# Drum tools visible only in notes mode
	for drum in _drum_palette_buttons.keys():
		var btn: Button = _drum_palette_buttons[drum] as Button
		if btn:
			btn.visible = not is_midi
	if _select_button:
		_select_button.visible = not is_midi
	if _pencil_button:
		_pencil_button.visible = not is_midi
	var tools_sep2 := get_node_or_null("ContentRow/DrumPalettePane/DrumPaletteVBox/ToolsSep2") as Control
	if tools_sep2:
		tools_sep2.visible = not is_midi
	if _midi_pattern_container:
		_midi_pattern_container.visible = is_midi

# === New MIDI Browser (Tree) ===

func _get_midi_samples_root() -> String:
	var p := "E:/samples/midi"
	if SettingsManager and SettingsManager.has_method("get_midi_samples_path"):
		p = String(SettingsManager.get_midi_samples_path())
	elif SettingsManager:
		p = String(SettingsManager.get_setting("midi_samples_path", "E:/samples/midi"))
	p = p.strip_edges().replace("\\", "/")
	if p == "":
		p = "E:/samples/midi"
	return p

func _on_midi_browser_refresh_pressed() -> void:
	_UiModifierSounds.play_select()
	_midi_scan_cache.clear()
	_midi_scan_cache_root = ""
	_refresh_midi_browser_tree()
	_return_focus_to_editor()

func _refresh_midi_browser_tree() -> void:
	var _t_midi := PerfTrace.begin("perf.load.chart_editor.midi")
	var _t_midi_tree := PerfTrace.begin("perf.detail.chart_editor.midi_tree")
	if _midi_browser_tree == null:
		PerfTrace.end("perf.detail.chart_editor.midi_tree", _t_midi_tree)
		PerfTrace.end("perf.load.chart_editor.midi", _t_midi)
		return
	_midi_browser_tree.clear()
	_selected_pattern_id = ""
	var root_path := _get_midi_samples_root().rstrip("/")
	# Invalidate scan cache if root path changed (SettingsManager.midi_samples_path) — normalized
	if _midi_scan_cache_root.rstrip("/") != root_path:
		_midi_scan_cache.clear()
		_midi_scan_cache_root = root_path
	_midi_browser_root_path = root_path
	var abs_root := DirectoryUtils.to_absolute(root_path).rstrip("/")
	# Root item hidden, but create a visible root for the midi folder
	var root_item := _midi_browser_tree.create_item()
	root_item.set_text(0, "MIDI Samples")
	root_item.set_metadata(0, root_path)
	# Use folder icon for root
	var folder_icon := _get_folder_icon(false)
	if folder_icon:
		root_item.set_icon(0, folder_icon)
	root_item.set_collapsed(false)
	if abs_root == "" or not DirAccess.dir_exists_absolute(abs_root):
		if _midi_pattern_info_label:
			_midi_pattern_info_label.text = "Папка не найдена"
		PerfTrace.end("perf.detail.chart_editor.midi_tree", _t_midi_tree)
		PerfTrace.end("perf.load.chart_editor.midi", _t_midi)
		return
	var _t_scan := PerfTrace.begin("perf.detail.chart_editor.midi_scan")
	var count := _build_midi_tree_recursive(root_item, abs_root, root_path)
	PerfTrace.end("perf.detail.chart_editor.midi_scan", _t_scan)
	if _midi_pattern_info_label:
		_midi_pattern_info_label.text = "%d файлов" % count
	PerfTrace.end("perf.detail.chart_editor.midi_tree", _t_midi_tree)
	PerfTrace.end("perf.load.chart_editor.midi", _t_midi)
	# Expand root by default
	root_item.set_collapsed(false)

func _get_folder_icon(expanded: bool) -> Texture2D:
	if expanded:
		if _midi_folder_open_icon_cache != null:
			return _midi_folder_open_icon_cache
		var tex := UiIconHelper.load_tinted_icon("folder-open.svg", Color(0.55, 0.78, 0.98, 1.0), 32) if UiIconHelper else null
		if tex != null:
			_midi_folder_open_icon_cache = tex
		return tex
	if _midi_folder_icon_cache != null:
		return _midi_folder_icon_cache
	var tex2 := UiIconHelper.load_tinted_icon("folder.svg", Color(0.55, 0.78, 0.98, 1.0), 32) if UiIconHelper else null
	if tex2 != null:
		_midi_folder_icon_cache = tex2
	return tex2

func _get_midi_file_icon() -> Texture2D:
	if _midi_file_icon_cache != null:
		return _midi_file_icon_cache
	var tex := UiIconHelper.load_tinted_icon("audio-lines.svg", Color(0.62, 0.86, 0.72, 1.0), 32) if UiIconHelper else null
	if tex != null:
		_midi_file_icon_cache = tex
	return tex

func _build_midi_tree_recursive(parent_item: TreeItem, abs_dir: String, rel_dir: String) -> int:
	var count := 0
	var folders: Array = []
	var files: Array = []
	var cached: Variant = _midi_scan_cache.get(abs_dir, null)
	if cached is Dictionary and cached.has("folders") and cached.has("files"):
		folders = (cached.get("folders", []) as Array).duplicate()
		files = (cached.get("files", []) as Array).duplicate()
	else:
		var da := DirAccess.open(abs_dir)
		if da == null:
			return 0
		da.list_dir_begin()
		var entries: Array = []
		var fname := da.get_next()
		while fname != "":
			if fname != "." and fname != "..":
				entries.append(fname)
			fname = da.get_next()
		da.list_dir_end()
		entries.sort_custom(func(a, b): return String(a).to_lower() < String(b).to_lower())
		# First add folders, then files for stable grouping (folders first)
		for e in entries:
			var full_abs := abs_dir.rstrip("/") + "/" + String(e)
			if DirAccess.dir_exists_absolute(full_abs):
				folders.append(String(e))
			else:
				var lower := String(e).to_lower()
				if lower.ends_with(".mid") or lower.ends_with(".midi"):
					files.append(String(e))
		_midi_scan_cache[abs_dir] = {"folders": folders.duplicate(), "files": files.duplicate()}
	for folder_name in folders:
		var child_abs: String = abs_dir.rstrip("/") + "/" + String(folder_name)
		var child_rel: String = rel_dir.rstrip("/") + "/" + String(folder_name)
		var item := _midi_browser_tree.create_item(parent_item)
		item.set_text(0, String(folder_name))
		item.set_metadata(0, child_rel)
		var _t_icon1 := PerfTrace.begin("perf.detail.chart_editor.midi_icons")
		var icon := _get_folder_icon(false)
		PerfTrace.end("perf.detail.chart_editor.midi_icons", _t_icon1)
		if icon:
			item.set_icon(0, icon)
		item.set_collapsed(true)
		# Recurse
		var sub_count := _build_midi_tree_recursive(item, child_abs, child_rel)
		count += sub_count
		# Keep folders visible even if empty (so user sees structure)
	for file_name in files:
		var file_rel: String = rel_dir.rstrip("/") + "/" + String(file_name)
		var item2 := _midi_browser_tree.create_item(parent_item)
		item2.set_text(0, file_name)
		item2.set_metadata(0, file_rel)
		var _t_icon2 := PerfTrace.begin("perf.detail.chart_editor.midi_icons")
		var ficon := _get_midi_file_icon()
		PerfTrace.end("perf.detail.chart_editor.midi_icons", _t_icon2)
		if ficon:
			item2.set_icon(0, ficon)
		item2.set_selectable(0, true)
		count += 1
	return count

func _on_midi_browser_item_selected() -> void:
	var item := _midi_browser_tree.get_selected() if _midi_browser_tree else null
	if item == null:
		_selected_pattern_id = ""
		return
	var meta := String(item.get_metadata(0))
	# Only files have .mid, folders have no pattern
	if meta.to_lower().ends_with(".mid") or meta.to_lower().ends_with(".midi"):
		var file_name := meta.get_file().get_basename()
		_selected_pattern_id = file_name.to_lower().replace(" ", "_")
	else:
		_selected_pattern_id = ""
	_return_focus_to_editor()

func _on_midi_browser_item_activated() -> void:
	var item := _midi_browser_tree.get_selected() if _midi_browser_tree else null
	if item == null:
		return
	var meta := String(item.get_metadata(0))
	if meta.to_lower().ends_with(".mid") or meta.to_lower().ends_with(".midi"):
		return
	# Folder double-click -> toggle expand/collapse (use new state after toggle)
	var was_collapsed := item.is_collapsed()
	item.set_collapsed(not was_collapsed)
	var now_expanded := not item.is_collapsed()
	var icon := _get_folder_icon(now_expanded)
	if icon:
		item.set_icon(0, icon)
	if MIDI_BROWSER_DIAGNOSTICS:
		var p2 := String(item.get_metadata(0))
		print("[RF_DIAG] FOLDER STATE path=%s collapsed=%s icon=%s" % [p2, str(item.is_collapsed()), "folder-open.svg" if now_expanded else "folder.svg"])

func _on_midi_browser_item_collapsed(item: TreeItem) -> void:
	if item == null or _midi_browser_tree == null:
		return
	# Tree already toggled collapsed via arrow; icon should reflect new expanded state
	var now_expanded := not item.is_collapsed()
	var icon := _get_folder_icon(now_expanded)
	if icon:
		item.set_icon(0, icon)
	if MIDI_BROWSER_DIAGNOSTICS:
		var p := String(item.get_metadata(0))
		print("[RF_DIAG] FOLDER STATE path=%s collapsed=%s icon=%s" % [p, str(item.is_collapsed()), "folder-open.svg" if now_expanded else "folder.svg"])

func _is_mouse_inside_midi_browser(global_pos: Vector2) -> bool:
	if _midi_browser_tree == null or not is_instance_valid(_midi_browser_tree):
		return false
	var scroll := get_node_or_null("ContentRow/DrumPalettePane/DrumPaletteVBox/MidiPatternContainer/MidiBrowserTreeScroll") as Control
	if scroll and is_instance_valid(scroll) and scroll.get_global_rect().has_point(global_pos):
		return true
	var tree_ctrl := _midi_browser_tree as Control
	if tree_ctrl and tree_ctrl.get_global_rect().has_point(global_pos):
		return true
	var pane := get_node_or_null("ContentRow/DrumPalettePane") as Control
	if pane and pane.get_global_rect().has_point(global_pos):
		# If inside left pane but not exactly tree, still consider as browser area for wheel
		return true
	return false

func _ensure_pattern_for_mid(mid_path: String) -> MidiPattern:
	if MIDI_BROWSER_DIAGNOSTICS:
		print("[RF_DIAG] PATTERN PREP START path=%s" % mid_path)
		print("[RF_DIAG] MIDI DEBUG filename=%s" % mid_path.get_file())
	var abs_path := DirectoryUtils.to_absolute(mid_path)
	if MIDI_BROWSER_DIAGNOSTICS:
		print("[RF_DIAG] PATTERN PREP abs=%s exists=%s" % [abs_path, str(abs_path != "" and FileAccess.file_exists(abs_path))])
	if abs_path == "" or not FileAccess.file_exists(abs_path):
		if MIDI_BROWSER_DIAGNOSTICS:
			print("[RF_DIAG] PATTERN PREP FAILED stage=abs_path reason=file_not_found abs=%s" % abs_path)
		return null
	# Check cache by file hash or name
	var file_hash := MidiPattern.file_hash_for_path(mid_path)
	if MIDI_BROWSER_DIAGNOSTICS:
		print("[RF_DIAG] PATTERN PREP file_hash=%s" % file_hash)
	var existing_id := mid_path.get_file().get_basename().to_lower().replace(" ", "_")
	var existing := MidiPatternStore.load_pattern(existing_id)
	if MIDI_BROWSER_DIAGNOSTICS:
		print("[RF_DIAG] CACHE CHECK id=%s exists=%s hash_match=%s" % [existing_id, str(existing != null), str(existing != null and String(existing.source_hash) == file_hash)])
	if existing != null and String(existing.source_hash) == file_hash and file_hash != "":
		if MIDI_BROWSER_DIAGNOSTICS:
			print("[RF_DIAG] CACHE HIT id=%s" % existing_id)
		return existing
	# Also try with hash suffix if previous import created unique id
	if file_hash != "":
		var alt_id := "%s_%s" % [existing_id, file_hash.substr(0, 6)]
		var alt := MidiPatternStore.load_pattern(alt_id)
		if MIDI_BROWSER_DIAGNOSTICS:
			print("[RF_DIAG] CACHE CHECK alt_id=%s exists=%s" % [alt_id, str(alt != null)])
		if alt != null and String(alt.source_hash) == file_hash:
			if MIDI_BROWSER_DIAGNOSTICS:
				print("[RF_DIAG] CACHE HIT alt_id=%s" % alt_id)
			return alt
	if MIDI_BROWSER_DIAGNOSTICS:
		print("[RF_DIAG] CACHE MISS — calling import_mid for %s" % mid_path)
	# Not found or hash mismatch — import automatically
	var res := MidiPatternStore.import_mid(mid_path)
	var err := String(res.get("error", ""))
	var warn := String(res.get("warning", ""))
	var pat_dbg: Variant = res.get("pattern")
	var dbg_note_count := 0
	var dbg_pitch_list := []
	var dbg_mapped_list := []
	var dbg_track_count := 0
	var dbg_leading := 0.0
	var dbg_dur := 0.0
	if pat_dbg is MidiPattern:
		var mp_dbg := pat_dbg as MidiPattern
		dbg_note_count = mp_dbg.note_count()
		dbg_pitch_list = MidiGmMapper.pitches_in_notes(mp_dbg.notes_rel)
		dbg_mapped_list = MidiGmMapper.default_map_for_pitches(dbg_pitch_list).keys()
		dbg_leading = mp_dbg.leading_offset
		dbg_dur = mp_dbg.duration_sec
		var _parsed_dbg := MidiParser.parse_file(mid_path)
		dbg_track_count = int(_parsed_dbg.get("nTracks", 0))
	if MIDI_BROWSER_DIAGNOSTICS:
		print("[RF_DIAG] IMPORT_MID RESULT error='%s' warning='%s' has_pattern=%s" % [err, warn, str(pat_dbg != null)])
		print("[RF_DIAG] MIDI DEBUG filename=%s parse_success=%s track_count=%d note_count=%d detected_pitches=%s mapped_drums=%s pattern_notes=%d leading_offset=%s duration=%s" % [mid_path.get_file(), str(err == ""), dbg_track_count, (res.get("pattern") as MidiPattern).note_count() if res.get("pattern") is MidiPattern else 0, str(dbg_pitch_list), str(dbg_mapped_list), dbg_note_count, str(dbg_leading), str(dbg_dur)])
	if err != "" or warn != "":
		if MIDI_BROWSER_DIAGNOSTICS:
			print("[RF_DIAG] PATTERN PREP FAILED stage=import_mid error='%s' warning='%s'" % [err, warn])
		var msg := err if err != "" else warn
		_set_status(msg, true)
		if _notice_overlay and _notice_overlay.has_method("show_notice"):
			_notice_overlay.show_notice("MIDI", msg, "warning")
		return null
	var pat: Variant = res.get("pattern")
	if pat is MidiPattern:
		return pat as MidiPattern
	return null

func _on_midi_browser_tree_gui_input(event: InputEvent) -> void:
	if _midi_browser_tree == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if MIDI_BROWSER_DIAGNOSTICS:
				var _diag_item := _midi_browser_tree.get_item_at_position(mb.position) if _midi_browser_tree else null
				var _diag_meta := String(_diag_item.get_metadata(0)) if _diag_item else "null"
				var _diag_id := str(_diag_item.get_text(0)) if _diag_item else "null"
				print("[RF_DIAG] TREE LEFT PRESS pressed=%s pos=%s global=%s item=%s item_id=%s meta=%s pattern_drag_active_before=%s" % [str(mb.pressed), str(mb.position), str(mb.global_position), str(_diag_item != null), _diag_id, _diag_meta, str(_pattern_drag_active)])
				if _diag_item == null:
					print("[RF_DIAG] TREE ITEM NULL — no drag")
				elif not (_diag_meta.to_lower().ends_with(".mid") or _diag_meta.to_lower().ends_with(".midi")):
					print("[RF_DIAG] TREE NOT MIDI — folder, no drag")
			if mb.pressed:
				# Ownership check: one gesture = one owner
				if _gesture_owner != "":
					if MIDI_BROWSER_DIAGNOSTICS:
						print("[RF_DIAG] TREE PRESS IGNORED owner=%s busy" % _gesture_owner)
					return
				var item2 := _midi_browser_tree.get_item_at_position(mb.position)
				if item2 == null:
					if MIDI_BROWSER_DIAGNOSTICS:
						print("[RF_DIAG] TREE ITEM NULL at pos %s — no drag start" % str(mb.position))
					return
				var meta2 := String(item2.get_metadata(0))
				if not (meta2.to_lower().ends_with(".mid") or meta2.to_lower().ends_with(".midi")):
					if MIDI_BROWSER_DIAGNOSTICS:
						print("[RF_DIAG] TREE NOT MIDI FILE meta=%s — no drag" % meta2)
					return
				if MIDI_BROWSER_DIAGNOSTICS:
					print("[RF_DIAG] TREE MIDI FOUND path=%s item=%s pattern_id_before=%s" % [meta2, str(item2.get_text(0)), _selected_pattern_id])
				# Left click on file -> select and start drag — claim ownership
				_gesture_owner = "midi"
				_midi_drag_state = "outside"
				if MIDI_BROWSER_DIAGNOSTICS:
					print("[RF_DIAG] MIDI START owner=midi state=outside")
				_midi_browser_tree.set_selected(item2, 0)
				_selected_pattern_id = meta2.get_file().get_basename().to_lower().replace(" ", "_")
				# Ensure pattern exists (auto import)
				var pat2 := _ensure_pattern_for_mid(meta2)
				if MIDI_BROWSER_DIAGNOSTICS:
					if pat2 == null:
						print("[RF_DIAG] TREE PATTERN FAILED for %s" % meta2)
					else:
						print("[RF_DIAG] TREE PATTERN READY pattern_id=%s note_count=%d" % [pat2.id, pat2.note_count()])
				if pat2 == null:
					_gesture_owner = ""
					_midi_drag_state = ""
					return
				_selected_pattern_id = pat2.id
				_pattern_drag_active = true
				_pattern_drag_pattern = pat2
				var init_t2 := state.song_time if state else 0.0
				_pattern_drag_start_time = _get_nearest_bar_start(init_t2)
				if MIDI_BROWSER_DIAGNOSTICS:
					print("[RF_DIAG] PATTERN DRAG START active=%s pattern_id=%s song_time=%s bar_start=%s" % [str(_pattern_drag_active), pat2.id, str(init_t2), str(_pattern_drag_start_time)])
				# Drag preview outside Playfield
				_create_midi_drag_preview(pat2.name if pat2 else meta2.get_file())
				_update_pattern_ghost(_pattern_drag_start_time)
				_set_ui_capture_during_gesture(true)
				# Also update global selected for consistency
				_midi_browser_tree.set_selected(item2, 0)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _gesture_owner == "midi" and _pattern_drag_active:
		var now_ms := Time.get_ticks_msec()
		var gpos := get_global_mouse_position()
		var is_inside := _is_mouse_inside_playfield(gpos)
		# Update drag preview position (follows cursor outside Playfield)
		if _midi_drag_preview and is_instance_valid(_midi_drag_preview):
			_midi_drag_preview.global_position = gpos + Vector2(16, 16)
		# Handle ghost visibility based on inside state (state machine)
		if is_inside and _midi_drag_state != "over_playfield":
			_midi_drag_state = "over_playfield"
			if MIDI_BROWSER_DIAGNOSTICS:
				print("[RF_DIAG] MIDI ENTER PLAYFIELD state=%s" % _midi_drag_state)
		elif not is_inside and _midi_drag_state != "outside":
			_midi_drag_state = "outside"
			if MIDI_BROWSER_DIAGNOSTICS:
				print("[RF_DIAG] MIDI LEAVE PLAYFIELD state=%s" % _midi_drag_state)
			# Hide ghost when outside
			if _pattern_drag_ghost_notes.size() > 0:
				_clear_pattern_ghost()
				# Recreate ghost notes for next enter (keep pattern)
				_pattern_drag_ghost_notes = _build_pattern_ghost_notes(_pattern_drag_pattern, _pattern_drag_start_time)
		# Throttled drag motion log
		if MIDI_BROWSER_DIAGNOSTICS and now_ms - _diag_last_motion_ms > 250:
			_diag_last_motion_ms = now_ms
			var ghost_vis := _midi_drag_state == "over_playfield" and _pattern_drag_ghost_notes.size() > 0
			print("[RF_DIAG] PATTERN DRAG MOTION global=%s inside_playfield=%s state=%s bar_start=%s ghost_visible=%s" % [str(gpos), str(is_inside), _midi_drag_state, str(_pattern_drag_start_time), str(ghost_vis)])
			if is_inside and not _diag_was_inside_playfield:
				print("[RF_DIAG] DRAG ENTER PLAYFIELD")
			elif not is_inside and _diag_was_inside_playfield:
				print("[RF_DIAG] DRAG LEAVE PLAYFIELD")
			_diag_was_inside_playfield = is_inside
		if is_inside:
			var local := _get_overlay_local_for_global(gpos)
			var t_at: float = _playfield.world_to_time(local.y, state.song_time) if _playfield and state else 0.0
			var bar_start := _get_nearest_bar_start(t_at)
			if bar_start != _pattern_drag_start_time or _midi_drag_state == "over_playfield" and _pattern_drag_ghost_notes.is_empty():
				_pattern_drag_start_time = bar_start
				_update_pattern_ghost(bar_start)

func _create_midi_drag_preview(file_name: String) -> void:
	if _midi_drag_preview and is_instance_valid(_midi_drag_preview):
		_midi_drag_preview.queue_free()
	var panel := PanelContainer.new()
	panel.name = "MidiDragPreview"
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(8)
	box.bg_color = Color(0.12, 0.13, 0.17, 0.95)
	box.border_color = Color(0.62, 0.86, 0.72, 0.9)
	box.set_border_width_all(1)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", box)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	panel.add_child(hbox)
	var icon := TextureRect.new()
	icon.texture = UiIconHelper.load_tinted_icon("audio-lines.svg", Color(0.62, 0.86, 0.72, 1.0), 24) if UiIconHelper else null
	icon.custom_minimum_size = Vector2(20, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(icon)
	var label := Label.new()
	label.text = file_name
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.88, 0.91, 0.96, 1.0))
	hbox.add_child(label)
	add_child(panel)
	panel.global_position = get_global_mouse_position() + Vector2(16, 16)
	panel.z_index = 100
	_midi_drag_preview = panel
	if MIDI_BROWSER_DIAGNOSTICS:
		print("[RF_DIAG] CREATE DRAG PREVIEW file=%s" % file_name)

func _update_midi_drag_preview_position() -> void:
	if _midi_drag_preview and is_instance_valid(_midi_drag_preview):
		_midi_drag_preview.global_position = get_global_mouse_position() + Vector2(16, 16)

func _clear_midi_drag_preview() -> void:
	if _midi_drag_preview and is_instance_valid(_midi_drag_preview):
		_midi_drag_preview.queue_free()
	_midi_drag_preview = null
	if MIDI_BROWSER_DIAGNOSTICS:
		print("[RF_DIAG] CLEAR DRAG PREVIEW")

# Legacy ItemList handlers kept for compatibility (no longer used in browser UI)
func _refresh_midi_pattern_list() -> void:
	# Redirect to new browser for any legacy calls
	_refresh_midi_browser_tree()

func _on_midi_pattern_selected(index: int) -> void:
	if _midi_pattern_list == null or index < 0 or index >= _midi_pattern_list.get_item_count():
		_selected_pattern_id = ""
		return
	_selected_pattern_id = String(_midi_pattern_list.get_item_metadata(index))
	_return_focus_to_editor()

func _on_import_midi_pressed() -> void:
	# Legacy import button hidden — keep for backend reuse but not part of main browser UX
	if _midi_import_dialog == null:
		_setup_midi_palette()
	if _midi_import_dialog:
		var midi_dir := _get_midi_samples_root()
		if midi_dir.begins_with("user://") or midi_dir.begins_with("res://"):
			midi_dir = ProjectSettings.globalize_path(midi_dir)
		if midi_dir != "":
			_midi_import_dialog.current_dir = midi_dir
		_midi_import_dialog.popup_centered()
	_return_focus_to_editor()

func _on_midi_file_selected(path: String) -> void:
	var res := MidiPatternStore.import_mid(path)
	var err: String = String(res.get("error", ""))
	var warn: String = String(res.get("warning", ""))
	if err != "" or warn != "":
		var msg := err if err != "" else warn
		_set_status(msg, true)
		if _notice_overlay and _notice_overlay.has_method("show_notice"):
			_notice_overlay.show_notice("MIDI Import", msg, "warning")
		else:
			print("[MidiImport] warning: %s" % msg)
		return
	var pat: Variant = res.get("pattern")
	if pat is MidiPattern:
		var mp: MidiPattern = pat as MidiPattern
		_set_status("Импортирован: %s (%d нот)" % [mp.name, mp.note_count()], false)
		_refresh_midi_browser_tree()
		_selected_pattern_id = mp.id
	_return_focus_to_editor()

func _on_midi_pattern_list_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and _selected_pattern_id != "":
			var pat := MidiPatternStore.load_pattern(_selected_pattern_id)
			if pat != null:
				_pattern_drag_active = true
				_pattern_drag_pattern = pat
				var init_t := state.song_time if state else 0.0
				_pattern_drag_start_time = _get_nearest_bar_start(init_t)
				_update_pattern_ghost(_pattern_drag_start_time)
				_set_ui_capture_during_gesture(true)
	elif event is InputEventMouseMotion and _pattern_drag_active:
		var mp := get_global_mouse_position()
		if _is_mouse_inside_playfield(mp):
			var local := _get_overlay_local_for_global(mp)
			var t_at: float = _playfield.world_to_time(local.y, state.song_time) if _playfield and state else 0.0
			var bar_start := _get_nearest_bar_start(t_at)
			if bar_start != _pattern_drag_start_time:
				_pattern_drag_start_time = bar_start
				_update_pattern_ghost(bar_start)

func _get_nearest_bar_start(t: float) -> float:
	if state == null or state.grid == null:
		return maxf(0.0, t)
	var grid: ChartGrid = state.grid as ChartGrid
	var idx := grid.measure_index(t)
	var s0 := grid.measure_start_time(idx)
	var s1 := grid.measure_start_time(idx + 1)
	# Also check previous bar for nearest
	var s_prev := grid.measure_start_time(idx - 1) if idx > 0 else s0
	var best := s0
	var best_dist := absf(t - s0)
	for s in [s1, s_prev]:
		var d := absf(t - s)
		if d < best_dist:
			best = s
			best_dist = d
	return clampf(best, 0.0, state.duration_s if state and state.duration_s > 0 else 9999.0)

func _build_pattern_ghost_notes(pattern: MidiPattern, start_time: float) -> Array:
	var out: Array = []
	if pattern == null:
		if MIDI_BROWSER_DIAGNOSTICS:
			print("[RF_DIAG] GHOST BUILD pattern null")
		return out
	var src_count := pattern.notes_rel.size()
	if src_count == 0:
		if MIDI_BROWSER_DIAGNOSTICS:
			print("[RF_DIAG] GHOST BUILD pattern_id=%s src 0 -> 0" % pattern.id)
		return out
	var mapping := MidiGmMapper.build_mapping_for_notes(pattern.notes_rel)
	var filtered_skipped := 0
	var drum_counts := {}
	for n in pattern.notes_rel:
		if not n is Dictionary:
			filtered_skipped += 1
			continue
		var pitch := int(n.get("pitch", -1))
		var drum := MidiGmMapper.drum_for_pitch(pitch, mapping)
		if drum == "":
			# MVP fallback: any pitch → kick (explicit, not global mapper change)
			drum = "kick"
			if MIDI_BROWSER_DIAGNOSTICS and filtered_skipped == 0:
				# Count as fallback, not skip
				pass
		if drum == "":
			filtered_skipped += 1
			continue
		drum_counts[drum] = int(drum_counts.get(drum, 0)) + 1
		var lane := MidiGmMapper.lane_for_drum(drum, state.lanes if state else 5)
		var rel: float = float(n.get("relTime", n.get("start_sec", 0.0)))
		var abs_t: float = start_time + rel
		out.append({"time": abs_t, "lane": lane, "drum": drum, "type": "DrumNote", "pitch": pitch, "relTime": rel})
	if MIDI_BROWSER_DIAGNOSTICS:
		var first_entries := []
		for i in range(mini(3, out.size())):
			var e: Dictionary = out[i] as Dictionary
			first_entries.append("time=%s drum=%s lane=%s pitch=%s rel=%s" % [str(e.get("time", "")), str(e.get("drum", "")), str(e.get("lane", "")), str(e.get("pitch", "")), str(e.get("relTime", ""))])
		print("[RF_DIAG] GHOST BUILD pattern_id=%s src=%d after_filter=%d skipped=%d drum_counts=%s first=%s" % [pattern.id, src_count, out.size(), filtered_skipped, str(drum_counts), str(first_entries)])
		print("[RF_DIAG] GHOST BUILD ghost_notes=%d bar_start=%s" % [out.size(), str(start_time)])
	return out

func _update_pattern_ghost(start_time: float) -> void:
	if _pattern_drag_pattern == null or not _pattern_drag_active:
		if MIDI_BROWSER_DIAGNOSTICS and _pattern_drag_active:
			print("[RF_DIAG] UPDATE GHOST SKIPPED pattern null or not active")
		return
	_pattern_drag_ghost_notes = _build_pattern_ghost_notes(_pattern_drag_pattern, start_time)
	if MIDI_BROWSER_DIAGNOSTICS and absf(start_time - _diag_last_ghost_bar) > 0.001:
		print("[RF_DIAG] UPDATE GHOST bar_start=%s note_count=%d" % [str(start_time), _pattern_drag_ghost_notes.size()])
		_diag_last_ghost_bar = start_time
	if _overlay and _overlay.has_method("set_pattern_ghost"):
		if MIDI_BROWSER_DIAGNOSTICS:
			print("[RF_DIAG] SET PATTERN GHOST visible=true note_count=%d bar_start=%s overlay=%s" % [_pattern_drag_ghost_notes.size(), str(start_time), str(_overlay != null)])
		_overlay.set_pattern_ghost(true, _pattern_drag_ghost_notes, start_time)
	elif _playfield:
		_playfield.queue_redraw()

func _clear_pattern_ghost() -> void:
	if MIDI_BROWSER_DIAGNOSTICS and _pattern_drag_active:
		print("[RF_DIAG] CLEAR PATTERN GHOST was_active=%s" % str(_pattern_drag_active))
	_pattern_drag_active = false
	_pattern_drag_ghost_notes.clear()
	_diag_last_ghost_bar = -1.0
	_diag_was_inside_playfield = false
	if _overlay and _overlay.has_method("clear_pattern_ghost"):
		if MIDI_BROWSER_DIAGNOSTICS:
			print("[RF_DIAG] CLEAR PATTERN GHOST via clear_pattern_ghost overlay=%s" % str(_overlay != null))
		_overlay.clear_pattern_ghost()
	elif _overlay and _overlay.has_method("set_pattern_ghost"):
		if MIDI_BROWSER_DIAGNOSTICS:
			print("[RF_DIAG] CLEAR PATTERN GHOST via set_pattern_ghost false")
		_overlay.set_pattern_ghost(false, [], 0.0)
	_set_ui_capture_during_gesture(false)

func _try_drop_pattern_at(time: float) -> void:
	if _pattern_drag_pattern == null:
		return
	var bar_start := _get_nearest_bar_start(time)
	# For Phase5 ghost only, insertion is Phase6; keep ghost update
	_pattern_drag_start_time = bar_start
	_update_pattern_ghost(bar_start)

func _insert_pattern_at(pattern_id: String, start_time: float) -> void:
	if pattern_id == "" or state == null:
		if MIDI_BROWSER_DIAGNOSTICS:
			print("[RF_DIAG] MATERIALIZE FAILED stage=empty_id_or_state pattern_id='%s' has_state=%s" % [pattern_id, str(state != null)])
		return
	var pattern := MidiPatternStore.load_pattern(pattern_id)
	if pattern == null:
		if MIDI_BROWSER_DIAGNOSTICS:
			print("[RF_DIAG] MATERIALIZE FAILED stage=load_pattern pattern_id=%s" % pattern_id)
		_set_status("Pattern not found: %s" % pattern_id, true)
		return
	var src_count := pattern.notes_rel.size()
	if src_count == 0:
		if MIDI_BROWSER_DIAGNOSTICS:
			print("[RF_DIAG] MATERIALIZE FAILED stage=empty_notes pattern_id=%s" % pattern.name)
		_set_status("Pattern empty: %s" % pattern.name, true)
		return
	var mapping := MidiGmMapper.build_mapping_for_notes(pattern.notes_rel)
	var mapped_count := mapping.size()
	if MIDI_BROWSER_DIAGNOSTICS:
		print("[RF_DIAG] MATERIALIZE mapping pattern_id=%s pitches=%s mapping_size=%d" % [pattern.id, str(MidiGmMapper.pitches_in_notes(pattern.notes_rel)), mapped_count])
	if mapping.is_empty():
		# MVP fallback: any pitch → kick (same as ghost) — do not block KICK MIDI with 60/112
		if MIDI_BROWSER_DIAGNOSTICS:
			print("[RF_DIAG] MATERIALIZE MAP EMPTY — MVP fallback any pitch → kick for pitches=%s" % str(MidiGmMapper.pitches_in_notes(pattern.notes_rel)))
		mapping.clear()
		for p in MidiGmMapper.pitches_in_notes(pattern.notes_rel):
			mapping[int(p)] = "kick"
		if MIDI_BROWSER_DIAGNOSTICS:
			print("[RF_DIAG] MATERIALIZE MAP FALLBACK mapping_size=%d" % mapping.size())
		if mapping.is_empty():
			_set_status("No mappable drums in pattern: %s" % pattern.name, true)
			return
	var notes_to_add: Array = []
	var skipped_no_dict := 0
	var skipped_no_drum := 0
	var drum_counts := {}
	for n in pattern.notes_rel:
		if not n is Dictionary:
			skipped_no_dict += 1
			continue
		var pitch := int(n.get("pitch", -1))
		var drum := MidiGmMapper.drum_for_pitch(pitch, mapping)
		if drum == "":
			# MVP fallback (should not happen after mapping fallback, but keep)
			drum = "kick"
		if drum == "":
			skipped_no_drum += 1
			continue
		drum_counts[drum] = int(drum_counts.get(drum, 0)) + 1
		var lane := MidiGmMapper.lane_for_drum(drum, state.lanes)
		var rel: float = float(n.get("relTime", 0.0))
		var abs_t: float = start_time + rel
		var note := EditorNoteUtils.make_note(abs_t, lane, drum, state.lanes)
		# Preserve provenance and MIDI vel/dur only if present (no artificial)
		note["pattern_id"] = pattern.id
		note["pattern_pitch"] = pitch
		if n.has("vel"):
			note["vel"] = int(n.get("vel"))
		if n.has("duration"):
			var dur: float = float(n.get("duration", 0.0))
			if dur > 0.0:
				note["duration"] = dur
		elif n.has("dur"):
			var dur2: float = float(n.get("dur", 0.0))
			if dur2 > 0.0:
				note["duration"] = dur2
		notes_to_add.append(note)
	if MIDI_BROWSER_DIAGNOSTICS:
		# Detailed materialization stats
		var first_mats := []
		for i in range(mini(3, notes_to_add.size())):
			var mn: Dictionary = notes_to_add[i] as Dictionary
			first_mats.append("time=%s drum=%s lane=%s pitch=%s rel=%s" % [str(mn.get("time", "")), str(mn.get("drum", "")), str(mn.get("lane", "")), str(mn.get("pattern_pitch", "")), str(mn.get("time", 0.0) - start_time)])
		print("[RF_DIAG] MATERIALIZE STATS pattern_id=%s src=%d after_drum=%d after_lane=%d before_create=%d really_added=%d skipped_no_dict=%d skipped_no_drum=%d drum_counts=%s first3=%s" % [pattern.id, src_count, notes_to_add.size() + skipped_no_drum + skipped_no_dict - 0, notes_to_add.size() + skipped_no_drum, notes_to_add.size(), notes_to_add.size(), skipped_no_dict, skipped_no_drum, str(drum_counts), str(first_mats)])
		# Specific notes for myown808 and Bass
		for n in notes_to_add:
			if n is Dictionary and int(n.get("pattern_pitch", -1)) == 60:
				print("[RF_DIAG] MATERIALIZE NOTE pitch=60 rel=%s drum=%s lane=%s" % [str(float(n.get("time", 0.0) - start_time)), str(n.get("drum", "")), str(n.get("lane", ""))])
				break
		for n in pattern.notes_rel:
			if n is Dictionary and int(n.get("pitch", -1)) == 60 and float(n.get("relTime", 0.0)) == 0.0:
				print("[RF_DIAG] MATERIALIZE SPECIFIC pitch=60 relTime=0.0 drum=kick lane=0")
				break
			if n is Dictionary and int(n.get("pitch", -1)) == 60 and abs(float(n.get("relTime", 0.0)) - 0.461538) < 0.01:
				print("[RF_DIAG] MATERIALIZE SPECIFIC pitch=60 relTime=0.461538 drum=kick lane=0")
				break
	if notes_to_add.is_empty():
		if MIDI_BROWSER_DIAGNOSTICS:
			print("[RF_DIAG] MATERIALIZE FAILED stage=empty_notes_to_add src=%d" % src_count)
		_set_status("No notes to insert for %s" % pattern.name, true)
		return
	if MIDI_BROWSER_DIAGNOSTICS:
		print("[RF_DIAG] MATERIALIZE BEFORE CREATE pattern_id=%s count=%d" % [pattern.id, notes_to_add.size()])
	var cmd := ChartEditorCommands.AddPatternNotesCommand.new(notes_to_add, pattern.id)
	var err := undo_stack.push_and_do(cmd, state)
	if err != "":
		_set_status("Insert failed: %s" % err, true)
		return
	state.mark_dirty()
	if state.corrections:
		state.corrections.record_action("add_pattern", {"pattern_id": pattern.id, "start": start_time, "count": notes_to_add.size()})
	_refresh_ui()
	_set_status("Inserted pattern %s (%d notes) at %s" % [pattern.name, notes_to_add.size(), _format_time_mmss(start_time)], false)

var _left_split_dragging: bool = false

func _setup_inspector_resizable() -> void:
	# Inspector is now fixed width (320) — no drag-resize, no persistence, as per spec.
	# Keep variables for compatibility but do not connect dragged signal.
	_main_split = get_node_or_null("ContentRow/MainSplit")
	_inspector_pane = get_node_or_null("ContentRow/MainSplit/InspectorPane") as PanelContainer
	if _inspector_pane:
		_inspector_pane.custom_minimum_size = Vector2(320, 0)
		_inspector_pane.size_flags_horizontal = 0
	# Ensure left HSplit (ContentRow) has a sensible initial split for MIDI Browser
	var left_split := get_node_or_null("ContentRow") as HSplitContainer
	if left_split:
		# Left panel (DrumPalettePane) minimum is 220 in tscn; initial split 260 leaves Playfield+Inspector visible.
		left_split.split_offset = 260
		left_split.collapsed = false
		if not left_split.gui_input.is_connected(_on_left_split_gui_input):
			left_split.gui_input.connect(_on_left_split_gui_input)
		if not left_split.dragged.is_connected(_on_left_split_dragged):
			left_split.dragged.connect(_on_left_split_dragged)

func _is_mouse_over_left_split_handle(global_pos: Vector2) -> bool:
	var left_split := get_node_or_null("ContentRow") as HSplitContainer
	if left_split == null or not is_instance_valid(left_split):
		return false
	var rect := left_split.get_global_rect()
	# HSplit handle is a small vertical area around split_offset
	var handle_x := rect.position.x + float(left_split.split_offset) + 4.0
	return absf(global_pos.x - handle_x) < 10.0 and global_pos.y >= rect.position.y and global_pos.y <= rect.position.y + rect.size.y

func _on_left_split_gui_input(event: InputEvent) -> void:
	if MIDI_BROWSER_DIAGNOSTICS:
		var ev_str := ""
		if event is InputEventMouseButton:
			var mbe := event as InputEventMouseButton
			ev_str = "MB%d %s dbl=%s pos=%s global=%s" % [mbe.button_index, "press" if mbe.pressed else "release", str(mbe.double_click), str(mbe.position), str(mbe.global_position)]
		elif event is InputEventMouseMotion:
			ev_str = "Motion pos=%s" % str((event as InputEventMouseMotion).position)
		else:
			ev_str = event.get_class()
		print("[RF_DIAG] LEFT SPLIT EVENT %s split_offset=%d dragging=%s" % [ev_str, int((get_node_or_null("ContentRow") as HSplitContainer).split_offset) if get_node_or_null("ContentRow") is HSplitContainer else -1, str(_left_split_dragging)])
	# HSplit handle double-click: check on any control that receives it, not just ContentRow
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		var left_split := get_node_or_null("ContentRow") as HSplitContainer
		if left_split:
			if MIDI_BROWSER_DIAGNOSTICS:
				print("[RF_DIAG] LEFT SPLIT DOUBLE CLICK split_offset_before=%d global=%s" % [left_split.split_offset, str((event as InputEventMouseButton).global_position)])
			left_split.split_offset = 260
			_left_split_dragging = false
			if MIDI_BROWSER_DIAGNOSTICS:
				print("[RF_DIAG] LEFT SPLIT RESET split_offset_after=%d" % left_split.split_offset)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_left_split_dragging = true
				if MIDI_BROWSER_DIAGNOSTICS:
					print("[RF_DIAG] LEFT SPLIT PRESS mouse=%s split_offset_before=%d dragging_before=%s handle_hit=%s" % [str(mb.global_position), int((get_node_or_null("ContentRow") as HSplitContainer).split_offset) if get_node_or_null("ContentRow") is HSplitContainer else -1, str(_left_split_dragging), str(_is_mouse_over_left_split_handle(mb.global_position))])
			else:
				if MIDI_BROWSER_DIAGNOSTICS:
					print("[RF_DIAG] LEFT SPLIT RELEASE split_offset=%d dragging=%s" % [int((get_node_or_null("ContentRow") as HSplitContainer).split_offset) if get_node_or_null("ContentRow") is HSplitContainer else -1, str(_left_split_dragging)])
				_left_split_dragging = false
				call_deferred("_clear_left_split_dragging_deferred")

func _on_left_split_dragged(offset: int) -> void:
	_left_split_dragging = true
	call_deferred("_clear_left_split_dragging_deferred")

func _clear_left_split_dragging_deferred() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_left_split_dragging = false
	if _left_split_dragging == false:
		# Ensure Playfield doesn't think LMB still held after resize drag that ended over Playfield
		_gesture_lmb_armed_outside = false
		_gesture_rmb_armed_outside = false

func _setup_top_menu() -> void:
	# File | Edit | View | Chart | Playback | Tools | Help — localized, shortcuts dynamically via Shortcut resource (muted secondary color, proper separation)
	var file_menu := get_node_or_null("MenuBar/FileMenu") as MenuButton
	if file_menu:
		var p := file_menu.get_popup()
		p.clear()
		var f_save_lbl := tr("CHART_EDITOR_MENU_FILE_SAVE") if tr("CHART_EDITOR_MENU_FILE_SAVE") != "CHART_EDITOR_MENU_FILE_SAVE" else "Save"
		p.add_item(f_save_lbl, 1)
		_set_menu_shortcut(p, 0, "save")
		var f_saveas_lbl := tr("CHART_EDITOR_MENU_FILE_SAVE_AS") if tr("CHART_EDITOR_MENU_FILE_SAVE_AS") != "CHART_EDITOR_MENU_FILE_SAVE_AS" else "Save As"
		p.add_item(f_saveas_lbl, 2)
		# Save As uses same binding as Save but shown without shortcut to avoid duplicate visual; keep clean
		if not p.id_pressed.is_connected(_on_file_menu_id_pressed):
			p.id_pressed.connect(_on_file_menu_id_pressed)
	var edit_menu := get_node_or_null("MenuBar/EditMenu") as MenuButton
	if edit_menu:
		var p2 := edit_menu.get_popup()
		p2.clear()
		var e_undo_lbl := tr("CHART_EDITOR_MENU_EDIT_UNDO") if tr("CHART_EDITOR_MENU_EDIT_UNDO") != "CHART_EDITOR_MENU_EDIT_UNDO" else "Undo"
		p2.add_item(e_undo_lbl, 1)
		_set_menu_shortcut(p2, 0, "undo")
		var e_redo_lbl := tr("CHART_EDITOR_MENU_EDIT_REDO") if tr("CHART_EDITOR_MENU_EDIT_REDO") != "CHART_EDITOR_MENU_EDIT_REDO" else "Redo"
		p2.add_item(e_redo_lbl, 2)
		_set_menu_shortcut(p2, 1, "redo")
		p2.add_separator()
		var e_cut_lbl := tr("CHART_EDITOR_MENU_EDIT_CUT") if tr("CHART_EDITOR_MENU_EDIT_CUT") != "CHART_EDITOR_MENU_EDIT_CUT" else "Cut"
		p2.add_item(e_cut_lbl, 3)
		_set_menu_shortcut(p2, 3, "cut")
		var e_copy_lbl := tr("CHART_EDITOR_MENU_EDIT_COPY") if tr("CHART_EDITOR_MENU_EDIT_COPY") != "CHART_EDITOR_MENU_EDIT_COPY" else "Copy"
		p2.add_item(e_copy_lbl, 4)
		_set_menu_shortcut(p2, 4, "copy")
		var e_paste_lbl := tr("CHART_EDITOR_MENU_EDIT_PASTE") if tr("CHART_EDITOR_MENU_EDIT_PASTE") != "CHART_EDITOR_MENU_EDIT_PASTE" else "Paste"
		p2.add_item(e_paste_lbl, 5)
		_set_menu_shortcut(p2, 5, "paste")
		var e_del_lbl := tr("CHART_EDITOR_MENU_EDIT_DELETE") if tr("CHART_EDITOR_MENU_EDIT_DELETE") != "CHART_EDITOR_MENU_EDIT_DELETE" else "Delete"
		p2.add_item(e_del_lbl, 6)
		_set_menu_shortcut(p2, 6, "delete")
		if not p2.id_pressed.is_connected(_on_edit_menu_id_pressed):
			p2.id_pressed.connect(_on_edit_menu_id_pressed)
	var view_menu := get_node_or_null("MenuBar/ViewMenu") as MenuButton
	if view_menu:
		var p3 := view_menu.get_popup()
		p3.clear()
		var v_in_lbl := tr("CHART_EDITOR_MENU_VIEW_ZOOM_IN") if tr("CHART_EDITOR_MENU_VIEW_ZOOM_IN") != "CHART_EDITOR_MENU_VIEW_ZOOM_IN" else "Zoom In"
		p3.add_item(v_in_lbl, 1)
		var v_out_lbl := tr("CHART_EDITOR_MENU_VIEW_ZOOM_OUT") if tr("CHART_EDITOR_MENU_VIEW_ZOOM_OUT") != "CHART_EDITOR_MENU_VIEW_ZOOM_OUT" else "Zoom Out"
		p3.add_item(v_out_lbl, 2)
		var v_reset_lbl := tr("CHART_EDITOR_MENU_VIEW_ZOOM_RESET") if tr("CHART_EDITOR_MENU_VIEW_ZOOM_RESET") != "CHART_EDITOR_MENU_VIEW_ZOOM_RESET" else "Reset Zoom"
		p3.add_item(v_reset_lbl, 3)
		if not p3.id_pressed.is_connected(_on_view_menu_id_pressed):
			p3.id_pressed.connect(_on_view_menu_id_pressed)
	var chart_menu := get_node_or_null("MenuBar/ChartMenu") as MenuButton
	if chart_menu:
		var p4 := chart_menu.get_popup()
		p4.clear()
		var c_quant_lbl := tr("CHART_EDITOR_MENU_CHART_QUANTIZE") if tr("CHART_EDITOR_MENU_CHART_QUANTIZE") != "CHART_EDITOR_MENU_CHART_QUANTIZE" else "Quantize"
		p4.add_item(c_quant_lbl, 1)
		_set_menu_shortcut(p4, 0, "quantize")
		if not p4.id_pressed.is_connected(_on_chart_menu_id_pressed):
			p4.id_pressed.connect(_on_chart_menu_id_pressed)
	var playback_menu := get_node_or_null("MenuBar/PlaybackMenu") as MenuButton
	if playback_menu:
		var p5 := playback_menu.get_popup()
		p5.clear()
		var pb_play_lbl := tr("CHART_EDITOR_MENU_PLAYBACK_PLAY") if tr("CHART_EDITOR_MENU_PLAYBACK_PLAY") != "CHART_EDITOR_MENU_PLAYBACK_PLAY" else "Play/Pause"
		p5.add_item(pb_play_lbl, 1)
		_set_menu_shortcut(p5, 0, "play_pause")
		var pb_stop_lbl := tr("CHART_EDITOR_MENU_PLAYBACK_STOP") if tr("CHART_EDITOR_MENU_PLAYBACK_STOP") != "CHART_EDITOR_MENU_PLAYBACK_STOP" else "Stop"
		p5.add_item(pb_stop_lbl, 2)
		var pb_toggle_lbl := tr("CHART_EDITOR_MENU_PLAYBACK_TOGGLE_AUDIO") if tr("CHART_EDITOR_MENU_PLAYBACK_TOGGLE_AUDIO") != "CHART_EDITOR_MENU_PLAYBACK_TOGGLE_AUDIO" else "Toggle Audio Source"
		p5.add_item(pb_toggle_lbl, 3)
		_set_menu_shortcut(p5, 2, "toggle_audio_source")
		if not p5.id_pressed.is_connected(_on_playback_menu_id_pressed):
			p5.id_pressed.connect(_on_playback_menu_id_pressed)
	var tools_menu := get_node_or_null("MenuBar/ToolsMenu") as MenuButton
	if tools_menu:
		var p6 := tools_menu.get_popup()
		p6.clear()
		var t_sel_lbl := tr("CHART_EDITOR_TOOL_SELECT") if tr("CHART_EDITOR_TOOL_SELECT") != "CHART_EDITOR_TOOL_SELECT" else "Select"
		p6.add_check_item(t_sel_lbl)
		_set_menu_shortcut(p6, 0, "tool_select")
		p6.set_item_checked(0, _current_tool == "select")
		var t_pen_lbl := tr("CHART_EDITOR_TOOL_PENCIL") if tr("CHART_EDITOR_TOOL_PENCIL") != "CHART_EDITOR_TOOL_PENCIL" else "Pencil"
		p6.add_check_item(t_pen_lbl)
		_set_menu_shortcut(p6, 1, "tool_pencil")
		p6.set_item_checked(1, _current_tool == "pencil")
		if not p6.id_pressed.is_connected(_on_tools_menu_id_pressed):
			p6.id_pressed.connect(_on_tools_menu_id_pressed)

func _keybind_text(action: String) -> String:
	var km := SettingsManager.get_chart_editor_keymap() if SettingsManager else {}
	var arr = km.get(action, [])
	if arr is Array and arr.size() > 0:
		var b = arr[0]
		if b is Dictionary:
			return ChartEditorBindings.binding_to_string(b)
	return ""

func _set_menu_shortcut(popup: PopupMenu, index: int, action: String) -> void:
	if popup == null or index < 0 or index >= popup.item_count:
		return
	var km := SettingsManager.get_chart_editor_keymap() if SettingsManager else {}
	var arr = km.get(action, [])
	if arr is Array and arr.size() > 0:
		var binding = arr[0]
		if binding is Dictionary and not binding.is_empty():
			var sc := Shortcut.new()
			var ev := InputEventKey.new()
			ev.keycode = int(binding.get("key", 0))
			ev.ctrl_pressed = bool(binding.get("ctrl", false))
			ev.shift_pressed = bool(binding.get("shift", false))
			ev.alt_pressed = bool(binding.get("alt", false))
			# Also set physical for robustness
			ev.physical_keycode = ev.keycode
			sc.events = [ev]
			popup.set_item_shortcut(index, sc)
			# Ensure shortcut text uses muted secondary color via theme (PopupMenu default)
			return
	# No binding — clear shortcut
	popup.set_item_shortcut(index, null)

func _on_file_menu_id_pressed(id: int) -> void:
	match id:
		1: _on_save_pressed()
		2: _on_save_as_pressed()
	_return_focus_to_editor()

func _on_edit_menu_id_pressed(id: int) -> void:
	match id:
		1:
			_on_undo_pressed()
			_undo_held = true
			_undo_hold_time = 0.0
			_undo_next_repeat = REPEAT_INITIAL_DELAY
			_undo_diag_last_log_t = -100.0
			print("[DIAG HOLD] MENU KEY DOWN action=undo held_after=%s" % str(_undo_held))
		2:
			_on_redo_pressed()
			_redo_held = true
			_redo_hold_time = 0.0
			_redo_next_repeat = REPEAT_INITIAL_DELAY
			_redo_diag_last_log_t = -100.0
			print("[DIAG HOLD] MENU KEY DOWN action=redo held_after=%s" % str(_redo_held))
		3: _on_cut_pressed()
		4: _on_copy()
		5: _on_paste()
		6: _on_inspector_delete()
	_return_focus_to_editor()

func _on_view_menu_id_pressed(id: int) -> void:
	match id:
		1: _on_zoom_changed(state.px_per_sec * 1.2 if state else 432)
		2: _on_zoom_changed(state.px_per_sec / 1.2 if state else 300)
		3: _on_zoom_changed(360.0)
	_return_focus_to_editor()

func _on_chart_menu_id_pressed(id: int) -> void:
	match id:
		1: _on_inspector_quantize(state.snap_division if state else 16)
	_return_focus_to_editor()

func _on_playback_menu_id_pressed(id: int) -> void:
	match id:
		1: _on_play_pressed()
		2: _go_to_time(0.0)
		3: _toggle_audio_source()
	_return_focus_to_editor()

func _on_tools_menu_id_pressed(id: int) -> void:
	match id:
		0: _set_tool("select")
		1: _set_tool("pencil")
	_return_focus_to_editor()

func _set_tool(tool: String) -> void:
	_current_tool = tool
	_update_tool_buttons()
	if _overlay and _overlay.has_method("set_tool"):
		_overlay.set_tool(_current_tool)
	var m := get_node_or_null("MenuBar/ToolsMenu") as MenuButton
	if m:
		var p := m.get_popup()
		p.set_item_checked(0, _current_tool == "select")
		p.set_item_checked(1, _current_tool == "pencil")
	_return_focus_to_editor()

func _update_tool_buttons() -> void:
	if _select_button:
		_select_button.button_pressed = _current_tool == "select"
		UiIconHelper.configure_button_icon(_select_button, "mouse-pointer-2.svg", Color(0.55,0.78,0.98) if _current_tool == "select" else Color(0.5,0.54,0.62), 16)
	if _pencil_button:
		_pencil_button.button_pressed = _current_tool == "pencil"
		UiIconHelper.configure_button_icon(_pencil_button, "pencil.svg", Color(0.55,0.78,0.98) if _current_tool == "pencil" else Color(0.5,0.54,0.62), 16)

func _on_select_tool_pressed() -> void:
	if _current_tool == "select":
		return
	_UiModifierSounds.play_select()
	_set_tool("select")

func _on_pencil_tool_pressed() -> void:
	if _current_tool == "pencil":
		return
	_UiModifierSounds.play_select()
	_set_tool("pencil")

func _on_cut_pressed() -> void:
	if state == null or not state.has_selection():
		return
	var sel: Array = state.selected_notes()
	state.clipboard = EditorNoteUtilsClass.clone_notes(sel)
	if state.clipboard.is_empty():
		return
	var min_t := 1e9
	for n in state.clipboard:
		min_t = minf(min_t, float(n.get("time", 0.0)))
	state.clipboard_min_time = min_t if min_t < 1e9 else 0.0
	# Delete as single undo
	var keys: Array = []
	for k in state.selected_keys.keys():
		keys.append(k)
	var cmd := ChartEditorCommands.DeleteNotesCommand.new(keys)
	var err := undo_stack.push_and_do(cmd, state)
	if err != "":
		_set_status(err, true)
		return
	state.mark_dirty()
	if state.corrections:
		state.corrections.record_action("cut", {"keys": keys, "count": keys.size()})
	_refresh_ui()
	_play_delete_feedback("cut")
	_return_focus_to_editor()

func _on_drum_palette_pressed(drum: String) -> void:
	var sanitized := EditorNoteUtilsClass.sanitize_drum(drum)
	if _active_drum == sanitized:
		return
	_UiModifierSounds.play_select()
	_active_drum = sanitized
	# Pencil remains active, no auto switch
	_refresh_drum_palette()
	if _inspector and _inspector.has_method("refresh"):
		_inspector.refresh()
	_set_status("Drum: %s" % _active_drum, false)
	# Spec 20: tool change must not start playback, must not change selection
	# Return focus so Space stays Play/Pause (spec 10)
	_return_focus_to_editor()

func _refresh_drum_palette() -> void:
	for drum in _drum_palette_buttons.keys():
		var btn: Button = _drum_palette_buttons[drum] as Button
		if btn == null:
			continue
		var is_active := String(drum) == _active_drum
		# Visual feedback: selected = white, non-selected = drum icon color (immediate, no lag)
		if is_active:
			btn.modulate = Color(1, 1, 1, 1.0)
			btn.remove_theme_color_override("font_color")
			btn.add_theme_color_override("font_color", Color(1, 1, 1, 1.0))
			btn.button_pressed = true
		else:
			btn.modulate = Color(1, 1, 1, 1.0)
			btn.add_theme_color_override("font_color", EditorNoteUtilsClass.color_for_drum(drum))
			btn.button_pressed = false

func _setup_bottom_extra() -> void:
	if _zoom_minus and not _zoom_minus.pressed.is_connected(_on_zoom_minus):
		_zoom_minus.pressed.connect(_on_zoom_minus)
	if _zoom_plus and not _zoom_plus.pressed.is_connected(_on_zoom_plus):
		_zoom_plus.pressed.connect(_on_zoom_plus)
	if _time_label:
		_time_label.text = "0:00.000 / 0:00.000"
	if _bpm_label:
		_bpm_label.text = "120.00 BPM"
	_update_bottom_labels()
	_apply_chart_editor_icons()

func _apply_chart_editor_icons() -> void:
	var _t_icons := PerfTrace.begin("perf.detail.chart_editor.bottom_extra.icons")
	# TopBar — header = document actions; left = tools; bottom = navigation
	if _back_btn:
		UiIconHelper.setup_back_button(_back_btn)
		if _back_btn.text.begins_with("‹"):
			_back_btn.text = tr("BTN_BACK")
		elif _back_btn.text == "":
			_back_btn.text = tr("BTN_BACK")
		_back_btn.tooltip_text = tr("CHART_EDITOR_TIP_BACK") if tr("CHART_EDITOR_TIP_BACK") != "CHART_EDITOR_TIP_BACK" else tr("BTN_BACK")
	if _undo_btn:
		UiIconHelper.configure_button_icon(_undo_btn, "rotate-ccw.svg", UiIconHelper.MUTED, 16)
		_undo_btn.text = ""
		_undo_btn.tooltip_text = tr("CHART_EDITOR_TIP_UNDO") if tr("CHART_EDITOR_TIP_UNDO") != "CHART_EDITOR_TIP_UNDO" else "Undo (Ctrl+Z)"
	if _redo_btn:
		UiIconHelper.configure_button_icon(_redo_btn, "refresh-cw.svg", UiIconHelper.MUTED, 16)
		_redo_btn.text = ""
		_redo_btn.tooltip_text = tr("CHART_EDITOR_TIP_REDO") if tr("CHART_EDITOR_TIP_REDO") != "CHART_EDITOR_TIP_REDO" else "Redo (Ctrl+Y)"
	if _play_btn:
		var icon := "pause.svg" if state and state.is_playing else "play.svg"
		UiIconHelper.configure_button_icon(_play_btn, icon, UiIconHelper.ACCENT, 16)
		_play_btn.text = ""
		_play_btn.tooltip_text = tr("CHART_EDITOR_TIP_PLAY") if tr("CHART_EDITOR_TIP_PLAY") != "CHART_EDITOR_TIP_PLAY" else "Play / Pause (Space)"
	if _save_btn:
		_save_btn.theme_type_variation = &"FlatModalPrimaryButton"
		UiIconHelper.setup_modal_accent_button(_save_btn, "check.svg", Color(0.16,0.62,0.38,1))
		if _save_btn.text == "":
			_save_btn.text = tr("BTN_SAVE") if tr("BTN_SAVE") != "BTN_SAVE" else "Сохранить"
		_save_btn.tooltip_text = tr("CHART_EDITOR_TIP_SAVE") if tr("CHART_EDITOR_TIP_SAVE") != "CHART_EDITOR_TIP_SAVE" else "Save (Ctrl+S)"
	if _save_as_btn:
		_save_as_btn.tooltip_text = tr("CHART_EDITOR_TIP_SAVE_AS") if tr("CHART_EDITOR_TIP_SAVE_AS") != "CHART_EDITOR_TIP_SAVE_AS" else "Save As Next Version"
		UiIconHelper.configure_button_icon(_save_as_btn, "plus.svg", UiIconHelper.MUTED, 14)
		if _save_as_btn.text == "" or _save_as_btn.text == "Сохранить как v+1":
			var save_as_text := tr("CHART_EDITOR_ACTION_SAVE_AS")
			_save_as_btn.text = save_as_text if save_as_text != "CHART_EDITOR_ACTION_SAVE_AS" and save_as_text != "" else "Сохранить как v+1"
	# MoreButton removed per spec — no dead controls
	if _more_btn:
		_more_btn.visible = false
	# Inspector actions — иконки вместо эмодзи
	var del_btn := get_node_or_null("ContentRow/MainSplit/InspectorPane/InspectorRoot/InspectorScroll/Inspector/ActionsRow/DeleteButton") as Button
	if del_btn == null:
		del_btn = get_node_or_null("ContentRow/MainSplit/InspectorPane/Inspector/ActionsRow/DeleteButton") as Button
	if del_btn == null:
		del_btn = _find_node_any(["ContentRow/MainSplit/InspectorPane/InspectorRoot/InspectorScroll/Inspector/ActionsRow/DeleteButton", "MainSplit/InspectorPane/InspectorRoot/InspectorScroll/Inspector/ActionsRow/DeleteButton", "MainSplit/InspectorPane/Inspector/ActionsRow/DeleteButton"]) as Button
	if del_btn:
		UiIconHelper.configure_button_icon(del_btn, "trash-2.svg", Color(0.95,0.45,0.45,1), 14)
	var copy_btn := get_node_or_null("ContentRow/MainSplit/InspectorPane/InspectorRoot/InspectorScroll/Inspector/ActionsRow/CopyButton") as Button
	if copy_btn == null:
		copy_btn = get_node_or_null("ContentRow/MainSplit/InspectorPane/Inspector/ActionsRow/CopyButton") as Button
	if copy_btn == null:
		copy_btn = _find_node_any(["ContentRow/MainSplit/InspectorPane/InspectorRoot/InspectorScroll/Inspector/ActionsRow/CopyButton", "MainSplit/InspectorPane/InspectorRoot/InspectorScroll/Inspector/ActionsRow/CopyButton", "MainSplit/InspectorPane/Inspector/ActionsRow/CopyButton"]) as Button
	if copy_btn:
		UiIconHelper.configure_button_icon(copy_btn, "layers.svg", UiIconHelper.MUTED, 14)
	var paste_btn := get_node_or_null("ContentRow/MainSplit/InspectorPane/InspectorRoot/InspectorScroll/Inspector/ActionsRow/PasteButton") as Button
	if paste_btn == null:
		paste_btn = get_node_or_null("ContentRow/MainSplit/InspectorPane/Inspector/ActionsRow/PasteButton") as Button
	if paste_btn == null:
		paste_btn = _find_node_any(["ContentRow/MainSplit/InspectorPane/InspectorRoot/InspectorScroll/Inspector/ActionsRow/PasteButton", "MainSplit/InspectorPane/InspectorRoot/InspectorScroll/Inspector/ActionsRow/PasteButton", "MainSplit/InspectorPane/Inspector/ActionsRow/PasteButton"]) as Button
	if paste_btn:
		UiIconHelper.configure_button_icon(paste_btn, "layers-2.svg", UiIconHelper.MUTED, 14)
	if _zoom_minus:
		_zoom_minus.text = "−"
		_zoom_minus.tooltip_text = tr("CHART_EDITOR_TIP_ZOOM_OUT") if tr("CHART_EDITOR_TIP_ZOOM_OUT") != "CHART_EDITOR_TIP_ZOOM_OUT" else "Zoom out"
	if _zoom_plus:
		_zoom_plus.text = "+"
		_zoom_plus.tooltip_text = tr("CHART_EDITOR_TIP_ZOOM_IN") if tr("CHART_EDITOR_TIP_ZOOM_IN") != "CHART_EDITOR_TIP_ZOOM_IN" else "Zoom in"
	if _zoom_slider:
		_zoom_slider.tooltip_text = tr("CHART_EDITOR_TIP_ZOOM_SLIDER") if tr("CHART_EDITOR_TIP_ZOOM_SLIDER") != "CHART_EDITOR_TIP_ZOOM_SLIDER" else tr("CHART_EDITOR_SNAP_TOOLTIP")
	if _snap_check:
		_snap_check.tooltip_text = tr("CHART_EDITOR_SNAP_TOOLTIP") if tr("CHART_EDITOR_SNAP_TOOLTIP") != "CHART_EDITOR_SNAP_TOOLTIP" else "Snap"
	if _snap_option:
		_snap_option.tooltip_text = tr("CHART_EDITOR_SNAP_TOOLTIP") if tr("CHART_EDITOR_SNAP_TOOLTIP") != "CHART_EDITOR_SNAP_TOOLTIP" else "Snap"
	# Ensure left palette header localized
	var tools_hdr := get_node_or_null("ContentRow/DrumPalettePane/DrumPaletteVBox/ToolsHeader") as Label
	if tools_hdr:
		var t := tr("CHART_EDITOR_TOOLS_TITLE")
		tools_hdr.text = t if t != "CHART_EDITOR_TOOLS_TITLE" and t != "" else "ИНСТРУМЕНТЫ"
	# Ensure bottom hints label localized
	var hints_lbl := get_node_or_null("BottomBar/BottomHBox/HintsLabel") as Label
	if hints_lbl:
		var ht := tr("CHART_EDITOR_HINTS_COMBINED")
		hints_lbl.text = ht if ht != "CHART_EDITOR_HINTS_COMBINED" and ht != "" else "ПКМ Добавить • ЛКМ Выбрать • Shift Область • Alt Переместить"
	PerfTrace.end("perf.detail.chart_editor.bottom_extra.icons", _t_icons)

func _update_bottom_labels() -> void:
	if state and state.document and state.document.notes.size() > 0:
		var last_t2 := float(state.document.notes[state.document.notes.size()-1].get("time", 0.0))
		var real_dur := maxf(state.duration_s, last_t2 + 2.0)
		if real_dur > state.duration_s + 1.0:
			state.duration_s = real_dur
	if _zoom_value and state:
		_zoom_value.text = "%d%%" % int(round(state.px_per_sec / 3.6))
	elif _zoom_value and _zoom_slider:
		_zoom_value.text = "%d%%" % int(round(_zoom_slider.value / 3.6))
	if _time_label and state:
		var cur := _format_time_mmss(state.song_time)
		var dur := _format_time_mmss(state.duration_s)
		_time_label.text = "%s / %s" % [cur, dur]
	if _bpm_label and state:
		_bpm_label.text = "%.2f BPM" % state.bpm

func _format_time_mmss(t: float) -> String:
	var total_ms := int(round(maxf(0.0, t) * 1000.0))
	var mins := total_ms / 60000
	var secs := (total_ms % 60000) / 1000
	var ms := total_ms % 1000
	return "%d:%02d.%03d" % [mins, secs, ms]

func _on_zoom_minus() -> void:
	if state and _zoom_slider:
		_zoom_slider.value = maxf(_zoom_slider.min_value, _zoom_slider.value - 80.0)
		_on_zoom_changed(_zoom_slider.value)
	_return_focus_to_editor()

func _on_zoom_plus() -> void:
	if state and _zoom_slider:
		_zoom_slider.value = minf(_zoom_slider.max_value, _zoom_slider.value + 80.0)
		_on_zoom_changed(_zoom_slider.value)
	_return_focus_to_editor()

func _on_view_settings_pressed() -> void:
	# Заглушка из мокапа: кнопок под подсказкой/внизу пока нет функционала.
	# Показываем статус, чтобы не было "мертвых" зон.
	_set_status("Настройки вида — в разработке (пока без функции)", false)

func _connect_scroll_sync() -> void:
	if _scroll == null or _playfield == null:
		return
	var vbar := _scroll.get_v_scroll_bar()
	if vbar and not vbar.value_changed.is_connected(_on_scroll_value_changed):
		vbar.value_changed.connect(_on_scroll_value_changed)

func _on_scroll_value_changed(value: float) -> void:
	print("[ChartEditor] _on_scroll_value_changed", value)
	if _playfield and state:
		if _playfield is GamePlayfield:
			# Для GamePlayfield скролл — абсолютный, view_time_offset не используется
			return
		# Legacy ChartEditorPlayfield
		if "view_time_offset" in _playfield:
			_playfield.view_time_offset = maxf(0.0, value / maxf(1.0, _playfield.editor_px_per_sec))
		_playfield.queue_redraw()

func _sync_playfield_to_scroll() -> void:
	if _playfield is GamePlayfield:
		return
	if _scroll and _playfield and state and "view_time_offset" in _playfield:
		var desired := int(maxf(0.0, _playfield.view_time_offset) * _playfield.editor_px_per_sec)
		if _scroll.scroll_vertical != desired:
			_scroll.scroll_vertical = desired

func _sync_scroll_to_playfield() -> void:
	if _playfield is GamePlayfield:
		return
	if _scroll and _playfield and state and "view_time_offset" in _playfield:
		_playfield.view_time_offset = maxf(0.0, float(_scroll.scroll_vertical) / maxf(1.0, _playfield.editor_px_per_sec))

func _build_fallback_ui() -> void:
	# Very minimal — for headless verification. Real UI is in tscn.
	pass

func _connect_signals() -> void:
	if _back_btn and not _back_btn.pressed.is_connected(_on_back_pressed):
		_back_btn.pressed.connect(_on_back_pressed)
	if _play_btn and not _play_btn.pressed.is_connected(_on_play_pressed):
		_play_btn.pressed.connect(_on_play_pressed)
	if _save_btn and not _save_btn.pressed.is_connected(_on_save_pressed):
		_save_btn.pressed.connect(_on_save_pressed)
	if _save_as_btn and not _save_as_btn.pressed.is_connected(_on_save_as_pressed):
		_save_as_btn.pressed.connect(_on_save_as_pressed)
	if _undo_btn and not _undo_btn.pressed.is_connected(_on_undo_pressed):
		_undo_btn.pressed.connect(_on_undo_pressed)
	if _redo_btn and not _redo_btn.pressed.is_connected(_on_redo_pressed):
		_redo_btn.pressed.connect(_on_redo_pressed)
	if _revert_btn and not _revert_btn.pressed.is_connected(_on_revert_pressed):
		_revert_btn.pressed.connect(_on_revert_pressed)
	if _more_btn and not _more_btn.pressed.is_connected(_on_revert_pressed):
		_more_btn.pressed.connect(_on_revert_pressed)
	if _snap_check and not _snap_check.toggled.is_connected(_on_snap_toggled):
		_snap_check.toggled.connect(_on_snap_toggled)
	if _snap_option and not _snap_option.item_selected.is_connected(_on_snap_division_selected):
		_snap_option.item_selected.connect(_on_snap_division_selected)
	if _zoom_slider and not _zoom_slider.value_changed.is_connected(_on_zoom_changed):
		_zoom_slider.value_changed.connect(_on_zoom_changed)
	if _audio_source_option and not _audio_source_option.item_selected.is_connected(_on_audio_source_selected):
		_audio_source_option.item_selected.connect(_on_audio_source_selected)

func _open_chart(song_path: String, chart_stem: String, lanes: int, chart_path: String = "") -> void:
	var _t_open := PerfTrace.begin("perf.load.chart_editor.chart")
	var _t_open_total := PerfTrace.begin("perf.load.chart_editor.open_total")
	var _t_scene := PerfTrace.begin("perf.load.chart_editor.scene")
	# Tiny optimization: let UI frame render before heavy chart load to reduce perceived lag
	if get_tree():
		await get_tree().process_frame
	PerfTrace.end("perf.load.chart_editor.scene", _t_scene)
	# If specific chart_path provided (from picker), use it directly
	var pending_path := chart_path.strip_edges().replace("\\", "/")
	if pending_path != "" and FileAccess.file_exists(DirectoryUtils.to_absolute(pending_path)):
		# Derive stem/version from file name for correct state
		var fname_tmp := pending_path.get_file()
		var base_tmp := fname_tmp.get_basename()
		if base_tmp.to_lower().begins_with("drums_"):
			var extracted_tmp := base_tmp.substr(6)
			if extracted_tmp != "":
				chart_stem = extracted_tmp
		# Also keep pending for state
		_pending_chart_path = pending_path
	var original_stem := chart_stem.strip_edges().to_lower()
	var stem_norm := original_stem
	# Preserve versioned/custom stems that actually exist on disk
	var is_ver := RfcCorrectionsCodec.is_versioned_stem(original_stem)
	if is_ver:
		var base_v := RfcCorrectionsCodec.base_stem_from_versioned(original_stem)
		var ver_v := RfcCorrectionsCodec.version_from_stem(original_stem)
		var vpath := RfcCorrectionsCodec.versioned_path_for(song_path, "drums", base_v, ver_v, "rf")
		if FileAccess.file_exists(DirectoryUtils.to_absolute(vpath)):
			stem_norm = original_stem
		else:
			# Fall back to base if versioned file not found, but check if base file exists
			if NotesUtils.notes_exist(song_path, "drums", original_stem, lanes) or NotesUtils.resolve_unified_mode_path(song_path, "drums", original_stem) != "":
				stem_norm = original_stem
			else:
				stem_norm = RfcCorrectionsCodec.base_stem_from_versioned(original_stem).to_lower()
				if stem_norm == "":
					stem_norm = "arcade_medium"
				else:
					var norm2 := NotesUtils.resolve_mode_stem_key(stem_norm)
					if norm2 != "":
						stem_norm = norm2
	else:
		# Check if original custom stem actually exists before normalizing
		if NotesUtils.notes_exist(song_path, "drums", original_stem, lanes) or NotesUtils.resolve_unified_mode_path(song_path, "drums", original_stem) != "" or FileAccess.file_exists(DirectoryUtils.to_absolute(RfcCorrectionsCodec.versioned_path_for(song_path, "drums", original_stem, 0, "rf"))):
			stem_norm = original_stem
		else:
			stem_norm = NotesUtils.resolve_mode_stem_key(original_stem)
			if stem_norm == "":
				stem_norm = "arcade_medium"
	# Canonical enforcement: if requested stem != medium but medium missing, prompt.
	var _t_resolve := PerfTrace.begin("perf.detail.chart_editor.resolve")
	var canonical_exists := NotesUtils.notes_exist(song_path, "drums", "arcade_medium", lanes)
	var requested_exists := NotesUtils.notes_exist(song_path, "drums", stem_norm, lanes)
	PerfTrace.end("perf.detail.chart_editor.resolve", _t_resolve)
	if stem_norm != "arcade_medium" and not canonical_exists:
		_show_missing_medium_dialog(song_path, stem_norm)
		# Still open requested if it exists, else open canonical placeholder.
		if not requested_exists:
			stem_norm = "arcade_medium"
	# If nothing exists, error.
	if not NotesUtils.notes_exist(song_path, "drums", stem_norm, lanes) and not NotesUtils.resolve_unified_mode_path(song_path, "drums", stem_norm) != "":
		_set_status("Chart not found: %s %s — generate it first" % [stem_norm, str(song_path.get_file())], true)
		# Still create empty state for inspection? For P0 we require existing chart.
		PerfTrace.end("perf.load.chart_editor.chart", _t_open)
		return

	state = ChartEditorStateClass.new()
	undo_stack = ChartEditorCommands.UndoStack.new()
	var chart_path_for_state := _pending_chart_path if _pending_chart_path.strip_edges() != "" else chart_path.strip_edges().replace("\\", "/")
	var _t_state := PerfTrace.begin("perf.detail.chart_editor.setup_state")
	var err := state.setup(song_path, stem_norm, lanes, chart_path_for_state)
	PerfTrace.end("perf.detail.chart_editor.setup_state", _t_state)
	if err != "":
		_set_status("Open failed: %s" % err, true)
		PerfTrace.end("perf.load.chart_editor.chart", _t_open)
		return

	# Player
	var _t_player := PerfTrace.begin("perf.detail.chart_editor.audio")
	if player == null:
		player = ChartEditorPlayerClass.new()
		player.setup(self, song_path)
	else:
		player.setup(self, song_path)
	player.load_song(song_path)
	PerfTrace.end("perf.detail.chart_editor.audio", _t_player)

	# Wire playfield (GamePlayfield) — reuse gameplay geometry (centered, hit_y 0.88)
	if _playfield:
		print("[ChartEditor] _open_chart has _playfield", _playfield != null, "has setup", _playfield.has_method("setup") if _playfield else false)
		if _playfield.has_method("setup"):
			var speed = state.px_per_sec / 60.0
			print("[ChartEditor] calling _playfield setup lanes", state.lanes, "speed", speed, "is_editor true")
			_playfield.setup(state.lanes, 0.88, speed, true)
			print("[ChartEditor] after setup is_editor", _playfield.is_editor if "is_editor" in _playfield else "no", "hit", _playfield.get_hit_y() if _playfield.has_method("get_hit_y") else 0)
			if _playfield.has_method("set_editor_state"):
				_playfield.set_editor_state(state)
	if _ruler and _ruler.has_method("setup"):
		_ruler.setup(state, _playfield)
		if _ruler.has_signal("seek_requested") and not _ruler.seek_requested.is_connected(_on_ruler_seek):
			_ruler.seek_requested.connect(_on_ruler_seek)
	elif _ruler:
		_ruler.queue_redraw()
		if _ruler.has_signal("seek_requested") and not _ruler.seek_requested.is_connected(_on_ruler_seek):
			_ruler.seek_requested.connect(_on_ruler_seek)
	if _inspector and _inspector.has_method("setup"):
		if _inspector.has_method("setup_with_undo"):
			_inspector.setup_with_undo(state, undo_stack)
		else:
			_inspector.setup(state)
			if _inspector.has_method("set_undo_stack"):
				_inspector.set_undo_stack(undo_stack)
		# Connect inspector signals.
		if _inspector.has_signal("drum_changed") and not _inspector.drum_changed.is_connected(_on_inspector_drum_changed):
			_inspector.drum_changed.connect(_on_inspector_drum_changed)
		if _inspector.has_signal("quantize_requested") and not _inspector.quantize_requested.is_connected(_on_inspector_quantize):
			_inspector.quantize_requested.connect(_on_inspector_quantize)
		if _inspector.has_signal("delete_requested") and not _inspector.delete_requested.is_connected(_on_inspector_delete):
			_inspector.delete_requested.connect(_on_inspector_delete)
		if _inspector.has_signal("copy_requested") and not _inspector.copy_requested.is_connected(_on_copy):
			_inspector.copy_requested.connect(_on_copy)
		if _inspector.has_signal("paste_requested") and not _inspector.paste_requested.is_connected(_on_paste):
			_inspector.paste_requested.connect(_on_paste)
		if _inspector.has_signal("hit_effects_toggled") and not _inspector.hit_effects_toggled.is_connected(_on_hit_effects_toggled):
			_inspector.hit_effects_toggled.connect(_on_hit_effects_toggled)
		if _inspector.has_signal("hide_after_hit_toggled") and not _inspector.hide_after_hit_toggled.is_connected(_on_hide_after_hit_toggled):
			_inspector.hide_after_hit_toggled.connect(_on_hide_after_hit_toggled)
		if _inspector.has_signal("note_color_mode_changed") and not _inspector.note_color_mode_changed.is_connected(_on_note_color_mode_changed):
			_inspector.note_color_mode_changed.connect(_on_note_color_mode_changed)
		if _inspector.has_signal("lane_highlight_toggled") and not _inspector.lane_highlight_toggled.is_connected(_on_lane_highlight_toggled):
			_inspector.lane_highlight_toggled.connect(_on_lane_highlight_toggled)
		if _inspector.has_signal("revert_requested") and not _inspector.revert_requested.is_connected(_on_revert_pressed):
			_inspector.revert_requested.connect(_on_revert_pressed)
		if _inspector.has_signal("select_all_requested") and not _inspector.select_all_requested.is_connected(_on_select_all):
			_inspector.select_all_requested.connect(_on_select_all)
		if _inspector.has_signal("clear_selection_requested") and not _inspector.clear_selection_requested.is_connected(_on_selection_cleared):
			_inspector.clear_selection_requested.connect(_on_selection_cleared)

	if _snap_check:
		_snap_check.button_pressed = state.snap_enabled
	if _snap_option:
		_select_snap_division(state.snap_division)
	if _zoom_slider:
		_zoom_slider.value = state.px_per_sec
	# Fixed viewport: GameScreen-like — narrow gameplay-sized, hit_y 0.88
	if _playfield and state:
		# Ensure playfield uses gameplay travel scale, fixed size (narrow like GameScreen)
		if _playfield.has_method("setup"):
			var speed = state.px_per_sec / 60.0
			_playfield.setup(state.lanes, 0.88, speed, true)
			if _playfield.has_method("set_editor_state"):
				_playfield.set_editor_state(state)
		# Fixed size (gameplay-like narrow, height via VBox expand) — keep width 480, min height 800 like GameScreen
		_playfield.custom_minimum_size = Vector2(480.0, 800.0)
		_update_shop_visuals()
		_refresh_audio_source_ui()
		_reset_hit_tracking(state.song_time)
		# Reset scroll if any (legacy)
		if _scroll:
			_scroll.scroll_vertical = 0
			_scroll.scroll_horizontal = 0
		var overlay = get_node_or_null("ContentRow/MainSplit/PlayfieldPane/PlayfieldVBox/PlayfieldCenter/Playfield/EditorOverlay")
		if overlay == null:
			overlay = get_node_or_null("ContentRow/MainSplit/PlayfieldPane/PlayfieldVBox/Playfield/EditorOverlay")
		if overlay == null:
			overlay = get_node_or_null("ContentRow/MainSplit/PlayfieldPane/PlayfieldVBox/Scroll/Playfield/EditorOverlay")
		if overlay == null:
			overlay = _find_node_any(["ContentRow/MainSplit/PlayfieldPane/PlayfieldVBox/PlayfieldCenter/Playfield/EditorOverlay", "ContentRow/MainSplit/PlayfieldPane/PlayfieldVBox/Playfield/EditorOverlay", "ContentRow/MainSplit/PlayfieldPane/PlayfieldVBox/Scroll/Playfield/EditorOverlay", "ContentRow/MainSplit/PlayfieldPane/Scroll/Playfield/EditorOverlay"])
		if overlay and overlay.has_method("setup"):
			overlay.setup(state, _playfield)
			_overlay = overlay
			# Ensure overlay tool matches screen's current tool (default Pencil) — fixes visual vs real state regression
			if _overlay.has_method("set_tool"):
				_overlay.set_tool(_current_tool)
			_update_tool_buttons()
			# Wire overlay interaction signals (missing in P0 — needed for mouse edit)
			if overlay.has_signal("notes_box_selected") and not overlay.notes_box_selected.is_connected(_on_box_selected):
				overlay.notes_box_selected.connect(_on_box_selected)
			if overlay.has_signal("notes_dragged") and not overlay.notes_dragged.is_connected(_on_notes_dragged):
				overlay.notes_dragged.connect(_on_notes_dragged)
			if overlay.has_signal("note_add_requested") and not overlay.note_add_requested.is_connected(_on_add_requested):
				overlay.note_add_requested.connect(_on_add_requested)
			if overlay.has_signal("notes_deleted") and not overlay.notes_deleted.is_connected(_on_notes_deleted):
				overlay.notes_deleted.connect(_on_notes_deleted)
			if overlay.has_signal("selection_cleared") and not overlay.selection_cleared.is_connected(_on_selection_cleared):
				overlay.selection_cleared.connect(_on_selection_cleared)
			if overlay.has_signal("note_clicked"):
				if not overlay.note_clicked.is_connected(_on_playfield_note_clicked):
					overlay.note_clicked.connect(_on_playfield_note_clicked)
			if overlay.has_signal("selection_changed") and not overlay.selection_changed.is_connected(_on_selection_changed):
				overlay.selection_changed.connect(_on_selection_changed)

	# Stage C: check for .rf.temp recovery before marking clean
	var recovery_handled := await _check_recovery_and_handle()
	if recovery_handled:
		# Recovery dialog handled the open (Restore/Delete/Open) — state may have been replaced via Restore
		# Re-initialize grid/bpm from restored notes if needed
		if state.document:
			# Rebuild grid if bpm changed
			pass
	undo_stack.mark_saved()
	state.mark_clean()
	_last_autosave_hash = _get_document_hash()
	_autosave_timer = 0.0
	_refresh_ui()
	var status_key := "CHART_EDITOR_STATUS_CANONICAL" if state.is_canonical else "CHART_EDITOR_STATUS_DERIVED"
	var status_fmt := tr(status_key)
	var status_text: String
	if status_fmt != status_key and status_fmt.contains("%s") and status_fmt.contains("%d"):
		status_text = status_fmt % [stem_norm, state.note_count()]
	else:
		status_text = "Opened %s — %d notes — %s" % [stem_norm, state.note_count(), "CANONICAL" if state.is_canonical else "Derived"]
	_set_status(status_text, false)
	var _t_first_draw := PerfTrace.begin("perf.detail.chart_editor.first_draw")
	await RenderingServer.frame_post_draw
	PerfTrace.end("perf.detail.chart_editor.first_draw", _t_first_draw)
	PerfTrace.end("perf.load.chart_editor.chart", _t_open)
	PerfTrace.end("perf.load.chart_editor.open_total", _t_open_total)

func _check_recovery_and_handle() -> bool:
	# Returns true if recovery dialog was shown and handled (state may have been modified)
	if state == null:
		return false
	var temp_path := _get_temp_path_for_current()
	if temp_path == "":
		return false
	var abs_temp := DirectoryUtils.to_absolute(temp_path)
	if not FileAccess.file_exists(abs_temp):
		return false
	var payload := RfTempCodec.read_file(temp_path)
	var valid_err := RfTempCodec.validate_payload(payload)
	var is_corrupted := valid_err != ""
	var is_deleted_source := false
	var is_mismatch := false
	var source_path: String = ""
	var source_hash: String = ""
	if not is_corrupted:
		var src: Dictionary = payload.get("source", {}) as Dictionary
		source_path = String(src.get("path", ""))
		source_hash = String(src.get("hash", ""))
		if source_path != "":
			var abs_src := DirectoryUtils.to_absolute(source_path)
			if not FileAccess.file_exists(abs_src):
				is_deleted_source = true
			else:
				# Check hash mismatch: load current source file's notes and compare hash
				var cur_source_notes: Array = []
				if state.is_corrected:
					cur_source_notes = NotesUtils.load_notes_array(state.song_path, state.instrument, state.base_stem, state.lanes)
				else:
					# Generated source is the same file being edited (version 0)
					cur_source_notes = NotesUtils.load_notes_array(state.song_path, state.instrument, state.base_stem, state.lanes)
				if not cur_source_notes.is_empty():
					var cur_hash := RfcCorrectionsCodec._hash_notes(cur_source_notes)
					if cur_hash != source_hash:
						is_mismatch = true
	var title := ""
	var msg := ""
	var ok_text := tr("CHART_EDITOR_RECOVERY_RESTORE") if tr("CHART_EDITOR_RECOVERY_RESTORE") != "CHART_EDITOR_RECOVERY_RESTORE" else "Restore"
	var cancel_text := tr("CHART_EDITOR_RECOVERY_DELETE") if tr("CHART_EDITOR_RECOVERY_DELETE") != "CHART_EDITOR_RECOVERY_DELETE" else "Delete temp"
	var extra_text := tr("CHART_EDITOR_RECOVERY_OPEN_SAVED") if tr("CHART_EDITOR_RECOVERY_OPEN_SAVED") != "CHART_EDITOR_RECOVERY_OPEN_SAVED" else "Open saved"
	if is_corrupted:
		title = tr("CHART_EDITOR_RECOVERY_CORRUPTED_TITLE") if tr("CHART_EDITOR_RECOVERY_CORRUPTED_TITLE") != "CHART_EDITOR_RECOVERY_CORRUPTED_TITLE" else "Recovery corrupted"
		msg = tr("CHART_EDITOR_RECOVERY_CORRUPTED_MSG") if tr("CHART_EDITOR_RECOVERY_CORRUPTED_MSG") != "CHART_EDITOR_RECOVERY_CORRUPTED_MSG" else "Temp file is corrupted (hash/format error: %s). Delete or open saved version." % valid_err
		ok_text = tr("CHART_EDITOR_RECOVERY_DELETE") if tr("CHART_EDITOR_RECOVERY_DELETE") != "CHART_EDITOR_RECOVERY_DELETE" else "Delete temp"
		extra_text = tr("CHART_EDITOR_RECOVERY_OPEN_SAVED") if tr("CHART_EDITOR_RECOVERY_OPEN_SAVED") != "CHART_EDITOR_RECOVERY_OPEN_SAVED" else "Open saved"
	elif is_deleted_source:
		title = tr("CHART_EDITOR_RECOVERY_DELETED_SOURCE_TITLE") if tr("CHART_EDITOR_RECOVERY_DELETED_SOURCE_TITLE") != "CHART_EDITOR_RECOVERY_DELETED_SOURCE_TITLE" else "Source deleted"
		msg = tr("CHART_EDITOR_RECOVERY_DELETED_SOURCE_MSG") if tr("CHART_EDITOR_RECOVERY_DELETED_SOURCE_MSG") != "CHART_EDITOR_RECOVERY_DELETED_SOURCE_MSG" else "Source file %s not found. Restore temp as standalone? (Save As to create new chart)" % source_path.get_file()
		ok_text = tr("CHART_EDITOR_RECOVERY_RESTORE_STANDALONE") if tr("CHART_EDITOR_RECOVERY_RESTORE_STANDALONE") != "CHART_EDITOR_RECOVERY_RESTORE_STANDALONE" else "Restore as standalone"
	elif is_mismatch:
		title = tr("CHART_EDITOR_RECOVERY_MISMATCH_TITLE") if tr("CHART_EDITOR_RECOVERY_MISMATCH_TITLE") != "CHART_EDITOR_RECOVERY_MISMATCH_TITLE" else "Source changed"
		msg = tr("CHART_EDITOR_RECOVERY_MISMATCH_MSG") if tr("CHART_EDITOR_RECOVERY_MISMATCH_MSG") != "CHART_EDITOR_RECOVERY_MISMATCH_MSG" else "Temp source hash %s != current %s. Restore anyway?" % [source_hash, "current"]
		ok_text = tr("CHART_EDITOR_RECOVERY_RESTORE_ANYWAY") if tr("CHART_EDITOR_RECOVERY_RESTORE_ANYWAY") != "CHART_EDITOR_RECOVERY_RESTORE_ANYWAY" else "Restore anyway"
	else:
		title = tr("CHART_EDITOR_RECOVERY_TITLE") if tr("CHART_EDITOR_RECOVERY_TITLE") != "CHART_EDITOR_RECOVERY_TITLE" else "Recovery found"
		var saved_at := String(payload.get("recovery", {}).get("saved_at", payload.get("updated_at", "")))
		var notes_cnt := int(payload.get("current", {}).get("notes_count", payload.get("notes", []).size()))
		msg = tr("CHART_EDITOR_RECOVERY_MSG") % [temp_path.get_file(), saved_at, notes_cnt] if tr("CHART_EDITOR_RECOVERY_MSG") != "CHART_EDITOR_RECOVERY_MSG" else "Found recovery snapshot %s at %s (%d notes). Restore?" % [temp_path.get_file(), saved_at, notes_cnt]
	var choice_overlay := _ensure_choice_overlay(self)
	if choice_overlay == null:
		return false
	choice_overlay.show_choice(title, msg, "warning", ok_text, cancel_text, extra_text)
	var choice: String = await choice_overlay.finished
	if choice == "confirm":
		# Restore
		if is_corrupted:
			# For corrupted, confirm means Delete
			RfTempCodec.delete_temp(temp_path)
			_set_status("Deleted corrupted temp", false)
			return true
		var notes: Array = payload.get("notes", []) as Array
		if notes.is_empty():
			_set_status("Restore failed: temp has no notes", true)
			return true
		state.document.set_notes(notes)
		state.clear_selection()
		# Do not restore Undo/Redo, selection, tool, zoom
		undo_stack.clear()
		# Keep temp until next successful Save (do not delete now)
		state.mark_dirty()
		_last_autosave_hash = "" # Force next autosave to be considered changed
		_refresh_ui()
		_set_status("Restored from temp (%d notes)" % notes.size(), false)
		if is_deleted_source:
			_set_status("Restored as standalone — use Save As", false)
		return true
	elif choice == "extra":
		# Open saved version — ignore temp, continue with saved file
		return true
	else: # cancel = Delete temp
		RfTempCodec.delete_temp(temp_path)
		_set_status("Deleted temp", false)
		return true

func _refresh_ui() -> void:
	if _playfield:
		if _playfield.has_method("set_editor_state"):
			_playfield.set_editor_state(state)
		_playfield.queue_redraw()
	if _overlay:
		_overlay.queue_redraw()
	if _inspector and _inspector.has_method("refresh"):
		# Ensure inspector has correct undo_stack for Changes count
		if _inspector.has_method("set_undo_stack") and undo_stack:
			_inspector.set_undo_stack(undo_stack)
		_inspector.refresh()
		if _inspector.has_method("update_timeline") and state:
			_inspector.update_timeline(state.song_time)
	if _top_label and state:
		var actual_path := NotesUtils.notes_path_by_song(state.song_path, state.instrument, state.chart_stem, state.lanes, "")
		var actual_file := actual_path.get_file() if actual_path != "" else state.chart_stem
		# Показываем фактический resolved chart variant, не внутренний stems
		var display_stem := state.chart_stem
		if display_stem == "stems":
			display_stem = "arcade_medium"
		var song_file := String(state.song_path.get_file())
		# Если song_path уже является .rf, показываем его напрямую
		if song_file.ends_with(".rf") or song_file.ends_with(".rfd"):
			song_file = actual_file if actual_file != "" else song_file
		var title := "%s — %s" % [song_file, display_stem]
		_top_label.text = title
	if _canonical_label and state:
		if state.is_canonical:
			_canonical_label.text = tr("CHART_EDITOR_BADGE_CANONICAL")
			_canonical_label.modulate = Color(0.35, 0.95, 0.65, 1.0)
		else:
			_canonical_label.text = tr("CHART_EDITOR_BADGE_DERIVED")
			_canonical_label.modulate = Color(0.75, 0.80, 0.90, 0.85)
		_canonical_label.visible = true
	if _undo_btn and undo_stack:
		_undo_btn.disabled = not undo_stack.can_undo()
	if _redo_btn and undo_stack:
		_redo_btn.disabled = not undo_stack.can_redo()
	if _save_btn and state:
		_save_btn.disabled = not state.is_dirty
	if _save_as_btn and state:
		# Save As enabled when document exists (even if not dirty, can duplicate current version)
		_save_as_btn.disabled = state.document == null or state.document.notes.is_empty()
		# Update text to show next version
		var next_ver = RfcCorrectionsCodec.next_free_version(state.song_path, state.instrument, state.base_stem)
		if next_ver <= state.version:
			next_ver = state.version + 1
		var next_name = RfcCorrectionsCodec.version_name(next_ver)
		if next_name != "":
			var cur_name := RfcCorrectionsCodec.version_name(state.version) if state.version > 0 else "v0"
			_save_as_btn.text = "%s → %s" % [cur_name, next_name]
			if state.version == 0:
				_save_as_btn.text = "Сохранить как %s" % next_name
		else:
			_save_as_btn.text = tr("CHART_EDITOR_ACTION_SAVE_AS") if tr("CHART_EDITOR_ACTION_SAVE_AS") != "CHART_EDITOR_ACTION_SAVE_AS" else "Сохранить как v+1"
	if _revert_btn and state:
		# Enable if source exists
		var src_rel := ChartEditorCorrectionsClass.source_path_for(state.song_path, state.chart_stem)
		_revert_btn.disabled = not FileAccess.file_exists(DirectoryUtils.to_absolute(src_rel))
	_update_bottom_labels()
	# Sync active drum to selection (if single selection)
	if state and state.has_selection() and state.selected_keys.size() == 1:
		var key := state.primary_key
		for n in state.document.notes:
			if EditorNoteUtilsClass.note_key(n as Dictionary) == key:
				_active_drum = String(n.get("drum", _active_drum)).to_lower()
				break
	_refresh_drum_palette()
	if _ruler:
		_ruler.queue_redraw()

func _set_status(text: String, is_error: bool) -> void:
	if _status_label:
		_status_label.text = text
		_status_label.modulate = Color(1, 0.45, 0.45, 1.0) if is_error else Color(0.72, 0.82, 0.95, 1.0)
	else:
		print("[ChartEditor] %s" % text)

# --- Input: playfield signals ---

func _on_playfield_note_clicked(key: String, _event: InputEvent) -> void:
	# Handled in playfield drag logic; selection already updated.
	_refresh_ui()

func _on_selection_changed() -> void:
	_refresh_ui()

func _on_box_selected(keys: Array, additive: bool) -> void:
	if state == null:
		return
	if additive:
		state.toggle_selection(keys)
	else:
		state.select_only(keys)
	_refresh_ui()

func _on_selection_cleared() -> void:
	_UiModifierSounds.play_deselect()
	if state:
		state.clear_selection()
	_refresh_ui()

func _on_notes_dragged(keys: Array, delta_t: float, delta_lane: int, snap_div: int) -> void:
	if state == null or keys.is_empty():
		return
	if absf(delta_t) < 1e-5 and delta_lane == 0:
		return
	var cmd := ChartEditorCommands.MoveNotesCommand.new(keys, delta_t, delta_lane, snap_div if state.snap_enabled else 0)
	var err := undo_stack.push_and_do(cmd, state)
	if err != "":
		_set_status("Move failed: %s" % err, true)
		return
	state.mark_dirty()
	# Record correction: move
	_record_corrections_for_move(keys, delta_t, delta_lane, snap_div)
	_refresh_ui()

func _on_add_requested(time: float, lane: int) -> void:
	if MIDI_BROWSER_DIAGNOSTICS and _pattern_drag_active:
		print("[RF_DIAG] !!! PENCIL CONFLICT DURING MIDI DRAG !!! pattern_drag_active=true current_tool=%s left_split_dragging=%s is_midi=%s" % [_current_tool, str(_left_split_dragging), str(_palette_mode == "midi")])
	if MIDI_BROWSER_DIAGNOSTICS:
		print("[RF_DIAG] NOTE ADD REQUEST pattern_drag_active=%s left_split_dragging=%s is_midi=%s time=%s lane=%s" % [str(_pattern_drag_active), str(_left_split_dragging), str(_palette_mode == "midi"), str(time), str(lane)])
	if state == null:
		return
	var use_drum := _active_drum if _active_drum != "" else "kick"
	# Mouse hold guard: prevent paint spam if LMB still held from previous add
	var now_msec := Time.get_ticks_msec()
	if now_msec - _last_lmb_press_msec < 80:
		# Too soon after previous add (likely hold) — ignore to enforce one action per press
		# Still return focus
		_return_focus_to_editor()
		return
	_last_lmb_press_msec = now_msec
	var cmd := ChartEditorCommands.AddNoteCommand.new(time, lane, use_drum)
	var err := undo_stack.push_and_do(cmd, state)
	if err != "":
		_set_status("Add failed: %s" % err, true)
		return
	state.mark_dirty()
	var key := cmd.added_key
	if state.corrections:
		state.corrections.record_action("add", {"to": {"time": time, "lane": lane, "drum": use_drum}, "key": key})
	_refresh_ui()
	_play_hit_feedback(use_drum)
	_return_focus_to_editor()

func _on_notes_deleted(keys: Array) -> void:
	if state == null or keys.is_empty():
		return
	# Determine logical action label for debug
	var logical := "delete"
	if keys.size() == 1:
		logical = "delete_single"
	else:
		logical = "delete_multi_%d" % keys.size()
	# Also detect if this was pencil delete vs keyboard: caller context is overlay or inspector
	var cmd := ChartEditorCommands.DeleteNotesCommand.new(keys)
	var err := undo_stack.push_and_do(cmd, state)
	if err != "":
		_set_status("Delete failed: %s" % err, true)
		return
	state.mark_dirty()
	if state.corrections:
		for k in keys:
			state.corrections.record_action("delete", {"target": {"key": k}})
	_refresh_ui()
	_play_delete_feedback(logical)
	_return_focus_to_editor()

# --- Inspector ---

func _on_inspector_drum_changed(new_drum: String) -> void:
	var sanitized := EditorNoteUtilsClass.sanitize_drum(new_drum)
	if _active_drum == sanitized:
		return
	_UiModifierSounds.play_select()
	_active_drum = sanitized
	_refresh_drum_palette()
	if state == null or not state.has_selection():
		if _inspector and _inspector.has_method("refresh"):
			_inspector.refresh()
		_return_focus_to_editor()
		return
	var keys: Array = []
	for k in state.selected_keys.keys():
		keys.append(k)
	var cmd := ChartEditorCommands.ReclassNotesCommand.new(keys, _active_drum)
	var err := undo_stack.push_and_do(cmd, state)
	if err != "":
		_set_status("Reclass failed: %s" % err, true)
		return
	state.mark_dirty()
	if state.corrections:
		state.corrections.record_action("reclass", {"keys": keys, "to_drum": _active_drum})
	_refresh_ui()
	_return_focus_to_editor()

func _on_inspector_quantize(division: int) -> void:
	if state == null or not state.has_selection():
		return
	_UiModifierSounds.play_select()
	var keys: Array = []
	for k in state.selected_keys.keys():
		keys.append(k)
	var cmd := ChartEditorCommands.QuantizeNotesCommand.new(keys, division)
	var err := undo_stack.push_and_do(cmd, state)
	if err != "":
		_set_status("Quantize failed: %s" % err, true)
		_StatusToast.show_from_node(self, "chart_editor_quantize", "Quantize failed: %s" % err, "error", 2.5)
		return
	state.mark_dirty()
	if state.corrections:
		state.corrections.record_action("quantize", {"keys": keys, "division": division})
	_StatusToast.show_from_node(self, "chart_editor_quantize", tr("CHART_EDITOR_NOTIFY_QUANTIZED"), "success", 2.5)
	_refresh_ui()
	_return_focus_to_editor()

func _on_inspector_delete() -> void:
	if state == null or not state.has_selection():
		return
	var keys: Array = []
	for k in state.selected_keys.keys():
		keys.append(k)
	_on_notes_deleted(keys)

func _on_hit_effects_toggled(enabled: bool) -> void:
	_UiModifierSounds.play_toggle(enabled)
	if SettingsManager and SettingsManager.has_method("set_chart_editor_hit_effects_enabled"):
		SettingsManager.set_chart_editor_hit_effects_enabled(enabled)
	if _playfield and _playfield.has_method("set_hit_effects_enabled"):
		_playfield.set_hit_effects_enabled(enabled)
	_return_focus_to_editor()

func _on_hide_after_hit_toggled(enabled: bool) -> void:
	_UiModifierSounds.play_toggle(enabled)
	if SettingsManager and SettingsManager.has_method("set_chart_editor_hide_notes_after_hit"):
		SettingsManager.set_chart_editor_hide_notes_after_hit(enabled)
	if not enabled:
		_hit_hidden_keys.clear()
		if _playfield and _playfield.has_method("set_hidden_keys"):
			_playfield.set_hidden_keys(_hit_hidden_keys)
		if _playfield:
			_playfield.queue_redraw()
	else:
		# when enabling, clear previous hidden to start fresh
		_hit_hidden_keys.clear()
		if _playfield and _playfield.has_method("set_hidden_keys"):
			_playfield.set_hidden_keys(_hit_hidden_keys)
	_return_focus_to_editor()

func _on_note_color_mode_changed(mode: int) -> void:
	_UiModifierSounds.play_select()
	if SettingsManager and SettingsManager.has_method("set_chart_editor_note_color_mode"):
		SettingsManager.set_chart_editor_note_color_mode(mode)
	if _playfield and _playfield.has_method("set_note_color_mode"):
		_playfield.set_note_color_mode(mode)
	_update_shop_visuals()
	_return_focus_to_editor()

func _on_lane_highlight_toggled(enabled: bool) -> void:
	_UiModifierSounds.play_toggle(enabled)
	if SettingsManager and SettingsManager.has_method("set_replay_hide_option"):
		SettingsManager.set_replay_hide_option("lane_highlights", not enabled)
	elif SettingsManager and SettingsManager.has_method("set_lane_highlight_brightness"):
		SettingsManager.set_lane_highlight_brightness(100.0 if enabled else 0.0)
	# Apply to playfield immediately
	if _playfield and _playfield.has_method("set_lane_highlight_enabled"):
		_playfield.set_lane_highlight_enabled(enabled)
	elif _playfield and _playfield.has_method("_update_lane_highlight_flash"):
		# Fallback: if lane highlight disabled, hide all highlights
		if not enabled and _playfield.has_node("LanesContainer"):
			var lc = _playfield.get_node_or_null("LanesContainer")
			if lc:
				for i in range(_playfield.lanes if "lanes" in _playfield else 5):
					var hl = lc.get_node_or_null("Lane%dHighlight" % i) as ColorRect
					if hl:
						hl.visible = false
		_playfield.queue_redraw()
	_return_focus_to_editor()

func _update_shop_visuals() -> void:
	if _playfield == null or not is_instance_valid(_playfield):
		return
	# Note colors — reuse shop "Notes" category (player-selected)
	var note_colors: Array[Color] = []
	if PlayerDataManager and PlayerDataManager.has_method("get_active_item"):
		var nid := String(PlayerDataManager.get_active_item("Notes"))
		if nid != "":
			var item := {}
			# Find item data via HitParticlePresets helper or shop_data
			if HitParticlePresets:
				item = HitParticlePresets.find_item_data(nid)
			if item.is_empty():
				# fallback: try shop_data directly
				var sd := JsonUtils.read_json_dict("user://shop_data.json")
				if sd.is_empty():
					sd = JsonUtils.read_json_dict("res://data/shop_data.json")
				for it in sd.get("items", []):
					if it is Dictionary and String(it.get("item_id","")) == nid:
						item = it
						break
			var arr = item.get("note_colors", [])
			if arr is Array:
				for hx in arr:
					var s := String(hx).strip_edges()
					if s != "":
						note_colors.append(Color(s))
	# If no shop colors, leave empty (playfield will fallback to drum colors)
	if _playfield.has_method("set_lane_colors_cache"):
		_playfield.set_lane_colors_cache(note_colors)
	# Lane highlight color — reuse shop "LaneHighlight"
	if PlayerDataManager and PlayerDataManager.has_method("get_active_item"):
		var lid := String(PlayerDataManager.get_active_item("LaneHighlight"))
		if lid != "" and _playfield.has_method("_update_lane_highlight_flash"):
			# _update_lane_highlight_flash uses highlight nodes; set their base color via lane_highlight_nodes
			var lh_item := {}
			if HitParticlePresets:
				lh_item = HitParticlePresets.find_item_data(lid)
			if lh_item.is_empty():
				var sd2 := JsonUtils.read_json_dict("user://shop_data.json")
				if sd2.is_empty():
					sd2 = JsonUtils.read_json_dict("res://data/shop_data.json")
				for it2 in sd2.get("items", []):
					if it2 is Dictionary and String(it2.get("item_id","")) == lid:
						lh_item = it2
						break
			var hex := String(lh_item.get("color_hex", "#fec6e580"))
			if hex != "":
				var col := Color(hex)
				# Apply brightness from SettingsManager
				var bright := 100.0
				if SettingsManager and SettingsManager.has_method("get_lane_highlight_brightness"):
					bright = SettingsManager.get_lane_highlight_brightness()
				col = Color(col.r, col.g, col.b, col.a * (bright / 100.0))
				# Directly set highlight nodes colors
				if _playfield.has_method("get_lane_highlight_nodes") or _playfield.has_node("LanesContainer"):
					var lc = _playfield.get_node_or_null("LanesContainer")
					if lc:
						for i in range(_playfield.lanes if "lanes" in _playfield else 5):
							var hl = lc.get_node_or_null("Lane%dHighlight" % i) as ColorRect
							if hl:
								hl.color = col
	# Apply note color mode and hit effects toggle to playfield
	if SettingsManager:
		if _playfield.has_method("set_note_color_mode") and SettingsManager.has_method("get_chart_editor_note_color_mode"):
			_playfield.set_note_color_mode(SettingsManager.get_chart_editor_note_color_mode())
		if _playfield.has_method("set_hit_effects_enabled") and SettingsManager.has_method("get_chart_editor_hit_effects_enabled"):
			_playfield.set_hit_effects_enabled(SettingsManager.get_chart_editor_hit_effects_enabled())
		if _playfield.has_method("set_hidden_keys"):
			_playfield.set_hidden_keys(_hit_hidden_keys)

func _on_copy() -> void:
	if state == null or not state.has_selection():
		return
	var sel: Array = state.selected_notes()
	state.clipboard = EditorNoteUtilsClass.clone_notes(sel)
	if state.clipboard.is_empty():
		return
	var min_t := 1e9
	for n in state.clipboard:
		min_t = minf(min_t, float(n.get("time", 0.0)))
	state.clipboard_min_time = min_t if min_t < 1e9 else 0.0
	_set_status("Copied %d notes" % state.clipboard.size(), false)

func _on_paste() -> void:
	if state == null or state.clipboard.is_empty():
		_set_status("Clipboard empty", true)
		return
	var at := state.song_time
	var cmd := ChartEditorCommands.PasteNotesCommand.new(state.clipboard, at)
	var err := undo_stack.push_and_do(cmd, state)
	if err != "":
		_set_status("Paste failed: %s" % err, true)
		return
	state.mark_dirty()
	if state.corrections:
		state.corrections.record_action("paste", {"count": state.clipboard.size(), "at": at})
	_refresh_ui()

func _on_duplicate() -> void:
	if state == null or not state.has_selection():
		return
	var keys: Array = []
	for k in state.selected_keys.keys():
		keys.append(k)
	var cmd := ChartEditorCommands.DuplicateNotesCommand.new(keys)
	var err := undo_stack.push_and_do(cmd, state)
	if err != "":
		_set_status("Duplicate failed: %s" % err, true)
		return
	state.mark_dirty()
	if state.corrections:
		state.corrections.record_action("duplicate", {"keys": keys, "count": keys.size()})
	_refresh_ui()

func _on_select_all() -> void:
	if state == null or state.document == null:
		return
	var all_keys: Array = []
	for n in state.document.notes:
		all_keys.append(EditorNoteUtils.note_key(n as Dictionary))
	if all_keys.is_empty():
		return
	_UiModifierSounds.play_select()
	state.select_only(all_keys)
	_refresh_ui()

func _on_quantize_hotkey() -> void:
	if state == null or not state.has_selection():
		return
	var div := state.snap_division
	if div <= 0:
		return
	_on_inspector_quantize(div)

func _reset_hit_tracking(to_time: float = -1.0) -> void:
	_hit_sound_cooldown.clear()
	_hit_hidden_keys.clear()
	_hit_effect_cooldown.clear()
	if to_time >= 0.0:
		_prev_song_time = to_time
	elif state:
		_prev_song_time = state.song_time
	if _playfield and _playfield.has_method("set_hidden_keys"):
		_playfield.set_hidden_keys(_hit_hidden_keys)
	if _playfield and _playfield.has_method("clear_lane_highlights"):
		_playfield.clear_lane_highlights()
	if _playfield:
		_playfield.queue_redraw()

func _go_to_time(t: float) -> void:
	if state == null:
		return
	var was_playing := player and player.is_playing()
	var clamped := clampf(t, 0.0, state.duration_s if state.duration_s > 0.0 else 9999.0)
	state.song_time = clamped
	_reset_hit_tracking(clamped)
	if _playfield:
		_playfield.queue_redraw()
	if _overlay:
		_overlay.queue_redraw()
	if _ruler:
		_ruler.queue_redraw()
	# Seek without changing play/pause state (invariant)
	if was_playing and player:
		player.seek(clamped)
	elif player:
		player.seek(clamped)
		# Ensure still paused after seek
		if not was_playing and player.is_playing():
			player.pause()
			state.is_playing = false
			if _play_btn:
				UiIconHelper.configure_button_icon(_play_btn, "play.svg", UiIconHelper.ACCENT, 16)

func _go_to_prev_beat() -> void:
	if state == null or state.grid == null:
		return
	var t := state.song_time
	var prev := -1.0
	# Find beat strictly before current (with epsilon)
	for b in state.grid.beats:
		if b < t - 0.001:
			prev = b
		elif b >= t - 0.001:
			break
	if prev < 0.0:
		# Fallback: step back by beat_interval
		prev = maxf(0.0, t - state.grid.beat_interval)
		if state.grid.snap_time(prev, state.snap_division) == t:
			prev = maxf(0.0, t - state.grid.beat_interval)
	# Snap to grid
	if state.snap_enabled and state.grid:
		prev = state.grid.snap_time(prev, state.snap_division) if prev > 0.0 else 0.0
	_go_to_time(prev)

func _go_to_next_beat() -> void:
	if state == null or state.grid == null:
		return
	var t := state.song_time
	var nxt := -1.0
	for b in state.grid.beats:
		if b > t + 0.001:
			nxt = b
			break
	if nxt < 0.0:
		nxt = minf(state.duration_s, t + state.grid.beat_interval)
	# Snap
	if state.snap_enabled and state.grid:
		nxt = state.grid.snap_time(nxt, state.snap_division)
		if absf(nxt - t) < 0.001:
			nxt = minf(state.duration_s, t + state.grid.beat_interval)
	_go_to_time(nxt)

func _go_to_prev_measure() -> void:
	if state == null or state.grid == null:
		return
	var t := state.song_time
	var cur_m := state.grid.measure_index(t)
	var target := state.grid.measure_start_time(cur_m - 1) if t > state.grid.measure_start_time(cur_m) + 0.001 else state.grid.measure_start_time(cur_m - 1)
	# If we are exactly on measure start, go to previous measure
	if absf(t - state.grid.measure_start_time(cur_m)) < 0.001:
		target = state.grid.measure_start_time(cur_m - 1)
	else:
		# If inside measure, go to current measure start
		var cur_start := state.grid.measure_start_time(cur_m)
		if t > cur_start + 0.001:
			target = cur_start
		else:
			target = state.grid.measure_start_time(cur_m - 1)
	target = clampf(target, 0.0, state.duration_s)
	_go_to_time(target)

func _go_to_next_measure() -> void:
	if state == null or state.grid == null:
		return
	var t := state.song_time
	var cur_m := state.grid.measure_index(t)
	var nxt := state.grid.measure_start_time(cur_m + 1)
	if nxt <= t + 0.001:
		nxt = state.grid.measure_start_time(cur_m + 1)
	nxt = clampf(nxt, 0.0, state.duration_s)
	_go_to_time(nxt)

func _is_editor_action(event: InputEventKey, action: String) -> bool:
	if SettingsManager == null:
		return false
	var km := SettingsManager.get_chart_editor_keymap()
	var bindings: Array = km.get(action, [])
	if bindings is Array:
		for b in bindings:
			if b is Dictionary and ChartEditorBindings.matches_event(b, event):
				return true
	return false

func _record_corrections_for_move(keys: Array, delta_t: float, delta_lane: int, snap_div: int) -> void:
	if state == null or state.corrections == null:
		return
	state.corrections.record_action("move", {"keys": keys, "delta_t": delta_t, "delta_lane": delta_lane, "snap": snap_div})

func _find_any_existing_stem(song_path: String, instrument: String, lanes: int) -> String:
	var _t_find := PerfTrace.begin("perf.detail.chart_editor.find_stem")
	# Ищем любой стем, который реально есть на диске (включая unified)
	var candidates: Array[String] = []
	candidates.append("arcade_medium")
	var _t_all := PerfTrace.begin("perf.detail.chart_editor.all_stems")
	for s in GenerationGoalDifficulty.all_stems():
		if not candidates.has(s):
			candidates.append(s)
	PerfTrace.end("perf.detail.chart_editor.all_stems", _t_all)
	# Легаси алиасы тоже
	for alias in ["basic", "enhanced", "original", "arcade_easy", "arcade_hard"]:
		if not candidates.has(alias):
			candidates.append(alias)
	for stem in candidates:
		var _t_ne := PerfTrace.begin("perf.detail.chart_editor.notes_exist")
		var exists := NotesUtils.notes_exist(song_path, instrument, stem, lanes)
		PerfTrace.end("perf.detail.chart_editor.notes_exist", _t_ne)
		if exists:
			PerfTrace.end("perf.detail.chart_editor.find_stem", _t_find)
			return stem
		var _t_ru := PerfTrace.begin("perf.detail.chart_editor.resolve_unified")
		var uni := NotesUtils.resolve_unified_mode_path(song_path, instrument, stem) != ""
		PerfTrace.end("perf.detail.chart_editor.resolve_unified", _t_ru)
		if uni:
			PerfTrace.end("perf.detail.chart_editor.find_stem", _t_find)
			return stem
		# Пробуем без учета lanes (универсально)
		for l in [3,4,5]:
			if l == lanes:
				continue
			var _t_ne2 := PerfTrace.begin("perf.detail.chart_editor.notes_exist")
			var exists2 := NotesUtils.notes_exist(song_path, instrument, stem, l)
			PerfTrace.end("perf.detail.chart_editor.notes_exist", _t_ne2)
			if exists2:
				PerfTrace.end("perf.detail.chart_editor.find_stem", _t_find)
				return stem
	PerfTrace.end("perf.detail.chart_editor.find_stem", _t_find)
	return ""

# --- Snap / Zoom ---

func _on_snap_toggled(enabled: bool) -> void:
	if state:
		# Snap enabled is master toggle; Off division also disables regardless
		if not enabled:
			state.snap_enabled = false
		else:
			# Re-enable only if division !=0
			if state.snap_division == 0:
				# If was Off, switch to default 16
				state.snap_division = 16
				_select_snap_division(16)
			state.snap_enabled = state.snap_division != 0
		_set_status("Snap %s" % ("ON" if state.snap_enabled else "OFF"), false)
		if _playfield:
			_playfield.queue_redraw()
		if _ruler:
			_ruler.queue_redraw()
	_return_focus_to_editor()

func _on_snap_division_selected(index: int) -> void:
	if _snap_option == null or state == null:
		return
	# Source of truth: id holds division (0=Off,1,2,4,8,16,32) as defined in chart_editor.tscn.
	var div := int(_snap_option.get_item_id(index)) if index >= 0 and index < _snap_option.item_count else 16
	# Handle Off and 1,1/2
	if div == 0:
		state.snap_division = 0
		state.snap_enabled = false
		if _snap_check:
			_snap_check.set_block_signals(true)
			_snap_check.button_pressed = false
			_snap_check.set_block_signals(false)
		_set_status("Snap OFF", false)
	else:
		state.snap_division = div
		# Auto-enable snap when choosing a division
		state.snap_enabled = true
		if _snap_check:
			_snap_check.set_block_signals(true)
			_snap_check.button_pressed = true
			_snap_check.set_block_signals(false)
		if div == 1:
			_set_status("Snap 1", false)
		elif div == 2:
			_set_status("Snap 1/2", false)
		else:
			_set_status("Snap 1/%d" % div, false)
	_refresh_ui()
	if _playfield:
		_playfield.queue_redraw()
	if _ruler:
		_ruler.queue_redraw()
	_return_focus_to_editor()

func _select_snap_division(div: int) -> void:
	if _snap_option == null:
		return
	# Primary via item id (tscn defines id = division). Fallback to text parse.
	for i in range(_snap_option.item_count):
		if int(_snap_option.get_item_id(i)) == div:
			_snap_option.select(i)
			return
	# Text fallback for legacy/metadata path (defensive)
	for i in range(_snap_option.item_count):
		var txt := _snap_option.get_item_text(i)
		if div == 0 and txt.to_lower() in ["off", "выкл"]:
			_snap_option.select(i)
			return
		if "/" in txt:
			var parts := txt.split("/")
			if parts.size() > 1 and String(parts[1]).is_valid_int() and int(parts[1]) == div:
				_snap_option.select(i)
				return
		elif txt == "1" and div == 1:
			_snap_option.select(i)
			return
		elif txt == "1/2" and div == 2:
			_snap_option.select(i)
			return
	# Fallback: Off
	if div == 0:
		_snap_option.select(0)

func _on_zoom_changed(value: float) -> void:
	if state:
		state.px_per_sec = clampf(value, 180.0, 720.0)
		if _playfield and _playfield is GamePlayfield:
			_playfield.set_speed(state.px_per_sec / 60.0)
			_playfield.queue_redraw()
		if _overlay:
			_overlay.queue_redraw()
		_update_bottom_labels()
	if _ruler:
		_ruler.queue_redraw()
	_return_focus_to_editor()

func _on_zoom_slider_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
		_on_zoom_changed(360.0)
		if _zoom_slider:
			_zoom_slider.value = 360.0
		get_viewport().set_input_as_handled()

func _on_audio_source_selected(index: int) -> void:
	var src := "original" if index == 0 else "drums"
	_set_audio_source(src)
	_return_focus_to_editor()

func _set_audio_source(source: String) -> void:
	if player == null or state == null:
		return
	var prev := player.get_active_source()
	var cur := player.set_audio_source(source)
	_refresh_audio_source_ui()
	if cur != prev:
		var key := "CHART_EDITOR_AUDIO_SOURCE_DRUMS" if cur == "drums" else "CHART_EDITOR_AUDIO_SOURCE_ORIGINAL"
		var txt := tr(key) if tr(key) != key else (cur.capitalize())
		_set_status("Audio: %s" % txt, false)

func _toggle_audio_source() -> void:
	if player == null or not player.has_stem():
		_set_status(tr("CHART_EDITOR_AUDIO_SOURCE_MISSING") if tr("CHART_EDITOR_AUDIO_SOURCE_MISSING") != "CHART_EDITOR_AUDIO_SOURCE_MISSING" else "Drum stem not available", true)
		return
	var cur := player.toggle_audio_source()
	_refresh_audio_source_ui()
	var key := "CHART_EDITOR_AUDIO_SOURCE_DRUMS" if cur == "drums" else "CHART_EDITOR_AUDIO_SOURCE_ORIGINAL"
	var txt := tr(key) if tr(key) != key else cur.capitalize()
	_set_status("Audio: %s" % txt, false)
	_return_focus_to_editor()

func _refresh_audio_source_ui() -> void:
	if _audio_source_option == null or player == null:
		return
	var has_stem := player.has_stem()
	_audio_source_option.set_item_disabled(1, not has_stem)
	if has_stem:
		_audio_source_option.tooltip_text = tr("CHART_EDITOR_AUDIO_SOURCE_TOOLTIP_DRUMS") if tr("CHART_EDITOR_AUDIO_SOURCE_TOOLTIP_DRUMS") != "CHART_EDITOR_AUDIO_SOURCE_TOOLTIP_DRUMS" else "Play drums stem if available"
		var cur := player.get_active_source()
		_audio_source_option.select(1 if cur == "drums" else 0)
	else:
		_audio_source_option.tooltip_text = tr("CHART_EDITOR_AUDIO_SOURCE_MISSING") if tr("CHART_EDITOR_AUDIO_SOURCE_MISSING") != "CHART_EDITOR_AUDIO_SOURCE_MISSING" else "Drum stem not available — using mix"
		_audio_source_option.select(0)
	var lbl := get_node_or_null("BottomBar/BottomHBox/AudioSourceLabel") as Label
	if lbl:
		var t := tr("CHART_EDITOR_AUDIO_SOURCE")
		lbl.text = t if t != "CHART_EDITOR_AUDIO_SOURCE" and t != "" else "Источник"

# --- Undo/Redo ---

func _on_undo_pressed() -> void:
	if state == null or undo_stack == null:
		return
	var err := undo_stack.undo(state)
	if err != "":
		_set_status(err, true)
		return
	state.is_dirty = undo_stack.is_dirty()
	_refresh_ui()
	_return_focus_to_editor()

func _on_redo_pressed() -> void:
	if state == null or undo_stack == null:
		return
	var err := undo_stack.redo(state)
	if err != "":
		_set_status(err, true)
		return
	state.is_dirty = undo_stack.is_dirty()
	_refresh_ui()
	_return_focus_to_editor()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	# DIAG all keys (throttled to avoid spam, but log every undo/redo attempt)
	var is_undo_down := ke.pressed and not ke.echo and _is_editor_action(ke, "undo")
	var is_redo_down := ke.pressed and not ke.echo and _is_editor_action(ke, "redo")
	if ke.pressed and not ke.echo and (is_undo_down or is_redo_down or ke.keycode == KEY_Z or ke.keycode == KEY_Y):
		print("[DIAG HOLD] RAW KEY DOWN keycode=%d phys=%d ctrl=%s shift=%s alt=%s echo=%s pressed=%s is_undo=%s is_redo=%s focus=%s" % [int(ke.keycode), int(ke.physical_keycode), str(ke.ctrl_pressed), str(ke.shift_pressed), str(ke.alt_pressed), str(ke.echo), str(ke.pressed), str(is_undo_down), str(is_redo_down), str(get_viewport().gui_get_focus_owner())])
	if not ke.pressed and (ke.keycode == KEY_Z or ke.keycode == KEY_Y):
		print("[DIAG HOLD] RAW KEY UP keycode=%d phys=%d ctrl=%s shift=%s pressed=%s is_undo_rel=%s is_redo_rel=%s" % [int(ke.keycode), int(ke.physical_keycode), str(ke.ctrl_pressed), str(ke.shift_pressed), str(ke.pressed), str(_is_editor_action(ke, "undo")), str(_is_editor_action(ke, "redo"))])
	# Handle release for undo/redo repeat tracking (must handle even when echoed)
	if not ke.pressed:
		# DIAG hold release
		var rel_is_undo := _is_editor_action(ke, "undo")
		var rel_is_redo := _is_editor_action(ke, "redo")
		if rel_is_undo or rel_is_redo:
			var rel_action := "undo" if rel_is_undo else "redo"
			var held_before := _undo_held if rel_is_undo else _redo_held
			print("[DIAG HOLD] KEY UP action=%s pressed=%s ctrl=%s shift=%s keycode=%d held_before=%s" % [rel_action, str(ke.pressed), str(ke.ctrl_pressed), str(ke.shift_pressed), int(ke.keycode), str(held_before)])
		# Release: stop repeat
		if rel_is_undo:
			_undo_held = false
			_undo_hold_time = 0.0
			_undo_next_repeat = REPEAT_INITIAL_DELAY
			_undo_diag_last_log_t = -100.0
			print("[DIAG HOLD] KEY UP action=undo held_after=%s" % str(_undo_held))
			get_viewport().set_input_as_handled()
			return
		if rel_is_redo:
			_redo_held = false
			_redo_hold_time = 0.0
			_redo_next_repeat = REPEAT_INITIAL_DELAY
			_redo_diag_last_log_t = -100.0
			print("[DIAG HOLD] KEY UP action=redo held_after=%s" % str(_redo_held))
			get_viewport().set_input_as_handled()
			return
		return
	# Now pressed == true
	if ke.echo:
		return
	# Don't steal typing from text fields and don't double-handle when UI control has focus
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner is TextEdit or focus_owner is LineEdit:
		return
	# When focus is on any ButtonBase (Button, CheckBox, OptionButton), Space/Enter/arrows belong to UI
	if focus_owner is BaseButton or focus_owner is OptionButton:
		if ke and ke.keycode in [KEY_SPACE, KEY_ENTER, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT] and not ke.ctrl_pressed and not ke.alt_pressed:
			return
		# For OptionButton popup, let it handle all keys
		if focus_owner is OptionButton and (focus_owner as OptionButton).get_popup() and (focus_owner as OptionButton).get_popup().visible:
			return
	# Use configurable bindings via ChartEditorBindings
	if _is_editor_action(ke, "undo"):
		_on_undo_pressed()
		_undo_held = true
		_undo_hold_time = 0.0
		_undo_next_repeat = REPEAT_INITIAL_DELAY
		_undo_diag_last_log_t = -100.0
		print("[DIAG HOLD] KEY DOWN action=undo held_after=%s hold_time=%s next_repeat=%s keycode=%d ctrl=%s shift=%s" % [str(_undo_held), str(_undo_hold_time), str(_undo_next_repeat), int(ke.keycode), str(ke.ctrl_pressed), str(ke.shift_pressed)])
		get_viewport().set_input_as_handled()
	elif _is_editor_action(ke, "redo"):
		_on_redo_pressed()
		_redo_held = true
		_redo_hold_time = 0.0
		_redo_next_repeat = REPEAT_INITIAL_DELAY
		_redo_diag_last_log_t = -100.0
		var redo_via := "redo"
		if ke.keycode == KEY_Z and ke.shift_pressed:
			redo_via = "redo(Ctrl+Shift+Z)"
		elif ke.keycode == KEY_Y:
			redo_via = "redo(Ctrl+Y)"
		print("[DIAG HOLD] KEY DOWN action=%s held_after=%s hold_time=%s next_repeat=%s keycode=%d ctrl=%s shift=%s" % [redo_via, str(_redo_held), str(_redo_hold_time), str(_redo_next_repeat), int(ke.keycode), str(ke.ctrl_pressed), str(ke.shift_pressed)])
		get_viewport().set_input_as_handled()
		get_viewport().set_input_as_handled()
	elif ke.ctrl_pressed and ke.keycode in [KEY_EQUAL, KEY_KP_ADD]:
		if state:
			_on_zoom_changed(state.px_per_sec * 1.2)
		get_viewport().set_input_as_handled()
		return
	elif ke.ctrl_pressed and ke.keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
		if state:
			_on_zoom_changed(state.px_per_sec / 1.2)
		get_viewport().set_input_as_handled()
		return
	elif _is_editor_action(ke, "save"):
		_on_save_pressed()
		get_viewport().set_input_as_handled()
	elif _is_editor_action(ke, "select_all"):
		_on_select_all()
		get_viewport().set_input_as_handled()
	elif _is_editor_action(ke, "copy"):
		_on_copy()
		get_viewport().set_input_as_handled()
	elif _is_editor_action(ke, "paste"):
		_on_paste()
		get_viewport().set_input_as_handled()
	elif _is_editor_action(ke, "duplicate"):
		_on_duplicate()
		get_viewport().set_input_as_handled()
	elif _is_editor_action(ke, "quantize"):
		if state and state.has_selection():
			_on_quantize_hotkey()
			get_viewport().set_input_as_handled()
	elif _is_editor_action(ke, "tool_pencil"):
		_set_tool("pencil")
		get_viewport().set_input_as_handled()
	elif _is_editor_action(ke, "tool_select"):
		_set_tool("select")
		get_viewport().set_input_as_handled()
	elif _is_editor_action(ke, "cut"):
		if state and state.has_selection():
			_on_cut_pressed()
			get_viewport().set_input_as_handled()
	elif _is_editor_action(ke, "toggle_audio_source"):
		_toggle_audio_source()
		get_viewport().set_input_as_handled()
	elif _is_editor_action(ke, "delete"):
		if state and state.has_selection():
			_on_inspector_delete()
			get_viewport().set_input_as_handled()
	elif _is_editor_action(ke, "clear_selection"):
		if state and state.has_selection():
			state.clear_selection()
			_refresh_ui()
			get_viewport().set_input_as_handled()
		else:
			# Нет выделения — Esc = Back (с dirty-проверкой)
			_on_back_pressed()
			get_viewport().set_input_as_handled()
	elif _is_editor_action(ke, "play_pause"):
		_on_play_pressed()
		get_viewport().set_input_as_handled()
	elif _is_editor_action(ke, "song_start"):
		_go_to_time(0.0)
		get_viewport().set_input_as_handled()
	elif _is_editor_action(ke, "song_end"):
		_go_to_time(state.duration_s if state else 0.0)
		get_viewport().set_input_as_handled()
	elif _is_editor_action(ke, "prev_beat"):
		_go_to_prev_beat()
		get_viewport().set_input_as_handled()
	elif _is_editor_action(ke, "next_beat"):
		_go_to_next_beat()
		get_viewport().set_input_as_handled()
	elif _is_editor_action(ke, "prev_measure"):
		_go_to_prev_measure()
		get_viewport().set_input_as_handled()
	elif _is_editor_action(ke, "next_measure"):
		_go_to_next_measure()
		get_viewport().set_input_as_handled()

# --- Playback ---

func _on_play_pressed() -> void:
	if state == null or player == null:
		return
	if state.is_playing:
		player.pause()
		state.is_playing = false
		if _play_btn:
			_play_btn.text = ""
			UiIconHelper.configure_button_icon(_play_btn, "play.svg", UiIconHelper.ACCENT, 16)
	else:
		player.play(state.song_time)
		state.is_playing = true
		if _play_btn:
			_play_btn.text = ""
			UiIconHelper.configure_button_icon(_play_btn, "pause.svg", UiIconHelper.ACCENT, 16)

func _process(delta: float) -> void:
	var _t_proc_frame := PerfTrace.begin("perf.detail.chart_editor.frame.process")
	_frame_diag_process_count += 1
	var _t_proc_start := Time.get_ticks_usec()
	_frame_diag_samples += 1
	if _fps_trace_active:
		_update_fps_trace()
	# Gesture transfer UI -> Playfield: if LMB/RMB was pressed outside and now cursor is inside, synthesize press
	if _gesture_lmb_armed_outside and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var vp := get_viewport()
		if vp and _is_mouse_inside_playfield(vp.get_mouse_position()):
			if _overlay and not _is_overlay_gesture_active():
				var gpos := vp.get_mouse_position()
				var local := _get_overlay_local_for_global(gpos)
				var synth := InputEventMouseButton.new()
				synth.button_index = MOUSE_BUTTON_LEFT
				synth.pressed = true
				synth.position = local
				synth.ctrl_pressed = Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)
				synth.shift_pressed = Input.is_key_pressed(KEY_SHIFT)
				synth.alt_pressed = Input.is_key_pressed(KEY_ALT)
				synth.meta_pressed = Input.is_key_pressed(KEY_META)
				_overlay._gui_input(synth)
				_gesture_lmb_armed_outside = false
		elif not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_gesture_lmb_armed_outside = false
	if _gesture_rmb_armed_outside and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var vp2 := get_viewport()
		if vp2 and _is_mouse_inside_playfield(vp2.get_mouse_position()):
			if _overlay and _overlay.current_tool == "pencil" and not _overlay._rmb_hold_active and not _is_overlay_gesture_active():
				var gpos2 := vp2.get_mouse_position()
				var local2 := _get_overlay_local_for_global(gpos2)
				var synth2 := InputEventMouseButton.new()
				synth2.button_index = MOUSE_BUTTON_RIGHT
				synth2.pressed = true
				synth2.position = local2
				_overlay._gui_input(synth2)
				_gesture_rmb_armed_outside = false
		elif not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_gesture_rmb_armed_outside = false
	# Editor-level mouse capture for active gesture (spec 3)
	if _overlay:
		var is_gesture_active: bool = _overlay._is_dragging or _overlay._is_boxing or _overlay._is_pencil_painting or _overlay._rmb_hold_active or _overlay._pencil_pending_action == "delete"
		_set_ui_capture_during_gesture(is_gesture_active)
	_maybe_autosave(delta)
	# Undo/Redo repeat (spec 5) — delta-based, not FPS dependent; release handler is sole reset (no is_physically_held poll)
	if _undo_held or _redo_held:
		if _undo_held:
			var before_undo := _undo_hold_time
			_undo_hold_time += delta
			if _undo_hold_time - _undo_diag_last_log_t >= 0.1 or _undo_diag_last_log_t < -50.0:
				print("[DIAG HOLD] _process undo delta=%s hold_before=%s hold_after=%s next=%s" % [str(delta), str(before_undo), str(_undo_hold_time), str(_undo_next_repeat)])
				_undo_diag_last_log_t = _undo_hold_time
			if _undo_hold_time >= _undo_next_repeat:
				print("[DIAG HOLD] UNDO REPEAT FIRED hold_time=%s next_repeat=%s" % [str(_undo_hold_time), str(_undo_next_repeat)])
				_on_undo_pressed()
				_undo_next_repeat += REPEAT_INTERVAL
				print("[DIAG HOLD] UNDO REPEAT DONE next_repeat now=%s" % str(_undo_next_repeat))
		if _redo_held:
			var before_redo := _redo_hold_time
			_redo_hold_time += delta
			if _redo_hold_time - _redo_diag_last_log_t >= 0.1 or _redo_diag_last_log_t < -50.0:
				print("[DIAG HOLD] _process redo delta=%s hold_before=%s hold_after=%s next=%s" % [str(delta), str(before_redo), str(_redo_hold_time), str(_redo_next_repeat)])
				_redo_diag_last_log_t = _redo_hold_time
			if _redo_hold_time >= _redo_next_repeat:
				print("[DIAG HOLD] REDO REPEAT FIRED hold_time=%s next_repeat=%s" % [str(_redo_hold_time), str(_redo_next_repeat)])
				_on_redo_pressed()
				_redo_next_repeat += REPEAT_INTERVAL
				print("[DIAG HOLD] REDO REPEAT DONE next_repeat now=%s" % str(_redo_next_repeat))
	# Update inspector timeline (follows playhead)
	if _inspector and _inspector.has_method("update_timeline") and state:
		_inspector.update_timeline(state.song_time)
	if state and player and player.is_playing():
		var prev := _prev_song_time
		state.song_time = player.get_time()
		_prev_song_time = state.song_time
		# Playback hit feedback for notes crossing HitZone (isolated, no scoring) — reuse gameplay visuals
		if state.document and state.document.notes.size() > 0 and prev >= 0.0:
			for n in state.document.notes:
				var t := float(n.get("time", 0.0))
				var is_hit := false
				var hit_k := ""
				# Note just crossed from future to past (t in (prev, song_time])
				if t > prev and t <= state.song_time + 0.02:
					hit_k = EditorNoteUtils.note_key(n as Dictionary)
					var last := float(_hit_sound_cooldown.get(hit_k, -999.0))
					if state.song_time - last > 0.25:
						_hit_sound_cooldown[hit_k] = state.song_time
						is_hit = true
				elif absf(t - state.song_time) < 0.02 and t > prev:
					hit_k = EditorNoteUtils.note_key(n as Dictionary)
					var last2 := float(_hit_sound_cooldown.get(hit_k, -999.0))
					if state.song_time - last2 > 0.25:
						_hit_sound_cooldown[hit_k] = state.song_time
						is_hit = true
				if is_hit:
					_play_hit_feedback(String(n.get("drum", "kick")))
					_trigger_hit_visual(n as Dictionary, hit_k)
		if _playfield:
			_playfield.queue_redraw()
		if _overlay:
			_overlay.queue_redraw()
		if _ruler:
			_ruler.queue_redraw()
	elif state and _playfield and player and not player.is_playing():
		_prev_song_time = state.song_time
	if state and _time_label:
		_update_bottom_labels()
		if _ruler and is_inside_tree():
			_ruler.queue_redraw()
	_frame_diag_process_time += Time.get_ticks_usec() - _t_proc_start
	PerfTrace.end("perf.detail.chart_editor.frame.process", _t_proc_frame)

# --- Save / Revert ---

func _on_save_pressed() -> void:
	if state == null:
		return
	# If not dirty, don't create new version
	if not state.is_dirty:
		_set_status("No changes to save", false)
		_return_focus_to_editor()
		return
	var err := _do_save()
	if err != "":
		_set_status("Save failed: %s" % err, true)
		_StatusToast.show_from_node(self, "chart_editor_save", "Save failed: %s" % err, "error", 2.5)
	else:
		_set_status("Saved %d notes to %s" % [state.note_count(), state.chart_stem], false)
		_StatusToast.show_from_node(self, "chart_editor_save", tr("CHART_EDITOR_NOTIFY_SAVED"), "success", 2.5)
		undo_stack.mark_saved()
		state.mark_clean()
		_refresh_ui()
	_return_focus_to_editor()

func _on_save_as_pressed() -> void:
	if state == null:
		return
	var err := _do_save_as_next_version()
	if err != "":
		_set_status("Save As failed: %s" % err, true)
		_StatusToast.show_from_node(self, "chart_editor_save_as", "Save As failed: %s" % err, "error", 2.5)
	else:
		_set_status("Saved as %s (%d notes)" % [state.chart_stem, state.note_count()], false)
		_StatusToast.show_from_node(self, "chart_editor_save_as", tr("CHART_EDITOR_NOTIFY_SAVED_AS"), "success", 2.5)
		# Save As clears undo/redo for new version per spec
		undo_stack.clear()
		undo_stack.mark_saved()
		state.mark_clean()
		state.clipboard.clear()
		_refresh_ui()
	_return_focus_to_editor()

func _get_source_notes_for_diff() -> Array:
	if state == null:
		return []
	if not state.source_notes_cache.is_empty():
		return state.source_notes_cache
	# Fallback: load generated base
	var gen := NotesUtils.load_notes_array(state.song_path, state.instrument, state.base_stem, state.lanes)
	if not gen.is_empty():
		return gen
	return EditorNoteUtils.clone_notes(state.document.notes)

func _get_current_actions() -> Array:
	if state == null:
		return []
	# For versioned saves, the authoritative history is the current corrections actions (which were populated from rfc on open and appended via record_action)
	if state.corrections and not state.corrections.actions.is_empty():
		return state.corrections.actions.duplicate(true)
	if state.is_corrected and not state.rfc_payload.is_empty():
		var a = state.rfc_payload.get("actions", [])
		if a is Array:
			return (a as Array).duplicate(true)
	return []

func _write_versioned_pair(version: int, notes: Array, actions: Array, source_notes: Array, parent_version: int, parent_hash: String) -> String:
	# Atomic write of .rf + .rfc for given version
	var base := state.base_stem if state else "arcade_medium"
	var inst := state.instrument if state else "drums"
	var lanes_v := state.lanes if state else 5
	var bpm_v := state.bpm if state else 120.0
	var rf_path := RfcCorrectionsCodec.versioned_path_for(state.song_path, inst, base, version, "rf")
	var rfc_path := RfcCorrectionsCodec.versioned_path_for(state.song_path, inst, base, version, "rfc")
	var labels := NotesUtils.resolve_track_labels(state.song_path)
	var artist := String(labels.get("artist", ""))
	var title := String(labels.get("title", ""))
	var Rfc := preload("res://logic/domain/charts/rfc_chart_codec.gd")
	var abs_rf := DirectoryUtils.to_absolute(rf_path)
	if abs_rf == "":
		return "invalid rf path"
	DirectoryUtils.ensure_dir_for_file(rf_path)
	var ok_rf := Rfc.write_file(rf_path, notes, inst, state.base_stem if state else base, lanes_v, artist, title)
	if not ok_rf:
		return "failed to write .rf %s" % rf_path
	# Build .rfc payload
	var src_path := RfcCorrectionsCodec.versioned_path_for(state.song_path, inst, base, 0, "rf")
	var payload := RfcCorrectionsCodec.build_payload(state.song_path, inst, base, version, source_notes, notes, actions, parent_version, parent_hash, bpm_v, lanes_v, src_path)
	var ok_rfc := RfcCorrectionsCodec.write_file(rfc_path, payload)
	if not ok_rfc:
		return "failed to write .rfc %s" % rfc_path
	NotesUtils.invalidate_notes_cache()
	return ""

func _delete_temp_for_current_after_save() -> void:
	# Delete temp only after successful Save (spec 15)
	var tp := _get_temp_path_for_current()
	if tp != "":
		RfTempCodec.delete_temp(tp)
		_last_autosave_hash = _get_document_hash()

func _do_save() -> String:
	if state == null:
		return "no state"
	if not state.is_dirty:
		return "" # No changes — not an error, just no-op per spec
	var is_generated := state.version == 0 and not state.is_corrected
	if is_generated:
		# First Save: Generated -> Corrected v1
		var next_ver = RfcCorrectionsCodec.next_free_version(state.song_path, state.instrument, state.base_stem)
		if next_ver <= 0:
			next_ver = 1
		var source_notes := _get_source_notes_for_diff()
		var actions := _get_current_actions()
		# Also include current dirty actions not yet in actions? The actions already recorded via record_action, so use them
		var err := _write_versioned_pair(next_ver, state.document.notes, actions, source_notes, 0, "")
		if err != "":
			return err
		# Success: switch active to new version
		state.version = next_ver
		state.is_corrected = true
		state.chart_stem = RfcCorrectionsCodec.versioned_stem(state.base_stem, next_ver)
		state.is_canonical = (state.base_stem == state.canonical_stem)
		# Update rfc_payload for future saves
		var rfc_path = RfcCorrectionsCodec.versioned_path_for(state.song_path, state.instrument, state.base_stem, next_ver, "rfc")
		state.rfc_payload = RfcCorrectionsCodec.read_file(rfc_path)
		# Also keep old corrections for compat — update its stem to versioned
		if state.corrections:
			state.corrections.chart_stem = state.chart_stem
			state.corrections.lanes = state.lanes
			state.corrections.bpm = state.bpm
			# Don't write old corrections for versioned — but keep in memory for legacy
		_delete_temp_for_current_after_save()
		return ""
	else:
		# Corrected vN -> overwrite same version
		var cur_ver := state.version
		var source_notes2 := _get_source_notes_for_diff()
		var actions2 := _get_current_actions()
		var parent_ver := state.parent_version_cache
		var parent_hash := state.parent_hash_cache
		# If we have rfc_payload, parent is from there
		if not state.rfc_payload.is_empty():
			parent_ver = int(state.rfc_payload.get("parent_version", 0))
			parent_hash = String(state.rfc_payload.get("parent_hash", ""))
		var err2 := _write_versioned_pair(cur_ver, state.document.notes, actions2, source_notes2, parent_ver, parent_hash)
		if err2 != "":
			return err2
		# Refresh payload
		var rfc_path2 = RfcCorrectionsCodec.versioned_path_for(state.song_path, state.instrument, state.base_stem, cur_ver, "rfc")
		state.rfc_payload = RfcCorrectionsCodec.read_file(rfc_path2)
		_delete_temp_for_current_after_save()
		return ""

func _do_save_as_next_version() -> String:
	if state == null:
		return "no state"
	# Determine next free version (global, not just current+1)
	var next_ver = RfcCorrectionsCodec.next_free_version(state.song_path, state.instrument, state.base_stem)
	if next_ver <= state.version:
		next_ver = state.version + 1
		# Ensure not colliding
		var existing = RfcCorrectionsCodec.list_existing_versions(state.song_path, state.instrument, state.base_stem)
		while next_ver in existing:
			next_ver += 1
	var source_notes3 := _get_source_notes_for_diff()
	var actions3 := _get_current_actions()
	var parent_ver := state.version
	var parent_hash := ""
	if state.version > 0:
		# Parent is current version's hash
		var cur_rfc_path = RfcCorrectionsCodec.versioned_path_for(state.song_path, state.instrument, state.base_stem, state.version, "rfc")
		var cur_payload = RfcCorrectionsCodec.read_file(cur_rfc_path)
		if not cur_payload.is_empty():
			parent_hash = String(cur_payload.get("current_hash", cur_payload.get("current", {}).get("hash", "")))
			if parent_hash == "":
				parent_hash = RfcCorrectionsCodec._hash_notes(state.document.notes) # fallback
		else:
			# No .rfc for current version yet (maybe just created via Save but not yet reloaded) — use current doc hash
			parent_hash = RfcCorrectionsCodec._hash_notes(state.document.notes)
	else:
		# Generated -> first corrected via Save As (same as Save)
		parent_ver = 0
		parent_hash = ""
	var old_ver := state.version
	var err3 := _write_versioned_pair(next_ver, state.document.notes, actions3, source_notes3, parent_ver, parent_hash)
	if err3 != "":
		return err3
	# Success: delete old temp (orphan) before switching, then switch active to new version
	_delete_temp_for_version(old_ver)
	state.version = next_ver
	state.is_corrected = true
	state.chart_stem = RfcCorrectionsCodec.versioned_stem(state.base_stem, next_ver)
	state.is_canonical = (state.base_stem == state.canonical_stem)
	var new_rfc_path = RfcCorrectionsCodec.versioned_path_for(state.song_path, state.instrument, state.base_stem, next_ver, "rfc")
	state.rfc_payload = RfcCorrectionsCodec.read_file(new_rfc_path)
	state.parent_version_cache = parent_ver
	state.parent_hash_cache = parent_hash
	# Update old corrections stem for compat
	if state.corrections:
		state.corrections.chart_stem = state.chart_stem
	_delete_temp_for_current_after_save()
	return ""

func _on_revert_pressed() -> void:
	if state == null or state.corrections == null:
		return
	var src_rel := ChartEditorCorrectionsClass.source_path_for(state.song_path, state.chart_stem)
	var abs_src := DirectoryUtils.to_absolute(src_rel)
	if abs_src == "" or not FileAccess.file_exists(abs_src):
		_set_status("No source backup to revert to", true)
		_StatusToast.show_from_node(self, "chart_editor_revert", "No source backup to revert to", "error", 2.5)
		return
	# P0: direct revert without async confirm (confirm wiring deferred).
	_do_revert()

func _do_revert() -> void:
	var src_rel := ChartEditorCorrectionsClass.source_path_for(state.song_path, state.chart_stem)
	var arr: Array = ChartEditorCorrectionsClass._load_notes_from_path(src_rel)
	if arr.is_empty():
		# Fallback to corrections source_notes
		arr = EditorNoteUtilsClass.clone_notes(state.corrections.source_notes)
	if arr.is_empty():
		_set_status("Revert failed: source empty", true)
		_StatusToast.show_from_node(self, "chart_editor_revert", "Revert failed: source empty", "error", 2.5)
		return
	state.document.set_notes(arr)
	state.clear_selection()
	undo_stack.clear()
	# Keep corrections but clear actions? For P0 we keep source but clear actions and re-save.
	state.corrections.clear()
	state.corrections.source_notes = EditorNoteUtilsClass.clone_notes(arr)
	state.corrections.source_hash = ChartEditorCorrectionsClass._hash_notes(arr)
	state.corrections.source_provenance = "verified"
	# Overwrite .rf with reverted
	var ok := NotesUtils.save_mode_chart_array(state.song_path, state.instrument, state.chart_stem, state.lanes, arr)
	if not ok:
		_set_status("Revert write failed", true)
		_StatusToast.show_from_node(self, "chart_editor_revert", "Revert write failed", "error", 2.5)
		return
	var c_err := state.corrections.save(state.bpm, state.lanes)
	if c_err != "":
		_set_status("Revert corrections save failed: %s" % c_err, true)
		_StatusToast.show_from_node(self, "chart_editor_revert", "Revert corrections save failed: %s" % c_err, "error", 2.5)
		return
	NotesUtils.invalidate_notes_cache()
	state.mark_clean()
	undo_stack.mark_saved()
	_refresh_ui()
	_set_status("Reverted to source (%d notes)" % arr.size(), false)
	_StatusToast.show_from_node(self, "chart_editor_revert", tr("CHART_EDITOR_NOTIFY_REVERTED"), "success", 2.5)

func _on_back_pressed() -> void:
	if state and state.is_dirty:
		_show_dirty_choice()
		return
	_close_editor()

func _show_dirty_choice() -> void:
	var host := self
	var choice_overlay := _ensure_choice_overlay(host)
	if choice_overlay:
		# Ensure overlay is ready before show_choice (handles pre-_ready call correctly via pending, but also await ready for safety)
		if not choice_overlay.is_node_ready():
			await choice_overlay.ready
		# Save = confirm, Don't Save = extra, Cancel = cancel — localized via CHART_EDITOR_UNSAVED_* keys
		var title := tr("CHART_EDITOR_UNSAVED_TITLE")
		if title == "CHART_EDITOR_UNSAVED_TITLE" or title.strip_edges() == "":
			title = "Unsaved changes"
		var msg := tr("CHART_EDITOR_UNSAVED_MESSAGE")
		if msg == "CHART_EDITOR_UNSAVED_MESSAGE" or msg.strip_edges() == "":
			msg = "You have unsaved edits. Save before leaving?"
		var save_txt := tr("CHART_EDITOR_UNSAVED_SAVE")
		if save_txt == "CHART_EDITOR_UNSAVED_SAVE" or save_txt.strip_edges() == "":
			save_txt = "Save"
		var cancel_txt := tr("CHART_EDITOR_UNSAVED_CANCEL")
		if cancel_txt == "CHART_EDITOR_UNSAVED_CANCEL" or cancel_txt.strip_edges() == "":
			cancel_txt = "Cancel"
		var dont_save_txt := tr("CHART_EDITOR_UNSAVED_DONT_SAVE")
		if dont_save_txt == "CHART_EDITOR_UNSAVED_DONT_SAVE" or dont_save_txt.strip_edges() == "":
			dont_save_txt = "Don't Save"
		choice_overlay.show_choice(title, msg, "warning", save_txt, cancel_txt, dont_save_txt)
		var choice: String = await choice_overlay.finished
		if choice == "confirm":
			var err := _do_save()
			if err != "":
				_set_status("Save failed: %s" % err, true)
				return
			undo_stack.mark_saved()
			state.mark_clean()
			_refresh_ui()
			_close_editor()
		elif choice == "extra":
			# Don't Save — discard temp so next open does NOT propose recovery
			_delete_temp_for_current()
			# Also ensure dirty flag cleared to avoid loop
			if state:
				state.is_dirty = false
			_close_editor()
		else:
			# Cancel — stay, keep temp for recovery
			return
	else:
		# Fallback if overlay unavailable — block close
		_set_status("Unsaved changes — press Save or Don't Save", true)

func _ensure_choice_overlay(host: Node) -> AppChoiceOverlay:
	if host == null:
		return null
	var existing := host.get_node_or_null("DirtyChoiceOverlay") as AppChoiceOverlay
	if existing and is_instance_valid(existing):
		return existing
	var scene: PackedScene = load("res://ui/overlays/app_choice_overlay.tscn") as PackedScene
	if scene == null:
		return null
	var overlay := scene.instantiate() as AppChoiceOverlay
	if overlay == null:
		return null
	overlay.name = "DirtyChoiceOverlay"
	host.add_child(overlay)
	return overlay

func _close_editor() -> void:
	if player:
		player.stop()
	# Try LIFO back first, preserve dirty flow already handled by caller
	var transitions = _get_transitions()
	if transitions and transitions.has_method("navigate_back"):
		if transitions.navigate_back():
			return
	# Navigate back to song_select — robust resolution, never leave app without navigation.
	if transitions and transitions.has_method("open_song_select"):
		transitions.open_song_select()
		return
	if transitions and transitions.has_method("transition_open_song_select"):
		transitions.transition_open_song_select()
		return
	if transitions and transitions.has_method("pop_screen"):
		transitions.pop_screen()
		return
	# Fallback: try via GameEngine autoload or SceneTree root.
	var tree := get_tree()
	if tree:
		var root := tree.root
		if root:
			# Try GameEngine node.
			var ge := root.get_node_or_null("GameEngine")
			if ge and ge.has_method("get_transitions"):
				var t2 = ge.get_transitions()
				if t2 and t2.has_method("open_song_select"):
					t2.open_song_select()
					return
			# Last resort: change scene directly (never just queue_free).
			var err := tree.change_scene_to_file("res://scenes/song_select/song_select.tscn")
			if err == OK:
				return
	# Absolute last fallback — still remove self but log error (should never happen).
	printerr("ChartEditor: no Transitions found — falling back to queue_free (navigation may be broken)")
	queue_free()

func _get_transitions():
	var tree := get_tree()
	var root := tree.root if tree else null
	if root and root.has_node("Transitions"):
		return root.get_node("Transitions")
	if root:
		var ge := root.get_node_or_null("GameEngine")
		if ge and ge.has_method("get_transitions"):
			return ge.get_transitions()
	var engine := get_parent()
	if engine and engine.has_method("get_transitions"):
		return engine.get_transitions()
	if Engine.has_singleton("Transitions"):
		return Engine.get_singleton("Transitions")
	return null

func _get_confirm_overlay():
	if _confirm_overlay and is_instance_valid(_confirm_overlay):
		return _confirm_overlay
	# Try find in scene
	var c := get_node_or_null("%ConfirmOverlay")
	if c:
		_confirm_overlay = c
		return c
	return null

func _show_missing_medium_dialog(song_path: String, requested_stem: String) -> void:
	var msg := tr("CHART_EDITOR_MISSING_MEDIUM")
	_set_status(msg, true)

func _request_generate_medium(song_path: String) -> void:
	# P0: delegate to existing generation flow via GenerationService / SongSelect.
	# For now, toast + navigate back to song_select where user can press Generate.
	_set_status(tr("CHART_EDITOR_REQUEST_MEDIUM"), true)
	# We could auto-trigger generation if GenerationService is available:
	if Engine.has_singleton("GenerationService"):
		pass