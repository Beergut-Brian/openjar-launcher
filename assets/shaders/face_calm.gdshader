// Profile picker, calm face. profile_picker.gd fades the face that is not highlighted with modulate
// alpha 0.55; on the busy sky that reads as a ghost, so this keeps the face solid and dims it
// towards the palette slate instead. Highlighted (alpha 1) it draws unchanged.
shader_type canvas_item;

uniform vec4 dim_color : source_color = vec4(0.557, 0.612, 0.753, 1.0);
uniform float dim_amount = 0.5;

varying float mod_alpha;

void vertex() {
	mod_alpha = COLOR.a;
}

void fragment() {
	vec4 c = COLOR;
	float dim = 1.0 - smoothstep(0.8, 0.95, mod_alpha);
	c.a = clamp(c.a / max(mod_alpha, 0.001), 0.0, 1.0);
	c.rgb = mix(c.rgb, c.rgb * dim_color.rgb, dim * dim_amount * 2.0);
	COLOR = c;
}
