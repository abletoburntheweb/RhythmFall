# scenes/shop/cover_gallery.gd
extends Control

signal gallery_closed
signal cover_selected(index: int)

@export var images_folder: String = ""
@export var images_count: int = 0

var cover_image_rects: Array[TextureRect] = []

func _ready():
	var background = $Background
	if background and background is ColorRect:
		background.color = Color(0, 0, 0, 180.0 / 255.0)
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE 

	var back_button = $GalleryContainer/BackButton
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)

	var grid_container = $GalleryContainer/Content
	if not grid_container or not grid_container is GridContainer:
		printerr("CoverGallery.gd: Content не является GridContainer!")
		return

	cover_image_rects.clear()
	for i in range(1, 8):
		var image_rect_name = "CoverImage" + str(i)
		var image_rect = grid_container.get_node(image_rect_name)
		if image_rect and image_rect is TextureRect:
			cover_image_rects.append(image_rect)
		else:
			printerr("CoverGallery.gd: Не удалось найти TextureRect с именем: ", image_rect_name)

	if cover_image_rects.size() < 7:
		printerr("CoverGallery.gd: Найдено только ", cover_image_rects.size(), " TextureRect, а должно быть 7.")
	else:
		print("CoverGallery.gd: Найдено ", cover_image_rects.size(), " TextureRect.")

	_load_images()

	_connect_texture_rect_signals()

	show()


func _load_images():
	for i in range(cover_image_rects.size()):
		var image_rect = cover_image_rects[i]
		image_rect.texture = null 
		image_rect.visible = (i < images_count)

	for i in range(images_count):
		var index = i + 1
		var image_path = images_folder + "/cover" + str(index) + ".png"

		var image = Image.new()
		var error = image.load(image_path)
		if error == OK and image:
			var texture = ImageTexture.create_from_image(image)
			if texture:
				if i < cover_image_rects.size():
					cover_image_rects[i].texture = texture
					cover_image_rects[i].visible = true
					print("CoverGallery.gd: Обложка ", index, " загружена в TextureRect ", i)
				else:
					print("CoverGallery.gd: Индекс ", i, " выходит за пределы массива cover_image_rects.")
			else:
				print("CoverGallery.gd: Не удалось создать ImageTexture для: ", image_path)
		else:
			print("CoverGallery.gd: Ошибка загрузки изображения: ", image_path, " Код ошибки: ", error)


func _connect_texture_rect_signals():
	for i in range(images_count):
		if i < cover_image_rects.size():
			var image_rect = cover_image_rects[i]
			image_rect.gui_input.connect(_on_texture_rect_gui_input.bind(i), CONNECT_ONE_SHOT)


func _on_texture_rect_gui_input(event: InputEvent, index: int):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("CoverGallery.gd: Клик на обложку %d." % (index + 1))
		emit_signal("gallery_closed")
		queue_free()


func _on_back_button_pressed():
	emit_signal("gallery_closed")
	queue_free()


func _input(event: InputEvent):
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		_on_back_button_pressed()


func close_gallery():
	emit_signal("gallery_closed")
	queue_free()
