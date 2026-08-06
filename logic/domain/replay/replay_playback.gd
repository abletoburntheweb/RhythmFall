# logic/domain/replay/replay_playback.gd
extends RefCounted
class_name ReplayPlayback

var _events: Array = []
var _cursor: int = 0


func setup(payload: Dictionary) -> void:
	_events.clear()
	_cursor = 0
	var raw: Variant = payload.get("events", [])
	if not raw is Array:
		return
	for item in raw:
		if item is Dictionary:
			_events.append(item)
	_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("t_ms", 0)) < int(b.get("t_ms", 0))
	)


func reset() -> void:
	_cursor = 0


func finished() -> bool:
	return _cursor >= _events.size()


func poll(song_time_s: float) -> Array:
	var fired: Array = []
	var now_ms := int(round(maxf(0.0, song_time_s) * 1000.0))
	while _cursor < _events.size():
		var evt: Dictionary = _events[_cursor]
		if int(evt.get("t_ms", 0)) > now_ms:
			break
		fired.append(evt)
		_cursor += 1
	return fired
