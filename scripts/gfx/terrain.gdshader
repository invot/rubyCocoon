shader_type spatial;
// The overworld ground. Each tile has a ground layer (grass, path, plaza...) in `kind_map`; the shader looks it up
// with a little noise so the borders between layers wander like a hand-painted map, in whole texture pixels (no
// blending), and colours each layer per biome. Flat ground is mapped from above and slopes from the side.

uniform sampler2DArray layers : source_color, filter_nearest_mipmap, repeat_enable;
// R = layer index / 255, one texel per tile, starting at `map_origin` (world x, z)
uniform sampler2D kind_map : filter_nearest, repeat_disable;
uniform vec2 map_origin = vec2(0.0);
uniform vec2 map_size = vec2(1.0);
uniform vec3 tints[9];
// how far (in tiles) a border may wander
uniform float edge_noise = 0.28;
// texture repeats per world unit
uniform float tex_scale = 0.5;
// borders step in this many pixels per tile
uniform float edge_px = 16.0;

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

void fragment() {
	vec2 q = (floor(wpos.xz * edge_px) + 0.5) / edge_px;
	vec2 j = vec2(vnoise(q * 1.6), vnoise(q * 1.6 + vec2(17.3, 41.9))) - 0.5;
	j += 0.5 * (vec2(vnoise(q * 4.1 + vec2(5.1, 2.7)), vnoise(q * 4.1 + vec2(29.0, 13.0))) - 0.5);
	int own = _layer_at(q);
	// laid surfaces (plaza, paving, ice) keep neat edges: they barely wander, and nothing wanders onto them
	float amp = _laid(own) ? 0.12 : 1.0;
	int layer = _layer_at(q + j * edge_noise * 2.0 * amp);
	if (_laid(layer) && layer != own) {
		layer = own;
	}
	vec3 n = abs(wnorm);
	vec2 uv = n.y > 0.6 ? wpos.xz : (n.x > n.z ? vec2(wpos.z, -wpos.y) : vec2(wpos.x, -wpos.y));
	vec3 col = texture(layers, vec3(uv * tex_scale, float(layer))).rgb;
	ALBEDO = col * tints[layer];
	ROUGHNESS = 1.0;
	SPECULAR = 0.2;
}
