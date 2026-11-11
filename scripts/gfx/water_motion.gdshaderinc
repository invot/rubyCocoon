// Shared by the water and floating leaves, so pads ride the same gentle swells.
vec2 water_phases(vec2 p, float time) {
	return vec2(dot(p, vec2(0.78, 1.18)) - time * 1.35,
		dot(p, vec2(-1.42, 0.55)) - time * 1.05);
}

float water_swell(vec2 p, float time) {
	vec2 phases = water_phases(p, time);
	return sin(phases.x) + 0.45 * sin(phases.y);
}
