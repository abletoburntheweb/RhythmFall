# logic/ui/ui_rounded_clip.gd
extends RefCounted
class_name UiRoundedClip

## Rounded StyleBox frames do not mask children: content fills the outer rect and
## paints over the border's inner curve. Fix:
## 1) clip_to_frame — StyleBox alpha clip only (never clip_contents; that kills border AA)
## 2) apply_to_canvas_item — soft-mask TextureRect corners
## 3) ensure_border_on_top — inset content under the border; optional overlay when safe

const _CLIP_SHADER_PATH := "res://shaders/rounded_rect_clip.gdshader"
const _FALLBACK_SHADER_PATH := "res://shaders/achievement_card.gdshader"
const _META_SIZE_BOUND := &"ui_rounded_clip_size_bound"
const _META_RADIUS := &"ui_rounded_clip_radius"
const _META_BORDER_OVERLAY := &"ui_rounded_border_overlay"

static var _clip_shader: Shader = null


static func _get_clip_shader() -> Shader:
	if _clip_shader != null:
		return _clip_shader
	if ResourceLoader.exists(_CLIP_SHADER_PATH):
		_clip_shader = load(_CLIP_SHADER_PATH) as Shader
	if _clip_shader == null and ResourceLoader.exists(_FALLBACK_SHADER_PATH):
		_clip_shader = load(_FALLBACK_SHADER_PATH) as Shader
	return _clip_shader


static func clip_to_frame(frame: CanvasItem) -> void:
	if frame == null:
		return
	# clip_contents is a hard rect clip — it chops StyleBoxFlat corner AA.
	if frame is Control:
		(frame as Control).clip_contents = false
	frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW


static func apply_to_canvas_item(item: CanvasItem, radius_px: float = 10.0) -> void:
	if item == null:
		return
	var shader := _get_clip_shader()
	if shader == null:
		return
	var mat := item.material as ShaderMaterial
	if mat == null or mat.shader != shader:
		mat = ShaderMaterial.new()
		mat.shader = shader
		item.material = mat
	mat.set_shader_parameter("corner_radius_px", maxf(0.0, radius_px))
	item.set_meta(_META_RADIUS, radius_px)
	if item is Control:
		var ctrl := item as Control
		_sync_rect_size(mat, ctrl.size)
		if not ctrl.get_meta(_META_SIZE_BOUND, false):
			ctrl.set_meta(_META_SIZE_BOUND, true)
			ctrl.resized.connect(_on_clipped_resized.bind(ctrl))
		# Size is often zero during _ready — sync after layout.
		_on_clipped_resized.call_deferred(ctrl)


static func ensure_border_on_top(frame: Control) -> void:
	## Keep the rounded border above square media without breaking container layout.
	if frame == null:
		return
	var src := _read_flat_style(frame)
	if src == null:
		return
	var border_w := maxi(
		src.border_width_left,
		maxi(src.border_width_top, maxi(src.border_width_right, src.border_width_bottom))
	)
	if border_w <= 0:
		return
	# Always inset content so the StyleBox stroke is not covered by children.
	_inset_content_for_border(frame, src, border_w)
	# Choose a host for the border overlay without breaking layout:
	# - Panel: free children → overlay on the frame itself
	# - PanelContainer: nest only into a bare Control; never into Box/Margin/
	#   AspectRatio/TextureRect (those broke covers / added extra slots)
	var host: Control = frame
	if frame is PanelContainer and frame.get_child_count() > 0:
		var first := frame.get_child(0) as Control
		if first != null and first.name != "UiRoundedBorderOverlay":
			if _is_layout_container(first) or first is TextureRect or first is VideoStreamPlayer:
				_remove_stale_overlay(first)
				_remove_stale_overlay(frame)
				return
			host = first
	var overlay := host.get_node_or_null("UiRoundedBorderOverlay") as Panel
	if overlay == null and host != frame:
		overlay = frame.get_node_or_null("UiRoundedBorderOverlay") as Panel
	if overlay == null:
		overlay = Panel.new()
		overlay.name = "UiRoundedBorderOverlay"
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay.offset_left = 0.0
		overlay.offset_top = 0.0
		overlay.offset_right = 0.0
		overlay.offset_bottom = 0.0
		overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
		overlay.grow_vertical = Control.GROW_DIRECTION_BOTH
		host.add_child(overlay)
	var border_only := StyleBoxFlat.new()
	border_only.draw_center = false
	border_only.bg_color = Color(0, 0, 0, 0)
	border_only.border_color = src.border_color
	border_only.border_width_left = src.border_width_left
	border_only.border_width_top = src.border_width_top
	border_only.border_width_right = src.border_width_right
	border_only.border_width_bottom = src.border_width_bottom
	border_only.corner_radius_top_left = src.corner_radius_top_left
	border_only.corner_radius_top_right = src.corner_radius_top_right
	border_only.corner_radius_bottom_right = src.corner_radius_bottom_right
	border_only.corner_radius_bottom_left = src.corner_radius_bottom_left
	border_only.corner_detail = maxi(12, src.corner_detail)
	border_only.shadow_size = 0
	overlay.add_theme_stylebox_override("panel", border_only)
	if overlay.get_parent() == host:
		host.move_child(overlay, host.get_child_count() - 1)
	frame.set_meta(_META_BORDER_OVERLAY, true)


