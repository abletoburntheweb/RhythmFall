# logic/services/app_window_manager.gd
# Tracks window focus/minimize state to drive background behaviours:
#   * cap FPS while EXCLUSIVE fullscreen sits in the background;
#   * mute Master audio in the same situation;
#   * borderless fullscreen and windowed: no throttle, no auto-mute;
#   * signal the OS (taskbar attention) when a long task finishes off-screen.
extends Node

signal app_unfocused

# Cap while backgrounded (exclusive fullscreen only). Borderless keeps full FPS/audio.
const LOW_POWER_FPS := 30

var _focused: bool = true
var _low_power_active: bool = false
var _saved_max_fps: int = 0
# Captured while focused so minimize (WINDOW_MODE_MINIMIZED) still knows we were
# in exclusive fullscreen. Borderless fullscreen is intentionally excluded.
var _exclusive_fullscreen_when_focused: bool = false
var _unfocus_muted: bool = false
var _saved_master_muted: bool = false
var _focus_out_generation: int = 0
const FOCUS_OUT_GRACE_SEC := 0.15


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Poll the real OS focus state once the tree is up. Focus in/out afterwards
	# is driven by the APPLICATION/WM focus notifications below, which are the
	# reliable cross-platform signals (the Window.focus_* signals are GUI-focus
	# and do not fire on OS alt-tab / minimize).
	call_deferred("_sync_focus_state")


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_on_app_focus_out()
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			_on_app_focus_in()


func _sync_focus_state() -> void:
	_exclusive_fullscreen_when_focused = _is_exclusive_fullscreen()
	if DisplayServer.window_is_focused():
		_on_app_focus_in()
	else:
		_apply_focus_lost_now()


func is_app_focused() -> bool:
	return _focused


func _on_app_focus_out() -> void:
	# OptionButton popups on Windows steal WM focus briefly; defer so menu music
	# is not treated as a real alt-tab / minimize.
	_focus_out_generation += 1
	var generation := _focus_out_generation
	var tree := get_tree()
	if tree == null:
		_apply_focus_lost_now()
		return
	await tree.create_timer(FOCUS_OUT_GRACE_SEC).timeout
	if generation != _focus_out_generation:
		return
	if DisplayServer.window_is_focused():
		return
	_apply_focus_lost_now()


func _on_app_focus_in() -> void:
	_focus_out_generation += 1
	_focused = true
	_exclusive_fullscreen_when_focused = _is_exclusive_fullscreen()
	_restore_low_power_mode()
	_restore_unfocus_mute()
	# Always resume BGM if it died while backgrounded. Mute/throttle stay exclusive-FS only.
	# (Do not gate on _should_mute() — that is false once _focused is true.)
	_notify_music_focus_restored()


func _apply_focus_lost_now() -> void:
	if not _focused:
		return
	_focused = false
	# Save playback position in every window mode so restore can continue after OS suspend.
	_notify_music_focus_lost()
	_apply_low_power_mode()
	_apply_unfocus_mute()
	_try_auto_pause_gameplay()
	app_unfocused.emit()


func _try_auto_pause_gameplay() -> void:
	if not _exclusive_fullscreen_when_focused:
		return
	var engine := get_tree().root.get_node_or_null("GameEngine")
	if engine and engine.has_method("auto_pause_on_unfocus"):
		engine.call_deferred("auto_pause_on_unfocus")


func _is_exclusive_fullscreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


# Throttle/mute only for exclusive fullscreen in the background.
# Borderless fullscreen and windowed stay at full FPS with audio playing.
func _should_throttle() -> bool:
	return not _focused and _exclusive_fullscreen_when_focused


func _apply_low_power_mode() -> void:
	if _low_power_active or not _should_throttle():
		return
	_saved_max_fps = Engine.max_fps
	Engine.max_fps = LOW_POWER_FPS
	_low_power_active = true


func _restore_low_power_mode() -> void:
	if not _low_power_active:
		return
	Engine.max_fps = _saved_max_fps
	_low_power_active = false


func _should_mute() -> bool:
	return _should_throttle()


func _apply_unfocus_mute() -> void:
	if not _should_mute() or _unfocus_muted:
		return
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx < 0:
		return
	_saved_master_muted = AudioServer.is_bus_mute(master_idx)
	AudioServer.set_bus_mute(master_idx, true)
	_unfocus_muted = true


func _restore_unfocus_mute() -> void:
	if not _unfocus_muted:
		return
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		AudioServer.set_bus_mute(master_idx, _saved_master_muted)
	_unfocus_muted = false


func refresh_unfocus_mute() -> void:
	if _should_mute():
		_apply_unfocus_mute()
	else:
		_restore_unfocus_mute()
	if _focused:
		_restore_low_power_mode()
	else:
		_apply_low_power_mode()


func _notify_music_focus_restored() -> void:
	if MusicManager and MusicManager.has_method("on_app_focus_restored"):
		MusicManager.on_app_focus_restored()


func _notify_music_focus_lost() -> void:
	if MusicManager and MusicManager.has_method("on_app_focus_lost"):
		MusicManager.on_app_focus_lost()


# Called when a background job (e.g. chart generation) finishes.
# Flashes the taskbar so the user notices while the game is in the background.
func notify_background_task_done() -> void:
	if _focused:
		return
	if SettingsManager and not bool(
		SettingsManager.get_setting("notify_generation_done_when_minimized", true)
	):
		return
	DisplayServer.window_request_attention()
