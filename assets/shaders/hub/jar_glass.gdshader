// Jar glass: clear in the middle, bright tinted rim, two soft vertical highlights.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, specular_schlick_ggx;

uniform vec3 tint : source_color = vec3(0.6, 0.9, 1.0);
uniform float lit = 0.0;   // 0 resting, 1 a Jarling is looking in

void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	float streak = smoothstep(0.035, 0.0, abs(UV.x - 0.31)) * 0.5 + smoothstep(0.012, 0.0, abs(UV.x - 0.36)) * 0.35;
	streak *= smoothstep(0.05, 0.2, UV.y) * smoothstep(0.95, 0.7, UV.y);
	ALBEDO = mix(tint, vec3(1.0), 0.55);
	ROUGHNESS = 0.06;
	SPECULAR = 0.9;
	EMISSION = tint * f * (0.9 + lit * 1.6) + vec3(1.0) * streak * (0.5 + lit * 0.4);
	ALPHA = clamp(0.07 + f * 0.75 + streak * 0.6, 0.0, 1.0);
}
