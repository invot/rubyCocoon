shader_type spatial;
// Keep the painted atlas shading; neutral light cover faces use slate blue.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
void fragment() {
	vec3 t = texture(albedo_tex, UV).rgb;
	float high = max(t.r, max(t.g, t.b));
	float low = min(t.r, min(t.g, t.b));
	float neutral = (1.0 - smoothstep(0.08, 0.22, high - low)) * smoothstep(0.45, 0.65, high);
	ALBEDO = mix(t, vec3(0.13, 0.31, 0.46) * clamp(high, 0.5, 1.0), neutral);
	ROUGHNESS = 0.9;
	SPECULAR = 0.25;
}
