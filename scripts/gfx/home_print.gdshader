shader_type spatial;
// A framed print's canvas (runbook 037a): one of the user's SVG prints from art_masks.png, recoloured.
// colour = slot0 x paper + R x slot1 + G x slot2 + B x slot3, where paper = 1 - R - G - B. The piece's canvas UVs
// point at its default print (src); they are moved onto the chosen print's crop (dst). Never smooth the masks.
render_mode cull_back;

uniform sampler2D masks : filter_linear_mipmap, repeat_disable;
uniform vec4 src = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 dst = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec3 slot0 : source_color = vec3(1.0);
uniform vec3 slot1 : source_color = vec3(0.8);
uniform vec3 slot2 : source_color = vec3(0.5);
uniform vec3 slot3 : source_color = vec3(0.2);

void fragment() {
	vec2 t = (UV - src.xy) / max(src.zw - src.xy, vec2(1e-5));
	vec2 uv = dst.xy + t * (dst.zw - dst.xy);
	vec3 m = clamp(texture(masks, uv).rgb, 0.0, 1.0);
	float paper = clamp(1.0 - m.r - m.g - m.b, 0.0, 1.0);
	ALBEDO = slot0 * paper + slot1 * m.r + slot2 * m.g + slot3 * m.b;
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
}
