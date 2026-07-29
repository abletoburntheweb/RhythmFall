# logic/ui/slider_scroll_utils.gd
extends RefCounted
class_name SliderScrollUtils

## Mouse wheel on HSlider/VSlider steals scroll from ScrollContainer.
## Accept the wheel event without changing the slider; forward to nearest scroll.


static func disable_wheel_under(root: Node) -> void:
	if root == null:
		return
	_walk(root)


static func disable_wheel_on_slider(slider: Slider) -> void:
	if slider == null or not is_instance_valid(slider):
		return
	if slider.has_meta("_rf_wheel_scroll_wired"):
		return
	slider.set_meta("_rf_wheel_scroll_wired", true)
	slider.gui_input.connect(_on_slider_gui_input.bind(slider))


static func _walk(node: Node) -> void:
	if node is HSlider or node is VSlider:
		disable_wheel_on_slider(node as Slider)
	for child in node.get_children():
		_walk(child)


static func _on_slider_gui_input(event: InputEvent, slider: Slider) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		if mb.button_index != MOUSE_BUTTON_WHEEL_UP and mb.button_index != MOUSE_BUTTON_WHEEL_DOWN:
			return
		# Swallow so Range does not step; scroll the page instead.
		slider.accept_event()
		var scroll := _find_scroll_ancestor(slider)
		if scroll == null:
			return
		var step := 48.0
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll.scroll_vertical = maxi(0, scroll.scroll_vertical - int(step))
		else:
			scroll.scroll_vertical = scroll.scroll_vertical + int(step)


static func _find_scroll_ancestor(node: Node) -> ScrollContainer:
	var cur: Node = node.get_parent()
	while cur != null:
		if cur is ScrollContainer:
			return cur as ScrollContainer
		cur = cur.get_parent()
	return null
