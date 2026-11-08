shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D mist_texture : filter_linear_mipmap_anisotropic, repeat_enable;
void fragment() {
	vec2 drift = UV * 2.4 + vec2(TIME * 0.009, TIME * -0.006);
	float cloud = texture(mist_texture, drift).r;
	float edge = 1.0 - smoothstep(0.18, 0.70, distance(UV, vec2(0.5)));
	ALBEDO = vec3(0.22, 0.40, 0.46);
	ALPHA = smoothstep(0.2, 0.85, cloud) * edge * 0.075;
}
