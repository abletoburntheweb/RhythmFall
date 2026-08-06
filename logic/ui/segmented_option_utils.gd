# logic/ui/segmented_option_utils.gd
extends RefCounted
class_name SegmentedOptionUtils

## Compact option row — same visual language as lane buttons in generation_settings_selector.

const ACTIVE_COLOR := Color(0.8, 0.8, 1.0, 1.0)
const DEFAULT_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const BUTTON_VARIATION := &"FlatModalPrimaryButton"


static func build_from_option_button(
	option_btn: OptionButton,
	font_size: int = 18,
	min_height: int = 44,
	min_total_width: float = 280.0
) -> Dictionary:
	if option_btn == null:
		return {}
	var row := option_btn.get_parent() as HBoxContainer
	if row == null:
		return {}

	var buttons: Array[Button] = []
	var container := HBoxContainer.new()
	container.name = "%sSegmented" % option_btn.name
	container.add_theme_constant_override("separation", 10)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	container.alignment = BoxContainer.ALIGNMENT_END
	container.custom_minimum_size.x = min_total_width

	var theme_res: Theme = option_btn.theme
	for i in range(option_btn.get_item_count()):
		var id := option_btn.get_item_id(i)
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.text = option_btn.get_item_text(i)
		btn.custom_minimum_size = Vector2(0, min_height)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if theme_res:
			btn.theme = theme_res
		btn.theme_type_variation = BUTTON_VARIATION
		btn.add_theme_font_size_override("font_size", font_size)
		btn.set_meta("option_id", id)
		container.add_child(btn)
		buttons.append(btn)

	row.add_child(container)
	option_btn.visible = false
	option_btn.focus_mode = Control.FOCUS_NONE
	option_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var seg := {
		"container": container,
		"buttons": buttons,
		"option_button": option_btn,
	}
	sync_from_option_button(seg)
	return seg


static func select_id(buttons: Array, id: int, _accent: Color = Color.WHITE) -> void:
	for btn in buttons:
		if btn is Button:
			var selected := int(btn.get_meta("option_id", -1)) == id
			btn.self_modulate = ACTIVE_COLOR if selected else DEFAULT_COLOR


static func sync_from_option_button(seg: Dictionary) -> void:
	var opt: OptionButton = seg.get("option_button")
	var buttons: Array = seg.get("buttons", [])
	if opt == null or buttons.is_empty():
		return
	var idx := opt.selected
	if idx < 0:
		idx = 0
	if idx >= opt.get_item_count():
		idx = opt.get_item_count() - 1
	select_id(buttons, opt.get_item_id(idx))


static func id_from_button(button: Button) -> int:
	return int(button.get_meta("option_id", -1))


static func play_segment_select_sound() -> void:
	if MusicManager and MusicManager.has_method("play_modifier_select_sound"):
		MusicManager.play_modifier_select_sound()


static func apply_texts(buttons: Array, texts: PackedStringArray) -> void:
	for i in range(mini(buttons.size(), texts.size())):
		var btn: Button = buttons[i]
		if btn:
			btn.text = texts[i]
