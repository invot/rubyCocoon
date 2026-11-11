uniform vec4 edge_tint : source_color = vec4(0.6, 0.65, 0.85, 1.0);

// Broad pools around the two rings, fading to a cool perimeter. One lit pass, no extra lights or shadow maps.
vec3 stage_floor_color(vec3 color, vec3 at) {
	vec2 ally = at.xz - vec2(2.4, 5.4);
	vec2 foe = at.xz - vec2(-2.6, -2.4);
	float edge = smoothstep(16.0, 144.0, min(dot(ally, ally), dot(foe, foe)));
	return color * mix(vec3(1.0), edge_tint.rgb * 0.65, edge * 0.85);
}
