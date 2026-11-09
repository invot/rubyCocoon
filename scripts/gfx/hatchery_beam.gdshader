shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// A soft shaft of light on an open cone one unit tall: it fades out towards its silhouette, so no hard outline shows.
uniform float power : hint_range(0.0, 1.0) = 0.0;
uniform float strength = 0.3;
uniform float falloff = 1.5;
// Where the lower end starts to fade, from 0 at the top of the shaft to 1 at its base.
uniform float base_fade = 0.78;
uniform vec4 light_color : source_color = vec4(1.0, 0.94, 0.82, 1.0);
varying float along;

void vertex() {
	along = 0.5 - VERTEX.y;
}

void fragment() {
	// An orthographic camera looks the same way from every point, but VIEW still aims back at the camera's origin.
	vec3 eye = PROJECTION_MATRIX[3][3] > 0.5 ? vec3(0.0, 0.0, 1.0) : normalize(VIEW);
	float soft_edge = pow(abs(dot(normalize(NORMAL), eye)), falloff);
	float ends = smoothstep(0.0, 0.05, along) * (1.0 - smoothstep(base_fade, 1.0, along));
	ALBEDO = light_color.rgb;
	ALPHA = clamp(soft_edge * ends * mix(1.0, 0.5, along) * power * strength, 0.0, 1.0);
}
