# logic/ui/ui_interaction_applier.gd
extends RefCounted
class_name UiInteractionApplier

const _SliderScrollUtils = preload("res://logic/ui/slider_scroll_utils.gd")


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
	clear_redundant_button_tooltips(root)


static func _walk(node: Node, source_theme: Theme) -> void:
	if node is Control:
		var control := node as Control
		_apply_cursor(control)
		if control is BaseButton and control.name == &"BackButton":
			_apply_back_button_icon(control as BaseButton)
		if control is HSlider or control is VSlider:
			_SliderScrollUtils.disable_wheel_on_slider(control as Slider)
		if source_theme != null:
			if control is BaseButton and not (control is CheckBox or control is CheckButton):
				_apply_button_hover_from_theme(control as BaseButton, source_theme)
			elif control is HSlider or control is VSlider:
				_apply_slider_styles_from_theme(control as Slider, source_theme)
	for child in node.get_children():
		_walk(child, source_theme)


static func clear_redundant_button_tooltips(root: Node) -> void:
	if root == null:
		return
	if root is Button:
		var btn := root as Button
		var tip: String = str(btn.tooltip_text).strip_edges()
		var label: String = str(btn.text).strip_edges()
		if tip != "" and tip == label:
			btn.tooltip_text = ""
	elif root is CheckBox:
		var checkbox := root as CheckBox
		var tip_cb: String = str(checkbox.tooltip_text).strip_edges()
		var label_cb: String = str(checkbox.text).strip_edges()
		if tip_cb != "" and tip_cb == label_cb:
			checkbox.tooltip_text = ""
	elif root is CheckButton:
		var check_btn := root as CheckButton
		var tip_ct: String = str(check_btn.tooltip_text).strip_edges()
		var label_ct: String = str(check_btn.text).strip_edges()
		if tip_ct != "" and tip_ct == label_ct:
			check_btn.tooltip_text = ""
	for child in root.get_children():
		clear_redundant_button_tooltips(child)


static func _apply_back_button_icon(button: BaseButton) -> void:
	if button == null or button.get_meta("ui_back_icon_applied", false):
		return
	UiIconHelper.setup_back_button(button)
	button.set_meta("ui_back_icon_applied", true)


static func _apply_cursor(control: Control) -> void:
	if control.has_meta("ui_force_cursor"):
		control.mouse_default_cursor_shape = int(control.get_meta("ui_force_cursor"))
		return
	if control.has_meta("ui_skip_cursor"):
		return
	if control is Button or control is CheckBox or control is CheckButton:
		control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	elif control is TextureButton:
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
	# Option chips / custom-styled toggles keep their own hover; theme FlatButton
	# hover would otherwise paint them primary-blue after screen enter.
	if btn.get_meta("ui_keep_style_overrides", false):
		return
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
