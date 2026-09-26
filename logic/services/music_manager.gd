# logic/services/music_manager.gd
extends Node

const BGM_DIR = "res://assets/audio/music/"
const SFX_DIR = "res://assets/audio/sfx/"
const SHOP_SOUND_DIR = "res://assets/shop/sounds/"
const MUSIC_BUS_NAME := "Music"
const PITCH_COMPENSATION_EFFECT_IDX := 1

const DEFAULT_MENU_MUSIC = "Tycho - Awake.mp3"
const DEFAULT_INTRO_MUSIC = "intro_music.wav"
const DEFAULT_VICTORY_SCREEN_MUSIC = "Breathturn - Hammock.mp3"
const DEFAULT_DEFEAT_SCREEN_MUSIC = "Life is Strange - Pause Menu.mp3"
const DEFAULT_SELECT_SOUND = "select_click.wav"
const DEFAULT_CANCEL_SOUND = "cancel_click.wav"
const ANALYSIS_SUCCESS_SOUND = "analysis_success.wav"
const ANALYSIS_ERROR_SOUND = "analysis_error.wav"
const STATUS_TOAST_SOUND = "status_toast.wav"
## Optional sparkle/diary toast; falls back to achievement SFX if missing.
const DIARY_CELEBRATION_SOUND = "diary_celebration.wav"
const DEFAULT_ACHIEVEMENT_SOUND = "achievement_unlocked.wav"
const SHOP_PURCHASE_SOUND = "shop_purchase.wav"
const SHOP_APPLY_SOUND = "shop_apply.wav"
const SHOP_OPEN_SOUND = "shop_open.wav"
const DEFAULT_SHOP_SOUND = "missing_sound.wav"
const DEFAULT_METRONOME_STRONG_SOUND = "metronome_strong.wav"
const DEFAULT_METRONOME_WEAK_SOUND = "metronome_weak.wav"
const DEFAULT_COVER_CLICK_SOUND = "page_flip.wav"
const DEFAULT_LEVEL_START_SOUND = "level_start_ripple.wav"
const DEFAULT_LEVEL_COMPLETE_SOUND = "level_complete.wav"
const DEFAULT_LEVEL_UP_SOUND = "level_up.wav"
const DEFAULT_SCORE_TICK_SOUND = "score_tick.wav"
const DEFAULT_GRADE_POP_SOUND = "grade_pop.wav"
const DEFAULT_MISS_HIT_SOUND_1 = "miss_hit1.wav"
const DEFAULT_MISS_HIT_SOUND_2 = "miss_hit2.wav"
const DEFAULT_MISS_HIT_SOUND_3 = "miss_hit3.wav"
const DEFAULT_MISS_HIT_SOUND_4 = "miss_hit4.wav"
const DEFAULT_MISS_HIT_SOUND_5 = "miss_hit5.wav"

const DEFAULT_RESTART_SOUND = "restart_level.wav"
const DEFAULT_RESUME_REWIND_SOUND = "resume_rewind.wav"
const DEFAULT_DEFEAT_SOUND = "level_defeat.wav"
const MODIFIER_SELECT_SOUND = "modifier_select.wav"
const MODIFIER_DESELECT_SOUND = "modifier_deselect.wav"
const MODAL_POPUP_SOUND = "modal_popup.wav"

const DEFAULT_DRUMS_SELECT_SOUND = "drums_select.wav"
const DEFAULT_BASS_SELECT_SOUND = "bass_select.wav"
const DEFAULT_STANDARD_SELECT_SOUND = "standard_select.wav"
const DEFAULT_FULLMIX_SELECT_SOUND = "drums_select.wav"

var was_menu_music_playing_before_shop: bool = false
var menu_music_position_before_shop: float = 0.0

var music_player: AudioStreamPlayer = null
var sfx_player: AudioStreamPlayer = null
var hit_sound_player: AudioStreamPlayer = null
const HIT_POOL_SIZE := 4
## Chord / multilane: play one kick, not stacked pool voices.
const HIT_SOUND_DEDUPE_MS := 35.0
var _hit_pool: Array[AudioStreamPlayer] = []
var _last_hit_sound_msec: int = -999999
var metronome_player1: AudioStreamPlayer = null
var metronome_player2: AudioStreamPlayer = null

var metronome_active: bool = false
var _current_metronome_player_index: int = 0
var _metronome_players: Array[AudioStreamPlayer] = []

var active_kick_sound_path: String = ""

var current_menu_music_file: String = ""
var current_game_music_file: String = ""
var current_screen_ambient_file: String = ""
var current_stem_file: String = ""
var stem_player: AudioStreamPlayer = null
var active_audio_source: String = "original" # "original" or "drums"

var original_game_music_volume: float = 1.0

var _external_metronome_controlled: bool = false

var _last_beat_index: int = -1
var _menu_music_volume_pct: float = 50.0
var _game_music_volume_pct: float = 50.0
var _game_playback_rate: float = 1.0
var _preserve_pitch: bool = true
var _menu_music_fade_tween: Tween = null
var _game_music_fade_tween: Tween = null
var _resume_audio_on_focus_in: bool = false
var _resume_game_audio_on_focus_in: bool = false
var _saved_playback_position_on_unfocus: float = 0.0
var _menu_music_intentionally_silent: bool = false

var _stream_cache: Dictionary = {}
var _async_audio_threads: Dictionary = {}
var _async_audio_callbacks: Dictionary = {}
var _async_audio_started_ms: Dictionary = {}
var _custom_hit_request_id: int = 0

# Diagnostic: game music play/stop/seek trace via existing Development Console (no behavior change).
func _mm_trace_game(op: String, detail: String) -> void:
	var c := get_tree().root.get_node_or_null("Console") if get_tree() and get_tree().root else null
	if c and c.has_method("print_line"):
		var playing := music_player.playing if music_player else false
		var stream_name := ""
		if music_player and music_player.stream:
			stream_name = str(music_player.stream.resource_path) if String(music_player.stream.resource_path) != "" else str(music_player.stream)
		var pos := 0.0
		if music_player and music_player.has_method("get_playback_position"):
			pos = music_player.get_playback_position()
		c.call("print_line", "[MUSIC TRACE] op=%s playing=%s pos=%.3f file=%s stream=%s %s" % [op, str(playing), pos, current_game_music_file.get_file() if current_game_music_file != "" else "(empty)", stream_name.get_file() if stream_name != "" else "(null)", detail])

