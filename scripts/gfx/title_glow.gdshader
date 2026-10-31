shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;
// The title's backdrop: near-black, a deep ruby glow round the middle and a hotter core, breathing slowly; darker
// towards the corners. Drawn on a big card far behind everything. `t`: the time, from the script.
uniform float t = 0.0;
uniform vec2 core = vec2(0.5, 0.42);

void fragment() {
	vec2 p = (UV - core) * vec2(1.6, 1.0);
	float r = length(p);
	float breathe = 0.94 + 0.06 * sin(t * 0.8);
	// (worked out in screen colours, then made linear)
	vec3 c = mix(vec3(0.07, 0.02, 0.035), vec3(0.03, 0.01, 0.02), smoothstep(0.0, 1.0, UV.y));
	c += vec3(0.48, 0.05, 0.14) * (1.0 - smoothstep(0.0, 0.62, r)) * breathe;
	c += vec3(0.4, 0.14, 0.08) * pow(1.0 - smoothstep(0.0, 0.26, r), 2.0) * breathe;
	ALBEDO = pow(c, vec3(2.2));
}
