shader_type spatial;
// One wood for a whole room (room_builder.gd _one_wood): a piece's own texture, with its wood tones (warm browns,
// tans and oranges) recoloured to `wood` and shaded by how light or dark they were against the texture's usual wood
// (`ref`); every other colour (paint, metal, cloth) is kept.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform vec3 wood : source_color = vec3(0.6, 0.4, 0.25);
uniform float ref = 0.3;
uniform vec2 uv_scale = vec2(1.0);

vec3 to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-5)), d / (q.x + 1e-5), q.x);
}

float woodness(vec3 c) {
	vec3 h = to_hsv(c);
	return smoothstep(0.005, 0.03, h.x) * (1.0 - smoothstep(0.12, 0.16, h.x)) * smoothstep(0.25, 0.4, h.y)
		* smoothstep(0.01, 0.03, h.z);
}

void fragment() {
	vec3 t = texture(albedo_tex, UV * uv_scale).rgb;
	float l = dot(t, vec3(0.2126, 0.7152, 0.0722));
	ALBEDO = mix(t, wood * clamp(l / ref, 0.6, 1.35), woodness(t));
	ROUGHNESS = 0.85;
}