func _mm_stream_diag() -> String:
	if not music_player or not music_player.stream:
		return "type=(null) loop=(n/a) len=0.000 variant=(none)"
	var s := music_player.stream
	var tname := s.get_class()
	var loop_state := "n/a"
	if s is AudioStreamMP3:
		loop_state = str((s as AudioStreamMP3).loop)
	elif s is AudioStreamOggVorbis:
		loop_state = str((s as AudioStreamOggVorbis).loop)
	elif s is AudioStreamWAV:
		loop_state = str((s as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED) if s.has_method("get_loop_mode") else "wav"
	var len_s := 0.0
	if s.has_method("get_length"):
		len_s = float(s.get_length())
	# Variant: imported res:// vs runtime_data (AudioStreamMP3.data=bytes has empty resource_path)
	var variant := "runtime_data"
	if String(s.resource_path) != "":
		if String(s.resource_path).begins_with("res://"):
			variant = "imported_res"
		else:
			variant = "imported_res"
	# Heuristic: imported streams have non-empty resource_path, runtime_data has empty
	return "type=%s loop=%s len=%.3f variant=%s" % [tname, loop_state, len_s, variant]

# Diagnostic finished — never changes playback, only logs (no play/stop/seek/stream change).
func _on_music_player_finished_diag() -> void:
	# Must stay read-only: just trace. Menu loop handler remains separate.
	var c := get_tree().root.get_node_or_null("Console") if get_tree() and get_tree().root else null
	if c and c.has_method("print_line"):
		var playing := music_player.playing if music_player else false
		var pos := 0.0
		if music_player and music_player.has_method("get_playback_position"):
			pos = music_player.get_playback_position()
		var stream_name := "(null)"
		if music_player and music_player.stream:
			stream_name = str(music_player.stream.resource_path) if String(music_player.stream.resource_path) != "" else str(music_player.stream)
		c.call("print_line", "[MUSIC TRACE] op=finished playing=%s pos=%.3f file=%s stream=%s %s" % [str(playing), pos, current_game_music_file.get_file() if current_game_music_file != "" else "(empty)", stream_name.get_file() if stream_name != "(null)" else "(null)", _mm_stream_diag()])
const SFX_POOL_SIZE := 8
var _sfx_pool: Array[AudioStreamPlayer] = []
const PERF_LOG_THRESHOLD_MS := 50
const PRELOAD_SFX := [
	DEFAULT_SELECT_SOUND,
	DEFAULT_CANCEL_SOUND,
	DEFAULT_COVER_CLICK_SOUND,
	DEFAULT_SCORE_TICK_SOUND
]
const DEFERRED_PRELOAD_SFX := [
	ANALYSIS_SUCCESS_SOUND,
	ANALYSIS_ERROR_SOUND,
	DEFAULT_ACHIEVEMENT_SOUND,
	SHOP_PURCHASE_SOUND,
	SHOP_APPLY_SOUND,
	DEFAULT_SHOP_SOUND,
	DEFAULT_METRONOME_STRONG_SOUND,
	DEFAULT_METRONOME_WEAK_SOUND,
	DEFAULT_LEVEL_START_SOUND,
	DEFAULT_LEVEL_UP_SOUND,
	DEFAULT_LEVEL_COMPLETE_SOUND,
	DEFAULT_RESTART_SOUND,
	DEFAULT_MISS_HIT_SOUND_1,
	DEFAULT_MISS_HIT_SOUND_2,
	DEFAULT_MISS_HIT_SOUND_3,
	DEFAULT_MISS_HIT_SOUND_4,
	DEFAULT_MISS_HIT_SOUND_5
]

# A/B diagnostic for astrid - glaive.mp3: imported_res vs runtime_data (no behavior change for other tracks)
# New scheme: isolated test/ folder (PROD D:\Games\godotprojects\RhythmFall\test\), keeps original full_path identity
const AB_ASTRID_IMPORTED_RES_PATH := "res://test/astrid - glaive.mp3"
const AB_ASTRID_FILE := "astrid - glaive.mp3"

# --- DIAG STATE WATCHER (read-only, astrid/game only, no behavior) ---
var _diag_watch_last_playing: Variant = null
var _diag_watch_last_paused: Variant = null
var _diag_watch_last_stream_id: String = ""
var _diag_watch_last_path: String = ""
# Controlled A/B: last play tracking for non-zero position test (read-only)
var _diag_last_play_req_pos: float = -1.0
var _diag_last_play_ts: int = 0
var _diag_last_play_stream_len: float = 0.0
var _diag_last_play_pitch: float = 1.0
var _diag_last_play_bus: String = ""
var _diag_last_play_had_stop: bool = false
var _diag_last_play_had_stream: bool = false
var _diag_last_play_had_seek: bool = false
var _diag_last_play_had_play: bool = false
var _diag_at73_logged: bool = false

func _diag_is_astrid_path(p: String) -> bool:
	if p == "":
		return false
	var low := String(p).to_lower()
	var f := low.get_file().strip_edges()
	return f == AB_ASTRID_FILE.to_lower() or (low.contains("astrid") and low.contains("glaive"))

func _diag_should_trace_game() -> bool:
	if current_game_music_file == "":
		return false
	return _diag_is_astrid_path(current_game_music_file)

func _diag_get_scene_str() -> String:
	if get_tree() == null or get_tree().current_scene == null:
		return "(no_scene)"
	var cs := get_tree().current_scene
	var sp := String(cs.scene_file_path)
	if sp != "":
		return sp.get_file()
	return String(cs.name)

func _diag_get_focus_str() -> String:
	var awm := get_node_or_null("/root/AppWindowManager")
	if awm and awm.has_method("is_app_focused"):
		return str(awm.call("is_app_focused"))
	if DisplayServer.window_is_focused():
		return "focused"
	return "unfocused"

func _diag_get_pause_str() -> String:
	if get_tree() == null or get_tree().current_scene == null:
		return "n/a"
	var gs := get_tree().current_scene
	if gs and gs.get("pauser") != null:
		var pauser = gs.get("pauser")
		if pauser and "is_paused" in pauser:
			return str(pauser.is_paused)
	if gs and "is_paused" in gs:
		return str(gs.get("is_paused"))
	return "n/a"

func _diag_get_game_time_str() -> String:
	if get_tree() == null or get_tree().current_scene == null:
		return "n/a"
	var gs := get_tree().current_scene
	if gs and "game_time" in gs:
		return "%.3f" % float(gs.get("game_time"))
	if gs and gs.has_method("get_song_time"):
		return "%.3f" % float(gs.call("get_song_time"))
	return "n/a"

func _diag_build_state(reason: String) -> String:
	var playing := music_player.playing if music_player else false
	var paused := music_player.stream_paused if music_player else false
	var pos := 0.0
	if music_player and music_player.has_method("get_playback_position"):
		pos = music_player.get_playback_position()
	var stream_id := "(null)"
	if music_player and music_player.stream:
		var rp := String(music_player.stream.resource_path)
		stream_id = rp if rp != "" else String(music_player.stream.get_class())
	var gt := _diag_get_game_time_str()
	var scene := _diag_get_scene_str()
	var focus := _diag_get_focus_str()
	var pause_st := _diag_get_pause_str()
	var variant := _mm_stream_diag()
	var ts := Time.get_ticks_msec()
	var pitch := music_player.pitch_scale if music_player else 1.0
	var bus := String(music_player.bus) if music_player else "(null)"
	var loop_s := "n/a"
	if music_player and music_player.stream and music_player.stream is AudioStreamMP3:
		loop_s = str((music_player.stream as AudioStreamMP3).loop)
	elif music_player and music_player.stream and music_player.stream is AudioStreamOggVorbis:
		loop_s = str((music_player.stream as AudioStreamOggVorbis).loop)
	var len_s := 0.0
	if music_player and music_player.stream and music_player.stream.has_method("get_length"):
		len_s = float(music_player.stream.get_length())
	# READ-ONLY extended: playback + bus peaks + PitchShift instance (no state change)
	var has_playback: bool = music_player.has_stream_playback() if music_player and music_player.has_method("has_stream_playback") else false
	var playback_valid: String = "n/a"
	if music_player and music_player.has_method("get_stream_playback"):
		var pb := music_player.get_stream_playback()
		playback_valid = str(pb != null)
		if pb == null:
			has_playback = false
	var music_peak_l: float = -160.0
	var music_peak_r: float = -160.0
	var master_peak_l: float = -160.0
	var master_peak_r: float = -160.0
	var music_bus_idx := AudioServer.get_bus_index(MUSIC_BUS_NAME)
	if music_bus_idx >= 0:
		music_peak_l = AudioServer.get_bus_peak_volume_left_db(music_bus_idx, 0)
		music_peak_r = AudioServer.get_bus_peak_volume_right_db(music_bus_idx, 0)
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		master_peak_l = AudioServer.get_bus_peak_volume_left_db(master_idx, 0)
		master_peak_r = AudioServer.get_bus_peak_volume_right_db(master_idx, 0)
	var pitch_inst_exists: String = "n/a"
	if music_bus_idx >= 0 and AudioServer.get_bus_effect_count(music_bus_idx) > PITCH_COMPENSATION_EFFECT_IDX:
		var inst := AudioServer.get_bus_effect_instance(music_bus_idx, PITCH_COMPENSATION_EFFECT_IDX)
		pitch_inst_exists = str(inst != null)
	return "ts=%d reason=%s gt=%s playing=%s pos=%.3f paused=%s stream=%s pitch=%.3f loop=%s len=%.3f bus=%s focus=%s pause=%s scene=%s path=%s has_playback=%s playback_valid=%s music_peak_L=%.1f music_peak_R=%.1f master_peak_L=%.1f master_peak_R=%.1f pitch_inst_exists=%s %s" % [ts, reason, gt, str(playing), pos, str(paused), stream_id.get_file() if stream_id != "(null)" else "(null)", pitch, loop_s, len_s, bus, focus, pause_st, scene, current_game_music_file.get_file() if current_game_music_file != "" else "(empty)", str(has_playback), playback_valid, music_peak_l, music_peak_r, master_peak_l, master_peak_r, pitch_inst_exists, variant]

func _diag_get_fade_state() -> String:
	var valid := is_instance_valid(_game_music_fade_tween)
	var running := false
	var is_valid_tween := false
	if valid and _game_music_fade_tween != null:
		var tw: Tween = _game_music_fade_tween as Tween
		if tw != null:
			is_valid_tween = tw.is_valid()
			running = tw.is_running() if is_valid_tween else false
	return "fade_valid=%s is_valid=%s running=%s" % [str(valid), str(is_valid_tween), str(running)]

func _diag_get_pitch_detail() -> String:
	var player_pitch: float = music_player.pitch_scale if music_player else 1.0
	var effect_pitch: String = "n/a"
	var bus_idx: int = AudioServer.get_bus_index(MUSIC_BUS_NAME)
	if bus_idx >= 0 and AudioServer.get_bus_effect_count(bus_idx) > PITCH_COMPENSATION_EFFECT_IDX:
		var fx := AudioServer.get_bus_effect(bus_idx, PITCH_COMPENSATION_EFFECT_IDX)
		if fx != null and fx is AudioEffectPitchShift:
			effect_pitch = "%.3f" % (fx as AudioEffectPitchShift).pitch_scale
	return "player_pitch=%.3f effect_pitch=%s rate=%.3f preserve=%s bus_idx=%d" % [player_pitch, effect_pitch, _game_playback_rate, str(_preserve_pitch), bus_idx]

func _diag_log_fade_and_pitch(prefix: String, reason: String) -> void:
	if not _diag_should_trace_game():
		return
	_mm_trace_game(prefix + ":fade", _diag_get_fade_state() + " " + _diag_build_state(reason + "_fade"))
	_mm_trace_game(prefix + ":pitch", _diag_get_pitch_detail() + " " + _diag_build_state(reason + "_pitch"))

func _diag_trace_before(op: String, detail: String, path_hint: String = "") -> void:
	var should := false
	if path_hint != "":
		should = _diag_is_astrid_path(path_hint)
	else:
		should = _diag_should_trace_game()
	if not should and path_hint != "" and _diag_is_astrid_path(path_hint):
		should = true
	if not should:
		return
	# Track intermediate ops between play and playing_false for controlled AB
	if op.contains("stop"):
		_diag_last_play_had_stop = true
	elif op.contains("stream_assign"):
		_diag_last_play_had_stream = true
	elif op.contains("seek"):
		_diag_last_play_had_seek = true
	elif op.contains("play_in_play_stream_on") or op.contains("set_music_position:play"):
		_diag_last_play_had_play = true
	_mm_trace_game(op, detail + " " + _diag_build_state(op))

func _diag_record_controlled_play(req_pos: float, stream: AudioStream) -> void:
	# Called from play_game_music_at_position for astrid, read-only
	if not _diag_is_astrid_path(current_game_music_file) and not _diag_is_astrid_path(String(stream.resource_path) if stream and String(stream.resource_path) != "" else ""):
		# Also check if stream is astrid imported variant via type/len heuristic — fallback to should_trace after assignment
		if not _diag_should_trace_game():
			# If this is the initial astrid play where current is still previous file, check req hint via caller: we already gated via caller path_hint
			pass
	_diag_last_play_req_pos = req_pos
	_diag_last_play_ts = Time.get_ticks_msec()
	_diag_last_play_had_stop = false
	_diag_last_play_had_stream = false
	_diag_last_play_had_seek = false
	_diag_last_play_had_play = false
	_diag_at73_logged = false
	if stream and stream.has_method("get_length"):
		_diag_last_play_stream_len = float(stream.get_length())
	else:
		_diag_last_play_stream_len = 0.0
	_diag_last_play_pitch = music_player.pitch_scale if music_player else 1.0
	_diag_last_play_bus = String(music_player.bus) if music_player else "(null)"
	var stream_id := "(null)"
	if stream:
		var rp := String(stream.resource_path)
		stream_id = rp if rp != "" else String(stream.get_class())
	var playing_after := false
	var pos_after := 0.0
	# Caller will have already done play, so we log after — this is pre-log, actual after will be in did_play
	_mm_trace_game("diag_controlled_ab:record", "req=%.3f stream=%s len=%.3f pitch=%.3f bus=%s %s" % [req_pos, stream_id.get_file() if stream_id != "(null)" else stream.get_class(), _diag_last_play_stream_len, _diag_last_play_pitch, _diag_last_play_bus, _diag_build_state("record")])

func diag_controlled_ab_test(pos: float) -> void:
	# Public helper for manual controlled A/B via debug console: MusicManager.diag_controlled_ab_test(1.0)
	# Uses same imported stream as normal gameplay, no logic change
	var path := current_game_music_file
	if not _diag_is_astrid_path(path):
		path = AB_ASTRID_IMPORTED_RES_PATH
		if not ResourceLoader.exists(path):
			path = AB_ASTRID_FILE
	_mm_trace_game("diag_controlled_ab:manual_req", "pos=%.3f path=%s" % [pos, path.get_file()])
	play_game_music_at_position(path, pos)

func _diag_watch_check(reason: String) -> void:
	if music_player == null:
		return
	var cur_playing: Variant = music_player.playing
	var cur_paused: Variant = music_player.stream_paused
	var cur_stream_id: String = ""
	if music_player.stream:
		var rp := String(music_player.stream.resource_path)
		cur_stream_id = rp if rp != "" else String(music_player.stream.get_class())
	else:
		cur_stream_id = "(null)"
	var cur_path: String = current_game_music_file
	if _diag_watch_last_playing == null:
		_diag_watch_last_playing = cur_playing
		_diag_watch_last_paused = cur_paused
		_diag_watch_last_stream_id = cur_stream_id
		_diag_watch_last_path = cur_path
		return
	var changed := false
	if cur_playing != _diag_watch_last_playing:
		changed = true
	if cur_paused != _diag_watch_last_paused:
		changed = true
	if cur_stream_id != _diag_watch_last_stream_id:
		changed = true
	if cur_path != _diag_watch_last_path:
		changed = true
	if not changed:
		return
	var is_astrid_now := _diag_is_astrid_path(cur_path) or _diag_is_astrid_path(_diag_watch_last_path) or _diag_should_trace_game()
	if not is_astrid_now:
		_diag_watch_last_playing = cur_playing
		_diag_watch_last_paused = cur_paused
		_diag_watch_last_stream_id = cur_stream_id
		_diag_watch_last_path = cur_path
		return
	var old_p: Variant = _diag_watch_last_playing
	var old_paused: Variant = _diag_watch_last_paused
	var old_stream: String = _diag_watch_last_stream_id
	var old_path: String = _diag_watch_last_path
	var detail := _diag_build_state(reason)
	detail += " CHG playing %s->%s paused %s->%s stream %s->%s path %s->%s" % [str(old_p), str(cur_playing), str(old_paused), str(cur_paused), old_stream.get_file() if old_stream != "(null)" and old_stream != "" else "(null)", cur_stream_id.get_file() if cur_stream_id != "(null)" and cur_stream_id != "" else "(null)", old_path.get_file() if old_path != "" else "(empty)", cur_path.get_file() if cur_path != "" else "(empty)"]
	_mm_trace_game("diag_watch:" + reason, detail)
	if old_p == true and cur_playing == false:
		var elapsed := 0
		if _diag_last_play_ts > 0:
			elapsed = Time.get_ticks_msec() - _diag_last_play_ts
		var inter := "stop=%s stream=%s seek=%s play=%s" % [str(_diag_last_play_had_stop), str(_diag_last_play_had_stream), str(_diag_last_play_had_seek), str(_diag_last_play_had_play)]
		var cur_pos := 0.0
		if music_player and music_player.has_method("get_playback_position"):
			cur_pos = music_player.get_playback_position()
		_mm_trace_game("diag_transition:playing_true_to_false", detail + " *** PLAYING LOST *** elapsed=%dms req_pos=%.3f cur_pos=%.3f len=%.3f inter=[%s]" % [elapsed, _diag_last_play_req_pos, cur_pos, _diag_last_play_stream_len, inter])
		# DIAG A/B: fade and pitch state at exact moment of loss (read-only)
		_mm_trace_game("diag_fade:at_lost", _diag_get_fade_state() + " " + _diag_build_state("at_lost_fade"))
		_mm_trace_game("diag_pitch:at_lost", _diag_get_pitch_detail() + " " + _diag_build_state("at_lost_pitch"))
	if old_stream != cur_stream_id:
		_mm_trace_game("diag_transition:stream_change", detail + " *** STREAM CHANGE ***")
	_diag_watch_last_playing = cur_playing
	_diag_watch_last_paused = cur_paused
	_diag_watch_last_stream_id = cur_stream_id
	_diag_watch_last_path = cur_path

func _load_audio_stream(path: String, base_dir: String = "") -> AudioStream:
	var full_path = (base_dir + path) if base_dir != "" else path
	var started_ms := Time.get_ticks_msec()
	var stream: AudioStream = null
	# A/B diagnostic: log actual full_path for astrid to make branch visible (no gameplay change).
	var _ab_is_astrid: bool = String(full_path).get_file().strip_edges().to_lower() == AB_ASTRID_FILE.to_lower() or String(full_path).to_lower().contains("astrid") and String(full_path).to_lower().contains("glaive")
	if _ab_is_astrid:
		var _ab_exists: bool = ResourceLoader.exists(AB_ASTRID_IMPORTED_RES_PATH)
		_mm_trace_game("load_audio_stream:ab_check", "full_path='%s' file='%s' imported='%s' exists=%s cache_has=%s" % [full_path, String(full_path).get_file(), AB_ASTRID_IMPORTED_RES_PATH, str(_ab_exists), str(_stream_cache.has(full_path))])
	# For the single A/B file, prefer imported res:// AudioStream if available (clean experiment).
	# Check BEFORE cache so cached runtime_data does not shadow imported_res.
	if _ab_is_astrid and ResourceLoader.exists(AB_ASTRID_IMPORTED_RES_PATH):
		# If cache already has imported_res, reuse it (keep variant=imported_res).
		if _stream_cache.has(full_path):
			var _cached_ab = _stream_cache[full_path] as AudioStream
			if _cached_ab != null and String(_cached_ab.resource_path) != "":
				# Already imported_res — keep it, but log to confirm.
				_mm_trace_game("load_audio_stream:ab_imported_cached", "full_path='%s' cached_resource='%s' variant=imported_res" % [full_path, String(_cached_ab.resource_path)])
				return _cached_ab
			else:
				_mm_trace_game("load_audio_stream:ab_cache_overwrite", "full_path='%s' cached_variant=runtime_data -> will replace with imported_res" % full_path)
		var imported := load(AB_ASTRID_IMPORTED_RES_PATH) as AudioStream
		if imported != null:
			var imp_len := float(imported.get_length()) if imported.has_method("get_length") else 0.0
			var imp_loop := "n/a"
			if imported is AudioStreamMP3:
				imp_loop = str((imported as AudioStreamMP3).loop)
			_mm_trace_game("load_audio_stream:ab_imported_res", "full_path='%s' imported='%s' type=%s loop=%s len=%.3f variant=imported_res" % [full_path, AB_ASTRID_IMPORTED_RES_PATH, imported.get_class(), imp_loop, imp_len])
			# Use imported directly; cache under original full_path key for consistency.
			_stream_cache[full_path] = imported
			_log_perf("audio sync load (ab imported_res) " + full_path, started_ms)
			return imported
		else:
			_mm_trace_game("load_audio_stream:ab_imported_fail", "full_path='%s' imported='%s' variant=runtime_data fallback" % [full_path, AB_ASTRID_IMPORTED_RES_PATH])
	if _stream_cache.has(full_path):
		return _stream_cache[full_path]
	# Default path: runtime_data via FilePathUtils (AudioStreamMP3.new() data=bytes for non-res)
	stream = FilePathUtils.load_audio_stream_for_path(full_path)
	_log_perf("audio sync load " + full_path, started_ms)
	if stream:
		# A/B diagnostic spam reduction: only for astrid target, not for WAV/UI SFX
		if _ab_is_astrid:
			var _ab_variant := "runtime_data"
			if String(stream.resource_path) != "":
				_ab_variant = "imported_res"
			var _ab_len2 := float(stream.get_length()) if stream.has_method("get_length") else 0.0
			var _ab_loop2 := "n/a"
			if stream is AudioStreamMP3:
				_ab_loop2 = str((stream as AudioStreamMP3).loop)
			_mm_trace_game("load_audio_stream:ab_runtime_data", "req=%s variant=%s type=%s loop=%s len=%.3f" % [full_path.get_file(), _ab_variant, stream.get_class(), _ab_loop2, _ab_len2])
		_stream_cache[full_path] = stream
	return stream

func _log_perf(label: String, started_ms: int, threshold_ms: int = PERF_LOG_THRESHOLD_MS) -> void:
	var elapsed := Time.get_ticks_msec() - started_ms
	if elapsed >= threshold_ms:
		print("[Perf] MusicManager %s: %d ms" % [label, elapsed])

func load_audio_stream_async(path: String, base_dir: String = "", callback: Callable = Callable()) -> void:
	var full_path = (base_dir + path) if base_dir != "" else path
	if _stream_cache.has(full_path):
		if callback.is_valid():
			callback.call_deferred(_stream_cache[full_path])
		return
	if _async_audio_threads.has(full_path):
		if callback.is_valid():
			var callbacks: Array = _async_audio_callbacks.get(full_path, [])
			callbacks.append(callback)
			_async_audio_callbacks[full_path] = callbacks
		return
	var thread := Thread.new()
	if callback.is_valid():
		_async_audio_callbacks[full_path] = [callback]
	else:
		_async_audio_callbacks[full_path] = []
	_async_audio_started_ms[full_path] = Time.get_ticks_msec()
	var err := thread.start(Callable(self, "_load_audio_stream_worker").bind(full_path))
	if err != OK:
		_async_audio_callbacks.erase(full_path)
		_async_audio_started_ms.erase(full_path)
		if callback.is_valid():
			callback.call_deferred(null)
		printerr("MusicManager: Не удалось запустить поток загрузки аудио: " + str(err))
		return
	_async_audio_threads[full_path] = thread
	call_deferred("_poll_async_audio", full_path)

func _load_audio_stream_worker(full_path: String) -> AudioStream:
	return FilePathUtils.load_audio_stream_for_path(full_path)

func _poll_async_audio(full_path: String) -> void:
	if not _async_audio_threads.has(full_path):
		return
	var thread: Thread = _async_audio_threads[full_path]
	if thread and thread.is_alive():
		await get_tree().process_frame
		call_deferred("_poll_async_audio", full_path)
		return
	var stream = thread.wait_to_finish() if thread else null
	if stream and stream is AudioStream:
		_stream_cache[full_path] = stream
	var callbacks: Array = _async_audio_callbacks.get(full_path, [])
	var started_ms := int(_async_audio_started_ms.get(full_path, Time.get_ticks_msec()))
	_log_perf("audio async load " + full_path, started_ms, 1)
	_async_audio_threads.erase(full_path)
	_async_audio_callbacks.erase(full_path)
	_async_audio_started_ms.erase(full_path)
	for cb in callbacks:
		if cb is Callable and cb.is_valid():
			cb.call_deferred(stream)

func _play_stream_on(player: AudioStreamPlayer, stream: AudioStream, volume_pct: float, position: float = 0.0, restart_if_playing: bool = true, enable_loop: bool = true):
	if not player or not stream:
		return
	if player == music_player:
		_diag_trace_before("diag_before:_play_stream_on:enter", "stream=%s pos=%.3f restart=%s loop=%s vol=%.1f" % [stream.get_class(), position, str(restart_if_playing), str(enable_loop), volume_pct], current_game_music_file)
		_diag_watch_check("before_play_stream_on")
	if restart_if_playing and player.playing:
		if player == music_player:
			_diag_trace_before("diag_before:stop_in_play_stream_on", "will_stop playing=%s pos=%.3f" % [str(player.playing), player.get_playback_position() if player.has_method("get_playback_position") else 0.0], current_game_music_file)
		player.stop()
		if player == music_player:
			_diag_watch_check("after_stop_in_play_stream_on")
	if enable_loop:
		_enable_stream_loop_if_supported(stream)
	else:
		_disable_stream_loop_if_supported(stream)
	if player == music_player:
		var old_id := "(null)"
		if player.stream:
			var rp0 := String(player.stream.resource_path)
			old_id = rp0 if rp0 != "" else String(player.stream.get_class())
		var new_id := String(stream.resource_path)
		new_id = new_id if new_id != "" else String(stream.get_class())
		_diag_trace_before("diag_before:stream_assign_in_play_stream_on", "old=%s new=%s" % [old_id.get_file() if old_id != "(null)" else "(null)", new_id.get_file() if new_id != "(null)" else "(null)"], current_game_music_file)
	player.stream = stream
	if player == music_player:
		_diag_watch_check("after_stream_assign")
	player.volume_db = linear_to_db(volume_pct / 100.0)
	if player == music_player:
		_apply_game_playback_rate_to_player()
	if player == music_player:
		_diag_trace_before("diag_before:play_in_play_stream_on", "pos=%.3f pitch=%.2f bus=%s" % [position, player.pitch_scale if player else 1.0, player.bus if player else ""], current_game_music_file)
	player.play(position)
	if player == music_player:
		_diag_watch_check("after_play_in_play_stream_on")


func _enable_stream_loop_if_supported(stream: AudioStream) -> void:
	if stream == null:
		return
	# DIAG: log loop change for game stream (read-only trace)
	var old_loop := "n/a"
	if stream is AudioStreamMP3:
		old_loop = str((stream as AudioStreamMP3).loop)
	elif stream is AudioStreamOggVorbis:
		old_loop = str((stream as AudioStreamOggVorbis).loop)
	elif stream is AudioStreamWAV:
		old_loop = str((stream as AudioStreamWAV).loop_mode)
	# Native loop survives OS suspend better than finished→play(0) alone.
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	if _diag_should_trace_game() or (stream != null and _diag_is_astrid_path(String(stream.resource_path) if String(stream.resource_path) != "" else "")):
		var new_loop := "n/a"
		if stream is AudioStreamMP3:
			new_loop = str((stream as AudioStreamMP3).loop)
		elif stream is AudioStreamOggVorbis:
			new_loop = str((stream as AudioStreamOggVorbis).loop)
		if old_loop != new_loop:
			_mm_trace_game("diag_loop:enable", "old=%s new=%s stream=%s %s" % [old_loop, new_loop, String(stream.resource_path).get_file() if String(stream.resource_path) != "" else stream.get_class(), _diag_build_state("loop_enable")])
	# WAV keeps finished→replay via _connect_menu_loop (loop_end needs sample frames).


# Game tracks must NOT loop: a native loop rewinds the playhead at the song's
# end, which resets game_time (the drift-sync snaps it back to ~0) and the run
# never reaches the victory/results transition. Menu/ambient loops stay on.
func _disable_stream_loop_if_supported(stream: AudioStream) -> void:
	if stream == null:
		return
	var old_loop := "n/a"
	if stream is AudioStreamMP3:
		old_loop = str((stream as AudioStreamMP3).loop)
	elif stream is AudioStreamOggVorbis:
		old_loop = str((stream as AudioStreamOggVorbis).loop)
	elif stream is AudioStreamWAV:
		old_loop = str((stream as AudioStreamWAV).loop_mode)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = false
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = false
	if _diag_should_trace_game() or (stream != null and _diag_is_astrid_path(String(stream.resource_path) if String(stream.resource_path) != "" else "")):
		var new_loop := "n/a"
		if stream is AudioStreamMP3:
			new_loop = str((stream as AudioStreamMP3).loop)
		elif stream is AudioStreamOggVorbis:
			new_loop = str((stream as AudioStreamOggVorbis).loop)
		if old_loop != new_loop:
			_mm_trace_game("diag_loop:disable", "old=%s new=%s stream=%s %s" % [old_loop, new_loop, String(stream.resource_path).get_file() if String(stream.resource_path) != "" else stream.get_class(), _diag_build_state("loop_disable")])


func _ensure_music_bus() -> int:
	var idx := AudioServer.get_bus_index(MUSIC_BUS_NAME)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, MUSIC_BUS_NAME)
		AudioServer.set_bus_send(idx, "Master")
	return idx


