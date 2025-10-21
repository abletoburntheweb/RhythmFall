# scenes/shop/cover_gallery.gd
extends Control

signal gallery_closed
signal cover_selected(index: int)

@export var images_folder: String = ""
@export var images_count: int = 0

var cover_images: Array[Texture] = []

func _ready():
	var background = $Background
	if background and background is ColorRect:
		background.color = Color(0, 0, 0, 0.7) # Черный цвет с прозрачностью 70%

	for i in range(1, images_count + 1):
		var cover_path = images_folder + "/cover%d.png" % i
		var image = Image.new()
		var error = image.load(cover_path)
		if error == OK:
			var texture = ImageTexture.create_from_image(image)
			if texture:
				cover_images.append(texture)
			else:
				print("CoverGallery.gd: Не удалось создать текстуру для: ", cover_path)
		else:
			print("CoverGallery.gd: Ошибка загрузки изображения: ", cover_path)

	if images_count == 0 or cover_images.size() == 0:
		var error_label = $ErrorLabel
		if error_label:
			error_label.visible = true
			return

	var grid_container = $GalleryContainer/CoversGrid
	for i in range(cover_images.size()):
		var texture = cover_images[i]
		var texture_rect = TextureRect.new()
		texture_rect.texture = texture
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
		texture_rect.mouse_filter = Control.MOUSE_FILTER_STOP

		texture_rect.connect("gui_input", _on_texture_rect_gui_input.bind(i))

		grid_container.add_child(texture_rect)

	show()

func _on_texture_rect_gui_input(event: InputEvent, index: int):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("CoverGallery.gd: Клик на обложку %d." % index)
		emit_signal("cover_selected", index)

func _on_back_button_pressed():
	emit_signal("gallery_closed")
	queue_free() # Закрываем галерею

func _input(event: InputEvent):
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		_on_back_button_pressed()

func close_gallery():
	emit_signal("gallery_closed")
	queue_free()
