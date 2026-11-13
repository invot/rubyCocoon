shader_type spatial;
// The overworld ground. Each tile has a ground layer (grass, path, plaza...) in `kind_map`; the shader looks it up
// with a little noise so the borders between layers wander like a hand-painted map, softly blended over a narrow
// band, and colours each layer per biome. Flat ground is mapped from above and slopes from the side. The same
// shader draws the cliff faces between levels (see "cliff").

uniform sampler2DArray layers : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// R = layer index / 255, one texel per tile, starting at `map_origin` (world x, z). On a diagonal cliff's tile
// (elevation.gd "/" or a backslash), B is its code (5-8: which half is high), R its high half's layer and G its low half's.
// On a tile with cut or filled corners (terrain_mesh.gd _prepare_corners: the grass's corners chamfered where a path
// bends round them, a path's corners filled where it bends inside the grass), B is 16 + the corners' bits (NW 1, NE 2,
// SE 4, SW 8) and G the layer in those corners.
uniform sampler2D kind_map : filter_nearest, repeat_disable;
uniform vec2 map_origin = vec2(0.0);
uniform vec2 map_size = vec2(1.0);
uniform vec3 tints[10];
// how far (in tiles) a border may wander
uniform float edge_noise = 0.28;
// texture repeats per world unit
uniform float tex_scale = 0.5;
// how wide (in tiles) the soft blend across a border is
uniform float edge_soft = 0.07;
// cliff faces (terrain_mesh.gd): the biome's rock (WorldDB.CLIFF_LOOKS) in cliff_tint, darker towards the foot
// (COLOR.r: 0 at the rock's top, 1 at its foot), under a rounded lip of the ground above (COLOR.g 1; COLOR.ba the way
// the face looks). The turf's edges (COLOR.g 0.5) show the soil under the grass, and lay a shadow on the ground at
// their foot (COLOR.g 0.2: COLOR.r 1 at the foot, 0 where it fades out). UV runs along the cliff and down from its top, in units. Retaining walls (no cliff_tex) are the
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
// the soil under the grass's edge (linear), where its turf stands above a path (terrain_mesh.gd _face)
uniform vec3 turf_soil = vec3(0.16, 0.1, 0.06);
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
	if (code >= 16) {
		// corners cut or filled: the corner out to the middles of the tile's sides, beyond a quarter circle round the
		// tile's middle (terrain_mesh.gd CORNER_ARC), takes the other layer
		int mask = code - 16;
		vec2 f = p - floor(p);
		// (A: the corners along a diagonal edge, which cut straight across instead)
		int along = int(k.a * 255.0 + 0.5);
		int bit = f.x < 0.5 ? (f.y < 0.5 ? 1 : 8) : (f.y < 0.5 ? 2 : 4);
		vec2 g = abs(f - 0.5);
		bool corner = (mask & bit) != 0 && ((along & bit) != 0 ? g.x + g.y > 0.5 : length(g) > 0.5);
		return int((corner ? k.g : k.r) * 255.0 + 0.5);
	}
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

// grass, dark grass (VT.GRASS_LAYERS): the turf, a pillow above the ground with a crisp edge round it
bool _grassy(int l) {
	return l == 0 || l == 9;
}

// path, plaza, sand, paving: the bare grounds that run into each other (stone road to dirt, dirt to beach) over a
// ragged, soft band instead of along the tiles' square edges
bool _soil(int l) {
	return l == 1 || l == 2 || l == 3 || l == 7;
}

// How far round a point the bare grounds are looked for (tiles): the band they fade over is about twice this wide.
const float SOIL_REACH = 0.5;

