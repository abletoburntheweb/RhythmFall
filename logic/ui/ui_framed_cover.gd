# logic/ui/ui_framed_cover.gd
extends RefCounted
class_name UiFramedCover

## Framed square media: inner CLIP mask + soft-mask shader + border drawn on top.
## Soft-mask catches TextureRect corners that CLIP alone can miss on nested panels.

const STACK_CLIP_NAME := "CoverClipHost"
const BORDER_OVERLAY_NAME := "CoverBorderOverlay"
const _UiRoundedClip = preload("res://logic/ui/ui_rounded_clip.gd")


static func apply(
	frame: PanelContainer,
	cover: TextureRect,
	radius_px: int = 10,
	border_w: int = 2,
	accent: Color = Color(0.62, 0.86, 0.72, 0.85),
	bg: Color = Color(0.05, 0.06, 0.09, 1.0),
	side_px: float = 0.0
) -> void:
	if frame == null or cover == null:
		return

	var preserved_min := cover.custom_minimum_size
	if side_px > 0.0:
		frame.custom_minimum_size = Vector2(side_px, side_px)
		# Frame size is authoritative; cover expands inside content margins.
		preserved_min = Vector2.ZERO

	frame.clip_contents = false
	frame.clip_children = CanvasItem.CLIP_CHILDREN_DISABLED

	_reparent_cover_out_of_doomed(frame, cover)

	# Inset a hair past the stroke so square media cannot peek past the curve.
	var inset := float(border_w + 1)
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_border_width_all(0)
	box.set_corner_radius_all(radius_px)
	box.corner_detail = 12
	box.content_margin_left = inset
	box.content_margin_top = inset
	box.content_margin_right = inset
	box.content_margin_bottom = inset
	frame.add_theme_stylebox_override("panel", box)

	var clip := _ensure_clip_host(frame, cover)
	var inner_r := maxi(0, radius_px - border_w - 1)
	var clip_box := StyleBoxFlat.new()
	clip_box.bg_color = bg
	clip_box.set_border_width_all(0)
	clip_box.set_corner_radius_all(inner_r)
	clip_box.corner_detail = 12
	clip_box.content_margin_left = 0.0
	clip_box.content_margin_top = 0.0
	clip_box.content_margin_right = 0.0
	clip_box.content_margin_bottom = 0.0
	clip.add_theme_stylebox_override("panel", clip_box)
	clip.clip_contents = false
	clip.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW

	cover.visible = true
	cover.custom_minimum_size = preserved_min
	cover.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cover.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	cover.z_as_relative = true
	cover.z_index = 0
	# Soft-mask by control size (not texture UV) — reliable for any cover resolution.
	_UiRoundedClip.apply_to_canvas_item(cover, float(inner_r))

	_ensure_border_overlay(frame, radius_px, border_w, accent)


static func _reparent_cover_out_of_doomed(frame: PanelContainer, cover: TextureRect) -> void:
	var doomed := ["UiRoundedBorderOverlay", "UiRoundedCoverHost", "CoverAspect"]
	var walk: Node = cover.get_parent()
	var under_doomed := false
	while walk != null and walk != frame:
		if str(walk.name) in doomed:
			under_doomed = true
			break
		walk = walk.get_parent()
	if under_doomed:
		var old_p := cover.get_parent()
		if old_p:
			old_p.remove_child(cover)
		frame.add_child(cover)
	for name in doomed:
		var stale := frame.find_child(name, true, false)
		while stale != null:
			var p := stale.get_parent()
			if p:
				p.remove_child(stale)
			stale.queue_free()
			stale = frame.find_child(name, true, false)


static func _ensure_clip_host(frame: PanelContainer, cover: TextureRect) -> PanelContainer:
	## PanelContainer so the cover's minimum size still drives the outer frame.
	var clip := frame.get_node_or_null(STACK_CLIP_NAME) as PanelContainer
	if clip == null:
		# Replace a legacy Panel clip host if present.
		var legacy := frame.get_node_or_null(STACK_CLIP_NAME)
		if legacy != null:
			var lp := legacy.get_parent()
			if lp:
				lp.remove_child(legacy)
			legacy.queue_free()
		clip = PanelContainer.new()
		clip.name = STACK_CLIP_NAME
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
		frame.add_child(clip)
		frame.move_child(clip, 0)
	if cover.get_parent() != clip:
		var old_p := cover.get_parent()
		if old_p:
			old_p.remove_child(cover)
		clip.add_child(cover)
	# Layout child (not anchors) so min size propagates.
	cover.set_anchors_preset(Control.PRESET_TOP_LEFT)
	cover.anchor_right = 0.0
	cover.anchor_bottom = 0.0
	cover.offset_left = 0.0
	cover.offset_top = 0.0
	cover.offset_right = 0.0
	cover.offset_bottom = 0.0
	return clip


static func _ensure_border_overlay(
	frame: PanelContainer,
	radius_px: int,
	border_w: int,
	accent: Color
) -> void:
	## Second child: ignored for PanelContainer layout, drawn full-rect on top.
	var overlay := frame.get_node_or_null(BORDER_OVERLAY_NAME) as Panel
	if overlay == null:
		overlay = Panel.new()
		overlay.name = BORDER_OVERLAY_NAME
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.offset_left = 0.0
	overlay.offset_top = 0.0
	overlay.offset_right = 0.0
	overlay.offset_bottom = 0.0
	overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	overlay.grow_vertical = Control.GROW_DIRECTION_BOTH
	var border_only := StyleBoxFlat.new()
	border_only.draw_center = false
	border_only.bg_color = Color(0, 0, 0, 0)
	border_only.border_color = accent
	border_only.set_border_width_all(border_w)
	border_only.set_corner_radius_all(radius_px)
	border_only.corner_detail = 12
	overlay.add_theme_stylebox_override("panel", border_only)
	frame.move_child(overlay, frame.get_child_count() - 1)
