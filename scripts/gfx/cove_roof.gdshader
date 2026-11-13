shader_type spatial;
// Clay tile roofs for Cocoon Cove's kit houses (cove_buildings.gd). The kit paints a roof one flat red; here it is
// laid in courses of rounded terracotta tiles running along the eaves, each course tucked under the one above (a
// soft shadow at its head, a lit lip at its foot), every tile fired a slightly different tone, with a gentle drift of
// weathering across the slope. Mapped from the world along each slope, so it fits whatever the kit's UVs do.
// Clean and painted: no grain, no hard black lines.

// the kit's palette, and whether this surface is coloured from it (else `clay` alone)
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_atlas = true;
// the fired clay the kit's reds are eased towards
uniform vec4 clay : source_color = vec4(0.79, 0.42, 0.27, 1.0);
// a tile's size: across the slope and down it, in world units
uniform vec2 tile = vec2(0.3, 0.36);

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

uniform float building_opacity = 1.0;

void fragment() {
	// Screen-door coverage keeps the opaque pipeline and hides interior surfaces.
	if (fract(dot(floor(FRAGCOORD.xy), vec2(0.754877666, 0.569840296))) >= building_opacity) discard;
	vec3 base = use_atlas ? texture(atlas, UV).rgb : clay.rgb;
	// the kit's roof reds; anything else on this surface keeps its own colour
	float red = use_atlas ? clamp((base.r - max(base.g, base.b) * 1.6) * 6.0, 0.0, 1.0) : 1.0;
	vec3 fired = mix(base, clay.rgb, 0.55);
	vec3 n = normalize(wnorm);
	float flat_len = length(n.xz);
	// along the eave and down the slope (a level top is laid north to south)
	vec2 level = flat_len > 0.05 ? n.xz / flat_len : vec2(0.0, 1.0);
	float along = dot(wpos.xz, vec2(-level.y, level.x));
	float down = flat_len > 0.05 ? (dot(wpos.xz, level) * n.y - wpos.y * flat_len) : wpos.z;
	float r = down / tile.y;
	float row = floor(r);
	float fr = fract(r);
	float c = along / tile.x + mod(row, 2.0) * 0.5;
	float fc = fract(c);
	vec2 id = vec2(floor(c), row);
	// rounded across its width, in the shade of the course above at its head, a lit lip at its foot
	float shade = mix(0.84, 1.0, pow(sin(fc * 3.14159), 0.6));
	shade *= mix(0.74, 1.0, smoothstep(0.0, 0.4, fr));
	shade *= mix(1.0, 1.1, smoothstep(0.7, 0.95, fr));
	// each tile's own firing, and the slope's weathering
	float h = hash(id);
	vec3 tone = mix(vec3(0.88, 0.86, 0.9), vec3(1.12, 1.06, 0.94), h);
	tone *= mix(0.92, 1.06, vnoise(wpos.xz * 0.35 + wpos.y * 0.2));
	vec3 tiles = fired * tone * shade;
	// only faces that look up are laid in tiles; a roof's edges and trim take the plain clay, a little deeper
	float roof = red * smoothstep(0.12, 0.3, n.y);
	ALBEDO = mix(mix(base, fired * 0.88, red), tiles, roof);
	ROUGHNESS = 0.9;
	SPECULAR = 0.15;
}
