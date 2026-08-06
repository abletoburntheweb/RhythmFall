# logic/domain/replay/replay_resolver.gd
extends RefCounted
class_name ReplayResolver

const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")


static func resolve(payload: Dictionary) -> Dictionary:
	var out := {
		"ok": false,
		"song_data": {},
		"chart": {},
		"run": {},
		"result": {},
		"events": [],
		"missing": [],
		"message_key": "REPLAY_ERR_INVALID",
		"message_args": [],
	}
	if payload.is_empty():
		return out
	var track: Dictionary = payload.get("track", {}) if payload.get("track", {}) is Dictionary else {}
	var chart: Dictionary = payload.get("chart", {}) if payload.get("chart", {}) is Dictionary else {}
	var run: Dictionary = payload.get("run", {}) if payload.get("run", {}) is Dictionary else {}
	out["chart"] = chart.duplicate(true)
	out["run"] = run.duplicate(true)
	out["result"] = payload.get("result", {}) if payload.get("result", {}) is Dictionary else {}
	out["events"] = payload.get("events", []) if payload.get("events", []) is Array else []

	var song_data := _find_song_data(track)
	if song_data.is_empty():
		out["missing"] = _missing_requirements(track, chart)
		out["message_key"] = "REPLAY_ERR_TRACK_MISSING"
		out["message_args"] = [
			String(track.get("title", "")),
			String(track.get("artist", "")),
			String(track.get("audio_file", "")),
		]
		return out

	var instrument := String(chart.get("instrument", "drums")).strip_edges().to_lower()
	var mode := String(chart.get("mode", "original")).strip_edges().to_lower()
	var lanes := int(chart.get("lanes", 4))
	var chart_tag := String(chart.get("chart_tag", "")).strip_edges()
	var song_path := String(song_data.get("path", "")).strip_edges()
	if NotesUtils.resolve_existing_path(song_path, instrument, mode, lanes, chart_tag) == "":
		out["missing"] = ["chart"]
		out["message_key"] = "REPLAY_ERR_CHART_MISSING"
		out["message_args"] = [instrument, mode]
		out["song_data"] = song_data
		return out

	if not FileAccess.file_exists(song_path):
		out["missing"] = ["audio"]
		out["message_key"] = "REPLAY_ERR_AUDIO_MISSING"
		out["message_args"] = [String(track.get("audio_file", song_path.get_file()))]
		out["song_data"] = song_data
		return out

	out["ok"] = true
	out["song_data"] = song_data
	out["message_key"] = ""
	return out


static func _find_song_data(track: Dictionary) -> Dictionary:
	var saved_path := String(track.get("song_path", "")).strip_edges()
	if saved_path != "" and FileAccess.file_exists(saved_path):
		return _song_dict_for_path(saved_path)
	var chart_id := String(track.get("chart_id", "")).strip_edges()
	if chart_id != "" and SongLibrary:
		for entry in SongLibrary.get_songs_list():
			if not entry is Dictionary:
				continue
			var path := String(entry.get("path", "")).strip_edges()
			if path == "":
				continue
			if NotesUtils.chart_id_from_song_path(path) == chart_id:
				return _song_dict_for_path(path)
	return _find_by_identity(track)


static func _find_by_identity(track: Dictionary) -> Dictionary:
	if SongLibrary == null:
		return {}
	var title := String(track.get("title", "")).strip_edges().to_lower()
	var artist := String(track.get("artist", "")).strip_edges().to_lower()
	var audio_file := String(track.get("audio_file", "")).strip_edges().to_lower()
	if title == "" and artist == "" and audio_file == "":
		return {}
	for entry in SongLibrary.get_songs_list():
		if not entry is Dictionary:
			continue
		var path := String(entry.get("path", "")).strip_edges()
		if path == "":
			continue
		if audio_file != "" and path.get_file().to_lower() != audio_file:
			continue
		var meta := SongLibrary.get_display_metadata_for_song(path)
		var meta_title := String(meta.get("title", "")).strip_edges().to_lower()
		var meta_artist := String(meta.get("artist", "")).strip_edges().to_lower()
		if title != "" and meta_title != title:
			continue
		if artist != "" and meta_artist != artist:
			continue
		return _song_dict_for_path(path)
	return {}


static func _song_dict_for_path(song_path: String) -> Dictionary:
	var data := {"path": song_path}
	if SongLibrary:
		var meta := SongLibrary.get_display_metadata_for_song(song_path)
		if meta is Dictionary:
			data.merge(meta, true)
	return data


static func _missing_requirements(track: Dictionary, chart: Dictionary) -> Array[String]:
	var missing: Array[String] = ["audio"]
	if String(track.get("title", "")).strip_edges() != "" or String(track.get("artist", "")).strip_edges() != "":
		missing.append("identity")
	missing.append("chart")
	return missing


static func build_track_ref(song_data: Dictionary) -> Dictionary:
	var song_path := String(song_data.get("path", "")).strip_edges()
	return {
		"chart_id": NotesUtils.chart_id_from_song_path(song_path),
		"song_path": song_path,
		"audio_file": song_path.get_file(),
		"title": String(song_data.get("title", "")),
		"artist": String(song_data.get("artist", "")),
		"duration_sec": int(round(_duration_sec_for_song(song_path))),
	}


static func build_chart_ref(
	instrument: String,
	mode: String,
	lanes: int,
	chart_tag: String = "",
) -> Dictionary:
	return {
		"instrument": instrument,
		"mode": mode,
		"lanes": lanes,
		"chart_tag": chart_tag,
	}


static func build_run_ref(
	modifiers: Array,
	modifier_params: Dictionary,
	play_mode: String = "",
) -> Dictionary:
	return {
		"modifiers": _RunModifiers.sanitize(modifiers),
		"modifier_params": _RunModifiers.sanitize_params(modifier_params),
		"play_mode": play_mode,
	}


static func _duration_sec_for_song(song_path: String) -> float:
	if SongLibrary == null or song_path.strip_edges() == "":
		return 0.0
	var meta := SongLibrary.get_metadata_for_song(song_path)
	if meta is Dictionary:
		return ChartDifficultyAnalyzer.parse_duration_seconds(meta.get("duration", "00:00"))
	return 0.0
