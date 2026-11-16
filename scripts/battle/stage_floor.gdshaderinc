uniform vec4 edge_tint : source_color = vec4(0.6, 0.65, 0.85, 1.0);
// The overworld's own painted ground layers (VT.ground_layers, terrain.gdshader), at the world's scale, so a battle
// stands on the same ground as the road it started on. stage_lighting.gd ground_material picks three layers:
// the stage's own, broad patches of a second and a few worn spots of a third, tinted per biome as the world does.
uniform sampler2DArray layers : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform int base_layer = 0;
uniform int patch_layer = 9;
uniform int worn_layer = 1;
uniform vec3 base_tint = vec3(1.0);
uniform vec3 patch_tint = vec3(1.0);
uniform vec3 worn_tint = vec3(1.0);
// how much of the floor the patches and the worn spots cover (0..1)
uniform float patch_cover = 0.4;
uniform float worn_cover = 0.2;
// sunny and shady stretches, as on the world's lawns
uniform float mottle_strength = 1.0;
// texture repeats per world unit (terrain.gdshader tex_scale)
uniform float tex_scale = 0.5;

// Broad pools around the two rings, fading to a cool perimeter. One lit pass, no extra lights or shadow maps.
vec3 stage_floor_color(vec3 color, vec3 at) {
	vec2 ally = at.xz - vec2(2.4, 5.4);
	vec2 foe = at.xz - vec2(-2.6, -2.4);
	float edge = smoothstep(16.0, 144.0, min(dot(ally, ally), dot(foe, foe)));
	return color * mix(vec3(1.0), edge_tint.rgb * 0.65, edge * 0.85);
}

float stage_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float stage_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(stage_hash(i), stage_hash(i + vec2(1.0, 0.0)), f.x),
		mix(stage_hash(i + vec2(0.0, 1.0)), stage_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Per vertex (the floor is a fine grid, so no noise runs per pixel): x the patches, y the worn spots, z which of the
// two texture placements shows (breaks the texture's repeat), w the mottle.
vec4 stage_ground_masks(vec2 q) {
	float p = stage_noise(q * 0.11 + vec2(3.1, 7.7)) * 0.7 + stage_noise(q * 0.33 + vec2(11.0, 2.0)) * 0.3;
	float w = stage_noise(q * 0.19 + vec2(23.0, 5.3)) * 0.65 + stage_noise(q * 0.52 + vec2(1.0, 31.0)) * 0.35;
	float k = stage_noise(q * 0.16 + vec2(41.0, 17.0));
	float m = stage_noise(q * 0.21 + vec2(7.0, 3.0)) * 0.65 + stage_noise(q * 0.8 + vec2(2.0, 11.0)) * 0.35;
	return vec4(p - (1.0 - patch_cover) + 0.5, w - (1.0 - worn_cover) + 0.5, k, m);
}

// One layer, read at two placements (the second turned and shifted) and blended broadly, so no tile grid repeats.
vec3 stage_layer(int layer, vec2 q, float k) {
	vec2 uv = q * tex_scale;
	vec3 a = texture(layers, vec3(uv, float(layer))).rgb;
	vec2 turned = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8)) * uv * 0.83 + vec2(0.37, 0.71);
	vec3 b = texture(layers, vec3(turned, float(layer))).rgb;
	return mix(a, b, smoothstep(0.3, 0.7, k));
}

vec3 stage_ground_color(vec2 q, vec4 m) {
	vec3 base = stage_layer(base_layer, q, m.z) * base_tint;
	vec3 col = base;
	float lum = dot(base, vec3(0.3, 0.55, 0.15));
	if (patch_cover > 0.0) {
		vec3 spot = stage_layer(patch_layer, q, 1.0 - m.z) * patch_tint;
		// the texture's own light and dark ragged the border, as the world's soil borders are
		float h = m.x + (dot(spot, vec3(0.3, 0.55, 0.15)) - lum) * 0.5;
		col = mix(col, spot, smoothstep(0.47, 0.56, h));
	}
	if (worn_cover > 0.0) {
		vec3 worn = stage_layer(worn_layer, q, m.z) * worn_tint;
		float h = m.y + (dot(worn, vec3(0.3, 0.55, 0.15)) - lum) * 0.5;
		col = mix(col, worn, smoothstep(0.5, 0.58, h));
	}
	vec3 mottle = mix(vec3(0.85, 0.9, 0.9), vec3(1.15, 1.12, 0.92), smoothstep(0.22, 0.78, m.w));
	return col * mix(vec3(1.0), mottle, mottle_strength);
}
