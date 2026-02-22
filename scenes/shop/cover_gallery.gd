# scenes/shop/cover_gallery.gd
extends Control

signal gallery_closed
signal cover_selected(index: int)

@export var images_folder: String = ""
@export var images_count: int = 0

var cover_image_rects: Array[TextureRect] = []
var _texture_cache: Dictionary = {}
var _is_loading: bool = false
var _pending_paths: Array = []
var _poll_timer: Timer = null

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
	if _is_loading:
		return
	_is_loading = true
	for i in range(cover_image_rects.size()):
		var image_rect = cover_image_rects[i]
		image_rect.texture = null
		image_rect.visible = (i < images_count)
		if image_rect:
			image_rect.custom_minimum_size = Vector2(350, 350)
			image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_pending_paths.clear()
	for i in range(images_count):
		var index = i + 1
		var image_path = images_folder + "/cover" + str(index) + ".png"
		if FileAccess.file_exists(image_path):
			_pending_paths.append(image_path)
			ResourceLoader.load_threaded_request(image_path, "Texture")
	if _poll_timer == null:
		_poll_timer = Timer.new()
		_poll_timer.wait_time = 0.05
		_poll_timer.one_shot = false
		_poll_timer.timeout.connect(_on_poll_threaded)
		add_child(_poll_timer)
	_poll_timer.start()

func _on_poll_threaded():
	if _pending_paths.is_empty():
		if _poll_timer:
			_poll_timer.stop()
		_apply_textures_batch()
		_is_loading = false
		return
	var completed: Array = []
	for path in _pending_paths:
		var status = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var tex = ResourceLoader.load_threaded_get(path)
			if tex and tex is Texture:
				_texture_cache[path] = tex
			completed.append(path)
		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			completed.append(path)
	for path in completed:
		_pending_paths.erase(path)

func _apply_textures_batch():
	var i = 0
	for rect in cover_image_rects:
		if i >= images_count:
			rect.visible = false
		else:
			var path = images_folder + "/cover" + str(i + 1) + ".png"
			if _texture_cache.has(path):
				rect.texture = _texture_cache[path]
				rect.visible = true
				rect.custom_minimum_size = Vector2(350, 350)
				rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			else:
				rect.texture = null
				rect.visible = true
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
