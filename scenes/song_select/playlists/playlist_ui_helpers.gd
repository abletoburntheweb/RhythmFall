# scenes/song_select/playlists/playlist_ui_helpers.gd
extends RefCounted
class_name PlaylistUiHelpers

const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")


static func make_tag_pill(icon_file: String, text: String, accent: Color) -> PanelContainer:
	var pill := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(accent.r, accent.g, accent.b, 0.14)
	box.border_color = accent.lerp(Color.WHITE, 0.22)
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	pill.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	if icon_file.strip_edges() != "":
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(12, 12)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = _UiIconHelper.load_tinted_icon(icon_file, accent.lightened(0.15), 12)
		row.add_child(icon)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", accent.lerp(Color.WHITE, 0.42))
	row.add_child(lbl)
	pill.add_child(row)
	return pill


static func add_tags_to_row(row: HBoxContainer, tags: Array, max_count: int = 5) -> void:
	if row == null:
		return
	for child in row.get_children():
		child.queue_free()
	var shown := 0
	for tag in tags:
		if shown >= max_count:
			break
		if not tag is Dictionary:
			continue
		var text := str((tag as Dictionary).get("text", "")).strip_edges()
		if text == "":
			continue
		var icon_file := str((tag as Dictionary).get("icon", "")).strip_edges()
		var accent: Color = (tag as Dictionary).get("accent", _UiIconHelper.ACCENT) as Color
		row.add_child(make_tag_pill(icon_file, text, accent))
		shown += 1
