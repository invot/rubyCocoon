shader_type spatial;
// The overworld ground. Each tile has a ground layer (grass, path, plaza...) in `kind_map`; the shader looks it up
// with a little noise so the borders between layers wander like a hand-painted map, softly blended over a narrow
// band, and colours each layer per biome. Flat ground is mapped from above and slopes from the side. The same
// shader draws the cliff faces between levels (see "cliff").

uniform sampler2DArray layers : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// R = layer index / 255, one texel per tile, starting at `map_origin` (world x, z)
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
// cliff faces (terrain_mesh.gd): rock in cliff_tint, darker towards the foot (COLOR.r), with a ragged lip of the
// ground above along the top (COLOR.g)
uniform bool cliff = false;
uniform vec3 cliff_tint = vec3(1.0);
uniform int rock_layer = 4;
// the see-through patch (world.gd): xyz the player's feet, w 1 while it's on. Ground higher than their feet that
// stands between the camera and them dissolves in a dither over their shape, so high ground never hides them.
uniform vec4 hole = vec4(0.0);

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
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
	return int(texelFetch(kind_map, t, 0).r * 255.0 + 0.5);
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
		ls[k] = (_laid(l) && l != own) ? own : l;
	}
	int layer = ls[0];
	bool border = ls[1] != layer || ls[2] != layer || ls[3] != layer;
	vec3 n = abs(wnorm);
	vec2 uv = n.y > 0.6 ? wpos.xz : (n.x > n.z ? vec2(wpos.z, -wpos.y) : vec2(wpos.x, -wpos.y));
	if (cliff) {
		// the lip: the ground above, just back from the edge, hanging a ragged strip over the rock
		bool lip = COLOR.g > 0.72 + 0.22 * vnoise(vec2(dot(wpos.xz, vec2(1.0)) * 7.0, wpos.y * 3.0));
		layer = lip ? _layer_at(wpos.xz - normalize(wnorm.xz + vec2(0.0001)) * 0.3) : rock_layer;
		vec3 col = texture(layers, vec3(uv * tex_scale, float(layer))).rgb;
		ALBEDO = lip ? col * tints[layer] * 0.85 : col * cliff_tint * COLOR.r;
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
