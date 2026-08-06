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

var original_game_music_volume: float = 1.0

var _external_metronome_controlled: bool = false

var _last_beat_index: int = -1
var _menu_music_volume_pct: float = 50.0
var _game_music_volume_pct: float = 50.0
var _game_playback_rate: float = 1.0
var _preserve_pitch: bool = true
var _menu_music_fade_tween: Tween = null
var _resume_audio_on_focus_in: bool = false
var _resume_game_audio_on_focus_in: bool = false
var _saved_playback_position_on_unfocus: float = 0.0
var _menu_music_intentionally_silent: bool = false

var _stream_cache: Dictionary = {}
var _async_audio_threads: Dictionary = {}
var _async_audio_callbacks: Dictionary = {}
var _async_audio_started_ms: Dictionary = {}
var _custom_hit_request_id: int = 0
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

func _load_audio_stream(path: String, base_dir: String = "") -> AudioStream:
	var full_path = (base_dir + path) if base_dir != "" else path
	if _stream_cache.has(full_path):
		return _stream_cache[full_path]
	var started_ms := Time.get_ticks_msec()
	var stream: AudioStream = FilePathUtils.load_audio_stream_for_path(full_path)
	_log_perf("audio sync load " + full_path, started_ms)
	if stream:
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

func _play_stream_on(player: AudioStreamPlayer, stream: AudioStream, volume_pct: float, position: float = 0.0, restart_if_playing: bool = true):
	if not player or not stream:
		return
	if restart_if_playing and player.playing:
		player.stop()
	_enable_stream_loop_if_supported(stream)
	player.stream = stream
	player.volume_db = linear_to_db(volume_pct / 100.0)
	if player == music_player:
		_apply_game_playback_rate_to_player()
	player.play(position)


func _enable_stream_loop_if_supported(stream: AudioStream) -> void:
	if stream == null:
		return
	# Native loop survives OS suspend better than finished→play(0) alone.
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	# WAV keeps finished→replay via _connect_menu_loop (loop_end needs sample frames).


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
	music_player.pitch_scale = rate
	var comp := _ensure_pitch_compensation_effect()
	if comp:
		if not _preserve_pitch:
			comp.pitch_scale = 1.0
		else:
			comp.pitch_scale = 1.0 if is_equal_approx(rate, 1.0) else 1.0 / rate


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

func _ready():
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = MUSIC_BUS_NAME
	add_child(music_player)
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
	if music_player:
		music_player.volume_db = linear_to_db(clampf(volume, 0.0, 1.0))


func set_game_music_muted(muted: bool) -> void:
	if music_player == null:
		return
	if muted:
		music_player.volume_db = -80.0
	else:
		var game_vol := (
			SettingsManager.get_music_volume()
			if SettingsManager.has_method("get_music_volume")
			else _game_music_volume_pct
		)
		music_player.volume_db = linear_to_db(game_vol / 100.0)

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
	if music_player and music_player.stream and current_game_music_file != "":
		if music_player.playing:
			menu_music_position_before_shop = music_player.get_playback_position()
			music_player.stop()
			current_game_music_file = ""
			_game_playback_rate = 1.0
			_apply_game_playback_rate_to_player()
			return
		else:
			menu_music_position_before_shop = 0.0
	else:
		pass 


func force_stop_game_track() -> void:
	if music_player:
		if music_player.playing:
			music_player.stop()
		music_player.stream_paused = false
	current_game_music_file = ""
	_game_playback_rate = 1.0
	_apply_game_playback_rate_to_player()

func play_game_music_at_position(song_path: String, position: float):
	var stream = _load_audio_stream(song_path)
	if not stream:
		push_error("MusicManager.gd: Файл игровой музыки не найден: " + song_path)
		return
	if music_player:
		current_game_music_file = song_path
		_preserve_pitch = true
		var game_vol = SettingsManager.get_music_volume() if SettingsManager.has_method("get_music_volume") else _game_music_volume_pct
		_play_stream_on(music_player, stream, game_vol, position, true)
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
	if music_player == null:
		_resume_audio_on_focus_in = false
		_resume_game_audio_on_focus_in = false
		_saved_playback_position_on_unfocus = 0.0
		return
	_resume_audio_on_focus_in = music_player.playing
	_resume_game_audio_on_focus_in = (
		current_game_music_file != ""
		and music_player.playing
	)
	_saved_playback_position_on_unfocus = (
		music_player.get_playback_position() if music_player.playing else 0.0
	)


func on_app_focus_restored() -> void:
	if music_player == null:
		return
	_cancel_menu_music_fade()
	music_player.stream_paused = false
	if music_player.playing:
		return
	if not _resume_audio_on_focus_in:
		return
	if _resume_game_audio_on_focus_in and current_game_music_file != "":
		music_player.stop()
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
	var stream = _load_audio_stream(music_file)
	if not stream:
		push_error("MusicManager: Не удалось загрузить аудио для игры: " + music_file)
		return

	if music_player:
		if music_player.stream == stream and music_player.playing:
			return

		current_game_music_file = music_file
		_preserve_pitch = true
		var game_vol = SettingsManager.get_music_volume() if SettingsManager.has_method("get_music_volume") else _game_music_volume_pct
		_play_stream_on(music_player, stream, game_vol, 0.0, true)
		_apply_game_playback_rate_to_player()
		original_game_music_volume = db_to_linear(music_player.volume_db)
		current_menu_music_file = ""
		current_screen_ambient_file = ""
		_disconnect_menu_loop()
	else:
		push_error("MusicManager.gd: music_player не установлен!")

func set_music_position(position: float):
	if music_player and music_player.stream:
		if music_player.playing:
			music_player.seek(position)
		else:
			music_player.play(position)
	else:
		push_error("MusicManager: Невозможно перемотать музыку. AudioStreamPlayer не установлен или нет аудио потока.")

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
