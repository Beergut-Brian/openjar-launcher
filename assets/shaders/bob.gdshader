// Background floaters: bob up and down with a little squash and stretch. Each node's position
// offsets the phase, so a row of them never moves in step. No script needed.
shader_type canvas_item;

uniform float amp = 12.0;
uniform float speed = 1.4;
uniform float squash = 0.06;

void vertex() {
	float ph = MODEL_MATRIX[3].x * 0.011 + MODEL_MATRIX[3].y * 0.007;
	float s = sin(TIME * speed + ph);
	VERTEX *= vec2(1.0 + squash * s, 1.0 - squash * s);
	VERTEX.y += s * amp;
}
