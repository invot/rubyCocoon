shader_type spatial;
// The soft patch of shade on the ground under someone standing outdoors (contact_shadow.gd): one small quad, no
// texture and no lighting, the same on the Forward+, Mobile and Compatibility renderers.
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

// black: blended over the ground it darkens without changing the ground's hue, so grass stays a saturated green.
// (Blending is in linear light, so this looks about half as strong on screen as it reads here.)
uniform float strength = 0.7;

void fragment() {
	// solid under the feet, where the body covers it anyway, so that it shows around them; fading out softly from there
	ALBEDO = vec3(0.0);
	ALPHA = (1.0 - smoothstep(0.2, 1.0, length(UV * 2.0 - 1.0))) * strength;
}
