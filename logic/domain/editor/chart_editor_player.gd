# logic/domain/editor/chart_editor_player.gd
extends RefCounted
class_name ChartEditorPlayer

# Playback для редактора — единый источник времени через MusicManager (как в игре)
# Не создаём второй независимый плеер для времени — используем MusicManager

const _AudioResolver = preload("res://logic/domain/audio/audio_source_resolver.gd")

var _host: Control = null
var _song_path: String = ""
var _original_path: String = ""
var _stem_path: String = ""
var _active_source: String = "original" # "original" or "drums"
var _song_time_offset: float = 0.0
var _is_playing: bool = false
var _duration_s: float = 0.0
var _audio_player: AudioStreamPlayer = null # fallback, если MusicManager недоступен

func setup(host: Control, song_path: String) -> void:
	_host = host
	_song_path = song_path
	_original_path = song_path
	# Fallback плеер на Music bus — только если MusicManager не справится
	if _audio_player == null and host != null:
		_audio_player = AudioStreamPlayer.new()
		_audio_player.name = "ChartEditorAudioFallback"
		_audio_player.bus = "Music"
		host.add_child(_audio_player)
	# Discover drums stem for this song
	_discover_stem()

const PerfTrace = preload("res://logic/utils/perf_trace.gd")

func _discover_stem() -> void:
	var _t_disc := PerfTrace.begin("perf.detail.chart_editor.stem_discover")
	_stem_path = ""
	if _song_path == "":
		print("[ChartEditorPlayer] discover_stem: empty song_path")
		PerfTrace.end("perf.detail.chart_editor.stem_discover", _t_disc)
		return
	var cid := NotesUtils.chart_id_from_song_path(_song_path) if NotesUtils else ""
	var song_name := _song_path.get_file().get_basename().strip_edges()
	print("[ChartEditorPlayer] discover_stem song_name='%s' hash='%s' song_path='%s'" % [song_name, cid, _song_path])
	var _t_pers := PerfTrace.begin("perf.detail.chart_editor.stem.persistent")
	var rel := ChartStemManager.persistent_stem_path_for(_song_path, "drums")
	PerfTrace.end("perf.detail.chart_editor.stem.persistent", _t_pers)
	if rel == "":
		var _t_srv := PerfTrace.begin("perf.detail.chart_editor.stem.server_path")
		rel = ChartStemManager.server_stem_path_for(_song_path, "drums")
		PerfTrace.end("perf.detail.chart_editor.stem.server_path", _t_srv)
		if rel == "":
			var _t_fallback := PerfTrace.begin("perf.detail.chart_editor.stem.fallback")
			rel = ChartStemManager.stem_path_for(_song_path, "drums")
			PerfTrace.end("perf.detail.chart_editor.stem.fallback", _t_fallback)
			print("[ChartEditorPlayer] fallback stem_path_for result='%s'" % rel)
		else:
			print("[ChartEditorPlayer] server_stem_path_for result='%s'" % rel)
	else:
		print("[ChartEditorPlayer] persistent_stem_path_for result='%s'" % rel)
	if rel == "":
		print("[ChartEditorPlayer] discover_stem NO stem candidate for hash='%s' song_name='%s'" % [cid, song_name])
		PerfTrace.end("perf.detail.chart_editor.stem_discover", _t_disc)
		return
	var _t_val := PerfTrace.begin("perf.detail.chart_editor.stem.validate")
	var info := ChartStemManager.validate_stem(rel)
	PerfTrace.end("perf.detail.chart_editor.stem.validate", _t_val)
	var valid := bool(info.get("valid", false))
	var dur := float(info.get("duration", 0.0))
	var abs_path := DirectoryUtils.to_absolute(rel)
	var exists := FileAccess.file_exists(abs_path)
	print("[ChartEditorPlayer] validate rel='%s' abs='%s' exists=%s duration=%.2f valid=%s reason='%s'" % [rel, abs_path, str(exists), dur, str(valid), str(info.get("reason", ""))])
	if not valid:
		print("[ChartEditorPlayer] discover_stem invalid, has_stem=false")
		PerfTrace.end("perf.detail.chart_editor.stem_discover", _t_disc)
		return
	# Check compatibility: duration within 5% or 2 seconds of original if possible
	var stream = info.get("stream", null)
	if stream and stream.has_method("get_length") and _original_path != "":
		var _t_orig := PerfTrace.begin("perf.detail.chart_editor.stem.orig_load")
		var orig_stream = FilePathUtils.load_audio_stream_for_path(_original_path) if FilePathUtils else null
		PerfTrace.end("perf.detail.chart_editor.stem.orig_load", _t_orig)
		if orig_stream and orig_stream.has_method("get_length"):
			var orig_dur := float(orig_stream.get_length())
			var stem_dur := float(stream.get_length())
			print("[ChartEditorPlayer] duration check orig=%.2f stem=%.2f diff=%.2f ratio=%.3f" % [orig_dur, stem_dur, absf(orig_dur - stem_dur), absf(orig_dur - stem_dur) / maxf(orig_dur, stem_dur) if maxf(orig_dur, stem_dur) > 0 else 0])
			if orig_dur > 1.0 and stem_dur > 1.0:
				var diff := absf(orig_dur - stem_dur)
				var ratio := diff / maxf(orig_dur, stem_dur)
				if ratio > 0.05 and diff > 2.0:
					print("[ChartEditorPlayer] discover_stem incompatible duration, rejecting stem")
					PerfTrace.end("perf.detail.chart_editor.stem_discover", _t_disc)
					return
	_stem_path = rel
	print("[ChartEditorPlayer] discover_stem SUCCESS stem_path='%s' has_stem=%s effective='%s'" % [_stem_path, str(has_stem()), get_effective_song_path()])
	PerfTrace.end("perf.detail.chart_editor.stem_discover", _t_disc)

