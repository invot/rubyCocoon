shader_type spatial;
render_mode cull_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 paint : source_color = vec4(0.9, 0.7, 0.75, 1.0);
void fragment() {
	vec4 sampled = texture(atlas, UV);
	// Cut only the source's leaf/chilli cards; plaster, timber and painted windows remain closed.
	if (sampled.a < 0.5) { discard; }
	vec3 original = sampled.rgb;
	bool region = (UV.x > 0.625 && UV.x < 0.866 && UV.y > 0.28 && UV.y < 0.855)
		|| (UV.x < 0.23 && UV.y > 0.68 && UV.y < 0.96);
	// Preserve the source's blue painted windows and brown timber within the plaster islands.
	float neutral = smoothstep(0.08, 0.22, min(original.r, min(original.g, original.b)));
	float blue = smoothstep(0.02, 0.12, original.b - original.r);
	float mask = region ? neutral * (1.0 - blue) : 0.0;
	float shade = clamp(sqrt(dot(original, vec3(0.3, 0.59, 0.11))) / 0.82, 0.62, 1.12);
	ALBEDO = mix(original, paint.rgb * shade, mask);
	ROUGHNESS = 0.95;
}
