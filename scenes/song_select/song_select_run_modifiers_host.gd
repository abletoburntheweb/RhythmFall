# scenes/song_select/song_select_run_modifiers_host.gd
class_name SongSelectRunModifiersHost
extends Node

const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const _UiModifierSounds = preload("res://logic/ui/ui_modifier_sounds.gd")
const _UiMotionEffects = preload("res://logic/ui/ui_motion_effects.gd")
const _ModifiersScene := preload("res://scenes/song_select/run_modifiers/run_modifiers_screen.tscn")

var screen: BaseScreen = null
var overlay: Control = null
var _list_refresh_pending := false


func initialize(host: BaseScreen) -> void:
	screen = host


func open() -> void:
	_UiModifierSounds.play_select()
	_suppress_favorite_for_overlay()
	screen.run_with_loading(screen.tr("UI_LOADING_MODIFIERS"), _mount_overlay)


func _mount_overlay() -> void:
	if overlay and is_instance_valid(overlay):
		overlay.queue_free()
	overlay = _ModifiersScene.instantiate()
	if screen and screen.get_tree():
		await screen.get_tree().process_frame
		await RenderingServer.frame_post_draw
	if overlay.has_signal("modifiers_changed"):
		overlay.modifiers_changed.connect(on_modifiers_changed)
	if overlay.has_signal("screen_closed"):
		overlay.screen_closed.connect(on_closed)
	var host := screen.get_parent()
	host.add_child(overlay)
	host.move_child(overlay, -1)
	if overlay.has_method("set_playfield_lanes"):
		overlay.set_playfield_lanes(screen.current_lanes)
	if overlay.has_method("set_song_context"):
		overlay.set_song_context(
			String(screen.current_selected_song_data.get("path", "")),
			screen.current_instrument,
			GenerationIntents.chart_lookup_key(
				screen.current_generation_mode,
				screen._saved_generation_intent() if screen.has_method("_saved_generation_intent") else ""
			),
			screen.current_lanes
		)
	if overlay.has_method("set_active_modifiers"):
		overlay.set_active_modifiers(screen.active_run_modifiers)
	UiInteractionApplier.apply_from_engine(overlay)
	if overlay.has_method("apply_locale"):
		overlay.apply_locale()
	await screen.get_tree().process_frame
	update_button_label()


func on_closed() -> void:
	var overlay_was_open := overlay and is_instance_valid(overlay)
	if overlay_was_open:
		overlay.queue_free()
	overlay = null
	_UiModifierSounds.play_deselect()
	if _list_refresh_pending:
		_apply_modifiers_to_song_views()
	screen._update_favorite_button(screen.current_displayed_song_path)
	screen.call_deferred("_focus_song_list")


func on_modifiers_changed(mods: Array) -> void:
	screen.active_run_modifiers = _RunModifiers.sanitize(mods)
	update_button_label()
	# While the overlay is open it fully covers the song list, so re-sorting the
	# difficulty-grouped library on every slider tick / card toggle only wastes
	# work and flashes the "sorting library" spinner. Defer the heavy refresh
	# until the overlay closes.
	if overlay and is_instance_valid(overlay):
		_list_refresh_pending = true
	else:
		_apply_modifiers_to_song_views()


func _apply_modifiers_to_song_views() -> void:
	_list_refresh_pending = false
	if screen.song_details_manager:
		screen.song_details_manager.set_active_run_modifiers(screen.active_run_modifiers)
	if screen.song_list_manager:
		screen.song_list_manager.set_active_run_modifiers(screen.active_run_modifiers)


func update_button_label() -> void:
	if screen.modifiers_button == null:
		return
	var base := screen.tr("MOD_BUTTON")
	var mods: Array[String] = screen.active_run_modifiers
	var params := SettingsManager.get_run_modifier_params()
	if mods.is_empty():
		screen.modifiers_button.text = base
	else:
		var mult := _RunModifiers.format_preset_multiplier_label(mods, params)
		screen.modifiers_button.text = screen.tr("MOD_BUTTON_ACTIVE_MULT") % [mods.size(), mult]
	screen._refresh_toolbar_icon_tints()
	_sync_modifiers_button_pulse()


func _sync_modifiers_button_pulse() -> void:
	var btn: Button = screen.modifiers_button
	if btn == null:
		return
	var should_pulse: bool = not screen.active_run_modifiers.is_empty()
	if not should_pulse and overlay and is_instance_valid(overlay) and overlay.has_method("has_unsaved_changes"):
		should_pulse = bool(overlay.has_unsaved_changes())
	_UiMotionEffects.stop_control_border_pulse(btn)
	if should_pulse:
		_UiMotionEffects.pulse_button_outline(btn, UiIconHelper.ACCENT, 0.4, 0.9, 0.7)


func _suppress_favorite_for_overlay() -> void:
	if screen.has_method("_suppress_favorite_for_overlay"):
		screen._suppress_favorite_for_overlay()
	elif screen._favorite_button:
		screen._favorite_button.visible = false
