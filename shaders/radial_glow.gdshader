shader_type canvas_item;

uniform float glow_strength : hint_range(0, 2) = 0.8;
uniform float glow_size : hint_range(0, 1) = 0.6;
uniform vec4 glow_color : source_color = vec4(0.3, 0.6, 1.0, 0.2);

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(UV, center);
	float alpha = smoothstep(glow_size, 0.0, dist) * glow_strength;
	COLOR = vec4(glow_color.rgb, glow_color.a * alpha);
}