func _ensure_pitch_compensation_effect() -> AudioEffectPitchShift:
	AudioSpectrumReader._ensure_music_bus()
	var idx := AudioServer.get_bus_index(MUSIC_BUS_NAME)
	if idx < 0:
		idx = _ensure_music_bus()
	if AudioServer.get_bus_effect_count(idx) <= PITCH_COMPENSATION_EFFECT_IDX:
		AudioServer.add_bus_effect(idx, AudioEffectPitchShift.new(), PITCH_COMPENSATION_EFFECT_IDX)
	var fx := AudioServer.get_bus_effect(idx, PITCH_COMPENSATION_EFFECT_IDX)
	if fx is AudioEffectPitchShift:
		return fx as AudioEffectPitchShift
	var pitch_fx := AudioEffectPitchShift.new()
	AudioServer.add_bus_effect(idx, pitch_fx, PITCH_COMPENSATION_EFFECT_IDX)
	return pitch_fx


func _apply_game_playback_rate_to_player() -> void:
	if music_player == null:
		return
	if current_game_music_file == "":
		music_player.pitch_scale = 1.0
		var idle_comp := _ensure_pitch_compensation_effect()
		if idle_comp:
			idle_comp.pitch_scale = 1.0
		return
	var rate := clampf(_game_playback_rate, 0.25, 4.0)
	var old_pitch := music_player.pitch_scale
	if _diag_should_trace_game() and not is_equal_approx(old_pitch, rate):
		_diag_trace_before("diag_before:pitch_change", "old=%.3f new=%.3f preserve=%s" % [old_pitch, rate, str(_preserve_pitch)], current_game_music_file)
	music_player.pitch_scale = rate
	var comp := _ensure_pitch_compensation_effect()
	if comp:
		if not _preserve_pitch:
			comp.pitch_scale = 1.0
		else:
			comp.pitch_scale = 1.0 if is_equal_approx(rate, 1.0) else 1.0 / rate
	if _diag_should_trace_game() and not is_equal_approx(old_pitch, rate):
		_diag_watch_check("after_pitch_change")


