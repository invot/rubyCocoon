shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec3 yellow : source_color = vec3(1.0, 0.811765, 0.141176);
uniform float opacity = 0.58;

void fragment() {
	// UV.y measures distance from the attacker. The centre of each chevron is
	// farther along the shaft than its edges, so both its point and travel face the target.
	float phase = (UV.y - TIME * 0.55 + abs(UV.x - 0.5) * 0.24) / 0.48;
	float line_distance = abs(fract(phase + 0.5) - 0.5) * 0.48;
	float aa = max(fwidth(phase) * 0.48, 0.001);
	float stripe = (1.0 - smoothstep(0.014, 0.014 + aa, line_distance)) * step(0.0, UV.x);
	ALBEDO = mix(yellow, vec3(1.0), stripe * 0.28);
	ALPHA = opacity;
	ROUGHNESS = 0.55;
	EMISSION = ALBEDO * 0.2;
}
