# logic/domain/rhythm/hit_particle_presets.gd
extends RefCounted
class_name HitParticlePresets

const PerfTrace = preload("res://logic/utils/perf_trace.gd")

# --- Procedural particle textures (lazy, cached once) ---
# No PNG/SVG assets — generated via Image/ImageTexture per DESIGN.
static var _dot_tex: Texture2D = null
static var _spark_tex: Texture2D = null
static var _ring_tex: Texture2D = null
static var _petal_tex: Texture2D = null

enum DebugMode { CURRENT, LEGACY }
static var _debug_mode: DebugMode = DebugMode.CURRENT

static func set_debug_mode(mode: DebugMode) -> void:
	_debug_mode = mode

static func get_debug_mode() -> DebugMode:
	return _debug_mode

static func get_debug_mode_name() -> String:
	return "LEGACY" if _debug_mode == DebugMode.LEGACY else "CURRENT"

const DEFAULT_PRESET := {
	"amount": 18,
	"lifetime": 0.45,
	"spread": 120.0,
	"gravity_y": 700.0,
	"velocity_min": 200.0,
	"velocity_max": 420.0,
	"scale_min": 3.0,
	"scale_max": 6.0,
	"damping_min": 40.0,
	"damping_max": 80.0,
	"perfect_white_lerp": 0.5,
	"preview_color": "#7ad4c8",
}


static func merge_with_defaults(raw: Dictionary) -> Dictionary:
	var out := DEFAULT_PRESET.duplicate(true)
	for key in raw.keys():
		out[key] = raw[key]
	return out


static func preset_from_item(item: Dictionary) -> Dictionary:
	if item.is_empty():
		return DEFAULT_PRESET.duplicate(true)
	var raw: Variant = item.get("particle_preset", {})
	if raw is Dictionary and not raw.is_empty():
		return merge_with_defaults(raw)
	return DEFAULT_PRESET.duplicate(true)


static func find_item_data(item_id: String) -> Dictionary:
	if item_id == "":
		return {}
	var user_path := "user://shop_data.json"
	var res_path := "res://data/shop_data.json"
	var data: Dictionary = JsonUtils.read_json_dict(user_path)
	if data.is_empty():
		data = JsonUtils.read_json_dict(res_path)
	else:
		var bundled := JsonUtils.read_json_dict(res_path)
		if not bundled.is_empty():
			data = CatalogDataSync.merge_shop_items(data, bundled)
	for item in data.get("items", []):
		if item is Dictionary and String(item.get("item_id", "")) == item_id:
			return item
	return {}


static func resolve_active_preset() -> Dictionary:
	var item_id := String(PlayerDataManager.get_active_item("HitParticles"))
	if item_id == "":
		return DEFAULT_PRESET.duplicate(true)
	return preset_from_item(find_item_data(item_id))


static func _get_dot_texture() -> Texture2D:
	var _perf_hit := PerfTrace.begin("perf.gameplay.first_use.hit_particles.texture")
	if _dot_tex != null:
		PerfTrace.end("perf.gameplay.first_use.hit_particles.texture", _perf_hit)
		PerfTrace.record("perf.gameplay.first_use.hit_particles.texture.cache_hit", 1)
		return _dot_tex
	_dot_tex = _create_dot_texture(14)
	PerfTrace.end("perf.gameplay.first_use.hit_particles.texture", _perf_hit)
	PerfTrace.record("perf.gameplay.first_use.hit_particles.texture.cache_miss", 1)
	return _dot_tex


static func _get_spark_texture() -> Texture2D:
	if _spark_tex != null:
		return _spark_tex
	_spark_tex = _create_spark_texture(10)
	return _spark_tex


static func _get_ring_texture() -> Texture2D:
	if _ring_tex != null:
		return _ring_tex
	_ring_tex = _create_ring_texture(32)
	return _ring_tex


static func _get_petal_texture() -> Texture2D:
	if _petal_tex != null:
		return _petal_tex
	_petal_tex = _create_petal_texture(12, 8)
	return _petal_tex


static func _texture_for_variant(variant: String) -> Texture2D:
	match variant.strip_edges().to_lower():
		"spark", "ember":
			return _get_spark_texture()
		"petal":
			return _get_petal_texture()
		"ring", "neon_ring":
			# Burst remains dots; ring visual is secondary layer.
			return _get_dot_texture()
		_:
			return _get_dot_texture()


