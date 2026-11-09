// The sea of clouds under the island: slow rolling noise, pink where the sun grazes it.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec3 light : source_color = vec3(1.0, 0.82, 0.76);
uniform vec3 shade : source_color = vec3(0.45, 0.30, 0.66);
uniform vec3 far_color : source_color = vec3(1.0, 0.66, 0.45);
varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5; float v = 0.0;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p = p * 2.03 + 7.1; a *= 0.5; }
	return v;
}

void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 p = wpos.xz * 0.022 + vec2(TIME * 0.012, TIME * 0.004);
	float n = fbm(p);
	float puff = smoothstep(0.36, 0.66, n);
	vec3 c = mix(shade, light, puff);
	float far = smoothstep(40.0, 220.0, length(wpos.xz));
	ALBEDO = mix(c, far_color, far);
}
