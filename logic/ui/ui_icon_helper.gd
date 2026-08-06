# logic/ui/ui_icon_helper.gd
extends RefCounted
class_name UiIconHelper

const ICONS_DIR := "res://assets/icons/"
const ACCENT := Color(0.55, 0.78, 0.98, 1.0)
const ACCENT_MINT := Color(0.62, 0.86, 0.72, 1.0)
const ACCENT_DNA := Color(0.98, 0.72, 0.32, 1.0)
const ACCENT_BRIGHT := Color(0.72, 0.88, 1.0, 1.0)
const MUTED := Color(0.5, 0.54, 0.62, 0.85)
const ICON_RESET_DANGER := Color(0.95, 0.55, 0.48, 1.0)
const ICON_NEUTRAL_BTN := Color(0.82, 0.86, 0.94, 1.0)
const SEARCH_ICON_GUTTER := 34
const META_ICON_FILE := &"ui_icon_file"
const META_ICON_TINT := &"ui_icon_tint"
const META_ICON_DISPLAY_SIZE := &"ui_icon_display_size"

static var _tint_cache: Dictionary = {}
static var _svg_source_cache: Dictionary = {}

# Lucide icons use a 24x24 viewBox. Rasterizing the vector source at the
# display resolution keeps icons crisp instead of upscaling the small
# imported bitmap (which caused blurry "staircase" edges).
const _SVG_NATIVE_SIZE := 24.0
const _RASTER_SCALE := 6


static func raster_size_for_display(display_px: int) -> int:
	return maxi(48, display_px * _RASTER_SCALE)


static func raster_size_for_framed_icon(frame_size: int, icon_size: int) -> int:
	# Framed icons are scaled by PanelContainer layout; rasterize at the larger
	# of icon and frame size so the downscale stays sharp inside the circle.
	return maxi(raster_size_for_display(icon_size), raster_size_for_display(frame_size))


static func load_icon(file_name: String) -> Texture2D:
	if file_name.strip_edges() == "":
		return null
	var path := _resolve_path(file_name)
	if not ResourceLoader.exists(path):
		push_warning("UiIconHelper: missing icon %s" % path)
		return null
	return load(path) as Texture2D


static func load_tinted_icon(file_name: String, color: Color, min_pixel_size: int = 48) -> Texture2D:
	if file_name.strip_edges() == "":
		return null
	var cache_key := "%s|%.4f|%.4f|%.4f|%.4f|%d" % [
		file_name, color.r, color.g, color.b, color.a, min_pixel_size
	]
	if _tint_cache.has(cache_key):
		return _tint_cache[cache_key]
	var image := _rasterize_svg(file_name, min_pixel_size)
	if image == null:
		var base := load_icon(file_name)
		if base == null:
			return null
		image = base.get_image()
		if image == null or image.is_empty():
			_tint_cache[cache_key] = base
			return base
		image = _ensure_icon_resolution(image, min_pixel_size)
	var tinted_img := _tint_image(image, color)
	var tinted := ImageTexture.create_from_image(tinted_img)
	_tint_cache[cache_key] = tinted
	return tinted


