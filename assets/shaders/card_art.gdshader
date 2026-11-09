// Real grid art (600x900): rounded corners and the house ink edge, matching the fallback tiles.
shader_type canvas_item;

uniform vec4 ink : source_color = vec4(0.04, 0.04, 0.08, 1.0);
uniform vec2 size = vec2(600.0, 900.0);
uniform float radius = 48.0;
uniform float edge = 18.0;

float sd_round_rect(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec4 c = COLOR;   // already texture * modulate
	float d = sd_round_rect((UV - 0.5) * size, size * 0.5, radius);
	float aa = max(fwidth(d), 0.5);
	c.rgb = mix(c.rgb, ink.rgb, smoothstep(-edge - aa, -edge + aa, d));
	c.a *= 1.0 - smoothstep(-aa, aa, d);
	COLOR = c;
}
