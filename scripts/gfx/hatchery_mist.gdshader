shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// Two drifting samples of one cloud texture, faded out towards the edge of the plane. Used lying flat for ground haze
// and standing up for banks of fog behind the plinth.
uniform sampler2D mist_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tint : source_color = vec3(0.62, 0.66, 0.76);
uniform float opacity = 0.2;
uniform float tiling = 3.0;
uniform vec2 drift = vec2(0.010, -0.007);
uniform float inner = 0.12;
uniform float outer = 0.5;
// Clears the middle of a ground layer, so it opens softly around whatever stands there.
uniform float hole = 0.0;

void fragment() {
	float first = texture(mist_texture, UV * tiling + drift * TIME).r;
	float second = texture(mist_texture, UV * tiling * 0.63 - drift.yx * TIME * 0.7 + vec2(0.37, 0.11)).r;
	float centre = distance(UV, vec2(0.5));
	float edge = (1.0 - smoothstep(inner, outer, centre)) * smoothstep(hole, hole + 0.05, centre);
	ALBEDO = tint;
	ALPHA = smoothstep(0.22, 0.82, first * 0.6 + second * 0.4) * edge * opacity;
}
