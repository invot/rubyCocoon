shader_type spatial;
// The Codex's head (codex_head.gd): each part's colour (vertex colour, tools/import_codex_head.gd) painted with a soft
// light-to-shade gradient across its planar UV, so it is a textured object like the rest of the 3D art.
render_mode diffuse_lambert, specular_schlick_ggx;

uniform sampler2D paint : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float glow = 0.0;

void fragment() {
	vec3 wash = texture(paint, vec2(0.5, clamp(UV.y, 0.0, 1.0))).rgb;
	ALBEDO = COLOR.rgb * wash;
	ROUGHNESS = 0.55;
	SPECULAR = 0.35;
	EMISSION = COLOR.rgb * glow;
}
