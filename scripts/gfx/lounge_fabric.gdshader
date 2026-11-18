shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 fabric : source_color = vec4(1.0);
void fragment() {
	vec3 painted = texture(albedo_tex, UV).rgb;
	float shade = max(painted.r, max(painted.g, painted.b));
	ALBEDO = fabric.rgb * shade;
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
}
