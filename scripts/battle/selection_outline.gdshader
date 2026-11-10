shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform vec4 gem : source_color = vec4(0.82, 0.12, 0.17, 1.0);

void vertex() {
	// Screen-sized inverted hull, including animated and skinned meshes. No screen/depth reads.
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 n = mat3(MODELVIEW_MATRIX) * NORMAL;
	vec2 direction = (PROJECTION_MATRIX * vec4(n, 0.0)).xy;
	clip.xy += direction / max(length(direction), 0.001) * 5.0 * clip.w / VIEWPORT_SIZE;
	POSITION = clip;
}

void fragment() {
	ALBEDO = gem.rgb;
}
