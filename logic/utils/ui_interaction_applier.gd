# logic/utils/ui_interaction_applier.gd
extends RefCounted
class_name UiInteractionApplier


static func apply_from_engine(root: Node) -> void:
	if root == null or not root.is_inside_tree():
		return
	var game_engine := root.get_tree().root.get_node_or_null("GameEngine")
	var source_theme: Theme = game_engine.theme if game_engine else null
	apply_to_tree(root, source_theme)


static func apply_to_tree(root: Node, source_theme: Theme = null) -> void:
	if root == null:
		return
	_walk(root, source_theme)


static func _walk(node: Node, source_theme: Theme) -> void:
	if node is Control:
		var control := node as Control
		_apply_cursor(control)
		if source_theme != null:
			if control is BaseButton:
				_apply_button_hover_from_theme(control as BaseButton, source_theme)
			elif control is HSlider or control is VSlider:
				_apply_slider_styles_from_theme(control as Slider, source_theme)
	for child in node.get_children():
		_walk(child, source_theme)


static func _apply_cursor(control: Control) -> void:
	if control.has_meta("ui_force_cursor"):
		control.mouse_default_cursor_shape = int(control.get_meta("ui_force_cursor"))
		return
	if control.has_meta("ui_skip_cursor"):
		return
	if control is Button or control is CheckBox or control is CheckButton:
		control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	elif control is LinkButton or control is OptionButton or control is MenuButton or control is ColorPickerButton:
		control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	elif control is ItemList or control is Tree or control is TabBar or control is SpinBox:
		control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	elif control is HSlider:
		control.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	elif control is VSlider:
		control.mouse_default_cursor_shape = Control.CURSOR_VSIZE
	elif control is LineEdit or control is TextEdit or control is CodeEdit:
		control.mouse_default_cursor_shape = Control.CURSOR_IBEAM


static func _apply_button_hover_from_theme(btn: BaseButton, source_theme: Theme) -> void:
	var type_name: StringName = btn.theme_type_variation
	if type_name == &"":
		type_name = btn.get_class()
	var hover := source_theme.get_stylebox("hover", type_name)
	if hover != null:
		btn.add_theme_stylebox_override("hover", hover.duplicate())


static func _apply_slider_styles_from_theme(slider: Slider, source_theme: Theme) -> void:
	var type_name := slider.get_class()
	for style_name in ["slider", "grabber_area", "grabber", "grabber_highlight", "grabber_pressed"]:
		var sb := source_theme.get_stylebox(style_name, type_name)
		if sb != null:
			slider.add_theme_stylebox_override(style_name, sb.duplicate())
