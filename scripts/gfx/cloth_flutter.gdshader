shader_type spatial;
// Banners and pennants stirring in the wind (valkoog_pyramid.gd): cloth in its vertex colour on the soft fabric finish,
// each vertex pushed along its normal by a couple of slow waves. UV2.x is how freely a vertex moves (0 where the cloth is
// held: a pole, a hanging rod; 1 at its free edge), UV2.y a phase of its own, so no two flags move together.
// Cheap: no textures beyond the fabric, no lighting tricks; drawn from both sides.
render_mode cull_disabled, diffuse_burley, specular_disabled;

uniform sampler2D cloth : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float speed = 2.2;
uniform float amount = 0.09;
// one over the fabric's mean brightness, so the cloth shows its colour as authored (surface_finish.gd mean)
uniform float level = 1.0;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) / vec3(1.055), vec3(2.4)), c / vec3(12.92), lessThan(c, vec3(0.04045)));
}

void vertex() {
	float w = UV2.x;
	float t = TIME * speed + UV2.y + VERTEX.x * 1.9 + VERTEX.y * 1.1 + VERTEX.z * 1.4;
	float wave = sin(t) * 0.65 + sin(t * 2.3 + 1.3) * 0.35;
	VERTEX += NORMAL * wave * amount * w;
	VERTEX.y += sin(t * 1.4 + 0.7) * amount * 0.2 * w;
}

void fragment() {
	// (its back lit as a back, not as its front)
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	vec3 tex = texture(cloth, UV).rgb;
	ALBEDO = srgb_to_linear(COLOR.rgb) * tex * level;
	ROUGHNESS = 0.92;
}
