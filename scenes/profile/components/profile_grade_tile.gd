extends PanelContainer


func apply_grade(caption: String, value: String, value_color: Color, value_font_size: int = 24) -> void:
	var value_label := get_node_or_null("VBox/ValueLabel") as Label
	var caption_label := get_node_or_null("VBox/CaptionLabel") as Label
	if value_label:
		value_label.text = value
		value_label.add_theme_font_size_override("font_size", value_font_size)
		value_label.add_theme_color_override("font_color", value_color)
	if caption_label:
		caption_label.text = caption
