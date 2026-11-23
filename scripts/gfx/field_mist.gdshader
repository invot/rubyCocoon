shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D coverage : filter_linear_mipmap;
uniform sampler2D clouds : repeat_enable, filter_linear_mipmap;
uniform float layer = 0.0;
uniform float opacity = 1.0;
// the faint mist kept over the whole plane however thin its coverage (0: none, the well's caves fade it out entirely)
uniform float fringe_floor = 0.24;
varying vec3 world_at;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(world.x * 1.3 + TIME * 0.25 + layer) * 0.045
		+ cos(world.z * 1.1 - TIME * 0.2 + layer) * 0.035;
	world_at = world;
}

void fragment() {
	vec2 flow = world_at.xz * 0.065 + vec2(TIME * 0.005, -TIME * 0.003);
	float broad = texture(clouds, flow + layer * 0.17).r;
	float detail = texture(clouds, flow * 2.1 - vec2(TIME * 0.004) + layer * 0.31).r;
	float density = smoothstep(0.15, 0.75, broad * 0.65 + detail * 0.35);
	vec2 drift = (vec2(broad, detail) - 0.5) * 0.035;
	float fringe = smoothstep(0.0, 0.16, UV.x) * smoothstep(0.0, 0.16, 1.0 - UV.x)
		* smoothstep(0.0, 0.16, UV.y) * smoothstep(0.0, 0.16, 1.0 - UV.y);
	float edge = max(smoothstep(0.01, 0.55, texture(coverage, UV + drift).r), fringe * fringe_floor);
	ALBEDO = mix(vec3(0.42, 0.46, 0.51), vec3(0.71, 0.76, 0.78), broad);
	if (OUTPUT_IS_SRGB) {
		ALBEDO = pow(ALBEDO, vec3(0.454545));
	}
	ALPHA = edge * density * (0.34 - layer * 0.055) * opacity;
}
