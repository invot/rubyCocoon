shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform float power : hint_range(0.0, 1.0) = 0.0;
uniform vec4 light_color : source_color = vec4(0.50, 0.90, 1.0, 1.0);
void fragment() {
	float ends = smoothstep(0.0, 0.12, UV.y) * (1.0 - smoothstep(0.82, 1.0, UV.y));
	float haze = 0.78 + sin(UV.y * 11.0 + TIME * 0.7) * 0.12;
	ALBEDO = light_color.rgb;
	ALPHA = ends * haze * power * 0.075;
}
