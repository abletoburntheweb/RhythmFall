# scenes/profile/share/profile_share_export.gd
# Profile stats export — HTML templates + Playwright (render on worker thread).
class_name ProfileShareExport
extends RefCounted

const _HtmlExport = preload("res://scenes/profile/share/profile_share_html_export.gd")


static func save_card(card_id: String, data: Dictionary, path: String, size: Vector2i) -> Dictionary:
	if not _HtmlExport.is_available():
		return {
			"ok": false,
			"error_key": "PROFILE_SHARE_EXPORT_ERR_CODE",
			"error_code": _HtmlExport.get_last_error_code(),
			"detail": _HtmlExport.get_last_error(),
		}

	var save_path := path.replace("\\", "/")
	if not save_path.begins_with("/") and not save_path.contains(":"):
		save_path = ProjectSettings.globalize_path(save_path).replace("\\", "/")

	var batch := await _HtmlExport.render_export_batch(
		[{"card_id": card_id, "data": data, "out_path": save_path}],
		size,
		1.0,
	)
	if not batch.get("ok", false):
		return {
			"ok": false,
			"error_key": "PROFILE_SHARE_EXPORT_ERR_CODE",
			"error_code": str(batch.get("error_code", _HtmlExport.get_last_error_code())),
			"detail": _HtmlExport.get_last_error(),
		}
	return {"ok": true, "path": save_path, "backend": "html"}


static func render_preview_batch(items: Array, render_size: Vector2i, display_size: Vector2i) -> Dictionary:
	var textures: Dictionary = {}
	if not _HtmlExport.is_available():
		for item in items:
			textures[str(item.get("card_id", ""))] = null
		return textures

	var images: Dictionary = await _HtmlExport.render_preview_batch(items, render_size, 1.0)
	for item in items:
		var card_id := str(item.get("card_id", ""))
		var img: Variant = images.get(card_id)
		if img == null or not img is Image:
			textures[card_id] = null
			continue
		textures[card_id] = ImageTexture.create_from_image(img as Image)
	return textures


static func render_preview_one(card_id: String, data: Dictionary, render_size: Vector2i, display_size: Vector2i) -> Texture2D:
	if not _HtmlExport.is_available():
		return null
	var img: Variant = await _HtmlExport.render_preview_one(card_id, data, render_size, 1.0)
	if img == null or not img is Image:
		return null
	return ImageTexture.create_from_image(img as Image)


static func save_all_cards(items: Array, size: Vector2i) -> Dictionary:
	if not _HtmlExport.is_available():
		return {
			"ok": false,
			"error_code": _HtmlExport.get_last_error_code(),
		}
	return await _HtmlExport.render_export_batch(items, size, 1.0)