// The bare ground at q, blended with its neighbours': each layer found round q (a jittered ring of eight looks and
// q itself) stands as high as its share of the looks, its texture's own light and dark (stones stand proud of
// their mortar, the dirt fills in round them) and a patchy noise; the highest show, softly.
vec3 _soil_mix(vec2 q, vec2 uv, int own) {
	vec2 jq = vec2(vnoise(q * 2.3 + vec2(3.1, 7.7)), vnoise(q * 2.3 + vec2(19.4, 1.3))) - 0.5;
	vec2 c = q + jq * 0.8;
	int found[3] = int[](own, -1, -1);
	float share[3] = float[](0.0, 0.0, 0.0);
	for (int k = 0; k < 9; k++) {
		vec2 o = k == 8 ? vec2(0.0) : vec2(cos(float(k) * 0.785398), sin(float(k) * 0.785398)) * SOIL_REACH;
		int l = _layer_at(c + o);
		// (grass, water and the rest stand apart: their own edges are drawn elsewhere)
		if (!_soil(l)) {
			l = own;
		}
		for (int s = 0; s < 3; s++) {
			if (found[s] == l || found[s] == -1) {
				found[s] = l;
				share[s] += 1.0 / 9.0;
				break;
			}
		}
	}
	if (found[1] == -1) {
		return texture(layers, vec3(uv * tex_scale, float(own))).rgb * tints[own];
	}
	vec3 cols[3];
	float hts[3];
	float top = -10.0;
	for (int s = 0; s < 3; s++) {
		if (found[s] == -1) {
			hts[s] = -10.0;
			cols[s] = vec3(0.0);
			continue;
		}
		vec3 t = texture(layers, vec3(uv * tex_scale, float(found[s]))).rgb;
		float lum = dot(t, vec3(0.3, 0.55, 0.15));
		cols[s] = t * tints[found[s]];
		hts[s] = share[s] + (lum - 0.5) * 0.3 + (vnoise(q * 1.7 + vec2(float(found[s]) * 7.1, 2.0)) - 0.5) * 0.45
			+ (vnoise(q * 5.3 + vec2(2.0, float(found[s]) * 3.7)) - 0.5) * 0.2;
		top = max(top, hts[s]);
	}
	vec3 col = vec3(0.0);
	float sum = 0.0;
	for (int s = 0; s < 3; s++) {
		float wgt = max(hts[s] - (top - 0.16), 0.0);
		col += cols[s] * wgt;
		sum += wgt;
	}
	return col / max(sum, 0.0001);
}