func has_stem() -> bool:
	# Delegate to shared resolver (single source of truth)
	if _song_path != "" and _AudioResolver.has_drums_stem(_song_path):
		return true
	return _stem_path != "" and FileAccess.file_exists(DirectoryUtils.to_absolute(_stem_path))

func get_stem_path() -> String:
	if _stem_path != "" and FileAccess.file_exists(DirectoryUtils.to_absolute(_stem_path)):
		return _stem_path
	# Fallback via resolver (keeps ChartEditorPlayer in sync with gameplay mods)
	var rel := _AudioResolver.get_drums_stem_rel(_song_path)
	if rel != "":
		_stem_path = rel
	return _stem_path

func get_active_source() -> String:
	return _active_source

func set_audio_source(source: String) -> String:
	var s := String(source).strip_edges().to_lower()
	if s not in ["original", "drums"]:
		s = "original"
	if s == "drums" and not has_stem():
		print("[ChartEditorPlayer] set_audio_source requested drums but has_stem=false, staying original")
		s = "original"
	if s == _active_source:
		return _active_source
	print("[ChartEditorPlayer] set_audio_source switching '%s' -> '%s' effective='%s' has_stem=%s" % [_active_source, s, get_effective_song_path(), str(has_stem())])
	var was_playing := _is_playing
	var cur_time := get_time()
	# Exclusive: stop previous source before switching (spec 6)
	if _audio_player and _audio_player.playing:
		_audio_player.stop()
	if MusicManager and MusicManager.has_method("stop_game_music"):
		# Don't fully stop if we will immediately play new, but ensure no overlap - MusicManager.play will handle
		pass
	_active_source = s
	print("[ChartEditorPlayer] after switch effective='%s' stem_path='%s' has_stem=%s" % [get_effective_song_path(), get_stem_path(), str(has_stem())])
	# If playing, switch stream at same position (exclusive)
	if was_playing:
		play(cur_time)
	elif cur_time > 0.0:
		# Paused — seek to keep in sync without starting, ensure fallback stopped
		if _audio_player:
			_audio_player.stop()
			_audio_player.stream_paused = false
		seek(cur_time)
	return _active_source

