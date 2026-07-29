extends RefCounted
class_name AudioSpectrumReader

const BUS_NAME := "Music"

var _bus_index: int = -1
var _instance: AudioEffectSpectrumAnalyzerInstance = null
var _ready: bool = false
var _smoothed_bass: float = 0.0
var _smoothed_energy: float = 0.0


func setup() -> bool:
	_bus_index = _ensure_music_bus()
	if _bus_index < 0:
		return false
	if AudioServer.get_bus_effect_count(_bus_index) <= 0:
		return false
	_instance = AudioServer.get_bus_effect_instance(_bus_index, 0) as AudioEffectSpectrumAnalyzerInstance
	_ready = _instance != null
	return _ready


func is_ready() -> bool:
	return _ready


static func _ensure_music_bus() -> int:
	var idx := AudioServer.get_bus_index(BUS_NAME)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, BUS_NAME)
		AudioServer.set_bus_send(idx, "Master")
	if AudioServer.get_bus_effect_count(idx) == 0:
		var fx := AudioEffectSpectrumAnalyzer.new()
		fx.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_512
		fx.buffer_length = 0.06
		AudioServer.add_bus_effect(idx, fx)
	return idx


func tick(delta: float, active: bool) -> void:
	if not _ready:
		return
	if not active:
		_decay(delta, 5.0)
		return
	var bass := _read_band(40.0, 160.0)
	var mid := _read_band(160.0, 1200.0)
	var energy := clampf(bass * 0.7 + mid * 0.3, 0.0, 1.0)
	var attack := clampf(delta * 16.0, 0.0, 1.0)
	_smoothed_bass = lerpf(_smoothed_bass, bass, attack)
	_smoothed_energy = lerpf(_smoothed_energy, energy, attack)


func get_bass() -> float:
	return _smoothed_bass


func get_energy() -> float:
	return _smoothed_energy


func reset() -> void:
	_smoothed_bass = 0.0
	_smoothed_energy = 0.0


func _decay(delta: float, speed: float) -> void:
	var t := clampf(delta * speed, 0.0, 1.0)
	_smoothed_bass = lerpf(_smoothed_bass, 0.0, t)
	_smoothed_energy = lerpf(_smoothed_energy, 0.0, t)


func _read_band(from_hz: float, to_hz: float) -> float:
	if _instance == null:
		return 0.0
	var mag: Vector2 = _instance.get_magnitude_for_frequency_range(from_hz, to_hz)
	var linear := (mag.x + mag.y) * 0.5
	return clampf(linear * 3.2, 0.0, 1.0)