func set_game_pitch_scale(scale: float) -> void:
	_game_playback_rate = clampf(scale, 0.25, 4.0)
	_apply_game_playback_rate_to_player()


func get_game_pitch_scale() -> float:
	return _game_playback_rate


func set_preserve_pitch(enabled: bool) -> void:
	_preserve_pitch = enabled
	_apply_game_playback_rate_to_player()


func get_preserve_pitch() -> bool:
	return _preserve_pitch

func _process(_delta: float) -> void:
	# read-only watcher, compact: only for astrid game track, logs only on change
	if current_game_music_file != "" and _diag_is_astrid_path(current_game_music_file):
		_diag_watch_check("process")
		# READ-ONLY AT-7.3 probe for silent playback with advancing position
		if not _diag_at73_logged and music_player and music_player.playing:
			var pos_at := music_player.get_playback_position() if music_player.has_method("get_playback_position") else 0.0
			if pos_at >= 7.0 and pos_at <= 7.6:
				_diag_at73_logged = true
				_mm_trace_game("diag_at73", _diag_build_state("at73"))

func _ready():
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = MUSIC_BUS_NAME
	add_child(music_player)
	# Diagnostic watcher: enable process polling for astrid (read-only, no behavior)
	set_process(true)
	# Diagnostic finished trace (read-only, does not affect menu loop logic).
	var _diag_cb := Callable(self, "_on_music_player_finished_diag")
	if music_player and not music_player.is_connected("finished", _diag_cb):
		music_player.connect("finished", _diag_cb)
	# init watcher
	_diag_watch_last_playing = null
	_diag_watch_last_paused = null
	_diag_watch_last_stream_id = ""
	_diag_watch_last_path = ""
	call_deferred("_setup_music_bus_pitch_compensation")

	sfx_player = AudioStreamPlayer.new() 
	sfx_player.name = "SFXPlayer"
	add_child(sfx_player)

	hit_sound_player = AudioStreamPlayer.new()
	hit_sound_player.name = "HitSoundPlayer"
	add_child(hit_sound_player)
	for i in range(HIT_POOL_SIZE):
		var hp = AudioStreamPlayer.new()
		hp.name = "HitPool_%d" % i
		add_child(hp)
		_hit_pool.append(hp)

	metronome_player1 = AudioStreamPlayer.new()
	metronome_player1.name = "MetronomePlayer1"
	add_child(metronome_player1)

	metronome_player2 = AudioStreamPlayer.new()
	metronome_player2.name = "MetronomePlayer2"
	add_child(metronome_player2)

	_metronome_players = [metronome_player1, metronome_player2]
	_update_active_sound_paths()
	_init_sfx_pool()
	_preload_common_sfx()


func _setup_music_bus_pitch_compensation() -> void:
	AudioSpectrumReader._ensure_music_bus()
	_ensure_pitch_compensation_effect()
	_apply_game_playback_rate_to_player()


func set_external_metronome_control(enabled: bool):
	_external_metronome_controlled = enabled
	if not enabled:
		_last_beat_index = -1

func update_metronome(delta: float, game_time: float, bpm: float):
	if not _external_metronome_controlled or bpm <= 0:
		return
	var time_since_offset = game_time

	var beat_interval = 60.0 / bpm
	var current_beat_index = int(floor(time_since_offset / beat_interval))
	var is_strong_beat = (current_beat_index % 4) == 0

	if current_beat_index != _last_beat_index:
		_last_beat_index = current_beat_index
		play_metronome_sound(is_strong_beat)


func get_volume_multiplier() -> float:
	if music_player:
		return db_to_linear(music_player.volume_db)
	return 1.0

