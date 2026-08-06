# logic/domain/replay/replay_recorder.gd
extends RefCounted
class_name ReplayRecorder

const _RfrCodec = preload("res://logic/platform/rfr_replay_codec.gd")

var _active := false
var _started_at_ms: int = 0
var _events: Array = []
var _track: Dictionary = {}
var _chart: Dictionary = {}
var _run: Dictionary = {}


func begin(track: Dictionary, chart: Dictionary, run: Dictionary) -> void:
	_active = true
	_started_at_ms = Time.get_ticks_msec()
	_events.clear()
	_track = track.duplicate(true)
	_chart = chart.duplicate(true)
	_run = run.duplicate(true)


func active() -> bool:
	return _active


func record_event(
	song_time_s: float,
	lane: int,
	kind: String,
	chart_time_s: float = -1.0,
) -> void:
	if not _active:
		return
	var evt := {
		"t_ms": int(round(maxf(0.0, song_time_s) * 1000.0)),
		"lane": lane,
		"kind": String(kind).strip_edges().to_lower(),
	}
	if chart_time_s >= 0.0:
		evt["chart_t_ms"] = int(round(chart_time_s * 1000.0))
	_events.append(evt)


func build_payload(result: Dictionary, duration_ms: int = 0) -> Dictionary:
	var payload := {
		"version": _RfrCodec.FORMAT_VERSION,
		"format": "rfreplay",
		"created_at": int(Time.get_unix_time_from_system()),
		"game_version": _game_version_label(),
		"track": _track.duplicate(true),
		"chart": _chart.duplicate(true),
		"run": _run.duplicate(true),
		"result": result.duplicate(true),
		"events": _events.duplicate(true),
	}
	payload["run"]["started_at_ms"] = _started_at_ms
	payload["run"]["duration_ms"] = maxi(0, duration_ms)
	return payload


static func _game_version_label() -> String:
	var version := str(ProjectSettings.get_setting("application/config/version", "")).strip_edges()
	if version != "":
		return version
	return "dev"


func reset() -> void:
	_active = false
	_events.clear()
	_track.clear()
	_chart.clear()
	_run.clear()
