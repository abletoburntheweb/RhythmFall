extends RefCounted
class_name WindowIconApplier

const WINDOW_ICON_ICO := "res://assets/app_icons/default_multi.ico"
const WINDOW_ICON_PNG := "res://assets/app_icons/default_multi.png"
const WINDOW_ICON_SIZE := 128


static func apply() -> void:
	if OS.get_name() != "Windows":
		return
	var ico_path := ProjectSettings.globalize_path(WINDOW_ICON_ICO)
	if FileAccess.file_exists(ico_path):
		DisplayServer.set_native_icon(ico_path)
		return
	var image := _load_taskbar_image()
	if image == null:
		return
	DisplayServer.set_icon(image)


static func apply_deferred(tree: SceneTree) -> void:
	if tree == null:
		return
	tree.create_timer(0.0).timeout.connect(apply, CONNECT_ONE_SHOT)


static func _load_taskbar_image() -> Image:
	var image := Image.new()
	if image.load(WINDOW_ICON_ICO) == OK:
		return _normalize_icon_size(image)
	image = Image.new()
	if image.load(WINDOW_ICON_PNG) != OK:
		return null
	return _downscale(image, WINDOW_ICON_SIZE)


static func _normalize_icon_size(image: Image) -> Image:
	var side := mini(image.get_width(), image.get_height())
	if side <= 0:
		return null
	if side == WINDOW_ICON_SIZE:
		return image
	if side > WINDOW_ICON_SIZE:
		return _downscale(image, WINDOW_ICON_SIZE)
	return image


static func _downscale(image: Image, target: int) -> Image:
	var copy := image.duplicate()
	copy.resize(target, target, Image.INTERPOLATE_LANCZOS)
	return copy
