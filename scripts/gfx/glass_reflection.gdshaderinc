// The supplied Aero glass reference is a translucent mask, shared across the screen.
// Its alpha matters: dark transparent pixels must not become a grey film over the glass.
uniform sampler2D glass_shimmer : filter_linear_mipmap_anisotropic, repeat_disable;

float glass_reflection(vec2 screen_uv, vec2 viewport_size) {
	// Map the whole image once over the viewport, never once per window. Sampling
	// a coarse mip softens the reference's hard white edges at every screen resolution.
	vec4 stripe = textureLod(glass_shimmer, screen_uv, 2.0);
	// The supplied PNG is already translucent (peak alpha 97/255). Normalize that
	// built-in fade before applying the material's faintness, rather than fading twice.
	return clamp(stripe.r * stripe.a / (97.0 / 255.0), 0.0, 1.0);
}

// Per-window variation (the user's 2026-11-16 direction: windows side by side shouldn't shimmer in lockstep): a
// `seed` (0..1, fixed per window) shifts and slants the band a little and fades it on some windows.
float glass_hash(float n) {
	return fract(sin(n * 91.3458) * 47453.5453);
}

// A seed for a window from where it stands (its centre, or any point fixed for the whole pane).
float glass_seed(vec3 p) {
	return fract(sin(dot(floor(p * 4.0), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

// The band stays on the screen, so it slides across the glass as the camera moves; each window takes it at its own
// offset and slant and a slightly different opacity (`seed`, 0..1, fixed per window). The image is sampled inside a
// margin, so the offset never runs off its edge.
float glass_reflection_varied(vec2 screen_uv, vec2 viewport_size, float seed) {
	vec2 shift = vec2(glass_hash(seed + 0.17), glass_hash(seed + 0.53)) * 2.0 - 1.0;
	float slant = (glass_hash(seed + 0.91) * 2.0 - 1.0) * 0.06;
	vec2 uv = vec2(0.12) + screen_uv * 0.76 + shift * vec2(0.08, 0.05);
	uv.x += (screen_uv.y - 0.5) * slant;
	// most windows keep the full sheen; some are a little fainter
	float strength = mix(0.6, 1.0, smoothstep(0.0, 0.6, glass_hash(seed + 0.37)));
	return glass_reflection(uv, viewport_size) * strength;
}
