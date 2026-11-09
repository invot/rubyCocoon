shader_type spatial;
// The overworld ground. Each tile has a ground layer (grass, path, plaza...) in `kind_map`; the shader looks it up
// with a little noise so the borders between layers wander like a hand-painted map, softly blended over a narrow
// band, and colours each layer per biome. Flat ground is mapped from above and slopes from the side. The same
// shader draws the cliff faces between levels (see "cliff").

uniform sampler2DArray layers : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// R = layer index / 255, one texel per tile, starting at `map_origin` (world x, z). On a diagonal cliff's tile
// (elevation.gd "/" or a backslash), B is its code (5-8: which half is high), R its high half's layer and G its low half's.
uniform sampler2D kind_map : filter_nearest, repeat_disable;
uniform vec2 map_origin = vec2(0.0);
uniform vec2 map_size = vec2(1.0);
uniform vec3 tints[9];
// how far (in tiles) a border may wander
uniform float edge_noise = 0.28;
// texture repeats per world unit
uniform float tex_scale = 0.5;
// how wide (in tiles) the soft blend across a border is
uniform float edge_soft = 0.07;
// cliff faces (terrain_mesh.gd): the biome's rock (WorldDB.CLIFF_LOOKS) in cliff_tint, darker towards the foot
// (COLOR.r: 0 at the rock's top, 1 at its foot), under a rounded lip of the ground above (COLOR.g; COLOR.ba the way
// the face looks). UV runs along the cliff and down from its top, in units. Retaining walls (no cliff_tex) are the
// rock_layer ground texture instead.
uniform bool cliff = false;
uniform vec3 cliff_tint = vec3(1.0);
uniform int rock_layer = 4;
uniform bool cliff_textured = false;
uniform sampler2D cliff_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// texture repeats per unit along the cliff and down it
uniform vec2 cliff_scale = vec2(0.5);
// strata: rgb a second (linear) colour laid in level bands, a how strongly
uniform vec4 cliff_band = vec4(0.0);
// moss: rgb its (linear) colour, a how much of the rock's upper part it covers
uniform vec4 cliff_moss = vec4(0.0);
// the see-through patch (world.gd): xyz the player's feet, w 1 while it's on. Ground higher than their feet that
// stands between the camera and them dissolves in a dither over their shape, so high ground never hides them.
uniform vec4 hole = vec4(0.0);

varying vec3 wpos;
varying vec3 wnorm;
varying vec2 cuv;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	cuv = UV;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

int _layer_at(vec2 p) {
	ivec2 t = clamp(ivec2(floor(p - map_origin)), ivec2(0), ivec2(map_size) - 1);
	vec4 k = texelFetch(kind_map, t, 0);
	int code = int(k.b * 255.0 + 0.5);
	if (code >= 5) {
		// a diagonal: the half p is on (map_origin is whole tiles, so p's fraction is its place in the tile)
		vec2 f = p - floor(p);
		bool high = code == 5 ? f.x + f.y <= 1.0 : (code == 6 ? f.x + f.y >= 1.0 : (code == 7 ? f.x >= f.y : f.x <= f.y));
		return int((high ? k.r : k.g) * 255.0 + 0.5);
	}
	return int(k.r * 255.0 + 0.5);
}

// plaza, paving, ice (see VT.GROUND_LAYERS)
bool _laid(int l) {
	return l == 2 || l == 7 || l == 8;
}

// 4x4 ordered dither threshold at a screen pixel
float bayer(vec2 px) {
	int i = int(mod(px.x, 4.0)) + int(mod(px.y, 4.0)) * 4;
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[i] + 0.5) / 16.0;
}

