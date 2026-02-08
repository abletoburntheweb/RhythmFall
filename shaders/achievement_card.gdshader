shader_type canvas_item;

uniform float corner_radius_px : hint_range(0.0, 100.0) = 20.0;

void fragment() {
    vec2 tex_size = vec2(textureSize(TEXTURE, 0));
    vec2 uv = UV;
    float r = corner_radius_px / min(tex_size.x, tex_size.y);

    float alpha_mask = 1.0;

    if (uv.x < r && uv.y < r) {
        float d = length(uv - vec2(r, r));
        alpha_mask = step(d, r);
    } else if (uv.x > 1.0 - r && uv.y < r) {
        float d = length(uv - vec2(1.0 - r, r));
        alpha_mask = step(d, r);
    } else if (uv.x < r && uv.y > 1.0 - r) {
        float d = length(uv - vec2(r, 1.0 - r));
        alpha_mask = step(d, r);
    } else if (uv.x > 1.0 - r && uv.y > 1.0 - r) {
        float d = length(uv - vec2(1.0 - r, 1.0 - r));
        alpha_mask = step(d, r);
    }

    vec4 col = texture(TEXTURE, uv);
    col.a *= alpha_mask;
    COLOR = col;
}