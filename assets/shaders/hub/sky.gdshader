// Magic-hour sky: indigo zenith, violet, pink, orange horizon, big soft sun, a few stars.
// No TIME, so the radiance map is only built once.
shader_type sky;

uniform vec3 zenith : source_color = vec3(0.05, 0.06, 0.30);
uniform vec3 high : source_color = vec3(0.27, 0.16, 0.62);
uniform vec3 mid : source_color = vec3(0.92, 0.33, 0.55);
uniform vec3 horizon : source_color = vec3(1.0, 0.62, 0.30);
uniform vec3 below : source_color = vec3(0.62, 0.42, 0.66);
uniform vec3 sun_color : source_color = vec3(1.0, 0.74, 0.42);
uniform vec3 sun_dir = vec3(0.38, 0.19, -0.9);   // where the disc is drawn (set by hub.gd)

float hash(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

void sky() {
	float h = EYEDIR.y;
	vec3 c = mix(horizon, mid, smoothstep(0.0, 0.11, h));
	c = mix(c, high, smoothstep(0.07, 0.3, h));
	c = mix(c, zenith, smoothstep(0.26, 0.7, h));
	c = mix(c, below, smoothstep(0.0, -0.25, h));
	float d = max(dot(EYEDIR, normalize(sun_dir)), 0.0);
	c += sun_color * pow(d, 8.0) * 0.2;            // wide warm bloom round the sun
	c += sun_color * pow(d, 90.0) * 0.4;
	c += sun_color * smoothstep(0.9978, 0.9984, d) * 0.85;   // the disc
	// stars: only high up, sparse, soft
	vec3 g = floor(EYEDIR * 90.0);
	float s = hash(g);
	vec3 f = fract(EYEDIR * 90.0) - 0.5;
	float star = step(0.985, s) * smoothstep(0.22, 0.0, length(f));
	c += vec3(1.0, 0.95, 0.85) * star * smoothstep(0.18, 0.5, h) * 2.0;
	COLOR = c;
}
