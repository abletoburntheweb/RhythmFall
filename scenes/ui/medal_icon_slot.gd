extends TextureRect


func apply_icon(icon_texture: Texture2D, tint: Color = Color.WHITE, min_size: Vector2 = Vector2(16, 16)) -> void:
	custom_minimum_size = min_size
	texture = icon_texture
	modulate = tint
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
