# scenes/shop/cover_gallery.gd
extends Control

signal gallery_closed
signal cover_selected(index: int)

@export var images_folder: String = ""
@export var images_count: int = 0

var cover_image_rects: Array[TextureRect] = []
var _path_to_rect: Dictionary = {}
var _loader: ThreadedTextureLoader = null
var _loader_connected: bool = false

static var _placeholder_texture: Texture2D


func _slot_placeholder_texture() -> Texture2D:
	if _placeholder_texture != null:
		return _placeholder_texture
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.11, 0.12, 0.16, 1.0))
	_placeholder_texture = ImageTexture.create_from_image(img)
	return _placeholder_texture


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

	call_deferred("_load_images_threaded")
	show()


func _exit_tree():
	if _loader != null and _loader_connected:
		if _loader.loaded.is_connected(_on_loader_loaded):
			_loader.loaded.disconnect(_on_loader_loaded)
		_loader_connected = false


func _load_images_threaded():
	var ph: Texture2D = _slot_placeholder_texture()
	for i in range(cover_image_rects.size()):
		var image_rect = cover_image_rects[i]
		image_rect.custom_minimum_size = Vector2(350, 350)
		image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		if i < images_count:
			image_rect.texture = ph
			image_rect.visible = true
			image_rect.modulate = Color(0.55, 0.57, 0.62, 1.0)
		else:
			image_rect.texture = null
			image_rect.visible = false
			image_rect.modulate = Color.WHITE

	_path_to_rect.clear()
	var loader_script = preload("res://logic/utils/threaded_texture_loader.gd")
	_loader = loader_script.get_instance()
	if _loader != null and not _loader_connected:
		_loader.loaded.connect(_on_loader_loaded)
		_loader_connected = true

	for i in range(images_count):
		var index = i + 1
		var image_path = images_folder + "/cover" + str(index) + ".png"
		if FileAccess.file_exists(image_path):
			_path_to_rect[image_path] = cover_image_rects[i]
			if _loader:
				_loader.request(image_path)


func _on_loader_loaded(path: String, tex: Texture2D) -> void:
	if not _path_to_rect.has(path):
		return
	if tex == null:
		return
	var rect: TextureRect = _path_to_rect[path]
	rect.texture = tex
	rect.visible = true
	rect.modulate = Color.WHITE
	rect.custom_minimum_size = Vector2(350, 350)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED


func _on_texture_rect_gui_input(event: InputEvent, index: int):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("gallery_closed")
		queue_free()


func _on_back_button_pressed():
	MusicManager.play_cancel_sound()
	emit_signal("gallery_closed")
	queue_free()


func _input(event: InputEvent):
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		_on_back_button_pressed()
		accept_event()


func close_gallery():
	emit_signal("gallery_closed")
	queue_free()