static func apply_cover(frame: Control, cover: CanvasItem, radius_px: float = 10.0) -> void:
	clip_to_frame(frame)
	var inner_radius := radius_px
	var src := _read_flat_style(frame)
	var bw := 0.0
	if src != null:
		bw = float(
			maxi(
				src.border_width_left,
				maxi(src.border_width_top, maxi(src.border_width_right, src.border_width_bottom))
			)
		)
		inner_radius = maxf(0.0, radius_px - bw)
		_inset_content_for_border(frame, src, maxi(1, int(bw)))
	# Drop any overlay previously nested into the cover TextureRect (broke layout).
	if cover is Node:
		_remove_stale_overlay(cover as Node)
	_remove_stale_overlay(frame)
	apply_to_canvas_item(cover, inner_radius)


static func _is_layout_container(node: Control) -> bool:
	return (
		node is BoxContainer
		or node is MarginContainer
		or node is GridContainer
		or node is FlowContainer
		or node is AspectRatioContainer
		or node is ScrollContainer
		or node is SplitContainer
		or node is TabContainer
		or node is PanelContainer
	)


static func _inset_content_for_border(frame: Control, src: StyleBoxFlat, border_w: int) -> void:
	if frame == null or src == null or border_w <= 0:
		return
	var inset := float(border_w)
	var needs := (
		src.content_margin_left < inset
		or src.content_margin_right < inset
		or src.content_margin_top < inset
		or src.content_margin_bottom < inset
	)
	if not needs:
		return
	var box := src.duplicate() as StyleBoxFlat
	box.content_margin_left = maxf(box.content_margin_left, inset)
	box.content_margin_right = maxf(box.content_margin_right, inset)
	box.content_margin_top = maxf(box.content_margin_top, inset)
	box.content_margin_bottom = maxf(box.content_margin_bottom, inset)
	if frame is PanelContainer or frame is Panel:
		frame.add_theme_stylebox_override("panel", box)


static func _remove_stale_overlay(host: Node) -> void:
	if host == null:
		return
	var overlay := host.get_node_or_null("UiRoundedBorderOverlay")
	if overlay != null:
		host.remove_child(overlay)
		overlay.queue_free()


static func _read_flat_style(frame: Control) -> StyleBoxFlat:
	if frame == null:
		return null
	var style: StyleBox = null
	if frame is PanelContainer or frame is Panel:
		style = frame.get_theme_stylebox("panel")
	if style == null:
		style = frame.get_theme_stylebox("panel", "PanelContainer")
	if style is StyleBoxFlat:
		return style as StyleBoxFlat
	return null


static func _on_clipped_resized(ctrl: Control) -> void:
	if ctrl == null or not is_instance_valid(ctrl):
		return
	var mat := ctrl.material as ShaderMaterial
	var shader := _get_clip_shader()
	if mat == null or shader == null or mat.shader != shader:
		return
	_sync_rect_size(mat, ctrl.size)


static func _sync_rect_size(mat: ShaderMaterial, size: Vector2) -> void:
	if mat == null:
		return
	var px := Vector2(maxf(1.0, size.x), maxf(1.0, size.y))
	if mat.shader != null and str(mat.shader.resource_path).ends_with("rounded_rect_clip.gdshader"):
		mat.set_shader_parameter("rect_size", px)
