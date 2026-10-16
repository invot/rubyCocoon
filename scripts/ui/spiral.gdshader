shader_type canvas_item;
// A pixelated spiral wipe: three arms wind out from the centre and thicken until the screen is solid colour.
uniform vec4 color : source_color = vec4(0.25, 0.75, 0.35, 1.0);
uniform float progress = 0.0;
uniform float fade = 1.0;
uniform float aspect = 1.7778;

void fragment() {
	// chunky 6-pixel blocks to match the pixel-art look
	vec2 px = floor(FRAGCOORD.xy / 6.0) * 6.0;
	vec2 uv = px * SCREEN_PIXEL_SIZE;
	vec2 p = (uv - 0.5) * vec2(aspect, 1.0);
	float r = length(p) / (0.5 * length(vec2(aspect, 1.0)));
	float a = atan(p.y, p.x) / 6.2831853 + 0.5;
	float arm = fract(a * 3.0 + r * 1.8 - progress * 2.5);
	float width = clamp(progress * 1.25, 0.0, 1.0);
	float reach = progress * 1.6;
	float on = step(arm, width) * step(r, reach);
	if (progress >= 0.999) {
		on = 1.0;
	}
	// a darker edge along each arm
	float edge = step(width - 0.06, arm) * step(arm, width) * step(progress, 0.98);
	vec3 col = mix(color.rgb, color.rgb * 0.55, edge);
	COLOR = vec4(col, on * fade * color.a);
}
