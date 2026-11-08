shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Slow motes drifting up through the light, all animated here so the whole cloud costs one draw call and no script time.
// Each instance's resting position seeds its speed and path.
uniform float size = 0.06;
uniform float strength = 0.5;
uniform float ceiling = 7.0;
varying float fade;

void vertex() {
	vec3 home = MODEL_MATRIX[3].xyz;
	float seed = fract(sin(dot(home, vec3(12.99, 78.23, 37.72))) * 43758.55);
	float t = TIME * (0.06 + seed * 0.08) + seed * 31.0;
	float height = mod(home.y + t, ceiling);
	vec3 world = vec3(home.x + sin(t * 3.1 + seed * 6.3) * 0.45, height, home.z + cos(t * 2.3 + seed * 9.1) * 0.45);
	fade = smoothstep(0.0, 0.8, height) * (1.0 - smoothstep(ceiling - 1.6, ceiling, height));
	fade *= 0.55 + 0.45 * sin(TIME * (0.7 + seed) + seed * 40.0);
	vec4 view = VIEW_MATRIX * vec4(world, 1.0);
	view.xy += VERTEX.xy * size * (0.6 + seed * 0.9);
	POSITION = PROJECTION_MATRIX * view;
}

void fragment() {
	ALBEDO = vec3(1.0, 0.95, 0.85);
	ALPHA = clamp((1.0 - smoothstep(0.0, 0.5, distance(UV, vec2(0.5)))) * fade * strength, 0.0, 1.0);
}
