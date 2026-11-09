// Profile picker: the happy face shows only on the highlighted face. profile_picker.gd dims the
// other face with modulate alpha 0.55, so the face's own modulate alpha drives the swap.
shader_type canvas_item;

varying float mod_alpha;

void vertex() {
	mod_alpha = COLOR.a;
}

void fragment() {
	vec4 c = COLOR;
	c.a *= smoothstep(0.8, 0.95, mod_alpha);
	COLOR = c;
}
