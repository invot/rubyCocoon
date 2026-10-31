shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
// The title's night sky, on a big card far behind everything: deep navy overhead, paler and bluer down to the horizon,
// stars twinkling in the upper part. Worked out in screen colours, then made linear. `t`: the time, from the script.
uniform float t = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float y = UV.y;
	vec3 c = mix(vec3(0.02, 0.03, 0.1), vec3(0.06, 0.08, 0.2), smoothstep(0.0, 0.55, y));
	c = mix(c, vec3(0.16, 0.17, 0.32), smoothstep(0.55, 0.9, y));
	// at most one star to a cell, a few of them bright
	vec2 g = UV * vec2(150.0, 64.0);
	vec2 id = floor(g);
	float h = hash(id);
	if (h > 0.85) {
		vec2 at = vec2(hash(id + 3.1), hash(id + 7.7)) * 0.7 + 0.15;
		float b = (h - 0.85) / 0.15;
		float twinkle = 0.6 + 0.4 * sin(t * (1.0 + 2.5 * hash(id + 1.3)) + h * 40.0);
		float star = 1.0 - smoothstep(0.0, 0.07 + 0.12 * b * b, length(fract(g) - at));
		c += vec3(0.95, 0.95, 1.0) * star * (0.35 + 0.65 * b) * twinkle * (1.0 - smoothstep(0.45, 0.8, y));
	}
	ALBEDO = pow(c, vec3(2.2));
}
