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


func event_count() -> int:
	return _events.size()


## Переводит курсор на первый ещё не сыгранный event (с t_ms > target_ms).
## Используется плеером при seek: всё, что ≤ target, уже «отработано» и
## учитывается в rescore, остальное продолжит воспроизводиться как обычно.
func seek_to(target_ms: int) -> void:
	_cursor = 0
	while _cursor < _events.size():
		if int(_events[_cursor].get("t_ms", 0)) > target_ms:
			break
		_cursor += 1


## Все события с t_ms <= target_ms (для пересчёта счёта/HP после seek).
func events_before(target_ms: int) -> Array:
	var out: Array = []
	for evt in _events:
		if int(evt.get("t_ms", 0)) > target_ms:
			break
		out.append(evt)
	return out


func events() -> Array:
	return _events


## Время (мс) первого несыгранного события; 0, если событий нет или все сыграны.
func next_event_time_ms() -> int:
	if _cursor < _events.size():
		return int(_events[_cursor].get("t_ms", 0))
	return 0