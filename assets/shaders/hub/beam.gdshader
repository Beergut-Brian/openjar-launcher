// Light pouring out of an open jar: additive, fades with height and at the silhouette.
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled, fog_disabled;

uniform vec3 tint : source_color = vec3(1.0, 0.9, 0.6);
uniform float strength = 0.0;

void fragment() {
	float edge = pow(abs(dot(NORMAL, VIEW)), 1.5);
	float up = pow(1.0 - UV.y, 0.0) * smoothstep(0.0, 0.85, UV.y);   // UV.y = 0 at the top of a cylinder
	float shimmer = 0.85 + 0.15 * sin(UV.x * 60.0 + TIME * 2.0);
	ALBEDO = tint * edge * up * shimmer * strength;
}
