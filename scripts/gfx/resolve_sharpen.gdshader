// The 3D view enlarged to the screen (main.gd `screen`): bilinear, then a mild contrast-adaptive sharpen at the
// source's texel scale (step 010b). The result is clamped to its neighbours' range, so edges firm up without halos
// or ringing. Forward+ and Mobile only; Compatibility (desktop OpenGL, the web) keeps plain bilinear.
shader_type canvas_item;

uniform float sharpness : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec3 c = texture(TEXTURE, UV).rgb;
	vec3 n = texture(TEXTURE, UV + vec2(0.0, -px.y)).rgb;
	vec3 s = texture(TEXTURE, UV + vec2(0.0, px.y)).rgb;
	vec3 e = texture(TEXTURE, UV + vec2(px.x, 0.0)).rgb;
	vec3 w = texture(TEXTURE, UV + vec2(-px.x, 0.0)).rgb;
	vec3 lo = min(c, min(min(n, s), min(e, w)));
	vec3 hi = max(c, max(max(n, s), max(e, w)));
	vec3 sharp = c + sharpness * (4.0 * c - n - s - e - w) * 0.25;
	COLOR = vec4(clamp(sharp, lo, hi), 1.0);
}
