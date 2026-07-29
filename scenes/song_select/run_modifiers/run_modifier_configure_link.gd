# scenes/song_select/run_modifiers/run_modifier_configure_link.gd
extends LinkButton

func _ready() -> void:
	underline = UNDERLINE_MODE_ALWAYS
	add_theme_font_size_override("font_size", 14)
	add_theme_color_override("font_color", Color(0.55, 0.78, 0.98, 1.0))
	add_theme_color_override("font_hover_color", Color(0.72, 0.88, 1.0, 1.0))
	focus_mode = Control.FOCUS_NONE