func toggle_audio_source() -> String:
	if not has_stem():
		return _active_source
	return set_audio_source("drums" if _active_source == "original" else "original")

func get_effective_song_path() -> String:
	var eff := _stem_path if _active_source == "drums" and has_stem() else _song_path
	# Debug helper can log if needed, but not per frame spam (only on source switch)
	return eff

func load_song(path: String) -> void:
	var _should_discover := _stem_path == "" or _song_path != path
	_song_path = path
	_original_path = path
	_is_playing = false
	_song_time_offset = 0.0
	_active_source = "original"
	if _audio_player:
		_audio_player.stop()
		_audio_player.stream = null
		_audio_player.stream_paused = false
	if path == "":
		print("[ChartEditorPlayer] load_song empty path")
		return
	print("[ChartEditorPlayer] load_song path='%s'" % path)
	# IMPLEMENTATION 1: avoid duplicate discover — setup() already discovered for same path
	if _should_discover:
		_discover_stem()
	else:
		print("[ChartEditorPlayer] load_song reuse stem_path='%s' (skip duplicate discover)" % _stem_path)
	print("[ChartEditorPlayer] after discover has_stem=%s stem_path='%s' effective='%s'" % [str(has_stem()), get_stem_path(), get_effective_song_path()])
	if MusicManager and MusicManager.has_method("stop_game_music"):
		MusicManager.stop_game_music()
	# Предзагрузка через MusicManager (async), длительность возьмём из потока при play
	var req_path := get_effective_song_path()
	if MusicManager and MusicManager.has_method("load_audio_stream_async"):
		MusicManager.load_audio_stream_async(req_path, "", func(stream):
			if stream and get_effective_song_path() == req_path:
				_duration_s = stream.get_length() if stream.has_method("get_length") else 0.0
		)
	else:
		var stream = FilePathUtils.load_audio_stream_for_path(req_path) if FilePathUtils else null
		if stream:
			_duration_s = stream.get_length() if stream.has_method("get_length") else 0.0
			if _audio_player:
				_audio_player.stream = stream

func play(from_time: float = -1.0) -> void:
	var t := from_time if from_time >= 0.0 else _song_time_offset
	t = maxf(0.0, t)
	_song_time_offset = t
	_is_playing = true
	var eff := get_effective_song_path()
	# Exclusive playback: ensure fallback stopped when using MusicManager, and vice versa (spec 6)
	if MusicManager and MusicManager.has_method("play_game_music_at_position"):
		if _audio_player and _audio_player.playing:
			_audio_player.stop()
			_audio_player.stream_paused = false
		# Ensure previous MusicManager track stopped before new
		MusicManager.play_game_music_at_position(eff, t)
		return
	# Fallback — ensure MusicManager stopped
	if MusicManager and MusicManager.has_method("stop_game_music"):
		MusicManager.stop_game_music()
	if _audio_player and _audio_player.stream:
		_audio_player.stream_paused = false
		_audio_player.play(t)

func pause() -> void:
	_song_time_offset = get_time()
	_is_playing = false
	if MusicManager and MusicManager.has_method("pause_music"):
		# MusicManager не имеет pause для game, используем stop с сохранением позиции
		# Вместо этого ставим стрим на паузу через AudioServer?
		# Попробуем через music_player напрямую
		var mp = MusicManager.get_music_player() if MusicManager.has_method("get_music_player") else null
		if mp and mp.playing:
			mp.stream_paused = true
			return
	if _audio_player:
		_audio_player.stream_paused = true

