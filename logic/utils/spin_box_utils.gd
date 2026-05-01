# logic/utils/spin_box_utils.gd
extends RefCounted
class_name SpinBoxUtils

const DEFAULT_VALUE_FONT_SIZE := 24

static func apply_value_font_size(spin_box: SpinBox, font_size: int = DEFAULT_VALUE_FONT_SIZE) -> void:
	if spin_box == null or not is_instance_valid(spin_box):
		return
	spin_box.add_theme_font_size_override("font_size", font_size)
	var le: LineEdit = spin_box.get_line_edit()
	if le and is_instance_valid(le):
		le.add_theme_font_size_override("font_size", font_size)
