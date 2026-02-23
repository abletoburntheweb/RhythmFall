# scenes/shop/cover_gallery.gd
extends Control

signal gallery_closed
signal cover_selected(index: int)

@export var images_folder: String = ""
@export var images_count: int = 0
@export var reveal_delay: float = 0.25

var cover_image_rects: Array[TextureRect] = []
var _path_to_rect: Dictionary = {}
var _loaded_textures: Dictionary = {}
var _reveal_timer: Timer = null
var _loader: ThreadedTextureLoader = null

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

	call_deferred("_load_images_threaded")
	show()

func _load_images_threaded():
	for i in range(cover_image_rects.size()):
		var image_rect = cover_image_rects[i]
		image_rect.texture = null
		image_rect.visible = false
		if image_rect:
			image_rect.custom_minimum_size = Vector2(350, 350)
			image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_path_to_rect.clear()
	_loaded_textures.clear()
	var loader_script = preload("res://logic/utils/threaded_texture_loader.gd")
	_loader = loader_script.get_instance()
	if _loader:
		_loader.loaded.connect(_on_loader_loaded)
	for i in range(images_count):
		var index = i + 1
		var image_path = images_folder + "/cover" + str(index) + ".png"
		if FileAccess.file_exists(image_path):
			_path_to_rect[image_path] = cover_image_rects[i]
			if _loader:
				_loader.request(image_path)
	if _reveal_timer == null:
		_reveal_timer = Timer.new()
		_reveal_timer.one_shot = true
		_reveal_timer.wait_time = reveal_delay
		_reveal_timer.timeout.connect(_on_reveal_timeout)
		add_child(_reveal_timer)
	_reveal_timer.start()

func _on_loader_loaded(path: String, tex: Texture2D) -> void:
	if tex:
		_loaded_textures[path] = tex

func _apply_textures_batch():
	pass

func _on_reveal_timeout():
	var i = 0
	for rect in cover_image_rects:
		if i >= images_count:
			rect.visible = false
		else:
			var path = images_folder + "/cover" + str(i + 1) + ".png"
			var tex: Texture2D = _loaded_textures.get(path, null)
			rect.texture = tex
			rect.visible = true
			rect.custom_minimum_size = Vector2(350, 350)
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		i += 1


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
