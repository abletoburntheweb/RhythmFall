shader_type canvas_item;

// Soft-masks canvas _draw() output (uses COLOR, not TEXTURE).
// Top corners only — play-mode hero sits under a rounded card frame.
uniform float corner_radius_px : hint_range(0.0, 128.0) = 10.0;
uniform vec2 rect_size = vec2(128.0, 128.0);
uniform float mask_top : hint_range(0.0, 1.0) = 1.0;
uniform float mask_bottom : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 col = COLOR;
	vec2 size = max(rect_size, vec2(1.0));
	float r = clamp(corner_radius_px, 0.0, min(size.x, size.y) * 0.5);
	vec2 p = UV * size;
	float alpha_mask = 1.0;
	if (mask_top > 0.5) {
		if (p.x < r && p.y < r) {
			float d = length(p - vec2(r, r));
			alpha_mask = min(alpha_mask, 1.0 - smoothstep(r - 0.75, r + 0.75, d));
		}
		if (p.x > size.x - r && p.y < r) {
			float d = length(p - vec2(size.x - r, r));
			alpha_mask = min(alpha_mask, 1.0 - smoothstep(r - 0.75, r + 0.75, d));
		}
	}
	if (mask_bottom > 0.5) {
		if (p.x < r && p.y > size.y - r) {
			float d = length(p - vec2(r, size.y - r));
			alpha_mask = min(alpha_mask, 1.0 - smoothstep(r - 0.75, r + 0.75, d));
		}
		if (p.x > size.x - r && p.y > size.y - r) {
			float d = length(p - vec2(size.x - r, size.y - r));
			alpha_mask = min(alpha_mask, 1.0 - smoothstep(r - 0.75, r + 0.75, d));
		}
	}
	col.a *= alpha_mask;
	COLOR = col;
}
