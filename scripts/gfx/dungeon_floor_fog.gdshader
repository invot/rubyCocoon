shader_type fog;
// Floor mist in the Dustwell Well's caves (well_cave.gd _mist): a FogVolume box over each level, Forward+ only.
// The noise drifts in world space, so neighbouring levels and rooms line up. The mist lies low (UVW.y is 0 at the box's
// floor and 1 at its top), fades out at the box's sides (SDF), and only lies over the level's own floor tiles (coverage).

uniform vec3 fog_color : source_color = vec3(0.25, 0.32, 0.38);
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float base_density : hint_range(-2.0, 5.0) = 0.85;
uniform float height_falloff : hint_range(0.1, 10.0) = 2.5;
uniform float edge_softness : hint_range(0.01, 2.0) = 0.5;
uniform float noise_scale : hint_range(0.01, 1.0) = 0.15;
uniform vec3 drift_speed = vec3(0.04, 0.0, 0.02);
uniform sampler3D noise_tex : repeat_enable, filter_linear;
// the level's floor tiles, white inside and fading to black at their edges, over the whole map
uniform sampler2D coverage : filter_linear, repeat_disable;
// where this box sits in coverage's UVs: xy its corner, zw its size
uniform vec4 cover_rect = vec4(0.0, 0.0, 1.0, 1.0);

void fog() {
	float noise = texture(noise_tex, WORLD_POSITION * noise_scale + drift_speed * TIME).r;
	float vertical_fade = pow(clamp(1.0 - UVW.y, 0.0, 1.0), height_falloff);
	// (SDF is negative inside the box; smoothstep's edges must rise, so it's flipped rather than run backwards)
	float border_fade = 1.0 - smoothstep(-edge_softness, 0.0, SDF);
	float cover = texture(coverage, cover_rect.xy + UVW.xz * cover_rect.zw).r;
	ALBEDO = fog_color;
	EMISSION = emission_color;
	DENSITY = base_density * noise * vertical_fade * border_fade * cover;
}
