// Fallback card art for a game with no grid.png. card.gd tints the Placeholder ColorRect with a
// per-game colour; that colour picks one tile of the atlas, so each game keeps the same picture.
// card.gd's empty-slot colour (#55506a) picks the empty-slot tile. Palette lives in the atlas PNG.
shader_type canvas_item;

uniform sampler2D tiles : source_color, filter_linear, repeat_disable;
uniform vec2 grid = vec2(3.0, 2.0);
uniform float variants = 5.0;
uniform vec3 empty_tint = vec3(0.3333, 0.3137, 0.4157);

void fragment() {
	vec3 t = COLOR.rgb;
	float idx = float(variants);
	if (distance(t, empty_tint) > 0.02) {
		vec3 b = floor(t * 255.0 + 0.5);
		idx = mod(b.r + b.g * 2.0 + b.b * 4.0, variants);
	}
	vec2 cell = vec2(mod(idx, grid.x), floor(idx / grid.x));
	vec2 uv = clamp(UV, vec2(0.001), vec2(0.999));
	COLOR = texture(tiles, (cell + uv) / grid);
}