func set_music_volume_multiplier(volume: float):
	print("[REPLAY AUDIO DEBUG] set_music_volume_multiplier %s source=music_manager" % str(volume))
	if music_player:
		music_player.volume_db = linear_to_db(clampf(volume, 0.0, 1.0))


func set_game_music_muted(muted: bool) -> void:
	if music_player == null:
		return
	if _diag_should_trace_game():
		_diag_trace_before("diag_before:set_game_music_muted", "muted=%s old_db=%.1f" % [str(muted), music_player.volume_db], current_game_music_file)
	if muted:
		music_player.volume_db = -80.0
	else:
		var game_vol := (
			SettingsManager.get_music_volume()
			if SettingsManager.has_method("get_music_volume")
			else _game_music_volume_pct
		)
		music_player.volume_db = linear_to_db(game_vol / 100.0)
	if _diag_should_trace_game():
		_diag_watch_check("after_set_game_music_muted")

func get_game_music_position() -> float:
	if music_player and music_player.stream and current_game_music_file != "":
		if music_player.playing:
			return music_player.get_playback_position()
		else:
			return 0.0
	return 0.0

func get_game_music_position_precise() -> float:
	if music_player and music_player.stream and current_game_music_file != "" and music_player.playing:
		return music_player.get_playback_position() + AudioServer.get_time_since_last_mix()
	return 0.0

func stop_game_music():
	# Trace before early-out so invariant investigation sees every stop attempt (reason inferred from caller: game_screen _update fallback/pause/cleanup).
	if music_player:
		_mm_trace_game("stop_game_music", "req file=%s has_stream=%s will_stop=%s" % [current_game_music_file.get_file() if current_game_music_file != "" else "(empty)", str(music_player.stream != null), str(music_player.playing and music_player.stream != null and current_game_music_file != "")])
	_diag_trace_before("diag_before:stop_game_music", "req will_stop=%s" % str(music_player.playing and music_player.stream != null and current_game_music_file != ""), current_game_music_file)
	if music_player and music_player.stream and current_game_music_file != "":
		if music_player.playing:
			menu_music_position_before_shop = music_player.get_playback_position()
			_diag_trace_before("diag_before:stop_game_music:will_stop", "pos=%.3f" % menu_music_position_before_shop, current_game_music_file)
			music_player.stop()
			_diag_watch_check("after_stop_game_music:did_stop")
			_mm_trace_game("stop_game_music:did_stop", "saved_pos=%.3f" % menu_music_position_before_shop)
			current_game_music_file = ""
			_game_playback_rate = 1.0
			_apply_game_playback_rate_to_player()
			return
		else:
			menu_music_position_before_shop = 0.0
			_mm_trace_game("stop_game_music:noop_not_playing", "file=%s" % current_game_music_file.get_file())
	else:
		pass 


func force_stop_game_track() -> void:
	_mm_trace_game("force_stop_game_track", "file=%s playing=%s" % [current_game_music_file.get_file() if current_game_music_file != "" else "(empty)", str(music_player.playing if music_player else false)])
	_diag_trace_before("diag_before:force_stop_game_track", "playing=%s paused=%s" % [str(music_player.playing if music_player else false), str(music_player.stream_paused if music_player else false)], current_game_music_file)
	if music_player:
		if music_player.playing:
			_diag_trace_before("diag_before:force_stop:will_stop", "pos=%.3f" % music_player.get_playback_position(), current_game_music_file)
			music_player.stop()
			_diag_watch_check("after_force_stop:stop")
		var old_paused := music_player.stream_paused
		if old_paused != false and _diag_should_trace_game():
			_diag_trace_before("diag_before:force_stop:clear_paused", "old=%s" % str(old_paused), current_game_music_file)
		music_player.stream_paused = false
		if old_paused != false:
			_diag_watch_check("after_force_stop:clear_paused")
	current_game_music_file = ""
	_game_playback_rate = 1.0
	_apply_game_playback_rate_to_player()

func play_game_music_at_position(song_path: String, position: float):
	_diag_trace_before("diag_before:play_game_music_at_position:req", "path=%s pos=%.3f" % [song_path.get_file(), position], song_path)
	_mm_trace_game("play_game_music_at_position:req", "path=%s pos=%.3f %s" % [song_path.get_file(), position, _mm_stream_diag()])
	var stream = _load_audio_stream(song_path)
	if not stream:
		push_error("MusicManager.gd: Файл игровой музыки не найден: " + song_path)
		_mm_trace_game("play_game_music_at_position:fail_load", "path=%s" % song_path.get_file())
		return
	# Pre-launch diag: stream to be assigned (type/loop/len of incoming stream)
	var _pre_loop := "n/a"
	if stream is AudioStreamMP3:
		_pre_loop = str((stream as AudioStreamMP3).loop)
	elif stream is AudioStreamOggVorbis:
		_pre_loop = str((stream as AudioStreamOggVorbis).loop)
	var _pre_len := float(stream.get_length()) if stream.has_method("get_length") else 0.0
	_mm_trace_game("play_game_music_at_position:pre_launch", "incoming_type=%s incoming_loop=%s incoming_len=%.3f req_pos=%.3f cur_%s" % [stream.get_class(), _pre_loop, _pre_len, position, _mm_stream_diag()])
	# Controlled A/B: record requested position and stream details for astrid (read-only)
	if _diag_is_astrid_path(song_path):
		_diag_record_controlled_play(position, stream)
		# Also immediate pre-play detailed snapshot for A/B table
		var _ab_bus: String = String(music_player.bus) if music_player else "(null)"
		var _ab_pitch: float = music_player.pitch_scale if music_player else 1.0
		var _ab_paused: bool = music_player.stream_paused if music_player else false
		_mm_trace_game("diag_controlled_ab:pre_play", "req=%.3f actual_before=%.3f playing=%s paused=%s type=%s path=%s len=%.3f loop=%s pitch=%.3f bus=%s %s" % [position, music_player.get_playback_position() if music_player else 0.0, str(music_player.playing if music_player else false), str(_ab_paused), stream.get_class(), String(stream.resource_path) if String(stream.resource_path) != "" else stream.get_class(), _pre_len, _pre_loop, _ab_pitch, _ab_bus, _diag_build_state("pre_play")])
	if music_player:
		_cancel_game_music_fade()
		current_game_music_file = song_path
		_preserve_pitch = true
		var game_vol = SettingsManager.get_music_volume() if SettingsManager.has_method("get_music_volume") else _game_music_volume_pct
		# Minimal refactor: seek same stream instead of stop/stream/play (skip_intro case)
		var same_stream := music_player.stream != null and music_player.stream == stream
		if same_stream:
			if music_player.playing and not music_player.stream_paused:
				# DIAG A/B: fade and pitch state immediately before seek (read-only)
				_diag_log_fade_and_pitch("diag_pre_seek", "seek")
				_diag_trace_before("diag_before:seek_same_stream", "seek to %.3f same_stream true" % position, song_path)
				music_player.seek(position)
				_diag_watch_check("after_seek_same_stream")
				# DIAG: pitch/fade immediately after seek
				_diag_log_fade_and_pitch("diag_post_seek", "seek")
				# Preserve pitch if architecture requires (no stop/play)
				# _apply_game_playback_rate_to_player() already correct for same stream; keep as is for minimal change
				_mm_trace_game("play_game_music_at_position:did_play", "path=%s pos=%.3f %s playing=%s playback=%.3f seek_same_stream" % [song_path.get_file(), position, _mm_stream_diag(), str(music_player.playing), music_player.get_playback_position() if music_player else 0.0])
				if _diag_is_astrid_path(song_path):
					var _ab_actual: float = music_player.get_playback_position() if music_player else 0.0
					var _ab_playing: bool = music_player.playing if music_player else false
					var _ab_paused2: bool = music_player.stream_paused if music_player else false
					var _ab_bus2: String = String(music_player.bus) if music_player else "(null)"
					var _ab_pitch2: float = music_player.pitch_scale if music_player else 1.0
					_mm_trace_game("diag_controlled_ab:did_play", "req=%.3f actual=%.3f playing=%s paused=%s type=%s path=%s len=%.3f loop=%s pitch=%.3f bus=%s seek_same_stream %s" % [position, _ab_actual, str(_ab_playing), str(_ab_paused2), stream.get_class(), String(stream.resource_path) if String(stream.resource_path) != "" else stream.get_class(), _pre_len, _pre_loop, _ab_pitch2, _ab_bus2, _diag_build_state("did_play")])
				_apply_game_playback_rate_to_player()
			elif not music_player.playing and not music_player.stream_paused:
				_diag_trace_before("diag_before:play_same_stream_stopped", "play to %.3f same_stream true" % position, song_path)
				music_player.play(position)
				_diag_watch_check("after_play_same_stream_stopped")
				_mm_trace_game("play_game_music_at_position:did_play", "path=%s pos=%.3f %s playing=%s playback=%.3f play_same_stream" % [song_path.get_file(), position, _mm_stream_diag(), str(music_player.playing), music_player.get_playback_position() if music_player else 0.0])
				if _diag_is_astrid_path(song_path):
					var _ab_actual2: float = music_player.get_playback_position() if music_player else 0.0
					var _ab_playing2: bool = music_player.playing if music_player else false
					var _ab_paused3: bool = music_player.stream_paused if music_player else false
					var _ab_bus3: String = String(music_player.bus) if music_player else "(null)"
					var _ab_pitch3: float = music_player.pitch_scale if music_player else 1.0
					_mm_trace_game("diag_controlled_ab:did_play", "req=%.3f actual=%.3f playing=%s paused=%s type=%s path=%s len=%.3f loop=%s pitch=%.3f bus=%s play_same_stream %s" % [position, _ab_actual2, str(_ab_playing2), str(_ab_paused3), stream.get_class(), String(stream.resource_path) if String(stream.resource_path) != "" else stream.get_class(), _pre_len, _pre_loop, _ab_pitch3, _ab_bus3, _diag_build_state("did_play")])
				_apply_game_playback_rate_to_player()
			else:
				# stream_paused == true: preserve pause semantics, use existing switch path
				_play_stream_on(music_player, stream, game_vol, position, true, false)
				_mm_trace_game("play_game_music_at_position:did_play", "path=%s pos=%.3f %s playing=%s playback=%.3f switch_paused" % [song_path.get_file(), position, _mm_stream_diag(), str(music_player.playing), music_player.get_playback_position() if music_player else 0.0])
				if _diag_is_astrid_path(song_path):
					var _ab_actual3: float = music_player.get_playback_position() if music_player else 0.0
					var _ab_playing3: bool = music_player.playing if music_player else false
					var _ab_paused4: bool = music_player.stream_paused if music_player else false
					var _ab_bus4: String = String(music_player.bus) if music_player else "(null)"
					var _ab_pitch4: float = music_player.pitch_scale if music_player else 1.0
					_mm_trace_game("diag_controlled_ab:did_play", "req=%.3f actual=%.3f playing=%s paused=%s type=%s path=%s len=%.3f loop=%s pitch=%.3f bus=%s switch_paused %s" % [position, _ab_actual3, str(_ab_playing3), str(_ab_paused4), stream.get_class(), String(stream.resource_path) if String(stream.resource_path) != "" else stream.get_class(), _pre_len, _pre_loop, _ab_pitch4, _ab_bus4, _diag_build_state("did_play")])
				_apply_game_playback_rate_to_player()
		else:
			_play_stream_on(music_player, stream, game_vol, position, true, false)
			_mm_trace_game("play_game_music_at_position:did_play", "path=%s pos=%.3f %s playing=%s playback=%.3f" % [song_path.get_file(), position, _mm_stream_diag(), str(music_player.playing), music_player.get_playback_position() if music_player else 0.0])
			if _diag_is_astrid_path(song_path):
				var _ab_actual4: float = music_player.get_playback_position() if music_player else 0.0
				var _ab_playing4: bool = music_player.playing if music_player else false
				var _ab_paused5: bool = music_player.stream_paused if music_player else false
				var _ab_bus5: String = String(music_player.bus) if music_player else "(null)"
				var _ab_pitch5: float = music_player.pitch_scale if music_player else 1.0
				_mm_trace_game("diag_controlled_ab:did_play", "req=%.3f actual=%.3f playing=%s paused=%s type=%s path=%s len=%.3f loop=%s pitch=%.3f bus=%s %s" % [position, _ab_actual4, str(_ab_playing4), str(_ab_paused5), stream.get_class(), String(stream.resource_path) if String(stream.resource_path) != "" else stream.get_class(), _pre_len, _pre_loop, _ab_pitch5, _ab_bus5, _diag_build_state("did_play")])
			_apply_game_playback_rate_to_player()
	else:
		push_error("MusicManager.gd: music_player не установлен!")

