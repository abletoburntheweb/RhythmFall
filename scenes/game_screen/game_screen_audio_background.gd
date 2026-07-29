# scenes/game_screen/game_screen_audio_background.gd
class_name GameScreenAudioBackground
extends Node

const _AudioSpectrumReader = preload("res://logic/domain/rhythm/audio_spectrum_reader.gd")

const BG_COMBO_MAX: float = 1000.0
const BG_MIX_MAX: float = 0.42
const BG_CONTRAST_MAX: float = 0.52
const BG_DRIFT_SPEED_LOW: float = 0.52
const BG_DRIFT_SPEED_HIGH: float = 0.16
const BG_MIX_SMOOTH: float = 1.05
const BG_COLOR_SMOOTH: float = 0.72
const BG_LOW_VIOLET := Color(0.62, 0.46, 0.86, 1.0)
const BG_LOW_MAGENTA := Color(0.74, 0.5, 0.82, 1.0)
const BG_MID_BLUE_VIOLET := Color(0.44, 0.58, 0.86, 1.0)
const AUDIO_BG_MIX: float = 0.14
const AUDIO_BG_DRIFT: float = 0.022
const AUDIO_BORDER_ALPHA: float = 0.28

var game_screen = null

var bg_rect: ColorRect = null
var bg_base_color: Color = Color(0.0, 0.0, 0.0, 0.7058824)
var bg_current_mix: float = 0.0
var bg_display_accent: Color = Color(0.0, 0.0, 0.0, 0.7058824)
var bg_drift_phase: float = 0.0

var audio_spectrum: AudioSpectrumReader = null
var playfield_panel: Panel = null
var playfield_style: StyleBoxFlat = null
var playfield_border_base: Color = Color(0.38, 0.55, 0.82, 0.5)


func initialize(gs: Control) -> void:
	game_screen = gs


func find_background_elements() -> void:
	bg_rect = game_screen.get_node_or_null("Background") as ColorRect
	if bg_rect:
		bg_base_color = bg_rect.color
		bg_display_accent = bg_base_color


func setup_audio_reactive_visuals() -> void:
	playfield_panel = game_screen.get_node_or_null("Playfield") as Panel
	if playfield_panel:
		var base_style := playfield_panel.get_theme_stylebox("panel")
		if base_style is StyleBoxFlat:
			playfield_style = base_style.duplicate() as StyleBoxFlat
			playfield_border_base = playfield_style.border_color
			playfield_panel.add_theme_stylebox_override("panel", playfield_style)
	audio_spectrum = _AudioSpectrumReader.new()
	audio_spectrum.setup()


func reset_visuals() -> void:
	bg_current_mix = 0.0
	bg_drift_phase = 0.0
	bg_display_accent = bg_base_color
	if bg_rect:
		bg_rect.color = bg_base_color
	if audio_spectrum:
		audio_spectrum.reset()
	if playfield_style:
		playfield_style.border_color = playfield_border_base


func update(delta: float) -> void:
	if bg_rect == null:
		return
	_tick_audio_spectrum(delta)
	if SettingsManager.get_reduce_bg_effects():
		bg_rect.color = bg_base_color
		_update_playfield_audio_border()
		return
	var progress := _smooth_combo_progress(_combo_background_progress())
	var drift_speed := lerpf(BG_DRIFT_SPEED_LOW, BG_DRIFT_SPEED_HIGH, progress)
	bg_drift_phase += delta * drift_speed

	var target_accent := _combo_background_accent_color(progress, bg_drift_phase)
	var color_t := clampf(delta * BG_COLOR_SMOOTH, 0.0, 1.0)
	bg_display_accent = bg_display_accent.lerp(target_accent, color_t)

	var target_mix := _combo_background_target_mix(progress)
	var mix_t := clampf(delta * BG_MIX_SMOOTH, 0.0, 1.0)
	bg_current_mix = lerpf(bg_current_mix, target_mix, mix_t)

	var blended := bg_base_color.lerp(bg_display_accent, bg_current_mix)
	blended = _push_bg_contrast(blended, _combo_contrast_amount(progress))

	var drift_amp := _combo_drift_amplitude(progress)
	if audio_spectrum and _use_audio_reactive():
		drift_amp += audio_spectrum.get_bass() * AUDIO_BG_DRIFT
	blended.r += sin(bg_drift_phase) * drift_amp
	blended.g += sin(bg_drift_phase * 0.87 + 1.2) * drift_amp * 0.5
	blended.b += cos(bg_drift_phase * 0.73 + 0.8) * drift_amp * 1.1
	blended = _apply_audio_to_background_color(blended, progress, bg_drift_phase)
	bg_rect.color = _clamp_bg_color(blended)
	_update_playfield_audio_border()


func _use_audio_reactive() -> bool:
	if SettingsManager.get_reduce_bg_effects():
		return false
	return SettingsManager.get_audio_reactive_background()


func _music_drives_audio_reactive() -> bool:
	return MusicManager != null and MusicManager.is_music_playing()


func _tick_audio_spectrum(delta: float) -> void:
	if audio_spectrum == null or not _use_audio_reactive():
		return
	audio_spectrum.tick(delta, _music_drives_audio_reactive())


