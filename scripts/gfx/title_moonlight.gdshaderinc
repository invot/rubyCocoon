// Shared by the moon card and its light on the ground so the rose halo meets at the horizon.
const vec3 MOON_GLOW = vec3(0.85, 0.32, 0.38);

float moon_halo(float d, float radius) {
	float out_d = max(d - radius, 0.0);
	return (exp(-out_d * 16.0) * 0.5 + exp(-out_d * 5.0) * 0.18)
		* (1.0 - smoothstep(0.32, 0.5, d));
}
