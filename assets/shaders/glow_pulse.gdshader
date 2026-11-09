// Highlight ring on the selected card: a slow, soft pulse.
shader_type canvas_item;

uniform float speed = 4.0;
uniform float depth = 0.25;

void fragment() {
	vec4 c = COLOR;   // already texture * modulate
	c.a *= 1.0 - depth + depth * sin(TIME * speed);
	COLOR = c;
}
