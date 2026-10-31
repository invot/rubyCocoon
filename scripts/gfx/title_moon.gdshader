shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
// The title's full moon, on a card: a pale disc with soft grey seas and a darker rim, bright enough to bloom, inside a
// cool halo that fades out before the card's edges.
uniform float r = 0.15;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = UV - 0.5;
	float d = length(p);
	float disc = 1.0 - smoothstep(r - 0.004, r + 0.002, d);
	float seas = smoothstep(0.5, 0.75, noise(p * 22.0) * 0.6 + noise(p * 45.0) * 0.4) * 0.22;
	float limb = 1.0 - 0.3 * pow(clamp(d / r, 0.0, 1.0), 3.0);
	vec3 moon = vec3(1.0, 0.97, 0.88) * (1.0 - seas) * limb * 1.6;
	float out_d = max(d - r, 0.0);
	float halo = (exp(-out_d * 16.0) * 0.5 + exp(-out_d * 5.0) * 0.18) * (1.0 - smoothstep(0.32, 0.5, d));
	ALBEDO = moon * disc + vec3(0.5, 0.6, 0.95) * halo * (1.0 - disc);
}
