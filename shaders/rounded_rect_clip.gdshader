shader_type canvas_item;

// Soft-masks a TextureRect / VideoStreamPlayer / ColorRect to a rounded rect.
// rect_size must match the Control's on-screen size (updated from script on resize).
uniform float corner_radius_px : hint_range(0.0, 128.0) = 10.0;
uniform vec2 rect_size = vec2(128.0, 128.0);

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	vec2 size = max(rect_size, vec2(1.0));
	float r = clamp(corner_radius_px, 0.0, min(size.x, size.y) * 0.5);
	vec2 p = UV * size;
	vec2 half_box = size * 0.5;
	vec2 d = abs(p - half_box) - (half_box - vec2(r));
	float dist = length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - r;
	float alpha_mask = 1.0 - smoothstep(-0.75, 0.75, dist);
	col.a *= alpha_mask;
	COLOR = col;
}