func _apply_audio_to_background_color(base: Color, progress: float, drift_phase: float) -> Color:
	if audio_spectrum == null or not _use_audio_reactive():
		return base
	var bass := audio_spectrum.get_bass()
	if bass <= 0.0001:
		return base
	var accent := _combo_background_accent_color(progress, drift_phase)
	var out := base.lerp(accent, bass * AUDIO_BG_MIX)
	out.r += bass * 0.035
	out.g += bass * 0.018
	out.b += bass * 0.055
	return _clamp_bg_color(out)


func _update_playfield_audio_border() -> void:
	if playfield_style == null:
		return
	if not _use_audio_reactive() or audio_spectrum == null:
		playfield_style.border_color = playfield_border_base
		return
	var bass := audio_spectrum.get_bass()
	var c := playfield_border_base
	c.r = lerpf(c.r, 0.48, bass * 0.35)
	c.g = lerpf(c.g, 0.68, bass * 0.28)
	c.b = lerpf(c.b, 0.92, bass * 0.4)
	c.a = clampf(playfield_border_base.a + bass * AUDIO_BORDER_ALPHA, playfield_border_base.a, 0.88)
	playfield_style.border_color = c


func _combo_background_progress() -> float:
	if game_screen.score_manager == null:
		return 0.0
	var combo: float = float(game_screen.score_manager.get_combo())
	return clampf(combo / BG_COMBO_MAX, 0.0, 1.0)


func _smooth_combo_progress(progress: float) -> float:
	var t := clampf(progress, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _combo_background_accent_color(progress: float, drift_phase: float) -> Color:
	var purple := Color(
		game_screen.combo_color_50.r,
		game_screen.combo_color_50.g,
		game_screen.combo_color_50.b,
		bg_base_color.a
	)
	var blue_peak := Color(
		game_screen.combo_color_100.r,
		game_screen.combo_color_100.g,
		game_screen.combo_color_100.b,
		bg_base_color.a
	)
	var low_violet := Color(BG_LOW_VIOLET.r, BG_LOW_VIOLET.g, BG_LOW_VIOLET.b, bg_base_color.a)
	var low_magenta := Color(BG_LOW_MAGENTA.r, BG_LOW_MAGENTA.g, BG_LOW_MAGENTA.b, bg_base_color.a)
	var mid_blue_violet := Color(BG_MID_BLUE_VIOLET.r, BG_MID_BLUE_VIOLET.g, BG_MID_BLUE_VIOLET.b, bg_base_color.a)

	var low_wave_a := 0.5 + 0.5 * sin(drift_phase * 1.15)
	var low_wave_b := 0.5 + 0.5 * cos(drift_phase * 0.92 + 0.9)
	var low_accent := low_violet.lerp(low_magenta, low_wave_a)
	low_accent = low_accent.lerp(purple, low_wave_b * 0.55)
	low_accent = low_accent.lerp(mid_blue_violet, (1.0 - low_wave_a) * 0.35)

	if progress < 0.32:
		var local := progress / 0.32
		return bg_base_color.lerp(low_accent, 0.18 + local * 0.42)
	if progress < 0.68:
		var local := (progress - 0.32) / 0.36
		local = local * local * (3.0 - 2.0 * local)
		var bridge := low_accent.lerp(purple, 0.35).lerp(mid_blue_violet, local * 0.55)
		return bridge.lerp(blue_peak, local * 0.45)
	var local_high := (progress - 0.68) / 0.32
	local_high = local_high * local_high * (3.0 - 2.0 * local_high)
	var pre_blue := mid_blue_violet.lerp(blue_peak, 0.42)
	return pre_blue.lerp(blue_peak, local_high)


func _combo_background_target_mix(progress: float) -> float:
	if progress < 0.28:
		return lerpf(0.14, 0.3, progress / 0.28)
	if progress < 0.68:
		return lerpf(0.3, 0.36, (progress - 0.28) / 0.4)
	return lerpf(0.36, BG_MIX_MAX, (progress - 0.68) / 0.32)


func _combo_drift_amplitude(progress: float) -> float:
	if progress < 0.32:
		return lerpf(0.04, 0.032, progress / 0.32)
	if progress < 0.68:
		return lerpf(0.032, 0.014, (progress - 0.32) / 0.36)
	return lerpf(0.014, 0.003, (progress - 0.68) / 0.32)


func _combo_contrast_amount(progress: float) -> float:
	if progress < 0.35:
		return progress * 0.12
	return lerpf(0.042, BG_CONTRAST_MAX, (progress - 0.35) / 0.65)


func _clamp_bg_color(color: Color) -> Color:
	return Color(
		clampf(color.r, 0.0, 1.0),
		clampf(color.g, 0.0, 1.0),
		clampf(color.b, 0.0, 1.0),
		color.a
	)


func _push_bg_contrast(color: Color, amount: float) -> Color:
	if amount <= 0.0001:
		return color
	var lum := color.r * 0.299 + color.g * 0.587 + color.b * 0.114
	return _clamp_bg_color(Color(
		lerpf(lum, color.r, 1.0 + amount),
		lerpf(lum, color.g, 1.0 + amount),
		lerpf(lum, color.b, 1.0 + amount),
		color.a
	))
