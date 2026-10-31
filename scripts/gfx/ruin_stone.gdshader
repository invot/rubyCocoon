shader_type spatial;
render_mode cull_disabled;
// Weathered temple stone taken over by the jungle: a painted stone texture laid on in world space (no UVs needed),
// tinted, with soft moss on every upward face, a green tide mark round the foot and vines hanging down the walls.
// Used by the Temple of Tides (tools/import_psx_tide_temple.gd) and its gatehouse.
uniform sampler2D stone_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moss_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(0.84, 0.78, 0.64, 1.0);
uniform vec4 moss_colour : source_color = vec4(0.34, 0.54, 0.24, 1.0);
// world units one repeat of the stone texture covers
uniform float span = 2.0;
// how much of the upward faces the moss covers (0 none, 1 nearly all)
uniform float moss = 0.6;
// how much of the walls the hanging vines cover
uniform float vines = 0.35;
// the height up the walls the green foot reaches
uniform float foot = 1.1;
varying vec3 place;
varying vec3 facing_world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	return noise(p) * 0.6 + noise(p * 2.3 + 7.1) * 0.3 + noise(p * 5.1 + 3.7) * 0.1;
}

vec3 triplanar(sampler2D tex, vec3 p, vec3 w) {
	return texture(tex, p.zy).rgb * w.x + texture(tex, p.xz).rgb * w.y + texture(tex, p.xy).rgb * w.z;
}

void vertex() {
	place = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	facing_world = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// the pack's faces aren't all wound the same way: both sides are drawn, each lit as its own front
	vec3 facing = FRONT_FACING ? facing_world : -facing_world;
	vec3 w = pow(abs(facing), vec3(4.0));
	w /= w.x + w.y + w.z;
	// the painted stone, its grout softened so the blocks read without dark seams
	vec3 stone = mix(triplanar(stone_tex, place / span, w), vec3(0.86), 0.4) * tint.rgb * COLOR.rgb;
	vec3 leaf = triplanar(moss_tex, place / (span * 0.6), w) * moss_colour.rgb;
	float height = place.y - NODE_POSITION_WORLD.y;
	float along = abs(facing.x) > abs(facing.z) ? place.z : place.x;
	// moss on the tops, in soft patches
	float top = smoothstep(0.3, 0.75, facing.y);
	float patch = fbm(place.xz * 0.9);
	float m = top * smoothstep(1.0 - moss - 0.08, 1.0 - moss + 0.08, patch);
	// a green foot where the ground's damp climbs the stone
	float side = 1.0 - top;
	float rise = foot * (0.55 + 0.6 * fbm(vec2(along * 1.3, 4.2)));
	m = max(m, side * (1.0 - smoothstep(rise - 0.25, rise + 0.05, height)));
	// vines: strands hanging down the walls, ragged at their ends
	float strand = fbm(vec2(along * 2.6, place.y * 0.18 + 11.0));
	float reach = fbm(vec2(along * 0.7, 2.0)) * 6.0;
	float hang = smoothstep(1.0 - vines - 0.06, 1.0 - vines + 0.06, strand) * smoothstep(reach - 0.6, reach + 0.6, height);
	m = max(m, side * step(abs(facing.y), 0.6) * hang);
	ALBEDO = mix(stone, leaf, m);
	ROUGHNESS = mix(0.92, 0.85, m);
}
