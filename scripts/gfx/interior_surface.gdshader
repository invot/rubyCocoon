shader_type spatial;
render_mode cull_disabled;

// Low-frequency, antialiased finishes: no enlarged pixel textures or per-frame noise.
uniform int finish = 0; // oak, carpet, tile, stone, diner checker, area rug
uniform vec4 base_colour : source_color = vec4(0.64, 0.44, 0.28, 1.0);
uniform vec4 accent_colour : source_color = vec4(0.75, 0.58, 0.39, 1.0);
uniform vec2 rug_size = vec2(3.0, 2.0);

float line_at(float coordinate, float width) {
	float distance_to_line = min(fract(coordinate), 1.0 - fract(coordinate));
	return 1.0 - smoothstep(width, width + max(fwidth(coordinate), 0.0005), distance_to_line);
}

void fragment() {
	vec3 colour = base_colour.rgb;
	if (finish == 0) {
		vec2 board = vec2(UV.x / 0.45, UV.y / 2.8);
		float row = floor(board.x);
		board.y += mod(row, 3.0) / 3.0;
		float tone = 0.5 + 0.5 * sin(row * 2.37);
		colour = mix(base_colour.rgb, accent_colour.rgb, tone * 0.45);
		colour *= 1.0 + 0.018 * sin(UV.y * 6.0 + sin(UV.x * 8.0));
		float seam = max(line_at(board.x, 0.007), line_at(board.y, 0.0025));
		colour = mix(colour, base_colour.rgb * 0.75, seam * 0.55);
	} else if (finish == 1) {
		colour *= 1.0 + 0.008 * sin(UV.x * 7.0) * sin(UV.y * 7.0);
	} else if (finish == 2 || finish == 3) {
		vec2 tiles = UV / (finish == 2 ? vec2(1.2) : vec2(1.8, 1.2));
		float seam = max(line_at(tiles.x, 0.006), line_at(tiles.y, 0.006));
		colour = mix(colour, accent_colour.rgb, seam);
	} else if (finish == 4) {
		float checker = mod(floor(UV.x) + floor(UV.y), 2.0);
		colour = mix(base_colour.rgb, accent_colour.rgb, checker);
	} else if (finish == 5) {
		// Distances are in world units, so every rug has the same broad, tidy binding.
		vec2 inset = min(UV, vec2(1.0) - UV) * rug_size;
		float edge = min(inset.x, inset.y);
		float aa = max(fwidth(edge), 0.001);
		float border = 1.0 - smoothstep(0.13, 0.13 + aa, edge);
		float piping = smoothstep(0.20 - aa, 0.20, edge) * (1.0 - smoothstep(0.23, 0.23 + aa, edge));
		colour = mix(base_colour.rgb, accent_colour.rgb, border);
		colour = mix(colour, mix(accent_colour.rgb, vec3(0.9, 0.84, 0.72), 0.65), piping * 0.65);
	}
	ALBEDO = colour * COLOR.rgb;
	ROUGHNESS = 0.95;
}
