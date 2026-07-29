extends HBoxContainer

const COLOR_CAPTION := Color(0.654902, 0.654902, 0.678431, 1)
const COLOR_VALUE := Color(0.784314, 0.823529, 0.901961, 1)


func apply_row(caption: String, value: String, value_color: Color = COLOR_VALUE) -> void:
	var cap := get_node_or_null("CaptionLabel") as Label
	var val := get_node_or_null("ValueLabel") as Label
	if cap:
		cap.text = caption
	if val:
		val.text = value
		val.add_theme_color_override("font_color", value_color)
