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