static func make_texture_rect(texture: Texture2D, size: int) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(size, size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Nearest is crisp for integer scales; linear softens odd downscales of tinted SVGs.
	icon.texture_filter = (
		CanvasItem.TEXTURE_FILTER_NEAREST if size >= 16 else CanvasItem.TEXTURE_FILTER_LINEAR
	)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = texture
	icon.modulate = Color.WHITE
	return icon


static func make_modulated_icon_rect(file_name: String, tint: Color, size: int) -> TextureRect:
	var icon := make_texture_rect(load_icon(file_name), size)
	if icon.texture == null:
		return icon
	icon.modulate = tint
	return icon


static func make_icon_frame(file_name: String, frame_size: int = 36, icon_size: int = 20, tint: Color = ACCENT) -> PanelContainer:
	var safe_frame := maxi(1, frame_size)
	var safe_icon := clampi(icon_size, 1, safe_frame)
	var frame := PanelContainer.new()
	# Lock square geometry so circular StyleBoxFlat never becomes an oval when a
	# parent stretches the control (common in profile record rows).
	frame.custom_minimum_size = Vector2(safe_frame, safe_frame)
	frame.size = Vector2(safe_frame, safe_frame)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(safe_frame / 2)
	box.bg_color = _frame_bg(tint, false)
	# No border on circular frames: StyleBoxFlat circle+border draws a vertical seam.
	box.set_border_width_all(0)
	box.set_content_margin_all(0)
	frame.add_theme_stylebox_override("panel", box)

	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(safe_frame, safe_frame)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(center)

	var icon := make_texture_rect(
		load_tinted_icon(file_name, tint, raster_size_for_framed_icon(safe_frame, safe_icon)),
		safe_icon
	)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(icon)
	frame.set_meta("ui_icon_file", file_name)
	frame.set_meta("ui_icon_tint", tint)
	frame.set_meta(META_ICON_DISPLAY_SIZE, safe_icon)
	frame.set_meta("ui_icon_frame_size", safe_frame)
	frame.set_meta("ui_icon_rect", icon)
	frame.set_meta("ui_icon_frame_box", box)
	return frame


static func set_frame_tint(frame: PanelContainer, tint: Color, selected: bool = false) -> void:
	if frame == null:
		return
	var file_name: String = str(frame.get_meta("ui_icon_file")) if frame.has_meta("ui_icon_file") else ""
	var icon: TextureRect = null
	if frame.has_meta("ui_icon_rect"):
		icon = frame.get_meta("ui_icon_rect") as TextureRect
	elif frame.get_child_count() > 0 and frame.get_child(0) is TextureRect:
		icon = frame.get_child(0) as TextureRect
	var box: StyleBoxFlat = null
	if frame.has_meta("ui_icon_frame_box"):
		box = frame.get_meta("ui_icon_frame_box") as StyleBoxFlat
	else:
		var panel_style := frame.get_theme_stylebox("panel")
		if panel_style is StyleBoxFlat:
			box = (panel_style as StyleBoxFlat).duplicate() as StyleBoxFlat
		else:
			box = StyleBoxFlat.new()
			var radius := int(frame.custom_minimum_size.x * 0.5) if frame.custom_minimum_size.x > 0.0 else 16
			box.set_corner_radius_all(radius)
	if icon and file_name != "":
		var use_tint := tint.lightened(0.1) if selected else tint
		var display_px := int(frame.get_meta(META_ICON_DISPLAY_SIZE, int(icon.custom_minimum_size.x)))
		var frame_px := int(frame.get_meta("ui_icon_frame_size", int(frame.custom_minimum_size.x)))
		icon.texture = load_tinted_icon(
			file_name, use_tint, raster_size_for_framed_icon(frame_px, display_px)
		)
	if box:
		box.bg_color = _frame_bg(tint, selected)
		# Keep circles borderless — a 1px ring on a full-circle StyleBoxFlat causes a center seam.
		box.set_border_width_all(0)
		frame.add_theme_stylebox_override("panel", box)


static func apply_button_icon(button: BaseButton, file_name: String, tint: Color = ACCENT, icon_size: int = 18) -> void:
	if button == null or file_name.strip_edges() == "":
		return
	var tex := load_tinted_icon(file_name, tint, raster_size_for_display(icon_size))
	if tex:
		button.icon = tex


static func configure_button_icon(
	button: BaseButton,
	file_name: String,
	tint: Color = ACCENT,
	icon_size: int = 18
) -> void:
	if button == null:
		return
	apply_button_icon(button, file_name, tint, icon_size)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_constant_override("icon_max_width", icon_size)
	button.add_theme_constant_override("h_separation", 8)


static func icon_tint_from_button_outline(button: BaseButton) -> Color:
	if button == null:
		return ACCENT
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := button.get_theme_stylebox(state)
		if style is StyleBoxFlat:
			var border := (style as StyleBoxFlat).border_color
			if border.a > 0.08:
				return border
	return ACCENT


static func apply_icon_from_meta(button: BaseButton, icon_size: int = 18, tint_override: Variant = null) -> bool:
	if button == null or not is_instance_valid(button):
		return false
	if not button.has_meta(META_ICON_FILE):
		return false
	var file_name := str(button.get_meta(META_ICON_FILE))
	if file_name.strip_edges() == "":
		return false
	var tint: Color
	if tint_override is Color:
		tint = tint_override
	elif button.has_meta(META_ICON_TINT):
		tint = button.get_meta(META_ICON_TINT)
	else:
		tint = icon_tint_from_button_outline(button)
	configure_button_icon(button, file_name, tint, icon_size)
	return true


static func apply_icons_from_meta(buttons: Array, icon_size: int = 18) -> void:
	for btn in buttons:
		if btn is BaseButton:
			apply_icon_from_meta(btn as BaseButton, icon_size)


static func mark_option_button_icon(
	button: OptionButton,
	file_name: String,
	tint: Color = MUTED,
	icon_size: int = 18
) -> void:
	if button == null or file_name.strip_edges() == "":
		return
	button.set_meta("ui_option_icon_file", file_name)
	button.set_meta("ui_option_icon_tint", tint)
	button.set_meta("ui_option_icon_size", icon_size)
	refresh_option_button_icon(button)


static func refresh_option_button_icon(button: OptionButton) -> void:
	if button == null:
		return
	var file_name: String = str(button.get_meta("ui_option_icon_file", ""))
	if file_name.strip_edges() == "":
		return
	var tint: Color = button.get_meta("ui_option_icon_tint", MUTED)
	var icon_size: int = int(button.get_meta("ui_option_icon_size", 18))
	configure_button_icon(button, file_name, tint, icon_size)


static func setup_search_field(line_edit: LineEdit) -> void:
	embed_line_edit_leading_icon(line_edit, "search.svg", MUTED, SEARCH_ICON_GUTTER)


static func setup_confirm_button(button: BaseButton) -> void:
	configure_button_icon(button, "check.svg", ACCENT_BRIGHT)


static func setup_modal_accent_button(
	button: BaseButton,
	icon_file: String,
	border_accent: Color,
	icon_size: int = 16,
	variation: StringName = &"FlatModalPrimaryButton"
) -> void:
	if button == null:
		return
	button.theme_type_variation = variation
	apply_outline_accent(button, border_accent, variation)
	if icon_file.strip_edges() != "":
		configure_button_icon(button, icon_file, border_accent, icon_size)


## Tint Flat* outline buttons to a page accent (settings tabs, etc.).
## Keeps existing theme_type_variation; skips exit/danger styles.
static func apply_outline_accent(
	button: BaseButton,
	border_accent: Color,
	variation: StringName = &""
) -> void:
	if button == null:
		return
	var type_name: StringName = variation if variation != &"" else button.theme_type_variation
	if type_name == &"":
		type_name = &"FlatButton"
	if is_danger_button_variation(type_name):
		return
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var base := button.get_theme_stylebox(state, type_name)
		if base == null:
			base = button.get_theme_stylebox(state)
		if base == null:
			continue
		var box := base.duplicate() as StyleBoxFlat
		if box == null:
			continue
		var border := border_accent
		if state == "disabled":
			border = Color(border.r, border.g, border.b, 0.35)
		elif state == "hover":
			border = border.lerp(Color(1, 1, 1, 1), 0.12)
		elif state == "pressed":
			border = border.darkened(0.08)
		else:
			border = Color(border.r, border.g, border.b, 0.85)
		box.border_color = border
		# Soft fill wash in the accent hue (keeps dark slate base).
		if state != "disabled":
			var wash_a := 0.14 if state == "normal" else (0.2 if state == "hover" else 0.18)
			box.bg_color = Color(border_accent.r, border_accent.g, border_accent.b, wash_a).lerp(
				Color(0.10, 0.11, 0.15, 0.96),
				0.55
			)
		button.add_theme_stylebox_override(state, box)


static func is_danger_button_variation(variation: StringName) -> bool:
	return (
		variation == &"FlatExitButton"
		or variation == &"FlatModalDangerButton"
		or variation == &"FlatDangerButton"
	)


static func configure_modal_overlay(control: Control, layer: int = 100) -> void:
	if control == null:
		return
	control.z_as_relative = false
	control.z_index = layer
	var bg := control.get_node_or_null("Background") as ColorRect
	if bg:
		var c := bg.color
		bg.color = Color(c.r, c.g, c.b, maxf(c.a, 0.94))


static func setup_back_button(button: BaseButton, tint: Color = MUTED) -> void:
	configure_button_icon(button, "arrow-left.svg", tint, 16)


## Full-screen hub screens (play modes, profile, library, …):
## MainVBox/Root inset = HUB_CONTENT_INSET, BackButton first child, FlatButton outline.
const HUB_CONTENT_INSET := 24.0
const HUB_BACK_MIN_SIZE := Vector2(140, 0)
const BACK_BUTTON_MIN_SIZE := Vector2(140, 36)


static func apply_hub_back_button(button: BaseButton, tint: Color = MUTED) -> void:
	if button == null:
		return
	button.custom_minimum_size = HUB_BACK_MIN_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.theme_type_variation = &"FlatButton"
	setup_back_button(button, tint)


## Modal / overlay Back chips (filled slate). Prefer apply_hub_back_button on full screens.
static func apply_standard_back_button(button: BaseButton, tint: Color = MUTED) -> void:
	if button == null:
		return
	button.custom_minimum_size = BACK_BUTTON_MIN_SIZE
	button.theme_type_variation = &"FlatBackButton"
	setup_back_button(button, tint)


static func setup_reset_button(button: BaseButton) -> void:
	if button == null:
		return
	var variation: StringName = button.theme_type_variation
	var danger := variation == &"FlatModalDangerButton" or variation == &"FlatExitButton"
	var tint := ICON_RESET_DANGER if danger else ICON_NEUTRAL_BTN
	configure_button_icon(button, "repeat.svg", tint)


static func wrap_line_edit_with_leading_icon(
	line_edit: LineEdit,
	file_name: String,
	tint: Color = MUTED,
	gutter_width: int = 34
) -> Control:
	embed_line_edit_leading_icon(line_edit, file_name, tint)
	return line_edit


static func embed_line_edit_leading_icon(
	line_edit: LineEdit,
	file_name: String,
	tint: Color = MUTED,
	padding: int = SEARCH_ICON_GUTTER
) -> void:
	if line_edit == null or file_name.strip_edges() == "":
		return
	if line_edit.get_meta("ui_leading_icon_embedded", false):
		return
	_unwrap_line_edit_from_icon_hbox(line_edit)
	line_edit.clip_contents = true
	var icon := make_texture_rect(load_tinted_icon(file_name, tint, raster_size_for_display(16)), 16)
	icon.name = &"LeadingIcon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.z_index = 0
	line_edit.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	icon.offset_left = 11.0
	icon.offset_right = 27.0
	icon.offset_top = -8.0
	icon.offset_bottom = 8.0
	_apply_line_edit_left_padding(line_edit, padding)
	line_edit.set_meta("ui_leading_icon_embedded", true)
	line_edit.set_meta("ui_leading_icon_gutter", padding)


static func _unwrap_line_edit_from_icon_hbox(line_edit: LineEdit) -> void:
	if line_edit == null or not line_edit.get_meta("ui_leading_icon_wrapped", false):
		return
	var parent_node := line_edit.get_parent()
	if parent_node == null or not (parent_node is HBoxContainer):
		return
	var hbox := parent_node as HBoxContainer
	var grandparent := hbox.get_parent()
	if grandparent == null:
		return
	var idx := hbox.get_index()
	var min_size: Vector2 = hbox.custom_minimum_size
	var h_flags_h: Control.SizeFlags = hbox.size_flags_horizontal
	var h_flags_v: Control.SizeFlags = hbox.size_flags_vertical
	hbox.remove_child(line_edit)
	grandparent.remove_child(hbox)
	grandparent.add_child(line_edit)
	grandparent.move_child(line_edit, idx)
	line_edit.custom_minimum_size = min_size
	line_edit.size_flags_horizontal = h_flags_h
	line_edit.size_flags_vertical = h_flags_v
	hbox.queue_free()
	line_edit.remove_meta("ui_leading_icon_wrapped")


static func _apply_line_edit_left_padding(line_edit: LineEdit, padding: int) -> void:
	var variation := line_edit.theme_type_variation if line_edit.theme_type_variation != &"" else &"LineEdit"
	for state in ["normal", "focus", "read_only"]:
		var stylebox := line_edit.get_theme_stylebox(state, variation)
		if stylebox == null:
			stylebox = line_edit.get_theme_stylebox(state, &"LineEdit")
		if stylebox == null:
			continue
		var copy: StyleBox = stylebox.duplicate()
		if copy is StyleBoxFlat:
			(copy as StyleBoxFlat).content_margin_left = maxf((copy as StyleBoxFlat).content_margin_left, float(padding))
		line_edit.add_theme_stylebox_override(state, copy)


static func add_icon_before_label(
	label: Label,
	file_name: String,
	center_row: bool = true,
	tint: Color = ACCENT
) -> void:
	if label == null or file_name.strip_edges() == "":
		return
	if label.get_meta("ui_icon_wrapped", false):
		return
	var parent := label.get_parent()
	if parent == null:
		return
	var idx := label.get_index()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER if center_row else BoxContainer.ALIGNMENT_BEGIN
	if center_row:
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.remove_child(label)
	parent.add_child(row)
	parent.move_child(row, idx)
	var frame := make_icon_frame(file_name, 28, 16, tint)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(frame)
	row.add_child(label)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if not center_row else HORIZONTAL_ALIGNMENT_LEFT
	label.set_meta("ui_icon_wrapped", true)
	label.set_meta("ui_icon_row", row)


static func get_header_row(label: Label) -> Control:
	if label == null:
		return null
	if label.get_meta("ui_icon_wrapped", false):
		var row := label.get_parent()
		if row is HBoxContainer:
			return row
	return label


static func set_header_with_icon_visible(label: Label, on: bool) -> void:
	var header := get_header_row(label)
	if header:
		header.visible = on


static func update_icon_before_label(label: Label, file_name: String, tint: Color = ACCENT) -> void:
	if label == null or file_name.strip_edges() == "":
		return
	if not label.get_meta("ui_icon_wrapped", false):
		add_icon_before_label(label, file_name, false, tint)
		return
	var row := label.get_parent()
	if row == null or not (row is HBoxContainer):
		return
	for child in row.get_children():
		if child is PanelContainer and child.has_meta("ui_icon_file"):
			child.set_meta("ui_icon_file", file_name)
			child.set_meta("ui_icon_tint", tint)
			set_frame_tint(child as PanelContainer, tint, false)
			break


static func _resolve_path(file_name: String) -> String:
	if file_name.begins_with("res://"):
		return file_name
	if file_name.contains("/"):
		return ICONS_DIR + file_name
	return ICONS_DIR + file_name


static func _frame_bg(tint: Color, selected: bool) -> Color:
	# Selected discs need a stronger fill — 0.14 vs 0.24 was hard to read on dark cards.
	var alpha := 0.42 if selected else 0.10
	return Color(tint.r, tint.g, tint.b, alpha)


static func _load_svg_source(file_name: String) -> String:
	if _svg_source_cache.has(file_name):
		return _svg_source_cache[file_name]
	var path := _resolve_path(file_name)
	var src := ""
	if FileAccess.file_exists(path):
		src = FileAccess.get_file_as_string(path)
	_svg_source_cache[file_name] = src
	return src


static func _rasterize_svg(file_name: String, pixel_size: int) -> Image:
	var src := _load_svg_source(file_name)
	if src.strip_edges() == "":
		return null
	var scale := maxf(1.0, float(pixel_size) / _SVG_NATIVE_SIZE)
	var img := Image.new()
	var err := img.load_svg_from_string(src, scale)
	if err != OK or img.is_empty():
		return null
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img


static func _ensure_icon_resolution(image: Image, min_pixel_size: int) -> Image:
	if image == null or image.is_empty() or min_pixel_size <= 0:
		return image
	var max_dim := maxi(image.get_width(), image.get_height())
	if max_dim >= min_pixel_size:
		return image
	var scale := float(min_pixel_size) / float(max_dim)
	var out := image.duplicate()
	out.resize(
		maxi(1, int(round(float(image.get_width()) * scale))),
		maxi(1, int(round(float(image.get_height()) * scale))),
		Image.INTERPOLATE_LANCZOS
	)
	return out


static func _tint_image(src: Image, color: Color) -> Image:
	var out := src.duplicate()
	if out.get_format() != Image.FORMAT_RGBA8:
		out.convert(Image.FORMAT_RGBA8)
	for y in range(out.get_height()):
		for x in range(out.get_width()):
			var pixel: Color = out.get_pixel(x, y)
			if pixel.a <= 0.001:
				continue
			out.set_pixel(x, y, Color(color.r, color.g, color.b, pixel.a * color.a))
	return out
