// Island top: mown grass rings, a warm stone plaza with a ring mosaic, a path out to the jars.
shader_type spatial;

uniform vec3 grass_a : source_color = vec3(0.30, 0.66, 0.30);
uniform vec3 grass_b : source_color = vec3(0.36, 0.74, 0.33);
uniform vec3 stone_a : source_color = vec3(0.93, 0.80, 0.66);
uniform vec3 stone_b : source_color = vec3(0.82, 0.66, 0.60);
uniform vec3 inlay : source_color = vec3(0.33, 0.78, 0.86);
uniform float plaza_radius = 7.4;
varying vec3 wpos;

void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	float r = length(wpos.xz);
	float a = atan(wpos.x, -wpos.z);
	vec3 grass = mix(grass_a, grass_b, step(0.5, fract(r * 0.45)));
	float tiles = step(0.5, fract(a * 12.0 / 6.28318 + floor(r / 1.15) * 0.5));
	vec3 stone = mix(stone_a, stone_b, tiles * 0.55);
	stone = mix(stone, stone_b * 0.82, smoothstep(0.04, 0.0, abs(fract(r / 1.15) - 0.5) - 0.46));
	// the Open Jar ring in the middle: two bright bands and a dot
	float ring = smoothstep(0.12, 0.08, abs(r - 2.3)) + smoothstep(0.09, 0.05, abs(r - 1.75)) + smoothstep(0.55, 0.5, r);
	stone = mix(stone, inlay, clamp(ring, 0.0, 1.0));
	float edge = smoothstep(plaza_radius - 0.05, plaza_radius + 0.05, r);
	vec3 border = mix(stone, stone_b * 0.7, smoothstep(plaza_radius - 0.35, plaza_radius - 0.3, r));
	ALBEDO = mix(border, grass, edge);
	ROUGHNESS = mix(0.86, 0.95, edge);
	EMISSION = inlay * clamp(ring, 0.0, 1.0) * (1.0 - edge) * 0.5;
}