static func _create_dot_texture(size: int = 14) -> Texture2D:
	# Binary small core: F54C footprint, no broad halo.
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	var max_r := float(size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(center)
			var t := clampf(d / max_r, 0.0, 1.0)
			var a := 0.0
			if t < 0.38:
				a = 1.0
			elif t < 0.52:
				a = clampf((0.52 - t) / 0.14, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(image)


static func _create_spark_texture(size: int = 10) -> Texture2D:
	# Binary diamond small core.
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := float(size) * 0.5
	for y in size:
		for x in size:
			var dx := absf(float(x) + 0.5 - center)
			var dy := absf(float(y) + 0.5 - center)
			var manhattan := (dx + dy) / (float(size) * 0.5)
			var chebyshev := maxf(dx, dy) / (float(size) * 0.5)
			var d := lerpf(manhattan, chebyshev, 0.35)
			var t := clampf(d, 0.0, 1.0)
			var a := 0.0
			if t < 0.38:
				a = 1.0
			elif t < 0.56:
				a = clampf((0.56 - t) / 0.18, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(image)


static func _create_ring_texture(size: int = 32) -> Texture2D:
	# Binary thin ring: hard 1px AA only.
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	var radius := float(size) * 0.38
	var thickness := float(size) * 0.07
	for y in size:
		for x in size:
			var d := Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(center)
			var dist_from_ring := absf(d - radius)
			var a := 0.0
			if dist_from_ring < thickness * 0.45:
				a = 1.0
			elif dist_from_ring < thickness * 0.80:
				a = clampf((thickness * 0.80 - dist_from_ring) / (thickness * 0.35), 0.0, 1.0) * 0.85
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(image)


static func _create_petal_texture(w: int = 12, h: int = 8) -> Texture2D:
	# Binary small ellipse.
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var cx := float(w) * 0.5
	var cy := float(h) * 0.5
	var rx := float(w) * 0.5
	var ry := float(h) * 0.5
	for y in h:
		for x in w:
			var dx := (float(x) + 0.5 - cx) / rx
			var dy := (float(y) + 0.5 - cy) / ry
			var t := sqrt(dx * dx + dy * dy)
			var a := 0.0
			if t < 0.45:
				a = 1.0
			elif t < 0.68:
				a = clampf((0.68 - t) / 0.23, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(image)


const _BASE_TEXELS := 2.75


static func _compensated_scale(preset_scale: float, texture_px: float) -> float:
	# Perceived size like F54C (good), not 1px math: 8/tex gives ~24px vs old 3px but visually balanced.
	return float(preset_scale) * (_BASE_TEXELS / maxf(texture_px, 1.0))


static func _texture_size_for_variant(variant: String) -> float:
	match variant.strip_edges().to_lower():
		"spark", "ember":
			return 10.0
		"petal":
			return 12.0
		_:
			return 14.0


static func spawn(
	parent: Node,
	position: Vector2,
	base_color: Color,
	perfect: bool,
	preset: Dictionary
) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var cfg := merge_with_defaults(preset)
	var variant := String(cfg.get("variant", "default"))
	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = int(cfg.get("amount", DEFAULT_PRESET["amount"]))
	p.lifetime = float(cfg.get("lifetime", DEFAULT_PRESET["lifetime"]))
	p.direction = Vector2(0, -1)
	p.spread = float(cfg.get("spread", DEFAULT_PRESET["spread"]))
	p.gravity = Vector2(0, float(cfg.get("gravity_y", DEFAULT_PRESET["gravity_y"])))
	p.initial_velocity_min = float(cfg.get("velocity_min", DEFAULT_PRESET["velocity_min"]))
	p.initial_velocity_max = float(cfg.get("velocity_max", DEFAULT_PRESET["velocity_max"]))
	# Compensate scale for small textures so footprint stays near old CPU squares (15-30 px²).
	var tex_px := _texture_size_for_variant(variant)
	p.scale_amount_min = _compensated_scale(float(cfg.get("scale_min", DEFAULT_PRESET["scale_min"])), tex_px)
	p.scale_amount_max = _compensated_scale(float(cfg.get("scale_max", DEFAULT_PRESET["scale_max"])), tex_px)
	p.damping_min = float(cfg.get("damping_min", DEFAULT_PRESET["damping_min"]))
	p.damping_max = float(cfg.get("damping_max", DEFAULT_PRESET["damping_max"]))
	var col := base_color
	var lerp_amt := clampf(float(cfg.get("perfect_white_lerp", DEFAULT_PRESET["perfect_white_lerp"])), 0.0, 1.0)
	if perfect:
		col = base_color.lerp(Color.WHITE, lerp_amt)
	p.color = col
	if _debug_mode == DebugMode.LEGACY:
		p.texture = null
		p.scale_amount_min = float(cfg.get("scale_min", DEFAULT_PRESET["scale_min"]))
		p.scale_amount_max = float(cfg.get("scale_max", DEFAULT_PRESET["scale_max"]))
	else:
		p.texture = _texture_for_variant(variant)
		p.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	p.position = position
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	# Secondary ring layer only in CURRENT.
	if _debug_mode == DebugMode.CURRENT:
		var v_lower := variant.strip_edges().to_lower()
		if v_lower in ["ring", "neon_ring"]:
			_spawn_ring_layer(parent, position, col, v_lower == "neon_ring", cfg)


static func _spawn_ring_layer(parent: Node, pos: Vector2, col: Color, is_neon: bool, cfg: Dictionary) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	# Restrained ring: minimal footprint, no bloom. If still too visible, disable call in spawn().
	var root := Node2D.new()
	root.position = pos
	root.z_index = 1
	var sprite := Sprite2D.new()
	sprite.texture = _get_ring_texture()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.centered = true
	var ring_col := col
	if is_neon:
		ring_col = col.lightened(0.12)
		ring_col.a = 0.45
	else:
		ring_col.a = 0.35
	sprite.modulate = ring_col
	sprite.scale = Vector2(0.12, 0.12)
	root.add_child(sprite)
	parent.add_child(root)
	if not root.is_inside_tree():
		return
	# Restrained duration 0.22-0.28s per DESIGN (vs old 0.35-0.5).
	var base_lt := float(cfg.get("lifetime", 0.5))
	var duration := clampf(base_lt * 0.52, 0.22, 0.28)
	var target_scale := Vector2(0.70, 0.70) if is_neon else Vector2(0.55, 0.55)
	var tw := root.create_tween()
	if tw == null:
		var tree := root.get_tree()
		if tree != null:
			var timer := tree.create_timer(duration)
			timer.timeout.connect(func() -> void:
				if is_instance_valid(root):
					root.queue_free()
			, CONNECT_ONE_SHOT)
		else:
			root.queue_free()
		return
	tw.set_parallel(true)
	tw.tween_property(sprite, "scale", target_scale, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.set_parallel(false)
	tw.tween_callback(func() -> void:
		if is_instance_valid(root):
			root.queue_free()
	)


static func preview_color_from_preset(preset: Dictionary) -> Color:
	var cfg := merge_with_defaults(preset)
	var hex := String(cfg.get("preview_color", DEFAULT_PRESET["preview_color"]))
	if hex.is_empty():
		return Color(cfg.get("preview_color", "#7ad4c8"))
	return Color(hex)


static func create_preview_texture(preset: Dictionary, width: int = 240, height: int = 180) -> Texture2D:
	var cfg := merge_with_defaults(preset)
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.06, 0.08, 0.12, 1.0))
	var center := Vector2(width * 0.5, height * 0.62)
	var base_col := preview_color_from_preset(cfg)
	var amount := int(cfg.get("amount", 18))
	var spread := float(cfg.get("spread", 120.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(hash(String(cfg.get("preview_color", ""))) & 0x7fffffff)
	for i in amount:
		var angle_deg := rng.randf_range(-spread * 0.5, spread * 0.5) - 90.0
		var dist := rng.randf_range(18.0, minf(width, height) * 0.38)
		var rad := deg_to_rad(angle_deg)
		var pt := center + Vector2(cos(rad), sin(rad)) * dist
		var px := int(clampf(pt.x, 0.0, float(width - 1)))
		var py := int(clampf(pt.y, 0.0, float(height - 1)))
		var dot := int(rng.randi_range(2, 4))
		for dx in range(-dot, dot + 1):
			for dy in range(-dot, dot + 1):
				var x := px + dx
				var y := py + dy
				if x < 0 or y < 0 or x >= width or y >= height:
					continue
				if Vector2(dx, dy).length() <= float(dot):
					image.set_pixel(x, y, base_col)
	image.set_pixel(int(center.x), int(center.y), base_col.lightened(0.25))
	return ImageTexture.create_from_image(image)
