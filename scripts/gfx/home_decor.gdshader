shader_type spatial;
// The home decor kit's atlas surface (runbook 037a): atlas x mix(1, tint, mask) per vertex-colour channel
// (R fabric, G ceramic/accent, B wood, A trim paint). One material per room scheme (home_decor.gd), so it needs
// no per-instance uniforms and runs the same on Forward+, Mobile and Compatibility. The lamp shade's inside and
// the bulb cells glow faintly; they add no light.
render_mode cull_back;

uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 fabric : source_color = vec3(0.88, 0.53, 0.42);
uniform vec3 ceramic : source_color = vec3(0.31, 0.56, 0.54);
uniform vec3 wood : source_color = vec3(0.75, 0.54, 0.33);
uniform vec3 trim : source_color = vec3(0.97, 0.95, 0.91);
// atlas cells that glow: x0, y0, x1, y1
uniform vec4 glow_a = vec4(0.0059, 0.5059, 0.1191, 0.6191);
uniform vec4 glow_b = vec4(0.8809, 0.5059, 0.9941, 0.6191);
uniform float glow = 0.35;

bool inside(vec2 uv, vec4 r) {
	return uv.x >= r.x && uv.x <= r.z && uv.y >= r.y && uv.y <= r.w;
}

void fragment() {
	vec3 c = texture(atlas, UV).rgb;
	vec4 m = clamp(COLOR, 0.0, 1.0);
	c *= mix(vec3(1.0), fabric, m.r);
	c *= mix(vec3(1.0), ceramic, m.g);
	c *= mix(vec3(1.0), wood, m.b);
	c *= mix(vec3(1.0), trim, m.a);
	ALBEDO = c;
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	if (inside(UV, glow_a) || inside(UV, glow_b)) {
		EMISSION = c * glow;
	}
}
