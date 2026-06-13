# scenes/shop/cover_gallery.gd
extends Control

signal gallery_closed
signal cover_selected(index: int)

@export var images_folder: String = ""
@export var images_count: int = 0
@export var item_title: String = ""

const GRID_CONTENT_PATH := "GalleryContainer/GalleryScroll/GridCenter/GridMargin/Content"
const GRID_COLUMNS := 4
const GRID_CELL_SIZE := 350.0
const GRID_SEPARATION := 30.0
const SLOT_COUNT := 7

var cover_image_rects: Array[TextureRect] = []
var cover_slot_panels: Array[PanelContainer] = []
var _path_to_rect: Dictionary = {}
var _loader: ThreadedTextureLoader = null
var _loader_connected: bool = false
var _hovered_slot_index: int = -1

@onready var _subtitle_label: Label = $GalleryContainer/SubtitleLabel

static var _placeholder_texture: Texture2D


func _ready():
	var grid_container := get_node_or_null(GRID_CONTENT_PATH)
	if grid_container == null or not grid_container is GridContainer:
		return

	_apply_header_text()
	_setup_slots(grid_container)

	call_deferred("_load_images_threaded")
	call_deferred("_update_grid_layout")
	show()


func _apply_header_text() -> void:
	if _subtitle_label == null:
		return
	var title := item_title.strip_edges()
	if title != "":
		_subtitle_label.text = "Варианты обложки: %s" % title
	else:
		_subtitle_label.text = "Варианты обложки товара"


func _setup_slots(grid_container: GridContainer) -> void:
	cover_image_rects.clear()
	cover_slot_panels.clear()

	for i in range(1, SLOT_COUNT + 1):
		var slot := grid_container.get_node_or_null("CoverSlot%d" % i) as PanelContainer
		if slot == null:
			continue
		slot.set_meta("slot_index", i - 1)
		cover_slot_panels.append(slot)

		var image_rect := slot.find_child("CoverImage%d" % i, true, false) as TextureRect
		if image_rect:
			cover_image_rects.append(image_rect)
			image_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

		if not slot.mouse_entered.is_connected(_on_slot_mouse_entered):
			slot.mouse_entered.connect(_on_slot_mouse_entered.bind(slot))
		if not slot.mouse_exited.is_connected(_on_slot_mouse_exited):
			slot.mouse_exited.connect(_on_slot_mouse_exited.bind(slot))
		slot.mouse_default_cursor_shape = Control.CURSOR_ARROW


func _on_slot_mouse_entered(slot: PanelContainer) -> void:
	if not slot.visible:
		return
	_hovered_slot_index = int(slot.get_meta("slot_index", -1))
	slot.theme_type_variation = &"CoverGallerySlotHover"


func _on_slot_mouse_exited(slot: PanelContainer) -> void:
	if int(slot.get_meta("slot_index", -1)) == _hovered_slot_index:
		_hovered_slot_index = -1
	slot.theme_type_variation = &"CoverGallerySlot"


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_grid_layout()


func _update_grid_layout() -> void:
	var grid := get_node_or_null(GRID_CONTENT_PATH) as GridContainer
	if grid == null:
		return

	grid.columns = GRID_COLUMNS

	var scroll := get_node_or_null("GalleryContainer/GalleryScroll") as Control
	var available_w := grid.size.x
	if available_w < 32.0 and scroll:
		available_w = scroll.size.x - 24.0
	if available_w < 32.0:
		available_w = GRID_CELL_SIZE * float(GRID_COLUMNS) + GRID_SEPARATION * float(GRID_COLUMNS - 1)

	var cell_w := (available_w - GRID_SEPARATION * float(GRID_COLUMNS - 1)) / float(GRID_COLUMNS)
	cell_w = minf(cell_w, GRID_CELL_SIZE)
	cell_w = maxf(cell_w, 140.0)
	var cell_size := Vector2(cell_w, cell_w)

	for slot in cover_slot_panels:
		slot.custom_minimum_size = cell_size
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	for image_rect in cover_image_rects:
		image_rect.custom_minimum_size = Vector2.ZERO
		image_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		image_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _slot_placeholder_texture() -> Texture2D:
	if _placeholder_texture != null:
		return _placeholder_texture
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.11, 0.12, 0.16, 1.0))
	_placeholder_texture = ImageTexture.create_from_image(img)
	return _placeholder_texture


func _exit_tree():
	if _loader != null and _loader_connected:
		if _loader.loaded.is_connected(_on_loader_loaded):
			_loader.loaded.disconnect(_on_loader_loaded)
		_loader_connected = false


func _load_images_threaded():
	var started_ms := Time.get_ticks_msec()
	var ph: Texture2D = _slot_placeholder_texture()
	for i in range(cover_image_rects.size()):
		var image_rect := cover_image_rects[i]
		var slot: PanelContainer = cover_slot_panels[i] if i < cover_slot_panels.size() else null
		image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		if i < images_count:
			image_rect.texture = ph
			image_rect.modulate = Color(0.72, 0.74, 0.78, 1.0)
			if slot:
				slot.visible = true
				slot.modulate = Color.WHITE
		else:
			image_rect.texture = null
			image_rect.modulate = Color.WHITE
			if slot:
				slot.visible = false

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
		if i % 2 == 1:
			await get_tree().process_frame
	print("[Perf] CoverGallery load image requests: %d ms, count=%d" % [Time.get_ticks_msec() - started_ms, images_count])
	_update_grid_layout()


func _on_loader_loaded(path: String, tex: Texture2D) -> void:
	if not _path_to_rect.has(path):
		return
	if tex == null:
		return
	var rect: TextureRect = _path_to_rect[path]
	rect.texture = tex
	rect.modulate = Color.WHITE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_update_grid_layout()


func _on_cover_slot_gui_input(event: InputEvent, index: int) -> void:
	if index >= images_count:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		MusicManager.play_cover_click_sound()
		emit_signal("cover_selected", index)
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