// lighter and darker patches across the grass: sunny, slightly yellower stretches and deeper, cooler ones
vec3 _mottle(vec2 q) {
	float m = vnoise(q * 0.21 + vec2(7.0, 3.0)) * 0.65 + vnoise(q * 0.8 + vec2(2.0, 11.0)) * 0.35;
	return mix(vec3(0.85, 0.9, 0.9), vec3(1.15, 1.12, 0.92), smoothstep(0.22, 0.78, m));
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
		// only ground truly in front of them, nearer the camera across the map (a cliff rising just behind them leans
		// toward the tilted camera, but must stay whole, or what's inside it shows through)
		if (length(wpos.xz - CAMERA_POSITION_WORLD.xz) < length(hole.xz - CAMERA_POSITION_WORLD.xz) - 0.4) {
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
	// The grass top's outermost pixels can look a hair over its edge into the path's tile and come out as dirt, a thin
	// light line round the turf. Bare ground this close to grass is under the turf's overhang anyway, so it's grass.
	if (!cliff && !_grassy(own)) {
		for (int k = 0; k < 4; k++) {
			vec2 o = vec2(k == 0 ? 0.03 : (k == 1 ? -0.03 : 0.0), k == 2 ? 0.03 : (k == 3 ? -0.03 : 0.0));
			int l = _layer_at(q + o);
			if (_grassy(l)) {
				own = l;
				break;
			}
		}
	}
	// laid surfaces (plaza, paving, ice) keep neat edges: they barely wander, and nothing wanders onto them
	float amp = _laid(own) ? 0.12 : 1.0;
	vec2 at = q + j * edge_noise * 2.0 * amp;
	// four looks round the point; where they disagree (a border) their layers are blended
	int ls[4];
	for (int k = 0; k < 4; k++) {
		vec2 o = vec2(k % 2 == 0 ? -1.0 : 1.0, k < 2 ? -1.0 : 1.0) * edge_soft * 0.5;
		int l = _layer_at(at + o);
		// (and a river or sea bed never wanders up onto the bank above it; the turf's edge is where its pillow steps
		// down, so grass and the ground below it never wander over one another)
		ls[k] = ((_laid(l) || l == 5 || l == 6 || _grassy(l) != _grassy(own)) && l != own) ? own : l;
	}
	int layer = ls[0];
	bool border = ls[1] != layer || ls[2] != layer || ls[3] != layer;
	vec3 n = abs(wnorm);
	vec2 uv = n.y > 0.6 ? wpos.xz : (n.x > n.z ? vec2(wpos.z, -wpos.y) : vec2(wpos.x, -wpos.y));
	if (cliff && COLOR.g > 0.1 && COLOR.g < 0.25) {
		// the turf's shadow on the ground at its foot: the ground as it is, darker towards the turf
		vec3 col = texture(layers, vec3(uv * tex_scale, float(own))).rgb * tints[own];
		ALBEDO = col * mix(1.0, 0.62, smoothstep(0.0, 1.0, COLOR.r));
	} else if (cliff) {
		vec2 face = COLOR.ba * 2.0 - 1.0;
		if (COLOR.g > 0.5) {
			// the lip: the ground just back from the edge, mapped from above as it is, rolling over the top
			int l = _layer_at(wpos.xz - face * 0.4);
			vec3 col = texture(layers, vec3(wpos.xz * tex_scale, float(l))).rgb * tints[l];
			if (_grassy(l)) {
				col *= _mottle(wpos.xz);
			}
			// its underside, turned away from the sky, a little darker
			ALBEDO = col * mix(0.72, 1.0, clamp(wnorm.y * 1.5 + 0.5, 0.0, 1.0));
		} else if (COLOR.g > 0.25) {
			// the soil under the turf's edge: darker in under the lip, a little uneven
			ALBEDO = turf_soil * (0.8 + 0.3 * vnoise(vec2(cuv.x * 6.0, wpos.y * 4.0))) * mix(0.7, 1.0, COLOR.r);
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
	} else {
		vec3 col;
		if (_soil(own) && n.y > 0.6) {
			col = _soil_mix(q, uv, own);
		} else if (border) {
			col = vec3(0.0);
			for (int k = 0; k < 4; k++) {
				col += texture(layers, vec3(uv * tex_scale, float(ls[k]))).rgb * tints[ls[k]];
			}
			col *= 0.25;
		} else {
			col = texture(layers, vec3(uv * tex_scale, float(layer))).rgb * tints[layer];
		}
		if (_grassy(own)) {
			// the darker grass (round the trees and hedges, where the long grass grows) melts into the lawn over
			// half a tile rather than along a line
			float dark = 0.0;
			for (int k = 0; k < 4; k++) {
				vec2 o = vec2(k % 2 == 0 ? -1.0 : 1.0, k < 2 ? -1.0 : 1.0) * 0.26;
				int l = _layer_at(at + o);
				dark += (l == 9 || (!_grassy(l) && own == 9)) ? 0.25 : 0.0;
			}
			col = texture(layers, vec3(uv * tex_scale, 0.0)).rgb * mix(tints[0], tints[9], smoothstep(0.0, 1.0, dark));
			col *= _mottle(q);
		}
		ALBEDO = col;
	}
	// The original cliff texture stays visible through the fall, with just a cool wet lift on that face.
	if (cliff && COLOR.g > 0.04 && COLOR.g < 0.1) {
		ALBEDO = mix(ALBEDO * 1.08, vec3(0.16, 0.32, 0.46), 0.12);
	}
	ROUGHNESS = 1.0;
	SPECULAR = 0.2;
}