func pause_menu_music():
	if music_player and current_menu_music_file != "":
		if music_player.playing:
			was_menu_music_playing_before_shop = true
			menu_music_position_before_shop = music_player.get_playback_position() 
			music_player.stop()
			_menu_music_intentionally_silent = true
		else:
			was_menu_music_playing_before_shop = true
			menu_music_position_before_shop = 0.0
			_menu_music_intentionally_silent = true
	else:
		pass 


func _cancel_game_music_fade() -> void:
	# DIAG: log cancel only for astrid game track (read-only)
	if _diag_should_trace_game() and is_instance_valid(_game_music_fade_tween):
		_mm_trace_game("diag_fade:cancel", _diag_get_fade_state() + " " + _diag_build_state("cancel_fade"))
	if _game_music_fade_tween and is_instance_valid(_game_music_fade_tween):
		_game_music_fade_tween.kill()
	_game_music_fade_tween = null


## Public accessor so UI can cancel a pending game-music fade (e.g. a finished
## pause Practice preview) before resuming playback at full volume.
func cancel_game_music_fade() -> void:
	_cancel_game_music_fade()


## Fades the current game music out and stops it. Used by the pause Practice
## section preview so the preview ends smoothly instead of cutting off. Mirrors
## the existing menu-music fade pattern but on the game track.
func fade_out_game_music(duration: float = 0.6) -> void:
	# DIAG: log request origin for fade tween suspicion (read-only)
	if _diag_should_trace_game():
		_mm_trace_game("diag_fade:request", "dur=%.2f start_db=%.1f %s fade=%s pitch=%s" % [duration, music_player.volume_db if music_player else 0.0, _diag_build_state("fade_request"), _diag_get_fade_state(), _diag_get_pitch_detail()])
	_cancel_game_music_fade()
	if music_player == null:
		return
	if current_game_music_file == "" or not music_player.playing:
		if _diag_should_trace_game():
			_mm_trace_game("diag_fade:skip_not_playing", _diag_get_fade_state() + " " + _diag_build_state("fade_skip"))
		return
	var start_db := music_player.volume_db
	var tween := create_tween()
	_game_music_fade_tween = tween
	tween.tween_method(func(v: float) -> void: music_player.volume_db = v, start_db, -80.0, duration)
	tween.tween_callback(func() -> void:
		# DIAG: log completion callback (potential stop) — read-only trace before stop
		if _diag_should_trace_game() or _diag_is_astrid_path(current_game_music_file):
			_mm_trace_game("diag_fade:callback_before_stop", _diag_get_fade_state() + " " + _diag_get_pitch_detail() + " " + _diag_build_state("fade_callback"))
		if music_player:
			music_player.stop()
			music_player.volume_db = -80.0
		if _diag_should_trace_game() or _diag_is_astrid_path(current_game_music_file):
			_diag_watch_check("after_fade_callback_stop")
		current_game_music_file = ""
		_game_music_fade_tween = null
	)


func _cancel_menu_music_fade() -> void:
	if _menu_music_fade_tween and is_instance_valid(_menu_music_fade_tween):
		_menu_music_fade_tween.kill()
	_menu_music_fade_tween = null


func _target_menu_music_volume_db() -> float:
	var menu_vol := (
		SettingsManager.get_menu_music_volume()
		if SettingsManager.has_method("get_menu_music_volume")
		else _menu_music_volume_pct
	)
	return linear_to_db(menu_vol / 100.0)


func cancel_menu_music_fade() -> void:
	_cancel_menu_music_fade()


func fade_out_menu_music(duration: float = 1.0) -> void:
	_cancel_menu_music_fade()
	_menu_music_intentionally_silent = true
	was_menu_music_playing_before_shop = false
	menu_music_position_before_shop = 0.0
	if music_player == null:
		return
	if current_menu_music_file == "" and current_screen_ambient_file == "":
		if music_player.playing:
			music_player.stop()
		return
	if not music_player.playing:
		music_player.volume_db = -80.0
		return
	var start_db := music_player.volume_db
	var tween := create_tween()
	_menu_music_fade_tween = tween
	tween.tween_method(func(v: float) -> void: music_player.volume_db = v, start_db, -80.0, duration)
	tween.tween_callback(func() -> void:
		if music_player:
			music_player.stop()
			music_player.volume_db = -80.0
		_menu_music_fade_tween = null
	)


func fade_in_menu_music(duration: float = 1.0, restart: bool = true) -> void:
	_cancel_menu_music_fade()
	_menu_music_intentionally_silent = false
	was_menu_music_playing_before_shop = false
	menu_music_position_before_shop = 0.0
	var track := current_menu_music_file
	if track == "":
		track = DEFAULT_MENU_MUSIC
	# Stop any faded mid-track playback first so volume restore cannot unmute it.
	if music_player and music_player.playing:
		music_player.stop()
	if music_player:
		music_player.volume_db = -80.0
	play_menu_music(track, restart)
	if music_player == null:
		return
	var target_db := _target_menu_music_volume_db()
	music_player.volume_db = -80.0
	var tween := create_tween()
	_menu_music_fade_tween = tween
	tween.tween_method(func(v: float) -> void: music_player.volume_db = v, -80.0, target_db, duration)
	tween.tween_callback(func() -> void: _menu_music_fade_tween = null)


func should_restart_menu_music() -> bool:
	return music_player == null or not music_player.playing


func is_menu_music_intentionally_silent() -> bool:
	return _menu_music_intentionally_silent

func resume_menu_music():
	if current_menu_music_file != "":
		if was_menu_music_playing_before_shop:
			if not music_player.playing: 
				music_player.play(menu_music_position_before_shop)
			else:
				pass 
		else:
			if not music_player.playing:
				music_player.play(0.0) 
			else:
				pass 
	else:
		pass 
	was_menu_music_playing_before_shop = false
	menu_music_position_before_shop = 0.0


func on_app_focus_lost() -> void:
	_diag_trace_before("diag_before:on_app_focus_lost", "playing=%s paused=%s path=%s" % [str(music_player.playing if music_player else false), str(music_player.stream_paused if music_player else false), current_game_music_file.get_file() if current_game_music_file != "" else "(empty)"], current_game_music_file)
	if music_player == null:
		_resume_audio_on_focus_in = false
		_resume_game_audio_on_focus_in = false
		_saved_playback_position_on_unfocus = 0.0
		_diag_watch_check("after_on_app_focus_lost:null_player")
		return
	var is_paused := music_player.stream_paused
	_resume_audio_on_focus_in = music_player.playing and not is_paused
	_resume_game_audio_on_focus_in = (
		current_game_music_file != ""
		and music_player.playing
		and not is_paused
	)
	_saved_playback_position_on_unfocus = (
		music_player.get_playback_position() if music_player.playing and not is_paused else 0.0
	)
	_diag_trace_before("diag_before:on_app_focus_lost:saved", "resume=%s resume_game=%s saved_pos=%.3f" % [str(_resume_audio_on_focus_in), str(_resume_game_audio_on_focus_in), _saved_playback_position_on_unfocus], current_game_music_file)
	_diag_watch_check("after_on_app_focus_lost")


func on_app_focus_restored() -> void:
	_diag_trace_before("diag_before:on_app_focus_restored", "resume=%s resume_game=%s playing=%s paused=%s saved=%.3f path=%s" % [str(_resume_audio_on_focus_in), str(_resume_game_audio_on_focus_in), str(music_player.playing if music_player else false), str(music_player.stream_paused if music_player else false), _saved_playback_position_on_unfocus, current_game_music_file.get_file() if current_game_music_file != "" else "(empty)"], current_game_music_file)
	if music_player == null:
		return
	_cancel_menu_music_fade()
	if not _resume_audio_on_focus_in:
		_diag_watch_check("after_on_app_focus_restored:no_resume")
		return
	var old_paused := music_player.stream_paused
	if old_paused != false:
		_diag_trace_before("diag_before:on_app_focus_restored:clear_paused", "old=%s" % str(old_paused), current_game_music_file)
	music_player.stream_paused = false
	if old_paused != false:
		_diag_watch_check("after_on_app_focus_restored:clear_paused")
	if music_player.playing:
		_diag_watch_check("after_on_app_focus_restored:still_playing")
		return
	if _resume_game_audio_on_focus_in and current_game_music_file != "":
		_diag_trace_before("diag_before:on_app_focus_restored:restart_game", "saved_pos=%.3f" % _saved_playback_position_on_unfocus, current_game_music_file)
		music_player.stop()
		_diag_watch_check("after_on_app_focus_restored:stop_before_restart")
		play_game_music_at_position(
			current_game_music_file,
			_saved_playback_position_on_unfocus
		)
		return
	if _menu_music_intentionally_silent:
		return
	var menu_track := current_menu_music_file
	var is_ambient := false
	if menu_track == "":
		menu_track = current_screen_ambient_file
		is_ambient = menu_track != ""
	if menu_track == "":
		return
	# Prefer resume on the already-loaded stream. restart=true reloads/decodes
	# the whole file and feels like a long stall after a long minimize.
	var pos := _menu_resume_position(_saved_playback_position_on_unfocus)
	if music_player.stream != null:
		music_player.play(pos)
		_connect_menu_loop()
		return
	if is_ambient:
		play_screen_ambient_music(menu_track, false)
	else:
		play_menu_music(menu_track, false)
	if pos > 0.05 and music_player:
		music_player.play(pos)


