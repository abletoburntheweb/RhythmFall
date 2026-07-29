extends Control

const _ACCENT := Color(0.38, 0.78, 0.74, 1.0)
const _BAR_COUNT := 56

var _waveform_sampler: AudioWaveformSampler = null
var _audio_path: String = ""
var _idle_envelope: PackedFloat32Array = PackedFloat32Array()
var _duration: float = 0.0
var _playhead: float = 0.0
var _anim_phase: float = 0.0
var _is_playing := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func has_waveform_data() -> bool:
	return not _idle_envelope.is_empty()


func set_audio_source(audio_path: String) -> void:
	if audio_path == _audio_path and has_waveform_data():
		_reset_to_idle()
		queue_redraw()
		return
	_audio_path = audio_path
	_load_idle_envelope()
	_reset_to_idle()
	queue_redraw()


func trigger() -> void:
	if _idle_envelope.is_empty():
		return
	_start_playback()


func trigger_from_audio(audio_path: String) -> void:
	set_audio_source(audio_path)
	trigger()


func _load_idle_envelope() -> void:
	_idle_envelope = PackedFloat32Array()
	_duration = 0.0
	if _audio_path == "" or not FileAccess.file_exists(_audio_path):
		return
	var analysis: Dictionary = _get_waveform_sampler().analyze_hit_envelope(_audio_path, _BAR_COUNT)
	_idle_envelope = analysis.get("envelope", PackedFloat32Array())
	_duration = maxf(0.12, float(analysis.get("duration", 0.35)))


func _reset_to_idle() -> void:
	_is_playing = false
	_playhead = 0.0
	_anim_phase = 0.0
	set_process(false)
	queue_redraw()


func _start_playback() -> void:
	_playhead = 0.0
	_anim_phase = 0.0
	_is_playing = true
	set_process(true)
	queue_redraw()


func _get_waveform_sampler() -> AudioWaveformSampler:
	if _waveform_sampler == null:
		_waveform_sampler = AudioWaveformSampler.new()
	return _waveform_sampler


func _process(delta: float) -> void:
	if not _is_playing:
		return
	_playhead += delta
	_anim_phase += delta
	if _playhead >= _duration:
		_reset_to_idle()
		return
	queue_redraw()


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	if _idle_envelope.is_empty():
		return
	_draw_waveform()
	if _is_playing:
		_draw_playhead()


func _draw_waveform() -> void:
	var bar_count := _idle_envelope.size()
	if bar_count <= 0:
		return
	var gap := 2.0
	var pad_x := 10.0
	var usable_w := size.x - pad_x * 2.0
	var bar_w := maxf(2.0, (usable_w - gap * float(bar_count - 1)) / float(bar_count))
	var base_y := size.y - 12.0
	var max_h := size.y * 0.72
	var x := pad_x
	var progress := clampf(_playhead / maxf(_duration, 0.001), 0.0, 1.0) if _is_playing else 0.0
	var play_pos := progress * float(bar_count - 1)

	for i in bar_count:
		var value := clampf(_idle_envelope[i], 0.0, 1.0)
		var h := _bar_height(value, i, bar_count, play_pos, max_h)
		var rect := Rect2(x, base_y - h, bar_w, h)
		var color := _bar_color(value, i, play_pos)
		draw_rect(rect, color, true)
		if value > 0.04:
			var cap_h := minf(4.0, h)
			draw_rect(Rect2(x, base_y - h, bar_w, cap_h), color.lightened(0.14), true)
		x += bar_w + gap


func _bar_height(value: float, index: int, bar_count: int, play_pos: float, max_h: float) -> float:
	var h := lerpf(5.0, max_h, value)
	if not _is_playing:
		return h
	var dist := absf(float(index) - play_pos)
	var head_pulse := exp(-dist * 0.62)
	var ripple := sin(_anim_phase * 24.0 + float(index) * 0.48) * 0.5 + 0.5
	var bounce := head_pulse * (0.22 + ripple * 0.38) * value
	if float(index) < play_pos - 0.35:
		bounce *= exp(-(play_pos - float(index)) * 0.18)
	return h * (1.0 + bounce)


func _bar_color(value: float, index: int, play_pos: float) -> Color:
	if not _is_playing:
		return Color(_ACCENT.r, _ACCENT.g, _ACCENT.b, 0.20 + value * 0.28)
	var dist := absf(float(index) - play_pos)
	var head := exp(-dist * 0.75)
	var alpha := lerpf(0.22 + value * 0.30, 0.42 + value * 0.58, head)
	var lit := lerpf(0.0, 0.22, head)
	return Color(
		lerpf(_ACCENT.r, 1.0, lit),
		lerpf(_ACCENT.g, 1.0, lit),
		lerpf(_ACCENT.b, 1.0, lit),
		alpha
	)


func _draw_playhead() -> void:
	var bar_count := _idle_envelope.size()
	if bar_count <= 0:
		return
	var pad_x := 10.0
	var usable_w := size.x - pad_x * 2.0
	var progress := clampf(_playhead / maxf(_duration, 0.001), 0.0, 1.0)
	var x := pad_x + progress * usable_w
	draw_line(
		Vector2(x, 8.0),
		Vector2(x, size.y - 8.0),
		Color(0.92, 0.98, 0.96, 0.72),
		1.5
	)
