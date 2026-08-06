# scenes/song_select/playlists/playlist_ui_helpers.gd
extends RefCounted
class_name PlaylistUiHelpers

const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")
const _SongSelectUiStyles = preload("res://scenes/song_select/lib/song_select_ui_styles.gd")
const _TimeUtils = preload("res://logic/platform/time_utils.gd")

const MOSAIC_SIDE := 88
const MOSAIC_CELL := 42
const MOSAIC_GAP := 2


static func make_cover_mosaic(cover_paths: Array) -> PanelContainer:
	var outer := PanelContainer.new()
	outer.custom_minimum_size = Vector2(MOSAIC_SIDE, MOSAIC_SIDE)
	outer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.06, 0.09, 1.0)
	box.set_corner_radius_all(10)
	box.set_border_width_all(1)
	box.border_color = Color(1, 1, 1, 0.08)
	box.content_margin_left = 2
	box.content_margin_right = 2
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	outer.add_theme_stylebox_override("panel", box)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", MOSAIC_GAP)
	grid.add_theme_constant_override("v_separation", MOSAIC_GAP)
	outer.add_child(grid)
	for i in 4:
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(MOSAIC_CELL, MOSAIC_CELL)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cell_box := StyleBoxFlat.new()
		cell_box.bg_color = Color(0.12, 0.14, 0.18, 1.0)
		cell_box.set_corner_radius_all(4)
		cell.add_theme_stylebox_override("panel", cell_box)
		var cover := TextureRect.new()
		cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		cover.custom_minimum_size = Vector2(MOSAIC_CELL, MOSAIC_CELL)
		cell.add_child(cover)
		grid.add_child(cell)
		if i < cover_paths.size():
			var path := str(cover_paths[i]).strip_edges()
			if path != "":
				_SongSelectUiStyles.apply_row_cover_texture(cover, path, MOSAIC_CELL)
	return outer


static func make_meta_line(icon_file: String, caption: String, value: String, tint: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_UiIconHelper.make_icon_frame(icon_file, 18, 12, tint))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var cap := Label.new()
	cap.text = caption
	cap.add_theme_font_size_override("font_size", 11)
	cap.add_theme_color_override("font_color", Color(0.55, 0.60, 0.70, 0.92))
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(cap)
	if value.strip_edges() != "":
		var val := Label.new()
		val.text = value
		val.add_theme_font_size_override("font_size", 13)
		val.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))
		val.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(val)
	else:
		cap.add_theme_font_size_override("font_size", 13)
		cap.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))
	return row


static func format_last_played(last_iso: String) -> String:
	var iso := last_iso.strip_edges()
	if iso == "":
		return TranslationServer.translate("PLAYLIST_HUB_LAST_NEVER")
	var relative := _TimeUtils.format_relative_ago_or_date_from_unix(
		_TimeUtils.unix_from_local_iso_datetime(iso)
	)
	if relative.strip_edges() == "":
		return TranslationServer.translate("PLAYLIST_HUB_LAST_NEVER")
	return relative


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