func _menu_resume_position(saved_pos: float) -> float:
	var pos := maxf(0.0, saved_pos)
	if music_player == null or music_player.stream == null:
		return pos
	var length := music_player.stream.get_length()
	# Track finished (or nearly) while backgrounded — loop from the start.
	if length > 0.0 and (pos <= 0.05 or pos >= length - 0.35):
		return 0.0
	return pos

func _update_active_sound_paths():
	var active_kick_id = PlayerDataManager.get_active_item("Kick")

	active_kick_sound_path = _get_sound_path_from_shop_data(active_kick_id, "Kick")
	if active_kick_sound_path == "":
		active_kick_sound_path = SHOP_SOUND_DIR + "kick/kick_default.wav"

func _get_sound_path_from_shop_data(item_id: String, category: String) -> String:
	var user_path = "user://shop_data.json"
	var path = user_path if FileAccess.file_exists(user_path) else "res://data/shop_data.json"
	var json_result: Dictionary = JsonUtils.read_json_dict(path)
	if json_result is Dictionary and json_result.has("items"):
		for item in json_result.items:
			if item.get("item_id", "") == item_id:
				var audio_path = item.get("audio", "")
				if audio_path != "":
					if not audio_path.begins_with("res://"):
						audio_path = SHOP_SOUND_DIR + audio_path
					return audio_path
	return ""

func set_active_kick_sound(path: String):
	active_kick_sound_path = path
	print("MusicManager: установлен активный кик-звук: ", path)


func set_music_volume(volume: float):
	if music_player:
		_game_music_volume_pct = volume
		if current_game_music_file != "" or current_menu_music_file == "":
			music_player.volume_db = linear_to_db(volume / 100.0)

func set_menu_music_volume(volume: float):
	_menu_music_volume_pct = volume
	# While menu BGM is intentionally faded out (settings/shop/library), do not
	# snap volume back — that briefly unmutes the old playback position.
	if _menu_music_intentionally_silent:
		return
	if music_player and (current_menu_music_file != "" or current_screen_ambient_file != ""):
		music_player.volume_db = linear_to_db(volume / 100.0)

func set_sfx_volume(volume: float):
	if sfx_player:
		sfx_player.volume_db = linear_to_db(volume / 100.0)

func set_hit_sounds_volume(volume: float): 
	if hit_sound_player: 
		hit_sound_player.volume_db = linear_to_db(volume / 100.0)
	for p in _hit_pool:
		if p:
			p.volume_db = linear_to_db(volume / 100.0)

func set_metronome_volume(volume: float):
	for player in _metronome_players:
		if player: 
			player.volume_db = linear_to_db(volume / 100.0)

func play_menu_music(music_file: String = DEFAULT_MENU_MUSIC, restart: bool = false):
	_menu_music_intentionally_silent = false
	current_screen_ambient_file = ""
	var stream = _load_audio_stream(music_file, BGM_DIR)
	var full_path = BGM_DIR + music_file
	if not stream:
		push_error("MusicManager: Не удалось загрузить аудио для меню: " + full_path)
		return

	if music_player and music_player.stream == stream and not restart:
		current_menu_music_file = music_file
		current_game_music_file = ""
		var menu_vol = SettingsManager.get_menu_music_volume() if SettingsManager.has_method("get_menu_music_volume") else _menu_music_volume_pct
		set_menu_music_volume(menu_vol)
		if music_player.playing:
			_connect_menu_loop()
			return
		music_player.play()
		_connect_menu_loop()
		return

	if music_player:
		current_menu_music_file = music_file
		current_game_music_file = ""
		current_screen_ambient_file = ""
		var menu_vol = SettingsManager.get_menu_music_volume() if SettingsManager.has_method("get_menu_music_volume") else _menu_music_volume_pct
		_play_stream_on(music_player, stream, menu_vol, 0.0, true)
		_connect_menu_loop()


func play_screen_ambient_music(music_file: String, restart: bool = false) -> void:
	_menu_music_intentionally_silent = false
	var stream = _load_audio_stream(music_file, BGM_DIR)
	var full_path = BGM_DIR + music_file
	if not stream:
		push_error("MusicManager: Не удалось загрузить ambient для экрана: " + full_path)
		return
	if music_player and music_player.stream == stream and not restart:
		current_screen_ambient_file = music_file
		current_menu_music_file = ""
		current_game_music_file = ""
		var menu_vol = SettingsManager.get_menu_music_volume() if SettingsManager.has_method("get_menu_music_volume") else _menu_music_volume_pct
		set_menu_music_volume(menu_vol)
		if music_player.playing:
			_connect_menu_loop()
			return
		music_player.play()
		_connect_menu_loop()
		return
	if music_player:
		current_screen_ambient_file = music_file
		current_menu_music_file = ""
		current_game_music_file = ""
		var menu_vol = SettingsManager.get_menu_music_volume() if SettingsManager.has_method("get_menu_music_volume") else _menu_music_volume_pct
		_play_stream_on(music_player, stream, menu_vol, 0.0, true)
		_connect_menu_loop()


func play_victory_screen_music() -> void:
	play_screen_ambient_music(DEFAULT_VICTORY_SCREEN_MUSIC)


func play_defeat_screen_music() -> void:
	play_screen_ambient_music(DEFAULT_DEFEAT_SCREEN_MUSIC)


func stop_screen_ambient_music() -> void:
	if current_screen_ambient_file == "":
		return
	if music_player and music_player.playing:
		music_player.stop()
	current_screen_ambient_file = ""
	_disconnect_menu_loop()

func play_game_music(music_file: String):
	_diag_trace_before("diag_before:play_game_music:req", "path=%s" % music_file.get_file(), music_file)
	_mm_trace_game("play_game_music:req", "path=%s %s" % [music_file.get_file(), _mm_stream_diag()])
	var stream = _load_audio_stream(music_file)
	if not stream:
		push_error("MusicManager: Не удалось загрузить аудио для игры: " + music_file)
		_mm_trace_game("play_game_music:fail_load", "path=%s" % music_file.get_file())
		return

	if music_player:
		if music_player.stream == stream and music_player.playing:
			_mm_trace_game("play_game_music:noop_already_playing", "path=%s %s" % [music_file.get_file(), _mm_stream_diag()])
			return

		var _pre_loop2 := "n/a"
		if stream is AudioStreamMP3:
			_pre_loop2 = str((stream as AudioStreamMP3).loop)
		elif stream is AudioStreamOggVorbis:
			_pre_loop2 = str((stream as AudioStreamOggVorbis).loop)
		var _pre_len2 := float(stream.get_length()) if stream.has_method("get_length") else 0.0
		_mm_trace_game("play_game_music:pre_launch", "incoming_type=%s incoming_loop=%s incoming_len=%.3f cur_%s" % [stream.get_class(), _pre_loop2, _pre_len2, _mm_stream_diag()])
		_cancel_game_music_fade()
		current_game_music_file = music_file
		_preserve_pitch = true
		var game_vol = SettingsManager.get_music_volume() if SettingsManager.has_method("get_music_volume") else _game_music_volume_pct
		_play_stream_on(music_player, stream, game_vol, 0.0, true, false)
		_mm_trace_game("play_game_music:did_play", "path=%s from=0.000 %s playing=%s playback=%.3f" % [music_file.get_file(), _mm_stream_diag(), str(music_player.playing), music_player.get_playback_position() if music_player else 0.0])
		_apply_game_playback_rate_to_player()
		original_game_music_volume = db_to_linear(music_player.volume_db)
		current_menu_music_file = ""
		current_screen_ambient_file = ""
		_disconnect_menu_loop()
	else:
		push_error("MusicManager.gd: music_player не установлен!")

func set_music_position(position: float):
	_diag_trace_before("diag_before:set_music_position:req", "target=%.3f was_playing=%s" % [position, str(music_player.playing if music_player else false)], current_game_music_file)
	if music_player and music_player.stream:
		_mm_trace_game("set_music_position:req", "target=%.3f was_playing=%s file=%s" % [position, str(music_player.playing), current_game_music_file.get_file() if current_game_music_file != "" else "(empty)"])
		if music_player.playing:
			_diag_trace_before("diag_before:set_music_position:seek", "target=%.3f" % position, current_game_music_file)
			music_player.seek(position)
			_diag_watch_check("after_set_music_position:seek")
			_mm_trace_game("set_music_position:seek", "target=%.3f" % position)
		else:
			_diag_trace_before("diag_before:set_music_position:play", "target=%.3f" % position, current_game_music_file)
			music_player.play(position)
			_diag_watch_check("after_set_music_position:play")
			_mm_trace_game("set_music_position:play", "target=%.3f" % position)
	else:
		push_error("MusicManager: Невозможно перемотать музыку. AudioStreamPlayer не установлен или нет аудио потока.")
		_mm_trace_game("set_music_position:fail", "no_player_or_stream target=%.3f" % position)

func get_current_music_position() -> float:
	if music_player and music_player.playing:
		return music_player.get_playback_position()
	return 0.0

func stop_music():
	if music_player: 
		music_player.stop()
		current_menu_music_file = ""
		current_game_music_file = ""
		current_screen_ambient_file = ""
		_game_playback_rate = 1.0
		_apply_game_playback_rate_to_player()
		was_menu_music_playing_before_shop = false
		menu_music_position_before_shop = 0.0
		_disconnect_menu_loop()

func pause_music():
	if music_player and music_player.playing:
		menu_music_position_before_shop = music_player.get_playback_position()
		music_player.stop()

func resume_music():
	if music_player and not music_player.playing and music_player.stream: 
		var resume_pos = menu_music_position_before_shop if menu_music_position_before_shop > 0 else 0.0
		music_player.play(resume_pos)

func is_music_playing() -> bool:
	if music_player:
		return music_player.playing
	else:
		return false
		
func stop_metronome():
	for player in _metronome_players:
		if player and player.playing:
			player.stop()
			
