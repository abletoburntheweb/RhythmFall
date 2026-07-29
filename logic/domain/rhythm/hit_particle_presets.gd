# logic/utils/hit_particle_presets.gd
extends RefCounted
class_name HitParticlePresets

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
	p.scale_amount_min = float(cfg.get("scale_min", DEFAULT_PRESET["scale_min"]))
	p.scale_amount_max = float(cfg.get("scale_max", DEFAULT_PRESET["scale_max"]))
	p.damping_min = float(cfg.get("damping_min", DEFAULT_PRESET["damping_min"]))
	p.damping_max = float(cfg.get("damping_max", DEFAULT_PRESET["damping_max"]))
	var col := base_color
	var lerp_amt := clampf(float(cfg.get("perfect_white_lerp", DEFAULT_PRESET["perfect_white_lerp"])), 0.0, 1.0)
	if perfect:
		col = base_color.lerp(Color.WHITE, lerp_amt)
	p.color = col
	p.position = position
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


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