func resume() -> void:
	_is_playing = true
	if MusicManager and MusicManager.has_method("get_music_player"):
		var mp = MusicManager.get_music_player() if MusicManager.has_method("get_music_player") else null
		if mp and mp.stream_paused:
			mp.stream_paused = false
			return
	if _audio_player:
		_audio_player.stream_paused = false

func stop() -> void:
	_is_playing = false
	if MusicManager and MusicManager.has_method("stop_game_music"):
		MusicManager.stop_game_music()
		return
	if _audio_player:
		_audio_player.stop()
		_audio_player.stream_paused = false

func seek(t: float) -> void:
	t = maxf(0.0, t)
	_song_time_offset = t
	if _is_playing:
		play(t)
	else:
		# В паузе — обновляем позицию без старта
		if MusicManager and MusicManager.has_method("play_game_music_at_position"):
			# Запомним, при следующем play начнётся оттуда
			# Для превью в паузе можно просто обновить offset, не трогая плеер
			var mp = MusicManager.get_music_player() if MusicManager.has_method("get_music_player") else null
			if mp and mp.playing:
				mp.play(t)
				mp.stream_paused = true
		elif _audio_player and _audio_player.stream:
			if _audio_player.playing:
				_audio_player.play(t)
				_audio_player.stream_paused = true

func get_time() -> float:
	# Единый источник — как в game_screen.gd: precise - latency, учитываем оба source
	var eff := get_effective_song_path()
	if MusicManager and MusicManager.has_method("get_game_music_position_precise") and MusicManager.has_method("is_music_playing"):
		if MusicManager.is_music_playing() and (String(MusicManager.current_game_music_file) == _song_path or String(MusicManager.current_game_music_file) == _stem_path or String(MusicManager.current_game_music_file) == eff):
			var cur := MusicManager.get_game_music_position_precise() - AudioServer.get_output_latency()
			if cur > 0.0:
				_song_time_offset = cur
				return maxf(0.0, cur)
			# fallback к обычному
			var cur2 := MusicManager.get_game_music_position_precise()
			if cur2 > 0.0:
				return maxf(0.0, cur2 - AudioServer.get_output_latency())
		elif _is_playing:
			# MusicManager ещё не стартовал, но _is_playing true — возможно fallback плеер
			pass
	# Fallback — собственный плеер
	if _audio_player and _audio_player.stream and _audio_player.playing and not _audio_player.stream_paused:
		var pos := _audio_player.get_playback_position() + AudioServer.get_time_since_last_mix()
		var cur := pos - AudioServer.get_output_latency()
		if cur > 0.0:
			_song_time_offset = cur
			return maxf(0.0, cur)
	return _song_time_offset

func is_playing() -> bool:
	var eff := get_effective_song_path()
	if MusicManager and MusicManager.has_method("is_music_playing") and (String(MusicManager.current_game_music_file) == _song_path or String(MusicManager.current_game_music_file) == _stem_path or String(MusicManager.current_game_music_file) == eff):
		return MusicManager.is_music_playing() and _is_playing
	if _audio_player:
		return _is_playing and _audio_player.playing and not _audio_player.stream_paused
	return _is_playing

func get_duration() -> float:
	if _duration_s > 0.0:
		return _duration_s
	if MusicManager and MusicManager.has_method("get_music_player"):
		var mp = MusicManager.get_music_player() if MusicManager.has_method("get_music_player") else null
		if mp and mp.stream and mp.stream.has_method("get_length"):
			return mp.stream.get_length()
	if _audio_player and _audio_player.stream and _audio_player.stream.has_method("get_length"):
		return _audio_player.stream.get_length()
	return 0.0

func set_volume_db(db: float) -> void:
	# Громкость через Music bus — не трогаем per-player, bus контролируется SettingsManager
	pass

func cleanup() -> void:
	_is_playing = false
	if MusicManager and MusicManager.has_method("stop_game_music"):
		MusicManager.stop_game_music()
	if _audio_player:
		_audio_player.stop()
