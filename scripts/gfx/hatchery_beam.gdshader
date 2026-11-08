shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// A soft shaft of light on an open cone one unit tall: it fades out towards its silhouette, so no hard outline shows.
uniform float power : hint_range(0.0, 1.0) = 0.0;
uniform float strength = 0.3;
uniform float falloff = 1.5;
uniform vec4 light_color : source_color = vec4(1.0, 0.94, 0.82, 1.0);
varying float along;

void vertex() {
	along = 0.5 - VERTEX.y;
}

void fragment() {
	float soft_edge = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), falloff);
	float ends = smoothstep(0.0, 0.05, along) * (1.0 - smoothstep(0.78, 1.0, along));
	ALBEDO = light_color.rgb;
	ALPHA = clamp(soft_edge * ends * mix(1.0, 0.5, along) * power * strength, 0.0, 1.0);
}
