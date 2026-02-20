# scenes/shop/cover_gallery.gd
extends Control

signal gallery_closed
signal cover_selected(index: int)

@export var images_folder: String = ""
@export var images_count: int = 0

var cover_image_rects: Array[TextureRect] = []

func _ready():
	var grid_container = $GalleryContainer/GridMargin/Content
	if not grid_container or not grid_container is GridContainer:
		return

	cover_image_rects.clear()
	for i in range(1, 8):
		var image_rect_name = "CoverImage" + str(i)
		var image_rect = grid_container.get_node(image_rect_name)
		if image_rect and image_rect is TextureRect:
			cover_image_rects.append(image_rect)

	if cover_image_rects.size() < 7:
		pass
	else:
		pass 

	_load_images()
	show()

func _load_images():
	for i in range(cover_image_rects.size()):
		var image_rect = cover_image_rects[i]
		image_rect.texture = null 
		image_rect.visible = (i < images_count)
		if image_rect:
			image_rect.custom_minimum_size = Vector2(350, 350)
			image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED


	for i in range(images_count):
		var index = i + 1
		var image_path = images_folder + "/cover" + str(index) + ".png"
		
		if not FileAccess.file_exists(image_path):
			continue
		
		var texture = ResourceLoader.load(image_path)
		if texture and texture is Texture:
			if i < cover_image_rects.size():
				var image_rect = cover_image_rects[i]
				image_rect.texture = texture
				image_rect.visible = true
				image_rect.custom_minimum_size = Vector2(350, 350)
				image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			else:
				pass
		else:
			var loaded_resource = ResourceLoader.load(image_path)
			if loaded_resource:
				pass
			else:
				pass


func _on_texture_rect_gui_input(event: InputEvent, index: int):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("gallery_closed")
		queue_free()

func _on_back_button_pressed():
	MusicManager.play_cancel_sound()
	print("CoverGallery.gd: Воспроизведен звук cancel при нажатии кнопки Назад.")
	emit_signal("gallery_closed")
	queue_free()

func _input(event: InputEvent):
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		_on_back_button_pressed()
		accept_event()

func close_gallery():
	emit_signal("gallery_closed")
	queue_free()
