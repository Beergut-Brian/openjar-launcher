// Cloud strip: scrolls slowly sideways (needs texture_repeat on the node) and bobs gently.
shader_type canvas_item;

uniform float speed = 0.006;
uniform float amp = 6.0;

varying vec4 tint;

void vertex() {
	tint = COLOR;
	VERTEX.y += sin(TIME * 0.7) * amp;
}

void fragment() {
	COLOR = texture(TEXTURE, UV + vec2(TIME * speed, 0.0)) * tint;
}
