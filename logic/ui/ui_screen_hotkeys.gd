# logic/ui/ui_screen_hotkeys.gd
extends RefCounted
class_name UiScreenHotkeys


static func is_global_loading_active(viewport: Viewport = null) -> bool:
	if viewport == null:
		var tree := Engine.get_main_loop() as SceneTree
		if tree:
			viewport = tree.root.get_viewport()
	if viewport == null:
		return false
	var ge := viewport.get_tree().root.get_node_or_null("GameEngine")
	if ge and ge.has_method("get_loading_overlay"):
		var overlay = ge.get_loading_overlay()
		if overlay and overlay.has_method("is_active") and overlay.is_active():
			return true
	return false


static func should_block_hotkeys(viewport: Viewport) -> bool:
	if viewport == null:
		return false
	if is_global_loading_active(viewport):
		return true
	var owner := viewport.gui_get_focus_owner()
	if owner == null:
		return false
	if owner is LineEdit or owner is TextEdit or owner is CodeEdit:
		return true
	if owner is SpinBox:
		return true
	if owner is Slider:
		return true
	return false


static func try_handle(bindings: Dictionary, event: InputEvent, viewport: Viewport) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false
	if should_block_hotkeys(viewport):
		return false
	if not bindings.has(key_event.keycode):
		return false
	var callback: Callable = bindings[key_event.keycode]
	if callback.is_valid():
		callback.call()
	return true


static func bind_digits(
	bindings: Dictionary,
	start_keycode: int,
	count: int,
	callback: Callable
) -> void:
	for i in range(count):
		bindings[start_keycode + i] = callback.bind(i)


static func press_button(button: BaseButton) -> void:
	if button and is_instance_valid(button) and not button.disabled:
		button.emit_signal("pressed")


static func play_section_switch_sound() -> void:
	if MusicManager and MusicManager.has_method("play_modifier_select_sound"):
		MusicManager.play_modifier_select_sound()