func play_sfx(sound_path: String):
	var full_path = SFX_DIR + sound_path
	var stream = _load_audio_stream(sound_path, SFX_DIR)
	if stream:
		var p = _get_free_sfx_player()
		if p:
			p.stream = stream
			if sfx_player:
				p.volume_db = sfx_player.volume_db
			p.play()
		else:
			push_error("MusicManager: Нет свободного SFX-плеера для " + full_path)
	else:
		push_error("MusicManager: Не удалось загрузить SFX: " + full_path)

func _on_sfx_player_finished(player: AudioStreamPlayer):
	if player and is_instance_valid(player):
		pass

func play_select_sound():
	play_sfx(DEFAULT_SELECT_SOUND)

func play_cancel_sound():
	play_sfx(DEFAULT_CANCEL_SOUND)
	
func play_analysis_success():
	play_sfx(ANALYSIS_SUCCESS_SOUND)

func play_analysis_error():
	play_sfx(ANALYSIS_ERROR_SOUND)


func play_status_toast() -> void:
	var full_path := SFX_DIR + STATUS_TOAST_SOUND
	if FileAccess.file_exists(full_path):
		play_sfx(STATUS_TOAST_SOUND)


func play_diary_celebration() -> void:
	var full_path := SFX_DIR + DIARY_CELEBRATION_SOUND
	if FileAccess.file_exists(full_path):
		play_sfx(DIARY_CELEBRATION_SOUND)
		return
	play_achievement_sound()


func play_modal_popup():
	play_sfx(MODAL_POPUP_SOUND)

func play_achievement_sound():
	play_sfx(DEFAULT_ACHIEVEMENT_SOUND)

func play_shop_purchase():
	play_sfx(SHOP_PURCHASE_SOUND)

func play_shop_apply():
	play_sfx(SHOP_APPLY_SOUND)

func play_shop_open():
	play_sfx(SHOP_OPEN_SOUND)
	
func play_default_shop_sound():
	play_sfx(DEFAULT_SHOP_SOUND)
	
func play_cover_click_sound():
	play_sfx(DEFAULT_COVER_CLICK_SOUND)
	
func play_level_start_sound():
	play_sfx(DEFAULT_LEVEL_START_SOUND)

func play_level_complete_sound():
	var full_path = SFX_DIR + DEFAULT_LEVEL_COMPLETE_SOUND
	if FileAccess.file_exists(full_path):
		play_sfx(DEFAULT_LEVEL_COMPLETE_SOUND)

func play_restart_sound():
	play_sfx(DEFAULT_RESTART_SOUND)


func play_resume_rewind_sound() -> void:
	var full_path := SFX_DIR + DEFAULT_RESUME_REWIND_SOUND
	if FileAccess.file_exists(full_path):
		play_sfx(DEFAULT_RESUME_REWIND_SOUND)


func play_defeat_sound() -> void:
	var full_path := SFX_DIR + DEFAULT_DEFEAT_SOUND
	if FileAccess.file_exists(full_path):
		play_sfx(DEFAULT_DEFEAT_SOUND)


func play_modifier_select_sound() -> void:
	var full_path := SFX_DIR + MODIFIER_SELECT_SOUND
	if FileAccess.file_exists(full_path):
		play_sfx(MODIFIER_SELECT_SOUND)
	else:
		play_select_sound()


func play_modifier_deselect_sound() -> void:
	var full_path := SFX_DIR + MODIFIER_DESELECT_SOUND
	if FileAccess.file_exists(full_path):
		play_sfx(MODIFIER_DESELECT_SOUND)
	else:
		play_cancel_sound()

func play_level_up_sound():
	var full_path = SFX_DIR + DEFAULT_LEVEL_UP_SOUND
	if FileAccess.file_exists(full_path):
		play_sfx(DEFAULT_LEVEL_UP_SOUND)

func play_score_tick():
	var full_path = SFX_DIR + DEFAULT_SCORE_TICK_SOUND
	if FileAccess.file_exists(full_path):
		play_sfx(DEFAULT_SCORE_TICK_SOUND)

func play_grade_pop_sound():
	var full_path = SFX_DIR + DEFAULT_GRADE_POP_SOUND
	if FileAccess.file_exists(full_path):
		play_sfx(DEFAULT_GRADE_POP_SOUND)

func _connect_menu_loop():
	if music_player:
		var cb = Callable(self, "_on_menu_music_finished")
		if not music_player.is_connected("finished", cb):
			music_player.connect("finished", cb)

func _disconnect_menu_loop():
	if music_player:
		var cb = Callable(self, "_on_menu_music_finished")
		if music_player.is_connected("finished", cb):
			music_player.disconnect("finished", cb)

func _on_menu_music_finished():
	if current_menu_music_file != "" and music_player:
		music_player.play(0.0)
	elif current_screen_ambient_file != "" and music_player:
		music_player.play(0.0)

func play_miss_hit_sound():
	var random_index = randi() % 5
	var sound_path = ""
	match random_index:
		0: sound_path = DEFAULT_MISS_HIT_SOUND_1
		1: sound_path = DEFAULT_MISS_HIT_SOUND_2
		2: sound_path = DEFAULT_MISS_HIT_SOUND_3
		3: sound_path = DEFAULT_MISS_HIT_SOUND_4
		4: sound_path = DEFAULT_MISS_HIT_SOUND_5
	play_sfx(sound_path)

func play_hit_sound(is_kick: bool = true):
	var now_msec := Time.get_ticks_msec()
	if now_msec - _last_hit_sound_msec < int(HIT_SOUND_DEDUPE_MS):
		return
	var sound_path = ""
	sound_path = active_kick_sound_path
	var stream = _load_audio_stream(sound_path)
	if stream:
		var player := _get_free_hit_player()
		if player:
			player.stream = stream
			player.play()
			_last_hit_sound_msec = now_msec
		elif hit_sound_player:
			hit_sound_player.stream = stream
			hit_sound_player.play()
			_last_hit_sound_msec = now_msec
	else:
		push_error("MusicManager: Не удалось загрузить звук удара: " + sound_path)

func _get_free_hit_player() -> AudioStreamPlayer:
	for p in _hit_pool:
		if p and not p.playing:
			return p
	if _hit_pool.size() > 0:
		return _hit_pool[0]
	return null

func play_custom_hit_sound(sound_path: String):
	var full_path = sound_path
	_custom_hit_request_id += 1
	var request_id := _custom_hit_request_id
	if not _stream_cache.has(full_path):
		load_audio_stream_async(full_path, "", func(stream): _on_custom_hit_sound_loaded(full_path, request_id, stream))
		return
	var stream = _stream_cache[full_path]
	_play_custom_hit_stream(full_path, stream)

func _on_custom_hit_sound_loaded(full_path: String, request_id: int, stream: AudioStream) -> void:
	if request_id != _custom_hit_request_id:
		return
	_play_custom_hit_stream(full_path, stream)

func _play_custom_hit_stream(full_path: String, stream: AudioStream) -> void:
	if stream:
		if hit_sound_player:
			hit_sound_player.stream = stream
			hit_sound_player.play()
		else:
			push_error("MusicManager: hit_sound_player не установлен!")
	else:
		push_error("MusicManager: Не удалось загрузить кастомный звук удара: " + full_path)

func play_metronome_sound(is_strong_beat: bool = true):
	var sound_file = DEFAULT_METRONOME_STRONG_SOUND if is_strong_beat else DEFAULT_METRONOME_WEAK_SOUND
	var full_path = SFX_DIR + sound_file
	var stream = _load_audio_stream(sound_file, SFX_DIR)
	if stream:
		var player_index = _current_metronome_player_index
		_current_metronome_player_index = (player_index + 1) % _metronome_players.size()
		var player = _metronome_players[player_index]
		if player:
			player.stream = stream
			player.play()
	else:
		push_error("MusicManager: Не удалось загрузить звук метронома: " + full_path)

func update_volumes_from_settings():
	_game_music_volume_pct = SettingsManager.get_music_volume()
	_menu_music_volume_pct = SettingsManager.get_menu_music_volume() if SettingsManager.has_method("get_menu_music_volume") else _menu_music_volume_pct
	if current_game_music_file != "":
		set_music_volume(_game_music_volume_pct)
	# While menu BGM is intentionally silent (settings/shop/…), do not snap volume
	# back onto a still-fading stream — that briefly restores the old position.
	if not _menu_music_intentionally_silent:
		if current_menu_music_file != "":
			set_menu_music_volume(_menu_music_volume_pct)
		if current_screen_ambient_file != "":
			set_menu_music_volume(_menu_music_volume_pct)
	set_sfx_volume(SettingsManager.get_effects_volume())
	set_hit_sounds_volume(SettingsManager.get_hit_sounds_volume())
	set_metronome_volume(SettingsManager.get_metronome_volume())

func play_instrument_select_sound(instrument_type: String):
	var sound_file_name = ""
	match instrument_type:
		"drums":
			sound_file_name = DEFAULT_DRUMS_SELECT_SOUND
		"bass":
			sound_file_name = DEFAULT_BASS_SELECT_SOUND
		"standard": 
			sound_file_name = DEFAULT_STANDARD_SELECT_SOUND
		"fullmix":
			sound_file_name = DEFAULT_FULLMIX_SELECT_SOUND
		_:
			printerr("MusicManager: Неизвестный тип инструмента для звука: ", instrument_type)
			return 

	var full_path = SFX_DIR + sound_file_name
	if FileAccess.file_exists(full_path):
		play_sfx(sound_file_name) 
	else:
		print("MusicManager: Файл звука инструмента не найден: ", full_path)

func get_music_player() -> AudioStreamPlayer:
	return music_player

func _init_sfx_pool():
	for i in range(SFX_POOL_SIZE):
		var p = AudioStreamPlayer.new()
		p.name = "SFXPool_%d" % i
		add_child(p)
		_sfx_pool.append(p)
		if sfx_player:
			p.volume_db = sfx_player.volume_db

func _get_free_sfx_player() -> AudioStreamPlayer:
	for p in _sfx_pool:
		if p and not p.playing:
			return p
	if _sfx_pool.size() > 0:
		return _sfx_pool[0]
	return null

func _preload_common_sfx():
	var started_ms := Time.get_ticks_msec()
	for file_name in PRELOAD_SFX:
		_load_audio_stream(file_name, SFX_DIR)
	_log_perf("critical SFX preload", started_ms, 1)
	call_deferred("_preload_deferred_sfx_step", 0)

func _preload_deferred_sfx_step(index: int) -> void:
	if index >= DEFERRED_PRELOAD_SFX.size():
		return
	_load_audio_stream(DEFERRED_PRELOAD_SFX[index], SFX_DIR)
	await get_tree().process_frame
	call_deferred("_preload_deferred_sfx_step", index + 1)