void fragment() {
	// (the camera's view only: the sun's shadow pass looks straight down its own orthographic view)
	if (hole.w > 0.5 && wpos.y > hole.y + 0.3 && PROJECTION_MATRIX[3][3] < 0.5) {
		vec3 feet = (VIEW_MATRIX * vec4(hole.xyz, 1.0)).xyz;
		if (-VERTEX.z < -feet.z - 0.4) {
			vec4 f = PROJECTION_MATRIX * vec4(feet, 1.0);
			vec4 hd = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(hole.xyz + vec3(0.0, 1.9, 0.0), 1.0));
			vec4 g = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
			vec2 asp = vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0);
			vec2 a = f.xy / f.w * asp;
			vec2 up = hd.xy / hd.w * asp - a;
			float tall = max(length(up), 0.0001);
			up /= tall;
			vec2 rel = g.xy / g.w * asp - a;
			// along the body (0 at the feet, 1 at the head) and out to the side, in body heights
			float along = dot(rel, up) / tall;
			float side = abs(dot(rel, vec2(-up.y, up.x))) / tall;
			float r = max(side / 0.48, (along - 0.9) / 0.4);
			if (along > -0.02 && r < 1.0 && smoothstep(1.0, 0.55, r) > bayer(FRAGCOORD.xy)) {
				discard;
			}
		}
	}
	vec2 q = wpos.xz;
	vec2 j = vec2(vnoise(q * 1.6), vnoise(q * 1.6 + vec2(17.3, 41.9))) - 0.5;
	j += 0.5 * (vec2(vnoise(q * 4.1 + vec2(5.1, 2.7)), vnoise(q * 4.1 + vec2(29.0, 13.0))) - 0.5);
	int own = _layer_at(q);
	// laid surfaces (plaza, paving, ice) keep neat edges: they barely wander, and nothing wanders onto them
	float amp = _laid(own) ? 0.12 : 1.0;
	vec2 at = q + j * edge_noise * 2.0 * amp;
	// four looks round the point; where they disagree (a border) their layers are blended
	int ls[4];
	for (int k = 0; k < 4; k++) {
		vec2 o = vec2(k % 2 == 0 ? -1.0 : 1.0, k < 2 ? -1.0 : 1.0) * edge_soft * 0.5;
		int l = _layer_at(at + o);
		// (and a river or sea bed never wanders up onto the bank above it)
		ls[k] = ((_laid(l) || l == 5 || l == 6) && l != own) ? own : l;
	}
	int layer = ls[0];
	bool border = ls[1] != layer || ls[2] != layer || ls[3] != layer;
	vec3 n = abs(wnorm);
	vec2 uv = n.y > 0.6 ? wpos.xz : (n.x > n.z ? vec2(wpos.z, -wpos.y) : vec2(wpos.x, -wpos.y));
	if (cliff) {
		vec2 face = COLOR.ba * 2.0 - 1.0;
		if (COLOR.g > 0.5) {
			// the lip: the ground just back from the edge, mapped from above as it is, rolling over the top
			int l = _layer_at(wpos.xz - face * 0.4);
			vec3 col = texture(layers, vec3(wpos.xz * tex_scale, float(l))).rgb * tints[l];
			// its underside, turned away from the sky, a little darker
			ALBEDO = col * mix(0.72, 1.0, clamp(wnorm.y * 1.5 + 0.5, 0.0, 1.0));
		} else if (cliff_textured) {
			float down = COLOR.r;
			vec3 rock = texture(cliff_tex, vec2(cuv.x, cuv.y) * cliff_scale).rgb;
			// faint upright streaks between the texture's own
			rock *= 0.92 + 0.16 * vnoise(vec2(cuv.x * 5.0, wpos.y * 0.6));
			vec3 tint = cliff_tint;
			if (cliff_band.a > 0.0) {
				float b = sin(wpos.y * 6.2832 / 0.55 + vnoise(vec2(cuv.x * 0.8, wpos.y * 0.5)) * 2.5);
				tint = mix(tint, cliff_band.rgb / 0.71, cliff_band.a * smoothstep(0.35, 0.8, b));
			}
			vec3 col = rock * tint;
			if (cliff_moss.a > 0.0) {
				float m = smoothstep(0.45, 0.7, vnoise(cuv * vec2(2.4, 3.2) + vec2(wpos.y * 0.3, 0.0)) + (0.5 - down) * 0.6 * cliff_moss.a);
				col = mix(col, cliff_moss.rgb * (0.85 + 0.3 * vnoise(cuv * 9.0)), m * cliff_moss.a);
			}
			// in the lip's shadow at the top, and darker towards the foot
			float shade = mix(1.0, 0.62, smoothstep(0.0, 1.0, down)) * mix(0.78, 1.0, smoothstep(0.0, 0.18, cuv.y));
			ALBEDO = col * shade;
		} else {
			vec3 col = texture(layers, vec3(uv * tex_scale, float(rock_layer))).rgb;
			ALBEDO = col * cliff_tint * mix(1.0, 0.6, COLOR.r);
		}
	} else if (border) {
		vec3 col = vec3(0.0);
		for (int k = 0; k < 4; k++) {
			col += texture(layers, vec3(uv * tex_scale, float(ls[k]))).rgb * tints[ls[k]];
		}
		ALBEDO = col * 0.25;
	} else {
		vec3 col = texture(layers, vec3(uv * tex_scale, float(layer))).rgb;
		ALBEDO = col * tints[layer];
	}
	ROUGHNESS = 1.0;
	SPECULAR = 0.2;
}
